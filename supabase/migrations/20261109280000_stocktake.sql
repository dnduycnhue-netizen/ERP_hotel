-- ============================================================================
-- T-032: Kiem ke thang mu + dieu chinh + khoa ngay/ky — Migration 09
-- Bang: stock_counts, stock_count_lines, count_adjustments.
-- RPC moi: count_open, count_record_line, count_submit, count_lock,
--   count_adjust_post, count_add_counter, count_cancel.
-- Redefine: period_close (them 3 dieu kien khoa ky theo 05 §10).
-- View: v_count_sheet (mu), v_count_result (day du, co count.view_variance).
-- Trigger: trg_stock_moves_count_freeze (ERR_COUNT_FREEZE).
-- Can cu: docs/03-DATA-MODEL.md A5, docs/05-BUSINESS-RULES.md §6 + §10,
--   docs/09-API-RPC.md §5 + §11, docs/04-SECURITY-RLS.md §6 + §8,
--   docs/modules/M05-inventory.md, docs/11-TESTING.md §5.
-- AC: nguoi dem khong doc duoc book_qty; kho dang kiem ke -> ERR_COUNT_FREEZE.
--
-- Quyet dinh tu chot (danh so de Duy doi chieu; chi tiet them trong bao cao):
--   D1. Dong bang thuc thi bang trigger BEFORE INSERT tren stock_moves (khong
--       sua _post_move — migration cu bat bien). Chi kind='monthly_full' dong
--       bang. Mien tru move 'adjust_count' cua chinh dot kiem dang dieu chinh
--       (status='locked', source_doc_type='stock_count').
--   D2. Nguoi dem gan luc mo dot qua p_counter_ids (mo rong chu ky spec);
--       monthly_full yeu cau >= 2 nguoi khac nhau; quyen tung nguoi kiem luc
--       ho tac dong (record/submit). SOD_COUNT_INDEPENDENT kiem o luc mo
--       (fail fast) VA kiem lai o luc submit (phong khi doi doi dem).
--   D3. Vong dem: counted_qty_1/_2 + counted_by_1/_2; nguoi ghi dau -> _1,
--       nguoi thu hai khac -> _2; ghi lai ghi de vong cua chinh minh. Dem lai
--       reset _1/_2 cua dong bi flag 'recount' (so cu khong hien — 06 §3.2).
--   D4. Submit vong 1: _1 = _2 -> final; khac nhau hoac lech so sach (vuot
--       0.0001) -> 'recount'. Vong 2: final = _2 neu co khong thi _1; con
--       lech hoac hai nguoi van khac nhau -> 'red'. Response chi co ID
--       (recount_line_ids, red_line_ids), khong tra so.
--   D5. count_submit(p_pins text[]): 1 PIN cho moi nguoi dem, khop khong phu
--       thuoc thu tu (crypt theo tung user); thieu/sai -> ERR_PIN_INVALID.
--       Nguoi submit phai la 1 trong counter_ids.
--   D6. Ly do dong do dua qua count_lock(p_reasons jsonb); thieu ly do bat ky
--       dong do nao -> ERR_REASON_REQUIRED.
--   D7. count_adjust_post (gm): ghi adjust_count theo gia binh quan hien tai
--       (moving_avg) / gia lop (FIFO, do _post_move tinh); tong gia tri doc
--       lai tu stock_moves cho chinh xac. Khong lech -> 0 move, van mo bang.
--   D8. period_close dinh nghia lai, giu nguyen chu ky: them 3 dieu kien
--       (05 §10): moi kho cua phap nhan co dot monthly_full thang do o
--       'locked'/'adjusted' (ERR_COUNT_NOT_LOCKED); khong PO
--       partially_received co expected_date qua 30 ngay (ERR_PO_UNRESOLVED);
--       khong tam ung 'overdue' (ERR_ADVANCE_OVERDUE).
--   D9. Mu o tang du lieu: v_count_sheet chi nguoi dem trong counter_ids,
--       chi hien so cua chinh minh (my_counted_qty/my_count_detail), an so cu
--       khi dem lai; v_count_result yeu cau count.view_variance VA khong nam
--       trong counter_ids. SELECT truc tiep stock_count_lines chi cho nguoi
--       co count.view_variance va khong phai nguoi dem.
--  D10. Can ruou theo can (05 §6.3): ml = (gram - tare_g) / density_g_ml;
--       doi sang stock_uom qua he so mua neu stock_uom <> 'ml'.
--  D11. kind='shift_key' yeu cau pos_imports (09 §5) nhung bang pos_imports
--       chua co migration nao tao -> count_open luon tra ERR_POS_IMPORT_REQUIRED
--       (xem Q34).
--  D12. Them 2 RPC ngoai spec: count_add_counter (them nguoi dem khi doi dem,
--       quyen count.open) va count_cancel (thoat dot mo nham/bo do, ly do bat
--       buoc, chi truoc khi lock) — tranh kho bi dong bang vinh vien.
--  D13. Khong co ma quyen moi: count.*/day.*/period.* da co trong catalog
--       (141000) va seed gan vai tro (gm, chief_accountant, accountant,
--       cost_controller, storekeeper, chef, bartender). Khong alert moi.
--  D14. Dong kiem o muc ma hang (khong co lot): adjust_count ghi lot NULL
--       (xem Q33).
--  D15. Ma loi moi: ERR_COUNT_NOT_LOCKED, ERR_COUNT_ALREADY_OPEN,
--       ERR_COUNT_INCOMPLETE, ERR_PO_UNRESOLVED, ERR_ADVANCE_OVERDUE.
--       (ERR_COUNT_FREEZE, ERR_POS_IMPORT_REQUIRED da co trong 09 §11.)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Bang stock_counts / stock_count_lines / count_adjustments
-- ---------------------------------------------------------------------------
create table public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  warehouse_id uuid not null references public.warehouses(id),
  doc_no text not null check (btrim(doc_no) <> ''),
  kind text not null check (kind in (
    'shift_key', 'monthly_full', 'cycle', 'trolley', 'minibar_audit'
  )),
  business_date date not null check (isfinite(business_date)),
  shift text,
  status text not null default 'open' check (status in (
    'open', 'counting', 'recount', 'submitted', 'locked', 'adjusted',
    'cancelled'
  )),
  pos_import_id uuid,
  counter_ids uuid[] not null default '{}',
  opened_by uuid not null references auth.users(id),
  locked_by uuid references auth.users(id),
  locked_at timestamptz,
  adjusted_by uuid references auth.users(id),
  adjusted_at timestamptz,
  cancel_reason text,
  cancelled_by uuid references auth.users(id),
  cancelled_at timestamptz,
  client_uuid uuid unique,
  created_by uuid not null references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (property_id, legal_entity_id, org_id)
    references public.properties(id, legal_entity_id, org_id),
  foreign key (warehouse_id, property_id)
    references public.warehouses(id, property_id)
);

-- Chi 1 dot monthly_full dang mo cho 1 kho (dong bang khong chong cheo).
create unique index stock_counts_one_open_monthly_idx
  on public.stock_counts (warehouse_id)
  where kind = 'monthly_full'
    and status in ('open', 'counting', 'recount', 'submitted', 'locked');

create index stock_counts_warehouse_status_idx
  on public.stock_counts (warehouse_id, status);

create table public.stock_count_lines (
  id uuid primary key default gen_random_uuid(),
  count_id uuid not null references public.stock_counts(id),
  org_id uuid not null references public.organizations(id),
  item_id uuid not null references public.items(id),
  count_detail jsonb not null default '{}'::jsonb,
  count_detail_by uuid references auth.users(id),
  bottle_weight_g numeric(18,4),
  counted_qty_1 numeric(18,4),
  counted_qty_2 numeric(18,4),
  counted_by_1 uuid references auth.users(id),
  counted_by_2 uuid references auth.users(id),
  final_qty numeric(18,4),
  book_qty numeric(18,4),
  theoretical_qty numeric(18,4),
  variance_qty numeric(18,4),
  variance_pct numeric(18,4),
  flag text check (flag in ('ok', 'recount', 'red')),
  reason_code text,
  explanation text,
  photo_ids uuid[] not null default '{}',
  client_uuid uuid unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (count_id, item_id),
  foreign key (count_id, org_id) references public.stock_counts(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id)
);

create index stock_count_lines_count_idx
  on public.stock_count_lines (count_id);

create table public.count_adjustments (
  id uuid primary key default gen_random_uuid(),
  count_id uuid not null unique references public.stock_counts(id),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  status text not null default 'pending' check (status in ('pending', 'approved')),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  note text,
  moves_posted integer not null default 0 check (moves_posted >= 0),
  total_value numeric(18,2) not null default 0,
  created_by uuid not null references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (count_id, org_id) references public.stock_counts(id, org_id),
  foreign key (property_id, org_id) references public.properties(id, org_id)
);

-- ---------------------------------------------------------------------------
-- 2. Trigger updated_at + write-guard + status-guard (mau T-030)
-- ---------------------------------------------------------------------------
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'stock_counts', 'stock_count_lines', 'count_adjustments'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

create or replace function public._count_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.count_guard_bypass', true), '') <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public._count_write_guard()
  from public, anon, authenticated;

create or replace function public._count_status_guard()
returns trigger
language plpgsql
as $$
begin
  if (
    old.status is distinct from new.status
    or old.created_by is distinct from new.created_by
  ) and coalesce(
    current_setting('app.count_guard_bypass', true), ''
  ) <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return new;
end;
$$;

revoke all on function public._count_status_guard()
  from public, anon, authenticated;

do $$
declare
  v_table text;
begin
  for v_table in
    select unnest(array[
      'stock_counts', 'stock_count_lines', 'count_adjustments'
    ])
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      'trg_' || v_table || '_write_guard', v_table
    );
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function public._count_write_guard()',
      'trg_' || v_table || '_write_guard', v_table
    );
  end loop;
  for v_table in
    select unnest(array['stock_counts', 'count_adjustments'])
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      'trg_' || v_table || '_status_guard', v_table
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function public._count_status_guard()',
      'trg_' || v_table || '_status_guard', v_table
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Trigger dong bang kho dang kiem ke thang (ERR_COUNT_FREEZE)
--    Goi tren moi INSERT vao stock_moves nen moi RPC post (nhan hang, linh,
--    dieu chuyen, xuat muc dich, huy, minibar...) deu bi chan nhu nhau.
--    Mien tru duy nhat: move adjust_count cua chinh dot kiem dang dieu chinh.
-- ---------------------------------------------------------------------------
create or replace function public._count_freeze_guard()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.move_type = 'adjust_count'
    and new.source_doc_type = 'stock_count'
    and exists (
      select 1 from public.stock_counts c
      where c.id = new.source_doc_id
        and c.warehouse_id = new.warehouse_id
        and c.status = 'locked'
    ) then
    return new;
  end if;

  if exists (
    select 1 from public.stock_counts c
    where c.warehouse_id = new.warehouse_id
      and c.kind = 'monthly_full'
      and c.status in ('open', 'counting', 'recount', 'submitted', 'locked')
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_FREEZE';
  end if;

  return new;
end;
$$;

revoke all on function public._count_freeze_guard()
  from public, anon, authenticated;

drop trigger if exists trg_stock_moves_count_freeze on public.stock_moves;
create trigger trg_stock_moves_count_freeze
  before insert on public.stock_moves
  for each row execute function public._count_freeze_guard();

-- ---------------------------------------------------------------------------
-- 4. RLS: SELECT-only; ghi chi qua RPC (write-guard o tren).
--    stock_count_lines: chi nguoi co count.view_variance VA khong phai nguoi
--    dem moi SELECT truc tiep (mu book_qty/theoretical_qty/variance).
-- ---------------------------------------------------------------------------
alter table public.stock_counts enable row level security;
alter table public.stock_count_lines enable row level security;
alter table public.count_adjustments enable row level security;

revoke all on table public.stock_counts, public.stock_count_lines,
  public.count_adjustments from public, anon, authenticated;

grant select on table public.stock_counts, public.stock_count_lines,
  public.count_adjustments to authenticated;

create policy stock_counts_select on public.stock_counts
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'count.open')
    or public.has_perm(property_id, 'count.perform')
    or public.has_perm(property_id, 'count.lock')
    or public.has_perm(property_id, 'count.view_variance')
    or public.has_perm(property_id, 'count.adjust.approve')
  )
);

create policy count_adjustments_select on public.count_adjustments
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'count.open')
    or public.has_perm(property_id, 'count.perform')
    or public.has_perm(property_id, 'count.lock')
    or public.has_perm(property_id, 'count.view_variance')
    or public.has_perm(property_id, 'count.adjust.approve')
  )
);

create policy stock_count_lines_select on public.stock_count_lines
for select using (
  exists (
    select 1 from public.stock_counts c
    where c.id = stock_count_lines.count_id
      and c.property_id in (select public.my_property_ids())
      and public.has_perm(c.property_id, 'count.view_variance')
      and not (auth.uid() = any(c.counter_ids))
  )
);

-- ---------------------------------------------------------------------------
-- 5. View mu: v_count_sheet / v_count_result (04 §8)
--    View chay voi quyen owner (postgres) nen doc duoc bang goc bat chap RLS;
--    nguoi goi chi thay cot view cho phep.
-- ---------------------------------------------------------------------------
create or replace view public.v_count_sheet as
select
  c.id as count_id,
  c.warehouse_id,
  c.business_date,
  c.status as count_status,
  l.id as line_id,
  l.item_id,
  i.code as item_code,
  i.name as item_name,
  i.stock_uom,
  case
    when c.status = 'recount' and l.flag = 'recount' then null
    when auth.uid() = l.counted_by_1 then l.counted_qty_1
    when auth.uid() = l.counted_by_2 then l.counted_qty_2
    else null
  end as my_counted_qty,
  case
    when c.status = 'recount' and l.flag = 'recount' then null
    when auth.uid() = l.count_detail_by then l.count_detail
    else null
  end as my_count_detail,
  (
    auth.uid() = l.counted_by_1 or auth.uid() = l.counted_by_2
  ) and not (c.status = 'recount' and l.flag = 'recount')
    as has_counted,
  l.final_qty,
  l.flag,
  l.reason_code,
  l.explanation,
  l.photo_ids
from public.stock_counts c
join public.stock_count_lines l on l.count_id = c.id
join public.items i on i.id = l.item_id
where auth.uid() = any(c.counter_ids);

create or replace view public.v_count_result as
select
  c.id as count_id,
  c.warehouse_id,
  c.business_date,
  c.status as count_status,
  l.id as line_id,
  l.item_id,
  i.code as item_code,
  i.name as item_name,
  i.stock_uom,
  l.count_detail,
  l.counted_qty_1,
  l.counted_qty_2,
  l.final_qty,
  l.book_qty,
  l.theoretical_qty,
  l.variance_qty,
  l.variance_pct,
  l.flag,
  l.reason_code,
  l.explanation,
  l.photo_ids
from public.stock_counts c
join public.stock_count_lines l on l.count_id = c.id
join public.items i on i.id = l.item_id
where public.has_perm(c.property_id, 'count.view_variance')
  and not (auth.uid() = any(c.counter_ids));

grant select on public.v_count_sheet, public.v_count_result to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Ham phu noi bo (revoke het, khong cap execute cho client)
-- ---------------------------------------------------------------------------

-- has_perm() cho 1 user cu the (has_perm chi kiem auth.uid()). Dung de kiem
-- SOD_COUNT_INDEPENDENT o luc mo dot va luc submit: nguoi dem co quyen
-- receiving.post / requisition.issue tai kho do khong. Logic giong het
-- has_perm (override deny thang allow, pham vi kho/outlet, hieu luc).
create or replace function public._count_user_has_perm(
  p_user uuid,
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
      p_user as user_id,
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

revoke all on function public._count_user_has_perm(uuid, uuid, text, uuid)
  from public, anon, authenticated;

-- Kiem PIN cua 1 user cu the (ban _verify_pin chi kiem auth.uid()).
create or replace function public._count_verify_pin(
  p_user uuid,
  p_pin text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_hash text;
begin
  select p.pin_hash into v_hash
  from public.profiles p
  where p.id = p_user;

  if v_hash is null or p_pin is null or p_pin = '' then
    raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
  end if;

  if v_hash <> crypt(p_pin, v_hash) then
    raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
  end if;
end;
$$;

revoke all on function public._count_verify_pin(uuid, text)
  from public, anon, authenticated;

-- Quy doi chi tiet dem da quy cach ve don vi ton kho.
-- p_detail: {"qty": 5, "uom": "kg"} hoac [{"qty": 2, "uom": "cai"}, ...].
-- Uom la stock_uom -> he so 1; uom khac phai co trong item_purchase_units.
create or replace function public._count_qty_from_detail(
  p_item_id uuid,
  p_detail jsonb
)
returns numeric(18,4)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_item public.items%rowtype;
  v_elem jsonb;
  v_qty numeric(18,4);
  v_uom text;
  v_factor numeric(18,4);
  v_total numeric(18,4) := 0;
begin
  select * into v_item from public.items where id = p_item_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_detail is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  for v_elem in
    select * from jsonb_array_elements(
      case when jsonb_typeof(p_detail) = 'array' then p_detail
           else jsonb_build_array(p_detail) end
    )
  loop
    v_qty := nullif(v_elem ->> 'qty', '')::numeric;
    v_uom := nullif(v_elem ->> 'uom', '');
    if v_qty is null or v_qty <= 0 or v_uom is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    if v_uom = v_item.stock_uom then
      v_factor := 1;
    else
      select factor_to_stock into v_factor
      from public.item_purchase_units
      where org_id = v_item.org_id and item_id = p_item_id and uom = v_uom;
      if not found then
        raise exception using errcode = 'P0001', message = 'ERR_UOM_UNKNOWN';
      end if;
    end if;

    v_total := v_total + v_qty * v_factor;
  end loop;

  if v_total <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  return v_total;
end;
$$;

revoke all on function public._count_qty_from_detail(uuid, jsonb)
  from public, anon, authenticated;

-- Can ruou theo can (05 §6.3): ml = (gram - tare_g) / density_g_ml, roi doi
-- sang stock_uom qua he so mua cua 'ml' neu stock_uom <> 'ml'.
create or replace function public._count_bottle_qty(
  p_item_id uuid,
  p_bottle_weight_g numeric(18,4)
)
returns numeric(18,4)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_item public.items%rowtype;
  v_ml numeric(18,4);
  v_factor numeric(18,4);
begin
  select * into v_item from public.items where id = p_item_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_bottle_weight_g is null or p_bottle_weight_g <= 0
    or v_item.tare_g is null or v_item.density_g_ml is null
    or v_item.density_g_ml <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_ml := (p_bottle_weight_g - v_item.tare_g) / v_item.density_g_ml;
  if v_ml <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_item.stock_uom = 'ml' then
    return v_ml;
  end if;

  select factor_to_stock into v_factor
  from public.item_purchase_units
  where org_id = v_item.org_id and item_id = p_item_id and uom = 'ml';
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_UOM_UNKNOWN';
  end if;

  return v_ml * v_factor;
end;
$$;

revoke all on function public._count_bottle_qty(uuid, numeric)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPC: count_open
-- ---------------------------------------------------------------------------
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

  -- Kiem ke ca yeu cau file POS (09 §5); bang pos_imports chua co (Q34).
  if p_kind = 'shift_key' then
    raise exception using errcode = 'P0001', message = 'ERR_POS_IMPORT_REQUIRED';
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
    perform public._sod_check(v_property_id, 'COUNT_INDEPENDENT');
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity_id, 'CNT', v_business_date);

  insert into public.stock_counts (
    org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind,
    business_date, shift, status, counter_ids, opened_by, client_uuid,
    created_by
  ) values (
    v_org_id, v_entity_id, v_property_id, p_warehouse_id, v_doc_no, p_kind,
    v_business_date, p_shift, 'open', v_counters, auth.uid(), p_client_uuid,
    auth.uid()
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

revoke all on function public.count_open(uuid, text, date, text, uuid[], uuid)
  from public, anon;
grant execute on function public.count_open(uuid, text, date, text, uuid[], uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. RPC: count_record_line
-- ---------------------------------------------------------------------------
create or replace function public.count_record_line(
  p_count_id uuid,
  p_item_id uuid,
  p_detail jsonb default null,
  p_bottle_weight_g numeric default null,
  p_client_uuid uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_item public.items%rowtype;
  v_qty numeric(18,4);
  v_line public.stock_count_lines%rowtype;
  v_round integer;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null or p_item_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status not in ('open', 'counting', 'recount') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.perform', v_count.warehouse_id);

  -- Chi nguoi trong doi dem moi duoc ghi so.
  if not (auth.uid() = any(v_count.counter_ids)) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:count.perform';
  end if;

  select * into v_item from public.items where id = p_item_id;
  if not found or v_item.org_id <> v_count.org_id then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- Idempotency: goi lai cung client_uuid tra dong cu.
  if p_client_uuid is not null then
    select * into v_line from public.stock_count_lines
    where client_uuid = p_client_uuid;
    if found then
      return jsonb_build_object(
        'ok', true, 'id', v_line.id,
        'counted_qty', coalesce(v_line.counted_qty_2, v_line.counted_qty_1),
        'round', case when v_line.counted_by_2 = auth.uid() then 2 else 1 end
      );
    end if;
  end if;

  -- Tinh so dem: can chai uu tien, khong thi chi tiet da quy cach.
  if p_bottle_weight_g is not null then
    v_qty := public._count_bottle_qty(p_item_id, p_bottle_weight_g);
  elsif p_detail is not null then
    v_qty := public._count_qty_from_detail(p_item_id, p_detail);
  else
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  select * into v_line from public.stock_count_lines
  where count_id = p_count_id and item_id = p_item_id
  for update;

  if not found then
    -- Ma tim thay trong kho nhung khong co trong snapshot: them dong moi,
    -- book_qty = ton hien tai (0 neu chua co).
    insert into public.stock_count_lines (
      count_id, org_id, item_id, count_detail, count_detail_by,
      bottle_weight_g, counted_qty_1, counted_by_1, book_qty,
      theoretical_qty, client_uuid
    ) values (
      p_count_id, v_count.org_id, p_item_id, coalesce(p_detail, '{}'::jsonb),
      auth.uid(), p_bottle_weight_g, v_qty, auth.uid(),
      coalesce((
        select sum(qty) from public.stock_balances
        where warehouse_id = v_count.warehouse_id and item_id = p_item_id
      ), 0),
      case when v_count.kind = 'monthly_full' then coalesce((
        select sum(qty) from public.stock_balances
        where warehouse_id = v_count.warehouse_id and item_id = p_item_id
      ), 0) else null end,
      p_client_uuid
    )
    returning * into v_line;
    v_round := 1;
  elsif v_line.counted_by_1 is null or v_line.counted_by_1 = auth.uid() then
    update public.stock_count_lines set
      count_detail = coalesce(p_detail, count_detail),
      count_detail_by = auth.uid(),
      bottle_weight_g = p_bottle_weight_g,
      counted_qty_1 = v_qty,
      counted_by_1 = auth.uid(),
      client_uuid = coalesce(p_client_uuid, client_uuid)
    where id = v_line.id
    returning * into v_line;
    v_round := 1;
  elsif v_line.counted_by_2 is null or v_line.counted_by_2 = auth.uid() then
    update public.stock_count_lines set
      count_detail = coalesce(p_detail, count_detail),
      count_detail_by = auth.uid(),
      bottle_weight_g = p_bottle_weight_g,
      counted_qty_2 = v_qty,
      counted_by_2 = auth.uid(),
      client_uuid = coalesce(p_client_uuid, client_uuid)
    where id = v_line.id
    returning * into v_line;
    v_round := 2;
  else
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Lan ghi dau tien chuyen dot sang 'counting'.
  if v_count.status = 'open' then
    update public.stock_counts set status = 'counting' where id = p_count_id;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', v_line.id, 'counted_qty', v_qty, 'round', v_round
  );
end;
$$;

revoke all on function public.count_record_line(uuid, uuid, jsonb, numeric, uuid)
  from public, anon;
grant execute on function public.count_record_line(uuid, uuid, jsonb, numeric, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 9. RPC: count_submit (tinh book/theoretical/variance; chi tra ID)
-- ---------------------------------------------------------------------------
create or replace function public.count_submit(
  p_count_id uuid,
  p_pins text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_counter uuid;
  v_pin text;
  v_hash text;
  v_pin_ok boolean;
  v_recount uuid[] := '{}';
  v_red uuid[] := '{}';
  r_line public.stock_count_lines%rowtype;
  v_final numeric(18,4);
  v_var numeric(18,4);
  v_book numeric(18,4);
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status not in ('counting', 'recount') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.perform', v_count.warehouse_id);

  if not (auth.uid() = any(v_count.counter_ids)) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:count.perform';
  end if;

  -- PIN tung nguoi dem (06 §3.2): du PIN, moi nguoi phai khop >= 1 PIN dua len.
  if p_pins is null
    or array_length(p_pins, 1) is null
    or array_length(p_pins, 1) <> array_length(v_count.counter_ids, 1) then
    raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
  end if;
  foreach v_counter in array v_count.counter_ids loop
    select pin_hash into v_hash from public.profiles where id = v_counter;
    v_pin_ok := false;
    if v_hash is not null then
      foreach v_pin in array p_pins loop
        if v_pin is not null and v_hash = crypt(v_pin, v_hash) then
          v_pin_ok := true;
        end if;
      end loop;
    end if;
    if not v_pin_ok then
      raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
    end if;
  end loop;

  -- SOD_COUNT_INDEPENDENT (04 §6): kiem lai o luc submit.
  if v_count.kind = 'monthly_full' and not exists (
    select 1 from unnest(v_count.counter_ids) as u(uid)
    where not public._count_user_has_perm(u.uid, v_count.property_id, 'receiving.post', v_count.warehouse_id)
      and not public._count_user_has_perm(u.uid, v_count.property_id, 'requisition.issue', v_count.warehouse_id)
  ) then
    perform public._sod_check(v_count.property_id, 'COUNT_INDEPENDENT');
  end if;

  -- Mọi dòng phải được đếm đủ: monthly_full cần cả 2 vòng.
  if exists (
    select 1 from public.stock_count_lines
    where count_id = p_count_id
      and (counted_qty_1 is null
        or (v_count.kind = 'monthly_full' and counted_qty_2 is null))
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_INCOMPLETE';
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  if v_count.status = 'counting' then
    -- Vong 1: hai nguoi khop nhau moi co final; lech so sach -> dem lai.
    for r_line in
      select * from public.stock_count_lines
      where count_id = p_count_id
      for update
    loop
      v_book := coalesce(r_line.book_qty, 0);
      if r_line.counted_qty_1 = r_line.counted_qty_2 then
        v_final := r_line.counted_qty_1;
        v_var := v_final - v_book;
        if abs(v_var) > 0.0001 then
          update public.stock_count_lines set
            final_qty = null, variance_qty = null, variance_pct = null,
            flag = 'recount',
            counted_qty_1 = null, counted_qty_2 = null,
            counted_by_1 = null, counted_by_2 = null,
            count_detail = '{}'::jsonb, count_detail_by = null,
            bottle_weight_g = null
          where id = r_line.id;
          v_recount := array_append(v_recount, r_line.id);
        else
          update public.stock_count_lines set
            final_qty = v_final, variance_qty = v_var,
            variance_pct = case when v_book <> 0
              then round(v_var / v_book * 100, 4) else null end,
            flag = 'ok'
          where id = r_line.id;
        end if;
      else
        update public.stock_count_lines set
          final_qty = null, variance_qty = null, variance_pct = null,
          flag = 'recount',
          counted_qty_1 = null, counted_qty_2 = null,
          counted_by_1 = null, counted_by_2 = null,
          count_detail = '{}'::jsonb, count_detail_by = null,
          bottle_weight_g = null
        where id = r_line.id;
        v_recount := array_append(v_recount, r_line.id);
      end if;
    end loop;

    if array_length(v_recount, 1) is not null then
      update public.stock_counts set status = 'recount' where id = p_count_id;
    else
      update public.stock_counts set status = 'submitted' where id = p_count_id;
    end if;
  else
    -- Vong 2 (sau dem lai): final = vong 2 neu co, khong thi vong 1;
    -- con lech so sach hoac hai nguoi van khac nhau -> 'red'.
    for r_line in
      select * from public.stock_count_lines
      where count_id = p_count_id and flag = 'recount'
      for update
    loop
      v_book := coalesce(r_line.book_qty, 0);
      v_final := coalesce(r_line.counted_qty_2, r_line.counted_qty_1);
      v_var := v_final - v_book;
      update public.stock_count_lines set
        final_qty = v_final, variance_qty = v_var,
        variance_pct = case when v_book <> 0
          then round(v_var / v_book * 100, 4) else null end,
        flag = case
          when r_line.counted_qty_1 is distinct from r_line.counted_qty_2
            then 'red'
          when abs(v_var) > 0.0001 then 'red'
          else 'ok'
        end
      where id = r_line.id;
      if r_line.counted_qty_1 is distinct from r_line.counted_qty_2
        or abs(v_var) > 0.0001 then
        v_red := array_append(v_red, r_line.id);
      end if;
    end loop;

    update public.stock_counts set status = 'submitted' where id = p_count_id;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', p_count_id,
    'recount_line_ids', coalesce(to_jsonb(v_recount), '[]'::jsonb),
    'red_line_ids', coalesce(to_jsonb(v_red), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.count_submit(uuid, text[])
  from public, anon;
grant execute on function public.count_submit(uuid, text[])
  to authenticated;

-- ---------------------------------------------------------------------------
-- 10. RPC: count_lock (ly do bat buoc cho dong do)
-- ---------------------------------------------------------------------------
create or replace function public.count_lock(
  p_count_id uuid,
  p_reasons jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_reason jsonb;
  v_line_id uuid;
  v_code text;
  v_expl text;
  v_red integer;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status <> 'submitted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.lock');

  perform set_config('app.count_guard_bypass', 'on', true);

  -- Ap ly do cho dong do (neu co).
  if p_reasons is not null then
    if jsonb_typeof(p_reasons) <> 'array' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    for v_reason in select * from jsonb_array_elements(p_reasons) loop
      v_line_id := nullif(v_reason ->> 'line_id', '')::uuid;
      v_code := nullif(v_reason ->> 'reason_code', '');
      v_expl := nullif(v_reason ->> 'explanation', '');
      if v_line_id is null or v_code is null then
        raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
      end if;
      update public.stock_count_lines
      set reason_code = v_code, explanation = v_expl
      where id = v_line_id and count_id = p_count_id and flag = 'red';
      if not found then
        raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
      end if;
    end loop;
  end if;

  select count(*) into v_red
  from public.stock_count_lines
  where count_id = p_count_id and flag = 'red'
    and (reason_code is null or btrim(reason_code) = '');
  if v_red > 0 then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  update public.stock_counts
  set status = 'locked', locked_by = auth.uid(), locked_at = now()
  where id = p_count_id;

  insert into public.count_adjustments (
    count_id, org_id, property_id, status, created_by
  ) values (
    p_count_id, v_count.org_id, v_count.property_id, 'pending', auth.uid()
  );

  return jsonb_build_object(
    'ok', true, 'id', p_count_id, 'red_lines', (
      select count(*) from public.stock_count_lines
      where count_id = p_count_id and flag = 'red'
    )
  );
end;
$$;

revoke all on function public.count_lock(uuid, jsonb)
  from public, anon;
grant execute on function public.count_lock(uuid, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPC: count_adjust_post (gm duyet -> adjust_count theo gia binh quan)
-- ---------------------------------------------------------------------------
create or replace function public.count_adjust_post(
  p_count_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_adj public.count_adjustments%rowtype;
  r_line public.stock_count_lines%rowtype;
  v_avg numeric(18,4);
  v_move_id bigint;
  v_amt numeric(18,2);
  v_moves integer := 0;
  v_total numeric(18,2) := 0;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status <> 'locked' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.adjust.approve');

  select * into v_adj from public.count_adjustments
  where count_id = p_count_id;
  if not found or v_adj.status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  -- Ghi move TRUOC khi doi status: trigger mien tru adjust_count chi khi
  -- dot van o 'locked'. _post_move tu tinh gia theo phuong phap cua phap
  -- nhan (moving_avg dung avg truyen vao; FIFO dung gia lop).
  for r_line in
    select * from public.stock_count_lines
    where count_id = p_count_id
      and variance_qty is not null
      and variance_qty <> 0
    order by item_id
  loop
    v_avg := public._inventory_avg_cost(v_count.legal_entity_id, r_line.item_id);
    v_move_id := public._post_move(
      v_count.legal_entity_id, v_count.property_id, v_count.warehouse_id,
      r_line.item_id, null, 'adjust_count', r_line.variance_qty, v_avg,
      v_count.business_date, 'stock_count', p_count_id, r_line.id
    );
    select amount into v_amt from public.stock_moves where id = v_move_id;
    v_total := v_total + coalesce(v_amt, 0);
    v_moves := v_moves + 1;
  end loop;

  update public.count_adjustments
  set status = 'approved', approved_by = auth.uid(), approved_at = now(),
    moves_posted = v_moves, total_value = v_total
  where id = v_adj.id;

  update public.stock_counts
  set status = 'adjusted', adjusted_by = auth.uid(), adjusted_at = now()
  where id = p_count_id;

  return jsonb_build_object(
    'ok', true, 'id', p_count_id,
    'moves_posted', v_moves, 'total_value', v_total
  );
end;
$$;

revoke all on function public.count_adjust_post(uuid)
  from public, anon;
grant execute on function public.count_adjust_post(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 12. RPC: count_add_counter / count_cancel (ngoai spec — xem D12)
-- ---------------------------------------------------------------------------
create or replace function public.count_add_counter(
  p_count_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null or p_user_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status not in ('open', 'counting', 'recount') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.open', v_count.warehouse_id);

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_user_id = any(v_count.counter_ids) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if not public._count_user_has_perm(p_user_id, v_count.property_id, 'count.perform', v_count.warehouse_id) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:count.perform';
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  update public.stock_counts
  set counter_ids = array_append(counter_ids, p_user_id)
  where id = p_count_id;

  return jsonb_build_object(
    'ok', true, 'id', p_count_id,
    'counter_ids', (select counter_ids from public.stock_counts where id = p_count_id)
  );
end;
$$;

revoke all on function public.count_add_counter(uuid, uuid)
  from public, anon;
grant execute on function public.count_add_counter(uuid, uuid)
  to authenticated;

create or replace function public.count_cancel(
  p_count_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status not in ('open', 'counting', 'recount', 'submitted') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.open', v_count.warehouse_id);

  perform set_config('app.count_guard_bypass', 'on', true);

  update public.stock_counts
  set status = 'cancelled', cancel_reason = p_reason,
    cancelled_by = auth.uid(), cancelled_at = now()
  where id = p_count_id;

  return jsonb_build_object('ok', true, 'id', p_count_id);
end;
$$;

revoke all on function public.count_cancel(uuid, text)
  from public, anon;
grant execute on function public.count_cancel(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 13. Redefine period_close: giu nguyen chu ky + them 3 dieu kien (05 §10).
--    (Ham goc o 20261109120000 khong kiem dieu kien nao.)
-- ---------------------------------------------------------------------------
create or replace function public.period_close(
  p_entity_id uuid,
  p_year integer,
  p_month integer
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_entity_id is null or p_year is null or p_year < 1 or p_month is null or p_month not between 1 and 12 then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  perform public.require_perm(null, 'period.close');

  if exists (
    select 1 from public.accounting_periods
    where legal_entity_id = p_entity_id and year = p_year and month = p_month and status = 'closed'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_ALREADY_CLOSED';
  end if;

  -- 05 §6.1.5 + §10: moi kho cua phap nhan (da ton tai trong thang) phai co
  -- dot monthly_full thang do o 'locked'/'adjusted'.
  if exists (
    select 1
    from public.properties p
    join public.warehouses w on w.property_id = p.id
    where p.legal_entity_id = p_entity_id
      and w.created_at < (make_date(p_year, p_month, 1) + interval '1 month')
      and not exists (
        select 1 from public.stock_counts c
        where c.warehouse_id = w.id
          and c.kind = 'monthly_full'
          and extract(year from c.business_date)::integer = p_year
          and extract(month from c.business_date)::integer = p_month
          and c.status in ('locked', 'adjusted')
      )
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_NOT_LOCKED';
  end if;

  -- 05 §10: khong PO partially_received co expected_date qua 30 ngay (Q29).
  if exists (
    select 1
    from public.purchase_orders po
    join public.properties p on p.id = po.property_id
    where p.legal_entity_id = p_entity_id
      and po.status = 'partially_received'
      and po.expected_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date - interval '30 days'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PO_UNRESOLVED';
  end if;

  -- 05 §10: khong tam ung qua han.
  if exists (
    select 1
    from public.advances a
    join public.properties p on p.id = a.property_id
    where p.legal_entity_id = p_entity_id
      and a.status = 'overdue'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_ADVANCE_OVERDUE';
  end if;

  insert into public.accounting_periods (legal_entity_id, year, month, status, closed_by, closed_at)
  values (p_entity_id, p_year, p_month, 'closed', auth.uid(), now())
  on conflict (legal_entity_id, year, month)
  do update set status = 'closed', closed_by = auth.uid(), closed_at = now(), updated_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

revoke all on function public.period_close(uuid, integer, integer) from public, anon;
grant execute on function public.period_close(uuid, integer, integer) to authenticated;
