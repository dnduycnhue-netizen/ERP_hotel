-- Q229: admin_permission_override_set only INSERTed a new override row and
-- never superseded prior ones. user_has_perm checks an active 'deny' before
-- any 'allow', so once a permission was denied it could never be re-allowed:
-- setting 'allow' afterwards was a silent no-op (found by pgTAP admin_users
-- run 3, 2026-11-12: test 27 failed - admin_count stayed baseline+1 after a
-- deny-then-allow probe on the second chain admin, because the deny row
-- still shadowed the new allow row).
-- Fix: delete currently-active overrides for the same (user, property,
-- permission) before inserting the new row, so "set" replaces like its
-- sibling admin_role_set_permissions (which DELETEs the old matrix first).
-- The last-admin guard still runs before the delete, on the current state.
-- Expired history and future-dated rows are left untouched. No other change.
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

  -- Q229: "set" must replace, not append. The old code only INSERTed, so a
  -- prior active 'deny' stayed effective forever: user_has_perm checks deny
  -- before allow, and a later 'allow' could never cancel it (pgTAP
  -- admin_users test 27: admin_count stayed baseline+1 after a
  -- deny-then-allow probe on the second chain admin). Supersede any
  -- currently-active override for the same (user, property, permission)
  -- before inserting the new one; expired history and future-dated rows are
  -- left untouched. Precedent: admin_role_set_permissions DELETEs the old
  -- matrix before INSERTing the new one.
  delete from public.user_permission_overrides o
  where o.user_id = p_user_id
    and o.property_id is not distinct from p_property_id
    and o.permission_code = p_permission_code
    and o.valid_from <= (now() at time zone 'Asia/Ho_Chi_Minh')::date
    and (o.valid_to is null or o.valid_to >= (now() at time zone 'Asia/Ho_Chi_Minh')::date);

  insert into public.user_permission_overrides (
    user_id, property_id, permission_code, effect, valid_to, reason, granted_by
  )
  values (
    p_user_id, p_property_id, p_permission_code, p_effect, p_valid_to, p_reason, auth.uid()
  )
  returning id into v_override_id;

  -- C8: cap/chan rieng quyen muc 'critical' -> alert
  -- PERMISSION_CRITICAL_CHANGED (09 §9, 08 §3: red, Zalo/email,
  -- khan). Chi bao, khong chan luu (tinh than admin-relax).
  if exists (
    select 1 from public.permissions p
    where p.code = p_permission_code and p.risk_level = 'critical'
  ) then
    perform public._create_alert(
      p_property_id,
      'PERMISSION_CRITICAL_CHANGED',
      'red',
      'Ghi đè quyền mức quan trọng',
      jsonb_build_object(
        'user_id', p_user_id,
        'permission_code', p_permission_code,
        'effect', p_effect,
        'override_id', v_override_id,
        'granted_by', auth.uid()
      )
    );
  end if;

  return jsonb_build_object('ok', true, 'id', v_override_id);
end;
$$;

revoke all on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) from public, anon;
grant execute on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) to authenticated;
