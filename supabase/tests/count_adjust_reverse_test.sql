-- count_adjust_reverse_test.sql
--
-- Q244 (migration 20261109564000): dao but toan adjust_count cua dot kiem ke.
--   * _post_move dao duoc adjust_count DUONG (item_costs khop stock_balances).
--   * count_adjust_reverse: dao het, ly do bat buoc, quyen, trang thai,
--     khong dao 2 lan, ghi audit_log; sau khi dao nhap hang that thi gia binh
--     quan dung (khong bi keo xuong boi ton gia 0).
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

-- Fixture: prefix a44d0000.
insert into public.organizations (id, name) values
  ('a44d0000-0000-4000-8000-000000000001', 'Q244 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a44d0000-0000-4000-8000-000000000101', 'a44d0000-0000-4000-8000-000000000001', 'Q244', 'Entity Q244');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a44d0000-0000-4000-8000-000000000201', 'a44d0000-0000-4000-8000-000000000001', 'a44d0000-0000-4000-8000-000000000101', 'PQ244', 'Property Q244', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('a44d0000-0000-4000-8000-000000000401', 'a44d0000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('a44d0000-0000-4000-8000-000000000501', 'a44d0000-0000-4000-8000-000000000001', 'ITM_A', 'Mã A', 'a44d0000-0000-4000-8000-000000000401', 'kg'),
  ('a44d0000-0000-4000-8000-000000000502', 'a44d0000-0000-4000-8000-000000000001', 'ITM_B', 'Mã B', 'a44d0000-0000-4000-8000-000000000401', 'kg');
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('a44d0000-0000-4000-8000-000000000301', 'a44d0000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('a44d0000-0000-4000-8000-000000000302', 'a44d0000-0000-4000-8000-000000000201', 'WH_B', 'Kho phụ', 'main', null);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a44d0000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q244@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a44d0000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q244@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a44d0000-0000-4000-8000-000000000a01', 'NV Q244 01', 'GM Q244'),
  ('a44d0000-0000-4000-8000-000000000a02', 'NV Q244 02', 'Thủ kho Q244')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a44d0000-0000-4000-8000-000000000601', 'a44d0000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('a44d0000-0000-4000-8000-000000000602', 'a44d0000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho');
insert into public.role_permissions (role_id, permission_code) values
  ('a44d0000-0000-4000-8000-000000000601', 'count.adjust.approve'),
  ('a44d0000-0000-4000-8000-000000000602', 'count.perform');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a44d0000-0000-4000-8000-000000000a01', 'a44d0000-0000-4000-8000-000000000601', 'a44d0000-0000-4000-8000-000000000201'),
  ('a44d0000-0000-4000-8000-000000000a02', 'a44d0000-0000-4000-8000-000000000602', 'a44d0000-0000-4000-8000-000000000201');

-- Hai dot kiem ke: d01 'adjusted' o kho MAIN (co move), d02 'locked' o kho phu
-- (kho khac, vi dot 'locked' dong bang kho cua no).
select set_config('app.count_guard_bypass', 'on', true);
insert into public.stock_counts (id, org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind, business_date, status, opened_by, created_by) values
  ('a44d0000-0000-4000-8000-000000000d01', 'a44d0000-0000-4000-8000-000000000001', 'a44d0000-0000-4000-8000-000000000101', 'a44d0000-0000-4000-8000-000000000201', 'a44d0000-0000-4000-8000-000000000301', 'CNT-Q244-0001', 'monthly_full', '2026-11-11', 'adjusted', 'a44d0000-0000-4000-8000-000000000a01', 'a44d0000-0000-4000-8000-000000000a01'),
  ('a44d0000-0000-4000-8000-000000000d02', 'a44d0000-0000-4000-8000-000000000001', 'a44d0000-0000-4000-8000-000000000101', 'a44d0000-0000-4000-8000-000000000201', 'a44d0000-0000-4000-8000-000000000302', 'CNT-Q244-0002', 'monthly_full', '2026-11-11', 'locked', 'a44d0000-0000-4000-8000-000000000a01', 'a44d0000-0000-4000-8000-000000000a01');
select set_config('app.count_guard_bypass', 'off', true);

-- 2 move adjust_count DUONG gia 0 (giong du lieu test tren production), ghi
-- bang _post_move (can auth.uid() khac null).
select set_config('request.jwt.claim.sub', 'a44d0000-0000-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"a44d0000-0000-4000-8000-000000000a01","role":"authenticated"}', true);
select public._post_move('a44d0000-0000-4000-8000-000000000101', 'a44d0000-0000-4000-8000-000000000201', 'a44d0000-0000-4000-8000-000000000301', 'a44d0000-0000-4000-8000-000000000501', null, 'adjust_count', 20, 0, '2026-11-11', 'stock_count', 'a44d0000-0000-4000-8000-000000000d01');
select public._post_move('a44d0000-0000-4000-8000-000000000101', 'a44d0000-0000-4000-8000-000000000201', 'a44d0000-0000-4000-8000-000000000301', 'a44d0000-0000-4000-8000-000000000502', null, 'adjust_count', 50, 0, '2026-11-11', 'stock_count', 'a44d0000-0000-4000-8000-000000000d01');

create temp table a44_resp (key text primary key, resp jsonb);
grant all on a44_resp to authenticated;
create or replace function public._a44_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;

-- Thieu quyen / ly do / trang thai (truoc khi dao thanh cong).
select public._a44_as('a44d0000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.count_adjust_reverse('a44d0000-0000-4000-8000-000000000d01', 'Don du lieu thu')$q$,
  '42501', null, 'user without count.adjust.approve cannot reverse');
select public._a44_as('a44d0000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_adjust_reverse('a44d0000-0000-4000-8000-000000000d01', '   ')$q$,
  'P0001', 'ERR_REASON_REQUIRED', 'empty reason is rejected');
select throws_ok(
  $q$select public.count_adjust_reverse('a44d0000-0000-4000-8000-000000000d02', 'Don du lieu thu')$q$,
  'P0001', 'ERR_INVALID_STATUS', 'only an adjusted count can be reversed');

-- Dao thanh cong.
insert into a44_resp values ('rev', public.count_adjust_reverse(
  'a44d0000-0000-4000-8000-000000000d01', 'Don du lieu kiem ke thu truoc go-live'));
select is((select resp ->> 'reversed_moves' from a44_resp where key = 'rev'), '2',
  'both adjust_count moves are reversed');

reset role;
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances where warehouse_id = 'a44d0000-0000-4000-8000-000000000301'),
  0::numeric, 'stock_balances back to 0');
select is(
  (select coalesce(sum(qty_on_hand), 0) from public.item_costs where legal_entity_id = 'a44d0000-0000-4000-8000-000000000101'),
  0::numeric, 'item_costs.qty_on_hand matches stock_balances (back to 0)');
select is(
  (select count(*) from public.stock_moves where move_type = 'reversal' and reverses_move_id is not null
     and source_doc_id = 'a44d0000-0000-4000-8000-000000000d01'),
  2::bigint, 'two reversal moves linked by reverses_move_id');
select is(
  (select coalesce(sum(qty), 0) from public.stock_moves where source_doc_id = 'a44d0000-0000-4000-8000-000000000d01'),
  0::numeric, 'ledger nets to zero for the count (original moves kept)');
select is(
  (select count(*) from public.audit_log where table_name = 'stock_counts'
     and row_id = 'a44d0000-0000-4000-8000-000000000d01'
     and new_data ->> 'reversal_reason' = 'Don du lieu kiem ke thu truoc go-live'),
  1::bigint, 'reversal reason is recorded in audit_log');

-- Goi lai -> khong con gi de dao.
set local role authenticated;
select public._a44_as('a44d0000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_adjust_reverse('a44d0000-0000-4000-8000-000000000d01', 'Lan hai')$q$,
  '23505', 'ERR_ALREADY_REVERSED', 'reversing twice is rejected');

-- Sau khi dao, nhap hang that: gia binh quan = gia nhap (khong bi keo xuong boi ton gia 0).
reset role;
select public._post_move('a44d0000-0000-4000-8000-000000000101', 'a44d0000-0000-4000-8000-000000000201', 'a44d0000-0000-4000-8000-000000000301', 'a44d0000-0000-4000-8000-000000000501', null, 'receipt', 10, 10000, '2026-11-12', 'goods_receipt', 'a44d0000-0000-4000-8000-000000000d01');
select is(
  (select avg_cost from public.item_costs where item_id = 'a44d0000-0000-4000-8000-000000000501'),
  10000::numeric, 'after reversal a real receipt gives avg_cost = receipt cost (not diluted)');

select finish();
rollback;
