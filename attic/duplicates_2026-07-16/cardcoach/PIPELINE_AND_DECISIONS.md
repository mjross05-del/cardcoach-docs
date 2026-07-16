# CardCoach Pipeline & Decisions

**The reverification pipeline (how it works) + the append-only log of settled decisions.**
This file is the "why things are the way they are" reference. The pipeline section is
stable; the decisions section is **append-only** — add new entries, never rewrite old ones.

Last updated: 2026-06-10 · Owner: Mike (data integrity, governance, review)
Status: **Infrastructure complete. First end-to-end run not yet done.**

---

# PART 1 — THE PIPELINE

## What it is

A three-stage system that keeps CardCoach's 95-card database accurate by detecting when
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

- **Prompt:** The full prompt is **STAGE3_PROMPT.md** in this folder (v1.2, 2026-06-10).
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
