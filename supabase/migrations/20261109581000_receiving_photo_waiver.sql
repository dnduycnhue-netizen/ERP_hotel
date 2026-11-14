-- Q274 (14/11/2026): quyet dinh Duy — nhan hang co 2 phuong an: chup camera; neu thiet bi khong co
-- camera thi tich xac nhan (kem ly do) la duoc. KHONG bo vet: moi lan nhan khong anh ghi vao
-- receiving_photo_waivers (co nhat ky audit), nguoi hau kiem xem duoc.
create table if not exists public.receiving_photo_waivers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  gr_id uuid not null references public.goods_receipts(id),
  po_line_id uuid not null,
  item_id uuid not null,
  reason text not null check (length(btrim(reason)) > 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists receiving_photo_waivers_gr_idx on public.receiving_photo_waivers (gr_id);
alter table public.receiving_photo_waivers enable row level security;
drop policy if exists receiving_photo_waivers_select on public.receiving_photo_waivers;
create policy receiving_photo_waivers_select on public.receiving_photo_waivers for select to authenticated
  using (
    property_id in (select public.my_property_ids())
    and (public.has_perm(property_id, 'receiving.view') or public.has_perm(property_id, 'receiving.review_photos'))
  );
revoke insert, update, delete on public.receiving_photo_waivers from anon, authenticated;
drop trigger if exists trg_receiving_photo_waivers_audit on public.receiving_photo_waivers;
create trigger trg_receiving_photo_waivers_audit after insert or update or delete on public.receiving_photo_waivers
  for each row execute function public.audit_trigger();

drop function if exists public.receiving_record_line(uuid, uuid, uuid, numeric, numeric, text, jsonb, text, date, uuid[], uuid);

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

revoke all on function public.receiving_record_line(uuid, uuid, uuid, numeric, numeric, text, jsonb, text, date, uuid[], uuid, text) from public, anon;
grant execute on function public.receiving_record_line(uuid, uuid, uuid, numeric, numeric, text, jsonb, text, date, uuid[], uuid, text) to authenticated;

CREATE OR REPLACE FUNCTION public.receiving_post(p_gr_id uuid, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_gr record;
  v_po record;
  v_line record;
  v_pol record;
  v_item record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_tol numeric;
  v_remaining numeric;
  v_cap numeric;
  v_accepted numeric;
  v_unit_cost numeric;
  v_lot_id uuid;
  v_lot_expiry date;
  v_target_wh uuid;
  v_final_wh uuid;
  v_move_id bigint;
  v_out_cost numeric;
  v_total numeric := 0;
  v_posted_lines int := 0;
  v_att_count int;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.post');

  if v_gr.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Chi nguoi nhan da mo phieu moi duoc post phieu do.
  if v_gr.receiver_id <> auth.uid() then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.post';
  end if;

  -- R18 (co rule.R18.enabled): khi co BAT (mac dinh) van kiem PIN truoc
  -- khi cham den ton kho; khi co TAT bo kiem PIN. SoD_PO_RECEIVER va
  -- SOD_MARKET_BUYER_RECEIVER ben duoi khong doi.
  if public._rule_enabled(v_gr.property_id, 'R18') then
    perform public._verify_pin(p_pin);
  end if;

  -- SoD: nguoi tao/duyet PO khong duoc nhan; nguoi giu tam ung cho khong
  -- duoc nhan PO cho do. _sod_check chi raise khi khong co ngoai le hop le.
  select po.* into v_po
  from public.purchase_orders po
  where po.id = v_gr.po_id;

  if v_po.created_by = auth.uid() then
    perform public._sod_check(v_gr.property_id, 'SOD_PO_RECEIVER');
  end if;

  if exists (
    select 1 from public.approvals a
    where a.doc_type = 'po' and a.doc_id = v_gr.po_id
      and a.decision = 'approved' and a.decided_by = auth.uid()
  ) then
    perform public._sod_check(v_gr.property_id, 'SOD_PO_RECEIVER');
  end if;

  if v_po.advance_id is not null and exists (
    select 1 from public.advances ad
    where ad.id = v_po.advance_id and ad.employee_id = auth.uid()
  ) then
    perform public._sod_check(v_gr.property_id, 'SOD_MARKET_BUYER_RECEIVER');
  end if;

  -- Chan post khi con dong chua can lai xong (can 1 lech, chua can lan 2).
  if exists (
    select 1 from public.goods_receipt_lines grl
    where grl.gr_id = p_gr_id
      and grl.needs_reweigh
      and grl.weigh_count = 1
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Moi phieu phai co it nhat 1 anh (05 §3: "Anh chup phieu (bat buoc)").
  select count(*) into v_att_count
  from public.attachments a
  where a.doc_type = 'receiving' and a.doc_id = p_gr_id;

  -- Q274: phieu da nhan khong anh co xac nhan 'khong co camera' (receiving_photo_waivers) van post duoc.
  if v_att_count = 0 and not exists (
    select 1 from public.receiving_photo_waivers w where w.gr_id = p_gr_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PHOTO_REQUIRED';
  end if;

  v_tol := public._receiving_tolerance_pct(v_gr.org_id, v_gr.property_id);

  perform set_config('app.receiving_guard_bypass', 'on', true);
  -- Mo bypass T-020 (210000): _pr_po_write_guard chan moi ghi vao
  -- purchase_order_lines; _pr_po_status_guard cung chan doi status PO
  -- khi _receiving_update_po_status cap nhat. Dat sau moi kiem tra
  -- quyen/PIN/SoD, truoc ghi dau tien (theo dung mau T-020).
  perform set_config('app.pr_po_guard_bypass', 'on', true);

  for v_line in
    select * from public.goods_receipt_lines
    where gr_id = p_gr_id
    order by created_at
  loop
    -- Dong QC fail: khong vao kho (phieu tra 'recorded' da sinh luc ghi).
    if v_line.qc_status = 'fail' then
      continue;
    end if;

    select pol.* into v_pol
    from public.purchase_order_lines pol
    where pol.id = v_line.po_line_id
    for update;

    if v_pol.id is null then
      continue;
    end if;

    v_remaining := v_pol.qty_stock - v_pol.received_qty_stock;
    v_cap := v_remaining * (1 + v_tol / 100);

    -- Cap ve so con mo tai luc post; dong co override thi khong cap.
    if v_line.override_by is not null then
      v_accepted := v_line.accepted_qty_stock;
    else
      v_accepted := least(v_line.accepted_qty_stock, greatest(v_cap, 0));
    end if;

    if v_accepted <= 0 then
      continue;
    end if;

    select i.* into v_item
    from public.items i
    where i.id = v_line.item_id and i.org_id = v_gr.org_id;

    -- Don gia theo UOM cua dong PO (xem chu thich o receiving_record_line).
    v_unit_cost := public._receiving_unit_cost_stock(
      v_gr.org_id, v_line.item_id, v_pol.uom, v_pol.unit_price);

    -- C8: gia nhap vuot TB 7 ngay + nguong -> alert PRICE_SPIKE
    -- (05 §2/§10, 08 §3: warn, App; nguong mac dinh 10% qua setting
    -- price_spike_pct). Chi bao, khong chan nhan hang. Kiem tra
    -- TRUOC khi post move cua dong nay de TB 7 ngay chi tinh gia
    -- nhan truoc do (loai move cua chinh phieu nay).
    perform public._check_price_spike(
      v_gr.property_id, v_gr.org_id, v_line.item_id, v_unit_cost,
      v_today, 'goods_receipt', p_gr_id
    );

    -- Lot: tim hoac tao (hang theo lot).
    v_lot_id := null;
    if v_item.track_lot then
      if v_line.lot_no is null or v_line.expiry_date is null then
        raise exception using errcode = 'P0001', message = 'ERR_LOT_REQUIRED';
      end if;

      insert into public.lots (org_id, property_id, item_id, lot_no, expiry_date)
      values (v_gr.org_id, v_gr.property_id, v_line.item_id,
        v_line.lot_no, v_line.expiry_date)
      on conflict (property_id, item_id, lot_no) do nothing
      returning id into v_lot_id;

      if v_lot_id is null then
        select l.id, l.expiry_date into v_lot_id, v_lot_expiry
        from public.lots l
        where l.property_id = v_gr.property_id
          and l.item_id = v_line.item_id
          and l.lot_no = v_line.lot_no;

        if v_lot_expiry is distinct from v_line.expiry_date then
          raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
        end if;
      end if;
    end if;

    -- Kho dich: QC conditional -> kho cach ly; binh thuong -> kho nhan.
    if v_line.qc_status = 'conditional' then
      v_target_wh := public._receiving_quarantine_wh(v_gr.property_id);
    else
      v_target_wh := v_gr.warehouse_id;
    end if;

    v_move_id := public._post_move(
      v_gr.legal_entity_id, v_gr.property_id, v_target_wh,
      v_line.item_id, v_lot_id, 'receipt', v_accepted, v_unit_cost,
      v_today, 'goods_receipt', p_gr_id, v_line.id);

    v_final_wh := v_target_wh;

    -- Nhan thang ra bep (chi dong pass): receipt + issue_out + issue_in.
    if v_gr.direct_issue_warehouse_id is not null
      and v_line.qc_status = 'pass' then
      v_move_id := public._post_move(
        v_gr.legal_entity_id, v_gr.property_id, v_target_wh,
        v_line.item_id, v_lot_id, 'issue_out', -v_accepted, null,
        v_today, 'goods_receipt', p_gr_id, v_line.id);

      select sm.unit_cost into v_out_cost
      from public.stock_moves sm
      where sm.id = v_move_id;

      perform public._post_move(
        v_gr.legal_entity_id, v_gr.property_id,
        v_gr.direct_issue_warehouse_id,
        v_line.item_id, v_lot_id, 'issue_in', v_accepted, v_out_cost,
        v_today, 'goods_receipt', p_gr_id, v_line.id);

      v_final_wh := v_gr.direct_issue_warehouse_id;
    end if;

    update public.goods_receipt_lines
    set accepted_qty_stock = v_accepted,
        unit_cost = v_unit_cost,
        lot_id = v_lot_id,
        posted_warehouse_id = v_final_wh,
        updated_at = now()
    where id = v_line.id;

    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock + v_accepted,
        updated_at = now()
    where id = v_pol.id;

    v_total := v_total + round(v_accepted * v_unit_cost, 2);
    v_posted_lines := v_posted_lines + 1;
  end loop;

  if v_posted_lines = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  update public.goods_receipts
  set status = 'posted',
      total_amount = round(v_total, 2),
      received_at = now(),
      updated_at = now()
  where id = p_gr_id;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object(
    'ok', true,
    'id', p_gr_id,
    'lines_posted', v_posted_lines
  );
end;
$function$;
