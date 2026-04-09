# PLAN

## Session S-2026-04-09-001
**Date:** 2026-04-09
**Objective:** Branch consolidation and project setup

### Tasks
- [x] Analyze branch structure and divergence (2026-04-09)
- [x] Create unified dev_ru branch from origin/dev (2026-04-09)
- [x] Merge origin/se into dev_ru (2026-04-09)
- [x] Squash 20 commits into 1 on dev_ru (2026-04-09)
- [x] Rebase dev_ru onto latest main (2026-04-09)
- [x] Delete stale remote branches (origin/dev, origin/se, origin/dev-update_ncbi_taxa) (2026-04-09)
- [x] Delete local dev branch (2026-04-09)
- [x] Create CLAUDE.md (2026-04-09)
- [x] Initialize pm context system (2026-04-09)
- [x] Full pipeline audit — identified 4 CRITICAL, 5 HIGH, 4 MEDIUM, 3 LOW issues (2026-04-09)
- [x] Fix all CRITICAL issues: BRACKEN syntax, VAMB emit, VRHYME container/sed, TODO cleanup (2026-04-09)
- [x] Fix all HIGH issues: SE mapping, contig_anno clustering, Python regex/pandas (2026-04-09)
- [x] Fix MEDIUM issues: manifest version, process resources, viewer container tag (2026-04-09)
- [x] Fix Dockerfile: binning Python path (2026-04-09)
- [x] Fix remaining Dockerfiles with hardcoded Python paths (geneannot, replicyc, taxa) — dynamic site.getsitepackages() (2026-04-09)
- [ ] Re-enable Docker CI workflow (.github/workflows/docker.yml)
- [ ] Commit and push all fixes to dev_ru
- [ ] Run test profile to validate pipeline
- [x] Design and implement Nextflow stub testing framework (2026-04-09)
- [x] Add stub blocks to all 45 processes (39 local + 6 nf-core) (2026-04-09)
- [x] Create test infrastructure: tests/data/, conf/test_stub.config, .github/workflows/stub_test.yml (2026-04-09)
- [x] Validate stub tests locally: VIROPROFILER 25/25 ✔, CONTIGANNO 15/15 ✔ (2026-04-09)
- [x] Apply /simplify review fixes: correct stub bugs (abricate filenames/header, abundance CONTIGINDEX versions.yml, VIRSORTER2 creation order); split CI into 2 parallel jobs; replace sed with envsubst; re-validated 25/25 + 15/15 ✔ (2026-04-09)
- [x] Full pipeline improvement audit — generated 18-item suggestions doc (CRITICAL/HIGH/MEDIUM/LOW) (2026-04-09)
- [x] Fix BUG-001: parse_mmseqsTaxa.py Strain KeyError crash on ICTV database (2026-04-09)
- [x] Fix BUG-002: CHECKV while loop `sleep 1` debug residue (2026-04-09)
- [x] Fix BUG-003 + DOCKER-002: taxa Dockerfile — dynamic Python path + remove redundant ASan MMseqs2 source build (2026-04-09)
- [x] Fix SCRIPT-001: normalize_abundance.py vectorized coverage fraction filter (50× speedup) (2026-04-09)
- [x] Fix SCRIPT-002: parse_mmseqsTaxa.py log unclassified contig count (2026-04-09)
- [x] Fix CONFIG-001: max_cpus 1→16, max_memory 8→128 GB, max_time 12→120 h (2026-04-09)

### Blockers
- None

---

## Session S-2026-04-09-002
**Date:** 2026-04-09
**Objective:** Docker CI 恢复、剩余改进项、commit & push

### Tasks
- [ ] Re-enable Docker CI workflow (.github/workflows/docker.yml) — 取消注释全部 11 个镜像构建条目
- [ ] Commit and push all fixes to dev_ru
- [ ] LOGIC-001: 确认 contig_anno.nf 是否需要补全 RESULTS_TSE 调用（或更新文档说明其局限）
- [ ] CONFIG-002: 审查 WorkflowMain.groovy / WorkflowViroprofiler.groovy 中被注释的参数验证逻辑，决定是否恢复
- [ ] DOCKER-003: viroprofiler-virsorter2 Dockerfile 取消注释 micromamba clean 行
- [ ] CI-002: 考虑添加 .github/workflows/lint.yml（nf-core lint + ruff check bin/）
- [ ] Run test profile to validate pipeline

### Blockers
- None
