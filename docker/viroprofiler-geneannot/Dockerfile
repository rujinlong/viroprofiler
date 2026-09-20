# ---------------------------------------------------------------------------
# ViroProfiler gene-annotation image (process label: viroprofiler_geneannot)
#
# Built from a committed lockfile for the conda side; DRAM comes from PyPI, for
# the reason given in pixi.toml. See docs/dev/PACKAGING.md.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

WORKDIR /app

COPY ./docker/viroprofiler-geneannot/pixi.toml ./docker/viroprofiler-geneannot/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked -e dram -e emapper -e abricate

# Nextflow does not activate an environment: it writes a `.command.sh` and runs
# it, so every tool must resolve from PATH alone.
ENV PATH=/app/.pixi/envs/dram/bin:/app/.pixi/envs/emapper/bin:/app/.pixi/envs/abricate/bin:$PATH

# DRAM, from the same sdist bioconda builds its package from. `--no-deps`
# because pixi.lock already provides the dependency set that solves on both
# platforms; letting pip resolve them would pull PyPI copies over the conda ones.
ARG DRAM_VERSION=1.4.6
RUN --mount=type=cache,target=/root/.cache/pip \
    /app/.pixi/envs/dram/bin/pip install --no-cache-dir --no-deps "DRAM-bio==${DRAM_VERSION}"

# DRAM 1.4.6 downloads all three dbCAN files from `bcb.unl.edu`. That host now
# answers every path below /dbCAN2/download/ with HTTP 200 and the dbCAN landing
# page, so `urlretrieve` silently stores an HTML document where the HMM profiles
# and the CAZy family descriptions should be. The files are still published,
# unchanged, from `pro.unl.edu`; only the host moved. This has to be patched in
# the installed library rather than passed at run time: `prepare_databases`
# builds its list of user-supplied files from the arguments whose names end in
# `_loc`, and neither `dbcan_fam_activities` nor `dbcan_subfam_ec` does.
RUN DRAM_DB_PROCESSING="$(/app/.pixi/envs/dram/bin/python -c 'import mag_annotator.database_processing as m; print(m.__file__)')" \
    && sed -i -E 's|https?://bcb\.unl\.edu/dbCAN2/|https://pro.unl.edu/dbCAN2/|g' "$DRAM_DB_PROCESSING" \
    && grep -q 'https://pro.unl.edu/dbCAN2/download/dbCAN-HMMdb-V' "$DRAM_DB_PROCESSING" \
    && ! grep -q 'bcb\.unl\.edu' "$DRAM_DB_PROCESSING"

# VOGDB used to ship `vog.hmm.tar.gz` with its 49116 profiles at the root of the
# archive and now nests them in `hmm/`, but `process_vogdb` still globs only the
# top level. It therefore concatenates nothing, writes an empty
# `vog_latest_hmms.txt`, and `hmmpress` stops with "File exists, but appears to
# be empty?" -- two hours into the build, after Pfam. Make the glob recursive.
RUN DRAM_DB_PROCESSING="$(/app/.pixi/envs/dram/bin/python -c 'import mag_annotator.database_processing as m; print(m.__file__)')" \
    && sed -i -E "s|glob\(path\.join\(hmm_dir, 'VOG\*\.hmm'\)\)|glob(path.join(hmm_dir, '**', 'VOG*.hmm'), recursive=True)|" \
        "$DRAM_DB_PROCESSING" \
    && grep -q "glob(path.join(hmm_dir, '\*\*', 'VOG\*.hmm'), recursive=True)" "$DRAM_DB_PROCESSING"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
RUN env -i HOME=/tmp LANG=C.UTF-8 \
        PATH=/app/.pixi/envs/dram/bin:/app/.pixi/envs/emapper/bin:/app/.pixi/envs/abricate/bin:/usr/bin:/bin \
    bash -c 'DRAM-v.py -h > /dev/null && DRAM-setup.py -h > /dev/null && \
             emapper.py --version > /dev/null && abricate --version && \
             mmseqs version && hmmsearch -h > /dev/null && prodigal -v 2>&1 | head -2 > /dev/null && \
             ps -p 1 -o comm='

# The pixi base image sets an entrypoint. Nextflow executes its own
# `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
