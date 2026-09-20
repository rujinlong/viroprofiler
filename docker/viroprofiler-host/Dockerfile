# ---------------------------------------------------------------------------
# ViroProfiler host prediction image (process label: viroprofiler_host)
#
# iPHoP is built from the hardened fork at github.com/rujinlong/iphop instead of
# the bioconda `iphop` package, which still ships three defects:
#
#   1. `perl-bioperl<=1.7` excludes every build bioconda actually publishes
#      (1.7.x), so the solver silently skipped the package and RaFAH crashed at
#      runtime with "Can't locate Bio/SeqIO.pm in @INC". The fork asks for
#      `perl-bioperl=1.7.*`.
#   2. `protobuf` is unpinned, so pip resolves 5.x and tensorflow 2.7 fails at
#      import with "TypeError: Descriptors cannot be created directly". The fork
#      pins `protobuf>=3.19,<4`.
#   3. The trained classifier models are tracked with Git LFS, so any plain
#      checkout yields ~130-byte pointer files instead of the real weights (see
#      the `COPY --from=` below for how that is worked around).
#
# ARCHITECTURE: linux/amd64 only, and pinned as such on purpose.
#   - tensorflow 2.7.0 and tensorflow-decision-forests 0.2.2 publish x86-64
#     Linux wheels only; no release of tensorflow-decision-forests has ever had
#     a linux-aarch64 wheel.
#   - blast 2.12, hmmer 3.3.2, scikit-learn 0.22 and r-ranger 0.13 have no
#     linux-aarch64 conda build, and perl-bioperl 1.7.x is unsatisfiable there.
# `docker/build_arm64.sh` therefore does not build this image and
# `conf/arm64_local.config` sets `use_iphop = false`. See docs/dev/ARM64.md.
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 mambaorg/micromamba:1.5.8-jammy

LABEL author="Jinlong Ru"
LABEL org.opencontainers.image.source="https://github.com/rujinlong/iphop"

# Source of the iPHoP fork. IPHOP_REF may be a tag, a branch or a commit SHA:
#   docker build --build-arg IPHOP_REF=v2.0.5 \
#       -f docker/viroprofiler-host/Dockerfile -t denglab/viroprofiler-host:vX .
ARG IPHOP_REPO=https://github.com/rujinlong/iphop.git
ARG IPHOP_REF=v2.0.4
LABEL org.opencontainers.image.revision="${IPHOP_REF}"

USER root

# Activate the base env for the RUN steps below.
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate a conda env: `iphop`,
# `seqkit` and `blastn` must be callable straight from `.command.sh`.
ENV PATH=/opt/conda/bin:$PATH
# Never smudge Git LFS objects during the checkout below; the classifier models
# are taken from the biocontainers image instead.
ENV GIT_LFS_SKIP_SMUDGE=1

# git for the checkout, build-essential for the legacy py3.8 pip wheels.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Fetch the fork at the pinned ref. `git init` + `git fetch` rather than
# `git clone --branch` so that IPHOP_REF may also be a bare commit SHA.
WORKDIR /opt/iphop
RUN git init -q . && \
    git remote add origin "${IPHOP_REPO}" && \
    git fetch -q --depth 1 origin "${IPHOP_REF}" && \
    git checkout -q FETCH_HEAD && \
    rm -rf .git

# One conda solve: the fork's own environment file plus the three extra specs this
# image needs on top of it. They are listed on the command line rather than in a
# second environment file because micromamba accepts only one YAML file per
# invocation ("Can only handle 1 yaml file!"), so `-f a.yml -f b.yml` is not an
# option; keep them here rather than reintroducing a yml that the build ignores.
#   typer      - the fork's CLI imports it; installed from conda-forge so it is
#                present before `pip install` has to resolve it
#   seqkit     - VIRALHOST_IPHOP reports its version in versions.yml
#   procps-ng  - `ps`, used by nextflow to collect per-task resource metrics
# blast, hmmer, prodigal, diamond, perl-bioperl, r-base/r-ranger and the pinned
# python 3.8 stack all come from iphop_environment.yml.
RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba install -n base -f iphop_environment.yml -c conda-forge \
        typer seqkit procps-ng --yes && \
    micromamba clean --all --yes

# iPHoP itself plus its pip-only dependencies (tensorflow 2.7.0,
# tensorflow-decision-forests 0.2.2, protobuf<4). The conda-installed
# dependencies (biopython, pandas, scikit-learn, joblib, ...) already satisfy
# the rest of the requirement set.
RUN --mount=type=cache,target=/root/.cache/pip \
    micromamba run -n base pip install --no-cache-dir .

# Overlay the trained classifier models from the bioconda iphop image.
#
# Why: the fork tracks the ~500 MB of Keras .h5 / TF SavedModel files under
# iphop/classifiers/ with Git LFS, so the checkout above holds ~130-byte LFS
# pointer files, and `pip install .` copies those pointers into site-packages.
# iPHoP's step-8 integrator then crashes at tf.saved_model.load() with
#   OSError: SavedModel file does not exist at: .../Model_blast_Conv-87.h5/...
# Instead of depending on Git LFS bandwidth at build time, the same directory is
# multi-stage-copied out of the original bioconda image: the model
# architectures match the fork (1.4.1 -> 2.0.0 is a Python refactor, not a model
# retrain) and bioconda ships the real weights inside the published image.
COPY --from=quay.io/biocontainers/iphop:1.4.1--pyhdfd78af_0 \
     /usr/local/lib/python3.8/site-packages/iphop/classifiers/ \
     /opt/conda/lib/python3.8/site-packages/iphop/classifiers/

# Fail the build fast if a representative model is still LFS-pointer-sized
# (a few hundred bytes) instead of the expected ~100 MB.
RUN test "$(stat -c%s /opt/conda/lib/python3.8/site-packages/iphop/classifiers/Model_blast_Conv-87.h5)" -gt 1000000 \
    || { echo "FATAL: classifiers/Model_blast_Conv-87.h5 is still a stub; multi-stage COPY did not land the real file"; exit 1; }

# Smoke test. Nextflow runs its `.command.sh` without activating a conda env, so
# every tool VIRALHOST_IPHOP calls has to work from PATH alone -- run the check
# in a stripped environment rather than the activated build shell.
# `iphop --help` also proves the package imports, which is how the process reads
# the iPHoP version.
RUN env -i HOME=/root LANG=C.UTF-8 PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c 'iphop --help > /dev/null && seqkit version && blastn -version && python -V'

# The fork's own Dockerfile ends with
#   ENTRYPOINT ["micromamba", "run", "-n", "base", "iphop"]
# and the mambaorg base image installs an env-activation entrypoint. Nextflow
# executes its own `.command.sh`, so neither may prefix the command: reset the
# entrypoint and rely on PATH.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
