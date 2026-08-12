FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

# VirSorter2 is installed from bioconda rather than from git master. The recipe pins the
# dependency versions VirSorter2 2.2.4 actually works with -- notably snakemake, whose
# top-level `load_configfile` was removed in snakemake 8, which breaks `virsorter setup`
# with an ImportError.

USER root

# Activate conda env during docker build
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate base env by default.
ENV PATH=/opt/conda/bin:$PATH

# Copy conda env files
COPY ./docker/viroprofiler-virsorter2/env_virsorter2.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_virsorter2.yml -y

RUN micromamba clean --all --yes
