-- T-010: run on a disposable database, or in one transaction that rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(34);

insert into public.organizations (id, name) values
  ('d0100000-0100-4000-8000-000000000001', 'T-010 organization A'),
  ('d0100000-0100-4000-8000-000000000002', 'T-010 organization B');
insert into public.legal_entities (id, org_id, code, name) values
  ('d0100000-0100-4000-8000-000000000101', 'd0100000-0100-4000-8000-000000000001', 'T010A', 'T-010 entity A'),
  ('d0100000-0100-4000-8000-000000000102', 'd0100000-0100-4000-8000-000000000002', 'T010B', 'T-010 entity B');
insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0100000-0100-4000-8000-000000000201', 'd0100000-0100-4000-8000-000000000001', 'd0100000-0100-4000-8000-000000000101', 'T010A', 'T-010 property A'),
  ('d0100000-0100-4000-8000-000000000202', 'd0100000-0100-4000-8000-000000000002', 'd0100000-0100-4000-8000-000000000102', 'T010B', 'T-010 property B');
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0100000-0100-4000-8000-000000000301', 'd0100000-0100-4000-8000-000000000001', 'T010', 'T-010 group A', 'food'),
  ('d0100000-0100-4000-8000-000000000302', 'd0100000-0100-4000-8000-000000000002', 'T010', 'T-010 group B', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0100000-0100-4000-8000-000000000401', 'd0100000-0100-4000-8000-000000000001', 'T010A', U&'  CA\0301I   H\00D4\0323P ', 'd0100000-0100-4000-8000-000000000301', 'cai'),
  ('d0100000-0100-4000-8000-000000000402', 'd0100000-0100-4000-8000-000000000002', 'T010B', 'Cái hộp', 'd0100000-0100-4000-8000-000000000302', 'cai');
insert into public.suppliers (id, org_id, code, name, kind) values
  ('d0100000-0100-4000-8000-000000000601', 'd0100000-0100-4000-8000-000000000001', 'T010A', 'T-010 supplier A', 'company'),
  ('d0100000-0100-4000-8000-000000000602', 'd0100000-0100-4000-8000-000000000002', 'T010B', 'T-010 supplier B', 'company');
insert into public.roles (id, org_id, code, name_vi) values
  ('d0100000-0100-4000-8000-000000000501', 'd0100000-0100-4000-8000-000000000001', 't010_reader', 'T-010 reader');
insert into public.role_permissions (role_id, permission_code) values
  ('d0100000-0100-4000-8000-000000000501', 'item.view');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values ('d0100000-0100-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 't010-reader@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.user_property_roles (user_id, role_id, property_id)
values ('d0100000-0100-4000-8000-000000000a01', 'd0100000-0100-4000-8000-000000000501', 'd0100000-0100-4000-8000-000000000201');
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, requested_by) values
  ('d0100000-0100-4000-8000-000000000001', 'd0100000-0100-4000-8000-000000000601', 'Test bank', 'T010-A', 'Test A', 'd0100000-0100-4000-8000-000000000a01'),
  ('d0100000-0100-4000-8000-000000000002', 'd0100000-0100-4000-8000-000000000602', 'Test bank', 'T010-B', 'Test B', 'd0100000-0100-4000-8000-000000000a01');
insert into public.price_agreements (org_id, supplier_id, valid_from, valid_to) values
  ('d0100000-0100-4000-8000-000000000001', 'd0100000-0100-4000-8000-000000000601', '2026-01-01', '2026-12-31'),
  ('d0100000-0100-4000-8000-000000000002', 'd0100000-0100-4000-8000-000000000602', '2026-01-01', '2026-12-31');
insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by) values
  ('d0100000-0100-4000-8000-000000000001', 'd0100000-0100-4000-8000-000000000201', 'd0100000-0100-4000-8000-000000000401', 'cai', 100, '2026-01-01', '2026-12-31', 'd0100000-0100-4000-8000-000000000a01'),
  ('d0100000-0100-4000-8000-000000000002', 'd0100000-0100-4000-8000-000000000202', 'd0100000-0100-4000-8000-000000000402', 'cai', 100, '2026-01-01', '2026-12-31', 'd0100000-0100-4000-8000-000000000a01');

select is(public.norm_text(U&'  CA\0301I   H\00D4\0323P '), 'cái hộp', 'normalizes NFC, case and whitespace');
select is((select name_norm from public.items where id = 'd0100000-0100-4000-8000-000000000401'), 'cái hộp', 'name_norm is generated');
select throws_ok($q$insert into public.items (org_id, code, name, group_id, stock_uom)
  values ('d0100000-0100-4000-8000-000000000001', 'T010_DUP', 'Cái hộp',
  'd0100000-0100-4000-8000-000000000301', 'cai')$q$, '23505', null, 'duplicate normalized item name rejected');
select is((select count(*) from public.items where name_norm = 'cái hộp'), 2::bigint, 'different organizations may use the same normalized name');
select throws_ok($q$insert into public.items (org_id, code, name, group_id, stock_uom)
  values ('d0100000-0100-4000-8000-000000000001', 'T010_X', 'Cross tenant',
  'd0100000-0100-4000-8000-000000000302', 'cai')$q$, '23503', null, 'item group cannot cross organizations');
select throws_ok($q$insert into public.item_purchase_units (org_id, item_id, uom, factor_to_stock, supplier_id)
  values ('d0100000-0100-4000-8000-000000000001', 'd0100000-0100-4000-8000-000000000401', 'cai', 1,
  'd0100000-0100-4000-8000-000000000602')$q$, '23503', null, 'purchase unit supplier cannot cross organizations');
select throws_ok($q$insert into public.approval_rules (org_id, doc_type, step, approver_role_id, item_group_id)
  values ('d0100000-0100-4000-8000-000000000001', 'po', 1,
  'd0100000-0100-4000-8000-000000000501', 'd0100000-0100-4000-8000-000000000302')$q$,
  'P0001', 'ERR_CONFIG_ITEM_GROUP', 'approval rule item group must belong to its organization');
select throws_ok($q$insert into public.uoms (code, name_vi) values ('KG', 'Uppercase')$q$,
  '23514', null, 'unit codes must be canonical lowercase');
select throws_ok($q$insert into public.item_purchase_units (org_id, item_id, uom, factor_to_stock)
  values ('d0100000-0100-4000-8000-000000000001', 'd0100000-0100-4000-8000-000000000401', 'kg', 0)$q$,
  '23514', null, 'conversion factor must be positive');
select is(public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'PO', '2026-01-01'), 'PO-T010A-2601-0001', 'first document number');
select is(public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'PO', '2026-02-01'), 'PO-T010A-2602-0002', 'counter continues across months');
select is(public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'PO', '2027-01-01'), 'PO-T010A-2701-0001', 'counter resets by year');
select is(public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'GR', '2026-01-01'), 'GR-T010A-2601-0001', 'counter is isolated by document type');
select is(public.next_doc_no('d0100000-0100-4000-8000-000000000102', 'PO', '2026-01-01'), 'PO-T010B-2601-0001', 'counter is isolated by legal entity');
update public.doc_sequences set last_no = 9999
where legal_entity_id = 'd0100000-0100-4000-8000-000000000101' and doc_type = 'PO' and year = 2026;
select is(public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'PO', '2026-01-01'), 'PO-T010A-2601-10000', 'counter does not truncate at 10000');
select throws_ok($q$select public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'PO', null)$q$,
  '22023', 'ERR_INVALID_DOCUMENT_NUMBER_INPUT', 'null business date rejected');
select ok(not has_function_privilege('authenticated', 'public.next_doc_no(uuid,text,date)', 'execute'), 'clients cannot allocate document numbers directly');
select ok(not has_table_privilege('authenticated', 'public.doc_sequences', 'select'), 'clients cannot read sequences');
select ok((select bool_and(relrowsecurity) from pg_class where oid in (
  'public.uoms'::regclass, 'public.item_groups'::regclass, 'public.items'::regclass,
  'public.suppliers'::regclass, 'public.item_purchase_units'::regclass, 'public.supplier_bank_accounts'::regclass,
  'public.price_agreements'::regclass, 'public.price_agreement_lines'::regclass, 'public.ceiling_prices'::regclass,
  'public.expense_categories'::regclass, 'public.doc_sequences'::regclass)), 'RLS enabled on all new tables');
select ok(not has_table_privilege('authenticated', 'public.supplier_bank_accounts', 'insert'), 'bank account workflow cannot be bypassed');
select ok(not has_table_privilege('authenticated', 'public.items', 'insert'), 'catalog writes wait for controlled workflows');
select is((select count(*) from public.audit_log where table_name = 'items' and row_id = 'd0100000-0100-4000-8000-000000000401'), 1::bigint, 'item creation is audited');
select set_config('request.jwt.claim.sub', 'd0100000-0100-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0100000-0100-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.items), 1::bigint, 'item reader sees only its own organization');
select is((select count(*) from public.item_groups), 1::bigint, 'item groups are isolated by organization');
select is((select count(*) from public.suppliers), 0::bigint, 'item permission alone cannot read suppliers');
select is((select count(*) from public.price_agreements), 0::bigint, 'item permission alone cannot read prices');
select is((select count(*) from public.uoms where code = 'kg'), 1::bigint, 'authenticated users can read canonical units');
select throws_ok($q$select public.next_doc_no('d0100000-0100-4000-8000-000000000101', 'PO', '2026-01-01')$q$,
  '42501', null, 'client invocation of sequence function denied');
select throws_ok($q$insert into public.items (org_id, code, name, group_id, stock_uom)
  values ('d0100000-0100-4000-8000-000000000001', 'T010_NO', 'Not allowed',
  'd0100000-0100-4000-8000-000000000301', 'cai')$q$, '42501', null, 'client cannot write item directly');
select is((select count(*) from public.supplier_bank_accounts), 0::bigint, 'item permission alone cannot read bank accounts');
reset role;
insert into public.role_permissions (role_id, permission_code) values
  ('d0100000-0100-4000-8000-000000000501', 'supplier.view'),
  ('d0100000-0100-4000-8000-000000000501', 'supplier.bank.request'),
  ('d0100000-0100-4000-8000-000000000501', 'price.view');
set local role authenticated;
select is((select count(*) from public.suppliers), 1::bigint, 'supplier permission exposes only own organization');
select is((select count(*) from public.supplier_bank_accounts), 1::bigint, 'bank permission exposes only own organization');
select is((select count(*) from public.price_agreements), 1::bigint, 'price permission exposes only own organization');
select is((select count(*) from public.ceiling_prices), 1::bigint, 'price permission exposes only own property');

select * from finish();
rollback;
