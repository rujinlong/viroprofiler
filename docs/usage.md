# ViroProfiler: Usage

## Introduction

ViroProfiler is a Nextflow DSL2 pipeline for comprehensive viral metagenomic data analysis. This page describes how to configure and run the pipeline, customize resource allocations, and integrate it into your computing environment.

## Custom configuration

### Resource requests

The default resource requirements set within the pipeline should work for most datasets and environments. However, you may need to customize the compute resources for specific steps. Each process in the pipeline has a default set of requirements for CPUs, memory, and time. If a job exits with a standard retry error code, it will automatically be resubmitted with higher requests (2x original, then 3x original). If it still fails after the third attempt, the pipeline execution stops.

For example, if the `VIRSORTER2` process is failing due to an out-of-memory error (exit code `137`), you can increase its resources by creating a custom config file:

```nextflow
process {
    withName: VIRSORTER2 {
        memory = 100.GB
    }
}
```

Then pass it to the pipeline with the `-c` parameter:

```bash
nextflow run deng-lab/viroprofiler -profile singularity -c custom.config --input samplesheet.csv
```

> **Note:** We specify the full process name in the config file because this takes priority over label-based selectors and allows precise control over individual process resources.

See `custom.config` in the repository root for a comprehensive example with resource settings for all processes.

### Updating containers

The Nextflow DSL2 implementation of this pipeline uses one container per functional group, making it straightforward to update software dependencies. If you need to use a different version of a particular tool, identify the relevant process and override the container definition using a `withName` declaration in your custom config:

For Docker:

```nextflow
process {
    withName: CHECKV {
        container = 'denglab/viroprofiler-base:latest'
    }
}
```

For Singularity:

```nextflow
process {
    withName: CHECKV {
        container = 'docker://denglab/viroprofiler-base:latest'
    }
}
```

> **Note:** If you update individual tool containers, ensure that the `work/` directory is preserved so that the `-resume` functionality is not compromised.

### nf-core/configs

If you and others in your organization regularly run Nextflow pipelines with the same settings, consider contributing a custom config to the [nf-core/configs](https://github.com/nf-core/configs) repository. Test the config file with ViroProfiler first using the `-c` parameter, then submit a pull request with your config file and associated documentation.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating configuration files.

## Running in the background

Nextflow handles job submissions and supervises running jobs. The Nextflow process must remain active until the pipeline finishes.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow continues if you log out of your session. Logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or a similar tool to create a detached session. Some HPC setups also allow you to run Nextflow within a cluster job submitted to your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory. We recommend adding the following line to your environment (typically in `~/.bashrc` or `~/.bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

## Configuration file

All parameters can be set through a configuration file. When a configuration file is used, the pipeline is executed as:

```bash
nextflow run deng-lab/viroprofiler -c custom.config
```

To get an example configuration file:

```bash
wget -O custom.config "https://raw.githubusercontent.com/deng-lab/viroprofiler/main/custom.config"
```

See the [configuration file documentation](config.md) for details on available settings.

## Interactive execution

### Via Seqera Platform (cloud environments)

Nextflow integrates with [Seqera Platform](https://seqera.io/) (formerly Nextflow Tower), which provides a web interface for configuring, launching, and monitoring pipeline executions across cloud and HPC environments. The pipeline's JSON schema enables automatic form rendering for parameter configuration.

### Via nf-core launch (local execution)

You can use [nf-core launch](https://nf-co.re/launch) for interactive pipeline configuration:

```bash
# Install nf-core
pip install nf-core

# Launch the pipeline
nf-core launch deng-lab/viroprofiler
```

This starts an interactive form in your web browser or command line, allowing you to configure the pipeline step by step before execution.
