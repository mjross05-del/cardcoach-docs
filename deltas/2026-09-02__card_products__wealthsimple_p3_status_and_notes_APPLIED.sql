-- DELTA 2026-09-02 — Wealthsimple onboarding, part 3 of 3 (status correction + issuer_notes addendum)
-- STATUS: APPLIED to production 2026-09-02 via MCP execute_sql, exactly as written below (after a first attempt
--         failed at PL/pgSQL compile time on an unescaped '%' in a RAISE string — nothing was applied by that attempt).
-- Depends on: 2026-09-02__issuers_card_products__wealthsimple_onboarding.sql
-- Snapshot (rule 9(a), in place for the unexposed verify schema): verify.issuer_notes_snapshot_20260902_wealthsimple,
--   RLS on, grants revoked. card_products was snapshotted at the start of this session
--   (snapshots.card_products_snapshot_20260902_wealthsimple) — first write of the session, per the rule.
--
-- WHY. An independent second read of all ten Wealthsimple sources (subagent, WebFetch only, fresh prompts) confirmed
-- every money fact in parts 1 and 2 and surfaced two things the first pass under-read:
--   1. The product-page FAQ sentence "Right now, the card is only available in limited quantities so even if you meet
--      these requirements, you might not get one." sits in the answer to "Can anyone apply for the Wealthsimple credit
--      card?", which matches applicants "to either a Visa Infinite + card or a Visa Infinite Privilege card". It covers
--      the programme — both cards — not Privilege alone. Visa Infinite + therefore moves open -> limited.
--   2. No page literally says the original Visa Infinite (2%) is "closed to new applications". The closure is inferred
--      (help centre offers only +, Privilege and the 1% beta; calls the original "our previous Visa Infinite card";
--      scopes its article to approvals before 2026-04-28). application_status stays 'closed'; the note now says so.
-- Everything else learned (Quebec first-year $220 promo, first-month fee waiver, household-waiver grandfathering,
-- 1% card virtual-only during beta, the 1% disclosure never naming "1%", the help-centre FX sentence that conflicts
-- with the 1% disclosure — disclosure governs) goes into verify.issuer_notes.quirks for the batches. None of it changes
-- a stored fact.

BEGIN;
CREATE TABLE verify.issuer_notes_snapshot_20260902_wealthsimple AS SELECT *, now() AS snapshot_taken_at FROM verify.issuer_notes;
ALTER TABLE verify.issuer_notes_snapshot_20260902_wealthsimple ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON verify.issuer_notes_snapshot_20260902_wealthsimple FROM anon, authenticated;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM card_products WHERE id='ca_wealthsimple_plus_visa_infinite_visa' AND application_status='open';
  IF n <> 1 THEN RAISE EXCEPTION 'PRE-STATE FAIL: Visa Infinite + not open (n=%)', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE id='ca_wealthsimple_2pct_visa_infinite_visa' AND application_status='closed';
  IF n <> 1 THEN RAISE EXCEPTION 'PRE-STATE FAIL: Visa Infinite 2%% not closed (n=%)', n; END IF;
  SELECT count(*) INTO n FROM verify.issuer_notes WHERE issuer='Wealthsimple';
  IF n <> 1 THEN RAISE EXCEPTION 'PRE-STATE FAIL: issuer_notes row missing'; END IF;
END $$;

UPDATE card_products
SET application_status = 'limited',
    source_metadata = jsonb_set(source_metadata, '{verify,application_status}',
      to_jsonb('''limited'' (corrected 2026-09-02 from ''open'' after an independent re-read): the product page FAQ "Can anyone apply for the Wealthsimple credit card?" says applicants are matched "to either a Visa Infinite + card or a Visa Infinite Privilege card" and ends "Right now, the card is only available in limited quantities so even if you meet these requirements, you might not get one." — the sentence covers the programme, i.e. both cards, not Privilege alone. Re-check each batch; flip to ''open'' when the sentence disappears.'::text))
WHERE id='ca_wealthsimple_plus_visa_infinite_visa';

UPDATE card_products
SET source_metadata = jsonb_set(source_metadata, '{verify,application_status}',
      to_jsonb('''closed'' — INFERRED, not a literal sentence: help centre 31614256039835 offers only Visa Infinite +, Visa Infinite Privilege and the 1% beta and calls this card "our previous Visa Infinite card"; article 49651670859675 is scoped to clients "approved for the Wealthsimple Visa Infinite* credit card before April 28, 2026" and says "you can keep using it as usual" and "we don''t have the ability to upgrade from Visa Infinite to Visa Infinite +". Existing cardholders keep the card, so it stays is_active and scoreable for in-wallet scoring. Naming follows Wealthsimple''s own legal name for the product ("Visa Infinite 2%").'::text))
WHERE id='ca_wealthsimple_2pct_visa_infinite_visa';

UPDATE verify.issuer_notes
SET quirks = quirks || E'\n\n=== INDEPENDENT RE-READ 2026-09-02 (second pass, all ten sources) — CONFIRMED every money fact; nuances to carry ===\n1. "LIMITED QUANTITIES" COVERS BOTH + AND PRIVILEGE. The product-page FAQ answer that carries the sentence matches applicants "to either a Visa Infinite + card or a Visa Infinite Privilege card" and then says "the card is only available in limited quantities". Visa Infinite + was corrected open -> limited on this basis. Do not read it as Privilege-only.\n2. THE 1% DISCLOSURE (CHA-041026-WS1) NEVER SAYS "1%". It identifies the card only as "Wealthsimple Visa Infinite* credit card"; the mapping to the 1% product rests on the agreements index (which files it under "Wealthsimple Visa Infinite* 1% Credit Card") and the redirect slug cardholder-agreement-core (insurance certificate "certificate-of-insurance-chubb-core"). Cite the index + slug when grep-guarding, not the PDF body.\n3. PROMOS, PARKING ONLY: "The Card Fee is automatically waived for all clients for the first month when the Card is issued." (ACCTC) and, for Quebec, a "Quebec Fee Waiver Offer" under which "the first year''s Annual Fee is reduced to $220". Year-one effective cost is therefore $220 everywhere; the STICKER stays $240 (disclosure box). Do not propose $220 as the fee.\n4. HOUSEHOLD WAIVER GRANDFATHERED: "As of April 28, 2026, being part of a Premium or Generation household no longer automatically waives the $20/month credit card fee" and "If you were receiving a household-based fee waiver before April 28, 2026, we''re honouring your fee waiver until further notice." The + page FAQ still carries the old Premium/Generation wording — stale marketing copy, not a fact change.\n5. 1% CARD: "virtual-only card during the beta"; "We don''t have a waitlist for this card"; rolled out "in phases". Interest 23.99%/23.99% (vs 20.99%/22.99% on the 2% family). Eligibility: $60k personal / $100k household / $250k assets / $15k spend.\n6. FX CONFLICT ON THE 1% CARD, RULED: the help centre "Apply" FAQ says generically "Wealthsimple doesn''t charge FX fees" with no 1% carve-out, while CHA-041026-WS1 charges 2.5% and the benefits article (dated 2026-09-02) says no-FX is "Available as a selectable benefit*" on the 1% card, with "Visa Infinite 1% cardholders who opt into no FX fees will see the fee reversal in their transaction summary." The disclosure governs: 2.5% stays.\n7. SUPPLEMENTARY CARDS: $120/yr each, "limited to requesting two (2) supplementary cards" (2% family only; no such row on the 1% disclosure).\n8. Earn clause is prefixed "The earn rate, which may be subject to change, is 2% ..." and the T&Cs never say "unlimited"/"no cap" — the no-cap fact rests on the product/help pages ("no categories, no cap"; "2% unlimited cash back rate"). Fine as Tier 1b, but a cap could appear in a future ACCTC revision — grep for "maximum" and "cap" on every run.\n9. STATUS OF THE 2% CARD IS INFERRED: no page says "closed to new applications"; the closure rests on the help centre offering only +, Privilege and the 1% beta, calling the original "our previous Visa Infinite card", and scoping its article to approvals before 2026-04-28. If a page ever offers it again, flip to open.',
    updated_at = now()
WHERE issuer='Wealthsimple';

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='wealthsimple' AND application_status='limited';
  IF n <> 2 THEN RAISE EXCEPTION 'POST-STATE FAIL: limited=% expected 2', n; END IF;
  SELECT count(*) INTO n FROM card_products WHERE issuer_id='wealthsimple';
  IF n <> 4 THEN RAISE EXCEPTION 'POST-STATE FAIL: ws cards=% expected 4', n; END IF;
  SELECT count(*) INTO n FROM verify.issuer_notes WHERE issuer='Wealthsimple' AND quirks LIKE '%INDEPENDENT RE-READ 2026-09-02%';
  IF n <> 1 THEN RAISE EXCEPTION 'POST-STATE FAIL: issuer_notes addendum missing'; END IF;
END $$;
COMMIT;

-- ROLLBACK (if ever needed):
--   UPDATE card_products SET application_status='open' WHERE id='ca_wealthsimple_plus_visa_infinite_visa';
--   (source_metadata.verify.application_status texts: restore from snapshots.card_products_snapshot_20260902_wealthsimple
--    is NOT possible — that snapshot predates the rows; re-read part 1 of this delta set for the original wording.)
--   UPDATE verify.issuer_notes n SET quirks = s.quirks, updated_at = s.updated_at
--     FROM verify.issuer_notes_snapshot_20260902_wealthsimple s WHERE s.issuer = n.issuer AND n.issuer='Wealthsimple';
