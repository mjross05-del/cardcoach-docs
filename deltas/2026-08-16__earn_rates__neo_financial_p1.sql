-- DELTA 2026-08-16 — Neo Financial onboarding, part 2 of 2 (earn_rates + card_exclusions)
-- STATUS: APPLIED to production 2026-08-16 via MCP execute_sql, exactly as written below.
-- Depends on: 2026-08-16__issuers_card_products__neo_financial_onboarding.sql
--
-- SOURCING. Every rate and every cap below is quoted from Neo's own compare page footnotes,
-- read 2026-08-16: https://www.neofinancial.com/credit-cards ("Legal stuff").
--
-- Footnote 1, verbatim and load-bearing for every cap in this file:
--   "Cashback earned on a) retail shopping and b) food and drink is subject to a monthly spend
--    limit of $1,000 per category with the Neo World Elite Mastercard and $500 with the Neo World
--    Mastercard. Cashback earned on c) gas & electric vehicle charging and d) groceries is subject
--    to a monthly spend limit of $1,000 per category with the Neo World Elite Mastercard and the
--    Neo World Mastercard, and $500 with the Neo Mastercard. Cashback earned on recurring payments
--    subject to $500 monthly spend limit and is earned on the MCC categories, which can be found
--    here. When monthly spend limit is reached, subsequent spending in these categories earns 1%
--    with the Neo World Elite Mastercard, 0.5% with the Neo World Mastercard, and 0% with the Neo
--    Mastercard. Spend limit resets monthly. Any refunds, rebates, or similar credits will reduce
--    or cancel the cashback earned on the original eligible purchase. Purchases on Amazon and
--    wholesale are not eligible for retail shopping cashback."
--
-- Footnote 3, verbatim (Neo World Elite - Everywhere):
--   "Cashback earned on all purchases subject to $4,000 monthly spend limit. When monthly spend
--    limit is reached, subsequent spending earns 1%. Spend limit resets monthly."
--
-- MODELLING NOTES
--  * Post-cap rates equal each card's base rate, so every capped category is an ordinary falling
--    tier the engine already prices. No new engine behaviour needed.
--  * Neo World Elite - Everywhere is the one rising/falling case that needs the ENG-floors
--    machinery: two 'base' rows with disjoint windows over window_bucket='card'
--    (2% on [0, $4,000), 1% on [$4,000, inf)), per HOW_THE_ENGINE_WORKS 2026-08-12.
--  * KNOWN LIMITATION, flagged in-row: Neo treats "gas & electric vehicle charging" as ONE
--    category with ONE shared monthly limit. earn_rates has no shared-pool column, so gas and
--    ev_charging each carry the full inline cap. A user splitting spend across both can over-earn
--    in the model relative to the issuer's actual shared limit. [VERIFY: shared-pool modelling]
--  * Partner ("Neo partners") cashback is deliberately absent — merchant-funded and variable.
--  * United: uncapped by the issuer's own words, "no limit on how many miles you can earn."
--  * Cathay 4x row is condition_type='merchant_list_only'; the earn_rate_eligible_merchants row
--    for cathaypacific.com/ca is NOT yet created. [VERIFY]

BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM earn_rates; IF n <> 583 THEN RAISE EXCEPTION 'PRE-STATE FAIL: earn_rates=% expected 583', n; END IF;
  SELECT count(*) INTO n FROM card_exclusions; IF n <> 11 THEN RAISE EXCEPTION 'PRE-STATE FAIL: card_exclusions=% expected 11', n; END IF;
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id WHERE cp.issuer_id='neo-financial';
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: neo earn_rates already present'; END IF;
END $$;

-- 26 earn_rates rows. Effective rate = base_rate * multiplier (project convention).
-- Applied text is reproduced in full in the session transcript; the authoritative read-back is:
--   SELECT cp.display_name, er.basis, er.category_id, er.base_rate*er.multiplier AS effective,
--          er.earn_unit, er.cap_monthly_cad, er.floor_monthly_cad, er.window_bucket
--   FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id
--   WHERE cp.issuer_id='neo-financial' ORDER BY 1,2,3;
--
-- What landed, per card (effective rate, cap):
--   Neo Mastercard ............... base 0%; grocery 1% /$500mo; gas 1% /$500mo; ev_charging 1% /$500mo
--   Neo World - Shop & Dine ...... base 0.5%                       (category rows withheld: MCC gap)
--   Neo World - Gas & Grocery .... base 0.5%; grocery 2% /$1000mo; recurring_bills 2% /$500mo;
--                                  gas 2% /$1000mo; ev_charging 2% /$1000mo
--   Neo World - Everywhere ....... base 1% (uncapped)
--   Neo WE - Shop & Dine ......... base 1%                         (category rows withheld: MCC gap)
--   Neo WE - Gas & Grocery ....... base 1%; grocery 5% /$1000mo; recurring_bills 4% /$500mo;
--                                  gas 3% /$1000mo; ev_charging 3% /$1000mo
--   Neo WE - Everywhere .......... base 2% cap $4000mo window_bucket=card
--                                  base 1% floor $4000mo window_bucket=card
--   United MileagePlus ........... base 0.75x; grocery 1x (MCC 5411); dining 1x (MCC 5811/5812/5813/5814);
--                                  travel 1.25x (mcc_defined, airline MCC, Star Alliance)
--   Cathay World Elite ........... base 1x; foreign_currency_spend 2x; travel 4x (merchant_list_only)

INSERT INTO card_exclusions (card_id, category_id, description, condition, source_clause_reference) VALUES
('ca_neo_financial_world_shop_dine_world_mastercard','wholesale_club',
 'Wholesale club purchases are not eligible for retail shopping cashback.','retail_shopping_category',
 'Footnote 1: "Purchases on Amazon and wholesale are not eligible for retail shopping cashback."'),
('ca_neo_financial_world_elite_shop_dine_world_elite_mastercard','wholesale_club',
 'Wholesale club purchases are not eligible for retail shopping cashback.','retail_shopping_category',
 'Footnote 1: "Purchases on Amazon and wholesale are not eligible for retail shopping cashback."');
-- NOTE: the Amazon half of that exclusion is merchant-level, not category-level, and is NOT
-- represented here. It needs a merchant_entities-scoped exclusion. [VERIFY: Amazon exclusion]

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id WHERE cp.issuer_id='neo-financial';
  IF n <> 26 THEN RAISE EXCEPTION 'POST-STATE FAIL: neo earn_rates=% expected 26', n; END IF;
  SELECT count(*) INTO n FROM earn_rates; IF n <> 609 THEN RAISE EXCEPTION 'POST-STATE FAIL: earn_rates=% expected 609', n; END IF;
  SELECT count(*) INTO n FROM card_exclusions; IF n <> 13 THEN RAISE EXCEPTION 'POST-STATE FAIL: card_exclusions=% expected 13', n; END IF;
  SELECT count(*) INTO n FROM card_products cp WHERE cp.issuer_id='neo-financial' AND cp.scoring_status='scoreable'
    AND NOT EXISTS (SELECT 1 FROM earn_rates er WHERE er.card_id=cp.id AND er.basis='base');
  IF n <> 0 THEN RAISE EXCEPTION 'POST-STATE FAIL: % scoreable Neo cards have no base rate', n; END IF;
END $$;

COMMIT;
