################################################################################
# SNB THESIS - 05: LOCAL PROJECTIONS
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest) 
library(xtable)
library(ggplot2)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)

load("cache/shock_identification.RData")

# control formula based on variable importance
if(exists("control_vars")) {
  control_formula <- paste(control_vars, collapse = " + ")
} else {
  control_formula <- "cpi_yoy_lag1 + kof_lag1"
}

#forward differences
horizons <- 1:12

for(h in horizons) {
  monthly_full[[paste0("fx_change_", h)]] <- 
    (lead(monthly_full$log_eur_chf, h) - monthly_full$log_eur_chf) * 100
  
  monthly_full[[paste0("cpi_change_", h)]] <- 
    lead(monthly_full$cpi_yoy, h) - monthly_full$cpi_yoy
}

# EUR/CHF local projections
lp_fx_results <- data.frame()

for(h in horizons) {
  formula_h <- as.formula(paste0("fx_change_", h, " ~ mp_shock + ", control_formula))
  model_h <- lm(formula_h, data = monthly_full)
  
  vcov_h <- NeweyWest(model_h, lag = h, prewhite = FALSE)
  se_h <- sqrt(diag(vcov_h))
  
  coef_shock <- coef(model_h)["mp_shock"]
  se_shock <- se_h["mp_shock"]
  
  lp_fx_results <- rbind(lp_fx_results, data.frame(
    horizon = h,
    beta = coef_shock,
    se = se_shock,
    ci_lower = coef_shock - 1.96 * se_shock,
    ci_upper = coef_shock + 1.96 * se_shock,
    t_stat = coef_shock / se_shock,
    p_value = 2 * pt(-abs(coef_shock / se_shock), 
                     df = nrow(monthly_full) - length(coef(model_h)))
  ))
}

# CPI local projections
lp_cpi_results <- data.frame()

for(h in horizons) {
  formula_h <- as.formula(paste0("cpi_change_", h, " ~ mp_shock + ", control_formula))
  model_h <- lm(formula_h, data = monthly_full)
  
  vcov_h <- NeweyWest(model_h, lag = h, prewhite = FALSE)
  se_h <- sqrt(diag(vcov_h))
  
  coef_shock <- coef(model_h)["mp_shock"]
  se_shock <- se_h["mp_shock"]
  
  lp_cpi_results <- rbind(lp_cpi_results, data.frame(
    horizon = h,
    beta = coef_shock,
    se = se_shock,
    ci_lower = coef_shock - 1.96 * se_shock,
    ci_upper = coef_shock + 1.96 * se_shock,
    t_stat = coef_shock / se_shock,
    p_value = 2 * pt(-abs(coef_shock / se_shock), 
                     df = nrow(monthly_full) - length(coef(model_h)))
  ))
}

# EUR/CHF IRF plot
p_fx_irf <- ggplot(lp_fx_results, aes(x = horizon, y = beta)) +
  geom_line(linewidth = 1.2, color = "blue") + 
  geom_point(size = 3, color = "blue") +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, fill = "blue") +
  geom_hline(yintercept = 0, linetype = "dashed") + 
  scale_x_continuous(breaks = 1:12) +
  labs(
    title = "Local Projections: EUR/CHF Impulse Response Function",
    subtitle = "Response to 1pp SNB rate cut shock with data-driven controls",
    x = "Months After Shock", 
    y = "EUR/CHF Change (%) per 1pp Shock", 
    caption = "Controls selected via Random Forest importance analysis"
  )

ggsave("output/figures/irf_eur_chf.pdf", p_fx_irf, width = 10, height = 6, dpi = 300)

# CPI IRF plot
p_cpi_irf <- ggplot(lp_cpi_results, aes(x = horizon, y = beta)) +
  geom_line(linewidth = 1.2, color = "red") + 
  geom_point(size = 3, color = "red") +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, fill = "red") +
  geom_hline(yintercept = 0, linetype = "dashed") + 
  scale_x_continuous(breaks = 1:12) +
  labs(
    title = "Local Projections: CPI Inflation Impulse Response Function",
    subtitle = "Response to 1pp SNB rate cut shock with data-driven controls",
    x = "Months After Shock", 
    y = "CPI Change (pp) per 1pp Shock", 
    caption = "Controls selected via Random Forest importance analysis"
  )

ggsave("output/figures/irf_cpi.pdf", p_cpi_irf, width = 10, height = 6, dpi = 300)

# Tables for key horizons
irf_fx_table <- lp_fx_results %>%
  filter(horizon %in% c(1, 2, 6, 12)) %>%
  mutate(
    coef_fmt = sprintf("%.2f", beta),
    se_fmt = sprintf("(%.2f)", se),
    ci_fmt = sprintf("[%.2f, %.2f]", ci_lower, ci_upper),
    t_fmt = sprintf("%.2f", t_stat),
    p_fmt = sprintf("%.3f", p_value),
    sig = case_when(
      p_value < 0.01 ~ "***",
      p_value < 0.05 ~ "**", 
      p_value < 0.10 ~ "*", 
      TRUE ~ ""
    ),
    coef_final = paste0(coef_fmt, sig)
  ) %>%
  select(horizon, coef_final, se_fmt, ci_fmt, t_fmt, p_fmt)

colnames(irf_fx_table) <- c("Horizon", "Coefficient", "Std. Error", "95\\% CI", "t-statistic", "p-value")

print(xtable(irf_fx_table, 
             caption = "Local Projections: EUR/CHF Response to 1pp Rate Cut Shock (Data-Driven Controls)", 
             label = "tab:lp_fx",
             align = c("l", "c", "r", "r", "c", "r", "r")),
      file = "output/tables/lp_fx.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

irf_cpi_table <- lp_cpi_results %>%
  filter(horizon %in% c(1, 2, 6, 12)) %>%
  mutate(
    coef_fmt = sprintf("%.2f", beta),
    se_fmt = sprintf("(%.2f)", se),
    ci_fmt = sprintf("[%.2f, %.2f]", ci_lower, ci_upper),
    t_fmt = sprintf("%.2f", t_stat),
    p_fmt = sprintf("%.3f", p_value),
    sig = case_when(
      p_value < 0.01 ~ "***",
      p_value < 0.05 ~ "**", 
      p_value < 0.10 ~ "*", 
      TRUE ~ ""
    ),
    coef_final = paste0(coef_fmt, sig)
  ) %>%
  select(horizon, coef_final, se_fmt, ci_fmt, t_fmt, p_fmt)

colnames(irf_cpi_table) <- c("Horizon", "Coefficient", "Std. Error", "95\\% CI", "t-statistic", "p-value")

print(xtable(irf_cpi_table, 
             caption = "Local Projections: CPI Inflation Response to 1pp Rate Cut Shock (Data-Driven Controls)", 
             label = "tab:lp_cpi",
             align = c("l", "c", "r", "r", "c", "r", "r")),
      file = "output/tables/lp_cpi.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

save(lp_fx_results, lp_cpi_results, monthly_full, file = "cache/local_projections.RData")
