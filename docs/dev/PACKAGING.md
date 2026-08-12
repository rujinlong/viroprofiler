# Container Packaging

How the 14 images in `docker/` should declare and freeze their dependencies, and what to do
about VirSorter2.

## Recommendation

**Adopt lockfiles, and use pixi as the vehicle.** The 2026 breakages recorded in
[KNOWN_ISSUES.md](KNOWN_ISSUES.md) ([I-21](KNOWN_ISSUES.md#i-21), [I-22](KNOWN_ISSUES.md#i-22),
[I-25](KNOWN_ISSUES.md#i-25)) were all one failure: a loose `env_*.yml` is a *request for a
future solve*, not a record of a working environment, so every rebuild silently produces an
untested environment. That diagnosis is about lockfiles, not about conda versus pixi — and if
the choice of tool ever threatens to delay locking, lock first with whatever is at hand. Among
the vehicles that can carry a lock, pixi is the right one for *this* repository on three
specific grounds: it locks conda and PyPI dependencies in one file, which matters because six
of the fourteen Dockerfiles install software outside any environment file today; per-feature
`platforms` turns the aarch64 support matrix from prose in [ARM64.md](ARM64.md) into a
machine-checked declaration; and at the scale of nineteen environment files its speed is the
difference between a routine `pixi lock` and a chore nobody runs. The two constraints that
could have vetoed pixi both check out empirically: tools are callable from `PATH` with no
activation, verified under both `docker run env -i` and `apptainer exec --no-home --cleanenv`,
and image size and build time are a wash (1.86 GB / 84 s versus 1.84 GB / 87 s for the same
two environments). The migration is per-image incremental — Nextflow cannot tell how an image
was built — so it should be done one image at a time behind a pilot, not as a flag day. That
the maintainer already uses pixi locally is a tiebreak, not a reason.

## The problem is the missing lock, not the package manager

Every failure in the table below has the same shape: a spec that was satisfiable and correct in
2022 is still satisfiable in 2026, but resolves to different packages.

| Tool | What a 2026 re-solve chose | Symptom |
|---|---|---|
| VirSorter2 2.2.4 | snakemake 8 | `ImportError: cannot import name 'load_configfile'` |
| DRAM 1.3.5 | Python 3.14 | `ModuleNotFoundError: No module named 'pkg_resources'` |
| vConTACT2 0.11.3 | Python 3.14 / setuptools 84 | same `pkg_resources` failure |
| eggNOG-mapper 2.1.9 | Python 3.14 | `ModuleNotFoundError: No module named 'distutils'` |
| bacphlip | numpy 1.24 | `AttributeError: module 'numpy' has no attribute 'float'` |

None of these is a conda defect, and none would have been prevented by a different solver. Each
was patched with a constraint (`python=3.10`, `setuptools<81`, `numpy<1.24`) inferred from the
traceback. Those constraints are correct today and are worth keeping as *declared intent*, but
they are upper bounds guessed from one failure each — the next incompatibility will arrive
somewhere they do not cover, and the environments will drift again.

A lockfile ends that class of failure outright, because the build stops solving. It also has a
cost worth stating plainly: locking today freezes today's environment, which is the environment
that a single end-to-end run has exercised, not a reconstruction of the 2022 one. That is
acceptable — the point of the lock is that the thing that was tested is the thing that ships —
but it means the lock must be regenerated deliberately and re-tested, never refreshed as a side
effect of a rebuild.

Two consequences follow for how the manifests should be written:

- The loose specs stay. `pandas>=1.5,<2`, `setuptools<81`, `python=3.10` express *why* a bound
  exists and survive a deliberate re-lock. The lockfile records *what* was chosen.
- A conda lock does not reach everything. The base image, the PyPI installs, the `git clone`
  steps and the `wget` of reference data are all outside it. Those need their own pins.

## Why pixi rather than conda-lock

`conda-lock` is the obvious lower-churn alternative: keep `env_*.yml`, keep micromamba, change
one line per Dockerfile. It was tested rather than assumed, and it does not hold up at this
repository's scale.

| | pixi 0.73.0 | conda-lock 4.0.2 |
|---|---|---|
| Lock `env_replidec.yml`, 2 platforms, cold cache | 9.4 s (with `env_bacphlip.yml` too) | killed at 16 min, no lockfile, no output |
| Same, warm cache | 2.1 s | not reached |
| Conda + PyPI in one lock | yes | conda only, in practice |
| Per-environment platform restriction | yes, in the manifest | separate invocations |
| Custom channels (`denglab`, `hcc`) | resolved | not reached |

Both tools were given the same two environment files from
`docker/viroprofiler-replicyc/`, the same two platforms, and an empty cache. pixi produced a
132 KB lockfile covering both environments and both platforms in 9.4 seconds; conda-lock,
solving strictly less (one environment), had written nothing after 16 minutes while sitting at
about 1% CPU — network-bound, not compute-bound.

The gap is structural, not incidental: pixi fetches sharded repodata for the packages actually
requested, while conda-lock pulls whole-channel repodata for bioconda and conda-forge on every
platform. With nineteen environment files to lock and re-lock, that is the difference between a
command that runs in CI on every pull request and one that does not.

The decisive advantage, though, is PyPI. Six of the fourteen Dockerfiles install software that
no conda lock can see:

| Image | Install outside any environment file | Pinned today? |
|---|---|---|
| `viroprofiler-binning` | `git clone` phamb at `master` + `pip install -e .`; `wget` of the vRhyme model from `raw/master` | no |
| `viroprofiler-viewer` | `remotes::install_github('deng-lab/vpfkit', ref = 'main')` | no |
| `viroprofiler-geneannot` | `pip install --no-deps DRAM-bio==1.4.6` | version only |
| `viroprofiler-host` | `pip install .` of the iPHoP fork | yes, `ARG IPHOP_REF` |
| `viroprofiler-replicyc` | `wget` of the Replidec database tarball | yes, versioned URL |
| `viroprofiler-taxa` | `wget` of three vConTACT2 reference files | yes, by commit |

The top two can change under a rebuild without any file in this repository changing. The rest
are pinned but invisible: nothing checks them, and nothing records what a given image actually
contained.

pixi resolves `DRAM-bio==1.4.6` into the same lockfile as its conda dependencies, recording the
wheel's hashed `files.pythonhosted.org` URL for both platforms, and it accepts a git revision as
a PyPI source, which covers phamb. Note one behavioral difference to validate during migration:
the Dockerfile deliberately uses `pip install --no-deps`, whereas pixi's PyPI resolver honors
DRAM's declared requirements — a manifest that moves DRAM into `[pypi-dependencies]` must be
checked to confirm it does not pull PyPI copies of packages the conda solve already provides.

`remotes::install_github` for vpfkit is outside both tools. It should be pinned to a commit SHA
rather than `main` regardless of what happens to the rest of this document.

## Constraints checked against this repository

### Tools on `PATH` without activation

This is the constraint that produced the current hand-maintained `ENV PATH` lines, and the one
most likely to have vetoed pixi. Nextflow writes a `.command.sh` and executes it inside the
container: no activation hook runs, no entrypoint survives, and there is no opportunity to wrap
a command in `pixi run`.

pixi installs each named environment into `.pixi/envs/<name>/`, and each is an ordinary conda
prefix. Putting the `bin/` directories on `PATH` works, with no activation and no wrapper. A
two-environment pilot image resolved and ran both tools under `docker run --entrypoint
/usr/bin/env … -i PATH=…` — a completely empty environment except `PATH` and `HOME` — and again
under `apptainer exec --no-home --cleanenv`, which is how the pipeline actually runs.

The mechanism that makes multiple environments coexist is worth understanding, because it is the
same one micromamba relies on and it has the same limits. In the pilot, `python` on `PATH` is
the *first* environment's Python 3.10, yet the second environment's `bacphlip` still runs,
because its console script carries an absolute shebang
(`#!/app/.pixi/envs/bacphlip/bin/python3.8`). That is robust for console scripts and for
binaries with correct RPATHs. It is *not* robust for a tool that shells out to `python`,
`perl`, `Rscript` or `samtools` by bare name and expects its own environment's copy — first on
`PATH` wins. pixi does not improve this and does not make it worse; it is a property of merging
several prefixes into one executable namespace, and the current images already live with it.

Activation scripts deserve the same honesty. The pilot's environments do ship one
(`etc/conda/activate.d/libxml2-split_activate.sh`), and it does not run — but it does not run
under the present micromamba images either, for exactly the same reason. Nothing regresses. What
does change is that pixi gives a supported way to *materialize* activation into the image:
`pixi shell-hook` emits the variables an activated environment would set, and they can be baked
in as `ENV` at build time instead of being hand-derived the way `ENV CHECKVDB=…` is today.

**Verdict: compatible, with no wrapper.** The multi-environment `ENV PATH` line remains; pixi
does not abolish it, it just makes the environments behind it declarable and lockable.

### Multiple environments per image

Three images build more than one environment: `viroprofiler-base` (base + checkv + virsorter2),
`viroprofiler-geneannot` (base/DRAM + emapper + abricate), `viroprofiler-replicyc` (replidec +
bacphlip). The mapping onto pixi is direct: one `pixi.toml` per image, one `[feature.X]` per
current `env_X.yml`, one entry in `[environments]` per prefix.

The one thing to get right is solve groups. These environments exist precisely because their
dependencies conflict — checkv wants numpy 1.23.1, virsorter2 wants Python 3.10.0 exactly. Each
environment must therefore be given its **own** `solve-group`, or pixi will try to co-solve them
and reproduce the conflict the split was created to avoid.

### Two platforms

A lockfile does not conjure a missing package, and it should not be sold as if it did. When a
package has no `linux-aarch64` build, `pixi lock` fails:

```
x failed to solve requirements of environment 'dvf' for platform 'linux-aarch64'
  ╰─▶ Cannot solve the request because of: No candidates were found for theano 1.0.3.*.
```

That is the same information `micromamba create --dry-run --platform linux-aarch64` already
gives (the recipe [ARM64.md](ARM64.md) documents), moved from build time to lock time. Earlier
is better, but on its own it would not justify a migration.

What does justify it is that pixi can *express the answer* rather than only report the problem.
Adding `platforms = ["linux-64"]` to the offending feature makes the manifest lock cleanly and
record that this environment exists on one platform only:

```
default -> []
dvf     -> ['linux-64']
```

Today that fact lives in prose in [ARM64.md](ARM64.md), in an array in `docker/build_arm64.sh`,
and in `use_iphop = false` in `conf/arm64_local.config` — three places that can disagree, and
which no tool checks. In a pixi manifest it is one declaration that
`pixi lock --check --dry-run` verifies on every pull request. pixi still does not control which
images CI publishes; the build matrix must skip amd64-only images on arm64 independently.

One correction to the assumption behind this question: **`virsorter=2.2.4` does solve on
`linux-aarch64`.** It is a `noarch` package and its full dependency closure resolves (142 and 141
packages on linux-64 and linux-aarch64 respectively). The genuinely arm64-impossible components
are DeepVirFinder (theano 1.0.3, keras 2.2.4) and iPHoP (`tensorflow-decision-forests`), both
already documented in [ARM64.md](ARM64.md).

### Image size and build time

Neutral, measured on this host (aarch64, Docker 29.2.1), building the same two environments both
ways with a package cache mount and a warm cache:

| Build | Time | Image | SIF |
|---|---|---|---|
| micromamba 1.5.8 | 1 m 27 s | 1.84 GB | 604 MB |
| pixi 0.73.0 | 1 m 24 s | 1.86 GB | 619 MB |

The pixi image carries the 63 MB `pixi` binary; a multi-stage build that copies only
`.pixi/envs` removes it, provided the prefix keeps the same absolute path, since conda packages
embed it. That is an optional refinement, not a reason to migrate. `pixi install --locked`
eliminates the solve but not the download, extraction or link steps, which dominate — so pixi is
not a build-speed argument in either direction.

## What this does not fix

State these plainly so the lockfile is not oversold:

- **Missing aarch64 packages.** DeepVirFinder and iPHoP remain unbuildable on arm64.
- **Tools that are already broken against a modern stack.** A lock freezes the workaround; it
  does not make DRAM 1.4.6 stop importing `pkg_resources`.
- **The base images.** `mambaorg/micromamba:1.5.8` and `ghcr.io/prefix-dev/pixi:0.73.0` are
  mutable tags. Pin them by `@sha256:` digest.
- **Databases.** The multi-gigabyte downloads in `modules/local/setup_db.nf` are unversioned and
  unverified ([I-08](KNOWN_ISSUES.md#i-08), [I-09](KNOWN_ISSUES.md#i-09),
  [I-10](KNOWN_ISSUES.md#i-10)). They are a larger reproducibility hole than the environments and
  are untouched by any of this.
- **The `hcc` and `denglab` channels.** Both resolve correctly under pixi, but a lockfile that
  points at `conda.anaconda.org/hcc/noarch/deepvirfinder-2020.11.21-py36_0.tar.bz2` still depends
  on that artifact continuing to be hosted.
- **CI.** Every entry in the `.github/workflows/docker.yml` build matrix is commented out, so no
  image is currently built by CI at all, on either architecture. A lock that nothing verifies is
  a comment.

## Migration sketch

Incremental, one image at a time. A pixi-built image and a micromamba-built image are
indistinguishable to Nextflow, so `conf/modules.config` needs no coordinated change and the two
styles can coexist indefinitely.

### Pilot: `viroprofiler-replicyc`

The right pilot is the smallest image that exercises every risk at once, and that is
`viroprofiler-replicyc`: two environments in one image, a custom channel (`denglab`), a
compatibility pin that was guessed from a traceback (`numpy<1.24`), and a `wget` of reference
data in the Dockerfile that no lock will cover. It is also small enough to rebuild in under two
minutes.

`docker/viroprofiler-replicyc/pixi.toml` — one feature per current `env_*.yml`, one solve group
each:

```toml
[workspace]
name = "viroprofiler-replicyc"
channels = ["denglab", "conda-forge", "bioconda"]
platforms = ["linux-64", "linux-aarch64"]

[feature.replidec.dependencies]
procps-ng = "4.0.0.*"
replidec = "*"

[feature.bacphlip.dependencies]
bacphlip = "*"
# bacphlip's scikit-learn still uses np.float, which numpy 1.24 removed.
numpy = "<1.24"

[environments]
replidec = { features = ["replidec"], solve-group = "replidec" }
bacphlip = { features = ["bacphlip"], solve-group = "bacphlip" }
```

`pixi lock` then produces `pixi.lock`, which is committed. The Dockerfile keeps its present
shape — the `ENV PATH` line survives verbatim apart from the prefix paths:

```dockerfile
FROM ghcr.io/prefix-dev/pixi:0.73.0@sha256:<digest>

WORKDIR /app
COPY ./docker/viroprofiler-replicyc/pixi.toml ./docker/viroprofiler-replicyc/pixi.lock /app/
RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi install --locked -e replidec -e bacphlip

# Nextflow does not activate an environment: every tool must resolve from PATH alone.
ENV PATH=/app/.pixi/envs/replidec/bin:/app/.pixi/envs/bacphlip/bin:$PATH

# Smoke test in a stripped environment, because that is how .command.sh runs.
RUN env -i HOME=/tmp PATH=/app/.pixi/envs/replidec/bin:/app/.pixi/envs/bacphlip/bin:/usr/bin:/bin \
    bash -c 'Replidec -h >/dev/null && bacphlip -h >/dev/null && mmseqs version && ps -p 1 -o comm='

ENTRYPOINT []
CMD ["/bin/bash"]
```

The Replidec database `wget` moves across unchanged, with `site-packages` located via the
environment's own Python rather than a bare `python3`.

### How to tell whether the pilot succeeded

Not "the image built". All five must hold:

1. **`pixi lock --check --dry-run` is clean** in CI on both platforms — the committed lock
   matches the manifest, and `pixi install --locked` in the Dockerfile refuses to build if it
   does not. Use `--dry-run`: plain `pixi lock --check` exits non-zero on drift but *rewrites*
   `pixi.lock` while doing so, which would leave CI with a dirty working tree.
2. **Every tool resolves and runs under `env -i`** with only `PATH` and `HOME` set. The
   in-Dockerfile smoke test above enforces this at build time, which is where it belongs.
3. **The same holds under `apptainer exec --no-home --cleanenv`** on the converted SIF, since
   `--no-home` is what broke `virsorter setup` and would break anything else that assumes a
   writable `$HOME`.
4. **`REPLIDEC` and `BACPHLIP` produce identical output** to the micromamba image on a real
   input — `-profile test`, not `test_stub`, since the stub blocks never invoke the tools. A
   packaging change must not be a scientific change; if output differs, the lock captured
   something the old solve did not, and that must be understood before proceeding.
5. **A rebuild a week later yields the same package set.** Diff `pixi list -e replidec` between
   the two builds. This is the property being bought, so it should be the property that is
   tested.

### Order for the rest

1. `viroprofiler-replicyc` — the pilot.
2. `viroprofiler-abundance`, `viroprofiler-bracken`, `viroprofiler-qc`, `viroprofiler-vibrant` —
   single environment, no in-Dockerfile installs, both platforms. Mechanical.
3. `viroprofiler-taxa`, `viroprofiler-virsorter2` — single environment, guessed compatibility
   pins that the lock now makes concrete.
4. `viroprofiler-base` — three environments, and the template for the multi-prefix `ENV PATH`.
5. `viroprofiler-geneannot` — three environments plus the DRAM PyPI install. The `--no-deps`
   question above must be answered here.
6. `viroprofiler-binning` — phamb from git moves into the lock as a PyPI git source.
   `docker/viroprofiler-phamb/` should be deleted rather than migrated: no label, config or
   script in this repository refers to it, and `viroprofiler-binning` already provides phamb.
7. `viroprofiler-viewer` — R only. Low value: pixi locks the conda side, but vpfkit still comes
   from `remotes::install_github`. Pin `VPFKIT_REF` to a SHA whether or not this image migrates.
8. `viroprofiler-dvf`, `viroprofiler-host` — last, and only if they survive the VirSorter2 and
   arm64 decisions at all. Both are linux-64 only and should say so via a feature-level
   `platforms = ["linux-64"]`.

Restoring the `.github/workflows/docker.yml` matrix, with `pixi lock --check --dry-run` as a
gate, is a prerequisite for any of this to hold. Locking without CI verification only moves the
drift from build time to the next person who runs `pixi lock`.

## VirSorter2: fork, freeze, or replace?

**Recommendation: keep the bioconda package, lock it, and do not fork.** Add a `--use_virsorter2`
switch so runs that do not need DRAM-v can skip it. Introduce geNomad — but as a replacement for
**DeepVirFinder**, not for VirSorter2.

### What VirSorter2 actually does in this pipeline

The premise that VirSorter2 is a viral-detection dependency does not hold here. Detection is
`VIRCONTIGS_PRE` (`modules/local/viral_detection.nf`), whose putative viral contig list is the
union of the DeepVirFinder list, the CheckV quality calls, and the VIBRANT output — VirSorter2
contributes nothing to it. `VIRSORTER2` runs *downstream*, on the already-selected
`vContigs_and_vMAGs` (`workflows/viroprofiler.nf:249`), and only two of its outputs are consumed:

- `viral-affi-contigs-for-dramv.tab` and `final-viral-combined-for-dramv.fa` feed `DRAMV`
  (`workflows/viroprofiler.nf:254`).
- `out_vs2/final-viral-score.tsv` becomes a score column in the TreeSummarizedExperiment
  (`workflows/viroprofiler.nf:299`).

So VirSorter2 is a DRAM-v feeder plus one score column. That reframes every option below.

### Forking is not worth it

A snakemake 7 to 8 port is not one import. The removed `load_configfile` is the visible symptom;
behind it are the programmatic `snakemake(...)` API, per-symbol changes in `snakemake.utils`,
reliance on internals such as `workflow.snakefile`, the `--use-conda` to software-deployment
transition, and the executor-plugin split. Then the real work starts: unpinning Python exposes
pandas, numpy and scikit-learn serialization changes, and a workflow that *runs* is not a
workflow that produces equivalent scores. The dangerous outcome is not a crash; it is a fork
that completes successfully with shifted gene boundaries or categories, silently changing the
DRAM-v auxiliary scores downstream. For a pipeline maintainer who is not a VirSorter2 developer,
this buys nothing the bioconda pin does not already provide, and it transfers packaging,
database distribution and user support to this repository permanently.

### The bioconda pin is durable enough, once locked

The snakemake constraint lives in the built package's dependency metadata, not merely in the
recipe on GitHub, so a fresh solve cannot legally pick snakemake 8 while that constraint stands.
A lock resolves `virsorter 2.2.4` together with `snakemake-minimal 5.26.0` and Python 3.10.0, on
both platforms. The realistic failure mode is therefore not silent breakage but "the image no
longer rebuilds", if old dependency builds disappear from current repodata — which is precisely
what a lockfile with pinned artifact URLs defends against, and which nothing else does.

The arm64 argument for abandoning VirSorter2 also does not stand: it locks cleanly for
`linux-aarch64`.

### geNomad cannot take over the load-bearing role

geNomad is the better modern detector and is unambiguously arm64-ready — `genomad 1.12.0` locks
for both `linux-64` and `linux-aarch64` (144 packages, Python 3.12), with mmseqs2 and aragorn
available on both. But it cannot produce VirSorter's `affi-contigs.tab`, and no other tool can.
That file is not a contig list; it carries per-gene VirSorter category assignments, and DRAM-v
consumes them to compute auxiliary scores.

The consequence is concrete and checkable in DRAM 1.4.6. `-v/--virsorter_affi_contigs` is
*optional* at the CLI, and `annotate_vgfs()` guards on it, so `DRAM-v.py annotate` will run
without it — but `add_dramv_scores_and_flags()` only creates the `auxiliary_score` and
`virsorter_category` columns inside `if virsorter_hits is not None`. `DRAM-v.py distill` then
calls `filter_to_amgs()`, which indexes `annotations['auxiliary_score']` unconditionally. So
`modules/local/annotation.nf:27` fails on a `KeyError` the moment VirSorter2 is removed. With
`use_dram = true` by default, dropping VirSorter2 today breaks the default configuration.

Producing a synthetic affi-contigs file from geNomad output would make DRAM-v execute while
changing what the auxiliary score means. There is no lossless adapter, and a plausible-looking
AMG table computed from fabricated VirSorter categories is worse than no AMG table.

### The tool that should be replaced is DeepVirFinder

Every argument aimed at VirSorter2 lands squarely on DeepVirFinder instead:

| | VirSorter2 2.2.4 | DeepVirFinder |
|---|---|---|
| Role here | DRAM-v prep + one score column | detection voter in `VIRCONTIGS_PRE` |
| Upstream | unmaintained, but pinned by bioconda | unmaintained |
| Packaging | bioconda | `hcc` channel only, last built 2020-11-21 |
| Stack | snakemake 5.26, Python 3.10 | theano 1.0.3, keras 2.2.4 (2018) |
| linux-aarch64 | solves | impossible ([ARM64.md](ARM64.md)) |
| Replaceable by geNomad | no — no affi-contigs | yes, directly |

DeepVirFinder is a genuine detection voter, is the harder arm64 blocker, comes from a channel
with a single maintainer, and does exactly the job geNomad was built to do better. Swapping
geNomad in for it removes an arm64 blocker, removes a dead dependency, and improves the science,
while VirSorter2 stays put doing the one job nothing else can do. `--use_dvf` already exists as
the switch to turn DeepVirFinder off, so a `GENOMAD` process can be introduced alongside it and
compared on real data before anything is removed.

### Verdict

1. Keep `bioconda::virsorter=2.2.4`; lock it. Do not fork.
2. Add `--use_virsorter2` (defaulting to `params.use_dram`, which is what actually needs it) so
   runs that skip AMG annotation avoid an unmaintained tool and an 11 GB database.
3. Add geNomad as a detection option and evaluate it against DeepVirFinder on real data. If it
   holds up, retire DeepVirFinder and delete `docker/viroprofiler-dvf/`.
4. Revisit VirSorter2 only when the DRAM-v auxiliary-score product is itself retired or
   replaced — that is a scientific decision about the AMG deliverable, not a packaging one.

This would change if DRAM-v's auxiliary scores stop being a required output, in which case
VirSorter2 has no remaining role and should simply be dropped; or if bioconda's `virsorter`
artifacts become unresolvable, in which case the frozen amd64 lock plus the base-image digest is
the fallback, not a fork.

## Appendix: verification

Every empirical claim above, with the command that produced it. Run on aarch64 (NVIDIA GB10),
pixi 0.73.0, conda-lock 4.0.2, Docker 29.2.1, Apptainer 1.5.2.

**Tools on `PATH` with no activation, Docker, stripped environment.**

```
$ docker run --rm --entrypoint /usr/bin/env <pixi-image> -i \
    PATH=/app/.pixi/envs/replidec/bin:/app/.pixi/envs/bacphlip/bin:/usr/bin:/bin HOME=/tmp \
    bash -c 'which Replidec bacphlip mmseqs ps; Replidec -h; bacphlip -h'
/app/.pixi/envs/replidec/bin/Replidec
/app/.pixi/envs/bacphlip/bin/bacphlip
/app/.pixi/envs/replidec/bin/mmseqs
/app/.pixi/envs/replidec/bin/ps
Replidec OK
bacphlip OK
```

**Same, under Apptainer as the pipeline runs it.**

```
$ apptainer exec --no-home --cleanenv vp-pilot-pixi.sif bash -c 'Replidec -h; bacphlip -h'
Replidec OK
bacphlip OK
```

**Cross-environment shebang, which is why two prefixes coexist on one `PATH`.**

```
$ head -1 /app/.pixi/envs/bacphlip/bin/bacphlip
#!/app/.pixi/envs/bacphlip/bin/python3.8
$ /app/.pixi/envs/replidec/bin/python -V   ->  Python 3.10.20
$ /app/.pixi/envs/bacphlip/bin/python -V   ->  Python 3.8.20
```

**Activation scripts exist and do not run — under either build system.**

```
$ find /app/.pixi/envs -path '*etc/conda/activate.d/*.sh'
/app/.pixi/envs/replidec/etc/conda/activate.d/libxml2-split_activate.sh
```

**Lock speed, cold cache (`PIXI_CACHE_DIR` pointed at an empty directory), 2 environments x 2
platforms, including the `denglab` channel.**

```
$ time PIXI_CACHE_DIR=/tmp/coldcache pixi lock        ->  9.4 s
$ time pixi lock                          (warm)      ->  2.1 s
```

**conda-lock, same inputs and an equally cold cache, 1 environment x 2 platforms.**

```
$ conda-lock lock -f env_replidec.yml -p linux-64 -p linux-aarch64
(killed at 16 min: zero bytes written, no lockfile, process alive at ~1% CPU = repodata-bound)
```

**The lock is actually enforced, and `--check` alone is the wrong CI gate.** After adding one
package to the manifest without re-locking:

```
$ pixi install --locked          -> exit 1, "lock file not up-to-date with the workspace"
                                    pixi.lock unchanged
$ pixi lock --check              -> exit 1, but pixi.lock WAS rewritten
$ pixi lock --check --dry-run    -> exit 1, pixi.lock unchanged        <- use this in CI
```

**Custom channels resolve.**

```
https://conda.anaconda.org/denglab/linux-64/replidec-0.2.3.1-py310_0.tar.bz2
https://conda.anaconda.org/denglab/linux-aarch64/replidec-0.2.3.1-py310_0.tar.bz2
https://conda.anaconda.org/hcc/noarch/deepvirfinder-2020.11.21-py36_0.tar.bz2
```

**PyPI and conda in one lock, both platforms.**

```
$ pixi lock            # [pypi-dependencies] DRAM-bio = "==1.4.6"   ->  5.4 s
linux-64       conda: 102  pypi: 15
linux-aarch64  conda: 100  pypi: 15
  https://files.pythonhosted.org/packages/4a/3e/.../DRAM_bio-1.4.6-py3-none-any.whl
```

**Unsatisfiable platform fails at lock time, and a feature-level restriction expresses the
answer.**

```
$ pixi lock          # theano 1.0.3 + keras 2.2.4, platforms = [linux-64, linux-aarch64]
x failed to solve requirements of environment 'dvf' for platform 'linux-aarch64'
  ╰─▶ Cannot solve the request because of: No candidates were found for theano 1.0.3.*.
                                                                        (exit 1)

$ pixi lock          # after adding [feature.dvf] platforms = ["linux-64"]
                                                                        (exit 0)
dvf -> ['linux-64']
```

**VirSorter2 solves on aarch64, and bioconda holds snakemake for us.**

```
virsorter2  linux-64        142 pkgs   virsorter-2.2.4-pyhdfd78af_2, snakemake-minimal-5.26.0, python-3.10.0
virsorter2  linux-aarch64   141 pkgs   virsorter-2.2.4-pyhdfd78af_2, snakemake-minimal-5.26.0, python-3.10.0
```

**geNomad is arm64-ready.**

```
genomad  linux-64        144 pkgs   genomad-1.12.0-pyhdfd78af_0, mmseqs2-18.8cc5c, aragorn-1.2.41, python-3.12.13
genomad  linux-aarch64   144 pkgs   genomad-1.12.0-pyhdfd78af_0, mmseqs2-18.8cc5c, aragorn-1.2.41, python-3.12.13
```

**Size and build time, same two environments, package cache mount, warm cache.**

```
micromamba 1.5.8   1 m 27 s   1.84 GB image   604 MB SIF
pixi 0.73.0        1 m 24 s   1.86 GB image   619 MB SIF
```

**DRAM-v breaks without affi-contigs** (DRAM-bio 1.4.6 source):

- `mag_annotator/annotate_vgfs.py` — `def annotate_vgfs(input_fasta, virsorter_affi_contigs=None, ...)`;
  `add_dramv_scores_and_flags()` creates `auxiliary_score` and `virsorter_category` only inside
  `if virsorter_hits is not None:`.
- `mag_annotator/summarize_vgfs.py` — `filter_to_amgs()` evaluates
  `annotations['auxiliary_score'] <= max_aux` unconditionally, so `DRAM-v.py distill` raises
  `KeyError` when the column was never created.

**Not tested.** Whether geNomad's calls are an acceptable substitute for DeepVirFinder's on this
pipeline's data — that requires a real comparison run, not a solve. Whether pixi's PyPI resolver
produces the same DRAM installation as the current `pip install --no-deps`. Whether the remaining
twelve images all pass the `env -i` smoke test; only the two-environment pilot was built.
