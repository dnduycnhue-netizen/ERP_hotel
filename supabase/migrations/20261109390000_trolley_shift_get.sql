-- ===========================================================================
-- Trolley mobile (bo sung T-034) — RPC doc 1 ca xe day cho man hinh
-- /m/[p]/trolley/[shiftId].
--
-- LY DO CAN RPC MOI (khong doc truc tiep qua RLS):
-- - Nguoi buong phong (hk_attendant) KHONG doc duoc `stock_counts` /
--   `stock_count_lines` (policy doi 1 trong 5 quyen count.* — xem
--   280000) nen khong the doc lai so dem dau/cuoi ca da ghi.
-- - Cung KHONG doc duoc `purpose_issues` (policy doi
--   purpose_issue.post / purpose_issue.reverse / stock.view_qty —
--   xem 260000) nen khong thay duoc so phieu tieu hao sau khi dong ca.
-- - RPC SECURITY DEFINER nay kiem `hk.trolley.operate` hoac
--   `hk.standard.manage` ben trong roi moi tra: ca + kho xe day +
--   so dem dau/cuoi + phieu linh bu + phieu tieu hao + bang tieu hao
--   tinh theo cong thuc dong ca (dau + linh - cuoi, am clamp 0).
--   Tien le: RPC `count_list_counters` cua T-033 (290000).
-- - Khong co permission code moi; khong sua bang cu.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. RPC doc 1 ca xe day (ke ca tieu hao tinh san khi ca da dong).
--    Ca chua dong: `closing_counts` = null, `consumption` = [] (chua co
--    so dem cuoi nen chua tinh duoc tieu hao — khong tra so tam bang
--    closing = 0).
-- ---------------------------------------------------------------------------
create or replace function public.trolley_shift_get(p_shift_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_s record;
  v_wh record;
  v_req record;
  v_pi record;
  v_open jsonb;
  v_close jsonb := null;
  v_cons jsonb := '[]'::jsonb;
begin
  select * into v_s from public.trolley_shifts s where s.id = p_shift_id;
  if v_s is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: ca xe day khong ton tai';
  end if;

  if not (
    public.has_perm(v_s.property_id, 'hk.trolley.operate')
    or public.has_perm(v_s.property_id, 'hk.standard.manage')
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:hk.trolley.operate';
  end if;

  select * into v_wh
  from public.warehouses w
  where w.id = v_s.trolley_warehouse_id;

  -- So dem dau ca (stock_count_lines cua opening_count_id).
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'item_id', l.item_id,
      'item_code', i.code,
      'item_name', i.name,
      'stock_uom', i.stock_uom,
      'qty', l.final_qty
    ) order by i.code
  ), '[]'::jsonb) into v_open
  from public.stock_count_lines l
  join public.items i on i.id = l.item_id
  where l.count_id = v_s.opening_count_id;

  -- So dem cuoi ca (chi khi da dong).
  if v_s.closing_count_id is not null then
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'item_id', l.item_id,
        'item_code', i.code,
        'item_name', i.name,
        'stock_uom', i.stock_uom,
        'qty', l.final_qty
      ) order by i.code
    ), '[]'::jsonb) into v_close
    from public.stock_count_lines l
    join public.items i on i.id = l.item_id
    where l.count_id = v_s.closing_count_id;
  end if;

  -- Phieu linh bu top-up (neu co).
  if v_s.requisition_id is not null then
    select doc_no, status into v_req
    from public.requisitions r
    where r.id = v_s.requisition_id;
  end if;

  -- Phieu tieu hao (neu da dong ca va co tieu hao).
  if v_s.purpose_issue_id is not null then
    select doc_no, status into v_pi
    from public.purpose_issues pi
    where pi.id = v_s.purpose_issue_id;
  end if;

  -- Bang tieu hao: dau + linh (issue_in tu phieu linh bu cua ca)
  -- - cuoi; am clamp 0 + surplus (giong cong thuc trong
  -- trolley_shift_close, 310000). Chi tinh khi ca da dong.
  if v_s.closing_count_id is not null then
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'item_id', u.item_id,
        'item_code', i.code,
        'item_name', i.name,
        'stock_uom', i.stock_uom,
        'opening_qty', coalesce(o.qty, 0),
        'received_qty', coalesce(r.qty, 0),
        'closing_qty', coalesce(c.qty, 0),
        'consumed_qty',
          greatest(
            coalesce(o.qty, 0) + coalesce(r.qty, 0) - coalesce(c.qty, 0),
            0
          ),
        'surplus_qty',
          greatest(
            coalesce(c.qty, 0) - coalesce(o.qty, 0) - coalesce(r.qty, 0),
            0
          )
      ) order by i.code
    ), '[]'::jsonb) into v_cons
    from (
      select item_id from public.stock_count_lines
      where count_id = v_s.opening_count_id
      union
      select item_id from public.stock_count_lines
      where count_id = v_s.closing_count_id
      union
      select item_id from public.stock_moves
      where warehouse_id = v_s.trolley_warehouse_id
        and move_type = 'issue_in'
        and source_doc_type = 'requisition'
        and source_doc_id = v_s.requisition_id
    ) u
    join public.items i on i.id = u.item_id
    left join (
      select item_id, final_qty as qty from public.stock_count_lines
      where count_id = v_s.opening_count_id
    ) o on o.item_id = u.item_id
    left join (
      select item_id, final_qty as qty from public.stock_count_lines
      where count_id = v_s.closing_count_id
    ) c on c.item_id = u.item_id
    left join (
      select item_id, sum(qty) as qty from public.stock_moves
      where warehouse_id = v_s.trolley_warehouse_id
        and move_type = 'issue_in'
        and source_doc_type = 'requisition'
        and source_doc_id = v_s.requisition_id
      group by item_id
    ) r on r.item_id = u.item_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'shift', jsonb_build_object(
      'id', v_s.id,
      'org_id', v_s.org_id,
      'property_id', v_s.property_id,
      'trolley_warehouse_id', v_s.trolley_warehouse_id,
      'trolley_code', v_wh.code,
      'trolley_name', v_wh.name,
      'attendant_id', v_s.attendant_id,
      'business_date', v_s.business_date,
      'shift', v_s.shift,
      'status', v_s.status,
      'opening_count_id', v_s.opening_count_id,
      'closing_count_id', v_s.closing_count_id,
      'rooms_done', v_s.rooms_done,
      'requisition_id', v_s.requisition_id,
      'requisition_doc_no', v_req.doc_no,
      'requisition_status', v_req.status,
      'purpose_issue_id', v_s.purpose_issue_id,
      'purpose_issue_doc_no', v_pi.doc_no,
      'closed_by', v_s.closed_by,
      'closed_at', v_s.closed_at,
      'created_at', v_s.created_at
    ),
    'opening_counts', v_open,
    'closing_counts', v_close,
    'consumption', v_cons
  );
end;
$$;

revoke all on function public.trolley_shift_get(uuid)
  from public, anon, authenticated;
grant execute on function public.trolley_shift_get(uuid)
  to authenticated;

-- Audit trail for the migration itself (pattern 210000/260000).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109390000_trolley_shift_get',
  'INSERT',
  jsonb_build_object('event', 'trolley_shift_get_created', 'task', 'trolley-mobile'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
