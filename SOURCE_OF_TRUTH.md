# CardCoach — Source of Truth

**Open this file first. Always.**
Last updated: 2026-07-08 · Owner: Mike

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
- **Live at `https://cardcoach.ca`** — canonical as of 2026-07-08; `card.coach` = 301 (path + query preserved). Hosted as a **Cloudflare Worker serving static assets** (worker: `cardcoach-site`) — not classic Cloudflare Pages. *(Domain flipped 2026-07-08, superseding the 2026-07-05 defensive-domain direction — repo cutover done in the worktree; the Cloudflare-side cutover (custom domain + 301 reversal) is pending Mike. The 2026-07-05 zip-workflow correction stands below.)*
- Cloudflare Web Analytics token: `f75218d6a9ea4e0787f5a3c6901ebde2` (swapped 2026-07-08 with the domain flip; the old `a3f06983…` token is retired).
- **Deploy workflow:** edit locally in the `01_CORE/site/` git worktree → commit → **push to `main` → Cloudflare Workers Builds auto-deploys**. Branch pushes give preview URLs. Zip uploads are retired; zips in `00_COWORK/_OUTPUTS/` serve as point-in-time records only. *(Corrected 2026-07-05.)*

**Card data**
- `card_sources_seed_enriched.csv` — the Stage 1 registry of issuer source URLs. **Real, on disk.**
- 95+ cards · 15 issuers · 442+ earn rates · 155+ caps (dataset v23, 2026-03-14; PCF net-new adds pending).
- The actual card facts (earn rates, caps, fees, point values) live in the **Supabase database**, governed by the pipeline. They are NOT re-derivable from the docs alone.

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
| `schema.public.sql` | Referenced by `README.md` but **not delivered into this folder.** Confirm with Alex. |
| `build_onepager.py` | Not in this folder. Source for the pipeline brief PDF. |
| `CardCoach_Brand_Sheet_Mikayla.pdf` | Referenced in the brand kit. **Not in this folder.** |
| `CardCoach_Chip_Contrast_Test.pdf` | Referenced in the brand kit. **Not in this folder.** |
| `CardCoach_Email_Signature.html` | Referenced in the brand kit. **Not in this folder.** |
| Brand docx (`WarmLogic_BrandKit`, `Colors_and_Fonts`) | Replaced by `BRAND.md`. |
| Stage 3 prompt PDFs (`stage3_reverify_prompt`, v1.1) | Full prompt now in `STAGE3_PROMPT.md`. |
| Phase 4 PDFs (`Revenue_Model`, `Revenue_Summary_v2`) | Both were renders of the v2 model. Consolidated into `REVENUE.md`. |
| `CardCoach_Phase4_Revenue_Model_v2.xlsx` | The live revenue model (866 formulas). **Not in this folder.** Needed to flex assumptions — the PDFs were just renders of it. |
| "audit workbook" (.xlsx) | **Does not exist in this project.** Card-level facts can't be verified from docs without it. |
| reverification "SQL files" (in old rules) | No `.sql` files exist here. Reverification exists as a *prompt*, not executable SQL. |

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
- **Safe public claims:** "issuer-verified," "95+ cards," **"15 issuers."** (The registry CSV has exactly 15 distinct issuer labels: Amex, BMO, CIBC, Canadian Tire, Desjardins, HSBC, MBNA, National Bank, PC Financial, RBC, Rogers, Scotia, Simplii, TD, Tangerine. Older docs said "16" — that was wrong; 15 is correct. If "16 issuers" appears anywhere on the live site, fix it.)
- **No ads.** Hard constraint.

---

## 2026-07-02 — Folder recovery addendum

Files the ghost list above said were absent that turned out to exist, found during
the 2026-07-02 folder recovery, and where each now lives:

- audit workbook → `01_CORE/data/cardcoach_initial_load_audit_pack_canada_2026-03-13_v23_patchready.xlsx` → recovered; current card-fact reference.
- `CardCoach_Phase4_Revenue_Model_v2.xlsx` → `01_CORE/data/CardCoach_Phase4_Revenue_Model_v2.xlsx` → recovered; the live 866-formula model.
- `schema copy.txt` → `99_ARCHIVE/superseded-governance/` → existed after all; consolidated DDL through migration 0037, superseded by SCHEMA.md (43 migrations).
- `schema.public.sql` → `01_CORE/data/` → recovered; 2026-04-15 dump, Alex's repo authoritative.
- `card_sources_ddl.sql` → `01_CORE/data/card_sources_ddl.sql` → recovered; dated 2026-04-25, Alex's repo authoritative.
- `CardCoach_Brand_Sheet_Mikayla.pdf` → `01_CORE/brand/CardCoach_Brand_Sheet_Mikayla.pdf` → recovered; newest copy.
- `CardCoach_Chip_Contrast_Test.pdf` → `01_CORE/brand/CardCoach_Chip_Contrast_Test.pdf` → recovered; newest copy.
- 2026-07-02 (second pass): filenames normalized to docs-canonical underscore names; naming drift closed.

Where this addendum conflicts with the ghost list above, this addendum governs.

---

*This file supersedes any conflicting file reference in older docs. When a referenced
file can't be found, this list is the authority on whether it should exist.*
