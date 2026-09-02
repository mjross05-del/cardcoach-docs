-- 2026-09-02 — merchant_entities.default_category_id: the 39-row name pass (NULL -> category), APPLIED
-- Lane: merchant-category apply (PROMPT_merchant_category_apply.md Phase A), run 4b0ccfa5-41f1-4d6f-975f-5856e4e3eae7 (chat).
-- Source: dispatches/WORKLIST_merchant_category_name_pass_2026-09-02.md — Mike's ruling in chat, 2026-09-02: "approved" (all 39).
-- Snapshot (rule 9(a)): snapshots.merchant_entities_snapshot_20260902_namepass, 679 rows, RLS + REVOKE.
-- Applied 2026-09-02 18:03 UTC in one transaction; every UPDATE asserted rows_affected = 1; one verify.write_audit row
-- per entity (approved_by 'mike'), cited on each line. Guardrail placed_null_category 45 -> 6; NULL entities 77 -> 38.
-- This file is the record, not a script to re-run.
--
-- ROLLBACK (by name, only if Mike reverses a ruling): update public.merchant_entities set default_category_id = null where id = '<id>';

-- CITGO · audit dab45269
update public.merchant_entities set default_category_id = 'gas' where id = '8f857d17-a797-4c6b-8a96-199c62b5b7b3' and default_category_id is not distinct from null;
-- Citgo Foodmart · audit e5329d1f
update public.merchant_entities set default_category_id = 'gas' where id = '6dc07998-9d01-429e-8431-ac6a37e71549' and default_category_id is not distinct from null;
-- Delta Hotels London Armouries · audit beecb69d
update public.merchant_entities set default_category_id = 'travel' where id = 'c220c4b0-ea9f-4d56-adeb-2781883be6e5' and default_category_id is not distinct from null;
-- Dairy Queen Grill & Chill · audit 41168e21
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = '49fc222a-e716-4fa4-b72f-e2b23fb00ec1' and default_category_id is not distinct from null;
-- Auntie Anne's Pretzels · audit ceff7e41
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = 'cdb894b5-07c5-4dca-b6e9-9f2b3a0826bd' and default_category_id is not distinct from null;
-- QDOBA Mexican Eats · audit 24de79e2
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = '93ea6a39-dc46-4514-932f-e55a6b76c127' and default_category_id is not distinct from null;
-- WingsUp! Unionville · audit 0118e9e4
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = '72a9f8ff-c682-4468-8fc9-2bd87d6707e8' and default_category_id is not distinct from null;
-- Abica Coffee · audit 52232995
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = '4ebf0fd9-1cb8-4c37-b23d-98ba84c733f7' and default_category_id is not distinct from null;
-- Glenn's Cafe · audit a05f9e9f
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = '495ac35f-58e5-42ea-b31f-1f6c8837ed74' and default_category_id is not distinct from null;
-- Covenant Cafe · audit 9da40626
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = 'f2245251-ec0f-4f38-abc3-e1dd843beaef' and default_category_id is not distinct from null;
-- El Burrito Plazero · audit 7278fc14
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = 'c8f667f2-1f70-4d26-bb1a-583f9070b8cb' and default_category_id is not distinct from null;
-- Boar's Head Cafe Concourse A Food Court · audit 4de31a17
update public.merchant_entities set default_category_id = 'coffee_fastfood' where id = 'b87aea9d-f580-476f-88d7-7e551227863c' and default_category_id is not distinct from null;
-- The Grand Malabar Indian Cuisine · audit d1e5a772
update public.merchant_entities set default_category_id = 'dining' where id = 'cf5ca5c7-9e98-478f-b80d-b6607f9f7b66' and default_category_id is not distinct from null;
-- Kennedy's Restaurant & Catering · audit 1589c130
update public.merchant_entities set default_category_id = 'dining' where id = '2d5fbdf8-46d6-4c11-9a9f-72520f1b3af5' and default_category_id is not distinct from null;
-- Ruby's Mediterranean Cuisine · audit 7900b12f
update public.merchant_entities set default_category_id = 'dining' where id = '732098d0-8a29-46d2-957a-f83c6564c3d2' and default_category_id is not distinct from null;
-- Tangra Villa Hakka Chinese Restaurant (HALAL) · audit f7599bba
update public.merchant_entities set default_category_id = 'dining' where id = '76a368ce-c641-4e06-83e6-086146f18771' and default_category_id is not distinct from null;
-- Ganesha Take out and catering · audit 16b5b8a7
update public.merchant_entities set default_category_id = 'dining' where id = '150e52ae-0595-41e0-8cd3-b19bfc9243fb' and default_category_id is not distinct from null;
-- Earls Kitchen + Bar · audit e78fd5c6
update public.merchant_entities set default_category_id = 'dining' where id = 'f218855c-4972-4f11-a3ce-04f2d0819757' and default_category_id is not distinct from null;
-- P.F. Chang's · audit fd7526a6
update public.merchant_entities set default_category_id = 'dining' where id = '92b6f069-714e-4c79-bcc4-e7149e3ee958' and default_category_id is not distinct from null;
-- Low Country · audit cb89ac76
update public.merchant_entities set default_category_id = 'dining' where id = 'd159439c-77b3-476d-8047-c249a645ebcd' and default_category_id is not distinct from null;
-- SK Nigerian Catering Service · audit d1781382
update public.merchant_entities set default_category_id = 'dining' where id = '35765311-5ea0-49e1-8eba-5b7a14712174' and default_category_id is not distinct from null;
-- Double Double Pizza · audit 50d6d2c7
update public.merchant_entities set default_category_id = 'dining' where id = 'f743f50a-5cf5-4ab4-9d2d-32c17bc2df70' and default_category_id is not distinct from null;
-- supermarcado el rancho · audit 60aa797f
update public.merchant_entities set default_category_id = 'grocery' where id = 'a53cd0c9-c056-48b2-8a4f-1a730cd57f26' and default_category_id is not distinct from null;
-- Noor Food Market & Butcher · audit e622dd17
update public.merchant_entities set default_category_id = 'grocery' where id = '64e66c9d-1a5b-434c-afe9-220aedc6f4a0' and default_category_id is not distinct from null;
-- Pfenning's Organic & More · audit 7898a402
update public.merchant_entities set default_category_id = 'grocery' where id = 'b39d6ac1-feed-4ff0-9a62-14c46b1ea7eb' and default_category_id is not distinct from null;
-- Kwik Way Foods · audit 8c9b0c8d
update public.merchant_entities set default_category_id = 'grocery' where id = '4ed36d02-8f9d-4559-8d25-4467278b08cd' and default_category_id is not distinct from null;
-- Quick Trip Variety Store · audit 7411c5da
update public.merchant_entities set default_category_id = 'grocery' where id = '3df1e33c-9efa-453a-8b4e-5bd116cfc854' and default_category_id is not distinct from null;
-- Hasty Market · audit 6b44d4d9
update public.merchant_entities set default_category_id = 'grocery' where id = 'd089ab90-bdb4-4868-a124-50a5c9305447' and default_category_id is not distinct from null;
-- MC Convenience · audit 4cc8103a
update public.merchant_entities set default_category_id = 'grocery' where id = 'f5c6cce9-f7a3-485c-ab1b-c0669b8c2373' and default_category_id is not distinct from null;
-- Dollarama · audit 467fb347
update public.merchant_entities set default_category_id = 'retail_shopping' where id = '4d1a7161-ae83-4590-984d-21b5a84342fb' and default_category_id is not distinct from null;
-- Best Buy · audit eef9a7d7
update public.merchant_entities set default_category_id = 'retail_shopping' where id = 'd1592676-b897-48e6-bccf-c33ac25361a0' and default_category_id is not distinct from null;
-- NAPA Auto Parts - NAPA Swift Current · audit 65d4c29d
update public.merchant_entities set default_category_id = 'retail_shopping' where id = 'bd6b32bf-2cf3-4151-b8e0-2463f4df28c8' and default_category_id is not distinct from null;
-- Bumper to Bumper - Great West Auto Electric Ltd. · audit 5fd99256
update public.merchant_entities set default_category_id = 'retail_shopping' where id = '34eeae5e-fbc5-4adc-9556-be17786e9e62' and default_category_id is not distinct from null;
-- One Plant - Strathroy · audit cc099c15
update public.merchant_entities set default_category_id = 'retail_shopping' where id = '48a3a256-d0d0-4976-bb5c-c8a661463c20' and default_category_id is not distinct from null;
-- Amazon · audit 3b8d03cd
update public.merchant_entities set default_category_id = 'retail_shopping' where id = '28016688-2a0f-4285-8a23-a46ce8bf2a8d' and default_category_id is not distinct from null;
-- Walmart + Parking · audit 1caad9ec
update public.merchant_entities set default_category_id = 'retail_shopping' where id = '4f8531a0-de9d-4f0f-b88b-93a618f5c144' and default_category_id is not distinct from null;
-- Costco Wholesale · audit 9070d795
update public.merchant_entities set default_category_id = 'wholesale_club' where id = '4e67329e-139a-4678-9e43-bcfcd4f1f1a4' and default_category_id is not distinct from null;
-- SaskTel · audit 646a4556
update public.merchant_entities set default_category_id = 'recurring_bills' where id = '6e6ed0cc-8d66-4096-9746-084526f505bf' and default_category_id is not distinct from null;
-- VRCADE · audit 9bd64383
update public.merchant_entities set default_category_id = 'entertainment' where id = 'ecf04f24-06db-4bc8-b39f-e71922674dd3' and default_category_id is not distinct from null;
