process DB_VIROPROFILER {
    label "viroprofiler_base"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    # TODO
    echo "Please download checkv database manually"
    """

    stub:
    """
    echo "DB_VIROPROFILER stub"
    """
}

process DB_CHECKV {
    label "viroprofiler_base"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/checkv ]; then
        checkv download_database $params.db
        mv $params.db/checkv-db-v* $params.db/checkv
    else
        echo "CheckV database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/checkv
    echo "DB_CHECKV stub"
    """
}


process DB_PHAMB {
    label "viroprofiler_base"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/phamb ]; then
        mkdir -p $params.db/phamb
        # wget -O $params.db/phamb/RF_model.sav "https://github.com/RasmussenLab/phamb/raw/master/workflows/mag_annotation/dbs/RF_model.sav"
        wget -O $params.db/phamb/RF_model.sav "https://raw.githubusercontent.com/RasmussenLab/phamb/master/phamb/dbs/RF_model.sav"
    else
        echo "PHAMB database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/phamb
    echo "DB_PHAMB stub"
    """
}


process DB_VIRSORTER2 {
    label "viroprofiler_virsorter2"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/virsorter2 ]; then
        virsorter setup -d ${params.db}/virsorter2 -j $task.cpus
    else
        echo "VirSorter2 database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/virsorter2
    echo "DB_VIRSORTER2 stub"
    """
}


process DB_DRAM {
    label "viroprofiler_geneannot"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/dram ]; then
        mkdir -p ${params.db}/dram
        # `prepare_databases` writes the CONFIG itself, filling in the absolute path of
        # every database as it is downloaded, but it can only read a CONFIG that already
        # exists. So export the empty template that ships inside mag_annotator (with
        # DRAM_CONFIG_LOCATION unset, otherwise `export_config` reads the file it is
        # supposed to create) and point DRAM at that copy for the actual build.
        unset DRAM_CONFIG_LOCATION
        DRAM-setup.py export_config --output_file ${params.db}/dram/CONFIG
        export DRAM_CONFIG_LOCATION=${params.db}/dram/CONFIG
        DRAM-setup.py prepare_databases --output_dir ${params.db}/dram --threads $task.cpus --skip_uniref
    else
        echo "DRAM database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/dram
    echo "DB_DRAM stub"
    """
}

process DB_VIBRANT {
    label "viroprofiler_vibrant"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/vibrant ]; then
        # `download-db.sh` ends with an unconditional `exit 0` and prints "databases are
        # downloaded successfully" even when VIBRANT_setup.py died, so its exit status
        # proves nothing. Build into the task work directory, verify the result, and only
        # then publish -- otherwise a 4 MB shell of a database gets left behind and the
        # directory-existence guard above makes that state permanent.
        mkdir -p vibrant_db
        export VIBRANT_DATA_PATH="/opt/conda/share/vibrant-1.2.1/db"
        download-db.sh \$(pwd)/vibrant_db
        find vibrant_db -type d -exec chmod u+rwx {} +
        find vibrant_db -type f -exec chmod u+rw {} +

        # VIBRANT_setup.py downloads VOG, Pfam and KEGG profiles and runs `hmmpress` on
        # each; the pressed databases are ~11 GB in total. Check for the binary index of
        # all three rather than trusting the exit status.
        for hmm in VOGDB94_phage KEGG_profiles_prokaryotes Pfam-A_v32; do
            test -s "vibrant_db/databases/\${hmm}.HMM.h3i" || {
                echo "VIBRANT database build failed: vibrant_db/databases/\${hmm}.HMM.h3i is missing or empty." >&2
                echo "See vibrant_db/databases/VIBRANT_setup.log for the underlying error." >&2
                exit 1
            }
        done

        mv vibrant_db ${params.db}/vibrant
    else
        echo "VIBRANT database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/vibrant
    echo "DB_VIBRANT stub"
    """
}


process DB_VREFSEQ {
    label "viroprofiler_base"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    # Download NCBI taxonomy
    if [ ! -d ${params.db}/taxonomy/taxdump ]; then
        mkdir dl_taxdump
        cd dl_taxdump
        wget -O taxdump.zip https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump_archive/taxdmp_2022-08-01.zip
        unzip taxdump.zip
        # wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
        #tar -zxvf taxdump.tar.gz
        mkdir -p ${params.db}/taxonomy/taxdump
        mv names.dmp nodes.dmp delnodes.dmp merged.dmp ${params.db}/taxonomy/taxdump
        cd ..
        rm -rf dl_taxonkit
    else
        echo "NCBI taxonomy already exists"
    fi

    if [ ! -d ${params.db}/taxonomy/mmseqs_vrefseq ]; then
        # Build in the task work directory, not in place. mmseqs writes its index with
        # access patterns that fail on NFS ("Can not open result file ..."), and building
        # elsewhere also means an interrupted run cannot leave a half-built database behind
        # for the directory-existence guard above to mistake for a complete one.
        wget -O mmseqs_vrefseq.tar.gz "https://zenodo.org/record/7044674/files/mmseqs_vrefseq.tar.gz"
        tar -zxf mmseqs_vrefseq.tar.gz
        rm mmseqs_vrefseq.tar.gz
        # The published archive stores its members with mode 040, so the owner cannot read
        # them and `mmseqs createdb` fails with "Permission denied". Use `find -exec`:
        # `chmod -R` is silently a no-op on filesystems that apply a default ACL.
        find mmseqs_vrefseq -type d -exec chmod u+rwx {} +
        find mmseqs_vrefseq -type f -exec chmod u+rw {} +
        test -r mmseqs_vrefseq/refseq_viral.faa \\
            || { echo "refseq_viral.faa is still unreadable after unpacking" >&2; exit 1; }

        cd mmseqs_vrefseq
        mmseqs createdb refseq_viral.faa refseq_viral
        mmseqs createtaxdb refseq_viral tmp --ncbi-tax-dump ${params.db}/taxonomy/taxdump --tax-mapping-file virus.accession2taxid --threads $task.cpus
        mmseqs createindex refseq_viral tmp --threads $task.cpus
        rm -rf tmp
        cd ..

        mv mmseqs_vrefseq ${params.db}/taxonomy/
    else
        echo "vRefSeq database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/taxonomy/taxdump
    mkdir -p ${params.db}/taxonomy/mmseqs_vrefseq
    echo "DB_VREFSEQ stub"
    """
}


process DB_IPHOP {
    label "viroprofiler_host"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/iphop ]; then
        mkdir -p ${params.db}/iphop
        iphop download -d $params.db/iphop -n

        # Drop the archive whatever release it belongs to; the name changes every release.
        rm -f ${params.db}/iphop/*.tar.gz
    else
        echo "iPHOP database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/iphop
    echo "DB_IPHOP stub"
    """
}


process DB_EGGNOG {
    label "viroprofiler_geneannot"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/eggnog ]; then
        mkdir -p ${params.db}/eggnog
        download_eggnog_data.py --data_dir ${params.db}/eggnog -y
    else
        echo "EggNOG database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/eggnog
    echo "DB_EGGNOG stub"
    """
}


process DB_VOGDB {
    label "viroprofiler_base"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/vogdb ]; then
        mkdir -p ${params.db}/vogdb
        cd ${params.db}/vogdb
        wget -O vog.hmm.tar.gz "http://fileshare.csb.univie.ac.at/vog/latest/vog.hmm.tar.gz"
        tar -zxvf vog.hmm.tar.gz
        rm vog.hmm.tar.gz
        cat VOG*.hmm > AllVOG.hmm
        rm -rf VOG*
    else
        echo "VOGDB database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/vogdb
    echo "DB_VOGDB stub"
    """
}

process DB_MICOMPLETEDB {
    label "viroprofiler_base"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    if [ ! -d ${params.db}/micomplete ]; then
        mkdir -p ${params.db}/micomplete
        wget -O ${params.db}/micomplete/Bact105.hmm "https://bitbucket.org/evolegiolab/micomplete/raw/165fea13201922f23fecb0e3c17e8e2cb07dae2d/micomplete/share/Bact105.hmm"
    else
        echo "Micomplete database already exists"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/micomplete
    echo "DB_MICOMPLETEDB stub"
    """
}


process DB_KRAKEN2 {
    label 'viroprofiler_bracken'
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    # Download Kraken2 taxonomy database
    if [ ! -d ${params.db}/kraken2/taxonomy ]; then
        mkdir -p ${params.db}/kraken2
        cd ${params.db}/kraken2
        kraken2-build --download-taxonomy --db taxonomy --threads $task.cpus
    else
        echo "Kraken2 taxonomy already exists"
    fi

    # Download user-defined Kraken2 database
    if [ ! -d ${params.db}/kraken2/${params.kraken2_db} ]; then
        kraken2-build --download-library ${params.kraken2_db} --db ${params.kraken2_db} --threads $task.cpus
        ln -s ../taxonomy/taxonomy ${params.kraken2_db}
        kraken2-build --build --db ${params.kraken2_db}
        rm ${params.kraken2_db}/taxonomy
        kraken2-build --clean --db ${params.kraken2_db}
    else
        echo "Kraken2 ${params.kraken2_db} database already exists"
    fi

    # If set params.kraken2_clean, remove the taxonomy folder to save ~39 GB storage space
    if [ "${params.kraken2_clean}" == "true" ]; then
        rm -rf ${params.db}/kraken2/taxonomy
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/kraken2
    echo "DB_KRAKEN2 stub"
    """
}

