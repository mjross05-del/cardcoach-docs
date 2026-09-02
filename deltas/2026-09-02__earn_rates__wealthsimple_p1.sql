-- DELTA 2026-09-02 — Wealthsimple onboarding, part 2 of 2 (earn_rates)
-- STATUS: APPLIED to production 2026-09-02 via MCP execute_sql, exactly as written below.
-- Depends on: 2026-09-02__issuers_card_products__wealthsimple_onboarding.sql
--
-- SOURCING. One Tier-1 clause carries every rate in this file — Additional Credit Card Terms & Conditions
-- ACCTC-080426-WS ("Last updated: August 4, 2026"), read 2026-09-02:
--   https://www.wealthsimple.com/en-ca/credit-card/rewards-terms-conditions
--   -> https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf
--   Verbatim: "2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards and
--              1% for the Wealthsimple Visa Infinite 1% credit card"
--   Qualified Spend: "purchases, excluding cash-like transactions, refunds, any applicable fees and adjustments charged to
--              the primary borrower or supplementary cardholder"
--   Cap: none stated.
-- Dual confirmation (Tier 1b):
--   https://www.wealthsimple.com/en-ca/credit-card — "2% on everything"; "The 2% does not apply to cash-like transactions,
--              refunds, or any applicable fees and adjustments."
--   https://www.wealthsimple.com/en-ca/wealthsimple-visa-infinite-card — "Earn 2% cash back on everything—no categories, no caps"
--   https://help.wealthsimple.com/hc/en-ca/articles/31614256039835-Apply-for-a-Wealthsimple-credit-card — "1% unlimited
--              cash back rate" (Visa Infinite 1% beta) / "2% unlimited cash back rate" (+ and Privilege)
--   https://help.wealthsimple.com/hc/en-ca/articles/49651670859675-... — "unlimited 2% cash back on eligible purchases" (2% card)
--
-- MODELLING NOTES
--  * Four 'base' rows, one per card. Flat rate, no category rows, no caps, no floors, no window — the simplest shape the
--    engine prices. Effective rate = base_rate * multiplier (project convention): 2 * 1 = 2 cents per dollar.
--  * Exclusions (cash-like transactions, refunds, fees, adjustments) are transaction-class, not category-class, and have
--    no card_exclusions row — the same posture as every other flat cash-back card in the catalogue.
--  * In-app boosted partner cash back and the 30-day welcome offer are deliberately absent (see part 1 scope notes).

BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM earn_rates; IF n <> 732 THEN RAISE EXCEPTION 'PRE-STATE FAIL: earn_rates=% expected 732', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='wealthsimple'; IF n <> 4 THEN RAISE EXCEPTION 'PRE-STATE FAIL: wealthsimple card_products=% expected 4', n; END IF;
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id WHERE cp.issuer_id='wealthsimple';
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: wealthsimple earn_rates already present'; END IF;
END $$;

INSERT INTO earn_rates
  (card_id, basis, category_id, earn_unit, base_rate, multiplier, cap_monthly_cad, cap_annual_cad, valid_from, valid_to,
   condition_type, condition_text, source_clause_reference, rate_unit, earn_rate_type, display_label)
VALUES
('ca_wealthsimple_plus_visa_infinite_visa', 'base', NULL, 'cents', 2, 1, NULL, NULL, '2026-09-02', NULL,
 NULL, NULL,
 'ACCTC-080426-WS: "2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards"; product page: "Earn 2% cash back on everything—no categories, no caps". Qualified Spend excludes cash-like transactions, refunds, fees and adjustments.',
 'cents_per_dollar', 'total', '2% all purchases'),
('ca_wealthsimple_privilege_visa_infinite_privilege_visa', 'base', NULL, 'cents', 2, 1, NULL, NULL, '2026-09-02', NULL,
 NULL, NULL,
 'ACCTC-080426-WS: "2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards"; product page: "2% on everything". Qualified Spend excludes cash-like transactions, refunds, fees and adjustments.',
 'cents_per_dollar', 'total', '2% all purchases'),
('ca_wealthsimple_1pct_visa_infinite_visa', 'base', NULL, 'cents', 1, 1, NULL, NULL, '2026-09-02', NULL,
 NULL, NULL,
 'ACCTC-080426-WS: "1% for the Wealthsimple Visa Infinite 1% credit card"; help centre 31614256039835: "1% unlimited cash back rate". Qualified Spend excludes cash-like transactions, refunds, fees and adjustments.',
 'cents_per_dollar', 'total', '1% all purchases'),
('ca_wealthsimple_2pct_visa_infinite_visa', 'base', NULL, 'cents', 2, 1, NULL, NULL, '2026-09-02', NULL,
 NULL, NULL,
 'ACCTC-080426-WS: "2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards"; help centre 49651670859675: "unlimited 2% cash back on eligible purchases". Qualified Spend excludes cash-like transactions, refunds, fees and adjustments.',
 'cents_per_dollar', 'total', '2% all purchases');

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM earn_rates er JOIN card_products cp ON cp.id=er.card_id WHERE cp.issuer_id='wealthsimple';
  IF n <> 4 THEN RAISE EXCEPTION 'POST-STATE FAIL: wealthsimple earn_rates=% expected 4', n; END IF;
  SELECT count(*) INTO n FROM earn_rates; IF n <> 736 THEN RAISE EXCEPTION 'POST-STATE FAIL: earn_rates=% expected 736', n; END IF;
  SELECT count(*) INTO n FROM card_products cp WHERE cp.issuer_id='wealthsimple' AND cp.scoring_status='scoreable'
    AND NOT EXISTS (SELECT 1 FROM earn_rates er WHERE er.card_id=cp.id AND er.basis='base' AND er.valid_to IS NULL);
  IF n <> 0 THEN RAISE EXCEPTION 'POST-STATE FAIL: % scoreable Wealthsimple cards have no base rate', n; END IF;
  -- base_earn on card_products must agree with the base earn row (engine reads the row; the scalar is the audit copy).
  SELECT count(*) INTO n FROM card_products cp JOIN earn_rates er ON er.card_id=cp.id AND er.basis='base' AND er.valid_to IS NULL
    WHERE cp.issuer_id='wealthsimple' AND cp.base_earn <> er.base_rate * er.multiplier;
  IF n <> 0 THEN RAISE EXCEPTION 'POST-STATE FAIL: base_earn/base row mismatch on % Wealthsimple cards', n; END IF;
END $$;

COMMIT;

-- ROLLBACK (if ever needed):
--   DELETE FROM earn_rates WHERE card_id IN (SELECT id FROM card_products WHERE issuer_id='wealthsimple');
