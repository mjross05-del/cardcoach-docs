# CardCoach DB/Engine Worklist Run — Report

Run: 2026-08-11 (start 13:54:31Z) · Input: `DB_ENGINE_WORKLIST_2026-08-11.md` (renamed this run from ALEX_HANDOFF) · verify.runs `a261a243-d361-4f53-82d3-9b66f9318ed2`
Outcome: items 1, 3, 4b, 5 closed by investigation (no writes warranted) · 4a and 6 executed and verified · item 2 blocked → propose-only (D-D) · zero failed · zero card-fact writes · engine probe unchanged before/after.
Decisions raised: D-A (stacking posture), D-B (leaked-password toggle, always-manual), D-D (Fido). D-C not triggered. W3 and D2 not triggered by their gates.

## Item ledger

| Item | Result | Evidence-or-Hash | Follow-up |
|---|---|---|---|
| 1 Delta provenance | CLOSED — investigated | seed.sql canon; out-of-band apply ~07-27–29; unmapped to any recorded mechanism | D1 note in DELTAS_INDEX (`26b14ae`) |
| 2 Fido end-state | BLOCKED → propose-only | Card row absent from live DB (evidence §I5/W1) | D-D |
| 3 Stacking flag vs engine | CLOSED — investigated | Wired + flag-gated in shared scorer; stateless excludes offers by design | D-A; docs untouched |
| 4a Trigger-fn revokes | DONE, verified | Migration `harden_trigger_function_execute`; audit `728310dc-f5f8-48f1-8d5c-f0d4beba238c` | none |
| 4b Definer views | ACCEPTED BY DESIGN 2026-08-11 | 9 views, catalog-only read surface (§I4) | none |
| 4c Leaked-password protection | MANUAL | Advisor WARN remains | D-B |
| 5 Earn-rate groups | NO DEFECT — nothing expired | Engine selects single best row; all 15 groups differentiated (§I3) | overstatement observation with Mike |
| 6 Snapshot attribution | DONE | Table COMMENT applied; audit `9487dc68-dfa2-4906-b089-d718a85c8a90` | drop stays Mike-only |

## Preflight record

Supabase auth ✓ (reads). Fix-run reconciliation confirmed: APPLY_CHECKLIST stop-note present, DELTAS_INDEX statuses 17 superseded-live + 1 not-applied. HEADs at start: CardCoachv2 `9045523`, cardcoach-docs `95070da` (both post-fix-run). GitHub: fix-run PAT still valid (read confirmed); doc commits stay local by standing policy (your 7 pre-existing unpushed commits stay unpublished). Schema introspection: all target tables + `verify.write_audit` column lists captured; all three §W2 functions are zero-arg SECURITY DEFINER with `PUBLIC/anon/authenticated/service_role` EXECUTE at start. Observed concurrent changes since the sweep (not this run's): migrations `20260811025239/49 create_verify_apply_loop_*` applied 2026-08-11 02:52 (added 2 definer views, 7→9), and an auto write_audit display-name fix (Scotiabank Passport, 2026-08-10).

## I1 — Delta provenance

End-states live-confirmed by targeted value checks: BMO CashBack WE fee 139 · Blue Rewards WE fee 150 · `blue_rewards` point program + 6 valuations (created 2026-07-27) · `ca_rogers_red_world_mastercard` present (created 2026-07-27) · Rogers tiered caps 16k/26k/61k, `valid_from 2026-08-04`, rows created 2026-07-27 (pre-staged) · PCF standard/world/world-elite fees 0, Insiders 120.

Producing mechanism: none of the 74 applied migrations contains these statements (repo migration corpus grepped; only display-label/rekey/stacking-seed files mention the ids) and no `verify.write_audit` rows reference them (write_audit only shows later PCF fx null-fills and the 08-02 FX audit). The same end-states are present in the repo catalog canon `mobile_app_codebase/supabase/seed.sql`, and the live rows' `created_at` cluster at 2026-07-27–29 — the verification-engine P1 window. Conclusion: out-of-band catalog apply from the repo canon, the same unattributed signature that migration `20260729205344`'s header documents for the 20260729 snapshot ("not created by the verification engine and has no corresponding migration or verify.write_audit entry"). Per-file: 16 files `live end-state confirmed · producing migration: none on record · confidence medium-high (mechanism by elimination + created_at cluster + seed.sql content match)`; the two Fido files: card absent (below). Full note committed into DELTAS_INDEX (D1).

## I5 + W1 — Fido

The delta file's intent is unambiguous (single guarded UPDATE: `application_status='closed', is_active=TRUE`, scoring_status untouched, AIR MILES World precedent cited). But introspect-before-write found no target: `ca_rogers_bank_fido_standard_mastercard` does not exist in live `card_products` (114 rows; no id or display_name match on `%fido%`; only 4 Rogers cards, all `open`). It is also absent from `card_products_night_2026_07_31` and `card_products_snapshot_fx_20260802`, has zero orphan rows in earn_rates/card_caps/card_exclusions, and zero write_audit mentions — the card has not been in the DB as far back as the snapshot record reaches. The sweep's "application_status = NULL" was a missing-row misread, and yesterday's DELTAS_INDEX status `not-applied — live state NULL` is refined accordingly (D1 note). The dispatch's W1 UPDATE would match 0 rows; not executed. No write.

**D-D (single-select):** (1) Insert the Fido Mastercard net-new as `closed`/`is_active true`/`load_only`, built from the two 2026-07-04 delta files' content, as a gated write next run — restores the closure record and lets existing Fido cardholders find their card; or (2) accept absence as the standing state and mark both Fido delta files `not-applicable — card never loaded post-repair`. Exact SQL for option 1 can be drafted on request; it is a net-new INSERT, which W1 did not authorize this run.

## I2 — Stacking: flag vs engine

Source (deployed bundle + repo, consistent):
- `_shared/scoring.ts` `loadReferenceScoringContext`: `includeOffers = args.includeOffers ?? true`; when true it reads `runtime_flags.loyalty_offer_stacking` → `loyaltyStackingEnabled`, gates `offer_class='loyalty_stack'` loading ("Any load error fails closed to disabled"), and the apply path runs `solveOfferStack(...)`. API-013/014 response surfaces are documented "present only while the flag is on."
- `recommend-card-v2` and `recommend-here-v2` do not pass `includeOffers` → default **true** → they read the flag and route into the offer path with it ON.
- `recommend-cards-stateless-v1/index.ts:91-97` passes **`includeOffers: false`** ("offers are out of scope") and its request contract (`zRecommendCardsStatelessV1Request`) has no loyalty/member field — per the dispatch, that is itself the answer: not wired at the stateless API surface, by design. Its `appliedOffers` is structurally always `[]`, which fully explains the sweep's probe result.

Live calls (transcripts summarized): schema requires `schemaVersion:"v1"`, `channel`, `locale` (400 with issue paths otherwise). TD Cash Back grocery $100 → rank 1, 300¢ (base 100 + category 200), `appliedOffers: []`, no warnings. Amex Gold travel $100 → 600¢ both `in_store` and `portal` channels (see I3). NB Platinum → `unrankable: load_only`.

Verdict per the dispatch's gates (scoped to a stateless live call): **not confirmed wired** → D2 not run, `HOW_THE_ENGINE_WORKS.md` / `PIPELINE_AND_DECISIONS.md` untouched. The premise shifted, though: the flag is not inert — it is read and routed on the authed v2 production path.

**D-A (single-select):** (1) leave the flag ON — it is active on the authed path; schedule the doc correction gated on an authed-path probe (a `recommend-here-v2` call with a Canadian Tire retail context, or a member-earn context per data_019) next run; or (2) flag OFF to align with the docs until that probe runs. This run changed nothing either way.

## I3 — Earn-rate predicate groups (15)

Engine semantics, from source + confirmed live: the scorer selects a single best-priced row per card+category (`breakdown.categoryBonus` is one rate; base and category are the only additive components) — rows are never summed, so an additive double-count is structurally impossible. Row gating: `earnRowPrices` enforces `portal_only` (channel), `mcc_defined` (assumption/merchant), `merchant_list_only` (eligible-merchant map); `other`-type conditions always price (disclosure-only).

| Group(s) | Verdict |
|---|---|
| National Bank Platinum dining + grocery, WE dining + grocery, World travel, World base (6) | differentiated (mutually exclusive spend tiers in condition_text); additionally unreachable — all 3 NB cards are `scoring_status='load_only'`, confirmed `unrankable` live |
| Amex Gold travel, Amex Platinum travel (2) | differentiated (2x generic vs 3x Amex Travel Online). Observation: both are `other`-type so both price; the 3x row wins selection on any travel purchase — live: 600¢ on $100 in_store AND portal. Overstatement when the portal condition cannot hold; not a duplicate; neither row is surplus |
| CIBC Aeroplan gas, CIBC Aventura gas (2) | differentiated by MCC (EV row `mcc_includes [5552]`); identical 1.5 value — harmless under any selection |
| MBNA Amazon.ca general + grocery (2) | differentiated (Prime 2.5 vs non-Prime 1.5, merchant_list_only). Same observation class: where both price, Prime wins — membership unknowable to the engine |
| MBNA Rewards WE + standard recurring_bills (2) | differentiated by disjoint MCC lists (utilities vs memberships) — properly gated |
| TD Business travel (1) | differentiated (portal phone 6 vs online 9); portal_only is channel-enforced; within portal the 9 wins — phone/online indistinguishable in-channel, minor |

Zero `duplicate → double-count (defect)` verdicts → W3 wrote nothing. The `other`-condition overstatement class (Amex travel, MBNA Prime) is an engine modeling observation for Mike — expiring real issuer facts would have been the wrong fix.

## I4 — Definer views (9, was 7 at sweep)

| View | Base data | Verdict |
|---|---|---|
| v_active_earn_rates · v_active_card_caps · v_active_point_valuations · v_active_benefits · v_active_i18n_strings · v_active_mcc_category_mappings | canonical catalog (validity-window filters) | intended public read surface |
| export_cards | card_products + issuers/networks/programs joins | intended public read surface |
| v_offer_scoped_merchants_from_groups · v_offer_scopes_debug | offer scope/membership catalog tables | catalog-only; `_debug` name is cosmetic, content safe |

None reaches user data, auth, or the `verify` schema. **Accepted by design 2026-08-11.** No conversion attempted (security_invoker would require base-table grants the RLS model deliberately withholds). The +2 since the sweep came from the 2026-08-11 02:52 `verify_apply_loop` migrations (concurrent session). D-C not raised.

## W2 — Trigger-function hardening (executed)

Migration `harden_trigger_function_execute`: `REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated` on `public.handle_new_user()`, `public.handle_user_email_updated()`, `public.maintain_user_spend_snapshots()` (zero-arg, no overloads, per pg_proc). SECURITY mode unchanged; service_role/postgres untouched; trigger firing does not require caller EXECUTE.
Verify: (a) anon RPC probes on all three → HTTP 404 `PGRST202` (function no longer exposed to the role), previously callable; (b) ACLs re-read: `postgres=X | service_role=X` only; (c) advisor re-run: all six 0028/0029 lints cleared, no new findings of any level; (d) engine probe identical to pre-change baseline (TD grocery 300¢). write_audit `728310dc-f5f8-48f1-8d5c-f0d4beba238c`.

## W4 — Snapshot attribution (executed)

Provenance found in migration `20260729205344`'s own header: `point_valuations_snapshot_20260729` appeared ad hoc in production 2026-07-29 (77-row full copy of point_valuations, including superseded More Rewards values and the same-day moi rows), no creating migration, no write_audit record, not the verification engine; secured deny-all by that migration after advisor lint 0013; redundant with point_valuations temporal versioning. COMMENT applied with that origin, "Retained; drop only on Mike's explicit instruction." Applied via `execute_sql` deliberately, not a migration — a migration referencing this prod-only orphan would break `supabase db reset` on fresh databases (the exact guard problem 20260729205344 documents). write_audit `9487dc68-dfa2-4906-b089-d718a85c8a90`. RLS-no-policy INFO lints on `*_snapshot_*`/`*_night_*`: deny-all by design; no policies added.

Note on the audit mechanism: `verify.write_audit.run_id` is NOT NULL with an FK to `verify.runs`, so one runs row was created for this dispatch (`a261a243…`, runtime `cowork`, status `complete`) — the same pattern every prior gated cowork session used. This is the sole verify-schema write beyond the two audit rows.

## Phase D — docs (local commits, unpushed)

- D1 `26b14ae` (CardCoachv2): DELTAS_INDEX provenance note incl. the Fido refinement.
- D2: not triggered (I2 gates); engine docs untouched.
- D3 `935637f` (cardcoach-docs): `git mv ALEX_HANDOFF_2026-08-11.md → DB_ENGINE_WORKLIST_2026-08-11.md` (history preserved) + per-item status ledger appended.
- D4 `552e611` (cardcoach-docs): WORKING_NOTES worklist run entry + handoff reference updated to the renamed file.
- Disclosure: the first D4 commit attempt (`97ff118`) accidentally included your uncommitted #23/#24 WIP plus a duplicated sweep entry — a pathspec-commit footgun (`git commit -- <path>` commits worktree content, and the worktree had been mutated for WIP restoration). It was corrected within a minute via `git reset --mixed` of that just-made, never-pushed commit and an index-based recommit. Final state verified: HEAD carries only the intended edit; your WIP sits uncommitted in the worktree, byte-identical (22 insertions, zero deletions vs HEAD). `97ff118` survives only in the local reflog.
- Known stale pointer (recorded, not acted on — out of D3's scope): CardCoachv2's APPLY_CHECKLIST stop-note still says "See ALEX_HANDOFF_2026-08-11.md"; the renamed file's header notes its former name, so the trail resolves. One-line fix available next docs pass.

## Mike-manual checklist

1. D-A, D-D: answer when ready (options above); D-B: Supabase dashboard → Authentication → Providers → Email/Password → enable leaked-password protection.
2. Revoke the GitHub PAT from the fix run if you have not already — it was still valid at this run's preflight.
3. Push docs when ready: cardcoach-docs is now 12 commits ahead of origin (your 7 + 5 from the two runs); CardCoachv2 has 8 local commits (7 sweep-run + `26b14ae`).
4. Repo debris: `rm -rf .git/stale-sweepfix-locks` in both `~/dev/cardcoach-docs` and `~/dev/CardCoachv2` (grew during this run; inert).
5. Advisor WARNs out of this dispatch's scope, recorded: 6 `function_search_path_mutable` functions (pre-existing).

## Decisions resolved — Mike, 2026-08-11 (post-run addendum)

**D-A: leave ON, with recommendation — executed.** The authed-path gate was closed at the strongest level available without fabricating a user session: (1) the deployed `recommend-here-v2` v19 bundle contains the flag read, `loadCanonicalOffers`, and `solveOfferStack` with no `includeOffers` opt-out anywhere (the only assignments are the shared signature, the `?? true` default, and the `if (includeOffers)` branch); (2) `recommend-card-v2` v19 same shared path; (3) flag confirmed still ON; (4) last-24h edge logs show real production traffic — multiple 200s on both v2 endpoints in ordinary app journeys (search-places → resolve-place → recommend → record-transaction). A synthetic end-to-end call was not possible: both endpoints derive the wallet from an authenticated user session (`no_wallet` guard), and no test user was created on principle. Engine docs corrected, dated: HOW_THE_ENGINE_WORKS.md — 4 repeated sentences + the roadmap line (`624e73b`); PIPELINE_AND_DECISIONS.md — the 2026-07 decision line, with a dated supersession marker preserving the register trail (`b31f651`). Zero "not wired" claims remain. Last-mile item for Mike: one TestFlight session at an eligible merchant (Canadian Tire family store with an RBC card, per offer `b0ff0008`) showing a non-empty applied-offer or linkage surface.

**D-D: accept absence — recorded.** Both Fido delta files marked `not-applicable — card never loaded post-repair (D-D, 2026-08-11)` in DELTAS_INDEX, provenance note updated (`34deeeb`). No insert; the card stays out of the catalog.

**D-B: approved — one click remains with Mike.** The toggle is dashboard-only (no connector or API path from this session, and Safari is read-only to me): Supabase dashboard → Authentication → Providers → Email/Password → enable leaked-password protection. The advisor WARN clears on the next run after that.

Resolution commits: `624e73b` `b31f651` `96ad915` `1d3b65e` (cardcoach-docs) · `34deeeb` (CardCoachv2). WORKING_NOTES and the worklist ledger both carry the resolutions; your #23/#24 WIP remains uncommitted and intact (re-verified: 22-insertion diff, zero deletions).

## CHAT SYNC

- Files changed: `DB_ENGINE_WORKLIST_2026-08-11.md` (renamed + ledger + resolutions), `WORKING_NOTES.md`, `DELTAS_INDEX.md`, `HOW_THE_ENGINE_WORKS.md`, `PIPELINE_AND_DECISIONS.md`.
- Commits: `935637f`, `552e611`, `624e73b`, `b31f651`, `96ad915`, `1d3b65e` (cardcoach-docs) · `26b14ae`, `34deeeb` (CardCoachv2). DB: migration `harden_trigger_function_execute` · COMMENT on `point_valuations_snapshot_20260729` · verify.runs `a261a243` · write_audit `728310dc`, `9487dc68`.
- Project sync required: Y — WORKING_NOTES, DELTAS_INDEX, the worklist file, and both engine docs changed; sync canonical docs and open a fresh Project chat for the updated index.
