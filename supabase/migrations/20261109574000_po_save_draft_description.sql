-- Q268 (14/11/2026): po_save_draft cap nhat mo ta cho dong da co khong ma hang.
-- Bao cao dem 13-14/11 (B-2): sua mo ta dong PO cho -> luu xong mo ta van cu.
CREATE OR REPLACE FUNCTION public.po_save_draft(p_property_id uuid, p_po jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_org_id uuid;
  v_po public.purchase_orders%rowtype;
  v_po_id uuid;
  v_line jsonb;
  v_line_id uuid;
  v_old public.purchase_order_lines%rowtype;
  v_item_id uuid;
  v_qty numeric(18,4);
  v_uom text;
  v_unit_price numeric(18,4);
  v_price_source text;
  v_ceiling_price numeric(18,4);
  v_over_ceiling boolean;
  v_qty_stock numeric(18,4);
  v_total numeric(18,2);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'po.create');

  v_po_id := nullif(p_po ->> 'id', '')::uuid;
  if v_po_id is null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = v_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status not in ('draft', 'rejected') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if jsonb_typeof(coalesce(p_po -> 'lines', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_org_id := v_po.org_id;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.purchase_orders po
  set expected_date = case
      when p_po ? 'expected_date'
      then nullif(p_po ->> 'expected_date', '')::date
      else po.expected_date end,
    over_ceiling_reason = case
      when p_po ? 'over_ceiling_reason'
      then nullif(p_po ->> 'over_ceiling_reason', '')
      else po.over_ceiling_reason end,
    status = 'draft'
  where po.id = v_po_id;

  if v_po.status = 'rejected' then
    delete from public.approvals
    where doc_type = 'po' and doc_id = v_po_id;
  end if;

  -- Dong bi xoa khoi payload: tra lai so luong da chuyen cho dong PR.
  for v_old in
    select * from public.purchase_order_lines pol
    where pol.po_id = v_po_id
      and not exists (
        select 1
        from jsonb_array_elements(coalesce(p_po -> 'lines', '[]'::jsonb)) l
        where nullif(l ->> 'id', '')::uuid = pol.id
      )
  loop
    if v_old.pr_line_id is not null then
      update public.purchase_request_lines
      set converted_qty = converted_qty - v_old.qty
      where id = v_old.pr_line_id;
      update public.purchase_requests pr
      set status = 'approved'
      where pr.id = (
        select prl.pr_id from public.purchase_request_lines prl
        where prl.id = v_old.pr_line_id
      )
      and pr.status = 'converted';
    end if;
    delete from public.purchase_order_lines where id = v_old.id;
  end loop;

  for v_line in
    select * from jsonb_array_elements(coalesce(p_po -> 'lines', '[]'::jsonb))
  loop
    v_line_id := nullif(v_line ->> 'id', '')::uuid;
    v_item_id := nullif(v_line ->> 'item_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    v_uom := v_line ->> 'uom';

    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_uom is null or not exists (
      select 1 from public.uoms u where u.code = v_uom
    ) then
      raise exception 'ERR_UOM_UNKNOWN';
    end if;
    if v_item_id is not null and not exists (
      select 1 from public.items i
      where i.id = v_item_id and i.org_id = v_org_id and i.status = 'active'
    ) then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    if v_item_id is null
      and (v_line ->> 'description' is null or btrim(v_line ->> 'description') = '')
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    -- Q267: PO cho (channel market) duoc phep dong chi co mo ta (chua biet mat hang).
    if v_po.kind = 'stock' and v_po.channel <> 'market' and v_item_id is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if nullif(v_line ->> 'expense_category_id', '')::uuid is not null
      and not exists (
        select 1 from public.expense_categories ec
        where ec.id = nullif(v_line ->> 'expense_category_id', '')::uuid
          and ec.org_id = v_org_id
      )
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if nullif(v_line ->> 'cost_center_id', '')::uuid is not null
      and not exists (
        select 1 from public.cost_centers cc
        where cc.id = nullif(v_line ->> 'cost_center_id', '')::uuid
          and cc.org_id = v_org_id
      )
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    if v_line_id is not null then
      select * into v_old
      from public.purchase_order_lines pol where pol.id = v_line_id;
      if not found or v_old.po_id <> v_po_id then
        raise exception 'ERR_INVALID_STATUS';
      end if;
      -- Q268: dong khong co ma hang (mua cho/dich vu) duoc sua mo ta.
      -- Truoc day mo ta cua dong da co khong bao gio duoc cap nhat -> mat sua.
      if v_old.item_id is null and v_line ? 'description' then
        update public.purchase_order_lines pol
        set description = nullif(btrim(v_line ->> 'description'), '')
        where pol.id = v_line_id;
      end if;
      if v_old.pr_line_id is not null then
        -- Dong gan PR: chi cho luu lai nguyen ven (khong sua); muon doi
        -- thi xoa dong khoi payload roi tao lai bang po_create_from_pr.
        -- Ngoai le (Q224): dong gia tay (price_source = 'manual') duoc
        -- sua unit_price — neu khong thi dong manual khong bao gio co
        -- gia (resolver tra 0 khi khong co hop dong/tran) va po_submit
        -- luon nem ERR_PRICE_NOT_SET: luong gia tay chet hoan toan.
        -- Gia hop dong/tran van cam sua (giua nguyen §21).
        if v_old.item_id is distinct from v_item_id
          or v_old.uom <> v_uom
          or v_old.qty <> v_qty
          or (v_line ? 'unit_price'
            and (v_line ->> 'unit_price')::numeric(18,4) <> v_old.unit_price
            and v_old.price_source <> 'manual')
          or (v_line ? 'expense_category_id'
            and nullif(v_line ->> 'expense_category_id', '')::uuid
              is distinct from v_old.expense_category_id)
          or (v_line ? 'cost_center_id'
            and nullif(v_line ->> 'cost_center_id', '')::uuid
              is distinct from v_old.cost_center_id)
        then
          raise exception 'ERR_INVALID_STATUS';
        end if;
        if v_old.price_source = 'manual' and (v_line ? 'unit_price') then
          update public.purchase_order_lines pol
          set unit_price = (v_line ->> 'unit_price')::numeric(18,4),
              over_ceiling = (pol.ceiling_price is not null
                and (v_line ->> 'unit_price')::numeric(18,4) > pol.ceiling_price)
          where pol.id = v_line_id;
        end if;
        continue;
      end if;
      if v_old.item_id is distinct from v_item_id
        or v_old.uom <> v_uom
      then
        -- Doi item/uom: xoa dong cu khoi payload, them dong moi.
        raise exception 'ERR_INVALID_STATUS';
      end if;

      v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

      update public.purchase_order_lines pol
      set qty = v_qty,
          qty_stock = v_qty_stock,
          unit_price = case
            when pol.price_source = 'manual'
              and v_line ? 'unit_price'
            then (v_line ->> 'unit_price')::numeric(18,4)
            else pol.unit_price end,
          over_ceiling = case
            when pol.price_source = 'manual'
              and v_line ? 'unit_price'
            then (pol.ceiling_price is not null
              and (v_line ->> 'unit_price')::numeric(18,4) > pol.ceiling_price)
            else pol.over_ceiling end,
          expense_category_id = case
            when v_line ? 'expense_category_id'
            then nullif(v_line ->> 'expense_category_id', '')::uuid
            else pol.expense_category_id end,
          cost_center_id = case
            when v_line ? 'cost_center_id'
            then nullif(v_line ->> 'cost_center_id', '')::uuid
            else pol.cost_center_id end
      where pol.id = v_line_id
        and (
          pol.price_source = 'manual'
          or not (v_line ? 'unit_price')
          or (v_line ->> 'unit_price')::numeric(18,4) = pol.unit_price
        );
      if not found then
        raise exception 'ERR_INVALID_STATUS';
      end if;
    else
      if v_po.channel = 'market' and v_item_id is not null and not (
        select 'market' = any(i.allowed_channels)
        from public.items i where i.id = v_item_id
      ) then
        raise exception 'ERR_CHANNEL_NOT_ALLOWED';
      end if;

      select unit_price, price_source, ceiling_price, over_ceiling
        into v_unit_price, v_price_source, v_ceiling_price, v_over_ceiling
      from public._po_resolve_line_price(
        v_org_id, p_property_id, v_po.supplier_id,
        v_item_id, v_uom, v_today
      );
      -- Dong moi co gia tay gui kem thi dung gia do (chi khi manual).
      if v_price_source = 'manual' and (v_line ? 'unit_price') then
        v_unit_price := (v_line ->> 'unit_price')::numeric(18,4);
        v_over_ceiling := v_ceiling_price is not null
          and v_unit_price > v_ceiling_price;
      end if;

      v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

      insert into public.purchase_order_lines (
        po_id, org_id, pr_line_id, item_id, description, qty, uom,
        qty_stock, unit_price, price_source, ceiling_price, over_ceiling,
        expense_category_id, cost_center_id, created_by
      )
      values (
        v_po_id, v_org_id, null, v_item_id,
        nullif(v_line ->> 'description', ''),
        v_qty, v_uom, v_qty_stock,
        v_unit_price, v_price_source, v_ceiling_price,
        v_over_ceiling,
        nullif(v_line ->> 'expense_category_id', '')::uuid,
        nullif(v_line ->> 'cost_center_id', '')::uuid,
        auth.uid()
      );
    end if;
  end loop;

  select total_amount into v_total
  from public.purchase_orders where id = v_po_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_po_id,
    'doc_no', v_po.doc_no,
    'status', 'draft',
    'total_amount', v_total
  );
end;
$function$;
