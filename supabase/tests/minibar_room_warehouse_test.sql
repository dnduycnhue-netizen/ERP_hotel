-- Minibar fix (460000) pgTAP: kho phong + kho minibar tong tu tao khi thieu.
-- Kiem tra: phong chua co kho `minibar_room` thi `minibar_request_check`
-- (le tan) / `minibar_refill` (buong) van chay duoc va kho phong duoc tu
-- tao dung quy uoc ma `MINIBAR_<so phong>`; luong day du request -> refill
-- -> submit -> confirm tru tien dung kho phong; property chua co kho nao
-- thi `_minibar_main_wh` tu tao `MINIBAR_MAIN`.
-- Fixture rieng (prefix d046) — khong dung chung fixture T-035 vi phong o
-- day CO TINH khong co kho phong truoc khi goi RPC.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(22);

insert into public.organizations (id, name) values
  ('d0460000-0000-4000-8000-000000000001', 'T-046 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000001', 'T046', 'Entity T-046'),
  ('d0460000-0000-4000-8000-000000000102', 'd0460000-0000-4000-8000-000000000001', 'T046B', 'Entity T-046 B');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000001', 'd0460000-0000-4000-8000-000000000101', 'P0461', 'Property T-046', 'with_cc'),
  ('d0460000-0000-4000-8000-000000000202', 'd0460000-0000-4000-8000-000000000001', 'd0460000-0000-4000-8000-000000000102', 'P0462', 'Property T-046 B', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('chai', 'Chai')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0460000-0000-4000-8000-000000000401', 'd0460000-0000-4000-8000-000000000001', 'MB', 'Minibar', 'minibar');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d0460000-0000-4000-8000-000000000501', 'd0460000-0000-4000-8000-000000000001', 'ITM_LAVIE', 'Nước Lavie', 'd0460000-0000-4000-8000-000000000401', 'chai', false, false, null, array['contract', 'market'], false);

insert into public.room_types (id, property_id, code, name, max_guests) values
  ('d0460000-0000-4000-8000-000000000b01', 'd0460000-0000-4000-8000-000000000201', 'DLX', 'Deluxe', 2);

-- CO TINH: 2 phong KHONG co kho minibar_room. Chi co kho minibar tong
-- cua P1 (de refill co hang); P2 khong co kho nao ca.
insert into public.rooms (id, property_id, room_type_id, room_no, floor) values
  ('d0460000-0000-4000-8000-000000000c01', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000b01', '105', '1'),
  ('d0460000-0000-4000-8000-000000000c02', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000b01', '106', '1');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id, room_id) values
  ('d0460000-0000-4000-8000-000000000301', 'd0460000-0000-4000-8000-000000000201', 'MB_MAIN', 'Kho minibar tổng', 'minibar_main', null, null);

insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d0460000-0000-4000-8000-000000000001', 'd0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000301', 'd0460000-0000-4000-8000-000000000501', null, 10);

insert into public.item_costs (legal_entity_id, org_id, item_id, avg_cost, qty_on_hand) values
  ('d0460000-0000-4000-8000-000000000101', 'd0460000-0000-4000-8000-000000000001', 'd0460000-0000-4000-8000-000000000501', 15000, 10);

insert into public.minibar_price_list (org_id, property_id, item_id, price, valid_from, valid_to) values
  ('d0460000-0000-4000-8000-000000000001', 'd0460000-0000-4000-8000-000000000201', 'd0460000-0000-4000-8000-000000000501', 25000, '2026-01-01', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0460000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-fd046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0460000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u2-hka046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0460000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u3-hks046@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0460000-0000-4000-8000-000000000a01', 'NV04601', 'Lễ tân'),
  ('d0460000-0000-4000-8000-000000000a02', 'NV04602', 'Nhân viên buồng'),
  ('d0460000-0000-4000-8000-000000000a03', 'NV04603', 'Giám sát buồng')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0460000-0000-4000-8000-000000000601', 'd0460000-0000-4000-8000-000000000001', 'front_desk', 'Lễ tân'),
  ('d0460000-0000-4000-8000-000000000602', 'd0460000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng'),
  ('d0460000-0000-4000-8000-000000000603', 'd0460000-0000-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng');

insert into public.role_permissions (role_id, permission_code) values
  ('d0460000-0000-4000-8000-000000000601', 'minibar.request_check'),
  ('d0460000-0000-4000-8000-000000000601', 'minibar.charge.confirm'),
  ('d0460000-0000-4000-8000-000000000602', 'minibar.check'),
  ('d0460000-0000-4000-8000-000000000603', 'minibar.refill');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0460000-0000-4000-8000-000000000a01', 'd0460000-0000-4000-8000-000000000601', 'd0460000-0000-4000-8000-000000000201'),
  ('d0460000-0000-4000-8000-000000000a02', 'd0460000-0000-4000-8000-000000000602', 'd0460000-0000-4000-8000-000000000201'),
  ('d0460000-0000-4000-8000-000000000a03', 'd0460000-0000-4000-8000-000000000603', 'd0460000-0000-4000-8000-000000000201');

create temp table t046_ctx (key text primary key, resp jsonb);
grant all on t046_ctx to authenticated;

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

-- A. request_check tu tao kho phong cho phong 105 (4).
select is(
  (select count(*) from public.warehouses w
   where w.room_id = 'd0460000-0000-4000-8000-000000000c01' and w.kind = 'minibar_room'),
  0::bigint, 'room 105 has no room warehouse before request_check'
);

select public._t046_as('d0460000-0000-4000-8000-000000000a01');
insert into t046_ctx values ('chk105', (select public.minibar_request_check(
  'd0460000-0000-4000-8000-000000000c01', 'checkout')));

select ok(
  ((select resp from t046_ctx where key = 'chk105') ->> 'ok')::boolean,
  'request_check succeeds for room without warehouse (was ERR_INVALID_VALUE)'
);
select is(
  (select count(*) from public.warehouses w
   where w.room_id = 'd0460000-0000-4000-8000-000000000c01' and w.kind = 'minibar_room'),
  1::bigint, 'room warehouse auto-created by request_check'
);
select is(
  (select code from public.warehouses w
   where w.room_id = 'd0460000-0000-4000-8000-000000000c01' and w.kind = 'minibar_room'),
  'MINIBAR_105', 'auto-created warehouse code is MINIBAR_105'
);

-- B. refill tu tao kho phong cho phong 106 + chuyen hang (5).
select public._t046_as('d0460000-0000-4000-8000-000000000a03');
insert into t046_ctx values ('ref106', (select public.minibar_refill(
  'd0460000-0000-4000-8000-000000000c02',
  jsonb_build_array(jsonb_build_object(
    'item_id', 'd0460000-0000-4000-8000-000000000501', 'qty', 5)))));

select ok(
  ((select resp from t046_ctx where key = 'ref106') ->> 'ok')::boolean,
  'refill succeeds for room without warehouse (was ERR_INVALID_VALUE)'
);
select is(
  (select count(*) from public.warehouses w
   where w.room_id = 'd0460000-0000-4000-8000-000000000c02' and w.kind = 'minibar_room'),
  1::bigint, 'room warehouse auto-created by refill'
);
select is(
  (select sb.qty from public.stock_balances sb
   join public.warehouses w on w.id = sb.warehouse_id
   where w.room_id = 'd0460000-0000-4000-8000-000000000c02'
     and sb.item_id = 'd0460000-0000-4000-8000-000000000501'),
  5::numeric, 'refill moved 5 Lavie into room 106 warehouse'
);

insert into t046_ctx values ('ref105', (select public.minibar_refill(
  'd0460000-0000-4000-8000-000000000c01',
  jsonb_build_array(jsonb_build_object(
    'item_id', 'd0460000-0000-4000-8000-000000000501', 'qty', 5)))));

select ok(
  ((select resp from t046_ctx where key = 'ref105') ->> 'ok')::boolean,
  'refill succeeds for room 105'
);
select is(
  (select sb.qty from public.stock_balances sb
   join public.warehouses w on w.id = sb.warehouse_id
   where w.room_id = 'd0460000-0000-4000-8000-000000000c01'
     and sb.item_id = 'd0460000-0000-4000-8000-000000000501'),
  5::numeric, 'refill moved 5 Lavie into room 105 warehouse'
);

-- C. Luong day du phong 105: kiem thieu 2 -> thu tien -> tru kho phong (5).
select public._t046_as('d0460000-0000-4000-8000-000000000a02');
insert into t046_ctx values ('sub105', (select public.minibar_submit_check(
  ((select resp from t046_ctx where key = 'chk105') ->> 'id')::uuid,
  jsonb_build_array(jsonb_build_object(
    'item_id', 'd0460000-0000-4000-8000-000000000501', 'missing_qty', 2)),
  gen_random_uuid())));

select ok(
  ((select resp from t046_ctx where key = 'sub105') ->> 'ok')::boolean,
  'submit_check succeeds on auto-created warehouse flow'
);
select is(
  (select total_amount from public.minibar_checks
   where id = ((select resp from t046_ctx where key = 'chk105') ->> 'id')::uuid),
  50000::numeric, 'submit priced 2 missing Lavie x 25000'
);

select public._t046_as('d0460000-0000-4000-8000-000000000a01');
insert into t046_ctx values ('cfm105', (select public.minibar_confirm_charge(
  ((select resp from t046_ctx where key = 'chk105') ->> 'id')::uuid, 'FOLIO-1')));

select ok(
  ((select resp from t046_ctx where key = 'cfm105') ->> 'ok')::boolean,
  'confirm_charge succeeds for room without pre-existing warehouse'
);
select is(
  (select status from public.minibar_checks
   where id = ((select resp from t046_ctx where key = 'chk105') ->> 'id')::uuid),
  'charged', 'check is charged after confirm'
);
select is(
  (select sb.qty from public.stock_balances sb
   join public.warehouses w on w.id = sb.warehouse_id
   where w.room_id = 'd0460000-0000-4000-8000-000000000c01'
     and sb.item_id = 'd0460000-0000-4000-8000-000000000501'),
  3::numeric, 'room 105 stock is 5 refilled - 2 sold = 3'
);

-- D. request_check goi lai: tra phieu cu, khong tao them kho/phieu (4).
select public._t046_as('d0460000-0000-4000-8000-000000000a01');
insert into t046_ctx values ('chk106a', (select public.minibar_request_check(
  'd0460000-0000-4000-8000-000000000c02', 'checkout')));
insert into t046_ctx values ('chk106b', (select public.minibar_request_check(
  'd0460000-0000-4000-8000-000000000c02', 'checkout')));

select is(
  ((select resp from t046_ctx where key = 'chk106a') ->> 'existing')::boolean,
  false, 'first request_check for room 106 creates new check'
);
select is(
  ((select resp from t046_ctx where key = 'chk106b') ->> 'existing')::boolean,
  true, 'second request_check for room 106 returns existing check'
);
select is(
  (select count(*) from public.minibar_checks
   where room_id = 'd0460000-0000-4000-8000-000000000c02'),
  1::bigint, 'no duplicate check created for room 106'
);
select is(
  (select count(*) from public.warehouses w
   where w.room_id = 'd0460000-0000-4000-8000-000000000c02' and w.kind = 'minibar_room'),
  1::bigint, 'still exactly one room warehouse for room 106'
);

-- E. Property chua co kho nao: helper tu tao MINIBAR_MAIN (4).
select is(
  (select count(*) from public.warehouses w
   where w.property_id = 'd0460000-0000-4000-8000-000000000202'),
  0::bigint, 'property P2 has no warehouses before'
);
select ok(
  public._minibar_main_wh('d0460000-0000-4000-8000-000000000202') is not null,
  'main warehouse auto-created for bare property'
);
select is(
  (select count(*) from public.warehouses w
   where w.property_id = 'd0460000-0000-4000-8000-000000000202' and w.kind = 'minibar_main'),
  1::bigint, 'exactly one MINIBAR_MAIN for P2'
);
select is(
  (select code from public.warehouses w
   where w.property_id = 'd0460000-0000-4000-8000-000000000202' and w.kind = 'minibar_main'),
  'MINIBAR_MAIN', 'auto-created main warehouse code is MINIBAR_MAIN'
);

select * from finish();
rollback;
