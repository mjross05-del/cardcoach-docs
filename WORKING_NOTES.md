# CardCoach Working Notes

**The only file that churns.** What's unresolved, who owns it, what unblocks it, what's
next. Update freely. When an item closes, **delete it** — closed items don't belong here.
Settled decisions move to `PIPELINE_AND_DECISIONS.md`; they don't live here.

Last updated: 2026-08-14 · Owner: Mike  (header date corrected 2026-07-04, housekeeping sweep 2 — was 2026-07-03, contradicting the 2026-07-04 dated updates within; prior correction 2026-07-03 — was 2026-06-02)

> For a future session: this is where you look to find what needs doing next. Don't
> re-propose items already listed here unless you have new information.

## Status index (added 2026-07-04, housekeeping sweep 2 — derived from the dated entries below; the entries stay authoritative)

- **#1** Scotia dry run — CLOSED 2026-07-04 (overtaken by the 2026-06-10 Scotia SQL handoff)
- **#2** Apply-delta helper script — not started; RESCOPED 2026-08-01 (input is now batch gated packages/parking rows, not Stage-3 JSON — script pipeline retired)
- **#3** French-language verification pass — not started (deferred post-V1); RESCOPED 2026-08-01 (vehicle is FR-CA passes inside the daily batches, not registry rows — registry retired)
- **#4** "Uncertain" registry entries (~10 landing-page rows) — CLOSED 2026-08-01 (retired with the registry; batch coverage-diff owns source discovery, per-card PDF paths accumulate in verify.issuer_notes)
- **#16** Blue Rewards tier successors (BMO) — CLOSED 2026-07-02
- **#5** Welcome-bonus data pipeline — design approved 2026-07-03; DB-side implementation pending
- **#8** Rogers cohort-differentiated rates — CLOSED 2026-07-04 (date-gated 2026-08-04 delta pre-staged; August confirmations remain; August-cycle fetcher/registry prep done 2026-07-05)
- **#9** PC Financial post-EQB — in progress (F2 post-close CMA, F3 standard-card income still open)
- **#10** Per-litre rate_unit enum — open, low priority (LANE CHANGE 2026-08-01: Mike's; pump case resolved by DATA-018 offers, enum only matters for catalog earn_rates)
- **#11** Legal review of affiliate disclosure — not started
- **#12** Commission-blind policy publication — not started
- **#13** Live-site hold-back claims — not started
- **#14** Point Valuations xlsx disposition — not started (LANE CHANGE 2026-08-01: Mike decides directly)
- **#15** File-for-Alex pack confirmation — not started (LANE CHANGE 2026-08-01: Mike decides directly)
- **#17** Waitlist endpoint (site v2 funnel) — OPEN (Mike, ~5 min; scaffold shipped 2026-07-05, see section below)
- **#18** Email routing on cardcoach.ca — not started (Mike, ~10 min; gates the domain-flip push)
- **#19** Site git wiring / deploy-channel cutover — wiring DONE 2026-07-05; G3 domain move pending (was a duplicate #16, renumbered 2026-07-08)
- **#20** Web app v1 (free recommendation surface) — approved 2026-07-13 (D1); P1 pending keys
- **#21** www.cardcoach.ca dead-ends — needs www→apex redirect
- **#23** merchant_list_only eligible lists — BACKFILLED PASS 1 + CHAIN BINDING FIX, 2026-08-02 (second live find: Google location-suffixed names minted orphan entities; 3 places re-pointed by delta, durable fix MERGED b13595f + migration applied to cloud (48 chains) + resolve-place v13 DEPLOYED with live 200s 2026-08-02; LAST STEP: `npx supabase functions deploy recommend-here-v2` on Mike's machine — 287KB closure exceeds the MCP deploy channel) (108 pairs / 21 of 31 rows; delta `deltas/2026-08-02__earn_rate_eligible_merchants__backfill_p1.sql`). Was EMPTY in production — every list-gated earn row failed closed everywhere; found via Mike's live Superstore test. Remaining: 10 rows deliberately fail-closed (network/classifier-defined); PC list is officially NON-EXHAUSTIVE (Provigo/YIG/Dominion/T&T unnamed in any official text — Sunday batch watches for an official enumeration); local seed.sql parity not done; Sunday/Sunday+Monday batches now maintain these lists via gated proposals.
- **#22** Loyalty stacking Phase 1 — **ACTIVATED 2026-08-02** (flag flipped 13:41 UTC, delta `deltas/2026-08-02__runtime_flags__loyalty_offer_stacking_on.sql`; all three gates closed; rule 5 superseded-in-part). Remaining tail in section below: counsel review before QC GA, batch parking reviews now carry live-data weight. Phase 1.1 (member-earn display + attribution notice) DISPATCHED 2026-08-02 for an Opus 5 session: `dispatches/DISPATCH_member_earn_display_2026-08-02.md` (DATA-019/API-014/APP-018; #1 invariant: response-level optional fields only — no new explanation-item types while the current build is live).
- **#25** API-011 disclosure slices (`mcc_defined` suppression) — **Slice 1 SHIPPED 2026-08-14**: `recommend-card-v2` v21, commit `f1a7158`. Adds `conditionalNotApplied[]` per recommendation plus two success-log fields, decided by the same exported `earnRowPrices` predicate that prices the rows (settled: see the 2026-08-14 entry in `PIPELINE_AND_DECISIONS.md`). Ranking byte-identical — RCSS `topCardId`/`cardCount` matched the same-day pre-deploy baseline on live taps; Kelsey's had no same-day v20 tap to compare against, so that half is unmeasured rather than verified. Governing doc is `HANDOFF_mcc_gating_accuracy_strategy.md` §6, which is **not filed anywhere on the machine** — searched 2026-08-14 by filename and by content across `~/dev`, `~/Documents`, `~/Downloads`, `~/Desktop`; only the rising-tiers and cpp-valuation handoffs exist. Its slice list beyond Slice 1 and its D-series decisions are unrecorded, so recover it (or ask Mike) before running Slice 2+; file it at this repo's root next to `HANDOFF_engine_rising_tiers_2026-08-12.md`. Execution record for what actually shipped, explicitly not a substitute for the strategy: `dispatches/NOTE_mcc_gating_slice1_2026-08-14.md`. The `default_category_id` runtime write-back listed here is DONE — commit `86c6110`, **deployed v22** (so prod is v22, not the v21 that carried Slice 1; use v22 for any drift check). Remaining: **D3 user-facing copy**, which gates all client rendering — the field ships in the API but nothing reaches users until D3 lands; engine-contracts type additions (ride the D3-gated client commit); and the `assumptions` response key, occupied by `fuelAssumptions` in v2 (Slice 5 decision).
- **#26** Category self-heal writes on the merchant read paths — **9 sites still open** (catalogued at `DESIGN_place_resolution_v1.md:27`): `recommend-here-v2/index.ts` ×6 (~lines 217, 222, 234, 270, 275, 283) and `resolve-place/index.ts` ×3 (~lines 425, 443, 507). These UPDATE `merchant_entities.default_category_id` from ordinary user traffic — unaudited merchant-graph DML, which the 2026-08-12 audit-class decision forbids and PROJECT_RULES rule 9 puts in SQL deltas instead of code. `recommend-card-v2`'s single site was removed 2026-08-14 (`86c6110`, v22; that function now performs no writes at all), but **these nine are NOT a mechanical removal**: unlike the one already fixed, they also write *reclassified* categories derived from live Google place types, so deleting them loses real classification improvement. Needs a decision on where reclassification should happen instead (gated delta from a queue? a batch lane? resolve-place only, audited?) before any code moves. Context for why unattributed merchant-graph writes are expensive: `DESIGN_place_resolution_v1.md` §1.4. Related data check 2026-08-14: all 344 non-null `default_category_id` rows are already canonical and `classifyPlace` can only emit canonical slugs, so the *normalization* half of these self-heals is dead code — only the reclassification half still does anything.

---

## #1 — Unblock the first real pipeline run (Scotia Momentum dry run)

- **Status:** CLOSED 2026-07-04 (Mike): overtaken by the 2026-06-10 Scotia SQL handoff.
- **Owner:** Mike + Alex
- **Blocker:** Alex needs to confirm the SQL file format he wants for approved deltas.
- **Next action:** Mike pings Alex to confirm the handoff format, then runs Stage 2 + Stage 3 for **Scotia Momentum Visa Infinite only**, produces a mock SQL delta, and walks through it with Alex.
- **Context:** Single-card dry run to prove the loop works end-to-end before committing to a monthly cadence. Scotia Momentum chosen because its earn structure is well-known, its Revolving Credit Agreement pattern is typical, and it's not mid-change. Low-stakes proof.
- **Also note:** `stage2_fetcher.py` is now recovered and compile-checked (it had been trapped inside `stage2_fetcher.pdf`). Before the run, `pip install requests pdfplumber beautifulsoup4`, then validate with `--dry-run`, then a one-issuer smoke test (`--issuer Amex`). It has never been executed against the live registry, so treat the first real run as a test of the script too, not just the data.

## #2 — Apply-delta helper script

- **Status:** not started — RESCOPED 2026-08-01 (script pipeline retired; the Stage-3-JSON framing is dead)
- **Owner:** Mike
- **Blocker:** None hard. Worth building once gated-package volume justifies it.
- **Next action:** ~100 lines that turn a batch **gated package / parking row** into the dated delta SQL file rule 10(b) requires (expire-then-insert, guards, snapshot preamble). The 2026-06-10 one-file-per-card handoff-format decision still applies to the output.
- **Context:** The daily batches classify structural changes as gated and record loyalty reverify results in verify.parking; applying them is manual SQL authoring today. The helper closes that gap in the new process.

---

## Data coverage gaps

### #3 — French-language verification pass
- **Status:** not started — RESCOPED 2026-08-01 (registry retired; "324 blank FR-CA rows" no longer the unit of work)
- **Owner:** Mike
- **Blocker:** None — scope only. Deferred to post-V1 per the 2026-04-22 decision.
- **Next action:** When V1 stabilizes, add an FR-CA leg to the daily batch prompts (fetch each issuer's FR pages alongside EN, diff the facts, record divergences as gated) — or run one dedicated FR sweep session per issuer, batch-style, ~3 hours total.
- **Context:** Quebec is a distinct launch channel, not a translation target. FR pages diverge from EN (Desjardins Bonidollars classification, National Bank product tier names). Needs its own review.
- **Watch:** reconcile the "French in V1" wording with the Operating Model — French is a V1 *market* commitment; French *source reverification* is the deferred piece. Say it once, in one place.

### #4 — "Uncertain" registry entries — ~10 landing-page rows
- **Status:** CLOSED 2026-08-01 — retired with the registry (script pipeline retirement, PIPELINE_AND_DECISIONS 2026-08-01 entry).
- **Context kept for the record:** CIBC Aeroplan benefits guides, MBNA Mastercard Benefits, and Rogers per-card benefits guides were landing-page-only registry rows. The need survives in the new form: batches resolving a direct per-card PDF record it in verify.issuer_notes for that issuer, which every future run reads first.

### #16 — Blue Rewards tier successors (BMO)
- **Status:** CLOSED 2026-07-02
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** None — no remaining BMO capture items. BMO's only standing item is the manual monthly fetch (bot block), noted in the infrastructure section.
- **Context:** **World Elite RESOLVED** — captured + delta filed (`2026-07-02__bmo__blue-rewards-world-elite.sql`); **fee + income resolved 2026-07-02** (product page captured: fee $150 waived yr 1 with chequing rebate; income $80K/$150K — fee delta filed). **World tier RESOLVED as no-successor** — closure delta filed (`2026-07-02__bmo__air-miles-world-closure.sql`): application_status closed, earn rows expired without replacement.

### #5 — Welcome bonus data pipeline
- **Status:** design approved (Mike, 2026-07-03 — PROPOSAL_welcome_bonus_schema_2026-07-03, all seven open questions resolved)
- **Owner:** Mike
- **Blocker:** None — flagged as a "significant gap" in data governance.
- **Next action:** DB-side implementation sits documented until picked up; capture flow may begin populating offer records as drafts once tables exist.
- **Context:** Welcome bonuses drive applications, and therefore affiliate revenue. Currently not in the verified dataset at all. Separate from the monthly loop but shares source material.
- **Example data for the schema decision (verified 2026-07-02, note-only):** PCF no-fee stream — 50,000 pts on $100 qualifying spend at named banners within 60 days, apply by 2026-07-31. PCF Insiders — 50,000 pts after $3,000 in 3 months + $120 first-year credit. Standard PC Mastercard: 20,000-point special offer (Silver product chart, seen 2026-07-02) — distinct from the 50K stream offer. All time-bounded and offer-specific — supports the separate-table option. Welcome bonuses remain outside the verified dataset.
- **Example #5 (added 2026-07-03):** Scotia Gold Amex offer rollover caught live 2026-07-03: page still displayed the 45K offer (window ended 2026-07-01) while the current offer is 50K (2026-07-02 → 2026-11-01, two-instalment structure). Proof case for offer-reverification cadence faster than the monthly loop.
- **Example #6 (added 2026-07-04, Rogers gate-3):** Rogers limited-time +1% cash back at eligible Rogers-POS/Clover small-business merchants (compare_cards fn14) — note-only, outside verified dataset; another time-bounded, merchant-scoped offer shape for the schema.
- **Example #7 (added 2026-07-05, Blue Rewards):** "Card Offers" targeted-offer layer — targeted, opt-in, time/quantity-limited (Blue Rewards Program Agreement, bluerewards.ca/en/terms.html, captured 2026-07-05). Offer-pile, note-only.

---

## Point valuation (CPP) verification

- **PC Optimum (verified 2026-07-02):** redemption floor 10,000 pts = $10 (0.1¢/pt), issuer-stated on the earning-rates legal page — input for the `point_programs` dataset.
- **Blue Rewards expiry [VERIFY] — CLOSED 2026-07-05:** 24-month Member-Account inactivity clause LIVE-VERIFIED (Program Agreement, bluerewards.ca/en/terms.html, captured 2026-07-05; Quebec notice/cure variant). Ledgered in post-06 + BLOG_OPERATIONS 2026-07-05. The gap lived in post-09 FLAG-4 / post-06 pre-draft inventory — no numbered item existed here; closure recorded so the trail resolves.

*(#6 Air Miles CPP and #7 More Rewards CPP closed and deleted 2026-07-31 — both resolved
2026-07-29: `airmiles-points` retired, `more-rewards-points` verified. Trail:
PIPELINE_AND_DECISIONS 2026-07-29 entry + `HANDOFF_cpp_valuation_lane_2026-07-29.md` in
CardCoachv2.)*

---

## Material issuer changes to watch

### #8 — Rogers rewards — cohort-differentiated rates
- **Status:** CLOSED 2026-07-04 — Stage-3 completed from the 2026-07-02 snapshots (supplied in `01_CORE/CardCoach/Reverify Script/snapshots/`)
- **Owner:** Mike (data)
- **Blocker:** None.
- **Next action:** GATE-3 RIDER APPLIED 2026-07-04 — **Aug-4 watch RESOLVED AHEAD OF SCHEDULE** (notification.pdf captured: amounts $16K/$26K/$61K + verbatim amended clause text in hand; WL explicitly uncapped). Remaining actions: (1) apply the pre-staged `2026-08-04__rogers__tiered-caps.sql` on/after Aug 4 (date-gated, APPLY_CHECKLIST §0); (2) August fetch confirms live pages match the notice (and whether the issuer fixes the WE amended-s.4 typo); (3) capture the per-card Rewards T&C docs referenced in notification.pdf (registry rows note this). Resolved at gate-3: fee table (WL $495/$95 AU; $0 all others incl. Fido — Disclosure 02/2026), WL conditional earn (1.5%/2% definitive) + no-cap + 0% FX + redemption-bonus participation, Red World full spec (net-new: fee $0, income $50K/$80K page-confirmed, 1%/2% USD/2% subscriber, Aug-4 $26K) + registry rows added, Fido application_status → closed (delta filed), Platinum closed noted. **WL income remains the sole Rogers [VERIFY].** **August-cycle prep DONE 2026-07-05:** registry + fetcher synced into `Reverify Script/` — the August Stage-2 run now fetches the current 98-card / 717-line world (20 Rogers rows incl. Red World; PC Silver + Blue Rewards URL fixes live); Jun-10 versions archived at `99_ARCHIVE/registry-versions/`; redundant snapshot copies removed (canonical `snapshots/` is the sole set).
- **Context:** **Decision settled 2026-06-10** (new-cardholder Feb 26, 2026 representation; Fido `scoring_status = load_only`) — applied 2026-07-04. Representation rule applied: earn_rates stores unconditional rates; subscriber uplift + verbatim qualifying-service definition (FAQ version, incl. Comwave) live in condition_text; account_bundle rows expired. NEW at 2026-07-02: both Red support pages pre-announce annual limits on subscriber-uplift rates effective 2026-08-04, amounts not stated.

### #9 — PC Financial post-EQB acquisition
- **Status:** in progress — watching for CMA publication
- **Owner:** Mike
- **Blocker:** New post-close Cardholder Agreement not yet published/captured (F2).
- **Next action:** Watch for the post-close CMA URL; capture it and the hosted 07/2026 Disclosure Summary URL, and pin down the standard card's own income threshold (F3 — [VERIFY: issuer-verified data needed]).
- **Context:** Close confirmed 2026-07-01. Post-close Disclosure Summary (07/2026, references EQ Bank) verified in hand. **Full four-tier reverification completed 2026-07-02** — see BLOG_OPERATIONS.md log and `01_CORE/data/deltas/2026-07-02/`. **F1 RESOLVED 2026-07-02: pc-silver-mastercard = standard card's new product page, no product or rate change; registry updated.** Remaining scope: F2 (post-close CMA URL — watching) and F3 (standard-card income threshold). The June 2025 CMA in the registry is confirmed pre-close/stale.

---

## Infrastructure / tooling

### #10 — Per-litre `rate_unit` enum extension
- **Status:** open, low priority — LANE CHANGE 2026-08-01: Mike's (Alex stepped back; "awaiting Alex" no longer a blocker state). Pump-case pressure is OFF: DATA-018 gives per-litre facts a canonical `offers` home (b0ff0005/6/7), so the enum now only matters for card-catalog `earn_rates` representation.
- **Owner:** Mike
- **Blocker:** None — priority only.
- **Next action:** Fold into a future earn_rates schema pass if catalog-side per-litre representation is ever wanted; otherwise leave — the offers home covers the till moment.
- **Context:** Canadian Tire (cents/litre) and PC Financial (points/litre) gas rewards are captured but parked. Unblocks when the enum gains `cents_per_litre` and `points_per_litre`.
- **Update 2026-07-02:** PCF gas rates now fully verified and waiting on the enum — World ≥30 pts/L; Insiders ≥50 pts/L (+20 bonus pts/L in months with ≥150L at Esso/Mobil → 70), loyalty-inclusive, price-dependent. Strengthens the case when Mike raises this with Alex.

### BMO Stage-2 fetch is manual until further notice
- **Note (2026-07-02):** bmo.com bot protection resets the fetcher's connections (confirmed 2026-07-02: script fails, browser loads fine). Monthly loop for BMO = manual browser capture of the 13 registry URLs, Stage-3 from captures.

### Capture methods
- **Note (2026-07-05):** bluerewards.ca blocks HTML save — capture via print-to-PDF (method of record for the 2026-07-05 Program Agreement capture).

### Open schema questions (for Alex — consolidates the 2026-07-02 delta audit notes)
- From the PCF deltas: no income-eligibility columns on `card_products`; no documented `source_url` column on `earn_rates`; no `Unsupported_Benefits` table in SCHEMA.md; Joe Fresh category mapping unresolved.
- Appended 2026-07-02 (late, BMO passes): `categories` enum may lack `alcohol` and `gas_ev` (needed by Blue Rewards accelerators); `point_programs` needs a `blue_rewards` entry; eclipse VI shows a fifth 5x tile "Takeout & food delivery" with no workbook row (cap/category [VERIFY: issuer-verified data needed]); eclipse VI eligibility offers an income OR $15,000-annual-spend alternative — first spend-based eligibility seen, representation open.
- Appended 2026-07-02 (close): partner cap differs by tier (standard $500 vs WE $1,000 combined per statement cycle) — scorer must key partner caps per card, not per program.

### Blue Rewards banking bundle (note-only)
- **Note (2026-07-02):** 500 bonus pts/month with WE card + Blue Rewards Chequing (landing page fn16); debit earn 1 pt/$2. Bundle/offer-stacking territory: captured-not-active.

---

## Revenue / trust (shares stakeholders with the pipeline, not blocked by it)

### #11 — Legal review of affiliate disclosure copy (EN + FR)
- **Status:** not started
- **Owner:** Mike
- **Blocker:** Needs external Canadian financial-services-literate legal counsel.
- **Next action:** Identify and engage counsel for bilingual disclosure review.
- **Context:** This is the highest-leverage unblocking decision in the broader revenue work — and it's been cold since well before this cleanup. Affiliate revenue is the primary V1 path and it can't activate without this. Listed here because it shares the pipeline's trust posture.

### #12 — External publication of the commission-blind integrity policy
- **Status:** not started
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** Decide whether to publish the commission-blind architecture externally (blog, about page, partner docs). Marketing/brand call, not a data call.
- **Context:** The architecture is defensible and trust-building. Parked here because it's tied to this pipeline's credibility.

---

## Live-site compliance (flagged, needs legal before copy changes)

### #13 — Resolve hold-back claims currently live on the site
- **Status:** not started
- **Owner:** Mike
- **Blocker:** Likely needs the same legal review as #11.
- **Next action:** Reconcile what's published against the "holding back until cleared" list — "we don't sell your data" wording, any fabricated testimonial, the draft legal note on the Terms page, and any FAQ marketing a deferred Pro tier as imminent.
- **Context:** Surfaced in a prior audit. Grouped here so it isn't lost; specifics should be confirmed against the live site before editing, and most changes wait on legal.

### #17 — Waitlist endpoint (site v2 funnel completion)
- **Status:** OPEN — the only human step left from the 2026-07-05 site build.
- **Owner:** Mike
- **Next action:** create a form endpoint (Formspree / Buttondown / any POST-able list), paste its URL into `FORM_ENDPOINT` at the top of `01_CORE/site/scripts.js`, flip the download-section variant per the marked `WAITLIST VARIANT` comments (5 pages), link `waitlist.html`, and remove its `noindex`. ~5 minutes.
- **Context:** waitlist.html + compact form variants shipped 2026-07-05 but parked: while `FORM_ENDPOINT` is the placeholder, the page is unlinked/noindexed/out of sitemap and the forms render disabled — no dead form ships. Copy is a bare email field + one neutral sentence per #13; anything more waits on #11/#12 legal review.

## Folder / data housekeeping

### #14 — Point Valuations xlsx disposition
- **Status:** not started — LANE CHANGE 2026-08-01: Mike decides directly (Alex stepped back; no answer to await).
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** Determine from the DB itself whether `CardCoach Point Valuations v1.3 2026-03-14.xlsx` (in `00_COWORK/_TRIAGE/`) feeds anything: `point_valuations` is tiered + evidence-governed since 0038/0034 and the 2026-07-31 master valuation index superseded workbook values — near-certainly archive. Verify no script references the file, then archive.
- **Context:** Surfaced in the 2026-07-02 folder reorg; the only remaining data file whose currency can't be determined from the folder itself.

### #15 — File-for-Alex pack confirmation
- **Status:** not started — LANE CHANGE 2026-08-01: Mike decides directly (Alex stepped back).
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** The `…v1.4_ONEFILE_ALEXTESTED.pdf` acquisition pack (in `00_COWORK/_TRIAGE/File for Alex/`) is a Jan-2026 handoff artifact from a handoff era that's fully archived; archive the folder on Mike's own review.
- **Context:** Jan 2026 handoff artifacts; everything else from the handoff era is archived.

### #19 — Site git wiring / deploy-channel cutover *(renumbered from a duplicate #16, 2026-07-08 — Blue Rewards keeps #16; it's cited by post-09's ledger)*
- **Status:** git wiring DONE (2026-07-05) — pending Mike's G3 domain move.
- **Owner:** Mike (G3 next).
- **Blocker:** None on wiring. Retirement of the old channel waits on the domain move.
- **Next action:** Mike does G3 (point the domain at the `cardcoach-site` Worker serving static assets — push-to-`main` auto-deploy via Cloudflare Workers Builds; not classic Cloudflare Pages). The old direct-upload deploy channel retires **+7 days after the domain move** (grace window; keep it live until then as fallback).
- **2026-07-08 note:** canonical flipped (see PIPELINE_AND_DECISIONS 2026-07-08) — G3's target domain is now **cardcoach.ca**, with card.coach getting the reverse 301 (path + query preserved). Repo-side cutover is done in the worktree, uncommitted; the Cloudflare-side move is unchanged in scope, just pointed at the other domain.
- **Context:** `01_CORE/site/` is now a git working tree pushed to `github.com/mjross05-del/cardcoach-site` (first commit `b0bd3d6`, 56 deployables + `.gitignore`). Deploy is now push-to-`main` → Cloudflare auto-deploy; drag-and-drop retired. Convention logged in LAUNCH_TRACKER + BLOG_OPERATIONS.

### #18 — Email routing on cardcoach.ca (gates the domain-flip push)
- **Status:** **DONE — verified live in the dashboard 2026-08-11.** Cloudflare Email Routing on cardcoach.ca is Enabled (MX route1/2/3.mx.cloudflare.net + SPF live in DNS), rule `hello@cardcoach.ca → mike@card.coach` Active, destination Verified. Was configured ~2026-07-16 (26 days before the check) — this entry had gone stale. Remaining nicety only: a send-as/reply-from for hello@ (optional, separate). hello@ is safe to publish everywhere (deletion page, Play listing contact).
- **Owner:** Mike.
- **Blocker:** None — ~10 min in the Cloudflare dashboard.
- **Next action:** Cloudflare Email Routing on cardcoach.ca: create hello@cardcoach.ca → forward to Mike's inbox (Cloudflare writes the MX records). **Must exist before the domain-flip commit is pushed** — otherwise the live site publishes a dead contact address. Keep hello@card.coach receiving as a legacy forward (it's on the currently-live site; the web 301 does not carry mail). Send-as for replies from the new address = separate, optional, later.
- **Context:** Follows the 2026-07-08 canonical-domain flip (PIPELINE_AND_DECISIONS 2026-07-08 ×2). All 58 site occurrences flipped in the worktree, uncommitted.

### #20 — Web app v1 (free recommendation surface)
*(Recovered 2026-07-16 from the 2026-07-13 session — the original append never landed on
disk.)*
- **Status:** approved 2026-07-13 (D1) — P0 done; P1 dispatch ready, pending keys
- **Owner:** Mike (design + build) · Alex (Annex A answers + URL/anon-key handoff only)
- **Blocker:** Supabase URL + anon key (P1); Annex A contract answers (P3)
- **Next action:** Send the Alex ping (item 0 = keys). On key receipt, run
  `P1_DISPATCH_web_data_spike.md` in Claude Code → output `01_CORE/webapp/DATA_CONTRACT.md`.
- **Context:** Proposal + phase plan: `PROPOSAL_web_app_v1_2026-07-13.md` (both files to be
  re-exported from the 2026-07-13 session or re-materialized — neither landed on disk).
  Decision logged in PIPELINE_AND_DECISIONS 2026-07-13. Web is read/invoke only — Supabase
  writes stay Alex's lane. CTA target (waitlist Worker) live and allowlisted; tag
  `source: "best-card"`.

### #21 — www.cardcoach.ca dead-ends (post-cutover residue)
- **Status:** open, flagged 2026-07-16
- **Owner:** Mike (dashboard — the API token lacks ruleset/pagerule scopes)
- **Problem:** `www.cardcoach.ca` carries a dummy A record and now dead-ends since the
  defensive redirects were removed at cutover.
- **Next action:** Add a www→apex redirect rule in the cardcoach.ca zone via dashboard;
  verify `www` resolves to the apex with path+query preserved.

## #23 — FX fee audit follow-ups (audit + engine fix landed 2026-08-02)

- **What landed 2026-08-02 (Cowork FX audit session):** full audit of `fx_fee_percent` across all 114 `card_products`. No unapplied corrections were found — all 9 prior verification corrections had landed, Scotiabank's 4 zero-FX cards match the issuer footnote's exclusion list exactly, and the USD-billed convention (Mike, 2026-07-29) is applied consistently across all 4 USD cards. **15 unsourced `2.50` values withdrawn to NULL** under rule 7 (12 Amex — 9 consumer + 3 business; 2 MBNA; 1 BMO AIR MILES World). Inside the Amex lineup the criterion is a stated clause, not product segment: Business Gold Rewards and Business Platinum keep 2.50 because their agreements say "a single conversion commission of 2.5%". Snapshot `card_products_snapshot_fx_20260802`; delta `deltas/2026-08-02__card_products__fx_fee_unsourced_to_null.sql`; `verify:cpp` green before and after. Distribution now 81 × 2.50 / 5 × 0.00 / **28 NULL**.
- **Owner:** Mike.
- **OPEN #23a — re-verification queue, 17 cards.** Not nulled because evidence exists and the failure was procedural, not evidentiary: **7 RBC** cards whose workbook rows cite a specific per-card InfoBox PDF (`avion_p.pdf`, `ba_platinum.pdf`, `gold_p.pdf`, `rewards_plus.pdf`, `classic2.pdf`, `westjet_world.pdf`, More Rewards co-app disclosure) that the 2026-07-29 run could not re-fetch because the InfoBox sits inside the application flow and the runbook forbids entering it; and **10 BMO** cards behind a confirmed domain-wide bot wall, covered by the BMO universal "Important information about BMO Credit Cards" PDF. Both need a pass allowed to read captured InfoBox/PDF artifacts. **This is staleness, not absence — do not null these.**
- **OPEN #23b — 11 cards never live-checked for FX.** The 7 CIBC + 3 Desjardins + RBC U.S. Dollar Visa Gold rows inserted by gated Mike-approved writes (2026-07-29 → 08-01). Provenance is in `verify.write_audit`, but they have never been through the verify pipeline, so they carry no `fact_checks` row and are invisible to the freshness view.
- **#23c — API-015: CLOSED 2026-08-02.** Engine is FX-aware (`netValueExactCents` = reward − FX cost; NULL never read as 0 or defaulted to 2.5) **and now wired end to end**. Mike ruled the currency comes from **explicit user selection**, not merchant-country inference. `spendCurrency` (optional ISO 4217) added to all **five** request schemas — the three shared contracts plus the private duplicates inlined in `recommend-card-v2` and `recommend-here-v2`, which don't import the contracts and would have silently stripped it — and threaded into all 4 `scoreWalletForPurchase` call sites including the stateless shadow re-score. Client: new `SpendCurrencyFooter` (8 curated currencies, ephemeral state like `tierOverride`, added to `buildRankingsRequestKey` or the fetch never re-triggers), en/fr keys. Deno 256/256, mobile `tsc` clean, INFRA-004 green. Spec: `mobile_app_codebase/docs/planning/specs/API-015_fx_aware_scoring.md`.
- **OPEN #23f — travel mode (future product feature, flagged by Mike 2026-08-02).** Detect or let the user declare a trip, then default the purchase currency for its duration so the picker becomes a correction rather than a per-purchase chore. Purely a client-side question of *what populates* `spendCurrency` — contract and scoring already support it. Pairs naturally with a pre-trip "cards to bring" view, since that view's ranking input is now the same one.
- **OPEN #23g — API-015 follow-ups.** (i) Mobile shows `fxFeePercent` but not `fxCostCents` or the fee-not-confirmed warning, so selecting USD changes the ranking without showing the cost line that explains it — highest-value next step. (ii) `record-transaction` takes no currency, so a recorded foreign purchase's `valueEarnedCents` is FX-free while the recommendation that preceded it was not; the two will disagree until wired. (iii) `packages/engine-contracts/dist/` is committed build output that goes stale — mobile types resolve through it while jest maps to `src`, so a src-only edit passes tests and breaks Metro. Rebuilt this session; standing trap.
- **NOTE — mobile test suites cannot run in the Cowork Linux sandbox.** All 57 jest suites fail to *start* (0 tests executed): `node_modules` is macOS-installed, so `@babel/runtime` is unreadable across the mount and vitest hits the same wall via `@rollup/rollup-linux-x64-gnu`. Not a code problem, and not fixable from the sandbox without rewriting your `node_modules` from a foreign platform — **run `pnpm test` on the laptop before merging API-015.** Deno suites run fine, which is why the new coverage went there.
- **OPEN #23d — web renders a null annual fee as `$0`.** `apps/web` `cards/[id]/page.tsx:145` and `CardDirectory.tsx:28` both do `formatCad(card.annualFeeCad ?? 0)`, presenting a paid card as free. The repo's own contract forbids this at `productTypes.ts:36`. Unrelated to FX, found alongside it. Small fix, real user-facing wrongness.
- **OPEN #23e — git hygiene, needs Mike.** The API-015 `scoring.ts` edits were made at 11:41 while a concurrent session committed `77a3056` at 11:43 on branch `feat/member-earn-display`; that commit swept them in under an unrelated message ("DATA-019/API-014/APP-018: membership-earn display + attribution notice"). Nothing is pushed, so it is cleanly fixable. Left alone deliberately rather than rewriting another session's history mid-flight. The remaining API-015 files (both `recommendCardV2.ts` copies, the test, the spec) are still uncommitted. This is rule 9(f) multi-session discipline biting in the file lane rather than the DB lane.

## #24 — Android launch lane (AND-001, dispatched 2026-08-07)

- **Status:** engineering lane landed 2026-08-07 (commit `6e17176` in CardCoachv2, + `43eb7eb` deletion page). Spec: `mobile_app_codebase/docs/planning/specs/AND-001_android_launch.md`. Runbook: `mobile_app_codebase/docs/app-store/RELEASE_android_1.x_HANDOFF.md`. Audit: `mobile_app_codebase/docs/dev_notes/AND-001_android_adaptation_audit_2026-08-07.md`.
- **What landed:** INFRA-005 Android build lane (EAS-managed keystore, dev APK green `e69a0c14`; **production AAB green: EAS `45bc2cfa`, 1.0.2 versionCode 4, commit `5f96fb3`** — third attempt, after fixing six corrupt CardVisual placeholder PNGs that AAPT2 rejects and the expo/expo#25188 locales lint tripwire, both release-only failures the dev APK masked); AUTH-006 Google sign-in code + tests (provider config pending, below); APP-019 adaptation audit + fixes (3 blockers: keypad-modal safe area, Android-13+ POST_NOTIFICATIONS never requested, back traps); QA-010 Android preflights + device matrix; REL-001 docs + `cardcoach.ca/delete-account` page.
- **#24a — RESOLVED 2026-08-07:** Play Console account exists — **organization account, mike@card.coach, identity verified** (Mike, confirmed in session). **No closed-testing gate** — the 12-tester × 14-day clock does not apply; production access comes with standard app review. This removes the schedule-critical path from AND-001 §Sequencing; remaining gates are engineering-free: provider config (#24b), site deploy + #18, forms, listing assets.
- **OPEN #24b — Mike, ~15 min, before the first tester build:** Google Cloud OAuth client (Web application; redirect `https://hrzpznlpmxxrbtwskacu.supabase.co/auth/v1/callback`) → id+secret into Supabase Auth → Providers → Google; verify `cardcoach://auth/callback` in the redirect allowlist. Steps in the handoff §Step 1. No rebuild needed after.
- **OPEN #24c — device pass:** Google+Apple+email round-trip, notifications (13+ prompt at Settings toggle, reminder from background), edge-to-edge matrix (Pixel / One UI 3-button / low-end; both locales+themes) — matrix table in the audit doc. Maestro-on-emulator needs a machine with Android tooling (this one has none).
- **Note:** deletion page **LIVE 2026-08-07** (`cardcoach.ca/delete-account`, cardcoach-site `519fe63`, Mike-ordered deploy). **#18 verified DONE 2026-08-11** — hello@cardcoach.ca receives (→ mike@card.coach), so nothing email-side gates Play submission anymore; use hello@cardcoach.ca as the listing contact.

## 2026-08-11 — Pre-launch sweep fixes (run entry)

- Sweep 2026-08-10 findings executed 2026-08-11 (approved dispatch), zero DB writes.
- Site: `.assetsignore` excludes repo internals — `/.git/*`, `/.gitignore`, `/wrangler.jsonc` now 404 (cardcoach-site `e18bd17`); Terms template disclaimer removed from `legal.html` (cardcoach-site `6f3a6d6`). Both deployed via Workers Builds, live-verified.
- Delta governance (CardCoachv2): APPLY_CHECKLIST top stop-note `99b259b` — the 18 card-lane delta files are superseded by live DB state, do not execute; DELTAS_INDEX card-lane statuses reconciled `4c8c8f6` (17 `superseded-live (2026-08-10 sweep)`, Fido closure `not-applied — live state NULL`).
- April-2026 governance snapshots bannered SUPERSEDED (CardCoachv2 `c2744b7` / `e2dd084` / `696b0f5` / `7c95eab` / `9045523`); bodies unedited.
- Alex handoff filed: `ALEX_HANDOFF_2026-08-11.md` (`2308bb4`; renamed `DB_ENGINE_WORKLIST_2026-08-11.md`, worklist run) — dormant-delta drift, Fido NULL, stacking-flag-vs-engine (N4), advisor items, earn-rate pairs, snapshot housekeeping. Engine docs stay unedited until Alex answers N4.
- Stray workers `divine-brook-e823` + `broad-leaf-7294`: workers.dev subdomains disabled, API-confirmed (archive-and-disable; assets-only workers — no script to archive; reversible via re-enable).
- www.card.coach dead-end: no change made — the apex 301 is a card.coach zone Single Redirect rule (catch-all expression, not worker-based), so the fix is dashboard-scoped: add a proxied `www` DNS record on the card.coach zone; the existing rule then covers www. Registrar-side getcardcoach.ca repoint stays on Mike's manual list.
## 2026-08-11 — DB/engine worklist run (run entry)

- Worklist executed per Mike's dispatch (no Alex lane; items are ours). File: `DB_ENGINE_WORKLIST_2026-08-11.md` (renamed from ALEX_HANDOFF this run) — per-item ledger appended there. verify.runs `a261a243-d361-4f53-82d3-9b66f9318ed2`; zero card-fact writes; write freeze formally lifted per dispatch standing-state note.
- Item 1 provenance: card-lane end-states live-confirmed; produced out-of-band from the repo catalog canon (seed.sql) ~2026-07-27–29 — no migrations, no write_audit rows. Full note in DELTAS_INDEX.
- Item 2 Fido: W1 blocked, no write — the card row is absent from live card_products entirely (not a NULL status; absent from the 07-31/08-02 snapshots, no orphans). Decision D-D: insert-as-closed from the delta files, or accept absence.
- Item 3 stacking: engine is flag-gated and wired via the shared scorer; authed v2 endpoints load offers (includeOffers defaults true); stateless-v1 opts out (includeOffers false, no loyalty inputs) so its appliedOffers is [] by design — the sweep probe could never show stacking. Doc-correction gates not met → HOW_THE_ENGINE_WORKS / PIPELINE_AND_DECISIONS untouched; decision D-A: flag posture + where to re-gate the doc fix (authed-path probe).
- Item 4a: trigger-function EXECUTE revoked (migration `harden_trigger_function_execute`); advisor lints cleared; anon RPC probes 404; engine probe unchanged. write_audit `728310dc`.
- Item 4b: 9 definer views reviewed — accepted by design 2026-08-11 (catalog-only read surface; +2 since sweep via the 2026-08-11 verify_apply_loop migrations, concurrent session). Item 4c: leaked-password protection = D-B, dashboard toggle, Mike.
- Item 5 earn-rate groups: no defect — engine picks the single best priced row (never sums); all 15 groups condition-differentiated; NB pairs additionally unreachable (all 3 NB cards load_only). Observation: 'other'-type condition variants can win selection when their condition cannot hold (Amex 3x portal row in-store; MBNA Prime rows) — overstatement class, with Mike; nothing expired.
- Item 6: `point_valuations_snapshot_20260729` attributed via table COMMENT (ad-hoc 2026-07-29 prod copy; secured by 20260729205344); retained, drop stays Mike-only. write_audit `9487dc68`.
- **Decisions resolved (Mike, 2026-08-11):** D-A — flag stays ON; authed-path verification passed (deployed v2 bundles carry the flag-gated path, no opt-out; live traffic confirmed); engine docs corrected, dated (HOW_THE_ENGINE_WORKS ×5, PIPELINE_AND_DECISIONS decision line). D-D — accept absence; both Fido delta files marked not-applicable in DELTAS_INDEX. D-B — approved; dashboard-only toggle with Mike.
- **§2 closure (stacking dispatch, 2026-08-11):** production offer application proven by live probe — recommend-card-v2 applied `b0ff0008` at exactly 1.2 percent (120¢ on $100; final 270 = 100 base + 50 category + 120 offer) for a linked probe user at a Canadian Tire place; pre-link the same offer surfaced as a linkage nudge at 120¢. TestFlight last-mile closed. Probe user retained + marked (probe-20260811@cardcoach.ca). Engine docs' evidence clauses upgraded to the transcript: STACKING_CLOSURE_REPORT_2026-08-11.md.
## 2026-08-11 — Verify batch: unlogged active cards (run 98d0bc59)

- Coverage 33 → 26 unlogged actives (live recount; the sweep's 24 was stale). Logged 7: Desjardins Bonus + Flexi, NB Syncro, RBC Rewards+ / Signature / Visa Preferred (closed-legacy baselines via lineup evidence), TD Business Select Rate. 23 facts: 22 confirmed, 1 changed-gated, 0 unverified, 0 auto-writes.
- Gated pending ×1: Desjardins Bonus $3,600 combined dining+pre-auth annual cap missing from card_caps (proposed SQL in fact_check 59fc3176; approve via RUNBOOK_gated_apply).
- BMO ×11 → chrome-lane queue (walled; list in VERIFY_REPORT_2026-08-11.md). Dedupe-deferred ×15: CIBC 7 + Scotiabank 7 + Amex Business Edge 1 (runs f63bfbd1 / 9a4de2ba <20h; next rotation slots).
- 6b classifications: Flexi, Syncro, TD BSR = base_earn 0 by design, permanently load_only, never re-fetch earn structure.
- 6c: Desjardins 8/8 clean. NB lineup carries mycredit/MC1/Edition/Allure/ECHO/Escapade/Ovation Gold/PB1859 beyond the DB's 4 — deliberate-scope question flagged for Mike, not proposed (precedent: 08-08 run proposed only Syncro).
- Riders: R1 SPEC stacking line corrected (CardCoachv2, local); R2 FK observation appended to worklist ledger.

## 2026-08-12 — Engine window semantics: push + edge deploy (run entry)

Executed on Mike's machine from `dispatches/` prompt `6e60c32` (the Cowork engine session could not reach GitHub or the deploy channel). Local clock 2026-08-12 evening; **DB/UTC had already rolled to 2026-08-13**, which is why the RBC-std rows carry `valid_from = 2026-08-13` and the interim rows `valid_to = 2026-08-12` — expire-then-insert is correct, the rows are live now, not pre-dated.

**Git.** Stale sandbox artifacts swept from both `.git` dirs (renamed `*.stale.N` locks + orphaned `tmp_obj_*`; no bare `*.lock` survived, no git process was running) then `git gc`. Both pushes were clean fast-forwards, no rebase, no force.
- `cardcoach-docs` `be235a3..6e60c32` — 5 commits, one more than the prompt listed: `b070acf` (merchant-graph DML is audit-class) had also never been pushed.
- `CardCoachv2` `cbf25b7..f61ca35` — 15 commits, 12 more than the prompt listed: the whole 08-10/08-11 docs+site backlog had been stranded locally by the sandbox's lack of GitHub reach. 59 files, +2965/−412.

**Deploy.** `recommend-card-v2` 19→**20**, `recommend-here-v2` 19→**20**, `recommend-cards-stateless-v1` 7→**8**. All three ACTIVE, `verify_jwt` still **false** (no `--no-verify-jwt` needed), and all three `ezbr_sha256` bundle digests changed — new code demonstrably shipped. `cap-progress-v1` left at v11 as instructed.

**Probes (stateless-v1, all HTTP 200; effectiveValueCents pre → post).** Every scoreable card's top-line value is **unchanged**, which is the designed outcome, not a failed deploy — see the discriminator note below.

| scenario | pre | post |
|---|---|---|
| RBC std · grocery $100 | 200¢ (2.0/$) | 200¢ (2.0/$) |
| RBC std · grocery $4,000 | 8000¢ (2.0/$) | 8000¢ (2.0/$) |
| RBC std · grocery $10,000 | 16000¢ (1.6/$) | 16000¢ (1.6/$) |
| RBC std · dining $100 *(control)* | 100¢ (1.0/$) | 100¢ (1.0/$) |
| RBC std · dining $10,000 | 10000¢ | 10000¢ |
| RBC std · no context $100 | 100¢ | 100¢ |
| RBC WE · grocery $4,000 | 6000¢ (1.5/$) | 6000¢ (1.5/$) |
| RBC WE · dining $100 | 150¢ (1.5/$) | 150¢ (1.5/$) |
| NBC WE · grocery $4,000 | unrankable `load_only` | unrankable `load_only` |
| rank pair · grocery $4,000 | std #1 8000¢, WE #2 6000¢ | unchanged ordering |

Six of ten responses are byte-identical modulo `requestId`/`computedAt`. The control held exactly.

**ANOMALY 1 — the prompt's discriminator does not exist.** NBC WE grocery $4,000 cannot be priced by any scoring endpoint: **both NBC cards are `scoring_status = 'load_only'`** (`ca_national_bank_rewards_mastercard_world_elite_mastercard`, `..._platinum_mastercard`), so stateless-v1 returns them in `unrankable`, and the authed v2 paths never rank them either. Consequence to be explicit about: **the NBC tier-window remodel is live in the data but dormant in production pricing** — it will start paying only if/when those cards become scoreable. This matches the 2026-08-11 worklist finding that NB cards are load_only; it was simply not carried into the deploy prompt. Nothing to fix here, but the ADDENDUM-2 claim that all four remodelled cards now price their true structure in production is **true only for the two RBC cards**.

**ANOMALY 2 (benign, and the actual proof) — the change is in attribution, not in totals.** With NBC unavailable, the discriminator is `category_excludes` on RBC std grocery, visible in `breakdown`:

| RBC std grocery | pre | post |
|---|---|---|
| $4,000 | baseEarn 1.0/$ = 4000¢ + categoryBonus 4000¢ | baseEarn **0** = **0¢** + categoryBonus **8000¢** |
| $10,000 | baseEarn 1.0/$ = 10000¢ + categoryBonus 6000¢, capAdj −4000¢ | baseEarn **0** = **0¢** + categoryBonus **16000¢**, capAdj **−8000¢** |

The base slot now pays **nothing** on grocery (its rows carry `category_excludes = {grocery}`) and the grocery slot carries the card's whole 2%→1% schedule itself — exactly the §3 target modelling. Totals are identical because A2 keeps the nominal primary at the highest total, so the category bonus absorbs what base used to contribute. This is the new engine running.

Why nothing else moved: on snapshot-less surfaces (stateless-v1 always sends no snapshots) generalized D2 sets the assumed prior to the *start of the highest-rate windowed row's window* — $6,000 for RBC std's base 1% row (rising pair → terminal rate) and $0 for its grocery 2% row (falling pair → headline rate) — which reproduces the old engine's numbers on both slots. RBC WE carries no floors or buckets at all. So every scoreable card converges by construction, and no snapshot-less probe can move a total. The floors bite only on authed, snapshot-bearing paths.

**Other verification.** `health` 200 `{"status":"healthy"}`, database check pass. Engine suite **143/143**. Goldens `verify:qa-005` **8/8**. Edge logs for all three functions across the full 24h window: `info`/`log` only — **no error or warn class** before or after. Caveat: `recommend-card-v2` and `recommend-here-v2` have had **zero invocations since the deploy** (authenticated endpoints, no live traffic in the window), so they are shipped and healthy-by-artifact but not yet exercised by real traffic.

**ANOMALY 3 — CLI/keychain, for the next session.** `npx supabase` installed a fresh **2.114.0** at a new npx cache path; the macOS Keychain item "Supabase CLI" (created 2026-07-29) does not grant that binary, so `npx supabase …` hangs indefinitely on an invisible authorization prompt with stdin closed. Fix used: invoke the already-authorized **2.110.0** binary directly at `~/.npm/_npx/7960735060baecd3/node_modules/@supabase/cli-darwin-x64/bin/supabase` — same CLI, deploys identically. Alternative is to export `SUPABASE_ACCESS_TOKEN`. Do not assume `npx supabase` works unattended on this machine.

**Not done / untouched:** no source files modified, no data SQL run (reads only, to diagnose the discriminator), no `db push`, `public.*` and `verify.*` untouched, apply queue still empty.
---

*Add new open items above this line. Close = delete. Settled = move to the decisions log.*

---

## #22 — Loyalty stacking Phase 1: activation gates (landed dark 2026-08-01)

- **Status (updated 2026-08-01 evening):** branch `feat/loyalty-offers-phase1` at `cbf2739`. **Gate 1 CLOSED** — WS-1 executed same-day; all 7 editorial offers now issuer_confirmed 0.95–0.97 (see `dispatches/REPORT_WS1_results_2026-08-01.md`; RBC↔Triangle corrected to CT-retail-only, Moi CPP 0.8¢/pt captured, excluded-co-brand scope added). **Gate 2 code-complete** — APP-017 landed via concurrent runtime (`cbf2739`), needs local suite re-run + a shipped build. Mike's first `db reset` failure (FK ordering, migrations-before-seed-data) fixed in `89facba`. Flag still **false**; rule 5 still holds.
- **Owner:** Mike — all of it (LANE CHANGE 2026-08-01: Alex stepped back for the time being; build + release are Mike's, in progress).
- **Gate 3 — founder flag flip** + rule 5 update, after the APP-017 TestFlight build is on the circle's devices. Mike's ruling 2026-08-01: audience is TestFlight-only, his circle — adoption is a non-issue; flip when the circle has updated. The adoption bar becomes real at GA (and the COMPLIANCE pack's counsel gate applies before QC GA).
- **Before merge:** re-run `pnpm supabase:db-reset` (now expected green) + `pnpm verify:loyalty-p1` + `pnpm test` + `pnpm test:supabase`; then full `pnpm verify`.
- **WS-5 freshness: WIRED 2026-08-01** into the daily scheduled verify batches (wed-rbc, fri-cibc, sun-ct-pcf, mon-scotiabank + chrome lane) — parking-lane only, OFFERS_PROMOTION OFF preserved, sections no-op until the branch merges; fuel-price check first Wednesday monthly; see `dispatches/DISPATCH_WS5_offer_freshness_ops_2026-08-01.md` (now the record of what was wired). Journie 30-vs-60-day conflict + Sunoco/2030 sunset + Scene+/Shell + Blue Rewards watches all live in those prompts.
- **QA-009: DONE 2026-08-01** — 30-scenario golden pack built + independently verified on branch `feat/qa-009-golden-pack` (commit `12f47fe`; suite 199/199; merge via the merge dispatch, step 6).
- **WS-7: DRAFTED 2026-08-01** — `COMPLIANCE_loyalty_stacking_pack_2026-08-01.md` (string review, trademark attribution EN/FR, Quebec/Law 25 checklist). NEEDS COUNSEL SIGN-OFF before flag flip; one APP-017 follow-up: in-app attribution notice screen.
- **Merge/push/cloud-apply prompt ready:** `dispatches/DISPATCH_MERGE_AND_CLOUD_APPLY_2026-08-01.md` — paste into Claude Code on the laptop.
