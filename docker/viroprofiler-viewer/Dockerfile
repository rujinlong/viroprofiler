# ---------------------------------------------------------------------------
# ViroProfiler viewer image (process label: viroprofiler_vpfkit)
#
# The R runtime for RESULTS_TSE (bin/create_tse.r), which assembles the final
# TreeSummarizedExperiment with vpfkit. The conda side is locked; vpfkit is not
# on conda and comes from GitHub at a pinned commit.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

# vpfkit is pinned to a commit SHA, not `main`: on `main` a rebuild could change
# what create_tse.r calls without any file in this repository changing.
#
# This commit is vpfkit 0.6.0 -- the rewrite that RESULTS_TSE needs, because it
# is what exports annotate_viral_votes() -- plus the fixes that followed it. It
# is on `main` in both deng-lab/vpfkit and rujinlong/vpfkit.
#
# Pin a SHA that is *reachable from a branch*. The previous value, efa71660,
# was the tip of vpfkit's `dev`, and `dev` was squash-merged rather than
# fast-forwarded: the commit it named survived only as an unreferenced object
# and was never an ancestor of `main`. GitHub still served it, so the build
# kept working while pointing at code no branch contained -- and it predated
# the Copilot review fixes, so the image would have installed the older viewer.
# `git merge-base --is-ancestor <ref> origin/main` is the check.
ARG VPFKIT_REPO=deng-lab/vpfkit
ARG VPFKIT_REF=b5113673856a1e4b6b5244cde2e2365ea99983af
LABEL org.opencontainers.image.revision="${VPFKIT_REF}"
LABEL org.opencontainers.image.source="https://github.com/${VPFKIT_REPO}"

WORKDIR /app

COPY ./docker/viroprofiler-viewer/pixi.toml ./docker/viroprofiler-viewer/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked

ENV PATH=/app/.pixi/envs/default/bin:$PATH

# `bioconductor-genomeinfodbdata` ships no R package. Its conda artifact contains
# exactly two files, both shell scripts, and the post-link one fetches and installs
# the actual data package. micromamba runs post-link scripts; pixi does not, so
# without this step GenomeInfoDb is present but cannot be loaded, and
# `library(vpfkit)` fails with "there is no package called 'GenomeInfoDbData'" --
# several layers below the package that is actually missing.
#
# Run this one script explicitly rather than setting `run-post-link-scripts insecure`,
# which would silently execute any post-link script in any future dependency.
RUN PL=/app/.pixi/envs/default/bin/.bioconductor-genomeinfodbdata-post-link.sh && \
    test -x "$PL" && \
    PREFIX=/app/.pixi/envs/default bash "$PL" && \
    test -d /app/.pixi/envs/default/lib/R/library/GenomeInfoDbData

# If a future dependency adds another post-link script, it will be just as silently
# skipped. Fail the build instead, so the next one is found here rather than in a run.
RUN found="$(ls /app/.pixi/envs/default/bin/.*-post-link.sh 2>/dev/null | \
             grep -v 'bioconductor-genomeinfodbdata' || true)"; \
    if [ -n "$found" ]; then \
        echo "Unhandled post-link script(s); pixi does not run these:"; echo "$found"; exit 1; \
    fi

RUN R -e "remotes::install_github('${VPFKIT_REPO}', ref = '${VPFKIT_REF}', upgrade = 'never', dependencies = FALSE)" && \
    R -e "library(vpfkit)"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# The functions named here are the ones create_tse.r calls, and a missing R
# dependency shows up as a load failure rather than at startup.
#
# The check is against getNamespaceExports(), not exists(where = asNamespace()):
# the latter finds internal objects too, so it passes for a function that the
# package defines but does not export -- which is exactly what happens when
# NAMESPACE is stale, and exactly the failure this test exists to catch. An
# unexported function then dies at run time with "not an exported object from
# 'namespace:vpfkit'", after the pipeline has done all its real work.
RUN env -i HOME=/tmp LANG=C.UTF-8 PATH=/app/.pixi/envs/default/bin:/usr/bin:/bin \
    bash -c 'Rscript -e "suppressMessages(library(vpfkit)); \
                         suppressMessages(library(TreeSummarizedExperiment)); \
                         suppressMessages(library(argparser)); \
                         need <- c(\"create_vpftse\", \"create_vpftse_vir\", \"annotate_viral_votes\", \
                                   \"read_taxonomy2\", \"read_coverm\"); \
                         miss <- setdiff(need, getNamespaceExports(\"vpfkit\")); \
                         if (length(miss)) stop(\"vpfkit does not export: \", paste(miss, collapse = \", \")); \
                         cat(\"vpfkit\", as.character(packageVersion(\"vpfkit\")), \"OK\n\")" && \
             ps -p 1 -o comm='

ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
