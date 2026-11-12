-- admin-relax pgTAP (10/11/2026): nới lỏng quản trị tài khoản/quyền.
-- Chạy bằng `supabase test db` ở local (cần Docker). KHÔNG chạy lên production.
-- Fixture dùng chung dải UUID với admin_users_test.sql; mỗi file test chạy
-- trong transaction riêng rồi rollback nên không xung đột.
-- Gỡ: ERR_SYSTEM_ROLE ở admin_role_save / admin_role_copy /
-- admin_role_set_permissions; ERR_SELF_GRANT ở admin_user_assign_role /
-- admin_permission_override_set. Giữ: ERR_SYSTEM_ROLE ở
-- admin_role_deactivate, ERR_SELF_GRANT ở revoke/set_active chính mình,
-- ERR_LAST_ADMIN (không khóa hệ thống).
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(13);

-- Baseline trước fixture: số quản trị chuỗi đã có trên DB. Production có
-- tài khoản Duy/owner giữ sys_admin cấp chuỗi nên baseline có thể > 0;
-- test 10/12 phải cộng baseline thay vì hard-code 2/3 (app đúng theo
-- spec: guard ERR_LAST_ADMIN chỉ chặn khi tổng <= 2).
create temp table pg_tap_admin_relax_baseline as
select public.admin_count() as chain_admins;

-- Bang tam tao duoi role postgres, doc o dong 262/283 duoi role
-- authenticated -> cap quyen truoc khi doi role (khong thi 42501).
grant all on pg_tap_admin_relax_baseline to authenticated;

-- Helper: thử thu hồi 1 lần gán, trả 'OK' hoặc message lỗi (ERR_*).
-- Thu hồi thành công thì gán lại ngay vai trò chuỗi đó để khôi phục
-- trạng thái cho các test sau (chỉ xảy ra khi baseline > 0).
create or replace function pg_temp.pgtap_try_revoke(p_assignment_id uuid, p_reason text)
returns text
language plpgsql
as $$
declare
  v_user_id uuid;
  v_role_id uuid;
begin
  select upr.user_id, upr.role_id into v_user_id, v_role_id
  from public.user_property_roles upr
  where upr.id = p_assignment_id;

  begin
    perform public.admin_user_revoke_role(p_assignment_id, p_reason);
  exception
    when others then
      return sqlerrm;
  end;

  perform public.admin_user_assign_role(v_user_id, v_role_id, null);
  return 'OK';
end;
$$;

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

-- 1. Sửa được vai trò hệ thống.
select ok(
  (
    select public.admin_role_save(
      '{"id": "00000000-0000-4000-8000-000000000517", "org_id": "00000000-0000-4000-8000-000000000001", "code": "sys_admin", "name_vi": "Đổi tên sys_admin"}'::jsonb
    ) ->> 'ok'
  ) = 'true',
  'an admin can rename the sys_admin role'
);

-- 2. Sao chép được vai trò hệ thống.
select ok(
  (
    select public.admin_role_copy(
      '00000000-0000-4000-8000-000000000517', 'Sao chép sys_admin'
    ) ->> 'ok'
  ) = 'true',
  'an admin can copy the sys_admin role'
);

-- 3. Vai trò sao chép giữ nguyên ma trận quyền gốc (3 mã quản trị).
select is(
  (
    select count(*)::int from public.role_permissions rp
    where rp.role_id = (
      select r.id from public.roles r where r.code like 'copy_sys_admin%'
    )
  ),
  3,
  'the copied sys_admin role keeps the source permission matrix'
);

-- 4. Ghi đè được ma trận của vai trò hệ thống (giữ các quyền quản trị).
select ok(
  (
    select public.admin_role_set_permissions(
      '00000000-0000-4000-8000-000000000517',
      array['admin.users.manage', 'admin.roles.manage', 'admin.permissions.override', 'receiving.perform']
    ) -> 'added'
  ) @> '["receiving.perform"]'::jsonb,
  'setting permissions on sys_admin adds the new permission'
);

-- 5. Tự gán vai trò cho chính mình được phép.
select ok(
  (
    select public.admin_user_assign_role(
      '00000000-0000-4000-8000-000000000a11',
      '00000000-0000-4000-8000-000000000507',
      '00000000-0000-4000-8000-000000000201'
    ) ->> 'ok'
  ) = 'true',
  'an admin can assign a role to themselves'
);

-- 6. Tự cấp quyền riêng cho chính mình được phép.
select ok(
  (
    select public.admin_permission_override_set(
      '00000000-0000-4000-8000-000000000a11',
      '00000000-0000-4000-8000-000000000201',
      'receiving.perform',
      'allow',
      null,
      'pgTAP: self grant is now allowed'
    ) ->> 'ok'
  ) = 'true',
  'an admin can set an override for themselves'
);

-- 7. Tự thu hồi vai trò của chính mình VẪN bị chặn.
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
  'revoking your own role still raises ERR_SELF_GRANT'
);

-- 8. Tự khóa tài khoản của chính mình VẪN bị chặn.
select throws_ok(
  $$select public.admin_user_set_active(
    '00000000-0000-4000-8000-000000000a11', false
  )$$,
  'P0001',
  'ERR_SELF_GRANT',
  'locking yourself still raises ERR_SELF_GRANT'
);

-- 9. Ngừng dùng vai trò hệ thống VẪN bị chặn.
select throws_ok(
  $$select public.admin_role_deactivate(
    '00000000-0000-4000-8000-000000000517'
  )$$,
  'P0001',
  'ERR_SYSTEM_ROLE',
  'deactivating sys_admin still raises ERR_SYSTEM_ROLE'
);

-- 10. Thu hồi lần gán quản trị cuối cùng VẪN bị chặn — nhưng guard chỉ nổ
-- khi tổng quản trị chuỗi <= 2 (admin_require_not_last_admin). Production
-- đã có quản trị chuỗi ngoài fixture nên kỳ vọng phụ thuộc baseline:
-- baseline 0 -> ERR_LAST_ADMIN; baseline > 0 -> thu hồi thành công ('OK',
-- helper gán lại ngay để các test sau vẫn thấy đủ quản trị fixture).
select is(
  (
    select pg_temp.pgtap_try_revoke(
      (
        select upr.id from public.user_property_roles upr
        where upr.user_id = '00000000-0000-4000-8000-000000000a12'
          and upr.role_id = '00000000-0000-4000-8000-000000000517'
      ),
      'pgTAP: last admin revoke must fail'
    )
  ),
  case
    when (select chain_admins from pg_tap_admin_relax_baseline) = 0 then 'ERR_LAST_ADMIN'
    else 'OK'
  end,
  'revoking the second admin assignment raises ERR_LAST_ADMIN only when it would leave fewer than two chain admins'
);

-- 11. Gán vai trò sys_admin cho người khác được phép.
select ok(
  (
    select public.admin_user_assign_role(
      '00000000-0000-4000-8000-000000000a13',
      '00000000-0000-4000-8000-000000000517',
      null
    ) ->> 'ok'
  ) = 'true',
  'an admin can assign the sys_admin role to another user'
);

-- 12. Số quản trị chuỗi tăng lên baseline + 3 sau lần gán trên.
select is(
  (select public.admin_count()),
  (select chain_admins from pg_tap_admin_relax_baseline) + 3,
  'admin_count is baseline + 3 after granting sys_admin to the target user'
);

select ok(num_failed() = 0, 'all preceding pgTAP assertions passed');
select * from finish();
rollback;
