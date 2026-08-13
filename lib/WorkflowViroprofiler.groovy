//
// This file holds several functions specific to the workflow/viroprofiler.nf in the nf-core/viroprofiler pipeline
//

class WorkflowViroprofiler {

    // The stages `--mode` can stop at, in the order they run. A mode is a prefix of the
    // pipeline, not a branch: `--mode contiglib` runs everything `--mode fastp` runs and
    // then continues. `setup` is not in here because it builds databases instead of
    // processing reads, and shares no stage with the others.
    public static final Map MODE_STAGE = [ 'fastqc': 1, 'fastp': 2, 'contiglib': 3, 'all': 4 ]

    //
    // Check and validate parameters
    //
    public static void initialise(params, log) {
        genomeExistsError(params, log)
        modeIsValid(params, log)
        binningIsAvailable(params, log)

        // if (!params.fasta) {
        //     log.error "Genome fasta file not specified with e.g. '--fasta genome.fa' or via a detectable config file."
        //     System.exit(1)
        // }
    }

    //
    // Return the stage number `--mode` stops at, for a mode other than `setup`.
    //
    public static int stageOf(params) {
        return MODE_STAGE[params.mode] as int
    }

    //
    // Reject a mode that names no stage, and a mode whose stages are all skipped anyway.
    //
    private static void modeIsValid(params, log) {
        if (params.mode != 'setup' && !MODE_STAGE.containsKey(params.mode)) {
            log.error "'--mode ${params.mode}' is not a pipeline mode.\n" +
                "  Available modes: setup, ${MODE_STAGE.keySet().join(', ')}"
            System.exit(1)
        }

        // `--reads_type clean` declares the reads already trimmed, so FASTQC and FASTP
        // never run. A mode that stops at one of them would then produce nothing at all.
        if (params.reads_type == 'clean' && params.mode in ['fastqc', 'fastp']) {
            log.error "'--mode ${params.mode}' has nothing to do with '--reads_type clean':\n" +
                "  reads declared clean skip both FASTQC and FASTP.\n" +
                "  Use '--reads_type raw', or a later mode such as '--mode contiglib'."
            System.exit(1)
        }
    }

    //
    // Get workflow summary for MultiQC
    //
    public static String paramsSummaryMultiqc(workflow, summary) {
        String summary_section = ''
        for (group in summary.keySet()) {
            def group_params = summary.get(group)  // This gets the parameters of that particular group
            if (group_params) {
                summary_section += "    <p style=\"font-size:110%\"><b>$group</b></p>\n"
                summary_section += "    <dl class=\"dl-horizontal\">\n"
                for (param in group_params.keySet()) {
                    summary_section += "        <dt>$param</dt><dd><samp>${group_params.get(param) ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>\n"
                }
                summary_section += "    </dl>\n"
            }
        }

        String yaml_file_text  = "id: '${workflow.manifest.name.replace('/','-')}-summary'\n"
        yaml_file_text        += "description: ' - this information is collected when the pipeline is started.'\n"
        yaml_file_text        += "section_name: '${workflow.manifest.name} Workflow Summary'\n"
        yaml_file_text        += "section_href: 'https://github.com/${workflow.manifest.name}'\n"
        yaml_file_text        += "plot_type: 'html'\n"
        yaml_file_text        += "data: |\n"
        yaml_file_text        += "${summary_section}"
        return yaml_file_text
    }

    //
    // Refuse `--binning phamb` where VAMB cannot exist.
    //
    // PHAMB bins VAMB's clusters, and VAMB has no linux-aarch64 artifact: 3.x and 4.x are
    // compiled and published for linux-64 only, and the noarch 5.x needs pycoverm, which
    // is a Rust extension built for linux-64 and macOS alone. Without this check the run
    // reaches VAMB and dies on `command not found`, several hours in.
    //
    // This reads the architecture of the machine Nextflow itself runs on, which is the
    // right answer for a local executor and a guess for a heterogeneous cluster. On such a
    // cluster set `--binning vrhyme`, or submit from a node of the architecture the tasks
    // will run on.
    //
    private static void binningIsAvailable(params, log) {
        def arch = System.getProperty('os.arch')
        if (params.binning == 'phamb' && arch in ['aarch64', 'arm64']) {
            log.error "'--binning phamb' cannot run on ${arch}.\n" +
                "  PHAMB bins VAMB's output, and VAMB has no linux-aarch64 build:\n" +
                "  releases through 4.1.3 are linux-64 only, and 5.x depends on pycoverm,\n" +
                "  which has no aarch64 artifact either. See docs/dev/ARM64.md.\n" +
                "  Use '--binning vrhyme', which is architecture-independent."
            System.exit(1)
        }
    }

    //
    // Exit pipeline if incorrect --genome key provided
    //
    private static void genomeExistsError(params, log) {
        if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
            log.error "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
                "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
                "  Currently, the available genome keys are:\n" +
                "  ${params.genomes.keySet().join(", ")}\n" +
                "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            System.exit(1)
        }
    }
}
