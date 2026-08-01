# PROPOSAL — D3: programme-level redemption-terms monitoring

**Status:** **APPROVED 2026-07-31** (Mike: "go with rec on all" — a: point_program_id column ·
d: parking row + runbook §5 gated carve-out · e: cadence values as proposed · f: normalise CSV
to DB tier format). Implementation same day, this session.
**Date:** 2026-07-31 · **Author:** Claude session (D3 lane) · **Authority:** governance §6, decision D3
**Inputs read:** `HANDOFF_cpp_valuation_lane_2026-07-29.md` · `PROPOSAL_cpp_audit_layer2.md` §4 ·
`PROPOSAL_point_valuation_governance.md` §6–7 · `card_sources_seed_enriched.csv` (716 rows) ·
`stage2_fetcher.py` · `stage3_delta_to_sql.py` · `RUNBOOK_verify_batch.md` ·
migrations `20260731151950_cpp_structured_evidence.sql` + `20260727215042_verification_engine_p1_verify_schema.sql` ·
`scripts/verify_cpp_invariants.mjs` · reports `changes_2026-07-26_2313.md` + `stage3_deltas_2026-07-27.md`

---

## 0. A correction to the framing, first

The gap is slightly different from "Aeroplan terms are fetched ~10 times and connect to
nothing." The registry's 179 `rewards_program_terms` rows are **per-card cardmember
agreements** — Amex's per-card CMA PDFs, TD's shared T&C PDF, etc. They are card-level
*earning* terms, legitimately keyed by card. The programme's own *redemption* document —
the Aeroplan Flight Reward Chart that moved 67% — appears **nowhere**: `aeroplan.com`
has zero hits in the registry. So the true state is worse than duplication: the document
class that devalued is fetched **zero** times.

Consequence for design: the new rows are a **fifth `source_type` = `redemption_terms`**
(the name governance §6 already approved), *additive* to the existing 179
`rewards_program_terms` rows, which keep their card-level meaning. ~19 new rows, not a
restructuring of 716.

---

## a) How programme-level rows get keyed

**Recommendation: add a `point_program_id` column to the existing registry; programme
rows carry it and leave `card_id` blank. Exactly one of the two keys is set per row.**

The three options:

1. **`point_program_id` column, `card_id` blank on programme rows** — recommended.
   *Cost:* a small patch to `stage2_fetcher.py` (§b — snapshot pathing, one filter, report
   labels; ~20 lines, not a rebuild). *Buys:* one registry, one fetch loop, one runbook
   entry, and the fetcher's output is keyed by the same id that `point_valuations`,
   `verify.fact_checks` (`cpp:<point_program_id>`) and CPP-13's SLA already use — the join
   D3 exists to create.
2. **Separate registry file** (`program_sources.csv`). Keeps the card registry untouched,
   but the fetcher keys snapshots off the `card_id` column, so the new file must either
   smuggle programme ids under a `card_id` header (a synthetic key in disguise) or get its
   own loader (a second fetcher path — worse than the small patch). Two sources of truth
   for "what do we fetch", two invocations in the monthly loop.
3. **Synthetic `card_id`** (e.g. `program_aeroplan_points`) — **agree this is wrong.**
   Zero code change is its only virtue. It encodes the programme identity inside a string
   that every consumer must parse back out; it pollutes a namespace with a strong format
   (`ca_<issuer>_<card>_<network>_<issuer>`) that tooling pattern-matches; and it
   preserves exactly the disconnect being fixed — nothing downstream can join a fake card
   id to `point_programs` without bespoke string surgery.

`point_program_id` values must be the DB `point_programs.id` slugs **verbatim** (the
formats are mixed — `aeroplan-points` but `blue_rewards` — copy, don't derive).

Snapshot layout for programme rows: `snapshots/program__<point_program_id>/redemption_terms__<lang>.txt`
(the `program__` prefix keeps the snapshots tree unambiguous; a card_id can never
collide with it).

## b) How stage2_fetcher.py consumes the CSV, and what breaks

`load_registry()` uses `csv.DictReader` with `r.get(col, "")` into a fixed `RegistryRow`
dataclass (stage2_fetcher.py:405–423).

- **Adding a column breaks nothing.** Unknown columns are silently ignored. Proof in the
  file itself: `source_referer_url` is in the CSV today and absent from `RegistryRow` —
  the fetcher never reads it and never sends a Referer header.
- **Blank `card_id` breaks three things.** Rows are *not* skipped (only blank
  `source_url` is, line 277), so blank-card rows flow through and:
  1. `snapshot_path_for()` (line 229) builds `snapshots/<card_id>/<type>__<lang>.txt` —
     with `card_id=""` every programme row of the same type+language collapses onto **the
     same snapshot file**, so programmes clobber each other and every run reports a false
     "changed" with a cross-programme diff. This is the one genuinely dangerous failure.
  2. `--card-id` filtering (line 437) can never select a blank-key row.
  3. The change report headers print `issuer — card_name`, which would be blank.
- **Required patch (small):** add `point_program_id` to `RegistryRow`; make the snapshot
  key `card_id or f"program__{point_program_id}"`; add a `--point-program-id` filter;
  report label falls back to the programme id. Note: two byte-identical copies of the
  fetcher exist (`Reverify Script/` and `01_CORE/data/`) — patch both or retire one.
- `fetch_cadence` is read but never used (relevant to §e).

## c) What a "changed rate" produces today

Traced through the 2026-07-26 run (`reports/changes_2026-07-26_2313.md`, 13 changed of
306): the fetcher writes a dated Markdown report with a `+N / -M lines` summary and a
40-line diff excerpt per change, and saves the prior snapshot as `.prev.txt`. **No delta
JSON, no DB write, no queue** — the report's "Next step" section instructs a human to run
the Stage 3 prompt manually. That happened on 2026-07-27
(`reports/stage3_deltas_2026-07-27.md`): the 13 were triaged to 2 substantive + 11 noise,
all deltas came out `no_change`, and `stage3_delta_to_sql.py` emitted no SQL. When a delta
is real, it becomes `runs/YYYY-MM-DD/<date>__<issuer>__<card>.sql` for Alex.

**Critical for D3:** `stage3_delta_to_sql.py` has emitters for exactly four card-keyed
tables (`card_products`, `earn_rates`, `card_caps`, `card_exclusions`) and hard-fails on
anything else. There is **no `point_valuations` path**. A programme-terms change
dead-ends after the Markdown report today — which is acceptable, because per governance
§6 the D3 output must *not* flow to an auto-writing stage at all (§d).

## d) Opening a CPP review item without auto-writing

**Recommendation, two layers:**

1. **Report:** changed `redemption_terms` rows get their own section in the Stage 2
   change report — "CPP review required" — naming the `point_program_id`, the diff
   summary, and the governance §7 protocol. (Part of the same small fetcher patch.)
2. **Durable item:** insert one row into **`verify.parking`** — topic
   `cpp_terms_change`, observed JSON
   `{point_program_id, report_path, diff_summary, snapshot_path, prev_path, fetched_at}`.
   `verify.parking` already exists (migration `20260727215042`), is *by design* the
   observed-but-never-promoted landing zone, and is indexed by `(topic, noted_at)` so the
   weekly digest and RUNBOOK_gated_apply can sweep it. The human then works the item
   through governance §7 (snapshot → expire-then-insert → delta file →
   `sources_verified_at` bump), which is what resets the CPP-13 clock.

   Alternative if Mike wants zero DB coupling from the CSV lane: a `cpp_review/` folder
   of dated Markdown items. Works, but invisible to the digest and to any query.

**Conflict that needs a ruling:** `RUNBOOK_verify_batch.md` §5 classifies "single-fact
change, dual-confirmed → **auto**" and §6 explicitly includes `point_valuations` in its
auto-write mechanics. So the verify_batch lane is *permitted to auto-write a CPP value
today*, which contradicts governance §6: "A changed published rate opens a verification
item; it does not auto-write." Proposed fix: one line in runbook §5 carving out
`cpp:<point_program_id>` facts as **gated, always**. Mike decides which document wins;
until then the two lanes disagree.

## e) fetch_cadence ↔ review SLA

The review SLA is already implemented: `verify_cpp_invariants.mjs` `STALENESS_SLA_DAYS =
{variable: 90, bank: 180, fixed: 365, legacy: exempt}`, keyed off `sources_verified_at`
(CPP-13, WARN per-commit / FAIL on weekly `--strict`). Nothing to build there.

Facts that shape the mapping:

- The CSV's `fetch_cadence` has exactly two values — `monthly` (179 product_page rows)
  and `quarterly` (the other 537) — and **the fetcher ignores the column entirely**:
  every run fetches every row with a URL. Cadence is enforced only by how often the loop
  is run. So no cadence value can *operationally* conflict with the SLA today.
- Proposed values for the new rows (advisory, like every other cadence in the file):
  `variable` → **monthly** (a 90d review clock wants ≥2–3 observations inside the
  window); `bank` and `fixed` → **quarterly**; `legacy` (`hsbc-rewards-points`) → give it
  a row at **quarterly** — fetching is nearly free and change detection still has value —
  but its *review* clock stays exempt per the SLA.
- Conflicts found, both documentation-level:
  1. Existing `rewards_program_terms` rows say `quarterly` while layer-2 §4 says
     programme terms ride "the existing monthly loop." Cosmetic while cadence is
     unenforced; recommend the values above and **no** cadence-filtering code now.
  2. Governance §6 last bullet gives `variable` programmes an "annual" calendar review —
     stale against the 90-day SLA that layer 2 adopted and CPP-13 now enforces.
     Recommend a one-line governance edit pointing at the SLA table.

## f) source_tier format mismatch

CSV: `tier_1` (537) / `tier_1b` (179). DB: migration `20260731151950` (**applied**)
constrains `point_valuations.source_tier` to `tier1 | tier1b | tier2` via CHECK
`pv_source_tier_valid`.

**The DB format wins.** It is constraint-enforced, already applied, and used by the
layer-2 checks; the CSV value is free text that no code parses (the fetcher carries it
and uses it nowhere). Recommend: normalise the CSV to `tier1`/`tier1b` in step 2 — a
mechanical substitution across 716 rows with zero code impact — rather than keeping two
vocabularies or adding a mapping layer. New `redemption_terms` rows are born `tier1`
(programme terms are Tier 1 by definition, governance §2).

---

## The 19 rows (URLs deliberately absent)

One row per programme from handoff §2, `source_type=redemption_terms`,
`source_tier=tier1`, `source_language=en-CA`, `card_id` blank. Every `source_url` is
**[VERIFY: issuer-verified data needed]** — rule 7 forbids inventing them; collecting and
verifying the 19 URLs is its own work item in step 2, done against the live programme
sites.

| point_program_id | complexity | fetch_cadence | note |
|---|---|---|---|
| aeroplan-points | variable | monthly | Flight Reward Chart — the document that moved 2026-06-01 |
| amex-mr-points | variable | monthly | |
| rbc-avion-points | variable | monthly | Air Travel Redemption Schedule (ION escalation doc) |
| marriott-bonvoy-points | variable | monthly | flagged March, still wrong in July |
| avios-points | variable | monthly | |
| bmo-rewards-points | bank | quarterly | **bmo.com blocks the fetcher UA at the edge** (url_rescue 2026-07-27) — expect chrome-lane handling |
| td-rewards-points | bank | quarterly | |
| cibc-aventura-points | bank | quarterly | the Aventura Points Chart the 2.28 reading needs anyway (handoff §5.5) |
| mbna-rewards-points | bank | quarterly | |
| rbc-avion-premium-points | bank | quarterly | |
| national-bank-points | bank | quarterly | 0 scoreable today |
| scene-plus-points | fixed | quarterly | |
| pc-optimum-points | fixed | quarterly | PC Financial also UA-walled — verify before relying on fetch |
| blue_rewards | fixed | quarterly | slug verbatim — no `-points` suffix |
| more-rewards-points | fixed | quarterly | |
| westjet-dollars-points | fixed | quarterly | |
| amazon-rewards-points | fixed | quarterly | |
| moi-points | fixed | quarterly | |
| hsbc-rewards-points | legacy | quarterly | fetch yes, review clock exempt |

Inert, **no row**: `airmiles-points`, `desjardins-odyssey-points`, `triangle-points`.

---

## Step 2 implementation sketch (after approval — not started)

1. CSV: add `point_program_id` column (blank on all 716 existing rows); normalise
   `tier_1`/`tier_1b` → `tier1`/`tier1b`; append the 19 rows with URLs individually
   verified against the live programme sites, `[VERIFY]` where a compliant URL cannot be
   found (BMO/PCF walls).
2. Fetcher patch (~20 lines, both copies): `RegistryRow.point_program_id`, snapshot key
   fallback `program__<id>`, `--point-program-id` filter, report section + labels for
   programme rows, `verify.parking` insert (or emit-only, per Mike's call on §d).
3. Runbook edits: monthly-loop invocation note; §5 carve-out `cpp:* → gated` (pending
   Mike's ruling on the conflict).
4. Governance §6 one-liner: variable calendar review "annual" → per SLA table (90d).
5. No DB DDL. No new tables. `verify.parking` and CPP-13 already exist and close the loop.

**Approved 2026-07-31; implemented same day. Record below.**

---

## Implementation record (2026-07-31)

**Registry** (`card_sources_seed_enriched.csv`, now 735 rows): `point_program_id` column
added (blank on all 716 card rows); `source_tier` normalised `tier_1`/`tier_1b` →
`tier1`/`tier1b`; 19 programme rows appended, every URL individually verified against the
live programme site the same day (browser-verified where bot walls block plain fetch).
Key finds: the actual June 2026 Aeroplan Flight Reward Chart PDF on aircanada.com;
`blue_rewards` = AIR MILES rebranded to **Blue Rewards** (airmiles.ca 301s to
bluerewards.ca; 1,500 Blue Points = $10 ≈ the stored 0.667); the master Avion T&C PDF
stating the Premium/ION rate 100 pts = $0.58 CAD (matches stored 0.5814); an
RBC-preserved HSBC disclosure PDF (hsbc.ca DNS is dead).

**Fetcher** (both copies, byte-identical): `point_program_id` on `RegistryRow`; snapshots
under `program__<point_program_id>/`; `--point-program-id` filter; "CPP review required"
report section; `reports/cpp_parking_*.sql` emission (INSERTs into `verify.parking`,
topic `cpp_terms_change`, applied by the connector session — never auto-writes);
programme-row shell guard (<500 chars normalised text → error, mirrors verify_batch
`SHELL_THRESHOLD`) so a JS shell can never become a baseline that diffs shell-vs-shell
past a devaluation.

**Docs:** runbook v1.3 `cpp:*` gated carve-out (§5 + §6); stage2_README D3 section;
governance §6 D3 bullet marked implemented. The governance "annual variable review"
correction had already been made by a concurrent session.

**Baseline state after first fetch (19 rows):** 13 clean baselines stored. 6 sources need
the chrome lane / rendered fetch and fail closed until then: `avios-points` (403),
`blue_rewards` (403 via oauth bounce), `more-rewards-points` and `bmo-rewards-points`
(SPA, empty extraction), `pc-optimum-points` and `scene-plus-points` (SPA shells caught
by the new guard; their initial shell baselines were purged). `rbc-avion-points` stores
2,467 chars of page copy but the chart itself is client-rendered — weak signal, noted in
its registry row; the master Avion T&C PDF row (`rbc-avion-premium-points`) covers both
tiers and is fully fetchable.

**Not done, deliberately:** no cadence-filtering code (cadence stays advisory); no Stage 3
path for programme rows (by design); no `verify.parking` rows inserted (no change has
been detected yet — the emitted SQL path is tested with a synthetic change).
