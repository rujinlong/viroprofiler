# ---------------------------------------------------------------------------
# ViroProfiler CheckAMG image (process label: viroprofiler_checkamg)
#
# CheckAMG curates auxiliary genes -- AMGs, AReGs and APGs -- from functional
# annotation plus genomic context. The conda side is locked; CheckAMG and torch
# come from PyPI, for the reasons in pixi.toml. See docs/dev/PACKAGING.md.
#
# One thing about this recipe is load-bearing beyond the torch ordering below:
# CheckAMG drives its own Snakemake workflow by shelling out to a bare
# `snakemake` command, so `snakemake` must be on PATH, not merely importable.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

# CheckAMG requires Python >= 3.11; the interpreter is pinned in pixi.toml.
ARG CHECKAMG_VERSION=1.1.1
# torch is installed ahead of CheckAMG for the reason given below; the version
# is the one CheckAMG's own dependency solve lands on.
ARG TORCH_VERSION=2.8.0
LABEL org.opencontainers.image.version="${CHECKAMG_VERSION}"

WORKDIR /app

COPY ./docker/viroprofiler-checkamg/pixi.toml ./docker/viroprofiler-checkamg/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked

ENV PATH=/app/.pixi/envs/default/bin:$PATH

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
    /app/.pixi/envs/default/bin/pip install --no-cache-dir \
        --index-url https://download.pytorch.org/whl/cpu \
        "torch==${TORCH_VERSION}"

RUN --mount=type=cache,target=/root/.cache/pip \
    /app/.pixi/envs/default/bin/pip install --no-cache-dir --no-build-isolation "torch_scatter==2.1.2"

RUN --mount=type=cache,target=/root/.cache/pip \
    /app/.pixi/envs/default/bin/pip install --no-cache-dir "checkamg==${CHECKAMG_VERSION}"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# `snakemake --version` is not decoration -- a missing `snakemake` on PATH is
# exactly how `checkamg annotate` fails, and it fails deep inside the run rather
# than at startup.
RUN env -i HOME=/tmp LANG=C.UTF-8 PATH=/app/.pixi/envs/default/bin:/usr/bin:/bin \
    bash -c 'checkamg --version && checkamg annotate --help > /dev/null && snakemake --version && ps -p 1 -o comm='

ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
