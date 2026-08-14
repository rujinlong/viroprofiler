# ViroProfiler: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.1 - 2026-08-14

The first release since the published version, and a large one: geNomad replaces
DeepVirFinder, Vclust replaces the all-vs-all BLAST recipe, VITAP and vConTACT3 supply
taxonomy, CheckAMG calls auxiliary genes, the output is a TreeSummarizedExperiment built by
[vpfkit](https://github.com/deng-lab/vpfkit), the images install from committed lockfiles,
and aarch64 is supported. **Requires Nextflow 26.04 or newer.**

### Added

- geNomad replaces DeepVirFinder as the reference-free virus caller (`GENOMAD` process,
  `docker/viroprofiler-genomad/`, `DB_GENOMAD` setup process). It also supplies a topology
  call, a taxonomy assignment and provirus coordinates; `bin/genomad_contig_table.py` maps
  its per-virus rows back onto contig IDs and fails loudly rather than letting an unmatched
  name silently drop a contig from the viral set
- `--genomad_preset` and `--genomad_splits`
- geNomad's per-contig virus score reaches the TSE through vpfkit's `fin_genomad` slot, so
  `rowData` gains `genomad_score`, `genomad_fdr`, `genomad_topology`, `genomad_taxonomy`
  and `genomad_n_hallmarks`, and `create_vpftse_vir()` counts a score >= 0.7 as viral
  evidence
- CheckAMG is the auxiliary-gene caller (`CHECKAMG` process,
  `docker/viroprofiler-checkamg/`, `DB_CHECKAMG` setup process), distinguishing AMGs,
  AReGs and APGs. DRAM-v is kept: its per-gene annotation table is complementary evidence,
  not a competing AMG call
- `--use_checkamg` and `--checkamg_min_weight`
- `--use_vibrant`, so VIBRANT can be skipped. It is on by default
- `vircontigs/putative_vcontigs_unmatched.list` records detector hits that name a sequence
  absent from the contig library, which `seqkit grep` used to drop without a word

- Single-end read support (`--single_end` parameter)
- Stub test infrastructure for CI pipeline validation (51/51 processes covered)
- GitHub Actions CI workflow with 7 stub test jobs (PE reads, SE reads, contig annotation,
  DB setup, optional modules, PHAMB binning, the `--mode` ladder)
- Stub blocks for all 12 database setup processes in `setup_db.nf`
- Stub test data files (`tests/data/`)
- `test_stub` profile for lightweight pipeline topology testing without databases or containers

### Removed

- DeepVirFinder, `--use_dvf`, `--dvf_qvalue`, `--dvf_maxlen`, `docker/viroprofiler-dvf/`
  and `bin/calc_qvalue.r`. It had no release since 2020 and no linux-aarch64 build in any
  version (theano 1.0.3 / keras 2.2.4)
- `--binning phamb` on aarch64, which is refused before any process is submitted: PHAMB
  bins VAMB's clusters and VAMB has no linux-aarch64 build. On amd64 it still runs, but
  its calls are approximate -- the random forest was fitted on DeepVirFinder's per-contig
  scores and `PHAMB_DVF_TABLE` gives it geNomad's in the same layout, which share a range
  but not a calibration. `--binning vrhyme` carries no such caveat

### Changed

- The config and the workflow scripts are written in Nextflow's strict language, which
  26.04 makes the default parser. Runs no longer need `NXF_SYNTAX_PARSER=v1`, and must not
  set it: the legacy parser rejects `env()` in the params block
- `check_max()` is replaced by the built-in `process.resourceLimits`
- `main.nf` declares the types of the 34 non-string parameters, which is what makes
  `--use_dram false` a boolean again rather than the string `"false"`

### Fixed

- A boolean passed on the command line arrived as a string under the strict parser, and
  Groovy reads `"false"` as true, so `--use_dram false` would have run DRAM-v. Schema
  validation rejected the run first, which is the only reason it was loud rather than silent
- The completion summary was printed twice on every run: a file-scope `workflow.onComplete`
  handler in each of the two workflow files, both registered because `main.nf` includes both
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
