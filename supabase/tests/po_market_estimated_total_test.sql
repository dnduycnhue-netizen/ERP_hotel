-- po_market_estimated_total_test.sql (Q173, migration 20261109566000)
-- PO cho co dong chua gia: bat buoc tong uoc tinh; bac duyet theo so lon hon.
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

insert into public.organizations (id, name) values ('a1730000-0000-4000-8000-000000000001', 'Q173 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a1730000-0000-4000-8000-000000000101', 'a1730000-0000-4000-8000-000000000001', 'Q173', 'Entity Q173');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a1730000-0000-4000-8000-000000000201', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000101', 'PQ173', 'Property Q173', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('a1730000-0000-4000-8000-000000000401', 'a1730000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom, allowed_channels) values
  ('a1730000-0000-4000-8000-000000000501', 'a1730000-0000-4000-8000-000000000001', 'ITM_Q173', 'Gạo Q173', 'a1730000-0000-4000-8000-000000000401', 'kg', array['contract', 'market']);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a1730000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q173@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a1730000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q173@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a1730000-0000-4000-8000-000000000a01', 'NV Q173 01', 'Thu mua Q173'),
  ('a1730000-0000-4000-8000-000000000a02', 'NV Q173 02', 'Khac Q173')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a1730000-0000-4000-8000-000000000601', 'a1730000-0000-4000-8000-000000000001', 'q173_buyer', 'Thu mua Q173'),
  ('a1730000-0000-4000-8000-000000000602', 'a1730000-0000-4000-8000-000000000001', 'q173_step1', 'Duyet 1'),
  ('a1730000-0000-4000-8000-000000000603', 'a1730000-0000-4000-8000-000000000001', 'q173_step2', 'Duyet 2'),
  ('a1730000-0000-4000-8000-000000000604', 'a1730000-0000-4000-8000-000000000001', 'q173_other', 'Khac');
insert into public.role_permissions (role_id, permission_code) values
  ('a1730000-0000-4000-8000-000000000601', 'po.create'),
  ('a1730000-0000-4000-8000-000000000604', 'count.perform');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a1730000-0000-4000-8000-000000000a01', 'a1730000-0000-4000-8000-000000000601', 'a1730000-0000-4000-8000-000000000201'),
  ('a1730000-0000-4000-8000-000000000a02', 'a1730000-0000-4000-8000-000000000604', 'a1730000-0000-4000-8000-000000000201');
insert into public.approval_rules (org_id, property_id, doc_type, min_amount, max_amount, item_group_id, condition, step, approver_role_id, approver_user_id, required_perm) values
  ('a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000201', 'po', 0, 4999999, null, '{}', 1, 'a1730000-0000-4000-8000-000000000602', null, 'po.approve'),
  ('a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000201', 'po', 5000000, null, null, '{}', 2, 'a1730000-0000-4000-8000-000000000603', null, 'po.approve');

-- PO cho nhap truc tiep (bypass guard): m01 dong gia 0; m02 dong co gia 1tr; m03 PO thuong (contract).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, status, doc_no) values
  ('a1730000-0000-4000-8000-000000000d01', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000101', 'a1730000-0000-4000-8000-000000000201', null, 'market', 'stock', current_date, 'draft', 'PO-Q173-M01'),
  ('a1730000-0000-4000-8000-000000000d02', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000101', 'a1730000-0000-4000-8000-000000000201', null, 'market', 'stock', current_date, 'draft', 'PO-Q173-M02'),
  ('a1730000-0000-4000-8000-000000000d03', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000101', 'a1730000-0000-4000-8000-000000000201', null, 'market', 'stock', current_date, 'draft', 'PO-Q173-M03');
insert into public.purchase_order_lines (po_id, org_id, item_id, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('a1730000-0000-4000-8000-000000000d01', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000501', 10, 'kg', 10, 0, 'manual', 0),
  ('a1730000-0000-4000-8000-000000000d02', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000501', 10, 'kg', 10, 100000, 'manual', 0),
  ('a1730000-0000-4000-8000-000000000d03', 'a1730000-0000-4000-8000-000000000001', 'a1730000-0000-4000-8000-000000000501', 10, 'kg', 10, 0, 'manual', 0);

create temp table a173_resp (key text primary key, resp jsonb);
grant all on a173_resp to authenticated;
create or replace function public._a173_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;
select public._a173_as('a1730000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.po_set_estimated_total('a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d01', 8000000)$q$,
  '42501', null, 'user without po.create cannot set estimate');

select public._a173_as('a1730000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.po_submit('a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d01')$q$,
  'P0001', 'ERR_ESTIMATE_REQUIRED', 'market PO with unpriced line and no estimate cannot be submitted');
select throws_ok(
  $q$select public.po_set_estimated_total('a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d01', 0)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'estimate must be positive');

insert into a173_resp values ('set', public.po_set_estimated_total(
  'a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d01', 8000000));
select is((select resp ->> 'ok' from a173_resp where key = 'set'), 'true', 'estimate saved');

insert into a173_resp values ('sub', public.po_submit(
  'a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d01'));
select is((select resp ->> 'ok' from a173_resp where key = 'sub'), 'true', 'submit succeeds once estimate is set');
select is((select (resp ->> 'steps')::int from a173_resp where key = 'sub'), 2,
  'approval steps follow the estimate (8tr -> 2 steps), not the zero line total');

-- Dong da co gia: khong can uoc tinh, bac theo total_amount (1tr -> 1 buoc).
insert into a173_resp values ('sub2', public.po_submit(
  'a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d02'));
select is((select (resp ->> 'steps')::int from a173_resp where key = 'sub2'), 1,
  'fully priced market PO needs no estimate and uses its own total');

-- Uoc tinh nho hon tong that: lay so lon hon.
select public.po_set_estimated_total('a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d03', 1000000);
insert into a173_resp values ('sub3', public.po_submit(
  'a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d03'));
select is((select (resp ->> 'steps')::int from a173_resp where key = 'sub3'), 1,
  'small estimate (1tr) -> 1 step');

-- Chi PO cho dang draft.
select throws_ok(
  $q$select public.po_set_estimated_total('a1730000-0000-4000-8000-000000000201','a1730000-0000-4000-8000-000000000d01', 9000000)$q$,
  'P0001', 'ERR_INVALID_STATUS', 'cannot change estimate after submit');
reset role;
select is((select estimated_total from public.purchase_orders where id = 'a1730000-0000-4000-8000-000000000d01'),
  8000000.00::numeric, 'estimate unchanged after rejected change');

select finish();
rollback;
