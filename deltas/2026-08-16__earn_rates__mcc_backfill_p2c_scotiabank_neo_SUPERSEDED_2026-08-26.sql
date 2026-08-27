-- SUPERSEDED 2026-08-26 by the pass-3 file for this issuer set. DO NOT APPLY.
-- Written against 43 rows; 64 are fillable as of 2026-08-26. The by-name-in-chat
-- approval gate this file carries was replaced by standing per-issuer approval
-- (Mike, 2026-08-26). Kept for the audit trail only.

-- earn_rates.mcc_includes backfill, pass 2c — SCOTIABANK + NEO (6 rows)
-- STATUS: PENDING VERIFY — DO NOT APPLY until (1) every row's [ ] source-clause
-- check below is closed by the verify lane (a card whose bonus is NARROWER than
-- the category gets the narrow set, not the category set), and (2) Mike approves
-- this batch by name in chat. Decision basis: Mike, 2026-08-16 Cowork session —
-- "Backfill via verify lane" over engine fail-open (PIPELINE_AND_DECISIONS
-- 2026-08-16). Sets are category-typical from mcc_category_mappings, the same
-- sets the merchant-path assumption already applies to these categories.
--
-- Pattern per p1 (2026-08-14): no snapshot table — every touched row starts
-- from mcc_includes IS NULL (also the UPDATE guard), ids enumerated, exact
-- rollback at bottom, in-transaction row-count assertion aborts on drift.
--
do $$
declare n integer;
begin
  update earn_rates er
  set mcc_includes = v.mccs
  from (values
    -- [ ] VERIFY ca_scotiabank_amex_no_fee_amex_credit_amex / dining
    ('e376d4c9-457f-4886-9035-90318800ede2'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_scotiabank_amex_no_fee_amex_credit_amex / entertainment
    ('978a3051-446b-4c9c-893e-7e625e7ae9c7'::uuid, '{7832,7841,7922}'::integer[]),
    -- [ ] VERIFY ca_scotiabank_amex_no_fee_amex_credit_amex / gas
    ('e4636cad-bbbe-41f2-8478-aa0f80c1bd3c'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_scotiabank_amex_no_fee_amex_credit_amex / grocery — 'all other grocery (excluding listed grocers)': exclusion handled by row structure, MCC set stays category-typical
    ('9241065d-c89a-4e71-b175-597ef9066ae3'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_scotiabank_amex_no_fee_amex_credit_amex / transit_rideshare
    ('c3c68337-3d2c-4997-8bd1-e361646acfa0'::uuid, '{4111,4112,4121,4131,4789,7523}'::integer[]),
    -- [ ] VERIFY ca_neo_financial_united_mileageplus_world_elite_mastercard / travel — SPECIAL: 'airline MCC only, own booking channels'; category-typical travel set would over-credit hotels/car rental. Proposed airline-only {3000,3009,4511}. Channel restriction is NOT MCC-expressible; verify pass must confirm acceptable over-credit or reject this row.
    ('67825deb-714e-47f7-af43-31f7ea8b047a'::uuid, '{3000,3009,4511}'::integer[])
  ) as v(id, mccs)
  where er.id = v.id
    and er.mcc_includes is null;

  get diagnostics n = row_count;
  if n <> 6 then
    raise exception 'expected 6 rows, got %% — aborting (drift since draft)', n;
  end if;
end $$;

-- Rollback (exact): resets ONLY these rows back to NULL.
-- update earn_rates set mcc_includes = null where id in (
--   'e376d4c9-457f-4886-9035-90318800ede2',
--   '978a3051-446b-4c9c-893e-7e625e7ae9c7',
--   'e4636cad-bbbe-41f2-8478-aa0f80c1bd3c',
--   '9241065d-c89a-4e71-b175-597ef9066ae3',
--   'c3c68337-3d2c-4997-8bd1-e361646acfa0',
--   '67825deb-714e-47f7-af43-31f7ea8b047a',
-- );
