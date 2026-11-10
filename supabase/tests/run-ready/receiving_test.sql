begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(87);
insert into public.organizations (id, name) values
('d0230000-0000-4000-8000-000000000001', 'T-023 Master Org');
insert into public.legal_entities (id, org_id, code, name) values
('d0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000001', 'T023', 'Entity T-023');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
('d0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'P0231', 'Property T-023', 'with_cc');
insert into public.uoms (code, name_vi) values
('kg', 'Kilôgam'),
('cai', 'Cái')
on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
('d0230000-0000-4000-8000-000000000401', 'd0230000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
('d0230000-0000-4000-8000-000000000402', 'd0230000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
('d0230000-0000-4000-8000-000000000403', 'd0230000-0000-4000-8000-000000000001', 'VP', 'Văn phòng phẩm', 'other');
insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels) values
('d0230000-0000-4000-8000-000000000501', 'd0230000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0230000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market']),
('d0230000-0000-4000-8000-000000000502', 'd0230000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0230000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract']),
('d0230000-0000-4000-8000-000000000503', 'd0230000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0230000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market']),
('d0230000-0000-4000-8000-000000000504', 'd0230000-0000-4000-8000-000000000001', 'ITM_DAU', 'Dầu ăn', 'd0230000-0000-4000-8000-000000000403', 'kg', false, true, 60, array['contract']);
insert into public.item_purchase_units (org_id, item_id, uom, factor_to_stock, is_default) values
('d0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'cai', 10, false);
insert into public.suppliers (id, org_id, code, name, kind, status) values
('d0230000-0000-4000-8000-000000000701', 'd0230000-0000-4000-8000-000000000001', 'NCC_GAO', 'Công ty Gạo Sạch', 'company', 'active');
insert into public.outlet_types (id, org_id, code, name) values
('d0230000-0000-4000-8000-000000000801', 'd0230000-0000-4000-8000-000000000001', 'KIT', 'Bếp');
insert into public.outlets (id, property_id, outlet_type_id, code, name) values
('d0230000-0000-4000-8000-000000000802', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000801', 'KITCHEN', 'Bếp chính');
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
('d0230000-0000-4000-8000-000000000301', 'd0230000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
('d0230000-0000-4000-8000-000000000302', 'd0230000-0000-4000-8000-000000000201', 'WH_QUAR', 'Kho cách ly', 'quarantine', null),
('d0230000-0000-4000-8000-000000000303', 'd0230000-0000-4000-8000-000000000201', 'WH_KIT', 'Kho bếp', 'outlet', 'd0230000-0000-4000-8000-000000000802');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
('d0230000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-pur023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-out023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u3-cc023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-gm023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u5-own023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a06', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u6-rec023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a07', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u7-stk023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a08', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u8-recnopin023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a09', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u9-admin023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0230000-0000-4000-8000-000000000a10', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u10-view023@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
('d0230000-0000-4000-8000-000000000a01', 'NV02301', 'Thu mua'),
('d0230000-0000-4000-8000-000000000a02', 'NV02302', 'Trưởng bếp'),
('d0230000-0000-4000-8000-000000000a03', 'NV02303', 'Cost Controller'),
('d0230000-0000-4000-8000-000000000a04', 'NV02304', 'Tổng quản lý'),
('d0230000-0000-4000-8000-000000000a05', 'NV02305', 'Chủ đầu tư'),
('d0230000-0000-4000-8000-000000000a06', 'NV02306', 'Nhân viên nhận hàng'),
('d0230000-0000-4000-8000-000000000a07', 'NV02307', 'Thủ kho'),
('d0230000-0000-4000-8000-000000000a08', 'NV02308', 'Nhận hàng chưa đặt PIN'),
('d0230000-0000-4000-8000-000000000a09', 'NV02309', 'Quản trị cấu hình'),
('d0230000-0000-4000-8000-000000000a10', 'NV02310', 'Chỉ xem')
on conflict (id) do update set
employee_code = excluded.employee_code,
full_name = excluded.full_name;
update public.profiles
set pin_hash = extensions.crypt('1234', extensions.gen_salt('bf'))
where id = 'd0230000-0000-4000-8000-000000000a06';
update public.profiles
set pin_hash = extensions.crypt('5678', extensions.gen_salt('bf'))
where id = 'd0230000-0000-4000-8000-000000000a07';
insert into public.roles (id, org_id, code, name_vi) values
('d0230000-0000-4000-8000-000000000601', 'd0230000-0000-4000-8000-000000000001', 'purchaser', 'Mua hàng'),
('d0230000-0000-4000-8000-000000000602', 'd0230000-0000-4000-8000-000000000001', 'outlet_head', 'Trưởng bộ phận'),
('d0230000-0000-4000-8000-000000000603', 'd0230000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
('d0230000-0000-4000-8000-000000000604', 'd0230000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
('d0230000-0000-4000-8000-000000000605', 'd0230000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
('d0230000-0000-4000-8000-000000000606', 'd0230000-0000-4000-8000-000000000001', 'receiver', 'Nhận hàng'),
('d0230000-0000-4000-8000-000000000607', 'd0230000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
('d0230000-0000-4000-8000-000000000608', 'd0230000-0000-4000-8000-000000000001', 'r_admin023', 'Quản trị cấu hình'),
('d0230000-0000-4000-8000-000000000609', 'd0230000-0000-4000-8000-000000000001', 'r_view023', 'Chỉ xem');
insert into public.role_permissions (role_id, permission_code) values
('d0230000-0000-4000-8000-000000000601', 'pr.create'),
('d0230000-0000-4000-8000-000000000601', 'po.create'),
('d0230000-0000-4000-8000-000000000601', 'po.view'),
('d0230000-0000-4000-8000-000000000601', 'po.view_qty'),
('d0230000-0000-4000-8000-000000000601', 'po.view_price'),
('d0230000-0000-4000-8000-000000000601', 'po.close'),
('d0230000-0000-4000-8000-000000000602', 'po.approve'),
('d0230000-0000-4000-8000-000000000603', 'po.approve'),
('d0230000-0000-4000-8000-000000000603', 'receiving.review_photos'),
('d0230000-0000-4000-8000-000000000604', 'po.approve'),
('d0230000-0000-4000-8000-000000000604', 'po.approve.over_ceiling'),
('d0230000-0000-4000-8000-000000000604', 'receiving.view'),
('d0230000-0000-4000-8000-000000000604', 'receiving.override_over_po'),
('d0230000-0000-4000-8000-000000000604', 'receiving.reverse'),
('d0230000-0000-4000-8000-000000000605', 'po.approve'),
('d0230000-0000-4000-8000-000000000605', 'po.view'),
('d0230000-0000-4000-8000-000000000605', 'po.view_price'),
('d0230000-0000-4000-8000-000000000605', 'receiving.view'),
('d0230000-0000-4000-8000-000000000605', 'receiving.perform'),
('d0230000-0000-4000-8000-000000000605', 'receiving.post'),
('d0230000-0000-4000-8000-000000000605', 'receiving.override_over_po'),
('d0230000-0000-4000-8000-000000000605', 'receiving.reverse'),
('d0230000-0000-4000-8000-000000000605', 'audit.view_all'),
('d0230000-0000-4000-8000-000000000606', 'receiving.perform'),
('d0230000-0000-4000-8000-000000000606', 'receiving.post'),
('d0230000-0000-4000-8000-000000000606', 'attachment.upload'),
('d0230000-0000-4000-8000-000000000606', 'attachment.view'),
('d0230000-0000-4000-8000-000000000607', 'receiving.perform'),
('d0230000-0000-4000-8000-000000000607', 'receiving.post'),
('d0230000-0000-4000-8000-000000000607', 'receiving.view'),
('d0230000-0000-4000-8000-000000000607', 'receiving.override_over_po'),
('d0230000-0000-4000-8000-000000000607', 'supplier_return.post'),
('d0230000-0000-4000-8000-000000000607', 'stock.view_qty'),
('d0230000-0000-4000-8000-000000000607', 'attachment.upload'),
('d0230000-0000-4000-8000-000000000607', 'attachment.view'),
('d0230000-0000-4000-8000-000000000608', 'admin.settings.manage'),
('d0230000-0000-4000-8000-000000000608', 'receiving.view'),
('d0230000-0000-4000-8000-000000000609', 'receiving.view');
insert into public.user_property_roles (user_id, role_id, property_id) values
('d0230000-0000-4000-8000-000000000a01', 'd0230000-0000-4000-8000-000000000601', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a02', 'd0230000-0000-4000-8000-000000000602', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a03', 'd0230000-0000-4000-8000-000000000603', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a04', 'd0230000-0000-4000-8000-000000000604', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a05', 'd0230000-0000-4000-8000-000000000605', null),
('d0230000-0000-4000-8000-000000000a06', 'd0230000-0000-4000-8000-000000000606', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a07', 'd0230000-0000-4000-8000-000000000607', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a08', 'd0230000-0000-4000-8000-000000000606', 'd0230000-0000-4000-8000-000000000201'),
('d0230000-0000-4000-8000-000000000a09', 'd0230000-0000-4000-8000-000000000608', null),
('d0230000-0000-4000-8000-000000000a10', 'd0230000-0000-4000-8000-000000000609', 'd0230000-0000-4000-8000-000000000201');
select set_config('app.advance_guard_bypass', 'on', true);
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status) values
('d0230000-0000-4000-8000-000000000901', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000a07', 'ADV-023-001', 1000000, 'Đi chợ', 'disbursed');
select set_config('app.advance_guard_bypass', 'off', true);
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
('d0230000-0000-4000-8000-000000000b01', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-001'),
('d0230000-0000-4000-8000-000000000b02', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', null, 'market', 'stock', '2026-11-09', '2026-11-09', 'd0230000-0000-4000-8000-000000000901', 'approved', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-002'),
('d0230000-0000-4000-8000-000000000b03', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'draft', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-003'),
('d0230000-0000-4000-8000-000000000b04', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-004'),
('d0230000-0000-4000-8000-000000000b05', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-005'),
('d0230000-0000-4000-8000-000000000b06', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0230000-0000-4000-8000-000000000a07', 'PO-023-006'),
('d0230000-0000-4000-8000-000000000b07', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-007'),
('d0230000-0000-4000-8000-000000000b08', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000101', 'd0230000-0000-4000-8000-000000000201', 'd0230000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0230000-0000-4000-8000-000000000a01', 'PO-023-008');
insert into public.purchase_order_lines (id, po_id, org_id, item_id, description, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
('d0230000-0000-4000-8000-000000000c01', 'd0230000-0000-4000-8000-000000000b01', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c02', 'd0230000-0000-4000-8000-000000000b01', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000502', 'Thịt ba chỉ', 5, 'kg', 5, 60000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c03', 'd0230000-0000-4000-8000-000000000b01', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000503', 'Muối hạt', 20, 'kg', 20, 5000, 'manual', 0),
('d0230000-0000-4000-8000-000000000c04', 'd0230000-0000-4000-8000-000000000b02', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 8, 'kg', 8, 9000, 'manual', 0),
('d0230000-0000-4000-8000-000000000c05', 'd0230000-0000-4000-8000-000000000b03', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c06', 'd0230000-0000-4000-8000-000000000b04', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c07', 'd0230000-0000-4000-8000-000000000b05', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000502', 'Thịt ba chỉ', 5, 'kg', 5, 60000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c08', 'd0230000-0000-4000-8000-000000000b06', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c09', 'd0230000-0000-4000-8000-000000000b07', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
('d0230000-0000-4000-8000-000000000c10', 'd0230000-0000-4000-8000-000000000b08', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0);
insert into public.approvals (id, org_id, property_id, doc_type, doc_id, step, approver_role_id, required_perm, decision, decided_by, decided_at) values
('d0230000-0000-4000-8000-000000000d01', 'd0230000-0000-4000-8000-000000000001', 'd0230000-0000-4000-8000-000000000201', 'po', 'd0230000-0000-4000-8000-000000000b07', 1, 'd0230000-0000-4000-8000-000000000607', 'po.approve', 'approved', 'd0230000-0000-4000-8000-000000000a07', now());
select set_config('app.pr_po_guard_bypass', 'off', true);
create temp table t023_ctx (key text primary key, id uuid);
create temp table t023_resp (key text primary key, resp jsonb);
grant all on t023_ctx, t023_resp to authenticated;
create or replace function public._t023_as(p_user uuid)
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
select is(
(select relrowsecurity from pg_class where relname = 'goods_receipts'),
true, 'goods_receipts has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'goods_receipt_lines'),
true, 'goods_receipt_lines has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'supplier_returns'),
true, 'supplier_returns has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'supplier_return_lines'),
true, 'supplier_return_lines has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'qc_templates'),
true, 'qc_templates has RLS enabled'
);
select throws_ok(
$q$insert into public.goods_receipt_lines (gr_id, org_id, property_id, item_id, gross_qty, uom, net_qty_stock, qc_status) values (
    'd0230000-0000-4000-8000-000000000e01',
    'd0230000-0000-4000-8000-000000000001',
    'd0230000-0000-4000-8000-000000000201',
    'd0230000-0000-4000-8000-000000000501',
    10, 'kg', 10, 'pass'
  )$q$,
'P0001', 'ERR_WRITE_GUARD: goods_receipt_lines chi duoc ghi qua RPC',
'Direct goods_receipt_lines insert is blocked'
);
select set_config('app.receiving_guard_bypass', 'on', true);
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, warehouse_id, doc_no, receiver_id, status)
values (
'd0230000-0000-4000-8000-000000000e01',
'd0230000-0000-4000-8000-000000000001',
'd0230000-0000-4000-8000-000000000101',
'd0230000-0000-4000-8000-000000000201',
'd0230000-0000-4000-8000-000000000301',
'GRN-GUARD-001', 'd0230000-0000-4000-8000-000000000a06', 'draft'
);
select set_config('app.receiving_guard_bypass', 'off', true);
select throws_ok(
$q$update public.goods_receipts set status = 'posted' where id = 'd0230000-0000-4000-8000-000000000e01'$q$,
'P0001', 'ERR_WRITE_GUARD: goods_receipts chi duoc ghi qua RPC',
'Direct goods_receipts status change is blocked'
);
set local role authenticated;
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select is(
(select count(*) from public.purchase_order_lines),
0::bigint, 'AC: receiver SELECT purchase_order_lines = 0 rows'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a08');
insert into t023_ctx values ('gr8', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b08',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select is(
(select count(*) from public.goods_receipts
where id = (select id from t023_ctx where key = 'gr8')),
0::bigint, 'receiver cannot SELECT another receiver draft receipt'
);
select ok(
(select public.receiving_list_tasks(
'd0230000-0000-4000-8000-000000000201', '2026-11-09'
) -> 'tasks' @> '[{"doc_no": "PO-023-001"}]'::jsonb),
'list_tasks includes sent PO-023-001'
);
select ok(
(select not (public.receiving_list_tasks(
'd0230000-0000-4000-8000-000000000201', '2026-11-09'
) -> 'tasks' @> '[{"doc_no": "PO-023-003"}]'::jsonb)),
'list_tasks excludes draft PO-023-003'
);
select ok(
(select public.receiving_list_tasks(
'd0230000-0000-4000-8000-000000000201', '2026-11-09'
) -> 'tasks' @> '[{"doc_no": "PO-023-002", "supplier_name": "Mua chợ"}]'::jsonb),
'list_tasks includes market approved PO-023-002 (Q20)'
);
select ok(
(select not ((public.receiving_list_tasks(
'd0230000-0000-4000-8000-000000000201', '2026-11-09'
) -> 'tasks' -> 0) ?| array['qty', 'qty_stock', 'unit_price', 'total_amount'])),
'list_tasks leaks no qty or price'
);
select is(
(select jsonb_array_length(public.receiving_get_task(
'd0230000-0000-4000-8000-000000000b01'
) -> 'lines')),
3, 'get_task returns 3 lines for PO-023-001'
);
select ok(
(select not ((public.receiving_get_task(
'd0230000-0000-4000-8000-000000000b01'
) -> 'lines' -> 0) ?| array['qty', 'qty_stock', 'unit_price'])),
'get_task leaks no qty or price'
);
select ok(
(select (public.receiving_get_task(
'd0230000-0000-4000-8000-000000000b01'
) -> 'lines' -> 0 ->> 'photo_required')::boolean),
'get_task: key item GAO requires photo'
);
select ok(
(select not (public.receiving_get_task(
'd0230000-0000-4000-8000-000000000b01'
) -> 'lines' -> 2 ->> 'photo_required')::boolean),
'get_task: non-key other-group MUOI does not require photo'
);
insert into t023_ctx values ('gr1', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b01',
'd0230000-0000-4000-8000-000000000301',
null,
'd0230000-0000-4000-8000-00000000aa01'
)) ->> 'id')::uuid);
select ok(
(select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b01',
'd0230000-0000-4000-8000-000000000301',
null,
'd0230000-0000-4000-8000-00000000aa01'
) ->> 'id')::uuid = (select id from t023_ctx where key = 'gr1')),
'receiving_start is idempotent on client_uuid'
);
select ok(
(select doc_no like 'GRN-%' from public.goods_receipts
where id = (select id from t023_ctx where key = 'gr1')),
'GR doc_no starts with GRN-'
);
select is(
(select count(*) from public.goods_receipts
where id = (select id from t023_ctx where key = 'gr1')),
1::bigint, 'receiver can SELECT own draft receipt'
);
select throws_ok(
$q$select public.receiving_start(
    'd0230000-0000-4000-8000-000000000b03',
    'd0230000-0000-4000-8000-000000000301'
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'receiving_start rejects draft PO'
);
select throws_ok(
$q$select public.receiving_start(
    'd0230000-0000-4000-8000-000000000b01',
    'd0230000-0000-4000-8000-000000000302'
  )$q$,
'P0001', 'ERR_WAREHOUSE_NOT_FOUND',
'receiving_start rejects quarantine warehouse as receiving warehouse'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
insert into t023_ctx values ('att1', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr1-photo1.jpg',
encode(sha256('gr1-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr1')
)) ->> 'id')::uuid);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
  v_att uuid := (select id from t023_ctx where key = 'att1');
begin
  insert into t023_resp values ('rec_gao',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c01',
      p_item_id := 'd0230000-0000-4000-8000-000000000501',
      p_gross := 9.6, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "pass"}'::jsonb,
      p_photo_ids := array[v_att]
    ));
end $$;
select ok(
(select not ((select resp from t023_resp where key = 'rec_gao') ->> 'needs_reweigh')::boolean),
'GAO 9.6kg within tolerance: no reweigh'
);
select is(
(select ((select resp from t023_resp where key = 'rec_gao') ->> 'accepted_qty_stock_capped')::numeric),
9.6::numeric, 'GAO 9.6kg accepted as-is'
);
select throws_ok(
$q$select public.receiving_record_line(
    p_gr_id := (select id from t023_ctx where key = 'gr1'),
    p_po_line_id := 'd0230000-0000-4000-8000-000000000c02',
    p_item_id := 'd0230000-0000-4000-8000-000000000502',
    p_gross := 5, p_tare := 0, p_uom := 'kg',
    p_qc := '{"status": "pass"}'::jsonb,
    p_lot := 'LOT-T1', p_expiry := '2026-12-09'
  )$q$,
'P0001', 'ERR_PHOTO_REQUIRED',
'THIT without photo is rejected'
);
select throws_ok(
$q$select public.receiving_record_line(
    p_gr_id := (select id from t023_ctx where key = 'gr1'),
    p_po_line_id := 'd0230000-0000-4000-8000-000000000c02',
    p_item_id := 'd0230000-0000-4000-8000-000000000502',
    p_gross := 5, p_tare := 0, p_uom := 'kg',
    p_qc := '{"status": "pass"}'::jsonb,
    p_photo_ids := array[(select id from t023_ctx where key = 'att1')]
  )$q$,
'P0001', 'ERR_LOT_REQUIRED',
'track_lot item without lot_no/expiry is rejected'
);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
  v_att uuid := (select id from t023_ctx where key = 'att1');
begin
  insert into t023_resp values ('rec_thit1',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c02',
      p_item_id := 'd0230000-0000-4000-8000-000000000502',
      p_gross := 5.3, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "pass"}'::jsonb,
      p_lot := 'LOT-T1', p_expiry := '2026-12-09',
      p_photo_ids := array[v_att]
    ));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'rec_thit1') ->> 'needs_reweigh')::boolean),
'AC: THIT 6% deviation needs reweigh'
);
select is(
(select ((select resp from t023_resp where key = 'rec_thit1') ->> 'accepted_qty_stock_capped')::numeric),
0::numeric, 'first weighing with deviation accepts nothing yet'
);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
  v_att uuid := (select id from t023_ctx where key = 'att1');
begin
  insert into t023_resp values ('rec_thit2',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c02',
      p_item_id := 'd0230000-0000-4000-8000-000000000502',
      p_gross := 4.7, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "pass"}'::jsonb,
      p_lot := 'LOT-T1', p_expiry := '2026-12-09',
      p_photo_ids := array[v_att]
    ));
end $$;
select is(
(select ((select resp from t023_resp where key = 'rec_thit2') ->> 'weigh_count')::int),
2, 'second weighing stored as weigh_count 2'
);
select is(
(select ((select resp from t023_resp where key = 'rec_thit2') ->> 'accepted_qty_stock_capped')::numeric),
4.7::numeric, 'reweigh accepts actual 4.7kg'
);
select is(
(select weigh1_gross_qty from public.goods_receipt_lines
where gr_id = (select id from t023_ctx where key = 'gr1')
and po_line_id = 'd0230000-0000-4000-8000-000000000c02'),
5.3::numeric, 'first weighing 5.3kg is kept in weigh1'
);
select throws_ok(
$q$select public.receiving_record_line(
    p_gr_id := (select id from t023_ctx where key = 'gr1'),
    p_po_line_id := 'd0230000-0000-4000-8000-000000000c02',
    p_item_id := 'd0230000-0000-4000-8000-000000000502',
    p_gross := 4.8, p_tare := 0, p_uom := 'kg',
    p_qc := '{"status": "pass"}'::jsonb,
    p_lot := 'LOT-T1', p_expiry := '2026-12-09',
    p_photo_ids := array[(select id from t023_ctx where key = 'att1')]
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'third weighing of the same line is rejected'
);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
begin
  insert into t023_resp values ('rec_muoi1',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c03',
      p_item_id := 'd0230000-0000-4000-8000-000000000503',
      p_gross := 22, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "pass"}'::jsonb
    ));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'rec_muoi1') ->> 'needs_reweigh')::boolean),
'MUOI 10% over needs reweigh'
);
select is(
(select ((select resp from t023_resp where key = 'rec_muoi1') ->> 'accepted_qty_stock_capped')::numeric),
0::numeric, 'MUOI first weighing accepts nothing'
);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
begin
  insert into t023_resp values ('rec_muoi2',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c03',
      p_item_id := 'd0230000-0000-4000-8000-000000000503',
      p_gross := 22, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "pass"}'::jsonb
    ));
end $$;
select is(
(select ((select resp from t023_resp where key = 'rec_muoi2') ->> 'accepted_qty_stock_capped')::numeric),
21::numeric, 'MUOI reweigh capped at remaining x (1 + tolerance) = 21'
);
select is(
(select over_po_qty_stock from public.goods_receipt_lines
where gr_id = (select id from t023_ctx where key = 'gr1')
and po_line_id = 'd0230000-0000-4000-8000-000000000c03'),
1::numeric, 'MUOI excess 1kg recorded as over_po'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select throws_ok(
$q$select public.receiving_override_line(
    (select id from public.goods_receipt_lines
     where gr_id = (select id from t023_ctx where key = 'gr1')
       and po_line_id = 'd0230000-0000-4000-8000-000000000c03'),
    ''
  )$q$,
'P0001', 'ERR_REASON_REQUIRED',
'override without reason is rejected'
);
select ok(
(select (public.receiving_override_line(
(select id from public.goods_receipt_lines
where gr_id = (select id from t023_ctx where key = 'gr1')
and po_line_id = 'd0230000-0000-4000-8000-000000000c03'),
'NCC giao thừa theo thùng, đã kiểm đếm'
) ->> 'ok')::boolean),
'storekeeper overrides over-PO line with reason'
);
select is(
(select accepted_qty_stock from public.goods_receipt_lines
where gr_id = (select id from t023_ctx where key = 'gr1')
and po_line_id = 'd0230000-0000-4000-8000-000000000c03'),
22::numeric, 'override accepts full 22kg'
);
select is(
(select over_po_qty_stock from public.goods_receipt_lines
where gr_id = (select id from t023_ctx where key = 'gr1')
and po_line_id = 'd0230000-0000-4000-8000-000000000c03'),
0::numeric, 'override clears over_po'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
insert into t023_ctx values ('gr4', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b04',
'd0230000-0000-4000-8000-000000000301',
'd0230000-0000-4000-8000-000000000303'
)) ->> 'id')::uuid);
insert into t023_ctx values ('att4', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr4-photo1.jpg',
encode(sha256('gr4-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr4')
)) ->> 'id')::uuid);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr4');
  v_att uuid := (select id from t023_ctx where key = 'att4');
begin
  insert into t023_resp values ('rec_cai',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c06',
      p_item_id := 'd0230000-0000-4000-8000-000000000501',
      p_gross := 1, p_tare := 0, p_uom := 'cai',
      p_qc := '{"status": "pass"}'::jsonb,
      p_photo_ids := array[v_att],
      p_client_uuid := 'd0230000-0000-4000-8000-00000000bb01'
    ));
end $$;
select is(
(select net_qty_stock from public.goods_receipt_lines
where gr_id = (select id from t023_ctx where key = 'gr4')),
10::numeric, '1 cai GAO converts to 10kg stock'
);
select is(
(select ((select resp from t023_resp where key = 'rec_cai') ->> 'accepted_qty_stock_capped')::numeric),
10::numeric, 'converted qty accepted in full'
);
select ok(
(select (public.receiving_record_line(
p_gr_id := (select id from t023_ctx where key = 'gr4'),
p_po_line_id := 'd0230000-0000-4000-8000-000000000c06',
p_item_id := 'd0230000-0000-4000-8000-000000000501',
p_gross := 1, p_tare := 0, p_uom := 'cai',
p_qc := '{"status": "pass"}'::jsonb,
p_photo_ids := array[(select id from t023_ctx where key = 'att4')],
p_client_uuid := 'd0230000-0000-4000-8000-00000000bb01'
) ->> 'id')::uuid = ((select resp from t023_resp where key = 'rec_cai') ->> 'id')::uuid),
'record_line replay with same client_uuid returns the same line'
);
insert into t023_ctx values ('gr5', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b05',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t023_ctx values ('att5', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr5-photo1.jpg',
encode(sha256('gr5-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr5')
)) ->> 'id')::uuid);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr5');
  v_att uuid := (select id from t023_ctx where key = 'att5');
begin
  insert into t023_resp values ('rec_cond',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c07',
      p_item_id := 'd0230000-0000-4000-8000-000000000502',
      p_gross := 5, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "conditional", "reason": "Bao bì rách nhẹ"}'::jsonb,
      p_lot := 'LOT-T2', p_expiry := '2026-11-14',
      p_photo_ids := array[v_att]
    ));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'rec_cond') ->> 'short_shelf_life_warning')::boolean),
'expiry within 50% of shelf life raises short_shelf_life_warning'
);
select is(
(select ((select resp from t023_resp where key = 'rec_cond') ->> 'accepted_qty_stock_capped')::numeric),
5::numeric, 'conditional line still accepted at 5kg (goes to quarantine at post)'
);
insert into t023_ctx values ('gr7', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b02',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t023_ctx values ('att7', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr7-photo1.jpg',
encode(sha256('gr7-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr7')
)) ->> 'id')::uuid);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr7');
  v_att uuid := (select id from t023_ctx where key = 'att7');
begin
  insert into t023_resp values ('rec_fail',
    public.receiving_record_line(
      p_gr_id := v_gr,
      p_po_line_id := 'd0230000-0000-4000-8000-000000000c04',
      p_item_id := 'd0230000-0000-4000-8000-000000000501',
      p_gross := 2, p_tare := 0, p_uom := 'kg',
      p_qc := '{"status": "fail", "reason": "Gạo ẩm mốc"}'::jsonb,
      p_photo_ids := array[v_att]
    ));
end $$;
select is(
(select ((select resp from t023_resp where key = 'rec_fail') ->> 'accepted_qty_stock_capped')::numeric),
0::numeric, 'QC fail accepts 0'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select is(
(select count(*) from public.supplier_returns
where gr_id = (select id from t023_ctx where key = 'gr7')
and status = 'recorded'),
1::bigint, 'QC fail creates a recorded supplier return'
);
select is(
(select qty_stock from public.supplier_return_lines srl
join public.supplier_returns sr on sr.id = srl.return_id
where sr.gr_id = (select id from t023_ctx where key = 'gr7')),
2::numeric, 'return line holds the rejected 2kg'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select throws_ok(
$q$select public.receiving_record_line(
    p_gr_id := (select id from t023_ctx where key = 'gr7'),
    p_po_line_id := 'd0230000-0000-4000-8000-000000000c04',
    p_item_id := 'd0230000-0000-4000-8000-000000000501',
    p_gross := 2, p_tare := 0, p_uom := 'kg',
    p_qc := '{"status": "pass"}'::jsonb,
    p_photo_ids := array[(select id from t023_ctx where key = 'att7')]
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'reweigh after QC fail is rejected (fail is final for the line)'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select throws_ok(
$q$select public.receiving_post(
    (select id from t023_ctx where key = 'gr1'), '9999'
  )$q$,
'P0001', 'ERR_PIN_INVALID',
'wrong PIN cannot post'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a08');
select throws_ok(
$q$select public.receiving_post(
    (select id from t023_ctx where key = 'gr8'), '1234'
  )$q$,
'P0001', 'ERR_PIN_INVALID',
'user without PIN cannot post'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
insert into t023_ctx values ('gr6', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b06',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t023_ctx values ('att6', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr6-photo1.jpg',
encode(sha256('gr6-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr6')
)) ->> 'id')::uuid);
select public.receiving_record_line(
p_gr_id := (select id from t023_ctx where key = 'gr6'),
p_po_line_id := 'd0230000-0000-4000-8000-000000000c08',
p_item_id := 'd0230000-0000-4000-8000-000000000501',
p_gross := 10, p_tare := 0, p_uom := 'kg',
p_qc := '{"status": "pass"}'::jsonb,
p_photo_ids := array[(select id from t023_ctx where key = 'att6')]
);
select throws_ok(
$q$select public.receiving_post(
    (select id from t023_ctx where key = 'gr6'), '5678'
  )$q$,
'P0001', 'ERR_SOD_PO_RECEIVER',
'PO creator cannot receive the PO'
);
insert into t023_ctx values ('gr7b', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b07',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t023_ctx values ('att7b', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr7b-photo1.jpg',
encode(sha256('gr7b-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr7b')
)) ->> 'id')::uuid);
select public.receiving_record_line(
p_gr_id := (select id from t023_ctx where key = 'gr7b'),
p_po_line_id := 'd0230000-0000-4000-8000-000000000c09',
p_item_id := 'd0230000-0000-4000-8000-000000000501',
p_gross := 10, p_tare := 0, p_uom := 'kg',
p_qc := '{"status": "pass"}'::jsonb,
p_photo_ids := array[(select id from t023_ctx where key = 'att7b')]
);
select throws_ok(
$q$select public.receiving_post(
    (select id from t023_ctx where key = 'gr7b'), '5678'
  )$q$,
'P0001', 'ERR_SOD_PO_RECEIVER',
'PO approver cannot receive the PO'
);
insert into t023_ctx values ('gr2b', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b02',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t023_ctx values ('att2b', (select (public.attachment_register(
'd0230000-0000-4000-8000-000000000201',
'evidence',
'd0230000-0000-4000-8000-000000000101/receiving/gr2b-photo1.jpg',
encode(sha256('gr2b-photo1'::bytea), 'hex'),
'receiving',
(select id from t023_ctx where key = 'gr2b')
)) ->> 'id')::uuid);
select public.receiving_record_line(
p_gr_id := (select id from t023_ctx where key = 'gr2b'),
p_po_line_id := 'd0230000-0000-4000-8000-000000000c04',
p_item_id := 'd0230000-0000-4000-8000-000000000501',
p_gross := 5, p_tare := 0, p_uom := 'kg',
p_qc := '{"status": "pass"}'::jsonb,
p_photo_ids := array[(select id from t023_ctx where key = 'att2b')]
);
select throws_ok(
$q$select public.receiving_post(
    (select id from t023_ctx where key = 'gr2b'), '5678'
  )$q$,
'P0001', 'ERR_SOD_MARKET_BUYER_RECEIVER',
'market advance holder cannot receive the market PO'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
insert into t023_ctx values ('gr_empty', (select (public.receiving_start(
'd0230000-0000-4000-8000-000000000b02',
'd0230000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
select throws_ok(
$q$select public.receiving_post(
    (select id from t023_ctx where key = 'gr_empty'), '1234'
  )$q$,
'P0001', 'ERR_PHOTO_REQUIRED',
'receipt without any photo cannot post'
);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
begin
  insert into t023_resp values ('post_gr1',
    public.receiving_post(v_gr, '1234'));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'post_gr1') ->> 'ok')::boolean),
'receiving_post succeeds for gr1'
);
select is(
(select ((select resp from t023_resp where key = 'post_gr1') ->> 'lines_posted')::int),
3, 'gr1 posts 3 lines'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select is(
(select qty from public.stock_balances
where warehouse_id = 'd0230000-0000-4000-8000-000000000301'
and item_id = 'd0230000-0000-4000-8000-000000000501'
and lot_id is null),
9.6::numeric, 'MAIN GAO balance is 9.6 after post'
);
select is(
(select qty from public.stock_balances
where warehouse_id = 'd0230000-0000-4000-8000-000000000301'
and item_id = 'd0230000-0000-4000-8000-000000000502'),
4.7::numeric, 'MAIN THIT balance is 4.7 after post'
);
select is(
(select qty from public.stock_balances
where warehouse_id = 'd0230000-0000-4000-8000-000000000301'
and item_id = 'd0230000-0000-4000-8000-000000000503'
and lot_id is null),
22::numeric, 'MAIN MUOI balance is 22 after post (override)'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a05');
select is(
(select status from public.purchase_orders
where id = 'd0230000-0000-4000-8000-000000000b01'),
'partially_received', 'PO1 is partially_received after post'
);
select is(
(select received_qty_stock from public.purchase_order_lines
where id = 'd0230000-0000-4000-8000-000000000c01'),
9.6::numeric, 'PO line GAO received_qty_stock is 9.6'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select throws_ok(
$q$select public.receiving_get_receipt(
    (select id from t023_ctx where key = 'gr1')
  )$q$,
'P0001', 'ERR_FORBIDDEN:receiving.view',
'receiver cannot view a posted receipt'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select ok(
(select (public.receiving_get_receipt(
(select id from t023_ctx where key = 'gr1')
) ->> 'total_amount') is null),
'storekeeper sees no total_amount (no po.view_price)'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a05');
select is(
(select (public.receiving_get_receipt(
(select id from t023_ctx where key = 'gr1')
) ->> 'total_amount')::numeric),
488000::numeric, 'owner sees total_amount 488000'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr4');
begin
  insert into t023_resp values ('post_gr4',
    public.receiving_post(v_gr, '1234'));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'post_gr4') ->> 'ok')::boolean),
'direct-issue receipt posts'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select is(
(select count(*) from public.stock_moves
where source_doc_type = 'goods_receipt'
and source_doc_id = (select id from t023_ctx where key = 'gr4')),
3::bigint, 'direct issue creates 3 moves'
);
select is(
(select qty from public.stock_balances
where warehouse_id = 'd0230000-0000-4000-8000-000000000303'
and item_id = 'd0230000-0000-4000-8000-000000000501'
and lot_id is null),
10::numeric, 'kitchen warehouse GAO balance is 10 after direct issue'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr5');
begin
  insert into t023_resp values ('post_gr5',
    public.receiving_post(v_gr, '1234'));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'post_gr5') ->> 'ok')::boolean),
'conditional receipt posts'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select is(
(select qty from public.stock_balances
where warehouse_id = 'd0230000-0000-4000-8000-000000000302'
and item_id = 'd0230000-0000-4000-8000-000000000502'),
5::numeric, 'conditional THIT goes to quarantine warehouse'
);
do $$
declare
  v_gr uuid := (select id from t023_ctx where key = 'gr1');
  v_line uuid := (select id from public.goods_receipt_lines
    where gr_id = v_gr
      and po_line_id = 'd0230000-0000-4000-8000-000000000c03');
begin
  insert into t023_resp values ('ret_muoi',
    public.supplier_return_post(
      v_gr,
      jsonb_build_array(jsonb_build_object(
        'gr_line_id', v_line,
        'qty_stock', 2,
        'reason', 'Muối vón cục'
      ))
    ));
end $$;
select ok(
(select ((select resp from t023_resp where key = 'ret_muoi') ->> 'ok')::boolean),
'supplier_return_post succeeds'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a05');
select is(
(select received_qty_stock from public.purchase_order_lines
where id = 'd0230000-0000-4000-8000-000000000c03'),
20::numeric, 'MUOI received_qty_stock drops to 20 after return'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select is(
(select count(*) from public.stock_moves
where source_doc_type = 'supplier_return' and qty = -2 and unit_cost = 5000),
1::bigint, 'return_out move at original cost 5000'
);
select throws_ok(
$q$select public.supplier_return_post(
    (select id from t023_ctx where key = 'gr1'),
    jsonb_build_array(jsonb_build_object(
      'gr_line_id', (select id from public.goods_receipt_lines
        where gr_id = (select id from t023_ctx where key = 'gr1')
          and po_line_id = 'd0230000-0000-4000-8000-000000000c03'),
      'qty_stock', 21,
      'reason', 'Trả quá số đã nhận'
    ))
  )$q$,
'P0001', 'ERR_INVALID_VALUE',
'return above returnable qty is rejected'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a04');
select throws_ok(
$q$select public.receiving_reverse(
    (select id from t023_ctx where key = 'gr1'), 'Sai số lượng'
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'reverse is blocked when a posted supplier return exists'
);
select ok(
(select (public.receiving_reverse(
(select id from t023_ctx where key = 'gr5'), 'Kiểm đếm sai'
) ->> 'ok')::boolean),
'gm reverses gr5'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a07');
select is(
(select qty from public.stock_balances
where warehouse_id = 'd0230000-0000-4000-8000-000000000302'
and item_id = 'd0230000-0000-4000-8000-000000000502'),
0::numeric, 'quarantine THIT balance back to 0 after reverse'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a05');
select is(
(select status from public.purchase_orders
where id = 'd0230000-0000-4000-8000-000000000b05'),
'sent', 'PO5 status back to sent after reverse'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a04');
select throws_ok(
$q$select public.receiving_reverse(
    (select id from t023_ctx where key = 'gr5'), 'Đảo lần hai'
  )$q$,
'P0001', 'ERR_ALREADY_REVERSED',
'second reverse is rejected'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a10');
select ok(
(select exists (
select 1 from jsonb_array_elements(
public.receiving_list_receipts(
'd0230000-0000-4000-8000-000000000201'
) -> 'receipts'
) v where v ->> 'id' = (select id::text from t023_ctx where key = 'gr1')
)),
'list_receipts contains gr1 for viewer'
);
select ok(
(select not ((public.receiving_list_receipts(
'd0230000-0000-4000-8000-000000000201'
) -> 'receipts' -> 0) ? 'total_amount')),
'list_receipts leaks no total_amount'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select throws_ok(
$q$select public.receiving_list_receipts(
    'd0230000-0000-4000-8000-000000000201'
  )$q$,
'P0001', 'ERR_FORBIDDEN:receiving.view',
'receiver cannot list receipts'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a09');
select ok(
(select (public.admin_qc_template_save(
'd0230000-0000-4000-8000-000000000001',
'd0230000-0000-4000-8000-000000000401',
'[{"q": "Màu sắc"}, {"q": "Mùi"}]'::jsonb
) ->> 'ok')::boolean),
'admin saves QC template for GAO group'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select ok(
(select (public.receiving_get_task(
'd0230000-0000-4000-8000-000000000b01'
) -> 'lines' -> 0 -> 'qc_template') is not null),
'get_task returns the QC template for GAO'
);
select throws_ok(
$q$select public.admin_qc_template_save(
    'd0230000-0000-4000-8000-000000000001',
    'd0230000-0000-4000-8000-000000000401',
    '[{"q": "Khác"}]'::jsonb
  )$q$,
'42501', 'ERR_FORBIDDEN:admin.settings.manage',
'receiver cannot save QC template'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a09');
select ok(
(select (public.admin_qc_template_delete(
(select id from public.qc_templates
where item_group_id = 'd0230000-0000-4000-8000-000000000401')
) ->> 'ok')::boolean),
'admin deletes QC template'
);
select public._t023_as('d0230000-0000-4000-8000-000000000a06');
select ok(
(select (public.receiving_get_task(
'd0230000-0000-4000-8000-000000000b01'
) -> 'lines' -> 0 ->> 'qc_template') is null),
'get_task returns null QC template after delete'
);
select * from finish();
rollback;
