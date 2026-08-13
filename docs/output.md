# ViroProfiler: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline. The output data is also stored in a `TreeSummarizedExperiment` object in file `viroprofiler_output.rds`, which can be uploaded to [ViroProfiler-viewer](https://github.com/deng-lab/viroprofiler-viewer) for interactive visualization, or imported into R for further analysis.

The directories listed below will be created in the `output` directory after the pipeline has finished. All paths are relative to the top-level `output` directory.

## Output directory structure

```text
output
├── abundance
├── bacphlip
├── checkv
├── contiglib
├── dramv
├── dvf
├── emapper
├── fastp
├── fastqc
├── genepred4ctg
├── mapping2contigs
├── multiqc
├── nrgene
├── nrprot
├── pipeline_info
├── results
├── spades
├── taxonomy
├── viralhost
├── vircontigs
└── virsorter2
```

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

1. Reads QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Dereplication
3. Contig quality evaluation and provirus detection ([`CheckV`](https://bitbucket.org/berkeleylab/checkv))
4. Contig clustering based on ANI
5. Binning (optional, using Phamb or vrhyme)
6. Abundance estimation
7. Viral sequence identification (VirSorter2, VIBRANT, DeepVirfinder)
8. Functional annotation
9. Taxonomy assignment
10. Viral-host prediction
11. Viral replication cycle prediction
12. Merged output
13. Aggregate report describing results and QC from the whole pipeline ([`MultiQC`](http://multiqc.info/))
14. [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### FastQC

<details markdown="1">
<summary>Output files</summary>

- `fastqc/`
  - `*_fastqc.html`: FastQC report containing quality metrics.
  - `*_fastqc.zip`: Zip archive containing the FastQC report, tab-delimited data file and plot images.

</details>

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences. For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

> **Note:** The FastQC plots displayed in the MultiQC report show _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality.

### Dereplication of contigs

Contigs from all samples were merged into a single file, and 100% identical contigs were removed and only the longest one was kept. This step is to remove redundant contigs and reduce the computational cost of downstream analysis. The remaining contigs formed the contig library (contigs_cclib.fasta.gz). In addition, another contig library was created by removing short contigs. The shortest contig length threshold can be set by users in the `params.yml` file. The remaining contigs formed the long contig library (contigs_cclib_long.fasta.gz).

### Contig quality evaluation and provirus detection

The first step of the long contig library analysis is to evaluate the quality of each contig. The quality of each contig is evaluated using [CheckV](https://bitbucket.org/berkeleylab/checkv/src/master/), which is a tool for evaluating the quality of contigs and predicting the presence of proviruses. We mainly rely on this tool to remove host contamination at the flanking sides of the provirus contigs. However, other metrics such as completeness and contamination are also reported for each contig.

### Contig clustering based on ANI

The long contig library were then dereplicated using MGV clustering script (https://github.com/snayfach/MGV/tree/master/ani_cluster). After clustering, each cluster is roughly a viral species. The representative contig of each cluster is merged into a non-redundant contig library (nrclib), and used for downstream annotation and analysis. This step is to reduce the computational cost of downstream analysis.

### Binning (optional, using Phamb or vrhyme)

The representative contigs of each cluster can be binned into viral MAGs using [phamb](https://github.com/RasmussenLab/phamb) or [vRhyme](https://github.com/AnantharamanLab/vRhyme).

### Abundance estimation

Abundance of contigs or bins is estimated using clean reads mapped to the contigs or bins. Multiple abundance metrics are available, including raw counts, TPM, and RPKM. The mapped BAM files can also be imported into other tools such as [MetaPop](https://github.com/metaGmetapop/metapop) for macro- and micro-diversity analyses of viruses and visualization of metagenomic-derived populations.

### Viral sequence identification

Viral sequences are identified using multiple tools in ViroProfiler (VirSorter2, VIBRANT, DeepVirFinder). Results from each tool are saved to separate files and merged into a final annotation file.

### Functional annotation

Protein sequences of viruses are annotated using multiple tools and databases (DRAM-v, eggNOG-mapper, abricate). Results from each tool are saved to separate files and merged into a final annotation file.

### Taxonomy assignment

Taxonomy is assigned by two independent callers and then merged. vConTACT3 clusters
the contigs with a reference set by gene sharing and predicts a lineage from realm down
to genus for each cluster; the MMseqs2 taxonomy module assigns a per-contig LCA against
a customized viral database built from NCBI RefSeq viral sequences, which reaches species
but is noisier. `merge_taxonomy.py` resolves the two rank by rank, taking the
highest-priority caller that made a call at that rank -- vConTACT3 first, MMseqs2 second.

The merged table is `taxonomy/taxonomy.tsv`: one row per contig, one column per rank
(`Realm` ... `Species`), and beside each rank a `<Rank>_source` column naming the caller
the value came from. Ranks vConTACT3 labelled as de novo clusters keep its
`novel_<rank>_<n>_of_<parent>` labels, which are stable per cluster and cannot be
confused with ICTV names. ViroProfiler also supports the ICTV viral taxonomy nomenclature
via a separate database built from ICTV sequences and annotations. Results are saved to
the `taxonomy` folder.

### Viral-host prediction

Viral host prediction is performed using [iPHoP](https://bitbucket.org/srouxjgi/iphop), which integrates signals from multiple viral-host prediction tools. Results are saved to the `viralhost` folder.

### Viral replication cycle prediction

The replication cycle of viral contigs or bins is predicted using either [BACPHLIP](https://github.com/adamhockenberry/bacphlip) or [Replidec](https://github.com/deng-lab/Replidec). Results are merged into the final annotation file.

### Merged output

All contig annotation results and the abundance table are merged into a [TreeSummarizedExperiment](https://bioconductor.org/packages/TreeSummarizedExperiment/) R object (`viroprofiler_output.rds`). This object can be imported into R for custom analysis or uploaded to [ViroProfiler-viewer](https://github.com/deng-lab/viroprofiler-viewer) for interactive exploration, including diversity analysis and differential abundance analysis.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
