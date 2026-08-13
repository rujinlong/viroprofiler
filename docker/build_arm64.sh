#!/usr/bin/env bash
#
# Build the ViroProfiler container images natively on an aarch64 host and convert them to
# SIF files for Apptainer.
#
# The images published on Docker Hub are amd64-only, so on arm64 they have to be rebuilt
# from the Dockerfiles in this directory. Two images are deliberately absent: see
# docs/dev/ARM64.md for why iPHoP and DeepVirFinder cannot be built for this architecture.
#
# Usage:
#   bash docker/build_arm64.sh                 # build everything, write SIFs to the default dir
#   SIF_DIR=/path bash docker/build_arm64.sh   # choose where the SIFs go
#   bash docker/build_arm64.sh base qc         # build only the named images
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${TAG:-v0.3}"
SIF_DIR="${SIF_DIR:-$HOME/singularity/viroprofiler}"

ALL_IMAGES=(base qc abundance replicyc vibrant bracken virsorter2 vcontact3 geneannot binning viewer)
IMAGES=("${@:-}")
[[ -z "${IMAGES[*]}" ]] && IMAGES=("${ALL_IMAGES[@]}")

mkdir -p "$SIF_DIR"
cd "$REPO_ROOT"
export DOCKER_BUILDKIT=1

status=0
for img in "${IMAGES[@]}"; do
    dockerfile="docker/viroprofiler-${img}/Dockerfile"
    if [[ ! -f "$dockerfile" ]]; then
        echo "SKIP  ${img}: no ${dockerfile}"
        continue
    fi

    echo "BUILD ${img}"
    if ! docker build -f "$dockerfile" -t "denglab/viroprofiler-${img}:${TAG}" . ; then
        echo "FAIL  ${img}: docker build"
        status=1
        continue
    fi

    echo "SIF   ${img}"
    if ! apptainer build --force "${SIF_DIR}/viroprofiler-${img}.sif" \
            "docker-daemon:denglab/viroprofiler-${img}:${TAG}"; then
        echo "FAIL  ${img}: apptainer build"
        status=1
        continue
    fi

    echo "OK    ${img} -> ${SIF_DIR}/viroprofiler-${img}.sif"
done

exit $status
