-- 01a_build_clean_events.sql
-- Applies the cleaning rules found in 01_data_quality.sql and writes
-- data/events_clean.parquet, which every later step reads.
--
-- Rule 1: drop rows without user_session (cannot be assigned to a visit)
-- Rule 2: drop exact duplicate rows (all 9 columns identical), keep one copy
-- Rule 3: bot-like users removed: >= 100 sessions AND events < 1.5 x sessions
-- Rule 4: price = 0 treated as missing (price set to NULL, row kept)
-- Not removed: missing brand / category_code (kept as NULL, labelled 'unknown'
--              at analysis time), sessions with several user_ids (939 sessions).

-- C1. Rules 1-2: dedup + drop NULL sessions -> intermediate file (1-2 min)
COPY (
    SELECT DISTINCT *
    FROM events_raw
    WHERE user_session IS NOT NULL
) TO 'data/_dedup.parquet' (FORMAT parquet, COMPRESSION zstd);

-- C2. Rules 3-4: remove bot-like users, zero price -> NULL, write clean file (1-2 min)
COPY (
    SELECT * REPLACE (NULLIF(price, 0) AS price)
    FROM read_parquet('data/_dedup.parquet')
    WHERE user_id NOT IN (
        SELECT user_id
        FROM read_parquet('data/_dedup.parquet')
        GROUP BY user_id
        HAVING count(DISTINCT user_session) >= 100
           AND count(*) < 1.5 * count(DISTINCT user_session)
    )
) TO 'data/events_clean.parquet' (FORMAT parquet, COMPRESSION zstd);

-- C3. Row waterfall: how many rows each stage leaves
SELECT
    (SELECT count(*) FROM events_raw)                              AS raw_rows,
    (SELECT count(*) FROM read_parquet('data/_dedup.parquet'))     AS after_rules_1_2,
    (SELECT count(*) FROM read_parquet('data/events_clean.parquet')) AS after_rule_3,
    (SELECT count(*) FROM read_parquet('data/events_clean.parquet') WHERE price IS NULL) AS rows_with_null_price;

-- C4. Rule 3 impact: users removed and their share of events, purchases, revenue
WITH d AS (SELECT * FROM read_parquet('data/_dedup.parquet')),
c AS (SELECT * FROM read_parquet('data/events_clean.parquet'))
SELECT
    (SELECT count(DISTINCT user_id) FROM d) - (SELECT count(DISTINCT user_id) FROM c) AS users_removed,
    (SELECT count(*) FROM d) - (SELECT count(*) FROM c)                               AS events_removed,
    (SELECT count(*) FROM d WHERE event_type = 'purchase')
      - (SELECT count(*) FROM c WHERE event_type = 'purchase')                         AS purchases_removed,
    round((SELECT sum(price) FROM d WHERE event_type = 'purchase')
      - (SELECT sum(price) FROM c WHERE event_type = 'purchase'), 0)                  AS revenue_removed,
    round(100.0 * ((SELECT sum(price) FROM d WHERE event_type = 'purchase')
      - (SELECT sum(price) FROM c WHERE event_type = 'purchase'))
      / (SELECT sum(price) FROM d WHERE event_type = 'purchase'), 3)                  AS pct_revenue_removed;
