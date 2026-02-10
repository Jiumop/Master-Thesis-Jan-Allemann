################################################################################
# SNB THESIS - 04: EVENT STUDIES (REGRESSION-BASED)
################################################################################

library(tidyverse)
library(ggplot2)
library(lubridate)
library(lmtest)
library(sandwich)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)

load("cache/prepared_data.RData")
load("cache/shock_identification.RData")

################################################################################
# DAILY EVENT STUDY - REGRESSION APPROACH
################################################################################

#daily event data with shocks
daily_events_with_shocks <- daily_event_data %>%
  left_join(
    rate_cuts %>% select(date, mp_shock),
    by = c("event_date" = "date")
  ) %>%
  filter(!is.na(mp_shock))

#regressions at each horizon
daily_horizons <- -10:10
daily_event_results <- data.frame()

for(d in daily_horizons) {
  horizon_data <- daily_events_with_shocks %>%
    filter(days_from == d, !is.na(return))
  
  if(nrow(horizon_data) >= 5) {
    model_d <- lm(return ~ mp_shock, data = horizon_data)
    vcov_d <- vcovHC(model_d, type = "HC1")
    
    coef_d <- coef(model_d)["mp_shock"]
    se_d <- sqrt(diag(vcov_d))["mp_shock"]
    
    daily_event_results <- rbind(daily_event_results, data.frame(
      days_from = d,
      beta = coef_d,
      se = se_d,
      ci_lower = coef_d - 1.96 * se_d,
      ci_upper = coef_d + 1.96 * se_d,
      n_obs = nrow(horizon_data)
    ))
  }
}

#daily event study plot
p_daily_event <- ggplot(daily_event_results, aes(x = days_from, y = beta)) +
  geom_line(linewidth = 1, color = "darkgreen") +
  geom_point(size = 2, color = "darkgreen") +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, fill = "darkgreen") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = seq(-10, 10, 2)) +
  labs(
    title = "Daily Event Study: EUR/CHF Response to Rate Cut Announcements",
    subtitle = paste0("Regression-based estimates scaled to 1pp shock (", 
                      length(unique(daily_events_with_shocks$event_id)), " events)"),
    x = "Days from Announcement", 
    y = "EUR/CHF Change (%) per 1pp Shock", 
    caption = "Shaded area: 95% confidence interval. Robust standard errors."
  )

ggsave("output/figures/daily_event_study.pdf", p_daily_event, width = 10, height = 6, dpi = 300)

################################################################################
# HOURLY EVENT STUDY - REGRESSION APPROACH
################################################################################

hourly_event_results <- data.frame()

if(exists("hourly_event_data") && nrow(hourly_event_data) > 0) {
  
  #shocks added to hourly data
  hourly_events_with_shocks <- hourly_event_data %>%
    left_join(
      rate_cuts %>% select(date, mp_shock),
      by = c("event_date" = "date")
    ) %>%
    filter(!is.na(mp_shock))
  
  #regressions at each hourly horizon
  hourly_horizons <- -6:6
  
  for(h in hourly_horizons) {
    horizon_data <- hourly_events_with_shocks %>%
      filter(hours_from == h, !is.na(return))
    
    if(nrow(horizon_data) >= 3) {
      model_h <- lm(return ~ mp_shock, data = horizon_data)
      vcov_h <- vcovHC(model_h, type = "HC1")
      
      coef_h <- coef(model_h)["mp_shock"]
      se_h <- sqrt(diag(vcov_h))["mp_shock"]
      
      hourly_event_results <- rbind(hourly_event_results, data.frame(
        hours_from = h,
        beta = coef_h,
        se = se_h,
        ci_lower = coef_h - 1.96 * se_h,
        ci_upper = coef_h + 1.96 * se_h,
        n_obs = nrow(horizon_data)
      ))
    }
  }
  
  #hourly event study plot
  if(nrow(hourly_event_results) > 0) {
    p_hourly_event <- ggplot(hourly_event_results, aes(x = hours_from, y = beta)) +
      geom_line(linewidth = 1, color = "darkblue") +
      geom_point(size = 2, color = "darkblue") +
      geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, fill = "darkblue") +
      geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      scale_x_continuous(breaks = seq(-6, 6, 1)) +
      labs(
        title = "Hourly Event Study: EUR/CHF Response to Rate Cut Announcements",
        subtitle = paste0("Regression-based estimates scaled to 1pp shock (", 
                          length(unique(hourly_events_with_shocks$event_id)), " events)"),
        x = "Hours from Announcement", 
        y = "EUR/CHF Change (%) per 1pp Shock",
        caption = "Shaded area: 95% confidence interval. Robust standard errors."
      )
    
    ggsave("output/figures/hourly_event_study.pdf", p_hourly_event, width = 10, height = 6, dpi = 300)
  }
}

################################################################################
# CUMULATIVE RESPONSE
################################################################################

# Cumulative response
daily_cumulative <- daily_event_results %>%
  filter(days_from >= 0) %>%
  arrange(days_from) %>%
  mutate(
    cumulative_beta = cumsum(beta),
    cumulative_se = sqrt(cumsum(se^2))
  ) %>%
  mutate(
    cum_ci_lower = cumulative_beta - 1.96 * cumulative_se,
    cum_ci_upper = cumulative_beta + 1.96 * cumulative_se
  )

p_daily_cumulative <- ggplot(daily_cumulative, aes(x = days_from, y = cumulative_beta)) +
  geom_line(linewidth = 1, color = "purple") +
  geom_point(size = 2, color = "purple") +
  geom_ribbon(aes(ymin = cum_ci_lower, ymax = cum_ci_upper), alpha = 0.2, fill = "purple") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = seq(0, 10, 2)) +
  labs(
    title = "Cumulative EUR/CHF Response to Rate Cut Announcements",
    subtitle = "Sum of daily responses scaled to 1pp shock",
    x = "Days from Announcement", 
    y = "Cumulative EUR/CHF Change (%) per 1pp Shock",
    caption = "Shaded area: 95% confidence interval"
  )

ggsave("output/figures/daily_cumulative_response.pdf", p_daily_cumulative, width = 10, height = 6, dpi = 300)

save(
  daily_event_results, 
  daily_cumulative, 
  hourly_event_results,
  file = "cache/event_study_results.RData"
)