FROM mambaorg/micromamba:0.25.1

LABEL author="Jinlong Ru"

# DeepVirFinder only. It is kept out of the binning image because its dependency set
# (theano 1.0.3 + keras 2.2.4) is frozen to 2018 and has no linux-aarch64 build, so bundling
# it made the whole binning image unbuildable on arm64.

USER root

ARG MAMBA_DOCKERFILE_ACTIVATE=1
ENV PATH=/opt/conda/bin:$PATH

COPY ./docker/viroprofiler-dvf/env_dvf.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_dvf.yml -y

RUN micromamba clean --all --yes
