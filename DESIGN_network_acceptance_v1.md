# DESIGN — Network acceptance (DATA-021 / API-019) v1

Date: 2026-08-17 · Owner: Mike · Status: **APPLIED to prod, flag OFF**

Schema + 25 seed rules are live in `hrzpznlpmxxrbtwskacu`. Nothing reads them:
`runtime_flags.network_acceptance` is **false**, so production behaviour is
unchanged until it is flipped.

Governing docs: `SOURCE_OF_TRUTH.md`, `PROJECT_RULES.md` (rules 7 and 9),
`HOW_THE_ENGINE_WORKS.md`. Companion: `DESIGN_place_resolution_v1.md` §1.5,
which explains the normalized-name hazard this design has to survive.

---

## 0. The report

2026-08-17, tester: her Amex was recommended at a Zehrs. No Loblaw grocery
banner accepts American Express.

The recommendation was not a scoring bug. The engine computed the earn
correctly, ranked correctly on that basis, and produced an answer she could not
act on, because **the engine has never had a concept of whether a card can be
tendered at all.** Every gate in `scoreWalletForPurchase` asks a version of
"what does this card earn here?" — caps, floors, exclusions, condition gating,
FX. None of them asks "will this card work here?"

`card_exclusions` is the near miss worth naming explicitly, because it is where
someone will reach first. An exclusion means *this card earns no bonus at this
merchant* — the card still works, still pays its base rate, and is still a
legitimate thing to recommend if nothing beats it. Non-acceptance means the
terminal declines it. Modelling one as the other would understate the problem to
the point of uselessness: a "0% here" Amex still ranks above a 0% Visa.

This is also not one merchant. The same shape, in Canada, at least covers:

| Merchant | Refuses | Notes |
|---|---|---|
| Loblaw grocery banners | Amex | One shared POS across the umbrella |
| Costco warehouses + gas bars | Amex, **Visa** | Mastercard-exclusive since 2015 |
| Costco.ca | Amex only | Visa **is** accepted online — channel split |

So the fix has to be a mechanism, not a patch.

---

## 1. What the model has to survive

Four constraints fell out of looking at production, and each one killed a
simpler design.

### 1.1 Merchant entities are minted at runtime

`merchant_entities` is not a curated list. `resolve-place` and
`recommend-here-v2` INSERT a new row whenever a Google place has no mapping
(`DESIGN_place_resolution_v1.md` §1, items 1–2). Production today:

```
Zehrs · Zehrs Laurentian · Zehrs Stanley Park · Zehrs Stratford
No Frills · Jim & Maria's No Frills · Mike's NOFRILLS Woodbridge · Steve's NOFRILLS Etobicoke
```

**Kills:** a rule table keyed only on `merchant_entity_id`, and a rule table
keyed only on `merchant_group_memberships`. Both cover the stores someone has
already visited and miss every store that opens next month — or that a user
walks into for the first time, which is precisely when the app is asked.

### 1.2 The normalized-name graph has two spellings

`normalizeMerchantName` strips punctuation but does not join or split words.
`"No Frills"` → `no frills`; `"NOFRILLS"` → `nofrills`. These are different keys
under `UNIQUE(normalized_name)`, which is how the 2026-08-02 chain fix matched
**zero** Superstore rows (§1.5 of the place-resolution design).

**Kills:** a single pattern per brand. Both spellings get seeded, and a test
pins the distinction so nobody "simplifies" it later.

### 1.3 Franchise banners lead with the franchisee's name

`mikes nofrills woodbridge`. A prefix match cannot reach it, and most No Frills
stores are franchises.

**Kills:** prefix-only matching. A `contains` mode is required — with token
boundaries, so `zehrs` never matches `zehrsville market`.

### 1.4 Ownership does not imply policy

Shoppers Drug Mart is Loblaw-owned. Two reputable secondary sources read on
2026-08-17 **disagree** on whether it takes Amex.

**Kills:** deriving acceptance from a corporate-parent group. The model must be
able to state an exception, and — since the sources conflict — the seed states
nothing for Shoppers at all and leaves the fail-open default in place.

---

## 2. The model

New canonical-fact table `network_acceptance_rules`
(migration `20260817182517_network_acceptance_rules.sql`), time-windowed like
every other fact table, with a `v_active_*` companion view.

```
scope              merchant_entity | merchant_group | brand_pattern
target             merchant_entity_id | merchant_group_id | brand_pattern
brand_match_mode   exact | prefix | contains
network_id         → networks(id)
accepts            boolean
channel            any | in_store | online
evidence_url / evidence_tier / evidence_quote / verified_at / confidence
valid_from / valid_to
```

Three decisions inside that shape carry the design.

### D1 — Absence is the third state, and it means "accepted"

`accepts` is a boolean, not a three-valued enum, because the third value lives
in the *absence of a row*. No matching rule ⇒ unknown ⇒ the card is treated as
accepted.

558 merchant entities exist. This table will realistically cover a few dozen
brands. A mechanism that demoted cards on missing data would be wrong at
thousands of merchants to be right at twenty — strictly worse than the bug. Only
an affirmative, evidenced `accepts = false` can demote anything, and **every
error path in the resolver returns an empty map**: flag off, flag unreadable,
table missing, query failure, portal channel, no merchant identity.

The asymmetry is the point. The worst failure of this design is that it misses a
merchant and we keep today's bug there. It cannot invent one.

### D2 — Specific beats broad, in both directions

Resolution walks, per network, most-specific-first:

1. `merchant_entity` — this exact store
2. `merchant_group` — an existing curated group
3. `brand_pattern` — token-boundary match on the normalized name

then channel specificity (`in_store`/`online` beats `any`), then longer pattern,
then fresher `verified_at`, then rule id for determinism.

A specific `accepts = true` therefore overrides a broad `accepts = false`. That
is not decoration — it is the only way to express §1.4 without either dropping
the parent rule or asserting something false about the exception.

### D3 — `brand_pattern` is the workhorse, not the fallback

It is the only scope that reaches a store row that does not exist yet, and it is
the only scope that works on the public web tool (which runs on the anon key,
where `merchant_group_memberships` is not readable). The whole seed is
brand-pattern rows: no UUID is hardcoded, the file is environment-portable, and
one row per banner covers every branch of it forever.

Reach against **live production data**, after applying:

```
zehrs                    → Zehrs, Zehrs Laurentian, Zehrs Stanley Park, Zehrs Stratford
nofrills   (contains)    → Mike's NOFRILLS Woodbridge, Steve's NOFRILLS Etobicoke
no frills  (contains)    → No Frills, Jim & Maria's No Frills
real canadian superstore → Real Canadian Superstore
loblaws / fortinos / valumart / atlantic superstore / maxi / provigo / wholesale club → 1 each
costco                   → Costco
```

and **not** `Zehrsville Market`, `Sobeys King Street`, `Shoppers Drug Mart`, or
any gas, pharmacy or general-retail chain. Four legacy-format rows needed
entity-scoped rules instead — §4.1.

---

## 3. What the engine does with it

`scoreWalletForPurchase` gains one optional argument — a resolved
`network_id → verdict` map for this merchant and channel — and one sort key.

### D4 — Hard partition, not a penalty

```
1. acceptanceRank asc     ← NEW. declined cards after accepted ones, always
2. netValueExactCents desc
3. fxUnknownRank asc
4. …unchanged
```

There is no exchange rate between "earns more" and "does not work", so there is
no penalty value that would be correct. A declined card ranks last among
declined cards; an accepted card ranks first even if it earns a cent. The map
being empty makes level 1 constant, which is what makes flag-off byte-identical.

### D5 — The value stays honest

The declined card keeps its computed `effectiveValueCents`. It is unusable
*here*, not worthless — zeroing it would misstate the card, and the user still
deserves to see what they gave up. What changes is position and a label:

- `recommendations[].acceptance` — the structured payload (network, scope,
  channel, evidence URL, verified date, rule id, English reason)
- the same sentence pushed into `warnings[]`, so the **1.0.3 builds already on
  TestFlight** show something true instead of silently reordering
- `walletAcceptanceNotice` at the response level, and **only** when every
  scoreable card was declined — the case a ranking cannot express, because such
  a list still has a rank 1

### D6 — Three places a declined card must not sneak back to the top

- **Tie disclosure.** A tie is a claim that two cards are equally good choices.
  Acceptance joins the tie key, so a declined card and an accepted one with the
  same rounded value are never grouped.
- **Pinned overrides.** A pin is a preference among cards the user *can* use.
  It cannot promote a declined card; the response says why instead.
- **Portal alternatives.** Deliberately *not* given the map. A portal booking is
  a purchase from the issuer's travel vendor, and the issuer accepts its own
  card — suppressing an Amex portal option because a Zehrs won't take Amex in
  the aisle would be flatly false. `channel = 'portal'` is never evaluated.

---

## 4. Evidence discipline

Acceptance is a **merchant** fact, so rule 7 ("never invent card facts") does not
literally bind it. The same discipline is applied anyway, because a wrong row
here removes a card from someone's ranking, which is as consequential as a wrong
earn rate. `evidence_url` and `verified_at` are NOT NULL.

Seed `deltas/2026-08-17__network_acceptance_rules__seed_p1.sql`, three blocks:

| Block | Rows | Confidence | Basis |
|---|---|---|---|
| 1 — Loblaw banners named by both sources | 10 | high | Loblaw's own "Why don't you accept American Express?" help page + two independent secondary sources |
| 2 — remaining Loblaw banners | 6 | **medium** | Covered only by the sources' general statement, not named individually. **Review before running; deletable without touching block 1.** |
| 3 — Costco (warehouse / online split) | 4 | high | Forbes Advisor Canada; Amex ended Dec 2014 |

Pass 2 (`…__seed_p2_legacy_names.sql`, 5 rows, entity-scoped) closed a gap the
pass-1 reach sweep found — see §4.1.

### 4.1 What the reach sweep caught

Running the false-positive query against live data did its job. Twenty
brand-pattern rules reached every Loblaw/Costco entity **except four**, all of
them in the retired normalizer formats from `DESIGN_place_resolution_v1.md` §1.5:

| Entity | `normalized_name` | Format |
|---|---|---|
| Costco Gas | `costco_gas` | underscore |
| No Frills *(a second row)* | `no_frills` | underscore |
| Wholesale Club | `wholesale_club` | underscore |
| Loblaws Carlton Street | `loblawscarltonstreet` | squashed |

No brand pattern can reach them, and none should be made to: the
`nar_brand_pattern_normalized` CHECK forbids underscores precisely because a
pattern in a format the resolver never emits would silently match nothing.
Loosening it would trade a visible gap for an invisible one. They are fixed with
`merchant_entity`-scoped rules instead — the layered model doing what it was
built for.

These rows are also a merchant-graph defect (one brand split across several
ids). Repairing that is audit-class DML under the 2026-08-12 decision and is
deliberately out of scope; if the graph is later deduped these rules cascade
away with the entity and the brand pattern covers the survivor.

Two honesty notes that belong in the record rather than buried in a comment:

- The Loblaw help page's **title** is dispositive of the policy; its **body**
  could not be machine-read in session (client-rendered SPA). Verify lane
  re-reads it and, if it enumerates banners, promotes block 2.
- **Shoppers Drug Mart is deliberately unseeded.** The sources conflict.
  Conflicting Tier-2 sources support no assertion in either direction, so
  fail-open leaves Amex recommendable there — today's behaviour. This is the
  highest-value open item; settle it against Shoppers' own payment-methods
  article.

---

## 5. Rollout

Flag `runtime_flags.network_acceptance`, seeded **OFF** by the migration. Read
per request, so flipping it back is a rollback with no deploy.

1. ~~Apply the migration.~~ **DONE 2026-08-17**, remote version
   `20260817182517_network_acceptance_rules`; the local file was renamed to
   match it exactly (rule 9(e)).
2. ~~Run the seed deltas.~~ **DONE** — 20 brand-pattern rows (p1) + 5
   entity-scoped rows (p2) = 25. All guards passed.
3. ~~Run the reach + false-positive sweep.~~ **DONE** — see §4.1. Every match is
   a genuine Loblaw banner or Costco; Shoppers, Sobeys, Metro, the gas chains
   and `Zehrsville Market` are untouched.
4. **NEXT:** commit both repos, run `pnpm engine:bundle` + `build:contracts` +
   `typecheck` + `lint`, deploy the three edge functions.
5. Ship a build that renders the badge (server can lead; 1.0.3 degrades to the
   warning string).
6. Flip the flag by its own dated delta. **Not done — the flag is OFF.**

Move `recommend-card-v2` and `recommend-here-v2` together — the API-008 parity
contract. A card that disappears on tap-through, or appears in the nearby list
and not on the card screen, is worse than either behaviour alone.

**Drift signal.** `topCardId` cannot show that acceptance fired: on a wallet with
one Amex and two Visas the top card is the same either way, and the whole point
is what did *not* get recommended. `recommend-card-v2` logs
`acceptanceDemotedCards`, `acceptanceNetworks`, `allCardsUnaccepted` instead.

---

## 6. Open items

1. **Shoppers Drug Mart / Pharmaprix — conflicting sources.** Settle it. (§4)
2. **Block 2 banners** — Provigo, Maxi, Atlantic Superstore, Wholesale Club,
   Extra Foods, Dominion. Promote to high or expire. (§4)
3. **PC Express / online Loblaw** — unverified. No `online`-scoped Loblaw rule
   exists, so the `any`-scoped rules currently cover online too. If PC Express
   differs, add an `online` row; it will outrank the `any` row automatically.
4. **Merchant-graph dedup** — the four legacy-format rows in §4.1 are duplicate
   entities. Audit-class DML; not touched here.
5. **Gas bars and non-grocery Loblaw formats** — Esso/Mobil sites carrying
   Loblaw loyalty are *not* Loblaw POS. Do not pattern-match them in.
6. **Merchant-group scope on the stateless path** — cannot fire (anon RLS on
   `merchant_group_memberships`). Either grant anon read or keep leaning on
   brand patterns. Currently: brand patterns.
7. **Debit / Interac** — out of scope. `networks` has three rows, all credit.
8. **`apps/web` `serverRanking.ts`** — untouched, and correctly so: it scores an
   assumed $100 purchase per category with no merchant context, so there is
   nothing to apply acceptance to.

---

## 7. Files

| File | State |
|---|---|
| `supabase/migrations/20260817182517_network_acceptance_rules.sql` | **APPLIED** 2026-08-17 (renamed from the 20260817140000 authoring stamp to match remote history) |
| `deltas/2026-08-17__network_acceptance_rules__seed_p1.sql` | **APPLIED** — 20 brand-pattern rules |
| `deltas/2026-08-17__network_acceptance_rules__seed_p2_legacy_names.sql` | **APPLIED** — 5 entity-scoped rules for legacy-format rows (§4.1) |
| `supabase/functions/_shared/networkAcceptance.ts` | new — pure matching + resolution + loader |
| `supabase/functions/_shared/scoring.ts` | partition, per-card payload, pinned guard, wallet notice, `networkMap` |
| `supabase/functions/_shared/tieDisclosure.ts` | acceptance joins the tie key |
| `supabase/functions/recommend-card-v2/index.ts` | resolve + pass + disclose + log |
| `supabase/functions/recommend-here-v2/index.ts` | same, per candidate; one flag read per request |
| `supabase/functions/recommend-cards-stateless-v1/index.ts` | same, anon client |
| `packages/engine-contracts/src/networkAcceptance.ts` | new — `CardAcceptanceV1`, `WalletAcceptanceNoticeV1` |
| `packages/engine-contracts/src/{recommendCardV2,recommendHereV2,recommendCardsStatelessV1,index}.ts` | additive fields |
| `apps/mobile/src/components/CardAcceptanceBadge.tsx` | new |
| `apps/mobile/src/components/CardCarousel/CarouselCardItem.tsx` | badge takes the TOP PICK slot when rank 1 is declined |
| `apps/mobile/src/components/recommendations/WhyThisCardReceipt.tsx` | caveat line above the total |
| `apps/mobile/src/i18n/locales/{en,fr}.json` | 4 keys each, parity holds |
| `supabase/functions/__tests__/network_acceptance_api_019.test.ts` | new — 26 tests |

**Verification run 2026-08-17:** `deno test __tests__/` → **370 passed, 0
failed** (26 new + the full existing suite, including the QA-009 golden pack and
the API-016 tie suite). Migration and seed executed against a scratch Postgres
16: guards fire, constraints reject non-normalized patterns and multi-target
rows, re-running the seed ROLLBACKs.

**Not run:** `pnpm engine:bundle`, `pnpm build:contracts`, `pnpm typecheck`,
`pnpm lint`, `pnpm verify:i18n-parity` (key-set parity was checked directly:
711 = 711, identical sets). Run these before committing — the vendored
`_shared/engine-contracts` copy must be regenerated, never hand-edited.
