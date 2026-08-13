process CONTIGLIB {
    label "viroprofiler_base"

    input:
    path contigs

    output:
    path 'contigs_cclib.fasta.gz'     , emit: cclib_ch
    path 'contigs_cclib_long.fasta.gz', emit: cclib_long_ch
    path 'contigs_cclib_long.dict'    , emit: cclib_long_dict_ch
    path "versions.yml"               , emit: versions

    script: // This script is bundled with the pipeline, in nf-core/viroprofiler/bin/
    """
    # Add sample id to contig name
    for sample_contigs in $contigs;do
        sample_id=\$(echo \${sample_contigs} | sed 's/.contigs.fa.gz//;s/.scaffolds.fa.gz//')
        seqkit replace -p '^' -r "\${sample_id}__" \${sample_contigs} > renamed_contigs_\${sample_id}.fa
    done

    # Merge all contigs into one file
    cat renamed_contigs_* > contigs_cclib.fasta
    seqkit replace -s -p "N+" -r "NNNNNNNNNNN" contigs_cclib.fasta
    gzip contigs_cclib.fasta

    # Select contigs longer than `contig_minlen` for downstream analysis
    seqkit seq -g -j $task.cpus -m $params.contig_minlen contigs_cclib.fasta.gz | pigz -p $task.cpus > contigs_cclib_long.fasta.gz

    # Generate a dict file for VAMB or Phamb binning
    samtools dict contigs_cclib_long.fasta.gz | cut -f1-3 > contigs_cclib_long.dict

    # remove temp files
    rm -rf renamed_contigs_*

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh | grep -v "Duplicate")
        seqkit: \$( seqkit | sed '3!d; s/Version: //' )
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    """
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGTACGTACGTACGTACGT\n' | gzip > contigs_cclib.fasta.gz
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGTACGTACGTACGTACGT\n' | gzip > contigs_cclib_long.fasta.gz
    printf '@SQ\tSN:stub_NODE_1_length_5000_cov_100\tLN:5000\n' > contigs_cclib_long.dict

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: 38.92
    END_VERSIONS
    """
}


/*
 * Dereplicate the pooled contig library with Vclust.
 *
 * The MIUViG species rule is a containment rule, and it is deliberately
 * asymmetric: two contigs belong to the same cluster when they align at
 * >= `contig_cluster_min_similarity` percent identity over >= `contig_cluster_
 * min_coverage` percent OF THE SHORTER CONTIG, with no constraint at all on how
 * much of the longer one is covered. A short contig contained in a long one is
 * absorbed by it.
 *
 * The three Vclust measures are not interchangeable, so the mapping matters
 * (definitions from the Vclust documentation):
 *
 *   ani   identical nucleotides / total length of the local alignments. This is
 *         identity over the aligned region only, which is what the MIUViG
 *         threshold means and what the superseded `anicalc.py` reported as
 *         `pid`. -> `contig_cluster_min_similarity`
 *   gani  identical nucleotides / length of the query genome. That folds
 *         coverage into the identity, so a contained short contig scores as
 *         poorly as a diverged one. Wrong measure here.
 *   tani  identical nucleotides / summed length of both genomes. Symmetric, so
 *         it can never express containment. Wrong measure here.
 *
 *   qcov  aligned fraction of the query. `vclust align` writes both
 *         orientations of every pair, so a pair passes `--qcov` as soon as the
 *         sequence that is more completely aligned -- in practice the shorter
 *         one -- clears the threshold. That is exactly the old `--min_tcov`
 *         with `--min_qcov 0`. -> `contig_cluster_min_coverage`
 *   rcov  aligned fraction of the reference. Passing `--qcov` and `--rcov`
 *         together would demand that BOTH sequences be covered, which is
 *         reciprocal-overlap clustering, not containment. Only `--qcov` is set.
 *
 * `--algorithm cd-hit` is the greedy incremental, longest-first, centroid
 * scheme that `aniclust.py` implemented, so representatives stay the longest
 * member of each cluster. Vclust's default `leiden` is a community-detection
 * method and moves more contigs between clusters.
 *
 * One representative can differ from what the old chain picked: when two
 * contigs in a cluster are exactly the same length, `aniclust.py` kept whichever
 * came first in the FASTA, so the choice followed the order the samples happened
 * to be pooled in. Vclust breaks the tie the same way every time regardless of
 * input order. Either contig is an equally valid representative -- they are the
 * same length and above both thresholds -- and the new behaviour is the
 * reproducible one.
 *
 * The prefilter threshold is derived from the identity the user asked for
 * rather than fixed at Vclust's suggested 0.95, so that lowering
 * `contig_cluster_min_similarity` cannot silently discard the very pairs the
 * lower threshold was meant to admit. It is set 5 points below that identity
 * because the Kmer-db estimate is approximate.
 */
process CONTIGLIB_CLUSTER {
    label "viroprofiler_vclust"

    input:
    path contigs

    output:
    path "contigs_nrclib.fasta", emit: nrclib_ch
    path "contigs_nrclib.dict", emit: nrclib_dict
    path "contigs_ANIclst.tsv", emit: cANIclst_ch
    path "contigs_ani.tsv"
    path "versions.yml", emit: versions

    script: // This script is bundled with the pipeline, in nf-core/viroprofiler/bin/
    def min_ani     = params.contig_cluster_min_similarity / 100
    def min_cov     = params.contig_cluster_min_coverage / 100
    def prefilter   = Math.max(0.0, (params.contig_cluster_min_similarity - 5) / 100)
    """
    # The library pools the contigs of every sample, so a contig that more than
    # one sample assembled arrives several times over. Collapsing those exact
    # duplicates (and their reverse complements) before the O(n^2) stage is
    # free; the ids that get dropped are read back in below.
    vclust deduplicate -i $contigs -o contigs_dedup.fasta -t $task.cpus

    # Kmer-db prefilter, then LZ-ANI on the pairs that survive it. Kmer-db
    # cannot build a filter a single sequence would satisfy, and lz-ani rejects
    # the degenerate file it writes, so a one-contig library skips the
    # prefilter -- there is nothing to narrow down in that case anyway.
    n_seqs=\$(grep -c '^>' contigs_dedup.fasta || true)
    if [ "\$n_seqs" -ge 2 ]; then
        vclust prefilter -i contigs_dedup.fasta -o contigs_prefilter.txt \\
            --min-ident $prefilter -t $task.cpus
        vclust align -i contigs_dedup.fasta -o contigs_ani.tsv \\
            --filter contigs_prefilter.txt -t $task.cpus
    else
        vclust align -i contigs_dedup.fasta -o contigs_ani.tsv -t $task.cpus
    fi

    vclust cluster -i contigs_ani.tsv -o contigs_vclust.tsv \\
        --ids contigs_ani.ids.tsv --out-repr \\
        --algorithm cd-hit --metric ani --ani $min_ani --qcov $min_cov

    parse_vclust_clusters.py \\
        --clusters contigs_vclust.tsv \\
        --duplicates contigs_dedup.fasta.duplicates.txt \\
        --out-tsv contigs_ANIclst.tsv \\
        --out-list contigs_nrclib_ani.list

    seqkit grep -f contigs_nrclib_ani.list $contigs > contigs_nrclib.fasta
    samtools dict contigs_nrclib.fasta | cut -f1-3 > contigs_nrclib.dict

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vclust: \$(vclust --version 2>&1 | sed 's/^v//')
        seqkit: \$( seqkit | sed '3!d; s/Version: //' )
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    """
    printf '>stub_NODE_1_length_5000_cov_100\nACGTACGTACGTACGTACGTACGT\n' > contigs_nrclib.fasta
    printf '@SQ\tSN:stub_NODE_1_length_5000_cov_100\tLN:5000\n' > contigs_nrclib.dict
    printf 'repid\tctgid\n' > contigs_ANIclst.tsv
    printf 'stub_NODE_1_length_5000_cov_100\tstub_NODE_1_length_5000_cov_100\n' >> contigs_ANIclst.tsv
    printf 'qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio\n' > contigs_ani.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vclust: 1.3.1
    END_VERSIONS
    """
}
