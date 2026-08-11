# How CardCoach's Recommendation Engine Works

Last updated: 2026-07-16 · Owner: Mike

This document explains in plain English how CardCoach decides which credit card you should use for any purchase.

---

## The Big Picture

When you're about to buy something, CardCoach answers one simple question:

> **"Of all the cards in my wallet, which one gives me the most value for THIS specific purchase?"**

The engine calculates the dollar value you'd earn from each card and ranks them from best to worst.

---

## What the Engine Considers

### 1. Base Earn Rate (Every Card Has One)

Every credit card has a "floor" earn rate that applies to all purchases. This is typically 1-2% cashback (or equivalent in points).

**Example:** The RBC Avion gives you 1 point per dollar on everything. At a baseline valuation of 1 cent per point, that's 1% back on every purchase.

**Where it comes from:** The `earn_rates` table, where `basis = 'base'`

---

### 2. Category Bonuses (The Main Driver of Recommendations)

Most cards offer *bonus* earn rates in specific categories like groceries, gas, dining, or travel. This is where the real value differences appear.

**Example:**
- Card A: 1% base + 2% grocery bonus = **3% on groceries**
- Card B: 1.5% base, no grocery bonus = **1.5% on groceries**
- **Winner:** Card A earns almost double for grocery purchases

**Where it comes from:** The `earn_rates` table, where `basis = 'category'` and linked to a `category_id`

**Categories we track:**
- Groceries
- Dining/Restaurants
- Gas/Fuel
- Travel (flights, hotels)
- Transit
- Pharmacies
- Streaming services
- And more...

---

### 3. Spending Caps (The Hidden Catch)

Here's something most people miss: **many bonus earn rates have limits**.

A card might advertise "3% on groceries" but the fine print says "up to $1,000 per month." After you hit $1,000 in grocery spending, you drop back to the base rate (usually 1%).

**How we handle this:**

The engine tracks how much you've spent in each category this month. When calculating your earn rate, it considers:
- How much of the cap you've already used
- How much of your current purchase fits within the remaining cap
- The blended rate if your purchase spans the cap boundary

**Example:**
- Card has 3% on groceries up to $500/month
- You've already spent $400 in groceries this month
- You're buying $200 in groceries now
  - First $100 earns 3% (still within cap) = $3.00
  - Next $100 earns 1% (over cap) = $1.00
  - **Actual value: $4.00 (2% effective, not 3%)**

**Where cap data comes from:**

Caps are stored in two places:

1. **Inline caps on `earn_rates`** — simple monthly/annual dollar limits via `cap_monthly_cad` and `cap_annual_cad` columns. Good for straightforward "up to $X/month" rules.

2. **`card_caps` table** — richer cap modeling for complex cases:
   - `cap_basis`: what the cap measures (`spend_cad`, `rewards_points`, `transactions`)
   - `cap_unit`: unit of the cap value (`CAD`, `points`, `transactions`, `percent`)
   - `cap_period`: when it resets (`billing_cycle`, `calendar_month`, `calendar_year`)
   - `cap_value`: the actual limit

**Pooled caps:** Some cards share a single cap across multiple categories. For example, a card might offer 3% on both groceries and gas, but with a combined $500/month cap across both. The engine handles this via `capPoolId` — earn rates that share a pool ID have their spending aggregated together when checking the cap.

- Your spending history: `user_spend_snapshots` table

---

### 4. Points vs. Cash

Some cards earn points instead of cashback. The engine converts points to a dollar value so it can compare apples to apples.

**How point values are determined:**

Each point program carries up to three active `cents_per_point` valuations — one per valuation
tier (`conservative`, `realistic`, `aggressive`), added in migration `0038_valuation_tiers`. The
tier a user is scored at comes from `user_preferences.valuation_tier`, defaulting to `realistic`.
Valuations are time-windowed (`valid_from` / `valid_to`) so we can update them as programs change
without losing historical data.

Values are issuer-sourced (Tier 1 / Tier 1b) wherever an issuer publishes a rate. For dynamic award
travel — Aeroplan, Avios, Bonvoy — no issuer publishes a cents-per-point value at all, so those
programs use **Tier 2: triangulated industry consensus**, which requires three or more independent
sources agreeing, the stored value inside the observed range, and `confidence` capped at
`medium-high`. Tier 2 applies to `point_valuations` only and never displaces an available issuer
value. If a tier row is absent, the engine falls back to `realistic` and emits a warning naming the
program. The spread rule per program type and the full Tier 2 conditions are in
`proposals/PROPOSAL_point_valuation_governance.md`.

**Example:**
- Scene+ points valued at 1.0¢ per point (issuer-stated, fixed, identical across all three tiers)
- A card earning 2 points/dollar = 2¢ per dollar = 2% effective return

**Where it comes from:** The `point_valuations` table (up to three active rows per program, one
per tier, filtered via the `v_active_point_valuations` view)

---

### 5. Promotional Offers

Cards sometimes have limited-time bonus offers. Offer stacking (`solveOfferStack`) is live in the V2 production path behind `runtime_flags.loyalty_offer_stacking` (flag ON since 2026-08-02; wiring verified 2026-08-11 in the deployed recommend-card-v2 / recommend-here-v2 bundles — the public stateless web tool alone excludes offers by design; evidence: WORKLIST_REPORT_2026-08-11.md §I2).

**Types of offers:**
- **Stackable:** Can combine with other stackable offers (all bonuses add up)
- **Non-stackable:** Can't combine; offer stacking (`solveOfferStack`) is live in the V2 production path behind `runtime_flags.loyalty_offer_stacking` (flag ON since 2026-08-02; wiring verified 2026-08-11 in the deployed recommend-card-v2 / recommend-here-v2 bundles — the public stateless web tool alone excludes offers by design; evidence: WORKLIST_REPORT_2026-08-11.md §I2)

**How stacking works:**
1. Add up all stackable bonuses
2. Find the single best non-stackable offer
3. Compare: (base + all stackable) vs. (base + best non-stackable)
4. Use whichever gives you more

**Where it comes from:**
- Offer details: `offers` and `offer_bonuses_v3` tables
- Which cards/merchants qualify: `offer_scope_*` tables

---

### 6. Card Exclusions

Some cards explicitly **cannot** earn bonus rates in certain categories, even if they technically have a matching earn rate. For example, a card might exclude grocery purchases at Walmart or Costco because those merchants are classified differently by the card issuer.

The engine checks the `card_exclusions` table before applying any category bonus. If a card has an exclusion for the purchase's category, its bonus rate is zeroed out and only the base rate applies.

**Where it comes from:** The `card_exclusions` table (linked by `card_id` and `category_id`)

---

### 7. Conditional Earn Rates

Some earn rates only apply under specific conditions:

- **`portal_only`** — You must make the purchase through the issuer's online shopping portal
- **`preauthorized_only`** — Only applies to recurring/preauthorized payments
- **`merchant_list_only`** — Only applies at specific merchants (checked via the `earn_rate_eligible_merchants` join table)

The engine records these conditions on the earn rate via the `condition_type` field. Rates with conditions are noted in the explanation so users understand any requirements.

**Where it comes from:** The `condition_type` column on `earn_rates`, with eligible merchants in `earn_rate_eligible_merchants`

---

## The Calculation Order

Here's exactly what happens when you ask "which card should I use?":

```
1. Look up your wallet (which cards you have)
         ↓
2. Identify the merchant and its category (e.g., Loblaws → Groceries)
         ↓
3. For EACH card in your wallet:
   a) Check for card exclusions — if this card is excluded from this
      category, skip the category bonus entirely
   b) Get the base earn rate
   c) Check if there's a category bonus for this purchase type
   d) If the card earns points, convert to dollar value
   e) Check your spending this month against any caps
   f) Offer stacking (`solveOfferStack`) is live in the V2 production path behind `runtime_flags.loyalty_offer_stacking` (flag ON since 2026-08-02; wiring verified 2026-08-11 in the deployed recommend-card-v2 / recommend-here-v2 bundles — the public stateless web tool alone excludes offers by design; evidence: WORKLIST_REPORT_2026-08-11.md §I2)
   g) Calculate the total value you'd earn
         ↓
4. Sort cards from highest value to lowest
         ↓
5. Return the ranking with explanations
```

**Note on channel:** The request includes a `channel` field (in-store, online, etc.) which is passed through for future use, but it does not currently affect scoring.

---

## Where the Data Lives

### Core Tables

| Table | What It Stores |
|-------|----------------|
| `card_products` | Master data for all credit cards (name, issuer, network, fees, tier) |
| `user_cards` | Which cards are in your wallet |
| `earn_rates` | All base and category earn rates for every card |
| `card_caps` | Spending caps with rich modeling (basis, unit, period) |
| `card_exclusions` | Categories where a card cannot earn bonus rates |
| `categories` | The list of spending categories (groceries, dining, etc.) |
| `merchant_entities` | Canonical merchant data |
| `merchant_entity_places` | Maps Google Place IDs to merchants |
| `earn_rate_eligible_merchants` | Which merchants qualify for `merchant_list_only` earn rates |

### Tracking & History

| Table | What It Stores |
|-------|----------------|
| `user_spend_snapshots` | Your spending per card, per category, per month |
| `transactions` | Your purchase history |

### Offers & Bonuses

| Table | What It Stores |
|-------|----------------|
| `offers` | Promotional offer details |
| `offer_bonuses_v3` | Typed bonus mechanics (multiplier, points, cashback) |
| `offer_scope_*` | Which cards/merchants/channels each offer applies to |

### Point Programs

| Table | What It Stores |
|-------|----------------|
| `reward_programs` | Reward program metadata (reward unit, currency) |
| `point_programs` | Point programs linked to reward programs |
| `point_valuations` | Cents-per-point conversion rates per program (time-windowed) |

### Key Views

| View | What It Provides |
|------|-----------------|
| `v_active_earn_rates` | Earn rates filtered to currently valid date window |
| `v_active_card_caps` | Card caps filtered to currently valid date window |
| `v_active_point_valuations` | Point valuations filtered to currently valid date window |

---

## How We Ensure Accuracy

### Automated Testing

The engine has comprehensive unit tests that verify calculations are correct:

**Earn Math Tests** (`earnMathV2.test.ts`)
- Basic category bonus: 1% base + 3% groceries = 2% bonus
- Monthly spend caps: Correctly reduces earn when cap exhausted
- Annual spend caps: Both monthly and annual limits tracked
- Pooled cap scenarios: Multiple categories share cap
- Points-based cards: Valuation applied correctly
- Multipliers: Applied correctly (1.5× multiplier tests)

**Cap Tests** (`caps.test.ts`)
- Cap computation and boundary behavior
- Inline caps vs. card_caps table caps
- Pool-scoped caps across categories

**Ranking Tests** (`engine.test.ts`)
- Card with 2% beats card with 1%
- Ties broken consistently (lexicographic ordering)
- Category filtering works (grocery bonus only applies to groceries)

**Offer Stacking Tests** (`stackingSolver.test.ts`)
- Stackable offers all combine correctly
- Non-stackable offers: best one selected
- Constraints enforced (mutual exclusivity rules)

### Deterministic Results

The engine is **pure**—same inputs always produce identical outputs. No randomness, no external calls during calculation. This means:
- Results are reproducible
- Bugs are easier to find and fix
- Testing is reliable

### Verification Scripts

We run automated verification scripts to ensure the full system works:

```bash
pnpm verify:recommend-card   # Tests the recommendation API
pnpm verify:recommend-auth   # Tests authenticated recommendations
```

### Spend Tracking Integrity

Your spending history is maintained by **database triggers**, not application code. When a transaction is recorded, the database automatically updates your spend snapshot. This prevents:
- Missed updates
- Double counting
- Race conditions

---

## The Flow: From Purchase to Recommendation

```
┌─────────────────────────────────────────────────────────────────┐
│                          YOUR PHONE                             │
│                                                                 │
│  1. You're at Loblaws checkout, about to spend $100             │
│                                                                 │
│  2. App sends to server:                                        │
│     • Merchant: Loblaws (place ID)                              │
│     • Amount: $100                                              │
│     • Channel: in-store                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         SERVER                                  │
│                                                                 │
│  3. Resolve Loblaws → Category: Groceries                       │
│                                                                 │
│  4. Load your wallet (3 cards)                                  │
│                                                                 │
│  5. For each card:                                              │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ TD Aeroplan Visa                                       │  │
│     │ • Base: 1 pt/$  (1¢ value)                             │  │
│     │ • Grocery bonus: +2 pts (3¢ total)                     │  │
│     │ • Cap: $1000/mo, spent $600 → $400 remaining           │  │
│     │ • $100 purchase fits in cap                            │  │
│     │ • VALUE: $3.00                                         │  │
│     └────────────────────────────────────────────────────────┘  │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ AMEX Cobalt                                            │  │
│     │ • Base: 1 pt/$  (1¢ value)                             │  │
│     │ • Grocery bonus: +4 pts (5¢ total)                     │  │
│     │ • Cap: $500/mo, spent $500 → AT CAP                    │  │
│     │ • Falls back to base rate                              │  │
│     │ • VALUE: $1.00                                         │  │
│     └────────────────────────────────────────────────────────┘  │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ Rogers World Elite                                     │  │
│     │ • Base: 1.5%                                           │  │
│     │ • No grocery bonus                                     │  │
│     │ • No cap                                               │  │
│     │ • VALUE: $1.50                                         │  │
│     └────────────────────────────────────────────────────────┘  │
│                                                                 │
│  6. Sort: TD ($3.00) > Rogers ($1.50) > AMEX ($1.00)            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          YOUR PHONE                             │
│                                                                 │
│  7. Shows: "Use your TD Aeroplan Visa"                          │
│     • Earning 3 Aeroplan points per dollar                      │
│     • Worth $3.00 on this $100 purchase                         │
│     • $400 of your $1000 monthly grocery cap remaining          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Design Principles

### 1. The Mobile App Never Computes Rankings

All calculation happens on the server. The app only:
- Identifies where you're shopping
- Sends the request
- Displays the result

This ensures consistency across all devices and prevents tampering.

### 2. Server-Side Engine is Pure

The ranking engine has no side effects—it only reads data and returns results. This makes it:
- Testable
- Predictable
- Fast

### 3. Canonical Facts in the Database

Card earn rates, point valuations, and merchant data are stored as "canonical facts" with validity dates. This means:
- Historical accuracy (rates were different last year)
- Future-proofing (we can load rate changes in advance)
- Audit trail (we know what rates applied when)

### 4. Spending Tracked Automatically

Database triggers maintain spend snapshots. You don't have to do anything—just record your purchases and the system keeps track.

---

## Engine Evolution: V1 → V2

**V1 is dead (final, 2026-07-16).** V2 is the only engine. There are not two engines
and nothing coexists; V1 appears below only as history. Any doc or copy claiming
V1/V2 coexistence or an operative V1 is an error — correct it on sight.

The engine has gone through two major versions:

- **V1** (`packages/engine/src/index.ts`) — The original scoring engine with `rankCardsForPurchase`. Was in use via the `recommend-card` edge function; no longer live.
- **V2** (`packages/engine/src/v2/earnMath.ts`) — Rewritten earn math with `computeEarnMathV2`. Uses the updated schema (single point valuations, card_caps, card_exclusions) and produces structured explanations via `buildStructuredExplanationV2`. Served by the `recommend-card-v2` edge function.

An offer stacking solver (`solveOfferStack`) has been implemented but is not yet wired into the v2 production path. Both versions coexisted during the transition — the v2 engine was the direction of travel.

---

## Summary

CardCoach's recommendation engine is a sophisticated but straightforward system:

1. **It knows your cards** and their earn rates (base + category bonuses)
2. **It tracks your spending** to account for monthly/annual caps
3. **It values points fairly** using conservative baseline estimates
4. Offer stacking (`solveOfferStack`) is live in the V2 production path behind `runtime_flags.loyalty_offer_stacking` (flag ON since 2026-08-02; wiring verified 2026-08-11 in the deployed recommend-card-v2 / recommend-here-v2 bundles — the public stateless web tool alone excludes offers by design; evidence: WORKLIST_REPORT_2026-08-11.md §I2)
5. **It ranks cards honestly** by actual dollar value earned
6. **It explains its reasoning** so you understand why one card beats another

The result: You always know which card to use, and exactly why.

---

## What is NOT live (governance guardrails — carried from the 2026-06-02 governance doc, 2026-07-16)

*Carried from the 2026-06-02 governance doc; welcome-bonus and MCC items updated 2026-07-16.*

- **Offer stacking** — `stack_rules` and `offer_incompatibilities` tables exist; **live behind `runtime_flags.loyalty_offer_stacking` since 2026-08-02** (wiring verified 2026-08-11; the stateless web tool is excluded by design).
- **Channel-aware scoring** — designed, not active.
- MCC-based routing — captured in data, not enforced at runtime (the payment vendor doesn't expose MCC codes; see the 2026-04-16 decision in PIPELINE_AND_DECISIONS.md).
- **Live/real-time point values** — `point_valuations` is a dated snapshot. Use "current" or "as of," never "live."
- **French source verification** — the i18n infrastructure exists, but FR-CA source rows are blank placeholders, not verified data.
- Welcome bonuses — NOT live. Separate offers + components tables decided 2026-07-02, schema approved 2026-07-03; build pending Alex's answers on the open items; `load_only` at launch.
