################################################################################
# SNB THESIS - 02: DATA DESCRIPTION
################################################################################

library(tidyverse)
library(ggplot2)
library(gridExtra)
library(scales)
library(xtable)

setwd("C:/Users/jan-a/Desktop/Masterthesis_final/Data_Analysis_R")
theme_set(theme_minimal(base_size = 12))

load("prepared_data.RData")

# Summary statistics table
summary_stats <- monthly %>%
  select(policy_rate, cpi_yoy, kof, eur_chf, yield_2y, vix) %>%
  summarise(across(everything(), list(
    Mean = ~mean(., na.rm = TRUE),
    SD = ~sd(., na.rm = TRUE),
    Min = ~min(., na.rm = TRUE),
    Max = ~max(., na.rm = TRUE),
    N = ~sum(!is.na(.))
  ))) %>%
  pivot_longer(everything(), names_to = c("Variable", ".value"), names_sep = "_(?=[^_]+$)") %>%
  mutate(Variable = case_when(
    Variable == "policy.rate" ~ "Policy Rate (\\%)",
    Variable == "cpi.yoy" ~ "CPI Inflation (\\%)",
    Variable == "kof" ~ "KOF Barometer",
    Variable == "eur.chf" ~ "EUR/CHF",
    Variable == "yield.2y" ~ "2Y Yield (\\%)",
    Variable == "vix" ~ "VIX",
    TRUE ~ Variable
  )) %>%
  select(Variable, Mean, SD, Min, Max, N)

print(xtable(summary_stats, 
             caption = "Descriptive Statistics: Monthly Data (2000-2025)", 
             label = "tab:summary_stats",
             align = c("l", "l", "c", "c", "c", "c", "c"), 
             digits = c(0, 0, 3, 3, 3, 3, 0)),
      file = "output/tables/summary_stats.tex", 
      include.rownames = FALSE, 
      caption.placement = "top", 
      booktabs = TRUE,
      sanitize.text.function = identity)

# Correlation analysis
cor_vars <- monthly %>%
  select(cpi_yoy, kof, eur_chf, yield_2y, vix, policy_rate) %>%
  filter(complete.cases(.)) %>%
  cor()

cor_melted <- expand.grid(Var1 = rownames(cor_vars), Var2 = colnames(cor_vars)) %>%
  mutate(
    Correlation = as.vector(cor_vars),
    Var1 = factor(Var1, levels = rev(rownames(cor_vars))),
    Var2 = factor(Var2, levels = colnames(cor_vars))
  )

# Correlation heatmap
p_correlation <- ggplot(cor_melted, aes(x = Var2, y = Var1, fill = Correlation)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(Correlation, 2)), size = 3) +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, name = "Correlation") +
  labs(title = "Variable Correlation Matrix", x = "", y = "") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("output/figures/correlation_heatmap.pdf", p_correlation, width = 10, height = 8, dpi = 300)

# Policy rate timeline 
p_policy <- ggplot(announcements, aes(x = date)) +
  annotate("rect", xmin = as.Date("2014-12-01"), xmax = as.Date("2022-06-01"), 
           ymin = -Inf, ymax = Inf, fill = "red", alpha = 0.1) +
  geom_ribbon(aes(ymin = libor_lower, ymax = libor_upper), 
              fill = "lightblue", alpha = 0.3, na.rm = TRUE) +
  geom_line(aes(y = unified_policy_rate), color = "darkblue", linewidth = 1, na.rm = TRUE) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  geom_point(data = filter(rate_changes, rate_action == "cut"), 
             aes(x = date, y = rate_to), color = "red", size = 2, shape = 25, fill = "red") +
  geom_point(data = filter(rate_changes, rate_action == "hike"), 
             aes(x = date, y = rate_to), color = "blue", size = 2, shape = 24, fill = "blue") +
  scale_y_continuous(labels = percent_format(scale = 1)) +
  labs(title = "SNB Policy Rate with Rate Changes and LIBOR Target Range (2000-2025)",
       subtitle = "Red: Rate cuts | Blue: Rate hikes | Blue band: LIBOR range",
       x = NULL, y = "Rate (%)")

ggsave("output/figures/policy_rate_timeline.pdf", p_policy, width = 12, height = 6, dpi = 300)

# Key variables timeline
p2a <- ggplot(monthly, aes(x = date, y = cpi_yoy)) +
  geom_line(color = "darkred") + 
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(title = "A. CPI Inflation", x = NULL, y = "YoY %")

p2b <- ggplot(monthly, aes(x = date, y = kof)) +
  geom_line(color = "darkgreen") + 
  geom_hline(yintercept = 100, linetype = "dashed") +
  labs(title = "B. KOF Barometer", x = NULL, y = "Index")

p2c <- ggplot(monthly, aes(x = date, y = eur_chf)) +
  geom_line(color = "darkblue") +
  annotate("rect", xmin = as.Date("2011-09-01"), xmax = as.Date("2015-01-15"), 
           ymin = -Inf, ymax = Inf, fill = "blue", alpha = 0.1) +
  labs(title = "C. EUR/CHF (floor period shaded)", x = NULL, y = "Exchange Rate")

p2d <- ggplot(monthly, aes(x = date, y = vix)) +
  geom_line(color = "purple") + 
  labs(title = "D. VIX", x = NULL, y = "Index")

p2_combined <- grid.arrange(p2a, p2b, p2c, p2d, ncol = 2)
ggsave("output/figures/key_variables_timeline.pdf", p2_combined, width = 12, height = 8, dpi = 300)

# Rate changes histogram
rate_changes <- monthly %>%
  filter(abs(delta_policy_rate) > 0.001) %>%
  mutate(type = ifelse(delta_policy_rate < 0, "Cut", "Hike"))

p_histogram <- ggplot(rate_changes, aes(x = delta_policy_rate * 100, fill = type)) +
  geom_histogram(binwidth = 10, color = "black", alpha = 0.7) +
  scale_fill_manual(values = c("Cut" = "red", "Hike" = "blue")) +
  labs(title = "Distribution of SNB Rate Changes by Magnitude (2000-2025)",
       x = "Rate Change (basis points)", y = "Count", fill = "Type")

ggsave("output/figures/rate_changes_histogram.pdf", p_histogram, width = 8, height = 5, dpi = 300)
