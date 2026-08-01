# REPORT — WS-1 Tier-1 verification results (executed 2026-08-01)

For the "Integrating Dynamic Loyalty Offers into CardCoach calculations" runtime. Per dispatch-file convention: fold into the night report and delete. Applied on branch `feat/loyalty-offers-phase1` commit `89facba`; APP-017 concurrent-runtime work separated into `cbf2739`.

## Outcome: Gate 1 CLOSED

All 7 editorial offers verified against Tier-1 sources by four parallel research agents. **Every offer is now `issuer_confirmed` (0.95–0.97).** No offer had to be expired. Two required real corrections; one exposed a schema gap, now fixed.

| Offer | Verdict | Key finding |
|---|---|---|
| CIBC↔Journie 3¢/L | CONFIRMED 0.95 | +100 L/transaction cap added (T&C cl.8); QC Couche-Tard exclusion claim REMOVED (absent from all current official docs); Simplii + most business cards excluded; 7¢/L threshold is a selectable reward (60-day validity per journie.ca vs 30 per cibc.com — conflict recorded); Parkland now owned by Sunoco; program T&C sunset 2030-12-31 (WS-5 watch) |
| PC MC +10 pts/L | CONFIRMED 0.97 | Decomposition exact (10 member + 10 card/L + 10 pts/$ = "at least 30/L"); loyalty requirement DROPPED — the PC MC doubles as the PC Optimum ID at the pump; <$1/L floor noted |
| PC WE +20 pts/L | CONFIRMED 0.95 | Delta right, no double-count (sums to official 50/L); re-ingestion warning recorded (pcfinancial.ca frames WE component as 30/L which contains the 10); unmodeled: WE volume bonus ≥150 L/month → 70/L |
| Triangle MC 5¢/L | CONFIRMED 0.95 | Card rate REPLACES member rate (never 5+3=8); modeling decision recorded: 5¢/L absolute is correct for credit-vs-credit ranking (3¢/L member rate requires cash/debit tender); WE 7¢/L premium unmodeled; network "Gas+ and Petro-Canada" confirmed |
| RBC↔Triangle 3x CT Money | **CORRECTED 0.95** | Linkage is real and live (1.2% pre-tax) but earns at **Canadian Tire family retail only — never at Petro-Canada or any fuel site** (terms PDF s.34: "you will not earn CT Money... at any other retailer"). Offer rescoped to a new ct-family-retail group (8 new merchant entities). The strategy doc's "at Petro-Canada" claim was wrong. |
| RBC↔More Rewards 2x | CONFIRMED 0.95 | Assumed 1 pt/$ base verified exactly; banners + BC/AB/SK/MB/YT confirmed; 0.15¢/pt always-on floor verified; **More Rewards RBC co-brands excluded from the linkage** |
| RBC↔Moi +0.5 pt/$ | CONFIRMED 0.95 | Evergreen, not a promo; **$60+ basket minimum** at Metro/Food Basics (modeled via min_amount_cents); **Moi CPP Tier-1 captured: 0.8¢/pt** (500 pts = $4) — Moi offers now valuable instead of fail-closed; moi RBC Visa co-brand excluded; official domain is programmemoi.ca |

## Schema addition forced by verification

`offer_scope_excluded_card_products_v3` — negative card scope. Three co-brand cards in the catalog (More Rewards RBC Visa ×2, moi RBC Visa) are ineligible for their bank's linkage; without exclusion the issuer-level scope would double-count on exactly those cards. Wired fail-closed into applicability + tested. RBC Esso Visa noted for the Petro linkage but not in catalog.

## Also in this round

- **Fresh-DB fix for Mike's `db reset` failure:** card-side scope inserts JOIN-guarded in the migration (issuers/reward_programs/card_products data lives in seed.sql, which runs after migrations locally) + completion block at seed.sql tail. Cloud path unaffected.
- **APP-017 landed concurrently** (separate runtime, separate commit `cbf2739`): stack badge, linkage nudges, fuel footnote, Settings link management, contract-adoption tests, EN/FR parity. **Gate 2 is code-complete** — remaining: Mike re-runs the suites locally, then a release build containing it ships BEFORE the flag flips.
- Suites after all changes: edge Deno 168/168; verify:loyalty-p1 green (now checks the exclusion table); migrations re-parsed.

## Remaining before activation

1. Mike: `pnpm supabase:db-reset` (should now complete), `pnpm verify:loyalty-p1`, `pnpm test`, `pnpm test:supabase` — then merge decision.
2. Ship a mobile build containing APP-017 (EAS/App Store lane).
3. Founder flag flip + PROJECT_RULES rule 5 update.
4. Open item for WS-5 cadence: Journie 30-vs-60-day threshold-validity conflict; Parkland/Sunoco ownership watch; Journie T&C 2030 sunset.
