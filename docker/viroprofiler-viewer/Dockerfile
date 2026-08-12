FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

# R runtime for RESULTS_TSE (bin/create_tse.r), which builds the final
# TreeSummarizedExperiment object with vpfkit.
#
# The image published as denglab/viroprofiler-viewer:v0.2 had no Dockerfile in this
# repository, so it could neither be audited nor rebuilt. This recipe replaces it.

USER root

ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate base env by default.
ENV PATH=/opt/conda/bin:$PATH

COPY ./docker/viroprofiler-viewer/env_viewer.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_viewer.yml -y

# vpfkit is not on conda; install it from GitHub against the environment above.
ARG VPFKIT_REF=main
RUN R -e "remotes::install_github('deng-lab/vpfkit', ref = '${VPFKIT_REF}', upgrade = 'never', dependencies = FALSE)" && \
    R -e "library(vpfkit)"

RUN micromamba clean --all --yes
