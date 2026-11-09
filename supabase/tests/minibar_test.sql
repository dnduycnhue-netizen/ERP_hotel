-- T-035 pgTAP: minibar theo phong — bang gia, phieu kiem, thu/mien/late
-- charge, doi soat cuoi ngay, thu hoi sap het han.
-- Kiem tra: RLS 3 bang moi, write-guard checks/lines, gia theo thoi gian,
-- refill transfer main -> room (item_costs khong doi), kiem + thu + folio
-- (move minibar_sale, kho phong con dung so), mien can gm duyet + SoD,
-- late_charge, write_off, audit that thoat gan ca buong, doi soat khop /
-- lech (pending qua ngay -> MINIBAR_MISMATCH), recall list.
-- Ngay nghiep vu = today (Asia/Ho_Chi_Minh) lay dong; khong hard-code today.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(104);

insert into public.organizations (id, name) values
  ('d0350000-0000-4000-8000-000000000001', 'T-035 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000001', 'T035', 'Entity T-035');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'P0351', 'Property T-035', 'with_cc'),
  ('d0350000-0000-4000-8000-000000000202', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'P0352', 'Property T-035 B', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('chai', 'Chai'),
  ('lon', 'Lon')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0350000-0000-4000-8000-000000000401', 'd0350000-0000-4000-8000-000000000001', 'MB', 'Minibar', 'minibar'),
  ('d0350000-0000-4000-8000-000000000402', 'd0350000-0000-4000-8000-000000000001', 'COMP', 'Complimentary', 'complimentary');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d0350000-0000-4000-8000-000000000501', 'd0350000-0000-4000-8000-000000000001', 'ITM_LAVIE', 'Nước Lavie', 'd0350000-0000-4000-8000-000000000401', 'chai', false, false, null, array['contract', 'market'], false),
  ('d0350000-0000-4000-8000-000000000502', 'd0350000-0000-4000-8000-000000000001', 'ITM_TIGER', 'Bia Tiger', 'd0350000-0000-4000-8000-000000000401', 'lon', false, false, null, array['contract', 'market'], false),
  ('d0350000-0000-4000-8000-000000000503', 'd0350000-0000-4000-8000-000000000001', 'ITM_COCA', 'Coca', 'd0350000-0000-4000-8000-000000000401', 'lon', false, false, null, array['contract', 'market'], false),
  ('d0350000-0000-4000-8000-000000000504', 'd0350000-0000-4000-8000-000000000001', 'ITM_DASANI', 'Nước Dasani', 'd0350000-0000-4000-8000-000000000402', 'chai', false, false, null, array['contract', 'market'], false),
  ('d0350000-0000-4000-8000-000000000505', 'd0350000-0000-4000-8000-000000000001', 'TMP-035-1', 'Mã tạm 1', 'd0350000-0000-4000-8000-000000000401', 'chai', false, false, null, array['contract', 'market'], true);

insert into public.outlet_types (id, org_id, code, name) values
  ('d0350000-0000-4000-8000-000000000801', 'd0350000-0000-4000-8000-000000000001', 'HK', 'Buồng phòng');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0350000-0000-4000-8000-000000000802', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000801', 'HK', 'Buồng phòng');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id, room_id) values
  ('d0350000-0000-4000-8000-000000000301', 'd0350000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null, null),
  ('d0350000-0000-4000-8000-000000000302', 'd0350000-0000-4000-8000-000000000201', 'WH_TRANSIT', 'Kho trung chuyển', 'transit', null, null),
  ('d0350000-0000-4000-8000-000000000303', 'd0350000-0000-4000-8000-000000000201', 'MB_MAIN', 'Kho minibar tổng', 'minibar_main', null, null),
  ('d0350000-0000-4000-8000-000000000304', 'd0350000-0000-4000-8000-000000000201', 'MB_101', 'Minibar phòng 101', 'minibar_room', null, 'd0350000-0000-4000-8000-000000000c01'),
  ('d0350000-0000-4000-8000-000000000305', 'd0350000-0000-4000-8000-000000000201', 'MB_102', 'Minibar phòng 102', 'minibar_room', null, 'd0350000-0000-4000-8000-000000000c02'),
  ('d0350000-0000-4000-8000-000000000306', 'd0350000-0000-4000-8000-000000000202', 'MB_MAIN2', 'Kho minibar tổng 2', 'minibar_main', null, null),
  ('d0350000-0000-4000-8000-000000000307', 'd0350000-0000-4000-8000-000000000202', 'MB_201', 'Minibar phòng 201', 'minibar_room', null, 'd0350000-0000-4000-8000-000000000c03'),
  ('d0350000-0000-4000-8000-000000000308', 'd0350000-0000-4000-8000-000000000201', 'WH_TROLLEY1', 'Xe đẩy 1', 'trolley', 'd0350000-0000-4000-8000-000000000802', null),
  ('d0350000-0000-4000-8000-000000000309', 'd0350000-0000-4000-8000-000000000201', 'MB_103', 'Minibar phòng 103', 'minibar_room', null, 'd0350000-0000-4000-8000-000000000c04'),
  ('d0350000-0000-4000-8000-000000000310', 'd0350000-0000-4000-8000-000000000201', 'MB_104', 'Minibar phòng 104', 'minibar_room', null, 'd0350000-0000-4000-8000-000000000c05');

insert into public.room_types (id, property_id, code, name, max_guests) values
  ('d0350000-0000-4000-8000-000000000b01', 'd0350000-0000-4000-8000-000000000201', 'DLX', 'Deluxe', 2),
  ('d0350000-0000-4000-8000-000000000b02', 'd0350000-0000-4000-8000-000000000202', 'STD', 'Standard', 2);

insert into public.rooms (id, property_id, room_type_id, room_no, floor) values
  ('d0350000-0000-4000-8000-000000000c01', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000b01', '101', '1'),
  ('d0350000-0000-4000-8000-000000000c02', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000b01', '102', '1'),
  ('d0350000-0000-4000-8000-000000000c03', 'd0350000-0000-4000-8000-000000000202', 'd0350000-0000-4000-8000-000000000b02', '201', '2'),
  ('d0350000-0000-4000-8000-000000000c04', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000b01', '103', '1'),
  ('d0350000-0000-4000-8000-000000000c05', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000b01', '104', '1');

-- Gia Lavie theo thoi gian: cu 20000 (01-06/2026), moi 25000 (tu 07/2026).
insert into public.minibar_price_list (org_id, property_id, item_id, price, valid_from, valid_to) values
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000501', 20000, '2026-01-01', '2026-06-30'),
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000501', 25000, '2026-07-01', null);

-- Ton mo dau kho minibar tong + gia von (moving_avg mac dinh).
insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000303', 'd0350000-0000-4000-8000-000000000501', null, 10),
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000303', 'd0350000-0000-4000-8000-000000000502', null, 10),
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000303', 'd0350000-0000-4000-8000-000000000503', null, 5);

insert into public.item_costs (legal_entity_id, org_id, item_id, avg_cost, qty_on_hand) values
  ('d0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000501', 15000, 10),
  ('d0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000502', 20000, 10),
  ('d0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000503', 12000, 5);

-- Lo sap het han (recall test): Tiger het han sau 10 ngay, Lavie sau 200 ngay.
insert into public.lots (id, org_id, property_id, item_id, lot_no, expiry_date) values
  ('d0350000-0000-4000-8000-000000000e01', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000502', 'LOT-TIGER-1', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 10),
  ('d0350000-0000-4000-8000-000000000e02', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000501', 'LOT-LAVIE-1', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 200);

insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000304', 'd0350000-0000-4000-8000-000000000502', 'd0350000-0000-4000-8000-000000000e01', 2),
  ('d0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000304', 'd0350000-0000-4000-8000-000000000501', 'd0350000-0000-4000-8000-000000000e02', 1);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0350000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-gm035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-hks035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-hka035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-fd035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-gm2035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a07', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u7-stk035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a08', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u8-cc035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0350000-0000-4000-8000-000000000a10', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u10-view035@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0350000-0000-4000-8000-000000000a01', 'NV03501', 'Tổng quản lý'),
  ('d0350000-0000-4000-8000-000000000a02', 'NV03502', 'Giám sát buồng'),
  ('d0350000-0000-4000-8000-000000000a03', 'NV03503', 'Nhân viên buồng'),
  ('d0350000-0000-4000-8000-000000000a04', 'NV03504', 'Lễ tân'),
  ('d0350000-0000-4000-8000-000000000a06', 'NV03506', 'Tổng quản lý 2'),
  ('d0350000-0000-4000-8000-000000000a07', 'NV03507', 'Thủ kho'),
  ('d0350000-0000-4000-8000-000000000a08', 'NV03508', 'Kiểm soát chi phí'),
  ('d0350000-0000-4000-8000-000000000a10', 'NV03510', 'Chỉ xem')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0350000-0000-4000-8000-000000000601', 'd0350000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0350000-0000-4000-8000-000000000602', 'd0350000-0000-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng'),
  ('d0350000-0000-4000-8000-000000000603', 'd0350000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng'),
  ('d0350000-0000-4000-8000-000000000604', 'd0350000-0000-4000-8000-000000000001', 'front_desk', 'Lễ tân'),
  ('d0350000-0000-4000-8000-000000000607', 'd0350000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0350000-0000-4000-8000-000000000608', 'd0350000-0000-4000-8000-000000000001', 'cost_controller', 'Kiểm soát chi phí'),
  ('d0350000-0000-4000-8000-000000000609', 'd0350000-0000-4000-8000-000000000001', 'r_view035', 'Chỉ xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0350000-0000-4000-8000-000000000601', 'minibar.waive.approve'),
  ('d0350000-0000-4000-8000-000000000601', 'minibar.waive.request'),
  ('d0350000-0000-4000-8000-000000000601', 'minibar.reconcile'),
  ('d0350000-0000-4000-8000-000000000601', 'minibar.price.manage'),
  ('d0350000-0000-4000-8000-000000000601', 'report.view.rpt_minibar'),
  ('d0350000-0000-4000-8000-000000000601', 'alert.receive.minibar_mismatch'),
  ('d0350000-0000-4000-8000-000000000601', 'alert.receive.minibar_loss'),
  ('d0350000-0000-4000-8000-000000000601', 'alert.receive.minibar_check_requested'),
  ('d0350000-0000-4000-8000-000000000602', 'minibar.price.manage'),
  ('d0350000-0000-4000-8000-000000000602', 'minibar.refill'),
  ('d0350000-0000-4000-8000-000000000602', 'hk.standard.manage'),
  ('d0350000-0000-4000-8000-000000000603', 'minibar.check'),
  ('d0350000-0000-4000-8000-000000000603', 'minibar.refill'),
  ('d0350000-0000-4000-8000-000000000604', 'minibar.request_check'),
  ('d0350000-0000-4000-8000-000000000604', 'minibar.charge.confirm'),
  ('d0350000-0000-4000-8000-000000000604', 'minibar.waive.request'),
  ('d0350000-0000-4000-8000-000000000607', 'stock.view_qty'),
  ('d0350000-0000-4000-8000-000000000608', 'minibar.reconcile'),
  ('d0350000-0000-4000-8000-000000000608', 'report.view.rpt_minibar'),
  ('d0350000-0000-4000-8000-000000000608', 'alert.receive.minibar_mismatch'),
  ('d0350000-0000-4000-8000-000000000609', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0350000-0000-4000-8000-000000000a01', 'd0350000-0000-4000-8000-000000000601', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a02', 'd0350000-0000-4000-8000-000000000602', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a03', 'd0350000-0000-4000-8000-000000000603', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a04', 'd0350000-0000-4000-8000-000000000604', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a06', 'd0350000-0000-4000-8000-000000000601', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a07', 'd0350000-0000-4000-8000-000000000607', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a08', 'd0350000-0000-4000-8000-000000000608', 'd0350000-0000-4000-8000-000000000201'),
  ('d0350000-0000-4000-8000-000000000a10', 'd0350000-0000-4000-8000-000000000609', 'd0350000-0000-4000-8000-000000000201');

-- 1 ca xe day mo hom nay (de audit-loss gan ca). Can bypass guard T-034.
select set_config('app.hk_guard_bypass', 'on', true);
insert into public.trolley_shifts (id, org_id, legal_entity_id, property_id, trolley_warehouse_id, attendant_id, business_date, shift, status) values
  ('d0350000-0000-4000-8000-000000000d01', 'd0350000-0000-4000-8000-000000000001', 'd0350000-0000-4000-8000-000000000101', 'd0350000-0000-4000-8000-000000000201', 'd0350000-0000-4000-8000-000000000308', 'd0350000-0000-4000-8000-000000000a03', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'day', 'open');
select set_config('app.hk_guard_bypass', 'off', true);

create temp table t035_ctx (key text primary key, id uuid, resp jsonb);
grant all on t035_ctx to authenticated;

create or replace function public._t035_as(p_user uuid)
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

-- A. RLS bat cho 3 bang moi (3).
select is(
  (select relrowsecurity from pg_class where relname = 'minibar_price_list'),
  true, 'minibar_price_list has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'minibar_checks'),
  true, 'minibar_checks has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'minibar_check_lines'),
  true, 'minibar_check_lines has RLS enabled'
);

-- B. Write-guard checks/lines (2).
select throws_ok(
  $q$insert into public.minibar_checks (org_id, legal_entity_id, property_id, room_id, doc_no, business_date, trigger, status) values (
    'd0350000-0000-4000-8000-000000000001',
    'd0350000-0000-4000-8000-000000000101',
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000c01',
    'MB-GUARD-001', '2026-11-10', 'checkout', 'pending_charge'
  )$q$,
  'P0001', 'ERR_WRITE_GUARD: minibar_checks chi duoc ghi qua RPC',
  'Direct minibar_checks insert is blocked by write guard'
);
select throws_ok(
  $q$insert into public.minibar_check_lines (check_id, org_id, property_id, item_id, missing_qty, unit_price, amount) values (
    'd0350000-0000-4000-8000-000000000001',
    'd0350000-0000-4000-8000-000000000001',
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000501', 1, 25000, 25000
  )$q$,
  'P0001', 'ERR_WRITE_GUARD: minibar_check_lines chi duoc ghi qua RPC',
  'Direct minibar_check_lines insert is blocked by write guard'
);

set local role authenticated;

-- C. Gia theo thoi gian + minibar_price_set (10).
select is(
  public._minibar_price_at(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000501', '2026-03-01'),
  20000::numeric, 'Lavie price at 2026-03-01 is old 20000'
);
select is(
  public._minibar_price_at(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000501', '2026-11-10'),
  25000::numeric, 'Lavie price at 2026-11-10 is new 25000'
);
select is(
  public._minibar_price_at(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000503', '2026-11-10'),
  null::numeric, 'Coca has no price yet'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000502', 35000, '2026-07-01', null
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.price.manage',
  'viewer cannot set minibar price'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a02');
select is(
  (select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000502', 35000, '2026-07-01', null
  ) ->> 'ok'),
  'true', 'hk_supervisor sets Tiger price 35000'
);
select is(
  (select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000503', 20000, '2026-07-01', '2026-11-09'
  ) ->> 'ok'),
  'true', 'hk_supervisor sets Coca price 20000 valid to 2026-11-09'
);
select throws_ok(
  $q$select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000502', 0, '2026-07-01', null
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'price_set rejects zero price'
);
select throws_ok(
  $q$select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000502', 35000, '2026-07-10', '2026-07-01'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'price_set rejects valid_to before valid_from'
);
select throws_ok(
  $q$select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000504', 10000, '2026-07-01', null
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'price_set rejects Dasani (complimentary, not minibar)'
);
select throws_ok(
  $q$select public.minibar_price_set(
    'd0350000-0000-4000-8000-000000000201',
    'd0350000-0000-4000-8000-000000000505', 10000, '2026-07-01', null
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'price_set rejects temp item'
);

-- D. Refill transfer main -> room (14).
select public._t035_as('d0350000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c01',
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 2}]'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.refill',
  'viewer cannot refill minibar'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c03',
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 2}]'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.refill',
  'attendant cannot refill room of another property'
);
select throws_ok(
  $q$select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c01',
    '[{"item_id": "d0350000-0000-4000-8000-000000000504", "qty": 2}]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'refill rejects Dasani (complimentary)'
);
select throws_ok(
  $q$select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c01',
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 100}]'::jsonb
  )$q$,
  'P0001', 'ERR_INSUFFICIENT_STOCK',
  'refill rejects qty above main stock'
);
select throws_ok(
  $q$select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c01',
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 1}, {"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 1}]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'refill rejects duplicate item in lines'
);

-- 11-TESTING §4.1: bo sung phong 101: 2 Lavie, 2 Tiger.
insert into t035_ctx values ('refill101', null, (select public.minibar_refill(
  'd0350000-0000-4000-8000-000000000c01',
  '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 2}, {"item_id": "d0350000-0000-4000-8000-000000000502", "qty": 2}]'::jsonb
)));
select is(
  (select resp ->> 'status' from t035_ctx where key = 'refill101'),
  'received', 'refill 101 returns status received'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000303'
     and item_id = 'd0350000-0000-4000-8000-000000000501' and lot_id is null),
  8::numeric, 'minibar_main Lavie drops 10 -> 8 after refill'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000303'
     and item_id = 'd0350000-0000-4000-8000-000000000502' and lot_id is null),
  8::numeric, 'minibar_main Tiger drops 10 -> 8 after refill'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000304'
     and item_id = 'd0350000-0000-4000-8000-000000000501' and lot_id is null),
  2::numeric, 'room 101 Lavie rises 0 -> 2 after refill'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000304'
     and item_id = 'd0350000-0000-4000-8000-000000000502' and lot_id is null),
  2::numeric, 'room 101 Tiger rises 0 -> 2 after refill'
);
select is(
  (select qty_on_hand from public.item_costs
   where legal_entity_id = 'd0350000-0000-4000-8000-000000000101'
     and item_id = 'd0350000-0000-4000-8000-000000000501'),
  10::numeric, 'item_costs Lavie qty_on_hand unchanged by transfer'
);
select is(
  (select qty_on_hand from public.item_costs
   where legal_entity_id = 'd0350000-0000-4000-8000-000000000101'
     and item_id = 'd0350000-0000-4000-8000-000000000502'),
  10::numeric, 'item_costs Tiger qty_on_hand unchanged by transfer'
);
select is(
  (select count(*) from public.stock_moves
   where source_doc_type = 'transfer'
     and source_doc_id = (select (resp ->> 'id')::uuid from t035_ctx where key = 'refill101')
     and move_type = 'transfer_out'),
  2::bigint, 'refill posts 2 transfer_out moves'
);
select is(
  (select count(*) from public.transfers
   where id = (select (resp ->> 'id')::uuid from t035_ctx where key = 'refill101')
     and status = 'received'),
  1::bigint, 'refill creates one received transfer doc'
);

-- Refill phong 103 + 104 (dung cho confirm_charge sau nay).
select is(
  (select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c04',
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 2}, {"item_id": "d0350000-0000-4000-8000-000000000502", "qty": 2}]'::jsonb
  ) ->> 'ok'),
  'true', 'refill room 103 ok'
);
select is(
  (select public.minibar_refill(
    'd0350000-0000-4000-8000-000000000c05',
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "qty": 2}, {"item_id": "d0350000-0000-4000-8000-000000000502", "qty": 2}]'::jsonb
  ) ->> 'ok'),
  'true', 'refill room 104 ok'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000303'
     and item_id = 'd0350000-0000-4000-8000-000000000501' and lot_id is null),
  4::numeric, 'minibar_main Lavie is 4 after all refills'
);

-- E. Yeu cau kiem (6).
select public._t035_as('d0350000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.minibar_request_check('d0350000-0000-4000-8000-000000000c01')$q$,
  '42501', 'ERR_FORBIDDEN:minibar.request_check',
  'viewer cannot request minibar check'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.minibar_request_check('d0350000-0000-4000-8000-000000000999')$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'request_check rejects unknown room'
);
insert into t035_ctx values ('chk101', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c01'
)));
select is(
  (select resp ->> 'status' from t035_ctx where key = 'chk101'),
  'pending_charge', 'request_check room 101 creates pending_charge check'
);
select is(
  (select resp ->> 'existing' from t035_ctx where key = 'chk101'),
  'false', 'first request_check is not existing'
);
select is(
  (select public.minibar_request_check(
    'd0350000-0000-4000-8000-000000000c01'
  ) ->> 'existing'),
  'true', 'second request_check returns existing open check'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a01');
select is(
  (select count(*) from public.alerts
   where code = 'MINIBAR_CHECK_REQUESTED'
     and property_id = 'd0350000-0000-4000-8000-000000000201'),
  1::bigint, 'request_check creates exactly one housekeeping alert'
);

-- F. Nop kiem (15).
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk101'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}]'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.check',
  'frontdesk cannot submit minibar check'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('chk103', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c04'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk103'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000503", "missing_qty": 1}]'::jsonb
  )$q$,
  'P0001', 'ERR_PRICE_NOT_SET',
  'submit_check rejects Coca with expired price'
);
select throws_ok(
  $q$select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk103'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000504", "missing_qty": 1}]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'submit_check rejects Dasani (complimentary, never charged)'
);
select throws_ok(
  $q$select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk103'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 0}]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'submit_check rejects zero missing_qty'
);
select throws_ok(
  $q$select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk103'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}, {"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'submit_check rejects duplicate item'
);

-- 11-TESTING §4.2: thieu 1 Lavie, 1 Tiger -> tong = gia Lavie + gia Tiger.
insert into t035_ctx values ('sub101', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'chk101'),
  '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}, {"item_id": "d0350000-0000-4000-8000-000000000502", "missing_qty": 1}]'::jsonb,
  'd0350000-0000-4000-8000-000000000f01'
)));
select is(
  (select (resp ->> 'total_amount')::numeric from t035_ctx where key = 'sub101'),
  60000::numeric, 'check 101 total = 25000 Lavie + 35000 Tiger'
);
select is(
  (select count(*) from public.minibar_check_lines
   where check_id = (select id from t035_ctx where key = 'chk101')),
  2::bigint, 'check 101 has 2 lines'
);
select is(
  (select amount from public.minibar_check_lines
   where check_id = (select id from t035_ctx where key = 'chk101')
     and item_id = 'd0350000-0000-4000-8000-000000000501'),
  25000::numeric, 'Lavie line amount is 25000'
);
select throws_ok(
  $q$select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk101'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}]'::jsonb,
    'd0350000-0000-4000-8000-000000000f02'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'resubmit with new client_uuid is rejected'
);

-- Idempotency: nop lai cung client_uuid -> tra ket qua cu, khong ghi them dong.
insert into t035_ctx values ('chk102', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c02', 'daily'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
insert into t035_ctx values ('sub102', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'chk102'),
  '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}]'::jsonb,
  'd0350000-0000-4000-8000-000000000f03'
)));
select is(
  (select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk102'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}]'::jsonb,
    'd0350000-0000-4000-8000-000000000f03'
  ) ->> 'duplicate'),
  'true', 'same client_uuid returns duplicate=true'
);
select is(
  (select count(*) from public.minibar_check_lines
   where check_id = (select id from t035_ctx where key = 'chk102')),
  1::bigint, 'duplicate submit creates no extra line'
);

-- Nop kiem phong 103 (1 Lavie, co near_expiry).
insert into t035_ctx values ('sub103', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'chk103'),
  '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1, "near_expiry": true}]'::jsonb,
  'd0350000-0000-4000-8000-000000000f04'
)));
select is(
  (select (resp ->> 'total_amount')::numeric from t035_ctx where key = 'sub103'),
  25000::numeric, 'check 103 total is 25000'
);
select is(
  (select near_expiry from public.minibar_check_lines
   where check_id = (select id from t035_ctx where key = 'chk103')),
  true, 'check 103 line keeps near_expiry flag'
);

-- G. Xac nhan thu + folio (8).
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.minibar_confirm_charge(
    (select id from t035_ctx where key = 'chk101'), 'FOL-001'
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.charge.confirm',
  'housekeeping cannot confirm charge'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.minibar_confirm_charge(
    (select id from t035_ctx where key = 'chk101'), ''
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'confirm_charge rejects empty folio_no'
);

-- 11-TESTING §4.3: xac nhan thu + folio -> move minibar_sale; kho phong con 1+1.
insert into t035_ctx values ('chg101', null, (select public.minibar_confirm_charge(
  (select id from t035_ctx where key = 'chk101'), 'FOL-001'
)));
select is(
  (select resp ->> 'status' from t035_ctx where key = 'chg101'),
  'charged', 'check 101 becomes charged after confirm'
);
select is(
  (select count(*) from public.stock_moves
   where source_doc_type = 'minibar_check'
     and source_doc_id = (select id from t035_ctx where key = 'chk101')
     and move_type = 'minibar_sale'),
  2::bigint, 'confirm posts 2 minibar_sale moves'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000304'
     and item_id = 'd0350000-0000-4000-8000-000000000501' and lot_id is null),
  1::numeric, 'room 101 Lavie left is 1 after charge'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where warehouse_id = 'd0350000-0000-4000-8000-000000000304'
     and item_id = 'd0350000-0000-4000-8000-000000000502' and lot_id is null),
  1::numeric, 'room 101 Tiger left is 1 after charge'
);
select is(
  (select qty_on_hand from public.item_costs
   where legal_entity_id = 'd0350000-0000-4000-8000-000000000101'
     and item_id = 'd0350000-0000-4000-8000-000000000501'),
  9::numeric, 'item_costs Lavie qty_on_hand drops 10 -> 9 after sale'
);
select throws_ok(
  $q$select public.minibar_confirm_charge(
    (select id from t035_ctx where key = 'chk101'), 'FOL-002'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'confirming an already charged check is rejected'
);

-- H. Mien: de nghi + gm duyet + SoD + tu choi (10).
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.minibar_request_waive(
    (select id from t035_ctx where key = 'chk102'), ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'request_waive rejects empty reason'
);
select is(
  (select public.minibar_request_waive(
    (select id from t035_ctx where key = 'chk102'), 'Khách VIP'
  ) ->> 'ok'),
  'true', 'frontdesk requests waive for check 102'
);
select throws_ok(
  $q$select public.minibar_decide_waive(
    (select id from t035_ctx where key = 'chk102'), 'approved'
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.waive.approve',
  'frontdesk cannot approve own waive request'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a01');
select is(
  (select public.minibar_request_waive(
    (select id from t035_ctx where key = 'chk103'), 'Lỗi phòng'
  ) ->> 'ok'),
  'true', 'gm requests waive for check 103'
);
select throws_ok(
  $q$select public.minibar_decide_waive(
    (select id from t035_ctx where key = 'chk103'), 'approved'
  )$q$,
  'P0001', 'ERR_SOD_MINIBAR_WAIVE',
  'waive requester cannot approve own request (SoD)'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a06');
select is(
  (select public.minibar_decide_waive(
    (select id from t035_ctx where key = 'chk103'), 'rejected'
  ) ->> 'status'),
  'pending_charge', 'second gm rejects waive, check stays pending_charge'
);
select is(
  (select waive_requested_by from public.minibar_checks
   where id = (select id from t035_ctx where key = 'chk103')),
  null::uuid, 'rejected waive clears waive_requested_by'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select is(
  (select public.minibar_confirm_charge(
    (select id from t035_ctx where key = 'chk103'), 'FOL-003'
  ) ->> 'status'),
  'charged', 'check 103 can be charged after waive rejection'
);

-- 11-TESTING §4.5: gm duyet mien -> waived.
select public._t035_as('d0350000-0000-4000-8000-000000000a01');
select is(
  (select public.minibar_decide_waive(
    (select id from t035_ctx where key = 'chk102'), 'approved'
  ) ->> 'status'),
  'waived', 'gm approves waive for check 102'
);
select throws_ok(
  $q$select public.minibar_decide_waive(
    (select id from t035_ctx where key = 'chk101'), 'approved'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'decide_waive without pending request is rejected'
);

-- I. Late charge + write_off (10).
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('chk104a', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c05'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select is(
  (select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk104a'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}, {"item_id": "d0350000-0000-4000-8000-000000000502", "missing_qty": 1}]'::jsonb
  ) ->> 'total_amount'),
  '60000', 'check 104a total is 60000'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select is(
  (select public.minibar_mark_late_charge(
    (select id from t035_ctx where key = 'chk104a'), 'Khách đã đi, thu qua thẻ'
  ) ->> 'status'),
  'late_charge', 'check 104a becomes late_charge'
);
select is(
  (select public.minibar_confirm_charge(
    (select id from t035_ctx where key = 'chk104a'), 'FOL-004'
  ) ->> 'status'),
  'charged', 'late_charge check can still be confirmed with folio'
);

insert into t035_ctx values ('chk104b', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c05'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select is(
  (select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk104b'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}, {"item_id": "d0350000-0000-4000-8000-000000000502", "missing_qty": 1}]'::jsonb
  ) ->> 'total_amount'),
  '60000', 'check 104b total is 60000'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select is(
  (select public.minibar_mark_late_charge(
    (select id from t035_ctx where key = 'chk104b'), 'Chưa thu được'
  ) ->> 'status'),
  'late_charge', 'check 104b stays late_charge for reconcile'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('chk105', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c02'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select is(
  (select public.minibar_submit_check(
    (select id from t035_ctx where key = 'chk105'),
    '[{"item_id": "d0350000-0000-4000-8000-000000000502", "missing_qty": 1}]'::jsonb
  ) ->> 'total_amount'),
  '35000', 'check 105 total is 35000'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.minibar_write_off(
    (select id from t035_ctx where key = 'chk105'), 'Không thu được'
  )$q$,
  '42501', 'ERR_FORBIDDEN:minibar.waive.approve',
  'frontdesk cannot write off a check'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.minibar_write_off(
    (select id from t035_ctx where key = 'chk105'), ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'write_off rejects empty reason'
);
select is(
  (select public.minibar_write_off(
    (select id from t035_ctx where key = 'chk105'), 'Khách đã về nước, không thu được'
  ) ->> 'status'),
  'written_off', 'gm writes off check 105'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.minibar_confirm_charge(
    (select id from t035_ctx where key = 'chk105'), 'FOL-005'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'confirming a written_off check is rejected'
);

-- J. Kiem dot xuat audit (8).
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('aud101', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c01', 'audit'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
insert into t035_ctx values ('subaud101', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'aud101'),
  '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 1}]'::jsonb
)));
select is(
  (select resp ->> 'status' from t035_ctx where key = 'subaud101'),
  'written_off', 'audit check with matching checkout check is written_off'
);
select is(
  (select resp ->> 'is_loss' from t035_ctx where key = 'subaud101'),
  'false', 'audit check explained by checkout check is not a loss'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('aud102', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c02', 'audit'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
insert into t035_ctx values ('subaud102', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'aud102'),
  '[{"item_id": "d0350000-0000-4000-8000-000000000502", "missing_qty": 1}]'::jsonb
)));
select is(
  (select resp ->> 'status' from t035_ctx where key = 'subaud102'),
  'written_off', 'audit check without checkout check is written_off'
);
select is(
  (select resp ->> 'is_loss' from t035_ctx where key = 'subaud102'),
  'true', 'audit check without checkout check is a loss'
);
select is(
  (select resp ->> 'trolley_shift_id' from t035_ctx where key = 'subaud102'),
  'd0350000-0000-4000-8000-000000000d01', 'loss is linked to nearest trolley shift'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a01');
select is(
  (select count(*) from public.alerts
   where code = 'MINIBAR_LOSS'
     and property_id = 'd0350000-0000-4000-8000-000000000201'),
  1::bigint, 'exactly one MINIBAR_LOSS alert exists'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('aud104', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c05', 'audit'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
insert into t035_ctx values ('subaud104', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'aud104'),
  '[]'::jsonb
)));
select is(
  (select resp ->> 'status' from t035_ctx where key = 'subaud104'),
  'pending_charge', 'audit check with no missing items stays pending_charge'
);
select is(
  (select (resp ->> 'total_amount')::numeric from t035_ctx where key = 'subaud104'),
  0::numeric, 'audit check with no missing items totals 0'
);

-- K. Doi soat ngay (9).
select public._t035_as('d0350000-0000-4000-8000-000000000a08');
insert into t035_ctx values ('rec1', null, (select public.minibar_reconcile(
  'd0350000-0000-4000-8000-000000000201'
)));
select is(
  (select (resp ->> 'diff')::numeric from t035_ctx where key = 'rec1'),
  0::numeric, 'reconcile today: recorded = charged + waived + late, diff 0'
);
select is(
  (select resp ->> 'alert_id' from t035_ctx where key = 'rec1'),
  null, 'reconcile with diff 0 creates no alert'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a04');
insert into t035_ctx values ('chk107', null, (select public.minibar_request_check(
  'd0350000-0000-4000-8000-000000000c02'
)));
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
insert into t035_ctx values ('sub107', null, (select public.minibar_submit_check(
  (select id from t035_ctx where key = 'chk107'),
  '[{"item_id": "d0350000-0000-4000-8000-000000000501", "missing_qty": 2}]'::jsonb
)));
select is(
  (select (resp ->> 'total_amount')::numeric from t035_ctx where key = 'sub107'),
  50000::numeric, 'check 107 total is 50000, left pending_charge'
);

select public._t035_as('d0350000-0000-4000-8000-000000000a08');
insert into t035_ctx values ('rec2', null, (select public.minibar_reconcile(
  'd0350000-0000-4000-8000-000000000201'
)));
select is(
  (select (resp ->> 'diff')::numeric from t035_ctx where key = 'rec2'),
  50000::numeric, 'reconcile today: pending 50000 makes diff 50000'
);
select ok(
  (select resp ->> 'alert_id' from t035_ctx where key = 'rec2') is not null,
  'reconcile with diff creates MINIBAR_MISMATCH alert'
);
insert into t035_ctx values ('rec3', null, (select public.minibar_reconcile(
  'd0350000-0000-4000-8000-000000000201'
)));
select is(
  (select resp ->> 'alert_id' from t035_ctx where key = 'rec3'),
  null, 're-reconcile same day dedupes the alert'
);
insert into t035_ctx values ('rec4', null, (select public.minibar_reconcile(
  'd0350000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
)));
select is(
  (select (resp ->> 'diff')::numeric from t035_ctx where key = 'rec4'),
  50000::numeric, 'reconcile next day: pending carried over still diffs 50000'
);
select ok(
  (select resp ->> 'alert_id' from t035_ctx where key = 'rec4') is not null,
  'reconcile next day creates a new dated MINIBAR_MISMATCH alert'
);
select is(
  (select count(*) from public.alerts
   where code = 'MINIBAR_MISMATCH'
     and property_id = 'd0350000-0000-4000-8000-000000000201'),
  2::bigint, 'two MINIBAR_MISMATCH alerts exist (today + tomorrow)'
);

-- L. Danh sach thu hoi sap het han (5).
select public._t035_as('d0350000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.minibar_recall_list('d0350000-0000-4000-8000-000000000201')$q$,
  '42501', 'ERR_FORBIDDEN:minibar_recall_list',
  'viewer cannot list recall items'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a03');
select is(
  jsonb_array_length(
    (select public.minibar_recall_list(
      'd0350000-0000-4000-8000-000000000201', 30
    ) -> 'items')),
  1, 'recall list (30 days) has exactly 1 lot'
);
select is(
  (select public.minibar_recall_list(
    'd0350000-0000-4000-8000-000000000201', 30
  ) -> 'items' -> 0 ->> 'item_code'),
  'TIGER', 'recall list item is Tiger (expires in 10 days)'
);
select is(
  jsonb_array_length(
    (select public.minibar_recall_list(
      'd0350000-0000-4000-8000-000000000201', 5
    ) -> 'items')),
  0, 'recall list (5 days) is empty'
);
select throws_ok(
  $q$select public.minibar_recall_list(
    'd0350000-0000-4000-8000-000000000201', -1
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'recall list rejects negative days'
);

-- M. RLS doc: nguoi khong co quyen minibar khong thay phieu/bang gia (3).
select public._t035_as('d0350000-0000-4000-8000-000000000a10');
select is(
  (select count(*) from public.minibar_checks),
  0::bigint, 'viewer sees 0 minibar checks'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a04');
select is(
  (select count(*) from public.minibar_checks),
  10::bigint, 'frontdesk sees all 10 minibar checks'
);
select public._t035_as('d0350000-0000-4000-8000-000000000a07');
select is(
  (select count(*) from public.minibar_price_list),
  0::bigint, 'storekeeper sees 0 minibar prices'
);

select * from finish();
rollback;
