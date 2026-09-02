# REPORT — auto location optimization

**Date:** 2026-08-25 · **Lane:** auto location · **Owner:** Mike · Last updated: 2026-09-02 (§5 self-heal correction)
**Status:** **DEPLOYED 2026-08-25 ~22:56 UTC** by Mike — `recommend-here-v2` v25, `resolve-place` v16. Server half live on both platforms; client half rides build 84.
**Supersedes §3 of** `FINDINGS_places_autolocation_2026-08-25.md`, which was wrong. See §1.

---

## 0. Headline

Auto location's problem was never that Google Places was off. It is on, and it has been.
The problem is that **the app has been sending the wrong category to the scoring engine**,
and a fuel stop has been scoring as a grocery run in production.

`Petro-Canada` classifies as **`grocery`**, not `gas`. So does any gas station whose Google
listing carries a `convenience_store` tag — which is most of them. Grocery and gas are
different multipliers on different cards, so the card the user was told to tap was the wrong
one. Live right now, on both platforms.

Twelve chains were resolving to the wrong category or to no category at all. All twelve are
fixed, verified against live Google data, 0 regressions.

## 1. Correction to the previous report

Yesterday's findings doc said widening `includedTypes` was a "free win — same money, roughly
double the categories reachable." **That was wrong, and shipping it as written would have made
auto location worse.**

Measured against six live Ontario coordinates: a naive widening to 38 types displaced the
correct merchant at **3 of 4** dense spots. `rankPreference: DISTANCE` means the nearest
listing wins outright, and the added types are full of listings that are not storefronts:

| Where | What shipped today found | What the naive widening found |
|---|---|---|
| Yonge/Sheppard | Taco Bell (42 m) | **"z z k m", a `camping_cabin` (5 m)** — and Rexall fell out of the list entirely |
| Bay/Queen | Gateway Newstands (61 m) | "HMaccessories", a 3 m clothing kiosk |
| Scarborough | Shell (182 m) | a gym and a mall; the gas station vanished |

`transit_station` alone put **three bus stops** in one top-10. The win is in which types are
left *out*. That is now documented in the code so the next pass does not re-widen it.

## 2. What was actually wrong: rung order

`classifyPlace` walks a ladder of type tests and returns on the first match. Google returns a
flat, unranked array in which broad tags sit beside specific ones, so **whichever rung is
tested first wins** — and the broad ones were on top.

| Chain | Real Google types | Was | Now |
|---|---|---|---|
| Petro-Canada | `gas_station, convenience_store, food_store, store, food` | `grocery` | **`gas`** |
| Rexall | `drugstore, pharmacy, convenience_store, …, food` | `grocery` | **`drugstore_pharmacy`** |
| LCBO | `liquor_store, store, food` | `dining` | **`alcohol`** |
| Fairmont Royal York | `hotel, lodging, restaurant, food` | `dining` | **`travel`** |
| Best Buy | `electronics_store, home_goods_store, store` | `home_improvement` | **`retail_shopping`** |
| IKEA / Leon's | `furniture_store, home_improvement_store, …` | `home_improvement` | **`furniture`** |
| Costco · Beer Store · Hudson's Bay · Sport Chek · Tesla Supercharger | — | **`null`** (no category at all) | correct category |

`convenience_store` rides along with nearly every gas station and drugstore; bare `food` rides
along with liquor stores and hotels. Both were being tested before the specific tags.

**Fix:** specific merchant types first, broad co-tags last as explicit fallbacks, plus Google's
own `primaryType` as the arbiter for genuinely multi-category stores. `primaryType` was correct
in every ambiguous case tested. It is what keeps Metro (which has a pharmacy counter) as
`grocery` instead of flipping to `drugstore_pharmacy`, and Home Depot (which carries a
furniture tag) as `home_improvement`.

Result: **24/24 chains correct, 12 fixed, 0 regressions**, checked against the live API.

## 3. The position feeding all of it was junk

Independent of categories, `NowScreen`'s `MERCHANT_LOCATION_REQUEST` accepted a cached fix
**up to 5 minutes old and accurate only to 1000 m**, and asked for `balanced` (~100 m) when it
needed a fresh one.

That position picks the merchant, and `DEFAULT_SINGLE_MERCHANT_DISTANCE_THRESHOLD_METERS`
(50 m, same file) then decides the app is *confident* about it. A kilometre of error feeding a
50 m confidence threshold is not a tuning choice, it is a contradiction — the screen could name
a merchant from a position nowhere near it, and say it was sure.

| | was | now |
|---|---|---|
| accuracy | `balanced` (~100 m) | `high` (~10 m) |
| cached fix max age | 5 min | 60 s |
| cached fix required accuracy | **1000 m** | 75 m |
| post-timeout fallback | 15 min / 1500 m | 10 min / 500 m |

Also fixed: `mapAccuracy` returned `Accuracy.Highest ?? High`, so production got `Highest`
while `location.test.ts` had always asserted `High`. `Highest` is `kCLLocationAccuracyBest` and
keeps refining until satisfied — indoors, the exact place this app is used, that can outlast
the 8 s timeout and drop the caller onto the stale path. Now `High` on both, matching the test.

## 4. iOS / Android parity — confirmed

You asked for this explicitly. Parity here is structural, not maintained by hand:

- **No `Platform.OS` branch exists anywhere in the location path** — `services/location.ts`,
  `useForegroundLocation.ts`, or `NowScreen`'s location code. Verified by search.
- `app.config.ts` configures `expo-location` symmetrically: foreground-only, with
  `isIosBackgroundLocationEnabled` and `isAndroidBackgroundLocationEnabled` both explicitly false.
- The category and type fixes are **server-side** (`recommend-here-v2`, `classify.ts`), so both
  platforms get them from the same deploy, at the same instant, with no build on either side.
- The accuracy fix is in shared JS with no platform branch. `Accuracy.High` maps to
  `PRIORITY_HIGH_ACCURACY` on Android and `kCLLocationAccuracyNearestTenMeters` on iOS.

The only asymmetry in this lane is release timing: the server half can ship today, the client
half rides the next build on both platforms together.

## 5. Nothing needs flipping — and one flag must NOT be flipped

You asked me to flip what needed flipping. Nothing does, and one would actively hurt:

**`auto_location_gate` is a `restrict` gate.** `false` means auto location is free for
everyone — today's behaviour. Setting it **`true` restricts auto location to Pro subscribers**.
With 6–10 real users and no RevenueCat project yet (`billing_events` row count is still 0 per
RUNBOOK_pro_go_live), flipping it would take a working feature away from all of them and give
it to nobody. `RUNBOOK_build_84` §B8 already says hold; the cost math is a second reason.

Checked every other flag for auto-location relevance: none gate coverage or quality.
`card_slot_limit`, `network_acceptance`, `billing_paywall` are all unrelated to this path.

## 6. Deploy — done, and the trap it hit

Deployed 2026-08-25: **`recommend-here-v2` v25**, **`resolve-place` v16**. Both boot clean
(~65 ms, no bundle errors). Deployed content verified field by field: `places.primaryType` is
in the Nearby field mask, the widened merchant types are present, `primaryType` is threaded
into the classifier, `classify.ts` carries the reordered rungs — and the junk-prone types
(`transit_station`, `clothing_store`) are correctly **absent**, confirming the conservative
list shipped rather than the one that regressed in testing.

Note the prior deployed version was **v24, from ~2026-08-15**. The repo had been ahead of
production for ten days, so this deploy also shipped whatever else had accumulated in
`recommend-here-v2` since then — not only this lane's changes.

### The import-map trap (first attempt failed)

The first `npx supabase functions deploy` attempt failed on BOTH functions while bundling:

```
Failed to bundle the function (reason: Relative import path "zod" not prefixed
  with / or ./ or ../ ... at .../recommend-here-v2/index.ts:10:19)
Failed to bundle the function (reason: Relative import path "@supabase/supabase-js"
  not prefixed with / or ./ or ../ ... at .../resolve-place/index.ts:1:30)
```

Not caused by this lane's edits — those import lines are untouched, and the failure is at
line 1 and line 10. The functions use bare specifiers (`zod`, `@supabase/supabase-js`) that
need `supabase/functions/deno.json` supplied as the import map; the CLI was not picking it up,
and the asset upload list in the failed run contains no `deno.json`. `resolve-place` v16 now
records `import_map: true` pointing at `source/deno.json`, so the resolved deploy passes it.

**For the next session that deploys these:** if bundling fails on a bare specifier, the import
map is the cause, not the code. The deployed-function metadata is the quickest check —
`import_map: true` means it was supplied, `import_map: null` means it was not.

## 7. Leftover to remove

```
npx supabase functions delete places-typecheck-tmp --project-ref hrzpznlpmxxrbtwskacu
```

Inert already — no API calls, no secrets, returns 410, `verify_jwt` back on — but it should
not outlive the lane.

## 8. Still outstanding

**The client half has not shipped.** The location-accuracy fix (§3) is in the working tree and
needs a build. Until build 84 lands, the position feeding the newly-correct categories is still
the one that accepts a 1000 m, 5-minute-old cached fix. The category fix and the position fix
are complementary; only one of them is live.

**No live traffic through v25 yet** at the time of writing, so the fix is verified by deployed-
content inspection and by the pre-deploy check against the live Places API (24/24, 12 fixed,
0 regressed) — not yet by a real request. Opening the Now screen once next to a gas station or
a Shoppers is the end-to-end confirmation. Watch it land with:

```sql
select event_message, timestamp from logs
where source = 'function_logs' and event_message ilike '%recommend_here_v2_success%'
order by timestamp desc limit 5;
```

> **CORRECTION 2026-09-02:** the paragraph below is wrong and is kept for the record. The request-path self-heal writes were removed on 2026-08-14 (WORKING_NOTES #26): the resolvers only *record* proposals to `verify.merchant_category_observations`, and the Monday batch that applies them has never executed. The nine entities in §6 will **not** correct themselves; they need that batch or a manual gated apply. Until then every entity with a NULL `default_category_id` scores base-rates-only on every tap.

**~~Category self-heal is now armed.~~** ~~Both resolvers will rewrite
`merchant_entities.default_category_id` as users pass those merchants.~~ Nine fuel entities are
currently mis- or un-categorized (§6 table below); they should correct themselves over the next
few sessions. Track with:

```sql
select default_category_id, count(*) from merchant_entities group by 1 order by 2 desc;
```

## 9. What you needed to run (historical)

The code is complete and tested in the working tree on `feat/pro-tier-and-statement-import`.
Six files, uncommitted — nothing is committed or pushed.

**Server half — ships without a build, fixes the gas-station bug for everyone immediately:**

```
cd ~/dev/CardCoachv2/mobile_app_codebase
npx supabase functions deploy recommend-here-v2
npx supabase functions deploy resolve-place     # shares classify.ts
```

I could not run these: the deploy closure is **49 files / 467 KB**, past the MCP deploy
channel (your own note on #23 records the same limit), and the shell I have on your Mac has
no network access.

**Client half — rides build 84**, no separate action. `NowScreen.tsx`, `location.ts`, and their
tests are staged for whatever build goes next.

**One consequence to accept before deploying.** Both resolvers run "category self-heal"
UPDATEs: when a live classification disagrees with the stored `merchant_entities
.default_category_id`, they correct the row. So deploying will progressively rewrite stored
categories in `public.merchant_entities` as users pass those merchants. That is the desired
outcome — it is what repairs the bad data — but it is an automatic write to `public.*`, and
PROJECT_RULES puts those behind your approval. Flagging it rather than assuming it.

Current blast radius on fuel brands alone:

| stored category | entities | examples |
|---|---|---|
| `gas` (correct) | 11 | Petro-Canada, Esso, Shell, Chevron, Mobil, Ultramar |
| **`null`** | 6 | Costco Gas, Husky, Canadian Tire Gas+ |
| **`grocery`** | 2 | Shell Gas Station, Circle K |
| **`dining`** | 1 | Shell Gas & KwikBite |

Nine fuel entities mis- or un-categorized, plus six more across the drugstore / liquor /
warehouse / home names. Watch it with:

```sql
select default_category_id, count(*) from merchant_entities group by 1 order by 2 desc;
```

**Also safe to delete** — an inert leftover from validating this work. It makes no API calls,
reads no secrets, returns 410, and has `verify_jwt` back on:

```
npx supabase functions delete places-typecheck-tmp --project-ref hrzpznlpmxxrbtwskacu
```

## 10. Tests

| suite | result |
|---|---|
| `supabase/functions/__tests__/classify.test.ts` | **54 passed, 0 failed** (was 27; +27 new) |
| `apps/mobile/src/__tests__/location.test.ts` | 16 passed |
| `NowScreen.test.tsx` + `useFeatureGate.test.tsx` | 25 passed |
| `apps/mobile/src/widget/**` | all passed |
| live chain check vs Places API | **24/24, 12 fixed, 0 regressed** |

The new classify tests are built from the **real type arrays Google returned on 2026-08-25**,
not invented fixtures, and each encodes a rung-order trap. If someone reorders the ladder,
they fail. Two of them exist only because my own first attempt got the order wrong — the
gas/EV precedence and the Home Depot/furniture collision were both caught by tests, not by
reading.

## 11. Deliberate behaviour changes, called out

1. **`home_goods_store` moved** from `home_improvement` to `retail_shopping`, changing an
   existing test expectation (HomeSense). It had to leave: Best Buy carries the same tag and
   was being dragged into home_improvement. It is also the better answer on the merits —
   Canadian "home improvement" earn categories mean hardware and building supply, not decor.
2. **Gas outranks EV charging** when a forecourt carries both tags. Fuel is the transaction
   the card is being presented for and `gas` has far wider card coverage (64 cards vs 17).
   Pure charging sites carry no `gas_station` tag and are unaffected.

## 12. Not done — the one real limit left

Ranking is still **pure distance**, and that is now the binding constraint. At several test
coordinates four or five listings sit within 1–6 m of each other, which is well inside GPS
error; which one is "nearest" is effectively random. Widening types safely required leaving
real categories out (`clothing_store`, `shopping_mall`, `gym`, transit) purely because
distance-ranking cannot defend against a 3 m kiosk.

Fixing that means ranking on something other than raw metres — a distance *bucket* roughly the
size of GPS error, broken by whether the classified category actually carries earn rates. That
is a design change to the candidate loop, not a config tweak, and it is the thing worth doing
next in this lane. Latency is the other reason to open that loop up: `recommend-here-v2` is
running **2.5–7 s** per call, resolving candidates serially.
