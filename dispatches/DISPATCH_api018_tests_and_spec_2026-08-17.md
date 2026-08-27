# DISPATCH — API-018: spec file, Deno tests, deploy

Date: 2026-08-17 · For: a fresh Opus 5 session · Owner: Mike
Design: `cardcoach-docs/DESIGN_online_merchant_v1.md`

Read `SOURCE_OF_TRUTH.md` and `PROJECT_RULES.md` first. Self-contained otherwise.

The API-018 code shipped on 2026-08-17 without its spec file or its tests. This dispatch closes
that gap. **No behaviour change is in scope** — if you find yourself wanting to change the
resolver's semantics, stop and record it as a finding instead.

---

## 1. Write `docs/planning/specs/API-018_resolve_merchant_v1.md`

Follow the house shape, of which `API-017_receipt_parse.md` is the best current example:
`SPEC — API-018: …` / Status / Context (with `file:line` citations) / Decisions D1–Dn / Scope
in-and-out / Interface / Acceptance / Verification.

The decisions are already made and recorded in `DESIGN_online_merchant_v1.md` §2 — transcribe
them faithfully rather than re-deriving. The load-bearing ones:

- **D1** — identity is a curated domain plus a **synthetic `merchant_entity_places` row**
  (`provider='domain'`, `place_id='domain:<host>'`). This is why `recommend-card-v2` needed no
  contract change: it loads the place row by id and joins the entity
  (`recommend-card-v2/index.ts:254-270`), with no provider filter and no Google dependency.
  One row per **entity**, not per domain, so every domain of a merchant yields the same
  `merchantPlaceId` and therefore the same transaction key.
- **D2** — the runtime never creates a merchant. Unresolved → `results: []` plus one
  `verify.parking` row, `topic: 'online_merchant_unresolved'`.
- **D3** — category resolves `merchant_domains.category_override` → `default_category_id`,
  never `online_retail` (0 active earn rates, 7 MCC mappings — the trap).
- **D5** — `portalAlternatives` is disclosure, never ranking.
- **D7** — two gates: `runtime_flags.online_merchant_resolution` (true) and
  `hasEntitlement(user, "online_merchant")` (closed — ENT-001 schema unapplied).

Record one open item the design already flags: **`category_override` is inert today.**
`recommend-card-v2` takes the category from the ENTITY (`index.ts:288`) and cannot see
`merchant_domains`, so a divergent override would have the resolver reporting one category while
the engine scored another. Every seeded row pins it NULL and `verify:data-020` asserts that. A
storefront that genuinely differs from its stores must be modelled as its own entity — which is
how `Apple Music` and `Apple Store` already coexist.

## 2. Deno tests — `supabase/functions/__tests__/api_018_online_merchant.test.ts`

Follow `api_017_receipt_parsing.test.ts` for structure. Pure-function tests, no live stack.

**`normalizeHost` (`_shared/onlineMerchant.ts`)** — the privacy boundary. Assert that a full URL
with path, query and fragment reduces to the bare host, and that scheme, `www.`, port, userinfo
and a trailing root dot are all stripped. Assert junk returns `null`.

**`hostCandidates`** — longest-first label walk, stopping at two labels:
`store.steampowered.com` → `["store.steampowered.com", "steampowered.com"]`, and **not**
`["…", "com"]`. Longest-first is load-bearing: `music.apple.com` is Apple Music (streaming) and
`apple.com` is the Apple store (retail); both are in the live catalogue, and a shortest-first
walk would collapse them.

**`derivePortalName` (`_shared/portalAlternatives.ts`)** — table-driven over the real
`condition_text` values. All 24 active `portal_only` rows currently name correctly; pin that.
Include `"Travel purchases made through Expedia® For TD."` → `"Expedia For TD"` (the ® strip),
`"CIBC Rewards Centre (CIBC by Expedia) bookings only."` → `"CIBC Rewards Centre"` (order in
`PORTAL_PHRASES` is significant — the Rewards Centre is the destination), and an unknown portal
falling through the regex to a sensible name rather than a wrong one.

**`computePortalAlternatives`** — inject a stub `score` (the signature takes one precisely so
this is testable without a wallet). Assert:
- empty when `channel === 'portal'` already;
- empty when no wallet card carries a `portal_only` row (the cheap pre-check);
- empty when the portal run ties or loses to the best direct value;
- comparison is **best-portal vs best-direct**, not per-card — a card whose portal value beats
  its own direct value but loses to a different card used directly must NOT be surfaced;
- sub-cent uplift is suppressed;
- a throwing `score` returns `[]` rather than propagating (a disclosure must never fail the
  recommendation it sits beside).

**`earnRowPrices` channel gating (`_shared/scoring.ts`)** — the regression that matters:
- `channel_includes: null` or absent prices on every channel (this is every row in production
  today, which is why the change could not move any ranking);
- `['online']` does not price `in_store`;
- gating applies to rows with `condition_type: null` too — it runs **before** the condition
  switch, which returns early on null. Getting this backwards would silently skip most of the
  catalogue.

## 3. Deploy (Mike's machine)

Not runnable from a Cowork session — WORKING_NOTES #23 records that the MCP deploy channel could
not carry `recommend-here-v2`'s closure.

```
pnpm engine:bundle                                  # syncs engine-contracts into _shared/
npx supabase functions deploy resolve-merchant-v1
npx supabase functions deploy recommend-card-v2     # picks up portalAlternatives
```

`pnpm engine:bundle` deletes and rewrites files, which the Cowork device bridge is not permitted
to do — that is why it has not been run.

## 4. Verification (stop condition)

```
cd supabase/functions && deno task test
pnpm verify:data-020
pnpm verify:recommend-card       # ranking must be unchanged
pnpm verify:engine-bundle
```

`verify:data-020` currently reports `channel_includes_populated 0`. **That number is the proof
that ranking is unchanged.** If it is ever non-zero, each populated row must trace to Tier 1/1b
issuer wording and a dated delta (rule 7) — the script prints them individually for exactly this
reason.
