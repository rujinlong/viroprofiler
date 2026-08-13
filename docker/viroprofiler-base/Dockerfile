# ---------------------------------------------------------------------------
# ViroProfiler base image (process label: viroprofiler_base)
#
# Built from a committed lockfile: `pixi install --locked` refuses to build if
# pixi.lock does not match pixi.toml. See docs/dev/PACKAGING.md.
#
# Three prefixes on one PATH, in the order below. That order is load-bearing:
# GENEPRED, MICOMPLETEDB and VOGDB call `prodigal-gv` and `hmmsearch` by bare
# name and get CheckV's copies, because the base environment declares neither.
# pixi.toml says more about why they are left there.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

WORKDIR /app

COPY ./docker/viroprofiler-base/pixi.toml ./docker/viroprofiler-base/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked -e base -e checkv -e virsorter2

# Nextflow does not activate an environment: it writes a `.command.sh` and runs
# it, so every tool must resolve from PATH alone.
ENV PATH=/app/.pixi/envs/base/bin:/app/.pixi/envs/checkv/bin:/app/.pixi/envs/virsorter2/bin:$PATH

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# prodigal-gv and hmmsearch are asserted to come from the checkv prefix: if a
# future edit adds them to the base environment they would silently take over
# CheckV's own internal calls as well.
RUN env -i HOME=/tmp LANG=C.UTF-8 \
        PATH=/app/.pixi/envs/base/bin:/app/.pixi/envs/checkv/bin:/app/.pixi/envs/virsorter2/bin:/usr/bin:/bin \
    bash -c 'checkv -h > /dev/null && seqkit version && samtools --version | head -1 && \
             blastn -version | head -1 && mmseqs version && csvtk version && \
             coverm --version && pigz --version && bbversion.sh > /dev/null && \
             python -c "import pandas, click, Bio" && \
             test "$(command -v prodigal-gv)" = /app/.pixi/envs/checkv/bin/prodigal-gv && \
             test "$(command -v hmmsearch)"   = /app/.pixi/envs/checkv/bin/hmmsearch && \
             ps -p 1 -o comm='

# The pixi base image sets an entrypoint. Nextflow executes its own
# `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
