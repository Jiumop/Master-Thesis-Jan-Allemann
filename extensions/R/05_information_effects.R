################################################################################
# EXTENSION 5: INFORMATION EFFECTS
# Decompose MP shocks into pure monetary vs information components
# Simplified version of Jarocinski & Karadi (2020)
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(xtable)
library(ggplot2)
library(gridExtra)

cat("\n=== Extension 5: Information Effects ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "cache/shock_identification.RData"))
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
# STEP 1: Compute 1-month changes in yield_2y and EUR/CHF around shocks
# --------------------------------------------------------------------------
monthly_full <- monthly_full %>%
  mutate(
    delta_yield_2y = yield_2y - lag(yield_2y, 1),
    delta_fx_1m    = delta_log_eur_chf  # already in %
  )

# Focus on announcement months with nonzero shocks
shock_months <- monthly_full %>%
  filter(abs(mp_shock) > 0.001) %>%
  select(date, year_month, mp_shock, delta_yield_2y, delta_fx_1m, delta_policy_rate)

cat(sprintf("  Announcement months with shocks: %d\n", nrow(shock_months)))

# --------------------------------------------------------------------------
# STEP 2: Classify shocks using sign restrictions
# Pure MP: rate cut -> CHF depreciates (EUR/CHF rises) AND yield falls
#          rate hike -> CHF appreciates AND yield rises
# => consistent sign: mp_shock and delta_yield_2y have same sign
#
# Information: rate cut -> CHF appreciates AND yield rises (bad news learned)
# => opposite sign: mp_shock and delta_yield_2y have opposite sign
# --------------------------------------------------------------------------
shock_months <- shock_months %>%
  mutate(
    # Pure MP: shock and yield change have same sign
    # (easing -> yield falls, tightening -> yield rises)
    is_pure_mp = (mp_shock * delta_yield_2y > 0) | is.na(delta_yield_2y),
    shock_type = ifelse(is_pure_mp, "Pure MP", "Information"),
    shock_type = ifelse(is.na(delta_yield_2y), "Unclassified", shock_type)
  )

type_counts <- table(shock_months$shock_type)
cat("  Shock classification:\n")
print(type_counts)

# Merge classification back to full monthly data
monthly_full <- monthly_full %>%
  left_join(
    shock_months %>% select(year_month, shock_type),
    by = "year_month"
  ) %>%
  mutate(
    shock_type = ifelse(is.na(shock_type), "No Shock", shock_type),
    mp_shock_pure = ifelse(shock_type == "Pure MP", mp_shock, 0),
    mp_shock_info = ifelse(shock_type == "Information", mp_shock, 0)
  )

# --------------------------------------------------------------------------
# STEP 3: Classification scatter plot
# --------------------------------------------------------------------------
p_classify <- ggplot(shock_months %>% filter(shock_type != "Unclassified"),
                     aes(x = mp_shock, y = delta_yield_2y, color = shock_type)) +
  geom_point(size = 3, alpha = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  # Quadrants annotation
  annotate("text", x = min(shock_months$mp_shock, na.rm = TRUE) * 0.5,
           y = min(shock_months$delta_yield_2y, na.rm = TRUE) * 0.5,
           label = "Pure MP\n(easing)", color = "steelblue", size = 3, fontface = "italic") +
  annotate("text", x = min(shock_months$mp_shock, na.rm = TRUE) * 0.5,
           y = max(shock_months$delta_yield_2y, na.rm = TRUE) * 0.5,
           label = "Information\n(bad news)", color = "darkred", size = 3, fontface = "italic") +
  scale_color_manual(values = c("Pure MP" = "steelblue", "Information" = "darkred",
                                 "Unclassified" = "grey50")) +
  labs(title = "Classification of MP Shocks: Pure Monetary vs Information",
       subtitle = "Based on co-movement of MP shock and 2Y yield change",
       x = "MP Shock (residual from purging regression)",
       y = "1-Month Change in 2Y Yield (pp)",
       color = "Shock Type") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/info_vs_mp_classification.pdf"),
       p_classify, width = 8, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 4: Run separate LPs for each component
# --------------------------------------------------------------------------
# FX responses
info_fx_results  <- data.frame()
pure_fx_results  <- data.frame()

for (h in horizons) {
  fx_formula <- as.formula(
    paste0("fx_change_", h, " ~ mp_shock_pure + mp_shock_info + ", ctrl)
  )
  fx_mod <- lm(fx_formula, data = monthly_full)
  vcov_fx <- NeweyWest(fx_mod, lag = h, prewhite = FALSE)
  se_fx <- sqrt(diag(vcov_fx))

  pure_fx_results <- rbind(pure_fx_results, data.frame(
    horizon  = h,
    beta     = coef(fx_mod)["mp_shock_pure"],
    se       = se_fx["mp_shock_pure"],
    ci_lower = coef(fx_mod)["mp_shock_pure"] - 1.96 * se_fx["mp_shock_pure"],
    ci_upper = coef(fx_mod)["mp_shock_pure"] + 1.96 * se_fx["mp_shock_pure"],
    type     = "Pure MP"
  ))

  info_fx_results <- rbind(info_fx_results, data.frame(
    horizon  = h,
    beta     = coef(fx_mod)["mp_shock_info"],
    se       = se_fx["mp_shock_info"],
    ci_lower = coef(fx_mod)["mp_shock_info"] - 1.96 * se_fx["mp_shock_info"],
    ci_upper = coef(fx_mod)["mp_shock_info"] + 1.96 * se_fx["mp_shock_info"],
    type     = "Information"
  ))
}

# CPI responses
info_cpi_results <- data.frame()
pure_cpi_results <- data.frame()

for (h in horizons) {
  cpi_formula <- as.formula(
    paste0("cpi_change_", h, " ~ mp_shock_pure + mp_shock_info + ", ctrl)
  )
  cpi_mod <- lm(cpi_formula, data = monthly_full)
  vcov_cpi <- NeweyWest(cpi_mod, lag = h, prewhite = FALSE)
  se_cpi <- sqrt(diag(vcov_cpi))

  pure_cpi_results <- rbind(pure_cpi_results, data.frame(
    horizon  = h,
    beta     = coef(cpi_mod)["mp_shock_pure"],
    se       = se_cpi["mp_shock_pure"],
    ci_lower = coef(cpi_mod)["mp_shock_pure"] - 1.96 * se_cpi["mp_shock_pure"],
    ci_upper = coef(cpi_mod)["mp_shock_pure"] + 1.96 * se_cpi["mp_shock_pure"],
    type     = "Pure MP"
  ))

  info_cpi_results <- rbind(info_cpi_results, data.frame(
    horizon  = h,
    beta     = coef(cpi_mod)["mp_shock_info"],
    se       = se_cpi["mp_shock_info"],
    ci_lower = coef(cpi_mod)["mp_shock_info"] - 1.96 * se_cpi["mp_shock_info"],
    ci_upper = coef(cpi_mod)["mp_shock_info"] + 1.96 * se_cpi["mp_shock_info"],
    type     = "Information"
  ))
}

# --------------------------------------------------------------------------
# STEP 5: IRF Plots
# --------------------------------------------------------------------------
all_fx <- rbind(pure_fx_results, info_fx_results)

p_info_fx <- ggplot(all_fx, aes(x = horizon, y = beta, color = type, fill = type)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.12, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c("Pure MP" = "steelblue", "Information" = "darkred")) +
  scale_fill_manual(values = c("Pure MP" = "steelblue", "Information" = "darkred")) +
  labs(title = "Information vs Pure MP: EUR/CHF Impulse Response",
       subtitle = "Decomposition based on yield co-movement (Jarocinski-Karadi approach)",
       x = "Months After Shock", y = "EUR/CHF Change (%) per 1pp Shock",
       color = "Shock Component", fill = "Shock Component") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/irf_info_vs_mp_fx.pdf"),
       p_info_fx, width = 10, height = 6, dpi = 300)

all_cpi <- rbind(pure_cpi_results, info_cpi_results)

p_info_cpi <- ggplot(all_cpi, aes(x = horizon, y = beta, color = type, fill = type)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.12, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c("Pure MP" = "steelblue", "Information" = "darkred")) +
  scale_fill_manual(values = c("Pure MP" = "steelblue", "Information" = "darkred")) +
  labs(title = "Information vs Pure MP: CPI Impulse Response",
       subtitle = "Decomposition based on yield co-movement (Jarocinski-Karadi approach)",
       x = "Months After Shock", y = "CPI Change (pp) per 1pp Shock",
       color = "Shock Component", fill = "Shock Component") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/irf_info_vs_mp_cpi.pdf"),
       p_info_cpi, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 6: Results table
# --------------------------------------------------------------------------
info_table <- data.frame(
  Horizon = rep(c(1, 3, 6, 12), 2),
  Component = c(rep("Pure MP", 4), rep("Information", 4)),
  FX_beta = c(pure_fx_results$beta[c(1, 3, 6, 12)], info_fx_results$beta[c(1, 3, 6, 12)]),
  FX_se   = c(pure_fx_results$se[c(1, 3, 6, 12)], info_fx_results$se[c(1, 3, 6, 12)]),
  CPI_beta = c(pure_cpi_results$beta[c(1, 3, 6, 12)], info_cpi_results$beta[c(1, 3, 6, 12)]),
  CPI_se   = c(pure_cpi_results$se[c(1, 3, 6, 12)], info_cpi_results$se[c(1, 3, 6, 12)])
) %>%
  mutate(
    FX_fmt  = sprintf("%.2f (%.2f)", FX_beta, FX_se),
    CPI_fmt = sprintf("%.2f (%.2f)", CPI_beta, CPI_se)
  ) %>%
  select(Horizon, Component, FX_fmt, CPI_fmt)

colnames(info_table) <- c("Horizon", "Component", "EUR/CHF", "CPI")

info_xtable <- xtable(info_table,
                       caption = "Information vs Pure MP Shocks: IRF Comparison",
                       label = "tab:info_effects_results",
                       align = c("l", "c", "l", "r", "r"))
print(info_xtable,
      file = file.path(ext_dir, "output/tables/info_effects_results.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

cat("  Extension 5 complete.\n")
