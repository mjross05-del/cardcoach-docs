# PROMPT — four verify-engine rulings Mike owes, with the evidence already gathered

Authored by the 2026-08-25 Code session that reviewed the Tangerine registry patch proposal.
**This is a decision prompt, not an execution prompt.** Four questions need Mike's ruling; none
of them can be settled from the code or the docs, and each has been blocked long enough to
recur. The investigation is done — do not redo it. Your job is to put each question to Mike
with its evidence, take the ruling, and apply the consequence.

Work through them in order. #1 is the one that is quietly costing the most.

## State when this prompt was written (verify, don't trust)

- `~/dev/cardcoach-docs` = **a5668d6**, `WORKING_NOTES.md` **uncommitted** — it holds items
  **#29, #30, #31** written by that session, plus an addition to **#27**. Read those four
  items first; this prompt is the decision layer on top of them and does not repeat their
  detail.
- `~/dev/CardCoachv2` = **f3b9134**, branch `feat/pro-tier-and-statement-import`. Ten
  uncommitted files under `card_coach_business_docs/` from the same session (Stage 2
  retirement tombstones + `RUNBOOK_verify_batch.md` v1.4 + a new
  `01_CORE/data/card_sources_seed_enriched.README.md`). The tree is **also** dirty with other
  lanes' work — stage explicit paths only, never `git add -A`.
- Supabase `card_coach_advanced` (`hrzpznlpmxxrbtwskacu`). Source run for the Tangerine
  material: **`d0028b40-170e-4905-aab5-92b255e4c792`** (2026-08-25, 18 facts, 17 confirmed,
  1 fail-closed).
- Live counts at authoring time — re-run before quoting to Mike:

```bash
psql_or_mcp <<'SQL'
select (select count(*) from card_products where is_active) as active_cards,
       (select count(*) from card_products where is_active and fx_fee_percent is null) as fx_null_cards,
       (select count(*) from earn_rates where condition_type='mcc_defined'
          and (mcc_includes is null or cardinality(mcc_includes)=0)) as empty_mcc_rows;
SQL
```

Expect **148 / 41 / 76**. If `fx_null_cards` has moved, decision #1 changed size — say so.

---

## Decision 1 — Are robots-disallowed issuer documents usable as evidence?

**WORKING_NOTES #31.** This is the one to lead with.

### What Mike needs to know

Some facts have exactly one public issuer-controlled statement, and it sits behind a
robots.txt-disallowed path. The engine fails closed, correctly, and then re-derives the same
dead end every week. Two confirmed instances, found independently:

- **Tangerine World Elite `fx_fee_percent`** — 4 consecutive fail-closed runs. The `wec_fee`
  widget states "Foreign currency conversion 2.50%", but its only URL 302s into `/en/static`,
  which robots.txt disallows. The requested path is allowed; the destination is not.
  **The document search is exhausted** — on 2026-08-25 six issuer PDFs were downloaded and
  text-searched, including the cardholder agreement effective April 22 2026. None states a
  rate. Both cardholder agreements say only that the fee "is disclosed in your Disclosure
  Statement", an account-specific document Tangerine does not publish. **There is no better
  document to find.** Do not let anyone re-open this by suggesting another PDF.
- **Neo Financial's entire legal corpus** — every `legal.neo.cc/*` link 302s to
  `static.production.neofinancial.com`, whose robots.txt is `Disallow: /`. Cardholder
  agreement, both disclosure/fee schedules, rewards policy, MCC schedule. Its agreement and
  rewards policy are dated June 2025 while its disclosure is 2026-06-01, so newer versions may
  exist — and there is no compliant way to check.

### Size this honestly when you present it

**41 of 148 active cards have `fx_fee_percent` NULL** — Amex 13, TD 12, MBNA 6, RBC 6, Scotia
2, BMO 1, Tangerine 1. Across history, 198 fail-closed `fx_fee_percent` checks over 72 cards.

**Do not tell Mike the ruling fixes 41 cards.** Only Tangerine's is confirmed robots-blocked;
the other 40 have not been diagnosed and Amex and TD almost certainly fail for unrelated
reasons. The honest framing: the ruling closes Tangerine outright, unblocks Neo currency
checks, and sets the precedent for whichever of the remaining 40 turn out to share the shape.
Sizing the rest is separate work — see Follow-up F4.

### The options

- **(a) Usable.** Robots governs crawling; a single fetch of a linked legal document a customer
  is expected to read is not crawling. → Tangerine WE `fx_fee_percent` closes at 2.50
  immediately (the artifact is already captured and auditable), Neo becomes checkable.
- **(b) Not usable.** The current stance, and defensible — following a redirect into a
  disallowed prefix *is* fetching a disallowed URL. → Both close only by founder manual
  capture, and that must become **a scheduled lane with an owner**, not an escalation note
  that recurs weekly. That lane does not exist today; if Mike picks (b), designing it is part
  of the ruling, not a follow-up.

### After the ruling

- Record it as a dated decision in `PIPELINE_AND_DECISIONS.md` — **append at the end, below
  the marker** (PROJECT_RULES rule 10d). It is a new decision, not a recovery; never mid-log.
- Add the rule to `RUNBOOK_verify_batch.md` §3.6, which currently says only to evaluate
  robots against the final URL. It does not yet say what to do when that check fails.
- Update `verify.parking` id `396e93c4-a9de-4f0d-849a-50dc3ea57dd9` (topic
  `source_access_policy`) with the ruling, and clear or re-scope it.
- If (a): the Tangerine write goes through the **gated** path per `RUNBOOK_gated_apply.md`
  with `verify.write_audit` — a ruling is not a licence to auto-write a money fact.
- Close #31.

---

## Decision 2 — How are MCC brand-code blocks represented?

**WORKING_NOTES #27**, plus the addition at the end of it.

### What Mike needs to know

Both Tangerine Money-Back cards carry `hotels_motels` `mcc_includes = {7011}`. The issuer's
own program terms §7 read "Hotels-Motels … (MCC 7011, 3500-3828)" — the hotel-brand block is
unmodelled. **This was deliberately not written**, because it is a modelling decision:

- No `earn_rates` row anywhere uses the 3500-3828 block. Enumerating 329 integers would be the
  first of its kind.
- The existing convention for brand blocks is **representative codes, not enumeration** —
  `mcc_category_mappings` maps `travel` to MCC 3000 "Airlines" (head of the 3000-3299 airline
  brand block) plus 3009 "Air Canada" specifically. Five rows, not three hundred.
- It would not price anyway: `hotels_motels` is one of #27's unmapped categories, so the
  assumption side has no MCCs to intersect regardless of what the row holds.

The broader item has grown: **76 `mcc_defined` rows now have an empty MCC list**, up from the
52 found 2026-08-16. CIBC Adapta alone carries 11 empty rows per card across three cards.
Every one is live-suppressed on a scoreable card — the card silently earns base everywhere.

### The options (these compose; it is not either/or)

- **Brand blocks:** enumerate the range · adopt a head-code convention like `travel` already
  uses · add a range representation to the schema.
- **The 76 empty rows:** backfill from `mcc_category_mappings` per the
  `DB_MCC_SWEEP_WORKLIST_2026-08-16.md` proposals · **or** the engine policy alternative
  already written up in #27 — admit an `mcc_defined` row with an empty list when the
  assumption's category matches the row's category (fail-open on category agreement). One
  engine change fixes all 76 and trades away MCC precision. The fail-closed stance was chosen
  deliberately, so taking this needs its own decision entry.

### After the ruling

Backfill runs through the verify/apply loop under rule 9, not as a bulk UPDATE. If the policy
alternative is taken, it needs a `PIPELINE_AND_DECISIONS.md` entry recording what precision was
traded away and why.

---

## Decision 3 — Does per-source cadence earn a home?

**WORKING_NOTES #29.** Lowest stakes of the four. Do not let it eat the session.

The retired registry carried a `fetch_cadence` column — monthly for product pages, quarterly
for Tier-1 PDFs. The verify engine rotates **per issuer**, weekly. Nothing carries the
per-source-type tolerance forward, so every fact inherits its issuer's slot regardless of how
volatile its source is.

Today that means **over**-checking the quarterly PDFs, not under-checking the pages — which is
the safe direction. The real cost is that we cannot answer "when does this fact expire?"
except by issuer.

- **(a)** Give it a column — an expected revision interval on the evidence or fact-check row.
- **(b)** Declare per-issuer weekly sufficient and let the concept die with the registry.

Either is defensible. **(b) is the honest default** — do not build the column unless Mike
wants the per-fact expiry answer for a reason beyond tidiness. Record whichever, close #29.

---

## Decision 4 — Should stored source URLs carry a drift signal?

**WORKING_NOTES #30(b).** The (a) half is already done — `RUNBOOK_verify_batch.md` v1.4.

### What Mike needs to know

`verify.issuer_notes.doc_locations` stores a URL and nothing else. On 2026-08-25 three of
Tangerine's entries pointed at superseded revisions, **all returning 200** — the Money-Back
program terms were the September 2024 revision, predating the 2025-10-25 amendment that added
three 2% categories. Issuers leave old PDF revisions served indefinitely, so the usual failure
signal never fires. `earn_rates` was already correct and nothing broke, but the next Tangerine
run would have reconciled against year-old terms.

All 37 URLs across the 7 issuers that record any were swept. One dead link (RBC
`documentation_hub`, 404, now marked `DEAD 2026-08-25`), four aged documents flagged, no other
breakage. **That sweep was manual and does not scale to weekly.**

- **(a)** Record a revision date or sha256 alongside each stored URL, so a run can *detect*
  that the file changed under a stable URL, or that a stored URL is no longer the one the
  issuer's index links.
- **(b)** Rely on the v1.4 RUNBOOK discipline — re-validate against the issuer's index before
  citing — and accept that it depends on each run actually doing it.

The argument for (a): v1.4 is a procedural control on an agent's diligence; a sha256 is a
mechanical one. The argument for (b): it is one more field to keep truthful, and a stale
sha256 is its own kind of lie.

---

## Follow-ups that need no ruling

Do these regardless, or file them. None is blocked on Mike.

- **F1 — RBC documentation hub.** `/credit-cards/documentation.html` is 404 and so is
  `/credit-cards/agreements-and-documents.html`. The `/credit-cards/documentation/pdf/` prefix
  beneath it still serves files (`suncor-terms-personal.pdf` confirmed 200), so only the index
  page is gone. Next RBC run navigates fresh from `https://www.rbcroyalbank.com/credit-cards/`
  (200) and replaces the value. **Do not guess a replacement URL** — that is the exact habit
  that produced the Tangerine drift.
- **F2 — NationalBank `fx_information_box_pdf`.** Recorded as the EN FX information box, but
  the PDF's source file is `1689_PPO_form_27972_FR_v2.indd` — an **FR** artifact. Its
  `doc_locations` note also says form 27972-012 dated 2026-02-10 while the file's ModDate is
  2026-03-13. Worth one run's attention; may be nothing.
- **F3 — aged documents, currency unconfirmed.** Canadian Tire `we_summary_2022_linked_live`
  (created 2022-06-27), NationalBank `rewards_plan_rules` (2025-02-18), RBC
  `petro_terms_personal` (2025-01-08). Old is not automatically wrong — check each against its
  issuer's index, do not replace on age alone.
- **F4 — size the real FX gap.** 41 active cards have `fx_fee_percent` NULL, concentrated in
  Amex (13) and TD (12). Only Tangerine's cause is diagnosed. Find out whether the rest are
  robots-blocked, genuinely unpublished, or never attempted, before anyone treats decision #1
  as the fix.

## Guardrails

- **Do not backfill `card_sources_seed_enriched.csv`.** It was retired 2026-08-01 and frozen
  2026-08-25; WORKING_NOTES #4 closed registry-row gap tracking. A patch proposing exactly this
  was reviewed and declined on 2026-08-25 — the reasoning is in
  `01_CORE/data/card_sources_seed_enriched.README.md`. If a new proposal arrives against that
  file, read the README before acting on it.
- **Do not resolve any issuer document by editing a filename pattern.** Date suffixes and
  version numbers produce a live URL of the wrong vintage. Re-read the issuer's index.
- **A ruling is not a write authorisation.** Money facts go through `RUNBOOK_gated_apply.md`
  with `verify.write_audit`, whatever Mike decides.
- **`PIPELINE_AND_DECISIONS.md` is append-only** for decisions (PROJECT_RULES rule 10). New
  rulings append at the end, below the marker.

## Report when done

Which of the four were ruled and how, where each ruling was recorded, which follow-ups were
executed versus filed, and anything Mike deferred — deferred is a fine outcome, silently
skipped is not. Then delete the closed items from `WORKING_NOTES.md` (close = delete) and move
the settled reasoning to `PIPELINE_AND_DECISIONS.md`.
