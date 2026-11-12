-- T-040 pgTAP: hoa don, khop 3 chieu, ap_ledger, bang ke, quyet toan
-- tam ung, de nghi thanh toan.
-- Cover: RLS 9 bang moi, write-guard + ap_ledger bat bien, nhap hoa
-- don (tinh tong server-side), khop 3 chieu (so luong / don gia / ran
-- gioi 1% / chong hoa don trung), duyet + ap_ledger (+) + SoD, tra
-- hang -> ap_ledger (-) chi phan da hoa don, quyet toan thua/thieu +
-- SoD, de nghi thanh toan (buoc duyet mac dinh, buoc owner khi doi STK
-- 30 ngay, SoD, tu choi can ly do), ghi da tra -> ap_ledger (-) +
-- cap nhat trang thai hoa don, bang ke.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(80);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0400000-0000-4000-8000-000000000001', 'T-040 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000001', 'T040', 'Entity T-040');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'P0401', 'Property T-040', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0400000-0000-4000-8000-000000000401', 'd0400000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d0400000-0000-4000-8000-000000000402', 'd0400000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
  ('d0400000-0000-4000-8000-000000000403', 'd0400000-0000-4000-8000-000000000001', 'VP', 'Văn phòng phẩm', 'other');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels) values
  ('d0400000-0000-4000-8000-000000000501', 'd0400000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0400000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market']),
  ('d0400000-0000-4000-8000-000000000502', 'd0400000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0400000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract']),
  ('d0400000-0000-4000-8000-000000000503', 'd0400000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0400000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market']);

insert into public.suppliers (id, org_id, code, name, kind, status, payment_terms_days, bank_changed_at) values
  ('d0400000-0000-4000-8000-000000000701', 'd0400000-0000-4000-8000-000000000001', 'NCC1', 'Công ty Gạo Sạch', 'company', 'active', 30, null),
  ('d0400000-0000-4000-8000-000000000702', 'd0400000-0000-4000-8000-000000000001', 'NCC2', 'Công ty Thực Phẩm', 'company', 'active', 0, now()),
  ('d0400000-0000-4000-8000-000000000703', 'd0400000-0000-4000-8000-000000000001', 'NCC3', 'Bà Tư chợ', 'individual_no_invoice', 'active', 0, null);

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0400000-0000-4000-8000-000000000301', 'd0400000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0400000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-acct040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0400000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-chief040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0400000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-gm040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0400000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-own040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0400000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u5-pur040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0400000-0000-4000-8000-000000000a06', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u6-emp040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0400000-0000-4000-8000-000000000a07', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u7-stk040@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0400000-0000-4000-8000-000000000a01', 'NV04001', 'Kế toán'),
  ('d0400000-0000-4000-8000-000000000a02', 'NV04002', 'Kế toán trưởng'),
  ('d0400000-0000-4000-8000-000000000a03', 'NV04003', 'Tổng quản lý'),
  ('d0400000-0000-4000-8000-000000000a04', 'NV04004', 'Chủ đầu tư'),
  ('d0400000-0000-4000-8000-000000000a05', 'NV04005', 'Thu mua'),
  ('d0400000-0000-4000-8000-000000000a06', 'NV04006', 'Nhân viên giữ tạm ứng'),
  ('d0400000-0000-4000-8000-000000000a07', 'NV04007', 'Thủ kho')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0400000-0000-4000-8000-000000000601', 'd0400000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d0400000-0000-4000-8000-000000000602', 'd0400000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('d0400000-0000-4000-8000-000000000603', 'd0400000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0400000-0000-4000-8000-000000000604', 'd0400000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0400000-0000-4000-8000-000000000605', 'd0400000-0000-4000-8000-000000000001', 'purchaser', 'Mua hàng'),
  ('d0400000-0000-4000-8000-000000000607', 'd0400000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho');

insert into public.role_permissions (role_id, permission_code) values
  ('d0400000-0000-4000-8000-000000000601', 'invoice.manage'),
  ('d0400000-0000-4000-8000-000000000601', 'payment.request'),
  ('d0400000-0000-4000-8000-000000000601', 'payment.mark_paid'),
  ('d0400000-0000-4000-8000-000000000601', 'advance.settle'),
  ('d0400000-0000-4000-8000-000000000601', 'ap.view'),
  ('d0400000-0000-4000-8000-000000000602', 'invoice.approve'),
  ('d0400000-0000-4000-8000-000000000602', 'payment.approve'),
  ('d0400000-0000-4000-8000-000000000602', 'invoice.manage'),
  ('d0400000-0000-4000-8000-000000000602', 'payment.request'),
  ('d0400000-0000-4000-8000-000000000604', 'payment.approve'),
  ('d0400000-0000-4000-8000-000000000604', 'ap.view'),
  ('d0400000-0000-4000-8000-000000000604', 'invoice.approve'),
  ('d0400000-0000-4000-8000-000000000605', 'advance.request'),
  ('d0400000-0000-4000-8000-000000000607', 'supplier_return.post');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0400000-0000-4000-8000-000000000a01', 'd0400000-0000-4000-8000-000000000601', 'd0400000-0000-4000-8000-000000000201'),
  ('d0400000-0000-4000-8000-000000000a02', 'd0400000-0000-4000-8000-000000000602', 'd0400000-0000-4000-8000-000000000201'),
  ('d0400000-0000-4000-8000-000000000a03', 'd0400000-0000-4000-8000-000000000603', 'd0400000-0000-4000-8000-000000000201'),
  ('d0400000-0000-4000-8000-000000000a04', 'd0400000-0000-4000-8000-000000000604', null),
  ('d0400000-0000-4000-8000-000000000a05', 'd0400000-0000-4000-8000-000000000605', 'd0400000-0000-4000-8000-000000000201'),
  ('d0400000-0000-4000-8000-000000000a06', 'd0400000-0000-4000-8000-000000000601', 'd0400000-0000-4000-8000-000000000201'),
  ('d0400000-0000-4000-8000-000000000a07', 'd0400000-0000-4000-8000-000000000607', 'd0400000-0000-4000-8000-000000000201');

-- Tam ung fixture (chen truc tiep, bypass advance guard).
select set_config('app.advance_guard_bypass', 'on', true);
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status) values
  ('d0400000-0000-4000-8000-000000000901', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000a06', 'ADV-040-001', 1000000, 'Đi chợ', 'disbursed'),
  ('d0400000-0000-4000-8000-000000000902', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000a06', 'ADV-040-002', 500000, 'Đi chợ', 'disbursed'),
  ('d0400000-0000-4000-8000-000000000903', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000a06', 'ADV-040-003', 300000, 'Đi chợ', 'disbursed'),
  ('d0400000-0000-4000-8000-000000000904', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000a06', 'ADV-040-004', 200000, 'Đi chợ', 'disbursed');
select set_config('app.advance_guard_bypass', 'off', true);

-- PO fixture (chen truc tiep, bypass pr_po).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, status, created_by, doc_no) values
  ('d0400000-0000-4000-8000-000000000b01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', 'sent', 'd0400000-0000-4000-8000-000000000a01', 'PO-040-001'),
  ('d0400000-0000-4000-8000-000000000b02', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', 'sent', 'd0400000-0000-4000-8000-000000000a01', 'PO-040-002'),
  ('d0400000-0000-4000-8000-000000000b03', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', 'draft', 'd0400000-0000-4000-8000-000000000a01', 'PO-040-003'),
  ('d0400000-0000-4000-8000-000000000b04', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000702', 'contract', 'stock', '2026-11-09', '2026-11-09', 'sent', 'd0400000-0000-4000-8000-000000000a01', 'PO-040-004');

insert into public.purchase_order_lines (id, po_id, org_id, item_id, description, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('d0400000-0000-4000-8000-000000000c01', 'd0400000-0000-4000-8000-000000000b01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 10),
  ('d0400000-0000-4000-8000-000000000c02', 'd0400000-0000-4000-8000-000000000b01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000502', 'Thịt ba chỉ', 5, 'kg', 5, 60000, 'agreement', 5),
  ('d0400000-0000-4000-8000-000000000c03', 'd0400000-0000-4000-8000-000000000b01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000503', 'Muối hạt', 20, 'kg', 20, 5000, 'manual', 20),
  ('d0400000-0000-4000-8000-000000000c04', 'd0400000-0000-4000-8000-000000000b02', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 10),
  ('d0400000-0000-4000-8000-000000000c05', 'd0400000-0000-4000-8000-000000000b03', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
  ('d0400000-0000-4000-8000-000000000c06', 'd0400000-0000-4000-8000-000000000b04', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 10);
select set_config('app.pr_po_guard_bypass', 'off', true);

-- GR da post (chen truc tiep, bypass receiving) + post move 'receipt'
-- de kho that co ton cho phep tra hang sau nay.
select set_config('app.receiving_guard_bypass', 'on', true);
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, po_id, supplier_id, warehouse_id, doc_no, receiver_id, status) values
  ('d0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000b01', 'd0400000-0000-4000-8000-000000000701', 'd0400000-0000-4000-8000-000000000301', 'GR-040-001', 'd0400000-0000-4000-8000-000000000a07', 'posted'),
  ('d0400000-0000-4000-8000-000000000e02', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000b02', 'd0400000-0000-4000-8000-000000000701', 'd0400000-0000-4000-8000-000000000301', 'GR-040-002', 'd0400000-0000-4000-8000-000000000a07', 'posted'),
  ('d0400000-0000-4000-8000-000000000e03', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000b04', 'd0400000-0000-4000-8000-000000000702', 'd0400000-0000-4000-8000-000000000301', 'GR-040-003', 'd0400000-0000-4000-8000-000000000a07', 'posted');

insert into public.goods_receipt_lines (id, gr_id, org_id, property_id, po_line_id, item_id, gross_qty, tare_qty, uom, net_qty_stock, unit_cost, accepted_qty_stock, qc_status, posted_warehouse_id) values
  ('d0400000-0000-4000-8000-000000000e11', 'd0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000c01', 'd0400000-0000-4000-8000-000000000501', 10, 0, 'kg', 10, 10000, 10, 'pass', 'd0400000-0000-4000-8000-000000000301'),
  ('d0400000-0000-4000-8000-000000000e12', 'd0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000c02', 'd0400000-0000-4000-8000-000000000502', 5, 0, 'kg', 5, 60000, 5, 'pass', 'd0400000-0000-4000-8000-000000000301'),
  ('d0400000-0000-4000-8000-000000000e13', 'd0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000c03', 'd0400000-0000-4000-8000-000000000503', 20, 0, 'kg', 20, 5000, 20, 'pass', 'd0400000-0000-4000-8000-000000000301'),
  ('d0400000-0000-4000-8000-000000000e14', 'd0400000-0000-4000-8000-000000000e02', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000c04', 'd0400000-0000-4000-8000-000000000501', 10, 0, 'kg', 10, 10000, 10, 'pass', 'd0400000-0000-4000-8000-000000000301'),
  ('d0400000-0000-4000-8000-000000000e15', 'd0400000-0000-4000-8000-000000000e03', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000c06', 'd0400000-0000-4000-8000-000000000501', 10, 0, 'kg', 10, 10000, 10, 'pass', 'd0400000-0000-4000-8000-000000000301');
select set_config('app.receiving_guard_bypass', 'off', true);

-- _post_move doi auth.uid() khac null (posted_by, 120000:439) nen phai set
-- JWT truoc khi goi — mau inventory_core_test.sql (set_config sub+claims
-- truoc lives_ok _post_move). Dung a07 (thu kho, nguoi nhan GR).
select set_config('request.jwt.claim.sub', 'd0400000-0000-4000-8000-000000000a07', true);
select set_config('request.jwt.claims', '{"sub":"d0400000-0000-4000-8000-000000000a07","role":"authenticated"}', true);

select public._post_move('d0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000301', 'd0400000-0000-4000-8000-000000000501', null, 'receipt', 10, 10000, '2026-11-09', 'goods_receipt', 'd0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000e11');
select public._post_move('d0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000301', 'd0400000-0000-4000-8000-000000000502', null, 'receipt', 5, 60000, '2026-11-09', 'goods_receipt', 'd0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000e12');
select public._post_move('d0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000301', 'd0400000-0000-4000-8000-000000000503', null, 'receipt', 20, 5000, '2026-11-09', 'goods_receipt', 'd0400000-0000-4000-8000-000000000e01', 'd0400000-0000-4000-8000-000000000e13');
select public._post_move('d0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000301', 'd0400000-0000-4000-8000-000000000501', null, 'receipt', 10, 10000, '2026-11-09', 'goods_receipt', 'd0400000-0000-4000-8000-000000000e02', 'd0400000-0000-4000-8000-000000000e14');
select public._post_move('d0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000301', 'd0400000-0000-4000-8000-000000000501', null, 'receipt', 10, 10000, '2026-11-09', 'goods_receipt', 'd0400000-0000-4000-8000-000000000e03', 'd0400000-0000-4000-8000-000000000e15');

-- Bang tam giu id chung tu tao trong test (mau T-020/T-023).
create temp table t040_ctx (key text primary key, id uuid);
create temp table t040_resp (key text primary key, resp jsonb);

-- Hai bang tam tao duoi role postgres, nhung tu lenh 'set local role
-- authenticated' tro di moi lenh INSERT/SELECT deu chay duoi authenticated
-- (khong co quyen ghi bang cua role khac) -> cap quyen truoc khi doi role.
grant all on t040_ctx, t040_resp to authenticated;

-- Helper doi user: dat lai JWT claim (mau T-020).
create or replace function public._t040_as(p_user uuid)
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

-- 1. RLS bat cho 9 bang moi.
select is((select relrowsecurity from pg_class where relname = 'supplier_invoices'), true, 'supplier_invoices has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'supplier_invoice_lines'), true, 'supplier_invoice_lines has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'no_invoice_listings'), true, 'no_invoice_listings has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'no_invoice_listing_lines'), true, 'no_invoice_listing_lines has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'ap_ledger'), true, 'ap_ledger has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'advance_settlements'), true, 'advance_settlements has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'advance_settlement_lines'), true, 'advance_settlement_lines has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'payment_requests'), true, 'payment_requests has RLS enabled');
select is((select relrowsecurity from pg_class where relname = 'payment_request_lines'), true, 'payment_request_lines has RLS enabled');

-- 2. Guard: ghi truc tiep bi chan; ap_ledger bat bien (chay truoc khi
--    doi role authenticated; superuser bo qua RLS nhung trigger van chay).
select throws_ok(
  $q$insert into public.supplier_invoices (org_id, legal_entity_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date) values ('d0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'INV-X', 'AA', '1', '2026-11-09')$q$,
  'P0001', 'ERR_WRITE_GUARD: supplier_invoices chi duoc ghi qua RPC',
  'Direct supplier_invoices insert is blocked by trigger'
);
select throws_ok(
  $q$insert into public.ap_ledger (org_id, legal_entity_id, property_id, supplier_id, doc_type, doc_id, amount, entry_date) values ('d0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'supplier_invoice', 'd0400000-0000-4000-8000-000000000001', 100, '2026-11-09')$q$,
  'P0001', 'ERR_WRITE_GUARD: ap_ledger chi duoc ghi qua RPC',
  'Direct ap_ledger insert is blocked by trigger'
);
select throws_ok(
  $q$insert into public.payment_requests (org_id, legal_entity_id, property_id, supplier_id, doc_no, total) values ('d0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'PAY-X', 100)$q$,
  'P0001', 'ERR_WRITE_GUARD: payment_requests chi duoc ghi qua RPC',
  'Direct payment_requests insert is blocked by trigger'
);
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.ap_ledger (id, org_id, legal_entity_id, property_id, supplier_id, doc_type, doc_id, amount, entry_date) values
  ('d0400000-0000-4000-8000-000000000f01', 'd0400000-0000-4000-8000-000000000001', 'd0400000-0000-4000-8000-000000000101', 'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', 'supplier_invoice', 'd0400000-0000-4000-8000-000000000001', 100, '2026-11-09');
select set_config('app.finance_guard_bypass', 'off', true);
select throws_ok(
  $q$update public.ap_ledger set amount = 200 where id = 'd0400000-0000-4000-8000-000000000f01'$q$,
  '55000', 'ERR_IMMUTABLE_LEDGER:ap_ledger:UPDATE',
  'ap_ledger UPDATE is blocked by immutable trigger'
);
select throws_ok(
  $q$delete from public.ap_ledger where id = 'd0400000-0000-4000-8000-000000000f01'$q$,
  '55000', 'ERR_IMMUTABLE_LEDGER:ap_ledger:DELETE',
  'ap_ledger DELETE is blocked by immutable trigger'
);

-- Tu day tro di chay duoi role authenticated (RLS co hieu luc).
set local role authenticated;

-- 4. Nhap hoa don nhap (a01): 3 dong PO1, VAT 10% -> truoc thue 500000,
--    VAT 50000, tong 550000.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('inv1', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000001", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c01", "qty": 10, "unit_price": 10000, "vat_rate": 10},
    {"po_line_id": "d0400000-0000-4000-8000-000000000c02", "qty": 5, "unit_price": 60000, "vat_rate": 10},
    {"po_line_id": "d0400000-0000-4000-8000-000000000c03", "qty": 20, "unit_price": 5000, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv1', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv1'));
select is((select resp ->> 'status' from t040_resp where key = 'inv1'), 'draft', 'invoice1 saved as draft');
select is((select (resp ->> 'total')::numeric from t040_resp where key = 'inv1'), 550000::numeric, 'invoice1 total = 550000 (500000 + 10% VAT)');
select is((select sum(amount) from public.supplier_invoice_lines where invoice_id = (select id from t040_ctx where key = 'inv1')), 500000::numeric, 'invoice1 lines amount sum = 500000');

-- 5. Nhap hoa don: cac ca loi.
select throws_ok(
  $q$select public.invoice_save_draft('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000703', '{"invoice_symbol": "AA", "invoice_no": "0000002", "invoice_date": "2026-11-09"}'::jsonb, '[{"po_line_id": "d0400000-0000-4000-8000-000000000c01", "qty": 1, "unit_price": 10000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'individual_no_invoice supplier cannot have VAT invoice'
);
select throws_ok(
  $q$select public.invoice_save_draft('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', '{"invoice_symbol": "AA", "invoice_no": "0000003", "invoice_date": "2026-11-09"}'::jsonb, '[{"po_line_id": "d0400000-0000-4000-8000-000000000c05", "qty": 1, "unit_price": 10000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'draft PO line cannot be invoiced'
);
select throws_ok(
  $q$select public.invoice_save_draft('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', '{"invoice_symbol": "AA", "invoice_no": "0000001", "invoice_date": "2026-11-09"}'::jsonb, '[{"po_line_id": "d0400000-0000-4000-8000-000000000c01", "qty": 1, "unit_price": 10000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'duplicate invoice symbol+number is rejected'
);
select throws_ok(
  $q$select public.invoice_save_draft('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', '{"invoice_symbol": "AA", "invoice_no": "0000004", "invoice_date": "2026-11-09"}'::jsonb, '[{"po_line_id": "d0400000-0000-4000-8000-000000000c06", "qty": 1, "unit_price": 10000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'PO line of another supplier cannot be invoiced'
);
select throws_ok(
  $q$select public.invoice_save_draft('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', '{"invoice_symbol": "AA", "invoice_no": "0000005", "invoice_date": "2026-11-09"}'::jsonb, '[{"po_line_id": "d0400000-0000-4000-8000-000000000c01", "qty": 0, "unit_price": 10000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'zero qty line is rejected'
);
select throws_ok(
  $q$select public.invoice_save_draft('d0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701', '{"invoice_symbol": "AA", "invoice_no": "0000006", "invoice_date": "2026-11-09"}'::jsonb, '[{"po_line_id": "d0400000-0000-4000-8000-000000000c01", "gr_line_id": "d0400000-0000-4000-8000-000000000e14", "qty": 1, "unit_price": 10000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'GR line of another PO line is rejected'
);

-- 6. Khop 3 chieu: invoice1 khop du -> matched.
insert into t040_resp values ('match1', public.invoice_match((select id from t040_ctx where key = 'inv1')));
select is((select resp ->> 'status' from t040_resp where key = 'match1'), 'matched', 'invoice1 matched');
select is((select status from public.supplier_invoices where id = (select id from t040_ctx where key = 'inv1')), 'matched', 'invoice1 status matched in table');
select is((select count(*) from public.supplier_invoice_lines where invoice_id = (select id from t040_ctx where key = 'inv1') and (match_result ->> 'qty_ok')::boolean and (match_result ->> 'price_ok')::boolean), 3::bigint, 'invoice1 all 3 lines qty_ok + price_ok');

-- 7. So luong vuot so nhan: PO2 GAO nhan 10, hoa don 11 -> on_hold.
insert into t040_resp values ('inv2', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000007", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c04", "qty": 11, "unit_price": 10000, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv2', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv2'));
insert into t040_resp values ('match2', public.invoice_match((select id from t040_ctx where key = 'inv2')));
select is((select resp ->> 'status' from t040_resp where key = 'match2'), 'on_hold', 'invoice2 on_hold (qty over received)');
select is((select match_result ->> 'reason' from public.supplier_invoice_lines where invoice_id = (select id from t040_ctx where key = 'inv2')), 'QTY_OVER_RECEIVED', 'invoice2 line reason QTY_OVER_RECEIVED');

-- 8. Don gia lech 2% (> dung sai 1%) -> on_hold.
insert into t040_resp values ('inv3', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000008", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c04", "qty": 10, "unit_price": 10200, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv3', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv3'));
insert into t040_resp values ('match3', public.invoice_match((select id from t040_ctx where key = 'inv3')));
select is((select resp ->> 'status' from t040_resp where key = 'match3'), 'on_hold', 'invoice3 on_hold (price +2% over tolerance)');
select is((select match_result ->> 'reason' from public.supplier_invoice_lines where invoice_id = (select id from t040_ctx where key = 'inv3')), 'PRICE_OVER_TOLERANCE', 'invoice3 line reason PRICE_OVER_TOLERANCE');

-- 9. Don gia lech dung 1% (ranh gioi) -> matched.
insert into t040_resp values ('inv4', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000009", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c04", "qty": 10, "unit_price": 10100, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv4', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv4'));
insert into t040_resp values ('match4', public.invoice_match((select id from t040_ctx where key = 'inv4')));
select is((select resp ->> 'status' from t040_resp where key = 'match4'), 'matched', 'invoice4 matched (price exactly +1% tolerance)');

-- 10. Chong hoa don trung: invoice4 da khop het 10kg PO2, them 1kg -> on_hold.
insert into t040_resp values ('inv5', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000010", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c04", "qty": 1, "unit_price": 10000, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv5', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv5'));
insert into t040_resp values ('match5', public.invoice_match((select id from t040_ctx where key = 'inv5')));
select is((select resp ->> 'status' from t040_resp where key = 'match5'), 'on_hold', 'invoice5 on_hold (qty already invoiced by invoice4)');

-- 11. Duyet hoa don: invoice1 (a02, khong phai nguoi tao) -> approved +
--     ap_ledger (+) 550000, han tra = 09/11 + 30 ngay = 09/12.
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('appr1', public.invoice_approve((select id from t040_ctx where key = 'inv1')));
select is((select resp ->> 'status' from t040_resp where key = 'appr1'), 'approved', 'invoice1 approved');
select is((select amount from public.ap_ledger where doc_type = 'supplier_invoice' and doc_id = (select id from t040_ctx where key = 'inv1')), 550000::numeric, 'ap_ledger (+) 550000 for invoice1');
select is((select due_date from public.ap_ledger where doc_type = 'supplier_invoice' and doc_id = (select id from t040_ctx where key = 'inv1')), '2026-12-09'::date, 'ap_ledger due_date = invoice_date + 30 payment terms');
select throws_ok(
  format('select public.invoice_approve(%L::uuid)', (select id::text from t040_ctx where key = 'inv2')),
  'P0001', 'ERR_INVALID_STATUS',
  'on_hold invoice cannot be approved'
);
-- SoD: a02 tao invoice6 (SUP2/PO4) roi tu duyet -> bi chan.
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('inv6', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000702',
  '{"invoice_symbol": "BB", "invoice_no": "0000001", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c06", "qty": 10, "unit_price": 10000, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv6', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv6'));
insert into t040_resp values ('match6', public.invoice_match((select id from t040_ctx where key = 'inv6')));
select is((select resp ->> 'status' from t040_resp where key = 'match6'), 'matched', 'invoice6 matched (SUP2, PO4)');
select throws_ok(
  format('select public.invoice_approve(%L::uuid)', (select id::text from t040_ctx where key = 'inv6')),
  'P0001', 'ERR_SOD_INVOICE_CREATOR_APPROVER',
  'invoice creator cannot approve own invoice (SoD)'
);
-- Duyet hoa don draft (chua khop) -> loi trang thai.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('inv7', public.invoice_save_draft(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000011", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "d0400000-0000-4000-8000-000000000c03", "qty": 1, "unit_price": 5000, "vat_rate": 10}]'::jsonb
));
insert into t040_ctx values ('inv7', (select (resp ->> 'id')::uuid from t040_resp where key = 'inv7'));
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
select throws_ok(
  format('select public.invoice_approve(%L::uuid)', (select id::text from t040_ctx where key = 'inv7')),
  'P0001', 'ERR_INVALID_STATUS',
  'draft invoice cannot be approved'
);

-- 12. Tra hang -> ap_ledger (-) chi phan da co hoa don duyet (a07).
select public._t040_as('d0400000-0000-4000-8000-000000000a07');
insert into t040_resp values ('ret1', public.supplier_return_post(
  'd0400000-0000-4000-8000-000000000e01',
  '[{"gr_line_id": "d0400000-0000-4000-8000-000000000e11", "qty_stock": 4, "reason": "Hỏng"}]'::jsonb
));
insert into t040_ctx values ('ret1', (select (resp ->> 'id')::uuid from t040_resp where key = 'ret1'));
select is((select resp ->> 'ok' from t040_resp where key = 'ret1'), 'true', 'return1 posted');
select is((select amount from public.ap_ledger where doc_type = 'supplier_return' and doc_id = (select id from t040_ctx where key = 'ret1')), -40000::numeric, 'ap_ledger (-) 40000 for return1 (4kg x 10000 invoiced)');
-- Tra hang chua co hoa don duyet (GR2, invoice4 moi 'matched') -> khong ghi so.
insert into t040_resp values ('ret2', public.supplier_return_post(
  'd0400000-0000-4000-8000-000000000e02',
  '[{"gr_line_id": "d0400000-0000-4000-8000-000000000e14", "qty_stock": 2, "reason": "Hỏng"}]'::jsonb
));
insert into t040_ctx values ('ret2', (select (resp ->> 'id')::uuid from t040_resp where key = 'ret2'));
select is((select resp ->> 'ok' from t040_resp where key = 'ret2'), 'true', 'return2 posted');
select is((select count(*) from public.ap_ledger where doc_type = 'supplier_return' and doc_id = (select id from t040_ctx where key = 'ret2')), 0::bigint, 'no ap_ledger entry for return2 (no approved invoice)');
-- Tra not 6kg GAO con lai cua GR1 -> tru not phan hoa don con lai 60000.
insert into t040_resp values ('ret3', public.supplier_return_post(
  'd0400000-0000-4000-8000-000000000e01',
  '[{"gr_line_id": "d0400000-0000-4000-8000-000000000e11", "qty_stock": 6, "reason": "Hỏng"}]'::jsonb
));
insert into t040_ctx values ('ret3', (select (resp ->> 'id')::uuid from t040_resp where key = 'ret3'));
select is((select resp ->> 'ok' from t040_resp where key = 'ret3'), 'true', 'return3 posted');
select is((select amount from public.ap_ledger where doc_type = 'supplier_return' and doc_id = (select id from t040_ctx where key = 'ret3')), -60000::numeric, 'ap_ledger (-) 60000 for return3 (remaining invoiced 6kg)');

-- 13. Quyet toan tam ung.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('stl1', public.advance_settle(
  'd0400000-0000-4000-8000-000000000901',
  '[{"amount": 800000}, {"gr_id": "d0400000-0000-4000-8000-000000000e01", "amount": 150000}]'::jsonb
));
select is((select (resp ->> 'spent')::numeric from t040_resp where key = 'stl1'), 950000::numeric, 'ADV1 settled: spent 950000');
select is((select (resp ->> 'refund_amount')::numeric from t040_resp where key = 'stl1'), 50000::numeric, 'ADV1 settled: refund 50000 (1000000 - 950000)');
select is((select status from public.advances where id = 'd0400000-0000-4000-8000-000000000901'), 'settled', 'ADV1 status settled');
-- SoD: nguoi giu tam ung (a06, co advance.settle) khong duoc tu quyet toan.
select public._t040_as('d0400000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.advance_settle('d0400000-0000-4000-8000-000000000902', '[{"amount": 100000}]'::jsonb)$q$,
  'P0001', 'ERR_SOD_ADVANCE_SETTLER',
  'advance holder cannot settle own advance (SoD)'
);
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.advance_settle('d0400000-0000-4000-8000-000000000901', '[{"amount": 100000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'already settled advance cannot be settled again'
);
select throws_ok(
  $q$select public.advance_settle('d0400000-0000-4000-8000-000000000904', '[{"amount": 0}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'zero settlement line amount is rejected'
);
-- Chi vuot tam ung: ADV3 300000, chi 350000 -> tra them 50000.
insert into t040_resp values ('stl3', public.advance_settle(
  'd0400000-0000-4000-8000-000000000903',
  '[{"amount": 350000}]'::jsonb
));
select is((select (resp ->> 'extra_pay_amount')::numeric from t040_resp where key = 'stl3'), 50000::numeric, 'ADV3 settled: extra pay 50000 (350000 - 300000)');
select is((select status from public.advances where id = 'd0400000-0000-4000-8000-000000000903'), 'settled', 'ADV3 status settled');

-- 14. De nghi thanh toan.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('pr1', public.payment_request_create(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv1'), 'amount', 300000)),
  null
));
insert into t040_ctx values ('pr1', (select (resp ->> 'id')::uuid from t040_resp where key = 'pr1'));
select is((select resp ->> 'status' from t040_resp where key = 'pr1'), 'submitted', 'payment request1 submitted');
select is((select (resp ->> 'steps')::integer from t040_resp where key = 'pr1'), 1, 'payment request1 has 1 default step (chief_accountant)');
select throws_ok(
  format('select public.payment_request_create(%L::uuid, %L::uuid, %L::jsonb, null)',
    'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701',
    jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv6'), 'amount', 1000))::text),
  'P0001', 'ERR_INVALID_VALUE',
  'matched (not approved) invoice cannot be paid'
);
select throws_ok(
  format('select public.payment_request_create(%L::uuid, %L::uuid, %L::jsonb, null)',
    'd0400000-0000-4000-8000-000000000201', 'd0400000-0000-4000-8000-000000000701',
    jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv1'), 'amount', 300000))::text),
  'P0001', 'ERR_INVALID_VALUE',
  'amount over remaining payable is rejected (300000 already requested)'
);
-- Duyet invoice6 (SUP2) bang owner a04 (khong phai nguoi tao a02).
select public._t040_as('d0400000-0000-4000-8000-000000000a04');
insert into t040_resp values ('appr6', public.invoice_approve((select id from t040_ctx where key = 'inv6')));
select is((select resp ->> 'status' from t040_resp where key = 'appr6'), 'approved', 'invoice6 approved by owner');
-- Duyet invoice4 (PO2) bang a02 de dung cho de nghi thanh toan sau.
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('appr4', public.invoice_approve((select id from t040_ctx where key = 'inv4')));
select is((select resp ->> 'status' from t040_resp where key = 'appr4'), 'approved', 'invoice4 approved');
-- NCC doi STK trong 30 ngay (SUP2) -> them buoc duyet owner.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('pr2', public.payment_request_create(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000702',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv6'), 'amount', 110000)),
  null
));
insert into t040_ctx values ('pr2', (select (resp ->> 'id')::uuid from t040_resp where key = 'pr2'));
select is((select (resp ->> 'steps')::integer from t040_resp where key = 'pr2'), 2, 'payment request2 has 2 steps (bank changed within 30 days)');
select is((select (resp ->> 'bank_changed_extra_step')::boolean from t040_resp where key = 'pr2'), true, 'payment request2 flags bank_changed_extra_step');

-- 15. Duyet de nghi thanh toan.
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('dec1', public.payment_request_decide(
  'd0400000-0000-4000-8000-000000000201',
  (select id from t040_ctx where key = 'pr1'), 'approved', null
));
select is((select resp ->> 'status' from t040_resp where key = 'dec1'), 'approved', 'payment request1 approved by chief');
insert into t040_resp values ('dec2a', public.payment_request_decide(
  'd0400000-0000-4000-8000-000000000201',
  (select id from t040_ctx where key = 'pr2'), 'approved', null
));
select is((select resp ->> 'status' from t040_resp where key = 'dec2a'), 'submitted', 'payment request2 still submitted after step 1 (owner step pending)');
select public._t040_as('d0400000-0000-4000-8000-000000000a04');
insert into t040_resp values ('dec2b', public.payment_request_decide(
  'd0400000-0000-4000-8000-000000000201',
  (select id from t040_ctx where key = 'pr2'), 'approved', null
));
select is((select resp ->> 'status' from t040_resp where key = 'dec2b'), 'approved', 'payment request2 approved by owner (step 2)');
-- De nghi moi cho invoice1 (con 250000) roi duyet bang nguoi khong co quyen.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('pr3', public.payment_request_create(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv1'), 'amount', 250000)),
  null
));
insert into t040_ctx values ('pr3', (select (resp ->> 'id')::uuid from t040_resp where key = 'pr3'));
select public._t040_as('d0400000-0000-4000-8000-000000000a03');
select throws_ok(
  format('select public.payment_request_decide(%L::uuid, %L::uuid, %L, null)',
    'd0400000-0000-4000-8000-000000000201', (select id::text from t040_ctx where key = 'pr3'), 'approved'),
  '42501', 'ERR_FORBIDDEN:payment.approve',
  'gm without payment.approve cannot decide'
);
-- SoD: a02 tao de nghi roi tu duyet buoc 1 -> bi chan.
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('pr4', public.payment_request_create(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv4'), 'amount', 50000)),
  null
));
insert into t040_ctx values ('pr4', (select (resp ->> 'id')::uuid from t040_resp where key = 'pr4'));
select throws_ok(
  format('select public.payment_request_decide(%L::uuid, %L::uuid, %L, null)',
    'd0400000-0000-4000-8000-000000000201', (select id::text from t040_ctx where key = 'pr4'), 'approved'),
  'P0001', 'ERR_SOD_PAYMENT_CREATOR_APPROVER',
  'payment request creator cannot approve own request (SoD)'
);
-- Tu choi khong ly do -> loi; tu choi co ly do -> cancelled.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('pr5', public.payment_request_create(
  'd0400000-0000-4000-8000-000000000201',
  'd0400000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from t040_ctx where key = 'inv4'), 'amount', 61100)),
  null
));
insert into t040_ctx values ('pr5', (select (resp ->> 'id')::uuid from t040_resp where key = 'pr5'));
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
select throws_ok(
  format('select public.payment_request_decide(%L::uuid, %L::uuid, %L, null)',
    'd0400000-0000-4000-8000-000000000201', (select id::text from t040_ctx where key = 'pr5'), 'rejected'),
  'P0001', 'ERR_REASON_REQUIRED',
  'reject without reason is rejected'
);
insert into t040_resp values ('dec5', public.payment_request_decide(
  'd0400000-0000-4000-8000-000000000201',
  (select id from t040_ctx where key = 'pr5'), 'rejected', 'Sai số tiền'
));
select is((select resp ->> 'status' from t040_resp where key = 'dec5'), 'cancelled', 'payment request5 cancelled after reject with reason');

-- 16. Ghi nhan da thanh toan.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('paid1', public.payment_mark_paid(
  (select id from t040_ctx where key = 'pr1'), 'BANK-001'
));
select is((select resp ->> 'status' from t040_resp where key = 'paid1'), 'paid', 'payment request1 paid');
select is((select amount from public.ap_ledger where doc_type = 'payment_request' and doc_id = (select id from t040_ctx where key = 'pr1')), -300000::numeric, 'ap_ledger (-) 300000 for payment request1');
select is((select status from public.supplier_invoices where id = (select id from t040_ctx where key = 'inv1')), 'partially_paid', 'invoice1 partially_paid after 300000 of 550000');
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('dec3', public.payment_request_decide(
  'd0400000-0000-4000-8000-000000000201',
  (select id from t040_ctx where key = 'pr3'), 'approved', null
));
select is((select resp ->> 'status' from t040_resp where key = 'dec3'), 'approved', 'payment request3 approved by chief');
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('paid3', public.payment_mark_paid(
  (select id from t040_ctx where key = 'pr3'), 'BANK-002'
));
select is((select status from public.supplier_invoices where id = (select id from t040_ctx where key = 'inv1')), 'paid', 'invoice1 paid after remaining 250000');
select throws_ok(
  format('select public.payment_mark_paid(%L::uuid, %L)', (select id::text from t040_ctx where key = 'pr4'), 'BANK-003'),
  'P0001', 'ERR_INVALID_STATUS',
  'submitted payment request cannot be marked paid'
);

-- 17. RLS ap_ledger: thu kho khong thay gi; ke toan thay du 7 dong
--     (tru dong f01 cua test guard o muc 2).
select public._t040_as('d0400000-0000-4000-8000-000000000a07');
select is((select count(*) from public.ap_ledger), 0::bigint, 'storekeeper sees 0 ap_ledger rows');
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
select is((select count(*) from public.ap_ledger where id <> 'd0400000-0000-4000-8000-000000000f01'), 7::bigint, 'accountant sees 7 ap_ledger rows (3 invoice + 2 returns + 2 payments)');

-- 18. Bang ke khong hoa don.
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
insert into t040_resp values ('lst1', public.no_invoice_listing_save(
  'd0400000-0000-4000-8000-000000000201',
  '{"seller_name": "Bà Tư chợ", "seller_address": "Chợ Hội An", "purchase_date": "2026-11-09", "po_id": "d0400000-0000-4000-8000-000000000b02"}'::jsonb,
  '[{"item_desc": "Rau muống", "qty": 5, "unit_price": 8000}]'::jsonb
));
insert into t040_ctx values ('lst1', (select (resp ->> 'id')::uuid from t040_resp where key = 'lst1'));
select is((select resp ->> 'status' from t040_resp where key = 'lst1'), 'draft', 'listing saved as draft');
select is((select (resp ->> 'total')::numeric from t040_resp where key = 'lst1'), 40000::numeric, 'listing total = 40000 (5 x 8000)');
select public._t040_as('d0400000-0000-4000-8000-000000000a02');
insert into t040_resp values ('lstappr', public.no_invoice_listing_approve((select id from t040_ctx where key = 'lst1')));
select is((select resp ->> 'status' from t040_resp where key = 'lstappr'), 'approved', 'listing approved by chief');
select public._t040_as('d0400000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.no_invoice_listing_save('d0400000-0000-4000-8000-000000000201', '{"seller_name": "", "purchase_date": "2026-11-09"}'::jsonb, '[{"item_desc": "Rau", "qty": 1, "unit_price": 1000}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'listing without seller name is rejected'
);

select * from finish();
rollback;
