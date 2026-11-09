-- T-012 pgTAP: CRUD qua RLS cho danh mục vật tư, kiểm tra chống trùng tên, chống xóa/đổi ĐVT khi có giao dịch.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(23);

-- 1. Setup Fixture
insert into public.organizations (id, name) values
  ('d0120000-1200-4000-8000-000000000001', 'T-012 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0120000-1200-4000-8000-000000000101', 'd0120000-1200-4000-8000-000000000001', 'T012', 'Entity T-012');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0120000-1200-4000-8000-000000000201', 'd0120000-1200-4000-8000-000000000001', 'd0120000-1200-4000-8000-000000000101', 'P012', 'Property T-012');

insert into public.warehouses (id, property_id, code, name, kind) values
  ('d0120000-1200-4000-8000-000000000301', 'd0120000-1200-4000-8000-000000000201', 'WH_MAIN', 'Kho chính T012', 'main');

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0120000-1200-4000-8000-000000000401', 'd0120000-1200-4000-8000-000000000001', 'BEV', 'Đồ uống giải khát', 'beverage');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0120000-1200-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'manager012@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0120000-1200-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer012@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.roles (id, org_id, code, name_vi) values
  ('d0120000-1200-4000-8000-000000000601', 'd0120000-1200-4000-8000-000000000001', 'r_master_mgr', 'Quản lý danh mục'),
  ('d0120000-1200-4000-8000-000000000602', 'd0120000-1200-4000-8000-000000000001', 'r_master_view', 'Xem danh mục');

insert into public.role_permissions (role_id, permission_code) values
  ('d0120000-1200-4000-8000-000000000601', 'item.view'),
  ('d0120000-1200-4000-8000-000000000601', 'item.manage'),
  ('d0120000-1200-4000-8000-000000000601', 'warehouse.manage'),
  ('d0120000-1200-4000-8000-000000000601', 'room.manage'),
  ('d0120000-1200-4000-8000-000000000602', 'item.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0120000-1200-4000-8000-000000000a01', 'd0120000-1200-4000-8000-000000000601', 'd0120000-1200-4000-8000-000000000201'),
  ('d0120000-1200-4000-8000-000000000a02', 'd0120000-1200-4000-8000-000000000602', 'd0120000-1200-4000-8000-000000000201');

-- Set actor to User 1 (Manager with item.manage)
select set_config('request.jwt.claim.sub', 'd0120000-1200-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0120000-1200-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

-- 2. Test INSERT item qua RLS
select lives_ok(
  $q$insert into public.items (
    id, org_id, code, name, group_id, stock_uom, is_key_item
  ) values (
    'd0120000-1200-4000-8000-000000000501', 'd0120000-1200-4000-8000-000000000001',
    'BEV_COCA', 'Nước ngọt Coca Cola lon', 'd0120000-1200-4000-8000-000000000401', 'lon', true
  )$q$,
  'Manager can insert new item via RLS'
);

-- 3. Test unique code
select throws_ok(
  $q$insert into public.items (
    org_id, code, name, group_id, stock_uom
  ) values (
    'd0120000-1200-4000-8000-000000000001',
    'BEV_COCA', 'Nước ngọt khác', 'd0120000-1200-4000-8000-000000000401', 'lon'
  )$q$,
  '23505', null, 'Duplicate item code is rejected by unique constraint'
);

-- 4. Test unique name_norm (chống trùng tên)
select throws_ok(
  $q$insert into public.items (
    org_id, code, name, group_id, stock_uom
  ) values (
    'd0120000-1200-4000-8000-000000000001',
    'BEV_COCA2', '  NƯỚC NGỌT   Coca cola LON ', 'd0120000-1200-4000-8000-000000000401', 'lon'
  )$q$,
  '23505', null, 'Duplicate normalized item name is rejected by unique constraint'
);

-- 5. Test UPDATE item qua RLS
select lives_ok(
  $q$update public.items set name_en = 'Coca Cola Can 330ml'
     where id = 'd0120000-1200-4000-8000-000000000501'$q$,
  'Manager can update item details via RLS'
);

select is(
  (select name_en from public.items where id = 'd0120000-1200-4000-8000-000000000501'),
  'Coca Cola Can 330ml',
  'Item name_en was updated'
);

-- 6. Switch to User 2 (Viewer without item.manage)
reset role;
select set_config('request.jwt.claim.sub', 'd0120000-1200-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0120000-1200-4000-8000-000000000a02","role":"authenticated"}', true);
set local role authenticated;

-- Viewer can select
select is(
  (select count(*) from public.items where id = 'd0120000-1200-4000-8000-000000000501'),
  1::bigint,
  'Viewer can read items'
);

-- Viewer cannot insert item
select throws_ok(
  $q$insert into public.items (
    org_id, code, name, group_id, stock_uom
  ) values (
    'd0120000-1200-4000-8000-000000000001',
    'BEV_PEPSI', 'Nước ngọt Pepsi lon', 'd0120000-1200-4000-8000-000000000401', 'lon'
  )$q$,
  '42501', null, 'Viewer without item.manage cannot insert items'
);

-- Viewer cannot update item (RLS prevents modifying row, 0 rows affected)
with upd as (
  update public.items set is_key_item = false where id = 'd0120000-1200-4000-8000-000000000501' returning id
)
select is((select count(*) from upd), 0::bigint, 'Viewer without item.manage cannot update items via RLS');

-- Viewer cannot delete item (RLS prevents deleting row, 0 rows affected)
with del as (
  delete from public.items where id = 'd0120000-1200-4000-8000-000000000501' returning id
)
select is((select count(*) from del), 0::bigint, 'Viewer without item.manage cannot delete items via RLS');

-- Switch back to Manager
reset role;
select set_config('request.jwt.claim.sub', 'd0120000-1200-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0120000-1200-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

-- 7. Test quy cách mua (item_purchase_units)
select lives_ok(
  $q$insert into public.item_purchase_units (
    org_id, item_id, uom, factor_to_stock, is_default
  ) values (
    'd0120000-1200-4000-8000-000000000001', 'd0120000-1200-4000-8000-000000000501',
    'hop', 24, true
  )$q$,
  'Manager can insert purchase unit with factor_to_stock'
);

-- 8. Test kho (warehouses CRUD)
select lives_ok(
  $q$insert into public.warehouses (
    id, property_id, code, name, kind
  ) values (
    'd0120000-1200-4000-8000-000000000302', 'd0120000-1200-4000-8000-000000000201',
    'WH_TRANSIT1', 'Kho trung chuyển 1', 'transit'
  )$q$,
  'Manager with warehouse.manage can insert warehouse'
);

select is(
  (select count(*) from public.warehouses where id = 'd0120000-1200-4000-8000-000000000302'),
  1::bigint,
  'Warehouse exists'
);

-- 9. Test phòng & loại phòng (rooms & room_types)
select lives_ok(
  $q$insert into public.room_types (
    id, property_id, code, name, max_guests
  ) values (
    'd0120000-1200-4000-8000-000000000701', 'd0120000-1200-4000-8000-000000000201',
    'DLX', 'Phòng Deluxe Hướng Biển', 2
  )$q$,
  'Manager with room.manage can insert room_type'
);

select lives_ok(
  $q$insert into public.rooms (
    id, property_id, room_type_id, room_no, floor
  ) values (
    'd0120000-1200-4000-8000-000000000711', 'd0120000-1200-4000-8000-000000000201',
    'd0120000-1200-4000-8000-000000000701', '101', '1'
  )$q$,
  'Manager with room.manage can insert room'
);

-- 10. Test outlets & outlet_types
select lives_ok(
  $q$insert into public.outlet_types (
    id, org_id, code, name
  ) values (
    'd0120000-1200-4000-8000-000000000801', 'd0120000-1200-4000-8000-000000000001',
    'BAR', 'Quầy Bar'
  )$q$,
  'Manager with warehouse.manage can insert outlet_type'
);

select lives_ok(
  $q$insert into public.outlets (
    id, property_id, outlet_type_id, code, name
  ) values (
    'd0120000-1200-4000-8000-000000000811', 'd0120000-1200-4000-8000-000000000201',
    'd0120000-1200-4000-8000-000000000801', 'POOL_BAR', 'Quầy Bar Bể Bơi'
  )$q$,
  'Manager with warehouse.manage can insert outlet'
);

-- 11. Test khoản mục chi phí (expense_categories)
select lives_ok(
  $q$insert into public.expense_categories (
    id, org_id, code, name, usali_line
  ) values (
    'd0120000-1200-4000-8000-000000000901', 'd0120000-1200-4000-8000-000000000001',
    'EXP_BEV', 'Chi phí đồ uống F&B', 'F&B Beverage'
  )$q$,
  'Manager with item.manage can insert expense category'
);

-- 12. Thử xóa vật tư CHƯA có giao dịch kho -> thành công
select lives_ok(
  $q$insert into public.items (
    id, org_id, code, name, group_id, stock_uom
  ) values (
    'd0120000-1200-4000-8000-000000000599', 'd0120000-1200-4000-8000-000000000001',
    'TEMP_DEL', 'Vật tư thử xóa', 'd0120000-1200-4000-8000-000000000401', 'lon'
  )$q$,
  'Insert temporary item for deletion'
);

select lives_ok(
  $q$delete from public.items where id = 'd0120000-1200-4000-8000-000000000599'$q$,
  'Deleting item without stock_moves succeeds'
);

-- 13. Phát sinh giao dịch kho trên BEV_COCA
reset role;
select public._post_move(
  'd0120000-1200-4000-8000-000000000101', 'd0120000-1200-4000-8000-000000000201',
  'd0120000-1200-4000-8000-000000000301', 'd0120000-1200-4000-8000-000000000501',
  null, 'receipt', 10, 10000, '2026-01-01', 'GRN', 'd0120000-1200-4000-8000-000000000999'
);

select set_config('request.jwt.claim.sub', 'd0120000-1200-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0120000-1200-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

-- Thử xóa vật tư ĐÃ CÓ giao dịch kho -> bị chặn ERR_ITEM_HAS_STOCK_MOVES
select throws_ok(
  $q$delete from public.items where id = 'd0120000-1200-4000-8000-000000000501'$q$,
  'P0001', 'ERR_ITEM_HAS_STOCK_MOVES',
  'Deleting item with stock_moves is forbidden by trigger'
);

-- Thử đổi stock_uom của vật tư ĐÃ CÓ giao dịch kho -> bị chặn ERR_ITEM_UOM_CHANGE_FORBIDDEN
select throws_ok(
  $q$update public.items set stock_uom = 'kg' where id = 'd0120000-1200-4000-8000-000000000501'$q$,
  'P0001', 'ERR_ITEM_UOM_CHANGE_FORBIDDEN',
  'Changing stock_uom of item with stock_moves is forbidden by trigger'
);

-- Đổi trạng thái status = 'inactive' của vật tư đã có giao dịch -> THÀNH CÔNG
select lives_ok(
  $q$update public.items set status = 'inactive' where id = 'd0120000-1200-4000-8000-000000000501'$q$,
  'Deactivating item with stock_moves is allowed'
);

select is(
  (select status from public.items where id = 'd0120000-1200-4000-8000-000000000501'),
  'inactive',
  'Item status is now inactive'
);

select * from finish();
rollback;
