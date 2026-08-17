-- deltas/2026-08-17__network_acceptance_rules__seed_p1.sql
--
-- DATA-021 pass 1: seed network acceptance rules.
--
-- STATUS: APPLIED 2026-08-17 to project hrzpznlpmxxrbtwskacu, all guards passed
--   (10 + 6 + 4 = 20 rows). Depends on migration
--   supabase/migrations/20260817182517_network_acceptance_rules.sql, applied
--   immediately before it. Block 2 was included — Mike approved the file as
--   written. See the companion pass-2 delta for the entity-scoped rules the
--   post-apply reach sweep showed were needed.
--
-- TRIGGERING DEFECT
--   2026-08-17, tester report: an Amex was recommended at a Zehrs. No Loblaw
--   grocery banner accepts Amex. The engine ranked on earned value with no
--   concept of whether the card can be tendered.
--
-- RULE 9 CONDITIONS
--   (a) Snapshot: vacuous and deliberately omitted. `network_acceptance_rules`
--       is created empty by the migration in the same change; a snapshot of a
--       table with no rows records nothing. The pre-state guard below asserts
--       count = 0, which is the real protection — if this file is ever run a
--       second time, or against a table someone has already populated, it
--       ROLLBACKs instead of duplicating.
--   (b) This IS the delta file. Nothing here is applied outside it.
--   (c) Expire-then-insert: not applicable on a first insert. Corrections to
--       these rows must expire (set valid_to) and re-insert, never DELETE.
--   (d) Guards: pre-state and post-state asserted inside one transaction.
--
-- EVIDENCE POSTURE (this is the part to read before signing off)
--   Merchant acceptance is a MERCHANT fact, not a card fact, so rule 7 does not
--   literally bind it. The same discipline applies anyway, because a wrong row
--   here silently removes a card from a user's ranking.
--
--   Loblaw publishes a customer-service page titled "Why don't you accept
--   American Express?" at
--   https://www.loblaws.ca/en/help/payments/why-dont-you-accept-american-express
--   The page exists and its title is dispositive of the policy; its BODY could
--   not be machine-read in this session (client-rendered SPA), so it is cited
--   as the primary URL with two independent secondary sources corroborating the
--   banner list. Verify lane: re-read the body on the next pass and, if it
--   enumerates banners, upgrade block 2 below and widen coverage.
--
--   BLOCK 1 (confidence 'high'): banners named independently by BOTH
--   secondary sources.
--   BLOCK 2 (confidence 'medium'): Loblaw banners covered only by the sources'
--   general statement ("neither do any other Loblaw Companies"), not named
--   individually. REVIEW BEFORE RUNNING. Block 2 can be deleted without
--   affecting block 1 — the two blocks share no dependency.
--
--   DELIBERATELY NOT SEEDED: Shoppers Drug Mart / Pharmaprix. The two secondary
--   sources DISAGREE — one lists it as the Loblaw-group exception that DOES
--   take Amex, the other lists it among the banners that do not. Conflicting
--   Tier-2 sources do not support an assertion in either direction, so no rule
--   is written and the fail-open default leaves Amex recommendable there, which
--   is the status quo. This is the single highest-value verify item; settle it
--   against Shoppers' own payment-methods article:
--   https://lclcallcenters.my.site.com/shoppersdrugmart/s/article/What-Payments-methods-are-accepted-by-Shoppers-Drug-Mart-Stores
--
-- WHY BRAND PATTERNS AND NOT ENTITY IDS
--   Every row below is scope='brand_pattern'. No UUID is hardcoded, so this
--   file is environment-portable AND — the real reason — it reaches store rows
--   that do not exist yet. `merchant_entities` is minted at runtime from Google
--   display names, so entity- or group-keyed rules would only cover the 26
--   Loblaw-ish rows in production today and miss every store nobody has visited.
--
--   Both spellings of No Frills are seeded on purpose. The shared normalizer
--   strips punctuation but does not join or split words, so "No Frills" ->
--   'no frills' and "NOFRILLS" -> 'nofrills' are DIFFERENT keys. Seeding one
--   silently matches nothing — the same trap documented in
--   DESIGN_place_resolution_v1.md §1.5, which is how the 2026-08-02 chain fix
--   matched zero Superstore rows.
--
--   match_mode 'contains' on the No Frills patterns is required, not stylistic:
--   franchise stores are named "<Franchisee>'s NOFRILLS <Place>", which no
--   prefix rule can reach. Production already holds
--   "Mike's NOFRILLS Woodbridge" and "Steve's NOFRILLS Etobicoke".
--
-- ROLLBACK
--   begin;
--   delete from public.network_acceptance_rules
--    where note like 'DATA-021 seed p1%';
--   commit;
--   (DELETE rather than expire is correct ONLY here: these rows have never been
--   live, so there is no history to preserve. Once the flag has been on, use
--   expire-then-insert.)

begin;

-- ---------------------------------------------------------------- pre-state
do $$
declare
  n bigint;
begin
  select count(*) into n from public.network_acceptance_rules;
  if n <> 0 then
    raise exception
      'PRE-STATE FAIL: network_acceptance_rules has % rows, expected 0. This file is a first seed and is not idempotent; do not re-run it.', n;
  end if;

  perform 1 from public.networks where id in ('amex', 'visa');
  if (select count(*) from public.networks where id in ('amex', 'visa')) <> 2 then
    raise exception 'PRE-STATE FAIL: expected networks amex and visa to exist.';
  end if;

  if not exists (select 1 from public.runtime_flags where key = 'network_acceptance') then
    raise exception 'PRE-STATE FAIL: runtime_flags.network_acceptance missing — run migration 20260817140000 first.';
  end if;

  if (select enabled from public.runtime_flags where key = 'network_acceptance') then
    raise exception 'PRE-STATE FAIL: network_acceptance is already ON. Seed rules before enabling, never while live.';
  end if;
end $$;

-- ============================================================================
-- BLOCK 1 — Loblaw grocery banners, Amex not accepted. Confidence: high.
-- Named independently by both secondary sources, on top of Loblaw's own
-- "Why don't you accept American Express?" help page.
-- ============================================================================

insert into public.network_acceptance_rules
  (scope, brand_pattern, brand_match_mode, network_id, accepts, channel,
   evidence_url, evidence_tier, evidence_quote, verified_at, confidence, note, valid_from)
select
  'brand_pattern', p.pattern, p.mode, 'amex', false, 'any',
  'https://www.loblaws.ca/en/help/payments/why-dont-you-accept-american-express',
  'merchant_published',
  'Loblaw customer-service article: "Why don''t you accept American Express?"',
  date '2026-08-17',
  'high',
  'DATA-021 seed p1 (block 1). Loblaw banner named independently by rewardscanada.ca/loblaw.html and piggybank.ca/credit-cards/where-is-american-express-accepted-in-canada. Mechanism per frugalflyer.ca: one shared POS across the Loblaw umbrella that authorises Visa and Mastercard only. Page body not machine-read in-session — verify lane to re-read.',
  date '2026-08-17'
from (values
  -- banner pattern                    match mode
  ('loblaws',                          'prefix'),
  ('zehrs',                            'prefix'),
  ('real canadian superstore',         'prefix'),
  ('fortinos',                         'prefix'),
  ('valumart',                         'prefix'),
  ('valu mart',                        'prefix'),
  ('your independent grocer',          'prefix'),
  ('tt supermarket',                   'prefix'),
  -- Franchise banners lead with the franchisee's name: 'contains', not 'prefix'.
  ('no frills',                        'contains'),
  ('nofrills',                         'contains')
) as p(pattern, mode);

-- ============================================================================
-- BLOCK 2 — remaining Loblaw grocery banners. Confidence: medium.
-- REVIEW BEFORE RUNNING. Covered only by the sources' general statement
-- ("Loblaws does not accept American Express and neither do any other Loblaw
-- Companies"), not named individually. Delete this INSERT to ship block 1 alone.
-- ============================================================================

insert into public.network_acceptance_rules
  (scope, brand_pattern, brand_match_mode, network_id, accepts, channel,
   evidence_url, evidence_tier, evidence_quote, verified_at, confidence, note, valid_from)
select
  'brand_pattern', p.pattern, 'prefix', 'amex', false, 'any',
  'https://piggybank.ca/credit-cards/where-is-american-express-accepted-in-canada',
  'industry_consensus',
  'Loblaws does not accept American Express and neither do any other Loblaw Companies',
  date '2026-08-17',
  'medium',
  'DATA-021 seed p1 (block 2). Loblaw banner covered by the general statement only — NOT named individually by any source read on 2026-08-17. Seeded at medium confidence because the stated mechanism is a single shared POS across the umbrella. Verify lane: confirm per banner and promote to high, or expire.',
  date '2026-08-17'
from (values
  ('provigo'),
  ('maxi'),
  ('atlantic superstore'),
  ('wholesale club'),
  ('extra foods'),
  ('dominion')
) as p(pattern);

-- ============================================================================
-- BLOCK 3 — Costco Canada. Confidence: high (in-store), high (online Visa).
-- The motivating case for the `channel` column: warehouses are Mastercard-only
-- under an exclusive network agreement, while costco.ca also takes Visa.
-- One brand pattern covers "Costco" and "Costco Gas" (both live entities).
-- ============================================================================

insert into public.network_acceptance_rules
  (scope, brand_pattern, brand_match_mode, network_id, accepts, channel,
   evidence_url, evidence_tier, evidence_quote, verified_at, confidence, note, valid_from)
values
  -- Warehouse + gas bar: Mastercard only.
  ('brand_pattern', 'costco', 'prefix', 'amex', false, 'in_store',
   'https://www.forbes.com/advisor/ca/credit-cards/what-credit-cards-does-costco-accept/',
   'industry_consensus',
   'American Express is not accepted anywhere at Costco Canada; the partnership expired in December 2014.',
   date '2026-08-17', 'high',
   'DATA-021 seed p1 (block 3). Amex acceptance ended Dec 2014 (CBC, 2014). Verify lane: upgrade evidence_tier to merchant_published against costco.ca customer service.',
   date '2026-08-17'),

  ('brand_pattern', 'costco', 'prefix', 'visa', false, 'in_store',
   'https://www.forbes.com/advisor/ca/credit-cards/what-credit-cards-does-costco-accept/',
   'industry_consensus',
   'Mastercard is the only credit card that can be used at Costco warehouse stores.',
   date '2026-08-17', 'high',
   'DATA-021 seed p1 (block 3). In-store only — costco.ca takes Visa, see the online row below, which outranks this one on the channel-specificity level of the resolver.',
   date '2026-08-17'),

  -- costco.ca: Visa is accepted. An affirmative TRUE row exists here purely to
  -- override the in-store refusal above; without it the 'in_store' scoping
  -- would already have made this a no-op, but stating it makes the split
  -- legible in the data instead of implicit in a channel value.
  ('brand_pattern', 'costco', 'prefix', 'visa', true, 'online',
   'https://www.forbes.com/advisor/ca/credit-cards/what-credit-cards-does-costco-accept/',
   'industry_consensus',
   'Online (Costco.ca): both Mastercard and Visa are accepted.',
   date '2026-08-17', 'high',
   'DATA-021 seed p1 (block 3). Channel-specific TRUE. Demonstrates the precedence rule: a channel-scoped row outranks an ''any''-scoped row for the same network.',
   date '2026-08-17'),

  ('brand_pattern', 'costco', 'prefix', 'amex', false, 'online',
   'https://www.forbes.com/advisor/ca/credit-cards/what-credit-cards-does-costco-accept/',
   'industry_consensus',
   'American Express is not accepted anywhere at Costco Canada.',
   date '2026-08-17', 'high',
   'DATA-021 seed p1 (block 3). Amex is refused on BOTH channels — unlike Visa, there is no online exception.',
   date '2026-08-17');

-- ---------------------------------------------------------------- post-state
do $$
declare
  total bigint;
  b1 bigint;
  b2 bigint;
  b3 bigint;
  bad bigint;
begin
  select count(*) into total from public.network_acceptance_rules;
  select count(*) into b1 from public.network_acceptance_rules where note like 'DATA-021 seed p1 (block 1)%';
  select count(*) into b2 from public.network_acceptance_rules where note like 'DATA-021 seed p1 (block 2)%';
  select count(*) into b3 from public.network_acceptance_rules where note like 'DATA-021 seed p1 (block 3)%';

  if b1 <> 10 then raise exception 'POST-STATE FAIL: block 1 inserted % rows, expected 10.', b1; end if;
  if b2 <> 6  then raise exception 'POST-STATE FAIL: block 2 inserted % rows, expected 6.', b2;  end if;
  if b3 <> 4  then raise exception 'POST-STATE FAIL: block 3 inserted % rows, expected 4.', b3;  end if;
  if total <> 20 then raise exception 'POST-STATE FAIL: % total rows, expected 20.', total; end if;

  -- No pattern may be stored in a form the resolver cannot match. The CHECK
  -- constraint already enforces the character class; this asserts the thing the
  -- constraint cannot see — that nothing arrived upper-cased or double-spaced
  -- through a copy-paste.
  select count(*) into bad
  from public.network_acceptance_rules
  where brand_pattern is distinct from btrim(lower(brand_pattern))
     or brand_pattern like '%  %';
  if bad <> 0 then raise exception 'POST-STATE FAIL: % brand_pattern rows are not canonically normalized.', bad; end if;

  -- A TRUE row that no FALSE row contradicts is dead weight and usually a
  -- mistake. Assert the one intended case (costco/visa/online) and only it.
  select count(*) into bad
  from public.network_acceptance_rules
  where accepts is true
    and not (brand_pattern = 'costco' and network_id = 'visa' and channel = 'online');
  if bad <> 0 then raise exception 'POST-STATE FAIL: % unexpected accepts=true rows.', bad; end if;

  raise notice 'DATA-021 seed p1 OK: 10 block-1 + 6 block-2 + 4 block-3 = 20 rows.';
end $$;

commit;

-- ---------------------------------------------------------------------------
-- POST-APPLY CHECKS (run outside the transaction)
-- ---------------------------------------------------------------------------
-- 1) Which live merchant entities does each rule now reach? Should list the
--    Zehrs/No Frills/Superstore/Fortinos/Valu-mart/Costco rows and NOTHING else.
--
--    select r.brand_pattern, r.network_id, r.channel, e.display_name
--    from public.network_acceptance_rules r
--    join public.merchant_entities e
--      on e.normalized_name = r.brand_pattern
--      or (r.brand_match_mode in ('prefix','contains')
--          and e.normalized_name like r.brand_pattern || ' %')
--      or (r.brand_match_mode = 'contains'
--          and (e.normalized_name like '% ' || r.brand_pattern
--            or e.normalized_name like '% ' || r.brand_pattern || ' %'))
--    order by 1, 2, 4;
--
-- 2) False-positive sweep — anything matched that is NOT a Loblaw/Costco store
--    is a defect. Read the output, do not just count it.
--
-- 3) The flag stays OFF until (1) and (2) are reviewed and a TestFlight build
--    renders the acceptance badge. Flip with a separate delta:
--    deltas/2026-08-__?__runtime_flags__network_acceptance_on.sql
