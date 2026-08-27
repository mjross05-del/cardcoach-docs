# LANE — iOS/Android app discrepancies — taken over by the Cowork tie-disclosure session, 2026-08-16

Mike's instruction: take charge of this lane and push its items to their
next steps with the release. State reconstructed from WORKING_NOTES #338-339,
`DB_MCC_SWEEP_WORKLIST_2026-08-16.md`, and live probes run tonight. If the
original runtime's transcript holds items not listed here, paste them into
the Cowork session and this doc gets amended.

## Item 1 — 52 mcc_defined rows never price (the root of "different results")

**State:** worklist complete (reads only, 2026-08-16 14:40). 52 active rows /
12 cards live-suppressed: null/empty `mcc_includes` fails closed under the
`merchant_mcc_assumption` flag, so the card silently earns base everywhere —
the CIBC Aeroplan $1.33/$100-at-RCSS case. 42 rows are fillable now with
category-typical sets; 10 sit in unmapped categories (e_games, ev_charging,
hotels_motels, recurring_bills, transit_parking).

**Decision needed (Mike, explicitly reserved to you by the worklist):**
- **(a) Data backfill** — fill the 42 per the worklist after per-card source-
  clause checks in the verify lane (a card whose bonus is NARROWER than the
  category must get the narrow set, not the category set); then map the 5
  missing categories and fill the last 10. Precise, slower, rule-9 audited.
- **(b) Engine policy** — fail-open on category agreement when the row's
  list is empty. One change fixes all 52 at once, trades away MCC precision,
  and reverses a deliberately-chosen fail-closed stance; needs a decision
  entry.
- Recommendation from this session: **(a)**, batched per-issuer through the
  verify lane's dual-confirmation, because (b) silently converts every
  future data-entry omission into a pricing grant.

**Next step prepared:** on your word, this session drafts the per-issuer
delta files (rule 9: snapshot, expire-then-insert, guards) for the 42 into
`cardcoach-docs/deltas/`, gated on your per-batch approval — plus the
`mcc_category_mappings` proposals for the 5 unmapped categories.

## Item 2 — Android carousel showed 2 cards for a 3-card wallet (2026-08-16 09:04, mike@card.coach)

**Probed tonight, server side EXONERATED:**
- Stateless scorer, 3 scoreable inputs → 3 recommendations, dense ranks 1-3.
- Your wallet (mike@card.coach): all 3 cards are `scoring_status='scoreable'`
  (Momentum MC, CIBC Dividend VI, PC WE MC) — so the legitimate
  "skipped load-only" path cannot explain a 2-card carousel, and the
  response warning line would have said so anyway.

**Remaining suspects (client):** the AND-001 carousel fix (stale module-load
width + Android-ignored `contentOffset`, fixed 2026-08-07) may postdate the
build on your device, or `fetchFullRankings` failed mid-session and the
carousel kept a partial set (there IS a retry affordance; a silent partial
would be new). **Next step:** repro once on versionCode 4 (or the 1.0.3
build when it exists): Now screen, note carousel count vs wallet, and
whether `rankingsRetry` is showing. If it repros on 1.0.3 → ticket as
client render bug with the QA-010 device matrix row.

## Item 3 — PC Financial MC (standard) grocery row is a modeled no-op

10 pts/$ `merchant_list_only` grocery == its base rate. Not a platform
discrepancy — a data-verification item. **Next step:** carries to the verify
lane's next weekly batch (re-verify the real Loblaw-banner rate; issuer page
says grocery earns above base at Loblaw banners if true).

## How this lane rides the release

Items 1a/1b change SERVER pricing — no app build dependency; they ship
whenever decided + applied, and both platforms pick them up on the next
request (that is the point: the "discrepancy" was never iOS-vs-Android code,
it was data visibility both platforms shared). Item 2 is the only
app-build-coupled item and folds into the 1.0.3 device pass
(PLAN_release_push_1.0.3_2026-08-16.md).

---

## Amendments from the original runtime (2026-08-16, per the header's invitation)

Two items from the source transcript not yet carried above:

## Item 4 — Sibling-product card art is indistinguishable (RETHEME-COUPLED — time-sensitive)

The trigger for this whole lane: CardVisual generates artwork from the
ISSUER, so every CIBC card renders the same bronze gradient and every PC
Financial card the same black one — the only differentiator is the small
name text. Mike read "CIBC Aeroplan Visa" vs "CIBC Dividend Visa Infinite"
on two phones as *the same card with different numbers*; the founder fell
for it in his own app. **This is a design defect, and RETHEME-001 is the
exact right (and cheapest) moment to fix it:** if the Final Spec's card
treatment doesn't differentiate sibling products (variant accent, product-
family gradient, or a persistent product-name chip on the art), the trap
ships again in 1.0.3. Flag to whoever holds the retheme lane BEFORE the
retheme commit lands.

## Item 5 — recommend-here-v2 does not emit `conditionalNotApplied` (Slice 2)

The 1.0.3 client renders suppressed-bonus lines in the Why This Card receipt
(3440789), fed by recommend-card-v2 v21+. recommend-here-v2 still emits
nothing, so any surface built purely on here-v2 responses (carousel ranking
values) cannot disclose suppression. Port is small (same `earnRowPrices`
predicate, same additive optional field — pattern in `f1a7158`) and pairs
naturally with the v24/v23 dark deploy already staged in
`PROMPT_code_push_deploy_2026-08-16.md`. WORKING_NOTES #25 carries the
cross-link.
