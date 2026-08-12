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
    # `iphop download` unpacks into a release-specific directory (Sept_2021_pub_rw,
    # Aug_2023_pub_rw, ...), so resolve it instead of hardcoding one release.
    iphop_db=\$(find ${params.db}/iphop -mindepth 1 -maxdepth 1 -type d -name '*_pub_rw' | sort | tail -n1)
    if [ -z "\$iphop_db" ]; then
        echo "No iPHoP database found under ${params.db}/iphop." >&2
        echo "Run the pipeline with --mode setup, or pass --use_iphop false." >&2
        exit 1
    fi

    iphop predict --fa_file $contigs --out_dir out_iphop --db_dir \$iphop_db --num_threads $task.cpus

    # iPHoP has no --version flag (neither the argparse CLI up to 1.4.1 nor the
    # Typer one in 2.x), so `iphop --version` exits 2 and prints nothing to
    # stdout; read the installed package version instead.
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        iPHoP: \$(python -c 'import iphop; print(iphop.__version__)')
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
