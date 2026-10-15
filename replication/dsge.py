"""
Corrected re-solution of the thesis DSGE model (Dynare/*.mod) in Python.

Run:  python3 replication/dsge.py      (from the repo root)

What is reproduced / corrected:
  * "orig" variants reproduce the .mod files (habit enters only as (1-h)/sigma).
  * "fixed" variants use the standard habit IS curve
        y_t = h/(1+h) y_{t-1} + 1/(1+h) E y_{t+1} - (1-h)/((1+h) sigma_u) (i_t - E pi_{H,t+1})
  * Units: model rates are quarterly percent. The .mod shock (0.25) is therefore
    a 1pp ANNUALISED innovation, not 25bp. Here all responses are normalised so
    that the annualised policy rate falls by exactly 1pp on impact, rates and
    inflation are annualised (x4), and the exchange rate and price level are in %.
  * Determinacy is checked with a Blanchard-Kahn eigenvalue count.
The model is solved as a perfect-foresight linear system (certainty
equivalence: identical to the rational-expectations IRF when determinate).
"""
import json
import os

import numpy as np
from scipy.linalg import eig

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "replication", "output")
os.makedirs(OUT, exist_ok=True)

SWISS = dict(betta=0.995, siggma=1.32, varphi=1.0, alppha=0.25, epsilon=9, theta=0.75, upsilon=0.4,
             eta=1.0, rho_nu=0.0, phi_y=0.15, h=0.70, rho_i=0.80, gamma=0.25, alpha_pass=0.40, alpha_m=0.23)
GALI = dict(betta=0.99, siggma=1.0, varphi=5.0, alppha=0.25, epsilon=9, theta=0.75, upsilon=0.4,
            eta=1.0, rho_nu=0.5, phi_y=0.125, phi_pi=1.5)

SPECS = {
    "Gali baseline": dict(P=GALI, habit=False, smooth=False, index=False, ptc=False, leaning=False, rule_on="pi_h"),
    "Swiss base":    dict(P={**SWISS, "phi_pi": 2.0}, habit=True, smooth=True, index=False, ptc=False, leaning=False, rule_on="pi_h"),
    "Full, Regime A": dict(P={**SWISS, "phi_pi": 2.0, "phi_ds": 0.15}, habit=True, smooth=True, index=True, ptc=True, leaning=True, rule_on="pi"),
    "Full, Regime B": dict(P={**SWISS, "phi_pi": 1.7, "phi_ds": 0.20}, habit=True, smooth=True, index=True, ptc=True, leaning=True, rule_on="pi"),
}
VARS = ["y", "pi_h", "i", "s", "pi", "p_h", "p", "er", "d_er", "pi_m", "nu"]
IX = {v: k for k, v in enumerate(VARS)}


def build(spec, habit_fixed):
    P = spec["P"]
    b, sg, ph, al, ep, th, up, et = (P[k] for k in ["betta", "siggma", "varphi", "alppha", "epsilon", "theta", "upsilon", "eta"])
    Om = (1 - al) / (1 - al + al * ep)
    lam = (1 - th) * (1 - b * th) / th * Om
    om = sg * et + (1 - up) * (sg * et - 1)
    Phi = 1 / (1 + up * (om - 1))
    su = sg * Phi
    kap = lam * (su + (ph + al) / (1 - al))
    eqs = []  # each: dict {(var, lag): coef}, shock coef  (sum = 0)

    g = P.get("gamma", 0) if spec["index"] else 0.0
    eqs.append(({("pi_h", 0): 1, ("pi_h", -1): -g, ("pi_h", 1): -(1 - g) * b, ("y", 0): -kap}, 0))
    if spec["habit"] and habit_fixed:
        hh = P["h"]
        eqs.append(({("y", 0): 1, ("y", -1): -hh / (1 + hh), ("y", 1): -1 / (1 + hh),
                     ("i", 0): (1 - hh) / ((1 + hh) * su), ("pi_h", 1): -(1 - hh) / ((1 + hh) * su)}, 0))
    else:
        c = (1 - P["h"]) / su if spec["habit"] else 1 / su
        eqs.append(({("y", 0): 1, ("y", 1): -1, ("i", 0): c, ("pi_h", 1): -c}, 0))
    rho = P.get("rho_i", 0) if spec["smooth"] else 0.0
    tr = {("i", 0): 1, ("i", -1): -rho, (spec["rule_on"], 0): -(1 - rho) * P["phi_pi"], ("y", 0): -(1 - rho) * P["phi_y"], ("nu", 0): -1}
    if spec["leaning"]:
        tr[("d_er", 0)] = -(1 - rho) * P["phi_ds"]
    eqs.append((tr, 0))
    if spec["ptc"]:
        eqs.append(({("pi", 0): 1, ("pi_h", 0): -(1 - P["alpha_m"]), ("pi_m", 0): -P["alpha_m"]}, 0))
        eqs.append(({("pi_m", 0): 1, ("d_er", 0): -P["alpha_pass"], ("pi_m", -1): -(1 - P["alpha_pass"])}, 0))
    else:
        eqs.append(({("pi", 0): 1, ("pi_h", 0): -1, ("s", 0): -up, ("s", -1): up}, 0))
        eqs.append(({("pi_m", 0): 1}, 0))
    eqs.append(({("s", 0): 1, ("y", 0): -su}, 0))
    eqs.append(({("s", 0): 1, ("er", 0): -1, ("p_h", 0): 1}, 0))
    eqs.append(({("p_h", 0): 1, ("p_h", -1): -1, ("pi_h", 0): -1}, 0))
    eqs.append(({("p", 0): 1, ("p", -1): -1, ("pi", 0): -1}, 0))
    eqs.append(({("d_er", 0): 1, ("er", 0): -1, ("er", -1): 1}, 0))
    eqs.append(({("nu", 0): 1, ("nu", -1): -P["rho_nu"]}, 1.0))   # nu = rho nu(-1) - eps  (written: nu - rho nu(-1) + eps = 0)
    n = len(VARS)
    Ml, M0, Mf, S = np.zeros((n, n)), np.zeros((n, n)), np.zeros((n, n)), np.zeros(n)
    for r, (e, sc) in enumerate(eqs):
        for (v, lag), c in e.items():
            {-1: Ml, 0: M0, 1: Mf}[lag][r, IX[v]] += c
        S[r] = sc
    return Ml, M0, Mf, S


def bk_ok(Ml, M0, Mf):
    n = M0.shape[0]
    A = np.block([[Mf, np.zeros((n, n))], [np.zeros((n, n)), np.eye(n)]])
    B = np.block([[-M0, -Ml], [np.eye(n), np.zeros((n, n))]])
    lam = eig(B, A, right=False)
    stable = int(np.sum(np.abs(lam) < 1 + 1e-6))  # unit roots (price/FX levels) count as stable
    # In the doubled system x_t = [z_t; z_{t-1}] the n lagged copies are
    # predetermined, so determinacy requires exactly n stable roots
    # (checked: Gali phi_pi = 1.01 -> determinate, 0.99 -> indeterminate).
    return stable == n, stable, n


def irf(Ml, M0, Mf, S, T=240):
    n = M0.shape[0]
    big = np.zeros((n * T, n * T)); rhs = np.zeros(n * T)
    for t in range(T):
        big[t*n:(t+1)*n, t*n:(t+1)*n] = M0
        if t > 0:
            big[t*n:(t+1)*n, (t-1)*n:t*n] = Ml
        if t < T - 1:
            big[t*n:(t+1)*n, (t+1)*n:(t+2)*n] = Mf
    rhs[:n] = -S * 1.0   # eps = +1 at t=0 -> nu falls (expansionary)
    z = np.linalg.solve(big, rhs).reshape(T, n)
    return z


res = {}
for name, spec in SPECS.items():
    for fixed in (False, True):
        Ml, M0, Mf, S = build(spec, fixed)
        ok, st, npred = bk_ok(Ml, M0, Mf)
        z = irf(Ml, M0, Mf, S)
        # (a) as in thesis: shock of 0.25 model units, reported x100 ("bp")
        z25 = z * 0.25
        orig = dict(pi_h_bp=z25[0, IX["pi_h"]] * 100, pi_bp=z25[0, IX["pi"]] * 100, er=z25[0, IX["er"]],
                    i_bp=z25[0, IX["i"]] * 100)
        # (b) normalised: annualised policy rate falls by exactly 1pp on impact
        k = -1.0 / (4 * z[0, IX["i"]])
        zn = z * k
        q = [0, 1, 3]  # quarters 1, 2, 4
        norm = dict(i_ann=[4 * zn[t, IX["i"]] for t in q], pi_ann=[4 * zn[t, IX["pi"]] for t in q],
                    er=[zn[t, IX["er"]] for t in q], p_level=[zn[t, IX["p"]] for t in q],
                    y=[zn[t, IX["y"]] for t in q],
                    y_peak_q=int(np.argmax(zn[:12, IX["y"]])) + 1)
        res[f"{name} | {'habit fixed' if fixed else 'as in .mod'}"] = dict(determinate=ok, stable=st, n_pred=npred,
                                                                          thesis_units=orig, normalised=norm)
        if name == "Gali baseline":
            break  # no habit in Gali spec; one version suffices

with open(os.path.join(OUT, "dsge_results.json"), "w") as f:
    json.dump(res, f, indent=1, default=float)
for k, v in res.items():
    o, nrm = v["thesis_units"], v["normalised"]
    print(f"{k:38s} det={v['determinate']} | thesis units: pi_h {o['pi_h_bp']:.1f}bp pi {o['pi_bp']:.1f}bp er {o['er']:.3f} i {o['i_bp']:.1f}bp")
    print(f"{'':38s} per 1pp annual cut: er Q1/Q2/Q4 = " + "/".join(f"{x:.2f}" for x in nrm['er'])
          + " | p level " + "/".join(f"{x:.2f}" for x in nrm['p_level'])
          + " | pi ann " + "/".join(f"{x:.2f}" for x in nrm['pi_ann'])
          + f" | y peak Q{nrm['y_peak_q']}")
