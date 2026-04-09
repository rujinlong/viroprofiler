# ROADMAP

## Validated
<!-- Methods and approaches confirmed to work well -->
- Systematic pipeline audit (3 parallel Explore agents: workflow syntax, containers/scripts, cross-references) — effective for catching CRITICAL/HIGH bugs before runtime
- Nextflow stub mode (`-stub` flag) with POSIX-only stub blocks — validates full pipeline topology (channel connections, emit names, output file glob matching) in ~3 minutes without any databases or containers; VIROPROFILER: 25 processes, CONTIGANNO: 15 processes, both pass cleanly

## Pending
<!-- Methods to evaluate in future sessions -->
- Single-end reads support (merged from origin/se, needs testing)
- Contig annotation workflow (contig_anno.nf, needs validation)

## Rejected
<!-- Methods tried and abandoned, with reasons -->
