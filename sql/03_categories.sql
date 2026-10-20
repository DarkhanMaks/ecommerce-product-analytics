-- 03_categories.sql
-- Category performance on events_main (clean data without 14-17 Nov).
-- Category = first part of category_code (NULL -> 'unknown').
-- Traffic = view events, revenue = sum of purchase prices.
-- Conversion = share of (session, category) pairs with a view that also have a purchase in that category.
-- Order = (session, category) pair with a purchase, so AOV is revenue per such order.

-- C1. Traffic share vs revenue share, conversion and AOV by category (top 12 by revenue)
WITH e AS (
    SELECT
        user_session,
        coalesce(split_part(category_code, '.', 1), 'unknown') AS category,
        event_type,
        price
    FROM events_main
),
by_event AS (
    SELECT
        category,
        count(*) FILTER (WHERE event_type = 'view')       AS views,
        sum(price) FILTER (WHERE event_type = 'purchase') AS revenue
    FROM e
    GROUP BY category
),
by_session AS (
    SELECT
        category,
        count(*) FILTER (WHERE has_view)                  AS view_sessions,
        count(*) FILTER (WHERE has_view AND has_purchase) AS converted_sessions,
        count(*) FILTER (WHERE has_purchase)              AS orders
    FROM (
        SELECT user_session, category,
               bool_or(event_type = 'view')     AS has_view,
               bool_or(event_type = 'purchase') AS has_purchase
        FROM e
        GROUP BY user_session, category
    )
    GROUP BY category
)
SELECT
    b.category,
    round(100.0 * b.views   / sum(b.views)   OVER (), 1)   AS traffic_share_pct,
    round(100.0 * b.revenue / sum(b.revenue) OVER (), 1)   AS revenue_share_pct,
    round(100.0 * s.converted_sessions / s.view_sessions, 2) AS view_to_purchase_pct,
    round(b.revenue / s.orders, 0)                         AS aov,
    round(1000.0 * b.revenue / b.views, 0)                 AS revenue_per_1k_views,
    -- illustrative size of the prize: extra revenue if conversion rose by 1 percentage point
    -- (assumes the extra buyers spend the category's average order value)
    round(s.view_sessions * 0.01 * (b.revenue / s.orders), 0) AS value_of_plus_1pp
FROM by_event b
JOIN by_session s USING (category)
ORDER BY b.revenue DESC NULLS LAST
LIMIT 12;
