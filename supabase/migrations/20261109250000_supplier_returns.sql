-- Migration 10 (T-026): hoan thien tra hang NCC + nhan thang vao bep.
--
-- Da co tu T-023 (khong lam lai):
--   * `supplier_return_post` (return_out theo gia dong nhan goc, giam so da
--     nhan tren PO) + server action `postSupplierReturnAction` (chua co UI).
--   * QC fail tu sinh `supplier_returns` 'recorded' (1 phieu / 1 dong fail).
--   * Nhan thang vao bep: `receiving_start(p_direct_issue_wh)` + post ghi
--     3 move receipt + issue_out + issue_in (da co UI chon kho dich o T-024).
--
-- Phan thieu T-026 bu o day:
--   * Doc phieu tra: `supplier_return_list`, `supplier_return_get`
--     (truoc day khong cach nao xem phieu tra trong app).
--   * Vong doi phieu tra QC fail 'recorded' (hien la ngo cut — status
--     'cancelled' trong check constraint khong toi duoc):
--     `supplier_return_confirm` ('recorded' -> 'posted', xac nhan NCC da
--     lay hang ve, bat buoc chu ky hoac anh moi) va `supplier_return_cancel`
--     ('recorded' -> 'cancelled', ly do bat buoc).
--   * `supplier_return_eligible_lines`: dong cua phieu nhan da post con
--     tra duoc (da nhan - da tra) de UI tao phieu tra.
--   * Cot audit cho xac nhan/huy tren `supplier_returns`.
-- GHI CHU: `ap_ledger` (-) khi tra hang thuoc T-040 (invoices chua co);
-- phieu tra posted o day chi dao kho + so da nhan (giong T-023).
-- Khong ma quyen moi: dung lai `supplier_return.post` (da co trong danh
-- muc tu 08141000, seed gan cho storekeeper) + `receiving.view` /
-- `receiving.review_photos` / `po.view_price` (chi hien gia khi co quyen).

-- ---------------------------------------------------------------------------
-- 1. Cot audit tren supplier_returns (T-023 chua co).
-- ---------------------------------------------------------------------------
alter table public.supplier_returns
  add column if not exists confirmed_by uuid references auth.users(id),
  add column if not exists confirmed_at timestamptz,
  add column if not exists cancelled_by uuid references auth.users(id),
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancel_reason text;

-- ---------------------------------------------------------------------------
-- 2. RPC — doc phieu tra NCC.
-- ---------------------------------------------------------------------------

-- Danh sach phieu tra NCC (chi header; total_amount chi khi co po.view_price).
create or replace function public.supplier_return_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_can_price boolean;
  v_rows jsonb;
  v_total int;
begin
  if not (
    public.has_perm(p_property_id, 'receiving.view')
    or public.has_perm(p_property_id, 'receiving.review_photos')
    or public.has_perm(p_property_id, 'supplier_return.post')
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.view';
  end if;

  if p_status is not null
    and p_status not in ('recorded', 'posted', 'cancelled') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_can_price := public.has_perm(p_property_id, 'po.view_price');

  select count(*) into v_total
  from public.supplier_returns sr
  where sr.property_id = p_property_id
    and (p_status is null or sr.status = p_status)
    and (p_search is null
      or sr.doc_no ilike '%' || p_search || '%');

  select coalesce(jsonb_agg(r), '[]'::jsonb) into v_rows
  from (
    select
      sr.id,
      sr.doc_no,
      sr.status,
      coalesce(s.name, 'Mua chợ') as supplier_name,
      gr.doc_no as gr_doc_no,
      po.doc_no as po_doc_no,
      (select count(*)::int from public.supplier_return_lines srl
        where srl.return_id = sr.id) as line_count,
      (select coalesce(sum(srl.qty_stock), 0)
        from public.supplier_return_lines srl
        where srl.return_id = sr.id) as total_qty_stock,
      case when v_can_price then (
        select coalesce(sum(srl.qty_stock * srl.unit_cost), 0)
        from public.supplier_return_lines srl
        where srl.return_id = sr.id
      ) else null end as total_amount,
      sr.created_at,
      sr.created_by,
      sr.confirmed_at,
      sr.cancelled_at
    from public.supplier_returns sr
    left join public.suppliers s
      on s.id = sr.supplier_id and s.org_id = sr.org_id
    left join public.goods_receipts gr
      on gr.id = sr.gr_id
    left join public.purchase_orders po
      on po.id = sr.po_id
    where sr.property_id = p_property_id
      and (p_status is null or sr.status = p_status)
      and (p_search is null
        or sr.doc_no ilike '%' || p_search || '%')
    order by sr.created_at desc
    limit greatest(p_limit, 1)
    offset greatest(p_offset, 0)
  ) r;

  return jsonb_build_object('ok', true, 'returns', v_rows, 'total', v_total);
end;
$$;

-- Chi tiet 1 phieu tra NCC (header + dong; gia chi khi co po.view_price).
create or replace function public.supplier_return_get(
  p_return_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sr record;
  v_can_price boolean;
  v_lines jsonb;
  v_supplier text;
  v_gr_doc_no text;
  v_po_doc_no text;
begin
  select sr.* into v_sr
  from public.supplier_returns sr
  where sr.id = p_return_id;

  if v_sr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_sr.property_id, 'receiving.view')
    or public.has_perm(v_sr.property_id, 'receiving.review_photos')
    or public.has_perm(v_sr.property_id, 'supplier_return.post')
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.view';
  end if;

  v_can_price := public.has_perm(v_sr.property_id, 'po.view_price');

  select s.name into v_supplier
  from public.suppliers s
  where s.id = v_sr.supplier_id and s.org_id = v_sr.org_id;

  select gr.doc_no into v_gr_doc_no
  from public.goods_receipts gr
  where gr.id = v_sr.gr_id;

  select po.doc_no into v_po_doc_no
  from public.purchase_orders po
  where po.id = v_sr.po_id;

  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_lines
  from (
    select
      srl.id,
      srl.gr_line_id,
      srl.item_id,
      i.name as item_name,
      srl.qty_stock,
      case when v_can_price then srl.unit_cost else null end as unit_cost,
      case when v_can_price
        then round(srl.qty_stock * srl.unit_cost, 2)
        else null end as line_amount,
      srl.reason,
      srl.photo_ids,
      srl.supplier_signature_path
    from public.supplier_return_lines srl
    join public.items i
      on i.id = srl.item_id and i.org_id = srl.org_id
    where srl.return_id = p_return_id
    order by srl.created_at
  ) l;

  return jsonb_build_object(
    'ok', true,
    'id', v_sr.id,
    'doc_no', v_sr.doc_no,
    'status', v_sr.status,
    'reason', v_sr.reason,
    'supplier_name', coalesce(v_supplier, 'Mua chợ'),
    'gr_id', v_sr.gr_id,
    'gr_doc_no', v_gr_doc_no,
    'po_id', v_sr.po_id,
    'po_doc_no', v_po_doc_no,
    'supplier_signature_path', v_sr.supplier_signature_path,
    'photo_ids', v_sr.photo_ids,
    'created_by', v_sr.created_by,
    'created_at', v_sr.created_at,
    'confirmed_by', v_sr.confirmed_by,
    'confirmed_at', v_sr.confirmed_at,
    'cancelled_by', v_sr.cancelled_by,
    'cancelled_at', v_sr.cancelled_at,
    'cancel_reason', v_sr.cancel_reason,
    'total_amount', case when v_can_price then (
      select coalesce(sum(srl.qty_stock * srl.unit_cost), 0)
      from public.supplier_return_lines srl
      where srl.return_id = p_return_id
    ) else null end,
    'lines', v_lines
  );
end;
$$;

-- Dong cua phieu nhan da post con tra duoc (da nhan - da tra > 0).
-- UI tao phieu tra dung RPC nay de gioi han so luong tra.
create or replace function public.supplier_return_eligible_lines(
  p_gr_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_can_price boolean;
  v_lines jsonb;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'supplier_return.post');

  if v_gr.status <> 'posted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  v_can_price := public.has_perm(v_gr.property_id, 'po.view_price');

  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_lines
  from (
    select
      grl.id as gr_line_id,
      grl.po_line_id,
      grl.item_id,
      i.name as item_name,
      grl.uom,
      grl.accepted_qty_stock,
      public._receiving_returned_qty(grl.id) as returned_qty_stock,
      grl.accepted_qty_stock
        - public._receiving_returned_qty(grl.id) as returnable_qty_stock,
      case when v_can_price then grl.unit_cost else null end as unit_cost
    from public.goods_receipt_lines grl
    join public.items i
      on i.id = grl.item_id and i.org_id = grl.org_id
    where grl.gr_id = p_gr_id
      and grl.accepted_qty_stock > 0
      and grl.qc_status <> 'fail'
      and grl.posted_warehouse_id is not null
      and grl.unit_cost is not null
      and grl.accepted_qty_stock
        - public._receiving_returned_qty(grl.id) > 0
    order by grl.created_at
  ) l;

  return jsonb_build_object(
    'ok', true,
    'gr_id', p_gr_id,
    'gr_doc_no', v_gr.doc_no,
    'lines', v_lines
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. RPC — vong doi phieu tra QC fail 'recorded'.
-- ---------------------------------------------------------------------------

-- Xac nhan NCC da lay hang ve: 'recorded' -> 'posted'. Hang QC fail khong
-- vao kho nen buoc nay khong move kho — chi ghi nhan bang chung lay hang
-- (chu ky nguoi giao hoac anh, theo M04) + nguoi/gio xac nhan.
create or replace function public.supplier_return_confirm(
  p_return_id uuid,
  p_supplier_signature_path text default null,
  p_photo_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sr record;
begin
  select sr.* into v_sr
  from public.supplier_returns sr
  where sr.id = p_return_id;

  if v_sr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_sr.property_id, 'supplier_return.post');

  if v_sr.status <> 'recorded' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Bat buoc bang chung lay hang MOI o buoc xac nhan (chu ky hoac anh).
  if (p_supplier_signature_path is null
      or btrim(p_supplier_signature_path) = '')
    and (p_photo_ids is null or cardinality(p_photo_ids) = 0) then
    raise exception using errcode = 'P0001', message = 'ERR_PHOTO_REQUIRED';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  update public.supplier_returns
  set status = 'posted',
      supplier_signature_path = coalesce(
        nullif(btrim(p_supplier_signature_path), ''),
        supplier_signature_path),
      photo_ids = photo_ids || coalesce(p_photo_ids, '{}'),
      confirmed_by = auth.uid(),
      confirmed_at = now(),
      updated_at = now()
  where id = p_return_id;

  return jsonb_build_object(
    'ok', true, 'id', p_return_id, 'doc_no', v_sr.doc_no,
    'status', 'posted'
  );
end;
$$;

-- Huy phieu tra QC fail 'recorded' (VD: NCC doi hang tai cho, ghi nhan
-- nham): 'recorded' -> 'cancelled', ly do bat buoc.
create or replace function public.supplier_return_cancel(
  p_return_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sr record;
begin
  select sr.* into v_sr
  from public.supplier_returns sr
  where sr.id = p_return_id;

  if v_sr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_sr.property_id, 'supplier_return.post');

  if v_sr.status <> 'recorded' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  update public.supplier_returns
  set status = 'cancelled',
      cancel_reason = btrim(p_reason),
      cancelled_by = auth.uid(),
      cancelled_at = now(),
      updated_at = now()
  where id = p_return_id;

  return jsonb_build_object(
    'ok', true, 'id', p_return_id, 'doc_no', v_sr.doc_no,
    'status', 'cancelled'
  );
end;
$$;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109250000_supplier_returns',
  'INSERT',
  jsonb_build_object('event', 'supplier_returns_completed', 'task', 'T-026'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
