# CardCoach Pipeline & Decisions

**The reverification pipeline (how it works) + the append-only log of settled decisions.**
This file is the "why things are the way they are" reference. The pipeline section is
stable; the decisions section is **append-only** — add new entries, never rewrite old ones.

Last updated: 2026-06-02 · Owner: Mike (data integrity, governance, review)
Status: **Infrastructure complete. First end-to-end run not yet done.**

---

# PART 1 — THE PIPELINE

## What it is

A three-stage system that keeps CardCoach's database of 95+ cards accurate by detecting when
issuers quietly change earn rates, caps, or fees, and turning those changes into
verified database updates. Runs locally on Mike's laptop. No servers, no ongoing costs,
no new platform dependencies.

The product promise is "issuer-verified, always current." Issuers reorganize product
pages and revise agreements on their own cadence, usually silently. Without change
detection, the data drifts and a user finds the mistake before we do. This pipeline
replaces ad-hoc manual checks.

## The three stages

### Stage 1 — Registry
A CSV of every official issuer URL CardCoach monitors. One row per (card × source_type ×
language). Source types: product page, benefits guide, disclosure, rewards program terms.

- **File:** `card_sources_seed_enriched.csv` *(real, on disk)*
- **Coverage:** 293 of 704 registry rows filled (42%). Gaps are mostly the 324 blank FR-CA rows (deferred — see decisions) plus ~10 landing-page-only entries needing per-card PDF resolution (CIBC Aeroplan, MBNA benefits, Rogers benefits).
- **Discontinued:** HSBC (migrated to RBC, March 2024 — flagged discontinued, not reverified).

### Stage 2 — Fetcher
A Python script, run monthly from Mike's laptop. Visits every URL, extracts normalized
text (PDF or HTML), compares to last month's snapshot on disk, and writes a dated
Markdown change report.

- **Script:** `stage2_fetcher.py` — **real file, recovered and compile-checked.** It was Claude-generated and had been archived inside `stage2_fetcher.pdf`, which is why it couldn't be found. Run it from a directory containing the registry CSV (it creates `snapshots/`, `reports/`, `logs/` on first run).
- **Dependencies:** `requests`, `pdfplumber`, `beautifulsoup4` (~60% of sources are PDFs).
- **Run modes:** dry-run (prints URLs, no network); smoke test (one issuer, e.g. Amex ~56 rows, 2–3 min); single-card debug (`--card-id`); full run (~293 URLs, 1.5s apart, ~10–12 min). Filters by `--language`, `--source-type`, `--issuer`.
- **Outputs (runtime artifacts, gitignored):**
  - `snapshots/<card_id>/<source_type>__<language>.txt` — current text
  - `…prev.txt` — previous text (only kept when a change was detected)
  - `reports/changes_YYYY-MM-DD_HHMM.md` — what changed this run
  - `logs/fetcher_…log` — verbose run log
- **First run** stores everything as baseline (293 "new", 0 "changed"). Change detection earns its keep on run two onward. Each row resolves to **unchanged / changed / error.**

### Stage 3 — Extraction
A reusable prompt Mike pastes into Claude when the fetcher flags a meaningful change.
Input: current DB rows for one card (JSON) + the new snapshot text + source metadata.
Output: a structured five-section delta (`card_products`, `earn_rates`, `card_caps`,
`card_exclusions`/Unsupported_Benefits, audit notes), field-level, with issuer-verified
evidence, for Alex to apply as SQL.

- **Prompt:** Stage 3 reverification prompt, v1.1 (2026-04-22). The full prompt is **not stored as a file in this folder** — it was delivered as a PDF. Keep the working copy wherever Mike pastes it from; this doc is the summary of what it does.
- **Hard rules the prompt enforces:** Canada-only; Tier 1 / Tier 1b sources only (reject secondary sources with `SOURCE_REJECTED`); every emitted row carries `source_url`, `source_date_accessed`, `source_language`, and `source_clause_reference` where applicable; never guess or infer — flag unclear facts for human review; expire-then-insert for versioned tables; no V1 writes ever.

## The monthly loop

1. Run the fetcher → ~10 min, automated.
2. Open the change report → usually 0–10 real changes.
3. For each real change: grab snapshot text → pull current DB rows → paste both into Claude with the Stage 3 prompt → review the delta (approve / edit / reject).
4. Send approved deltas to Alex as SQL.

Active work per month: ~30 min at a typical 3–5 material changes. Scales with the change
rate, not the registry size.

## Constraints baked into the design

These come from the decisions below. Changing them means revisiting the decision, not
patching code.

- **Canada-only** — every record needs Canada applicability evidence.
- **V2 tables only** — writes target `card_products`, `earn_rates`, `card_caps`, `card_exclusions`. V1 is not in any read path.
- **Issuer-verified only** — Tier 1 or Tier 1b sources. Blogs/aggregators are review triggers, never truth.
- **Commission-blind** — reads issuer pages only. No affiliate link handling, ever.
- **Caps use expire-then-insert** — never delete-and-replace. History preserved.
- **Per-litre rates parked** in Unsupported_Benefits until the `rate_unit` enum is extended (affects Canadian Tire, PC Financial gas rows).
- **MCC routing captured, not enforced** — vendor doesn't expose MCC in transactions yet.

## Note for a future Claude session

Output should be SQL files, data files, prompt revisions, or documentation — **never
direct writes to Supabase or the app.** Don't push code or DB changes on Mike; that's
Alex's lane.

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
