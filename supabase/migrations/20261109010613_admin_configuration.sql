-- T-006: Cấu hình nghiệp vụ, quy tắc duyệt và quy tắc cảnh báo.

create table public.settings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid,
  key text not null check (key in (
    'price_spike_pct',
    'receiving_tolerance_pct',
    'market_advance_deadline_hours',
    'waste_approval_threshold_vnd',
    'count_random_items',
    'count_variance_threshold_pct',
    'count_without_cc_factor',
    'invoice_price_tolerance_pct'
  )),
  value jsonb not null check (jsonb_typeof(value) = 'number'),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (property_id, org_id)
    references public.properties(id, org_id) on delete cascade,
  unique nulls not distinct (org_id, property_id, key)
);

create table public.approval_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid,
  doc_type text not null check (doc_type ~ '^[a-z][a-z0-9_]{1,39}$'),
  min_amount numeric(18,2) not null default 0 check (min_amount >= 0),
  max_amount numeric(18,2) check (max_amount is null or max_amount >= min_amount),
  item_group_id uuid,
  condition jsonb not null default '{}'::jsonb
    check (jsonb_typeof(condition) = 'object'),
  step integer not null check (step > 0),
  approver_role_id uuid,
  approver_user_id uuid references auth.users(id),
  required_perm text not null default 'po.approve'
    references public.permissions(code),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (property_id, org_id)
    references public.properties(id, org_id) on delete cascade,
  foreign key (approver_role_id, org_id)
    references public.roles(id, org_id),
  check ((approver_role_id is null) <> (approver_user_id is null)),
  unique nulls not distinct (
    org_id, property_id, doc_type, min_amount, max_amount, item_group_id, condition, step
  )
);

create table public.alert_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid,
  code text not null check (code ~ '^[A-Z][A-Z0-9_]{1,63}$'),
  threshold jsonb not null default '{}'::jsonb
    check (jsonb_typeof(threshold) = 'object'),
  channels text[] not null default array['app']::text[]
    check (
      cardinality(channels) > 0
      and channels <@ array['app', 'email', 'webpush', 'zalo']::text[]
    ),
  urgent boolean not null default false,
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (property_id, org_id)
    references public.properties(id, org_id) on delete cascade,
  unique nulls not distinct (org_id, property_id, code)
);

create index approval_rules_scope_idx
  on public.approval_rules (org_id, property_id, doc_type, step);
create index alert_rules_scope_idx
  on public.alert_rules (org_id, property_id, active);

alter table public.settings enable row level security;
alter table public.approval_rules enable row level security;
alter table public.alert_rules enable row level security;
revoke all on public.settings, public.approval_rules, public.alert_rules
  from public, anon, authenticated;

create trigger trg_settings_updated_at before update on public.settings
  for each row execute function public.set_updated_at();
create trigger trg_approval_rules_updated_at before update on public.approval_rules
  for each row execute function public.set_updated_at();
create trigger trg_alert_rules_updated_at before update on public.alert_rules
  for each row execute function public.set_updated_at();

create trigger trg_settings_audit after insert or update or delete on public.settings
  for each row execute function public.audit_trigger();
create trigger trg_approval_rules_audit after insert or update or delete on public.approval_rules
  for each row execute function public.audit_trigger();
create trigger trg_alert_rules_audit after insert or update or delete on public.alert_rules
  for each row execute function public.audit_trigger();

create or replace function public._admin_config_require_perm(
  p_org_id uuid,
  p_property_id uuid,
  p_permission text
)
returns void
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_allowed boolean;
begin
  if auth.uid() is null or p_org_id is null or p_permission is null then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN';
  end if;
  if not exists (
    select 1 from public.organizations o where o.id = p_org_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_SCOPE';
  end if;

  if p_property_id is not null then
    if not exists (
      select 1 from public.properties p
      where p.id = p_property_id and p.org_id = p_org_id
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_CONFIG_SCOPE';
    end if;
    v_allowed := public.user_has_perm(auth.uid(), p_property_id, p_permission);
  else
    v_allowed := public.user_has_perm(auth.uid(), null, p_permission)
      and (
        exists (
          select 1
          from public.user_property_roles upr
          join public.roles r on r.id = upr.role_id and r.org_id = p_org_id and r.active
          join public.role_permissions rp
            on rp.role_id = r.id and rp.permission_code = p_permission
          where upr.user_id = auth.uid()
            and upr.property_id is null
            and upr.warehouse_ids is null
            and upr.outlet_ids is null
            and (now() at time zone 'Asia/Ho_Chi_Minh')::date
              between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
        )
        or exists (
          select 1
          from public.user_permission_overrides o
          where o.user_id = auth.uid()
            and o.property_id is null
            and o.permission_code = p_permission
            and o.effect = 'allow'
            and (now() at time zone 'Asia/Ho_Chi_Minh')::date
              between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
        )
      );
  end if;

  if not coalesce(v_allowed, false) then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN';
  end if;
end;
$$;

create or replace function public._admin_setting_default(p_key text)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  select case p_key
    when 'price_spike_pct' then '10'::jsonb
    when 'receiving_tolerance_pct' then '5'::jsonb
    when 'market_advance_deadline_hours' then '24'::jsonb
    when 'waste_approval_threshold_vnd' then '1000000'::jsonb
    when 'count_random_items' then '3'::jsonb
    when 'count_variance_threshold_pct' then '3'::jsonb
    when 'count_without_cc_factor' then '0.7'::jsonb
    when 'invoice_price_tolerance_pct' then '1'::jsonb
    else null
  end
$$;

create or replace function public._setting_get(
  p_org_id uuid,
  p_property_id uuid,
  p_key text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_value jsonb;
begin
  if p_org_id is null or not exists (
    select 1 from public.organizations o where o.id = p_org_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_SCOPE';
  end if;
  if public._admin_setting_default(p_key) is null then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;
  if p_property_id is not null and not exists (
    select 1 from public.properties p
    where p.id = p_property_id and p.org_id = p_org_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_SCOPE';
  end if;

  select coalesce(
    (
      select s.value from public.settings s
      where s.org_id = p_org_id and s.property_id = p_property_id and s.key = p_key
    ),
    (
      select s.value from public.settings s
      where s.org_id = p_org_id and s.property_id is null and s.key = p_key
    ),
    public._admin_setting_default(p_key)
  )
  into v_value;
  return v_value;
end;
$$;

create or replace function public.admin_settings_list(
  p_org_id uuid,
  p_property_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_settings jsonb;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.settings.manage'
  );

  select jsonb_agg(
    jsonb_build_object(
      'key', k.key,
      'value', public._setting_get(p_org_id, p_property_id, k.key) #>> '{}',
      'source', case
        when ps.id is not null then 'property'
        when os.id is not null then 'organization'
        else 'default'
      end
    )
    order by k.sort_order
  )
  into v_settings
  from (values
    ('price_spike_pct', 10),
    ('receiving_tolerance_pct', 20),
    ('market_advance_deadline_hours', 30),
    ('waste_approval_threshold_vnd', 40),
    ('count_random_items', 50),
    ('count_variance_threshold_pct', 60),
    ('count_without_cc_factor', 70),
    ('invoice_price_tolerance_pct', 80)
  ) as k(key, sort_order)
  left join public.settings ps
    on ps.org_id = p_org_id and ps.property_id = p_property_id and ps.key = k.key
  left join public.settings os
    on os.org_id = p_org_id and os.property_id is null and os.key = k.key;

  return coalesce(v_settings, '[]'::jsonb);
end;
$$;

create or replace function public.admin_setting_save(
  p_org_id uuid,
  p_property_id uuid,
  p_key text,
  p_value text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_value numeric;
  v_min numeric;
  v_max numeric;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.settings.manage'
  );

  if public._admin_setting_default(p_key) is null then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  v_value := p_value::numeric;
  case p_key
    when 'price_spike_pct' then v_min := 0; v_max := 1000;
    when 'receiving_tolerance_pct' then v_min := 0; v_max := 100;
    when 'market_advance_deadline_hours' then v_min := 1; v_max := 720;
    when 'waste_approval_threshold_vnd' then v_min := 0; v_max := 9999999999999999;
    when 'count_random_items' then v_min := 2; v_max := 3;
    when 'count_variance_threshold_pct' then v_min := 0; v_max := 100;
    when 'count_without_cc_factor' then v_min := 0; v_max := 1;
    when 'invoice_price_tolerance_pct' then v_min := 0; v_max := 100;
    else raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end case;

  if v_value < v_min or v_value > v_max
    or (p_key in ('market_advance_deadline_hours', 'count_random_items')
      and v_value <> trunc(v_value))
    or (p_key = 'waste_approval_threshold_vnd' and v_value <> trunc(v_value))
    or (p_key not in (
      'market_advance_deadline_hours',
      'waste_approval_threshold_vnd',
      'count_random_items',
      'count_without_cc_factor'
    ) and v_value <> round(v_value, 2))
    or (p_key = 'count_without_cc_factor' and v_value <> round(v_value, 4)) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  insert into public.settings (org_id, property_id, key, value, updated_by)
  values (p_org_id, p_property_id, p_key, to_jsonb(v_value), auth.uid())
  on conflict (org_id, property_id, key) do update
    set value = excluded.value, updated_by = excluded.updated_by;

  return jsonb_build_object('ok', true, 'key', p_key, 'value', v_value::text);
end;
$$;

create or replace function public.admin_approval_rules_list(
  p_org_id uuid,
  p_property_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_rules jsonb;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.approval_rules.manage'
  );

  select jsonb_agg(
    jsonb_build_object(
      'id', ar.id,
      'org_id', ar.org_id,
      'property_id', ar.property_id,
      'doc_type', ar.doc_type,
      'min_amount', ar.min_amount::text,
      'max_amount', ar.max_amount::text,
      'item_group_id', ar.item_group_id,
      'condition', ar.condition,
      'step', ar.step,
      'approver_role_id', ar.approver_role_id,
      'approver_role_name', r.name_vi,
      'approver_user_id', ar.approver_user_id,
      'required_perm', ar.required_perm
    )
    order by ar.doc_type, ar.min_amount, ar.step
  )
  into v_rules
  from public.approval_rules ar
  left join public.roles r on r.id = ar.approver_role_id
  where ar.org_id = p_org_id
    and ar.property_id is not distinct from p_property_id;

  return coalesce(v_rules, '[]'::jsonb);
end;
$$;

create or replace function public.admin_approval_approvers_list(
  p_org_id uuid,
  p_property_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_approvers jsonb;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.approval_rules.manage'
  );

  select jsonb_build_object(
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name_vi) order by r.name_vi)
      from public.roles r
      where r.org_id = p_org_id and r.active
    ), '[]'::jsonb),
    'users', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'name', coalesce(nullif(p.full_name, ''), p.employee_code, p.id::text),
          'employee_code', p.employee_code
        )
        order by p.full_name
      )
      from public.profiles p
      where p.active
        and exists (
          select 1
          from public.user_property_roles upr
          join public.roles r
            on r.id = upr.role_id and r.org_id = p_org_id and r.active
          where upr.user_id = p.id
            and (
              (p_property_id is null and upr.property_id is null
                and upr.warehouse_ids is null and upr.outlet_ids is null)
              or (p_property_id is not null
                and (upr.property_id is null or upr.property_id = p_property_id))
            )
            and (now() at time zone 'Asia/Ho_Chi_Minh')::date
              between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
        )
    ), '[]'::jsonb)
  )
  into v_approvers;

  return v_approvers;
end;
$$;

create or replace function public.admin_approval_rule_save(p_rule jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid;
  v_org_id uuid;
  v_property_id uuid;
  v_doc_type text;
  v_min numeric(18,2);
  v_max numeric(18,2);
  v_step integer;
  v_role_id uuid;
  v_user_id uuid;
  v_required_perm text;
  v_user_authorized boolean;
  v_old_property_id uuid;
begin
  if jsonb_typeof(p_rule) <> 'object' then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  v_org_id := (p_rule->>'org_id')::uuid;
  v_property_id := nullif(p_rule->>'property_id', '')::uuid;
  perform public._admin_config_require_perm(
    v_org_id, v_property_id, 'admin.approval_rules.manage'
  );

  v_id := nullif(p_rule->>'id', '')::uuid;
  v_doc_type := p_rule->>'doc_type';
  v_min := coalesce(nullif(p_rule->>'min_amount', '')::numeric, 0);
  v_max := nullif(p_rule->>'max_amount', '')::numeric;
  v_step := (p_rule->>'step')::integer;
  v_role_id := nullif(p_rule->>'approver_role_id', '')::uuid;
  v_user_id := nullif(p_rule->>'approver_user_id', '')::uuid;
  v_required_perm := coalesce(nullif(p_rule->>'required_perm', ''), 'po.approve');

  if v_doc_type is null
    or v_doc_type !~ '^[a-z][a-z0-9_]{1,39}$'
    or v_min < 0
    or (v_max is not null and v_max < v_min)
    or v_step is null or v_step < 1
    or ((v_role_id is null) = (v_user_id is null))
    or jsonb_typeof(coalesce(p_rule->'condition', '{}'::jsonb)) <> 'object'
    or not exists (select 1 from public.permissions p where p.code = v_required_perm) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  if v_role_id is not null and not exists (
    select 1 from public.roles r
    join public.role_permissions rp
      on rp.role_id = r.id and rp.permission_code = v_required_perm
    where r.id = v_role_id and r.org_id = v_org_id and r.active
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_APPROVER';
  end if;

  if v_user_id is not null then
    v_user_authorized := public.user_has_perm(
      v_user_id, v_property_id, v_required_perm
    ) and (
      exists (
        select 1
        from public.user_property_roles upr
        join public.roles r on r.id = upr.role_id and r.org_id = v_org_id and r.active
        join public.role_permissions rp
          on rp.role_id = r.id and rp.permission_code = v_required_perm
        where upr.user_id = v_user_id
          and (
            (v_property_id is null and upr.property_id is null)
            or (v_property_id is not null
              and (upr.property_id is null or upr.property_id = v_property_id))
          )
          and upr.warehouse_ids is null
          and upr.outlet_ids is null
          and (now() at time zone 'Asia/Ho_Chi_Minh')::date
            between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
      )
      or exists (
        select 1
        from public.user_permission_overrides o
        where o.user_id = v_user_id
          and o.permission_code = v_required_perm
          and o.effect = 'allow'
          and (o.property_id is null or o.property_id = v_property_id)
          and (now() at time zone 'Asia/Ho_Chi_Minh')::date
            between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
      )
    );
    if not coalesce(v_user_authorized, false) then
      raise exception using errcode = 'P0001', message = 'ERR_CONFIG_APPROVER';
    end if;
  end if;

  if v_id is null then
    insert into public.approval_rules (
      org_id, property_id, doc_type, min_amount, max_amount, item_group_id,
      condition, step, approver_role_id, approver_user_id, required_perm, created_by
    )
    values (
      v_org_id, v_property_id, v_doc_type, v_min, v_max,
      nullif(p_rule->>'item_group_id', '')::uuid,
      coalesce(p_rule->'condition', '{}'::jsonb), v_step,
      v_role_id, v_user_id, v_required_perm, auth.uid()
    )
    returning id into v_id;
  else
    select ar.property_id into v_old_property_id
    from public.approval_rules ar
    where ar.id = v_id and ar.org_id = v_org_id
    for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_CONFIG_NOT_FOUND';
    end if;
    perform public._admin_config_require_perm(
      v_org_id, v_old_property_id, 'admin.approval_rules.manage'
    );

    update public.approval_rules
    set property_id = v_property_id,
        doc_type = v_doc_type,
        min_amount = v_min,
        max_amount = v_max,
        item_group_id = nullif(p_rule->>'item_group_id', '')::uuid,
        condition = coalesce(p_rule->'condition', '{}'::jsonb),
        step = v_step,
        approver_role_id = v_role_id,
        approver_user_id = v_user_id,
        required_perm = v_required_perm
    where id = v_id and org_id = v_org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_CONFIG_NOT_FOUND';
    end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.admin_approval_rule_delete(p_rule_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_rule public.approval_rules%rowtype;
begin
  select * into v_rule
  from public.approval_rules
  where id = p_rule_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN';
  end if;

  perform public._admin_config_require_perm(
    v_rule.org_id, v_rule.property_id, 'admin.approval_rules.manage'
  );
  delete from public.approval_rules where id = p_rule_id;
  return jsonb_build_object('ok', true, 'id', p_rule_id);
end;
$$;

create or replace function public.admin_alert_rules_list(
  p_org_id uuid,
  p_property_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_rules jsonb;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.alert_rules.manage'
  );

  select jsonb_agg(
    jsonb_build_object(
      'id', ar.id,
      'org_id', ar.org_id,
      'property_id', ar.property_id,
      'code', ar.code,
      'threshold', ar.threshold,
      'channels', ar.channels,
      'urgent', ar.urgent,
      'active', ar.active
    )
    order by ar.code
  )
  into v_rules
  from public.alert_rules ar
  where ar.org_id = p_org_id
    and ar.property_id is not distinct from p_property_id;

  return coalesce(v_rules, '[]'::jsonb);
end;
$$;

create or replace function public.admin_alert_rule_save(p_rule jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid;
  v_org_id uuid;
  v_property_id uuid;
  v_code text;
  v_threshold jsonb;
  v_channels text[];
  v_urgent boolean;
  v_active boolean;
  v_old_property_id uuid;
begin
  if jsonb_typeof(p_rule) <> 'object' then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  v_org_id := (p_rule->>'org_id')::uuid;
  v_property_id := nullif(p_rule->>'property_id', '')::uuid;
  perform public._admin_config_require_perm(
    v_org_id, v_property_id, 'admin.alert_rules.manage'
  );

  v_id := nullif(p_rule->>'id', '')::uuid;
  v_code := p_rule->>'code';
  v_threshold := coalesce(p_rule->'threshold', '{}'::jsonb);
  if jsonb_typeof(coalesce(p_rule->'channels', '[]'::jsonb)) <> 'array' then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;
  v_channels := array(
    select jsonb_array_elements_text(coalesce(p_rule->'channels', '[]'::jsonb))
  );
  v_urgent := coalesce((p_rule->>'urgent')::boolean, false);
  v_active := coalesce((p_rule->>'active')::boolean, true);

  if v_code is null
    or v_code !~ '^[A-Z][A-Z0-9_]{1,63}$'
    or jsonb_typeof(v_threshold) <> 'object'
    or cardinality(v_channels) = 0
    or cardinality(v_channels) <> (
      select count(distinct channel)::integer
      from unnest(v_channels) as t(channel)
    )
    or not (v_channels <@ array['app', 'email', 'webpush', 'zalo']::text[]) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  if v_id is null then
    insert into public.alert_rules (
      org_id, property_id, code, threshold, channels, urgent, active, created_by
    )
    values (
      v_org_id, v_property_id, v_code, v_threshold, v_channels,
      v_urgent, v_active, auth.uid()
    )
    returning id into v_id;
  else
    select ar.property_id into v_old_property_id
    from public.alert_rules ar
    where ar.id = v_id and ar.org_id = v_org_id
    for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_CONFIG_NOT_FOUND';
    end if;
    perform public._admin_config_require_perm(
      v_org_id, v_old_property_id, 'admin.alert_rules.manage'
    );

    update public.alert_rules
    set property_id = v_property_id,
        code = v_code,
        threshold = v_threshold,
        channels = v_channels,
        urgent = v_urgent,
        active = v_active
    where id = v_id and org_id = v_org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_CONFIG_NOT_FOUND';
    end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.admin_alert_rule_delete(p_rule_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_rule public.alert_rules%rowtype;
begin
  select * into v_rule
  from public.alert_rules
  where id = p_rule_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN';
  end if;

  perform public._admin_config_require_perm(
    v_rule.org_id, v_rule.property_id, 'admin.alert_rules.manage'
  );
  delete from public.alert_rules where id = p_rule_id;
  return jsonb_build_object('ok', true, 'id', p_rule_id);
end;
$$;

revoke all on function public._admin_config_require_perm(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public._admin_setting_default(text)
  from public, anon, authenticated;
revoke all on function public._setting_get(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.admin_settings_list(uuid, uuid)
  from public, anon;
revoke all on function public.admin_setting_save(uuid, uuid, text, text)
  from public, anon;
revoke all on function public.admin_approval_rules_list(uuid, uuid)
  from public, anon;
revoke all on function public.admin_approval_approvers_list(uuid, uuid)
  from public, anon;
revoke all on function public.admin_approval_rule_save(jsonb)
  from public, anon;
revoke all on function public.admin_approval_rule_delete(uuid)
  from public, anon;
revoke all on function public.admin_alert_rules_list(uuid, uuid)
  from public, anon;
revoke all on function public.admin_alert_rule_save(jsonb)
  from public, anon;
revoke all on function public.admin_alert_rule_delete(uuid)
  from public, anon;
grant execute on function public.admin_settings_list(uuid, uuid) to authenticated;
grant execute on function public.admin_setting_save(uuid, uuid, text, text)
  to authenticated;
grant execute on function public.admin_approval_rules_list(uuid, uuid)
  to authenticated;
grant execute on function public.admin_approval_approvers_list(uuid, uuid)
  to authenticated;
grant execute on function public.admin_approval_rule_save(jsonb) to authenticated;
grant execute on function public.admin_approval_rule_delete(uuid) to authenticated;
grant execute on function public.admin_alert_rules_list(uuid, uuid) to authenticated;
grant execute on function public.admin_alert_rule_save(jsonb) to authenticated;
grant execute on function public.admin_alert_rule_delete(uuid) to authenticated;

insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109010613_admin_configuration',
  'INSERT',
  jsonb_build_object('event', 'admin_configuration_schema_created'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);