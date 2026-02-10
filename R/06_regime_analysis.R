################################################################################
# SNB THESIS - 06: REGIME ANALYSIS
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(car)
library(xtable)
library(ggplot2)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)

load("cache/local_projections.RData")

#local projections
if(exists("control_formula")) {
  enhanced_controls <- control_formula
} else {
  enhanced_controls <- "cpi_yoy_lag1 + kof_lag1"
}

# Key horizons for regime analysis
key_horizons <- c(1, 2, 6, 12)

# EUR/CHF regime analysis
regime_fx_results <- data.frame()

for(h in key_horizons) {
  formula_fx <- as.formula(paste0("fx_change_", h, " ~ shock_positive + shock_negative + ", enhanced_controls))
  model_fx <- lm(formula_fx, data = monthly_full)
  
  vcov_fx <- NeweyWest(model_fx, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))
  
  wald_test_fx <- linearHypothesis(model_fx, "shock_positive = shock_negative", vcov. = vcov_fx)
  
  regime_fx_results <- rbind(regime_fx_results, data.frame(
    horizon = h,
    beta_pos = coef(model_fx)["shock_positive"],
    se_pos = se_fx["shock_positive"],
    beta_neg = coef(model_fx)["shock_negative"],
    se_neg = se_fx["shock_negative"],
    wald_f = wald_test_fx$F[2],
    wald_p = wald_test_fx$`Pr(>F)`[2]
  ))
}

# CPI regime analysis
regime_cpi_results <- data.frame()

for(h in key_horizons) {
  formula_cpi <- as.formula(paste0("cpi_change_", h, " ~ shock_positive + shock_negative + ", enhanced_controls))
  model_cpi <- lm(formula_cpi, data = monthly_full)
  
  vcov_cpi <- NeweyWest(model_cpi, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))
  
  wald_test_cpi <- linearHypothesis(model_cpi, "shock_positive = shock_negative", vcov. = vcov_cpi)
  
  regime_cpi_results <- rbind(regime_cpi_results, data.frame(
    horizon = h,
    beta_pos = coef(model_cpi)["shock_positive"],
    se_pos = se_cpi["shock_positive"],
    beta_neg = coef(model_cpi)["shock_negative"],
    se_neg = se_cpi["shock_negative"],
    wald_f = wald_test_cpi$F[2],
    wald_p = wald_test_cpi$`Pr(>F)`[2]
  ))
}

# EUR/CHF regime comparison plot
fx_regime_long <- regime_fx_results %>%
  select(horizon, beta_pos, beta_neg, se_pos, se_neg) %>%
  pivot_longer(cols = c(beta_pos, beta_neg), names_to = "regime", values_to = "beta") %>%
  mutate(
    se = ifelse(regime == "beta_pos", 
                regime_fx_results$se_pos[match(horizon, regime_fx_results$horizon)], 
                regime_fx_results$se_neg[match(horizon, regime_fx_results$horizon)]),
    regime_label = ifelse(regime == "beta_pos", "Positive Rate Regime", "Negative Rate Regime"),
    ci_lower = beta - 1.96 * se, 
    ci_upper = beta + 1.96 * se
  )

p_fx_regime <- ggplot(fx_regime_long, aes(x = horizon, y = beta, color = regime_label, fill = regime_label)) +
  geom_line(linewidth = 1.2) + 
  geom_point(size = 3) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_color_manual(values = c("Positive Rate Regime" = "blue", "Negative Rate Regime" = "red")) +
  scale_fill_manual(values = c("Positive Rate Regime" = "blue", "Negative Rate Regime" = "red")) +
  scale_x_continuous(breaks = key_horizons) +
  labs(
    title = "Regime Comparison: EUR/CHF Impulse Responses by Interest Rate Regime",
    subtitle = "Local projections showing transmission differences across regimes",
    x = "Months After Shock", 
    y = "EUR/CHF Change (%) per 1pp Shock", 
    color = "Regime", fill = "Regime"
  ) +
  theme(legend.position = "bottom")

ggsave("output/figures/irf_eur_chf_regime.pdf", p_fx_regime, width = 10, height = 6, dpi = 300)

# CPI regime comparison plot  
cpi_regime_long <- regime_cpi_results %>%
  select(horizon, beta_pos, beta_neg, se_pos, se_neg) %>%
  pivot_longer(cols = c(beta_pos, beta_neg), names_to = "regime", values_to = "beta") %>%
  mutate(
    se = ifelse(regime == "beta_pos", 
                regime_cpi_results$se_pos[match(horizon, regime_cpi_results$horizon)], 
                regime_cpi_results$se_neg[match(horizon, regime_cpi_results$horizon)]),
    regime_label = ifelse(regime == "beta_pos", "Positive Rate Regime", "Negative Rate Regime"),
    ci_lower = beta - 1.96 * se, 
    ci_upper = beta + 1.96 * se
  )

p_cpi_regime <- ggplot(cpi_regime_long, aes(x = horizon, y = beta, color = regime_label, fill = regime_label)) +
  geom_line(linewidth = 1.2) + 
  geom_point(size = 3) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_color_manual(values = c("Positive Rate Regime" = "blue", "Negative Rate Regime" = "red")) +
  scale_fill_manual(values = c("Positive Rate Regime" = "blue", "Negative Rate Regime" = "red")) +
  scale_x_continuous(breaks = key_horizons) +
  labs(
    title = "Regime Comparison: CPI Inflation Impulse Responses by Interest Rate Regime",
    subtitle = "Local projections showing transmission differences across regimes",
    x = "Months After Shock", 
    y = "CPI Change (pp) per 1pp Shock", 
    color = "Regime", fill = "Regime"
  ) +
  theme(legend.position = "bottom")

ggsave("output/figures/irf_cpi_regime.pdf", p_cpi_regime, width = 10, height = 6, dpi = 300)

# Regime comparison tables
add_stars <- function(coef, se) {
  p_val <- 2 * pt(-abs(coef/se), df = 250)
  case_when(
    p_val < 0.01 ~ "***",
    p_val < 0.05 ~ "**", 
    p_val < 0.10 ~ "*", 
    TRUE ~ ""
  )
}

# EUR/CHF regime table
regime_fx_table <- regime_fx_results %>%
  mutate(
    pos_fmt = paste0(sprintf("%.2f", beta_pos), add_stars(beta_pos, se_pos)),
    neg_fmt = paste0(sprintf("%.2f", beta_neg), add_stars(beta_neg, se_neg)),
    pos_se = sprintf("(%.2f)", se_pos),
    neg_se = sprintf("(%.2f)", se_neg),
    wald_fmt = sprintf("%.2f", wald_f),
    wald_p_fmt = sprintf("%.3f", wald_p)
  ) %>%
  select(horizon, pos_fmt, pos_se, neg_fmt, neg_se, wald_fmt, wald_p_fmt)

colnames(regime_fx_table) <- c("Horizon", "Positive", "SE", "Negative", "SE", "Wald F", "p-value")

print(xtable(regime_fx_table, 
             caption = "Regime Comparison: EUR/CHF Response (Positive vs Negative Rates)", 
             label = "tab:lp_fx_regime",
             align = c("l", "c", "r", "r", "r", "r", "r", "r")),
      file = "output/tables/lp_fx_regime.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

# CPI regime table
regime_cpi_table <- regime_cpi_results %>%
  mutate(
    pos_fmt = paste0(sprintf("%.2f", beta_pos), add_stars(beta_pos, se_pos)),
    neg_fmt = paste0(sprintf("%.2f", beta_neg), add_stars(beta_neg, se_neg)),
    pos_se = sprintf("(%.2f)", se_pos),
    neg_se = sprintf("(%.2f)", se_neg),
    wald_fmt = sprintf("%.2f", wald_f),
    wald_p_fmt = sprintf("%.3f", wald_p)
  ) %>%
  select(horizon, pos_fmt, pos_se, neg_fmt, neg_se, wald_fmt, wald_p_fmt)

colnames(regime_cpi_table) <- c("Horizon", "Positive", "SE", "Negative", "SE", "Wald F", "p-value")

print(xtable(regime_cpi_table, 
             caption = "Regime Comparison: CPI Inflation Response (Positive vs Negative Rates)", 
             label = "tab:lp_cpi_regime",
             align = c("l", "c", "r", "r", "r", "r", "r", "r")),
      file = "output/tables/lp_cpi_regime.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

save(regime_fx_results, regime_cpi_results, fx_regime_long, cpi_regime_long,
     file = "cache/regime_analysis.RData")
