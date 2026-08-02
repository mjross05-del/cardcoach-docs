# WS-5: Offer freshness ops — EXECUTED via daily scheduled batches (2026-08-01)

Status: DONE — superseded and implemented same day. The original version of this dispatch assumed the monthly Stage-2 fetcher was the reverification vehicle; Mike corrected this — reverification runs as **daily batched scheduled tasks** (per-issuer weekday rotation + Friday chrome lane). The loyalty-offer freshness work was folded directly into those task prompts instead. This file records what changed and where.

## What was wired in (additive sections in the scheduled task prompts)

All additions respect the batches' standing invariants: OFFERS_PROMOTION OFF (batches NEVER write `public.offers` or any loyalty table), evidence + grep-guard discipline, results land as `verify.parking` rows (kind `loyalty_stack_reverify` / `loyalty_stack_watch` / `fuel_price_drift`) + issuer_notes for Mike's review pass. All sections no-op gracefully until the feature branch merges (offer_class column absent → skip + note). `runtime_flags.loyalty_offer_stacking` is read-only everywhere — founder decision.

| Task | Addition |
|---|---|
| `verify-batch-wed-rbc` (Wed) | Reverify b0ff0001/2/3 (RBC↔Petro-Points: 3¢/L anchors incl. retail-only, excluded cards, one-additional-card rule), b0ff0008 (RBC↔Triangle: 1.2% pre-tax, CT-retail-only — fuel appearing in scope = mechanic change), b0ff0009 (More Rewards +1 pt/$), b0ff0010 (Moi +1 pt/$2, $60 min). Plus FIRST-WEDNESDAY monthly fuel-price check vs StatsCan 18-10-0001-01 (drift >±5¢/L → expire-then-insert proposal). |
| `verify-batch-fri-cibc` (Fri) | Reverify b0ff0004 (Journie 3¢/L, max 100 L, dual-presentation requirement, card exclusions); standing recheck of the 60-vs-30-day threshold-validity conflict (journie.ca vs cibc.com); Sunoco-ownership + 2030-12-31 T&C sunset watch. |
| `verify-batch-sun-ct-pcf-simplii-tangerine` (Sun) | Reverify b0ff0005/6 (PC litre-bonus deltas +10/+20 with the 30-contains-10 re-ingestion warning; floors; premium/app/volume-bonus watch items) and b0ff0007 (Triangle 5¢/L absolute, card-rate-replaces-member-rate anchor). Notes that the previously-parked CT per-litre facts now have canonical offer records to reverify against. |
| `verify-batch-mon-scotiabank` (Mon) | Scene+/Shell fuel-partner watch: check sceneplus.ca for published Shell fuel-earn mechanics; Tier-1 mechanics appearing → parking + flag so Mike can commission the Shell+Scene+ stack. |
| `verify-chrome-lane-weekly` (Fri pm) | BMO Blue Rewards / AIR MILES transition watch (~3 min cap): surviving AIR MILES/Shell claims on bmo.com → parking with screenshot evidence; capture Blue Rewards accelerator mechanics as gated proposals. No Blue Rewards stack seeded until the program stabilizes. |

## Freshness SLA

Persistent stack offers: staleness flag in RUN SYNC when `last_verified_at` > 35 days (daily rotation gives each issuer a weekly touch, so the effective cadence is weekly with a 5-week alarm). Fuel price: monthly, first Wednesday. `last_verified_at` refreshes are applied by Mike from parking rows — never auto-written by batches.

## Not covered here (unchanged)

Tue Amex and Sat Rogers/MBNA/Desjardins/NB batches carry no loyalty-stack offers today — no additions. If Phase-2/3 adds Amex Offers or other issuer stacks, extend those prompts the same way.
