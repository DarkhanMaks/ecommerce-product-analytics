-- 06_installment_sizing.sql
-- Sizing of the feature "show the monthly installment payment on the product card" for expensive items.
-- Reads events_main (clean data without 14-17 Nov; 57 days: all of October, 26 days of November).
-- The dataset has NO payment data, so the uplift is scenario-based, not measured.
-- Expensive = event price >= 360 (about the 75th percentile of event prices, see A6 in 01_data_quality.sql).

-- I1. The addressable segment: sessions that view an expensive item
WITH sp AS (
    SELECT user_session,
           bool_or(event_type = 'view'     AND price >= 360) AS saw_exp,
           bool_or(event_type = 'purchase' AND price >= 360) AS bought_exp
    FROM events_main
    GROUP BY user_session
),
seg AS (
    SELECT count(*) FILTER (WHERE saw_exp)                   AS exposed_sessions,
           count(*) FILTER (WHERE saw_exp AND bought_exp)    AS converted_sessions
    FROM sp
),
tot AS (
    SELECT count(*) FILTER (WHERE event_type = 'view')                                 AS views_all,
           count(*) FILTER (WHERE event_type = 'view' AND price >= 360)                AS views_exp,
           sum(price) FILTER (WHERE event_type = 'purchase')                           AS rev_all,
           sum(price) FILTER (WHERE event_type = 'purchase' AND price >= 360)          AS rev_exp,
           count(DISTINCT user_session) FILTER (WHERE event_type = 'purchase' AND price >= 360) AS orders_exp
    FROM events_main
)
SELECT
    seg.exposed_sessions,
    seg.converted_sessions,
    round(100.0 * seg.converted_sessions / seg.exposed_sessions, 2) AS conversion_pct,
    round(100.0 * tot.views_exp / tot.views_all, 1)                 AS share_of_views_pct,
    round(100.0 * tot.rev_exp / tot.rev_all, 1)                     AS share_of_revenue_pct,
    round(tot.rev_exp / tot.orders_exp, 0)                          AS aov_expensive,
    round(tot.rev_exp, 0)                                           AS revenue_expensive
FROM seg, tot;

-- I2. Scenarios: relative uplift of conversion among exposed sessions (assumed, NOT estimated from data)
-- incremental orders = converted sessions x uplift; incremental revenue = orders x AOV of expensive items
WITH sp AS (
    SELECT user_session,
           bool_or(event_type = 'view'     AND price >= 360) AS saw_exp,
           bool_or(event_type = 'purchase' AND price >= 360) AS bought_exp
    FROM events_main
    GROUP BY user_session
),
seg AS (
    SELECT count(*) FILTER (WHERE saw_exp)                   AS exposed_sessions,
           count(*) FILTER (WHERE saw_exp AND bought_exp)    AS converted_sessions
    FROM sp
),
tot AS (
    SELECT sum(price) FILTER (WHERE event_type = 'purchase')                           AS rev_all,
           sum(price) FILTER (WHERE event_type = 'purchase' AND price >= 360)          AS rev_exp,
           count(DISTINCT user_session) FILTER (WHERE event_type = 'purchase' AND price >= 360) AS orders_exp
    FROM events_main
),
sc(scenario, uplift) AS (VALUES ('low', 0.02), ('base', 0.05), ('high', 0.10))
SELECT
    sc.scenario,
    round(100 * sc.uplift, 0)                                                   AS relative_uplift_pct,
    round(100.0 * seg.converted_sessions / seg.exposed_sessions * (1 + sc.uplift), 2) AS new_conversion_pct,
    round(seg.converted_sessions * sc.uplift, 0)                                AS incremental_orders,
    round(seg.converted_sessions * sc.uplift * tot.rev_exp / tot.orders_exp, 0) AS incremental_revenue,
    round(100.0 * seg.converted_sessions * sc.uplift * tot.rev_exp / tot.orders_exp / tot.rev_all, 2) AS pct_of_total_revenue
FROM sc, seg, tot
ORDER BY sc.uplift;

-- I3. Does conversion fall with price WITHIN a category? (three largest known categories)
WITH sb AS (
    SELECT user_session,
           coalesce(split_part(category_code, '.', 1), 'unknown') AS category,
           CASE WHEN price < 70  THEN '1: under 70'
                WHEN price < 165 THEN '2: 70-165'
                WHEN price < 360 THEN '3: 165-360'
                ELSE                  '4: 360+' END AS price_band,
           bool_or(event_type = 'view')     AS has_view,
           bool_or(event_type = 'purchase') AS has_purchase
    FROM events_main
    WHERE price IS NOT NULL
    GROUP BY user_session, category, price_band
)
SELECT
    category,
    price_band,
    count(*) FILTER (WHERE has_view)                                        AS view_sessions,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_purchase)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_purchase_pct
FROM sb
WHERE category IN ('electronics', 'appliances', 'computers')
GROUP BY category, price_band
ORDER BY category, price_band;
