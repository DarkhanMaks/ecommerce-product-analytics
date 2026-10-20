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

## Limitations

- Two genuinely different events that share all 9 column values (same second, same product, same user and session) cannot be told apart from a duplicate and are removed.
- Bot detection is behavioural and approximate; the data has no device, IP or user-agent fields.
- `user_id` is not necessarily one person; 939 sessions contain more than one `user_id`.
- Roughly a third of purchase sessions contain no cart event [scratch check, S5: 462,538 of 1,402,758]. The funnel therefore must not assume view -> cart -> purchase is strictly sequential (handled in the funnel step).
