-- SUPERSEDED 2026-08-26 by the pass-3 file for this issuer set. DO NOT APPLY.
-- Written against 43 rows; 64 are fillable as of 2026-08-26. The by-name-in-chat
-- approval gate this file carries was replaced by standing per-issuer approval
-- (Mike, 2026-08-26). Kept for the audit trail only.

-- earn_rates.mcc_includes backfill, pass 2a — BMO (11 rows)
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
    -- [ ] VERIFY ca_bmo_eclipse_rise_standard_visa / dining
    ('5041a039-144f-4a13-b692-4518baa70efc'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_rise_standard_visa / grocery
    ('e0cec8f1-0216-4ee9-ab22-f28be93955ef'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_privilege_visa / dining
    ('bc47bcea-dd35-416f-a4c6-4359d191830a'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_privilege_visa / drugstore_pharmacy
    ('1c5179a6-07e4-4ba8-8150-6860828f7cec'::uuid, '{5122,5912}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_privilege_visa / gas
    ('6c046501-1395-4574-9d25-061705888c71'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_privilege_visa / grocery
    ('8cf4685b-c967-4c0e-91a8-ed89ba73a80a'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_privilege_visa / travel
    ('3332af4c-48bc-46b8-8e6a-aa8547d6cc78'::uuid, '{3000,3009,4511,7011,7512}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_visa / dining
    ('07bf8fd6-4972-42b3-a400-19a864d04fd8'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_visa / gas
    ('aeabf16a-b513-482e-80d2-47c6dc4f0936'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_visa / grocery
    ('8eeade60-b1ea-4b4c-a934-37b38dba9e6c'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_bmo_eclipse_visa_infinite_visa / transit_rideshare
    ('751c73ad-3232-452a-9444-886f89a62391'::uuid, '{4111,4112,4121,4131,4789,7523}'::integer[])
  ) as v(id, mccs)
  where er.id = v.id
    and er.mcc_includes is null;

  get diagnostics n = row_count;
  if n <> 11 then
    raise exception 'expected 11 rows, got %% — aborting (drift since draft)', n;
  end if;
end $$;

-- Rollback (exact): resets ONLY these rows back to NULL.
-- update earn_rates set mcc_includes = null where id in (
--   '5041a039-144f-4a13-b692-4518baa70efc',
--   'e0cec8f1-0216-4ee9-ab22-f28be93955ef',
--   'bc47bcea-dd35-416f-a4c6-4359d191830a',
--   '1c5179a6-07e4-4ba8-8150-6860828f7cec',
--   '6c046501-1395-4574-9d25-061705888c71',
--   '8cf4685b-c967-4c0e-91a8-ed89ba73a80a',
--   '3332af4c-48bc-46b8-8e6a-aa8547d6cc78',
--   '07bf8fd6-4972-42b3-a400-19a864d04fd8',
--   'aeabf16a-b513-482e-80d2-47c6dc4f0936',
--   '8eeade60-b1ea-4b4c-a934-37b38dba9e6c',
--   '751c73ad-3232-452a-9444-886f89a62391',
-- );
