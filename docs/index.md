# Welcome to ViroProfiler pipeline documentation

## About

[ViroProfiler](https://github.com/deng-lab/viroprofiler) is a pipeline designed to provide an easy-to-use framework for performing a comprehensive analyses of viral metagenomics data. It is developed with [Nextflow](https://www.nextflow.io/docs/latest/index.html) and [Docker](https://www.docker.com/). It can detect and characterize viral sequences and communities recovered from metagenomics data.

## Workflow

The pipeline's main steps are:

| Pipeline modules | Used software or databases |
| :------------- | :------------------------- |
| Genome assembly | [metaSPAdes](https://github.com/ablab/spades) |
| Contig library dereplication | [Vclust](https://github.com/refresh-bio/vclust), at the MIUViG species thresholds |
| Abundance estimation | [CoverM](https://github.com/wwood/CoverM) |
| Binning | [vRhyme](https://github.com/AnantharamanLab/vRhyme) |
| Viral contig identification | [geNomad](https://github.com/apcamargo/genomad), [CheckV](https://bitbucket.org/berkeleylab/checkv/src/master/) and [VIBRANT](https://github.com/AnantharamanLab/VIBRANT); [VirSorter2](https://github.com/jiarong/VirSorter2) then prepares the affi-contigs table DRAM-v needs |
| Auxiliary gene (AMG/AReG/APG) calling | [CheckAMG](https://github.com/AnantharamanLab/CheckAMG) |
| Gene function annotation | [DRAM-v](https://github.com/WrightonLabCSU/DRAM), [EggNOG](http://eggnog5.embl.de/) and [abricate](https://github.com/tseemann/abricate) |
| Viral replication cycle prediction |  [BACPHLIP](https://github.com/adamhockenberry/bacphlip) or [Replidec](https://github.com/deng-lab/Replidec) |
| Viral taxonomy annotation | [VITAP](https://github.com/DrKaiyangZheng/VITAP) and [vConTACT3](https://bitbucket.org/MAVERICLab/vcontact3) |
| Viral-host prediction | [iPHoP](https://bitbucket.org/srouxjgi/iphop) |
| Results object and visualization | [vpfkit](https://github.com/deng-lab/vpfkit) assembles a [TreeSummarizedExperiment](https://bioconductor.org/packages/TreeSummarizedExperiment/) and provides the Shiny viewer and the Quarto report; [MultiQC](https://multiqc.info/) summarises the run |

The pipeline's headline output is that TreeSummarizedExperiment: one object carrying the
abundance assays, every per-contig annotation and the sample metadata, ready for analysis in
R. Pass `--sample_metadata` or its `colData` will hold nothing but the sample names.

Requires **Nextflow 26.04 or newer** — see [Installation](installation.md).

!!! note "Tutorial"

    A [tutorial](tutorial.md#) is available so you can quickly get the gist of the pipeline's capabilities.

