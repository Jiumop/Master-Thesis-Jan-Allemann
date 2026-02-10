################################################################################
# SNB THESIS - 07: MACHINE LEARNING ANALYSIS
################################################################################

library(tidyverse)
library(grf)
library(ggplot2)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)

load("cache/local_projections.RData")

# ML dataset
ml_data <- monthly_full %>%
  select(delta_log_eur_chf, mp_shock, cpi_yoy_lag1, kof_lag1, vix, yield_2y, regime_negative) %>%
  na.omit()

# Causal Forest
X <- ml_data %>% 
  select(-delta_log_eur_chf, -mp_shock) %>% 
  as.matrix()
Y <- ml_data$delta_log_eur_chf  
W <- ml_data$mp_shock

treatment_variation <- var(W)

if(treatment_variation > 0.001) {
  
  set.seed(42)
  cf <- causal_forest(X = X, Y = Y, W = W, 
                      num.trees = 2000,
                      ci.group.size = 4)
  
  cate <- predict(cf)$predictions
  
  # CATE by regime
  cate_data <- data.frame(
    cate = cate,
    regime = ifelse(ml_data$regime_negative == 1, "Negative", "Positive"),
    vix = ml_data$vix,
    kof = ml_data$kof_lag1
  )
  
  p_cate_regime <- ggplot(cate_data, aes(x = regime, y = cate, fill = regime)) +
    geom_boxplot(alpha = 0.7, outlier.alpha = 0.6) + 
    geom_jitter(width = 0.2, alpha = 0.4, size = 1) +
    scale_fill_manual(values = c("Negative" = "red", "Positive" = "blue")) +
    labs(
      title = "Conditional Average Treatment Effects by Interest Rate Regime",
      subtitle = "Distribution of heterogeneous treatment effects from Causal Forest",
      x = "Interest Rate Regime", 
      y = "Conditional Average Treatment Effect (%)", 
      fill = "Regime"
    ) +
    theme(legend.position = "none")
  
  ggsave("output/figures/cate_by_regime.pdf", p_cate_regime, width = 8, height = 6, dpi = 300)
}

# Out-of-sample validation
set.seed(42)
n_obs <- nrow(ml_data)
train_idx <- sample(1:n_obs, floor(0.8 * n_obs))

train_data <- ml_data[train_idx, ]
test_data <- ml_data[-train_idx, ]

if(nrow(test_data) >= 10) {
  
  lm_model <- lm(delta_log_eur_chf ~ mp_shock + cpi_yoy_lag1 + kof_lag1, 
                 data = train_data)
  pred_lm <- predict(lm_model, newdata = test_data)
  
  if(exists("cf")) {
    X_test <- test_data %>% select(-delta_log_eur_chf, -mp_shock) %>% as.matrix()
    pred_cf <- predict(cf, newdata = X_test)$predictions
    
    actual <- test_data$delta_log_eur_chf
    rmse_lm <- sqrt(mean((actual - pred_lm)^2, na.rm = TRUE))
    
    prediction_results <- data.frame(
      Model = "Linear (Local Projections)",
      RMSE = round(rmse_lm, 3)
    )
    
    pred_comparison <- data.frame(
      Actual = actual,
      Linear = pred_lm
    )
    
    p_prediction <- pred_comparison %>%
      ggplot(aes(x = Linear, y = Actual)) +
      geom_point(alpha = 0.7, size = 2) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red") +
      labs(
        title = "Out-of-Sample Validation: Linear Model Predictions",
        subtitle = "Perfect predictions would lie on the diagonal line",
        x = "Predicted EUR/CHF Change (%)",
        y = "Actual EUR/CHF Change (%)"
      )
    
    ggsave("output/figures/prediction_comparison.pdf", p_prediction, width = 8, height = 6, dpi = 300)
  }
}

ml_results <- list(
  ml_data = ml_data
)

if(exists("cf")) {
  ml_results$causal_forest <- cf
  ml_results$cate_data <- cate_data
}

if(exists("prediction_results")) {
  ml_results$prediction_results <- prediction_results
}

save(ml_results, file = "cache/machine_learning.RData")
