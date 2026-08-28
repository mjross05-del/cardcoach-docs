# DESIGN — Online Merchant Recommendation v1 (Pro)

Date: 2026-08-17 · Status: **SHIPPED — see §7a.** · Author: Cowork session (Claude)
Sign-off was needed on: D1–D9 (§2) before any code was written.

> **CORRECTION 2026-08-27.** The header said "DRAFT for review" and "before any code is
> written" while §7a of this same file lists five migrations applied to production on
> 2026-08-17, a 140-merchant catalogue seeded, and `runtime_flags.online_merchant_resolution`
> seeded true. Verified: that flag is **enabled = true** (updated 2026-08-17 01:32:36 UTC).
> §7a is the accurate section; this header was never bumped.

**Scope note (Mike, 2026-08-17):** this ships inside the paid **Pro** feature set. Pro does not
exist yet — there is no entitlement infrastructure anywhere in the tree (§1.8). Nothing here is
built until the Pro surface lands. This document is the design that waits for it.

All code paths are relative to `CardCoachv2/mobile_app_codebase/` unless prefixed otherwise.
Current-state claims are cited `file:line` against working tree at commit `11b601b` (2026-08-17).
Live-DB counts are from `card_coach_advanced` (`hrzpznlpmxxrbtwskacu`), read 2026-08-17.

---

## 0. What the feature is

The user is about to buy something on a website. They tell CardCoach which store, and CardCoach
ranks their wallet for that purchase — the same answer the Now screen gives at a physical till,
for a merchant that has no physical till.

Three things make the online answer different from the in-store answer, and all three are
already modelled in the database but unreachable from any client:

1. **Some rates only exist online.** Costco's 2% is `Costco.ca online` only; Home Hardware's
   Scene+ rate names `homehardware.ca`; Cathay's 4x names `cathaypacific.com/ca`.
2. **Travel bought online has a portal alternative.** 24 active `portal_only` rows say "book the
   same trip through Expedia For TD / CIBC by Expedia / Scene+ Travel and earn more." At a
   physical till that is noise. In a browser it is the single highest-value thing we can say.
3. **Online purchases cross borders.** FX cost is already computed per card and already
   suppressed to zero for domestic spend. Online is where it stops being zero.

---

## 1. Current state (verified 2026-08-17)

### 1.1 `channel` is carried end-to-end and gates exactly one thing

The enum `('in_store' | 'online' | 'portal')` is defined once
(`packages/engine-contracts/src/recommendCardV2.ts:32-37`) and defaults to `in_store` on both
authenticated request contracts (`recommendCardV2.ts:70`, `recommendHereV2.ts:66`). The same
three values are constrained identically in four places in the schema
(`0004_offers_applicability_v2.sql:53,125`, `0015_offers_v3_typed_bonuses_scoping.sql:117`,
`0044_user_card_personalization.sql:69,183`).

In scoring, `channel` is read in exactly one predicate — `portal_only` gating:

```ts
if (condition === "portal_only") {
  return input.channel === "portal";
}
```
`supabase/functions/_shared/scoring.ts:1233-1234`, defaulting at `:1589`.

Nothing else in the engine reads it. **`HOW_THE_ENGINE_WORKS.md:210` is therefore wrong** — it
says channel "is passed through for future use, but it does not currently affect scoring," which
was true before `portal_only` gating landed and is not true now. Correct it on sight (that file's
own §"Engine Evolution" convention).

`portalId` is validated and then dropped: required when `channel === 'portal'`, forbidden
otherwise (`recommend-card-v2/index.ts:87,100-111`; `recommend-here-v2/index.ts:81,84-95`), and
read nowhere in `_shared/scoring.ts`. So the engine knows *that* a purchase is on a portal, never
*which* portal. Harmless today — `portal_only` rows belong to the card whose portal they describe
— but it means a portal recommendation cannot currently be attributed to a named portal in the
response.

### 1.2 The client-side channel switch is dead wiring

Mobile persists `channel` in purchase-context prefs with default `in_store`
(`apps/mobile/src/prefs/purchaseContextPrefs.ts:19`,
`apps/mobile/src/contexts/PurchaseContextPrefsContext.tsx:36`) and exposes a setter
(`PurchaseContextPrefsContext.tsx:79-81`). **`setChannel(` has zero call sites in any screen or
component.** The value is written once at defaults and never changes.

The strings for the missing UI already exist: `screens.storeDetail.channelLabel` = "Purchase
type", `channel_in_store`, `channel_online`, `channel_portal` = "Travel portal"
(`apps/mobile/src/i18n/locales/en.json:312-315`). `grep -r storeDetail apps/mobile/src` returns
hits only inside the locale files — the screen those keys were written for was never built.

### 1.3 The blocker: merchant identity is Google-Place-anchored

`zRecommendCardV2Request.merchantPlaceId: z.string().uuid()` is **required, not optional**
(`recommendCardV2.ts:67`; echoed on the response at `:319`). That UUID is a
`merchant_entity_places.id` — the mobile client explicitly resolves it that way
(`apps/mobile/src/services/api.ts:25-28`, comment: "Use V2 schema to get the correct
merchantPlaceId (UUID) for recommend-card-v2").

`merchant_entity_places` is `UNIQUE(place_id)` over a Google place id
(`0009_canonical_merchant_entities.sql:34-42`). An online-only merchant has no Google place, so
**there is no way to ask the authenticated engine about one.** This is the whole feature gap in
one sentence.

`recommend-cards-stateless-v1` does accept `merchantEntityId` / `categoryId`
(`recommendCardsStatelessV1.ts:162-163`) — but it is stateless by construction: no wallet, no
caps, no spend snapshots, offers excluded by design. And nothing ships against it: `grep -rn
"functions/v1\|invoke(" apps/web/src` returns **zero hits**; the only callers are verify scripts
(`scripts/verify_api_010_*.mjs`, `verify_api_011_*.mjs`, `verify_pkg_009_*.mjs`,
`sweep_value_ledger.mjs`). The web app ranks locally in `apps/web/src/lib/serverRanking.ts`.

### 1.4 The online merchants are already in the graph — and every one is uncategorized

Live DB, 2026-08-17: **458** `merchant_entities`, **419** `merchant_entity_places`, **104**
entities with no place row, **112** with `default_category_id IS NULL`.

The placeless set is largely the online catalogue we would want, arrived via the DATA-018/019
seeds and offer scoping: Amazon.ca, Amazon Prime, Netflix, Spotify, Disney+, Crave, Apple Music,
DoorDash, Uber Eats, SkipTheDishes, Instacart, Airbnb, Booking.com, Expedia, Wayfair, Best Buy,
Walmart, Home Depot, Lowe's, RONA, Air Canada, WestJet, Porter Airlines, Marriott, Hilton.

**Every one of those rows carries `default_category_id = NULL`.**

`recommend-card-v2` derives the purchase category from exactly one place —
`merchantEntity?.default_category_id ?? null` (`recommend-card-v2/index.ts:288`) — and has no
classifier fallback (WORKING_NOTES #26, and the live 2026-08-15 Harvey's incident recorded
there). A NULL category means base-rates-only for every card in the wallet. So wiring identity
without doing the category work would ship a feature that confidently returns the wrong answer
for every merchant it resolves. **The data work is the feature; the plumbing is the small part.**

### 1.5 `online_retail` is a trap, not a destination

`categories` contains `online_retail` ("Online Retail", `0049_data_repair.sql:113`). It is
referenced by **7 `mcc_category_mappings` rows** — including 5968 and the 5964–5969 block, i.e.
the direct-marketing/catalogue MCCs — and by **0 active `earn_rates`.**

Routing resolved online merchants to `online_retail` therefore scores every card at base rate
while *looking* correct. The Neo "Shop" schedule already documents the same instinct and the same
correction: 79 of 94 codes map to `retail_shopping`, and the rest "keep prior homes
(home_improvement, online_retail, streaming) and pay base." Online merchants must resolve to
their **real** category — amazon.ca is retail, walmart.ca is whatever Walmart is, netflix.com is
streaming. `online_retail` stays what it is: the home for MCCs that genuinely mean "catalogue and
direct marketing," which no card in the catalogue currently pays a bonus on.

### 1.6 What the data already supports for online

- **24 active `portal_only` rows**, every one a travel portal: Expedia For TD (TD Rewards, First
  Class Travel, Platinum Travel, Business Travel), CIBC by Expedia / CIBC Rewards Centre
  (Aventura ×4, Dividend ×3, Adapta ×2, US Dollar Aventura), Scene+ Travel Powered by Expedia
  (Scotia Gold Amex, Passport VI, Passport VIP, Scene+ standard), À la carte Travel Agency
  (National Bank Rewards ×4), Tangerine travel.
- **13 active rows whose fine print names an online-only condition** — Costco.ca online
  (`merchant_list_only`), homehardware.ca, cathaypacific.com/ca, Amex Travel Online ×4 (`other`),
  aircanada.com, and the two Neo "Recurring" MCC schedules.
- **FX is modelled end to end already.** `spendCurrency` on request
  (`recommendCardV2.ts:103-107`, same on the stateless contract), `fxFeePercent` / `fxFeeApplies`
  / `fxFeeKnown` on the response (`:218-226`), with `fxFeeKnown === false` explicitly meaning
  *unverified, not zero* (`:223-224`). The mobile Now screen already has a currency selector
  (`components/recommendations/SpendCurrencyFooter.tsx`).
- **Category coverage for online-native spend:** `recurring_bills` 36 rows / 34 cards,
  `entertainment` 21/21, `streaming` 17/17, `food_delivery` 11/11, `e_games` 8/8,
  `foreign_currency_spend` 6/6, `retail_shopping` 2/2, `shipping` 1/1.

### 1.7 Runtime flags in production

`loyalty_offer_stacking=true`, `merchant_mcc_assumption=true`, `tie_disclosure=true`. The
established pattern — seeded `false` by migration, flipped by dated delta, read once per request,
**fails closed to disabled on any error** (`_shared/scoring.ts:669-682`, and the same shape in
`_shared/categoryMccAssumption.ts:57-71`) — is what this design reuses.

### 1.8 The entitlement primitive already exists — code written, schema unapplied

**CORRECTED 2026-08-17.** The first draft of this section claimed no entitlement infrastructure
existed anywhere. That claim was produced by a grep scoped to `apps/*/src`, `packages/*/src` and
`supabase/migrations` — which excluded `supabase/functions/`, where the entitlement system
actually lives. The claim was wrong; this is what is really there.

**ENT-001** (`docs/planning/specs/ENT-001_entitlements.md`, PROPOSED 2026-08-16, awaiting Mike's
sign-off on its D1–D6 and its schema) already specifies and part-builds the primitive:

- `supabase/functions/_shared/entitlements.ts` — `hasEntitlement(userClient, key)`, reading
  `v_active_user_entitlements` through the **RLS-scoped user client** (not the admin client — the
  file documents that as the security property, not an optimisation), failing closed on every
  error path and logging errors distinguishably from denials.
- `supabase/functions/_shared/runtimeFlags.ts` — a generic `isRuntimeFlagEnabled(client, key)`,
  written precisely so new features stop hand-rolling a fourth per-feature flag reader.
- `apps/mobile/src/hooks/useEntitlement.ts` — the client hook, fail-closed, re-checked on
  foreground, gating *presentation only*.
- ENT-001 D1 is emphatic and correct: **the unit of access is a named entitlement key, never an
  "is this user Pro" boolean**, so the tier's name, price and contents can change without
  touching feature code.

**The `user_entitlements` table and `v_active_user_entitlements` view are NOT in the database** —
`information_schema` shows neither. So `hasEntitlement()` currently hits a missing relation, logs,
and returns `false` for every caller. That is not a defect; it is precisely the state Mike asked
for on 2026-08-17 — fully built, deployed, and unreachable.

**Consequence for this design:** D7 is rewritten below. This feature does not invent a gate. It
adds one key to ENT-001's existing mechanism, and it shares the Pro gate with the receipt scanner
(API-017 / APP-021). Both features unlock when ENT-001's schema is applied, which is Mike's
decision on a spec that is still awaiting his sign-off — not something this design may assume.

Also carried from ENT-001's Context, unresolved and worth Mike's attention: `REVENUE.md` still
says *"Pro tier — out of scope. Current pricing IS the iOS monetization"*, and WORKING_NOTES #13
flags that the live site already markets a deferred Pro tier. Both need a dated reconciliation
once the paid tier is real.

### 1.9 Interaction with the in-flight place-resolution design

`DESIGN_place_resolution_v1.md` (2026-08-12, DRAFT) is **not implemented**: both mint paths are
still live in production code — `resolve-place/index.ts:557` and `recommend-here-v2/index.ts:307`
still INSERT `merchant_entities` on a miss. (The category self-heal writes *are* gone —
WORKING_NOTES #26, commits `86c6110` / `cc445e2`.)

That design's §2.6 already plans a `provider` discriminator on `merchant_entity_places`
(`'google' | 'apple' | …`), with existing rows backfilling to `'google'`. **This design depends
on that column and adds one provider value to it.** Whichever ships first cuts the migration; the
other consumes it. They must not both write it.

---

## 2. Decisions for sign-off

### D1 — Identity is a curated domain, and it reuses `merchant_entity_places`

A new curated table maps a registrable domain to an existing merchant entity:

```
merchant_domains(domain, merchant_entity_id, category_override, billing_currency, …)
```

and each online merchant additionally gets **one synthetic `merchant_entity_places` row** with
`provider = 'domain'` and `place_id = 'domain:amazon.ca'`.

**Why the synthetic place row is the whole trick.** It means `recommend-card-v2` needs **no
contract change**: the resolver hands back a `merchant_entity_places.id` UUID and the client calls
the existing endpoint exactly as it does at a physical till. Downstream, everything keeps working
for free — `record-transaction` is place-keyed, so online purchases log to `transactions` and roll
into `user_spend_snapshots` and cap progress with zero new code. The online path becomes
**byte-identical to the in-store path** below the resolver, which is also what makes it testable
against the existing verify suite.

The alternative — adding `merchantEntityId` as an optional alternative to `merchantPlaceId` on
`recommend-card-v2` — is *architecturally cleaner* and will eventually be wanted (see O2), but it
touches the single most load-bearing production contract, its edge function, the mobile client,
`record-transaction`, and four verify scripts. Not for v1.

### D2 — The runtime never creates an online merchant

Same discipline as `DESIGN_place_resolution_v1` §2.4, for the same reason (§1.4 of that document:
four duplicate Real Canadian Superstore rows, one of which no committed code can explain).
Unknown domain ⇒ `merchant_entity_id: null` ⇒ the caller gets a base-rate ranking, correctly
labelled as such — plus one `verify.parking` row, `topic: 'online_merchant_unresolved'`, `observed`
= `{ domain, raw_input, locale, requestId, seen_count, first_seen }`.

That queue is not a chore; it is the **demand signal**. It tells us exactly which stores paying
users are actually shopping at, ranked by frequency, which is the curation worklist and a genuinely
useful piece of product intelligence besides.

### D3 — Category comes from the domain row first, entity second, never from `online_retail`

Resolution order for the purchase category:
`merchant_domains.category_override` → `merchant_entities.default_category_id` → `null`.

`category_override` exists for the one case that actually needs it: a brand whose online
storefront is categorized differently from its stores by the issuers' own wording. It is NULL for
the overwhelming majority. Per §1.5, `online_retail` is never a resolution target.

**A domain row may not ship with both `category_override` and its entity's category NULL.** That
is a data invariant, enforced in the seed migration's guards, because such a row is a silent
base-rate answer wearing a merchant's name.

### D4 — Channel-restricted earn rows get `channel_includes`, fail-open

Add `earn_rates.channel_includes text[]`, NULL = applies on every channel. A row prices when
`channel_includes IS NULL OR channel = ANY(channel_includes)`, evaluated inside the existing
`earnRowPrices` predicate (`scoring.ts:1217-1250`) so that suppressed rows are disclosed by the
same predicate that priced them — the API-011 `conditionalNotApplied` machinery gets it for free.

NULL-default means **every existing row prices byte-identically to today**, which is the same
property `floor_monthly_cad` and `window_bucket` were given (`HOW_THE_ENGINE_WORKS.md:89`).
Population is Tier 1/1b only, per rule 7 — the ~13 rows of §1.6 are the candidate set, and
several are already correctly gated by `merchant_list_only` and need nothing.

### D5 — The portal alternative is disclosed, never ranked

When the resolved merchant/category is travel and a wallet card carries a `portal_only` row that
would beat the winning in-channel option, the response carries a new optional
`portalAlternatives[]` array. It is informational: **it never enters the ranking, never changes
`topCardId`, and is computed once.**

This is deliberately the `membershipEarn` pattern — "constant across the wallet, so it is computed
once and NEVER folded into any recommendation" (`scoring.ts:1584`, API-014). Ranking a portal rate
against a direct rate would be dishonest: they are different purchases, at possibly different
prices, from a different vendor. Telling the user "the same hotel booked through Scene+ Travel
earns 4x instead of 1x, and here is what that is worth on this amount" is honest, and it is the
most valuable sentence this feature can produce.

Because `portalId` is currently dropped (§1.1), naming the portal requires reading it off the
`portal_only` row's own `condition_text`/`display_label` rather than off the request. That is a
display concern, not an engine one.

### D6 — Entry point: in-app search and paste, share sheet second

v1: an **Online** mode on the Now screen. The user types a store name or pastes a URL; we resolve
against our own catalogue only — no Google, no provider spend, no new permission prompt, and it
works identically on iOS, Android and web from one contract. URL handling extracts the registrable
domain client-side and sends only that (`https://www.amazon.ca/dp/B0…?ref=…` → `amazon.ca`); the
full URL, its path and its query string never leave the device.

Phase 2 is the native share sheet (iOS Share Extension / Android `ACTION_SEND`), which is the
genuinely low-friction moment and a strong Pro differentiator — but it is Expo native-module work
plus a store review cycle, and it is a thin client over the identical resolver. A desktop browser
extension is out of scope for v1: separate codebase, separate review, no reuse of the app.

### D7 — Reuse ENT-001's gate; add one key, invent nothing

**REVISED 2026-08-17 after §1.8's correction.** The original D7 proposed a bespoke
`hasProEntitlement(userId)`. That would have been a second, worse copy of a mechanism that already
exists and is better designed. Superseded.

Two gates, both from existing shared helpers:

- `isRuntimeFlagEnabled(client, 'online_merchant_resolution')` (`_shared/runtimeFlags.ts`) — the
  operational kill switch. Per Mike's 2026-08-17 direction this ships **`true`**, deliberately
  departing from the seeded-false house pattern, because the entitlement gate is the one holding
  the feature shut and launch should be a single action.
- `hasEntitlement(userClient, ENTITLEMENT_ONLINE_MERCHANT)` (`_shared/entitlements.ts`) — the paid
  gate. `ENTITLEMENT_ONLINE_MERCHANT = "online_merchant"` is added beside the existing
  `ENTITLEMENT_RECEIPT_SCANNER`, honouring ENT-001 D1: a **named key, never a Pro boolean**.

The user client, not the admin client, is passed — ENT-001's security property, restated here so
it is not lost in a copy-paste: the query is RLS-self-limiting, so a bug in this feature cannot
confer someone else's entitlement.

Today both `hasEntitlement` calls fail closed against a missing relation (§1.8), so the feature is
deployed and unreachable. Nothing about this design decides when that changes: applying ENT-001's
schema is Mike's call on Mike's spec.

Scoring still never learns what a tier is. `DESIGN_place_resolution_v1` §2.2's constraint —
"model-agnostic… never a hardcoded tier" — binds the engine, and it holds: the *endpoint* refuses,
the *engine* is unaware. A user without the entitlement who somehow reaches `recommend-card-v2`
with `channel: 'online'` gets a correct answer, not a broken one; they simply have no way to
obtain an online merchant id.

Mobile gates presentation with the existing `useEntitlement(ENTITLEMENT_ONLINE_MERCHANT)` hook —
which, as ENT-001 puts it, gates presentation only: the server re-checks on every call and a
client that lies gains nothing.

### D8 — FX is pre-filled from the domain, and never asserted without evidence

`merchant_domains.billing_currency` (nullable, Tier 1/1b or observable-fact evidence in
`source_notes`) lets the client pre-select `spendCurrency` for a merchant that bills in USD, so
the FX cost the engine already computes actually reaches the user at the moment it matters. NULL
means "we don't know" and the client behaves exactly as today. `fxFeeKnown === false` continues to
mean *unverified, not zero* (`recommendCardV2.ts:223-224`) — this design does not weaken that.

### D9 — iOS first, web second

Pro is the iOS surface (REVENUE.md: $3.99/mo · $34.99/yr, 40.4% of the 24-month model), the
mobile client already carries the dead `channel` pref and the missing screen's translations, and
1.0.3 is in flight. The web app is a bigger lift than it looks — it calls no edge functions at all
today (§1.3) — and the free web tool is the wrong home for a paid feature anyway.

---

## 3. Contract draft

New edge function `resolve-merchant-v1`. Types land in
`packages/engine-contracts/src/resolveMerchantV1.ts` (types only, mobile-safe, per `CLAUDE.md`
boundaries).

### 3.1 Request

```ts
type ResolveMerchantV1Request = {
  schemaVersion: 1;
  locale: "en" | "fr";
  /** EITHER a registrable domain extracted client-side… */
  domain?: string;      // "amazon.ca" — never a full URL, never a path or query
  /** …OR free text from the search field. */
  query?: string;       // "amazon"
  limit?: number;       // query mode only, default 8, max 20
};
```

Exactly one of `domain` / `query`; 400 otherwise. Auth: user JWT verified before any work
(`resolve-place/index.ts:200-216` pattern — 401 `not_authenticated`), then the Pro gate (D7),
then the flag (D7).

### 3.2 Response

```ts
type ResolvedMerchant = {
  merchantPlaceId: string;        // synthetic merchant_entity_places.id — feeds recommend-card-v2 unchanged
  merchantEntityId: string;
  displayName: string;
  domain: string;
  categoryId: string | null;      // per D3
  billingCurrency: string | null; // per D8
  confidence: "domain" | "alias" | "exact" | "prefix";
};

type ResolveMerchantV1Response = {
  schemaVersion: 1;
  results: ResolvedMerchant[];    // domain mode: 0 or 1; query mode: 0..limit
  parked: boolean;                // true when a verify.parking row was written (D2)
  requestId: string;
};
```

Zero results is a first-class outcome, not an error. The client then offers the existing
`search-places` picker (physical store) or a plain "we don't have this store yet" state — never a
silent base-rate ranking presented as a merchant answer.

### 3.3 Writes the resolver is allowed

`verify.parking` INSERT on a miss (D2). **Nothing else.** No `merchant_entities`, no
`merchant_domains`, no `merchant_entity_places`, no aliases. Every row in the online graph is a
reviewed, dated migration or delta.

### 3.4 What changes on `recommend-card-v2`

Request contract: **nothing** (D1). Response contract: one optional additive field,
`portalAlternatives?: PortalAlternativeV1[]` (D5), absent unless the flag is on and a qualifying
row exists — the same "response-level optional fields only, no new explanation-item types"
invariant that governed APP-018.

---

## 4. Schema proposal

Per rule 9, each change with its reasoning, read-path impact and rollback. Two migrations, both
additive; no column is dropped, no existing row is rewritten.

### 4.1 `merchant_entity_places.provider`

```sql
ALTER TABLE merchant_entity_places ADD COLUMN provider text NOT NULL DEFAULT 'google';
ALTER TABLE merchant_entity_places ADD CONSTRAINT merchant_entity_places_provider_check
  CHECK (provider IN ('google','apple','domain'));
-- UNIQUE(place_id) is retained and remains sufficient: 'domain:…' keys cannot collide
-- with Google place ids. A (provider, place_id) composite is deferred to the place-resolution
-- design, which needs it for Apple.
```

- **Read-path impact:** none. Every existing read filters on `place_id` or `merchant_entity_id`;
  the default backfills all 419 rows to `'google'` in place.
- **Rollback:** `ALTER TABLE merchant_entity_places DROP COLUMN provider;`
- **Coordination:** this is the same column `DESIGN_place_resolution_v1` §2.6 specifies. Ship it
  once, from whichever design lands first, with `'apple'` already in the CHECK so the other does
  not need a second migration.

### 4.2 `merchant_domains`

```sql
CREATE TABLE merchant_domains (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain             text NOT NULL,                       -- registrable domain, lowercase, no scheme/path
  merchant_entity_id uuid NOT NULL REFERENCES merchant_entities(id) ON DELETE CASCADE,
  category_override  text REFERENCES categories(id),      -- D3; NULL for most rows
  billing_currency   text CHECK (billing_currency ~ '^[A-Z]{3}$'),  -- D8; NULL = unknown
  source_notes       text NOT NULL,                       -- evidence + access date, rule 7
  valid_from         date NOT NULL DEFAULT CURRENT_DATE,
  valid_to           date,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT merchant_domains_domain_unique UNIQUE (domain),
  CONSTRAINT merchant_domains_domain_shape  CHECK (domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$')
);
```

RLS: `canonical_read` — anon/authenticated SELECT, no client write, matching every other canonical
fact table (`0021_auth_005_canonical_facts_readonly_rls.sql`). Time-windowed like the other fact
tables so a domain that changes hands is expired, not deleted (rule 9(c)).

- **Read-path impact:** additive; nothing reads it until `resolve-merchant-v1` exists.
- **Rollback:** `DROP TABLE merchant_domains;`

### 4.3 `earn_rates.channel_includes`

```sql
ALTER TABLE earn_rates ADD COLUMN channel_includes text[];
ALTER TABLE earn_rates ADD CONSTRAINT earn_rates_channel_includes_valid CHECK (
  channel_includes IS NULL OR (
    array_length(channel_includes, 1) > 0
    AND channel_includes <@ ARRAY['in_store','online','portal']::text[]
  )
);
```

- **Read-path impact:** NULL on all 605 active rows ⇒ every card prices byte-identically until a
  row is deliberately populated with issuer-verified wording (D4, rule 7).
- **Rollback:** `ALTER TABLE earn_rates DROP COLUMN channel_includes;`
- **Guard discipline:** any delta that populates it asserts the pre-state row count and the
  post-state row count and rolls back on surprise (rule 9(d)).

### 4.4 Seed (DATA-020, separate migration, guarded replay)

Entities first (attach to the existing rows of §1.4 — **do not create a second "Amazon.ca"**;
the RCSS incident is what that costs), then their categories, then domains, then synthetic place
rows. `ON CONFLICT DO NOTHING` throughout, with rowcount assertions.

---

## 5. The data work (this is the real cost)

The plumbing above is perhaps a week. The data is the feature:

1. **Categorize the ~25 online-native entities that already exist** (§1.4) — every one is NULL
   today, and each one is a wrong answer waiting to be served. These flow through the existing
   `verify.merchant_category_observations` / `public.propose_merchant_category` review surface
   (`verify.v_merchant_category_review`), or as a hand-cut delta with the same evidence standard.
2. **Curate a launch catalogue.** Target the top online destinations for Canadian cardholders —
   marketplaces, the big-box `.ca` storefronts, grocery delivery, food delivery, streaming and
   subscriptions, airlines, hotels and OTAs, telecom self-serve. Roughly 100–150 domains reaches
   the long tail's knee; the parking queue (D2) then drives every addition after launch with real
   evidence of demand instead of a guess.
3. **Backfill `channel_includes`** on the ~13 rows of §1.6 that carry explicit online-only issuer
   wording, Tier 1/1b only, leaving anything ambiguous NULL. Several of those rows are already
   correctly handled by `merchant_list_only` and need nothing at all.
4. **Verify `billing_currency`** only where it is a plain observable fact of the storefront.
   Unknown stays NULL.

None of this invents a card fact. Domain→brand and storefront currency are observable facts about
a merchant, not assertions about a card, and they carry `source_notes` with an access date
regardless.

---

## 6. Rollout

1. Migration 4.1 (`provider`), coordinated with the place-resolution design so it ships once.
2. Migrations 4.2 + 4.3, both inert — nothing reads them yet.
3. DATA-020 seed + the category backfill. **Gate:** zero domain rows resolve to a NULL category
   (D3's invariant), asserted by the verify script, not by eye.
4. `resolve-merchant-v1` deployed with `online_merchant_resolution = true` and the
   `online_merchant` entitlement gate closed (Mike, 2026-08-17 — §D7). Deployed, reachable by
   nobody.
5. `channel_includes` evaluated inside `earnRowPrices`; ranking must be byte-identical on the
   existing scenario pack while every row is NULL — that is the regression test.
6. `portalAlternatives` (D5) behind the same flag.
7. APP client: Online mode on the Now screen, gated on `useEntitlement("online_merchant")`; this
   is where `setChannel` finally acquires a caller and `screens.storeDetail.*` finally acquires a
   screen.
8. **Launch is one action:** apply ENT-001's schema and grant the `online_merchant` key. Nothing
   in this feature needs a deploy at that point. **Kill switch:** flip
   `online_merchant_resolution` false — no deploy, and the app returns to today's behaviour
   exactly, since every online surface is additive and the in-store path is untouched.

**Verification, per house discipline:** `pnpm verify:api-018` (resolver contract, miss-parks,
no-mint assertions), `pnpm verify:data-020` (domain/category invariants, no orphan entities, no
duplicate brands), and the existing `verify:e2e` and 30-scenario pack must stay green — with a
pre/post ranking diff proving byte-identical output while `channel_includes` is universally NULL.

Suggested slice IDs, following the current numbering (highest today: DATA-019, API-017, APP-021):
**DATA-020** (online merchant graph + seed), **API-018** (`resolve-merchant-v1` + portal
alternatives), **APP-022** (Online mode UI), **APP-023** (share sheet, phase 2).

---

## 7. Cost

Zero provider spend. Resolution is entirely own-data: a domain lookup and a text search over
`merchant_entities` / `merchant_entity_aliases` / `merchant_domains`. This is the same free path
`DESIGN_place_resolution_v1` §2.5 specifies for web, and it is one of the reasons the online
feature is a good Pro candidate — margin is unaffected by usage.

Only the domain string is stored. Full URLs, paths and query strings never leave the device (D6),
which keeps the feature clear of the "what did this person browse" data class entirely — worth
stating plainly in the privacy copy, because a shopping-assistant feature invites exactly that
suspicion.

---

## 7a. Build status — 2026-08-17

Mike, 2026-08-17: build it fully, apply and deploy it, gate it on Pro only, full
100–150-domain catalogue. Against that instruction:

**Applied to production and verified**

| Migration | What |
|---|---|
| `20260817013135_online_merchant_p1_places_provider` | `merchant_entity_places.provider` (`google`\|`apple`\|`domain`), 421 rows backfilled `google` |
| `20260817013156_online_merchant_p2_merchant_domains` | `merchant_domains` + `v_active_merchant_domains`, canonical-read RLS |
| `20260817013209_online_merchant_p3_earn_rates_channel_includes` | `earn_rates.channel_includes`, NULL on all 605 active rows |
| `20260817013236_online_merchant_p4_runtime_flag` | `online_merchant_resolution`, seeded **true** |
| `20260817020859_data_020_online_merchant_catalogue_seed` | **140 merchants / 141 domains** |

Snapshots taken and secured before the first write, per rule 9(a):
`merchant_entities_snapshot_20260817` (459 rows), `merchant_entity_places_snapshot_20260817` (421),
`earn_rates_snapshot_20260817` (668) — each with RLS enabled and `anon`/`authenticated` revoked.

Live invariant check, run against production after the seed:

```
active_domains                 141
orphan_no_place_row              0     every domain reaches a usable merchantPlaceId
null_category                    0     no silent base-rate answer wearing a merchant's name
dead_category                    0     no online_retail / telecom_internet / costco
divergent_override               0
duplicate_domain                 0
entities_with_multi_place        0     one merchantPlaceId per merchant
bad_place_prefix                 0     every synthetic id namespaced "domain:"
channel_includes_populated       0     ranking provably byte-identical to before
flag_state                       online_merchant_resolution=true
entitlements_view                ABSENT (every caller refused)
```

The last two lines together are the requested state: **live infrastructure, shut door.**

The catalogue closed a live defect on the way past. 40 of the 140 merchants already existed as
placeless, category-NULL rows (Amazon.ca, Netflix, Best Buy, DoorDash, Walmart, Expedia, the
airlines) and were scoring base-rates-only on every tap. They are keyed to their existing
hand-seed underscore slugs — `amazon_ca`, `best_buy`, `skip_the_dishes` — so the seed joined them
rather than minting duplicates; that duplication is the Real Canadian Superstore incident, and it
is the reason the seed carries an explicit slug map instead of trusting the normalizer. Graph-wide
NULL categories fell 112 → 72.

**Code written and on disk**

- `packages/engine-contracts/src/resolveMerchantV1.ts` + export wired into `index.ts`
- `supabase/functions/_shared/onlineMerchant.ts` — host normalisation, longest-first label walk,
  domain and query resolution, `verify.parking` on miss. Reads only; writes nothing to the graph.
- `supabase/functions/resolve-merchant-v1/index.ts` — both gates, fail-closed
- `supabase/functions/_shared/entitlements.ts` — `ENTITLEMENT_ONLINE_MERCHANT` added (see the
  incident note below)
- `supabase/functions/_shared/scoring.ts` — `channel_includes` on the row type, in the select list,
  and gating **before** the condition switch (an unconditional row can still be online-only, and
  that switch returns early on `null`)
- `scripts/verify_data_020_online_merchant_graph.mjs` + `pnpm verify:data-020`

**The portal nudge (D5) — built 2026-08-17**

`supabase/functions/_shared/portalAlternatives.ts`, wired into `recommend-card-v2` and added to
the response contract as an optional `portalAlternatives[]`.

It is **self-gating by construction**: it re-scores the same in-memory context with
`channel: 'portal'` and diffs. Because `channel` gates exactly one thing — whether `portal_only`
rows price — the portal run is the direct run plus those rows, so a purchase with no relevant
portal row produces an identical result and nothing is emitted. No category allowlist to
maintain, and no way for the feature to drift from the rows it describes. No extra database work
either: the context is already loaded.

The comparison is **best-portal vs best-direct**, not per-card. The user's real question is
"should I book here or over there?", and that is answered by the best thing available in each
venue. A per-card diff would cheerfully announce a portal uplift on a card that is still worse
than simply using a different card right here.

Portal naming reads the issuer's own `condition_text` — the request's `portalId` is validated
and dropped by the engine, so it cannot be the source. A six-entry phrase list normalises the
rendering; **all 24 live `portal_only` rows name correctly**, verified by running every one
through the function, and an unrecognised portal falls through a regex to something specific
rather than something wrong. `conditionText` always travels verbatim alongside, because that is
the claim the user can actually check.

Ranking is untouched: the array is computed after `recommendations` and never fed back, so it
cannot move a rank or `topCardId`. Any error inside returns an empty list — a disclosure must
never be able to fail the recommendation it sits beside.

**Branched to their own sessions — 2026-08-17**

| Dispatch | Covers |
|---|---|
| `dispatches/DISPATCH_app022_online_mode_ui_2026-08-17.md` | APP-022: Online mode on the Now screen, URL-paste host extraction, `portalAlternatives` rendering, the entitlement gate |
| `dispatches/DISPATCH_api018_tests_and_spec_2026-08-17.md` | The API-018 spec file, the Deno test suite, and the two deploy commands |

Both are written cold-start: a fresh session needs nothing from the one that wrote them.

**Still yours, not a session's:** `pnpm engine:bundle` then
`npx supabase functions deploy resolve-merchant-v1` and `recommend-card-v2`. The bundler deletes
and rewrites files, which the Cowork device bridge is not permitted to do, and WORKING_NOTES #23
already records that the MCP deploy channel could not carry `recommend-here-v2`'s closure.

**Incident, flagged rather than buried.** While this session ran, `_shared/entitlements.ts` and
`apps/mobile/src/hooks/useEntitlement.ts` disappeared from the working tree. Both were untracked,
so git could not recover them; HEAD moved four commits in the same window, so a concurrent session
was live. `entitlements.ts` was restored verbatim to the interface ENT-001 specifies, with a header
saying so — API-017's `parse-receipt` imports it too, so it could not be left missing.
`useEntitlement.ts` was **not** restored: nothing of mine imports it, and re-creating a client hook
another session may be mid-rewrite on is not a call this session should make. Worth checking what
else that session lost.

---

## 8. Open questions

1. **The share sheet's real ceiling.** iOS Share Extensions run in a separate process with their
   own memory budget and no access to the app's session by default. Whether the extension can
   resolve and rank in-place, or must hand off to the app, needs a spike before APP-023 is scoped.
   Do not assume it is free.
2. **Should `recommend-card-v2` eventually take `merchantEntityId` directly?** D1 sidesteps it
   with synthetic place rows, which is right for v1. But "I'm buying groceries online, no specific
   store" has no merchant at all, and that request is category-only — which the stateless contract
   already models and the authenticated one cannot. Revisit when a second consumer needs it.
3. **Do online purchases need their own spend buckets?** `user_spend_snapshots` is keyed by card
   and category. A cap whose issuer wording is channel-specific would need a channel dimension.
   No such cap is known in the catalogue today — confirm against the caps set before assuming it
   stays true.
4. **Portal attribution.** D5 reads the portal's name off the earn row's own text. If portals ever
   need to be first-class (a registry, a link, an affiliate path), that is a schema question and a
   commission-blind question at the same time — the pipeline never touches affiliate data
   (SOURCE_OF_TRUTH, "Commission-blind"). Flagging it early because a portal link is exactly the
   kind of thing that looks harmless and isn't.
5. **French.** Domain rows are locale-independent, but display names and the new UI strings are
   not, and FR-CA source rows are still placeholders (SOURCE_OF_TRUTH). The Online mode strings
   should not ship EN-only when the rest of the app has parity (`verify:i18n-parity`).
6. **Recommending a card the user doesn't hold.** The online moment is the strongest affiliate
   surface in the product — and also the one where "commission-blind" is most load-bearing. Out of
   scope here; do not let it drift in without its own decision entry.

---

## Appendix A — verification log

Every claim above was checked against the tree at `11b601b` and the live DB on 2026-08-17.
Reproducible spot checks:

| Claim | Check |
|---|---|
| channel gates only `portal_only` | `grep -n "channel" supabase/functions/_shared/scoring.ts` → 1202, 1234, 1551, 1589, 1620, 1632, 1923, 1934; only 1234 is a predicate |
| `setChannel` has no caller | `grep -rn "setChannel(" apps/mobile/src --include=*.tsx` → 0 |
| `merchantPlaceId` required | `recommendCardV2.ts:67` — `z.string().uuid()`, no `.optional()` |
| web calls no edge functions | `grep -rn "functions/v1\|invoke(" apps/web/src` → 0 |
| ~~no entitlement infra~~ **WRONG — see §1.8** | the original grep excluded `supabase/functions/`, where `_shared/entitlements.ts`, `_shared/runtimeFlags.ts` and spec ENT-001 live. What is true: `select … from information_schema.tables where table_name ilike '%entitle%'` → 0 rows, i.e. the code exists and the schema does not |
| mint paths still live | `grep -n "\.insert({" supabase/functions/resolve-place/index.ts` → 557, 591; `recommend-here-v2/index.ts` → 307, 341 |
| `online_retail` has no earn rates | `select count(*) from earn_rates where category_id='online_retail' and valid_to is null` → 0 |
| `online_retail` has 7 MCC mappings | `select count(*) from mcc_category_mappings where category_id='online_retail'` → 7 |
| 24 portal_only rows | `select count(*) from earn_rates where condition_type='portal_only' and valid_to is null` → 24 |
| 104 placeless entities, 112 null-category | single aggregate query, §1.4 |
| runtime flags | `select key, enabled from runtime_flags` → 3 rows, all true |

**One correction owed regardless of this design:** `HOW_THE_ENGINE_WORKS.md:210` states channel
does not affect scoring. `scoring.ts:1234` says otherwise. Fix that line whether or not D1–D9 are
approved.
