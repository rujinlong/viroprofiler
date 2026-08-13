# ViroProfiler Data Workflow Rules

## Pipeline Type
- Nextflow DSL2 bioinformatics pipeline for viral metagenomics

## Database Directory
- Default: `$HOME/viroprofiler/`
- Subdirectories per tool: `checkv/`, `virsorter2/`, `genomad/`, `checkamg/`, `dram/`, `iphop/`, `vibrant/`, `vitap/`, `vcontact3/`, `kraken2/`, `vogdb/`, `micomplete/`, `eggnog/`
- Setup via `--mode setup`

## Container Images
- Published under `denglab/` on Docker Hub
- 15 functional groups defined in `conf/modules.config`
- Built from `docker/` subdirectories
- Every image except `viroprofiler-host` installs from a committed `pixi.lock`; re-lock
  deliberately and re-test, and gate CI on `pixi lock --check --dry-run` (plain `--check`
  rewrites the lockfile while exiting non-zero)

## Output Structure
- Default output dir: `output/`
- Each process publishes to `{outdir}/{process_name_lowercase}/`
- Pipeline info: `{outdir}/pipeline_info/`

## Branch Convention
- `main` — stable releases only
- `dev_ru` — active development, rebase onto main periodically
