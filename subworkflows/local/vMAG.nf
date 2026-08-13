include { CHECKV as CHECKV4PHAMB; CHECKV as CHECKV4VRHYME } from '../../modules/local/viral_detection'
include { VAMB; PHAMB_DVF_TABLE; PHAMB_RF; VRHYME } from '../../modules/local/binning'
include { GENEPRED as GENEPRED4BIN } from '../../modules/local/gene_library'
include { MICOMPLETEDB; VOGDB } from '../../modules/local/annotation'

workflow vMAG_PHAMB {
    take:
    ch_contigs
    // GENOMAD's per-contig virus summary. PHAMB's forest wants DeepVirFinder's
    // score table; PHAMB_DVF_TABLE converts geNomad's scores into that layout,
    // which is an approximation -- see bin/genomad_to_dvf.py.
    ch_genomad_score
    ch_bams

    main:
    // VAMB
    VAMB(ch_contigs, ch_bams)
    vamb_CLUSTERS = VAMB.out.vamb_clusters_ch

    // Per-contig virus score, in DeepVirFinder's format
    PHAMB_DVF_TABLE(ch_contigs, ch_genomad_score)

    // Protein annotation
    GENEPRED4BIN(ch_contigs, "input4bin")
    MICOMPLETEDB(GENEPRED4BIN.out.prot_ch)
    VOGDB(GENEPRED4BIN.out.prot_ch)

    // Random forest model to predict viral bins
    PHAMB_RF(ch_contigs, PHAMB_DVF_TABLE.out.dvf_table_ch, MICOMPLETEDB.out.hmm_miComplete, VOGDB.out.hmm_VOGDB, vamb_CLUSTERS)

    // QC + Remove host region in prophage
    CHECKV4PHAMB(PHAMB_RF.out.phamb_bins)

    emit:
    CHECKV4PHAMB.out.checkv_qc_ch

}


workflow vMAG_VRHYME {
    take:
    ch_contigs
    ch_genes
    ch_prots
    ch_bams

    main:
    VRHYME(ch_contigs, ch_genes, ch_prots, ch_bams)

    // QC + remove host region in prophage
    CHECKV4VRHYME(VRHYME.out.vrhyme_merge_ch)

    emit:
    CHECKV4VRHYME.out.checkv_qc_ch
}
