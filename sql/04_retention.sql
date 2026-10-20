-- 04_retention.sql
-- Weekly cohort retention on events_main (clean data without 14-17 Nov).
-- Cohort = users whose first event in the data falls in a 7-day window counted from 1 Oct
-- (cohort 0: 1-7 Oct, 1: 8-14 Oct, 2: 15-21 Oct, 3: 22-28 Oct). First visits on 29-31 Oct are not used.
-- Activity weeks are also 7-day windows from 1 Oct (week 0 = 1-7 Oct ... week 7 = 19-25 Nov).
-- Week 6 (12-18 Nov) is skipped because 14-17 Nov are excluded; week 8 (26-30 Nov) is partial and not used.
-- Left-censoring: "first event" means first event in our window; some October "new" users
-- may have visited before October.

-- R1. Visitor and buyer retention by weekly cohort (weeks 0-4 after the first week)
WITH base AS (
    SELECT user_id, CAST(event_time AS DATE) AS day, event_type
    FROM events_main
),
first_seen AS (
    SELECT user_id, min(day) AS first_day FROM base GROUP BY user_id
),
cohort AS (
    SELECT user_id, date_diff('day', DATE '2019-10-01', first_day) // 7 AS k
    FROM first_seen
    WHERE first_day BETWEEN DATE '2019-10-01' AND DATE '2019-10-28'
),
sizes AS (SELECT k, count(*) AS cohort_size FROM cohort GROUP BY k),
act AS (
    SELECT user_id,
           date_diff('day', DATE '2019-10-01', day) // 7 AS w,
           bool_or(event_type = 'purchase')              AS bought
    FROM base
    GROUP BY user_id, w
)
SELECT
    c.k                                    AS cohort,
    DATE '2019-10-01' + CAST(7 * c.k AS INTEGER) AS cohort_start,
    n.n                                    AS weeks_after,
    z.cohort_size,
    round(100.0 * count(a.user_id) / z.cohort_size, 2)                          AS visitor_retention_pct,
    round(100.0 * count(*) FILTER (WHERE a.bought) / z.cohort_size, 2)          AS buyer_retention_pct
FROM cohort c
JOIN sizes z ON z.k = c.k
CROSS JOIN (VALUES (0), (1), (2), (3), (4)) AS n(n)
LEFT JOIN act a ON a.user_id = c.user_id AND a.w = c.k + n.n
WHERE c.k + n.n <> 6 AND c.k + n.n <= 7
GROUP BY c.k, n.n, z.cohort_size
ORDER BY c.k, n.n;

-- R2. Repeat purchase: share of buyers with 2 or more orders (order = session with a purchase)
WITH o AS (
    SELECT user_id, count(DISTINCT user_session) AS orders
    FROM events_main
    WHERE event_type = 'purchase'
    GROUP BY user_id
)
SELECT
    count(*)                                                       AS buyers,
    count(*) FILTER (WHERE orders >= 2)                            AS repeat_buyers,
    round(100.0 * count(*) FILTER (WHERE orders >= 2) / count(*), 1) AS repeat_rate_pct,
    round(avg(orders), 2)                                          AS orders_per_buyer
FROM o;
