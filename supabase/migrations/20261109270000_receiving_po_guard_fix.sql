-- ===========================================================================
-- 20261109270000_receiving_po_guard_fix.sql — FIX KHAN (T-023)
--
-- BUG THAT (phat hien bang pgTAP T-023 lan 6, 09/11 21:30-21:38, SQL Editor
-- project ERP_hotel): receiving_post + supplier_return_post + receiving_reverse
-- KHONG BAO GIO chay duoc tren production.
--
-- Nguyen nhan: migration 20261109210000 (T-020) gan trigger
-- _pr_po_write_guard len purchase_order_lines / purchase_request_lines /
-- approvals — moi ghi deu bi chan voi ERR_INVALID_STATUS neu
-- current_setting('app.pr_po_guard_bypass') <> 'on'. Mọi RPC cua T-020 deu
-- tu mo bypass dau ham (11 cho trong 210000). Nhung migration
-- 20261109230000 (T-023) chi mo 'app.receiving_guard_bypass' (8 cho) va
-- KHONG BAO GIO mo 'app.pr_po_guard_bypass', trong khi 3 ham sau ghi vao
-- purchase_order_lines:
--   * receiving_post        (230000:1423) — UPDATE received_qty_stock +=
--   * supplier_return_post  (230000:1724) — UPDATE received_qty_stock -=
--   * receiving_reverse     (230000:1802) — UPDATE received_qty_stock -=
-- Ca 3 ham con goi _receiving_update_po_status, ma ham nay UPDATE
-- purchase_orders.status — cung bi _pr_po_status_guard (210000) chan neu
-- thieu bypass. Mot lenh set_config duy nhat dau moi ham mo ca hai guard
-- vi set_config local=true co hieu luc trong toan bo transaction goi RPC.
--
-- Bang chung chay that (lan 6): receiving_post(gr1, '1234') loi
--   ERROR: P0001: ERR_INVALID_STATUS — _pr_po_write_guard() line 4
--   SQL statement "update public.purchase_order_lines set
--   received_qty_stock..." — receiving_post(uuid,text) line 205.
-- He qua: KHONG phieu nhan nao post duoc (phieu co dong duoc duyet thi rot
-- o UPDATE PO lines; phieu 0 dong duoc duyet thi rot o v_posted_lines = 0);
-- nut "ghi so" o UI mobile T-024 fail voi moi user.
--
-- FIX: CREATE OR REPLACE lai 3 ham voi body Y HET ban 230000, chi them
--   perform set_config('app.pr_po_guard_bypass', 'on', true);
-- ngay sau lenh mo receiving_guard_bypass cua moi ham (sau moi kiem tra
-- quyen/PIN/SoD, truoc ghi dau tien — theo dung mau pr_submit / po_send /
-- po_close trong 210000). KHONG doi chu ky ham, KHONG doi logic, KHONG
-- them quyen moi, KHONG sua file migration cu nao.
--
-- Kiem chung sau merge: db push --remote (ap 270000) roi chay lai suite
-- pgTAP T-023 (87 assertions) lan 7 — ky vong vuot qua buoc post_gr1.
-- ===========================================================================

create or replace function public.receiving_post(
  p_gr_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

  -- PIN kiem truoc khi cham den ton kho.
  perform public._verify_pin(p_pin);

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

  if v_att_count = 0 then
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
$$;

create or replace function public.supplier_return_post(
  p_gr_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_el jsonb;
  v_gr_line record;
  v_pol record;
  v_returnable numeric;
  v_qty numeric;
  v_ret_id uuid;
  v_ret_no text;
  v_ret_line_id uuid;
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

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);
  -- Mo bypass T-020 (210000): _pr_po_write_guard chan moi ghi vao
  -- purchase_order_lines; _pr_po_status_guard cung chan doi status PO
  -- khi _receiving_update_po_status cap nhat. Dat sau moi kiem tra
  -- quyen/PIN/SoD, truoc ghi dau tien (theo dung mau T-020).
  perform set_config('app.pr_po_guard_bypass', 'on', true);

  v_ret_no := public.next_doc_no(v_gr.legal_entity_id, 'SRT', v_today);

  insert into public.supplier_returns (
    org_id, legal_entity_id, property_id, gr_id, po_id, supplier_id,
    doc_no, status, reason
  ) values (
    v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
    p_gr_id, v_gr.po_id, v_gr.supplier_id,
    v_ret_no, 'posted', p_lines -> 0 ->> 'reason'
  ) returning id into v_ret_id;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    v_qty := (v_el ->> 'qty_stock')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    select grl.* into v_gr_line
    from public.goods_receipt_lines grl
    where grl.id = (v_el ->> 'gr_line_id')::uuid
      and grl.gr_id = p_gr_id;

    -- Dong QC fail khong vao kho nen khong tra bang RPC nay.
    if v_gr_line.id is null or v_gr_line.qc_status = 'fail'
      or v_gr_line.posted_warehouse_id is null
      or v_gr_line.unit_cost is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    -- So tra toi da = da nhan - da tra (phieu tra da post).
    v_returnable := v_gr_line.accepted_qty_stock
      - public._receiving_returned_qty(v_gr_line.id);
    if v_qty > v_returnable then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    insert into public.supplier_return_lines (
      return_id, org_id, gr_line_id, item_id, qty_stock, unit_cost,
      reason, photo_ids, supplier_signature_path
    ) values (
      v_ret_id, v_gr.org_id, v_gr_line.id, v_gr_line.item_id, v_qty,
      v_gr_line.unit_cost,
      v_el ->> 'reason',
      coalesce(
        (select array_agg(x::uuid)
         from jsonb_array_elements_text(
           coalesce(v_el -> 'photo_ids', '[]'::jsonb)) x),
        '{}'),
      v_el ->> 'supplier_signature_path'
    ) returning id into v_ret_line_id;

    perform public._post_move(
      v_gr.legal_entity_id, v_gr.property_id,
      v_gr_line.posted_warehouse_id,
      v_gr_line.item_id, v_gr_line.lot_id, 'return_out', -v_qty,
      v_gr_line.unit_cost, v_today, 'supplier_return', v_ret_id,
      v_ret_line_id);

    select pol.* into v_pol
    from public.purchase_order_lines pol
    where pol.id = v_gr_line.po_line_id
    for update;

    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock - v_qty,
        updated_at = now()
    where id = v_pol.id;
  end loop;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object('ok', true, 'id', v_ret_id, 'doc_no', v_ret_no);
end;
$$;

create or replace function public.receiving_reverse(
  p_gr_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_move record;
  v_line record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.reverse');

  if v_gr.status = 'reversed' then
    raise exception using errcode = 'P0001', message = 'ERR_ALREADY_REVERSED';
  end if;

  if v_gr.status <> 'posted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  if exists (
    select 1 from public.supplier_returns sr
    where sr.gr_id = p_gr_id and sr.status = 'posted'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);
  -- Mo bypass T-020 (210000): _pr_po_write_guard chan moi ghi vao
  -- purchase_order_lines; _pr_po_status_guard cung chan doi status PO
  -- khi _receiving_update_po_status cap nhat. Dat sau moi kiem tra
  -- quyen/PIN/SoD, truoc ghi dau tien (theo dung mau T-020).
  perform set_config('app.pr_po_guard_bypass', 'on', true);

  for v_move in
    select * from public.stock_moves sm
    where sm.doc_type = 'goods_receipt' and sm.doc_id = p_gr_id
    order by sm.id desc
  loop
    perform public._post_move(
      v_move.legal_entity_id, v_move.property_id, v_move.warehouse_id,
      v_move.item_id, v_move.lot_id, 'reversal', -v_move.qty, null,
      v_today, 'goods_receipt', p_gr_id, v_move.line_id,
      null, null, null, v_move.id);
  end loop;

  for v_line in
    select * from public.goods_receipt_lines
    where gr_id = p_gr_id
      and accepted_qty_stock > 0
      and posted_warehouse_id is not null
  loop
    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock - v_line.accepted_qty_stock,
        updated_at = now()
    where id = v_line.po_line_id;
  end loop;

  update public.goods_receipts
  set status = 'reversed',
      reversed_by = auth.uid(),
      reversed_at = now(),
      reverse_reason = p_reason,
      updated_at = now()
  where id = p_gr_id;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object('ok', true, 'id', p_gr_id);
end;
$$;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109270000_receiving_po_guard_fix',
  'INSERT',
  jsonb_build_object('event', 'receiving_po_guard_fix', 'task', 'T-023'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
