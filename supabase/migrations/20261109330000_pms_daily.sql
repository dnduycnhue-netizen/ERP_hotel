-- ===========================================================================
-- T-036 — Form PMS ngày (pms_daily_upsert).
--   * Bang `pms_daily_stats`: so lieu van hanh ngay theo khach san
--     (phong ban, khach, an sang...), 1 dong / (property, business_date).
--   * RPC `pms_daily_upsert`: nhap lan dau tao dong; nhap lai cung ngay thi
--     CAP NHAT dong do (khong tao dong trung) — lich su sua duoc ghi tu dong
--     bang trigger `audit_trigger()` chung cua repo vao `audit_log`
--     (xem 20261108140958: trigger ghi INSERT/UPDATE/DELETE kem old/new
--     jsonb, khong sua/xoa duoc); doc lich su qua RPC `pms_daily_history`
--     vi RLS tren `audit_log` chi cho `audit.view_all` doc truc tiep.
--   * Quyen: TAI DUNG `pms.input` (da co trong catalog 141000, seed da gan
--     cho `front_desk` + `accountant`) — KHONG them ma moi. Migration nay
--     chi gan them `pms.input` cho `owner` + `gm` (tien le T-035 da lam
--     voi `alert.receive.minibar_mismatch`): neu khong gan, Duy (owner)
--     va gm khong mo duoc form de nhap/kim tra.
--   * Quyet dinh (ghi Q63): chan ngay tuong lai — so lieu PMS ngay la so
--     lieu da xay ra, khong phai ke hoach.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Bang pms_daily_stats.
--    `entered_by` = nguoi nhap lan cuoi (cap nhat moi lan upsert);
--    nguoi nhap goc + toan bo lich su nam trong `audit_log` (trigger §2).
-- ---------------------------------------------------------------------------
create table public.pms_daily_stats (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  business_date date not null,
  rooms_available integer not null check (rooms_available >= 0),
  rooms_sold integer not null check (rooms_sold >= 0),
  guests integer not null check (guests >= 0),
  breakfast_pax integer not null check (breakfast_pax >= 0),
  extra_beds integer not null check (extra_beds >= 0),
  checkouts integer not null check (checkouts >= 0),
  source text not null default 'form' check (source in ('form', 'file')),
  entered_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (property_id, business_date)
);

-- ---------------------------------------------------------------------------
-- 2. Write-guard (chi ghi qua RPC) + updated_at + audit trigger chung.
-- ---------------------------------------------------------------------------
create or replace function public._pms_daily_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.pms_daily_guard_bypass', true), '') <> 'on' then
    raise exception using errcode = 'P0001',
      message = format('ERR_WRITE_GUARD: %s chi duoc ghi qua RPC', TG_TABLE_NAME);
  end if;
  return coalesce(new, old);
end;
$$;

create trigger pms_daily_stats_write_guard
before insert or update or delete on public.pms_daily_stats
for each row execute function public._pms_daily_write_guard();

create trigger pms_daily_stats_updated_at
before update on public.pms_daily_stats
for each row execute function public.set_updated_at();

-- Nhat ky sua: trigger chung cua repo (141000 dung cho bang master data).
-- Ghi ca INSERT (tao moi) lan UPDATE (sua) vao audit_log, kem old/new jsonb.
create trigger trg_pms_daily_stats_audit
after insert or update or delete on public.pms_daily_stats
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 3. RLS: bat 100% + policy SELECT-only (mau T-035 §5).
--    Chi nguoi co `pms.input` cua dung khach san moi doc duoc.
--    Dung `in (select public.my_property_ids())` — TUYET DOI KHONG dung
--    `= any (public.my_property_ids())` (loi 0A000 khi db push).
-- ---------------------------------------------------------------------------
alter table public.pms_daily_stats enable row level security;

create policy pms_daily_stats_select on public.pms_daily_stats
for select using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'pms.input')
);

-- ---------------------------------------------------------------------------
-- 4. Gan `pms.input` (ma da co) cho owner + gm.
--    Seed chi gan cho front_desk + accountant; khong gan them thi owner/gm
--    khong mo duoc form (ca layout frontdesk cung chan theo quyen nay).
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, 'pms.input'
from public.roles r
where r.code in ('owner', 'gm')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 5. Helper noi bo: doc 1 so nguyen >= 0 tu p_stats (khong grant execute).
-- ---------------------------------------------------------------------------
create or replace function public._pms_daily_stat_int(p_stats jsonb, p_key text)
returns integer
language plpgsql
immutable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_val jsonb := p_stats -> p_key;
  v_num numeric;
begin
  if v_val is null or jsonb_typeof(v_val) <> 'number' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  v_num := (v_val)::text::numeric;
  if v_num <> trunc(v_num) or v_num < 0 or v_num > 2147483647 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  return v_num::integer;
end;
$$;

revoke all on function public._pms_daily_stat_int(jsonb, text)
  from public, anon, authenticated;
revoke all on function public._pms_daily_write_guard()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPC: pms_daily_upsert — le tan nhap so lieu ngay.
--    p_stats: {rooms_available, rooms_sold, guests, breakfast_pax,
--    extra_beds, checkouts, source?} — ca 6 so bat buoc, so nguyen >= 0.
--    source tuy chon ('form'|'file', mac dinh 'form'); khi sua ma khong
--    truyen source thi giu nguyen source cu.
-- ---------------------------------------------------------------------------
create or replace function public.pms_daily_upsert(
  p_property_id uuid,
  p_date date,
  p_stats jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_prop public.properties%rowtype;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_existing public.pms_daily_stats%rowtype;
  v_rooms_available integer;
  v_rooms_sold integer;
  v_guests integer;
  v_breakfast_pax integer;
  v_extra_beds integer;
  v_checkouts integer;
  v_source text := 'form';
  v_source_provided boolean := false;
  v_final_source text;
  v_id uuid;
  v_is_new boolean;
begin
  select * into v_prop from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(p_property_id, 'pms.input');

  -- So lieu ngay la so lieu da xay ra: khong nhap ngay tuong lai (Q63).
  if p_date is null or p_date > v_today then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if p_stats is null or jsonb_typeof(p_stats) <> 'object' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_rooms_available := public._pms_daily_stat_int(p_stats, 'rooms_available');
  v_rooms_sold := public._pms_daily_stat_int(p_stats, 'rooms_sold');
  v_guests := public._pms_daily_stat_int(p_stats, 'guests');
  v_breakfast_pax := public._pms_daily_stat_int(p_stats, 'breakfast_pax');
  v_extra_beds := public._pms_daily_stat_int(p_stats, 'extra_beds');
  v_checkouts := public._pms_daily_stat_int(p_stats, 'checkouts');

  if p_stats ? 'source' then
    v_source_provided := true;
    v_source := p_stats ->> 'source';
    if v_source not in ('form', 'file') then
      raise exception 'ERR_INVALID_VALUE';
    end if;
  end if;

  if v_rooms_sold > v_rooms_available then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.pms_daily_guard_bypass', 'on', true);

  select * into v_existing
  from public.pms_daily_stats s
  where s.property_id = p_property_id and s.business_date = p_date;

  if found then
    v_is_new := false;
    v_final_source := case when v_source_provided then v_source else v_existing.source end;
    update public.pms_daily_stats s set
      rooms_available = v_rooms_available,
      rooms_sold = v_rooms_sold,
      guests = v_guests,
      breakfast_pax = v_breakfast_pax,
      extra_beds = v_extra_beds,
      checkouts = v_checkouts,
      source = v_final_source,
      entered_by = auth.uid(),
      updated_at = now()
    where s.id = v_existing.id
    returning s.id into v_id;
  else
    v_is_new := true;
    v_final_source := v_source;
    insert into public.pms_daily_stats
      (org_id, legal_entity_id, property_id, business_date,
       rooms_available, rooms_sold, guests, breakfast_pax, extra_beds, checkouts,
       source, entered_by, created_by)
    values
      (v_prop.org_id, v_prop.legal_entity_id, p_property_id, p_date,
       v_rooms_available, v_rooms_sold, v_guests, v_breakfast_pax, v_extra_beds, v_checkouts,
       v_final_source, auth.uid(), auth.uid())
    returning id into v_id;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'property_id', p_property_id,
    'business_date', p_date, 'is_new', v_is_new,
    'stats', jsonb_build_object(
      'rooms_available', v_rooms_available, 'rooms_sold', v_rooms_sold,
      'guests', v_guests, 'breakfast_pax', v_breakfast_pax,
      'extra_beds', v_extra_beds, 'checkouts', v_checkouts
    ),
    'source', v_final_source, 'entered_by', auth.uid()
  );
end;
$$;

revoke all on function public.pms_daily_upsert(uuid, date, jsonb)
  from public, anon, authenticated;
grant execute on function public.pms_daily_upsert(uuid, date, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPC: pms_daily_history — lich su nhap/sua cua 1 ngay.
--    Doc `audit_log` (trigger §2 ghi) qua SECURITY DEFINER vi RLS tren
--    `audit_log` chi cho `audit.view_all` doc truc tiep (141000).
--    Tra ve moi nhat truoc, kem ten nguoi sua (join profiles).
-- ---------------------------------------------------------------------------
create or replace function public.pms_daily_history(
  p_property_id uuid,
  p_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_prop public.properties%rowtype;
  v_row public.pms_daily_stats%rowtype;
  v_entries jsonb;
begin
  select * into v_prop from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(p_property_id, 'pms.input');

  select * into v_row
  from public.pms_daily_stats s
  where s.property_id = p_property_id and s.business_date = p_date;

  if not found then
    return jsonb_build_object('ok', true, 'entries', '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'action', a.action,
        'at', a.at,
        'actor_id', a.actor,
        'actor_name', coalesce(p.full_name, ''),
        'old_stats', case when a.old_data is null then null else jsonb_build_object(
          'rooms_available', (a.old_data ->> 'rooms_available')::integer,
          'rooms_sold', (a.old_data ->> 'rooms_sold')::integer,
          'guests', (a.old_data ->> 'guests')::integer,
          'breakfast_pax', (a.old_data ->> 'breakfast_pax')::integer,
          'extra_beds', (a.old_data ->> 'extra_beds')::integer,
          'checkouts', (a.old_data ->> 'checkouts')::integer
        ) end,
        'new_stats', case when a.new_data is null then null else jsonb_build_object(
          'rooms_available', (a.new_data ->> 'rooms_available')::integer,
          'rooms_sold', (a.new_data ->> 'rooms_sold')::integer,
          'guests', (a.new_data ->> 'guests')::integer,
          'breakfast_pax', (a.new_data ->> 'breakfast_pax')::integer,
          'extra_beds', (a.new_data ->> 'extra_beds')::integer,
          'checkouts', (a.new_data ->> 'checkouts')::integer
        ) end
      )
      order by a.at desc, a.id desc
    ),
    '[]'::jsonb
  )
  into v_entries
  from public.audit_log a
  left join public.profiles p on p.id = a.actor
  where a.table_name = 'pms_daily_stats'
    and a.row_id = v_row.id::text;

  return jsonb_build_object('ok', true, 'entries', v_entries);
end;
$$;

revoke all on function public.pms_daily_history(uuid, date)
  from public, anon, authenticated;
grant execute on function public.pms_daily_history(uuid, date)
  to authenticated;

-- Audit trail cho chinh migration nay (mau T-026).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109330000_pms_daily',
  'INSERT',
  jsonb_build_object('event', 'pms_daily_completed', 'task', 'T-036'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
