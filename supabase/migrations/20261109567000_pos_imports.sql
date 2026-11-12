-- ============================================================================
-- Q34 — 20261109567000_pos_imports
--   Nap file xuat POS (P2). Dinh dang cot la GIA DINH dua tren file gia lap
--   docs/samples/pos-export-sample-SYNTHETIC.csv — sua khi co file POS that.
--   * pos_imports (1 dong / file da nap) + pos_import_lines (1 dong / dong ban).
--     Ghi CHI qua RPC; client khong INSERT/UPDATE/DELETE truc tiep (RLS khong
--     co policy ghi). Khong ghi dish_sales / ton kho / tien — chi la du lieu
--     doi chieu va dieu kien mo kiem ke ca.
--   * Quyen moi pos.import (gm, chief_accountant, accountant, cost_controller).
--   * RPC pos_import_commit(property, file_name, sha256, lines jsonb):
--     dong bo nhom theo (business_date, shift) -> 1 pos_imports moi nhom;
--     cung file (sha256) nap lai -> ERR_ALREADY_IMPORTED; ma mon chua co trong
--     recipes.code duoc luu voi recipe_id NULL va bao lai (khong doan).
--   * count_open (sinh lai tu 20261109542000): shift_key can pos_imports
--     committed dung khach san + ngay + ca (ERR_POS_IMPORT_REQUIRED neu thieu),
--     ghi stock_counts.pos_import_id. Khong doi gi khac.
-- ============================================================================

insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values ('pos.import', 'Kho', 'Nạp file POS',
  'Nạp file xuất từ POS của ca để đối chiếu và mở kiểm kê theo ca.', 'sensitive', 2050)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'pos.import' from public.roles r
where r.is_system and r.code in ('gm', 'chief_accountant', 'accountant', 'cost_controller')
on conflict do nothing;

create table if not exists public.pos_imports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  business_date date not null,
  shift text not null check (btrim(shift) <> ''),
  file_name text not null check (btrim(file_name) <> ''),
  file_sha256 text not null check (file_sha256 ~ '^[0-9a-f]{64}$'),
  status text not null default 'committed' check (status in ('committed', 'voided')),
  row_count integer not null check (row_count > 0),
  total_amount numeric(18,2) not null check (total_amount >= 0),
  unmapped_count integer not null default 0 check (unmapped_count >= 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, business_date, shift, file_sha256)
);
create index if not exists pos_imports_property_date_idx
  on public.pos_imports (property_id, business_date, shift);

create table if not exists public.pos_import_lines (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null references public.pos_imports(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.properties(id),
  bill_no text not null check (btrim(bill_no) <> ''),
  business_date date not null,
  shift text not null,
  sold_time text,
  outlet text,
  item_code text not null check (btrim(item_code) <> ''),
  item_name text,
  recipe_id uuid,
  qty numeric(18,4) not null check (qty > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  amount numeric(18,2) not null check (amount >= 0),
  payment text,
  created_at timestamptz not null default now()
);
create index if not exists pos_import_lines_import_idx on public.pos_import_lines (import_id);

alter table public.pos_imports enable row level security;
alter table public.pos_import_lines enable row level security;

drop policy if exists pos_imports_select on public.pos_imports;
create policy pos_imports_select on public.pos_imports for select to authenticated
  using (public.has_perm(property_id, 'pos.import') or public.has_perm(property_id, 'count.open'));
drop policy if exists pos_import_lines_select on public.pos_import_lines;
create policy pos_import_lines_select on public.pos_import_lines for select to authenticated
  using (public.has_perm(property_id, 'pos.import'));

revoke insert, update, delete on public.pos_imports from anon, authenticated;
revoke insert, update, delete on public.pos_import_lines from anon, authenticated;

drop trigger if exists trg_pos_imports_audit on public.pos_imports;
create trigger trg_pos_imports_audit after insert or update or delete on public.pos_imports
  for each row execute function public.audit_trigger();

create or replace function public.pos_import_commit(
  p_property_id uuid,
  p_file_name text,
  p_file_sha256 text,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_entity uuid;
  v_group record;
  v_import_id uuid;
  v_ids uuid[] := '{}';
  v_rows integer := 0;
  v_unmapped_codes text[];
begin
  perform public.require_perm(p_property_id, 'pos.import');
  if p_file_name is null or btrim(p_file_name) = ''
     or p_file_sha256 is null or p_file_sha256 !~ '^[0-9a-f]{64}$'
     or p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 20000 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  select p.org_id, p.legal_entity_id into v_org, v_entity
  from public.properties p where p.id = p_property_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if exists (select 1 from public.pos_imports
             where property_id = p_property_id and file_sha256 = p_file_sha256
               and status = 'committed') then
    raise exception using errcode = '23505', message = 'ERR_ALREADY_IMPORTED';
  end if;

  -- Kiem tra tung dong (loi bat ky -> huy ca file).
  if exists (
    select 1 from jsonb_array_elements(p_lines) l
    where coalesce(btrim(l ->> 'bill_no'), '') = ''
       or coalesce(btrim(l ->> 'item_code'), '') = ''
       or coalesce(btrim(l ->> 'shift'), '') = ''
       or (l ->> 'business_date') is null
       or (l ->> 'business_date') !~ '^\d{4}-\d{2}-\d{2}$'
       or (l ->> 'qty') is null or (l ->> 'qty') !~ '^\d+(\.\d+)?$' or (l ->> 'qty')::numeric <= 0
       or (l ->> 'unit_price') is null or (l ->> 'unit_price') !~ '^\d+(\.\d+)?$'
       or (l ->> 'amount') is null or (l ->> 'amount') !~ '^\d+(\.\d+)?$'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  for v_group in
    select (l ->> 'business_date')::date as d, btrim(l ->> 'shift') as s
    from jsonb_array_elements(p_lines) l
    group by 1, 2 order by 1, 2
  loop
    insert into public.pos_imports (
      org_id, legal_entity_id, property_id, business_date, shift,
      file_name, file_sha256, row_count, total_amount
    )
    select v_org, v_entity, p_property_id, v_group.d, v_group.s,
      btrim(p_file_name), p_file_sha256, count(*),
      coalesce(sum((l ->> 'amount')::numeric), 0)
    from jsonb_array_elements(p_lines) l
    where (l ->> 'business_date')::date = v_group.d and btrim(l ->> 'shift') = v_group.s
    returning id into v_import_id;
    v_ids := v_ids || v_import_id;

    insert into public.pos_import_lines (
      import_id, org_id, property_id, bill_no, business_date, shift, sold_time,
      outlet, item_code, item_name, recipe_id, qty, unit_price, amount, payment
    )
    select v_import_id, v_org, p_property_id, btrim(l ->> 'bill_no'), v_group.d, v_group.s,
      nullif(btrim(l ->> 'time'), ''), nullif(btrim(l ->> 'outlet'), ''),
      btrim(l ->> 'item_code'), nullif(btrim(l ->> 'item_name'), ''),
      (select r.id from public.recipes r
        where r.org_id = v_org and r.code = btrim(l ->> 'item_code') limit 1),
      (l ->> 'qty')::numeric, (l ->> 'unit_price')::numeric, (l ->> 'amount')::numeric,
      nullif(btrim(l ->> 'payment'), '')
    from jsonb_array_elements(p_lines) l
    where (l ->> 'business_date')::date = v_group.d and btrim(l ->> 'shift') = v_group.s;

    update public.pos_imports pi
    set unmapped_count = (select count(*) from public.pos_import_lines x
                          where x.import_id = pi.id and x.recipe_id is null)
    where pi.id = v_import_id;
    v_rows := v_rows + (select row_count from public.pos_imports where id = v_import_id);
  end loop;

  select coalesce(array_agg(distinct x.item_code order by x.item_code), '{}')
  into v_unmapped_codes
  from public.pos_import_lines x
  where x.import_id = any (v_ids) and x.recipe_id is null;

  return jsonb_build_object(
    'ok', true,
    'import_ids', to_jsonb(v_ids),
    'imports', cardinality(v_ids),
    'rows', v_rows,
    'unmapped_codes', to_jsonb(v_unmapped_codes)
  );
end;
$$;

revoke all on function public.pos_import_commit(uuid, text, text, jsonb) from public, anon;
grant execute on function public.pos_import_commit(uuid, text, text, jsonb) to authenticated, service_role;

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
