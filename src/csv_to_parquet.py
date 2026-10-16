"""Convert the raw REES46 CSV files to Parquet (one-off, run once).

The conversion is a faithful copy of the raw data: no deduplication, no cleaning.
All cleaning rules live in sql/ so that every removed row is documented.

Usage (from project root):
    python src/csv_to_parquet.py
"""
from pathlib import Path
import time

import duckdb

DATA = Path(__file__).resolve().parents[1] / "data"
MONTHS = ["2019-Oct", "2019-Nov"]

con = duckdb.connect()
con.execute("SET memory_limit = '8GB'")

for month in MONTHS:
    src = DATA / f"{month}.csv"
    dst = DATA / f"{month}.parquet"
    if dst.exists():
        print(f"{dst.name} already exists, skipping")
        continue

    t0 = time.time()
    # event_time looks like '2019-10-01 00:00:00 UTC'; strip the suffix and store
    # as a naive TIMESTAMP that is always UTC.
    con.execute(f"""
        COPY (
            SELECT
                CAST(replace(event_time, ' UTC', '') AS TIMESTAMP) AS event_time,
                event_type,
                product_id,
                category_id,
                category_code,
                brand,
                price,
                user_id,
                user_session
            FROM read_csv(
                '{src.as_posix()}',
                header = true,
                columns = {{
                    'event_time': 'VARCHAR',
                    'event_type': 'VARCHAR',
                    'product_id': 'BIGINT',
                    'category_id': 'BIGINT',
                    'category_code': 'VARCHAR',
                    'brand': 'VARCHAR',
                    'price': 'DOUBLE',
                    'user_id': 'BIGINT',
                    'user_session': 'VARCHAR'
                }}
            )
        ) TO '{dst.as_posix()}' (FORMAT parquet, COMPRESSION zstd)
    """)

    rows, tmin, tmax = con.execute(
        f"SELECT count(*), min(event_time), max(event_time) "
        f"FROM read_parquet('{dst.as_posix()}')"
    ).fetchone()
    size_gb = dst.stat().st_size / 1024**3
    print(f"{dst.name}: {rows:,} rows, {tmin} .. {tmax}, "
          f"{size_gb:.2f} GB, {time.time() - t0:.0f}s")
