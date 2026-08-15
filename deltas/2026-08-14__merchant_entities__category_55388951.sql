-- Harvey's default_category_id: NULL -> 'dining' (2026-08-14, applied 2026-08-15T01:2xZ).
--
-- FIRST APPLY through the merchant-category proposal lane
-- (verify.merchant_category_observations -> PROMPT_merchant_category_apply
-- Phase A, run manually in chat with Mike deciding live).
--
-- Provenance: entity 55388951-eb46-4b59-8b3a-a5c5bd3d7379 ('harveys') is a
-- 2026-01-22 hand-seed row (the 50-row 22:13:04.660227 batch,
-- DESIGN_place_resolution_v1 §1.4) that carried NULL category since creation.
-- Mike's live taps 2026-08-15T01:15Z minted its first place row and the
-- resolve-place proposal path recorded fill_null -> dining (observed_count 2,
-- deduped). Decision: Mike in chat, "Approve as dining" — classifier's own
-- proposal; Wendy's/KFC/A&W precedent; and CIBC Dividend's 2% dining row
-- (mcc_includes [5812,5813,5814]) correctly applies at a 5814 fast-food
-- terminal, whereas coffee_fastfood would match no CIBC earn row at all.
-- (Noted for the taxonomy backlog: McDonald's exists as BOTH dining and
-- coffee_fastfood across duplicate entities; guardrail dup checks cover it.)
--
-- Audit: verify.write_audit row (policy gated, fact_check_id NULL by design —
-- the structurally-unlinkable class), observation closed with applied_at +
-- write_audit_id in the same transaction. Guard asserted rows_affected = 1.

update merchant_entities
set default_category_id = 'dining'
where id = '55388951-eb46-4b59-8b3a-a5c5bd3d7379'
  and default_category_id is null;

-- Rollback:
-- update merchant_entities set default_category_id = null
-- where id = '55388951-eb46-4b59-8b3a-a5c5bd3d7379' and default_category_id = 'dining';
