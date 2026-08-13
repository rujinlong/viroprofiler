# Running ViroProfiler on aarch64

The container images published on Docker Hub under `denglab/` are amd64-only
([I-01](KNOWN_ISSUES.md#i-01)), so on an aarch64 host (Apple silicon, AWS Graviton,
NVIDIA GB10/GB200, Ampere) the images have to be built locally from `docker/`:

```bash
bash docker/build_arm64.sh                  # build + convert to SIF
nextflow run main.nf -profile apptainer,arm64_local --input samplesheet.csv --db ~/viroprofiler
```

`docker/build_arm64.sh` covers `base`, `qc`, `abundance`, `replicyc`, `vibrant`, `bracken`,
`virsorter2`, `vcontact3`, `vclust`, `vitap`, `genomad`, `checkamg`, `geneannot`, `binning`
and `viewer`. One image is missing from that list on purpose — `host`, which cannot be built
for `linux-aarch64` at all — and one tool inside `binning` is likewise unavailable here.

`vcontact3` is buildable here only because it does not come from conda: `fastcluster` and
`jenkspy` have no `linux-aarch64` conda build, so `pixi global install -c bioconda vcontact3`
and every other conda route fail, while both packages compile from their PyPI sdists. See
[I-32](KNOWN_ISSUES.md#i-32).

`vitap` builds natively with no constraint to work around, which is worth recording because
it is the exception among the taxonomy tools. VITAP itself is pure Python, and all three
executables it calls have `linux-aarch64` builds in bioconda:

```bash
python3 -c "
import json, urllib.request
for p in ['diamond', 'seqkit', 'prodigal']:
    d = json.load(urllib.request.urlopen('https://api.anaconda.org/package/bioconda/' + p))
    subs = sorted({f['attrs'].get('subdir') for f in d['files'] if f['version'] == d['latest_version']})
    print(p, d['latest_version'], subs)
"
# diamond 2.2.5 ['linux-64', 'linux-aarch64', 'osx-64', 'osx-arm64']
# seqkit 2.13.0 ['linux-64', 'linux-aarch64', 'osx-64', 'osx-arm64']
# prodigal 2.6.3 ['linux-64', 'linux-aarch64', 'osx-64', 'osx-arm64']
```

The bioconda `vitap` package is `noarch`, so the same holds for installing VITAP from
bioconda rather than from source. What made a source install necessary is a version
question, not an architecture one: see `docker/viroprofiler-vitap/Dockerfile` for why the
image pins 1.7.1 rather than the current 1.12.

The image was built and its smoke test run on an aarch64 host
(`bash docker/build_arm64.sh vitap`, NVIDIA GB10, Apptainer 1.5.2):

```
#11 2.864 diamond version 2.1.16
#11 2.868 Prodigal V2.6.3: February, 2016
#11 2.889 seqkit v2.13.0
OK    vitap -> /home/allen/singularity/viroprofiler/viroprofiler-vitap.sif
```

## `viroprofiler-host` — iPHoP

Both halves of the dependency set are x86-64-only.

**conda half.** Solving the fork's `iphop_environment.yml` for `linux-aarch64` fails
(micromamba 1.5.8, 2026-08-12):

```
error    libmamba Could not solve for environment specs
    The following packages are incompatible
    ├─ blast 2.12**  does not exist (perhaps a typo or a missing channel);
    ├─ hmmer 3.3.2**  does not exist (perhaps a typo or a missing channel);
    ├─ perl-bioperl 1.7.*  is installable with the potential options
    │  ├─ perl-bioperl 1.7.2 would require
    │  │  └─ perl-bioperl-core 1.007002 , which requires
    │  │     └─ perl-db-file, which does not exist (perhaps a missing channel);
    │  └─ perl-bioperl 1.7.8 would require
    │     └─ perl-bio-tools-run-alignment-tcoffee ... t-coffee ... pasta
    ├─ python 3.8**  is not installable because there are no viable options
    ├─ r-ranger 0.13**  does not exist (perhaps a typo or a missing channel);
    └─ scikit-learn 0.22.0**  does not exist (perhaps a typo or a missing channel).
```

bioconda does publish `linux-aarch64` builds of `blast` and `hmmer`, but only of versions
iPHoP does not accept (2.16.0 and 3.4 respectively).

**pip half.** iPHoP's classifier inference engine has no aarch64 Linux wheel in any release:

| Package | Linux wheel platform tags on PyPI |
|---------|-----------------------------------|
| `tensorflow-decision-forests` (all 40 releases) | `manylinux_2_12_x86_64`, `manylinux_2_17_x86_64` |
| `tensorflow==2.7.0` | `manylinux2010_x86_64` |

The `*_arm64` wheels those projects publish are `macosx_12_0_arm64` / `macosx_13_0_arm64`,
i.e. Apple silicon, not Linux.

Neither constraint can be worked around by relaxing a pin: iPHoP loads Keras models trained
with TF 2.7 through `tensorflow-decision-forests` 0.2.2, and that package's Linux build has
never targeted aarch64.

**Consequence.** `conf/arm64_local.config` sets `use_iphop = false`, so host prediction is
skipped on aarch64. `docker/viroprofiler-host/Dockerfile` pins
`FROM --platform=linux/amd64`, so building it on an aarch64 host requires a registered
`binfmt_misc` QEMU interpreter and produces an amd64 image that then has to run under
emulation.

## DeepVirFinder — removed, replaced by geNomad

DeepVirFinder was frozen to a 2018 stack that bioconda/conda-forge never built for
`linux-aarch64`. Solving its environment file for that platform failed:

```
error    libmamba Could not solve for environment specs
    The following packages are incompatible
    ├─ deepvirfinder is not installable because it requires
    │  └─ keras 2.2.4 , which does not exist (perhaps a missing channel);
    ├─ keras 2.2.4**  does not exist (perhaps a typo or a missing channel);
    └─ theano 1.0.3**  does not exist (perhaps a typo or a missing channel).
```

`deepvirfinder` was not in bioconda at all; it came from the `hcc` channel, and it has had
no release since 2020.

**Resolution.** `GENOMAD` replaced `DVF` in both workflows. geNomad does virus
identification, provirus excision and marker-based gene annotation in one pass, and every
one of its dependencies — including `mmseqs2` and `aragorn` — has a linux-aarch64 conda
build, so `docker/viroprofiler-genomad/` builds natively on both architectures.

`CHECKAMG` was added alongside it and is likewise architecture-neutral, with one caveat
recorded in `docker/viroprofiler-checkamg/Dockerfile`: `torch_scatter` publishes no aarch64
wheel and compiles from its sdist, and its `setup.py` imports torch at build time, so torch
has to be installed before CheckAMG and the compile has to run with `--no-build-isolation`.

**Consequence for PHAMB.** `run_RF.py` reads a per-contig virus score in DeepVirFinder's
format. `PHAMB_DVF_TABLE` writes geNomad's scores in that layout, so the missing score table
is no longer what stops PHAMB here — VAMB is. See the next section.

## `--binning phamb` — VAMB

PHAMB classifies VAMB's clusters, and VAMB has no `linux-aarch64` artifact in any release
line:

| VAMB | bioconda subdirs | Blocker on aarch64 |
|---|---|---|
| 2.0.1 – 4.1.3 | `linux-64`, `osx-64` | compiled package, never built for aarch64 |
| 5.0.3, 5.0.4 | `noarch` | requires `pycoverm`, published for `linux-64`, `osx-64`, `osx-arm64` only |

```bash
python3 -c "
import json, urllib.request, collections
for p in ['vamb', 'pycoverm']:
    d = json.load(urllib.request.urlopen('https://api.anaconda.org/package/bioconda/' + p))
    print(p, dict(collections.Counter(f['attrs'].get('subdir') for f in d['files'])))
"
# vamb     {'linux-64': 14, 'osx-64': 14, 'noarch': 2}
# pycoverm {'linux-64': 4, 'osx-arm64': 4, 'osx-64': 4}
```

`docker/viroprofiler-binning/pixi.toml` therefore declares `[feature.vamb] platforms =
["linux-64"]`, and the Dockerfile installs that environment only when BuildKit's
`TARGETARCH` is `amd64`. The image still builds on aarch64 and still provides vRhyme and
PHAMB's scoring code — it simply has no clusterer for PHAMB to classify.

`WorkflowViroprofiler.binningIsAvailable()` refuses `--binning phamb` on aarch64 at
start-up, so the run fails in a second with an explanation instead of hours later on
`vamb: command not found`. It reads the architecture Nextflow itself runs on, which is exact
for a local executor and a guess on a heterogeneous cluster.

**`--binning vrhyme` is unaffected** and is the binner to use on aarch64.

The version pinned is 3.0.2, and that is a compatibility choice rather than a platform one.
VAMB 4 removed `--jgi` outright — it takes only `--bamfiles` or a `.npz`, and hashes the BAM
reference names against the FASTA, so it cannot be handed a contig subset with BAMs mapped
against the full library, which is exactly this pipeline's arrangement. VAMB 5 additionally
renamed and restructured the cluster file PHAMB's `read_clusters` parses. 3.0.2 is the
release PHAMB was developed against; it runs on Python 3.6, which is why it lives in its own
pixi environment and why the lockfile matters for keeping it installable.

## Re-checking these constraints

Package availability changes; both checks are cheap and need no aarch64 hardware, since
`--platform` makes the solver work cross-platform.

```bash
# conda side. Every image except `host` now declares its platforms in a pixi manifest, so
# `pixi lock` reports an unsatisfiable platform at lock time rather than at build time:
#     x failed to solve requirements of environment 'vamb' for platform 'linux-aarch64'
# For `host`, whose environment file comes from the iPHoP checkout, use micromamba:
docker run --rm -v "$PWD/iphop_environment.yml:/tmp/e.yml:ro" \
    mambaorg/micromamba:1.5.8 \
    micromamba create --dry-run --platform linux-aarch64 -n t -f /tmp/e.yml -y

# pip side
curl -s https://pypi.org/pypi/tensorflow-decision-forests/json | python3 -c \
  'import json,sys; d=json.load(sys.stdin); print(sorted({f["filename"].split("-")[-1] \
   for v in d["releases"] for f in d["releases"][v] if f["filename"].endswith(".whl")}))'
```

The same `--platform linux-64` solve is also the only way to check
`docker/viroprofiler-host/Dockerfile` without an amd64 machine: it reports
`Install: 285 packages` for the fork's environment file, and `Install: 296 packages` once
the `typer`, `seqkit` and `procps-ng` specs the Dockerfile adds are included. Both dry runs
end with a `pip failed to install packages` error, which is expected — a dry run has no
prefix for the trailing `pip:` section to install into, and the conda solve has already
completed by then.
