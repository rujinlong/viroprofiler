//
// This file holds several functions specific to the main.nf workflow in the nf-core/viroprofiler pipeline
//

class WorkflowMain {

    //
    // Citation string for pipeline
    //
    public static String citation(workflow) {
        return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
            // TODO nf-core: Add Zenodo DOI for pipeline after first release
            "* The ViroProfiler pipeline\n" +
            ' Ru, Jinlong, et al. "ViroProfiler: a containerized bioinformatics pipeline for viral metagenomic data analysis."\n Gut Microbes 15.1 (2023): 2192522. https://doi.org/10.1080/19490976.2023.2192522\n\n' +
            "* The nf-core framework\n" +
            ' Ewels, Philip A., et al. "The nf-core framework for community-curated bioinformatics pipelines."\n Nature biotechnology 38.3 (2020): 276-278. https://doi.org/10.1038/s41587-020-0439-x\n\n' +
            "* Software dependencies\n" +
            "  https://github.com/deng-lab/viroprofiler/blob/main/CITATIONS.md"
    }

    //
    // Print help to screen if required
    //
    public static String help(workflow, params, log) {
        def command = "nextflow run ${workflow.manifest.name} --input samplesheet.csv -profile docker"
        def help_string = ''
        help_string += NfcoreTemplate.logo(workflow, params.monochrome_logs)
        help_string += NfcoreSchema.paramsHelp(workflow, params, command)
        help_string += '\n' + citation(workflow) + '\n'
        help_string += NfcoreTemplate.dashedLine(params.monochrome_logs)
        return help_string
    }

    //
    // Print parameter summary log to screen
    //
    public static String paramsSummaryLog(workflow, params, log) {
        def summary_log = ''
        summary_log += NfcoreTemplate.logo(workflow, params.monochrome_logs)
        summary_log += NfcoreSchema.paramsSummaryLog(workflow, params)
        summary_log += '\n' + citation(workflow) + '\n'
        summary_log += NfcoreTemplate.dashedLine(params.monochrome_logs)
        return summary_log
    }

    //
    // Validate parameters and print summary to screen
    //
    //
    // Warn when `params.max_*` and the resource ceiling actually in force disagree.
    //
    // `process.resourceLimits` replaced nf-core's `check_max()`, which the strict config
    // language cannot express. The two are not evaluated at the same time: `check_max()`
    // ran per task and read `params.max_cpus` as it finally stood, whereas the map is
    // evaluated where it is written. nextflow.config writes it below the `profiles` block,
    // so a profile, `-params-file` and `--max_cpus` are all picked up -- but a `-c` file is
    // applied afterwards, and one that sets only `params.max_cpus` moves the number this
    // pipeline prints in its parameter summary without moving the cap it submits with.
    //
    // Measured: `-c` setting max_cpus 7 against `-profile test_stub`, whose ceiling is 2,
    // leaves every task at 2 while the summary says 7.
    //
    // This warns rather than fails: setting `process.resourceLimits` directly in a `-c` file
    // is the supported way to raise the ceiling, and that route makes the two disagree by
    // design. Either way the message names the value that is in force.
    //
    private static void resourceLimitsAgree(workflow, params, log) {
        def limits = null
        try {
            limits = workflow.session.config.navigate('process.resourceLimits')
        } catch (Exception e) {
            return    // no config to inspect; nothing useful to say
        }
        if (!(limits instanceof Map)) return

        def disagree = [
            ['cpus',   params.max_cpus],
            ['memory', params.max_memory],
            ['time',   params.max_time],
        ].findAll { key, want ->
            want != null && limits[key] != null && limits[key].toString() != want.toString()
        }
        if (!disagree) return

        log.warn "The resource ceiling in force is not the one --max_* asks for.\n" +
            disagree.collect { key, want ->
                "  ${key}: --max_${key} says ${want}, " +
                "process.resourceLimits enforces ${limits[key]}"
            }.join("\n") + "\n" +
            "  process.resourceLimits is evaluated where it is written, so a -c file that\n" +
            "  sets only params.max_* arrives too late. Set process.resourceLimits there\n" +
            "  instead, or pass --max_* on the command line."
    }

    public static void initialise(workflow, params, log) {
        // Print help to screen if required
        if (params.help) {
            log.info help(workflow, params, log)
            System.exit(0)
        }

        // Validate workflow parameters via the JSON schema
        if (params.validate_params) {
            NfcoreSchema.validateParameters(workflow, params, log)
        }

        // Print parameter summary log to screen
        log.info paramsSummaryLog(workflow, params, log)

        // Check that a -profile or Nextflow config has been provided to run the pipeline
        NfcoreTemplate.checkConfigProvided(workflow, log)

        // Say so when the resource ceiling the summary just printed is not the one in force
        resourceLimitsAgree(workflow, params, log)

        // Check that conda channels are set-up correctly
        if (params.enable_conda) {
            Utils.checkCondaChannels(log)
        }

        // Check AWS batch settings
        NfcoreTemplate.awsBatch(workflow, params)

        // The database root is bind-mounted into every container (see the `containerOptions`
        // closure in nextflow.config). Apptainer/Singularity refuse to bind a path that does
        // not exist, so create it up front -- `--mode setup` populates it afterwards.
        def db_dir = new File(params.db as String)
        if (!db_dir.exists() && !db_dir.mkdirs()) {
            log.error "Cannot create the database directory '${db_dir}'. Pass a writable path with --db."
            System.exit(1)
        }

        // Check input has been provided
        // if (!params.input) {
        //     log.error "Please provide an input samplesheet to the pipeline e.g. '--input samplesheet.csv'"
        //     System.exit(1)
        // }
    }

}
