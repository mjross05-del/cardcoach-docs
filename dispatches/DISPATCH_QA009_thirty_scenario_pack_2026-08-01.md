# DISPATCH — QA-009: 30-scenario loyalty stacking regression pack

For: a coding runtime on `CardCoachv2/mobile_app_codebase`, branched from `feat/loyalty-offers-phase1`. Target: the strategy benchmark "engine correctly re-ranks the top card in ≥95% of tested gas/grocery scenarios," with hand-computed expected values within ±1%.

## Prompt (paste below this line into the runtime)

Read first: `packages/engine/test/golden/qa-005/` (the fixture pattern to clone — contracts.ts, runFixture.ts, fixtures/*.json), `supabase/functions/__tests__/api_013_loyalty_stacking.test.ts` (the 16 seed tests and their `makeCtx` fixture builder), and specs DATA-018/PKG-010/API-013.

Build `qa-009` as a Deno-level golden pack (the loyalty path lives in `_shared/scoring.ts`, not the pure engine, so the harness belongs in `supabase/functions/__tests__/golden_qa009/` with fixtures as JSON + a runner mirroring `runFixtureWithDeterminismCheck`). 30 scenarios, each with hand-computed expected math in a comment:

- **Ranking flips (10):** RBC Avion (linked) vs 2% flat at Petro-Canada across amounts $20/$50/$80/$120 and prices 150/165/175¢/L; Triangle MC vs 3% gas card at Gas+; CIBC Journie vs Scotia Gold at Pioneer; PC WE vs Rogers Red at Esso. Assert the top card WITH the flag on differs from (or matches) flag-off ranking exactly as hand-computed.
- **Linkage state matrix (6):** same wallet at same merchant with links absent / member-only / linked; assert applied offers, nudge presence, and that member never unlocks a linked-level offer.
- **Caps & thresholds (4):** max_litres boundary (exactly at cap, 1L over); min_amount_cents; expired offer (ends_at yesterday) suppressed; future offer (starts_at tomorrow) suppressed.
- **Valuation guards (4):** loyalty CPP missing (moi) → warning not value; fuel price missing → warning not value; loyalty CPP present but 0-ish; card CPP vs loyalty CPP routing (b0ff0002-style).
- **Interaction (3):** multiple stacked offers at one merchant (RBC 3¢/L + 20% Petro-Points + Avion multiplier all applied and summed); non-stackable synthetic constraint respected; incompatible pair from `offer_incompatibilities`.
- **Determinism & parity (3):** byte-parity flag-off with loyalty offers present; double-run determinism; opportunity ordering stability.

Add `pnpm verify:qa-009` (a `.mjs` runner that shells `deno test` on the pack and checks the ±1% invariant metadata), wire it into `scripts/verify_all.mjs`'s list, and record the pack in `docs/planning/01_feature_inventory.md` as QA-009. All expected values must be derived in-comment from first principles (show the arithmetic), not from running the engine — that is the point of a golden pack.
