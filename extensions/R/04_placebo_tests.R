################################################################################
# EXTENSION 4: PLACEBO / FALSIFICATION TESTS
# LPs on no-change meetings and permutation tests
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(xtable)
library(ggplot2)
library(gridExtra)

cat("\n=== Extension 4: Placebo / Falsification Tests ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "shock_identification.RData"))

if (exists("control_formula")) {
  ctrl <- control_formula
} else {
  ctrl <- "cpi_yoy_lag1 + kof_lag1"
}

horizons <- 1:12

# Ensure forward differences exist
for (h in horizons) {
  if (!paste0("fx_change_", h) %in% colnames(monthly_full)) {
    monthly_full[[paste0("fx_change_", h)]] <-
      (lead(monthly_full$log_eur_chf, h) - monthly_full$log_eur_chf) * 100
  }
  if (!paste0("cpi_change_", h) %in% colnames(monthly_full)) {
    monthly_full[[paste0("cpi_change_", h)]] <-
      lead(monthly_full$cpi_yoy, h) - monthly_full$cpi_yoy
  }
}

# --------------------------------------------------------------------------
# STEP 1: Create placebo shock from predicted component (fitted values)
# On no-change months, the "shock" is the anticipated/predicted part
# --------------------------------------------------------------------------
ann <- read.csv(file.path(base_dir, "data/snb_announcements.csv"),
                stringsAsFactors = FALSE)
ann$date <- as.Date(ann$date)

# Identify hold months (rate_change_pp == 0 or rate_action == "hold")
hold_dates <- ann %>%
  filter(rate_change_pp == 0 | rate_action == "hold") %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  pull(year_month) %>%
  unique()

cat(sprintf("  No-change (hold) meetings: %d\n", length(hold_dates)))

# Placebo shock: predicted component from purging regression on the full sample
# (fitted values represent the anticipated policy move given macro conditions)
monthly_full$placebo_shock <- 0
monthly_full$is_hold <- monthly_full$year_month %in% hold_dates

# For hold months: use the fitted value from the purging regression
# (what the model predicts the rate change should have been)
if (exists("purge_main")) {
  # Get predicted values for hold months
  hold_data <- monthly_full %>% filter(is_hold)

  tryCatch({
    predicted_vals <- predict(purge_main, newdata = hold_data)
    monthly_full$placebo_shock[monthly_full$is_hold] <- predicted_vals
  }, error = function(e) {
    cat("  Note: Using random placebo shocks (purging model variables not available for all holds)\n")
    set.seed(123)
    monthly_full$placebo_shock[monthly_full$is_hold] <<-
      rnorm(sum(monthly_full$is_hold), 0, sd(monthly_full$mp_shock, na.rm = TRUE))
  })
} else {
  set.seed(123)
  monthly_full$placebo_shock[monthly_full$is_hold] <-
    rnorm(sum(monthly_full$is_hold), 0, sd(monthly_full$mp_shock, na.rm = TRUE))
}

# --------------------------------------------------------------------------
# STEP 2: Run placebo LPs on hold months
# --------------------------------------------------------------------------
placebo_fx  <- data.frame()
placebo_cpi <- data.frame()

for (h in horizons) {
  # EUR/CHF
  fx_formula <- as.formula(paste0("fx_change_", h, " ~ placebo_shock + ", ctrl))
  fx_mod <- lm(fx_formula, data = monthly_full)
  vcov_fx <- NeweyWest(fx_mod, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))

  placebo_fx <- rbind(placebo_fx, data.frame(
    horizon  = h,
    beta     = coef(fx_mod)["placebo_shock"],
    se       = se_fx["placebo_shock"],
    ci_lower = coef(fx_mod)["placebo_shock"] - 1.96 * se_fx["placebo_shock"],
    ci_upper = coef(fx_mod)["placebo_shock"] + 1.96 * se_fx["placebo_shock"],
    type     = "Placebo (Fitted Values)"
  ))

  # CPI
  cpi_formula <- as.formula(paste0("cpi_change_", h, " ~ placebo_shock + ", ctrl))
  cpi_mod <- lm(cpi_formula, data = monthly_full)
  vcov_cpi <- NeweyWest(cpi_mod, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))

  placebo_cpi <- rbind(placebo_cpi, data.frame(
    horizon  = h,
    beta     = coef(cpi_mod)["placebo_shock"],
    se       = se_cpi["placebo_shock"],
    ci_lower = coef(cpi_mod)["placebo_shock"] - 1.96 * se_cpi["placebo_shock"],
    ci_upper = coef(cpi_mod)["placebo_shock"] + 1.96 * se_cpi["placebo_shock"],
    type     = "Placebo (Fitted Values)"
  ))
}

# --------------------------------------------------------------------------
# STEP 3: Permutation test — random shock assignment
# --------------------------------------------------------------------------
set.seed(42)
n_perm <- 500

# Store actual LP coefficients for comparison
load(file.path(base_dir, "local_projections.RData"))
actual_betas_fx  <- lp_fx_results$beta
actual_betas_cpi <- lp_cpi_results$beta

perm_fx_dist  <- matrix(NA, nrow = n_perm, ncol = length(horizons))
perm_cpi_dist <- matrix(NA, nrow = n_perm, ncol = length(horizons))

cat(sprintf("  Running permutation test (%d permutations)...\n", n_perm))

for (p in seq_len(n_perm)) {
  if (p %% 100 == 0) cat(sprintf("    Permutation %d/%d\r", p, n_perm))

  # Randomly shuffle shock assignment
  monthly_full$perm_shock <- sample(monthly_full$mp_shock)

  for (h in horizons) {
    # FX
    fx_f <- as.formula(paste0("fx_change_", h, " ~ perm_shock + ", ctrl))
    fx_m <- lm(fx_f, data = monthly_full)
    perm_fx_dist[p, h] <- coef(fx_m)["perm_shock"]

    # CPI
    cpi_f <- as.formula(paste0("cpi_change_", h, " ~ perm_shock + ", ctrl))
    cpi_m <- lm(cpi_f, data = monthly_full)
    perm_cpi_dist[p, h] <- coef(cpi_m)["perm_shock"]
  }
}
cat("\n")

# Permutation p-values
perm_pval_fx  <- sapply(seq_along(horizons), function(h)
  mean(abs(perm_fx_dist[, h]) >= abs(actual_betas_fx[h])))
perm_pval_cpi <- sapply(seq_along(horizons), function(h)
  mean(abs(perm_cpi_dist[, h]) >= abs(actual_betas_cpi[h])))

# Add permutation results as additional placebo series
perm_fx_results <- data.frame(
  horizon  = horizons,
  beta     = colMeans(perm_fx_dist, na.rm = TRUE),
  se       = apply(perm_fx_dist, 2, sd, na.rm = TRUE),
  ci_lower = apply(perm_fx_dist, 2, quantile, 0.025, na.rm = TRUE),
  ci_upper = apply(perm_fx_dist, 2, quantile, 0.975, na.rm = TRUE),
  type     = "Permutation (Random)"
)

perm_cpi_results <- data.frame(
  horizon  = horizons,
  beta     = colMeans(perm_cpi_dist, na.rm = TRUE),
  se       = apply(perm_cpi_dist, 2, sd, na.rm = TRUE),
  ci_lower = apply(perm_cpi_dist, 2, quantile, 0.025, na.rm = TRUE),
  ci_upper = apply(perm_cpi_dist, 2, quantile, 0.975, na.rm = TRUE),
  type     = "Permutation (Random)"
)

# Actual baseline for reference
actual_fx <- data.frame(
  horizon  = horizons,
  beta     = actual_betas_fx,
  se       = lp_fx_results$se,
  ci_lower = lp_fx_results$ci_lower,
  ci_upper = lp_fx_results$ci_upper,
  type     = "Actual MP Shock"
)

actual_cpi <- data.frame(
  horizon  = horizons,
  beta     = actual_betas_cpi,
  se       = lp_cpi_results$se,
  ci_lower = lp_cpi_results$ci_lower,
  ci_upper = lp_cpi_results$ci_upper,
  type     = "Actual MP Shock"
)

# --------------------------------------------------------------------------
# STEP 4: Plots
# --------------------------------------------------------------------------
all_fx  <- rbind(placebo_fx, perm_fx_results, actual_fx)
all_cpi <- rbind(placebo_cpi, perm_cpi_results, actual_cpi)

p_placebo_fx <- ggplot(all_fx, aes(x = horizon, y = beta, color = type, fill = type)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.12, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c("Actual MP Shock" = "blue",
                                 "Placebo (Fitted Values)" = "grey50",
                                 "Permutation (Random)" = "orange")) +
  scale_fill_manual(values = c("Actual MP Shock" = "blue",
                                "Placebo (Fitted Values)" = "grey50",
                                "Permutation (Random)" = "orange")) +
  labs(title = "Placebo Test: EUR/CHF Impulse Response",
       subtitle = "Actual shock vs placebo (predicted component) vs random permutation",
       x = "Months After Shock", y = "EUR/CHF Change (%) per 1pp Shock",
       color = "Shock Type", fill = "Shock Type") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/placebo_fx.pdf"),
       p_placebo_fx, width = 10, height = 6, dpi = 300)

p_placebo_cpi <- ggplot(all_cpi, aes(x = horizon, y = beta, color = type, fill = type)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.12, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c("Actual MP Shock" = "red",
                                 "Placebo (Fitted Values)" = "grey50",
                                 "Permutation (Random)" = "orange")) +
  scale_fill_manual(values = c("Actual MP Shock" = "red",
                                "Placebo (Fitted Values)" = "grey50",
                                "Permutation (Random)" = "orange")) +
  labs(title = "Placebo Test: CPI Impulse Response",
       subtitle = "Actual shock vs placebo (predicted component) vs random permutation",
       x = "Months After Shock", y = "CPI Change (pp) per 1pp Shock",
       color = "Shock Type", fill = "Shock Type") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/placebo_cpi.pdf"),
       p_placebo_cpi, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 5: Results table
# --------------------------------------------------------------------------
placebo_table <- data.frame(
  Horizon = horizons,
  Actual_FX = sprintf("%.2f", actual_betas_fx),
  Placebo_FX = sprintf("%.2f", placebo_fx$beta),
  Perm_pval_FX = sprintf("%.3f", perm_pval_fx),
  Actual_CPI = sprintf("%.2f", actual_betas_cpi),
  Placebo_CPI = sprintf("%.2f", placebo_cpi$beta),
  Perm_pval_CPI = sprintf("%.3f", perm_pval_cpi)
) %>%
  filter(Horizon %in% c(1, 3, 6, 12))

colnames(placebo_table) <- c("Horizon",
                              "Actual (FX)", "Placebo (FX)", "Perm. p (FX)",
                              "Actual (CPI)", "Placebo (CPI)", "Perm. p (CPI)")

placebo_xtable <- xtable(placebo_table,
                          caption = "Placebo and Permutation Tests: Comparison of Responses",
                          label = "tab:placebo_results",
                          align = c("l", "c", rep("r", 6)))
print(placebo_xtable,
      file = file.path(ext_dir, "output/tables/placebo_results.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

cat("  Extension 4 complete.\n")
