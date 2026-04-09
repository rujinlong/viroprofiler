# ROADMAP

## Validated
<!-- Methods and approaches confirmed to work well -->
- Systematic pipeline audit (3 parallel Explore agents: workflow syntax, containers/scripts, cross-references) — effective for catching CRITICAL/HIGH bugs before runtime
- Nextflow stub mode (`-stub` flag) with POSIX-only stub blocks — validates full pipeline topology (channel connections, emit names, output file glob matching) in ~3 minutes without any databases or containers; 51/51 processes covered across 5 CI jobs (PE, SE, CONTIGANNO, DB setup, optional modules)
- /simplify three-agent review (reuse, quality, efficiency) on documentation changes — effective at catching factual errors (CI badge URL mismatch), orphaned assets (unreferenced images), and correctness issues (printf format specifiers, trailing newlines)

## Pending
<!-- Methods to evaluate in future sessions -->
- Single-end reads support (merged from origin/se, needs testing)
- Contig annotation workflow (contig_anno.nf, needs validation)

## Rejected
<!-- Methods tried and abandoned, with reasons -->
