# ---------------------------------------------------------------------------
# ViroProfiler geNomad image (process labels: viroprofiler_genomad)
#
# geNomad replaces DeepVirFinder as the reference-free virus caller. Unlike
# DeepVirFinder -- whose theano 1.0.3 / keras 2.2.4 pin has no linux-aarch64
# build in any version -- every geNomad dependency is available for aarch64, so
# this image builds on both architectures from the same recipe.
#
# The version is pinned because geNomad refuses to run against a database built
# for a different major version of its marker set; DB_GENOMAD downloads the
# matching release.
# ---------------------------------------------------------------------------
FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

USER root

# Activate the base env for the RUN steps below.
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because Nextflow does not activate a conda env: `genomad`
# and the tools it shells out to must be callable straight from `.command.sh`.
ENV PATH=/opt/conda/bin:$PATH

COPY ./docker/viroprofiler-genomad/env_genomad.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba install -n base -f /tmp/env_genomad.yml -y

RUN micromamba clean --all --yes

# Smoke test in a stripped environment: Nextflow runs `.command.sh` without
# activating a conda env, so everything the GENOMAD and DB_GENOMAD processes
# call has to resolve from PATH alone.
RUN env -i HOME=/root LANG=C.UTF-8 PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c 'genomad --version && genomad end-to-end --help > /dev/null && \
             mmseqs version && command -v aragorn && seqkit version && csvtk version'

# The mambaorg base image installs an env-activation entrypoint. Nextflow
# executes its own `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
