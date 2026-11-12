-- T-032 pgTAP: kiem ke thang mu, dieu chinh, khoa ngay/ky, view v_count_sheet.
-- Ton kho dau: MAIN GAO 100kg @10000, THIT 20kg @60000 (lo), MUOI 50kg @5000,
-- RUUOU 7000ml @20/ml; KIT GAO 10kg @10000, MUOI 10kg @5000.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(103);

insert into public.organizations (id, name) values
  ('d0320000-0000-4000-8000-000000000001', 'T-032 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000001', 'T032', 'Entity T-032');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'P0321', 'Property T-032', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái'),
  ('ml', 'Mililít')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0320000-0000-4000-8000-000000000401', 'd0320000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d0320000-0000-4000-8000-000000000402', 'd0320000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
  ('d0320000-0000-4000-8000-000000000403', 'd0320000-0000-4000-8000-000000000001', 'MUOI', 'Muối', 'other'),
  ('d0320000-0000-4000-8000-000000000404', 'd0320000-0000-4000-8000-000000000001', 'RUUOU', 'Rượu', 'beverage');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, tare_g, density_g_ml) values
  ('d0320000-0000-4000-8000-000000000501', 'd0320000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0320000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market'], null, null),
  ('d0320000-0000-4000-8000-000000000502', 'd0320000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0320000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract'], null, null),
  ('d0320000-0000-4000-8000-000000000503', 'd0320000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0320000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market'], null, null),
  ('d0320000-0000-4000-8000-000000000504', 'd0320000-0000-4000-8000-000000000001', 'ITM_RUUOU', 'Rượu gạo', 'd0320000-0000-4000-8000-000000000404', 'ml', false, false, null, array['contract'], 450, 0.95);

insert into public.item_purchase_units (org_id, item_id, uom, factor_to_stock, is_default) values
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000501', 'cai', 10, false);

insert into public.outlet_types (id, org_id, code, name) values
  ('d0320000-0000-4000-8000-000000000801', 'd0320000-0000-4000-8000-000000000001', 'KIT', 'Bếp');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0320000-0000-4000-8000-000000000802', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000801', 'KITCHEN', 'Bếp chính');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0320000-0000-4000-8000-000000000302', 'd0320000-0000-4000-8000-000000000201', 'WH_KIT', 'Kho bếp', 'outlet', 'd0320000-0000-4000-8000-000000000802');

insert into public.cost_centers (id, org_id, code, name) values
  ('d0320000-0000-4000-8000-000000000901', 'd0320000-0000-4000-8000-000000000001', 'FB', 'F&B');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0320000-0000-4000-8000-000000000902', 'd0320000-0000-4000-8000-000000000001', 'FOOD', 'Thực phẩm');

insert into public.lots (id, org_id, property_id, item_id, lot_no, expiry_date) values
  ('d0320000-0000-4000-8000-000000000903', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000502', 'LOT-THIT-001', '2027-01-01');

-- auth.users phai dung truoc stock_moves: stock_moves.posted_by co FK toi auth.users.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0320000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-stk032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-chef032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-cc032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-gm032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u5-own032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-acc032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-chief032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a08', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u8-rec032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0320000-0000-4000-8000-000000000a09', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u9-cc2032@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.stock_moves (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id) values
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000501', null, 'receipt', 100, 10000, 1000000, '2026-11-09', 'd0320000-0000-4000-8000-000000000a07', 'opening', 'd0320000-0000-4000-8000-000000000f01'),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000502', 'd0320000-0000-4000-8000-000000000903', 'receipt', 20, 60000, 1200000, '2026-11-09', 'd0320000-0000-4000-8000-000000000a07', 'opening', 'd0320000-0000-4000-8000-000000000f01'),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000503', null, 'receipt', 50, 5000, 250000, '2026-11-09', 'd0320000-0000-4000-8000-000000000a07', 'opening', 'd0320000-0000-4000-8000-000000000f01'),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000504', null, 'receipt', 7000, 20, 140000, '2026-11-09', 'd0320000-0000-4000-8000-000000000a07', 'opening', 'd0320000-0000-4000-8000-000000000f01'),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000302', 'd0320000-0000-4000-8000-000000000501', null, 'receipt', 10, 10000, 100000, '2026-11-09', 'd0320000-0000-4000-8000-000000000a07', 'opening', 'd0320000-0000-4000-8000-000000000f01'),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000302', 'd0320000-0000-4000-8000-000000000503', null, 'receipt', 10, 5000, 50000, '2026-11-09', 'd0320000-0000-4000-8000-000000000a07', 'opening', 'd0320000-0000-4000-8000-000000000f01');

insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000501', null, 100),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000502', 'd0320000-0000-4000-8000-000000000903', 20),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000503', null, 50),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000301', 'd0320000-0000-4000-8000-000000000504', null, 7000),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000302', 'd0320000-0000-4000-8000-000000000501', null, 10),
  ('d0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000302', 'd0320000-0000-4000-8000-000000000503', null, 10);

insert into public.item_costs (legal_entity_id, org_id, item_id, avg_cost, qty_on_hand) values
  ('d0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000501', 10000, 110),
  ('d0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000502', 60000, 20),
  ('d0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000503', 5000, 60),
  ('d0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000504', 20, 7000);

insert into public.profiles (id, employee_code, full_name) values
  ('d0320000-0000-4000-8000-000000000a01', 'NV03201', 'Thủ kho'),
  ('d0320000-0000-4000-8000-000000000a02', 'NV03202', 'Bếp trưởng'),
  ('d0320000-0000-4000-8000-000000000a03', 'NV03203', 'Cost Controller'),
  ('d0320000-0000-4000-8000-000000000a04', 'NV03204', 'Tổng quản lý'),
  ('d0320000-0000-4000-8000-000000000a05', 'NV03205', 'Chủ đầu tư'),
  ('d0320000-0000-4000-8000-000000000a06', 'NV03206', 'Kế toán'),
  ('d0320000-0000-4000-8000-000000000a07', 'NV03207', 'Kế toán trưởng'),
  ('d0320000-0000-4000-8000-000000000a08', 'NV03208', 'Nhận hàng 2'),
  ('d0320000-0000-4000-8000-000000000a09', 'NV03209', 'Cost Controller kiêm đếm')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

update public.profiles
set pin_hash = extensions.crypt('1111', extensions.gen_salt('bf'))
where id = 'd0320000-0000-4000-8000-000000000a01';

update public.profiles
set pin_hash = extensions.crypt('2222', extensions.gen_salt('bf'))
where id = 'd0320000-0000-4000-8000-000000000a02';

update public.profiles
set pin_hash = extensions.crypt('8888', extensions.gen_salt('bf'))
where id = 'd0320000-0000-4000-8000-000000000a08';

update public.profiles
set pin_hash = extensions.crypt('9999', extensions.gen_salt('bf'))
where id = 'd0320000-0000-4000-8000-000000000a09';

insert into public.roles (id, org_id, code, name_vi) values
  ('d0320000-0000-4000-8000-000000000601', 'd0320000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0320000-0000-4000-8000-000000000602', 'd0320000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('d0320000-0000-4000-8000-000000000603', 'd0320000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('d0320000-0000-4000-8000-000000000604', 'd0320000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0320000-0000-4000-8000-000000000605', 'd0320000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0320000-0000-4000-8000-000000000606', 'd0320000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d0320000-0000-4000-8000-000000000607', 'd0320000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('d0320000-0000-4000-8000-000000000608', 'd0320000-0000-4000-8000-000000000001', 'receiver2', 'Nhận hàng 2'),
  ('d0320000-0000-4000-8000-000000000609', 'd0320000-0000-4000-8000-000000000001', 'cc_counter', 'Cost Controller kiêm đếm');

insert into public.role_permissions (role_id, permission_code) values
  ('d0320000-0000-4000-8000-000000000601', 'count.open'),
  ('d0320000-0000-4000-8000-000000000601', 'count.perform'),
  ('d0320000-0000-4000-8000-000000000601', 'receiving.post'),
  ('d0320000-0000-4000-8000-000000000601', 'requisition.issue'),
  ('d0320000-0000-4000-8000-000000000601', 'purpose_issue.post'),
  ('d0320000-0000-4000-8000-000000000601', 'stock.view_qty'),
  ('d0320000-0000-4000-8000-000000000602', 'count.perform'),
  ('d0320000-0000-4000-8000-000000000603', 'count.view_variance'),
  ('d0320000-0000-4000-8000-000000000603', 'stock.view_qty'),
  ('d0320000-0000-4000-8000-000000000603', 'stock.view_value'),
  ('d0320000-0000-4000-8000-000000000604', 'count.adjust.approve'),
  ('d0320000-0000-4000-8000-000000000604', 'stock.view_value'),
  ('d0320000-0000-4000-8000-000000000604', 'day.unlock'),
  ('d0320000-0000-4000-8000-000000000605', 'audit.view_all'),
  ('d0320000-0000-4000-8000-000000000605', 'stock.view_value'),
  ('d0320000-0000-4000-8000-000000000605', 'po.view'),
  ('d0320000-0000-4000-8000-000000000605', 'po.view_qty'),
  ('d0320000-0000-4000-8000-000000000605', 'po.view_price'),
  ('d0320000-0000-4000-8000-000000000606', 'count.lock'),
  ('d0320000-0000-4000-8000-000000000606', 'day.lock'),
  ('d0320000-0000-4000-8000-000000000607', 'period.close'),
  ('d0320000-0000-4000-8000-000000000607', 'period.reopen'),
  ('d0320000-0000-4000-8000-000000000608', 'count.perform'),
  ('d0320000-0000-4000-8000-000000000608', 'receiving.post'),
  ('d0320000-0000-4000-8000-000000000609', 'count.perform'),
  ('d0320000-0000-4000-8000-000000000609', 'count.view_variance');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0320000-0000-4000-8000-000000000a01', 'd0320000-0000-4000-8000-000000000601', 'd0320000-0000-4000-8000-000000000201'),
  ('d0320000-0000-4000-8000-000000000a02', 'd0320000-0000-4000-8000-000000000602', 'd0320000-0000-4000-8000-000000000201'),
  ('d0320000-0000-4000-8000-000000000a03', 'd0320000-0000-4000-8000-000000000603', 'd0320000-0000-4000-8000-000000000201'),
  ('d0320000-0000-4000-8000-000000000a04', 'd0320000-0000-4000-8000-000000000604', 'd0320000-0000-4000-8000-000000000201'),
  ('d0320000-0000-4000-8000-000000000a05', 'd0320000-0000-4000-8000-000000000605', null),
  ('d0320000-0000-4000-8000-000000000a06', 'd0320000-0000-4000-8000-000000000606', 'd0320000-0000-4000-8000-000000000201'),
  ('d0320000-0000-4000-8000-000000000a07', 'd0320000-0000-4000-8000-000000000607', null),
  ('d0320000-0000-4000-8000-000000000a08', 'd0320000-0000-4000-8000-000000000608', 'd0320000-0000-4000-8000-000000000201'),
  ('d0320000-0000-4000-8000-000000000a09', 'd0320000-0000-4000-8000-000000000609', 'd0320000-0000-4000-8000-000000000201');

select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
  ('d0320000-0000-4000-8000-000000000b01', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', null, 'contract', 'stock', '2026-08-15', '2026-09-01', null, 'partially_received', 'd0320000-0000-4000-8000-000000000a01', 'PO-032-001');
select set_config('app.pr_po_guard_bypass', 'off', true);

select set_config('app.advance_guard_bypass', 'on', true);
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status) values
  ('d0320000-0000-4000-8000-000000000901', 'd0320000-0000-4000-8000-000000000001', 'd0320000-0000-4000-8000-000000000101', 'd0320000-0000-4000-8000-000000000201', 'd0320000-0000-4000-8000-000000000a07', 'ADV-032-001', 1000000, 'Đi chợ', 'overdue');
select set_config('app.advance_guard_bypass', 'off', true);

create temp table t032_ctx (key text primary key, id uuid);

create temp table t032_resp (key text primary key, resp jsonb);

grant all on t032_ctx, t032_resp to authenticated;

create or replace function public._t032_as(p_user uuid)
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
  (select relrowsecurity from pg_class where relname = 'stock_counts'),
  true, 'stock_counts has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'stock_count_lines'),
  true, 'stock_count_lines has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'count_adjustments'),
  true, 'count_adjustments has RLS enabled'
);

select throws_ok(
  $q$insert into public.stock_counts (org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind, business_date, status, opened_by, created_by) values (
    'd0320000-0000-4000-8000-000000000001',
    'd0320000-0000-4000-8000-000000000101',
    'd0320000-0000-4000-8000-000000000201',
    'd0320000-0000-4000-8000-000000000301',
    'CNT-TEST-001', 'monthly_full', '2026-11-09', 'open',
    'd0320000-0000-4000-8000-000000000a07',
    'd0320000-0000-4000-8000-000000000a07'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Direct stock_counts insert is blocked by write guard'
);

select throws_ok(
  $q$insert into public.stock_count_lines (count_id, org_id, item_id) values (
    'd0320000-0000-4000-8000-000000000e01',
    'd0320000-0000-4000-8000-000000000001',
    'd0320000-0000-4000-8000-000000000501'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Direct stock_count_lines insert is blocked by write guard'
);

set local role authenticated;

select public._t032_as('d0320000-0000-4000-8000-000000000a05');
select throws_ok(
  $q$select public.count_open(
    'd0320000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
    array['d0320000-0000-4000-8000-000000000a01', 'd0320000-0000-4000-8000-000000000a02']::uuid[]
  )$q$,
  '42501', 'ERR_FORBIDDEN:count.open',
  'owner without count.open cannot open a count'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_open(
    'd0320000-0000-4000-8000-000000000301', 'bad_kind', '2026-11-09'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'count_open rejects unknown kind'
);
select throws_ok(
  $q$select public.count_open(
    'd0320000-0000-4000-8000-000000000301', 'shift_key', '2026-11-09', 'ca_sang',
    array['d0320000-0000-4000-8000-000000000a01', 'd0320000-0000-4000-8000-000000000a02']::uuid[]
  )$q$,
  'P0001', 'ERR_POS_IMPORT_REQUIRED',
  'shift_key count requires pos_imports'
);
select throws_ok(
  $q$select public.count_open(
    'd0320000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
    array['d0320000-0000-4000-8000-000000000a01']::uuid[]
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'monthly_full needs at least 2 counters'
);
select throws_ok(
  $q$select public.count_open(
    'd0320000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
    array['d0320000-0000-4000-8000-000000000a01', 'd0320000-0000-4000-8000-000000000a08']::uuid[]
  )$q$,
  'P0001', 'ERR_SOD_COUNT_INDEPENDENT',
  'team without an independent counter is rejected at open'
);

insert into t032_resp values ('openA', public.count_open(
  'd0320000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['d0320000-0000-4000-8000-000000000a01', 'd0320000-0000-4000-8000-000000000a02']::uuid[],
  'd0320000-0000-4000-8000-00000000aa01'
));
select ok(
  (select (resp ->> 'ok')::boolean from t032_resp where key = 'openA'),
  'count_open succeeds for MAIN warehouse'
);
select ok(
  (select (resp ->> 'doc_no') like 'CNT-%' from t032_resp where key = 'openA'),
  'count doc_no starts with CNT-'
);
select is(
  (select (resp ->> 'lines_created')::int from t032_resp where key = 'openA'),
  4, 'snapshot creates 4 lines'
);
insert into t032_ctx values ('cntA', (select (resp ->> 'id')::uuid from t032_resp where key = 'openA'));

select throws_ok(
  $q$select public.count_open(
    'd0320000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
    array['d0320000-0000-4000-8000-000000000a01', 'd0320000-0000-4000-8000-000000000a02']::uuid[]
  )$q$,
  'P0001', 'ERR_COUNT_ALREADY_OPEN',
  'second monthly count on the same warehouse is rejected'
);

select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'v_count_sheet'
     and column_name in ('book_qty', 'theoretical_qty')),
  0::bigint, 'v_count_sheet has no book_qty/theoretical_qty columns'
);
select is(
  (select count(*) from public.v_count_sheet
   where count_id = (select id from t032_ctx where key = 'cntA')),
  4::bigint, 'counter reads 4 sheet lines'
);
select is(
  (select count(*) from public.stock_count_lines
   where count_id = (select id from t032_ctx where key = 'cntA')),
  0::bigint, 'counter cannot SELECT stock_count_lines directly'
);
select is(
  (select count(*) from public.v_count_result
   where count_id = (select id from t032_ctx where key = 'cntA')),
  0::bigint, 'counter sees no rows in v_count_result'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a03');
select is(
  (select count(*) from public.v_count_result
   where count_id = (select id from t032_ctx where key = 'cntA')),
  4::bigint, 'variance viewer reads 4 result lines'
);
select is(
  (select book_qty from public.v_count_result
   where count_id = (select id from t032_ctx where key = 'cntA')
     and item_code = 'ITM_GAO'),
  100::numeric, 'GAO book_qty is 100 in v_count_result'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.count_record_line(
    (select id from t032_ctx where key = 'cntA'),
    'd0320000-0000-4000-8000-000000000501',
    '{"qty": 1, "uom": "kg"}'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:count.perform',
  'non-counter cannot record a line'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a08');
select throws_ok(
  $q$select public.count_record_line(
    (select id from t032_ctx where key = 'cntA'),
    'd0320000-0000-4000-8000-000000000501',
    '{"qty": 1, "uom": "kg"}'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:count.perform',
  'count.perform holder outside the team cannot record'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_record_line(
    (select id from t032_ctx where key = 'cntA'),
    'd0320000-0000-4000-8000-000000000503',
    '{"qty": 1, "uom": "thung"}'::jsonb
  )$q$,
  'P0001', 'ERR_UOM_UNKNOWN',
  'unknown UOM is rejected'
);

insert into t032_resp values ('rec_gao1', public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000501',
  '[{"qty": 9, "uom": "cai"}, {"qty": 8, "uom": "kg"}]'::jsonb
));
select is(
  (select (resp ->> 'counted_qty')::numeric from t032_resp where key = 'rec_gao1'),
  98::numeric, 'GAO 9 cai + 8 kg converts to 98 kg'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000501',
  '{"qty": 98, "uom": "kg"}'::jsonb
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
insert into t032_resp values ('rec_thit1', public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000502',
  '{"qty": 20, "uom": "kg"}'::jsonb
));
select ok(
  (select (resp ->> 'ok')::boolean from t032_resp where key = 'rec_thit1'),
  'THIT recorded by counter 1'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000502',
  '{"qty": 20, "uom": "kg"}'::jsonb
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
insert into t032_resp values ('rec_muoi1', public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
));
select ok(
  (select (resp ->> 'ok')::boolean from t032_resp where key = 'rec_muoi1'),
  'MUOI recorded by counter 1'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
insert into t032_resp values ('rec_ruou1', public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000504',
  null, 925
));
select is(
  (select (resp ->> 'counted_qty')::numeric from t032_resp where key = 'rec_ruou1'),
  500::numeric, 'bottle 925g converts to 500 ml'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._t032_as('d0320000-0000-4000-8000-000000000a01');
-- purpose_issue_save_draft chi nhan 1 doi so jsonb (migration 260000):
-- {property_id, warehouse_id, purpose_code, cost_center_id,
-- expense_category_id, lines[{item_id, qty, uom}]}; khong co client_uuid.
insert into t032_resp values ('freeze_issue', public.purpose_issue_save_draft(jsonb_build_object(
  'property_id', 'd0320000-0000-4000-8000-000000000201',
  'warehouse_id', 'd0320000-0000-4000-8000-000000000301',
  'purpose_code', 'other',
  'cost_center_id', 'd0320000-0000-4000-8000-000000000901',
  'expense_category_id', 'd0320000-0000-4000-8000-000000000902',
  'lines', jsonb_build_array(jsonb_build_object(
    'item_id', 'd0320000-0000-4000-8000-000000000503',
    'qty', 5, 'uom', 'kg'
  ))
)));
insert into t032_ctx values ('pi_main', (select (resp ->> 'id')::uuid from t032_resp where key = 'freeze_issue'));
select throws_ok(
  $q$select public.purpose_issue_post((select id from t032_ctx where key = 'pi_main'))$q$,
  'P0001', 'ERR_COUNT_FREEZE',
  'purpose_issue into MAIN is frozen while count A is open'
);

insert into t032_resp values ('kit_issue', public.purpose_issue_save_draft(jsonb_build_object(
  'property_id', 'd0320000-0000-4000-8000-000000000201',
  'warehouse_id', 'd0320000-0000-4000-8000-000000000302',
  'purpose_code', 'other',
  'cost_center_id', 'd0320000-0000-4000-8000-000000000901',
  'expense_category_id', 'd0320000-0000-4000-8000-000000000902',
  'lines', jsonb_build_array(jsonb_build_object(
    'item_id', 'd0320000-0000-4000-8000-000000000503',
    'qty', 5, 'uom', 'kg'
  ))
)));
insert into t032_ctx values ('pi_kit', (select (resp ->> 'id')::uuid from t032_resp where key = 'kit_issue'));
select ok(
  (select (resp ->> 'ok')::boolean from t032_resp where key = 'kit_issue'),
  'purpose_issue draft for KIT is created'
);
select public.purpose_issue_post((select id from t032_ctx where key = 'pi_kit'));
select is(
  (select qty::numeric from public.stock_balances
   where warehouse_id = 'd0320000-0000-4000-8000-000000000302'
     and item_id = 'd0320000-0000-4000-8000-000000000503'),
  5::numeric, 'KIT MUOI balance is 5 after unfrozen purpose_issue'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a08');
select throws_ok(
  $q$select public.count_submit(
    (select id from t032_ctx where key = 'cntA'),
    array['1111', '9999']
  )$q$,
  '42501', 'ERR_FORBIDDEN:count.perform',
  'submit by non-counter is rejected'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_submit(
    (select id from t032_ctx where key = 'cntA'),
    array['9999', '2222']
  )$q$,
  'P0001', 'ERR_PIN_INVALID',
  'submit with wrong PIN is rejected'
);

insert into t032_resp values ('submit1', public.count_submit(
  (select id from t032_ctx where key = 'cntA'),
  array['1111', '2222']
));
select ok(
  (select (resp ->> 'ok')::boolean from t032_resp where key = 'submit1'),
  'count_submit round 1 succeeds'
);
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from t032_resp where key = 'submit1'),
  2, 'submit1 flags 2 recount lines'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from t032_resp where key = 'submit1'),
  0, 'submit1 flags 0 red lines'
);
select ok(
  (select (resp - 'ok' - 'id' - 'recount_line_ids' - 'red_line_ids') = '{}'::jsonb
   from t032_resp where key = 'submit1'),
  'submit1 leaks no quantities in the response'
);
select is(
  (select status from public.stock_counts where id = (select id from t032_ctx where key = 'cntA')),
  'recount', 'count status is recount after submit1'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select is(
  (select my_counted_qty from public.v_count_sheet
   where count_id = (select id from t032_ctx where key = 'cntA')
     and item_code = 'ITM_GAO'),
  null, 'sheet hides old counted qty for a recount line'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000501',
  '{"qty": 98, "uom": "kg"}'::jsonb
);
select public._t032_as('d0320000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000501',
  '{"qty": 98, "uom": "kg"}'::jsonb
);
select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._t032_as('d0320000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from t032_ctx where key = 'cntA'),
  'd0320000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
-- GHI CHU: vong 2 KHONG can ghi lai dong da 'ok' (THIT/MUOI giu so vong 1).
-- count_submit chi kiem "moi dong du 2 luot dem" (spec 09 §11 ERR_COUNT_INCOMPLETE);
-- dong 'recount' (GAO/RUUOU) da ghi lai du 2 luot o tren nen submit vong 2
-- THANH CONG luon. Test cu doi ERR_COUNT_INCOMPLETE o day la sai, va 4 lenh
-- ghi lai THIT/MUOI sau do se chet tren phieu da 'submitted' (ERR_INVALID_STATUS).
select public._t032_as('d0320000-0000-4000-8000-000000000a01');
insert into t032_resp values ('submit2', public.count_submit(
  (select id from t032_ctx where key = 'cntA'),
  array['2222', '1111']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from t032_resp where key = 'submit2'),
  0, 'submit2 flags 0 recount lines'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from t032_resp where key = 'submit2'),
  2, 'submit2 flags 2 red lines (GAO + RUUOU)'
);
select is(
  (select status from public.stock_counts where id = (select id from t032_ctx where key = 'cntA')),
  'submitted', 'count status is submitted after submit2'
);
-- Doc truc tiep stock_count_lines chi cho phep nguoi co count.view_variance
-- (policy stock_count_lines_select) nen cac assert doc dong phai chay bang a03.
select public._t032_as('d0320000-0000-4000-8000-000000000a03');
select ok(
  (select (resp -> 'red_line_ids')::text like '%' || (select id::text from public.stock_count_lines
     where count_id = (select id from t032_ctx where key = 'cntA')
       and item_id = 'd0320000-0000-4000-8000-000000000501') || '%'
   from t032_resp where key = 'submit2'),
  'red lines include GAO'
);
select ok(
  (select (resp -> 'red_line_ids')::text like '%' || (select id::text from public.stock_count_lines
     where count_id = (select id from t032_ctx where key = 'cntA')
       and item_id = 'd0320000-0000-4000-8000-000000000504') || '%'
   from t032_resp where key = 'submit2'),
  'red lines include RUUOU (500 ml vs book 7000 ml)'
);
select is(
  (select flag from public.stock_count_lines
   where count_id = (select id from t032_ctx where key = 'cntA')
     and item_id = 'd0320000-0000-4000-8000-000000000501'),
  'red', 'GAO line flag is red'
);
select is(
  (select variance_qty::numeric from public.stock_count_lines
   where count_id = (select id from t032_ctx where key = 'cntA')
     and item_id = 'd0320000-0000-4000-8000-000000000501'),
  -2::numeric, 'GAO variance is -2'
);

select public._t032_as('d0320000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_lock((select id from t032_ctx where key = 'cntA'))$q$,
  '42501', 'ERR_FORBIDDEN:count.lock',
  'counter cannot lock the count'
);
select public._t032_as('d0320000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.count_lock((select id from t032_ctx where key = 'cntA'))$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'lock without a reason for the red line is rejected'
);
-- count_lock chi nhan p_reasons dang mang JSON [{line_id, reason_code, explanation}]
-- (migration 280000 + script demo mo ton); RPC khong co whitelist ma ly do nen
-- khong the test "ma ly do khong ton tai". Test thay the: doi tuong JSON
-- (khong phai mang) bi tu choi ERR_INVALID_VALUE.
select throws_ok(
  $q$select public.count_lock(
    (select id from t032_ctx where key = 'cntA'),
    jsonb_build_object('test-line', 'lost')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'lock with a non-array reasons argument is rejected'
);
-- Mang ly do phai dung truoc bang a03 (co count.view_variance, doc duoc
-- stock_count_lines): doi so cua count_lock chay trong context cua nguoi goi
-- (a06, khong co count.view_variance) nen subquery doc line_id tra NULL.
select public._t032_as('d0320000-0000-4000-8000-000000000a03');
insert into t032_resp values ('lock_reasons', jsonb_build_array(
  jsonb_build_object(
    'line_id', (select id from public.stock_count_lines
       where count_id = (select id from t032_ctx where key = 'cntA')
         and item_id = 'd0320000-0000-4000-8000-000000000501'),
    'reason_code', 'lost',
    'explanation', 'test'
  ),
  jsonb_build_object(
    'line_id', (select id from public.stock_count_lines
       where count_id = (select id from t032_ctx where key = 'cntA')
         and item_id = 'd0320000-0000-4000-8000-000000000504'),
    'reason_code', 'lost',
    'explanation', 'test'
  )
));
select public._t032_as('d0320000-0000-4000-8000-000000000a06');
select ok(
  (select (resp ->> 'ok')::boolean from (
    select public.count_lock(
      (select id from t032_ctx where key = 'cntA'),
      (select resp from t032_resp where key = 'lock_reasons')
    ) as resp
  ) s),
  'count_lock succeeds with a valid reason'
);
rollback;
