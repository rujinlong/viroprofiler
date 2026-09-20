# ---------------------------------------------------------------------------
# ViroProfiler binning image (process label: viroprofiler_binning)
#
# Built from a committed lockfile: `pixi install --locked` refuses to build if
# pixi.lock does not match pixi.toml. See docs/dev/PACKAGING.md.
#
# VAMB is installed only on amd64. It has no linux-aarch64 build (see
# pixi.toml), so on arm64 this image carries vRhyme and PHAMB's scoring code but
# not the clusterer PHAMB needs -- which is why `--binning phamb` is refused on
# aarch64 before any process is submitted.
# ---------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:66ae514a4421ca06587291beb037e5151b1b280a4f54eed82f57e9b70b94d5ca

LABEL author="Jinlong Ru"

# git, because phamb is a git source in [pypi-dependencies] and pixi shells out to
# `git` to fetch it. The pixi base image ships neither git nor curl.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./docker/viroprofiler-binning/pixi.toml ./docker/viroprofiler-binning/pixi.lock /app/

RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked -e binning

# BuildKit sets TARGETARCH. The vamb environment is declared for linux-64 only,
# so installing it on arm64 would fail the build rather than skip the feature.
ARG TARGETARCH
RUN --mount=type=cache,target=/root/.cache/rattler \
    if [ "$TARGETARCH" = "amd64" ]; then pixi install --locked -e vamb; \
    else echo "TARGETARCH=$TARGETARCH: skipping VAMB, which has no aarch64 build"; fi

# Nextflow does not activate an environment: it writes a `.command.sh` and runs
# it, so every tool must resolve from PATH alone. The vamb entry is absent on
# arm64 and a missing PATH element is harmless.
#
# Defined once and reused by the smoke tests below. A smoke test that searches a
# different PATH than the image exports proves nothing about the image: the
# run_RF.py wrapper installed below only wins because /usr/local/bin comes first
# here, and testing it under any other order would pass while the real run took
# the shadowed script.
ENV VP_PATH=/usr/local/bin:/app/.pixi/envs/binning/bin:/app/.pixi/envs/vamb/bin
ENV PATH=$VP_PATH:$PATH

# phamb ships `run_RF.py` as a plain script and loads its random forest from
# `Path(__file__).parent/"dbs"`. Copying the script onto PATH -- which is what
# this image used to do -- therefore makes it look for the model beside the copy,
# where there is no `dbs/`, and it dies in joblib.load(). Install a wrapper that
# executes the file in its installed location instead, so `__file__` still
# resolves next to the model.
RUN RF="$(/app/.pixi/envs/binning/bin/python -c 'import phamb, pathlib; print(pathlib.Path(phamb.__file__).parent / "run_RF.py")')" && \
    test -f "$RF" && \
    test -f "$(dirname "$RF")/dbs/RF_model.python39.sav" && \
    printf '#!/bin/sh\nexec /app/.pixi/envs/binning/bin/python %s "$@"\n' "$RF" > /usr/local/bin/run_RF.py && \
    chmod +x /usr/local/bin/run_RF.py && \
    test ! -e /app/.pixi/envs/binning/bin/dbs/RF_model.python39.sav

# The vRhyme machine-learning model, which the conda package does not ship.
# Pinned to a commit rather than `master`, so a rebuild cannot silently pick up
# a different model than the one this pipeline was tested with.
ARG VRHYME_REF=2d9e75812647ea055d363b86d1b2540a0c813716
ARG VRHYME_MODEL_SHA256=b293526ccf0bb550a654d6b3e0a99b3715a853e4a8d200b618faeb885f4b172f
RUN VRHYME_MODELS="$(/app/.pixi/envs/binning/bin/python -c 'import vRhyme, pathlib; print(pathlib.Path(vRhyme.__file__).parent / "models")')" && \
    wget -q -O /tmp/model.sav.gz \
        "https://github.com/AnantharamanLab/vRhyme/raw/${VRHYME_REF}/vRhyme/models/vRhyme_machine_model_ET.sav.gz" && \
    echo "${VRHYME_MODEL_SHA256}  /tmp/model.sav.gz" | sha256sum -c - && \
    gunzip -c /tmp/model.sav.gz > "${VRHYME_MODELS}/vRhyme_machine_model_ET.sav" && \
    rm /tmp/model.sav.gz && \
    test -s "${VRHYME_MODELS}/vRhyme_machine_model_ET.sav"

# Smoke test in a stripped environment, because that is how `.command.sh` runs.
# Loading the random forest is checked explicitly: a model that cannot be
# deserialised by the installed scikit-learn fails deep inside PHAMB_RF
# otherwise, after VAMB has already run.
RUN env -i HOME=/tmp LANG=C.UTF-8 PATH=$VP_PATH:/usr/bin:/bin \
    bash -c 'vRhyme --version && \
             jgi_summarize_bam_contig_depths --help 2>&1 | head -1 > /dev/null && \
             seqkit version && csvtk version && ps -p 1 -o comm= && \
             test "$(command -v run_RF.py)" = /usr/local/bin/run_RF.py && \
             run_RF.py 2>&1 | grep -q "fastafile" && \
             python -c "import joblib, phamb, pathlib; \
m = joblib.load(pathlib.Path(phamb.__file__).parent / \"dbs/RF_model.python39.sav\"); \
print(\"RF model loads:\", type(m).__name__)"'

# The wrapper must be the one PATH finds, and it must reach the model. Checked by
# running it the way PHAMB_RF does -- with real arguments, so joblib.load() actually
# executes rather than argparse exiting first.
RUN set -e; cd /tmp && \
    printf '>c1\nACGTACGTACGTACGTACGTACGTACGTACGT\n' > c.fna && \
    printf 'cluster_1\tc1\n' > clusters.tsv && \
    mkdir -p anno && \
    printf 'name\tlen\tscore\tpvalue\nc1\t32\t0.9\t0.0\n' > anno/all.DVF.predictions.txt && \
    : > anno/all.hmmVOG.tbl && \
    : > anno/all.hmmMiComplete105.tbl && \
    env -i HOME=/tmp LANG=C.UTF-8 PATH=$VP_PATH:/usr/bin:/bin \
        bash -c 'run_RF.py c.fna clusters.tsv anno out_rf -m 10' && \
    test -f out_rf/vambbins_RF_predictions.txt && \
    echo "run_RF.py end-to-end OK" && \
    rm -rf /tmp/c.fna /tmp/clusters.tsv /tmp/anno /tmp/out_rf

# On amd64 VAMB must be present as well; on arm64 it must be absent. Assert
# whichever is expected, so a broken conditional install cannot pass unnoticed.
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        env -i PATH=/app/.pixi/envs/vamb/bin:/usr/bin:/bin vamb --help > /dev/null && echo "vamb present (amd64)"; \
    else \
        test ! -x /app/.pixi/envs/vamb/bin/vamb && echo "vamb absent (${TARGETARCH}), as expected"; \
    fi

# The pixi base image sets an entrypoint. Nextflow executes its own
# `.command.sh`, so nothing may prefix the command.
ENTRYPOINT []
CMD ["/bin/bash"]

WORKDIR /
