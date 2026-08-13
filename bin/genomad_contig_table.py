#!/usr/bin/env python
"""Reduce geNomad's virus summary to one row per contig of the input library.

geNomad reports one row per *virus*, not per input sequence. When
`find-proviruses` excises an integrated element it emits the excised region under
a derived name (`<source contig>|provirus_<start>_<end>`), so the summary can
name sequences that do not exist in the contig library the rest of the pipeline
indexes, cluster and maps reads against.

Two downstream consumers need contig-level names:

  * `VIRCONTIGS_PRE` unions detector hit lists and pulls those names out of the
    non-redundant library with `seqkit grep`, which *silently drops* names it
    cannot find. A provirus name reaching that list would quietly remove a
    contig geNomad actually called viral.
  * `RESULTS_TSE` joins the score table onto `rowData` by contig ID, so a
    provirus name simply never matches and the contig looks unscored.

So map every row back to its parent contig, keep the highest-scoring row per
contig, and verify the result against the FASTA the caller actually searched --
an unmatched name is a bug, not something to pass on quietly.

Writes two files:
  <prefix>_virus_summary.tsv  geNomad's columns, keyed by contig, for vpfkit's
                              `read_genomad()` (needs seq_name, virus_score,
                              fdr, topology, taxonomy, n_hallmarks).
  <prefix>.list               contig IDs, one per line, for the detector union.
"""

import argparse
import os
import sys

# vpfkit's read_genomad() addresses these by name; keep them even when geNomad
# leaves them empty, or the reader raises.
REQUIRED_COLUMNS = ("seq_name", "virus_score", "fdr", "topology", "taxonomy",
                    "n_hallmarks")

# A header-only table makes data.table::fread infer logical columns, and joining
# a logical Contig column against the character contig IDs in rowData fails. One
# sentinel row fixes the inferred types; it matches no contig, and create_vpftse()
# joins from the contig side, so it never reaches the output.
SENTINEL_NAME = "__no_genomad_virus_placeholder__"


def read_fasta_ids(path):
    ids = set()
    with open(path) as handle:
        for line in handle:
            if line.startswith(">"):
                ids.add(line[1:].split()[0])
    return ids


def read_provirus_parents(path):
    """seq_name -> source_seq, straight from geNomad's own provirus table.

    Preferred over parsing the `|provirus_...` suffix out of the name, which is
    a private naming convention that has no reason to stay stable.
    """
    parents = {}
    if not path or not os.path.isfile(path):
        return parents
    with open(path) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        if "seq_name" not in header or "source_seq" not in header:
            return parents
        i_seq = header.index("seq_name")
        i_src = header.index("source_seq")
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) > max(i_seq, i_src):
                parents[fields[i_seq]] = fields[i_src]
    return parents


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", required=True,
                        help="geNomad <prefix>_virus_summary.tsv")
    parser.add_argument("--contigs", required=True,
                        help="FASTA geNomad was run on; every emitted name must be in it")
    parser.add_argument("--provirus", default=None,
                        help="geNomad <prefix>_provirus.tsv, for seq_name -> source_seq")
    parser.add_argument("--out-prefix", default="genomad_virus")
    args = parser.parse_args()

    contig_ids = read_fasta_ids(args.contigs)
    if not contig_ids:
        sys.exit("No sequences in %s" % args.contigs)
    parents = read_provirus_parents(args.provirus)

    with open(args.summary) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        missing = [c for c in REQUIRED_COLUMNS if c not in header]
        if missing:
            sys.exit("geNomad summary %s is missing columns: %s"
                     % (args.summary, ", ".join(missing)))
        i_name = header.index("seq_name")
        i_score = header.index("virus_score")

        best = {}     # contig -> (score, row)
        order = []    # contigs in first-seen order, so output is deterministic
        unmatched = []
        for line in handle:
            if not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            name = fields[i_name]
            # An exact hit against the library is authoritative and is tried first,
            # because contig IDs are allowed to contain "|" themselves -- NCBI-style
            # headers routinely do. Splitting such a name would hand its evidence to
            # whatever contig happens to share the prefix, and the unmatched check below
            # would not notice because that prefix is a real contig.
            # Then geNomad's own provirus mapping, and only then the naming convention.
            if name in contig_ids:
                contig = name
            elif name in parents:
                contig = parents[name]
            else:
                contig = name.split("|")[0]
            if contig not in contig_ids:
                unmatched.append((name, contig))
                continue
            try:
                score = float(fields[i_score])
            except ValueError:
                score = float("-inf")
            fields[i_name] = contig
            if contig not in best:
                order.append(contig)
                best[contig] = (score, fields)
            elif score > best[contig][0]:
                best[contig] = (score, fields)

    if unmatched:
        sys.stderr.write(
            "geNomad named %d sequence(s) that are absent from %s. Passing them on "
            "would silently drop contigs from the viral set, so this is fatal:\n"
            % (len(unmatched), args.contigs))
        for name, contig in unmatched[:20]:
            sys.stderr.write("  %s (resolved to %s)\n" % (name, contig))
        sys.exit(1)

    summary_out = "%s_summary.tsv" % args.out_prefix
    list_out = "%s.list" % args.out_prefix
    with open(summary_out, "w") as out:
        out.write("\t".join(header) + "\n")
        if order:
            for contig in order:
                out.write("\t".join(best[contig][1]) + "\n")
        else:
            row = ["NA"] * len(header)
            row[i_name] = SENTINEL_NAME
            row[i_score] = "0"
            out.write("\t".join(row) + "\n")

    with open(list_out, "w") as out:
        for contig in order:
            out.write(contig + "\n")

    sys.stderr.write("geNomad called %d of %d contigs viral\n"
                     % (len(order), len(contig_ids)))


if __name__ == "__main__":
    main()
