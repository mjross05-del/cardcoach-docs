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
