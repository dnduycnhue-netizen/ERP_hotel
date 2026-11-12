-- q233_po_expected_date_default_test.sql
--
-- Q233 (migration 20261109561000): ngay giao PO.
--   (a) po_create_from_pr dat expected_date = order_date (ngay VN) cho PO moi.
--   (b) receiving_list_tasks coi expected_date NULL la den han.
--   (c) KHONG doi luat: PO hop dong 'approved' (chua gui NCC) van khong hien
--       trong man nhan hang; PO co ngay giao trong tuong lai van khong hien.
--
-- Diễn tập/chạy trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

-- Fixture: prefix a9d00000.
insert into public.organizations (id, name) values
  ('a9d00000-0000-4000-8000-000000000001', 'Q233 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a9d00000-0000-4000-8000-000000000101', 'a9d00000-0000-4000-8000-000000000001', 'Q233', 'Entity Q233');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a9d00000-0000-4000-8000-000000000201', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000101', 'PQ233', 'Property Q233', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('a9d00000-0000-4000-8000-000000000401', 'a9d00000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom, allowed_channels) values
  ('a9d00000-0000-4000-8000-000000000501', 'a9d00000-0000-4000-8000-000000000001', 'ITM_Q233', 'Gạo Q233', 'a9d00000-0000-4000-8000-000000000401', 'kg', array['contract', 'market']);
insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('a9d00000-0000-4000-8000-000000000701', 'a9d00000-0000-4000-8000-000000000001', 'NCC_Q233', 'NCC Q233', 'company', 'active');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a9d00000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q233@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a9d00000-0000-4000-8000-000000000a01', 'NV Q233', 'Thu mua Q233')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a9d00000-0000-4000-8000-000000000601', 'a9d00000-0000-4000-8000-000000000001', 'q233_role', 'Vai trò Q233');
insert into public.role_permissions (role_id, permission_code) values
  ('a9d00000-0000-4000-8000-000000000601', 'po.create'),
  ('a9d00000-0000-4000-8000-000000000601', 'receiving.perform');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a9d00000-0000-4000-8000-000000000a01', 'a9d00000-0000-4000-8000-000000000601', 'a9d00000-0000-4000-8000-000000000201');

-- PR da duyet + 1 dong (chen truc tiep, bypass guard PR/PO).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_requests (id, org_id, legal_entity_id, property_id, doc_no, kind, status) values
  ('a9d00000-0000-4000-8000-000000000b01', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000101', 'a9d00000-0000-4000-8000-000000000201', 'PR-Q233-0001', 'stock', 'approved');
insert into public.purchase_request_lines (id, pr_id, org_id, item_id, qty, uom) values
  ('a9d00000-0000-4000-8000-000000000c01', 'a9d00000-0000-4000-8000-000000000b01', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000501', 10, 'kg');

-- 4 PO fixture de thu receiving_list_tasks (chen truc tiep, bypass guard).
--  d01: contract, sent,     expected NULL          -> phai hien (b)
--  d02: contract, approved, expected NULL          -> KHONG hien (c)
--  d03: contract, sent,     expected = ngay mai    -> KHONG hien (c)
--  d04: contract, sent,     expected = hom nay     -> hien (khong doi)
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, status, doc_no) values
  ('a9d00000-0000-4000-8000-000000000d01', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000101', 'a9d00000-0000-4000-8000-000000000201', 'a9d00000-0000-4000-8000-000000000701', 'contract', 'stock', (now() at time zone 'Asia/Ho_Chi_Minh')::date, null, 'sent', 'PO-Q233-D01'),
  ('a9d00000-0000-4000-8000-000000000d02', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000101', 'a9d00000-0000-4000-8000-000000000201', 'a9d00000-0000-4000-8000-000000000701', 'contract', 'stock', (now() at time zone 'Asia/Ho_Chi_Minh')::date, null, 'approved', 'PO-Q233-D02'),
  ('a9d00000-0000-4000-8000-000000000d03', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000101', 'a9d00000-0000-4000-8000-000000000201', 'a9d00000-0000-4000-8000-000000000701', 'contract', 'stock', (now() at time zone 'Asia/Ho_Chi_Minh')::date, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1, 'sent', 'PO-Q233-D03'),
  ('a9d00000-0000-4000-8000-000000000d04', 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000101', 'a9d00000-0000-4000-8000-000000000201', 'a9d00000-0000-4000-8000-000000000701', 'contract', 'stock', (now() at time zone 'Asia/Ho_Chi_Minh')::date, (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'sent', 'PO-Q233-D04');
insert into public.purchase_order_lines (po_id, org_id, item_id, qty, uom, qty_stock, unit_price, price_source, received_qty_stock)
select p.id, 'a9d00000-0000-4000-8000-000000000001', 'a9d00000-0000-4000-8000-000000000501', 10, 'kg', 10, 10000, 'manual', 0
from public.purchase_orders p
where p.id in (
  'a9d00000-0000-4000-8000-000000000d01', 'a9d00000-0000-4000-8000-000000000d02',
  'a9d00000-0000-4000-8000-000000000d03', 'a9d00000-0000-4000-8000-000000000d04');

create temp table a9d_resp (key text primary key, resp jsonb);
grant all on a9d_resp to authenticated;
create or replace function public._a9d_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;
select public._a9d_as('a9d00000-0000-4000-8000-000000000a01');

-- (a) po_create_from_pr dat expected_date = order_date.
insert into a9d_resp values ('po', public.po_create_from_pr(
  'a9d00000-0000-4000-8000-000000000201',
  array['a9d00000-0000-4000-8000-000000000c01']::uuid[],
  'a9d00000-0000-4000-8000-000000000701',
  'contract'));
select is((select resp ->> 'ok' from a9d_resp where key = 'po'), 'true',
  'po_create_from_pr succeeds');
select is(
  (select po.expected_date from public.purchase_orders po
   where po.id = (select (resp ->> 'id')::uuid from a9d_resp where key = 'po')),
  (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  'new PO from PR has expected_date = today (VN)');
select is(
  (select po.expected_date = po.order_date from public.purchase_orders po
   where po.id = (select (resp ->> 'id')::uuid from a9d_resp where key = 'po')),
  true, 'new PO expected_date equals order_date');

-- (b)/(c) receiving_list_tasks.
insert into a9d_resp values ('tasks', public.receiving_list_tasks('a9d00000-0000-4000-8000-000000000201'));
select ok(
  exists (select 1 from jsonb_array_elements((select resp -> 'tasks' from a9d_resp where key = 'tasks')) t
          where t ->> 'doc_no' = 'PO-Q233-D01'),
  'sent contract PO with NULL expected_date is listed (NULL = due)');
select ok(
  not exists (select 1 from jsonb_array_elements((select resp -> 'tasks' from a9d_resp where key = 'tasks')) t
              where t ->> 'doc_no' = 'PO-Q233-D02'),
  'approved (not yet sent) contract PO stays hidden');
select ok(
  not exists (select 1 from jsonb_array_elements((select resp -> 'tasks' from a9d_resp where key = 'tasks')) t
              where t ->> 'doc_no' = 'PO-Q233-D03'),
  'PO with expected_date tomorrow stays hidden');
select ok(
  exists (select 1 from jsonb_array_elements((select resp -> 'tasks' from a9d_resp where key = 'tasks')) t
          where t ->> 'doc_no' = 'PO-Q233-D04'),
  'PO with expected_date today is still listed');
select is(
  (select jsonb_array_length(resp -> 'tasks') from a9d_resp where key = 'tasks'),
  2,
  'exactly the 2 due+sent POs are listed (draft PO from PR is not)');

select finish();
rollback;
