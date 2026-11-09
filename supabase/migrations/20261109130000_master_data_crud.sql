-- T-012: Phân quyền CRUD qua RLS cho danh mục vật tư, nhóm hàng, ĐVT, quy cách mua, kho, phòng, outlet, khoản mục.

-- 0. Cấp quyền thực thi hàm tiện ích norm_text cho người dùng đăng nhập để sinh cột name_norm
grant execute on function public.norm_text(text) to authenticated;

-- 1. Trigger chặn xóa vật tư đã có phát sinh giao dịch kho (stock_moves)
create or replace function public.validate_item_delete()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if exists (select 1 from public.stock_moves where item_id = old.id) then
    raise exception using errcode = 'P0001', message = 'ERR_ITEM_HAS_STOCK_MOVES';
  end if;
  return old;
end;
$$;
revoke all on function public.validate_item_delete() from public, anon, authenticated;

create trigger trg_items_validate_delete
  before delete on public.items
  for each row execute function public.validate_item_delete();

-- 2. Trigger chặn đổi stock_uom của vật tư đã có giao dịch kho
create or replace function public.validate_item_update()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if old.stock_uom <> new.stock_uom and exists (select 1 from public.stock_moves where item_id = old.id) then
    raise exception using errcode = 'P0001', message = 'ERR_ITEM_UOM_CHANGE_FORBIDDEN';
  end if;
  return new;
end;
$$;
revoke all on function public.validate_item_update() from public, anon, authenticated;

create trigger trg_items_validate_update
  before update on public.items
  for each row execute function public.validate_item_update();

-- 3. Cấp quyền và RLS Write Policies cho các bảng danh mục
grant insert, update, delete on public.items to authenticated;
grant insert, update, delete on public.item_groups to authenticated;
grant insert, update on public.uoms to authenticated;
grant insert, update, delete on public.item_purchase_units to authenticated;
grant insert, update, delete on public.expense_categories to authenticated;
grant insert, update, delete on public.warehouses to authenticated;
grant insert, update, delete on public.rooms to authenticated;
grant insert, update, delete on public.room_types to authenticated;
grant insert, update, delete on public.outlets to authenticated;
grant insert, update, delete on public.outlet_types to authenticated;
grant insert, update, delete on public.cost_centers to authenticated;

-- Policies items
create policy items_insert on public.items for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = items.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy items_update on public.items for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = items.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
)
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = items.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy items_delete on public.items for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = items.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

-- Policies item_groups
create policy item_groups_insert on public.item_groups for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = item_groups.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy item_groups_update on public.item_groups for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = item_groups.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy item_groups_delete on public.item_groups for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = item_groups.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

-- Policies uoms
create policy uoms_insert on public.uoms for insert to authenticated
with check (
  (select public.has_perm(null, 'item.manage'))
  or exists (
    select 1 from public.properties p
    where p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  )
);

create policy uoms_update on public.uoms for update to authenticated
using (
  (select public.has_perm(null, 'item.manage'))
  or exists (
    select 1 from public.properties p
    where p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  )
);

-- Policies item_purchase_units
create policy item_purchase_units_insert on public.item_purchase_units for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = item_purchase_units.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy item_purchase_units_update on public.item_purchase_units for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = item_purchase_units.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy item_purchase_units_delete on public.item_purchase_units for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = item_purchase_units.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

-- Policies expense_categories
create policy expense_categories_insert on public.expense_categories for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = expense_categories.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy expense_categories_update on public.expense_categories for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = expense_categories.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy expense_categories_delete on public.expense_categories for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = expense_categories.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.manage')
  ) or (select public.has_perm(null, 'item.manage'))
);

-- Policies warehouses
create policy warehouses_insert on public.warehouses for insert to authenticated
with check (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'warehouse.manage')
);

create policy warehouses_update on public.warehouses for update to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'warehouse.manage')
);

create policy warehouses_delete on public.warehouses for delete to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'warehouse.manage')
);

-- Policies rooms
create policy rooms_insert on public.rooms for insert to authenticated
with check (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'room.manage')
);

create policy rooms_update on public.rooms for update to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'room.manage')
);

create policy rooms_delete on public.rooms for delete to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'room.manage')
);

-- Policies room_types
create policy room_types_insert on public.room_types for insert to authenticated
with check (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'room.manage')
);

create policy room_types_update on public.room_types for update to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'room.manage')
);

create policy room_types_delete on public.room_types for delete to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'room.manage')
);

-- Policies outlets
create policy outlets_insert on public.outlets for insert to authenticated
with check (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'warehouse.manage')
);

create policy outlets_update on public.outlets for update to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'warehouse.manage')
);

create policy outlets_delete on public.outlets for delete to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'warehouse.manage')
);

-- Policies outlet_types
create policy outlet_types_insert on public.outlet_types for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = outlet_types.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'warehouse.manage')
  ) or (select public.has_perm(null, 'warehouse.manage'))
);

create policy outlet_types_update on public.outlet_types for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = outlet_types.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'warehouse.manage')
  ) or (select public.has_perm(null, 'warehouse.manage'))
);

create policy outlet_types_delete on public.outlet_types for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = outlet_types.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'warehouse.manage')
  ) or (select public.has_perm(null, 'warehouse.manage'))
);

-- Policies cost_centers
create policy cost_centers_insert on public.cost_centers for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = cost_centers.org_id
      and p.id in (select public.my_property_ids())
      and (public.has_perm(p.id, 'item.manage') or public.has_perm(p.id, 'warehouse.manage'))
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy cost_centers_update on public.cost_centers for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = cost_centers.org_id
      and p.id in (select public.my_property_ids())
      and (public.has_perm(p.id, 'item.manage') or public.has_perm(p.id, 'warehouse.manage'))
  ) or (select public.has_perm(null, 'item.manage'))
);

create policy cost_centers_delete on public.cost_centers for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = cost_centers.org_id
      and p.id in (select public.my_property_ids())
      and (public.has_perm(p.id, 'item.manage') or public.has_perm(p.id, 'warehouse.manage'))
  ) or (select public.has_perm(null, 'item.manage'))
);
