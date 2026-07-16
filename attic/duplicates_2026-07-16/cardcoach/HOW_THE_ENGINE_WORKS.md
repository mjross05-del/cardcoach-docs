# How the CardCoach Engine Works

**The data model and pipeline, in plain terms.** This is the file the old rules kept
asking for and couldn't find. It now exists. It changes only on real architecture
changes — not casually.

Last updated: 2026-06-02 · Owner: Mike
Built from: the live Supabase schema (`SCHEMA.md`) + the reverification pipeline docs.

---

## The shape of it

CardCoach answers one question: *"Which of my cards should I use for this purchase?"*
To answer it truthfully, three layers have to hold:

1. **The data** — verified card facts (earn rates, caps, exclusions, point values), held in Supabase.
2. **The pipeline** — keeps that data current by detecting when issuers quietly change things. (Full detail in `PIPELINE_AND_DECISIONS.md`.)
3. **The scoring engine** — Alex's domain, in the app. Reads the verified data and ranks cards. Not documented here beyond how it reads the data.

This file covers layers 1 and 2. The app/scoring layer is Alex's.

---

## The database (layer 1)

A live Supabase Postgres database. **48 tables, 18 views, 43 migrations** as of the
2026-04-15 schema generation. The authoritative table-by-table reference is `SCHEMA.md` —
this section explains how the pieces fit, not every column.

### V1 vs V2 — read this carefully

The schema contains **two generations of card tables that physically coexist**, but only
one is live:

- **V1 (dead):** `cards`, `card_earn_rates`, `offers`. Original `0001_initial` design. **No production code path reads from these.** Confirmed dead by Alex, 2026-04-16. They still exist in the schema for history; they are not maintained and not read.
- **V2 (live):** `card_products`, `earn_rates`, `card_caps`, `card_exclusions`, and the `offer_*_v3` scoping tables. **This is the only production path.** Everything new writes here.

> If anyone proposes "dual-writing to V1 just in case," the answer is no — see the
> 2026-04-16 decision. V1 coming back would be a material architecture change, not a flip.

### The core V2 tables

| Table | Holds | Key behavior |
|-------|-------|--------------|
| `card_products` | One row per card (the canonical product). | Links to issuer, network, reward program, point program. |
| `earn_rates` | How much a card earns, by category. | Versioned (`valid_from`/`valid_to`). MCC include/exclude captured. |
| `card_caps` | Spend caps on earn rates. | **Expire-then-insert, never delete.** Versioned. |
| `card_exclusions` | What's excluded from earning. | No versioning — straight insert/delete/update. |
| `issuers`, `networks` | Taxonomy. | 15 issuers currently supported. |
| `reward_programs`, `point_programs` | Rewards program taxonomy. | |
| `point_valuations` | What points are worth (CPP). | Snapshot, tiered, confidence-flagged. **Not "live" values.** |
| `benefits`, `benefit_scopes` | Card perks. | |
| `mcc_category_mappings` | Maps merchant category codes → categories. | Captured, see runtime note below. |
| `merchant_entities` + aliases/places | Canonical merchant identity. | |
| `i18n_strings` | Bilingual (EN/FR) string storage. | French infrastructure exists; FR data largely unfilled. |

User-side spine: `profiles`, `user_cards`, `user_preferences`, `transactions`,
`user_spend_snapshots`, `card_requests`. This is the per-user wallet and activity layer.

Export views (`export_cards`, `export_card_earnings`, `export_point_valuations`, etc.)
are the read surfaces the app consumes. `v_active_*` views filter to currently-valid rows
by date.

### Two behaviors that aren't obvious from the schema

- **Versioning by validity, not deletion.** `earn_rates` and `card_caps` carry `valid_from`/`valid_to`. When a rate or cap changes, the old row is *expired* (set `valid_to = now()`) and a new row inserted. History is preserved. The `v_active_*` views show only what's current. **Never delete-and-replace.**
- **MCC routing is captured but not enforced.** `earn_rates` stores `mcc_includes`/`mcc_excludes` accurately, but the app does **not** route on MCC at runtime — the current payment vendor doesn't expose MCC codes in transactions. The data is kept correct so routing can light up the day that vendor gap closes, with no backfill needed.

---

## The pipeline (layer 2) — short version

Full operational detail lives in `PIPELINE_AND_DECISIONS.md`. The one-paragraph version:

A three-stage system keeps the 95-card dataset accurate by catching issuer changes:

1. **Watch** — a registry (`card_sources_seed_enriched.csv`) of official issuer URLs.
2. **Detect** — a local Python fetcher visits each URL monthly, compares to last month's text snapshot, and writes a change report.
3. **Update** — when a real change is flagged, a human feeds the new source text into a structured extraction prompt that produces a field-level delta for Alex to apply as SQL.

It runs locally, costs nothing, touches only issuer pages (never affiliate data), and
writes only to the V2 tables. Status: **infrastructure complete, first end-to-end run not
yet done.**

---

## What is NOT live (don't describe these as working)

- **Offer stacking** — `stack_rules` and `offer_incompatibilities` tables exist; the logic is designed/passed-through but **not wired into the V2 production scoring path.**
- **Channel-aware scoring** — designed, not active.
- **MCC-based routing** — data captured, runtime disabled (vendor gap, above).
- **Live/real-time point values** — `point_valuations` is a dated snapshot. Use "current" or "as of," never "live."
- **French source verification** — the i18n infrastructure exists, but FR-CA source rows are blank placeholders, not verified data.
- **Welcome bonuses** — not in the verified dataset at all yet. Open question whether they get their own table.

---

## How a fact gets from an issuer to a recommendation

```
Issuer publishes / changes a page
        │
        ▼
[Stage 1] URL is in the registry  ──────────  card_sources_seed_enriched.csv
        │
        ▼
[Stage 2] Monthly fetcher detects the change  ─  local Python, text-diff, change report
        │
        ▼
[Stage 3] Human + extraction prompt produce a field-level delta  ─  reviewed, issuer-verified
        │
        ▼
Alex applies the delta as SQL (expire-then-insert)  ─────────────  V2 tables in Supabase
        │
        ▼
Export views surface current rows  ──────────────────────────────  v_active_* / export_*
        │
        ▼
App scoring engine reads verified data → ranks the user's cards   ─  Alex's domain
```

Every arrow that writes data passes through a human review gate. Nothing auto-writes to
the database.

---

*Architecture changes get logged in `PIPELINE_AND_DECISIONS.md`, then reflected here.
This file should never drift ahead of a real, decided change.*
