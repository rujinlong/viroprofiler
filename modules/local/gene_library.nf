process GENEPRED {
    label "viroprofiler_base"

    input:
    path(contigs)
    val(prefix)

    output:
    path("genes_*.fna"), emit: gene_fna_ch
    path("genes_*.gff"), emit: gene_gff_ch
    path("genes_*.faa"), emit: prot_ch

    when:
    task.ext.when == null || task.ext.when

    """
    prodigal-gv -i $contigs -o all.gff -a all.faa -d all.fna -p meta -f gff -g 11
    pretty_gff.py -i all.gff -o genes_${prefix}.gff
    mkdir -p prodigal
    mv all.faa all.fna prodigal
    sed 's/*//' prodigal/all.faa |  grep -v '^\$' > genes_${prefix}.faa
    sed 's/*//' prodigal/all.fna |  grep -v '^\$' > genes_${prefix}.fna
    """

    stub:
    """
    printf '>stub_gene_1\nACGTACGT\n' > genes_${prefix}.fna
    printf '>stub_gene_1\nMKVL\n' > genes_${prefix}.faa
    printf '##gff-version 3\n' > genes_${prefix}.gff
    """
}

process NRSEQS {
    label "viroprofiler_geneannot"

    input:
    path(seqs)
    val(prefix)
    val(min_similarity)
    val(min_coverage)

    output:
    path("${prefix}_rep_seq.fasta"), emit: cluster_rep_ch
    path("${prefix}_cluster.tsv"), emit: cluster_tsv_ch

    when:
    task.ext.when == null || task.ext.when

    """
    mmseqs easy-cluster $seqs $prefix tmp --min-seq-id $min_similarity -c $min_coverage --threads $task.cpus
    """

    stub:
    """
    printf '>stub_seq\nACGT\n' > ${prefix}_rep_seq.fasta
    printf 'representative\tmember\n' > ${prefix}_cluster.tsv
    """

}
