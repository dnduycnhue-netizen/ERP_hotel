-- Q228: trolley_shift_open called min(w.id) to pick the source floor
-- warehouse, but Postgres has no min(uuid) aggregate — every call failed at
-- runtime with 42883 (function min(uuid) does not exist) at
-- trolley_shift_open line 69, before any top-up work. plpgsql bodies are only
-- parsed at CREATE time, so db push never caught it; the function was never
-- executed successfully on production, so opening a trolley shift NEVER
-- worked (found by pgTAP trolley_shift_get run 4, 2026-11-12 09:06, at §C
-- shift open; seed fixes 048e4b6/1bfea5d/44f1e7b had cleared the way).
-- Fix: count the floor warehouses first, then select the id only when the
-- count is exactly 1. Semantics unchanged: v_floor_wh is only read inside
-- the v_floor_n = 1 branch (top-up requisition source); when the count is
-- 0 or > 1 it stays NULL as before (min() over 0 rows is NULL; the > 1
-- value was never used). No other change to the function.
create or replace function public.trolley_shift_open(
  p_property_id uuid,
  p_trolley_wh uuid,
  p_counts jsonb,
  p_shift text default null,
  p_business_date date default (now() at time zone 'Asia/Ho_Chi_Minh')::date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_entity_id uuid;
  v_wh record;
  v_shift text := coalesce(nullif(btrim(coalesce(p_shift, '')), ''), 'day');
  v_biz date := coalesce(
    p_business_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_count_id uuid;
  v_doc_no text;
  v_floor_wh uuid;
  v_floor_n integer;
  v_req_id uuid;
  v_topup_n integer := 0;
  v_topup_note text;
  v_steps integer;
  v_shift_id uuid;
begin
  perform public.require_perm(p_property_id, 'hk.trolley.operate');

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = p_property_id;
  if v_org_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: property khong ton tai';
  end if;

  select * into v_wh from public.warehouses w
  where w.id = p_trolley_wh and w.property_id = p_property_id;
  if v_wh is null or v_wh.kind <> 'trolley' then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: kho xe day khong ton tai hoac sai kind';
  end if;

  if exists (
    select 1 from public.trolley_shifts s
    where s.trolley_warehouse_id = p_trolley_wh
      and s.business_date = v_biz and s.shift = v_shift
      and s.status = 'open'
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_STATUS: da co ca dang mo cho xe day nay';
  end if;

  -- Dem dau ca (mu): tao stock_counts kind='trolley' o status 'submitted'
  -- ngay khi tao, book_qty NULL — khong lo ton so (quyet dinh 9).
  perform set_config('app.count_guard_bypass', 'on', true);
  v_doc_no := public.next_doc_no(v_entity_id, 'CNT', v_biz);
  insert into public.stock_counts (
    org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind,
    business_date, shift, status, counter_ids, opened_by, created_by
  ) values (
    v_org_id, v_entity_id, p_property_id, p_trolley_wh, v_doc_no,
    'trolley', v_biz, v_shift, 'submitted', array[auth.uid()],
    auth.uid(), auth.uid()
  )
  returning id into v_count_id;

  insert into public.stock_count_lines (
    count_id, org_id, item_id, count_detail,
    counted_qty_1, counted_by_1, final_qty, flag
  )
  select v_count_id, v_org_id, c.item_id, '{}'::jsonb,
    c.qty, auth.uid(), c.qty, 'ok'
  from public._hk_parse_counts(p_counts, v_org_id) c;

  -- Tim kho tang nguon: kind='floor' duy nhat cung outlet + property (Q41).
  -- (Q228: min(uuid) khong ton tai trong Postgres — dem truoc, lay id sau.)
  select count(*) into v_floor_n
  from public.warehouses w
  where w.property_id = p_property_id
    and w.kind = 'floor'
    and w.outlet_id = v_wh.outlet_id;

  if v_floor_n = 1 then
    select w.id into v_floor_wh
    from public.warehouses w
    where w.property_id = p_property_id
      and w.kind = 'floor'
      and w.outlet_id = v_wh.outlet_id;
  end if;

  if v_floor_n = 1 then
    -- So can linh = par - ton dau ca (chi dong > 0), theo stock_count_lines
    -- vua ghi (item khong dem = 0).
    select count(*) into v_topup_n
    from public.trolley_par_levels tpl
    where tpl.trolley_warehouse_id = p_trolley_wh
      and tpl.par_qty > coalesce((
        select l.final_qty from public.stock_count_lines l
        where l.count_id = v_count_id and l.item_id = tpl.item_id
      ), 0);

    if v_topup_n > 0 then
      perform set_config('app.inventory_guard_bypass', 'on', true);
      -- _generate_approval_steps ghi bang approvals (co write-guard rieng
      -- o 210000): phai bat ca pr_po bypass nhu requisition_submit (260000).
      perform set_config('app.pr_po_guard_bypass', 'on', true);
      v_doc_no := public.next_doc_no(v_entity_id, 'REQ', v_biz);
      insert into public.requisitions (
        org_id, legal_entity_id, property_id, outlet_id,
        from_warehouse_id, to_warehouse_id, doc_no, business_date,
        status, note, created_by
      ) values (
        v_org_id, v_entity_id, p_property_id, v_wh.outlet_id,
        v_floor_wh, p_trolley_wh, v_doc_no, v_biz, 'submitted',
        'Top-up xe day ' || v_wh.code || ' ca ' || v_shift
          || ' ' || v_biz::text,
        auth.uid()
      )
      returning id into v_req_id;

      insert into public.requisition_lines (
        requisition_id, org_id, property_id, item_id, uom,
        qty, qty_stock, created_by
      )
      select v_req_id, v_org_id, p_property_id, tpl.item_id, i.stock_uom,
        tpl.par_qty - coalesce(l.final_qty, 0),
        tpl.par_qty - coalesce(l.final_qty, 0), auth.uid()
      from public.trolley_par_levels tpl
      join public.items i on i.id = tpl.item_id
      left join public.stock_count_lines l
        on l.count_id = v_count_id and l.item_id = tpl.item_id
      where tpl.trolley_warehouse_id = p_trolley_wh
        and tpl.par_qty > coalesce(l.final_qty, 0);

      v_steps := public._generate_approval_steps(
        'requisition', v_req_id, p_property_id, v_org_id, 0
      );
      if v_steps = 0 then
        raise exception using errcode = 'P0001',
          message = 'ERR_INVALID_VALUE: thieu ma tran duyet requisition (outlet_head)';
      end if;
    end if;
  elsif v_floor_n = 0 then
    v_topup_note := 'khong co kho tang cho outlet ' || v_wh.code;
  else
    v_topup_note := 'nhieu kho tang cho outlet ' || v_wh.code
      || ', can gan kho tang cho xe day';
  end if;

  perform set_config('app.hk_guard_bypass', 'on', true);
  insert into public.trolley_shifts (
    org_id, legal_entity_id, property_id, trolley_warehouse_id,
    attendant_id, business_date, shift, opening_count_id,
    requisition_id, status, created_by
  ) values (
    v_org_id, v_entity_id, p_property_id, p_trolley_wh,
    auth.uid(), v_biz, v_shift, v_count_id,
    v_req_id, 'open', auth.uid()
  )
  returning id into v_shift_id;

  return jsonb_build_object(
    'ok', true, 'shift_id', v_shift_id,
    'opening_count_id', v_count_id,
    'requisition_id', v_req_id,
    'top_up_lines', v_topup_n,
    'top_up_note', v_topup_note
  );
end;
$$;
