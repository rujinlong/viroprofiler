# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Policy (MANDATORY)

**Everything written into this repository must be in English.** ViroProfiler's users are
predominantly English-speaking, so English is the only language allowed in:

- source code, comments, and log/error messages
- commit messages, branch names, PR/issue text
- `README.md`, `docs/`, `CHANGELOG.md`, and every other tracked document
- test fixtures, sample sheets, and CI workflow definitions

This applies regardless of the language used in the interactive conversation with the user,
and it also applies to any subagent invoked while working on this repository.

## What is ViroProfiler

A Nextflow DSL2 pipeline for viral metagenomic data analysis. It takes raw reads (or pre-assembled contigs), performs QC, assembly, viral detection, taxonomy, host prediction, functional annotation, and produces a TreeSummarizedExperiment (TSE) R object.

## Running the Pipeline

```bash
# Database setup (required on a new installation)
nextflow run main.nf -profile apptainer --mode setup --db /path/to/db

# Full pipeline
nextflow run main.nf -profile apptainer --input samplesheet.csv --db /path/to/db

# Contig annotation only (skips assembly)
nextflow run main.nf -profile apptainer --input_contigs contigs.fasta --db /path/to/db

# Topology check, runs every process as a no-op in seconds
nextflow run main.nf -stub -profile test_stub
```

`--db` may live anywhere: it is bind-mounted into every container by the `containerOptions`
closure in `nextflow.config`. If entries under it are symlinks pointing elsewhere, add those
targets with `--container_binds a,b,c` — Nextflow runs Apptainer with `--no-home`, so nothing
outside the work directory is visible unless bound.

`--mode` accepts `setup` and `all` (default). `fastqc`, `fastp` and `contiglib` appear in the
schema but are not implemented; anything other than `setup` currently runs the full pipeline.

Container profiles: `docker`, `singularity`, `apptainer`, `podman`, `shifter`, `charliecloud`.
On aarch64 add `arm64_local`, which points at locally built SIFs — the published images are
amd64 only. See [docs/dev/ARM64.md](docs/dev/ARM64.md).

## Architecture

### Entry Point and Workflow Routing

`main.nf` routes to one of two workflows:
- `params.input_contigs` set -> `CONTIGANNO` (workflows/contig_anno.nf) — annotation-only, skips assembly
- otherwise -> `VIROPROFILER` (workflows/viroprofiler.nf) — full pipeline

### Pipeline Data Flow (VIROPROFILER workflow)

```
INPUT_CHECK (samplesheet CSV)
  -> FASTQC + FASTP [+ DECONTAM]
  -> SPADES assembly
  -> CONTIGLIB -> CHECKV -> CONTIGLIB_CLUSTER
  -> [parallel branches]:
     |- Gene library: GENEPRED -> NRPROT/NRGENE [-> EMAPPER, ABRICATE]
     |- Abundance: CONTIGINDEX -> MAPPING2CONTIGS2 -> ABUNDANCE
     |- Viral detection: GENOMAD [+ VIBRANT] + CheckV quality -> VIRCONTIGS_PRE
     |  [-> binning] -> VIRSORTER2 [-> DRAMV], and CHECKAMG on the candidate viruses
     |- Taxonomy: TAXONOMY_VITAP + TAXONOMY_VCONTACT3 + TAXONOMY_MMSEQS -> TAXONOMY_MERGE
     |- Host prediction: VIRALHOST_IPHOP
     |- Replication cycle: BACPHLIP or REPLIDEC
  -> RESULTS_TSE (final R object)
  -> MULTIQC
```

### Module Organization

- `modules/local/` — Custom processes grouped by function (viral_detection.nf, taxonomy.nf, abundance.nf, annotation.nf, etc.). Process names are ALL_CAPS.
- `modules/nf-core/modules/` — vendored nf-core processes (FASTQC, FASTP, SPADES, BBMAP, MULTIQC,
  CUSTOM_DUMPSOFTWAREVERSIONS), pinned to 2022 releases.
- `subworkflows/local/` — Composite workflows: `input_check.nf` (CSV parsing), `init.nf` (database setup), `vMAG.nf` (viral MAG binning via PHAMB or VRhyme).

### Configuration Layering

Loaded in this order; a later file wins, which is why `conf/modules.config` is included
*before* `profiles` — otherwise no profile could override a container image.

1. `nextflow.config` — params, profiles, per-process resources, `check_max()`
2. `conf/base.config` — default resource labels (`process_low`, `process_medium`, `process_high`)
3. `conf/modules.config` — container image per `withLabel`, and the publishDir pattern
4. `profiles` — including `test`, `test_stub`, `arm64_local` (`conf/arm64_local.config`)
5. `custom.config` — site-specific overrides, loaded by the `test_denglab` profile

### Container Strategy

One image per functional group, built from `docker/` subdirectories and published under the
`denglab/` org. `conf/modules.config` maps each `withLabel` to an image; `conf/arm64_local.config`
maps the same labels to local SIFs, and additionally redirects the vendored nf-core modules,
whose `quay.io/biocontainers` images are amd64 only, to `viroprofiler-qc`.

`docker/viroprofiler-phamb/` is not referenced by any label — PHAMB ships inside
`viroprofiler-binning`. Build with `bash docker/build_arm64.sh [name ...]`.

### Helper Scripts

`bin/` contains the Python/R/shell scripts called by processes (e.g., `run_checkv.sh`,
`parse_mmseqsTaxa.py`, `merge_taxonomy.py`, `genomad_contig_table.py`,
`parse_vclust_clusters.py`, `create_tse.r`).

### Groovy Libraries

`lib/` contains workflow utilities: `WorkflowMain.groovy` (parameter validation, citation), `WorkflowViroprofiler.groovy` (pipeline-specific checks), `NfcoreSchema.groovy` (JSON schema validation), `NfcoreTemplate.groovy` (email/output templates).

## Key Parameters

Optional modules controlled by `use_*` flags: `use_dram` (true), `use_iphop` (true), `use_vitap` (true), `use_checkamg` (true), `use_vibrant` (true), `use_eggnog` (false), `use_kraken2` (false), `use_phamb` (false), `use_abricate` (false), `use_decontam` (false).

Taxonomy sources are merged by `bin/merge_taxonomy.py`, which resolves each rank independently from ranked `--source NAME PRIORITY FILE` triples (smaller priority wins): VITAP 1, geNomad 2, vConTACT3 3, MMseqs2 4.

Binning: `params.binning` = false | "vrhyme". `"phamb"` errors out — PHAMB's random forest reads DeepVirFinder's score table, which the pipeline no longer produces.

Detection vs. downstream tools: geNomad, CheckV quality and (optionally) VIBRANT are the detectors whose union `VIRCONTIGS_PRE` forms. VirSorter2 is **not** a detector here — it runs on the already-selected candidates to produce `viral-affi-contigs-for-dramv.tab`, without which `DRAM-v.py distill` raises `KeyError` on the missing `auxiliary_score` column.

## Verification Discipline

These correspond to defects that shipped in this repository and stayed invisible for years.
They are not style preferences.

- **An exit status proves nothing about a database.** VIBRANT's `download-db.sh` ends in an
  unconditional `exit 0`; DRAM once stored an HTML landing page as a database; VITAP publishes
  a DIAMOND index that `dbinfo` reads and `blastp` rejects; vConTACT3's `prepare_databases`
  reports a failure it did not have. Every `DB_*` process builds into the task work directory,
  checks the *content* of what it produced, and publishes only then. Keep that shape.
- **Stub tests validate topology, not schemas.** A stub passes whether or not the real process
  writes the columns its consumers read. When you change an output, diff the stub header
  against a real product.
- **Loosening a version pin on a 2022-era tool is an untested environment, not an upgrade.**
  Unpinned solves reach Python 3.14, setuptools 84, snakemake 8, numpy 1.24, scipy 1.15 and
  pandas 3, each of which breaks at least one tool here. See [docs/dev/PACKAGING.md](docs/dev/PACKAGING.md).
- **Treat a subagent or Codex finding as a lead, not a fact.** Verify against the code first.

Current state, open work and what has *not* been verified: [docs/HANDOFF.md](docs/HANDOFF.md).
Every known defect with its status: [docs/dev/KNOWN_ISSUES.md](docs/dev/KNOWN_ISSUES.md).

## Branch Strategy

- `main` — stable releases only, no direct development
- `dev_ru` — unified development branch, rebase onto main periodically
