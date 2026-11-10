-- C6 (completion wave 2 — route thieu page): danh sach lenh mua cho.
--  1. `po_list` them tham so loc theo kenh `p_channel` (mac dinh null =
--     khong loc). Khong co RPC nao loc PO theo channel truoc day; loc o
--     client se lam sai tong phan trang nen phai loc o SQL.
--  2. Khoi phuc `LEFT JOIN suppliers`: migration 410000 (Q18) viet lai
--     `po_list` bang `JOIN` trong nen PO cho (`supplier_id` NULL, theo
--     quyet dinh 1 cua 220000) bien mat khoi danh sach — trang
--     `/procurement/market` se rong neu khong sua. Giu nguyen join
--     `profiles` lay `created_by_name` cua 410000 va cua quyen cu.
-- Khong them bang, khong them quyen, khong doi du lieu.
-- ============================================================================

-- `create or replace` khong doi duoc chu ky: phai drop ban cu (5 doi so)
-- truoc roi tao lai ban 6 doi so (tien le: 430000 drop service_accept).
drop function if exists public.po_list(uuid, text, text, integer, integer);

create function public.po_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0,
  p_channel text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'po.view')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.approve')
    or public.has_perm(p_property_id, 'po.close')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      po.id, po.doc_no, po.kind, po.channel, po.supplier_id,
      s.name as supplier_name, po.order_date, po.expected_date,
      po.total_amount, po.status, po.over_ceiling_reason,
      po.created_by, pf.full_name as created_by_name,
      po.created_at, po.updated_at,
      count(pol.id) as line_count,
      coalesce(sum(pol.received_qty_stock), 0) as received_qty_stock
    from public.purchase_orders po
    left join public.suppliers s on s.id = po.supplier_id
    left join public.profiles pf on pf.id = po.created_by
    left join public.purchase_order_lines pol on pol.po_id = po.id
    where po.property_id = p_property_id
      and (p_status is null or po.status = p_status)
      and (p_channel is null or po.channel = p_channel)
      and (
        p_search is null or btrim(p_search) = ''
        or po.doc_no ilike '%' || p_search || '%'
        or s.name ilike '%' || p_search || '%'
      )
    group by po.id, s.name, pf.full_name
  )
  select jsonb_build_object(
    'ok', true,
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f))
      from (select * from filtered order by created_at desc limit v_limit offset v_offset) f
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.po_list(uuid, text, text, integer, integer, text)
  from public, anon, authenticated;
grant execute on function public.po_list(uuid, text, text, integer, integer, text) to authenticated;

-- Audit trail for the migration itself (pattern 210000/410000: actor la
-- uuid, khong bao gio ghi text 'migration').
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109525000_missing_routes',
  'INSERT',
  jsonb_build_object('event', 'missing_routes_po_list_channel_created', 'task', 'C6'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
