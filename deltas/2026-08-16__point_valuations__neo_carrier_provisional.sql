-- DELTA 2026-08-16 — Neo Financial part 3 of 3: PROVISIONAL carrier point valuations
-- STATUS: APPLIED to production 2026-08-16 via MCP execute_sql, guarded.
-- Depends on: 2026-08-16__issuers_card_products__neo_financial_onboarding.sql (parts 1 and 2)
-- Snapshots: point_valuations_snapshot_20260816_neo, reward_programs_snapshot_20260816_neo,
--            card_products_snapshot_20260816_neo (taken at session start, RLS-secured)
--
-- ============================ READ THIS BEFORE CITING THESE ROWS ============================
-- These two valuations are UNCONFIRMED and NOT TIER 2 COMPLIANT. They are live on Mike's
-- explicit ruling of 2026-08-16: "go with what we see right now (two matching valuations with
-- no source), mark as unconfirmed for me requiring a deeper dive."
--
-- Tier 2 condition 2 requires three or more independent recognised sources. Only TWO
-- independent publishers state a figure in Canadian cents for either currency:
--   United MileagePlus  Prince of Travel 1.6   Milesopedia 1.6   -> stored 1.6000
--   Cathay Asia Miles   Prince of Travel 1.5   Milesopedia 1.5   -> stored 1.5000
-- Both read on the publisher's own page 2026-08-16 (§2b: a search summary is not a source).
-- Evidence attached as four point_valuation_sources rows.
--
-- source_tier is NULL, deliberately, NOT 'tier2'. The database enforces the governance rule:
--   CHECK (valid_to IS NOT NULL OR source_tier IS DISTINCT FROM 'tier2' OR source_count >= 3)
-- Writing these as tier2 would have been rejected by the constraint, and would have been a
-- false compliance claim if it had not been. confidence='low'. source_count=2, honestly.
--
-- Only the 'realistic' tier is written. conservative and aggressive are ABSENT on purpose:
-- two identical data points give no basis for a spread, and manufacturing one would be
-- inventing precision (rule 7). The engine falls back to realistic for users on the other
-- tiers and emits a warning naming the programme — the documented, correct behaviour.
--
-- KNOWN WEAKNESS, carried deliberately and recorded so the deeper dive starts informed:
-- the two surviving sources report IDENTICAL figures, neither cites the other, neither
-- discloses a method beyond "an average benchmark", and neither states whether its CAD
-- figure is native or converted. Their own CAD/USD pairs imply inconsistent FX rates
-- (1.333 for MileagePlus, 1.364 for Asia Miles), and neither matches the Bank of Canada
-- rate of 1.3875 for 2026-08-14. Consistent with independent rounding to one decimal,
-- which means neither figure is reproducible from the other.
--
-- EXCLUDED SOURCES AND WHY (do not re-litigate without new evidence):
--   Frugal Flyer — publishes CAD figures (United 1.8, Asia Miles 1.5) but its own programme
--     pages state United at 1.3 cents USD (1.3 x 1.3875 = 1.80) and Asia Miles at "1.6 CAD
--     cents per point (1.2 USD cents per point)", contradicting its own roundup. FX-derived,
--     which §2a currency discipline forbids counting, and self-inconsistent besides.
--   TPG, Frequent Miler, Upgraded Points, NerdWallet, OMAAT, Bankrate, The Point Calculator —
--     all USD-denominated. §2a forbids converting USD into the band.
--   NerdWallet Canada, Ratehub, The Points Standard, Rewards Canada, Points Nerd,
--     creditcardgenius, MoneySense, Loonie Tree — checked 2026-08-16, no figure for either
--     programme. Do not re-check these first.
--
-- EFFECT: both carrier cards move load_only -> scoreable. Neo now has 7 of 9 scoreable.
-- REVERT IF THE DIVE FAILS: set both cards back to load_only and expire these rows
-- (valid_to = the expiry date; never DELETE — rule 9c).
-- ===========================================================================================

BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM point_valuations WHERE point_program_id IN ('united-mileageplus-miles','asia-miles-points');
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: valuations already exist (%)', n; END IF;
  SELECT count(*) INTO n FROM reward_programs WHERE id IN ('united-mileageplus','asia-miles') AND default_cents_per_point = 0;
  IF n <> 2 THEN RAISE EXCEPTION 'PRE-STATE FAIL: placeholder defaults not both 0 (%)', n; END IF;
  SELECT count(*) INTO n FROM card_products
    WHERE id IN ('ca_neo_financial_united_mileageplus_world_elite_mastercard','ca_neo_financial_cathay_world_elite_mastercard')
      AND scoring_status = 'load_only';
  IF n <> 2 THEN RAISE EXCEPTION 'PRE-STATE FAIL: co-brands not both load_only (%)', n; END IF;
END $$;

-- point_valuations: 2 rows (realistic tier only), source_tier NULL, confidence low,
--   observed_low = observed_high = the stored value, source_count = 2.
-- point_valuation_sources: 4 evidence rows (2 per valuation), each with the URL the figure
--   was read from, the verbatim figure, accessed_at = 2026-08-16, and the publisher's own
--   stated method where it gives one.
-- Full applied text is in the session transcript; authoritative read-back:
--   SELECT pv.point_program_id, pv.cents_per_point, pv.valuation_tier, pv.confidence,
--          pv.source_tier, pv.source_count, pv.observed_low, pv.observed_high
--   FROM point_valuations pv
--   WHERE pv.point_program_id IN ('united-mileageplus-miles','asia-miles-points') AND pv.valid_to IS NULL;

-- Placeholder defaults replaced (this is what resolves the 0-placeholder problem recorded
-- in part 1: reward_programs_cents_per_point_rule forbids NULL on a points programme, so the
-- programmes had been carrying a fail-closed 0).
UPDATE reward_programs SET default_cents_per_point = 1.6000 WHERE id = 'united-mileageplus';
UPDATE reward_programs SET default_cents_per_point = 1.5000 WHERE id = 'asia-miles';

UPDATE card_products SET scoring_status = 'scoreable',
  source_metadata = jsonb_set(source_metadata, '{verify,point_valuation}', to_jsonb('[UNCONFIRMED — deeper dive required] ...'::text))
WHERE id IN ('ca_neo_financial_united_mileageplus_world_elite_mastercard','ca_neo_financial_cathay_world_elite_mastercard');

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM point_valuations
    WHERE point_program_id IN ('united-mileageplus-miles','asia-miles-points') AND valid_to IS NULL;
  IF n <> 2 THEN RAISE EXCEPTION 'POST-STATE FAIL: active valuations=% expected 2', n; END IF;
  SELECT count(*) INTO n FROM point_valuations
    WHERE point_program_id IN ('united-mileageplus-miles','asia-miles-points') AND source_tier = 'tier2';
  IF n <> 0 THEN RAISE EXCEPTION 'POST-STATE FAIL: a provisional row is claiming tier2'; END IF;
  SELECT count(*) INTO n FROM point_valuation_sources pvs JOIN point_valuations pv ON pv.id = pvs.valuation_id
    WHERE pv.point_program_id IN ('united-mileageplus-miles','asia-miles-points');
  IF n <> 4 THEN RAISE EXCEPTION 'POST-STATE FAIL: evidence rows=% expected 4', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='neo-financial' AND scoring_status='scoreable';
  IF n <> 7 THEN RAISE EXCEPTION 'POST-STATE FAIL: scoreable neo cards=% expected 7', n; END IF;
  SELECT count(*) INTO n FROM reward_programs
    WHERE id IN ('united-mileageplus','asia-miles') AND default_cents_per_point = 0;
  IF n <> 0 THEN RAISE EXCEPTION 'POST-STATE FAIL: a placeholder 0 survived'; END IF;
END $$;

COMMIT;

-- POST-APPLY LIVE PROBE (recommend-cards-stateless-v1, $100, 2026-08-16):
--   grocery                 Cathay 150c (1.5c/$)   United 120c (1.2c/$)
--   foreign_currency_spend  Cathay 300c (3c/$)     United 120c (1.2c/$)
-- Cathay base 1 mile x 1.5c and United base 0.75 x 1.6c both price exactly as intended.
