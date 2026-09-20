/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Run the PHAMB binning path, and nothing else
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

`vMAG_PHAMB` is called from exactly one place, deep inside VIROPROFILER, and
CONTIGANNO has no binning path -- so there is no way to reach it without first
running assembly, dereplication, CheckV and geNomad. That matters more here than
for other subworkflows, because PHAMB is the one path with no aarch64 execution
route at all: VAMB has no linux-aarch64 build, so it can only ever be exercised
on x86-64, which in practice means CI.

Two stages, selected with `--phamb_stage`:

    # 1. the two HMM databases PHAMB needs, and only those
    nextflow run phamb_entry.nf -profile docker \
        --phamb_stage databases --mode setup --db /path/to/db

    # 2. the binning path itself, from a fixture
    nextflow run phamb_entry.nf -profile docker --db /path/to/db \
        --phamb_contigs assets/test_phamb/putative_vcontigs.fasta \
        --phamb_genomad assets/test_phamb/genomad_virus_summary.tsv \
        --phamb_bams   'assets/test_phamb/bams/*.bam'

A param rather than `-entry`, because the strict parser rejects `-entry`
outright: "use a param to run a named workflow from the entry workflow". That is
also why the pipeline selects its own stages with `--mode`.

Stage 1 goes through the real `DB_VOGDB` and `DB_MICOMPLETEDB` rather than a
shell script, deliberately: both were broken until recently -- in ways their own
content checks now catch -- so running them here keeps that fixed. `--mode
setup` on `main.nf` would instead build all sixteen databases, including CheckV
at 6.4 GB and DRAM at 38 GB, none of which PHAMB reads.

What stage 2 does NOT establish, and must not be read as establishing: that the
upstream stages produce these files correctly. It starts from a fixture, so it
tests VAMB, PHAMB_DVF_TABLE, GENEPRED, MICOMPLETEDB, VOGDB and PHAMB_RF, and
takes their inputs on faith. The fixture is real output from the sixteen-sample
reference run, which is the closest available substitute.

Note the asymmetry the fixture preserves deliberately: the contigs are the viral
subset (102 sequences) while the BAMs are mapped against the whole dereplicated
library (161). VAMB's depth table has to be rebuilt in FASTA order because
`--jgi` pairs depths to contigs positionally, and that is precisely the code
path a fixture with matching counts would fail to exercise.
*/

include { vMAG_PHAMB } from './subworkflows/local/vMAG'
include { DB_VOGDB; DB_MICOMPLETEDB; DB_CHECKV } from './modules/local/setup_db'

params.phamb_stage   = 'run'
params.phamb_contigs = null
params.phamb_genomad = null
params.phamb_bams    = null

workflow {
    if (params.phamb_stage == 'databases') {
        // As in SETUP: create --db on the host first, or Docker creates it as root
        // while the container runs as the invoking user, and every DB_* process
        // fails on `mkdir: Permission denied`.
        file(params.db).mkdirs()

        DB_VOGDB()
        DB_MICOMPLETEDB()
        // CheckV as well: vMAG_PHAMB ends in CHECKV4PHAMB, which QCs the bins the
        // random forest called, so the path does not complete without it. At
        // 6.4 GB it is the largest single cost of running PHAMB.
        DB_CHECKV()
    }
    else if (params.phamb_stage == 'run') {
        if (!params.phamb_contigs || !params.phamb_genomad || !params.phamb_bams) {
            error """
            --phamb_stage run needs three inputs:
              --phamb_contigs  putative viral contigs FASTA (VIRCONTIGS_PRE output)
              --phamb_genomad  geNomad per-contig virus summary TSV
              --phamb_bams     glob of BAMs mapped against the full contig library
            See assets/test_phamb/ for a fixture from the reference run.
            """.stripIndent()
        }

        ch_contigs = channel.fromPath(params.phamb_contigs, checkIfExists: true)
        ch_genomad = channel.fromPath(params.phamb_genomad, checkIfExists: true)

        // `.collect()` because VAMB takes every BAM in one task -- one process
        // invocation over all samples, not one per sample.
        ch_bams = channel.fromPath(params.phamb_bams, checkIfExists: true).collect()

        vMAG_PHAMB(ch_contigs, ch_genomad, ch_bams)
    }
    else {
        error "Unknown --phamb_stage '${params.phamb_stage}'. Use 'databases' or 'run'."
    }
}
