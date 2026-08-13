process CHECKV {
    label "viroprofiler_base"

    input:
    path contigs

    output:
    // TODO nf-core: Named file extensions MUST be emitted for ALL output channels
    path "quality_summary.tsv", emit: checkv2vContigs_ch
    path "checkv_qc_long.fasta", emit: checkv_qc_ch
    path "quality_summary_proviruses.tsv"
    path "*.list"
    // TODO nf-core: List additional required output channels/values here
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    run_checkv.sh $contigs $params.contig_minlen \$(pwd) $task.cpus $params.assembler ${params.db}/checkv
    mv viruses.fna checkv_qc.fasta
    while [ -s proviruses_nextInput.fna ] ; do
        dir_new=run_\$(date +"%Y%m%d%h%s")
        run_checkv.sh proviruses_nextInput.fna $params.contig_minlen \$dir_new 1 $params.assembler ${params.db}/checkv
        cat \$dir_new/viruses.fna >> checkv_qc.fasta
        csvtk concat -t quality_summary_viruses.tsv \$dir_new/quality_summary_viruses.tsv > quality_summary.tsv
        cp quality_summary.tsv quality_summary_viruses.tsv
        sed 1d \$dir_new/quality_summary_proviruses.tsv >> quality_summary_proviruses.tsv
        cat \$dir_new/proviruses_short.fna >> proviruses_short.fna
        cat \$dir_new/proviruse_ids_raw.list >> proviruse_ids_raw.list
        cat \$dir_new/proviruse_ids_clean.list >> proviruse_ids_clean.list
        cp \$dir_new/proviruses_nextInput.fna .
    done
    seqkit seq -m $params.contig_minlen checkv_qc.fasta > checkv_qc_long.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CheckV: \$(echo \$(checkv | head -n1 | sed 's/:.*//' | sed 's/CheckV v//'))
    END_VERSIONS
    """

    stub:
    """
    printf 'contig_id\tcheckv_quality\tcompleteness\n' > quality_summary.tsv
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGTACGT\n' > checkv_qc_long.fasta
    printf 'contig_id\tcheckv_quality\n' > quality_summary_proviruses.tsv
    touch complete.list
    touch hq.list
    touch mq.list
    touch lq.list

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CheckV: 1.0.1
    END_VERSIONS
    """
}


process VIRSORTER2 {
    label "viroprofiler_virsorter2"

    input:
    path contigs

    output:
    path "final-viral-combined-for-dramv.fa", emit: vs2_contigs_ch
    path "viral-affi-contigs-for-dramv.tab", emit: vs2_affi_ch
    path "out_vs2/final-viral-combined.fa"
    path "out_vs2/final-viral-score.tsv", emit: vs2_score_ch
    path "vs2_category.csv"
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # VirSorter2 initializes its config template under $HOME/.virsorter. Nextflow runs
    # Apptainer with --no-home, so $HOME is a read-only stub; point it at the task
    # directory instead.
    export HOME=\$PWD

    virsorter run --seqname-suffix-off --viral-gene-enrich-off --prep-for-dramv -i $contigs -w out_vs2 --include-groups $params.virsorter2_groups --min-length $params.contig_minlen --min-score 0.5 -j $task.cpus --provirus-off -d ${params.db}/virsorter2 all
    grep '^>' out_vs2/final-viral-combined.fa | sed 's/>//' | sed 's/||.*//' > virus_virsorter2.list
    ln -s out_vs2/for-dramv/final-viral-combined-for-dramv.fa .
    ln -s out_vs2/for-dramv/viral-affi-contigs-for-dramv.tab .
    seqkit fx2tab -n final-viral-combined-for-dramv.fa | sed 's/-cat_/,/g' | csvtk add-header -n Contig,vs2_category > vs2_category.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        VirSorter2: \$(grep 'VirSorter' .command.log | head -n1 | sed 's/.* //')
    END_VERSIONS
    """

    stub:
    """
    printf '>stub_contig||full\nACGTACGTACGT\n' > final-viral-combined-for-dramv.fa
    printf 'seqname\taffi\n' > viral-affi-contigs-for-dramv.tab
    printf 'Contig,vs2_category\n' > vs2_category.csv
    mkdir -p out_vs2
    cp final-viral-combined-for-dramv.fa out_vs2/final-viral-combined.fa
    printf 'seqname\tmax_score\tmax_score_group\n' > out_vs2/final-viral-score.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        VirSorter2: 2.2.4
    END_VERSIONS
    """
}


process GENOMAD {
    label "viroprofiler_genomad"

    input:
    path(contigs)

    output:
    path("virus_genomad.list"), emit: genomad_list_ch
    path("virus_genomad_summary.tsv"), emit: genomad_score_ch
    path("genomad_raw_virus_summary.tsv")
    path("genomad_plasmid_summary.tsv")
    path("genomad_provirus.tsv")
    path("genomad_virus.fna")
    path("genomad_taxonomy.tsv")
    path("versions.yml"), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // The presets and the individual thresholds are mutually exclusive in
    // `end-to-end`; geNomad rejects the combination outright.
    def preset = params.genomad_preset == "default" ? "" : "--${params.genomad_preset}"
    def splits = params.genomad_splits > 0 ? "--splits ${params.genomad_splits}" : ""
    """
    # geNomad names every output file after the stem of its input, so give it a
    # stem this process controls rather than deriving one from whatever the
    # upstream library file happens to be called.
    ln -s $contigs genomad_input.fna

    genomad end-to-end \\
        --threads $task.cpus \\
        $preset $splits $args \\
        genomad_input.fna genomad_out ${params.db}/genomad

    SUMMARY_DIR=genomad_out/genomad_input_summary
    cp \$SUMMARY_DIR/genomad_input_virus_summary.tsv genomad_raw_virus_summary.tsv
    cp \$SUMMARY_DIR/genomad_input_plasmid_summary.tsv genomad_plasmid_summary.tsv
    cp \$SUMMARY_DIR/genomad_input_virus.fna genomad_virus.fna
    cp genomad_out/genomad_input_annotate/genomad_input_taxonomy.tsv genomad_taxonomy.tsv

    # `--disable-find-proviruses` (reachable through ext.args) skips the module
    # that writes this table. An empty one keeps the declared outputs satisfied
    # and makes genomad_contig_table.py fall back to parsing the provirus
    # naming convention.
    PROVIRUS=genomad_out/genomad_input_find_proviruses/genomad_input_provirus.tsv
    if [ -f "\$PROVIRUS" ]; then
        cp "\$PROVIRUS" genomad_provirus.tsv
    else
        printf 'seq_name\\tsource_seq\\tstart\\tend\\n' > genomad_provirus.tsv
    fi

    # geNomad reports one row per virus, which is not one row per contig once
    # proviruses have been excised. Everything downstream keys on contig IDs.
    genomad_contig_table.py \\
        --summary genomad_raw_virus_summary.tsv \\
        --contigs $contigs \\
        --provirus genomad_provirus.tsv \\
        --out-prefix virus_genomad

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        geNomad: \$(genomad --version | sed 's/.*version //')
    END_VERSIONS
    """

    stub:
    """
    printf 'seq_name\\tlength\\ttopology\\tcoordinates\\tn_genes\\tgenetic_code\\tvirus_score\\tfdr\\tn_hallmarks\\tmarker_enrichment\\ttaxonomy\\n' > genomad_raw_virus_summary.tsv
    printf 'stub_NODE_1_length_5000_cov_100\\t5000\\tNo terminal repeats\\tNA\\t5\\t11\\t0.99\\tNA\\t1\\t5.0\\tViruses\\n' >> genomad_raw_virus_summary.tsv
    cp genomad_raw_virus_summary.tsv virus_genomad_summary.tsv
    printf 'stub_NODE_1_length_5000_cov_100\\n' > virus_genomad.list
    printf 'seq_name\\tlength\\ttopology\\tcoordinates\\tn_genes\\tgenetic_code\\tplasmid_score\\tfdr\\tn_hallmarks\\tmarker_enrichment\\tconjugation_genes\\tamr_genes\\n' > genomad_plasmid_summary.tsv
    printf 'seq_name\\tsource_seq\\tstart\\tend\\n' > genomad_provirus.tsv
    printf '>stub_NODE_1_length_5000_cov_100\\nACGTACGT\\n' > genomad_virus.fna
    printf 'seq_name\\tn_genes_with_taxonomy\\tagreement\\ttaxid\\tlineage\\n' > genomad_taxonomy.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        geNomad: 1.12.0
    END_VERSIONS
    """
}

process VIBRANT {
    label "viroprofiler_vibrant"

    input:
    path(contigs)

    output:
    path("VIBRANT_*"), emit: vibrant_ch
    path("virus_vibrant.list"), emit: vibrant_list_ch
    path("VIBRANT_contigs/VIBRANT_results_contigs/VIBRANT_genome_quality_contigs.tsv"), emit: vibrant_quality_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ln -s $contigs contigs.fasta
    VIBRANT_run.py -i contigs.fasta -d $params.db/vibrant/databases -m $params.db/vibrant/files -t $task.cpus -virome

    # VIBRANT's contribution to the candidate-virus union, emitted here rather
    # than read out of the results directory by VIRCONTIGS_PRE, so that VIBRANT
    # can be switched off without VIRCONTIGS_PRE having to know. `sed` rather
    # than `seqkit`, which this image does not carry; the names it produces are
    # the same ones `seqkit fx2tab -n` used to produce, verbatim FASTA headers.
    #
    # Insist the results directory itself is there. Only the FASTA inside it is allowed
    # to be missing or empty, which is how VIBRANT reports "no phages found". Without
    # that distinction a VIBRANT layout change would read as zero detections and drop
    # every VIBRANT-only contig from the union without a word -- whereas the previous
    # code, which cat'ed this path directly in VIRCONTIGS_PRE, failed loudly.
    PHAGE_DIR=VIBRANT_contigs/VIBRANT_phages_contigs
    if [ ! -d "\$PHAGE_DIR" ]; then
        echo "VIBRANT produced no \$PHAGE_DIR directory. Its output layout has changed," >&2
        echo "so the list of VIBRANT phage contigs cannot be built." >&2
        exit 1
    fi
    PHAGES=\$PHAGE_DIR/contigs.phages_combined.fna
    if [ -s "\$PHAGES" ]; then
        sed -n 's/^>//p' "\$PHAGES" > virus_vibrant.list
    else
        echo "VIBRANT reported no phage contigs." >&2
        : > virus_vibrant.list
    fi
    """

    stub:
    """
    mkdir -p VIBRANT_contigs/VIBRANT_results_contigs
    mkdir -p VIBRANT_contigs/VIBRANT_phages_contigs
    printf 'contig\tquality\n' > VIBRANT_contigs/VIBRANT_results_contigs/VIBRANT_genome_quality_contigs.tsv
    printf '>stub_phage\nACGTACGT\n' > VIBRANT_contigs/VIBRANT_phages_contigs/contigs.phages_combined.fna
    printf 'stub_phage\n' > virus_vibrant.list
    """
}


process VIRCONTIGS_PRE {
    label "viroprofiler_base"

    input:
    path(nrclib)
    path(genomad_list)
    path(checkv_quality)
    path(vibrant_list)

    output:
    path("putative_vcontigs_pref1.fasta"), emit: putative_vContigs_ch
    path("putative_vcontigs_pref1.list"), emit: putative_vList_ch
    path("putative_vcontigs_unmatched.list")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    csvtk grep -t -r -f checkv_quality -p 'Complete|High-quality|Medium-quality|Low-quality' $checkv_quality | cut -f1 | sed 1d > checkv_vcontigs.list
    cat $genomad_list checkv_vcontigs.list $vibrant_list | sed '/^\$/d' | sort -u > putative_vcontigs_pref1.list
    seqkit grep -f putative_vcontigs_pref1.list $nrclib > putative_vcontigs_pref1.fasta

    # `seqkit grep` drops names it cannot find without saying so, and the
    # detectors do not all name sequences the way the contig library does --
    # VIBRANT reports excised prophages as `<contig>_fragment_N`, for instance.
    # Those names silently vanish from the viral set, so record them.
    seqkit fx2tab -n -i putative_vcontigs_pref1.fasta | sort -u > matched_vcontigs.list
    comm -23 putative_vcontigs_pref1.list matched_vcontigs.list > putative_vcontigs_unmatched.list
    if [ -s putative_vcontigs_unmatched.list ]; then
        echo "WARNING: \$(wc -l < putative_vcontigs_unmatched.list) name(s) called viral by a detector are absent from the contig library and were dropped; see putative_vcontigs_unmatched.list" >&2
    fi
    """

    stub:
    """
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGTACGT\n' > putative_vcontigs_pref1.fasta
    printf 'stub_NODE_1_length_5000_cov_100\n' > putative_vcontigs_pref1.list
    : > putative_vcontigs_unmatched.list
    """
}
