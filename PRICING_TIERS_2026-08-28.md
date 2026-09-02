# CardCoach pricing — the structures, weighed

**Date:** 2026-08-28 · **Owner:** Mike · **Lane:** revenue
**Companion to:** `REVENUE.md` (rewritten same day), `CardCoach_Revenue_Model_v3.xlsx`
**Reproduce with:** `01_CORE/data/model_v3/final_numbers.py` — it computes against the recommended
configuration and prints every figure in §4, §5, §5A and §6. The ten-structure grid in §3 comes
from `tiers.py`; the Free/Pro grid in §5A from `free_vs_pro.py`.
**Supersedes:** nothing. This is the first pricing analysis the project has had; Phase 4 v2
priced a single tier and never tested an alternative.

---

## The finding, before the method

**Price is a second-order lever and traffic is the business.** One variable — web traffic
growth — moves 24-month revenue by **+235%**. The entire spread from the worst tier structure
to the best is **22.1%**.

That is not an argument for ignoring price. Within 24 months, revenue and conversion barely
trade off against each other, so price can be chosen to build the largest defensible
subscriber base rather than to squeeze near-term revenue — and a subscriber is also an
affiliate-earning, word-of-mouth-carrying asset.

Nor is the base case an assumption of no growth: it compounds traffic at 15%/month and signups
at 12%/month. Every scenario below is quoted at that rate. **The ordering was re-checked at
25%/month and holds**, so the pricing conclusion does not depend on the growth case — which is
exactly why price can be decided now, independently of the traffic question.

**The recommendation is Free + Pro — the structure that already exists — with Pro at $7.99/mo
($59.99/yr) and the two shipped gates turned on.**

> **REVISED 2026-08-28 (Mike): "why aren't we looking at free and pro tiers?"** The first version
> of this document recommended a three-tier ladder with an invented "Plus" tier. That was wrong on
> the facts and weak on the numbers. `public.billing_tiers` holds **exactly one row — `pro`**;
> Free is the absence of it. A second tier would need its own tier row and
> `provider_entitlement_id`, a second RevenueCat entitlement and offering, two more store SKUs,
> and paywall rework to render two tiers — on a product that has never taken a dollar. And the
> ladder is worth **+5.0% / +8.8% / +14.2%** against the recommendation — reliably positive, so
> the case for shipping Free + Pro first is a **sequencing** case, not a revenue one. §5A models
> the decision that actually exists and prices the ladder honestly.
>
> The same review corrected a factual error carried throughout: there are **six** entitlements,
> not five — `ambient_widget`, `auto_location`, `online_merchant`, `receipt_scanner`,
> **`statement_import`**, `unlimited_cards`. Five are visible; `online_merchant` is
> `is_active = false` until APP-022 ships.

---

## 1. What is actually true right now

Measured 2026-08-28 against production and Cloudflare.

| | |
|---|---|
| Canadian visits to cardcoach.ca | **3, 3 and 5** on Aug 25 / 26 / 27 — about **110/month** |
| Everything else hitting the site | WordPress vulnerability scanners. Top request origins are NL, US, FR — **Canada is 4th at ~7%** |
| App signups | **15** in Aug 2026 (82 lifetime, **19** signed in within 30 days) |
| Users holding cards | **32**, holding **86** cards between them |
| Entitlement grants | **50** — every one a comped tester |
| `billing_events` | **0**. Nothing has ever been sold, at any price |
| Affiliate links | Live since 2026-08-11, all 126 `network:"direct", sponsored:false` — **earning nothing** |
| Catalogue | **149** card products across **16** issuers |

Two deserve emphasis. Nothing has ever been sold, so no price is yet "wrong" about the world —
this is a genuinely open decision. And the traffic figure is Cloudflare's own `visits` metric
filtered to Canada, over three consecutive weekdays. It is a small window, and it is the only
direct observation of demand this project has.

---

## 2. The demand model, and what it cannot know

**There is no CardCoach price test.** Any single elasticity would be an invention, and the
published evidence actively conflicts:

- RevenueCat's 2026 report finds higher-priced apps convert **better** — 8.9% vs 4.4%
  download-to-trial. Observational, not a price test: better apps in better niches charge more.
- Adapty finds monthly conversion drops **~53%** from the low to the mid price band, implying
  an elasticity near **1.1**.

So the grid runs at **e = 0.4, 0.8 and 1.3**, and a recommendation only counts if it survives
all three. Conversion is anchored at **2.6% signup-to-paid at $4.99** — RevenueCat's
Business-category download-to-paid median.

### Three honest weaknesses in that anchor

1. **It is a global, USD-denominated median applied at a CAD price.** $4.99 CAD is roughly
   $3.60 USD, well below the price at which the 2.6% median was observed. The anchor is
   therefore **conservative** — a below-median price should convert above the median — but the
   mismatch is real and unquantified.
2. **Two different RevenueCat categories are spliced into one funnel.** Conversion uses
   Business (the closest monetisation analogue); retention uses Utilities (the closest
   functional analogue). Neither report breaks out Finance at all.
3. **Only the first month of traffic is measured.** The 15%/month growth that accounts for 87% of cumulative
   24-month traffic is judgment, and is labelled as such in the workbook's own source column.
   The same is true of signup growth, web→signup, free-user retention and the gate lift.

### Two scenario adjustments

- **Gate lift, 1.6x** — turning on `card_slot_limit` and `auto_location_gate`. Bounded above by
  RevenueCat's hard-vs-soft paywall gap of 5.1x (10.7% vs 2.1%); a feature gate is much weaker
  than a hard paywall, so 1.6x is deliberately cautious. **This is a judgment call, not a
  sourced figure** — the source only bounds it.
- **Hard paywall, 2.6x** — half that same published gap — with the free base collapsing to 10%.
  The gate lift is **not** applied on top: a hard paywall has no free tier for those gates to
  gate. An earlier version of this model stacked both, which is what made the hard paywall
  appear to win. See §4.

### The card cap is the one lever with a measured trigger

From `public.user_cards`, the 32 users who hold cards:

| Free cap | At or over it | Reading |
|---|---|---|
| 2 cards | **71.9%** | Aggressive. Most users hit a wall almost immediately. |
| **3 cards** | **53.1%** | **The shipped design.** Nine users sit exactly at 3 — one card from the wall. |
| 4 cards | 25.0% | Comfortable, and a quarter still convert. |
| 5 cards | 12.5% | Effectively no cap. |

The 3-card cap already in `free_card_slot_limit()` is well chosen. Nothing here argues for
changing it.

---

## 3. The ten structures

All built only from entitlements already in `public.entitlement_catalog` — **six** of them:
`unlimited_cards`, `auto_location`, `ambient_widget`, `receipt_scanner`, `statement_import` and
`online_merchant` (that last one `is_active = false` until APP-022). No feature is invented.

24-month revenue, CAD, at the measured M1 traffic baseline growing 15%/month:

| | Structure | conv @e=0.8 | subs M24 | e=0.4 | **e=0.8** | e=1.3 |
|---|---|---|---|---|---|---|
| **R** | **Plus $3.99 / Pro $9.99** | 4.98% | 62 | 6,097 | 6,004 | 5,969 |
| T6 | Plus $4.99 / Pro $11.99 | 4.16% | 51 | 6,328 | **6,073** | 5,857 |
| T7 | Annual only $59.99 | 3.12% | 59 | 5,981 | 5,980 | **5,978** |
| T8 | $7.99 + lifetime $179.99 | 2.85% | 35 | **6,336** | 5,960 | 5,581 |
| T4 | $9.99 single | 2.39% | 30 | 6,102 | 5,628 | 5,195 |
| T9 | Hard paywall $6.99 | 5.16% | 64 | 5,876 | 5,553 | 5,205 |
| T3 | $7.99 single | 2.85% | 35 | 5,814 | 5,529 | 5,239 |
| T2 | $4.99 single, gates ON | 4.16% | 51 | 5,465 | 5,465 | 5,465 |
| T0 | $3.99 single (v2's price) | 3.11% | 38 | 4,908 | 4,979 | 5,078 |
| T1 | $4.99, gates OFF — today | 2.60% | 32 | 4,972 | 4,972 | 4,972 |

Bold in the elasticity columns marks the revenue leader at that elasticity: **T8 at 0.4, T6 at
0.8, T7 at 1.3 — a different structure every time.** That instability is the reason the
recommendation is chosen on the frontier rather than from a single column. The recommended
ladder (R) leads none of them, and that is the point.

**The configuration shipping today ranks last or next-to-last at every elasticity.**

### The efficient frontier — the actual "best blend" answer

A structure is on the frontier if nothing else beats it on **both** revenue and conversion.

| Elasticity | On the frontier |
|---|---|
| e = 0.4 | T8, T6, **R**, T9 |
| e = 0.8 | T6, **R**, T9 |
| e = 1.3 | T7, **R** |

**R is the only structure in all three sets** — which is why the ladder is worth returning to
later. Its revenue gap to the leader is 3.8% / 1.1% / 0.2%, and it ranks 2nd, 2nd and 1st on
conversion. Every alternative wins at one elasticity and falls off at another.

Two caveats on this frontier. It ranks structures **on revenue and conversion only**, pricing
nothing that any of them costs to build — which is what §5A adds and what decides the sequencing.
And the recommended Free + Pro is **T3** on this grid, appearing on no frontier list precisely
because the frontier cannot see build cost.

### Three things that fall out

**Ladders beat single prices on the blend — but only at high elasticity, and only if you build
one.** R converts at 4.98% against 2.39% for a $9.99 single tier while earning 6.7% more at
e = 0.8. At e = 0.4 a well-set Free/Pro beats it outright. §5A prices that trade against what a
second tier actually costs to build.

**Turning the gates on is the cheapest move available.** T2 versus T1 is the same SKU at the
same price with two boolean flags flipped: **+60% conversion, +$493 over 24 months, zero
engineering.** The flags exist, the trigger is measured, and the migration exposure is small —
most of the 82 accounts are test accounts.

**The revenue surface is flattish, but how flat depends on the elasticity.** Sweeping a single
tier from $3.99 to $13.99:

| Elasticity | Revenue spread | Conversion spread |
|---|---|---|
| e = 0.4 | 22.6% | 1.7x |
| e = 0.8 | **5.5%** | 2.7x |
| e = 1.3 | 9.4% | 5.1x |

Conversion always moves more than revenue does, at every elasticity. The reason is structural:
across all ten structures and all three elasticities, **58–85% of revenue is affiliate, not
subscription**, so price only ever moves a minority stream. But the "price barely matters"
reading is strongest at e = 0.8 and weakest at e = 0.4 — it should not be quoted flatly.

---

## 4. The hard paywall: a bug, then a decision that stands on its own terms

An earlier run had T9 topping the table at every elasticity. Part of that was a defect:
`tiers.py` applied the 2.6x hard-paywall conversion multiplier **and** the 1.6x gate lift to the
same scenario — 4.16x combined — when a hard paywall has no free tier for `card_slot_limit` or
`auto_location_gate` to gate.

Correcting it narrowed T9's margin but did not remove it. Compared like for like — both sides
without the free-retention penalty, since `tiers.score()` does not apply it:

| Elasticity | recommended Free + Pro | T9 hard paywall | T9 gains |
|---|---|---|---|
| 0.4 | $5,813 | $5,876 | +1.1% |
| 0.8 | $5,527 | $5,553 | +0.5% |
| 1.3 | $5,238 | $5,205 | **−0.6%** |

**T9's edge is 1% or less, and it loses outright at e = 1.3.** Applying the penalty to both sides
would push it further down, because a hard paywall sheds its entire free base rather than the
slice a 3-card cap costs.

An earlier draft said the corrected number "no longer requires that argument to carry it."
**That is withdrawn** — as is an intermediate claim that T9 beat the recommendation at every
elasticity, which mixed two bases. On margins this thin the rejection rests on the qualitative
case, and that case has to be stated as such:

- **The model measures conversion of installs. It cannot see that a paywalled utility attracts
  fewer installs in the first place** — the listing converts worse, reviews say "wants money
  immediately," and ranking suffers. On margins of 1–3%, a very small install penalty erases it.
- **It contradicts the rest of the product.** The web surface is free and commission-blind on
  purpose, and the tie-ordering rule in `REVENUE.md` exists specifically so commission bias can
  never enter the ranking. An app that demands payment before showing a recommendation discards
  the trust position those decisions were made to protect.
- **It strands 82 existing accounts and 50 comped testers.**
- **Every comparable keeps a real free tier** — CardPointers, Kudos, MaxRewards.

A 1–3% modelled edge is not worth any of that. But it is a judgment, not a number, and it should
be revisited if the install penalty ever gets measured.

---

## 5A. Free vs Pro — the decision that actually exists

Only **two** of the six entitlements are clawbacks from today's free app: `unlimited_cards` and
`auto_location`. The other four are new features — gating them takes nothing from anyone. So the
Free/Pro line is set by exactly two questions: **how many cards does Free hold, and is automatic
location free?**

The first version of this document collapsed both into a single 1.6x "gates on" multiplier, which
cannot answer where the line should sit. Decomposed:

> lift = 1 + cap_pressure(cap) × 0.60 + (auto-location gated ? 0.28 : 0)

`cap_pressure` is **measured** — the share of the 32 card-holding users at or over each cap. The
two coefficients are judgment, calibrated so the shipped design reproduces the same 1.6x used
elsewhere. A harsher cap also costs free-user retention (they leave rather than pay), and the free
base earns affiliate revenue, so that penalty is modelled too.

**24-month revenue at e = 0.8, Free shape × Pro price:**

| Free tier | lift | $4.99 | $5.99 | $6.99 | **$7.99** | $8.99 | $9.99 | $11.99 |
|---|---|---|---|---|---|---|---|---|
| everything free — **today** | 1.00 | **4,972** | 4,998 | 5,020 | 5,040 | 5,058 | 5,075 | 5,106 |
| auto-location Pro only | 1.28 | 5,204 | 5,235 | 5,263 | 5,289 | 5,313 | 5,335 | 5,374 |
| 5-card cap only | 1.07 | 5,012 | 5,038 | 5,062 | 5,084 | 5,104 | 5,122 | 5,155 |
| 5-card cap + auto-location | 1.35 | 5,243 | 5,276 | 5,306 | 5,333 | 5,358 | 5,381 | 5,423 |
| 4-card cap + auto-location | 1.43 | 5,283 | 5,318 | 5,350 | 5,378 | 5,405 | 5,429 | 5,473 |
| **3-card cap + auto-location** | **1.60** | 5,378 | 5,417 | 5,452 | **5,484** | 5,513 | 5,540 | 5,590 |
| 3-card cap only | 1.32 | 5,147 | 5,179 | 5,208 | 5,234 | 5,258 | 5,281 | 5,321 |
| 2-card cap + auto-location | 1.71 | 5,444 | 5,485 | 5,522 | 5,557 | 5,588 | 5,617 | 5,670 |

> The grid above prices annual at a flat 33% off; the recommendation uses **$59.99** (37% off),
> a real store price point, which lands the recommended cell at **$5,438**. Note also that this
> grid applies a free-user retention penalty the ten-structure table in §3 does not — like for
> like it reads **1.64% lower** ($5,438 against $5,527), and the gap scales with how hard the cap
> bites (2.12% at a 2-card cap, 0.00% with no cap). That is the point of having it: it is what
> stops a harsh cap looking free. No ordering changes. Every uplift below uses the store prices.

**The Free/Pro shape is worth more than the price is.** Moving from everything-free to a 3-card
cap plus gated auto-location is worth **+8.1%** at a fixed $4.99. Moving from $4.99 to $11.99 at
a fixed free shape is worth **+2.7%**. Where the line sits beats what you charge, and the line
costs nothing to move — both flags already exist.

### Why 3 cards, not 2

The 2-card cap earns more at every retention penalty tested — but the margin over 3 narrows from
1.75% to 0.75% as the penalty rises, and it is the wrong call for two reasons the model cannot see:

| Cap | Users already over it | Sitting exactly on it |
|---|---|---|
| 2 cards | **17 of 32** | 6 |
| **3 cards** | **8 of 32** | 9 |
| 4 cards | 4 of 32 | 4 |
| 5 cards | 1 of 32 | 3 |

A 2-card cap strands more than half the existing base and would need grandfathering for 17
accounts. More fundamentally, an app whose entire pitch is *which of your cards should you use*
barely functions at two. The 3-card limit already written into `free_card_slot_limit()` is well
chosen: half the card-adding population is at or over it, and the largest single cohort sits
exactly on the line, one card from the wall.

### Why $7.99

An earlier draft justified $7.99 as having the "best worst-case rank" across the elasticity
sweep. **That criterion is an artifact and is withdrawn.** Revenue is monotone *increasing* in
price at e = 0.4 and 0.8 and monotone *decreasing* at e = 1.3, so with reversed orderings the
**median of whatever price grid you write down always minimises the worst rank**. Re-running the
test on other grids moves the "winner" to the new median every time:

| Price grid tested | "winner" | its median |
|---|---|---|
| $4.99 … $11.99 (seven prices) | $7.99 | $7.99 |
| $4.99 … $8.99 (five prices) | $6.99 | $6.99 |
| $5.99 … $13.99 (five prices) | $9.99 | $9.99 |

What survives is the finding underneath it: **the revenue-maximal price swings from $4.99 at
e = 1.3 to $11.99 at e = 0.4, so no price is optimal without knowing an elasticity nobody has
measured.** The whole range is worth **4.4%** on the mean.

| Pro price | e = 0.4 | e = 0.8 | e = 1.3 | mean | conv @ 0.8 |
|---|---|---|---|---|---|
| $4.99 | 5,336 | 5,336 | 5,336 | 5,336 | 4.16% |
| $5.99 | 5,473 | 5,373 | 5,258 | 5,368 | 3.59% |
| $6.99 | 5,601 | 5,407 | 5,198 | 5,402 | 3.17% |
| **$7.99** | **5,723** | **5,437** | **5,148** | **5,436** | **2.85%** |
| $8.99 | 5,840 | 5,466 | 5,107 | 5,471 | 2.60% |
| $9.99 | 5,951 | 5,492 | 5,071 | 5,505 | 2.39% |
| $11.99 | 6,162 | 5,539 | 5,014 | 5,572 | 2.06% |

**$7.99 is therefore a judgment, not an optimum**: a mid-market point that sits below every
comparable (CardPointers $9.99, Kudos $14.99, the Adapty Utilities median $12.99), leaves room to
raise — the easy direction to move — and does not bet the launch on an elasticity nobody has
tested. Higher prices earn more on the mean and less if the market turns out price-sensitive.
**Run a price test as soon as there is traffic to test on; it is the only thing that settles it.**

### What the ladder actually buys — corrected

The first version of this section compared the ladder against the **best** Free/Pro cell — which
is the 2-card cap at $11.99, a configuration this same section rejects. That was not a fair test.
Against the **recommendation**, on the same basis and the same free-tier shape:

| Elasticity | recommended Free + Pro | Plus/Pro ladder | ladder gains |
|---|---|---|---|
| 0.4 | $5,724 | $6,008 | **+5.0%** |
| 0.8 | $5,438 | $5,916 | **+8.8%** |
| 1.3 | $5,149 | $5,880 | **+14.2%** |

**The ladder is reliably positive at every elasticity, and worth more the more price-sensitive
the market turns out to be.** The earlier claim that it was "not reliably positive" was an
artifact of the unfair comparison and is withdrawn.

So the case for shipping Free + Pro first is **a sequencing case, not a revenue case**:

- Nothing has ever been sold. The conversion rate that decides whether a ladder pays is
  **swept, not known** — a second tier built now is built against a guess.
- Free + Pro needs no new billing infrastructure. The ladder needs a second tier row and
  `provider_entitlement_id`, a second RevenueCat entitlement and offering, two more store SKUs,
  paywall rework to render and compare two tiers, and a second price to defend in two languages
  on two stores — all of it ahead of the first dollar.
- The Apple account decision already gates every subscription dollar. Adding scope to that
  critical path buys nothing.

Ship Free + Pro, sell something, measure the real conversion rate, **then** build the ladder
against data. On these numbers it is worth coming back for.

---

## 5. The recommendation

### Free — the acquisition surface

Up to **3 cards**, manual place selection, and the whole recommendation engine. Everything that
makes the product worth trusting stays free, on both the web and the app.

Two flags do it, both already built: `card_slot_limit` and `auto_location_gate`. Nothing else is
taken away, because nothing else was ever given — the widget, receipt scanning, statement
analysis and online shopping are all new features.

### CardCoach Pro — $7.99/mo, $59.99/yr

`unlimited_cards`, `auto_location`, `ambient_widget`, `receipt_scanner`, `statement_import`, and
`online_merchant` when APP-022 ships. That is the `pro` tier exactly as seeded today — no new
tier row, no second RevenueCat entitlement, no extra SKUs.

$59.99 annual is **37% off** monthly, inside the 25–44% band the comparables use. $7.99 sits
below CardPointers ($9.99), Kudos ($14.99) and the Adapty Utilities median ($12.99) — room to
raise later, which is the easy direction to move.

**Worth +9.4% over today's configuration**, and every part of it already exists in the database.

**$8.99 is the honest alternative** — it earns **0.63% more on the mean** ($5,471 against
$5,436), and less if the market turns out price-sensitive. If you would rather start higher and
discount later than start lower and raise, take $8.99. Neither is an optimum — see §5A on why
"best worst-case rank" was withdrawn as a criterion.

**The Plus/Pro ladder is a later move, not a launch move.** Revisit it once Pro has sold
something and there is conversion data to justify a second SKU — see §5A.

### Ship it with

- **Gates ON.** `card_slot_limit` and `auto_location_gate`, per BILL-001 §7c — after the store
  build that renders the upsell is in the field, exactly as the go-live runbook sequences it.
- **A 14-day trial, not 7.** RevenueCat's day-0 trial cancellation is 39.8% at 7 days against
  35.7% at 14, and trial-to-paid runs 25.5% for trials of ≤4 days versus 42.5% at 17–32 days.
  Trial length is a model input in v3: **+4.4% over the 7-day trial the runbook specifies**, for
  a dropdown change in App Store Connect. A 30-day trial models at +11.8% but delays cash and
  widens refund exposure; a 3-day trial costs 3.1%.
- **Apple Small Business Program enrolment.** 15% instead of 30%. New developers qualify
  automatically. Worth 4.5% of 24-month revenue and it is free.
- **No lifetime SKU yet.** T8 front-loads cash and leads at e = 0.4, but a lifetime buyer at 3x
  annual is revenue-negative past roughly year three. Revisit when there is retention data to
  price it against. (T8 is modelled in Python only; the workbook's T8 row is T3 without the
  lifetime SKU.)

### What would change this

- **A real price test.** Adapty puts price experiments at **+45.5% LTV / +28.3% conversion**
  uplift on average — the second-highest ROI of any paywall experiment. Every number above is a
  substitute for that test, not a replacement.
- **Elasticity landing outside 0.4–1.3.** Below 0.4 the ladder should widen toward T8/T6; above
  1.3 it should compress.
- **The gate lift proving weaker than 1.6x.** Watch conversion in the first 60 days after the
  flags flip. That is the cheapest validation available, and 1.6x is the least-supported number
  in this document.

---

## 6. What this document is not

None of these structures makes the business profitable inside 24 months. Every scenario nets
between **−$5,664 and −$7,092** against $12,000 of operational burn. Cumulative break-even
needs **21.9%/month traffic growth — 10,394 visits/month by M24, 94x measured traffic today** —
or roughly **69 app signups/month** from M1 against 15 measured.

Pricing is worth getting right because it is nearly free to get right — and the Free/Pro line is
the freest part of it, since both flags are already built and switched off. It is not the growth
plan: the whole worst-to-best spread is 22.1%, against **+235%** for traffic growth alone. That
argument belongs in `REVENUE.md`, which is where the traffic case now lives.
