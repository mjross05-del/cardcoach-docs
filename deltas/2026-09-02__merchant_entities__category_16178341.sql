-- 2026-09-02 — merchant_entities.default_category_id: Holiday Inn Express Strathroy by IHG (NULL -> travel)
-- Lane: merchant-category apply (PROMPT_merchant_category_apply.md), run 99b6d975-e762-42f1-acd3-1e9861fa0213 (chat).
-- Observation ef30d037-2f53-4c2f-9aff-06a0c7af9b19 · decided_by mike (in chat, 2026-09-02) · write_audit 98c80f7d · rows_affected 1.
-- Applied 2026-09-02 ~16:50 UTC. This file is the record, not a script to re-run.
update public.merchant_entities
   set default_category_id = 'travel'
 where id = '16178341-9ff3-4651-8609-7e7df5ab1938'
   and default_category_id is not distinct from null;
