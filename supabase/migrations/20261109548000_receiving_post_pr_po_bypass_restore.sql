-- Q225 (11/11/2026): migration 537000 (rule toggles R25/R18/R32) da
-- CREATE OR REPLACE receiving_post tu ban TRUOC migration 270000
-- (receiving_po_guard_fix) nen lam mat dong mo bypass
--   perform set_config('app.pr_po_guard_bypass', 'on', true);
-- ma 270000 da them (sau moi kiem tra quyen/PIN/SoD, truoc ghi dau tien).
-- Ket qua: moi receiving_post cap nhat purchase_order_lines.received_qty_stock
-- deu bi trigger _pr_po_write_guard() chan (ERR_INVALID_STATUS) — nhan hang
-- chet hoan toan tren production tu luc 537000 duoc db push (~17:00 11/11).
-- Chung co live: toggle test R18 TAT abort dung loi nay o receiving_post line 219.
-- Fix: CREATE OR REPLACE receiving_post y het ban 537000, CHI them lai 5 dong
-- bypass (comment + set_config) dung vi tri 270000. supplier_return_post va
-- receiving_reverse khong bi anh huong (537000 khong dinh nghia lai 2 ham do,
-- bypass 270000 cua chung van con). Khong doi contract/search_path/quyen.
-- Sau db push: chay lai toan bo toggle test (ky vong 21/21) + T-023 (87/87).

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
$$;
