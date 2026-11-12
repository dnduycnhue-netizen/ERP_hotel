-- ============================================================================
-- Q242 — 20261109563000_sod_invoice_gr_payment_approver
--   Thuc thi 2 quy tac SoD co trong dac ta (docs/04-SECURITY-RLS.md §6) nhung
--   chua tung duoc code kiem tra (Q241 ra soat; Duy chot 12/11/2026 la thuc thi):
--     * SOD_INVOICE_GR: nguoi nhap hoa don != nguoi nhan hang. Chan o
--       invoice_match -> ERR_SOD_INVOICE_GR.
--     * SOD_PAYMENT_APPROVER: nguoi duyet thanh toan != nguoi nhap hoa don
--       trong de nghi != nguoi yeu cau doi STK NCC trong 30 ngay. Chan o
--       payment_request_decide (chi khi duyet) -> ERR_SOD_PAYMENT_APPROVER.
--   Ca hai cho qua neu co sod_exceptions con han (alert SOD_EXCEPTION_USED),
--   theo co che _sod_check hien co.
--   Ham moi _sod_check_user(property, rule, user): nhu _sod_check nhung tra
--   ngoai le theo user chi dinh (dung khi nguoi vi pham khong phai nguoi goi,
--   vd nguoi nhap hoa don khac nguoi bam khop). _sod_check KHONG doi.
--   invoice_match / payment_request_decide sinh lai NGUYEN VAN tu ban cuoi
--   (350000 / 340000), chi chen 1 khoi kiem tra moi. Grant giu nguyen.
-- ============================================================================
create or replace function public._sod_check_user(
  p_property_id uuid,
  p_rule_code text,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if exists (
    select 1
    from public.sod_exceptions e
    where e.property_id = p_property_id
      and e.user_id = p_user_id
      and e.rule_code = p_rule_code
      and e.valid_to >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
  ) then
    perform public._create_alert(
      p_property_id,
      'SOD_EXCEPTION_USED',
      'warn',
      'Đã dùng ngoại lệ tách biệt nhiệm vụ',
      jsonb_build_object('rule_code', p_rule_code, 'user_id', p_user_id)
    );
    return;
  end if;
  raise exception 'ERR_%', p_rule_code;
end;
$$;

revoke all on function public._sod_check_user(uuid, text, uuid)
  from public, anon, authenticated;

create or replace function public.invoice_match(
  p_invoice_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_inv record;
  v_tol_pct numeric;
  v_line record;
  v_pol record;
  v_po_qty numeric;
  v_received numeric;
  v_invoiced_other numeric;
  v_inv_qty_for_po numeric;
  v_available numeric;
  v_qty_ok boolean;
  v_price_ok boolean;
  v_diff_pct numeric;
  v_po_kind text;
  v_all_ok boolean := true;
  v_results jsonb := '[]'::jsonb;
begin
  select * into v_inv from public.supplier_invoices where id = p_invoice_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_inv.property_id, 'invoice.manage');
  if v_inv.status not in ('draft', 'on_hold') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- SOD_INVOICE_GR (04 §6): nguoi nhap hoa don khong duoc la nguoi nhan
  -- hang cua chinh cac dong PO ma hoa don nay doi chieu. Kiem tra theo NGUOI
  -- NHAP HOA DON (created_by), khong theo nguoi bam khop, de nguoi khac bam
  -- khop ho cung khong lach duoc. PO dich vu khong co phieu nhan nen khong
  -- bi anh huong (dung nghiem thu thay phieu nhan).
  if v_inv.created_by is not null and exists (
    select 1
    from public.supplier_invoice_lines sil
    join public.goods_receipt_lines grl on grl.po_line_id = sil.po_line_id
    join public.goods_receipts gr on gr.id = grl.gr_id
    where sil.invoice_id = p_invoice_id
      and gr.status = 'posted'
      and gr.receiver_id = v_inv.created_by
  ) then
    perform public._sod_check_user(
      v_inv.property_id, 'SOD_INVOICE_GR', v_inv.created_by);
  end if;

  v_tol_pct := ((public._setting_get(
    v_inv.org_id, v_inv.property_id, 'invoice_price_tolerance_pct'
  ))::text)::numeric;

  perform set_config('app.finance_guard_bypass', 'on', true);

  for v_line in
    select * from public.supplier_invoice_lines
    where invoice_id = p_invoice_id
    order by created_at, id
  loop
    select * into v_pol
    from public.purchase_order_lines where id = v_line.po_line_id;

    v_po_qty := coalesce(v_pol.qty_stock, v_pol.qty);

    -- T-042 (Q72): PO dich vu — so nhan thay bang nghiem thu (05 §8/§9).
    -- Chua nghiem thu -> chan han ERR_SERVICE_NOT_ACCEPTED; da nghiem
    -- thu thi so nhan = so luong PO (nghiem thu theo PO, khong theo GR).
    select kind into v_po_kind
    from public.purchase_orders where id = v_pol.po_id;
    if v_po_kind = 'service' then
      if not public._service_po_accepted(v_pol.po_id, v_inv.invoice_date) then
        raise exception using errcode = 'P0001', message = 'ERR_SERVICE_NOT_ACCEPTED';
      end if;
      v_received := v_po_qty;
    else
      -- So da nhan: tong accepted_qty_stock cua GR da 'posted'.
      select coalesce(sum(grl.accepted_qty_stock), 0) into v_received
      from public.goods_receipt_lines grl
      join public.goods_receipts gr on gr.id = grl.gr_id
      where grl.po_line_id = v_pol.id
        and gr.status = 'posted';
    end if;

    -- So da hoa don o hoa don KHAC (chua huy, da khop tro di).
    select coalesce(sum(sil.qty), 0) into v_invoiced_other
    from public.supplier_invoice_lines sil
    join public.supplier_invoices si on si.id = sil.invoice_id
    where sil.po_line_id = v_pol.id
      and sil.invoice_id <> p_invoice_id
      and si.status in ('matched', 'approved', 'partially_paid', 'paid');

    -- Tong so luong hoa don NAY cho cung dong PO (phieu co the co 2
    -- dong trung po_line_id).
    select coalesce(sum(qty), 0) into v_inv_qty_for_po
    from public.supplier_invoice_lines
    where invoice_id = p_invoice_id
      and po_line_id = v_pol.id;

    v_available := v_received - v_invoiced_other;
    v_qty_ok := (v_inv_qty_for_po <= v_available);

    if v_pol.unit_price = 0 then
      v_price_ok := (v_line.unit_price = 0);
      v_diff_pct := case when v_line.unit_price = 0 then 0 else null end;
    else
      v_diff_pct := round(
        abs(v_line.unit_price - v_pol.unit_price) / v_pol.unit_price * 100, 4);
      v_price_ok := (v_diff_pct <= v_tol_pct);
    end if;

    if not (v_qty_ok and v_price_ok) then
      v_all_ok := false;
    end if;

    update public.supplier_invoice_lines
    set match_result = jsonb_build_object(
      'qty_ok', v_qty_ok,
      'price_ok', v_price_ok,
      'po_qty', v_po_qty,
      'received_qty', v_received,
      'available_qty', v_available,
      'already_invoiced_qty', v_invoiced_other,
      'invoice_qty_for_po_line', v_inv_qty_for_po,
      'po_unit_price', v_pol.unit_price,
      'invoice_unit_price', v_line.unit_price,
      'price_diff_pct', v_diff_pct,
      'tolerance_pct', v_tol_pct,
      'reason', case
        when not v_qty_ok then 'QTY_OVER_RECEIVED'
        when not v_price_ok then 'PRICE_OVER_TOLERANCE'
        else null end
    )
    where id = v_line.id;

    v_results := v_results || jsonb_build_object(
      'line_id', v_line.id,
      'po_line_id', v_pol.id,
      'qty_ok', v_qty_ok,
      'price_ok', v_price_ok,
      'reason', case
        when not v_qty_ok then 'QTY_OVER_RECEIVED'
        when not v_price_ok then 'PRICE_OVER_TOLERANCE'
        else null end
    );
  end loop;

  update public.supplier_invoices
  set status = case when v_all_ok then 'matched' else 'on_hold' end,
      updated_at = now()
  where id = p_invoice_id;

  return jsonb_build_object(
    'ok', true, 'id', p_invoice_id,
    'status', case when v_all_ok then 'matched' else 'on_hold' end,
    'lines', v_results
  );
end;
$$;

create or replace function public.payment_request_decide(
  p_property_id uuid,
  p_request_id uuid,
  p_decision text,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req record;
  v_step public.approvals%rowtype;
  v_pending integer;
  v_new_status text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_req
  from public.payment_requests where id = p_request_id;
  if not found or v_req.property_id <> p_property_id then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if v_req.status <> 'submitted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select * into v_step
  from public.approvals a
  where a.doc_type = 'payment_request'
    and a.doc_id = p_request_id
    and a.decision = 'pending'
  order by a.step asc
  limit 1;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(p_property_id, v_step.required_perm);

  if not public._approval_can_decide(p_property_id, v_step.id) then
    raise exception using errcode = 'P0001', message = 'ERR_NOT_APPROVER';
  end if;

  if v_req.created_by = auth.uid() then
    perform public._sod_check(p_property_id, 'SOD_PAYMENT_CREATOR_APPROVER');
  end if;

  -- SOD_PAYMENT_APPROVER (04 §6): nguoi DUYET thanh toan khong duoc la (a)
  -- nguoi nhap bat ky hoa don nao trong de nghi, cung khong duoc la (b) nguoi
  -- da yeu cau doi STK cua NCC nay trong 30 ngay gan nhat. Chi ap dung khi
  -- duyet (approved); tu choi khong gay rui ro nen khong chan.
  if p_decision = 'approved' and (
    exists (
      select 1
      from public.payment_request_lines prl
      join public.supplier_invoices si
        on si.id = prl.invoice_id and si.org_id = prl.org_id
      where prl.request_id = p_request_id
        and si.created_by = auth.uid()
    )
    or exists (
      select 1
      from public.supplier_bank_accounts b
      where b.supplier_id = v_req.supplier_id
        and b.org_id = v_req.org_id
        and b.requested_by = auth.uid()
        and b.created_at >= now() - interval '30 days'
    )
  ) then
    perform public._sod_check(p_property_id, 'SOD_PAYMENT_APPROVER');
  end if;

  if p_decision = 'rejected'
    and (p_comment is null or btrim(p_comment) = '') then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.approvals a
  set decision = p_decision,
      comment = p_comment,
      decided_by = auth.uid(),
      decided_at = now(),
      delegated_from = case
        when auth.uid() <> coalesce(v_step.approver_user_id, auth.uid())
          and v_step.approver_user_id is not null
        then v_step.approver_user_id
        else (
          select d.from_user
          from public.approval_delegations d
          where d.org_id = v_step.org_id
            and d.to_user = auth.uid()
            and (d.property_id is null or d.property_id = p_property_id)
            and (now() at time zone 'Asia/Ho_Chi_Minh')::date
              between d.valid_from and d.valid_to
          order by d.valid_from desc
          limit 1
        )
      end
  where a.id = v_step.id;

  if p_decision = 'rejected' then
    v_new_status := 'cancelled';
  else
    select count(*) into v_pending
    from public.approvals a
    where a.doc_type = 'payment_request'
      and a.doc_id = p_request_id
      and a.decision = 'pending';
    v_new_status := case when v_pending = 0 then 'approved' else 'submitted' end;
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);
  update public.payment_requests
  set status = v_new_status, updated_at = now()
  where id = p_request_id;

  return jsonb_build_object(
    'ok', true, 'id', p_request_id, 'status', v_new_status
  );
end;
$$;
