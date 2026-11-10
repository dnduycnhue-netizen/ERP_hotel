-- 20261109530000_restaurant_followups.sql
--
-- C11 — Follow-up nha hang (completion wave 2, Q166–Q170).
--   Q166: KHONG doi code — kiem tra trung sanh trong banquet_confirm
--     (M06) giu nguyen; quyet dinh giu hay bo cho Duy chot (xem
--     docs/OPEN-QUESTIONS.md).
--   Q167: portions_per_batch DA co o recipes + form mon + tinh chuan bi
--     (500000); dot nay chi them so me (batches) vao restaurant_kitchen_today
--     de bep thay so me khi scale theo so phan.
--   Q168: KHONG lam (import Excel — de Duy quyet, xem OPEN-QUESTIONS.md).
--   Q169: tu sinh phieu linh NHAP tu tiec xac nhan / ban mon
--     (helper _restaurant_auto_requisition, mau sinh phieu bu toi par T-034).
--   Q170: (a) trang thai coc banquets.deposit_status (chi ghi nhan, KHONG
--     ghi ap_ledger); (b) danh muc sanh banquet_halls + chon sanh khi dat tiec.
--
-- Quy uoc: tien/sl numeric; ngay Asia/Ho_Chi_Minh; actor = auth.uid();
-- khong dung `= any (my_property_ids())`.

-- ---------------------------------------------------------------------------
-- 1. Danh muc sanh tiec (Q170b).
-- ---------------------------------------------------------------------------
create table public.banquet_halls (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.properties(id),
  name text not null check (btrim(name) <> ''),
  capacity integer check (capacity is null or capacity > 0),
  is_active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (id, property_id)
);

-- Ten sanh duy nhat trong cac sanh dang hoat dong cua 1 khach san
-- (khong phan biet hoa/thuong); sanh da tat co the tao lai ten cu.
create unique index banquet_halls_property_name_active
  on public.banquet_halls (property_id, lower(btrim(name)))
  where is_active;

-- Write-guard + updated_at (mau 500000 §3).
create trigger trg_banquet_halls_write_guard
  before insert or update or delete on public.banquet_halls
  for each row execute function public._restaurant_write_guard();
create trigger trg_banquet_halls_updated_at
  before update on public.banquet_halls
  for each row execute function public.set_updated_at();

alter table public.banquet_halls enable row level security;

create policy banquet_halls_select on public.banquet_halls
for select using (
  property_id in (select public.my_property_ids())
  and (public.has_perm(property_id, 'restaurant.view')
    or public.has_perm(property_id, 'restaurant.banquet.manage'))
);

-- ---------------------------------------------------------------------------
-- 2. Banquets: gan sanh danh muc + trang thai coc (Q170).
--    hall: giu text (snapshot ten sanh luc dat, mau snapshot unit_price);
--    hall_id: link danh muc (nullable — tiec cu / sanh ngoai danh muc
--    van dung text tu do). deposit_status: chi ghi nhan da/chua coc,
--    KHONG ghi ap_ledger, KHONG co luong thu tien moi.
-- ---------------------------------------------------------------------------
alter table public.banquets
  add column hall_id uuid,
  add column deposit_status text not null default 'unpaid'
    check (deposit_status in ('unpaid', 'paid'));

alter table public.banquets
  add constraint banquets_hall_id_fk
  foreign key (hall_id, property_id)
  references public.banquet_halls(id, property_id);

-- ---------------------------------------------------------------------------
-- 3. RPC luu sanh (Q170b). Quyen restaurant.banquet.manage (khong them
--    ma quyen moi — quan ly sanh la 1 phan cua quan ly dat tiec).
-- ---------------------------------------------------------------------------
create or replace function public.banquet_hall_save(
  p_property_id uuid, p_hall jsonb
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_hall_id uuid;
  v_name text;
  v_capacity integer;
  v_is_active boolean;
  v_existing public.banquet_halls%rowtype;
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  select org_id into v_org_id from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  v_name := btrim(coalesce(p_hall ->> 'name', ''));
  v_capacity := nullif(p_hall ->> 'capacity', '')::integer;
  v_is_active := coalesce((p_hall ->> 'is_active')::boolean, true);
  if v_name = '' or (v_capacity is not null and v_capacity <= 0) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_hall_id := nullif(p_hall ->> 'id', '')::uuid;
  if v_hall_id is not null then
    select * into v_existing from public.banquet_halls
    where id = v_hall_id and property_id = p_property_id;
    if not found then raise exception 'ERR_INVALID_VALUE'; end if;
  end if;
  -- Trung ten (khong phan biet hoa/thuong) voi sanh dang hoat dong khac.
  if exists (
    select 1 from public.banquet_halls h
    where h.property_id = p_property_id and h.is_active
      and lower(btrim(h.name)) = lower(v_name)
      and (v_hall_id is null or h.id <> v_hall_id)
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  if v_hall_id is null then
    insert into public.banquet_halls
      (org_id, property_id, name, capacity, is_active, notes, created_by)
    values
      (v_org_id, p_property_id, v_name, v_capacity, v_is_active,
       nullif(p_hall ->> 'notes', ''), auth.uid())
    returning id into v_hall_id;
  else
    update public.banquet_halls set
      name = v_name,
      capacity = v_capacity,
      is_active = v_is_active,
      notes = nullif(p_hall ->> 'notes', '')
    where id = v_hall_id;
  end if;

  return jsonb_build_object('ok', true, 'id', v_hall_id);
end;
$$;

revoke all on function public.banquet_hall_save(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.banquet_hall_save(uuid, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Helper noi bo: sinh phieu linh NHAP tu danh sach (mon, so phan)
--    (Q169). Mau sinh phieu bu toi par cua T-034 (trolley_shift_open):
--    insert truc tiep requisitions + lines, chi tao NHAP, KHONG sinh
--    buoc duyet, KHONG tu submit. Nguoi tao = auth.uid() (nguoi xac
--    nhan tiec / ghi ban); nguoi duyet = luong duyet phieu linh binh
--    thuong (outlet_head) khi phieu duoc submit tay.
--    Kho dich: kho outlet cua bo phan Bep chinh (outlet_types KITCHEN);
--    kho nguon: kho main cua khach san. Thieu outlet/kho -> tra ve
--    requisition_id NULL + note (khong raise) de nghiep vu chinh khong
--    hong. Dong NVL khong quy doi duoc don vi thi bo qua (dem vao
--    skipped_lines); phieu khong co dong nao thi xoa, tra NULL.
-- ---------------------------------------------------------------------------
create or replace function public._restaurant_auto_requisition(
  p_property_id uuid, p_business_date date, p_note text, p_servings jsonb
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_entity_id uuid;
  v_outlet_id uuid;
  v_to_wh uuid;
  v_from_wh uuid;
  v_doc_no text;
  v_req_id uuid;
  v_lines integer := 0;
  v_skipped integer := 0;
begin
  if p_property_id is null or p_business_date is null
    or jsonb_typeof(coalesce(p_servings, '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select org_id, legal_entity_id into v_org_id, v_entity_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  select o.id into v_outlet_id
  from public.outlets o
  join public.outlet_types t on t.id = o.outlet_type_id
  where o.property_id = p_property_id
    and t.org_id = v_org_id and t.code = 'KITCHEN'
  order by o.created_at limit 1;
  if v_outlet_id is null then
    return jsonb_build_object('requisition_id', null, 'lines', 0,
      'skipped_lines', 0,
      'note', 'Chưa có bộ phận Bếp chính (outlet KITCHEN) nên không tạo phiếu lĩnh tự động.');
  end if;

  select id into v_to_wh from public.warehouses
  where property_id = p_property_id and outlet_id = v_outlet_id
    and kind = 'outlet'
  order by created_at limit 1;
  if v_to_wh is null then
    return jsonb_build_object('requisition_id', null, 'lines', 0,
      'skipped_lines', 0,
      'note', 'Chưa có kho bếp (kind outlet) nên không tạo phiếu lĩnh tự động.');
  end if;

  select id into v_from_wh from public.warehouses
  where property_id = p_property_id and kind = 'main'
  order by created_at limit 1;
  if v_from_wh is null then
    return jsonb_build_object('requisition_id', null, 'lines', 0,
      'skipped_lines', 0,
      'note', 'Chưa có kho chính (kind main) nên không tạo phiếu lĩnh tự động.');
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity_id, 'REQ', p_business_date);
  insert into public.requisitions (
    org_id, legal_entity_id, property_id, outlet_id,
    from_warehouse_id, to_warehouse_id, doc_no, business_date,
    status, note, created_by
  ) values (
    v_org_id, v_entity_id, p_property_id, v_outlet_id,
    v_from_wh, v_to_wh, v_doc_no, p_business_date,
    'draft', p_note, auth.uid()
  )
  returning id into v_req_id;

  -- Dong NVL: mo rong dinh luong theo so phan (dung quy uoc
  -- portions_per_batch cua _restaurant_expand_recipe), gom theo NVL,
  -- quy ve stock_uom (stock_uom / recipe_uom qua stock_to_recipe /
  -- item_purchase_units.factor_to_stock).
  with expanded as (
    select e.item_id, e.uom, e.qty
    from jsonb_array_elements(p_servings) s
    cross join lateral public._restaurant_expand_recipe(
      (s ->> 'recipe_id')::uuid, (s ->> 'servings')::numeric) e
  ), converted as (
    select x.item_id, i.stock_uom,
      sum(case
        when x.uom = i.stock_uom then x.qty
        when x.uom = i.recipe_uom
          and i.stock_to_recipe is not null and i.stock_to_recipe > 0
          then x.qty / i.stock_to_recipe
        when pu.factor_to_stock is not null
          then x.qty * pu.factor_to_stock
        else null end) as qty_stock
    from expanded x
    join public.items i on i.id = x.item_id
    left join lateral (
      select pu.factor_to_stock from public.item_purchase_units pu
      where pu.org_id = v_org_id and pu.item_id = x.item_id
        and pu.uom = x.uom
      limit 1
    ) pu on true
    group by x.item_id, i.stock_uom
  )
  select count(*) into v_skipped from converted
  where qty_stock is null or qty_stock <= 0;

  with expanded as (
    select e.item_id, e.uom, e.qty
    from jsonb_array_elements(p_servings) s
    cross join lateral public._restaurant_expand_recipe(
      (s ->> 'recipe_id')::uuid, (s ->> 'servings')::numeric) e
  ), converted as (
    select x.item_id, i.stock_uom,
      sum(case
        when x.uom = i.stock_uom then x.qty
        when x.uom = i.recipe_uom
          and i.stock_to_recipe is not null and i.stock_to_recipe > 0
          then x.qty / i.stock_to_recipe
        when pu.factor_to_stock is not null
          then x.qty * pu.factor_to_stock
        else null end) as qty_stock
    from expanded x
    join public.items i on i.id = x.item_id
    left join lateral (
      select pu.factor_to_stock from public.item_purchase_units pu
      where pu.org_id = v_org_id and pu.item_id = x.item_id
        and pu.uom = x.uom
      limit 1
    ) pu on true
    group by x.item_id, i.stock_uom
  )
  insert into public.requisition_lines (
    requisition_id, org_id, property_id, item_id, uom,
    qty, qty_stock, created_by
  )
  select v_req_id, v_org_id, p_property_id, c.item_id, c.stock_uom,
    c.qty_stock, c.qty_stock, auth.uid()
  from converted c
  where c.qty_stock is not null and c.qty_stock > 0;
  get diagnostics v_lines = row_count;

  if v_lines = 0 then
    delete from public.requisitions where id = v_req_id;
    return jsonb_build_object('requisition_id', null, 'lines', 0,
      'skipped_lines', v_skipped,
      'note', 'Không có dòng NVL quy đổi được nên không tạo phiếu lĩnh tự động.');
  end if;

  return jsonb_build_object(
    'requisition_id', v_req_id, 'lines', v_lines,
    'skipped_lines', v_skipped,
    'note', 'Đã tạo phiếu lĩnh nháp ' || v_doc_no
      || ' (' || v_lines || ' dòng'
      || case when v_skipped > 0
        then '; bỏ qua ' || v_skipped || ' dòng không quy đổi được đơn vị'
        else '' end
      || ').'
  );
end;
$$;

revoke all on function public._restaurant_auto_requisition(uuid, date, text, jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. banquet_save: them hall_id + deposit_status (Q170).
--    Toan van ham goc tu 500000, chi them cac doan danh dau C11.
-- ---------------------------------------------------------------------------
create or replace function public.banquet_save(
  p_property_id uuid, p_banquet jsonb
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_banquet_id uuid;
  v_doc_no text;
  v_dish jsonb;
  v_recipe_id uuid;
  v_qty numeric;
  v_price numeric;
  v_hall_id uuid;
  v_hall_id_given boolean;
  v_use_catalog boolean;
  v_hall_name text;
  v_dep_amt numeric;
  v_dep_status text;
  v_old_dep_amt numeric;
  v_old_dep_status text;
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  select org_id, legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  -- C11 (Q170): sanh lay tu danh muc (hall_id) hoac text tu do;
  -- trang thai coc (deposit_status) chi ghi nhan, khong ghi ap_ledger.
  v_hall_id_given := p_banquet ? 'hall_id';
  v_hall_id := nullif(p_banquet ->> 'hall_id', '')::uuid;
  v_use_catalog := v_hall_id_given and v_hall_id is not null;
  if v_use_catalog then
    select name into v_hall_name from public.banquet_halls
    where id = v_hall_id and property_id = p_property_id and is_active;
    if not found then raise exception 'ERR_INVALID_VALUE'; end if;
    v_hall_name := btrim(v_hall_name);
  end if;

  if btrim(coalesce(p_banquet ->> 'customer_name', '')) = ''
    or (p_banquet ->> 'event_date')::date is null
    or (p_banquet ->> 'event_date')::date < v_today
    or (p_banquet ->> 'start_time')::time is null
    or (p_banquet ->> 'end_time')::time is null
    or (p_banquet ->> 'end_time')::time
      <= (p_banquet ->> 'start_time')::time
    or (not v_use_catalog
      and btrim(coalesce(p_banquet ->> 'hall', '')) = '')
    or (p_banquet ? 'deposit_status'
      and not (p_banquet ->> 'deposit_status' in ('unpaid', 'paid')))
    or coalesce((p_banquet ->> 'guests_count')::integer, 0) <= 0
    or coalesce((p_banquet ->> 'tables_count')::integer, 0) < 0
    or coalesce((p_banquet ->> 'deposit_amount')::numeric, 0) < 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if jsonb_typeof(coalesce(p_banquet -> 'dishes', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  v_banquet_id := nullif(p_banquet ->> 'id', '')::uuid;
  if v_banquet_id is null then
    v_dep_amt := coalesce((p_banquet ->> 'deposit_amount')::numeric, 0);
    v_dep_status := coalesce(
      nullif(p_banquet ->> 'deposit_status', ''), 'unpaid');
    if v_dep_status = 'paid' and v_dep_amt <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_doc_no := public.next_doc_no(
      v_legal_entity_id, 'banquet', (p_banquet ->> 'event_date')::date);
    insert into public.banquets
      (org_id, legal_entity_id, property_id, doc_no,
       customer_name, customer_phone, event_date, start_time, end_time,
       hall, hall_id, tables_count, guests_count, deposit_amount,
       deposit_status, notes)
    values
      (v_org_id, v_legal_entity_id, p_property_id, v_doc_no,
       btrim(p_banquet ->> 'customer_name'),
       nullif(p_banquet ->> 'customer_phone', ''),
       (p_banquet ->> 'event_date')::date,
       (p_banquet ->> 'start_time')::time,
       (p_banquet ->> 'end_time')::time,
       case when v_use_catalog then v_hall_name
         else btrim(p_banquet ->> 'hall') end,
       case when v_use_catalog then v_hall_id else null end,
       coalesce((p_banquet ->> 'tables_count')::integer, 0),
       (p_banquet ->> 'guests_count')::integer,
       v_dep_amt, v_dep_status,
       nullif(p_banquet ->> 'notes', ''))
    returning id, doc_no into v_banquet_id, v_doc_no;
  else
    select deposit_amount, deposit_status
      into v_old_dep_amt, v_old_dep_status
    from public.banquets
    where id = v_banquet_id and property_id = p_property_id;
    if v_old_dep_amt is null then raise exception 'ERR_INVALID_STATUS'; end if;
    v_dep_amt := coalesce(
      (p_banquet ->> 'deposit_amount')::numeric, v_old_dep_amt);
    v_dep_status := case when p_banquet ? 'deposit_status'
      then coalesce(nullif(p_banquet ->> 'deposit_status', ''), 'unpaid')
      else v_old_dep_status end;
    if v_dep_status = 'paid' and v_dep_amt <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    update public.banquets set
      customer_name = btrim(p_banquet ->> 'customer_name'),
      customer_phone = nullif(p_banquet ->> 'customer_phone', ''),
      event_date = (p_banquet ->> 'event_date')::date,
      start_time = (p_banquet ->> 'start_time')::time,
      end_time = (p_banquet ->> 'end_time')::time,
      hall = case when v_use_catalog then v_hall_name
        when p_banquet ? 'hall' then btrim(p_banquet ->> 'hall')
        else hall end,
      hall_id = case when v_hall_id_given then v_hall_id else hall_id end,
      tables_count = coalesce((p_banquet ->> 'tables_count')::integer, tables_count),
      guests_count = case when p_banquet ? 'guests_count'
        then (p_banquet ->> 'guests_count')::integer else guests_count end,
      deposit_amount = v_dep_amt,
      deposit_status = v_dep_status,
      notes = nullif(p_banquet ->> 'notes', '')
    where id = v_banquet_id and property_id = p_property_id
      and status in ('new', 'confirmed')
    returning doc_no into v_doc_no;
    if v_doc_no is null then raise exception 'ERR_INVALID_STATUS'; end if;
  end if;

  if p_banquet ? 'dishes' then
    delete from public.banquet_dishes where banquet_id = v_banquet_id;
    for v_dish in
      select * from jsonb_array_elements(p_banquet -> 'dishes')
    loop
      v_recipe_id := nullif(v_dish ->> 'recipe_id', '')::uuid;
      v_qty := (v_dish ->> 'qty')::numeric;
      v_price := nullif(v_dish ->> 'unit_price', '')::numeric;
      if v_recipe_id is null or v_qty is null or v_qty <= 0
        or not exists (select 1 from public.recipes
          where id = v_recipe_id and org_id = v_org_id and is_active) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      if v_price is null then
        select sale_price into v_price from public.recipes
        where id = v_recipe_id;
      end if;
      if v_price is null or v_price < 0 then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      insert into public.banquet_dishes
        (org_id, banquet_id, recipe_id, qty, unit_price, note)
      values
        (v_org_id, v_banquet_id, v_recipe_id, v_qty, v_price,
         nullif(v_dish ->> 'note', ''));
    end loop;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', v_banquet_id, 'doc_no', v_doc_no
  );
end;
$$;
revoke all on function public.banquet_save(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.banquet_save(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. banquet_confirm: tu sinh phieu linh nhap (Q169).
--    Toan van ham goc tu 500000, chi them cac doan danh dau C11.
-- ---------------------------------------------------------------------------
create or replace function public.banquet_confirm(
  p_property_id uuid, p_banquet_id uuid
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_row public.banquets%rowtype;
  v_servings jsonb;
  v_auto jsonb;
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  select * into v_row from public.banquets
  where id = p_banquet_id and property_id = p_property_id;
  if not found then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_row.status <> 'new' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  if exists (
    select 1 from public.banquets b
    where b.property_id = p_property_id
      and b.id <> p_banquet_id
      and lower(btrim(b.hall)) = lower(btrim(v_row.hall))
      and b.event_date = v_row.event_date
      and b.status in ('confirmed', 'in_progress')
      and b.start_time < v_row.end_time
      and b.end_time > v_row.start_time
  ) then
    raise exception 'ERR_BANQUET_HALL_CONFLICT';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.banquets set status = 'confirmed'
  where id = p_banquet_id;

  -- C11 (Q169): tu sinh phieu linh NHAP cho NVL can dung (chi nhap,
  -- khong tu duyet). Tao phieu la best-effort: loi thi ghi chu, khong
  -- lam hong viec xac nhan tiec.
  select coalesce(jsonb_agg(jsonb_build_object(
    'recipe_id', d.recipe_id, 'servings', d.qty
  )), '[]'::jsonb) into v_servings
  from public.banquet_dishes d where d.banquet_id = p_banquet_id;
  begin
    v_auto := public._restaurant_auto_requisition(
      p_property_id, v_row.event_date,
      'Tự động từ tiệc ' || v_row.doc_no, v_servings);
  exception when others then
    v_auto := jsonb_build_object(
      'requisition_id', null,
      'note', 'Không tạo được phiếu lĩnh tự động: ' || sqlerrm);
  end;

  return jsonb_build_object(
    'ok', true, 'id', p_banquet_id,
    'requisition_id', v_auto ->> 'requisition_id',
    'requisition_note', v_auto ->> 'note'
  );
end;
$$;
revoke all on function public.banquet_confirm(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.banquet_confirm(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. dish_sale_record: tu sinh phieu linh nhap (Q169).
--    Toan van ham goc tu 500000, chi them cac doan danh dau C11.
-- ---------------------------------------------------------------------------
create or replace function public.dish_sale_record(
  p_property_id uuid, p_business_date date,
  p_recipe_id uuid, p_qty numeric, p_unit_price numeric
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_sale_id uuid;
  v_amount numeric;
  v_auto jsonb;
  v_recipe_name text;
begin
  perform public.require_perm(p_property_id, 'restaurant.sale.record');

  select org_id, legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  if p_business_date is null or p_business_date > v_today then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_qty is null or p_qty <= 0
    or p_unit_price is null or p_unit_price < 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if not exists (select 1 from public.recipes
    where id = p_recipe_id and org_id = v_org_id and is_active) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_amount := round(p_qty * p_unit_price, 2);

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  insert into public.dish_sales
    (org_id, legal_entity_id, property_id, business_date,
     recipe_id, source, ref_id, qty, unit_price, amount)
  values
    (v_org_id, v_legal_entity_id, p_property_id, p_business_date,
     p_recipe_id, 'manual', null, p_qty, p_unit_price, v_amount)
  returning id into v_sale_id;

  -- C11 (Q169): tu sinh phieu linh NHAP cho NVL cua mon vua ban
  -- (best-effort, nhu banquet_confirm).
  select name into v_recipe_name from public.recipes where id = p_recipe_id;
  begin
    v_auto := public._restaurant_auto_requisition(
      p_property_id, p_business_date,
      'Tự động từ bán món ' || coalesce(v_recipe_name, p_recipe_id::text),
      jsonb_build_array(jsonb_build_object(
        'recipe_id', p_recipe_id, 'servings', p_qty)));
  exception when others then
    v_auto := jsonb_build_object(
      'requisition_id', null,
      'note', 'Không tạo được phiếu lĩnh tự động: ' || sqlerrm);
  end;

  return jsonb_build_object(
    'ok', true, 'id', v_sale_id, 'amount', v_amount,
    'requisition_id', v_auto ->> 'requisition_id',
    'requisition_note', v_auto ->> 'note'
  );
end;
$$;
revoke all on function public.dish_sale_record(uuid, date, uuid, numeric, numeric)
  from public, anon, authenticated;
grant execute on function public.dish_sale_record(uuid, date, uuid, numeric, numeric)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. restaurant_kitchen_today: them portions_per_batch + batches (Q167).
--    Toan van ham goc tu 500000, chi them cac doan danh dau C11.
-- ---------------------------------------------------------------------------
create or replace function public.restaurant_kitchen_today(
  p_property_id uuid, p_business_date date default null
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_date date := coalesce(p_business_date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date);
begin
  perform public.require_perm(p_property_id, 'restaurant.view');

  select org_id into v_org_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  return jsonb_build_object(
    'ok', true, 'business_date', v_date,
    'dishes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'code', r.code, 'name', r.name, 'kind', r.kind,
        'group_name', r.group_name, 'sale_price', r.sale_price,
        'foodcost', f.foodcost, 'has_unknown_cost', f.has_unknown_cost,
        'portions_per_batch', r.portions_per_batch
      ) order by r.kind, r.name)
      from public.recipes r
      left join public._restaurant_foodcost_list(p_property_id) f
        on f.recipe_id = r.id
      where r.org_id = v_org_id and r.is_active
    ), '[]'::jsonb),
    'buffet_sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'meal', s.meal, 'guest_count', s.guest_count,
        'price_per_guest', s.price_per_guest, 'status', s.status,
        'dishes', coalesce((
          select jsonb_agg(jsonb_build_object(
            'recipe_id', d.recipe_id, 'recipe_code', r.code,
            'recipe_name', r.name, 'planned_qty', d.planned_qty,
            'portions_per_batch', r.portions_per_batch,
            'batches', case
              when r.portions_per_batch is not null
                and r.portions_per_batch > 0
              then ceil(d.planned_qty / r.portions_per_batch)
              else null end
          ) order by r.name)
          from public.buffet_session_dishes d
          join public.recipes r on r.id = d.recipe_id
          where d.session_id = s.id
        ), '[]'::jsonb)
      ) order by s.meal)
      from public.buffet_sessions s
      where s.property_id = p_property_id
        and s.business_date = v_date
        and s.status in ('planned', 'open')
    ), '[]'::jsonb),
    'banquets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'doc_no', b.doc_no, 'customer_name', b.customer_name,
        'hall', b.hall, 'start_time', b.start_time, 'end_time', b.end_time,
        'guests_count', b.guests_count, 'status', b.status,
        'dishes', coalesce((
          select jsonb_agg(jsonb_build_object(
            'recipe_id', d.recipe_id, 'recipe_code', r.code,
            'recipe_name', r.name, 'qty', d.qty,
            'portions_per_batch', r.portions_per_batch,
            'batches', case
              when r.portions_per_batch is not null
                and r.portions_per_batch > 0
              then ceil(d.qty / r.portions_per_batch)
              else null end
          ) order by r.name)
          from public.banquet_dishes d
          join public.recipes r on r.id = d.recipe_id
          where d.banquet_id = b.id
        ), '[]'::jsonb)
      ) order by b.start_time)
      from public.banquets b
      where b.property_id = p_property_id
        and b.event_date = v_date
        and b.status in ('confirmed', 'in_progress')
    ), '[]'::jsonb),
    -- Bang NVL chuan bi gop: dinh luong version active x so phan
    -- (theo quy uoc §5: co portions_per_batch thi tinh theo me).
    'prep', coalesce((
      select jsonb_agg(jsonb_build_object(
        'item_id', p.item_id, 'item_code', i.code, 'item_name', i.name,
        'uom', p.uom, 'total_qty', p.total_qty
      ) order by i.name)
      from (
        select e.item_id, e.uom, sum(e.qty) as total_qty
        from (
          select d.recipe_id, d.planned_qty as servings
          from public.buffet_sessions s
          join public.buffet_session_dishes d on d.session_id = s.id
          where s.property_id = p_property_id
            and s.business_date = v_date
            and s.status in ('planned', 'open')
          union all
          select d.recipe_id, d.qty as servings
          from public.banquets b
          join public.banquet_dishes d on d.banquet_id = b.id
          where b.property_id = p_property_id
            and b.event_date = v_date
            and b.status in ('confirmed', 'in_progress')
        ) dd
        cross join lateral
          public._restaurant_expand_recipe(dd.recipe_id, dd.servings) e
        group by e.item_id, e.uom
      ) p
      join public.items i on i.id = p.item_id
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.restaurant_kitchen_today(uuid, date)
  from public, anon, authenticated;
grant execute on function public.restaurant_kitchen_today(uuid, date)
  to authenticated;
