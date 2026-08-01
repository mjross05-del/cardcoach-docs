# REPORT — to runtime "Integrating Dynamic Loyalty Offers into CardCoach calculations"

From: builder/director session, 2026-08-01. Per dispatch-file convention: fold into the night report and delete.

## Outcome

Phase 1 of the stacked-offers strategy is **built, tested, and landed dark** — not a plan, working code. Branch `feat/loyalty-offers-phase1` on CardCoachv2 (commit `b7f288d`, 30 files). The strategy doc's Stage-1 recommendation (persistent gas/grocery stacks, manual data, no bank links, ship the Offer & Eligibility Engine) is complete as specified, with one improvement: the repo already had a stacking solver, typed `cents_per_litre` bonuses, fail-closed offer scoping, and a mobile stacking callout — all dark with zero data. So this initiative EXTENDED the platform instead of duplicating it: ~85% of the strategy doc's proposed offer data model already existed; the four real gaps (user↔loyalty linkage fact, per-litre valuation, loyalty scope dimension, offer verification metadata) are what got built.

## What exists now

- **Schema (DATA-018):** loyalty_programs (9 programs), user_loyalty_links (member|linked, RLS own-rows), offer_scope_loyalty_programs_v3 (fail-closed; linked satisfies member, never the reverse), per-litre bonus units + litre caps + loyalty-currency bonuses, offers verification metadata (verification_status/confidence/source_url/last_verified_at), fuel_price_assumptions (parameterized ¢/L; litres derive from amount÷price so no fill-volume guess), runtime_flags.
- **Engine (PKG-010):** pure fuel math; $80 @ 160¢/L × 3¢/L = 150¢ exactly (the strategy doc's worked example reproduces to the cent, and the full RBC-Avion stack computes ≈ $3.5 on $80 ≈ 4.4% as the doc projected).
- **Scoring (API-013):** flag-gated loyalty applicability + per-litre pricing with self-disclosed fuel assumptions (mirrors the repo's API-011/012 assumption-disclosure precedent) + `linkageOpportunities` ("link to earn more") on both recommend endpoints. **Flag off ⇒ byte-identical output, proven by test** — rule 5 intact.
- **Data:** 10 offers seeded. RBC↔Petro-Canada ×3 = `issuer_confirmed` (live-verified against rbcroyalbank.com + terms PDF today; all strategy-doc claims CONFIRMED, plus material nuances captured: RBC Esso Visa/commercial/prepaid excluded, retail-only, max ONE additional fuel-savings card per transaction, Avion bonus covers all Petro purchases with 90-day posting, authorized users excluded). The other 7 are `editorial` (confidence 0.4–0.6, [VERIFY]-flagged) and hard-gated on verification.
- **Verification:** engine 120/120, contracts 103/103, edge Deno 166/166 (16 new API-013 tests incl. flag-off byte parity and determinism), endpoints deno-check green, both migrations parse, `pnpm verify:loyalty-p1` 8/8.

## Strategy deviations worth knowing

1. **No fill-volume parameter needed at the till** — the doc assumed one; litres derive from the actual amount ÷ price, so only the fuel PRICE is assumed and it's disclosed per response. Cleaner and more honest.
2. **Scene+/Empire seeded no offers** — membership base earn isn't card-conditional, so it can't change a card ranking; Scotia card earn_rates already carry Scene+ value. The doc's "stack" there is really presentation, which is APP-017's job.
3. **Loyalty currencies with issuer-FIXED redemption rates** (Petro 0.1¢, CT 1:1) live on loyalty_programs, outside the tiered/evidence-governed point_valuations system — deliberate, to avoid a second valuation authority for what are Tier-1 published constants. Moi has NO rate (fails closed) until Tier-1 capture.
4. **Triangle pump earn modeled as offers** resolves WORKING_NOTES #10's pump case without waiting on the earn_rates enum.
5. **AIR MILES/Shell: watch, don't build** — transition dates recorded on loyalty_programs (status `transitioning`); WS-5 dispatch owns the watch.

## Activation gates (strict order)

1. WS-1 Tier-1 verification of the 7 editorial offers → `dispatches/DISPATCH_WS1_stack_verification_2026-08-01.md`
2. APP-017 mobile release with the widened explanation union BEFORE the flag flips (old clients would fail the union parse) → `dispatches/DISPATCH_APP017_till_moment_ux_2026-08-01.md`
3. Founder flag flip + PROJECT_RULES rule 5 update.

Supporting dispatches: WS-5 freshness/registry extension + AIR MILES watch; QA-009 30-scenario golden pack (the doc's ≥95% re-rank benchmark).

## Needs Mike's machine (sandbox couldn't)

`pnpm supabase:db-reset` (no Docker here) + full `pnpm verify` + mobile jest, then merge decision. `pnpm engine:bundle` will also want a clean run locally (sandbox synced the bundle by copy-over; file parity verified). Both repos committed locally; docs push to origin needs your credentials/connector.
