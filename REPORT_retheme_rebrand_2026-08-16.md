# REPORT — RETHEME-001: CardCoach Final Spec rebrand (mobile app)

Executed 2026-08-16 per `PROMPT_retheme_rebrand_2026-08-16.md`, on
`feat/api016-app020-tie-disclosure` (on top of APP-020's tie components; ships
with 1.0.3). Source of truth: the turn-0 token card and the `4a` (light) /
`5a` (dark) final-pass rows in
`design_handoff_cardcoach_rebrand/CardCoach Final Spec.dc.html`.

## 1. Token deltas applied (`apps/mobile/src/theme/theme.ts`)

Verified against the token card directly; the prompt's starting map was
correct on every row it filled and its `verify` cells resolved as follows.

| Role | Light | Dark | What changed |
|---|---|---|---|
| Text heading (**new** `textHeading`) | #2B3A67 | #FDF8F3 | light headings become indigo; ivory becomes heading-only in dark |
| Text body `text` | #4A3F35 (kept) | **#EDE4D6** | dark body warms to parchment (12.8:1 on surface) |
| Text muted `textMuted` + `mutedFill` | #5A6370 (kept) | **#A79D8F** | dark muted warms to stone (6.0:1); fill keeps the dark fill==ink invariant (bark on it 3.83:1) |
| Indigo accent `indigo` | #2B3A67 (kept) | **#9FB0DE** | 7.5:1 on surface; `tintIndigo` tracks it (rgba 159,176,222 @ .14) |
| Tangerine text `primaryText` | #B04619 (kept) | **#F08B63** | splits from the fill in dark (6.6:1) |
| Tangerine fill `primary` | #E8734A | #E8734A | unchanged, both modes (card row confirmed) |
| Money text `successText` | #17795A (kept) | **#4CC79A** | splits from the sage fill in dark (7.6:1); `#3CB58C` never appears in any frame |
| Surface 2 `surfaceRaised` (+`surfaceSecondary` alias) | #F5EDE4 (kept) | **#322A22** | inputs · skeletons · tracks |
| Bottom bars & sheets (**new** `sheet`/`sheetBody`/`sheetBorder`) | #FFFFFF / #FDF8F3 / transparent | #211B15 / #211B15 / ivory 10% | card says #FFFFFF; the 4a add-card frame shows sheet BODIES ivory in light — split into `sheet` (bars, footers, floating modals) and `sheetBody` |
| Active segment (**new** `segmentActive`) | #FFFFFF on `surfaceRaised` | #4A3F35 on `surfaceRaised` | active ink = `textHeading`, inactive = `textMuted` (frames) |
| Hairline `border`/`borderSubtle` | bark 10% / 8% | ivory 10% / 8% | two-tier: page-level vs in-card (was 16%/8% light, 16%/14% dark) |
| Gold ramp `gradients.goldGlow` | #D9B44A → #F5D678 | same | was goldDark→goldLight; `getGoldGlowShadow(mode)` now 45% light / **35% dark** (both values confirmed in frames) |
| Dock `nav` | #2B3A67 | **#2B3A67** | dark bar no longer darkens (was #1C2747) |
| Dock active `navActiveBg`/`navTextActive`(new) | solid #FDF8F3 pill, #2B3A67 ink | same | was translucent ivory 10% chip with ivory ink |
| Dock `navTextMuted` | ivory 75% | ivory 75% | was 55% |
| Dock `navOutline`/`navActiveBorder` | transparent / transparent | ivory 10% / transparent | light dock has no ring in the frames; dark ring drops from 30% to the spec's 10% |

Further token moves out of the adversarial verification pass (§6):
`overlay` → rgba(26,22,17,0.40) light / rgba(0,0,0,0.55) dark (frame scrims);
`tintMuted` dark → ivory 4% (frames never put cool slate on the bark canvas);
new `progressTrack` (slate 22% light / ivory 14% dark — onboarding progress);
new `borderStrong` (bark/ivory 25% — unchecked checkboxes, dashed ghosts);
`indigoDark` deleted from both palettes (zero consumers; it pinned the retired
#1C2747).

Not moved (not on the card, no frame evidence): copper/warning family, danger,
info, `indigoLight/indigoFill/onIndigo`, `onGold`, `onStatusLight`,
light `surfaceSecondary` #EDE4D6 (pressed states), `mutedFill` light,
`gradients.structure` (avatar — matches the frames' #1F2B4D→#2B3A67 exactly),
`focusRing`, decorative tints (except `tintIndigo`/`tintMuted` dark).

## 2. Type system: headings are indigo

`textHeading` was added to the palettes, `BrandColorTokens`, and
`brand.colors`. `T.tsx` now defaults **h1/h2** to it (new `color="heading"` /
`color="body"` opt-ins; title/subtitle stay body-inked by default — most of
those call sites are data figures, merchant names, keypad keys). Changes:

- 15 hardcoded `colors.indigo` heading sites → `textHeading` (auth h1s ×4,
  Welcome h1, wizard h1+h2 ×5, Wallet h2, History h2, AddCardSheet h2,
  NowScreen hero card-name, RootNavigator `headerTitleStyle`).
- Explicit `color="heading"` opt-ins where the title/subtitle variant plays a
  heading role: FullScreenModal title, CardDetailModal card-name,
  TransactionDetailModal merchant name, wizard success title, Wallet + History
  empty-state titles (the 4a Wallet-empty frame shows "No cards yet" in
  indigo). The add-card sheet's issuer group headers stay BODY ink — the
  frames ink them bark/parchment, overriding the heading-role guess.
- Serif Literata leads (Welcome slide 0, Location) moved from `indigo` to
  `textHeading` — same light render, ivory instead of indigo-300 in dark.
- Receipt titles ("Why this card"/"Why these cards") and the total's
  "Value per $100" label are body-bark in light but IVORY in dark per the 5a
  frames — the one role with no single token; they carry a mode-conditional
  `color={dark ? "heading" : "body"}`.
- One opt-out: TransactionDetailModal's h2 multiplier figure (`color="body"`).
- Money figures keep `successText`; indigo ACCENT sites (links, progress
  fills, monograms, cap %) deliberately stay `colors.indigo` — in dark they
  render #9FB0DE per the frames, while headings go ivory.

## 3. Component restyles (frames-confirmed)

- **CustomTabBar (dock)**: solid ivory active pill with indigo icon+label
  (was translucent chip + ivory ink); tangerine active-tab underline deleted
  (no counterpart in the Final Spec dock); bar identical in both modes; light
  outline removed, dark 1px ivory 10%. Layout untouched (pill already
  rendered icon+label).
- **Segmented controls** (HistoryRangeControl, ValuationTierFooter): active
  chip `segmentActive`, active ink `textHeading`; tracks already Surface 2.
- **Inputs → Surface 2**: CardDetailModal ×5, CardSetupWizard ×4,
  FindStoresScreen (was fill-less), NowScreen merchant search. Auth inputs
  already conformed.
- **Sheets**: AddCardSheet / CardDetailModal / TransactionDetailModal bodies →
  `sheetBody` + 1px `sheetBorder`; FullScreenModal → `sheet`; BottomActions +
  KeyboardDoneBar bars → `sheet` (top hairline via `border`). AddCardSheet
  footer stays `surface` — matches both frame modes exactly.
- **Gold chrome**: TOP PICK pill and glow ring → gold→goldLight; glow 35% in
  dark; TieBadge same ramp; pagination best-dot → goldLight fill + gold ring
  (was gold + goldDark). Tie tests assert testIDs/copy only — untouched, green.
- **Card artwork** (frames disagreed with current art, so per step 1 it moved):
  NETWORK_THEMES + cardGradients pool → the card's 3-stop ramps (cobalt
  #3A4C88→#2B3A67 48%→#161F3D, copper #D69A6A→#C4875C 45%→#63432A, bark
  #5C4F42→#4A3F35 48%→#211A13), gradient `locations` wired through
  CardVisual; 1px inner white-10% edge added (`CARD_ART_EDGE`, shared with the
  tie rail); gloss overlay re-tuned to the spec (white 5% → clear 30% → black
  18%); sheen bumped to white 16%. Tie receipt identity swatches now use the
  ramp's middle (brand) stop via `cardIdentityColor()`.
- **Wallet header add button**: filled tangerine circle with ivory plus (was
  a muted outlined ghost) — the frames put Wallet's add affordance in the
  header, not a bottom FAB.
- **GlassSurface**: light glass is translucent WHITE (0.88/0.85 per frames,
  was ivory-based); dark glass renders solid `surface` (frames show no dark
  translucency).
- **KeyboardDoneBar**: hardcoded `#FFFFFF` button ink → `primaryTextOn` (the
  only un-tokenized UI ink in the app).
- **From the verification pass**: Welcome promise-card detail and History's
  "Recent" header move from muted to body ink; the Now merchant pill border
  moves to the page-level 10% hairline tier; onboarding progress tracks get
  the `progressTrack` token; AuthChoice's dark background wash ends on
  `sheet` (~#221C15 in the frame) instead of a full Surface-2 step; add-card
  checkboxes follow the frames exactly (checked = indigo accent, flipping to
  Indigo-300 with a near-black check in dark; unchecked = `borderStrong`);
  the Wallet empty CTA becomes the tangerine primary; the Wallet header add
  button gains its missing shadow; the copper card ramp's 45% brand stop is
  threaded through `getCardGradientLocations` so wallet faces and sheet
  swatches hit the exact stop.

`brandKit.test.ts` was re-pinned to the card values with a comment citing the
prompt; the 2a→Final Spec supersession is recorded in
`PIPELINE_AND_DECISIONS.md`.

## 4. Structural deltas — NOT built (Mike's call)

1. **Skeleton loading states** (Now-detecting frame): cream Surface-2 blocks
   with a 1.6s opacity pulse. No skeleton/shimmer component exists anywhere —
   all loading is `ActivityIndicator` spinners. The "Surface 2 for skeletons"
   token rule currently has zero call sites.
2. **Wallet empty ghost card**: frame shows a dashed 2px bark-22% placeholder
   card with icon chip; the app's empty state is text + CTA only (colors now
   conform, structure doesn't).
3. **Auth-choice background gradient**: frames give it a 135° background
   wash (#FDF8F3→#F5EDE4 light, #1A1611→#221C15 dark); app renders flat.
4. **No shared FAB component**: Now's record-transaction FAB is inline JSX
   and already tangerine; the frames' Now "+" FAB and Wallet header button
   exist as bespoke elements. Extraction into a reusable FAB is refactor work.
5. **Bespoke shadow tints**: the frames use per-family shadow colors (navy
   dock shadow rgba(28,37,66,.38) light, tangerine CTA shadows
   rgba(212,95,56,.35–.45), gold-badge rgba(120,95,25,.25)); the app keeps its
   semantic mode-aware shadow system (warm brown light / black ~45–50% dark —
   the dark side matches the spec's "black shadows 45–50%" note).
6. **Dock geometry**: the frames draw the bar at r32/pad 8 with an r24 h46
   active pill and ICON-ONLY inactive tabs; the app renders r24 bar, r16
   pill, and icon+label on every tab. All dock COLORS now match; the radii
   and the label-vs-icon-only question are layout/a11y calls.
7. **Two-tone "Already have an account? Sign in"**: the frames color the
   action segment indigo at weight 600; the app renders one muted i18n
   string. Splitting needs new EN+FR keys — copy change, not a recolor.
8. **Per-product mini card art**: the add-card sheet frames give each card
   PRODUCT its own 2-stop art (amex-gold, scotia-passport, rbc-avion…); the
   app keys art by ISSUER through the shared trio. Needs a product-art
   catalog to match.

## 5. Accepted deviations (colors, deliberate)

- **Top-pick ring third stop**: frames end the ring on #E8C55E; the prompt
  and token card fix the ramp at gold→goldLight (2-stop) — followed the card.
- **Radial corner sheen**: expo-linear-gradient has no radial; the existing
  angled linear sheen approximates it at the spec's white 16%.
- **Off-card micro-alphas**: the frames use a wider alpha ladder than the
  card documents (6/12/14/18/22/25% hairlines, decorative slate blobs,
  translucent placeholder fills). Where a token exists it was used; the
  card's 10%/8% two-tier rule is the system.
- **⚠ Unchecked checkbox border (WCAG 1.4.11)**: the frames draw it at
  bark/ivory 25%, which composites to ~1.5:1 light / ~2.4:1 dark — under the
  3:1 control-boundary floor the previous opaque-muted border was chosen to
  clear. The spec value now ships (`borderStrong`); if accessibility should
  win over frame fidelity here, revert that one line in
  `WalletIssuerSections.tsx` to `textMuted`. Flagged for Mike's call.

## 6. Verification

- `pnpm verify:ui` **green**: lint, typecheck, i18n parity, jest — 59 suites,
  605 tests (after re-pinning brandKit deliberately; no other test asserts
  colors). `pnpm build:contracts` was needed first (stale dist, pre-existing).
- Adversarial color-role verification, round 1 (six agents: diff-vs-card
  audit + onboarding/Now/Wallet/History frame traces + regression sweep):
  the diff audit found the palettes matching the token card **field by
  field** and zero unsanctioned literals; the traces surfaced **23 defects**,
  of which 16 were legitimate color/token fixes (applied — see §1 and §3),
  4 were structural (added to §4), 2 were stale comments, and 1 was the
  checkbox-a11y tension (§5).
- Round 2 (targeted re-verification of every fix + regression greps):
  **0 defects** — all 14 fix sites verified in both modes, old values purged
  (`#1C2747`/`#33291F`/`#A5AAB6`/`#7C8FC7`/old overlay/`indigoDark` have zero
  live hits), `tintMuted` consumers are decorative only, goldDark survives
  only as a token definition, jest + tsc clean.
- `pnpm verify:ui` re-run green after the fix pass (59 suites / 605 tests).
- Live screenshot compare was NOT run: it needs the app built on a seeded
  local stack (the release lane owns builds; the Cowork session's
  `/tmp/tie_compare` scratch no longer exists). The Maestro journeys +
  seeded-Supabase harness are ready if a pixel pass is wanted before release.
