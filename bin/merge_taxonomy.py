#!/usr/bin/env python
"""Merge per-contig taxonomy from several callers into one table.

Which callers to merge is data, not code: every source is declared on the
command line as a (name, priority, file) triple, so adding VITAP or geNomad to
the pipeline means adding one `--source` line to `TAXONOMY_MERGE`, not editing
the resolution logic. What each caller's file *looks like* is the one thing that
cannot be data -- every tool writes its own layout -- so each name maps to a
reader in `READERS` below, and a new caller needs a reader beside its entry
there.

Resolution is per rank: for a given contig and a given rank, the highest-priority
source that assigned anything at that rank wins. A smaller priority number means
higher priority, so `--source vcontact3 1 ...` is consulted before
`--source mmseqs 2 ...`.

A lineage may therefore be assembled from more than one caller -- family from
vConTACT3, species from MMseqs2, say. That is the point, but taken literally it
produces contradictory lineages: give vConTACT3 priority and a contig can come
out as family Casjensviridae with the species Escherichia virus T4, which is a
Straboviridae. So a caller is only consulted at a rank if it does not already
disagree with the resolved lineage *above* that rank.

Precisely: a caller that disagrees is passed over for the ranks below the
disagreement, and the next caller in priority order is tried. It is not
disqualified for the whole contig, and a caller further down that *does* agree
with the resolved lineage still fills the rank -- being consistent is what
qualifies it, not being first. Only when no caller both has a value and agrees
does the rank stay empty, which is an honest gap rather than a lineage that
cannot be true. The tally printed at the end counts values that would otherwise
have been used and were rejected for disagreeing; a value that lost on priority
anyway is not counted, because nothing was lost by rejecting it.

vConTACT3 labels de novo clusters `novel_<rank>_<n>_of_<parent>`, and those count
as assignments. They are genuine predictions and each is a stable per-cluster
label, so grouping by them is meaningful and the `novel_` prefix keeps them from
being mistaken for ICTV names. They also participate in the consistency check: a
rank vConTACT3 called novel is a positive claim that no known taxon fits, so a
lower-priority caller naming one there is a disagreement.
"""

import sys

import click
import pandas as pd

# Ranks written to the output table, in descending order. This is the union of
# what the supported callers produce: vConTACT3 predicts realm..genus (it has no
# species rank), MMseqs2's LCA reaches species but never subfamily.
RANKS = ["Realm", "Kingdom", "Phylum", "Class", "Order", "Family", "Subfamily",
         "Genus", "Species"]

# Values that mean "this caller made no call here". Read as strings and compared
# after stripping, because the callers disagree about how to spell a blank:
# `parse_mmseqsTaxa.py` is invoked with `-u ""`, vConTACT3 writes an empty field
# for pd.NA, and pandas turns an empty CSV field into NaN.
# `singleton` and `default` are vConTACT3 status markers that it writes into
# `realm_prediction` itself -- the first for a genome that clustered with
# nothing, the second for one whose component got no realm. Neither is a taxon,
# and both would otherwise be written into the Realm column as if they were.
MISSING = {"", "na", "n/a", "nan", "none", "null", "unknown", "unassigned",
           "unclassified", "-", ".", "singleton", "default"}

# How a `Reference` flag may be spelled. Anything outside both sets is not given
# a default, because defaulting either way is wrong in a way nobody would
# notice: treat an unknown flag as False and RefSeq genomes are reported as
# contigs of the dataset, treat it as True and real contigs vanish.
TRUTHY = {"true", "t", "yes", "y", "1", "1.0"}
FALSY = {"false", "f", "no", "n", "0", "0.0"}


def _usable(series):
    """True where the value is a real assignment rather than a blank or marker."""
    values = series.astype("string").str.strip()
    return values.notna() & ~values.str.casefold().isin(MISSING)


def _clean(df):
    """Normalise a reader's frame: string values, blanks as NA, unique index."""
    df = df.reindex(columns=[rank for rank in RANKS if rank in df.columns])
    for rank in df.columns:
        values = df[rank].astype("string").str.strip()
        df[rank] = values.where(_usable(values))
    df.index = df.index.astype("string").str.strip()
    df = df[df.index.notna() & (df.index != "")]
    duplicated = df.index.duplicated(keep="first")
    if duplicated.any():
        print(f"[merge_taxonomy] dropped {int(duplicated.sum())} duplicate contig "
              f"ids, keeping the first of each", flush=True)
        df = df[~duplicated]
    df.index.name = "contig_id"
    return df


def read_vcontact3(path):
    """vConTACT3 `exports/final_assignments.csv`.

    Only the `<rank>_prediction` columns are used; `<rank>_reference` holds the
    genome's own label and is populated for reference genomes only.

    Reference genomes share the table with the query contigs -- 5343 of the 5358
    rows in a two-contig test run -- and have to be dropped, or the RefSeq
    genomes vConTACT3 clustered against would be reported as if they were
    contigs of this dataset. `Reference` is the boolean vConTACT3 sets from the
    reference database's ID list, which is why this no longer has to guess from
    the contig name.

    Only rows flagged explicitly false are kept. The flag is blank for genomes
    that clustered with nothing, because vConTACT3 sets it while assembling the
    clusters and then left-joins the genomes that have none: `export_assignments`
    backfills those rows' names and sizes from the reference database but never
    their `Reference` flag. Such a row carries no taxonomy either -- its only
    non-empty prediction is the marker `singleton` -- so dropping it loses
    nothing, and treating a blank as "not a reference" would have added every
    unclustered RefSeq genome to the table. Any row that is neither explicitly
    flagged nor empty of taxonomy stops the merge instead of being guessed at.
    """
    df = pd.read_csv(path, dtype=str, keep_default_na=False, na_values=[""])
    if df.empty:
        return _clean(pd.DataFrame(index=pd.Index([], name="Genome")))
    if "Reference" not in df.columns:
        raise click.ClickException(
            f"{path} has no 'Reference' column, so query contigs cannot be told "
            f"apart from the reference genomes vConTACT3 clustered against; "
            f"refusing to report reference genomes as contigs of this dataset")

    flag = df["Reference"].astype("string").str.strip().str.casefold()
    undecided = ~flag.isin(TRUTHY) & ~flag.isin(FALSY)
    if undecided.any():
        carries_taxonomy = pd.Series(False, index=df.index)
        for rank in RANKS:
            column = f"{rank.lower()}_prediction"
            if column in df.columns:
                carries_taxonomy |= _usable(df[column])
        lost = undecided & carries_taxonomy
        if lost.any():
            raise click.ClickException(
                f"{path} has {int(lost.sum())} rows whose 'Reference' flag is "
                f"unreadable but which do carry taxonomy, so they can be neither "
                f"kept nor dropped safely (first: "
                f"{df.loc[lost, 'Genome'].iloc[0]}). Expected {sorted(TRUTHY)} "
                f"or {sorted(FALSY)}")
        print(f"[merge_taxonomy] {int(undecided.sum())} genomes in {path} have no "
              f"'Reference' flag and no taxonomy (vConTACT3 clustered them with "
              f"nothing); dropped", flush=True)

    df = df[flag.isin(FALSY)]
    predictions = pd.DataFrame(index=pd.Index(df["Genome"], name="Genome"))
    for rank in RANKS:
        column = f"{rank.lower()}_prediction"
        if column in df.columns:
            predictions[rank] = df[column].to_numpy()
    return _clean(predictions)


def read_mmseqs(path):
    """The `<prefix>.tsv` written by `parse_mmseqsTaxa.py`.

    Its rank columns are already named as in `RANKS`. With
    `--taxa_db_source NCBI` it carries a `Domain` column instead of `Realm`;
    that column is dropped rather than mapped, because NCBI's domain for viruses
    is the superkingdom `Viruses` and not an ICTV realm.
    """
    df = pd.read_csv(path, sep="\t", dtype=str, keep_default_na=False,
                     na_values=[""])
    if df.empty:
        return _clean(pd.DataFrame(index=pd.Index([], name="contig_id")))
    return _clean(df.set_index("contig_id"))


# Source name -> reader. A reader takes a path and returns a frame indexed by
# contig id whose columns are a subset of RANKS. Add VITAP and geNomad here.
READERS = {
    "vcontact3": read_vcontact3,
    "mmseqs": read_mmseqs,
}


def resolve(frames):
    """Per rank, take the assignment of the first frame that has one and that
    does not contradict the lineage resolved above it.

    `frames` is a list of (name, frame) already ordered by priority. Ranks are
    resolved top down, so by the time a rank is reached everything above it is
    settled. Returns the merged table and the number of assignments dropped for
    contradicting the lineage above them.
    """
    contigs = pd.Index([], dtype="string", name="contig_id")
    for _, frame in frames:
        contigs = contigs.union(frame.index)

    merged = pd.DataFrame(index=contigs)
    suppressed = 0
    for depth, rank in enumerate(RANKS):
        values = pd.Series(pd.NA, index=contigs, dtype="string")
        origin = pd.Series(pd.NA, index=contigs, dtype="string")
        for name, frame in frames:
            if rank not in frame.columns:
                continue
            candidate = frame[rank].reindex(contigs)

            # Compared case-insensitively so that a difference in capitalisation
            # is not mistaken for a difference in taxon.
            agrees = pd.Series(True, index=contigs)
            for above in RANKS[:depth]:
                if above not in frame.columns:
                    continue
                theirs = frame[above].reindex(contigs).str.casefold()
                ours = merged[above].str.casefold()
                conflict = (theirs.notna() & ours.notna() & (theirs != ours))
                agrees &= ~conflict.fillna(False).astype(bool)

            offered = values.isna() & candidate.notna()
            suppressed += int((offered & ~agrees).sum())
            fill = offered & agrees
            values = values.mask(fill, candidate)
            origin = origin.mask(fill, name)
        merged[rank] = values
        merged[f"{rank}_source"] = origin
    return merged, suppressed


def summarise(merged, frames, suppressed):
    """Print per-rank coverage, how often lineages mix sources, and how many
    assignments were dropped for contradicting the lineage above them."""
    total = len(merged)
    print(f"[merge_taxonomy] {total} contigs from {len(frames)} sources: "
          f"{', '.join(name for name, _ in frames)}", flush=True)
    if total == 0:
        return
    for rank in RANKS:
        assigned = merged[rank].notna()
        if not assigned.any():
            print(f"[merge_taxonomy]   {rank:<10} 0/{total}", flush=True)
            continue
        by_source = merged.loc[assigned, f"{rank}_source"].value_counts()
        breakdown = ", ".join(f"{name}={count}" for name, count in by_source.items())
        print(f"[merge_taxonomy]   {rank:<10} {int(assigned.sum())}/{total} "
              f"({breakdown})", flush=True)

    source_columns = [f"{rank}_source" for rank in RANKS]
    distinct = merged[source_columns].nunique(axis=1, dropna=True)
    mixed = int((distinct > 1).sum())
    print(f"[merge_taxonomy] {mixed}/{total} contigs have a lineage assembled "
          f"from more than one source", flush=True)
    print(f"[merge_taxonomy] {suppressed} assignments were dropped for "
          f"contradicting the lineage resolved above them", flush=True)


@click.command()
@click.option("--source", "sources", nargs=3, multiple=True, required=True,
              metavar="NAME PRIORITY FILE",
              help="A taxonomy caller to merge, e.g. `--source vcontact3 1 "
                   "final_assignments.csv`. NAME selects the reader and labels "
                   "the assignment in the output; PRIORITY is an integer where "
                   "smaller wins. Repeat for each caller.")
@click.option("--fout", "-o", default="taxonomy.tsv", show_default=True,
              help="Output table.")
def main(sources, fout):
    parsed = []
    for name, priority, path in sources:
        if name not in READERS:
            raise click.BadParameter(
                f"no reader for source '{name}'; known sources are "
                f"{', '.join(sorted(READERS))}", param_hint="--source")
        try:
            rank = int(priority)
        except ValueError:
            raise click.BadParameter(
                f"priority for source '{name}' must be an integer, got "
                f"'{priority}'", param_hint="--source")
        parsed.append((rank, name, path))

    priorities = [rank for rank, _, _ in parsed]
    if len(set(priorities)) != len(priorities):
        print("[merge_taxonomy] WARNING: two sources share a priority; ties are "
              "broken by the order the --source options were given", flush=True,
              file=sys.stderr)

    # Stable, so equal priorities keep their command-line order.
    parsed.sort(key=lambda item: item[0])

    frames = []
    for rank, name, path in parsed:
        frame = READERS[name](path)
        print(f"[merge_taxonomy] read {len(frame)} contigs from {name} "
              f"(priority {rank}): {path}", flush=True)
        frames.append((name, frame))

    merged, suppressed = resolve(frames)
    summarise(merged, frames, suppressed)
    merged.sort_index().to_csv(fout, sep="\t", index=True, na_rep="")


if __name__ == "__main__":
    main()
