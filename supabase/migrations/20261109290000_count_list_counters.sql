-- T-033: RPC chi doc danh sach nguoi duoc dem tai kho (phuc vu picker khi mo dot).
-- Can thiet vi profiles RLS chi cho doc chinh minh / admin.users.manage, nen
-- storekeeper (count.open) khong co cach nao khac de liet ke nguoi co count.perform.
-- Khong thay doi schema, khong cap them quyen count.* moi; dung lai helper
-- _count_user_has_perm cua T-032 (bao gom override deny > allow, pham vi kho/outlet).
create or replace function public.count_list_counters(
  p_property_id uuid,
  p_warehouse_id uuid
)
returns table (id uuid, employee_code text, full_name text)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  if p_property_id is null or p_warehouse_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if not exists (
    select 1
    from public.warehouses w
    where w.id = p_warehouse_id
      and w.property_id = p_property_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;

  perform public.require_perm(p_property_id, 'count.open', p_warehouse_id);

  return query
  select p.id, p.employee_code, p.full_name
  from public.profiles p
  where p.active
    and public._count_user_has_perm(p.id, p_property_id, 'count.perform', p_warehouse_id)
  order by p.full_name;
end;
$$;

revoke all on function public.count_list_counters(uuid, uuid) from public;
revoke all on function public.count_list_counters(uuid, uuid) from anon;
grant execute on function public.count_list_counters(uuid, uuid) to authenticated;
