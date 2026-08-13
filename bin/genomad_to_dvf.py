#!/usr/bin/env python
"""Write geNomad's per-contig virus scores in the layout PHAMB reads.

PHAMB's random forest takes four features per bin: total size, the number of
distinct bacterial hallmarks, VOGs per contig, and a length-weighted mean of a
per-contig virus score. It reads that last one from a file it expects to be
DeepVirFinder's `all.DVF.predictions.txt`, and this pipeline no longer runs
DeepVirFinder, so the score has to come from geNomad instead.

That substitution is not free and should be read as an approximation:

  * Both scores are a probability-like value in [0, 1] that a sequence is
    viral, so they occupy the same range and the same slot.
  * They are not the same quantity. DeepVirFinder scores k-mer composition with
    a CNN; geNomad scores marker content and gene topology. The forest was
    fitted on the first distribution and is applied here to the second, so the
    decision boundary it learned is not calibrated for these inputs.

The consequence is that PHAMB's viral/non-viral call on a bin may differ from
what the published model would have produced, in a direction this pipeline has
not measured. `--binning phamb` therefore documents itself as approximate;
`--binning vrhyme` needs no such caveat.

Every contig of the input FASTA gets a row. geNomad only reports the sequences
it called viral, and a contig missing from the file would be missing from
PHAMB's aggregation entirely rather than scored zero -- which would make the
length-weighted mean an average over the viral contigs of a bin instead of over
all of them, inflating the score of exactly those mixed bins the forest exists
to reject.
"""

import argparse
import sys

# The four whitespace-separated fields phamb's `_parse_dvf_row` unpacks, in
# order. It reads them positionally and ignores the header line, but writing
# DeepVirFinder's own names keeps the file recognisable.
HEADER = ("name", "len", "score", "pvalue")


def read_fasta_lengths(path):
    """contig id -> sequence length, in file order."""
    lengths = {}
    order = []
    name = None
    length = 0
    with open(path) as handle:
        for line in handle:
            if line.startswith(">"):
                if name is not None:
                    lengths[name] = length
                name = line[1:].split()[0]
                order.append(name)
                length = 0
            elif name is not None:
                length += len(line.strip())
    if name is not None:
        lengths[name] = length
    return order, lengths


def read_genomad_scores(path):
    """contig id -> virus_score AS WRITTEN, from the per-contig table GENOMAD publishes.

    The score is kept as the source text rather than parsed to a float and
    re-formatted. PHAMB applies `round(float(score), 2)` to whatever it reads, and
    rounding is not associative: re-emitting geNomad's 0.00499 through `%.4f`
    yields 0.0050, which PHAMB then rounds to 0.01 instead of 0.00. Passing the
    digits through unchanged makes the value PHAMB sees the value geNomad wrote.
    The text is validated as a float here so a malformed table still fails loudly.
    """
    scores = {}
    with open(path) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        for column in ("seq_name", "virus_score"):
            if column not in header:
                sys.exit("%s has no '%s' column; expected the per-contig table "
                         "genomad_contig_table.py writes" % (path, column))
        i_name = header.index("seq_name")
        i_score = header.index("virus_score")
        for line in handle:
            if not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) <= max(i_name, i_score):
                continue
            text = fields[i_score].strip()
            try:
                float(text)
            except ValueError:
                # The sentinel row genomad_contig_table.py writes when geNomad
                # called nothing carries "NA" here.
                continue
            scores[fields[i_name]] = text
    return scores


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", required=True,
                        help="virus_genomad_summary.tsv from GENOMAD")
    parser.add_argument("--contigs", required=True,
                        help="FASTA of the contigs PHAMB will bin")
    parser.add_argument("--out", default="all.DVF.predictions.txt")
    args = parser.parse_args()

    order, lengths = read_fasta_lengths(args.contigs)
    if not order:
        sys.exit("No sequences in %s" % args.contigs)
    scores = read_genomad_scores(args.summary)

    scored = 0
    with open(args.out, "w") as out:
        out.write("\t".join(HEADER) + "\n")
        for name in order:
            score = scores.get(name)
            if score is None:
                # Not called viral by geNomad, so it contributes a zero to the
                # bin's length-weighted mean rather than being absent from it.
                # Absence is not the same thing: PHAMB averages only over the
                # contigs that have a row, so omitting these would make a mixed
                # bin score as if it were made of its viral contigs alone.
                #
                # This is where the substitution is least faithful. DeepVirFinder
                # scores every contig and gives a non-viral one some small
                # non-zero value, so a zero here dilutes a bin slightly more than
                # DeepVirFinder would have. The bias is toward calling fewer bins
                # viral, which is the safe direction, but it is a bias.
                score, pvalue = "0.0", "1.0"
            else:
                scored += 1
                pvalue = "0.0"
            out.write("%s\t%d\t%s\t%s\n" % (name, lengths[name], score, pvalue))

    sys.stderr.write("geNomad scored %d of %d contigs; the rest were written as "
                     "0. PHAMB's forest was trained on DeepVirFinder scores, so "
                     "treat its bin calls as approximate.\n" % (scored, len(order)))


if __name__ == "__main__":
    main()
