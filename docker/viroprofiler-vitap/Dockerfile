# ---------------------------------------------------------------------------
# ViroProfiler VITAP image (process label: viroprofiler_vitap)
#
# VITAP -- the VIral TAxonomic Assignment Pipeline, Zheng et al., Nat Commun 16,
# 2226 (2025) -- classifies viral contigs down to species by scoring them
# against ICTV reference genomes on a multipartite graph.
#
# Version 1.7.1, and deliberately not the newer 1.10/1.11/1.12. From 1.10
# onwards VITAP folds UniRef90 into the assignment and upstream withdrew the
# pre-built databases as a result, so `VITAP assignment` then requires a
# `uniref90.dmnd` that only `VITAP upd` can build -- by downloading the whole
# UniRef90 FASTA (~200 GB unpacked) plus every VMR genome from GenBank, pausing
# halfway on a blocking `input()` prompt. None of that can be a `--mode setup`
# process. 1.7.1 is the last release whose database is published, checksummed
# and downloadable in one piece, which is what DB_VITAP installs.
#
# VITAP_REF is a commit SHA on purpose: it is the commit tag `v.1.7.1` points at
# today, pinned so that a moved tag cannot silently change the image.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

ARG VITAP_REPO=https://github.com/DrKaiyangZheng/VITAP.git
# VITAP v.1.7.1
ARG VITAP_REF=7375c7ba5f2f749dfb7b902e1fafbf93d38a3290
LABEL org.opencontainers.image.revision="${VITAP_REF}"

# git for the checkout pip performs.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./docker/viroprofiler-vitap/pixi.toml ./docker/viroprofiler-vitap/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked

ENV PATH=/app/.pixi/envs/default/bin:$PATH

# `--no-deps` is required, not an optimisation: VITAP's setup.py lists
# `entrez-direct`, `seqkit`, `prodigal` and `diamond` in `install_requires`, and
# none of those is a PyPI distribution -- resolving them fails. The Python
# libraries VITAP actually imports come from pixi.lock instead.
#
# The package installs no importable module: `scripts=[...]` in setup.py drops
# `VITAP` (a shell wrapper), `VITAP_assignment_20241007.py` and
# `VITAP_upd_20241007.py` side by side into the environment's bin directory, and
# the wrapper resolves its siblings through its own `$BASH_SOURCE` directory.
RUN --mount=type=cache,target=/root/.cache/pip \
    /app/.pixi/envs/default/bin/pip install --no-cache-dir --no-deps \
        "VITAP @ git+${VITAP_REPO}@${VITAP_REF}"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# `VITAP assignment -h` also proves the assignment script imports, which is what
# fails if a Python dependency is missing from pixi.toml.
RUN env -i HOME=/tmp LANG=C.UTF-8 PATH=/app/.pixi/envs/default/bin:/usr/bin:/bin \
    bash -c 'VITAP --help > /dev/null && VITAP assignment -h > /dev/null && \
             diamond version && prodigal -v 2>&1 | head -2 > /dev/null && seqkit version && \
             wget --version | head -n 1 && unzip -v | head -n 1 && ps -p 1 -o comm='

ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
