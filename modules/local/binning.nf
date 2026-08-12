process VAMB {
    label "viroprofiler_binning"

    input:
    path(contigs)
    path(bams)

    output:
    path("*")
    path("out_vamb/clusters.tsv"), emit: vamb_clusters_ch
    path("out_vamb/bins"), emit: vamb_bins_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    jgi_summarize_bam_contig_depths --outputDepth depth.txt $bams
    cut -f1-3 depth.txt > col1to3.txt
    cut -f1-3 --complement depth.txt > cut.txt
    paste col1to3.txt cut.txt | csvtk filter -t -f "contigLen>=$params.binning_minlen_contig" > depth_clean.txt
    vamb --outdir out_vamb --fasta $contigs -m $params.binning_minlen_contig --jgi depth_clean.txt -o __ --minfasta $params.binning_minlen_contig
    """

    stub:
    """
    mkdir -p out_vamb/bins
    printf 'contigname\tbinid\n' > out_vamb/clusters.tsv
    touch out_vamb/bins/stub_bin.fna
    """
}


process PHAMB_RF{
    label "viroprofiler_binning"
    
    input:
    path(CONTIGS)
    path(output_dvf)
    path(hmm_MiComplete)
    path(hmm_VOGDB)
    path(cluster)

    output:
    path("vambbins_RF_predictions.txt"), emit: phamb_out
    path("vamb_bins.1.fna"), emit: phamb_bins
    path("vambbins_aggregated_annotation.txt"), emit: phamb_anno

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    run_RF.py -f $CONTIGS -d $output_dvf -p $hmm_MiComplete -g $hmm_VOGDB -c $cluster  -l $params.binning_minlen_contig -m /opt/phamb/workflows/mag_annotation/dbs/RF_model.python39.sav -s $params.binning_minlen_bin -o .
    mv vamb_bins/vamb_bins.1.fna .
    """

    stub:
    """
    printf 'binid\tprediction\n' > vambbins_RF_predictions.txt
    printf '>stub_bin_seq\nACGT\n' > vamb_bins.1.fna
    printf 'binid\tannotation\n' > vambbins_aggregated_annotation.txt
    """
}


process VRHYME {
    label 'viroprofiler_binning'

    input:
    path(contigs)
    path(genes)
    path(prots)
    path(bams)

    output:
    path "out_vrhyme", emit: out_vrhyme_ch
    path("vRhyme_all.fasta"), emit: vrhyme_merge_ch
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    seqkit fx2tab -n $contigs > contigs.list
    extract_gene_by_contig_id.py -i $genes -c contigs.list -o genes_sel.fna
    extract_gene_by_contig_id.py -i $prots -c contigs.list -o prots_sel.faa

    vRhyme \\
        -i $contigs \\
        -g genes_sel.fna \\
        -p prots_sel.faa \\
        -b $bams \\
        -t $task.cpus \\
        -o out_vrhyme \\
        $args

    cut -f1 out_vrhyme/vRhyme_best_bins.*.membership.tsv | sed 1d > bins_ctgid.list
    seqkit grep -v -f bins_ctgid.list $contigs > vRhyme_unbinned.fasta

    # concat bins
    mkdir -p bins
    for bin in \$(ls out_vrhyme/vRhyme_best_bins_fasta/*.fasta); do
        binid=\$(basename \$bin | sed 's/_bin//;s/.fasta//')
        concat_vrhyme_bin.py -i \$bin -o bins/\$binid
    done

    cat bins/*.fasta vRhyme_unbinned.fasta > vRhyme_all.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vRhyme: \$(echo \$(vRhyme --version 2>&1) | sed 's/^.*vRhyme //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p out_vrhyme
    touch out_vrhyme/.gitkeep
    printf '>stub_seq\nACGTACGT\n' > vRhyme_all.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vRhyme: 1.1.0
    END_VERSIONS
    """
}
