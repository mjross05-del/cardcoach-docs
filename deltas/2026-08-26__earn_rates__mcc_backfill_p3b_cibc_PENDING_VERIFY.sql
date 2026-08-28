-- =========================================================================
-- SAFETY NOTE ADDED 2026-08-27 — THIS FILE IS ALL-OR-NOTHING, NOT PER-ROW.
-- The header promises per-row gating: "apply per row as its source-clause
-- check closes", "A row ships when its [ ] source-clause check below is
-- closed by the verify lane", "An unchecked row does not ship."
-- THE FILE DOES NOT IMPLEMENT THAT. It is a single BEGIN ... COMMIT
-- containing every UPDATE, followed by a DO block that raises unless ZERO
-- mapped-category rows remain empty for the whole issuer. Running it ships
-- EVERY row in it, including every row whose [ ] checkbox is still open, and
-- the final assertion will fail the transaction if any row was deliberately
-- withheld.
-- To honour the stated discipline, either run one UPDATE at a time by hand as
-- its checkbox closes, or split this file per row before running anything.
-- Do not run it whole and assume the checkboxes protected you.
-- =========================================================================
-- earn_rates.mcc_includes backfill, pass 3b — CIBC (41 rows)
-- Generated 2026-08-26. SUPERSEDES the 2026-08-16 pass-2 file for this issuer set,
-- which was written against 43 rows and went stale while it sat: the debt grew from
-- 52 to 76 empty mcc_defined rows in the ten days it was pending.
--
-- STATUS: PENDING VERIFY — apply per row as its source-clause check closes.
--
-- APPROVAL: **STANDING, per issuer** (Mike, 2026-08-26). This replaces the
-- "Mike approves this batch by name in chat" gate on the pass-2 files, which is the
-- gate that actually stalled this work. A row ships when its [ ] source-clause check
-- below is closed by the verify lane — no further chat approval is needed. The other
-- gate is unchanged and non-negotiable: **a card whose bonus is NARROWER than the
-- category gets the narrow set, not the category set.** An unchecked row does not ship.
--
-- Decision basis: Mike, 2026-08-16 — "Backfill via verify lane" over engine fail-open;
-- fail-closed on empty mcc_includes retained. Re-affirmed and unblocked 2026-08-26.
-- See PIPELINE_AND_DECISIONS.md, both dates.
--
-- Sets are category-typical, read live from mcc_category_mappings on 2026-08-26 — the
-- same sets the merchant-path assumption already applies to these categories.
--
-- Pattern per p1 (2026-08-14): no snapshot table — every touched row starts from an
-- empty mcc_includes (also the UPDATE guard), ids enumerated, exact rollback at bottom,
-- in-transaction row-count assertion aborts on drift.
--
-- WHY THIS MATTERS: all 41 rows below are live-suppressed on active, scoreable cards.
-- earnRowPrices admits an mcc_defined row only when mcc_includes intersects the category
-- assumption; an empty list fails closed and the row NEVER prices. Every card here is
-- silently earning base everywhere in its bonus categories today.

-- ============================ SOURCE-CLAUSE CHECKLIST ============================
-- Close each [ ] by quoting the card's own terms for that category before its row ships.
--
-- CIBC Adapta Mastercard  (ca_cibc_adapta_standard_mastercard)  — 7 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] drugstore_pharmacy   -> {5122,5912}
--   [ ] entertainment        -> {7832,7841,7922}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] home_improvement     -> {5200,5211,5231,5251,5261}
--   [ ] streaming            -> {5815,5816,5817,5818}
--
-- CIBC Adapta Mastercard for Students  (ca_cibc_adapta_student_mastercard)  — 7 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] drugstore_pharmacy   -> {5122,5912}
--   [ ] entertainment        -> {7832,7841,7922}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] home_improvement     -> {5200,5211,5231,5251,5261}
--   [ ] streaming            -> {5815,5816,5817,5818}
--
-- CIBC Adapta World Mastercard  (ca_cibc_adapta_world_mastercard)  — 7 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] drugstore_pharmacy   -> {5122,5912}
--   [ ] entertainment        -> {7832,7841,7922}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] home_improvement     -> {5200,5211,5231,5251,5261}
--   [ ] streaming            -> {5815,5816,5817,5818}
--
-- CIBC Aeroplan Visa  (ca_cibc_aeroplan_standard_visa)  — 2 rows
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--
-- CIBC Aeroplan Visa Card for Students  (ca_cibc_aeroplan_student_visa)  — 2 rows
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--
-- CIBC Aeroplan Visa Infinite Privilege  (ca_cibc_aeroplan_visa_infinite_privilege_visa)  — 4 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] travel               -> {3000,3009,4511,7011,7512}
--
-- CIBC Aventura Visa  (ca_cibc_aventura_standard_visa)  — 3 rows
--   [ ] drugstore_pharmacy   -> {5122,5912}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--
-- CIBC Aventura Visa Card for Students  (ca_cibc_aventura_student_visa)  — 3 rows
--   [ ] drugstore_pharmacy   -> {5122,5912}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--
-- CIBC Dividend Visa  (ca_cibc_dividend_standard_visa)  — 3 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] transit_rideshare    -> {4111,4112,4121,4131,4789,7523}
--
-- CIBC Dividend Visa Card for Students  (ca_cibc_dividend_student_visa)  — 3 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] transit_rideshare    -> {4111,4112,4121,4131,4789,7523}

-- ================================ APPLY ================================

BEGIN;

-- CIBC Adapta Mastercard / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = '03f957ca-ea10-44d4-a741-3406beabc7b5'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard / drugstore_pharmacy
UPDATE public.earn_rates SET mcc_includes = ARRAY[5122,5912]
 WHERE id = 'fdfdf69b-fb15-4c33-b27a-5360d06d4622'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard / entertainment
UPDATE public.earn_rates SET mcc_includes = ARRAY[7832,7841,7922]
 WHERE id = '30f183ad-60ad-4725-af27-c6a07935c1da'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = '0c8281b9-646f-48e9-9b57-8577554ed4f2'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = 'a7d17254-b9f7-4961-9480-05d354feffd3'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard / home_improvement
UPDATE public.earn_rates SET mcc_includes = ARRAY[5200,5211,5231,5251,5261]
 WHERE id = '229b5aef-3c61-4f09-a38a-5dee2270e306'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard / streaming
UPDATE public.earn_rates SET mcc_includes = ARRAY[5815,5816,5817,5818]
 WHERE id = '4b2e2fa9-e983-4211-9f0d-1885a401c367'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = '563d0202-f08f-4813-a39f-3617b7a18b6b'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / drugstore_pharmacy
UPDATE public.earn_rates SET mcc_includes = ARRAY[5122,5912]
 WHERE id = '0677b330-b13c-4112-a29d-def4ebcc363a'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / entertainment
UPDATE public.earn_rates SET mcc_includes = ARRAY[7832,7841,7922]
 WHERE id = 'af9a89d6-b3bc-409b-930b-f920db2e794f'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = '2012a4c8-647c-4fba-9658-9c180000a24b'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = 'b60f8c18-0adf-40ae-8c5e-61e43bba325c'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / home_improvement
UPDATE public.earn_rates SET mcc_includes = ARRAY[5200,5211,5231,5251,5261]
 WHERE id = '691a9275-f0e5-4b89-bccf-92040ab2d0f1'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta Mastercard for Students / streaming
UPDATE public.earn_rates SET mcc_includes = ARRAY[5815,5816,5817,5818]
 WHERE id = '42f3137c-e221-415e-b1f4-0c5902c8f48d'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = 'fee370dc-d6ef-44be-b3e8-b800bfd5e0de'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / drugstore_pharmacy
UPDATE public.earn_rates SET mcc_includes = ARRAY[5122,5912]
 WHERE id = '73111aa5-47f7-475e-9d6d-3c80c7555412'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / entertainment
UPDATE public.earn_rates SET mcc_includes = ARRAY[7832,7841,7922]
 WHERE id = '912f6b4f-ac5d-4bc5-8f4d-08e9eb181b9b'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = '34a13436-89bc-4643-9965-b40b104e9cc6'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = 'a52159d1-3cbf-412d-887f-a37db72b9878'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / home_improvement
UPDATE public.earn_rates SET mcc_includes = ARRAY[5200,5211,5231,5251,5261]
 WHERE id = '4883b551-ef07-4679-bd9e-63240e3f5d74'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Adapta World Mastercard / streaming
UPDATE public.earn_rates SET mcc_includes = ARRAY[5815,5816,5817,5818]
 WHERE id = 'af81049a-46de-4552-84b9-50c27f87a046'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'd447475d-b69a-47f1-bbc0-7bc646899805'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '979b8566-590c-48a5-9fb1-72887f69dd2c'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa Card for Students / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'c8eb3bdd-abc3-42b4-93b0-8384f6ce18e2'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa Card for Students / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '1c1cf7c6-f9ce-4ffe-ae46-1bd47f3c769d'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa Infinite Privilege / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = 'e778c9e6-394e-47b7-9966-1c4d5f35a608'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa Infinite Privilege / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'bb670c9a-b808-417c-b5a2-88ff19d36327'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa Infinite Privilege / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '7fa782bb-bb40-419b-9bfb-0c3b4dd42526'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aeroplan Visa Infinite Privilege / travel
UPDATE public.earn_rates SET mcc_includes = ARRAY[3000,3009,4511,7011,7512]
 WHERE id = 'e9de039d-8d59-472b-92fa-ec246a57d0fb'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aventura Visa / drugstore_pharmacy
UPDATE public.earn_rates SET mcc_includes = ARRAY[5122,5912]
 WHERE id = 'e3ab7bd3-6747-4293-ae77-d15cc8746dda'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aventura Visa / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'a9b2a627-2989-4c29-a2c0-41a78ce2e695'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aventura Visa / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = 'bbee82f2-81d1-4aed-bdd5-ba839f21937d'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aventura Visa Card for Students / drugstore_pharmacy
UPDATE public.earn_rates SET mcc_includes = ARRAY[5122,5912]
 WHERE id = '2e3c595d-c180-42c6-892b-c61479a51080'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aventura Visa Card for Students / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = '7a18f394-9d91-46a9-8b98-a1375d9bd135'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Aventura Visa Card for Students / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = 'a928f30b-9f14-443f-9b3d-db3567fb934b'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Dividend Visa / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = '777d0a1a-45a4-477a-b003-6b92e6b7ea0b'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Dividend Visa / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = '1c8a8baf-3f76-4e2a-a256-67aea5abe2d9'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Dividend Visa / transit_rideshare
UPDATE public.earn_rates SET mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523]
 WHERE id = 'e0f35d09-e5f7-4fe8-99a2-9704de08f29e'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Dividend Visa Card for Students / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = 'c1b7fc62-fa07-4366-a3f2-b9fcdd5f4468'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Dividend Visa Card for Students / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'ca914db1-765d-48e5-b7eb-0eecc07c6252'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- CIBC Dividend Visa Card for Students / transit_rideshare
UPDATE public.earn_rates SET mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523]
 WHERE id = '8d388355-9b37-407e-aa25-998892bbd879'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

DO $$
DECLARE remaining int;
BEGIN
  SELECT count(*) INTO remaining
    FROM public.earn_rates er
    JOIN public.card_products cp ON cp.id = er.card_id
   WHERE cp.issuer_id IN ('cibc')
     AND er.condition_type = 'mcc_defined'
     AND (er.mcc_includes IS NULL OR cardinality(er.mcc_includes) = 0)
     AND EXISTS (SELECT 1 FROM public.mcc_category_mappings m WHERE m.category_id = er.category_id);
  IF remaining <> 0 THEN
    RAISE EXCEPTION 'DRIFT: % mapped-category rows still empty for this issuer set; expected 0. Rows appeared since generation — regenerate before applying.', remaining;
  END IF;
END $$;

COMMIT;

-- ============================== ROLLBACK ==============================
-- BEGIN;
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '03f957ca-ea10-44d4-a741-3406beabc7b5' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'fdfdf69b-fb15-4c33-b27a-5360d06d4622' AND mcc_includes = ARRAY[5122,5912];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '30f183ad-60ad-4725-af27-c6a07935c1da' AND mcc_includes = ARRAY[7832,7841,7922];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '0c8281b9-646f-48e9-9b57-8577554ed4f2' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'a7d17254-b9f7-4961-9480-05d354feffd3' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '229b5aef-3c61-4f09-a38a-5dee2270e306' AND mcc_includes = ARRAY[5200,5211,5231,5251,5261];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '4b2e2fa9-e983-4211-9f0d-1885a401c367' AND mcc_includes = ARRAY[5815,5816,5817,5818];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '563d0202-f08f-4813-a39f-3617b7a18b6b' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '0677b330-b13c-4112-a29d-def4ebcc363a' AND mcc_includes = ARRAY[5122,5912];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'af9a89d6-b3bc-409b-930b-f920db2e794f' AND mcc_includes = ARRAY[7832,7841,7922];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '2012a4c8-647c-4fba-9658-9c180000a24b' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'b60f8c18-0adf-40ae-8c5e-61e43bba325c' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '691a9275-f0e5-4b89-bccf-92040ab2d0f1' AND mcc_includes = ARRAY[5200,5211,5231,5251,5261];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '42f3137c-e221-415e-b1f4-0c5902c8f48d' AND mcc_includes = ARRAY[5815,5816,5817,5818];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'fee370dc-d6ef-44be-b3e8-b800bfd5e0de' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '73111aa5-47f7-475e-9d6d-3c80c7555412' AND mcc_includes = ARRAY[5122,5912];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '912f6b4f-ac5d-4bc5-8f4d-08e9eb181b9b' AND mcc_includes = ARRAY[7832,7841,7922];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '34a13436-89bc-4643-9965-b40b104e9cc6' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'a52159d1-3cbf-412d-887f-a37db72b9878' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '4883b551-ef07-4679-bd9e-63240e3f5d74' AND mcc_includes = ARRAY[5200,5211,5231,5251,5261];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'af81049a-46de-4552-84b9-50c27f87a046' AND mcc_includes = ARRAY[5815,5816,5817,5818];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'd447475d-b69a-47f1-bbc0-7bc646899805' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '979b8566-590c-48a5-9fb1-72887f69dd2c' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'c8eb3bdd-abc3-42b4-93b0-8384f6ce18e2' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '1c1cf7c6-f9ce-4ffe-ae46-1bd47f3c769d' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e778c9e6-394e-47b7-9966-1c4d5f35a608' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'bb670c9a-b808-417c-b5a2-88ff19d36327' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '7fa782bb-bb40-419b-9bfb-0c3b4dd42526' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e9de039d-8d59-472b-92fa-ec246a57d0fb' AND mcc_includes = ARRAY[3000,3009,4511,7011,7512];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e3ab7bd3-6747-4293-ae77-d15cc8746dda' AND mcc_includes = ARRAY[5122,5912];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'a9b2a627-2989-4c29-a2c0-41a78ce2e695' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'bbee82f2-81d1-4aed-bdd5-ba839f21937d' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '2e3c595d-c180-42c6-892b-c61479a51080' AND mcc_includes = ARRAY[5122,5912];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '7a18f394-9d91-46a9-8b98-a1375d9bd135' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'a928f30b-9f14-443f-9b3d-db3567fb934b' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '777d0a1a-45a4-477a-b003-6b92e6b7ea0b' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '1c8a8baf-3f76-4e2a-a256-67aea5abe2d9' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e0f35d09-e5f7-4fe8-99a2-9704de08f29e' AND mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'c1b7fc62-fa07-4366-a3f2-b9fcdd5f4468' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'ca914db1-765d-48e5-b7eb-0eecc07c6252' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '8d388355-9b37-407e-aa25-998892bbd879' AND mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523];
-- COMMIT;
