-- 05_revenue_decomposition.sql
-- Revenue = active users x buyer rate x orders per buyer x AOV, October vs November.
-- Like-for-like windows: days 1-13 and 18-30 of each month (26 days each). Days 14-17 are
-- excluded in BOTH months (the November anomaly window), day 31 is dropped. Black Friday
-- (29 Nov) is inside the November window and is a confounder.
-- Reads the cleaned view `events`.

-- D1. The four factors by month
WITH d AS (
    SELECT strftime(date_trunc('month', event_time), '%Y-%m') AS month,
           user_id, user_session, event_type, price
    FROM events
    WHERE day(event_time) <= 30 AND day(event_time) NOT BETWEEN 14 AND 17
),
m AS (
    SELECT month,
           count(DISTINCT user_id)                                         AS users,
           count(DISTINCT user_id) FILTER (WHERE event_type = 'purchase')  AS buyers,
           count(DISTINCT user_session) FILTER (WHERE event_type = 'purchase') AS orders,
           sum(price) FILTER (WHERE event_type = 'purchase')               AS revenue
    FROM d
    GROUP BY month
)
SELECT
    month, users, buyers, orders, round(revenue, 0) AS revenue,
    round(100.0 * buyers / users, 2)      AS buyer_rate_pct,
    round(1.0 * orders / buyers, 3)       AS orders_per_buyer,
    round(revenue / orders, 1)            AS aov
FROM m
ORDER BY month;

-- D2. Revenue bridge: contribution of each factor to the change (log-mean split, sums exactly to the change)
-- contribution_i = (Nov revenue - Oct revenue) * ln(factor_i Nov / factor_i Oct) / ln(Nov revenue / Oct revenue)
WITH d AS (
    SELECT strftime(date_trunc('month', event_time), '%Y-%m') AS month,
           user_id, user_session, event_type, price
    FROM events
    WHERE day(event_time) <= 30 AND day(event_time) NOT BETWEEN 14 AND 17
),
m AS (
    SELECT month,
           count(DISTINCT user_id) * 1.0                                         AS users,
           count(DISTINCT user_id) FILTER (WHERE event_type = 'purchase') * 1.0  AS buyers,
           count(DISTINCT user_session) FILTER (WHERE event_type = 'purchase') * 1.0 AS orders,
           sum(price) FILTER (WHERE event_type = 'purchase')                     AS revenue
    FROM d
    GROUP BY month
),
x AS (
    SELECT p.revenue AS r0, n.revenue AS r1,
           ln(n.users / p.users)                                         AS l_users,
           ln((n.buyers / n.users) / (p.buyers / p.users))               AS l_buyer_rate,
           ln((n.orders / n.buyers) / (p.orders / p.buyers))             AS l_orders,
           ln((n.revenue / n.orders) / (p.revenue / p.orders))           AS l_aov,
           ln(n.revenue / p.revenue)                                     AS l_total
    FROM m p, m n
    WHERE p.month = '2019-10' AND n.month = '2019-11'
)
SELECT 1 AS seq, 'October revenue' AS step, r0 AS value FROM x
UNION ALL SELECT 2, 'Users',            (r1 - r0) * l_users      / l_total FROM x
UNION ALL SELECT 3, 'Buyer rate',       (r1 - r0) * l_buyer_rate / l_total FROM x
UNION ALL SELECT 4, 'Orders per buyer', (r1 - r0) * l_orders     / l_total FROM x
UNION ALL SELECT 5, 'AOV',              (r1 - r0) * l_aov        / l_total FROM x
UNION ALL SELECT 6, 'November revenue', r1 FROM x
ORDER BY seq;
