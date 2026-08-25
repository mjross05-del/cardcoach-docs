# PROMPT — build 84 execution: verify, merge, version, build both, submit both (code runtime)

Authored by the 2026-08-25 Cowork session. You are a Claude Code session on
Mike's machine. Six jobs: run the one gate that needs a single process,
fast-forward main, set both build numbers to 84, EAS-build both platforms,
verify the iOS artifact, submit both. Then file a report. Nothing else.

## State when this prompt was written (verify, don't trust)

- `~/dev/CardCoachv2` — the git root. The mobile app is the
  `mobile_app_codebase/` **subdirectory**, not its own repo.
- Branch **`feat/pro-tier-and-statement-import` = 1339030**, on top of
  1bd52e4, on top of c99e42d. **main = 67e7945**, 78 behind, 0 ahead —
  fast-forward is clean.
- Working tree dirty with **another lane's** files: `mobile_app_codebase/
  supabase/config.toml` and three `card_coach_website/site/*`. **Leave them.**
  Do not commit, stash-drop, or revert them.
- `app.config.ts` `version: "1.3.0"` — already correct, do not re-bump.
  `runtimeVersion.policy: "fingerprint"`.
- **`autoIncrement` is gone** from `eas.json`'s production profile (1339030).
  Build numbers are now set explicitly, once per train. Any doc telling you
  not to hand-set the Android versionCode predates this — `RELEASE_1.0.3_
  RUNBOOK.md` is one, and it is a dated record, not current guidance.
- Gates re-verified by the Cowork session on this tree tonight: eslint 0
  errors, `tsc` 0 errors, verify:i18n-parity ✓, verify:sheet-layout ✓, jest
  **107 suites / 1287 tests / 0 failures** — but jest ran in 6 shards and
  `verify:ui` has never run as one process. That is Step 1.
- `~/dev/cardcoach-docs` = 005c0cb. Background: `SPEC_build_84_2026-08-25.md`,
  `RUNBOOK_build_84_2026-08-25.md`, `WORKING_NOTES.md` #24.

## Step 0 — git artifacts + preconditions

```bash
find ~/dev/CardCoachv2/.git -maxdepth 3 \( -name '*.lock' -o -name 'tmp_obj_*' \) -delete
git -C ~/dev/CardCoachv2 log --oneline -3 feat/pro-tier-and-statement-import  # expect: 1339030, 1bd52e4, c99e42d
git -C ~/dev/CardCoachv2 rev-list --left-right --count main...feat/pro-tier-and-statement-import  # expect: 0	78
```

Any mismatch → STOP and report.

## Step 1 — the gate that has never run as one process

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase && pnpm verify:ui   # ~4 min, exit 0
```

Not green → STOP and report.

## Step 2 — fast-forward main WITHOUT a checkout

```bash
cd ~/dev/CardCoachv2
git merge-base --is-ancestor main feat/pro-tier-and-statement-import \
  && git branch -f main feat/pro-tier-and-statement-import \
  && git rev-parse --short main    # expect: 1339030
```

`git checkout main` will refuse — another lane has `config.toml` dirty and
one of the 78 commits touches it. The `--is-ancestor` guard makes this
ff-only; if it refuses, the branch diverged → STOP and report.

## Step 3 — set both to 84

`autoIncrement` was removed from `eas.json`'s production profile in 1339030,
so the number you set is the number that ships. No arithmetic, nothing to
watch for.

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase/apps/mobile
eas build:version:set -p ios       # enter 84
eas build:version:set -p android   # enter 84
eas build:version:get -p ios       # expect 84
eas build:version:get -p android   # expect 84
```

Both must read 84 before you build. (For context if something looks off:
iOS was at 83 and Android at versionCode 6 — autoIncrement had been moving
each platform only on its own builds, which is exactly how they drifted that
far apart. That is why it is gone.)

## Step 4 — build both at 84

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
eas build --platform ios     --profile production --non-interactive
eas build --platform android --profile production --non-interactive
```

**Confirm the build-number line EAS prints at the start of each says 84.**
Anything else → cancel and report. Record both build IDs and fingerprints.

## Step 5 — prove the widget shipped (iOS only, NOT optional)

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
node scripts/verify_widget_native.mjs <ios-build-id>
```

Build 82 shipped without `ExtensionStorageModule` and nothing noticed for a
week: the JS half degrades to empty stub functions, so `writeSnapshot`
returns true and the lock screen shows its first-run tile forever.
Autolinking resolving it locally proves nothing — it listed the module while
the shipped binary had zero occurrences. This script downloads the IPA and
greps the real binary. This build raises the iOS floor 15.5 → 16.4, which is
the fix; this is how you confirm it took.

**Fails → STOP. Do not submit iOS.**

## Step 6 — iOS → TestFlight

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
eas submit --platform ios --latest --profile production
```

ASC App ID 6757937693, team AF887JD7ZG. "What to test": Pro surfaces end to
end, the Android-parity fixes, widget draws on the lock screen. Do NOT
promise Apple sign-in on Android — that button is hidden in this build.
App Store version creation stays with Alex; he has still not accepted the
Apple Program License Agreement (blocks App Store, not TestFlight).

## Step 7 — Android → Play internal (GATED — do not improvise past the gate)

Records disagree on whether the Play service-account key exists.
`mobile_app_codebase/docs/app-store/RELEASE_android_1.x_HANDOFF.md` has
checklist Steps 2a–2d unticked; `cardcoach-docs/WORKING_NOTES.md` says the
Cloud + Play Console side was executed 2026-08-24 with only the EAS upload
left. **Look for the JSON before assuming either.**

```bash
eas credentials -p android    # production -> Google Service Account -> upload
eas submit --platform android --latest --profile production   # internal track
```

Key exists → upload it, submit, delete the local JSON copy. Key does not
exist → report "Android AAB built at 84, waiting on handoff Step 2" and stop
this step. **Either way, tick the checklist in the handoff.** This lane
already lost real time to one stale checkbox — #24b claimed Google sign-in
config was the gating Android blocker, five documents repeated it, and it had
been done and working the whole time.

## Step 8 — report

Both build IDs + fingerprints + confirmed build numbers, the
`verify_widget_native` output, TestFlight status, Android gate state. Update
`cardcoach-docs/RUNBOOK_build_84_2026-08-25.md` with what actually shipped
and anything that went differently from this prompt. Post the report back to
Mike.
