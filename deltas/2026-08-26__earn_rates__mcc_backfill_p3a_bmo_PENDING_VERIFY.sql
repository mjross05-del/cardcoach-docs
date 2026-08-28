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
-- earn_rates.mcc_includes backfill, pass 3a — BMO (11 rows)
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
-- WHY THIS MATTERS: all 11 rows below are live-suppressed on active, scoreable cards.
-- earnRowPrices admits an mcc_defined row only when mcc_includes intersects the category
-- assumption; an empty list fails closed and the row NEVER prices. Every card here is
-- silently earning base everywhere in its bonus categories today.

-- ============================ SOURCE-CLAUSE CHECKLIST ============================
-- Close each [ ] by quoting the card's own terms for that category before its row ships.
--
-- BMO eclipse rise Visa Card  (ca_bmo_eclipse_rise_standard_visa)  — 2 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--
-- BMO eclipse Visa Infinite Privilege Card  (ca_bmo_eclipse_visa_infinite_privilege_visa)  — 5 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] drugstore_pharmacy   -> {5122,5912}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] travel               -> {3000,3009,4511,7011,7512}
--
-- BMO eclipse Visa Infinite Card  (ca_bmo_eclipse_visa_infinite_visa)  — 4 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] transit_rideshare    -> {4111,4112,4121,4131,4789,7523}

-- ================================ APPLY ================================

BEGIN;

-- BMO eclipse rise Visa Card / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = '5041a039-144f-4a13-b692-4518baa70efc'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse rise Visa Card / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = 'e0cec8f1-0216-4ee9-ab22-f28be93955ef'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Privilege Card / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = 'bc47bcea-dd35-416f-a4c6-4359d191830a'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Privilege Card / drugstore_pharmacy
UPDATE public.earn_rates SET mcc_includes = ARRAY[5122,5912]
 WHERE id = '1c5179a6-07e4-4ba8-8150-6860828f7cec'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Privilege Card / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = '6c046501-1395-4574-9d25-061705888c71'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Privilege Card / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '8cf4685b-c967-4c0e-91a8-ed89ba73a80a'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Privilege Card / travel
UPDATE public.earn_rates SET mcc_includes = ARRAY[3000,3009,4511,7011,7512]
 WHERE id = '3332af4c-48bc-46b8-8e6a-aa8547d6cc78'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Card / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = '07bf8fd6-4972-42b3-a400-19a864d04fd8'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Card / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'aeabf16a-b513-482e-80d2-47c6dc4f0936'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Card / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '8eeade60-b1ea-4b4c-a934-37b38dba9e6c'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- BMO eclipse Visa Infinite Card / transit_rideshare
UPDATE public.earn_rates SET mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523]
 WHERE id = '751c73ad-3232-452a-9444-886f89a62391'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

DO $$
DECLARE remaining int;
BEGIN
  SELECT count(*) INTO remaining
    FROM public.earn_rates er
    JOIN public.card_products cp ON cp.id = er.card_id
   WHERE cp.issuer_id IN ('bmo')
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
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '5041a039-144f-4a13-b692-4518baa70efc' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e0cec8f1-0216-4ee9-ab22-f28be93955ef' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'bc47bcea-dd35-416f-a4c6-4359d191830a' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '1c5179a6-07e4-4ba8-8150-6860828f7cec' AND mcc_includes = ARRAY[5122,5912];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '6c046501-1395-4574-9d25-061705888c71' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '8cf4685b-c967-4c0e-91a8-ed89ba73a80a' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '3332af4c-48bc-46b8-8e6a-aa8547d6cc78' AND mcc_includes = ARRAY[3000,3009,4511,7011,7512];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '07bf8fd6-4972-42b3-a400-19a864d04fd8' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'aeabf16a-b513-482e-80d2-47c6dc4f0936' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '8eeade60-b1ea-4b4c-a934-37b38dba9e6c' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '751c73ad-3232-452a-9444-886f89a62391' AND mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523];
-- COMMIT;
