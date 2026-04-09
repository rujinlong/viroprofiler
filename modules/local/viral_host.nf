process VIRALHOST_IPHOP {
    label "viroprofiler_host"

    input:
    path contigs

    output:
    path "out_iphop/Detailed_output_by_tool.csv", emit: iphop_tool_ch
    path "out_iphop/Host_prediction_to_genome_m90.csv", emit: iphop_genome_ch
    path "out_iphop/Host_prediction_to_genus_m90.csv", emit: iphop_genus_ch
    path "out_iphop/Date_and_version.log"
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    """
    iphop predict --fa_file $contigs --out_dir out_iphop --db_dir ${params.db}/iphop/Aug_2023_pub_rw --num_threads $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        iPHoP: \$(iphop --version | head -n1 | sed 's/iPHoP v//;s/: .*//')
        seqkit: \$( seqkit | sed '3!d; s/Version: //' )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p out_iphop
    printf 'Virus,Host_prediction,Score\n' > out_iphop/Detailed_output_by_tool.csv
    printf 'Virus,Host_genome,Confidence_score\n' > out_iphop/Host_prediction_to_genome_m90.csv
    printf 'Virus,Host_genus,Confidence_score\n' > out_iphop/Host_prediction_to_genus_m90.csv
    touch out_iphop/Date_and_version.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        iPHoP: 1.3.0
    END_VERSIONS
    """
}
