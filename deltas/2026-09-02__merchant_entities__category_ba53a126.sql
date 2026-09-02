-- 2026-09-02 — merchant_entities.default_category_id: Pioneer (NULL -> gas)
-- Lane: merchant-category apply (PROMPT_merchant_category_apply.md), run 99b6d975-e762-42f1-acd3-1e9861fa0213 (chat).
-- Observation 7a7cca24-2994-4469-8504-ca5ff2f6651c · decided_by mike (in chat, 2026-09-02) · write_audit cff35621 · rows_affected 1.
-- Applied 2026-09-02 ~16:50 UTC. This file is the record, not a script to re-run.
update public.merchant_entities
   set default_category_id = 'gas'
 where id = 'ba53a126-8490-444a-bb66-8d495fa0aa54'
   and default_category_id is not distinct from null;
