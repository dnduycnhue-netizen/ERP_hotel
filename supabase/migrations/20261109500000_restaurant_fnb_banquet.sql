-- ===========================================================================
-- 20261109500000_restaurant_fnb_banquet.sql
--
-- M06 — Module Nha hang (F&B) + Dat tiec (banquet).
-- Dac ta: docs/modules/M06-restaurant.md. Bang cong thuc theo
-- docs/03-DATA-MODEL.md A7 (P2 — "tao bang som"): recipes /
-- recipe_versions / recipe_lines (pos_item_map chua lam — cho co POS).
--
-- Du lieu goc: 2 file Excel (Lst_2020_DL_Buffet.xlsx: Menu 75 mon,
-- 02 DL goc 358 dong dinh luong; Lst_Alacarte_foodcost.xlsx: 53 dong /
-- 6 mon). Mon + dinh luong CHUA nhap o migration nay — can task nhap
-- rieng sau (bep truong dien portions_per_batch tung mon, Q167/Q168).
-- Foodcost tinh tu GIA TRAN hien hanh (ceiling_prices); dong nao thieu
-- gia tran thi foodcost = NULL + co has_unknown_cost (khong dung gia
-- Excel 2018-2020 da cu). Quy doi don vi theo items.recipe_uom /
-- stock_to_recipe; khong quy doi duoc -> dong do tinh la chua biet gia.
--
-- Quy tac chung (mau T-042): unique(id, org_id); RLS 100% + policy
-- SELECT-only; write-guard trigger chan ghi truc tiep (moi ghi qua RPC
-- SECURITY DEFINER, co app.restaurant_guard_bypass); set_updated_at().
-- RLS dung `in (select public.my_property_ids())` — TUYET DOI KHONG
-- dung `= any (public.my_property_ids())` (loi 0A000 khi db push).
-- Audit: khong insert audit_log o day (mau po_submit/service_accept —
-- trang thai chung tu tu ghi lai trong bang).
-- Test: supabase/tests/restaurant_test.sql (pgTAP).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Ma quyen moi (AGENTS.md quy tac 10) + gan cho vai tro mau.
--    restaurant.view: chef, outlet_head, front_desk, bartender, owner, gm
--    dish.manage: chef, outlet_head, owner, gm
--    sale.record: front_desk, outlet_head, chef, owner, gm
--    buffet.manage: chef, outlet_head, owner, gm
--    banquet.manage: front_desk, outlet_head, owner, gm
--    report.view.rpt_fnb_revenue: owner, gm, internal_audit (mau rpt_minibar)
-- ---------------------------------------------------------------------------
insert into public.permissions
  (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('report.view.rpt_fnb_revenue', 'Báo cáo',
   'Xem báo cáo doanh thu F&B',
   'Xem doanh thu, giá vốn và lãi gộp từng món ăn / buffet / tiệc.',
   'sensitive', 1392),
  ('restaurant.view', 'Nhà hàng',
   'Xem nhà hàng',
   'Xem món ăn, màn bếp, bán hàng, phiên buffet và đặt tiệc.',
   'normal', 1400),
  ('restaurant.dish.manage', 'Nhà hàng',
   'Quản lý món ăn + công thức',
   'Tạo/sửa món ăn, công thức và định lượng NVL; bật/tắt món.',
   'sensitive', 1410),
  ('restaurant.sale.record', 'Nhà hàng',
   'Ghi nhận bán hàng',
   'Ghi bán theo món theo ca/ngày; hủy dòng bán tay ghi sai.',
   'sensitive', 1420),
  ('restaurant.buffet.manage', 'Nhà hàng',
   'Quản lý phiên buffet',
   'Tạo/sửa/đóng/hủy phiên buffet.',
   'sensitive', 1430),
  ('restaurant.banquet.manage', 'Nhà hàng',
   'Quản lý đặt tiệc',
   'Tạo/sửa/xác nhận/bắt đầu/hoàn thành/hủy tiệc.',
   'sensitive', 1440)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('chef', 'restaurant.view'),
  ('outlet_head', 'restaurant.view'),
  ('front_desk', 'restaurant.view'),
  ('bartender', 'restaurant.view'),
  ('owner', 'restaurant.view'),
  ('gm', 'restaurant.view'),
  ('chef', 'restaurant.dish.manage'),
  ('outlet_head', 'restaurant.dish.manage'),
  ('owner', 'restaurant.dish.manage'),
  ('gm', 'restaurant.dish.manage'),
  ('front_desk', 'restaurant.sale.record'),
  ('outlet_head', 'restaurant.sale.record'),
  ('chef', 'restaurant.sale.record'),
  ('owner', 'restaurant.sale.record'),
  ('gm', 'restaurant.sale.record'),
  ('chef', 'restaurant.buffet.manage'),
  ('outlet_head', 'restaurant.buffet.manage'),
  ('owner', 'restaurant.buffet.manage'),
  ('gm', 'restaurant.buffet.manage'),
  ('front_desk', 'restaurant.banquet.manage'),
  ('outlet_head', 'restaurant.banquet.manage'),
  ('owner', 'restaurant.banquet.manage'),
  ('gm', 'restaurant.banquet.manage'),
  ('owner', 'report.view.rpt_fnb_revenue'),
  ('gm', 'report.view.rpt_fnb_revenue'),
  ('internal_audit', 'report.view.rpt_fnb_revenue')
) as v(role_code, permission_code)
  on r.code = v.role_code
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Bang (A7, thu gon cho MVP — xem M06 §2).
-- ---------------------------------------------------------------------------
create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  code text not null check (btrim(code) <> ''),
  name text not null check (btrim(name) <> ''),
  kind text not null
    check (kind in ('dish', 'buffet_batch', 'set_menu')),
  group_name text,
  yield_qty numeric(18,4) check (yield_qty is null or yield_qty > 0),
  yield_uom text references public.uoms(code),
  portions_per_batch numeric(18,4)
    check (portions_per_batch is null or portions_per_batch > 0),
  diet_flags text[] not null default '{}'::text[],
  sale_price numeric(18,2) check (sale_price is null or sale_price >= 0),
  is_active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, code)
);

create table public.recipe_versions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  recipe_id uuid not null,
  version_no integer not null check (version_no > 0),
  valid_from date not null
    default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  status text not null default 'active'
    check (status in ('draft', 'active', 'retired')),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (recipe_id, version_no),
  foreign key (recipe_id, org_id) references public.recipes(id, org_id)
    on delete cascade
);

create table public.recipe_lines (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  version_id uuid not null,
  item_id uuid,
  sub_recipe_id uuid,
  qty numeric(18,4) not null check (qty > 0),
  uom text not null references public.uoms(code),
  loss_pct numeric(5,2) not null default 0
    check (loss_pct >= 0 and loss_pct <= 100),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (version_id, org_id)
    references public.recipe_versions(id, org_id) on delete cascade,
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (sub_recipe_id, org_id) references public.recipes(id, org_id),
  -- A7: dung 1 trong 2 — NVL truc tiep hoac mon con (sub-recipe).
  check ((item_id is null) <> (sub_recipe_id is null))
);

create table public.buffet_sessions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  business_date date not null,
  meal text not null check (meal in ('breakfast', 'lunch', 'dinner')),
  guest_count integer not null default 0 check (guest_count >= 0),
  price_per_guest numeric(18,2) check (price_per_guest is null or price_per_guest >= 0),
  status text not null default 'planned'
    check (status in ('planned', 'open', 'closed', 'cancelled')),
  cancel_reason text,
  notes text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id)
);

-- 1 KS chi co 1 phien moi buoi moi ngay (tru phien da huy).
create unique index buffet_sessions_one_per_meal
  on public.buffet_sessions (property_id, business_date, meal)
  where status <> 'cancelled';

create table public.buffet_session_dishes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  session_id uuid not null,
  recipe_id uuid not null,
  planned_qty numeric(18,4) not null check (planned_qty > 0),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (session_id, recipe_id),
  foreign key (session_id, org_id)
    references public.buffet_sessions(id, org_id) on delete cascade,
  foreign key (recipe_id, org_id) references public.recipes(id, org_id)
);

create table public.dish_sales (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  business_date date not null,
  recipe_id uuid,
  source text not null check (source in ('manual', 'buffet', 'banquet')),
  ref_id uuid,
  qty numeric(18,4) not null check (qty > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  amount numeric(18,2) not null check (amount >= 0),
  voided_at timestamptz,
  voided_by uuid references auth.users(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (recipe_id, org_id) references public.recipes(id, org_id),
  -- recipe_id NULL = doanh thu buffet gop theo khach (khong theo mon).
  check ((source = 'buffet') = (recipe_id is null))
);

create index dish_sales_property_date
  on public.dish_sales (property_id, business_date);

create table public.banquets (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  doc_no text not null,
  customer_name text not null check (btrim(customer_name) <> ''),
  customer_phone text,
  event_date date not null,
  start_time time not null,
  end_time time not null,
  hall text not null check (btrim(hall) <> ''),
  tables_count integer not null default 0 check (tables_count >= 0),
  guests_count integer not null check (guests_count > 0),
  deposit_amount numeric(18,2) not null default 0
    check (deposit_amount >= 0),
  status text not null default 'new'
    check (status in ('new', 'confirmed', 'in_progress', 'completed', 'cancelled')),
  cancel_reason text,
  notes text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, doc_no),
  check (end_time > start_time)
);

create index banquets_property_date
  on public.banquets (property_id, event_date);

create table public.banquet_dishes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  banquet_id uuid not null,
  recipe_id uuid not null,
  qty numeric(18,4) not null check (qty > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (banquet_id, recipe_id),
  foreign key (banquet_id, org_id)
    references public.banquets(id, org_id) on delete cascade,
  foreign key (recipe_id, org_id) references public.recipes(id, org_id)
);

-- ---------------------------------------------------------------------------
-- 3. Write-guard (mau T-042) + updated_at. Ghi truc tiep bi chan —
-- chi RPC SECURITY DEFINER duoc ghi (set app.restaurant_guard_bypass).
-- ---------------------------------------------------------------------------
create or replace function public._restaurant_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.restaurant_guard_bypass', true), '') <> 'on' then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return coalesce(new, old);
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'recipes', 'recipe_versions', 'recipe_lines',
    'buffet_sessions', 'buffet_session_dishes',
    'dish_sales',
    'banquets', 'banquet_dishes'
  ] loop
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function public._restaurant_write_guard()',
      'trg_' || v_table || '_write_guard', v_table
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. RLS: bat 100% + policy SELECT-only.
--    Bang cap chuoi (recipes/versions/lines): kiem qua properties cung org.
--    Bang theo KS: property_id in (select my_property_ids()).
-- ---------------------------------------------------------------------------
alter table public.recipes enable row level security;
alter table public.recipe_versions enable row level security;
alter table public.recipe_lines enable row level security;
alter table public.buffet_sessions enable row level security;
alter table public.buffet_session_dishes enable row level security;
alter table public.dish_sales enable row level security;
alter table public.banquets enable row level security;
alter table public.banquet_dishes enable row level security;

create policy recipes_select on public.recipes
for select using (
  exists (select 1 from public.properties p where p.org_id = recipes.org_id
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'restaurant.view')
      or public.has_perm(p.id, 'restaurant.dish.manage')
      or public.has_perm(p.id, 'restaurant.sale.record')
      or public.has_perm(p.id, 'restaurant.buffet.manage')
      or public.has_perm(p.id, 'restaurant.banquet.manage')))
);

create policy recipe_versions_select on public.recipe_versions
for select using (
  exists (select 1 from public.properties p where p.org_id = recipe_versions.org_id
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'restaurant.view')
      or public.has_perm(p.id, 'restaurant.dish.manage')
      or public.has_perm(p.id, 'restaurant.sale.record')
      or public.has_perm(p.id, 'restaurant.buffet.manage')
      or public.has_perm(p.id, 'restaurant.banquet.manage')))
);

create policy recipe_lines_select on public.recipe_lines
for select using (
  exists (select 1 from public.properties p where p.org_id = recipe_lines.org_id
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'restaurant.view')
      or public.has_perm(p.id, 'restaurant.dish.manage')
      or public.has_perm(p.id, 'restaurant.sale.record')
      or public.has_perm(p.id, 'restaurant.buffet.manage')
      or public.has_perm(p.id, 'restaurant.banquet.manage')))
);

create policy buffet_sessions_select on public.buffet_sessions
for select using (
  property_id in (select public.my_property_ids())
  and (public.has_perm(property_id, 'restaurant.view')
    or public.has_perm(property_id, 'restaurant.buffet.manage')
    or public.has_perm(property_id, 'restaurant.banquet.manage'))
);

create policy buffet_session_dishes_select on public.buffet_session_dishes
for select using (
  exists (select 1 from public.buffet_sessions s
    where s.id = buffet_session_dishes.session_id
      and s.property_id in (select public.my_property_ids())
      and (public.has_perm(s.property_id, 'restaurant.view')
        or public.has_perm(s.property_id, 'restaurant.buffet.manage')
        or public.has_perm(s.property_id, 'restaurant.banquet.manage')))
);

create policy dish_sales_select on public.dish_sales
for select using (
  property_id in (select public.my_property_ids())
  and (public.has_perm(property_id, 'restaurant.view')
    or public.has_perm(property_id, 'restaurant.sale.record')
    or public.has_perm(property_id, 'restaurant.buffet.manage')
    or public.has_perm(property_id, 'restaurant.banquet.manage'))
);

create policy banquets_select on public.banquets
for select using (
  property_id in (select public.my_property_ids())
  and (public.has_perm(property_id, 'restaurant.view')
    or public.has_perm(property_id, 'restaurant.banquet.manage'))
);

create policy banquet_dishes_select on public.banquet_dishes
for select using (
  exists (select 1 from public.banquets b
    where b.id = banquet_dishes.banquet_id
      and b.property_id in (select public.my_property_ids())
      and (public.has_perm(b.property_id, 'restaurant.view')
        or public.has_perm(b.property_id, 'restaurant.banquet.manage')))
);

-- ---------------------------------------------------------------------------
-- 5. Helper noi bo (khong grant execute — chi RPC SECURITY DEFINER goi).
--
-- Quy uoc dinh luong (M06 §3):
-- - Neu recipe co portions_per_batch: lines la dinh luong CHO 1 ME
--   (batch) -> so me = ceil(so phan / portions_per_batch).
-- - Neu khong co: lines la dinh luong THEO PHAN -> nhan thang so phan.
-- - loss_pct: luong hao hut cong them (qty x (1 + loss/100)).
-- - Gia tran: uu tien dong gia co uom = uom cua line; neu khong co thi
--   lay gia theo stock_uom + quy doi (recipe_uom -> stock_uom qua
--   items.stock_to_recipe). Khong quy doi duoc -> dong do chua biet gia.
-- ---------------------------------------------------------------------------

-- Mo rong 1 mon thanh cac dong NVL la (xu ly sub-recipe toi da 3 tang,
-- chong vong lap bang path). Tra ve so luong DA gom loss + so me/phan.
create or replace function public._restaurant_expand_recipe(
  p_recipe_id uuid,
  p_servings numeric
)
returns table (item_id uuid, uom text, qty numeric)
language sql stable security definer
set search_path = public, auth, pg_temp
as $$
  with recursive walk(recipe_id, servings, depth, path, leaf_item_id, leaf_qty, leaf_uom) as (
    select p_recipe_id, p_servings, 0, array[p_recipe_id],
      null::uuid, null::numeric, null::text
    union all
    select
      case when rl.item_id is not null then null else rl.sub_recipe_id end,
      case when rl.item_id is not null then null
        else rl.qty * case
          when r.portions_per_batch is not null and r.portions_per_batch > 0
            then ceil(w.servings / r.portions_per_batch)
          else w.servings end end,
      w.depth + 1,
      w.path || coalesce(rl.sub_recipe_id, w.recipe_id),
      rl.item_id,
      rl.qty * (1 + rl.loss_pct / 100.0) * case
        when r.portions_per_batch is not null and r.portions_per_batch > 0
          then ceil(w.servings / r.portions_per_batch)
        else w.servings end,
      rl.uom
    from walk w
    join public.recipes r on r.id = w.recipe_id
    join public.recipe_versions rv
      on rv.recipe_id = w.recipe_id and rv.status = 'active'
    join public.recipe_lines rl on rl.version_id = rv.id
    where w.leaf_item_id is null
      and w.depth < 3
      and (rl.sub_recipe_id is null
        or not (rl.sub_recipe_id = any (w.path)))
  )
  select leaf_item_id, leaf_uom, sum(leaf_qty)
  from walk
  where leaf_item_id is not null
  group by leaf_item_id, leaf_uom;
$$;

-- Foodcost THEO PHAN cho moi mon co version active (gia tran hien hanh).
-- foodcost NULL + has_unknown_cost = true khi: khong co version active,
-- hoac co dong khong tim duoc gia / khong quy doi duoc don vi.
create or replace function public._restaurant_foodcost_list(
  p_property_id uuid
)
returns table (recipe_id uuid, foodcost numeric, has_unknown_cost boolean)
language sql stable security definer
set search_path = public, auth, pg_temp
as $$
  with prop as (
    select org_id from public.properties where id = p_property_id
  ),
  v_today as (
    select (now() at time zone 'Asia/Ho_Chi_Minh')::date as d
  ),
  act as (
    select rv.recipe_id, rv.id as version_id
    from public.recipe_versions rv
    join prop on rv.org_id = prop.org_id
    where rv.status = 'active'
  ),
  leaves as (
    select r.id as recipe_id, e.item_id, e.uom, e.qty
    from public.recipes r
    join prop on r.org_id = prop.org_id
    cross join lateral public._restaurant_expand_recipe(r.id, 1) e
  ),
  priced as (
    select l.recipe_id,
      case
        when cp_line.price is not null then l.qty * cp_line.price
        when cp_stock.price is not null and l.uom = it.stock_uom
          then l.qty * cp_stock.price
        when cp_stock.price is not null and l.uom = it.recipe_uom
          and it.stock_to_recipe is not null
          then l.qty / it.stock_to_recipe * cp_stock.price
        else null
      end as line_cost
    from leaves l
    join public.items it on it.id = l.item_id
    left join lateral (
      select cp.price from public.ceiling_prices cp, v_today t
      where cp.org_id = it.org_id
        and cp.property_id = p_property_id
        and cp.item_id = l.item_id and cp.uom = l.uom
        and cp.valid_from <= t.d
        and (cp.valid_to is null or cp.valid_to >= t.d)
      order by cp.valid_from desc limit 1
    ) cp_line on true
    left join lateral (
      select cp.price from public.ceiling_prices cp, v_today t
      where cp.org_id = it.org_id
        and cp.property_id = p_property_id
        and cp.item_id = l.item_id and cp.uom = it.stock_uom
        and cp.valid_from <= t.d
        and (cp.valid_to is null or cp.valid_to >= t.d)
      order by cp.valid_from desc limit 1
    ) cp_stock on true
  ),
  agg as (
    select recipe_id,
      bool_or(line_cost is null) as has_unknown,
      sum(line_cost) as total
    from priced
    group by recipe_id
  )
  select r.id,
    case
      when a.recipe_id is null and not exists
        (select 1 from act where act.recipe_id = r.id)
        then null
      when coalesce(a.has_unknown, false) then null
      else round(coalesce(a.total, 0) / coalesce(r.portions_per_batch, 1), 2)
    end,
    case
      when not exists (select 1 from act where act.recipe_id = r.id)
        then true
      else coalesce(a.has_unknown, false)
    end
  from public.recipes r
  join prop on r.org_id = prop.org_id
  left join agg a on a.recipe_id = r.id;
$$;

-- Foodcost theo phan cho toan bo mon (UI danh sach).
create or replace function public.recipe_foodcost_list(p_property_id uuid)
returns table (recipe_id uuid, foodcost numeric, has_unknown_cost boolean)
language plpgsql stable security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.require_perm(p_property_id, 'restaurant.view');
  return query select * from public._restaurant_foodcost_list(p_property_id);
end;
$$;

revoke all on function public.recipe_foodcost_list(uuid)
  from public, anon, authenticated;
grant execute on function public.recipe_foodcost_list(uuid) to authenticated;

-- Foodcost theo phan cho 1 mon (UI chi tiet + bao cao).
create or replace function public.recipe_foodcost(
  p_property_id uuid, p_recipe_id uuid
)
returns numeric
language plpgsql stable security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_cost numeric;
begin
  perform public.require_perm(p_property_id, 'restaurant.view');
  select f.foodcost into v_cost
  from public._restaurant_foodcost_list(p_property_id) f
  where f.recipe_id = p_recipe_id;
  return v_cost;
end;
$$;

revoke all on function public.recipe_foodcost(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.recipe_foodcost(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Mon an / cong thuc.
-- ---------------------------------------------------------------------------
create or replace function public.recipe_save(
  p_property_id uuid, p_recipe jsonb
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_recipe_id uuid;
  v_version_id uuid;
  v_version_no integer;
  v_line jsonb;
  v_item_id uuid;
  v_sub_id uuid;
  v_qty numeric;
  v_uom text;
  v_loss numeric;
  v_code text;
  v_name text;
  v_kind text;
  v_yield_qty numeric;
  v_portions numeric;
  v_sale_price numeric;
begin
  perform public.require_perm(p_property_id, 'restaurant.dish.manage');

  select org_id into v_org_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  v_code := btrim(coalesce(p_recipe ->> 'code', ''));
  v_name := btrim(coalesce(p_recipe ->> 'name', ''));
  v_kind := p_recipe ->> 'kind';
  if v_code = '' or v_name = ''
    or v_kind not in ('dish', 'buffet_batch', 'set_menu') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if jsonb_typeof(coalesce(p_recipe -> 'lines', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_yield_qty := nullif(p_recipe ->> 'yield_qty', '')::numeric;
  v_portions := nullif(p_recipe ->> 'portions_per_batch', '')::numeric;
  v_sale_price := nullif(p_recipe ->> 'sale_price', '')::numeric;
  if (v_yield_qty is not null and v_yield_qty <= 0)
    or (v_portions is not null and v_portions <= 0)
    or (v_sale_price is not null and v_sale_price < 0) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_recipe_id := nullif(p_recipe ->> 'id', '')::uuid;
  if v_recipe_id is not null
    and not exists (select 1 from public.recipes
      where id = v_recipe_id and org_id = v_org_id) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if exists (select 1 from public.recipes
    where org_id = v_org_id and code = v_code
      and id <> coalesce(v_recipe_id, '00000000-0000-0000-0000-000000000000')) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  if v_recipe_id is null then
    insert into public.recipes
      (org_id, code, name, kind, group_name, yield_qty, yield_uom,
       portions_per_batch, diet_flags, sale_price, is_active, notes)
    values
      (v_org_id, v_code, v_name, v_kind,
       nullif(p_recipe ->> 'group_name', ''),
       v_yield_qty, nullif(p_recipe ->> 'yield_uom', ''),
       v_portions,
       coalesce((select array_agg(x) from jsonb_array_elements_text(
         coalesce(p_recipe -> 'diet_flags', '[]'::jsonb)) x), '{}'::text[]),
       v_sale_price,
       coalesce((p_recipe ->> 'is_active')::boolean, true),
       nullif(p_recipe ->> 'notes', ''))
    returning id into v_recipe_id;
  else
    update public.recipes set
      code = v_code, name = v_name, kind = v_kind,
      group_name = nullif(p_recipe ->> 'group_name', ''),
      yield_qty = v_yield_qty,
      yield_uom = nullif(p_recipe ->> 'yield_uom', ''),
      portions_per_batch = v_portions,
      diet_flags = coalesce((select array_agg(x) from jsonb_array_elements_text(
        coalesce(p_recipe -> 'diet_flags', '[]'::jsonb)) x), '{}'::text[]),
      sale_price = v_sale_price,
      is_active = coalesce((p_recipe ->> 'is_active')::boolean, is_active),
      notes = nullif(p_recipe ->> 'notes', '')
    where id = v_recipe_id and org_id = v_org_id;
  end if;

  -- Version moi len active, version active cu ve huu.
  update public.recipe_versions set status = 'retired'
  where recipe_id = v_recipe_id and status = 'active';

  select coalesce(max(version_no), 0) + 1 into v_version_no
  from public.recipe_versions where recipe_id = v_recipe_id;

  insert into public.recipe_versions
    (org_id, recipe_id, version_no, valid_from, status)
  values (v_org_id, v_recipe_id, v_version_no, v_today, 'active')
  returning id into v_version_id;

  for v_line in
    select * from jsonb_array_elements(
      coalesce(p_recipe -> 'lines', '[]'::jsonb))
  loop
    v_item_id := nullif(v_line ->> 'item_id', '')::uuid;
    v_sub_id := nullif(v_line ->> 'sub_recipe_id', '')::uuid;
    if (v_item_id is null) = (v_sub_id is null) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_line ->> 'qty')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_uom := v_line ->> 'uom';
    if v_uom is null
      or not exists (select 1 from public.uoms where code = v_uom) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_loss := coalesce((v_line ->> 'loss_pct')::numeric, 0);
    if v_loss < 0 or v_loss > 100 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_item_id is not null
      and not exists (select 1 from public.items
        where id = v_item_id and org_id = v_org_id) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_sub_id is not null then
      if v_sub_id = v_recipe_id then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      if not exists (select 1 from public.recipes
        where id = v_sub_id and org_id = v_org_id) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
    end if;
    insert into public.recipe_lines
      (org_id, version_id, item_id, sub_recipe_id, qty, uom, loss_pct, note)
    values
      (v_org_id, v_version_id, v_item_id, v_sub_id, v_qty, v_uom,
       v_loss, nullif(v_line ->> 'note', ''));
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', v_recipe_id, 'version_no', v_version_no
  );
end;
$$;

revoke all on function public.recipe_save(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.recipe_save(uuid, jsonb) to authenticated;

create or replace function public.recipe_set_active(
  p_property_id uuid, p_recipe_id uuid, p_is_active boolean
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
begin
  perform public.require_perm(p_property_id, 'restaurant.dish.manage');

  select org_id into v_org_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.recipes set is_active = p_is_active
  where id = p_recipe_id and org_id = v_org_id;
  if not found then raise exception 'ERR_INVALID_VALUE'; end if;

  return jsonb_build_object(
    'ok', true, 'id', p_recipe_id, 'is_active', p_is_active
  );
end;
$$;

revoke all on function public.recipe_set_active(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.recipe_set_active(uuid, uuid, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Man bep + tong hop doanh thu.
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
        'foodcost', f.foodcost, 'has_unknown_cost', f.has_unknown_cost
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
            'recipe_name', r.name, 'planned_qty', d.planned_qty
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
            'recipe_name', r.name, 'qty', d.qty
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

create or replace function public.restaurant_sales_summary(
  p_property_id uuid, p_from date default null, p_to date default null
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_from date := coalesce(p_from,
    date_trunc('month', (now() at time zone 'Asia/Ho_Chi_Minh')::date)::date);
  v_to date := coalesce(p_to,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date);
begin
  perform public.require_perm(p_property_id, 'restaurant.view');

  select org_id into v_org_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_from > v_to then raise exception 'ERR_INVALID_VALUE'; end if;

  return (
    with sales as (
      select ds.*
      from public.dish_sales ds
      where ds.property_id = p_property_id
        and ds.business_date between v_from and v_to
        and ds.voided_at is null
    ),
    per_dish as (
      select
        s.recipe_id, r.code as recipe_code, r.name as recipe_name,
        sum(s.qty) as qty,
        sum(s.amount) as revenue,
        case
          when s.recipe_id is null then null
          when f.has_unknown_cost then null
          else round(sum(s.qty) * coalesce(f.foodcost, 0), 2)
        end as foodcost
      from sales s
      left join public.recipes r on r.id = s.recipe_id
      left join public._restaurant_foodcost_list(p_property_id) f
        on f.recipe_id = s.recipe_id
      group by s.recipe_id, r.code, r.name, f.has_unknown_cost, f.foodcost
    )
    select jsonb_build_object(
      'ok', true, 'from', v_from, 'to', v_to,
      'totals', jsonb_build_object(
        'qty', coalesce((select sum(qty) from sales), 0),
        'revenue', coalesce((select sum(amount) from sales), 0),
        'foodcost', coalesce((select sum(foodcost) from per_dish), 0),
        'gross_profit', coalesce((select sum(amount) from sales), 0)
          - coalesce((select sum(foodcost) from per_dish), 0),
        'has_unknown_cost',
          exists (select 1 from per_dish where foodcost is null
            and recipe_id is not null)
      ),
      'by_day', coalesce((
        select jsonb_agg(jsonb_build_object(
          'business_date', business_date,
          'qty', sum(qty), 'revenue', sum(amount)
        ) order by business_date)
        from sales group by business_date
      ), '[]'::jsonb),
      'by_dish', coalesce((
        select jsonb_agg(jsonb_build_object(
          'recipe_id', recipe_id, 'recipe_code', recipe_code,
          'recipe_name', coalesce(recipe_name, 'Buffet (theo khách)'),
          'qty', qty, 'revenue', revenue, 'foodcost', foodcost,
          'gross_profit', case when foodcost is null then null
            else revenue - foodcost end
        ) order by revenue desc)
        from per_dish
      ), '[]'::jsonb)
    )
  );
end;
$$;

revoke all on function public.restaurant_sales_summary(uuid, date, date)
  from public, anon, authenticated;
grant execute on function public.restaurant_sales_summary(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Phien buffet.
-- ---------------------------------------------------------------------------
create or replace function public.buffet_session_save(
  p_property_id uuid, p_session jsonb
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_session_id uuid;
  v_dish jsonb;
  v_recipe_id uuid;
  v_qty numeric;
begin
  perform public.require_perm(p_property_id, 'restaurant.buffet.manage');

  select org_id, legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  if (p_session ->> 'business_date')::date is null
    or (p_session ->> 'meal') not in ('breakfast', 'lunch', 'dinner') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if jsonb_typeof(coalesce(p_session -> 'dishes', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  v_session_id := nullif(p_session ->> 'id', '')::uuid;
  if v_session_id is null then
    insert into public.buffet_sessions
      (org_id, legal_entity_id, property_id, business_date, meal,
       guest_count, price_per_guest, notes)
    values
      (v_org_id, v_legal_entity_id, p_property_id,
       (p_session ->> 'business_date')::date, p_session ->> 'meal',
       coalesce((p_session ->> 'guest_count')::integer, 0),
       nullif(p_session ->> 'price_per_guest', '')::numeric,
       nullif(p_session ->> 'notes', ''))
    returning id into v_session_id;
  else
    update public.buffet_sessions set
      business_date = (p_session ->> 'business_date')::date,
      meal = p_session ->> 'meal',
      guest_count = coalesce((p_session ->> 'guest_count')::integer, guest_count),
      price_per_guest = nullif(p_session ->> 'price_per_guest', '')::numeric,
      notes = nullif(p_session ->> 'notes', '')
    where id = v_session_id and property_id = p_property_id
      and status in ('planned', 'open');
    if not found then raise exception 'ERR_INVALID_STATUS'; end if;
  end if;

  if p_session ? 'dishes' then
    delete from public.buffet_session_dishes
    where session_id = v_session_id;
    for v_dish in
      select * from jsonb_array_elements(p_session -> 'dishes')
    loop
      v_recipe_id := nullif(v_dish ->> 'recipe_id', '')::uuid;
      v_qty := (v_dish ->> 'planned_qty')::numeric;
      if v_recipe_id is null or v_qty is null or v_qty <= 0
        or not exists (select 1 from public.recipes
          where id = v_recipe_id and org_id = v_org_id) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      insert into public.buffet_session_dishes
        (org_id, session_id, recipe_id, planned_qty, note)
      values
        (v_org_id, v_session_id, v_recipe_id, v_qty,
         nullif(v_dish ->> 'note', ''));
    end loop;
  end if;

  return jsonb_build_object('ok', true, 'id', v_session_id);
end;
$$;

revoke all on function public.buffet_session_save(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.buffet_session_save(uuid, jsonb)
  to authenticated;

create or replace function public.buffet_session_close(
  p_property_id uuid, p_session_id uuid,
  p_guest_count integer, p_price_per_guest numeric
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_row public.buffet_sessions%rowtype;
  v_revenue numeric;
begin
  perform public.require_perm(p_property_id, 'restaurant.buffet.manage');

  if p_guest_count is null or p_guest_count <= 0
    or p_price_per_guest is null or p_price_per_guest < 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select * into v_row from public.buffet_sessions
  where id = p_session_id and property_id = p_property_id;
  if not found then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_row.status not in ('planned', 'open') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_revenue := round(p_guest_count::numeric * p_price_per_guest, 2);

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.buffet_sessions set
    status = 'closed', guest_count = p_guest_count,
    price_per_guest = p_price_per_guest
  where id = p_session_id;

  -- Doanh thu buffet gop theo khach (khong theo mon).
  insert into public.dish_sales
    (org_id, legal_entity_id, property_id, business_date,
     recipe_id, source, ref_id, qty, unit_price, amount)
  values
    (v_row.org_id, v_row.legal_entity_id, p_property_id,
     v_row.business_date, null, 'buffet', p_session_id,
     p_guest_count, p_price_per_guest, v_revenue);

  return jsonb_build_object(
    'ok', true, 'id', p_session_id, 'revenue', v_revenue
  );
end;
$$;

revoke all on function public.buffet_session_close(uuid, uuid, integer, numeric)
  from public, anon, authenticated;
grant execute on function public.buffet_session_close(uuid, uuid, integer, numeric)
  to authenticated;

create or replace function public.buffet_session_cancel(
  p_property_id uuid, p_session_id uuid, p_reason text
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_status text;
begin
  perform public.require_perm(p_property_id, 'restaurant.buffet.manage');

  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select status into v_status from public.buffet_sessions
  where id = p_session_id and property_id = p_property_id;
  if v_status is null then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_status not in ('planned', 'open') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.buffet_sessions set
    status = 'cancelled', cancel_reason = btrim(p_reason)
  where id = p_session_id;

  return jsonb_build_object('ok', true, 'id', p_session_id);
end;
$$;

revoke all on function public.buffet_session_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.buffet_session_cancel(uuid, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Ghi nhan ban hang theo mon.
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

  return jsonb_build_object(
    'ok', true, 'id', v_sale_id, 'amount', v_amount
  );
end;
$$;

revoke all on function public.dish_sale_record(uuid, date, uuid, numeric, numeric)
  from public, anon, authenticated;
grant execute on function public.dish_sale_record(uuid, date, uuid, numeric, numeric)
  to authenticated;

-- Huy dong ban tay ghi sai: danh dau void (khong xoa dong — giu so).
create or replace function public.dish_sale_void(
  p_property_id uuid, p_sale_id uuid
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_row public.dish_sales%rowtype;
begin
  perform public.require_perm(p_property_id, 'restaurant.sale.record');

  select * into v_row from public.dish_sales
  where id = p_sale_id and property_id = p_property_id;
  if not found then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_row.source <> 'manual' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_row.voided_at is not null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.dish_sales set
    voided_at = now(), voided_by = auth.uid()
  where id = p_sale_id;

  return jsonb_build_object('ok', true, 'id', p_sale_id);
end;
$$;

revoke all on function public.dish_sale_void(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.dish_sale_void(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Dat tiec (banquet).
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
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  select org_id, legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  if btrim(coalesce(p_banquet ->> 'customer_name', '')) = ''
    or (p_banquet ->> 'event_date')::date is null
    or (p_banquet ->> 'event_date')::date < v_today
    or (p_banquet ->> 'start_time')::time is null
    or (p_banquet ->> 'end_time')::time is null
    or (p_banquet ->> 'end_time')::time
      <= (p_banquet ->> 'start_time')::time
    or btrim(coalesce(p_banquet ->> 'hall', '')) = ''
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
    v_doc_no := public.next_doc_no(
      v_legal_entity_id, 'banquet', (p_banquet ->> 'event_date')::date);
    insert into public.banquets
      (org_id, legal_entity_id, property_id, doc_no,
       customer_name, customer_phone, event_date, start_time, end_time,
       hall, tables_count, guests_count, deposit_amount, notes)
    values
      (v_org_id, v_legal_entity_id, p_property_id, v_doc_no,
       btrim(p_banquet ->> 'customer_name'),
       nullif(p_banquet ->> 'customer_phone', ''),
       (p_banquet ->> 'event_date')::date,
       (p_banquet ->> 'start_time')::time,
       (p_banquet ->> 'end_time')::time,
       btrim(p_banquet ->> 'hall'),
       coalesce((p_banquet ->> 'tables_count')::integer, 0),
       (p_banquet ->> 'guests_count')::integer,
       coalesce((p_banquet ->> 'deposit_amount')::numeric, 0),
       nullif(p_banquet ->> 'notes', ''))
    returning id, doc_no into v_banquet_id, v_doc_no;
  else
    update public.banquets set
      customer_name = btrim(p_banquet ->> 'customer_name'),
      customer_phone = nullif(p_banquet ->> 'customer_phone', ''),
      event_date = (p_banquet ->> 'event_date')::date,
      start_time = (p_banquet ->> 'start_time')::time,
      end_time = (p_banquet ->> 'end_time')::time,
      hall = btrim(p_banquet ->> 'hall'),
      tables_count = coalesce((p_banquet ->> 'tables_count')::integer, tables_count),
      guests_count = case when p_banquet ? 'guests_count'
        then (p_banquet ->> 'guests_count')::integer else guests_count end,
      deposit_amount = coalesce((p_banquet ->> 'deposit_amount')::numeric, deposit_amount),
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

-- Xac nhan tiec: kiem tra trung sanh + khung gio (M06 §4).
create or replace function public.banquet_confirm(
  p_property_id uuid, p_banquet_id uuid
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_row public.banquets%rowtype;
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

  return jsonb_build_object('ok', true, 'id', p_banquet_id);
end;
$$;

revoke all on function public.banquet_confirm(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.banquet_confirm(uuid, uuid) to authenticated;

create or replace function public.banquet_start(
  p_property_id uuid, p_banquet_id uuid
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_status text;
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  select status into v_status from public.banquets
  where id = p_banquet_id and property_id = p_property_id;
  if v_status is null then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_status <> 'confirmed' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.banquets set status = 'in_progress'
  where id = p_banquet_id;

  return jsonb_build_object('ok', true, 'id', p_banquet_id);
end;
$$;

revoke all on function public.banquet_start(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.banquet_start(uuid, uuid) to authenticated;

create or replace function public.banquet_complete(
  p_property_id uuid, p_banquet_id uuid
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_row public.banquets%rowtype;
  v_revenue numeric;
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  select * into v_row from public.banquets
  where id = p_banquet_id and property_id = p_property_id;
  if not found then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_row.status <> 'in_progress' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.banquets set status = 'completed'
  where id = p_banquet_id;

  -- Ghi doanh thu tung mon vao dish_sales (source 'banquet').
  insert into public.dish_sales
    (org_id, legal_entity_id, property_id, business_date,
     recipe_id, source, ref_id, qty, unit_price, amount)
  select
    v_row.org_id, v_row.legal_entity_id, p_property_id,
    v_row.event_date, d.recipe_id, 'banquet', p_banquet_id,
    d.qty, d.unit_price, round(d.qty * d.unit_price, 2)
  from public.banquet_dishes d
  where d.banquet_id = p_banquet_id;

  select coalesce(sum(amount), 0) into v_revenue
  from public.dish_sales
  where ref_id = p_banquet_id and source = 'banquet';

  return jsonb_build_object(
    'ok', true, 'id', p_banquet_id, 'revenue', v_revenue
  );
end;
$$;

revoke all on function public.banquet_complete(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.banquet_complete(uuid, uuid) to authenticated;

create or replace function public.banquet_cancel(
  p_property_id uuid, p_banquet_id uuid, p_reason text
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_status text;
begin
  perform public.require_perm(p_property_id, 'restaurant.banquet.manage');

  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select status into v_status from public.banquets
  where id = p_banquet_id and property_id = p_property_id;
  if v_status is null then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_status not in ('new', 'confirmed') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  update public.banquets set
    status = 'cancelled', cancel_reason = btrim(p_reason)
  where id = p_banquet_id;

  return jsonb_build_object('ok', true, 'id', p_banquet_id);
end;
$$;

revoke all on function public.banquet_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.banquet_cancel(uuid, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPT_FNB_REVENUE — doanh thu, gia von, lai gop tung mon (T-044).
--     Nguon: dish_sales chua void trong ky. Foodcost = gia tran hien hanh
--     tai thoi diem chay bao cao (khong phai gia luc ban — xem notes).
--     Khong grant execute (chi report_get goi, mau _report_minibar).
-- ---------------------------------------------------------------------------
create or replace function public._report_fnb_revenue(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce((p_params ->> 'from')::date, date_trunc('month', public._report_today())::date) as d_from,
      coalesce((p_params ->> 'to')::date, public._report_today()) as d_to
  ),
  sales as (
    select ds.recipe_id, ds.qty, ds.amount
    from public.dish_sales ds, p
    where ds.property_id = p_property_id
      and ds.business_date between p.d_from and p.d_to
      and ds.voided_at is null
  ),
  per_dish as (
    select
      s.recipe_id, r.code as dish_code, r.name as dish_name,
      sum(s.qty) as qty, sum(s.amount) as revenue,
      case when s.recipe_id is null then null
        when f.has_unknown_cost then null
        else round(sum(s.qty) * coalesce(f.foodcost, 0), 2) end as foodcost
    from sales s
    left join public.recipes r on r.id = s.recipe_id
    left join public._restaurant_foodcost_list(p_property_id) f
      on f.recipe_id = s.recipe_id
    group by s.recipe_id, r.code, r.name, f.has_unknown_cost, f.foodcost
  ),
  rows as (
    select jsonb_build_object(
      'dish_code', dish_code,
      'dish_name', coalesce(dish_name, 'Buffet (theo khách)'),
      'qty', qty, 'revenue', revenue, 'foodcost', foodcost,
      'gross_profit', case when foodcost is null then null
        else revenue - foodcost end,
      'margin_pct', case when foodcost is null or revenue = 0 then null
        else round((revenue - foodcost) / revenue * 100, 1) end
    ) as row,
    recipe_id, revenue, foodcost
    from per_dish
    order by revenue desc
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_FNB_REVENUE',
    'params', jsonb_build_object('from', p.d_from, 'to', p.d_to),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'revenue', coalesce((select sum(r.revenue) from rows r), 0),
      'foodcost', coalesce((select sum(r.foodcost) from rows r), 0),
      'gross_profit', coalesce((select sum(r.revenue - r.foodcost) from rows r
        where r.foodcost is not null), 0),
      'has_unknown_cost', exists (select 1 from rows r
        where r.foodcost is null and r.recipe_id is not null)
    ),
    'notes', jsonb_build_array(
      'Foodcost lay tu gia tran hien hanh tai thoi diem chay bao cao (khong phai gia luc ban); mon nao thieu gia tran thi foodcost NULL va khong tinh vao lai gop.',
      'Dong Buffet (theo khach) la doanh thu gop theo so khach cua phien buffet da dong, khong co foodcost theo mon.')
  ) from p;
$$;
revoke all on function public._report_fnb_revenue(uuid, jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 12. Them nhanh RPT_FNB_REVENUE vao report_get (T-044) — dinh nghia goc
--     sao chep nguyen van tu 20261109370000_reports.sql, chi them 1 nhanh
--     CASE. Quyen report.view.rpt_fnb_revenue da seed o §1 (report_get tu
--     choi neu ma quyen chua co trong bang permissions).
-- ---------------------------------------------------------------------------
create or replace function public.report_get(
  p_property_id uuid, p_code text, p_params jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_perm text;
  v_params jsonb := coalesce(p_params, '{}'::jsonb);
  v_from date;
  v_to date;
begin
  if not exists (select 1 from public.properties where id = p_property_id) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_perm := 'report.view.' || lower(p_code);
  if not exists (select 1 from public.permissions where code = v_perm) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(p_property_id, v_perm);

  v_from := (v_params ->> 'from')::date;
  v_to := (v_params ->> 'to')::date;
  if v_from is not null and v_to is not null and v_from > v_to then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  case upper(p_code)
    when 'RPT_STOCK_CARD' then return public._report_stock_card(p_property_id, v_params);
    when 'RPT_RECEIVING_QUALITY' then return public._report_receiving_quality(p_property_id, v_params);
    when 'RPT_OPEN_PO_INVOICE' then return public._report_open_po_invoice(p_property_id, v_params);
    when 'RPT_AP_AGING' then return public._report_ap_aging(p_property_id, v_params);
    when 'RPT_ADVANCES' then return public._report_advances(p_property_id, v_params);
    when 'RPT_WASTE' then return public._report_waste(p_property_id, v_params);
    when 'RPT_OPEX' then return public._report_opex(p_property_id, v_params);
    when 'RPT_MINIBAR' then return public._report_minibar(p_property_id, v_params);
    when 'RPT_AMENITY_CPOR' then return public._report_amenity_cpor(p_property_id, v_params);
    when 'RPT_FNB_REVENUE' then return public._report_fnb_revenue(p_property_id, v_params);
    when 'RPT_DAILY_BRIEF' then
      return public._build_daily_brief(
        p_property_id,
        coalesce((v_params ->> 'date')::date, public._report_today()));
    else raise exception 'ERR_INVALID_VALUE';
  end case;
end $$;
revoke all on function public.report_get(uuid, text, jsonb) from public, anon;
grant execute on function public.report_get(uuid, text, jsonb) to authenticated;
