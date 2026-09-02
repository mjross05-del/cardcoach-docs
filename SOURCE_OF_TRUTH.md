# CardCoach — Source of Truth

**Open this file first. Always.**
Last updated: 2026-09-02 (Wealthsimple onboarded, 17 issuers) · Owner: Mike

> **2026-09-02 — read this block first; where it conflicts with anything below, it governs.**
> - The company is **CardCoach Inc.** (Ontario). "Warm Logic" below is the pre-incorporation working brand; the legal, privacy and store surfaces say CardCoach Inc. and so should new docs.
> - **What is real and built:** the iOS app (App Store, Alex's team until the app transfer — see the 2026-09-01 decision), the Android app (Play internal testing, build 85), the scoring engine + Deno edge functions on Supabase project `hrzpznlpmxxrbtwskacu` (AWS us-east-1), the verification batches, cardcoach.ca (26 pages, affiliate lane live), and the database: **128 recorded migrations** as of 2026-09-02 — the ledger is `mobile_app_codebase/supabase/APPLIED_MIGRATIONS.txt` in the monorepo, and CI (`verify:migration-history`) fails when the migrations directory and the ledger disagree.
> - **Live in production (runtime_flags):** loyalty offer stacking (`loyalty_offer_stacking`, on since 2026-08-02), MCC assumption routing (`merchant_mcc_assumption`, on since 2026-08-14), online merchant resolution, receipt scanner, statement import (read), tie disclosure, ambient widget. **Off:** `billing_paywall`, `card_slot_limit`, `auto_location_gate`, `network_acceptance`, `statement_import_write`. The line below saying stacking and MCC routing are "not active" is retired.
> - **Since 2026-09-02 the engine reads `card_caps`** (CAPS-001: pooled, annual and whole-card caps folded onto earn rows before ranking); the site's `/best-card` tool scores through `recommend-cards-stateless-v1`, which is therefore live, not dead.
> - **Lanes:** every Claude runtime other than the review lane was retired 2026-09-02; there is one lane. Alex is not "stepped back" in the sense of gone: he is still the Apple Account Holder of the team the app ships from and must initiate the app transfer (2026-09-01 decision).
> - **Files:** `README.md` is `SCHEMA_HANDOFF_README.md` here; `stage2_fetcher.py` is not in this repo (retired; archive only); `card_sources_seed_enriched.csv` lives in the monorepo under `card_coach_business_docs/01_CORE/CardCoach/Reverify Script/`, not here. The review that established all of this: `REVIEW_full_2026-09-02.md`.

This is the only file that tells you what to trust. If any other document points you
at a filename, check it against the lists below before you go looking for it. Most of
the old references are dead — see "Files that DO NOT exist" at the bottom.

---

## The 30-second orientation

CardCoach is a Canada-only, issuer-verified credit card recommendation product of
**CardCoach Inc.** ("Warm Logic" was the working brand before incorporation). Three things were real and built when this section was written — the 2026-09-02 block above lists what is real now:

1. **The database** — a live Supabase schema (48 tables, 18 views, 43 migrations). Real. Done. The asset.
2. **The verification batches** — daily scheduled runs (per-issuer weekday rotation + Friday chrome lane) that keep card data current, with evidence and audit in the Supabase `verify` schema. Operational since late July 2026. *(The old 3-stage script pipeline is retired — 2026-08-01 decision entry in PIPELINE_AND_DECISIONS.md.)*
3. **The brand + live site** — Warm Logic brand kit and the marketing site (HTML).

Everything else in the old project folder is either (a) the same content in a worse
file format, or (b) a reference to a file that was never delivered here.

---

## What governs what — the clean doc set

These are the **only** documents you need to maintain going forward. Plainly named,
plain Markdown, each one actually is what it says it is.

| File | What it's for | How often it changes |
|------|---------------|----------------------|
| `SOURCE_OF_TRUTH.md` | This file. The index + ghost list. | Rarely |
| `HOW_THE_ENGINE_WORKS.md` | The data model + pipeline truth. How the engine and DB actually work. | Rarely — only on real architecture changes |
| `PIPELINE_AND_DECISIONS.md` | The daily verification batch process, plus the append-only log of settled decisions. | Part 1 on process changes; Part 2 append-only |
| `WORKING_NOTES.md` | What's unresolved, who owns it, what's next. The churning to-do reality. | Often — this is the only one that churns |
| `STAGE3_PROMPT.md` | RETIRED 2026-08-01 (script pipeline). Kept as the record of the extraction rules. | Frozen |
| `BRAND.md` | Warm Logic brand: palette, type, logo, voice, rules. | Rarely |
| `REVENUE.md` | The revenue model (v3 as of 2026-08-28; Phase 4 v2 retired): free web + paid iOS. | Rarely — on strategy shifts |

Seven files. Plus `SCHEMA.md` and `SCHEMA_HANDOFF_README.md` (real, on disk, keep). `stage2_fetcher.py` is retired and is **not** in this repo (2026-09-02 correction). If you find yourself maintaining an eighth governance
doc, ask whether it belongs inside one of these instead.

---

## What's real on disk (don't reinvent these)

**Database**
- Live Supabase instance — 128 recorded migrations as of 2026-09-02 (ledger: `mobile_app_codebase/supabase/APPLIED_MIGRATIONS.txt`); the "48 tables, 18 views, 43 migrations" figure was the 2026-04-15 schema generation.
- `SCHEMA.md` — human-readable schema reference. **Real, on disk, trustworthy.**
- `SCHEMA_HANDOFF_README.md` — schema handoff notes (the file older docs call `README.md`). **Real, on disk.**
- `schema.public.sql` lives in Alex's repo at `docs/schema-handoff/2026-04-15/`; regenerable via `supabase db dump`.

**Brand**
- Warm Logic brand (palette, type, voice, the Chip logo) — now in `BRAND.md`.
- Logo PNGs: Mark + Lockup, Light + Dark. **The current, adopted logo.**

**Live site**
- `index.html`, `about.html`, `how.html`, `support.html`, `legal.html`, `privacy.html`, `styles.css`, `scripts.js`. **Real, deployed.**
- **Live at `https://cardcoach.ca`** — canonical as of 2026-07-08; `card.coach` = 301 (path + query preserved). Hosted as a **Cloudflare Worker serving static assets** (worker: `cardcoach-site`) — not classic Cloudflare Pages. *(Domain flipped 2026-07-08, superseding the 2026-07-05 defensive-domain direction — repo cutover done in the worktree; the Cloudflare-side cutover (custom domain + 301 reversal) is pending Mike. The 2026-07-05 zip-workflow correction stands below.)*
- Cloudflare Web Analytics token: `f75218d6a9ea4e0787f5a3c6901ebde2` (swapped 2026-07-08 with the domain flip; the old `a3f06983…` token is retired).
- **Deploy workflow:** edit locally in the `01_CORE/site/` git worktree → commit → **push to `main` → Cloudflare Workers Builds auto-deploys**. Branch pushes give preview URLs. Zip uploads are retired; zips in `00_COWORK/_OUTPUTS/` serve as point-in-time records only. *(Corrected 2026-07-05.)*

**Card data**
- `card_sources_seed_enriched.csv` — the Stage 1 registry of issuer source URLs. **Not in this repo** — it lives in the monorepo under `card_coach_business_docs/01_CORE/CardCoach/Reverify Script/` (2026-09-02 correction). **RETIRED 2026-08-01** with the script pipeline; kept as a record. Source discovery now happens in the daily batches' coverage diffs; learned per-issuer source knowledge lives in `verify.issuer_notes`.
- 95+ cards · **17 issuers** · 442+ earn rates · 155+ caps (dataset v23, 2026-03-14; PCF net-new adds pending).
  Live DB as of 2026-08-16: 139 `card_products`, 16 issuers, 609 `earn_rates`, 155 `card_caps`.
  Live DB as of 2026-09-02 (Wealthsimple onboarded): 153 `card_products`, **17 issuers**, 736 `earn_rates`, 173 `card_caps`.
  The public **card-count** claim stays "95+" until the 2026-07-16 decision is revisited — that
  entry governs the claim, not this line. The **issuer** count is a plain fact and moves to 16.
- The actual card facts (earn rates, caps, fees, point values) live in the **Supabase database**, governed by the pipeline. They are NOT re-derivable from the docs alone.

**Pipeline code (retired)**
- `stage2_fetcher.py` — the Stage 2 source fetcher. Recovered from `stage2_fetcher.pdf`, compile-checked — and **RETIRED 2026-08-01** with the script pipeline (it could not handle bot-walled / headless-blocked / client-rendered issuer sites; see the decision entry). Kept on disk as a record; do not run it against live sites. `STAGE3_PROMPT.md` is likewise retired-with-banner.

---

## Files that DO NOT exist (stop looking for them)

These names appear in older documents and in past working rules. **None of them are in
this project folder.** When you see them referenced, mentally substitute the real file
(or note "lives in Alex's repo") and move on. Do not search for them. Do not recreate
them from memory. Do not cite them as if they're here.

| Ghost reference | Reality |
|-----------------|---------|
| `HOW_THE_ENGINE_WORKS.md` (in old rules) | Now real — built fresh. Use it. |
| `schema copy.txt` | Never existed. The schema is `SCHEMA.md`. |
| `PIPELINE.md` / `DECISIONS.md` / `OPEN_ITEMS.md` | Were `.pdf` (image-only). Content now lives in `PIPELINE_AND_DECISIONS.md` + `WORKING_NOTES.md`. |
| `stage2_fetcher.py` | Was recovered from `stage2_fetcher.pdf` (a ZIP) in July and retired 2026-08-01; **it is not in this repo** (2026-09-02). Archive only. |
| `stage2_README.md` | Not in this folder. Runbook content is summarized in `PIPELINE_AND_DECISIONS.md`. |
| `stage3_reverify_prompt.md` (and v1.1) | Were `.pdf`. The Stage 3 prompt is summarized in `PIPELINE_AND_DECISIONS.md`; full prompt lives wherever Mike pastes it from. |
| `card_sources_ddl.sql` | **Not in this folder.** Referenced as "for future Supabase migration." Confirm with Alex. |
| `schema.public.sql` | Referenced by `README.md` but **not delivered into this folder.** Confirm with Alex. |
| `build_onepager.py` | Not in this folder. Source for the pipeline brief PDF. |
| `CardCoach_Brand_Sheet_Mikayla.pdf` | Referenced in the brand kit. **Not in this folder.** |
| `CardCoach_Chip_Contrast_Test.pdf` | Referenced in the brand kit. **Not in this folder.** |
| `CardCoach_Email_Signature.html` | Referenced in the brand kit. **Not in this folder.** |
| Brand docx (`WarmLogic_BrandKit`, `Colors_and_Fonts`) | Replaced by `BRAND.md`. |
| Stage 3 prompt PDFs (`stage3_reverify_prompt`, v1.1) | Full prompt now in `STAGE3_PROMPT.md`. |
| Phase 4 PDFs (`Revenue_Model`, `Revenue_Summary_v2`) | Both were renders of the v2 model. Consolidated into `REVENUE.md`. |
| `CardCoach_Phase4_Revenue_Model_v2.xlsx` | **RETIRED 2026-08-28** — superseded by `CardCoach_Revenue_Model_v3.xlsx` in `01_CORE/data/`. Kept for provenance only (866 formulas). **Not in this folder.** Needed to flex assumptions — the PDFs were just renders of it. |
| "audit workbook" (.xlsx) | **Does not exist in this project.** Card-level facts can't be verified from docs without it. → recovered 2026-07-16; superseded by the workbook block above. |
| reverification "SQL files" (in old rules) | No `.sql` files exist here. Reverification exists as a *prompt*, not executable SQL. |

Retired 2026-06-10 to `_archive/files/`: `CARDCOACH.md`, `pipeline/DECISIONS.md`, `pipeline/OPEN_ITEMS.md`.

The four issuer reverification `.sql` files are pipeline *outputs*, not recoverable artifacts.

**The rule:** if it's not in "What's real on disk" above, treat it as not-here until
someone produces it. The content is good; the file trail was broken. This list is the fix.

---

## Lanes (who owns what)

- **Mike** — data integrity, the reverification pipeline, governance, brand, ops.
- **Alex** — the app build, the scoring engine, the Supabase database deployment. **AMENDED 2026-07-29 (Mike): "We can do anything Alex can. This is our lane now."** Data writes to Supabase no longer route through Alex — Mike's side applies them directly under the four standing conditions in PROJECT_RULES.md rule 9 (snapshot, delta file, expire-then-insert, transaction guards). Delta files are still cut for every change; they are now a record rather than a handoff. ~~Alex retains the app build, App Store, and — pending Mike's confirmation — schema/DDL/RLS.~~ **AMENDED 2026-08-01 (Mike): Alex has stepped back for the time being.** The full lane — app build, App Store/TestFlight releases, engine, schema/DDL/RLS — is Mike's with equal authority until Alex re-engages (the 2026-07-29 "pending confirmation" on schema is resolved: confirmed). PROJECT_RULES rule 9 conditions and the per-change DDL discipline bind unchanged.
- **Mikayla** — marketing assets, Canva, social. Executes under Mike's direct review; does not ship independently.

---

## The few hard truths to never lose again

- **Canada-only.** Every record carries Canada applicability evidence.
- **Issuer-verified only.** Tier 1 (legal/disclosure) or Tier 1b (product page). Blogs/aggregators are review triggers, never truth. **One narrow exception, `point_valuations` only (Mike, 2026-07-29): Tier 2 — triangulated industry consensus.** Where a programme publishes no cents-per-point value at all — dynamic award travel is the whole of this category — a consensus value is permitted, because diverging from an aligned industry view without a verifiable reason is itself a defensibility risk. It is not a general licence to cite aggregators. All six conditions bind: (1) no issuer-published value exists for that redemption path; (2) three or more independent recognised sources agree within a stated tolerance; (3) the stored value falls **inside** the observed range, never above it; (4) `confidence` capped at `medium-high`; (5) every source named with its access date in `source_notes`; (6) any deliberate divergence from consensus documented with its reason. Tier 2 never overrides an available Tier 1/1b value. Full rule: `proposals/PROPOSAL_point_valuation_governance.md` §2.
- **Commission-blind** — enforced at the data layer, not just as policy. The pipeline never touches affiliate/commission data.
- **V1 is dead.** Production reads only the V2 tables (`card_products`, `earn_rates`, `card_caps`, `card_exclusions`). The old `cards` / `card_earn_rates` tables are not in any read path. (See decision 2026-04-16.)
- **French is V1 scope, but not yet done.** The FR-CA source rows are still blank — placeholder, not verified.
- **Offer stacking + MCC routing** — RETIRED LINE (2026-09-02): both are live. `loyalty_offer_stacking` has been on since 2026-08-02 and `merchant_mcc_assumption` since 2026-08-14; see the block at the top of this file.
- **Safe public claims:** "issuer-verified," "95+ cards," **"17 issuers."** (UPDATED 2026-09-02 — Wealthsimple onboarded; see the PIPELINE_AND_DECISIONS entry of that date. Previously updated 2026-08-16 for Neo Financial.) The 17 are: Amex, BMO, CIBC, Canadian Tire, Desjardins, HSBC, MBNA, National Bank, Neo Financial, PC Financial, RBC, Rogers, Scotia, Simplii, TD, Tangerine, **Wealthsimple**. A "cards across N issuers" claim should say **16**, not 17 (HSBC still holds no tracked cards) — the Play listing copy currently says 15 and needs a bump at its next edit. **Read the history carefully before “correcting” this line:** older docs claimed "16" and were wrong — that 16 double-counted Rogers as both “Rogers” and “Rogers Bank”. The count was genuinely 15 from then until 2026-08-16, and is genuinely 16 now for a different reason. The old standing instruction to hunt down and fix “16 issuers” on the live site is **retired**; 16 was correct from 2026-08-16 to 2026-09-02 and **17** is correct from 2026-09-02. HSBC still carries 0 tracked cards and is excluded from the verification rotation.)
- **No ads.** Hard constraint.

---

## 2026-07-02 — Folder recovery addendum

Files the ghost list above said were absent that turned out to exist, found during
the 2026-07-02 folder recovery, and where each now lives:

- **Audit workbook:** `cardcoach_initial_load_audit_pack_canada_2026-06-07_v24_cleaned.xlsx`
  at repo root is canonical (re-designated 2026-07-16; verified: 95 unique cards, 15
  issuers, v22→v23→v24 lineage sheets intact). v23 patchready is superseded — archived
  2026-06-10 to `_archive/files/`.
- **Revenue model:** `01_CORE/data/CardCoach_Revenue_Model_v3.xlsx` (built 2026-08-28; ten switchable tier
  scenarios; Python reference in `01_CORE/data/model_v3/`). RETIRED predecessor:
  `CardCoach_Phase4_Revenue_Model_v2.xlsx` (materialized 2026-06-09;
  verified 2026-07-16 — 7 tabs, 866 formulas). Current summary output:
  `CardCoach_Phase4_Sensitivity_OnePager.md` (generated 2026-06-10).
- `schema copy.txt` → `99_ARCHIVE/superseded-governance/` → existed after all; consolidated DDL through migration 0037, superseded by SCHEMA.md (43 migrations).
- `schema.public.sql` → `01_CORE/data/` → recovered; 2026-04-15 dump, Alex's repo authoritative.
- `card_sources_ddl.sql` → `01_CORE/data/card_sources_ddl.sql` → recovered; dated 2026-04-25, Alex's repo authoritative.
- `CardCoach_Brand_Sheet_Mikayla.pdf` → `01_CORE/brand/CardCoach_Brand_Sheet_Mikayla.pdf` → recovered; newest copy.
- `CardCoach_Chip_Contrast_Test.pdf` → `01_CORE/brand/CardCoach_Chip_Contrast_Test.pdf` → recovered; newest copy.
- 2026-07-02 (second pass): filenames normalized to docs-canonical underscore names; naming drift closed.

Where this addendum conflicts with the ghost list above, this addendum governs.

---

**2026-07-16 — Domain cutover complete.** `cardcoach.ca` serves the site directly
(Worker custom domain); `card.coach` 301s to `cardcoach.ca` with path+query
preserved. The two stacked defensive redirects on cardcoach.ca were removed.
`hello@cardcoach.ca` routes via Email Routing. Deploy: push to `main` auto-deploys
via Cloudflare Workers Builds (active since 2026-07-05, verified 2026-07-16) —
anything committed to `main` ships live within ~1 minute. `www.cardcoach.ca` 301s to the
apex (verified 2026-09-02; WORKING_NOTES #21 closed). The site's working copy is
`card_coach_website/site/` in the monorepo (relocated git-dir `.cardcoach-site.git`; see that
directory's README) — the `01_CORE/site/` worktree named above is the old location.

---

*This file supersedes any conflicting file reference in older docs. When a referenced
file can't be found, this list is the authority on whether it should exist.*
