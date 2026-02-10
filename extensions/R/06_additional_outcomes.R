################################################################################
# EXTENSION 6: ADDITIONAL OUTCOME VARIABLES
# LPs for yield_2y, yield_10y, and KOF barometer
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(xtable)
library(ggplot2)
library(gridExtra)

cat("\n=== Extension 6: Additional Outcome Variables ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "cache/local_projections.RData"))

if (exists("control_formula")) {
  ctrl <- control_formula
} else {
  ctrl <- "cpi_yoy_lag1 + kof_lag1"
}

horizons <- 1:12

# --------------------------------------------------------------------------
# STEP 1: Create forward differences for additional outcomes
# --------------------------------------------------------------------------
outcomes <- list(
  list(var = "yield_2y",  label = "2-Year Government Bond Yield",
       unit = "Yield Change (pp)", color = "darkorange"),
  list(var = "yield_10y", label = "10-Year Government Bond Yield",
       unit = "Yield Change (pp)", color = "darkgreen"),
  list(var = "kof",       label = "KOF Economic Barometer",
       unit = "KOF Change (points)", color = "purple")
)

for (out in outcomes) {
  v <- out$var
  for (h in horizons) {
    col_name <- paste0(v, "_change_", h)
    if (!col_name %in% colnames(monthly_full)) {
      monthly_full[[col_name]] <- lead(monthly_full[[v]], h) - monthly_full[[v]]
    }
  }
}

# --------------------------------------------------------------------------
# STEP 2: Run LPs for each additional outcome
# --------------------------------------------------------------------------
all_results <- list()

for (out in outcomes) {
  v <- out$var
  cat(sprintf("  Estimating LPs for %s...\n", out$label))

  results <- data.frame()
  for (h in horizons) {
    dep_var <- paste0(v, "_change_", h)
    formula_h <- as.formula(paste0(dep_var, " ~ mp_shock + ", ctrl))
    model_h <- lm(formula_h, data = monthly_full)

    vcov_h <- NeweyWest(model_h, lag = h, prewhite = FALSE)
    se_h <- sqrt(diag(vcov_h))

    coef_shock <- coef(model_h)["mp_shock"]
    se_shock <- se_h["mp_shock"]

    results <- rbind(results, data.frame(
      horizon  = h,
      beta     = coef_shock,
      se       = se_shock,
      ci_lower = coef_shock - 1.96 * se_shock,
      ci_upper = coef_shock + 1.96 * se_shock,
      t_stat   = coef_shock / se_shock,
      p_value  = 2 * pt(-abs(coef_shock / se_shock),
                        df = nrow(monthly_full) - length(coef(model_h)))
    ))
  }
  all_results[[v]] <- results
}

# --------------------------------------------------------------------------
# STEP 3: Individual IRF plots
# --------------------------------------------------------------------------
for (out in outcomes) {
  v <- out$var
  res <- all_results[[v]]

  p <- ggplot(res, aes(x = horizon, y = beta)) +
    geom_line(linewidth = 1.2, color = out$color) +
    geom_point(size = 3, color = out$color) +
    geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper),
                alpha = 0.2, fill = out$color) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    scale_x_continuous(breaks = 1:12) +
    labs(title = sprintf("Impulse Response: %s", out$label),
         subtitle = "Response to 1pp SNB rate cut shock",
         x = "Months After Shock", y = out$unit) +
    theme_minimal(base_size = 12)

  ggsave(file.path(ext_dir, sprintf("output/figures/irf_%s.pdf", v)),
         p, width = 10, height = 6, dpi = 300)
}

# --------------------------------------------------------------------------
# STEP 4: Multi-panel comparison figure (all outcomes + FX + CPI)
# --------------------------------------------------------------------------
# Load baseline FX and CPI results
fx_panel <- lp_fx_results %>%
  mutate(outcome = "EUR/CHF", unit = "Change (%)")
cpi_panel <- lp_cpi_results %>%
  mutate(outcome = "CPI Inflation", unit = "Change (pp)")

yield2_panel <- all_results[["yield_2y"]] %>%
  mutate(outcome = "2Y Yield", unit = "Change (pp)")
yield10_panel <- all_results[["yield_10y"]] %>%
  mutate(outcome = "10Y Yield", unit = "Change (pp)")
kof_panel <- all_results[["kof"]] %>%
  mutate(outcome = "KOF Barometer", unit = "Change (pts)")

all_panel <- bind_rows(fx_panel, cpi_panel, yield2_panel, yield10_panel, kof_panel) %>%
  mutate(outcome = factor(outcome,
                          levels = c("EUR/CHF", "CPI Inflation", "2Y Yield",
                                     "10Y Yield", "KOF Barometer")))

p_all <- ggplot(all_panel, aes(x = horizon, y = beta)) +
  geom_line(linewidth = 1, color = "steelblue") +
  geom_point(size = 2, color = "steelblue") +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper),
              alpha = 0.2, fill = "steelblue") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = c(1, 3, 6, 9, 12)) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 3) +
  labs(title = "Impulse Responses Across Transmission Channels",
       subtitle = "Response to 1pp SNB rate cut shock with Newey-West 95% CIs",
       x = "Months After Shock", y = "Response") +
  theme_minimal(base_size = 11) +
  theme(strip.text = element_text(face = "bold"))

ggsave(file.path(ext_dir, "output/figures/irf_all_outcomes.pdf"),
       p_all, width = 14, height = 8, dpi = 300)

# --------------------------------------------------------------------------
# STEP 5: Results table
# --------------------------------------------------------------------------
add_stars <- function(beta, se, n = 250) {
  p <- 2 * pt(-abs(beta / se), df = n)
  case_when(
    p < 0.01 ~ "***",
    p < 0.05 ~ "**",
    p < 0.10 ~ "*",
    TRUE ~ ""
  )
}

short_labels <- c("yield_2y" = "2Y Yield", "yield_10y" = "10Y Yield", "kof" = "KOF")

out_table <- data.frame(Horizon = c(1, 3, 6, 12))
for (out in outcomes) {
  v <- out$var
  res <- all_results[[v]] %>% filter(horizon %in% c(1, 3, 6, 12))
  out_table[[short_labels[v]]] <- sprintf("%.3f%s (%.3f)",
                                           res$beta,
                                           add_stars(res$beta, res$se),
                                           res$se)
}

out_xtable <- xtable(out_table,
                      caption = "Additional Outcome Variables: LP Impulse Responses to 1pp Rate Cut",
                      label = "tab:additional_outcomes",
                      align = c("l", "c", rep("r", length(outcomes))))
print(out_xtable,
      file = file.path(ext_dir, "output/tables/additional_outcomes.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

cat("  Extension 6 complete.\n")
