-- SUPERSEDED 2026-08-26 by the pass-3 file for this issuer set. DO NOT APPLY.
-- Written against 43 rows; 64 are fillable as of 2026-08-26. The by-name-in-chat
-- approval gate this file carries was replaced by standing per-issuer approval
-- (Mike, 2026-08-26). Kept for the audit trail only.

-- earn_rates.mcc_includes backfill, pass 2b — CIBC (26 rows)
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
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / dining
    ('03f957ca-ea10-44d4-a741-3406beabc7b5'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / drugstore_pharmacy
    ('fdfdf69b-fb15-4c33-b27a-5360d06d4622'::uuid, '{5122,5912}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / entertainment
    ('30f183ad-60ad-4725-af27-c6a07935c1da'::uuid, '{7832,7841,7922}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / gas
    ('0c8281b9-646f-48e9-9b57-8577554ed4f2'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / grocery
    ('a7d17254-b9f7-4961-9480-05d354feffd3'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / home_improvement
    ('229b5aef-3c61-4f09-a38a-5dee2270e306'::uuid, '{5200,5211,5231,5251,5261}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_standard_mastercard / streaming
    ('4b2e2fa9-e983-4211-9f0d-1885a401c367'::uuid, '{5815,5816,5817,5818}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / dining
    ('fee370dc-d6ef-44be-b3e8-b800bfd5e0de'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / drugstore_pharmacy
    ('73111aa5-47f7-475e-9d6d-3c80c7555412'::uuid, '{5122,5912}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / entertainment
    ('912f6b4f-ac5d-4bc5-8f4d-08e9eb181b9b'::uuid, '{7832,7841,7922}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / gas
    ('34a13436-89bc-4643-9965-b40b104e9cc6'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / grocery
    ('a52159d1-3cbf-412d-887f-a37db72b9878'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / home_improvement
    ('4883b551-ef07-4679-bd9e-63240e3f5d74'::uuid, '{5200,5211,5231,5251,5261}'::integer[]),
    -- [ ] VERIFY ca_cibc_adapta_world_mastercard / streaming
    ('af81049a-46de-4552-84b9-50c27f87a046'::uuid, '{5815,5816,5817,5818}'::integer[]),
    -- [ ] VERIFY ca_cibc_aeroplan_standard_visa / gas
    ('d447475d-b69a-47f1-bbc0-7bc646899805'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_cibc_aeroplan_standard_visa / grocery
    ('979b8566-590c-48a5-9fb1-72887f69dd2c'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_cibc_aeroplan_visa_infinite_privilege_visa / dining
    ('e778c9e6-394e-47b7-9966-1c4d5f35a608'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_cibc_aeroplan_visa_infinite_privilege_visa / gas
    ('bb670c9a-b808-417c-b5a2-88ff19d36327'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_cibc_aeroplan_visa_infinite_privilege_visa / grocery
    ('7fa782bb-bb40-419b-9bfb-0c3b4dd42526'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_cibc_aeroplan_visa_infinite_privilege_visa / travel
    ('e9de039d-8d59-472b-92fa-ec246a57d0fb'::uuid, '{3000,3009,4511,7011,7512}'::integer[]),
    -- [ ] VERIFY ca_cibc_aventura_standard_visa / drugstore_pharmacy
    ('e3ab7bd3-6747-4293-ae77-d15cc8746dda'::uuid, '{5122,5912}'::integer[]),
    -- [ ] VERIFY ca_cibc_aventura_standard_visa / gas
    ('a9b2a627-2989-4c29-a2c0-41a78ce2e695'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_cibc_aventura_standard_visa / grocery
    ('bbee82f2-81d1-4aed-bdd5-ba839f21937d'::uuid, '{5411,5422,5441,5451,5462,5499}'::integer[]),
    -- [ ] VERIFY ca_cibc_dividend_standard_visa / dining
    ('777d0a1a-45a4-477a-b003-6b92e6b7ea0b'::uuid, '{5811,5812,5813}'::integer[]),
    -- [ ] VERIFY ca_cibc_dividend_standard_visa / gas
    ('1c8a8baf-3f76-4e2a-a256-67aea5abe2d9'::uuid, '{5541,5542,5552}'::integer[]),
    -- [ ] VERIFY ca_cibc_dividend_standard_visa / transit_rideshare
    ('e0f35d09-e5f7-4fe8-99a2-9704de08f29e'::uuid, '{4111,4112,4121,4131,4789,7523}'::integer[])
  ) as v(id, mccs)
  where er.id = v.id
    and er.mcc_includes is null;

  get diagnostics n = row_count;
  if n <> 26 then
    raise exception 'expected 26 rows, got %% — aborting (drift since draft)', n;
  end if;
end $$;

-- Rollback (exact): resets ONLY these rows back to NULL.
-- update earn_rates set mcc_includes = null where id in (
--   '03f957ca-ea10-44d4-a741-3406beabc7b5',
--   'fdfdf69b-fb15-4c33-b27a-5360d06d4622',
--   '30f183ad-60ad-4725-af27-c6a07935c1da',
--   '0c8281b9-646f-48e9-9b57-8577554ed4f2',
--   'a7d17254-b9f7-4961-9480-05d354feffd3',
--   '229b5aef-3c61-4f09-a38a-5dee2270e306',
--   '4b2e2fa9-e983-4211-9f0d-1885a401c367',
--   'fee370dc-d6ef-44be-b3e8-b800bfd5e0de',
--   '73111aa5-47f7-475e-9d6d-3c80c7555412',
--   '912f6b4f-ac5d-4bc5-8f4d-08e9eb181b9b',
--   '34a13436-89bc-4643-9965-b40b104e9cc6',
--   'a52159d1-3cbf-412d-887f-a37db72b9878',
--   '4883b551-ef07-4679-bd9e-63240e3f5d74',
--   'af81049a-46de-4552-84b9-50c27f87a046',
--   'd447475d-b69a-47f1-bbc0-7bc646899805',
--   '979b8566-590c-48a5-9fb1-72887f69dd2c',
--   'e778c9e6-394e-47b7-9966-1c4d5f35a608',
--   'bb670c9a-b808-417c-b5a2-88ff19d36327',
--   '7fa782bb-bb40-419b-9bfb-0c3b4dd42526',
--   'e9de039d-8d59-472b-92fa-ec246a57d0fb',
--   'e3ab7bd3-6747-4293-ae77-d15cc8746dda',
--   'a9b2a627-2989-4c29-a2c0-41a78ce2e695',
--   'bbee82f2-81d1-4aed-bdd5-ba839f21937d',
--   '777d0a1a-45a4-477a-b003-6b92e6b7ea0b',
--   '1c8a8baf-3f76-4e2a-a256-67aea5abe2d9',
--   'e0f35d09-e5f7-4fe8-99a2-9704de08f29e',
-- );
