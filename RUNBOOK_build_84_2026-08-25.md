# Build 84 — the run sheet

**Date:** 2026-08-25 · **For:** Mike (the only machine with EAS auth) · **Spec:** `SPEC_build_84_2026-08-25.md`
**Branch:** `feat/pro-tier-and-statement-import` · **11 commits** `48ae454 … b812781`
**State:** all code and database work is DONE and committed. What follows is the part that needs your machine.

---

## 0 · Where things stand

| | |
|---|---|
| Branch vs `main` | **72 ahead, 0 behind** — `main` is an ancestor, so merging is a **fast-forward**. No conflicts are possible. |
| Test suite at HEAD | **106 suites · 1285 tests · 0 failures** |
| `tsc --noEmit` | 0 errors |
| `eslint src` | **0 errors**, 183 pre-existing warnings |
| `verify:sheet-layout` | PASSED (it was CRASHING on HEAD before this branch — see §1) |
| `verify_i18n_parity` | OK (en/fr) |
| Testers | 5 accounts comped, 25 grant rows, expiring **2026-11-23** |
| `billing_paywall` · `statement_import_write` | both **false** |

Not committed, and deliberately left alone: `card_coach_website/*` and
`supabase/config.toml` + `supabase/functions/affiliate-click/` — that is the affiliate lane, not this one.

---

## 1 · Before anything else — the CI gate is red and has been for a while

`verify:sheet-layout` crashes rather than verifying on Node 22.23.2, and
`.github/workflows/ci.yml:30` pins `node-version: 22` **floating**. So CI has been running a red
gate on every push since the GitHub runner image moved past 22.16. The branch fixes the crash, but
the floating pin is still there.

**One line, worth doing now:**

```yaml
# .github/workflows/ci.yml:30
- uses: actions/setup-node@v4
  with:
    node-version: 22.16.0    # was: 22 — match the eas.json build image
```

---

## 2 · Console work — no rebuild, and A2 gates the tester round

These are the only things standing between build 84 and a tester opening it. **A2 in particular
must land before any Android tester touches the build**: Google is the *first* button on Android's
auth screen and it throws today.

| | What | Where |
|---|---|---|
| **A2** | Google sign-in provider. OAuth **web** client in `cardcoach-auth` (web, not Android — Supabase brokers the flow), consent screen published to production, redirect URI `https://hrzpznlpmxxrbtwskacu.supabase.co/auth/v1/callback`, then client ID + secret into Supabase → Auth → Providers → Google. | GCP Console + Supabase |
| **A3** | Apple-on-Android. Android's Apple button routes to **web** OAuth, which needs a Services ID + secret — a different configuration from iOS's native path. Check Supabase → Auth → Providers → Apple: if only a bundle-id client is listed, either configure it or tell me and I will hide the button and wire `screens.auth.choice.appleUnavailable`, which already exists in both catalogues and is connected to nothing. | Supabase |
| **A11** | Play key onto EAS. Then delete the local JSON. | `eas credentials -p android` → production → Google Service Account |
| **D6** | Alex accepts the Apple Program License Agreement. Does not block TestFlight; blocks every App Store submission after it. | developer.apple.com → Agreements |

---

## 3 · The build

Run from `mobile_app_codebase/apps/mobile` unless noted.

```bash
# 3.1  Verify the COMMIT, not the tree. A green run from fifteen minutes ago is
#      not evidence about what you are on the point of building.
cd ~/dev/CardCoachv2/mobile_app_codebase
pnpm install                     # this repo has repeatedly sat with a partial node_modules
pnpm verify:ui                   # ~4 min. THE gate — lint, typecheck, i18n parity, jest, yoga
pnpm verify:sheet-layout         # ~1s
pnpm verify:bill-002             # expect CANNOT SELL — correct for this build.
                                 # It reports UNKNOWN unless the server half can
                                 # run, so export these first or read the SKIPs:
                                 #   CARDCOACH_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

# 3.2  Merge to main. Fast-forward, so this cannot conflict.
git checkout main && git merge --ff-only feat/pro-tier-and-statement-import
git push origin main

# 3.3  Pin the build number ONCE, on both platforms. 84 is one above the highest
#      either has consumed (iOS 82 shipped / 83 orphaned; Android vc5 / vc6).
cd apps/mobile
npx eas-cli build:version:set -p ios       # -> 84
npx eas-cli build:version:set -p android   # -> 84

# 3.4  Build BOTH from the SAME commit. Invariant #8, honoured for the first
#      time since 1.0.3. Export the Sentry vars first or the evaluated config
#      differs from the build's and every fingerprint you compute is wrong.
export SENTRY_ORG=falcon-view-group
export SENTRY_PROJECT=react-native-card-coach
npx eas-cli build -p ios     --profile production
npx eas-cli build -p android --profile production
```

---

## 4 · The gate this build exists for — DO NOT SKIP

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
node scripts/verify_widget_native.mjs <IOS_BUILD_ID>
```

It downloads the finished IPA and takes the binary apart: `ExtensionStorage` present in the app
binary, App Group signed into **both** the app and the extension.

**If it fails, do not submit.** The lock-screen widget has never worked on any iOS build ever
shipped — `ExtensionStorage` appears zero times in build 82's binary and zero times in its
65,886-line build log, because the pod needs iOS 16.4 and the app targeted 15.5, so autolinking
skipped it in yellow and every build went green. ~27 snapshots a day wrote into an empty stub.
**Autolinking resolving the module locally proves nothing** — `expo-modules-autolinking resolve -p ios`
listed it happily the whole time, because that command does not apply the platform filter. The
binary is the only trustworthy check.

Android has the same class of bug from the opposite direction and it is fixed in this branch:
`registerWidgetTaskHandler` was called nowhere, so the widget was offerable in the launcher with
correct EN/FR labels and then drew nothing, forever.

---

## 5 · Submit

```bash
cd apps/mobile
npx eas-cli submit -p ios     --latest --profile production   # -> TestFlight
npx eas-cli submit -p android --latest --profile production   # -> Play internal track
```

**Known first-submit failure mode on Android:** if Google answers *"Changes cannot be sent for
review automatically"*, set `changesNotSentForReview: true` under `submit.production.android`,
re-run, send the changes for review once from the Play Console UI, then flip it back to `false` —
or production submits will silently sit unsent. It fires on apps whose store listing has never
completed a review, which is plausible here: CardCoach has only ever released to internal.

---

## 6 · On the phone

The tester comps are already live, so Pro is on the moment you install. Six things only a device
can settle:

1. **The lock-screen widget, iOS.** First time it has ever had a chance. Add it, then confirm
   Settings → About shows `1.3.0 (84)`.
2. **The home-screen widget, Android.** Also a first. Add it from the launcher — it should draw a
   card, not a blank tile.
3. **The four Pro sheets.** The X should sit ~16pt below the sheet's rounded edge now, not ~78pt,
   and there should be no empty band above the first content.
4. **Camera on an API 24–28 Android device — it must now SUCCEED.** This was a confirmed failure,
   not an untested risk: every capture on Android 7–9 rejected right after the camera grant.
   `plugins/withCameraManifest.js` declares `WRITE_EXTERNAL_STORAGE` capped at API 28. Also watch
   the prebuild log for `No <receiver> ending in .CardCoach` — that warning is the tell that the
   widget-strings plugin has stopped running after the library, which ships an English picker to
   French launchers.
5. **ML Kit resolving in a release build.** If the scanner says "isn't available in this version",
   the TurboModule interop probe missed and the provider swap is one file.
6. **The ten AND-001 adaptation items and the six-row device matrix** — open and unexecuted since
   2026-08-07, blocked on there being no Android SDK or emulator on this machine. A real device
   closes them.

---

## 7 · Still owed after this build

- ~~**A5 — `withCameraManifest`.**~~ **CLOSED 2026-08-25 — and it was never theoretical.** The
  commit `e63c9951` is gone from every reflog, object store and bundle in `~/dev`, but the AAB did
  not need reading: the **patch series it was built from was sitting in
  `_to_delete/cowork-android-lane/android-patches.tgz`** the whole time. All five patches are now
  reconciled onto the branch. What `withCameraManifest` fixes: on API ≤ 28 `expo-image-picker`'s
  `launchCameraAsync` demands `WRITE_EXTERNAL_STORAGE` alongside `CAMERA` and requires both granted,
  and a permission absent from the manifest is auto-denied — so **every receipt capture on Android
  7–9 rejected with `ERR_USER_REJECTED_PERMISSIONS`** right after the user granted the camera. The
  device check in §6.4 is now "a capture on an API 24–28 device must SUCCEED", not "see whether it
  breaks".
- **B3** is §4 above — it closes when the artifact check passes.
- **B8** — leave `card_slot_limit` and `auto_location_gate` **false** through the tester round.
  Flipping them withdraws working features from 80 existing users. Exercise those paths behind a
  temporary flip on one account instead.
- **The Apple account structure** (`RUNBOOK_pro_go_live_2026-08-24.md` §1). Still the gate on
  revenue, still not a gate on this build, and it gets more expensive every month it runs.
- Record build IDs, fingerprints, commit and submission IDs in the release record; close the
  Android handoff checklist; put the iOS 15 drop in the release notes.
