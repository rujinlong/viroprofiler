# ---------------------------------------------------------------------------
# ViroProfiler vConTACT3 image (process labels: viroprofiler_vcontact3)
#
# vConTACT3 is installed from its Bitbucket source rather than from bioconda,
# for two reasons:
#
#   1. There is no `vcontact3` package on PyPI at all, and the bioconda package
#      is 3.0.3 while the source tree is 3.2.4.
#   2. The bioconda package cannot be solved on linux-aarch64: two of its
#      dependencies, `fastcluster` and `jenkspy`, have no linux-aarch64 conda
#      build. Both build from their PyPI sdists, so the pip route works on
#      aarch64 and amd64 alike -- which is why `build-essential` is installed
#      below.
#
# VCONTACT3_REF is a commit SHA on purpose: the project publishes no tags, so
# "latest" is the only alternative and it is not reproducible.
# ---------------------------------------------------------------------------
FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

ARG VCONTACT3_REPO=https://bitbucket.org/MAVERICLab/vcontact3.git
# vConTACT3 3.2.4
ARG VCONTACT3_REF=d57ae81e0be5ab57a8a14692a4cb8ab255ce2d52
LABEL org.opencontainers.image.revision="${VCONTACT3_REF}"

USER root

# Activate the base env for the RUN steps below.
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate a conda env: `vcontact3`,
# `mmseqs` and `seqkit` must be callable straight from `.command.sh`.
ENV PATH=/opt/conda/bin:$PATH

# git for the checkout pip performs, build-essential because `fastcluster` and
# `jenkspy` are compiled from their sdists (no aarch64 wheels for the versions
# vConTACT3 pins).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential ca-certificates git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY ./docker/viroprofiler-vcontact3/env_vcontact3.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba install -n base -f /tmp/env_vcontact3.yml -y

# vConTACT3 bundles pyrodigal and pyrodigal-gv, so no external gene caller is
# needed; the only external executable it looks up is `mmseqs` (plus `vclust`,
# which is optional and only gates the `ani` export that this pipeline does not
# request).
#
# `pandas<3` is not vConTACT3's own constraint: it declares `pandas>=2.1.1`, an
# open upper bound, so a fresh resolve installs pandas 3.x -- a major release
# published years after this commit, which changes copy-on-write and string
# dtype semantics throughout. This is the same trap that broke vConTACT2 in
# docker/viroprofiler-taxa/env_taxa.yml. Held at the 2.x series the upstream
# authors developed against.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir \
        "vcontact3 @ git+${VCONTACT3_REPO}@${VCONTACT3_REF}" \
        "pandas>=2.1.1,<3"

RUN micromamba clean --all --yes

# Smoke test. Nextflow runs its `.command.sh` without activating a conda env, so
# every tool TAXONOMY_VCONTACT3 calls has to work from PATH alone -- run the
# check in a stripped environment rather than the activated build shell.
# `vcontact3 version` also proves the package imports, which is how the process
# fills in versions.yml.
RUN env -i HOME=/root LANG=C.UTF-8 PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c 'vcontact3 version && vcontact3 --help > /dev/null && mmseqs version && diamond --version && seqkit version'

# The mambaorg base image installs an env-activation entrypoint. Nextflow
# executes its own `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
