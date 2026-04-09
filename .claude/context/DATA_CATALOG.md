# DATA CATALOG

<!-- Track data assets: raw inputs, intermediates, outputs -->
<!-- Format: Name, Type (raw/intermediate/output), Path, Description, Status (active/deprecated) -->

## Pipeline Databases
- **viroprofiler-db** | raw | `$HOME/viroprofiler/` | All reference databases (CheckV, VirSorter2, DRAM, iPHoP, VIBRANT, vRefSeq, Kraken2, PHAMB, EggNOG) | active

## Test Data
- **test-samplesheet** | raw | `conf/test.config` references GitHub-hosted test data | 5 minimal samples for CI testing | active
- **stub-test-data** | raw | `tests/data/` | Minimal FASTQ.GZ (PE + SE) + FASTA for Nextflow `-stub` CI testing (no databases needed); samplesheets use relative paths (work both locally and on CI) | active
