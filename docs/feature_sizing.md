# Feature sizing: monthly installment payment on the product card

Feature: on the product card of expensive items show "from X per month" (installment payment).
Question: is the opportunity big enough to justify an A/B test, and how big could it be?

**The dataset has no payment data** (no payment type, no installments, no cancellations). The uplift
below is therefore **scenario-based, not estimated from data**. What the data does provide is the
size of the audience and the baseline. Queries: `sql/06_installment_sizing.sql` (I1-I3).
Period: the analysis window, all of October and 26 days of November (14-17 Nov excluded).
The numbers are for this period, not per month.

## Addressable segment [I1]

Expensive = event price of at least 360 (about the 75th percentile of event prices).

| Metric | Value |
|---|---|
| Sessions that viewed an expensive item | 6,854,076 |
| Of them, sessions with a purchase of an expensive item | 304,196 |
| Baseline conversion in the segment | 4.44% |
| Share of all views | 24.7% |
| Share of revenue | 65.9% |
| Average order value (expensive items) | 902 |

A quarter of the traffic brings two thirds of the revenue.

## Is conversion lower for expensive items? [I3, F4]

Across the whole store, no: conversion is 4.39% / 4.41% / 4.75% / 4.44% for the four price bands [F4].
Within categories the picture is mixed:

| Category | under 70 | 70-165 | 165-360 | 360+ |
|---|---|---|---|---|
| Appliances | 5.63% | 4.28% | 3.89% | 2.56% |
| Computers | 3.58% | 2.28% | 3.95% | 2.71% |
| Electronics | 4.28% | 6.80% | 6.55% | 5.88% |

Conversion falls clearly with price in appliances (574,553 sessions in the 360+ band at 2.56%), only mildly in
electronics and without a clear pattern in computers. The store-wide average is flat because expensive items are
mostly electronics, which convert well. Expensive appliances are the sharpest sub-segment for the test.

## Scenarios [I2]

Relative uplift of conversion among exposed sessions. **The uplift values are assumptions.**

| Scenario | Uplift | New conversion | Incremental orders | Incremental revenue | Share of total revenue |
|---|---|---|---|---|---|
| Low | +2% | 4.53% | 6,084 | 5,486,870 | 1.32% |
| Base | +5% | 4.66% | 15,210 | 13,717,175 | 3.29% |
| High | +10% | 4.88% | 30,420 | 27,434,351 | 6.58% |

Incremental orders = converted sessions x uplift. Incremental revenue = orders x average order value of expensive items (902).

## Assumptions

1. Exposure: every session that viewed an item priced 360 or more would see the installment label.
2. Eligibility: all such items are eligible for installments (in reality eligibility is narrower).
3. Only the conversion of exposed sessions changes; views, other categories and cart behaviour stay the same.
4. Uplift is relative to today's conversion (4.44%) and is assumed (+2%, +5%, +10%), not measured.
5. Incremental orders have the average order value of expensive items (902). New buyers may buy less, so this can overstate revenue.
6. No change in cancellations, returns or payment mix, and no cannibalisation of other payment methods (not measurable here).
7. Revenue is gross price of purchase events; margin, financing cost and interest are not considered.
8. Figures are for the 57-day analysis window, not per month.
9. Heavy buyers are kept in the data (top 0.1% of buyers hold 6.36% of revenue [A14]).

## Two other ways to size the feature

- **Analogues:** take the conversion lift measured for comparable past launches (a similar payment feature, a similar label on another product page) and apply it to this segment. Replaces the assumed +2/5/10%.
- **User research / fake-door test:** survey or interview buyers of expensive items, or show a non-functional "from X per month" element to a small share of users and measure the click rate. Gives evidence about demand before building anything.

## Conclusion

The segment is large (24.7% of views, 65.9% of revenue), so even the low scenario is worth testing
(1.32% of period revenue). The size of the real effect is unknown and is exactly what the A/B test measures.
