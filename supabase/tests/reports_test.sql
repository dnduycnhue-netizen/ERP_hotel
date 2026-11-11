-- T-044 pgTAP: 10 bao cao MVP (report_get) + report_build_daily + snapshot.
-- Kiem tra: so lieu moi bao cao khop truy van kiem tra doc lap (tinh lai
-- bang SQL truc tiep tu bang nguon), RLS + write-guard cua report_snapshots,
-- catalog report.view.*, Q64 (cost_controller khong co pms.input van doc
-- duoc CPOR qua RPC SECURITY DEFINER), tu choi quyen, tham so sai.
-- Du lieu mau: khach san P044, ky 2026-11-09..2026-11-10, thang 2026-11,
-- rooms_sold thang 100 (10 ngay x 10 phong).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(82);

-- ---------------------------------------------------------------------------
-- 0. Fixture: master data + nguoi dung + quyen.
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d0440000-0000-4000-8000-000000000001', 'T-044 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000001', 'T044', 'Entity T-044');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'P0441', 'Property T-044', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0440000-0000-4000-8000-000000000401', 'd0440000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d0440000-0000-4000-8000-000000000402', 'd0440000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
  ('d0440000-0000-4000-8000-000000000403', 'd0440000-0000-4000-8000-000000000001', 'MUOI', 'Muối', 'other'),
  ('d0440000-0000-4000-8000-000000000404', 'd0440000-0000-4000-8000-000000000001', 'LAVIE', 'Nước Lavie', 'other'),
  ('d0440000-0000-4000-8000-000000000405', 'd0440000-0000-4000-8000-000000000001', 'DASANI', 'Nước Dasani', 'other'),
  ('d0440000-0000-4000-8000-000000000406', 'd0440000-0000-4000-8000-000000000001', 'AMEN', 'Amenities', 'amenity');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d0440000-0000-4000-8000-000000000501', 'd0440000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0440000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market'], false),
  ('d0440000-0000-4000-8000-000000000502', 'd0440000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0440000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract'], false),
  ('d0440000-0000-4000-8000-000000000503', 'd0440000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0440000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market'], false),
  ('d0440000-0000-4000-8000-000000000504', 'd0440000-0000-4000-8000-000000000001', 'ITM_LAVIE', 'Lavie 500ml', 'd0440000-0000-4000-8000-000000000404', 'cai', false, false, null, array['contract'], false),
  ('d0440000-0000-4000-8000-000000000505', 'd0440000-0000-4000-8000-000000000001', 'ITM_DASANI', 'Dasani 500ml', 'd0440000-0000-4000-8000-000000000405', 'cai', false, false, null, array['contract'], false),
  ('d0440000-0000-4000-8000-000000000506', 'd0440000-0000-4000-8000-000000000001', 'ITM_AMEN1', 'Dầu gội', 'd0440000-0000-4000-8000-000000000406', 'cai', false, false, null, array['contract'], false);

insert into public.cost_centers (id, org_id, code, name) values
  ('d0440000-0000-4000-8000-000000000901', 'd0440000-0000-4000-8000-000000000001', 'FB', 'F&B');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0440000-0000-4000-8000-000000000902', 'd0440000-0000-4000-8000-000000000001', 'FOOD', 'Thực phẩm'),
  ('d0440000-0000-4000-8000-000000000903', 'd0440000-0000-4000-8000-000000000001', 'AMEN', 'Amenities');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null);

insert into public.room_types (id, property_id, code, name) values
  ('d0440000-0000-4000-8000-000000000904', 'd0440000-0000-4000-8000-000000000201', 'DLX', 'Deluxe');

insert into public.rooms (id, property_id, room_type_id, room_no) values
  ('d0440000-0000-4000-8000-000000000905', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000904', 'R101');

insert into public.lots (id, org_id, property_id, item_id, lot_no, expiry_date) values
  ('d0440000-0000-4000-8000-000000000906', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000502', 'LOT-THIT-001', '2027-01-01');

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('d0440000-0000-4000-8000-000000000701', 'd0440000-0000-4000-8000-000000000001', 'NCC1', 'Nhà cung cấp 1', 'company', 'active'),
  ('d0440000-0000-4000-8000-000000000702', 'd0440000-0000-4000-8000-000000000001', 'NCC2', 'Nhà cung cấp 2', 'company', 'active');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0440000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-cc044@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0440000-0000-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u5-own044@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0440000-0000-4000-8000-000000000a03', 'NV04403', 'Cost Controller'),
  ('d0440000-0000-4000-8000-000000000a05', 'NV04405', 'Chủ đầu tư')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0440000-0000-4000-8000-000000000603', 'd0440000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('d0440000-0000-4000-8000-000000000605', 'd0440000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư');

insert into public.role_permissions (role_id, permission_code) values
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_stock_card'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_receiving_quality'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_open_po_invoice'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_ap_aging'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_advances'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_waste'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_opex'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_minibar'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_amenity_cpor'),
  ('d0440000-0000-4000-8000-000000000605', 'report.view.rpt_daily_brief'),
  ('d0440000-0000-4000-8000-000000000603', 'report.view.rpt_opex'),
  ('d0440000-0000-4000-8000-000000000603', 'report.view.rpt_amenity_cpor');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0440000-0000-4000-8000-000000000a03', 'd0440000-0000-4000-8000-000000000603', 'd0440000-0000-4000-8000-000000000201'),
  ('d0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000605', null);

-- Bat bypass cho cac bang co write-guard de chen fixture truc tiep.
do $$
begin
  perform set_config('app.pr_po_guard_bypass', 'on', true);
  perform set_config('app.receiving_guard_bypass', 'on', true);
  perform set_config('app.advance_guard_bypass', 'on', true);
  perform set_config('app.inventory_guard_bypass', 'on', true);
  perform set_config('app.minibar_guard_bypass', 'on', true);
  perform set_config('app.pms_daily_guard_bypass', 'on', true);
  perform set_config('app.finance_guard_bypass', 'on', true);
  perform set_config('app.service_guard_bypass', 'on', true);
end $$;

-- ---------------------------------------------------------------------------
-- 0b. Fixture: so lieu nghiep vu.
-- ---------------------------------------------------------------------------
-- stock_moves: ton dau 11-08 (LAVIE 20, DASANI 30, AMEN1 50) + phat sinh 11-09.
insert into public.stock_moves (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id, cost_center_id, expense_category_id, purpose_code) values
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000504', null, 'receipt', 20, 3000, 60000, '2026-11-08', 'd0440000-0000-4000-8000-000000000a05', 'opening', 'd0440000-0000-4000-8000-000000000f01', null, null, null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000505', null, 'receipt', 30, 4000, 120000, '2026-11-08', 'd0440000-0000-4000-8000-000000000a05', 'opening', 'd0440000-0000-4000-8000-000000000f01', null, null, null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000506', null, 'receipt', 50, 5000, 250000, '2026-11-08', 'd0440000-0000-4000-8000-000000000a05', 'opening', 'd0440000-0000-4000-8000-000000000f01', null, null, null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000501', null, 'receipt', 200, 10000, 2000000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'opening', 'd0440000-0000-4000-8000-000000000f01', null, null, null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000502', 'd0440000-0000-4000-8000-000000000906', 'receipt', 20, 60000, 1200000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'opening', 'd0440000-0000-4000-8000-000000000f01', null, null, null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000501', null, 'purpose_issue', -30, 10000, -300000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'purpose_issue', 'd0440000-0000-4000-8000-000000000f02', 'd0440000-0000-4000-8000-000000000901', 'd0440000-0000-4000-8000-000000000902', 'kitchen'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000502', 'd0440000-0000-4000-8000-000000000906', 'waste', -5, 60000, -300000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'waste_report', 'd0440000-0000-4000-8000-000000000f03', 'd0440000-0000-4000-8000-000000000901', 'd0440000-0000-4000-8000-000000000902', null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000506', null, 'purpose_issue', -10, 5000, -50000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'purpose_issue', 'd0440000-0000-4000-8000-000000000f04', 'd0440000-0000-4000-8000-000000000901', 'd0440000-0000-4000-8000-000000000903', 'housekeeping'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000504', null, 'minibar_sale', -4, 3000, -12000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'minibar_check', 'd0440000-0000-4000-8000-000000000f05', null, null, null),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'd0440000-0000-4000-8000-000000000505', null, 'purpose_issue', -6, 4000, -24000, '2026-11-09', 'd0440000-0000-4000-8000-000000000a05', 'purpose_issue', 'd0440000-0000-4000-8000-000000000f06', 'd0440000-0000-4000-8000-000000000901', 'd0440000-0000-4000-8000-000000000903', 'housekeeping');

-- Don mua mo: PO1 approved (GAO 100 nhan 90, MUOI 20 nhan 0), PO2 sent (THIT 10 nhan 0).
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, total_amount, status, doc_no) values
  ('d0440000-0000-4000-8000-000000000c01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-05', '2026-11-08', 1100000, 'approved', 'PO-044-001'),
  ('d0440000-0000-4000-8000-000000000c02', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000702', 'contract', 'stock', '2026-11-06', '2026-11-09', 600000, 'sent', 'PO-044-002');

insert into public.purchase_order_lines (id, po_id, org_id, item_id, qty, uom, qty_stock, unit_price, price_source, received_qty_stock, expense_category_id, cost_center_id) values
  ('d0440000-0000-4000-8000-000000000c11', 'd0440000-0000-4000-8000-000000000c01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000501', 100, 'kg', 100, 10000, 'agreement', 90, 'd0440000-0000-4000-8000-000000000902', 'd0440000-0000-4000-8000-000000000901'),
  ('d0440000-0000-4000-8000-000000000c12', 'd0440000-0000-4000-8000-000000000c01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000503', 20, 'kg', 20, 5000, 'agreement', 0, 'd0440000-0000-4000-8000-000000000902', 'd0440000-0000-4000-8000-000000000901'),
  ('d0440000-0000-4000-8000-000000000c13', 'd0440000-0000-4000-8000-000000000c02', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000502', 10, 'kg', 10, 60000, 'agreement', 0, 'd0440000-0000-4000-8000-000000000902', 'd0440000-0000-4000-8000-000000000901');

-- Phieu nhan GR1 posted 2026-11-09 (GAO 90/100 pass; MUOI 20 nhan, 0 chap nhan, QC fail, can 2 lan) + tra hang 20 MUOI.
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, po_id, supplier_id, warehouse_id, doc_no, receiver_id, received_at, status, total_amount) values
  ('d0440000-0000-4000-8000-000000000d01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000c01', 'd0440000-0000-4000-8000-000000000701', 'd0440000-0000-4000-8000-000000000301', 'GR-044-001', 'd0440000-0000-4000-8000-000000000a05', '2026-11-09 10:00:00+07', 'posted', 900000);

insert into public.goods_receipt_lines (id, gr_id, org_id, property_id, po_line_id, item_id, gross_qty, tare_qty, uom, net_qty_stock, unit_cost, accepted_qty_stock, qc_status, weigh_count, weigh2_gross_qty, weigh2_tare_qty) values
  ('d0440000-0000-4000-8000-000000000d11', 'd0440000-0000-4000-8000-000000000d01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000c11', 'd0440000-0000-4000-8000-000000000501', 95, 5, 'kg', 90, 10000, 90, 'pass', 1, null, null),
  ('d0440000-0000-4000-8000-000000000d12', 'd0440000-0000-4000-8000-000000000d01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000c12', 'd0440000-0000-4000-8000-000000000503', 20, 0, 'kg', 20, 5000, 0, 'fail', 2, 20, 0);

-- Phieu tra 20 MUOI. created_at ghim 2026-11-09: _report_receiving_quality
-- loc returns theo created_at (khong phai ngay chung tu); mac dinh now() luc
-- chay test (11-11+) nam ngoai khoang from/to 11-09..11-10 -> return_count 0.
insert into public.supplier_returns (id, org_id, legal_entity_id, property_id, gr_id, po_id, supplier_id, doc_no, status, created_at) values
  ('d0440000-0000-4000-8000-000000000d21', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000d01', 'd0440000-0000-4000-8000-000000000c01', 'd0440000-0000-4000-8000-000000000701', 'RET-044-001', 'posted', '2026-11-09 10:00:00+07');

insert into public.supplier_return_lines (id, return_id, org_id, gr_line_id, item_id, qty_stock, unit_cost) values
  ('d0440000-0000-4000-8000-000000000d22', 'd0440000-0000-4000-8000-000000000d21', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000d12', 'd0440000-0000-4000-8000-000000000503', 20, 5000);

-- Hoa don: INV1 on_hold 1.100.000; INV2 approved 500.000 (tinh OPEX); INV3 approved 200.000.
insert into public.supplier_invoices (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date, total, status) values
  ('d0440000-0000-4000-8000-000000000e01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'INV-044-001', 'AA', '0001', '2026-11-09', 1100000, 'on_hold'),
  ('d0440000-0000-4000-8000-000000000e02', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'INV-044-002', 'AA', '0002', '2026-11-09', 500000, 'approved'),
  ('d0440000-0000-4000-8000-000000000e03', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'INV-044-003', 'AA', '0003', '2026-11-09', 200000, 'approved');

insert into public.supplier_invoice_lines (id, invoice_id, org_id, property_id, po_line_id, item_id, qty, unit_price, amount, match_result) values
  ('d0440000-0000-4000-8000-000000000e11', 'd0440000-0000-4000-8000-000000000e01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000c11', 'd0440000-0000-4000-8000-000000000501', 100, 10000, 1000000, '{"status": "mismatch"}'::jsonb),
  ('d0440000-0000-4000-8000-000000000e12', 'd0440000-0000-4000-8000-000000000e02', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000c11', 'd0440000-0000-4000-8000-000000000501', 50, 10000, 500000, '{}'::jsonb);

-- So cai cong no: L1 500.000 han 11-15; L2 200.000 han 11-05; thanh toan 150.000.
-- FIFO tai 11-10: 150.000 tru vao L2 truoc -> con 50.000 qua han 1-30 ngay.
insert into public.ap_ledger (id, org_id, legal_entity_id, property_id, supplier_id, doc_type, doc_id, amount, due_date, entry_date) values
  ('d0440000-0000-4000-8000-000000000e21', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'supplier_invoice', 'd0440000-0000-4000-8000-000000000e02', 500000, '2026-11-15', '2026-11-09'),
  ('d0440000-0000-4000-8000-000000000e22', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'supplier_invoice', 'd0440000-0000-4000-8000-000000000e03', 200000, '2026-11-05', '2026-11-09'),
  ('d0440000-0000-4000-8000-000000000e23', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'payment_request', 'd0440000-0000-4000-8000-000000000f09', -150000, null, '2026-11-09');

-- Tam ung: ADV1 qua han (han 11-08), ADV2 chua qua han (han 11-20).
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status, due_settle_at) values
  ('d0440000-0000-4000-8000-000000000a21', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000a03', 'ADV-044-001', 2000000, 'Đi chợ', 'disbursed', '2026-11-08 10:00:00+07'),
  ('d0440000-0000-4000-8000-000000000a22', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000a05', 'ADV-044-002', 1000000, 'Mua đồ dùng', 'approved', '2026-11-20 10:00:00+07');

-- Huy hang posted 11-09: het han THIT 5kg 300.000; vo GAO 10kg 100.000.
insert into public.waste_reports (id, org_id, legal_entity_id, property_id, warehouse_id, doc_no, business_date, status, reason_code, proposed_by) values
  ('d0440000-0000-4000-8000-000000000b01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'WR-044-001', '2026-11-09', 'posted', 'expired', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000b02', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000301', 'WR-044-002', '2026-11-09', 'posted', 'broken', 'd0440000-0000-4000-8000-000000000a05');

insert into public.waste_report_lines (id, waste_report_id, org_id, property_id, item_id, lot_id, qty_stock, unit_cost) values
  ('d0440000-0000-4000-8000-000000000b11', 'd0440000-0000-4000-8000-000000000b01', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000502', 'd0440000-0000-4000-8000-000000000906', 5, 60000),
  ('d0440000-0000-4000-8000-000000000b12', 'd0440000-0000-4000-8000-000000000b02', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000501', null, 10, 10000);

-- Minibar: MC1 charged Lavie 4x10.000; MC2 waived Lavie 2x10.000; MC3 pending 11-08 Lavie 3x10.000.
insert into public.minibar_checks (id, org_id, legal_entity_id, property_id, room_id, doc_no, business_date, trigger, checked_by, status, total_amount) values
  ('d0440000-0000-4000-8000-000000000b21', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000905', 'MC-044-001', '2026-11-09', 'daily', 'd0440000-0000-4000-8000-000000000a05', 'charged', 40000),
  ('d0440000-0000-4000-8000-000000000b22', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000905', 'MC-044-002', '2026-11-09', 'checkout', 'd0440000-0000-4000-8000-000000000a05', 'waived', 20000),
  ('d0440000-0000-4000-8000-000000000b23', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000905', 'MC-044-003', '2026-11-08', 'daily', 'd0440000-0000-4000-8000-000000000a05', 'pending_charge', 30000);

insert into public.minibar_check_lines (id, check_id, org_id, property_id, item_id, missing_qty, unit_price, amount) values
  ('d0440000-0000-4000-8000-000000000b31', 'd0440000-0000-4000-8000-000000000b21', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000504', 4, 10000, 40000),
  ('d0440000-0000-4000-8000-000000000b32', 'd0440000-0000-4000-8000-000000000b22', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000504', 2, 10000, 20000),
  ('d0440000-0000-4000-8000-000000000b33', 'd0440000-0000-4000-8000-000000000b23', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000504', 3, 10000, 30000);

-- PMS: 10 ngay 11-01..11-10, moi ngay ban 10 phong -> thang 100 dem.
insert into public.pms_daily_stats (org_id, legal_entity_id, property_id, business_date, rooms_available, rooms_sold, guests, breakfast_pax, extra_beds, checkouts, entered_by, created_by) values
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-01', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-02', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-03', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-04', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-05', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-06', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-07', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-08', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-09', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05'),
  ('d0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', '2026-11-10', 20, 10, 15, 10, 0, 5, 'd0440000-0000-4000-8000-000000000a05', 'd0440000-0000-4000-8000-000000000a05');

-- Hop dong dich vu: het han 11-20 (trong 30 ngay bao truoc) + ky 11 da nghiem thu + ky 10 chua nghiem thu.
insert into public.service_contracts (id, org_id, legal_entity_id, property_id, supplier_id, expense_category_id, cost_center_id, title, start_date, end_date, billing_cycle, amount_per_cycle, renew_notice_days, status) values
  ('d0440000-0000-4000-8000-000000000a31', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000701', 'd0440000-0000-4000-8000-000000000902', 'd0440000-0000-4000-8000-000000000901', 'Vệ sinh định kỳ', '2026-11-01', '2026-11-20', 'monthly', 1200000, 30, 'active');

insert into public.service_schedules (id, org_id, legal_entity_id, property_id, contract_id, period_start, period_end, due_date, status) values
  ('d0440000-0000-4000-8000-000000000a32', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000a31', '2026-11-01', '2026-11-30', '2026-11-30', 'accepted'),
  ('d0440000-0000-4000-8000-000000000a33', 'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101', 'd0440000-0000-4000-8000-000000000201', 'd0440000-0000-4000-8000-000000000a31', '2026-10-01', '2026-10-31', '2026-10-31', 'scheduled');

-- Canh bao do chua xu ly (tao luc chay test -> trong 24h).
insert into public.alerts (property_id, code, severity, title, doc_type, doc_id) values
  ('d0440000-0000-4000-8000-000000000201', 'ADVANCE_OVERDUE', 'red', 'Tạm ứng quá hạn', 'advance', 'd0440000-0000-4000-8000-000000000a21'),
  ('d0440000-0000-4000-8000-000000000201', 'MINIBAR_LOSS', 'red', 'Minibar thất thoát', 'waste', 'd0440000-0000-4000-8000-000000000b01');

-- C10 (529000): _report_stock_card doc tu mv_report_stock_card_daily, chi
-- moi sau moi lan lam moi. Fixture stock_moves chen sau lan lam moi cuoi nen
-- phai lam moi MV truoc khi goi report_get, neu khong the kho tra 0 dong
-- (tien le report_matview_dashboard_test.sql §A/§C: MV cu khong thay move moi).
-- Goi duoi quyen postgres (auth.uid() null) nen bo qua kiem tra quyen.
select public.report_refresh_stock_card_mv();

-- ---------------------------------------------------------------------------
-- 0c. Bang tam luu ket qua + helper doc so.
-- ---------------------------------------------------------------------------
create temp table t044_resp (key text primary key, resp jsonb);
grant all on t044_resp to authenticated;

create or replace function public._t044_as(p_user uuid)
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

create or replace function public._t044_num(p_key text, p_match_key text, p_match_val text, p_field text)
returns numeric
language sql stable
as $$
  select (r ->> p_field)::numeric
  from jsonb_array_elements((select resp->'rows' from t044_resp where key = p_key)) r
  where r ->> p_match_key = p_match_val;
$$;

create or replace function public._t044_total(p_key text, p_field text)
returns numeric
language sql stable
as $$
  select (resp->'totals'->>p_field)::numeric from t044_resp where key = p_key;
$$;

create or replace function public._t044_rows(p_key text)
returns bigint
language sql stable
as $$
  select jsonb_array_length(resp->'rows') from t044_resp where key = p_key;
$$;

create or replace function public._t044_val(p_key text, p_field text)
returns text
language sql stable
as $$
  select resp->>p_field from t044_resp where key = p_key;
$$;

create or replace function public._t044_len(p_key text, p_field text)
returns bigint
language sql stable
as $$
  select jsonb_array_length(resp->p_field) from t044_resp where key = p_key;
$$;

-- ---------------------------------------------------------------------------
-- A. Schema / RLS / catalog.
-- ---------------------------------------------------------------------------
select is(
  (select relrowsecurity from pg_class where relname = 'report_snapshots'),
  true, 'report_snapshots has RLS enabled'
);
select is(
  (select count(*) from pg_indexes where tablename = 'report_snapshots' and indexdef like '%(id, org_id)%'),
  1::bigint, 'report_snapshots has unique (id, org_id)'
);
select throws_ok(
  $q$insert into public.report_snapshots (org_id, legal_entity_id, property_id, report_code, business_date, data) values (
    'd0440000-0000-4000-8000-000000000001', 'd0440000-0000-4000-8000-000000000101',
    'd0440000-0000-4000-8000-000000000201', 'RPT_DAILY_BRIEF', '2026-11-10', '{}'::jsonb
  )$q$,
  'P0001', 'ERR_WRITE_GUARD: report_snapshots chi duoc ghi qua RPC',
  'Direct report_snapshots insert is blocked by write guard'
);
select is(
  (select count(*) from public.permissions where code like 'report.view.%'),
  11::bigint, 'catalog has 11 report.view.* permission codes (10 T-044 + rpt_fnb_revenue, 500000)'
);

-- ---------------------------------------------------------------------------
-- B. RPT_STOCK_CARD (owner).
-- ---------------------------------------------------------------------------
set local role authenticated;
select public._t044_as('d0440000-0000-4000-8000-000000000a05');
insert into t044_resp (key, resp)
select 'stock_card', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_STOCK_CARD',
  '{"from": "2026-11-09", "to": "2026-11-10", "warehouse_id": "d0440000-0000-4000-8000-000000000301"}'::jsonb);

select is(public._t044_rows('stock_card'), 5::bigint, 'stock card has 5 rows');
select is(public._t044_num('stock_card', 'item_code', 'ITM_GAO', 'closing_qty'), 170::numeric, 'GAO closing qty 170');
select is(public._t044_num('stock_card', 'item_code', 'ITM_GAO', 'closing_value'), 1700000::numeric, 'GAO closing value 1.700.000');
select is(public._t044_num('stock_card', 'item_code', 'ITM_THIT', 'closing_qty'), 15::numeric, 'THIT closing qty 15');
select is(public._t044_total('stock_card', 'closing_value'), 2944000::numeric, 'stock card total closing value 2.944.000');

-- ---------------------------------------------------------------------------
-- C. RPT_RECEIVING_QUALITY (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'receiving_quality', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_RECEIVING_QUALITY',
  '{"from": "2026-11-09", "to": "2026-11-10"}'::jsonb);

select is(public._t044_rows('receiving_quality'), 1::bigint, 'receiving quality has 1 supplier row');
select is(public._t044_num('receiving_quality', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'gr_count'), 1::numeric, 'NCC1 has 1 posted GR');
select is(public._t044_num('receiving_quality', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'short_qty'), 10::numeric, 'NCC1 short qty 10');
select is(public._t044_num('receiving_quality', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'short_pct'), 8.33::numeric, 'NCC1 short pct 8.33');
select is(public._t044_num('receiving_quality', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'reweigh_count'), 1::numeric, 'NCC1 reweigh count 1');
select is(public._t044_num('receiving_quality', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'qc_fail_count'), 1::numeric, 'NCC1 QC fail count 1');
select is(public._t044_num('receiving_quality', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'return_count'), 1::numeric, 'NCC1 return count 1');

-- ---------------------------------------------------------------------------
-- D. RPT_OPEN_PO_INVOICE (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'open_po', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_OPEN_PO_INVOICE',
  '{"as_of": "2026-11-10"}'::jsonb);

select is(public._t044_rows('open_po'), 2::bigint, 'open PO has 2 rows');
select is(public._t044_num('open_po', 'doc_no', 'PO-044-001', 'remaining_amount'), 200000::numeric, 'PO1 remaining 200.000');
select is(public._t044_num('open_po', 'doc_no', 'PO-044-001', 'overdue_days'), 2::numeric, 'PO1 overdue 2 days');
select is(public._t044_num('open_po', 'doc_no', 'PO-044-002', 'remaining_amount'), 600000::numeric, 'PO2 remaining 600.000');
select is(public._t044_total('open_po', 'open_po_count'), 2::numeric, 'open PO count 2');
select is(public._t044_total('open_po', 'open_po_remaining_amount'), 700000::numeric, 'open PO remaining total 700.000');
select is(public._t044_total('open_po', 'on_hold_count'), 1::numeric, 'on_hold invoice count 1');
select is(public._t044_total('open_po', 'on_hold_amount'), 1100000::numeric, 'on_hold invoice amount 1.100.000');

-- ---------------------------------------------------------------------------
-- E. RPT_AP_AGING (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'ap_aging', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_AP_AGING',
  '{"as_of": "2026-11-10"}'::jsonb);

select is(public._t044_rows('ap_aging'), 1::bigint, 'AP aging has 1 supplier row');
select is(public._t044_num('ap_aging', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'not_due'), 500000::numeric, 'NCC1 not due 500.000');
select is(public._t044_num('ap_aging', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'overdue_1_30'), 50000::numeric, 'NCC1 overdue 1-30 is 50.000 after FIFO payment');
select is(public._t044_num('ap_aging', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'forecast_14d'), 500000::numeric, 'NCC1 14-day forecast 500.000');
select is(public._t044_num('ap_aging', 'supplier_id', 'd0440000-0000-4000-8000-000000000701', 'total'), 550000::numeric, 'NCC1 AP total 550.000');

-- ---------------------------------------------------------------------------
-- F. RPT_ADVANCES (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'advances', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_ADVANCES',
  '{"as_of": "2026-11-10"}'::jsonb);

select is(public._t044_rows('advances'), 2::bigint, 'advances has 2 rows');
select is(public._t044_total('advances', 'remaining_amount'), 3000000::numeric, 'advances remaining total 3.000.000');
select is(public._t044_total('advances', 'overdue_count'), 1::numeric, 'advances overdue count 1');
select ok(public._t044_num('advances', 'doc_no', 'ADV-044-001', 'overdue_hours') > 0, 'ADV1 overdue_hours > 0');
select is(public._t044_num('advances', 'doc_no', 'ADV-044-002', 'overdue_hours'), 0::numeric, 'ADV2 overdue_hours is 0 (not yet due; null only when due_settle_at is null — greatest(0, ...) in _report_advances)');

-- ---------------------------------------------------------------------------
-- G. RPT_WASTE (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'waste', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_WASTE',
  '{"from": "2026-11-09", "to": "2026-11-10"}'::jsonb);

select is(public._t044_rows('waste'), 2::bigint, 'waste has 2 rows');
select is(public._t044_num('waste', 'reason_code', 'expired', 'value'), 300000::numeric, 'waste expired value 300.000');
select is(public._t044_num('waste', 'reason_code', 'broken', 'value'), 100000::numeric, 'waste broken value 100.000');
select is(public._t044_total('waste', 'total_value'), 400000::numeric, 'waste total value 400.000');
select is(public._t044_total('waste', 'waste_pct_of_received'), 44.44::numeric, 'waste pct of received 44.44');

-- ---------------------------------------------------------------------------
-- H. RPT_OPEX (owner + Q64: cost_controller khong co pms.input).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'opex', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_OPEX',
  '{"month": "2026-11"}'::jsonb);

select is(public._t044_rows('opex'), 2::bigint, 'opex has 2 category rows');
select is(public._t044_num('opex', 'expense_category_code', 'FOOD', 'total_cost'), 2300000::numeric, 'FOOD total cost 2.300.000 (moves 600k + service 1.2M + invoice 500k)');
select is(public._t044_num('opex', 'expense_category_code', 'FOOD', 'cpor'), 23000::numeric, 'FOOD CPOR 23.000');
select is(public._t044_num('opex', 'expense_category_code', 'AMEN', 'total_cost'), 74000::numeric, 'AMEN total cost 74.000');
select is(public._t044_num('opex', 'expense_category_code', 'AMEN', 'cpor'), 740::numeric, 'AMEN CPOR 740');
select is(public._t044_total('opex', 'total_cost'), 2374000::numeric, 'opex total cost 2.374.000');
select is(public._t044_total('opex', 'cpor'), 23740::numeric, 'opex total CPOR 23.740');

select public._t044_as('d0440000-0000-4000-8000-000000000a03');
insert into t044_resp (key, resp)
select 'opex_cc', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_OPEX',
  '{"month": "2026-11"}'::jsonb);
select ok(
  (select resp->>'ok' from t044_resp where key = 'opex_cc') = 'true',
  'Q64: cost_controller without pms.input reads CPOR via report_get'
);
select public._t044_as('d0440000-0000-4000-8000-000000000a05');

-- ---------------------------------------------------------------------------
-- I. RPT_MINIBAR (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'minibar', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_MINIBAR',
  '{"from": "2026-11-09", "to": "2026-11-10"}'::jsonb);

select is(public._t044_rows('minibar'), 1::bigint, 'minibar has 1 item row');
select is(public._t044_num('minibar', 'item_code', 'ITM_LAVIE', 'revenue'), 40000::numeric, 'Lavie revenue 40.000');
select is(public._t044_num('minibar', 'item_code', 'ITM_LAVIE', 'cogs'), 12000::numeric, 'Lavie COGS 12.000');
select is(public._t044_num('minibar', 'item_code', 'ITM_LAVIE', 'gross_profit'), 28000::numeric, 'Lavie gross profit 28.000');
select is(public._t044_total('minibar', 'recorded'), 60000::numeric, 'minibar recorded 60.000');
select is(public._t044_total('minibar', 'charged'), 40000::numeric, 'minibar charged 40.000');
select is(public._t044_total('minibar', 'waived'), 20000::numeric, 'minibar waived 20.000');
select is(public._t044_total('minibar', 'diff'), 0::numeric, 'minibar reconcile diff 0');
select is(public._t044_total('minibar', 'pending_stale'), 30000::numeric, 'minibar pending stale 30.000');
select is(public._t044_total('minibar', 'lavie_units'), 4::numeric, 'Lavie units sold 4');
select is(public._t044_total('minibar', 'dasani_units'), 6::numeric, 'Dasani units issued 6');
select is(public._t044_total('minibar', 'room_nights'), 1::numeric, 'minibar room nights 1');
select is(public._t044_total('minibar', 'lavie_per_roomnight'), 4::numeric, 'Lavie per room night 4');
select is(public._t044_total('minibar', 'dasani_per_roomnight'), 6::numeric, 'Dasani per room night 6');

-- ---------------------------------------------------------------------------
-- J. RPT_AMENITY_CPOR (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'amenity', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_AMENITY_CPOR',
  '{"month": "2026-11"}'::jsonb);

select is(public._t044_rows('amenity'), 1::bigint, 'amenity CPOR has 1 group row');
select is(public._t044_num('amenity', 'group_name', 'Amenities', 'cost'), 50000::numeric, 'amenity cost 50.000');
select is(public._t044_num('amenity', 'group_name', 'Amenities', 'cost_per_roomnight'), 500::numeric, 'amenity cost per room night 500');
select is(public._t044_total('amenity', 'total_cost'), 50000::numeric, 'amenity total cost 50.000');

-- ---------------------------------------------------------------------------
-- K. RPT_DAILY_BRIEF (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'brief', public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_DAILY_BRIEF',
  '{"date": "2026-11-10"}'::jsonb);

select is(public._t044_val('brief', 'purchase_yesterday')::numeric, 900000::numeric, 'brief purchase yesterday 900.000');
select is(public._t044_val('brief', 'waste_yesterday')::numeric, 400000::numeric, 'brief waste yesterday 400.000');
select is(public._t044_val('brief', 'red_alerts_unacked')::numeric, 2::numeric, 'brief red alerts unacked 2');
select is(public._t044_val('brief', 'ap_due_7d')::numeric, 500000::numeric, 'brief AP due 7d 500.000');
select is(((select resp->'advances_overdue'->>'count' from t044_resp where key = 'brief'))::numeric, 1::numeric, 'brief overdue advances count 1');
select is(((select resp->'advances_overdue'->>'amount' from t044_resp where key = 'brief'))::numeric, 2000000::numeric, 'brief overdue advances amount 2.000.000');
select is(public._t044_len('brief', 'red_alerts_24h'), 2::bigint, 'brief red alerts 24h has 2 items');
select is(public._t044_len('brief', 'contracts_expiring'), 1::bigint, 'brief expiring contracts 1');
select is(public._t044_len('brief', 'schedules_unaccepted'), 1::bigint, 'brief unaccepted schedules 1');
select is(
  ((select (resp->'contracts_expiring'->0->>'days_left')::numeric from t044_resp where key = 'brief')),
  10::numeric, 'brief expiring contract days_left 10'
);

-- ---------------------------------------------------------------------------
-- L. report_build_daily + snapshot (owner).
-- ---------------------------------------------------------------------------
insert into t044_resp (key, resp)
select 'built', public.report_build_daily('d0440000-0000-4000-8000-000000000201', '2026-11-10'::date);
select ok(
  (select resp->>'ok' from t044_resp where key = 'built') = 'true',
  'report_build_daily returns ok'
);
select is(
  (select count(*) from public.report_snapshots
   where property_id = 'd0440000-0000-4000-8000-000000000201'
     and report_code = 'RPT_DAILY_BRIEF' and business_date = '2026-11-10'),
  1::bigint, 'daily brief snapshot saved once'
);
select is(
  (select (data->>'purchase_yesterday')::numeric from public.report_snapshots
   where property_id = 'd0440000-0000-4000-8000-000000000201'
     and report_code = 'RPT_DAILY_BRIEF' and business_date = '2026-11-10'),
  900000::numeric, 'snapshot purchase yesterday 900.000'
);
select public.report_build_daily('d0440000-0000-4000-8000-000000000201', '2026-11-10'::date);
select is(
  (select count(*) from public.report_snapshots
   where property_id = 'd0440000-0000-4000-8000-000000000201'
     and report_code = 'RPT_DAILY_BRIEF' and business_date = '2026-11-10'),
  1::bigint, 'report_build_daily is idempotent (upsert, still 1 row)'
);

-- ---------------------------------------------------------------------------
-- M. Tu choi quyen + tham so sai.
-- ---------------------------------------------------------------------------
select public._t044_as('d0440000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_STOCK_CARD', '{}'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:report.view.rpt_stock_card',
  'cost_controller without report.view.rpt_stock_card is forbidden'
);
select public._t044_as('d0440000-0000-4000-8000-000000000a05');
select throws_ok(
  $q$select public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_NOPE', '{}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'unknown report code is rejected'
);
select throws_ok(
  $q$select public.report_get('d0440000-0000-4000-8000-000000000201', 'RPT_STOCK_CARD', '{"from": "2026-11-10", "to": "2026-11-09"}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'from after to is rejected'
);

select * from finish();
rollback;
