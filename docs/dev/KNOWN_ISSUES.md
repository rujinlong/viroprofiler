# Known Issues — 2026 Modernization Audit

Running log of every defect found while redeploying ViroProfiler `dev_ru` on a fresh
machine (NVIDIA DGX Spark, aarch64/GB10, Apptainer 1.5.2, Nextflow 26.04.3, 2026-08-12).

Bugs are recorded first and fixed in batches; the `Status` column tracks that.
Severity: **P0** blocks any run · **P1** blocks a common use case · **P2** correctness or
usability defect · **P3** hygiene.

| ID | Severity | Area | Status |
|----|----------|------|--------|
| [I-01](#i-01) | P0 | Containers — amd64-only images | Partly fixed — arm64 images build from `docker/`, except iPHoP. DeepVirFinder was retired in favour of geNomad, which builds on aarch64 |
| [I-02](#i-02) | P0 | Containers — `viroprofiler-viewer` has no Dockerfile | Fixed |
| [I-03](#i-03) | P0 | Config — `params.db` never bind-mounted into containers | Fixed |
| [I-04](#i-04) | P1 | Test data — stub samplesheet uses launch-dir-relative paths | Fixed |
| [I-05](#i-05) | P1 | Config — `params.tracedir` frozen to the default `outdir` | Fixed |
| [I-06](#i-06) | P1 | Databases — iPHoP DB directory name hardcoded and stale | Fixed |
| [I-07](#i-07) | P1 | Databases — Bracken/Kraken2 DB paths disagree | Fixed |
| [I-08](#i-08) | P2 | Databases — NCBI taxonomy pinned to a 2022 archive snapshot | Fixed — its only consumer, the MMseqs2 LCA, was retired and `DB_VREFSEQ` deleted |
| [I-09](#i-09) | P2 | Databases — VOGDB host renamed; plain-HTTP URL | Open |
| [I-10](#i-10) | P2 | Databases — setup steps are not resumable and never verified | Open |
| [I-11](#i-11) | P2 | Workflow — `--mode fastqc` / `fastp` / `contiglib` not honoured | Fixed |
| [I-12](#i-12) | P2 | Config — `docker.userEmulation` removed in modern Nextflow | Fixed |
| [I-13](#i-13) | P3 | Repo — stub output directories committed despite `.gitignore` | Open |
| [I-14](#i-14) | P3 | Docs — `CLAUDE.md` references an MCP server that is not part of the repo | Fixed |
| [I-15](#i-15) | P1 | Config — `contamref_idx` ignores `--db` and nothing ever creates it | Partly fixed — follows `--db`, still not built by setup |
| [I-16](#i-16) | P1 | Config — `modules.config` loaded after `profiles`, so containers were unoverridable | Fixed |
| [I-17](#i-17) | P2 | Containers — Dockerfiles call `wget` that is only present transitively | Fixed |
| [I-18](#i-18) | P2 | Containers — DeepVirFinder bundled into the binning image | Fixed |
| [I-19](#i-19) | P2 | Modules — vendored nf-core modules and their containers are from 2022 | Open |
| [I-20](#i-20) | P3 | Assets — `samplesheet_contigs.csv` contains a literal `${HOME}` | Open |
| [I-21](#i-21) | P1 | Containers — 2022-era tools break on modern Python/setuptools | Fixed |
| [I-22](#i-22) | P0 | Containers — DRAM 1.4 source file copied over a DRAM 1.3.5 install | Fixed |
| [I-23](#i-23) | P1 | Databases — DRAM `CONFIG` hand-written from 2021 filenames and today's date | Fixed |
| [I-24](#i-24) | P0 | Modules — `DRAMV` writes a symlink into the container image | Fixed |
| [I-25](#i-25) | P1 | Containers — eggNOG-mapper 2.1.9 needs `distutils`, gone in Python 3.12 | Fixed |
| [I-26](#i-26) | P0 | Databases — VIBRANT setup reports success with an unusable database | Fixed |
| [I-27](#i-27) | P1 | Containers — iPHoP built from bioconda carries three known defects | Fixed |
| [I-28](#i-28) | P0 | Databases — DRAM's dbCAN downloads return an HTML landing page | Fixed |
| [I-29](#i-29) | P1 | Databases — DRAM setup cannot tell a finished database from an abandoned one | Fixed |
| [I-30](#i-30) | P0 | Databases — VOGDB moved its profiles into a subdirectory; DRAM builds an empty HMM file | Fixed |
| [I-31](#i-31) | P1 | Databases — files unpacked by tar can land unreadable by their own owner | Fixed |
| [I-32](#i-32) | P1 | Modules — vConTACT2 taxonomy derived from a SPAdes naming convention | Fixed — replaced by vConTACT3 |
| [I-33](#i-33) | P0 | Containers — `RESULTS_TSE` cannot read its own gzipped abundance inputs | Open |
| [I-34](#i-34) | P2 | Modules — `-max_target_seqs` makes contig dereplication depend on library size | Fixed — BLAST chain replaced by Vclust |
| [I-35](#i-35) | P3 | Modules — exact duplicate contigs entered the O(n²) dereplication stage | Fixed |
| [I-36](#i-36) | P1 | Modules — `PHAMB_RF` calls a CLI the installed phamb does not have | Fixed |
| [I-37](#i-37) | P0 | Containers — `run_RF.py` copied onto PATH cannot find its own model | Fixed |
| [I-38](#i-38) | P0 | Containers — the binning image never installed VAMB | Fixed on amd64; VAMB has no aarch64 build |
| [I-39](#i-39) | P1 | Containers — the binning image's second `vrhyme` prefix had drifted to Python 3.14 | Fixed |
| [I-40](#i-40) | P2 | Modules — `VAMB` was given a depth table covering contigs its FASTA does not contain | Fixed |
| [I-41](#i-41) | P3 | Config — `CONTIGLIB_CLUSTER` requested one CPU while Vclust threads every stage | Fixed |
| [I-42](#i-42) | P0 | Containers — conda post-link scripts are not run by pixi, leaving a data package uninstalled | Fixed |
| [I-43](#i-43) | P0 | Containers — the VAMB version pinned has no `--jgi`, the flag the process passes | Fixed |
| [I-44](#i-44) | P1 | Modules — VAMB's `--jgi` pairs depths to contigs by row, not by name | Fixed |
| [I-45](#i-45) | P0 | Config — the pipeline does not parse under Nextflow's default config parser | Fixed |
| [I-46](#i-46) | P1 | Modules — iPHoP, CheckAMG and DRAM-v results never reached `RESULTS_TSE` | Fixed |
| [I-47](#i-47) | P2 | Config — 432 lines of iGenomes reference config that nothing reads | Fixed |
| [I-48](#i-48) | P1 | Config — a scheduler's `TMPDIR` points outside the container, and DRAM-v dies on it | Fixed |
| [I-49](#i-49) | P2 | Workflow — the completion summary was printed twice on every run | Fixed |
| [I-50](#i-50) | P0 | Config — a boolean given on the command line arrived as a string, and `"false"` is true | Fixed |
| [I-51](#i-51) | P1 | Config — `process.resourceLimits` above the `profiles` block ignores every profile | Fixed |

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
| `checkv`, `vibrant`, `iphop`, `bacphlip`, `replidec`, `vrhyme` | `noarch` (installable, but their compiled dependencies must resolve) |
| `vcontact3` | no — and two of its dependencies have no aarch64 conda build either ([I-32](#i-32)) |
| `deepvirfinder` | not in bioconda at all (comes from the `hcc` channel) |

The retired `docker/viroprofiler-taxa/Dockerfile` additionally downloaded
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

`DB_VREFSEQ` downloaded
`https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump_archive/taxdmp_2022-08-01.zip`. The URL still
resolves (HTTP 200 as of 2026-08-12), so this was not a dead link, but every ViroProfiler
installation was silently frozen to a four-year-old taxonomy. Taxa described since 2022 —
including the entire post-2022 ICTV phage reclassification — could not be assigned.

**Resolution.** The snapshot existed for one consumer: `mmseqs createtaxdb`, which built the
LCA database `TAXONOMY_MMSEQS` searched. That module was the lowest-priority taxonomy source
of four, behind VITAP, geNomad and vConTACT3, and it has been retired along with
`DB_VREFSEQ`, `bin/parse_mmseqsTaxa.py` and `params.taxa_db_source`. VITAP and vConTACT3
carry their own reference sets, so nothing in the pipeline reads an NCBI taxdump any more.

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

`nextflow.config` and the documentation advertised
`mode = ["setup", "fastqc", "fastp", "contiglib", "all"]`, but
`workflows/viroprofiler.nf` only branched on `setup` and `all`. Any other value ran
everything up to and including `CONTIGLIB_CLUSTER` and then silently stopped, so
`--mode fastqc` still ran assembly and CheckV. The schema also defaulted `mode` to `test`,
a value the workflow never mentions.

**Resolution.** The stages are numbered in `WorkflowViroprofiler.MODE_STAGE` and each block
in the workflow is gated on that number, so a mode is a prefix of the pipeline rather than a
branch. `--mode fastqc` now runs 3 processes, `fastp` 4, `contiglib` 8 and `all` 26 on the
stub dataset. Reporting — `CUSTOM_DUMPSOFTWAREVERSIONS` and `MULTIQC` — runs in every mode,
so a run stopped early still says what it did. `initialise()` rejects an unknown mode, and
rejects `fastqc`/`fastp` together with `--reads_type clean`, which skips both stages and
would otherwise produce an empty run.

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

<a id="i-15"></a>
## I-15 — `contamref_idx` ignores `--db` and nothing ever creates it (P1)

`nextflow.config` defaults `contamref_idx = "${HOME}/viroprofiler/contamination_refs/hg19/ref"`.
Two problems:

1. The path is anchored to `$HOME`, not to `params.db`, so moving the databases with `--db`
   leaves the decontamination reference behind.
2. No process in `modules/local/setup_db.nf` builds a `contamination_refs` index, and
   `--mode setup` never mentions it. `--use_decontam true` therefore fails on a clean
   installation with a bare Nextflow file-not-found:

```
ERROR ~ No such file or directory: /home/<user>/viroprofiler/contamination_refs/hg19/ref
```

The default should follow `params.db`, resolved lazily, and either a setup process should
build the index or the failure should carry an actionable message.

<a id="i-16"></a>
## I-16 — `conf/modules.config` was loaded after `profiles` (P1)

`includeConfig 'conf/modules.config'` sat at the bottom of `nextflow.config`, after the
`profiles` block. In Nextflow the later include wins, so the container assignments in
`modules.config` overrode anything a profile set. No profile could redirect the pipeline to
a different registry, a local mirror, or a locally built image — an offline or
air-gapped cluster had no supported way to substitute images.

Moving the include above `profiles` makes profile overrides possible; `conf/arm64_local.config`
relies on it.

<a id="i-17"></a>
## I-17 — Dockerfiles call `wget` that was only present transitively (P2)

`docker/viroprofiler-taxa/Dockerfile` and `docker/viroprofiler-binning/Dockerfile` download
reference data with `wget`, but neither `env_taxa.yml` nor `env_binning.yml` listed it — the
binary arrived as an incidental dependency of a pinned package. As soon as the solve
changes, the build fails late with `wget: command not found` (exit 127) after the multi-GB
conda step. `wget` is now declared explicitly.

<a id="i-18"></a>
## I-18 — DeepVirFinder was bundled into the binning image (P2)

`docker/viroprofiler-binning/Dockerfile` created a second conda environment from
`env_dvf.yml`, which pins `theano=1.0.3` and `keras=2.2.4` — both frozen to 2018, and
`theano` has no `linux-aarch64` build at all. One unmaintained tool therefore made the whole
binning image (metabat2, vRhyme, phamb) unbuildable on arm64.

DeepVirFinder now lives in `docker/viroprofiler-dvf/`, and the `DVF` process carries its own
`viroprofiler_dvf` label. This changes nothing for amd64 users beyond one extra image.

<a id="i-19"></a>
## I-19 — Vendored nf-core modules and their containers are from 2022 (P2)

`modules/nf-core/modules/` pins FastQC 0.11.9, fastp 0.23.2, SPAdes 3.15.4 and MultiQC 1.12
against `quay.io/biocontainers`, which publishes amd64 only. They also use the pre-nf-core-3
`conda (params.enable_conda ? ... : null)` idiom, and `params.enable_conda` is itself
deprecated. Current bioconda has FastQC 0.12.1, fastp 1.3.6, SPAdes 4.3.0 and MultiQC 1.35,
all with `linux-aarch64` builds.

<a id="i-20"></a>
## I-20 — `assets/samplesheet_contigs.csv` contains a literal `${HOME}` (P3)

```
sample,contigs
contigs,${HOME}/viroprofiler/testdata/viroprofiler-test/contigs.fasta
```

`splitCsv` does no shell expansion, so this resolves to a directory literally named `${HOME}`.
The file is also unused: contig-only runs are driven by `--input_contigs`, not by a
samplesheet.

<a id="i-21"></a>
## I-21 — 2022-era tools break on a modern Python/setuptools (P1)

Loosening the conda pins so the environments solve on `linux-aarch64` also lets the solver
pick current Python and setuptools, and three tools break there:

| Tool | Failure |
|------|---------|
| VirSorter2 2.2.4 | `ImportError: cannot import name 'load_configfile' from 'snakemake'` — removed in snakemake 8 |
| DRAM 1.3.5 | `ModuleNotFoundError: No module named 'pkg_resources'` on Python 3.14 |
| vConTACT2 0.11.3 | same `pkg_resources` failure |

`pkg_resources` cannot be restored just by adding `setuptools`: setuptools 81 dropped it, and
the solver picks 84 by default. The environments therefore pin `python=3.10` and
`setuptools<81`, and VirSorter2 now comes from bioconda instead of a `pip install -e` of git
master, so its recipe constrains snakemake for us.

Upgrading DRAM to 1.4.6 does not lift its half of this: `mag_annotator/database_handler.py`
still opens with `from pkg_resources import resource_filename`, so `setuptools<81` stays.

This is the general hazard when reviving a pipeline whose environments were captured in
2022: an unpinned solve is not a "newer, better" environment, it is an untested one.

<a id="i-22"></a>
## I-22 — A DRAM 1.4 source file was copied over a DRAM 1.3.5 install (P0)

`docker/viroprofiler-geneannot/Dockerfile` copied a vendored `database_handler.py` over
`mag_annotator/database_handler.py`, but `env_dram.yml` left `dram` unpinned and the solver
resolved 1.3.5. The vendored file is from 1.4.x and imports a helper that does not exist in
1.3.5, so every `DRAM-setup.py` invocation died on import:

```
File ".../mag_annotator/database_handler.py", line 17, in <module>
    from mag_annotator.utils import divide_chunks, setup_logger
ImportError: cannot import name 'setup_logger' from 'mag_annotator.utils'
```

The environment now pins DRAM 1.4.6, whose own `database_handler.py` is byte-identical to
the vendored copy (`diff` reports only a missing trailing newline). Both the overlay file
and its `database_handler_bak.py` sibling are deleted along with the `COPY`/`cp` steps.

DRAM 1.4.6 is installed with `pip install --no-deps DRAM-bio==1.4.6` rather than from
bioconda: every bioconda build of `dram 1.4.6` constrains `scikit-bio` to `<0.6`, and
conda-forge publishes no `scikit-bio` below 0.6.0 for `linux-aarch64`, so the conda solve is
unsatisfiable on arm64. bioconda builds that package from the same PyPI sdist, so the
installed code is identical; `env_dram.yml` now lists the run dependencies explicitly.

<a id="i-23"></a>
## I-23 — DRAM's `CONFIG` was hand-written from 2021 filenames and today's date (P1)

`bin/create_dram_config.py` wrote DRAM's `CONFIG` by hand before `DRAM-setup.py
prepare_databases` ran. It was wrong in three independent ways:

- **Stale filenames.** `dbCAN-HMMdb-V10.txt`, `CAZyDB.07292021.fam-activities.txt`,
  `vog_latest_hmms.txt` and friends are 2021 release names that DRAM 1.4 no longer produces.
- **Today's date baked into paths.** Entries such as `refseq_viral.{today}.mmsdb` only line
  up if `prepare_databases` finishes on the same calendar day the config was written.
- **Wrong schema.** DRAM 1.3 read a flat `{key: path}` dict; 1.4 uses a nested document with
  `search_databases` / `database_descriptions` / `dram_sheets` / `description_db` /
  `dram_version` keys. A flat file is routed through
  `DatabaseHandler.__construct_from_dram_pre_1_4_0()`, a legacy import path.

None of it is needed. `prepare_databases` builds a `DatabaseHandler`, calls `clear_config()`
and then `set_database_paths()` / `write_config()` after every single database it processes,
recording each `path.realpath()` as it goes. The only thing it cannot do is create the file:
`DatabaseHandler.load_config()` opens it unconditionally, so a missing
`DRAM_CONFIG_LOCATION` is a `FileNotFoundError`. `DB_DRAM` therefore seeds the file with
DRAM's own `DRAM-setup.py export_config --output_file`, which copies the empty template that
ships inside `mag_annotator`, and `bin/create_dram_config.py` is deleted.

`export_config` has to run with `DRAM_CONFIG_LOCATION` unset — it resolves its *source*
through the same `get_config_loc()`, so with the variable already exported it would try to
read the file it is supposed to create.

<a id="i-24"></a>
## I-24 — `DRAMV` created a symlink inside the container image (P0)

```
# Due to limitation of container, DRAM database path is hardset to /opt/conda/db2
ln -s ${params.db} /opt/conda/db2
```

Writing into `/opt/conda` needs a writable container filesystem. Under Apptainer and
Singularity that means `--writable-tmpfs`, which was only ever set in the untracked,
site-specific `custom.config`, so `DRAMV` could not run for anybody else.

The symlink is not needed at all. The `CONFIG` that `prepare_databases` writes holds
absolute paths under `--db`, and `--db` is bind-mounted into every task at the identical
path (see [I-03](#i-03)), so exporting `DRAM_CONFIG_LOCATION` is sufficient. Verified by
replaying the setup and annotate config paths in a `docker run --read-only` container: the
`ln -s` fails with `Read-only file system` while the rest of the chain succeeds and leaves
the in-image `mag_annotator/CONFIG` untouched.

One residual sharp edge: `set_database_paths()` stores `path.realpath()`, whereas the bind
mount is computed with Groovy's `getAbsolutePath()`, which does not resolve symlinks. A
`--db` that is itself a symlink will therefore be recorded under its resolved name and that
name will not be mounted.

<a id="i-25"></a>
## I-25 — eggNOG-mapper 2.1.9 needs `distutils`, removed in Python 3.12 (P1)

`env_emapper.yml` pinned only `eggnog-mapper=2.1.9`, so the solver picked Python 3.14 and
`emapper.py` could not start:

```
File ".../eggnogmapper/common.py", line 6, in <module>
    from distutils.spawn import find_executable
ModuleNotFoundError: No module named 'distutils'
```

`distutils` left the standard library in Python 3.12. The environment now pins
`python<3.12`. Same class of defect as [I-21](#i-21), in a second environment of the same
image.

<a id="i-26"></a>
## I-26 — VIBRANT setup reports success with an unusable database (P0)

`DB_VIBRANT` calls `download-db.sh`, whose last two lines are:

```bash
echo "VIBRANT databases are downloaded successfully. Please see log file for any error messages."

exit 0
```

The exit status is unconditional. On a first run against a filesystem that applies a
default ACL, the files `download-db.sh` copies out of the image land without owner read
permission, so `python VIBRANT_setup.py` never starts:

```
Set VIBRANT_DATA_PATH to <db>/vibrant
Downloading VIBRANT databases to <db>/vibrant...
python: can't open file 'VIBRANT_setup.py': [Errno 13] Permission denied
VIBRANT databases are downloaded successfully. Please see log file for any error messages.
```

The process exits 0 with a 4 MB directory instead of the expected ~11 GB of pressed HMM
profiles. Because the guard is `if [ ! -d <db>/vibrant ]`, every later run then skips the
step, and the pipeline fails much later inside VIBRANT itself with an unrelated-looking
error.

The setup step now builds into the task work directory, fixes permissions, asserts that
`VOGDB94_phage`, `KEGG_profiles_prokaryotes` and `Pfam-A_v32` all have a non-empty
`hmmpress` index, and only then publishes the directory.

The three sources `VIBRANT_setup.py` downloads from were re-checked on 2026-08-12 and all
resolve: the VOG host redirects `fileshare.csb.univie.ac.at` to
`fileshare.lisc.univie.ac.at`, and the Pfam and KEGG profile archives are reachable. Both
of the latter are fetched over `ftp://`, however, which many clusters block outbound; the
HTTPS mirrors `https://ftp.ebi.ac.uk/...` and `https://www.genome.jp/ftp/...` serve the
same files.

<a id="i-27"></a>
## I-27 — iPHoP built from bioconda carries three known defects (P1)

`docker/viroprofiler-host/` installed the bioconda `iphop` package, which ships:

1. `perl-bioperl<=1.7`, which excludes every build bioconda actually publishes (1.7.x). The
   solver silently skipped the package and RaFAH crashed at run time with
   `Can't locate Bio/SeqIO.pm in @INC`.
2. an unpinned `protobuf`, so pip resolves 5.x and TensorFlow 2.7 fails at import with
   `TypeError: Descriptors cannot be created directly`.
3. classifier weights tracked with Git LFS, so a plain checkout yields ~130-byte pointer
   files and the step-8 integrator dies in `tf.saved_model.load()`.

The image is now built from the hardened fork at `github.com/rujinlong/iphop`, pinned by
`ARG IPHOP_REF`, which fixes all three. It is amd64-only; see
[ARM64.md](ARM64.md).

Separately, `iphop --version` does not exist in any iPHoP release, so `versions.yml`
recorded an empty iPHoP version. The process now reads `iphop.__version__` instead.

<a id="i-28"></a>
## I-28 — DRAM's dbCAN downloads return an HTML landing page (P0)

`mag_annotator/database_processing.py` fetches all three dbCAN files from `bcb.unl.edu`.
That host now redirects every path below `/dbCAN2/download/` to the dbCAN home page and
answers `200`:

```
$ curl -sIL -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' \
    http://bcb.unl.edu/dbCAN2/download/dbCAN-HMMdb-V11.txt
200 text/html; charset=UTF-8 https://pro.unl.edu/dbCAN2/
```

`download_file()` uses `urlretrieve`, which treats that as a successful download and writes
the 8 KB landing page to `dbCAN-HMMdb-V11.txt`, `CAZyDB.08062022.fam-activities.txt` and
`CAZyDB.08062022.fam.subfam.ec.txt`. `hmmpress` at least rejects the first one; the other two
are description files that nothing validates, so they are parsed straight into
`description_db.sqlite` and every dbCAN annotation comes out as fragments of HTML.

The files themselves are unchanged and still published — only the host moved:

```
$ curl -sIL -o /dev/null -w '%{http_code} %{content_type}\n' \
    https://pro.unl.edu/dbCAN2/download/dbCAN-HMMdb-V11.txt
200 text/plain
```

`docker/viroprofiler-geneannot/Dockerfile` therefore rewrites the host in the installed
`mag_annotator`, and the same `RUN` asserts that the rewrite matched so a future DRAM
release cannot silently skip it. Patching the library is the last resort, but it is the only
option here: `prepare_databases()` collects user-supplied files with

```python
locs = {remove_suffix(i, '_loc'): j for i, j in locals().items() if i.endswith('_loc') and j is not None}
```

and neither `dbcan_fam_activities` nor `dbcan_subfam_ec` carries the `_loc` suffix, so
`--dbcan_fam_activities` is accepted and then ignored, and the sub-family EC file has no
command-line option at all. The same defect makes `--vog_annotations` a no-op.

Every other source DRAM 1.4.6 uses was re-checked at the same time and is alive
(2026-08-12). All of them are tried over `ftp://` first with an `http(s)://` fallback, and on
this network FTP is reachable for all three hosts, so both routes work:

| Database | URL | Status |
|----------|-----|--------|
| KOfam profiles, KO list | `ftp.genome.jp/pub/db/kofam/` | 200, ~8 MB/s over FTP |
| Pfam-A.full, Pfam-A.hmm.dat | `ftp.ebi.ac.uk/pub/databases/Pfam/current_release/` | 200, ~3 MB/s; `Pfam-A.full.gz` is 22.3 GiB |
| MEROPS pepunit.lib | `ftp.ebi.ac.uk/pub/databases/merops/current_release/` | 200, 436 MiB |
| RefSeq viral proteins | `ftp.ncbi.nlm.nih.gov/refseq/release/viral/` | 200; one `viral.N.protein.faa.gz` exists, which is what `NUMBER_OF_VIRAL_FILES = 1` expects |
| VOGDB hmms, annotations | `fileshare.csb.univie.ac.at/vog/latest/` | 301 to `fileshare.lisc.univie.ac.at`, followed automatically |
| DRAM distillation sheets | `raw.githubusercontent.com/WrightonLabCSU/DRAM/master/data/` | 200 |
| dbCAN HMMs, family activities, sub-family EC | `bcb.unl.edu/dbCAN2/download/` | **dead**, see above |

`DB_VOGDB` reaches the same VOGDB host over plain HTTP; that is tracked separately as
[I-09](#i-09).

<a id="i-29"></a>
## I-29 — DRAM setup cannot tell a finished database from an abandoned one (P1)

`DB_DRAM` guarded its work with `[ ! -d ${params.db}/dram ]`. `prepare_databases` downloads
and processes sixteen databases over several hours and cannot resume, so any interruption
leaves a directory that satisfies the guard forever: the next run prints "DRAM database
already exists", the pipeline reports success, and `DRAM-v.py annotate` fails much later
against a database that was never finished.

The guard is now a completeness check of the `CONFIG` that DRAM will actually read. Every
path it names must exist and be non-empty; none may begin with an HTML document (the failure
mode in [I-28](#i-28)); the sidecar files that mmseqs and HMMER need but the `CONFIG` does not
name must be present — `.h3f`/`.h3i`/`.h3m`/`.h3p` for the HMM databases, and for the mmseqs
ones both the `.idx*` k-mer index that `mmseqs search` needs and the `_h*` header database
that DRAM opens directly to turn a hit into a description; and every description table in
`description_db.sqlite` must have rows. The same check runs after the
build, so a database that fails it makes the process exit non-zero instead of being
published. An incomplete directory is deleted and rebuilt rather than reused.

The build now runs in the task work directory and is published to `${params.db}/dram` only
once it is complete, which is what `DB_VIBRANT` and `DB_VREFSEQ` already do and what
[I-31](#i-31) requires. Because `set_database_paths()` records every database under the path
it was built at, the `CONFIG` is repointed at the published location afterwards and then
re-checked.

That needs room: `mmseqs convertmsa` turns the 22.3 GiB `Pfam-A.full.gz` into a 143 GB
intermediate, and with the 25 GB of downloads and 25 GB of finished databases alongside it
the build peaks at about 190 GB. `DB_DRAM` refuses to start below 250 GB rather than fill the
filesystem two hours in.

`prepare_databases` never deletes the intermediates it feeds to a step that has finished, and
the `CONFIG` never refers to them, so `DB_DRAM` removes `pfam.mmsmsa`, the mmseqs `tmp`
directory and the unpacked KOfam and VOGDB profile trees before publishing. They are larger
than everything the build publishes put together.

`--skip_uniref` is kept: UniRef90 adds several hundred GB and DRAM's own documentation states
it does not affect distillation. KEGG is licensed and cannot be downloaded, so `kegg` and
`gene_ko_link` stay unset; DRAM substitutes KOfam for KEGG orthology.

<a id="i-30"></a>
## I-30 — VOGDB moved its profiles into a subdirectory and DRAM silently builds nothing (P0)

`vog.hmm.tar.gz` used to hold its profiles at the root of the archive. It now nests them:

```
$ tar -tzf vog.hmm.tar.gz | head -2
hmm/VOG00001.hmm
hmm/VOG00003.hmm
```

`process_vogdb()` unpacks the archive and then collects the profiles with
`glob(path.join(hmm_dir, 'VOG*.hmm'))`, which matches the top level only. It finds none of
the 49116 files, `merge_files()` writes a zero-byte `vog_latest_hmms.txt`, and `hmmpress`
stops with "File exists, but appears to be empty?" — two hours into the build, after Pfam has
been processed and with no way to resume.

`docker/viroprofiler-geneannot/Dockerfile` makes the glob recursive, so it no longer depends
on the archive's internal layout. `--vogdb_loc` is not a way out: DRAM unpacks whatever file
it is handed and then applies the same glob, so the pipeline would have to download and
repack the archive purely to satisfy a hardcoded path.

<a id="i-31"></a>
## I-31 — Files unpacked by tar can land unreadable by their own owner (P1)

On a filesystem whose default ACL leaves the owner class empty — access being granted through
a named entry instead — GNU tar restores each member's stored mode and produces files that
their owner cannot open:

```
$ getfacl -p /mnt/scratch/db
user::---
user:allen:rwx
default:user::---
default:user:allen:rwx

$ tar xzf probe.tar.gz -C /mnt/scratch/db/probe && ls -l /mnt/scratch/db/probe
----rw---- 1 allen uucp 1 probe          # archived as -rw-rw-r--
```

Only tar is affected: `open()`, `touch` + `chmod`, `install -m` and `cp` all produce the mode
they asked for on the same directory. DRAM unpacks the KOfam profiles with tar and then opens
all 26000 of them, so the build dies with `PermissionError` an hour in. `DB_VREFSEQ` hits the
same thing when it unpacks `mmseqs_vrefseq.tar.gz` and works around it with an explicit
`chmod`, attributing it there to the archive's stored modes.

Two things in `DB_DRAM` follow from this. The build happens in the task work directory rather
than under `--db`, so the databases are assembled where the pipeline computes rather than
wherever the user keeps storage; and before any of it starts, the process unpacks a one-file
archive and checks that it can read the result, so an unsuitable work directory is reported in
seconds with the reason and the fix (`-w`) instead of an hour later as a bare `PermissionError`.
The published database is then made owner-readable explicitly, and `check_dram_db.py` opens
every file the `CONFIG` names rather than trusting its mode bits.

<a id="i-32"></a>
## I-32 — vConTACT2 replaced by vConTACT3 (P1)

vConTACT2 clusters contigs but does not assign taxonomy, so `bin/parse_vContact2_vc.py`
had to derive one: it split `genome_by_genome_overview.csv` into query contigs and
reference genomes **by testing whether the contig name contains `NODE_`**, computed a
per-cluster LCA over the reference genomes, and transferred it to the queries. That test
is a SPAdes naming convention, so the whole taxonomy assignment silently produced nothing
for MEGAHIT, Flye or any pre-assembled contig set, and `--assembler other` only inverted
the test rather than fixing it. vConTACT3 predicts taxonomy natively and marks reference
genomes with a `Reference` boolean, so both the guess and the hand-rolled LCA are gone,
along with `bin/parse_vContact2_vc.py` and `bin/combine_taxa.py`.

Four things about vConTACT3 are not obvious and each one costs a build or a wrong result.

**It cannot be installed from conda on aarch64, and there is no PyPI package.**
`pixi global install -c bioconda vcontact3` and every other conda route fail because
`fastcluster` and `jenkspy` have no `linux-aarch64` conda build. There is no `vcontact3`
distribution on PyPI at all, so the Bitbucket source is the only option — and the source
tree is 3.2.4 against bioconda's 3.0.3. Both blocking packages build from their PyPI
sdists, which is why `docker/viroprofiler-vcontact3/Dockerfile` installs `build-essential`
and pins the source by commit (the project publishes no tags).

**Exactly one database version works per release.** 3.2.4 accepts version 232 and rejects
223, 228 and 230 outright. `--db-version` is therefore passed explicitly by
`TAXONOMY_VCONTACT3`; without it vConTACT3 globs `--db-path` and takes whatever is
numerically newest, which on a host that has ever held another release is the wrong one.
The version lives in `params.vcontact3_db_version` so that both `DB_VCONTACT3` and
`TAXONOMY_VCONTACT3` read the same value.

**`prepare_databases` prints `[ERROR] Unable to retrieve database 232 ...` on runs that
succeed.** Its exit status is not evidence either way. `DB_VCONTACT3` ignores both and
checks the artifact instead: `mmseqs dbtype <dir>/v232/RefSeq.232.0.3.mmseq_0.3_clu` must
print `Clustering`, which a truncated download, an HTML error page or a directory that
only got as far as being created cannot do. The database is built in the task work
directory and moved into `--db` only after that check passes.

**Its `pandas>=2.1.1` has no upper bound.** A fresh resolve installs pandas 3.x, published
years after this commit and changing copy-on-write and string-dtype semantics throughout —
the same trap that broke vConTACT2 with numpy 1.24 and scipy's COO refactor ([I-21](#i-21)).
The Dockerfile pins `pandas>=2.1.1,<3`.

Two smaller findings. vConTACT3 3.2.4 never invokes `diamond`: `find_tools` looks up only
`mmseqs` (required) and `vclust` (optional, and it gates only the `ani` export this
pipeline does not request). And it bundles `pyrodigal` and `pyrodigal-gv`, so the external
gene caller and `bin/gene_to_genome.py` that vConTACT2 needed are gone too.

`docker/viroprofiler-taxa` is retired with vConTACT2; `TAXONOMY_MERGE` is pure Python over
the callers' tables and runs in `viroprofiler-base`, which already carries pandas and click.

<a id="i-33"></a>
## I-33 — `RESULTS_TSE` cannot read its own gzipped abundance inputs (P0)

Unrelated to taxonomy, but it is what the pipeline now fails on once taxonomy
completes, and it had never been reached before: no run in this repository has
ever produced an `.rds`, because every earlier one stopped at vConTACT2.

`ABUNDANCE` writes `abundance_contigs_{count,tpm,covered_fraction}.tsv.gz`, and
`vpfkit::read_coverm()` opens them with `data.table::fread()`. `fread()` cannot
decompress a `.gz` without the `R.utils` package, and `denglab/viroprofiler-viewer`
does not have it:

```
$ apptainer exec viroprofiler-viewer.sif Rscript -e 'requireNamespace("R.utils")'
FALSE

Error in fread(fpath) :
  To read gz files directly, fread() requires 'R.utils' package which cannot be
  found. Please install 'R.utils' using 'install.packages('R.utils')'.
Calls: <Anonymous> ... read_coverm -> fread -> stopf -> raise_condition -> signal
```

The taxonomy input is unaffected: `taxa_mmseqs_formatted_all.tsv` is not
compressed, and `read_coverm` never opens it.

This cannot be fixed from this repository as it stands, which is the point of
[I-02](#i-02): the viewer image has no Dockerfile here, so `R.utils` cannot be
added to it. Either that image gains a Dockerfile and the package, or
`RESULTS_TSE` decompresses the three files before calling `create_tse.r`.

<a id="i-34"></a>
## I-34 — `-max_target_seqs` makes contig dereplication depend on library size (P2)

`CONTIGLIB_CLUSTER` dereplicated the pooled contig library with the MIUViG recipe: an
all-vs-all `blastn`, `anicalc.py` to turn the HSPs into ANI and coverage, and
`aniclust.py` to cluster them greedily. The `blastn` call carried
`-max_target_seqs 25000`, which reads like "keep the best 25000 hits" and is not that.
It is a cutoff applied *during* the search, and NCBI documents that the hits it keeps are
not guaranteed to be the best ones — the point of Shah *et al.*, "Misunderstood parameter
of NCBI BLAST impacts the correctness of bioinformatics workflows", *Bioinformatics*
35(9):1613–1614 (2019).

The consequence for this pipeline is that a contig pair can stop being reported because of
sequences that have nothing to do with either contig. A query, a 98%-identity full-length
partner and `-max_target_seqs 5` (the same mechanism as 25000, at a size that is quick to
run):

```
$ blastn -query q.fasta -db db_small -perc_identity 90 -max_target_seqs 5 ...
library=small subjects=1  reported=1 partner_reported=1

$ blastn -query q.fasta -db db_big   -perc_identity 90 -max_target_seqs 5 ...
library=big   subjects=31 reported=5 partner_reported=0
```

The 30 sequences added to `db_big` are unrelated to the query–partner relationship, yet
the partner is no longer reported at all, so `aniclust.py` never sees the edge and the two
contigs land in different clusters. Representatives are the read-mapping reference for
abundance and the input to viral detection, so a pair silently lost this way propagates
into apparent abundance and viral calls. Nothing in the outputs records that it happened,
and the effect grows with the number of samples pooled.

**Fixed.** The chain is now Vclust 1.3.1 — a Kmer-db prefilter, LZ-ANI alignment, and
greedy clustering — which has no equivalent per-query cap, so the result no longer depends
on how many other contigs are in the library. `bin/anicalc.py`, `bin/aniclust.py` and
`bin/parse_NRCLib_clusters.py` are deleted; `bin/parse_vclust_clusters.py` writes the same
`repid`/`ctgid` table the pipeline published before. The thresholds keep their names and
their meaning:

| Old | New | Measure |
|-----|-----|---------|
| `--min_ani 95` | `--ani 0.95` | Vclust `ani` — identical nucleotides over the aligned region only |
| `--min_tcov 85`, `--min_qcov 0` | `--qcov 0.85` | Vclust `qcov` — aligned fraction of the shorter contig, longer one unconstrained |

`gani` and `tani` are the wrong measures here: `gani` divides by the whole query length, so
it scores a contained contig as poorly as a diverged one, and `tani` is symmetric, so it
cannot express containment at all. Setting `--rcov` alongside `--qcov` would demand that
both sequences be covered, which is reciprocal-overlap clustering rather than containment.
`--algorithm cd-hit` is used rather than Vclust's default `leiden` because it is the same
greedy longest-first centroid scheme `aniclust.py` implemented.

One class of representative does change. When two contigs in a cluster are exactly the same
length, `aniclust.py` kept whichever came first in the FASTA, so the representative followed
the order the samples happened to be pooled in; Vclust breaks the tie the same way every
time. Both contigs are equally valid representatives, and the new choice is the reproducible
one:

```
input order alpha,beta : aniclust -> alpha_first   vclust -> alpha_first
input order beta,alpha : aniclust -> beta_second   vclust -> alpha_first
```

On the contig library of the two-sample run in this repository (23 contigs, 22 clusters),
the substitution reproduces `contigs_nrclib.fasta` and `contigs_nrclib.dict` byte for byte
and `contigs_ANIclst.tsv` row for row. That library is far too small to bound the change on
its own, so it was repeated on 1600 sequences — 800 CheckV reference genomes plus derived
fragments placed on both sides of the 95 %/85 % boundary: 824 of 825 clusters identical,
1599 of 1600 contigs assigned the same representative, and the single disagreement a pair
whose identity the two aligners estimate as 0.9507 (BLAST) and 0.9496 (LZ-ANI), i.e. astride
the threshold rather than a difference in what the threshold means.

End to end, the two-sample run (`-profile apptainer,arm64_local --use_dram false`) still
completes and its two TreeSummarizedExperiment objects are byte identical to the ones the
BLAST chain produced:

```
$ cmp <blast-run>/results/viroprofiler_output.rds <vclust-run>/results/viroprofiler_output.rds
$ cmp <blast-run>/results/viroprofiler_output_all_contigs.rds <vclust-run>/results/viroprofiler_output_all_contigs.rds
```

`CONTIGLIB_CLUSTER` itself went from 3.3 s to 1.5 s on that library, which is far too small
to say anything about how the two scale.

<a id="i-35"></a>
## I-35 — Exact duplicate contigs entered the O(n²) dereplication stage (P3)

`CONTIGLIB` pools the contigs of every sample into one library, so a contig that several
samples assembled identically appears once per sample. The all-vs-all `blastn` compared each
of those copies against everything else, and `aniclust.py` then collapsed them again at the
end.

`CONTIGLIB_CLUSTER` now runs `vclust deduplicate` first, which drops contigs whose sequence
is identical to another contig's, in either orientation, before the prefilter sees them. On
the 1600-sequence set above that removed 115 sequences (7 %) with no change to the clustering.
The ids it drops are not lost: `vclust deduplicate` writes a `.duplicates.txt` companion file,
and `bin/parse_vclust_clusters.py` reads it back so that every contig in the library still
appears in `contigs_ANIclst.tsv` under the representative of its cluster.

<a id="i-36"></a>
## I-36 — `PHAMB_RF` calls a CLI the installed phamb does not have (P1)

The process invoked

```
run_RF.py -f <contigs> -d <dvf> -p <micomplete> -g <vog> -c <clusters> \
          -l <minlen> -m /opt/phamb/workflows/mag_annotation/dbs/RF_model.python39.sav \
          -s <minbin> -o .
```

but the phamb the image installs takes four positional arguments and two options:

```
run_RF.py <fastafile> <clusterspath> <annotationdir> <directoryout> [-m MIN_BIN_SIZE] [-s SEPARATOR]
```

Every flag was wrong, and two were actively dangerous: `-m` had become an `int` minimum bin
size and was being handed a filesystem path, while `-s` had become a binsplit separator and
was being handed a size in bases. The model path did not exist either — phamb moved its
`dbs/` from `workflows/mag_annotation/` into the package itself.

The three annotation files are also not passed individually any more. `run_RF.py` looks them
up by fixed name inside `annotationdir`: `all.DVF.predictions.txt`, `all.hmmVOG.tbl` and
`all.hmmMiComplete105.tbl` — none of which matches what `MICOMPLETEDB` and `VOGDB` emit
(`hmmMiComplete.tbl`, `hmmVOG.tbl`).

**Resolution.** `PHAMB_RF` builds the annotation directory under the expected names and calls
the current CLI. Nothing was passing before, so `--binning phamb` had been broken for longer
than the missing DeepVirFinder table alone would explain.

<a id="i-37"></a>
## I-37 — `run_RF.py` copied onto PATH cannot find its own model (P0)

`run_RF.py` loads the random forest from a path relative to its own source file:

```python
rf_model_file = Path(__file__).parent / "dbs/RF_model.python39.sav"
```

The binning Dockerfile did `cp /opt/phamb/phamb/*.py /opt/conda/bin/`, so the copy that PATH
resolves has `__file__` in `/opt/conda/bin`, where there is no `dbs/`:

```
$ command -v run_RF.py               -> /opt/conda/bin/run_RF.py
$ ls /opt/conda/bin/dbs/             -> No such file or directory
$ ls /opt/phamb/phamb/dbs/           -> RF_model.python39.sav
```

`joblib.load` would therefore have failed with `FileNotFoundError` — after VAMB and both HMM
searches had already run.

**Resolution.** The image installs a wrapper at `/usr/local/bin/run_RF.py` that executes the
file in its installed location, so `__file__` still resolves beside the model. The Dockerfile
asserts both the script and the model exist, and the smoke test deserialises the forest.

<a id="i-38"></a>
## I-38 — The binning image never installed VAMB (P0)

`vMAG_PHAMB` runs `VAMB` before `PHAMB_RF`, but `vamb` was not in `env_binning.yml` and not
in the image:

```
$ apptainer exec viroprofiler-binning.sif vamb --version
/bin/bash: line 1: vamb: command not found
```

So `--binning phamb` could not have worked on any architecture, independently of I-36 and
I-37.

**Resolution on amd64.** `vamb 4.1.3` is declared in `docker/viroprofiler-binning/pixi.toml`
as a `linux-64`-only feature and installed when BuildKit's `TARGETARCH` is `amd64`.

**Not resolvable on aarch64.** VAMB has no `linux-aarch64` artifact in any release line, and
5.x depends on `pycoverm`, which has none either. `WorkflowViroprofiler.binningIsAvailable()`
refuses `--binning phamb` on aarch64 at start-up rather than letting the run reach VAMB. See
[ARM64.md](ARM64.md).

<a id="i-39"></a>
## I-39 — The binning image's second `vrhyme` prefix had drifted to Python 3.14 (P1)

The image built two prefixes containing vRhyme: the base environment, and a separate
`viroprofiler-vrhyme` one from `env_vrhyme.yml`. Only the base environment was on `PATH`, so
the second was never used — and its unpinned solve had drifted far enough to stop working:

```
$ /opt/conda/envs/viroprofiler-vrhyme/bin/vRhyme --version
  File "/opt/conda/envs/viroprofiler-vrhyme/bin/vRhyme", line 16, in <module>
    import pkg_resources
ModuleNotFoundError: No module named 'pkg_resources'
```

It had resolved to Python 3.14, numpy 2.4.6, pandas 3.0.5 and setuptools ≥81, which no longer
ships `pkg_resources`. The vRhyme that VRHYME actually runs, from the base environment, was
on Python 3.10 with scikit-learn 1.0.2 and works.

**Resolution.** There is one environment now, `binning`, and `vrhyme` is declared in it —
which is where the working executable always came from. Its Python and scikit-learn are
pinned, the latter because PHAMB's forest is a joblib-serialised scikit-learn estimator and
phamb's own `setup.py` requires exactly 1.0.2.

<a id="i-40"></a>
## I-40 — `VAMB` was given a depth table covering contigs its FASTA does not contain (P2)

`vMAG_PHAMB` passes the viral subset as `--fasta` but the BAMs are mapped against the whole
dereplicated library, and `jgi_summarize_bam_contig_depths` summarises whatever the BAMs
contain. VAMB pairs `--jgi` with `--fasta` by row, so every contig after the first extra one
would have been given another contig's abundance.

The two `cut`/`paste` lines that preceded the filter were a no-op: `cut -f1-3` and
`cut -f1-3 --complement` pasted back together reproduce the input table exactly.

**Resolution.** The depth table is restricted to the names in the FASTA before the length
filter is applied.

<a id="i-41"></a>
## I-41 — `CONTIGLIB_CLUSTER` requested one CPU while Vclust threads every stage (P3)

`vclust deduplicate`, `prefilter`, `align` and `cluster` all take `-t $task.cpus`, and the
process passed `task.cpus` to each of them, but `nextflow.config` requested
`cpus = 1 * task.attempt`. The Kmer-db prefilter and the LZ-ANI alignment — the two stages
that dominate the runtime — ran single-threaded.

Memory was also sized for the viral subset rather than for what this process actually sees:
it dereplicates the whole pooled contig library, because its output is the read-mapping
reference for abundance.

**Resolution.** 4 CPUs and 12 GB, both scaled by `task.attempt` and still bounded by
`check_max`.

<a id="i-42"></a>
## I-42 — conda post-link scripts are not run by pixi (P0)

`bioconductor-genomeinfodbdata` ships no R package. Its conda artifact contains exactly two
files, both shell scripts:

```
$ python3 -c "import json; print(json.load(open('conda-meta/bioconductor-genomeinfodbdata-1.2.11-r43hdfd78af_1.json'))['files'])"
['bin/.bioconductor-genomeinfodbdata-post-link.sh', 'bin/.bioconductor-genomeinfodbdata-pre-unlink.sh']

$ cat bin/.bioconductor-genomeinfodbdata-post-link.sh
#!/bin/bash
installBiocDataPackage.sh "genomeinfodbdata-1.2.11"
```

The data package itself is downloaded and installed by that post-link script. micromamba runs
post-link scripts; pixi does not, and says so only as a build-time notice. So the environment
solved and installed cleanly while `GenomeInfoDb` — a dependency of every
SummarizedExperiment package — could not be loaded, and `library(vpfkit)` failed with

```
Error in loadNamespace(i, ...) : there is no package called 'GenomeInfoDbData'
ERROR: lazy loading failed for package 'vpfkit'
```

several layers below the package that was actually missing.

**Resolution.** `docker/viroprofiler-viewer/Dockerfile` runs that one script explicitly and
asserts the resulting directory exists, rather than setting `run-post-link-scripts insecure`,
which would silently execute any post-link script any future dependency brings in. A second
step fails the build if a package other than `bioconductor-genomeinfodbdata` ever ships one,
so the next occurrence is found at build time rather than in a run.

This is a general hazard of the micromamba-to-pixi move, not a defect in either tool: it is
invisible in the solve, invisible in the lockfile, and only shows up when something tries to
load the package.

<a id="i-43"></a>
## I-43 — the pinned VAMB has no `--jgi`, which is the flag the process passes (P0)

`VAMB` runs

```
vamb --outdir out_vamb --fasta $contigs -m ... --jgi depth_clean.txt -o __ --minfasta ...
```

but the version first pinned in `docker/viroprofiler-binning/pixi.toml` was 4.1.3, and VAMB 4
removed `--jgi` entirely. Its argument parser offers only `--bamfiles` and `--rpkm`; the word
`jgi` does not appear anywhere in the 4.1.3 package. The process would have died on
`unrecognized arguments: --jgi`.

Nor is 4.x a matter of renaming the flag. It computes depths from BAMs itself and hashes the
BAM reference names against the FASTA, refusing a mismatch — and this pipeline deliberately
hands it a *viral subset* FASTA with BAMs mapped against the *whole* dereplicated library.
VAMB 5 goes further and restructures the cluster file `phamb.vambtools.read_clusters` parses.

**Resolution.** Pinned to `vamb 3.0.2`, the release PHAMB was developed against: it has
`--jgi`, and its `write_clusters` emits the two-column `clustername<TAB>contigname` file phamb
reads. It runs on Python 3.6, which is why it stays in its own pixi environment with its own
solve group; the lockfile is what keeps a Python 3.6 environment installable at all.

<a id="i-44"></a>
## I-44 — VAMB's `--jgi` pairs depths to contigs by row, not by name (P1)

`vamb.vambtools.load_jgi` discards the contig names:

```python
header = next(filehandle)
...
columns = tuple([i for i in range(3, len(fields)) if not fields[i].endswith("-var")])
array = _np.loadtxt(filehandle, dtype=_np.float32, usecols=columns)
return validate_input_array(array)
```

It returns an `N_contigs x N_samples` matrix that VAMB then pairs with `--fasta` **by row**.
So the depth table must hold exactly the sequences of the FASTA, in exactly their order.
Anything else silently gives each contig another contig's abundance, and the clustering is
computed on the wrong numbers with no error anywhere.

The process filtered the table with `csvtk grep -f contigName -P <list>`, which preserves the
order of the *depth file* — the BAM reference order — not the order of the FASTA. Those two
happen to agree today, because the viral subset is produced by `seqkit grep` from the same
library the bowtie2 index was built from, and both preserve input order. That is a property
of the tools involved, not a guarantee either makes.

**Resolution.** The table is now built in FASTA order explicitly, by looking each sequence up
by name, and two assertions follow it: a contig absent from the depth table is fatal (it would
mean the BAMs were built against a different library), and the emitted row count must equal
the number of FASTA sequences that pass VAMB's own `-m` length filter.

Two related hardenings went in with it, neither of which had produced a wrong answer yet:
`bin/genomad_to_dvf.py` now passes geNomad's score through as the source text rather than
re-formatting it with `%.4f`, because PHAMB applies `round(x, 2)` to whatever it reads and
0.00499 re-emitted as 0.0050 rounds to 0.01 instead of 0.00; and the vRhyme model download is
checked against a pinned SHA-256 rather than trusted because its URL carries a commit.


---

## I-45

**Config — the pipeline does not parse under Nextflow's default config parser.** P0. Fixed.

Nextflow 25.x made a new, restricted config language the default. `nextflow.config` is not
written in it, and a run dies before the first process with a message that points at a line
of config rather than at the cause:

```
Error nextflow.config:286:27: Unexpected input: '\n'
 286 |             case 'docker':
ERROR ~ Config parsing failed
```

Four constructs are rejected, each independently fatal:

- the `switch` in the `containerOptions` closure;
- `def check_max(obj, type)`, a function definition, used at 133 call sites;
- the top-level `if (!params.igenomes_ignore)` — *"If statements cannot be mixed with config
  statements"*, so a conditional `includeConfig` has no v2 spelling at all;
- `def trace_timestamp = ...`, a variable declaration.

The script parser is stricter too: `for` loops are gone (`workflows/viroprofiler.nf:15`), and
a top-level statement such as `WorkflowMain.initialise(...)` in `main.nf` must move inside a
`workflow` block.

**Why it has been invisible.** `NXF_SYNTAX_PARSER=v1` happens to be set in the interactive
shell on the development machine. Every run to date inherited it. A `sbatch --export=NIL` job
does not, which is how it surfaced, and neither does a new user's shell.

**The two parsers cannot both be satisfied.** Moving the Groovy into `lib/` fixes the config
under v2 — and breaks it under v1, where an unknown identifier in a config closure resolves
to a `ConfigObject` instead of the class: `Unknown method invocation 'checkMax' on ConfigObject
type`. Likewise `env('HOME')` is v2-only. So this cannot be done incrementally: config and
scripts have to migrate together, in one change, and the pipeline then requires a Nextflow new
enough to have the v2 parser. `manifest.nextflowVersion` would move from `>=22.04.0`
accordingly.

**Resolution.** Config and scripts migrated together, and `manifest.nextflowVersion` is now
`>=26.04.0`. `NXF_SYNTAX_PARSER` must not be set at all.

- `check_max()` and its 137 call sites are gone, replaced by `process.resourceLimits`.
  Moving the helper into `lib/` was tried first and does not work: a config closure resolves
  `Utils` to a `ConfigObject`, so the call fails with `No signature of method:
  groovy.util.ConfigObject.checkMax()`. The assignment sits below the `profiles` block —
  see [I-51](#i-51) for what happens when it does not.
- The `switch` is an if/else chain. `def` and `if` inside a config closure remain legal.
- The report file names use `params.trace_timestamp`, assigned by `nextflow.config` itself
  from `new java.util.Date().format(...)`. The earlier note here — that the timestamp would
  have to come from the command line — was wrong: an arbitrary expression is a legal
  assignment value, and `params` is what carries it into the four reporting scopes. It is in
  `schema_ignore_params`, being an implementation detail rather than an option.
- `"${HOME}"` is `"${env('HOME')}"`, which is what makes the legacy parser unusable.
- Statements at file scope moved into the workflow bodies, `for` became `.each`, and the
  `no_file` closure became a function — the strict parser resolves `no_file(...)` as a
  function name.

Two further defects surfaced during the migration and have their own entries: the completion
summary was being printed twice ([I-49](#i-49)), and command-line booleans stopped being
coerced ([I-50](#i-50)).

Verified with the default parser: `nextflow lint` reports no errors where it reported 54, and
all five CI stub jobs, the four-mode ladder and both negative tests pass.

---

## I-46

**iPHoP, CheckAMG and DRAM-v results never reached `RESULTS_TSE`.** P1. Fixed.

All three ran, all three published their tables under `--outdir`, and none of them was wired
into the process that builds the TreeSummarizedExperiment. The R object that is the pipeline's
headline output therefore carried no host prediction, no auxiliary-gene calls and no per-gene
annotation. On the two-sample test CheckAMG produced 210 curated protein calls that nothing
downstream could see.

`DRAMV` did not even emit its annotation table as a named channel — only `genes.faa` and
`scaffolds.fna` — and `ABUNDANCE` did not emit `log_contig_count.txt`, the only place CoverM
records each sample's library size.

**Resolution.** `RESULTS_TSE` takes eight optional inputs: VIBRANT, geNomad, CheckAMG, iPHoP,
DRAM-v, the candidate contig list, the CoverM log and a sample metadata table. When a tool did
not run its slot carries an empty placeholder from `assets/optional/` and the corresponding
`create_tse.r` argument is omitted, so vpfkit leaves those columns out of `rowData` rather
than joining an empty table — which keeps "switched off" distinguishable from "found nothing".

Sample metadata needs `--sample_metadata` rather than extra samplesheet columns:
`INPUT_CHECK` rejects a samplesheet that is not exactly three columns. Until this, `colData`
held nothing but the sample name, so no group-wise analysis was possible on the pipeline's own
output at all.

The two placeholder tables with fabricated header rows (`assets/no_dvf_scores.tsv`,
`assets/no_vibrant_quality.tsv`) are gone. They existed only because `create_vpftse()` indexed
columns without checking for them; vpfkit now treats both inputs as optional.

---

## I-47

**432 lines of iGenomes reference config that nothing reads.** P2. Fixed.

`conf/igenomes.config`, `params.genome`, `params.igenomes_base`, `params.igenomes_ignore`,
`WorkflowMain.getGenomeAttribute()` and `WorkflowViroprofiler.genomeExistsError()` were
nf-core template scaffolding. No process reads `params.genome` or `params.fasta`;
`getGenomeAttribute` is defined and never called. `genomeExistsError` validated `--genome` on
every run, against a table only it consulted.

Removed. `workflows/contig_anno.nf` also imported `RESULTS_TSE` without ever calling it; that
import is gone too.


---

## I-48

**A scheduler's `TMPDIR` points outside the container, and DRAM-v dies on it.** P1. Fixed.

`TMPDIR` is inherited from whatever launched the pipeline. Under a batch scheduler it
normally names node-local scratch — `/localscratch/<user>/slurm/<jobid>/tmp` here. Nextflow
binds the task directory into the container and nothing else, so a tool that writes to
`$TMPDIR` by absolute path finds no such directory:

```
tRNAscan-SE ... experienced an error: Unable to open
/localscratch/allen/slurm/2615/tmp/tscan87374.fpass for writing.  Aborting program.
```

DRAM-v reached that call **nine minutes in**, after kofam, viral, peptidase, pfam, dbCAN and
VOGDB had all completed, and the whole process was lost. Only tRNAscan-SE was affected
because it is the one tool in this pipeline that builds an absolute scratch path from
`TMPDIR`; the rest write relative paths into the task directory and never noticed.

It does not reproduce interactively, where `TMPDIR` is `/tmp` and Apptainer provides one.

**Resolution.** `conf/base.config` sets `beforeScript = 'export TMPDIR="$PWD"'` for every
process. The task directory is bound by definition and lives on the work filesystem, which
is where large scratch files belong. Verified by checking that the export reaches all 26
task scripts in a stub run, rather than by assuming a directive took effect.

---

<a id="i-49"></a>
## I-49

**The completion summary was printed twice on every run.** P2. Fixed.

`workflows/viroprofiler.nf` and `workflows/contig_anno.nf` each ended in a file-scope
`workflow.onComplete { ... NfcoreTemplate.summary(...) }`. `main.nf` includes both entry
workflows and invokes one of them, but a module's file-scope statements run at *include*
time, not at invocation — so both handlers were registered and both fired. Every run
printed the completion summary twice, and with `--email` set would have tried to send two
e-mails.

Confirmed in isolation: two modules, one file-scope handler each, only one workflow
invoked, both handlers ran.

**Resolution.** There is one handler, in `main.nf`'s entry workflow, and it is registered
once. See [I-45](#i-45) for why it is an `onComplete:` section rather than a closure.

---

<a id="i-50"></a>
## I-50

**A boolean given on the command line arrived as a string, and `"false"` is true.** P0. Fixed.

Under the strict parser Nextflow no longer infers a parameter's type from its default, so
`--use_dram false` reaches the pipeline as the String `"false"`. Groovy treats any non-empty
string as true, so `if (params.use_dram)` is true and DRAM-v runs when the user asked for it
not to. The same applies to all 19 boolean, 7 integer and 8 number parameters —
`--max_cpus 4` arrives as `"4"`.

What made this survivable is accidental: JSON-schema validation rejects the run with
`expected type: Boolean, found: String (false)` before the workflow starts. Switch
`validate_params` off and the inversion is silent.

**Resolution.** `main.nf` declares the types of all 34 non-string parameters in a `params { }`
block, which is where the strict language expects a parameter's type; values stay in
`nextflow.config`, which still overrides the declaration, and a profile and then the command
line override that in turn. Only `Boolean`, `Integer` and `Float` convert a command-line
string — `Number`, `Double` and `BigDecimal` reject it outright. `Float` is the right choice
for the schema's `number` parameters even where the value is a whole number: it leaves 95 an
`Integer` rather than rendering it into a tool's command line as `95.0`.

The declaration mirrors `"type"` in `nextflow_schema.json`. A new non-string parameter has
to be added to both.

Verified: `--use_dram false` now leaves DRAMV out of the run rather than failing validation.

---

<a id="i-51"></a>
## I-51

**`process.resourceLimits` above the `profiles` block ignores every profile.** P1. Fixed.

`resourceLimits` replaced `check_max()` ([I-45](#i-45)), but the two are not evaluated at the
same time. `check_max()` ran inside a per-task closure and read `params.max_cpus` at
submission; `resourceLimits` is a plain map, evaluated where it is written. Written in
`conf/base.config` — the natural home, next to the resource defaults — it freezes to the
values in the `params` block of `nextflow.config`, because that file is included before
`profiles` is applied.

The effect is silent and specific: `--max_cpus` on the command line still works, because
command-line parameters are resolved before the config is, but `test` (2 cpus, 6.GB),
`test_stub` (2 cpus, 4.GB) and `custom.config` (4 cpus, 20.GB) are all ignored, and every
process runs at the unrestricted defaults.

**Resolution.** The assignment lives in `nextflow.config` below `profiles`, next to the
reporting scopes that are placed there for the same reason. Verified per profile with
`nextflow config -flat`, and end to end: `process_high` requests 12 cpus, 72.GB and 16.h,
and under `-profile test_stub` no task received more than 2 cpus, 4 GB and 1h.
