# NOTE — API-011 `mcc_defined` disclosure, Slice 1 (executed 2026-08-14)

Last updated: 2026-08-14
From: Claude Code session (Mike supervising), executing the Slice 1 dispatch
Re: `recommend-card-v2` v21 — condition-suppressed earn-row disclosure

## Read this first: what this note is NOT

**This is not `HANDOFF_mcc_gating_accuracy_strategy.md`.** That document governs the
slicing of this work and is cited by the Slice 1 dispatch as its reference (§6). As of
2026-08-14 it is **not filed anywhere on Mike's machine** — not in this repo, not in
`CardCoachv2`, not under `~/Documents`, `~/Downloads` or `~/Desktop`. Searches by
filename (`*mcc*gating*`) and by content (`mcc_gating_accuracy`) across the home
directory return nothing but the two references in `WORKING_NOTES.md` /
`PIPELINE_AND_DECISIONS.md` that were written on 2026-08-14. The only `HANDOFF_*` files
that exist are `HANDOFF_engine_rising_tiers_2026-08-12.md` (this repo) and
`HANDOFF_cpp_valuation_lane_2026-07-31.md` (CardCoachv2 business docs).

This note therefore records **only what is directly evidenced**: the dispatch as
received, and what executing it actually produced. It deliberately does not reconstruct
§1–§5 or §7–§8 of the strategy, the full slice list, or the reasoning behind the
slicing — none of that was in hand. **Do not treat this file as the strategy.** If the
handoff resurfaces, file it at the repo root next to the rising-tiers handoff; this note
stays as the execution record.

## What Slice 1 was

Scope was one file: `mobile_app_codebase/supabase/functions/recommend-card-v2/index.ts`.
Stated guarantee: byte-identical ranking order and values — additive response fields and
two log fields only, no data writes, no user-facing copy.

The change ports API-011's `conditionalNotApplied` disclosure onto the **authed merchant
path**. When the condition gate suppresses an earn row at the resolved merchant, that row
is now reported per recommendation, so a card is not silently valued as though the row
never existed. Two disclosure gates were ported from `recommend-cards-stateless-v1`: a
card excluded for the purchase category, or with no usable base rate, is never told it
"may earn more".

`categoryMccAssumption` stays `null` on the merchant path — API-011's assumption
behaviour is unchanged by this slice.

## What shipped

- **Deployed:** `recommend-card-v2` v20 → **v21**, ACTIVE, `verify_jwt: false`
  (gateway verification stays off; JWT is validated in-code).
- **Commit:** `f1a7158` in CardCoachv2 (`main`), one file, 88 insertions / 1 deletion.
- **Settled decision:** see the 2026-08-14 entry *"Suppression disclosure is decided by
  the pricing predicate, never a copy"* in `PIPELINE_AND_DECISIONS.md`. The short form:
  disclosure is decided by the same exported `earnRowPrices` predicate
  (`_shared/scoring.ts:1179`) that prices the rows, so disclosure cannot drift from
  pricing. The field is absent — never an empty array — when nothing was suppressed.

## Evidence

Gates, all green before deploy: `pnpm typecheck`; `deno check` on the changed function;
`pnpm test:supabase` 256 passed / 0 failed; `pnpm verify:api-006` 9/0; `pnpm
verify:api-008` 8/0. Note the two verify scripts ran against a freshly-created
empty-wallet user and self-skipped their ranking, caps, stacking and parity assertions —
they validated the contract, not the ranking.

Live fixtures on Mike's wallet (`13249fa5…`), from `recommend_card_v2_success` logs:

| Tap | Result |
|---|---|
| Kelsey's `cbaeb36c` (dining) | `suppressedEarnRateIds ["c0cfce4c"]`, `conditionalNotAppliedCards 1`, `cardCount 5`. Two taps, byte-identical output. |
| RCSS `6e7370e0` (grocery) | `suppressedEarnRateIds ["f382d9d7"]`, `conditionalNotAppliedCards 1`, `cardCount 5`. **No** PC Financial grocery row id (`e5ad5cc0`, `2e456e14`, `19bece9a`, `dbafc1bc`) disclosed, and the PC card still ranked top — the mixed-gate regression guard. |

Ranking regression, honestly stated: RCSS `topCardId`/`cardCount` were **identical** to
the same-day pre-deploy v20 baseline (6 samples, 01:15–02:43). Kelsey's had **no**
same-day v20 tap to compare against, so that half is **unmeasured, not verified**. The
structural argument — the success log reads `recommendations[0]`/`.length` from the
untouched array, while only a shallow map adding one key feeds the response — is
reasoning, not a measurement.

## The QA-009 detour (worth knowing before the next slice)

Slice 1 hit its own `pnpm test:supabase` STOP gate on the first attempt. The failure was
**pre-existing on `main`**, proven by re-running against the pristine file: `bfd487e`
(ENG-floors, 2026-08-12) added four fields to `EarnRateRow` and `annualSnapshots` to
`ScoringContext` and touched no file under `__tests__/`, leaving 6 type errors and 40
runtime failures — the entire QA-009 golden pack — dead on
`ctx.annualSnapshots is not iterable`. Repaired first, in its own commit `bd88062`
(fixtures only, inert defaults); suite went 216/40 + 6 type errors → 256/0. See the
2026-08-14 entry *"A shared-type change owns the edge-function fixtures too"* in
`PIPELINE_AND_DECISIONS.md`.

Consequence for whoever runs the next slice: `pnpm typecheck` is `pnpm -r typecheck` over
the five pnpm workspaces and **does not see `supabase/functions/` at all**. Use
`deno check <fn>/index.ts` and `pnpm test:supabase`.

## Explicitly deferred by the dispatch

Carried verbatim from the dispatch's own out-of-scope list — these are known-open, not
oversights:

1. The `default_category_id` runtime UPDATE at ~line 253 of the same file (§9 class,
   its own hotfix commit).
2. `engine-contracts` type additions — ride the D3-gated client-rendering commit.
3. Any user-facing copy — **D3 pending**. The field ships in the API but nothing reaches
   users until D3 lands.
4. The `assumptions` response key, occupied by `fuelAssumptions` in v2 — Slice 5
   decision.

**Ambiguity flag:** "D3" here is a decision in the *mcc-gating* handoff. It is **not**
the D3 in `HANDOFF_engine_rising_tiers_2026-08-12.md`, which has its own D1/D2/D3 (Mike,
2026-08-12, referenced in the ENG-floors commit). The numbering collides across the two
documents. Since the mcc-gating handoff is unfiled, D1/D2 of that series are unrecorded
anywhere.

## Where the real records are

The engineering record for this feature area is committed and intact — it is only the
strategy handoff that is missing:

- `mobile_app_codebase/docs/planning/specs/API-011_category_mcc_assumption.md`
- `mobile_app_codebase/docs/planning/specs/API-012_assumption_disclosure.md`
- `.../specs/implementation_summaries/API-011_category_mcc_assumption_complete.md`
- `.../specs/implementation_summaries/API-012_assumption_disclosure_complete.md`
- `WORKING_NOTES.md` **#25** — the live tracking item for the remaining slices.

## Still missing

`HANDOFF_mcc_gating_accuracy_strategy.md` itself: the slice list beyond Slice 1, the
D-series decisions, and the accuracy rationale for gating on `mcc_defined`. Ask Mike, or
recover it from the session that authored the dispatch, before running Slice 2+.
