begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(30);

insert into public.organizations (id, name)
values ('00000000-0000-4000-8000-000000000001', 'pgTAP organization')
on conflict (id) do nothing;

insert into public.legal_entities (
  id, org_id, code, name, accounting_regime, costing_method
)
values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'TAP01', 'pgTAP entity 01', 'TT99', 'moving_avg'),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000001', 'TAP02', 'pgTAP entity 02', 'TT99', 'moving_avg')
on conflict (id) do nothing;

insert into public.properties (
  id, org_id, legal_entity_id, code, name, sod_profile
)
values
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'TAP01', 'pgTAP property 01', 'with_cc'),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'TAP02', 'pgTAP property 02', 'without_cc')
on conflict (id) do nothing;

insert into public.outlet_types (id, org_id, code, name)
values
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000001', 'TAP_KITCHEN', 'pgTAP kitchen'),
  ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000001', 'TAP_BAR', 'pgTAP bar')
on conflict (id) do nothing;

insert into public.outlets (id, property_id, outlet_type_id, code, name)
values
  ('00000000-0000-4000-8000-000000000321', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000301', 'TAP_KITCHEN', 'pgTAP kitchen'),
  ('00000000-0000-4000-8000-000000000322', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000302', 'TAP_BAR', 'pgTAP bar')
on conflict (id) do nothing;

insert into public.room_types (id, property_id, code, name, max_guests)
values
  ('00000000-0000-4000-8000-000000000331', '00000000-0000-4000-8000-000000000201', 'TAP_STD', 'pgTAP room 01', 2),
  ('00000000-0000-4000-8000-000000000332', '00000000-0000-4000-8000-000000000202', 'TAP_STD', 'pgTAP room 02', 2)
on conflict (id) do nothing;

insert into public.rooms (id, property_id, room_type_id, room_no, floor)
values
  ('00000000-0000-4000-8000-000000000341', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000331', 'TAP-101', '1'),
  ('00000000-0000-4000-8000-000000000342', '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000332', 'TAP-201', '2')
on conflict (id) do nothing;

insert into public.warehouses (
  id, property_id, outlet_id, room_id, code, name, kind
)
values
  ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000201', null, null, 'TAP_MAIN', 'pgTAP main', 'main'),
  ('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000321', null, 'TAP_KITCHEN', 'pgTAP kitchen', 'outlet'),
  ('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000322', null, 'TAP_BAR', 'pgTAP bar', 'outlet')
on conflict (id) do nothing;

insert into public.roles (id, org_id, code, name_vi, is_system)
values
  ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000001', 'pg_tap_owner', 'pgTAP owner', true),
  ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000001', 'pg_tap_storekeeper', 'pgTAP storekeeper', true)
on conflict (id) do nothing;

insert into public.role_permissions (role_id, permission_code)
values
  ('00000000-0000-4000-8000-000000000501', 'audit.view_all'),
  ('00000000-0000-4000-8000-000000000501', 'report.daily_brief.receive'),
  ('00000000-0000-4000-8000-000000000507', 'receiving.perform')
on conflict do nothing;

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
    '00000000-0000-4000-8000-000000000a01',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'storekeeper-ks01@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Thủ kho KS01"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a02',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'expired-user-ks02@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Người dùng hết hạn KS02"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a03',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'scoped-owner@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Chủ đầu tư phạm vi kho"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000a04',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'inactive-role@example.test',
    '',
    now(),
    now(),
    now(),
    '{}'::jsonb,
    '{"full_name":"Người dùng vai trò tắt"}'::jsonb
  );

insert into public.roles (id, org_id, code, name_vi, is_system, active)
values (
  '00000000-0000-4000-8000-000000000520',
  '00000000-0000-4000-8000-000000000001',
  'pg_tap_inactive',
  'Vai trò pgTAP không hoạt động',
  false,
  false
);
insert into public.role_permissions (role_id, permission_code)
values ('00000000-0000-4000-8000-000000000520', 'receiving.perform');

insert into public.user_property_roles (
  user_id,
  role_id,
  property_id,
  warehouse_ids
)
values
  (
    '00000000-0000-4000-8000-000000000a01',
    '00000000-0000-4000-8000-000000000507',
    '00000000-0000-4000-8000-000000000201',
    array[
      '00000000-0000-4000-8000-000000000401'::uuid,
      '00000000-0000-4000-8000-000000000406'::uuid
    ]
  ),
  (
    '00000000-0000-4000-8000-000000000a02',
    '00000000-0000-4000-8000-000000000507',
    '00000000-0000-4000-8000-000000000202',
    null
  ),
  (
    '00000000-0000-4000-8000-000000000a03',
    '00000000-0000-4000-8000-000000000501',
    null,
    array['00000000-0000-4000-8000-000000000401'::uuid]
  ),
  (
    '00000000-0000-4000-8000-000000000a04',
    '00000000-0000-4000-8000-000000000520',
    '00000000-0000-4000-8000-000000000201',
    null
  );

update public.user_property_roles
set valid_from = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 2,
    valid_to = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1
where user_id = '00000000-0000-4000-8000-000000000a02';

insert into public.user_permission_overrides (
  user_id,
  property_id,
  permission_code,
  effect,
  reason,
  valid_from,
  valid_to
)
values
  (
    '00000000-0000-4000-8000-000000000a01',
    '00000000-0000-4000-8000-000000000201',
    'price.view',
    'allow',
    'pgTAP: verify property permission override',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    null
  ),
  (
    '00000000-0000-4000-8000-000000000a01',
    '00000000-0000-4000-8000-000000000201',
    'stock.view_qty',
    'deny',
    'pgTAP: verify deny takes precedence',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    null
  ),
  (
    '00000000-0000-4000-8000-000000000a01',
    '00000000-0000-4000-8000-000000000201',
    'po.view_qty',
    'allow',
    'pgTAP: verify expired override',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date - 2,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1
  );

insert into public.audit_log (table_name, row_id, action)
values ('test_fixture', 'immutable-row', 'INSERT');

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a01',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a01","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (select count(*)::int from public.properties),
  1,
  'a user assigned to KS01 cannot read KS02'
);
select is(
  (select count(*)::int from public.properties where id = '00000000-0000-4000-8000-000000000202'),
  0,
  'RLS hides the other property'
);
select is(
  (select count(*)::int from public.my_property_ids()),
  1,
  'my_property_ids returns only assigned properties'
);
select is(
  (select count(*)::int from public.my_warehouse_ids('00000000-0000-4000-8000-000000000201')),
  2,
  'my_warehouse_ids respects the assigned warehouse scope'
);
select ok(
  public.has_perm('00000000-0000-4000-8000-000000000201', 'receiving.perform'),
  'an active role grants its permission in the assigned property'
);
select ok(
  public.has_perm(
    '00000000-0000-4000-8000-000000000201',
    'receiving.perform',
    '00000000-0000-4000-8000-000000000401'
  ),
  'the role grants permission in an assigned warehouse'
);
select ok(
  not public.has_perm(
    '00000000-0000-4000-8000-000000000201',
    'receiving.perform',
    '00000000-0000-4000-8000-000000000407'
  ),
  'the role does not grant permission in an unassigned warehouse'
);
select ok(
  not public.has_perm('00000000-0000-4000-8000-000000000202', 'receiving.perform'),
  'a property-scoped role does not grant access to another property'
);
select ok(
  not public.has_perm('00000000-0000-4000-8000-000000000201', 'po.view_qty'),
  'an expired permission override does not grant access'
);
select ok(
  public.has_perm('00000000-0000-4000-8000-000000000201', 'price.view'),
  'an active allow override grants the scoped permission'
);
select ok(
  not public.has_perm('00000000-0000-4000-8000-000000000201', 'stock.view_qty'),
  'a deny override takes precedence over a role grant'
);
select is(
  (select count(*)::int from public.profiles where id = auth.uid()),
  1,
  'a user can read their own profile'
);
select is(
  (select count(*)::int from public.audit_log),
  0,
  'users without audit permission cannot read audit entries'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a02',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a02","role":"authenticated"}',
  true
);
select ok(
  not public.has_perm('00000000-0000-4000-8000-000000000202', 'receiving.perform'),
  'an expired role assignment grants no permission'
);
select is(
  (select count(*)::int from public.properties),
  0,
  'a user with only an expired assignment cannot read a property'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a03',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a03","role":"authenticated"}',
  true
);
select is(
  (select count(*)::int from public.properties),
  1,
  'a chain role scoped to one warehouse exposes only its property'
);
select is(
  (select count(*)::int from public.my_property_ids()),
  1,
  'my_property_ids applies warehouse scope to chain roles'
);
select ok(
  public.has_perm('00000000-0000-4000-8000-000000000201', 'report.daily_brief.receive'),
  'a chain role can grant permission within its scoped property'
);
select ok(
  not public.has_perm(null, 'audit.view_all'),
  'a warehouse-scoped chain role does not grant chain-wide permissions'
);
select ok(
  not public.has_perm('00000000-0000-4000-8000-000000000999', 'report.daily_brief.receive'),
  'a permission check for a nonexistent property is denied'
);

reset role;
select throws_ok(
  $$insert into public.warehouses (property_id, outlet_id, code, name, kind) values ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000321', 'CROSS_PROPERTY_OUTLET', 'invalid', 'outlet')$$,
  '23503',
  'insert or update on table "warehouses" violates foreign key constraint "warehouses_outlet_id_property_id_fkey"',
  'a warehouse cannot reference an outlet from another property'
);
select throws_ok(
  $$insert into public.warehouses (property_id, room_id, code, name, kind) values ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000341', 'CROSS_PROPERTY_ROOM', 'invalid', 'minibar_room')$$,
  '23503',
  'insert or update on table "warehouses" violates foreign key constraint "warehouses_room_id_property_id_fkey"',
  'a minibar warehouse cannot reference a room from another property'
);
select is(
  (
    select count(*)::int
    from (
      values
        ('organizations'),
        ('legal_entities'),
        ('properties'),
        ('profiles'),
        ('outlet_types'),
        ('cost_centers'),
        ('outlets'),
        ('room_types'),
        ('rooms'),
        ('warehouses'),
        ('permissions'),
        ('roles'),
        ('role_permissions'),
        ('user_property_roles'),
        ('user_permission_overrides'),
        ('sod_exceptions'),
        ('audit_log')
    ) expected(table_name)
    join pg_namespace n on n.nspname = 'public'
    join pg_class c
      on c.relnamespace = n.oid
     and c.relname = expected.table_name
     and c.relkind = 'r'
    where c.relrowsecurity
  ),
  17,
  'RLS is enabled on every organization/access table'
);
select ok(
  not exists (
    select 1
    from (
      values
        ('organizations'),
        ('legal_entities'),
        ('properties'),
        ('profiles'),
        ('outlet_types'),
        ('cost_centers'),
        ('outlets'),
        ('room_types'),
        ('rooms'),
        ('warehouses'),
        ('permissions'),
        ('roles'),
        ('role_permissions'),
        ('user_property_roles'),
        ('user_permission_overrides'),
        ('sod_exceptions'),
        ('audit_log')
    ) protected(table_name)
    where has_table_privilege(
      'authenticated',
      format('public.%I', protected.table_name),
      'INSERT'
    )
  ),
  'authenticated users cannot insert directly into organization/access tables'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000a04',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000a04","role":"authenticated"}',
  true
);
set local role authenticated;
select ok(
  not public.has_perm('00000000-0000-4000-8000-000000000201', 'receiving.perform'),
  'a disabled role grants no permission'
);
reset role;

select ok(
  not has_column_privilege('authenticated', 'public.profiles', 'pin_hash', 'select'),
  'authenticated users cannot read profile PIN hashes'
);
select ok(
  not has_table_privilege('authenticated', 'public.properties', 'insert'),
  'authenticated users cannot write property records directly'
);
select throws_ok(
  $$update public.audit_log set row_id = 'changed' where table_name = 'test_fixture' and row_id = 'immutable-row'$$,
  '55000',
  'ERR_IMMUTABLE_LEDGER:audit_log:UPDATE',
  'audit log updates are rejected'
);
select throws_ok(
  $$delete from public.audit_log where table_name = 'test_fixture' and row_id = 'immutable-row'$$,
  '55000',
  'ERR_IMMUTABLE_LEDGER:audit_log:DELETE',
  'audit log deletes are rejected'
);

select ok(num_failed() = 0, 'all preceding pgTAP assertions passed');
select * from finish();
rollback;
