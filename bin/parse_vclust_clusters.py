#!/usr/bin/env python3
"""Turn a Vclust cluster table into ViroProfiler's contig cluster outputs.

`vclust cluster --out-repr` writes one `<contig> <representative>` row per
sequence it was given. Two things still have to happen before the rest of the
pipeline can use it:

1.  `vclust deduplicate` runs first and drops contigs whose sequence is byte
    identical to another contig (or its reverse complement). Those contigs are
    absent from the cluster table, so they are read back from the deduplicator's
    `.duplicates.txt` companion file and attached to the cluster of the contig
    that displaced them. Without this step the pooled library would silently
    lose every contig that more than one sample assembled.

2.  The old BLAST-based chain emitted a `repid`/`ctgid` table, and the published
    outputs, the TSE and any downstream script keep that contract.

Outputs
-------
--out-tsv   `repid<TAB>ctgid`, one row per contig, header included.
--out-list  Representative ids, one per line, for `seqkit grep`.

Stdlib only: this runs inside the Vclust image, which carries no pandas.
"""

import argparse
import sys


def read_clusters(path):
    """Read `vclust cluster -r` output: object<TAB>cluster-representative."""
    rep_of = {}
    with open(path) as handle:
        header = handle.readline()
        if not header:
            sys.exit("error: %s is empty" % path)
        if not header.lower().startswith("object"):
            sys.exit("error: %s does not look like `vclust cluster` output "
                     "(first line: %r)" % (path, header.rstrip()))
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            fields = line.split("\t")
            if len(fields) != 2:
                sys.exit("error: %s line %r has %d fields, expected 2"
                         % (path, line, len(fields)))
            rep_of[fields[0]] = fields[1]
    return rep_of


def read_duplicates(path):
    """Read `vclust deduplicate` output: kept-id followed by the ids it displaced.

    Fields are whitespace separated. A duplicate that matched the kept sequence
    in reverse-complement orientation is written with a leading '-'; the
    orientation is irrelevant here because either way the two contigs carry the
    same sequence and belong in the same cluster.
    """
    duplicates = {}
    with open(path) as handle:
        for line in handle:
            fields = line.split()
            if len(fields) < 2:
                continue
            kept = fields[0].lstrip("-")
            duplicates.setdefault(kept, []).extend(f.lstrip("-") for f in fields[1:])
    return duplicates


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--clusters", required=True,
                        help="`vclust cluster --out-repr` table")
    parser.add_argument("--duplicates",
                        help="`vclust deduplicate` .duplicates.txt companion file")
    parser.add_argument("--out-tsv", required=True,
                        help="output repid/ctgid table")
    parser.add_argument("--out-list", required=True,
                        help="output list of representative ids")
    args = parser.parse_args()

    rep_of = read_clusters(args.clusters)

    if args.duplicates:
        for kept, dups in read_duplicates(args.duplicates).items():
            if kept not in rep_of:
                sys.exit("error: %s lists %r as a kept sequence, but it is "
                         "absent from %s" % (args.duplicates, kept, args.clusters))
            for dup in dups:
                rep_of[dup] = rep_of[kept]

    # Group by representative, keeping the representative itself first so the
    # table reads the same way the old `aniclust.py` map did.
    members = {}
    for contig, rep in rep_of.items():
        members.setdefault(rep, [])
        if contig != rep:
            members[rep].append(contig)

    with open(args.out_tsv, "w") as tsv, open(args.out_list, "w") as lst:
        tsv.write("repid\tctgid\n")
        for rep in sorted(members):
            lst.write("%s\n" % rep)
            tsv.write("%s\t%s\n" % (rep, rep))
            for contig in sorted(members[rep]):
                tsv.write("%s\t%s\n" % (rep, contig))

    sys.stderr.write("%d contigs in %d clusters\n" % (len(rep_of), len(members)))


if __name__ == "__main__":
    main()
