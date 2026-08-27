# PLAN — 1.0.3 release push: TestFlight (iOS) + Play internal track (Android)

Owner: the Cowork tie-disclosure session (coordinating) · Mike (approvals,
Play Console) · Alex (App Store Connect) · Code runtimes (mechanical steps).
Trigger: Mike says **"retheme done"** in the Cowork session.

## What 1.0.3 contains

APP-020 tie display (inert until the server flag flips) + RETHEME-001 (Final
Spec rebrand) + everything already on main since 1.0.2 build 56 (Neo
Financial issuer, API-011 receipt disclosure, 1.0.3 prep + EAS Update wiring
from 56965af). All JS-layer; native fingerprint should match build 56 unless
the retheme touches native assets (icon/splash — it should not).

## Preconditions already met tonight

- API-016 committed (67cab22), flag row live in prod, **OFF** — 1.0.3 renders
  identically to 1.0.2 until the flag flips post-release.
- Deploy prompt staged: `PROMPT_code_push_deploy_2026-08-16.md` (functions
  v24/v23, dark).
- Android production AAB lane proven (45bc2cfa, versionCode 4); EAS-managed
  keystore; remote versionCode auto-increment.
- iOS 1.0.2 build 56 already in App Store Connect (pipeline proven).

## Sequence on trigger

1. **Merge order:** `feat/api016-app020-tie-disclosure` (with the retheme
   commit on top) → main, push. Run `pnpm verify:api-016` + `pnpm verify:ui`
   on main post-merge — both must exit 0.
2. **Server deploy (dark):** run PROMPT_code_push_deploy_2026-08-16.md if
   not already done. Flag stays OFF.
3. **Version:** confirm marketing version 1.0.3 both platforms (invariant
   #8: shared, manual). iOS buildNumber auto/next (57+); Android versionCode
   remote auto-increment (5).
4. **Builds:** `eas build --platform ios --profile production` and
   `--platform android --profile production` from the same commit. Record
   IDs/fingerprints in the two RELEASE handoff docs.
5. **iOS → TestFlight:** `eas submit --platform ios` (Alex's ASC App ID
   6757937693, team AF887JD7ZG) — lands in TestFlight processing; add
   internal testers; Alex attaches the build to a 1.0.3 App Store version
   when TestFlight soak looks clean. Update RELEASE_1.0.2_HANDOFF successor
   doc (1.0.3) with build number + "what's new" copy: rebrand + groundwork
   for tie display (copy must NOT promise tie UI — the flag is off at
   submission time).
6. **Android → Play internal track:** GATED ON STEP 0 of
   RELEASE_android_1.x_HANDOFF (Play Console account — Mike, unchanged).
   Once the account + service-account key exist: `eas submit --platform
   android --track internal` per the handoff; closed-track testers per
   QA-010 matrix.
7. **Device pass (folds in discrepancies Item 2):** QA-010 matrix on the
   1.0.3 builds — including one explicit check: 3-card wallet renders 3
   carousel cards on Android.
8. **Flag flip (separate, after 5/6 are live):** run the production probe in
   `scripts/verify_api_016_tie_disclosure.mjs`'s header, then apply
   `cardcoach-docs/deltas/2026-08-XX__runtime_flags__tie_disclosure_on_TEMPLATE.sql`
   (dated, Mike's approval recorded). Rollback = flag off, no deploy.
9. **Discrepancies Item 1** (MCC backfill or engine policy) ships server-side
   on Mike's decision, independent of app builds — see
   LANE_ios_android_discrepancies_2026-08-16.md.

## Accelerator (optional)

EAS Update wiring exists (56965af): the retheme + tie UI are pure JS, so an
EAS Update channel push can reach existing TestFlight/dev installs before
store review — useful for the device pass; store builds above remain the
release of record.

## Standing rule for this plan

Nothing here flips the tie flag, submits to a store, or writes card data
without the named human's action: Mike (Play, flag, data), Alex (App Store).
The Cowork session prepares, sequences, verifies, and reports.
