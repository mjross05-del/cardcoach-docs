# CardCoach Revenue Model — v3

**Built:** 2026-08-28, replacing Phase 4 v2 (May 2026) · **Currency:** CAD throughout
**Horizon:** 24 months, M1 = **Sep 2026** · **Live model:** `01_CORE/data/CardCoach_Revenue_Model_v3.xlsx`
**Companion:** `PRICING_TIERS_2026-08-28.md` — the structures, weighed
**Reproduce with:** `01_CORE/data/model_v3/final_numbers.py` for §1, §3–§5 and the growth and
break-even tables; `tiers.py` for the ten-structure comparison and `free_vs_pro.py` for the
Free/Pro grid quoted from `PRICING_TIERS_2026-08-28.md`
**Decision record:** `PIPELINE_AND_DECISIONS.md`, 2026-08-28

> **What happened to v2.** It was not wrong to have; it was wrong by 2026-08-28, in
> one direction, on every major assumption at once. `01_CORE/data/model_v3/legacy_check.py`
> reproduces v2's published $113,441 / $60,918 / $45,848 / $6,675 **to the dollar**
> before changing anything, so what follows is a set of deliberate corrections rather
> than a different model. v2's numbers should not be quoted anywhere from today.

---

## The three numbers

| Metric | v2 said | **v3 says** |
|---|---|---|
| 12-month revenue | $12,807 | **$793** |
| 24-month revenue | $113,441 | **$5,438** |
| 24-month net after $12,000 burn | +$101,441 | **-$6,562** |
| First monthly break-even | Month 6 | **Month 22** |
| First cumulative break-even | Month 9 | **not inside 24 months** |
| Worst point | -$1,344 at M5 | **-$6,976 at M21** |
| Top sensitivity | monthly churn | **web traffic growth** |

Figures are for the recommended **Free + Pro** configuration (§3), starting from the measured M1 traffic and
growing at the 15%/month this model assumes. **Only M1 is measured**; the growth rate is
judgment, and it accounts for 87% of cumulative 24-month traffic. The workbook and the Python model agree
on all **nine** scenarios they share; T8's lifetime SKU is Python-only (the workbook's T8 row is
T3 without it), and the workbook's P8/P9 rows have no `tiers.py` counterpart. Twelve is the count
of dropdown entries, not of agreeing scenarios.

**This is not a forecast that CardCoach fails, and it is not an assumption of no growth.**
The base case compounds traffic at 15%/month (110 → 2,738 visits) and app signups at 12%/month
(15 → 258). It is one scenario on a curve, not a prediction.

**The scenario that matters most:** at the growth rate **Phase 4 v2 itself assumed** — 27.3%/month
— this corrected model returns **+$13,026 over 24 months**, on the same corrected approval rate,
commission, coverage and churn. Cumulative break-even lands at **21.9%/month**.

| Traffic growth | 24-month revenue | 24-month net | Visits/mo at M24 |
|---|---|---|---|
| 10%/mo | $3,562 | −$8,438 | 985 |
| **15%/mo — base case** | **$5,438** | **−$6,562** | **2,738** |
| 20%/mo | $9,491 | −$2,509 | 7,287 |
| **21.9%/mo — break-even** | ~$12,000 | **$0** | **10,394** |
| 25%/mo | $18,197 | +$6,197 | 18,635 |
| 27.3%/mo — v2's own rate | $25,026 | +$13,026 | 28,343 |
| 35%/mo | $75,485 | +$63,485 | 109,413 |

So v2's error was not optimism about the destination. It was that **a single unexamined
assumption was carrying the entire result** — hardcoded in a spreadsheet column where nobody
could argue with it — while every other assumption leaned the same way. The useful output of
this model is the growth rate the business needs, not the dollar figure at any one rate.

Section 5 states what has to change and by how much. An interactive version of the whole model,
where every input above is a slider, is published as the **CardCoach Revenue Planner** artifact.

---

## 1. Why v2 was off by 19x

Five errors, all pointing the same way.

**The traffic ramp.** v2's visit column ran 100 → 25,650/month over 24 months. That is
**27.3% compounding, every month, for two years**, and it was hardcoded rather than
expressed as an assumption anyone could challenge. Measured Canadian traffic to
cardcoach.ca is **3, 3 and 5 visits** on 2026-08-25/26/27 — about **110/month**
(Cloudflare `httpRequestsAdaptiveGroups`, `clientCountryName = CA`, `sum.visits`).
Almost everything else hitting the site is WordPress vulnerability scanners; the top
request origins are the Netherlands, the US and France, with **Canada fourth at ~7%**.

**The approval rate.** v2 assumed 60% of completed applications get approved. The CFPB
puts **unsolicited online applications at ~38%** — the channel a comparison site
actually feeds. No Canadian issuer publishes approval rates, so this is a US proxy,
and it is still better than the number it replaces.

**The commission — wrong in the *other* direction.** v2 used $65, a midpoint of a
"$40–90" range traceable to a Fintel Connect article whose supporting data is
2017–2021. Fintel's live brand page publishes **$110–175 CAD per approved Scotiabank
credit card**. v3 uses **$142.50**. This is the one correction that helps.

**Coverage was assumed to be total.** v2 paid a commission on every approval. Of the
16 issuers in the catalogue, Fintel Connect carries **RBC, Scotiabank, Tangerine, Neo,
Simplii and Vancity**. It does **not** carry TD, CIBC, American Express, MBNA, Home
Trust, Brim, PC Financial, Rogers Bank or Desjardins — and National Bank's page now
404s. v3 introduces an explicit **issuer coverage** input, set at **40%**.

**Churn was roughly three times too kind.** v2 used 12%/month for monthly plans and
3.5%/month for annual. RevenueCat's published Utilities medians are **57% monthly
first-renewal** — about 43% churn in month one — and **35% annual first-renewal**,
— meaning 65% of annual subscribers are gone at the first renewal. v3 replaces the smoothing
with **cohort survival**, which v2's own "what this does not cover" section asked for,
calibrated so 12-month monthly retention lands at 10.85% against RevenueCat's published 11%
median. Annual cohorts run their full term and then meet a renewal cliff at month 12 and again
at 24, rather than leaking a smoothed percentage every month.

**And one thing v2 left out that changes conclusions.** v2 credited in-app affiliate
revenue **only to paying subscribers**. Free users earn nothing in that structure,
which silently biases every pricing comparison toward paywalls. v3 credits free users
at the rate v2's own text quotes (0.30%/month, re-based to 0.19% at the corrected
approval rate). Correcting this is what turns the hard-paywall scenario from an
obvious win into a marginal one.

---

## 2. What is actually true today

Measured 2026-08-28 against production, not remembered.

| | |
|---|---|
| Revenue earned to date | **$0.** `public.billing_events` has **0 rows** |
| Affiliate revenue earned to date | **$0.** All 126 links are `network:"direct", sponsored:false` |
| Canadian web visits | **~110/month** |
| App signups | **15** in Aug 2026 · 82 lifetime · **19** signed in within 30 days |
| Users holding cards | **32**, holding **86** cards |
| Entitlements granted | **50** — all comped testers |
| Catalogue | **149** card products, **16** issuers (v2 said "95+") |
| Android | not in production — internal testing only |
| iOS subscriptions | cannot be sold. See `RUNBOOK_pro_go_live_2026-08-24.md` §1 |

Both revenue streams are at zero, for different reasons, and neither reason is
technical. Affiliate is waiting on network applications. Subscriptions are waiting on
the Apple account-structure decision.

---

## 3. Pricing

**Configured today:** `cardcoach_pro_monthly` **$4.99** and `cardcoach_pro_annual`
**$39.99**, gates off. The v2 price drift note is now closed: v3 prices $4.99/$39.99
as the baseline and the $3.99/$34.99 figures are retired.

**Recommended: Free + Pro — the structure that already exists.**

`public.billing_tiers` holds **exactly one row, `pro`**. Free is the absence of it. Nothing below
needs a new tier, a second RevenueCat entitlement, or extra SKUs.

| Tier | Monthly | Annual | Holds |
|---|---|---|---|
| **Free** | — | — | up to **3 cards**, manual place selection, the whole engine |
| **Pro** | **$7.99** | **$59.99** (37% off) | all six entitlements, as seeded today |

Two flags do the work, both already built and switched off: `card_slot_limit` and
`auto_location_gate`. **Worth +9.4% over today's configuration.**

**The Free/Pro line matters more than the price does.** Moving from everything-free to a 3-card
cap plus gated auto-location is worth **+8.1%** at a fixed $4.99; moving $4.99 → $11.99 at a
fixed free shape is worth **+2.7%**. And $7.99 is a **judgment, not an optimum**: the revenue-maximal price swings from $4.99 at
e = 1.3 to $11.99 at e = 0.4, so no price is optimal without an elasticity nobody has measured,
and the whole range is worth 4.4% on the mean. $7.99 is a mid-market point below every comparable
with room to raise. (An earlier draft justified it as having the "best worst-case rank" across
the sweep; that criterion is an artifact — it always selects the median of whatever price grid
you write down — and is withdrawn. See `PRICING_TIERS_2026-08-28.md` §5A.)

A **Plus/Pro ladder** is worth **+5.0% / +8.8% / +14.2%** over this recommendation across the
elasticity sweep — reliably positive, and worth more the more price-sensitive the market turns
out to be. It is deferred on **sequencing**, not on the numbers: it needs a second tier row and
entitlement, two more SKUs and paywall rework, and the conversion rate that decides whether it
pays is swept rather than known. Ship Free + Pro, sell something, measure, then build it against
data. Full working in `PRICING_TIERS_2026-08-28.md` §5A.

**Store cut: 15%, and v2 was right about this.** Apple's Small Business Program is
free and new developers qualify automatically; Google Play charges 15% flat on
subscriptions in Canada from day one. The 2026 US link-out ruling and the EU DMA tiers
do **not** apply in Canada. Enrolling is worth 4.5% of 24-month revenue.

**Trial: 14 days, not the 7 in the runbook.** RevenueCat's day-0 trial cancellation is
39.8% at 7 days against 35.7% at 14; trial-to-paid runs 25.5% for trials of ≤4 days
against 42.5% at 17–32 days. Trial length is a model input in v3: **+4.4% revenue for a
dropdown change in App Store Connect**. A 30-day trial models at +11.8% but delays cash and
widens refund exposure; a 3-day trial costs 3.1%.

---

## 4. Sensitivity — what actually moves the answer

Each variable moved alone, against the recommended Free + Pro configuration.

| # | Variable | 24-mo revenue | vs base |
|---|---|---|---|
| 1 | Traffic growth 15% → 25%/mo | $18,197 | **+235%** |
| 2 | App signup growth 12% → 20%/mo | $8,805 | **+62%** |
| 3 | Affiliate coverage 40% → 70% | $8,512 | **+57%** |
| 4 | Click-to-affiliate 6% → 9% | $7,048 | +30% |
| 5 | Approval 38% → 50% | $6,475 | +19% |
| 6 | Commission $142.50 → $175 / $110 | $6,373 / $4,503 | ±17% |
| 7 | **Both gates off — today's free tier** | **$5,011** | **−7.8%** |
| 8 | Web → signup 2% → 4% | $5,831 | +7% |
| 9 | Trial 7 → 14 days | $5,676 | +4% |
| 10 | **Auto-location returned to free** | **$5,196** | **−4.4%** |
| 11 | Store cut 15% → 30% (no SBP) | $5,202 | −4% |
| 12 | Affiliate launch M3 → M7 | $5,286 | −3% |
| 13 | Subscription launch M4 → M8 | $5,292 | −3% |
| 14 | **Free cap 3 → 4 cards** | **$5,338** | **−1.8%** |
| 15 | Annual mix 40% → 60% | $5,537 | +2% |
| 16 | Monthly retention 86% → 91% | $5,530 | +2% |
| 17 | **Free cap 3 → 2 cards** | **$5,508** | **+1.3%** |
| 18 | Annual renewal 35% → 50% | $5,450 | +0.2% |

**The Free/Pro line earns its place in this table.** Turning both gates off costs 7.8% — more
than the trial length, the store cut, or a four-month launch slip. Tightening the cap from 3 to
2 buys only 1.3% and strands 17 of 32 existing users, which is why it is not recommended.


**The ranking inverted from v2.** v2 named churn the single most-leveraged variable.
At the real scale it is second from last — there is almost no base to retain, and the
first annual renewal does not land until M16. Traffic and reach are the whole game.

**Pricing is worth 22.1%** — the whole spread from the worst structure to the best at
e = 0.8. Real, nearly free to capture, and an order of magnitude smaller than traffic.

---

## 5. What break-even actually requires

| Path | Requirement | Against measured |
|---|---|---|
| Traffic | **21.9%/month growth** → 10,394 visits/mo by M24 | **94x** today's 110 |
| App reach | **69 signups/month** from M1 | **4.6x** the measured 15 |
| Affiliate coverage | 100% issuer coverage — still nets **−$414** | cannot reach it alone |

Traffic is the only single lever that reaches break-even, and the required rate is
below what v2 assumed without noticing. Two independent facts make it harder than it
was when v2 was written: **NerdWallet's Q4 2025 credit-card revenue fell 24% YoY**,
management attributing it to AI-summary traffic loss; and roughly **83% of
AI-Overview searches now end without a click**. The top of this funnel is contracting
for everyone.

**The clearest available step-changes, in order of measured leverage:**

1. **Get the affiliate links earning.** They have been live and unmonetised since
   2026-08-11. The pre-flight items in `PACKET_affiliate_applications_2026-08-24.md`
   are closed. Apply Tuesday–Friday, per Fintel's own advice.
2. **Apply to Milesopedia Network.** The only route found to TD, CIBC, Amex, MBNA, PC
   Financial and Rogers Bank — the issuers Fintel does not carry. Coverage 40% → 70%
   is worth **+57%**.
3. **Ship Android to production.** Signup growth is the second-largest lever and the
   Android base is entirely untapped.
4. **Take the Apple account decision.** It gates all subscription revenue and costs
   ~3% for every four months it slips. `RUNBOOK_pro_go_live_2026-08-24.md` §1.
5. **Flip the gates.** Worth **7.8%** on its own, for two boolean flags that already exist —
   and it is the whole Free/Pro decision, which matters more than the price does.

---

## 6. Hard constraints, unchanged

- **Commission-blind ranking.** Flat conversion rates across cards, matching the
  data-layer enforcement in the engine. Not negotiable and not modelled away.
- **No ads.**
- **Canada-only, CAD throughout.**
- **Welcome bonus pipeline not shipped** — no application uplift modelled from welcome
  offers. Tracked in `WORKING_NOTES.md` #5.

## 7. What v3 still does not cover

- **Customer acquisition cost.** No paid acquisition is modelled; burn is operational
  only. Any paid acquisition changes the arithmetic completely.
- **The $500/month burn is inherited from v2 and unaudited.** Google Places, Supabase,
  Apple and Play fees have all changed since May 2026.
- **Most growth inputs are judgment, not measurement.** Only M1 traffic (110 visits) and M1
  signups (15) are measured. Traffic growth 15%/mo, signup growth 12%/mo, web→signup 2%,
  free-user retention 85% and the 1.6x gate lift are all marked "YOUR CALL" in the workbook.
  The gate lift is the least-supported figure in the model — its source only bounds it above.
- **The demand anchor mixes currencies and categories.** The 2.6% reference conversion is
  RevenueCat's global, USD-denominated Business-category median applied at a CAD price
  ($4.99 CAD ≈ $3.60 USD), which makes it conservative but not clean. Retention comes from
  RevenueCat's Utilities category instead. Neither report breaks out Finance at all.
- **Funnel rates from click to application are unvalidated.** Engaged-per-visit,
  click-to-affiliate and application-start are carried from v2. **No published
  Canadian credit-card comparison funnel benchmark exists** — this was searched for
  specifically and is a real gap, not an omission. Instrumenting the live site is the
  cheapest way to replace them.
- **Elasticity is swept, not known.** No CardCoach price test has been run.
- **Clawback windows.** No Canadian card affiliate program publishes a validation or
  reversal period. Fintel's contracts say commissions are paid by the 10th business
  day of the following month and may be held for "a reasonable period of time."
- **Android is assumed to price identically** and is not modelled separately.
- **Lifetime SKU** is modelled in Python only; the workbook's T8 row is T3 without it.
- **The workbook's Sensitivity sheet is a static readout**, not live formulas. It does not
  follow the Tier Scenarios dropdown — re-run `final_numbers.py` after changing an input.

---

## Open items

1. **Affiliate network applications** — Fintel Connect and CJ. Pre-flight is closed.
2. **Milesopedia Network application** — the coverage lever.
3. **Apple account structure** — blocks every dollar of subscription revenue.
4. **Apple Small Business Program enrolment** — free, worth 4.5%.
5. **Instrument the web funnel** — replaces four unvalidated inputs with measurement.
6. **Audit the $500/month burn.**
7. **Run a price test once there is traffic to test on** — the highest-ROI experiment
   available, and the thing that would retire the elasticity sweep.

---

*To change assumptions, edit `01_CORE/data/CardCoach_Revenue_Model_v3.xlsx` — every
blue cell is an input and the Tier Scenarios dropdown at `Inputs!C42` reprices the Web Path,
Subscriptions and Monthly Model sheets (the Sensitivity sheet is a static readout). The Python model in `01_CORE/data/model_v3/` is the reference implementation;
the two agree on all **nine** scenarios they share; T8's lifetime SKU is Python-only, and the
workbook's P8/P9 rows have no `tiers.py` counterpart. Log material strategy shifts in
`PIPELINE_AND_DECISIONS.md` and update this file.*

---

## Tie-ordering independence note (recorded 2026-08-16, per API-016 spec downstream item)

When two or more cards tie on value (API-016 rounded-net tie groups), the order
among them is: annual fee ascending (NULL last), then display name, then card
product id — decision D2, Mike, 2026-08-16. **This rule contains no affiliate,
commission, or partner input, and none may be added to it.** Order among
equal-value cards is exactly where commission bias would be invisible to users;
this note exists so the rule predates the surface. Any future proposal to alter
within-tie ordering must be evaluated against this section and recorded here.
