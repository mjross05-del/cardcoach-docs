# DISPATCH — DATA-019 / API-014 / APP-018: Membership-earn display + attribution notice (Phase 1.1)

Recommended executor: **Opus 5 with extended thinking (ultrathink)**. This touches `_shared/scoring.ts`, which both live recommendation endpoints depend on — a subtle error silently returns confidently wrong dollar values to a live app. Run with `~/dev/CardCoachv2` mounted, work in `mobile_app_codebase/`, branch `feat/member-earn-display` off `main`. Read `AGENTS.md` + `~/dev/cardcoach-docs/PROJECT_RULES.md` first; both bind.

## Prompt (paste below this line into the Opus 5 session)

Think hard before writing any code. Derive current behaviour from the code you read, not from this document — where they disagree, the code wins and you flag the discrepancy.

### Why

At Shoppers Drug Mart the app shows a PC World Elite as 3.0% while pcfinancial.ca markets 45 pts/$ (4.5%). Both are right: 45 = 15 pts/$ that ANY PC Optimum member earns regardless of tender + 30 pts/$ card-conditional. CardCoach ranks by card-conditional value only (correct — member earn is constant across cards) but displays nothing about the member component, so the app silently disagrees with issuer marketing. Fix: an informational, NON-RANKING "member earn" line, plus the in-app trademark attribution notice from the WS-7 compliance pack (`~/dev/cardcoach-docs/COMPLIANCE_loyalty_stacking_pack_2026-08-02...` — the file is `COMPLIANCE_loyalty_stacking_pack_2026-08-01.md`, §2 has the EN/FR notice copy).

### THE ONE INVARIANT THAT DOMINATES EVERYTHING ELSE

The flag `loyalty_offer_stacking` is LIVE and the circle's current TestFlight build parses every response with zod. A NEW explanation-item type would fail the current build's discriminated union (`zExplanationItemV2`) — that lesson is why `fuel_price_assumption` shipped app-first behind a dark flag. You do NOT have a dark flag this time. Therefore: **the new server surface must be a response-level / recommendation-level OPTIONAL OBJECT FIELD, never a new explanation-item type.** Old zod object parsers strip unknown keys, so server-first deploy is then safe. Add a test that parses a new-style response with the CURRENT (pre-change) response schema and asserts success. Do not touch `zExplanationItemV2`.

### Read first, in order

1. `supabase/functions/_shared/scoring.ts` — `loadScoringContext` / `loadReferenceScoringContext` (how loyalty context loads, flag gate at `runtime_flags` read), `scoreWalletForPurchase` return shape (`linkageOpportunities` / `fuelAssumptions` pattern — you are adding a sibling surface).
2. `supabase/functions/_shared/offerApplicability.ts` — `loadCanonicalOffers` group/entity scoping pattern; `loyalty_programs.cents_per_point` usage (fail-closed valuation).
3. `packages/engine-contracts/src/loyaltyStacking.ts` + `recommendCardV2.ts` / `recommendHereV2.ts` — where the optional response fields were added for API-013; mirror exactly.
4. `supabase/migrations/20260801150500_data_018_loyalty_stacking_seed.sql` + `20260802160000_chain_entity_matching.sql` — the JOIN-guarded seed pattern (migrations run BEFORE seed.sql data locally; every FK-dependent insert must be guarded AND repeated in a completion block at the END of `supabase/seed.sql`).
5. `supabase/functions/__tests__/api_013_loyalty_stacking.test.ts` — `makeCtx` fixture pattern; extend, don't fork.
6. `apps/mobile/src/components/recommendations/LinkageNudge.tsx`, `WhyThisCardReceipt.tsx`, `SettingsScreen.tsx`, `src/services/loyaltyLinks.ts`, `src/i18n/locales/{en,fr}.json` — APP-017's patterns for services, i18n parity, and fail-closed rendering.

### DATA-019 — schema + seeds (one migration + seed.sql completion block)

New table `loyalty_member_earn_rates`:
- `id uuid pk`, `loyalty_program_id text not null references loyalty_programs(id)`, exactly one of `merchant_group_id uuid references merchant_groups(id)` / `merchant_entity_id uuid references merchant_entities(id)` (CHECK), `value numeric(8,4) not null check (value > 0)`, `value_unit text check in ('points_per_dollar','points_per_litre','cents_per_dollar')`, `tender_restriction text not null default 'any' check in ('any','cash_debit_only')`, `verification_status` / `source_url` / `last_verified_at` / `notes` (mirror the offers columns), `valid_from date not null`, `valid_to date null`. RLS: canonical_read (copy the 0021 pattern verbatim).
- Also: `UPDATE loyalty_programs SET cents_per_point = 0.1000, cents_per_point_source_url = 'https://www.pcfinancial.ca/en/esso-credit-card/', cents_per_point_note = 'Issuer-published: minimum redemption 10,000 points = $10 (verified 2026-08-02)' WHERE id = 'pc_optimum' AND cents_per_point IS NULL;` — required so PC member points can value; the guard preserves idempotency.

Seed ONLY these rows (all Tier-1 verified 2026-08-01/02 in the WS-1 and PC verification reports; do not add more without sources — rule 7):
| program | scope | value | unit | tender | source |
|---|---|---|---|---|---|
| pc_optimum | entities: shoppers drug mart, pharmaprix | 15 | points_per_dollar | any | pcfinancial.ca card pages footnote "All PC Optimum members earn 15 points per dollar…" (2026-08-02) |
| pc_optimum | group esso-mobil | 10 | points_per_litre | any | esso.ca/en-ca/pc-optimum-rewards (2026-08-02) |
| petro_points | group petro-canada-network | 10 | points_per_litre | any | petro-canada.ca / RBC Linked Loyalty Terms (2026-08-01) |
| more_rewards | group more-rewards-grocery-partners | 1 | points_per_dollar | any | morerewards.ca "one base point for every dollar" (2026-08-01) |
| moi | entity metro | 1 | points_per_dollar | any | programmemoi.ca accumulation grid — QC rate; ON is 1 pt/$3 (see trap 4) |
| triangle_rewards | group ct-family-retail | 0.4 | cents_per_dollar | any | triangle.canadiantire.ca loyalty grid (2026-08-01) |
| triangle_rewards | groups canadian-tire-gas-plus + petro-canada-network | 3 | cents_per_litre… **NO — do not seed**: pump member earn is cash/debit-only (Program Rules), i.e. never available when paying by credit. Record as a `notes` row-comment in the migration, not data. |

Loblaw-banner grocery member rate and Scene+/Empire member rate are NOT Tier-1 captured — leave out, add `[VERIFY]` items to the migration comment, and note them for the Sunday/Monday batches.

### API-014 — scoring surface

- `loadReferenceScoringContext`: when `loyaltyStackingEnabled`, also load active `loyalty_member_earn_rates` (valid window vs asOfDate). Store raw rows on the context.
- `scoreWalletForPurchase`: resolve applicable rows for THIS merchant (entity match ∪ group match), exclude `tender_restriction = 'cash_debit_only'` (we recommend credit cards), value each: points_per_dollar → `amountDollars × value × loyalty_programs.cents_per_point` (row's program; CPP null ⇒ SKIP the row silently-with-warning, never 0-value it); points_per_litre → reuse the PKG-010 helpers with `ctx.fuelPrice` (no fuel price ⇒ skip+warning); cents_per_dollar → direct. Sum per program.
- Output: NEW optional return field `membershipEarn?: { entries: Array<{ loyaltyProgramId; programDisplayName; value; valueUnit; valueCents }>; totalValueCents }` — **response-level (constant across cards — compute once, not per card)**, absent (not empty) when flag off or nothing applies. Deterministic ordering (program id asc).
- **It must never touch `effectiveValueCents`, `effectiveValueExactCents`, ranking, breakdowns, or explanations.** Add a byte-parity test: recommendations array deep-equals a run without member rates in context.
- Contracts: `zMembershipEarnV1` in `loyaltyStacking.ts`; optional field on `zRecommendCardV2Response` + `zRecommendHereV2Response` (here-v2: compute from the FIRST resolved candidate's merchant? No — member earn is merchant-specific and here-v2 is multi-candidate: attach per-candidate as an optional field on `zRecommendHereV2Candidate` instead, and leave the response level absent. Think this through against the actual candidate schema before deciding; document your choice in the spec file.)
- Endpoints: pass-through in `recommend-card-v2/index.ts` and `recommend-here-v2/index.ts`.

### APP-018 — display + attribution

1. Member-earn line under the recommendation (WhyThisCardReceipt collapsed view, below the stack badge): user has `member`/`linked` for the program → "Plus as a {program} member: +{value} ({percent-or-per-litre}) — any card"; user has NO link → fold into the LinkageNudge as an any-card teaser instead (reuse its dismissal + explainer). Values from the server field only — the app computes nothing.
2. Reconciliation microcopy in the expanded receipt when both card earn and member earn exist for one program family: "{cardPct} from this card + {memberPct} as a member = {totalPct} — matches {program} advertising." Localize; formatters exist in `src/i18n/formatters.ts`.
3. Attribution notice: static "About loyalty programs" screen reachable from Settings (near the loyalty section), rendering the WS-7 §2 EN/FR copy verbatim from i18n keys. No network.
4. i18n: EN/FR parity for every new key; `pnpm verify:i18n-parity` green.

### Traps (each one has already bitten this codebase)

1. New explanation-item types break deployed clients (see THE ONE INVARIANT). 2. Migrations run before seed.sql on fresh local DBs — JOIN-guard FK-dependent inserts and mirror them in a seed.sql completion block. 3. `pnpm engine:bundle` copy discipline — you should NOT need engine changes (valuation reuses exported PKG-010 helpers via `_shared/engine/index.ts`); if you think you need an engine edit, stop and re-derive. 4. Moi is per-banner and per-province (Metro ON = 1 pt/$3, Food Basics = 0) — the single seeded Metro row is the QC rate; put the ON caveat in `notes` and surface nothing you can't defend. 5. `deno.json` test.include makes every `.ts` under `__tests__/` a test module — no helper files there without care. 6. Response fields must be absent-not-empty when the flag is off (match `linkageOpportunities` semantics exactly).

### Acceptance — all must exit 0, in this order

`pnpm build:contracts` · `pnpm -C packages/engine-contracts test` · `cd supabase/functions && deno task test` (entire suite; your new tests included — cover: valuation per unit, CPP-missing skip, tender exclusion, ranking byte-parity, old-schema parse-compatibility, absent-when-flag-off, determinism) · `pnpm typecheck` · `pnpm -C apps/mobile test` · `pnpm verify:i18n-parity` · `pnpm verify:loyalty-p1` (must stay green — you changed shared files it checks). Then: spec files `docs/planning/specs/{DATA-019,API-014,APP-018}_*.md` (house format), inventory rows, implementation summary with State block, single commit on the branch. Do NOT merge, do NOT deploy, do NOT write to the cloud DB — report and stop. Ship steps for Mike after review: `git merge --no-ff feat/member-earn-display && npx supabase db push && npx supabase functions deploy recommend-card-v2 recommend-here-v2` + EAS build for the app side.
