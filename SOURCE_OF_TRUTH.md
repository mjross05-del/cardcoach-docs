# CardCoach — Source of Truth

**Open this file first. Always.**
Last updated: 2026-08-01 · Owner: Mike

This is the only file that tells you what to trust. If any other document points you
at a filename, check it against the lists below before you go looking for it. Most of
the old references are dead — see "Files that DO NOT exist" at the bottom.

---

## The 30-second orientation

CardCoach is a Canada-only, issuer-verified credit card recommendation product under
the **Warm Logic** brand. Three things are real and built:

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
| `REVENUE.md` | The Phase 4 v2 revenue model: free web + paid iOS. | Rarely — on strategy shifts |

Seven files. Plus `SCHEMA.md` and `README.md` (real, on disk, keep), and the recovered —
now retired — `stage2_fetcher.py`. If you find yourself maintaining an eighth governance
doc, ask whether it belongs inside one of these instead.

---

## What's real on disk (don't reinvent these)

**Database**
- Live Supabase instance — 48 tables, 18 views, 43 migrations (as of 2026-04-15 schema generation).
- `SCHEMA.md` — human-readable schema reference. **Real, on disk, trustworthy.**
- `README.md` — schema handoff notes. **Real, on disk.**
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
- `card_sources_seed_enriched.csv` — the Stage 1 registry of issuer source URLs. **Real, on disk — RETIRED 2026-08-01** with the script pipeline; kept as a record. Source discovery now happens in the daily batches' coverage diffs; learned per-issuer source knowledge lives in `verify.issuer_notes`.
- 95+ cards · 15 issuers · 442+ earn rates · 155+ caps (dataset v23, 2026-03-14; PCF net-new adds pending).
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
| `stage2_fetcher.py` | **RECOVERED.** Was Claude-generated and archived inside `stage2_fetcher.pdf` (a ZIP), which is why no one could find it and Alex never had it. Now a real `.py` file in this set. |
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
| `CardCoach_Phase4_Revenue_Model_v2.xlsx` | The live revenue model (866 formulas). **Not in this folder.** Needed to flex assumptions — the PDFs were just renders of it. |
| "audit workbook" (.xlsx) | **Does not exist in this project.** Card-level facts can't be verified from docs without it. → recovered 2026-07-16; superseded by the workbook block above. |
| reverification "SQL files" (in old rules) | No `.sql` files exist here. Reverification exists as a *prompt*, not executable SQL. |

Retired 2026-06-10 to `_archive/files/`: `CARDCOACH.md`, `pipeline/DECISIONS.md`, `pipeline/OPEN_ITEMS.md`.

The four issuer reverification `.sql` files are pipeline *outputs*, not recoverable artifacts.

**The rule:** if it's not in "What's real on disk" above, treat it as not-here until
someone produces it. The content is good; the file trail was broken. This list is the fix.

---

## Lanes (who owns what)

- **Mike** — data integrity, the reverification pipeline, governance, brand, ops.
- **Alex** — the app build, the scoring engine, the Supabase database deployment. **AMENDED 2026-07-29 (Mike): "We can do anything Alex can. This is our lane now."** Data writes to Supabase no longer route through Alex — Mike's side applies them directly under the four standing conditions in PROJECT_RULES.md rule 9 (snapshot, delta file, expire-then-insert, transaction guards). Delta files are still cut for every change; they are now a record rather than a handoff. Alex retains the app build, App Store, and — pending Mike's confirmation — schema/DDL/RLS.
- **Mikayla** — marketing assets, Canva, social. Executes under Mike's direct review; does not ship independently.

---

## The few hard truths to never lose again

- **Canada-only.** Every record carries Canada applicability evidence.
- **Issuer-verified only.** Tier 1 (legal/disclosure) or Tier 1b (product page). Blogs/aggregators are review triggers, never truth. **One narrow exception, `point_valuations` only (Mike, 2026-07-29): Tier 2 — triangulated industry consensus.** Where a programme publishes no cents-per-point value at all — dynamic award travel is the whole of this category — a consensus value is permitted, because diverging from an aligned industry view without a verifiable reason is itself a defensibility risk. It is not a general licence to cite aggregators. All six conditions bind: (1) no issuer-published value exists for that redemption path; (2) three or more independent recognised sources agree within a stated tolerance; (3) the stored value falls **inside** the observed range, never above it; (4) `confidence` capped at `medium-high`; (5) every source named with its access date in `source_notes`; (6) any deliberate divergence from consensus documented with its reason. Tier 2 never overrides an available Tier 1/1b value. Full rule: `proposals/PROPOSAL_point_valuation_governance.md` §2.
- **Commission-blind** — enforced at the data layer, not just as policy. The pipeline never touches affiliate/commission data.
- **V1 is dead.** Production reads only the V2 tables (`card_products`, `earn_rates`, `card_caps`, `card_exclusions`). The old `cards` / `card_earn_rates` tables are not in any read path. (See decision 2026-04-16.)
- **French is V1 scope, but not yet done.** The FR-CA source rows are still blank — placeholder, not verified.
- **Offer stacking + MCC routing** are captured in data but **not active in production.** Don't describe them as live features.
- **Safe public claims:** "issuer-verified," "95+ cards," **"15 issuers."** (The registry CSV has exactly 15 distinct issuer labels: Amex, BMO, CIBC, Canadian Tire, Desjardins, HSBC, MBNA, National Bank, PC Financial, RBC, Rogers, Scotia, Simplii, TD, Tangerine. Older docs said "16" — that was wrong; 15 is correct. If "16 issuers" appears anywhere on the live site, fix it.)
- **No ads.** Hard constraint.

---

## 2026-07-02 — Folder recovery addendum

Files the ghost list above said were absent that turned out to exist, found during
the 2026-07-02 folder recovery, and where each now lives:

- **Audit workbook:** `cardcoach_initial_load_audit_pack_canada_2026-06-07_v24_cleaned.xlsx`
  at repo root is canonical (re-designated 2026-07-16; verified: 95 unique cards, 15
  issuers, v22→v23→v24 lineage sheets intact). v23 patchready is superseded — archived
  2026-06-10 to `_archive/files/`.
- **Revenue model:** `01_CORE/data/CardCoach_Phase4_Revenue_Model_v2.xlsx` (materialized 2026-06-09;
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
anything committed to `main` ships live within ~1 minute. Open: `www.cardcoach.ca`
dead-ends and needs a www→apex redirect (WORKING_NOTES #21).

---

*This file supersedes any conflicting file reference in older docs. When a referenced
file can't be found, this list is the authority on whether it should exist.*
