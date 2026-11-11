-- C1 pgTAP: RPC chi doc `period_close_check` (migration 20261109520000)
-- + khoi dong lai `day_lock`/`day_unlock` (120000) ma man locks dung.
-- Fixture toi thieu: 1 org / 1 phap nhan / 1 property / 2 kho; khong can
-- item/stock vi count_open chi can 2 counter ton tai trong auth.users.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(24);

insert into public.organizations (id, name) values
  ('c1000000-0000-4000-8000-000000000001', 'C1 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000001', 'C1', 'Entity C1');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'PC1', 'Property C1', 'with_cc');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('c1000000-0000-4000-8000-000000000301', 'c1000000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('c1000000-0000-4000-8000-000000000302', 'c1000000-0000-4000-8000-000000000201', 'WH_KIT', 'Kho bếp', 'main', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('c1000000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-c1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-c1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-c1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-c1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-c1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a09', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u9-c1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('c1000000-0000-4000-8000-000000000a01', 'NV0C101', 'Thủ kho'),
  ('c1000000-0000-4000-8000-000000000a02', 'NV0C102', 'Bếp trưởng'),
  ('c1000000-0000-4000-8000-000000000a04', 'NV0C104', 'Tổng quản lý'),
  ('c1000000-0000-4000-8000-000000000a06', 'NV0C106', 'Kế toán'),
  ('c1000000-0000-4000-8000-000000000a07', 'NV0C107', 'Kế toán trưởng'),
  ('c1000000-0000-4000-8000-000000000a09', 'NV0C109', 'Người ngoài')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('c1000000-0000-4000-8000-000000000601', 'c1000000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('c1000000-0000-4000-8000-000000000602', 'c1000000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('c1000000-0000-4000-8000-000000000603', 'c1000000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('c1000000-0000-4000-8000-000000000604', 'c1000000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('c1000000-0000-4000-8000-000000000605', 'c1000000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng');

insert into public.role_permissions (role_id, permission_code) values
  ('c1000000-0000-4000-8000-000000000601', 'count.open'),
  ('c1000000-0000-4000-8000-000000000601', 'count.perform'),
  ('c1000000-0000-4000-8000-000000000602', 'count.perform'),
  ('c1000000-0000-4000-8000-000000000603', 'day.unlock'),
  ('c1000000-0000-4000-8000-000000000604', 'day.lock'),
  ('c1000000-0000-4000-8000-000000000605', 'period.close'),
  ('c1000000-0000-4000-8000-000000000605', 'period.reopen');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('c1000000-0000-4000-8000-000000000a01', 'c1000000-0000-4000-8000-000000000601', 'c1000000-0000-4000-8000-000000000201'),
  ('c1000000-0000-4000-8000-000000000a02', 'c1000000-0000-4000-8000-000000000602', 'c1000000-0000-4000-8000-000000000201'),
  ('c1000000-0000-4000-8000-000000000a04', 'c1000000-0000-4000-8000-000000000603', 'c1000000-0000-4000-8000-000000000201'),
  ('c1000000-0000-4000-8000-000000000a06', 'c1000000-0000-4000-8000-000000000604', 'c1000000-0000-4000-8000-000000000201'),
  ('c1000000-0000-4000-8000-000000000a07', 'c1000000-0000-4000-8000-000000000605', null);

create temp table c1_resp (key text primary key, resp jsonb);
-- c1_resp tao duoi role postgres truoc khi chuyen sang authenticated:
-- phai grant thi authenticated moi INSERT duoc (bay T-043/C7).
grant all on c1_resp to authenticated;

create or replace function public._c1_as(p_user uuid)
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

-- 1-2. Dinh nghia ham: SECURITY DEFINER + authenticated duoc execute.
select is(
  (select prosecdef from pg_proc where proname = 'period_close_check'),
  true, 'period_close_check is SECURITY DEFINER'
);
select ok(
  has_function_privilege('authenticated', 'public.period_close_check(uuid, integer, integer)', 'execute'),
  'authenticated can execute period_close_check'
);

-- 3. Khong dang nhap (auth.uid() null) -> ERR_FORBIDDEN.
select throws_ok(
  $q$select public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 11)$q$,
  '42501', 'ERR_FORBIDDEN',
  'period_close_check without auth is rejected'
);

set local role authenticated;

-- 4. Nguoi ngoai phap nhan (khong co role o property nao) -> ERR_FORBIDDEN.
select public._c1_as('c1000000-0000-4000-8000-000000000a09');
select throws_ok(
  $q$select public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 11)$q$,
  '42501', 'ERR_FORBIDDEN',
  'period_close_check for an outsider is rejected'
);

select public._c1_as('c1000000-0000-4000-8000-000000000a06');

-- 5-7. Input khong hop le.
select throws_ok(
  $q$select public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 13)$q$,
  '22023', 'ERR_INVALID_INPUT',
  'period_close_check rejects month 13'
);
select throws_ok(
  $q$select public.period_close_check('c1000000-0000-4000-8000-000000000101', 0, 11)$q$,
  '22023', 'ERR_INVALID_INPUT',
  'period_close_check rejects year 0'
);
select throws_ok(
  $q$select public.period_close_check(null, 2026, 11)$q$,
  '22023', 'ERR_INVALID_INPUT',
  'period_close_check rejects null entity'
);

-- 8-17. Trang thai ban dau thang 2026-11: chua dong ky, ca 2 kho deu
-- thieu dot monthly_full da khoa, khong PO/tam ung vuong, khong dong bang.
insert into c1_resp values ('fresh',
  public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 11));
select ok(
  (select (resp ->> 'ok')::boolean from c1_resp where key = 'fresh'),
  'period_close_check returns ok=true'
);
select is(
  (select (resp ->> 'already_closed')::boolean from c1_resp where key = 'fresh'),
  false, 'fresh period is not closed yet'
);
select is(
  (select (resp ->> 'count_blocked')::boolean from c1_resp where key = 'fresh'),
  true, 'fresh period is count-blocked (no locked monthly count)'
);
select ok(
  (select (resp -> 'missing_counts') @> '[{"warehouse_id": "c1000000-0000-4000-8000-000000000301"}]' from c1_resp where key = 'fresh'),
  'missing_counts lists Kho chính'
);
select ok(
  (select (resp -> 'missing_counts') @> '[{"warehouse_id": "c1000000-0000-4000-8000-000000000302"}]' from c1_resp where key = 'fresh'),
  'missing_counts lists Kho bếp'
);
select is(
  (select (resp ->> 'po_blocked')::boolean from c1_resp where key = 'fresh'),
  false, 'fresh period has no unresolved PO'
);
select is(
  (select (resp ->> 'po_count')::integer from c1_resp where key = 'fresh'),
  0, 'fresh period po_count is 0'
);
select is(
  (select (resp ->> 'advance_blocked')::boolean from c1_resp where key = 'fresh'),
  false, 'fresh period has no overdue advance'
);
select is(
  (select (resp ->> 'advance_count')::integer from c1_resp where key = 'fresh'),
  0, 'fresh period advance_count is 0'
);
select is(
  (select (resp -> 'frozen_warehouses')::text from c1_resp where key = 'fresh'),
  '[]', 'fresh period has no frozen warehouse'
);

-- 18-19. PO partially_received qua 30 ngay -> po_blocked.
set local role postgres;
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
  ('c1000000-0000-4000-8000-000000000b01', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', null, 'contract', 'stock', '2026-08-15', '2026-09-01', null, 'partially_received', 'c1000000-0000-4000-8000-000000000a01', 'PO-C1-001');
select set_config('app.pr_po_guard_bypass', 'off', true);
set local role authenticated;
select public._c1_as('c1000000-0000-4000-8000-000000000a06');
insert into c1_resp values ('po',
  public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 11));
select is(
  (select (resp ->> 'po_blocked')::boolean from c1_resp where key = 'po'),
  true, 'stale partially_received PO blocks the period'
);
select is(
  (select (resp ->> 'po_count')::integer from c1_resp where key = 'po'),
  1, 'stale PO count is 1'
);

-- 20-21. Tam ung qua han -> advance_blocked.
set local role postgres;
select set_config('app.advance_guard_bypass', 'on', true);
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status) values
  ('c1000000-0000-4000-8000-000000000901', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000a07', 'ADV-C1-001', 1000000, 'Đi chợ', 'overdue');
select set_config('app.advance_guard_bypass', 'off', true);
set local role authenticated;
select public._c1_as('c1000000-0000-4000-8000-000000000a06');
insert into c1_resp values ('adv',
  public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 11));
select is(
  (select (resp ->> 'advance_blocked')::boolean from c1_resp where key = 'adv'),
  true, 'overdue advance blocks the period'
);
select is(
  (select (resp ->> 'advance_count')::integer from c1_resp where key = 'adv'),
  1, 'overdue advance count is 1'
);

-- 22. Mo dot monthly_full o Kho chính -> kho dong bang, van thieu dot khoa.
select public._c1_as('c1000000-0000-4000-8000-000000000a01');
select public.count_open(
  'c1000000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['c1000000-0000-4000-8000-000000000a01', 'c1000000-0000-4000-8000-000000000a02']::uuid[]
);
select public._c1_as('c1000000-0000-4000-8000-000000000a06');
insert into c1_resp values ('frozen',
  public.period_close_check('c1000000-0000-4000-8000-000000000101', 2026, 11));
select ok(
  (select (resp -> 'frozen_warehouses') @> '[{"warehouse_id": "c1000000-0000-4000-8000-000000000301", "count_status": "open"}]' from c1_resp where key = 'frozen'),
  'open monthly_full count freezes Kho chính'
);
select is(
  (select jsonb_array_length(resp -> 'frozen_warehouses') from c1_resp where key = 'frozen'),
  1, 'exactly one warehouse is frozen'
);
select is(
  (select (resp ->> 'count_blocked')::boolean from c1_resp where key = 'frozen'),
  true, 'open (not locked) count still blocks the period'
);

select finish();
rollback;
