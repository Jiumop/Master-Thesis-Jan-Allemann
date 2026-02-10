# Master Thesis — Jan Allemann

## Monetary Policy Transmission in Switzerland: Exchange Rate and Inflation Responses to Rate Cuts, 2000–2025

**University of Bern, Faculty of Economics**
Master in International and Monetary Economics
Supervisor: Prof. Dr. Costanza Naguib

---

### Abstract

This thesis examines Swiss monetary policy transmission from 2000 to 2025 by combining a Swiss-calibrated small open economy DSGE model with empirical evidence using purging regression identification and local projections. The analysis investigates how unexpected SNB rate cuts affect the EUR/CHF exchange rate and inflation across positive and negative interest rate regimes.

Three main findings emerge:
1. Rate cuts depreciate the Swiss franc by **4.5% per percentage point shock**, confirming theoretical predictions but exceeding model magnitudes, suggesting stronger transmission during crisis episodes.
2. Inflation shows **weak pooled responses**, validating New Keynesian mechanisms of incomplete pass-through and habit formation.
3. Regime analysis reveals **large inflation asymmetries during negative rates**, though these reflect the extraordinary 2015 EUR/CHF floor removal rather than general negative-rate properties.

**Keywords:** Monetary policy transmission, small open economy, DSGE model, exchange rate, inflation, negative interest rates, Switzerland

---

### Research Questions

- **RQ1:** What is the effect of an unexpected SNB rate cut on (i) the EUR/CHF exchange rate and (ii) Swiss inflation between 2000–2025?
- **RQ2:** Can the transmission mechanisms of a Swiss-calibrated SOE DSGE model be empirically validated using structural identification combined with machine-learning methods?

---

### Project Structure

```
├── run_all.R                         # Master script — runs entire pipeline
│
├── R/                                # Analysis scripts (execute in order)
│   ├── 01_data_loading.R             # Load & merge monthly, daily, hourly data
│   ├── 02_data_description.R         # Descriptive statistics & visualizations
│   ├── 03_shock_identification.R     # MP shock identification (purging + RF)
│   ├── 04_event_studies.R            # Daily & hourly event studies
│   ├── 05_local_projections.R        # Jordà local projections (EUR/CHF, CPI)
│   ├── 06_regime_analysis.R          # Positive vs negative rate regime comparison
│   ├── 07_machine_learning.R         # Causal Forest for heterogeneous effects
│   └── 08_robustness.R              # Robustness across control specifications
│
├── data/                             # Input datasets
│   ├── swiss_monetary_monthly.csv    # Monthly macro indicators (CPI, KOF, yields, etc.)
│   ├── snb_announcements.csv         # SNB policy rate decisions & actions
│   ├── EUR_CHF_1day.csv              # Daily EUR/CHF exchange rate
│   └── EUR_CHF_1h.csv                # Hourly EUR/CHF exchange rate
│
├── output/
│   ├── figures/                      # Generated plots (PDF)
│   └── tables/                       # Generated LaTeX tables
│
└── thesis/
    ├── Masterthesis_Jan_Allemann.pdf  # Final thesis document
    ├── MA_final.tex                  # LaTeX source
    └── ref5.bib                      # Bibliography
```

---

### Methodology

#### 1. Data

| Dataset | Frequency | Period | Description |
|---------|-----------|--------|-------------|
| `swiss_monetary_monthly.csv` | Monthly | 2000–2025 | CPI (YoY), KOF Barometer, 2Y yield, VIX, EUR/CHF |
| `snb_announcements.csv` | Event | 2000–2025 | SNB policy rate decisions, LIBOR target ranges, rate actions |
| `EUR_CHF_1day.csv` | Daily | 2000–2025 | EUR/CHF spot rate, log returns |
| `EUR_CHF_1h.csv` | Hourly | 2020–2025 | EUR/CHF intraday data for high-frequency event studies |

Two interest rate regimes are defined:
- **Positive rate regime**: Before Dec 2014 and from Jun 2022 onward
- **Negative rate regime**: Dec 2014 – Jun 2022

#### 2. Shock Identification (`03_shock_identification.R`)

Monetary policy shocks are identified via a **purging regression** that removes the predictable component of SNB rate decisions. Control variables are selected data-driven using **Random Forest variable importance** (Gini index), rather than imposed ad hoc. The residuals from this regression serve as the identified monetary policy shock series.

#### 3. Event Studies (`04_event_studies.R`)

Regression-based event studies estimate the EUR/CHF response in a **[-10, +10] day window** around each rate cut announcement, as well as a **[-6, +6] hour window** for recent events where intraday data is available. Each horizon is estimated separately with heteroskedasticity-robust (HC1) standard errors.

#### 4. Local Projections (`05_local_projections.R`)

Following [Jordà (2005)](https://doi.org/10.1257/0002828053828518), impulse response functions are estimated for:
- **EUR/CHF exchange rate** response (1–12 month horizons)
- **CPI inflation** response (1–12 month horizons)

Standard errors are computed using Newey-West HAC estimators with lag length equal to the projection horizon.

#### 5. Regime Analysis (`06_regime_analysis.R`)

The shock variable is interacted with regime indicators to estimate **separate impulse responses under positive and negative rate environments**. A Wald test formally tests whether transmission differs across regimes at each horizon.

#### 6. Machine Learning (`07_machine_learning.R`)

A **Causal Forest** (Athey & Imbens, 2018) estimates conditional average treatment effects (CATEs), allowing the data to reveal heterogeneity in how monetary policy shocks transmit across different macroeconomic states and regimes.

#### 7. Robustness (`08_robustness.R`)

Three control specifications are compared:
- No controls (baseline)
- Lagged controls only (KOF, CPI)
- Full data-driven controls (RF-selected)

Regime-dependent results are also re-estimated under alternative specifications with Wald tests.

---

### Key Output

#### Figures

| Figure | Description |
|--------|-------------|
| `policy_rate_timeline.pdf` | SNB policy rate history with rate changes and LIBOR range |
| `key_variables_timeline.pdf` | CPI, KOF, EUR/CHF, VIX time series |
| `variable_importance_selection.pdf` | Random Forest variable importance for control selection |
| `daily_event_study.pdf` | EUR/CHF response [-10, +10] days around rate cuts |
| `hourly_event_study.pdf` | EUR/CHF response [-6, +6] hours around rate cuts |
| `daily_cumulative_response.pdf` | Cumulative EUR/CHF response post-announcement |
| `irf_eur_chf.pdf` | Local projection IRF: EUR/CHF (1–12 months) |
| `irf_cpi.pdf` | Local projection IRF: CPI inflation (1–12 months) |
| `irf_eur_chf_regime.pdf` | EUR/CHF IRF by regime (positive vs negative rates) |
| `irf_cpi_regime.pdf` | CPI IRF by regime (positive vs negative rates) |
| `cate_by_regime.pdf` | Causal Forest treatment effect heterogeneity |
| `prediction_comparison.pdf` | Out-of-sample prediction validation |

#### Tables

| Table | Description |
|-------|-------------|
| `summary_stats.tex` | Descriptive statistics (2000–2025) |
| `purging_regression.tex` | Purging regression with data-driven controls |
| `lp_fx.tex` / `lp_cpi.tex` | Local projection coefficients at key horizons |
| `lp_fx_regime.tex` / `lp_cpi_regime.tex` | Regime-dependent IRF coefficients with Wald tests |
| `robustness_fx.tex` / `robustness_cpi.tex` | Robustness across control specifications |

---

### How to Run

1. Open R or RStudio
2. Run the full pipeline:

```r
source("run_all.R")
```

This executes all 8 scripts sequentially. Intermediate `.RData` files are saved in the working directory and output is written to `output/figures/` and `output/tables/`.

### Requirements

- **R** (>= 4.0)
- **Packages:** tidyverse, ggplot2, lubridate, sandwich, lmtest, car, xtable, stargazer, ranger, grf, gridExtra, scales

Install all dependencies:

```r
install.packages(c("tidyverse", "lubridate", "sandwich", "lmtest", "car",
                    "xtable", "stargazer", "ranger", "grf", "gridExtra", "scales"))
```

---

### License

This repository is provided for academic and educational purposes.
