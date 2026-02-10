################################################################################
# EXTENSION 7: SIZE & SIGN ASYMMETRY TESTS
# Test whether transmission depends on shock magnitude or direction
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(car)
library(quantreg)
library(xtable)
library(ggplot2)
library(gridExtra)

cat("\n=== Extension 7: Size & Sign Asymmetry Tests ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "cache/local_projections.RData"))

if (exists("control_formula")) {
  ctrl <- control_formula
} else {
  ctrl <- "cpi_yoy_lag1 + kof_lag1"
}

horizons <- 1:12

# Ensure forward differences
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
# STEP 1: Sign asymmetry — split into easing vs tightening
# --------------------------------------------------------------------------
monthly_full <- monthly_full %>%
  mutate(
    shock_cut  = ifelse(mp_shock < 0, mp_shock, 0),   # easing (negative = rate cut)
    shock_hike = ifelse(mp_shock > 0, mp_shock, 0)    # tightening (positive = rate hike)
  )

sign_fx_results  <- data.frame()
sign_cpi_results <- data.frame()
sign_wald_fx     <- data.frame()
sign_wald_cpi    <- data.frame()

for (h in horizons) {
  # EUR/CHF
  fx_f <- as.formula(paste0("fx_change_", h, " ~ shock_cut + shock_hike + ", ctrl))
  fx_m <- lm(fx_f, data = monthly_full)
  vcov_fx <- NeweyWest(fx_m, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))

  # Wald test: H0: beta_cut = beta_hike
  wald_fx <- linearHypothesis(fx_m, "shock_cut = shock_hike", vcov. = vcov_fx)

  sign_fx_results <- rbind(sign_fx_results, data.frame(
    horizon   = h,
    beta_cut  = coef(fx_m)["shock_cut"],
    se_cut    = se_fx["shock_cut"],
    beta_hike = coef(fx_m)["shock_hike"],
    se_hike   = se_fx["shock_hike"]
  ))

  sign_wald_fx <- rbind(sign_wald_fx, data.frame(
    horizon = h,
    wald_f  = wald_fx$F[2],
    wald_p  = wald_fx$`Pr(>F)`[2]
  ))

  # CPI
  cpi_f <- as.formula(paste0("cpi_change_", h, " ~ shock_cut + shock_hike + ", ctrl))
  cpi_m <- lm(cpi_f, data = monthly_full)
  vcov_cpi <- NeweyWest(cpi_m, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))

  wald_cpi <- linearHypothesis(cpi_m, "shock_cut = shock_hike", vcov. = vcov_cpi)

  sign_cpi_results <- rbind(sign_cpi_results, data.frame(
    horizon   = h,
    beta_cut  = coef(cpi_m)["shock_cut"],
    se_cut    = se_cpi["shock_cut"],
    beta_hike = coef(cpi_m)["shock_hike"],
    se_hike   = se_cpi["shock_hike"]
  ))

  sign_wald_cpi <- rbind(sign_wald_cpi, data.frame(
    horizon = h,
    wald_f  = wald_cpi$F[2],
    wald_p  = wald_cpi$`Pr(>F)`[2]
  ))
}

# --------------------------------------------------------------------------
# STEP 2: Size asymmetry — large vs small shocks
# --------------------------------------------------------------------------
shock_median <- median(abs(monthly_full$mp_shock[monthly_full$mp_shock != 0]), na.rm = TRUE)
cat(sprintf("  Median absolute nonzero shock: %.4f\n", shock_median))

monthly_full <- monthly_full %>%
  mutate(
    is_large = abs(mp_shock) > shock_median & mp_shock != 0,
    shock_large = ifelse(is_large, mp_shock, 0),
    shock_small = ifelse(!is_large & mp_shock != 0, mp_shock, 0)
  )

size_fx_results  <- data.frame()
size_cpi_results <- data.frame()
size_wald_fx     <- data.frame()
size_wald_cpi    <- data.frame()

for (h in horizons) {
  # EUR/CHF
  fx_f <- as.formula(paste0("fx_change_", h, " ~ shock_large + shock_small + ", ctrl))
  fx_m <- lm(fx_f, data = monthly_full)
  vcov_fx <- NeweyWest(fx_m, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))

  wald_fx <- linearHypothesis(fx_m, "shock_large = shock_small", vcov. = vcov_fx)

  size_fx_results <- rbind(size_fx_results, data.frame(
    horizon    = h,
    beta_large = coef(fx_m)["shock_large"],
    se_large   = se_fx["shock_large"],
    beta_small = coef(fx_m)["shock_small"],
    se_small   = se_fx["shock_small"]
  ))

  size_wald_fx <- rbind(size_wald_fx, data.frame(
    horizon = h,
    wald_f  = wald_fx$F[2],
    wald_p  = wald_fx$`Pr(>F)`[2]
  ))

  # CPI
  cpi_f <- as.formula(paste0("cpi_change_", h, " ~ shock_large + shock_small + ", ctrl))
  cpi_m <- lm(cpi_f, data = monthly_full)
  vcov_cpi <- NeweyWest(cpi_m, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))

  wald_cpi <- linearHypothesis(cpi_m, "shock_large = shock_small", vcov. = vcov_cpi)

  size_cpi_results <- rbind(size_cpi_results, data.frame(
    horizon    = h,
    beta_large = coef(cpi_m)["shock_large"],
    se_large   = se_cpi["shock_large"],
    beta_small = coef(cpi_m)["shock_small"],
    se_small   = se_cpi["shock_small"]
  ))

  size_wald_cpi <- rbind(size_wald_cpi, data.frame(
    horizon = h,
    wald_f  = wald_cpi$F[2],
    wald_p  = wald_cpi$`Pr(>F)`[2]
  ))
}

# --------------------------------------------------------------------------
# STEP 3: Plots — Sign asymmetry
# --------------------------------------------------------------------------
sign_fx_long <- sign_fx_results %>%
  pivot_longer(cols = c(beta_cut, beta_hike), names_to = "type", values_to = "beta") %>%
  mutate(
    se = ifelse(type == "beta_cut",
                sign_fx_results$se_cut[match(horizon, sign_fx_results$horizon)],
                sign_fx_results$se_hike[match(horizon, sign_fx_results$horizon)]),
    label = ifelse(type == "beta_cut", "Easing (cuts)", "Tightening (hikes)"),
    ci_lower = beta - 1.96 * se,
    ci_upper = beta + 1.96 * se
  )

p_sign_fx <- ggplot(sign_fx_long, aes(x = horizon, y = beta, color = label, fill = label)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.12, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c("Easing (cuts)" = "steelblue", "Tightening (hikes)" = "darkred")) +
  scale_fill_manual(values = c("Easing (cuts)" = "steelblue", "Tightening (hikes)" = "darkred")) +
  labs(title = "Sign Asymmetry: EUR/CHF Response to Easing vs Tightening",
       subtitle = "Separate coefficients for rate cuts and rate hikes",
       x = "Months After Shock", y = "EUR/CHF Change (%) per 1pp Shock",
       color = "Direction", fill = "Direction") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/irf_sign_asymmetry_fx.pdf"),
       p_sign_fx, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 4: Plots — Size asymmetry
# --------------------------------------------------------------------------
size_fx_long <- size_fx_results %>%
  pivot_longer(cols = c(beta_large, beta_small), names_to = "type", values_to = "beta") %>%
  mutate(
    se = ifelse(type == "beta_large",
                size_fx_results$se_large[match(horizon, size_fx_results$horizon)],
                size_fx_results$se_small[match(horizon, size_fx_results$horizon)]),
    label = ifelse(type == "beta_large",
                   sprintf("Large (|shock| > %.3f)", shock_median),
                   sprintf("Small (|shock| <= %.3f)", shock_median)),
    ci_lower = beta - 1.96 * se,
    ci_upper = beta + 1.96 * se
  )

p_size_fx <- ggplot(size_fx_long, aes(x = horizon, y = beta, color = label, fill = label)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.12, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c(setNames("darkorange", sprintf("Large (|shock| > %.3f)", shock_median)),
                                 setNames("grey40", sprintf("Small (|shock| <= %.3f)", shock_median)))) +
  scale_fill_manual(values = c(setNames("darkorange", sprintf("Large (|shock| > %.3f)", shock_median)),
                                setNames("grey40", sprintf("Small (|shock| <= %.3f)", shock_median)))) +
  labs(title = "Size Asymmetry: EUR/CHF Response by Shock Magnitude",
       subtitle = sprintf("Split at median absolute nonzero shock (%.3f pp)", shock_median),
       x = "Months After Shock", y = "EUR/CHF Change (%) per 1pp Shock",
       color = "Size", fill = "Size") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/irf_size_asymmetry_fx.pdf"),
       p_size_fx, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 5: Quantile regression for robustness
# --------------------------------------------------------------------------
taus <- c(0.25, 0.50, 0.75)
qr_results <- data.frame()

key_horizons <- c(1, 3, 6, 12)

for (h in key_horizons) {
  dep_var <- paste0("fx_change_", h)

  for (tau in taus) {
    qr_formula <- as.formula(paste0(dep_var, " ~ mp_shock + ", ctrl))

    tryCatch({
      qr_mod <- rq(qr_formula, tau = tau, data = monthly_full)
      qr_summ <- summary(qr_mod, se = "nid")

      coef_shock <- coef(qr_mod)["mp_shock"]
      se_shock   <- qr_summ$coefficients["mp_shock", "Std. Error"]

      qr_results <- rbind(qr_results, data.frame(
        horizon = h,
        tau     = tau,
        beta    = coef_shock,
        se      = se_shock,
        t_stat  = coef_shock / se_shock,
        p_value = 2 * pt(-abs(coef_shock / se_shock), df = nrow(monthly_full) - 5)
      ))
    }, error = function(e) {
      cat(sprintf("  Warning: QR failed at h=%d, tau=%.2f\n", h, tau))
    })
  }
}

# --------------------------------------------------------------------------
# STEP 6: Asymmetry results table
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

asym_table <- sign_fx_results %>%
  filter(horizon %in% c(1, 3, 6, 12)) %>%
  left_join(sign_wald_fx, by = "horizon") %>%
  left_join(size_fx_results %>%
              filter(horizon %in% c(1, 3, 6, 12)) %>%
              select(horizon, beta_large, se_large, beta_small, se_small),
            by = "horizon") %>%
  left_join(size_wald_fx %>%
              rename(size_wald_f = wald_f, size_wald_p = wald_p),
            by = "horizon") %>%
  mutate(
    cut_fmt   = sprintf("%.2f%s (%.2f)", beta_cut, add_stars(beta_cut, se_cut), se_cut),
    hike_fmt  = sprintf("%.2f%s (%.2f)", beta_hike, add_stars(beta_hike, se_hike), se_hike),
    sign_wald = sprintf("%.2f [%.3f]", wald_f, wald_p),
    large_fmt = sprintf("%.2f%s (%.2f)", beta_large, add_stars(beta_large, se_large), se_large),
    small_fmt = sprintf("%.2f%s (%.2f)", beta_small, add_stars(beta_small, se_small), se_small),
    size_wald_fmt = sprintf("%.2f [%.3f]", size_wald_f, size_wald_p)
  ) %>%
  select(horizon, cut_fmt, hike_fmt, sign_wald, large_fmt, small_fmt, size_wald_fmt)

colnames(asym_table) <- c("h", "Cuts", "Hikes", "Sign Wald",
                           "Large", "Small", "Size Wald")

asym_xtable <- xtable(asym_table,
                       caption = "Asymmetry Tests: EUR/CHF Response by Shock Sign and Size",
                       label = "tab:asymmetry_results",
                       align = c("l", "c", rep("r", 6)))
print(asym_xtable,
      file = file.path(ext_dir, "output/tables/asymmetry_results.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

# --------------------------------------------------------------------------
# STEP 7: Quantile regression table
# --------------------------------------------------------------------------
if (nrow(qr_results) > 0) {
  qr_table <- qr_results %>%
    mutate(
      coef_fmt = sprintf("%.2f%s (%.2f)", beta, add_stars(beta, se), se),
      tau_label = paste0("tau = ", tau)
    ) %>%
    select(horizon, tau_label, coef_fmt) %>%
    pivot_wider(names_from = tau_label, values_from = coef_fmt)

  qr_xtable <- xtable(qr_table,
                        caption = "Quantile Regression: EUR/CHF Response at Different Quantiles",
                        label = "tab:quantile_regression",
                        align = c("l", "c", rep("r", length(taus))))
  print(qr_xtable,
        file = file.path(ext_dir, "output/tables/quantile_regression.tex"),
        include.rownames = FALSE, caption.placement = "top",
        booktabs = TRUE, sanitize.text.function = identity)
}

cat("  Extension 7 complete.\n")
