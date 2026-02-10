################################################################################
# EXTENSION 1: HIGH-FREQUENCY IDENTIFICATION
# IV-LP using intraday EUR/CHF changes around SNB announcements
################################################################################

library(tidyverse)
library(sandwich)
library(lmtest)
library(ivreg)
library(xtable)
library(ggplot2)

cat("\n=== Extension 1: High-Frequency Identification ===\n")

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
ext_dir  <- file.path(base_dir, "extensions")

load(file.path(base_dir, "cache/shock_identification.RData"))
load(file.path(base_dir, "cache/local_projections.RData"))
load(file.path(base_dir, "cache/prepared_data.RData"))

# --------------------------------------------------------------------------
# STEP 1: Compute HF surprise from hourly EUR/CHF data
# --------------------------------------------------------------------------
hourly_fx <- read.csv(file.path(base_dir, "data/EUR_CHF_1h.csv"),
                      stringsAsFactors = FALSE)
hourly_fx$datetime <- as.POSIXct(hourly_fx$datetime)

ann <- read.csv(file.path(base_dir, "data/snb_announcements.csv"),
                stringsAsFactors = FALSE)
ann$date <- as.Date(ann$date)

# Filter to announcements with hourly data coverage (2020+)
ann_hf <- ann %>%
  filter(date >= as.Date("2020-01-01"),
         !is.na(rate_change_pp))

hf_surprises <- list()
for (i in seq_len(nrow(ann_hf))) {
  event_date <- ann_hf$date[i]
  event_time <- as.POSIXct(paste(event_date, "09:30:00"))

  pre  <- hourly_fx %>%
    filter(datetime >= event_time - 3600, datetime < event_time) %>%
    arrange(datetime) %>%
    slice(1)

  post <- hourly_fx %>%
    filter(datetime > event_time, datetime <= event_time + 3600) %>%
    arrange(datetime) %>%
    slice(n())

  if (nrow(pre) > 0 && nrow(post) > 0) {
    hf_surprises[[i]] <- data.frame(
      date       = event_date,
      year_month = format(event_date, "%Y-%m"),
      hf_surprise = (post$log_eur_chf - pre$log_eur_chf) * 100,
      rate_change = ann_hf$rate_change_pp[i]
    )
  }
}
hf_data <- bind_rows(hf_surprises) %>% filter(!is.na(hf_surprise))

cat(sprintf("  HF surprises computed: %d events\n", nrow(hf_data)))

# --------------------------------------------------------------------------
# STEP 2: Merge HF surprise with monthly data
# --------------------------------------------------------------------------
monthly_iv <- monthly_full %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  inner_join(hf_data %>% select(year_month, hf_surprise), by = "year_month")

# Ensure forward differences exist
horizons <- 1:12
for (h in horizons) {
  if (!paste0("fx_change_", h) %in% colnames(monthly_iv)) {
    monthly_iv[[paste0("fx_change_", h)]] <-
      (lead(monthly_iv$log_eur_chf, h) - monthly_iv$log_eur_chf) * 100
  }
  if (!paste0("cpi_change_", h) %in% colnames(monthly_iv)) {
    monthly_iv[[paste0("cpi_change_", h)]] <-
      lead(monthly_iv$cpi_yoy, h) - monthly_iv$cpi_yoy
  }
}

# --------------------------------------------------------------------------
# STEP 3: First-stage diagnostics
# --------------------------------------------------------------------------
if (exists("control_formula")) {
  ctrl <- control_formula
} else {
  ctrl <- "cpi_yoy_lag1 + kof_lag1"
}

first_stage <- lm(as.formula(paste0("mp_shock ~ hf_surprise + ", ctrl)),
                  data = monthly_iv)
fs_robust <- coeftest(first_stage, vcov = vcovHC(first_stage, type = "HC1"))

fs_fstat <- (fs_robust["hf_surprise", "t value"])^2

cat(sprintf("  First-stage F-statistic: %.2f\n", fs_fstat))
cat(sprintf("  Instrument relevance: %s\n",
            ifelse(fs_fstat > 10, "Strong (F > 10)", "Weak (F < 10) — interpret with caution")))

# First-stage table
fs_table <- data.frame(
  Variable  = gsub("_", "\\\\_", rownames(fs_robust)),
  Estimate  = sprintf("%.4f", fs_robust[, 1]),
  SE        = sprintf("(%.4f)", fs_robust[, 2]),
  t.stat    = sprintf("%.2f", fs_robust[, 3]),
  p.value   = sprintf("%.3f", fs_robust[, 4])
)

fs_xtable <- xtable(fs_table,
                     caption = "First-Stage Regression: HF EUR/CHF Surprise as Instrument for MP Shock",
                     label = "tab:hf_first_stage",
                     align = c("l", "l", "r", "r", "r", "r"))
print(fs_xtable,
      file = file.path(ext_dir, "output/tables/hf_first_stage.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

# --------------------------------------------------------------------------
# STEP 4: IV-LP at each horizon
# --------------------------------------------------------------------------
iv_results <- data.frame()

for (h in horizons) {
  dep_var <- paste0("fx_change_", h)

  iv_formula <- as.formula(
    paste0(dep_var, " ~ mp_shock + ", ctrl, " | hf_surprise + ", ctrl)
  )

  tryCatch({
    iv_mod <- ivreg(iv_formula, data = monthly_iv)
    vcov_iv <- vcovHC(iv_mod, type = "HC1")
    se_iv <- sqrt(diag(vcov_iv))

    coef_iv <- coef(iv_mod)["mp_shock"]
    se_mp   <- se_iv["mp_shock"]

    iv_results <- rbind(iv_results, data.frame(
      horizon  = h,
      beta     = coef_iv,
      se       = se_mp,
      ci_lower = coef_iv - 1.96 * se_mp,
      ci_upper = coef_iv + 1.96 * se_mp,
      method   = "IV-LP (HF)"
    ))
  }, error = function(e) {
    cat(sprintf("  Warning: IV-LP failed at horizon %d: %s\n", h, e$message))
  })
}

# OLS baseline for comparison (restrict to same sample)
ols_results <- data.frame()
for (h in horizons) {
  dep_var <- paste0("fx_change_", h)
  ols_formula <- as.formula(paste0(dep_var, " ~ mp_shock + ", ctrl))

  ols_mod <- lm(ols_formula, data = monthly_iv)
  vcov_ols <- NeweyWest(ols_mod, lag = h, prewhite = FALSE)
  se_ols <- sqrt(diag(vcov_ols))

  coef_ols <- coef(ols_mod)["mp_shock"]
  se_mp    <- se_ols["mp_shock"]

  ols_results <- rbind(ols_results, data.frame(
    horizon  = h,
    beta     = coef_ols,
    se       = se_mp,
    ci_lower = coef_ols - 1.96 * se_mp,
    ci_upper = coef_ols + 1.96 * se_mp,
    method   = "OLS-LP (Baseline)"
  ))
}

combined <- rbind(iv_results, ols_results)

# --------------------------------------------------------------------------
# STEP 5: Comparison plot
# --------------------------------------------------------------------------
p_hf <- ggplot(combined, aes(x = horizon, y = beta, color = method, fill = method)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.15, color = NA) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(values = c("IV-LP (HF)" = "darkred", "OLS-LP (Baseline)" = "steelblue")) +
  scale_fill_manual(values = c("IV-LP (HF)" = "darkred", "OLS-LP (Baseline)" = "steelblue")) +
  labs(title = "IV-LP vs OLS-LP: EUR/CHF Impulse Response",
       subtitle = "Instrument: Intraday EUR/CHF change in [-1h, +1h] window around SNB announcements",
       x = "Months After Shock", y = "EUR/CHF Change (%) per 1pp Shock",
       color = "Method", fill = "Method",
       caption = sprintf("Note: IV sample restricted to %d events with hourly data (2020+). First-stage F = %.1f",
                         nrow(hf_data), fs_fstat)) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(ext_dir, "output/figures/irf_hf_vs_baseline.pdf"),
       p_hf, width = 10, height = 6, dpi = 300)

# --------------------------------------------------------------------------
# STEP 6: Comparison table
# --------------------------------------------------------------------------
comp_table <- combined %>%
  mutate(
    sig = case_when(
      abs(beta / se) > 2.576 ~ "***",
      abs(beta / se) > 1.960 ~ "**",
      abs(beta / se) > 1.645 ~ "*",
      TRUE ~ ""
    ),
    cell = paste0(sprintf("%.2f", beta), sig, " (", sprintf("%.2f", se), ")")
  ) %>%
  filter(horizon %in% c(1, 3, 6, 12)) %>%
  select(horizon, method, cell) %>%
  pivot_wider(names_from = horizon, values_from = cell, names_prefix = "h = ")

colnames(comp_table)[1] <- "Method"

comp_xtable <- xtable(comp_table,
                       caption = "IV-LP vs OLS-LP: EUR/CHF Response Comparison",
                       label = "tab:irf_hf_comparison",
                       align = c("l", "l", rep("r", ncol(comp_table) - 1)))
print(comp_xtable,
      file = file.path(ext_dir, "output/tables/irf_hf_comparison.tex"),
      include.rownames = FALSE, caption.placement = "top",
      booktabs = TRUE, sanitize.text.function = identity)

cat("  Extension 1 complete.\n")
