FROM mambaorg/micromamba:0.25.1

LABEL author="Jinlong Ru"

USER root

# Activate conda env during docker build
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate base env by default.
ENV PATH=/opt/conda/bin:/opt/conda/envs/viroprofiler-emapper/bin:/opt/conda/envs/viroprofiler-abricate/bin:$PATH

COPY ./docker/viroprofiler-geneannot/env_*.yml /tmp

# Install DRAM's dependencies into the `base` env, then DRAM itself from PyPI.
# DRAM is not taken from bioconda because its 1.4.6 packages cannot be solved on
# linux-aarch64; see the comments in env_dram.yml. bioconda builds that package from the
# very same `DRAM-bio` sdist, so this installs identical code.
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_dram.yml -y
RUN pip install --no-cache-dir --no-deps DRAM-bio==1.4.6

# Install emapper to `viroprofiler_emapper` env
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba create -f /tmp/env_emapper.yml -y

# Installl abricate to `viroprofiler_abricate` env
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba create -f /tmp/env_abricate.yml -y

RUN micromamba clean --all --yes
