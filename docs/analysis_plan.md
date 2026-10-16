# Analysis plan

Written and committed **before** any metric was computed. It fixes definitions and questions so
that results cannot be tuned afterwards. If a definition has to change later, the change is
logged at the bottom of this file with the reason.

## 1. Data and scope

- Source: REES46 multi-category store, October and November 2019 (event log).
- Columns: `event_time` (UTC), `event_type` (view / cart / purchase), `product_id`, `category_id`,
  `category_code`, `brand`, `price`, `user_id`, `user_session`.
- One row = one event on one product. **One purchase event = one product, not one order.**
- There is no quantity, no order id, no payment type, no cancellations/returns, no traffic source,
  no device. Anything that needs these is out of scope or scenario-based (stated explicitly).
- All metrics are computed on the cleaned event table. Cleaning rules and how many rows each one
  removes are defined in step 2 (`sql/01_data_quality.sql`) and documented there.

## 2. Business questions

| # | Question | Step | Decision it could inform |
|---|---|---|---|
| Q1 | Where in view -> cart -> purchase do we lose the most users, and does it differ by category and price band? | 3 | Which funnel step to fix first (product page, cart, checkout) |
| Q2 | Which categories bring traffic but little revenue? Which are small but convert well? | 4 | Where to put merchandising, promo budget, assortment work |
| Q3 | Do new visitors come back and buy again? How fast does retention decay? | 5 | Whether to invest in retention (CRM, loyalty) or in acquisition |
| Q4 | Why did revenue change from October to November: more users, better conversion, more orders per buyer, or bigger baskets? | 6 | Whether November growth is sustainable or a Black Friday spike |
| Q5 | How big is the opportunity for an installment-payment label on expensive products? | 7 | Whether the feature is worth an A/B test and how to prioritise it |
| Q6 | How would we test that feature, and how long would it take? | 8 | Test design, duration, ship / no-ship rule |

## 3. Definitions

### 3.1 Entities

| Term | Definition | Notes |
|---|---|---|
| **User** | A distinct `user_id`. | Not a person: one person may have several ids, one id may be shared. Extreme users (bots) are handled in step 2. |
| **Session** | A distinct `user_session` value, as given in the data. | We do not rebuild sessions from timestamps. Sessions that contain several `user_id`s are flagged in step 2. |
| **Order** | A session with at least one purchase event. | The data has no order id. Several purchases in one session count as **one order**. Two sessions with purchases = two orders. |
| **Buyer** | A user with at least one purchase event in the period. | |
| **Active user** | A user with at least one event (any type) in the period. | |
| **Revenue** | Sum of `price` over purchase events. | Quantity is not available, so one purchase event = one unit. Gross revenue: no returns, cancellations or discounts known. |

### 3.2 Conversion

| Metric | Numerator | Denominator | Unit |
|---|---|---|---|
| **Session conversion** | Sessions with >= 1 purchase | Sessions with >= 1 view | Session |
| **User conversion (buyer rate)** | Users with >= 1 purchase in the period | Users with >= 1 view in the period | User, per period |
| **Funnel step rate** | Entities reaching step N+1 | Entities reaching step N | Session or user |

- Funnel stages: `view`, `cart`, `purchase`. A session or user reaches a stage if it has at least
  one event of that type. Stages are not forced to be nested: purchases without a prior view or
  cart in the same session are possible in logs, and their count is measured in step 2/3 before
  deciding how to treat them.
- Session-level and user-level conversion differ by construction: a user with 5 sessions and 1
  purchase counts once at user level but contributes 4 non-converting sessions at session level.
  Step 3 shows both and explains the gap.
- Period = calendar month (October, November) unless stated otherwise.

### 3.3 Money metrics

| Metric | Formula | Meaning |
|---|---|---|
| **AOV** | Revenue / orders | Average basket value |
| **ARPU** | Revenue / active users | Revenue per visitor, mixes conversion and basket |
| **ARPPU** | Revenue / buyers | Revenue per paying user |
| **Orders per buyer** | Orders / buyers | Purchase frequency in the period |

Identity used in step 6:

`Revenue = active users x buyer rate x orders per buyer x AOV`

so `ARPU = buyer rate x ARPPU` and `ARPPU = orders per buyer x AOV`. The factors must multiply back
to total revenue exactly; this is checked in step 6.

### 3.4 Retention and repeat purchase

| Metric | Definition |
|---|---|
| **Cohort** | Users grouped by the calendar week (Monday start) of their first event in the dataset, October only. |
| **Visitor retention, week N** | Share of the cohort with >= 1 event in week (cohort week + N). |
| **Buyer retention, week N** | Share of the cohort with >= 1 purchase in week (cohort week + N). |
| **Repeat purchase rate** | Buyers with >= 2 orders in the window / buyers. Orders as defined above (distinct purchase sessions). |

Known issues, stated now:

- **Left-censoring.** "First event" means first event in the dataset, not first ever. Some October
  "new" users are returning customers from before October. Cohorts are "first seen in our window".
- **Partial cohort weeks.** 1 Oct 2019 is a Tuesday, so the first and last October weeks are
  incomplete. Their treatment (keep with a flag, or drop) is decided in step 5 and logged here.
- **Right-censoring.** Late cohorts have fewer weeks of follow-up (the data ends 30 Nov), so
  retention curves are compared at equal ages only.
- **Black Friday** (29 Nov 2019) falls at the end of the window and lifts November activity.
  Any October vs November comparison is confounded by it.

## 4. Metric roles (product view)

| Role | Metrics | Why |
|---|---|---|
| **Key** | Buyer rate (user conversion), revenue per active user (ARPU) | Direct measures of the business outcome |
| **Guardrail** | AOV / ARPPU | A change that lifts conversion by selling cheaper baskets must be visible |
| **Diagnostic** | Funnel step rates, view-to-cart, cart-to-purchase, category conversion | Explain *where* a change in a key metric comes from; not decision metrics |

Step 8 extends this for the installment test (for example share of card payments and cancellations
as guardrails), noting that those fields do not exist in this dataset.

## 5. Unit of analysis per question

| Question | Unit | Why |
|---|---|---|
| Q1 funnel | Session and user (both) | Session shows page-flow friction; user shows whether people eventually buy |
| Q2 categories | Event / product-view and purchase event, aggregated by category | Revenue is an event-level quantity; conversion shown at session level where possible |
| Q3 retention | User | Retention is about people returning |
| Q4 decomposition | Month-level aggregates of users, buyers, orders | Matches the multiplicative identity |
| Q5-Q6 feature | User for randomisation; session for exposure | Avoids a user seeing both variants |

## 6. What this project will not claim

- Causal effects. This is observational data; the installment uplift is a **scenario**, not an estimate.
- Anything about payment type, margins, returns or acquisition channel.
- That user_id equals a person, or that October-new users are truly new.

## Change log

_(none yet)_
