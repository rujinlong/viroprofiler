FROM mambaorg/micromamba:0.25.1

LABEL author="Jinlong Ru"

USER root

# Activate conda env during docker build
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set PATH manually, because nextflow doesn't activate base env by default.
ENV PATH=/opt/conda/bin:/opt/conda/envs/viroprofiler-emapper/bin:/opt/conda/envs/viroprofiler-abricate/bin:$PATH

COPY ./docker/viroprofiler-geneannot/env_*.yml /tmp

# Install DRAM's dependencies into the `base` env, then DRAM itself from PyPI.
# DRAM is not taken from bioconda because its 1.4.6 packages cannot be solved on
# linux-aarch64; see the comments in env_dram.yml. bioconda builds that package from the
# very same `DRAM-bio` sdist, so this installs identical code.
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_dram.yml -y
RUN pip install --no-cache-dir --no-deps DRAM-bio==1.4.6

# DRAM 1.4.6 downloads all three dbCAN files from `bcb.unl.edu`. That host now answers
# every path below /dbCAN2/download/ with HTTP 200 and the dbCAN landing page, so
# `urlretrieve` silently stores an HTML document where the HMM profiles and the CAZy family
# descriptions should be. The files are still published, unchanged, from `pro.unl.edu`; only
# the host moved, so rewrite it. This has to be done in the installed library rather than
# passed in at run time: `prepare_databases` builds its list of user-supplied files from the
# arguments whose names end in `_loc`, and neither `dbcan_fam_activities` nor
# `dbcan_subfam_ec` does, so `--dbcan_fam_activities` is silently ignored and the sub-family
# EC file has no command-line option at all.
RUN DRAM_DB_PROCESSING="$(python -c 'import mag_annotator.database_processing as m; print(m.__file__)')" \
    && sed -i -E 's|https?://bcb\.unl\.edu/dbCAN2/|https://pro.unl.edu/dbCAN2/|g' "$DRAM_DB_PROCESSING" \
    && grep -q 'https://pro.unl.edu/dbCAN2/download/dbCAN-HMMdb-V' "$DRAM_DB_PROCESSING" \
    && ! grep -q 'bcb\.unl\.edu' "$DRAM_DB_PROCESSING"

# Install emapper to `viroprofiler_emapper` env
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba create -f /tmp/env_emapper.yml -y

# Installl abricate to `viroprofiler_abricate` env
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba create -f /tmp/env_abricate.yml -y

RUN micromamba clean --all --yes
