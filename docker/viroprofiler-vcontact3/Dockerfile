# ---------------------------------------------------------------------------
# ViroProfiler vConTACT3 image (process label: viroprofiler_vcontact3)
#
# vConTACT3 is installed from its Bitbucket source rather than from bioconda,
# for two reasons:
#
#   1. There is no `vcontact3` package on PyPI at all, and the bioconda package
#      is 3.0.3 while the source tree is 3.2.4.
#   2. The bioconda package cannot be solved on linux-aarch64: two of its
#      dependencies, `fastcluster` and `jenkspy`, have no linux-aarch64 conda
#      build. Both build from their PyPI sdists, which is why `build-essential`
#      is installed below.
#
# VCONTACT3_REF is a commit SHA on purpose: the project publishes no tags, so
# "latest" is the only alternative and it is not reproducible.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

ARG VCONTACT3_REPO=https://bitbucket.org/MAVERICLab/vcontact3.git
# vConTACT3 3.2.4
ARG VCONTACT3_REF=d57ae81e0be5ab57a8a14692a4cb8ab255ce2d52
LABEL org.opencontainers.image.revision="${VCONTACT3_REF}"

# git for the checkout pip performs, build-essential because `fastcluster` and
# `jenkspy` are compiled from their sdists.
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential ca-certificates git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./docker/viroprofiler-vcontact3/pixi.toml ./docker/viroprofiler-vcontact3/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked

ENV PATH=/app/.pixi/envs/default/bin:$PATH

# vConTACT3 bundles pyrodigal and pyrodigal-gv, so no external gene caller is
# needed; the only external executable it looks up is `mmseqs` (plus `vclust`,
# which is optional and only gates an export this pipeline does not request).
#
# `pandas<3` is not vConTACT3's own constraint: it declares `pandas>=2.1.1`, an
# open upper bound, so a fresh resolve installs pandas 3.x -- a major release
# published years after this commit, which changes copy-on-write and string
# dtype semantics throughout. Held at the 2.x series the authors developed
# against.
RUN --mount=type=cache,target=/root/.cache/pip \
    /app/.pixi/envs/default/bin/pip install --no-cache-dir \
        "vcontact3 @ git+${VCONTACT3_REPO}@${VCONTACT3_REF}" \
        "pandas>=2.1.1,<3"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# `vcontact3 version` also proves the package imports, which is how the process
# fills in versions.yml.
RUN env -i HOME=/tmp LANG=C.UTF-8 PATH=/app/.pixi/envs/default/bin:/usr/bin:/bin \
    bash -c 'vcontact3 version && vcontact3 --help > /dev/null && mmseqs version && \
             diamond --version && seqkit version && ps -p 1 -o comm='

ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
