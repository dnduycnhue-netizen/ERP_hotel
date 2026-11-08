create or replace function public.bootstrap_initial_org(
  p_org_name text,
  p_legal_entity_code text,
  p_legal_entity_name text,
  p_property_code text,
  p_property_name text,
  p_admin_one uuid,
  p_admin_two uuid,
  p_test_user uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_property_id uuid;
  v_admin_role_id uuid;
  v_test_role_id uuid;
  v_admin_permission_count integer;
  v_test_permission_count integer;
begin
  perform pg_advisory_xact_lock(hashtext('bootstrap_initial_org'));

  if exists (select 1 from public.organizations) then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_BOOTSTRAP_ALREADY_INITIALIZED';
  end if;

  if p_org_name is null or btrim(p_org_name) = ''
     or p_legal_entity_code is null or btrim(p_legal_entity_code) = ''
     or p_legal_entity_name is null or btrim(p_legal_entity_name) = ''
     or p_property_code is null or btrim(p_property_code) = ''
     or p_property_name is null or btrim(p_property_name) = '' then
    raise exception using
      errcode = '22023',
      message = 'ERR_BOOTSTRAP_INVALID_INPUT';
  end if;

  if p_admin_one is null
     or p_admin_two is null
     or p_test_user is null
     or p_admin_one = p_admin_two
     or p_admin_one = p_test_user
     or p_admin_two = p_test_user
     or (
       select count(*)
       from auth.users u
       where u.id = any(array[p_admin_one, p_admin_two, p_test_user])
     ) <> 3 then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_BOOTSTRAP_USERS_INVALID';
  end if;

  select count(*) into v_admin_permission_count
  from public.permissions
  where module = 'Quản trị';

  select count(*) into v_test_permission_count
  from public.permissions
  where module <> 'Quản trị'
    and risk_level <> 'critical';

  if v_admin_permission_count = 0 or v_test_permission_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_BOOTSTRAP_PERMISSIONS_MISSING';
  end if;

  insert into public.organizations (name, created_by)
  values (btrim(p_org_name), p_admin_one)
  returning id into v_org_id;

  insert into public.legal_entities (org_id, code, name, created_by)
  values (
    v_org_id,
    upper(btrim(p_legal_entity_code)),
    btrim(p_legal_entity_name),
    p_admin_one
  )
  returning id into v_legal_entity_id;

  insert into public.properties (
    org_id,
    legal_entity_id,
    code,
    name,
    created_by
  )
  values (
    v_org_id,
    v_legal_entity_id,
    upper(btrim(p_property_code)),
    btrim(p_property_name),
    p_admin_one
  )
  returning id into v_property_id;

  insert into public.roles (
    org_id,
    code,
    name_vi,
    description,
    is_system,
    created_by
  )
  values (
    v_org_id,
    'sys_admin',
    'Quản trị hệ thống',
    'Quản trị người dùng và quyền; không có quyền nghiệp vụ tiền hoặc kho.',
    true,
    p_admin_one
  )
  returning id into v_admin_role_id;

  insert into public.role_permissions (role_id, permission_code, created_by)
  select v_admin_role_id, p.code, p_admin_one
  from public.permissions p
  where p.module = 'Quản trị';

  insert into public.roles (
    org_id,
    code,
    name_vi,
    description,
    is_system,
    created_by
  )
  values (
    v_org_id,
    'business_test_broad',
    'Kiểm thử nghiệp vụ rộng',
    'Chỉ dùng kiểm thử tại khách sạn được gán; không có quyền quản trị hoặc quyền nghiệp vụ critical.',
    false,
    p_admin_one
  )
  returning id into v_test_role_id;

  insert into public.role_permissions (role_id, permission_code, created_by)
  select v_test_role_id, p.code, p_admin_one
  from public.permissions p
  where p.module <> 'Quản trị'
    and p.risk_level <> 'critical';

  insert into public.user_property_roles (
    user_id,
    role_id,
    property_id,
    granted_by
  )
  values
    (p_admin_one, v_admin_role_id, null, p_admin_one),
    (p_admin_two, v_admin_role_id, null, p_admin_one),
    (p_test_user, v_test_role_id, v_property_id, p_admin_one);

  return jsonb_build_object(
    'ok', true,
    'org_id', v_org_id,
    'legal_entity_id', v_legal_entity_id,
    'property_id', v_property_id,
    'admin_role_id', v_admin_role_id,
    'test_role_id', v_test_role_id,
    'admin_permission_count', v_admin_permission_count,
    'test_permission_count', v_test_permission_count
  );
end;
$$;

revoke all on function public.bootstrap_initial_org(
  text, text, text, text, text, uuid, uuid, uuid
) from public, anon, authenticated;

grant execute on function public.bootstrap_initial_org(
  text, text, text, text, text, uuid, uuid, uuid
) to service_role;
