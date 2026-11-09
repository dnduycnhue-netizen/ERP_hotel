-- T-011 pgTAP: Sổ cái kho, hàm _post_move, FIFO layers, khóa ngày và đóng kỳ.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(54);

-- 1. Setup Fixture
insert into public.organizations (id, name) values
  ('d0110000-1100-4000-8000-000000000001', 'T-011 Test Org');

insert into public.legal_entities (id, org_id, code, name, costing_method) values
  ('d0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000001', 'T011A', 'Entity A (Moving Avg)', 'moving_avg'),
  ('d0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000001', 'T011B', 'Entity B (FIFO)', 'fifo');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000101', 'P011A', 'Property A'),
  ('d0110000-1100-4000-8000-000000000202', 'd0110000-1100-4000-8000-000000000001', 'd0110000-1100-4000-8000-000000000102', 'P011B', 'Property B');

insert into public.outlet_types (id, org_id, code, name) values
  ('d0110000-1100-4000-8000-000000000300', 'd0110000-1100-4000-8000-000000000001', 'FB', 'Food and Beverage');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0110000-1100-4000-8000-000000000310', 'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000300', 'KIT', 'Kitchen Outlet');

insert into public.warehouses (id, property_id, outlet_id, code, name, kind) values
  ('d0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000201', null, 'MAIN_A', 'Main Warehouse A', 'main'),
  ('d0110000-1100-4000-8000-000000000302', 'd0110000-1100-4000-8000-000000000201', 'd0110000-1100-4000-8000-000000000310', 'KIT_A', 'Kitchen Warehouse A', 'outlet'),
  ('d0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000202', null, 'MAIN_B', 'Main Warehouse B', 'main');

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0110000-1100-4000-8000-000000000401', 'd0110000-1100-4000-8000-000000000001', 'FOOD', 'Food Group', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0110000-1100-4000-8000-000000000501', 'd0110000-1100-4000-8000-000000000001', 'BEEF01', 'Thịt bò Úc test', 'd0110000-1100-4000-8000-000000000401', 'kg'),
  ('d0110000-1100-4000-8000-000000000502', 'd0110000-1100-4000-8000-000000000001', 'FISH01', 'Cá hồi tươi test FIFO', 'd0110000-1100-4000-8000-000000000401', 'kg');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0110000-1100-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin011@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0110000-1100-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer011@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.roles (id, org_id, code, name_vi) values
  ('d0110000-1100-4000-8000-000000000601', 'd0110000-1100-4000-8000-000000000001', 'r_admin', 'Role Admin'),
  ('d0110000-1100-4000-8000-000000000602', 'd0110000-1100-4000-8000-000000000001', 'r_viewer', 'Role Viewer');

insert into public.role_permissions (role_id, permission_code) values
  ('d0110000-1100-4000-8000-000000000601', 'stock.view_qty'),
  ('d0110000-1100-4000-8000-000000000601', 'stock.view_value'),
  ('d0110000-1100-4000-8000-000000000601', 'day.lock'),
  ('d0110000-1100-4000-8000-000000000601', 'day.unlock'),
  ('d0110000-1100-4000-8000-000000000601', 'period.close'),
  ('d0110000-1100-4000-8000-000000000601', 'period.reopen'),
  ('d0110000-1100-4000-8000-000000000602', 'stock.view_qty');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0110000-1100-4000-8000-000000000a01', 'd0110000-1100-4000-8000-000000000601', null),
  ('d0110000-1100-4000-8000-000000000a02', 'd0110000-1100-4000-8000-000000000602', 'd0110000-1100-4000-8000-000000000201');

-- Set actor to User 1
select set_config('request.jwt.claim.sub', 'd0110000-1100-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0110000-1100-4000-8000-000000000a01","role":"authenticated"}', true);

-- 2. Kiểm tra RLS và cấu trúc bảng
select ok((select bool_and(relrowsecurity) from pg_class where oid in (
  'public.lots'::regclass, 'public.stock_moves'::regclass, 'public.stock_balances'::regclass,
  'public.item_costs'::regclass, 'public.accounting_periods'::regclass, 'public.day_locks'::regclass,
  'public.fifo_layers'::regclass, 'public.fifo_allocations'::regclass
)), 'RLS enabled on all 8 inventory core tables');

select ok(not has_function_privilege('authenticated', 'public._post_move(uuid,uuid,uuid,uuid,uuid,text,numeric,numeric,date,text,uuid,uuid,uuid,uuid,text,bigint)', 'execute'),
  'authenticated client cannot call _post_move directly');

select ok(not has_table_privilege('authenticated', 'public.stock_moves', 'insert'),
  'authenticated client cannot insert into stock_moves directly');

-- 3. Phần A: BÌNH QUÂN GIA QUYỀN TỨC THỜI (Moving Average)
-- Ca 1.1: Nhập 10 kg @ 100.000 -> avg = 100.000, tồn = 10
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 10, 100000, '2026-01-05', 'GRN', 'd0110000-1100-4000-8000-000000000701'
  )$q$, 'Move 1: Receipt 10 kg @ 100.000 succeeds'
);

select is(
  (select avg_cost from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  100000.0000::numeric,
  'Item cost avg_cost is 100.000'
);

select is(
  (select qty from public.stock_balances where warehouse_id = 'd0110000-1100-4000-8000-000000000301' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  10.0000::numeric,
  'Stock balance in warehouse is 10'
);

-- Ca 1.2: Nhập tiếp 10 kg @ 120.000 -> avg = 110.000, tồn = 20
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 10, 120000, '2026-01-06', 'GRN', 'd0110000-1100-4000-8000-000000000702'
  )$q$, 'Move 2: Receipt 10 kg @ 120.000 succeeds'
);

select is(
  (select avg_cost from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  110000.0000::numeric,
  'Item cost avg_cost is now 110.000 (weighted average of 10@100k + 10@120k)'
);

-- Ca 1.3: Xuất 5 kg -> giá xuất tự lấy 110.000, tồn còn 15 kg
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'purpose_issue', -5, null, '2026-01-07', 'ISS', 'd0110000-1100-4000-8000-000000000703'
  )$q$, 'Move 3: Issue 5 kg succeeds'
);

select is(
  (select unit_cost from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000703'),
  110000.0000::numeric,
  'Move 3 unit_cost automatically took current avg_cost 110.000'
);

select is(
  (select amount from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000703'),
  -550000.00::numeric,
  'Move 3 amount is -550.000'
);

select is(
  (select qty from public.stock_balances where warehouse_id = 'd0110000-1100-4000-8000-000000000301' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  15.0000::numeric,
  'Stock balance in warehouse is now 15'
);

-- Ca 2: Xuất quá tồn -> chặn ERR_NEGATIVE_STOCK
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'purpose_issue', -16, null, '2026-01-08', 'ISS', 'd0110000-1100-4000-8000-000000000704'
  )$q$, 'P0001', null, 'Issue 16 kg when only 15 kg available is rejected with ERR_NEGATIVE_STOCK'
);

-- Ca 3: UPDATE / DELETE stock_moves -> chặn ERR_IMMUTABLE_LEDGER
select throws_ok(
  $q$update public.stock_moves set qty = 99 where source_doc_id = 'd0110000-1100-4000-8000-000000000701'$q$,
  '55000', null, 'Updating stock_moves is forbidden by trigger'
);

select throws_ok(
  $q$delete from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000701'$q$,
  '55000', null, 'Deleting from stock_moves is forbidden by trigger'
);

-- Ca 4: Điều chuyển nội bộ không đổi item_costs.qty_on_hand
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'issue_out', -5, null, '2026-01-09', 'REQ', 'd0110000-1100-4000-8000-000000000705'
  )$q$, 'Internal transfer issue_out succeeds'
);

select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000302', 'd0110000-1100-4000-8000-000000000501',
    null, 'issue_in', 5, null, '2026-01-09', 'REQ', 'd0110000-1100-4000-8000-000000000705'
  )$q$, 'Internal transfer issue_in succeeds'
);

select is(
  (select qty_on_hand from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  15.0000::numeric,
  'Legal entity total qty_on_hand remains 15 after internal warehouse transfer'
);

select is(
  (select qty from public.stock_balances where warehouse_id = 'd0110000-1100-4000-8000-000000000302' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  5.0000::numeric,
  'Kitchen warehouse now has 5 kg'
);

-- Ca 5: Đảo phiếu nhận Move 2 (10 kg @ 120k)
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'reversal', -10, null, '2026-01-10', 'REV', 'd0110000-1100-4000-8000-000000000706',
    null, null, null, null,
    (select id from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000702')
  )$q$, 'Reversing Move 2 succeeds'
);

select is(
  (select avg_cost from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  90000.0000::numeric,
  'Avg cost restored correctly to 90.000 after reversing 10 kg @ 120.000'
);

select is(
  (select qty_on_hand from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  5.0000::numeric,
  'qty_on_hand reduced by 10 to 5'
);

-- Đảo lần 2 cùng bút toán -> chặn ERR_ALREADY_REVERSED
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'reversal', -10, null, '2026-01-11', 'REV', 'd0110000-1100-4000-8000-000000000707',
    null, null, null, null,
    (select id from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000702')
  )$q$, '23505', null, 'Reversing the same move twice is rejected with unique constraint'
);

-- Ca 6: Trả hàng NCC (return_out) dùng đơn giá dòng nhận gốc
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 5, 80000, '2026-01-12', 'GRN', 'd0110000-1100-4000-8000-000000000708'
  )$q$, 'Receipt 5 kg @ 80.000 succeeds'
);

-- Hiện tại: 5 kg @ 90k (450k) + 5 kg @ 80k (400k) = 10 kg, tổng 850k -> avg = 85.000
select is(
  (select avg_cost from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  85000.0000::numeric,
  'Avg cost is 85.000'
);

-- Trả 2 kg theo giá gốc 80.000 -> còn 8 kg, giá trị còn 850k - 160k = 690k -> avg mới = 86.250
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'return_out', -2, 80000, '2026-01-13', 'RET', 'd0110000-1100-4000-8000-000000000709'
  )$q$, 'return_out 2 kg @ 80.000 succeeds'
);

select is(
  (select avg_cost from public.item_costs where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and item_id = 'd0110000-1100-4000-8000-000000000501'),
  86250.0000::numeric,
  'Avg cost recalculated after return to 86.250'
);

-- 4. Phần B: FIFO (Entity B, Item 2)
-- Ca FIFO 1: Nhập lớp 1: 10 kg @ 100.000 ngày 2026-02-01
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000202',
    'd0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000502',
    null, 'receipt', 10, 100000, '2026-02-01', 'GRN', 'd0110000-1100-4000-8000-000000000801'
  )$q$, 'FIFO Move 1: Receipt 10 kg @ 100.000'
);

select is(
  (select count(*) from public.fifo_layers where legal_entity_id = 'd0110000-1100-4000-8000-000000000102' and item_id = 'd0110000-1100-4000-8000-000000000502'),
  1::bigint,
  'FIFO layer 1 created'
);

-- Ca FIFO 2: Nhập lớp 2: 10 kg @ 120.000 ngày 2026-02-02
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000202',
    'd0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000502',
    null, 'receipt', 10, 120000, '2026-02-02', 'GRN', 'd0110000-1100-4000-8000-000000000802'
  )$q$, 'FIFO Move 2: Receipt 10 kg @ 120.000'
);

select is(
  (select count(*) from public.fifo_layers where legal_entity_id = 'd0110000-1100-4000-8000-000000000102' and item_id = 'd0110000-1100-4000-8000-000000000502'),
  2::bigint,
  'FIFO layer 2 created'
);

-- Ca FIFO 3: Xuất 5 kg ngày 2026-02-03 -> lấy 5 kg từ lớp 1 @ 100.000
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000202',
    'd0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000502',
    null, 'purpose_issue', -5, null, '2026-02-03', 'ISS', 'd0110000-1100-4000-8000-000000000803'
  )$q$, 'FIFO Move 3: Issue 5 kg'
);

select is(
  (select unit_cost from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000803'),
  100000.0000::numeric,
  'FIFO issue 5 kg unit_cost is exactly 100.000 from layer 1'
);

select is(
  (select qty_remaining from public.fifo_layers where stock_move_id = (select id from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000801')),
  5.0000::numeric,
  'FIFO layer 1 qty_remaining is now 5'
);

-- Ca FIFO 4: Xuất tiếp 8 kg ngày 2026-02-04 -> lấy 5 kg lớp 1 @ 100k + 3 kg lớp 2 @ 120k (tổng 860k -> đơn giá 107.500)
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000202',
    'd0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000502',
    null, 'purpose_issue', -8, null, '2026-02-04', 'ISS', 'd0110000-1100-4000-8000-000000000804'
  )$q$, 'FIFO Move 4: Issue 8 kg across layers'
);

select is(
  (select amount from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000804'),
  -860000.00::numeric,
  'FIFO issue 8 kg total amount is -860.000 (5@100k + 3@120k)'
);

select is(
  (select qty_remaining from public.fifo_layers where stock_move_id = (select id from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000801')),
  0.0000::numeric,
  'FIFO layer 1 is now fully consumed (qty_remaining = 0)'
);

select is(
  (select qty_remaining from public.fifo_layers where stock_move_id = (select id from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000802')),
  7.0000::numeric,
  'FIFO layer 2 has 7 kg remaining'
);

-- Ca FIFO 5: Chặn ghi lùi ngày (Q12)
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000202',
    'd0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000502',
    null, 'receipt', 5, 110000, '2026-02-02', 'GRN', 'd0110000-1100-4000-8000-000000000805'
  )$q$, 'P0001', 'ERR_FIFO_BACKDATED_FORBIDDEN', 'Backdated transaction in FIFO entity is forbidden'
);

-- Ca FIFO 6: Chặn đảo/trả lớp hàng đã bị xuất (Q11/Q12)
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000102', 'd0110000-1100-4000-8000-000000000202',
    'd0110000-1100-4000-8000-000000000303', 'd0110000-1100-4000-8000-000000000502',
    null, 'reversal', -10, null, '2026-02-05', 'REV', 'd0110000-1100-4000-8000-000000000806',
    null, null, null, null,
    (select id from public.stock_moves where source_doc_id = 'd0110000-1100-4000-8000-000000000801')
  )$q$, 'P0001', 'ERR_FIFO_LAYER_CONSUMED', 'Reversing consumed FIFO layer is forbidden'
);

-- 5. Phần C: KHÓA NGÀY & ĐÓNG KỲ KẾ TOÁN (RPCs)
-- Khóa ngày 2026-03-15
select ok(
  ((select public.day_lock('d0110000-1100-4000-8000-000000000301', '2026-03-15')) ->> 'ok')::boolean,
  'day_lock RPC succeeds'
);

-- Ghi ngày 2026-03-15 vào kho đã khóa -> chặn ERR_DAY_LOCKED
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 1, 100000, '2026-03-15', 'GRN', 'd0110000-1100-4000-8000-000000000901'
  )$q$, 'P0001', 'ERR_DAY_LOCKED', 'Posting to locked day is rejected with ERR_DAY_LOCKED'
);

-- Ghi ngày 2026-03-14 (quá khứ) -> cũng bị chặn do <= ngày khóa
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 1, 100000, '2026-03-14', 'GRN', 'd0110000-1100-4000-8000-000000000902'
  )$q$, 'P0001', 'ERR_DAY_LOCKED', 'Posting to date before locked day is rejected with ERR_DAY_LOCKED'
);

-- Mở khóa ngày thiếu lý do -> chặn ERR_REASON_REQUIRED
select throws_ok(
  $q$select public.day_unlock((select id from public.day_locks where warehouse_id = 'd0110000-1100-4000-8000-000000000301'), '')$q$,
  'P0001', 'ERR_REASON_REQUIRED', 'day_unlock without reason fails'
);

-- Mở khóa ngày có lý do hợp lệ
select ok(
  ((select public.day_unlock((select id from public.day_locks where warehouse_id = 'd0110000-1100-4000-8000-000000000301'), 'Kiểm kê đột xuất ca đêm')) ->> 'ok')::boolean,
  'day_unlock with valid reason succeeds'
);

-- Ghi lại ngày 2026-03-15 sau mở khóa -> thành công
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 1, 100000, '2026-03-15', 'GRN', 'd0110000-1100-4000-8000-000000000903'
  )$q$, 'Posting after day unlock succeeds'
);

-- Đóng kỳ kế toán tháng 4/2026
select ok(
  ((select public.period_close('d0110000-1100-4000-8000-000000000101', 2026, 4)) ->> 'ok')::boolean,
  'period_close RPC succeeds'
);

-- Ghi vào kỳ đã đóng -> chặn ERR_PERIOD_CLOSED
select throws_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 1, 100000, '2026-04-10', 'GRN', 'd0110000-1100-4000-8000-000000000904'
  )$q$, 'P0001', 'ERR_PERIOD_CLOSED', 'Posting to closed period is rejected with ERR_PERIOD_CLOSED'
);

-- Mở lại kỳ kế toán
select ok(
  ((select public.period_reopen(
    (select id from public.accounting_periods where legal_entity_id = 'd0110000-1100-4000-8000-000000000101' and year = 2026 and month = 4),
    'Kế toán trưởng phê duyệt điều chỉnh'
  )) ->> 'ok')::boolean,
  'period_reopen with reason succeeds'
);

-- Ghi lại vào kỳ sau khi mở -> thành công
select lives_ok(
  $q$select public._post_move(
    'd0110000-1100-4000-8000-000000000101', 'd0110000-1100-4000-8000-000000000201',
    'd0110000-1100-4000-8000-000000000301', 'd0110000-1100-4000-8000-000000000501',
    null, 'receipt', 1, 100000, '2026-04-10', 'GRN', 'd0110000-1100-4000-8000-000000000905'
  )$q$, 'Posting after period reopen succeeds'
);

-- 6. Phần D: PHÂN QUYỀN VÀ TRUY VẤN CLIENT (RLS)
select set_config('request.jwt.claim.sub', 'd0110000-1100-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0110000-1100-4000-8000-000000000a02","role":"authenticated"}', true);
set local role authenticated;

-- User 2 có stock.view_qty tại Property A:
select is(
  (select count(*) > 0 from public.stock_balances where property_id = 'd0110000-1100-4000-8000-000000000201'),
  true,
  'User with stock.view_qty can read stock_balances in Property A'
);

select is(
  (select count(*) > 0 from public.stock_moves where property_id = 'd0110000-1100-4000-8000-000000000201'),
  true,
  'User with stock.view_qty can read stock_moves in Property A'
);

-- User 2 không có quyền xem ở Property B:
select is(
  (select count(*) from public.stock_moves where property_id = 'd0110000-1100-4000-8000-000000000202'),
  0::bigint,
  'User cannot read stock_moves of Property B'
);

-- User 2 không có stock.view_value -> không thấy dòng nào trong item_costs
select is(
  (select count(*) from public.item_costs),
  0::bigint,
  'User without stock.view_value cannot see any item_costs rows'
);

select * from finish();
rollback;
