begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

select ok(
  has_function_privilege(
    'service_role',
    'public.bootstrap_initial_org(text,text,text,text,text,uuid,uuid,uuid)',
    'EXECUTE'
  ),
  'only the service role receives bootstrap execution'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.bootstrap_initial_org(text,text,text,text,text,uuid,uuid,uuid)',
    'EXECUTE'
  ),
  'anonymous callers cannot execute the bootstrap function'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.bootstrap_initial_org(text,text,text,text,text,uuid,uuid,uuid)',
    'EXECUTE'
  ),
  'authenticated callers cannot execute the bootstrap function'
);

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
)
values
  (
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'bootstrap-admin-one@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Bootstrap admin one"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a12',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'bootstrap-admin-two@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Bootstrap admin two"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a13',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'bootstrap-test@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Bootstrap test"}'::jsonb
  );

select throws_ok(
  $$select public.bootstrap_initial_org(
    'pgTAP bootstrap',
    'TAP-ENTITY',
    'pgTAP legal entity',
    'TAP-PROPERTY',
    'pgTAP property',
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000a13'
  )$$,
  'P0001',
  'ERR_BOOTSTRAP_USERS_INVALID',
  'the same identity cannot occupy multiple bootstrap accounts'
);

set local role service_role;
select lives_ok(
  $$select public.bootstrap_initial_org(
    'pgTAP bootstrap',
    'TAP-ENTITY',
    'pgTAP legal entity',
    'TAP-PROPERTY',
    'pgTAP property',
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000a12',
    '00000000-0000-4000-8000-000000000a13'
  )$$,
  'a service-role bootstrap creates the initial organization and access roles'
);
reset role;

select is(
  (select count(*)::int from public.organizations),
  1,
  'bootstrap creates exactly one organization'
);
select is(
  (select count(*)::int from public.properties where code = 'TAP-PROPERTY'),
  1,
  'bootstrap creates the requested property'
);
select is(
  (select count(*)::int from public.roles),
  2,
  'bootstrap creates only the system-admin and test roles'
);
select is(
  (
    select count(*)::int
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    where r.code = 'sys_admin'
      and rp.permission_code = 'admin.users.manage'
  ),
  1,
  'system admins can manage users'
);
select is(
  (
    select count(*)::int
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    where r.code = 'sys_admin'
      and rp.permission_code = 'receiving.post'
  ),
  0,
  'system admins receive no business stock permissions'
);
select is(
  (
    select count(*)::int
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    where r.code = 'business_test_broad'
  ),
  (
    select count(*)::int
    from public.permissions
    where module <> 'Quản trị'
      and risk_level <> 'critical'
  ),
  'the test role receives every non-admin normal or sensitive permission'
);
select is(
  (
    select count(*)::int
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.code = rp.permission_code
    where r.code = 'business_test_broad'
      and (p.module = 'Quản trị' or p.risk_level = 'critical')
  ),
  0,
  'the test role receives no admin or critical permission'
);
select is(
  (select count(*)::int from public.user_property_roles),
  3,
  'bootstrap assigns both admins and the scoped test user'
);
select is(
  (
    select count(*)::int
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id
    where upr.property_id is null
      and r.code = 'sys_admin'
  ),
  2,
  'both initial admins receive chain-level system-admin scope'
);
select is(
  (
    select count(*)::int
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id
    join public.properties p on p.id = upr.property_id
    where r.code = 'business_test_broad'
      and p.code = 'TAP-PROPERTY'
  ),
  1,
  'the test role is limited to the initial property'
);
select ok(
  (select count(*) from public.audit_log) > 0,
  'bootstrap writes audit records for organization and permission assignments'
);

select throws_ok(
  $$select public.bootstrap_initial_org(
    'pgTAP bootstrap again',
    'TAP-ENTITY-2',
    'pgTAP legal entity 2',
    'TAP-PROPERTY-2',
    'pgTAP property 2',
    '00000000-0000-4000-8000-000000000a11',
    '00000000-0000-4000-8000-000000000a12',
    '00000000-0000-4000-8000-000000000a13'
  )$$,
  'P0001',
  'ERR_BOOTSTRAP_ALREADY_INITIALIZED',
  'the bootstrap function cannot initialize a second organization'
);

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
set local role authenticated;
select is(
  (select count(*)::int from public.my_property_ids()),
  1,
  'the test user can access exactly the assigned property'
);
select ok(
  public.has_perm(
    (select id from public.properties where code = 'TAP-PROPERTY'),
    'supplier.manage'
  ),
  'the test user receives an active sensitive business permission'
);
select ok(
  not public.has_perm(
    (select id from public.properties where code = 'TAP-PROPERTY'),
    'payment.approve'
  ),
  'the test user cannot use a critical payment permission'
);
select ok(
  not public.has_perm(
    (select id from public.properties where code = 'TAP-PROPERTY'),
    'admin.users.manage'
  ),
  'the test user cannot manage accounts'
);
reset role;

select ok(num_failed() = 0, 'all bootstrap assertions passed');
select * from finish();
rollback;
