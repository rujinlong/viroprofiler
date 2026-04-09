# ViroProfiler: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Single-end read support (`--single_end` parameter)
- Stub test infrastructure for CI pipeline validation (51/51 processes covered)
- GitHub Actions CI workflow with 5 stub test jobs (PE reads, SE reads, contig annotation, DB setup, optional modules)
- Stub blocks for all 12 database setup processes in `setup_db.nf`
- Stub test data files (`tests/data/`)
- `test_stub` profile for lightweight pipeline topology testing without databases or containers

### Fixed

- ABRICATE stub output: `printf` format specifier error with `%COVERAGE`/`%IDENTITY` column headers
- `.gitignore`: bare `data` pattern was ignoring `tests/data/` directory
- Missing `single_end` and `dvf_maxlen` parameter definitions in `nextflow.config`
- Schema validation warnings for `single_end` and `decontam` parameters

### Documentation

- Rewrote `docs/usage.md` to remove nf-core boilerplate referencing unrelated pipelines
- Fixed typos across documentation (MultiQC, iPHoP, Singularity, analysis)
- Corrected parameter defaults in tutorial (use_dram, use_iphop, --outdir)
- Added missing parameters to tutorial documentation (--mode, --input_contigs, --single_end)
- Fixed broken image references and TODO placeholders in output documentation
- Added test_stub profile to profiles documentation
- Fixed repository URLs in CONTRIBUTING.md (rujinlong -> deng-lab)
- Added CI badge to README.md
- Fixed empty fastp URL in CITATIONS.md

## v1.0dev - 2023-03-01

Initial release of ViroProfiler, created with the [nf-core](https://nf-co.re/) template.

### Added

- Full viral metagenomics pipeline: QC, assembly, viral detection, taxonomy, host prediction, functional annotation
- Support for Docker, Singularity, Podman, Shifter, and Charliecloud container engines
- TreeSummarizedExperiment R object output for downstream analysis
- Integration with ViroProfiler-viewer for interactive visualization
