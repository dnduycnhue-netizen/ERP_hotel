-- Q73 + Q18 pgTAP: timeline duyet de nghi thanh toan + ten nguoi tao
-- o danh sach PR/PO (migration 20261109410000).
-- Kiem tra:
--  Q18: pr_list/po_list tra them created_by_name (join profiles).
--  Q73: approval_timeline ho tro doc_type 'payment_request' (quyen
--       payment.request/payment.approve/payment.mark_paid); policy
--       approvals_select cho doc dong payment_request; nguoi chi co
--       po.view bi ERR_FORBIDDEN; doc_type la bao ERR_INVALID_VALUE.
--  Hoi quy: approval_timeline 'pr'/'po' van chay nhu cu.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
-- Fixture chen truc tiep (superuser, truoc khi doi role) voi co
-- bypass nhu mau T-020/T-040; chi kiem duong DOC, khong kiem luong
-- tao de nghi (payment_request_create da co test o T-040).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0730000-0000-4000-8000-000000000001', 'Q73-Q18 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0730000-0000-4000-8000-000000000101', 'd0730000-0000-4000-8000-000000000001', 'Q73', 'Entity Q73-Q18');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0730000-0000-4000-8000-000000000201', 'd0730000-0000-4000-8000-000000000001', 'd0730000-0000-4000-8000-000000000101', 'P073', 'Property Q73-Q18', 'with_cc');

insert into public.cost_centers (id, org_id, code, name) values
  ('d0730000-0000-4000-8000-000000000311', 'd0730000-0000-4000-8000-000000000001', 'CC_KIT', 'Bếp');

insert into public.outlet_types (id, org_id, code, name) values
  ('d0730000-0000-4000-8000-000000000301', 'd0730000-0000-4000-8000-000000000001', 'KITCHEN', 'Bếp');

insert into public.outlets (id, property_id, outlet_type_id, cost_center_id, code, name) values
  ('d0730000-0000-4000-8000-000000000321', 'd0730000-0000-4000-8000-000000000201', 'd0730000-0000-4000-8000-000000000301', 'd0730000-0000-4000-8000-000000000311', 'KIT01', 'Bếp chính');

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('d0730000-0000-4000-8000-000000000701', 'd0730000-0000-4000-8000-000000000001', 'NCC_Q73', 'Công ty Gạo Sạch', 'company', 'active');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0730000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q73@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0730000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q73@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0730000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u3-q73@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0730000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-q73@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0730000-0000-4000-8000-000000000a01', 'NV07301', 'Người tạo mua'),
  ('d0730000-0000-4000-8000-000000000a02', 'NV07302', 'Kế toán trưởng'),
  ('d0730000-0000-4000-8000-000000000a03', 'NV07303', 'Chủ đầu tư'),
  ('d0730000-0000-4000-8000-000000000a04', 'NV07304', 'Chỉ xem PO');

insert into public.roles (id, org_id, code, name_vi) values
  ('d0730000-0000-4000-8000-000000000601', 'd0730000-0000-4000-8000-000000000001', 'purchaser', 'Mua hàng'),
  ('d0730000-0000-4000-8000-000000000602', 'd0730000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('d0730000-0000-4000-8000-000000000603', 'd0730000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0730000-0000-4000-8000-000000000604', 'd0730000-0000-4000-8000-000000000001', 'r_view073', 'Chỉ xem PO');

insert into public.role_permissions (role_id, permission_code) values
  ('d0730000-0000-4000-8000-000000000601', 'pr.create'),
  ('d0730000-0000-4000-8000-000000000601', 'po.create'),
  ('d0730000-0000-4000-8000-000000000601', 'po.view'),
  ('d0730000-0000-4000-8000-000000000601', 'payment.request'),
  ('d0730000-0000-4000-8000-000000000602', 'payment.approve'),
  ('d0730000-0000-4000-8000-000000000603', 'payment.approve'),
  ('d0730000-0000-4000-8000-000000000604', 'po.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0730000-0000-4000-8000-000000000a01', 'd0730000-0000-4000-8000-000000000601', 'd0730000-0000-4000-8000-000000000201'),
  ('d0730000-0000-4000-8000-000000000a02', 'd0730000-0000-4000-8000-000000000602', 'd0730000-0000-4000-8000-000000000201'),
  ('d0730000-0000-4000-8000-000000000a03', 'd0730000-0000-4000-8000-000000000603', 'd0730000-0000-4000-8000-000000000201'),
  ('d0730000-0000-4000-8000-000000000a04', 'd0730000-0000-4000-8000-000000000604', 'd0730000-0000-4000-8000-000000000201');

-- PR/PO do a01 tao (created_by = a01, co profile 'Người tạo mua').
insert into public.purchase_requests (id, org_id, legal_entity_id, property_id, outlet_id, doc_no, kind, status, created_by) values
  ('d0730000-0000-4000-8000-000000000c01', 'd0730000-0000-4000-8000-000000000001', 'd0730000-0000-4000-8000-000000000101', 'd0730000-0000-4000-8000-000000000201', 'd0730000-0000-4000-8000-000000000321', 'PR-Q73-001', 'stock', 'draft', 'd0730000-0000-4000-8000-000000000a01');

insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, doc_no, total_amount, status, created_by) values
  ('d0730000-0000-4000-8000-000000000c02', 'd0730000-0000-4000-8000-000000000001', 'd0730000-0000-4000-8000-000000000101', 'd0730000-0000-4000-8000-000000000201', 'd0730000-0000-4000-8000-000000000701', 'contract', 'stock', 'PO-Q73-001', 1000000, 'draft', 'd0730000-0000-4000-8000-000000000a01');

-- De nghi thanh toan + 2 buoc duyet (buoc 1 cho, buoc 2 da duyet boi a03).
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.payment_requests (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, total, status, created_by) values
  ('d0730000-0000-4000-8000-000000000c03', 'd0730000-0000-4000-8000-000000000001', 'd0730000-0000-4000-8000-000000000101', 'd0730000-0000-4000-8000-000000000201', 'd0730000-0000-4000-8000-000000000701', 'PAY-Q73-001', 500000, 'submitted', 'd0730000-0000-4000-8000-000000000a01');
select set_config('app.finance_guard_bypass', 'off', true);

select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.approvals (id, org_id, property_id, doc_type, doc_id, step, approver_role_id, approver_user_id, required_perm, decision, created_by) values
  ('d0730000-0000-4000-8000-000000000d01', 'd0730000-0000-4000-8000-000000000001', 'd0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03', 1, 'd0730000-0000-4000-8000-000000000602', null, 'payment.approve', 'pending', 'd0730000-0000-4000-8000-000000000a01'),
  ('d0730000-0000-4000-8000-000000000d02', 'd0730000-0000-4000-8000-000000000001', 'd0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03', 2, 'd0730000-0000-4000-8000-000000000603', null, 'payment.approve', 'approved', 'd0730000-0000-4000-8000-000000000a01');
update public.approvals
set decided_by = 'd0730000-0000-4000-8000-000000000a03',
    decided_at = now(),
    comment = 'Đã kiểm tra, đồng ý.'
where id = 'd0730000-0000-4000-8000-000000000d02';
select set_config('app.pr_po_guard_bypass', 'off', true);

-- Helper doi user: dat lai JWT claim (mau T-020).
create or replace function public._t073_as(p_user uuid)
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

-- 1. Q18: pr_list tra ten nguoi tao.
select public._t073_as('d0730000-0000-4000-8000-000000000a01');
select is(
  (public.pr_list('d0730000-0000-4000-8000-000000000201', null, null, 20, 0) ->> 'total')::integer,
  1, 'pr_list returns 1 row'
);
select is(
  public.pr_list('d0730000-0000-4000-8000-000000000201', null, null, 20, 0) -> 'rows' -> 0 ->> 'created_by_name',
  'Người tạo mua', 'pr_list returns creator full name'
);
select is(
  public.pr_list('d0730000-0000-4000-8000-000000000201', null, null, 20, 0) -> 'rows' -> 0 ->> 'created_by',
  'd0730000-0000-4000-8000-000000000a01', 'pr_list still returns created_by uuid'
);

-- 2. Q18: po_list tra ten nguoi tao.
select is(
  (public.po_list('d0730000-0000-4000-8000-000000000201', null, null, 20, 0) ->> 'total')::integer,
  1, 'po_list returns 1 row'
);
select is(
  public.po_list('d0730000-0000-4000-8000-000000000201', null, null, 20, 0) -> 'rows' -> 0 ->> 'created_by_name',
  'Người tạo mua', 'po_list returns creator full name'
);
select is(
  public.po_list('d0730000-0000-4000-8000-000000000201', null, null, 20, 0) -> 'rows' -> 0 ->> 'created_by',
  'd0730000-0000-4000-8000-000000000a01', 'po_list still returns created_by uuid'
);

-- 3. Q73: approval_timeline doc_type 'payment_request' (nguoi co payment.request).
select is(
  jsonb_array_length(public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps'),
  2, 'payment_request timeline has 2 steps for payment.request holder'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps' -> 0 ->> 'approver_role_name',
  'Kế toán trưởng', 'payment_request step 1 approver role name'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps' -> 0 ->> 'decision',
  'pending', 'payment_request step 1 is pending'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps' -> 1 ->> 'decision',
  'approved', 'payment_request step 2 is approved'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps' -> 1 ->> 'decided_by_name',
  'Chủ đầu tư', 'payment_request step 2 decided_by_name'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps' -> 1 ->> 'comment',
  'Đã kiểm tra, đồng ý.', 'payment_request step 2 comment'
);

-- Nguoi duyet (payment.approve) cung doc duoc timeline.
select public._t073_as('d0730000-0000-4000-8000-000000000a02');
select is(
  jsonb_array_length(public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03') -> 'steps'),
  2, 'payment_request timeline has 2 steps for payment.approve holder'
);

-- Nguoi chi co po.view khong doc duoc timeline de nghi thanh toan.
select public._t073_as('d0730000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'payment_request', 'd0730000-0000-4000-8000-000000000c03')$q$,
  '42501', 'ERR_FORBIDDEN',
  'payment_request timeline forbidden without payment.* perm'
);

-- doc_type la van bao ERR_INVALID_VALUE.
select public._t073_as('d0730000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'invoice', 'd0730000-0000-4000-8000-000000000c03')$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'unknown doc_type still rejected'
);

-- 4. Q73: policy approvals_select cho doc dong payment_request.
select is(
  (select count(*) from public.approvals
   where doc_type = 'payment_request'
     and doc_id = 'd0730000-0000-4000-8000-000000000c03'),
  2::bigint, 'approvals_select allows payment_request rows for payment.request holder'
);
select public._t073_as('d0730000-0000-4000-8000-000000000a04');
select is(
  (select count(*) from public.approvals
   where doc_type = 'payment_request'
     and doc_id = 'd0730000-0000-4000-8000-000000000c03'),
  0::bigint, 'approvals_select hides payment_request rows without payment.* perm'
);

-- 5. Hoi quy: approval_timeline 'pr'/'po' van chay.
select public._t073_as('d0730000-0000-4000-8000-000000000a01');
select is(
  (public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'pr', 'd0730000-0000-4000-8000-000000000c01') ->> 'ok')::boolean,
  true, 'pr timeline still returns ok'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'pr', 'd0730000-0000-4000-8000-000000000c01') -> 'steps',
  '[]'::jsonb, 'pr timeline steps empty (no approval rows for fixture PR)'
);
select is(
  (public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'po', 'd0730000-0000-4000-8000-000000000c02') ->> 'ok')::boolean,
  true, 'po timeline still returns ok'
);
select is(
  public.approval_timeline('d0730000-0000-4000-8000-000000000201', 'po', 'd0730000-0000-4000-8000-000000000c02') -> 'steps',
  '[]'::jsonb, 'po timeline steps empty (no approval rows for fixture PO)'
);

select * from finish();
rollback;
