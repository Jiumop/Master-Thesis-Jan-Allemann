# Master Thesis — Jan Allemann

## Monetary Policy Transmission in Switzerland: Exchange Rate and Inflation Responses to Rate Cuts, 2000–2025

**University of Bern, Faculty of Economics**
Master in International and Monetary Economics

---

### Abstract

This thesis examines Swiss monetary policy transmission from 2000 to 2025 by combining a Swiss-calibrated small open economy DSGE model with empirical evidence using purging regression identification and local projections. The analysis investigates how unexpected SNB rate cuts affect the EUR/CHF exchange rate and inflation across positive and negative interest rate regimes.

Three main findings emerge:
1. Rate cuts depreciate the Swiss franc by **4.5% per percentage point shock**, confirming theoretical predictions but exceeding model magnitudes, suggesting stronger transmission during crisis episodes.
2. Inflation shows **weak pooled responses**, validating New Keynesian mechanisms of incomplete pass-through and habit formation.
3. Regime analysis reveals **large inflation asymmetries during negative rates**, though these reflect the extraordinary 2015 EUR/CHF floor removal rather than general negative-rate properties.

**Keywords:** Monetary policy transmission, small open economy, DSGE model, exchange rate, inflation, negative interest rates, Switzerland

---

### Key Results

#### EUR/CHF Exchange Rate Response

A 1 percentage point unexpected rate cut depreciates the Swiss franc significantly in the short run, with the effect fading over time:

| Horizon | Coefficient | SE | 95% CI | p-value |
|---------|------------|-----|--------|---------|
| 1 month | **4.53\*\*\*** | 1.47 | [1.64, 7.42] | 0.002 |
| 3 months | **3.61\*\*\*** | 1.32 | [1.02, 6.20] | 0.006 |
| 6 months | **2.75\*\*** | 1.30 | [0.20, 5.30] | 0.035 |
| 12 months | 0.57 | 2.01 | [-3.36, 4.51] | 0.776 |

> Peak depreciation of **4.5% at 1 month**, statistically significant through 6 months, consistent with DSGE predictions but larger in magnitude.

#### CPI Inflation Response

Inflation responses to rate cuts are economically small and statistically insignificant in the pooled sample:

| Horizon | Coefficient | SE | 95% CI | p-value |
|---------|------------|-----|--------|---------|
| 1 month | 0.14 | 0.29 | [-0.42, 0.70] | 0.627 |
| 6 months | 0.07 | 0.44 | [-0.79, 0.93] | 0.870 |
| 12 months | -0.29 | 0.58 | [-1.42, 0.85] | 0.618 |

> Weak pass-through confirms the DSGE model's incomplete exchange rate pass-through and habit formation mechanisms.

#### Regime-Dependent Transmission

Transmission differs sharply between positive and negative interest rate environments:

| | Positive Rates | Negative Rates | Wald p-value |
|---|---|---|---|
| **EUR/CHF (h=1)** | 4.13\*\*\* (1.26) | 11.22 (18.06) | 0.696 |
| **EUR/CHF (h=12)** | 1.42 (1.86) | -13.32\*\* (6.73) | **0.032** |
| **CPI (h=1)** | 0.07 (0.29) | 1.23\*\*\* (0.14) | **0.001** |
| **CPI (h=6)** | -0.16 (0.45) | 3.92\*\*\* (0.54) | **0.000** |
| **CPI (h=12)** | -0.66 (0.46) | 5.79\*\*\* (0.93) | **0.000** |

> CPI responses under negative rates are large and highly significant (Wald F up to 40.24), but driven by the extraordinary 2015 EUR/CHF floor removal event.

---

### Extension Results

The seven extensions refine the main findings along three dimensions: **identification**, **inference**, and **heterogeneity**. The most robust result across all methods is the immediate ~4.5% depreciation per pp shock. Full discussion with RQ linkage is in `extensions/doc/extensions_paper.pdf`.

#### Ext. 1 — High-Frequency IV Identification

First-stage F-statistic = 0.62 (weak instrument, well below the threshold of 10). The intraday EUR/CHF surprise is not a strong predictor of the monthly purging-regression residual, likely because (i) only 25 events have hourly data (2020+) and (ii) the hourly market reaction does not map linearly onto the monthly shock. IV-LP estimates are consequently uninformative:

| Method | h = 1 | h = 3 | h = 6 | h = 12 |
|--------|-------|-------|-------|--------|
| IV-LP (HF) | -30.61 (47.50) | -26.86 (66.92) | -79.30 (82.95) | -451.07 (2831.50) |
| OLS-LP | -2.79 (2.12) | -9.68\*\*\* (1.89) | -3.62 (3.25) | 17.48\*\*\* (5.02) |

> **Takeaway:** The IV failure does not invalidate the baseline --- it underscores the sample constraint. The purging regression remains the most feasible identification strategy with available data.

#### Ext. 2 — Smooth Transition LPs

With logistic transition (gamma=5, threshold=0%), the normal-rate regime estimates (4.22% at h=1) closely match the pooled baseline (4.53%) and are **stable across all gamma values**. Low-rate estimates are large but imprecise, and **sensitive to gamma**, confirming that the regime asymmetry is driven by few extreme observations (2015 floor removal) rather than a smooth structural shift:

| Horizon | Low-Rate Regime | Normal-Rate Regime | Difference |
|---------|-----------------|-------------------|------------|
| 1 | 8.39 (15.75) | 4.22 (1.26) | +4.17 |
| 3 | 16.11 (11.37) | 2.62 (1.08) | +13.49 |
| 6 | 9.63 (8.71) | 2.20 (1.28) | +7.43 |
| 12 | -14.89 (8.33) | 1.77 (1.84) | -16.66 |

> **Takeaway:** Strengthens the ~4% core finding under normal rates. Supports the thesis's cautious interpretation that negative-rate regime differences reflect the 2015 episode rather than general ELB properties. Aligns with the DSGE model's prediction of minimal regime differences.

#### Ext. 3 — Wild Bootstrap CIs

The Rademacher wild bootstrap (B=999) produces wider CIs than Newey-West, refining the significance assessment:

| Horizon | Coeff | NW 95% CI | NW p | Bootstrap 95% CI | Boot p |
|---------|-------|-----------|------|-----------------|--------|
| 1 | 4.53 | [2.17, 6.89] | 0.000 | [0.72, 8.88] | 0.025 |
| 3 | 3.61 | [1.02, 6.20] | 0.006 | [-0.71, 9.23] | 0.128 |
| 6 | 2.75 | [0.20, 5.30] | 0.034 | [-0.47, 8.08] | 0.293 |
| 12 | 0.57 | [-4.15, 5.29] | 0.813 | [-2.36, 9.08] | 0.848 |

> **Takeaway:** The **impact effect (h=1) is robust** to inference method (p=0.025). Persistence beyond 1 month (h=3, h=6) should be interpreted more cautiously --- Newey-West appears optimistic in this small sample. This narrows the main finding from "significant through 6 months" to **"robust impact depreciation with suggestive persistence."**

#### Ext. 4 — Placebo / Falsification Tests

Placebo shocks (fitted values from 68 no-change meetings) produce near-zero responses, while the permutation test (N=500) provides direct falsification evidence:

| Variable | h = 1 | h = 3 | h = 6 | h = 12 |
|----------|-------|-------|-------|--------|
| Actual (FX) | 4.53 | 3.61 | 2.75 | 0.57 |
| Placebo (FX) | -0.57 | 0.97 | 1.49 | 2.06 |
| Perm. p (FX) | **0.018** | 0.116 | 0.344 | 0.878 |

> **Takeaway:** The **strongest validation of the identification strategy**. Anticipated policy (fitted values) generates no FX response; the actual shock is significant in only 1.8% of random permutations at h=1. This confirms that the purging regression isolates genuine policy surprises, at least at impact. Declining permutation significance at longer horizons is consistent with the bootstrap results.

#### Ext. 5 — Information Effects

Decomposing shocks via yield co-movement (simplified Jarocinski-Karadi approach) reveals that the baseline estimates blend two distinct channels:

| Component | h = 1 | h = 3 | h = 6 | h = 12 |
|-----------|-------|-------|-------|--------|
| Pure MP (FX) | 4.33 | 3.34 | 2.90 | 0.25 |
| Information (FX) | 6.60 | 6.37 | 1.19 | 3.70 |
| Pure MP (CPI) | 0.06 | -0.24 | 0.25 | -0.08 |
| Information (CPI) | 0.91 | 0.49 | -1.75 | -2.32 |

> **Takeaway:** Pure MP shocks produce **4.3% FX depreciation and near-zero CPI effects** --- closely matching the DSGE model's predictions and validating its incomplete pass-through mechanism (9% immediate pass-through) even more strongly than the pooled results. Information shocks generate larger but less persistent FX effects, and a CPI sign reversal (initial inflation then disinflation) consistent with markets learning negative economic news. This suggests the **DSGE model is well-calibrated to the pure monetary channel** (RQ2).

#### Ext. 6 — Additional Outcome Variables

| Horizon | 2Y Yield | 10Y Yield | KOF |
|---------|----------|-----------|-----|
| 1 | 0.119 (0.115) | -0.106 (0.216) | 2.919 (4.148) |
| 6 | -0.390 (0.247) | **-0.643\*\*\*** (0.141) | -4.591 (4.707) |
| 12 | 0.290 (0.276) | -0.002 (0.189) | -1.113 (4.141) |

> **Takeaway:** The **10-year yield declines significantly at 6 months (-0.64pp, p<0.01)**, validating the DSGE model's expectations channel: rate cuts transmit to longer maturities through expectations, with the full effect materializing at 6 months. KOF responses are noisy, reflecting the endogeneity of rate cuts to economic weakness. The 2Y yield's initial positive response is consistent with the information effect channel (Section 5).

#### Ext. 7 — Asymmetry Tests

No statistically significant asymmetry by sign or size (all Wald p-values > 0.10):

| Horizon | Cuts | Hikes | Sign Wald p | Large | Small | Size Wald p |
|---------|------|-------|-------------|-------|-------|-------------|
| 1 | 3.13\* | 6.83\*\* | 0.300 | 3.56\*\* | 23.04 | 0.375 |
| 3 | 3.06 | 4.52\* | 0.711 | 2.50\*\* | 24.96 | 0.316 |
| 12 | -4.10 | 8.14 | 0.265 | -0.88 | 33.88 | 0.130 |

> **Takeaway:** The **linear specification is justified** --- the 4.5% depreciation applies symmetrically to cuts/hikes and large/small shocks. This importantly distinguishes shock-level symmetry (not rejected) from the regime-level asymmetry (strongly significant in the thesis), confirming that regime dependence operates through structural changes (2015 floor removal) rather than nonlinear responses to shock characteristics. Quantile regression at the median (3.04\*\*\* at h=1) confirms the mean result.

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
│       ├── extensions_paper.pdf      # Compiled extensions document
│       └── ref_ext.bib               # Bibliography for extensions
│
├── Dynare/                           # DSGE model simulations
│   ├── dsge_gali.mod                 # Baseline Galí (2015) specification
│   ├── dsge_swiss_base.mod           # Swiss-calibrated model (Cuche-Curti et al.)
│   ├── dsge_full_rega.mod            # Regime A: positive interest rates
│   ├── dsge_full_regb.mod            # Regime B: negative/zero interest rates
│   ├── dsge_unstable.mod             # Stability test with extreme ER leaning
│   └── IRF_figures.m                 # MATLAB script for IRF visualization
│
├── data/                             # Input datasets
│   ├── swiss_monetary_monthly.csv    # Monthly macro indicators (CPI, KOF, yields, etc.)
│   ├── snb_announcements.csv         # SNB policy rate decisions & actions
│   ├── EUR_CHF_1day.csv              # Daily EUR/CHF exchange rate
│   └── EUR_CHF_1h.csv                # Hourly EUR/CHF exchange rate
│
├── cache/                            # Pipeline intermediates (.RData, gitignored)
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

#### 1. DSGE Model (`Dynare/`)

A small open economy New Keynesian DSGE model is calibrated to Switzerland using Dynare/MATLAB. Five model variants are estimated:

| Model | Key Features | Purpose |
|-------|-------------|---------|
| **Galí Baseline** | Standard 3-equation NK model | Reference specification |
| **Swiss Base** | Swiss calibration + habit formation + interest rate smoothing | Country-specific fit |
| **Regime A** | Full extensions + positive-rate parameters (phi_pi=2.00) | Normal policy environment |
| **Regime B** | Full extensions + negative-rate parameters (phi_pi=1.70) | Low/negative rate environment |
| **Unstable** | Extreme ER leaning (phi_ds=1.5) | Determinacy boundary test |

Swiss calibration: beta=0.995, sigma=1.32, openness=0.40 (Cuche-Curti et al., 2009). Extensions include habit persistence, price indexation, incomplete exchange rate pass-through, and exchange rate leaning in the Taylor rule.

#### 2. Data

The dataset spans **January 2000 to December 2025** (~300 monthly observations, 109 announcement events, 19 rate cuts). Data sources:

| Variable | Source |
|----------|--------|
| EUR/CHF exchange rate (daily & hourly) | TwelveData API |
| CPI inflation (YoY) | Federal Statistical Office (BFS) |
| SNB policy rates & LIBOR target ranges | SNB Statistical Data Portal |
| KOF Economic Barometer | KOF Swiss Economic Institute, ETH Zurich |
| 2-Year government bond yield | SNB |
| VIX volatility index | CBOE |
| Announcement dates & rate actions | SNB press releases & monetary policy assessments |

| Dataset | Frequency | Period | Description |
|---------|-----------|--------|-------------|
| `swiss_monetary_monthly.csv` | Monthly | 2000–2025 | CPI (YoY), KOF Barometer, 2Y yield, VIX, EUR/CHF |
| `snb_announcements.csv` | Event | 2000–2025 | SNB policy rate decisions, LIBOR target ranges, rate actions |
| `EUR_CHF_1day.csv` | Daily | 2000–2025 | EUR/CHF spot rate, log returns |
| `EUR_CHF_1h.csv` | Hourly | 2020–2025 | EUR/CHF intraday data for high-frequency event studies |

Two interest rate regimes are defined:
- **Positive rate regime**: Before Dec 2014 and from Jun 2022 onward
- **Negative rate regime**: Dec 2014 – Jun 2022

#### 3. Shock Identification (`03_shock_identification.R`)

Monetary policy shocks are identified via a **purging regression** that removes the predictable component of SNB rate decisions. Control variables are selected data-driven using **Random Forest variable importance** (Gini index), rather than imposed ad hoc. The residuals from this regression serve as the identified monetary policy shock series.

#### 4. Event Studies (`04_event_studies.R`)

Regression-based event studies estimate the EUR/CHF response in a **[-10, +10] day window** around each rate cut announcement, as well as a **[-6, +6] hour window** for recent events where intraday data is available.

#### 5. Local Projections (`05_local_projections.R`)

Following [Jorda (2005)](https://doi.org/10.1257/0002828053828518), impulse response functions are estimated for EUR/CHF and CPI at horizons 1–12 months. Standard errors use Newey-West HAC estimators.

#### 6. Regime Analysis (`06_regime_analysis.R`)

The shock variable is interacted with regime indicators to estimate **separate impulse responses under positive and negative rate environments**. Wald tests formally test whether transmission differs across regimes.

#### 7. Machine Learning (`07_machine_learning.R`)

A **Causal Forest** (Athey & Imbens, 2018) estimates conditional average treatment effects (CATEs), revealing heterogeneity in monetary policy transmission across macroeconomic states.

#### 8. Robustness (`08_robustness.R`)

Three control specifications are compared: no controls, lagged controls (KOF, CPI), and full RF-selected controls. Results are robust across specifications.

---

### Methodological Extensions

Seven self-contained extensions complement the core analysis. They are located in `extensions/` and require the core pipeline to have run first.

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

### How to Run

**DSGE simulations** (requires MATLAB + Dynare):

```matlab
% In MATLAB, from Dynare/ folder:
run('IRF_figures.m')
```

**Core pipeline** (8 scripts):

```r
source("run_all.R")
```

**Extensions** (7 scripts, requires core pipeline to finish first):

```r
source("extensions/run_extensions.R")
```

The core pipeline executes all 8 scripts sequentially. Intermediate `.RData` files are saved in `cache/` (gitignored) and output is written to `output/figures/` and `output/tables/`. The extensions pipeline then builds on these cached `.RData` files and writes to `extensions/output/`.

### Requirements

- **DSGE:** MATLAB (>= R2020a) with [Dynare](https://www.dynare.org/) (>= 5.0)
- **R** (>= 4.0)
- **Core packages:** tidyverse, ggplot2, lubridate, sandwich, lmtest, car, xtable, stargazer, ranger, grf, gridExtra, scales
- **Extension packages:** ivreg, quantreg (installed automatically by `run_extensions.R` if missing)

Install all R dependencies:

```r
install.packages(c("tidyverse", "lubridate", "sandwich", "lmtest", "car",
                    "xtable", "stargazer", "ranger", "grf", "gridExtra", "scales",
                    "ivreg", "quantreg"))
```

---

### License

This repository is provided for academic and educational purposes.
