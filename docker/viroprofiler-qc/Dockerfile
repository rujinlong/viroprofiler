# ---------------------------------------------------------------------------
# ViroProfiler QC image (FASTQC, FASTP, SPADES, MULTIQC)
#
# The vendored nf-core modules point at quay.io/biocontainers images, which
# exist for amd64 only; conf/arm64_local.config redirects those four processes
# here.
#
# Built from a committed lockfile: `pixi install --locked` refuses to build if
# pixi.lock does not match pixi.toml. See docs/dev/PACKAGING.md.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

WORKDIR /app

COPY ./docker/viroprofiler-qc/pixi.toml ./docker/viroprofiler-qc/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked

# Nextflow does not activate an environment: it writes a `.command.sh` and runs
# it, so every tool must resolve from PATH alone.
ENV PATH=/app/.pixi/envs/default/bin:$PATH

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# `ps` is checked because Nextflow's trace observer calls it.
RUN env -i HOME=/tmp LANG=C.UTF-8 PATH=/app/.pixi/envs/default/bin:/usr/bin:/bin \
    bash -c 'fastqc --version && fastp --version 2>&1 | head -1 && spades.py --version && multiqc --version && ps -p 1 -o comm='

# The pixi base image sets an entrypoint. Nextflow executes its own
# `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
