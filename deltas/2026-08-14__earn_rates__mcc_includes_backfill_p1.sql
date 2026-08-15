-- earn_rates.mcc_includes backfill, pass 1 (2026-08-14).
-- Approved by Mike in chat 2026-08-14 ("do the mcc_includes backfill").
--
-- Scope: 15 of the 67 live mcc_defined rows with NULL mcc_includes — only the
-- rows whose MCCs are already evidenced ON the row itself. Two tiers applied:
--
--   Tier A (5 rows): condition_text cites the numerals. Completing ingestion
--     of an already-captured issuer fact; the populated CIBC Dividend VI gas
--     row 350c583a ("...(MCC 5552)" -> [5552]) is the existing convention.
--   Tier B (10 rows): condition_text quotes the network's official MCC class
--     names verbatim ("grocery stores and supermarkets" = 5411; "eating
--     places, restaurants" = 5812; "drinking places" = 5813; "fast food
--     restaurants" = 5814; "service stations" = 5541; "automated gas/fuel
--     dispensers" = 5542; "drugstores/pharmacies" = 5912; "local/suburban
--     commuter transportation" = 4111; "taxi, limousine" = 4121). The
--     name->number step is a deterministic lookup through the network
--     standard; each row's derivation is recorded below. Issuer batches
--     should spot-confirm tier B on their next weekly pass.
--
--   NOT applied (52 rows): generic prose ("eligible dining purchases", "as
--   classified by Visa MCC", "AUTO TOP-3", Amex classification language).
--   Assigning numbers there would invent card facts (rule 7) — verify lane.
--
-- Ranking effect: rows in mapped categories flip from suppressed to admitted
-- under the merchant-path assumption iff their MCCs intersect the category
-- mapping. All 15 intersect. Expected: 88 -> 103 of 145 rows pricing.
-- Fallback-category rows are unaffected today (fallback short-circuits) but
-- become robust to a future first mapping.
--
-- No snapshot table: every touched row starts from mcc_includes IS NULL (also
-- the UPDATE guard), and the ids are enumerated here, so the exact rollback is
-- the statement at the bottom. In-transaction row-count assertion aborts on
-- any drift.

do $$
declare n integer;
begin
  update earn_rates er
  set mcc_includes = v.mccs
  from (values
    -- ============ Tier A: numerals cited in condition_text ============
    -- "2% on gas (MCC 5541, 5542)" - MBNA Smart Cash Platinum Plus
    ('2349f8a4-6ce1-4c7d-afd3-f17d4e141586'::uuid, '{5541,5542}'::integer[]),
    -- "2% on gas (MCC 5541, 5542)" - MBNA Smart Cash World
    ('b49cf33f-3ec1-4772-864c-7631643e7b15'::uuid, '{5541,5542}'::integer[]),
    -- "2% on grocery (MCC 5411)" - MBNA Smart Cash Platinum Plus
    ('b145845c-bf5e-46bd-bcbd-91a87899fe5b'::uuid, '{5411}'::integer[]),
    -- "2% on grocery (MCC 5411)" - MBNA Smart Cash World
    ('311173d9-3cf6-4332-b494-9235bb7308e8'::uuid, '{5411}'::integer[]),
    -- "gas merchants and electric vehicle charging (MCC 5552)" - CIBC Costco;
    -- populate exactly the cited numeral, matching populated sibling 350c583a
    ('8229be32-baf1-4e63-9d0f-aa37edec2779'::uuid, '{5552}'::integer[]),
    -- ====== Tier B: verbatim network class names in condition_text ======
    -- "eating places, restaurants, drinking places and fast food restaurants"
    -- = 5812/5813/5814 - CIBC Dividend VI dining
    ('c0cfce4c-4962-4775-800b-bb030dec7890'::uuid, '{5812,5813,5814}'::integer[]),
    -- "grocery stores and supermarkets" = 5411 - CIBC Dividend VI grocery
    ('f382d9d7-dff2-42f3-85c4-20d9730b2a4c'::uuid, '{5411}'::integer[]),
    -- "grocery stores and supermarkets" = 5411 - CIBC Dividend Standard
    ('bb32eec0-729f-4d4d-b1a0-6224331e9b43'::uuid, '{5411}'::integer[]),
    -- "local/suburban commuter transportation ... (subway, streetcar, taxi,
    -- limousine, ride sharing)" = 4111 + 4121 (rideshare processes as 4121;
    -- no additional code named) - CIBC Dividend VI transit
    ('ce86a00e-de93-4fe2-b61b-96de0123224b'::uuid, '{4111,4121}'::integer[]),
    -- "classified in the credit card network as restaurants" = 5812 only
    -- (fast food / drinking places not named) - CIBC Costco dining
    ('23deff28-6c3a-4977-9dcd-277b786612db'::uuid, '{5812}'::integer[]),
    -- "service stations/automated gas dispensers" = 5541/5542 - CIBC
    -- Aeroplan VI gas
    ('c981fef5-1e3f-4173-a77f-0c788290c66e'::uuid, '{5541,5542}'::integer[]),
    -- "service stations or automated gas dispensers" = 5541/5542 - CIBC
    -- Aventura VI gas
    ('ebdde85c-71df-415b-a24c-49a553c5ce91'::uuid, '{5541,5542}'::integer[]),
    -- "classified in the Visa network as grocery stores" = 5411 - CIBC
    -- Aeroplan VI grocery
    ('b4bc34ca-0d6a-4a37-b2a4-51f230abb4a9'::uuid, '{5411}'::integer[]),
    -- "classified as grocery stores" = 5411 - CIBC Aventura VI grocery
    ('72e927b0-efb0-4615-a136-7ab63eb1ca04'::uuid, '{5411}'::integer[]),
    -- "classified as drugstores/pharmacies" = 5912 (5122 is wholesale, not
    -- named) - CIBC Aventura VI drugstore
    ('b5b88737-f195-411b-92a9-f1e61424d1df'::uuid, '{5912}'::integer[])
  ) as v(id, mccs)
  where er.id = v.id
    and er.condition_type = 'mcc_defined'
    and er.valid_to is null
    and er.mcc_includes is null;

  get diagnostics n = row_count;
  if n <> 15 then
    raise exception 'mcc_includes backfill expected 15 rows, updated % - aborting', n;
  end if;
end $$;

-- Rollback (exact: every row above started NULL):
-- update earn_rates set mcc_includes = null where id in (
--   '2349f8a4-6ce1-4c7d-afd3-f17d4e141586','b49cf33f-3ec1-4772-864c-7631643e7b15',
--   'b145845c-bf5e-46bd-bcbd-91a87899fe5b','311173d9-3cf6-4332-b494-9235bb7308e8',
--   '8229be32-baf1-4e63-9d0f-aa37edec2779','c0cfce4c-4962-4775-800b-bb030dec7890',
--   'f382d9d7-dff2-42f3-85c4-20d9730b2a4c','bb32eec0-729f-4d4d-b1a0-6224331e9b43',
--   'ce86a00e-de93-4fe2-b61b-96de0123224b','23deff28-6c3a-4977-9dcd-277b786612db',
--   'c981fef5-1e3f-4173-a77f-0c788290c66e','ebdde85c-71df-415b-a24c-49a553c5ce91',
--   'b4bc34ca-0d6a-4a37-b2a4-51f230abb4a9','72e927b0-efb0-4615-a136-7ab63eb1ca04',
--   'b5b88737-f195-411b-92a9-f1e61424d1df');
