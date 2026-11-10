-- C6 (completion wave 2 — route thieu page): `po_list` loc theo kenh
-- (migration 20261109525000).
-- Kiem tra:
--  1. `p_channel = 'market'` chi tra PO cho (supplier NULL van hien —
--     hoi quy LEFT JOIN suppliers ma 410000 vo tinh ve JOIN trong).
--  2. `p_channel = 'contract'` chi tra PO hop dong.
--  3. Khong truyen `p_channel` (mac dinh null) tra ca hai; dang goi cu
--     5 doi so van chay nho gia tri mac dinh.
--  4. Tim theo so chung tu van thay PO cho; loc ket hop channel + status.
--  5. Nguoi khong co quyen po.* bi ERR_FORBIDDEN.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
-- Fixture chen truc tiep (superuser, truoc khi doi role) theo mau T-020.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0c60000-0000-4000-8000-000000000001', 'C6 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0c60000-0000-4000-8000-000000000101', 'd0c60000-0000-4000-8000-000000000001', 'C6', 'Entity C6');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0c60000-0000-4000-8000-000000000201', 'd0c60000-0000-4000-8000-000000000001', 'd0c60000-0000-4000-8000-000000000101', 'PC6', 'Property C6', 'with_cc');

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('d0c60000-0000-4000-8000-000000000701', 'd0c60000-0000-4000-8000-000000000001', 'NCC_C6', 'Cong ty Gao Sach C6', 'company', 'active');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0c60000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-c6@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0c60000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-c6@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0c60000-0000-4000-8000-000000000a01', 'NVC601', 'Nguoi tao cho'),
  ('d0c60000-0000-4000-8000-000000000a02', 'NVC602', 'Nguoi ngoai');

insert into public.roles (id, org_id, code, name_vi) values
  ('d0c60000-0000-4000-8000-000000000601', 'd0c60000-0000-4000-8000-000000000001', 'purchaser', 'Mua hang');

insert into public.role_permissions (role_id, permission_code) values
  ('d0c60000-0000-4000-8000-000000000601', 'po.view'),
  ('d0c60000-0000-4000-8000-000000000601', 'po.create');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0c60000-0000-4000-8000-000000000a01', 'd0c60000-0000-4000-8000-000000000601', 'd0c60000-0000-4000-8000-000000000201');

-- 1 PO hop dong (co NCC) + 1 PO cho (supplier NULL).
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, doc_no, total_amount, status, created_by) values
  ('d0c60000-0000-4000-8000-000000000c01', 'd0c60000-0000-4000-8000-000000000001', 'd0c60000-0000-4000-8000-000000000101', 'd0c60000-0000-4000-8000-000000000201', 'd0c60000-0000-4000-8000-000000000701', 'contract', 'stock', 'PO-C6-001', 1000000, 'draft', 'd0c60000-0000-4000-8000-000000000a01'),
  ('d0c60000-0000-4000-8000-000000000c02', 'd0c60000-0000-4000-8000-000000000001', 'd0c60000-0000-4000-8000-000000000101', 'd0c60000-0000-4000-8000-000000000201', null, 'market', 'stock', 'PO-C6-002', 250000, 'draft', 'd0c60000-0000-4000-8000-000000000a01');

-- Helper doi user: dat lai JWT claim (mau T-020/Q73).
create or replace function public._tc6_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
end;
$$;

-- Chuyen sang role authenticated; doi user bang helper.
set local role authenticated;

-- 1. Loc market chi tra 1 PO cho.
select public._tc6_as('d0c60000-0000-4000-8000-000000000a01');
select is(
  (public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0, 'market') ->> 'total')::integer,
  1, 'po_list channel=market returns 1 row'
);
select is(
  public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0, 'market') -> 'rows' -> 0 ->> 'doc_no',
  'PO-C6-002', 'po_list channel=market returns the market PO'
);
select ok(
  (public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0, 'market') -> 'rows' -> 0 ->> 'supplier_name') is null,
  'po_list channel=market row has null supplier_name'
);
select is(
  public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0, 'market') -> 'rows' -> 0 ->> 'created_by_name',
  'Nguoi tao cho', 'po_list channel=market row keeps created_by_name (Q18)'
);

-- 2. Loc market + status khong khop tra 0.
select is(
  (public.po_list('d0c60000-0000-4000-8000-000000000201', 'submitted', null, 20, 0, 'market') ->> 'total')::integer,
  0, 'po_list channel=market + status=submitted returns 0 rows'
);

-- 3. Loc contract chi tra 1 PO hop dong.
select is(
  (public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0, 'contract') ->> 'total')::integer,
  1, 'po_list channel=contract returns 1 row'
);

-- 4. Khong loc channel tra ca hai (hoi quy LEFT JOIN: PO cho van hien).
select is(
  (public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0) ->> 'total')::integer,
  2, 'po_list without channel returns both POs'
);

-- 5. Tim theo so chung tu van thay PO cho.
select is(
  (public.po_list('d0c60000-0000-4000-8000-000000000201', null, 'PO-C6-002', 20, 0) ->> 'total')::integer,
  1, 'po_list search finds the market PO by doc_no'
);

-- 6. Nguoi khong co quyen po.* bi chan.
select public._tc6_as('d0c60000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.po_list('d0c60000-0000-4000-8000-000000000201', null, null, 20, 0, 'market')$q$,
  '42501', 'ERR_FORBIDDEN',
  'po_list channel=market forbidden without po.* perm'
);

select * from finish();
rollback;
