# CardCoach Working Notes

**The only file that churns.** What's unresolved, who owns it, what unblocks it, what's
next. Update freely. When an item closes, **delete it** — closed items don't belong here.
Settled decisions move to `PIPELINE_AND_DECISIONS.md`; they don't live here.

Last updated: 2026-08-01 · Owner: Mike  (header date corrected 2026-07-04, housekeeping sweep 2 — was 2026-07-03, contradicting the 2026-07-04 dated updates within; prior correction 2026-07-03 — was 2026-06-02)

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
- **#22** Loyalty stacking Phase 1 (DATA-018/PKG-010/API-013) — LANDED DARK 2026-08-01 on `feat/loyalty-offers-phase1`; three activation gates open (see section below). Also gives #10 a pump-case resolution via cents_per_litre offers (earn_rates enum for card-catalog per-litre representation still Alex's).

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
- **Next action:** Mike does G3 (point the domain at the new Cloudflare Pages project fed by `cardcoach-site`). The old direct-upload Pages project retires **+7 days after the domain move** (grace window; keep it live until then as fallback).
- **2026-07-08 note:** canonical flipped (see PIPELINE_AND_DECISIONS 2026-07-08) — G3's target domain is now **cardcoach.ca**, with card.coach getting the reverse 301 (path + query preserved). Repo-side cutover is done in the worktree, uncommitted; the Cloudflare-side move is unchanged in scope, just pointed at the other domain.
- **Context:** `01_CORE/site/` is now a git working tree pushed to `github.com/mjross05-del/cardcoach-site` (first commit `b0bd3d6`, 56 deployables + `.gitignore`). Deploy is now push-to-`main` → Cloudflare auto-deploy; drag-and-drop retired. Convention logged in LAUNCH_TRACKER + BLOG_OPERATIONS.

### #18 — Email routing on cardcoach.ca (gates the domain-flip push)
- **Status:** not started — repo already publishes hello@cardcoach.ca (swap executed 2026-07-08, Mike-approved).
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
