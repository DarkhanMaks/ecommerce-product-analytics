# Data cleaning rules

Raw data: REES46 events, October + November 2019, **109,950,743 rows**
(42,448,764 in October, 67,501,979 in November). Every number below comes from
`sql/01_data_quality.sql` (query ids in brackets) or `sql/01a_build_clean_events.sql`.
The cleaned table is written to `data/events_clean.parquet` and is the input of all later steps.

## Rules applied

| # | Rule | Rows affected | Share of raw | Why |
|---|---|---|---|---|
| 1 | Drop rows with missing `user_session` [A2, A9] | 12 | ~0 | A session is our unit of visit; these rows cannot be assigned to one. All 12 are cart events from 12 different users. |
| 2 | Drop exact duplicates (all 9 columns equal), keep one copy [A4, A5] | 130,739 | 0.119% | Identical events recorded more than once. 97% of the extra copies are cart events (126,985 of 130,739), so unchecked they inflate the cart step of the funnel. |
| 3 | Drop bot-like users: at least 100 sessions and fewer than 1.5 events per session [A16, C4] | 287,550 events from 639 users (249 purchases, revenue 59,033) | 0.012% of revenue | See "Bot rule" below. |
| 4 | Treat `price = 0` as missing: set `price` to NULL, keep the row [A6, A7, C3] | 252,818 rows remain with NULL price after rules 1-3 | about 0.23% of raw rows (256,761 zero-price rows before cleaning) | Zero price is a missing value on view/cart events (252,203 views, 4,558 carts). There are **no zero or negative prices on purchases**, so revenue is unaffected. Price-band analysis must exclude NULL prices. |

Total rows removed by rules 1-3: 418,301 (109,950,743 -> 109,532,442).
Rule 4 changes values but removes no rows.

## Clean data baseline [A17]

| Month | Events | Users | Sessions | Purchase events | Revenue |
|---|---|---|---|---|---|
| 2019-10 | 42,390,452 | 3,022,218 | 9,219,091 | 742,761 | 229,923,848 |
| 2019-11 | 67,141,990 | 3,695,481 | 13,537,404 | 916,693 | 275,143,413 |
| Total | 109,532,442 | 5,316,010 | 22,752,678 | 1,659,454 | 505,067,261 |

Monthly users and sessions do not add up to the total because users active in both months
and sessions that cross midnight at the month boundary are counted in both rows.
Revenue is the sum of `price` over purchase events (currency not stated in the data).

## Checked, no action

| Item | Finding | Decision |
|---|---|---|
| Missing `category_code` [A2] | 35,413,780 rows (32.209%) | Keep rows. Analyse as `unknown` category; always report its share. `category_id` is never missing. |
| Missing `brand` [A2] | 15,331,243 rows (13.944%) | Keep rows, treat as `unknown`. |
| Other columns [A2] | 0 missing in event_time, event_type, product_id, category_id, price, user_id | None needed. |
| Negative prices [A7] | 0 | None. |
| Extreme prices [A6] | max 2,574.07 vs p99 1,688.82; median 164.93 | No outlier cap needed. Price distribution is right-skewed (mean 291.63 > median), so use medians for "typical price". |
| Sessions with more than one `user_id` [A8] | 939 sessions, 2,962 events, max 3 users | Keep. Affects a negligible share of sessions; noted as a limitation. |
| Event types [A1] | only view, cart, purchase | None. |

## Bot rule: how the threshold was chosen

1. Events per user is heavy-tailed [A10]: median 5, p99 225, p99.99 1,283, max 22,929.
2. A pure volume cut does not work [A13, A15]: among users with more than 1,000 events,
   only 292 of 1,168 bought nothing, and their sessions look like everyone else's
   (median 13.5 events per session versus 10.7 for buyers with 11+ purchases).
   Cutting at 300 events would remove 9.46% of revenue. So high activity alone is not a bot signal.
3. A behavioural signature works [A11, A16]: scanners start a new session for almost every
   event (for example one user: 22,929 events in 22,542 sessions, 0 purchases).
   Rule: sessions >= 100 AND events < 1.5 x sessions. In raw data this flags 639 users,
   574 of them (89.8%) with no purchase, and holds 0.262% of events, 0.015% of purchases, 0.012% of revenue.
4. Raising the session threshold to 300 or 1,000 does not make the flagged group purer
   (86% and 88% without purchases), so the lowest tested threshold (100) was kept.

This is a heuristic, not proof: 65 of the 639 flagged users did buy something. Revenue impact is
0.012%, so the conclusion is not sensitive to the choice.

## Heavy buyers are kept [A14]

The top 0.1% of buyers (698 people) generate 6.36% of revenue and the top 1% generate 20.96%.
They look like real customers (for example resellers or business buyers), so they stay in the data.
Revenue is moderately concentrated; this is reported in the revenue decomposition step.

## Time anomalies found in the daily profile [A18] (decision: exclude 14-17 Nov from the main analysis)

- **Cart events switch on and off on specific dates.** Carts per 100 views: 1.34-1.72 on 1-3 Oct,
  2.45-3.17 on 4-6 Oct, 1.35-1.52 on 7-13 Oct, 2.49-3.28 on 14-27 Oct, 1.08-1.41 from 28 Oct to 7 Nov,
  then 3.60-4.21 from 8 Nov. Step changes on exact dates look like a change in how cart events are
  recorded rather than customer behaviour (hypothesis, not proven). Black Friday (29 Nov: 5.17) does not explain the 8 Nov jump.
- **Cart events grew 3.27x from October to November** (926,516 -> 3,028,930 raw events [A1]),
  against 1.56x for views and 1.23x for purchases. Duplicates cannot explain it: extra cart copies in all data total 126,985 [A5].
  (The monthly split of duplicate copies, 28,073 in October and 98,912 in November, comes from a one-off check; add it to the SQL file before quoting it publicly.)
- **14-17 November are anomalous.** Views: 1,906,883 (13 Nov), 2,855,084 (14 Nov), 5,735,339 (15 Nov),
  6,026,872 (16 Nov), 5,781,753 (17 Nov), 1,897,940 (18 Nov). Purchases: 22,118 (14 Nov), **0 (15 Nov)**,
  68,247 (16 Nov), 185,191 (17 Nov), against roughly 22,000-28,000 on normal days. Cause unknown
  (tracking outage with backfill, or abnormal traffic). November totals, the October vs November
  comparison and the revenue bridge depend on how this window is treated.
- **What the investigation showed** [B1-B4, sql/01b_november_anomaly.sql]: it is not a handful of bots
  (top 1,000 users hold 3.83% of events on 16 Nov versus 5.9% on 12 Nov; first-seen users are not elevated).
  Many users are simply more active (about 13-16 events per user per day versus about 7), purchase events stop
  completely from about 19:00 on 14 Nov to 07:00 on 16 Nov and again from 16:00 on 16 Nov to 02:00 on 17 Nov
  while views and carts continue, then purchases arrive at several times the normal hourly rate (8,000-15,900 per hour versus 1,000-1,600 on a normal afternoon). The 14-17 Nov
  window carries 88,164,936 of revenue [B4 sum], 32% of November revenue [A17], in 4 of 30 days.
  The data cannot say whether this was a short sale, a checkout outage or a logging failure.
- **Decision:** the main analysis (view `events_main`, defined in `sql/00_setup.sql`) excludes the calendar days
  14-17 Nov. The cleaned file keeps those rows. Month-to-month revenue comparisons use like-for-like windows
  (days 1-13 and 18-30 of each month, 26 days each) so that the 4 missing days do not bias them. The exclusion is stated as a limitation in the README.

## Limitations

- Two genuinely different events that share all 9 column values (same second, same product, same user and session) cannot be told apart from a duplicate and are removed.
- Bot detection is behavioural and approximate; the data has no device, IP or user-agent fields.
- `user_id` is not necessarily one person; 939 sessions contain more than one `user_id`.
- 462,518 of 1,402,518 purchase sessions (33.0%) contain no cart event [A19], but the share is 53.6% in October and 16.1% in November. The average hides two very different regimes, so the funnel must not assume view -> cart -> purchase is strictly sequential, and cart-based metrics need care (see "Time anomalies"). Only 45,485 of the 462,518 no-cart purchase sessions have an earlier cart for the same product by the same user, so "the cart was in another session" explains little.
- 6,784 purchase sessions have no view event [A19]; purchases without a prior view are also possible.
