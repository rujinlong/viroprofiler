include { DB_CHECKV; DB_PHAMB; DB_VIRSORTER2; DB_DRAM; DB_VIBRANT; DB_IPHOP; DB_EGGNOG; DB_VOGDB; DB_MICOMPLETEDB; DB_VREFSEQ; DB_VCONTACT3; DB_VITAP; DB_KRAKEN2; DB_GENOMAD; DB_CHECKAMG } from "../../modules/local/setup_db"

workflow SETUP {
    main:
    DB_CHECKV()
    DB_GENOMAD()
    DB_VIRSORTER2()

    if (params.use_vibrant) {
        DB_VIBRANT()
    }
    if (params.use_checkamg) {
        DB_CHECKAMG()
    }
    if (params.use_dram) {
        DB_DRAM()
    }
    if (params.use_eggnog) {
        DB_EGGNOG()
    }

    // contig annotation
    if (params.use_iphop) {
        DB_IPHOP()
    }

    // taxonomy
    DB_VREFSEQ()
    DB_VCONTACT3()
    if (params.use_vitap) {
        DB_VITAP()
    }
    if (params.use_kraken2) {
        DB_KRAKEN2()
    }

    // binning
    if (params.use_phamb) {
        DB_PHAMB()
        DB_VOGDB()
        DB_MICOMPLETEDB()
    }
}
