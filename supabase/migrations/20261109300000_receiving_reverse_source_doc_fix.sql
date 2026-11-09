-- Migration 20261109300000 — fix receiving_reverse: dung ten cot that cua stock_moves.
--
-- BUG (phat hien boi pgTAP T-023 lan 8, 22:12-22:16 09/11/2026):
--   receiving_reverse(gr5) roi 42703 o vong FOR qua stock_moves:
--   "column sm.doc_type does not exist" (PL/pgSQL line 44).
--   Bang stock_moves (110000, T-011) KHONG co doc_type/doc_id; cot that la
--   move_type / source_doc_type / source_doc_id (_post_move nhan p_doc_type/
--   p_doc_id nhung luu vao source_doc_type/source_doc_id). He qua: MOI lan
--   dao nguoc phieu nhan tren production deu fail.
--   Loi nay co o ca 230000 (dinh nghia goc) VA 270000 (fix guard, copy
--   nguyen than ham) — migration nay redefine ham dang live (ban 270000).
--
-- Sua 3 cho trong than ham, giu nguyen moi thu khac (ke ca dong mo
--   app.pr_po_guard_bypass cua 270000 — KHONG duoc mat, neu khong se
--   hoi quy ve loi ERR_INVALID_STATUS cua fix guard):
--   1. sm.doc_type        -> sm.source_doc_type
--   2. sm.doc_id          -> sm.source_doc_id
--   3. v_move.line_id     -> v_move.source_line_id  (stock_moves khong co
--      cot line_id; cot that la source_line_id — _post_move map p_line_id
--      vao source_line_id. Day la bug an thu 2 trong cung ham: sua xong
--      (1)/(2), vong lap se roi tiep o day voi 42703 neu khong sua.)
--
-- Cac cho doc_type/doc_id khac trong 230000 (attachments/approvals) la
-- dung, khong dung den. Khong doi UI, khong quyen moi.

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
    where sm.source_doc_type = 'goods_receipt' and sm.source_doc_id = p_gr_id
    order by sm.id desc
  loop
    perform public._post_move(
      v_move.legal_entity_id, v_move.property_id, v_move.warehouse_id,
      v_move.item_id, v_move.lot_id, 'reversal', -v_move.qty, null,
      v_today, 'goods_receipt', p_gr_id, v_move.source_line_id,
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
