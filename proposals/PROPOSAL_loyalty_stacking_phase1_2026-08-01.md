# PROPOSAL — Loyalty Stacking Phase 1 (Dynamic Loyalty Offers at the Till)

Status: LANDED DARK 2026-08-01 (branch `feat/loyalty-offers-phase1`, CardCoachv2/mobile_app_codebase) — activation pending three gates below. Authored by the "Integrating Dynamic Loyalty Offers into CardCoach calculations" initiative session.

## Problem

A category-multiplier engine cannot see card × loyalty stacking. At Petro-Canada, a linked RBC cardholder earns an instant 3¢/L + 20% bonus Petro-Points + (Avion) 20% bonus Avion points. At $1.60/L a 3¢/L linkage is ~1.9% incremental — it flips the till ranking against a 2% flat card ($80 fill: 2% card = 160¢; RBC Avion stack ≈ 310¢+ with the discount alone on a 2%-equivalent base). No Canadian product does point-of-sale, stack-aware recommendations; this is CardCoach's core unmet need and a genuine white space.

## What landed (all dark behind `runtime_flags.loyalty_offer_stacking = false`)

1. **DATA-018** — schema: `loyalty_programs` (9 programs incl. issuer-published fixed CPPs where Tier-1: Petro-Points 0.1¢), `user_loyalty_links` (member|linked, RLS own-rows), `offer_scope_loyalty_programs_v3` (fail-closed scope dimension), per-litre bonus units + `max_litres` + loyalty-currency bonuses, offer verification metadata (`verification_status`, `confidence`, `source_url`, `last_verified_at`), `fuel_price_assumptions` (parameterized, self-disclosed; litres derive from amount ÷ price — no fill-volume guess), `runtime_flags`.
2. **Seeds** — 10 offers across the Phase-1 stacks: RBC↔Petro-Canada ×3 (**issuer_confirmed, live-verified 2026-08-01** incl. exclusions: RBC Esso Visa/commercial/prepaid, retail-only, one-additional-fuel-card stacking limit), CIBC↔Journie, PC↔Esso/Mobil ×2, Triangle pump ×1 (resolves WORKING_NOTES #10 for the pump case), RBC↔Triangle, RBC↔More Rewards, RBC↔Moi — the last seven **editorial, confidence 0.4–0.6, [VERIFY]-flagged**, hard-gated on WS-1 before activation. Scene+/Empire deliberately has no offer rows (membership base earn is not card-conditional); Costco stays a network-exclusion concern; AIR MILES/Shell NOT seeded (P0 transition watch instead).
3. **PKG-010** — pure fuel math in the engine (`litres = amount ÷ price`; worked example $80 @ 160¢/L × 3¢/L = 150¢ exactly).
4. **API-013** — flag-gated scoring: loyalty dimension fail-closed (`linked` satisfies `member`, never the reverse; missing-link-only rejections become truthful `linkageOpportunities` nudges), per-litre pricing with `fuel_price_assumption` self-disclosure at both response and explanation level (API-011/012 pattern), across both recommend endpoints. **Flag off ⇒ byte-identical output, proven by test.**
5. **Tests/verification** — engine 120/120, contracts 103/103, edge Deno 166/166 (16 new), endpoint `deno check` green, migrations parse (pglast), `pnpm verify:loyalty-p1` 8/8. Not yet run: `supabase db reset` (no Docker in session sandbox), mobile jest (untouched), full `pnpm verify`.

## Activation gates (in order)

1. **WS-1 verification dispatch** — Tier-1 capture of the 7 editorial offers; any failed row gets expired or corrected before the flag ever flips. RBC Avion double-count check included (0035 display_label history).
2. **APP-017 mobile release** — the widened explanation union (`fuel_price_assumption` item) must be in the shipped app BEFORE activation, or old clients fail response parsing. UI renders stack badge, disclosure, nudges.
3. **Founder flag decision** — flip `loyalty_offer_stacking` via service role; then and only then update PROJECT_RULES rule 5.

## Founder decisions embedded (from the strategy doc's open questions)

- Data-access posture: **credential-free** (CardPointers-style) for the foreseeable term; self-declared links + memberships. CDBA/open-banking ingestion deferred until accreditation is real (draft regs consultation ends 2026-08-26; Phase-1 read access reported at risk).
- Point-value philosophy: **conservative, issuer-published fixed rates only** for loyalty currencies (Petro 0.1¢ verified; More Rewards 0.15¢ floor [VERIFY]; Moi fail-closed NULL). Card currencies stay in the tiered, evidence-governed point_valuations system — no second valuation authority for skill-dependent currencies.
- Targeted offers (Amex/Scene+/RBC personalized): **out of scope** until Phase 3; nothing unconfirmed is ever presented as guaranteed.
- AIR MILES/Blue Rewards: **watch, don't build** — deprecation watch entry in loyalty_programs (status `transitioning`, Shell end-dates recorded); Shell+Scene+ stack stood up only when rollout is Tier-1 verifiable.

## Open items for Mike

1. Gas price default seeded at 165.0¢/L national (mid-range of 2026 readings; excise-holiday distortion noted). Monthly WS-5 review against StatsCan 18-10-0001-01 — confirm cadence owner.
2. Quebec: Journie QC carve-out is [VERIFY]-flagged; Bill 96 French copy for APP-017 nudge/disclosure strings needs the compliance pass before activation in QC.
3. `pnpm supabase:db-reset` + full `pnpm verify` on your machine before merging the branch.
