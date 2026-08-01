# APPLY REPORT — master valuation index → point_valuations

**Session:** night apply, 2026-07-31 ~22:56–23:50 ET · **Project:** `hrzpznlpmxxrbtwskacu` (card_coach_advanced)
**Authority:** `cardcoach_master_valuation_index_2026-07-31_v1.xlsx` (approved, amendments 1–4 baked in) executed per `cardcoach-docs/PROMPT_apply_valuation_index_2026-07-31.md`
**WRITE_DATE:** pinned `DATE '2026-07-31'` (Eastern) in every statement. UTC had already rolled to 2026-08-01 at session start — the §7 trap was live all night; post-write check confirms **zero rows stamped past 2026-07-31**.

---

## Applied — 8 rows across 6 programs

| Program / tier | Old → New | Method | Basis |
|---|---|---|---|
| avios conservative | 1.2000 → **1.5000** | expire-then-insert | Band floor as practical floor (no issuer CAD floor); 5 CAD sources on file, copied to the successor row. Supersedes session-4's same-day HELD-at-1.20 ruling per the approved index |
| avios realistic | 1.5000 → **1.9000** | **same-day in-place UPDATE** (§7; row was written earlier today by session 4) | v3 median of 5 {1.50, 1.70, 1.90, 2.00, 2.00} |
| aeroplan realistic | 1.2700 → **2.0000** | expire-then-insert (+ constraint drop/re-add, see notes) | v3 median{NerdWallet CA 1.60, PoT 2.00, Milesopedia 2.00} — all three read on the publishers' pages this session (§2b); 3 evidence rows attached. Cures the 1.27-below-band §8 defect |
| amex-mr realistic | 1.7000 → **2.0000** | expire-then-insert | v3 median{Milesopedia 1.70, Frugal Flyer 2.00, PoT 2.20}; FF read on-page this session; MMB demoted (below); 3 evidence rows attached |
| rbc-avion realistic | 1.0000 → **2.0000** | expire-then-insert | Air Travel Redemption Schedule floor (four long-haul bands price at exactly 2.00), **dual-confirmed on two issuer PDFs**; band-optimal-fares caveat recorded (amendment 3) |
| rbc-avion aggressive | 2.3000 → **2.3333** | expire-then-insert | Schedule max, $350/15,000 exact |
| td-rewards conservative | 0.4000 → **0.2500** | expire-then-insert | Verify-to-page: T&C PDF §3.3 "minimum value of 400 TD Rewards Points per $1" — exact page rate (research 0.25 happened to match). "Limited-time promotional offers" caveat recorded |
| national-bank conservative | 0.8300 → **0.4000** | expire-then-insert | Verify-to-page: À la carte Rewards Plan Schedule A, repayment $100 = 25,000 pts (uniform 0.40 at all five tiers). Also cures the unrecorded-basis defect on the old 0.83 |

Side effects applied in the amex transaction (per spec): **Mega Miles Broker demoted to directional** on the two active carrier rows — `observed_value` nulled (the band trigger counts `count(observed_value)`, so the row stays attached as a note without banding) + §2a demotion note; **FF 2.00 attached in its place** on both rows so their counts recompute to 3, bands unchanged at 1.70–2.20. The expired realistic keeps its original MMB row (history frozen at expiry).

Post-commit rider (same session): **CPP-16 SIGNED-OFF tokens** added by in-place notes UPDATE to the aeroplan and amex realistic rows (realistic change on ≥5-scoreable-card programs requires the token; the approval is the approved index itself). Recorded in both delta files.

## Verified no-writes — 2 programs (verify-to-page, page showed no lower channel)

- **bmo-rewards conservative stays 0.5000.** The issuer T&C (bmo.com popups terms page, read in-browser this session) states travel 150 pts/$1 (0.667) and "for all other non-travel purchases… 200 points per $1 value" (0.50). No 300 pts/$1 channel exists on the page; the research 0.33 does not verify.
- **scene-plus conservative stays 1.0000, class stays `fixed`.** The program's own help page (help.sceneplus.ca, read in-browser) states every numeric rate at 1.0 (1,000 = $10 groceries/pharmacy/Home Hardware; 500 = $5 dining; 100 = $1 Cineplex/Scene+ Travel); "Points for Credit" is listed with **no** stated rate. Scotiabank welcome-kit page agrees. The flagged ~0.70 statement-credit channel does not verify → no re-anchor, no fixed→bank reclass.

## Deferred — fail closed, no writes

| Item | Reason |
|---|---|
| aeroplan conservative 1.20 → 1.00 | The ~1.0 portal/gift-card **issuer** artifact did not verify on-page: aircanada.com eStore page timed out; only stale third-party artifacts (2021 LCBO PR) locatable. Rule: keep 1.2000 |
| aeroplan aggressive 2.00 → 3.00 | Worked-redemption evidence pack (live partner-chart prices + dated cash-fare snapshots for ≥2 named examples: ANA YVR/SEA–Tokyo J 55k, NA–EU J 60–75k) not capturable this session. No estimates — deferred |
| amex-mr aggressive 2.20 → 3.00 | Same pack via 1:1 Aeroplan transfer. Deferred with it. (Would have been a same-day in-place UPDATE — the row is dated 2026-07-31) |

## Drifted / skipped — 1 program

**marriott-bonvoy-points.** Workbook current says 0.70 / 0.70 / 0.90; live at preflight was **0.70 / 0.86 / 1.00** — another session applied Mike's morning ruling under **spread rule v2** (lowest-consensus), committing at **22:58 ET, one minute before this session's preflight read** (delta: CardCoachv2 `2026-07-31__marriott__spread-rule-v2-four-cad-sources.sql`, still untracked in git). Skipped per the drift rule.
**Needs Mike:** the same day produced a v2 marriott ruling and a v3 index. Under v3, the median of the *live* band {Finly 0.86, TPC 0.90, Milesopedia 0.90, FF 1.00} = **0.90** — reconciling marriott to v3 would move realistic 0.86 → 0.90. Recorded as a conflict entry in PIPELINE_AND_DECISIONS.md; no write made.
**→ RESOLVED 2026-08-01: Mike ruled; reconciliation applied. See the addendum at the bottom of this report.**

## Snapshots (rule 1)

`point_valuations_snapshot_20260731` (108 rows) and `point_valuation_sources_snapshot_20260731` (94 rows) — taken before the first write, RLS enabled, `REVOKE ALL` from anon/authenticated/PUBLIC (the 07-29 unattributed-snapshot failure mode addressed), `COMMENT ON TABLE` names purpose, session, and the prompt as origin.
Note: the snapshot counts (108/94) exceed this session's first preflight read (106/82) — the delta is exactly the concurrent marriott commit (2 valuation rows + 12 evidence rows). The snapshot is internally consistent with live at snapshot time.

## Delta files (CardCoachv2, `card_coach_business_docs/01_CORE/data/deltas/2026-07-31/`)

- `2026-07-31__avios-points__cpp.sql`
- `2026-07-31__aeroplan-points__cpp.sql` (incl. CPP-16 rider)
- `2026-07-31__amex-mr-points__cpp.sql` (incl. CPP-16 rider)
- `2026-07-31__rbc-avion-points__cpp.sql`
- `2026-07-31__td-rewards-points__cpp.sql`
- `2026-07-31__national-bank-points__cpp.sql`

Each: BEGIN/COMMIT, guarded pre/expire/attach/post assertions (rowcount ≠ expected raises and aborts), full as-applied SQL, header naming the workbook + prompt, rollback instructions, as-applied new-row IDs. Files were cut immediately after each COMMIT. `DELTAS_INDEX.md` was **not** amended — it is a frozen 2026-07-04 snapshot of the card-delta corpus and has never tracked CPP-lane files (07-29/07-31 files absent by convention).

## Verification output

Compliance sweep over active rows (all touched + no-write programs), post-write:

| Check | Result |
|---|---|
| Active tier2 rows with < 3 sources | **2** — aeroplan conservative + aggressive, the pre-existing gate leftovers (deferred above); was 3 before tonight, realistic is cured. Constraint remains honestly NOT VALID |
| Value above own `observed_high` | 0 |
| Non-conservative value below own `observed_low` | 0 |
| tier2 carrying `high` confidence | 0 |
| tier2 with NULL `sources_verified_at` / NULL `source_count` | 0 / 0 |
| Evidence-bearing rows where `source_count` ≠ trigger-counted values | 0 |
| Rows stamped with a future `valid_from` (UTC trap) | **0** |

`pnpm verify:cpp:cloud` (mobile_app_codebase): **suite passed** — 17 checks, after the CPP-16 rider. Remaining WARNs, both pre-existing:
- **CPP-17** (9 tier1/1b `high` rows without evidence — bmo realistic/aggressive, westjet ×3, etc.): the evidence-attach campaign is mid-flight in another lane; not touched.
- **CPP-14** seed drift: `seed.sql` has 108 pv rows vs live 115 (this session's +7). **Deliberately not regenerated** — `mobile_app_codebase/supabase/seed.sql` carries uncommitted modifications from a concurrent runtime; regenerating would clobber them. Chore: resync seed after the other runtime's work lands.

## Docs

- PIPELINE_AND_DECISIONS.md (cardcoach-docs): ten DecisionLog entries appended under the marker, each with a **Landed:** annotation reflecting what actually happened (including the marriott NOT-APPLIED conflict entry). Existing entries untouched.
- This report: `cardcoach-docs/APPLY_REPORT_valuation_index_2026-07-31.md`.

## Material impacts (default-tier scoring — will re-rank against cashback)

| Program | Realistic move | Scoreable cards |
|---|---|---|
| Aeroplan | 1.27 → 2.00 (**+57.5%**) | 10 |
| RBC Avion Elite | 1.00 → 2.00 (**+100%**) | 3 |
| Amex MR | 1.70 → 2.00 (**+17.6%**) | 6 |
| Avios | 1.50 → 1.90 (**+26.7%**) | 1 |
| Marriott | *not applied* (live 0.86 via v2; v3 would say 0.90) | 2 |

Conservative-tier moves (display only): avios 1.20→1.50, td 0.40→0.25, nbc 0.83→0.40 (0 scoreable).

## Needs Mike's decision

1. **Marriott v2/v3 reconciliation** (above) — realistic 0.86 vs v3-median 0.90.
2. **Chart-derived confidence classification** — §5 strictly reads `medium-low`; the 07-31 Aventura precedent used `high`; the two new rbc-avion rows carry `medium-high` per the apply prompt with the flag in `review_notes`. Settle and (if desired) restate.
   **→ RESOLVED 2026-08-01 ~09:55 ET: Mike ruled — dual-confirmed chart-derived rates classify as `medium-high`. Avion rows unchanged (already MH), flags resolved on-row; §5 annotated. New residue: Aventura aggressive 2.2857 still carries `high` under the old reading — retrofit needs an explicit call (it was on the no-writes list).**
   **→ Retrofit RULED and APPLIED 2026-08-01 ~10:05 ET: aventura aggressive `high` → `medium-high` (value 2.2857 unchanged; delta `2026-08-01__cibc-aventura-points__cpp.sql`). No chart-derived row carries `high`. Items 2 and its residue fully closed — remaining from this report: items 3 (TD promo-caveat floor) and 4 (BMO 0.6667 cosmetic).**
3. **TD floor fragility** — the 0.25 "Minimum Value" sits in a section TD labels "limited-time promotional offers [we] can cancel or change at any time" (caveat on the row). If that reads too soft for a floor, the alternative is reverting to Expedia 0.50 as conservative.
   **→ RESOLVED 2026-08-01 ~11:25 ET: Mike ruled — 0.2500 stands; the on-row caveat is the accepted defensibility record (Expedia-0.50 revert declined). Ruling recorded on the row and as a rider on the TD delta; channel withdrawal/repricing is covered by the event-driven refresh triggers. With this, EVERY item in this report is closed: all writes landed, all deferred values subsequently ruled and applied, all decision items settled. Final board: `pnpm verify:cpp:cloud` 17/17, zero warnings.**
4. **BMO cosmetic precision** (observed in passing, out of tonight's scope): stored realistic/aggressive 0.6700 vs the page's exact 150 pts/$1 = 0.6667 — same class of fix as Avion 2.30→2.3333 if wanted.
   **→ RESOLVED 2026-08-01 ~11:08–11:15 ET: Mike ruled; the parallel lane landed the value fix first (`2026-08-01__blue-bmo__exact-ratio-0p6667.sql`, both rows → 0.6667) — the apply session's duplicate transaction aborted on its pre-guard, a clean near-collision. The apply session then attached a second issuer artifact (Ascend WE Business T&C, identical 150/$1 language) to both new rows, making their `high` fully §5-compliant (numeric + dual-confirmed; rider file `2026-08-01__bmo-rewards-points__cpp-dual-confirmation-rider.sql`). Only item 3 (TD promo-caveat floor) remains open from this report.**
5. **Structural follow-up** (re-flagged): `pv_tier2_needs_three_sources` still needs the active-row-scoped rewrite proposed in the marriott delta header — tonight's aeroplan transaction needed the drop/re-add dance again.
6. **Seed resync** (CPP-14) once the concurrent runtime's `seed.sql` changes land.

## Session notes

- Concurrent-runtime activity was live all night: marriott committed mid-preflight (22:58 ET); CPP-17 evidence batches landed 22:37–22:39 ET. Every transaction here carried pre-guards asserting expected ids/values/dates, so a collision would have aborted the write rather than clobbering — none fired.
- Frugal Flyer's MR figure moved articles: the index's cited URL (frequent-flyer-miles) now carries transfer ratios only; the 2.00 CAD figure was read in the bank-loyalty-program article. Value and median unchanged; divergence recorded on the row and in the delta.
- Milesopedia's /en/ points-value page showed header "Updated: January 1, 2026" on tonight's read while prior sessions recorded a 2026-06-01 edition; figure (Aeroplan 2¢) unambiguous. Noted on the evidence row.
- RBC benefits-guide PDFs carry a 2019 internal creation date while being the currently-served issuer artifacts; noted on the rows; 2026 third-party guides describe the same schedule.

---

## Addendum — 2026-08-01: marriott v3 reconciliation applied (decision item 1 resolved)

Mike ruled on this report 2026-08-01 morning: *"apply the marriott v3 reconciliation — realistic 0.86 → 0.90."* Applied at ~08:25 ET:

- **marriott realistic 0.8600 → 0.9000**, the v3 median of the live band {Finly 0.86, TPC 0.90, Milesopedia 0.90, FF 1.00} — the band was re-guarded as exactly those four values at write time before the transaction proceeded. Conservative 0.7000 and aggressive 1.0000 untouched.
- **Method: standard expire-then-insert with `WRITE_DATE = DATE '2026-08-01'`** — by ruling time it was a new Eastern day, so the same-day exception no longer applied to yesterday's 0.86 row; it closes with an honest one-day validity window (2026-07-31 → 2026-08-01). Evidence carried to the new row with its original 2026-07-31 on-page access dates; `sources_verified_at` honestly kept at 2026-07-31 (no fresh read claimed; variable SLA 90d).
- **Fresh snapshot pair** `point_valuations_snapshot_20260801` + `point_valuation_sources_snapshot_20260801` (115/115 rows — confirming zero overnight writes since last night's end state) taken before the write, RLS + REVOKE + attributed comments.
- **Delta:** `card_coach_business_docs/01_CORE/data/deltas/2026-08-01/2026-08-01__marriott-bonvoy-points__cpp.sql` (new dated run folder). Pipeline doc updated with the resolution entry.
- **Verification:** `pnpm verify:cpp:cloud` re-run — suite passes; unchanged pre-existing WARNs (CPP-17 evidence campaign; CPP-14 seed drift, now 108 vs 116).
- **Residue for Mike:** confidence on the new row left at the v2 pass's `medium`; the index proposed `medium-high` for marriott realistic under v3. One-line change if wanted (and the index also proposed MH for marriott aggressive). Decision item 2 (chart-derived confidence classification) also still open.
  **→ RESOLVED 2026-08-01 ~08:30 ET: Mike ruled; realistic + aggressive bumped to `medium-high` in place (rider on the 2026-08-01 marriott delta). Marriott now matches the index grid M/MH/MH exactly.**

**Post-report movements (parallel session, 2026-08-01 morning, logged in PIPELINE_AND_DECISIONS.md):** `pv_tier2_needs_three_sources` rescoped to active rows and **VALIDATED** (migrations `20260801082400`/`20260801090500`) — decision item 5 resolved; **aeroplan aggressive 2.00 → 3.0000 landed** on a worked-redemption pack with dated 2026-08-01 fare snapshots — one of this report's two deferred aggressives is closed, and aeroplan conservative keeps 1.2000 with the consensus evidence now attached. Still open from this report: **amex-mr aggressive 2.20 → 3.00** (1:1-transfer inheritance of the aeroplan pack), decision item 2 (chart-derived confidence), items 3/4/6.

**→ 2026-08-01 ~09:45 ET: amex-mr aggressive 2.2000 → 3.0000 APPLIED on Mike's ruling** via the aeroplan pack (worked rows copied with the 1:1 transfer named per example; band 1.70–6.48; confidence medium-high → medium per the worked cap; delta `2026-08-01/2026-08-01__amex-mr-points__cpp.sql`). Item 6 (seed resync) also confirmed done by the parallel session (CPP-14 clean). **The master valuation index is now fully landed — every index row is at its final state.** Remaining open items from this report: decision items 2 (chart-derived confidence, RBC Avion rows), 3 (TD promo-caveat floor), 4 (BMO 0.6667 cosmetic).

Marriott realistic temporal chain: 0.90 (03-14) → 0.70 (07-29) → 0.86 (07-31) → **0.90 (08-01)**. Impact: +4.7% vs v2's 0.86, net +28.6% vs the 07-29 baseline, across 2 scoreable cards.
