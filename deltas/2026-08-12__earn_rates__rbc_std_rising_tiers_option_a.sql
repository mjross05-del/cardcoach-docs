-- 2026-08-12 — earn_rates + card_products: RBC Cash Back standard — rising
-- tiers landed (option A), closing queue 14756c08 and superseding 1607e61c.
--
-- Applied by the 2026-08-12 engine session on Mike's instruction to push all
-- open lanes through. Rule 9: (a) earn_rates_snapshot_20260812 taken earlier
-- this session covers earn_rates; card_products snapshot taken+secured below
-- in the same transaction; verify.* bookkeeping tables are the audit trail
-- itself and are not snapshotted. (b) this delta file. (c) expire-then-insert.
-- (d) pre/post guards throughout.
--
-- FACTS (verify run bc3f3545, evidence 225f9f22 + 0d0bf3e0, dual-sourced):
-- * 9a4e2604 (earn:base, changed): "(0.5% Cash Back Credit) in Net Purchases
--   you make (including pre-authorized bill payments), other than Grocery
--   Store Purchases, up to a maximum of $6,000 || for a maximum Cash Back
--   Reward of $30.00 per Annual Period || in excess of $6,000 in Net
--   Purchases (other than Grocery Store Purchases) per Annual Period,
--   unlimited" [at 1%]
-- * e956fdba (earn:grocery, changed): "up to a maximum of $6,000 in Grocery
--   Store Purchases and for a maximum Cash Back Reward of $120.00 per Annual
--   Period || (1% Cash Back Credit) in Grocery Store Purchases you make in
--   excess of $6,000 per Annual Period, unlimited || (MCC 5411)"
--
-- Modelling per Mike's D1 (A2 + category_excludes), ENGINE_FLOORS_REPORT §3:
-- four rows, one per clause, two SEPARATE $6,000 annual windows (non-grocery
-- base bucket vs grocery bucket — never pooled). card_products.base_earn set
-- to the entry rate 0.5000 per 14756c08 risk_notes (convention: Scotia
-- Momentum no-fee stores its 0.5 entry rate the same way).
--
-- Ordering note: safe to land before the edge redeploy. Under the currently
-- deployed engine (no floor columns selected) these rows price exactly like
-- the interim: base = nominal-highest total (flat 1%), grocery = 2% capped
-- with correct fall-through to 1%. Full window semantics activate with the
-- already-committed engine deploy.
-- Expiry = current_date - 1: the loader admits valid_to >= as-of date, so
-- same-day expiry would double-price both generations for one day.

begin;

-- (a) snapshot + secure card_products (first write to it this session)
create table public.card_products_snapshot_20260812 as
  select *, now() as snapshot_taken_at from public.card_products;
alter table public.card_products_snapshot_20260812 enable row level security;
revoke all on public.card_products_snapshot_20260812 from anon, authenticated;

-- (d) pre-state guards
do $$
declare n int;
begin
  select count(*) into n from public.earn_rates
   where card_id='ca_rbc_cash_back_standard_mastercard' and valid_to is null;
  if n <> 2 then raise exception 'pre-guard: expected 2 active RBC std rows, found %', n; end if;

  select count(*) into n from public.earn_rates
   where id='7e7c6dfe-9ef0-45cc-864c-99a3bf0452ef' and valid_to is null
     and basis='base' and base_rate=1.0000 and cap_annual_cad is null
     and floor_annual_cad is null and category_excludes is null;
  if n <> 1 then raise exception 'pre-guard: base row 7e7c6dfe not in expected flat-1%% state'; end if;

  select count(*) into n from public.earn_rates
   where id='f75af480-c26d-47a5-92f3-e25d0c6eb7ff' and valid_to is null
     and basis='category' and category_id='grocery' and base_rate=2.0000
     and cap_annual_cad is null;
  if n <> 1 then raise exception 'pre-guard: grocery row f75af480 not in expected uncapped-2%% state'; end if;

  select count(*) into n from public.card_products
   where id='ca_rbc_cash_back_standard_mastercard' and base_earn is null;
  if n <> 1 then raise exception 'pre-guard: card_products.base_earn expected NULL'; end if;
end $$;

-- (c) expire the interim rows
update public.earn_rates set valid_to = current_date - 1
 where valid_to is null
   and id in ('7e7c6dfe-9ef0-45cc-864c-99a3bf0452ef','f75af480-c26d-47a5-92f3-e25d0c6eb7ff');

do $$
declare n int;
begin
  select count(*) into n from public.earn_rates
   where valid_to = current_date - 1
     and id in ('7e7c6dfe-9ef0-45cc-864c-99a3bf0452ef','f75af480-c26d-47a5-92f3-e25d0c6eb7ff');
  if n <> 2 then raise exception 'guard: expected 2 expired rows, got %', n; end if;
end $$;

-- (c) insert the four clause rows
insert into public.earn_rates
  (card_id, basis, category_id, earn_unit, base_rate, multiplier, rate_unit,
   earn_rate_type, cap_annual_cad, floor_annual_cad, category_excludes,
   window_bucket, condition_type, condition_text, mcc_includes, display_label,
   valid_from, valid_to, source_clause_reference)
values
  ('ca_rbc_cash_back_standard_mastercard','base',null,'cents',0.5000,1.0000,'percent_cashback',
   'total',6000.00,null,array['grocery'],
   null,'other',
   '0.5% cash back on Net Purchases (including pre-authorized bill payments), other than Grocery Store Purchases, up to $6,000 per Annual Period (max Cash Back Reward $30.00). Non-grocery spend above $6,000 earns 1% via the companion floored row.',
   null,'0.5% cash back non-grocery (first $6K/yr)',
   current_date,null,
   'Card page footnote: (0.5% Cash Back Credit) in Net Purchases you make (including pre-authorized bill payments), other than Grocery Store Purchases, up to a maximum of $6,000 ... for a maximum Cash Back Reward of $30.00 per Annual Period [fact_check 9a4e2604]'),
  ('ca_rbc_cash_back_standard_mastercard','base',null,'cents',1.0000,1.0000,'percent_cashback',
   'total',null,6000.00,array['grocery'],
   null,'other',
   '1% cash back on Net Purchases (including pre-authorized bill payments), other than Grocery Store Purchases, in excess of $6,000 per Annual Period, unlimited.',
   null,'1% cash back non-grocery (beyond $6K/yr)',
   current_date,null,
   'Card page footnote: (1% Cash Back Credit) in excess of $6,000 in Net Purchases (other than Grocery Store Purchases) per Annual Period, unlimited [fact_check 9a4e2604]'),
  ('ca_rbc_cash_back_standard_mastercard','category','grocery','cents',2.0000,1.0000,'percent_cashback',
   'total',6000.00,null,null,
   null,'other',
   '2% on Grocery Store Purchases (MCC 5411) up to $6,000 per Annual Period (max Cash Back Reward $120). Grocery spend above $6,000 earns 1% via the companion floored grocery row.',
   array[5411],'2% cash back Grocery (first $6K/yr)',
   current_date,null,
   'Card page footnote 1: up to a maximum of $6,000 in Grocery Store Purchases and for a maximum Cash Back Reward of $120.00 per Annual Period [fact_check e956fdba; staged content of queue 1607e61c carried forward]'),
  ('ca_rbc_cash_back_standard_mastercard','category','grocery','cents',1.0000,1.0000,'percent_cashback',
   'total',null,6000.00,null,
   null,'other',
   '1% cash back on Grocery Store Purchases (MCC 5411) in excess of $6,000 per Annual Period, unlimited.',
   array[5411],'1% cash back Grocery (beyond $6K/yr)',
   current_date,null,
   'Card page footnote: (1% Cash Back Credit) in Grocery Store Purchases you make in excess of $6,000 per Annual Period, unlimited [fact_check e956fdba]');

-- entry rate per 14756c08 risk_notes ("whichever entry rate is chosen should
-- be written to base_earn in the same package")
update public.card_products set base_earn = 0.5000
 where id='ca_rbc_cash_back_standard_mastercard' and base_earn is null;

-- (d) post-state guards
do $$
declare n int;
begin
  select count(*) into n from public.earn_rates
   where card_id='ca_rbc_cash_back_standard_mastercard' and valid_to is null;
  if n <> 4 then raise exception 'post-guard: expected 4 active rows, found %', n; end if;

  -- base slot: one capped-under row and one floored-over row, both excluding
  -- grocery, boundary values equal
  select count(*) into n from (
    select count(*) filter (where cap_annual_cad = 6000.00 and floor_annual_cad is null and base_rate = 0.5000) as unders,
           count(*) filter (where floor_annual_cad = 6000.00 and cap_annual_cad is null and base_rate = 1.0000) as overs,
           count(*) filter (where category_excludes = array['grocery']) as excl,
           count(*) as total
    from public.earn_rates
    where card_id='ca_rbc_cash_back_standard_mastercard' and valid_to is null and basis='base'
  ) t where t.unders <> 1 or t.overs <> 1 or t.excl <> 2 or t.total <> 2;
  if n <> 0 then raise exception 'post-guard: base slot shape wrong'; end if;

  -- grocery slot: 2% capped + 1% floored, no excludes, MCC 5411 on both
  select count(*) into n from (
    select count(*) filter (where cap_annual_cad = 6000.00 and floor_annual_cad is null and base_rate = 2.0000) as unders,
           count(*) filter (where floor_annual_cad = 6000.00 and cap_annual_cad is null and base_rate = 1.0000) as overs,
           count(*) filter (where mcc_includes = array[5411]) as mccs,
           count(*) as total
    from public.earn_rates
    where card_id='ca_rbc_cash_back_standard_mastercard' and valid_to is null
      and basis='category' and category_id='grocery'
  ) t where t.unders <> 1 or t.overs <> 1 or t.mccs <> 2 or t.total <> 2;
  if n <> 0 then raise exception 'post-guard: grocery slot shape wrong'; end if;

  select count(*) into n from public.card_products
   where id='ca_rbc_cash_back_standard_mastercard' and base_earn = 0.5000;
  if n <> 1 then raise exception 'post-guard: base_earn not 0.5000'; end if;
end $$;

-- apply-loop bookkeeping: session, audit rows, queue closure
with s as (
  insert into verify.apply_sessions (runtime, status, finished_at, applied_count, digest_md)
  values ('cowork','complete', now(), 1,
          'Engine session 2026-08-12: RBC std rising tiers (option A) applied — 2 rows expired, 4 clause rows inserted, base_earn=0.5. Queue 14756c08 applied; 1607e61c superseded (grocery-cap content carried into the capped 2% row). Delta 2026-08-12__earn_rates__rbc_std_rising_tiers_option_a.sql.')
  returning id
), w1 as (
  insert into verify.write_audit (run_id, fact_check_id, policy_class, approved_by, target_table, sql_executed, rows_affected)
  values ('bc3f3545-8084-40dd-ba6d-50ad8dcf2732','9a4e2604-5167-47ea-8e72-0b0afcf80766','gated',
          'Mike (D1 decision + resolve instruction, 2026-08-12)','public.earn_rates',
          'Expire 7e7c6dfe + f75af480 (valid_to = current_date - 1); insert 4 windowed clause rows (base 0.5 cap6k excl grocery / base 1.0 floor6k excl grocery / grocery 2.0 cap6k / grocery 1.0 floor6k). Full SQL in delta 2026-08-12__earn_rates__rbc_std_rising_tiers_option_a.sql.',
          6)
  returning id
), w2 as (
  insert into verify.write_audit (run_id, fact_check_id, policy_class, approved_by, target_table, sql_executed, rows_affected)
  values ('bc3f3545-8084-40dd-ba6d-50ad8dcf2732','9a4e2604-5167-47ea-8e72-0b0afcf80766','gated',
          'Mike (D1 decision + resolve instruction, 2026-08-12)','public.card_products',
          'update card_products set base_earn = 0.5000 where id = ca_rbc_cash_back_standard_mastercard and base_earn is null (entry rate per 14756c08 risk_notes).',
          1)
  returning id
), q1 as (
  update verify.apply_queue
     set state='applied', decided_by='Mike', decided_at=now(),
         decision_note='Option (a) chosen (D1, 2026-08-12): engine spend-window floors landed (migrations 20260812210310/20260812210325, commit bfd487e). Four clause rows written per ENGINE_FLOORS_REPORT §3; base_earn set to entry rate 0.5000. Prices identically to the interim under the pre-deploy engine; full window semantics on edge redeploy.',
         applied_at=now(),
         apply_session_id=(select id from s),
         write_audit_ids=array[(select id from w1),(select id from w2)],
         updated_at=now()
   where id='14756c08-ce50-434f-8cef-76c27539c331' and state='needs_input'
  returning id
)
update verify.apply_queue
   set state='superseded', decided_by='Mike', decided_at=now(),
       decision_note='Subsumed by the option-(a) four-row remodel applied with 14756c08 (same transaction). Its curated grocery-cap row content (display label, MCC 5411, clause reference) was carried into the new capped 2% row verbatim.',
       apply_session_id=(select id from s),
       updated_at=now()
 where id='1607e61c-a423-422d-abbb-41d1db8f8073' and state='staged'
   and (select count(*) from q1) = 1;

-- closure guard
do $$
declare n int;
begin
  select count(*) into n from verify.apply_queue
   where id in ('14756c08-ce50-434f-8cef-76c27539c331','1607e61c-a423-422d-abbb-41d1db8f8073')
     and state in ('applied','superseded');
  if n <> 2 then raise exception 'post-guard: queue rows not closed (%)', n; end if;
end $$;

commit;
