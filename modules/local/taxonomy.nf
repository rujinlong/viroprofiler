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

process TAXONOMY_VITAP {
    label "viroprofiler_vitap"
    // Almost the whole runtime is one `diamond blastp --sensitive` against
    // 726k reference proteins, which scales with threads. At the one CPU of the
    // default that search took 126 s for the 200 proteins of a two-sample test.
    label "process_medium"

    input:
    path contigs

    output:
    path "out_vitap/best_determined_lineages.tsv", emit: taxa_vitap_ch
    // Read by `read_vitap` in merge_taxonomy.py, which needs it to tell the
    // query contigs apart from the reference genomes VITAP mixes into them.
    path "out_vitap/ICTV_selected_genomes.fasta", emit: taxa_vitap_ref_ch
    path "out_vitap/all_lineages.tsv"
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Nextflow runs Apptainer with --no-home, so \$HOME is a read-only stub.
    export HOME=\$PWD

    # No length filter of its own, unlike TAXONOMY_VCONTACT3: VITAP is built to
    # classify fragments down to 1 kb, and the contig library it is given has
    # already been filtered at --contig_minlen.
    VITAP assignment \\
        -i $contigs \\
        -d ${params.db}/vitap \\
        -o out_vitap \\
        -p $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        VITAP: \$(pip show VITAP | awk '/^Version:/ { print \$2 }')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p out_vitap
    printf 'Genome_ID\\tlineage\\tlineage_score\\tConfidence_level\\n' > out_vitap/best_determined_lineages.tsv
    printf 'Genome_ID\\tlineage\\tlineage_score\\n' > out_vitap/all_lineages.tsv
    : > out_vitap/ICTV_selected_genomes.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        VITAP: 1.7
    END_VERSIONS
    """
}

process TAXONOMY_MERGE {
    // Pure python over the callers' output tables; needs pandas and click, both
    // of which the base image already carries.
    label "viroprofiler_base"

    input:
    path taxa_vitap
    // Never named on the command line. `read_vitap` reads it from beside
    // $taxa_vitap to drop the reference genomes VITAP classifies alongside the
    // query contigs, so it has to be staged into this task's directory.
    path taxa_vitap_ref
    path taxa_vc

    output:
    path "taxonomy.tsv", emit: taxa_merged_ch
    // The same lineages in the layout vpfkit's read_taxonomy2() requires, for
    // RESULTS_TSE. See write_tse_table() in merge_taxonomy.py for what the
    // Domain and taxa_id columns mean.
    path "taxonomy_tse.tsv", emit: taxa_tse_ch
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Which callers are merged is data: each --source is a (name, priority,
    # file) triple, smaller priority wins per rank.
    #
    # VITAP goes first: it is the only caller here that reaches species, it
    # scores each rank against ICTV reference genomes on a multipartite graph
    # rather than by a single best hit, and this ordering is the one already in
    # production use. Priority 2 is deliberately left free for geNomad, which
    # classifies more genomes than VITAP but stops at family. vConTACT3 follows,
    # predicting from gene sharing against a reference set.
    merge_taxonomy.py \\
        --source vitap 1 $taxa_vitap \\
        --source vcontact3 3 $taxa_vc \\
        -o taxonomy.tsv \\
        --fout-tse taxonomy_tse.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    printf 'contig_id\tRealm\tRealm_source\tKingdom\tKingdom_source\tPhylum\tPhylum_source\tClass\tClass_source\tOrder\tOrder_source\tFamily\tFamily_source\tSubfamily\tSubfamily_source\tGenus\tGenus_source\tSpecies\tSpecies_source\n' > taxonomy.tsv
    printf 'contig_id\ttaxa_id\tDomain\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n' > taxonomy_tse.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.11.0
    END_VERSIONS
    """
}
