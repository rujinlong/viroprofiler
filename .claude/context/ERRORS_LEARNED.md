# ERRORS LEARNED

<!-- Format: EL-NNN, Date, Context, Error/Symptom, Root Cause, Fix, Prevention Rule, Tag, Reusability -->
<!-- Newest entries at top -->

## EL-009
**Date:** 2026-04-09
**Context:** Dockerfile viroprofiler-geneannot — COPY + dynamic path
**Error/Symptom:** `COPY ./path/file /opt/conda/lib/python3.10/site-packages/pkg/` — Dockerfile `COPY` instruction does not support shell variable expansion, so hardcoded Python version paths will break when conda resolves a different version.
**Root Cause:** Docker `COPY` destination is evaluated at build time without shell; cannot use `$(...)` expansion.
**Fix:** `COPY ./path/file /tmp/file` then `RUN SITE_PKGS=$(python3 -c "import site; print(site.getsitepackages()[0])") && cp /tmp/file $SITE_PKGS/pkg/`
**Prevention Rule:** Never use Python version paths in Dockerfile `COPY` destinations; always COPY to `/tmp/` first, then use a `RUN` layer with `site.getsitepackages()` to move to the correct location.
**Tag:** docker, python, path, COPY
**Reusability:** high

## EL-008
**Date:** 2026-04-09
**Context:** bin/parse_mmseqsTaxa.py — column selection after commented-out initialization
**Error/Symptom:** `df_formatted[['contig_id', ..., 'Strain']]` raises `KeyError: 'Strain'` at runtime when `dbsource == "ICTV"`. No error at import time.
**Root Cause:** The code block that populates the `'Strain'` column (lines 24-30) was commented out, but the column reference in the selector (line 79) was not updated to match.
**Fix:** Remove `'Strain'` from the column selector in line 79 (or restore the extraction logic if Strain is needed).
**Prevention Rule:** When commenting out initialization logic that creates a new column/variable, grep for all downstream references and update or remove them atomically.
**Tag:** python, pandas, commented-code
**Reusability:** high

## EL-007
**Date:** 2026-04-09
**Context:** VIRSORTER2 process stub block
**Error/Symptom:** VIRSORTER2 script uses `ln -s out_vs2/for-dramv/file .` to create top-level symlinks. In stub mode, the source directory doesn't exist, so `ln -s` would fail.
**Root Cause:** Symlinks require source files to exist; in stub mode there are no real tool outputs
**Fix:** Create actual files directly at the expected paths (`cp` instead of `ln -s`) in the stub block
**Prevention Rule:** In Nextflow stub blocks, replace `ln -s` with direct file creation (`cp` or `printf`) — symlinks require source files that don't exist in stub context
**Tag:** nextflow, stub, symlink
**Reusability:** high

## EL-006
**Date:** 2026-04-09
**Context:** VIBRANT process stub + VIRCONTIGS_PRE dependency
**Error/Symptom:** VIBRANT emits `path("VIBRANT_*")` (entire directory), but VIRCONTIGS_PRE directly accesses `${vibrant_dir}/VIBRANT_phages_contigs/contigs.phages_combined.fna` at line 144. A stub that only `touch`es top-level files would make this downstream access fail.
**Root Cause:** Directory emit hides the fact that downstream processes access specific deep paths inside the emitted directory
**Fix:** Stub block must replicate the complete directory structure with all files that downstream processes actually access
**Prevention Rule:** When a process emits a directory, grep all downstream process scripts for paths into that directory — stub must create every accessed path
**Tag:** nextflow, stub, directory-emit, vibrant
**Reusability:** high

## EL-005
**Date:** 2026-04-09
**Context:** Dockerfile for viroprofiler-binning
**Error/Symptom:** `python3.1` in site-packages path — clearly a typo (should be 3.10 or 3.11)
**Root Cause:** Hardcoded Python version path instead of dynamic detection
**Fix:** Use `$(python3 -c "import site; print(site.getsitepackages()[0])")` for dynamic path
**Prevention Rule:** Never hardcode Python version paths in Dockerfiles; always use dynamic detection via `site.getsitepackages()`
**Tag:** docker, python, path
**Reusability:** high

## EL-004
**Date:** 2026-04-09
**Context:** bin/normalize_abundance.py
**Error/Symptom:** `df.applymap()` will fail with pandas >= 2.1.0
**Root Cause:** API deprecated in pandas 2.0, removed in 2.1
**Fix:** Replace `applymap` with `map` (DataFrame.map was added as replacement)
**Prevention Rule:** Check pandas deprecation warnings when using DataFrame methods; `applymap` -> `map`, `append` -> `concat`
**Tag:** python, pandas, deprecation
**Reusability:** high

## EL-003
**Date:** 2026-04-09
**Context:** modules/local/abundance.nf MAPPING2CONTIGS2
**Error/Symptom:** Pipeline would crash on single-end data — `illumina[1]` index out of bounds
**Root Cause:** Defined SE/PE variable but hardcoded PE syntax in the actual command
**Fix:** Use the prepared `$illumina_reads` variable instead of hardcoded `-1 ${illumina[0]} -2 ${illumina[1]}`
**Prevention Rule:** When adding SE support to Nextflow processes, always verify the script block uses the conditional variable, not just the def line
**Tag:** nextflow, single-end, bowtie2
**Reusability:** high

## EL-002
**Date:** 2026-04-09
**Context:** modules/local/binning.nf VAMB process
**Error/Symptom:** `VAMB.out.vamb_clusters_ch` would fail — no named emit exists
**Root Cause:** VAMB outputs defined without `emit:` names, but subworkflow references named emit
**Fix:** Add `emit: vamb_clusters_ch` to the output declaration
**Prevention Rule:** When referencing process outputs by name (`.out.name`), always verify the process has a matching `emit:` declaration
**Tag:** nextflow, emit, channel
**Reusability:** high

## EL-001
**Date:** 2026-04-09
**Context:** workflows/viroprofiler.nf BRACKEN call
**Error/Symptom:** Groovy syntax error — unquoted string interpolation in function argument
**Root Cause:** `${params.db}/kraken2` passed without quotes — Groovy interprets this as code, not a string
**Fix:** Wrap in quotes: `"${params.db}/kraken2"`
**Prevention Rule:** In Nextflow/Groovy, always quote string interpolations when passing paths as process arguments
**Tag:** nextflow, groovy, syntax
**Reusability:** high
