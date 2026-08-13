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
# Database setup (required first run)
nextflow run main.nf -profile singularity --mode "setup" --db ~/viroprofiler

# Full pipeline
nextflow run main.nf -profile singularity --input samplesheet.csv --db ~/viroprofiler

# Contig annotation only (skip assembly)
nextflow run main.nf -profile singularity --input_contigs contigs.fasta --db ~/viroprofiler

# Test run
nextflow run main.nf -profile singularity,test
```

Run modes via `--mode`: `setup`, `fastqc`, `fastp`, `contiglib`, `all` (default).

Container profiles: `docker`, `singularity`, `apptainer`, `podman`, `shifter`, `charliecloud`.

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
     |- Viral detection: VIBRANT + DVF -> VIRCONTIGS_PRE [-> binning] -> VIRSORTER2 [-> DRAMV]
     |- Taxonomy: TAXONOMY_VITAP + TAXONOMY_VCONTACT3 + TAXONOMY_MMSEQS -> TAXONOMY_MERGE
     |- Host prediction: VIRALHOST_IPHOP
     |- Replication cycle: BACPHLIP or REPLIDEC
  -> RESULTS_TSE (final R object)
  -> MULTIQC
```

### Module Organization

- `modules/local/` — Custom processes grouped by function (viral_detection.nf, taxonomy.nf, abundance.nf, annotation.nf, etc.). Process names are ALL_CAPS.
- `modules/nf-core/modules/` — Standard nf-core processes (FASTQC, FASTP, SPADES, BBMAP_ALIGN, MULTIQC).
- `subworkflows/local/` — Composite workflows: `input_check.nf` (CSV parsing), `init.nf` (database setup), `vMAG.nf` (viral MAG binning via PHAMB or VRhyme).

### Configuration Layering

1. `nextflow.config` — All params (80+), profiles, per-process resources, `check_max()` function
2. `conf/base.config` — Default resource labels (`process_low`, `process_medium`, `process_high`)
3. `conf/modules.config` — Container image assignments via labels (`viroprofiler_base`, `viroprofiler_virsorter2`, etc.), publishDir pattern
4. `conf/test.config` — Minimal test resources
5. `custom.config` — Site-specific overrides (not tracked; loaded by `test_denglab` profile)

### Container Strategy

15 separate Docker images per functional group, built from `docker/` subdirectories. Images published to Docker Hub under `denglab/` org. Container versions defined in `conf/modules.config` via `withLabel` directives.

### Helper Scripts

`bin/` contains 15 Python/R/shell scripts called by processes (e.g., `run_checkv.sh`, `parse_mmseqsTaxa.py`, `create_tse.r`).

### Groovy Libraries

`lib/` contains workflow utilities: `WorkflowMain.groovy` (parameter validation, citation), `WorkflowViroprofiler.groovy` (pipeline-specific checks), `NfcoreSchema.groovy` (JSON schema validation), `NfcoreTemplate.groovy` (email/output templates).

## Key Parameters

Optional modules controlled by `use_*` flags: `use_dram` (true), `use_iphop` (true), `use_vitap` (true), `use_eggnog` (false), `use_kraken2` (false), `use_phamb` (false), `use_abricate` (false), `use_decontam` (false).

Taxonomy sources are merged by `bin/merge_taxonomy.py`, which resolves each rank independently from ranked `--source NAME PRIORITY FILE` triples (smaller priority wins): VITAP 1, geNomad 2, vConTACT3 3, MMseqs2 4.

Binning: `params.binning` = false | "phamb" | "vrhyme".

## Branch Strategy

- `main` — stable releases only, no direct development
- `dev_ru` — unified development branch, rebase onto main periodically

## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
