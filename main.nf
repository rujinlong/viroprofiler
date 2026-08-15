#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    deng-lab/viroprofiler
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/deng-lab/viroprofiler
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARAMETER TYPES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Types only; the values stay in nextflow.config, which still wins over anything here,
// and a profile and then the command line win over that in turn.
//
// Without a declaration, the strict parser hands a command-line value to the pipeline as
// the String it was typed as, where the old parser coerced it to the type of the default.
// `--use_dram false` then arrives as "false", which Groovy reads as true, so the module
// runs when the user asked for it not to. Schema validation currently rejects the run
// before that happens, which is the only reason it is loud rather than silent -- and it
// rejects every one of the 34 non-string parameters, `--max_cpus` included.
//
// Only Boolean, Integer and Float convert a command-line string. Number, Double and
// BigDecimal reject it. Float is right for the `number` parameters even where the value is
// a whole number: it leaves 95 an Integer rather than rendering it into a command as 95.0.
//
// The Boolean, Integer and Float groups mirror `"type"` in nextflow_schema.json, which is
// what validates them. `single_end` is here although the schema ignores it, precisely
// because the schema ignores it: nothing else would catch `--single_end false`.
//
// `binning` and `input_contigs` need no conversion -- they are strings already -- but are
// declared so that the type is stated where a reader looks for it. Both once defaulted to
// the boolean `false` for "off", which is the shape that breaks: `--binning false` arrives
// as "false", and a non-empty String is true. Their off values are now the string "false"
// and `null`, and the workflow matches `binning` against the binner names rather than
// testing it for truth.
params {
    binning:                       String
    input_contigs:                 String

    single_end:                    Boolean
    enable_conda:                  Boolean
    help:                          Boolean
    kraken2_clean:                 Boolean
    monochrome_logs:               Boolean
    plaintext_email:               Boolean
    save_output_fastqs:            Boolean
    save_reads_assignment:         Boolean
    show_hidden_params:            Boolean
    use_abricate:                  Boolean
    use_checkamg:                  Boolean
    use_decontam:                  Boolean
    use_dram:                      Boolean
    use_eggnog:                    Boolean
    use_iphop:                     Boolean
    use_kraken2:                   Boolean
    use_phamb:                     Boolean
    use_vibrant:                   Boolean
    use_vitap:                     Boolean
    validate_params:               Boolean

    binning_minlen_bin:            Integer
    binning_minlen_contig:         Integer
    vogdb_version:                 Integer
    contig_minlen:                 Integer
    contig_minlen_vcontact3:       Integer
    genomad_splits:                Integer
    max_cpus:                      Integer
    vcontact3_db_version:          Integer

    checkamg_min_weight:           Float
    contig_cluster_min_coverage:   Float
    contig_cluster_min_similarity: Float
    decontam_min_similarity:       Float
    gene_cluster_min_coverage:     Float
    gene_cluster_min_similarity:   Float
    prot_cluster_min_coverage:     Float
    prot_cluster_min_similarity:   Float
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VIROPROFILER } from './workflows/viroprofiler'
include { CONTIGANNO } from './workflows/contig_anno'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main deng-lab/viroprofiler analysis pipeline
//
workflow {
    main:
    // Parameter validation and the parameter summary run here rather than at file scope:
    // the strict script syntax allows no statements outside a declaration.
    WorkflowMain.initialise(workflow, params, log)

    def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

    def multiqc_report = channel.value([])
    if (params.input_contigs) {
        CONTIGANNO()
        multiqc_report = CONTIGANNO.out.multiqc_report
    } else {
        VIROPROFILER ()
        multiqc_report = VIROPROFILER.out.multiqc_report
    }

    // The completion handler belongs to the entry workflow, and specifically to this
    // `onComplete:` section rather than a `workflow.onComplete { }` closure: inside a
    // closure `params` resolves to null, which no linter reports. Registering it here also
    // means it runs once -- a file-scope handler in each of the two workflow files was
    // registered by both, so every run printed the completion summary twice.
    onComplete:
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
