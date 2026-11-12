-- Q231: purpose_issue_get/list gate locks out cost_controller (12/11/2026).
-- Both functions gated on purpose_issue.post OR purpose_issue.reverse ONLY,
-- so cost_controller (no workflow permission on purpose_issue — it has no
-- approve step) got 42501 ERR_FORBIDDEN on every read, although the UI
-- Inventory nav group is visible to stock.view_qty / stock.view_value
-- holders and /inventory/issues inherits that visibility, and the
-- functions' own masking (unit_cost/line_amount only with stock.view_value)
-- shows they were built to serve value-viewers. Sibling precedent:
-- waste_get (same file) admits waste.propose/approve/approve.large, so
-- cost_controller (waste.approve) can read waste details and values.
-- Fix: widen the gate in BOTH functions to also admit stock.view_value.
-- No masking change, no other behavior change; the caller still only sees
-- costs when it holds stock.view_value, and no new data is exposed
-- (cost_controller can already read the same costs from stock_moves).
-- Found by pgTAP T-030 run 1 (2026-11-12 11:39-11:56), aborted at test 70/97.
-- Functions copied verbatim from 260000; only the gate lines changed.
-- Danh sach phieu xuat muc dich.
create or replace function public.purpose_issue_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
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
    public.has_perm(p_property_id, 'purpose_issue.post')
    or public.has_perm(p_property_id, 'purpose_issue.reverse')
    or public.has_perm(p_property_id, 'stock.view_value')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      pi.id, pi.doc_no, pi.status, pi.business_date, pi.note,
      pi.purpose_code, pi.warehouse_id, w.name as warehouse_name,
      pi.cost_center_id, cc.name as cost_center_name,
      pi.expense_category_id, ec.name as expense_category_name,
      pi.created_by, pi.created_at, pi.updated_at,
      count(pil.id) as line_count,
      coalesce(sum(pil.qty_stock), 0) as total_qty_stock
    from public.purpose_issues pi
    left join public.warehouses w on w.id = pi.warehouse_id
    left join public.cost_centers cc on cc.id = pi.cost_center_id
    left join public.expense_categories ec on ec.id = pi.expense_category_id
    left join public.purpose_issue_lines pil on pil.purpose_issue_id = pi.id
    where pi.property_id = p_property_id
      and (p_status is null or pi.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or pi.doc_no ilike '%' || btrim(p_search) || '%'
        or pi.note ilike '%' || btrim(p_search) || '%'
      )
    group by
      pi.id, pi.doc_no, pi.status, pi.business_date, pi.note,
      pi.purpose_code, pi.warehouse_id, w.name,
      pi.cost_center_id, cc.name,
      pi.expense_category_id, ec.name,
      pi.created_by, pi.created_at, pi.updated_at
  )
  select jsonb_build_object(
    'rows', coalesce(jsonb_agg(f.* order by f.created_at desc), '[]'::jsonb),
    'total', (select count(*) from filtered)
  )
  into v_result
  from (select * from filtered order by created_at desc limit v_limit offset v_offset) f;

  return v_result;
end;
$$;

revoke all on function public.purpose_issue_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet phieu xuat muc dich + dong (gia von chi hien khi co stock.view_value).
create or replace function public.purpose_issue_get(
  p_issue_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pi public.purpose_issues%rowtype;
  v_show_value boolean;
  v_result jsonb;
begin
  select * into v_pi
  from public.purpose_issues pi where pi.id = p_issue_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_pi.property_id, 'purpose_issue.post')
    or public.has_perm(v_pi.property_id, 'purpose_issue.reverse')
    or public.has_perm(v_pi.property_id, 'stock.view_value')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  v_show_value := public.has_perm(v_pi.property_id, 'stock.view_value');

  select jsonb_build_object(
    'id', pi.id, 'doc_no', pi.doc_no, 'status', pi.status,
    'business_date', pi.business_date, 'note', pi.note,
    'property_id', pi.property_id,
    'warehouse_id', pi.warehouse_id, 'warehouse_name', w.name,
    'purpose_code', pi.purpose_code,
    'cost_center_id', pi.cost_center_id, 'cost_center_name', cc.name,
    'expense_category_id', pi.expense_category_id,
    'expense_category_name', ec.name,
    'work_order_id', pi.work_order_id,
    'created_by', pi.created_by, 'created_at', pi.created_at,
    'updated_at', pi.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', pil.id, 'item_id', pil.item_id, 'item_name', i.name,
          'uom', pil.uom, 'qty', pil.qty, 'qty_stock', pil.qty_stock,
          'lot_id', pil.lot_id, 'lot_no', l.lot_no, 'note', pil.note,
          'unit_cost', case when v_show_value then sm.unit_cost else null end,
          'line_amount', case when v_show_value then sm.amount else null end
        ) order by pil.created_at asc
      )
      from public.purpose_issue_lines pil
      join public.items i on i.id = pil.item_id
      left join public.lots l on l.id = pil.lot_id
      left join public.stock_moves sm
        on sm.source_doc_type = 'purpose_issue'
        and sm.source_doc_id = pi.id
        and sm.source_line_id = pil.id
        and sm.move_type = 'purpose_issue'
      where pil.purpose_issue_id = pi.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.purpose_issues pi
  left join public.warehouses w on w.id = pi.warehouse_id
  left join public.cost_centers cc on cc.id = pi.cost_center_id
  left join public.expense_categories ec on ec.id = pi.expense_category_id
  where pi.id = p_issue_id;

  return v_result;
end;
$$;

revoke all on function public.purpose_issue_get(uuid)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_get(uuid) to authenticated;

-- Audit trail for the migration itself (pattern 210000/260000).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109554000_q231_purpose_issue_get_view_value',
  'INSERT',
  jsonb_build_object('event', 'purpose_issue_get_gate_view_value', 'task', 'q231'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
