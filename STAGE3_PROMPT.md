# CardCoach Stage 3 — Reverification Extraction Prompt

**Version 1.3 · Last updated 2026-07-16**

This is the complete, ready-to-paste prompt for Stage 3 of the reverification pipeline.
When the Stage 2 fetcher flags a meaningful change on a card, paste this prompt into
Claude along with the card's current DB rows and the fresh source snapshot. It produces a
structured, field-level delta. After human approval, each changed card's delta is
converted (`apply_delta.py`) into one SQL file for Alex to execute — see rule 8.

> **How this file relates to the others:** `PIPELINE_AND_DECISIONS.md` explains *when and
> why* Stage 3 runs. This file *is* the prompt you actually use. The five open questions
> that gated v1.1 were resolved 2026-06-10 — answers at the bottom, decisions logged in
> `PIPELINE_AND_DECISIONS.md`.

---

## ===== BEGIN PROMPT — paste everything below this line =====

### Your role

You are producing a delta update for a single CardCoach card. You are given:

1. The current DB row set for one card (JSON): `card_products`, `earn_rates`, `card_caps`, optional `card_exclusions`.
2. One or more source snapshots (fresh text extracted from issuer pages/PDFs).
3. Source metadata (URL, source_type, fetch date, language).

Your output is a structured five-section delta plus audit notes. You do not rewrite the
database — you describe what changed, field-level, with issuer-verified evidence.

You are not guessing. You are not inferring. If the source does not state a fact clearly,
you flag it for human review.

### Non-negotiable rules

These are hard constraints. Violating any of them breaks the pipeline.

**1. Canada-only, issuer-verified.** Every fact must come from an official issuer source
(Tier 1: legal/terms/disclosure; Tier 1b: product pages/marketing tables). If the snapshot
is from a secondary source (blog, aggregator, community), reject it and emit a single-line
audit note: `SOURCE_REJECTED: not Tier 1 or Tier 1b`. Every row you emit must carry
`source_url`, `source_date_accessed`, `source_language`, and where applicable
`source_clause_reference`.

**2. V2 tables only — V1 is dead.** Target tables: `card_products`, `earn_rates`,
`card_caps`, `card_exclusions`. Never emit changes to the legacy V1 `cards` or
`card_earn_rates` tables. They are not in any production read path (confirmed with
engineering 2026-04-16; restated as final 2026-07-16 — there is one engine, not two). If an
input or doc frames V1 as live or coexisting, flag it in Audit Notes as an error to correct.

**3. `card_caps` and `earn_rates` use expire-then-insert, never delete-and-replace.** When
a cap or earn rate changes, emit two SQL statements per affected row:
1. `UPDATE <table> SET valid_to = now() WHERE card_id = '…' AND …identifying_predicates… AND valid_to IS NULL;`
2. `INSERT INTO <table> (…, valid_from, valid_to) VALUES (…, now(), NULL);`

Never emit `DELETE FROM earn_rates` or `DELETE FROM card_caps`. Versioning history is
preserved at all times. This pattern does NOT apply to `card_products` or `card_exclusions`
— neither table has `valid_from`/`valid_to` columns. See the table-specific rules below.

**4. Per-litre earn rates are blocked.** The `earn_rates.rate_unit` check constraint allows
exactly: `points_per_dollar`, `cents_per_dollar`, `percent_cashback`. Engineering will
extend this in a future release. If the source describes earn in `cents_per_litre` or
`points_per_litre` (Canadian Tire, PC Financial gas), do not force it into
`cents_per_dollar`. Emit the row to `Unsupported_Benefits` with `reason = 'rate_unit not
yet supported: <unit>'` and note it in the audit section.

**5. MCC-based routing is captured in data, not enforced at runtime.** The payment vendor
currently does not expose MCC codes in transaction data (confirmed with engineering
2026-04-16). Continue to capture `mcc_includes` and `mcc_excludes` accurately from source
clauses. The data will be correct when MCC routing is wired up. Do not silently drop MCC
metadata just because it can't be used yet.

**6. No invented facts.** If a value is unstated in the source, emit it as `null` with an
audit note. Never guess at standard values (e.g., don't assume FX fee is 2.5% if the source
doesn't say so). If a category cannot be mapped to the CardCoach taxonomy with certainty,
flag it. Do not force a fit. If caps, exclusions, or condition text are ambiguous, flag
them. Ambiguity is a signal, not a defect.

**7. One card, one delta.** Your output covers exactly the card named in the input. Do not
bleed into sibling products even if the same CMA covers several cards. A universal CMA
becomes N separate deltas (one per affected card), driven by one human reviewer at a time.

**8. Approved deltas hand off as SQL, one file per changed card.** (Settled 2026-06-10,
logged in `PIPELINE_AND_DECISIONS.md`.) Your output here is still the six-section delta —
conversion happens after human approval via `apply_delta.py`. The spec the conversion
targets: one `.sql` file per changed card per run, in a dated run folder, named
`YYYY-MM-DD__issuer-slug__card-slug.sql`, wrapped in `BEGIN`/`COMMIT`, with a comment
header carrying the audit metadata (source URLs, dates accessed, clause references,
confidence). Files assume `service_role` execution and touch the four V2 tables only.

### Inputs

**Input block 1 — current DB row set (JSON).** Shape:

```json
{
  "card_id": "ca_american_express_canada_cobalt_amex_credit_amex",
  "card_products": {
    "id": "ca_american_express_canada_cobalt_amex_credit_amex",
    "display_name": "American Express Cobalt Card",
    "issuer_id": "amex",
    "network_id": "amex",
    "reward_program_id": "membership_rewards",
    "point_program_id": "membership_rewards",
    "product_family": "Cobalt",
    "tier_normalized": "amex_credit",
    "tier_raw": "Credit Card",
    "application_status": "open",
    "availability_scope": "national",
    "available_provinces": [],
    "earn_unit_default": "points",
    "base_earn": 1,
    "base_rate_unit": "points_per_dollar",
    "annual_fee_cad": 191.88,
    "fx_fee_percent": 2.5,
    "scoring_status": "scoreable",
    "is_active": true
  },
  "earn_rates": [ /* rows */ ],
  "card_caps": [ /* rows */ ],
  "card_exclusions": [ /* rows */ ]
}
```

**Input block 2 — source snapshot(s).** One or more blocks of normalized text from issuer
pages or PDFs, each labeled with source metadata.

**Input block 3 — issuer pattern hint (optional).** Free-form note about the issuer's
documentation structure if non-obvious.

### Output format

Emit exactly these sections, in order, with headers matching verbatim.

#### 1) card_products delta

`card_products` has no validity columns. Changes are expressed as field-level updates on
the existing row, tracked in `versioning_metadata` jsonb if you include version trail data.
Emit either `no_change` or a JSON object with:
- `op`: `"update"` (field changes on an existing row), `"insert"` (newly added card), or `"deactivate"` (set `is_active = false` — reserved for cards that should disappear from the product entirely).
- `id`: the `card_products` primary key (text).
- `changed_fields`: array of field names that changed.
- `proposed`: the new values for those fields only (for `update`), or the full row (for `insert`).
- `source_evidence`: url, clause, quoted_value.

**Discontinued-card default (settled 2026-06-10):** emit an `update` setting
`application_status = 'closed'` and `scoring_status = 'load_only'`, leaving
`is_active = true`. The three flags are orthogonal — `application_status` answers "can you
apply," `is_active` answers "does it appear," `scoring_status` answers "can it rank."
`"deactivate"` is only for cards that should be hidden outright.

**Program conversions keep card identity** (settled 2026-07; e.g. an issuer migrating a
card to a new rewards program): emit an `update` on the existing `card_products` row —
never a new `id` — and turn earn rows over via rule 3 (expire-then-insert).

**Writable columns on `card_products`:** `id` (text, PK), `display_name` (text, NOT NULL),
`issuer_id` (FK to issuers — use `issuer_id`, not `issuer`), `network_id` (FK to networks),
`reward_program_id` (FK), `point_program_id` (nullable FK), `is_active` (bool, default
true), `product_family` (nullable), `tier_normalized` (constrained, nullable), `tier_raw`
(nullable), `application_status` (`open | closed | invitation_only | limited`, default
`open`), `availability_scope` (`national | regional | provincial`, default `national`),
`available_provinces` (text[], default `{}`), `earn_unit_default` (`points | cents`),
`base_earn` (numeric(10,4)), `base_rate_unit` (`points_per_dollar | cents_per_dollar |
percent_cashback`), `annual_fee_cad` (numeric(10,2), CAD), `fx_fee_percent` (numeric(5,2)),
`source_metadata` (jsonb), `versioning_metadata` (jsonb), `scoring_status` (`scoreable |
load_only`, NOT NULL, default `scoreable`).

`tier_normalized` allowed values: `standard`, `visa_classic`, `visa_gold`, `visa_platinum`,
`visa_infinite`, `visa_infinite_privilege`, `mastercard_standard`, `mastercard_world`,
`mastercard_world_elite`, `amex_credit`, `amex_charge`, `platinum`, `other`.

Example (fee change):

```json
{
  "op": "update",
  "id": "ca_american_express_canada_cobalt_amex_credit_amex",
  "changed_fields": ["annual_fee_cad"],
  "proposed": { "annual_fee_cad": 195.00 },
  "source_evidence": {
    "source_url": "…",
    "clause": "Disclosure Statement, Annual Fee section",
    "quoted_value": "Annual fee: $16.25 per month"
  }
}
```

#### 2) earn_rates delta

List of row-level operations. Each op is `no_change`, `expire_and_replace` (rate changed),
`insert` (new category added), or `expire` (category removed, no replacement). Apply rule 3
(expire-then-insert). Never `DELETE`.

**Writable columns on `earn_rates`:** `card_id` (FK), `basis` (NOT NULL, `base | category`
— if `base`, `category_id` must be NULL; if `category`, `category_id` must be non-NULL),
`category_id` (FK to categories, required when `basis = 'category'`), `earn_unit` (NOT NULL,
`cents | points`), `base_rate` (numeric(10,4), NOT NULL), `multiplier` (numeric(10,4),
default 1.0; `effective_rate = base_rate × multiplier` is derived, not a column),
`cap_monthly_cad` (nullable), `cap_annual_cad` (nullable), `valid_from` (date, NOT NULL,
default CURRENT_DATE), `valid_to` (nullable, NULL for active rows), `condition_type`
(constrained: `portal_only | preauthorized_only | merchant_list_only | mcc_defined |
account_bundle | other`), `condition_text` (nullable), `mcc_includes` (integer[]),
`mcc_excludes` (integer[]), `source_clause_reference` (nullable), `rate_unit` (constrained:
`points_per_dollar | cents_per_dollar | percent_cashback` — per-litre units →
`Unsupported_Benefits` instead), `earn_rate_type` (constrained, default `total`: `total` =
rate replaces base, `incremental` = rate stacks on top of base — read the source carefully,
"earn 4x on top of 1x base" wording is common), `display_label` (nullable, e.g. `"5x on
dining & drinks"`).

Do NOT emit `id`, `created_at`, or any computed field like `effective_rate` — those are
DB-owned.

Example op:

```json
{
  "op": "expire_and_replace",
  "current_row_id": "<uuid, if known>",
  "expire_sql": "UPDATE earn_rates SET valid_to = now() WHERE card_id = '…' AND category_id = '…' AND valid_to IS NULL;",
  "insert_row": {
    "card_id": "…",
    "basis": "category",
    "category_id": "dining",
    "earn_unit": "points",
    "base_rate": 1,
    "multiplier": 4,
    "rate_unit": "points_per_dollar",
    "earn_rate_type": "total",
    "display_label": "4x on dining",
    "condition_type": "category",
    "condition_text": "Eligible dining purchases in Canada, up to $2,500 per billing period",
    "mcc_includes": [5812, 5813, 5814],
    "mcc_excludes": [],
    "cap_monthly_cad": 2500,
    "cap_annual_cad": null,
    "valid_from": "2026-04-21",
    "valid_to": null,
    "source_clause_reference": "Earn Rates table, page 27",
    "source_url": "…"
  }
}
```

#### 3) card_caps delta

Same op vocabulary as `earn_rates`. Apply rule 3 (expire-then-insert).

**Writable columns on `card_caps`:** `card_id` (NOT NULL, FK), `category_id` (nullable; null
for caps across categories), `condition` (nullable, what triggers the cap, e.g.
`combined_spend_in_bonus_categories`), `cap_basis` (NOT NULL: `spend_cad | rewards_points |
transactions | unknown`), `cap_value` (numeric(12,2), NOT NULL), `cap_unit` (NOT NULL: `CAD
| points | transactions | percent`), `cap_period` (NOT NULL: `billing_cycle |
calendar_month | calendar_year | unknown`), `reset_rule` (nullable), `source_clause_reference`
(nullable), `valid_from` (date, default CURRENT_DATE), `valid_to` (nullable, NULL for active
rows).

Do NOT emit `id` or `created_at`.

#### 4) card_exclusions delta

`card_exclusions` has no validity columns. Changes are straightforward insert/delete against
the current row set. Emit either `no_change` or a list of ops: `insert` (new exclusion in
source), `delete` (exclusion removed — emit a DELETE by `id`), `update` (rewording of
description or condition on an existing row).

**Writable columns on `card_exclusions`:** `card_id` (NOT NULL, FK), `category_id`
(nullable), `condition` (nullable, e.g. `non_qualifying_purchases`,
`specific_merchant_exclusion`), `description` (NOT NULL, human-readable), `source_clause_reference`
(nullable).

Do NOT emit `id` or `created_at`.

#### 5) Unsupported_Benefits

Rows that cannot go into `earn_rates` because of enum or routing gaps. Same row shape as
`earn_rates` plus a `reason` field. Also used for any earn structure the current schema
can't yet represent (e.g. per-litre).

```json
[
  {
    "card_id": "ca_canadian_tire_triangle_mastercard",
    "category_id": "gas",
    "basis": "category",
    "earn_unit": "cents",
    "base_rate": 10,
    "rate_unit": "cents_per_litre",
    "condition_type": "merchant_list_only",
    "condition_text": "10¢/L off at Gas+ and Husky stations (World Elite tier)",
    "source_url": "…",
    "source_clause_reference": "Cardmember Agreement p.12",
    "reason": "rate_unit not yet supported: cents_per_litre"
  }
]
```

#### 6) Audit Notes

Bulleted list. Include: assumptions made (state each one); unclear items (and what would
resolve them); flags for human review; any `SOURCE_REJECTED:` lines; pattern observations
that might help future reverifications; and a confidence summary: **HIGH / MEDIUM / LOW**
with a one-line reason.

### Source metadata on every output row

Each row carries: `source_url`, `source_date_accessed`, `source_language` (`en-CA` or
`fr-CA`), `canada_evidence_type` (e.g. `domain_ca`, `currency_cad_in_doc`, `clause_ca`),
`source_clause_reference` (e.g. `"Section 4.2"`, `"Earn Rates table"`, `"Page 27"`).
**Missing source metadata is a hard fail — do not emit rows without it.**

### Worked examples

**Example 1 — No change**

```
### 1) card_products delta
no_change
### 2) earn_rates delta
all rows no_change
### 3) card_caps delta
all rows no_change
### 4) card_exclusions delta
no_change
### 5) Unsupported_Benefits
none
### 6) Audit Notes
- Source snapshot dated 2026-04-21 (product page + CMA).
- All earn rates, caps, fees, and exclusions match current DB row set.
- No material changes since last verification (2026-02-18).
- Confidence: HIGH — two independent sources (product page + CMA) agree.
```

**Example 2 — Earn rate change with matching cap update** — emit an `expire_and_replace`
op in section 2 (dining 5x → 4x) and a matching `expire_and_replace` in section 3 if the
cap also changed; sections 1, 4, 5 `no_change`/`none`; audit note states the CMA effective
date and confidence.

**Example 3 — Blocked per-litre row** — sections 1–4 `no_change`; section 5 emits the
Canadian Tire gas row with `reason: "rate_unit not yet supported: cents_per_litre"`; audit
note explains it's captured but blocked pending the enum extension, and to re-run once the
enum ships.

### Issuer pattern quick reference

For the 15 issuers in the current dataset, the document-hosting pattern determines how to
read snapshots:

| Issuer | Pattern | Read priority |
|--------|---------|---------------|
| Amex | per-product CMA | One CMA covers earn + caps + rewards + Quebec disclosures. Single-source diff sufficient. |
| RBC | universal agreement + product page | Product page = earn rates. Universal agreement = FX, fees, structural. Two-source diff. |
| TD | master CHA + per-card benefits guide | Benefits guide = earn rates + cap detail. Master CHA = fees + structural. Two-source diff. |
| Scotia | universal revolving credit agreement + product page | Product page drives earn; agreement drives structural. Two-source diff. |
| BMO | universal CHA + World Elite addendum | Product page drives earn. Addendum applies to World Elite tier only. |
| CIBC | universal CHA + per-product privacy disclosure | Product page drives earn. Privacy disclosure has FX/fees. |
| Rogers | universal CHA + per-card benefits landing | **Material change flag:** rewards restructured 2025 and 2026. Cohorts see different rates. Settled 2026-06-10: CardCoach represents **new-cardholder rates** (Feb 26, 2026 restructure); cohort disclosure is handled app-side. |
| MBNA | universal account agreement | Product page drives earn. TD subsidiary — shares some infrastructure. |
| Desjardins | grouped CMAs by product family | French-first issuer. EN version is a translation. One agreement covers 4–6 products. Quebec vs Quebec-resident agreements differ. |
| National Bank | personal/business agreements | Cashback program terms live separately per card. |
| Canadian Tire | universal cardmember agreement | Gas earn in `cents_per_litre` → `Unsupported_Benefits`. |
| PC Financial | universal CHA + disclosure summary | EQB acquisition in progress — watch for agreement version changes post-close. Gas earn in `points_per_litre` → `Unsupported_Benefits`. |
| Simplii | single card | All docs on product page. |
| Tangerine | single card | User-selected categories → `scoring_status = 'load_only'`. |
| HSBC | discontinued | All cards migrated to RBC successor products. Do not reverify directly. Settled 2026-06-10: `application_status = 'closed'`, `is_active = true` (unless the card should be hidden), `scoring_status = 'load_only'`. |

### Invocation

Run with this user message structure:

```
[CURRENT DB ROW SET]
<JSON block as described in Input block 1>

[SOURCE SNAPSHOT(S)]
<One or more snapshot blocks as described in Input block 2>

[ISSUER PATTERN HINT]
<optional, see Input block 3>

Produce the six-section delta.
```

## ===== END PROMPT =====

---

## Versioning

Bump this prompt's version number when any non-negotiable rule or output-spec column
changes. Record what changed and why in the changelog below.

### Changelog

**1.3 (2026-07-16)** — Relabel of the same-day rebuild. The rebuild was written as
a reconstruction while the June v1.2 was believed lost; the June original then
surfaced at repo root via the 2026-07-16 sync (preserved at commit `1a55114c` and
in `attic/duplicates_2026-07-16/governance/STAGE3_PROMPT.md`). This file is that
rebuild, relabeled. Relative to v1.1 it bakes in the settled 2026-06-10 set (rule
8 SQL handoff spec, the five open questions resolved in place, the discontinued
three-flag default, the Rogers cohort settlement) plus the post-June items: the
program-conversion identity rule, rule 2 restated as V1-is-dead (2026-07-16
ruling), and the PCF pending note. The 1.2 entry below is carried verbatim from
the recovered original; diff this file against `1a55114c:STAGE3_PROMPT.md` for the
full comparison.

**1.2 (2026-06-10)** — Handoff format settled (SQL per card, Alex's spec) and added as a
section. RLS write path fixed to service_role. Discontinued semantics finalized
(closed / is_active / load_only). Explicit ban on emitting `scoring_status='exclude'`.
All five open questions resolved and removed.

**1.1 (2026-04-22)** — Column-accuracy pass against the live schema (database as of
2026-04-15, migration 0043). Output spec is now column-accurate for all four V2 write
targets. Added missing NOT NULL columns previously absent (`earn_rates.basis`,
`earn_rates.earn_unit`, `card_caps.cap_basis`). Added `earn_rates.earn_rate_type` and
`earn_rates.display_label` (Mike's request). Corrected expire-then-insert scope: rule 3
applies to `earn_rates` and `card_caps` only. Fixed `card_products` naming (PK is `id`, FK
is `issuer_id`). Removed computed `effective_rate` from examples. Added `card_exclusions` as
a distinct output section. Added full column-reference tables per section. Added
`tier_normalized` allowed-values list. Added HSBC discontinued guidance
(`application_status = 'closed'`, not an invented value). Added `is_active = false` pattern
for retired products.

**1.0 (2026-04-21)** — Initial version. Baked in engineering decisions from 2026-04-16: V1
dead, caps expire-then-insert, per-litre blocked, MCC routing deferred. Includes 15-issuer
pattern reference.

---

## Former open questions — resolved 2026-06-10

Resolved with Alex and logged in `PIPELINE_AND_DECISIONS.md` (2026-06-10). The
`WORKING_NOTES.md` #1 mirror of these questions is superseded by this list.

1. **RLS write path** — assume `service_role` execution for all four V2 tables (explicit
   `_service` policies on `card_caps`/`card_exclusions`; `BYPASSRLS` covers
   `card_products`/`earn_rates`).
2. **SQL file format** — one file per changed card per run, not per table.
3. **Filename + wrapping** — dated run folder; `YYYY-MM-DD__issuer-slug__card-slug.sql`;
   plain `BEGIN`/`COMMIT`. Savepoints and idempotent guards were not part of the settled
   spec.
4. **Audit metadata** — comment header inline in the SQL file; no `.md` sidecar.
5. **HSBC / discontinued semantics** — three orthogonal flags: `application_status =
   'closed'`, `is_active = true` unless the card should be hidden, `scoring_status =
   'load_only'`.
