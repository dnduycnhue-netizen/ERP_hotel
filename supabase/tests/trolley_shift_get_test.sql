-- Trolley mobile pgTAP: RPC doc 1 ca xe day `trolley_shift_get`.
-- Kiem tra: ca khong ton tai, quyen (chi hk.trolley.operate /
-- hk.standard.manage moi doc duoc), so dem dau/cuoi, phieu linh bu,
-- phieu tieu hao, bang tieu hao = dau + linh - cuoi (am clamp 0 +
-- surplus). So lieu ky vong lay tu file Amenities that ngay 9.5.2019
-- (~/workspace/user/files/...Amenities...xlsx, sheet '9.5.2019'):
-- mo ca GIAY 37 / NUOC 57 / BANCHAI 57; par 40/60/60 -> linh bu 3/3/3;
-- dong ca GIAY 9 / NUOC 12 / BANCHAI 35 -> tieu hao 31/48/25.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(37);

insert into public.organizations (id, name) values
  ('d0460000-0000-4000-8000-000000000001', 'T-046 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000001', 'T046', 'Entity T-046');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000001', 'd0460000-0000-4000-8000-000000000101', 'P0461', 'Property T-046', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('cai', 'Cái'),
  ('cuon', 'Cuộn'),
  ('chai', 'Chai')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0460000-0000-4000-8000-000000000401', 'd0460000-0000-4000-8000-000000000001', 'AMEN', 'Amenities', 'amenity');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d0460000-0000-4000-8000-000000000501', 'd0460000-0000-4000-8000-000000000001', 'ITM_BANCHAI', 'Bàn chải', 'd0460000-0000-4000-8000-000000000401', 'cai', false, false, null, array['contract', 'market'], false),
  ('d0460000-0000-4000-8000-000000000502', 'd0460000-0000-4000-8000-000000000001', 'ITM_GIAY', 'Giấy vệ sinh', 'd0460000-0000-4000-8000-000000000401', 'cuon', false, false, null, array['contract', 'market'], false),
  ('d0460000-0000-4000-8000-000000000503', 'd0460000-0000-4000-8000-000000000001', 'ITM_NUOC', 'Nước suối', 'd0460000-0000-4000-8000-000000000401', 'chai', false, false, null, array['contract', 'market'], false);

insert into public.outlet_types (id, org_id, code, name) values
  ('d0460000-0000-4000-8000-000000000801', 'd0460000-0000-4000-8000-000000000001', 'HK', 'Buồng phòng');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0460000-0000-4000-8000-000000000802', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000801', 'HK', 'Buồng phòng');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0460000-0000-4000-8000-000000000301', 'd0460000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0460000-0000-4000-8000-000000000302', 'd0460000-0000-4000-8000-000000000201', 'WH_TRANSIT', 'Kho trung chuyển', 'transit', null),
  ('d0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000201', 'WH_FLOOR1', 'Kho tầng 1', 'floor', 'd0460000-0000-4000-8000-000000000802'),
  ('d0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000201', 'WH_TROLLEY1', 'Xe đẩy 1', 'trolley', 'd0460000-0000-4000-8000-000000000802'),
  ('d0460000-0000-4000-8000-000000000305', 'd0460000-0000-4000-8000-000000000201', 'WH_TROLLEY2', 'Xe đẩy 2', 'trolley', 'd0460000-0000-4000-8000-000000000802');

insert into public.cost_centers (id, org_id, code, name) values
  ('d0460000-0000-4000-8000-000000000901', 'd0460000-0000-4000-8000-000000000001', 'ROOMS', 'Buồng phòng');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0460000-0000-4000-8000-000000000902', 'd0460000-0000-4000-8000-000000000001', 'GUEST_SUPPLIES', 'Guest supplies');

insert into public.room_types (id, property_id, code, name, max_guests) values
  ('d0460000-0000-4000-8000-000000000b01', 'd0460000-0000-4000-8000-000000000201', 'DLX', 'Deluxe', 2);

insert into public.rooms (id, property_id, room_type_id, room_no, floor) values
  ('d0460000-0000-4000-8000-000000000c01', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000b01', '101', '1');

insert into public.approval_rules (
  org_id, property_id, doc_type, min_amount, max_amount,
  item_group_id, condition, step,
  approver_role_id, approver_user_id, required_perm
) values
  ('d0460000-0000-4000-8000-000000000001', null, 'requisition', 0, null,
   null, '{}'::jsonb, 1,
   'd0460000-0000-4000-8000-000000000601', null, 'requisition.approve')
on conflict do nothing;

insert into public.item_costs (legal_entity_id, item_id, avg_cost, qty_on_hand) values
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000501', 2000, 105),
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000502', 3000, 100),
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000503', 5000, 210);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0460000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-sup046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0460000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-att046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0460000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-stk046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0460000-0000-4000-8000-000000000a10', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u10-view046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0460000-0000-4000-8000-000000000a01', 'NV04601', 'Giám sát buồng'),
  ('d0460000-0000-4000-8000-000000000a02', 'NV04602', 'Nhân viên buồng'),
  ('d0460000-0000-4000-8000-000000000a07', 'NV04607', 'Thủ kho'),
  ('d0460000-0000-4000-8000-000000000a10', 'NV04610', 'Chỉ xem')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0460000-0000-4000-8000-000000000601', 'd0460000-0000-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng'),
  ('d0460000-0000-4000-8000-000000000602', 'd0460000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng'),
  ('d0460000-0000-4000-8000-000000000607', 'd0460000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0460000-0000-4000-8000-000000000609', 'd0460000-0000-4000-8000-000000000001', 'r_view046', 'Chỉ xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0460000-0000-4000-8000-000000000601', 'hk.standard.manage'),
  ('d0460000-0000-4000-8000-000000000601', 'hk.trolley.operate'),
  ('d0460000-0000-4000-8000-000000000601', 'requisition.approve'),
  ('d0460000-0000-4000-8000-000000000601', 'requisition.receive'),
  ('d0460000-0000-4000-8000-000000000602', 'hk.trolley.operate'),
  ('d0460000-0000-4000-8000-000000000602', 'item.view'),
  ('d0460000-0000-4000-8000-000000000602', 'requisition.receive'),
  ('d0460000-0000-4000-8000-000000000607', 'requisition.issue'),
  ('d0460000-0000-4000-8000-000000000607', 'stock.view_qty'),
  ('d0460000-0000-4000-8000-000000000609', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0460000-0000-4000-8000-000000000a01', 'd0460000-0000-4000-8000-000000000601', 'd0460000-0000-4000-8000-000000000201'),
  ('d0460000-0000-4000-8000-000000000a02', 'd0460000-0000-4000-8000-000000000602', 'd0460000-0000-4000-8000-000000000201'),
  ('d0460000-0000-4000-8000-000000000a07', 'd0460000-0000-4000-8000-000000000607', 'd0460000-0000-4000-8000-000000000201'),
  ('d0460000-0000-4000-8000-000000000a10', 'd0460000-0000-4000-8000-000000000609', 'd0460000-0000-4000-8000-000000000201');

insert into public.stock_moves (legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id) values
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000501', null, 'receipt', 100, 2000, 200000, '2026-11-09', 'd0460000-0000-4000-8000-000000000a07', 'opening', 'd0460000-0000-4000-8000-000000000f01'),
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000502', null, 'receipt', 100, 3000, 300000, '2026-11-09', 'd0460000-0000-4000-8000-000000000a07', 'opening', 'd0460000-0000-4000-8000-000000000f01'),
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000503', null, 'receipt', 200, 5000, 1000000, '2026-11-09', 'd0460000-0000-4000-8000-000000000a07', 'opening', 'd0460000-0000-4000-8000-000000000f01'),
  -- Ton dau xe day 1 (muc par): phieu tieu hao khi dong ca ghi -25/-31/-48
  -- tu kho xe day; _post_move chan ton am (ERR_NEGATIVE_STOCK) nen phai
  -- co ton truoc (chi 3 cai linh bu la khong du).
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000501', null, 'receipt', 60, 2000, 120000, '2026-11-09', 'd0460000-0000-4000-8000-000000000a07', 'opening', 'd0460000-0000-4000-8000-000000000f01'),
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000502', null, 'receipt', 40, 3000, 120000, '2026-11-09', 'd0460000-0000-4000-8000-000000000a07', 'opening', 'd0460000-0000-4000-8000-000000000f01'),
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000503', null, 'receipt', 60, 5000, 300000, '2026-11-09', 'd0460000-0000-4000-8000-000000000a07', 'opening', 'd0460000-0000-4000-8000-000000000f01');

insert into public.stock_balances (warehouse_id, item_id, lot_id, qty) values
  ('d0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000501', null, 100),
  ('d0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000502', null, 100),
  ('d0460000-0000-4000-8000-000000000303', 'd0460000-0000-4000-8000-000000000503', null, 200),
  ('d0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000501', null, 60),
  ('d0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000502', null, 40),
  ('d0460000-0000-4000-8000-000000000304', 'd0460000-0000-4000-8000-000000000503', null, 60);

create temp table t046_ctx (key text primary key, id uuid);

create temp table t046_resp (key text primary key, resp jsonb);

grant all on t046_ctx, t046_resp to authenticated;

create or replace function public._t046_as(p_user uuid)
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

set local role authenticated;

-- A. Ca khong ton tai (1).
select throws_ok(
  $q$select public.trolley_shift_get('d0460000-0000-4000-8000-000000000999')$q$,
  'P0001', 'ERR_INVALID_VALUE: ca xe day khong ton tai',
  'trolley_shift_get rejects unknown shift'
);

-- B. Dat muc par xe day 1: BANCHAI 60, GIAY 40, NUOC 60 (1).
select public._t046_as('d0460000-0000-4000-8000-000000000a01');
select public.trolley_par_set(
  p_property_id := 'd0460000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0460000-0000-4000-8000-000000000304',
  p_item_id := 'd0460000-0000-4000-8000-000000000501',
  p_par_qty := 60
);
select public.trolley_par_set(
  p_property_id := 'd0460000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0460000-0000-4000-8000-000000000304',
  p_item_id := 'd0460000-0000-4000-8000-000000000502',
  p_par_qty := 40
);
select public.trolley_par_set(
  p_property_id := 'd0460000-0000-4000-8000-000000000201',
  p_trolley_warehouse_id := 'd0460000-0000-4000-8000-000000000304',
  p_item_id := 'd0460000-0000-4000-8000-000000000503',
  p_par_qty := 60
);
select is(
  (select count(*) from public.trolley_par_levels
   where trolley_warehouse_id = 'd0460000-0000-4000-8000-000000000304'),
  3::bigint, 'par levels seeded for trolley 1'
);

-- C. Mo ca 1: dem dau BANCHAI 57, GIAY 37, NUOC 57 -> linh bu 3/3/3 (3).
select public._t046_as('d0460000-0000-4000-8000-000000000a02');
insert into t046_resp values ('s1', public.trolley_shift_open(
  p_property_id := 'd0460000-0000-4000-8000-000000000201',
  p_trolley_wh := 'd0460000-0000-4000-8000-000000000304',
  p_counts := '[{"item_id": "d0460000-0000-4000-8000-000000000501", "qty": 57}, {"item_id": "d0460000-0000-4000-8000-000000000502", "qty": 37}, {"item_id": "d0460000-0000-4000-8000-000000000503", "qty": 57}]'::jsonb,
  p_shift := 'day',
  p_business_date := '2026-11-09'::date
));
select is(
  (select resp ->> 'ok' from t046_resp where key = 's1'),
  'true', 'trolley_shift_open returns ok'
);
select ok(
  (select resp ->> 'requisition_id' from t046_resp where key = 's1') is not null,
  'open creates a top-up requisition'
);
select is(
  (select (resp ->> 'top_up_lines')::integer from t046_resp where key = 's1'),
  3, 'top-up has 3 lines (par minus opening)'
);

-- D. Nguoi khong co quyen xe day khong doc duoc ca (1).
select public._t046_as('d0460000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.trolley_shift_get((select (resp ->> 'shift_id')::uuid from t046_resp where key = 's1'))$q$,
  'P0001', 'ERR_FORBIDDEN:hk.trolley.operate',
  'trolley_shift_get rejects caller without hk.trolley.operate'
);

-- E. Doc ca 1 khi dang mo (8).
select public._t046_as('d0460000-0000-4000-8000-000000000a02');
insert into t046_resp values ('g1', public.trolley_shift_get(
  (select (resp ->> 'shift_id')::uuid from t046_resp where key = 's1')
));
select is(
  (select resp ->> 'ok' from t046_resp where key = 'g1'),
  'true', 'trolley_shift_get returns ok'
);
select is(
  (select resp -> 'shift' ->> 'status' from t046_resp where key = 'g1'),
  'open', 'open shift has status open'
);
select is(
  (select resp -> 'shift' ->> 'trolley_code' from t046_resp where key = 'g1'),
  'WH_TROLLEY1', 'shift carries trolley warehouse code'
);
select is(
  (select jsonb_array_length(resp -> 'opening_counts') from t046_resp where key = 'g1'),
  3, 'opening counts has 3 lines'
);
select is(
  (select (c ->> 'qty')::numeric
   from jsonb_array_elements((select resp -> 'opening_counts' from t046_resp where key = 'g1')) c
   where c ->> 'item_code' = 'ITM_GIAY'),
  37::numeric, 'opening count GIAY is 37 (real 9.5.2019 data)'
);
select ok(
  (select resp -> 'shift' ->> 'requisition_doc_no' from t046_resp where key = 'g1') is not null,
  'open shift carries top-up requisition doc no'
);
select ok(
  (select resp ->> 'closing_counts' from t046_resp where key = 'g1') is null,
  'open shift has no closing counts yet'
);
select is(
  (select resp -> 'consumption' from t046_resp where key = 'g1'),
  '[]'::jsonb, 'open shift has no consumption yet'
);

-- F. Duyet / xuat / nhan phieu linh bu 3/3/3 (4).
select throws_ok(
  $q$select public.requisition_decide(
    'd0460000-0000-4000-8000-000000000201',
    (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1'),
    'approved',
    null
  )$q$,
  'P0001', 'ERR_SOD_REQUISITION_CREATOR_APPROVER',
  'requisition creator cannot approve own top-up requisition (SoD)'
);
select public._t046_as('d0460000-0000-4000-8000-000000000a01');
insert into t046_resp values ('r1dec', public.requisition_decide(
  'd0460000-0000-4000-8000-000000000201',
  (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1'),
  'approved',
  null
));
select is(
  (select resp ->> 'status' from t046_resp where key = 'r1dec'),
  'approved', 'supervisor approves top-up requisition'
);
insert into t046_ctx select 'r1_banchai', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1')
    and item_id = 'd0460000-0000-4000-8000-000000000501';
insert into t046_ctx select 'r1_giay', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1')
    and item_id = 'd0460000-0000-4000-8000-000000000502';
insert into t046_ctx select 'r1_nuoc', id from public.requisition_lines
  where requisition_id = (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1')
    and item_id = 'd0460000-0000-4000-8000-000000000503';
select public._t046_as('d0460000-0000-4000-8000-000000000a07');
insert into t046_resp values ('r1iss', public.requisition_issue(
  (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1'),
  (select jsonb_build_array(
    jsonb_build_object('line_id', (select id from t046_ctx where key = 'r1_banchai'), 'qty_stock', 3),
    jsonb_build_object('line_id', (select id from t046_ctx where key = 'r1_giay'), 'qty_stock', 3),
    jsonb_build_object('line_id', (select id from t046_ctx where key = 'r1_nuoc'), 'qty_stock', 3)
  ))
));
select ok(
  (select (resp ->> 'ok')::boolean from t046_resp where key = 'r1iss'),
  'storekeeper issues full top-up quantities'
);
select public._t046_as('d0460000-0000-4000-8000-000000000a02');
insert into t046_resp values ('r1rcv', public.requisition_confirm_receipt(
  (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1'),
  (select jsonb_build_array(
    jsonb_build_object('line_id', (select id from t046_ctx where key = 'r1_banchai'), 'qty_stock', 3),
    jsonb_build_object('line_id', (select id from t046_ctx where key = 'r1_giay'), 'qty_stock', 3),
    jsonb_build_object('line_id', (select id from t046_ctx where key = 'r1_nuoc'), 'qty_stock', 3)
  )),
  null
));
select is(
  (select resp ->> 'status' from t046_resp where key = 'r1rcv'),
  'received', 'top-up requisition is received'
);
-- Doc stock_moves duoi quyen thu kho (u2 khong co stock.view_qty).
select public._t046_as('d0460000-0000-4000-8000-000000000a07');
select is(
  (select sum(qty) from public.stock_moves
   where warehouse_id = 'd0460000-0000-4000-8000-000000000304'
     and move_type = 'issue_in'
     and source_doc_type = 'requisition'
     and source_doc_id = (select (resp ->> 'requisition_id')::uuid from t046_resp where key = 's1')
     and item_id = 'd0460000-0000-4000-8000-000000000503'),
  3::numeric, 'trolley received 3 NUOC from top-up'
);

-- G. Dong ca 1: dem cuoi BANCHAI 35, GIAY 9, NUOC 12 -> tieu hao 25/31/48 (3).
select public._t046_as('d0460000-0000-4000-8000-000000000a02');
insert into t046_resp values ('s1c', public.trolley_shift_close(
  p_shift_id := (select (resp ->> 'shift_id')::uuid from t046_resp where key = 's1'),
  p_counts := '[{"item_id": "d0460000-0000-4000-8000-000000000501", "qty": 35}, {"item_id": "d0460000-0000-4000-8000-000000000502", "qty": 9}, {"item_id": "d0460000-0000-4000-8000-000000000503", "qty": 12}]'::jsonb,
  p_rooms_done := '[{"room_id": "d0460000-0000-4000-8000-000000000c01", "clean_type": "checkout", "guests": 2}]'::jsonb
));
select is(
  (select resp ->> 'ok' from t046_resp where key = 's1c'),
  'true', 'trolley_shift_close returns ok'
);
select is(
  (select (resp ->> 'consumption_lines')::integer from t046_resp where key = 's1c'),
  3, 'close computes 3 consumption lines'
);
select ok(
  (select resp ->> 'purpose_issue_id' from t046_resp where key = 's1c') is not null,
  'close creates a purpose_issue'
);

-- H. Doc ca 1 sau khi dong (11).
insert into t046_resp values ('g2', public.trolley_shift_get(
  (select (resp ->> 'shift_id')::uuid from t046_resp where key = 's1')
));
select is(
  (select resp -> 'shift' ->> 'status' from t046_resp where key = 'g2'),
  'closed', 'closed shift has status closed'
);
select is(
  (select jsonb_array_length(resp -> 'closing_counts') from t046_resp where key = 'g2'),
  3, 'closing counts has 3 lines'
);
select is(
  (select (c ->> 'qty')::numeric
   from jsonb_array_elements((select resp -> 'closing_counts' from t046_resp where key = 'g2')) c
   where c ->> 'item_code' = 'ITM_GIAY'),
  9::numeric, 'closing count GIAY is 9 (real 9.5.2019 data)'
);
select is(
  (select jsonb_array_length(resp -> 'consumption') from t046_resp where key = 'g2'),
  3, 'consumption has 3 lines'
);
select is(
  (select (c ->> 'consumed_qty')::numeric
   from jsonb_array_elements((select resp -> 'consumption' from t046_resp where key = 'g2')) c
   where c ->> 'item_code' = 'ITM_GIAY'),
  31::numeric, 'consumed GIAY is 37 + 3 - 9 = 31'
);
select is(
  (select (c ->> 'consumed_qty')::numeric
   from jsonb_array_elements((select resp -> 'consumption' from t046_resp where key = 'g2')) c
   where c ->> 'item_code' = 'ITM_NUOC'),
  48::numeric, 'consumed NUOC is 57 + 3 - 12 = 48'
);
select is(
  (select (c ->> 'consumed_qty')::numeric
   from jsonb_array_elements((select resp -> 'consumption' from t046_resp where key = 'g2')) c
   where c ->> 'item_code' = 'ITM_BANCHAI'),
  25::numeric, 'consumed BANCHAI is 57 + 3 - 35 = 25'
);
select is(
  (select (c ->> 'received_qty')::numeric
   from jsonb_array_elements((select resp -> 'consumption' from t046_resp where key = 'g2')) c
   where c ->> 'item_code' = 'ITM_NUOC'),
  3::numeric, 'received NUOC is 3 (top-up issue_in)'
);
select ok(
  (select resp -> 'shift' ->> 'purpose_issue_doc_no' from t046_resp where key = 'g2') is not null,
  'closed shift carries purpose_issue doc no'
);
-- Doc purpose_issues duoi quyen thu kho (u2 khong co stock.view_qty).
select public._t046_as('d0460000-0000-4000-8000-000000000a07');
select is(
  (select purpose_code from public.purpose_issues
   where id = (select (resp ->> 'purpose_issue_id')::uuid from t046_resp where key = 's1c')),
  'housekeeping', 'consumption purpose_issue code is housekeeping'
);
select public._t046_as('d0460000-0000-4000-8000-000000000a02');
select is(
  (select (r ->> 'room_id')
   from jsonb_array_elements((select resp -> 'shift' -> 'rooms_done' from t046_resp where key = 'g2')) r
   limit 1),
  'd0460000-0000-4000-8000-000000000c01', 'rooms_done keeps room 101'
);

-- I. Ca thua hang: mo NUOC 10, dong NUOC 15 -> tieu hao 0, thua 5 (4).
insert into t046_resp values ('s2', public.trolley_shift_open(
  p_property_id := 'd0460000-0000-4000-8000-000000000201',
  p_trolley_wh := 'd0460000-0000-4000-8000-000000000305',
  p_counts := '[{"item_id": "d0460000-0000-4000-8000-000000000503", "qty": 10}]'::jsonb,
  p_shift := 'day',
  p_business_date := '2026-11-09'::date
));
select is(
  (select resp ->> 'ok' from t046_resp where key = 's2'),
  'true', 'second trolley opens without par levels'
);
insert into t046_resp values ('s2c', public.trolley_shift_close(
  p_shift_id := (select (resp ->> 'shift_id')::uuid from t046_resp where key = 's2'),
  p_counts := '[{"item_id": "d0460000-0000-4000-8000-000000000503", "qty": 15}]'::jsonb,
  p_rooms_done := '[]'::jsonb
));
select is(
  (select resp ->> 'ok' from t046_resp where key = 's2c'),
  'true', 'surplus shift closes ok'
);
insert into t046_resp values ('g3', public.trolley_shift_get(
  (select (resp ->> 'shift_id')::uuid from t046_resp where key = 's2')
));
select is(
  (select (c ->> 'consumed_qty')::numeric
   from jsonb_array_elements((select resp -> 'consumption' from t046_resp where key = 'g3')) c
   where c ->> 'item_code' = 'ITM_NUOC'),
  0::numeric, 'surplus close consumes 0 (clamped)'
);
select is(
  (select (c ->> 'surplus_qty')::numeric
   from jsonb_array_elements((select resp -> 'consumption' from t046_resp where key = 'g3')) c
   where c ->> 'item_code' = 'ITM_NUOC'),
  5::numeric, 'surplus close reports surplus 5'
);

rollback;
