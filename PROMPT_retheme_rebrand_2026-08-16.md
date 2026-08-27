# PROMPT — RETHEME-001: rebrand the mobile app to CardCoach Final Spec (code runtime)

Authored by the 2026-08-16 Cowork session (API-016/APP-020), on Mike's
instruction: "rethemed to match the design exactly." You are a Claude Code
session on `~/dev/CardCoachv2/mobile_app_codebase`, branched from
`feat/api016-app020-tie-disclosure` (contains APP-020's tie components —
retheme ON TOP of them, they ship together as 1.0.3).

**Source of truth:** `~/dev/CardCoachv2/design_handoff_cardcoach_rebrand/CardCoach Final Spec.dc.html`
— the turn-0 token card ("Every color in the mocks is on this card — build
from these tokens, nothing inferred") and the two final pass rows: `4a *`
(light) and `5a * dark` frames: Welcome, Auth choice, Now, Now detecting,
Now tie, Wallet, Wallet add card, Wallet empty, History, Location.

## The token deltas (parsed from turn-0; verify against the card yourself before writing)

Current `apps/mobile/src/theme/theme.ts` already matches the rebrand on:
light background/surface/body-text/muted/indigo/money, dark
background/surface. The rebrand CHANGES at least:

| Role | Light (rebrand) | Dark (rebrand) | Current dark | Delta |
|---|---|---|---|---|
| Text primary (headings) | **#2B3A67 (indigo)** | #FDF8F3 | — | light headings become INDIGO, not bark — check every `T` heading variant and screen title |
| Text body | #4A3F35 | **#EDE4D6** | #FDF8F3 | dark body warms to parchment; ivory stays for headings |
| Text muted | #5A6370 | **#A79D8F** | #A5AAB6 | dark muted warms |
| Indigo accent | #2B3A67 | **#9FB0DE** | #7C8FC7 | dark indigo lightens |
| Money | #17795A | **#4CC79A** | #3CB58C | dark money brightens |
| Tangerine text | #B04619 | **#F08B63** | verify | |
| Tangerine fill (CTA · FAB) | #E8734A | #E8734A (same) | verify | |
| Surface 2 (inputs · skeleton · tracks) | **#F5EDE4** | **#322A22** | verify surfaceRaised | |
| Bottom bars & sheets | #FFFFFF | **#211B15 + 1px ivory 10%** | verify nav | |
| Active segment | #FFFFFF on #F5EDE4 | #4A3F35 on #322A22 | verify | segmented controls (tier picker etc.) |
| Hairline | bark 10% (8% in cards) | ivory 10% (8% in cards) | dark borderSubtle is 14% | two-tier hairline: in-card vs page |
| Gold (top pick · badge · ring) | **#D9B44A → #F5D678** | same, glow 35% | ramp is goldDark→goldLight today | **the pill/ring RAMP changes to gold→goldLight** — update CarouselCardItem TOP PICK, gold glow border, and APP-020's TieBadge together |
| Dock | bar #2B3A67 · pill #FDF8F3 | same + 1px ivory 10% | verify CustomTabBar | active tab = ivory pill on indigo bar |

## Steps

1. Read the token card and BOTH frame rows in full. Build your own
   role→(light,dark) table from the HTML (the one above is a starting map,
   not the authority). Card-art tokens (NETWORK_THEMES gradients, card ink
   #FDF8F3, gold chip) are mode-independent artwork — confirm against the
   frames and leave them unless the frames disagree.
2. Apply to `theme.ts` (lightColors/darkColors/brand/type). Headings-indigo
   is a TYPE-SYSTEM change, not just a palette swap: find where `type`
   variants and screens set heading color (NowScreen card-name already uses
   indigo; h1/h2/title elsewhere use `text`).
3. Sweep for hardcoded deviations: `grep -rn "#[0-9A-Fa-f]\{6\}" apps/mobile/src`
   outside theme.ts/CardVisual assets — anything matching an OLD token value
   gets re-pointed at the theme token.
4. Update `apps/mobile/src/theme/__tests__/brandKit.test.ts` deliberately —
   it pins the "2a locked design" values; re-pin to the rebrand card values
   with a comment citing this prompt. Record the supersession in
   `PIPELINE_AND_DECISIONS.md` (2a → Final Spec rebrand, 2026-08-16).
5. Restyle existing components the frames show changed: CustomTabBar (dock),
   segmented controls (Surface 2 + active segment), inputs/skeletons
   (Surface 2), sheets/bottom bars, TOP PICK + tie badge gold ramp.
6. **Structural deltas that are NOT theming — list, do not build:** the
   frames show an orange FAB (bottom right, "+") that has no existing
   surface, and any layout that differs beyond color. Report these for
   Mike's call; a retheme prompt does not invent features.
7. Verify: `pnpm verify:ui` green (lint/typecheck/i18n/jest — expect
   brandKit + any color-pinned component tests to need deliberate re-pins;
   chase none blindly). Then screenshot-compare: render Welcome, Now,
   Now-tie, Wallet, History light+dark against the frames (the Cowork
   session's `/tmp/tie_compare` harness pattern works: hydrate the frame,
   render yours, side-by-side). Every token mismatch is a defect; every
   structural mismatch goes on the step-6 list.
8. Commit on this branch: `retheme: apply Final Spec rebrand tokens
   (supersedes 2a locked design)`. Do NOT bump versions, do NOT build —
   the release lane (PLAN_release_push_1.0.3_2026-08-16.md) owns that.

## Guardrails

- Colors only move through theme tokens. No component grows a raw hex.
- Card artwork ink and network gradients are mode-independent; do not
  theme-key them.
- Do not touch `_shared/`, the engine, or anything server-side.
- APP-020's tie components restyle through the same tokens — their tests
  assert testIDs and copy, not colors, so they should survive untouched.
- When done, tell Mike to say **"retheme done"** in the Cowork session
  (tie-disclosure thread) — it is watching for that to run the combined
  release push.
