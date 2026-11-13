-- C5 pgTAP: RPC admin_org_create (migration 20261109524000).
-- Chạy bằng `supabase test db` ở local (cần Docker). KHÔNG chạy lên production.
-- Fixture dùng chung dải UUID với org_access_test.sql / admin_users_test.sql;
-- mỗi file test chạy trong transaction riêng rồi rollback nên không xung đột.
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(29);

insert into public.organizations (id, name)
values ('00000000-0000-4000-8000-000000000001', 'pgTAP organization')
on conflict (id) do nothing;

insert into public.legal_entities (
  id, org_id, code, name, accounting_regime, costing_method
)
values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'TAP01', 'pgTAP entity 01', 'TT99', 'moving_avg')
on conflict (id) do nothing;

insert into public.properties (
  id, org_id, legal_entity_id, code, name, sod_profile
)
values
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'TAP01', 'pgTAP property 01', 'with_cc')
on conflict (id) do nothing;

insert into public.roles (id, org_id, code, name_vi, is_system)
values
  ('00000000-0000-4000-8000-000000000517', '00000000-0000-4000-8000-000000000001', 'sys_admin', 'Quản trị hệ thống', true),
  ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000001', 'pg_tap_plain', 'pgTAP plain', true)
on conflict (id) do nothing;

-- Vai trò fixture tự gán quyền (migration chỉ gán admin.org.manage cho
-- vai trò đã tồn tại lúc chạy migration, không gán cho vai trò tạo sau).
insert into public.role_permissions (role_id, permission_code)
values
  ('00000000-0000-4000-8000-000000000517', 'admin.org.manage'),
  ('00000000-0000-4000-8000-000000000517', 'admin.users.manage'),
  ('00000000-0000-4000-8000-000000000507', 'receiving.perform')
on conflict do nothing;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
)
values
  (
    '00000000-0000-4000-8000-000000000a21',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'org-admin@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"Quản trị tổ chức"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a22',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'org-plain@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"Người dùng thường"}'::jsonb
  );

insert into public.user_property_roles (user_id, role_id, property_id)
values
  (
    '00000000-0000-4000-8000-000000000a21',
    '00000000-0000-4000-8000-000000000517',
    null
  );

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a21',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a21","role":"authenticated"}',
  true
);
set local role authenticated;

-- 1. Mã quyền mới tồn tại trong seed permissions.
select ok(
  exists (select 1 from public.permissions p where p.code = 'admin.org.manage'),
  'admin.org.manage permission exists'
);

-- 2. Quản trị chuỗi tạo org + pháp nhân + property trong 1 lần gọi
-- (mã nhập chữ thường vẫn được chuẩn hóa thành chữ hoa).
select ok(
  (
    select public.admin_org_create('{
      "org_name": "Tap Corp",
      "legal_code": "taple2",
      "legal_name": "Tap Legal",
      "property_code": "tapprop2",
      "property_name": "Tap Hotel",
      "rooms_count": 120
    }'::jsonb) ->> 'ok'
  ) = 'true',
  'chain admin creates org + legal entity + property in one call'
);

-- 3. Tổ chức mới có đúng tên.
select ok(
  exists (select 1 from public.organizations o where o.name = 'Tap Corp'),
  'new organization row is created with the given name'
);

-- 4. Mã pháp nhân được chuẩn hóa thành chữ hoa.
select is(
  (select code from public.legal_entities le where le.name = 'Tap Legal'),
  'TAPLE2',
  'legal entity code is upper-cased'
);

-- 5. Pháp nhân mặc định costing moving_avg.
select is(
  (select costing_method from public.legal_entities le where le.name = 'Tap Legal'),
  'moving_avg',
  'legal entity defaults to moving_avg costing'
);

-- 6. Pháp nhân mặc định chế độ kế toán TT99.
select is(
  (select accounting_regime from public.legal_entities le where le.name = 'Tap Legal'),
  'TT99',
  'legal entity defaults to TT99 accounting regime'
);

-- 7. Khách sạn mặc định hồ sơ SoD có Cost Controller.
select is(
  (select sod_profile from public.properties p where p.name = 'Tap Hotel'),
  'with_cc',
  'property defaults to with_cc sod profile'
);

-- 8. Số phòng được lưu đúng.
select is(
  (select rooms_count from public.properties p where p.name = 'Tap Hotel'),
  120,
  'property rooms_count is stored'
);

-- 9. Property nối đúng tổ chức và pháp nhân mới.
select ok(
  exists (
    select 1
    from public.properties p
    join public.organizations o on o.id = p.org_id
    join public.legal_entities le on le.id = p.legal_entity_id
    where p.name = 'Tap Hotel'
      and o.name = 'Tap Corp'
      and le.name = 'Tap Legal'
  ),
  'property links the new organization and legal entity'
);

-- 10. Tổ chức mới được seed đủ 24 vai trò mẫu (17 cũ + 7 sm_*).
select is(
  (
    select count(*)
    from public.roles r
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
  ),
  24::bigint,
  'new organization is seeded with 24 system roles (17 sample + 7 compact)'
);

-- 11. sys_admin của tổ chức mới có quyền tạo tổ chức.
select ok(
  exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
      and r.code = 'sys_admin'
      and rp.permission_code = 'admin.org.manage'
  ),
  'new org sys_admin holds admin.org.manage'
);

-- 12. owner của tổ chức mới có mọi quyền.
select is(
  (
    select count(*)
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
      and r.code = 'owner'
  ),
  (select count(*) from public.permissions),
  'new org owner holds every permission'
);

-- 13. Ma trận quyền mẫu: gm có po.approve.
select ok(
  exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
      and r.code = 'gm'
      and rp.permission_code = 'po.approve'
  ),
  'new org gm holds po.approve from the template matrix'
);

-- 14. Ma trận quyền mẫu: cost_controller có receiving.review_photos.
select ok(
  exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
      and r.code = 'cost_controller'
      and rp.permission_code = 'receiving.review_photos'
  ),
  'new org cost_controller holds receiving.review_photos from the template matrix'
);

-- 15. Người tạo được gán sys_admin toàn chuỗi của tổ chức mới.
select ok(
  exists (
    select 1
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
      and r.code = 'sys_admin'
      and upr.user_id = '00000000-0000-4000-8000-000000000a21'
      and upr.property_id is null
  ),
  'creator is granted the new org sys_admin role chain-wide'
);

-- 16. Người tạo được gán owner toàn chuỗi của tổ chức mới.
select ok(
  exists (
    select 1
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp'
      and r.code = 'owner'
      and upr.user_id = '00000000-0000-4000-8000-000000000a21'
      and upr.property_id is null
  ),
  'creator is granted the new org owner role chain-wide'
);

-- 17. Có dòng audit sự kiện tạo tổ chức, actor là người tạo.
select ok(
  exists (
    select 1
    from public.audit_log a
    where a.table_name = 'organizations'
      and a.new_data ->> 'event' = 'admin_org_create'
      and a.actor = '00000000-0000-4000-8000-000000000a21'
  ),
  'admin_org_create audit event is logged with the creator as actor'
);

-- Đổi sang người dùng thường (không có admin.org.manage).
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a22',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a22","role":"authenticated"}',
  true
);

-- 18. Người không có quyền bị chặn.
select throws_ok(
  $$select public.admin_org_create('{
    "org_name": "Nope Corp",
    "legal_code": "NOPE01",
    "legal_name": "Nope Legal",
    "property_code": "NOPE01",
    "property_name": "Nope Hotel"
  }'::jsonb)$$,
  '42501',
  'ERR_FORBIDDEN:admin.org.manage',
  'user without admin.org.manage cannot create an organization'
);

-- Đổi lại quản trị chuỗi.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a21',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a21","role":"authenticated"}',
  true
);

-- 19. Thiếu tên tổ chức.
select throws_ok(
  $$select public.admin_org_create('{
    "org_name": "",
    "legal_code": "BAD001",
    "legal_name": "Bad Legal",
    "property_code": "BAD001",
    "property_name": "Bad Hotel"
  }'::jsonb)$$,
  'P0001',
  'ERR_INVALID_VALUE',
  'missing organization name raises ERR_INVALID_VALUE'
);

-- 20. Mã pháp nhân sai định dạng.
select throws_ok(
  $$select public.admin_org_create('{
    "org_name": "Bad Corp",
    "legal_code": "x",
    "legal_name": "Bad Legal",
    "property_code": "BAD001",
    "property_name": "Bad Hotel"
  }'::jsonb)$$,
  'P0001',
  'ERR_INVALID_VALUE',
  'invalid legal entity code raises ERR_INVALID_VALUE'
);

-- 21. Phương pháp tính giá không hợp lệ.
select throws_ok(
  $$select public.admin_org_create('{
    "org_name": "Bad Corp",
    "legal_code": "BAD002",
    "legal_name": "Bad Legal",
    "property_code": "BAD002",
    "property_name": "Bad Hotel",
    "costing_method": "lifo"
  }'::jsonb)$$,
  'P0001',
  'ERR_INVALID_VALUE',
  'invalid costing method raises ERR_INVALID_VALUE'
);

-- 22. Hồ sơ SoD không hợp lệ.
select throws_ok(
  $$select public.admin_org_create('{
    "org_name": "Bad Corp",
    "legal_code": "BAD003",
    "legal_name": "Bad Legal",
    "property_code": "BAD003",
    "property_name": "Bad Hotel",
    "sod_profile": "with_gm"
  }'::jsonb)$$,
  'P0001',
  'ERR_INVALID_VALUE',
  'invalid sod profile raises ERR_INVALID_VALUE'
);

-- 23. Số phòng âm.
select throws_ok(
  $$select public.admin_org_create('{
    "org_name": "Bad Corp",
    "legal_code": "BAD004",
    "legal_name": "Bad Legal",
    "property_code": "BAD004",
    "property_name": "Bad Hotel",
    "rooms_count": -1
  }'::jsonb)$$,
  'P0001',
  'ERR_INVALID_VALUE',
  'negative rooms_count raises ERR_INVALID_VALUE'
);

-- 24. Tổ chức thứ hai với giá trị tường minh (fifo, không Cost Controller).
select ok(
  (
    select public.admin_org_create('{
      "org_name": "Tap Corp 2",
      "legal_code": "taple3",
      "legal_name": "Tap Legal 2",
      "tax_code": "0123456789",
      "accounting_regime": "TT133",
      "costing_method": "fifo",
      "property_code": "tapprop3",
      "property_name": "Tap Hotel 2",
      "sod_profile": "without_cc",
      "rooms_count": 0
    }'::jsonb) ->> 'ok'
  ) = 'true',
  'second organization with explicit fifo + without_cc values is created'
);

-- 25. Pháp nhân thứ hai dùng fifo.
select is(
  (select costing_method from public.legal_entities le where le.name = 'Tap Legal 2'),
  'fifo',
  'second legal entity uses fifo costing'
);

-- 26. Khách sạn thứ hai không có Cost Controller.
select is(
  (select sod_profile from public.properties p where p.name = 'Tap Hotel 2'),
  'without_cc',
  'second property uses without_cc sod profile'
);

-- 27. Mã số thuế được lưu.
select is(
  (select tax_code from public.legal_entities le where le.name = 'Tap Legal 2'),
  '0123456789',
  'second legal entity tax code is stored'
);

-- 28. Tổ chức thứ hai cũng được seed đủ 24 vai trò mẫu.
select is(
  (
    select count(*)
    from public.roles r
    join public.organizations o on o.id = r.org_id
    where o.name = 'Tap Corp 2'
  ),
  24::bigint,
  'second organization is seeded with 24 system roles'
);

select ok(num_failed() = 0, 'all preceding pgTAP assertions passed');
select * from finish();
rollback;
