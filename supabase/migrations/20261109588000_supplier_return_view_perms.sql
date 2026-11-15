-- Q284: GM (stock.view_qty) xem duoc phieu tra hang NCC (chi doc; gia van an neu thieu po.view_price).

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
    or public.has_perm(p_property_id, 'stock.view_qty')
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
    or public.has_perm(v_sr.property_id, 'stock.view_qty')
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
