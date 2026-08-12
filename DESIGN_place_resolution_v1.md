# DESIGN — Place Resolution v1 (`resolve-place-v1`)

Date: 2026-08-12 · Status: DRAFT for review · Author: writer-hunt dispatch session (Claude)
Companion workstream: RCSS dedupe SQL (`2026-08-11__merchant-graph__rcss-dedupe.sql`) + `verify.merchant_graph_guardrail` — handled in Chat, **not** this doc.

All code paths below are relative to `CardCoachv2/mobile_app_codebase/` unless prefixed otherwise. Every current-state claim is cited `file:line` against the tree at commit `c175a46` (2026-08-02) + working tree of 2026-08-12; git citations name their commit explicitly.

---

## 1. Current state (writer-hunt findings, 2026-08-12)

### 1.1 The hypothesis, verified

> Hypothesis (2026-08-11 dispatch): a runtime or session path creates `merchant_entities` rows from place names.

**Verified.** Two edge-function paths mint `merchant_entities` rows at runtime, on ordinary authenticated user requests, via service-role clients:

1. **`resolve-place` v2 miss path** — `supabase/functions/resolve-place/index.ts:548-556`. On a `placeId` with no `merchant_entity_places` mapping (lookup `index.ts:347-363`), no exact `normalized_name` match (`index.ts:465-470`), and no chain-prefix match (`index.ts:525-530`), it INSERTs `{display_name: place.name, normalized_name, default_category_id}` from the Google Place Details result, then INSERTs the `merchant_entity_places` pointer (`index.ts:581-589`). One row per unknown place, name straight from Google.
2. **`recommend-here-v2` per-candidate path** — `supabase/functions/recommend-here-v2/index.ts:301-309` inside `resolveCandidateMerchant` (`index.ts:163-366`, invoked at `index.ts:649`). Same funnel per nearby candidate (mapping lookup `180-192`, exact match `252-256`, chain fallback `290-295`), so **one location request can mint up to `maxCandidates` (default 3, max 5) new entities** from Google `searchNearby` display names. Unique-violation races re-read the winner (`index.ts:311-321`).

Creation is the *designed* fallback: neither resolver has a "no match → no entity" outcome for a normalizable name (`resolve-place/index.ts:547` comment-free fall-through; `recommend-here-v2/index.ts:299-325`). The only non-creating case is a name with no usable characters (`recommend-here-v2/index.ts:329-332`; `resolve-place` substitutes a place-scoped key `` `place:${placeId}` `` at `index.ts:463-464`).

Both writes are service-role because RLS revokes INSERT/UPDATE/DELETE on `merchant_entities` from `anon` and `authenticated` (`supabase/migrations/0021_auth_005_canonical_facts_readonly_rls.sql:63-67`); admin clients built at `resolve-place/index.ts:227` and `recommend-here-v2/index.ts:410`. No client or package code can write the table: `apps/`, `packages/`, and the sibling web app (`../card_coach_web_app`, a `.gitkeep` placeholder) contain zero `merchant_entities` write references.

### 1.2 Secondary runtime writers (same class, lower blast radius)

- **Category self-heal UPDATEs** on `merchant_entities.default_category_id`: `resolve-place/index.ts:423-426, 441-444, 507-510`; `recommend-here-v2/index.ts:215-218, 220-224, 232-236, 268-271, 273-277, 283-286`; `recommend-card-v2/index.ts:259-262`. Never touch `normalized_name`.
- **Alias INSERT on chain hit**: `merchant_entity_aliases` gets the raw observed name whenever the chain matcher fires (`supabase/functions/_shared/merchantIdentity.ts:118-122`), best-effort, errors swallowed.
- **Legacy `merchants` table writers** (V1 graph, not `merchant_entities`): `resolve-place` v1 handler upserts on every call (`resolve-place/index.ts:276-281`); `record-transaction` inserts a `merchants` row when the mapping exists but the V1 row doesn't (`record-transaction/index.ts:292-300`, verbatim `display_name`, fallback `'Unknown Merchant'`).

### 1.3 Non-runtime writers (complete inventory)

| Writer | Kind | Notes |
|---|---|---|
| `supabase/seed.sql:982` (dump block) | seed (local db-reset only) | pg_dump replay of the live DB (~2026-02-25); truncates every public table first (`seed.sql:24-31`), then resurrects all three legacy naming styles verbatim — incl. both bug rows (`:997`, `:1125`) |
| `supabase/seed.sql:2119`, `:2450` | seed replays of DATA-018/019 | `ON CONFLICT (normalized_name) DO NOTHING`; hand-written canonical-style literals |
| `supabase/migrations/20260801150500_data_018_loyalty_stacking_seed.sql:80` | migration | hand-curated entity list, keyed to the live normalizer's output per its own comment (`:12-13`) |
| `supabase/migrations/20260802170000_data_019_member_earn_rates.sql:147` (+ `is_chain` UPDATE `:154-155`) | migration | inserts spaces-style drugstore banners; comment `:140-146` documents the dead-underscore trap |
| `supabase/migrations/20260802160000_chain_entity_matching.sql:18-33` | migration | UPDATE `is_chain=true` keyed on **spaces-style** names only — see §1.5 |
| `supabase/migrations/0036:7`, `0041:9`, `0043:12` | migrations | category-column repairs only |
| `scripts/verify_phase3_applicability.mjs:94,103`; `verify_data_007_...mjs:64-66+`; `verify_data_008_...mjs:219`; `verify_api_006_...mjs:165-170`; `verify_api_010_...mjs:309`; `verify_qa_007_...mjs:196-199` | manual/session tooling | synthetic fixtures with a service key, self-deleting; cannot produce real merchant names |
| `scripts/verify_api_007_resolve_place_v2.mjs:149,160,317` | manual, **indirect** | POSTs real Google placeIds at a live stack → triggers the runtime mint path itself |

### 1.4 Fingerprint attribution (the four RCSS duplicates)

| Entity | Style | Writer | Evidence |
|---|---|---|---|
| `30eed4a6` "Real Canadian Superstore", 2026-01-16, `real_canadian_superstore` | underscores | **manual seed batch applied to the live DB** | Hand-written slugs committed same day in `09050a3` (2026-01-16, adds `('Real Canadian Superstore', 'real_canadian_superstore', 'grocery')` + aliases `'Superstore'`, `'RCSS'` to seed files). Live row sits in a 32-row batch sharing the identical timestamp `2026-01-16 15:31:40.357931` (`seed.sql:996-1007`), with curated aliases at the same instant (`seed.sql:1267-1279`) — a one-shot hand load, not a request path. A second 50-row underscore batch shares `2026-01-22 22:13:04.660227` (`seed.sql:1073-1121`). **No code in any revision produces underscores** (repo-wide + git-history search). |
| `c6d6785f` "…Victoria Street", 2026-01-23, `realcanadiansuperstorevictoriastreet` | squashed | **runtime mint by the pre-repair `resolve-place` normalizer** | January-era `resolve-place` had `normalizeForMatching` = `toLowerCase().replace(/[^a-z0-9]/g,'')` and an entity INSERT (git `0528d0e:supabase/functions/resolve-place/index.ts:65-68, 271-277`). Row carries the runtime signature: ms-precision timestamp `13:41:00.093319` with its `merchant_entity_places` row created 106 ms later (`seed.sql:1125`, `:1358`). The removed normalizer is also documented in `_shared/merchantIdentity.ts:5-10`. |
| `5bb0fad1` "…Oxford Street - Oakridge", 2026-08-02 13:46, spaces | spaces | **runtime mint by the current shared normalizer** (either resolver) | `normalizeMerchantName` (`_shared/merchantIdentity.ts:21-30`) produces exactly this style; the literal appears in no migration or seed. The chain guard shipped the same day could not catch it — §1.5. |
| `d4a1923b` "Real Canadian Superstore", 2026-08-02 14:09, spaces, `is_chain=true` | spaces | **INSERT not attributable to any committed code** | `20260802160000` only UPDATEs the flag (`:18-33`); no migration/seed inserts a spaces-style RCSS brand row. Consistent with the interactive 2026-08-02 repair session creating it (manually, or via a runtime mint of an unsuffixed place) and the flag UPDATE landing after. The place-row re-point between the Aug-2 pair supports the partially-self-corrected-session reading. **Flagged plainly: the insert itself is the one unattributed event.** |

At least **two distinct runtime writers were concurrently live in Jan–Feb 2026**: squashed and spaces rows interleave on the same days in the dump (e.g. `sobeysnorthlondon` 2026-02-20 23:00 vs `rick's sideline concessions` 2026-02-20 22:33) — matching `merchantIdentity.ts:5-10`'s history note that old `resolve-place` (squashed) and old `recommend-here-v2` (space-preserving) ran different formats against one `UNIQUE(normalized_name)` key.

### 1.5 Why the 2026-08-02 chain fix couldn't stop the Aug-2 mints

`20260802160000_chain_entity_matching.sql:18-33` sets `is_chain = true` `WHERE normalized_name IN ('real canadian superstore', …)` — **spaces-style names only**. Production's only RCSS brand row was the dead underscore row (`real_canadian_superstore`, `seed.sql:997`), and nothing in any migration or seed inserts a spaces-style one. The UPDATE matched 0 Superstore-family rows, `matchChainEntity`'s candidate list (`is_chain=true` rows, `merchantIdentity.ts:107-110`) never contained the chain, and the resolver fell through to the mint. Same silent-miss mechanism as the `shoppers_drug_mart` case documented in `20260802170000:140-146`. Other flagged-but-never-inserted names in the same trap: `zehrs`, `maxi`, `atlantic superstore`, `valumart`, `fortinos`, `wholesale club` (`20260802160000:27-28`).

### 1.6 Normalization implementations found (≥ the three §1 styles, as predicted)

1. **Current canonical** — `normalizeMerchantName`, `_shared/merchantIdentity.ts:21-30`: lowercase, strip `/[^\p{L}\p{N}\s]/gu`, trim, collapse whitespace → **spaces style**; returns `null` on empty. Sole callers: `resolve-place/index.ts:463`, `recommend-here-v2/index.ts:248`. Introduced by the Phase-2 repair (`de709d5`, 2026-07-04).
2. **Call-site fallback** — `` normalizeMerchantName(name) ?? `place:${placeId}` `` (`resolve-place/index.ts:463-464`): place-scoped key for unusable names.
3. **Historical squashed** — `normalizeForMatching`, removed; recovered from git (`0528d0e` / `9c05a5f`, `resolve-place/index.ts:65-68`): `toLowerCase().replace(/[^a-z0-9]/g,'')`.
4. **Underscore slug convention** — data-only, hand-written (seed commit `09050a3`); **no implementing function ever existed**.
5. Ad-hoc synthetic literals in verify scripts (§1.3) — all three styles, fixtures only.
6. (Categories, not names: `normalizeCategoryId`, `resolve-place/classify.ts:29-51`.)

### 1.7 Schema + flag facts the design builds on

- `merchant_entities`: `id uuid PK`, `display_name text NOT NULL`, `normalized_name text NOT NULL` + `UNIQUE` (`0009_canonical_merchant_entities.sql:7-16`), `default_category_id → categories(id)`, `is_chain boolean NOT NULL DEFAULT false` (`20260802160000:12-13`). The UNIQUE key is why three styles coexist as three rows instead of conflicting.
- `merchant_entity_places`: `UNIQUE(place_id)` (`0009:41`) — **already a provider-place-id → entity cache**, minus a provider column.
- `merchant_entity_aliases`: `UNIQUE(merchant_entity_id, alias)` (`0009:26`).
- `earn_rate_eligible_merchants`: `UNIQUE(earn_rate_id, merchant_entity_id)`, fail-closed semantics (`0033:6-15`) — the list the Victoria Street duplicate was absent from.
- `runtime_flags`: `key TEXT PK CHECK (key ~ '^[a-z0-9_]{2,64}$')`, `enabled boolean NOT NULL DEFAULT false`, RLS read-only to clients (`20260801150000_data_018_loyalty_stacking_phase1.sql:259-273`); reference row `loyalty_offer_stacking` seeded false (`:275-281`); read pattern: one `select enabled … maybeSingle()` per request, **fails closed to disabled on any error** (`_shared/scoring.ts:612-624`).
- `verify` schema exists with `verify.parking (id, run_id, card_id, topic, observed jsonb, evidence_ids, noted_at)` (`20260727215042_verification_engine_p1_verify_schema.sql:71-79`), service-role-only (`:101-106`). `card_id` is nullable — usable for non-card parking rows as-is.
- Client flow today (all Google, all server-side): `search-places` = pure authenticated Autocomplete proxy, zero DB access (`search-places/index.ts:154, 202-212`); mobile calls it (`apps/mobile/src/services/api.ts:11-23`) then `resolvePlace` with `schemaVersion: 2` forced (`api.ts:25-48`, call site `NowScreen.tsx:715`); location flow sends bare coords to `recommend-here-v2` (`apps/mobile/src/services/recommendHereV2.ts:56-62`). Client never learns whether an entity was minted — the response shape is identical either way (`resolve-place/index.ts:671-682`).

---

## 2. Target architecture

Constraints are settled (2026-08-11 Chat); restated here bound to the concrete names found in Phase 1:

1. **Platforms: iOS, Android, web.** Nothing below assumes an Apple-only capability; the shared contract lives in `packages/engine-contracts/src/index.ts` beside `SearchPlacesRequest`/`ResolvePlaceRequest`.
2. **Model-agnostic, flag-gated.** No monetization assumptions; every new behavior is a `runtime_flags` key or a config value, never a hardcoded tier.
3. **Single server-side resolver: `resolve-place-v1`** (new Supabase edge function; the name is a distinct function slug — the existing `resolve-place` function keeps its slug until retired, §4). Two modes:
   - `nearby`: coords in → candidate entities out (replaces `recommend-here-v2`'s internal `resolveCandidateMerchant`, `recommend-here-v2/index.ts:163-366`).
   - `search`: text or provider payload in → entity out (replaces `search-places` + `resolve-place` as the manual flow's resolver).
   All three clients are thin callers, parity discipline identical to `recommend-here-v2`/`recommend-card-v2`: same store → same brand entity → same recommendation on every platform.
4. **Runtime never inserts `merchant_entities`.** The mint fall-throughs (`resolve-place/index.ts:547-556`, `recommend-here-v2/index.ts:299-325`) are deleted, not gated. Unresolved input → `merchant_entity_id: null` (caller falls back to base earn — fail-closed, correct) + one `verify.parking` row (`topic: 'place_resolution_unresolved'`, §3.4). Entity creation becomes a gated curated write — same class as new cards: guarded-replay migration SQL per the existing migration discipline, reviewed from the parking queue.
5. **Pickers:** iOS = MapKit on-device (free). Android = Google Places with the **Essentials field mask only** (`place_id`, name, coords/address — no rating/review/atmosphere fields), hard quota at the 10k/month free threshold + budget alert (§5). Web free path = own-data text search over `merchant_entities` + `merchant_entity_aliases`, **no provider calls**.
6. **Provider caching: place_id only** (the one field Google permits storing). `merchant_entity_places` already keys `place_id → merchant_entity_id` with `UNIQUE(place_id)` (`0009:41`); it gains a `provider` discriminator (`'google' | 'apple' | …`) so repeat stores skip the provider on every platform. Existing rows backfill as `'google'`.
7. **`nearby` mode ships behind `runtime_flags` key `place_nearby_resolution`, default OFF** — same pattern as `loyalty_offer_stacking` (`20260801150000:259-281`, read + fail-closed per `scoring.ts:612-624`).

Resolution funnel inside `resolve-place-v1` (both modes), strictly read-only on the merchant graph:

```
provider_place_id cache hit (merchant_entity_places, provider-scoped)
  → exact normalized_name match (normalizeMerchantName, merchantIdentity.ts:21-30)
  → alias match (merchant_entity_aliases)
  → chain word-boundary prefix match (is_chain=true rows, merchantIdentity.ts:62-91)
  → NULL + park (verify.parking)          ← replaces the INSERT
```

The alias-match rung is new in the funnel (aliases exist and are runtime-written today but never read at resolution time — no SELECT on `merchant_entity_aliases` exists in either resolver).

## 3. Contract draft — `resolve-place-v1`

Types land in `packages/engine-contracts/src/index.ts` (mobile-safe, types only per `CLAUDE.md` boundaries).

### 3.1 Request

```ts
type ResolvePlaceV1Request = {
  schemaVersion: 1;
  mode: "nearby" | "search";
  locale: "en" | "fr";

  // mode: "nearby" — coords in (flag-gated, place_nearby_resolution)
  coords?: { latitude: number; longitude: number; radiusMeters?: number };

  // mode: "search" — EITHER a picker result (provider payload) OR free text
  place?: {
    provider: "google" | "apple";
    providerPlaceId: string;        // the only provider field we may store
    name: string;                   // display name from the picker
    coords?: { latitude: number; longitude: number };
    address?: string;               // transient; never stored
  };
  query?: string;                   // free text (web free path; own-data only)
};
```

Auth: same as today — user JWT verified before any work (`resolve-place/index.ts:199-216` pattern). Validation: `mode`-specific required fields; 400 on violation.

### 3.2 Response

```ts
type ResolvedPlace = {
  merchant_entity_id: string | null;   // null = unresolved (caller: base earn)
  merchant_place_id: string | null;    // merchant_entity_places.id when cache row exists/created
  display_name: string;                // entity display_name, or echo of input name
  category_id: string | null;
  confidence: "provider_id" | "exact" | "alias" | "chain_prefix" | "none";
  parked: boolean;                     // true when a verify.parking row was written
};

type ResolvePlaceV1Response = {
  schemaVersion: 1;
  mode: "nearby" | "search";
  results: ResolvedPlace[];            // search: 0..n (n small); nearby: 0..maxCandidates
  requestId: string;
};
```

`confidence` names the funnel rung that matched — it is diagnostic, not a probability; thresholds/semantics for fuzzy own-data search are an open question (§7).

### 3.3 Writes the resolver IS allowed

- `merchant_entity_places` INSERT — cache fill: `(provider, provider_place_id) → merchant_entity_id` after a successful non-cache match, mirroring today's mapping inserts (`resolve-place/index.ts:581-589`, `recommend-here-v2/index.ts:335-342`) but only for **resolved** entities.
- `verify.parking` INSERT on `confidence: "none"` (§3.4).
- **Nothing else.** No `merchant_entities` INSERT or UPDATE (the category self-heal UPDATEs do not carry over — §7), no alias INSERT (chain-hit alias capture `merchantIdentity.ts:118-122` moves to the curation review, which sees the parked/observed names anyway).

### 3.4 Parking row shape

`verify.parking` as-is (`20260727215042:71-79`), no schema change: `card_id NULL`, `topic = 'place_resolution_unresolved'`, `observed` jsonb =
`{ provider, provider_place_id, name, normalized_name, coords, locale, mode, requestId, seen_count?, first_seen? }`.
Dedup within the resolver: one row per `(provider, provider_place_id)` or per `normalized_name` for text queries — bump a counter instead of inserting repeats (exact mechanism TBD in implementation; the point is the queue stays reviewable).

## 4. Migration path

**Deleted or bypassed (all minting paths found in Phase 1):**

| Code | Fate |
|---|---|
| `resolve-place/index.ts:548-556` entity INSERT + `:581-589` mapping insert on the mint branch | deleted with the function — clients move to `resolve-place-v1` `search` mode; until then the mint branch is replaced by park-and-null |
| `resolve-place` handleV1 + `merchants` upsert (`index.ts:270-281`) | retired with the function (V1 legacy graph) |
| `recommend-here-v2/index.ts:299-325` entity INSERT (+ `:335-342` mapping insert for minted rows) | deleted; `resolveCandidateMerchant` is replaced by a call into the shared resolver module (no-mint semantics); unresolved candidates surface with `merchant_entity_id: null` → base-earn scoring (`scoring.ts:1148-1157` already fail-closes `merchant_list_only` rates on a missing entity) instead of being dropped (`index.ts:650-652`) |
| Category self-heal UPDATEs (`resolve-place/index.ts:423,441,507`; `recommend-here-v2/index.ts:215-286`; `recommend-card-v2/index.ts:259`) | do not carry over into `resolve-place-v1`; whether they survive elsewhere is §7 |
| Chain-hit alias INSERT (`merchantIdentity.ts:118-122`) | dropped from runtime; alias curation happens in review |
| `search-places` (Google Autocomplete proxy, `search-places/index.ts`) | superseded: Android picks via client-side Places SDK (Essentials mask), iOS via MapKit, web via own-data `search` mode — the server-side Autocomplete spend disappears |
| `verify_api_007_resolve_place_v2.mjs` | rewritten against `resolve-place-v1` (it currently exercises the mint path against live stacks) |

**Kept:** `normalizeMerchantName` + `findChainEntityMatch`/`matchChainEntity` matching logic (`merchantIdentity.ts:21-30, 62-91` — minus the alias write), `merchant_entity_places` as the cache (plus `provider` column, backfill `'google'`), the read-only funnel order, `recommend-card-v2`/`recommend-cards-stateless-v1`/`record-transaction` (already non-minting for `merchant_entities` — `record-transaction`'s legacy `merchants` insert is out of scope here, flagged for the V1-graph retirement).

**Ship order relative to the dedupe (Chat workstream):**

1. Dedupe Part A (merge the four RCSS rows; re-point `merchant_entity_places`/scopes) — prerequisite for trusting exact-match results.
2. Migration: `merchant_entity_places.provider` column + backfill; `resolve-place-v1` deployed with `search` mode live and `nearby` dark behind `place_nearby_resolution=false`.
3. Clients switch the manual flow (`api.ts` `searchPlaces`/`resolvePlace` call sites) to `resolve-place-v1 search`; old `resolve-place` + `search-places` functions deleted after the last client release that calls them ages out.
4. `recommend-here-v2` internals re-pointed at the shared resolver module (mint removed) — this can ship independently of client releases since the response contract is unchanged.
5. Dedupe Part B verification (`verify.merchant_graph_guardrail` green) → flip `place_nearby_resolution` (§6).

Steps 2–4 are pure code+migration; the only data prerequisite is Part A. **The minting deletion (step 4) should not wait for the flag** — every day the old paths run, new orphan entities accrue.

## 5. Cost & quota

- **iOS:** MapKit search/pickers are free on-device. No provider spend. Cache key: see §7 [VERIFY].
- **Android:** Google Places, Essentials-tier SKUs only, field mask restricted to `place_id`, display name, location/address. Essentials SKUs carry a 10k free calls/month threshold — the design pins usage under it:
  - **Hard quota:** cap the Places API at the free threshold in Google Cloud (requests/day ≈ 320 ⇒ ~9.6k/month ceiling) so overrun is impossible, plus a billing budget alert at the first dollar as a tripwire. Config change, no code.
  - **Cache effect:** `merchant_entity_places` short-circuits every previously-seen store before any provider call (the `UNIQUE(place_id)` lookup is rung 1 of the funnel). Observed live-DB growth while both minting resolvers ran: ~140 new entities over ~40 days, Jan 16–Feb 25 (dump timestamps, `seed.sql:982-1195`) ≈ **3–4 never-before-seen places/day across all platforms**. Even at 10× that, Android-only new-place Details calls sit an order of magnitude under the cap; the variable driver is Autocomplete keystroke sessions, which the client SDK's session tokens collapse to per-pick billing.
  - No rating/review/atmosphere fields ever — those SKUs are the expensive tiers and are contractually unnecessary here.
- **Web:** own-data search only (`merchant_entities` + `merchant_entity_aliases`), zero provider calls on the free path.
- **Storage:** only `provider_place_id` is cached (Google's storable field); names/addresses from provider payloads are transient except the entity `display_name` for rows that already exist in our graph, and the `observed` jsonb in parking rows (our own review queue, provider-independent input capture).

No assumptions anywhere about which platform tier a user is on — quota posture is identical whichever monetization model lands (§2.2).

## 6. Rollout

1. `place_nearby_resolution` seeded `false` exactly like `loyalty_offer_stacking` (`20260801150000:275-281`): migration inserts the row `ON CONFLICT DO NOTHING`, note documents the flip condition.
2. `search` mode ships un-flagged — it is the existing manual flow made non-minting (strictly less write-capable than today), and the fail-closed null path is the *correct* behavior the incident lacked.
3. Flip condition for `nearby`: dedupe Part B verification passes (`verify.merchant_graph_guardrail` clean — no orphan store-level duplicates, chain rows present in canonical form). Founder flips the flag; resolver reads it per request and fails closed to disabled on any error (`scoring.ts:612-624` pattern).
4. Kill switch: same flag; OFF returns `nearby` requests to the pre-launch behavior (clients fall back to the manual flow).
5. Parking queue watched from day one of `search` mode — its arrival rate is the direct measure of graph coverage gaps and of how much curated entity-creation work the gated write pipeline must absorb.

## 7. Open questions

1. **[VERIFY] Apple MapKit place identifier stability.** Whether MapKit's place identifiers are stable enough across time/devices to cache-key `merchant_entity_places (provider='apple', provider_place_id)`. **Do not guess Apple's identifier semantics** — verify against current MapKit documentation/behavior. If not stable: iOS cache keys on a `name+coords` hash (normalized name + ~50 m geo bucket), which needs its own collision review.
2. **Do the category self-heal UPDATEs survive anywhere?** They are runtime `merchant_entities` writes (§1.2) — outside the letter of "never inserts" but the same governance class. Options: drop entirely (categories fixed by curation), or park category-mismatch observations alongside unresolved places. Not settled in Chat.
3. **Fuzzy own-data search semantics for web `search` mode** — exact + alias + chain-prefix are defined; whether a trigram/prefix fuzzy rung is added, and what `confidence` it reports, is open.
4. **`recommend-here-v2` → resolver coupling**: shared in-process module (vendored like `_shared/engine`) vs an internal HTTP call to `resolve-place-v1`. Latency and deploy-coupling trade-off; module-share is the working assumption.
5. **Parking dedup mechanism** (§3.4): per-key counter row vs append-only + review-time grouping. Append-only is simpler; counter keeps the queue small. Implementation-time choice.
6. **Legacy `merchants` (V1) graph retirement** — `record-transaction` still writes it (`record-transaction/index.ts:292-300`) and `recommend-card` reads it; out of scope for this design but the same never-mint discipline should eventually apply.

---

## Appendix A — writer classification summary (Phase 1 deliverable)

**Runtime (executes on user requests):** `resolve-place/index.ts:548` (entity INSERT — mint), `recommend-here-v2/index.ts:301` (entity INSERT — mint, ×maxCandidates), `resolve-place/index.ts:423,441,507` + `recommend-here-v2/index.ts:215-286` + `recommend-card-v2/index.ts:259` (category UPDATEs), `merchantIdentity.ts:119` (alias INSERT), `resolve-place/index.ts:581` + `recommend-here-v2/index.ts:335` (mapping INSERTs), `resolve-place/index.ts:276` + `record-transaction/index.ts:292` (legacy `merchants` writes).

**Seed/migration:** `seed.sql:982, 2119, 2420, 2450`; migrations `20260801150500:80`, `20260802170000:147,154`, `20260802160000:18`, `0036:7`, `0041:9`, `0043:12`.

**Manual/session tooling:** verify scripts (§1.3, synthetic self-deleting fixtures); `verify_api_007` (indirect — drives the runtime mint); the 2026-01-16/-22 hand seed batches applied to live (commit `09050a3`); the unattributed `d4a1923b` INSERT of 2026-08-02 14:09 (§1.4 — the single event no committed code explains).

**Fingerprint → writer:** underscores = hand seed batches (Jan 16/22); squashed = pre-repair `resolve-place` runtime normalizer (Jan 16–Feb 25 era, git `0528d0e`); spaces = current shared normalizer via either resolver (post `de709d5`, 2026-07-04) + hand-written 2026-08 migrations. All four RCSS rows accounted for; one insert event (`d4a1923b`) unattributable to committed code, flagged above.
