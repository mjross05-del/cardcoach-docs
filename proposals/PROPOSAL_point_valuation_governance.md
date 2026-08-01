# PROPOSAL — Point valuation (CPP) governance

**Status:** PROPOSED 2026-07-29 · Last updated: 2026-07-31 · Owner: Mike · Supersedes: nothing (first written rule for this table)
**Decisions captured:** tier spread rule (Mike, 2026-07-29); drop `aggressive` where no issuer
ceiling is published (Mike, 2026-07-29); `point_valuations` moved to Mike's lane with direct-write
authorisation (Mike, 2026-07-29 — see PROJECT_RULES.md rule 9 exception).

---

## 1. Why this exists

Three structural problems, all confirmed against the live table on 2026-07-29:

1. **No spread rule existed.** Migration `0038_valuation_tiers` introduced
   `conservative` / `realistic` / `aggressive` in March 2026. Nothing in either repo ever defined
   what the three tiers mean, so values were set case by case. The result is that the tier
   distinction is meaningless for roughly two thirds of programs and internally contradictory for
   the rest.

2. **Aggregator-sourced values reached production.** SOURCE_OF_TRUTH.md:123 and
   PIPELINE_AND_DECISIONS.md:78 both state that blogs and aggregators are review triggers, never
   truth. Despite that, `source_notes` on `aeroplan-points`, `airmiles-points`,
   `marriott-bonvoy-points`, `rbc-avion-points` and `amex-mr-points` (aggressive) cite
   FrequentMiler, PointsPath, NerdWallet, Ratehub, Milesopedia, Prince of Travel, TPG and
   ThePointCalculator.ca as the **basis of the value**, not as review triggers.

3. **The table is mid-migration between two methodologies.** The 2026-07-27 batch-1 re-anchoring
   moved `amex-mr-points`, `td-rewards-points` and `cibc-aventura-points` to issuer floors, but
   only on the `conservative` and `realistic` rows. The `aggressive` rows were left untouched and
   still carry `source_notes` describing the superseded scheme — `amex-mr-points` aggressive reads
   "Realistic 2.00" while the realistic row reads 1.00. Batch 2 (`aeroplan`, `scene-plus`,
   `rbc-avion`, `bmo-rewards`) was queued and never run.

A fourth, known issue this document closes: **the devaluation blind spot.** Program CPP changes do
not surface through the monthly Stage-2 reverification loop, because Stage 2 fetches card product
pages, not loyalty-program redemption terms. A program can devalue without any card fact changing.

---

## 2. Sourcing rule

Three source tiers, in strict precedence. **Tier 2 is new as of 2026-07-29 and applies to this
table only** — it is not a change to the sourcing rule for any other card fact.

**Tier 1** — cardholder agreement, disclosure PDF, program terms.
**Tier 1b** — issuer or program product page.

**Tier 2 — triangulated industry consensus.** Permitted only where the program publishes no
cents-per-point value at all for the redemption path being valued. Dynamic award travel is the
whole of this category: Air Canada, British Airways and Marriott do not publish a cash-equivalent
per point, so a Tier 1/1b value does not exist to be found. The rationale (Mike, 2026-07-29): where
competitors and industry experts align, differing from that view without a verifiable reason is
itself a defensibility risk.

All six conditions bind. Failing any one means the row is **not** compliant:

1. No issuer-published value exists for that redemption path.
2. Three or more **independent** recognised sources agree within a stated tolerance.
3. The stored value falls **inside** the observed range — never above its own ceiling.
4. `confidence` capped at `medium-high`. Tier 2 can never be `high`.
5. Every source named, with its access date, in `source_notes`.
6. Any deliberate divergence from consensus documented with its verifiable reason.

Tier 2 never overrides an available Tier 1/1b value. Where an issuer publishes a floor and
consensus describes a typical redemption, the floor governs the `conservative` row and consensus
may govern `realistic` — the issuer value is not displaced.

**What has not changed:** aggregators remain review triggers for every fact outside
`point_valuations`. Citing one to justify an earn rate, cap, fee or exclusion is still forbidden.
A single blog post is not consensus. Two sources are not consensus.

### 2a. Programme valuations vs channel rates (added 2026-07-29)

The consensus band is built from **programme valuations** — a source's published answer to "what is
one point worth". It must **exclude channel rates**: statement-credit rates, cash-out rates, broker
buy/sell prices, and point-purchase costs.

The distinction is not academic. Amex MR has a Milesopedia programme valuation of 1.70, a Prince of
Travel statement-credit rate of 1.50, a Mega Miles Broker cash range of 1.10–1.55, and a purchase
cost above 2.00. Treating all of those as one band would put the consensus low at 1.10 — which
collapses `realistic` onto the 1.00 issuer floor and destroys the tier's information. The same trap
appears with Avios, where the Canadian *purchase* price (2.2–3.0¢) exceeds every *redemption*
valuation (1.20–2.00). A buy price is not a value.

Channel rates still matter — they are the natural source for the `conservative` floor and for `bank`
programmes, where the tiers are explicitly channel-based. They just do not belong in a consensus
band.

**Currency discipline:** `cents_per_point` is CAD. Do not convert GBP-pence or USD figures into the
band; FX drift makes them non-reproducible. Avios is quoted in pence by most sources, so only the
CAD-denominated figures were used.

### 2b. A search summary is not a source (added 2026-07-31)

Every source recorded in `point_valuation_sources` must be **read on the publisher's own page**.
A search-engine summary characterising what a publisher says is not that publisher's figure, and
recording it as one puts an unverifiable number behind a constraint that looks satisfied.

Two rows written on 2026-07-29 failed this and neither attribution reproduced when checked:

| Recorded | Actual, on the publisher's page (2026-07-31) |
|---|---|
| `amex-mr` — "Prince of Travel ~2.00" | Prince of Travel publishes **2.2¢ CAD** for MR |
| `avios` — "ThePointCalculator / Award Travel Finder 1.20" | ThePointCalculator's CAD page says **1.5–1.7**, no 1.20 anywhere. Award Travel Finder publishes only GBP pence and USD — unusable under the currency rule above |

Both were taken from search-result summaries rather than the publishers' pages. The failure mode
is quiet: the band looked plausible, the source count was right, and the constraint would have
passed. In the Avios case the error was load-bearing — the stored `realistic` 1.20 was *below* the
real consensus floor, which only surfaced when someone tried to attach the actual evidence.

**Practical rule:** the URL in `source_urls` must be the page the figure was read from. If you
cannot open it and see the number, you do not have the source.

- Dual confirmation applies, per RUNBOOK_verify_batch.md §52: two independent artifacts agree, or
  two independently prompted extraction passes agree. Disagreement fails closed.
- No value is estimated. Unknowns are flagged `[VERIFY: issuer-verified data needed]` and the row
  is left absent rather than filled — per PROJECT_RULES.md rule 7. Tier 2 does not relax this: a
  value that cannot clear all six conditions is absent, not guessed.

---

## 3. Complexity tiers

`complexity_tier` classifies how a program's redemption value is determined. It drives the spread
rule in §4.

| Value | Meaning | Programs (2026-07-29) |
|---|---|---|
| `fixed` | One published rate, no channel variation | amazon-rewards, blue_rewards, moi, more-rewards, pc-optimum, scene-plus, westjet-dollars |
| `bank` | Multiple issuer-published redemption channels at different rates | bmo-rewards, cibc-aventura, mbna-rewards, national-bank, td-rewards |
| `variable` | Value depends on dynamic award pricing the issuer does not publish | aeroplan, airmiles, amex-mr, avios, marriott-bonvoy, rbc-avion |
| `legacy` | Program retired or cards excluded from scoring; values frozen | hsbc-rewards |

`desjardins-odyssey-points` and `triangle-points` are unclassified (`complexity_tier IS NULL`) and
unsourced. Both are addressed in §7.

---

## 4. The spread rule

| complexity_tier | `conservative` | `realistic` | `aggressive` |
|---|---|---|---|
| `fixed` | Issuer published rate | Same | Same |
| `bank` | Lowest issuer-published channel | Issuer's primary published channel | Highest issuer-published channel; omit if only one exists |
| `variable` | **Floor** — issuer-stated where published, else the documented practical floor | **LOWEST consensus** figure across all sources | **HIGHEST consensus** figure across all sources |
| `legacy` | Frozen at last verified | Frozen | Frozen |

**Spread rule v2 for `variable` programs (Mike, 2026-07-29).** Superseded v1, which set realistic to
the *typical* consensus value. Under v2 the three tiers are:

- `conservative` = the **floor** — what the points are guaranteed to be worth. Issuer-stated where
  one exists (Amex statement credit 1.00), otherwise the documented practical floor.
- `realistic` = the **lowest** published valuation among the source set. The default scoring tier
  therefore reports the most pessimistic expert view, not the median. This is deliberate: it means
  CardCoach never overstates a points card's return on the tier most users see.
- `aggressive` = the **highest** published valuation. Still bound by condition 3 — the stored value
  is the observed ceiling, never above it.

The consequence worth understanding: v2 **decouples the floor from the lowest expert view.** Under
v1 those collapsed together for Amex MR (both 1.00). Under v2 conservative holds the 1.00 issuer
floor while realistic carries the 1.70 consensus low, so all three tiers carry distinct information.

**Tier collapse is legitimate and expected** for `fixed` programs and for `bank` programs with a
single channel. Identical values across tiers are a correct representation of a program that
genuinely has one rate — not a defect.

**`variable` programs keep all three tiers** (decision reversed, Mike, 2026-07-29 — see §10). An
earlier version of this rule dropped the `aggressive` row for these programs on the grounds that
its basis was aggregator-derived. Tier 2 removes that objection: the same evidence that supports a
consensus `realistic` value supports a consensus ceiling, and treating the two differently is
inconsistent. The discipline moves from *excluding* the row to *testing* it against §2's six
conditions. **Condition (3) does real work here** — a ceiling above its own cited range is a defect,
and re-auditing under this rule caught one that the exclusion approach would have masked
(`amex-mr-points` aggressive, §8).

**Engine behaviour on a missing row.** `loadTierValuations` in
`supabase/functions/_shared/scoring.ts` falls back to the `realistic` row when the requested tier
is absent, and emits a warning naming the program. This is now the fallback path for a row awaiting
verification rather than a designed outcome — the target state is a complete grid for every program
with cards attached.

---

## 5. Confidence

`confidence` is a CHECK-constrained enum: `low`, `medium-low`, `medium`, `medium-high`, `high`.
Note that `issuer_stated` is **not** a legal value — it was requested for the blue_rewards row on
2026-07-03 and filed as `high` with the basis recorded in `source_notes`
(`01_CORE/data/deltas/APPLY_CHECKLIST.md` §3.1).

| Level | Criterion |
|---|---|
| `high` | Tier 1 source, dual-confirmed, rate stated numerically by the issuer. **Tier 1/1b only** |
| `medium-high` | Tier 1b source dual-confirmed, **or** Tier 2 clearing all six conditions of §2. This is the Tier 2 ceiling |
| `medium` | Single Tier 1/1b artifact, not yet dual-confirmed |
| `medium-low` | Issuer source located but rate inferred from a redemption chart rather than stated |
| `low` | Legacy or excluded program; value retained for completeness only |

A Tier 2 row carrying `high` is non-compliant on its face. Four rows currently do: all three
`aeroplan-points` rows and `amex-mr-points` aggressive. Each must be capped at `medium-high` or
re-sourced to Tier 1/1b — see §8.

---

## 6. Devaluation detection

This closes the blind spot. Stage 2 fetches card product pages; program redemption terms are a
separate source class and need their own cadence.

- Add a `redemption_terms` source type to the registry — approved as decision D3,
  **implemented 2026-07-31** (`PROPOSAL_d3_redemption_terms_registry.md`): 19 programme rows
  keyed by `point_program_id`, baselines fetched, changed sources emit `verify.parking` review
  items (topic `cpp_terms_change`), never writes.
- One registry row per point program, pointing at the program's redemption terms or rewards-chart
  URL, distinct from any card product page.
- Monthly fetch on the same loop as Stage 2. `CPP_DEDUPE_DAYS: 6` already handles multi-issuer
  programs so a shared program is checked once per weekly cycle
  (RUNBOOK_verify_batch.md §10).
- A changed published rate opens a verification item; it does not auto-write. Every value change
  still goes through §7.
- Programs classified `variable` get a calendar review regardless of fetch result, since their
  floors can move without page changes.

  **CORRECTED 2026-07-31.** This clause originally said "annual", which contradicted the review
  SLA agreed in `PROPOSAL_cpp_audit_layer2.md` §4 and now enforced by CPP-13 off
  `sources_verified_at`: **`variable` 90 days**, `bank` 180, `fixed` 365, `legacy` exempt. The
  SLA governs. An annual review would have let the 2026-06-01 Aeroplan devaluation sit for up
  to a year — the exact failure this section exists to prevent, written into the section itself.

  Note the two clocks are different things and both are needed: **fetch cadence** is how often
  the registry pulls the document; **review SLA** is how long a stored value may go without its
  sources being re-read. Fetching cannot satisfy the SLA on its own, because an unchanged page
  does not prove the valuation still holds.

---

## 7. Change protocol

Per PROJECT_RULES.md rule 9 exception (2026-07-29):

1. **Snapshot before the first write of a session.** `point_valuations_snapshot_<YYYYMMDD>`.
2. **Expire-then-insert, never DELETE.** `UPDATE ... SET valid_to = CURRENT_DATE WHERE
   point_program_id = ... AND valuation_tier = ... AND valid_to IS NULL`, then INSERT the
   replacement with `valid_from = CURRENT_DATE`. Expire count ≠ expected → ROLLBACK.

   **`CURRENT_DATE` is UTC on the server, and it will bite evening sessions.** Added 2026-07-31
   after a live incident: a session running past 20:00 Eastern crossed 00:00 UTC mid-flight, and
   the first write of ruling A stamped `valid_from = 2026-08-01` — a future date, from a session
   everyone involved believed was running on 2026-07-31. Post-commit verification caught it and
   it was corrected in place.

   Two consequences, both nasty because they are silent:
   - A row can be stamped **tomorrow**, which makes it invisible to
     `valid_from <= CURRENT_DATE` filters in local time and breaks the staleness arithmetic.
   - The same-day rule below inverts: a row you wrote "today" may be dated tomorrow, so
     expire-then-insert unexpectedly *succeeds* where it should have failed, silently creating a
     one-day validity window nobody intended.

   **Rule:** pin an explicit `DATE 'YYYY-MM-DD'` literal in every write of a session that could
   cross 00:00 UTC — which in Eastern time means any session running after 20:00. Do not rely on
   `CURRENT_DATE`. Verify after the first write of the session, not at the end.

   **Same-day supersession is an in-place UPDATE, not expire-then-insert.** The schema enforces
   `CHECK (valid_to IS NULL OR valid_to > valid_from)`, strictly greater, so a row created today
   cannot be expired today — the attempt raises `point_valuations_valid_date_range` and rolls the
   transaction back. This is correct behaviour: a zero-length validity window carries no
   information. When revising a row written earlier in the same session, UPDATE it in place, bump
   `updated_at`, and record the supersession in `review_notes`. The snapshot and the delta file
   preserve the trail. Check `valid_from` before choosing the path — a guard that asserts
   `valid_from < CURRENT_DATE` before expiring is cheap and fails closed.
3. **Cut a delta file for every applied change**, dated run folder,
   `YYYY-MM-DD__<program-slug>__cpp.sql`, BEGIN/COMMIT, comment header. The file record must never
   lag the DB — the 2026-07-27 batch-1 changes were applied with no delta files, and the
   2026-07-22 APPLY_REPORT confirms the files were never cut. That is the failure this condition
   prevents.
4. **Record the basis in `source_notes` and the decision in `review_notes`.** State the source tier
   explicitly. A Tier 2 row must name its three-plus sources, their access dates, and the observed
   range the stored value sits inside.

---

## 8. Current state and work list

Applied 2026-07-29 under this rule:

- `blue_rewards` — conservative and aggressive rows added at the issuer-stated 0.667¢/pt, matching
  the existing realistic row. `fixed`, so collapse is correct. Closes the only structural gap that
  touched live scoring (2 scoreable cards).
- `mbna-rewards-points` conservative re-anchored 0.90 → 0.8333, the issuer-stated cash redemption
  rate (120 pts = $1, live-verified 2026-07-04). The prior 0.90 matched neither published rate.
- `generic_points` retired — registered program, zero valuations, zero cards.

**Reversed the same day:** an earlier delta expiring the six `variable` aggressive rows was cut and
then voided before application (`.VOID` file retained in the run folder). Tier 2 removed its
justification. No aggressive row was ever expired; the snapshot confirms it.

> **SUPERSEDED 2026-07-31 — the table below is the state BEFORE the spread-rule-v2 pass, and
> most of it is closed.** It was never updated after the values moved on 2026-07-29, so it
> reads as outstanding work that is already done. Verified against live on 2026-07-31:
>
> | Row below claims | Live now |
> |---|---|
> | `amex-mr` aggressive **defect**, 2.50 above its own range | **2.0000**, inside the 1.70–2.00 band — closed |
> | `aeroplan` realistic/aggressive unsourced, all three `high` | 1.20 / 1.27 / 2.00 at `medium-high` — re-sourced |
> | `rbc-avion` realistic 1.50 / aggressive 2.00 unsourced | 1.00 / 1.00 / 2.30, Tier 1b issuer-published |
> | `marriott`, `avios`, `national-bank`, `cibc` gaps | all re-sourced during the v2 pass |
> | `airmiles`, `desjardins-odyssey`, `triangle` | retired to inert — no active valuation |
>
> All 57 active rows now carry a `source_tier` (11 `tier2`, 46 `tier1`/`tier1b`, 0 NULL) and a
> `sources_verified_at`. See §11 for the current values and
> `card_coach_business_docs/01_CORE/data/deltas/2026-07-31/` for the layer-2 backfill.
>
> **What is genuinely outstanding is now three rows, not eleven** — and the constraint layer,
> not this prose, is what holds the line on them:
>
> | Programme | Open item | Blocks |
> |---|---|---|
> | `avios-points` | Only **two** identifiable sources (1.20, 2.00). §2 condition 2 needs three. Values sit inside the band; the defect is count alone | `pv_tier2_needs_three_sources` |
> | `marriott-bonvoy-points` | Two **attributable** sources (0.80, 0.90). The third figure on file, 0.70, is a band low-end, not a named publisher. If a genuine third is found, note that realistic 0.7000 would then sit below a 0.80 floor and breach §2 condition 3 as well | same, plus `pv_within_observed_floor` |
> | `aeroplan-points` | Five genuine sources exist (band 1.44–2.00) but were **not** recorded: realistic 1.2700 sits below the 1.44 floor and is not `conservative`, so inserting them fails the row. Re-anchor realistic, extend condition 6's documented-divergence allowance beyond the conservative tier, or leave unsourced | `pv_within_observed_floor` |
>
> Each is a decision for Mike per §2 — find a genuine source, retire the value, or leave the
> constraint unvalidated. None may be resolved by inventing a source (rule 7).
>
> Also open, and not a valuation question: the four `load_only` legacy RBC cards remain
> unclassified (`ca_rbc_rewards_plus_standard_visa`, `ca_rbc_rewards_visa_preferred_standard_visa`,
> `ca_rbc_signature_rewards_standard_visa`, `ca_rbc_us_dollar_visa_gold_visa`). They do not score,
> so there is no live impact, but their redemption tier is unverified and needs issuer
> confirmation before any of them is made `scoreable`.

Outstanding **as of 2026-07-29, retained for history**. Values needing **Tier 1/1b issuer
verification** cannot be filled without one. Values needing **Tier 2 completion** already have a
defensible number — what they lack is the three-source evidence trail §2 now demands. Those are
documentation work, not re-valuation.

| Program | Gap | Type | Cards / scoreable |
|---|---|---|---|
| `amex-mr-points` aggressive | **Defect.** 2.50 sits ABOVE its own cited range (Prince of Travel 2.2 / Milesopedia 1.7 / TPG 2.0), breaching §2 condition (3). Also `high` on a Tier 2 basis, breaching (4). Move inside the range or re-source | Tier 2 fix | 7 / 6 |
| `aeroplan-points` | Realistic 2.00 **confirmed to stay** (Mike, 2026-07-29). Conservative 1.20 names three sources and clears the test; realistic 2.00 and aggressive 2.50 name none — only "standard trans-Canada economy". All three carry `high`, breaching (4) | Tier 2 completion | 10 / 10 |
| `rbc-avion-points` | Conservative 1.00 is issuer-published (portal 100 pts = $1) and compliant. Realistic 1.50 and aggressive 2.00 are chart judgment with no sources named | Tier 2 completion | 8 / 5 |
| `marriott-bonvoy-points` | Realistic 0.90 names two sources (NerdWallet 0.8, ThePointCalculator.ca 0.9) — one short of three, and 0.90 sits at the top of that two-point range. Conservative and aggressive name none. Dynamic-pricing devaluation flagged since March | Tier 2 completion | 2 / 2 |
| `avios-points` | No source named on any of the three rows | Tier 2 completion | 1 / 1 |
| `airmiles-points` | Realistic 10.50 is issuer-anchored (95 miles = $10) and compliant. Conservative 9.50 is inferred ("slightly below standard Cash rate"); aggressive 14.00 names two sources | Tier 2 completion | 1 / 0 |
| `cibc-aventura-points` aggressive | 2.00 may be correct but `source_notes` still describe the superseded 1.00/1.50 scheme. Restate against the Airline Rewards Chart | Tier 1b restatement | 2 / 2 |
| `national-bank-points` | Conservative 0.90 basis not recorded. Cards are `load_only`, so no live scoring impact | Tier 1b restatement | 3 / 0 |
| `desjardins-odyssey-points` | Unsourced 0.3750, `valid_from` 2020-01-01, no complexity or confidence | Tier 1/1b needed | 0 / 0 |
| `triangle-points` | Unsourced 1.4000, same shape. CT Money unit convention parked (WORKING_NOTES #10) | Tier 1/1b needed | 0 / 0 |
| `hsbc-rewards-points` | `legacy`, confidence `low`, card excluded. Archive when HSBC records are formally retired | No action | — |

Doc corrections made in the same pass: HOW_THE_ENGINE_WORKS.md §4 described a single valuation row
per program, stale since migration 0038. SOURCE_OF_TRUTH.md's "aggregators are never truth" line
amended with the Tier 2 carve-out. PROJECT_RULES.md rule 9 amended with the lane exception.
`webapp/DATA_CONTRACT.md` reports `export_point_valuations` at 53 rows against live — needs a
refresh after this pass settles.

---

## 9. Open questions for Mike

1. **Is three sources reachable for every variable program?** `avios-points` has zero on file and
   one scoreable card. If three independent Canadian-relevant valuations do not exist for Avios,
   §2 leaves no compliant path and the rows should be absent rather than kept. Same risk for
   `marriott-bonvoy-points`, which is one source short today.
2. **`amex-mr-points` aggressive is a live defect**, not a documentation gap. 2.50 exceeds its own
   ceiling. Pending your call it should move to 2.20 (top of cited range) or be re-sourced — I have
   not guessed a value.
3. **`Operating_Model.md`** holds back "any specific dollar value claims tied to point_valuations."
   Tier 2 improves the evidence trail but a consensus-based number is a weaker public claim than an
   issuer-stated one. Worth deciding whether the holdback distinguishes the two.
4. **Tier 2 is scoped to this table only.** If it later gets cited as precedent for earn rates or
   fees, that is scope creep and should be refused.

---

## 10. Decision log

| Date | Decision | Effect |
|---|---|---|
| 2026-07-29 | `point_valuations` moved to Mike's lane; direct writes authorised with snapshot, delta file and expire-then-insert | PROJECT_RULES.md rule 9 exception |
| 2026-07-29 | Tier spread rule keyed to `complexity_tier` | §4 |
| 2026-07-29 | Drop `aggressive` for `variable` programs | **REVERSED same day** — delta voided before application |
| 2026-07-29 | Aeroplan realistic stays 2.00; Tier 2 industry consensus permitted for this table | §2, SOURCE_OF_TRUTH.md amended |
| 2026-07-29 | Consensus test: 3+ independent sources, value inside observed range, confidence capped `medium-high` | §2 conditions 2–4 |
| 2026-07-29 | `mbna-rewards-points` conservative → issuer cash floor 0.8333 | Applied |
| 2026-07-29 | `generic_points` retired | Applied |
| 2026-07-29 | Aeroplan realistic held at 2.00 | **SUPERSEDED same day by spread rule v2** → 1.27 |
| 2026-07-29 | `amex-mr` aggressive → 2.20 ("highest industry") | **SUPERSEDED same day** → 2.00, after a re-check put the live ceiling at 2.00 |
| 2026-07-29 | Four Tier 2 rows re-sourced, confidence capped at `medium-high` | Applied — live check returns 0 violations |
| 2026-07-29 | **Spread rule v2**: conservative = floor, realistic = LOWEST consensus, aggressive = HIGHEST consensus | §4. Applied to `aeroplan-points` and `amex-mr-points` only — see §11 |
| 2026-07-29 | `avios-points` investigated as a suspected typo of `rbc-avion-points` | **NOT merged** — distinct real programme, see §11 |

---

## 11. Spread rule v2 — applied vs outstanding

v2 is applied to **five of six** `variable` programs. All source sets were built by live research on
2026-07-29; nothing was estimated.

| Program | conservative | realistic | aggressive | Basis | Cards / scoreable |
|---|---|---|---|---|---|
| `aeroplan-points` | 1.2000 | 1.2700 | 2.0000 | Tier 2, 5 sources, range 1.27–2.00 | 10 / 10 |
| `amex-mr-points` | 1.0000 | 1.7000 | 2.0000 | Tier 1 floor + Tier 2, programme-valuation range 1.70–2.00 | 7 / 6 |
| `rbc-avion-points` | 1.0000 | 1.0000 | 2.3000 | **Tier 1b** — issuer-published tier rates | 8 / 5 |
| `marriott-bonvoy-points` | 0.7000 | 0.7000 | 0.9000 | Tier 2, range 0.70–0.90 | 2 / 2 |
| `avios-points` | 1.2000 | 1.2000 | 2.0000 | Tier 2, CAD figures only, range 1.20–2.00 | 1 / 1 |
| `airmiles-points` | — | — | — | **RETIRED 2026-07-29** — superseded by `blue_rewards` | 1 / 0 |

### Retirements (Mike, 2026-07-29)

Five valuation rows expired across three programs. The `point_programs` registry rows **remain**;
the programs are now *inert* — present, no active valuation, nothing scores against them.

| Program | Rows expired | Why |
|---|---|---|
| `airmiles-points` | 3 | AIR MILES rebranded to Blue Rewards in the real world (WORKING_NOTES #6, verified 2026-07-02). `blue_rewards` carries the issuer-anchored successor at 0.667 |
| `desjardins-odyssey-points` | 1 | Never migrated. Unsourced 0.3750, `valid_from` 2020-01-01, zero cards |
| `triangle-points` | 1 | Never migrated. Unsourced 1.4000, same shape. CT Money unit convention parked |

**Retiring an unsourced value is an improvement, not housekeeping.** Rule 7 says unknowns are
flagged, never estimated. An absent row is honest; an unsourced one sitting in a table that claims
issuer verification is a latent false claim.

**Why the registry rows are not deleted.** Three independent reasons, any one of which is sufficient:

1. **The schema forbids it.** `point_valuations_point_program_id_fkey` is `ON DELETE RESTRICT`, and
   six valuation rows still reference these programs counting expired history. Deleting the registry
   row means DELETEing that history — violating §7 and destroying the record of what we used to
   believe. Contrast `generic_points`, deleted the same day: zero valuation rows, zero cards, so
   nothing had to be destroyed.
2. **A live card legitimately references `airmiles-points`** —
   `ca_bmo_air_miles_mastercard_world_mastercard` (BMO AIR MILES World Mastercard), `closed` +
   `load_only` + `is_active`, retained per the standing discontinued-card convention. Its historical
   earn rates are AIR MILES-denominated, so repointing it to `blue_rewards` would misrepresent what
   it earned. The BMO standard and World Elite cards *were* converted to `blue_rewards` on
   2026-07-02; the World card was closed instead. That asymmetry is correct.
3. **`triangle-points` will be needed again.** Canadian Tire cards are parked behind the per-litre
   `rate_unit` enum (WORKING_NOTES #10). Deleting the program now guarantees recreating it later.

Post-retirement live state: **54 active rows / 94 total · 18 programs with an active valuation ·
21 in the registry · 3 inert · 0 scoreable cards without a valuation.**

Movements applied 2026-07-29:

| Row | From | To | Why |
|---|---|---|---|
| `marriott-bonvoy` realistic | 0.90 | **0.70** | **Closes the Bonvoy review open since March.** 2026 award pricing rose 5–10% across category tiers; third-party valuations fell from ~0.84 (2024) to 0.70–0.80 |
| `marriott-bonvoy` aggressive | 1.20 | **0.90** | 1.20 exceeded every 2026 source and predated the devaluation |
| `avios` realistic | 2.00 | **1.20** | Economy awards ~1.20 CAD, the documented low. Programme had **zero** sources on any row before today |
| `avios` aggressive | 2.50 | **2.00** | 2.50 exceeded every located source |
| `rbc-avion` realistic | 1.50 | **1.00** | The prior 1.50 was unsourced judgment. Issuer portal rate is 1.00 |
| `rbc-avion` aggressive | 2.00 | **2.30** | RBC Air Travel Redemption Schedule pays up to 2.30 at Avion Elite — issuer-published, so this row is now Tier 1b |

### ESCALATION — RBC ION tier mismatch

`rbc-avion-points` is attached to 5 scoreable cards, but they are **not all on the same redemption
tier**. RBC's published structure, confirmed 2026-07-29:

| Tier | Rate | Cards in catalog |
|---|---|---|
| Avion Elite | up to 2.30 (Air Travel Redemption Schedule) | Avion Visa Platinum, Infinite, Infinite Privilege |
| Avion Premium | 100 pts = $1 → 1.00 | — |
| Avion Select | 172 pts = $1 → **0.58** | **RBC ION Visa, RBC ION+ Visa** |

Both ION cards are `scoring_status = 'scoreable'` and share `point_program_id = 'rbc-avion-points'`,
so they are valued at up to 2.30 when their own tier redeems nearer 0.58. The previous `source_notes`
asserted "ION cards not in scope" — they are in the catalog and they are scoreable, so that note was
factually wrong.

**Correction to an earlier draft of this section.** It named the ION tier as *Avion Select* at 0.58
and asserted that the pre-existing note on `rbc-avion-points` — "ION cards (Avion Premium, 0.58 cpp)"
— was wrong. **The old note was right.** Verified 2026-07-29 against Prince of Travel and
Milesopedia: RBC ION and ION+ cardholders are in the **Avion Premium** tier, which redeems travel at
**172 points = $1.00 CAD = 0.5814 c/pt**. An intermediate research pass had transposed the Select and
Premium rates. The corrected tier table:

| Tier | Travel redemption | Cards in catalog |
|---|---|---|
| Avion Elite | up to 2.30 (Air Travel Redemption Schedule) | Avion Visa Platinum, Infinite, Infinite Privilege |
| Avion Premium | 172 pts = $1 → **0.5814** | **RBC ION Visa, RBC ION+ Visa** |
| Avion Select | lowest tier | none in catalog |

**Exposure was amplified by earn multipliers.** ION+ carries bonus categories to 3 pts/$, so at the
aggressive tier it presented as ~6.9% effective return on a $48 card against ~1.74% real. The three
genuine Elite cards cap at 1.25 pts/$ and are far less sensitive to the same CPP error — which is why
the distortion landed almost entirely on the two cards that did not belong.

### Resolution

**Applied 2026-07-29 (live):** both ION cards set to `scoring_status = 'load_only'`. Exposure closed.
`rbc-avion-points` now serves only the three genuine Avion Elite cards for scoring, so its
1.00 / 1.00 / 2.30 values are correct for everything that scores against it.

**Staged, not yet applied** — two files, in order:

1. `mobile_app_codebase/supabase/migrations/0056_point_programs_allow_multiple_redemption_tiers.sql`
2. `card_coach_business_docs/01_CORE/data/deltas/2026-07-29/2026-07-29__rbc-ion__avion-premium-tier-split.sql`

**Why a migration was needed at all.** Migration 0008 created
`point_programs_reward_program_id_unique` with the comment *"Create unique index on reward_program_id
for 1:1 mapping"*. A second Avion point programme is therefore impossible without touching that
index. The 1:1 assumption is falsified by RBC: one reward programme, multiple redemption tiers. 0056
relaxes uniqueness only — no column, table, data, RLS or grant change — and nothing in the read path
depends on it (`scoring.ts` filters `v_active_point_valuations` on `point_program_id`; `export_cards`
joins `point_programs` on `id`). A non-unique index is retained for the FK lookup.

Options considered and rejected: a parallel `reward_programs` row (would put two rows in the registry
for one real-world programme and surface to users via `export_cards.reward_program_name`, and would
not scale to a third tier); a card-level valuation override (DDL plus an engine change plus
regression testing the recommendation path, for two cards — revisit if tiered redemption appears at a
third issuer); leaving ION `load_only` permanently (drops a $0 and a $48 card from recommendations
over a modelling gap rather than a data problem).

DDL authorised by Mike 2026-07-29. Execution was blocked by the Cowork session's DDL permission gate,
so the migration ships as a file rather than being applied in-session — see the tooling note in
PROJECT_RULES rule 9.

**Still open:** four `load_only` legacy RBC cards remain on `rbc-avion-points` (RBC Rewards+, RBC
Rewards Visa Preferred, Signature RBC Rewards, RBC U.S. Dollar Visa Gold). Tier unverified. No live
impact while they do not score; classify before any is made scoreable.

**Material impacts of the v2 changes already applied.** Both move the default scoring tier, so both
change recommendations:

- Aeroplan realistic 2.00 → 1.27, a **36.5% reduction** across 10 scoreable cards. Aeroplan cards
  will rank lower against cashback competitors. Directionally consistent with the 2026-06-01
  devaluation.
- Amex MR realistic 1.00 → 1.70, a **70% increase** across 6 scoreable cards. This reverses the
  direction of the 2026-07-27 batch-1 re-anchoring, which had pulled realistic down to the issuer
  floor. Amex cards will rank higher.

**`avios-points` is not a typo of `rbc-avion-points`.** Investigated on that hypothesis 2026-07-29.
`avios-points` has exactly one card, `ca_rbc_british_airways_visa_infinite_visa` — RBC British
Airways Visa Infinite, $165 fee, `scoreable`, `application_status = open`. RBC issues a genuine BA
co-brand in Canada and it earns Avios. Distinct `reward_programs` rows also exist (`avios` default
1.80, `rbc-avion` default 1.20). Merging would have mis-mapped a live scoreable card onto the wrong
currency. No action taken.

**One flag on the Amex 1.70.** It is a 2026-03-14 Milesopedia figure. The 2026-07-29 re-check of the
same source gives a cash range of 1.1–1.55 cpp; if that is adopted as the consensus low, this row
moves to roughly 1.10 rather than 1.70. The 1.70 is the lowest figure in the *cited* set, not
necessarily the lowest *current* one.
