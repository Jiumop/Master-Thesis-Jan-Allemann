################################################################################
# EXTENSION 2: SMOOTH TRANSITION LOCAL PROJECTIONS
# Replace hard regime dummy with logistic transition function
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(xtable)
library(ggplot2)
library(gridExtra)

cat("\n=== Extension 2: Smooth Transition Local Projections ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "cache/local_projections.RData"))

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
# STEP 1: Define logistic transition function
# G(z) = 1 / (1 + exp(gamma * (z - c)))
# G = 1 means "low-rate regime" (negative/zero rates)
# G = 0 means "normal regime" (positive rates)
# --------------------------------------------------------------------------
transition_fn <- function(z, gamma, c_threshold) {
  1 / (1 + exp(gamma * (z - c_threshold)))
}

# --------------------------------------------------------------------------
# STEP 2: Estimate ST-LP for different gamma values
# --------------------------------------------------------------------------
gamma_grid <- c(1, 3, 5, 10)
c_threshold <- 0  # natural threshold: zero interest rate

st_results_fx  <- data.frame()
st_results_cpi <- data.frame()

for (gam in gamma_grid) {
  monthly_full$G_val <- transition_fn(monthly_full$policy_rate, gam, c_threshold)
  monthly_full$shock_low  <- monthly_full$mp_shock * monthly_full$G_val
  monthly_full$shock_high <- monthly_full$mp_shock * (1 - monthly_full$G_val)

  for (h in horizons) {
    # EUR/CHF
    fx_formula <- as.formula(paste0("fx_change_", h, " ~ shock_low + shock_high + ", ctrl))
    fx_mod <- lm(fx_formula, data = monthly_full)
    vcov_fx <- NeweyWest(fx_mod, lag = h, prewhite = FALSE)
    se_fx <- sqrt(diag(vcov_fx))

    st_results_fx <- rbind(st_results_fx, data.frame(
      gamma    = gam,
      horizon  = h,
      beta_low  = coef(fx_mod)["shock_low"],
      se_low    = se_fx["shock_low"],
      beta_high = coef(fx_mod)["shock_high"],
      se_high   = se_fx["shock_high"]
    ))

    # CPI
    cpi_formula <- as.formula(paste0("cpi_change_", h, " ~ shock_low + shock_high + ", ctrl))
    cpi_mod <- lm(cpi_formula, data = monthly_full)
    vcov_cpi <- NeweyWest(cpi_mod, lag = h, prewhite = FALSE)
    se_cpi <- sqrt(diag(vcov_cpi))

    st_results_cpi <- rbind(st_results_cpi, data.frame(
      gamma    = gam,
      horizon  = h,
      beta_low  = coef(cpi_mod)["shock_low"],
      se_low    = se_cpi["shock_low"],
      beta_high = coef(cpi_mod)["shock_high"],
      se_high   = se_cpi["shock_high"]
    ))
  }
}

# --------------------------------------------------------------------------
# STEP 3: Plot transition function
# --------------------------------------------------------------------------
rate_grid <- seq(-1.5, 3, by = 0.01)
trans_df <- expand.grid(rate = rate_grid, gamma = gamma_grid) %>%
  mutate(G = transition_fn(rate, gamma, c_threshold),
         gamma_label = paste0("gamma = ", gamma))

p_transition <- ggplot(trans_df, aes(x = rate, y = G, color = gamma_label)) +
  geom_line(linewidth = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  geom_hline(yintercept = 0.5, linetype = "dotted", alpha = 0.5) +
  scale_color_brewer(palette = "Set1") +
  labs(title = "Logistic Transition Function G(policy rate)",
       subtitle = "G = 1: low-rate regime; G = 0: normal regime; threshold c = 0%",
       x = "Policy Rate (%)", y = "G(policy rate)",
       color = "Smoothness") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/transition_function.pdf"),
       p_transition, width = 8, height = 5, dpi = 300)

# --------------------------------------------------------------------------
# STEP 4: EUR/CHF IRF plot with smooth transition
# --------------------------------------------------------------------------
st_fx_plot <- st_results_fx %>%
  mutate(gamma_label = paste0("gamma = ", gamma))

# Low-rate regime
p_fx_low <- ggplot(st_fx_plot, aes(x = horizon, y = beta_low, color = gamma_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  geom_ribbon(aes(ymin = beta_low - 1.96 * se_low,
                  ymax = beta_low + 1.96 * se_low,
                  fill = gamma_label), alpha = 0.08, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Low-Rate Regime (G ~ 1)",
       x = "Months", y = "EUR/CHF Change (%)",
       color = NULL, fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom")

p_fx_high <- ggplot(st_fx_plot, aes(x = horizon, y = beta_high, color = gamma_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  geom_ribbon(aes(ymin = beta_high - 1.96 * se_high,
                  ymax = beta_high + 1.96 * se_high,
                  fill = gamma_label), alpha = 0.08, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Normal-Rate Regime (G ~ 0)",
       x = "Months", y = "EUR/CHF Change (%)",
       color = NULL, fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom")

p_fx_st <- grid.arrange(p_fx_low, p_fx_high, ncol = 2,
                         top = "Smooth Transition LP: EUR/CHF Response by Regime and Gamma")
ggsave(file.path(ext_dir, "output/figures/irf_smooth_transition_fx.pdf"),
       p_fx_st, width = 12, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 5: CPI IRF plot with smooth transition
# --------------------------------------------------------------------------
st_cpi_plot <- st_results_cpi %>%
  mutate(gamma_label = paste0("gamma = ", gamma))

p_cpi_low <- ggplot(st_cpi_plot, aes(x = horizon, y = beta_low, color = gamma_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  geom_ribbon(aes(ymin = beta_low - 1.96 * se_low,
                  ymax = beta_low + 1.96 * se_low,
                  fill = gamma_label), alpha = 0.08, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Low-Rate Regime (G ~ 1)",
       x = "Months", y = "CPI Change (pp)",
       color = NULL, fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom")

p_cpi_high <- ggplot(st_cpi_plot, aes(x = horizon, y = beta_high, color = gamma_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  geom_ribbon(aes(ymin = beta_high - 1.96 * se_high,
                  ymax = beta_high + 1.96 * se_high,
                  fill = gamma_label), alpha = 0.08, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Normal-Rate Regime (G ~ 0)",
       x = "Months", y = "CPI Change (pp)",
       color = NULL, fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom")

p_cpi_st <- grid.arrange(p_cpi_low, p_cpi_high, ncol = 2,
                          top = "Smooth Transition LP: CPI Response by Regime and Gamma")
ggsave(file.path(ext_dir, "output/figures/irf_smooth_transition_cpi.pdf"),
       p_cpi_st, width = 12, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 6: Results table (gamma = 5 as preferred specification)
# --------------------------------------------------------------------------
preferred_gamma <- 5

st_table <- st_results_fx %>%
  filter(gamma == preferred_gamma, horizon %in% c(1, 3, 6, 12)) %>%
  mutate(
    low_fmt  = sprintf("%.2f (%.2f)", beta_low, se_low),
    high_fmt = sprintf("%.2f (%.2f)", beta_high, se_high),
    diff     = beta_low - beta_high,
    diff_fmt = sprintf("%.2f", diff)
  ) %>%
  select(horizon, low_fmt, high_fmt, diff_fmt)

colnames(st_table) <- c("Horizon", "Low-Rate Regime", "Normal-Rate Regime", "Difference")

st_xtable <- xtable(st_table,
                     caption = sprintf("Smooth Transition LP: EUR/CHF Response (gamma = %d, c = 0\\%%)", preferred_gamma),
                     label = "tab:smooth_transition_results",
                     align = c("l", "c", "r", "r", "r"))
print(st_xtable,
      file = file.path(ext_dir, "output/tables/smooth_transition_results.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

cat("  Extension 2 complete.\n")
