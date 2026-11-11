-- T-042 pgTAP: hop dong dich vu + nghiem thu + lich dinh ky + cron.
-- Cover: RLS 3 bang moi, write-guard, service_contract_save (validate /
-- quyen / cap nhat), service_schedule_generate (monthly / quarterly /
-- yearly / per_visit / idempotent), service_accept (theo ky / theo PO /
-- SoD / rating / quyen / note Q81: co note + khong note), chan thanh
-- toan khi chua nghiem thu (Q72: invoice_match / invoice_approve / payment_request_create raise
-- ERR_SERVICE_NOT_ACCEPTED; sau nghiem thu so nhan = so luong PO),
-- service_maintenance (het han + alert gia han + dedupe), RLS doc.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(70);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0420000-0000-4000-8000-000000000001', 'T-042 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000001', 'T042', 'Entity T-042');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'P0421', 'Property T-042', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('cai', 'Cái')
on conflict do nothing;

insert into public.suppliers (id, org_id, code, name, kind, status, payment_terms_days, bank_changed_at) values
  ('d0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000001', 'NCC1', 'Công ty Thang máy An Toàn', 'company', 'active', 30, null),
  ('d0420000-0000-4000-8000-000000000702', 'd0420000-0000-4000-8000-000000000001', 'NCC2', 'Công ty Vệ sinh Sạch', 'company', 'active', 0, null),
  ('d0420000-0000-4000-8000-000000000703', 'd0420000-0000-4000-8000-000000000001', 'NCC3', 'Công ty Ngừng HĐ', 'company', 'suspended', 0, null);

insert into public.cost_centers (id, org_id, code, name) values
  ('d0420000-0000-4000-8000-000000000301', 'd0420000-0000-4000-8000-000000000001', 'ENG', 'Kỹ thuật');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000001', 'MAINT', 'Bảo trì');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0420000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-acct042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0420000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-chief042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0420000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-gm042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0420000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-own042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0420000-0000-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u5-pur042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0420000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-eng042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0420000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-stk042@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0420000-0000-4000-8000-000000000a01', 'NV04201', 'Kế toán'),
  ('d0420000-0000-4000-8000-000000000a02', 'NV04202', 'Kế toán trưởng'),
  ('d0420000-0000-4000-8000-000000000a03', 'NV04203', 'Tổng quản lý'),
  ('d0420000-0000-4000-8000-000000000a04', 'NV04204', 'Chủ đầu tư'),
  ('d0420000-0000-4000-8000-000000000a05', 'NV04205', 'Thu mua'),
  ('d0420000-0000-4000-8000-000000000a06', 'NV04206', 'Kỹ sư'),
  ('d0420000-0000-4000-8000-000000000a07', 'NV04207', 'Thủ kho')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0420000-0000-4000-8000-000000000601', 'd0420000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d0420000-0000-4000-8000-000000000602', 'd0420000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('d0420000-0000-4000-8000-000000000603', 'd0420000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0420000-0000-4000-8000-000000000604', 'd0420000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0420000-0000-4000-8000-000000000605', 'd0420000-0000-4000-8000-000000000001', 'purchaser', 'Mua hàng'),
  ('d0420000-0000-4000-8000-000000000606', 'd0420000-0000-4000-8000-000000000001', 'engineer', 'Kỹ sư'),
  ('d0420000-0000-4000-8000-000000000607', 'd0420000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho');

-- gm giu ca 2 quyen de test SoD nghiem thu (chi trong fixture nay).
-- Ke toan a01 doc alerts o §7: policy alerts_select doi
-- 'alert.receive.' || lower(code) = 'alert.receive.service_contract_renewal'
-- (seed 380000, gan cho owner/gm/chief_accountant); fixture phai gan
-- ro cho vai tro doc alerts, neu khong count(*) tra 0.
insert into public.role_permissions (role_id, permission_code) values
  ('d0420000-0000-4000-8000-000000000601', 'invoice.manage'),
  ('d0420000-0000-4000-8000-000000000601', 'payment.request'),
  ('d0420000-0000-4000-8000-000000000601', 'ap.view'),
  ('d0420000-0000-4000-8000-000000000601', 'alert.receive.service_contract_renewal'),
  ('d0420000-0000-4000-8000-000000000602', 'invoice.approve'),
  ('d0420000-0000-4000-8000-000000000602', 'payment.approve'),
  ('d0420000-0000-4000-8000-000000000603', 'service.contract.manage'),
  ('d0420000-0000-4000-8000-000000000603', 'service.accept'),
  ('d0420000-0000-4000-8000-000000000604', 'service.contract.manage'),
  ('d0420000-0000-4000-8000-000000000604', 'payment.approve'),
  ('d0420000-0000-4000-8000-000000000604', 'ap.view'),
  ('d0420000-0000-4000-8000-000000000604', 'invoice.approve'),
  ('d0420000-0000-4000-8000-000000000606', 'service.accept');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0420000-0000-4000-8000-000000000a01', 'd0420000-0000-4000-8000-000000000601', 'd0420000-0000-4000-8000-000000000201'),
  ('d0420000-0000-4000-8000-000000000a02', 'd0420000-0000-4000-8000-000000000602', 'd0420000-0000-4000-8000-000000000201'),
  ('d0420000-0000-4000-8000-000000000a03', 'd0420000-0000-4000-8000-000000000603', 'd0420000-0000-4000-8000-000000000201'),
  ('d0420000-0000-4000-8000-000000000a04', 'd0420000-0000-4000-8000-000000000604', null),
  ('d0420000-0000-4000-8000-000000000a05', 'd0420000-0000-4000-8000-000000000605', 'd0420000-0000-4000-8000-000000000201'),
  ('d0420000-0000-4000-8000-000000000a06', 'd0420000-0000-4000-8000-000000000606', 'd0420000-0000-4000-8000-000000000201'),
  ('d0420000-0000-4000-8000-000000000a07', 'd0420000-0000-4000-8000-000000000607', 'd0420000-0000-4000-8000-000000000201');

-- Hop dong fixture (chen truc tiep, bypass service guard).
select set_config('app.service_guard_bypass', 'on', true);
insert into public.service_contracts (id, org_id, legal_entity_id, property_id, supplier_id, expense_category_id, cost_center_id, title, start_date, end_date, billing_cycle, amount_per_cycle, renew_notice_days, status, created_by) values
  ('d0420000-0000-4000-8000-000000000d01', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000301', 'Bảo trì thang máy', '2026-11-01', '2027-10-31', 'monthly', 5000000, 30, 'active', 'd0420000-0000-4000-8000-000000000a05'),
  ('d0420000-0000-4000-8000-000000000d02', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000301', 'Bảo trì hệ thống lạnh', '2026-10-01', '2027-09-30', 'quarterly', 15000000, 30, 'active', 'd0420000-0000-4000-8000-000000000a05'),
  ('d0420000-0000-4000-8000-000000000d03', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000301', 'Bảo hiểm cháy nổ', '2026-01-01', '2026-12-31', 'yearly', 60000000, 30, 'active', 'd0420000-0000-4000-8000-000000000a05'),
  ('d0420000-0000-4000-8000-000000000d04', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000301', 'Sửa chữa theo lượt', '2026-11-01', null, 'per_visit', 2000000, 30, 'active', 'd0420000-0000-4000-8000-000000000a05'),
  ('d0420000-0000-4000-8000-000000000d05', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000301', 'Vệ sinh kính (tạm ngưng)', '2026-11-01', '2027-10-31', 'monthly', 3000000, 30, 'suspended', 'd0420000-0000-4000-8000-000000000a05');
select set_config('app.service_guard_bypass', 'off', true);

-- PO dich vu fixture (chen truc tiep, bypass pr_po).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, status, created_by, doc_no, service_contract_id) values
  ('d0420000-0000-4000-8000-000000000b01', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-09', '2026-11-09', 'sent', 'd0420000-0000-4000-8000-000000000a05', 'PO-042-001', 'd0420000-0000-4000-8000-000000000d01'),
  ('d0420000-0000-4000-8000-000000000b02', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-09', '2026-11-09', 'sent', 'd0420000-0000-4000-8000-000000000a05', 'PO-042-002', null),
  ('d0420000-0000-4000-8000-000000000b03', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-09', '2026-11-09', 'sent', 'd0420000-0000-4000-8000-000000000a06', 'PO-042-003', null);

insert into public.purchase_order_lines (id, po_id, org_id, item_id, description, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('d0420000-0000-4000-8000-000000000c01', 'd0420000-0000-4000-8000-000000000b01', 'd0420000-0000-4000-8000-000000000001', null, 'Bảo trì thang máy tháng 11', 1, 'cai', 1, 5000000, 'manual', 0),
  ('d0420000-0000-4000-8000-000000000c02', 'd0420000-0000-4000-8000-000000000b02', 'd0420000-0000-4000-8000-000000000001', null, 'Sửa điều hòa', 1, 'cai', 1, 2000000, 'manual', 0),
  ('d0420000-0000-4000-8000-000000000c03', 'd0420000-0000-4000-8000-000000000b02', 'd0420000-0000-4000-8000-000000000001', null, 'Thay gas điều hòa', 1, 'cai', 1, 1000000, 'manual', 0),
  ('d0420000-0000-4000-8000-000000000c04', 'd0420000-0000-4000-8000-000000000b03', 'd0420000-0000-4000-8000-000000000001', null, 'Vệ sinh bể nước', 1, 'cai', 1, 1500000, 'manual', 0);
select set_config('app.pr_po_guard_bypass', 'off', true);

-- Hoa don truc tiep (chen truc tiep, bypass finance) de test duong chan
-- o invoice_approve / payment_request_create khi chua nghiem thu.
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.supplier_invoices (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date, amount_before_tax, vat_amount, total, status, created_by) values
  ('d0420000-0000-4000-8000-000000000e02', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'INV-042-002', 'AA', '0000002', '2026-11-09', 2000000, 200000, 2200000, 'matched', 'd0420000-0000-4000-8000-000000000a01'),
  ('d0420000-0000-4000-8000-000000000e03', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'INV-042-003', 'AA', '0000003', '2026-11-09', 2000000, 200000, 2200000, 'approved', 'd0420000-0000-4000-8000-000000000a01');
insert into public.supplier_invoice_lines (id, invoice_id, org_id, property_id, po_line_id, gr_line_id, item_id, qty, unit_price, amount, vat_rate, vat_amount) values
  ('d0420000-0000-4000-8000-000000000e12', 'd0420000-0000-4000-8000-000000000e02', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000c02', null, null, 1, 2000000, 2000000, 10, 200000),
  ('d0420000-0000-4000-8000-000000000e13', 'd0420000-0000-4000-8000-000000000e03', 'd0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000c02', null, null, 1, 2000000, 2000000, 10, 200000);
select set_config('app.finance_guard_bypass', 'off', true);

-- Bang tam giu id / response (mau T-040).
create temp table t042_ctx (key text primary key, id uuid);
create temp table t042_resp (key text primary key, resp jsonb);
grant all on table t042_ctx to authenticated;
grant all on table t042_resp to authenticated;

-- Helper doi user: dat lai JWT claim (mau T-020/T-040).
create or replace function public._t042_as(p_user uuid)
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

-- 1. RLS bat cho 3 bang moi.
select is((select relrowsecurity from pg_class where relname = 'service_contracts'), true, 'service_contracts has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'service_schedules'), true, 'service_schedules has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'service_acceptances'), true, 'service_acceptances has RLS enabled');

-- 2. Guard: ghi truc tiep bi chan (chay truoc khi doi role authenticated;
--    superuser bo qua RLS nhung trigger van chay).
select throws_ok(
  $q$insert into public.service_contracts (org_id, legal_entity_id, property_id, supplier_id, expense_category_id, cost_center_id, title, start_date, billing_cycle, amount_per_cycle) values ('d0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', 'd0420000-0000-4000-8000-000000000302', 'd0420000-0000-4000-8000-000000000301', 'X', '2026-11-01', 'monthly', 100)$q$,
  'P0001', 'ERR_WRITE_GUARD: service_contracts chi duoc ghi qua RPC',
  'Direct service_contracts insert is blocked by trigger'
);
select throws_ok(
  $q$insert into public.service_schedules (org_id, legal_entity_id, property_id, contract_id, period_start, period_end, due_date) values ('d0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000d01', '2026-11-01', '2026-11-30', '2026-11-30')$q$,
  'P0001', 'ERR_WRITE_GUARD: service_schedules chi duoc ghi qua RPC',
  'Direct service_schedules insert is blocked by trigger'
);
select throws_ok(
  $q$insert into public.service_acceptances (org_id, legal_entity_id, property_id, schedule_id) values ('d0420000-0000-4000-8000-000000000001', 'd0420000-0000-4000-8000-000000000101', 'd0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000001')$q$,
  'P0001', 'ERR_WRITE_GUARD: service_acceptances chi duoc ghi qua RPC',
  'Direct service_acceptances insert is blocked by trigger'
);

-- Tu day tro di chay duoi role authenticated (RLS co hieu luc).
set local role authenticated;

-- 3. service_contract_save (gm a03).
select public._t042_as('d0420000-0000-4000-8000-000000000a03');
insert into t042_resp values ('ct_sod', public.service_contract_save(
  'd0420000-0000-4000-8000-000000000201',
  '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "Vệ sinh bể nước định kỳ", "start_date": "2026-11-01", "end_date": "2027-10-31", "billing_cycle": "monthly", "amount_per_cycle": 1000000}'::jsonb
));
insert into t042_ctx values ('ct_sod', (select (resp ->> 'id')::uuid from t042_resp where key = 'ct_sod'));
select is((select resp ->> 'status' from t042_resp where key = 'ct_sod'), 'active', 'contract created via RPC is active');
select is((select resp ->> 'billing_cycle' from t042_resp where key = 'ct_sod'), 'monthly', 'contract billing_cycle is monthly');

-- Validate.
select throws_ok(
  $q$select public.service_contract_save('d0420000-0000-4000-8000-000000000201', '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "X", "start_date": "2026-11-01", "billing_cycle": "weekly", "amount_per_cycle": 100}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'bad billing_cycle is rejected'
);
select throws_ok(
  $q$select public.service_contract_save('d0420000-0000-4000-8000-000000000201', '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "X", "start_date": "2026-11-01", "end_date": "2026-10-31", "billing_cycle": "monthly", "amount_per_cycle": 100}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'end before start is rejected'
);
select throws_ok(
  $q$select public.service_contract_save('d0420000-0000-4000-8000-000000000201', '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "X", "start_date": "2026-11-01", "billing_cycle": "monthly", "amount_per_cycle": -5}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'negative amount is rejected'
);
select throws_ok(
  $q$select public.service_contract_save('d0420000-0000-4000-8000-000000000201', '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "title": "X", "start_date": "2026-11-01", "billing_cycle": "monthly", "amount_per_cycle": 100}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'missing cost_center_id is rejected'
);
select throws_ok(
  $q$select public.service_contract_save('d0420000-0000-4000-8000-000000000201', '{"supplier_id": "d0420000-0000-4000-8000-000000000703", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "X", "start_date": "2026-11-01", "billing_cycle": "monthly", "amount_per_cycle": 100}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'suspended supplier is rejected'
);

-- Sai quyen: ky su khong co service.contract.manage.
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.service_contract_save('d0420000-0000-4000-8000-000000000201', '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "X", "start_date": "2026-11-01", "billing_cycle": "monthly", "amount_per_cycle": 100}'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:service.contract.manage',
  'engineer cannot save a contract'
);

-- Cap nhat: gm doi so tien hop dong thang (fixture) 5tr -> 6tr.
select public._t042_as('d0420000-0000-4000-8000-000000000a03');
insert into t042_resp values ('ct_upd', public.service_contract_save(
  'd0420000-0000-4000-8000-000000000201',
  '{"supplier_id": "d0420000-0000-4000-8000-000000000701", "expense_category_id": "d0420000-0000-4000-8000-000000000302", "cost_center_id": "d0420000-0000-4000-8000-000000000301", "title": "Bảo trì thang máy", "start_date": "2026-11-01", "end_date": "2027-10-31", "billing_cycle": "monthly", "amount_per_cycle": 6000000}'::jsonb,
  'd0420000-0000-4000-8000-000000000d01'
));
select is((select amount_per_cycle from public.service_contracts where id = 'd0420000-0000-4000-8000-000000000d01'), 6000000::numeric, 'contract amount updated to 6000000');

-- Fixture hop dong dung nhu ky vong.
select is((select billing_cycle from public.service_contracts where id = 'd0420000-0000-4000-8000-000000000d01'), 'monthly', 'monthly fixture contract exists');
select is((select status from public.service_contracts where id = 'd0420000-0000-4000-8000-000000000d05'), 'suspended', 'suspended fixture contract exists');

-- 4. service_schedule_generate thang 11/2026 (gm a03).
insert into t042_resp values ('gen1', public.service_schedule_generate('2026-11-01'::date));
select is((select (resp ->> 'generated')::integer from t042_resp where key = 'gen1'), 4, 'generate Nov 2026 creates 4 schedules (monthly + quarterly + yearly + SoD)');
select is((select (resp ->> 'existing')::integer from t042_resp where key = 'gen1'), 0, 'generate Nov 2026 existing = 0');
select is((select (resp ->> 'skipped_per_visit')::integer from t042_resp where key = 'gen1'), 1, 'per_visit contract is skipped');

select is((select period_start from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d01'), '2026-11-01'::date, 'monthly period starts Nov 1');
select is((select period_end from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d01'), '2026-11-30'::date, 'monthly period ends Nov 30');
select is((select due_date from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d01'), '2026-11-30'::date, 'monthly due_date = period_end');
select is((select period_start from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d02'), '2026-10-01'::date, 'quarterly period starts Oct 1');
select is((select period_end from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d02'), '2026-12-31'::date, 'quarterly period ends Dec 31');
select is((select period_start from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03'), '2026-01-01'::date, 'yearly period starts Jan 1');
select is((select period_end from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03'), '2026-12-31'::date, 'yearly period ends Dec 31');

-- Chay lai: idempotent, khong sinh trung.
insert into t042_resp values ('gen2', public.service_schedule_generate('2026-11-01'::date));
select is((select (resp ->> 'generated')::integer from t042_resp where key = 'gen2'), 0, 'second generate creates 0 schedules');
select is((select (resp ->> 'existing')::integer from t042_resp where key = 'gen2'), 4, 'second generate existing = 4');

-- per_visit khong co lich; thang null bi loi.
select is((select count(*) from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d04'), 0::bigint, 'per_visit contract has no schedule');
select throws_ok(
  $q$select public.service_schedule_generate(null::date)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'null month is rejected'
);

-- 5. service_accept theo ky (ky su a06).
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
insert into t042_resp values ('acc_q', public.service_accept(
  (select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d02'),
  5, '[]'::jsonb, null, 'Thang máy chạy êm, đã vệ sinh cabin.'
));
select is((select resp ->> 'status' from t042_resp where key = 'acc_q'), 'accepted', 'quarterly schedule accepted');
select is((select status from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d02'), 'accepted', 'quarterly schedule status is accepted');
-- Q81: note duoc luu vao service_acceptances.note.
select is((select note from public.service_acceptances where schedule_id = (select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d02')), 'Thang máy chạy êm, đã vệ sinh cabin.', 'schedule acceptance note is persisted');

-- Nghiem thu lai ky da accepted -> loi.
select throws_ok(
  $q$select public.service_accept((select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d02'), 5, '[]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_STATUS', 'accepting an accepted schedule is rejected'
);

-- SoD: gm tao hop dong SoD, tu nghiem thu ky cua no -> chan.
select public._t042_as('d0420000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.service_accept((select id from public.service_schedules where contract_id = (select id from t042_ctx where key = 'ct_sod')), 5, '[]'::jsonb)$q$,
  'P0001', 'ERR_SOD_SERVICE_ACCEPTOR', 'contract creator cannot accept own schedule'
);

-- Ky su nghiem thu ky cua hop dong SoD -> duoc.
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
insert into t042_resp values ('acc_sod', public.service_accept(
  (select id from public.service_schedules where contract_id = (select id from t042_ctx where key = 'ct_sod')),
  4, '[]'::jsonb
));
select is((select resp ->> 'status' from t042_resp where key = 'acc_sod'), 'accepted', 'engineer accepts SoD contract schedule');

-- Validate rating / photos / ton tai (ky yearly chua nghiem thu).
select throws_ok(
  $q$select public.service_accept((select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03'), 6, '[]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'rating 6 is rejected'
);
select throws_ok(
  $q$select public.service_accept((select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03'), 0, '[]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'rating 0 is rejected'
);
select throws_ok(
  $q$select public.service_accept((select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03'), 5, '"x"'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'photos not an array is rejected'
);
select throws_ok(
  $q$select public.service_accept('d0420000-0000-4000-8000-00000000ffff', 5, '[]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'nonexistent schedule is rejected'
);

-- Lay id lich d01 truoc khi doi sang thu kho: policy
-- service_schedules_select an lich khoi thu kho (khong co quyen nao
-- trong danh sach) nen subquery truc tiep tra NULL -> ham nhan
-- p_schedule_id NULL va raise ERR_INVALID_VALUE thay vi 42501.
-- (a06 ky su thay duoc lich nen lay luc nay; t042_ctx la bang tam,
-- khong RLS, thu kho doc duoc.)
insert into t042_ctx values ('sched_d01', (select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d01'));

-- Sai quyen: thu kho khong co service.accept.
select public._t042_as('d0420000-0000-4000-8000-000000000a07');
select throws_ok(
  $q$select public.service_accept((select id from t042_ctx where key = 'sched_d01'), 5, '[]'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:service.accept', 'storekeeper cannot accept'
);

-- Ky su nghiem thu ky yearly, rating 4.
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
insert into t042_resp values ('acc_y', public.service_accept(
  (select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03'),
  4, '[]'::jsonb
));
select is((select resp ->> 'status' from t042_resp where key = 'acc_y'), 'accepted', 'yearly schedule accepted with rating 4');
-- Q81: khong truyen note -> note NULL (tuong thich nguoc loi goi cu).
select ok((select note from public.service_acceptances where schedule_id = (select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d03')) is null, 'note is null when not passed');

-- 6. Luong hoa don dich vu — CHOT Q72 (ke toan a01 / ke toan truong a02).
select public._t042_as('d0420000-0000-4000-8000-000000000a01');
insert into t042_resp values ('inv1', public.invoice_save_draft(
  'd0420000-0000-4000-8000-000000000201',
  'd0420000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000001", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0420000-0000-4000-8000-000000000c01", "qty": 1, "unit_price": 5000000, "vat_rate": 10}]'::jsonb
));
insert into t042_ctx values ('inv1', (select (resp ->> 'id')::uuid from t042_resp where key = 'inv1'));
select is((select resp ->> 'status' from t042_resp where key = 'inv1'), 'draft', 'service invoice saved as draft before acceptance');

-- Chua nghiem thu ky thang 11 -> khop bi chan.
select throws_ok(
  $q$select public.invoice_match((select id from t042_ctx where key = 'inv1'))$q$,
  'P0001', 'ERR_SERVICE_NOT_ACCEPTED', 'invoice_match blocked before acceptance'
);

-- Duyet hoa don 'matched' chua nghiem thu (INV-SVC2) -> chan.
select public._t042_as('d0420000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.invoice_approve('d0420000-0000-4000-8000-000000000e02')$q$,
  'P0001', 'ERR_SERVICE_NOT_ACCEPTED', 'invoice_approve blocked before acceptance'
);

-- De nghi thanh toan cho hoa don 'approved' chua nghiem thu (INV-SVC3) -> chan.
select public._t042_as('d0420000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.payment_request_create('d0420000-0000-4000-8000-000000000201', 'd0420000-0000-4000-8000-000000000701', '[{"invoice_id": "d0420000-0000-4000-8000-000000000e03", "amount": 2200000}]'::jsonb)$q$,
  'P0001', 'ERR_SERVICE_NOT_ACCEPTED', 'payment_request_create blocked before acceptance'
);

-- Nghiem thu ky thang 11 cua hop dong thang.
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
insert into t042_resp values ('acc_m', public.service_accept(
  (select id from public.service_schedules where contract_id = 'd0420000-0000-4000-8000-000000000d01'),
  5, '[]'::jsonb
));
select is((select resp ->> 'status' from t042_resp where key = 'acc_m'), 'accepted', 'monthly schedule accepted');

-- Sau nghiem thu: khop duoc, so nhan = so luong PO.
select public._t042_as('d0420000-0000-4000-8000-000000000a01');
insert into t042_resp values ('match1', public.invoice_match((select id from t042_ctx where key = 'inv1')));
select is((select resp ->> 'status' from t042_resp where key = 'match1'), 'matched', 'service invoice matched after acceptance');
select is((select (match_result ->> 'received_qty')::numeric from public.supplier_invoice_lines where invoice_id = (select id from t042_ctx where key = 'inv1')), 1::numeric, 'service received_qty = PO qty after acceptance');

-- Duyet -> ap_ledger (+) + han tra theo payment terms 30 ngay.
select public._t042_as('d0420000-0000-4000-8000-000000000a02');
insert into t042_resp values ('appr1', public.invoice_approve((select id from t042_ctx where key = 'inv1')));
select is((select resp ->> 'status' from t042_resp where key = 'appr1'), 'approved', 'service invoice approved');
select is((select amount from public.ap_ledger where doc_type = 'supplier_invoice' and doc_id = (select id from t042_ctx where key = 'inv1')), 5500000::numeric, 'ap_ledger (+) 5500000 for service invoice');
select is((select due_date from public.ap_ledger where doc_type = 'supplier_invoice' and doc_id = (select id from t042_ctx where key = 'inv1')), '2026-12-09'::date, 'ap_ledger due_date = invoice_date + 30 days');

-- De nghi thanh toan sau nghiem thu -> duoc.
select public._t042_as('d0420000-0000-4000-8000-000000000a01');
insert into t042_resp values ('pay1', public.payment_request_create(
  'd0420000-0000-4000-8000-000000000201',
  'd0420000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from t042_ctx where key = 'inv1'), 'amount', 5500000))
));
select is((select resp ->> 'status' from t042_resp where key = 'pay1'), 'submitted', 'payment request submitted after acceptance');

-- Nghiem thu theo PO le (PO-SVC2, khong hop dong) — Q81: goi kieu
-- named-notation de kiem tra ten tham so p_note.
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
insert into t042_resp values ('acc_po2', public.service_accept(
  p_po_id => 'd0420000-0000-4000-8000-000000000b02',
  p_rating => 5, p_photos => '[]'::jsonb,
  p_note => 'Điều hòa chạy mát, đã thay gas.'
));
select is((select resp ->> 'status' from t042_resp where key = 'acc_po2'), 'accepted', 'one-off service PO accepted via po_id');
select is((select note from public.service_acceptances where po_id = 'd0420000-0000-4000-8000-000000000b02'), 'Điều hòa chạy mát, đã thay gas.', 'PO acceptance note is persisted (named notation)');

-- Hoa don cho dong c03 cua PO-SVC2 khop duoc sau nghiem thu theo PO.
select public._t042_as('d0420000-0000-4000-8000-000000000a01');
insert into t042_resp values ('inv2', public.invoice_save_draft(
  'd0420000-0000-4000-8000-000000000201',
  'd0420000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000004", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0420000-0000-4000-8000-000000000c03", "qty": 1, "unit_price": 1000000, "vat_rate": 10}]'::jsonb
));
insert into t042_ctx values ('inv2', (select (resp ->> 'id')::uuid from t042_resp where key = 'inv2'));
select is((select resp ->> 'status' from t042_resp where key = 'inv2'), 'draft', 'second service invoice saved as draft');
insert into t042_resp values ('match2', public.invoice_match((select id from t042_ctx where key = 'inv2')));
select is((select resp ->> 'status' from t042_resp where key = 'match2'), 'matched', 'second service invoice matched after PO acceptance');

-- SoD theo PO: ky su tao PO-SVC3, tu nghiem thu PO do -> chan.
select public._t042_as('d0420000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.service_accept(null, 5, '[]'::jsonb, 'd0420000-0000-4000-8000-000000000b03')$q$,
  'P0001', 'ERR_SOD_SERVICE_ACCEPTOR', 'PO creator cannot accept own PO'
);

-- 7. service_maintenance: het han + alert gia han (gm a03 tao hop dong
--    voi ngay tuong doi theo ngay chay test).
select public._t042_as('d0420000-0000-4000-8000-000000000a03');
insert into t042_resp values ('ct_ren', public.service_contract_save(
  'd0420000-0000-4000-8000-000000000201',
  jsonb_build_object('supplier_id', 'd0420000-0000-4000-8000-000000000701', 'expense_category_id', 'd0420000-0000-4000-8000-000000000302', 'cost_center_id', 'd0420000-0000-4000-8000-000000000301', 'title', 'Gia hạn sắp tới', 'start_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 30)::text, 'end_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 10)::text, 'billing_cycle', 'monthly', 'amount_per_cycle', 1000000)
));
insert into t042_ctx values ('ct_ren', (select (resp ->> 'id')::uuid from t042_resp where key = 'ct_ren'));
insert into t042_resp values ('ct_exp', public.service_contract_save(
  'd0420000-0000-4000-8000-000000000201',
  jsonb_build_object('supplier_id', 'd0420000-0000-4000-8000-000000000701', 'expense_category_id', 'd0420000-0000-4000-8000-000000000302', 'cost_center_id', 'd0420000-0000-4000-8000-000000000301', 'title', 'Đã hết hạn', 'start_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 60)::text, 'end_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 5)::text, 'billing_cycle', 'monthly', 'amount_per_cycle', 1000000)
));
insert into t042_ctx values ('ct_exp', (select (resp ->> 'id')::uuid from t042_resp where key = 'ct_exp'));
insert into t042_resp values ('ct_far', public.service_contract_save(
  'd0420000-0000-4000-8000-000000000201',
  jsonb_build_object('supplier_id', 'd0420000-0000-4000-8000-000000000701', 'expense_category_id', 'd0420000-0000-4000-8000-000000000302', 'cost_center_id', 'd0420000-0000-4000-8000-000000000301', 'title', 'Còn hạn dài', 'start_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 10)::text, 'end_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 60)::text, 'billing_cycle', 'monthly', 'amount_per_cycle', 1000000)
));
insert into t042_ctx values ('ct_far', (select (resp ->> 'id')::uuid from t042_resp where key = 'ct_far'));

select public._t042_as('d0420000-0000-4000-8000-000000000a01');
insert into t042_resp values ('maint1', public.service_maintenance());
select is((select status from public.service_contracts where id = (select id from t042_ctx where key = 'ct_exp')), 'expired', 'past-end contract is expired by maintenance');
select is((select count(*) from public.alerts where code = 'SERVICE_CONTRACT_RENEWAL' and (payload ->> 'contract_id') = (select id::text from t042_ctx where key = 'ct_ren')), 1::bigint, 'renewal alert created for contract ending in 10 days');
select is((select count(*) from public.alerts where code = 'SERVICE_CONTRACT_RENEWAL' and (payload ->> 'contract_id') = (select id::text from t042_ctx where key = 'ct_far')), 0::bigint, 'no renewal alert for contract ending in 60 days');

-- Chay lai: khong tao alert trung.
insert into t042_resp values ('maint2', public.service_maintenance());
select is((select count(*) from public.alerts where code = 'SERVICE_CONTRACT_RENEWAL' and (payload ->> 'contract_id') = (select id::text from t042_ctx where key = 'ct_ren')), 1::bigint, 'renewal alert is deduped on second run');

-- 8. RLS doc: thu kho khong thay gi; ky su thay du.
select public._t042_as('d0420000-0000-4000-8000-000000000a07');
select is((select count(*) from public.service_contracts), 0::bigint, 'storekeeper sees 0 contracts');
select is((select count(*) from public.service_schedules), 0::bigint, 'storekeeper sees 0 schedules');
select is((select count(*) from public.service_acceptances), 0::bigint, 'storekeeper sees 0 acceptances');

select public._t042_as('d0420000-0000-4000-8000-000000000a06');
select is((select count(*) from public.service_contracts), 9::bigint, 'engineer sees 9 contracts');
select is((select count(*) from public.service_acceptances), 5::bigint, 'engineer sees 5 acceptances');
select ok((select count(*) from public.service_schedules) > 0, 'engineer sees schedules');

select * from finish();
rollback;
