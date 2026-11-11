-- ============================================================================
-- T-040 follow-up fix (found by the pgTAP T-040 wave, 11/11/2026).
--
-- Q223 -- supplier_return_post never writes ap_ledger (-) for returned goods
--   that were invoiced: the (-) branch (340000) computes the invoiced qty
--   and the earliest approved invoice price with
--   `sil.gr_line_id = v_gr_line.id`, and writes the ledger row only when
--   v_invoiced_qty > 0. But gr_line_id is optional on supplier_invoice_lines
--   (nullable column; the invoice RPC + Zod + UI invoice-form.tsx:151 all
--   send grLineId null; invoice_match matches on po_line_id only) — so in
--   practice the predicate never matches and every return of invoiced goods
--   silently skips the (-) entry: the payable is never reduced and AP aging
--   is overstated. There is no UI workaround.
--   Fix: match invoice lines by PO line, falling back to the GR line only
--   when it is set:
--     sil.po_line_id = v_gr_line.po_line_id
--     and (sil.gr_line_id is null or sil.gr_line_id = v_gr_line.id)
--   at BOTH query sites (invoiced-qty sum and earliest-price lookup).
--   The per-GR-line prior-return cap (srl.gr_line_id = v_gr_line.id) is
--   kept as-is — supplier_return_lines always carry gr_line_id — as is the
--   approved/partially_paid/paid condition. Generated programmatically from
--   the current function text (340000); EXACTLY TWO lines differ. No change
--   to the function's contract, search_path, or grants (CREATE OR REPLACE
--   preserves the revoke/grant from 340000).
-- ============================================================================

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
  -- T-040: bien cho nhanh ap_ledger (-).
  v_invoiced_qty numeric;
  v_prev_returned numeric;
  v_ledger_qty numeric;
  v_inv_price numeric;
  v_inv_id uuid;
  v_ledger_due date;
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
  -- T-040: mo bypass finance de ghi ap_ledger (-) (neu co).
  perform set_config('app.finance_guard_bypass', 'on', true);

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

    -- T-040: ap_ledger (-) cho phan da co hoa don duyet (05 §8).
    -- Khong co hoa don duyet thi khong ghi (dung ghi chu T-023).
    select coalesce(sum(sil.qty), 0) into v_invoiced_qty
    from public.supplier_invoice_lines sil
    join public.supplier_invoices si on si.id = sil.invoice_id
    where sil.po_line_id = v_gr_line.po_line_id
      and (sil.gr_line_id is null or sil.gr_line_id = v_gr_line.id)
      and si.status in ('approved', 'partially_paid', 'paid');

    if v_invoiced_qty > 0 then
      -- So da tra truoc do (tru phieu tra hien tai) de khong tru
      -- trung cong no cua cung 1 so luong.
      select coalesce(sum(srl.qty_stock), 0) into v_prev_returned
      from public.supplier_return_lines srl
      join public.supplier_returns sr on sr.id = srl.return_id
      where srl.gr_line_id = v_gr_line.id
        and sr.status = 'posted'
        and sr.id <> v_ret_id;

      v_ledger_qty := least(
        v_qty, greatest(v_invoiced_qty - v_prev_returned, 0));
      if v_ledger_qty > 0 then
        -- Gia hoa don duyet som nhat cua dong GR nay.
        select sil.unit_price, si.id into v_inv_price, v_inv_id
        from public.supplier_invoice_lines sil
        join public.supplier_invoices si on si.id = sil.invoice_id
        where sil.po_line_id = v_gr_line.po_line_id
          and (sil.gr_line_id is null or sil.gr_line_id = v_gr_line.id)
          and si.status in ('approved', 'partially_paid', 'paid')
        order by si.invoice_date, si.created_at
        limit 1;

        -- Han tra goc (theo ap_ledger (+) cua hoa don do).
        select al.due_date into v_ledger_due
        from public.ap_ledger al
        where al.doc_type = 'supplier_invoice'
          and al.doc_id = v_inv_id
        order by al.entry_date desc
        limit 1;

        insert into public.ap_ledger (
          org_id, legal_entity_id, property_id, supplier_id,
          doc_type, doc_id, amount, due_date, entry_date
        ) values (
          v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
          v_gr.supplier_id,
          'supplier_return', v_ret_id,
          -v_ledger_qty * v_inv_price,
          coalesce(v_ledger_due, v_today), v_today
        );
      end if;
    end if;
  end loop;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object('ok', true, 'id', v_ret_id, 'doc_no', v_ret_no);
end;
$$;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109545000_return_invoiced_qty_po_line',
  'INSERT',
  jsonb_build_object('event', 't040_q223_fix', 'task', 'T-040'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
