/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowViroprofiler.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK             } from '../subworkflows/local/input_check'
include { vMAG_PHAMB; vMAG_VRHYME } from '../subworkflows/local/vMAG'
include { SETUP } from '../subworkflows/local/init'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//


include { FASTQC                       } from '../modules/nf-core/modules/fastqc/main'
include { MULTIQC                      } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS  } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'
include { FASTP                        } from '../modules/nf-core/modules/fastp/main'
include { SPADES                       } from '../modules/nf-core/modules/spades/main'
// local modules
include { DECONTAM                     } from '../modules/local/decontam'
include { CONTIGLIB; CONTIGLIB_CLUSTER } from '../modules/local/contig_library'
include { CONTIGINDEX; MAPPING2CONTIGS2; ABUNDANCE   } from '../modules/local/abundance'
include { BRACKEN; BRACKEN_COMBINEBRACKENOUTPUTS } from '../modules/local/bracken'
include { DRAMV; CHECKAMG; EMAPPER; ABRICATE } from '../modules/local/annotation'
include { VIRALHOST_IPHOP              } from '../modules/local/viral_host'
include { BACPHLIP; REPLIDEC           } from '../modules/local/replicyc'
include { CHECKV; VIRSORTER2; GENOMAD; VIRCONTIGS_PRE; VIBRANT       } from '../modules/local/viral_detection'
include { GENEPRED as GENEPRED4CTG; NRSEQS as NRPROT; NRSEQS as NRGENE } from '../modules/local/gene_library'
include { TAXONOMY_VITAP; TAXONOMY_VCONTACT3; TAXONOMY_MERGE } from '../modules/local/taxonomy'
include { RESULTS_TSE                  } from '../modules/local/base'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow VIROPROFILER {
    if (params.mode == "setup") {
        SETUP()
    } else {
        // `--mode` names the last stage to run, and the stages are cumulative: every
        // stage below the requested one runs too. The numbering, and the validation
        // that rejects an unknown mode, both live in WorkflowViroprofiler.MODE_STAGE.
        def stage = WorkflowViroprofiler.stageOf(params)

        ch_multiqc_files = Channel.empty()

        // Check mandatory parameters
        if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }
        ch_versions = Channel.empty()

        //
        // SUBWORKFLOW: Read in samplesheet, validate and stage input files
        //
        INPUT_CHECK ( ch_input )

        //
        // STAGE fastqc: report on the reads as submitted.
        //
        // Skipped entirely for `--reads_type clean`, which declares the reads already
        // trimmed. `--mode fastqc` is rejected in that combination rather than run empty.
        //
        if (params.reads_type != "clean") {
            FASTQC (
                INPUT_CHECK.out.reads
            )
            ch_versions = ch_versions.mix(FASTQC.out.versions.first())
            ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
        }

        //
        // STAGE fastp: trimming, and optional removal of host reads.
        //
        if (stage >= WorkflowViroprofiler.MODE_STAGE['fastp']) {
            // if input_type is "clean", set ch_clean_reads to input_reads, otherwise set to FASTP.out.reads
            if (params.reads_type == "clean") {
                ch_clean_reads = INPUT_CHECK.out.reads
            } else {
                // MODULE: Run fastp
                FASTP (
                    INPUT_CHECK.out.reads, false, false
                )
                ch_versions = ch_versions.mix(FASTP.out.versions.first())
                ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.collect{it[1]}.ifEmpty([]))

                // Decontamination
                if (params.use_decontam) {
                    def contamref = params.contamref_idx ?: "${params.db}/contamination_refs/hg19/ref"
                    if (!file(contamref).exists()) {
                        exit 1, "Decontamination is enabled but no reference index was found at '${contamref}'.\n" +
                                "Build a BBMap index there, point --contamref_idx at an existing one, or pass --use_decontam false."
                    }
                    ch_contamref = Channel.fromPath(contamref, checkIfExists: true).first()
                    DECONTAM (FASTP.out.reads, ch_contamref)
                    ch_clean_reads = DECONTAM.out.reads
                    ch_versions = ch_versions.mix(DECONTAM.out.versions.first())
                } else {
                    ch_clean_reads = FASTP.out.reads
                }
            }
        }

        //
        // STAGE contiglib: assemble, clean with CheckV, and dereplicate.
        //
        // The dereplicated library is the read-mapping reference for abundance, which is
        // why it covers all contigs and not only the viral ones, and why viral
        // identification happens after this stage rather than before it.
        //
        if (stage >= WorkflowViroprofiler.MODE_STAGE['contiglib']) {
            // if input_contigs is specified, set ch_cclib to input_contigs, otherwise set to CONTIGLIB.out.cclib_long_ch
            if (params.input_contigs) {
                ch_cclib = Channel.fromPath("${params.input_contigs}", checkIfExists: true).first()
            } else {
                // Run spades
                SPADES (
                    ch_clean_reads.map { meta, fastq -> [ meta, fastq, [], [] ] },
                    []
                )

                // Use contigs or scaffolds
                if ( params.assemblies == "contigs") {
                    assemblies = SPADES.out.contigs
                } else {
                    assemblies = SPADES.out.scaffolds
                }

                // Create contig library
                CONTIGLIB(
                    assemblies.map { meta, fasta -> [fasta] }.collect()
                )
                ch_cclib = CONTIGLIB.out.cclib_long_ch

                // Extract versions
                ch_versions = ch_versions.mix(SPADES.out.versions.first())
                ch_versions = ch_versions.mix(CONTIGLIB.out.versions)
            }

            // MODULE: CheckV
            CHECKV(ch_cclib)
            clean_cclib_long = CHECKV.out.checkv_qc_ch
            ch_versions = ch_versions.mix(CHECKV.out.versions)

            // MODULE: contig clustering
            CONTIGLIB_CLUSTER (clean_cclib_long)
            ch_nrclib = CONTIGLIB_CLUSTER.out.nrclib_ch
            ch_versions = ch_versions.mix(CONTIGLIB_CLUSTER.out.versions)
        }

        //
        // STAGE all: everything downstream of the dereplicated contig library.
        //
        if (stage >= WorkflowViroprofiler.MODE_STAGE['all']) {
            // Gene library
            GENEPRED4CTG (clean_cclib_long, "ccclib_long")
            ch_prot_all = GENEPRED4CTG.out.prot_ch
            ch_gene_all = GENEPRED4CTG.out.gene_fna_ch

            // Non-redundant gene library
            NRPROT (ch_prot_all, "prot", params.prot_cluster_min_similarity, params.prot_cluster_min_coverage)
            ch_nr_prot = NRPROT.out.cluster_rep_ch
            NRGENE (ch_gene_all, "gene", params.gene_cluster_min_similarity, params.gene_cluster_min_coverage)
            ch_nr_gene = NRGENE.out.cluster_rep_ch

            // Gene/Protein annotation
            if (params.use_eggnog) {
                EMAPPER (ch_nr_prot)
                // ch_versions = ch_versions.mix(EMAPPER.out.versions)
            }
            if (params.use_abricate) {
                ABRICATE (ch_nr_gene)
                ch_versions = ch_versions.mix(ABRICATE.out.versions)
            }

            // TODO: Abundance (but in minimap2, replace with bowtie2)
            // MAPPING2CONTIGS (
            //     ch_clean_reads,
            //     ch_nrclib,
            //     CONTIGLIB_CLUSTER.out.nrclib_dict
            // )
            // ch_bams = MAPPING2CONTIGS.out.bams_ch.collect()
            // ch_versions = ch_versions.mix(MAPPING2CONTIGS.out.versions.first())

            CONTIGINDEX (ch_nrclib)
            MAPPING2CONTIGS2 (
                ch_clean_reads,
                CONTIGINDEX.out.bowtie2idx_ch
            )
            ch_bams = MAPPING2CONTIGS2.out.bams_ch.collect()
            ch_versions = ch_versions.mix(MAPPING2CONTIGS2.out.versions.first())

            ABUNDANCE (ch_bams)
            // ch_versions = ch_versions.mix(ABUNDANCE.out.versions)


            // Viral detection: geNomad + CheckV MQ, HQ, Complete [+ VIBRANT]
            GENOMAD(ch_nrclib)
            ch_genomad_list = GENOMAD.out.genomad_list_ch
            ch_genomad_score = GENOMAD.out.genomad_score_ch
            ch_versions = ch_versions.mix(GENOMAD.out.versions)

            if (params.use_vibrant) {
                VIBRANT(ch_nrclib)
                ch_vibrant_list = VIBRANT.out.vibrant_list_ch
                ch_vibrant_quality = VIBRANT.out.vibrant_quality_ch
            } else {
                // Placeholders keep the union in VIRCONTIGS_PRE and the TSE assembly
                // supplied with a file to read. The quality table carries one sentinel
                // row: a header-only table makes R infer logical columns, which then
                // fails to join against the character contig IDs. The sentinel matches
                // no contig, and RESULTS_TSE joins from the contig side, so it never
                // reaches the output.
                ch_vibrant_list = Channel.fromPath("${projectDir}/assets/no_vibrant_contigs.list").first()
                ch_vibrant_quality = Channel.fromPath("${projectDir}/assets/no_vibrant_quality.tsv").first()
            }

            // vpfkit 0.5.0 still takes fin_dvf as a required argument and
            // create_vpftse_vir() indexes the dvf_score column it produces, so the slot
            // has to be filled even though DeepVirFinder is gone from the pipeline. Same
            // sentinel reasoning as above: it matches no contig and never reaches the
            // output.
            ch_dvf2vcontigs = Channel.fromPath("${projectDir}/assets/no_dvf_scores.tsv").first()

            VIRCONTIGS_PRE(ch_nrclib, ch_genomad_list, CHECKV.out.checkv2vContigs_ch, ch_vibrant_list)
            ch_putative_vList =  VIRCONTIGS_PRE.out.putative_vList_ch
            ch_putative_vContigs =  VIRCONTIGS_PRE.out.putative_vContigs_ch

            // TODO: add back after fix bug in abundance.
            // Binning (optional)
            if ( params.binning ) {
                if ( params.binning == "phamb" ) {
                    // PHAMB's features are counts of VOG and miComplete HMM hits, and those
                    // two HMM sets are installed by `--mode setup` only when
                    // `--use_phamb true` was passed. Check here rather than letting
                    // MICOMPLETEDB fail on a missing file after VAMB has already run.
                    // Not under `-stub`, where no process reads a database at all.
                    def phamb_hmms = ["${params.db}/vogdb/AllVOG.hmm",
                                      "${params.db}/micomplete/Bact105.hmm"]
                    def missing_hmms = workflow.stubRun ? [] : phamb_hmms.findAll { !file(it).exists() }
                    if (missing_hmms) {
                        exit 1, "--binning phamb needs HMM sets that are not present:\n" +
                                missing_hmms.collect { "  ${it}" }.join("\n") + "\n" +
                                "Build them with '--mode setup --use_phamb true', or use --binning vrhyme."
                    }

                    // PHAMB's random forest reads a per-contig virus score in
                    // DeepVirFinder's format. This pipeline no longer runs DeepVirFinder,
                    // so PHAMB_DVF_TABLE supplies geNomad's scores in that layout: the same
                    // range and the same slot, but not the distribution the forest was
                    // fitted on, so its bin calls are approximate. bin/genomad_to_dvf.py
                    // states the limitation in full.
                    vMAG_PHAMB(ch_putative_vContigs, ch_genomad_score, ch_bams)
                    vContigs_and_vMAGs = vMAG_PHAMB.out
                } else if ( params.binning == "vrhyme" ) {
                    vMAG_VRHYME(ch_putative_vContigs, ch_gene_all, ch_prot_all, ch_bams)
                    vContigs_and_vMAGs = vMAG_VRHYME.out
                }
            } else {
                vContigs_and_vMAGs = ch_putative_vContigs
            }

            VIRSORTER2(vContigs_and_vMAGs)        // for DRAM-v gene annotation and AMG detection
            ch_vs2contigs = VIRSORTER2.out.vs2_contigs_ch

            // ANNOTATION (AMG). CheckAMG is the auxiliary-gene caller; DRAM-v is kept
            // because its per-gene annotation table is complementary evidence, not a
            // competing AMG call.
            if ( params.use_dram ) {
                DRAMV (ch_vs2contigs, VIRSORTER2.out.vs2_affi_ch)
                ch_versions = ch_versions.mix(DRAMV.out.versions)
            }
            if ( params.use_checkamg ) {
                CHECKAMG (vContigs_and_vMAGs)
                ch_versions = ch_versions.mix(CHECKAMG.out.versions)
            }

            // Taxonomy
            if (params.use_vitap) {
                TAXONOMY_VITAP(vContigs_and_vMAGs)
                ch_taxa_vitap = TAXONOMY_VITAP.out.taxa_vitap_ch
                ch_taxa_vitap_ref = TAXONOMY_VITAP.out.taxa_vitap_ref_ch
                ch_versions = ch_versions.mix(TAXONOMY_VITAP.out.versions)
            } else {
                // An empty VITAP result, so that TAXONOMY_MERGE reads a source
                // with no assignments rather than being given a different set of
                // inputs. The two files together are what `read_vitap` expects:
                // the lineage table, and the reference genomes to subtract from
                // it.
                ch_taxa_vitap = Channel.fromPath("${projectDir}/assets/no_vitap/best_determined_lineages.tsv").first()
                ch_taxa_vitap_ref = Channel.fromPath("${projectDir}/assets/no_vitap/ICTV_selected_genomes.fasta").first()
            }
            TAXONOMY_VCONTACT3(vContigs_and_vMAGs)
            TAXONOMY_MERGE(ch_taxa_vitap, ch_taxa_vitap_ref, TAXONOMY_VCONTACT3.out.taxa_vc_ch)

            // Using kraken2 and bracken
            if ( params.use_kraken2 ) {
                BRACKEN(ch_clean_reads, "${params.db}/kraken2")
                BRACKEN_COMBINEBRACKENOUTPUTS(BRACKEN.out.ch_reports.collect())
            }

            // Viral host
            if ( params.use_iphop ) {
                VIRALHOST_IPHOP(vContigs_and_vMAGs)
                ch_versions = ch_versions.mix(VIRALHOST_IPHOP.out.versions)
            }

            ch_versions = ch_versions.mix(VIRSORTER2.out.versions)
            ch_versions = ch_versions.mix(TAXONOMY_VCONTACT3.out.versions)
            ch_versions = ch_versions.mix(TAXONOMY_MERGE.out.versions)
            // ch_versions = ch_versions.mix(BRACKEN.out.versions)

            // Replication cycle
            if ( params.replicyc == "bacphlip" ) {
                BACPHLIP (vContigs_and_vMAGs)
                ch_versions = ch_versions.mix(BACPHLIP.out.versions)
                ch_replicyc = BACPHLIP.out.bacphlip_ch
            } else if ( params.replicyc == "replidec" ) {
                REPLIDEC (vContigs_and_vMAGs)
                ch_versions = ch_versions.mix(REPLIDEC.out.versions)
                ch_replicyc = REPLIDEC.out.replidec_ch
            }

            // TreeSummarizedExperiment
            RESULTS_TSE (ABUNDANCE.out.ab_count_ch, ABUNDANCE.out.ab_tpm_ch, ABUNDANCE.out.ab_trmean_ch, ABUNDANCE.out.ab_covfrac_ch, TAXONOMY_MERGE.out.taxa_tse_ch, CHECKV.out.checkv2vContigs_ch, VIRSORTER2.out.vs2_score_ch, ch_vibrant_quality, ch_dvf2vcontigs, ch_genomad_score, ch_replicyc)
        }

        // Reporting runs for every mode, so that a run stopped early still says what it
        // did and with which tool versions.
        CUSTOM_DUMPSOFTWAREVERSIONS (
            ch_versions.unique().collectFile(name: 'collated_versions.yml')
        )

        //
        // MODULE: MultiQC
        //
        workflow_summary    = WorkflowViroprofiler.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)

        ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
        ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

        MULTIQC (
            ch_multiqc_files.collect()
        )
        multiqc_report = MULTIQC.out.report.toList()
        ch_versions    = ch_versions.mix(MULTIQC.out.versions)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
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
