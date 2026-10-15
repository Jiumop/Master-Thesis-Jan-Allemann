# Corrected replication

`paper.md` is a short revised version of the thesis with corrected methods and results.

```bash
pip install pandas numpy statsmodels matplotlib scipy
python3 replication/analysis.py   # empirical part -> replication/output/
python3 replication/dsge.py       # DSGE part      -> replication/output/dsge_results.json
```

`dsge.py` reproduces the thesis DSGE impact responses exactly with the original equations, then reports results with the corrected habit IS curve and units. Appendix A of `paper.md` lists every correction relative to the original R/Dynare code.
