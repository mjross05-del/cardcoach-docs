Take the CardCoach build-84 release lane to the finish. Everything is committed and
verified; what's left needs a shell with network and my Expo credentials, which a cloud
session doesn't have. That's you.

## Where things stand

Repo: `~/dev/CardCoachv2` (git root — the mobile app is the `mobile_app_codebase/`
subdirectory, not its own repo). Branch `feat/pro-tier-and-statement-import`, **77 commits
ahead of main, 0 behind**, fast-forward clean. Marketing version is already `1.3.0` in
`app.config.ts`. Target: **build 84 on both platforms** — the whole point of the lane is that
"build N" means the same number on iOS and Android from here on.

Already run and green, so don't redo them piecemeal: eslint 0 errors, `tsc` 0 errors,
`verify_i18n_parity` PASS, `verify_sheet_layout` PASS, and the full jest suite at
**107 suites / 1287 tests / 0 failures** (run in shards — `pnpm verify:ui` is step 1 below
precisely because it hasn't been run as one process).

Background if you want it, in `~/dev/cardcoach-docs`: `SPEC_build_84_2026-08-25.md`,
`RUNBOOK_build_84_2026-08-25.md`, `RUNSHEET_build_84_commands_2026-08-25.md` (the command
list this prompt is drawn from), and `WORKING_NOTES.md` #24. Read them only if something
below doesn't match reality — they're context, not instructions.

## Two traps. Both silent. Do not skip past these.

**1. `autoIncrement` will give you 85.** `apps/mobile/eas.json` has `autoIncrement: true` on
the `production` profile and `cli.appVersionSource: "remote"`. EAS reads the stored remote
number and **adds one**. So set the remote version to **83**, not 84, and let the build
increment into 84. Confirm with `build:version:get` before building, and **watch the number
EAS prints when the build starts — if it says 85, cancel it.** Getting this wrong breaks the
one property this release exists to establish.

**2. Don't `git checkout main`.** `mobile_app_codebase/supabase/config.toml` and three
`card_coach_website/site/*` files are modified and uncommitted — they belong to a different
lane (affiliate-click). One of the 77 commits touches `config.toml`, so the checkout will
refuse. Move the ref instead; it's the same fast-forward and never touches the working tree.
**Do not commit, stash-drop, or revert those files** — they aren't mine to touch.

## The sequence

```bash
# 1. The gate that hasn't run as one process
cd ~/dev/CardCoachv2/mobile_app_codebase
pnpm verify:ui                      # ~4 min. Must be green before anything else.

# 2. Fast-forward main without a checkout
cd ~/dev/CardCoachv2
git merge-base --is-ancestor main feat/pro-tier-and-statement-import \
  && git branch -f main feat/pro-tier-and-statement-import \
  && echo "main -> $(git rev-parse --short main)"

# 3. Pin to 83 (see trap 1)
cd mobile_app_codebase/apps/mobile
npx eas-cli build:version:set -p ios       # enter 83
npx eas-cli build:version:set -p android   # enter 83
npx eas-cli build:version:get -p ios
npx eas-cli build:version:get -p android   # both must read 83

# 4. Build
npx eas-cli build -p ios     --profile production
npx eas-cli build -p android --profile production

# 5. Prove the widget actually shipped — iOS only, and do not skip it
cd ~/dev/CardCoachv2/mobile_app_codebase
node scripts/verify_widget_native.mjs <ios-build-id>

# 6. Submit
cd apps/mobile
npx eas-cli submit -p ios --latest --profile production        # → App Store Connect 6757937693
npx eas-cli credentials -p android                              # production → Google Service Account
npx eas-cli submit -p android --latest --profile production     # → internal track
```

## Why step 5 is not optional

Build 82 shipped **without** the widget's native storage module and nothing noticed for a
week. `@bacons/apple-targets` ships `ExtensionStorageModule`, the only route from JS to
`UserDefaults(suiteName:)` — and its JS half degrades to stub methods that are literally
empty functions when the native half is absent. So the app publishes snapshots,
`writeSnapshot` returns `true`, and the lock screen shows its first-run tile forever.
Autolinking resolving the module locally proves nothing: it listed the module while the
shipped binary contained zero occurrences of the string. `verify_widget_native.mjs`
downloads the IPA and greps the real binary. This build raises the iOS floor 15.5 → 16.4,
which is the fix for exactly that failure — step 5 is how you confirm it took.

**If step 5 fails, stop and tell me. Do not submit iOS.**

## Authorization and stop conditions

I've approved the builds and both submits for build 84 — you don't need to ask again before
spending compute or pushing to TestFlight and the internal Play track. Stop and ask me if:

- `pnpm verify:ui` is not green
- either build reports a number other than 84
- `verify_widget_native.mjs` fails
- the fast-forward guard in step 2 refuses
- anything wants to modify files outside this lane

## One thing I can't answer for you

The records disagree on the **Play service-account key**.
`mobile_app_codebase/docs/app-store/RELEASE_android_1.x_HANDOFF.md` has its checklist Steps
2a–2d all unticked; `cardcoach-docs/WORKING_NOTES.md` says the Google Cloud and Play Console
side was executed 2026-08-24 (project-scoped policy override, key minted, Play permissions
granted) with only the EAS upload left. Look for the JSON before assuming either. If it
exists, step 6's `eas credentials` is all that's needed; if not, you're doing handoff §Step 2
first, and the Android submit waits.

**Whichever it turns out to be, tick the checklist in the handoff.** This lane already lost
real time to one stale checkbox: #24b claimed Google sign-in provider config was the gating
Android blocker, five documents repeated it, and it had been done and working the whole time.
Leave the record true.

Also open, not yours: Alex still needs to accept the Apple Program License Agreement. It
doesn't block TestFlight; it blocks every App Store submission after it.

## When you're done

Give me the two build IDs, the two submit results, and the `verify_widget_native` output.
Then update `cardcoach-docs/RUNBOOK_build_84_2026-08-25.md` with what actually shipped —
build numbers, artifact IDs, and anything that went differently from this prompt.
