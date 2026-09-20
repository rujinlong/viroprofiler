# Installation

## Requirements

- A UNIX system. Windows users can run the pipeline under [WSL](https://docs.microsoft.com/windows/wsl/install).
- [Nextflow](https://www.nextflow.io/) **26.04 or newer**. The pipeline is written in
  Nextflow's strict language, which that release makes the default parser, and
  `manifest.nextflowVersion` refuses to start on anything older. Do not set
  `NXF_SYNTAX_PARSER`.
- A container engine: Docker, Singularity/Apptainer, Podman, Shifter or Charliecloud.
- Disk for the databases. A full setup is roughly 100 GB, most of it DRAM and VIBRANT.

## Getting the pipeline

```bash
nextflow pull deng-lab/viroprofiler              # latest
nextflow pull deng-lab/viroprofiler -r v1.0.1    # a specific release
```

Container images are pulled on demand; there is nothing to download by hand. If you use
Singularity or Apptainer, point `NXF_SINGULARITY_LIBRARYDIR` at a writable directory so the
converted images are reused between runs.

On aarch64 (Apple silicon, AWS Graviton, NVIDIA GB10) the published images do not apply —
they are amd64 only. See [ARM64.md](dev/ARM64.md) for what can be built locally and what
cannot.

## Building the databases

Required once per installation, and the longest part of setting up:

```bash
nextflow run deng-lab/viroprofiler -profile docker --mode setup --db /path/to/db
```

Every later run takes the same `--db`. If entries under it are symlinks pointing elsewhere,
add those targets with `--container_binds a,b,c` — Nextflow runs the container without your
home directory mounted, so nothing outside the work directory is visible unless it is bound.

## Checking the installation

```bash
# Seconds, no databases: runs every process as a no-op and proves the graph wires up.
nextflow run deng-lab/viroprofiler -stub -profile test_stub

# The bundled test dataset, end to end.
nextflow run deng-lab/viroprofiler -profile docker,test --db /path/to/db
```

See [Profiles](profiles.md) for choosing a container engine and an execution environment.
