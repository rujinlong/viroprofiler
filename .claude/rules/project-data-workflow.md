# ViroProfiler Data Workflow Rules

## Pipeline Type
- Nextflow DSL2 bioinformatics pipeline for viral metagenomics

## Database Directory
- Default: `$HOME/viroprofiler/`
- Subdirectories per tool: `checkv/`, `virsorter2/`, `dram/`, `iphop/`, `vibrant/`, `vrefseq/`, `kraken2/`, `phamb/`, `eggnog/`
- Setup via `--mode setup`

## Container Images
- Published under `denglab/` on Docker Hub
- 11 functional groups defined in `conf/modules.config`
- Built from `docker/` subdirectories

## Output Structure
- Default output dir: `output/`
- Each process publishes to `{outdir}/{process_name_lowercase}/`
- Pipeline info: `{outdir}/pipeline_info/`

## Branch Convention
- `main` — stable releases only
- `dev_ru` — active development, rebase onto main periodically
