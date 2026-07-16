# CardCoach — Clean Document Set

This folder is the consolidated, plain-Markdown replacement for the old CardCoach project
file pile. Everything here is real, cross-checked against what's actually on disk, and free
of references to files that don't exist.

**Start with `SOURCE_OF_TRUTH.md`.** It's the index and the authority on what to trust.

---

## What's in this folder (the clean set)

| File | What it is |
|------|-----------|
| `SOURCE_OF_TRUTH.md` | **Open first.** Index of every real file + the "these don't exist, stop looking" ghost list. |
| `HOW_THE_ENGINE_WORKS.md` | The data model + pipeline truth. V1 is dead; V2 is live. |
| `PIPELINE_AND_DECISIONS.md` | The reverification pipeline + the append-only decisions log. |
| `WORKING_NOTES.md` | The only file that churns — open items, owners, next actions. |
| `STAGE3_PROMPT.md` | The full Stage 3 reverification prompt (recovered, complete). |
| `BRAND.md` | Warm Logic brand: palette, type, logo, voice, rules. |
| `REVENUE.md` | The Phase 4 v2 revenue model (free web + paid iOS). |
| `stage2_fetcher.py` | The Stage 2 source fetcher — **recovered** and compile-checked. |

These replace the entire old PDF/docx governance pile.

---

## Files to KEEP in the project (not in this folder — already real on disk)

These are real, current, and should stay. They are NOT duplicated here because they didn't
need rewriting.

**Database / schema**
- `SCHEMA.md` — the live Supabase schema reference (48 tables, 18 views, 43 migrations).
- `README.md` — schema handoff notes.

**Card data**
- `card_sources_seed_enriched.csv` — the Stage 1 registry the fetcher runs against. **Load-bearing — do not delete.**

**Brand assets**
- `CardCoach_Mark_Light.png`
- `CardCoach_Mark_Dark.png`
- `CardCoach_Lockup_Light.png`
- `CardCoach_Lockup_Dark.png`

**Live website**
- `index.html`, `about.html`, `how.html`, `support.html`, `legal.html`, `privacy.html`
- `styles.css`, `scripts.js`

---

## Files to DELETE from the project (superseded — content preserved above)

All of these were either reformatted into the clean set or are stale narrative. Their useful
content is captured in this folder.

**PDFs**
- `PIPELINE.pdf`, `OPEN_ITEMS.pdf`, `DECISIONS.pdf` → folded into `PIPELINE_AND_DECISIONS.md` + `WORKING_NOTES.md`
- `CardCoach_Pipeline_Brief.pdf` → summarized in `PIPELINE_AND_DECISIONS.md`
- `stage2_README.pdf`, `stage2_fetcher.pdf` → the runbook is in `PIPELINE_AND_DECISIONS.md`; the code is now `stage2_fetcher.py`
- `stage3_reverify_prompt.pdf`, `stage3_reverify_prompt_v1_1.pdf` → `STAGE3_PROMPT.md`
- `CardCoach_App_Prototype_WarmLogic.pdf`, `CardCoach_Web_App_V1_Scope.pdf` → UX intent only; superseded by current build truth
- `CardCoach_Phase4_Revenue_Model.pdf`, `CardCoach_Phase4_Revenue_Summary_v2.pdf` → `REVENUE.md`

**docx**
- `CardCoach_Master_Context_Pack.docx`, `CardCoach_File_Index.docx` → replaced by `SOURCE_OF_TRUTH.md`
- `CardCoach_Decisions_Addendum.docx`, `CardCoach_Whats_Live.docx` → folded into the decisions log + working notes
- `CardCoach_Operating_Model.docx` → its governance content is distributed across the clean set
- `CardCoach_App_Design_Session_Notes.docx` → UX intent only
- `CardCoach_WarmLogic_BrandKit.docx`, `CardCoach_Colors_and_Fonts.docx` → `BRAND.md`

---

## The genuine gaps (real files that were never delivered here)

Not lost, not pretended into existence — just not in this project. If you find them in
another chat or on your machine, drop them in and they can be folded into the set. Full list
is in `SOURCE_OF_TRUTH.md`; the ones that actually matter:

- `CardCoach_Phase4_Revenue_Model_v2.xlsx` — **NOW IN THE PROJECT** (added June 2026). The live revenue model, 866 formulas. The PDFs were renders of it. Use the xlsx to flex assumptions; REVENUE.md remains the narrative authority.
- The **audit workbook** (.xlsx) — **NOW IN THE PROJECT** as `cardcoach_initial_load_audit_pack_canada_2026-06-07_v24_cleaned.xlsx` (canonical, at root). v24 = v23 data, cleaned. Counts unchanged: 95 cards · 442 earn rates · 155 caps.
- `card_sources_ddl.sql` / `schema.public.sql` — DDL referenced by the docs; the live schema is captured in `SCHEMA.md`, but the raw SQL was never delivered here.

Everything else the old docs referenced is accounted for.
