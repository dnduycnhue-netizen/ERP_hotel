-- T-043 pgTAP: xuat Excel cho ke toan — 5 RPC SECURITY DEFINER.
-- Cover: quyen `export.accounting` (co / khong / chua dang nhap), dau vao
-- sai, khoa so (ky da khoa / ngay da khoa / ngay chua khoa co phat sinh),
-- noi dung + tong cua 5 loai xuat, tuoi no FIFO tai thoi diem `to`.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(55);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0430000-0000-4000-8000-000000000001', 'T-043 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000001', 'T043', 'Entity T-043');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'P0431', 'Property T-043', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0430000-0000-4000-8000-000000000401', 'd0430000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels) values
  ('d0430000-0000-4000-8000-000000000501', 'd0430000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0430000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market']);

insert into public.suppliers (id, org_id, code, name, kind, status, payment_terms_days, bank_changed_at) values
  ('d0430000-0000-4000-8000-000000000701', 'd0430000-0000-4000-8000-000000000001', 'NCC1', 'Công ty Gạo Sạch', 'company', 'active', 30, null);

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0430000-0000-4000-8000-000000000301', 'd0430000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0430000-0000-4000-8000-000000000302', 'd0430000-0000-4000-8000-000000000201', 'WH_KITCHEN', 'Kho bếp', 'main', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0430000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-chief043@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0430000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-acct043@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0430000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-stk043@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0430000-0000-4000-8000-000000000a01', 'NV04301', 'Kế toán trưởng'),
  ('d0430000-0000-4000-8000-000000000a02', 'NV04302', 'Kế toán'),
  ('d0430000-0000-4000-8000-000000000a03', 'NV04303', 'Thủ kho')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0430000-0000-4000-8000-000000000601', 'd0430000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d0430000-0000-4000-8000-000000000602', 'd0430000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('d0430000-0000-4000-8000-000000000603', 'd0430000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho');

insert into public.role_permissions (role_id, permission_code) values
  ('d0430000-0000-4000-8000-000000000601', 'invoice.manage'),
  ('d0430000-0000-4000-8000-000000000601', 'ap.view'),
  ('d0430000-0000-4000-8000-000000000602', 'invoice.approve'),
  ('d0430000-0000-4000-8000-000000000602', 'payment.approve'),
  ('d0430000-0000-4000-8000-000000000602', 'export.accounting'),
  ('d0430000-0000-4000-8000-000000000603', 'receiving.perform');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0430000-0000-4000-8000-000000000a01', 'd0430000-0000-4000-8000-000000000602', 'd0430000-0000-4000-8000-000000000201'),
  ('d0430000-0000-4000-8000-000000000a02', 'd0430000-0000-4000-8000-000000000601', 'd0430000-0000-4000-8000-000000000201'),
  ('d0430000-0000-4000-8000-000000000a03', 'd0430000-0000-4000-8000-000000000603', 'd0430000-0000-4000-8000-000000000201');

-- Ky 10/2026 + 11/2026 da khoa; 12/2026 mo.
insert into public.accounting_periods (legal_entity_id, year, month, status, closed_by, closed_at) values
  ('d0430000-0000-4000-8000-000000000101', 2026, 10, 'closed', 'd0430000-0000-4000-8000-000000000a01', now()),
  ('d0430000-0000-4000-8000-000000000101', 2026, 11, 'closed', 'd0430000-0000-4000-8000-000000000a01', now());

-- Ngay 05/12/2026 da khoa ngay o kho chinh (ky 12/2026 van mo).
insert into public.day_locks (property_id, warehouse_id, business_date, locked_by) values
  ('d0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000301', '2026-12-05', 'd0430000-0000-4000-8000-000000000a01');

-- PO + dong PO (cho dong hoa don).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, status, created_by, doc_no) values
  ('d0430000-0000-4000-8000-000000000b01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-10-10', '2026-10-15', 'sent', 'd0430000-0000-4000-8000-000000000a01', 'PO-043-001');
insert into public.purchase_order_lines (id, po_id, org_id, item_id, qty, uom, qty_stock, unit_price, price_source) values
  ('d0430000-0000-4000-8000-000000000b11', 'd0430000-0000-4000-8000-000000000b01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000501', 10, 'kg', 10, 50000, 'manual');
select set_config('app.pr_po_guard_bypass', 'off', true);

-- Phieu nhan posted: 15/10 (10 kg @ 10000), 03/12 (5 kg @ 12000, khong khoa
-- ngay), 05/12 (5 kg @ 12000, da khoa ngay).
select set_config('app.receiving_guard_bypass', 'on', true);
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, supplier_id, warehouse_id, doc_no, receiver_id, received_at, status, total_amount, created_by) values
  ('d0430000-0000-4000-8000-000000000e01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'd0430000-0000-4000-8000-000000000301', 'GR-043-001', 'd0430000-0000-4000-8000-000000000a03', '2026-10-15 10:00:00+07', 'posted', 100000, 'd0430000-0000-4000-8000-000000000a03'),
  ('d0430000-0000-4000-8000-000000000e02', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'd0430000-0000-4000-8000-000000000301', 'GR-043-002', 'd0430000-0000-4000-8000-000000000a03', '2026-12-03 09:00:00+07', 'posted', 60000, 'd0430000-0000-4000-8000-000000000a03'),
  ('d0430000-0000-4000-8000-000000000e03', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'd0430000-0000-4000-8000-000000000301', 'GR-043-003', 'd0430000-0000-4000-8000-000000000a03', '2026-12-05 09:00:00+07', 'posted', 60000, 'd0430000-0000-4000-8000-000000000a03');
insert into public.goods_receipt_lines (id, gr_id, org_id, property_id, item_id, gross_qty, tare_qty, uom, net_qty_stock, unit_cost, accepted_qty_stock, qc_status) values
  ('d0430000-0000-4000-8000-000000000e11', 'd0430000-0000-4000-8000-000000000e01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000501', 10, 0, 'kg', 10, 10000, 10, 'pass'),
  ('d0430000-0000-4000-8000-000000000e12', 'd0430000-0000-4000-8000-000000000e02', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000501', 5, 0, 'kg', 5, 12000, 5, 'pass'),
  ('d0430000-0000-4000-8000-000000000e13', 'd0430000-0000-4000-8000-000000000e03', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000501', 5, 0, 'kg', 5, 12000, 5, 'pass');
select set_config('app.receiving_guard_bypass', 'off', true);

-- Dieu chuyen + move xuat kho: 16/10 (-5 @ 10000), 05/12 (-2 @ 12000).
select set_config('app.inventory_guard_bypass', 'on', true);
insert into public.transfers (id, org_id, legal_entity_id, property_id, from_warehouse_id, to_warehouse_id, doc_no, business_date, status) values
  ('d0430000-0000-4000-8000-000000000c01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000301', 'd0430000-0000-4000-8000-000000000302', 'TRF-043-001', '2026-10-16', 'received'),
  ('d0430000-0000-4000-8000-000000000c02', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000301', 'd0430000-0000-4000-8000-000000000302', 'TRF-043-002', '2026-12-05', 'received');
select set_config('app.inventory_guard_bypass', 'off', true);
insert into public.stock_moves (org_id, legal_entity_id, property_id, warehouse_id, item_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id) values
  ('d0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000301', 'd0430000-0000-4000-8000-000000000501', 'transfer_out', -5, 10000, -50000, '2026-10-16', 'd0430000-0000-4000-8000-000000000a03', 'transfer', 'd0430000-0000-4000-8000-000000000c01'),
  ('d0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000301', 'd0430000-0000-4000-8000-000000000501', 'transfer_out', -2, 12000, -24000, '2026-12-05', 'd0430000-0000-4000-8000-000000000a03', 'transfer', 'd0430000-0000-4000-8000-000000000c02');

-- Hoa don 20/10: 10 kg @ 50000, VAT 10% -> 550000 (match_result rong).
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.supplier_invoices (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date, amount_before_tax, vat_amount, total, status) values
  ('d0430000-0000-4000-8000-000000000d01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'INV-043-001', 'AA', '0000001', '2026-10-20', 500000, 50000, 550000, 'approved');
insert into public.supplier_invoice_lines (id, invoice_id, org_id, property_id, po_line_id, item_id, qty, unit_price, amount, vat_rate, vat_amount) values
  ('d0430000-0000-4000-8000-000000000d11', 'd0430000-0000-4000-8000-000000000d01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000b11', 'd0430000-0000-4000-8000-000000000501', 10, 50000, 500000, 10, 50000);

-- So cong no: (+) 500000 han 10/11 nhap 20/10; (-) 200000 nhap 25/10.
insert into public.ap_ledger (id, org_id, legal_entity_id, property_id, supplier_id, doc_type, doc_id, amount, due_date, entry_date) values
  ('d0430000-0000-4000-8000-000000000f01', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'supplier_invoice', 'd0430000-0000-4000-8000-000000000d01', 500000, '2026-11-10', '2026-10-20'),
  ('d0430000-0000-4000-8000-000000000f02', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000701', 'payment_request', 'd0430000-0000-4000-8000-000000000001', -200000, '2026-11-10', '2026-10-25');
select set_config('app.finance_guard_bypass', 'off', true);

-- Tam ung 1.000.000 (nhan vien a03), quyet toan 800.000 + hoan 200.000.
select set_config('app.advance_guard_bypass', 'on', true);
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status, requested_at, disbursed_at, due_settle_at, settled_at) values
  ('d0430000-0000-4000-8000-000000000901', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000a03', 'ADV-043-001', 1000000, 'Đi chợ', 'settled', '2026-10-12 09:00:00+07', '2026-10-12 10:00:00+07', '2026-10-27 00:00:00+07', '2026-10-28 15:00:00+07');
select set_config('app.advance_guard_bypass', 'off', true);
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.advance_settlements (id, org_id, legal_entity_id, property_id, advance_id, doc_no, amount, refund_amount, extra_pay_amount, settled_by, settled_at) values
  ('d0430000-0000-4000-8000-000000000911', 'd0430000-0000-4000-8000-000000000001', 'd0430000-0000-4000-8000-000000000101', 'd0430000-0000-4000-8000-000000000201', 'd0430000-0000-4000-8000-000000000901', 'STL-043-001', 800000, 200000, 0, 'd0430000-0000-4000-8000-000000000a02', '2026-10-28 15:00:00+07');
select set_config('app.finance_guard_bypass', 'off', true);

-- Helper doi user (mau T-020/T-040).
create or replace function public._t043_as(p_user uuid)
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

-- Bang tam giu ket qua RPC (mau T-020/T-023).
create temp table t043_resp (key text primary key, resp jsonb);

-- Bang tam tao duoi role postgres; cap quyen truoc khi doi role
-- (mau T-023/T-032/T-043-batches da chay live: khong cap thi INSERT
-- duoi authenticated loi 42501 permission denied for table t043_resp).
grant all on t043_resp to authenticated;

-- Tu day tro di chay duoi role authenticated (RLS co hieu luc).
set local role authenticated;

-- 1. Chua dang nhap (chua dat JWT claim) -> 42501.
select throws_ok(
  $q$select public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN',
  'Unauthenticated export is blocked'
);

-- 2. Ke toan thuong (a02) khong co export.accounting -> 42501 cho ca 5 RPC.
select public._t043_as('d0430000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN:export.accounting',
  'Accountant cannot export goods receipts'
);
select throws_ok(
  $q$select public.export_stock_issues('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN:export.accounting',
  'Accountant cannot export stock issues'
);
select throws_ok(
  $q$select public.export_invoices('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN:export.accounting',
  'Accountant cannot export invoices'
);
select throws_ok(
  $q$select public.export_payables('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN:export.accounting',
  'Accountant cannot export payables'
);
select throws_ok(
  $q$select public.export_advances('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN:export.accounting',
  'Accountant cannot export advances'
);

-- 3. Dau vao sai (a01 ke toan truong).
select public._t043_as('d0430000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-10-31', '2026-10-01')$q$,
  '22023', 'ERR_INVALID_INPUT',
  'from > to is rejected'
);
select throws_ok(
  $q$select public.export_goods_receipts('d0430000-0000-4000-8000-000000000999', '2026-10-01', '2026-10-31')$q$,
  '42501', 'ERR_FORBIDDEN',
  'Unknown entity is forbidden (no existence leak)'
);
select throws_ok(
  $q$select public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-01-01', '2027-06-01')$q$,
  '22023', 'ERR_INVALID_INPUT',
  'Range over 366 days is rejected'
);

-- 4. Khoang chua khoa (12/2026 mo): nhap kho 01–10/12 chi co phieu 03/12
--    chua khoa ngay -> chi liet ngay do (cac ngay khong phat sinh duoc mien).
select throws_ok(
  $q$select public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-12-01', '2026-12-10')$q$,
  'P0001', 'ERR_EXPORT_NOT_LOCKED: 03/12/2026',
  'Un-locked receipt date blocks goods-receipts export'
);
-- Xuat kho 01–10/12: chi co move 05/12 (da khoa ngay) -> xuat duoc.
insert into t043_resp values ('issues_dec', public.export_stock_issues('d0430000-0000-4000-8000-000000000101', '2026-12-01', '2026-12-10'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'issues_dec'), true, 'Day-locked stock issues export is ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'issues_dec'), 1, 'Day-locked stock issues has 1 row');
-- Hoa don 01–10/12 (tai chinh: chi xet ky khoa) -> chan het 10 ngay.
select throws_ok(
  $q$select public.export_invoices('d0430000-0000-4000-8000-000000000101', '2026-12-01', '2026-12-10')$q$,
  'P0001', 'ERR_EXPORT_NOT_LOCKED: 01/12/2026, 02/12/2026, 03/12/2026, 04/12/2026, 05/12/2026, 06/12/2026, 07/12/2026, 08/12/2026, 09/12/2026, 10/12/2026',
  'Un-closed period blocks invoices export with all dates listed'
);

-- 5. Nhap kho thang 10 (ky da khoa).
insert into t043_resp values ('gr_oct', public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'gr_oct'), true, 'Oct goods receipts export ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'gr_oct'), 1, 'Oct goods receipts has 1 line');
select is((select (resp -> 'totals' ->> 'amount')::numeric from t043_resp where key = 'gr_oct'), 100000::numeric, 'Oct goods receipts total 100000');
select is((select resp -> 'rows' -> 0 ->> 'received_date' from t043_resp where key = 'gr_oct'), '2026-10-15', 'Receipt row has VN business date');
select is((select resp -> 'rows' -> 0 ->> 'item_code' from t043_resp where key = 'gr_oct'), 'ITM_GAO', 'Receipt row has item code');
select is((select (resp -> 'rows' -> 0 ->> 'qty')::numeric from t043_resp where key = 'gr_oct'), 10::numeric, 'Receipt row qty is accepted qty');

-- 6. Nhap kho ngay 05/12 (da khoa ngay, ky mo).
insert into t043_resp values ('gr_dec5', public.export_goods_receipts('d0430000-0000-4000-8000-000000000101', '2026-12-05', '2026-12-05'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'gr_dec5'), true, 'Day-locked goods receipts export ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'gr_dec5'), 1, 'Day-locked goods receipts has 1 line');
select is((select (resp -> 'totals' ->> 'amount')::numeric from t043_resp where key = 'gr_dec5'), 60000::numeric, 'Day-locked goods receipts total 60000');

-- 7. Xuat kho thang 10: dieu chuyen WH_MAIN -> WH_KITCHEN.
insert into t043_resp values ('issues_oct', public.export_stock_issues('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'issues_oct'), true, 'Oct stock issues export ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'issues_oct'), 1, 'Oct stock issues has 1 row');
select is((select resp -> 'rows' -> 0 ->> 'move_type' from t043_resp where key = 'issues_oct'), 'transfer_out', 'Issue row move_type is transfer_out');
select is((select resp -> 'rows' -> 0 ->> 'doc_no' from t043_resp where key = 'issues_oct'), 'TRF-043-001', 'Issue row doc_no resolves via transfer');
select is((select resp -> 'rows' -> 0 ->> 'to_warehouse_code' from t043_resp where key = 'issues_oct'), 'WH_KITCHEN', 'Issue row has destination warehouse');
select is((select (resp -> 'rows' -> 0 ->> 'qty')::numeric from t043_resp where key = 'issues_oct'), -5::numeric, 'Issue row qty is negative');
select is((select (resp -> 'totals' ->> 'amount')::numeric from t043_resp where key = 'issues_oct'), -50000::numeric, 'Oct stock issues total -50000');

-- 8. Xuat kho ngay 05/12 (da khoa ngay).
insert into t043_resp values ('issues_dec5', public.export_stock_issues('d0430000-0000-4000-8000-000000000101', '2026-12-05', '2026-12-05'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'issues_dec5'), true, 'Day-locked stock issues export ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'issues_dec5'), 1, 'Day-locked stock issues has 1 row');

-- 9. Hoa don thang 10.
insert into t043_resp values ('inv_oct', public.export_invoices('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'inv_oct'), true, 'Oct invoices export ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'inv_oct'), 1, 'Oct invoices has 1 line');
select is((select (resp -> 'totals' ->> 'amount')::numeric from t043_resp where key = 'inv_oct'), 500000::numeric, 'Oct invoices amount 500000');
select is((select (resp -> 'totals' ->> 'vat_amount')::numeric from t043_resp where key = 'inv_oct'), 50000::numeric, 'Oct invoices VAT 50000');
select is((select resp -> 'rows' -> 0 ->> 'po_doc_no' from t043_resp where key = 'inv_oct'), 'PO-043-001', 'Invoice row has PO doc_no');
select is((select resp -> 'rows' -> 0 ->> 'match_reason' from t043_resp where key = 'inv_oct'), null, 'Invoice row match_reason is null before matching');

-- 10. Cong no tai 31/10: phai tra 500000, da tra 200000, con no 300000,
--     chua qua han (han 10/11).
insert into t043_resp values ('ap_oct31', public.export_payables('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'ap_oct31'), true, 'Payables as of Oct 31 ok');
select is((select (resp -> 'totals' ->> 'supplier_count')::integer from t043_resp where key = 'ap_oct31'), 1, 'Payables has 1 supplier');
select is((select (resp -> 'totals' ->> 'payable')::numeric from t043_resp where key = 'ap_oct31'), 500000::numeric, 'Payables payable 500000');
select is((select (resp -> 'totals' ->> 'paid')::numeric from t043_resp where key = 'ap_oct31'), 200000::numeric, 'Payables paid 200000');
select is((select (resp -> 'totals' ->> 'balance')::numeric from t043_resp where key = 'ap_oct31'), 300000::numeric, 'Payables balance 300000');
select is((select (resp -> 'rows' -> 0 ->> 'not_due')::numeric from t043_resp where key = 'ap_oct31'), 300000::numeric, 'Payables not yet due 300000 at Oct 31');
select is((select (resp -> 'rows' -> 0 ->> 'overdue_1_30')::numeric from t043_resp where key = 'ap_oct31'), 0::numeric, 'Payables overdue 1-30 is 0 at Oct 31');
select is((select resp -> 'rows' -> 0 ->> 'oldest_overdue_days' from t043_resp where key = 'ap_oct31'), null, 'Payables oldest overdue is null at Oct 31');

-- 11. Cong no tai 15/11 (ky 11 da khoa): qua han 5 ngay -> nhom 1–30.
insert into t043_resp values ('ap_nov15', public.export_payables('d0430000-0000-4000-8000-000000000101', '2026-11-01', '2026-11-15'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'ap_nov15'), true, 'Payables as of Nov 15 ok');
select is((select (resp -> 'rows' -> 0 ->> 'overdue_1_30')::numeric from t043_resp where key = 'ap_nov15'), 300000::numeric, 'Payables overdue 1-30 is 300000 at Nov 15');
select is((select (resp -> 'rows' -> 0 ->> 'not_due')::numeric from t043_resp where key = 'ap_nov15'), 0::numeric, 'Payables not due is 0 at Nov 15');
select is((select (resp -> 'rows' -> 0 ->> 'oldest_overdue_days')::integer from t043_resp where key = 'ap_nov15'), 5, 'Payables oldest overdue is 5 days at Nov 15');

-- 12. Tam ung thang 10.
insert into t043_resp values ('adv_oct', public.export_advances('d0430000-0000-4000-8000-000000000101', '2026-10-01', '2026-10-31'));
select is((select (resp ->> 'ok')::boolean from t043_resp where key = 'adv_oct'), true, 'Oct advances export ok');
select is((select (resp -> 'totals' ->> 'count')::integer from t043_resp where key = 'adv_oct'), 1, 'Oct advances has 1 row');
select is((select (resp -> 'totals' ->> 'amount')::numeric from t043_resp where key = 'adv_oct'), 1000000::numeric, 'Oct advances amount 1000000');
select is((select (resp -> 'totals' ->> 'settled_amount')::numeric from t043_resp where key = 'adv_oct'), 800000::numeric, 'Oct advances settled 800000');
select is((select (resp -> 'totals' ->> 'refund_amount')::numeric from t043_resp where key = 'adv_oct'), 200000::numeric, 'Oct advances refund 200000');
select is((select resp -> 'rows' -> 0 ->> 'employee_name' from t043_resp where key = 'adv_oct'), 'Thủ kho', 'Advance row has employee name via profiles');

select * from finish();
rollback;
