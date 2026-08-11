# ALEX HANDOFF — 2026-08-11

Source: CardCoach Pre-Launch Full Sweep, run 2026-08-10 (executed 2026-08-11 01:41 UTC). Filed by the sweep-fix run, 2026-08-11. Everything below is DB/engine lane. Contents are the sweep's ALEX PACKET, verbatim where possible. Zero DB writes were made by the sweep or the fix run; all observations are read-only introspection of live `hrzpznlpmxxrbtwskacu`.

---

## 1. Dormant-delta drift (N3)

Live DB already holds the card-lane end-states. Applying the 18 files now: guarded `UPDATE`s no-op; **unguarded `INSERT`s duplicate rows**. Do not run as-is. Per-file posture:

- `2026-07-02/*` (BMO Blue Rewards ×4, PCF ×4, closures): end-states LIVE — inserts would duplicate `earn_rates`/`card_exclusions`.
- `2026-07-03/bmo point-programs`: `blue_rewards` program + valuation LIVE — re-insert would duplicate.
- `2026-07-04/rogers ×6`: red-world net-new card LIVE; **Fido closure NOT applied** (status NULL, see §2).
- `2026-08-04/rogers tiered-caps` (was date-gated): caps LIVE (`valid_from 2026-08-04`) — do not re-apply.

Reference `APPLY_CHECKLIST.md` (now carries a top-of-file stop-note, added 2026-08-11); treat the folder as an executed-then-filed record, not a pending queue. `DELTAS_INDEX.md` card-lane status column was reconciled 2026-08-11: 17 files marked `superseded-live (2026-08-10 sweep)`, the Fido closure file marked `not-applied — live state NULL (2026-08-10 sweep)`. Application history (who applied the end-states, when, via which mechanism) is unconfirmed — reconcile against migration history (72 migrations applied through 2026-08-02).

Evidence observed live: BMO Blue Rewards WE fee 150 and CashBack WE 139; `blue_rewards` point program + 3 valuations; `ca_rogers_red_world_mastercard` present; Rogers tiered caps live (Red $16k / World $26k / World Elite $61k, `valid_from 2026-08-04`); PCF fees 0; PCF World net-new present.

## 2. Fido (N5)

`ca_rogers_bank_fido_standard_mastercard.application_status = NULL`; the closure delta predicate (`WHERE application_status='limited'`) never matched. Deviates from the discontinued-card convention. Decide target state per the settled Rogers/Fido representation convention.

## 3. Stacking flag vs engine (N4)

`runtime_flags.loyalty_offer_stacking = true`, note "ACTIVATED 2026-08-02 by Mike"; migrations `data_018_loyalty_stacking_phase1/seed` + `data_019_member_earn_rates` applied. Canonical `HOW_THE_ENGINE_WORKS.md` and `PIPELINE_AND_DECISIONS.md` still state `solveOfferStack` "is not wired into the V2 production path." Sweep observation: a grocery-category call to `recommend-cards-stateless-v1` returned `appliedOffers: []` (no loyalty context present to trigger an offer), so production offer application could not be confirmed from the public tool. Confirm whether the live edge function actually applies `loyalty_stack` offers with the flag ON; if yes, correct the docs; if no, the flag is ahead of the engine. The docs stay unedited until this is answered.

## 4. Advisor items (N7)

- 3 anon-executable `SECURITY DEFINER` functions callable via `/rest/v1/rpc/…`: `handle_new_user`, `handle_user_email_updated`, `maintain_user_spend_snapshots`. They are trigger functions not meant for direct call; revoke `EXECUTE` from `anon`/`authenticated` or switch to `SECURITY INVOKER`.
- 7 `SECURITY DEFINER` views (the `export_*`/`v_active_*` read surface — intended public read, but the linter flags the definer bypass): review.
- Leaked-password protection disabled on Auth: enable.

## 5. Earn-rate predicate collisions (N9)

15 active earn-rate groups share (card, category, basis, condition_type); none identical, but the National Bank dining/grocery 0.6667 pairs warrant a double-count check.

## 6. Snapshot-table housekeeping

Snapshot/backup tables (`*_snapshot_*`, `*_night_*`) carry RLS-enabled-no-policy lints; `point_valuations_snapshot_20260729` is an unattributed drop-candidate. Housekeeping only.

---

# Status ledger — worklist run 2026-08-11 (appended by the run; file renamed from ALEX_HANDOFF_2026-08-11.md, lane model updated: no Alex lane)

verify.runs id `a261a243-d361-4f53-82d3-9b66f9318ed2` · run start 2026-08-11T13:54:31Z · zero card-fact writes.

| Item | Result | Evidence |
|---|---|---|
| 1 delta provenance | INVESTIGATED | End-states live-confirmed by value checks. No producing migration (74 checked) and no write_audit rows; rows' created_at cluster 2026-07-27–29; end-states present in repo catalog canon (`mobile_app_codebase/supabase/seed.sql`) — out-of-band catalog apply, same unattributed signature as the 20260729 snapshot. Full note in DELTAS_INDEX. |
| 2 Fido | BLOCKED → D-D | `ca_rogers_bank_fido_standard_mastercard` is absent from live card_products (114 rows; no fido match by id or name; absent from 2026-07-31 and 2026-08-02 snapshots; zero orphan earn_rates/caps/exclusions; no audit trail). The sweep's "application_status NULL" was a missing-row misread. No write. Options: insert-as-closed from the two delta files, or accept absence. |
| 3 stacking | INVESTIGATED | Shared scorer is flag-gated and wired: `loadReferenceScoringContext` reads `runtime_flags.loyalty_offer_stacking` when `includeOffers` (default true); `solveOfferStack` sits in the apply path; API-013/014 surfaces are flag-conditional. Authed v2 endpoints use the default (offers on); `recommend-cards-stateless-v1` passes `includeOffers: false` and has no loyalty input — its `appliedOffers` is [] by design, which explains the sweep probe. D2 doc-correction gates (scoped to a stateless live call) not met → docs untouched; D-A raised. |
| 4a function revokes | DONE | Migration `harden_trigger_function_execute`: EXECUTE revoked from PUBLIC/anon/authenticated on the 3 trigger functions; ACLs now postgres+service_role only; anon RPC probes 404 (PGRST202); advisor lints 0028/0029 cleared, no new ERRORs; engine probe unchanged (TD grocery 300¢). write_audit `728310dc-f5f8-48f1-8d5c-f0d4beba238c`. |
| 4b definer views | ACCEPTED BY DESIGN 2026-08-11 | 9 definer views (was 7 at sweep; +2 via the 2026-08-11 02:52 verify_apply_loop migrations, concurrent session). All read canonical catalog/offer/i18n data only; none reaches user data, auth, or verify schema. No conversion (security_invoker would break the RLS-withheld public read surface). |
| 4c leaked-password | D-B (manual) | Dashboard → Authentication → Providers → Email/Password → enable leaked-password protection. Not reachable via connector. |
| 5 earn-rate groups | NO DEFECT | Engine selects the single best priced row per category (never sums rows), so no additive double-count is possible. All 15 groups are condition-differentiated; the National Bank pairs are additionally unreachable (all 3 NB cards `load_only`, confirmed unrankable live). Observation: `other`-type condition variants (Amex 3x Amex-Travel-Online row, MBNA Prime rows) always price and win selection even when their condition cannot hold — overstatement class, not duplication; no row is surplus, nothing expired. |
| 6 snapshot | ATTRIBUTED | COMMENT applied to `point_valuations_snapshot_20260729` (ad-hoc prod copy 2026-07-29; no engine/migration/audit provenance; secured by 20260729205344). Retained; drop stays Mike-only. RLS-no-policy lints on `*_snapshot_*`/`*_night_*`: deny-all by design, no policies added. write_audit `9487dc68-dfa2-4906-b089-d718a85c8a90`. |

**Decisions resolved — Mike, 2026-08-11:** D-A: flag stays ON; the authed-path gate passed at deployed-artifact + live-traffic level (recommend-card-v2 / recommend-here-v2 v19 bundles carry the flag read and `solveOfferStack` with no `includeOffers` opt-out; both endpoints serving production 200s in the last 24h); engine docs corrected, dated. Remaining last-mile: one TestFlight session at an eligible merchant showing a non-empty applied-offer or linkage surface. D-D: accept absence — both Fido delta files marked not-applicable in DELTAS_INDEX; no insert; the card stays out of the catalog. D-B: approved; the toggle is dashboard-only and stays with Mike (Authentication → Providers → Email/Password → leaked-password protection).

**§2 closure — stacking dispatch, 2026-08-11:** production offer application PROVEN by live probe. recommend-card-v2 applied `b0ff0008` (3x CT Money, 1.2 percent) for a linked probe user at a Canadian Tire place: 120¢ on $100, final 270 = 100 base + 50 category + 120 offer — exactly the pre-registered expectation. Pre-link, the identical offer surfaced as a linkage nudge at potentialValueCents 120; post-link it applied and the nudge disappeared. Signup doubled as the W2 regression proof (handle_new_user fired with anon EXECUTE revoked; no email-confirm gate, so the guarded auth.users update was never needed). Probe user retained + marked: probe-20260811@cardcoach.ca, uid 7360beb1, rows user_cards `dda94724` + user_loyalty_links `c63c1df1`; audit row on run `a261a243`. The TestFlight last-mile item is closed. Fido public-claim check (§5 OFF path): site, published blog, and website copy carry no Fido claims (one internal business-doc mention only). Transcript: STACKING_CLOSURE_REPORT_2026-08-11.md.
