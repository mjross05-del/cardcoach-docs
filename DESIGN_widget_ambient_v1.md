# DESIGN — Ambient card widget (iOS + Android), v1

Status: PROPOSED · 2026-08-17 · Author: Cowork session, at Mike's direction
Feature id: **WIDGET-001** · Spec: `mobile_app_codebase/docs/planning/specs/WIDGET-001_ambient_card_widget.md`

The ask: a lock/home-screen widget showing the card to use, based on where you are.

This document exists because the obvious implementation of that sentence is not
possible on either platform under the constraints CardCoach has already chosen,
and the reasons are not obvious until you go looking. The design that *is*
possible is better than a compromise — but only if it is built deliberately
rather than discovered halfway through.

---

## 1. The finding that shapes everything

**A widget cannot reliably get a location fix on its own.** Not on iOS, not on
Android, not without background location — which `LOC-001` deliberately does not
request, and which is the right call.

**iOS.** A widget extension *can* use Core Location, gated on
`NSWidgetWantsLocation` in the extension's `Info.plist` plus When-In-Use in the
parent app. Always is **not** required — Apple explicitly recommends When-In-Use
here. But the grant is time-boxed: WWDC21 states the widget receives location
"up to **15 minutes** after a widget was last viewed," and current docs say only
"a short period of time after the widget is visible." Outside that window the
system stops delivering location, and the failure is quiet — either no delegate
callback, or `kCLErrorDenied`. Apple's own Frameworks engineer gives the verdict
on the forums: *"WidgetKit does not support continuous location updates like
today extensions; you should consider caching the location in your phone app and
updating it when necessary for your widget."*

**Android.** Worse, and the failure mode is nastier. A widget-update worker has
no visible activity and no foreground service, so by Android's own definition it
is doing **background** location — which on API 29+ requires
`ACCESS_BACKGROUND_LOCATION`. Without it you do not get a `SecurityException`;
the app-op resolves to `MODE_FOREGROUND` and you get nulls and silently missing
callbacks. That is the worst bug class available: works in dev with the app
open, fails intermittently in production. And requesting background location
would put us in front of Play's Location Permissions Declaration Form against a
core-functionality test a widget refresh cannot pass.

**Conclusion.** The app owns location. The widget owns rendering. This is not a
workaround — it is both platforms' documented architecture.

---

## 2. What that costs, and how to not pay it

The naive form of "app owns location" is: cache the merchant you were last at,
render it. That widget is wrong the moment you walk next door.

**The fix is to cache a neighbourhood, not a point.**

`recommend-here-v2` already returns up to `maxCandidates: 10` nearby candidates
within `radiusMeters: 2000`, **each carrying its own server-ranked `topCard`**.
The Now screen already makes exactly this call with exactly these parameters.
That response *is* the bundle. We are not adding a request; we are keeping one
we already throw away.

So the app projects that response into a compact **neighbourhood snapshot** and
writes it to shared storage. The widget then does one thing:

> pick the nearest merchant in the snapshot, render the card the engine already
> chose for it.

**Nearest-by-distance is not scoring.** Every card choice in the snapshot was
made server-side by the engine. The widget selects among pre-computed answers by
comparing two coordinates. The `AGENTS.md` / `CLAUDE.md` rule — *the mobile app
must never compute "best card"* — holds exactly, and the spec makes it an
enforced invariant rather than a promise.

The payoff: **within your neighbourhood the widget stays correct as you move
between stores without opening the app.** You go stale only when you leave the
tile, and the widget can tell that it has (it knows the snapshot's centre and
radius) — so it degrades honestly instead of lying.

### One additive server field is required — and only one

An earlier draft of this document claimed the snapshot needed **no server
change**. That was wrong, and the way it was wrong is worth recording.

`recommend-here-v2` computes each candidate's coordinates
(`index.ts:590-593`) and then **drops them in the response projection**
(`:765-771`). What survives is `distanceMeters`, frozen against the *request
origin*. That scalar cannot be re-evaluated as the user moves — which collapses
the neighbourhood snapshot back into exactly the "cache a point" degenerate case
this whole architecture exists to avoid. Nearest-merchant re-selection was the
mechanism, and the data for it was not in the response.

The fix is **one additive optional `location` object** on the candidate, carved
out as **API-017** so it is reviewed as a server change rather than smuggled in
under a UI spec. It follows the API-014 precedent exactly: an optional field, so
every deployed client's `zod` parse still succeeds. It is still **zero new Places
spend** — the coordinates are already fetched and thrown away.

**A latent bug surfaced while verifying this.** The same projection emits
`distanceMeters: … : null` against a contract that declares `.optional()`. In
zod 4 `.optional()` admits `undefined`, not `null`, and the mobile client
hard-parses — so a single placeless candidate would reject the *entire* response
and the user would get a generic error at the till instead of a recommendation.

It is latent rather than live: reaching it needs `hasLocation === false`, and the
Places request sets a field mask that includes `places.location`, which the API
returns for every place. Nobody has hit it. Worth closing anyway while API-017 is
already in those three lines and already answering the same omit-vs-null
question — a trap in a code path that runs at the till is cheap to remove now and
expensive to diagnose later.

### Why still no new edge function

A `widget-snapshot-v1` endpoint is attractive — smaller payload, server-side tile
cache, a target for WidgetKit push. It is also net-new server surface and a
second thing that can be wrong on launch day. One optional field on an existing,
already-called endpoint buys the same capability for a fraction of the risk.
`widget-snapshot-v1` is deferred to v2, where its real justification
(push-driven refresh) actually lands. See §8.

---

## 3. The three states — and the one rule about them

This is a financial recommendation displayed on a lock screen. A stale answer
presented as a live one is the failure mode that matters, and it is worse than
showing nothing.

| State | Condition | Render |
|---|---|---|
| **Live** | snapshot fresh **and** current position inside its radius | merchant + card, no qualifier |
| **Stale** | snapshot aged out, or position outside radius, or no fix available | last known, **visibly timestamped and de-emphasised**, "open to refresh" |
| **Unauthorised** | `isAuthorizedForWidgetUpdates == false` / permission denied | deep-link CTA into the app |

Apple documents the middle and bottom rows as genuinely different situations
requiring different UI, and they are right. `isAuthorizedForWidgetUpdates ==
false` is *not* "location impossible" — the widget still gets fixes during
app-foreground reloads — so it must not hard-gate rendering.

**Never render a stale card as if live.** No exceptions, no "probably fine."

---

## 4. Refresh: what actually moves the needle

Ranked by leverage, not by cleverness:

1. **App foreground → `WidgetCenter.shared.reloadTimelines(ofKind:)`.** Free and
   immediate — foreground reloads are budget-exempt. This is the single highest-value
   lever and it costs one line at a lifecycle boundary. Do it on every foreground
   *and* on backgrounding, after refreshing the snapshot.
2. **Significant location change.** WidgetKit reloads location-using widgets on
   SLC and grants it **budget-free**. The widget re-picks nearest from the
   snapshot it already holds — no network, no scoring, well inside an extension's
   resource ceiling. *(Caveat: Apple does not document whether a fix is
   obtainable at that reload if the widget hasn't been visible. Treat the reload
   as reliable and the fresh fix as a bonus; the snapshot makes the reload useful
   either way.)*
3. **Timeline cadence.** 40–70 reloads/day for a frequently-viewed widget,
   entries ≥5 minutes apart. Plan for the bottom of that band.
4. **Android:** `updatePeriodMillis` has a hard 30-minute floor and Doze defers
   `WorkManager` entirely when the device is idle. The update handler runs JS in a
   headless context with a **30-second budget**. Design for ~30–60 min while in
   use, hours when idle, and never depend on it.

The honest product framing, which should also be the App Store description:
**"shows the right card when you look at it"** — not "notices you've arrived."
The latter genuinely requires Always/background location and we are not buying it.

---

## 5. The lock screen has no colour — and that is load-bearing

iOS renders Lock Screen widgets in **`.vibrant`** mode: desaturated, grayscale,
no brand colour, with a user tint applied on top. `accessoryInline` additionally
uses a system-defined font and colour that cannot be overridden.

CardCoach's `CardVisual` identifies cards by **issuer-derived gradient**. On the
lock screen that entire channel is gone.

This collides head-on with `LANE_ios_android_discrepancies_2026-08-16.md`
**Item 4** — sibling products already render identically because the artwork
comes from the issuer, and the founder misread his own two CIBC cards as one
card. The widget does not create that problem; it removes the last thing that
was masking it.

**So the widget needs a monochrome card token, and the app needs one anyway.**
A short, typographic, per-*product* identifier — `CIBC DIV VI`, `PC WE MC`,
`SCOTIA MOM` — legible at 26pt inline and at 76×76 circular, and equally useful
as the persistent product chip Item 4 asks for on the card art. Server-supplied
(`card_products`), never client-derived, so the app keeps computing nothing.

**v1 does not ship the token.** Its source is decision 2 in §9 and unresolved,
and inventing an abbreviation on the client to fill the gap is precisely the
plausible-but-unsourced string PROJECT_RULES rule 7 forbids. So v1 renders
`cardName` verbatim and lets the *view* truncate for the accessory families.
When the token lands it becomes one more pass-through field — a few lines, not a
rework. Shipping a degraded-but-correct label beats shipping a confident wrong
one, which is the same principle as §3.

Android renders its widget as a bitmap drawn from real views, so **full colour is
available there**. Fine — design the monochrome token as the primitive, let
Android layer colour on top. Do not design the token to Android's capabilities.

**Recommendation:** land the token in the retheme lane alongside Item 4, not as
widget-only work. It is the same defect with two symptoms.

---

## 5b. The widget has no i18n runtime — so the app pre-resolves its strings

Neither platform's widget can call `t()`. `useI18n()` throws outside the React
tree, and `registerWidgetTaskHandler` runs headless; on iOS a Swift
`Localizable.strings` would be structurally invisible to
`verify_i18n_parity.mjs`, which reads only `locales/{en,fr}.json`.

So the app resolves every widget string at snapshot-write time — inside the React
tree, where `t` exists — and writes them into the snapshot. The widget renders
strings it is handed and formats nothing.

This is not a workaround so much as the same idea as §2 applied to text: the
surface that has the context does the resolving, and the widget stays a renderer.
Keys live in `en.json`/`fr.json` like every other string, so FR parity is covered
by the existing verifier with no new machinery. A snapshot whose locale no longer
matches the app's is simply **stale**, and §3 already says what to do with stale.

---

## 6. Privacy, and one call worth making explicitly

**The snapshot must not contain `last4`.** The Now screen shows it; the widget
must not. A lock screen is visible to anyone holding the phone, and the widget
already reveals which cards the user holds — adding partial card numbers to a
surface that renders without authentication is not a tradeoff worth taking for a
four-digit convenience. Mark the views `.privacySensitive()` so the system
redacts them when locked, and keep the snapshot to: merchant name, card name,
issuer, earn line, and the freshness metadata. (No card token in v1 — see §5.)

**App Store 5.1.1(iv)** requires an alternative for users who decline location —
reviewers actively test the decline path, and 5.1.2(i) forbids gating
functionality on location. So the widget ships with a configuration intent:
**Nearest** (default) or **Pinned merchant**. The pinned mode also happens to be
the better widget for someone with a regular commute, so this is a requirement
that improves the product.

**Privacy manifest.** Reading App Group `UserDefaults` is a required-reason API.
The correct code is **`1C8F.1`** (App Group members), *not* `CA92.1` (app-only —
a common and rejectable mistake). The widget extension is a separate bundle with
its own executable, so it needs **its own** `PrivacyInfo.xcprivacy`; the app,
being CNG with no committed `ios/` and no manifest today, gets one via
`ios.privacyManifests` in `app.config.ts`. Getting this wrong is `ITMS-91053`
(missing) or `ITMS-91055` (malformed) — both block upload, so neither is a review
comment you get to argue with.

Purpose strings must be specific. The current one is adequate for the app; the
widget's usage should be named in it.

---

## 7. Release mechanics — including a live footgun

A widget is a native extension. Adding it changes the Expo fingerprint, so it
**cannot ship over EAS Update** — it is a new binary and a full submission round
on both stores. Nothing about this feature belongs in 1.0.3.

**Sequencing:** build both platforms under **1.1.0**, ship iOS first because that
lane is open, and release the Android widget from the same branch when `REL-001`
opens the Play lane. One version number, two ship dates.

**The footgun, and it is a real one:** `@expo/fingerprint` does **not** hash a
top-level `targets/` directory. You can rewrite the widget's entire SwiftUI, get
an identical `runtimeVersion`, publish an EAS Update onto the existing binary,
and reasonably conclude the widget changed. It did not. This is specifically
dangerous for a team that adopted EAS Update nine days ago. The fix is three
lines in `apps/mobile/fingerprint.config.js` and it is step 1 of the plan, not a
cleanup item.

**Toolchain, decided:**

- iOS — **`@bacons/apple-targets@^5.0.0`**. The `^5` floor is not stylistic: v4
  deep-imports `@expo/prebuild-config` without declaring it, which is unresolvable
  under pnpm's isolated `node_modules` and fails at prebuild. v5 declares it.
  (The `@kingstinct` fork is 19 months stale and pinned to SDK 52-era deps.)
  Expo's first-party `expo-widgets` is the eventual destination but starts at
  **SDK 55** and cannot display images — revisit at SDK 56+.
- Android — **`react-native-android-widget@^0.22.0`** (published 9 days ago,
  `peerDeps: expo >=54`). Its update handler runs our own JS, which means no
  native data-sharing layer is needed at all.
- Set `deploymentTarget` **explicitly**. The plugin defaults widgets to `18.0`,
  which would silently withhold the widget from every iOS 15–17 device.

---

## 8. Deliberately out of scope for v1

Each of these is a real idea being *deferred*, not rejected:

- **`widget-snapshot-v1` edge function** — compact payload + server-side tile
  cache. Justified when push arrives, not before.
- **WidgetKit push (iOS 26)** — refreshes the widget without location background
  modes. Cannot geo-trigger (the server does not know where you are), but it is
  the right channel for pushing *data* changes — a new bonus category, a rotating
  quarter — into a widget the user hasn't opened the app for.
- **Widget-side live fetch** via a Keychain access group (`SecureStoreOptions.accessGroup`,
  SDK 53+). Would let the widget refresh its own snapshot inside the in-use
  window. Meaningful complexity for a bounded gain; revisit once v1 telemetry
  shows how often users actually leave the tile.
- **Android lock screen.** Android 16 QPR2, Pixel-first, off by default behind a
  user toggle, and Android 16 is ~24% of devices. Our widget is automatically
  eligible (the plugin hardcodes `home_screen`, and lock screen is opt-*out* via
  `not_keyguard`). Take it as a free bonus; do not design for it or promise it.
- **Control Center control (iOS 18+).** Apple documents nothing about location in
  controls. Do not build on undocumented behaviour.
- **Smart Stack location relevance.** `RelevantContext.location` is **watchOS
  only**. There is no iOS API to auto-surface a widget by place. Setting
  `TimelineEntryRelevance.score` on a confident merchant match is the only lever
  and it only affects rotation within a stack the user already built.

---

## 9. Open decisions for Mike

0. **API-017 — approve the additive field?** One optional `location` object on
   the `recommend-here-v2` candidate, plus the `distanceMeters` null fix (§2).
   Without it the widget degrades to a cached point and most of this design's
   value evaporates. The `distanceMeters` fix is worth doing regardless of
   whether the widget ever ships — it is a live error path at the till.
1. **Card token ownership.** Land the monochrome product token in the retheme
   lane (with LANE Item 4) or as WIDGET-001 scope? Recommendation: retheme lane —
   same defect, and the widget shouldn't own a schema addition the app needs too.
2. **`card_products.short_code`** — new column, or derive server-side in the
   response projection? Recommendation: column, verified per product like every
   other card fact, because a derived abbreviation is exactly the kind of
   plausible-but-unsourced string this project has rules against.
3. **Android ship gate.** Hold the Android widget for `REL-001`, or ship iOS 1.1.0
   and treat Android as 1.1.1? Recommendation: same branch, same version, second
   ship date — do not fork the codebase around a store timeline.
4. **Pinned-merchant mode** — ship in v1 as designed (it is the 5.1.1(iv)
   answer), or ship a simpler "open the app" fallback and add pinning in v1.1?
   Recommendation: ship it; reviewers test the decline path and a bare CTA reads
   as a broken widget.

---

## Sources

Apple: [Accessing location information in widgets](https://developer.apple.com/documentation/widgetkit/accessing-location-information-in-widgets) ·
[NSWidgetWantsLocation](https://developer.apple.com/documentation/bundleresources/information-property-list/nswidgetwantslocation) ·
[isAuthorizedForWidgetUpdates](https://developer.apple.com/documentation/corelocation/cllocationmanager/isauthorizedforwidgetupdates) ·
[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) ·
[Requesting authorization to use location services](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services) ·
[Preparing widgets for additional contexts and appearances](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances) ·
[Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) ·
[Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) ·
[App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) ·
[Forum 658686 (Apple Frameworks Engineer on caching location)](https://developer.apple.com/forums/thread/658686) ·
[WWDC21 — Principles of great widgets](https://developer.apple.com/videos/play/wwdc2021/10048/)

Android: [Request location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions) ·
[Access location in the background](https://developer.android.com/develop/sensors-and-location/location/background) ·
[Optimize for Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby) ·
[App widgets overview](https://developer.android.com/develop/ui/views/appwidgets) ·
[Widgets on lock screen FAQ](https://android-developers.googleblog.com/2025/03/widgets-on-lock-screen-faq.html) ·
[Play — background location permissions](https://support.google.com/googleplay/android-developer/answer/9799150)

Tooling: [expo-apple-targets](https://github.com/EvanBacon/expo-apple-targets) ·
[react-native-android-widget](https://github.com/sAleksovski/react-native-android-widget) ·
[Expo fingerprint](https://docs.expo.dev/versions/latest/sdk/fingerprint/) ·
[EAS app extensions](https://docs.expo.dev/build-reference/app-extensions/) ·
[expo-widgets (SDK 55+)](https://docs.expo.dev/versions/latest/sdk/widgets/)
