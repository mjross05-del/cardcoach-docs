# CardCoach — Source of Truth

**Open this file first. Always.**
Last updated: 2026-06-10 · Owner: Mike

This is the only file that tells you what to trust. If any other document points you
at a filename, check it against the lists below before you go looking for it. Most of
the old references are dead — see "Files that DO NOT exist" at the bottom.

---

## The 30-second orientation

CardCoach is a Canada-only, issuer-verified credit card recommendation product under
the **Warm Logic** brand. Three things are real and built:

1. **The database** — a live Supabase schema (48 tables, 18 views, 43 migrations). Real. Done. The asset.
2. **The reverification pipeline** — a 3-stage system that keeps card data current. Infrastructure complete; first real run not done yet.
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
| `PIPELINE_AND_DECISIONS.md` | The reverification pipeline, plus the append-only log of settled decisions. | Append-only — add, never rewrite |
| `WORKING_NOTES.md` | What's unresolved, who owns it, what's next. The churning to-do reality. | Often — this is the only one that churns |
| `STAGE3_PROMPT.md` | The full reverification prompt you paste into Claude. | Versioned — bump on rule/column changes |
| `BRAND.md` | Warm Logic brand: palette, type, logo, voice, rules. | Rarely |
| `REVENUE.md` | The Phase 4 v2 revenue model: free web + paid iOS. | Rarely — on strategy shifts |

Seven files. Plus `SCHEMA.md` and `README.md` (real, on disk, keep), and the recovered
`stage2_fetcher.py`. If you find yourself maintaining an eighth governance doc, ask whether
it belongs inside one of these instead.

---

## What's real on disk (don't reinvent these)

**Database**
- Live Supabase instance — 48 tables, 18 views, 43 migrations (as of 2026-04-15 schema generation).
- `SCHEMA.md` — human-readable schema reference. **Real, on disk, trustworthy.**
- `README.md` — schema handoff notes. **Real, on disk.**

**Brand**
- Warm Logic brand (palette, type, voice, the Chip logo) — now in `BRAND.md`.
- Logo PNGs: Mark + Lockup, Light + Dark. **The current, adopted logo.**

**Live site**
- `index.html`, `about.html`, `how.html`, `support.html`, `legal.html`, `privacy.html`, `styles.css`, `scripts.js`. **Real, deployed.**
- **Live at `https://card.coach`**, hosted on **Cloudflare Pages**.
- **Deploy workflow:** edit the HTML/CSS/JS locally → zip the folder → upload the zip to the Cloudflare Pages dashboard as a new deployment → live in ~30 seconds. No build step.

**Card data**
- `card_sources_seed_enriched.csv` — the Stage 1 registry of issuer source URLs. **Real, on disk.**
- 95 cards · 15 issuers · 442 earn rates · 155 caps (dataset v23, 2026-03-14).
- `cardcoach_initial_load_audit_pack_canada_2026-06-07_v24_cleaned.xlsx` — **the audit workbook (canonical, at root).** v24 = v23 data, cleaned. Counts unchanged: 95 cards · 442 earn rates · 155 caps. (v23 patchready archived 2026-06-10 → `_archive/files/`.) Row-level card facts: `cards` (95), `earn_rates` (442), `card_caps` (155), plus `Unsupported_Benefits` (4 per-litre gas rows), `RunReady_Exclusions` (17), and audit/patch/change-log tabs. This is where "issuer-verified" becomes checkable fact-by-fact (each row carries source clause references). The v23 tabs are current; the `Needs_Decision` tab is historical v22 (superseded by `V23_Patch_Summary` / `Card_Status_Rec`).
- The card facts also live in the **Supabase database** (governed by the pipeline). Between the database and this workbook, they ARE now verifiable — earlier docs said "not re-derivable from docs alone," which was true only while the workbook was missing.

**Revenue model**
- `CardCoach_Phase4_Revenue_Model_v2.xlsx` — **the live revenue model. RECOVERED — now on disk.** 866 formulas across 7 tabs (README, Inputs, Web Path, iOS Subscription, iOS Path, Monthly Model, Sensitivity). Edit blue input cells to flex assumptions and watch the 24-month projection recalculate. `REVENUE.md` is the prose summary; this is the calculator.

**Pipeline code**
- `stage2_fetcher.py` — the Stage 2 source fetcher. **Recovered from `stage2_fetcher.pdf` and now a real, compile-checked `.py` file.** Run it from a directory next to the registry CSV. See `STAGE3_PROMPT.md` for the Stage 3 half.

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
| `schema.public.sql` | Not in this folder, but **location known:** Alex's repo at `docs/schema-handoff/2026-04-15/` (per `README.md`). Raw DDL dump of the `public` schema. Regenerable via the `supabase db dump` command in `README.md`. The human-readable schema is `SCHEMA.md` (which IS here). |
| `build_onepager.py` | Not in this folder. Source for the pipeline brief PDF. |
| `CardCoach_Brand_Sheet_Mikayla.pdf` | Referenced in the brand kit. **Not in this folder.** |
| `CardCoach_Chip_Contrast_Test.pdf` | Referenced in the brand kit. **Not in this folder.** |
| `CardCoach_Email_Signature.html` | Referenced in the brand kit. **Not in this folder.** |
| Brand docx (`WarmLogic_BrandKit`, `Colors_and_Fonts`) | Replaced by `BRAND.md`. |
| Stage 3 prompt PDFs (`stage3_reverify_prompt`, v1.1) | Full prompt now in `STAGE3_PROMPT.md`. |
| Phase 4 PDFs (`Revenue_Model`, `Revenue_Summary_v2`) | Both were renders of the v2 model. Consolidated into `REVENUE.md`. |
| `CardCoach_Phase4_Revenue_Model_v2.xlsx` | **NOW IN THE PROJECT** (added June 2026). The live revenue model, 866 formulas. The PDFs were renders of it. Use the xlsx to flex assumptions; REVENUE.md remains the narrative authority. |
| Audit workbook (`..._v23_patchready.xlsx`) | **NOW IN THE PROJECT** as `cardcoach_initial_load_audit_pack_canada_2026-06-07_v24_cleaned.xlsx` (canonical, at root). v24 = v23 data, cleaned. Counts unchanged: 95 cards · 442 earn rates · 155 caps. v23 patchready archived 2026-06-10 → `_archive/files/`. |
| Four issuer reverification `.sql` files (Amex/RBC/TD/Scotia, 2026-02-18) | **Genuinely not here, and not a "find it" item.** These are *output* of running `STAGE3_PROMPT.md` against fresh snapshots — the Scotia Momentum dry run (`WORKING_NOTES.md` #1) produces the next one. Generated by doing the work, not recovered. |
| `CARDCOACH.md` | Retired 2026-06-10 → `_archive/files/`. Asserted the superseded JSON handoff. The decisions log in `PIPELINE_AND_DECISIONS.md` is the only authority. |
| `pipeline/DECISIONS.md` | Retired 2026-06-10 → `_archive/files/`. Parallel decisions log — drift risk. Superseded by `PIPELINE_AND_DECISIONS.md`. |
| `pipeline/OPEN_ITEMS.md` | Retired 2026-06-10 → `_archive/files/`. Superseded by `WORKING_NOTES.md`. |

**The rule:** if it's not in "What's real on disk" above, treat it as not-here until
someone produces it. The content is good; the file trail was broken. This list is the fix.

---

## Lanes (who owns what)

- **Mike** — data integrity, the reverification pipeline, governance, brand, ops.
- **Alex** — the app build, the scoring engine, the Supabase database deployment. SQL deltas get handed to him; he runs them. Don't push code/DB changes on Mike's side.
- **Mikayla** — marketing assets, Canva, social. Executes under Mike's direct review; does not ship independently.

---

## The few hard truths to never lose again

- **Canada-only.** Every record carries Canada applicability evidence.
- **Issuer-verified only.** Tier 1 (legal/disclosure) or Tier 1b (product page). Blogs/aggregators are review triggers, never truth.
- **Commission-blind** — enforced at the data layer, not just as policy. The pipeline never touches affiliate/commission data.
- **V1 is dead.** Production reads only the V2 tables (`card_products`, `earn_rates`, `card_caps`, `card_exclusions`). The old `cards` / `card_earn_rates` tables are not in any read path. (See decision 2026-04-16.)
- **French is V1 scope, but not yet done.** The FR-CA source rows are still blank — placeholder, not verified.
- **Offer stacking + MCC routing** are captured in data but **not active in production.** Don't describe them as live features.
- **Safe public claims:** "issuer-verified," "95 cards," **"15 issuers."** (The registry CSV has exactly 15 distinct issuer labels: Amex, BMO, CIBC, Canadian Tire, Desjardins, HSBC, MBNA, National Bank, PC Financial, RBC, Rogers, Scotia, Simplii, TD, Tangerine. Older docs said "16" — that was wrong; 15 is correct. If "16 issuers" appears anywhere on the live site, fix it.)
- **No ads.** Hard constraint.

---

*This file supersedes any conflicting file reference in older docs. When a referenced
file can't be found, this list is the authority on whether it should exist.*
