# Known Issues — 2026 Modernization Audit

Running log of every defect found while redeploying ViroProfiler `dev_ru` on a fresh
machine (NVIDIA DGX Spark, aarch64/GB10, Apptainer 1.5.2, Nextflow 26.04.3, 2026-08-12).

Bugs are recorded first and fixed in batches; the `Status` column tracks that.
Severity: **P0** blocks any run · **P1** blocks a common use case · **P2** correctness or
usability defect · **P3** hygiene.

| ID | Severity | Area | Status |
|----|----------|------|--------|
| [I-01](#i-01) | P0 | Containers — amd64-only images | Partly fixed — arm64 images build from `docker/`, except iPHoP and DVF |
| [I-02](#i-02) | P0 | Containers — `viroprofiler-viewer` has no Dockerfile | Fixed |
| [I-03](#i-03) | P0 | Config — `params.db` never bind-mounted into containers | Fixed |
| [I-04](#i-04) | P1 | Test data — stub samplesheet uses launch-dir-relative paths | Fixed |
| [I-05](#i-05) | P1 | Config — `params.tracedir` frozen to the default `outdir` | Fixed |
| [I-06](#i-06) | P1 | Databases — iPHoP DB directory name hardcoded and stale | Fixed |
| [I-07](#i-07) | P1 | Databases — Bracken/Kraken2 DB paths disagree | Fixed |
| [I-08](#i-08) | P2 | Databases — NCBI taxonomy pinned to a 2022 archive snapshot | Open |
| [I-09](#i-09) | P2 | Databases — VOGDB host renamed; plain-HTTP URL | Open |
| [I-10](#i-10) | P2 | Databases — setup steps are not resumable and never verified | Open |
| [I-11](#i-11) | P2 | Workflow — `--mode fastqc` / `fastp` / `contiglib` not honoured | Open |
| [I-12](#i-12) | P2 | Config — `docker.userEmulation` removed in modern Nextflow | Fixed |
| [I-13](#i-13) | P3 | Repo — stub output directories committed despite `.gitignore` | Open |
| [I-14](#i-14) | P3 | Docs — `CLAUDE.md` references an MCP server that is not part of the repo | Open |
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
mode in [I-28](#i-28)); the sidecar files that mmseqs and HMMER need but the `CONFIG` does
not name — `.dbtype`/`.index` and `.h3f`/`.h3i`/`.h3m`/`.h3p` — must be present; and every
description table in `description_db.sqlite` must have rows. The same check runs after the
build, so a database that fails it makes the process exit non-zero instead of being
published. An incomplete directory is deleted and rebuilt rather than reused.

Two other things `prepare_databases` gets wrong are handled in the same place:

- It never deletes the intermediates it feeds to a finished step. `pfam.mmsmsa`, the
  uncompressed mmseqs form of `Pfam-A.full.gz` that `msa2profile` consumes, is by far the
  largest object the build produces and the `CONFIG` never refers to it. `DB_DRAM` removes it
  along with the mmseqs `tmp` directory and the unpacked KOfam and VOGDB profile trees.
- The build runs directly in `${params.db}/dram` rather than in the task work directory,
  because staging that intermediate and copying it across filesystems is not viable.

`--skip_uniref` is kept: UniRef90 adds several hundred GB and DRAM's own documentation states
it does not affect distillation. KEGG is licensed and cannot be downloaded, so `kegg` and
`gene_ko_link` stay unset; DRAM substitutes KOfam for KEGG orthology.
