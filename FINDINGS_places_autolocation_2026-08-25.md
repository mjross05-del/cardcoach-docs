# FINDINGS — Google Places & auto location

**Date:** 2026-08-25 · **Lane:** auto location · **Requested by:** Mike
**Verdict: there was nothing to enable. Google Places has been on and billing the whole time.**

Verified against production 2026-08-25, not remembered. This doc exists because the
request that opened this lane — "enable Google Places, now that Pro justifies the cost" —
rests on a premise that production contradicts, and the real constraint is somewhere else
entirely.

---

## 0. The premise, tested

> "A past runtime told me Google Places was the answer but it had a cost."

That runtime was `DESIGN_place_resolution_v1.md` (2026-08-12, still **DRAFT**). Its §5 is not
a proposal to *adopt* Google Places. It is a proposal to **spend less on the Google Places we
already run** — move iOS pickers to MapKit, restrict Android to an Essentials field mask, cap
quota at the free threshold, keep web on own-data search. The cost anxiety was about scaling
*down*, and it got read a year later as a switch that was never flipped.

Same failure mode as build-84 item **A2** (Google sign-in, "carried as the gating Android
blocker for weeks and was simply stale"). Third occurrence of a stale-blocker in this project
in two weeks. Worth a habit: check production before scheduling the fix.

## 1. Evidence that Places is live

Last 24h of `function_edge_logs` on `hrzpznlpmxxrbtwskacu`:

| Function | Google API it calls | Calls | Result |
|---|---|---|---|
| `recommend-here-v2` | Places API (New) `places:searchNearby` | 49 | **48× 200**, 1× 400 (bad payload) |
| `search-places` | Places Autocomplete (legacy) | 20 | **20× 200** |
| `resolve-place` | Place Details (legacy) | 4 | **4× 200** |

Zero `502`s and zero `500`s across all three. That is dispositive, because of how the code
fails:

- missing key → `search-places` returns **500** (`search-places/index.ts:128-135`),
  `recommend-here-v2` returns **502 places_error** (`recommend-here-v2/index.ts:505-515`)
- Google non-OK → **502** (`recommend-here-v2/index.ts:553-565`, `search-places/index.ts:167-177`)
- zero results → **404 no_candidates** (`recommend-here-v2/index.ts:576-585`)

A `200` from `recommend-here-v2` is only reachable *after* a successful Google
`searchNearby` that returned at least one place. Corroborating: `merchant_entity_places`
gained new Google place-id mappings on 12 of the last 14 days (5–18/day, plus a 149 spike on
08-17).

**So:** `GOOGLE_PLACES_API_KEY` is set on the Supabase project, billing is attached, and both
the legacy Places API and Places API (New) are enabled. Nothing to turn on.

## 2. The cost number the design got wrong

DESIGN §5 assumed the `searchNearby` call bills at **Essentials, 10k free/month**. It does not.

The field mask actually sent is
`places.id,places.displayName,places.formattedAddress,places.location,places.types`
(`recommend-here-v2/index.ts:548-551`). Per Google's current data-fields table, **all five of
those fields are `Nearby Search Pro`** — the SKU is set by the field mask, and there is no
Essentials mask that returns a usable place. Current rates:

| SKU | Free/month | Then |
|---|---|---|
| Nearby Search **Pro** (`recommend-here-v2`) | **5,000** | **$32.00 / 1,000** |
| Place Details Pro (`resolve-place`) | 5,000 | $17.00 / 1,000 |
| Autocomplete (`search-places`) | 10,000 | $2.83 / 1,000 |

Today's ~48 Nearby calls/day ≈ **1.4k/month** — comfortably inside the free 5k, which is why
no one has ever seen a bill.

The exposure is growth, not features. Nearby Search Pro is the expensive SKU and it fires on
Now-screen opens:

- 80 users × 2 opens/day ≈ **4.8k/month** — right at the free cap
- 1,000 users × 2 opens/day ≈ 60k/month → 55k billable ≈ **$1,760/month**

That is the real cost story, and it scales with *users*, not with Pro subscribers. Which is
exactly why BILL-001 made auto location a Pro entitlement — `auto_location_gate` is the cost
control, not a feature switch.

## 3. What actually limits auto location

Not the API. A hardcoded filter.

`recommend-here-v2/index.ts:519-529` asks Google for **nine** place types:

```
restaurant, cafe, supermarket, grocery_store, gas_station,
convenience_store, bar, meal_takeaway, meal_delivery
```

The engine scores **37 categories**. So auto location is structurally blind to roughly twenty
of them — standing in any of these, the user gets `no_candidates` and falls back to typing:

| Engine category | Why it can never resolve |
|---|---|
| `drugstore`, `drugstore_pharmacy`, `pharmacy` | no `pharmacy`/`drugstore` type requested |
| `alcohol` | asks for `bar`, never `liquor_store` — **an LCBO cannot be detected** |
| `costco`, `wholesale_club` | no `warehouse_store` |
| `home_improvement` | no `home_improvement_store`/`hardware_store` — Canadian Tire, Rona, Home Depot |
| `hotels_motels`, `travel`, `marriott_travel` | no `hotel`/`lodging` |
| `retail_shopping`, `furniture`, `office_supplies` | no `department_store`, `clothing_store`, `furniture_store`, `shopping_mall` |
| `entertainment`, `e_games`, `fitness_sports_clubs` | no `movie_theater`, `gym` |
| `transit`, `transit_parking` | no `transit_station`, `parking` |
| `ev_charging` | no `electric_vehicle_charging_station` |

Drugstore and wholesale-club are load-bearing for Canadian card multipliers. Those are the
categories the whole product exists to optimize, and the location path cannot see them.

> **CORRECTION (same day, after measurement).** The paragraph below called this a free
> win. It is not, and shipping it as written would have made auto location WORSE — a naive
> widening displaced the correct merchant at 3 of 4 dense test coordinates. The type list is
> only half the problem; the other half is that `classifyPlace`'s rung order was sending the
> wrong category to the engine (a Petro-Canada scored as `grocery`). Read
> `REPORT_autolocation_optimization_2026-08-25.md` instead of acting on this section.

**The fix is free.** `includedTypes` is a request filter, not a field — widening it does not
change the field mask, so the SKU stays Nearby Search Pro and one request stays one billable
event. Same money, roughly double the categories reachable. This is the single highest-value
change in the lane and it was sitting behind an assumed paywall that does not exist.

Verified-valid Table A types to add:
`pharmacy, drugstore, liquor_store, warehouse_store, home_improvement_store, hardware_store,
department_store, clothing_store, electronics_store, furniture_store, shopping_mall, hotel,
lodging, motel, gym, fitness_center, movie_theater, parking, electric_vehicle_charging_station,
book_store, pet_store, transit_station`

Caveat to design before shipping: `rankPreference: DISTANCE` with `maxResultCount: 10` over a
2,000 m radius means a wider type list will surface *nearer irrelevant* places ahead of the
intended store. Widening types without retuning ranking will make some currently-correct
answers worse. Recommend a tiered pass (retail types at a tighter radius) rather than one flat list.

## 4. Minor defect found en route

`NowScreen.tsx:988-989` sends `maxCandidates: 10`. The server clamps to `MAX_CANDIDATES = 5`
(`recommend-here-v2/index.ts:112, 497-499`). Harmless today — the client asks for more than it
can get and silently receives five — but the two numbers should agree so nobody tunes the
client value expecting an effect.

## 5. What still needs Mike (~1 minute)

Everything above came from production data and the repo. One thing needs the Google Cloud
Console, which requires a passkey tap I cannot perform:

1. **Is a hard quota cap set on the Places APIs?** DESIGN §5 proposed ~320 requests/day.
   If someone applied it, it is invisible today at 48/day and will silently throttle auto
   location the moment Pro launch drives volume — appearing as `502 places_error`, not as a
   quota message. This is the one live landmine.
2. **Is the API key restricted?** A server-side key with no application/API restriction is the
   standard leak risk; it is used from Supabase edge functions, so it should be API-restricted
   to Places + Places (New) and nothing else.
3. **Is a billing budget alert set?** At $32/1k on the SKU that fires per app-open, the first
   warning should not be an invoice.

Sign in to `console.cloud.google.com` for project **`cardcoach-auth`** and a session can finish
the audit unattended.

## 6. Recommendation

- **Do not** flip `auto_location_gate` during the tester round. It is a `restrict` gate: true
  takes working auto location away from ~80 existing users. RUNBOOK_build_84 §B8 already says
  this; the cost math above is the second reason.
- **Do** widen `includedTypes` as its own change, after build 84 ships — free, and it is the
  actual "improve auto location" the lane was opened for.
- **Do** treat Nearby Search Pro volume as the thing to watch before Pro launch, not the
  enablement status.

