-- Q277 (14/11/2026): C2-N3 — ghi hang hong MOT PHAN khi nhan hang ("nhan 180, hong 5").
-- Truoc day QC chi co dat/khong dat cho CA DONG. Nay p_qc.rejected_qty (+ reject_reason): phan hong
-- khong nhap kho, ghi vao dong nhan (rejected_qty_stock) va sinh phieu tra NCC 'recorded' cho phan hong;
-- dung sai/so nhan tinh tren phan tot. Phan hong luon < tong net (ca dong hong = QC khong dat).
alter table public.goods_receipt_lines
  add column if not exists rejected_qty_stock numeric(18,4) not null default 0 check (rejected_qty_stock >= 0),
  add column if not exists reject_reason text;

CREATE OR REPLACE FUNCTION public.receiving_record_line(p_gr_id uuid, p_po_line_id uuid, p_item_id uuid, p_gross numeric, p_tare numeric DEFAULT 0, p_uom text DEFAULT NULL::text, p_qc jsonb DEFAULT '{}'::jsonb, p_lot text DEFAULT NULL::text, p_expiry date DEFAULT NULL::date, p_photo_ids uuid[] DEFAULT NULL::uuid[], p_client_uuid uuid DEFAULT NULL::uuid, p_photo_waived_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_gr record;
  v_pol record;
  v_item record;
  v_line record;
  v_uom text;
  v_net numeric;
  v_net_stock numeric;
  v_remaining numeric;
  v_cap numeric;
  v_tol numeric;
  v_dev numeric;
  v_qc_status text;
  v_photo_required boolean;
  v_waived text := nullif(btrim(coalesce(p_photo_waived_reason, '')), '');
  v_rej numeric := 0;
  v_rej_stock numeric := 0;
  v_part_ret_id uuid;
  v_part_ret_no text;
  v_unit_cost numeric;
  v_short_warning boolean := false;
  v_accepted numeric;
  v_over_po numeric;
  v_needs_reweigh boolean;
  v_is_reweigh boolean := false;
  v_line_id uuid;
  v_ret_id uuid;
  v_ret_no text;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.perform');

  if v_gr.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if v_gr.receiver_id <> auth.uid() then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.perform';
  end if;

  -- Idempotency (offline queue T-025): tra lai dong da ghi.
  if p_client_uuid is not null then
    select grl.* into v_line
    from public.goods_receipt_lines grl
    where grl.client_uuid = p_client_uuid and grl.gr_id = p_gr_id;

    if found then
      return jsonb_build_object(
        'ok', true,
        'id', v_line.id,
        'weigh_count', v_line.weigh_count,
        'needs_reweigh', v_line.needs_reweigh,
        'accepted_qty_stock_capped', v_line.accepted_qty_stock,
        'short_shelf_life_warning', false
      );
    end if;
  end if;

  select pol.* into v_pol
  from public.purchase_order_lines pol
  where pol.id = p_po_line_id and pol.po_id = v_gr.po_id;

  if v_pol.id is null or v_pol.item_id is null or v_pol.item_id <> p_item_id then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select i.* into v_item
  from public.items i
  where i.id = p_item_id and i.org_id = v_gr.org_id;

  if v_item.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_ITEM_NOT_FOUND';
  end if;

  v_uom := coalesce(p_uom, v_pol.uom);

  if p_gross is null or p_gross <= 0 or p_tare is null or p_tare < 0
    or p_gross <= p_tare then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_net := p_gross - p_tare;
  v_net_stock := public._po_line_qty_stock(v_gr.org_id, p_item_id, v_uom, v_net);

  v_qc_status := coalesce(p_qc ->> 'status', 'pass');
  if v_qc_status not in ('pass', 'fail', 'conditional') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- Q277 (C2-N3): hang hong MOT PHAN. p_qc.rejected_qty (theo UOM ghi nhan, < net) la phan hong:
  -- khong nhap kho, sinh phieu tra NCC 'recorded' (khong move kho, nhu QC fail nhung chi phan hong).
  -- Dung sai/so nhan tinh tren phan TOT (net_stock sau khi tru hong).
  v_rej := coalesce(nullif(p_qc ->> 'rejected_qty', '')::numeric, 0);
  if v_rej < 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_rej > 0 then
    -- QC fail = tra ca dong; hong mot phan phai nho hon tong net.
    if v_qc_status = 'fail' or v_rej >= v_net then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    v_rej_stock := round(v_net_stock * v_rej / v_net, 4);
    v_net_stock := v_net_stock - v_rej_stock;
  end if;

  -- Hang theo lot: bat buoc so lot + han su dung.
  if v_item.track_lot and (p_lot is null or p_lot = '' or p_expiry is null) then
    raise exception using errcode = 'P0001', message = 'ERR_LOT_REQUIRED';
  end if;

  -- Anh bat buoc theo dong (hang then chot / nhom thuc pham).
  v_photo_required := public._receiving_photo_required(v_gr.org_id, p_item_id);
  if v_photo_required and coalesce(cardinality(p_photo_ids), 0) = 0 then
    -- Q274 (quyet dinh Duy): thiet bi khong co camera thi duoc nhan khong anh
    -- khi nguoi nhan xac nhan + ghi ly do; luon de lai vet (receiving_photo_waivers + nhat ky).
    if v_waived is null then
      raise exception using errcode = 'P0001', message = 'ERR_PHOTO_REQUIRED';
    end if;
    insert into public.receiving_photo_waivers
      (org_id, property_id, gr_id, po_line_id, item_id, reason)
    values
      (v_gr.org_id, v_gr.property_id, p_gr_id, p_po_line_id, p_item_id, v_waived);
  end if;

  -- Anh phai la attachment doc_type = 'receiving', doc_id = phieu nay
  -- (line_id khong cap nhat duoc — trigger T-016 chan UPDATE attachments).
  if coalesce(cardinality(p_photo_ids), 0) > 0 then
    if exists (
      select 1 from public.attachments a
      where a.id = any (p_photo_ids)
        and (a.doc_type <> 'receiving' or a.doc_id <> p_gr_id)
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    if (select count(*) from public.attachments a
        where a.id = any (p_photo_ids)) <> cardinality(p_photo_ids) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
  end if;

  -- Canh bao han su dung ngan: expiry < 50% shelf_life ke tu hom nay.
  if v_item.track_lot and v_item.shelf_life_days is not null
    and p_expiry is not null then
    if p_expiry < current_date + floor(v_item.shelf_life_days * 0.5)::int then
      v_short_warning := true;
    end if;
  end if;

  v_tol := public._receiving_tolerance_pct(v_gr.org_id, v_gr.property_id);
  -- Don gia PO dinh gia theo UOM cua dong PO (pol.uom), khong phai UOM ghi
  -- nhan (v_uom) — quy doi sai o day se lech gia von theo he so don vi.
  v_unit_cost := public._receiving_unit_cost_stock(
    v_gr.org_id, p_item_id, v_pol.uom, v_pol.unit_price);

  -- So con mo tai luc nhan (chi tinh so da POST).
  v_remaining := v_pol.qty_stock - v_pol.received_qty_stock;
  if v_remaining <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  v_cap := v_remaining * (1 + v_tol / 100);
  v_dev := abs(v_net_stock - v_remaining) / v_remaining * 100;

  -- Dong da ton tai -> can lai (lan 2). QC fail la chung ket cua dong:
  -- muon nhan lai phai mo phieu moi (phieu tra 'recorded' da sinh).
  select grl.* into v_line
  from public.goods_receipt_lines grl
  where grl.gr_id = p_gr_id and grl.po_line_id = p_po_line_id;

  if found then
    if v_line.weigh_count >= 2 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    if v_line.qc_status = 'fail' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    v_is_reweigh := true;
  end if;

  -- Quy tac chap nhan (D3):
  --  can 1 lech ngoai dung sai -> needs_reweigh, chua nhan (accepted = 0);
  --  can 2 lech ngoai dung sai -> nhan so thuc, cap o tran; phan du ghi
  --  over_po (can override moi nhan du); lech trong dung sai -> nhan du.
  if v_qc_status = 'fail' then
    v_needs_reweigh := false;
    v_accepted := 0;
    v_over_po := 0;
  elsif v_dev <= v_tol then
    v_needs_reweigh := false;
    v_accepted := least(v_net_stock, v_cap);
    v_over_po := 0;
  elsif not v_is_reweigh then
    v_needs_reweigh := true;
    v_accepted := 0;
    v_over_po := 0;
  else
    v_needs_reweigh := true;
    v_accepted := least(v_net_stock, v_cap);
    v_over_po := greatest(v_net_stock - v_cap, 0);
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  if not v_is_reweigh then
    insert into public.goods_receipt_lines (
      gr_id, org_id, property_id, po_line_id, item_id,
      gross_qty, tare_qty, uom, net_qty_stock, unit_cost,
      accepted_qty_stock, over_po_qty_stock,
      qc_status, qc_checklist, temperature_c,
      lot_no, expiry_date,
      weigh_count, weigh1_gross_qty, weigh1_tare_qty,
      needs_reweigh, photo_ids, client_uuid
    ) values (
      p_gr_id, v_gr.org_id, v_gr.property_id, p_po_line_id, p_item_id,
      p_gross, p_tare, v_uom, v_net_stock, v_unit_cost,
      v_accepted, v_over_po,
      v_qc_status, coalesce(p_qc -> 'checklist', '{}'::jsonb),
      (p_qc ->> 'temperature_c')::numeric,
      p_lot, p_expiry,
      1, p_gross, p_tare,
      v_needs_reweigh, coalesce(p_photo_ids, '{}'),
      p_client_uuid
    ) returning id into v_line_id;
  else
    update public.goods_receipt_lines
    set gross_qty = p_gross,
        tare_qty = p_tare,
        uom = v_uom,
        net_qty_stock = v_net_stock,
        unit_cost = v_unit_cost,
        accepted_qty_stock = v_accepted,
        over_po_qty_stock = v_over_po,
        override_by = null,
        override_reason = null,
        qc_status = v_qc_status,
        qc_checklist = coalesce(p_qc -> 'checklist', '{}'::jsonb),
        temperature_c = (p_qc ->> 'temperature_c')::numeric,
        lot_no = p_lot,
        expiry_date = p_expiry,
        weigh_count = 2,
        weigh2_gross_qty = p_gross,
        weigh2_tare_qty = p_tare,
        needs_reweigh = v_needs_reweigh,
        photo_ids = coalesce(p_photo_ids, '{}'),
        client_uuid = coalesce(p_client_uuid, client_uuid),
        updated_at = now()
    where id = v_line.id
    returning id into v_line_id;
  end if;

  -- Q277: ghi phan hong + phieu tra 'recorded' cho phan hong (cân lai thi lam lai).
  update public.goods_receipt_lines
  set rejected_qty_stock = v_rej_stock,
      reject_reason = case when v_rej_stock > 0 then nullif(btrim(coalesce(p_qc ->> 'reject_reason', '')), '') end
  where id = v_line_id;

  delete from public.supplier_return_lines srl
  using public.supplier_returns sr
  where srl.gr_line_id = v_line_id and sr.id = srl.return_id and sr.status = 'recorded';
  delete from public.supplier_returns sr
  where sr.gr_id = p_gr_id and sr.status = 'recorded'
    and not exists (select 1 from public.supplier_return_lines x where x.return_id = sr.id)
    and v_qc_status <> 'fail';

  if v_rej_stock > 0 then
    v_part_ret_no := public.next_doc_no(
      v_gr.legal_entity_id, 'SRT',
      (now() at time zone 'Asia/Ho_Chi_Minh')::date);
    insert into public.supplier_returns (
      org_id, legal_entity_id, property_id, gr_id, po_id, supplier_id,
      doc_no, status, reason, photo_ids
    ) values (
      v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
      p_gr_id, v_gr.po_id, v_gr.supplier_id,
      v_part_ret_no, 'recorded',
      coalesce(nullif(btrim(coalesce(p_qc ->> 'reject_reason', '')), ''), 'Hàng hỏng một phần'),
      coalesce(p_photo_ids, '{}')
    ) returning id into v_part_ret_id;
    insert into public.supplier_return_lines (
      return_id, org_id, gr_line_id, item_id, qty_stock, unit_cost, reason, photo_ids
    ) values (
      v_part_ret_id, v_gr.org_id, v_line_id, p_item_id, v_rej_stock, v_unit_cost,
      coalesce(nullif(btrim(coalesce(p_qc ->> 'reject_reason', '')), ''), 'Hàng hỏng một phần'),
      coalesce(p_photo_ids, '{}')
    );
  end if;

  -- QC fail: sinh phieu tra NCC 'recorded' ngay (khong move kho).
  if v_qc_status = 'fail' then
    v_ret_no := public.next_doc_no(
      v_gr.legal_entity_id, 'SRT',
      (now() at time zone 'Asia/Ho_Chi_Minh')::date);

    insert into public.supplier_returns (
      org_id, legal_entity_id, property_id, gr_id, po_id, supplier_id,
      doc_no, status, reason,
      supplier_signature_path, photo_ids
    ) values (
      v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
      p_gr_id, v_gr.po_id, v_gr.supplier_id,
      v_ret_no, 'recorded', p_qc ->> 'reason',
      p_qc ->> 'supplier_signature_path', coalesce(p_photo_ids, '{}')
    ) returning id into v_ret_id;

    insert into public.supplier_return_lines (
      return_id, org_id, gr_line_id, item_id, qty_stock, unit_cost,
      reason, photo_ids, supplier_signature_path
    ) values (
      v_ret_id, v_gr.org_id, v_line_id, p_item_id, v_net_stock, v_unit_cost,
      p_qc ->> 'reason', coalesce(p_photo_ids, '{}'),
      p_qc ->> 'supplier_signature_path'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_line_id,
    'weigh_count', case when v_is_reweigh then 2 else 1 end,
    'needs_reweigh', v_needs_reweigh,
    'accepted_qty_stock_capped', v_accepted,
    'short_shelf_life_warning', v_short_warning
  );
end;
$function$;
