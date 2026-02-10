################################################################################
# ROBUSTNESS CHECK: Control Variable Sensitivity
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(xtable)
library(car)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)
load("cache/shock_identification.RData")
horizons <- c(1, 2, 6, 12)  

for(h in horizons) {
  if(!paste0("fx_change_", h) %in% colnames(monthly_full)) {
    monthly_full[[paste0("fx_change_", h)]] <- 
      (lead(monthly_full$log_eur_chf, h) - monthly_full$log_eur_chf) * 100
  }
  
  if(!paste0("cpi_change_", h) %in% colnames(monthly_full)) {
    monthly_full[[paste0("cpi_change_", h)]] <- 
      lead(monthly_full$cpi_yoy, h) - monthly_full$cpi_yoy
  }
}

################################################################################
# SPECIFICATION 1: NO CONTROLS (Baseline)
################################################################################
results_nocontrol_fx <- data.frame()
results_nocontrol_cpi <- data.frame()

for(h in horizons) {
  model_fx <- lm(as.formula(paste0("fx_change_", h, " ~ mp_shock")), 
                 data = monthly_full)
  vcov_fx <- NeweyWest(model_fx, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))
  
  results_nocontrol_fx <- rbind(results_nocontrol_fx, data.frame(
    horizon = h,
    beta = coef(model_fx)["mp_shock"],
    se = se_fx["mp_shock"],
    p_value = 2 * pt(-abs(coef(model_fx)["mp_shock"] / se_fx["mp_shock"]), 
                     df = nrow(monthly_full) - length(coef(model_fx)))
  ))
  
  model_cpi <- lm(as.formula(paste0("cpi_change_", h, " ~ mp_shock")), 
                  data = monthly_full)
  vcov_cpi <- NeweyWest(model_cpi, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))
  
  results_nocontrol_cpi <- rbind(results_nocontrol_cpi, data.frame(
    horizon = h,
    beta = coef(model_cpi)["mp_shock"],
    se = se_cpi["mp_shock"],
    p_value = 2 * pt(-abs(coef(model_cpi)["mp_shock"] / se_cpi["mp_shock"]), 
                     df = nrow(monthly_full) - length(coef(model_cpi)))
  ))
}

################################################################################
# SPECIFICATION 2: LAGGED CONTROLS ONLY (Conservative)
################################################################################
control_lagged <- "kof_lag1 + cpi_yoy_lag1"

results_lagged_fx <- data.frame()
results_lagged_cpi <- data.frame()

for(h in horizons) {
  formula_fx <- as.formula(paste0("fx_change_", h, " ~ mp_shock + ", control_lagged))
  model_fx <- lm(formula_fx, data = monthly_full)
  vcov_fx <- NeweyWest(model_fx, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))
  
  results_lagged_fx <- rbind(results_lagged_fx, data.frame(
    horizon = h,
    beta = coef(model_fx)["mp_shock"],
    se = se_fx["mp_shock"],
    p_value = 2 * pt(-abs(coef(model_fx)["mp_shock"] / se_fx["mp_shock"]), 
                     df = nrow(monthly_full) - length(coef(model_fx)))
  ))
  
  formula_cpi <- as.formula(paste0("cpi_change_", h, " ~ mp_shock + ", control_lagged))
  model_cpi <- lm(formula_cpi, data = monthly_full)
  vcov_cpi <- NeweyWest(model_cpi, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))
  
  results_lagged_cpi <- rbind(results_lagged_cpi, data.frame(
    horizon = h,
    beta = coef(model_cpi)["mp_shock"],
    se = se_cpi["mp_shock"],
    p_value = 2 * pt(-abs(coef(model_cpi)["mp_shock"] / se_cpi["mp_shock"]), 
                     df = nrow(monthly_full) - length(coef(model_cpi)))
  ))
}

################################################################################
# SPECIFICATION 3: FULL CONTROLS
################################################################################
load("cache/local_projections.RData")

results_full_fx <- lp_fx_results %>% filter(horizon %in% horizons)
results_full_cpi <- lp_cpi_results %>% filter(horizon %in% horizons)

################################################################################
# REGIME COMPARISON ROBUSTNESS: LAGGED CONTROLS ONLY
################################################################################
regime_lagged_fx <- data.frame()
regime_lagged_cpi <- data.frame()

for(h in horizons) {
  formula_fx <- as.formula(paste0("fx_change_", h, 
                                  " ~ shock_positive + shock_negative + ", control_lagged))
  model_fx <- lm(formula_fx, data = monthly_full)
  vcov_fx <- NeweyWest(model_fx, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))
  wald_fx <- linearHypothesis(model_fx, "shock_positive = shock_negative", 
                              vcov. = vcov_fx)
  
  regime_lagged_fx <- rbind(regime_lagged_fx, data.frame(
    horizon = h,
    beta_pos = coef(model_fx)["shock_positive"],
    se_pos = se_fx["shock_positive"],
    beta_neg = coef(model_fx)["shock_negative"],
    se_neg = se_fx["shock_negative"],
    wald_f = wald_fx$F[2],
    wald_p = wald_fx$`Pr(>F)`[2]
  ))
  
  formula_cpi <- as.formula(paste0("cpi_change_", h, 
                                   " ~ shock_positive + shock_negative + ", control_lagged))
  model_cpi <- lm(formula_cpi, data = monthly_full)
  vcov_cpi <- NeweyWest(model_cpi, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))
  
  wald_cpi <- linearHypothesis(model_cpi, "shock_positive = shock_negative", 
                               vcov. = vcov_cpi)
  
  regime_lagged_cpi <- rbind(regime_lagged_cpi, data.frame(
    horizon = h,
    beta_pos = coef(model_cpi)["shock_positive"],
    se_pos = se_cpi["shock_positive"],
    beta_neg = coef(model_cpi)["shock_negative"],
    se_neg = se_cpi["shock_negative"],
    wald_f = wald_cpi$F[2],
    wald_p = wald_cpi$`Pr(>F)`[2]
  ))
}

################################################################################
# REGIME RESULTS WITH FULL CONTROLS (for comparison)
################################################################################

load("cache/regime_analysis.RData")

regime_full_fx <- regime_fx_results %>% filter(horizon %in% horizons)
regime_full_cpi <- regime_cpi_results %>% filter(horizon %in% horizons)

################################################################################
# COMPARISON TABLES
################################################################################
comparison_fx <- data.frame(
  Horizon = horizons,
  
  No_Controls = sprintf("%.2f (%.2f)%s", 
                        results_nocontrol_fx$beta,
                        results_nocontrol_fx$se,
                        ifelse(results_nocontrol_fx$p_value < 0.01, "***",
                               ifelse(results_nocontrol_fx$p_value < 0.05, "**",
                                      ifelse(results_nocontrol_fx$p_value < 0.10, "*", "")))),
  
  Lagged_Only = sprintf("%.2f (%.2f)%s", 
                        results_lagged_fx$beta,
                        results_lagged_fx$se,
                        ifelse(results_lagged_fx$p_value < 0.01, "***",
                               ifelse(results_lagged_fx$p_value < 0.05, "**",
                                      ifelse(results_lagged_fx$p_value < 0.10, "*", "")))),
  
  Full_Controls = sprintf("%.2f (%.2f)%s", 
                          results_full_fx$beta,
                          results_full_fx$se,
                          ifelse(results_full_fx$p_value < 0.01, "***",
                                 ifelse(results_full_fx$p_value < 0.05, "**",
                                        ifelse(results_full_fx$p_value < 0.10, "*", ""))))
)

print(comparison_fx)


comparison_cpi <- data.frame(
  Horizon = horizons,
  
  No_Controls = sprintf("%.2f (%.2f)%s", 
                        results_nocontrol_cpi$beta,
                        results_nocontrol_cpi$se,
                        ifelse(results_nocontrol_cpi$p_value < 0.01, "***",
                               ifelse(results_nocontrol_cpi$p_value < 0.05, "**",
                                      ifelse(results_nocontrol_cpi$p_value < 0.10, "*", "")))),
  
  Lagged_Only = sprintf("%.2f (%.2f)%s", 
                        results_lagged_cpi$beta,
                        results_lagged_cpi$se,
                        ifelse(results_lagged_cpi$p_value < 0.01, "***",
                               ifelse(results_lagged_cpi$p_value < 0.05, "**",
                                      ifelse(results_lagged_cpi$p_value < 0.10, "*", "")))),
  
  Full_Controls = sprintf("%.2f (%.2f)%s", 
                          results_full_cpi$beta,
                          results_full_cpi$se,
                          ifelse(results_full_cpi$p_value < 0.01, "***",
                                 ifelse(results_full_cpi$p_value < 0.05, "**",
                                        ifelse(results_full_cpi$p_value < 0.10, "*", ""))))
)

print(comparison_cpi)


print(regime_lagged_cpi %>% 
        select(horizon, beta_pos, se_pos, beta_neg, se_neg, wald_f, wald_p))
print(regime_full_cpi %>% 
        select(horizon, beta_pos, se_pos, beta_neg, se_neg, wald_f, wald_p))


################################################################################
#TABLES FOR APPENDIX
################################################################################

# EUR/CHF comparison
print(xtable(comparison_fx, 
             caption = "Robustness Check: EUR/CHF Response Across Control Specifications", 
             label = "tab:robust_controls_fx",
             align = c("l", "c", "l", "l", "l")),
      file = "output/tables/robustness_fx.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

# CPI comparison
print(xtable(comparison_cpi, 
             caption = "Robustness Check: CPI Inflation Response Across Control Specifications", 
             label = "tab:robust_controls_cpi",
             align = c("l", "c", "l", "l", "l")),
      file = "output/tables/robustness_cpi.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

# Regime comparison with lagged controls only
regime_lagged_cpi_table <- regime_lagged_cpi %>%
  mutate(
    pos_fmt = sprintf("%.2f (%.2f)%s", beta_pos, se_pos,
                      ifelse(2*pt(-abs(beta_pos/se_pos), df=250) < 0.01, "***",
                             ifelse(2*pt(-abs(beta_pos/se_pos), df=250) < 0.05, "**",
                                    ifelse(2*pt(-abs(beta_pos/se_pos), df=250) < 0.10, "*", "")))),
    neg_fmt = sprintf("%.2f (%.2f)%s", beta_neg, se_neg,
                      ifelse(2*pt(-abs(beta_neg/se_neg), df=250) < 0.01, "***",
                             ifelse(2*pt(-abs(beta_neg/se_neg), df=250) < 0.05, "**",
                                    ifelse(2*pt(-abs(beta_neg/se_neg), df=250) < 0.10, "*", "")))),
    wald_fmt = sprintf("%.2f (%.3f)%s", wald_f, wald_p,
                       ifelse(wald_p < 0.01, "***",
                              ifelse(wald_p < 0.05, "**",
                                     ifelse(wald_p < 0.10, "*", ""))))
  ) %>%
  select(horizon, pos_fmt, neg_fmt, wald_fmt)

colnames(regime_lagged_cpi_table) <- c("Horizon", "Positive Regime", 
                                       "Negative Regime", "Wald Test (F, p)")

print(xtable(regime_lagged_cpi_table, 
             caption = "Robustness Check: CPI Regime Comparison with Lagged Controls Only", 
             label = "tab:robust_regime_cpi",
             align = c("l", "c", "l", "l", "l")),
      file = "output/tables/robustness_regime_cpi.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

save(results_nocontrol_fx, results_nocontrol_cpi,
     results_lagged_fx, results_lagged_cpi,
     regime_lagged_fx, regime_lagged_cpi,
     comparison_fx, comparison_cpi,
     file = "cache/robustness_controls.RData")