-- =========================================================================
-- SUPERSEDED 2026-09-02 — DO NOT RUN. Replaced by
-- deltas/2026-09-02__earn_rates__mcc_backfill_p3_APPLIED.sql, which applied 40 rows with the
-- source-clause checks closed against the issuers' own definitions (CIBC rows carry the
-- issuer's narrower class sets, not the category-typical sets in this file) and withheld
-- 35 (33 CIBC Adapta auto-top-3, Aeroplan VIP dining, Neo United). Kept for the record.
-- =========================================================================
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
-- earn_rates.mcc_includes backfill, pass 3c — SCOTIABANK + NEO (12 rows)
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
-- WHY THIS MATTERS: all 12 rows below are live-suppressed on active, scoreable cards.
-- earnRowPrices admits an mcc_defined row only when mcc_includes intersects the category
-- assumption; an empty list fails closed and the row NEVER prices. Every card here is
-- silently earning base everywhere in its bonus categories today.

-- ============================ SOURCE-CLAUSE CHECKLIST ============================
-- Close each [ ] by quoting the card's own terms for that category before its row ships.
--
-- United MileagePlus Neo World Elite Mastercard  (ca_neo_financial_united_mileageplus_world_elite_mastercard)  — 1 row
--   [ ] travel               -> {3000,3009,4511,7011,7512}
--
-- Scotiabank American Express Card  (ca_scotiabank_amex_no_fee_amex_credit_amex)  — 5 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] entertainment        -> {7832,7841,7922}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] transit_rideshare    -> {4111,4112,4121,4131,4789,7523}
--
-- Scotiabank American Express Card (for students)  (ca_scotiabank_amex_student_amex)  — 5 rows
--   [ ] dining               -> {5811,5812,5813}
--   [ ] entertainment        -> {7832,7841,7922}
--   [ ] gas                  -> {5541,5542,5552}
--   [ ] grocery              -> {5411,5422,5441,5451,5462,5499}
--   [ ] transit_rideshare    -> {4111,4112,4121,4131,4789,7523}
--
-- Scotia Momentum Visa Infinite + Card  (ca_scotiabank_momentum_visa_infinite_visa)  — 1 row
--   [ ] recurring_bills      -> {4814,4899,4900,6300,7997}

-- ================================ APPLY ================================

BEGIN;

-- United MileagePlus Neo World Elite Mastercard / travel
--
-- !! OVER-CREDIT WARNING, RESTORED 2026-08-27. The p2 file this supersedes set
-- !! this same row to the AIRLINE-ONLY set {3000,3009,4511} and carried an
-- !! explicit note that was dropped here without explanation:
-- !!   "SPECIAL: 'airline MCC only, own booking channels'; category-typical
-- !!    travel set would over-credit hotels/car rental ... verify pass must
-- !!    confirm acceptable over-credit or reject this row."
-- !! Widening to {3000,3009,4511,7011,7512} adds 7011 (hotels) and 7512 (car
-- !! rental). If the card's terms really say airline-only, this row credits a
-- !! hotel stay at the travel rate that the issuer would not pay -- an
-- !! over-credit, which is the failure mode this project treats as worse than
-- !! under-crediting. DO NOT SHIP THIS ROW until the source clause is quoted
-- !! and it either justifies the wider set or this reverts to {3000,3009,4511}.
UPDATE public.earn_rates SET mcc_includes = ARRAY[3000,3009,4511,7011,7512]
 WHERE id = '67825deb-714e-47f7-af43-31f7ea8b047a'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = 'e376d4c9-457f-4886-9035-90318800ede2'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card / entertainment
UPDATE public.earn_rates SET mcc_includes = ARRAY[7832,7841,7922]
 WHERE id = '978a3051-446b-4c9c-893e-7e625e7ae9c7'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'e4636cad-bbbe-41f2-8478-aa0f80c1bd3c'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '9241065d-c89a-4e71-b175-597ef9066ae3'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card / transit_rideshare
UPDATE public.earn_rates SET mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523]
 WHERE id = 'c3c68337-3d2c-4997-8bd1-e361646acfa0'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card (for students) / dining
UPDATE public.earn_rates SET mcc_includes = ARRAY[5811,5812,5813]
 WHERE id = '475f66cf-520a-4c15-9958-07861888e8eb'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card (for students) / entertainment
UPDATE public.earn_rates SET mcc_includes = ARRAY[7832,7841,7922]
 WHERE id = '90f8db9d-ec77-462d-8518-a252aaf3415f'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card (for students) / gas
UPDATE public.earn_rates SET mcc_includes = ARRAY[5541,5542,5552]
 WHERE id = 'e7982e97-2e9c-434c-805d-42f8535912d7'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card (for students) / grocery
UPDATE public.earn_rates SET mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499]
 WHERE id = '0b30e1ed-8ddd-4d81-ba1d-33aeca479f23'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotiabank American Express Card (for students) / transit_rideshare
UPDATE public.earn_rates SET mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523]
 WHERE id = 'aa8a69db-29b0-402d-959f-63422df2ffe7'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

-- Scotia Momentum Visa Infinite + Card / recurring_bills
UPDATE public.earn_rates SET mcc_includes = ARRAY[4814,4899,4900,6300,7997]
 WHERE id = '7c20914f-ed4b-4ea1-9f38-e5434626bcc7'
   AND (mcc_includes IS NULL OR cardinality(mcc_includes) = 0);

DO $$
DECLARE remaining int;
BEGIN
  SELECT count(*) INTO remaining
    FROM public.earn_rates er
    JOIN public.card_products cp ON cp.id = er.card_id
   WHERE cp.issuer_id IN ('scotiabank', 'neo-financial')
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
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '67825deb-714e-47f7-af43-31f7ea8b047a' AND mcc_includes = ARRAY[3000,3009,4511,7011,7512];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e376d4c9-457f-4886-9035-90318800ede2' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '978a3051-446b-4c9c-893e-7e625e7ae9c7' AND mcc_includes = ARRAY[7832,7841,7922];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e4636cad-bbbe-41f2-8478-aa0f80c1bd3c' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '9241065d-c89a-4e71-b175-597ef9066ae3' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'c3c68337-3d2c-4997-8bd1-e361646acfa0' AND mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '475f66cf-520a-4c15-9958-07861888e8eb' AND mcc_includes = ARRAY[5811,5812,5813];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '90f8db9d-ec77-462d-8518-a252aaf3415f' AND mcc_includes = ARRAY[7832,7841,7922];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'e7982e97-2e9c-434c-805d-42f8535912d7' AND mcc_includes = ARRAY[5541,5542,5552];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '0b30e1ed-8ddd-4d81-ba1d-33aeca479f23' AND mcc_includes = ARRAY[5411,5422,5441,5451,5462,5499];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = 'aa8a69db-29b0-402d-959f-63422df2ffe7' AND mcc_includes = ARRAY[4111,4112,4121,4131,4789,7523];
--   UPDATE public.earn_rates SET mcc_includes = NULL WHERE id = '7c20914f-ed4b-4ea1-9f38-e5434626bcc7' AND mcc_includes = ARRAY[4814,4899,4900,6300,7997];
-- COMMIT;
