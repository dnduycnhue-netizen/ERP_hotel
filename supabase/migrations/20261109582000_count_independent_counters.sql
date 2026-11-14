-- Q275 (14/11/2026): bao cao verify V3-N2 — giao dien khong cho biet ai du dieu kien "nguoi dem doc lap"
-- (04 §6 SOD_COUNT_INDEPENDENT: dot thang can >= 1 nguoi dem KHONG co receiving.post va
-- requisition.issue tai kho do). RPC chi doc: danh sach id nguoi dem doc lap tai kho.
create or replace function public.count_independent_counter_ids(
  p_property_id uuid,
  p_warehouse_id uuid
)
returns uuid[]
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
    select 1 from public.warehouses w
    where w.id = p_warehouse_id and w.property_id = p_property_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;

  perform public.require_perm(p_property_id, 'count.open', p_warehouse_id);

  return coalesce((
    select array_agg(p.id order by p.full_name)
    from public.profiles p
    where p.active
      and public._count_user_has_perm(p.id, p_property_id, 'count.perform', p_warehouse_id)
      and not public._count_user_has_perm(p.id, p_property_id, 'receiving.post', p_warehouse_id)
      and not public._count_user_has_perm(p.id, p_property_id, 'requisition.issue', p_warehouse_id)
  ), '{}'::uuid[]);
end;
$$;

revoke all on function public.count_independent_counter_ids(uuid, uuid) from public, anon;
grant execute on function public.count_independent_counter_ids(uuid, uuid) to authenticated;
