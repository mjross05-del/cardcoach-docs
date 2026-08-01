# DISPATCH — APP-017: Till-moment stack UX (mobile)

For: a coding runtime (Claude Code) on `CardCoachv2/mobile_app_codebase`, branched from `feat/loyalty-offers-phase1`. Activation precondition: this must SHIP before the `loyalty_offer_stacking` flag flips.

## Prompt (paste below this line into the runtime)

Read first: `docs/planning/specs/API-013_loyalty_stacking_scoring.md`, `docs/planning/specs/DATA-018_loyalty_stacking_schema.md`, `AGENTS.md` (mobile never computes; render only), and the existing stacking callout at `apps/mobile/src/components/recommendations/stacking/`.

Implement APP-017 (spec stub in `docs/planning/01_feature_inventory.md`):

1. **Contract adoption (the actual activation precondition).** The app's response parsing must accept: optional `assumptions[]` (fuel_price_assumption) and `linkageOpportunities[]` on recommend-card-v2/recommend-here-v2 responses, and the new `fuel_price_assumption` item inside `explanation.sections[id="assumptions"]`. These are already in `@cardcoach/engine-contracts` on the branch — bump the app's usage, confirm old fixtures still parse, and add parse tests. This is what makes old-vs-new client compatibility real.
2. **Stack badge.** `WhyThisCardReceipt` + `StackingCallout` already render offer stacks generically; extend `extractStackingCalloutModel` so an applied `cents_per_litre`/`points_per_litre` offer renders as "3¢/L Petro-Points linkage" style lines. Glanceable: the top card + effective % + stack badge must be readable in ≤3 seconds (usability bar from the strategy doc).
3. **Fuel disclosure.** When `fuel_price_assumption` is present, render a small footnote: "Fuel value estimated at {price}¢/L ({litres} L) — verify at the pump." Localize EN/FR (`pnpm verify:i18n-parity` must pass; Quebec Bill 96 compliance copy comes from WS-7 — use neutral phrasing, no program-partnership implication).
4. **Linkage nudge.** Render `linkageOpportunities` as a dismissible "You could earn more here" row: program display name, potential value when present ("possible — check with the program" phrasing when absent), and a "How to link" tap-through to a static explainer per program (petro_points, journie, pc_optimum, triangle_rewards, more_rewards, moi). NEVER present nudge value as guaranteed.
5. **Link management.** A minimal settings surface writing `user_loyalty_links` (member|linked per program) through Supabase with RLS as-is. Self-declared, no bank credentials, ever.
6. Tests: jest for the extractor + parse; Maestro flow for badge visibility gated on a fixture response. UI rules: `theme.spacing`/`Stack`/`Inline` only.

Constraints: no engine imports in mobile; no computation of value client-side; all copy via i18n; `pnpm typecheck && pnpm -C apps/mobile test` green; do not touch `_shared/` or the engine.
