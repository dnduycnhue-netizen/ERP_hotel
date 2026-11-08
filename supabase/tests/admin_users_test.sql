-- T-005 pgTAP: RPC quản trị người dùng/vai trò (docs/09-API-RPC.md mục 9).
-- Chạy bằng `supabase test db` ở local (cần Docker). KHÔNG chạy lên production.
-- Fixture dùng chung dải UUID với org_access_test.sql; mỗi file test chạy
-- trong transaction riêng rồi rollback nên không xung đột.
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(35);

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

insert into public.warehouses (
  id, property_id, outlet_id, room_id, code, name, kind
)
values
  ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000201', null, null, 'TAP_MAIN', 'pgTAP main', 'main')
on conflict (id) do nothing;

insert into public.roles (id, org_id, code, name_vi, is_system)
values
  ('00000000-0000-4000-8000-000000000517', '00000000-0000-4000-8000-000000000001', 'sys_admin', 'Quản trị hệ thống', true),
  ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000001', 'pg_tap_storekeeper', 'pgTAP storekeeper', true)
on conflict (id) do nothing;

insert into public.role_permissions (role_id, permission_code)
values
  ('00000000-0000-4000-8000-000000000517', 'admin.users.manage'),
  ('00000000-0000-4000-8000-000000000517', 'admin.roles.manage'),
  ('00000000-0000-4000-8000-000000000517', 'admin.permissions.override'),
  ('00000000-0000-4000-8000-000000000507', 'receiving.perform')
on conflict do nothing;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
)
values
  (
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'admin-one@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"Quản trị một"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a12',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'admin-two@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"Quản trị hai"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a13',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'target-user@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"Nhân viên mục tiêu"}'::jsonb
  );

insert into public.user_property_roles (user_id, role_id, property_id)
values
  (
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000517',
    null
  ),
  (
    '00000000-0000-4000-8000-000000000a12',
    '00000000-0000-4000-8000-000000000517',
    null
  );

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a11',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a11","role":"authenticated"}',
  true
);
set local role authenticated;

-- 1. Đếm quản trị chuỗi.
select is(
  (select public.admin_count()),
  2,
  'admin_count counts the two chain admins'
);

-- 2. Kiểm tra quyền theo người dùng cụ thể.
select ok(
  public.user_has_perm(
    '00000000-0000-4000-8000-000000000a11', null, 'admin.users.manage'
  ),
  'user_has_perm grants chain admin permission to the first admin'
);

-- 3. Gán vai trò cho người khác.
select ok(
  (
    select public.admin_user_assign_role(
      '00000000-0000-4000-8000-000000000a13',
      '00000000-0000-4000-8000-000000000507',
      '00000000-0000-4000-8000-000000000201'
    ) ->> 'ok'
  ) = 'true',
  'an admin can assign a role to another user'
);

-- 4. Quyền hiệu lực của người được gán.
select ok(
  (
    select public.admin_user_effective_permissions(
      '00000000-0000-4000-8000-000000000a13',
      '00000000-0000-4000-8000-000000000201'
    ) -> 'permissions'
  ) @> '[{"code": "receiving.perform", "granted": true, "source": "Vai trò pgTAP storekeeper"}]'::jsonb,
  'effective permissions show the granted permission with its role source'
);

-- 5. Quyền riêng chặn thắng vai trò.
select ok(
  (
    select public.admin_permission_override_set(
      '00000000-0000-4000-8000-000000000a13',
      '00000000-0000-4000-8000-000000000201',
      'receiving.perform',
      'deny',
      null,
      'pgTAP: verify deny override'
    ) ->> 'ok'
  ) = 'true',
  'an admin can set a deny override for another user'
);
select ok(
  (
    select public.admin_user_effective_permissions(
      '00000000-0000-4000-8000-000000000a13',
      '00000000-0000-4000-8000-000000000201'
    ) -> 'permissions'
  ) @> '[{"code": "receiving.perform", "granted": false}]'::jsonb,
  'a deny override removes the effective permission'
);

-- 6. Tự cấp quyền riêng cho chính mình bị chặn.
select throws_ok(
  $$select public.admin_permission_override_set(
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000201',
    'receiving.perform',
    'allow',
    null,
    'pgTAP: self grant must fail'
  )$$,
  'P0001',
  'ERR_SELF_GRANT',
  'setting an override for yourself raises ERR_SELF_GRANT'
);

-- 7. Tự gán vai trò cho chính mình bị chặn.
select throws_ok(
  $$select public.admin_user_assign_role(
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000507',
    '00000000-0000-4000-8000-000000000201'
  )$$,
  'P0001',
  'ERR_SELF_GRANT',
  'assigning a role to yourself raises ERR_SELF_GRANT'
);

-- 8. Thu hồi vai trò của người khác, kèm lý do.
select ok(
  (
    select public.admin_user_revoke_role(
      (
        select upr.id from public.user_property_roles upr
        where upr.user_id = '00000000-0000-4000-8000-000000000a13'
          and upr.role_id = '00000000-0000-4000-8000-000000000507'
      ),
      'pgTAP: revoke target role'
    ) ->> 'ok'
  ) = 'true',
  'an admin can revoke another user role assignment'
);
select is(
  (
    select upr.valid_to from public.user_property_roles upr
    where upr.user_id = '00000000-0000-4000-8000-000000000a13'
      and upr.role_id = '00000000-0000-4000-8000-000000000507'
  ),
  (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  'revoking sets valid_to to today'
);

-- 9. Tự thu hồi vai trò của chính mình bị chặn.
select throws_ok(
  $$select public.admin_user_revoke_role(
    (
      select upr.id from public.user_property_roles upr
      where upr.user_id = '00000000-0000-4000-8000-000000000a11'
        and upr.role_id = '00000000-0000-4000-8000-000000000517'
    ),
    'pgTAP: self revoke must fail'
  )$$,
  'P0001',
  'ERR_SELF_GRANT',
  'revoking your own role raises ERR_SELF_GRANT'
);

-- 10. Thu hồi lần gán quản trị cuối cùng bị chặn.
select throws_ok(
  $$select public.admin_user_revoke_role(
    (
      select upr.id from public.user_property_roles upr
      where upr.user_id = '00000000-0000-4000-8000-000000000a12'
        and upr.role_id = '00000000-0000-4000-8000-000000000517'
    ),
    'pgTAP: last admin revoke must fail'
  )$$,
  'P0001',
  'ERR_LAST_ADMIN',
  'revoking the second admin assignment raises ERR_LAST_ADMIN'
);

-- 11. Người không có quyền quản trị không gọi được RPC.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a13',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a13","role":"authenticated"}',
  true
);
select throws_ok(
  $$select public.admin_user_set_pin(
    '00000000-0000-4000-8000-000000000a13', '123456'
  )$$,
  '42501',
  'ERR_FORBIDDEN:admin.users.manage',
  'a user without admin.users.manage cannot set a PIN'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a11',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a11","role":"authenticated"}',
  true
);

-- 12. Đặt PIN hợp lệ: băm bcrypt, kiểm chứng được bằng crypt().
select ok(
  (
    select public.admin_user_set_pin(
      '00000000-0000-4000-8000-000000000a13', '123456'
    ) ->> 'ok'
  ) = 'true',
  'an admin can set a PIN for another user'
);
select ok(
  extensions.crypt(
    '123456',
    (select p.pin_hash from public.profiles p where p.id = '00000000-0000-4000-8000-000000000a13')
  ) = (select p.pin_hash from public.profiles p where p.id = '00000000-0000-4000-8000-000000000a13'),
  'the stored PIN hash verifies with crypt'
);

-- 13. PIN sai định dạng bị chặn.
select throws_ok(
  $$select public.admin_user_set_pin(
    '00000000-0000-4000-8000-000000000a13', '12'
  )$$,
  'P0001',
  'ERR_INVALID_PIN',
  'a PIN shorter than 4 digits raises ERR_INVALID_PIN'
);

-- 14. Khóa quản trị cuối cùng bị chặn.
select throws_ok(
  $$select public.admin_user_set_active(
    '00000000-0000-4000-8000-000000000a12', false
  )$$,
  'P0001',
  'ERR_LAST_ADMIN',
  'locking the second admin raises ERR_LAST_ADMIN'
);

-- 15. Tự khóa chính mình bị chặn.
select throws_ok(
  $$select public.admin_user_set_active(
    '00000000-0000-4000-8000-000000000a11', false
  )$$,
  'P0001',
  'ERR_SELF_GRANT',
  'locking yourself raises ERR_SELF_GRANT'
);

-- 16. Khóa rồi mở lại tài khoản thường.
select ok(
  (
    select public.admin_user_set_active(
      '00000000-0000-4000-8000-000000000a13', false, 'pgTAP: lock target'
    ) ->> 'ok'
  ) = 'true',
  'an admin can lock a regular account'
);
select is(
  (select p.active from public.profiles p where p.id = '00000000-0000-4000-8000-000000000a13'),
  false,
  'the locked profile has active = false'
);
select ok(
  (
    select public.admin_user_set_active(
      '00000000-0000-4000-8000-000000000a13', true, 'pgTAP: unlock target'
    ) ->> 'ok'
  ) = 'true',
  'an admin can unlock the account again'
);

-- 17. Tạo vai trò mới.
select ok(
  (
    select public.admin_role_save(
      '{"org_id": "00000000-0000-4000-8000-000000000001", "code": "pg_tap_counter", "name_vi": "Kiểm kê viên pgTAP"}'::jsonb
    ) ->> 'ok'
  ) = 'true',
  'an admin can create a role'
);

-- 18. Không sửa được vai trò hệ thống.
select throws_ok(
  $$select public.admin_role_save(
    '{"id": "00000000-0000-4000-8000-000000000517", "org_id": "00000000-0000-4000-8000-000000000001", "code": "sys_admin", "name_vi": "Đổi tên sys_admin"}'::jsonb
  )$$,
  'P0001',
  'ERR_SYSTEM_ROLE',
  'saving the sys_admin role raises ERR_SYSTEM_ROLE'
);

-- 19. Sao chép vai trò kèm ma trận quyền.
select ok(
  (
    select public.admin_role_copy(
      '00000000-0000-4000-8000-000000000507', 'Thủ kho sao chép pgTAP'
    ) ->> 'ok'
  ) = 'true',
  'an admin can copy a role'
);
select is(
  (
    select count(*)::int from public.role_permissions rp
    where rp.role_id = (
      select r.id from public.roles r where r.code like 'copy_pg_tap_storekeeper%'
    )
  ),
  1,
  'the copied role keeps the source permission matrix'
);

-- 20. Không sao chép được vai trò hệ thống.
select throws_ok(
  $$select public.admin_role_copy(
    '00000000-0000-4000-8000-000000000517', 'Sao chép sys_admin'
  )$$,
  'P0001',
  'ERR_SYSTEM_ROLE',
  'copying the sys_admin role raises ERR_SYSTEM_ROLE'
);

-- 21. Ghi đè ma trận quyền: trả added/removed/conflicts.
select ok(
  (
    select public.admin_role_set_permissions(
      (
        select r.id from public.roles r where r.code like 'copy_pg_tap_storekeeper%'
      ),
      array['receiving.post', 'po.create']
    ) -> 'conflicts'
  ) @> '[{"permission_a": "po.create", "permission_b": "receiving.post"}]'::jsonb,
  'setting a conflicting permission pair reports the SoD conflict'
);
select ok(
  (
    select public.admin_role_set_permissions(
      (
        select r.id from public.roles r where r.code like 'copy_pg_tap_storekeeper%'
      ),
      array['receiving.perform']
    ) -> 'removed'
  ) @> '["po.create"]'::jsonb,
  'removing the conflicting permission reports it as removed'
);

-- 22. Không ghi đè được ma trận của vai trò hệ thống.
select throws_ok(
  $$select public.admin_role_set_permissions(
    '00000000-0000-4000-8000-000000000517',
    array['receiving.perform']
  )$$,
  'P0001',
  'ERR_SYSTEM_ROLE',
  'setting permissions on sys_admin raises ERR_SYSTEM_ROLE'
);

-- 23. Kiểm tra xung đột SoD của vai trò.
select ok(
  (
    select public.admin_sod_conflict_check(
      null,
      (select r.id from public.roles r where r.code like 'copy_pg_tap_storekeeper%')
    ) -> 'conflicts'
  ) = '[]'::jsonb,
  'a role without conflicting pairs reports no conflicts'
);

-- 24. Ngừng dùng vai trò sao chép.
select ok(
  (
    select public.admin_role_deactivate(
      (select r.id from public.roles r where r.code like 'copy_pg_tap_storekeeper%')
    ) ->> 'ok'
  ) = 'true',
  'an admin can deactivate a copied role'
);

-- 25. Không ngừng được vai trò hệ thống.
select throws_ok(
  $$select public.admin_role_deactivate(
    '00000000-0000-4000-8000-000000000517'
  )$$,
  'P0001',
  'ERR_SYSTEM_ROLE',
  'deactivating sys_admin raises ERR_SYSTEM_ROLE'
);

-- 26. Chặn quyền quản trị cấp chuỗi của quản trị cuối bị chặn.
select throws_ok(
  $$select public.admin_permission_override_set(
    '00000000-0000-4000-8000-000000000a12',
    null,
    'admin.users.manage',
    'deny',
    null,
    'pgTAP: deny last admin must fail'
  )$$,
  'P0001',
  'ERR_LAST_ADMIN',
  'denying a chain admin permission of the second admin raises ERR_LAST_ADMIN'
);

-- 27. Số quản trị không đổi sau các thao tác bị chặn.
select is(
  (select public.admin_count()),
  2,
  'admin_count is still 2 after the blocked operations'
);

select ok(num_failed() = 0, 'all preceding pgTAP assertions passed');
select * from finish();
rollback;
