-- Flip merchant_mcc_assumption ON (2026-08-14).
--
-- Activates the category-typical MCC assumption on the authed merchant path
-- (recommend-card-v2 v23, recommend-here-v2 v22, commit 42d4dc0). Approved by
-- Mike in chat 2026-08-14: "yes, wire the category_fallback assumption on the
-- merchant path" (implemented as the ordered test - mapping intersection
-- primary, category_fallback only for unmapped categories).
--
-- Expected effect (recon of 2026-08-14): 88 of 145 live mcc_defined rows
-- begin pricing (65 mcc_mapping, 23 category_fallback); 57 stay suppressed on
-- NULL/non-intersecting mcc_includes pending the card-fact backfill.
-- Rollback: set enabled=false - both endpoints revert to pre-change
-- behaviour on the next request, no deploy.

update public.runtime_flags
set enabled = true,
    note = coalesce(note, '') || ' FLIPPED ON 2026-08-14 (delta; Mike approval in chat).'
where key = 'merchant_mcc_assumption'
  and enabled = false;
