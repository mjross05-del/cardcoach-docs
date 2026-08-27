# PROMPT — 1.0.3 release execution: push, deploy, build, TestFlight (code runtime)

Authored by the 2026-08-16 Cowork session. SUPERSEDES
`PROMPT_code_push_deploy_2026-08-16.md` (its push/deploy steps are folded in
here — do not run both). You are a Claude Code session on Mike's machine.
Five jobs: clean git artifacts, push, deploy two edge functions (dark), EAS-
build both platforms, submit iOS to TestFlight. Android store submission is
prepared but GATED (Step 6). Then file a report. Nothing else.

## State when this prompt was written (verify, don't trust)

- `~/dev/CardCoachv2` **main = 63a08be** (retheme) on top of 67cab22 (tie) on
  top of 675b7b7. The feature branch is merged (ff) and can be deleted after
  push. Working tree clean except two untracked drops ("Brand kit app
  mockup.zip", design_handoff_cardcoach_rebrand/) — leave them.
- All gates re-verified by the Cowork session on the merged tree tonight:
  verify:ui ✓ (jest 601/601, lint 0 errors, i18n parity), verify:api-016 ✓
  (deno 283/283), engine 143/143, contracts 103/103. Token audit: every
  theme.ts value matches the Final Spec card exactly (incl. textHeading /
  surfaceRaised / segmentActive).
- Remote DB: `tie_disclosure` flag row EXISTS and is **false**
  (migration 20260816185557, applied). Do not touch it.
- Production functions still at recommend-card-v2 v23 / recommend-here-v2
  v22 (old code). The deploy below is dark.

## Step 0 — git artifacts + preconditions

```bash
find ~/dev/CardCoachv2/.git -maxdepth 3 \( -name '*.lock' -o -name '*.stale.*' -o -name 'tmp_obj_*' \) -delete
git -C ~/dev/CardCoachv2 gc --quiet
git -C ~/dev/CardCoachv2 log --oneline -3   # expect: 63a08be, 67cab22, 675b7b7
git -C ~/dev/CardCoachv2 status --porcelain | grep -v '^??'  # expect: empty
cd ~/dev/CardCoachv2/mobile_app_codebase && pnpm verify:ui && pnpm verify:api-016  # both exit 0
```

Any mismatch → STOP and report.

## Step 1 — push

```bash
cd ~/dev/CardCoachv2 && git fetch origin && git push origin main
git push origin --delete feat/api016-app020-tie-disclosure 2>/dev/null; git branch -d feat/api016-app020-tie-disclosure
```

(The branch was never pushed; the delete may no-op. Never force-push; rebase
conflicts → STOP.)

## Step 2 — deploy the two edge functions (dark)

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
supabase functions deploy recommend-card-v2 --project-ref hrzpznlpmxxrbtwskacu
supabase functions deploy recommend-here-v2 --project-ref hrzpznlpmxxrbtwskacu
```

Expect v24 / v23, ACTIVE. Do NOT deploy recommend-cards-stateless-v1
(API-016 D3: it stays byte-identical by not shipping).

Post-deploy parity: POST recommend-cards-stateless-v1 (publishable key) with

```json
{"schemaVersion":"v1","cardProductIds":["ca_scotiabank_passport_visa_infinite_visa","ca_amex_cobalt_amex"],"amountCents":10000,"categoryId":"grocery","channel":"in_store","locale":"en"}
```

— minus requestId/computedAt it must match the pre-deploy baseline (1
recommendation, Passport ranked; the Cowork session holds the byte baseline
and re-checks after you report). Then one authed recommend-card-v2 call from
the signed-in app: NO `tie` field, NO `value_tie` item, same ranking as
before the deploy.

## Step 3 — versions

Confirm `apps/mobile/app.json` (or app.config) marketing version is
**1.0.3** on both platforms (56965af prepped this — verify, don't re-bump).
iOS buildNumber and Android versionCode are remote/auto — never hand-set.

## Step 4 — build both platforms from THIS commit

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
eas build --platform ios --profile production --non-interactive
eas build --platform android --profile production --non-interactive
```

Record both build IDs, fingerprints, and versionCode/buildNumber in
`docs/app-store/RELEASE_1.0.3_HANDOFF.md` (create from the 1.0.2 doc's
shape) and the Android handoff. Expect the iOS fingerprint to match build 56
(JS-only changes); if it differs, find out why before submitting.

## Step 5 — iOS → TestFlight

```bash
eas submit --platform ios --latest
```

(ASC App ID 6757937693, team AF887JD7ZG — credentials as configured for the
1.0.2 uploads.) After processing: add the internal tester group, attach
"what to test": rebrand visual pass (every screen, both modes) + the QA-010
device-pass items + 3-card wallet renders 3 carousel cards. Copy must NOT
promise the tie UI — the flag is off. App Store version creation/submission
stays with Alex per the handoff doc.

## Step 6 — Android → Play internal (GATED — do not improvise past the gate)

If Play Console account + service-account key exist (RELEASE_android
handoff Step 0, Mike): `eas submit --platform android --track internal` and
fill the handoff TBDs. If not: report "Android AAB built and waiting on
Step 0" and stop this step.

## Step 7 — report

Push result, function versions, parity results, both build IDs +
fingerprints, TestFlight status, Android gate state. Post the report back to
Mike and tell him the Cowork session is watching for it to run the
tie-flag-flip preflight (which stays OFF until the 1.0.3 rollout looks
healthy — flip preconditions live in migration 20260816185557's header).
