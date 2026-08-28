-- =========================================================================
-- STATUS NOTE ADDED 2026-08-27 — PRE-STATE ASSERTION IS STALE; THIS WILL ABORT.
-- The file asserts exactly 48 curated chains as its pre-state (post-state 80).
-- Production now has 59 is_chain rows, verified 2026-08-27, and 2 of this
-- file's own 32 targets have already been flagged by some other route.
-- Running it today raises "pre-state: expected 48 curated chains, found 59"
-- and rolls back. That is the guard working as designed, not a safety problem
-- -- but the delta is no longer applicable as written and needs its targets
-- and counts recomputed against live state before it means anything.
-- =========================================================================

-- Chain curation p1: is_chain on 32 head-of-statement Canadian brands.
--
-- STATUS: **PROPOSED — NOT APPLIED.** Nothing in this file has been run.
-- Requires Mike's review before execution (DESIGN_statement_import_v1 §6.2 asks
-- for the list as a delta for review, not for application).
--
-- Live read 2026-08-20 on card_coach_advanced (hrzpznlpmxxrbtwskacu):
-- 567 merchant_entities, 48 is_chain, 72 NULL default_category_id, 46 aliases,
-- 583 merchant_entity_places, 60 merchants, 141 merchant_domains.
--
-- ===========================================================================
-- READ THIS FIRST: this is NOT a dark change.
-- ===========================================================================
--
-- §6.2 frames chain curation as lifting the statement-import coverage number,
-- which is true and is the smaller half. `is_chain` is read by FOUR call sites
-- and TWO OF THEM ARE LIVE IN PRODUCTION TODAY:
--
--   LIVE   supabase/functions/resolve-place/index.ts:532      -> matchChainEntity
--   LIVE   supabase/functions/recommend-here-v2/index.ts:300  -> matchChainEntity
--   dark   supabase/functions/resolve-descriptors-v1/index.ts:468  (API-020, flag off)
--   dark   supabase/functions/_shared/receiptProposal.ts:138       (API-017, flag off)
--
-- So applying this changes what the shipped app resolves, on the next request.
--
-- WHAT CHANGES, precisely. `matchChainEntity` runs only on an exact-match MISS
-- — the path that would otherwise mint a new per-location entity ("Tim Hortons
-- Stanley Park") that no eligible-merchant list and no offer scope references.
-- That minting is the 2026-08-02 defect this flag was introduced to fix. So the
-- direction of this change is: FEWER spurious per-location entities, MORE taps
-- landing on the curated brand that offers and list-gated earn rates point at.
-- That is the intended behaviour, and it is still a behaviour change on a
-- shipped surface and should be flipped with that understood.
--
-- TWO SIDE EFFECTS worth stating plainly:
--
--  1. `matchChainEntity` INSERTs a `merchant_entity_aliases` row on every match
--     (a best-effort curation trail, duplicates ignored). Adding 32 chains means
--     that table starts growing where it did not before. It is 46 rows today.
--
--  2. `findChainEntityMatch` REJECTS a match when the classified category and
--     the chain's category are both known, both specific, and different. Every
--     brand below already has a category (except the two marked), so the guard
--     is active for it from the moment it is flagged — a place classified
--     `dining` will not match a chain categorised `grocery`. That is the guard
--     working, but it means a mis-set category on a chain silently suppresses
--     matches rather than producing a visible error.
--
-- ===========================================================================
-- SELECTION RULE, and what it deliberately excludes
-- ===========================================================================
--
-- `merchantIdentity.ts:41-42` states the curation principle: "curation is the
-- false-positive guard — generic single words like 'metro' are deliberately not
-- flagged." Matching is a WORD-BOUNDARY PREFIX ("zehrs" matches "zehrs stanley
-- park", never "zehrsville"), so a chain whose name is a common English word
-- captures every place that merely begins with it.
--
-- Included only where the normalized name is a brand rather than a word, the
-- entity already exists (this file creates nothing), and the category is
-- defensible from the merchant's actual business (rule 7).
--
-- HELD BACK, with reasons — these are the judgement calls, please read them:
--
--   subway (8 places!)  Highest-volume candidate here and still held. "subway"
--                       is a transit noun, and `is_chain` is read LIVE by
--                       resolve-place, where "Subway Station" is a real Google
--                       place name. On a card statement "SUBWAY #1234" is
--                       unambiguous; on a place lookup it is not, and this flag
--                       cannot distinguish the two callers. Worth a decision.
--   metro               Already deliberately excluded; cited by name in
--                       merchantIdentity.ts. Not reopened here.
--   staples, indigo,    Generic single words. "staples", "indigo" and "roots"
--   roots               all capture unrelated places under a prefix match.
--   bell, rogers, fido  Surnames and common nouns. "bell" would capture "Bell
--                       Tower Cafe"; "rogers" captures "Rogers Place".
--   mcdonalds AND       DUPLICATE ROWS WITH CONFLICTING CATEGORIES:
--   mcdonald's          'mcdonalds' -> coffee_fastfood (3 places), "mcdonald's"
--                       -> dining (1 place). Flagging either makes the conflict
--                       load-bearing. Already on the taxonomy backlog — the
--                       2026-08-14 Harvey's delta notes it. Resolve first.
--   circle k (4 places) The NAME is fine; the CATEGORY is the problem. It is
--                       currently `grocery`, which carries 83 active earn rates.
--                       Circle K is a convenience store, usually forecourt, and
--                       issuers route it to convenience/gas MCCs, not grocery.
--                       Flagging it as a grocery chain would credit grocery
--                       multipliers an issuer would not pay. Rule 7 says fix the
--                       category first, and not by guessing.
--   homesense           `home_improvement` looks wrong: HomeSense is the TJX
--                       decor banner, a sibling of Winners, not a hardware
--                       store. Category question, not a chain question.
--   princess auto       `home_improvement` likewise questionable for an auto
--                       parts and surplus tools retailer.
--
-- ===========================================================================
-- A LARGER DEFECT FOUND WHILE DOING THIS — not fixed here, needs a decision
-- ===========================================================================
--
-- `merchant_entities.normalized_name` carries TWO INCOMPATIBLE CONVENTIONS:
-- 372 rows are space-separated ('tim hortons'), 37 are underscore-joined
-- ('tim_hortons'), 158 are single tokens where the two agree.
--
-- 19 display names exist as 2-3 rows because of it, several with CONFLICTING
-- categories: 'canadian tire' (general, is_chain) vs 'canadian_tire'
-- (home_improvement); 'sport chek' (general, is_chain) vs 'sport_chek'
-- (retail_shopping); 'canadian tire gas+' as THREE rows.
--
-- Why it matters more than it looks: `normalizeMerchantName` and
-- `normalizeStatementDescriptor` produce ONE canonical form. Whichever
-- convention they do not emit is unreachable — those rows can never be hit by
-- exact match, by descriptor resolution, or by chain prefix matching. Note that
-- ZERO of the 37 underscore rows is currently is_chain, which is consistent
-- with them being the dead half.
--
-- That fragmentation directly suppresses the coverage figure D4 shows the user,
-- and it is worth more than the 31 flips below. It needs its own ticket: decide
-- the canonical convention, merge each duplicate pair (keeping places, aliases
-- and the defensible category), and add a guard that refuses a second
-- convention. NOT attempted here — merging entities moves foreign keys and is
-- exactly the "wrong shape can break the running app" class rule 9 reserves for
-- a per-change proposal.
--
-- ===========================================================================
-- CATEGORY FILLS ARE NOT IN THIS FILE, on purpose
-- ===========================================================================
--
-- Six entities are ALREADY is_chain and carry NULL default_category_id:
-- FreshCo, Maxi, Safeway, Sobeys (grocery banners) and Pioneer, Ultramar (fuel).
-- Filling them is high-value and low-risk — a NULL category means the guard
-- above is inactive, so these six currently match anything.
--
-- They are NOT filled here because that lane already exists and has an owner's
-- process: `verify.merchant_category_observations` ->
-- PROMPT_merchant_category_apply Phase A, "run manually in chat with Mike
-- deciding live", per the 2026-08-14 Harvey's delta. Routing six category
-- assignments around that lane in a chain-curation file would be the kind of
-- quiet process bypass that lane was built to prevent.
--
-- ===========================================================================

BEGIN;

-- Rule 9(a): snapshot before the first write, and SECURE IT IN THE SAME
-- TRANSACTION. A bare CREATE TABLE AS in public inherits default privileges and
-- lands anon-readable — that happened on 2026-07-29 with
-- point_valuations_snapshot_20260729 and Alex had to ship a migration to close
-- it. Enabling RLS with no policies denies all non-bypassing roles; the REVOKE
-- removes the grant so a later permissive policy cannot silently reopen it.
CREATE TABLE merchant_entities_snapshot_20260820 AS
  SELECT *, now() AS snapshot_taken_at FROM public.merchant_entities;
ALTER TABLE merchant_entities_snapshot_20260820 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON merchant_entities_snapshot_20260820 FROM anon, authenticated;

-- Rule 9(d): assert the PRE-state. If the catalogue has moved since this file
-- was written, stop rather than proceed on a surprise (rule 9(f): Mike runs
-- concurrent sessions and none of them can see each other).
DO $$
DECLARE
  chain_count  integer;
  target_count integer;
BEGIN
  SELECT count(*) INTO chain_count FROM public.merchant_entities WHERE is_chain;
  IF chain_count <> 48 THEN
    RAISE EXCEPTION
      'pre-state: expected 48 curated chains, found %. The catalogue moved since 2026-08-20; re-derive this list before applying.',
      chain_count;
  END IF;

  SELECT count(*) INTO target_count
  FROM public.merchant_entities
  WHERE normalized_name IN (
    'tim hortons','starbucks','starbucks coffee company','wendys','harveys',
    'kfc','pizza hut','pizza pizza','swiss chalet','popeyes louisiana kitchen',
    'kelseys original roadhouse','pita pit','booster juice','freshii',
    'boston pizza','walmart','costco','giant tiger','bulk barn','lcbo','saq',
    'lululemon','sephora','ikea','rona','m&m food market','mm food market',
    'dollarama','rexall','telus','koodo','virgin plus'
  );
  IF target_count <> 32 THEN
    RAISE EXCEPTION
      'pre-state: expected to find 32 named target rows, found %.', target_count;
  END IF;
END $$;

-- The flips. `is_chain` only; no category is written by this file, and no row
-- is created — every name below already exists.
UPDATE public.merchant_entities
SET is_chain = true, updated_at = now()
WHERE is_chain = false
  AND normalized_name IN (
    -- coffee and fast food
    'tim hortons',                 -- 14 places, the single highest-volume brand here
    'starbucks',
    'starbucks coffee company',    -- 6 places; longest-name-wins keeps both usable
    'wendys',
    'harveys',
    'kfc',
    'pizza hut',
    'pizza pizza',
    'popeyes louisiana kitchen',
    'pita pit',
    'booster juice',
    'freshii',
    -- casual dining
    'boston pizza',                -- duplicate row exists, SAME category: safe
    'swiss chalet',
    'kelseys original roadhouse',
    -- grocery and general merchandise
    'walmart',
    'costco',
    'giant tiger',
    'bulk barn',
    'm&m food market',
    'mm food market',              -- both conventions, same category: safe
    -- alcohol (provincial monopolies; unambiguous)
    'lcbo',
    'saq',
    -- retail
    'lululemon',
    'sephora',
    'ikea',
    'rona',
    -- NULL-category chains: flagging them helps resolve-place consolidation,
    -- which does not need a category. It does NOT help API-020, which returns a
    -- category and will return null for these until the category lane fills
    -- them. Included because the consolidation benefit is real on a live
    -- surface; excluded from any claim about descriptor coverage.
    'dollarama',
    'rexall',
    -- telcos with unambiguous brand names. bell / rogers / fido held back.
    'telus',
    'koodo',
    'virgin plus'
  );

-- Rule 9(d): assert the POST-state; fail closed.
DO $$
DECLARE
  chain_count integer;
  still_off   integer;
BEGIN
  SELECT count(*) INTO chain_count FROM public.merchant_entities WHERE is_chain;
  IF chain_count <> 48 + 32 THEN
    RAISE EXCEPTION 'post-state: expected 80 curated chains, found %.', chain_count;
  END IF;

  -- 'starbucks coffee company' is a prefix-superset of 'starbucks'; the matcher
  -- resolves that by longest-name-wins, so both may be chains. Assert the pair
  -- is intact rather than assuming it.
  SELECT count(*) INTO still_off
  FROM public.merchant_entities
  WHERE normalized_name IN ('starbucks', 'starbucks coffee company')
    AND NOT is_chain;
  IF still_off <> 0 THEN
    RAISE EXCEPTION 'post-state: the starbucks pair did not both flip.';
  END IF;

  -- The held-back list must remain held back. If a later edit sweeps them in,
  -- this fails rather than shipping a generic word as a chain.
  SELECT count(*) INTO still_off
  FROM public.merchant_entities
  WHERE normalized_name IN (
    'subway','metro','staples','indigo','roots','bell','rogers','fido',
    'mcdonalds','mcdonald''s','circle k','homesense','princess auto'
  ) AND is_chain;
  IF still_off <> 0 THEN
    RAISE EXCEPTION
      'post-state: % deliberately-held brand(s) were flagged as chains. Read the HELD BACK block.',
      still_off;
  END IF;
END $$;

COMMIT;

-- ===========================================================================
-- Rollback
-- ===========================================================================
-- Restores is_chain from the snapshot for every row this file could have
-- touched, rather than blanket-clearing, so a concurrent session's flips are
-- not reverted along with these.
--
-- BEGIN;
-- UPDATE public.merchant_entities e
-- SET is_chain = s.is_chain, updated_at = now()
-- FROM merchant_entities_snapshot_20260820 s
-- WHERE e.id = s.id AND e.is_chain IS DISTINCT FROM s.is_chain;
-- COMMIT;
--
-- After verifying: DROP TABLE merchant_entities_snapshot_20260820;
--
-- ===========================================================================
-- Verify after applying
-- ===========================================================================
--   pnpm verify:data-007      -- canonical merchant entities
--   pnpm verify:data-008      -- merchant groups
--   pnpm verify:cpp           -- rule 9(f): before and after any batch
-- and spot-check the live surfaces this actually changes:
--   a resolve-place lookup for a Tim Hortons with a location suffix should now
--   return the curated brand entity rather than minting a new one.
