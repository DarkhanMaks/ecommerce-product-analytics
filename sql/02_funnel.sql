-- 02_funnel.sql
-- Funnel view -> cart -> purchase on events_main (clean data without 14-17 Nov).
-- A session/user "reaches" a stage if it has at least one event of that type.
-- Rates are computed among sessions/users that have a view (the funnel entry).
-- Cart tracking is inconsistent across months (see docs/data_cleaning_rules.md),
-- so view -> purchase is the main conversion and the cart step is diagnostic.

-- F1. Session-level funnel by month
WITH s AS (
    SELECT
        user_session,
        strftime(date_trunc('month', min(event_time)), '%Y-%m') AS month,
        bool_or(event_type = 'view')     AS has_view,
        bool_or(event_type = 'cart')     AS has_cart,
        bool_or(event_type = 'purchase') AS has_purchase
    FROM events_main
    GROUP BY user_session
)
SELECT
    coalesce(month, 'total')                                                AS month,
    count(*) FILTER (WHERE has_view)                                        AS view_sessions,
    count(*) FILTER (WHERE has_view AND has_cart)                           AS with_cart,
    count(*) FILTER (WHERE has_view AND has_purchase)                       AS with_purchase,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_cart)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_cart_pct,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_cart AND has_purchase)
          / count(*) FILTER (WHERE has_view AND has_cart), 2)               AS cart_to_purchase_pct,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_purchase)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_purchase_pct
FROM s
GROUP BY ROLLUP (month)
ORDER BY month;

-- F2. User-level funnel by month (and over both months)
WITH m AS (
    SELECT
        user_id,
        strftime(date_trunc('month', event_time), '%Y-%m') AS period,
        bool_or(event_type = 'view')     AS has_view,
        bool_or(event_type = 'cart')     AS has_cart,
        bool_or(event_type = 'purchase') AS has_purchase
    FROM events_main
    GROUP BY user_id, period
),
a AS (
    SELECT
        user_id,
        'Oct+Nov' AS period,
        bool_or(event_type = 'view')     AS has_view,
        bool_or(event_type = 'cart')     AS has_cart,
        bool_or(event_type = 'purchase') AS has_purchase
    FROM events_main
    GROUP BY user_id
),
u AS (SELECT * FROM m UNION ALL SELECT * FROM a)
SELECT
    period,
    count(*) FILTER (WHERE has_view)                                        AS view_users,
    count(*) FILTER (WHERE has_view AND has_cart)                           AS with_cart,
    count(*) FILTER (WHERE has_view AND has_purchase)                       AS with_purchase,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_cart)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_cart_pct,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_cart AND has_purchase)
          / count(*) FILTER (WHERE has_view AND has_cart), 2)               AS cart_to_purchase_pct,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_purchase)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_purchase_pct
FROM u
GROUP BY period
ORDER BY period;

-- F3. Conversion by top-level category (session x category pairs, 12 largest by view sessions)
-- A session counts in every category it viewed; "purchase" means a purchase in that same category.
WITH sc AS (
    SELECT
        user_session,
        coalesce(split_part(category_code, '.', 1), 'unknown') AS category,
        bool_or(event_type = 'view')     AS has_view,
        bool_or(event_type = 'cart')     AS has_cart,
        bool_or(event_type = 'purchase') AS has_purchase
    FROM events_main
    GROUP BY user_session, category
)
SELECT
    category,
    count(*) FILTER (WHERE has_view)                                        AS view_sessions,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_cart)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_cart_pct,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_purchase)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_purchase_pct
FROM sc
GROUP BY category
ORDER BY view_sessions DESC
LIMIT 12;

-- F4. Conversion by price band (session x band pairs; bands are about the quartiles of event prices, see A6)
WITH sb AS (
    SELECT
        user_session,
        CASE WHEN price < 70  THEN '1: under 70'
             WHEN price < 165 THEN '2: 70-165'
             WHEN price < 360 THEN '3: 165-360'
             ELSE                  '4: 360+' END AS price_band,
        bool_or(event_type = 'view')     AS has_view,
        bool_or(event_type = 'cart')     AS has_cart,
        bool_or(event_type = 'purchase') AS has_purchase
    FROM events_main
    WHERE price IS NOT NULL
    GROUP BY user_session, price_band
)
SELECT
    price_band,
    count(*) FILTER (WHERE has_view)                                        AS view_sessions,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_cart)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_cart_pct,
    round(100.0 * count(*) FILTER (WHERE has_view AND has_purchase)
          / count(*) FILTER (WHERE has_view), 2)                            AS view_to_purchase_pct
FROM sb
GROUP BY price_band
ORDER BY price_band;
