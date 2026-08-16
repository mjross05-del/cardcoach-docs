# Verify Batch — Unlogged Active Cards — Report

Run `98d0bc59-a219-4b00-abf6-f3a6c8579507` · 2026-08-11 · cowork · RUNBOOK_verify_batch v1.0
Coverage: active cards with no verification history **33 → 26** (live recount at start; the sweep's 24 was stale). Writes by class: auto 0 · gated pending 1 · public-schema writes 0. Parked: 0. Chrome-lane queued: 11 (BMO). Dedupe-deferred: 15.
Every one of the 33 is now logged (7), chrome-queued (11), or dedupe-deferred with a named covering run (15). Zero unverified facts, zero flags, no STOP conditions hit.

## Ledger

| Card | Facts checked | Outcome | Class |
|---|---|---|---|
| Desjardins Bonus Visa (scoreable+open, priority) | fee, earn:base, earn:categories, cap, status, name | 5 confirmed + 1 changed (missing cap) | gated ×1 |
| Desjardins Flexi Visa | fee, status, earn:base | 3 confirmed; 6b: 0-earn by design, permanently load_only | — |
| NB Syncro Mastercard | fee, status, earn:base, name | 4 confirmed ($35 dual-pass via information-box PDF); 6b permanent load_only | — |
| RBC Rewards+ Visa (closed) | status, name | 2 confirmed — commented-out nav maps it to ION (closure corroboration) | — |
| Signature RBC Rewards Visa (closed) | status, name | 2 confirmed — nav comment maps it to ION+ | — |
| RBC Rewards Visa Preferred (closed) | status, name | 2 confirmed — fully absent from served lineup markup | — |
| TD Business Select Rate Visa | fee, status, earn:base, name | 4 confirmed ($0 base config; optional $49-for-8.99% election noted); 6b permanent load_only | — |

23 facts · 22 confirmed · 1 changed-gated. Money facts dual-confirmed (two artifacts or two mechanical extraction transforms; grep-guard literals verified against artifacts via the documented strip/pdftotext transforms). Closed-legacy money facts not publicly published — per §10 v1.1 that is a sourcing gap, not a wall; noted in issuer_notes, no unverified spam recorded.

## Gated queue (one-tap ready, via RUNBOOK_gated_apply)

1. fact_check `59fc3176-4f9a-497b-84c4-4f0a81852010` — Desjardins Bonus Visa, missing annual cap. Issuer: "After your first $3,600 in annual purchases in the Restaurants and Pre-authorized payments categories, you earn BONUSDOLLARS at the rate of the All other purchases category." DB has zero card_caps rows. Proposed SQL (two rows, [CAP_POOL] combined-pool convention):
```sql
INSERT INTO card_caps (card_id, category_id, condition, cap_basis, cap_value, cap_unit, cap_period, reset_rule, valid_from) VALUES
('ca_desjardins_bonus_standard_visa','dining','[CAP_POOL] combined with recurring_bills','spend',3600,'cad','annual','calendar year',CURRENT_DATE),
('ca_desjardins_bonus_standard_visa','recurring_bills','[CAP_POOL] combined with dining','spend',3600,'cad','annual','calendar year',CURRENT_DATE);
```

## Chrome-lane queue — BMO (11 cards, weekly Mike-present session)

Hub: `https://www.bmo.com/main/personal/credit-cards/all-cards/` (reachable via the extension per issuer_notes 2026-08-07). Facts needed per card: annual fee, FX, base earn + category earn rows, caps, status; plus the 6c lineup coverage diff. Cards: Blue Rewards WE · Blue Rewards MC · AIR MILES World (closed — status baseline only) · Ascend WE · CashBack WE · CashBack World · CashBack MC · eclipse rise Visa · eclipse Visa Infinite Privilege · eclipse Visa Infinite · BMO Rewards MC (load_only open — 6b earn backfill candidate). Queued ≠ parked.

## Dedupe-deferred (rule v1.2; still unlogged, next rotation slot)

- CIBC ×7 + MBNA + Scotiabank ×7 — covered by run `9a4de2ba` (complete 15:41Z, lineup-delta batch). CIBC unlogged: Aventura Gold, Aventura VIP, Classic, Costco World MC, Dividend Platinum, Select, U.S. Dollar Aventura Gold. Scotiabank unlogged: 5 student cards + 2 GM (closed).
- AmexCanada ×1 (Business Edge, load_only+closed) — covered by run `f63bfbd1` (Tue solo, 10:09Z).

## Notes and observations

- Syncro's missing history explained: it entered the DB via a gated new_card apply on 2026-08-08 (run 738eb8b6) and was never post-verified — until this run.
- 6c: Desjardins lineup 8/8 both directions. NB lineup shows mycredit, MC1, Edition, Allure, ECHO Cashback, Escapade, Ovation Gold, PB1859 beyond the DB's 4 NB cards — precedent (08-08 run proposed only Syncro) treats dataset scope as curated, so this is flagged as a scope question for Mike rather than eight unsolicited full-row proposals. Deviation from 6c's letter, recorded deliberately.
- Pre-existing pending signals untouched: NB World MC closure_signal (2026-07-27) and the 9 lineup-delta proposals from run `9a4de2ba` remain in the gated queue.
- Transport learnings written to issuer_notes (Desjardins plain-HTTP full; NB fee channel = ppo_form summary PDF; RBC nav-comment closure pattern; TD business-card URL tree).
- Renderer was not needed (all four issuers served over plain HTTP); the sandbox playwright bootstrap footgun (background jobs die with the bash call) is noted for future runs.
- BLOG_OPERATIONS: untouched — no corrected fact appears in any published post (the one gated cap is additive, and no post cites Bonus Visa caps).
- Riders: R1 — SPEC_verification_engine stacking line corrected to the verified dated sentence (`23f1e10`, CardCoachv2 local); repo-wide grep found no other live stale phrasing (the worklist file's occurrence is a quoted historical record inside a resolved item, retained). R2 — FK observation appended to the worklist ledger (`16921ba`).

## Freshness after-state

`verify.v_card_freshness`: unlogged actives now 26 = BMO 11 + CIBC 7 + Scotiabank 7 + Amex 1 (exactly the queued/deferred sets). All 7 batch cards carry `last_verified_at` = today. Evidence: 10 artifacts uploaded to `verification-evidence` under `evidence_98d0bc59/` (4 Desjardins, 3 NationalBank, 1 RBC, 2 TDBank), every fact_check evidence-linked. write_audit: none required (zero public-schema writes).

## CHAT SYNC

- Files changed: `SPEC_verification_engine_2026-07-27.md` (CardCoachv2, local — push blocked by token scope, 10 commits now queued there) · `DB_ENGINE_WORKLIST_2026-08-11.md`, `WORKING_NOTES.md` (cardcoach-docs, pushed).
- Commits: `23f1e10` (CardCoachv2) · `16921ba`, `970a73b` (cardcoach-docs; origin verified at `970a73b`).
- Project sync required: Y — WORKING_NOTES, worklist ledger, and SPEC changed; sync canonical docs, then open a fresh Project chat.
- Action needed: gated approval ×1 (above) · BMO chrome-lane session · D-B toggle still open · CardCoachv2 push from your machine.
