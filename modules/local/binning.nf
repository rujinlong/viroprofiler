/*
 * VAMB has no linux-aarch64 build: releases up to 4.1.3 are compiled packages
 * published for linux-64 only, and 5.x is noarch but depends on pycoverm, which
 * is a Rust extension with no aarch64 artifact either. `--binning phamb` is
 * therefore refused on aarch64 before any process is submitted; see
 * docs/dev/ARM64.md.
 */
process VAMB {
    label "viroprofiler_binning"

    input:
    path(contigs)
    path(bams)

    output:
    path("out_vamb/clusters.tsv"), emit: vamb_clusters_ch
    path("out_vamb/bins"), emit: vamb_bins_ch
    path("depth_clean.txt")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # VAMB's --jgi reader is positional: `load_jgi` discards contigName entirely
    # and returns the numeric columns as an N_contigs x N_samples matrix, which is
    # then paired with --fasta row by row. So the depth table must contain exactly
    # the sequences of \$contigs, in exactly their order, or every contig from the
    # first mismatch on is given another contig's abundance -- silently.
    #
    # Two things make that a real risk here. The BAMs are mapped against the whole
    # dereplicated library while \$contigs is the viral subset, so the table starts
    # out longer than the FASTA; and while the subset happens to inherit the
    # library's order today, that is a property of how `seqkit grep` and bowtie2
    # order their output, not something either promises. Build the table in FASTA
    # order explicitly and check the result, rather than depending on it.
    seqkit fx2tab -n -i -l $contigs > binned_contigs.tsv
    cut -f1 binned_contigs.tsv > binned_contigs.list
    jgi_summarize_bam_contig_depths --outputDepth depth.txt $bams

    # Emit the header, then one row per FASTA sequence in FASTA order, looked up
    # by name. A name absent from the depth table is fatal: it would mean the BAMs
    # were built against a different library than \$contigs came from.
    awk -F'\\t' -v OFS='\\t' '
        NR == FNR { if (FNR > 1) { depth[\$1] = \$0 } ; if (FNR == 1) { hdr = \$0 } ; next }
        FNR == 1 { print hdr }
        {
            if (!(\$1 in depth)) { print "contig not in depth table: " \$1 > "/dev/stderr"; missing++ ; next }
            if (\$2 + 0 >= $params.binning_minlen_contig) { print depth[\$1] }
        }
        END { if (missing) { exit 1 } }
    ' depth.txt binned_contigs.tsv > depth_clean.txt || {
        echo "The depth table does not cover every contig being binned; the BAMs and" >&2
        echo "the contig subset disagree. Refusing to hand VAMB a misaligned matrix." >&2
        exit 1
    }

    # Row count must match what --fasta will yield after VAMB's own -m filter.
    n_fasta=\$(awk -F'\\t' '\$2 + 0 >= $params.binning_minlen_contig' binned_contigs.tsv | wc -l)
    n_depth=\$(( \$(wc -l < depth_clean.txt) - 1 ))
    if [ "\$n_fasta" -ne "\$n_depth" ]; then
        echo "depth rows (\$n_depth) != contigs passing -m (\$n_fasta)" >&2
        exit 1
    fi

    # VAMB trains a variational autoencoder, and refuses to start on a library
    # smaller than one batch. Its default batch size is 256, and the check lives
    # inside `make_dataloader`, so it raises
    #
    #     ValueError: Fewer sequences left after filtering than the batch size.
    #
    # only after the BAMs have been read and the depth table built -- and the
    # message names neither VAMB's batch size nor the contig count, so it reads
    # as a filtering bug. Say it here instead, with both numbers and a way out.
    if [ "\$n_fasta" -lt 256 ]; then
        echo "VAMB cannot bin this library: \$n_fasta contigs pass -m ${params.binning_minlen_contig}," >&2
        echo "and it needs at least 256 -- one batch for the autoencoder it trains." >&2
        echo "" >&2
        echo "Options, in the order worth trying:" >&2
        echo "  * --binning vrhyme, which has no such minimum and needs no VAMB" >&2
        echo "  * a lower --binning_minlen_contig, if contigs are being excluded by length" >&2
        echo "  * more samples: viral libraries this small are usually not worth binning" >&2
        exit 1
    fi

    vamb --outdir out_vamb --fasta $contigs -m $params.binning_minlen_contig \\
        --jgi depth_clean.txt -o __ --minfasta $params.binning_minlen_contig
    """

    stub:
    """
    mkdir -p out_vamb/bins
    # As `vambtools.write_clusters` writes it: cluster name first, contig second,
    # no header row -- phamb's `read_clusters` splits every non-comment line on a
    # single tab and would read a header as a cluster.
    printf 'cluster_1\tstub_NODE_1_length_5000_cov_100\n' > out_vamb/clusters.tsv
    touch out_vamb/bins/stub_bin.fna
    printf 'contigName\tcontigLen\ttotalAvgDepth\n' > depth_clean.txt
    """
}


/*
 * The per-contig virus score PHAMB's random forest expects in DeepVirFinder's
 * format, derived from geNomad. See bin/genomad_to_dvf.py for why the two
 * scores are interchangeable in layout but not in calibration.
 */
process PHAMB_DVF_TABLE {
    label "viroprofiler_base"

    input:
    path(contigs)
    path(genomad_summary)

    output:
    path("all.DVF.predictions.txt"), emit: dvf_table_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    genomad_to_dvf.py \\
        --summary $genomad_summary \\
        --contigs $contigs \\
        --out all.DVF.predictions.txt
    """

    stub:
    """
    printf 'name\tlen\tscore\tpvalue\n' > all.DVF.predictions.txt
    printf 'stub_NODE_1_length_5000_cov_100\t5000\t0.9900\t0.0000\n' >> all.DVF.predictions.txt
    """
}


process PHAMB_RF{
    label "viroprofiler_binning"

    input:
    path(contigs)
    path(dvf_table)
    path(hmm_miComplete)
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
    # `run_RF.py` takes four positional arguments and finds its three annotation
    # files by fixed name inside the third. It also loads the random forest from
    # beside its own source (phamb/dbs/RF_model.python39.sav), so the model is
    # not a parameter and nothing has to be downloaded for it.
    mkdir -p annotations
    cp $hmm_miComplete annotations/all.hmmMiComplete105.tbl
    cp $hmm_VOGDB      annotations/all.hmmVOG.tbl
    cp $dvf_table      annotations/all.DVF.predictions.txt

    # -m is the minimum bin size in bases; -s would be a binsplit separator,
    # which this pipeline does not use.
    run_RF.py $contigs $cluster annotations out_phamb -m $params.binning_minlen_bin

    mv out_phamb/vamb_bins/vamb_bins.1.fna .
    mv out_phamb/vambbins_RF_predictions.txt .
    mv out_phamb/vambbins_aggregated_annotation.txt .
    """

    stub:
    """
    # Columns as `write_phamb_tables` writes them.
    printf 'binname\tlabel\tprobability\n' > vambbins_RF_predictions.txt
    printf 'binname\tsize\tmicomplete\tVOG\tdvf_score\n' > vambbins_aggregated_annotation.txt
    printf '>stub_bin_seq\nACGT\n' > vamb_bins.1.fna
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
