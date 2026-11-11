-- Q209 pgTAP: RPC admin_legal_entity_update (migration 20261109535000).
-- Chay bang `supabase test db` o local (can Docker). KHONG chay len production.
-- Fixture dung chung dai UUID voi admin_org_create_test.sql /
-- org_access_test.sql / admin_users_test.sql; moi file test chay trong
-- transaction rieng roi rollback nen khong xung dot.
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(11);

insert into public.organizations (id, name)
values ('00000000-0000-4000-8000-000000000001', 'pgTAP organization')
on conflict (id) do nothing;

insert into public.legal_entities (
  id, org_id, code, name, tax_code, accounting_regime, costing_method
)
values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'TAP01', 'pgTAP entity 01', '0123456789', 'TT99', 'moving_avg')
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

-- Vai tro fixture tu gan quyen (migration chi gan admin.org.manage cho
-- vai tro da ton tai luc chay migration, khong gan cho vai tro tao sau).
insert into public.role_permissions (role_id, permission_code)
values
  ('00000000-0000-4000-8000-000000000517', 'admin.org.manage'),
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

-- 1. Quan tri chuoi doi ten phap nhan thanh cong.
select ok(
  (
    select public.admin_legal_entity_update(
      '00000000-0000-4000-8000-000000000101',
      'Tên pháp nhân thật'
    ) ->> 'ok'
  ) = 'true',
  'chain admin renames legal entity'
);

-- 2. Ten moi duoc luu.
select is(
  (select name from public.legal_entities where id = '00000000-0000-4000-8000-000000000101'),
  'Tên pháp nhân thật',
  'new legal entity name is stored'
);

-- 3. Ma phap nhan khong doi.
select is(
  (select code from public.legal_entities where id = '00000000-0000-4000-8000-000000000101'),
  'TAP01',
  'legal entity code is untouched'
);

-- 4. MST / che do ke toan / phuong phap tinh gia khong doi.
select ok(
  (
    select tax_code = '0123456789'
      and accounting_regime = 'TT99'
      and costing_method = 'moving_avg'
    from public.legal_entities
    where id = '00000000-0000-4000-8000-000000000101'
  ),
  'tax code, accounting regime and costing method are untouched'
);

-- 5. Ten rong bi tu choi.
select throws_ok(
  $q$select public.admin_legal_entity_update(
    '00000000-0000-4000-8000-000000000101', ''
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'empty name is rejected'
);

-- 6. Ten chi co khoang trang bi tu choi.
select throws_ok(
  $q$select public.admin_legal_entity_update(
    '00000000-0000-4000-8000-000000000101', '   '
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'blank-only name is rejected'
);

-- 7. Ten dai hon 200 ky tu bi tu choi.
select throws_ok(
  $q$select public.admin_legal_entity_update(
    '00000000-0000-4000-8000-000000000101', repeat('X', 201)
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'name longer than 200 characters is rejected'
);

-- 8. ID phap nhan khong ton tai bi tu choi.
select throws_ok(
  $q$select public.admin_legal_entity_update(
    '00000000-0000-4000-8000-000000000999', 'Tên mới'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'nonexistent legal entity id is rejected'
);

-- 9. Nguoi khong co admin.org.manage bi tu choi (42501).
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
select throws_ok(
  $q$select public.admin_legal_entity_update(
    '00000000-0000-4000-8000-000000000101', 'Tên khác'
  )$q$,
  '42501', 'ERR_FORBIDDEN:admin.org.manage',
  'user without admin.org.manage is forbidden'
);

-- 10. Dong audit_log ghi lai viec doi ten.
select ok(
  exists (
    select 1 from public.audit_log
    where table_name = 'legal_entities'
      and row_id = '00000000-0000-4000-8000-000000000101'
      and action = 'UPDATE'
      and new_data ->> 'event' = 'admin_legal_entity_update'
      and new_data ->> 'new_name' = 'Tên pháp nhân thật'
  ),
  'audit_log records the rename'
);

select ok(num_failed() = 0, 'all preceding pgTAP assertions passed');
select * from finish();
rollback;
