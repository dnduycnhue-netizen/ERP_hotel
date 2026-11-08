create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.legal_entities (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  tax_code text,
  accounting_regime text not null default 'TT99'
    check (accounting_regime in ('TT99', 'TT133')),
  costing_method text not null default 'moving_avg'
    check (costing_method in ('moving_avg', 'fifo')),
  external_codes jsonb not null default '{}'::jsonb
    check (jsonb_typeof(external_codes) = 'object'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null unique,
  code text not null,
  name text not null,
  address text,
  sod_profile text not null default 'with_cc'
    check (sod_profile in ('with_cc', 'without_cc')),
  rooms_count integer not null default 0 check (rooms_count >= 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id),
  foreign key (legal_entity_id, org_id)
    references public.legal_entities(id, org_id)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  employee_code text unique,
  full_name text not null default '',
  phone text,
  pin_hash text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.outlet_types (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

create table public.cost_centers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  usali_department text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

create table public.outlets (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  outlet_type_id uuid not null references public.outlet_types(id),
  cost_center_id uuid references public.cost_centers(id),
  code text not null,
  name text not null,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code),
  unique (id, property_id)
);

create table public.room_types (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  code text not null,
  name text not null,
  max_guests integer check (max_guests is null or max_guests > 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code),
  unique (id, property_id)
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  room_type_id uuid not null,
  room_no text not null,
  floor text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, room_no),
  unique (id, property_id),
  foreign key (room_type_id, property_id)
    references public.room_types(id, property_id)
);

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  outlet_id uuid references public.outlets(id),
  room_id uuid references public.rooms(id),
  code text not null,
  name text not null,
  kind text not null check (kind in (
    'main', 'outlet', 'floor', 'trolley', 'minibar_main', 'minibar_room',
    'transit', 'quarantine', 'disposal'
  )),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code),
  unique (id, property_id),
  check ((kind = 'minibar_room') = (room_id is not null)),
  check (kind not in ('outlet', 'floor', 'trolley') or outlet_id is not null),
  foreign key (outlet_id, property_id)
    references public.outlets(id, property_id),
  foreign key (room_id, property_id)
    references public.rooms(id, property_id)
);

create unique index warehouses_one_minibar_per_room
  on public.warehouses (room_id)
  where kind = 'minibar_room';
create index warehouses_property_outlet_idx
  on public.warehouses (property_id, outlet_id);

create table public.permissions (
  code text primary key,
  module text not null,
  name_vi text not null,
  description_vi text not null,
  risk_level text not null check (risk_level in ('normal', 'sensitive', 'critical')),
  sort_order integer not null,
  created_at timestamptz not null default now()
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null,
  name_vi text not null,
  description text,
  is_system boolean not null default false,
  active boolean not null default true,
  copied_from_id uuid references public.roles(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_code text not null references public.permissions(code),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (role_id, permission_code)
);

create table public.user_property_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.roles(id),
  property_id uuid references public.properties(id) on delete cascade,
  outlet_ids uuid[],
  warehouse_ids uuid[],
  valid_from date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  valid_to date,
  granted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to >= valid_from)
);

create table public.user_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid references public.properties(id) on delete cascade,
  permission_code text not null references public.permissions(code),
  effect text not null check (effect in ('allow', 'deny')),
  valid_from date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  valid_to date,
  reason text not null check (btrim(reason) <> ''),
  granted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to >= valid_from)
);

create table public.sod_exceptions (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  rule_code text not null,
  reason text not null check (btrim(reason) <> ''),
  valid_to date not null,
  approved_by uuid not null references auth.users(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (approved_by <> user_id)
);

create index user_property_roles_user_idx
  on public.user_property_roles (user_id);
create index user_property_roles_property_idx
  on public.user_property_roles (property_id, user_id);
create index user_property_roles_role_idx
  on public.user_property_roles (role_id);
create index user_permission_overrides_user_perm_idx
  on public.user_permission_overrides (user_id, permission_code);
create index user_permission_overrides_property_idx
  on public.user_permission_overrides (property_id, user_id);
create index role_permissions_permission_idx
  on public.role_permissions (permission_code);
create index audit_log_table_row_idx
  on public.audit_log (table_name, row_id);
create index audit_log_actor_at_idx
  on public.audit_log (actor, at desc);

create or replace function public.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  insert into public.profiles (id, employee_code, full_name, phone)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'employee_code', ''),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    nullif(new.phone, '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.create_profile_for_auth_user();

create or replace function public.validate_user_property_role()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
begin
  select org_id into v_org_id
  from public.roles
  where id = new.role_id;

  if not found then
    raise exception using errcode = '23503', message = 'ERR_ROLE_NOT_FOUND';
  end if;

  if new.property_id is not null and not exists (
    select 1
    from public.properties p
    where p.id = new.property_id
      and p.org_id = v_org_id
  ) then
    raise exception using errcode = '23514', message = 'ERR_ROLE_PROPERTY_ORG_MISMATCH';
  end if;

  if new.property_id is null and (
    exists (
      select 1
      from unnest(coalesce(new.warehouse_ids, '{}'::uuid[])) scoped(id)
      where not exists (
        select 1
        from public.warehouses w
        join public.properties p on p.id = w.property_id
        where w.id = scoped.id
          and p.org_id = v_org_id
      )
    )
    or exists (
      select 1
      from unnest(coalesce(new.outlet_ids, '{}'::uuid[])) scoped(id)
      where not exists (
        select 1
        from public.outlets o
        join public.properties p on p.id = o.property_id
        where o.id = scoped.id
          and p.org_id = v_org_id
      )
    )
  ) then
    raise exception using errcode = '23514', message = 'ERR_ROLE_SCOPE_ORG_MISMATCH';
  end if;

  if new.property_id is not null and (
    exists (
      select 1
      from unnest(coalesce(new.warehouse_ids, '{}'::uuid[])) scoped(id)
      where not exists (
        select 1 from public.warehouses w
        where w.id = scoped.id and w.property_id = new.property_id
      )
    )
    or exists (
      select 1
      from unnest(coalesce(new.outlet_ids, '{}'::uuid[])) scoped(id)
      where not exists (
        select 1 from public.outlets o
        where o.id = scoped.id and o.property_id = new.property_id
      )
    )
  ) then
    raise exception using errcode = '23514', message = 'ERR_ROLE_SCOPE_PROPERTY_MISMATCH';
  end if;

  return new;
end;
$$;

create trigger trg_user_property_roles_validate
before insert or update on public.user_property_roles
for each row execute function public.validate_user_property_role();

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

  if old.code = 'sys_admin' then
    raise exception using errcode = '23514', message = 'ERR_SYSTEM_ROLE';
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

create trigger trg_roles_protect_system
before insert or update or delete on public.roles
for each row execute function public.protect_system_role();

create or replace function public.has_perm(
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
      auth.uid() as user_id,
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

create or replace function public.require_perm(
  p_property uuid,
  p_perm text,
  p_warehouse uuid default null
)
returns void
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.has_perm(p_property, p_perm, p_warehouse) then
    raise exception using
      errcode = '42501',
      message = format('ERR_FORBIDDEN:%s', p_perm);
  end if;
end;
$$;

create or replace function public.my_property_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select p.id
  from public.properties p
  where exists (
    select 1
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id and r.active
    cross join lateral (
      select (now() at time zone 'Asia/Ho_Chi_Minh')::date as business_date
    ) d
    where upr.user_id = auth.uid()
      and r.org_id = p.org_id
      and (upr.property_id = p.id or upr.property_id is null)
      and d.business_date between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
      and (
        (upr.warehouse_ids is null and upr.outlet_ids is null)
        or exists (
          select 1
          from public.warehouses w
          where w.id = any(upr.warehouse_ids)
            and w.property_id = p.id
        )
        or exists (
          select 1
          from public.outlets o
          where o.id = any(upr.outlet_ids)
            and o.property_id = p.id
        )
      )
  )
$$;

create or replace function public.my_warehouse_ids(p_property uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select w.id
  from public.warehouses w
  where w.property_id = p_property
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id and r.active
      cross join lateral (
        select (now() at time zone 'Asia/Ho_Chi_Minh')::date as business_date
      ) d
      where upr.user_id = auth.uid()
        and r.org_id = (
          select p.org_id from public.properties p where p.id = p_property
        )
        and (upr.property_id = p_property or upr.property_id is null)
        and d.business_date between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
        and (
          (upr.warehouse_ids is null and upr.outlet_ids is null)
          or w.id = any(upr.warehouse_ids)
          or w.outlet_id = any(upr.outlet_ids)
        )
    )
$$;

create or replace function public.my_permissions(p_property uuid)
returns text[]
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select coalesce(array_agg(p.code order by p.code), '{}'::text[])
  from public.permissions p
  where public.has_perm(p_property, p.code)
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'organizations',
    'legal_entities',
    'properties',
    'profiles',
    'outlet_types',
    'cost_centers',
    'outlets',
    'room_types',
    'rooms',
    'warehouses',
    'permissions',
    'roles',
    'role_permissions',
    'user_property_roles',
    'user_permission_overrides',
    'sod_exceptions'
  ]
  loop
    execute format('alter table public.%I enable row level security', v_table);
  end loop;
end;
$$;

create policy organizations_select on public.organizations
for select to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = organizations.id
      and p.id in (select public.my_property_ids())
  )
);

create policy legal_entities_select on public.legal_entities
for select to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.legal_entity_id = legal_entities.id
      and p.id in (select public.my_property_ids())
  )
);

create policy properties_select on public.properties
for select to authenticated
using (id in (select public.my_property_ids()));

create policy profiles_select on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or (select public.has_perm(null, 'admin.users.manage'))
);

create policy outlet_types_select on public.outlet_types
for select to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = outlet_types.org_id
      and p.id in (select public.my_property_ids())
  )
);

create policy cost_centers_select on public.cost_centers
for select to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = cost_centers.org_id
      and p.id in (select public.my_property_ids())
  )
);

create policy outlets_select on public.outlets
for select to authenticated
using (property_id in (select public.my_property_ids()));

create policy room_types_select on public.room_types
for select to authenticated
using (property_id in (select public.my_property_ids()));

create policy rooms_select on public.rooms
for select to authenticated
using (property_id in (select public.my_property_ids()));

create policy warehouses_select on public.warehouses
for select to authenticated
using (id in (select public.my_warehouse_ids(property_id)));

create policy permissions_select on public.permissions
for select to authenticated
using (auth.uid() is not null);

create policy roles_select on public.roles
for select to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = roles.org_id
      and p.id in (select public.my_property_ids())
  )
);

create policy role_permissions_select on public.role_permissions
for select to authenticated
using (
  exists (
    select 1
    from public.roles r
    join public.properties p on p.org_id = r.org_id
    where r.id = role_permissions.role_id
      and p.id in (select public.my_property_ids())
  )
);

create policy user_property_roles_select on public.user_property_roles
for select to authenticated
using (
  user_id = auth.uid()
  or (
    property_id is not null
    and (select public.has_perm(property_id, 'admin.users.manage'))
  )
  or (
    property_id is null
    and (select public.has_perm(null, 'admin.users.manage'))
  )
);

create policy user_permission_overrides_select on public.user_permission_overrides
for select to authenticated
using (
  user_id = auth.uid()
  or (
    property_id is not null
    and (select public.has_perm(property_id, 'admin.users.manage'))
  )
  or (
    property_id is null
    and (select public.has_perm(null, 'admin.permissions.override'))
  )
);

create policy sod_exceptions_select on public.sod_exceptions
for select to authenticated
using (
  user_id = auth.uid()
  or (select public.has_perm(property_id, 'admin.permissions.override'))
);

create policy audit_log_select on public.audit_log
for select to authenticated
using ((select public.has_perm(null, 'audit.view_all')));

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'organizations',
    'legal_entities',
    'properties',
    'profiles',
    'outlet_types',
    'cost_centers',
    'outlets',
    'room_types',
    'rooms',
    'warehouses',
    'permissions',
    'roles',
    'role_permissions',
    'user_property_roles',
    'user_permission_overrides',
    'sod_exceptions',
    'audit_log'
  ]
  loop
    execute format(
      'revoke all on table public.%I from anon, authenticated',
      v_table
    );
  end loop;
end;
$$;

grant select on public.organizations,
  public.legal_entities,
  public.properties,
  public.outlet_types,
  public.cost_centers,
  public.outlets,
  public.room_types,
  public.rooms,
  public.warehouses,
  public.permissions,
  public.roles,
  public.role_permissions,
  public.user_property_roles,
  public.user_permission_overrides,
  public.sod_exceptions,
  public.audit_log
to authenticated;

grant select (
  id,
  employee_code,
  full_name,
  phone,
  active,
  created_at,
  updated_at
) on public.profiles to authenticated;

revoke all on function public.create_profile_for_auth_user() from public, anon, authenticated;
revoke all on function public.validate_user_property_role() from public, anon, authenticated;
revoke all on function public.protect_system_role() from public, anon, authenticated;

revoke all on function public.has_perm(uuid, text, uuid) from public, anon;
revoke all on function public.require_perm(uuid, text, uuid) from public, anon;
revoke all on function public.my_property_ids() from public, anon;
revoke all on function public.my_warehouse_ids(uuid) from public, anon;
revoke all on function public.my_permissions(uuid) from public, anon;

grant execute on function public.has_perm(uuid, text, uuid) to authenticated;
grant execute on function public.require_perm(uuid, text, uuid) to authenticated;
grant execute on function public.my_property_ids() to authenticated;
grant execute on function public.my_warehouse_ids(uuid) to authenticated;
grant execute on function public.my_permissions(uuid) to authenticated;

insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('admin.users.manage', 'Quản trị', 'Quản lý người dùng', 'Tạo, khóa và cập nhật người dùng.', 'critical', 10),
  ('admin.roles.manage', 'Quản trị', 'Quản lý vai trò', 'Tạo vai trò và cấu hình ma trận quyền.', 'critical', 20),
  ('admin.permissions.override', 'Quản trị', 'Ghi đè quyền', 'Cấp hoặc chặn quyền riêng có lý do.', 'critical', 30),
  ('admin.settings.manage', 'Quản trị', 'Quản lý cấu hình', 'Thay đổi cấu hình nghiệp vụ.', 'critical', 40),
  ('admin.approval_rules.manage', 'Quản trị', 'Quản lý quy tắc duyệt', 'Cấu hình các bước duyệt chứng từ.', 'critical', 50),
  ('admin.alert_rules.manage', 'Quản trị', 'Quản lý quy tắc cảnh báo', 'Cấu hình ngưỡng và kênh cảnh báo.', 'critical', 60),
  ('item.view', 'Danh mục', 'Xem vật tư', 'Xem danh mục vật tư.', 'normal', 100),
  ('item.manage', 'Danh mục', 'Quản lý vật tư', 'Tạo và cập nhật danh mục vật tư.', 'sensitive', 110),
  ('item.temp.create', 'Danh mục', 'Tạo mã tạm', 'Tạo mã vật tư tạm thời.', 'normal', 120),
  ('item.temp.normalize', 'Danh mục', 'Chuẩn hóa mã tạm', 'Chuẩn hóa và gộp mã tạm.', 'sensitive', 130),
  ('item.import', 'Danh mục', 'Nhập danh mục', 'Xem trước và nhập dữ liệu danh mục.', 'sensitive', 140),
  ('warehouse.manage', 'Danh mục', 'Quản lý kho', 'Tạo và cập nhật danh mục kho.', 'sensitive', 150),
  ('room.manage', 'Danh mục', 'Quản lý phòng', 'Tạo và cập nhật danh mục phòng.', 'sensitive', 160),
  ('supplier.view', 'NCC và giá', 'Xem nhà cung cấp', 'Xem danh mục nhà cung cấp.', 'normal', 200),
  ('supplier.manage', 'NCC và giá', 'Quản lý nhà cung cấp', 'Tạo và cập nhật hồ sơ nhà cung cấp.', 'sensitive', 210),
  ('supplier.approve', 'NCC và giá', 'Duyệt nhà cung cấp', 'Thẩm định và duyệt nhà cung cấp.', 'sensitive', 220),
  ('supplier.bank.request', 'NCC và giá', 'Đề nghị đổi tài khoản NCC', 'Đề nghị thêm hoặc đổi tài khoản ngân hàng NCC.', 'sensitive', 230),
  ('supplier.bank.approve', 'NCC và giá', 'Duyệt tài khoản NCC', 'Duyệt tài khoản ngân hàng NCC bởi người khác.', 'critical', 240),
  ('price.agreement.manage', 'NCC và giá', 'Quản lý hợp đồng giá', 'Quản lý hợp đồng khung và giá thỏa thuận.', 'sensitive', 250),
  ('price.ceiling.manage', 'NCC và giá', 'Quản lý giá trần', 'Thiết lập giá trần theo vật tư và khách sạn.', 'sensitive', 260),
  ('price.view', 'NCC và giá', 'Xem giá', 'Xem đơn giá và giá trần.', 'sensitive', 270),
  ('pr.create', 'Thu mua', 'Tạo yêu cầu mua', 'Tạo yêu cầu mua hàng hoặc dịch vụ.', 'normal', 300),
  ('pr.approve', 'Thu mua', 'Duyệt yêu cầu mua', 'Duyệt yêu cầu mua trong phạm vi được giao.', 'sensitive', 310),
  ('po.create', 'Thu mua', 'Tạo đơn mua hàng', 'Tạo đơn đặt hàng.', 'sensitive', 320),
  ('po.view', 'Thu mua', 'Xem đơn mua hàng', 'Xem thông tin đơn đặt hàng được phép.', 'normal', 330),
  ('po.view_qty', 'Thu mua', 'Xem số lượng PO', 'Xem số lượng trên đơn đặt hàng.', 'sensitive', 340),
  ('po.view_price', 'Thu mua', 'Xem giá PO', 'Xem đơn giá trên đơn đặt hàng.', 'sensitive', 350),
  ('po.approve', 'Thu mua', 'Duyệt PO', 'Duyệt đơn đặt hàng theo bước được giao.', 'sensitive', 360),
  ('po.approve.over_ceiling', 'Thu mua', 'Duyệt PO vượt giá trần', 'Duyệt ngoại lệ giá vượt giá trần.', 'critical', 370),
  ('po.close', 'Thu mua', 'Đóng PO', 'Đóng phần số lượng chưa nhận của đơn hàng.', 'sensitive', 380),
  ('market.order.create', 'Thu mua', 'Tạo lệnh mua chợ', 'Tạo lệnh mua chợ gắn với tạm ứng.', 'sensitive', 390),
  ('receiving.perform', 'Nhận hàng', 'Thực hiện nhận hàng', 'Cân, kiểm tra và ghi nhận hàng thực nhận.', 'sensitive', 400),
  ('receiving.post', 'Nhận hàng', 'Ghi sổ nhận hàng', 'Ghi nhận hàng vào kho bằng RPC.', 'critical', 410),
  ('receiving.view', 'Nhận hàng', 'Xem phiếu nhận hàng', 'Xem phiếu nhận hàng trong phạm vi được cấp.', 'sensitive', 420),
  ('receiving.review_photos', 'Nhận hàng', 'Hậu kiểm ảnh nhận hàng', 'Kiểm tra ảnh và bằng chứng nhận hàng.', 'sensitive', 430),
  ('receiving.override_over_po', 'Nhận hàng', 'Ghi nhận vượt PO', 'Duyệt ghi nhận phần hàng vượt giới hạn PO.', 'critical', 440),
  ('receiving.reverse', 'Nhận hàng', 'Đảo phiếu nhận hàng', 'Tạo bút toán đảo phiếu nhận đã ghi sổ.', 'critical', 450),
  ('supplier_return.post', 'Nhận hàng', 'Ghi sổ trả hàng NCC', 'Ghi nhận hàng trả lại nhà cung cấp.', 'sensitive', 460),
  ('stock.view_qty', 'Kho', 'Xem số lượng tồn', 'Xem số lượng tồn trong phạm vi kho.', 'sensitive', 500),
  ('stock.view_value', 'Kho', 'Xem giá trị tồn', 'Xem giá vốn và giá trị tồn kho.', 'sensitive', 510),
  ('requisition.create', 'Kho', 'Tạo phiếu lĩnh', 'Tạo phiếu yêu cầu lĩnh hàng.', 'normal', 520),
  ('requisition.approve', 'Kho', 'Duyệt phiếu lĩnh', 'Duyệt phiếu yêu cầu lĩnh hàng.', 'sensitive', 530),
  ('requisition.issue', 'Kho', 'Xuất phiếu lĩnh', 'Xuất hàng từ kho theo phiếu lĩnh.', 'sensitive', 540),
  ('requisition.receive', 'Kho', 'Xác nhận nhận phiếu lĩnh', 'Xác nhận số lượng thực nhận tại bộ phận.', 'sensitive', 550),
  ('transfer.send', 'Kho', 'Gửi điều chuyển', 'Gửi hàng điều chuyển qua kho trung chuyển.', 'sensitive', 560),
  ('transfer.receive', 'Kho', 'Nhận điều chuyển', 'Xác nhận nhận hàng điều chuyển.', 'sensitive', 570),
  ('purpose_issue.post', 'Kho', 'Ghi sổ xuất theo mục đích', 'Ghi nhận xuất dùng theo mục đích và khoản mục.', 'sensitive', 580),
  ('waste.propose', 'Kho', 'Đề xuất hủy hàng', 'Đề xuất hủy hàng kèm lý do và ảnh.', 'sensitive', 590),
  ('waste.approve', 'Kho', 'Duyệt hủy hàng', 'Duyệt phiếu hủy bởi người khác người đề xuất.', 'sensitive', 600),
  ('waste.approve.large', 'Kho', 'Duyệt phiếu hủy lớn', 'Duyệt phiếu hủy vượt ngưỡng giá trị.', 'critical', 610),
  ('count.open', 'Kiểm kê và khóa', 'Mở đợt kiểm kê', 'Mở đợt kiểm kê và đóng băng kho.', 'sensitive', 700),
  ('count.perform', 'Kiểm kê và khóa', 'Thực hiện kiểm kê', 'Đếm hàng theo phiếu kiểm kê mù.', 'sensitive', 710),
  ('count.lock', 'Kiểm kê và khóa', 'Khóa đợt kiểm kê', 'Khóa đợt kiểm kê sau khi hoàn tất.', 'sensitive', 720),
  ('count.view_variance', 'Kiểm kê và khóa', 'Xem chênh lệch kiểm kê', 'Xem tồn sổ và chênh lệch; không áp dụng cho người đếm.', 'sensitive', 730),
  ('count.adjust.approve', 'Kiểm kê và khóa', 'Duyệt điều chỉnh kiểm kê', 'Duyệt điều chỉnh tồn kho sau kiểm kê.', 'critical', 740),
  ('day.lock', 'Kiểm kê và khóa', 'Khóa ngày', 'Khóa ngày nghiệp vụ theo kho.', 'sensitive', 750),
  ('day.unlock', 'Kiểm kê và khóa', 'Mở khóa ngày', 'Mở khóa ngày kèm lý do và cảnh báo.', 'critical', 760),
  ('period.close', 'Kiểm kê và khóa', 'Khóa kỳ', 'Khóa kỳ kế toán sau khi đạt điều kiện.', 'critical', 770),
  ('period.reopen', 'Kiểm kê và khóa', 'Mở lại kỳ', 'Mở lại kỳ kế toán theo phê duyệt.', 'critical', 780),
  ('hk.standard.manage', 'Buồng phòng', 'Quản lý chuẩn setup', 'Quản lý chuẩn setup phòng.', 'sensitive', 800),
  ('hk.trolley.operate', 'Buồng phòng', 'Vận hành xe đẩy', 'Mở và chốt ca xe đẩy buồng phòng.', 'normal', 810),
  ('minibar.request_check', 'Buồng phòng', 'Yêu cầu kiểm minibar', 'Yêu cầu kiểm minibar khi khách trả phòng.', 'normal', 820),
  ('minibar.check', 'Buồng phòng', 'Kiểm minibar', 'Ghi nhận minibar thực tế trong phòng.', 'sensitive', 830),
  ('minibar.charge.confirm', 'Buồng phòng', 'Xác nhận thu minibar', 'Xác nhận đã thu tiền minibar và folio.', 'sensitive', 840),
  ('minibar.waive.request', 'Buồng phòng', 'Đề nghị miễn minibar', 'Đề nghị miễn tiền minibar kèm lý do.', 'normal', 850),
  ('minibar.waive.approve', 'Buồng phòng', 'Duyệt miễn minibar', 'Duyệt miễn minibar bởi người khác người đề nghị.', 'critical', 860),
  ('minibar.refill', 'Buồng phòng', 'Bổ sung minibar', 'Điều chuyển hàng vào minibar phòng.', 'sensitive', 870),
  ('invoice.manage', 'Tài chính', 'Quản lý hóa đơn', 'Nhập và khớp hóa đơn nhà cung cấp.', 'sensitive', 900),
  ('invoice.approve', 'Tài chính', 'Duyệt hóa đơn', 'Duyệt hóa đơn đã khớp ba chiều.', 'critical', 910),
  ('ap.view', 'Tài chính', 'Xem công nợ', 'Xem sổ chi tiết công nợ nhà cung cấp.', 'sensitive', 920),
  ('advance.request', 'Tài chính', 'Đề nghị tạm ứng', 'Đề nghị tạm ứng phục vụ mua hàng.', 'sensitive', 930),
  ('advance.approve', 'Tài chính', 'Duyệt tạm ứng', 'Duyệt tạm ứng bởi người khác người đề nghị.', 'sensitive', 940),
  ('advance.disburse', 'Tài chính', 'Chi tạm ứng', 'Ghi nhận chi tiền tạm ứng.', 'critical', 950),
  ('advance.settle', 'Tài chính', 'Quyết toán tạm ứng', 'Nộp chứng từ và quyết toán tạm ứng.', 'sensitive', 960),
  ('payment.request', 'Tài chính', 'Đề nghị thanh toán', 'Tạo đề nghị thanh toán hóa đơn.', 'sensitive', 970),
  ('payment.approve', 'Tài chính', 'Duyệt thanh toán', 'Duyệt đề nghị thanh toán nhà cung cấp.', 'critical', 980),
  ('payment.mark_paid', 'Tài chính', 'Ghi nhận đã thanh toán', 'Ghi nhận khoản thanh toán đã thực hiện.', 'critical', 990),
  ('export.accounting', 'Tài chính', 'Xuất dữ liệu kế toán', 'Xuất dữ liệu chứng từ và công nợ cho kế toán.', 'sensitive', 1000),
  ('service.contract.manage', 'Dịch vụ', 'Quản lý hợp đồng dịch vụ', 'Tạo và cập nhật hợp đồng dịch vụ.', 'sensitive', 1100),
  ('service.accept', 'Dịch vụ', 'Nghiệm thu dịch vụ', 'Nghiệm thu dịch vụ bởi người không đặt dịch vụ.', 'sensitive', 1110),
  ('pms.input', 'Dữ liệu ngoài', 'Nhập số liệu PMS', 'Nhập số liệu vận hành ngày từ PMS.', 'normal', 1200),
  ('pos.import', 'Dữ liệu ngoài', 'Nhập dữ liệu POS', 'Nhập và đối soát dữ liệu bán hàng POS.', 'sensitive', 1210),
  ('report.view.rpt_stock_card', 'Báo cáo', 'Xem thẻ kho', 'Xem báo cáo nhập, xuất, tồn theo kho.', 'sensitive', 1300),
  ('report.view.rpt_receiving_quality', 'Báo cáo', 'Xem chất lượng nhận hàng', 'Xem chất lượng nhận hàng theo nhà cung cấp.', 'normal', 1310),
  ('report.view.rpt_open_po_invoice', 'Báo cáo', 'Xem PO mở và hóa đơn treo', 'Xem PO chưa nhận đủ và hóa đơn đang treo.', 'sensitive', 1320),
  ('report.view.rpt_ap_aging', 'Báo cáo', 'Xem tuổi nợ', 'Xem tuổi nợ và dự báo dòng tiền.', 'sensitive', 1330),
  ('report.view.rpt_advances', 'Báo cáo', 'Xem tạm ứng', 'Xem các khoản tạm ứng chưa quyết toán.', 'sensitive', 1340),
  ('report.view.rpt_waste', 'Báo cáo', 'Xem báo cáo hủy hàng', 'Xem hàng hủy theo lý do và bộ phận.', 'sensitive', 1350),
  ('report.view.rpt_opex', 'Báo cáo', 'Xem chi phí vận hành', 'Xem chi phí theo khoản mục và trung tâm chi phí.', 'sensitive', 1360),
  ('report.view.rpt_minibar', 'Báo cáo', 'Xem báo cáo minibar', 'Xem doanh thu, giá vốn và đối soát minibar.', 'sensitive', 1370),
  ('report.view.rpt_amenity_cpor', 'Báo cáo', 'Xem chi phí amenities', 'Xem chi phí amenities trên đêm phòng.', 'sensitive', 1380),
  ('report.view.rpt_daily_brief', 'Báo cáo', 'Xem bản tin 8 giờ', 'Xem bản tin tổng hợp vận hành hằng ngày.', 'sensitive', 1390),
  ('report.daily_brief.receive', 'Báo cáo', 'Nhận bản tin 8 giờ', 'Nhận bản tin tổng hợp vận hành hằng ngày.', 'normal', 1400),
  ('audit.view_all', 'Báo cáo', 'Xem nhật ký kiểm toán', 'Xem nhật ký kiểm toán toàn chuỗi.', 'critical', 1410),
  ('alert.receive.bank_account_change', 'Cảnh báo', 'Nhận cảnh báo đổi tài khoản NCC', 'Nhận cảnh báo về thay đổi tài khoản ngân hàng NCC.', 'normal', 1500),
  ('alert.receive.unlock', 'Cảnh báo', 'Nhận cảnh báo mở khóa', 'Nhận cảnh báo mở khóa ngày hoặc kỳ.', 'normal', 1510),
  ('alert.receive.water_night_spike', 'Cảnh báo', 'Nhận cảnh báo nước ban đêm', 'Nhận cảnh báo mức tiêu thụ nước ban đêm.', 'normal', 1520),
  ('alert.receive.count_variance', 'Cảnh báo', 'Nhận cảnh báo lệch kiểm kê', 'Nhận cảnh báo chênh lệch kiểm kê.', 'normal', 1530),
  ('alert.receive.avt_daily', 'Cảnh báo', 'Nhận cảnh báo lệch AvT', 'Nhận cảnh báo lệch thực tế và lý thuyết.', 'normal', 1540),
  ('alert.receive.over_ceiling_approved', 'Cảnh báo', 'Nhận cảnh báo duyệt vượt giá trần', 'Nhận cảnh báo PO được duyệt vượt giá trần.', 'normal', 1550),
  ('alert.receive.price_spike', 'Cảnh báo', 'Nhận cảnh báo tăng giá', 'Nhận cảnh báo giá nhập tăng bất thường.', 'normal', 1560),
  ('alert.receive.waste_large', 'Cảnh báo', 'Nhận cảnh báo hủy hàng lớn', 'Nhận cảnh báo phiếu hủy vượt ngưỡng.', 'normal', 1570),
  ('alert.receive.minibar_mismatch', 'Cảnh báo', 'Nhận cảnh báo lệch minibar', 'Nhận cảnh báo đối soát minibar không khớp.', 'normal', 1580),
  ('alert.receive.advance_overdue', 'Cảnh báo', 'Nhận cảnh báo tạm ứng quá hạn', 'Nhận cảnh báo tạm ứng chưa quyết toán đúng hạn.', 'normal', 1590),
  ('alert.receive.temp_item_stale', 'Cảnh báo', 'Nhận cảnh báo mã tạm quá hạn', 'Nhận cảnh báo mã tạm chưa được chuẩn hóa.', 'normal', 1600),
  ('alert.receive.photo_reused', 'Cảnh báo', 'Nhận cảnh báo ảnh dùng lại', 'Nhận cảnh báo ảnh chứng từ trùng lặp.', 'normal', 1610),
  ('alert.receive.permission_critical_changed', 'Cảnh báo', 'Nhận cảnh báo đổi quyền quan trọng', 'Nhận cảnh báo thay đổi quyền mức quan trọng.', 'normal', 1620),
  ('alert.receive.sod_exception_used', 'Cảnh báo', 'Nhận cảnh báo dùng ngoại lệ SoD', 'Nhận cảnh báo khi sử dụng ngoại lệ tách biệt nhiệm vụ.', 'normal', 1630),
  ('alert.receive.service_unaccepted_payment', 'Cảnh báo', 'Nhận cảnh báo dịch vụ chưa nghiệm thu', 'Nhận cảnh báo đề nghị thanh toán dịch vụ chưa nghiệm thu.', 'normal', 1640)
on conflict (code) do update set
  module = excluded.module,
  name_vi = excluded.name_vi,
  description_vi = excluded.description_vi,
  risk_level = excluded.risk_level,
  sort_order = excluded.sort_order;

insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261108141000_org_access',
  'INSERT',
  jsonb_build_object('event', 'organization_access_schema_created'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);

create trigger trg_organizations_updated_at before update on public.organizations
for each row execute function public.set_updated_at();
create trigger trg_legal_entities_updated_at before update on public.legal_entities
for each row execute function public.set_updated_at();
create trigger trg_properties_updated_at before update on public.properties
for each row execute function public.set_updated_at();
create trigger trg_profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger trg_outlet_types_updated_at before update on public.outlet_types
for each row execute function public.set_updated_at();
create trigger trg_cost_centers_updated_at before update on public.cost_centers
for each row execute function public.set_updated_at();
create trigger trg_outlets_updated_at before update on public.outlets
for each row execute function public.set_updated_at();
create trigger trg_room_types_updated_at before update on public.room_types
for each row execute function public.set_updated_at();
create trigger trg_rooms_updated_at before update on public.rooms
for each row execute function public.set_updated_at();
create trigger trg_warehouses_updated_at before update on public.warehouses
for each row execute function public.set_updated_at();
create trigger trg_roles_updated_at before update on public.roles
for each row execute function public.set_updated_at();
create trigger trg_user_property_roles_updated_at before update on public.user_property_roles
for each row execute function public.set_updated_at();
create trigger trg_user_permission_overrides_updated_at before update on public.user_permission_overrides
for each row execute function public.set_updated_at();
create trigger trg_sod_exceptions_updated_at before update on public.sod_exceptions
for each row execute function public.set_updated_at();

create trigger trg_organizations_audit after insert or update or delete on public.organizations
for each row execute function public.audit_trigger();
create trigger trg_legal_entities_audit after insert or update or delete on public.legal_entities
for each row execute function public.audit_trigger();
create trigger trg_properties_audit after insert or update or delete on public.properties
for each row execute function public.audit_trigger();
create trigger trg_outlet_types_audit after insert or update or delete on public.outlet_types
for each row execute function public.audit_trigger();
create trigger trg_cost_centers_audit after insert or update or delete on public.cost_centers
for each row execute function public.audit_trigger();
create trigger trg_outlets_audit after insert or update or delete on public.outlets
for each row execute function public.audit_trigger();
create trigger trg_room_types_audit after insert or update or delete on public.room_types
for each row execute function public.audit_trigger();
create trigger trg_rooms_audit after insert or update or delete on public.rooms
for each row execute function public.audit_trigger();
create trigger trg_warehouses_audit after insert or update or delete on public.warehouses
for each row execute function public.audit_trigger();
create trigger trg_roles_audit after insert or update or delete on public.roles
for each row execute function public.audit_trigger();
create trigger trg_role_permissions_audit after insert or update or delete on public.role_permissions
for each row execute function public.audit_trigger();
create trigger trg_user_property_roles_audit after insert or update or delete on public.user_property_roles
for each row execute function public.audit_trigger();
create trigger trg_user_permission_overrides_audit after insert or update or delete on public.user_permission_overrides
for each row execute function public.audit_trigger();
create trigger trg_sod_exceptions_audit after insert or update or delete on public.sod_exceptions
for each row execute function public.audit_trigger();