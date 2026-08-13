# Running ViroProfiler on aarch64

The container images published on Docker Hub under `denglab/` are amd64-only
([I-01](KNOWN_ISSUES.md#i-01)), so on an aarch64 host (Apple silicon, AWS Graviton,
NVIDIA GB10/GB200, Ampere) the images have to be built locally from `docker/`:

```bash
bash docker/build_arm64.sh                  # build + convert to SIF
nextflow run main.nf -profile apptainer,arm64_local --input samplesheet.csv --db ~/viroprofiler
```

`docker/build_arm64.sh` covers `base`, `qc`, `abundance`, `replicyc`, `vibrant`, `bracken`,
`virsorter2`, `vcontact3`, `vitap`, `geneannot`, `binning` and `viewer`. Two images are
missing from that list on purpose: they cannot be built for `linux-aarch64` at all.

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

## `viroprofiler-dvf` — DeepVirFinder

DeepVirFinder is frozen to a 2018 stack that bioconda/conda-forge never built for
`linux-aarch64`. Solving `docker/viroprofiler-dvf/env_dvf.yml` for that platform fails:

```
error    libmamba Could not solve for environment specs
    The following packages are incompatible
    ├─ deepvirfinder is not installable because it requires
    │  └─ keras 2.2.4 , which does not exist (perhaps a missing channel);
    ├─ keras 2.2.4**  does not exist (perhaps a typo or a missing channel);
    └─ theano 1.0.3**  does not exist (perhaps a typo or a missing channel).
```

`deepvirfinder` itself is not in bioconda at all; it comes from the `hcc` channel.

**Consequence.** `DVF` is called unconditionally in `workflows/viroprofiler.nf` and
`workflows/contig_anno.nf` — there is no `use_dvf` switch — while
`conf/arm64_local.config` points the `viroprofiler_dvf` label at a SIF that
`docker/build_arm64.sh` does not produce. A full run on aarch64 therefore stops at `DVF`
unless an amd64 `viroprofiler-dvf.sif` is supplied and QEMU emulation is available.

## Re-checking these constraints

Package availability changes; both checks are cheap and need no aarch64 hardware, since
`--platform` makes the solver work cross-platform.

```bash
# conda side (swap in either environment file)
docker run --rm -v "$PWD/docker/viroprofiler-dvf/env_dvf.yml:/tmp/e.yml:ro" \
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
