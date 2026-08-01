# DISPATCH — WS-5: Offer freshness ops (registry extension + transition watch)

For: a session extending the existing reverification pipeline (see PIPELINE_AND_DECISIONS.md Part 1). Runs alongside, not instead of, the monthly card pass.

## Prompt (paste below this line into the runtime)

CardCoach's reverification pipeline (Stage 1 registry CSV → Stage 2 fetcher → Stage 3 extraction) currently tracks card sources. DATA-018 introduced loyalty-stack offers whose staleness is now a product-trust risk (a wrong "use this card" costs the user money at the till). Extend the pipeline:

1. **Registry rows (Stage 1).** Add one row per (offer-source × language) to `card_sources_seed_enriched.csv` with a new `source_type: loyalty_offer`, covering: rbcroyalbank.com/petro-canada + faq + Linked Loyalty Terms PDF (EN/FR), petro-canada.ca RBC page, cibc.com Journie offer page + journie.ca terms, pcfinancial.ca card pages + pcoptimum.ca terms, triangle.canadiantire.ca credit-cards + triangle-rewards pages, morerewards.ca, moi.ca, sceneplus.ca partners page (Shell watch). Follow the existing row conventions exactly.
2. **Freshness SLAs.** Persistent gas/grocery linkage offers: re-verify monthly (fetcher cadence). Record the SLA in the offer's `notes` convention: any offer whose `last_verified_at` is older than its SLA must be flagged in the monthly change report even when the page hash is unchanged (silent T&C swaps happen inside PDFs).
3. **AIR MILES → Blue Rewards / Shell → Scene+ transition watch (P0).** `loyalty_programs.blue_rewards` carries the dates: Blue Rewards launched 2026-06-02; Shell earn/redeem ended nationally 2026-05-25 (Alberta 2026-03-02). Each monthly run must check: (a) any surviving AIR MILES references in CardCoach data, (b) Scene+ Shell rollout status — when Shell fuel earn mechanics are published and stable, open a WORKING_NOTES item to stand up the Shell+Scene+ stack (Tier-1 capture first; do not seed from press coverage).
4. **Fuel price parameter review.** Monthly: pull the latest Statistics Canada Table 18-10-0001-01 national self-serve regular average; if it differs from `fuel_price_assumptions` by more than ±5¢/L, produce an expire-then-insert delta (never UPDATE in place; `valid_to` the old row). Note the 2026 federal excise-holiday distortion in `source_note`.
5. **Output**: the standard dated change report, plus a "loyalty offers freshness" section listing every `loyalty_stack` offer with `last_verified_at`, SLA state (fresh/stale), and source-page change status.

Constraints: registry/report/file outputs only — DB deltas go through the normal Stage 3 → apply flow with its snapshot/delta/guard discipline (PROJECT_RULES rule 10 a–f).
