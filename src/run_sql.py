"""Run a .sql file against the Parquet data and print the result of every statement.

Usage (from project root):
    python src/run_sql.py sql/01_data_quality.sql        # all queries
    python src/run_sql.py sql/01_data_quality.sql A2     # only the query titled "A2. ..."

sql/00_setup.sql is executed first (defines the events_raw view). A line starting
with "-- " at the top of each statement is printed as its title.
"""
import os
import re
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)  # SQL files use paths relative to the project root

tmp_dir = ROOT / "data" / "duckdb_tmp"  # inside git-ignored data/
tmp_dir.mkdir(exist_ok=True)

con = duckdb.connect()
con.execute("SET memory_limit = '8GB'")
con.execute(f"SET temp_directory = '{tmp_dir.as_posix()}'")
con.execute((ROOT / "sql" / "00_setup.sql").read_text(encoding="utf-8"))

sql_text = Path(sys.argv[1]).read_text(encoding="utf-8")
only = sys.argv[2] if len(sys.argv) > 2 else None  # e.g. "A2": run just that query

for stmt in con.extract_statements(sql_text):
    query = stmt.query.strip()
    # title = the "-- A1. ..." style line; fall back to the first comment line
    comments = [l[3:].strip() for l in query.splitlines() if l.startswith("-- ")]
    title = next((c for c in comments if re.match(r"[A-Z]\d+\. ", c)), comments[0] if comments else "")
    if only and not title.startswith(only + "."):
        continue
    print(f"\n=== {title} ===")
    t0 = time.time()
    rel = con.sql(query)
    if rel is not None:
        rel.show(max_rows=100)
    print(f"({time.time() - t0:.1f}s)")
