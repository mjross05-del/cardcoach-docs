# Stacking Doc Closure + Push Reconciliation — Report

Run: 2026-08-11 · Input: STACKING DOC CLOSURE + PUSH RECONCILIATION dispatch · audit run `a261a243` (extended)
Outcome: §2 probe PASS on all three criteria, exactly as pre-registered · docs corrected and evidence-upgraded to the probe transcript · push done twice this session (15 commits earlier on "push and merge", 4 more this run), origin verified at `4215b24`.
Fido stays absent (D-D, FIDO_INSERT OFF); public surfaces carry no Fido claims. Flag untouched (leave_ON). Zero deletions anywhere. Probe user retained and marked.

## State reconciliation (dispatch premises vs session reality)

This dispatch was drafted against the worklist run's end-state; two of its steps had already run on Mike's direct in-chat instructions before it arrived: the D-A doc correction (commits `624e73b`/`b31f651`, artifact-level evidence) and the push ("push and merge": 15 commits `9752d1c..1d3b65e`, not 12 — the count predated the resolution commits). Both were treated as candidate RESOLVED-PRIOR, then brought up to this dispatch's standard: §4's per-commit inspection was performed retroactively on the pushed range (clean — table below), and §3's correction was upgraded from "wiring verified" to "production application verified" only after §2 passed.

## Ledger

| Step | Result | Evidence-or-Hash | Follow-up |
|---|---|---|---|
| §2 Tier 1 | UNAVAILABLE | `includeOffers: false` hardcoded in stateless index.ts (not caller-controllable) | — |
| §2 Tier 2 probe | PASS | Transcript below; offer `b0ff0008` applied at 120¢ on $100 | none |
| §2 W2-regression bonus | PASS | Signup completed normally with anon EXECUTE revoked (`handle_new_user` fired as trigger) | none |
| §3 doc correction | DONE, transcript-grade | `624e73b` `b31f651` (correction) + `69a820e` `390064f` (evidence upgrade) | Project sync |
| §3 ledger + WORKING_NOTES | DONE | `051b5fa` `96ad915` `1d3b65e` `4215b24` | Project sync |
| §4 push | DONE ×2, inspected | origin = local = `4215b24`; inspection tables below | — |
| §5 Fido (OFF path) | ABSENCE ACCEPTED; public check CLEAN | site clone, published blog, website copy: zero Fido mentions; one internal business-doc mention (LAUNCH_REVIEW_2026-07-03.md, not public) | none |
| Probe user | RETAINED, marked | details below | optional dashboard deletion, Mike |

## §2 probe transcript

**Pre-registered expectation (written before any call):** endpoint `recommend-card-v2` · context: probe user holding one RBC card (`ca_rbc_cash_back_mastercard_world_elite_mastercard`) with a Triangle link at level `linked` via issuer `rbc` · merchantPlaceId `c087b396-4e56-41d9-bd48-12daaf9eebc8` ("Canadian Tire" retail place) · amountCents 10000, channel in_store · expected: `appliedOffers` contains `b0ff0008-0000-4000-8000-000000000008`, applied value = 1.2 percent of pre-tax spend = **120 cents** (offer row: bonus_type cashback, value 1.2 percent, scope issuer=rbc + ct-family-retail group, issuer_confirmed 0.95, terms s.9: 3x the 0.4 percent member base).

**Setup:** signup `probe-20260811@cardcoach.ca` → 200 with immediate session (no email-confirm gate — the dispatch's guarded `auth.users` update was therefore never needed and never run). uid `7360beb1-2b42-4005-92fd-76b6ef4a9761`. Wallet insert `user_cards` `dda94724` (201). First link insert failed FK — the registry table is `loyalty_programs` with id `triangle_rewards` (underscore), not `reward_programs`/`triangle-rewards`; corrected insert `user_loyalty_links` `c63c1df1` (201): `{triangle_rewards, linked, rbc}`.

**State A — before the link existed** (wallet only): `appliedOffers: []` and `linkageOpportunities` non-empty: `{loyaltyProgramId: triangle_rewards, requiredLinkLevel: linked, potentialValueCents: 120, offerDescriptions: ["3x CT Money (1.2%) at Canadian Tire family stores with an RBC card linked to Triangle Rewards"]}` — the flag-gated path evaluating the offer, failing solely on the link, and pricing the miss at exactly the expected 120¢.

**State B — after the link** (same request): rank-1 card `ca_rbc_cash_back_mastercard_world_elite_mastercard`, `finalValueCents: 270` = base 100 + category 50 + offer 120. `appliedOffers: [{offerId: "b0ff0008-0000-4000-8000-000000000008", offerSource: "canonical", bonusType: "cashback", value: 1.2, valueUnit: "percent", valueCents: 120}]`. `linkageOpportunities: null` (correctly absent once linked). Warnings: none.

**Expected vs observed:** offer id — match. Math — match exactly (1.2 percent × $100.00 = 120¢). Surface transition (nudge → applied) — consistent with the contract's documented semantics. **PASS.**

**Post-probe engine regression:** public stateless TD Cash Back grocery probe = 300¢, identical to every prior baseline. No STOP-EVERYTHING condition.

## §4 commit inspection

Earlier push (`9752d1c..1d3b65e`, 15 commits, inspected retroactively): Mike's 7 (WORKING_NOTES, PROJECT_RULES, SOURCE_OF_TRUTH, dispatches/, deltas/ — his own logged work) + this session's 8 (WORKING_NOTES ×3, ALEX_HANDOFF→DB_ENGINE_WORKLIST ×2, HOW_THE_ENGINE_WORKS, PIPELINE_AND_DECISIONS). Every path in the expected population; zero WIP content in any commit (verified against HEAD greps and the standing worktree diff).

This run's push (`1d3b65e..4215b24`, 4 commits): `69a820e` HOW_THE_ENGINE_WORKS only · `390064f` PIPELINE_AND_DECISIONS only · `051b5fa` DB_ENGINE_WORKLIST only · `4215b24` WORKING_NOTES only. Staging discipline enforced per commit (porcelain check: exactly the intended path staged). Origin verified = local = `4215b24`.

Worktree WIP status after everything: your uncommitted work is intact and grew during this run by your own hand — #23/#24 blocks plus a new #18 status update ("email routing DONE, verified live in dashboard 2026-08-11") observed in the worktree and deliberately left uncommitted. Nothing of it is in any commit or push.

## Probe user (TEST_USER_CLEANUP: retain)

`probe-20260811@cardcoach.ca` · password `Pr0be-x7Rr9mQz-2026` · uid `7360beb1-2b42-4005-92fd-76b6ef4a9761` · rows: `user_cards` `dda94724` (nickname-marked "PROBE — worklist 2026-08-11, retain per TEST_USER_CLEANUP") + `user_loyalty_links` `c63c1df1`. Audit: write_audit row on run `a261a243` records the whole probe. Deletion, if wanted: dashboard → Authentication → delete user (cascades per FK/RLS design).

## CHAT SYNC

- Files changed this run: `HOW_THE_ENGINE_WORKS.md`, `PIPELINE_AND_DECISIONS.md`, `DB_ENGINE_WORKLIST_2026-08-11.md`, `WORKING_NOTES.md`.
- Commits (local = origin): `69a820e` `390064f` `051b5fa` `4215b24`; origin head `4215b24` verified.
- DB: probe-user rows (retained, marked) + one write_audit row; no card-fact writes; `runtime_flags` untouched.
- Project sync required: Y — WORKING_NOTES + both engine docs changed and are now pushed; sync canonical docs, then open a fresh Project chat.
- Outside this run: D-B (leaked-password toggle) remains the one dashboard click, Mike only.
