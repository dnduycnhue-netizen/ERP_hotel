-- ============================================================================
-- Q254 — 20261109569000_property_modules
--   Module hoa: bat/tat theo TUNG KHACH SAN hai module tuy chon
--     * hk_frontdesk = Buong phong & Le tan (minibar, xe day, chuan setup phong,
--       nhap so lieu PMS hang ngay);
--     * restaurant   = Nha hang (mon/cong thuc, buffet, tiec, ban hang, nap POS).
--   Loi (mua hang, nhan hang, kho, tai chinh, bao cao chung, canh bao) luon bat.
--   Mac dinh KHONG co dong = BAT (khach san hien co khong doi hanh vi).
--   Chan o tang du lieu: trigger BEFORE INSERT/UPDATE tren bang cua module ->
--   ERR_MODULE_DISABLED (RPC ghi nao cung bi chan, khong can sua tung RPC).
--   Du lieu cu giu nguyen; bat lai la dung tiep.
--   count_open: kiem ke theo ca chi doi file POS khi module Nha hang dang bat.
--   Quyen moi admin.modules.manage (owner, sys_admin).
-- ============================================================================

create table if not exists public.property_modules (
  property_id uuid not null references public.properties(id) on delete cascade,
  module text not null check (module in ('hk_frontdesk', 'restaurant')),
  enabled boolean not null default true,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  primary key (property_id, module)
);

alter table public.property_modules enable row level security;
drop policy if exists property_modules_select on public.property_modules;
create policy property_modules_select on public.property_modules for select to authenticated
  using (property_id in (select public.my_property_ids()));
revoke insert, update, delete on public.property_modules from anon, authenticated;

drop trigger if exists trg_property_modules_audit on public.property_modules;
create trigger trg_property_modules_audit after insert or update or delete on public.property_modules
  for each row execute function public.audit_trigger();

insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values (
  'admin.modules.manage', 'Quản trị', 'Bật/tắt module',
  'Bật hoặc tắt module Buồng phòng & Lễ tân, Nhà hàng cho từng khách sạn.',
  'sensitive', 81
)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'admin.modules.manage'
from public.roles r
where r.is_system and r.code in ('sys_admin', 'owner')
on conflict (role_id, permission_code) do nothing;

-- Khong co dong = bat.
create or replace function public.module_enabled(p_property_id uuid, p_module text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select pm.enabled from public.property_modules pm
      where pm.property_id = p_property_id and pm.module = p_module),
    true);
$$;

create or replace function public.require_module(p_property_id uuid, p_module text)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.module_enabled(p_property_id, p_module) then
    raise exception using errcode = 'P0001', message = 'ERR_MODULE_DISABLED';
  end if;
end;
$$;

-- Trigger chung: TG_ARGV[0] = ma module; bang phai co cot property_id.
create or replace function public._module_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.require_module(new.property_id, tg_argv[0]);
  return new;
end;
$$;

do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('hk_frontdesk', 'minibar_checks'),
      ('hk_frontdesk', 'minibar_check_lines'),
      ('hk_frontdesk', 'minibar_price_list'),
      ('hk_frontdesk', 'pms_daily_stats'),
      ('hk_frontdesk', 'room_setup_standards'),
      ('hk_frontdesk', 'trolley_par_levels'),
      ('hk_frontdesk', 'trolley_shifts'),
      ('restaurant', 'banquets'),
      ('restaurant', 'banquet_halls'),
      ('restaurant', 'buffet_sessions'),
      ('restaurant', 'dish_sales'),
      ('restaurant', 'pos_imports'),
      ('restaurant', 'pos_import_lines')
    ) as t(module, tbl)
  loop
    execute format('drop trigger if exists trg_%1$s_module_guard on public.%1$s', r.tbl);
    execute format(
      'create trigger trg_%1$s_module_guard before insert or update on public.%1$s '
      'for each row execute function public._module_guard(%2$L)', r.tbl, r.module);
  end loop;
end $$;

-- Bat/tat 1 module cua 1 khach san (chi quan tri chuoi).
create or replace function public.admin_module_set(
  p_property_id uuid, p_module text, p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.require_perm(null, 'admin.modules.manage');
  if p_module is null or p_module not in ('hk_frontdesk', 'restaurant')
     or p_enabled is null
     or not exists (select 1 from public.properties where id = p_property_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  insert into public.property_modules (property_id, module, enabled, updated_by, updated_at)
  values (p_property_id, p_module, p_enabled, auth.uid(), now())
  on conflict (property_id, module) do update
    set enabled = excluded.enabled, updated_by = excluded.updated_by, updated_at = now();
  return jsonb_build_object('ok', true, 'property_id', p_property_id,
    'module', p_module, 'enabled', p_enabled);
end;
$$;

-- Cac module dang bat cua 1 khach san (moi nguoi co quyen vao KS deu doc duoc).
create or replace function public.property_modules_get(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null
     or p_property_id not in (select public.my_property_ids()) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  return jsonb_build_object(
    'hk_frontdesk', public.module_enabled(p_property_id, 'hk_frontdesk'),
    'restaurant', public.module_enabled(p_property_id, 'restaurant'));
end;
$$;

-- Tong quan cho man quan tri: moi khach san + trang thai 2 module.
create or replace function public.admin_modules_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.require_perm(null, 'admin.modules.manage');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'property_id', p.id, 'code', p.code, 'name', p.name,
      'hk_frontdesk', public.module_enabled(p.id, 'hk_frontdesk'),
      'restaurant', public.module_enabled(p.id, 'restaurant')
    ) order by p.code)
    from public.properties p), '[]'::jsonb);
end;
$$;

revoke all on function public.module_enabled(uuid, text) from public, anon;
revoke all on function public.require_module(uuid, text) from public, anon;
revoke all on function public._module_guard() from public, anon, authenticated;
revoke all on function public.admin_module_set(uuid, text, boolean) from public, anon;
revoke all on function public.property_modules_get(uuid) from public, anon;
revoke all on function public.admin_modules_overview() from public, anon;
grant execute on function public.module_enabled(uuid, text) to authenticated, service_role;
grant execute on function public.require_module(uuid, text) to authenticated, service_role;
grant execute on function public.admin_module_set(uuid, text, boolean) to authenticated, service_role;
grant execute on function public.property_modules_get(uuid) to authenticated, service_role;
grant execute on function public.admin_modules_overview() to authenticated, service_role;

create or replace function public.count_open(
  p_warehouse_id uuid,
  p_kind text,
  p_business_date date,
  p_shift text default null,
  p_counter_ids uuid[] default null,
  p_client_uuid uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wh public.warehouses%rowtype;
  v_property_id uuid;
  v_org_id uuid;
  v_entity_id uuid;
  v_business_date date := coalesce(
    p_business_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_counters uuid[] := coalesce(p_counter_ids, '{}');
  v_counter uuid;
  v_doc_no text;
  v_id uuid;
  v_lines integer;
  v_existing jsonb;
  v_pos_import_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_warehouse_id is null or p_kind is null
    or p_kind not in ('shift_key', 'monthly_full', 'cycle', 'trolley', 'minibar_audit')
    or v_business_date is null or not isfinite(v_business_date) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_wh from public.warehouses where id = p_warehouse_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;
  v_property_id := v_wh.property_id;

  perform public.require_perm(v_property_id, 'count.open', p_warehouse_id);

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = v_property_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- Idempotency: goi lai cung client_uuid tra dot cu.
  if p_client_uuid is not null then
    select jsonb_build_object('ok', true, 'id', id, 'doc_no', doc_no,
      'lines_created', (select count(*) from public.stock_count_lines where count_id = stock_counts.id))
    into v_existing
    from public.stock_counts
    where client_uuid = p_client_uuid;
    if found then
      return v_existing;
    end if;
  end if;

  -- Kiem ke ca yeu cau file POS cua ca do (09 §5, Q34): phai co pos_imports
  -- da nap (committed) cho dung khach san + ngay + ca.
  if p_kind = 'shift_key' then
    if p_shift is null or btrim(p_shift) = '' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    -- Khach san khong bat module Nha hang thi khong co file POS de doi chieu:
    -- bo qua yeu cau (pos_import_id de NULL).
    if public.module_enabled(v_property_id, 'restaurant') then
    select pi.id into v_pos_import_id
    from public.pos_imports pi
    where pi.property_id = v_property_id
      and pi.business_date = v_business_date
      and pi.shift = p_shift
      and pi.status = 'committed'
    order by pi.created_at desc
    limit 1;
    if v_pos_import_id is null then
      raise exception using errcode = 'P0001', message = 'ERR_POS_IMPORT_REQUIRED';
    end if;
    end if;
  end if;

  -- Ngay nghiep vu khong nam trong ky da khoa / ngay da khoa (giong _post_move).
  if exists (
    select 1 from public.accounting_periods
    where legal_entity_id = v_entity_id
      and year = extract(year from v_business_date)::integer
      and month = extract(month from v_business_date)::integer
      and status = 'closed'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_CLOSED';
  end if;

  if exists (
    select 1 from public.day_locks
    where warehouse_id = p_warehouse_id
      and business_date = v_business_date
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_DAY_LOCKED';
  end if;

  -- Chi 1 dot monthly_full dang mo cho 1 kho.
  if p_kind = 'monthly_full' and exists (
    select 1 from public.stock_counts
    where warehouse_id = p_warehouse_id and kind = 'monthly_full'
      and status in ('open', 'counting', 'recount', 'submitted', 'locked')
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_ALREADY_OPEN';
  end if;

  -- Doi dem: monthly_full >= 2 nguoi khac nhau; moi nguoi phai ton tai.
  if array_length(v_counters, 1) is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if p_kind = 'monthly_full' and array_length(v_counters, 1) < 2 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  foreach v_counter in array v_counters loop
    if v_counter is null or not exists (
      select 1 from auth.users where id = v_counter
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
  end loop;
  if (select count(*) from (select distinct unnest(v_counters) as u) s)
    <> array_length(v_counters, 1) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- SOD_COUNT_INDEPENDENT (04 §6): dot thang phai co >= 1 nguoi dem khong co
  -- quyen receiving.post / requisition.issue tai kho do.
  if p_kind = 'monthly_full' and not exists (
    select 1 from unnest(v_counters) as u(uid)
    where not public._count_user_has_perm(u.uid, v_property_id, 'receiving.post', p_warehouse_id)
      and not public._count_user_has_perm(u.uid, v_property_id, 'requisition.issue', p_warehouse_id)
  ) then
    perform public._sod_check(v_property_id, 'SOD_COUNT_INDEPENDENT');
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity_id, 'CNT', v_business_date);

  insert into public.stock_counts (
    org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind,
    business_date, shift, status, counter_ids, opened_by, client_uuid,
    created_by, pos_import_id
  ) values (
    v_org_id, v_entity_id, v_property_id, p_warehouse_id, v_doc_no, p_kind,
    v_business_date, p_shift, 'open', v_counters, auth.uid(), p_client_uuid,
    auth.uid(), v_pos_import_id
  )
  returning id into v_id;

  -- Khoa dong ton hien tai de snapshot nhat quan: _post_move cung khoa dong
  -- nay (FOR UPDATE) nen post dong thoi bi chan toi khi mo dot xong.
  perform 1 from public.stock_balances
  where warehouse_id = p_warehouse_id
  for update;

  -- Snapshot ton so: 1 dong / ma hang, cong don qua cac lo.
  insert into public.stock_count_lines (count_id, org_id, item_id, book_qty, theoretical_qty)
  select v_id, v_org_id, sb.item_id, sum(sb.qty),
    case when p_kind = 'monthly_full' then sum(sb.qty) else null end
  from public.stock_balances sb
  where sb.warehouse_id = p_warehouse_id and sb.qty <> 0
  group by sb.item_id;

  get diagnostics v_lines = row_count;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no, 'lines_created', v_lines
  );
end;
$$;
