process DRAMV {
    label "viroprofiler_geneannot"

    input:
    path contigs
    path AFFI

    output:
    path "dramv-annotate"
    path "dramv-distill"
    path "dramv-annotate/genes.faa", emit: dramv_proteins_ch
    path "dramv-annotate/scaffolds.fna", emit: dramv_contigs_ch
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # DRAM takes every database location from its CONFIG, which DB_DRAM wrote with the
    # absolute paths under --db. That directory is bind-mounted into the container at the
    # same path, so pointing DRAM at the CONFIG is all that is needed and nothing has to
    # be written inside the image.
    export DRAM_CONFIG_LOCATION=${params.db}/dram/CONFIG

    DRAM-v.py annotate -i $contigs -v $AFFI -o dramv-annotate --threads $task.cpus --min_contig_size $params.contig_minlen
    DRAM-v.py distill -i dramv-annotate/annotations.tsv -o dramv-distill

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DRAM: \$(python -c 'from mag_annotator import __version__; print(__version__)')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p dramv-annotate
    mkdir -p dramv-distill
    printf '>stub_gene\nMKVL\n' > dramv-annotate/genes.faa
    printf '>stub_scaffold\nACGT\n' > dramv-annotate/scaffolds.fna
    touch dramv-annotate/annotations.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DRAM: 1.4.6
    END_VERSIONS
    """
}


process CHECKAMG {
    label "viroprofiler_checkamg"

    input:
    path(contigs)

    output:
    path("checkamg_results"), emit: checkamg_ch
    path("versions.yml"), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # CheckAMG drives its own Snakemake workflow, and Snakemake writes into
    # \$HOME. Nextflow runs Apptainer with --no-home, so \$HOME is a read-only
    # stub; point it at the task directory, as VIRSORTER2 and DRAMV do.
    export HOME=\$PWD

    # `-m` is a hard ceiling CheckAMG enforces on itself -- it aborts rather
    # than exceeding it -- so it has to track what Nextflow actually granted the
    # task, not a fixed default derived from the whole machine.
    checkamg annotate \\
        -i $contigs \\
        -d ${params.db}/checkamg \\
        -o checkamg_out \\
        -l $params.contig_minlen \\
        -amg $params.checkamg_min_weight \\
        -t $task.cpus \\
        -m ${task.memory.toGiga()} \\
        $args

    # Publish the tables and the log, not the Snakemake bookkeeping under
    # `.snakemake/` (thousands of files, and symlinks that point into the work
    # directory). `-L` because the FASTA subdirectories contain symlinks.
    mkdir -p checkamg_results
    cp -rL checkamg_out/results/. checkamg_results/
    cp checkamg_out/CheckAMG_annotate.log checkamg_results/

    # The one table that proves the run produced curated calls rather than
    # stopping early: CheckAMG exits 0 after writing nothing if every contig is
    # filtered out before the curation step.
    test -s checkamg_results/final_results.tsv || {
        echo "CheckAMG finished but wrote no final_results.tsv; see checkamg_results/CheckAMG_annotate.log." >&2
        exit 1
    }

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CheckAMG: \$(checkamg --version 2>&1 | grep -o 'CheckAMG .*' | sed 's/CheckAMG //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p checkamg_results
    printf 'Protein\tContig\tGenome\tProtein Classification\n' > checkamg_results/final_results.tsv
    printf 'stub_gene_1\tstub_NODE_1_length_5000_cov_100\tstub_NODE_1_length_5000_cov_100\tAMG\n' >> checkamg_results/final_results.tsv
    printf 'Protein\tContig\n' > checkamg_results/metabolic_genes_curated.tsv
    printf 'Protein\tContig\n' > checkamg_results/regulation_genes_curated.tsv
    printf 'Protein\tContig\n' > checkamg_results/physiology_genes_curated.tsv
    touch checkamg_results/CheckAMG_annotate.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CheckAMG: 1.1.1
    END_VERSIONS
    """
}


process MICOMPLETEDB{
    label "viroprofiler_base"
    
    input:
    path(prot)

    output:
    path("hmmMiComplete.tbl"), emit: hmm_miComplete

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    hmmsearch --cpu $task.cpus -E 1.0e-05 -o out_miComplete --tblout hmmMiComplete.tbl ${params.db}/micomplete/Bact105.hmm $prot
    """

    stub:
    """
    printf '# hmmsearch tblout stub\n' > hmmMiComplete.tbl
    """
}


process VOGDB{
    label "viroprofiler_base"
    
    input:
    path(prot)

    output:
    path("hmmVOG.tbl"), emit: hmm_VOGDB

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    hmmsearch --cpu $task.cpus -E 1.0e-05 -o out_vogdb --tblout hmmVOG.tbl ${params.db}/vogdb/AllVOG.hmm $prot
    """

    stub:
    """
    printf '# hmmsearch tblout stub\n' > hmmVOG.tbl
    """
}

process EMAPPER {
    label "viroprofiler_geneannot"

    input:
    path(prot_faa)

    output:
    path("anno_eggnog.tsv"), emit: anno_eggnog_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    emapper.py -i $prot_faa -o eggnog --cpu $task.cpus --no_file_comments -m diamond --data_dir ${params.db}/eggnog
    parse_eggnog.py -i eggnog.emapper.annotations -o anno_eggnog.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emapper: \$(echo \$(emapper.py -v) | grep version | cut -d' ' -f1 | sed 's/emapper-/v/g')
    END_VERSIONS
    """

    stub:
    """
    printf 'query_name\tseed_ortholog\tevalue\tscore\n' > anno_eggnog.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emapper: 2.1.9
    END_VERSIONS
    """
}


// process ABRICATE {
//     label "viroprofiler_geneannot"

//     input:
//     path(genes)

//     output:
//     path("*.tsv")

//     when:
//     task.ext.when == null || task.ext.when

//     """
//     for abrdb in argannot card ecoh ncbi plasmidfinder resfinder vfdb;do
//         abricate --db \$abrdb $genes > ARG_\${abrdb}.tsv
//     done

//     head -n1 ARG_argannot.tsv | cut -f2- > anno_abricate.tsv
//     cat ARG_* | grep -v "^#FILE" | cut -f2- | sort -k1,2 >> anno_abricate.tsv
//     """
// }


process ABRICATE {
    conda (params.enable_conda ? "bioconda::abricate=1.0.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/abricate:1.0.1--ha8f3691_1':
        'quay.io/biocontainers/abricate:1.0.1--ha8f3691_1' }"

    input:
    path gene_fasta

    output:
    path "*.tsv"
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    for abrdb in argannot card ecoh ncbi plasmidfinder resfinder vfdb;do
        abricate --db \$abrdb $args $gene_fasta > ARG_\${abrdb}.tsv
    done

    head -n1 ARG_argannot.tsv | cut -f2- > anno_abricate.tsv
    cat ARG_* | grep -v "^#FILE" | cut -f2- | sort -k1,2 >> anno_abricate.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$(echo \$(abricate -v) | sed 's/^abricate  //' )
    END_VERSIONS
    """

    stub:
    """
    printf '#FILE\tSEQUENCE\tSTART\tEND\tSTRAND\tGENE\tCOVERAGE\tCOVERAGE_MAP\tGAPS\t%%COVERAGE\t%%IDENTITY\tDATABASE\tACCESSION\tPRODUCT\tRESISTANCE\n' > ARG_argannot.tsv
    printf 'SEQUENCE\tSTART\tEND\tSTRAND\tGENE\tCOVERAGE\tCOVERAGE_MAP\tGAPS\t%%COVERAGE\t%%IDENTITY\tDATABASE\tACCESSION\tPRODUCT\tRESISTANCE\n' > anno_abricate.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: 1.0.1
    END_VERSIONS
    """
}