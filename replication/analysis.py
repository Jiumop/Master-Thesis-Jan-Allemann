"""
Corrected replication of the empirical part of
"Monetary Policy Transmission in Switzerland" (Allemann).

Run:  python3 replication/analysis.py            (from the repo root)
Needs: pandas, numpy, statsmodels, matplotlib
Writes: replication/output/{tables,figures}/ and replication/output/results.json

Corrections relative to the original R pipeline (R/01-06):
  1. Monthly EUR/CHF change = change in month-end log level
     (original used the last trading day's daily return).
  2. Shock sign made explicit: purging residual > 0 = tightening surprise.
     All impulse responses are reported for a 1pp EASING surprise (shock = -1).
  3. Purging regression on ALL policy meetings (cuts, holds, hikes) with
     predetermined (t-1) controls only (original: 19 cut months, contemporaneous
     2y yield and VIX, controls selected by predicting the FX outcome).
  4. Rate decisions announced together with unconventional measures
     (12 Mar 2009 FX interventions, 15 Jan 2015 floor exit) are not treated as
     rate surprises; the floor introduction (6 Sep 2011) and these two events
     are absorbed with window dummies.
  5. LPs start at h = 0 (month of the decision), include two lags of the
     outcome change and of the shock, and use HAC lags = h + 1.
  6. Inflation outcome = cumulative change in the log CPI level.
  7. Event studies index trading days, not calendar days; the hourly data are
     time-stamped in Australia/Sydney local time (bar start) and are aligned to
     the 09:30 Zurich announcement time.
"""
import json
import os
import warnings

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

warnings.filterwarnings("ignore")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
OUT = os.path.join(ROOT, "replication", "output")
os.makedirs(os.path.join(OUT, "tables"), exist_ok=True)
os.makedirs(os.path.join(OUT, "figures"), exist_ok=True)
RES = {}

# --------------------------------------------------------------------------
# 1. Data
# --------------------------------------------------------------------------
m = pd.read_csv(os.path.join(DATA, "swiss_monetary_monthly.csv"), parse_dates=["date"])
ann = pd.read_csv(os.path.join(DATA, "snb_announcements.csv"), parse_dates=["date"])
d = pd.read_csv(os.path.join(DATA, "EUR_CHF_1day.csv"), parse_dates=["datetime"])
hr = pd.read_csv(os.path.join(DATA, "EUR_CHF_1h.csv"), parse_dates=["datetime"])

m["ym"] = m.date.dt.to_period("M")
d["ym"] = d.datetime.dt.to_period("M")
fx_me = d.groupby("ym").tail(1).set_index("ym")["eur_chf"]
m["fx"] = np.log(m.ym.map(fx_me)) * 100          # month-end log EUR/CHF x100
m["p"] = np.log(m.cpi_index) * 100                 # log CPI x100

# Meetings with a known policy rate (Dec 2000 onward)
mt = ann.dropna(subset=["unified_policy_rate"]).copy()
mt["di"] = (mt.rate_to - mt.rate_from).round(4)
mt["ym"] = mt.date.dt.to_period("M")
CONFOUNDED = [pd.Timestamp("2009-03-12"), pd.Timestamp("2015-01-15")]
mt["confounded"] = mt.date.isin(CONFOUNDED)
agg = mt.groupby("ym").agg(di=("di", "sum"), n_meet=("di", "size"),
                           confounded=("confounded", "max"),
                           rate_end=("unified_policy_rate", "last"))
m = m.merge(agg, left_on="ym", right_index=True, how="left")
m["meeting"] = m.n_meet.notna().astype(int)
m["di"] = m.di.fillna(0.0)
m["confounded"] = m.confounded.fillna(False).astype(bool)
m["i"] = m.rate_end.ffill()
m.loc[m.i.isna(), "i"] = 3.5                      # Nov 2000 (target-range midpoint)

# Predetermined controls (information available before the decision)
m["dfx"] = m.fx.diff()
m["dp"] = m.p.diff()
m["di_m"] = m.i.diff()
m["i_l1"] = m.i.shift(1)
m["dfx_l1"] = m.dfx.shift(1)
m["dy2_l1"] = m.yield_2y.diff().shift(1)
m["vix_l1"] = m.vix.shift(1)
m["neg"] = ((m.date >= "2014-12-01") & (m.date < "2022-06-01")).astype(int)
CTRL = "cpi_yoy_lag1 + kof_lag1 + i_l1 + dfx_l1 + dy2_l1 + vix_l1"

# --------------------------------------------------------------------------
# 2. Purging regression on all meetings
# --------------------------------------------------------------------------
pm_data = m[(m.meeting == 1) & (~m.confounded)].dropna(subset=CTRL.split(" + "))
purge = smf.ols("di ~ " + CTRL, data=pm_data).fit(cov_type="HC1")
m["shock"] = 0.0
m.loc[pm_data.index, "shock"] = purge.resid
RES["purge"] = dict(n=int(purge.nobs), r2=purge.rsquared, r2_adj=purge.rsquared_adj,
                    n_cut=int((pm_data.di < 0).sum()), n_hike=int((pm_data.di > 0).sum()),
                    n_hold=int((pm_data.di == 0).sum()),
                    sd_shock=float(purge.resid.std()),
                    coefs={k: [float(purge.params[k]), float(purge.bse[k])] for k in purge.params.index})
with open(os.path.join(OUT, "tables", "purging.md"), "w") as f:
    f.write("| Variable | Coef. | Robust SE |\n|---|---|---|\n")
    for k in purge.params.index:
        f.write(f"| {k} | {purge.params[k]:.3f} | ({purge.bse[k]:.3f}) |\n")
    f.write(f"| N / R2 / adj. R2 | {int(purge.nobs)} | {purge.rsquared:.3f} / {purge.rsquared_adj:.3f} |\n")

for l in (1, 2):
    m[f"shock_l{l}"] = m.shock.shift(l)
    m[f"dfx_l{l}x"] = m.dfx.shift(l)
    m[f"dp_l{l}x"] = m.dp.shift(l)
    m[f"di_m_l{l}x"] = m.di_m.shift(l)

EVENTS = {"ev2009": "2009-03", "ev2011": "2011-09", "ev2015": "2015-01"}
H = list(range(0, 13))
LAGS = {"fx": "dfx", "p": "dp", "i": "di_m"}


def window_dummies(df, h):
    cols = []
    for name, e in EVENTS.items():
        e = pd.Period(e, "M")
        df[f"{name}_{h}"] = ((df.ym <= e) & (df.ym + h >= e)).astype(int)
        cols.append(f"{name}_{h}")
    return cols


def lp(df, var, h, shock="shock", dummies=True, ctrl=CTRL, extra_shocks=None):
    df = df.copy()
    df["y"] = df[var].shift(-h) - df[var].shift(1)
    lag = LAGS[var]
    rhs = [shock, f"{lag}_l1x", f"{lag}_l2x", "shock_l1", "shock_l2"]
    if extra_shocks:
        rhs = extra_shocks + rhs[1:]
    if ctrl:
        rhs += ctrl.split(" + ")
    if dummies:
        rhs += window_dummies(df, h)
    r = smf.ols("y ~ " + " + ".join(rhs), data=df).fit(cov_type="HAC", cov_kwds={"maxlags": h + 1})
    return r


def irf(df, var, **kw):
    rows = []
    for h in H:
        r = lp(df, var, h, **kw)
        b, s = -r.params[kw.get("shock", "shock")], r.bse[kw.get("shock", "shock")]
        rows.append(dict(h=h, b=b, se=s, lo=b - 1.96 * s, hi=b + 1.96 * s, p=float(r.pvalues[kw.get("shock", "shock")]), n=int(r.nobs)))
    return pd.DataFrame(rows)


# --------------------------------------------------------------------------
# 3. Baseline LPs (response to a 1pp EASING surprise)
# --------------------------------------------------------------------------
base = {v: irf(m, v) for v in ["i", "fx", "p"]}
for v, t in base.items():
    t.to_csv(os.path.join(OUT, "tables", f"lp_{v}.csv"), index=False)
RES["lp"] = {v: t.round(4).to_dict("records") for v, t in base.items()}

fig, ax = plt.subplots(1, 3, figsize=(13, 3.6))
titles = {"i": "Policy rate (pp)", "fx": "EUR/CHF (%; + = CHF depreciation)", "p": "CPI level (%)"}
for a, v in zip(ax, ["i", "fx", "p"]):
    t = base[v]
    a.fill_between(t.h, t.lo, t.hi, alpha=.2, color="C0")
    a.plot(t.h, t.b, "o-", color="C0", ms=3)
    a.axhline(0, color="k", lw=.7, ls="--")
    a.set_title(titles[v], fontsize=10); a.set_xlabel("Months after decision")
fig.suptitle("Local projections: response to a 1pp easing surprise (95% HAC bands)", fontsize=11)
fig.tight_layout(); fig.savefig(os.path.join(OUT, "figures", "irf_baseline.png"), dpi=160)

# --------------------------------------------------------------------------
# 4. Robustness (FX and CPI at selected horizons)
# --------------------------------------------------------------------------
KH = [0, 1, 3, 6, 12]


def pick(t):
    return {int(r.h): (round(r.b, 2), round(r.se, 2)) for r in t.itertuples() if r.h in KH}


rob = {}
rob["Baseline"] = {v: pick(base[v]) for v in ["fx", "p"]}
rob["No event window dummies"] = {v: pick(irf(m, v, dummies=False)) for v in ["fx", "p"]}
mm = m.copy(); mm.loc[(mm.ym >= pd.Period("2008-10", "M")) & (mm.ym <= pd.Period("2009-03", "M")), "shock"] = 0
for l in (1, 2): mm[f"shock_l{l}"] = mm.shock.shift(l)
rob["Excl. GFC easing (Oct 2008-Mar 2009)"] = {v: pick(irf(mm, v)) for v in ["fx", "p"]}
mm = m.copy(); mm["shock"] = np.where(m.meeting == 1, m.di, 0.0); mm.loc[mm.confounded, "shock"] = 0
for l in (1, 2): mm[f"shock_l{l}"] = mm.shock.shift(l)
rob["Raw rate change instead of residual"] = {v: pick(irf(mm, v)) for v in ["fx", "p"]}
mm = m.copy(); mm.loc[mm.date < "2009-04-01", "shock"] = 0
for l in (1, 2): mm[f"shock_l{l}"] = mm.shock.shift(l)
rob["Post-2009 meetings only"] = {v: pick(irf(mm, v)) for v in ["fx", "p"]}
RES["robustness"] = rob
with open(os.path.join(OUT, "tables", "robustness.md"), "w") as f:
    for v, lab in [("fx", "EUR/CHF (%)"), ("p", "CPI level (%)")]:
        f.write(f"\n**{lab}, response to 1pp easing surprise**\n\n| Specification | " + " | ".join(f"h={h}" for h in KH) + " |\n|---|" + "---|" * len(KH) + "\n")
        for k, r in rob.items():
            f.write(f"| {k} | " + " | ".join(f"{r[v][h][0]:.2f} ({r[v][h][1]:.2f})" for h in KH) + " |\n")

# --------------------------------------------------------------------------
# 5. Regime analysis (positive vs negative rate regime)
# --------------------------------------------------------------------------
m["shock_neg"] = m.shock * m.neg
m["shock_pos"] = m.shock * (1 - m.neg)
reg = {}
for v in ["fx", "p"]:
    rows = []
    for h in KH:
        r = lp(m, v, h, shock="shock_pos", extra_shocks=["shock_pos", "shock_neg"])
        w = r.wald_test("shock_pos = shock_neg", scalar=True)
        rows.append(dict(h=h, pos=-r.params.shock_pos, se_pos=r.bse.shock_pos,
                         neg=-r.params.shock_neg, se_neg=r.bse.shock_neg, wald_p=float(w.pvalue)))
    reg[v] = pd.DataFrame(rows)
RES["regime"] = {v: t.round(4).to_dict("records") for v, t in reg.items()}
RES["regime_counts"] = dict(meet_neg=int(((pm_data.neg == 1)).sum()), meet_pos=int((pm_data.neg == 0).sum()),
                            changes_neg=int(((pm_data.neg == 1) & (pm_data.di != 0)).sum()),
                            sd_shock_neg=float(pm_data.loc[pm_data.neg == 1].index.map(m.shock).to_series().std()),
                            sd_shock_pos=float(pm_data.loc[pm_data.neg == 0].index.map(m.shock).to_series().std()))
with open(os.path.join(OUT, "tables", "regime.md"), "w") as f:
    for v, lab in [("fx", "EUR/CHF (%)"), ("p", "CPI level (%)")]:
        f.write(f"\n**{lab}**\n\n| h | Positive regime | Negative regime | Wald p |\n|---|---|---|---|\n")
        for r in reg[v].itertuples():
            f.write(f"| {r.h} | {r.pos:.2f} ({r.se_pos:.2f}) | {r.neg:.2f} ({r.se_neg:.2f}) | {r.wald_p:.3f} |\n")

# --------------------------------------------------------------------------
# 6. Reference: original thesis specification, with and without fixes
# --------------------------------------------------------------------------
cuts = m[(m.di_m < -0.001)].dropna(subset=["cpi_yoy_lag1", "kof_lag1"]).copy()
po = smf.ols("di_m ~ yield_2y + vix + kof_lag1 + cpi_yoy_lag1", data=cuts).fit()
mo = m.copy(); mo["sh_o"] = 0.0; mo.loc[cuts.index, "sh_o"] = po.resid
mo["y1"] = mo.fx.shift(-1) - mo.fx
ro = smf.ols("y1 ~ sh_o + yield_2y + vix + kof_lag1 + cpi_yoy_lag1", data=mo).fit(cov_type="HAC", cov_kwds={"maxlags": 1})
RES["original_spec_h1"] = dict(coef_on_residual=float(ro.params.sh_o), se=float(ro.bse.sh_o),
                               implied_easing_response=float(-ro.params.sh_o))

# --------------------------------------------------------------------------
# 7. Daily event study (trading-day index, all meetings)
# --------------------------------------------------------------------------
d = d.sort_values("datetime").reset_index(drop=True)
d["lfx"] = np.log(d.eur_chf) * 100
pos = {t: i for i, t in enumerate(d.datetime)}
ev = mt.merge(m[["ym", "shock"]], on="ym", how="left")
ev = ev[ev.date.isin(pos.keys())].copy()
# shock of the meeting (one meeting per month in this sample except months with 2 decisions)
rows = []
for k in range(-5, 11):
    y = []
    for t in ev.date:
        i0 = pos[t]
        # k >= 0: change from close of day -1 to close of day k
        # k <  0: change over the |k| days before the announcement (pre-trend)
        y.append(d.lfx.iloc[i0 + k] - d.lfx.iloc[i0 - 1] if k >= 0
                 else d.lfx.iloc[i0 - 1] - d.lfx.iloc[i0 - 1 + k])
    ev[f"c{k}"] = y
ev_ok = ev[~ev.confounded & (ev.date != pd.Timestamp("2011-09-06"))]
es = []
for k in range(0, 11):
    for lab, df in [("clean", ev_ok), ("all", ev)]:
        r = smf.ols(f"c{k} ~ shock", data=df.rename(columns={f"c{k}": f"c{k}"})).fit(cov_type="HC1")
        es.append(dict(k=k, sample=lab, b=-r.params.shock, se=r.bse.shock, n=int(r.nobs)))
es = pd.DataFrame(es)
for lab in ["clean", "all"]:
    r = smf.ols("c0 ~ di", data=(ev_ok if lab == "clean" else ev)).fit(cov_type="HC1")
    RES[f"event_day0_rawdi_{lab}"] = dict(b=float(-r.params.di), se=float(r.bse.di), n=int(r.nobs))
# pre-trend: change from day -5 to -1 (stored in c-5 as lfx[-1]-lfx[-6])
r = smf.ols("Q('c-5') ~ shock", data=ev_ok).fit(cov_type="HC1")
RES["event_pretrend"] = dict(b=float(-r.params.shock), se=float(r.bse.shock))
RES["event_study"] = es.round(4).to_dict("records")
fig, a = plt.subplots(figsize=(6.5, 3.6))
for lab, c in [("clean", "C0"), ("all", "C3")]:
    t = es[es["sample"] == lab]
    a.errorbar(t.k + (0.1 if lab == "all" else 0), t.b, yerr=1.96 * t.se, fmt="o-", color=c, ms=3, capsize=2,
               label="excl. 2009-03-12 / 2015-01-15" if lab == "clean" else "all meetings")
a.axhline(0, color="k", lw=.7, ls="--"); a.legend(fontsize=8)
a.set_xlabel("Trading days after announcement (cumulative from day -1 close)")
a.set_ylabel("EUR/CHF (%) per 1pp easing surprise")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "figures", "event_daily.png"), dpi=160)

# --------------------------------------------------------------------------
# 8. Hourly event study (2020-2025), Sydney-time stamps -> Zurich 09:30
# --------------------------------------------------------------------------
hr["ts"] = hr.datetime.dt.tz_localize("Australia/Sydney", ambiguous="NaT", nonexistent="NaT")
hr = hr.dropna(subset=["ts"]).set_index("ts").sort_index()
lc = np.log(hr.eur_chf) * 100
hrows = []
for r_ in mt[mt.date >= "2020-02-01"].itertuples():
    t0 = pd.Timestamp(f"{r_.date.date()} 09:00", tz="Europe/Zurich")   # bar containing 09:30
    try:
        pre = lc[lc.index < t0].iloc[-1]                                   # close of bar ending 09:00 Zurich
        post = lc[lc.index <= t0 + pd.Timedelta(hours=1)].iloc[-1]         # close of bar ending 11:00 Zurich
    except IndexError:
        continue
    hrows.append(dict(date=str(r_.date.date()), di=r_.di, ret=post - pre))
hd = pd.DataFrame(hrows)
r = smf.ols("ret ~ di", data=hd).fit(cov_type="HC1")
RES["hourly"] = dict(n=len(hd), b_per_1pp_cut=float(-r.params.di), se=float(r.bse.di),
                     events=hd.round(3).to_dict("records"))

# --------------------------------------------------------------------------
# 9. Descriptives used in text
# --------------------------------------------------------------------------
RES["sample"] = dict(start=str(m.date.min().date()), end=str(m.date.max().date()),
                     n_months=len(m), n_meetings=int(len(mt)), n_cuts=int((mt.di < 0).sum()),
                     n_hikes=int((mt.di > 0).sum()), n_holds=int((mt.di == 0).sum()))
with open(os.path.join(OUT, "results.json"), "w") as f:
    json.dump(RES, f, indent=1, default=str)
print(json.dumps({k: RES[k] for k in ["sample", "purge", "original_spec_h1", "regime_counts", "event_pretrend",
                                      "event_day0_rawdi_clean", "event_day0_rawdi_all"]}, indent=1, default=str))
for v in ["i", "fx", "p"]:
    print(v); print(base[v].round(3).to_string(index=False))
print(open(os.path.join(OUT, "tables", "robustness.md")).read())
print(open(os.path.join(OUT, "tables", "regime.md")).read())
print(es[es.k.isin([0, 1, 2, 5, 10])].round(3).to_string(index=False))
print(json.dumps(RES["hourly"], indent=0))
