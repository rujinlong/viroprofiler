process TAXONOMY_VCONTACT3 {
    label "viroprofiler_vcontact3"

    input:
    path contigs

    output:
    path "out_vcontact3/exports/final_assignments.csv", emit: taxa_vc_ch
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # matplotlib and ete3 both write into \$HOME on import, and Nextflow runs
    # Apptainer with --no-home, so \$HOME is a read-only stub.
    export HOME=\$PWD

    seqkit seq -m $params.contig_minlen_vcontact3 $contigs > input.fasta

    # vConTACT3 calls its own genes with the bundled pyrodigal-gv, so unlike
    # vConTACT2 this needs no external gene caller and no gene-to-genome map.
    # Only database version ${params.vcontact3_db_version} is compatible with this release; leaving the
    # version out would make vConTACT3 pick whatever is newest under --db-path.
    vcontact3 run \\
        --nucleotide input.fasta \\
        --pyrodigal-gv \\
        --output out_vcontact3 \\
        --db-path ${params.db}/vcontact3 \\
        --db-version ${params.vcontact3_db_version} \\
        --threads $task.cpus \\
        --no-progress \\
        --force-overwrite

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vConTACT3: \$(vcontact3 version)
    END_VERSIONS
    """

    stub:
    """
    mkdir -p out_vcontact3/exports
    printf 'Genome,GenomeName,Proteins,Reference,Size_Kb,realm_reference,realm_prediction,kingdom_reference,kingdom_prediction,phylum_reference,phylum_prediction,class_reference,class_prediction,order_reference,order_prediction,family_reference,family_prediction,subfamily_reference,subfamily_prediction,genus_reference,genus_prediction\\n' > out_vcontact3/exports/final_assignments.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vConTACT3: 3.2.4
    END_VERSIONS
    """
}

process TAXONOMY_MMSEQS {
    label "viroprofiler_base"

    input:
    path contigs

    output:
    path "mmseqsTaxaRst.tsv", emit: taxa_mmseqs_ch
    path "mmseqsTaxaRst_report.*"
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Run mmseqs taxonomy
    mmseqs createdb $contigs qry
    mmseqs taxonomy qry ${params.db}/taxonomy/mmseqs_vrefseq/refseq_viral mmseqsTaxaRst tmp --tax-lineage 1 --majority 0.4 --vote-mode 1 --lca-mode 3 --orf-filter 0 --threads $task.cpus

    # report
    mmseqs createtsv qry mmseqsTaxaRst mmseqsTaxaRst.tsv
    mmseqs taxonomyreport ${params.db}/taxonomy/mmseqs_vrefseq/refseq_viral mmseqsTaxaRst mmseqsTaxaRst_report.txt --report-mode 0
    mmseqs taxonomyreport ${params.db}/taxonomy/mmseqs_vrefseq/refseq_viral mmseqsTaxaRst mmseqsTaxaRst_report.html --report-mode 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MMseqs2: \$(grep "MMseqs Version" .command.log | head -n1 | sed 's/.*\t//g')
    END_VERSIONS
    """

    stub:
    """
    printf 'contig_id\ttaxid\trank\tname\n' > mmseqsTaxaRst.tsv
    touch mmseqsTaxaRst_report.txt
    touch mmseqsTaxaRst_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MMseqs2: 14.7564d
    END_VERSIONS
    """
}

process TAXONOMY_MERGE {
    // Pure python over the callers' output tables; needs pandas and click, both
    // of which the base image already carries.
    label "viroprofiler_base"

    input:
    path taxa_vc
    path taxa_mmseqs

    output:
    path "taxonomy.tsv", emit: taxa2abundance_ch
    path "taxa_mmseqs_formatted_all.tsv", emit: taxa_mmseqs_ch
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    parse_mmseqsTaxa.py -i $taxa_mmseqs -o taxa_mmseqs -u "" -s $params.taxa_db_source

    # Which callers are merged is data: each --source is a (name, priority,
    # file) triple, smaller priority wins per rank. vConTACT3 goes first because
    # it predicts taxonomy from gene sharing against a reference set, while the
    # MMseqs2 LCA is a per-contig vote that reaches further down the ranks but
    # is noisier. Add VITAP and geNomad as further --source lines.
    merge_taxonomy.py \\
        --source vcontact3 1 $taxa_vc \\
        --source mmseqs 2 taxa_mmseqs.tsv \\
        -o taxonomy.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    printf 'contig_id\tRealm\tRealm_source\tKingdom\tKingdom_source\tPhylum\tPhylum_source\tClass\tClass_source\tOrder\tOrder_source\tFamily\tFamily_source\tSubfamily\tSubfamily_source\tGenus\tGenus_source\tSpecies\tSpecies_source\n' > taxonomy.tsv
    # Columns as parse_mmseqsTaxa.py writes them for the default --taxa_db_source
    # NCBI; with ICTV the leading rank is Realm rather than Domain.
    printf 'contig_id\ttaxa_id\tlca_rank\tlca_name\tnprot_all\tnprot_labeled\tnprot_support\tpctprot_support\tDomain\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n' > taxa_mmseqs_formatted_all.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.11.0
    END_VERSIONS
    """
}
