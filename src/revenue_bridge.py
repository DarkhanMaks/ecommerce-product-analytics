"""Run query D2 of sql/05_revenue_decomposition.sql, save the bridge as CSV and a waterfall chart.

Usage (from project root):
    python src/revenue_bridge.py
Outputs: results/revenue_bridge.csv, results/revenue_bridge.png
"""
import csv
import os
from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
(ROOT / "results").mkdir(exist_ok=True)

con = duckdb.connect()
con.execute((ROOT / "sql" / "00_setup.sql").read_text(encoding="utf-8"))

sql_text = (ROOT / "sql" / "05_revenue_decomposition.sql").read_text(encoding="utf-8")
d2 = next(s.query for s in con.extract_statements(sql_text) if "D2." in s.query)
rows = con.sql(d2).fetchall()  # (seq, step, value)

steps = [r[1] for r in rows]
values = [float(r[2]) for r in rows]

change = values[-1] - values[0]
effects_sum = sum(values[1:-1])
print(f"Revenue change: {change:,.0f}; sum of factor effects: {effects_sum:,.0f}; "
      f"difference: {change - effects_sum:,.4f}")
for s, v in zip(steps, values):
    print(f"{s:18s} {v:>16,.0f}")

with open(ROOT / "results" / "revenue_bridge.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["step", "value"])
    for s, v in zip(steps, values):
        w.writerow([s, round(v, 2)])

# Waterfall (values in millions, zero baseline)
m = [v / 1e6 for v in values]
TOTAL, UP, DOWN, INK = "#6b7280", "#2563eb", "#d97706", "#1f2937"
fig, ax = plt.subplots(figsize=(9, 5))
running = m[0]
for i, (s, v) in enumerate(zip(steps, m)):
    if i in (0, len(m) - 1):
        ax.bar(i, v, color=TOTAL, width=0.55)
        ax.text(i, v, f"{v:,.1f}M", ha="center", va="bottom", color=INK, fontsize=10)
    else:
        bottom = running if v >= 0 else running + v
        ax.bar(i, abs(v), bottom=bottom, color=UP if v >= 0 else DOWN, width=0.55)
        ax.text(i, max(running, running + v), f"{v:+,.1f}M", ha="center", va="bottom",
                color=INK, fontsize=10)
        running += v
ax.set_xticks(range(len(steps)))
ax.set_xticklabels(steps, fontsize=10)
ax.set_ylabel("Revenue, millions")
ax.set_title("Revenue bridge: October to November (same 26 days in each month)", loc="left", fontsize=12)
ax.spines[["top", "right"]].set_visible(False)
ax.grid(axis="y", alpha=0.2)
fig.text(0.01, 0.01, "Excludes days 14-17 and 31 in both months. Black Friday (29 Nov) is inside November.",
         fontsize=8, color="#6b7280")
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(ROOT / "results" / "revenue_bridge.png", dpi=150)
print("Saved results/revenue_bridge.png")
