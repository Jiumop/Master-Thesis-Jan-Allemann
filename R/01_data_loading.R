################################################################################
# SNB THESIS - 01: DATA LOADING
################################################################################

rm(list = ls())

library(tidyverse)
library(lubridate)

base_dir <- "C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R"
setwd(base_dir)

dir.create("output/tables",  showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("cache",          showWarnings = FALSE, recursive = TRUE)

# datasets loading
monthly_pure <- read.csv("data/swiss_monetary_monthly.csv", stringsAsFactors = FALSE)
monthly_pure$date <- as.Date(monthly_pure$date)

announcements <- read.csv("data/snb_announcements.csv", stringsAsFactors = FALSE)
announcements$date <- as.Date(announcements$date)

daily_fx <- read.csv("data/EUR_CHF_1day.csv", stringsAsFactors = FALSE)
daily_fx$datetime <- as.Date(daily_fx$datetime)

hourly_fx <- read.csv("data/EUR_CHF_1h.csv", stringsAsFactors = FALSE) 
hourly_fx$datetime <- as.POSIXct(hourly_fx$datetime)

# unified monthly dataset
monthly_fx <- daily_fx %>%
  mutate(year_month = format(datetime, "%Y-%m")) %>%
  group_by(year_month) %>%
  slice_tail(n = 1) %>%
  select(year_month, eur_chf, log_eur_chf, delta_log_eur_chf) %>%
  ungroup()

monthly_policy <- announcements %>%
  filter(!is.na(unified_policy_rate)) %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  group_by(year_month) %>%
  slice_tail(n = 1) %>%
  select(year_month, policy_rate = unified_policy_rate) %>%
  ungroup()

monthly <- monthly_pure %>%
  mutate(year_month = format(date, "%Y-%m")) %>%
  left_join(monthly_fx, by = "year_month") %>%
  left_join(monthly_policy, by = "year_month") %>%
  arrange(date) %>%
  fill(policy_rate, .direction = "down") %>%
  mutate(
    delta_policy_rate = c(NA, diff(policy_rate)),
    policy_rate_lag1 = lag(policy_rate, 1),
    log_eur_chf = ifelse(is.na(log_eur_chf), log(eur_chf), log_eur_chf),
    delta_log_eur_chf = ifelse(is.na(delta_log_eur_chf), 
                               c(NA, diff(log_eur_chf)) * 100, 
                               delta_log_eur_chf * 100),
    regime_positive = ifelse(date < as.Date("2014-12-01") | date >= as.Date("2022-06-01"), 1, 0),
    regime_negative = ifelse(date >= as.Date("2014-12-01") & date < as.Date("2022-06-01"), 1, 0)
  )

# Rate cuts (for analysis - event studies, local projections)
rate_cuts <- announcements %>%
  filter(rate_action == "cut") %>%
  arrange(date)

# ALL rate changes (for visualization)
rate_changes <- announcements %>%
  filter(rate_action %in% c("cut", "hike")) %>%
  arrange(date)

# Daily event study data
daily_events <- list()
for(i in 1:nrow(rate_cuts)) {
  event_date <- rate_cuts$date[i]
  window <- daily_fx %>%
    filter(datetime >= event_date - days(10), 
           datetime <= event_date + days(10)) %>%
    mutate(
      event_id = i,
      event_date = event_date,
      days_from = as.numeric(difftime(datetime, event_date, units = "days")),
      return = delta_log_eur_chf
    )
  daily_events[[i]] <- window
}
daily_event_data <- bind_rows(daily_events)

# Hourly event study data  
hourly_cut_dates <- rate_cuts %>%
  filter(date >= as.Date("2020-01-01")) %>%
  pull(date)

hourly_events <- list()
for(i in seq_along(hourly_cut_dates)) {
  event_date <- hourly_cut_dates[i]
  event_datetime <- as.POSIXct(paste(event_date, "09:30:00"))
  
  window <- hourly_fx %>%
    filter(datetime >= event_datetime - hours(6),
           datetime <= event_datetime + hours(6)) %>%
    mutate(
      event_id = i,
      event_date = event_date,
      hours_from = as.numeric(difftime(datetime, event_datetime, units = "hours")),
      return = delta_log_eur_chf
    )
  hourly_events[[i]] <- window
}

if(length(hourly_events) > 0) {
  hourly_event_data <- bind_rows(hourly_events)
} else {
  hourly_event_data <- data.frame()
}

save(monthly, announcements, rate_cuts, rate_changes, daily_event_data, hourly_event_data,
      file = "cache/prepared_data.RData")
