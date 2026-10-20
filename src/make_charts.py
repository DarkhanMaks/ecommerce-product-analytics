"""Export aggregated tables to results/ and draw the README charts.

Usage (from project root):
    python src/make_charts.py
Runs queries F1, F2 (sql/02_funnel.sql), C1 (sql/03_categories.sql), R1 (sql/04_retention.sql)
and writes CSV files plus three PNG charts into results/. (The revenue bridge comes from src/revenue_bridge.py.)
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
RES = ROOT / "results"
RES.mkdir(exist_ok=True)

INK, GRAY, BLUE, ORANGE = "#1f2937", "#6b7280", "#2563eb", "#d97706"

con = duckdb.connect()
con.execute((ROOT / "sql" / "00_setup.sql").read_text(encoding="utf-8"))


def run(sql_file, tag):
    """Run the query whose title starts with `tag.` and return (columns, rows)."""
    text = (ROOT / "sql" / sql_file).read_text(encoding="utf-8")
    q = next(s.query for s in con.extract_statements(text) if f"-- {tag}. " in s.query)
    rel = con.sql(q)
    return rel.columns, rel.fetchall()


def save_csv(name, cols, rows):
    with open(RES / name, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)


def style(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="y", alpha=0.2)


# ---------- 1. Funnel ----------
cols_s, rows_s = run("02_funnel.sql", "F1")
cols_u, rows_u = run("02_funnel.sql", "F2")
save_csv("funnel_sessions_by_month.csv", cols_s, rows_s)
save_csv("funnel_users_by_period.csv", cols_u, rows_u)
s_tot = next(r for r in rows_s if r[0] == "total")
u_tot = next(r for r in rows_u if r[0] == "Oct+Nov")
# columns: label, entities, with_cart, with_purchase, view_to_cart_pct, cart_to_purchase_pct, view_to_purchase_pct
stages = ["Add to cart", "Purchase"]
sess = [s_tot[4], s_tot[6]]
usr = [u_tot[4], u_tot[6]]
fig, ax = plt.subplots(figsize=(8, 5))
x = range(len(stages))
b1 = ax.bar([i - 0.2 for i in x], sess, width=0.38, color=GRAY, label="Sessions with a view")
b2 = ax.bar([i + 0.2 for i in x], usr, width=0.38, color=BLUE, label="Users with a view")
for bars in (b1, b2):
    for b in bars:
        ax.text(b.get_x() + b.get_width() / 2, b.get_height(), f"{b.get_height():.1f}%",
                ha="center", va="bottom", color=INK, fontsize=10)
ax.set_xticks(list(x))
ax.set_xticklabels(stages)
ax.set_ylabel("% of those with a view")
ax.set_title("Funnel: share of sessions and users that reach each step", loc="left", fontsize=12)
ax.legend(frameon=False)
style(ax)
fig.text(0.01, 0.01, "Oct+Nov without 14-17 Nov. Cart events are logged inconsistently across months; "
         "view to purchase is the main conversion.", fontsize=8, color=GRAY)
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(RES / "chart_funnel.png", dpi=150)
plt.close(fig)

# ---------- 2. Categories ----------
cols_c, rows_c = run("03_categories.sql", "C1")
save_csv("categories.csv", cols_c, rows_c)
top = rows_c[:8]  # already sorted by revenue
names = [r[0] for r in top][::-1]
traffic = [r[1] for r in top][::-1]
revenue = [r[2] for r in top][::-1]
fig, ax = plt.subplots(figsize=(8, 5.5))
y = range(len(names))
h1 = ax.barh([i + 0.2 for i in y], traffic, height=0.38, color=GRAY, label="Share of views")
h2 = ax.barh([i - 0.2 for i in y], revenue, height=0.38, color=BLUE, label="Share of revenue")
for bars in (h1, h2):
    for b in bars:
        ax.text(b.get_width() + 0.5, b.get_y() + b.get_height() / 2, f"{b.get_width():.1f}%",
                va="center", color=INK, fontsize=9)
ax.set_yticks(list(y))
ax.set_yticklabels(names)
ax.set_xlabel("% of total")
ax.set_title("Traffic share vs revenue share by category", loc="left", fontsize=12)
ax.legend(frameon=False, loc="lower right")
ax.spines[["top", "right"]].set_visible(False)
ax.grid(axis="x", alpha=0.2)
fig.text(0.01, 0.01, "Top 8 categories by revenue; 'unknown' = no category_code (33% of views).",
         fontsize=8, color=GRAY)
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(RES / "chart_categories.png", dpi=150)
plt.close(fig)

# ---------- 3. Retention ----------
cols_r, rows_r = run("04_retention.sql", "R1")
save_csv("retention_cohorts.csv", cols_r, rows_r)
ramp = ["#93c5fd", "#60a5fa", "#2563eb", "#1e3a8a"]
fig, ax = plt.subplots(figsize=(8, 5))
cohorts = sorted({r[0] for r in rows_r})
for i, k in enumerate(cohorts):
    pts = {r[2]: r[4] for r in rows_r if r[0] == k}  # weeks_after -> visitor retention
    xs = list(range(0, 5))
    ys = [pts.get(w, float("nan")) for w in xs]  # gaps stay gaps
    start = next(r[1] for r in rows_r if r[0] == k)
    size = next(r[3] for r in rows_r if r[0] == k)
    ax.plot(xs, ys, marker="o", color=ramp[i], linewidth=2,
            label=f"First seen {start:%d %b} ({size:,} users)")
ax.set_xticks(range(0, 5))
ax.set_xlabel("Weeks after the first week")
ax.set_ylabel("% of cohort active")
ax.set_ylim(0, 105)
ax.set_title("Visitor retention by first-visit week", loc="left", fontsize=12)
ax.legend(frameon=False, loc="upper right")
style(ax)
fig.text(0.01, 0.01, "The first cohort also contains returning customers who were not seen earlier in the data (left-censoring). "
         "Gaps = skipped week.", fontsize=8, color=GRAY)
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(RES / "chart_retention.png", dpi=150)
plt.close(fig)

print("Saved CSV files and charts to results/")
