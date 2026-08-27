# CardCoach Revenue Model — Phase 4 v2

**The current revenue thesis: free web (affiliate) + paid iOS (subscription).** This
consolidates both Phase 4 PDFs — the full spreadsheet dump and its executive summary —
into one reference. It supersedes any earlier affiliate-only framing.

Built: May 2026 · Currency: CAD throughout · Horizon: 24-month projection (M1 = July 2026)
Last updated: 2026-08-16 (paid-tier correction; pointer + lanes corrections authored 2026-07-16, landed 2026-07-31)
Last consolidated: 2026-07-16

> **CORRECTION (Mike, 2026-08-16) — plan vs. shipped reality.** The thesis line above
> ("free web + paid iOS") describes the *modelled* architecture, not the app that shipped.
> **The iOS app is live and free.** No subscription, no purchase flow, no entitlement
> storage exists in the product today — `profiles` carries id/email/display_name/created_at
> and nothing else, and no IAP library is installed. Everything below the "three numbers"
> remains a projection from the Phase 4 v2 model; none of it has been realised as revenue.
> Read every subscription figure in this file as forecast, not run-rate.

> **Note on the old model.** Earlier project notes framed revenue as affiliate-only with a
> "$100k ARR / ~30 conversions a week" target. That framing is **stale** — this v2 model is
> the current one. The architecture changed: free web for trust/acquisition, paid iOS for
> committed users. If you see the old affiliate-only math referenced anywhere, this file is
> the authority.

> **Revenue model:** `01_CORE/data/CardCoach_Phase4_Revenue_Model_v2.xlsx` (materialized 2026-06-09;
> verified 2026-07-16 — 7 tabs, 866 formulas). Current summary output:
> `CardCoach_Phase4_Sensitivity_OnePager.md` (generated 2026-06-10). The two PDFs were
> renders of it. If you want to flex assumptions, use that `.xlsx`. This doc captures the
> numbers and logic, not the live model.

---

## The three numbers

| Metric | Value |
|--------|-------|
| 12-month revenue (M1–M12) | **$12,807 CAD** |
| 24-month revenue | **$113,441 CAD** |
| 24-month net (after $12,000 burn) | **+$101,441 CAD** |
| First monthly break-even | **Month 6 (Dec 2026)** |
| First cumulative break-even | **Month 9 (March 2027)** |
| Worst point | end of M5, cumulative deficit ~$1,344 |
| Top sensitivity | **Monthly subscription churn rate** |

Worst-case cumulative deficit (~$1,344) is well within self-funded tolerance — one month
tighter than the affiliate-only model, but recovered by M9.

---

## Architecture: why two surfaces

**Free web app** — discovery, trust, acquisition. Monetized by affiliate commissions.
**Paid iOS app** — committed users. Monetized by subscription + (higher-engagement) affiliate.

Three revenue streams stack:

| Stream | 24-mo total | Share | Notes |
|--------|-------------|-------|-------|
| Web affiliate | $60,918 | **53.7%** | Free web users → application clicks → commissions. Unchanged from the affiliate-only model. |
| iOS subscription | $45,848 | **40.4%** | $3.99/mo or $34.99/yr, net of App Store cut. The new stream. |
| iOS affiliate | $6,675 | 5.9% | Active subs × per-user affiliate, with engagement uplift. |

**The key strategic shift:** web affiliate share drops from 80% (affiliate-only model) to
54%. That rebalance — not the raw revenue bump — is the point. It makes the trajectory
robust to a slow SEO ramp, because revenue no longer rides almost entirely on web SEO.

**The iOS trade, made concrete (M24):**
- Free model would be: ~8,000 MAU × $0.20 affiliate/user = ~$1,600/mo.
- Paid model is: ~2,100 active subs × ($0.43 affiliate + $2.94 subscription)/user ≈ $7,050/mo.
- Paid filtering cuts the user count ~75%, but subscription revenue + per-user engagement uplift make the iOS surface generate ~4× more revenue at M24.

---

## Pricing (Mike, 2026-05)

- **Monthly:** $3.99 CAD
- **Annual:** $34.99 CAD (~$2.92/mo equivalent — a 27% discount)
- **App Store cut:** modeled at **15%** (Apple Small Business Program), not the 30% standard. SBP is opt-in but free; CardCoach qualifies under $1M annual revenue. **Confirm enrollment before launch — leaving 15% on the table is real money.**

---

## Subscription dynamics

| | M3 | M6 | M12 | M18 | M24 |
|---|----|----|-----|-----|-----|
| New subs / month | 12 | 28 | 93 | 210 | 352 |
| Total active subs | 25 | 81 | 366 | 1,018 | 2,094 |
| Net sub revenue / mo | $74 | $243 | $1,087 | $3,011 | $6,153 |

- **Annual subs become the majority of the active base over time** — lower churn means they stick. New sales stay ~60% monthly, but by M24 the active base is roughly 50/50.
- **Direct App Store discovery dominates new subs for the first ~9 months** (web traffic takes time to ramp). By M24, web contributes ~half of new subs. Direct ASO curve: 5/mo at launch → 75 by M12 → 275 by M24.
- ~2,100 active subs at M24 is a sustainable scale for a Canadian financial utility app in its first two years.

---

## Funnels

**Web (free) — affiliate.** End-to-end ~0.45% of visits produce an approved application.
- Engaged sessions / visit: 50%
- Click-to-affiliate / engaged session: 6%
- Application start / click: 45% · complete / start: 55% · approval / completion: 60%

**iOS subscription path — three input channels:**
- Web visit → engaged → "Get the app" CTA → App Store → trial → paid (compressed to 0.3% of web visits)
- Direct App Store discovery → trial → paid (the ASO curve above)

**iOS affiliate path — applied to active subscribers:**
- Sessions per active sub/mo: 14
- Insights view rate: 15% · Gap view rate: 30% · click-to-affiliate: 10%
- App start: 35% · complete: 50% · approval: 60%
- Net: ~0.66% of active subs produce an approved application per month, vs ~0.30% for the free-model assumption — roughly **2× per-user revenue** ("paid users engage more," made concrete).

**Average commission per approved application:** $65 CAD (mid-point; Fintel Connect range
is $40–90 — confirm during onboarding).

---

## Hard constraints baked into the model

- **Commission-blind ranking** — flat conversion rates across cards. (Matches the data-layer enforcement in the engine.)
- **No ads.**
- **Canada-only, CAD throughout.**
- **V1 inventory of 95+ cards.**
- **Welcome bonus pipeline NOT shipped** — no application uplift from welcome offers modeled. (When it ships, both web and iOS affiliate lift materially. Tracked in `WORKING_NOTES.md` #5.)

---

## Sensitivity — what moves the model (in order of leverage)

1. **Monthly sub churn rate** (base 12%). Drop to 8% and the active base nearly doubles by M24 — it *compounds*, not scales linearly. Now the single most-leveraged variable, displacing the old SEO-ramp #1.
2. **Web visits at M24 / SEO ramp speed** (base 25,650/mo). Still huge — 54% of revenue is web affiliate, plus web is half of subs by M24. Slow SEO double-hits.
3. **Web → paid sub conversion** (base 0.3%). The bridge between surfaces. Trial mechanics, CTA placement, App Store listing copy all move it. Linear on subscription revenue.
4. **App Store cut** (15% vs 30%). Free upgrade via SBP. 30% cut → ~17.6% revenue loss.
5. **Annual sub mix share** (base 40%). 40% → 55% lifts total subscription revenue ~10%.
6. **Average commission per approved app** ($65). Linear on web AND iOS affiliate. Fintel range alone spans ±35%.
7. **iOS affiliate uplift multiplier** (held at 1.0× because the uplift is already baked into the funnel rates). Multiplicative on iOS affiliate if increased.

---

## Leading indicators to watch

- **Monthly sub churn at M2–M3.** Base 12%. Tracking 20%+ means the surface isn't proving value at the price point; under 8% means the model is conservative.
- **Trial-to-paid conversion in M1.** Expect ~30%; the first 100 trials test onboarding.
- **Web → "Get the app" CTA click rate.** If under 2% of engaged sessions click out, the subscription path is silted at the top.
- **Direct App Store discovery volume** vs the base curve (ASO working or not).
- **Annual/monthly mix on new sales.** Above 50% annual means the discount is working and unit economics improve.
- **Quebec share of subs.** French was set up as a distinct channel; parity-to-English conversion makes the 25% Quebec uplift assumption conservative.

---

## What this model does NOT cover

- **Welcome bonus impact** — pipeline not built.
- **Pro tier** — out of scope. Current pricing IS the iOS monetization. (Note: this is consistent with treating any "Pro tier" marketing as premature — see live-site compliance, `WORKING_NOTES.md` #13.)

  **REOPENED (Mike, 2026-08-16).** A paid tier is now in scope and is being built. Its first
  feature is the receipt scanner (specs `API-017_receipt_parse.md`, `APP-021_receipt_capture.md`,
  gated by `ENT-001_entitlements.md`), built complete and shipped inert behind a runtime flag
  and a per-user entitlement. Consequences to hold in mind:
  - **The model below does not include it.** No pricing, take-rate, conversion or churn
    assumption for a paid tier exists in `CardCoach_Phase4_Revenue_Model_v2.xlsx`. Any
    revenue attributed to it would be invented, which rule 7 forbids. The model needs a
    deliberate amendment before a paid-tier number is quoted anywhere.
  - **The app being free today changes the funnel this model assumes.** The 24-month
    projection prices iOS as paid from M1; it has been free instead. Treat the subscription
    line as unstarted rather than tracking-to-plan.
  - **`WORKING_NOTES.md` #13 should be revisited, not closed.** The live site marketing a
    deferred Pro tier becomes *less* premature once a tier is real — but "real" means
    purchasable, and there is no purchase flow yet. The compliance item stands until there is.
  - **Naming is deliberately open.** The build gates on a named entitlement key
    (`receipt_scanner`), never a "Pro" boolean, so tier name, price and contents can be
    decided without touching feature code.
- **Customer acquisition cost** — no paid acquisition modeled; burn is operational only. Any paid acquisition flips the math.
- **Refunds / chargebacks / App Store deflections** — apply a 5–10% haircut for a more cautious bottom line.
- **Android** — assumed same pricing/dynamics; not modeled separately (same 15% under Google Play's small-business program).
- **Marketing site revenue** — treated as an upstream referral feeder.
- **Cohort effects** — churn is smoothed monthly, not cohort-tracked. Fine for 24 months; for 36+ you'd want cohort decay tables.

---

## Open items to close (revenue-specific)

These are revenue-model open items. They overlap with — but are narrower than — the broader
blockers in `WORKING_NOTES.md`. The cross-cutting ones (legal review, Fintel application)
live there; these are specific to making the model real.

1. **Apple Small Business Program enrollment** before launch (free 15% rate). Confirm with Alex during App Store submission.
2. **Trial structure decision.** Default assumes 30% trial-to-paid via the 0.3% web→sub bridge. Generous trials may raise conversion but increase abuse cost. Alex's call at submission.
3. **Fintel Connect commission ranges** during onboarding — replaces the $65 mid-point.
4. **First 60 days of TestFlight retention** as a sanity check on the 12% monthly churn assumption. (TestFlight users aren't paid, but engagement patterns signal whether the product earns retention.)
5. **App Store listing copy** for the paid app — the "free web, premium mobile companion" narrative bridge needs to be in both the App Store description and the website CTA. App Store listing copy is Alex's lane entirely (settled 2026-06-10, reaffirmed 2026-07-16 — it sits in the app lane). Mikayla handles social media; her role is being defined, directed by Mike.

---

*The numbers here are a snapshot of the v2 model as of May 2026. To change assumptions, use
`CardCoach_Phase4_Revenue_Model_v2.xlsx` in `01_CORE/data/`. If revenue
strategy shifts materially, log the decision in `PIPELINE_AND_DECISIONS.md` and update this
file.*

---

## Tie-ordering independence note (recorded 2026-08-16, per API-016 spec downstream item)

When two or more cards tie on value (API-016 rounded-net tie groups), the order
among them is: annual fee ascending (NULL last), then display name, then card
product id — decision D2, Mike, 2026-08-16. **This rule contains no affiliate,
commission, or partner input, and none may be added to it.** Order among
equal-value cards is exactly where commission bias would be invisible to users;
this note exists so the rule predates the surface. Any future proposal to alter
within-tie ordering must be evaluated against this section and recorded here.
