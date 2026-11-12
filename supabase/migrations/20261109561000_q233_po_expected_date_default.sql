-- ============================================================================
-- Q233 (Duy chot 12/11/2026: lam CA HAI huong, giu luat PO chua gui NCC):
--   (a) po_create_from_pr dat expected_date = order_date cho PO moi (truoc day
--       INSERT khong dat -> NULL).
--   (b) receiving_list_tasks coi expected_date NULL la den han (truoc day
--       `expected_date <= today` loai moi PO NULL, nen cac PO cu van NULL se
--       khong bao gio hien trong man nhan hang). Khong can backfill.
--   KHONG doi _receiving_po_eligible: PO hop dong chi nhan duoc khi
--   status in ('sent','partially_received') — approved chua gui NCC van khong
--   nhan duoc (quyet dinh Duy).
--   Hai ham duoc sinh lai NGUYEN VAN tu ban cuoi cung (210000 / 230000), chi
--   doi dung cac dong noi tren. Grant giu nguyen (create or replace khong
--   doi quyen).
-- ============================================================================
create or replace function public.po_create_from_pr(
  p_property_id uuid,
  p_pr_line_ids uuid[],
  p_supplier_id uuid,
  p_channel text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_sup public.suppliers%rowtype;
  v_po_id uuid;
  v_po_no text;
  v_kind text;
  v_line_id uuid;
  v_prl public.purchase_request_lines%rowtype;
  v_pr public.purchase_requests%rowtype;
  v_remaining numeric(18,4);
  v_unit_price numeric(18,4);
  v_price_source text;
  v_ceiling_price numeric(18,4);
  v_over_ceiling boolean;
  v_qty_stock numeric(18,4);
  v_lines integer := 0;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'po.create');

  if p_channel not in ('contract', 'quote', 'market') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_pr_line_ids is null or array_length(p_pr_line_ids, 1) is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select p.org_id, p.legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_sup
  from public.suppliers s where s.id = p_supplier_id;
  if not found or v_sup.org_id <> v_org_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_sup.status <> 'active' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  -- Kiem tra truoc toan bo dong: cung KS, PR da duyet, con so luong,
  -- cung kind, kenh mua cho hop le.
  for v_line_id in select unnest(p_pr_line_ids) loop
    select * into v_prl
    from public.purchase_request_lines prl where prl.id = v_line_id;
    if not found or v_prl.org_id <> v_org_id then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    select * into v_pr
    from public.purchase_requests pr where pr.id = v_prl.pr_id;
    if v_pr.property_id <> p_property_id or v_pr.status <> 'approved' then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    v_remaining := v_prl.qty - v_prl.converted_qty;
    if v_remaining <= 0 then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    if v_kind is null then
      v_kind := v_pr.kind;
    elsif v_kind <> v_pr.kind then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    if v_prl.item_id is not null then
      if not exists (
        select 1 from public.items i
        where i.id = v_prl.item_id and i.org_id = v_org_id and i.status = 'active'
      ) then
        raise exception 'ERR_INVALID_STATUS';
      end if;
      if p_channel = 'market' and not (
        select 'market' = any(i.allowed_channels)
        from public.items i where i.id = v_prl.item_id
      ) then
        raise exception 'ERR_CHANNEL_NOT_ALLOWED';
      end if;
    end if;
  end loop;

  v_po_no := public.next_doc_no(v_legal_entity_id, 'PO', v_today);

  insert into public.purchase_orders (
    org_id, legal_entity_id, property_id, supplier_id, channel, kind,
    order_date, expected_date, status, doc_no, created_by
  )
  values (
    v_org_id, v_legal_entity_id, p_property_id, p_supplier_id, p_channel,
    v_kind, v_today, v_today, 'draft', v_po_no, auth.uid()
  )
  returning id into v_po_id;

  for v_line_id in select unnest(p_pr_line_ids) loop
    select * into v_prl
    from public.purchase_request_lines prl where prl.id = v_line_id;
    v_remaining := v_prl.qty - v_prl.converted_qty;

    select unit_price, price_source, ceiling_price, over_ceiling
      into v_unit_price, v_price_source, v_ceiling_price, v_over_ceiling
    from public._po_resolve_line_price(
      v_org_id, p_property_id, p_supplier_id,
      v_prl.item_id, v_prl.uom, v_today
    );

    v_qty_stock := public._po_line_qty_stock(
      v_org_id, v_prl.item_id, v_prl.uom, v_remaining
    );

    insert into public.purchase_order_lines (
      po_id, org_id, pr_line_id, item_id, description, qty, uom,
      qty_stock, unit_price, price_source, ceiling_price, over_ceiling,
      expense_category_id, cost_center_id, created_by
    )
    values (
      v_po_id, v_org_id, v_prl.id, v_prl.item_id, v_prl.description,
      v_remaining, v_prl.uom, v_qty_stock,
      v_unit_price, v_price_source, v_ceiling_price,
      v_over_ceiling,
      v_prl.expense_category_id, v_prl.cost_center_id, auth.uid()
    );

    update public.purchase_request_lines
    set converted_qty = qty
    where id = v_line_id;

    v_lines := v_lines + 1;
  end loop;

  -- PR nao chuyen het dong thi chuyen sang 'converted'.
  update public.purchase_requests pr
  set status = 'converted'
  where pr.id in (
    select distinct prl.pr_id
    from public.purchase_request_lines prl
    where prl.id = any(p_pr_line_ids)
  )
  and pr.status = 'approved'
  and not exists (
    select 1 from public.purchase_request_lines prl2
    where prl2.pr_id = pr.id and prl2.converted_qty < prl2.qty
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_po_id,
    'doc_no', v_po_no,
    'kind', v_kind,
    'lines', v_lines,
    'status', 'draft'
  );
end;
$$;

create or replace function public.receiving_list_tasks(
  p_property_id uuid,
  p_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_date date := coalesce(
    p_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_rows jsonb;
begin
  select p.org_id into v_org_id
  from public.properties p
  where p.id = p_property_id;

  if v_org_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(p_property_id, 'receiving.perform');

  select coalesce(jsonb_agg(t), '[]'::jsonb) into v_rows
  from (
    select
      po.id as po_id,
      po.doc_no,
      coalesce(s.name, 'Mua chợ') as supplier_name,
      po.channel,
      po.expected_date,
      count(pol.id)::int as line_count
    from public.purchase_orders po
    left join public.suppliers s
      on s.id = po.supplier_id and s.org_id = po.org_id
    join public.purchase_order_lines pol
      on pol.po_id = po.id and pol.org_id = po.org_id
    where po.property_id = p_property_id
      and (po.expected_date is null or po.expected_date <= v_date)
      and public._receiving_po_eligible(po.channel, po.status)
      and pol.item_id is not null
      and pol.received_qty_stock < pol.qty_stock
    group by po.id, po.doc_no, s.name, po.channel, po.expected_date
    order by coalesce(po.expected_date, po.order_date), po.doc_no
  ) t;

  return jsonb_build_object('ok', true, 'tasks', v_rows);
end;
$$;
