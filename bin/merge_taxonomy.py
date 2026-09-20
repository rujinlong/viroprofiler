#!/usr/bin/env python
"""Merge per-contig taxonomy from several callers into one table.

Which callers to merge is data, not code: every source is declared on the
command line as a (name, priority, file) triple, so adding geNomad to the
pipeline means adding one `--source` line to `TAXONOMY_MERGE`, not editing the
resolution logic. What each caller's file *looks like* is the one thing that
cannot be data -- every tool writes its own layout -- so each name maps to a
reader in `READERS` below, and a new caller needs a reader beside its entry
there.

Resolution is per rank: for a given contig and a given rank, the highest-priority
source that assigned anything at that rank wins. A smaller priority number means
higher priority, so `--source vitap 1 ...` is consulted before
`--source vcontact3 3 ...`.

A lineage may therefore be assembled from more than one caller -- family from
vConTACT3, species from VITAP, say. That is the point, but taken literally it
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

import os
import sys

import click
import pandas as pd

# Ranks written to the output table, in descending order. This is the union of
# what the supported callers produce: vConTACT3 predicts realm..genus (it has no
# species rank) and VITAP realm..species (it has no subfamily). Subfamily is
# kept because a caller that reports it may be added later, and dropping a rank
# from this list would silently discard its assignments.
RANKS = ["Realm", "Kingdom", "Phylum", "Class", "Order", "Family", "Subfamily",
         "Genus", "Species"]

# Values that mean "this caller made no call here". Read as strings and compared
# after stripping, because the callers disagree about how to spell a blank:
# vConTACT3 writes an empty field for pd.NA, and pandas turns an empty CSV field
# into NaN.
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


# The ranks VITAP packs into its single `lineage` column, in the order it writes
# them: deepest first, no subfamily. `pad_lineage` in VITAP_assignment pads short
# lineages on the *left*, so the string always holds exactly these eight fields
# and Realm is always last.
VITAP_RANKS = ["Species", "Genus", "Family", "Order", "Class", "Phylum",
               "Kingdom", "Realm"]

# VITAP writes the reference genomes it mixed into the query set to this file,
# beside the lineage table in the same result directory.
VITAP_REFERENCE_GENOMES = "ICTV_selected_genomes.fasta"


def read_vitap(path):
    """VITAP `best_determined_lineages.tsv`.

    Four columns: `Genome_ID`, `lineage`, a score, and `Confidence_level`. Only
    the first two are read. The score column is named `lineage_score` up to
    VITAP 1.7 and `lineage_score/participation_index` from 1.10, which is why it
    is selected by position in the header rather than by name -- and why nothing
    here has to change to read a newer VITAP.

    Every row is kept regardless of `Confidence_level`. `VITAP assignment`
    already drops its low-confidence calls unless asked for them with
    `--low_conf`, and it blanks the species and genus of everything it is not
    confident about, so what reaches this table is the caller's own answer and
    not something to second-guess here.

    VITAP writes `[<Rank>]_<child>` where ICTV has no taxon at a rank above one
    it did assign -- `[Order]_Peduoviridae` for a family that belongs to no
    order. Those are kept, for the same reason vConTACT3's `novel_` labels are:
    each is a positive claim that no known taxon fits, it is stable enough to
    group by, and the bracketed prefix keeps it from being mistaken for an ICTV
    name. Dropping them would also be actively harmful, because it would let a
    lower-priority caller write the order that VITAP is saying does not exist.

    Reference genomes share the table with the query contigs, exactly as in
    vConTACT3, and again have to be dropped or RefSeq genomes are reported as
    contigs of this dataset. VITAP marks nothing: `VITAP assignment` picks five
    reference genomes with `seqkit sample`, concatenates them onto the query
    FASTA and classifies the union, so the output carries no column that tells
    the two apart. What it does write is the FASTA of exactly those genomes,
    beside this table -- and since the classified set is precisely
    `input FASTA + ICTV_selected_genomes.fasta`, subtracting that file's IDs
    leaves the query contigs and nothing else. That file is therefore required:
    without it there is no way to tell a contig from a reference, and guessing
    from the shape of an accession is how RefSeq genomes end up in the output.
    """
    references = os.path.join(os.path.dirname(path), VITAP_REFERENCE_GENOMES)
    if not os.path.isfile(references):
        raise click.ClickException(
            f"{references} is missing. VITAP mixes reference genomes into the "
            f"genomes it classifies and writes them to that file; without it "
            f"the query contigs cannot be told apart from the reference "
            f"genomes in {path}, and refusing is better than reporting RefSeq "
            f"genomes as contigs of this dataset")
    with open(references) as handle:
        reference_ids = {line[1:].split()[0] for line in handle
                         if line.startswith(">") and line[1:].strip()}

    df = pd.read_csv(path, sep="\t", dtype=str, keep_default_na=False,
                     na_values=[""])
    for column in ("Genome_ID", "lineage"):
        if column not in df.columns:
            raise click.ClickException(
                f"{path} has no '{column}' column; expected the four-column "
                f"`best_determined_lineages.tsv` VITAP writes")
    if df.empty:
        return _clean(pd.DataFrame(index=pd.Index([], name="Genome_ID")))

    genomes = df["Genome_ID"].astype("string").str.strip()
    leaked = genomes.isin(reference_ids)
    if leaked.any():
        print(f"[merge_taxonomy] dropped {int(leaked.sum())} of "
              f"{len(reference_ids)} VITAP reference genomes from {path}",
              flush=True)
    df = df[~leaked.fillna(False)]

    text = df["lineage"].astype("string").fillna("")
    # Every row must carry all eight fields. VITAP guarantees it -- `pad_lineage`
    # in VITAP_assignment fills a short lineage up to eight before writing, and
    # it pads on the *left*, so the last field is always Realm. Depending on that
    # rather than repairing short rows here is deliberate: pandas' `str.split`
    # pads on the right, so a row that really did arrive short would be read as
    # Species-first and every value in it would land one or more ranks too deep
    # -- a genus written into the Family column, silently. Checked against 25
    # VITAP result files (445k rows), every one of which has exactly eight.
    widths = text.str.count(";") + 1
    wrong = widths != len(VITAP_RANKS)
    if wrong.any():
        raise click.ClickException(
            f"{path} has {int(wrong.sum())} lineages that are not "
            f"{len(VITAP_RANKS)} fields wide (first: "
            f"{df.loc[wrong, 'Genome_ID'].iloc[0]}, "
            f"{int(widths[wrong].iloc[0])} fields). Either a taxon name "
            f"contains ';', which shifts every rank below it, or this is not a "
            f"VITAP `best_determined_lineages.tsv`")

    lineages = text.str.split(";", expand=True)
    predictions = pd.DataFrame(index=pd.Index(genomes[~leaked.fillna(False)],
                                              name="Genome_ID"))
    for offset, rank in enumerate(VITAP_RANKS):
        predictions[rank] = lineages[offset].to_numpy()
    return _clean(predictions)


# Source name -> reader. A reader takes a path and returns a frame indexed by
# contig id whose columns are a subset of RANKS. Add geNomad here.
READERS = {
    "vitap": read_vitap,
    "vcontact3": read_vcontact3,
}


# The columns vpfkit's `read_taxonomy2()` requires, in the order it lists them.
# It selects exactly these, drops any row whose `taxa_id` is 0, and
# `create_vpftse_vir()` then treats a non-missing `Domain` as one of the votes
# that make a contig viral. Nothing else in the file is read.
TSE_RANKS = ["Domain", "Kingdom", "Phylum", "Class", "Order", "Family",
             "Genus", "Species"]


def write_tse_table(merged, path):
    """Write the merged lineages in the layout `RESULTS_TSE` feeds to vpfkit.

    Two columns are not a straight copy of a merged rank:

    `Domain` is the ICTV realm where one was resolved, and the literal
    `Viruses` where a lower rank was resolved but no realm was. The fallback is
    not a placeholder: NCBI's superkingdom for every virus is `Viruses`, which
    is what this column is defined to hold, and `create_vpftse_vir()` reads it
    as "some caller placed this contig". Leaving it empty for a contig assigned
    only at, say, family would drop that contig from the viral TSE without a
    word.

    `taxa_id` is 1 for a contig with any assignment and 0 for one with none,
    because vpfkit only ever compares it against 0. It is deliberately not an
    NCBI taxid: the callers that remain report names, not taxids, and inventing
    a lookup here would be inventing precision.

    `Subfamily` has no column in the vpfkit layout and is dropped. The complete
    merged table, subfamily and per-rank provenance included, is `taxonomy.tsv`.
    """
    assigned = merged[RANKS].notna().any(axis=1)

    out = pd.DataFrame(index=merged.index)
    out["taxa_id"] = assigned.astype(int)
    out["Domain"] = merged["Realm"].where(merged["Realm"].notna(),
                                          pd.Series("Viruses", index=merged.index)
                                          .where(assigned))
    for rank in TSE_RANKS[1:]:
        out[rank] = merged[rank]

    out.to_csv(path, sep="\t", index=True, na_rep="")
    print(f"[merge_taxonomy] {int(assigned.sum())}/{len(merged)} contigs carry an "
          f"assignment and will reach the TSE: {path}", flush=True)


def resolve(frames):
    """Per rank, take the assignment of the first frame that has one and that
    does not contradict the lineage resolved above it.

    `frames` is a list of (name, frame) already ordered by priority. Ranks are
    resolved top down, so by the time a rank is reached everything above it is
    settled. Returns the merged table, the number of assignments dropped for
    contradicting the lineage above them, and the number of contigs whose
    lineage contains at least one unbridged transition.

    An unbridged transition is the limit of what this check can promise. A
    source is only ever compared against the ranks it has a value for, so where
    it has none -- no column at all, or a blank -- it cannot contradict what is
    already resolved, and is accepted by default. Both happen constantly here:
    VITAP has no Subfamily column while vConTACT3 does, and VITAP assigns a
    family without an order for about one contig in six, so a lineage can take
    its family from one caller and its genus from another with nothing in
    between to reconcile them. The result can be a chimaera that is worse than
    either caller's own answer. Deciding which one is right needs a taxonomy to
    look the names up in, which is not available at merge time, so these are
    counted and reported rather than resolved.
    """
    contigs = pd.Index([], dtype="string", name="contig_id")
    for _, frame in frames:
        contigs = contigs.union(frame.index)

    merged = pd.DataFrame(index=contigs)
    suppressed = 0
    unbridged = pd.Series(False, index=contigs)
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

        # Flag the transitions the agreement check above could not make. A rank
        # is unbridged when the source that filled it had nothing at some rank
        # further up that a different source did fill: the two were never
        # compared, and nothing here can say whether they belong together.
        for name, frame in frames:
            filled = (origin == name).fillna(False)
            if not filled.any():
                continue
            for above in RANKS[:depth]:
                theirs = (frame[above].reindex(contigs) if above in frame.columns
                          else pd.Series(pd.NA, index=contigs, dtype="string"))
                gap = (filled & merged[above].notna() & theirs.isna()
                       & (merged[f"{above}_source"] != name))
                unbridged |= gap.fillna(False)
    return merged, suppressed, int(unbridged.sum())


def summarise(merged, frames, suppressed, unbridged):
    """Print per-rank coverage, how often lineages mix sources, how many
    assignments were dropped for contradicting the lineage above them, and how
    many lineages mix sources across a rank that was never reconciled."""
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
    print(f"[merge_taxonomy] {unbridged}/{total} contigs took a rank from a "
          f"source that had no value at some rank above it, so the two were "
          f"never checked against each other", flush=True)


@click.command()
@click.option("--source", "sources", nargs=3, multiple=True, required=True,
              metavar="NAME PRIORITY FILE",
              help="A taxonomy caller to merge, e.g. `--source vcontact3 1 "
                   "final_assignments.csv`. NAME selects the reader and labels "
                   "the assignment in the output; PRIORITY is an integer where "
                   "smaller wins. Repeat for each caller.")
@click.option("--fout", "-o", default="taxonomy.tsv", show_default=True,
              help="Output table: every rank, with the source that filled it.")
@click.option("--fout-tse", "fout_tse", default="taxonomy_tse.tsv",
              show_default=True,
              help="Second output, in the layout vpfkit's read_taxonomy2() "
                   "requires, for RESULTS_TSE to read.")
def main(sources, fout, fout_tse):
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

    merged, suppressed, unbridged = resolve(frames)
    summarise(merged, frames, suppressed, unbridged)
    merged = merged.sort_index()
    merged.to_csv(fout, sep="\t", index=True, na_rep="")
    write_tse_table(merged, fout_tse)


if __name__ == "__main__":
    main()
