# A/B test design: monthly installment payment on the product card

Context and sizing: `docs/feature_sizing.md`. Baseline and power numbers: `sql/07_ab_baseline.sql` (T1)
and `src/ab_power.py` -> `results/ab_power.csv`. The dataset has no payment data, so payment metrics
below are defined for the real test but cannot be computed here.

## 1. Hypothesis

**H1:** showing the monthly installment payment ("from X per month") on the product card of items priced
360 or more increases the share of exposed users who make a purchase during the test.
**H0:** no difference.
Rationale: price is a barrier for expensive items; a small monthly amount lowers it. Conversion falls clearly with
price in appliances (5.63% under 70 versus 2.56% at 360+) [feature_sizing.md, I3].

## 2. Population and randomisation

- **Population:** users who view at least one item priced 360 or more (about 25% of views, 66% of revenue).
  Users are counted from their first such view (triggered analysis), so users who never see an expensive item do not dilute the effect.
- **Randomisation unit: user.** The treatment changes what one person sees on every visit, so splitting by session
  would show the same person both versions and mix the effects. Assignment is a stable hash of `user_id` with a test-specific salt, 50/50.
- **Interference:** one user_id can be several people or devices, and a person can have several ids
  (see data cleaning limitations). Assumed to hit both arms equally.

## 3. Metrics

| Role | Metric | Why |
|---|---|---|
| **Primary** | Share of exposed users with at least one purchase during the test (overall purchase conversion) | Measures incremental sales |
| Guardrail | Average order value and ARPPU (revenue per buyer) | Conversion must not rise by selling cheaper baskets |
| Guardrail | Revenue per exposed user | The business outcome |
| Guardrail | Cancellation / return rate | Installments may attract orders that are cancelled |
| Guardrail | Share of card payments | Detects substitution of existing payment methods |
| Diagnostic | CTR of the installment element | Do people notice and use it |
| Diagnostic | Payment-type breakdown of orders | Where the extra orders come from |
| Diagnostic | Items per order | Separates a higher order value from more purchases (installments can raise order value without more items) |

**Why overall purchase conversion and not "installment conversion" as the primary metric.**
Installment conversion is undefined in control (nobody can pay in installments there), and it can rise
simply because buyers switch from card to installments without any extra sale. Overall conversion is
defined in both arms and counts only real additional purchases.
Conversion is also a better primary than revenue per user: revenue per user is heavy-tailed
(mean 114.15, standard deviation 860.37 in the baseline window), so it detects only a 4.62% change versus 1.60% for conversion.

## 4. Sample size, MDE and duration [results/ab_power.csv]

Two-sided alpha 0.05, power 0.80, 50/50 split. Baseline measured on 8-21 Oct from users who viewed an expensive item.

| Window | Exposed users | Per arm | Baseline conversion | MDE (conversion, relative) | MDE (revenue per user, relative) |
|---|---|---|---|---|---|
| 7 days | 465,348 | 232,674 | 11.24% | 2.31% | 6.02% |
| 14 days | 836,915 | 418,458 | 12.79% | 1.60% | 4.62% |

Users per arm needed for the sizing scenarios (14-day baseline): +10% uplift 11,158; +5% uplift 43,735; +2% uplift 269,947.
At 7 days the +2% scenario would be under-powered (312,688 needed, 232,674 available).

**Duration: 14 days** (two full weekly cycles; enough for a +2% effect; lets us compare week 1 and week 2 for a novelty effect).
Recompute the baseline just before launch (conversion is lower in November than in October) and avoid launching
during Black Friday or other promotions.

## 5. Statistical tests

| Metric | Type | Test |
|---|---|---|
| Overall purchase conversion, cancellation rate, card share | proportion | two-proportion z-test, 95% confidence interval for the difference |
| AOV, ARPPU | skewed mean, ratio | bootstrap CI (or linearisation for ratio metrics); winsorise at the 99.9th percentile because the top 0.1% of buyers hold 6.36% of revenue [A14] |
| Revenue per exposed user | skewed mean | bootstrap CI of the difference in means |

**Multiple comparisons.** One primary metric, tested at alpha 0.05. Guardrails and other secondary metrics form one family
and are corrected with Holm (or Bonferroni). Diagnostics are descriptive and are not used for the decision.
Subgroup cuts (for example appliances only) are fixed in advance; any other cut is exploratory.
Fixed horizon: no stopping on an early significant p-value (peeking inflates false positives).

## 6. Validity checks

- **SRM (sample ratio mismatch):** chi-square test of the arm sizes against the planned 50/50.
  Example: `scipy.stats.chisquare([n_control, n_treatment])`. If p < 0.001, the result is invalid:
  stop and look for a logging or assignment bug before reading any metric. Check overall and by day.
- A/A check of the assignment and metric pipeline before launch.
- Novelty effect: compare week 1 with week 2.
- Logging: the 14-17 Nov anomaly in this dataset shows that event logging can break; monitor daily event counts per arm.

## 7. Decision rule (fixed before the test)

Ship when **all** hold:
1. SRM check passes.
2. Primary: the 95% CI of the conversion difference is above 0 and the observed relative uplift is at least 1.6% (the MDE).
3. No guardrail breaches its margin: AOV and ARPPU not lower by more than 3% (proposed margin, to be agreed with the product owner),
   cancellation rate not higher by more than 0.5 percentage points (proposed), revenue per exposed user not significantly lower.

| Outcome | Decision |
|---|---|
| Conversion up, guardrails fine | Ship (consider rollout in stages) |
| Conversion up, but AOV or revenue per user down, or cancellations up | Do not ship as is; investigate which segment drives it and iterate (for example restrict to a price range) |
| Conversion flat, installment share up | Pure shift between payment methods: do not ship on these metrics alone; the case would need to rest on payment economics (not in our data) |
| Conversion down | Stop |
| CI wide and includes 0 | Inconclusive: report the CI; extending the test is allowed only if planned in advance |

### Scenario: installment conversion +10%, card payments -20%: ship or not?

These two numbers alone do not decide it, because they describe a shift between payment methods.
- **Arithmetic:** with installments at share I and card payments at share C of baseline orders, total orders change by
  0.10 x I - 0.20 x C. It is positive only if the installment share is more than twice the card share
  (ignoring other payment types). With a larger card base the total falls even though installments grow.
- **Decision:** read the primary metric and the guardrails. If overall conversion rose significantly and revenue per user did not fall,
  ship: the drop in card payments is expected substitution and the feature added sales.
  If overall conversion is flat, the feature moved payments without adding sales, so do not ship unless the economics of installments
  (margin, financing cost, cancellations) are better, which this dataset cannot show.

## 8. Limitations

- Baseline from October data, for a 14-day window with outcomes measured inside the window.
- No payment, cancellation or return data in the dataset; these metrics are defined for the real test only.
- The +2% / +5% / +10% sizing scenarios are assumptions (see feature_sizing.md).
- The guardrail margins (AOV and ARPPU not lower by more than 3%, cancellations not higher by more than 0.5 percentage points) are proposals, not derived from data.
