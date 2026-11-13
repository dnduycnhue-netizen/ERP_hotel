-- demo_test_fixes_test.sql (Q267, migration 20261109573000)
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into public.organizations (id, name) values ('a5900000-0000-4000-8000-000000000001', 'Q267 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a5900000-0000-4000-8000-000000000101', 'a5900000-0000-4000-8000-000000000001', 'Q267', 'Entity Q267');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a5900000-0000-4000-8000-000000000201', 'a5900000-0000-4000-8000-000000000001', 'a5900000-0000-4000-8000-000000000101', 'PQ267', 'Property Q267', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('a5900000-0000-4000-8000-000000000301', 'a5900000-0000-4000-8000-000000000201', 'WH_Q267', 'Kho Q267', 'main', null);
select public.seed_compact_roles('a5900000-0000-4000-8000-000000000001');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a5900000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q267@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a5900000-0000-4000-8000-000000000a01', 'NV Q267 01', 'Thu mua Q267')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a5900000-0000-4000-8000-000000000601', 'a5900000-0000-4000-8000-000000000001', 'q267_buyer', 'Mua Q267');
insert into public.role_permissions (role_id, permission_code) values
  ('a5900000-0000-4000-8000-000000000601', 'po.create'),
  ('a5900000-0000-4000-8000-000000000601', 'receiving.perform');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a5900000-0000-4000-8000-000000000a01', 'a5900000-0000-4000-8000-000000000601', 'a5900000-0000-4000-8000-000000000201');

-- 2 PO nhap: cho (market) va hop dong (contract), moi PO 1 dong KHONG co ma hang.
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, channel, doc_no, status, kind, created_by) values
  ('a5900000-0000-4000-8000-000000000b01', 'a5900000-0000-4000-8000-000000000001', 'a5900000-0000-4000-8000-000000000101', 'a5900000-0000-4000-8000-000000000201', 'market', 'PO-Q267-M', 'draft', 'stock', 'a5900000-0000-4000-8000-000000000a01'),
  ('a5900000-0000-4000-8000-000000000b02', 'a5900000-0000-4000-8000-000000000001', 'a5900000-0000-4000-8000-000000000101', 'a5900000-0000-4000-8000-000000000201', 'contract', 'PO-Q267-C', 'draft', 'stock', 'a5900000-0000-4000-8000-000000000a01');
insert into public.purchase_order_lines (id, po_id, org_id, description, qty, uom, unit_price, price_source) values
  ('a5900000-0000-4000-8000-000000000c01', 'a5900000-0000-4000-8000-000000000b01', 'a5900000-0000-4000-8000-000000000001', 'Rau cu cho', 5, 'kg', 0, 'manual');
select set_config('app.pr_po_guard_bypass', 'off', true);

create or replace function public._a59_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;
select public._a59_as('a5900000-0000-4000-8000-000000000a01');

-- (1) PO cho: luu lai dong chi co mo ta + sua gia -> duoc.
select lives_ok(
  $q$select public.po_save_draft('a5900000-0000-4000-8000-000000000201', jsonb_build_object(
      'id', 'a5900000-0000-4000-8000-000000000b01',
      'lines', jsonb_build_array(jsonb_build_object(
        'id', 'a5900000-0000-4000-8000-000000000c01', 'item_id', null, 'description', 'Rau cu cho',
        'qty', 5, 'uom', 'kg', 'unit_price', 20000))))$q$,
  'market PO: a description-only line can be saved (unchanged item, new price)');
reset role;
select is((select unit_price from public.purchase_order_lines where id = 'a5900000-0000-4000-8000-000000000c01'), 20000::numeric,
  'market PO: the manual price was updated');
set local role authenticated;
select public._a59_as('a5900000-0000-4000-8000-000000000a01');
select lives_ok(
  $q$select public.po_save_draft('a5900000-0000-4000-8000-000000000201', jsonb_build_object(
      'id', 'a5900000-0000-4000-8000-000000000b01',
      'lines', jsonb_build_array(
        jsonb_build_object('id', 'a5900000-0000-4000-8000-000000000c01', 'item_id', null, 'description', 'Rau cu cho', 'qty', 5, 'uom', 'kg', 'unit_price', 20000),
        jsonb_build_object('item_id', null, 'description', 'Hanh la', 'qty', 2, 'uom', 'kg', 'unit_price', 30000))))$q$,
  'market PO: a new description-only line can be added');
-- Van chan o PO hop dong (kind stock, khong co ma hang).
select throws_ok(
  $q$select public.po_save_draft('a5900000-0000-4000-8000-000000000201', jsonb_build_object(
      'id', 'a5900000-0000-4000-8000-000000000b02',
      'lines', jsonb_build_array(jsonb_build_object('item_id', null, 'description', 'Khong ro', 'qty', 1, 'uom', 'kg'))))$q$,
  'P0001', 'ERR_INVALID_VALUE', 'contract stock PO still requires an item on every line');

-- (2) Quyen: ke toan xem duoc don mua, khong nhan hang.
create temp table a59_perms as
select r.code as role_code, rp.permission_code as perm
from public.roles r join public.role_permissions rp on rp.role_id = r.id
where r.org_id = 'a5900000-0000-4000-8000-000000000001' and r.code like 'sm\_%';
select is((select count(*) from a59_perms where role_code = 'sm_accountant' and perm in ('po.view', 'po.view_price', 'po.view_qty')), 3::bigint,
  'accountant role can view POs (needed by the invoice form)');
select is((select count(*) from a59_perms where role_code = 'sm_manager' and perm in ('po.view', 'po.view_price', 'po.view_qty')), 3::bigint,
  'manager role can view POs it approves');
select is((select count(*) from a59_perms where role_code = 'sm_owner' and perm = 'po.view_qty'), 1::bigint, 'owner role can view PO quantities');
select is((select count(distinct role_code) from a59_perms where perm in ('receiving.perform', 'receiving.post')), 0::bigint,
  'no compact role can receive goods (blind receiving intact)');
select is((select count(*) from public.role_permissions rp join public.roles r on r.id = rp.role_id
           where r.code in ('accountant', 'chief_accountant') and rp.permission_code = 'po.view'
             and r.org_id <> 'a5900000-0000-4000-8000-000000000001' and r.is_system), (select count(*) from public.roles where code in ('accountant', 'chief_accountant') and is_system and org_id <> 'a5900000-0000-4000-8000-000000000001'),
  'old accountant roles in existing organisations got po.view');

select finish();
rollback;
