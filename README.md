# Master Thesis — Jan Allemann

## SNB Monetary Policy Transmission Under Negative Interest Rates

This repository contains the full data analysis pipeline and thesis document for my master thesis on Swiss National Bank (SNB) monetary policy transmission, with a focus on comparing the exchange rate and inflation channels under positive vs. negative interest rate regimes.

## Project Structure

```
Data_Analysis_R/
├── run_all.R                  # Master script — runs entire pipeline
├── R/                         # Analysis scripts (run in order)
│   ├── 01_data_loading.R      # Load & merge monthly, daily, hourly data
│   ├── 02_data_description.R  # Descriptive statistics & visualizations
│   ├── 03_shock_identification.R  # MP shock identification (purging + RF)
│   ├── 04_event_studies.R     # Daily & hourly event studies
│   ├── 05_local_projections.R # Jordà local projections (EUR/CHF, CPI)
│   ├── 06_regime_analysis.R   # Positive vs negative rate regime comparison
│   ├── 07_machine_learning.R  # Causal Forest for heterogeneous effects
│   └── 08_robustness.R        # Robustness across control specifications
├── data/                      # Input datasets
│   ├── swiss_monetary_monthly.csv
│   ├── snb_announcements.csv
│   ├── EUR_CHF_1day.csv
│   └── EUR_CHF_1h.csv
├── output/
│   ├── figures/               # Generated plots (PDF)
│   └── tables/                # Generated LaTeX tables
└── thesis/
    ├── Masterthesis_Jan_Allemann.pdf
    ├── MA_final.tex
    └── ref5.bib
```

## Methodology

1. **Shock Identification**: Monetary policy shocks are extracted via a purging regression, with control variables selected using Random Forest variable importance
2. **Event Studies**: Regression-based daily and hourly event studies around SNB rate cut announcements
3. **Local Projections**: Jordà (2005) impulse response functions for EUR/CHF and CPI inflation, with Newey-West standard errors
4. **Regime Analysis**: Separate impulse responses for positive and negative interest rate environments, tested via Wald statistics
5. **Machine Learning**: Causal Forest (Athey & Imbens) for conditional average treatment effect heterogeneity across regimes
6. **Robustness**: Sensitivity analysis across no controls, lagged controls, and full data-driven control specifications

## How to Run

1. Open R or RStudio
2. Run the full pipeline:

```r
source("run_all.R")
```

This executes all 8 scripts sequentially. Output is saved to `output/figures/` and `output/tables/`.

## Requirements

- R (>= 4.0)
- tidyverse, ggplot2, lubridate, sandwich, lmtest, car, xtable, stargazer, ranger, grf, gridExtra, scales
