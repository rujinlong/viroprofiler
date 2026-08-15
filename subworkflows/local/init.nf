include { DB_CHECKV; DB_VIRSORTER2; DB_DRAM; DB_VIBRANT; DB_IPHOP; DB_EGGNOG; DB_VOGDB; DB_MICOMPLETEDB; DB_VCONTACT3; DB_VITAP; DB_KRAKEN2; DB_GENOMAD; DB_CHECKAMG } from "../../modules/local/setup_db"

workflow SETUP {
    main:
    // Create --db here, on the host, before any container starts. Docker creates a
    // missing bind-mount source itself and does so as root, while the container runs
    // as the invoking user (`docker.runOptions = '-u $(id -u):$(id -g)'`) -- so
    // pointing --db at a path that does not exist yet produces a directory the
    // pipeline cannot write into. The symptom is a `mkdir: Permission denied` from
    // whichever DB_* process gets there first, typically several hundred MB into a
    // download, and it names neither Docker nor the mount.
    //
    // Nextflow runs this on the host as the invoking user, so the directory exists
    // and is owned correctly by the time anything is mounted.
    file(params.db).mkdirs()

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
    DB_VCONTACT3()
    if (params.use_vitap) {
        DB_VITAP()
    }
    if (params.use_kraken2) {
        DB_KRAKEN2()
    }

    // binning. PHAMB's random forest ships inside the phamb package, so only the two
    // HMM sets its features are computed from have to be downloaded.
    if (params.use_phamb) {
        DB_VOGDB()
        DB_MICOMPLETEDB()
    }
}
