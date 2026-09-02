-- 2026-09-02 — earn_rates: CIBC Adapta's 33 bonus rows retyped mcc_defined -> auto_top_n (DATA-023), APPLIED
-- Lane: review lane (chat). Mike's ruling in chat, 2026-09-02: "add condition type" for the Adapta auto top-3.
-- Run 7d3e0c1a-5b6f-4e2a-9c4d-2f1a8b7c6d5e · verify.write_audit 21096c42 · rows_affected 33 (11 per card).
-- Prerequisite DDL: migration 20260902182121_data_023_auto_top_n_condition_type (columns condition_top_n,
-- condition_group; CHECK widened). Snapshot (rule 9(a)): snapshots.earn_rates_snapshot_20260902_adapta, 732 rows.
-- Applied 2026-09-02 18:22 UTC in one transaction with guards (33 touched; 11 per card; 3 groups; no Adapta
-- row left mcc_defined). This file is the record, not a script to re-run.
--
-- Before: condition_type = 'mcc_defined', mcc_includes NULL — failed closed everywhere, the cards scored at
-- base in every category. After: the edge gate (_shared/autoTopN.ts) prices the row when the purchase's
-- issuer category ranks in the card's top 3 this month, purchase counted in; ties and callers without spend
-- facts fail closed. Live after the next edge deploy.
--
-- ROLLBACK: update public.earn_rates set condition_type = 'mcc_defined', condition_top_n = null,
--           condition_group = null where condition_type = 'auto_top_n' and card_id like 'ca_cibc_adapta%';

update public.earn_rates
   set condition_type = 'auto_top_n',
       condition_top_n = 3,
       condition_group = case category_id
                           when 'grocery' then 'cibc_grocery_drug'
                           when 'drugstore_pharmacy' then 'cibc_grocery_drug'
                           when 'gas' then 'cibc_gas_ev'
                           when 'ev_charging' then 'cibc_gas_ev'
                           when 'e_games' then 'cibc_egames_subscriptions'
                           when 'streaming' then 'cibc_egames_subscriptions'
                           else null
                         end
 where card_id in ('ca_cibc_adapta_standard_mastercard','ca_cibc_adapta_student_mastercard','ca_cibc_adapta_world_mastercard')
   and condition_type = 'mcc_defined'
   and condition_text like 'AUTO TOP-3%'
   and valid_to is null
   and (mcc_includes is null or cardinality(mcc_includes) = 0);
