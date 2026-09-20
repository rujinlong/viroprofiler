#!/usr/bin/env Rscript

library(argparser)
library(TreeSummarizedExperiment)
library(vpfkit)

p <- arg_parser("Create ViroProfiler TSE object")
# Always supplied by RESULTS_TSE.
p <- add_argument(p, "--fin_abcount", help="abundance_contigs_count.tsv.gz")
p <- add_argument(p, "--fin_abtpm", help="abundance_contigs_tpm.tsv.gz")
p <- add_argument(p, "--fin_abtmm", help="abundance_contigs_trimmed_mean.tsv.gz")
p <- add_argument(p, "--fin_abcov", help="abundance_contigs_covered_fraction.tsv.gz")
p <- add_argument(p, "--fin_taxa", help="taxonomy_tse.tsv from TAXONOMY_MERGE")
p <- add_argument(p, "--fin_checkv", help="quality_summary.tsv")
p <- add_argument(p, "--fin_virsorter2", help="final-viral-score.tsv")
p <- add_argument(p, "--fin_replicyc", help="putative_vcontigs_pref1.fasta.bacphlip")
# Omitted when the tool is switched off. create_vpftse() treats a missing argument, NA,
# an empty string and a non-existent path alike, so nothing here has to guard them.
p <- add_argument(p, "--fin_vibrant", help="VIBRANT_genome_quality_contigs.tsv")
p <- add_argument(p, "--fin_genomad", help="virus_genomad_summary.tsv")
p <- add_argument(p, "--fin_checkamg", help="checkamg_results directory from CHECKAMG")
p <- add_argument(p, "--fin_iphop", help="Host_prediction_to_genus_m90.csv")
p <- add_argument(p, "--fin_dramv", help="dramv-annotate/annotations.tsv")
p <- add_argument(p, "--fin_vircontigs", help="putative_vcontigs_pref1.list")
p <- add_argument(p, "--fin_coverm_log", help="abundance/log_contig_count.txt")
p <- add_argument(p, "--fin_metadata", help="sample metadata table (CSV/TSV/XLSX)")
argv <- parse_args(p)

tse <- vpfkit::create_vpftse(fin_abcount = argv$fin_abcount,
                             fin_abtpm = argv$fin_abtpm,
                             fin_abtmm = argv$fin_abtmm,
                             fin_abcov = argv$fin_abcov,
                             fin_taxa = argv$fin_taxa,
                             fin_checkv = argv$fin_checkv,
                             fin_virsorter2 = argv$fin_virsorter2,
                             fin_replicyc = argv$fin_replicyc,
                             fin_vibrant = argv$fin_vibrant,
                             fin_genomad = argv$fin_genomad,
                             fin_checkamg = argv$fin_checkamg,
                             fin_iphop = argv$fin_iphop,
                             fin_dramv = argv$fin_dramv,
                             fin_vircontigs = argv$fin_vircontigs,
                             fin_coverm_log = argv$fin_coverm_log,
                             fin_metadata = argv$fin_metadata)

# Annotate the all-contig object too, so that the record of which rule called a contig
# viral survives in the object the viral subset was cut from.
tse <- vpfkit::annotate_viral_votes(tse)
tse_vir <- vpfkit::create_vpftse_vir(tse)

readr::write_rds(tse, file = "viroprofiler_output_all_contigs.rds")
readr::write_rds(tse_vir, file = "viroprofiler_output.rds")
