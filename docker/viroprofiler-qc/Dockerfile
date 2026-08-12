FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

# Read QC, trimming, assembly and reporting. The vendored nf-core modules point at
# quay.io/biocontainers images, which exist for amd64 only; this image provides the same
# tools for any architecture bioconda builds for.

USER root

ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate base env by default.
ENV PATH=/opt/conda/bin:$PATH

COPY ./docker/viroprofiler-qc/env_qc.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_qc.yml -y

RUN micromamba clean --all --yes
