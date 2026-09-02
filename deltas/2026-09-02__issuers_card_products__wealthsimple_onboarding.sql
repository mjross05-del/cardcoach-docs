-- DELTA 2026-09-02 — Wealthsimple onboarding, part 1 of 2 (issuer + card_products + verify.issuer_notes seed)
-- STATUS: APPLIED to production 2026-09-02 via MCP execute_sql, in the guarded transaction below.
-- Authority: PROJECT_RULES rule 9 (direct write), conditions (a) snapshot (b) delta file (d) guards (f) re-read live state.
-- Snapshots taken first, in the `snapshots` schema (rule 9(a) as tightened 2026-09-02), RLS-secured:
--   snapshots.issuers_snapshot_20260902_wealthsimple
--   snapshots.card_products_snapshot_20260902_wealthsimple
--   snapshots.earn_rates_snapshot_20260902_wealthsimple
--
-- SOURCING — read 2026-09-02 from the cloud fetcher (plain HTTP; wealthsimple.com product page,
-- help.wealthsimple.com articles, and the legal PDFs on www.cdn.wealthsimple.com all served full content).
-- Tier 1 (legal / disclosure):
--   [D1] Disclosure Statement (Information Summary Box) CHA-080426-WS — covers "Wealthsimple Visa Infinite*",
--        "Wealthsimple Visa Infinite +*" and "Wealthsimple Visa Infinite Privilege*"
--        https://www.wealthsimple.com/en-ca/credit-card/cardholder-agreement
--        -> 302 https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA080426.pdf
--        Annual Fees, verbatim: "$240* charged monthly at $20/month, also referred to as the "maintenance fee"
--          *The amortized fee will be charged when the Card is issued (regardless of activation) and will be billed to
--          your first Statement and once a month thereafter. For residents of Quebec: $240 charged annually when the
--          Card is issued (regardless of activation). Fee waivers may apply. See Additional Credit Card Terms & Conditions"
--        FX, verbatim: "Foreign Currency Conversion Fee 0.00% We do not charge any additional foreign currency conversion mark-up."
--        Supplementary Card Fee: "$120 per card charged annually to the Primary Borrower's Account" (no schema home; noted)
--        Interest: purchases 20.99%, cash advances 22.99% (not modelled)
--   [D2] Disclosure Statement (Information Summary Box) CHA-041026-WS1 — the "Wealthsimple Visa Infinite* 1%" card
--        https://www.wealthsimple.com/en-ca/credit-card/cardholder-agreement-core
--        -> 302 https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA041026.pdf
--        Annual Fees, verbatim: "No Annual Fees"
--        FX, verbatim: "Foreign Currency Conversion Fee 2.5%" / "you will be charged a currency conversion fee equal to 2.5%
--          for each transaction made in foreign currency."
--        Interest: 23.99% purchases and cash advances (not modelled)
--   [T1] Additional Credit Card Terms & Conditions ACCTC-080426-WS, "Last updated: August 4, 2026"
--        https://www.wealthsimple.com/en-ca/credit-card/rewards-terms-conditions
--        -> 302 https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf
--        Earn rate, verbatim: "2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit
--          cards and 1% for the Wealthsimple Visa Infinite 1% credit card"
--        Qualified Spend, verbatim: "purchases, excluding cash-like transactions, refunds, any applicable fees and adjustments
--          charged to the primary borrower or supplementary cardholder"
--        Cap: ABSENT (no maximum stated). Fee waiver conditions: "$100,000 in individual net deposits or assets under
--          management" or "directly direct deposited at least $4,000 into the Chequing Account linked to their Spend Card".
--   [L1] Legal Disclaimers https://www.wealthsimple.com/en-ca/legal/legal-disclaimers — names all four products:
--        "The Wealthsimple Visa Infinite* 1%, Visa Infinite* 2%, Visa Infinite +*, and Visa Infinite Privilege* credit cards
--        (each, the "Card") are issued under license by Wealthsimple Payments Inc."
-- Tier 1b (issuer product / help pages):
--   [P1] https://www.wealthsimple.com/en-ca/credit-card — "2% on everything"; FX "0%" / "With us, it's always zero";
--        FAQ "$20 monthly if you have under $100,000 in individual assets" (Quebec: charged annually); direct-deposit waiver
--        "$4,000 or more per month"; Privilege: "Right now, the card is only available in limited quantities.";
--        "The 2% does not apply to cash-like transactions, refunds, or any applicable fees and adjustments.";
--        boosted partners "only applies when you shop through our app"; issuer line "issued under license by Wealthsimple Payments Inc."
--   [P2] https://www.wealthsimple.com/en-ca/wealthsimple-visa-infinite-card — Visa Infinite +: "$240 annually ($20/mo)", FX "0%",
--        "Earn 2% cash back on everything—no categories, no caps"; welcome "up to 5% back for your first 30 days" (parked)
--   [H1] https://help.wealthsimple.com/hc/en-ca/articles/31614256039835-Apply-for-a-Wealthsimple-credit-card — three cards
--        offered: "Visa Infinite 1% (beta)" ("We're inviting select clients to take part in the new 1% cash back Visa Infinite*
--        credit card beta release."; "free and incurs no monthly or yearly fees"), "Visa Infinite +" and "Visa Infinite
--        Privilege" ("$20 each month ($240 annually for Quebec residents)"); income/asset/spend thresholds per card.
--   [H2] https://help.wealthsimple.com/hc/en-ca/articles/49651670859675-Wealthsimple-Visa-Infinite-credit-card-benefits-for-cardholders-before-April-28-2026
--        — the original card: "This article is for clients who were approved for the Wealthsimple Visa Infinite* credit card
--        before April 28, 2026."; "you can keep using it as usual"; "unlimited 2% cash back on eligible purchases".
--   [H3] https://help.wealthsimple.com/hc/en-ca/articles/41441164389915-Credit-card-benefits-offered-through-Wealthsimple
--        — no-FX on the 1% card is "Available as a selectable benefit"; included by default on + / Privilege.
--   [H4] https://help.wealthsimple.com/hc/en-ca/articles/37750003281563-Earn-cash-back-with-your-credit-card
--        — "unlimited 2% cash back on all purchases"; cash-like transaction list.
--
-- SCOPE NOTES
--  * FOUR card_products rows, one per product Wealthsimple names in [L1]. Visa Infinite + and Visa Infinite Privilege are
--    the two openly offered cards; Visa Infinite 1% is an invite-only beta (application_status='invitation_only');
--    Visa Infinite 2% is the original card, closed to new applicants since 2026-04-28 but still held (application_status=
--    'closed', is_active=true, scoreable — the 8 closed cards already in the catalogue set the precedent; an in-wallet
--    optimizer must score the cards people actually hold).
--  * All four are flat-rate cash back on the shared 'cashback' reward_program (Rogers/Tangerine/BMO/Neo precedent).
--    No category rows, no caps ([T1] states none; [P2] "no categories, no caps"). No card_exclusions rows: the exclusions
--    are transaction-class (cash-like, refunds, fees), not category-level, and there is no category to hang them on.
--  * annual_fee_cad stores the STICKER fee ($240) on the three 2% cards. The standing waiver ($100,000+ assets or $4,000+/mo
--    direct deposit) is a per-client condition with no schema home; recorded in source_metadata.verify. Same posture as
--    every other conditional-waiver card in the catalogue.
--  * fx_fee_percent: 0.00 on the three 2% cards ([D1] + [P1], dual-confirmed); 2.50 on the 1% card ([D2]; [H3] corroborates
--    that no-FX is only a selectable benefit there). The engine has no per-user benefit selection, so the disclosed default
--    is stored and the selectable waiver is a [VERIFY] note.
--  * In-app "boosted" partner cash back and the "up to 5% for 30 days" welcome offer are EXCLUDED from earn_rates
--    (merchant-funded / welcome-class; Neo 2026-08-16 partner-cashback precedent; rule 7). Parked in source_metadata.
--  * Wealthsimple's prepaid Mastercard (the "Cash" card) is a prepaid product, out of catalogue scope — not loaded.
--  * Evidence capture: onboarded from cloud fetches without sha256 evidence rows; the first Wealthsimple verification
--    batch must capture [D1] [D2] [T1] as verify.evidence artifacts. Tracked [VERIFY].

BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM issuers;
  IF n <> 16 THEN RAISE EXCEPTION 'PRE-STATE FAIL: issuers=% expected 16', n; END IF;
  SELECT count(*) INTO n FROM issuers WHERE id = 'wealthsimple';
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: wealthsimple already exists'; END IF;
  SELECT count(*) INTO n FROM card_products;
  IF n <> 149 THEN RAISE EXCEPTION 'PRE-STATE FAIL: card_products=% expected 149', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE id LIKE 'ca_wealthsimple_%';
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: wealthsimple card_products already present'; END IF;
  SELECT count(*) INTO n FROM verify.issuer_notes WHERE lower(issuer) = 'wealthsimple';
  IF n <> 0 THEN RAISE EXCEPTION 'PRE-STATE FAIL: verify.issuer_notes row already present'; END IF;
END $$;

INSERT INTO issuers (id, display_name) VALUES ('wealthsimple', 'Wealthsimple');
-- Issuer of record ([L1], [P1]): "issued under license by Wealthsimple Payments Inc." Network: Visa.

INSERT INTO card_products
  (id, display_name, issuer_id, network_id, reward_program_id, point_program_id, is_active,
   product_family, tier_normalized, tier_raw, application_status, availability_scope, available_provinces,
   earn_unit_default, base_earn, base_rate_unit, annual_fee_cad, fx_fee_percent, scoring_status, billing_currency,
   source_metadata)
VALUES
-- 1. Visa Infinite + : the mainline card, open to applications.
('ca_wealthsimple_plus_visa_infinite_visa', 'Wealthsimple Visa Infinite +', 'wealthsimple', 'visa', 'cashback', NULL, true,
 'Wealthsimple Visa Infinite', 'visa_infinite', 'Visa Infinite', 'open', 'national', '{}',
 'cents', 2.0000, 'cents_per_dollar', 240.00, 0.00, 'scoreable', 'CAD',
 $j${"onboarded":"2026-09-02 (delta 2026-09-02__issuers_card_products__wealthsimple_onboarding.sql)",
  "sources":[
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA080426.pdf","source_type":"issuer_disclosure_statement","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"CHA-080426-WS Information Summary Box: Annual Fees \"$240* charged monthly at $20/month\" (Quebec \"$240 charged annually\"); \"Foreign Currency Conversion Fee 0.00%\""},
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf","source_type":"issuer_rewards_terms","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"ACCTC-080426-WS (last updated August 4, 2026): \"2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards\"; no cap stated"},
   {"source_url":"https://www.wealthsimple.com/en-ca/wealthsimple-visa-infinite-card","source_type":"issuer_product_page","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"\"$240 annually ($20/mo)\"; FX \"0%\"; \"Earn 2% cash back on everything—no categories, no caps\"; eligibility \"personal income of at least $80,000 or household income of at least $150,000\""},
   {"source_url":"https://www.wealthsimple.com/en-ca/credit-card","source_type":"issuer_product_page","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"\"2% on everything\"; FAQ \"$20 monthly if you have under $100,000 in individual assets\"; \"issued under license by Wealthsimple Payments Inc.\""}
  ],
  "verify":{
   "annual_fee_cad":"Sticker $240/yr ($20/mo maintenance fee; Quebec billed $240 annually) per CHA-080426-WS. STANDING WAIVER not modelled (no schema home): waived with $100,000+ individual net deposits/assets at Wealthsimple or $4,000+/month direct deposit into a Wealthsimple chequing account (ACCTC-080426-WS; product page FAQ).",
   "fx_fee_percent":"0.00 dual-confirmed: CHA-080426-WS \"We do not charge any additional foreign currency conversion mark-up.\" + product page \"With us, it's always zero\".",
   "supplementary_card_fee":"$120 per card per year (CHA-080426-WS). No schema home; noted only.",
   "welcome_parked":"\"up to 5% back for your first 30 days\" on the Visa Infinite + page (T&Cs apply) — welcome-class, parked, not modelled.",
   "boosted_cashback_parked":"In-app boosted cash back at named partners (Walmart, Chewy, Audible, Hotels.com, Gap, Aesop, Sonos, Patagonia, Dyson — \"only applies when you shop through our app\") is merchant-funded with no published per-purchase rate. Excluded from earn_rates (Neo 2026-08-16 partner-cashback precedent, rule 7).",
   "eligibility":"Active Wealthsimple chequing account required; personal income $80,000+ or household $150,000+ (or $300,000+ savings/investments, or $25,000+ annual card spend) per help centre article 31614256039835.",
   "evidence_capture":"[VERIFY] Onboarded 2026-09-02 from cloud fetches without sha256 evidence rows; first Wealthsimple batch must capture CHA-080426-WS, CHA-041026-WS1 and ACCTC-080426-WS as verify.evidence artifacts and grep-guard the quoted clauses."
  }}$j$::jsonb),

-- 2. Visa Infinite Privilege : same rate sheet and fee box; "limited quantities" on the product page.
('ca_wealthsimple_privilege_visa_infinite_privilege_visa', 'Wealthsimple Visa Infinite Privilege', 'wealthsimple', 'visa', 'cashback', NULL, true,
 'Wealthsimple Visa Infinite', 'visa_infinite_privilege', 'Visa Infinite Privilege', 'limited', 'national', '{}',
 'cents', 2.0000, 'cents_per_dollar', 240.00, 0.00, 'scoreable', 'CAD',
 $j${"onboarded":"2026-09-02 (delta 2026-09-02__issuers_card_products__wealthsimple_onboarding.sql)",
  "sources":[
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA080426.pdf","source_type":"issuer_disclosure_statement","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"CHA-080426-WS Information Summary Box (covers Visa Infinite Privilege*): Annual Fees \"$240* charged monthly at $20/month\"; \"Foreign Currency Conversion Fee 0.00%\""},
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf","source_type":"issuer_rewards_terms","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"ACCTC-080426-WS: \"2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards\"; no cap stated"},
   {"source_url":"https://www.wealthsimple.com/en-ca/credit-card","source_type":"issuer_product_page","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"\"2% on everything\"; \"Right now, the card is only available in limited quantities.\"; eligibility \"Personal income of at least $150,000 or household income of at least $200,000. Or ... minimum annual spend of $50,000, or hold at least $400,000 in assets with us.\""},
   {"source_url":"https://help.wealthsimple.com/hc/en-ca/articles/44069610862363-Upgrade-your-credit-card-to-Visa-Infinite-Privilege","source_type":"issuer_help_centre","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"\"$240 (charged $20/month, or annually for Quebec residents)\"; upgrade from Visa Infinite + after 90 days"}
  ],
  "verify":{
   "application_status":"'limited' per product page \"Right now, the card is only available in limited quantities.\" — re-check each batch; flip to 'open' when the sentence disappears.",
   "annual_fee_cad":"Sticker $240/yr ($20/mo; Quebec billed annually) per CHA-080426-WS. STANDING WAIVER not modelled: $100,000+ individual assets or $4,000+/month direct deposit.",
   "fx_fee_percent":"0.00 dual-confirmed (CHA-080426-WS + product page).",
   "boosted_cashback_parked":"In-app boosted partner cash back excluded from earn_rates (merchant-funded, no published per-purchase rate; rule 7).",
   "evidence_capture":"[VERIFY] first batch must capture the three legal documents as verify.evidence artifacts."
  }}$j$::jsonb),

-- 3. Visa Infinite 1% : invite-only beta, no fee, 2.5% FX by default.
('ca_wealthsimple_1pct_visa_infinite_visa', 'Wealthsimple Visa Infinite 1%', 'wealthsimple', 'visa', 'cashback', NULL, true,
 'Wealthsimple Visa Infinite', 'visa_infinite', 'Visa Infinite', 'invitation_only', 'national', '{}',
 'cents', 1.0000, 'cents_per_dollar', 0.00, 2.50, 'scoreable', 'CAD',
 $j${"onboarded":"2026-09-02 (delta 2026-09-02__issuers_card_products__wealthsimple_onboarding.sql)",
  "sources":[
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA041026.pdf","source_type":"issuer_disclosure_statement","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"CHA-041026-WS1 Information Summary Box: Annual Fees \"No Annual Fees\"; \"Foreign Currency Conversion Fee 2.5%\" / \"you will be charged a currency conversion fee equal to 2.5% for each transaction made in foreign currency.\""},
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf","source_type":"issuer_rewards_terms","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"ACCTC-080426-WS: \"1% for the Wealthsimple Visa Infinite 1% credit card\"; no cap stated"},
   {"source_url":"https://help.wealthsimple.com/hc/en-ca/articles/31614256039835-Apply-for-a-Wealthsimple-credit-card","source_type":"issuer_help_centre","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"\"Visa Infinite 1% (beta)\" — \"We're inviting select clients to take part in the new 1% cash back Visa Infinite* credit card beta release.\"; \"free and incurs no monthly or yearly fees\"; \"1% unlimited cash back rate\""},
   {"source_url":"https://help.wealthsimple.com/hc/en-ca/articles/41441164389915-Credit-card-benefits-offered-through-Wealthsimple","source_type":"issuer_help_centre","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"No-FX-fee on the 1% card: \"Available as a selectable benefit\""}
  ],
  "verify":{
   "application_status":"'invitation_only' — beta by invitation (help centre 31614256039835). Re-check each batch; flip to 'open' when the beta language goes.",
   "annual_fee_cad":"0 dual-confirmed: CHA-041026-WS1 \"No Annual Fees\" + help centre \"free and incurs no monthly or yearly fees\".",
   "fx_fee_percent":"2.50 per CHA-041026-WS1 (single Tier-1 document; help centre 41441164389915 corroborates that no-FX is only a selectable benefit on this card). [VERIFY] The no-FX benefit is user-selectable and the engine has no per-user benefit switch, so the disclosed default is stored; a holder who selected it pays 0% and the model over-charges FX for them.",
   "evidence_capture":"[VERIFY] first batch must capture CHA-041026-WS1 and ACCTC-080426-WS as verify.evidence artifacts."
  }}$j$::jsonb),

-- 4. Visa Infinite 2% : the original card. Closed to new applicants 2026-04-28; existing holders keep it ([H2]).
('ca_wealthsimple_2pct_visa_infinite_visa', 'Wealthsimple Visa Infinite 2%', 'wealthsimple', 'visa', 'cashback', NULL, true,
 'Wealthsimple Visa Infinite', 'visa_infinite', 'Visa Infinite', 'closed', 'national', '{}',
 'cents', 2.0000, 'cents_per_dollar', 240.00, 0.00, 'scoreable', 'CAD',
 $j${"onboarded":"2026-09-02 (delta 2026-09-02__issuers_card_products__wealthsimple_onboarding.sql)",
  "sources":[
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA080426.pdf","source_type":"issuer_disclosure_statement","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"CHA-080426-WS Information Summary Box (covers \"Wealthsimple Visa Infinite*\"): Annual Fees \"$240* charged monthly at $20/month\"; \"Foreign Currency Conversion Fee 0.00%\""},
   {"source_url":"https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf","source_type":"issuer_rewards_terms","source_language":"en","canada_evidence_type":"issuer_legal_document","source_date_accessed":"2026-09-02","source_clause_reference":"ACCTC-080426-WS: \"2% for the Wealthsimple Visa Infinite 2%, Visa Infinite +, and Visa Infinite Privilege credit cards\"; no cap stated"},
   {"source_url":"https://help.wealthsimple.com/hc/en-ca/articles/49651670859675-Wealthsimple-Visa-Infinite-credit-card-benefits-for-cardholders-before-April-28-2026","source_type":"issuer_help_centre","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"\"This article is for clients who were approved for the Wealthsimple Visa Infinite* credit card before April 28, 2026.\"; \"you can keep using it as usual\"; \"unlimited 2% cash back on eligible purchases\""},
   {"source_url":"https://www.wealthsimple.com/en-ca/legal/legal-disclaimers","source_type":"issuer_legal_page","source_language":"en","canada_evidence_type":"issuer_page","source_date_accessed":"2026-09-02","source_clause_reference":"Names the product \"Visa Infinite* 2%\"; \"issued under license by Wealthsimple Payments Inc.\""}
  ],
  "verify":{
   "application_status":"'closed' — no new applications since 2026-04-28 (help centre 49651670859675); existing cardholders keep the card, so it stays is_active and scoreable for in-wallet scoring. Naming follows Wealthsimple's own legal name for the product (\"Visa Infinite 2%\").",
   "annual_fee_cad":"Sticker $240/yr ($20/mo; Quebec billed annually) per CHA-080426-WS, which covers \"Wealthsimple Visa Infinite*\" alongside + and Privilege. STANDING WAIVER not modelled: $100,000+ with Wealthsimple or a qualifying paycheque (help centre 49651670859675). [VERIFY] whether grandfathered holders sit on a different fee schedule — the pre-April-28 article states the waiver but not the amount.",
   "fx_fee_percent":"0.00 per CHA-080426-WS.",
   "evidence_capture":"[VERIFY] first batch must capture CHA-080426-WS and ACCTC-080426-WS as verify.evidence artifacts."
  }}$j$::jsonb);

-- verify.issuer_notes seed — keyed by the ISSUER_BATCH display token (CamelCase convention; unique on lower(issuer)).
INSERT INTO verify.issuer_notes (issuer, nav_path, lineup_url_hint, wall_status, preferred_channels, doc_locations, quirks, updated_at)
VALUES ('Wealthsimple',
 'wealthsimple.com -> /en-ca/credit-card (marketing page: Visa Infinite + and Visa Infinite Privilege only). The AUTHORITATIVE product list is the legal disclaimers page and the credit-card agreements index, which name FOUR products (Visa Infinite 1%, Visa Infinite 2%, Visa Infinite +, Visa Infinite Privilege). Legal index: /en-ca/legal/credit-card-agreements -> each link 302s to a PDF on www.cdn.wealthsimple.com. Help centre (help.wealthsimple.com, Zendesk) carries the per-card fee, eligibility and beta/closed status.',
 'https://www.wealthsimple.com/en-ca/legal/credit-card-agreements',
 'open',
 ARRAY['http_pdf','browser_render'],
 $j${
  "product_page":"https://www.wealthsimple.com/en-ca/credit-card (2% hero, FAQ with $20/mo fee, $4,000 direct-deposit waiver, Privilege limited-quantities line)",
  "product_page_plus":"https://www.wealthsimple.com/en-ca/wealthsimple-visa-infinite-card (Visa Infinite +: $240 annually ($20/mo), FX 0%, welcome up to 5% for 30 days — parked)",
  "legal_index":"https://www.wealthsimple.com/en-ca/legal/credit-card-agreements (two groups: [Visa Infinite 2% / + / Privilege] and [Visa Infinite 1%])",
  "disclosure_2pct_family":"https://www.wealthsimple.com/en-ca/credit-card/cardholder-agreement -> https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA080426.pdf (CHA-080426-WS: $240/yr at $20/mo, QC annual, FX 0.00%, supplementary $120, 20.99%/22.99%)",
  "disclosure_1pct":"https://www.wealthsimple.com/en-ca/credit-card/cardholder-agreement-core -> https://www.cdn.wealthsimple.com/en-ca/pdfs/Disclosure-Statement-and-Visa-Credit-Account-Agreement-CHA041026.pdf (CHA-041026-WS1: No Annual Fees, FX 2.5%, 23.99%)",
  "rewards_terms":"https://www.wealthsimple.com/en-ca/credit-card/rewards-terms-conditions -> https://www.cdn.wealthsimple.com/en-ca/pdfs/Additional-Credit-Card-Terms-Conditions-ACCTC-080426-WS.pdf (ACCTC-080426-WS, last updated August 4, 2026: 2% / 1% earn clause, Qualified Spend definition, waiver conditions)",
  "legal_disclaimers":"https://www.wealthsimple.com/en-ca/legal/legal-disclaimers (names all four products; issuer Wealthsimple Payments Inc.)",
  "merchant_cashback_terms":"https://www.wealthsimple.com/en-ca/legal/merchant-cashback-terms (redemption of earned cash back for goods — not an earn rate)",
  "help_apply":"https://help.wealthsimple.com/hc/en-ca/articles/31614256039835-Apply-for-a-Wealthsimple-credit-card (three cards offered; 1% is invite-only beta; income/asset/spend thresholds; $20/mo fee)",
  "help_legacy_visa_infinite":"https://help.wealthsimple.com/hc/en-ca/articles/49651670859675-Wealthsimple-Visa-Infinite-credit-card-benefits-for-cardholders-before-April-28-2026 (original card closed 2026-04-28, holders keep it)",
  "help_benefits":"https://help.wealthsimple.com/hc/en-ca/articles/41441164389915-Credit-card-benefits-offered-through-Wealthsimple (no-FX is a selectable benefit on the 1% card)",
  "help_earn":"https://help.wealthsimple.com/hc/en-ca/articles/37750003281563-Earn-cash-back-with-your-credit-card (unlimited 2%; cash-like exclusion list)"
 }$j$::jsonb,
 'ONBOARDED 2026-09-02 (review lane, cloud fetch, no chrome lane needed). 17th issuer; 4 card_products, all scoreable.

ACCESS: www.wealthsimple.com, help.wealthsimple.com and the PDF host www.cdn.wealthsimple.com all served full content to the cloud fetcher on 2026-09-02 — no bot wall, no JS shell for the product page, plain HTTP is enough. The three legal documents sit behind 302 redirects from wealthsimple.com paths (cardholder-agreement, cardholder-agreement-core, rewards-terms-conditions) to versioned PDF filenames on the CDN; ALWAYS navigate from the legal index rather than guessing a filename, because the version code is in the filename (CHA080426 / CHA041026 / ACCTC-080426-WS) and it moves when the document is reissued. A changed filename is itself a revision signal. NOTE: the Claude-in-Chrome extension refuses wealthsimple.com ("safety restrictions"), so the chrome lane is NOT available for this issuer — the cloud lanes are the only lanes.

PRODUCT STRUCTURE (the thing that will trip a coverage diff): the marketing page /en-ca/credit-card shows only TWO cards (Visa Infinite +, Visa Infinite Privilege). Wealthsimple actually names FOUR on its legal disclaimers page and its agreements index: Visa Infinite 1% (invite-only beta since ~June 2026, free, 1%), Visa Infinite 2% (the original card, closed to new applicants 2026-04-28, held by existing clients), Visa Infinite + (open), Visa Infinite Privilege (limited quantities). A naive lineup count of 2 against 4 DB rows is NOT a closure signal for the 1% and 2% cards — check the help centre articles for their status before proposing anything. The disclosure statement CHA-080426-WS covers Visa Infinite (2%) + Visa Infinite + + Visa Infinite Privilege in one fee box; CHA-041026-WS1 covers the 1% card alone.

FEES: annual_fee_cad on the three 2% cards is the STICKER $240 ($20/mo "maintenance fee"; Quebec billed $240 annually). The standing waiver — $100,000+ individual net deposits/assets under management OR $4,000+/month direct deposit into the linked Wealthsimple chequing account — is a per-client condition with no schema home and is deliberately NOT modelled. Do not propose $0. Supplementary card $120/yr (no column). The 1% card: "No Annual Fees".

FX: 0.00% on the 2% family (CHA-080426-WS: "We do not charge any additional foreign currency conversion mark-up."), 2.5% on the 1% card (CHA-041026-WS1) where no-FX is only a SELECTABLE benefit (help centre 41441164389915) — stored at the disclosed default.

EARN: flat, uncapped cash back — 2% (2% / + / Privilege) and 1% (1% card), ACCTC-080426-WS. Qualified Spend excludes cash-like transactions, refunds, fees and adjustments (transaction-class, no category row). In-app "boosted" partner cash back (Walmart, Chewy, Audible, Hotels.com, Gap, Aesop, Sonos, Patagonia, Dyson) is merchant-funded with no published per-purchase rate — EXCLUDED from earn_rates by the Neo partner-cashback precedent; do not file fact_checks against it. Welcome offer on the + page ("up to 5% back for your first 30 days") is welcome-class — parking only.

STATUS FACTS TO RE-CHECK EVERY RUN: (1) Privilege "Right now, the card is only available in limited quantities." on /en-ca/credit-card -> application_status=limited; flip to open when the sentence goes. (2) 1% card beta/invite language in help centre 31614256039835 -> application_status=invitation_only. (3) 2% card remains closed (help centre 49651670859675).

OPEN [VERIFY] ITEMS carried out of onboarding:
 1. EVIDENCE CAPTURE — onboarded from cloud fetches; no sha256 evidence rows yet. First run must capture CHA-080426-WS, CHA-041026-WS1 and ACCTC-080426-WS as verify.evidence artifacts and grep-guard the quoted clauses.
 2. LEGACY 2% FEE — the pre-April-28 help article states the waiver but not the amount; the DB carries the CHA-080426-WS $240 which names "Wealthsimple Visa Infinite*". Confirm grandfathered holders are on that box.
 3. 1% CARD FX — the selectable no-FX benefit cannot be modelled per user; disclosed default 2.5% stored.
 4. WEALTHSIMPLE PREPAID MASTERCARD ("Cash" card) — prepaid, out of catalogue scope; not loaded. Do not flag as a missing card.',
 now());

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM issuers;
  IF n <> 17 THEN RAISE EXCEPTION 'POST-STATE FAIL: issuers=% expected 17', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='wealthsimple';
  IF n <> 4 THEN RAISE EXCEPTION 'POST-STATE FAIL: wealthsimple cards=% expected 4', n; END IF;
  SELECT count(*) INTO n FROM card_products;
  IF n <> 153 THEN RAISE EXCEPTION 'POST-STATE FAIL: card_products=% expected 153', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='wealthsimple' AND network_id='visa' AND reward_program_id='cashback' AND earn_unit_default='cents' AND base_rate_unit='cents_per_dollar' AND billing_currency='CAD';
  IF n <> 4 THEN RAISE EXCEPTION 'POST-STATE FAIL: wealthsimple taxonomy columns wrong on % rows', 4-n; END IF;
  SELECT count(*) INTO n FROM verify.issuer_notes WHERE issuer='Wealthsimple';
  IF n <> 1 THEN RAISE EXCEPTION 'POST-STATE FAIL: issuer_notes seed missing'; END IF;
END $$;

COMMIT;

-- ROLLBACK (if ever needed):
--   DELETE FROM earn_rates WHERE card_id IN (SELECT id FROM card_products WHERE issuer_id='wealthsimple');
--   DELETE FROM card_products WHERE issuer_id='wealthsimple';
--   DELETE FROM verify.issuer_notes WHERE issuer='Wealthsimple';
--   DELETE FROM issuers WHERE id='wealthsimple';
-- Snapshots for a full restore: snapshots.issuers_snapshot_20260902_wealthsimple,
--   snapshots.card_products_snapshot_20260902_wealthsimple, snapshots.earn_rates_snapshot_20260902_wealthsimple.
