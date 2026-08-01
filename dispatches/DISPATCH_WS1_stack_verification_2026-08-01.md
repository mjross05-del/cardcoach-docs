# DISPATCH — WS-1: Tier-1 verification of Phase-1 loyalty stack offers

For: a research-capable Claude runtime with web access. Est. 2–3 hours. Blocks activation of `loyalty_offer_stacking`.

## Prompt (paste below this line into the runtime)

You are verifying loyalty-program stacking facts for CardCoach (Canada-only, issuer-verified; PROJECT_RULES rules 1/7: never assert an unverified card fact; unknowns are flagged `[VERIFY]`, never estimated). Today's job: take the 7 `editorial` offers seeded by migration `20260801150500_data_018_loyalty_stacking_seed.sql` in `CardCoachv2/mobile_app_codebase/supabase/migrations/` and verify each against **Tier 1 sources only** (official issuer/program pages and T&C PDFs; secondary sources may locate a page but never verify a fact).

For each offer below, confirm or correct: the mechanic (what triggers it), the value and unit, merchant scope (exact banner list), card scope (which cards/issuers), loyalty requirement (membership presented vs one-time bank link), caps/thresholds/exclusions, and any Quebec carve-outs. Capture for every fact: source URL, access date, and a verbatim quote or clause reference.

1. `b0ff0004` CIBC↔Journie 3¢/L — cibc.com + journie.ca. Also: is the 300-pt→7¢/L threshold (max 100 L, 60 days) current? Are QC Ultramar/Couche-Tard sites excluded?
2. `b0ff0005` PC Mastercard +10 PC Optimum pts/L at Esso/Mobil — pcfinancial.ca + pcoptimum.ca. Decompose the "at least 30 pts/L" claim precisely: member base vs card litre-bonus vs per-$ earn. The seed's decomposition is flagged as overcount-risk.
3. `b0ff0006` PC World Elite +20 pts/L delta — same sources; confirm the WE-vs-standard litre delta and whether it stacks with (2) or replaces it. Premium-grade bonus too.
4. `b0ff0007` Triangle Mastercard 5¢/L CT Money at Gas+ AND Petro-Canada — triangle.canadiantire.ca. Confirm both merchant networks, standard vs World Elite rates, premium-grade 7¢/L condition.
5. `b0ff0008` RBC↔Triangle "3x CT Money at Petro-Canada" (confidence 0.40 — weakest seed) — confirm the linkage exists, its actual multiplier/base, and whether it co-applies with the RBC↔Petro-Points stack on one transaction.
6. `b0ff0009` More Rewards×RBC 2x points at Pattison banners — morerewards.ca + rbcroyalbank.com. Confirm the base member pts/$ (seed ASSUMES 1/$ — unverified), the doubling mechanic, banner list, and the 10,000 pts = $15 floor.
7. `b0ff0010` Metro Moi×RBC bonus (1 Moi pt per $2) — moi.ca + rbcroyalbank.com. Is this promo still live? End date? And capture a Tier-1 Moi redemption value if one is published (loyalty_programs.moi.cents_per_point is deliberately NULL until you do).

Also re-verify (dated, quick): `b0ff0001/2/3` RBC↔Petro-Canada (last verified 2026-08-01) — only if any source page changed since.

Cross-checks while you are in the sources:
- **RBC Avion double-count guard:** migration 0035 historically labeled RBC Avion gas earn rows "Petro-Canada fuel (linked Petro-Points)". Confirm current `earn_rates` for `ca_rbc_avion_visa_infinite_visa` / `_privilege_visa` do NOT bake the +20% linkage bonus into a card earn row — the bonus must live only in offer `b0ff0003`.
- **Shell → Scene+**: if Scene+ has published Tier-1 mechanics for Shell fuel earn, capture them (do NOT seed — report only).

Output: one Markdown report per offer with CONFIRMED / CORRECTED / CANNOT-VERIFY per field, plus a single SQL delta file (expire-then-insert style where a fact changed; `UPDATE offers SET verification_status='issuer_confirmed', confidence=…, source_url=…, last_verified_at=… WHERE id=…` where confirmed). Any offer left below `issuer_confirmed` must be listed in a final "blocks activation" section. Do not write to any database — file output only.
