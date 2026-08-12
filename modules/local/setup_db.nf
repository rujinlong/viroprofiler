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
    # VirSorter2 writes its config template under $HOME/.virsorter, and Nextflow runs
    # Apptainer with --no-home, so $HOME is a read-only stub.
    export HOME=\$PWD

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
    # DRAM writes into \$HOME while importing its dependencies, and Nextflow runs Apptainer
    # with --no-home, so \$HOME is a read-only stub.
    export HOME=\$PWD

    DRAM_DB="${params.db}/dram"

    # A directory-existence guard cannot be used here. `prepare_databases` downloads and
    # processes sixteen databases over several hours with no resume support, so an
    # interrupted or partly failed build leaves a directory that looks finished; two earlier
    # setups produced exactly that. Check instead that the CONFIG DRAM will actually read
    # names a usable file for every database, and rebuild from scratch when it does not.
    cat > check_dram_db.py <<'PYTHON'
import json
import os
import sqlite3
import sys

# Everything `prepare_databases --skip_uniref` is expected to produce. KEGG is absent
# because it is licensed and DRAM cannot download it; UniRef is skipped because it costs
# several hundred GB and does not affect distillation.
REQUIRED = (
    ('search_databases', ('kofam_hmm', 'kofam_ko_list', 'pfam', 'dbcan', 'viral',
                          'peptidase', 'vogdb')),
    ('database_descriptions', ('pfam_hmm', 'dbcan_fam_activities', 'dbcan_subfam_ec',
                               'vog_annotations')),
    ('dram_sheets', ('genome_summary_form', 'module_step_form', 'etc_module_database',
                     'function_heatmap_form', 'amg_database')),
)
# mmseqs and HMMER spread one database over several files but the CONFIG names only the
# first, so a half-written database still reads as present. Check what the search step opens:
# the k-mer index `mmseqs search` needs, and the `_h` header database that DRAM reads
# directly to turn a hit into a description.
MMSEQS = ('.dbtype', '.index', '_h', '_h.dbtype', '_h.index',
          '.idx', '.idx.dbtype', '.idx.index')
HMMER = ('.h3f', '.h3i', '.h3m', '.h3p')
SIDECARS = {
    'pfam': MMSEQS,
    'viral': MMSEQS,
    'peptidase': MMSEQS,
    'kofam_hmm': HMMER,
    'dbcan': HMMER,
    'vogdb': HMMER,
}
# Written by `populate_description_db`; DRAM joins every annotation against these.
DESCRIPTION_TABLES = ('pfam_description', 'dbcan_description', 'viral_description',
                      'peptidase_description', 'vogdb_description')

db_dir = sys.argv[1]
config_loc = os.path.join(db_dir, 'CONFIG')
problems = []


def check_file(label, loc):
    if loc is None:
        problems.append('%s is not set' % label)
        return False
    if not os.path.isfile(loc):
        problems.append('%s names a missing file: %s' % (label, loc))
        return False
    if os.path.getsize(loc) == 0:
        problems.append('%s names an empty file: %s' % (label, loc))
        return False
    try:
        with open(loc, 'rb') as handle:
            head = handle.read(512).lstrip().lower()
    except OSError as error:
        # Unpacked files are routinely left unreadable by their own owner on a filesystem
        # whose default ACL empties the owner class, so read rather than trust the mode.
        problems.append('%s cannot be read: %s' % (label, error))
        return False
    # Several of the hosts DRAM downloads from now answer a retired path with HTTP 200 and
    # a landing page, which urlretrieve stores as if it were the database.
    if head.startswith(b'<!doctype html') or head.startswith(b'<html'):
        problems.append('%s names an HTML page, not a database: %s' % (label, loc))
        return False
    return True


if not os.path.isfile(config_loc):
    print('No DRAM CONFIG at %s' % config_loc)
    sys.exit(1)
try:
    with open(config_loc) as handle:
        config = json.load(handle)
except ValueError as error:
    print('DRAM CONFIG at %s is not readable JSON: %s' % (config_loc, error))
    sys.exit(1)

for section, names in REQUIRED:
    entries = config.get(section) or {}
    for name in names:
        loc = entries.get(name)
        if check_file('%s.%s' % (section, name), loc):
            for suffix in SIDECARS.get(name, ()):
                check_file('%s.%s%s' % (section, name, suffix), loc + suffix)

if check_file('description_db', config.get('description_db')):
    connection = sqlite3.connect(config['description_db'])
    for table in DESCRIPTION_TABLES:
        try:
            rows = connection.execute('SELECT count(*) FROM ' + table).fetchone()[0]
        except sqlite3.Error as error:
            problems.append('description_db has no usable %s table: %s' % (table, error))
            continue
        if rows == 0:
            problems.append('description_db table %s is empty' % table)
    connection.close()

if problems:
    print('The DRAM database in %s is not usable:' % db_dir)
    for problem in problems:
        print('  - %s' % problem)
    sys.exit(1)
print('The DRAM database in %s is complete.' % db_dir)
PYTHON

    if python check_dram_db.py "\$DRAM_DB"; then
        echo "DRAM database already exists"
    else
        BUILD_DIR="\$PWD/dram_build"

        # `mmseqs convertmsa` expands Pfam-A.full.gz into a 143 GB intermediate, on top of
        # 25 GB of downloads and 25 GB of finished databases. Refuse to start rather than
        # fill the filesystem hours in.
        REQUIRED_KB=\$((250 * 1024 * 1024))
        AVAILABLE_KB=\$(df -Pk "\$PWD" | awk 'NR == 2 { print \$4 }')
        if [ "\$AVAILABLE_KB" -lt "\$REQUIRED_KB" ]; then
            echo "Building the DRAM database needs ~250 GB in the work directory, but only" >&2
            echo "\$((AVAILABLE_KB / 1024 / 1024)) GB is free on the filesystem holding \$PWD." >&2
            echo "Point Nextflow at a larger work directory with -w." >&2
            exit 1
        fi

        # The finished database is published to --db, which is usually a different
        # filesystem, and it is 38 GB.
        mkdir -p "${params.db}"
        PUBLISH_KB=\$(df -Pk "${params.db}" | awk 'NR == 2 { print \$4 }')
        if [ "\$PUBLISH_KB" -lt \$((50 * 1024 * 1024)) ]; then
            echo "The finished DRAM database needs ~40 GB under ${params.db}, but only" >&2
            echo "\$((PUBLISH_KB / 1024 / 1024)) GB is free there." >&2
            exit 1
        fi

        # GNU tar restores each member's stored mode, and on a filesystem whose default ACL
        # leaves the owner class empty the result is a file that its own owner cannot read.
        # DRAM unpacks the KOfam profiles with tar and then opens all 26000 of them, so
        # establish here that the work directory does not do this.
        mkdir -p tar_probe/in tar_probe/out
        : > tar_probe/in/probe
        chmod 664 tar_probe/in/probe
        tar -czf tar_probe/probe.tar.gz -C tar_probe/in probe
        tar -xzf tar_probe/probe.tar.gz -C tar_probe/out
        if [ ! -r tar_probe/out/probe ]; then
            echo "Files unpacked by tar into \$PWD are not readable by their owner, so the" >&2
            echo "KOfam and VOGDB steps of the DRAM build cannot work here. This filesystem" >&2
            echo "applies a default ACL that empties the owner class; choose a work directory" >&2
            echo "elsewhere with -w." >&2
            exit 1
        fi
        rm -rf tar_probe

        # `prepare_databases` writes the CONFIG itself, filling in the absolute path of
        # every database as it is downloaded, but it can only read a CONFIG that already
        # exists. So export the empty template that ships inside mag_annotator (with
        # DRAM_CONFIG_LOCATION unset, otherwise `export_config` reads the file it is
        # supposed to create) and point DRAM at that copy for the actual build.
        rm -rf "\$BUILD_DIR"
        mkdir -p "\$BUILD_DIR"
        unset DRAM_CONFIG_LOCATION
        DRAM-setup.py export_config --output_file "\$BUILD_DIR/CONFIG"
        export DRAM_CONFIG_LOCATION="\$BUILD_DIR/CONFIG"
        DRAM-setup.py prepare_databases --output_dir "\$BUILD_DIR" --threads $task.cpus --skip_uniref --verbose

        # Inputs to steps that have finished. DRAM never deletes them and the CONFIG never
        # names them, but `pfam.mmsmsa` alone is an order of magnitude larger than every
        # database the build publishes put together.
        rm -rf "\$BUILD_DIR"/pfam.mmsmsa* "\$BUILD_DIR/tmp" "\$BUILD_DIR/kofam_profiles" "\$BUILD_DIR/vogdb_hmms"

        # Publish, then repoint the CONFIG: `set_database_paths()` recorded every database
        # under its build path.
        rm -rf "\$DRAM_DB"
        mkdir -p "\$DRAM_DB"
        mv "\$BUILD_DIR"/* "\$DRAM_DB/"
        rm -rf "\$BUILD_DIR"
        sed -i "s|\$BUILD_DIR|\$DRAM_DB|g" "\$DRAM_DB/CONFIG"
        export DRAM_CONFIG_LOCATION="\$DRAM_DB/CONFIG"
        find "\$DRAM_DB" -type d -exec chmod u+rwx {} +
        find "\$DRAM_DB" -type f -exec chmod u+rw {} +

        python check_dram_db.py "\$DRAM_DB" || {
            echo "DRAM finished but its database is unusable; see \$DRAM_DB/database_processing.log." >&2
            exit 1
        }
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

