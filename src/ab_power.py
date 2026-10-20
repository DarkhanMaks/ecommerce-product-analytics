"""Sample size, MDE and duration for the installment A/B test, from real baseline numbers.

Usage (from project root):
    python src/ab_power.py
Reads query T1 of sql/07_ab_baseline.sql, prints the tables, saves results/ab_power.csv.
Settings: two-sided alpha = 0.05, power = 0.80, 50/50 split, randomisation unit = user.
"""
import csv
import math
import os
from pathlib import Path

import duckdb
from scipy.stats import norm

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
(ROOT / "results").mkdir(exist_ok=True)

ALPHA, POWER = 0.05, 0.80
Z_A, Z_B = norm.ppf(1 - ALPHA / 2), norm.ppf(POWER)

con = duckdb.connect()
con.execute((ROOT / "sql" / "00_setup.sql").read_text(encoding="utf-8"))
sql_text = (ROOT / "sql" / "07_ab_baseline.sql").read_text(encoding="utf-8")
t1 = next(s.query for s in con.extract_statements(sql_text) if "T1." in s.query)
rows = con.sql(t1).fetchall()  # days, exposed, p_any, p_exp, mean, sd


def n_per_arm_proportion(p0, rel_uplift):
    """Users needed per arm to detect a relative uplift of a conversion rate."""
    p1 = p0 * (1 + rel_uplift)
    pbar = (p0 + p1) / 2
    num = (Z_A * math.sqrt(2 * pbar * (1 - pbar)) + Z_B * math.sqrt(p0 * (1 - p0) + p1 * (1 - p1))) ** 2
    return num / (p1 - p0) ** 2


def mde_proportion(p0, n_arm):
    """Smallest relative uplift of a conversion rate detectable with n users per arm."""
    delta = (Z_A + Z_B) * math.sqrt(2 * p0 * (1 - p0) / n_arm)
    return delta / p0


def mde_mean(mean, sd, n_arm):
    """Smallest relative change of a mean (revenue per user) detectable with n users per arm."""
    return (Z_A + Z_B) * sd * math.sqrt(2 / n_arm) / mean


out = []
for days, exposed, p_any, p_exp, mean, sd in rows:
    n_arm = exposed / 2
    rec = {
        "window_days": days,
        "exposed_users": exposed,
        "users_per_arm": round(n_arm),
        "baseline_conversion_any_purchase": round(p_any, 4),
        "mde_conversion_relative_pct": round(100 * mde_proportion(p_any, n_arm), 2),
        "revenue_per_user_mean": round(mean, 2),
        "revenue_per_user_sd": round(sd, 2),
        "mde_revenue_per_user_relative_pct": round(100 * mde_mean(mean, sd, n_arm), 2),
    }
    for r in (0.02, 0.05, 0.10):
        rec[f"users_per_arm_needed_for_{int(r * 100)}pct_uplift"] = round(n_per_arm_proportion(p_any, r))
    out.append(rec)

for rec in out:
    print("\n--- window of", rec["window_days"], "days ---")
    for k, v in rec.items():
        print(f"{k:45s} {v:>14,}" if isinstance(v, (int, float)) else f"{k:45s} {v}")

with open(ROOT / "results" / "ab_power.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
    w.writeheader()
    w.writerows(out)
print("\nSaved results/ab_power.csv")
