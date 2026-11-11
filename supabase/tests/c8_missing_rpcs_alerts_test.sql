-- C8 pgTAP: 3 RPC moi + diem phat canh bao cho 4 ma chet
-- (migration 20261109527000_missing_rpcs_alerts.sql).
-- Kiem tra: RPC ton tai + cot moi, tu choi khi khong du quyen, hanh vi
-- dung khi du quyen (tu choi/huy/dao + doi trang thai), alert phat ra
-- o duong thanh cong (UNLOCK, PERMISSION_CRITICAL_CHANGED), khoi chan
-- dich vu chua nghiem thu van giu (ERR_SERVICE_NOT_ACCEPTED).
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
-- GHI CHU:
--   * require_perm raise 42501 'ERR_FORBIDDEN:<ma.quyen>' (xem
--     141000); cac loi nghiep vu raise P0001.
--   * SERVICE_UNACCEPTED_PAYMENT: KHONG chen alert (quyet dinh fix
--     11/11/2026 — alert chen truoc raise se bi rollback cung
--     transaction nen khong bao gio ton tai duoc; giu la code chet).
--     Suite chi assert khoi chan van raise (ERR_SERVICE_NOT_ACCEPTED,
--     §6) + ham khong chua lenh _create_alert cho ma nay (2 assert
--     NOT LIKE o §0). Muon bao ben vung can co che hang doi alert
--     rieng hoac alert o phia caller (xem Q101).
--   * OVER_CEILING_APPROVED / PRICE_SPIKE: chi kiem tra diem goi qua
--     pg_get_functiondef (luong duyet PO day du / nhan hang day du
--     thuoc suite T-020 / T-023); suite nay khong dung lai toan bo
--     luong do.
--   * Cac SELECT kiem tra trang thai chay sau `reset role` (ve role
--     postgres, bypass RLS — mau bootstrap_initial_org_test.sql),
--     vi policy SELECT cua alerts / audit_log doi quyen
--     alert.receive.* / audit.view_all ma user test khong co.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(67);

-- ---------------------------------------------------------------------------
-- 0. Fixture
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d8c80000-0000-4000-8000-000000000001', 'C8 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000001', 'C8', 'Entity C8');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'PC81', 'Property C8', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d8c80000-0000-4000-8000-000000000401', 'd8c80000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d8c80000-0000-4000-8000-000000000501', 'd8c80000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd8c80000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market'], false);

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('d8c80000-0000-4000-8000-000000000701', 'd8c80000-0000-4000-8000-000000000001', 'NCC1', 'Nhà cung cấp 1', 'company', 'active');

insert into public.outlet_types (id, org_id, code, name) values
  ('d8c80000-0000-4000-8000-000000000801', 'd8c80000-0000-4000-8000-000000000001', 'HK', 'Buồng phòng');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d8c80000-0000-4000-8000-000000000802', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000801', 'HK', 'Buồng phòng');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d8c80000-0000-4000-8000-000000000301', 'd8c80000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d8c80000-0000-4000-8000-000000000302', 'd8c80000-0000-4000-8000-000000000201', 'WH_TROLLEY1', 'Xe đẩy 1', 'trolley', 'd8c80000-0000-4000-8000-000000000802'),
  ('d8c80000-0000-4000-8000-000000000303', 'd8c80000-0000-4000-8000-000000000201', 'WH_FLOOR1', 'Kho tầng 1', 'floor', 'd8c80000-0000-4000-8000-000000000802');

insert into public.cost_centers (id, org_id, code, name) values
  ('d8c80000-0000-4000-8000-000000000901', 'd8c80000-0000-4000-8000-000000000001', 'FB', 'F&B');

insert into public.expense_categories (id, org_id, code, name) values
  ('d8c80000-0000-4000-8000-000000000902', 'd8c80000-0000-4000-8000-000000000001', 'FOOD', 'Thực phẩm');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d8c80000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-gm-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-stk-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u3-hk-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-noperm-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u5-eng-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a06', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u6-eng2-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a07', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u7-adm-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a08', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u8-creator-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d8c80000-0000-4000-8000-000000000a09', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u9-acc-c8@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d8c80000-0000-4000-8000-000000000a01', 'NVC801', 'Tổng quản lý'),
  ('d8c80000-0000-4000-8000-000000000a02', 'NVC802', 'Thủ kho'),
  ('d8c80000-0000-4000-8000-000000000a03', 'NVC803', 'Nhân viên buồng'),
  ('d8c80000-0000-4000-8000-000000000a04', 'NVC804', 'Không quyền'),
  ('d8c80000-0000-4000-8000-000000000a05', 'NVC805', 'Kỹ sư 1'),
  ('d8c80000-0000-4000-8000-000000000a06', 'NVC806', 'Kỹ sư 2'),
  ('d8c80000-0000-4000-8000-000000000a07', 'NVC807', 'Quản trị'),
  ('d8c80000-0000-4000-8000-000000000a08', 'NVC808', 'Người tạo'),
  ('d8c80000-0000-4000-8000-000000000a09', 'NVC809', 'Kế toán')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d8c80000-0000-4000-8000-000000000601', 'd8c80000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d8c80000-0000-4000-8000-000000000602', 'd8c80000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d8c80000-0000-4000-8000-000000000603', 'd8c80000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng'),
  ('d8c80000-0000-4000-8000-000000000604', 'd8c80000-0000-4000-8000-000000000001', 'no_perm', 'Không quyền'),
  ('d8c80000-0000-4000-8000-000000000605', 'd8c80000-0000-4000-8000-000000000001', 'engineer', 'Kỹ sư'),
  ('d8c80000-0000-4000-8000-000000000606', 'd8c80000-0000-4000-8000-000000000001', 'engineer2', 'Kỹ sư 2'),
  ('d8c80000-0000-4000-8000-000000000607', 'd8c80000-0000-4000-8000-000000000001', 'admin', 'Quản trị'),
  ('d8c80000-0000-4000-8000-000000000608', 'd8c80000-0000-4000-8000-000000000001', 'creator', 'Người tạo'),
  ('d8c80000-0000-4000-8000-000000000609', 'd8c80000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d8c80000-0000-4000-8000-000000000610', 'd8c80000-0000-4000-8000-000000000001', 'rtest', 'Vai trò test'),
  ('d8c80000-0000-4000-8000-000000000611', 'd8c80000-0000-4000-8000-000000000001', 'rtest2', 'Vai trò test 2'),
  ('d8c80000-0000-4000-8000-000000000612', 'd8c80000-0000-4000-8000-000000000001', 'rcrit', 'Vai trò critical');

insert into public.role_permissions (role_id, permission_code) values
  ('d8c80000-0000-4000-8000-000000000601', 'count.adjust.approve'),
  ('d8c80000-0000-4000-8000-000000000601', 'day.unlock'),
  ('d8c80000-0000-4000-8000-000000000602', 'count.perform'),
  ('d8c80000-0000-4000-8000-000000000603', 'hk.trolley.operate'),
  ('d8c80000-0000-4000-8000-000000000605', 'service.accept'),
  ('d8c80000-0000-4000-8000-000000000606', 'service.accept'),
  ('d8c80000-0000-4000-8000-000000000607', 'admin.roles.manage'),
  ('d8c80000-0000-4000-8000-000000000607', 'admin.users.manage'),
  ('d8c80000-0000-4000-8000-000000000607', 'admin.permissions.override'),
  ('d8c80000-0000-4000-8000-000000000609', 'invoice.manage'),
  ('d8c80000-0000-4000-8000-000000000609', 'payment.request'),
  ('d8c80000-0000-4000-8000-000000000610', 'item.view'),
  ('d8c80000-0000-4000-8000-000000000612', 'day.unlock');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d8c80000-0000-4000-8000-000000000a01', 'd8c80000-0000-4000-8000-000000000601', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a02', 'd8c80000-0000-4000-8000-000000000602', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a03', 'd8c80000-0000-4000-8000-000000000603', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a04', 'd8c80000-0000-4000-8000-000000000604', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a05', 'd8c80000-0000-4000-8000-000000000605', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a06', 'd8c80000-0000-4000-8000-000000000606', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a07', 'd8c80000-0000-4000-8000-000000000607', null),
  ('d8c80000-0000-4000-8000-000000000a08', 'd8c80000-0000-4000-8000-000000000608', 'd8c80000-0000-4000-8000-000000000201'),
  ('d8c80000-0000-4000-8000-000000000a09', 'd8c80000-0000-4000-8000-000000000609', 'd8c80000-0000-4000-8000-000000000201');

-- Dot kiem da locked + dieu chinh pending (chen truc tiep qua bypass).
select set_config('app.count_guard_bypass', 'on', true);
insert into public.stock_counts (id, org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind, business_date, status, counter_ids, opened_by, locked_by, locked_at, created_by) values
  ('d8c80000-0000-4000-8000-000000000e01', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000301', 'CNT-C8-001', 'monthly_full', '2026-11-09', 'locked', array['d8c80000-0000-4000-8000-000000000a02'::uuid, 'd8c80000-0000-4000-8000-000000000a05'::uuid], 'd8c80000-0000-4000-8000-000000000a02', 'd8c80000-0000-4000-8000-000000000a06', now(), 'd8c80000-0000-4000-8000-000000000a02');
insert into public.count_adjustments (id, count_id, org_id, property_id, status, created_by) values
  ('d8c80000-0000-4000-8000-000000000e02', 'd8c80000-0000-4000-8000-000000000e01', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000201', 'pending', 'd8c80000-0000-4000-8000-000000000a06');
select set_config('app.count_guard_bypass', 'off', true);

-- Ca xe day: 1 mo + 1 da dong (chen truc tiep qua bypass).
select set_config('app.hk_guard_bypass', 'on', true);
insert into public.trolley_shifts (id, org_id, legal_entity_id, property_id, trolley_warehouse_id, attendant_id, business_date, shift, status, created_by) values
  ('d8c80000-0000-4000-8000-000000000e11', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000302', 'd8c80000-0000-4000-8000-000000000a03', '2026-11-10', 'day', 'open', 'd8c80000-0000-4000-8000-000000000a03'),
  ('d8c80000-0000-4000-8000-000000000e12', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000302', 'd8c80000-0000-4000-8000-000000000a03', '2026-11-09', 'day', 'closed', 'd8c80000-0000-4000-8000-000000000a03');
select set_config('app.hk_guard_bypass', 'off', true);

-- Hop dong dich vu + lich (chen truc tiep qua bypass); nghiem thu tao
-- bang RPC service_accept that o muc §3.
select set_config('app.service_guard_bypass', 'on', true);
insert into public.service_contracts (id, org_id, legal_entity_id, property_id, supplier_id, expense_category_id, cost_center_id, title, start_date, billing_cycle, amount_per_cycle, status, created_by) values
  ('d8c80000-0000-4000-8000-000000000e21', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'd8c80000-0000-4000-8000-000000000902', 'd8c80000-0000-4000-8000-000000000901', 'Vệ sinh bể nước', '2026-11-01', 'monthly', 2000000, 'active', 'd8c80000-0000-4000-8000-000000000a08');
insert into public.service_schedules (id, org_id, legal_entity_id, property_id, contract_id, period_start, period_end, due_date, status, created_by) values
  ('d8c80000-0000-4000-8000-000000000e22', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000e21', '2026-10-01', '2026-10-31', '2026-10-31', 'performed', 'd8c80000-0000-4000-8000-000000000a08'),
  ('d8c80000-0000-4000-8000-000000000e24', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000e21', '2026-11-01', '2026-11-30', '2026-11-30', 'performed', 'd8c80000-0000-4000-8000-000000000a08');
select set_config('app.service_guard_bypass', 'off', true);

-- PO dich vu (chen truc tiep qua bypass).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
  ('d8c80000-0000-4000-8000-000000000e31', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-05', '2026-11-10', null, 'approved', 'd8c80000-0000-4000-8000-000000000a08', 'PO-C8-001'),
  ('d8c80000-0000-4000-8000-000000000e32', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-05', '2026-11-10', null, 'approved', 'd8c80000-0000-4000-8000-000000000a08', 'PO-C8-002'),
  ('d8c80000-0000-4000-8000-000000000e33', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-05', '2026-11-10', null, 'approved', 'd8c80000-0000-4000-8000-000000000a08', 'PO-C8-003'),
  ('d8c80000-0000-4000-8000-000000000e34', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-05', '2026-11-10', null, 'approved', 'd8c80000-0000-4000-8000-000000000a08', 'PO-C8-004'),
  ('d8c80000-0000-4000-8000-000000000e35', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'contract', 'service', '2026-11-05', '2026-11-10', null, 'approved', 'd8c80000-0000-4000-8000-000000000a08', 'PO-C8-005');
update public.purchase_orders set service_contract_id = 'd8c80000-0000-4000-8000-000000000e21' where id = 'd8c80000-0000-4000-8000-000000000e33';
insert into public.purchase_order_lines (id, po_id, org_id, item_id, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('d8c80000-0000-4000-8000-000000000e42', 'd8c80000-0000-4000-8000-000000000e32', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000501', 1, 'kg', 1, 2000000, 'manual', 0),
  ('d8c80000-0000-4000-8000-000000000e43', 'd8c80000-0000-4000-8000-000000000e33', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000501', 1, 'kg', 1, 2000000, 'manual', 0),
  ('d8c80000-0000-4000-8000-000000000e44', 'd8c80000-0000-4000-8000-000000000e34', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000501', 1, 'kg', 1, 2000000, 'manual', 0),
  ('d8c80000-0000-4000-8000-000000000e45', 'd8c80000-0000-4000-8000-000000000e35', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000501', 1, 'kg', 1, 2000000, 'manual', 0);
select set_config('app.pr_po_guard_bypass', 'off', true);

-- Hoa don cho muc §3 (chan dao khi da khop) + §6 (chan khi chua
-- nghiem thu). Chen truc tiep qua bypass.
select set_config('app.finance_guard_bypass', 'on', true);
insert into public.supplier_invoices (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date, total, status, created_by) values
  ('d8c80000-0000-4000-8000-000000000e52', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'INV-C8-002', 'AA', '0000002', '2026-11-10', 2000000, 'matched', 'd8c80000-0000-4000-8000-000000000a09'),
  ('d8c80000-0000-4000-8000-000000000e53', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'INV-C8-003', 'AA', '0000003', '2026-11-15', 2000000, 'matched', 'd8c80000-0000-4000-8000-000000000a09'),
  ('d8c80000-0000-4000-8000-000000000e54', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'INV-C8-004', 'AA', '0000004', '2026-11-10', 2000000, 'draft', 'd8c80000-0000-4000-8000-000000000a09'),
  ('d8c80000-0000-4000-8000-000000000e55', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000101', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000701', 'INV-C8-005', 'AA', '0000005', '2026-11-10', 100000, 'approved', 'd8c80000-0000-4000-8000-000000000a09');
insert into public.supplier_invoice_lines (id, invoice_id, org_id, property_id, po_line_id, qty, unit_price, amount) values
  ('d8c80000-0000-4000-8000-000000000e62', 'd8c80000-0000-4000-8000-000000000e52', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000e42', 1, 2000000, 2000000),
  ('d8c80000-0000-4000-8000-000000000e63', 'd8c80000-0000-4000-8000-000000000e53', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000e43', 1, 2000000, 2000000),
  ('d8c80000-0000-4000-8000-000000000e64', 'd8c80000-0000-4000-8000-000000000e54', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000e44', 1, 2000000, 2000000),
  ('d8c80000-0000-4000-8000-000000000e65', 'd8c80000-0000-4000-8000-000000000e55', 'd8c80000-0000-4000-8000-000000000001', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000e45', 1, 100000, 100000);
select set_config('app.finance_guard_bypass', 'off', true);

-- Khoa ngay (chen truc tiep; day_locks khong co write-guard).
insert into public.day_locks (id, property_id, warehouse_id, business_date, locked_by, created_by) values
  ('d8c80000-0000-4000-8000-000000000e71', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000301', '2026-11-09', 'd8c80000-0000-4000-8000-000000000a01', 'd8c80000-0000-4000-8000-000000000a01'),
  ('d8c80000-0000-4000-8000-000000000e72', 'd8c80000-0000-4000-8000-000000000201', 'd8c80000-0000-4000-8000-000000000301', '2026-11-08', 'd8c80000-0000-4000-8000-000000000a01', 'd8c80000-0000-4000-8000-000000000a01');

create temp table c8_ctx (key text primary key, id uuid);
create temp table c8_resp (key text primary key, resp jsonb);

grant all on c8_ctx, c8_resp to authenticated;

create or replace function public._c8_as(p_user uuid)
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

-- ---------------------------------------------------------------------------
-- §0. Ton tai RPC / cot moi / diem phat alert trong source ham
-- ---------------------------------------------------------------------------
select ok(
  to_regprocedure('public.count_adjust_reject(uuid, text)') is not null,
  'count_adjust_reject(uuid, text) exists'
);
select ok(
  to_regprocedure('public.trolley_shift_cancel(uuid, text)') is not null,
  'trolley_shift_cancel(uuid, text) exists'
);
select ok(
  to_regprocedure('public.service_accept_reverse(uuid, text)') is not null,
  'service_accept_reverse(uuid, text) exists'
);
select ok(
  to_regprocedure('public._check_price_spike(uuid, uuid, uuid, numeric, date, text, uuid)') is not null,
  '_check_price_spike helper exists'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'count_adjustments'
     and column_name in ('rejected_by', 'rejected_at', 'reject_reason')),
  3::bigint, 'count_adjustments has rejected_by/rejected_at/reject_reason'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'trolley_shifts'
     and column_name in ('cancel_reason', 'cancelled_by', 'cancelled_at')),
  3::bigint, 'trolley_shifts has cancel_reason/cancelled_by/cancelled_at'
);
select ok(
  pg_get_functiondef('public.day_unlock(uuid, text)'::regprocedure) like '%UNLOCK%',
  'day_unlock emits UNLOCK'
);
select ok(
  pg_get_functiondef('public._decide_approval(uuid, text, uuid, text, text)'::regprocedure) like '%OVER_CEILING_APPROVED%',
  '_decide_approval emits OVER_CEILING_APPROVED'
);
select ok(
  pg_get_functiondef('public.receiving_post(uuid, text)'::regprocedure) like '%_check_price_spike%',
  'receiving_post calls _check_price_spike'
);
select ok(
  pg_get_functiondef('public._check_price_spike(uuid, uuid, uuid, numeric, date, text, uuid)'::regprocedure) like '%PRICE_SPIKE%',
  '_check_price_spike emits PRICE_SPIKE'
);
select ok(
  pg_get_functiondef('public.invoice_match(uuid)'::regprocedure) not like '%SERVICE_UNACCEPTED_PAYMENT%',
  'invoice_match has no dead SERVICE_UNACCEPTED_PAYMENT alert'
);
select ok(
  pg_get_functiondef('public.payment_request_create(uuid, uuid, jsonb, date)'::regprocedure) not like '%SERVICE_UNACCEPTED_PAYMENT%',
  'payment_request_create has no dead SERVICE_UNACCEPTED_PAYMENT alert'
);
select ok(
  pg_get_functiondef('public.admin_role_set_permissions(uuid, text[])'::regprocedure) like '%PERMISSION_CRITICAL_CHANGED%',
  'admin_role_set_permissions emits PERMISSION_CRITICAL_CHANGED'
);
select ok(
  pg_get_functiondef('public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date)'::regprocedure) like '%PERMISSION_CRITICAL_CHANGED%',
  'admin_user_assign_role emits PERMISSION_CRITICAL_CHANGED'
);
select ok(
  pg_get_functiondef('public.admin_permission_override_set(uuid, uuid, text, text, date, text)'::regprocedure) like '%PERMISSION_CRITICAL_CHANGED%',
  'admin_permission_override_set emits PERMISSION_CRITICAL_CHANGED'
);
-- §0: 15 assertions (4 ton tai + 2 cot + 9 diem phat) — cong them 2
-- assert duoi day cho du 17: check 'rejected' co trong check
-- constraint cua count_adjustments + trolley_shifts status co 'cancelled'.
select ok(
  (select pg_get_constraintdef(oid) from pg_constraint
   where conrelid = 'public.count_adjustments'::regclass and contype = 'c'
     and pg_get_constraintdef(oid) like '%pending%') like '%rejected%',
  'count_adjustments status check allows rejected'
);
select ok(
  (select pg_get_constraintdef(oid) from pg_constraint
   where conrelid = 'public.trolley_shifts'::regclass and contype = 'c'
     and pg_get_constraintdef(oid) like '%open%') like '%cancelled%',
  'trolley_shifts status check allows cancelled'
);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- §1. count_adjust_reject
-- ---------------------------------------------------------------------------
select public._c8_as('d8c80000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.count_adjust_reject(
    'd8c80000-0000-4000-8000-000000000e01', 'Chênh lệch chưa rõ nguyên nhân'
  )$q$,
  '42501', 'ERR_FORBIDDEN:count.adjust.approve',
  'storekeeper without count.adjust.approve cannot reject an adjustment'
);

select public._c8_as('d8c80000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_adjust_reject(
    'd8c80000-0000-4000-8000-000000000e01', ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'reject without a reason is refused'
);

insert into c8_resp values ('reject1', public.count_adjust_reject(
  'd8c80000-0000-4000-8000-000000000e01', 'Chênh lệch chưa rõ nguyên nhân'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'reject1'),
  'count_adjust_reject succeeds for gm'
);
select is(
  (select (resp ->> 'status') from c8_resp where key = 'reject1'),
  'submitted', 'reject returns the count to submitted'
);
reset role;
select is(
  (select status from public.stock_counts where id = 'd8c80000-0000-4000-8000-000000000e01'),
  'submitted', 'count row is back to submitted after reject'
);
select is(
  (select status from public.count_adjustments where id = 'd8c80000-0000-4000-8000-000000000e02'),
  'rejected', 'adjustment row is rejected after reject'
);
select is(
  (select rejected_by from public.count_adjustments where id = 'd8c80000-0000-4000-8000-000000000e02'),
  'd8c80000-0000-4000-8000-000000000a01'::uuid, 'adjustment records who rejected it'
);
select is(
  (select reject_reason from public.count_adjustments where id = 'd8c80000-0000-4000-8000-000000000e02'),
  'Chênh lệch chưa rõ nguyên nhân', 'adjustment records the reject reason'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_adjust_reject(
    'd8c80000-0000-4000-8000-000000000e01', 'Từ chối lần nữa'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'second reject on the same count is refused (no longer locked)'
);
select throws_ok(
  $q$select public.count_adjust_reject(
    'd8c80000-0000-4000-8000-000000000fff', 'Không có đợt này'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'reject on a missing count is refused'
);

-- ---------------------------------------------------------------------------
-- §2. trolley_shift_cancel
-- ---------------------------------------------------------------------------
select public._c8_as('d8c80000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.trolley_shift_cancel(
    'd8c80000-0000-4000-8000-000000000e11', 'Mở nhầm xe'
  )$q$,
  '42501', 'ERR_FORBIDDEN:hk.trolley.operate',
  'user without hk.trolley.operate cannot cancel a shift'
);

select public._c8_as('d8c80000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.trolley_shift_cancel(
    'd8c80000-0000-4000-8000-000000000e11', ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'cancel without a reason is refused'
);

insert into c8_resp values ('cancel1', public.trolley_shift_cancel(
  'd8c80000-0000-4000-8000-000000000e11', 'Mở nhầm xe đẩy'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'cancel1'),
  'trolley_shift_cancel succeeds for hk attendant'
);
select is(
  (select (resp ->> 'status') from c8_resp where key = 'cancel1'),
  'cancelled', 'cancel returns status cancelled'
);
reset role;
select is(
  (select status from public.trolley_shifts where id = 'd8c80000-0000-4000-8000-000000000e11'),
  'cancelled', 'shift row is cancelled after cancel'
);
select is(
  (select cancel_reason from public.trolley_shifts where id = 'd8c80000-0000-4000-8000-000000000e11'),
  'Mở nhầm xe đẩy', 'shift records the cancel reason'
);
select is(
  (select cancelled_by from public.trolley_shifts where id = 'd8c80000-0000-4000-8000-000000000e11'),
  'd8c80000-0000-4000-8000-000000000a03'::uuid, 'shift records who cancelled it'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.trolley_shift_cancel(
    'd8c80000-0000-4000-8000-000000000e11', 'Hủy lần nữa'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'second cancel on the same shift is refused'
);
select throws_ok(
  $q$select public.trolley_shift_cancel(
    'd8c80000-0000-4000-8000-000000000e12', 'Hủy ca đã đóng'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'cancel on a closed shift is refused'
);
select throws_ok(
  $q$select public.trolley_shift_cancel(
    'd8c80000-0000-4000-8000-000000000fff', 'Không có ca này'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'cancel on a missing shift is refused'
);

-- ---------------------------------------------------------------------------
-- §3. service_accept_reverse
--    Nghiem thu tao bang RPC that service_accept (ky SC1 + PO1/PO2/SC3).
-- ---------------------------------------------------------------------------
select public._c8_as('d8c80000-0000-4000-8000-000000000a05');
insert into c8_resp values ('acc1', public.service_accept(
  'd8c80000-0000-4000-8000-000000000e22', 5, '[]'::jsonb, null
));
insert into c8_ctx values ('ac1', (select (resp ->> 'id')::uuid from c8_resp where key = 'acc1'));
insert into c8_resp values ('acc2', public.service_accept(
  null, 4, '[]'::jsonb, 'd8c80000-0000-4000-8000-000000000e31'
));
insert into c8_ctx values ('ac2', (select (resp ->> 'id')::uuid from c8_resp where key = 'acc2'));
insert into c8_resp values ('acc4', public.service_accept(
  null, 5, '[]'::jsonb, 'd8c80000-0000-4000-8000-000000000e32'
));
insert into c8_ctx values ('ac4', (select (resp ->> 'id')::uuid from c8_resp where key = 'acc4'));
insert into c8_resp values ('acc5', public.service_accept(
  'd8c80000-0000-4000-8000-000000000e24', 5, '[]'::jsonb, null
));
insert into c8_ctx values ('ac5', (select (resp ->> 'id')::uuid from c8_resp where key = 'acc5'));

select public._c8_as('d8c80000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.service_accept_reverse(
    (select id from c8_ctx where key = 'ac2'), 'Nghiệm thu nhầm'
  )$q$,
  '42501', 'ERR_FORBIDDEN:service.accept',
  'storekeeper without service.accept cannot reverse an acceptance'
);

select public._c8_as('d8c80000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.service_accept_reverse(
    (select id from c8_ctx where key = 'ac2'), ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'reverse without a reason is refused'
);

select public._c8_as('d8c80000-0000-4000-8000-000000000a05');
select throws_ok(
  $q$select public.service_accept_reverse(
    (select id from c8_ctx where key = 'ac1'), 'Tự đảo nghiệm thu của mình'
  )$q$,
  'P0001', 'ERR_SOD_SERVICE_ACCEPTOR',
  'the acceptor cannot reverse their own acceptance without a SoD exception'
);

select public._c8_as('d8c80000-0000-4000-8000-000000000a06');
insert into c8_resp values ('rev1', public.service_accept_reverse(
  (select id from c8_ctx where key = 'ac1'), 'Nghiệm thu nhầm kỳ'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'rev1'),
  'service_accept_reverse succeeds for another engineer'
);
select is(
  (select (resp ->> 'status') from c8_resp where key = 'rev1'),
  'reversed', 'reverse returns status reversed'
);
reset role;
select ok(
  (select not exists (
    select 1 from public.service_acceptances
    where id = (select id from c8_ctx where key = 'ac1')
  )),
  'acceptance row is gone after reverse'
);
select is(
  (select status from public.service_schedules where id = 'd8c80000-0000-4000-8000-000000000e22'),
  'performed', 'schedule is back to performed after reverse'
);
select ok(
  (select exists (
    select 1 from public.audit_log
    where table_name = 'service_acceptances'
      and row_id = (select id::text from c8_ctx where key = 'ac1')
      and action = 'DELETE'
      and (new_data ->> 'event') = 'service_accept_reverse'
  )),
  'reverse writes an audit_log row for the deleted acceptance'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.service_accept_reverse(
    (select id from c8_ctx where key = 'ac1'), 'Đảo lần nữa'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'second reverse on the same acceptance is refused'
);

-- Nghiem thu lai sau khi dao phai chay duoc.
insert into c8_resp values ('reacc1', public.service_accept(
  'd8c80000-0000-4000-8000-000000000e22', 4, '[]'::jsonb, null
));
select is(
  (select (resp ->> 'status') from c8_resp where key = 'reacc1'),
  'accepted', 'schedule can be accepted again after reverse'
);

-- Duong PO le.
insert into c8_resp values ('rev2', public.service_accept_reverse(
  (select id from c8_ctx where key = 'ac2'), 'Nghiệm thu nhầm PO'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'rev2'),
  'service_accept_reverse succeeds for a standalone service PO'
);
reset role;
select ok(
  (select not exists (
    select 1 from public.service_acceptances
    where id = (select id from c8_ctx where key = 'ac2')
  )),
  'PO acceptance row is gone after reverse'
);
set local role authenticated;

-- Chan dao khi PO da co hoa don da khop (INV2 matched -> POL2 -> PO2).
select public._c8_as('d8c80000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.service_accept_reverse(
    (select id from c8_ctx where key = 'ac4'), 'Đảo khi đã có hóa đơn'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'reverse is blocked when a matched invoice already references the PO'
);

-- Chan dao khi ky da co hoa don da khop (INV3 matched, trong ky SC3).
select throws_ok(
  $q$select public.service_accept_reverse(
    (select id from c8_ctx where key = 'ac5'), 'Đảo khi kỳ đã lên hóa đơn'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'reverse is blocked when a matched invoice already references the schedule period'
);

-- ---------------------------------------------------------------------------
-- §4. UNLOCK (day_unlock)
-- ---------------------------------------------------------------------------
select public._c8_as('d8c80000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.day_unlock(
    'd8c80000-0000-4000-8000-000000000e72', 'Mở khóa để sửa'
  )$q$,
  '42501', 'ERR_FORBIDDEN:day.unlock',
  'storekeeper without day.unlock cannot unlock a day'
);

select public._c8_as('d8c80000-0000-4000-8000-000000000a01');
insert into c8_resp values ('unlock1', public.day_unlock(
  'd8c80000-0000-4000-8000-000000000e71', 'Mở khóa để sửa số liệu'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'unlock1'),
  'day_unlock succeeds for gm'
);
reset role;
select ok(
  (select exists (
    select 1 from public.alerts
    where code = 'UNLOCK' and severity = 'red'
      and property_id = 'd8c80000-0000-4000-8000-000000000201'
      and doc_type = 'day_lock'
      and doc_id = 'd8c80000-0000-4000-8000-000000000e71'
  )),
  'day_unlock creates a red UNLOCK alert for the property'
);
select ok(
  (select not exists (
    select 1 from public.day_locks
    where id = 'd8c80000-0000-4000-8000-000000000e71'
  )),
  'day lock row is gone after unlock'
);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- §5. PERMISSION_CRITICAL_CHANGED (3 ham quan tri)
-- ---------------------------------------------------------------------------
select public._c8_as('d8c80000-0000-4000-8000-000000000a07');
insert into c8_resp values ('setp1', public.admin_role_set_permissions(
  'd8c80000-0000-4000-8000-000000000610', array['item.view', 'day.unlock']
));
select is(
  (select (resp ->> 'critical_changed')::boolean from c8_resp where key = 'setp1'),
  true, 'adding a critical permission reports critical_changed=true'
);
reset role;
select ok(
  (select exists (
    select 1 from public.alerts
    where code = 'PERMISSION_CRITICAL_CHANGED' and severity = 'red'
      and property_id is null
      and (payload ->> 'role_id') = 'd8c80000-0000-4000-8000-000000000610'
  )),
  'set_permissions with a critical change creates a red chain-wide alert'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a07');
insert into c8_resp values ('setp2', public.admin_role_set_permissions(
  'd8c80000-0000-4000-8000-000000000611', array['item.view']
));
select is(
  (select (resp ->> 'critical_changed')::boolean from c8_resp where key = 'setp2'),
  false, 'adding only a normal permission reports critical_changed=false'
);
reset role;
select is(
  (select count(*) from public.alerts
   where code = 'PERMISSION_CRITICAL_CHANGED'
     and (payload ->> 'role_id') = 'd8c80000-0000-4000-8000-000000000611'),
  0::bigint, 'no alert for a non-critical permission change'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a07');
insert into c8_resp values ('assign1', public.admin_user_assign_role(
  'd8c80000-0000-4000-8000-000000000a02',
  'd8c80000-0000-4000-8000-000000000612',
  'd8c80000-0000-4000-8000-000000000201'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'assign1'),
  'assigning a role with a critical permission succeeds'
);
reset role;
select ok(
  (select exists (
    select 1 from public.alerts
    where code = 'PERMISSION_CRITICAL_CHANGED'
      and (payload ->> 'role_id') = 'd8c80000-0000-4000-8000-000000000612'
      and (payload ->> 'user_id') = 'd8c80000-0000-4000-8000-000000000a02'
  )),
  'assigning a critical role creates a PERMISSION_CRITICAL_CHANGED alert'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a07');
insert into c8_resp values ('ovr1', public.admin_permission_override_set(
  'd8c80000-0000-4000-8000-000000000a02',
  'd8c80000-0000-4000-8000-000000000201',
  'day.unlock', 'allow', null, 'Cấp riêng để mở khóa ngày'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'ovr1'),
  'overriding a critical permission succeeds'
);
reset role;
select ok(
  (select exists (
    select 1 from public.alerts
    where code = 'PERMISSION_CRITICAL_CHANGED'
      and (payload ->> 'permission_code') = 'day.unlock'
      and (payload ->> 'user_id') = 'd8c80000-0000-4000-8000-000000000a02'
  )),
  'overriding a critical permission creates a PERMISSION_CRITICAL_CHANGED alert'
);
set local role authenticated;

select public._c8_as('d8c80000-0000-4000-8000-000000000a07');
insert into c8_resp values ('ovr2', public.admin_permission_override_set(
  'd8c80000-0000-4000-8000-000000000a04',
  'd8c80000-0000-4000-8000-000000000201',
  'item.view', 'allow', null, 'Cấp riêng để xem vật tư'
));
select ok(
  (select (resp ->> 'ok')::boolean from c8_resp where key = 'ovr2'),
  'overriding a normal permission succeeds'
);
reset role;
select is(
  (select count(*) from public.alerts
   where code = 'PERMISSION_CRITICAL_CHANGED'
     and (payload ->> 'permission_code') = 'item.view'
     and (payload ->> 'user_id') = 'd8c80000-0000-4000-8000-000000000a04'),
  0::bigint, 'no alert for a non-critical permission override'
);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- §6. SERVICE_UNACCEPTED_PAYMENT — khoi chan van giu, KHONG chen alert
--      (quyet dinh fix 11/11/2026: alert truoc raise se bi rollback
--      cung transaction nen khong ton tai duoc — xem GHI CHU dau file).
-- ---------------------------------------------------------------------------
select public._c8_as('d8c80000-0000-4000-8000-000000000a09');
select throws_ok(
  $q$select public.invoice_match(
    'd8c80000-0000-4000-8000-000000000e54'
  )$q$,
  'P0001', 'ERR_SERVICE_NOT_ACCEPTED',
  'invoice_match still blocks a service PO without acceptance'
);
select throws_ok(
  $q$select public.payment_request_create(
    'd8c80000-0000-4000-8000-000000000201',
    'd8c80000-0000-4000-8000-000000000701',
    '[{"invoice_id": "d8c80000-0000-4000-8000-000000000e55", "amount": 50000}]'::jsonb
  )$q$,
  'P0001', 'ERR_SERVICE_NOT_ACCEPTED',
  'payment_request_create still blocks an unaccepted service invoice'
);

select finish();
rollback;
