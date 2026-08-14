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


process DB_GENOMAD {
    label "viroprofiler_genomad"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    GENOMAD_DB="${params.db}/genomad"

    # geNomad refuses to start when its marker database is incomplete, but it
    # says so only after the annotate module has already begun. Check up front,
    # and check the files the marker search actually opens rather than the
    # directory: `download-database` untars an archive it streams from Zenodo,
    # and an interrupted download leaves a directory that looks finished.
    #
    # The three marker sets are mmseqs profile databases, so `mmseqs dbtype`
    # answers "Profile" for an intact one. Match that answer rather than the
    # exit status: `mmseqs dbtype` returns 0 on a path that is not a database at
    # all, so `|| return 1` would pass anything.
    check_db () {
        [ -s "\$1/version.txt" ] || return 1
        [ -s "\$1/genomad_marker_metadata.tsv" ] || return 1
        [ -s "\$1/names.dmp" ] || return 1
        [ -s "\$1/nodes.dmp" ] || return 1
        for db in genomad_db genomad_mini_db genomad_integrase_db; do
            mmseqs dbtype "\$1/\$db" 2>/dev/null | grep -qx "Profile" || return 1
        done
        return 0
    }

    if check_db "\$GENOMAD_DB"; then
        echo "geNomad database already exists"
    else
        # Build into the task work directory and publish only once verified, so
        # a partial download cannot leave behind a directory that the guard
        # above would then have to tell apart from a finished one.
        BUILD_DIR="\$PWD/genomad_download"
        rm -rf "\$BUILD_DIR"
        mkdir -p "\$BUILD_DIR"

        # ~1.5 GB unpacked, plus the archive while it is being unpacked.
        REQUIRED_KB=\$((6 * 1024 * 1024))
        AVAILABLE_KB=\$(df -Pk "\$PWD" | awk 'NR == 2 { print \$4 }')
        if [ "\$AVAILABLE_KB" -lt "\$REQUIRED_KB" ]; then
            echo "Downloading the geNomad database needs ~6 GB in the work directory, but" >&2
            echo "only \$((AVAILABLE_KB / 1024 / 1024)) GB is free on the filesystem holding \$PWD." >&2
            echo "Point Nextflow at a larger work directory with -w." >&2
            exit 1
        fi

        genomad download-database "\$BUILD_DIR"

        check_db "\$BUILD_DIR/genomad_db" || {
            echo "The geNomad database in \$BUILD_DIR/genomad_db is incomplete." >&2
            exit 1
        }

        rm -rf "\$GENOMAD_DB"
        mkdir -p "\$(dirname "\$GENOMAD_DB")"
        mv "\$BUILD_DIR/genomad_db" "\$GENOMAD_DB"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/genomad
    echo "DB_GENOMAD stub"
    """
}


process DB_CHECKAMG {
    label "viroprofiler_checkamg"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    CHECKAMG_DB="${params.db}/checkamg"

    # `checkamg download` unpacks the release into a versioned subdirectory of
    # --db-dir, and `checkamg annotate --db-dir` accepts that parent. So the
    # check has to look one level down, for the pressed HMM binaries the
    # annotation step actually opens -- the human-readable `.hmm` files are
    # optional and `--rm-hmm` deletes them.
    check_db () {
        for db in KEGG Pfam-A dbCAN_HMMdb_v14 METABOLIC_custom FOAM CAMPER; do
            ls "\$1"/CheckAMG_annotate_db_*/\${db}*.h3i > /dev/null 2>&1 || return 1
        done
        return 0
    }

    if check_db "\$CHECKAMG_DB"; then
        echo "CheckAMG database already exists"
    else
        # Only the annotate database is fetched. The de-novo database is a
        # further ~76 GB and serves `checkamg de-novo`, which this pipeline does
        # not run.
        BUILD_DIR="\$PWD/checkamg_download"
        rm -rf "\$BUILD_DIR"
        mkdir -p "\$BUILD_DIR"

        # ~41 GB unpacked, plus the ~13 GB archive while it is being unpacked.
        REQUIRED_KB=\$((70 * 1024 * 1024))
        AVAILABLE_KB=\$(df -Pk "\$PWD" | awk 'NR == 2 { print \$4 }')
        if [ "\$AVAILABLE_KB" -lt "\$REQUIRED_KB" ]; then
            echo "Downloading the CheckAMG annotate database needs ~70 GB in the work" >&2
            echo "directory, but only \$((AVAILABLE_KB / 1024 / 1024)) GB is free on the" >&2
            echo "filesystem holding \$PWD. Point Nextflow at a larger work directory with -w." >&2
            exit 1
        fi

        PUBLISH_KB=\$(df -Pk "\$(dirname "\$CHECKAMG_DB")" | awk 'NR == 2 { print \$4 }')
        if [ "\$PUBLISH_KB" -lt \$((45 * 1024 * 1024)) ]; then
            echo "The finished CheckAMG database needs ~41 GB under ${params.db}, but only" >&2
            echo "\$((PUBLISH_KB / 1024 / 1024)) GB is free there." >&2
            exit 1
        fi

        export HOME=\$PWD
        checkamg download -d "\$BUILD_DIR" --no-download-denovo-db

        check_db "\$BUILD_DIR" || {
            echo "The CheckAMG database in \$BUILD_DIR is incomplete: the pressed HMM" >&2
            echo "binaries CheckAMG searches are missing." >&2
            exit 1
        }

        rm -rf "\$CHECKAMG_DB"
        mkdir -p "\$(dirname "\$CHECKAMG_DB")"
        mv "\$BUILD_DIR" "\$CHECKAMG_DB"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/checkamg
    echo "DB_CHECKAMG stub"
    """
}


process DB_VIRSORTER2 {
    label "viroprofiler_virsorter2"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    # VirSorter2 writes its config template under \$HOME/.virsorter, and Nextflow runs
    # Apptainer with --no-home, so \$HOME is a read-only stub.
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


process DB_VCONTACT3 {
    label "viroprofiler_vcontact3"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    VCONTACT3_DB="${params.db}/vcontact3"
    VERSION="${params.vcontact3_db_version}"

    # The one file whose presence proves the release actually landed and is
    # readable by mmseqs: the clustered RefSeq protein database vConTACT3
    # searches every run. `mmseqs dbtype` prints the database's type, so
    # "Clustering" is the answer for an intact clustering database and anything
    # else -- a truncated file, an HTML error page, a directory that only got
    # as far as being created -- fails to produce it.
    #
    # Do not substitute the exit status of `prepare_databases` for this check:
    # it prints "[ERROR] Unable to retrieve database <v> ..." on runs that go on
    # to produce a perfectly usable database.
    check_db () {
        mmseqs dbtype "\$1/v\${VERSION}/RefSeq.\${VERSION}.0.3.mmseq_0.3_clu" 2>/dev/null \\
            | grep -qx "Clustering"
    }

    if check_db "\$VCONTACT3_DB"; then
        echo "vConTACT3 database already exists"
    else
        # Build into the task work directory and publish only once verified, so
        # an interrupted download cannot leave a directory behind that the check
        # above would later have to distinguish from a finished one.
        BUILD_DIR="\$PWD/vcontact3_db"
        rm -rf "\$BUILD_DIR"
        mkdir -p "\$BUILD_DIR"

        # ~14 GB unpacked, plus the archive itself while it is being unpacked.
        REQUIRED_KB=\$((40 * 1024 * 1024))
        AVAILABLE_KB=\$(df -Pk "\$PWD" | awk 'NR == 2 { print \$4 }')
        if [ "\$AVAILABLE_KB" -lt "\$REQUIRED_KB" ]; then
            echo "Building the vConTACT3 database needs ~40 GB in the work directory, but" >&2
            echo "only \$((AVAILABLE_KB / 1024 / 1024)) GB is free on the filesystem holding \$PWD." >&2
            echo "Point Nextflow at a larger work directory with -w." >&2
            exit 1
        fi

        # Only one database version is compatible with any given vConTACT3
        # release, and `prepare_databases` refuses the others outright, so the
        # version is pinned rather than left at "latest".
        vcontact3 prepare_databases -g "\$VERSION" -s "\$BUILD_DIR" || \\
            echo "prepare_databases returned non-zero; verifying the result anyway"

        # The archive is only an intermediate; it is as large as the database.
        rm -f "\$BUILD_DIR"/v\${VERSION}.tar.*

        check_db "\$BUILD_DIR" || {
            echo "The vConTACT3 database in \$BUILD_DIR is unusable: " >&2
            echo "v\${VERSION}/RefSeq.\${VERSION}.0.3.mmseq_0.3_clu is not an mmseqs clustering database." >&2
            exit 1
        }

        rm -rf "\$VCONTACT3_DB"
        mkdir -p "\$(dirname "\$VCONTACT3_DB")"
        mv "\$BUILD_DIR" "\$VCONTACT3_DB"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/vcontact3
    echo "DB_VCONTACT3 stub"
    """
}


process DB_VITAP {
    label "viroprofiler_vitap"
    label "setup"

    when:
    params.mode == "setup"

    script:
    """
    VITAP_DB="${params.db}/vitap"

    # What `VITAP assignment` actually opens in its database directory: one
    # DIAMOND database, one VMR taxonomy map (*.csv), one VMR genome FASTA and
    # the eight per-rank threshold tables. Everything else in the published
    # archive is only read by `VITAP upd`.
    #
    # The DIAMOND database is checked by running a search, not by testing that
    # the file exists, because existing is exactly what it does while being
    # unusable: the published index was built with DIAMOND 0.9 and DIAMOND 2
    # refuses it with "Database was built with an older version of Diamond and
    # is incompatible" -- while still answering `diamond dbinfo` about it, so
    # anything short of a search reports a healthy database. The build below
    # therefore re-indexes, and this check is what proves the re-index took.
    check_db () {
        local db="\$1"
        local dmnd faa
        for rank in Species Genus Family Order Class Phylum Kingdom Realm; do
            test -s "\$db/\${rank}_genome.threshold" || return 1
        done
        test "\$(ls "\$db"/*.csv 2>/dev/null | wc -l)" -eq 1 || return 1
        test "\$(ls "\$db"/*.fasta 2>/dev/null | wc -l)" -eq 1 || return 1
        dmnd=\$(ls "\$db"/*.dmnd 2>/dev/null | head -n 1)
        faa=\$(ls "\$db"/*.faa 2>/dev/null | head -n 1)
        test -s "\$dmnd" || return 1
        test -s "\$faa" || return 1
        # Query the database with its own first few proteins, which must align
        # to themselves. An empty result means the index is unreadable or empty.
        rm -rf db_probe && mkdir -p db_probe
        seqkit head -n 3 "\$faa" > db_probe/probe.faa 2>/dev/null || return 1
        diamond blastp -q db_probe/probe.faa -d "\$dmnd" -o db_probe/probe.align \\
            -f 6 qseqid sseqid bitscore -k 1 --max-hsps 1 -e 1e-3 \\
            --threads $task.cpus --quiet > /dev/null 2>&1 || return 1
        test -s db_probe/probe.align || return 1
        return 0
    }

    if check_db "\$VITAP_DB"; then
        echo "VITAP database already exists"
    else
        # Build into the task work directory and publish only once verified, so
        # an interrupted download cannot leave behind a directory that the check
        # above would later have to tell apart from a finished one.
        BUILD_DIR="\$PWD/vitap_db"
        rm -rf "\$BUILD_DIR"
        mkdir -p "\$BUILD_DIR"

        # 622 MB archive, 2.3 GB unpacked, both present at once while unzipping.
        REQUIRED_KB=\$((10 * 1024 * 1024))
        AVAILABLE_KB=\$(df -Pk "\$PWD" | awk 'NR == 2 { print \$4 }')
        if [ "\$AVAILABLE_KB" -lt "\$REQUIRED_KB" ]; then
            echo "Building the VITAP database needs ~10 GB in the work directory, but only" >&2
            echo "\$((AVAILABLE_KB / 1024 / 1024)) GB is free on the filesystem holding \$PWD." >&2
            echo "Point Nextflow at a larger work directory with -w." >&2
            exit 1
        fi

        # The hybrid VMR-MSL37 / RefSeq209 / IMG-VR v4 database published with
        # VITAP, and the last one upstream released: from VITAP 1.10 the
        # assignment searches UniRef90 as well and the pre-built databases were
        # withdrawn, which is why docker/viroprofiler-vitap pins VITAP 1.7.1.
        # The checksum is the one in VITAP's README, so a truncated download or
        # a replaced file is caught here rather than at assignment time.
        VITAP_DB_URL="https://ndownloader.figshare.com/files/49682337"
        VITAP_DB_SHA256="13ac7e4790cfdad2a7f0d6c3ebc8a66badfab98138693bb86f7b2a71a91cb951"

        wget -O "\$BUILD_DIR/db.zip" "\$VITAP_DB_URL"
        echo "\$VITAP_DB_SHA256  \$BUILD_DIR/db.zip" | sha256sum -c - || {
            echo "The VITAP database archive does not match the checksum published in" >&2
            echo "VITAP's README; refusing to install it." >&2
            exit 1
        }

        unzip -q "\$BUILD_DIR/db.zip" -d "\$BUILD_DIR/unpacked"
        rm -f "\$BUILD_DIR/db.zip"

        # The archive holds one directory of databases plus __MACOSX, the
        # resource-fork directory the upstream author's Mac added when zipping.
        UNPACKED=\$(find "\$BUILD_DIR/unpacked" -mindepth 1 -maxdepth 1 -type d \\
                       -not -name '__MACOSX' | head -n 1)
        test -d "\$UNPACKED" || {
            echo "The VITAP database archive did not unpack to a directory." >&2
            exit 1
        }
        mv "\$UNPACKED"/* "\$BUILD_DIR/"
        rm -rf "\$BUILD_DIR/unpacked"

        # 1 GB of self-alignments that only `VITAP upd` reads, and this image has
        # no entrez-direct so it cannot run `upd` at all. The *.gff is kept even
        # though 1.7 ignores it: VITAP 1.10 onwards resolves the name of the
        # DIAMOND database from it.
        rm -f "\$BUILD_DIR"/Self_BLAST_*.align

        # Re-index. The published *.dmnd is in the DIAMOND 0.9 format that
        # DIAMOND 2 will not search; the *.faa it was built from ships beside
        # it, and re-indexing 726k proteins takes a couple of seconds.
        FAA=\$(ls "\$BUILD_DIR"/*.faa | head -n 1)
        DMND="\${FAA%.faa}"
        rm -f "\$DMND.dmnd"
        diamond makedb --in "\$FAA" -d "\$DMND" --threads $task.cpus

        check_db "\$BUILD_DIR" || {
            echo "The VITAP database in \$BUILD_DIR is unusable: a DIAMOND search against" >&2
            echo "its own proteins returned nothing, or a required file is missing." >&2
            exit 1
        }

        rm -rf "\$VITAP_DB"
        mkdir -p "\$(dirname "\$VITAP_DB")"
        mv "\$BUILD_DIR" "\$VITAP_DB"
    fi
    """

    stub:
    """
    mkdir -p ${params.db}/vitap
    echo "DB_VITAP stub"
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

