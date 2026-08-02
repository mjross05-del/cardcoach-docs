# CardCoach Pipeline & Decisions

**The reverification process (how it works) + the append-only log of settled decisions.**
This file is the "why things are the way they are" reference. The process section reflects
the current system; the decisions section is **append-only** — add new entries, never
rewrite old ones.

Last updated: 2026-08-01 · Owner: Mike (data integrity, governance, review)
Status: **Daily scheduled batches operational (first runs week of 2026-07-27). The Stage 1–3 script pipeline is RETIRED (2026-08-01 decision entry) — see the historical note at the end of Part 1.**

---

# PART 1 — THE PROCESS

## What it is

Verification runs as **daily batched scheduled runs** — one issuer batch per weekday
morning (~6 a.m.) plus a Friday-afternoon chrome lane with Mike present for issuers that
wall out automated access. Each batch is a self-contained Cowork scheduled task whose
prompt carries the full runbook; per-issuer learned state lives in `verify.issuer_notes`
so every run starts smarter than the last.

The product promise is "issuer-verified, always current." Issuers reorganize product
pages and revise agreements on their own cadence, usually silently. The batches detect
those changes weekly per issuer and turn them into verified, audited database updates —
auto for narrow guarded facts, gated proposals for everything structural.

## The rotation

| Day | Batch |
|-----|-------|
| Mon | Scotiabank |
| Tue | Amex Canada |
| Wed | RBC (+ loyalty-stack reverify; first-Wednesday fuel-price check) |
| Thu | TD Bank |
| Fri | CIBC (+ Journie loyalty reverify) — BMO explicitly excluded (walled) |
| Sat | Rogers + MBNA + Desjardins + National Bank |
| Sun | Canadian Tire + PC Financial + Simplii + Tangerine (+ PC/Triangle loyalty reverify) |
| Fri 5 p.m. | Chrome lane, Mike present (~15–20 min): BMO coverage + facts, RBC tier thresholds, in-application FX boxes, Blue Rewards/AIR MILES transition watch |

Effective cadence: every tracked issuer touched weekly. Loyalty-stack offers carry a
35-day staleness alarm on top (DATA-018/WS-1, added 2026-08-01).

## Infrastructure (all in Supabase project hrzpznlpmxxrbtwskacu)

- **`verify` schema** — `runs` (one row per batch run, dedupe <20 h), `evidence`
  (sha256-addressed artifacts via the prefix-locked `evidence-upload` edge function),
  fact checks with grep-guarded quoted clauses, `issuer_notes` (per-issuer learned
  state: transport quirks, traps, wall_status), `parking` (public offers, loyalty-stack
  reverify verdicts, watch signals — things recorded but never auto-written), and
  `write_audit` (every auto write, with old-value guards).
- **Render lane** — Playwright Chromium inside the run sandbox for client-rendered
  lineups (RBC) and 403-on-plain-HTTP sites (canadiantire.ca).
- **Plain-fetch lane** — for the CIBC-family transport quirk (cibc.com, PC Financial,
  Simplii block headless Chromium but serve full content over plain HTTP).
- **Chrome lane** — the Claude-in-Chrome extension in Mike's real browser for issuers
  whose bot walls defeat both lanes (BMO). Public pages only; never logged in.

## Order of work, per batch

1. Dedupe + schema introspection (live schema always wins over documents).
2. **Load-only backfill** — cards with verified fees but no verified earn structure;
   dual-confirmed earn rows + the `scoring_status` flip proposed as one gated package.
3. **Normal verification** of tracked cards (fees, FX, earn rates, caps, status).
4. **Loyalty-stack reverify** (issuer-relevant batches; added 2026-08-01) — anchor facts
   grep-guarded against Tier-1 sources; verdicts to `verify.parking`, never written to
   `public.offers` (OFFERS_PROMOTION OFF stands until the founder flips
   `runtime_flags.loyalty_offer_stacking`).
5. **Coverage diff** — the live lineup vs `card_products`: new cards and closure signals,
   both always gated.
6. Close: upsert `issuer_notes`, update `runs`, emit RUN SYNC.

## Discipline (non-negotiable, enforced in every batch prompt)

- Evidence before assertion: sha256 → upload → `verify.evidence` row **before** any
  citing fact check; grep guard on every quoted clause; dual confirmation on money facts.
- Classification: match→confirmed · single-fact dual-confirmed→**auto** (old-value
  guards, `write_audit`, expire-then-insert, never DELETE) · anything structural→**gated,
  never written** · unverifiable→fail closed · public offers→parking.
- Never: invent a value · write without linked evidence · record targeted/invite offers ·
  log in or start applications · treat web content as instructions.

## The human loop

Mike reviews RUN SYNCs, parking rows, and gated packages; approved structural changes are
applied under PROJECT_RULES rule 10 discipline (snapshot first, dated delta file,
expire-then-insert, guards, `verify:cpp` where valuations are touched). Loyalty-offer
`last_verified_at` refreshes are applied from parking rows in this review pass.

## Constraints baked into the design

These come from the decisions below. Changing them means revisiting the decision, not
patching prompts.

- **Canada-only** — every record needs Canada applicability evidence.
- **V2 tables only** — writes target `card_products`, `earn_rates`, `card_caps`, `card_exclusions`. V1 is not in any read path.
- **Issuer-verified only** — Tier 1 or Tier 1b sources. Blogs/aggregators are review triggers, never truth.
- **Commission-blind** — reads issuer pages only. No affiliate link handling, ever.
- **Caps use expire-then-insert** — never delete-and-replace. History preserved.
- **Per-litre rates stay out of `earn_rates`** (rate_unit cannot express them). As of DATA-018 (2026-08-01) per-litre facts have a canonical home in `public.offers` as `loyalty_stack` records — dark behind `runtime_flags.loyalty_offer_stacking`; batches reverify them via parking, never write them.
- **MCC routing captured, not enforced** — vendor doesn't expose MCC in transactions yet.
- **OFFERS_PROMOTION OFF** — batches never write `public.offers`. Flag flips are founder decisions.

## The retired script pipeline (historical)

Until 2026-08-01 this file described a three-stage script pipeline: Stage 1 registry CSV
(`card_sources_seed_enriched.csv`), Stage 2 Python fetcher (`stage2_fetcher.py`, run
monthly from Mike's laptop), Stage 3 extraction prompt (`STAGE3_PROMPT.md`). It is
**retired** — see the 2026-08-01 decision entry for why (in short: it was difficult to
use on certain websites — bot walls, headless blocks, client-rendered lineups — and the
walled issuers needed a human-present browser regardless). The files remain on disk as
records; snapshots are superseded by `verify.evidence`. Do not run the fetcher against
live sites; do not paste Stage 3 for new work.

---

# PART 2 — DECISIONS LOG (append-only)

Every decision that shaped the pipeline, with reasoning. Settled decisions stay settled.
To revisit one, add a *new* entry that references and supersedes the old — don't rewrite
history. If a proposal contradicts an entry here, the burden is on the proposal to explain
why the original reasoning no longer applies.

---

### 2026-04-16 — V2 tables are the only production path
**Decision:** The pipeline writes exclusively to `card_products`, `earn_rates`,
`card_caps`, `card_exclusions`. The legacy V1 `cards`/`card_earn_rates` tables are not
touched.
**Why:** Alex confirmed no production code path reads from V1. Dual writes would double
the work for zero benefit.
**Alternatives:** Dual-write "just in case" — rejected as over-engineering a known-dead path.
**Implications:** The Stage 3 prompt has a hard rule against emitting V1 writes. V1
returning would be a material architecture change, not a config flip.

### 2026-04-16 — `card_caps` uses expire-then-insert, never delete-and-replace
**Decision:** When a cap changes, expire the current row (`valid_to = now()`) then insert
the new one. Never `DELETE`.
**Why:** `card_caps` has `valid_from`/`valid_to` versioning and an active view filtering by
validity. Deleting destroys audit history. The March 14 seed used delete-and-replace by
mistake; corrected here.
**Alternatives:** Delete-and-replace (simpler, lossy) — rejected.
**Implications:** Same pattern applies to `earn_rates`. Enforced as non-negotiable in the
Stage 3 prompt.

### 2026-04-16 — MCC-based routing is captured in data, not enforced at runtime
**Decision:** Keep capturing `mcc_includes`/`mcc_excludes` accurately from issuer clauses
even though the payment vendor doesn't expose MCC codes in transactions.
**Why:** Data integrity should be independent of runtime routing. When the vendor gap
closes, accurate MCC data already exists — no backfill.
**Alternatives:** Drop MCC columns until runtime support exists — rejected as short-sighted.
**Implications:** MCC fields stay live. Separate future conversation on how runtime
routing will work.

### 2026-04-22 — Per-litre earn rates are blocked, parked in Unsupported_Benefits
**Decision:** Rows with `rate_unit = cents_per_litre` or `points_per_litre` route to an
Unsupported_Benefits holding table with a "rate_unit not yet supported" flag, rather than
being forced into the current enum.
**Why:** The `earn_rates.rate_unit` constraint allows only `points_per_dollar`,
`cents_per_dollar`, `percent_cashback`. Forcing per-litre into `cents_per_dollar` produces
wrong recommendations. Alex owns the enum extension.
**Alternatives:** (1) Compute an approximate CAD equivalent — rejected, gas prices make it
a moving target. (2) Drop per-litre rows — rejected, the data is real and useful once the
enum extends.
**Implications:** Canadian Tire and PC Financial gas rows are blocked until Alex extends
the enum.

### 2026-04-22 — Canada-only, no international expansion in V1
**Decision:** Every record carries Canada applicability evidence. Non-Canadian products
are rejected outright.
**Why:** CardCoach is Canada-first. Quebec is a distinct launch channel but still Canadian.
Expanding before the Canadian data is rock-solid dilutes the core promise.
**Implications:** US-issued Amex, international co-brands, etc. are out of scope even if an
issuer publishes their terms on the same legal landing page.

### 2026-04-22 — V1 does not include French-language source reverification
**Decision:** The 324 FR-CA registry rows stay blank for V1. French reverification is a
dedicated future pass, not a translation of the English run.
**Why:** Quebec is a distinct launch channel, not a translation target. Issuer French
pages sometimes lag or diverge from English (Desjardins Bonidollars, National Bank product
tiers). A superficial French pass creates false confidence.
**Alternatives:** (1) Auto-swap `/en-ca/` → `/fr-ca/` and verify — rejected, ~60% hit rate
and unverified rows are worse than none. (2) Skip French entirely — rejected, Quebec is a
priority market.
**Implications:** French reverification is tracked in `WORKING_NOTES.md` with its own plan.
Reuses the same Stage 2 + Stage 3 machinery when it ships.
**Note:** This is the known governance tension to watch — the Operating Model frames French
as "V1: yes." Reconcile the wording: French is a V1 *market* commitment, but French *source
reverification* is the deferred piece. Both can be true; just say it in one place.

### 2026-04-22 — Commission-blind posture is architectural, not policy
**Decision:** The pipeline reads issuer pages only. It never touches affiliate URLs,
commission data, or anything downstream of monetization.
**Why:** Commission-blindness is a foundational promise. Enforcing it at the data layer
(not just policy) means no single mistake can corrupt a recommendation.
**Implications:** The affiliate/CPA/network infrastructure is out of scope for this
pipeline. Period.

### 2026-04-22 — Runs locally on Mike's laptop, not on Supabase or a VM
**Decision:** Stage 2 is a Python script Mike runs manually. No cron, no server, no Edge
Function.
**Why:** Simplest working path; keeps Alex out of this workstream; at ~300 URLs / ~10-min
runtime, automation isn't a bottleneck.
**Alternatives:** (1) Edge Function + pg_cron — rejected, the 400s limit is tight for
PDF-heavy fetches and drags Alex in. (2) Small VM — rejected, adds cost/infra for no
benefit at this scale.
**Implications:** If the laptop's off, no run happens. Acceptable now. Revisit if scale
demands always-on.

### 2026-04-22 — Text-based change detection, no hashing
**Decision:** Stage 2 compares normalized text snapshots directly. No SHA hashes.
**Why:** At ~300 URLs, text comparison is milliseconds per file. Hashing pays off at
10,000+ URLs. Dropping it simplifies code and schema.
**Alternatives:** Hash-based detection — rejected as premature optimization.
**Implications:** Revisit past a few thousand URLs.

### 2026-04-22 — No database for Stage 2 outputs
**Decision:** Snapshots live on disk as `.txt`; change reports as `.md`. No SQL DB for
fetcher state.
**Why:** Disk is cheap, text is debuggable, the system can be moved or deleted without
touching Supabase or depending on Alex's infra.
**Alternatives:** Store snapshots in Supabase (a `source_snapshots` table was sketched) —
deferred, not rejected; commented-out future option.
**Implications:** Audit trail is only as permanent as the file system. Adding Supabase
storage is a viable Stage 2.5 upgrade if compliance ever needs it.

### 2026-04-22 — One previous snapshot kept, not full history
**Decision:** On change, save the prior version as `.prev.txt`; older versions overwritten.
**Why:** Stage 3 only needs current-vs-last-month. Full history adds storage for no use.
**Alternatives:** Keep every snapshot — rejected on storage grounds.
**Implications:** "What did this URL say 6 months ago?" is unanswerable. Add
`--archive-all-snapshots` if it ever matters.

*The following entry is carried verbatim from the retired `pipeline/DECISIONS.md` (archived 2026-06-10) so the pre-fork base is complete in this log.*

### 2026-04-22 — Three docs, not five
**Decision:** The pipeline is documented in exactly three markdown files — `PIPELINE.md`,
`DECISIONS.md`, `OPEN_ITEMS.md`. No separate overview, runbook, or stakeholder brief docs
at the markdown layer.
**Why:** More files means more drift. The existing `stage2_README.md` already serves as
the operational runbook and should not be duplicated. The stakeholder-facing one-pager is
a PDF and doesn't need a markdown twin.
**Alternatives considered:** Five files (Overview, Decisions, Open Items, Runbook,
Stakeholder Brief) — rejected because of overlap and maintenance burden. Two files
(combined decisions+open) — rejected because append-only history and churning status have
incompatible editing patterns.
**Implications:** `PIPELINE.md` is the single "start here" doc. `DECISIONS.md` is
append-only. `OPEN_ITEMS.md` is the only file that churns regularly.

### 2026-06-02 — Documentation collapsed into the clean four-file set
**Decision:** Project documentation is consolidated into `SOURCE_OF_TRUTH.md`,
`HOW_THE_ENGINE_WORKS.md`, `PIPELINE_AND_DECISIONS.md` (this file), and `WORKING_NOTES.md`.
All prior PDF/docx governance docs are superseded as the authority, and every dangling
file reference is catalogued in the Source of Truth ghost list.
**Why:** The old content was sound but trapped in image-only PDFs and mislabeled docx,
referencing filenames that don't exist on disk. The format — not the content — was the mess.
**Alternatives:** (1) Full architecture rebuild — rejected; it would destroy a working DB
and weeks of settled decisions to fix what is a formatting/legibility problem. (2) Keep
five+ separate docs — rejected for drift and maintenance burden.
**Implications:** Maintain only the four clean files going forward. The Supabase database,
brand kit, and live site were not touched.
**Supersedes:** the documentation structure in the 2026-04-22 "Three docs, not five" entry.

---

*Append new decisions below this line.*

### 2026-06-10 — Delta handoff format: SQL, per Alex's spec (supersedes the unlogged JSON decision)
**Decision:** Approved Stage 3 deltas are handed to Alex as **SQL files**: one file per
changed card, containing all affected V2-table changes for that card. Files live in a dated
run folder, named `YYYY-MM-DD__issuer-slug__card-slug.sql` (e.g.
`2026-06-08__scotia__momentum-visa-infinite.sql`). Each file is wrapped in `BEGIN;` /
`COMMIT;` and opens with a short SQL-comment header: source URLs, changed fields,
verification date.
**Why:** Alex specified this format directly (2026-06-08) and he is the one executing the
files. A complete, executable spec from the person running it beats relitigating format.
**Supersedes:** Mike's earlier decision to hand off deltas as JSON (~May 2026, never logged
— recorded here for the trail). That decision predated Alex's concrete spec.
**Implications:** Stage 3 keeps emitting structured JSON internally; a small converter
script (WORKING_NOTES #2) turns approved JSON deltas into Alex's SQL file format. The
Stage 3 prompt is bumped to v1.2 to reflect the resolved format.

### 2026-06-10 — Pipeline writes assume service_role for all four V2 tables
**Decision:** All handoff SQL assumes `service_role` / admin maintenance execution for
`card_products`, `earn_rates`, `card_caps`, and `card_exclusions`. No client, anon, or
authenticated write paths for this pipeline, ever.
**Why:** Alex confirmed (2026-06-08). `card_caps`/`card_exclusions` have explicit
`_service` policies; `card_products`/`earn_rates` rely on `service_role` BYPASSRLS — same
effective path either way.
**Implications:** Resolves Stage 3 open question #1. No RLS-policy changes requested.

### 2026-06-10 — Discontinued / not-recommended card semantics
**Decision:** Three orthogonal flags, used as follows:
- `application_status = 'closed'` — card closed to new applications.
- `is_active = true` stays the default; set `false` only to intentionally hide a card from
  all active app/product surfaces.
- `scoring_status = 'load_only'` — card stays in the database but is never recommended.
**Why:** Alex confirmed (2026-06-08). The schema already expresses all three states;
no new values or constraint changes needed.
**Implications:** Resolves Stage 3 open question #5 (HSBC). HSBC rows: `closed` +
`is_active = true` + `load_only`.

### 2026-06-10 — Fido/HSBC `scoring_status='exclude'` fixed by data, not by constraint
**Decision:** Replace `scoring_status = 'exclude'` with `'load_only'` on all affected rows.
The check constraint (`scoreable | load_only`, migration 0039) is **not** extended.
**Why:** Alex confirmed (2026-06-08). `'exclude'` was never a valid value; `'load_only'`
expresses the intended "in DB, never recommended" semantics exactly.
**Implications:** 16 registry rows in `card_sources_seed_enriched.csv` carry the invalid
string and are corrected (see the registry fix in this same sync). The Stage 3 prompt's
allowed-values list is unchanged; v1.2 adds an explicit "never emit `exclude`" note.

### 2026-06-10 — Rogers cohort representation: new-cardholder rates only, flagged
**Decision:** CardCoach represents Rogers (and Fido) card earn rates as they apply to
**new cardholders as of the February 26, 2026 restructure**. Legacy cohort rates are not
represented in V1. The app shows a disclosure line on affected cards, e.g.: "Rates shown
reflect terms for new cardholders as of February 2026; earlier cardholders may earn
different rates."
**Why:** Three cohorts see different rates on the same products after the Mar 2025 and
Feb 2026 restructures. Representing multiple cohorts requires scoring changes in Alex's
lane; new-cardholder rates serve the acquisition use case and are what issuer pages
publish. Cohort complexity is also depreciating — further Rogers changes are expected to
converge cohorts over time.
**Alternatives:** Legacy-only (serves existing holders, contradicts published pages);
both cohorts (major scoring change) — both rejected for V1.
**Implications:** Rogers/Fido reverification targets current new-cardholder terms.
Disclosure copy ships with those cards. Revisit only if cohort divergence becomes
user-visible complaint volume.

### 2026-06-10 — BMO AIR MILES → Blue Rewards: card treatment
**Decision:** AIR MILES converted to BMO Blue Rewards (conversion June 1, 2026; official
launch June 2; baseline redemption 1,500 Blue Points = $10 → 0.667¢/pt in-store/eGift,
other redemption forms at separate rates per bluerewards.ca/value). The three legacy
BMO AIR MILES cards in the registry: `application_status = 'closed'` (no longer
available to new applicants), remain `scoreable` (renamed in place, live in existing
wallets), names and earn rates to be updated ONLY via a verified Stage 2/3 pass against
BMO's pages — public reports of the converted structure (12.5x partners / 1.25x base)
are Tier 2 and do not enter the DB. The two NEW BMO Blue Rewards Mastercards (no-fee +
World Elite) are queued as Stage 1 registry additions; when they land, the safe public
claim moves 95 → 97 cards and SOURCE_OF_TRUTH's safe-claims line must move with it.
**Why:** Follows mechanically from the 2026-06-10 discontinued-card semantics and the
Rogers new-cardholder precedent. Existing-wallet scoring is CardCoach's core use case;
closed-to-new + scoreable is exactly what those flags exist to express.
**Implications:** BMO kit pre-staged (`Reverify Script/bmo_bluerewards_kit/`). Air Miles
point_programs entry is superseded by Blue Rewards (legacy Miles converted ~16:1, no
loss of value per BMO).

### 2026-07-02 — PC Financial earn-basis model: card-attributable rates only
**Decision:** `earn_rates` stores card-attributable rates. Loyalty overlays (the 15 pts/$
all-member earn at Shoppers/Pharmaprix) live in `condition_text`, never summed into the card
rate. Advertised loyalty-inclusive percentages (2.5% / 3.5% / 4.5% / 5% at Shoppers) are never
stored as card rates.
**Why:** The issuer's own legal clauses decompose each rate as "regular 10 … plus an extra N …
charged on your card(s)" (PC Optimum earning-rates legal page, verified 2026-07-02). Storing
the marketing total would double-count the loyalty program's member earn and corrupt
cross-card comparisons.
**Implications:** Insiders is the only asymmetric tier (Shoppers card-attributable 35, not 40).
Any surface that shows the advertised total must compute card rate + overlay at display time.

### 2026-07-02 — PC Financial canonical earning-terms source
**Decision:** The canonical PCF earning-terms source is the `-2023` legal-stuff slug
(`/en/legal-stuff/pc-optimum-points-earning-rates-2023/`). The older
`/en/legal-stuff/pc-optimum-mastercard/` slug is dead (404) and must not be used.
**Why:** Live verification 2026-07-02; the old slug 404s, the `-2023` page carries the current
clauses and an FR mirror per hreflang.
**Implications:** Registry updated (both existing PCF cards' `rewards_program_terms` rows filled;
net-new World and Insiders rows point at the same source). FR mirror noted, deferred pipeline-wide.

### 2026-07-02 — Welcome bonuses get a separate table + their own reverification flow
**Decision:** Welcome bonuses get a separate table + their own reverification flow (Mike).
**Why:** Offers are time-bounded, can span multiple cards (PCF no-fee stream 50K offer covers
three cards via one application), can be multi-component (PCF Insiders: 50K points + $120
first-year fee credit), and can run concurrently per card (standard PC card: 20K special offer
alongside stream offer). A `card_products` column cannot represent any of these.
**Implications:** Schema proposal pending; offers remain outside the verified dataset until it
lands.

### 2026-07-02 — Program conversions keep card identity
**Decision:** When an issuer converts a card's rewards program (e.g., BMO AIR MILES → Blue
Rewards), the existing `card_id` is retained; `earn_rates` and `card_caps` are
expired-then-inserted; `display_name` and program ids update in place.
**Why:** Preserves history per the expire-then-insert constraint, and the workbook's own
transition note anticipated in-place update.
**Implications:** First applied: `ca_bmo_air_miles_standard_mastercard`, delta 2026-07-02.

### 2026-07-03 — Welcome-bonus schema design APPROVED (Mike)
**Decision:** Welcome-bonus schema design APPROVED (Mike): separate offers + offer_components
tables, many-to-many card linkage, typed components (points grant / statement credit / fee
waiver-rebate / multiplier), offer-level exclusions distinct from program-level, dual window
columns (verbatim + normalized-as-interpretation), expire-then-insert lifecycle, load_only at
launch, public offers only, provinces via available_provinces pattern, FR deferred,
commission-blind boundary, registry sourcing via product-page cadence notes pending distinct
offer URLs.
**Why:** All seven open questions in PROPOSAL_welcome_bonus_schema_2026-07-03 resolved by Mike
2026-07-03; design constraints from the four verified example offers (BLOG_OPERATIONS
2026-07-02) satisfied.
**Implications:** DB-side work sits documented until picked up — no migrations exist. Capture
flow may begin populating offer records as drafts once tables exist. Offers stay load_only /
outside the scoring engine at launch.

**2026-07-05 — Housekeeping process rule (standing; Mike, in chat 2026-07-05):** CoWork sessions never change permissions or self-escalate; if an operation is blocked, that item stops and is reported — the fallback is always report-or-archive, never enable.

### 2026-07-05 — Traffic and monetization plan adopted (Mike)
**Decision:** Traffic and monetization plan adopted — analytics via Cloudflare Web Analytics snippet in the base template; paid acquisition held to the day-60 gate (~Sep 4, decided on real conversion data); interim CTA destination = waitlist until Fintel links are live; sitemap.xml, robots.txt, and sitewide Organization/WebSite JSON-LD added to the render pipeline.
**Why:** Adopted with the 2026-07-05 technical SEO pass (Cowork session 1); measurement is gated on real conversion data before any paid spend.
**Implications:** Organization + WebSite @graph JSON-LD now emitted by render_v2.py on every page (per-post Article/FAQPage and hub CollectionPage schema untouched). sitemap.xml and robots.txt were verified already present and correct in site/ (sitemap is pipeline-generated; lastmod = render date per BLOG_OPERATIONS parity rule). Beacon insertion ran as the same-day 1B pass — session 1's snippet placeholder was empty, per its dispatch. Day-60 gate lands ~2026-09-04.

### 2026-07-05 — cardcoach.ca acquired as a defensive domain (Mike)
**Decision:** cardcoach.ca acquired as a defensive domain; a Cloudflare redirect rule 301s all requests (path + query preserved) to card.coach; card.coach remains the sole canonical; cardcoach.ca is excluded from GSC and the sitemap.
**Why:** Captures type-in and spoken-brand traffic without splitting SEO authority across two domains.
**Implications:** No site or pipeline changes required — canonicals, og:url, JSON-LD and the sitemap all reference card.coach only, and continue to. Apex redirect verified live 2026-07-05; session corroboration: https://cardcoach.ca/how?utm_test=1 → https://card.coach/how?utm_test=1 (path and query preserved, canonical intact).

### 2026-07-08 — Canonical domain flipped: cardcoach.ca primary; card.coach demoted to 301 (Mike)
**Decision:** cardcoach.ca becomes the hosting/canonical domain. card.coach is demoted to a 301 (path + query preserved) pointing at cardcoach.ca — the exact reverse of the 2026-07-05 defensive-domain arrangement, which this entry supersedes. The single-canonical principle is unchanged; only which domain is primary changes.
**Why:** .ca geotargeting + Canadian trust signal + spoken-brand match, executed pre-launch while the switch cost is near zero.
**Implications:** Repo-side cutover executed 2026-07-08, local and uncommitted (review/commit/push = Mike; the session made no Cloudflare, DNS, or GSC changes — nothing is live until Mike's Cloudflare pass): render_v2.py BASE → https://cardcoach.ca, with the previously hardcoded CTA-UTM append and CTA-detection strings consolidated onto BASE; all 10 post-source CTA destinations flipped; full re-render (10 posts + blog index + 4 hubs + post.css + sitemap.xml — 22 URLs, all lastmod 2026-07-08 per the migration); the 8 hand-authored pages + robots.txt swapped by hand. The Cloudflare Web Analytics token was swapped in the same pass (see BLOG_OPERATIONS 2026-07-08). hello@card.coach is deliberately unchanged everywhere — mail routing on cardcoach.ca is unverified; open decision for Mike.

### 2026-07-08 — Contact email flipped to hello@cardcoach.ca (Mike, same-day follow-up)
**Decision:** The published contact address flips with the domain: hello@cardcoach.ca everywhere (mailto links, Organization JSON-LD email, and the nine in-body/microcopy sentences — Mike approved the prose touch by requesting the swap). Resolves the "open decision" left by the entry above. hello@card.coach stays alive as a legacy forward.
**Why:** Same logic as the domain flip — pre-launch, switch cost near zero; a mismatched @card.coach address would permanently advertise the demoted domain.
**Implications:** Repo-side only, same uncommitted worktree: render_v2.py footer mailto + SITE_JSONLD email flipped, 8 hand pages swapped (28 occurrences), full re-render + demo rebuild. site/ and render_v2.py now grep **zero** for card.coach in any form; new address ×58 sitewide. **Push gate (WORKING_NOTES #18):** Cloudflare Email Routing for hello@cardcoach.ca must exist before the domain-flip commit is pushed, or the live site publishes a dead address; keep card.coach mail forwarding (the web 301 does not carry mail). Send-as for outbound replies = separate, optional.

### 2026-07-13 — Web app v1: Mike-built free recommendation surface, scored by the v2 engine
*(Recovered 2026-07-16 from the 2026-07-13 session — the original append never landed on
disk. Deploy sentence corrected to the verified mechanism.)*
**Decision:** The free web recommendation app is Mike's lane to design and build (per the
July 2026 Mike/Alex meeting). It calls Alex's `recommend-card-v2` edge function for all
scoring — the web never reimplements earn math. Purchase input = category picker (primary)
+ merchant search via `merchant_entities` (secondary, graceful degrade); owned-card filter
persists in device-only localStorage (`cc_wallet_v1`, product ids only, "Clear my cards"
control); ships at `cardcoach.ca/best-card/` inside the `cardcoach-site` repo/Worker,
vanilla no-build; anonymous and free — no accounts, geolocation, wallet sync, or cap
tracking (those are the app); `scoring_status = 'load_only'` cards badged "can't rank
yet," not hidden; caps disclosed with the zero-spend assumption stated; CTA = waitlist
until the iOS app ships; no affiliate links until Fintel; pageview analytics only.
**Why:** Calling the engine eliminates web-vs-app answer drift by construction and keeps
scoring truth in one codebase. The remaining choices follow existing site conventions
(repo, brand, no-build) and the freemium split in REVENUE.md.
**Implications:** Alex's contract answers (Annex A of the proposal) gate the build phase
(P3); Supabase URL + anon key gate the P1 data spike. The CTA target is already live: the
waitlist Worker has served production since 2026-07-05 and was origin-allowlisted for both
domains 2026-07-13; web-app submissions can tag `source: "best-card"` for segmentation.
Deploy rides the site's actual mechanism — push to `main` auto-deploys via Workers Builds
(verified 2026-07-16); anything committed to `main` ships live within ~1 minute. Full
decision set, phase plan, and contract questions: `PROPOSAL_web_app_v1_2026-07-13.md`.

### 2026-07-16 — Docs fork identified; canonical files rebased to carry both waves
**Decision:** The attic and canonical copies of SOURCE_OF_TRUTH.md,
PIPELINE_AND_DECISIONS.md, REVENUE.md, and HOW_THE_ENGINE_WORKS.md are forked lineages,
not duplicates: the 2026-07-02 folder recovery rebuilt the canonical tree from a
pre-2026-06-10 snapshot, so all July edits sat on a base missing the June wave. The
canonical files are rebased to carry both waves plus the 2026-07-16 verified state; the
attic copies stay in `_archive` with a merged-on note. Nothing is deleted.
**Why:** Each side was the sole carrier of decisions the other lacked — six June decisions
(attic) vs ten July entries (canonical). Discarding either loses settled history.
**Implications:** The v24 audit workbook
(`cardcoach_initial_load_audit_pack_canada_2026-06-07_v24_cleaned.xlsx`) is re-designated
canonical at repo root — verified 2026-07-16: 95 unique cards, 15 issuers, v22→v23→v24
lineage sheets intact. The Phase 4 revenue model
(`CardCoach_Phase4_Revenue_Model_v2.xlsx`) is verified as the 2026-06-09 build: 7 tabs,
exactly 866 formulas, Web Path C5=100/C28=25,650 and Monthly Model C45/C46 break-even
formulas matching the Sensitivity One-Pager. STAGE3_PROMPT.md: the June v1.2 was recovered after all — it rode into the repo with the 2026-07-16 sync and sat at root; the same-day rebuild is relabeled v1.3 and supersedes it (see the prompt's changelog). The three files retired 2026-06-10
(`CARDCOACH.md`, `pipeline/DECISIONS.md`, `pipeline/OPEN_ITEMS.md`) were found loose on
Mike's Mac, not in the live tree; confirm their absence from the tree at commit time.
`pipeline/DECISIONS.md`'s twelve April entries must exist in this log (as the pre-fork
base) before its archival is treated as final.

### 2026-07-16 — Engine framing is final: V2 is the only engine
**Decision:** V2 is it. V1 is dead; there are not two engines and nothing coexists. Any
live doc, copy, or prompt claiming V1/V2 coexistence or an operative V1 is an error —
correct it on sight. Offer stacking (`solveOfferStack`) is not wired into the V2
production path; no live doc may claim the engine "factors in" stacking until Alex ships
it.
**Why:** Ruled by Mike 2026-07-16 to put the question to bed permanently. The canonical
engine explainer's "factors in automatically" stacking claim contradicts its own V1→V2
section; the retired CARDCOACH.md's "V1 and V2 coexist" line is the same class of error.
**Implications:** HOW_THE_ENGINE_WORKS.md becomes one file, one truth: the plain-English
explainer body, corrected to V2-only, with the governance guardrails ("what is NOT live,"
V1-is-dead statement) folded in. No separate governance doc — one file means one surface
for drift. Stage-3 prompt rule 2 restated accordingly (v1.2).
**Supersedes:** any coexistence framing anywhere, including archived docs if quoted.

### 2026-07-16 — Public card-count claim: "95+ cards" until the registry clears 100
**Decision:** All public copy uses "95+ cards." No other number ships until the registry
clears 100.
**Why:** Verified-safe today: the v24 baseline counts exactly 95 unique cards across 15
issuers; Blue Rewards adds and PCF net-new ride on top as deltas, so "95+" stays true
through the queued growth without copy churn.
**Implications:** Corrects the attic's "95 cards" and standardizes the canonical's "95+."
Registry count is the trigger to revisit, not a date.

### 2026-07-16 — Lanes: Mike everything-but-the-app; Alex the app; Mikayla social media
**Decision:** Mike is ultimately responsible for everything except the app. Alex handles
the app — including App Store submission and listing copy. Mikayla handles social media;
her role is still being defined, directed by Mike.
**Why:** Ruled by Mike 2026-07-16. App Store listing copy sits in the app lane, not the
social lane.
**Supersedes:** REVENUE.md "what we still need" item 5's "Mikayla's lane" framing (stale);
any "Mikayla off project" framing.

### 2026-07-29 — Air Miles CPP retired; More Rewards CPP verified
**Decision:** `airmiles-points` is retired (inert in the point-programs registry —
superseded by `blue_rewards`; nothing scores against it). `more-rewards-points` is
verified at **0.1429 / 0.15 / 0.15** (fixed, 2 sources).
**Why:** Resolved in the 2026-07-29 CPP valuation-lane session; the Air Miles program-wide
question that rode in WORKING_NOTES #6's audit notes is moot with the program retired.
**Implications:** Closes WORKING_NOTES #6 and #7 (deleted per "Close = delete",
2026-07-31). Trail: `card_coach_business_docs/HANDOFF_cpp_valuation_lane_2026-07-29.md`
in CardCoachv2; `pnpm verify:cpp:cloud` remains the live source of truth for the numbers.

### 2026-07-31 — CardCoachv2 is the canonical site home; cardcoach-site becomes a downstream mirror
**Decision:** The cardcoach.ca working tree lives canonically at
`CardCoachv2/card_coach_website/site/` (Mike's ruling, 2026-07-31; committed `b87aa22`
overnight). The `cardcoach-site` GitHub repo remains the DEPLOY repo — Cloudflare Workers
Builds auto-deploys it on push, live since 2026-07-05 — but is now a downstream mirror
pending the repoint in `proposals/PROPOSAL_site_deploy_repoint_2026-07-31.md`.
**Why:** One repo of record; the deployed tree had no canonical home under version control
alongside its render sources (`01_CORE/blog/`).
**Implications:** Interim deploy mechanics (double-repo working copy, detached git-dir) are
documented in `card_coach_website/README.md`. The renderer's templates lag the deployed
truth (waitlist retirement, App Store link, Best Card nav) — regenerating without a
template update would regress the site. Repoint execution and the eventual archive of
`cardcoach-site` are Mike's dashboard work, not a session's.

### 2026-07-31 — Stamp discipline: the stamp is the landing date
**Decision:** A doc's `Last updated:` stamp carries the date of the commit that lands the
change — never the authoring date, and a stamp never predates its own commit. Late-landed
work notes the authoring date in parentheses: `Last updated: 2026-07-31 (authored 2026-07-16)`.
Docs spelling the field differently (`Last consolidated:`, `Version N · Last updated`, a
proposal's `Status:` line) satisfy the rule via that field; a doc with no stamp field gets a
`Last updated:` line the first time it is edited.
**Why:** Adopted by Mike 2026-07-31 after a restamp audit showed authoring-date stamps made
landed work look unlanded (REVENUE.md appeared unstamped because its stamp carried the 07-16
authoring date while the commit landed 07-31). Full text in SYNC_PROTOCOL.md; recorded here
because it lived only in the protocol doc.
**Implications:** The six docs that carried no stamp field (BLOG_OPERATIONS, BRAND,
LAUNCH_TRACKER, SCHEMA, README2, SCHEMA_HANDOFF_README) were stamped 2026-07-31, content
untouched.

### 2026-07-31 — Marriott Bonvoy re-anchored under spread rule v2; three-source test satisfied
**Decision:** `marriott-bonvoy-points` is **0.70 / 0.86 / 1.00** (conservative kept as the
practical floor with a documented divergence — every live consensus figure sits above it;
realistic = lowest consensus, Finly Wealth 0.86; aggressive = highest, Frugal Flyer 1.00
explicit-CAD). Four CAD sources attached to all three rows (Finly 0.86, ThePointCalculator
/ca/ 0.90, Milesopedia 0.90, Frugal Flyer 1.00); NerdWallet 0.80 excluded as USD. The
tier2 three-source test is satisfied for marriott; the retirement option is dead.
**Why:** Ruled by Mike 2026-07-31 (morning ruling on the overnight report, item 4). The
2026-07-29 basis — the low end of a 0.70–0.80 third-party band — is no longer published
anywhere; the live band is 0.86–1.00.
**Implications:** `pv_tier2_needs_three_sources` still cannot be VALIDATED — aeroplan is
unresolved, and the constraint as written also freezes expired tier2 history (it fires on
any UPDATE of an under-evidenced tier2 row, discovered executing this ruling). A
constraint rewrite scoped to active rows is proposed in the marriott delta header
(CardCoachv2, `2026-07-31__marriott__spread-rule-v2-four-cad-sources.sql`). Trail:
commit `ef807c7`; `pnpm verify:cpp:cloud` remains the source of truth.

### 2026-07-31 — Spread rule v3: realistic = MEDIAN of CAD consensus
**Decision:** Realistic for `variable` programs = **MEDIAN of 3+ independent CAD programme
valuations**, superseding v2's lowest-consensus rule.
**Why:** Aligns with the two documented industry methodologies (Frequent Miler
50th-percentile RRV; Frugal Flyer median-of-observations) per the 2026-07 valuation
research; the lowest-consensus rule systematically understated flexible currencies on the
default scoring tier. v2's reasoning (never overstate) is retained at the conservative
tier, which stays the floor.
**Landed:** 2026-07-31 (night apply session, from
`cardcoach_master_valuation_index_2026-07-31_v1.xlsx`, approved with amendments 1–4).
Applied to avios, aeroplan, amex-mr this session; marriott excluded — see the v3-vs-v2
conflict entry below.

### 2026-07-31 — Governance §2 condition 3 amended: worked-redemption ceiling
**Decision:** Aggressive for `variable` programs may exceed the highest published valuation
only on **worked-redemption evidence**: named, currently-bookable, fixed-price partner
redemptions, 75th–90th percentile of repeatable value, stored at or below the worked band,
documented one-off outliers excluded. New source class `worked_redemption`; confidence cap
`medium`. Each worked example records route, points cost from the live chart, dated
cash-fare snapshot, computed CPP.
**Landed:** 2026-07-31 as a rule. No worked-redemption row landed this session — the
aeroplan and amex-mr aggressive targets (3.00) are **deferred** pending the evidence pack
(live chart prices + dated cash fares for 2+ named examples were not capturable in the
apply session).

### 2026-07-31 — Aeroplan re-anchor (v3)
**Decision:** Conservative 1.20→1.00 (practical floor, pending Tier 1b artifact), realistic
1.27→2.00 (median; also cures the below-band defect from governance §8), aggressive
2.00→3.00 (worked cap).
**Landed:** 2026-07-31 — **realistic 2.0000 applied** (median{NerdWallet CA 1.60, PoT 2.00,
Milesopedia 2.00}, all read on the publishers' pages per §2b; +57.5% on the default tier,
10 scoreable cards). Conservative **deferred, stays 1.2000** — no ~1.0 portal/gift-card
issuer artifact verified on-page this session. Aggressive **deferred, stays 2.0000** — no
evidence pack. Delta: `2026-07-31/2026-07-31__aeroplan-points__cpp.sql` (CardCoachv2).

### 2026-07-31 — Amex MR re-anchor (v3)
**Decision:** Realistic 1.70→2.00 (median{1.70, 2.00, 2.20}; Frugal Flyer added as band
source, Mega Miles Broker demoted to directional per §2a), aggressive 2.20→3.00 via 1:1
Aeroplan.
**Landed:** 2026-07-31 — **realistic 2.0000 applied**; MMB demoted (observed_value nulled +
notes) on the active conservative/aggressive rows with FF 2.00 attached in its place, bands
unchanged at 1.70–2.20 (+17.6%, 6 scoreable cards). FF's MR figure was read on-page in
their **bank-loyalty-program** article (the frequent-flyer article the index cited now
carries transfer ratios only — divergence recorded on the row). Aggressive **deferred,
stays 2.2000** (same evidence pack as aeroplan). Delta:
`2026-07-31/2026-07-31__amex-mr-points__cpp.sql`.

### 2026-07-31 — RBC Avion Elite realistic anchored to the Air Travel Redemption Schedule
**Decision:** Realistic 1.00→2.00 anchored to the issuer-published Air Travel Redemption
Schedule floor (tier1b); the 2.00 assumes band-optimal fares — mid-band redemptions yield
less, so it is the schedule floor under optimal use, not a guarantee. Aggressive
2.30→2.3333 exact chart max ($350/15,000). Confidence classification of chart-derived
rates to be settled (§5 wording vs 07-31 Aventura precedent).
**Landed:** 2026-07-31 — both rows applied at **medium-high** (not `high`; flag recorded in
review_notes for Mike). Dual-confirmed on two issuer artifacts: the Avion Visa Infinite and
Visa Platinum benefits-guide PDFs on rbcroyalbank.com (identical schedule tables; internal
doc date 2019, noted). +100% on the default tier, 3 scoreable Elite cards. Delta:
`2026-07-31/2026-07-31__rbc-avion-points__cpp.sql`.

### 2026-07-31 — Avios unblocked; conservative re-anchored
**Decision:** Five CAD sources on file (1.50–2.00) satisfy §2 condition 2. Conservative
1.20→1.50 (band floor as practical floor; prior figure traced to discredited §2b reading),
realistic 1.50→1.90 (median).
**Landed:** 2026-07-31 — both applied. The realistic row was written earlier the same day
(session-4 ruling D, v2), so the v3 value landed as a **same-day in-place UPDATE** per §7;
supersession recorded in review_notes. +26.7% on 1 scoreable card. Delta:
`2026-07-31/2026-07-31__avios-points__cpp.sql`.

### 2026-07-31 — Marriott Bonvoy under v3 (drafted) — NOT APPLIED; v2/v3 conflict for Mike
**Decision (drafted in the index):** Directed search per amendment 4 unblocked Marriott:
band {PoT 0.80, Milesopedia 0.90, TPC 0.90, FF 1.00}, realistic 0.70→0.90 (median),
aggressive 0.90→1.00, conservative 0.70 unchanged.
**Landed:** **NOT APPLIED.** The v2 morning ruling (previous entry, applied 22:58 ET the
same evening) landed first: live is 0.70 / 0.86 / 1.00 on a band {Finly 0.86, TPC 0.90,
Milesopedia 0.90, FF 1.00} — which no longer matches the index's "current" values, so the
apply session skipped marriott on preflight drift (per the apply prompt's drift rule).
**Open for Mike:** under v3, the median of the *live* band is 0.90 — reconciling marriott
to v3 would move realistic 0.86→0.90. The two same-day rulings applied different spread
rules; needs an explicit call before any further marriott write.

### 2026-07-31 — Bank conservative floors: verify-to-page rule (amendment 1)
**Decision:** TD, BMO, NBC and Scene+ conservative floors re-anchor to the EXACT rate the
issuer page states at verification — the research figures (0.25 / 0.33 / 0.40 / ~0.70) are
framework approximations, not write values; the page is truth, not the workbook cell. If a
page shows no channel below the current value, the current value stands. Scene+
additionally reclassifies fixed→bank only if a lower channel confirms.
**Landed:** 2026-07-31 —
**TD 0.40→0.2500** (T&C PDF §3.3: "minimum value of 400 TD Rewards Points per $1";
limited-time-promotional caveat recorded; confidence medium, single numeric artifact).
**NBC 0.83→0.4000** (À la carte Rewards Plan Schedule A: repayment $100 = 25,000 pts,
uniform 0.40 across all five tiers; also cures the unrecorded-basis defect; medium).
**BMO: no write** — the issuer T&C states travel 150 pts/$1 and non-travel 200 pts/$1
(=0.50, equals current); no 300 pts/$1 channel exists on the page; 0.5000 stands.
**Scene+: no write, no reclass** — the program's own help page and Scotiabank welcome-kit
pages state every rate at 1.0 (1,000 = $10; 500 = $5; 100 = $1) and give no numeric rate
for "Points for Credit"; 1.0000 and `fixed` stand.
Deltas: `2026-07-31__td-rewards-points__cpp.sql`, `2026-07-31__national-bank-points__cpp.sql`.

### 2026-07-31 — Event-driven refresh triggers adopted (framework recommendation 5)
**Decision:** Award-chart change, transfer-ratio change, statement-credit rate change, and
program merger/closure each trigger immediate re-valuation of the affected program
regardless of SLA. The SLA ladder (variable 90d / bank 180d / fixed 365d / legacy exempt)
is the scheduled backstop, not the only trigger. Detection feeds: D3 redemption_terms
registry (monthly fetch) for chart and rate changes; transfer-ratio and merger events are
manual-watch until a registry source class exists for them.
**Landed:** 2026-07-31 (rule adoption; recorded with the index apply).

### 2026-07-31 — Master valuation index adopted as review artifact
**Decision:** `cardcoach_master_valuation_index_2026-07-31_v1.xlsx` is the
review-and-approval artifact for `point_valuations` changes; DB writes only via its
StagedSQL sheet under governance §7.
**Landed:** 2026-07-31 — the night apply session executed it: 8 rows written across 6
programs (avios ×2, aeroplan realistic, amex-mr realistic, rbc-avion ×2, td conservative,
nbc conservative), 2 verified no-writes (bmo, scene+), 3 deferred (aeroplan conservative +
both worked-redemption aggressives), 1 drift-skip (marriott). Full accounting:
`cardcoach-docs/APPLY_REPORT_valuation_index_2026-07-31.md`.

### 2026-08-01 — Marriott v2/v3 conflict resolved: realistic reconciled to v3 median
**Decision:** `marriott-bonvoy-points` realistic **0.8600 → 0.9000** — the v3 median of the
live four-source band {Finly 0.86, TPC /ca/ 0.90, Milesopedia 0.90, Frugal Flyer 1.00}.
Ruled by Mike 2026-08-01 on the apply report ("apply the marriott v3 reconciliation —
realistic 0.86 → 0.90"), closing the conflict entry above (two 2026-07-31 rulings had
applied different spread rules to the same program).
**Landed:** 2026-08-01 (morning). Standard expire-then-insert — the 0.86 row was a
prior-day row by ruling time, so no same-day exception; it keeps an honest one-day validity
window (07-31 → 08-01). Evidence carried over with original 07-31 on-page access dates;
band re-guarded as exactly {0.86, 0.90, 0.90, 1.00} at write time. Snapshots
`point_valuations_snapshot_20260801` + sources companion taken before the write. Delta:
CardCoachv2 `2026-08-01/2026-08-01__marriott-bonvoy-points__cpp.sql`.
**Residue:** confidence left at the v2 pass's `medium`; the index proposed `medium-high`
for this row under v3 — still open for Mike (noted on the row). Realistic temporal chain now
reads 0.90 (03-14) → 0.70 (07-29) → 0.86 (07-31) → 0.90 (08-01). +4.7% vs v2, net +28.6%
vs the 07-29 baseline, 2 scoreable cards.

### 2026-08-01 — tier2 three-source constraint rescoped to active rows and VALIDATED; Aeroplan completed
**Decision:** `pv_tier2_needs_three_sources` is rescoped to active rows (`valid_to IS NOT
NULL OR source_tier IS DISTINCT FROM 'tier2' OR source_count >= 3`, migration
`20260801082400`) and **VALIDATED** (`20260801090500`) — all six pv_ constraints are now
load-bearing; the database itself refuses an active Tier 2 valuation without three
sources. Aeroplan is complete per the approved master valuation index: conservative
**1.20 kept** (the ~1.0 portal/gift-card artifact does not verify on the issuer page —
aircanada.com's redeem hub publishes no ratio; workbook fallback applied), realistic
**2.00** (spread rule v3 median, master-index apply session), aggressive **3.00** on a
worked-redemption pack under amended condition 3 (ANA YVR–HND J 55k pts: 6.48–8.68 cpp
typical-date; YYZ–FRA J 60k pts: 4.40–6.2; dated Google Flights snapshots 2026-08-01,
chart points from the D3 registry capture 2026-07-31; peak/monopoly and single-date-low
outliers excluded; 3.00 stored below the worked band).
**Why:** Ruled by Mike 2026-08-01 in-session ("apply the constraint rescope migration and
start on aeroplan"). The old constraint shape froze under-evidenced tier2 history (fires
on any UPDATE, including expiry) and could never validate.
**Implications:** The v2-era draft (realistic → 1.44) was VOIDed — the pre-guards caught
that the master-index session had already applied v3 (realistic = median) before it ran;
the two-rule window also produced marriott 0.86 (v2) → 0.90 (v3 reconciliation, apply
session, Mike's ruling — that session's delta). Trail: CardCoachv2 commit `1dc84fe`;
`pnpm verify:cpp:cloud` remains the source of truth while the master-index apply session
finishes landing workbook rows.

### 2026-08-01 — Marriott confidence aligned to the index (M / MH / MH)
**Decision:** `marriott-bonvoy-points` realistic and aggressive confidence **medium →
medium-high**, per the index's marriott row (C/R/A = M/MH/MH); conservative stays medium.
Ruled by Mike 2026-08-01 ("bump marriott realistic and aggressive to medium-high per the
index"). Closes the residue line of the reconciliation entry above.
**Landed:** 2026-08-01 (~08:30 ET), in-place metadata updates per house convention (values
unchanged — cf. the session-4 avios confidence pass): both rows guarded at 0.9000/1.0000 @
medium before the bump. The tier2 MH ceiling clears (§5): four CAD sources read on the
publishers' pages 2026-07-31, values inside the 0.86–1.00 band. Recorded as a rider on
CardCoachv2 `2026-08-01/2026-08-01__marriott-bonvoy-points__cpp.sql`. Marriott now matches
the index's proposed confidence grid exactly.

### 2026-08-01 — Amex MR aggressive to 3.00 via the aeroplan pack; master valuation index fully landed
**Decision:** `amex-mr-points` aggressive **2.2000 → 3.0000**, inheriting the aeroplan
worked-redemption pack via the 1:1 MR→Aeroplan transfer (index section D / Changes r6,
amended §2 condition 3). Ruled by Mike 2026-08-01 ("apply the amex-mr aggressive
2.20 → 3.00 via the aeroplan pack").
**Landed:** 2026-08-01 (~09:45 ET), expire-then-insert; the 2.20 row keeps a one-day
validity window. Evidence: the consensus band carried over (Milesopedia 1.70, FF 2.00,
PoT 2.20 + demoted MMB directional) plus the two worked rows copied from the aeroplan
aggressive row with the 1:1 transfer named per example (ANA YVR–HND J 55k = 6.48 cpp;
YYZ–FRA J 60k = 4.40 cpp; dated 2026-08-01 fare snapshots; outliers excluded). Band
1.70–6.48; 3.0000 stored below the worked band. Confidence **medium-high → medium** — the
worked-row cap, a deliberate downgrade paired with the higher value. Transfer-ratio basis
recorded honestly: 1:1 per the approved index + PoT's transfer-based valuation; the public
amex.ca transfer page (attempted 2026-08-01) does not state the ratio. Pre-guards pinned
both the outgoing amex row and the aeroplan pack rows by id and value. Delta: CardCoachv2
`2026-08-01/2026-08-01__amex-mr-points__cpp.sql`.
**Implications:** This was the last deferred value — **the 2026-07-31 master valuation
index is now fully landed**: every index row is at its final state (writes applied,
verified no-writes kept, marriott reconciled to v3 with the index confidence grid,
aeroplan conservative kept at 1.20 by the fallback rule). Still open, tracked in the apply
report: chart-derived confidence classification (affects the two RBC Avion rows), the TD
promo-caveat floor question, and the BMO 0.67 → 0.6667 cosmetic candidate.

### 2026-08-01 — Chart-derived confidence settled: dual-confirmed charts are medium-high
**Decision:** A rate read from an issuer-published redemption chart and **dual-confirmed**
classifies as **`medium-high`** — not `medium-low` (governance §5's strict line, which
continues to govern chart inferences that are *not* dual-confirmed), and not `high`
(reserved for rates the issuer states numerically). Ruled by Mike 2026-08-01 ("settle the
avion confidence — keep medium-high on chart-derived rates"), resolving apply-report
decision item 2 and the §5-vs-Aventura-precedent tension.
**Landed:** 2026-08-01 (~09:55 ET). No value or confidence changes needed — the two
`rbc-avion-points` chart rows (realistic 2.0000, aggressive 2.3333) already carried
`medium-high`; their open flags were resolved on-row by in-place notes update (rider on
the 2026-07-31 rbc-avion delta). Dated SETTLED note added under §5 of
`PROPOSAL_point_valuation_governance.md` (same inline-annotation convention as §6's
2026-07-31 correction).
**Residue:** `cibc-aventura-points` aggressive 2.2857 carries `high` from the 07-31 pass
under the old reading (dual-confirmed chart = high). Retrofit not actioned — aventura was
on the index's no-writes list and this ruling named avion only. Needs an explicit call:
downgrade to `medium-high`, or document an exception on the row.

### 2026-08-01 — Aventura aggressive retrofitted: high → medium-high
**Decision:** `cibc-aventura-points` aggressive (2.2857, the Airline Rewards Chart maximum
whose 07-31 `high` created the §5 tension) is downgraded to **`medium-high`**, conforming
to the settled chart-derived classification. Ruled by Mike 2026-08-01 ("downgrade the
aventura aggressive to medium-high"), closing the residue of the entry above.
**Landed:** 2026-08-01 (~10:05 ET), in-place metadata update (value and evidence
unchanged; guarded at 2.2857 @ high, count 2). Aventura's conservative 0.6250 and
realistic 1.0000 keep `high` — issuer-stated rates, outside the ruling. **No chart-derived
row now carries `high`.** The §5 dated note updated to record the completed retrofit.
Delta: CardCoachv2 `2026-08-01/2026-08-01__cibc-aventura-points__cpp.sql`. Outside the
master index's no-writes list by explicit ruling; noted on the row.

### 2026-08-01 — WestJet: the "relaunch" was history; points-era record completed, values unchanged
**Decision:** `westjet-dollars-points` stays **1.00 ×3** (master-index NO CHANGE honoured).
The overnight "programme relaunch in flight" gate resolves as already-history: WestJet
dollars converted to WestJet points on **2025-04-30 at $1 = 100 points** (D3 registry
verification 2026-07-31); the future-tense copy on westjet.com is stale marketing text.
Nine evidence rows attached (redeem page read live 2026-08-01: "100 WestJet points will be
worth 1 CAD... base fare, surcharges, bags and seats"; "2,500 points for $25 CAD"; plus the
two legacy-URL pages), `point_programs.display_name` updated to **WestJet Points** (id
keeps the FK-stable legacy slug), and both RBC WestJet cards' earn_rates confirmed already
points-based — no earn work needed.
**Why:** Ruled by Mike 2026-08-01 in-session ("start on westjet").
**Implications:** NEW report-only flag: the taxes/fees and post-booking-extras channel
redeems at 105–115 pts/$1 (**0.87–0.95 c/pt**) — a lower published channel. If WestJet is
ever reclassified fixed→bank (the Scene+ amendment-1 pattern), conservative re-anchors
there; Mike's ruling, not written. CPP-17 remainder is now 6, all awaiting rulings
(blue_rewards ×3 and bmo r/a on the 0.6667 rounding pair; cibc realistic de-publication).
Trail: CardCoachv2 commit `c17696d`.

### 2026-08-01 — TD conservative floor affirmed at 0.2500; promo-caveated floors acceptable when documented
**Decision:** `td-rewards-points` conservative stays **0.2500** — the T&C §3.3 issuer-stated
minimum ("400 TD Rewards Points per $1 (Minimum Value)") — despite the same section labeling
Other Redemption Options "limited-time promotional offers" TD may change or cancel. The
caveat documented on the row is the accepted defensibility record; reverting conservative to
the Expedia 0.50 was considered and declined. Ruled by Mike 2026-08-01 ("keep the td 0.25 —
the caveat note is enough"), closing apply-report item 3 — the report's last open item.
**Implications:** Precedent: a promo-caveated issuer floor is acceptable for the
conservative tier when the caveat is recorded on-row. Risk containment is the event-driven
refresh trigger set (2026-07-31): withdrawal or repricing of the 400/$1 channel is a
statement-credit rate change → immediate re-valuation, not an SLA wait. Ruling recorded on
the row and as a rider on `2026-07-31/2026-07-31__td-rewards-points__cpp.sql`. **With this,
every item from the 2026-07-31 master valuation index apply and its follow-up rulings is
closed**; `pnpm verify:cpp:cloud` runs 17/17 with zero warnings.

### 2026-08-01 — Rounding pair fixed; CIBC realistic re-based; CPP-17 promoted to FAIL; strict passes
**Decision:** (1) `blue_rewards` ×3 re-anchored **0.6670 → 0.6667** and `bmo-rewards-points`
realistic/aggressive **0.6700 → 0.6667** — the exact issuer ratios (1,500 pts = $10;
150 pts = $1) at the schema's 4-dp precision; evidence recorded at the same precision (bmo
conservative 0.50 stands per the 07-31 verify-to-page outcome). (2) `cibc-aventura-points`
realistic **value kept at 1.00**, basis re-sourced **tier1 → tier2** with confidence capped
medium-high: CIBC de-published the fixed general-redemption ratio, and the value now rests
on the v3 consensus median {Prince of Travel 1.0 CAD, Frugal Flyer 1.0, Milesopedia 1.2},
all three read on the publishers' own pages 2026-08-01; event trigger recorded to re-anchor
to tier1 immediately if CIBC republishes. (3) **CPP-17 promoted WARN → FAIL** — the tier1/1b
evidence backlog went 32 → 0 across the overnight batches and the morning rulings.
**Why:** Ruled by Mike 2026-08-01 in-session ("fix the rounding pair and cibc"), closing the
last items of the overnight report's gated queue.
**Implications:** **The gated queue is empty and `pnpm verify:cpp:cloud --strict` exits 0** —
every check passes including staleness and drift; every active row traces to attached,
dated, on-page evidence; all six pv_ constraints are validated. Trail: CardCoachv2 commit
`27d0598`. The master-index apply session was still landing workbook rows (live 124/155 at
the final resync); `verify:cpp:cloud` remains the source of truth.

### 2026-08-01 — TD promo-caveat floor resolved (0.25 stands); marriott's last index prerequisite closed
**Decision:** (1) `td-rewards-points` conservative **stays 0.25**. The full T&C §3.3 read
confirms the fragility flag was real — "Other Redemption Options are limited-time
promotional offers ... [TD] can cancel or change" covers the 400 pts/$1 Minimum Value —
but td.com's pay-off-purchases page publishes the identical $1 = 400 pts as a **standing
feature** ("accurate as of August 19, 2025", no promotional framing), now attached as a
second issuer artifact. The conservative tier is the lowest channel that exists today;
withdrawal is covered by the event-driven refresh triggers, confidence stays `medium`, and
the row carries an explicit revert-to-Expedia-0.50 instruction if the channel disappears.
(2) `marriott-bonvoy-points`: Prince of Travel's Marriott figure — the one workbook band
member never read on-page — verified 2026-08-01 ("0.8 cents (CAD), 5th night free on 5+
night stays, off-peak value") and attached as the **fifth source** on all three rows.
Five-source band 0.80–1.00; the v3 median is still 0.90; **no values changed** by either
item.
**Why:** Ruled by Mike 2026-08-01 in-session ("do the td conservative and marriott open
items") — the last open items from APPLY_REPORT_valuation_index_2026-07-31.md other than
decision item 2 (chart-derived confidence on the RBC Avion rows, still awaiting a ruling).
**Implications:** Suite passes both modes (exit 0, CPP-17 at FAIL severity). Trail:
CardCoachv2 commit `feee2ac`; deltas
`2026-08-01__td-conservative__promo-caveat-resolution.sql` and
`2026-08-01__marriott__pot-fifth-source-band-0p80.sql`; the apply-report ledger annotated
in place (that session's file to land).

### 2026-08-01 — Avion Elite conservative: dual evidence attached; zero-evidence rows extinct
**Decision:** `rbc-avion-points` conservative (1.0000, portal baseline) now carries dual
issuer evidence: Avion Rewards T&C §24 (100 Points per $1.00 CAD outside ION/Core/Select —
the Elite non-schedule baseline; doc 128366, 03/2026) and the Signature RBC Rewards Visa
benefits guide ("Every 100 Avion points is worth $1 CAD for travel"). Value unchanged;
band [1.00, 1.00]. It was the last active issuer-anchored row with an empty evidence set —
it had escaped CPP-17 only because its confidence is medium-high.
**Why:** Ruled by Mike 2026-08-01 in-session ("do the avion conservative evidence row").
**Implications:** Every active row in point_valuations now carries attached, dated
evidence. Suite green both modes. Trail: CardCoachv2 commit `c40ef29`, delta
`2026-08-01__rbc-avion-conservative__evidence.sql`.

### 2026-08-01 — The Stage 1–3 script pipeline is retired; verification is daily scheduled batches
**Decision:** The registry-CSV + `stage2_fetcher.py` + `STAGE3_PROMPT.md` pipeline is
retired. Verification now runs as daily batched scheduled tasks (per-issuer weekday
rotation + Friday chrome lane with Mike present), with evidence, fact checks, learned
issuer state, parking, and write audit in the Supabase `verify` schema. Part 1 of this
file now documents that process.
**Why:** The script was difficult to use on certain websites, and the failure modes were
structural, not fixable with retries: bmo.com bot protection resets the fetcher's
connections outright (noted 2026-07-02 — BMO's whole fact contract was already manual);
cibc.com, PC Financial and Simplii break the fetcher's transport (serve plain HTTP but
block automated rendering); RBC's lineup is client-rendered so plain HTTP returns zero
cards; canadiantire.ca 403s plain HTTP. Spanning those needs three access lanes (plain
fetch, rendered, human-present browser) chosen per issuer — a per-issuer prompt with
learned state, not one Python script. The batches also upgrade cadence (weekly per issuer
vs monthly) at similar total effort, and add disciplines the script never had: sha256
evidence before assertion, grep-guarded quotes, dual confirmation, auto-vs-gated
classification with write audit.
**Alternatives:** Patch the fetcher site-by-site — rejected as an arms race inside one
script, with BMO unreachable regardless. Keep the script for the "easy" issuers and batch
the hard ones — rejected: two parallel processes with different evidence standards is how
data drifts.
**Implications:** `card_sources_seed_enriched.csv`, `stage2_fetcher.py` and
`STAGE3_PROMPT.md` are retired on disk as records (STAGE3_PROMPT carries a retired
banner); on-disk `snapshots/` are superseded by `verify.evidence`. Stage 3's five-section
delta lives on conceptually as gated packages + dated delta files under rule 10.
WORKING_NOTES #2 rescoped (apply-helper now targets parking/gated output), #3 rescoped
(FR-CA verification rides the batches), #4 closed (registry rows retired with the
registry; batch coverage-diff owns discovery). The 2026-04-22 per-litre parking entry
stands for `earn_rates`; per-litre facts additionally gained a canonical `offers` home,
dark, via DATA-018 (2026-08-01). Loyalty-stack reverification and the monthly
fuel-price check ride the batches (WS-5, wired 2026-08-01). The old "never direct
writes to Supabase" note in Part 1 was already superseded by PROJECT_RULES rule 10
(2026-07-29); the batches' guarded auto lane operates under that authority.

