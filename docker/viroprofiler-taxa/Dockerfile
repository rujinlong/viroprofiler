FROM mambaorg/micromamba:0.25.1

USER root

COPY ./docker/viroprofiler-taxa/env_*.yml /tmp

# Install packages into `base` env, because nextflow can't use other envs.
RUN --mount=type=cache,target=/opt/conda/pkgs micromamba install -n base -f /tmp/env_taxa.yml -y && \
    micromamba clean --all --yes

# Activate conda env during docker build
ARG MAMBA_DOCKERFILE_ACTIVATE=1


RUN VCONTACT2_DATA=$(python3 -c "import site; print(site.getsitepackages()[0])")/vcontact2/data && \
    cd $VCONTACT2_DATA && \
    /opt/conda/bin/wget https://bitbucket.org/MAVERICLab/vcontact2/raw/6089ed83fd03a844de3140c442863c7b29881d43/vcontact2/data/ViralRefSeq-prokaryotes-v211.Merged-reference.csv && \
    /opt/conda/bin/wget https://bitbucket.org/MAVERICLab/vcontact2/raw/6089ed83fd03a844de3140c442863c7b29881d43/vcontact2/data/ViralRefSeq-prokaryotes-v211.faa.gz && \
    /opt/conda/bin/wget https://bitbucket.org/MAVERICLab/vcontact2/raw/6089ed83fd03a844de3140c442863c7b29881d43/vcontact2/data/ViralRefSeq-prokaryotes-v211.protein2contig.csv

RUN micromamba clean --all --yes

# Set PATH manually, because nextflow doesn't activate base env by default.
ENV PATH=/opt/conda/bin:$PATH