# WS-7 — Loyalty Stacking Compliance Pack (Phase 1)

Last updated: 2026-08-01 · Owner: Mike · Status: **DRAFT FOR COUNSEL REVIEW — not legal advice.** Prepared by the loyalty-offers initiative session as drafting support; a lawyer must sign off before activation, especially for Quebec. Scope: the DATA-018/API-013/APP-017 surfaces only.

## 1. Review of the shipped APP-017 strings (en.json / fr.json, 29 keys)

Verdict: the shipped copy already follows the core rules — conditional phrasing ("could earn", "possible", "estimates, never guaranteed"), no partnership implication ("some banks let you link…", "check the program's terms"), fuel values disclosed as estimates with "verify at the pump," and full EN/FR parity (`pnpm verify:i18n-parity` green). Specific findings:

| Key | Finding | Action |
|---|---|---|
| `linkage.disclaimer` | Good: "estimates, never guaranteed… terms are set by the program operator." | Keep. Counsel: confirm sufficiency as the sole gate-level disclaimer. |
| `linkage.explainer.journie` | (a) FR renders the mark as "Journie Récompenses" — [VERIFY the program's own French branding on journie.ca/qc-fr and use exactly that form; do not invent a translation of a trademark]. (b) Banner list says "Fas Gas Plus"; the governing program documents say "Fas Gas", and the program list now includes On the Run. | Fix (b) to mirror the program's own wording; verify (a) before QC activation. |
| `linkage.explainer.triangle_rewards` | FR "Récompenses Triangle" matches Canadian Tire's own French branding. | Keep. |
| `linkage.explainer.moi` | Does not mention basket minimums. Acceptable: the $60 minimum is enforced in scoring (min_amount_cents), so the nudge cannot appear on sub-minimum purchases (QA009-19 pins this). | Keep; note for counsel. |
| `linkage.potentialValue` | "{{amount}} more possible on this purchase" — conditional, good. | Keep. |
| `receipt.fuelAssumption` | Price + litres disclosed, "verify at the pump." | Keep. |

**Gap found: no in-app trademark attribution notice shipped.** Recommend adding a static "About loyalty programs" screen (Settings, near the link-management section) carrying §2 below. Small APP-017 follow-up.

## 2. Trademark attribution (nominative use)

Draft in-app notice — EN:

> CardCoach is an independent product. Petro-Points™ and Petro-Canada™ (Suncor Energy Inc.), Journie™ Rewards (Parkland Corporation), PC Optimum™ and PC Financial® (Loblaw Companies Limited / President's Choice Bank), Triangle™ Rewards, CT Money® and Canadian Tire® (Canadian Tire Corporation), Scene+™ (Scene LP), More Rewards® (Pattison Food Group), Moi™ (Metro Inc.), AIR MILES® (AM Royalties LP), Aeroplan® (Air Canada), and all bank and card marks (RBC®, CIBC®, Scotiabank®, BMO®, American Express®, Visa®, Mastercard®, and others) are trademarks of their respective owners. CardCoach is not affiliated with, endorsed by, or sponsored by any of these companies. Program details are set by the program operators and can change without notice — always confirm with the program.

FR (parity draft — counsel/translator to polish):

> CardCoach est un produit indépendant. Petro-Points™ et Petro-Canada™ (Suncor Énergie Inc.), Journie™ (Parkland Corporation), PC Optimum™ et PC Finance® (Les Compagnies Loblaw limitée / Banque le Choix du Président), Récompenses Triangle™, Argent CT® et Canadian Tire® (La Société Canadian Tire), Scène+™ (Scene LP), More Rewards® (Pattison Food Group), Moi™ (Metro Inc.), AIR MILES® (AM Royalties LP), Aéroplan® (Air Canada) ainsi que toutes les marques bancaires et de cartes (RBC®, CIBC®, Banque Scotia®, BMO®, American Express®, Visa®, Mastercard®, et autres) sont des marques de commerce de leurs propriétaires respectifs. CardCoach n'est affilié à aucune de ces entreprises et n'est ni endossé ni commandité par elles. Les modalités des programmes sont fixées par leurs exploitants et peuvent changer sans préavis — confirmez toujours auprès du programme.

Usage rules (already followed in the shipped strings; keep enforcing): marks used descriptively only, never in CardCoach's own branding/logo/app-store assets; no "partner"/"official" language; no program logos without a license; ™/® on first in-screen mention is good practice but not a legal cure — the disclaimer is.

## 3. Quebec pre-activation checklist

1. **Charter of the French Language (Bill 96):** all new consumer-facing strings available in French of equal quality and prominence — SHIPPED (29/29 keys, parity-verified). Marks may remain in their recognized form; verify each program's own French branding (Journie flagged above). App-store listing updates that mention the feature need FR versions too.
2. **Law 25 (privacy):** `user_loyalty_links` stores self-declared program membership/linkage — personal information. Confirm the privacy policy's collection list includes it, with purpose ("to tailor card recommendations you request") and deletion path (delete-account edge function already cascades user rows — verify it covers the new table). No data is pulled from banks or programs; self-declared only — say so in the policy.
3. **Consumer protection (CPA):** savings claims are conditional and per-purchase estimates, never guaranteed ("could earn", "possible", "estimates"); fuel values carry the assumed price and "verify at the pump." Counsel to confirm no representation amounts to a warranty; keep the QC carve-out honesty (Journie 30-vs-60-day threshold conflict is recorded in data, not surfaced as a claim).
4. **Program carve-outs in QC:** none currently asserted (the earlier Journie/Couche-Tard exclusion was removed as unverifiable on WS-1). If any QC-specific exclusion is Tier-1 verified later, geo-scope the offer rather than caveating copy.

## 4. Disclaimers inventory (where each lives)

| Surface | Copy | Status |
|---|---|---|
| Linkage nudge | `linkage.disclaimer` (estimates, operator's terms) | Shipped |
| Fuel valuation | `receipt.fuelAssumption` (price, litres, verify at pump) | Shipped |
| Unknown value | `linkage.valueUnknown` ("Possible — check with the program") | Shipped |
| Attribution notice | §2 above | **To add (APP-017 follow-up)** |
| App Store / marketing | Mirror §2's independence sentence wherever stacks are marketed | To do at launch marketing |

## 5. Counsel flags (decide before flag flip)

1. Sufficiency of `linkage.disclaimer` as the master disclaimer vs. a first-run interstitial.
2. §2 attribution list completeness + the exact French trademark forms.
3. Law 25: whether self-declared loyalty membership triggers any PIA obligation at CardCoach's size.
4. Whether "issuer-verified" as a marketing phrase needs qualification when editorial-confidence offers ever ship (today all shipped offers are issuer_confirmed 0.95+, so the phrase is currently accurate).
