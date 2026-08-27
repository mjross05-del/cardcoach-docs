# PROPOSAL — mcc_category_mappings for the 4 unmapped categories (+1 modeling note)

From the discrepancies-lane decision (Mike, 2026-08-16: backfill via verify
lane). The 8 live-suppressed rows in unmapped categories (Adapta std + world:
e_games, ev_charging, hotels_motels, transit_parking × 2 cards) cannot be
fixed by row backfill alone — the merchant-path assumption needs a category
mapping to intersect against. These proposed sets need the verify lane's
source pass (network MCC class names → numbers) before insert; nothing here
is applied.

| category | proposed MCCs | derivation to verify |
|---|---|---|
| e_games | `{5816}` | digital goods: games (network digital-goods block 5815-5818; the CIBC label "E-Games" reads as digital game purchases, NOT arcades 7994 — confirm against CIBC's own wording) |
| ev_charging | `{5552}` | electric vehicle charging (already the gas set's third member; a standalone mapping lets EV-only rows exist without granting 5541/5542) |
| hotels_motels | `{7011,3501,3509}` | lodging: 7011 hotels/motels/resorts + representative direct-hotel block entries, mirroring how travel's mapping carries 3000/3009 as airline-block representatives — confirm the block convention against the travel mapping's own derivation note before copying it |
| transit_parking | `{4111,4112,4121,4131,4789,7523}` | the existing transit_rideshare set + 7523 parking (7523 is already in that set — confirm whether transit_parking should DROP rideshare 4121 per CIBC's "Transit and Parking" label; taxis/rideshare may not be intended) |

**recurring_bills — do not map.** The two Momentum recurring-bills rows the
14:40 sweep listed no longer appear in the live mcc_defined suppressed set.
Recurring billing is a transaction *behavior* (pre-authorized payments), not
a merchant class — no MCC set expresses it. If those rows resurface as
mcc_defined, the right fix is remodeling to `preauthorized_only` condition
semantics, not a mapping. Flag for the next verify batch to confirm how the
live rows are now modeled.

**Order of operations once approved:** insert mappings (own gated delta) →
then the affected row backfill can ride a p2d delta using the new sets. The
assumption's `category_fallback` branch changes behavior for these
categories the moment a first mapping exists (fallback stops
short-circuiting) — the verify pass should sanity-probe one merchant per
category after insert.
