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
├── R/                                # Core analysis scripts (execute in order)
│   ├── 01_data_loading.R             # Load & merge monthly, daily, hourly data
│   ├── 02_data_description.R         # Descriptive statistics & visualizations
│   ├── 03_shock_identification.R     # MP shock identification (purging + RF)
│   ├── 04_event_studies.R            # Daily & hourly event studies
│   ├── 05_local_projections.R        # Jordà local projections (EUR/CHF, CPI)
│   ├── 06_regime_analysis.R          # Positive vs negative rate regime comparison
│   ├── 07_machine_learning.R         # Causal Forest for heterogeneous effects
│   └── 08_robustness.R              # Robustness across control specifications
│
├── extensions/                       # 7 methodological extensions (self-contained)
│   ├── run_extensions.R              # Master script for all extensions
│   ├── R/
│   │   ├── 01_hf_identification.R    # High-frequency IV estimation (2SLS)
│   │   ├── 02_smooth_transition.R    # Smooth transition local projections
│   │   ├── 03_wild_bootstrap.R       # Wild bootstrap confidence intervals
│   │   ├── 04_placebo_tests.R        # Placebo / falsification tests
│   │   ├── 05_information_effects.R  # Info vs pure MP shock decomposition
│   │   ├── 06_additional_outcomes.R  # LPs for yields and KOF barometer
│   │   └── 07_asymmetry_tests.R      # Size & sign asymmetry + quantile regression
│   ├── output/
│   │   ├── figures/                  # Extension plots (17 PDFs)
│   │   └── tables/                   # Extension LaTeX tables (9 files)
│   └── doc/
│       ├── extensions_paper.tex      # Self-contained LaTeX companion document
│       └── ref_ext.bib               # Bibliography for extensions
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

### Methodological Extensions

Seven self-contained extensions complement the core analysis. They are located in `extensions/` and require the core pipeline to have run first (to generate the `.RData` files).

| # | Extension | Method | Key Output |
|---|-----------|--------|------------|
| 1 | **High-Frequency Identification** | IV-LP using intraday EUR/CHF in [-1h, +1h] around 09:30 CET announcements as instrument for mp_shock (2SLS) | `irf_hf_vs_baseline.pdf`, first-stage diagnostics |
| 2 | **Smooth Transition LPs** | Logistic transition function G(policy_rate; gamma, c=0%) replaces hard regime dummy; grid search over gamma = {1, 3, 5, 10} | `irf_smooth_transition_fx.pdf`, `transition_function.pdf` |
| 3 | **Wild Bootstrap CIs** | Rademacher wild bootstrap (B=999) under imposed null for LP standard errors; percentile-t confidence intervals | `irf_bootstrap_fx.pdf`, NW vs bootstrap comparison |
| 4 | **Placebo / Falsification** | LPs on predicted component from no-change meetings + permutation test (N=500 random reassignments) | `placebo_fx.pdf`, permutation p-values |
| 5 | **Information Effects** | Shock decomposition into pure MP vs information components via yield co-movement sign restrictions (Jarocinski-Karadi approach) | `info_vs_mp_classification.pdf`, separate IRFs |
| 6 | **Additional Outcomes** | LPs for 2Y yield, 10Y yield, and KOF barometer to trace full transmission mechanism | `irf_all_outcomes.pdf` (multi-panel) |
| 7 | **Asymmetry Tests** | Sign asymmetry (cuts vs hikes), size asymmetry (large vs small), Wald tests at each horizon, quantile regression at tau = {0.25, 0.50, 0.75} | `irf_sign_asymmetry_fx.pdf`, `irf_size_asymmetry_fx.pdf` |

A self-contained LaTeX companion document (`extensions/doc/extensions_paper.tex`) presents all results with motivation, methodology, and discussion for each extension.

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

#### Extension Figures (`extensions/output/figures/`)

| Figure | Description |
|--------|-------------|
| `irf_hf_vs_baseline.pdf` | IV-LP vs OLS-LP impulse response comparison |
| `transition_function.pdf` | Logistic transition function for different gamma values |
| `irf_smooth_transition_fx.pdf` / `_cpi.pdf` | Smooth transition LP impulse responses by regime |
| `irf_bootstrap_fx.pdf` / `_cpi.pdf` | Newey-West vs wild bootstrap confidence intervals |
| `placebo_fx.pdf` / `_cpi.pdf` | Placebo and permutation test results |
| `info_vs_mp_classification.pdf` | Shock classification scatter plot |
| `irf_info_vs_mp_fx.pdf` / `_cpi.pdf` | Pure MP vs information shock IRFs |
| `irf_all_outcomes.pdf` | Multi-panel IRFs across all transmission channels |
| `irf_yield_2y.pdf` / `irf_yield_10y.pdf` / `irf_kof.pdf` | Individual outcome IRFs |
| `irf_sign_asymmetry_fx.pdf` | Sign asymmetry: easing vs tightening |
| `irf_size_asymmetry_fx.pdf` | Size asymmetry: large vs small shocks |

#### Extension Tables (`extensions/output/tables/`)

| Table | Description |
|-------|-------------|
| `hf_first_stage.tex` | First-stage IV diagnostics |
| `irf_hf_comparison.tex` | IV-LP vs OLS-LP coefficient comparison |
| `smooth_transition_results.tex` | Smooth transition LP results |
| `bootstrap_comparison.tex` | Bootstrap vs Newey-West CI comparison |
| `placebo_results.tex` | Placebo and permutation test p-values |
| `info_effects_results.tex` | Information vs pure MP shock responses |
| `additional_outcomes.tex` | Additional outcome variable IRFs |
| `asymmetry_results.tex` | Sign and size asymmetry Wald tests |
| `quantile_regression.tex` | Quantile regression at tau = {0.25, 0.50, 0.75} |

---

### How to Run

**Core pipeline** (8 scripts):

```r
source("run_all.R")
```

**Extensions** (7 scripts, requires core pipeline to finish first):

```r
source("extensions/run_extensions.R")
```

The core pipeline executes all 8 scripts sequentially. Intermediate `.RData` files are saved in the working directory and output is written to `output/figures/` and `output/tables/`. The extensions pipeline then builds on these `.RData` files and writes to `extensions/output/`.

### Requirements

- **R** (>= 4.0)
- **Core packages:** tidyverse, ggplot2, lubridate, sandwich, lmtest, car, xtable, stargazer, ranger, grf, gridExtra, scales
- **Extension packages:** ivreg, quantreg (installed automatically by `run_extensions.R` if missing)

Install all dependencies:

```r
install.packages(c("tidyverse", "lubridate", "sandwich", "lmtest", "car",
                    "xtable", "stargazer", "ranger", "grf", "gridExtra", "scales",
                    "ivreg", "quantreg"))
```

---

### License

This repository is provided for academic and educational purposes.
