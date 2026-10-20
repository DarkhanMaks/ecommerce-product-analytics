-- 01_data_quality.sql
-- Goal: find what is wrong with the raw events before any metric is computed.
-- Each cleaning rule found here is listed with the number of rows it affects.

-- A1. Rows by month and event type
SELECT
    strftime(date_trunc('month', event_time), '%Y-%m') AS month,
    event_type,
    count(*) AS n_rows
FROM events_raw
GROUP BY 1, 2
ORDER BY 1, 2;

-- A2. Missing values per column
-- One row per column (UNPIVOT turns the wide row into a readable list).
SELECT
    column_name,
    n_null,
    round(100.0 * n_null / total_rows, 3) AS pct_null
FROM (
    UNPIVOT (
        SELECT
            count(*)                                        AS total_rows,
            count(*) FILTER (WHERE event_time    IS NULL)   AS event_time,
            count(*) FILTER (WHERE event_type    IS NULL)   AS event_type,
            count(*) FILTER (WHERE product_id    IS NULL)   AS product_id,
            count(*) FILTER (WHERE category_id   IS NULL)   AS category_id,
            count(*) FILTER (WHERE category_code IS NULL)   AS category_code,
            count(*) FILTER (WHERE brand         IS NULL)   AS brand,
            count(*) FILTER (WHERE price         IS NULL)   AS price,
            count(*) FILTER (WHERE user_id       IS NULL)   AS user_id,
            count(*) FILTER (WHERE user_session  IS NULL)   AS user_session
        FROM events_raw
    )
    ON event_time, event_type, product_id, category_id, category_code,
       brand, price, user_id, user_session
    INTO NAME column_name VALUE n_null
)
ORDER BY n_null DESC;

-- A3. Distinct entities in the raw data
SELECT
    count(DISTINCT user_id)      AS users,
    count(DISTINCT user_session) AS sessions,
    count(DISTINCT product_id)   AS products,
    count(DISTINCT category_id)  AS category_ids,
    count(DISTINCT brand)        AS brands
FROM events_raw;

-- A4. Exact duplicates: rows where all 9 columns are identical (heavy: 1-3 min)
SELECT
    total_rows,
    distinct_rows,
    total_rows - distinct_rows AS duplicate_rows,
    round(100.0 * (total_rows - distinct_rows) / total_rows, 3) AS pct_duplicates
FROM (
    SELECT
        (SELECT count(*) FROM events_raw)                         AS total_rows,
        (SELECT count(*) FROM (SELECT DISTINCT * FROM events_raw)) AS distinct_rows
);

-- A5. Duplicates by event type: how many groups are repeated, and how many extra copies
SELECT
    event_type,
    count(*)     AS duplicated_groups,
    sum(n - 1)   AS extra_copies
FROM (
    SELECT event_type, count(*) AS n
    FROM events_raw
    GROUP BY event_time, event_type, product_id, category_id, category_code,
             brand, price, user_id, user_session
    HAVING count(*) > 1
)
GROUP BY event_type
ORDER BY extra_copies DESC;

-- A6. Price distribution (min, percentiles, max)
SELECT
    min(price)                    AS min_price,
    quantile_cont(price, 0.01)    AS p01,
    quantile_cont(price, 0.25)    AS p25,
    median(price)                 AS p50,
    quantile_cont(price, 0.75)    AS p75,
    quantile_cont(price, 0.99)    AS p99,
    max(price)                    AS max_price,
    round(avg(price), 2)          AS avg_price
FROM events_raw;

-- A7. Zero, negative and very low prices by event type
SELECT
    event_type,
    count(*)                                          AS total_rows,
    count(*) FILTER (WHERE price < 0)                 AS negative,
    count(*) FILTER (WHERE price = 0)                 AS zero,
    count(*) FILTER (WHERE price > 0 AND price < 1)   AS between_0_and_1
FROM events_raw
GROUP BY event_type
ORDER BY event_type;

-- A8. Sessions that contain more than one user_id
SELECT
    count(*)       AS multi_user_sessions,
    sum(n_events)  AS events_in_them,
    max(n_users)   AS max_users_in_one_session
FROM (
    SELECT user_session,
           count(DISTINCT user_id) AS n_users,
           count(*)                AS n_events
    FROM events_raw
    WHERE user_session IS NOT NULL
    GROUP BY user_session
    HAVING count(DISTINCT user_id) > 1
);

-- A9. The 12 rows without user_session
SELECT event_time, event_type, product_id, price, user_id
FROM events_raw
WHERE user_session IS NULL
ORDER BY event_time;

-- A10. Events per user: how long is the tail?
SELECT
    count(*)                    AS users,
    quantile_cont(n, 0.50)      AS p50,
    quantile_cont(n, 0.90)      AS p90,
    quantile_cont(n, 0.99)      AS p99,
    quantile_cont(n, 0.999)     AS p999,
    quantile_cont(n, 0.9999)    AS p9999,
    max(n)                      AS max_events
FROM (SELECT user_id, count(*) AS n FROM events_raw GROUP BY user_id);

-- A11. 15 most active users and what they do
SELECT
    user_id,
    count(*)                                                    AS events,
    count(DISTINCT user_session)                                AS sessions,
    count(*) FILTER (WHERE event_type = 'purchase')             AS purchases,
    count(DISTINCT product_id)                                  AS products,
    round(sum(price) FILTER (WHERE event_type = 'purchase'), 0) AS revenue
FROM events_raw
GROUP BY user_id
ORDER BY events DESC
LIMIT 15;

-- A12. Purchases per buyer: how long is the tail?
SELECT
    count(*)                    AS buyers,
    quantile_cont(n, 0.50)      AS p50,
    quantile_cont(n, 0.90)      AS p90,
    quantile_cont(n, 0.99)      AS p99,
    quantile_cont(n, 0.999)     AS p999,
    max(n)                      AS max_purchases
FROM (
    SELECT user_id, count(*) AS n
    FROM events_raw
    WHERE event_type = 'purchase'
    GROUP BY user_id
);

-- A13. Bot threshold sensitivity: what would we remove at each events-per-user cutoff?
WITH u AS (
    SELECT user_id,
           count(*)                                                          AS events,
           count(*) FILTER (WHERE event_type = 'purchase')                   AS purchases,
           coalesce(sum(price) FILTER (WHERE event_type = 'purchase'), 0)    AS revenue
    FROM events_raw
    GROUP BY user_id
),
t(threshold) AS (VALUES (300), (500), (1000), (2000), (5000))
SELECT
    t.threshold,
    count(*)           FILTER (WHERE u.events > t.threshold)                       AS users_flagged,
    count(*)           FILTER (WHERE u.events > t.threshold AND u.purchases = 0)   AS flagged_no_purchase,
    round(100.0 * sum(u.events)    FILTER (WHERE u.events > t.threshold) / sum(u.events), 2)    AS pct_events,
    round(100.0 * sum(u.purchases) FILTER (WHERE u.events > t.threshold) / sum(u.purchases), 2) AS pct_purchases,
    round(100.0 * sum(u.revenue)   FILTER (WHERE u.events > t.threshold) / sum(u.revenue), 2)   AS pct_revenue
FROM u CROSS JOIN t
GROUP BY t.threshold
ORDER BY t.threshold;

-- A14. Revenue concentration: share of revenue from the top buyers
WITH b AS (
    SELECT user_id, sum(price) AS revenue
    FROM events_raw
    WHERE event_type = 'purchase'
    GROUP BY user_id
),
r AS (SELECT *, ntile(1000) OVER (ORDER BY revenue DESC) AS bucket FROM b)
SELECT
    count(*) FILTER (WHERE bucket = 1)                                              AS buyers_in_top_0_1pct,
    round(100.0 * sum(revenue) FILTER (WHERE bucket = 1) / sum(revenue), 2)         AS pct_revenue_top_0_1pct,
    round(100.0 * sum(revenue) FILTER (WHERE bucket <= 10) / sum(revenue), 2)       AS pct_revenue_top_1pct
FROM r;

-- A15. Users with > 1000 events: do purchases and events-per-session separate bots from heavy shoppers?
WITH u AS (
    SELECT user_id,
           count(*)                                        AS events,
           count(DISTINCT user_session)                    AS sessions,
           count(*) FILTER (WHERE event_type = 'purchase') AS purchases
    FROM events_raw
    GROUP BY user_id
    HAVING count(*) > 1000
)
SELECT
    CASE WHEN purchases = 0  THEN '0 purchases'
         WHEN purchases <= 2 THEN '1-2 purchases'
         WHEN purchases <= 10 THEN '3-10 purchases'
         ELSE '11+ purchases' END                          AS purchase_bucket,
    count(*)                                               AS users,
    sum(events)                                            AS events,
    round(median(events * 1.0 / sessions), 2)              AS median_events_per_session,
    median(sessions)                                       AS median_sessions
FROM u
GROUP BY 1
ORDER BY min(purchases);

-- A16. Scanner signature: many sessions with ~1 event each (events < 1.5 x sessions)
WITH u AS (
    SELECT user_id,
           count(*)                                                       AS events,
           count(DISTINCT user_session)                                   AS sessions,
           count(*) FILTER (WHERE event_type = 'purchase')                AS purchases,
           coalesce(sum(price) FILTER (WHERE event_type = 'purchase'), 0) AS revenue
    FROM events_raw
    GROUP BY user_id
),
t(min_sessions) AS (VALUES (100), (300), (1000))
SELECT
    t.min_sessions,
    count(*) FILTER (WHERE u.sessions >= t.min_sessions AND u.events < 1.5 * u.sessions)                  AS users_flagged,
    count(*) FILTER (WHERE u.sessions >= t.min_sessions AND u.events < 1.5 * u.sessions AND u.purchases = 0) AS flagged_no_purchase,
    round(100.0 * sum(u.events)    FILTER (WHERE u.sessions >= t.min_sessions AND u.events < 1.5 * u.sessions) / sum(u.events), 3)    AS pct_events,
    round(100.0 * sum(u.purchases) FILTER (WHERE u.sessions >= t.min_sessions AND u.events < 1.5 * u.sessions) / sum(u.purchases), 3) AS pct_purchases,
    round(100.0 * sum(u.revenue)   FILTER (WHERE u.sessions >= t.min_sessions AND u.events < 1.5 * u.sessions) / sum(u.revenue), 3)   AS pct_revenue
FROM u CROSS JOIN t
GROUP BY t.min_sessions
ORDER BY t.min_sessions;

-- A17. Clean data baseline (reads the cleaned view `events`)
SELECT
    coalesce(month, 'total')                                        AS month,
    count(*)                                                        AS events,
    count(DISTINCT user_id)                                         AS users,
    count(DISTINCT user_session)                                    AS sessions,
    count(*) FILTER (WHERE event_type = 'purchase')                 AS purchase_events,
    round(sum(price) FILTER (WHERE event_type = 'purchase'), 0)     AS revenue
FROM (SELECT strftime(date_trunc('month', event_time), '%Y-%m') AS month, * FROM events)
GROUP BY ROLLUP (month)
ORDER BY month;
