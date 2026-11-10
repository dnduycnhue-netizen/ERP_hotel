-- Nới lỏng quản trị tài khoản/quyền (chỉ thị Duy 10/11/2026).
--
-- Chỉ nới phía QUẢN TRỊ (tạo tài khoản, gán vai trò, cấp/thu hồi quyền).
-- KHÔNG đụng kiểm tra quyền nghiệp vụ (has_perm/require_perm trong RPC
-- nghiệp vụ), quy tắc SoD, nhận hàng mù, write-guard, sổ cái bất biến, RLS.
--
-- Gỡ:
--   1. ERR_SYSTEM_ROLE ở admin_role_save / admin_role_copy /
--      admin_role_set_permissions: owner/sys_admin được sửa, sao chép và
--      cấp/thu hồi mọi mã quyền cho BẤT KỲ vai trò nào, kể cả sys_admin.
--      (Vai trò sys_admin không còn bị đóng băng ở tầng RPC.)
--   2. ERR_SELF_GRANT ở admin_user_assign_role /
--      admin_permission_override_set: quản trị được tự gán vai trò/quyền
--      cho chính mình. Người có admin.users.manage vốn đã tạo được tài
--      khoản khác với mọi quyền nên khối tự cấp không thêm an toàn thật,
--      chỉ thêm ma sát (Duy là quản trị duy nhất).
-- Giữ nguyên (an toàn chống khóa hệ thống, không chặn tạo/cấp quyền):
--   - ERR_SYSTEM_ROLE ở admin_role_deactivate (không ngừng dùng vai trò
--     hệ thống; UI cũng ẩn nút này với vai trò hệ thống).
--   - ERR_SELF_GRANT ở admin_user_revoke_role và admin_user_set_active
--     (không tự thu hồi vai trò / tự khóa tài khoản của chính mình).
--   - ERR_LAST_ADMIN / admin_require_not_last_admin (giữ ít nhất 2 quản trị
--     chuỗi; chặn thu hồi/ngừng dùng/khóa quản trị cuối).
--   - Cảnh báo xung đột SoD và cảnh báo quyền critical: chỉ cảnh báo,
--     không chặn lưu (đã như vậy từ trước); SoD trên từng chứng từ vẫn
--     được RPC nghiệp vụ kiểm tra.

create or replace function public.admin_role_save(p_role jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid := nullif(p_role ->> 'id', '')::uuid;
  v_org_id uuid := nullif(p_role ->> 'org_id', '')::uuid;
  v_code text := lower(btrim(coalesce(p_role ->> 'code', '')));
  v_name_vi text := btrim(coalesce(p_role ->> 'name_vi', ''));
  v_description text := nullif(btrim(coalesce(p_role ->> 'description', '')), '');
  v_existing public.roles;
begin
  perform public.require_perm(null, 'admin.roles.manage');

  if v_org_id is null or not exists (select 1 from public.organizations o where o.id = v_org_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if v_code !~ '^[a-z0-9_]{2,40}$' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if v_name_vi = '' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if v_id is not null then
    select * into v_existing from public.roles r where r.id = v_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    if v_existing.org_id <> v_org_id then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    update public.roles r
    set code = v_code, name_vi = v_name_vi, description = v_description
    where r.id = v_id;
  else
    insert into public.roles (org_id, code, name_vi, description, is_system)
    values (v_org_id, v_code, v_name_vi, v_description, false)
    returning id into v_id;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id, 'code', v_code);
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
end;
$$;

create or replace function public.admin_role_copy(p_role_id uuid, p_new_name text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_source public.roles;
  v_new_code text;
  v_suffix integer := 2;
  v_new_id uuid;
  v_name_vi text := btrim(coalesce(p_new_name, ''));
begin
  perform public.require_perm(null, 'admin.roles.manage');

  select * into v_source from public.roles r where r.id = p_role_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if v_name_vi = '' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  v_new_code := 'copy_' || v_source.code;
  while exists (select 1 from public.roles r where r.org_id = v_source.org_id and r.code = v_new_code) loop
    v_new_code := 'copy_' || v_source.code || '_' || v_suffix;
    v_suffix := v_suffix + 1;
  end loop;

  insert into public.roles (org_id, code, name_vi, description, is_system, copied_from_id)
  values (v_source.org_id, v_new_code, v_name_vi, v_source.description, false, v_source.id)
  returning id into v_new_id;

  insert into public.role_permissions (role_id, permission_code)
  select v_new_id, rp.permission_code
  from public.role_permissions rp
  where rp.role_id = v_source.id;

  return jsonb_build_object('ok', true, 'id', v_new_id, 'code', v_new_code);
end;
$$;

create or replace function public.admin_role_set_permissions(
  p_role_id uuid,
  p_permission_codes text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role public.roles;
  v_added text[];
  v_removed text[];
  v_conflicts jsonb;
  v_critical boolean;
  v_unknown text[];
begin
  perform public.require_perm(null, 'admin.roles.manage');

  select * into v_role from public.roles r where r.id = p_role_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select array_agg(code) into v_unknown
  from unnest(coalesce(p_permission_codes, '{}'::text[])) code
  where code not in (select p.code from public.permissions p);
  if v_unknown is not null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select array_agg(permission_code order by permission_code) into v_added
  from unnest(coalesce(p_permission_codes, '{}'::text[])) code(permission_code)
  where code not in (select rp.permission_code from public.role_permissions rp where rp.role_id = p_role_id);
  select array_agg(rp.permission_code order by rp.permission_code) into v_removed
  from public.role_permissions rp
  where rp.role_id = p_role_id
    and rp.permission_code <> all(coalesce(p_permission_codes, '{}'::text[]));

  delete from public.role_permissions rp where rp.role_id = p_role_id;
  insert into public.role_permissions (role_id, permission_code)
  select p_role_id, code
  from unnest(coalesce(p_permission_codes, '{}'::text[])) code
  on conflict do nothing;

  v_conflicts := (select public.admin_sod_conflict_check(null, p_role_id) -> 'conflicts');
  v_critical := exists (
    select 1 from public.permissions p
    where p.code = any(coalesce(v_added, '{}'::text[]))
      and p.risk_level = 'critical'
  ) or exists (
    select 1 from public.permissions p
    where p.code = any(coalesce(v_removed, '{}'::text[]))
      and p.risk_level = 'critical'
  );

  return jsonb_build_object(
    'ok', true,
    'role_id', p_role_id,
    'added', coalesce(v_added, '{}'::text[]),
    'removed', coalesce(v_removed, '{}'::text[]),
    'conflicts', coalesce(v_conflicts, '[]'::jsonb),
    'critical_changed', v_critical
  );
end;
$$;

create or replace function public.admin_user_assign_role(
  p_user_id uuid,
  p_role_id uuid,
  p_property_id uuid default null,
  p_outlet_ids uuid[] default null,
  p_warehouse_ids uuid[] default null,
  p_valid_from date default null,
  p_valid_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role public.roles;
  v_assignment_id uuid;
  v_from date := coalesce(p_valid_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
begin
  perform public.require_perm(p_property_id, 'admin.users.manage');


  select * into v_role from public.roles r where r.id = p_role_id;
  if not found or not v_role.active then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if p_valid_to is not null and p_valid_to < v_from then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  insert into public.user_property_roles (
    user_id, role_id, property_id, outlet_ids, warehouse_ids,
    valid_from, valid_to, granted_by
  )
  values (
    p_user_id, p_role_id, p_property_id, p_outlet_ids, p_warehouse_ids,
    v_from, p_valid_to, auth.uid()
  )
  returning id into v_assignment_id;

  return jsonb_build_object('ok', true, 'id', v_assignment_id);
end;
$$;

create or replace function public.admin_permission_override_set(
  p_user_id uuid,
  p_property_id uuid,
  p_permission_code text,
  p_effect text,
  p_valid_to date,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_override_id uuid;
begin
  perform public.require_perm(p_property_id, 'admin.permissions.override');

  if p_effect not in ('allow', 'deny') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;
  if not exists (select 1 from public.permissions p where p.code = p_permission_code) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Chặn quyền quản trị cấp chuỗi của một trong hai quản trị cuối thì chặn.
  if p_effect = 'deny'
    and p_property_id is null
    and p_permission_code in ('admin.users.manage', 'admin.roles.manage') then
    perform public.admin_require_not_last_admin(p_user_id);
  end if;

  insert into public.user_permission_overrides (
    user_id, property_id, permission_code, effect, valid_to, reason, granted_by
  )
  values (
    p_user_id, p_property_id, p_permission_code, p_effect, p_valid_to, p_reason, auth.uid()
  )
  returning id into v_override_id;

  return jsonb_build_object('ok', true, 'id', v_override_id);
end;
$$;

revoke all on function public.admin_role_save(jsonb) from public, anon;
revoke all on function public.admin_role_copy(uuid, text) from public, anon;
revoke all on function public.admin_role_set_permissions(uuid, text[]) from public, anon;
revoke all on function public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date) from public, anon;
revoke all on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) from public, anon;

grant execute on function public.admin_role_save(jsonb) to authenticated;
grant execute on function public.admin_role_copy(uuid, text) to authenticated;
grant execute on function public.admin_role_set_permissions(uuid, text[]) to authenticated;
grant execute on function public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date) to authenticated;
grant execute on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) to authenticated;

-- Audit trail cho chính migration này (pattern 210000/260000).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109400000_admin_relax',
  'INSERT',
  jsonb_build_object('event', 'admin_relax_completed', 'task', 'admin-relax'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
