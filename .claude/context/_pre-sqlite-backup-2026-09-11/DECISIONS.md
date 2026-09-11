# DECISIONS

<!-- Format: DEC-NNN, Date, Decision, Chosen Option, Rejected Alternatives, Rationale -->
<!-- Newest entries at top -->

## DEC-001
**Date:** 2026-04-09
**Decision:** Unified development branch strategy
**Chosen Option:** Single `dev_ru` branch based on origin/dev, rebased onto main
**Rejected Alternatives:** Keep multiple dev branches (dev, se, dev-update_ncbi_taxa); merge all into main directly
**Rationale:** Multiple divergent branches caused confusion. origin/dev was the most complete development line. Local dev had no unique content not already in origin/dev. Consolidating to dev_ru with periodic rebase onto main prevents future divergence.
