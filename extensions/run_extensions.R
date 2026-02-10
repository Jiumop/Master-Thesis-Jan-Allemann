################################################################################
# SNB THESIS - METHODOLOGICAL EXTENSIONS
# Master script: runs all 7 extensions
#
# Prerequisites: Run the main pipeline first (run_all.R) to generate
#   - prepared_data.RData
#   - shock_identification.RData
#   - local_projections.RData
#   - regime_analysis.RData
################################################################################

cat("============================================================\n")
cat("  SNB Thesis: Methodological Extensions Pipeline\n")
cat("============================================================\n\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

# Verify prerequisites
required_files <- c("cache/prepared_data.RData", "cache/shock_identification.RData",
                    "cache/local_projections.RData")
missing <- required_files[!file.exists(file.path(base_dir, required_files))]

if (length(missing) > 0) {
  stop("Missing prerequisite files. Run run_all.R first:\n  ",
       paste(missing, collapse = "\n  "))
}

# Ensure output directories exist
dir.create(file.path(ext_dir, "output/figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(ext_dir, "output/tables"),  showWarnings = FALSE, recursive = TRUE)

# Install required packages if missing
required_pkgs <- c("ivreg", "quantreg")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("Installing package: %s\n", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# Run all extensions
t_start <- Sys.time()

cat("\n--- Running Extension 1/7: High-Frequency Identification ---\n")
tryCatch(source(file.path(ext_dir, "R/01_hf_identification.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

cat("\n--- Running Extension 2/7: Smooth Transition LPs ---\n")
tryCatch(source(file.path(ext_dir, "R/02_smooth_transition.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

cat("\n--- Running Extension 3/7: Wild Bootstrap CIs ---\n")
tryCatch(source(file.path(ext_dir, "R/03_wild_bootstrap.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

cat("\n--- Running Extension 4/7: Placebo Tests ---\n")
tryCatch(source(file.path(ext_dir, "R/04_placebo_tests.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

cat("\n--- Running Extension 5/7: Information Effects ---\n")
tryCatch(source(file.path(ext_dir, "R/05_information_effects.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

cat("\n--- Running Extension 6/7: Additional Outcomes ---\n")
tryCatch(source(file.path(ext_dir, "R/06_additional_outcomes.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

cat("\n--- Running Extension 7/7: Asymmetry Tests ---\n")
tryCatch(source(file.path(ext_dir, "R/07_asymmetry_tests.R")),
         error = function(e) cat("  ERROR:", e$message, "\n"))

t_end <- Sys.time()

cat("\n============================================================\n")
cat("  Extensions pipeline complete!\n")
cat(sprintf("  Elapsed: %.1f minutes\n", as.numeric(difftime(t_end, t_start, units = "mins"))))
cat("============================================================\n")
cat("  Figures: extensions/output/figures/\n")
cat("  Tables:  extensions/output/tables/\n")
cat("  LaTeX:   extensions/doc/extensions_paper.tex\n")
cat("============================================================\n")
