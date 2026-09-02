-- 2026-09-02 — earn_rates.mcc_includes backfill, pass 3 APPLIED (40 of the 76 empty rows)
-- Run f890f135-a0ec-4b20-b985-bdc349cc4227 (chat, review lane). Standing per-issuer approval:
-- Mike, 2026-08-26. One verify.write_audit row per issuer (rows_affected 11 / 19 / 10).
-- This file is the record of what ran, not a script to re-run. Pattern per p1: no snapshot
-- table — every touched row started from an empty mcc_includes (also the UPDATE guard), ids
-- enumerated, per-row rows_affected = 1 asserted, exact rollback at the bottom.
--
-- SUPERSEDES the three 2026-08-26 PENDING_VERIFY files. Their category-typical sets were kept
-- only where the issuer defines the category as the network category (BMO, Scotiabank);
-- where the issuer names merchant classes (CIBC) the sets below are the deterministic
-- name->number reading of the issuer's own text (tier B, 2026-08-14 decision), narrower than
-- the category-typical set. Source-clause checks closed 2026-09-02 against:
--   bmo: BMO benefits guides define each bonus category as purchases 'classified through the Visa network with an MCC that identifies them in the <category> category' (eclipse rise guide, quoted 2026-09-02; eclipse VI/VIP legal footnotes say the same in the row's condition_text). No narrower enumeration, so the category-typical set from mcc_category_mappings is the faithful encoding; travel is the guide's own list (air fare, hotel, car rental).
--   cibc: CIBC defines each category by network class name: 'grocery stores' -> 5411; 'service stations/automated gas dispensers' -> 5541, 5542; 'electric vehicle charging with a merchant category code of MCC 5552' -> 5552; 'drug stores' -> 5912; Dividend 'eating and drinking places and restaurants' -> 5812, 5813 and 'local and suburban commuter transportation ... taxi, limousine and ride sharing' -> 4111, 4121; Aeroplan VIP travel is the guide's enumerated class list. Sources: Aeroplan Visa benefits guide, Aeroplan VIP benefits guide footnote 11, Aventura Visa guide footnote 8, Dividend Visa guide (all fetched 2026-09-02). Deterministic name->number, tier B of the 2026-08-14 decision.
--   scotiabank: Scotiabank American Express legal text 1: purchases 'classified through the American Express network with a Merchant Category Code that identifies them in the American Express network in the grocery, dining, entertainment, gas, streaming service or transit category' (card page, quoted 2026-09-02). Full network category, so the category-typical set from mcc_category_mappings is the faithful encoding.
--
-- WITHHELD (still empty, fail closed): 33 CIBC Adapta rows (auto top-3 — pricing all 11
-- categories would over-credit; belongs with the Tangerine choose-N precedent), CIBC Aeroplan
-- VIP dining e778c9e6 (the guide names no merchant class for dining), Neo United MileagePlus
-- travel 67825deb (airline-MCC-only clause; under the category-level assumption a partial set
-- would price at hotels).
--
-- ENGINE NOTE: assumptionAdmitsMccDefinedRow() tests set-intersection between a row's
-- mcc_includes and the requested category's mapped MCCs, so today a narrower set prices exactly
-- like the category-typical one. The narrow sets are recorded faithfully for the day merchants
-- carry real MCCs.

-- ===== BMO (11 rows) =====
update public.earn_rates set mcc_includes = array[5811,5812,5813]::integer[]
 where id = '5041a039-144f-4a13-b692-4518baa70efc' -- ca_bmo_eclipse_rise_standard_visa / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411,5422,5441,5451,5462,5499]::integer[]
 where id = 'e0cec8f1-0216-4ee9-ab22-f28be93955ef' -- ca_bmo_eclipse_rise_standard_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5811,5812,5813]::integer[]
 where id = 'bc47bcea-dd35-416f-a4c6-4359d191830a' -- ca_bmo_eclipse_visa_infinite_privilege_visa / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5122,5912]::integer[]
 where id = '1c5179a6-07e4-4ba8-8150-6860828f7cec' -- ca_bmo_eclipse_visa_infinite_privilege_visa / drugstore_pharmacy
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = '6c046501-1395-4574-9d25-061705888c71' -- ca_bmo_eclipse_visa_infinite_privilege_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411,5422,5441,5451,5462,5499]::integer[]
 where id = '8cf4685b-c967-4c0e-91a8-ed89ba73a80a' -- ca_bmo_eclipse_visa_infinite_privilege_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4511,7011,7512]::integer[]
 where id = '3332af4c-48bc-46b8-8e6a-aa8547d6cc78' -- ca_bmo_eclipse_visa_infinite_privilege_visa / travel
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5811,5812,5813]::integer[]
 where id = '07bf8fd6-4972-42b3-a400-19a864d04fd8' -- ca_bmo_eclipse_visa_infinite_visa / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'aeabf16a-b513-482e-80d2-47c6dc4f0936' -- ca_bmo_eclipse_visa_infinite_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411,5422,5441,5451,5462,5499]::integer[]
 where id = '8eeade60-b1ea-4b4c-a934-37b38dba9e6c' -- ca_bmo_eclipse_visa_infinite_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4111,4112,4121,4131,4789,7523]::integer[]
 where id = '751c73ad-3232-452a-9444-886f89a62391' -- ca_bmo_eclipse_visa_infinite_visa / transit_rideshare
   and (mcc_includes is null or cardinality(mcc_includes) = 0);

-- ===== CIBC (19 rows) =====
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'd447475d-b69a-47f1-bbc0-7bc646899805' -- ca_cibc_aeroplan_standard_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411]::integer[]
 where id = '979b8566-590c-48a5-9fb1-72887f69dd2c' -- ca_cibc_aeroplan_standard_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'c8eb3bdd-abc3-42b4-93b0-8384f6ce18e2' -- ca_cibc_aeroplan_student_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411]::integer[]
 where id = '1c1cf7c6-f9ce-4ffe-ae46-1bd47f3c769d' -- ca_cibc_aeroplan_student_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'bb670c9a-b808-417c-b5a2-88ff19d36327' -- ca_cibc_aeroplan_visa_infinite_privilege_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411]::integer[]
 where id = '7fa782bb-bb40-419b-9bfb-0c3b4dd42526' -- ca_cibc_aeroplan_visa_infinite_privilege_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4511,7512,4722,7011,4411,4131,4111,4112,4121,4789]::integer[]
 where id = 'e9de039d-8d59-472b-92fa-ec246a57d0fb' -- ca_cibc_aeroplan_visa_infinite_privilege_visa / travel
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5912]::integer[]
 where id = 'e3ab7bd3-6747-4293-ae77-d15cc8746dda' -- ca_cibc_aventura_standard_visa / drugstore_pharmacy
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'a9b2a627-2989-4c29-a2c0-41a78ce2e695' -- ca_cibc_aventura_standard_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411]::integer[]
 where id = 'bbee82f2-81d1-4aed-bdd5-ba839f21937d' -- ca_cibc_aventura_standard_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5912]::integer[]
 where id = '2e3c595d-c180-42c6-892b-c61479a51080' -- ca_cibc_aventura_student_visa / drugstore_pharmacy
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = '7a18f394-9d91-46a9-8b98-a1375d9bd135' -- ca_cibc_aventura_student_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411]::integer[]
 where id = 'a928f30b-9f14-443f-9b3d-db3567fb934b' -- ca_cibc_aventura_student_visa / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5812,5813]::integer[]
 where id = '777d0a1a-45a4-477a-b003-6b92e6b7ea0b' -- ca_cibc_dividend_standard_visa / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = '1c8a8baf-3f76-4e2a-a256-67aea5abe2d9' -- ca_cibc_dividend_standard_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4111,4121]::integer[]
 where id = 'e0f35d09-e5f7-4fe8-99a2-9704de08f29e' -- ca_cibc_dividend_standard_visa / transit_rideshare
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5812,5813]::integer[]
 where id = 'c1b7fc62-fa07-4366-a3f2-b9fcdd5f4468' -- ca_cibc_dividend_student_visa / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'ca914db1-765d-48e5-b7eb-0eecc07c6252' -- ca_cibc_dividend_student_visa / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4111,4121]::integer[]
 where id = '8d388355-9b37-407e-aa25-998892bbd879' -- ca_cibc_dividend_student_visa / transit_rideshare
   and (mcc_includes is null or cardinality(mcc_includes) = 0);

-- ===== SCOTIABANK (10 rows) =====
update public.earn_rates set mcc_includes = array[5811,5812,5813]::integer[]
 where id = 'e376d4c9-457f-4886-9035-90318800ede2' -- ca_scotiabank_amex_no_fee_amex_credit_amex / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[7832,7841,7922]::integer[]
 where id = '978a3051-446b-4c9c-893e-7e625e7ae9c7' -- ca_scotiabank_amex_no_fee_amex_credit_amex / entertainment
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'e4636cad-bbbe-41f2-8478-aa0f80c1bd3c' -- ca_scotiabank_amex_no_fee_amex_credit_amex / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411,5422,5441,5451,5462,5499]::integer[]
 where id = '9241065d-c89a-4e71-b175-597ef9066ae3' -- ca_scotiabank_amex_no_fee_amex_credit_amex / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4111,4112,4121,4131,4789,7523]::integer[]
 where id = 'c3c68337-3d2c-4997-8bd1-e361646acfa0' -- ca_scotiabank_amex_no_fee_amex_credit_amex / transit_rideshare
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5811,5812,5813]::integer[]
 where id = '475f66cf-520a-4c15-9958-07861888e8eb' -- ca_scotiabank_amex_student_amex / dining
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[7832,7841,7922]::integer[]
 where id = '90f8db9d-ec77-462d-8518-a252aaf3415f' -- ca_scotiabank_amex_student_amex / entertainment
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5541,5542,5552]::integer[]
 where id = 'e7982e97-2e9c-434c-805d-42f8535912d7' -- ca_scotiabank_amex_student_amex / gas
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[5411,5422,5441,5451,5462,5499]::integer[]
 where id = '0b30e1ed-8ddd-4d81-ba1d-33aeca479f23' -- ca_scotiabank_amex_student_amex / grocery
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
update public.earn_rates set mcc_includes = array[4111,4112,4121,4131,4789,7523]::integer[]
 where id = 'aa8a69db-29b0-402d-959f-63422df2ffe7' -- ca_scotiabank_amex_student_amex / transit_rideshare
   and (mcc_includes is null or cardinality(mcc_includes) = 0);

-- ===== ROLLBACK (exact) =====
-- update public.earn_rates set mcc_includes = null where id in (
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
--   'd447475d-b69a-47f1-bbc0-7bc646899805',
--   '979b8566-590c-48a5-9fb1-72887f69dd2c',
--   'c8eb3bdd-abc3-42b4-93b0-8384f6ce18e2',
--   '1c1cf7c6-f9ce-4ffe-ae46-1bd47f3c769d',
--   'bb670c9a-b808-417c-b5a2-88ff19d36327',
--   '7fa782bb-bb40-419b-9bfb-0c3b4dd42526',
--   'e9de039d-8d59-472b-92fa-ec246a57d0fb',
--   'e3ab7bd3-6747-4293-ae77-d15cc8746dda',
--   'a9b2a627-2989-4c29-a2c0-41a78ce2e695',
--   'bbee82f2-81d1-4aed-bdd5-ba839f21937d',
--   '2e3c595d-c180-42c6-892b-c61479a51080',
--   '7a18f394-9d91-46a9-8b98-a1375d9bd135',
--   'a928f30b-9f14-443f-9b3d-db3567fb934b',
--   '777d0a1a-45a4-477a-b003-6b92e6b7ea0b',
--   '1c8a8baf-3f76-4e2a-a256-67aea5abe2d9',
--   'e0f35d09-e5f7-4fe8-99a2-9704de08f29e',
--   'c1b7fc62-fa07-4366-a3f2-b9fcdd5f4468',
--   'ca914db1-765d-48e5-b7eb-0eecc07c6252',
--   '8d388355-9b37-407e-aa25-998892bbd879',
--   'e376d4c9-457f-4886-9035-90318800ede2',
--   '978a3051-446b-4c9c-893e-7e625e7ae9c7',
--   'e4636cad-bbbe-41f2-8478-aa0f80c1bd3c',
--   '9241065d-c89a-4e71-b175-597ef9066ae3',
--   'c3c68337-3d2c-4997-8bd1-e361646acfa0',
--   '475f66cf-520a-4c15-9958-07861888e8eb',
--   '90f8db9d-ec77-462d-8518-a252aaf3415f',
--   'e7982e97-2e9c-434c-805d-42f8535912d7',
--   '0b30e1ed-8ddd-4d81-ba1d-33aeca479f23',
--   'aa8a69db-29b0-402d-959f-63422df2ffe7'
-- );
