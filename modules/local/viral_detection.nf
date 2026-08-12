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


process DVF {
    label "viroprofiler_dvf"

    input:
    path(contigs)

    output:
    path("*")
    path("dvf_virus.tsv"), emit: dvf2vContigs_ch
    path("virus_dvf.list"), emit: dvflist_ch
    path("*_dvfpred.txt"), emit: dvfscore_ch
    path("dvf.fasta"), emit: dvfseq_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    export OMP_NUM_THREADS=$task.cpus
    seqkit seq -M $params.dvf_maxlen $contigs > contigs_maxlen.fasta
    dvf.py -i contigs_maxlen.fasta -o . -c $task.cpus
    dvf_output=\$(ls *_dvfpred.txt)
    calc_qvalue.r \${dvf_output} $params.dvf_qvalue dvf_virus.tsv
    sed 1d dvf_virus.tsv | cut -f1 > virus_dvf.list
    seqkit grep -f virus_dvf.list $contigs > dvf.fasta
    """

    stub:
    """
    printf 'name\tlen\tscore_dvfpred\tpvalue_flag\n' > contigs_dvfpred.txt
    printf 'contig_id\tdvf_score\n' > dvf_virus.tsv
    printf 'stub_NODE_1_length_5000_cov_100\n' > virus_dvf.list
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGT\n' > dvf.fasta
    """
}

process VIBRANT {
    label "viroprofiler_vibrant"

    input:
    path(contigs)

    output:
    path("VIBRANT_*"), emit: vibrant_ch
    path("VIBRANT_contigs/VIBRANT_results_contigs/VIBRANT_genome_quality_contigs.tsv"), emit: vibrant_quality_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ln -s $contigs contigs.fasta
    VIBRANT_run.py -i contigs.fasta -d $params.db/vibrant/databases -m $params.db/vibrant/files -t $task.cpus -virome
    """

    stub:
    """
    mkdir -p VIBRANT_contigs/VIBRANT_results_contigs
    mkdir -p VIBRANT_contigs/VIBRANT_phages_contigs
    printf 'contig\tquality\n' > VIBRANT_contigs/VIBRANT_results_contigs/VIBRANT_genome_quality_contigs.tsv
    printf '>stub_phage\nACGTACGT\n' > VIBRANT_contigs/VIBRANT_phages_contigs/contigs.phages_combined.fna
    """
}


process VIRCONTIGS_PRE {
    label "viroprofiler_base"

    input:
    path(nrclib)
    path(dvflist)
    path(checkv_quality)
    path(vibrant_dir)

    output:
    path("putative_vcontigs_pref1.fasta"), emit: putative_vContigs_ch
    path("putative_vcontigs_pref1.list"), emit: putative_vList_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cat ${vibrant_dir}/VIBRANT_phages_contigs/contigs.phages_combined.fna | seqkit fx2tab -n > vibrant_vcontigs.list
    csvtk grep -t -r -f checkv_quality -p 'Complete|High-quality|Medium-quality|Low-quality' $checkv_quality | cut -f1 | sed 1d > checkv_vcontigs.list
    cat $dvflist checkv_vcontigs.list vibrant_vcontigs.list | sort -u > putative_vcontigs_pref1.list
    seqkit grep -f putative_vcontigs_pref1.list $nrclib > putative_vcontigs_pref1.fasta
    """

    stub:
    """
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGTACGT\n' > putative_vcontigs_pref1.fasta
    printf 'stub_NODE_1_length_5000_cov_100\n' > putative_vcontigs_pref1.list
    """
}
