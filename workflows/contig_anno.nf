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

workflow CONTIGANNO {
    ch_cclib = Channel.fromPath("${params.input_contigs}", checkIfExists: true).first()
    // MODULE: CheckV
    CHECKV(ch_cclib)
    clean_cclib_long = CHECKV.out.checkv_qc_ch
    CONTIGLIB_CLUSTER(clean_cclib_long)
    ch_nrclib = CONTIGLIB_CLUSTER.out.nrclib_ch

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
    }
    if (params.use_abricate) {
        ABRICATE (ch_nr_gene)
    }


    // Viral detection: geNomad + CheckV MQ, HQ, Complete [+ VIBRANT]
    GENOMAD(ch_nrclib)

    if (params.use_vibrant) {
        VIBRANT(ch_nrclib)
        ch_vibrant_list = VIBRANT.out.vibrant_list_ch
    } else {
        ch_vibrant_list = Channel.fromPath("${projectDir}/assets/no_vibrant_contigs.list").first()
    }

    VIRCONTIGS_PRE(ch_nrclib, GENOMAD.out.genomad_list_ch, CHECKV.out.checkv2vContigs_ch, ch_vibrant_list)
    ch_putative_vList =  VIRCONTIGS_PRE.out.putative_vList_ch
    ch_putative_vContigs =  VIRCONTIGS_PRE.out.putative_vContigs_ch
    vContigs_and_vMAGs = ch_putative_vContigs

    VIRSORTER2(ch_nrclib)        // for DRAM-v gene annotation and AMG detection
    ch_vs2contigs = VIRSORTER2.out.vs2_contigs_ch

    // ANNOTATION (AMG). CheckAMG is the auxiliary-gene caller; DRAM-v is kept because
    // its per-gene annotation table is complementary evidence, not a competing AMG call.
    if ( params.use_dram ) {
        DRAMV (ch_vs2contigs, VIRSORTER2.out.vs2_affi_ch)
    }
    if ( params.use_checkamg ) {
        CHECKAMG (ch_putative_vContigs)
    }

    // Taxonomy
    if (params.use_vitap) {
        TAXONOMY_VITAP(ch_nrclib)
        ch_taxa_vitap = TAXONOMY_VITAP.out.taxa_vitap_ch
        ch_taxa_vitap_ref = TAXONOMY_VITAP.out.taxa_vitap_ref_ch
    } else {
        // An empty VITAP result, so that TAXONOMY_MERGE reads a source with no
        // assignments rather than being given a different set of inputs.
        ch_taxa_vitap = Channel.fromPath("${projectDir}/assets/no_vitap/best_determined_lineages.tsv").first()
        ch_taxa_vitap_ref = Channel.fromPath("${projectDir}/assets/no_vitap/ICTV_selected_genomes.fasta").first()
    }
    TAXONOMY_VCONTACT3(ch_nrclib)
    TAXONOMY_MERGE(ch_taxa_vitap, ch_taxa_vitap_ref, TAXONOMY_VCONTACT3.out.taxa_vc_ch)

    // Viral host
    if ( params.use_iphop ) {
        VIRALHOST_IPHOP(ch_nrclib)
    }

    // Replication cycle
    BACPHLIP (ch_nrclib)
    ch_replicyc = BACPHLIP.out.bacphlip_ch

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowViroprofiler.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)
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
