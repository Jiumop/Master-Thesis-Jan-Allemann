################################################################################
# SNB THESIS - 03: SHOCK IDENTIFICATION
################################################################################

library(tidyverse)
library(lmtest)
library(sandwich)
library(stargazer)
library(ggplot2)
library(ranger)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)

load("cache/prepared_data.RData")

# STEP 1: VARIABLE IMPORTANCE ANALYSIS FOR CONTROL SELECTION
ml_data_selection <- monthly %>%
  select(delta_log_eur_chf, delta_policy_rate, cpi_yoy_lag1, kof_lag1, vix, yield_2y, regime_negative) %>%
  na.omit()

if(nrow(ml_data_selection) > 50) {
  
  set.seed(42)
  rf_selection <- ranger(delta_log_eur_chf ~ delta_policy_rate + cpi_yoy_lag1 + kof_lag1 + vix + yield_2y + regime_negative, 
                         data = ml_data_selection, 
                         importance = "impurity", 
                         num.trees = 1000, 
                         mtry = 3)
  
  importance_df <- data.frame(
    variable = names(rf_selection$variable.importance),
    importance = rf_selection$variable.importance
  ) %>%
    arrange(desc(importance)) %>%
    mutate(
      variable_label = case_when(
        variable == "delta_policy_rate" ~ "Policy Rate Change",
        variable == "cpi_yoy_lag1" ~ "CPI (t-1)",
        variable == "kof_lag1" ~ "KOF (t-1)", 
        variable == "vix" ~ "VIX",
        variable == "yield_2y" ~ "2Y Yield",
        variable == "regime_negative" ~ "Negative Regime",
        TRUE ~ variable
      )
    )
  
  p_rf_importance <- ggplot(importance_df, aes(x = reorder(variable_label, importance), y = importance)) +
    geom_bar(stat = "identity", fill = "steelblue", alpha = 0.8) + 
    coord_flip() +
    labs(title = "Variable Importance for Control Variable Selection",
         subtitle = "Random Forest importance guides purging regression and local projections",
         x = NULL, y = "Importance (Gini Index)")
  
  ggsave("output/figures/variable_importance_selection.pdf", p_rf_importance, width = 8, height = 6, dpi = 300)
  
  # Select control variables (top 4)
  control_vars <- importance_df %>%
    filter(!variable %in% c("mp_shock", "regime_negative")) %>%
    arrange(desc(importance)) %>%
    slice(1:4) %>%
    pull(variable)
  
  control_formula <- paste(control_vars, collapse = " + ")
  
} else {
  control_vars <- c("cpi_yoy_lag1", "kof_lag1")
  control_formula <- "cpi_yoy_lag1 + kof_lag1"
}

# STEP 2: PURGING REGRESSION WITH SELECTED CONTROLS
monthly_cuts <- monthly %>%
  filter(abs(delta_policy_rate) > 0.001 & delta_policy_rate < 0) %>%
  filter(!is.na(delta_policy_rate) & !is.na(cpi_yoy_lag1) & !is.na(kof_lag1))

if(nrow(monthly_cuts) < 10) {
  monthly_cuts <- monthly %>%
    filter(abs(delta_policy_rate) > 0.001) %>%
    filter(!is.na(delta_policy_rate) & !is.na(cpi_yoy_lag1) & !is.na(kof_lag1))
}

purge_formula <- as.formula(paste0("delta_policy_rate ~ ", control_formula))
purge_main <- lm(purge_formula, data = monthly_cuts)

# STEP 3: MONETARY POLICY SHOCKS
monthly_cuts$mp_shock <- residuals(purge_main)

rate_cuts <- rate_cuts %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  left_join(
    monthly_cuts %>% 
      mutate(year_month = format(date, "%Y-%m")) %>% 
      select(year_month, mp_shock), 
    by = "year_month"
  )

#full monthly dataset with shocks
monthly_full <- monthly %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  left_join(
    monthly_cuts %>% 
      mutate(year_month = format(date, "%Y-%m")) %>% 
      select(year_month, mp_shock), 
    by = "year_month"
  ) %>%
  mutate(
    mp_shock = ifelse(is.na(mp_shock), 0, mp_shock),
    shock_positive = mp_shock * regime_positive,
    shock_negative = mp_shock * regime_negative
  )

#purging regression table
stargazer(purge_main, 
          se = list(sqrt(diag(vcovHC(purge_main, type = "HC1")))),
          title = "Enhanced Purging Regression with Data-Driven Controls",
          label = "tab:purging_regression",
          dep.var.labels = "Policy Rate Change (pp)",
          out = "output/tables/purging_regression.tex",
          table.placement = "H",
          header = FALSE,
          omit.stat = c("f", "ser"))

save(monthly_full, purge_main, rate_cuts, monthly_cuts, importance_df, control_vars, control_formula,
     file = "cache/shock_identification.RData")