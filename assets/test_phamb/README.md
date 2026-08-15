# PHAMB fixture

Real output from the sixteen-sample reference run, cut down to what
[`tests/phamb_entry.nf`](../../tests/phamb_entry.nf) needs to exercise the PHAMB binning path
without first running assembly, dereplication, CheckV and geNomad.

It exists because that path cannot be run on the development machine at all — VAMB has no
linux-aarch64 build — so the only place it can execute is CI, and CI cannot spend hours
regenerating inputs that already exist.

| File | What it is | From |
|---|---|---|
| `putative_vcontigs.fasta` | 102 putative viral contigs, the union `VIRCONTIGS_PRE` forms | `vircontigs/putative_vcontigs_pref1.fasta` |
| `genomad_virus_summary.tsv` | geNomad per-contig virus scores; `PHAMB_DVF_TABLE` converts these into DeepVirFinder's layout | `genomad/virus_genomad_summary.tsv` |
| `bams/*.bam` | Six samples (HT02, HT03, HT04, UC20, UC21, UC24), the smallest of the sixteen | `mapping2contigs2/` |

All from `/mnt/nas26/testdata/viroprofiler_16sample/run_dram/`, about 7 MB in total.

## Two things about it that are deliberate

**The contig count and the BAM count do not match, and must not.** The contigs are the viral
subset (102 sequences); the BAMs are mapped against the whole dereplicated library (161). That
is how a real run reaches `VAMB`, and it is the reason `VAMB`'s script rebuilds the depth table
in FASTA order by name lookup instead of using `jgi_summarize_bam_contig_depths` output
directly — `--jgi` pairs depths to contigs *positionally*, so a table that is merely longer
than the FASTA silently misassigns every abundance from the first extra row onward. A tidied
fixture with 102 contigs and 102 depth rows would pass while testing none of that.

**Six samples, not two.** VAMB clusters on tetranucleotide frequency *and* co-abundance across
samples, so the number of samples is part of what is being tested. Six is a compromise against
the ~7 MB budget; all sixteen would be 41 MB.

## Regenerating it

Any run of the pipeline produces these files. Copy the three paths in the table above out of a
completed `--outdir`. If the reference run is rebuilt, the contig names change, and the fixture
has to be replaced as a set — a FASTA from one run with BAMs from another is exactly the
mismatch `VAMB` is written to refuse.
