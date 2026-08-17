# REPORT — 1.0.3 release execution (2026-08-16, code runtime)

Closes `PROMPT_release_1.0.3_execute_2026-08-16.md` Step 7. Written after the
fact, because live TestFlight QA (Mike, same evening) overtook the report —
the post-release section below is part of the record.

## Release execution (Steps 0–5)

- **Gates on `63a08be` (build commit):** `verify:ui` exit 0, `verify:api-016`
  exit 0 (deno 283/283). Jest is **605/605**, not the prompt's 601 — the
  prompt's count was stale, lint 0 errors and i18n parity as stated.
- **Push:** `c0e8f4d..63a08be → origin/main` (fast-forward, no force).
  `feat/api016-app020-tie-disclosure` deleted locally; remote delete no-op as
  predicted.
- **Edge functions (dark deploy):** `recommend-card-v2` **v23→v24**,
  `recommend-here-v2` **v22→v23**, both ACTIVE.
  `recommend-cards-stateless-v1` **not deployed**, stays v8 (API-016 D3).
- **Parity (pre-flip):** stateless-v1 response byte-identical to the
  pre-deploy baseline minus `requestId`/`computedAt` (2398 normalized bytes
  both sides; Passport rank 1, Cobalt `unknown_id_removed`). Authed
  `recommend-card-v2` on v24: HTTP 200, no `tie`, no `value_tie`, no
  tie-ordering keys. (The Cowork session's independent byte-baseline re-check
  is still meaningful for stateless — that function never reads the flag.)
- **Builds (both from `63a08be`):**
  | | iOS | Android |
  | --- | --- | --- |
  | Build | **1.0.3 (57)** | **1.0.3 (versionCode 5)** |
  | EAS ID | `19267cdc-0d82-4ef8-849a-6244981e8df6` | `f52ca840-a0ca-474d-b73c-3677412ad5c0` |
  | Fingerprint | `a8eeb074c7623fbc5d00a857d33383c9bbe1b277` | `8c317a3f6400e616d95cd941b96b68481083f895` |
- **iOS fingerprint vs build 56 (`31cd21dd…`): differs, and had to.** The
  prompt's "expect a match, JS-only changes" premise was wrong — 1.0.3 adds
  **expo-updates** (absent at `b621fbf`, present at `63a08be`) plus
  `runtimeVersion`/`updates` config, a native-layer change. The runbook
  already said so. Not a blocker; verified against the tree before submitting.
- **TestFlight:** `eas submit -p ios --latest` green (submission
  `dd07c8bb-c6b4-4f34-8aa0-f942eb1a4061`); accepted by Apple, processed, and
  installed by Mike the same evening. **Internal tester group NOT yet added
  and "what to test" NOT yet pasted** — EAS holds the ASC API key server-side
  (no local AuthKey), so those are App-Store-Connect-UI steps; the exact copy
  is in `mobile_app_codebase/docs/app-store/RELEASE_1.0.3_HANDOFF.md`.
- **Extra artifact:** iOS **simulator** build of the same commit parked for
  any Xcode-equipped machine: EAS `932c64a4-f128-4f97-b622-88291cd6b077`
  (this Mac has no Xcode, so it could not be run locally).

## Step 6 — Android: built, GATED, corrected gate

AAB built and waiting. The prompt's gate ("Play Console account +
service-account key") is half-stale: **the account exists** (org account,
`mike@card.coach`, verified — WORKING_NOTES #24a, resolved 2026-08-07). The
actual blocker is only the **service-account JSON key** (Android handoff
Step 2): no `~/secrets/...json`, no `serviceAccountKeyPath` in `eas.json`.
`RELEASE_android_1.x_HANDOFF.md`'s header now carries this correction.
#24b (Google OAuth provider config) also remains open before any Android
tester touches a build.

## Post-release events (same evening — part of this record)

1. **False alarm: "retheme not applied."** Mike's first TestFlight launch
   showed the old design. Investigated to the bundle level: build 57's
   `main.jsbundle` contains only Final Spec hexes, wiring verified
   end-to-end, zero OTA updates published. Cause: **stale TestFlight
   install**; a delete + clean reinstall showed the retheme. Recorded here
   because it will recur: TestFlight's build row can read "57" while the
   installed binary is older.
2. **Design conformance audited.** Build 57 matches the Design-project canvas
   (`CardCoach Final Spec.dc.html`): tokens, dock (ivory active pill), FAB,
   Literata-on-onboarding-heroes, verbatim frame copy ("TOP PICK", "WRONG?",
   "VALUE PER $100", history ranges…). The handoff folder's `ios-frame.jsx` /
   `support.js` are the design tool's scaffolding, not components to port;
   the uploads/ lockups are byte-identical to the app's existing brand
   assets.
3. **`tie_disclosure` flipped ON at 21:49:43 UTC by Mike** (in-session
   decision, for build-57 tie QA on his engineered 2-way ties).
   **This supersedes the Cowork session's planned tie-flag-flip preflight** —
   do not run the flip; it is done. Delta with preconditions ledger:
   `deltas/2026-08-16__runtime_flags__tie_disclosure_on.sql` (this repo,
   `28944ff`). Flag-on authed probe: HTTP 200, healthy shape. Rollback stays
   the documented flip-back-off.
4. **TestFlight feedback fixes (CardCoachv2 `7a6fe93` + follow-up):**
   - Stacking callout: mono ALL-CAPS → Poppins sentence case; breakdown now
     renders served per-line dollar values closing with the served
     `summary.finalValueCents` as a **Total** row (base + bonus ± cap
     adjustment visibly adds up; no client arithmetic anywhere).
   - Log-purchase modal: uncapped Dynamic Type could push the submit CTA off
     screen; hero amount capped at 1.2× + shrink-to-fit, keypad/merchant
     title at 1.3×; `T` now honors caller-supplied `maxFontSizeMultiplier`
     (previously silently discarded).
   - Delivery to build 57 planned as **one EAS Update** on the `production`
     channel (reaches only fingerprint-matched binaries = internal TestFlight
     installs; no App Store users exist on 1.0.3) — awaiting Mike's go.

## Open items

- Mike: on-device tie QA result (flag is live); log-purchase screenshot to
  confirm the overflow diagnosis; go/no-go on the OTA.
- ASC UI: tester group + what-to-test (copy in the 1.0.3 handoff).
- Android: service-account key (Step 2) → `eas submit -p android`; #24b.
- Screenshots for the App Store listing still show the pre-rebrand design.
