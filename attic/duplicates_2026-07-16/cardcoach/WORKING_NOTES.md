# CardCoach Working Notes

**The only file that churns.** What's unresolved, who owns it, what unblocks it, what's
next. Update freely. When an item closes, **delete it** — closed items don't belong here.
Settled decisions move to `PIPELINE_AND_DECISIONS.md`; they don't live here.

Last updated: 2026-06-10 · Owner: Mike

> For a future session: this is where you look to find what needs doing next. Don't
> re-propose items already listed here unless you have new information.

---

## #2 — Apply-delta helper script

- **Status:** built, pending dry-run validation
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** validate against the real Scotia Momentum delta. The converter is
  `Reverify Script/stage3_delta_to_sql.py` (synthetic test + golden file in
  `Reverify Script/tests/`); it emits one file per card, dated run folder,
  `YYYY-MM-DD__issuer-slug__card-slug.sql`, `BEGIN;`/`COMMIT;` wrap, comment header
  (source URLs, changed fields, verification date), and refuses V1 tables, invalid
  `scoring_status`/`rate_unit`, and rows missing source metadata.
- **Context:** Stage 3 emits structured JSON; this converter is the last mile to Alex's
  spec. Hand-write the first Scotia file to validate the format before automating.
- **Bug (found in the 2026-06-10 Scotia dry run):** validation scoping bug: converter
  rejects per-litre rate_unit inside unsupported_benefits, a section that never becomes
  SQL — scope refusals to SQL-emitting sections; rate_unit_raw workaround in use.

---

## Data coverage gaps

### #3 — French-language URL pass (324 blank FR-CA rows)
- **Status:** not started
- **Owner:** Mike
- **Blocker:** None — scope only. Deferred to post-V1 per the 2026-04-22 decision.
- **Next action:** When V1 stabilizes, run a dedicated French research session like the April 2026 English enrichment. ~3 hours focused.
- **Context:** Quebec is a distinct launch channel, not a translation target. FR pages diverge from EN (Desjardins Bonidollars classification, National Bank product tier names). Needs its own review.
- **Watch:** reconcile the "French in V1" wording with the Operating Model — French is a V1 *market* commitment; French *source reverification* is the deferred piece. Say it once, in one place.

### #5 — Welcome bonus data pipeline
- **Status:** not started
- **Owner:** Mike
- **Blocker:** None — flagged as a "significant gap" in data governance.
- **Next action:** Decide whether welcome bonuses get their own table + reverification flow, or a column on `card_products`. Likely a separate table given the time-bounded, offer-specific nature.
- **Context:** Welcome bonuses drive applications, and therefore affiliate revenue. Currently not in the verified dataset at all. Separate from the monthly loop but shares source material.

---

## Point valuation (CPP) verification

### #6 — Air Miles CPP → BMO Blue Rewards (verified — pipeline pass pending)
- **Status:** verified — pipeline pass pending
- **Owner:** Mike + Claude
- **Blocker:** None.
- **Next action:** (1) enter the Blue Rewards `point_programs` row (program, 0.667,
  fixed-value in-store/eGift baseline, sources + 2026-06-10, confidence high) and retire
  the Air Miles entry on the dataset's next update; (2) run the BMO kit
  (`Reverify Script/bmo_bluerewards_kit/`) through Stage 2/3 locally; (3) Stage-1 the
  two new Blue Rewards cards — URL enrichment is local/chat work (issuer sites blocked
  from CoWork).
- **Context:** Program launched: AIR MILES converted to BMO Blue Rewards June 1, 2026
  (official launch June 2; baseline redemption 1,500 Blue Points = $10 → 0.667¢/pt
  in-store/eGift; Miles converted ~16 Blue Points per Mile at equivalent value — see
  decisions log 2026-06-10). CPP baseline 0.667¢ verified against BMO newsroom (June 2,
  2026 release) and bmo.com T&C (which defers full rates to bluerewards.ca/value);
  travel redemptions now Expedia-powered, rates not yet Tier-1 pinned — 0.667 is the
  defensible floor.

### #7 — More Rewards CPP (low confidence)
- **Status:** verified floor 0.15¢/pt (10,000 pts = $15 grocery, morerewards.ca, 2026-06-10); full-catalog CPP not Tier-1 verifiable. Treat 0.15 as the conservative floor in point_programs; confidence: medium.
- **Owner:** Mike + Claude
- **Blocker:** None.
- **Next action:** enter the floor value into the point_programs dataset on its next update; revisit only if the official catalog publishes richer redemption tables.
- **Context:** More Rewards (Pattison Food Group / Save-On-Foods). Flagged low-confidence in the `point_programs` dataset. Not blocking, but tighten before V1 launch.

---

## Material issuer changes to watch

### #8 — Rogers rewards — cohort-differentiated rates
- **Status:** decided — data task remains
- **Owner:** Mike (data)
- **Blocker:** None.
- **Next action:** reverify Rogers/Fido cards against Feb 26 2026 new-cardholder terms in the normal pipeline loop; include the disclosure line in the delta notes.
- **Context:** Rogers restructured twice (Mar 6 2025, Feb 26 2026). Three cohorts now see different rates on the same product. Decided 2026-06-10 (see decisions log): V1 represents new-cardholder rates as of the Feb 26 2026 restructure only, with a disclosure line on affected cards.
  The four Rogers/Fido benefits_guide rows still marked uncertain resolve in this same pass.

### #9 — PC Financial post-EQB acquisition
- **Status:** dated — close confirmed
- **Owner:** Mike
- **Blocker:** None — timeline now known.
- **Next action:** reverify all PC Financial cards against post-close agreement
  revisions, starting the first pipeline run after July 1; expect the June 2025 CMA in
  the registry to be superseded.
- **Context:** EQB acquisition announced Dec 2025, Competition Bureau cleared Mar 6
  2026; final Ministerial approval received May 5, 2026; EQB confirmed expected close
  **July 1, 2026** — same day as the CardCoach launch target. EQB becomes exclusive
  financial partner of PC Optimum. Expect cardholder agreement updates around close.

---

## Infrastructure / tooling

### #10 — Per-litre `rate_unit` enum extension
- **Status:** blocked
- **Owner:** Alex (engineering)
- **Blocker:** Engineering backlog priority.
- **Next action:** Mike raises with Alex when other blockers clear. Not urgent while the Unsupported_Benefits pattern holds the data.
- **Context:** Canadian Tire (cents/litre) and PC Financial (points/litre) gas rewards are captured but parked. Unblocks when the enum gains `cents_per_litre` and `points_per_litre`. Welcome-bonus schema work (2026-06-10) surfaced a second enum gap to bundle into the same Alex request: cap_period. Raise per-litre + cap_period together.

---

## Revenue / trust (shares stakeholders with the pipeline, not blocked by it)

### #11 — Legal review of affiliate disclosure copy (EN + FR)
**SHELVED by Mike 2026-06-10 — do not surface or re-propose until Mike reopens.**
- **Status:** not started
- **Owner:** Mike
- **Blocker:** Needs external Canadian financial-services-literate legal counsel.
- **Next action:** Identify and engage counsel for bilingual disclosure review.
- **Context:** This is the highest-leverage unblocking decision in the broader revenue work — and it's been cold since well before this cleanup. Affiliate revenue is the primary V1 path and it can't activate without this. Listed here because it shares the pipeline's trust posture.

### #12 — External publication of the commission-blind integrity policy
**SHELVED by Mike 2026-06-10 — do not surface or re-propose until Mike reopens.**
- **Status:** not started
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** Decide whether to publish the commission-blind architecture externally (blog, about page, partner docs). Marketing/brand call, not a data call.
- **Context:** The architecture is defensible and trust-building. Parked here because it's tied to this pipeline's credibility.

---

## Live-site compliance (flagged, needs legal before copy changes)

### #13 — Resolve hold-back claims currently live on the site
**SHELVED by Mike 2026-06-10 — do not surface or re-propose until Mike reopens.**
- **Status:** not started
- **Owner:** Mike
- **Blocker:** Likely needs the same legal review as #11.
- **Next action:** Reconcile what's published against the "holding back until cleared" list — "we don't sell your data" wording, any fabricated testimonial, the draft legal note on the Terms page, and any FAQ marketing a deferred Pro tier as imminent.
- **Context:** Surfaced in a prior audit. Grouped here so it isn't lost; specifics should be confirmed against the live site before editing, and most changes wait on legal.

---

*Add new open items above this line. Close = delete. Settled = move to the decisions log.*
