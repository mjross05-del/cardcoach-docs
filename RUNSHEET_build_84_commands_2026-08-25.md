# Build 84 — the commands, in order

**Why you and not me.** I checked before answering: the shell I have on your machine has
**no network at all** (`api.expo.dev` and `registry.npmjs.org` both fail to connect), there is
no `eas` CLI installed globally or in `node_modules/.bin`, `eas-cli` is not in `package.json`
(the docs have always used `npx eas-cli`, which needs the registry), and the `~/.expo` I can
see is the sandbox's home, not yours — so it does not carry your Expo credentials. `eas build`
and `eas submit` cannot run from here. Every command below has to come from your terminal.

Run these from `~/dev/CardCoachv2/mobile_app_codebase`. The `eas` ones from `apps/mobile`.

---

## ⚠️ Read these two before you start

### 1. `autoIncrement: true` will give you 85, not 84

`eas.json` → `build.production` has **`autoIncrement: true`**, and `cli.appVersionSource` is
`"remote"`. So EAS takes the stored remote number, **adds one**, and builds that. If you set
the remote version to 84 you will ship **85** on both platforms.

**Set it to 83.** Then the build increments to 84.

Verify before you spend a build — `eas build:version:get` should read 83, and when the build
starts EAS prints the number it assigned. **If it says 85, cancel it.** Getting this wrong is
how "build N means the same number on both platforms" quietly stops being true.

<details><summary>Deterministic alternative if you'd rather not trust the increment</summary>

Temporarily set `"autoIncrement": false` in the production profile, set the remote version to
exactly **84**, build both, then put `autoIncrement` back. `eas.json` is not a runtime
fingerprint input, so toggling it does not invalidate anything.
</details>

### 2. Don't `git checkout main` — you have other lanes dirty

`mobile_app_codebase/supabase/config.toml` (the affiliate-click lane) and three
`card_coach_website/site/*` files are modified and uncommitted. One of the 77 lane commits
touches `config.toml`, so `git checkout main` will refuse to switch. Move the ref instead —
same result as a fast-forward merge, and it never touches your working tree.

---

## Step 1 — the gate I couldn't finish

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
pnpm verify:ui
```

I ran all five of its steps individually and they pass — eslint 0 errors, tsc 0 errors,
i18n parity PASS, 107 suites / 1287 tests, sheet-layout PASS. What I could **not** do is run
them the way CI does, in one process, because corepack cannot download pnpm without a network.
This is the run that counts. Expect ~4 minutes.

## Step 2 — move main to the lane tip

```bash
cd ~/dev/CardCoachv2
git merge-base --is-ancestor main feat/pro-tier-and-statement-import \
  && git branch -f main feat/pro-tier-and-statement-import \
  && echo "main -> $(git rev-parse --short main)"
```

The `--is-ancestor` guard makes this fast-forward-only in effect: it refuses if the branch has
diverged. Right now it hasn't — 77 ahead, 0 behind.

## Step 3 — pin the version (see trap 1)

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase/apps/mobile
npx eas-cli build:version:set -p ios       # enter 83
npx eas-cli build:version:set -p android   # enter 83

npx eas-cli build:version:get -p ios
npx eas-cli build:version:get -p android
```

Both must read **83** before you build. `version` in `app.config.ts` is already `1.3.0`.

## Step 4 — build both

```bash
npx eas-cli build -p ios     --profile production
npx eas-cli build -p android --profile production
```

**Watch the build-number line EAS prints at the start of each.** It must say **84**.
Add `--no-wait` if you'd rather not hold the terminal; you'll get a build id either way.

## Step 5 — prove the widget actually shipped (iOS only, do not skip)

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
node scripts/verify_widget_native.mjs <ios-build-id>
```

This downloads the IPA and greps the real binary for `ExtensionStorage`. It exists because
build 82 shipped without the native module and nothing noticed for a week — autolinking
resolving it locally proves nothing, the JS half degrades to empty stub functions, and
`writeSnapshot` happily returns `true` while the lock screen shows its first-run tile forever.
**If this fails, do not submit.** The iOS floor raise to 16.4 in this build is the fix for
exactly that; this is how you confirm it took.

## Step 6 — submit

**iOS — should work now:**
```bash
cd ~/dev/CardCoachv2/mobile_app_codebase/apps/mobile
npx eas-cli submit -p ios --latest --profile production
```
Goes to App Store Connect app `6757937693`, i.e. TestFlight.

**Android — needs the Play key on EAS first:**
```bash
npx eas-cli credentials -p android
# → production → Google Service Account → upload the JSON
npx eas-cli submit -p android --latest --profile production
```
Lands on the **internal** track (`submit.production.android.track`).
Delete the local JSON copy once EAS has it.

---

## Two things I can't resolve for you

**Where the Play service-account key actually stands.** The records disagree.
`RELEASE_android_1.x_HANDOFF.md`'s checklist has Steps 2a–2d all unticked, but WORKING_NOTES
says the Google Cloud and Play Console side was executed 2026-08-24 (policy override, key
minted, Play permissions granted) with only the EAS upload left. If the key exists, Step 6 is
just `eas credentials`. If it doesn't, you're doing handoff §Step 2 first. You'll know in
about ten seconds by looking for the JSON. Whichever it is, tick the checklist so the next
person isn't guessing — this lane has now burned real time on exactly one stale checkbox.

**Alex and the Apple Program License Agreement.** Still unaccepted. The handoff says it does
not block TestFlight and does block every App Store submission after it. Worth him doing it
before you need it rather than at the moment you do.

## Order that matters

`verify:ui` → move main → **set 83** → build → **verify the iOS artifact** → submit.
The two bolded ones are where this goes wrong silently.
