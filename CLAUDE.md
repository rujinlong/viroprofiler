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

**Nextflow 26.04 or newer.** The config and the workflow scripts are written in Nextflow's
strict language, which that release makes the default parser. `manifest.nextflowVersion`
enforces it. Do not set `NXF_SYNTAX_PARSER`: the legacy parser rejects `env()` in the params
block, and the two parsers cannot both be satisfied.

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

`--db` may live anywhere: the `containerOptions` closure in `nextflow.config` bind-mounts it
into the container for every engine that has a per-task bind option, which is all of them
except Shifter. If entries under it are symlinks pointing elsewhere, add those
targets with `--container_binds a,b,c` — Nextflow runs Apptainer with `--no-home`, so nothing
outside the work directory is visible unless bound.

`--sample_metadata` joins per-sample phenotypes into the TSE's `colData`. It cannot ride in
the samplesheet: `INPUT_CHECK` rejects anything that is not exactly three columns. Without it
`colData` holds only the sample name, and no group-wise analysis of the output is possible.

`--mode` names the last stage to run. `setup` builds databases and reads no samplesheet; the
rest are cumulative — `fastqc` → `fastp` → `contiglib` → `all` (default), each running every
earlier stage. `fastqc` and `fastp` are rejected together with `--reads_type clean`, which
skips both. Stage numbering lives in `WorkflowViroprofiler.MODE_STAGE`, which is also what
validates the mode.

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
     |- Taxonomy: TAXONOMY_VITAP + TAXONOMY_VCONTACT3 -> TAXONOMY_MERGE
     |- Host prediction: VIRALHOST_IPHOP
     |- Replication cycle: BACPHLIP or REPLIDEC
  -> RESULTS_TSE (final R object)
  -> MULTIQC
```

### Module Organization

- `modules/local/` — Custom processes grouped by function (viral_detection.nf, taxonomy.nf, abundance.nf, annotation.nf, etc.). Process names are ALL_CAPS.
- `modules/nf-core/modules/` — vendored nf-core processes (FASTQC, FASTP, SPADES, BBMAP, MULTIQC,
  CUSTOM_DUMPSOFTWAREVERSIONS), pinned to 2022 releases.
- `subworkflows/local/` — Composite workflows: `input_check.nf` (CSV parsing), `init.nf` (database setup), `vMAG.nf` (viral MAG binning via PHAMB or vRhyme).

### Configuration Layering

Loaded in this order; a later file wins, which is why `conf/modules.config` is included
*before* `profiles` — otherwise no profile could override a container image.

1. `nextflow.config` — params, profiles, per-process resources, `process.resourceLimits`
2. `conf/base.config` — default resource labels (`process_low`, `process_medium`, `process_high`)
3. `conf/modules.config` — container image per `withLabel`, and the publishDir pattern
4. `profiles` — including `test`, `test_stub`, `arm64_local` (`conf/arm64_local.config`)
5. `custom.config` — site-specific overrides, loaded by the `test_denglab` profile

### Container Strategy

One image per functional group, built from `docker/` subdirectories and published under the
`denglab/` org. `conf/modules.config` maps each `withLabel` to an image; `conf/arm64_local.config`
maps the same labels to local SIFs, and additionally redirects the vendored nf-core modules,
whose `quay.io/biocontainers` images are amd64 only, to `viroprofiler-qc`.

PHAMB ships inside `viroprofiler-binning`. Build with `bash docker/build_arm64.sh [name ...]`.

Every image except `viroprofiler-host` declares its conda dependencies in a `pixi.toml` and
installs from a committed `pixi.lock`, so a rebuild cannot silently resolve a different
package set. `pixi install --locked` fails the build when the two disagree. Re-lock
deliberately and re-test; gate CI on `pixi lock --check --dry-run`, never plain `--check`,
which rewrites the lockfile while exiting non-zero. `viroprofiler-host` stays on micromamba:
its environment file comes from the iPHoP fork's own checkout, which no lockfile here can
cover. See [docs/dev/PACKAGING.md](docs/dev/PACKAGING.md).

### Helper Scripts

`bin/` contains the Python/R/shell scripts called by processes (e.g., `run_checkv.sh`,
`merge_taxonomy.py`, `genomad_contig_table.py`, `genomad_to_dvf.py`,
`parse_vclust_clusters.py`, `create_tse.r`). They must be executable: Nextflow puts `bin/`
on PATH but does not chmod anything.

### Groovy Libraries

`lib/` contains workflow utilities: `WorkflowMain.groovy` (parameter validation, citation), `WorkflowViroprofiler.groovy` (pipeline-specific checks), `NfcoreSchema.groovy` (JSON schema validation), `NfcoreTemplate.groovy` (email/output templates).

## Key Parameters

Optional modules controlled by `use_*` flags: `use_dram` (true), `use_iphop` (true), `use_vitap` (true), `use_checkamg` (true), `use_vibrant` (true), `use_eggnog` (false), `use_kraken2` (false), `use_phamb` (false), `use_abricate` (false), `use_decontam` (false).

Taxonomy sources are merged by `bin/merge_taxonomy.py`, which resolves each rank independently
from ranked `--source NAME PRIORITY FILE` triples (smaller priority wins): VITAP 1, vConTACT3 3.
Priority 2 is reserved for geNomad. It writes two tables: `taxonomy.tsv`, every rank with the
source that filled it, and `taxonomy_tse.tsv`, the same lineages in the layout vpfkit's
`read_taxonomy2()` requires — where `Domain` carries the ICTV realm, or the literal `Viruses`
for a contig placed at a lower rank only, because `create_vpftse_vir()` reads a non-missing
`Domain` as one of the votes that make a contig viral.

Binning: `params.binning` = false | "vrhyme" | "phamb". PHAMB is amd64-only — it classifies
VAMB's clusters and VAMB has no linux-aarch64 build — and
`WorkflowViroprofiler.binningIsAvailable()` refuses it on aarch64 before any process is
submitted. PHAMB's random forest reads a per-contig virus score in DeepVirFinder's format;
`PHAMB_DVF_TABLE` supplies geNomad's scores in that layout, which is the same range and the
same slot but not the distribution the forest was fitted on, so its bin calls are approximate.
`bin/genomad_to_dvf.py` states the limitation in full. `--binning vrhyme` needs no such caveat
and is the only binner available on aarch64.

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
  pandas 3, each of which breaks at least one tool here. The images install from committed
  lockfiles for this reason. See [docs/dev/PACKAGING.md](docs/dev/PACKAGING.md).
- **A clean solve is not a working environment.** Some conda packages ship only a post-link
  script that fetches what they nominally provide; micromamba runs those, pixi does not, and
  the difference appears in neither the solve nor the lockfile. Every Dockerfile therefore
  ends with a smoke test that exercises the tools under `env -i` with the image's own PATH —
  the environment `.command.sh` actually runs in. A smoke test that searches a different PATH
  than the image exports proves nothing about the image.
- **A new parameter needs a type in `main.nf`, or its command-line value is a string.** The
  strict parser does no type detection: `--use_dram false` arrives as `"false"`, which Groovy
  reads as true, so the module runs when the user asked for it not to. Add non-string
  parameters to the `params { }` declaration block, matching `"type"` in
  `nextflow_schema.json`. Only `Boolean`, `Integer` and `Float` convert a command-line
  string; `Number`, `Double` and `BigDecimal` reject it. Values stay in `nextflow.config`.
- **`process.resourceLimits` must stay below the `profiles` block.** It is evaluated where it
  is written, not per task, so moving it into `conf/base.config` would freeze it to the
  defaults and silently ignore the lower ceilings `test`, `test_stub` and `custom.config` set.
- **`nextflow lint` does not check what a closure resolves to.** It reported no error on a
  `workflow.onComplete { }` handler in which `params` was null at run time. Completion
  handlers belong in the entry workflow's `onComplete:` section.
- **Treat a subagent or Codex finding as a lead, not a fact.** Verify against the code first.

Current state, open work and what has *not* been verified: [docs/HANDOFF.md](docs/HANDOFF.md).
Every known defect with its status: [docs/dev/KNOWN_ISSUES.md](docs/dev/KNOWN_ISSUES.md).

## Branch Strategy

- `main` — stable releases only, no direct development
- `dev_ru` — unified development branch, rebase onto main periodically
