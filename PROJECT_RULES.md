# CardCoach — Session Rules (2026-07-02)

Read SOURCE_OF_TRUTH.md first. It governs what's real; this file governs how to behave.

1. Canada-only, issuer-verified. Every asserted card fact traces to Tier 1 / Tier 1b sources.
2. SOURCE_OF_TRUTH.md is the index and authority on files. SCHEMA.md is database truth.
   HOW_THE_ENGINE_WORKS.md is engine truth. schema copy.txt is superseded — never cite it.
3. Current card facts come from the audit workbook (…20260313_v23_patchready.xlsx) plus
   verification outputs; dated live-issuer verification supersedes the workbook on conflict.
4. V1 is dead. Production reads only the V2 tables (card_products, earn_rates, card_caps,
   card_exclusions). Never emit or describe V1 paths.
5. Offer stacking and MCC routing are captured in data but NOT active in production.
   Never describe them as live features.
6. Older marketing/handoff docs are strategy and UX intent, not technical truth.
7. Never invent card facts — earn rates, caps, exclusions, fees, point values. Unknowns are
   flagged [VERIFY: issuer-verified data needed], never estimated.
8. Distinguish current build vs. current working data vs. roadmap. Be explicit about uncertainty.
9. Output is files, SQL deltas, prompts, or docs — never direct writes to Supabase or the app.
   Alex's lane (app, DB, App Store) and Mikayla's lane (social/Canva) are off-limits.
10. PIPELINE_AND_DECISIONS.md is append-only. Settled decisions stay settled; shelved items
    stay shelved until Mike reopens them.
