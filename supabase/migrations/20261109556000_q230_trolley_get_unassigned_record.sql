-- Q230: trolley_shift_get crashed with 55000 on every OPEN shift read.
-- `v_pi record` is only SELECTed when purpose_issue_id is not null, but the
-- RETURN read `v_pi.doc_no` unconditionally; on an open shift (no
-- purpose_issue yet) the record was never assigned and plpgsql raised
-- "record "v_pi" is not assigned yet" at RETURN (line 130). Found by
-- pgTAP trolley_shift_get, 2026-11-12 11:30-11:34, at section E (read open
-- shift); the bug was hidden behind Q228 (shift open itself failed before
-- any read could happen). Same latent pattern for `v_req`: only selected
-- when requisition_id is not null, but RETURN read `v_req.doc_no` /
-- `v_req.status` unconditionally — a shift with no top-up requisition
-- would crash the same way.
-- Fix v1 (553000): CASE-guard the three response fields on their ids
-- (null when the linked doc does not exist). PROVED INSUFFICIENT by the
-- live re-run 2026-11-12 13:27: the error CONTEXT showed the CASE guard
-- present in the live function, yet it still raised 55000. Reason: a
-- plpgsql record variable has no tupdesc until it is assigned, and
-- resolving `v_pi.doc_no` in ANY branch of an expression — including a
-- CASE branch that is not taken — raises "record is not assigned yet".
-- CASE does NOT short-circuit unassigned-record access.
-- Fix v2 (556000, this file): guarantee v_req and v_pi are ALWAYS
-- assigned before RETURN. Each conditional SELECT gains an else branch
-- with a dummy SELECT INTO that gives the record its tupdesc with NULLs
-- (doc_no, status). The CASE guards are kept (harmless). No change to
-- permissions, RLS, queries, or any other behavior. When the ids are
-- present the values come from the selected records exactly as before.
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
  else
    -- v_req phai LUON duoc gan: record chua gan khong co tupdesc nen
    -- bat ky tham chieu v_req.<cot> nao (ke ca nhanh CASE khong chay)
    -- cung no 55000. SELECT dummy cho tupdesc (doc_no, status) voi NULL.
    select null::text as doc_no, null::text as status into v_req;
  end if;

  -- Phieu tieu hao (neu da dong ca va co tieu hao).
  if v_s.purpose_issue_id is not null then
    select doc_no, status into v_pi
    from public.purpose_issues pi
    where pi.id = v_s.purpose_issue_id;
  else
    -- v_pi phai LUON duoc gan: ly do nhu v_req (xem tren).
    select null::text as doc_no, null::text as status into v_pi;
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
      'requisition_doc_no', case when v_s.requisition_id is null then null else v_req.doc_no end,
      'requisition_status', case when v_s.requisition_id is null then null else v_req.status end,
      'purpose_issue_id', v_s.purpose_issue_id,
      'purpose_issue_doc_no', case when v_s.purpose_issue_id is null then null else v_pi.doc_no end,
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
  '20261109556000_q230_trolley_get_unassigned_record',
  'INSERT',
  jsonb_build_object('event', 'trolley_shift_get_q230_unassigned_record_v2', 'task', 'Q230'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
