# ENGINE REPORT — rising spend tiers landed (option A) — 2026-08-12

Implements HANDOFF_engine_rising_tiers_2026-08-12. Decisions D1/D2/D3 taken by Mike this session (recorded below). Engine, contracts, migration DDL, loader plumbing, tests, and docs are done; **no `public.*` card data was touched and no DB writes were made** — the corrected RBC rows remain the apply loop's lane (queue `14756c08`).

**SUPERSEDED IN PART (same day, see ADDENDUM below):** on Mike's instruction the follow-up findings were then resolved in a second pass — both migrations are now APPLIED to live, and the NBC/RBC-WE rows were remodelled under rule 9. Still true: the RBC *standard* card's data is untouched and queue `14756c08` remains the apply loop's lane.

## 1. Sweep result (§5.1)

46 text hits, hand-reviewed. **Strictly rising: 1 card — `ca_rbc_cash_back_standard_mastercard` itself.** Adjacent findings, not engine work:

- `ca_rbc_cash_back_mastercard_world_elite_mastercard` — falling (1.5%→1%), expressible today, but its +0.5% tier rides a `category_id='general'` incremental row: the bonus never applies to grocery/dining/etc. purchases and its $25k pool tracks only 'general' spend instead of all Net Purchases. Recommend a re-check ticket for the apply loop (sibling flag from apply session `2a25761b` confirmed).
- `ca_national_bank_rewards_mastercard_platinum/world_elite` — falling tiers modelled as two `total` rows per category slot with **no caps**; the "thereafter" row is silently dropped (§2.2), so both cards over-credit grocery/dining beyond the monthly threshold today. The new window machinery can express them once someone models the whole-card *monthly* bucket; their threshold ("gross monthly purchases across ALL categories") is not yet representable. Follow-up, not blocking.

## 2. Decisions

- **D1 = A2 + `category_excludes`.** A1 as sketched is arithmetically unworkable: `combineEarnRates` sums increments into the slot's nominal rate, and the base slot's nominal rate is what every category row's bonus subtracts (`earnMath.ts`). A1 makes RBC's nominal base 1.5% → grocery full-year prices $130, not the §6 table's $160. Under A2 the nominal primary stays the highest total — the 1% terminal row — so subtraction and display stay right with no special-casing.
- **D2 = floor met (optimistic) when the bucket is entirely absent.** Symmetric with caps (missing bucket = nothing consumed); snapshot-less contexts (web ranking passes `spendSnapshots: []` always; brand-new users) price RBC at flat 1% — exactly the interim compromise, never worse. Implemented as an assumed prior at the slot's highest floor so the 0.5% sibling prices as exhausted (no double-pay). A bucket **present with $0** is real data: floor genuinely unmet, 0.5% applies.
- **D3 = loader-synthesized annual buckets.** `scoring.ts` sums the user's monthly `user_spend_snapshots` over the calendar year (same approximation cap-progress documents), **only for cards carrying floored rows**: per-category annual buckets + a base-slot bucket (`category_id` null) excluding the union of the card's floored base rows' `category_excludes`. No schema change, the ACL-hardened `maintain_user_spend_snapshots` trigger is untouched, no rule-9(a) exposure. Snapshots gained an optional `period` (`monthly`|`annual`); legs prefer their own period and fall back to the legacy period-less row, so every no-floor card's reads are unchanged.

## 3. Target modelling for the apply loop (queue `14756c08`)

Four rows, each tracing to one clause of fact_checks `9a4e2604`/`e956fdba` (dollars in DB; engine reads cents):

| basis | category | rate | window (annual) | category_excludes |
|---|---|---|---|---|
| base | — | 0.5 | cap_annual_cad 6000 | {grocery} |
| base | — | 1.0 | floor_annual_cad 6000 | {grocery} |
| category | grocery | 2.0 | cap_annual_cad 6000 | — |
| category | grocery | 1.0 | floor_annual_cad 6000 | — |

Notes: the two $6,000 windows track **separate** buckets (non-grocery base bucket vs grocery bucket) — never pooled. The interim state (flat 1% base + grocery 2% capped, queue `1607e61c`) prices identically under the new engine until these rows land: floors/excludes absent = all new paths dormant. Grocery's "then 1% unlimited" clause becomes its own floored row because both base tiers are "other than Grocery Store Purchases" — base pays nothing on grocery purchases, and the grocery slot carries its full schedule. Rule 9 conditions (snapshot+secure, delta file, expire-then-insert, guards) apply to that write as usual.

## 4. What changed

- `supabase/migrations/20260812210310_earn_rates_spend_floors.sql` — `floor_monthly_cad`, `floor_annual_cad`, `category_excludes` + non-negative and floor<cap checks + both views recreated (columns appended). **Written, not applied** *(superseded: applied in the same-day second pass, see ADDENDUM)*. §5.4's cross-row overlap guard is engine-side by design: same-slot overlapping totals exist legitimately when merchant-scoped (Scotia Gold grocery pair) and NBC's broken pair would violate a DB constraint on day one.
- `packages/engine-contracts/src/engineEarnMathV2.ts` (+ edge copy) — `floorMonthlyCents`/`floorAnnualCents`, `categoryExcludes`, snapshot `period`.
- `packages/engine/src/v2/earnMath.ts` (+ edge copy, md5-identical: `5b2d46aa…`) — `computeCapStatus` window arithmetic `[floor, cap)` (floor-less legs reduce to the old formula exactly); period-aware snapshot lookup with legacy fallback; D2 assumed priors; A2 disjoint-total contributors in both slots; category-exclusion filter with zero-base path; §5.4 overlap warning (fires only when a floor is involved — NBC/Scotia stay silent); floored slots' cap-status reporting prefers capped rows and the base "capped" warning uses tier coverage (floor-less slots keep the old test verbatim).
- `supabase/functions/_shared/scoring.ts` — columns selected + mapped to the engine; annual bucket synthesis (gated to floored cards; fails open to D2 with a warning).
- Readers: `apps/web` (`productTypes`, `productData`, `serverRanking`), `apps/mobile/src/services/api.ts`, `apps/admin/src/lib/adminConfig.ts` (grid fields). `cap-progress-v1`: invariant comment only — its query already admits only capped rows, so floor-only rows can never render as "0 of $X used".
- Docs (rule 2): `cardcoach-docs/HOW_THE_ENGINE_WORKS.md` § caps + repo `docs/dev_notes` copy; `cardcoach-docs/SCHEMA.md` earn_rates columns.

## 5. Verification

- `pnpm --filter @cardcoach/engine test`: **133/133 green**, including 13 new ENG-floors tests covering every §6 scenario (non-grocery $70 full-year, $30 bound documented, below/spanning/above floor, grocery $160, bucket independence both directions, D2 both defaults, coverage warning suppression, §5.4 guard, display rates).
- Golden pack `verify:qa-005`: **8/8 byte-identical** (no floors set anywhere → regression bar met).
- Falling-tier test (`earnMathV2.test.ts` "partial cap - blended bonus", the §2.4 anchor): untouched, passing.
- Duplicated files: engine pair and contracts pair each md5-identical after sync (no sync script exists in the repo — hand-copied, verified).
- Typecheck: contracts clean; engine shows 2 pre-existing errors in `test/golden/qa-005/runFixture.ts` that reproduce identically on pristine HEAD in a fresh Linux install — environmental, not from this change. (Tests ran from a scratch install because the repo's `node_modules` are macOS-native; the repo tree was not reinstalled.)

## 6. Follow-ups (not started, in suggested order)

1. Apply loop: write the four RBC rows (§3) and flip `14756c08`; ~~re-check the RBC WE 'general'-row modelling~~ *(done in ADDENDUM)*.
2. ~~NBC Platinum/WE: model the whole-card monthly bucket, then express their falling tiers as windowed rows~~ *(done in ADDENDUM — `window_bucket='card'`)*.
3. Optional one-liner (product sign-off needed): remove the floored-card gate on annual bucket synthesis so annual **caps** (TD Aeroplan $100k etc.) also read true YTD instead of current-month — a correctness improvement, gated today purely to keep this change's blast radius at zero.

---

# ADDENDUM — follow-up findings resolved (same day)

Mike's instruction: "Address and resolve those findings." Both §1 adjacent findings and follow-up 1 (RBC WE portion) + follow-up 2 are now DONE, under rule 9 write authority.

## What was found on inspection

- The NBC tier pairs were **already correct in rate values** — the sweep note "identical base_rate" missed `multiplier` (Platinum 0.6667×2.9999≈2 pts/$ vs ×2.2499≈1.5; WE 1×5 vs 1×2). The defect was purely the missing window boundary and the dropped second row. No rates were invented; the remodel adds windows to verbatim copies of the verified rows.
- NBC's boundary is measured over **gross monthly purchases across ALL categories** (verify.fact_checks 2026-07-27, both cards) — not the bonus category's own spend. That needed one more engine concept.

## Engine additions

- **`window_bucket` on earn_rates** (engine `windowBucket`, migration `20260812210325_earn_rates_window_bucket`, applied): `NULL`/`'category'` = the row's own bucket (legacy, unchanged); `'card'` = the whole-card bucket (snapshot categoryId null). Two totals combine only when their windows read the SAME bucket. Loader synthesizes a whole-card current-month bucket for cards carrying such rows.
- **D2 generalized to falling tiers** (same principle, RBC outcome unchanged): the missing-bucket assumed prior is now the start of the highest-rate windowed row's window — a rising pair still defaults to its terminal rate (RBC std: 1%), a falling pair to its headline rate (NBC: 5 pts/$), matching legacy no-snapshot behaviour in both shapes.
- Loader gate for annual buckets widened to include base-slot rows with an annual cap (RBC WE's $25k consumption). No pre-existing card matches, so nothing else changes.

## Data applied (live, rule 9 discipline)

Delta: `cardcoach-docs/deltas/2026-08-12__earn_rates__nbc_tier_windows_and_rbc_we_base_incremental.sql` — executed verbatim, single transaction, all guards passed. Snapshot `earn_rates_snapshot_20260812` (570 rows) secured in the same transaction (RLS enabled, zero anon/authenticated grants — verified). Expiry uses `valid_to = current_date − 1` because the reference loader admits `valid_to >= asOfDate`; expiring "today" would have double-counted replacements for a day (and doubled the RBC WE bonus on 'general' purchases).

- **NBC Platinum + WE** (8 rows expired → 8 re-inserted): grocery/dining tier pairs now carry `cap_monthly_cad`/`floor_monthly_cad` at $1,000 (Platinum) / $2,500 (WE) with `window_bucket='card'`. Engine now prices: full rate under the threshold, blended across it, after-rate beyond — and non-grocery card spend correctly pushes the boundary. Previously both cards scored grocery/dining at the top rate with no limit.
- **RBC WE** (1 row expired → 1 re-inserted): the +0.5% incremental moved from `category_id='general'` to the base slot, values verbatim (0.5%, cap $25,000/yr). The card now prices 1.5% on ALL Net Purchases under $25k YTD, blended across, 1% beyond — per fact_check 9c5b9707 (2026-08-12, dual evidence). Previously the bonus applied only to 'general' purchases and its cap tracked only 'general' spend.

Both migrations were applied via MCP with matching local files in `supabase/migrations/` (rule 9e).

## Verification

- Engine suite **143/143** (10 new tests: NBC under/boundary/after/cross-category-push/no-snapshot/month-rollover + legacy-shape unchanged; RBC WE all-categories/blend/exhausted/no-snapshot). Goldens **8/8 byte-identical**. Duplicated engine + contracts pairs md5-identical.
- Live post-state verified by independent selects (slot shapes, boundary equality, no residual 'general' rows).
- `apps/web`, `apps/admin`, `apps/mobile` typecheck clean (package dists rebuilt); edge TS parses.
- Docs updated: HOW_THE_ENGINE_WORKS (both copies, window-bucket section), SCHEMA.md.

## Still open (unchanged from §6)

1. Apply loop: the RBC **standard** card's four tiered rows (§3) and queue `14756c08` — engine ready, data intentionally left in the interim state pending that lane's process.
2. Optional: remove the floored/base-capped gate on annual bucket synthesis so all annual caps read true YTD (product sign-off).

---

# ADDENDUM 2 — all lanes pushed through (same day, third pass)

Mike's instruction: "manage all of these, and push them through in the correct order." Final state:

**Git (all local commits on `main`, authored Mike Ross):**
- `cardcoach-docs`: `3f06994` (stale session artifacts 08-02..08-11, incl. the 10-day fx_fee delta), `1fb1c17` (engine docs + handoff + NBC/RBC-WE delta), + the RBC-std delta commit.
- `CardCoachv2`: `bfd487e` (the full ENG-floors engine/loader/reader work + both migrations), `c75f747` (5 recovered remote-only migrations — local↔remote history now 1:1), `f61ca35` (the affiliate-wire website deliverable filed 2026-08-11, FUSE junk gitignored).
- The stale-lock blocker dissolved: the sandbox can't `unlink` inside `.git` but CAN `rename` — every lock was swept aside. Leftover `*.stale.*` and `tmp_obj_*` files inside both `.git` dirs are inert; `git gc` on the Mac cleans them.

**Database / pipeline:**
- RBC Cash Back standard: interim rows expired, four clause rows live (base 0.5% [0,$6k) excl grocery / base 1% [$6k,∞) excl grocery / grocery 2% [0,$6k) / grocery 1% [$6k,∞)), `card_products.base_earn = 0.5000`. Delta `2026-08-12__earn_rates__rbc_std_rising_tiers_option_a.sql`; snapshot `card_products_snapshot_20260812` secured in-transaction; verified safe to precede the edge redeploy (prices identically to the interim under the deployed engine).
- Queue `14756c08` → **applied**, `1607e61c` → **superseded**, with apply-session + write_audit bookkeeping against run `bc3f3545`. **The apply queue is empty** (no staged / needs_input / approved rows).

**Left for Mike's machine (in order, ~5 min):**
1. `git push` in `cardcoach-docs` and `CardCoachv2` (GitHub unreachable from the sandbox).
2. `npx supabase functions deploy recommend-card-v2 recommend-here-v2 recommend-cards-stateless-v1` from `mobile_app_codebase` — the scoring closures exceed the MCP deploy channel (precedent: 2026-08-02, #23). cap-progress-v1's change is comment-only and can ride the next natural deploy. This deploy activates full window semantics; until then every remodelled card prices at its safe approximation.
3. Optional: `git gc` in both repos to clear the renamed lock/tmp artifacts.

**CLOSED (code session, night of 2026-08-12→13, WORKING_NOTES entry + commit `2530ba7`):** both repos pushed (fast-forwards, carrying prior sessions' unpushed backlog too), three functions deployed (v20/v20/v8, `verify_jwt` false preserved), 143/143 + 8/8 + health green, logs clean.

**Two corrections from that run, on this session's own analysis:**
- **The NBC remodel is live in data but DORMANT in production pricing: both NBC cards are `scoring_status='load_only'`**, which this session never checked when claiming the deploy would activate them (and when designing the NBC-based deploy probe, which was therefore inexpressible on any scoring endpoint). Window semantics are live for the two RBC cards; NBC starts pricing its tiers the moment those cards flip to `scoreable` — a catalog/product decision for the verify lane, not an engineering gap. Engine, data, and buckets are ready and tested for that flip.
- Deploy proof came from **breakdown attribution**, not totals: generalized D2 intentionally reproduces old snapshot-less totals, so the discriminator is RBC std grocery's breakdown (base 0¢ + grocery slot carrying the full 2%→1% schedule — the §3 target exactly). Totals and rankings unchanged on snapshot-less surfaces by design; floors bite on authed, snapshot-bearing paths.

Residual watch item: `recommend-card-v2`/`recommend-here-v2` had zero invocations in the post-deploy window (authed endpoints) — healthy by artifact, unexercised by traffic at report time.
