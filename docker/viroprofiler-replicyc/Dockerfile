# ---------------------------------------------------------------------------
# ViroProfiler replication-cycle image (process labels: viroprofiler_replicyc)
#
# Built from a committed lockfile: `pixi install --locked` refuses to build if
# pixi.lock does not match pixi.toml, so the image can only contain the package
# set that was tested. See docs/dev/PACKAGING.md.
#
# Two environments, one per tool, for the dependency conflict documented in
# pixi.toml. They coexist on one PATH because each console script carries an
# absolute shebang into its own interpreter -- `bacphlip` runs under its Python
# 3.8 even though `python` on PATH is Replidec's 3.10.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

WORKDIR /app

COPY ./docker/viroprofiler-replicyc/pixi.toml ./docker/viroprofiler-replicyc/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked -e replidec -e bacphlip

# Nextflow does not activate an environment: it writes a `.command.sh` and runs
# it, so every tool must resolve from PATH alone.
ENV PATH=/app/.pixi/envs/replidec/bin:/app/.pixi/envs/bacphlip/bin:$PATH

# The Replidec reference database, which no lockfile covers. Located through the
# environment's own interpreter rather than a bare `python3`, which on PATH is
# whichever environment comes first.
RUN REPLIDEC_DIR="$(/app/.pixi/envs/replidec/bin/python -c 'import site; print(site.getsitepackages()[0])')/Replidec" && \
    cd "$REPLIDEC_DIR" && \
    wget -q https://zenodo.org/record/6975142/files/db_v0.2.3.tar.gz && \
    tar xzf db_v0.2.3.tar.gz && \
    rm db_v0.2.3.tar.gz && \
    test -d "$REPLIDEC_DIR/db"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# `ps` is checked because Nextflow's trace observer calls it.
RUN env -i HOME=/tmp LANG=C.UTF-8 \
        PATH=/app/.pixi/envs/replidec/bin:/app/.pixi/envs/bacphlip/bin:/usr/bin:/bin \
    bash -c 'Replidec -h > /dev/null && bacphlip -h > /dev/null && mmseqs version && ps -p 1 -o comm='

# The pixi base image sets an entrypoint. Nextflow executes its own
# `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
