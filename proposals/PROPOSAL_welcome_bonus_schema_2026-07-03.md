# PROPOSAL — Welcome-Bonus Schema

**APPROVED 2026-07-03 (Mike)**
2026-07-03 · Author: Claude session · Status: approved design — DB-side work sits documented until picked up

The *decision* that welcome bonuses get a separate table + their own reverification flow is
already logged (PIPELINE_AND_DECISIONS, 2026-07-02). This document is the design. DB-side
work sits documented here until picked up — nothing in this proposal touches Supabase.

---

## Design constraints (from the four verified example offers, BLOG_OPERATIONS 2026-07-02)

| # | Offer | What it forces |
|---|-------|----------------|
| 1 | PCF no-fee stream: 50,000 pts on $100 qualifying spend at named banners within 60 days, apply by 2026-07-31 | ONE offer spanning THREE cards (PC / World / WE via one application) → many-to-many card linkage |
| 2 | PCF Insiders: 50,000 pts after $3,000 in 3 months PLUS $120 first-year fee credit | Multi-component (points + fee credit) → component table |
| 3 | PC standard 20K special offer, concurrent with the stream offer; terms uncaptured `[VERIFY: issuer-verified data needed]` | Concurrent offers per card + representing known-incomplete terms |
| 4 | BMO Blue Rewards WE: $200 NEXUS statement credit in year one + first-year fee waiver | Component types beyond points (statement credit, fee waiver) |

A `card_products` column fails all four. A single flat table fails #2 and #4 (multi-component)
unless components are packed into jsonb, which breaks queryability and the house preference
for typed columns. **Proposal: two tables.**

## Table shape

### `welcome_offers` (offer level)
- `id` text PK (slugged, e.g. `pcf_nofee_stream_50k_2026H2`)
- `issuer_id` text FK → issuers
- `display_name` text NOT NULL
- `offer_status` text CHECK (`active | expired | withdrawn | incomplete`) — `application_status`-style state; #3 loads as `incomplete`
- `qualification_spend_cad` numeric(10,2) NULL (NULL = unknown/no threshold; #3 loads NULL)
- `window_text` text NULL (issuer wording verbatim — source of truth; "60 days" for #1, "3 months" for #2) + `window_days` integer NULL (normalized interpretation — column comment must label it as such; 60 for #1, 90 for #2) — dual columns per RESOLVED Q4 (2026-07-03)
- `apply_by` date NULL (2026-07-31 for #1)
- `qualifying_purchase_exclusions` text NULL — OFFER-level exclusions, distinct from program-level `card_exclusions`. The PCF wording pattern is the model: the program's "qualifying purchase" definition (excludes withdrawals, cash advances, balance transfers, convenience cheques, cash-like) applies, and the offer adds its own scope on top ("qualifying spend **at named banners**"). Store the offer-scope wording here; never duplicate program exclusions.
- `one_application_multi_card` boolean DEFAULT false (true for #1 — one application matched to PC/World/WE)
- `valid_from` date NOT NULL DEFAULT CURRENT_DATE, `valid_to` date NULL — expire-then-insert per house convention (never DELETE; terms change → expire the row, insert the successor)
- `source_url`, `source_date_accessed`, `source_language`, `source_clause_reference` — required on every row per house rules
- `notes` text

### `welcome_offer_components` (component level)
- `id` uuid PK
- `offer_id` FK → welcome_offers
- `component_type` text CHECK (`points_grant | statement_credit | fee_waiver | fee_rebate | first_year_multiplier`) — **extensible enum**; extend by migration, never by overloading
- `points_amount` integer NULL (50,000 for #1/#2; 20,000 for #3)
- `cash_amount_cad` numeric(10,2) NULL ($120 for #2's credit; $200 for #4's NEXUS credit)
- `multiplier` numeric(10,4) NULL (first_year_multiplier only)
- `component_terms` text NULL (e.g. "first year", "NEXUS application", "billed then credited")
- `source_clause_reference` text
- Constraint: exactly one of points_amount / cash_amount_cad / multiplier non-NULL, matched to component_type.

### `welcome_offer_cards` (linkage, many-to-many)
- `offer_id` FK, `card_id` text FK → card_products, PK (offer_id, card_id)
- #1 gets three rows; #2/#3/#4 get one each. Concurrency (#3 alongside #1 on the same card) is inherent — two active offers can reference one card.

## Worked mapping of the four examples

1. **PCF stream** — one `welcome_offers` row (`spend $100 / 60 days / apply-by 2026-07-31 / exclusions: qualifying spend at named banners`), one `points_grant` 50,000 component, three `welcome_offer_cards` rows.
2. **PCF Insiders** — one offer row (`$3,000 / 90 days`), two components (`points_grant` 50,000 + `fee_rebate` $120 "first year"), one card row.
3. **PC standard 20K** — one offer row, `offer_status = 'incomplete'`, spend/window NULL, one `points_grant` 20,000 component, one card row. Nothing invented; the status flag is the representation of "known-incomplete."
4. **BMO Blue Rewards WE** — one offer row, two components (`statement_credit` $200 "NEXUS, year one" + `fee_waiver` "first year"), one card row.

## Lifecycle

Expire-then-insert throughout (`valid_from`/`valid_to`), matching `earn_rates`/`card_caps`.
`offer_status` handles the marketing state (`expired` when the apply-by passes; `withdrawn`
when the issuer pulls it early); validity columns handle the versioning history. An offer
whose terms change mid-flight = expire + insert, not update.

## Reverification flow

Offers churn faster than the monthly loop — #1's 2026-07-31 apply-by goes stale mid-cycle.
Proposal: **biweekly offer pass** over offer-bearing pages only, separate from the monthly
full run. Registry implications (named, not edited): a new `source_type = 'welcome_offer_page'`
row per card whose product page carries offers, `fetch_cadence = 'biweekly'`; most offer
sources are the existing product pages, so rows duplicate URLs with a different source_type —
acceptable, since cadence and diff-scope differ. BMO rows inherit the manual-fetch caveat.

Registry pattern (RESOLVED Q6, 2026-07-03): distinct welcome_offer_page rows are added only
when an issuer publishes a distinct offer URL; until then, offer sourcing rides the
product-page rows with a cadence note.

## Scoring boundary

**Offers are load_only / excluded from the scoring engine at launch.** No offer value enters
`computeEarnMathV2` or any recommendation path until Mike explicitly revisits. The tables are
capture infrastructure, mirroring the offer-stacking posture (captured, not active).

## Open questions — all RESOLVED 2026-07-03 (Mike)

1. Targeted/invite-only offers — **RESOLVED 2026-07-03 (Mike): public offers only at launch.** Targeted offers deferred entirely — no audience concept in v1.
2. Provincial variations — **RESOLVED 2026-07-03 (Mike): reuse the `available_provinces` text[] pattern** from card_products.
3. FR mirrors — **RESOLVED 2026-07-03 (Mike): FR offer rows stay blank** per the pipeline-wide FR deferral.
4. "3 months" vs days — **RESOLVED 2026-07-03 (Mike): dual columns** — `window_text` (issuer wording verbatim, source of truth) + `window_days` (normalized integer, explicitly labeled interpretation in the column comment).
5. Affiliate linkage — **RESOLVED 2026-07-03 (Mike): stays out of the data layer** — commission-blind boundary confirmed; revenue modeling reads, never writes.
6. Registry sourcing — **RESOLVED 2026-07-03 (Mike): track offers via the registry.** No `welcome_offer_page` rows with guessed URLs; offer sourcing rides the existing product-page rows with a cadence note (see Reverification flow) until an issuer publishes a distinct offer URL.
7. Standing dormancy note — **RESOLVED 2026-07-03 (Mike): as written** — DB-side work sits documented until picked up; no migrations exist for any of this.
