-- T-011 foundation only. This does not test posting, costing or lock enforcement.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(23);

insert into public.organizations (id, name) values
  ('d0110000-1100-4000-8000-000000000001', 'T-011 organization A'),
  ('d0110000-1100-4000-8000-000000000002', 'T-011 organization B');
insert into public.legal_entities (id, org_id, code, name) values
  ('d0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000001', 'T011A', 'T-011 entity A'),
  ('d0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000002', 'T011B', 'T-011 entity B');
insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101', 'T011A', 'T-011 property A'),
  ('d0110000-1100-4000-8000-000000000202', 'd0110000-1100-4000-8000-000000000002', 'd0110000-1100-4000-8000-000000000102', 'T011B', 'T-011 property B');
insert into public.warehouses (id, property_id, code, name, kind) values
  ('d0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000201', 'T011A', 'T-011 warehouse A', 'main'),
  ('d0110000-1100-4000-8000-000000000302', 'd0110000-1100-4000-8000-000000000202', 'T011B', 'T-011 warehouse B', 'main');
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0110000-1100-4000-8000-000000000401', 'd0110000-1100-4000-8000-000000000001', 'T011A', 'T-011 group A', 'food'),
  ('d0110000-1100-4000-8000-000000000402', 'd0110000-1100-4000-8000-000000000002', 'T011B', 'T-011 group B', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0110000-1100-4000-8000-000000000501', 'd0110000-1100-4000-8000-000000000001', 'T011A', 'T-011 item A', 'd0110000-1100-4000-8000-000000000401', 'kg'),
  ('d0110000-1100-4000-8000-000000000502', 'd0110000-1100-4000-8000-000000000002', 'T011B', 'T-011 item B', 'd0110000-1100-4000-8000-000000000402', 'kg');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values ('d0110000-1100-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 't011-foundation@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.lots (id, org_id, property_id, item_id, lot_no)
values ('d0110000-1100-4000-8000-000000000601', 'd0110000-1100-4000-8000-000000000001',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000501', 'T011');
insert into public.stock_moves (
  id, org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type,
  qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id
) overriding system value values (
  90110001, 'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 'd0110000-1100-4000-8000-000000000601',
  'receipt', 10, 100, 1000, '2026-01-01', 'd0110000-1100-4000-8000-000000000a01',
  'test', 'd0110000-1100-4000-8000-000000000701'
);

select ok((select bool_and(relrowsecurity) from pg_class where oid in (
  'public.lots'::regclass, 'public.stock_moves'::regclass, 'public.stock_balances'::regclass,
  'public.item_costs'::regclass, 'public.accounting_periods'::regclass, 'public.day_locks'::regclass
)), 'RLS is enabled on all six foundation tables');
select ok(not has_table_privilege('authenticated', 'public.stock_moves', 'select'), 'clients cannot read unfinished stock ledger');
select ok(not has_table_privilege('authenticated', 'public.stock_moves', 'insert'), 'clients cannot insert stock moves');
select ok(not has_table_privilege('authenticated', 'public.stock_balances', 'update'), 'clients cannot update balances');
select ok(not has_table_privilege('authenticated', 'public.item_costs', 'insert'), 'clients cannot insert item costs');
select ok(not has_table_privilege('authenticated', 'public.accounting_periods', 'update'), 'clients cannot change accounting periods');
select ok(not has_table_privilege('authenticated', 'public.day_locks', 'insert'), 'clients cannot create day locks');
select ok(not has_sequence_privilege('authenticated', 'public.stock_moves_id_seq', 'usage'), 'clients cannot consume ledger sequence');
select throws_ok($q$update public.stock_moves set qty = 11 where id = 90110001$q$,
  '55000', 'ERR_IMMUTABLE_LEDGER:stock_moves:UPDATE', 'stock moves cannot be updated');
select throws_ok($q$delete from public.stock_moves where id = 90110001$q$,
  '55000', 'ERR_IMMUTABLE_LEDGER:stock_moves:DELETE', 'stock moves cannot be deleted');
select throws_ok($q$insert into public.lots (org_id, property_id, item_id, lot_no)
  values ('d0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000201',
  'd0110000-1100-4000-8000-000000000502', 'CROSS')$q$, '23503', null, 'lots cannot reference items from another organization');
select throws_ok($q$insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, qty)
  values ('d0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000302',
  'd0110000-1100-4000-8000-000000000501', 1)$q$, '23503', null, 'balance warehouse must belong to property');
select throws_ok($q$insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, qty)
  values ('d0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', -1)$q$, '23514', null, 'negative balances are rejected');
insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, qty)
values ('d0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 0);
select throws_ok($q$insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, qty)
  values ('d0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 1)$q$, '23505', null, 'null lot balance is unique');
select throws_ok($q$insert into public.item_costs (org_id, legal_entity_id, item_id)
  values ('d0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000502')$q$, '23503', null, 'item cost cannot cross organizations');
select throws_ok($q$insert into public.accounting_periods (legal_entity_id, year, month, status)
  values ('d0110000-1100-4000-8000-000000000101', 2026, 1, 'closed')$q$,
  '23514', null, 'closed period must record actor and time');
select throws_ok($q$insert into public.day_locks (property_id, warehouse_id, business_date, locked_by)
  values ('d0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000302',
  '2026-01-01', 'd0110000-1100-4000-8000-000000000a01')$q$,
  '23503', null, 'day lock warehouse must belong to property');
select is((select count(*) from public.audit_log where table_name = 'lots'
  and row_id = 'd0110000-1100-4000-8000-000000000601'), 1::bigint, 'lot creation is audited');
select throws_ok($q$insert into public.stock_moves (
  org_id, legal_entity_id, property_id, warehouse_id, item_id, move_type,
  qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id
) values (
  'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 'receipt', 1, 100, 99, '2026-01-01',
  'd0110000-1100-4000-8000-000000000a01', 'test', 'd0110000-1100-4000-8000-000000000701'
)$q$, '23514', null, 'amount must match quantity and unit cost');
select throws_ok($q$insert into public.stock_moves (
  org_id, legal_entity_id, property_id, warehouse_id, item_id, move_type,
  qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id
) values (
  'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 'reversal', -1, 100, -100, '2026-01-01',
  'd0110000-1100-4000-8000-000000000a01', 'test', 'd0110000-1100-4000-8000-000000000701'
)$q$, '23514', null, 'reversal must reference an original move');
insert into public.stock_moves (
  org_id, legal_entity_id, property_id, warehouse_id, item_id, move_type, qty, unit_cost,
  amount, business_date, posted_by, source_doc_type, source_doc_id, reverses_move_id
) values (
  'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 'reversal', -10, 100, -1000, '2026-01-01',
  'd0110000-1100-4000-8000-000000000a01', 'test', 'd0110000-1100-4000-8000-000000000701', 90110001
);
select throws_ok($q$insert into public.stock_moves (
  org_id, legal_entity_id, property_id, warehouse_id, item_id, move_type, qty, unit_cost,
  amount, business_date, posted_by, source_doc_type, source_doc_id, reverses_move_id
) values (
  'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101',
  'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000301',
  'd0110000-1100-4000-8000-000000000501', 'reversal', -10, 100, -1000, '2026-01-01',
  'd0110000-1100-4000-8000-000000000a01', 'test', 'd0110000-1100-4000-8000-000000000701', 90110001
)$q$, '23505', null, 'original move cannot be reversed twice');
select throws_ok($q$insert into public.stock_moves (
  org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type,
  qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id
) values (
  'd0110000-1100-4000-8000-000000000002', 'd0110000-1100-4000-8000-000000000102',
  'd0110000-1100-4000-8000-000000000202', 'd0110000-1100-4000-8000-000000000302',
  'd0110000-1100-4000-8000-000000000502', 'd0110000-1100-4000-8000-000000000601',
  'receipt', 1, 100, 100, '2026-01-01', 'd0110000-1100-4000-8000-000000000a01',
  'test', 'd0110000-1100-4000-8000-000000000701'
)$q$, '23503', null, 'stock move cannot reference another property lot');
select ok(not has_table_privilege('anon', 'public.stock_moves', 'select'), 'anonymous users cannot read stock moves');

select * from finish();
rollback;
