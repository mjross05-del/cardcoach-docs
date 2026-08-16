-- DELTA 2026-08-16 — Neo Financial onboarding, part 1 of 2 (taxonomy + card_products)
-- STATUS: APPLIED to production 2026-08-16 via MCP execute_sql, in the guarded transaction below.
-- Authority: PROJECT_RULES rule 9 (direct write), conditions (a) snapshot (b) delta file (d) guards.
-- Snapshots taken first, RLS-secured, suffix _snapshot_20260816_neo:
--   issuers, reward_programs, point_programs, card_products, earn_rates, card_caps,
--   card_exclusions, point_valuations
--
-- SOURCING — all facts Tier 1b (issuer product pages), read 2026-08-16 via the chrome lane:
--   https://www.neofinancial.com/credit-cards          (compare page + "Legal stuff" footnotes 1, 3, 16)
--   https://www.neofinancial.com/credit-cards/neo-mastercard
--   https://www.neofinancial.com/credit-cards/neo-world-elite-mastercard
--   https://www.neofinancial.com/credit-cards/neo-united-mastercard
--   https://cathay.neofinancial.com/
-- legal.neo.cc (cardholder agreement, rate & fee schedule, rewards policy, MCC schedule) is
-- robots-disallowed to the fetcher; read via the operator's browser only where noted.
--
-- SCOPE NOTES
--  * Neo World and Neo World Elite each ship in THREE reward plans (Shop & Dine / Gas & Grocery /
--    Everywhere). Neo sells them as separate products with separate rate sheets, so each is its
--    own card_products row. Nine rows total.
--  * Partner ("Neo partners") cashback is merchant-funded, variable and not a published per-purchase
--    rate. EXCLUDED from earn_rates by decision (Mike, 2026-08-16) — modelling it would breach rule 7.
--  * fx_fee_percent is NULL on all nine: Neo publishes no FX fee on any product page. Follows the
--    2026-08-02 unsourced-FX-to-NULL precedent. Flagged [VERIFY] in source_metadata.
--  * Shop & Dine plans land load_only: their "Shop" and "Food and drink" categories are MCC-defined
--    in Neo's MCC Code Descriptions schedule, which is not yet transcribed. Base rates loaded;
--    category rows withheld rather than guessed.
--  * United and Cathay land load_only: Tier 2 point valuation FAILED condition 2 (see part 2 header).

BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM issuers;
  IF n <> 15 THEN RAISE EXCEPTION 'PRE-STATE FAIL: issuers=% expected 15', n; END IF;
  SELECT count(*) INTO n FROM issuers WHERE id = 'neo-financial';
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: neo-financial already exists'; END IF;
  SELECT count(*) INTO n FROM card_products;
  IF n <> 130 THEN RAISE EXCEPTION 'PRE-STATE FAIL: card_products=% expected 130', n; END IF;
END $$;

INSERT INTO issuers (id, display_name) VALUES ('neo-financial', 'Neo Financial');

-- Issuer of record, verbatim from every product page:
--   "issued by Neo Financial(TM) pursuant to license by Mastercard International Incorporated"
-- Legal entity named in the insurance footnotes: Neo Financial Technologies Inc.

-- Cashback products reuse the shared 'cashback' reward_program (Rogers/Tangerine/BMO precedent).
-- Two new airline currencies. default_cents_per_point = 0 is a FAIL-CLOSED PLACEHOLDER, not a
-- valuation: reward_programs_cents_per_point_rule forbids NULL on a points programme, and rule 7
-- forbids estimating. Zero cannot inflate a ranking and both carrier cards are load_only anyway.
INSERT INTO reward_programs (id, display_name, reward_unit, currency, default_cents_per_point) VALUES
  ('united-mileageplus', 'United MileagePlus', 'points', 'CAD', 0.0000),
  ('asia-miles',         'Asia Miles',         'points', 'CAD', 0.0000);

INSERT INTO point_programs (id, reward_program_id, display_name) VALUES
  ('united-mileageplus-miles', 'united-mileageplus', 'United MileagePlus Miles'),
  ('asia-miles-points',        'asia-miles',         'Asia Miles');

-- card_products: nine rows. Full column values as applied are reproduced in the session
-- transcript and readable from card_products WHERE issuer_id='neo-financial'.
-- Summary of what landed:
--   ca_neo_financial_neo_standard_mastercard                        $0    base 0.00  scoreable
--   ca_neo_financial_world_shop_dine_world_mastercard               $0    base 0.50  load_only
--   ca_neo_financial_world_gas_grocery_world_mastercard             $0    base 0.50  scoreable
--   ca_neo_financial_world_everywhere_world_mastercard              $0    base 1.00  scoreable
--   ca_neo_financial_world_elite_shop_dine_world_elite_mastercard   $149  base 1.00  load_only
--   ca_neo_financial_world_elite_gas_grocery_world_elite_mastercard $149  base 1.00  scoreable
--   ca_neo_financial_world_elite_everywhere_world_elite_mastercard  $149  base 2.00  scoreable
--   ca_neo_financial_united_mileageplus_world_elite_mastercard      $89   base 0.75  load_only
--   ca_neo_financial_cathay_world_elite_mastercard                  $180  base 1.00  load_only
-- Cathay is availability_scope='regional' with available_provinces excluding QC, per its own
-- disclaimer: "The Cathay World Elite Mastercard is not available in Quebec."

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM issuers;
  IF n <> 16 THEN RAISE EXCEPTION 'POST-STATE FAIL: issuers=% expected 16', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='neo-financial';
  IF n <> 9 THEN RAISE EXCEPTION 'POST-STATE FAIL: neo cards=% expected 9', n; END IF;
  SELECT count(*) INTO n FROM card_products;
  IF n <> 139 THEN RAISE EXCEPTION 'POST-STATE FAIL: card_products=% expected 139', n; END IF;
END $$;

COMMIT;

-- ROLLBACK (if ever needed):
--   DELETE FROM earn_rates WHERE card_id IN (SELECT id FROM card_products WHERE issuer_id='neo-financial');
--   DELETE FROM card_exclusions WHERE card_id IN (SELECT id FROM card_products WHERE issuer_id='neo-financial');
--   DELETE FROM card_products WHERE issuer_id='neo-financial';
--   DELETE FROM point_programs WHERE id IN ('united-mileageplus-miles','asia-miles-points');
--   DELETE FROM reward_programs WHERE id IN ('united-mileageplus','asia-miles');
--   DELETE FROM issuers WHERE id='neo-financial';
