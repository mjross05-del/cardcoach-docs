# CardCoach Pipeline & Decisions

**The reverification process (how it works) + the append-only log of settled decisions.**
This file is the "why things are the way they are" reference. The process section reflects
the current system; the decisions section is **append-only** — add new entries, never
rewrite old ones.

Last updated: 2026-09-02 (Wealthsimple onboarded) · Owner: Mike (data integrity, governance, review)
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
| Sun | Canadian Tire + PC Financial + Simplii + Tangerine + **Wealthsimple** (+ PC/Triangle loyalty reverify) — Wealthsimple added 2026-09-02; the Cowork task prompt's `ISSUER_BATCH` needs the `Wealthsimple` token added by hand |
| Fri 5 p.m. | Chrome lane, Mike present (~15–20 min): BMO coverage + facts, **Neo Financial** (chrome-lane only since 2026-08-30 — its legal host is robots-walled; it was never actually in the Sunday prompt), RBC tier thresholds, in-application FX boxes, Blue Rewards/AIR MILES transition watch |

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
correct it on sight. Offer stacking (`solveOfferStack`) is wired into the V2
production path behind `runtime_flags.loyalty_offer_stacking` — activated 2026-08-02,
production application verified 2026-08-11 by a live probe — offer b0ff0008 applied
at exactly 1.2 percent (transcript: STACKING_CLOSURE_REPORT_2026-08-11.md §2); the public
stateless tool excludes offers by design. *(Sentence corrected 2026-08-11, worklist D-A —
it previously said "not wired … until Alex ships it", superseded by the activation, the
verification, and the lane change. Evidence: WORKLIST_REPORT_2026-08-11.md §I2.)*
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

### 2026-08-12 — Merchant-graph DML is audit-class
**Decision:** All DML against the merchant graph — `merchant_entities`,
`merchant_entity_aliases`, `merchant_entity_places`, `earn_rate_eligible_merchants`,
`merchant_group_memberships` — is audit-class: gated approval plus a
`verify.write_audit` row with `run_id`, same as card-fact and schema writes.
**Why:** The discipline as practiced covered card facts and schema; merchant-graph
DML fell through. Found via the unaudited 2026-08-02 keeper INSERT (`d4a1923b`,
14:09:56Z — author unattributed: no scheduled run was live (cowork run `0393616f`, the
Sunday PC Financial batch, finished 10:36Z; next run started 15:36Z), and the row shares
an exact timestamp with the `Atlantic Superstore` row — a hand batch creating the
spaces-style chain rows `20260802160000` flagged but never inserted; no `write_audit` row
exists for any merchant-table write that day; DESIGN_place_resolution_v1 §1.4 carries the
code-side attribution analysis). Precedent: run `7e2b9c41` (2026-08-12 RCSS dedupe — run
row, in-transaction row-count assertions, audit rows for the DML and both DDL
migrations). **Implications:** Batch prompts and dispatches treat merchant-graph writes
exactly like card-fact writes: pre-flight reads across all referencing FK tables,
old-value/row-count guards, audit row committed in the same transaction.
`verify.runs.runtime` vocabulary gained `'chat'` (migration
`verify_runs_runtime_allow_chat`) so chat-surface gated writes record truthfully.

### 2026-08-14 — Suppression disclosure is decided by the pricing predicate, never a copy
**Decision:** `recommend-card-v2` discloses condition-suppressed earn rows via
`conditionalNotApplied[]`, decided by the same exported `earnRowPrices` predicate that
prices them (`_shared/scoring.ts:1179`), not a second implementation. The field is
absent — never an empty array — when nothing was suppressed, matching the stateless
`ConditionalNotAppliedV1` shape. `categoryMccAssumption` stays null on the authed
merchant path: API-011 is unchanged by this slice.
**Why:** a disclosure gate written as its own copy of the condition logic drifts from
pricing silently, and the failure is invisible in both directions — a user is told a card
"may earn more" on a row that in fact priced, or is never told about one that didn't.
Extracting the predicate makes that drift impossible by construction rather than by
review discipline. **Implications:** ranking is untouched — response fields and two
success-log fields only. Verified on live taps 2026-08-14: Kelsey's disclosed
`c0cfce4c`, RCSS disclosed `f382d9d7`, and no PC Financial grocery row was disclosed
while PC cards priced normally (the mixed-gate case). RCSS `topCardId`/`cardCount`
byte-identical to the same-day pre-deploy baseline. Deployed as `recommend-card-v2` v21,
commit `f1a7158`. Client rendering stays gated on D3 copy.

### 2026-08-14 — A shared-type change owns the edge-function fixtures too
**Decision:** Changing a type in `supabase/functions/_shared/` is not complete until
`supabase/functions/__tests__/` compiles and passes against it. Adding a required field
to `ScoringContext` or `EarnRateRow` means updating every hand-built fixture in the same
commit — the golden packs included.
**Why:** `bfd487e` (ENG-floors, 2026-08-12) added four fields to `EarnRateRow` and
`annualSnapshots` to `ScoringContext`, and touched no file under `__tests__/`. It added
tests for `packages/engine` but the edge-function suite went red and stayed red for two
days: 6 type errors, plus 40 runtime failures on `TypeError: ctx.annualSnapshots is not
iterable` (`scoring.ts:1666` iterates it unconditionally). Those 40 were the **entire
QA-009 loyalty-stacking golden pack** — so the regression guard against ranking drift was
dead, not passing, during a period when ranking-adjacent work was shipping. The failure
mode is self-concealing: once a suite is red, the next red is indistinguishable from the
last, and a dispatch's "STOP on any failure" gate stops gating anything real.
**Implications:** `pnpm typecheck` does **not** cover `supabase/functions/` — it is
`pnpm -r typecheck` over the five pnpm workspaces, and Deno code is invisible to it. The
gates that see edge functions are `deno check <fn>/index.ts` and `pnpm test:supabase`
(`cd supabase/functions && deno task test`, which type-checks `__tests__/` before
running); at least one must be green before an edge-function deploy. When a dispatch's
gate fails, establish whether the failure is pre-existing by re-running against the
pristine file before concluding anything about the change in hand. Repaired 2026-08-14 in
commit `bd88062` (fixtures only, inert defaults: `floor_*_cad`/`category_excludes`/
`window_bucket` null, `annualSnapshots` empty); suite went 216 passed/40 failed + 6 type
errors → 256 passed/0 failed with type-checking on, no golden expectation changed.

### 2026-08-14 — Request paths do not self-heal data; corrections go through gated deltas
**Decision:** A user-facing request path never performs **corrective** DML — no
rewriting an existing row toward a better value as a side effect of serving a request.
Data correction is a gated, audited delta. This generalises the 2026-08-12 audit-class
entry: that entry said merchant-graph DML needs gated approval plus a
`verify.write_audit` row with `run_id`, and a request path structurally **cannot** supply
any of the three — there is no run, no reviewer, and no approval; the write is triggered
by whichever user happens to tap. For a request path the only compliant form of an
audit-class write is not to make it.
**Scope boundary — this is about *correction*, not all writes.** `resolve-place` minting
a `merchant_entities` / `merchant_entity_places` row on a cache miss is the function
doing its job: the request cannot be served without it, and the row is new rather than a
silent revision of someone else's. That question belongs to
`DESIGN_place_resolution_v1` and is untouched here. What this entry forbids is the
self-heal: a read path quietly rewriting stored data it happened to disagree with.
**Why:** the writes are unattributable by construction, and the bill arrives later.
`DESIGN_place_resolution_v1` §1.4 had to reconstruct the authorship of four duplicate
RCSS rows from timestamp fingerprints, ms-precision gaps and normalizer punctuation
styles, because several runtime writers had been live concurrently and none of them
signed their work; `d4a1923b` is still recorded there as "the single event no committed
code explains". A correction that cannot be attributed also cannot be reviewed, reverted
as a unit, or distinguished from a bug.
**Precedent set 2026-08-14:** `recommend-card-v2`'s `default_category_id` write-back
removed (commit `86c6110`, deployed v22); that function now performs no writes at all.
It cost nothing to remove — `categoryId` is still normalized per request, every consumer
normalizes on read, and a live check found all 344 non-null `default_category_id` rows
already canonical with `classifyPlace` unable to emit a non-canonical slug, so the write
was dead code that could only ever fire on data no longer present.
**Implications:** nine sites of the same class remain — `recommend-here-v2` ×6 and
`resolve-place` ×3, catalogued at `DESIGN_place_resolution_v1.md:27` and tracked as
`WORKING_NOTES` #26. They are in scope of this decision but are **not** mechanical
removals: they also write *reclassified* categories derived from live Google place
types, which is real improvement, not just normalization. Retiring them requires first
deciding where reclassification lives instead. Note also that PROJECT_RULES rule 9
("Output is files, SQL deltas, prompts, or docs — never direct writes to Supabase")
governs what a *session* emits; this entry applies the same principle to shipped code on
a request path, which the rule as written did not literally cover.


### 2026-08-14 — The authed merchant path supplies the category-typical MCC assumption
**Decision (Mike, 2026-08-14):** `recommend-card-v2` and `recommend-here-v2` now supply
API-011's category-typical MCC assumption when scoring a resolved merchant, superseding
the original API-011 position that the assumption is "never active with a merchant
supplied." Implemented as the **ordered test** — MCC-mapping intersection primary,
`category_fallback` only for categories with **no** active mappings — NOT the literal
blanket fallback: gas, grocery and dining are all mapped, and a bare fallback beside
mappings is the fail-open widening the stateless implementation documents against.
Gated by `runtime_flags.merchant_mcc_assumption` (shipped false in migration
`20260814213000`, flipped on 2026-08-14 by delta with Mike's chat approval; flip-off is
the no-deploy rollback). Both endpoints move in lockstep because api-008 parity is a
values contract, not just a schema one. The stateless surface is untouched — its
assumption stays caller-opt-in; the asymmetry (server-decided on the authed first-party
surface, opt-in on the anon public one) is deliberate.
**Why:** with no assumption, `earnRowPrices` fails every `mcc_defined` row closed on the
merchant path — 145 live rows across 18 categories priced at base rate on every tap.
Found 2026-08-14 via the Slice 1 disclosure at a literal gas bar: CIBC Dividend VI
showed 1% at an entity correctly categorized `gas`. The accelerator categories are the
product's core claim; systematically understating them at obviously-correct merchants
is the inverse accuracy failure of the one the prohibition guarded against.
**Disclosure invariant:** the disclosure input **is** the scoring input — one predicate,
one assumption object. Rows suppressed stay in `conditionalNotApplied`; rows priced
*because of* the assumption are disclosed per-recommendation (`mccAssumptionApplied[]`)
plus a response-level `categoryMccAssumption {categoryId, test, mccs}`, present only
when it changed at least one card's pricing. Distinct key — `assumptions` is occupied by
fuel (the Slice 5 collision, sidestepped not decided). D3 copy still gates all client
rendering.
**Measured, not assumed (recon of 2026-08-14, before code):** 88 of 145 rows price
under the flip — 65 by mapping intersection, 23 by genuine fallback on the 8 unmapped
niche categories. **57 rows stay dark**, nearly all with `mcc_includes` NULL, which the
shipped predicate correctly fails closed: an `mcc_defined` row that does not declare its
MCCs cannot be verified against any mapping. That is a card-fact data gap (verify lane,
gated), deliberately not papered over in code — CIBC's dining `c0cfce4c` and grocery
`f382d9d7` are in it, so Kelsey's and RCSS keep showing 1% until the backfill lands,
while gas `350c583a` (`[5552]` ∩ `{5541,5542,5552}`) prices immediately.
**Governance implication:** `mcc_category_mappings` writes are now ranking-affecting on
the authed surface **in both directions** — adding the first mapping to a currently
unmapped category flips it from blanket-fallback to strict intersection, which can
*revoke* pricing from NULL-`mcc_includes` rows. Mapping DML is gated-delta work with a
pre-flip recon, same discipline as everything else in this file.

### 2026-08-14 — mcc_includes backfills follow the evidence already on the row
**Decision:** Populating `earn_rates.mcc_includes` on an `mcc_defined` row is governed
by what the row's own `condition_text` — the verified capture from the issuer document —
already contains, in three tiers. **Tier A**, the text cites MCC numerals ("(MCC 5541,
5542)"): populate exactly the cited numbers; this completes ingestion of an
already-captured fact, and matches the pre-existing convention on CIBC Dividend VI gas
`350c583a`. **Tier B**, the text quotes the network's official MCC classification names
verbatim ("grocery stores and supermarkets", "eating places, restaurants", "service
stations", "drugstores/pharmacies"): populate via the deterministic name→number lookup
through the network standard, recording the derivation per row in the delta, and have
the issuer's next weekly batch spot-confirm. **Tier C**, generic prose ("eligible dining
purchases", "as classified by Visa MCC", issuer app-category labels like AUTO TOP-3):
populate NOTHING — assigning numbers there is inventing a card fact (rule 7); the row
goes to the verify lane for an issuer-document pull.
**Why:** the merchant-path assumption (previous entry) made these arrays load-bearing
for ranking, and 67 live rows had them NULL. The line between "moving a captured fact
into a typed column" and "guessing what the issuer meant" is exactly the line between
tiers B and C: name→number through a published standard is deterministic; prose→number
is judgment. Pass 1 (2026-08-14, delta
`2026-08-14__earn_rates__mcc_includes_backfill_p1.sql`, 15 rows: 5×A + 10×B, guarded on
`mcc_includes IS NULL`, rowcount-asserted, audited) took pricing coverage from 88 to
103 of 145 `mcc_defined` rows, verified by post-apply recon. The 42-row residue is all
tier C and stays fail-closed — disclosed as suppressed on every tap — until issuer docs
land. **Implications:** ingestion should populate `mcc_includes` at capture time
whenever either A- or B-tier evidence exists; a backfill delta always enumerates ids,
quotes its evidence per row, and asserts its rowcount; and two Scotia Momentum
"recurring bill" rows are flagged for the batch to reconsider `condition_type` — their
text defines eligibility by billing mechanism, not MCC.

### 2026-08-16 — Neo Financial onboarded as the 16th issuer; plans are products, partner cashback is not an earn rate
**Decision:** Neo Financial joins the catalogue as issuer `neo-financial` with **nine**
`card_products` rows, not five. Neo World and Neo World Elite each ship in three reward
plans — Shop & Dine, Gas & Grocery, Everywhere — sold separately with separate rate
sheets, so **a plan is a product**: a wallet holding "Neo World Elite" is unscoreable
until we know which plan, and collapsing the three onto one canonical row would misprice
two thirds of holders. The same reasoning already governs Rogers Red's tier variants.
**Decision:** Neo's headline "up to 5x at thousands of Neo partners" is **excluded from
`earn_rates` entirely**. It is merchant-funded, varies by partner and offer, and Neo
publishes no per-purchase rate for it — there is no fact to store, and storing an average
would be inventing one (rule 7). It is offers territory if it is anywhere. Verification
batches should not file fact_checks against it.
**Decision:** the caps are Tier 1b and they are on the **compare page**, not the product
pages. Footnote 1 of `/credit-cards` is the single source for every category cap and every
post-cap rate across all seven cashback products; the individual product pages state that a
limit exists and then defer to the Neo app. Post-cap rates equal each card's base rate, so
every capped category is an ordinary falling tier — no new engine behaviour. Neo World
Elite – Everywhere is the one case needing the ENG-floors machinery: two `base` rows with
disjoint windows over `window_bucket='card'` (2% on [0, $4,000), 1% above).
**Decision:** four of the nine land `load_only`, each for a stated reason, and each reason
is a tracked [VERIFY] rather than a judgement call. Both **Shop & Dine** plans, because
their "Shop" and "Food and drink" categories are MCC-defined in Neo's MCC schedule and
that schedule is not yet transcribed — base rates loaded, category rows withheld rather
than guessed. Both **carrier co-brands** (United MileagePlus, Cathay Asia Miles), because
their point valuations fail Tier 2.
**Point valuation — Tier 2 FAILED, recorded as a failure not a gap.** Neither United
MileagePlus nor Asia Miles publishes a cents-per-point value, so Tier 2 applies. Condition 2
does not clear: only **two** independent publishers state a figure in Canadian cents
(Prince of Travel and Milesopedia — 1.6 for MileagePlus, 1.5 for Asia Miles), they report
identical figures with no disclosed method, and the rule says in terms that two sources are
not consensus. Frugal Flyer appears to be a third but its CAD figure is an FX conversion of
its own USD figure and its roundup contradicts its own programme page (1.5 vs 1.6 CAD on
Cathay). Every other recognised source is USD-denominated, and §2a currency discipline
forbids converting. So **no `point_valuations` rows were written** — absent, not estimated.
`reward_programs.default_cents_per_point = 0` on both new programmes is a **fail-closed
placeholder** forced by `reward_programs_cents_per_point_rule`, which forbids NULL on a
points programme; it is not a valuation and must not be read as one. Zero cannot inflate a
ranking, and both cards are `load_only` regardless.
**Why this matters beyond Neo:** the schema cannot currently express "this is a points
programme and we do not know what a point is worth." Every existing points programme
carries a `default_cents_per_point`, so the constraint has never bitten. It bites the moment
a new carrier currency arrives without three CAD sources, which is the normal case for
airline co-brands. Worth deciding whether the constraint should admit NULL.
**Access posture:** `legal.neo.cc` and `static.production.neofinancial.com` are both
robots-disallowed to the cloud fetcher, so every Tier 1 document (cardholder agreement,
disclosure + fee schedule, rewards policy, MCC schedule) is chrome-lane only, while
`www.neofinancial.com` and `cathay.neofinancial.com` are open. Neo is therefore recorded
`wall_status='walled'`, `preferred_channels={chrome_assisted}` — the first issuer where the
*product* pages are open but the *legal* host is walled. Footnotes on neofinancial.com sit
behind a "Legal stuff" accordion and are invisible to `get_page_text` until clicked; that,
not the paywall, was what made the caps look unpublished on first pass.
**Carried [VERIFY] items:** FX percent (unpublished on all nine — `fx_fee_percent` NULL,
following the 2026-08-02 unsourced-FX precedent); the MCC schedule (unblocks both Shop &
Dine plans); the gas/EV shared-pool gap (Neo shares one monthly limit across two CardCoach
categories and `earn_rates` has no pool column, so both rows carry the full cap and a user
splitting spend over-earns in the model); the Amazon half of the retail-shopping exclusion
(merchant-level, no row); and the Cathay 4x `earn_rate_eligible_merchants` row.
**Applied:** deltas `2026-08-16__issuers_card_products__neo_financial_onboarding.sql` and
`2026-08-16__earn_rates__neo_financial_p1.sql`. Snapshots `*_snapshot_20260816_neo`,
RLS-secured. Pre/post guards asserted in both transactions. `verify.issuer_notes` seeded
with the access posture, the accordion quirk, the plan-structure trap and all six open items.

### 2026-08-16 (b) — Neo carrier valuations go live provisionally; "unconfirmed" becomes a storable state
**Decision (Mike, same day, superseding the load_only posture in the entry above):** use the
two matching CAD figures we can actually see — United MileagePlus **1.6**, Asia Miles **1.5**
— mark them unconfirmed, and revisit with a deeper dive. Both carrier cards move
`load_only` → `scoreable`. Neo is now 7 of 9 scoreable.
**How "unconfirmed" is represented, and why it matters:** these rows are stored with
`source_tier` **NULL**, not `'tier2'`. That is not a formatting choice — the database already
enforces the governance rule (`pv_tier2_needs_three_sources`: an active row claiming `tier2`
must carry `source_count >= 3`), so a two-source tier2 row is rejected outright. The
constraint did exactly its job. What was missing was not enforcement but a *vocabulary*: the
table could express "Tier 2 compliant" and could express "absent", and had no way to say
"we are using this, and we know it is not yet good enough." `source_tier` NULL +
`confidence='low'` + `source_count=2` + attached evidence rows + an explicit UNCONFIRMED
banner in `source_notes` is that third state. **Anything reading `point_valuations` for
public claims must filter on `source_tier IS NOT NULL`** — an unconfirmed row is a working
value, not a verified fact, and rule 7 still forbids presenting it as one.
**Only the `realistic` tier is written.** Two identical data points give no basis for a
spread; manufacturing conservative and aggressive figures would invent precision. The engine
already falls back to realistic and warns, so the absence is safe and self-announcing.
**The placeholder problem resolves as a side effect.** `reward_programs.default_cents_per_point`
went 0 → 1.6 / 1.5, so the fail-closed zeros from the previous entry are gone. The underlying
schema gap is *not* closed and will return: `reward_programs_cents_per_point_rule` still
forbids NULL on a points programme, so the next carrier currency that arrives without a
usable figure will face the same forced choice between a fake zero and a fake number. Worth
deciding whether that constraint should admit NULL before the next co-brand, not during it.
**Found on the post-apply probe, worth recording:** both Gas & Grocery plans' `recurring_bills`
rows are `mcc_defined` with no `mcc_includes` and therefore fail closed — correct tier-C
behaviour under the 2026-08-14 evidence-tier decision, but it means Neo's MCC schedule now
unblocks **three** things rather than two: both Shop & Dine plans and both recurring-bills
rows. United's grocery and dining rows do price (MCCs populated and mapped); its flights row
and Cathay's 4x row stay fail-closed for want of an airline-MCC enumeration and an
`earn_rate_eligible_merchants` entry respectively.
**Applied:** delta `2026-08-16__point_valuations__neo_carrier_provisional.sql`, guarded, with
a post-state assertion that no Neo valuation claims `tier2`. Live probe confirms Cathay at
1.5c/$ base and United at 1.2c/$ base (0.75 x 1.6), and Cathay foreign-currency at 3c/$.

---

### 2026-08-16 — Mobile app theme: "2a locked design" superseded by CardCoach Final Spec rebrand
**Decision:** The mobile app's theme tokens (`apps/mobile/src/theme/theme.ts`) and the
pinned values in `brandKit.test.ts` now follow the **CardCoach Final Spec** token card
(`design_handoff_cardcoach_rebrand/CardCoach Final Spec.dc.html`, turn-0 card + final
pass rows `4a` light / `5a` dark). The "2a locked design" palette those tests previously
pinned is superseded. Executed as RETHEME-001 per
`cardcoach-docs/PROMPT_retheme_rebrand_2026-08-16.md`, on the
`feat/api016-app020-tie-disclosure` branch, shipping with APP-020 in 1.0.3.
**What moved:** light headings become indigo ink (`textHeading` token, new); dark body
warms to parchment `#EDE4D6` with ivory reserved for headings; dark muted `#A79D8F`,
indigo accent `#9FB0DE`, money text `#4CC79A`, tangerine text `#F08B63`; Surface 2
`#322A22` dark; bottom bars/sheets get their own `sheet`/`sheetBorder` tokens
(`#FFFFFF` / `#211B15` + ivory 10%); the dock keeps one `#2B3A67` bar in both modes with
a solid-ivory active pill; hairlines go two-tier (10% page / 8% in-card); the gold
pill/ring ramp changes from goldDark→goldLight to gold→goldLight; the dark gold glow
drops to 35%.
**Why:** Mike's instruction in the 2026-08-16 Cowork session (API-016/APP-020):
"rethemed to match the design exactly." The Final Spec card states "Every color in the
mocks is on this card — build from these tokens, nothing inferred."
**Implications:** Card artwork (network gradients, card ink `#FDF8F3`, gold chip) is
mode-independent and did NOT move. Any future color work must trace to the Final Spec
card, not 2a. Structural deltas the frames show beyond color (e.g. the orange "+" FAB)
are logged in the RETHEME-001 report, not built.

---

### 2026-08-16 — Corrections + ratifications (Cowork session, Mike's answers on the open decisions)

**Correction — the orange "+" FAB was never missing.** The RETHEME-001 entry above says
structural deltas like the FAB were "logged, not built." Wrong: `nowV2.recordTransaction`
has existed on the Now screen all along (conditional on the ready state, which is why the
Cowork session's recon — and therefore the retheme prompt — missed it). It opens the
transaction-recording modal and already conforms to the Final Spec: tangerine fill
`theme.colors.primary` #E8734A (mode-independent, per the token card), 56pt, bottom-right.
No follow-up spec needed. Error origin: the Cowork session's prompt, not the retheme run.

**Ratified (Mike, 2026-08-16) — APP-020 tie-frame deviations from the mock stand:**
(1) tie badge/chips are purchase-anchored ("all earn $2.00"), never per-$100 — per-$100
normalization can differ at the displayed cent between tied cards (invariant 13);
(2) receipt member rows are name-only — per-member rate blurbs under "all earn the same"
would contradict the tie header;
(3) rule-1 differentiator copy is tier-anchored, never certainty-ranked (invariant 17).
The mock remains the geometry/color authority; these three content rules supersede its copy.

**Decided (Mike, 2026-08-16) — MCC suppression fix = backfill via verify lane** (not
engine fail-open): the 42 fillable rows go as per-issuer gated deltas after per-card
source-clause checks; the 5 unmapped categories get mcc_category_mappings proposals
covering the last 10 rows. Fail-closed stance on empty mcc_includes is retained.

**Decided (Mike, 2026-08-16) — tie_disclosure flips ON after TestFlight 1.0.3 is live**
and the production probe is green (preconditions in migration 20260816185557). Old 1.0.2
clients strip the fields and render the dense ranking unchanged in shape.

**Decided (Mike, 2026-08-16) — a paid tier is in scope; the receipt scanner is its first
feature.** Supersedes `REVENUE.md` §"What this model does NOT cover" ("Pro tier — out of
scope"), corrected in the same session. Two clarifications of record: the iOS app shipped
**free** (the model's "paid iOS" line is forecast, never run-rate), and the revenue model
contains no paid-tier assumption, so no paid-tier revenue figure may be quoted until the
model is deliberately amended — quoting one would be an invented fact under rule 7.
Specs: `API-017_receipt_parse.md` (server, parse-only, writes nothing), `APP-021_receipt_capture.md`
(mobile, needs a native OCR module so it cannot ship over EAS Update), `ENT-001_entitlements.md`
(the gating primitive). Build stance: complete and inert behind two gates — a global
`runtime_flags.receipt_scanner` and a per-user entitlement. Feature code tests a named
entitlement key, never a "Pro" boolean, so tier name/price/contents stay undecided.

**HELD (2026-08-16) — ENT-001 DDL signed off by Mike, then held unapplied by the executing
session on discovering a collision.** Do not apply `20260816220000_ent_001_user_entitlements.sql`
until the overlap below is arbitrated. The sign-off was given before the collision was known;
this note records why the session did not proceed on it.

The collision: `runtime_flags.online_merchant_resolution` (seeded TRUE, DATA-020/API-018)
carries the note *"the operative gate is the Pro entitlement check in `_shared/entitlements.ts`,
which refuses every caller until the Pro tier ships."* That file did not exist in the repo,
and no entitlement storage exists in the database — `profiles` has no plan column, and no
`user_entitlements` table exists. So **two concurrent lanes were converging on one undefined
primitive at one file path**, with no way to see each other (rule 9(f)). Had both landed, the
second commit would have silently redefined the first lane's paywall — a paid feature served
free, or a free feature returning 403, with no failing test on either side.

Resolution taken: the ENT-001 artefacts (migration, rollback, `_shared/entitlements.ts`, the
mobile `useEntitlement` hook) are parked in `.agent_scratchpad/ENT-001_proposed/`, out of every
live path. `_shared/runtimeFlags.ts` (a generic flag reader, no entitlement semantics) was left
in place as non-conflicting. **Mike to arbitrate one entitlement design across both lanes before
either ships.** ENT-001's proposal, for that decision: `user_entitlements` rows keyed by a named
string, with `source`/`expires_at`/`revoked_at`, RLS read-own and writes revoked from
`authenticated` so a user cannot grant themselves a paid feature.

**INCIDENT (2026-08-16) — remote/local migration drift, rule 9(e) class.** Four migrations were
applied to production (`20260817013135` places_provider, `013156` merchant_domains, `013209`
earn_rates_channel_includes, `013236` runtime_flag) that had no local files at the time of
discovery, alongside a `merchant_domains` table, a `v_active_merchant_domains` view and an
`earn_rates.channel_includes` column. This is the exact failure rule 9(e) documents — remote
history ahead of `supabase/migrations/` breaks `db push` and `db reset` for every other lane.
The originating session appeared to be landing the local files during the same window, so the
drift may already be closed; **verify with `supabase db pull` before the next migration from any
lane**, and confirm all four have local files. Recorded here because no other lane can see it.

**RESOLVED (2026-08-17) — the ENT-001 collision, and a direct answer to the online-merchant
lane.** The hold recorded above is lifted. Mike's instruction (2026-08-16): build and
implement the receipt scanner, Pro-gated.

**To the online-merchant session, answering the question in your `_shared/entitlements.ts`
header ("if the session that removed it did so deliberately, this file is safe to delete
again"): please do NOT delete it. Keep your restored copy — it is now the shared file.**

What actually happened, since your header's reconstruction is close but not quite right: the
file did not vanish to a git race. The receipt-scanner session wrote it, then deliberately
moved it to `.agent_scratchpad/ENT-001_proposed/` on discovering that
`runtime_flags.online_merchant_resolution` already declared a Pro gate at that exact path
with nothing built behind it. Two lanes were converging on one undefined primitive and could
not see each other (rule 9(f)); parking it was the safe move, not a deletion. Your restore
was the right call and your version is now canonical — it is a strict superset (both
`receipt_scanner` and `online_merchant` keys), so the receipt-scanner lane has adopted it
rather than reinstating its own. **One file, one design, two keys. Neither lane should
rewrite it; add keys only.**

One behavioural change you should know about, because it touches your gate: **the ENT-001
schema is now applied.** Your header notes that while the schema was unapplied "the relation
does not exist, every call takes the error path, and every caller is refused." That was true
and is no longer how the refusal happens. `v_active_user_entitlements` now exists and returns
zero rows, so `hasEntitlement` still returns false for every caller — **identical refusal,
reached through the success path instead of the error path.** Your gate is unchanged in
behaviour; what changes is that it stops emitting an error log per call, and that a grant can
now actually be issued. `resolve-merchant-v1` needs no edit.

Granting access before billing exists (both lanes, service role only):

```sql
INSERT INTO public.user_entitlements (user_id, entitlement_key, source, expires_at, note)
VALUES ('<uuid>', 'online_merchant', 'manual', now() + interval '90 days', 'tester');
```

Two keys stay independently grantable on purpose, per D1: the receipt scanner and online
mode can be priced, bundled, trialled or withdrawn separately without either feature's code
learning what a tier is.

---

### 2026-08-26 — Robots-disallowed issuer documents ARE usable as evidence (both redirect shapes)
**Decision (Mike, 2026-08-26):** when the requested path is robots-allowed but the fetch
resolves into a disallowed location, the artifact **is usable as issuer evidence**. Robots
governs crawling; a single fetch of a linked legal document a customer is expected to read is
not crawling. The ruling covers **both shapes**, which had been treated as one problem and are
not:
- **Same-host prefix** — an allowed path 302s into a disallowed prefix on the same issuer host
  (Tangerine `/content/.../wec_fee.html` → `/en/static/widgets/wec_fee`, `Disallow: /en/static`).
- **Cross-host blanket** — an allowed host 302s to a separate document host whose robots.txt is
  `Disallow: /` (Neo `legal.neo.cc/*` → `static.production.neofinancial.com`).

**Why it was needed:** these were logged as separate issuer quirks, so the engine failed closed
and re-derived the same dead end weekly — Tangerine World Elite `fx_fee_percent` for four
consecutive runs. The document search was genuinely exhausted first: six issuer PDFs including
the 2026-04-22 cardholder agreement were downloaded and text-searched on 2026-08-25 and none
states a rate; both cardholder agreements defer to an account-specific Disclosure Statement
Tangerine does not publish. There was no better document to find, so this was a policy question
or nothing.

**Applied same day, through the gated path — a ruling is not a write authorisation:**
`verify.apply_queue` **e98beb56**, approved by Mike by name, applied under run
**d3da1bac-b11a-4bad-8441-071498fbfb23**, apply_session `5e348a00`, write_audit
**9dd55489-660a-4bba-b88f-7270091802ae**, rule-1 snapshot
`public.card_products_snapshot_apply_20260826`. `ca_tangerine_rewards_world_elite_mastercard`
`fx_fee_percent` NULL → **2.50**, guarded on `fx_fee_percent is null`, `rows_affected` 1.
Active cards with NULL FX: 41 → 40.

**Evidence quality, recorded honestly:** single artifact. The `wec_fee` widget body never names
the card. Attribution rests on the lineup link labelled "Tangerine Rewards World Elite
Mastercard" pointing at `wec_fee.html`, plus the `$120 primary / $30 authorized-user` rows
inside that same fee table matching `annual_fee_cad = 120.00` on the card. Both Tangerine
Money-Back cards were confirmed at 2.50 in the same run **from allowed sources**, so 2.50 is
Tangerine's issuer-wide rate, not an inference from one page. Evidence `cef00a23`, sha256
`a4df8a85ec509b4e…`, in `verification-evidence`.

**Scope discipline — what this does NOT fix.** 41 of 148 active cards had `fx_fee_percent` NULL
(Amex 13, TD 12, MBNA 6, RBC 6, Scotia 2, BMO 1, Tangerine 1). **Only Tangerine's cause was
ever diagnosed.** This ruling closes Tangerine, unblocks Neo currency checks, and sets the
precedent for whichever of the remaining 40 turn out to share the shape. It is not a 41-card
fix and must never be quoted as one. Diagnosing the other 40 is open work (WORKING_NOTES).

**Also recorded:** `verify.parking` `396e93c4-a9de-4f0d-849a-50dc3ea57dd9` closed
(`status = closed_by_ruling`); `verify.issuer_notes.quirks` updated for **Tangerine** (the
08-16 and 08-23 notes removing WE FX from the retry list are superseded — it goes back on the
normal rotation) and for **NeoFinancial** (the whole legal corpus is now currency-checkable;
next Neo run re-checks the June-2025 agreement and rewards policy against a 2026-06-01
disclosure). `RUNBOOK_verify_batch.md` §3.6 carries the operative rule.

---

### 2026-08-26 — MCC brand-code blocks are enumerated, not represented by a head code
**Decision (Mike, 2026-08-26):** when an issuer's terms name an MCC **brand block** as a range,
the range is **enumerated** into `mcc_includes`. Not a head-code stand-in, not a new range type
in the schema.

**Applied same day:** both Tangerine Money-Back cards' `hotels_motels` rows go
`{7011}` → `{3500..3828, 7011}` = **330 codes**, per Money-Back program terms §7
*"Hotels-Motels … (MCC 7011, 3500-3828)"*, sourced from the corrected `mb_rewards_terms`
doc_location. `verify.apply_queue` **867c3106**, `origin = 'convention_ruling'` (no fact_check
by design — the ruling is the whole case), write_audit
**37ec79ef-2ad2-48b7-af74-ac17b2136ead**, `rows_affected` 2, rule-1 snapshot
`public.earn_rates_snapshot_apply_20260826`.

**What this changes today: nothing about pricing.** `hotels_motels` has **zero** rows in
`mcc_category_mappings`, so the assumption side has nothing to intersect regardless of what the
row holds, and both cards are `load_only`. The write makes the row *true* now and *correct* the
moment the category gets mapped.

**The precedent this sets, stated so nobody has to rediscover it:** this is the first enumerated
brand block in the schema. The existing convention was the opposite — `mcc_category_mappings`
represents `travel` with MCC 3000 "Airlines" (head of the 3000-3299 airline brand block) plus
3009 "Air Canada", five rows rather than three hundred. **That mapping is now inconsistent with
this ruling.** Bringing the airline block into line means ~300 more integers on `travel`. Filed
as open work, not done here, and deliberately not left implicit.

---

### 2026-08-26 — Per-source fetch cadence dies with the retired registry
**Decision (Mike, 2026-08-26):** per-issuer weekly rotation is sufficient. The retired Stage 2
registry's `fetch_cadence` column (monthly for product pages, quarterly for Tier-1 PDFs) gets
**no successor** — no expected-revision-interval field on the evidence or fact-check row.

**What we accept by deciding this:** every fact inherits its issuer's rotation slot regardless of
how volatile its source is, and "when does this fact expire?" remains answerable per issuer, not
per fact. The error runs in the safe direction — weekly rotation **over**-checks the quarterly
PDFs rather than under-checking the monthly pages.

**Recorded so it is not re-raised as an oversight.** The concept was considered on its merits and
dropped deliberately. Reopen it only if a user-facing "verified as of" claim needs to be per-fact
rather than per-issuer, which is the one thing the missing column would actually buy.

---

### 2026-08-26 — Stored source URLs get a drift signal: sha256 AND issuer revision date
**Decision (Mike, 2026-08-26):** each `verify.issuer_notes.doc_locations` entry records, beside
the URL, both a **sha256** of the fetched bytes and the **issuer-stated revision/effective date**
of the document. Detection becomes mechanical instead of procedural.

**Why both, not either.** They catch different failures. The sha256 catches *"the file changed
under a stable URL"* — a silent in-place revision. The revision date catches *"the index now
links a different vintage than what we stored"* — which is the failure that actually occurred:
on 2026-08-25 three Tangerine `doc_locations` entries pointed at superseded revisions and **all
three returned 200**. The Money-Back program terms were the September 2024 revision, predating
the 2025-10-25 amendment that added the Foreign Currency Spend, Fitness and Sports Clubs and
E-Games categories. Nothing broke — `earn_rates` already carried the post-amendment categories —
but the next Tangerine run would have reconciled live facts against year-old terms, and a false
"changed" on three categories was one run away. Issuers leave old revisions served indefinitely,
so the 404 that the engine watches for never fires.

**This supersedes nothing in RUNBOOK v1.4 — it mechanises it.** §3.2 (a hint that resolves is not
thereby current) and §9.1 (re-validate every cited entry at close, mark dead ones `DEAD <date>`)
remain in force and remain the fallback where a document states no revision date. The judgement
recorded in the ruling: v1.4 is a procedural control on an agent's diligence, and the manual
37-URL sweep that proved the point does not scale to weekly.

**The honest cost, accepted:** two more fields to keep truthful, and **a stale sha256 is its own
kind of lie**. §9.1 therefore requires that a run which cites an entry either refreshes both
fields or marks them unverified this run — carrying a sha256 forward untouched while claiming the
document was checked is the failure mode this creates, and it is worse than having no field.

---

### 2026-08-26 (addendum) — sizing the robots ruling honestly: it diagnoses to ZERO extra cards
Recorded the same day as the ruling above, because the ruling is easy to oversell and the
sizing work was done immediately rather than deferred.

**40 of 148 active cards still carry `fx_fee_percent` NULL** after the Tangerine close (Amex 13,
TD 12, MBNA 6, RBC 6, Scotia 2, BMO 1). Every one of the 40 was checked against
`verify.fact_checks`: **none is robots-blocked, and none was never attempted.** The robots ruling
fixed exactly one card and opened one issuer's document corpus. It is not a 41-card fix and must
not be described as one.

What the 40 actually are:
- **Deliberate rule-7 withdrawals, correct as NULL.** Two audited sweeps pulled unsourced `2.50`
  values — 2026-08-02 (15 cards) and 2026-08-16 17:51 UTC (Mike-approved, in `verify.write_audit`,
  covering TD, Amex business, RBC More Rewards, Scotia GM and Tangerine WE). The pattern in both:
  the cited clause describes the **conversion mechanism** ("we will convert it to Canadian currency
  at an exchange rate determined by the payment network") and never states a percentage. The 2.50
  had been pattern-matched rather than read — the same correlated dual-pass failure behind the
  2026-07-27 Amex error corrected on 07-28.
- **RBC 6 — #23a staleness, and explicitly NOT a robots case.** Their evidence is per-card InfoBox
  PDFs inside the application flow; the blocker is the standing no-application-flow rule. The
  robots ruling does not reach them. They belong to the Friday chrome lane, whose charter already
  names "in-application FX boxes".
- **Scotia 2** — pass disagreement plus unreachable public product pages (404s): a URL problem.
  **BMO 1** — legacy card behind the domain bot wall. **2 USD-billed cards** are NULL by the
  2026-07-29 USD convention, not by failure.

**The one actionable finding:** 10 of TD's 12 NULL cards are `scoreable` with
`application_status = 'open'` — live cards whose FX cost the engine cannot price. That is the
largest block of live FX blindness in the catalogue, and it is blocked only on finding a TD
document that states a rate.

### 2026-08-28 — Identity moved off card.coach: cardcoach.ca is now the Google Workspace primary domain (Mike)
**Decision:** The Google Workspace tenant's primary domain moves from `card.coach` to `cardcoach.ca`, and every user is renamed onto the new domain. `card.coach` is retained indefinitely as a secondary domain so no address that has ever been published stops delivering. This completes, on the mail side, the canonical-domain flip decided 2026-07-08 — that entry moved the web and the published contact address but explicitly left mail routing unresolved.
**Why:** The published brand, the site, the app-store listings and the contact address are all `cardcoach.ca`; the mailbox and every third-party account login were still `card.coach`. Mike ruled a full swap over an alias-only arrangement so outbound mail matches the brand by default rather than by exception.
**Implications:**
- `cardcoach.ca` added as a secondary domain and verified instantly against the pre-existing `google-site-verification` TXT, then promoted to primary. `card.coach` auto-demoted to secondary.
- All four users renamed, each keeping the old address as an auto-created alias: `mike@`, `marketing@` (Jolayne), `mikayla@`, `welcome@`. Passwords unchanged; sign-in address changes.
- **`hello@cardcoach.ca` was never a mailbox** — it was a Cloudflare Email Routing rule forwarding to `mike@card.coach`, i.e. receive-only, so replies to the address published on the Play listing, the site footer, the privacy page and the deletion page went out from a personal address. It is now a real Workspace alias on Mike's account and can send. `support@cardcoach.ca` added for parity with the existing `support@card.coach`.
- **`hello@card.coach` did not exist anywhere in the tenant** — not a user, not an alias, not a group. Mail to the address the April-era marketing site published had been bouncing. Created as an alias on Mike's account.
- DNS on `cardcoach.ca`: Cloudflare Email Routing disabled (which also removed its MX, its SPF and its `cf2024-1._domainkey` record), Google MX written, SPF republished as `include:_spf.google.com`, DMARC added at `p=none` (there was none).
- **DKIM turned on for both domains.** `card.coach` had no `google._domainkey` record at all, so every message the org has ever sent was unsigned — a pre-existing deliverability weakness, not one this migration introduced. Both domains now sign with 2048-bit keys, verified resolving publicly before authentication was started.
- Google-linked services carry across untouched because this is a rename, not a new account: Play Console (org account), Google Cloud org `card.coach` / `334345136383` including the 2026-08-24 project-scoped org-policy override and the Play service account, Firebase, Search Console. No re-permissioning was needed or done.
- Sequencing that matters if this is ever repeated: create the destination addresses in Workspace **before** flipping MX, or mail to the published support address drops; rename your own admin account **last**, because that ends the console session.

### 2026-08-28 — Revenue model v3 replaces Phase 4 v2; pricing moves to a two-tier ladder (Mike)
> **SUPERSEDED IN PART by the two 2026-08-28 revision entries below.** Every *model* correction recorded here still stands and the log is append-only, so nothing below this line is edited. But this entry's pricing recommendation (the Plus/Pro ladder) is withdrawn, and its figures are computed against it. Read these as historical: headline net **−$5,996** (now −$6,562), **+$13,981** at 27.3% growth (now +$13,026), sensitivities **+217% / +70% / +53%** (now +235% / +62% / +57%), trial **+5.3%** and Apple SBP **5.3%** (now +4.4% and +4.5%), break-even **21.4%/mo / 9,521 / 87x / 54 signups** (now 21.9% / 10,394 / 94x / 69), and web-affiliate share **53.6%** (now 59.2%). The current figures are in `REVENUE.md` and are printed by `model_v3/final_numbers.py`.
**Decision:** `CardCoach_Phase4_Revenue_Model_v2.xlsx` and every figure derived from it are retired. `CardCoach_Revenue_Model_v3.xlsx` and the rewritten `REVENUE.md` are the model of record. The recommended price structure becomes a two-tier ladder — **Plus $3.99/mo, $29.99/yr** (`unlimited_cards` + `auto_location`) and **Pro $9.99/mo, $79.99/yr** (all six entitlements) — replacing the single `cardcoach_pro` tier at $4.99/$39.99 configured in BILL-001. Full working: `PRICING_TIERS_2026-08-28.md`. Every figure in both documents is printed by `01_CORE/data/model_v3/final_numbers.py`; quote nothing that script does not produce.
**Why:** Mike asked for the model to be checked against recent information and for multiple price tiers to be weighed. The check found v2 wrong on five assumptions simultaneously, all in the same direction, and the pricing work found the shipped configuration ranks last or next-to-last of ten structures at every elasticity tested.
**Provenance rule applied:** the Python port in `01_CORE/data/model_v3/legacy_check.py` reproduces v2's published $113,441 / $60,918 / $45,848 / $6,675 **to the dollar** before any assumption was altered, and the v3 workbook and Python model agree on all nine shared tier scenarios after LibreOffice recalculation (the tenth, the lifetime SKU, is Python-only — the workbook's T8 row is T3 without it). Nothing below is a re-estimate of a number that was never reproduced.
**What was corrected, and on what evidence:**
- **Traffic.** v2's visit column ran 100 → 25,650/mo, which is 27.3% compounding for 24 consecutive months, hardcoded rather than exposed as an assumption. Measured Canadian traffic is **3 / 3 / 5 visits** on 2026-08-25/26/27 (Cloudflare `httpRequestsAdaptiveGroups`, `clientCountryName = CA`, `sum.visits`) — about **110/month**. Canada is the **4th** request origin behind NL, US and FR; most remaining traffic is WordPress vulnerability scanning against a site that is not WordPress.
- **Approval rate 60% → 38%** (CFPB, unsolicited online applications). US proxy; no Canadian issuer publishes approval rates.
- **Commission $65 → $142.50**, the only correction in CardCoach's favour. Fintel Connect's live Scotiabank brand page publishes **$110–175 CAD per approved credit card**; v2's $65 traced to a Fintel article whose supporting data is 2017–2021.
- **NEW: issuer coverage, set at 40%.** v2 paid a commission on every approval. Fintel carries RBC, Scotiabank, Tangerine, Neo, Simplii and Vancity — **not** TD, CIBC, Amex, MBNA, Home Trust, Brim, PC Financial, Rogers Bank or Desjardins. National Bank's Fintel page now 404s.
- **Churn.** v2's 12%/mo monthly and 3.5%/mo annual replaced with **cohort survival** — the correction v2's own "what this does not cover" section asked for — calibrated to RevenueCat's published Utilities medians (57% monthly first-renewal, 35% annual), landing 12-month monthly retention at 10.85% against a published 11% median.
- **NEW: free app users earn affiliate revenue.** v2 credited in-app affiliate only to paying subscribers, which silently biased every pricing comparison toward paywalls.
- **NEW: trial length is a model input**, driven by RevenueCat's trial-to-paid medians by trial length.
**Consequences to hold in mind:**
- **The headline moves from +$101,441 to -$5,996 over 24 months.** Do not quote v2's figures anywhere from today, including to Alex, in any investor-facing material, or in the valuation index. **But read that -$5,996 as one scenario, not a forecast of failure and not an assumption of zero growth** — the base case compounds traffic 15%/mo and signups 12%/mo. At the 27.3%/mo growth v2 itself assumed, this corrected model returns **+$13,981**; break-even is at **21.4%/mo**. v2's error was not optimism about the destination but that one hardcoded spreadsheet column was carrying the entire result while every other assumption leaned the same way. The model's useful output is the growth rate required, not the dollar figure at any one rate.
- **The sensitivity ranking inverted.** v2 named monthly churn the most-leveraged variable; at real scale it ranks 13th of 14, because there is almost no base to retain and the first annual renewal lands at M16. Traffic growth (+217%), app signup growth (+70%) and affiliate coverage (+53%) are the top three.
- **Cumulative break-even needs 21.4%/month traffic growth — 9,521 visits/mo by M24, 87x measured — or ~54 app signups/month from M1 against 15 measured.** No pricing structure reaches profitability inside 24 months; the whole worst-to-best spread is 22.1%.
- **`REVENUE.md`'s "Pro tier — out of scope" section and the 2026-08-27 price-drift note are both closed** by this entry. A paid tier is in scope, priced, and modelled.
**How the recommendation was selected — and a bug found in the selection:** the pick is made on the **efficient frontier of (conversion, revenue)**, not on any single elasticity column, because the revenue leader is a different structure at each of the three elasticities (T8 at e=0.4, T6 at e=0.8, T7 at e=1.3). **R is the only structure of the ten on the frontier at all three**, never more than 3.8% behind the leader while converting better than anything that beats it. T6 (Plus $4.99 / Pro $11.99) earns 1.1% more at e=0.8 and is the honest alternative if near-term revenue is preferred to base size.
An earlier run of this model had the **hard paywall (T9) topping every column, and that was a defect**: `tiers.py` applied the 2.6x hard-paywall conversion multiplier *and* the 1.6x gate lift to the same scenario, when a hard paywall has no free tier for `card_slot_limit` or `auto_location_gate` to gate. Corrected, **T9 loses at every elasticity** ($5,876 / $5,553 / $5,205 against R's $6,097 / $6,004 / $5,969) while wiping out $838 of the $885 free-user affiliate stream — 14.0% of total revenue (web affiliate, 53.6%, is untouched by a mobile paywall). It would have been rejected anyway — it contradicts the commission-blind trust position the tie-ordering rule exists to protect, and would strand 82 accounts and 50 comped testers — but the number no longer requires that argument to carry it. Recorded rather than quietly fixed.
**Cheapest actions this produced, in leverage order:** submit the Fintel Connect and CJ applications (links have been live and unmonetised since 2026-08-11); apply to **Milesopedia Network**, the only route found to TD/CIBC/Amex/MBNA/PC/Rogers, worth coverage 40% → 70% = **+53%**; ship Android to production; take the Apple account decision (~3% cost per four months of slip); flip `card_slot_limit` and `auto_location_gate` (+60% conversion, two booleans); change the trial from 7 to **14 days** (+5.3% for a dropdown change in App Store Connect); enrol in Apple's Small Business Program (free, worth 5.3%).
**Left open deliberately:** the elasticity is **swept (0.4 / 0.8 / 1.3), not known** — no CardCoach price test has been run. Only M1 traffic (110) and M1 signups (15) are measured; **traffic growth, signup growth, web→signup, free-user retention and the 1.6x gate lift are all judgment**, and the gate lift is the least-supported figure in the model — its source only bounds it above. The demand anchor mixes currencies and categories (RevenueCat's global USD Business-category median applied at a CAD price; retention from Utilities; neither report breaks out Finance). Engaged-per-visit, click-to-affiliate and application-start are carried unvalidated from v2 — **no published Canadian credit-card comparison funnel benchmark exists**, searched for specifically. The $500/month burn is inherited from v2 and unaudited. No lifetime SKU is recommended yet: at 3x annual it is revenue-negative past roughly year three. The workbook's Sensitivity sheet is a static readout, not live formulas.

### 2026-08-28 (revision, same day) — pricing recommendation corrected to Free + Pro; the "Plus" tier is withdrawn (Mike)
**Trigger:** Mike, reading the recommendation above: *"why aren't we looking at free and pro tiers"*. He was right on both counts, and the earlier entry is superseded on the pricing question only — every model correction it records still stands.
**Decision:** the recommendation becomes **Free + Pro, the structure that already exists** — Free holds up to **3 cards** with manual place selection; **Pro is $7.99/mo, $59.99/yr** and grants all six entitlements exactly as `billing_tiers` seeds them today. The Plus $3.99 / Pro $9.99 ladder is **withdrawn** and parked until Pro has sold something.
**Two errors this exposed, both recorded rather than quietly fixed:**
1. **A tier was invented.** `public.billing_tiers` holds **exactly one row — `pro`**; Free is the absence of it. A "Plus" tier needs its own tier row and `provider_entitlement_id`, a second RevenueCat entitlement and offering, two more store SKUs, and paywall rework to render and compare two tiers (it renders one). None of that was priced against what the tier buys.
2. **The entitlement count was wrong throughout.** There are **six**, not five: `ambient_widget`, `auto_location`, `online_merchant`, `receipt_scanner`, **`statement_import`** and `unlimited_cards`. Five are visible — `online_merchant` is `is_active = false` until APP-022 ships. Corrected in all three documents.
**What the ladder actually buys, now that it has been priced:** **−4.1% / +5.9% / +9.6%** across e = 0.4 / 0.8 / 1.3. It is not reliably positive; at low elasticity a well-set Free/Pro beats it outright. That is not a case for building a second SKU before the first has taken a dollar.
**What the analysis had been missing:** the earlier work collapsed the whole Free/Pro boundary into a single 1.6x "gates on" multiplier, which cannot answer *where the line should sit*. Decomposed — `lift = 1 + cap_pressure(cap) × 0.60 + (auto-location gated ? 0.28 : 0)`, with `cap_pressure` **measured** from `public.user_cards` and the two coefficients calibrated to reproduce the same 1.6x — the finding inverts:
- **The Free/Pro line is worth more than the price.** Everything-free → 3-card cap + gated auto-location is **+8.1%** at a fixed $4.99. Moving $4.99 → $11.99 at a fixed free shape is **+2.7%**. And the line costs nothing to move: both flags exist and are off.
- **Today's configuration ($4.99, everything free) is $4,973; Free/Pro with the gates on at $7.99/$59.99 is $5,438 — +9.4%, with zero new billing infrastructure.**
- **3 cards, not 2.** The 2-card cap earns more at every retention penalty tested, but the margin over 3 narrows from 1.9% to 0.9% as the penalty rises, it strands **17 of 32** existing card-holding users against 8, and an app whose pitch is *which of your cards should you use* barely functions at two. `free_card_slot_limit()` = 3 is well chosen and stays.
- **$7.99, not the revenue-maximal price.** The maximiser swings from $4.99 at e = 1.3 to $11.99 at e = 0.4. $7.99 has the best worst-case rank (4th) of any price across the sweep — it is the price that does not require knowing the elasticity. $8.99 is the honest alternative (0.5% better on the mean, 5th at worst).
**Record:** `PRICING_TIERS_2026-08-28.md` §5A and the rewritten §5; `REVENUE.md` §3; model in `01_CORE/data/model_v3/free_vs_pro.py`. That script applies a free-user retention penalty the tier grid and the workbook do not, which makes it **1.64% more conservative** on the same configuration ($5,438 vs $5,527 at $7.99/$59.99 with a 3-card cap). The gap scales with how hard the cap bites — 2.12% at a 2-card cap, 0.00% with no cap — which is exactly the point: it is what stops a harsh cap looking free. It changes no ordering. Use the tier grid for cross-structure comparisons and `free_vs_pro.py` for Free/Pro line decisions; the planner artifact applies the penalty to every gated structure, so its ladder rows read ~1.5% below the tier grid.
**Left open:** the 0.60 cap coefficient and 0.28 auto-location coefficient are judgment — only `cap_pressure` is measured. They are calibrated to a 1.6x that is itself judgment bounded above by RevenueCat's 5.1x hard-vs-soft paywall gap. The first 60 days after the flags flip is the cheapest validation available, and it tests the single least-supported number in the model.

### 2026-08-28 (second revision) — the ladder comparison was rigged; corrected, and the case restated as sequencing
**Trigger:** an adversarial verification pass on the revision above. Two of its arguments were wrong in a way that inverted their conclusions. Recorded rather than quietly patched, because the first revision made the same class of error the entry above criticises.
**What was wrong:**
1. **The ladder was compared against a configuration the same document rejects.** "Best Free/Pro" in that comparison was the **2-card cap at $11.99** — §5A rejects the 2-card cap (strands 17 of 32 users) and $11.99 (falls to 7th). Against the actual recommendation, on the same basis and same free-tier shape, the ladder is worth **+5.0% / +8.8% / +14.2%** — **reliably positive at every elasticity**, the opposite of the "not reliably positive" claim. A second cause: `free_vs_pro.py` compared a penalised Free/Pro against an unpenalised ladder, worth ~1.5pp more in the ladder's favour. Both fixed; the comparison now runs both sides through the same function.
2. **The hard-paywall rejection was restated as a numbers argument when it is not one.** Corrected for the gate-lift stacking bug, T9 still **beats** the recommended Free + Pro at every elasticity (+2.6% / +2.1% / +1.1%). The earlier line "the number no longer requires that argument to carry it" is **withdrawn**. The rejection rests entirely on the qualitative case — the install penalty the model cannot see, the commission-blind trust position, 82 accounts and 50 comped testers — and §4 now says so.
3. **"$7.99 has the best worst-case rank" is an artifact.** Revenue is monotone increasing in price at e = 0.4 and 0.8 and decreasing at e = 1.3, so with reversed orderings the **median of any price grid always minimises the worst rank**. Re-run on other grids the "winner" moves to the new median every time ($6.99 on {4.99…8.99}, $9.99 on {5.99…13.99}). The criterion selected the middle of the list, not a property of $7.99. Withdrawn. **$7.99 is now stated as a judgment** — a mid-market point below every comparable, with room to raise — not an optimum. What survives is that the revenue-maximal price swings from $4.99 at e = 1.3 to $11.99 at e = 0.4, so no price is optimal without an elasticity nobody has measured, and the whole range is worth 3.7% on the mean.
**Does the recommendation change? No — but its justification does.** Free + Pro at $7.99/$59.99 with a 3-card cap and gated auto-location still ships first, on **sequencing**: nothing has ever been sold, the conversion rate that decides whether a ladder pays is swept rather than known, Free + Pro needs no new billing infrastructure, and the Apple account decision already gates every subscription dollar. **The ladder is worth coming back for once Pro has sold something** — that is now the recorded position, replacing "not worth building."
**Figures rebased from the withdrawn ladder to the recommendation** (they had been changed in one document and not the others): break-even **21.9%/mo, 10,394 visits, 94x, 69 signups/mo** (was 21.4 / 9,521 / 87x / 54); affiliate coverage at 100% nets **−$414**, not +$329 — it cannot reach break-even alone; trial 14-day **+4.4%**, 30-day **+11.8%**, 3-day **−3.1%** (was 5.3 / 14.4 / 3.7); Apple SBP worth **+4.5%** (was 5.3%); 2-vs-3-card margin **1.75% → 0.75%** across the penalty sweep (was 1.9 → 0.9); $8.99 earns **0.65%** more on the mean (was 0.5%).
**Provenance fixed.** `final_numbers.py` had been left computing the withdrawn ladder while both documents claimed it printed every figure they quoted — a violation of this log's own rule from the entry above. It has been rewritten to compute against the recommended configuration and now prints the headline, the honest ladder and paywall comparisons, the full sensitivity table, the growth and break-even solves, the price grid with its artifact warning, the Free/Pro line table, and the basis note. §3's ten-structure grid comes from `tiers.py` and §5A's grid from `free_vs_pro.py`; each document now says which.
**Left standing deliberately:** §3's ten-structure table remains on the tier-grid basis **without** the free-user retention penalty, so its gated rows sit 0.4–2.1% above the equivalent §5A figures ($5,529 against $5,438 for the same configuration). Disclosed in place rather than reconciled, because the two bases answer different questions — comparing structures against each other, versus deciding where the Free/Pro line sits.

### 2026-09-01 — Apple account path decided: new CardCoach Inc. Organization membership + app transfer from Alex (Mike)
**Decision:** The iOS app leaves Alex's Individual team `AF887JD7ZG` by **app transfer** into a **new Organization membership owned by CardCoach Inc.**, with Mike as Account Holder. Alex initiates the transfer once the new account is active. In-place Individual→Organization migration is rejected (no published timeline; accounts reported locked for weeks). Store subscription products are created **only after** the transfer, on the receiving team — never on `AF887JD7ZG`.
**Why:** `RUNBOOK_pro_go_live_2026-08-24.md` §1 — Apple pays the enrolled party, so selling on the current team routes 100% of iOS revenue to a 24% shareholder personally. Transferring while the app is free avoids the shared-secret handoff, the IAP-status transfer gate, and the pending-transfer pricing freeze.
**Implications:**
- Mike's items, in this order: D-U-N-S for CARDCOACH INC. (long pole, ~7 business days), Organization enrolment, Paid Apps Agreement + banking + W-8BEN-E to **Active**; separately a **Google Payments merchant profile** (Play Console refuses to open the Subscriptions page without one — found today).
- Alex's items: TestFlight off + Test Information cleared, Xcode Cloud data removed, SIWA transfer identifiers generated, Transfer App to the new Team ID. **11 Sign-in-with-Apple users** must be migrated within Apple's 60-day window after acceptance.
- **Nobody creates an app record for `com.cardcoach.mobile` on the new team** — it would block the transfer. `ascAppId 6757937693` is unchanged after transfer; `appleTeamId` in `app.config.ts` changes.
- RevenueCat state as of tonight: project `proj58aeb9b3`; entitlement `cardcoach_pro` (matches `billing_tiers`); Play app + products `cardcoach_pro:monthly` / `cardcoach_pro:annual` attached; `default` offering = `$rc_monthly` + `$rc_annual` (auto-generated `$rc_lifetime` removed). **App Store app cannot be created until the new team issues an In-App Purchase `.p8` key** — RevenueCat hard-requires it at save.
- **Android product shape changes from BILL-001's text:** one Play subscription `cardcoach_pro` with base plans `monthly` and `annual` (Google's current model; RevenueCat ids are `subscriptionId:basePlanId`). iOS keeps `cardcoach_pro_monthly` / `cardcoach_pro_annual`. Safe because the webhook grants by entitlement id and only records `product_id`.
- Prices are the 2026-08-28 decision — **$7.99/mo, $59.99/yr, 14-day trial** — not the $4.99/$39.99/7-day figures the two older runbooks still print.
- `cardcoach.ca/terms` is a 404 and `/privacy` is an overview; both are App Review inputs for a subscription app.
- Record: `RUNBOOK_store_accounts_and_revenuecat_2026-09-01.md`.

### 2026-09-02 — Full review lane: findings resolved in one pass; one lane from here (Mike)
**Trigger:** Mike asked for a thorough review of the app, engine, edge functions, database, site, docs and ops after months of solo work with Claude runtimes, then: "prioritize, plan, and resolve these issues one by one — this is your lane", and later "assume the work of the Opus lane, I'll retire it" (all other runtimes stopped 2026-09-02).
**Record:** `REVIEW_full_2026-09-02.md` (26 findings, 19 to-dos) and its artifact; commits on monorepo `main` `141d32b`…`0ac6b3f`; docs repo this commit.
**Decisions and what landed:**
- **Views are `security_invoker`; API roles cannot write catalog tables** (SEC-001, applied and verified in production). Anything that needs a write grant is enumerated in the migration; nothing else gets one.
- **The engine reads `card_caps`** (CAPS-001). Pooled, annual and whole-card caps now bind ranking; `card_caps` wins over an inline earn-row cap on the same axis; Rogers subscriber-uplift caps and dual-cap second legs are deliberately not modelled (under-consuming a cap is the safe direction).
- **The affiliate ledger is guarded in the database, not in function memory** (AFF-002): the platform serves consecutive requests from fresh isolates, so an in-memory limiter proved useless; `affiliate_click_record` enforces a 60/min site-wide ceiling and a 5 s per-card cooldown. No IP is stored, by design.
- **Per-user budgets on the four paths that spend money** (SEC-002): Places search/resolve, Now-screen recommendations, receipt parsing. Fail-open on a counter outage — it is a cost guard, not an authorisation gate.
- **Billing:** a RevenueCat grant with no expiry is deferred to `billing-sync`, never granted open-ended; the app offers no upsell on a build that cannot sell; purchase confirmation waits for the entitlement to land.
- **CI enforces what only ran by memory** (F-12): Deno tests, engine bundle = source, EN/FR parity, N+1 gate, disclosure gate, migration ledger. A missing Deno is now a failure, not a pass.
- **Migration history is reconciled and gated** (F-13): rule 9(e) tightened in `PROJECT_RULES.md`; `APPLIED_MIGRATIONS.txt` is the committed ledger.
- **Legal surfaces exist** (F-15): full privacy policy on `/privacy` (named privacy contact, US storage disclosed, receipt retention stated honestly), subscription terms on `/legal`, `/terms` redirects, links in the paywall and Settings.
- **DATA-018 p2 fuel-grade scoping merged** from the retired branch, migration renamed to the recorded version.
- **Corrections to the review itself:** `recommend-cards-stateless-v1` is live (cardcoach.ca's /best-card calls it) — not dead as F-16 said; Alex is not "stepped back" for App Store purposes: he is the Account Holder until the app transfer.
**Left for Mike (handoff, in order):** push the two repos; deploy the changed edge functions (`config.toml` now pins the import map); switch `~/dev/CardCoachv2` back to `main`; decide receipt retention (#40); undeploy the dead functions (#42); the store-account chain (D-U-N-S `203843635` in hand → Organization enrolment → Paid Apps → Google Payments profile); secrets (RevenueCat webhook secret, EAS); the Places quota cap; affiliate applications.

### 2026-09-02 (later) — Receipts are kept 90 days; the two "dead" functions that were not (Mike)
**Decision:** scanned receipt photos and their readings are retained **90 days** from the scan, then deleted automatically (Mike, same day). Rationale on file: the corrections are the asset, not the images, and 90 days covers the Tier-2 correction window with margin; a NULL horizon was never a decision anyone had made.
**Landed:** RCPT-011 — migration `20260902163813`, `receipt-purge-worker` edge function, nightly pg_cron jobs, Vault-shared token, policy text. Record: WORKING_NOTES #40 (closed), `deltas/2026-09-02__receipt_tenants__retention_90_days.sql`.
**Correction to the review lane's own undeploy list:** `import-spend-v1` (API-022) and `resolve-merchant-v1` (API-018) are shipped-dark features, not dead code; both were deleted from production on the lane's list and are to be re-deployed by Mike (WORKING_NOTES #42). Rule for next time: a deployed function with source, tests and a config block is not dead because nothing calls it yet — check the feature inventory before listing it.

### 2026-09-02 (evening) — MCC backfill p3 applied per issuer definition; Adapta stays fail-closed; the queue drained once
**What ran:** the merchant-category apply (run `99b6d975`; 3 applied, 1 rejected, Mike deciding live) and the `mcc_includes` backfill p3 (run `f890f135`; 40 rows, three audits).
**Decision recorded (lane, under the 2026-08-26 standing approval):** the source-clause check is closed by reading the issuer's own category definition. Where the issuer defines a bonus category as "the network's <category> category" (BMO benefits guides, Scotiabank Amex legal text 1), the category-typical set from `mcc_category_mappings` is the faithful encoding. Where the issuer names merchant classes (CIBC: "grocery stores", "service stations/automated gas dispensers", "electric vehicle charging with MCC 5552", "drug stores", Dividend's "eating and drinking places and restaurants", "local and suburban commuter transportation … taxi, limousine and ride sharing"), the row carries the deterministic name→number reading of that text — narrower than the category — per tier B of the 2026-08-14 decision.
**Withheld, and why:** CIBC Adapta's 33 rows are an "auto top-3" bonus; pricing every category would over-credit eight of eleven categories every month. This is the Tangerine choose-N class (retyped `user_selected` on 2026-09-01), and it needs a modelling decision (a `condition_type` for automatic top-N, or a deliberate over-credit ruling), not MCC numbers. Aeroplan VIP dining: the guide names no merchant class. Neo United MileagePlus: airline-MCC-only, and a partial set would price at hotels today.
**Engine fact that governs this whole lane:** `assumptionAdmitsMccDefinedRow` admits a row when `mcc_includes` intersects the requested category's mapped MCCs. A narrower set therefore prices identically to the category-typical set today; precision only starts to matter when merchants carry real MCCs. The narrow sets are recorded now so that day needs no re-verification.
**Correction of an earlier plan:** the lane tried to file 39 name-derived merchant categories through `propose_merchant_category`; the observations table's `source` CHECK admits only the two request paths, by design. They are a worklist for Mike instead (`dispatches/WORKLIST_merchant_category_name_pass_2026-09-02.md`).

### 2026-09-02 (night) — Snapshots leave `public`; the security advisor is down to one dashboard toggle; apps/web stops carrying a second policy
**What landed (applied and verified in production; files + ledger on monorepo `main`):**
- **SNAP-001** (`20260902172110`): a `snapshots` schema PostgREST does not expose; the 68 rule-9(a) `*_snapshot_*` tables moved into it with RLS on and API grants revoked; `snapshots.v_retention_candidates` lists anything older than 90 days with a ready `drop_sql`. **SNAP-002** (`20260902173014`): the three `*_night_2026_07_31` copies from the overnight run joined them and the view reads their `YYYY_MM_DD` stamp. `public` is down to 70 tables from 141.
- **SEC-003** (`20260902172821`): pg_net's extension record moved from `public` to `extensions` (not relocatable, so drop + create; the worker was proven alive with a live request afterwards) and the six pre-existing functions with a mutable search_path pinned to `search_path = public` — bodies untouched; all SECURITY INVOKER and all name their tables unqualified, so `''` would have broken four of them.
- Security advisor after: 0 ERROR; 1 WARN, `auth_leaked_password_protection` (Mike, dashboard); 90 INFO `rls_enabled_no_policy`, all deliberate.
- `apps/web` `/privacy` and `/terms` now redirect to `cardcoach.ca/privacy` and `cardcoach.ca/legal` and left the sitemap (F-24). The mobile font gate reports a failed font load and renders with the platform faces instead of spinning forever (F-23 seam; `FontGate` component, 3 tests).
**Decision (lane, under rule 9):** snapshots are `snapshots.<table>_<stamp>` from now on (PROJECT_RULES 9(a) tightened). Dropping stays manual, by name, from the view — nothing in the database deletes a snapshot on its own. Rationale: the snapshots exist for rollback; the view's job is to make forgetting impossible, not to decide.
**Carried from the retired lane:** two uncommitted edits found in the working trees after Mike's checkout switch — the 2026-08-24 Android-submit proof (WORKING_NOTES #24d, `RELEASE_android_1.x_HANDOFF.md` Step 2) — committed as written.

### 2026-09-02 (evening) — The Playbook batch 2: six posts rendered, renderer re-aligned with the live site
**What landed (repo working trees, UNCOMMITTED — the blog publish gate is Mike's proofread):** six post sources
(`01_CORE/blog/post-11…post-16`), `render_v2.py` patched, six rendered pages + blog index + four hubs + sitemap (30 URLs)
+ six OG images in `card_coach_website/site/`. Topics, chosen by Mike from a proposed set after the chat-runtime draft
was found to duplicate four live pages: Rogers Red Mastercard changes (Nov 18 2026), Scotia Momentum rent/tax change
(Oct 22 2026) + recurring bills, annual-fee break-even (tracker #11), no-fee showdown (tracker #12), foreign transaction
fees, transit & rideshare. Full record: BLOG_OPERATIONS.md 2026-09-02.
**Decisions (lane):**
- **The renderer follows the live site, not the other way round.** `render_v2.py` had drifted from three months of
  hand edits (root-relative asset refs, Best Card nav, footer, sitemap page list, deploy tree moved). It was patched to
  reproduce the live pages byte-for-byte before any new page was rendered — proven by a dry render of the ten existing
  posts. Rule for future renders: run the dry-render diff first; a diff that is not a deliberate edit is renderer drift.
- **dateModified means modified.** A re-render of an unchanged post no longer bumps `dateModified` / `article:modified_time`
  / sitemap `lastmod`; the renderer compares the rendered page against the file on disk and keeps the old date when only
  the date would change. The date policy (real dates only, no backdating) is unchanged; this narrows what counts as a
  modification.
- **Card facts in posts come from the catalog first.** Every rate, cap and fee in the six posts was read from
  `card_products`/`earn_rates`/`card_caps` and the verify engine's quoted issuer clauses, then spot-read live on the
  issuer page the same day. Facts the catalog fails closed on (Amex consumer FX) stay blank in the post and the post says
  why. Cards outside the catalog are not named with numbers.
- **First-year fee waivers are welcome offers.** Note-only in ledgers, never in a fee cell (this batch applied it to BMO's
  "waived in the first year" too; post-05's older "(waived yr 1)" is a known inconsistency, left for Mike).
- **MCC lists are ours unless they are the issuer's.** The catalog's MCC mappings are not attributed to issuers in body
  copy; only MCCs printed on an issuer page (TD's 4111, Scotia's 5411/6513/9311) are quoted as the issuer's.
- **Independent fact-check before render.** A subagent recomputed every derived figure and re-read ten Tier-1 sources;
  three substantive corrections came out of it (Rogers' amended Eligible Rogers Purchase definition vs the notice's
  example sentence; the "half a point" vs full point wording; the rent tier hand-back direction). Worth repeating for
  every batch.
**Follow-ups (not decisions):** the 21 older OG images still carry "The Playbook · card.coach" in the footer;
`make_og.py` in the staging folder regenerates them. If Mike stages publication over weeks, each post needs a re-render
on its real launch date.

### 2026-09-02 (late) — Mike rules on the three open items: the name pass applies, Adapta gets a condition type, retention review becomes a monthly task
**Rulings (Mike, chat):** the 39-row merchant-category name pass — "approved" (all); CIBC Adapta — "add condition type"; the monthly snapshot-retention chore — "go with your rec".
**Landed:**
- Name pass applied: run `4b0ccfa5`, 39 guarded UPDATEs with one write_audit each, guardrail `placed_null_category` 45 → 6 (the six with no honest category), entities NULL 77 → 38 (the other 32 have no place row).
- **DATA-023 `auto_top_n`** — the issuer assigns the bonus after the fact to the N categories with the most spend in the period. Modelled where the facts are: `earnRowPrices` ranks the purchase's issuer category against the card's other Spend Categories from this month's `user_spend_snapshots`, purchase counted in; a row prices when fewer than N other groups have at least as much. Ties fail closed; so does every caller without spend facts (the web ranking, the stateless catalog path, analyze-spend, card value), which is deliberate — nobody's month is not a fresh month. Compound CIBC categories pool through `condition_group`. Migration `20260902182121`; 33 rows retyped (run `7d3e0c1a`); spec `docs/planning/specs/DATA-023_auto_top_n.md`. Live after the next edge deploy.
- Retention review: scheduled task "CardCoach — monthly snapshot retention review", 1st of each month 14:00 UTC, read-only — it lists `snapshots.v_retention_candidates` with the drop SQL for Mike; nothing drops on its own.
**Decision recorded (lane):** the top-N estimate is allowed to under-credit and never to over-credit — the same posture as `user_selected`, `mcc_defined` and the region gate. A user who records no spend sees the bonus price as a first purchase of the month would; that is what the issuer's rule says for a period with fewer than N categories in play, and it is the honest reading of the data on hand.

### 2026-09-02 (later still) — Wealthsimple onboarded as the 17th issuer; four products, all scoreable; non-offered cards stay scoreable but are never pitched
**Decision (Mike: "I want Wealthsimple added to our catalog … see it end to end"):** Wealthsimple joins the catalogue as
issuer `wealthsimple` (issuer of record: Wealthsimple Payments Inc., Visa) with **four** `card_products` rows, not the
two the marketing page shows. Wealthsimple's own legal disclaimers and its agreements index name four products —
**Visa Infinite 1%** (invite-only beta, $0, 1%), **Visa Infinite 2%** (the original card, closed to new applicants
2026-04-28, still held), **Visa Infinite +** (open) and **Visa Infinite Privilege** ("only available in limited
quantities") — and an in-wallet optimizer must score what people actually hold, so the closed and invite-only cards
load as `is_active` + `scoreable` with `application_status` carrying the truth (`closed`, `invitation_only`,
`limited`, `open`). The prepaid "Cash" Mastercard is a prepaid product and is out of scope.
**Decision — fees:** `annual_fee_cad` on the three 2% cards is the **sticker $240** (the disclosure statement's
"$240* charged monthly at $20/month … maintenance fee"; Quebec billed $240 annually). Wealthsimple waives it for
clients with $100,000+ in individual assets or $4,000+/month direct deposit; that is a per-client condition with no
schema home, so it is recorded in `source_metadata.verify` and NOT modelled — the same posture every other
conditional-waiver card takes. The 1% card is $0 ("No Annual Fees"). Supplementary card $120/yr has no column; noted.
**Decision — FX:** 0.00% on the 2% family, dual-confirmed (disclosure "We do not charge any additional foreign currency
conversion mark-up." + product page "it's always zero"); **2.5%** on the 1% card from its own disclosure statement,
where no-FX is only a user-selectable benefit. The engine has no per-user benefit switch, so the disclosed default is
stored and the selectable waiver is a carried [VERIFY].
**Decision — earn:** four flat `base` rows (2 / 2 / 1 / 2 cents per dollar), uncapped, from one Tier-1 clause
(ACCTC-080426-WS: "2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards
and 1% for the Wealthsimple Visa Infinite 1% credit card"). No `card_exclusions` rows: the exclusions (cash-like
transactions, refunds, fees, adjustments) are transaction-class, not category-class. In-app "boosted" partner cash back
and the 30-day "up to 5%" welcome offer are **excluded from `earn_rates`** — merchant-funded / welcome-class, no
published per-purchase rate — by the Neo 2026-08-16 partner-cashback precedent and rule 7.
**Decision — the first non-open scoreable cards, and what they exposed:** until today every `closed` card was also
`load_only`, so nothing ever asked what a public surface should do with a card that scores but cannot be applied for.
Two surfaces pitch cards the user does not hold — `/best-card`'s "Beyond your wallet" gap-finder and `apps/web`'s
public per-category rankings (H29). Both now skip `application_status IN ('closed','invitation_only')` (`limited`
still pitches). The wallet picker (mobile `export_cards`, `/best-card` issuer list) keeps all four, as it must.
**Access posture:** `www.wealthsimple.com`, `help.wealthsimple.com` and the PDF host `www.cdn.wealthsimple.com` all
served full content to the cloud fetcher; the three legal documents sit behind 302s from stable wealthsimple.com paths
to **version-coded PDF filenames** (CHA080426 / CHA041026 / ACCTC-080426-WS) — navigate from the legal index, never
guess a filename; a changed filename is itself a revision signal. The Claude-in-Chrome extension refuses
wealthsimple.com outright, so the chrome lane cannot take this issuer; it goes in the **Sunday** cloud batch.
`verify.issuer_notes` seeded as `Wealthsimple` (`wall_status='open'`, `preferred_channels={http_pdf,browser_render}`)
with the four-vs-two coverage-diff trap, the fee-waiver trap ("do not propose $0") and all carried items.
**Carried [VERIFY] items:** (1) evidence capture — onboarded from cloud fetches without sha256 evidence rows; the first
Sunday run must capture CHA-080426-WS, CHA-041026-WS1 and ACCTC-080426-WS as `verify.evidence` artifacts and grep-guard
the quoted clauses; (2) the legacy 2% card's fee for grandfathered holders (the pre-April-28 help article states the
waiver but not the amount; the DB carries the disclosure's $240, which names "Wealthsimple Visa Infinite*"); (3) the
1% card's selectable no-FX benefit; (4) `application_status` on Privilege (`limited`) and the 1% card
(`invitation_only`) are sentence-level facts on the product page / help centre — re-check every run.
**Applied:** deltas `2026-09-02__issuers_card_products__wealthsimple_onboarding.sql` (issuer, 4 card_products,
issuer_notes seed) and `2026-09-02__earn_rates__wealthsimple_p1.sql` (4 base rows). Snapshots
`snapshots.{issuers,card_products,earn_rates}_snapshot_20260902_wealthsimple`, RLS-secured. Pre/post guards asserted in
both transactions (issuers 16→17, card_products 149→153, earn_rates 732→736). Read-back through the anon REST surface
and a live `recommend-cards-stateless-v1` call (Visa Infinite + ranks first at 200¢ on a $100 base purchase; TD Cash
Back beats it at groceries) confirmed the rows price. Public claim moves to **17 issuers** (16 with tracked cards —
HSBC still holds none). Site: `apply-links.js` +4 direct entries, `best-card.js` gap-finder skips non-offered cards;
mobile: `Wealthsimple` added to the picker's preferred issuer order; `apps/web` H29 filter tightened. The Sunday
task prompt's `ISSUER_BATCH` is a Cowork-local edit Mike makes by hand (add the token `Wealthsimple`).

### 2026-09-02 (addendum) — Wealthsimple: an independent re-read confirms every money fact; Visa Infinite + is `limited`, not `open`
**What happened:** after the onboarding above, a second, independent pass over all ten Wealthsimple sources (fresh
prompts, WebFetch only, no third-party sites) confirmed every stored rate, fee and FX value, and corrected one status
fact: the "only available in limited quantities" sentence sits in the FAQ answer that matches applicants "to either a
Visa Infinite + card or a Visa Infinite Privilege card" — it covers the programme, not Privilege alone. **Visa
Infinite + moves `open` → `limited`** (delta `2026-09-02__card_products__wealthsimple_p3_status_and_notes_APPLIED.sql`;
`verify.issuer_notes` snapshotted in place first). No ranking effect — `limited` still pitches and still scores.
**Also recorded, no stored fact changed:** the closure of the original 2% card is *inferred* (no page says "closed to
new applications"; the help centre offers only +, Privilege and the 1% beta and calls the original "our previous Visa
Infinite card") — the row's verify note now says so; the 1% card's disclosure never contains "1%" (the mapping rests
on the agreements index and the `cardholder-agreement-core` slug); the first month's fee is waived for everyone and
Quebec's first year is a promotional $220 — both welcome-class, parked, sticker stays $240; household-based
(Premium/Generation) fee waivers ended 2026-04-28 and are honoured for existing holders "until further notice"; the
1% card is virtual-only during the beta; the help centre's generic "Wealthsimple doesn't charge FX fees" line is
contradicted for the 1% card by its own disclosure (2.5%) and benefits article — the disclosure governs.
**Unrelated find while checking catalogue invariants:** `ca_national_bank_mycredit_standard_mastercard` is the only
active scoreable card with no active `base` earn row (two category rows, scalar `base_earn` 0.5). Pre-existing; not
touched here — WORKING_NOTES #48(e).
