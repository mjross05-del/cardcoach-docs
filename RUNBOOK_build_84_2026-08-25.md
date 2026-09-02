# Build 84 — the run sheet

**Date:** 2026-08-25 · **For:** Mike (the only machine with EAS auth) · **Spec:** `SPEC_build_84_2026-08-25.md`
**Branch:** `feat/pro-tier-and-statement-import` · **13 commits** `48ae454 … 7fcc709`
**State:** all code and database work is DONE and committed. What follows is the part that needs your machine.

---

## 0 · Where things stand

| | |
|---|---|
| Branch vs `main` | **74 ahead, 0 behind** — `main` is an ancestor, so merging is a **fast-forward**. No conflicts are possible. |
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

## 2 · Console work — no rebuild

**Updated 2026-08-25.** A2 and A3 are both closed, and A2 turned out never to have been open —
Google sign-in was already fully configured and a live authorize round trip minted a session.
Nothing about auth gates the tester round any more. What is left below is **A11 and D6**.

| | What | Where |
|---|---|---|
| ~~**A2**~~ | ✅ **DONE — was already done.** Consent screen In production/External; Supabase Google provider enabled, ID `638080256275-j8qme1ga1b6…` + secret populated; `cardcoach://auth/callback` allowlisted; live `/auth/v1/authorize?provider=google` completed and minted a session (which also proves the redirect URI is registered). **Nothing for you to do.** | — |
| ~~**A3**~~ | ✅ **DONE — checked, and it was the bad case, so I hid it.** Apple *Client IDs* holds only `com.cardcoach.mobile` (a bundle ID). Correct for iOS's native path, useless for the web flow Android takes — the button was a guaranteed `invalid_client`. `renderAppleButton()` now returns `null` off iOS and Android shows `appleUnavailable`, rewritten to *"Sign in with Apple works on iPhone and iPad only. On Android, use Google or your email address."* Test added. **Nothing for you to do** unless you want Apple-on-Android back, which needs a Services ID — handoff §Step 1b. | — |
| **A12** | *Optional, cosmetic.* Supabase → Auth → URL Configuration → **Site URL** is still `http://localhost:3000`. Not a blocker (email confirmation is off; password reset passes its own `redirectTo`), but it is `{{ .SiteURL }}` in the email templates. Change it when cardcoach.ca deploys. | Supabase |
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

---

## 8 · Loose ends, closed 2026-08-25

Everything this lane touched is committed. What is deliberately left, and why:

| | |
|---|---|
| `card_coach_website/*`, `supabase/config.toml`, `supabase/functions/affiliate-click/`, `PENDING_affiliate_clicks.sql` | **The affiliate lane.** Untouched, uncommitted, exactly as found. |
| `PIPELINE_AND_DECISIONS.md`, `REVENUE.md` (docs repo) | Other lanes' uncommitted edits. Left as found. |
| A dozen untracked docs in `cardcoach-docs` | Predate this lane. Only this lane's four files were committed. |
| `_to_delete/cc_snapshot.tar.gz`, `dev_tmp_ent002_draft.sql`, `git-locks-20260825/` | Scratch this session produced. Already in the junk drawer, matching the existing `git-locks-2026082{1,2,4}` convention. Safe to bin. |
| `_to_delete/cowork-android-lane/` | Now carries `MERGED_2026-08-25.md`, mapping each of the five patches to the commit it landed as. **Do not re-apply them.** The 105 MB `CardCoach-1.2.0-vc6.aab` was never needed and can go. |

Fixed while tidying, both real:

- **`verify_bill_002_provider_readiness.mjs` was untracked** while `package.json` referenced it — so `pnpm verify:bill-002` worked on one machine and failed everywhere else. Same shape as the `registration.snippet.ts` that a comment referenced and nobody ever merged. Committed (`86b6ecf`).
- **`RELEASE_1.2.0`'s lineage section and `HANDOFF_pro_lane` §4.5 were left wrong by this work** and are corrected (`7fcc709`) — the first said the Android work existed on one machine, the second did not yet know that `jest.setup.ts` pins `useSafeAreaInsets` to all-zero and thereby deletes the arithmetic it is meant to test.

Verified at HEAD, all five components of `pnpm verify:ui` run individually:
`eslint src` 0 errors · `tsc --noEmit` 0 errors · i18n parity OK · **106 suites /
1285 tests / 0 failures** · sheet-layout PASS. Plus `verify:widget-001` PASS and
`expo config --type prebuild` evaluating at 1.3.0 with 16 plugins.

Production re-checked: 5 allowlisted, **25 active comps across 5 users** expiring
2026-11-23, signup trigger installed, pro resolves to 5 keys, `billing_paywall`
and `statement_import_write` false, `receipt_scanner` / `statement_import` /
`ambient_widget` true, `online_merchant` inactive.

---

## 9 · What actually shipped — execution record, 2026-08-25

Executed by a Claude Code session on Mike's machine against `~/dev/CardCoachv2`. **Both
platforms are built at 84 and submitted.**

### The artifacts

| | iOS | Android |
|---|---|---|
| EAS Build ID | `e1785be9-ce0d-4d60-8752-601411b5ce90` | `5a97eef4-0c67-4876-ae19-d101be343164` |
| Build number | **84** | **84** (versionCode) |
| Marketing version | 1.3.0 | 1.3.0 |
| Fingerprint (= Runtime Version) | `05ca321829ca70d5ab53b3651a5d2c6a72337b45` | `c5e5c012e7299776adcd64c6b05fe62a8eeb9c4b` |
| Commit | `1339030c8d0be54759139f5bd846210cfd772080` | `1339030c8d0be54759139f5bd846210cfd772080` |
| Submission ID | `bd031282-51ea-412f-b70d-9163603d3df5` | `df23dbf4-3710-4eb7-8d41-987f7bccf160` |
| Destination | TestFlight (Apple processing) | Play **internal**, `Release Status: completed` |
| Artifact | [.ipa](https://expo.dev/artifacts/eas/sWrBXBvSRctRooWn58v3o_0uNPl_y9B9eVL4HUwl-OA.ipa) | [.aab](https://expo.dev/artifacts/eas/ADj8o84P6OyTi90NEUwrQoqgpZnQWIN06pd24cUJzXk.aab) |

Both from the **same commit** — invariant #8 honoured. The two fingerprints differ from each
other, which is correct: the policy is `fingerprint`, computed per platform.

### §4 gate — the reason this build exists — PASSED

```
[WIDGET-NATIVE] checking build e1785be9-ce0d-4d60-8752-601411b5ce90
  ✓ ExtensionStorage present in the app binary (4 occurrences)
  ✓ the app is provisioned for group.com.cardcoach.mobile
  ✓ the widget extension is provisioned for group.com.cardcoach.mobile
[WIDGET-NATIVE] PASSED — this build can actually write to the widget's App Group.
```

**4 occurrences against build 82's zero.** The 15.5 → 16.4 deployment-target raise did what
it was for: the pod is no longer filtered out of autolinking and the widget's only route to
`UserDefaults(suiteName:)` is in the shipped binary.

---

## 10 · What went differently from the prompt

**1. `verify:ui` is flaky as a single process — 3 pass / 2 fail over 5 runs.** It is green
(twice consecutively on the final tree), but it is not *reliably* green, and that is the real
answer to "it has never run as one process". Neither failure is a product bug; both are
wall-clock assertions that lose a race when the machine is loaded, and neither reproduces in
isolation:

- `src/lib/__tests__/resilience.test.ts` › *transitions to half-open after reset timeout*.
  `CircuitBreaker.getState()` derives state lazily from `Date.now() - lastFailureTime >=
  resetTimeoutMs`. The test set `resetTimeoutMs: 100`, called `onFailure()`, then asserted
  `"open"` **on real timers**, installing fake timers only on the next line. Any pause >100 ms
  between those two adjacent statements — a V8 GC under a loaded 107-suite run — flips it to
  `"half-open"` early. Passed 3/3 in isolation, 8/8 standalone.
  **Fixed during this run** by moving `jest.useFakeTimers()` above the breaker construction,
  exactly matching the sibling test below it, which is not flaky for that reason. Uncommitted.
- `src/__tests__/MyCardsScreen.test.tsx:278` › *adds every selected card with a null last4*.
  A `waitFor` timeout. Its own source comment at line 276 already says it "is enough in
  isolation but not always when jest runs suites in parallel workers, which made this the one
  intermittently red test in a full run." Still true. **Not fixed** — left for a decision.

Both `verify:ui` failures landed in the jest step that runs immediately **after** the heavy
eslint step, while standalone `npx jest` went 8/8 green — consistent with memory pressure
from lint rather than anything in the tests' own logic.

**2. `scripts/verify_widget_native.mjs` was broken and could not run.** It shelled out to
`eas-cli build:view <id> --json --non-interactive`, but `--non-interactive` is not a flag on
`build:view` in eas-cli 22.4.0 (which is also what `eas-cli@latest` resolves to today) — it
exits `Nonexistent flag: --non-interactive`. So the §4 gate would have hard-failed for anyone
who ran it, on any build, for reasons having nothing to do with the widget. Dropping the flag
is sufficient; `--json` alone puts pure JSON on stdout. **Fixed and the gate then passed.**
Uncommitted. A gate nobody can run is worth as little as a gate nobody runs.

**3. The Android gate was not a gate.** Step 7 said records disagreed on whether the Play
service-account key exists. It exists at `~/secrets/cardcoach-play-service-account.json` —
**and it was already uploaded to EAS credentials**, 2026-08-24, Private Key ID
`cd256d1030a34947e5e9277c935724d65ea5d55c`, matching the local file. So handoff Step 2d was
done as well as 2a–2c; nothing needed uploading. Both records undersold reality. Handoff doc
corrected with the evidence.

**4. `--what-to-test` cannot be set from the CLI on this plan.** The first iOS submit failed
with *"Changes cannot be sent for review automatically... Changelog submission is currently
available for Enterprise plan only."* Resubmitted without it and it succeeded. **The "What to
test" text still needs typing into the TestFlight UI by hand.**

**5. The prompt's paths were slightly off.** `eas.json` lives in `apps/mobile`, not
`mobile_app_codebase`, so Steps 3/4 must run from `apps/mobile`. `build:version:set` is
interactive-only with no `--version` flag; it was driven through a pty and **both values
re-read as 84 before either build started**.

**6. Left undone, deliberately** — see the build 84 report:
- `main` is fast-forwarded **locally only**: `1339030`, **80 commits ahead of `origin/main`,
  unpushed**. Pushing was not asked for.
- The local service-account JSON was **not deleted**. It is redundant (the key is on EAS) and
  removing it is a one-line `rm` left for Mike.
- The Android first-submit failure mode never fired: `changesNotSentForReview` stayed `false`.

---

## 11 · Build 85 — the one 84 made necessary (2026-08-25 → 08-27)

Build 84 shipped, and then three things landed that could not reach it.

### Why 85 had to exist

**Two independent native changes**, either of which alone forces a binary:

1. `f3b9134` rewrote the receipt camera copy. The old string — *"The photo is never
   uploaded and never saved."* — was true while OCR ran on device. API-017/APP-021 make
   the app upload the image and possibly send it outside Canada, so the sentence would
   have become a false statement to users **and a false Play data-safety declaration**.
   InfoPlist strings are baked into the binary.
2. `9500bea` (APP-021) added **`expo-image-manipulator`**, a brand-new native module. A
   new pod can never be delivered over the air.

`eas fingerprint:compare` against build 84 confirmed the delta rather than assuming it —
`05ca3218…` → `d7a02945…`. Worth recording: **`locales/*.json` contents are NOT fingerprint
sources.** The iOS fingerprint has 53 sources and `locales/en.json` is not among them; only
`expoConfig` is, and it carries the *path*, not the text. A copy fix touching only the
localized permission strings would leave the fingerprint unchanged, look OTA-compatible,
and silently never reach anyone. This one was caught only because `app.config.ts` changed
alongside.

### The artifacts

| | iOS | Android |
|---|---|---|
| Build ID | `2a459328-852c-48bd-985f-a1d02a4225dc` | `1de60406-4167-4f1b-8769-b731a413ddb0` |
| Number | **85** | **85** |
| Fingerprint | `d7a02945185f31ed97bdf402abdfe5250b241869` | `e1a30960a1e12f8892c8c22ba7baa502ab99545c` |
| Commit | `599e6de` | `599e6de` |
| Submission | `c6c8ef45-974a-4bd3-a481-8eeeccee6da9` | `4c35ffc9-58f1-4275-8260-3f83f20c033b` |
| Landed | TestFlight, 08-27 | Play internal, 08-27 |

**iOS shipped two days ahead of Android.** iOS 85 went out 08-27; Android sat unsubmitted at
84 until it was noticed while writing the tester email. Android testers were a build behind
without anyone knowing. `eas submit:list` is the check — it is the only place the two
platforms are shown side by side.

### Gates

`verify_widget_native` PASSED (`ExtensionStorage` ×4, App Group on both app and extension).
Supplementary artifact check on the new pod, because build 82's lesson is that autolinking
can list a module while the binary has none of it: `ImageManipulatorModule` ×3,
`ExpoImageManipulator` ×26, `MLKitTextRecognition` ×3 — all present.

### What nearly blocked it

**Four eslint errors from `9500bea` failed the gate before jest ever ran** (`tsc` clean,
109 suites / 1300 tests green underneath). Two were real raw paddings; two were false
positives — `height: 2000` on a mock *image* object, which the rule cannot distinguish from
a style. Fixed in `599e6de`: the paddings now compose `spacing[3] + spacing[0.5]` for 14,
the idiom `ReceiptProvenanceBanner` already uses, so **the values did not change**; the
fixtures got a scoped disable rather than edited numbers, since one exists precisely to test
an oversized image.

### Edge functions — deployed, and the command in §5 is wrong

`0a32bfd` (classification rung order) is an edge function and reaches production by deploy,
not by build. Deployed 08-27: `resolve-place` v21, `recommend-here-v2` v30, both ACTIVE.

**A bare `supabase functions deploy` FAILS** on CLI 2.116 — the server-side bundler does not
pick up `supabase/functions/deno.json` and dies on `@supabase/supabase-js` and `zod` with
*"Relative import path not prefixed with / or ./ or ../"*. The working command is:

```bash
npx supabase functions deploy resolve-place recommend-here-v2 \
  --import-map supabase/functions/deno.json
```

### Testers

`tester_allowlist` is now **6** — `lisapietras63@gmail.com` added 08-27 (`build-85 tester
round`). She had no account, so nothing was granted; the signup trigger
`on_auth_user_created_tester_grant` is enabled and will comp her on registration. Verified
there is still no second route to Pro: 81 accounts, 6 allowlisted, and every active
entitlement traces to `manual`/`tester_allowlist`.

**She is an Android tester, so she needs a Play internal tester slot** — the allowlist grants
Pro, not the app. Still outstanding on the console side.

An Android tester checklist was published as an artifact, grouped by whether each item is a
fixed Android regression, new behaviour, or a known non-bug.

### OTA on 85 — 2026-09-02, wallet add-card search field

JS-only (search field at the top of the add-card sheet, filter by name / issuer / network,
EN+FR strings). Published with `--environment production`; both runtime versions verified
equal to the build 85 fingerprints above, so every current install on both platforms
receives it — no binary.

| | iOS | Android |
|---|---|---|
| Update group | `04797dbc-ec8f-46bc-aeca-94150006d18c` | `fbd4c798-eb68-4b6e-8a09-39007fca572b` |
| Runtime | `d7a02945…` (= build 85) | `e1a30960…` (= build 85) |
| Commit | `e4f3ddc` on `wallet/add-card-search` (CardCoachv2; fast-forwards onto main) | same |
| Confirmed on device | 09-02, yes | pending at time of writing |

Two things to know if you come back to this:

- **The first publish went to the `preview` channel** (groups `fde2387a` iOS / `fbe718ac`
  Android). No build has ever been made with the preview profile, so those groups are
  inert — ignore them. Builds 85 are both on `production`; that is the only channel with
  installs.
- The EAS record shows the commit with a `*` (dirty tree). The dirt was unrelated
  `card_coach_website/` and blog files another session had open; every file in the bundle
  matched `e4f3ddc`.
