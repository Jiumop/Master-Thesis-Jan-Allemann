################################################################################
# SNB THESIS - Master Pipeline
# Run all analysis scripts in order
################################################################################

setwd("C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R")

cat("========================================\n")
cat("  SNB Thesis Analysis Pipeline\n")
cat("========================================\n\n")

source("R/01_data_loading.R")
source("R/02_data_description.R")
source("R/03_shock_identification.R")
source("R/04_event_studies.R")
source("R/05_local_projections.R")
source("R/06_regime_analysis.R")
source("R/07_machine_learning.R")
source("R/08_robustness.R")

cat("\n========================================\n")
cat("  Pipeline complete!\n")
cat("========================================\n")
cat("  Data:    data/\n")
cat("  Figures: output/figures/\n")
cat("  Tables:  output/tables/\n")
cat("========================================\n")
