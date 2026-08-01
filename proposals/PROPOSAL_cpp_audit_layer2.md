# PROPOSAL — CPP audit layer 2: structured evidence and scheduled re-verification

**Status:** **DECIDED 2026-07-29** (Mike, all four questions) · Last updated: 2026-07-31 · Migration written:
`mobile_app_codebase/supabase/migrations/0057_cpp_structured_evidence.sql`, not yet applied

## Decisions (Mike, 2026-07-29)

| # | Question | Decision |
|---|---|---|
| 1 | `redemption_tier` labelling | **Issuer's own labels**, verbatim. The invariant only needs equality within a programme; a normalisation layer would be a new place to be wrong |
| 2 | SLA gating | **Split by failure type.** Correctness (CPP-01→12) blocks CI. Staleness and drift (CPP-13/14/15) report in CI, fail on a weekly `--strict` run. Gate commits on what a commit could break; gate schedules on what time breaks |
| 3 | `source_urls` shape | **Child table** `point_valuation_sources`, carrying each source's own `observed_value`. `observed_low`/`observed_high`/`source_count` become derived, never hand-typed |
| 4 | Change-control gate | **Yes, enforced as a check** — not a convention. A rule in a document will not survive multi-session work |

### RESOLVED DEFECT — the three-source constraint does not currently bite (found 2026-07-31, resolved 2026-07-31)

> **RESOLVED 2026-07-31** by migration `20260731221119_source_count_not_null`
> (CardCoachv2): backfill NULL→0 across all 95 NULL rows, `SET DEFAULT 0`,
> `SET NOT NULL`. One wrinkle the fix surfaced: a NOT VALID CHECK still fires on
> UPDATE, so the constraint had to be dropped around the backfill and re-added
> NOT VALID (verified against prod — the naive UPDATE is rejected with 23514).
> The seven tier2 rows (six active: aeroplan ×3, marriott ×3; plus one expired
> avios row) now read `source_count = 0` and genuinely fail
> `source_count >= 3` — validation stays gated on evidence attachment.
> The section below is preserved as found.

`source_count` was applied as **nullable**. The draft specified `NOT NULL DEFAULT 0`; the applied
migration `20260731151950_cpp_structured_evidence` does not carry that. The consequence:

```sql
CHECK (source_tier IS DISTINCT FROM 'tier2' OR source_count >= 3)
```

For a Tier 2 row with no evidence attached, `source_count` is NULL, so `source_count >= 3`
evaluates to NULL, `false OR NULL` is NULL — and **a CHECK constraint is satisfied by NULL.**

So a Tier 2 row with *zero* sources passes. Validating the constraint would not catch it. Six
rows are in exactly this state right now — `aeroplan-points` ×3 and `marriott-bonvoy-points` ×3,
all `source_count = NULL`.

This means the headline claim for layer 2 — "the database refuses a Tier 2 row without three
sources" — **is not true as applied.** The rows that most need the rule are the ones it silently
passes.

**Fix, needs a migration:** either `ALTER COLUMN source_count SET DEFAULT 0` plus a backfill of
NULL → 0 then `SET NOT NULL`, or rewrite the constraint as
`coalesce(source_count, 0) >= 3`. The first is cleaner — it makes "no evidence" and "zero
evidence" the same state, which they are.

Until then the gate is CPP-11/CPP-17 in the check suite, not the database. Do not treat
`pv_tier2_needs_three_sources` as load-bearing.

### Consequence of decision 3 that changed the design

**A CHECK constraint cannot reference another table.** Putting sources in a child table means
the band is not readable at constraint-evaluation time, so `cents_per_point <= observed_high`
cannot be a plain CHECK against child rows.

Resolution: `observed_low` / `observed_high` / `source_count` are **columns on
`point_valuations`, maintained by an AFTER trigger on `point_valuation_sources`**. The
constraints read the columns; the trigger keeps the columns honest. Both properties survive —
the numbers are derived rather than typed, *and* the database still refuses a row priced above
its own evidence.

Ordering follows from this: insert the valuation first (band NULL, constraints pass
vacuously), then its sources. The trigger recomputes and the CHECK re-evaluates on that
UPDATE, so an out-of-band value fails at the moment the source exposing it is added.

---

**Original proposal follows.** Owner: Mike · Requires DDL, so Alex's eyes before it runs
**Depends on:** `PROPOSAL_point_valuation_governance.md` (the rules) ·
`mobile_app_codebase/scripts/verify_cpp_invariants.mjs` (layer 1, built and registered as `pnpm verify:cpp`)

---

## 1. What layer 1 cannot do, and why

Layer 1 encodes fifteen invariants as executable checks. Two of them are structurally
weak, and both weaknesses have the same cause: **the evidence lives in prose.**

**CPP-11 — "stored value sits inside the range its own notes cite."** This is the defect
class that produced `amex-mr` at 2.50 against a cited range of 1.70–2.20, plus the same
error on `aeroplan` (2.50 vs 2.00), `avios` (2.50 vs 2.00), `marriott-bonvoy` (1.20 vs
0.90) and `cibc-aventura` (2.00 described as "near-max chart" when the published economy
maximum was 2.28). Five programmes, one root cause.

The check works by regex-scraping an `OBSERVED RANGE x-y` string out of `source_notes`.
Measured against live data on 2026-07-29 it found 0 violations — but across only
**12 of 54 active rows**, because only the rows rewritten that day carry the string.
The other 42 rows are unprotected. A regex over English prose is not an invariant; it is
a convention that happens to hold where someone remembered it.

**CPP-13 — staleness.** Uses `updated_at` as a proxy for "when were the sources last
actually read". The proxy overstates freshness: editing a typo in `review_notes` resets
the clock without anyone re-reading a single source. Against live data it reports 0
offenders, which is not reassuring — it is a measurement failure. The two real
devaluations found on 2026-07-29 (Aeroplan effective 2026-06-01, Marriott Bonvoy 2026)
would both have passed this check on the morning of the audit.

**CPP-12 — tier coherence.** Currently a hardcoded allowlist naming the two RBC ION cards.
It catches the exact defect found, and nothing else. Any other issuer with tiered
redemption would slip straight through.

---

## 2. Schema change

Six columns on `point_valuations`, one on `card_products`. No data loss, all nullable on
arrival so the backfill can be incremental.

```sql
ALTER TABLE point_valuations
  ADD COLUMN source_tier          text,      -- 'tier1' | 'tier1b' | 'tier2'
  ADD COLUMN observed_low         numeric,   -- bottom of the cited band
  ADD COLUMN observed_high        numeric,   -- top of the cited band
  ADD COLUMN source_count         smallint,  -- independent sources behind the band
  ADD COLUMN sources_verified_at  date,      -- when the sources were last READ
  ADD COLUMN source_urls          text[];    -- the named sources

ALTER TABLE card_products
  ADD COLUMN redemption_tier      text;      -- issuer's own tier label, nullable
```

`source_tier` is the important one. It replaces regex-sniffing a prose prefix with a
constrained enum, which is what makes the rest checkable.

### Constraints this unlocks

```sql
-- the amex-mr defect class becomes structurally impossible
ALTER TABLE point_valuations ADD CONSTRAINT pv_within_observed_ceiling
  CHECK (observed_high IS NULL OR cents_per_point <= observed_high);

-- below the floor is legitimate ONLY for conservative (governance §2 condition 6)
ALTER TABLE point_valuations ADD CONSTRAINT pv_within_observed_floor
  CHECK (observed_low IS NULL
         OR cents_per_point >= observed_low
         OR valuation_tier = 'conservative');

ALTER TABLE point_valuations ADD CONSTRAINT pv_band_coherent
  CHECK (observed_low IS NULL OR observed_high IS NULL OR observed_low <= observed_high);

ALTER TABLE point_valuations ADD CONSTRAINT pv_source_tier_valid
  CHECK (source_tier IS NULL OR source_tier IN ('tier1','tier1b','tier2'));

-- Tier 2 needs three independent sources (governance §2 condition 2)
ALTER TABLE point_valuations ADD CONSTRAINT pv_tier2_needs_three_sources
  CHECK (source_tier <> 'tier2' OR source_count >= 3);

-- Tier 2 may never claim issuer-grade confidence (governance §2 condition 4)
ALTER TABLE point_valuations ADD CONSTRAINT pv_tier2_confidence_cap
  CHECK (source_tier <> 'tier2' OR confidence <> 'high');
```

Note what changes in kind here. Today these rules are enforced by me reading rows and by
a regex that covers 22% of them. After this, **the database refuses the bad row.** A
future agent cannot write `2.50` against a ceiling of `2.20` even if it wants to.

### Checks that get promoted

| Layer 1 check | Today | After |
|---|---|---|
| CPP-08 source tier declared | WARN, regex on prose | Drop — replaced by `source_tier` NOT NULL where cards score |
| CPP-09 Tier 2 confidence cap | FAIL, regex-gated | Constraint `pv_tier2_confidence_cap` |
| CPP-11 value inside range | FAIL, 12/54 coverage | Constraints `pv_within_observed_ceiling` / `_floor`, 100% coverage |
| CPP-12 tier coherence | FAIL, hardcoded allowlist | Generic: group by `point_program_id`, assert one distinct `redemption_tier` |
| CPP-13 staleness | WARN, `updated_at` proxy | FAIL on `sources_verified_at`, which only moves when sources are re-read |

---

## 3. Backfill

54 active rows. Not a migration script — it is verification work, and rule 7 forbids
inventing a band to satisfy a constraint.

1. Add the columns nullable. Add **no** constraints yet.
2. Backfill the 12 rows that already state a range in prose: `aeroplan` ×3, `amex-mr` ×2,
   `avios` ×3, `marriott-bonvoy` ×3, plus `cibc-aventura` aggressive. Mechanical.
3. Backfill `fixed` and `bank` programmes from their published channel rates —
   `observed_low` and `observed_high` are the lowest and highest published channels, and
   `source_count` is the number of channels confirmed. Mostly already in `source_notes`.
4. Set `sources_verified_at` **honestly** — the date the source was actually read, which
   for the 2026-03-19 cohort is 2026-03-19, not today. Expect CPP-13 to light up
   immediately with real staleness. That is the check working.
5. Only then add the constraints, with `NOT VALID` first so existing rows are not
   rejected on arrival, then `VALIDATE CONSTRAINT` once the backfill is clean.

Expected outcome of step 4: the `fixed`/`bank` cohort last verified 2026-03-19 is 132 days
old. Under the SLA in §4 the `bank` programmes breach at 180 days, so several will be due
inside the next two months. Better to know.

---

## 4. Scheduled re-verification

This is decision **D3** — the `redemption_terms` source type — approved and never built.
It is the half of the problem that no constraint can catch, because the data is correct
until the issuer changes it.

**Why Stage 2 misses it:** Stage 2 fetches *card product pages*. A loyalty programme can
devalue without any card fact changing. Aeroplan republished its Flight Reward Chart on
2026-04-26 effective 2026-06-01 with some bands up 67%; not one CardCoach card page
changed, so nothing fired. The stale value sat in production for three months.

**The registry:** one row per point programme, `source_type = 'redemption_terms'`, pointing
at the programme's redemption-terms or rewards-chart URL — distinct from any card page.
Fetched on the existing monthly loop. `CPP_DEDUPE_DAYS: 6` already handles programmes
shared across issuers (RUNBOOK_verify_batch.md §10).

**Review SLA by `complexity_tier`,** deliberately aligned to when the sources themselves
republish:

| complexity_tier | SLA | Rationale |
|---|---|---|
| `variable` | 90 days | Prince of Travel publishes quarterly valuations; Aeroplan moved between two of them |
| `bank` | 180 days | Milesopedia's semi-annual Canadian valuation; issuer portal rates move slowly |
| `fixed` | 365 days | A published ratio like 1,500 pts = $10 changes rarely, and loudly |
| `legacy` | exempt | Frozen by definition |

On a 90-day clock Aeroplan would have surfaced around six weeks after the devaluation
instead of three months.

**A changed rate opens a verification item. It does not auto-write.** Every value change
still goes through governance §7 — snapshot, delta file, expire-then-insert, guards.

---

## 5. Change-control gate

One process addition, and this session is the argument for it.

On 2026-07-29 `aeroplan` realistic went 2.00 → 1.27 within an hour of being explicitly
confirmed to stay at 2.00, and `amex-mr` aggressive moved 2.50 → 2.20 → 2.00 in a single
sitting. Every one of those moves was a rule change working correctly. But they show how
fast the default scoring tier can swing, and the default tier is what moves rankings.

**Proposed:** any change to a `realistic` value on a programme with **≥5 scoreable cards**
requires explicit sign-off recorded in `review_notes`. That is `aeroplan` (10),
`rbc-avion` (5 pending the ION split), `amex-mr` (6) and `scene-plus` (6). Everything else
proceeds under the standing rule 9 authority.

---

## 6. Cost, and what it does not buy

**Cost:** one migration, roughly a day of backfill verification, and the D3 registry
plumbing. The constraints are cheap; the backfill is the real work, because doing it
honestly means admitting how old some sources are.

**What it does not buy:** correctness of judgment. Nothing here decides whether 1.27 is
the right Aeroplan number — that is a call about which expert to weight, and it stays
Mike's. Layer 2 guarantees that whatever number is chosen is inside its own evidence,
dated, sourced, tier-labelled, and re-checked on a clock. That is the achievable target:
**0% unverifiable, 0% self-contradictory, bounded staleness.** Not 100% accuracy — that
was never available for a consensus estimate, and claiming it would be the same category
of error this whole pass was opened to fix.

---

## 7. Open questions

1. **`redemption_tier` on `card_products`** — use the issuer's own label (`Avion Elite`,
   `Avion Premium`) or a normalised internal scale? Issuer labels are honest but
   unstable; a normalised scale invites its own mapping errors.
2. **Does the SLA gate deploys or just report?** A breached SLA failing CI would block
   unrelated work on a data-freshness problem. Suggest: report by default, fail only on
   `--strict`, and run `--strict` on a schedule rather than per-commit.
3. **`source_urls` as `text[]` or a child table?** Array is simpler; a child table lets
   each source carry its own access date and observed figure, which is closer to what the
   three-source rule actually asserts.
