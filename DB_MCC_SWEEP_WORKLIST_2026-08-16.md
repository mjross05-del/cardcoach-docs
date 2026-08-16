# DB WORKLIST — mcc_defined rows with no MCC list — 2026-08-16

**Lane:** verify/apply loop (rule 9: snapshot, delta file, expire-then-insert, guards). **No DB writes were made by this sweep — reads only.**

## Why this matters

`earnRowPrices` (`_shared/scoring.ts`) admits an `mcc_defined` row only when the category's MCC assumption intersects the row's own `mcc_includes`. A row with a null/empty list fails closed and NEVER prices, at any merchant, for any user — the card silently earns base. Found 2026-08-16 when the CIBC Aeroplan Visa priced $1.33/$100 (base) at Real Canadian Superstore while its catalog grocery row (1 pt/$) sat unpriced: `mcc_includes` null. The `merchant_mcc_assumption` flag (ON since 2026-08-14, v22/v23) made rows WITH lists start pricing; these rows missed the ride.

**Scope: 52 active rows across 12 cards — all `scoring_status='scoreable'`, so every one is live-suppressed today.**

- **42 rows** are immediately fillable: their category has an active `mcc_category_mappings` set; the proposed `mcc_includes` below is exactly that set (category-typical). Each still needs its card's source clause checked in the verify lane before write — a card whose bonus uses a NARROWER MCC set than the category should get the narrow set.
- **10 rows** sit in categories with NO mapping at all (e_games, ev_charging, hotels_motels, recurring_bills, transit_parking): filling the row is not enough — the category needs `mcc_category_mappings` rows first (or an explicit engine policy decision, below).

## Policy alternative (Mike's call, not data-lane)

Instead of (or alongside) the backfill: admit an `mcc_defined` row with an EMPTY list when the assumption's category matches the row's category (fail-open on category agreement). One engine change fixes all 52 at once but trades away MCC precision — the current fail-closed stance was chosen deliberately, so this needs an explicit decision entry if taken.

## Worklist (grouped by card)

### BMO eclipse rise Visa Card (`ca_bmo_eclipse_rise_standard_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `5041a039` | dining | 2.5 pt/$ | 5x Dining (first $5K/yr) | `{5811,5812,5813}` |
| `e0cec8f1` | grocery | 2.5 pt/$ | 5x Grocery (first $5K/yr) | `{5411,5422,5441,5451,5462,5499}` |

### BMO eclipse Visa Infinite Privilege Card (`ca_bmo_eclipse_visa_infinite_privilege_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `bc47bcea` | dining | 5 pt/$ | 5x Dining (first $25K/yr) | `{5811,5812,5813}` |
| `1c5179a6` | drugstore_pharmacy | 5 pt/$ | 5x Drugstore (first $15K/yr) | `{5122,5912}` |
| `6c046501` | gas | 5 pt/$ | 5x Gas (first $15K/yr) | `{5541,5542,5552}` |
| `8cf4685b` | grocery | 5 pt/$ | 5x Grocery (first $20K/yr) | `{5411,5422,5441,5451,5462,5499}` |
| `3332af4c` | travel | 5 pt/$ | 5x Travel (first $25K/yr) | `{3000,3009,4511,7011,7512}` |

### BMO eclipse Visa Infinite Card (`ca_bmo_eclipse_visa_infinite_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `07bf8fd6` | dining | 5 pt/$ | 5x Dining (first $6K/yr) | `{5811,5812,5813}` |
| `aeabf16a` | gas | 5 pt/$ | 5x Gas (first $20K/yr) | `{5541,5542,5552}` |
| `8eeade60` | grocery | 5 pt/$ | 5x Grocery (first $6K/yr) | `{5411,5422,5441,5451,5462,5499}` |
| `751c73ad` | transit_rideshare | 5 pt/$ | 5x Transit (first $20K/yr) | `{4111,4112,4121,4131,4789,7523}` |

### CIBC Adapta Mastercard (`ca_cibc_adapta_standard_mastercard`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `03f957ca` | dining | 1.5 pt/$ | 1.5x Dining (auto top-3) | `{5811,5812,5813}` |
| `fdfdf69b` | drugstore_pharmacy | 1.5 pt/$ | 1.5x Drug Stores (auto top-3) | `{5122,5912}` |
| `2b572e0b` | e_games | 1.5 pt/$ | 1.5x E-Games (auto top-3) | `— (category unmapped)` |
| `30f183ad` | entertainment | 1.5 pt/$ | 1.5x Entertainment (auto top-3) | `{7832,7841,7922}` |
| `5defd809` | ev_charging | 1.5 pt/$ | 1.5x EV (auto top-3) | `— (category unmapped)` |
| `0c8281b9` | gas | 1.5 pt/$ | 1.5x Gas (auto top-3) | `{5541,5542,5552}` |
| `a7d17254` | grocery | 1.5 pt/$ | 1.5x Grocery (auto top-3) | `{5411,5422,5441,5451,5462,5499}` |
| `229b5aef` | home_improvement | 1.5 pt/$ | 1.5x Home Improvement (auto top-3) | `{5200,5211,5231,5251,5261}` |
| `65056e5b` | hotels_motels | 1.5 pt/$ | 1.5x Hotels+Motels (auto top-3) | `— (category unmapped)` |
| `4b2e2fa9` | streaming | 1.5 pt/$ | 1.5x Subscriptions (auto top-3) | `{5815,5816,5817,5818}` |
| `f14a8808` | transit_parking | 1.5 pt/$ | 1.5x Transit+Parking (auto top-3) | `— (category unmapped)` |

### CIBC Adapta World Mastercard (`ca_cibc_adapta_world_mastercard`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `fee370dc` | dining | 1.5 pt/$ | 1.5x Dining (auto top-3) | `{5811,5812,5813}` |
| `73111aa5` | drugstore_pharmacy | 1.5 pt/$ | 1.5x Drug Stores (auto top-3) | `{5122,5912}` |
| `3a39e09e` | e_games | 1.5 pt/$ | 1.5x E-Games (auto top-3) | `— (category unmapped)` |
| `912f6b4f` | entertainment | 1.5 pt/$ | 1.5x Entertainment (auto top-3) | `{7832,7841,7922}` |
| `f9c8e47e` | ev_charging | 1.5 pt/$ | 1.5x EV (auto top-3) | `— (category unmapped)` |
| `34a13436` | gas | 1.5 pt/$ | 1.5x Gas (auto top-3) | `{5541,5542,5552}` |
| `a52159d1` | grocery | 1.5 pt/$ | 1.5x Grocery (auto top-3) | `{5411,5422,5441,5451,5462,5499}` |
| `4883b551` | home_improvement | 1.5 pt/$ | 1.5x Home Improvement (auto top-3) | `{5200,5211,5231,5251,5261}` |
| `18b30d33` | hotels_motels | 1.5 pt/$ | 1.5x Hotels+Motels (auto top-3) | `— (category unmapped)` |
| `af81049a` | streaming | 1.5 pt/$ | 1.5x Subscriptions (auto top-3) | `{5815,5816,5817,5818}` |
| `85947c8f` | transit_parking | 1.5 pt/$ | 1.5x Transit+Parking (auto top-3) | `— (category unmapped)` |

### CIBC Aeroplan Visa (`ca_cibc_aeroplan_standard_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `d447475d` | gas | 0.999983 pt/$ | 1 pt/$ Gas & EV (to $40K/yr account threshold) | `{5541,5542,5552}` |
| `979b8566` | grocery | 0.999983 pt/$ | 1 pt/$ Grocery (to $40K/yr account threshold) | `{5411,5422,5441,5451,5462,5499}` |

### CIBC Aeroplan Visa Infinite Privilege (`ca_cibc_aeroplan_visa_infinite_privilege_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `e778c9e6` | dining | 1.5 pt/$ | 1.5 pts/$ Dining (to $100K/yr account threshold) | `{5811,5812,5813}` |
| `bb670c9a` | gas | 1.5 pt/$ | 1.5 pts/$ Gas & EV (to $100K/yr account threshold) | `{5541,5542,5552}` |
| `7fa782bb` | grocery | 1.5 pt/$ | 1.5 pts/$ Grocery (to $100K/yr account threshold) | `{5411,5422,5441,5451,5462,5499}` |
| `e9de039d` | travel | 1.5 pt/$ | 1.5 pts/$ Travel (to $100K/yr account threshold) | `{3000,3009,4511,7011,7512}` |

### CIBC Aventura Visa (`ca_cibc_aventura_standard_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `e3ab7bd3` | drugstore_pharmacy | 1 pt/$ | 1 pt/$ Drug Stores (to $6K/yr category pool) | `{5122,5912}` |
| `a9b2a627` | gas | 1 pt/$ | 1 pt/$ Gas & EV (to $6K/yr category pool) | `{5541,5542,5552}` |
| `bbee82f2` | grocery | 1 pt/$ | 1 pt/$ Grocery (to $6K/yr category pool) | `{5411,5422,5441,5451,5462,5499}` |

### CIBC Dividend Visa (`ca_cibc_dividend_standard_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `777d0a1a` | dining | 1 c/$ | 1% Dining (dual-cap structure) | `{5811,5812,5813}` |
| `1c8a8baf` | gas | 1 c/$ | 1% Gas & EV (dual-cap structure) | `{5541,5542,5552}` |
| `e0f35d09` | transit_rideshare | 1 c/$ | 1% Transit (dual-cap structure) | `{4111,4112,4121,4131,4789,7523}` |

### Scotiabank American Express Card (`ca_scotiabank_amex_no_fee_amex_credit_amex`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `e376d4c9` | dining | 2 pt/$ | 2 pts/$ Dining (to $50K/yr pooled) | `{5811,5812,5813}` |
| `978a3051` | entertainment | 2 pt/$ | 2 pts/$ Entertainment (to $50K/yr pooled) | `{7832,7841,7922}` |
| `e4636cad` | gas | 2 pt/$ | 2 pts/$ Gas (to $50K/yr pooled) | `{5541,5542,5552}` |
| `9241065d` | grocery | 2 pt/$ | 2 pts/$ Grocery (non-listed grocers) (to $50K/yr pooled) | `{5411,5422,5441,5451,5462,5499}` |
| `c3c68337` | transit_rideshare | 2 pt/$ | 2 pts/$ Transit (to $50K/yr pooled) | `{4111,4112,4121,4131,4789,7523}` |

### Scotiabank Momentum Visa Card (`ca_scotiabank_momentum_standard_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `3d7c8cce` | recurring_bills | 2 c/$ | +1% Recurring Bills (to 2%) (to $25K/yr) | `— (category unmapped)` |

### Scotia Momentum Visa Infinite + Card (`ca_scotiabank_momentum_visa_infinite_visa`)

| earn_rate_id | category | rate | label | proposed mcc_includes |
|---|---|---|---|---|
| `70627918` | recurring_bills | 4 c/$ | +3% Recurring Bills (to 4%) (to $25K/yr) | `— (category unmapped)` |

## Adjacent findings (same sweep)

1. **PC Financial Mastercard (standard), grocery row `merchant_list_only` at 10 pts/$ = its base rate.** The row is a no-op as modeled (9 eligible-merchant entries, zero increment). If the real product pays >10 pts at Loblaw banners, this is a catalog error wearing the same 'row exists but does nothing' shape. Re-verify the product's Loblaw rate.
2. **Android carousel showed 2 cards for a 3-card wallet (2026-08-16 09:04, mike@card.coach at RCSS).** All three cards were scoreable and priceable (Aeroplan $1.33, PC std $1.00, Momentum $1.00 expected). The wallet has since been edited, so not reproducible as-was — if the new 3-card wallet also shows 2 dots, ticket it as a client/API drop.
3. **Recorded for completeness:** the two RCSS merchant rows (places `ChIJMWjUi5sFL4gR…`, `ChIJtzWr_GvwLogR…`) are both `grocery` + entity-linked — merchant graph was NOT at fault in the 2026-08-16 report.
