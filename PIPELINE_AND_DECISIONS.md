# CardCoach Pipeline & Decisions

**The reverification pipeline (how it works) + the append-only log of settled decisions.**
This file is the "why things are the way they are" reference. The pipeline section is
stable; the decisions section is **append-only** — add new entries, never rewrite old ones.

Last updated: 2026-07-31 · Owner: Mike (data integrity, governance, review)
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

- **Prompt:** The full prompt is **STAGE3_PROMPT.md** in this folder (v1.3, 2026-07-16). The June v1.2 was recovered at commit 1a55114c after the rebuild was written; v1.3 is the rebuild relabeled — see the prompt's changelog.
- **Hard rules the prompt enforces:** Canada-only; Tier 1 / Tier 1b sources only (reject secondary sources with `SOURCE_REJECTED`); every emitted row carries `source_url`, `source_date_accessed`, `source_language`, and `source_clause_reference` where applicable; never guess or infer — flag unclear facts for human review; expire-then-insert for versioned tables; no V1 writes ever.

## The monthly loop

1. Run the fetcher → ~10 min, automated.
2. Open the change report → usually 0–10 real changes.
3. For each real change: grab snapshot text → pull current DB rows → paste both into Claude with the Stage 3 prompt → review the delta (approve / edit / reject).
4. Send approved deltas to Alex as SQL. (one file per card, per the 2026-06-10 handoff-format decision below)

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
