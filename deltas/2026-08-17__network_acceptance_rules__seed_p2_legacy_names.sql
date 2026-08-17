-- deltas/2026-08-17__network_acceptance_rules__seed_p2_legacy_names.sql
--
-- DATA-021 pass 2: entity-scoped rules for merchant rows in the RETIRED
-- normalized-name formats, which no brand pattern can reach.
--
-- STATUS: APPLIED 2026-08-17 to project hrzpznlpmxxrbtwskacu.
-- Depends on: migration 20260817182517_network_acceptance_rules and
--             deltas/2026-08-17__network_acceptance_rules__seed_p1.sql.
--
-- WHY THIS FILE EXISTS
--   Pass 1 seeded brand patterns only, and the post-apply reach sweep found
--   four live merchant_entities rows they cannot touch. All four are in the
--   dead normalizer formats documented in DESIGN_place_resolution_v1.md §1.5 —
--   the same trap that made the 2026-08-02 chain fix match zero Superstore rows:
--
--     Costco Gas            -> costco_gas            (underscore style)
--     No Frills             -> no_frills             (underscore style; a SECOND
--                                                     No Frills row, distinct
--                                                     from the spaces-style one)
--     Wholesale Club        -> wholesale_club        (underscore style)
--     Loblaws Carlton Street-> loblawscarltonstreet  (squashed style)
--
--   A brand pattern cannot reach any of them, and cannot be made to: the
--   `nar_brand_pattern_normalized` CHECK forbids underscores by design, because
--   a pattern in a format the resolver never produces would silently match
--   nothing — which is the exact failure this design set out to avoid. Loosening
--   the CHECK would trade a visible gap for an invisible one.
--
--   So they are fixed the way the model intends: `merchant_entity` scope, keyed
--   by id. This is the layered model working, not a workaround — entity scope
--   exists precisely for stores the brand layer cannot describe.
--
-- NOT A MERCHANT-GRAPH REPAIR
--   These rows are ALSO a data defect (duplicate/legacy entities that split one
--   brand across several ids). Repairing them is merchant-graph DML, which the
--   2026-08-12 "merchant-graph DML is audit-class" decision puts behind gated
--   approval — out of scope here and deliberately untouched. This file only
--   makes acceptance correct WHILE the defect exists. If the graph is later
--   deduped, these rows go stale harmlessly: the entity is deleted, the rule
--   cascades away (ON DELETE CASCADE), and the brand pattern covers the survivor.
--
-- EVIDENCE
--   Identical to pass 1 — same banners, same sources. Confidence mirrors the
--   pass-1 block each banner sat in: high for the named banners (Costco, No
--   Frills, Loblaws), medium for Wholesale Club (block 2, general statement only).
--
-- ROLLBACK
--   delete from public.network_acceptance_rules where note like 'DATA-021 seed p2%';

begin;

do $$
declare n bigint;
begin
  if (select count(*) from public.network_acceptance_rules where note like 'DATA-021 seed p1%') <> 20 then
    raise exception 'PRE-STATE FAIL: expected the 20 pass-1 rows; run seed p1 first.';
  end if;
  select count(*) into n from public.network_acceptance_rules where note like 'DATA-021 seed p2%';
  if n <> 0 then
    raise exception 'PRE-STATE FAIL: pass 2 already applied (% rows). Not idempotent.', n;
  end if;
  if (select enabled from public.runtime_flags where key = 'network_acceptance') then
    raise exception 'PRE-STATE FAIL: network_acceptance is already ON. Seed before enabling.';
  end if;
end $$;

insert into public.network_acceptance_rules
  (scope, merchant_entity_id, network_id, accepts, channel,
   evidence_url, evidence_tier, evidence_quote, verified_at, confidence, note, valid_from)
select
  'merchant_entity', e.id, p.network_id, false, p.channel,
  p.evidence_url, p.evidence_tier, p.evidence_quote,
  date '2026-08-17', p.confidence,
  'DATA-021 seed p2. Entity-scoped because merchant_entities.normalized_name = '''
    || e.normalized_name || ''' is in a RETIRED normalizer format (see '
    || 'DESIGN_place_resolution_v1.md §1.5) that no brand_pattern can match. '
    || 'Same evidence as the pass-1 rule for this banner.',
  date '2026-08-17'
from (values
  -- normalized_name        network   channel     evidence_url, tier, quote, confidence
  ('costco_gas',            'amex',   'in_store',
     'https://www.forbes.com/advisor/ca/credit-cards/what-credit-cards-does-costco-accept/',
     'industry_consensus',
     'American Express is not accepted anywhere at Costco Canada; the partnership expired in December 2014.',
     'high'),
  ('costco_gas',            'visa',   'in_store',
     'https://www.forbes.com/advisor/ca/credit-cards/what-credit-cards-does-costco-accept/',
     'industry_consensus',
     'Mastercard is the only credit card that can be used at Costco warehouse stores.',
     'high'),
  ('no_frills',             'amex',   'any',
     'https://www.loblaws.ca/en/help/payments/why-dont-you-accept-american-express',
     'merchant_published',
     'Loblaw customer-service article: "Why don''t you accept American Express?"',
     'high'),
  ('loblawscarltonstreet',  'amex',   'any',
     'https://www.loblaws.ca/en/help/payments/why-dont-you-accept-american-express',
     'merchant_published',
     'Loblaw customer-service article: "Why don''t you accept American Express?"',
     'high'),
  ('wholesale_club',        'amex',   'any',
     'https://piggybank.ca/credit-cards/where-is-american-express-accepted-in-canada',
     'industry_consensus',
     'Loblaws does not accept American Express and neither do any other Loblaw Companies',
     'medium')
) as p(normalized_name, network_id, channel, evidence_url, evidence_tier, evidence_quote, confidence)
join public.merchant_entities e on e.normalized_name = p.normalized_name;

do $$
declare n bigint;
begin
  select count(*) into n from public.network_acceptance_rules where note like 'DATA-021 seed p2%';
  -- Exactly 5. A LOWER count means a join missed, i.e. one of those legacy rows
  -- has already been renamed or deduped by another session — do not paper over
  -- it, re-run the reach sweep and re-derive the list.
  if n <> 5 then
    raise exception 'POST-STATE FAIL: pass 2 inserted % rows, expected 5. A legacy entity name may have changed — re-run the reach sweep.', n;
  end if;
  if (select count(*) from public.network_acceptance_rules) <> 25 then
    raise exception 'POST-STATE FAIL: expected 25 total rules after p1 + p2.';
  end if;
  raise notice 'DATA-021 seed p2 OK: 5 entity-scoped rules for legacy-format merchant rows.';
end $$;

commit;
