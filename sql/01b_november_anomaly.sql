-- 01b_november_anomaly.sql
-- Goal: understand what happened on 14-17 Nov 2019 (views up to 3x normal,
-- 0 purchases on 15 Nov, 185,191 purchases on 17 Nov). Reads the cleaned view `events`.

-- B1. Who is in the traffic? Users, sessions and first-time users per day (10-20 Nov)
SELECT
    e.day,
    count(*)                                                      AS events,
    count(DISTINCT e.user_id)                                     AS users,
    count(DISTINCT e.user_session)                                AS sessions,
    count(DISTINCT e.user_id) FILTER (WHERE f.first_day = e.day)  AS first_seen_users,
    round(count(*) * 1.0 / count(DISTINCT e.user_id), 1)          AS events_per_user
FROM (SELECT *, CAST(event_time AS DATE) AS day FROM events) e
JOIN (SELECT user_id, min(CAST(event_time AS DATE)) AS first_day
      FROM events GROUP BY user_id) f USING (user_id)
WHERE e.day BETWEEN DATE '2019-11-10' AND DATE '2019-11-20'
GROUP BY e.day
ORDER BY e.day;

-- B2. Hour by hour: when did views and purchases jump or stop? (14 Nov 12:00 - 18 Nov 00:00)
SELECT
    date_trunc('hour', event_time)                    AS hour,
    count(*) FILTER (WHERE event_type = 'view')       AS views,
    count(*) FILTER (WHERE event_type = 'cart')       AS carts,
    count(*) FILTER (WHERE event_type = 'purchase')   AS purchases
FROM events
WHERE event_time >= TIMESTAMP '2019-11-14 12:00:00'
  AND event_time <  TIMESTAMP '2019-11-18 00:00:00'
GROUP BY 1
ORDER BY 1;

-- B3. Is the extra traffic concentrated in a few users? (normal day 12 Nov vs 16 Nov)
WITH x AS (
    SELECT CAST(event_time AS DATE) AS day, user_id, count(*) AS n
    FROM events
    WHERE CAST(event_time AS DATE) IN (DATE '2019-11-12', DATE '2019-11-16')
    GROUP BY 1, 2
),
r AS (SELECT *, row_number() OVER (PARTITION BY day ORDER BY n DESC) AS rk FROM x)
SELECT
    day,
    count(*)                                                         AS users,
    sum(n)                                                           AS events,
    round(100.0 * sum(n) FILTER (WHERE rk <= 1000) / sum(n), 2)      AS pct_events_top1000_users,
    max(n)                                                           AS max_events_one_user
FROM r
GROUP BY day
ORDER BY day;

-- B4. Purchases, buyers and revenue per day (10-20 Nov)
SELECT
    CAST(event_time AS DATE)                                              AS day,
    count(*) FILTER (WHERE event_type = 'purchase')                       AS purchases,
    count(DISTINCT user_id) FILTER (WHERE event_type = 'purchase')        AS buyers,
    round(sum(price) FILTER (WHERE event_type = 'purchase'), 0)           AS revenue,
    round(avg(price) FILTER (WHERE event_type = 'purchase'), 1)           AS avg_item_price
FROM events
WHERE CAST(event_time AS DATE) BETWEEN DATE '2019-11-10' AND DATE '2019-11-20'
GROUP BY 1
ORDER BY 1;
