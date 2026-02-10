################################################################################
# EXTENSION 3: WILD BOOTSTRAP CONFIDENCE INTERVALS
# Rademacher wild bootstrap for LP standard errors
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(xtable)
library(ggplot2)

cat("\n=== Extension 3: Wild Bootstrap Confidence Intervals ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "cache/local_projections.RData"))

if (exists("control_formula")) {
  ctrl <- control_formula
} else {
  ctrl <- "cpi_yoy_lag1 + kof_lag1"
}

horizons <- 1:12
B <- 999
set.seed(42)

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
# Wild bootstrap function (Rademacher weights, imposed null H0: beta_shock=0)
# --------------------------------------------------------------------------
wild_bootstrap_lp <- function(data, dep_var, shock_var, ctrl_formula, B = 999) {

  full_formula <- as.formula(paste0(dep_var, " ~ ", shock_var, " + ", ctrl_formula))
  mod <- lm(full_formula, data = data)

  complete_idx <- complete.cases(model.frame(mod))
  data_complete <- data[complete_idx, ]
  n <- nrow(data_complete)

  # Observed t-statistic
  vcov_nw <- NeweyWest(mod, lag = max(1, floor(n^(1/3))), prewhite = FALSE)
  se_obs <- sqrt(diag(vcov_nw))
  beta_obs <- coef(mod)[shock_var]
  se_obs_shock <- se_obs[shock_var]
  t_obs <- beta_obs / se_obs_shock

  # Restricted model (under H0: beta_shock = 0)
  restricted_formula <- as.formula(paste0(dep_var, " ~ ", ctrl_formula))
  mod_r <- lm(restricted_formula, data = data_complete)
  y_fitted_r <- fitted(mod_r)
  resid_r <- residuals(mod_r)

  # Design matrix for full model
  X_full <- model.matrix(full_formula, data = data_complete)
  y_name <- dep_var

  # Bootstrap
  boot_t <- numeric(B)
  for (b in seq_len(B)) {
    # Rademacher weights: +1 or -1 with equal probability
    w <- sample(c(-1, 1), n, replace = TRUE)
    y_boot <- y_fitted_r + resid_r * w

    data_boot <- data_complete
    data_boot[[dep_var]] <- y_boot

    mod_boot <- lm(full_formula, data = data_boot)

    tryCatch({
      vcov_boot <- NeweyWest(mod_boot, lag = max(1, floor(n^(1/3))), prewhite = FALSE)
      se_boot <- sqrt(diag(vcov_boot))
      boot_t[b] <- coef(mod_boot)[shock_var] / se_boot[shock_var]
    }, error = function(e) {
      boot_t[b] <<- NA
    })
  }

  boot_t <- boot_t[!is.na(boot_t)]

  # Symmetric bootstrap p-value
  p_boot <- mean(abs(boot_t) >= abs(t_obs))

  # Bootstrap confidence interval (percentile-t)
  q_lower <- quantile(boot_t, 0.025, na.rm = TRUE)
  q_upper <- quantile(boot_t, 0.975, na.rm = TRUE)
  ci_boot_lower <- beta_obs - q_upper * se_obs_shock
  ci_boot_upper <- beta_obs - q_lower * se_obs_shock

  list(
    beta     = beta_obs,
    se_nw    = se_obs_shock,
    t_obs    = t_obs,
    p_boot   = p_boot,
    ci_nw_lower   = beta_obs - 1.96 * se_obs_shock,
    ci_nw_upper   = beta_obs + 1.96 * se_obs_shock,
    ci_boot_lower = ci_boot_lower,
    ci_boot_upper = ci_boot_upper
  )
}

# --------------------------------------------------------------------------
# Run bootstrap for FX
# --------------------------------------------------------------------------
cat("  Bootstrapping EUR/CHF LPs (B =", B, ")...\n")
boot_fx <- data.frame()
for (h in horizons) {
  cat(sprintf("    Horizon %d/%d\r", h, max(horizons)))
  res <- wild_bootstrap_lp(monthly_full, paste0("fx_change_", h), "mp_shock", ctrl, B)
  boot_fx <- rbind(boot_fx, data.frame(
    horizon       = h,
    beta          = res$beta,
    ci_nw_lower   = res$ci_nw_lower,
    ci_nw_upper   = res$ci_nw_upper,
    ci_boot_lower = res$ci_boot_lower,
    ci_boot_upper = res$ci_boot_upper,
    p_nw          = 2 * pnorm(-abs(res$t_obs)),
    p_boot        = res$p_boot
  ))
}
cat("\n")

# --------------------------------------------------------------------------
# Run bootstrap for CPI
# --------------------------------------------------------------------------
cat("  Bootstrapping CPI LPs (B =", B, ")...\n")
boot_cpi <- data.frame()
for (h in horizons) {
  cat(sprintf("    Horizon %d/%d\r", h, max(horizons)))
  res <- wild_bootstrap_lp(monthly_full, paste0("cpi_change_", h), "mp_shock", ctrl, B)
  boot_cpi <- rbind(boot_cpi, data.frame(
    horizon       = h,
    beta          = res$beta,
    ci_nw_lower   = res$ci_nw_lower,
    ci_nw_upper   = res$ci_nw_upper,
    ci_boot_lower = res$ci_boot_lower,
    ci_boot_upper = res$ci_boot_upper,
    p_nw          = 2 * pnorm(-abs(res$t_obs)),
    p_boot        = res$p_boot
  ))
}
cat("\n")

# --------------------------------------------------------------------------
# FX plot: NW vs Bootstrap CIs
# --------------------------------------------------------------------------
p_boot_fx <- ggplot(boot_fx, aes(x = horizon)) +
  geom_ribbon(aes(ymin = ci_nw_lower, ymax = ci_nw_upper),
              fill = "steelblue", alpha = 0.25) +
  geom_ribbon(aes(ymin = ci_boot_lower, ymax = ci_boot_upper),
              fill = "darkred", alpha = 0.20) +
  geom_line(aes(y = beta), linewidth = 1.2, color = "black") +
  geom_point(aes(y = beta), size = 2.5, color = "black") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf,
           fill = NA, color = NA) +
  labs(title = "EUR/CHF IRF: Newey-West vs Wild Bootstrap Confidence Intervals",
       subtitle = sprintf("Blue band: Newey-West 95%% CI; Red band: Rademacher wild bootstrap 95%% CI (B = %d)", B),
       x = "Months After Shock", y = "EUR/CHF Change (%) per 1pp Shock") +
  theme_minimal(base_size = 12)

ggsave(file.path(ext_dir, "output/figures/irf_bootstrap_fx.pdf"),
       p_boot_fx, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# CPI plot: NW vs Bootstrap CIs
# --------------------------------------------------------------------------
p_boot_cpi <- ggplot(boot_cpi, aes(x = horizon)) +
  geom_ribbon(aes(ymin = ci_nw_lower, ymax = ci_nw_upper),
              fill = "steelblue", alpha = 0.25) +
  geom_ribbon(aes(ymin = ci_boot_lower, ymax = ci_boot_upper),
              fill = "darkred", alpha = 0.20) +
  geom_line(aes(y = beta), linewidth = 1.2, color = "black") +
  geom_point(aes(y = beta), size = 2.5, color = "black") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  labs(title = "CPI IRF: Newey-West vs Wild Bootstrap Confidence Intervals",
       subtitle = sprintf("Blue band: Newey-West 95%% CI; Red band: Rademacher wild bootstrap 95%% CI (B = %d)", B),
       x = "Months After Shock", y = "CPI Change (pp) per 1pp Shock") +
  theme_minimal(base_size = 12)

ggsave(file.path(ext_dir, "output/figures/irf_bootstrap_cpi.pdf"),
       p_boot_cpi, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# Comparison table
# --------------------------------------------------------------------------
boot_table <- boot_fx %>%
  filter(horizon %in% c(1, 3, 6, 12)) %>%
  mutate(
    nw_ci  = sprintf("[%.2f, %.2f]", ci_nw_lower, ci_nw_upper),
    bt_ci  = sprintf("[%.2f, %.2f]", ci_boot_lower, ci_boot_upper),
    p_nw_fmt   = sprintf("%.3f", p_nw),
    p_boot_fmt = sprintf("%.3f", p_boot),
    beta_fmt   = sprintf("%.2f", beta)
  ) %>%
  select(horizon, beta_fmt, nw_ci, p_nw_fmt, bt_ci, p_boot_fmt)

colnames(boot_table) <- c("Horizon", "Coeff.", "NW 95\\% CI", "NW p-val",
                           "Bootstrap 95\\% CI", "Boot. p-val")

boot_xtable <- xtable(boot_table,
                       caption = sprintf("Wild Bootstrap vs Newey-West: EUR/CHF Response (B = %d)", B),
                       label = "tab:bootstrap_comparison",
                       align = c("l", "c", "r", "c", "r", "c", "r"))
print(boot_xtable,
      file = file.path(ext_dir, "output/tables/bootstrap_comparison.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

cat("  Extension 3 complete.\n")
