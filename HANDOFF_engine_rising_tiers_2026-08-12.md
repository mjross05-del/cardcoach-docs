# ENGINE HANDOFF — rising spend tiers (option A) — 2026-08-12

Filed by the apply-loop session, 2026-08-12. Source: verify run `bc3f3545` (RBC, 2026-08-12), queue rows `14756c08` / `1607e61c`. Everything below is read-only introspection of live `hrzpznlpmxxrbtwskacu` plus the mounted repo at `CardCoachv2/mobile_app_codebase`. **No DB writes and no code changes were made by this session.**

You are being asked to implement **option (a)** from the RBC Cash Back ruling: teach the engine to express an earn rate that *rises* after a spend threshold. Today the engine can only express rates that *fall*. Read §3 before estimating — there is a blocking data dependency that is easy to miss and will silently produce under-credit if you skip it.

---

## 1. The card fact

`ca_rbc_cash_back_standard_mastercard` (RBC Cash Back Mastercard, $0 fee, `scoring_status='scoreable'`). Issuer wording, dual-sourced, `verify.fact_checks` `9a4e2604` (base) and `e956fdba` (grocery), evidence `225f9f22` + `0d0bf3e0`:

- **Non-grocery — RISING.** `(0.5% Cash Back Credit) in Net Purchases you make (including pre-authorized bill payments), other than Grocery Store Purchases, up to a maximum of $6,000 … for a maximum Cash Back Reward of $30.00 per Annual Period` then `in excess of $6,000 in Net Purchases (other than Grocery Store Purchases) per Annual Period, unlimited` at 1%.
- **Grocery — FALLING.** 2% on Grocery Store Purchases (MCC 5411) `up to a maximum of $6,000 … for a maximum Cash Back Reward of $120.00 per Annual Period`, then 1% unlimited.

Two **separate** $6,000 buckets — one for grocery, one for everything else. Do not pool them.

Live DB today: one base row `7e7c6dfe` at a flat 1% uncapped, one grocery row `f75af480` at 2% uncapped. `card_products.base_earn` is NULL.

Interim data state (decided by Mike 2026-08-12, pending apply): the grocery row gets `cap_annual_cad = 6000.00` (queue `1607e61c` — falling tier, already expressible, verified correct); the base row **stays at flat 1%** with `base_earn` set to `1.0000`, accepting a bounded over-credit of at most $30/yr, because the rising tier is not expressible. Your change is what eventually supersedes that compromise.

---

## 2. Why it does not fit today — with code cites

All paths below are relative to `CardCoachv2/mobile_app_codebase`.

**2.1 Caps are ceilings, never floors.** `packages/engine/src/v2/earnMath.ts` → `computeCapStatus()` (~L254–350) derives `eligibleSpendCents` as spend remaining *under* `capMonthlyCents`/`capAnnualCents`. There is no concept of spend that must be exceeded before a row applies.

**2.2 A second `total` row in the same slot is silently dropped.** `combineEarnRates()` (L137–192) partitions rows into `totals` and `increments`, then picks a single `primary` — the highest `effectiveRowRate` among `totals` (L156–166). The base slot then contributes only `[primary, ...increments]` (L444–447). So the obvious naive modelling — a 0.5% row capped at $6,000 alongside a 1% row — resolves to primary = the 1% row, the 0.5% row is discarded entirely, and you get today's flat 1% plus a misleading orphan row in `earn_rates`.

**2.3 Making the second row `incremental` is worse, not better.** Increments are *additive over base* (category slot L581–583 makes the "don't subtract base twice" point explicitly). 0.5% total capped + 1% incremental uncapped = 1.5% on the first $6,000 and 1% after — a bigger error than the one you are fixing.

**2.4 What already works, and must keep working.** Falling tiers are correct today and the catalog is full of them (BMO Air Miles WE/standard accelerators, BMO CashBack WE grocery/gas/transit, BMO Eclipse VIP, TD Aeroplan family, MBNA). Mechanism: base earn is computed on the **full** purchase amount, and a category `total` row contributes only its *excess over base*, clipped by its own cap — so above a cap, spend keeps earning the base rate. Asserted by the existing test at `packages/engine/test/earnMathV2.test.ts:290–322` (1% base on the whole $100 + 4% bonus on only the $50 under cap = 300 cents). Do not regress this.

---

## 3. BLOCKING DEPENDENCY — there is no spend bucket a base-slot floor could read

This is the item that makes option (a) more than a two-column migration.

- `computeCapStatus()` reads prior spend from `user_spend_snapshots`, matched by `(cardId, categoryId)` or `(cardId, poolId)` (`findSnapshot`, ~L234–252).
- `public.user_spend_snapshots.category_id` is **NOT NULL**. Live rows exist only for real categories (`grocery` 12, `dining` 12, `coffee_fastfood` 2, `travel` 1). There is no `null`/`__all__` bucket and no "everything except grocery" bucket.
- The engine already admits this in a comment at L422–425: *"base caps track against the whole-card spend which has no snapshot bucket yet, so prior spend is treated as 0 — the cap still clips single purchases that exceed it instead of being silently ignored."*

Consequence, and the reason this matters more for floors than for ceilings: **a missing snapshot degrades a ceiling safely and a floor unsafely.** With prior spend = 0, a capped row stays fully eligible (best rate, mild over-credit on a single huge purchase). With prior spend = 0, a *floored* row is never eligible at all — the 1% tier would never activate and every RBC non-grocery recommendation would be scored at 0.5%, i.e. **half the true rate**. That is a worse error than the $30/yr over-credit this project is trying to remove.

So the work is: floor semantics **plus** a non-grocery (or whole-card) spend bucket, **plus** an explicit decision about what to assume when no snapshot exists. See §7 decision D2.

---

## 4. Recommended design

### Option A — spend windows on earn rows (recommended)

Generalise a row's applicability from a ceiling to a half-open window `[floor, ceiling)` over cumulative period spend.

- New nullable columns on `public.earn_rates`: `floor_monthly_cad numeric`, `floor_annual_cad numeric`. Same units convention as the existing caps — **dollars in the DB, cents in the engine** (confirm: `cap_annual_cad` reads `100000.00` for TD Aeroplan's $100k; `apps/mobile/src/services/api.ts:772–775` multiplies by 100; `supabase/functions/cap-progress-v1/index.ts:535` does `Math.round(Number(er.cap_annual_cad) * 100)`).
- New contract fields `floorMonthlyCents` / `floorAnnualCents` in `zEngineEarnRateV2`.
- `computeCapStatus()` becomes window arithmetic: eligible spend for this purchase = length of the overlap between `[priorSpend, priorSpend + amount]` and `[floor, ceiling)`. With `floor` null/0 this is byte-identical to today's behaviour — keep that path literally unchanged so uncapped and falling-tier cards produce identical output (see §6).
- Model RBC's base slot as two rows with **disjoint** windows: 0.5% with `floor_annual_cad = null, cap_annual_cad = 6000`, and 1% with `floor_annual_cad = 6000, cap_annual_cad = null`.

The one subtlety: two `total` rows in the same slot still hit the primary-selection collapse in §2.2. Two ways out —

- **A1 (smaller diff):** mark the upper-tier row `earn_rate_type='incremental'` so it joins `baseContributors` without competing for primary. Because the windows are disjoint the rows never both apply, so "incremental" never actually adds on top and the arithmetic is right. Requires a validation guard (§5.4) or it is a footgun for whoever writes the next tiered card.
- **A2 (more honest, bigger diff):** allow multiple `total` rows when their windows are disjoint, and make both slots sum all window-eligible totals rather than picking one. Touches `combineEarnRates()` and the cap-aware primary selection in the category slot (L532–558). Prefer this if the §5.1 sweep shows rising tiers are common.

Recommendation: **A2 if the sweep finds more than one or two rising cards, A1 otherwise** — and if you take A1, land the validation guard in the same PR.

### Option B — a tiers table

A `earn_rate_tiers` child table (`earn_rate_id`, `from_cad`, `to_cad`, `rate`). Cleanest data model, worst blast radius: every consumer that reads `earn_rates` flat would need to learn about tiers. Not recommended for this card. Revisit only if tiered structures become the norm rather than the exception.

---

## 5. Work items

**5.1 Sweep first — size the problem.** Before writing code, find every other rising structure in the catalog. Falling tiers are already correct; only rising ones are broken. Start from:

```sql
select card_id, basis, category_id, base_rate, earn_rate_type, cap_annual_cad, condition_text
from public.earn_rates
where valid_to is null
  and (condition_text ilike '%in excess of%' or condition_text ilike '%thereafter%'
       or condition_text ilike '%after the first%' or condition_text ilike '%once you%');
```

Read the hits by hand — the same phrasings appear in falling tiers too, so the text match is a candidate list, not an answer. The RBC Cash Back family siblings were already flagged for re-check in apply session `2a25761b` (2026-08-11) and are the most likely additional hits.

**5.2 The duplicated engine file.** `packages/engine/src/v2/earnMath.ts` and `supabase/functions/_shared/engine/v2/earnMath.ts` are **byte-identical** (both md5 `46157ffbd1dc741963268ed9f925f915`) — the Deno edge runtime gets a copy. Change both or the web/edge paths will diverge from mobile. Check for a sync script before hand-copying.

**5.3 Files in scope.**

| File | Change |
|---|---|
| `packages/engine-contracts/src/engineEarnMathV2.ts` (L25–52) | add `floorMonthlyCents` / `floorAnnualCents` to `zEngineEarnRateV2` |
| `packages/engine/src/v2/earnMath.ts` | `computeCapStatus()` window arithmetic; base slot L418–485; category slot L500–620 if A2 |
| `supabase/functions/_shared/engine/v2/earnMath.ts` | identical copy of the above |
| `supabase/migrations/<ts>_earn_rates_spend_floors.sql` | new columns + non-negative checks + a `floor < cap` check. Latest migration is `20260802170000`; follow `YYYYMMDDHHMMSS_snake_name.sql` |
| `apps/mobile/src/services/api.ts` (~L759–775) | select the new columns, ×100 to cents |
| `apps/web/src/lib/productData.ts` (L72, L203, L216) | same |
| `apps/admin/src/lib/adminConfig.ts` (L265, ~L324) | expose the columns in the admin grid |
| `supabase/functions/cap-progress-v1/index.ts` (L265–268, L534) | cap-progress UI must not report a floored row as "0 of $6,000 used" |
| `cardcoach-docs/HOW_THE_ENGINE_WORKS.md` (§ caps, L63–85) | engine truth doc — update in the same PR |

**5.4 Validation guard.** Reject (in the migration as a constraint where possible, otherwise in the engine with a `warnings.push`) two rows in the same slot whose windows overlap. Overlapping windows double-count; that is the failure mode most likely to escape review.

**5.5 The spend bucket (§3).** Decide and implement how cumulative non-grocery spend is tracked for a base-slot floor. Touches `maintain_user_spend_snapshots` (a `SECURITY DEFINER` trigger function — note it had its ACLs hardened 2026-08-11, `verify.write_audit` `728310dc`). Options: a reserved `category_id` sentinel for whole-card spend plus a subtraction for grocery, or a real "non-grocery" bucket. This is the long pole — scope it before promising a date.

---

## 6. Acceptance tests

Add to `packages/engine/test/earnMathV2.test.ts` (2,228 lines, vitest; `pnpm --filter @cardcoach/engine test`). RBC modelled as base 0.5% `[0, $6k)` + 1% `[$6k, ∞)`, grocery 2% `[0, $6k)`:

| Scenario | Prior spend | Purchase | Expected |
|---|---|---|---|
| Non-grocery, full year | — | $10,000 cumulative | $70 (0.5%×6,000 = $30, then 1%×4,000 = $40) |
| Same year under today's flat 1% | — | $10,000 | $100 — the $30 over-credit, i.e. the bound Mike accepted |
| Non-grocery, below floor | $2,000 | $1,000 | $5 (0.5%) |
| Non-grocery, spanning the boundary | $5,000 | $2,000 | $15 ($1,000 at 0.5% + $1,000 at 1%) |
| Non-grocery, above floor | $8,000 | $1,000 | $10 (1%) |
| Grocery, full year | — | $10,000 cumulative | $160 (2%×6,000 = $120, then base 1%×4,000 = $40) |
| Grocery and non-grocery buckets independent | $6,000 grocery | $1,000 non-grocery | $5 — grocery spend must not push non-grocery past its floor |
| No snapshot present | none | $1,000 non-grocery | per decision D2 — assert whichever default is chosen, explicitly |

Regression bar: the whole existing suite green, `test/golden/qa-005` fixtures byte-identical for every card with no floors set, and the L290–322 falling-tier test untouched and passing.

---

## 7. Decisions for Mike (do not guess)

- **D1 — A1 vs A2 (§4).** Depends on the §5.1 sweep result. Bring the sweep to him with a count.
- **D2 — no-snapshot default for a floored row.** Assume the floor is *unmet* (conservative, under-credits, current behaviour for a missing bucket) or *met* (optimistic, over-credits)? Neither is safe; the third path is to suppress the card from ranking when a floored row has no snapshot and say so in the explanation. This is a product call, not an engineering one.
- **D3 — scope of the spend-bucket work (§5.5).** Whole-card bucket plus subtraction, or a dedicated non-grocery bucket.

---

## 8. Rules that bind this work

From `PROJECT_RULES.md`: rule 2 (`HOW_THE_ENGINE_WORKS.md` is engine truth — update it, do not let it drift), rule 4 (V2 tables only), rule 7 (never invent card facts — every rate and threshold here traces to the clause in §1), rule 9(a) (snapshot before any DB write, and secure the snapshot in the same transaction — `ENABLE ROW LEVEL SECURITY` plus `REVOKE ALL … FROM anon, authenticated`; an unsecured snapshot has already cost one remediation migration).

Also: `verify.apply_queue` row `14756c08` stays `needs_input` until this lands. When it does, it is the apply loop's job to write the corrected earn rows — not yours. Leave `public.*` card data alone; your lane is engine code, contracts, migration DDL for the new columns, and the spend-bucket plumbing.
