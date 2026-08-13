# DISPATCH — Android launch lane (AND-001)

**Cut:** 2026-08-07 · **For:** a Claude Code session in `CardCoachv2/mobile_app_codebase`
**Authority:** `docs/planning/specs/AND-001_android_launch.md` (the spec; read it first).
Decisions signed by Mike 2026-08-07: free at launch, repo-convention spec, no Play account yet.
**Inputs:** `apps/mobile/eas.json`, `apps/mobile/app.config.ts`, `apps/mobile/src/services/socialAuth.ts`, `docs/app-store/app-store-submission-draft.md`, `docs/app-store/RELEASE_1.0.2_HANDOFF.md` (mirror its shape for the Play handoff).

Five items. **Item 0 is Mike-only and gates the calendar, not the code** — engineering items
1–4 can start immediately and in parallel with it.

> **The clock is the thing to respect.** For a personal Play account the 14-day / 12-tester
> closed test runs on tester opt-in time, not build quality. Every day items 1–2 slip before
> the first AAB reaches the closed track is a day added to launch. Ship rough, iterate on the
> track.

---

## 0. Play Console account (Mike, day 0)

Decide: personal account (US$25, 14-day tester gate) · organization account (D-U-N-S, no
gate) · or confirm whether Alex holds a pre-2023-11-13 personal account (gate wouldn't apply;
the Apple account is already his individual one — same question, other store).
Then: create account, pass identity verification, pay the fee. Nothing store-side moves
without this; all engineering below proceeds regardless.

**Deliverable:** account id + type recorded in WORKING_NOTES as a new numbered item.

---

## 1. INFRA-005 — Android build lane

- `apps/mobile/eas.json`: add `android` keys per profile — `development`: APK, dev client, internal; `preview`: APK, internal; `production`: AAB (`buildType: "app-bundle"`), store. Base image: current EAS Android default (do not pin without cause).
- Credentials: EAS-managed keystore (`eas credentials -p android`). Never a local keystore file in the repo.
- `submit.production.android`: track `internal` initially; service-account JSON path once Mike's Console exists (Play Console → API access). Leave a TODO keyed to item 0 if not ready.
- Verify `.easignore` excludes nothing Android builds need.
- Sanity: `npx expo-doctor`, then `eas build -p android --profile development`, install on a physical device, full manual smoke (auth → Now → search → store detail → record transaction → history).

**STOP if** the dev build renders any screen broken under edge-to-edge — that becomes APP-019's first work item, not a reason to pin `targetSdkVersion` below 36 (Play requires 36 for new apps from 2026-08-31).

**Deliverable:** first AAB on the closed track (or ready for it, pending item 0).

---

## 2. AUTH-006 — Google sign-in + Android auth parity

Order inside this item is load-bearing: Supabase config before code, code before screen.

1. Google Cloud: OAuth client (web application type) → client id + secret into Supabase Auth → Providers → Google. Redirect stays the Supabase callback; the app-side deep link `cardcoach://auth/callback` is already allowlisted for Apple — confirm it's provider-agnostic.
2. `services/socialAuth.ts`: `export type SocialAuthProvider = "apple" | "google"`. The generic `signInWithOAuthProvider` path (supabase `signInWithOAuth` + `WebBrowser.openAuthSessionAsync`) already handles any provider — Google needs **no new flow code**. Keep the native-Apple branch iOS-only as is.
3. `AuthContext`: add `signInWithGoogle` mirroring `signInWithApple` (one-liner to the service seam).
4. `AuthChoiceScreen`: Google button per Google brand guidelines, above/beside the existing Apple fallback `Button` that non-iOS already renders. Apple stays visible on Android (account continuity for iPhone-origin users).
5. Strings: en + fr for the button and error fallbacks (`verify:i18n-parity` gates).
6. Tests: extend `socialAuth.test.ts` + `AuthContext.test.tsx` for the new provider; a Platform.OS=android case proving Apple routes to web OAuth.

**Invariant:** no screen-level `supabase.auth` calls; everything through the service seam.

**Deliverable:** all three auth methods round-trip on a physical Android device, including Custom-Tabs return and password-reset deep link.

---

## 3. APP-019 — Android adaptation pass

- Edge-to-edge/safe-area audit, every screen, both themes: SDK 54 targets API 36 where edge-to-edge cannot be disabled. UI-005 (ScreenContainer) is a STUB — promote it if the audit finds repeated per-screen fixes; don't hand-patch insets screen by screen.
- Hardware + predictive back: React Navigation 7 handles defaults; verify no screen traps back (keypad modal APP-008, auth stack, password-recovery state).
- Notifications: verify the existing channel (`NotificationContext`) + `POST_NOTIFICATIONS` request (`transactionReminder.ts`) on an Android 13+ device; reminder fires from a backgrounded app.
- Keyboard: keypad screens (APP-008), search field (APP-002 inline results), no `windowSoftInputMode` surprises.
- Splash light/dark + adaptive icon render check (config already present).
- `locales` tripwire: `locales/{en,fr}.json` hold only the iOS `NSLocationWhenInUseUsageDescription` key, and Expo also injects locale JSON into Android `strings.xml` — iOS-only keys with no default value are a known Gradle-lint failure (expo/expo#25188). If the first Android build trips on it, nest the strings under platform keys. Either way Android's OS permission dialog shows no custom rationale; the in-app copy is the Android story.

**Deliverable:** audit checklist committed to `docs/dev_notes/` with per-screen pass/fail and fixes landed.

---

## 4. QA-010 — Android QA lane

- Extend FIX-004/005 preflights: Android application id (`com.cardcoach.mobile`) + emulator-installed check alongside the iOS simulator ones.
- Maestro happy path (QA-006 flow) green on Android emulator.
- Device matrix minimum: recent Pixel (stock), one Samsung (One UI), one small/low-end at the minSdk floor. Both locales, both themes, offline-start (resilience path in AuthContext init).
- Full `pnpm verify` green from the same commit that builds the closed-track AAB.

**Deliverable:** QA matrix results in the audit doc; the production-submission commit is pinned and recorded (RELEASE-handoff style: version, versionCode, EAS build id, git commit, fingerprint).

---

## 5. REL-001 — Play presence + launch (Mike + session, after item 0)

- App content forms: **data safety** (use the inventory table in AND-001 §Data safety — email/name, location, user-entered purchase history, Sentry diagnostics; all collected-not-shared), **Financial features declaration** (mandatory for all apps; v1 has no lending/brokering/money-movement and no affiliate links — declare truthfully; re-file before any affiliate build), ads = none, target audience 18+, privacy policy `cardcoach.ca/privacy`.
- Account deletion **web URL** on cardcoach.ca (in-app deletion exists; Play wants the link too). Coordinate with site items #17/#18.
- Listing: adapt `app-store-submission-draft.md`; new assets: feature graphic 1024×500 (Warm Logic palette, Mikayla lane if she's doing brand assets), phone screenshots.
- Closed test: 12 testers opted in, 14 continuous days (personal-account path). Recruit day one — family, the Alex/Mikayla circle, warm users.
- Apply for production access → submit → **staged rollout starting ~20%**, Sentry watch for a week before 100%.

**Deliverable:** `docs/app-store/RELEASE_android_1.x_HANDOFF.md` in the shape of the 1.0.2 handoff — everything needed to press the button, and the record of having pressed it.

---

## Out of scope (do not do, even if adjacent)

FCM / `google-services.json` · Play Billing / paywall · any new native module · affiliate
links · tablet/Wear/Auto form factors · web app changes beyond the deletion URL page.

## Done means

AND-001 §Acceptance, all five bullets. Then: inventory rows INFRA-005 / AUTH-006 / APP-019 /
QA-010 / REL-001 flipped to DONE, WORKING_NOTES item closed, decision entry appended to
PIPELINE_AND_DECISIONS.md recording the launch date and rollout percentage.
