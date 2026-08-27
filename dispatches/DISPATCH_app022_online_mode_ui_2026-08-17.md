# DISPATCH — APP-022: Online mode on the Now screen

Date: 2026-08-17 · For: a fresh Opus 5 session · Owner: Mike
Depends on: API-018 (shipped 2026-08-17, this repo), ENT-001 (schema NOT applied — see §5)
Design: `cardcoach-docs/DESIGN_online_merchant_v1.md` (D6, D7, D9)

Read `SOURCE_OF_TRUTH.md` and `PROJECT_RULES.md` first. This dispatch is self-contained
otherwise — do not assume any context from the session that wrote it.

---

## 1. What already exists (verified 2026-08-17)

The whole server side is built, applied and deployed-ready. **Your job is the client only.**

- **`resolve-merchant-v1`** edge function — `supabase/functions/resolve-merchant-v1/index.ts`.
  POST `{ schemaVersion: 1, locale, domain?, query?, limit? }` → `{ schemaVersion, results[],
  parked, requestId }`. Exactly one of `domain`/`query`. Each result carries
  `merchantPlaceId`, `merchantEntityId`, `displayName`, `domain`, `categoryId`,
  `billingCurrency`, `confidence`.
- **Types**: `packages/engine-contracts/src/resolveMerchantV1.ts`, exported from the package
  index. Import them; do not redeclare.
- **Catalogue**: 140 merchants / 141 domains live in `merchant_domains`, every one resolving to
  a non-null category (asserted by `pnpm verify:data-020`).
- **The key trick**: `merchantPlaceId` in the response is a real `merchant_entity_places.id`
  (synthetic, `provider='domain'`). **Feed it straight to `recommend-card-v2` as
  `merchantPlaceId` with `channel: "online"`.** No new recommendation call is needed and no
  contract changed — the online path is byte-identical to the in-store path below the resolver.
- **`portalAlternatives`** — `recommend-card-v2` now returns an optional array when a travel
  portal beats the best in-channel option. Type `PortalAlternativeV1` in engine-contracts.
  Rendering it is in scope for you (§4).

## 2. The client gap you are filling

- `apps/mobile/src/prefs/purchaseContextPrefs.ts:19` persists `channel`, default `in_store`.
  `PurchaseContextPrefsContext.tsx:79` exposes `setChannel`. **`setChannel(` has zero call sites
  in any screen.** It has never been called. You are its first caller.
- `apps/mobile/src/i18n/locales/en.json:312-315` already holds
  `screens.storeDetail.channelLabel` = "Purchase type", `channel_in_store`, `channel_online`,
  `channel_portal` = "Travel portal" — written for a screen that was never built. Reuse them;
  add FR-CA counterparts (`pnpm verify:i18n-parity` must stay green).

## 3. Build

**Entry point (D6): in-app search + URL paste. No share sheet in this slice.**

1. An **Online** affordance on the Now screen (`apps/mobile/src/screens/NowScreen.tsx`, 2737
   lines — read before editing). Toggling it calls `setChannel("online")`; leaving restores
   `"in_store"`.
2. In online mode, replace the place picker with a merchant field that accepts either:
   - typed text → `resolve-merchant-v1 { query }`, show `results` as a list; or
   - a pasted URL → **extract the host client-side** and send `{ domain }`.
3. **Extract the host on device. Never send a full URL.** Strip scheme, `www.`, port, path,
   query and fragment before the request. This is a privacy property of the feature, not an
   optimisation: CardCoach must not receive the path of a page a user was reading, so the
   product cannot accumulate a browsing history even by accident. Say so in the privacy copy.
   `_shared/onlineMerchant.ts` has a `normalizeHost` you can mirror; the server strips again
   defensively, but the client is the boundary that matters.
4. On selection: call `recommend-card-v2` with the returned `merchantPlaceId`,
   `channel: "online"`, and — when `billingCurrency` is non-null and not `CAD` — pre-select it
   as `spendCurrency` so the FX cost the engine already computes reaches the user.
   **`billingCurrency: null` means UNKNOWN, never CAD.** Do not pre-fill on null.
5. Empty `results` is a first-class state, not an error. The runtime never invents a merchant
   (D2), so an unknown store legitimately resolves to nothing and is parked for curation. Say
   "we don't have this store yet" and offer the existing `search-places` picker for a physical
   store. **Never show a base-rate ranking as if it were a merchant-specific answer.**

## 4. Rendering `portalAlternatives`

Disclosure only, below the ranking, visually distinct from it. It must never look like a
ranked row. Each entry has `cardDisplayName`, `portalName`, `portalValueCents`,
`directValueCents`, `upliftCents`, `conditionText`.

Copy shape: "Booked through **Expedia For TD**, your **TD First Class Travel** earns **$X more**
on this purchase." Show `conditionText` verbatim, or behind a disclosure — it is the issuer's
own wording and the thing the user can actually check.

Do not imply the portal price equals the direct price. It is a different vendor and may not be.

## 5. The gate — and why nothing will be visible yet

Two gates, both server-enforced:

- `runtime_flags.online_merchant_resolution` — **true** in production.
- `hasEntitlement(user, "online_merchant")` — ENT-001's paid gate.

**`user_entitlements` does not exist in the database.** ENT-001 is PROPOSED and awaiting Mike's
sign-off, so `hasEntitlement()` fails closed and `resolve-merchant-v1` returns
`403 not_entitled` to everyone, including you. That is the intended pre-launch state.

Gate the UI with the existing `useEntitlement("online_merchant")` hook, presentation only.
**Note:** `apps/mobile/src/hooks/useEntitlement.ts` disappeared from the working tree on
2026-08-17 (untracked, unrecoverable from git) and was deliberately not restored by the session
that noticed. Check whether it is back before you build against it; if not, it needs writing to
ENT-001's specified interface — `{ entitled, loading, refresh }`, fail-closed, re-checked on
`AppState` foreground.

To exercise the feature end to end you need ENT-001's schema applied and a manual grant to your
own user (`source: 'manual'`). **That is Mike's call, not yours** — ask before applying it.

## 6. Acceptance

- [ ] Toggling online mode calls `setChannel`, and the pref survives a relaunch.
- [ ] Typed text and pasted URL both resolve; the URL path/query never leaves the device
      (assert in a test with a URL containing a path and query).
- [ ] Selecting a merchant produces a ranking via `recommend-card-v2` with `channel: "online"`.
- [ ] `billingCurrency` non-CAD pre-fills `spendCurrency`; null pre-fills nothing.
- [ ] Zero results renders the honest empty state, never a base-rate ranking.
- [ ] `portalAlternatives` renders as disclosure, never as a ranked row.
- [ ] EN + FR strings both present.
- [ ] Every online surface is invisible when the entitlement hook says false.

## 7. Verification (stop condition)

```
pnpm -C apps/mobile typecheck
pnpm -C apps/mobile test
pnpm verify:i18n-parity
pnpm verify:ui
```

All must pass. Ranking must be unchanged for every in-store path — this slice adds a surface,
it does not touch the engine.
