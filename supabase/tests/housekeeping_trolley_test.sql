-- T-034 pgTAP: chuan setup, par xe day, mo/dong ca xe day.
-- Kiem tra: RLS 3 bang moi, write-guard trolley_shifts, RPC quan ly chuan/par
-- (validate + upsert + quyen), mo ca sinh phieu linh bu toi par, duyet/xuat/
-- nhan phieu linh theo luong T-030, dong ca tinh dung tieu hao = dau + linh
-- - cuoi va sinh purpose_issue (Rooms / Guest supplies / 'housekeeping'),
-- dem mu (book_qty NULL), tieu hao am bi clamp + surplus_lines, SoD/quyen.
-- Ton kho dau: kho tang BANCHAI 100, GIAY 100, NUOC 200, CAPHE 100;
-- xe day TROLLEY1: BANCHAI 5, NUOC 10.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(93);

insert into public.organizations (id, name) values
  ('d0340000-0000-4000-8000-000000000001', 'T-034 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000001', 'T034', 'Entity T-034'),
  ('d0340000-0000-4000-8000-000000000102', 'd0340000-0000-4000-8000-000000000001', 'T034B', 'Entity T-034 B');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'P0341', 'Property T-034', 'with_cc'),
  ('d0340000-0000-4000-8000-000000000202', 'd0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000102', 'P0342', 'Property T-034 B', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('cai', 'Cái'),
  ('cuon', 'Cuộn'),
  ('chai', 'Chai'),
  ('goi', 'Gói')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0340000-0000-4000-8000-000000000401', 'd0340000-0000-4000-8000-000000000001', 'AMEN', 'Amenities', 'amenity'),
  ('d0340000-0000-4000-8000-000000000402', 'd0340000-0000-4000-8000-000000000001', 'COMP', 'Complimentary', 'complimentary');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp, temp_created_at) values
  ('d0340000-0000-4000-8000-000000000501', 'd0340000-0000-4000-8000-000000000001', 'ITM_BANCHAI', 'Bàn chải', 'd0340000-0000-4000-8000-000000000401', 'cai', false, false, null, array['contract', 'market'], false, null),
  ('d0340000-0000-4000-8000-000000000502', 'd0340000-0000-4000-8000-000000000001', 'ITM_GIAY', 'Giấy vệ sinh', 'd0340000-0000-4000-8000-000000000401', 'cuon', false, false, null, array['contract', 'market'], false, null),
  ('d0340000-0000-4000-8000-000000000503', 'd0340000-0000-4000-8000-000000000001', 'ITM_NUOC', 'Nước suối', 'd0340000-0000-4000-8000-000000000402', 'chai', false, false, null, array['contract', 'market'], false, null),
  ('d0340000-0000-4000-8000-000000000504', 'd0340000-0000-4000-8000-000000000001', 'ITM_CAPHE', 'Cà phê gói', 'd0340000-0000-4000-8000-000000000402', 'goi', false, false, null, array['contract', 'market'], false, null),
  ('d0340000-0000-4000-8000-000000000505', 'd0340000-0000-4000-8000-000000000001', 'TMP-034-1', 'Mã tạm 1', 'd0340000-0000-4000-8000-000000000401', 'cai', false, false, null, array['contract', 'market'], true, now());

insert into public.outlet_types (id, org_id, code, name) values
  ('d0340000-0000-4000-8000-000000000801', 'd0340000-0000-4000-8000-000000000001', 'HK', 'Buồng phòng');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0340000-0000-4000-8000-000000000802', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000801', 'HK', 'Buồng phòng');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0340000-0000-4000-8000-000000000301', 'd0340000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0340000-0000-4000-8000-000000000302', 'd0340000-0000-4000-8000-000000000201', 'WH_TRANSIT', 'Kho trung chuyển', 'transit', null),
  ('d0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000201', 'WH_FLOOR1', 'Kho tầng 1', 'floor', 'd0340000-0000-4000-8000-000000000802'),
  ('d0340000-0000-4000-8000-000000000304', 'd0340000-0000-4000-8000-000000000201', 'WH_TROLLEY1', 'Xe đẩy 1', 'trolley', 'd0340000-0000-4000-8000-000000000802'),
  ('d0340000-0000-4000-8000-000000000305', 'd0340000-0000-4000-8000-000000000201', 'WH_TROLLEY2', 'Xe đẩy 2', 'trolley', 'd0340000-0000-4000-8000-000000000802');

insert into public.cost_centers (id, org_id, code, name) values
  ('d0340000-0000-4000-8000-000000000901', 'd0340000-0000-4000-8000-000000000001', 'ROOMS', 'Buồng phòng');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0340000-0000-4000-8000-000000000902', 'd0340000-0000-4000-8000-000000000001', 'GUEST_SUPPLIES', 'Guest supplies');

insert into public.room_types (id, property_id, code, name, max_guests) values
  ('d0340000-0000-4000-8000-000000000b01', 'd0340000-0000-4000-8000-000000000201', 'DLX', 'Deluxe', 2),
  ('d0340000-0000-4000-8000-000000000b02', 'd0340000-0000-4000-8000-000000000202', 'STD', 'Standard', 2);

insert into public.rooms (id, property_id, room_type_id, room_no, floor) values
  ('d0340000-0000-4000-8000-000000000c01', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000b01', '101', '1');

insert into public.roles (id, org_id, code, name_vi) values
  ('d0340000-0000-4000-8000-000000000601', 'd0340000-0000-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng'),
  ('d0340000-0000-4000-8000-000000000602', 'd0340000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng'),
  ('d0340000-0000-4000-8000-000000000607', 'd0340000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0340000-0000-4000-8000-000000000609', 'd0340000-0000-4000-8000-000000000001', 'r_view034', 'Chỉ xem');

insert into public.approval_rules (
  org_id, property_id, doc_type, min_amount, max_amount,
  item_group_id, condition, step,
  approver_role_id, approver_user_id, required_perm
) values
  ('d0340000-0000-4000-8000-000000000001', null, 'requisition', 0, null,
   null, '{}'::jsonb, 1,
   'd0340000-0000-4000-8000-000000000601', null, 'requisition.approve')
on conflict do nothing;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0340000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-sup034@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0340000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-att034@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0340000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-stk034@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0340000-0000-4000-8000-000000000a10', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u10-view034@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0340000-0000-4000-8000-000000000a01', 'NV03401', 'Giám sát buồng'),
  ('d0340000-0000-4000-8000-000000000a02', 'NV03402', 'Nhân viên buồng'),
  ('d0340000-0000-4000-8000-000000000a07', 'NV03407', 'Thủ kho'),
  ('d0340000-0000-4000-8000-000000000a10', 'NV03410', 'Chỉ xem')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.role_permissions (role_id, permission_code) values
  ('d0340000-0000-4000-8000-000000000601', 'hk.standard.manage'),
  ('d0340000-0000-4000-8000-000000000601', 'hk.trolley.operate'),
  ('d0340000-0000-4000-8000-000000000601', 'requisition.approve'),
  ('d0340000-0000-4000-8000-000000000601', 'requisition.receive'),
  ('d0340000-0000-4000-8000-000000000601', 'count.view_variance'),
  ('d0340000-0000-4000-8000-000000000602', 'hk.trolley.operate'),
  ('d0340000-0000-4000-8000-000000000602', 'requisition.receive'),
  ('d0340000-0000-4000-8000-000000000607', 'requisition.issue'),
  ('d0340000-0000-4000-8000-000000000607', 'stock.view_qty'),
  ('d0340000-0000-4000-8000-000000000607', 'item.view'),
  ('d0340000-0000-4000-8000-000000000609', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0340000-0000-4000-8000-000000000a01', 'd0340000-0000-4000-8000-000000000601', 'd0340000-0000-4000-8000-000000000201'),
  ('d0340000-0000-4000-8000-000000000a02', 'd0340000-0000-4000-8000-000000000602', 'd0340000-0000-4000-8000-000000000201'),
  -- u2 them vai giam sat de §G SoD chay toi _sod_check: _decide_approval
  -- require_perm(requisition.approve) + _approval_can_decide (role 601)
  -- truoc khi kiem SoD, nen nguoi tao (u2) phai dong thoi la approver.
  ('d0340000-0000-4000-8000-000000000a02', 'd0340000-0000-4000-8000-000000000601', 'd0340000-0000-4000-8000-000000000201'),
  ('d0340000-0000-4000-8000-000000000a07', 'd0340000-0000-4000-8000-000000000607', 'd0340000-0000-4000-8000-000000000201'),
  ('d0340000-0000-4000-8000-000000000a10', 'd0340000-0000-4000-8000-000000000609', 'd0340000-0000-4000-8000-000000000201');

insert into public.stock_moves (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id) values
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000501', null, 'receipt', 100, 2000, 200000, '2026-11-09', 'd0340000-0000-4000-8000-000000000a07', 'opening', 'd0340000-0000-4000-8000-000000000f01'),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000502', null, 'receipt', 100, 3000, 300000, '2026-11-09', 'd0340000-0000-4000-8000-000000000a07', 'opening', 'd0340000-0000-4000-8000-000000000f01'),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000503', null, 'receipt', 200, 5000, 1000000, '2026-11-09', 'd0340000-0000-4000-8000-000000000a07', 'opening', 'd0340000-0000-4000-8000-000000000f01'),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000504', null, 'receipt', 100, 8000, 800000, '2026-11-09', 'd0340000-0000-4000-8000-000000000a07', 'opening', 'd0340000-0000-4000-8000-000000000f01'),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000304', 'd0340000-0000-4000-8000-000000000501', null, 'receipt', 5, 2000, 10000, '2026-11-09', 'd0340000-0000-4000-8000-000000000a07', 'opening', 'd0340000-0000-4000-8000-000000000f01'),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000304', 'd0340000-0000-4000-8000-000000000503', null, 'receipt', 10, 5000, 50000, '2026-11-09', 'd0340000-0000-4000-8000-000000000a07', 'opening', 'd0340000-0000-4000-8000-000000000f01');

insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000501', null, 100),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000502', null, 100),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000503', null, 200),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000303', 'd0340000-0000-4000-8000-000000000504', null, 100),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000304', 'd0340000-0000-4000-8000-000000000501', null, 5),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000201', 'd0340000-0000-4000-8000-000000000304', 'd0340000-0000-4000-8000-000000000503', null, 10);

insert into public.item_costs (org_id, legal_entity_id, item_id, avg_cost, qty_on_hand) values
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000501', 2000, 105),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000502', 3000, 100),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000503', 5000, 210),
  ('d0340000-0000-4000-8000-000000000001', 'd0340000-0000-4000-8000-000000000101', 'd0340000-0000-4000-8000-000000000504', 8000, 100);

create temp table t034_ctx (key text primary key, id uuid);

create temp table t034_resp (key text primary key, resp jsonb);

grant all on t034_ctx, t034_resp to authenticated;

create or replace function public._t034_as(p_user uuid)
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
  (select relrowsecurity from pg_class where relname = 'room_setup_standards'),
  true, 'room_setup_standards has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'trolley_par_levels'),
  true, 'trolley_par_levels has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'trolley_shifts'),
  true, 'trolley_shifts has RLS enabled'
);

-- B. Write-guard trolley_shifts (1).
select throws_ok(
  $q$insert into public.trolley_shifts (org_id, legal_entity_id, property_id, trolley_warehouse_id, attendant_id, business_date, shift, status) values (
    'd0340000-0000-4000-8000-000000000001',
    'd0340000-0000-4000-8000-000000000101',
    'd0340000-0000-4000-8000-000000000201',
    'd0340000-0000-4000-8000-000000000304',
    'd0340000-0000-4000-8000-000000000a02',
    '2026-11-09', 'day', 'open'
  )$q$,
  'P0001', 'ERR_WRITE_GUARD: trolley_shifts chi duoc ghi qua RPC',
  'Direct trolley_shifts insert is blocked by write guard'
);

set local role authenticated;

-- C. room_setup_standard_set (10).
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.room_setup_standard_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
    p_clean_type := 'sai',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_qty := 1
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: clean_type khong hop le',
  'room_setup_standard_set rejects bad clean_type'
);
select throws_ok(
  $q$select public.room_setup_standard_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
    p_clean_type := 'checkout',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_qty := -1
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: qty khong duoc am',
  'room_setup_standard_set rejects negative qty'
);
select throws_ok(
  $q$select public.room_setup_standard_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
    p_clean_type := 'checkout',
    p_item_id := 'd0340000-0000-4000-8000-000000000505',
    p_qty := 1
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: khong dung ma tam lam chuan setup',
  'room_setup_standard_set rejects temp item'
);
select throws_ok(
  $q$select public.room_setup_standard_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_room_type_id := 'd0340000-0000-4000-8000-000000000b02',
    p_clean_type := 'checkout',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_qty := 1
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: room_type khong thuoc property',
  'room_setup_standard_set rejects room_type of another property'
);
insert into t034_resp values ('std1', public.room_setup_standard_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
  p_clean_type := 'checkout',
  p_item_id := 'd0340000-0000-4000-8000-000000000501',
  p_qty := 1,
  p_per_guest := false
));
select is(
  (select resp ->> 'ok' from t034_resp where key = 'std1'),
  'true', 'room_setup_standard_set returns ok'
);
select is(
  (select qty from public.room_setup_standards
   where room_type_id = 'd0340000-0000-4000-8000-000000000b01'
     and clean_type = 'checkout'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and per_guest = false),
  1::numeric, 'standard row stored with qty 1'
);
insert into t034_resp values ('std1b', public.room_setup_standard_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
  p_clean_type := 'checkout',
  p_item_id := 'd0340000-0000-4000-8000-000000000501',
  p_qty := 2,
  p_per_guest := false
));
select is(
  (select qty from public.room_setup_standards
   where room_type_id = 'd0340000-0000-4000-8000-000000000b01'
     and clean_type = 'checkout'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and per_guest = false),
  2::numeric, 'standard upsert updates qty to 2'
);
select is(
  (select count(*) from public.room_setup_standards
   where room_type_id = 'd0340000-0000-4000-8000-000000000b01'
     and clean_type = 'checkout'
     and item_id = 'd0340000-0000-4000-8000-000000000501'),
  1::bigint, 'standard upsert does not duplicate the row'
);
insert into t034_resp values ('std2', public.room_setup_standard_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
  p_clean_type := 'checkout',
  p_item_id := 'd0340000-0000-4000-8000-000000000503',
  p_qty := 2,
  p_per_guest := false
));
insert into t034_resp values ('std3', public.room_setup_standard_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
  p_clean_type := 'stayover',
  p_item_id := 'd0340000-0000-4000-8000-000000000503',
  p_qty := 1,
  p_per_guest := true
));
select is(
  (select count(*) from public.room_setup_standards
   where room_type_id = 'd0340000-0000-4000-8000-000000000b01'
     and item_id = 'd0340000-0000-4000-8000-000000000503'),
  2::bigint, 'same item can have per-room and per-guest standards'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.room_setup_standard_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_room_type_id := 'd0340000-0000-4000-8000-000000000b01',
    p_clean_type := 'checkout',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_qty := 1
  )$q$,
  '42501', 'ERR_FORBIDDEN:hk.standard.manage',
  'viewer cannot set room setup standard'
);

-- D. trolley_par_set (7).
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.trolley_par_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000301',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_par_qty := 20
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: kho xe day khong ton tai hoac sai kind',
  'trolley_par_set rejects non-trolley warehouse'
);
select throws_ok(
  $q$select public.trolley_par_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_par_qty := -1
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: par_qty khong duoc am',
  'trolley_par_set rejects negative par'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.trolley_par_set(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
    p_item_id := 'd0340000-0000-4000-8000-000000000501',
    p_par_qty := 20
  )$q$,
  '42501', 'ERR_FORBIDDEN:hk.standard.manage',
  'viewer cannot set trolley par'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
insert into t034_resp values ('par1', public.trolley_par_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
  p_item_id := 'd0340000-0000-4000-8000-000000000501',
  p_par_qty := 20
));
insert into t034_resp values ('par2', public.trolley_par_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
  p_item_id := 'd0340000-0000-4000-8000-000000000502',
  p_par_qty := 15
));
insert into t034_resp values ('par3', public.trolley_par_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
  p_item_id := 'd0340000-0000-4000-8000-000000000503',
  p_par_qty := 30
));
insert into t034_resp values ('par4', public.trolley_par_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
  p_item_id := 'd0340000-0000-4000-8000-000000000504',
  p_par_qty := 10
));
select is(
  (select count(*) from public.trolley_par_levels
   where trolley_warehouse_id = 'd0340000-0000-4000-8000-000000000304'),
  4::bigint, '4 par levels stored for TROLLEY1'
);
select is(
  (select par_qty from public.trolley_par_levels
   where trolley_warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000501'),
  20::numeric, 'BANCHAI par is 20'
);
insert into t034_resp values ('par1b', public.trolley_par_set(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0340000-0000-4000-8000-000000000304',
  p_item_id := 'd0340000-0000-4000-8000-000000000501',
  p_par_qty := 20
));
select is(
  (select count(*) from public.trolley_par_levels
   where trolley_warehouse_id = 'd0340000-0000-4000-8000-000000000304'),
  4::bigint, 'par upsert does not duplicate rows'
);
select is(
  (select par_qty from public.trolley_par_levels
   where trolley_warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000501'),
  20::numeric, 'par upsert keeps par 20'
);

-- E. Mo ca 1: dem dau BANCHAI 5, NUOC 10; par 20/15/30/10 -> bu 15/15/20/10 (18).
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
insert into t034_resp values ('s1', public.trolley_shift_open(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_wh := 'd0340000-0000-4000-8000-000000000304',
  p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 5}, {"item_id": "d0340000-0000-4000-8000-000000000503", "qty": 10}]'::jsonb,
  p_shift := 'day',
  p_business_date := '2026-11-09'::date
));
select is(
  (select resp ->> 'ok' from t034_resp where key = 's1'),
  'true', 'trolley_shift_open returns ok'
);
select ok(
  (select resp ->> 'requisition_id' from t034_resp where key = 's1') is not null,
  'open creates a top-up requisition'
);
select is(
  (select (resp ->> 'top_up_lines')::integer from t034_resp where key = 's1'),
  4, 'top-up has 4 lines (par minus opening)'
);
select is(
  (select status from public.requisitions
   where id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')),
  'submitted', 'top-up requisition is submitted'
);
select is(
  (select from_warehouse_id from public.requisitions
   where id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')),
  'd0340000-0000-4000-8000-000000000303', 'top-up requisition is from floor warehouse'
);
select is(
  (select to_warehouse_id from public.requisitions
   where id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')),
  'd0340000-0000-4000-8000-000000000304', 'top-up requisition is to trolley warehouse'
);
select is(
  (select qty_stock from public.requisition_lines
   where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
     and item_id = 'd0340000-0000-4000-8000-000000000501'),
  15::numeric, 'top-up BANCHAI 20 par - 5 opening = 15'
);
select is(
  (select qty_stock from public.requisition_lines
   where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
     and item_id = 'd0340000-0000-4000-8000-000000000502'),
  15::numeric, 'top-up GIAY 15 par - 0 opening = 15'
);
select is(
  (select qty_stock from public.requisition_lines
   where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
     and item_id = 'd0340000-0000-4000-8000-000000000503'),
  20::numeric, 'top-up NUOC 30 par - 10 opening = 20'
);
select is(
  (select qty_stock from public.requisition_lines
   where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
     and item_id = 'd0340000-0000-4000-8000-000000000504'),
  10::numeric, 'top-up CAPHE 10 par - 0 opening = 10'
);
-- Doc dem (stock_counts/lines) chi doc duoc voi count.view_variance va
-- KHONG phai nguoi dem (u2 la counter) -> doc duoi u1 (giam sat).
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
select is(
  (select kind from public.stock_counts
   where id = (select (resp ->> 'opening_count_id')::uuid from t034_resp where key = 's1')),
  'trolley', 'opening count kind is trolley'
);
select is(
  (select status from public.stock_counts
   where id = (select (resp ->> 'opening_count_id')::uuid from t034_resp where key = 's1')),
  'submitted', 'opening count is submitted'
);
select is(
  (select count(*) from public.stock_count_lines
   where count_id = (select (resp ->> 'opening_count_id')::uuid from t034_resp where key = 's1')),
  2::bigint, 'opening count has 2 lines (only counted items)'
);
select is(
  (select final_qty from public.stock_count_lines
   where count_id = (select (resp ->> 'opening_count_id')::uuid from t034_resp where key = 's1')
     and item_id = 'd0340000-0000-4000-8000-000000000501'),
  5::numeric, 'opening count BANCHAI final_qty 5'
);
select ok(
  (select bool_and(book_qty is null) from public.stock_count_lines
   where count_id = (select (resp ->> 'opening_count_id')::uuid from t034_resp where key = 's1')),
  'opening count is blind (book_qty NULL)'
);
select is(
  (select status from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1')),
  'open', 'shift status is open'
);
select is(
  (select attendant_id from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1')),
  'd0340000-0000-4000-8000-000000000a02', 'shift attendant is the opener'
);
select is(
  (select opening_count_id::text from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1')),
  (select resp ->> 'opening_count_id' from t034_resp where key = 's1'),
  'shift links opening_count_id'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');

-- F. Mo ca: validate (8).
select throws_ok(
  $q$select public.trolley_shift_open(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_wh := 'd0340000-0000-4000-8000-000000000304',
    p_counts := '[]'::jsonb,
    p_shift := 'day',
    p_business_date := '2026-11-09'::date
  )$q$,
  'P0001', 'ERR_INVALID_STATUS: da co ca dang mo cho xe day nay',
  'cannot open a second shift for the same trolley/date/shift'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.trolley_shift_open(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_wh := 'd0340000-0000-4000-8000-000000000304',
    p_counts := '[]'::jsonb,
    p_shift := 'day',
    p_business_date := '2026-11-09'::date
  )$q$,
  '42501', 'ERR_FORBIDDEN:hk.trolley.operate',
  'viewer cannot open a trolley shift'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.trolley_shift_open(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_wh := 'd0340000-0000-4000-8000-000000000305',
    p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000999", "qty": 1}]'::jsonb,
    p_shift := 'day',
    p_business_date := '2026-11-09'::date
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: item khong ton tai hoac khac org',
  'open rejects unknown item in counts'
);
select throws_ok(
  $q$select public.trolley_shift_open(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_wh := 'd0340000-0000-4000-8000-000000000305',
    p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 1}, {"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 2}]'::jsonb,
    p_shift := 'day',
    p_business_date := '2026-11-09'::date
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: trung item_id trong p_counts',
  'open rejects duplicate item in counts'
);
select throws_ok(
  $q$select public.trolley_shift_open(
    p_property_id := 'd0340000-0000-4000-8000-000000000201',
    p_trolley_wh := 'd0340000-0000-4000-8000-000000000305',
    p_counts := '{}'::jsonb,
    p_shift := 'day',
    p_business_date := '2026-11-09'::date
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: p_counts phai la mang JSON',
  'open rejects non-array p_counts'
);
insert into t034_resp values ('sT2', public.trolley_shift_open(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_wh := 'd0340000-0000-4000-8000-000000000305',
  p_counts := '[]'::jsonb,
  p_shift := 'day',
  p_business_date := '2026-11-09'::date
));
select is(
  (select resp ->> 'ok' from t034_resp where key = 'sT2'),
  'true', 'open succeeds for trolley without par levels'
);
select ok(
  (select resp ->> 'requisition_id' from t034_resp where key = 'sT2') is null,
  'no par levels means no top-up requisition'
);
select is(
  (select (resp ->> 'top_up_lines')::integer from t034_resp where key = 'sT2'),
  0, 'no par levels means 0 top-up lines'
);

-- G. Duyet / xuat / nhan phieu linh bu cua ca 1 (12).
select throws_ok(
  $q$select public.requisition_decide(
    'd0340000-0000-4000-8000-000000000201',
    (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1'),
    'approved',
    null
  )$q$,
  'P0001', 'ERR_SOD_REQUISITION_CREATOR_APPROVER',
  'requisition creator cannot approve own top-up requisition (SoD)'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
insert into t034_resp values ('r1dec', public.requisition_decide(
  'd0340000-0000-4000-8000-000000000201',
  (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1'),
  'approved',
  null
));
select is(
  (select resp ->> 'status' from t034_resp where key = 'r1dec'),
  'approved', 'supervisor approves top-up requisition'
);
insert into t034_ctx select 'r1_banchai', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
    and item_id = 'd0340000-0000-4000-8000-000000000501';
insert into t034_ctx select 'r1_giay', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
    and item_id = 'd0340000-0000-4000-8000-000000000502';
insert into t034_ctx select 'r1_nuoc', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
    and item_id = 'd0340000-0000-4000-8000-000000000503';
insert into t034_ctx select 'r1_caphe', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1')
    and item_id = 'd0340000-0000-4000-8000-000000000504';
select public._t034_as('d0340000-0000-4000-8000-000000000a07');
insert into t034_resp values ('r1iss', public.requisition_issue(
  (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1'),
  (select jsonb_build_array(
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_banchai'), 'qty_stock', 15),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_giay'), 'qty_stock', 15),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_nuoc'), 'qty_stock', 20),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_caphe'), 'qty_stock', 10)
  ))
));
select ok(
  (select (resp ->> 'ok')::boolean from t034_resp where key = 'r1iss'),
  'storekeeper issues full top-up quantities'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000303'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  85::numeric, 'issue: floor BANCHAI balance 100 -> 85'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000302'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  15::numeric, 'issue: transit BANCHAI balance 15'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
insert into t034_resp values ('r1rcv', public.requisition_confirm_receipt(
  (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's1'),
  (select jsonb_build_array(
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_banchai'), 'qty_stock', 15),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_giay'), 'qty_stock', 15),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_nuoc'), 'qty_stock', 20),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r1_caphe'), 'qty_stock', 10)
  )),
  null
));
select ok(
  (select (resp ->> 'ok')::boolean from t034_resp where key = 'r1rcv'),
  'attendant confirms receipt of full top-up'
);
select is(
  (select resp ->> 'status' from t034_resp where key = 'r1rcv'),
  'received', 'top-up requisition is received'
);
-- Ton kho chi doc duoc voi stock.view_qty -> doc duoi u7 (thu kho).
select public._t034_as('d0340000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  20::numeric, 'trolley BANCHAI 5 + 15 = 20 after receipt'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000502'
     and lot_id is null),
  15::numeric, 'trolley GIAY 0 + 15 = 15 after receipt'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000503'
     and lot_id is null),
  30::numeric, 'trolley NUOC 10 + 20 = 30 after receipt'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000504'
     and lot_id is null),
  10::numeric, 'trolley CAPHE 0 + 10 = 10 after receipt'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000302'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  0::numeric, 'transit BANCHAI 0 after full receipt'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');

-- H. Dong ca 1: dem cuoi 12/9/18/7 -> tieu hao 8/6/12/3 (20).
insert into t034_resp values ('s1c', public.trolley_shift_close(
  p_shift_id := (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1'),
  p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 12}, {"item_id": "d0340000-0000-4000-8000-000000000502", "qty": 9}, {"item_id": "d0340000-0000-4000-8000-000000000503", "qty": 18}, {"item_id": "d0340000-0000-4000-8000-000000000504", "qty": 7}]'::jsonb,
  p_rooms_done := '[{"room_id": "d0340000-0000-4000-8000-000000000c01", "clean_type": "checkout", "guests": 2}]'::jsonb
));
select is(
  (select resp ->> 'ok' from t034_resp where key = 's1c'),
  'true', 'trolley_shift_close returns ok'
);
select is(
  (select (resp ->> 'consumption_lines')::integer from t034_resp where key = 's1c'),
  4, 'close computes 4 consumption lines'
);
select ok(
  (select resp ->> 'purpose_issue_id' from t034_resp where key = 's1c') is not null,
  'close creates a purpose_issue'
);
-- Phieu tieu hao + ton kho chi doc duoc voi stock.view_qty (u7);
-- expense_categories con doi item.view (da gan cho thu kho o fixture).
select public._t034_as('d0340000-0000-4000-8000-000000000a07');
select is(
  (select status from public.purpose_issues
   where id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')),
  'posted', 'consumption purpose_issue is posted'
);
select is(
  (select purpose_code from public.purpose_issues
   where id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')),
  'housekeeping', 'consumption purpose_issue code is housekeeping'
);
select is(
  (select cc.code from public.purpose_issues pi
   join public.cost_centers cc on cc.id = pi.cost_center_id
   where pi.id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')),
  'ROOMS', 'consumption purpose_issue cost center is ROOMS'
);
select is(
  (select ec.code from public.purpose_issues pi
   join public.expense_categories ec on ec.id = pi.expense_category_id
   where pi.id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')),
  'GUEST_SUPPLIES', 'consumption purpose_issue expense category is GUEST_SUPPLIES'
);
select is(
  (select qty from public.purpose_issue_lines
   where purpose_issue_id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')
     and item_id = 'd0340000-0000-4000-8000-000000000501'),
  8::numeric, 'consumption BANCHAI 5 + 15 - 12 = 8'
);
select is(
  (select qty from public.purpose_issue_lines
   where purpose_issue_id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')
     and item_id = 'd0340000-0000-4000-8000-000000000502'),
  6::numeric, 'consumption GIAY 0 + 15 - 9 = 6'
);
select is(
  (select qty from public.purpose_issue_lines
   where purpose_issue_id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')
     and item_id = 'd0340000-0000-4000-8000-000000000503'),
  12::numeric, 'consumption NUOC 10 + 20 - 18 = 12'
);
select is(
  (select qty from public.purpose_issue_lines
   where purpose_issue_id = (select (resp ->> 'purpose_issue_id')::uuid from t034_resp where key = 's1c')
     and item_id = 'd0340000-0000-4000-8000-000000000504'),
  3::numeric, 'consumption CAPHE 0 + 10 - 7 = 3'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  12::numeric, 'trolley BANCHAI balance 20 - 8 = 12 after close'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000502'
     and lot_id is null),
  9::numeric, 'trolley GIAY balance 15 - 6 = 9 after close'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000503'
     and lot_id is null),
  18::numeric, 'trolley NUOC balance 30 - 12 = 18 after close'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000504'
     and lot_id is null),
  7::numeric, 'trolley CAPHE balance 10 - 3 = 7 after close'
);
-- Dem dong ca doc duoi u1 nhu dem dau ca (count.view_variance, khong phai counter).
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
select ok(
  (select bool_and(book_qty is null) from public.stock_count_lines
   where count_id = (select (resp ->> 'closing_count_id')::uuid from t034_resp where key = 's1c')),
  'closing count is blind (book_qty NULL)'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
select is(
  (select status from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1')),
  'closed', 'shift status is closed'
);
select is(
  (select purpose_issue_id::text from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1')),
  (select resp ->> 'purpose_issue_id' from t034_resp where key = 's1c'),
  'shift links purpose_issue_id'
);
select is(
  (select rooms_done -> 0 ->> 'room_id' from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1')),
  'd0340000-0000-4000-8000-000000000c01', 'shift stores rooms_done'
);
select throws_ok(
  $q$select public.trolley_shift_close(
    p_shift_id := (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's1'),
    p_counts := '[]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_STATUS: ca khong o trang thai mo',
  'cannot close an already closed shift'
);

-- I. Ca 2 (ngay 2026-11-10): mo, duyet/xuat/nhan bu, dong thua hang (13).
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
insert into t034_resp values ('s2', public.trolley_shift_open(
  p_property_id := 'd0340000-0000-4000-8000-000000000201',
  p_trolley_wh := 'd0340000-0000-4000-8000-000000000304',
  p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 12}, {"item_id": "d0340000-0000-4000-8000-000000000502", "qty": 9}, {"item_id": "d0340000-0000-4000-8000-000000000503", "qty": 18}, {"item_id": "d0340000-0000-4000-8000-000000000504", "qty": 7}]'::jsonb,
  p_shift := 'day',
  p_business_date := '2026-11-10'::date
));
select is(
  (select (resp ->> 'top_up_lines')::integer from t034_resp where key = 's2'),
  4, 'shift 2 top-up has 4 lines'
);
select ok(
  (select resp ->> 'requisition_id' from t034_resp where key = 's2') is not null,
  'shift 2 creates a top-up requisition'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a01');
insert into t034_resp values ('r2dec', public.requisition_decide(
  'd0340000-0000-4000-8000-000000000201',
  (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2'),
  'approved',
  null
));
insert into t034_ctx select 'r2_banchai', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2')
    and item_id = 'd0340000-0000-4000-8000-000000000501';
insert into t034_ctx select 'r2_giay', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2')
    and item_id = 'd0340000-0000-4000-8000-000000000502';
insert into t034_ctx select 'r2_nuoc', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2')
    and item_id = 'd0340000-0000-4000-8000-000000000503';
insert into t034_ctx select 'r2_caphe', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2')
    and item_id = 'd0340000-0000-4000-8000-000000000504';
select public._t034_as('d0340000-0000-4000-8000-000000000a07');
insert into t034_resp values ('r2iss', public.requisition_issue(
  (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2'),
  (select jsonb_build_array(
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_banchai'), 'qty_stock', 8),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_giay'), 'qty_stock', 6),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_nuoc'), 'qty_stock', 12),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_caphe'), 'qty_stock', 3)
  ))
));
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
insert into t034_resp values ('r2rcv', public.requisition_confirm_receipt(
  (select (resp ->> 'requisition_id')::uuid from t034_resp where key = 's2'),
  (select jsonb_build_array(
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_banchai'), 'qty_stock', 8),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_giay'), 'qty_stock', 6),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_nuoc'), 'qty_stock', 12),
    jsonb_build_object('line_id', (select id from t034_ctx where key = 'r2_caphe'), 'qty_stock', 3)
  )),
  null
));
select is(
  (select resp ->> 'status' from t034_resp where key = 'r2rcv'),
  'received', 'shift 2 top-up requisition is received'
);
-- Ton kho doc duoi u7 (stock.view_qty).
select public._t034_as('d0340000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  20::numeric, 'trolley BANCHAI 12 + 8 = 20 before shift 2 close'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.trolley_shift_close(
    p_shift_id := (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's2'),
    p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 20}]'::jsonb,
    p_rooms_done := '[{"room_id": "d0340000-0000-4000-8000-000000000999", "clean_type": "checkout"}]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: room khong thuoc property',
  'close rejects rooms_done with unknown room'
);
select is(
  (select status from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's2')),
  'open', 'shift stays open after failed close'
);
insert into t034_resp values ('s2c', public.trolley_shift_close(
  p_shift_id := (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's2'),
  -- Dem cuoi = dau + linh (15/30/10) de tieu hao = 0, chi BANCHAI thua 5
  -- (25 - 20); dem 9/18/7 nhu ban cu se ra tieu hao 6/12/3, mau thuan
  -- voi ky vong consumption_lines = 0 + khong co purpose_issue o duoi.
  p_counts := '[{"item_id": "d0340000-0000-4000-8000-000000000501", "qty": 25}, {"item_id": "d0340000-0000-4000-8000-000000000502", "qty": 15}, {"item_id": "d0340000-0000-4000-8000-000000000503", "qty": 30}, {"item_id": "d0340000-0000-4000-8000-000000000504", "qty": 10}]'::jsonb
));
select is(
  (select resp ->> 'ok' from t034_resp where key = 's2c'),
  'true', 'shift 2 close returns ok'
);
select is(
  (select (resp ->> 'consumption_lines')::integer from t034_resp where key = 's2c'),
  0, 'negative consumption is not recorded as consumption lines'
);
select ok(
  (select resp ->> 'purpose_issue_id' from t034_resp where key = 's2c') is null,
  'no purpose_issue when all consumption is zero or negative'
);
select is(
  (select resp -> 'surplus_lines' -> 0 ->> 'item_id' from t034_resp where key = 's2c'),
  'd0340000-0000-4000-8000-000000000501', 'surplus item is BANCHAI'
);
select is(
  (select (resp -> 'surplus_lines' -> 0 ->> 'surplus_qty')::numeric from t034_resp where key = 's2c'),
  5::numeric, 'surplus BANCHAI 25 closing - 20 available = 5'
);
select is(
  (select status from public.trolley_shifts
   where id = (select (resp ->> 'shift_id')::uuid from t034_resp where key = 's2')),
  'closed', 'shift 2 status is closed'
);
-- Ton kho doc duoi u7 (stock.view_qty).
select public._t034_as('d0340000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0340000-0000-4000-8000-000000000304'
     and item_id = 'd0340000-0000-4000-8000-000000000501'
     and lot_id is null),
  20::numeric, 'trolley BANCHAI balance stays 20 (no auto-adjust on surplus)'
);
select public._t034_as('d0340000-0000-4000-8000-000000000a02');

-- J. Dong ca khong ton tai (1).
select throws_ok(
  $q$select public.trolley_shift_close(
    p_shift_id := 'd0340000-0000-4000-8000-000000000999',
    p_counts := '[]'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: ca xe day khong ton tai',
  'close rejects unknown shift'
);

select * from finish();
rollback;
