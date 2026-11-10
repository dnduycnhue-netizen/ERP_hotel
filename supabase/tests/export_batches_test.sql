-- C3 pgTAP: chong xuat trung — bang export_batches + RPC export_po_data /
-- export_bank_transfer / export_batch_record + cot export_status.
-- Cover: RLS + write-guard cua bang moi, quyen (co / khong / thieu
-- po.view_price / chua dang nhap), dau vao sai, du lieu PDF PO (dong +
-- timeline), danh sach chuyen khoan (chi de nghi DA DUYET, tai khoan
-- ngan hang ACTIVE moi nhat, co danh dau xuat truoc), ghi log + danh
-- dau export_status (ghi 2 lan van log du).
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(47);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0c30000-0000-4000-8000-000000000001', 'T-C3 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0c30000-0000-4000-8000-000000000101', 'd0c30000-0000-4000-8000-000000000001', 'TC3', 'Entity T-C3');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0c30000-0000-4000-8000-000000000201', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000101', 'PC31', 'Property T-C3', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0c30000-0000-4000-8000-000000000401', 'd0c30000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels) values
  ('d0c30000-0000-4000-8000-000000000501', 'd0c30000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0c30000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market']);

insert into public.suppliers (id, org_id, code, name, tax_code, kind, status) values
  ('d0c30000-0000-4000-8000-000000000701', 'd0c30000-0000-4000-8000-000000000001', 'NCC1', 'Công ty Gạo Sạch', '1234567890', 'company', 'active'),
  ('d0c30000-0000-4000-8000-000000000702', 'd0c30000-0000-4000-8000-000000000001', 'NCC2', 'Công ty Thịt Sạch', '0987654321', 'company', 'active');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0c30000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-pur-c3@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0c30000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u2-chief-c3@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0c30000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u3-acct-c3@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0c30000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-view-c3@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0c30000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u5-noperm-c3@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0c30000-0000-4000-8000-000000000a01', 'NVC301', 'Thu mua C3'),
  ('d0c30000-0000-4000-8000-000000000a02', 'NVC302', 'Kế toán trưởng C3'),
  ('d0c30000-0000-4000-8000-000000000a03', 'NVC303', 'Kế toán C3'),
  ('d0c30000-0000-4000-8000-000000000a04', 'NVC304', 'Chỉ xem C3'),
  ('d0c30000-0000-4000-8000-000000000a05', 'NVC305', 'Không quyền C3')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

-- Tai khoan ngan hang NCC1: 1 ACTIVE (Vietcombank) + 1 pending cu hon
-- (BIDV) — RPC phai lay dung ACTIVE moi nhat. NCC2 khong co tai khoan.
insert into public.supplier_bank_accounts (id, org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, approved_by, approved_at) values
  ('d0c30000-0000-4000-8000-000000000711', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000701', 'BIDV', '0000000001', 'CTY GAO SACH', 'pending', 'd0c30000-0000-4000-8000-000000000a01', null, null),
  ('d0c30000-0000-4000-8000-000000000712', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000701', 'Vietcombank', '1234567890', 'CTY GAO SACH', 'active', 'd0c30000-0000-4000-8000-000000000a01', 'd0c30000-0000-4000-8000-000000000a02', now());

insert into public.roles (id, org_id, code, name_vi) values
  ('d0c30000-0000-4000-8000-000000000601', 'd0c30000-0000-4000-8000-000000000001', 'purchaser', 'Thu mua'),
  ('d0c30000-0000-4000-8000-000000000602', 'd0c30000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('d0c30000-0000-4000-8000-000000000603', 'd0c30000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d0c30000-0000-4000-8000-000000000604', 'd0c30000-0000-4000-8000-000000000001', 'viewer', 'Chỉ xem'),
  ('d0c30000-0000-4000-8000-000000000605', 'd0c30000-0000-4000-8000-000000000001', 'outlet_head', 'Trưởng outlet'),
  ('d0c30000-0000-4000-8000-000000000606', 'd0c30000-0000-4000-8000-000000000001', 'gm', 'Giám đốc');

insert into public.role_permissions (role_id, permission_code) values
  ('d0c30000-0000-4000-8000-000000000601', 'po.view'),
  ('d0c30000-0000-4000-8000-000000000601', 'po.view_price'),
  ('d0c30000-0000-4000-8000-000000000601', 'po.create'),
  ('d0c30000-0000-4000-8000-000000000602', 'export.accounting'),
  ('d0c30000-0000-4000-8000-000000000602', 'payment.approve'),
  ('d0c30000-0000-4000-8000-000000000603', 'payment.request'),
  ('d0c30000-0000-4000-8000-000000000603', 'payment.mark_paid'),
  ('d0c30000-0000-4000-8000-000000000604', 'po.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0c30000-0000-4000-8000-000000000a01', 'd0c30000-0000-4000-8000-000000000601', 'd0c30000-0000-4000-8000-000000000201'),
  ('d0c30000-0000-4000-8000-000000000a02', 'd0c30000-0000-4000-8000-000000000602', 'd0c30000-0000-4000-8000-000000000201'),
  ('d0c30000-0000-4000-8000-000000000a03', 'd0c30000-0000-4000-8000-000000000603', 'd0c30000-0000-4000-8000-000000000201'),
  ('d0c30000-0000-4000-8000-000000000a04', 'd0c30000-0000-4000-8000-000000000604', 'd0c30000-0000-4000-8000-000000000201');

-- PO da duyet (2 dong = 500000 + 500000) + 2 buoc duyet.
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, total_amount, status, created_by, doc_no) values
  ('d0c30000-0000-4000-8000-000000000b01', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000101', 'd0c30000-0000-4000-8000-000000000201', 'd0c30000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-10', '2026-11-15', 1000000, 'approved', 'd0c30000-0000-4000-8000-000000000a01', 'PO-C3-001');
insert into public.purchase_order_lines (id, po_id, org_id, item_id, description, qty, uom, qty_stock, unit_price, price_source) values
  ('d0c30000-0000-4000-8000-000000000b11', 'd0c30000-0000-4000-8000-000000000b01', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000501', null, 10, 'kg', 10, 50000, 'manual'),
  ('d0c30000-0000-4000-8000-000000000b12', 'd0c30000-0000-4000-8000-000000000b01', 'd0c30000-0000-4000-8000-000000000001', null, 'Muối hạt', 20, 'kg', 20, 25000, 'manual');
insert into public.approvals (id, org_id, property_id, doc_type, doc_id, step, approver_role_id, required_perm, decision, decided_by, decided_at, comment, created_by) values
  ('d0c30000-0000-4000-8000-000000000b21', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000201', 'po', 'd0c30000-0000-4000-8000-000000000b01', 1, 'd0c30000-0000-4000-8000-000000000605', 'po.approve', 'approved', 'd0c30000-0000-4000-8000-000000000a02', now(), 'OK', 'd0c30000-0000-4000-8000-000000000a01'),
  ('d0c30000-0000-4000-8000-000000000b22', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000201', 'po', 'd0c30000-0000-4000-8000-000000000b01', 2, 'd0c30000-0000-4000-8000-000000000606', 'po.approve', 'pending', null, null, null, 'd0c30000-0000-4000-8000-000000000a01');
select set_config('app.pr_po_guard_bypass', 'off', true);

-- De nghi thanh toan: r01 approved (co bank), r02 approved (khong bank),
-- r03 submitted, r04 paid.
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.payment_requests (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, total, due_date, status, paid_at, created_by) values
  ('d0c30000-0000-4000-8000-000000000c01', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000101', 'd0c30000-0000-4000-8000-000000000201', 'd0c30000-0000-4000-8000-000000000701', 'DNTT-C3-001', 1500000, '2026-11-20', 'approved', null, 'd0c30000-0000-4000-8000-000000000a03'),
  ('d0c30000-0000-4000-8000-000000000c02', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000101', 'd0c30000-0000-4000-8000-000000000201', 'd0c30000-0000-4000-8000-000000000702', 'DNTT-C3-002', 500000, '2026-11-21', 'approved', null, 'd0c30000-0000-4000-8000-000000000a03'),
  ('d0c30000-0000-4000-8000-000000000c03', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000101', 'd0c30000-0000-4000-8000-000000000201', 'd0c30000-0000-4000-8000-000000000701', 'DNTT-C3-003', 200000, null, 'submitted', null, 'd0c30000-0000-4000-8000-000000000a03'),
  ('d0c30000-0000-4000-8000-000000000c04', 'd0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000101', 'd0c30000-0000-4000-8000-000000000201', 'd0c30000-0000-4000-8000-000000000701', 'DNTT-C3-004', 300000, '2026-11-19', 'paid', now(), 'd0c30000-0000-4000-8000-000000000a03');
select set_config('app.finance_guard_bypass', 'off', true);

-- A. Bang moi: guard chan ghi truc tiep, RLS bat, cot export_status co.
select throws_ok(
  $q$insert into public.export_batches (org_id, property_id, kind, ref_type, ref_id, exported_by)
    values ('d0c30000-0000-4000-8000-000000000001', 'd0c30000-0000-4000-8000-000000000201', 'po-pdf', 'purchase_order', 'd0c30000-0000-4000-8000-000000000b01', 'd0c30000-0000-4000-8000-000000000a01')$q$,
  'P0001', 'ERR_WRITE_GUARD: export_batches chi duoc ghi qua RPC',
  'Direct insert into export_batches is blocked by write guard'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.export_batches'::regclass),
  'export_batches has RLS enabled'
);

select ok(
  exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'purchase_orders' and column_name = 'export_status'),
  'purchase_orders has export_status column'
);

select ok(
  exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'payment_requests' and column_name = 'export_status'),
  'payment_requests has export_status column'
);

-- Helper doi user (mau T-043).
create or replace function public._tc3_as(p_user uuid)
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

-- Bang tam giu ket qua RPC (mau T-020/T-043).
create temp table tc3_resp (key text primary key, resp jsonb);

-- Tu day tro di chay duoi role authenticated (RLS co hieu luc).
set local role authenticated;

-- Chua dang nhap (chua dat JWT claim): ca 3 RPC deu chan 42501.
-- Phai test truoc lan _tc3_as dau tien (claim set 1 lan thi ton tai
-- het transaction).
select throws_ok(
  $q$select public.export_po_data('d0c30000-0000-4000-8000-000000000b01')$q$,
  '42501', 'ERR_FORBIDDEN',
  'Unauthenticated export_po_data is blocked'
);
select throws_ok(
  $q$select public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c01'::uuid])$q$,
  '42501', 'ERR_FORBIDDEN',
  'Unauthenticated export_bank_transfer is blocked'
);
select throws_ok(
  $q$select public.export_batch_record('po-pdf', 'purchase_order', array['d0c30000-0000-4000-8000-000000000b01'::uuid], null, null)$q$,
  '42501', 'ERR_FORBIDDEN',
  'Unauthenticated export_batch_record is blocked'
);

-- B. export_po_data: quyen + du lieu.
select public._tc3_as('d0c30000-0000-4000-8000-000000000a05');
select throws_ok(
  $q$select public.export_po_data('d0c30000-0000-4000-8000-000000000b01')$q$,
  '42501', 'ERR_FORBIDDEN:po.view',
  'User without po.view cannot export PO data'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.export_po_data('d0c30000-0000-4000-8000-000000000b01')$q$,
  '42501', 'ERR_FORBIDDEN:po.view_price',
  'User with po.view but no po.view_price cannot export priced PDF data'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.export_po_data('d0c30000-0000-4000-8000-000000000999')$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Unknown PO id is rejected'
);

insert into tc3_resp values ('po', public.export_po_data('d0c30000-0000-4000-8000-000000000b01'));
select is(
  (select resp->>'ok' from tc3_resp where key = 'po'),
  'true',
  'export_po_data returns ok'
);
select is(
  (select resp->'po'->>'doc_no' from tc3_resp where key = 'po'),
  'PO-C3-001',
  'export_po_data returns PO doc_no'
);
select is(
  (select resp->'po'->>'supplier_name' from tc3_resp where key = 'po'),
  'Công ty Gạo Sạch',
  'export_po_data returns supplier name'
);
select is(
  (select jsonb_array_length(resp->'lines') from tc3_resp where key = 'po'),
  2,
  'export_po_data returns 2 lines'
);
select is(
  (select (resp->'lines'->0->>'line_amount')::numeric from tc3_resp where key = 'po'),
  500000::numeric,
  'export_po_data line amount = qty * unit_price'
);
select is(
  (select (resp->'po'->>'total_amount')::numeric from tc3_resp where key = 'po'),
  1000000::numeric,
  'export_po_data returns PO total'
);
select is(
  (select jsonb_array_length(resp->'timeline') from tc3_resp where key = 'po'),
  2,
  'export_po_data returns 2 approval steps'
);
select is(
  (select resp->'timeline'->0->>'decision' from tc3_resp where key = 'po'),
  'approved',
  'export_po_data timeline step 1 is approved'
);

-- C. export_bank_transfer: quyen + dau vao + trang thai + ngan hang.
select public._tc3_as('d0c30000-0000-4000-8000-000000000a05');
select throws_ok(
  $q$select public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c01'::uuid])$q$,
  '42501', 'ERR_FORBIDDEN:export.accounting',
  'User without export.accounting/payment.mark_paid cannot export bank transfer'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.export_bank_transfer('{}'::uuid[])$q$,
  '22023', 'ERR_INVALID_INPUT',
  'Empty id list is rejected'
);
select throws_ok(
  $q$select public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000999'::uuid])$q$,
  '22023', 'ERR_INVALID_INPUT',
  'Unknown payment request id is rejected'
);
select throws_ok(
  $q$select public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c03'::uuid])$q$,
  'P0001', 'ERR_INVALID_STATUS: DNTT-C3-003',
  'Submitted (not approved) request is rejected'
);
select throws_ok(
  $q$select public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c04'::uuid])$q$,
  'P0001', 'ERR_INVALID_STATUS: DNTT-C3-004',
  'Already paid request is rejected'
);
select throws_ok(
  $q$select public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c02'::uuid])$q$,
  'P0001', 'ERR_BANK_ACCOUNT_MISSING: DNTT-C3-002',
  'Approved request without active bank account is rejected'
);

insert into tc3_resp values ('bt', public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c01'::uuid]));
select is(
  (select resp->>'ok' from tc3_resp where key = 'bt'),
  'true',
  'export_bank_transfer returns ok'
);
select is(
  (select jsonb_array_length(resp->'rows') from tc3_resp where key = 'bt'),
  1,
  'export_bank_transfer returns 1 row'
);
select is(
  (select resp->'rows'->0->>'bank_name' from tc3_resp where key = 'bt'),
  'Vietcombank',
  'export_bank_transfer picks latest ACTIVE bank account'
);
select is(
  (select resp->'rows'->0->>'account_no' from tc3_resp where key = 'bt'),
  '1234567890',
  'export_bank_transfer returns account number'
);
select is(
  (select resp->'rows'->0->>'content' from tc3_resp where key = 'bt'),
  'Thanh toán DNTT-C3-001',
  'export_bank_transfer builds transfer content from doc_no'
);
select is(
  (select (resp->'totals'->>'amount')::numeric from tc3_resp where key = 'bt'),
  1500000::numeric,
  'export_bank_transfer totals the amount'
);
select is(
  (select resp->'rows'->0->>'previously_exported_at' from tc3_resp where key = 'bt'),
  null,
  'Never-exported request has null previously_exported_at'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a03');
select is(
  (select (public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c01'::uuid])->>'ok')),
  'true',
  'Accountant with payment.mark_paid can export bank transfer'
);

-- D. export_batch_record: quyen + dau vao + log + danh dau.
select public._tc3_as('d0c30000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.export_batch_record('khong-co', 'purchase_order', array['d0c30000-0000-4000-8000-000000000b01'::uuid], null, null)$q$,
  '22023', 'ERR_INVALID_INPUT',
  'Unknown kind is rejected'
);
select throws_ok(
  $q$select public.export_batch_record('po-pdf', 'khong-co', array['d0c30000-0000-4000-8000-000000000b01'::uuid], null, null)$q$,
  '22023', 'ERR_INVALID_INPUT',
  'Unknown ref_type is rejected'
);
select throws_ok(
  $q$select public.export_batch_record('po-pdf', 'purchase_order', array['d0c30000-0000-4000-8000-000000000999'::uuid], null, null)$q$,
  '22023', 'ERR_INVALID_INPUT',
  'Unknown ref id is rejected'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a05');
select throws_ok(
  $q$select public.export_batch_record('po-pdf', 'purchase_order', array['d0c30000-0000-4000-8000-000000000b01'::uuid], null, null)$q$,
  '42501', 'ERR_FORBIDDEN:po.view',
  'User without po.view cannot record PO export'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a01');
insert into tc3_resp values ('rec-po', public.export_batch_record('po-pdf', 'purchase_order', array['d0c30000-0000-4000-8000-000000000b01'::uuid], '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', null));
select is(
  (select resp->>'ok' from tc3_resp where key = 'rec-po'),
  'true',
  'export_batch_record for PO returns ok'
);
select is(
  (select (resp->>'count')::integer from tc3_resp where key = 'rec-po'),
  1,
  'export_batch_record for PO records 1 batch'
);
select is(
  (select export_status from public.purchase_orders where id = 'd0c30000-0000-4000-8000-000000000b01'),
  'exported',
  'PO export_status is marked exported'
);
select ok(
  exists (select 1 from public.export_batches where kind = 'po-pdf' and ref_id = 'd0c30000-0000-4000-8000-000000000b01' and file_hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'),
  'export_batches has the PO batch row with file hash'
);

insert into tc3_resp values ('rec-po2', public.export_batch_record('po-pdf', 'purchase_order', array['d0c30000-0000-4000-8000-000000000b01'::uuid], 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210', null));
select is(
  (select resp->>'ok' from tc3_resp where key = 'rec-po2'),
  'true',
  'Re-export of the same PO is logged again (not blocked)'
);
select is(
  (select count(*)::integer from public.export_batches where kind = 'po-pdf' and ref_id = 'd0c30000-0000-4000-8000-000000000b01'),
  2,
  'Two batch rows exist after re-export'
);

select public._tc3_as('d0c30000-0000-4000-8000-000000000a02');
insert into tc3_resp values ('rec-bt', public.export_batch_record('bank-transfer', 'payment_request', array['d0c30000-0000-4000-8000-000000000c01'::uuid], 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', null));
select is(
  (select resp->>'ok' from tc3_resp where key = 'rec-bt'),
  'true',
  'export_batch_record for payment request returns ok'
);
select is(
  (select export_status from public.payment_requests where id = 'd0c30000-0000-4000-8000-000000000c01'),
  'exported',
  'Payment request export_status is marked exported'
);

insert into tc3_resp values ('rec-le', public.export_batch_record('goods-receipts', 'legal_entity', array['d0c30000-0000-4000-8000-000000000101'::uuid], 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', null));
select is(
  (select resp->>'ok' from tc3_resp where key = 'rec-le'),
  'true',
  'export_batch_record for legal entity returns ok'
);
select ok(
  exists (select 1 from public.export_batches where kind = 'goods-receipts' and ref_id = 'd0c30000-0000-4000-8000-000000000101' and property_id = 'd0c30000-0000-4000-8000-000000000201'),
  'Legal-entity batch row resolves the property'
);

-- C (tiep): sau khi ghi log, de nghi da xuat duoc danh dau.
select public._tc3_as('d0c30000-0000-4000-8000-000000000a02');
insert into tc3_resp values ('bt2', public.export_bank_transfer(array['d0c30000-0000-4000-8000-000000000c01'::uuid]));
select ok(
  (select resp->'rows'->0->>'previously_exported_at' from tc3_resp where key = 'bt2') is not null,
  'Previously exported request shows previously_exported_at'
);

rollback;
