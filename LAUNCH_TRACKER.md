# LAUNCH_TRACKER.md — The Playbook go-live sequence
Updated 2026-07-01. Check items off as they complete. Owner key: [M]ike · [CW] Cowork · [C]laude chat.
Last updated: 2026-07-31 (stamp added per SYNC_PROTOCOL landing-date rule; content unchanged)

## Stage 1 — Project knowledge complete  ← YOU ARE HERE
- [x] Rule 3 supersedence clause added to project instructions
- [ ] [M] Add to project: post-01, post-02, post-04 markdown (completes the 6-post source set)
- [ ] [M] Add to project: render_v2.py + build_demo.py — use the .py.txt copies (now in
      `99_ARCHIVE/restored-script-artifacts/`, moved 2026-07-03, byte-identical to the
      live .py files) if your upload path converts .py to PDF again
- [ ] [M] Replace BLOG_OPERATIONS.pdf with BLOG_OPERATIONS.md (readable > printable)
- [ ] [M] Remove the partial rendered set from project knowledge (cash-back-vs-points.html,
      category-caps-explained.html, blog.html, sitemap.xml) — build artifacts live in the
      site folder, not project knowledge; partial copies go stale silently
- [ ] [M] Rule 4: "schema copy.txt" → SCHEMA.md (the file that actually exists)
- Exit test: project contains 6 post .md + 2 scripts + BLOG_OPERATIONS.md, no orphan HTML.

## Stage 2 — Local staging via Cowork (~30 min)
- [ ] [M] Put downloaded blog files + site folder on the machine running Cowork
- [x] [CW] DONE 2026-07-04 (launch session): eight post pages + blog.html + sitemap.xml
      (15 URLs) rendered into `01_CORE/site/` (flat) → Blog nav link added to all 6
      existing pages (desktop + mobile blocks) → footer-contrast CSS ships inside each
      rendered blog page (site-wide styles.css patch still optional, item 5 below) →
      demo rebuilt (`blog/cardcoach-blog-demo.html`, covers blog + 6 original posts)
      *[Update 2026-07-05 (final render): posts 08+09 publish-cleared, sitting riders
      applied — site/ now holds 10 post pages + blog.html (10 cards) + sitemap.xml
      (17 URLs); demo rebuilt (blog index + 10 posts, 160 KB). Catalog at 10.]*
- [ ] [M] Review Cowork's change summary; if the script test-run reports a render mismatch,
      bring it back to chat — do not let it self-reconcile
- Exit test: integrity checklist green; deploy folder ready.

## Stage 2b — SITE v2 (Cowork build 2026-07-05) — COMPLETE, in the same deploy zip
- [x] [CW] T0: funnel interim (badges → "Coming soon" spans + Playbook line, 5 pages);
      DATE POLICY (real dates only — 6 posts → 2026-07-04 launch date, dateModified =
      render date, "Verified <ledger>" labels, renderer tripwires); footer contrast at
      source (0.65/0.70 ≥ 5.69:1); full heads on 6 static pages; color-scheme pinned site-wide
- [x] [CW] T1: favicon trio · robots.txt · 404.html · Track-1 audit mechanical stragglers
      folded (13 svg aria-hidden, sitemap homepage → /, post-07 `**` renderer fix)
- [x] [CW] T2: 4 pillar hubs (POSTS has 4 pillars, not 5 — dispatch count corrected) +
      motif system + blog index v2 (chips/thumbnails/Start-here) + auto-TOC + 68ch +
      21 OG images (Lora stands in for Literata — no font network in-session) +
      post.css extraction (rendered pages byte-identical; −61.8 KB)
- [x] [CW] Waitlist scaffold parked on FORM_ENDPOINT (unlinked, noindexed, disabled —
      no dead form); fonts self-host skipped (no network) — external css2 stands
- [ ] [M] **ONE TODO:** create form endpoint (Formspree/Buttondown/etc.) → paste into
      FORM_ENDPOINT (top of scripts.js) → flip the marked download-section comments →
      link waitlist.html + remove its noindex (~5 min)
- Exit state: site/ = 56 files, 783 KB, sitemap 21 URLs, verification clean —
  one zip → Cloudflare ships everything (SITE_AUDIT md moved out of the deploy folder).
- [x] [CW] ADDENDUM v2 (2026-07-05, same deploy zip): tangerine-ink text/CTA token (all
      pairs ≥4.71:1, hovers 6.15:1) · one footer md5 sitewide (both bottom lines + Blog) ·
      pillar renamed "Rewards Mechanics" → "How Rewards Work" (Mike's copy verbatim; files,
      OG, sitemap swapped; old names zero on disk/refs) · UTM campaign = post slug (renderer-
      derived, 9 changed) · lang="en-CA" ×23 · hamburger/FAQ aria-controls + label toggle ·
      ledger "ships on purpose" headers · cream cards · legal/per-litre descriptions ·
      per-URL sitemap lastmod truth. Verification clean; 23 pages / 56 files / ~788 KB.

## Stage 3 — Go live (~20 min, Mike only — credentialed actions)
- [ ] [M] Deploy to Cloudflare Pages
- [ ] [M] Google Search Console: verify cardcoach.ca, submit sitemap.xml   ← gates ALL measurement
- [ ] [M] Enable Cloudflare Web Analytics; grab the beacon snippet
- [ ] [CW or C] Inject analytics snippet into all pages; redeploy
- [ ] [M] Phone-check live pages incl. footer contrast + dark-mode behaviour
- Exit test: blog.html reachable from site nav; sitemap accepted in Search Console.

## Stage 4 — Parked decisions (no urgency, but decide — don't drift)
- [ ] [M] FR: name a human French reviewer OR declare EN-first launch (brand rule requires
      human-reviewed FR; today it's EN-only in practice). FR blog name candidate:
      «Le Plan de match» — needs reviewer sign-off
- [ ] [M] Confirm whether the 2026-06-10 Scotia SQL handoff already encodes the per-tier
      caps; if not, it's delta #1 below

## Stage 5 — Standing loops
WEEKLY (2 posts):
- [x] [C] #6 do-points-expire DRAFTED, signed off + rendered in the 2026-07-04 launch
      batch; #8 per-litre-vs-percentage OUTLINED (OUTLINE_post-08.md — draft next;
      keeps Triangle/PCF as [VERIFY])
      *[Update 2026-07-04, housekeeping sweep 2: #8 and #9 since DRAFTED
      (post-08-per-litre-vs-percentage.md, post-09-bmo-blue-rewards.md — both
      ⛔ publish-blocked, under Mike's review, not in render_v2 POSTS); both
      outlines archived → `99_ARCHIVE/planning/2026-07/`.]*
      *[Update 2026-07-05: #8 + #9 cleared Mike's fact check (2026-07-05 sitting),
      riders applied, gates flipped ✅, rendered into site/ (in render_v2 POSTS).]*
- [ ] [C] Fact-check gate: approved-only assertions, live-issuer check, ledger updated
- [ ] [CW] Render + stage into site folder (add POSTS entries, run both scripts)
- [ ] [M] Deploy
MONTHLY:
- [ ] [C] 20-prompt AI-citation check (log in BLOG_OPERATIONS.md); refresh KPI readout
DATA LANE (next Stage-2 batch):
- [ ] [M] Workbook deltas 1–5 (Scotia per-tier · Cobalt $2,500/mo · TD per-category ·
      BMO CWE $139 · CIBC Costco combined $5K gas bucket) — details in BLOG_OPERATIONS.md

## Content queue after #6/#8 (from the 26-post calendar)
#10 Loblaws (blocked on PC Financial reverification post-July; note Loblaws ≠ Amex) →
#11 annual-fee-worth-it → #12 no-fee showdown → per calendar in BLOG_OPERATIONS.md.
*[Update 2026-07-04, housekeeping sweep 2: PCF reverification completed 2026-07-02;
#6 and #10 publish-cleared + rendered in the 2026-07-04 launch batch (awaiting
Mike's Cloudflare deploy). Queue proceeds #11 → #12 once 08/09 clear review.]*
*[Update 2026-07-05: 08/09 cleared + rendered (final render, catalog at 10);
queue is live at #11 annual-fee-worth-it. Deploy remains Mike's Stage-3 step —
one zip site/ → Cloudflare ships everything.]*

## Deploy channel (as of 2026-07-05)
Push to `main` on `cardcoach-site` → Cloudflare Workers Builds auto-deploy (project imported as Workers static assets, 2026-07-05). Branch pushes = preview URLs
(use for review sittings before merging). `wrangler pages deploy` = break-glass only.
Drag-and-drop retired. Render sessions end with commit+push once Mike confirms the publish gate.
*(Supersedes the "one zip site/ → Cloudflare" note above.)*
