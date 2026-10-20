# Memo: what the October-November 2019 data says and what to do

**For:** Product Manager. **Data:** 109,532,442 cleaned events, 5,316,010 users, 22,752,678 sessions.

## Summary

November brought many more users, but they did not bring more revenue: over the same 26 days in each month revenue was 186,687,995 in October and 186,978,477 in November. The extra users (2,728,612 to 3,378,360) were offset by a lower buyer rate (11.03% to 9.40%) and smaller baskets (AOV 362.4 to 342.3). Electronics is the business: 36.3% of views and 76.9% of revenue. A quarter of the views (items priced 360 or more) bring two thirds of the revenue.

## Recommendations (in priority order)

### 1. Test a monthly-payment label on expensive items, starting with appliances

- **Why:** items priced 360+ are 24.7% of views and 65.9% of revenue. Conversion falls clearly with price in appliances (5.63% under 70 versus 2.56% at 360+).
- **Expected impact:** 5,486,870 / 13,717,175 / 27,434,351 of extra revenue over the analysed period (1.32% / 3.29% / 6.58% of period revenue) if conversion of the segment rises by 2% / 5% / 10%. **These uplifts are assumptions;** the data has no payment information. The A/B test measures the real effect.
- **How:** user-level randomisation, 14 days, smallest detectable effect 1.60%, primary metric overall purchase conversion, guardrails AOV, revenue per user, cancellations and card share (`docs/ab_test_design.md`).
- **Confidence:** medium. The audience is large and measurable; the effect size is unknown.

### 2. Fix the quality of new traffic and bring users back in the first week

- **Why:** in the revenue bridge (same 26 days) more users added 39,907,072, but the lower buyer rate cost 29,875,349 and smaller baskets cost 10,644,111. Retention drops mostly after the first week: 19.65% to 34.73% of new visitors come back, and 4.93% of the first cohort bought in week 1 (cohort of 957,487 users).
- **Expected impact:** this is a hypothesis to test. If November's buyer rate had stayed at October's level, the bridge suggests up to 29,875,349 more revenue in those 26 days; this is an upper bound, not a forecast.
- **How:** compare buyer rate and AOV for new versus returning users by acquisition source (not in this dataset) before scaling acquisition; test a first-week reminder or remarketing message with the same A/B approach.
- **Confidence:** low to medium. Black Friday (29 November) is mixed into the November numbers.

### 3. Fix product categorisation and look at computers and appliances

- **Why:** 33.0% of views have no category and give 10.3% of revenue, so category decisions are blind there. Among known categories computers (conversion 3.72%, AOV 455) and appliances (5.51%, AOV 197) have large traffic and room to improve.
- **Expected impact (illustration):** each +1 percentage point of conversion is worth 5,401,729 in computers, 4,252,672 in appliances and 10,066,803 in the unlabelled group over the analysed period (assumes the average order value of the category).
- **How:** add the missing categories at the source; then review the product pages of the two categories.
- **Confidence:** medium for the categorisation fix, low for the conversion lift.

## Data issues to know about

- 14-17 November are excluded: purchases are recorded in uneven blocks there (zero for 37 hours, then several times the normal hourly rate) while views triple. Those four days carry 88,164,936 of revenue, 32% of November in the cleaned data. Worth raising with the data engineering team.
- Cart events are logged inconsistently across months, so cart-based funnel steps are not reliable.
- There is no payment, cancellation or margin data, so payment-related claims need the test.

## Next steps

1. Agree the guardrail margins and the launch window (avoid Black Friday).
2. Recompute the baseline conversion just before launch.
3. Run the 14-day test and apply the decision rule written in advance.
