# ---------------------------------------------------------------------------
# ViroProfiler CheckAMG image (process labels: viroprofiler_checkamg)
#
# CheckAMG curates auxiliary genes -- AMGs, AReGs and APGs -- from functional
# annotation plus genomic context. It is installed from PyPI because there is no
# conda package; every dependency resolves on linux-aarch64 as well as amd64.
#
# Two things about this recipe are load-bearing:
#
#   1. CheckAMG drives its own Snakemake workflow by shelling out to a bare
#      `snakemake` command, so `snakemake` must be on PATH, not merely
#      importable. Installing into the base conda prefix puts it in
#      /opt/conda/bin alongside `checkamg`, which is already on PATH.
#   2. `ptn-set-transformer` pulls in torch, and through it `torch_scatter`.
#      Only `checkamg de-novo` uses either, and this pipeline runs `checkamg
#      annotate`, but they are hard dependencies of the distribution and the CLI
#      imports them at startup -- so they cannot be dropped, and this image is
#      correspondingly large.
# ---------------------------------------------------------------------------
FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

# CheckAMG requires Python >= 3.11; pinned so a rebuild cannot silently move to
# an interpreter its wheels were never tested against.
ARG CHECKAMG_VERSION=1.1.1
# torch is installed ahead of CheckAMG for the reason given below; the version
# is the one CheckAMG's own dependency solve lands on.
ARG TORCH_VERSION=2.8.0
LABEL org.opencontainers.image.version="${CHECKAMG_VERSION}"

USER root

ARG MAMBA_DOCKERFILE_ACTIVATE=1
ENV PATH=/opt/conda/bin:$PATH

COPY ./docker/viroprofiler-checkamg/env_checkamg.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba install -n base -f /tmp/env_checkamg.yml -y

# torch first, and from PyTorch's CPU index rather than PyPI. Two reasons:
#
#   * PyPI's default linux-aarch64 torch wheel is the CUDA build, which drags in
#     ~4 GB of `nvidia-*` wheels. Nothing this pipeline runs uses a GPU, and the
#     CPU wheel is 102 MB.
#   * `torch_scatter` ships no aarch64 wheel, so pip compiles it from its sdist
#     -- and its `setup.py` does `import torch` at build time. Under pip's
#     default build isolation that import fails ("No module named 'torch'"),
#     which is how a plain `pip install checkamg` dies on this platform. Hence
#     torch up front, and `--no-build-isolation` for the compile.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir \
        --index-url https://download.pytorch.org/whl/cpu \
        "torch==${TORCH_VERSION}"

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --no-build-isolation "torch_scatter==2.1.2"

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir "checkamg==${CHECKAMG_VERSION}"

RUN micromamba clean --all --yes

# Smoke test in a stripped environment, for the same reason as the other
# images: `.command.sh` runs with no conda activation. `snakemake --version` is
# not decoration -- a missing `snakemake` on PATH is exactly how `checkamg
# annotate` fails, and it fails deep inside the run rather than at startup.
RUN env -i HOME=/root LANG=C.UTF-8 PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c 'checkamg --version && checkamg annotate --help > /dev/null && snakemake --version'

ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
