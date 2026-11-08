-- T-005: Quản trị người dùng và vai trò (docs/09-API-RPC.md mục 9).
--
-- Phạm vi:
--   * `user_has_perm(p_user_id, ...)` — bản kiểm tra quyền theo người dùng
--     cụ thể (để Edge Function service-role và các RPC quản trị dùng chung).
--     `has_perm` hiện có giữ nguyên để không ảnh hưởng test cũ.
--   * Các RPC `admin_*`: vai trò (lưu/sao chép/ma trận quyền/ngừng dùng),
--     gán/thu hồi vai trò, quyền riêng, quyền hiệu lực, kiểm tra xung đột SoD,
--     đặt PIN, khóa/mở tài khoản.
--   * Rào chắn (docs/04-SECURITY-RLS.md mục 5): ERR_SELF_GRANT khi tự cấp
--     quyền cho chính mình; ERR_LAST_ADMIN khi thao tác làm số quản trị
--     chuỗi (người giữ cả `admin.users.manage` + `admin.roles.manage`)
--     giảm dưới 2. Kiểm tra last-admin dùng quy tắc thận trọng: chặn khi
--     người bị tác động đang là quản trị chuỗi và tổng số quản trị <= 2.
--   * Audit: thay đổi bảng đã có trigger audit; `admin_user_revoke_role`
--     và `admin_user_set_active` ghi thêm dòng audit kèm lý do.
--   * Bảng `alerts` chưa tồn tại (sẽ có ở T-045) nên cảnh báo
--     `PERMISSION_CRITICAL_CHANGED` chưa ghi được vào DB; RPC
--     `admin_role_set_permissions` trả cờ `critical_changed` để UI/Edge
--     Function bề mặt cảnh báo cho chủ đầu tư.
--   * PIN 4–6 chữ số (docs/02-ARCHITECTURE.md mục 4.5), băm bằng
--     `extensions.crypt` (bcrypt). `pin_hash` không SELECT được
--     (đã chặn ở migration 02); việc kiểm PIN lúc ghi sổ thuộc T-023.
--
-- Không tạo bảng mới nên không cần policy RLS mới. Chỉ chạy migration này
-- ở local (`supabase db reset`); KHÔNG push lên production trong task này.

-- ---------------------------------------------------------------------------
-- Kiểm tra quyền theo người dùng cụ thể (dùng chung cho RPC + Edge Function)
-- ---------------------------------------------------------------------------
create or replace function public.user_has_perm(
  p_user_id uuid,
  p_property uuid,
  p_perm text,
  p_warehouse uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  with context as (
    select
      p_user_id as user_id,
      (now() at time zone 'Asia/Ho_Chi_Minh')::date as business_date
  ),
  matching_overrides as (
    select o.effect
    from public.user_permission_overrides o
    cross join context c
    where o.user_id = c.user_id
      and o.permission_code = p_perm
      and (
        o.property_id is null
        or (p_property is not null and o.property_id = p_property)
      )
      and c.business_date between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
  )
  select case
    when (select user_id from context) is null or p_perm is null then false
    when p_property is not null and not exists (
      select 1 from public.properties p where p.id = p_property
    ) then false
    when p_warehouse is not null and (
      p_property is null
      or not exists (
        select 1
        from public.warehouses w
        where w.id = p_warehouse
          and w.property_id = p_property
      )
    ) then false
    when exists (select 1 from matching_overrides where effect = 'deny') then false
    when exists (select 1 from matching_overrides where effect = 'allow') then true
    else exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id and r.active
      join public.role_permissions rp
        on rp.role_id = r.id and rp.permission_code = p_perm
      cross join context c
      left join public.properties prop on prop.id = p_property
      where upr.user_id = c.user_id
        and (upr.property_id = p_property or upr.property_id is null)
        and (prop.id is null or r.org_id = prop.org_id)
        and c.business_date between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
        and (
          (
            p_property is null
            and upr.warehouse_ids is null
            and upr.outlet_ids is null
          )
          or (
            p_property is not null
            and (
              (
                p_warehouse is null
                and (
                  (upr.warehouse_ids is null and upr.outlet_ids is null)
                  or exists (
                    select 1
                    from public.warehouses w
                    where w.id = any(upr.warehouse_ids)
                      and w.property_id = p_property
                  )
                  or exists (
                    select 1
                    from public.outlets o
                    where o.id = any(upr.outlet_ids)
                      and o.property_id = p_property
                  )
                )
              )
              or (
                p_warehouse is not null
                and (
                  (upr.warehouse_ids is null and upr.outlet_ids is null)
                  or p_warehouse = any(upr.warehouse_ids)
                  or exists (
                    select 1
                    from public.warehouses w
                    where w.id = p_warehouse
                      and w.outlet_id = any(upr.outlet_ids)
                  )
                )
              )
            )
          )
        )
    )
  end
$$;

-- Số quản trị chuỗi: người giữ cả hai quyền quản trị cấp chuỗi.
create or replace function public.admin_count()
returns integer
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select count(*)::int
  from auth.users u
  where public.user_has_perm(u.id, null, 'admin.users.manage')
    and public.user_has_perm(u.id, null, 'admin.roles.manage')
$$;

-- Người dùng có đang là quản trị chuỗi nhờ một lần gán vai trò cấp chuỗi
-- (property null, không giới hạn kho/bộ phận) không? `p_exclude_assignment_id`
-- dùng khi kiểm tra thu hồi: bỏ qua chính lần gán sắp thu hồi.
create or replace function public.admin_has_chain_admin_assignment(
  p_user_id uuid,
  p_exclude_assignment_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id and r.active
    cross join lateral (
      select (now() at time zone 'Asia/Ho_Chi_Minh')::date as business_date
    ) d
    where upr.user_id = p_user_id
      and (p_exclude_assignment_id is null or upr.id <> p_exclude_assignment_id)
      and upr.property_id is null
      and upr.warehouse_ids is null
      and upr.outlet_ids is null
      and d.business_date between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
      and exists (
        select 1 from public.role_permissions rp
        where rp.role_id = r.id and rp.permission_code = 'admin.users.manage'
      )
      and exists (
        select 1 from public.role_permissions rp
        where rp.role_id = r.id and rp.permission_code = 'admin.roles.manage'
      )
  )
$$;

-- Chặn khi thao tác làm mất quản trị chuỗi cuối cùng (còn <= 2 người).
create or replace function public.admin_require_not_last_admin(p_user_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if public.admin_count() <= 2
    and public.admin_has_chain_admin_assignment(p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_LAST_ADMIN';
  end if;
end;
$$;

-- Các cặp quyền xung đột trong cùng vai trò / cùng người (04-SECURITY-RLS mục 5).
-- Trả về từng cặp dạng text[] để gọi trực tiếp trong FROM.
create or replace function public.admin_sod_pairs()
returns setof text[]
language sql
immutable
set search_path = public, auth, pg_temp
as $$
  select array['po.create', 'receiving.post']
  union all select array['supplier.bank.request', 'payment.approve']
  union all select array['waste.propose', 'waste.approve']
$$;

revoke all on function public.user_has_perm(uuid, uuid, text, uuid) from public, anon;
revoke all on function public.admin_count() from public, anon;
revoke all on function public.admin_has_chain_admin_assignment(uuid, uuid) from public, anon;
revoke all on function public.admin_require_not_last_admin(uuid) from public, anon;
revoke all on function public.admin_sod_pairs() from public, anon;
grant execute on function public.user_has_perm(uuid, uuid, text, uuid) to authenticated, service_role;
grant execute on function public.admin_count() to authenticated;
grant execute on function public.admin_has_chain_admin_assignment(uuid, uuid) to authenticated;
grant execute on function public.admin_require_not_last_admin(uuid) to authenticated;
grant execute on function public.admin_sod_pairs() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC vai trò
-- ---------------------------------------------------------------------------
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
    if v_existing.code = 'sys_admin' then
      raise exception using errcode = 'P0001', message = 'ERR_SYSTEM_ROLE';
    end if;
    if v_existing.org_id <> v_org_id then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    update public.roles r
    set code = v_code, name_vi = v_name_vi, description = v_description
    where r.id = v_id;
  else
    if v_code = 'sys_admin' then
      raise exception using errcode = 'P0001', message = 'ERR_SYSTEM_ROLE';
    end if;
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
  if v_source.code = 'sys_admin' then
    raise exception using errcode = 'P0001', message = 'ERR_SYSTEM_ROLE';
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
  if v_role.code = 'sys_admin' then
    raise exception using errcode = 'P0001', message = 'ERR_SYSTEM_ROLE';
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

create or replace function public.admin_role_deactivate(p_role_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role public.roles;
  v_admin_user uuid;
begin
  perform public.require_perm(null, 'admin.roles.manage');

  select * into v_role from public.roles r where r.id = p_role_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if v_role.code = 'sys_admin' then
    raise exception using errcode = 'P0001', message = 'ERR_SYSTEM_ROLE';
  end if;

  -- Ngừng vai trò đang là nguồn quản trị chuỗi duy nhất của một trong
  -- hai quản trị cuối thì chặn (kẻo mất người quản trị).
  if public.admin_count() <= 2 then
    select upr.user_id into v_admin_user
    from public.user_property_roles upr
    where upr.role_id = p_role_id
      and public.admin_has_chain_admin_assignment(upr.user_id)
      and not public.admin_has_chain_admin_assignment(upr.user_id, upr.id)
    limit 1;
    if v_admin_user is not null then
      raise exception using errcode = 'P0001', message = 'ERR_LAST_ADMIN';
    end if;
  end if;

  update public.roles r set active = false where r.id = p_role_id;
  return jsonb_build_object('ok', true, 'id', p_role_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC người dùng
-- ---------------------------------------------------------------------------
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

  if p_user_id = auth.uid() then
    raise exception using errcode = 'P0001', message = 'ERR_SELF_GRANT';
  end if;

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

create or replace function public.admin_user_revoke_role(
  p_assignment_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_assignment public.user_property_roles;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select * into v_assignment
  from public.user_property_roles upr where upr.id = p_assignment_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  perform public.require_perm(v_assignment.property_id, 'admin.users.manage');

  if v_assignment.user_id = auth.uid() then
    raise exception using errcode = 'P0001', message = 'ERR_SELF_GRANT';
  end if;

  -- Thu hồi lần gán đang là nguồn quản trị chuỗi duy nhất của một trong
  -- hai quản trị cuối thì chặn.
  if public.admin_count() <= 2
    and public.admin_has_chain_admin_assignment(v_assignment.user_id)
    and not public.admin_has_chain_admin_assignment(v_assignment.user_id, p_assignment_id) then
    raise exception using errcode = 'P0001', message = 'ERR_LAST_ADMIN';
  end if;

  update public.user_property_roles upr
  set valid_to = least(coalesce(upr.valid_to, v_today), v_today)
  where upr.id = p_assignment_id;

  insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
  values (
    'user_property_roles',
    p_assignment_id::text,
    'UPDATE',
    jsonb_build_object('event', 'admin_user_revoke_role', 'reason', p_reason),
    auth.uid(),
    jsonb_build_object('source', 'admin_user_revoke_role')
  );

  return jsonb_build_object('ok', true, 'id', p_assignment_id);
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

  if p_user_id = auth.uid() then
    raise exception using errcode = 'P0001', message = 'ERR_SELF_GRANT';
  end if;
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

create or replace function public.admin_user_effective_permissions(
  p_user_id uuid,
  p_property_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_result jsonb;
begin
  perform public.require_perm(p_property_id, 'admin.users.manage');

  select jsonb_build_object(
    'ok', true,
    'user_id', p_user_id,
    'property_id', p_property_id,
    'permissions', coalesce(jsonb_agg(perms ORDER BY perms.code), '[]'::jsonb)
  )
  into v_result
  from (
    select
      p.code,
      p.module,
      p.name_vi,
      p.risk_level,
      public.user_has_perm(p_user_id, p_property_id, p.code) as granted,
      case
        when exists (
          select 1 from public.user_permission_overrides o
          where o.user_id = p_user_id
            and o.permission_code = p.code
            and (o.property_id is null or o.property_id = p_property_id)
            and v_today between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
            and o.effect = 'deny'
        ) then 'Quyền riêng: chặn'
        when exists (
          select 1 from public.user_permission_overrides o
          where o.user_id = p_user_id
            and o.permission_code = p.code
            and (o.property_id is null or o.property_id = p_property_id)
            and v_today between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
            and o.effect = 'allow'
        ) then 'Quyền riêng: cho phép'
        else (
          select 'Vai trò ' || r.name_vi
          from public.user_property_roles upr
          join public.roles r on r.id = upr.role_id and r.active
          join public.role_permissions rp
            on rp.role_id = r.id and rp.permission_code = p.code
          where upr.user_id = p_user_id
            and (upr.property_id = p_property_id or upr.property_id is null)
            and v_today between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
          limit 1
        )
      end as source,
      (
        select max(valid_to)
        from (
          select o.valid_to
          from public.user_permission_overrides o
          where o.user_id = p_user_id
            and o.permission_code = p.code
            and (o.property_id is null or o.property_id = p_property_id)
            and v_today between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
          union all
          select upr.valid_to
          from public.user_property_roles upr
          join public.role_permissions rp
            on rp.role_id = upr.role_id and rp.permission_code = p.code
          where upr.user_id = p_user_id
            and (upr.property_id = p_property_id or upr.property_id is null)
            and v_today between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
        ) validity
      ) as valid_to
    from public.permissions p
  ) perms;

  return v_result;
end;
$$;

create or replace function public.admin_sod_conflict_check(
  p_user_id uuid default null,
  p_role_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_codes text[];
  v_conflicts jsonb;
begin
  if (p_user_id is null) = (p_role_id is null) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_role_id is not null then
    perform public.require_perm(null, 'admin.roles.manage');
    select array_agg(rp.permission_code) into v_codes
    from public.role_permissions rp where rp.role_id = p_role_id;
  else
    perform public.require_perm(null, 'admin.users.manage');
    select array_agg(p.code) into v_codes
    from public.permissions p
    where public.user_has_perm(p_user_id, null, p.code);
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object('permission_a', codes[1], 'permission_b', codes[2])
  ), '[]'::jsonb)
  into v_conflicts
  from public.admin_sod_pairs() as pair(codes)
  where codes[1] = any(coalesce(v_codes, '{}'::text[]))
    and codes[2] = any(coalesce(v_codes, '{}'::text[]));

  return jsonb_build_object(
    'ok', true,
    'scope', case when p_role_id is not null then 'role' else 'user' end,
    'conflicts', v_conflicts
  );
end;
$$;

create or replace function public.admin_user_set_pin(
  p_user_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.require_perm(null, 'admin.users.manage');

  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,6}$' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_PIN';
  end if;

  update public.profiles p
  set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf'))
  where p.id = p_user_id;

  return jsonb_build_object('ok', true, 'user_id', p_user_id);
end;
$$;

create or replace function public.admin_user_set_active(
  p_user_id uuid,
  p_active boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.require_perm(null, 'admin.users.manage');

  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if not p_active and p_user_id = auth.uid() then
    raise exception using errcode = 'P0001', message = 'ERR_SELF_GRANT';
  end if;
  if not p_active then
    perform public.admin_require_not_last_admin(p_user_id);
  end if;

  update public.profiles p set active = p_active where p.id = p_user_id;

  if btrim(coalesce(p_reason, '')) <> '' then
    insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
    values (
      'profiles',
      p_user_id::text,
      'UPDATE',
      jsonb_build_object(
        'event', 'admin_user_set_active',
        'active', p_active,
        'reason', p_reason
      ),
      auth.uid(),
      jsonb_build_object('source', 'admin_user_set_active')
    );
  end if;

  return jsonb_build_object('ok', true, 'user_id', p_user_id, 'active', p_active);
end;
$$;

revoke all on function public.admin_role_save(jsonb) from public, anon;
revoke all on function public.admin_role_copy(uuid, text) from public, anon;
revoke all on function public.admin_role_set_permissions(uuid, text[]) from public, anon;
revoke all on function public.admin_role_deactivate(uuid) from public, anon;
revoke all on function public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date) from public, anon;
revoke all on function public.admin_user_revoke_role(uuid, text) from public, anon;
revoke all on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) from public, anon;
revoke all on function public.admin_user_effective_permissions(uuid, uuid) from public, anon;
revoke all on function public.admin_sod_conflict_check(uuid, uuid) from public, anon;
revoke all on function public.admin_user_set_pin(uuid, text) from public, anon;
revoke all on function public.admin_user_set_active(uuid, boolean, text) from public, anon;

grant execute on function public.admin_role_save(jsonb) to authenticated;
grant execute on function public.admin_role_copy(uuid, text) to authenticated;
grant execute on function public.admin_role_set_permissions(uuid, text[]) to authenticated;
grant execute on function public.admin_role_deactivate(uuid) to authenticated;
grant execute on function public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date) to authenticated;
grant execute on function public.admin_user_revoke_role(uuid, text) to authenticated;
grant execute on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) to authenticated;
grant execute on function public.admin_user_effective_permissions(uuid, uuid) to authenticated;
grant execute on function public.admin_sod_conflict_check(uuid, uuid) to authenticated;
grant execute on function public.admin_user_set_pin(uuid, text) to authenticated;
grant execute on function public.admin_user_set_active(uuid, boolean, text) to authenticated;

insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109000001_admin_users_roles',
  'INSERT',
  jsonb_build_object('event', 'admin_users_roles_rpc_created'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
