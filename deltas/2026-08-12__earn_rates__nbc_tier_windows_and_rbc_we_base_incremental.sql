-- 2026-08-12 — earn_rates: NBC monthly tier windows + RBC WE incremental moved to base slot
--
-- Applied by the engine session of 2026-08-12 (Mike: "address and resolve those
-- findings", ENGINE_FLOORS_REPORT_2026-08-12 §1). Rule 9 conditions honoured:
-- (a) secured snapshot earn_rates_snapshot_20260812 in this transaction,
-- (b) this delta file, (c) expire-then-insert, (d) pre/post guards below.
--
-- FACTS (no values invented):
-- * NBC Platinum — verify.fact_checks 2026-07-27, confirmed: grocery/dining
--   "2 points/$1 ... For the first increment of $1,000 in gross monthly
--   purchases", then 1.5 pts/$. Rows already carry both tiers (multiplier
--   2.9999 / 2.2499 over base 0.6667); this delta only adds the window
--   boundary and marks it measured over WHOLE-CARD monthly spend.
-- * NBC World Elite — same run: 5 pts/$ until $2,500 gross monthly, then 2
--   (multiplier 5.0 / 2.0 over base 1.0).
-- * RBC Cash Back WE — verify.fact_checks 9c5b9707 (2026-08-12, confirmed,
--   dual evidence): "(1.5% Cash Back Credit) in Net Purchases you make
--   (including pre-authorized bill payments), up to a maximum of $25,000 ...
--   maximum Cash Back Reward of $375.00 || (1% ...) in excess of $25,000 ...
--   unlimited". The +0.5% tier applies to ALL Net Purchases; the old row
--   b60c098d scoped it to category_id='general' only (bonus missing from
--   every other category, cap tracking only 'general' spend). It moves to the
--   base slot unchanged in value.
--
-- Expiry uses valid_to = current_date - 1: the reference loader admits rows
-- with valid_to >= as-of date, so expiring "today" would double-count the
-- replacement rows for one day (and double the RBC WE bonus on 'general'
-- purchases). Yesterday is the only overlap-free instant cutover.

begin;

-- (a) snapshot + secure, same transaction
create table public.earn_rates_snapshot_20260812 as
  select *, now() as snapshot_taken_at from public.earn_rates;
alter table public.earn_rates_snapshot_20260812 enable row level security;
revoke all on public.earn_rates_snapshot_20260812 from anon, authenticated;

-- (d) pre-state guards
do $$
declare
  nbc_count int;
  rbc_ok int;
begin
  select count(*) into nbc_count from public.earn_rates
   where valid_to is null and window_bucket is null
     and id in ('aa1e01da-ab4f-4373-a4bf-fb6db3b3c688','960ea09f-d911-4485-abb7-12b010488096',
                '4bf509cc-cb6d-4247-b4d8-9b9b7f0d292e','5d5ddda8-996c-4a67-ab51-bc02cf72a206',
                '9187fd92-441e-4c83-aab7-70ab27e003de','21e8ece3-3fb9-4c06-95ca-153285c33666',
                'a0e44715-7af1-429e-b337-5a56e8f0866a','13b3c5d1-481c-462a-8dce-00a30c258766');
  if nbc_count <> 8 then
    raise exception 'pre-guard: expected 8 active unwindowed NBC tier rows, found %', nbc_count;
  end if;

  select count(*) into rbc_ok from public.earn_rates
   where id = 'b60c098d-a1e6-4b55-9c27-a26127fd81ab' and valid_to is null
     and basis = 'category' and category_id = 'general'
     and earn_rate_type = 'incremental' and base_rate = 0.5000
     and cap_annual_cad = 25000.00;
  if rbc_ok <> 1 then
    raise exception 'pre-guard: RBC WE general incremental row not in expected state';
  end if;
end $$;

-- (c) expire
update public.earn_rates
   set valid_to = current_date - 1
 where valid_to is null
   and id in ('aa1e01da-ab4f-4373-a4bf-fb6db3b3c688','960ea09f-d911-4485-abb7-12b010488096',
              '4bf509cc-cb6d-4247-b4d8-9b9b7f0d292e','5d5ddda8-996c-4a67-ab51-bc02cf72a206',
              '9187fd92-441e-4c83-aab7-70ab27e003de','21e8ece3-3fb9-4c06-95ca-153285c33666',
              'a0e44715-7af1-429e-b337-5a56e8f0866a','13b3c5d1-481c-462a-8dce-00a30c258766',
              'b60c098d-a1e6-4b55-9c27-a26127fd81ab');

do $$
declare expired int;
begin
  select count(*) into expired from public.earn_rates
   where valid_to = current_date - 1
     and id in ('aa1e01da-ab4f-4373-a4bf-fb6db3b3c688','960ea09f-d911-4485-abb7-12b010488096',
                '4bf509cc-cb6d-4247-b4d8-9b9b7f0d292e','5d5ddda8-996c-4a67-ab51-bc02cf72a206',
                '9187fd92-441e-4c83-aab7-70ab27e003de','21e8ece3-3fb9-4c06-95ca-153285c33666',
                'a0e44715-7af1-429e-b337-5a56e8f0866a','13b3c5d1-481c-462a-8dce-00a30c258766',
                'b60c098d-a1e6-4b55-9c27-a26127fd81ab');
  if expired <> 9 then
    raise exception 'guard: expected 9 expired rows, got % — rolling back', expired;
  end if;
end $$;

-- (c) re-insert NBC tier rows with windows (values copied verbatim from the
-- expired rows; only the window columns and validity differ)
insert into public.earn_rates
  (card_id, basis, category_id, earn_unit, base_rate, multiplier,
   cap_monthly_cad, cap_annual_cad, valid_from, valid_to,
   condition_type, condition_text, mcc_includes, mcc_excludes,
   source_clause_reference, rate_unit, earn_rate_type, display_label,
   floor_monthly_cad, floor_annual_cad, category_excludes, window_bucket)
select
  card_id, basis, category_id, earn_unit, base_rate, multiplier,
  case when id in ('aa1e01da-ab4f-4373-a4bf-fb6db3b3c688','4bf509cc-cb6d-4247-b4d8-9b9b7f0d292e') then 1000.00
       when id in ('9187fd92-441e-4c83-aab7-70ab27e003de','a0e44715-7af1-429e-b337-5a56e8f0866a') then 2500.00
       else null end as cap_monthly_cad,
  cap_annual_cad, current_date, null,
  condition_type, condition_text, mcc_includes, mcc_excludes,
  source_clause_reference, rate_unit, earn_rate_type, display_label,
  case when id in ('960ea09f-d911-4485-abb7-12b010488096','5d5ddda8-996c-4a67-ab51-bc02cf72a206') then 1000.00
       when id in ('21e8ece3-3fb9-4c06-95ca-153285c33666','13b3c5d1-481c-462a-8dce-00a30c258766') then 2500.00
       else null end as floor_monthly_cad,
  null, null, 'card'
from public.earn_rates
where id in ('aa1e01da-ab4f-4373-a4bf-fb6db3b3c688','960ea09f-d911-4485-abb7-12b010488096',
             '4bf509cc-cb6d-4247-b4d8-9b9b7f0d292e','5d5ddda8-996c-4a67-ab51-bc02cf72a206',
             '9187fd92-441e-4c83-aab7-70ab27e003de','21e8ece3-3fb9-4c06-95ca-153285c33666',
             'a0e44715-7af1-429e-b337-5a56e8f0866a','13b3c5d1-481c-462a-8dce-00a30c258766');

-- (c) re-insert RBC WE +0.5% in the BASE slot (values verbatim from the
-- expired 'general' row; only basis/category placement changes)
insert into public.earn_rates
  (card_id, basis, category_id, earn_unit, base_rate, multiplier,
   cap_monthly_cad, cap_annual_cad, valid_from, valid_to,
   condition_type, condition_text, mcc_includes, mcc_excludes,
   source_clause_reference, rate_unit, earn_rate_type, display_label,
   floor_monthly_cad, floor_annual_cad, category_excludes, window_bucket)
select
  card_id, 'base', null, earn_unit, base_rate, multiplier,
  cap_monthly_cad, cap_annual_cad, current_date, null,
  condition_type, condition_text, mcc_includes, mcc_excludes,
  source_clause_reference, rate_unit, earn_rate_type, display_label,
  null, null, null, null
from public.earn_rates
where id = 'b60c098d-a1e6-4b55-9c27-a26127fd81ab';

-- (d) post-state guards
do $$
declare
  bad int;
  rbc_base int;
  rbc_general int;
begin
  -- each NBC card × category must hold exactly one capped-under row and one
  -- floored-after row, both windowed over the whole card
  select count(*) into bad from (
    select card_id, category_id,
           count(*) filter (where cap_monthly_cad is not null and floor_monthly_cad is null and window_bucket = 'card') as unders,
           count(*) filter (where floor_monthly_cad is not null and cap_monthly_cad is null and window_bucket = 'card') as afters,
           count(*) as total
    from public.earn_rates
    where valid_to is null
      and card_id in ('ca_national_bank_rewards_mastercard_platinum_mastercard',
                      'ca_national_bank_rewards_mastercard_world_elite_mastercard')
      and category_id in ('grocery','dining')
    group by card_id, category_id
  ) t where t.unders <> 1 or t.afters <> 1 or t.total <> 2;
  if bad <> 0 then
    raise exception 'post-guard: NBC tier slot shape wrong in % slots — rolling back', bad;
  end if;

  -- floor value must equal the sibling cap value in every NBC slot
  select count(*) into bad from (
    select card_id, category_id,
           max(cap_monthly_cad) as cap, max(floor_monthly_cad) as flr
    from public.earn_rates
    where valid_to is null
      and card_id in ('ca_national_bank_rewards_mastercard_platinum_mastercard',
                      'ca_national_bank_rewards_mastercard_world_elite_mastercard')
      and category_id in ('grocery','dining')
    group by card_id, category_id
  ) t where t.cap is distinct from t.flr;
  if bad <> 0 then
    raise exception 'post-guard: NBC floor/cap boundary mismatch — rolling back';
  end if;

  -- RBC WE: base slot = 1% total uncapped + 0.5% incremental capped 25000;
  -- no active 'general' rows remain
  select count(*) into rbc_base from public.earn_rates
   where valid_to is null and card_id = 'ca_rbc_cash_back_mastercard_world_elite_mastercard'
     and basis = 'base' and (
       (earn_rate_type = 'total' and base_rate = 1.0000 and cap_annual_cad is null)
       or
       (earn_rate_type = 'incremental' and base_rate = 0.5000 and cap_annual_cad = 25000.00)
     );
  select count(*) into rbc_general from public.earn_rates
   where valid_to is null and card_id = 'ca_rbc_cash_back_mastercard_world_elite_mastercard'
     and category_id = 'general';
  if rbc_base <> 2 or rbc_general <> 0 then
    raise exception 'post-guard: RBC WE base slot wrong (base=%, general=%) — rolling back', rbc_base, rbc_general;
  end if;
end $$;

commit;
