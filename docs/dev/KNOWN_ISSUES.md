# Known Issues — 2026 Modernization Audit

Running log of every defect found while redeploying ViroProfiler `dev_ru` on a fresh
machine (NVIDIA DGX Spark, aarch64/GB10, Apptainer 1.5.2, Nextflow 26.04.3, 2026-08-12).

Bugs are recorded first and fixed in batches; the `Status` column tracks that.
Severity: **P0** blocks any run · **P1** blocks a common use case · **P2** correctness or
usability defect · **P3** hygiene.

| ID | Severity | Area | Status |
|----|----------|------|--------|
| [I-01](#i-01) | P0 | Containers — amd64-only images | Open |
| [I-02](#i-02) | P0 | Containers — `viroprofiler-viewer` has no Dockerfile | Open |
| [I-03](#i-03) | P0 | Config — `params.db` never bind-mounted into containers | Open |
| [I-04](#i-04) | P1 | Test data — stub samplesheet uses launch-dir-relative paths | Open |
| [I-05](#i-05) | P1 | Config — `params.tracedir` frozen to the default `outdir` | Open |
| [I-06](#i-06) | P1 | Databases — iPHoP DB directory name hardcoded and stale | Open |
| [I-07](#i-07) | P1 | Databases — Bracken/Kraken2 DB paths disagree | Open |
| [I-08](#i-08) | P2 | Databases — NCBI taxonomy pinned to a 2022 archive snapshot | Open |
| [I-09](#i-09) | P2 | Databases — VOGDB host renamed; plain-HTTP URL | Open |
| [I-10](#i-10) | P2 | Databases — setup steps are not resumable and never verified | Open |
| [I-11](#i-11) | P2 | Workflow — `--mode fastqc` / `fastp` / `contiglib` not honoured | Open |
| [I-12](#i-12) | P2 | Config — `docker.userEmulation` removed in modern Nextflow | Open |
| [I-13](#i-13) | P3 | Repo — stub output directories committed despite `.gitignore` | Open |
| [I-14](#i-14) | P3 | Docs — `CLAUDE.md` references an MCP server that is not part of the repo | Open |

---

<a id="i-01"></a>
## I-01 — All 11 container images are amd64-only (P0)

`docker manifest inspect` on every image referenced by `conf/modules.config` returns a
single-architecture amd64 manifest:

```
denglab/viroprofiler-base:v0.2           amd64
denglab/viroprofiler-abundance:v0.2      amd64
denglab/viroprofiler-bracken:v0.2        amd64
denglab/viroprofiler-vibrant:v0.2        amd64
denglab/viroprofiler-binning:v0.2        amd64
denglab/viroprofiler-geneannot:v0.2      amd64
denglab/viroprofiler-host:v0.2.6         amd64
denglab/viroprofiler-replicyc:v0.1       amd64
denglab/viroprofiler-taxa:v0.1           amd64
denglab/viroprofiler-virsorter2:v0.2.5   amd64
denglab/viroprofiler-viewer:v0.2         amd64
```

The four vendored nf-core modules (FASTQC, FASTP, SPADES, MULTIQC) pull
`quay.io/biocontainers/*`, which are likewise amd64-only.

**Impact.** The pipeline cannot start on any arm64 host (Apple silicon, AWS Graviton,
NVIDIA GB10/GB200, Ampere). Apptainer fails with `Exec format error` unless a
`binfmt_misc` QEMU interpreter is registered, and emulation is not a supportable answer for
multi-threaded native aligners.

**Decision.** Publish arm64 builds from the Dockerfiles already in `docker/`.

**Known obstacles for the arm64 rebuild** (from `api.anaconda.org`, 2026-08-12):

| Package | linux-aarch64 in bioconda? |
|---------|---------------------------|
| `mmseqs2`, `spades`, `fastp`, `bbmap`, `seqkit`, `prodigal-gv`, `bowtie2`, `coverm` | yes |
| `virsorter` | no — `linux-64` + `noarch` only |
| `fastqc`, `abricate`, `eggnog-mapper`, `multiqc` | no — `linux-64` + `noarch` only |
| `checkv`, `vibrant`, `vcontact2`, `iphop`, `bacphlip`, `replidec`, `vrhyme` | `noarch` (installable, but their compiled dependencies must resolve) |
| `deepvirfinder` | not in bioconda at all (comes from the `hcc` channel) |

`docker/viroprofiler-taxa/Dockerfile` additionally downloads
`mmseqs-linux-avx2.tar.gz`, an x86-64 binary that has no arm64 equivalent under that name.

<a id="i-02"></a>
## I-02 — `viroprofiler-viewer` image has no Dockerfile in this repo (P0 for rebuilds)

`conf/modules.config` maps `withLabel: viroprofiler_vpfkit` to
`denglab/viroprofiler-viewer:v0.2`, which `RESULTS_TSE` (`modules/local/base.nf`) uses to
build the final TreeSummarizedExperiment. There is no `docker/viroprofiler-viewer/`
directory, so the image cannot be rebuilt or audited from this repository. The label name
(`vpfkit`) and the image name (`viewer`) also disagree, which makes the mapping hard to
follow.

<a id="i-03"></a>
## I-03 — `params.db` is used inside containers but never bind-mounted (P0)

Thirteen call sites reference the database root as a bare path inside a container script,
for example:

- `modules/local/viral_detection.nf:22,26,81,160`
- `modules/local/annotation.nf:21,22,62,85,107`
- `modules/local/taxonomy.nf:61,65,66`
- `modules/local/viral_host.nf:18`
- `modules/local/bracken.nf:27`

`params.db` is a plain string, not a staged Nextflow input, so `singularity.autoMounts` /
`apptainer.autoMounts` do not mount it. Nothing in `nextflow.config` adds a bind either —
the only bind directives in the repository live in the untracked, site-specific
`custom.config`.

**Impact.** The default `--db $HOME/viroprofiler` works only by accident, because Apptainer
mounts `$HOME` by default. Any user who follows the documentation and puts the databases on
a scratch or project filesystem (`--db /mnt/scratch/db/viroprofiler`,
`--db /scratch/$USER/db`, …) gets "No such file or directory" from inside every container.
This is a strong candidate for the failure users have been reporting.

<a id="i-04"></a>
## I-04 — Stub samplesheet paths resolve against the launch directory (P1)

`tests/data/samplesheet_stub.csv` and `samplesheet_stub_se.csv` list
`tests/data/stub_R1.fastq.gz`. Nextflow resolves a relative `file()` path against
`launchDir`, not `projectDir`, so the stub test only works when it is launched from the
repository root:

```
ERROR ~ No such file or directory: <launchDir>/tests/data/stub_R1.fastq.gz
 -- Check script 'subworkflows/local/input_check.nf' at line: 14
```

Introduced by commit `b7689d1` ("use relative paths in stub samplesheet for local
compatibility"). The CI workflow happens to run from the repo root, so CI never caught it.

<a id="i-05"></a>
## I-05 — `params.tracedir` captures the default `outdir` (P1)

`nextflow.config:88` defines `tracedir = "${params.outdir}/pipeline_info"` inside the same
`params` block that defines `outdir`. The GString is interpolated when the block is parsed,
before any profile or `--outdir` on the command line is applied. Running with
`-profile test_stub` (which sets `outdir = "output_stub"`) still reports
`tracedir : output/pipeline_info`, and the timeline/report/trace/DAG files are written to
the wrong tree — or fail to render at all:

```
WARN: Failed to render execution report -- see the log file for details
WARN: Failed to render execution timeline -- see the log file for details
```

<a id="i-06"></a>
## I-06 — iPHoP database directory name is hardcoded and inconsistent (P1)

- `modules/local/viral_host.nf:18` passes `--db_dir ${params.db}/iphop/Aug_2023_pub_rw`.
- `modules/local/setup_db.nf` (`DB_IPHOP`) runs `iphop download -d $params.db/iphop -n` and
  then deletes `${params.db}/iphop/iPHoP_db_Sept21.tar.gz`.

The setup step therefore cleans up an artefact from the *September 2021* release while the
analysis step expects the *August 2023* directory. Whichever release `iphop download`
currently fetches, at most one of the two is right, and the layout is not verified after
download. iPHoP host prediction is on by default (`use_iphop = true`), so this breaks the
default configuration.

<a id="i-07"></a>
## I-07 — Bracken and Kraken2 database paths disagree (P1)

`DB_KRAKEN2` builds into `${params.db}/kraken2/...`, `workflows/viroprofiler.nf:255` passes
`"${params.db}/kraken2"` to `BRACKEN`, but `modules/local/bracken.nf:27` links
`${params.db}/bracken/taxonomy/*`. The `bracken` subdirectory is never created by any setup
process. Only reachable with `--use_kraken2 true`, hence P1 rather than P0.

<a id="i-08"></a>
## I-08 — NCBI taxonomy pinned to the 2022-08-01 archive (P2)

`DB_VREFSEQ` downloads
`https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump_archive/taxdmp_2022-08-01.zip`. The URL still
resolves (HTTP 200 as of 2026-08-12), so this is not a dead link, but every ViroProfiler
installation is silently frozen to a four-year-old taxonomy. Taxa described since 2022 —
including the entire post-2022 ICTV phage reclassification — cannot be assigned.

<a id="i-09"></a>
## I-09 — VOGDB host renamed; URL is plain HTTP (P2)

`DB_VOGDB` fetches `http://fileshare.csb.univie.ac.at/vog/latest/vog.hmm.tar.gz`, which now
redirects to `https://fileshare.lisc.univie.ac.at/vog/latest/vog.hmm.tar.gz`. It works today
only because `wget` follows the redirect; the canonical URL should be used directly, over
HTTPS. `latest` is also unpinned, so runs are not reproducible across time.

The other external URLs were re-verified on 2026-08-12 and all return HTTP 200:
Zenodo record 7044674 (`mmseqs_vrefseq.tar.gz`), the phamb `RF_model.sav` on
`raw.githubusercontent.com`, and the miComplete `Bact105.hmm` on Bitbucket.

<a id="i-10"></a>
## I-10 — Database setup is not resumable and never verified (P2)

Every process in `modules/local/setup_db.nf` follows the same pattern:

```groovy
if [ ! -d ${params.db}/<tool> ]; then <download> ; else echo "already exists" ; fi
```

Consequences:

1. **Interrupted downloads are treated as success.** The guard tests only for directory
   existence. A download killed halfway leaves the directory in place, so every later run
   skips it and the pipeline fails much later with a confusing tool-level error.
2. **No checksum or content validation.** Nothing confirms that the expected files landed.
3. **No declared outputs.** The processes have neither `input:` nor `output:` blocks and
   write outside the task work directory, so `-resume` cannot reason about them and
   Nextflow's provenance tracking does not cover the databases.
4. **`DB_VIROPROFILER` is a stub that prints "Please download checkv database manually".**
   It is dead code — never included by `subworkflows/local/init.nf`.

<a id="i-11"></a>
## I-11 — `--mode fastqc` / `fastp` / `contiglib` are not implemented (P2)

`nextflow.config:15` and the documentation advertise
`mode = ["setup", "fastqc", "fastp", "contiglib", "all"]`, but
`workflows/viroprofiler.nf` only branches on `setup` and `all`. Any other value runs
everything up to and including `CONTIGLIB_CLUSTER` and then silently stops, so
`--mode fastqc` still runs assembly and CheckV. The advertised early-exit modes do not
exist.

<a id="i-12"></a>
## I-12 — `docker.userEmulation` was removed from Nextflow (P2)

`nextflow.config:144` sets `docker.userEmulation = true`. The option was deprecated in
Nextflow 23.x and removed in 24.x; `manifest.nextflowVersion` still claims `>=22.04.0`.
Users on a current Nextflow release who pick `-profile docker` hit an unknown-option error.
The manifest's version floor needs to state a range this pipeline has actually been tested
against.

<a id="i-13"></a>
## I-13 — Stub output directories are committed (P3)

`.gitignore` lists `output_stub*`, yet 121 files under `output_stub_v2/` and
`output_stub_contiganno_v2/` are tracked in git — they were added before the ignore rule.
They are run artefacts, not fixtures, and they inflate every clone.

<a id="i-14"></a>
## I-14 — `CLAUDE.md` mandates an MCP server that is not part of the repo (P3)

`CLAUDE.md` instructs assistants to "ALWAYS use the code-review-graph MCP tools BEFORE
using Grep/Glob/Read". That server is a local, personal setup; it is not configured in this
repository and is unavailable in a clean checkout, so the instruction misfires for every
other contributor.
