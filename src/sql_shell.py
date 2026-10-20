"""Tiny interactive SQL prompt over the Parquet data (for exploring by hand).

Usage (from project root):
    python src/sql_shell.py

Type a query ending with ';' and press Enter. A query may span several lines.
The view events_raw is available. Type 'exit' to quit.
"""
import os
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

con = duckdb.connect()
con.execute("SET memory_limit = '8GB'")
con.execute((ROOT / "sql" / "00_setup.sql").read_text(encoding="utf-8"))

print("DuckDB shell. Table: events_raw. End a query with ';'. Type 'exit' to quit.")
buffer = []
while True:
    line = input("sql> " if not buffer else "...> ")
    if not buffer and line.strip().lower() in ("exit", "quit"):
        break
    buffer.append(line)
    if line.rstrip().endswith(";"):
        query = "\n".join(buffer)
        buffer = []
        try:
            rel = con.sql(query)
            if rel is not None:
                rel.show(max_rows=50)
        except Exception as e:
            print(f"Error: {e}")
