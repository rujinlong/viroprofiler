process RESULTS_TSE {
    label "viroprofiler_vpfkit"

    input:
    // Always present.
    path abundance_count
    path abundance_tpm
    path abundance_tmm
    path abundance_covfrac
    path taxa
    path checkv_quality
    path virsorter2_score
    path replicyc_type
    // Switched off by a --use_* flag, or simply absent. Each arrives as its own
    // `assets/optional/no_*` placeholder when the tool did not run; see the README there
    // for why the placeholders are not one shared file.
    path vibrant_quality
    path genomad_score
    path checkamg_dir
    path iphop_genus
    path dramv_annotations
    path vircontigs_list
    path coverm_log
    path sample_metadata

    output:
    path "*.rds"

    when:
    task.ext.when == null || task.ext.when

    script:
    // An absent optional input drops its argument rather than passing the placeholder:
    // create_vpftse() then leaves the corresponding columns out of rowData instead of
    // joining an empty table, which is what makes "the tool did not run" distinguishable
    // downstream from "the tool ran and found nothing".
    def vibrant_arg   = vibrant_quality.name.startsWith('no_')    ? '' : "--fin_vibrant ${vibrant_quality}"
    def genomad_arg   = genomad_score.name.startsWith('no_')      ? '' : "--fin_genomad ${genomad_score}"
    def checkamg_arg  = checkamg_dir.name.startsWith('no_')       ? '' : "--fin_checkamg ${checkamg_dir}"
    def iphop_arg     = iphop_genus.name.startsWith('no_')        ? '' : "--fin_iphop ${iphop_genus}"
    def dramv_arg     = dramv_annotations.name.startsWith('no_')  ? '' : "--fin_dramv ${dramv_annotations}"
    def vircontigs_arg= vircontigs_list.name.startsWith('no_')    ? '' : "--fin_vircontigs ${vircontigs_list}"
    def covermlog_arg = coverm_log.name.startsWith('no_')         ? '' : "--fin_coverm_log ${coverm_log}"
    def metadata_arg  = sample_metadata.name.startsWith('no_')    ? '' : "--fin_metadata ${sample_metadata}"
    """
    create_tse.r --fin_abcount $abundance_count \\
                 --fin_abtpm $abundance_tpm \\
                 --fin_abtmm $abundance_tmm \\
                 --fin_abcov $abundance_covfrac \\
                 --fin_taxa $taxa \\
                 --fin_checkv $checkv_quality \\
                 --fin_virsorter2 $virsorter2_score \\
                 --fin_replicyc $replicyc_type \\
                 $vibrant_arg \\
                 $genomad_arg \\
                 $checkamg_arg \\
                 $iphop_arg \\
                 $dramv_arg \\
                 $vircontigs_arg \\
                 $covermlog_arg \\
                 $metadata_arg
    """

    stub:
    """
    touch viroprofiler_results.rds
    """
}

