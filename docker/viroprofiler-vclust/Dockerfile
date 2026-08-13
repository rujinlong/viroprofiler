# ---------------------------------------------------------------------------
# ViroProfiler Vclust image (process label: viroprofiler_vclust)
#
# Vclust dereplicates the pooled contig library: a Kmer-db prefilter narrows the
# candidate pairs, LZ-ANI aligns the survivors, and the clustering step applies
# the MIUViG containment rule. It replaces the all-vs-all `blastn` +
# `anicalc.py` + `aniclust.py` chain that used to live in the base image; see
# docs/dev/KNOWN_ISSUES.md I-32 for why that chain had to go.
#
# This is a separate image rather than an addition to `viroprofiler-base`
# because nothing else in the pipeline needs Vclust, and the base image is
# already the largest and most frequently rebuilt one.
#
# bioconda publishes `vclust` for linux-aarch64 as well as linux-64, so this
# image builds on both architectures without a source build.
# ---------------------------------------------------------------------------
FROM mambaorg/micromamba:1.5.8

LABEL author="Jinlong Ru"

USER root

# Activate the base env for the RUN steps below.
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because Nextflow does not activate a conda env: `vclust`,
# `seqkit`, `samtools` and `python3` must be callable straight from
# `.command.sh`.
ENV PATH=/opt/conda/bin:$PATH

COPY ./docker/viroprofiler-vclust/env_vclust.yml /tmp

RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba install -n base -f /tmp/env_vclust.yml -y

RUN micromamba clean --all --yes

# Smoke test. Nextflow runs its `.command.sh` without activating a conda env, so
# every tool CONTIGLIB_CLUSTER calls has to work from PATH alone -- run the
# check in a stripped environment rather than the activated build shell.
# `vclust info` also proves that the bundled kmer-db and lz-ani binaries are
# present and executable, which `vclust --version` alone does not.
RUN env -i HOME=/root LANG=C.UTF-8 PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c 'vclust --version && vclust info && seqkit version && samtools --version | head -1 && python3 -c "import sys; print(sys.version)"'

# The mambaorg base image installs an env-activation entrypoint. Nextflow
# executes its own `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
