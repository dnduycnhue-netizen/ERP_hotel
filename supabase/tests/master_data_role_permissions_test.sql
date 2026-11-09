-- Go-live MVP-A pgTAP: quyền quản lý danh mục cho vai trò mẫu.
-- Kiểm chứng migration 20261109150000_master_data_role_permissions.sql:
-- `item.manage` cho thủ kho / cost controller / kế toán trưởng,
-- `warehouse.manage` cho thủ kho, `room.manage` cho giám sát buồng /
-- tổng quản lý; vai trò khác (receiver) không có các quyền này; chạy lại
-- câu lệnh cấp quyền không tạo trùng.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(13);

-- 1. Setup fixture
insert into public.organizations (id, name) values
  ('d0150000-1500-4000-8000-000000000001', 'T-015 Master Perm Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0150000-1500-4000-8000-000000000101', 'd0150000-1500-4000-8000-000000000001', 'T015', 'Entity T-015');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0150000-1500-4000-8000-000000000201', 'd0150000-1500-4000-8000-000000000001', 'd0150000-1500-4000-8000-000000000101', 'P015', 'Property T-015');

insert into public.roles (id, org_id, code, name_vi, is_system) values
  ('d0150000-1500-4000-8000-000000000601', 'd0150000-1500-4000-8000-000000000001', 'storekeeper', 'Thủ kho', true),
  ('d0150000-1500-4000-8000-000000000602', 'd0150000-1500-4000-8000-000000000001', 'cost_controller', 'Cost Controller', true),
  ('d0150000-1500-4000-8000-000000000603', 'd0150000-1500-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng', true),
  ('d0150000-1500-4000-8000-000000000604', 'd0150000-1500-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng', true),
  ('d0150000-1500-4000-8000-000000000605', 'd0150000-1500-4000-8000-000000000001', 'gm', 'Tổng quản lý', true),
  ('d0150000-1500-4000-8000-000000000606', 'd0150000-1500-4000-8000-000000000001', 'receiver', 'Nhận hàng ca sáng', true);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0150000-1500-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'storekeeper015@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0150000-1500-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'receiver015@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0150000-1500-4000-8000-000000000a01', 'd0150000-1500-4000-8000-000000000601', 'd0150000-1500-4000-8000-000000000201'),
  ('d0150000-1500-4000-8000-000000000a02', 'd0150000-1500-4000-8000-000000000606', 'd0150000-1500-4000-8000-000000000201');

-- 2. Áp dụng đúng câu lệnh cấp quyền của migration 20261109150000
insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('storekeeper', 'item.manage'),
    ('cost_controller', 'item.manage'),
    ('chief_accountant', 'item.manage'),
    ('storekeeper', 'warehouse.manage'),
    ('hk_supervisor', 'room.manage'),
    ('gm', 'room.manage')
) as rp(role_code, permission_code)
  on r.code = rp.role_code and r.is_system = true
on conflict (role_id, permission_code) do nothing;

-- 3. Vai trò mẫu có đủ quyền danh mục
select ok(
  exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000601' and permission_code = 'item.manage'),
  'storekeeper has item.manage'
);
select ok(
  exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000602' and permission_code = 'item.manage'),
  'cost_controller has item.manage'
);
select ok(
  exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000603' and permission_code = 'item.manage'),
  'chief_accountant has item.manage'
);
select ok(
  exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000601' and permission_code = 'warehouse.manage'),
  'storekeeper has warehouse.manage'
);
select ok(
  exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000604' and permission_code = 'room.manage'),
  'hk_supervisor has room.manage'
);
select ok(
  exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000605' and permission_code = 'room.manage'),
  'gm has room.manage'
);

-- 4. Vai trò đối chứng (receiver) không có quyền danh mục
select ok(
  not exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000606' and permission_code = 'item.manage'),
  'receiver lacks item.manage'
);
select ok(
  not exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000606' and permission_code = 'warehouse.manage'),
  'receiver lacks warehouse.manage'
);
select ok(
  not exists (select 1 from public.role_permissions where role_id = 'd0150000-1500-4000-8000-000000000606' and permission_code = 'room.manage'),
  'receiver lacks room.manage'
);

-- 5. Chạy lại câu lệnh cấp quyền không tạo trùng (idempotent)
insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('storekeeper', 'item.manage'),
    ('cost_controller', 'item.manage'),
    ('chief_accountant', 'item.manage'),
    ('storekeeper', 'warehouse.manage'),
    ('hk_supervisor', 'room.manage'),
    ('gm', 'room.manage')
) as rp(role_code, permission_code)
  on r.code = rp.role_code and r.is_system = true
on conflict (role_id, permission_code) do nothing;

select is(
  (select count(*) from public.role_permissions where role_id in (
    'd0150000-1500-4000-8000-000000000601',
    'd0150000-1500-4000-8000-000000000602',
    'd0150000-1500-4000-8000-000000000603',
    'd0150000-1500-4000-8000-000000000604',
    'd0150000-1500-4000-8000-000000000605',
    'd0150000-1500-4000-8000-000000000606'
  ) and permission_code in ('item.manage', 'warehouse.manage', 'room.manage')),
  6::bigint,
  're-running the grant is a no-op (still 6 rows)'
);

-- 6. Đúng 3 vai trò fixture giữ item.manage
select is(
  (select count(distinct role_id) from public.role_permissions where permission_code = 'item.manage' and role_id in (
    'd0150000-1500-4000-8000-000000000601',
    'd0150000-1500-4000-8000-000000000602',
    'd0150000-1500-4000-8000-000000000603',
    'd0150000-1500-4000-8000-000000000604',
    'd0150000-1500-4000-8000-000000000605',
    'd0150000-1500-4000-8000-000000000606'
  )),
  3::bigint,
  'exactly 3 fixture roles hold item.manage'
);

-- 7. has_perm() nhìn thấy quyền qua vai trò được gán
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

select is(
  public.has_perm('d0150000-1500-4000-8000-000000000201', 'item.manage'),
  true,
  'storekeeper passes has_perm(item.manage)'
);

select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a02","role":"authenticated"}', true);

select is(
  public.has_perm('d0150000-1500-4000-8000-000000000201', 'item.manage'),
  false,
  'receiver fails has_perm(item.manage)'
);

select * from finish();
rollback;
