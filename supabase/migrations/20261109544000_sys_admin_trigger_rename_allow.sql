-- ============================================================================
-- Q222 -- protect_system_role trigger still froze the sys_admin role
--   (found by the pgTAP admin_users / admin_relax pre-flight, 11/11/2026).
--
--   The admin-relax migration (400000, 10/11/2026) removed ERR_SYSTEM_ROLE
--   from admin_role_save / admin_role_copy / admin_role_set_permissions
--   (ADR-007: owner/sys_admin may edit, copy and grant permissions on ANY
--   role, including sys_admin), but it never touched the BEFORE trigger
--   trg_roles_protect_system. protect_system_role() (141000) raised
--   23514 ERR_SYSTEM_ROLE on ANY UPDATE where old.code = 'sys_admin', so
--   an admin_role_save rename of sys_admin raised an uncaught 23514 and
--   aborted the transaction (admin_users test 18, admin_relax test 4).
--   Fix: narrow the trigger function -- a sys_admin row may be renamed /
--   its description edited; only changes to code, org_id, is_system or
--   active (deactivation) stay blocked, and DELETE of a sys_admin row is
--   still blocked. INSERT of a non-system role with code 'sys_admin',
--   DELETE of an assigned role, and UPDATE of a non-system role to code
--   'sys_admin' keep their existing guards, untouched. Generated
--   programmatically from the original function text; only the
--   old.code = 'sys_admin' block differs. No change to the trigger
--   itself (it calls the function by name), search_path, or grants.
-- ============================================================================

create or replace function public.protect_system_role()
returns trigger
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if new.code = 'sys_admin' and not new.is_system then
      raise exception using errcode = '23514', message = 'ERR_SYSTEM_ROLE';
    end if;
    return new;
  end if;

  -- Q222 (admin-relax 10/11/2026): the relax migration removed ERR_SYSTEM_ROLE
  -- from admin_role_save, but this trigger still froze every sys_admin row,
  -- so a rename raised an uncaught 23514 and aborted the transaction.
  -- A sys_admin row may now be renamed / its description edited; only
  -- changes to its identity (code, org_id, is_system) or deactivation
  -- (active) stay blocked, and DELETE of a sys_admin row is still blocked.
  if old.code = 'sys_admin' then
    if tg_op = 'DELETE' then
      raise exception using errcode = '23514', message = 'ERR_SYSTEM_ROLE';
    end if;
    if tg_op = 'UPDATE'
      and (new.code is distinct from old.code
        or new.org_id is distinct from old.org_id
        or new.is_system is distinct from old.is_system
        or new.active is distinct from old.active) then
      raise exception using errcode = '23514', message = 'ERR_SYSTEM_ROLE';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if exists (
      select 1 from public.user_property_roles upr where upr.role_id = old.id
    ) then
      raise exception using errcode = '23514', message = 'ERR_ROLE_ASSIGNED';
    end if;
    return old;
  end if;

  if new.code = 'sys_admin' and (not new.is_system or new.org_id <> old.org_id) then
    raise exception using errcode = '23514', message = 'ERR_SYSTEM_ROLE';
  end if;

  return new;
end;
$$;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109544000_sys_admin_trigger_rename_allow',
  'INSERT',
  jsonb_build_object('event', 'q222_sys_admin_trigger_rename_allow', 'task', 'admin_users/admin_relax'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
