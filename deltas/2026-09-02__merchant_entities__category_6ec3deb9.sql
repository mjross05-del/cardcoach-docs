-- 2026-09-02 — merchant_entities.default_category_id: SOCO Cafe (dining -> coffee_fastfood)
-- Lane: merchant-category apply (PROMPT_merchant_category_apply.md), run 99b6d975-e762-42f1-acd3-1e9861fa0213 (chat).
-- Observation c6fe1d31-ce99-49b2-9db6-bc35ad3c95c2 · decided_by mike (in chat, 2026-09-02) · write_audit 20d9a07f · rows_affected 1.
-- Applied 2026-09-02 ~16:50 UTC. This file is the record, not a script to re-run.
update public.merchant_entities
   set default_category_id = 'coffee_fastfood'
 where id = '6ec3deb9-8777-4535-a1d6-68c06049816f'
   and default_category_id is not distinct from 'dining';
