-- 07_ab_baseline.sql
-- Baseline numbers for the A/B test design (docs/ab_test_design.md), measured on October data
-- so that no excluded days are involved. Test population = users who view an expensive item
-- (price >= 360, see docs/feature_sizing.md). Windows start on 8 Oct and last 7 or 14 days.
-- Outcomes are measured inside the same window (a user counts as converted if they bought in the window).

-- T1. Exposed users, conversion, revenue per user (mean and standard deviation) for 7- and 14-day windows
WITH w(days, d_end) AS (VALUES (7, DATE '2019-10-14'), (14, DATE '2019-10-21')),
e AS (
    SELECT user_id, CAST(event_time AS DATE) AS day, event_type, price
    FROM events_main
    WHERE CAST(event_time AS DATE) BETWEEN DATE '2019-10-08' AND DATE '2019-10-21'
),
u AS (
    SELECT
        w.days,
        e.user_id,
        bool_or(e.event_type = 'view'     AND e.price >= 360)      AS exposed,
        bool_or(e.event_type = 'purchase')                         AS bought_any,
        bool_or(e.event_type = 'purchase' AND e.price >= 360)      AS bought_exp,
        coalesce(sum(e.price) FILTER (WHERE e.event_type = 'purchase'), 0) AS revenue
    FROM w
    JOIN e ON e.day <= w.d_end
    GROUP BY w.days, e.user_id
)
SELECT
    days,
    count(*) FILTER (WHERE exposed)                                                   AS exposed_users,
    avg(CASE WHEN bought_any THEN 1.0 ELSE 0.0 END) FILTER (WHERE exposed)            AS p_any_purchase,
    avg(CASE WHEN bought_exp THEN 1.0 ELSE 0.0 END) FILTER (WHERE exposed)            AS p_expensive_purchase,
    avg(revenue)         FILTER (WHERE exposed)                                       AS revenue_per_user_mean,
    stddev_samp(revenue) FILTER (WHERE exposed)                                       AS revenue_per_user_sd
FROM u
GROUP BY days
ORDER BY days;
