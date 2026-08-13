# ---------------------------------------------------------------------------
# ViroProfiler VITAP image (process labels: viroprofiler_vitap)
#
# VITAP -- the VIral TAxonomic Assignment Pipeline, Zheng et al., Nat Commun 16,
# 2226 (2025) -- classifies viral contigs down to species by scoring them
# against ICTV reference genomes on a multipartite graph.
#
# Version: 1.7.1, and deliberately not the newer 1.10/1.11/1.12.
#
#   From 1.10 onwards VITAP folds UniRef90 into the assignment, and upstream
#   withdrew the pre-built databases as a result ("Because UniRef90 has been
#   integrated, prebuilt databases are no longer provided", README of v.1.12).
#   `VITAP assignment` in 1.12 then runs `diamond blastp` against
#   `<db>/uniref90.dmnd` with `check=True` and no way to skip it, so building
#   that database is mandatory -- and `VITAP upd` builds it by downloading the
#   whole UniRef90 FASTA (~200 GB unpacked) plus every VMR genome from GenBank,
#   pausing halfway on a blocking `input()` prompt that asks the operator to
#   hand-correct the VMR table. None of that can be a `--mode setup` process.
#
#   1.7.1 is the last release whose database is published, checksummed and
#   downloadable in one piece, which is what DB_VITAP installs. Its assignment
#   needs nothing but that directory. When upstream publishes a UniRef90-era
#   database, moving up is a version bump here plus a new URL in DB_VITAP:
#   `read_vitap` in bin/merge_taxonomy.py already accepts both spellings of the
#   score column that 1.7 and 1.12 write.
#
# VITAP_REF is a commit SHA on purpose: it is the commit tag `v.1.7.1` points at
# today, pinned so that a moved tag cannot silently change the image.
# ---------------------------------------------------------------------------
FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

ARG VITAP_REPO=https://github.com/DrKaiyangZheng/VITAP.git
# VITAP v.1.7.1
ARG VITAP_REF=7375c7ba5f2f749dfb7b902e1fafbf93d38a3290
LABEL org.opencontainers.image.revision="${VITAP_REF}"

USER root

# Activate the base env for the RUN steps below.
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate a conda env: `VITAP`,
# `diamond`, `prodigal` and `seqkit` must be callable straight from
# `.command.sh`.
ENV PATH=/opt/conda/bin:$PATH

# git for the checkout pip performs.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY ./docker/viroprofiler-vitap/env_vitap.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba install -n base -f /tmp/env_vitap.yml -y

# `--no-deps` is required, not an optimisation: VITAP's setup.py lists
# `entrez-direct`, `seqkit`, `prodigal` and `diamond` in `install_requires`, and
# none of those is a PyPI distribution -- resolving them fails. The Python
# libraries VITAP actually imports (pandas, numpy, networkx, biopython, tqdm)
# come from env_vitap.yml instead.
#
# The package installs no importable module: `scripts=[...]` in setup.py drops
# `VITAP` (a shell wrapper), `VITAP_assignment_20241007.py` and
# `VITAP_upd_20241007.py` side by side into the environment's bin directory, and
# the wrapper resolves its siblings through its own `$BASH_SOURCE` directory.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --no-deps \
        "VITAP @ git+${VITAP_REPO}@${VITAP_REF}"

RUN micromamba clean --all --yes

# Smoke test. Nextflow runs its `.command.sh` without activating a conda env, so
# every tool TAXONOMY_VITAP calls has to work from PATH alone -- run the check in
# a stripped environment rather than the activated build shell. `VITAP
# assignment -h` also proves the assignment script imports, which is what fails
# if a Python dependency is missing from env_vitap.yml.
RUN env -i HOME=/root LANG=C.UTF-8 PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c 'VITAP --help > /dev/null && VITAP assignment -h > /dev/null && diamond version && prodigal -v && seqkit version && wget --version | head -n 1 && unzip -v | head -n 1'

# The mambaorg base image installs an env-activation entrypoint. Nextflow
# executes its own `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
