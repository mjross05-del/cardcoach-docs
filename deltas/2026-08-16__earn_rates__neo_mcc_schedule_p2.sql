-- DELTA 2026-08-16 — Neo Financial, part 4: MCC schedule applied + a dining/fast-food defect fixed
-- STATUS: APPLIED to production 2026-08-16 via MCP execute_sql, guarded (one rollback on a bad
--         assertion of my own, corrected and re-run — see POST-STATE note at the foot).
-- Source: MCC Code Descriptions.pdf (4pp), linked from footnote 1 of neofinancial.com/credit-cards
--         via legal.neo.cc/cashback-categories. robots-disallowed to the fetcher; retrieved in the
--         chrome lane and read off disk. Both Neo disclosure statements also now held on disk.
--
-- WHAT NEO PUBLISHES (per plan):
--   Gas       5541, 5542, 5552          <- EV charging sits INSIDE Neo's gas bucket
--   Grocery   5411
--   Dine      5811, 5812, 5813, 5814
--   Recurring 4812, 4814, 4899, 4900, 5815, 5816, 5817, 5818, 5968, 6300, 7997
--   Shop      ~90 codes across retail (see the PDF; deliberately not transcribed here)
--
-- DEFECT FIXED — 5814 IS NOT `dining`.
-- MCC 5814 (Fast Food Restaurants) maps to category `coffee_fastfood` in mcc_category_mappings.
-- The United MileagePlus dining row loaded earlier today carried all four Dine codes on category
-- `dining`. Under the merchant MCC assumption (flag ON since 2026-08-14) the intersection test
-- category(row) vs mapping(mcc) can never succeed at a fast-food merchant, so that row silently
-- failed to price somewhere Neo actually pays. Split into two rows, each carrying only the codes
-- that map to its own category. Any issuer whose "dining" enumeration includes 5814 has this trap.
--
-- SHARED-POOL CONCERN RETIRED (raised in part 2 of this series).
-- All three Neo gas codes map to `gas`, 5552 included, so EV spend accumulates in the gas bucket
-- rather than a second one. The gas/ev_charging double-cap risk is inert. The ev_charging rows are
-- redundant on the merchant path and are kept only for an explicit ev_charging category request.
--
-- STILL BLOCKED, both bigger than Neo and both left alone here:
--  1. "Shop" has no CardCoach category. ~90 MCCs spanning department stores, electronics, clothing,
--     hardware, books, digital goods, direct marketing. No `retail_shopping` exists and it does not
--     collapse into one existing category. Both Shop & Dine plans stay load_only: their
--     Food-and-drink half is now loaded and correct, their Shop half is not.
--  2. `recurring_bills` is an unmapped category. Of Neo's 11 Recurring codes only 5815-5818
--     (-> streaming) and 5968 (-> online_retail) are mapped, and NONE point at recurring_bills.
--     4812/4814/4899/4900/6300/7997 are unmapped outright. Neo's 2%/4% recurring bonus therefore
--     does not price — and neither does any other issuer's. Adding those mappings is
--     ranking-affecting in both directions per the 2026-08-14 decision and needs a gated delta
--     with a pre-flip recon. mcc_includes was populated on the two Neo rows as documentation only;
--     it does NOT unblock them, and the condition_text says so.
--
-- NOT CHANGED ON PURPOSE: condition_type on the gas/grocery/ev rows stays as loaded. Neo's cashback
-- is genuinely MCC-defined, so 'mcc_defined' would be the truthful value, but flipping it would make
-- those rows fail closed on the stateless path and is a live scoring change across three scoreable
-- cards. That is a decision, not a backfill.

BEGIN;
DO $$ DECLARE n int; BEGIN
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id WHERE cp.issuer_id='neo-financial';
  IF n <> 26 THEN RAISE EXCEPTION 'PRE-STATE FAIL: neo earn_rates=% expected 26', n; END IF;
END $$;

-- 1. Narrow the United dining row to the codes that map to `dining`.
-- 2. Add coffee_fastfood {5814} to United (1x) and to both Shop & Dine plans (2% / 5%).
-- 3. Add the Food-and-drink `dining` rows to both Shop & Dine plans (2% $500/mo, 5% $1,000/mo).
-- 4. Backfill mcc_includes as documentation: grocery {5411}, gas {5541,5542,5552},
--    ev_charging {5552}, recurring_bills {the 11 codes}.
-- 5. Record Cathay's FX + $180 fee as Tier 1 confirmed by the Except-Quebec document, which
--    names the card (the Quebec-jurisdiction gap raised earlier today is closed).
-- Full applied text is in the session transcript. Authoritative read-back:
--   SELECT cp.display_name, er.category_id, er.base_rate*er.multiplier AS eff,
--          er.cap_monthly_cad, er.mcc_includes
--   FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id
--   WHERE cp.issuer_id='neo-financial' ORDER BY 1,2;

DO $$ DECLARE n int; BEGIN
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id WHERE cp.issuer_id='neo-financial';
  IF n <> 31 THEN RAISE EXCEPTION 'POST-STATE FAIL: neo earn_rates=% expected 31', n; END IF;
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id
   WHERE cp.issuer_id='neo-financial' AND er.category_id='dining' AND 5814 = ANY(er.mcc_includes);
  IF n <> 0 THEN RAISE EXCEPTION 'POST-STATE FAIL: a dining row still claims MCC 5814'; END IF;
  -- Exactly three category rows legitimately carry no MCCs: Cathay travel (merchant_list_only),
  -- Cathay foreign_currency_spend (currency-based, no MCC concept), United travel (tier C prose).
  -- The first run of this delta asserted 1 here, failed closed, and rolled back. Corrected to 3.
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id
   WHERE cp.issuer_id='neo-financial' AND er.mcc_includes IS NULL AND er.basis='category';
  IF n <> 3 THEN RAISE EXCEPTION 'POST-STATE FAIL: % category rows lack mcc_includes, expected 3', n; END IF;
END $$;
COMMIT;
