-- T-043: Xuat Excel cho ke toan — 5 RPC SECURITY DEFINER.
--
-- Tai sao can RPC (thay vi doc truc tiep qua RLS nhu cac man hinh):
-- `export.accounting` trong seed chi gan cho `chief_accountant`, nhung
-- policy SELECT cua `goods_receipts` (can `receiving.view`),
-- `advances`/`advance_settlements` (can `advance.*`) va `profiles`
-- (chi doc duoc chinh minh / admin) deu chan vai tro nay. Doc truc tiep
-- qua client se tra 0 dong cho 3/5 loai xuat. Tien le trong repo:
-- `advance_list` / `pr_list` / `count_list_counters` — RPC SECURITY
-- DEFINER kiem tra quyen ben trong roi tra du lieu.
-- Khong co permission code moi: tai dung `export.accounting` (catalog
-- 141000, seed da gan cho `chief_accountant`).
--
-- Quy tac khoa so (05 §10, roadmap T-043): chi xuat du lieu thuoc ky da
-- khoa (`accounting_periods` status='closed') HOAC ngay da khoa
-- (`day_locks`). Quyet dinh ap dung (xem Q82):
--  - Tai chinh (hoa don / cong no / tam ung): khong co kho/ngay khoa
--    rieng, chi xet ky da khoa theo thang cua ngay.
--  - Kho (nhap kho / xuat kho): ngay duoc coi la khoa neu ky cua thang
--    do da khoa, HOAC moi kho co phat sinh trong ngay do deu co
--    `day_locks` (bat ky ca nao — `day_lock` thuc te luon goi khong ca).
--  - Ngay khong co phat sinh nao thi khong can khoa (khong co du lieu
--    can bao ve) — khong chan ca khoang xuat vi 1 ngay trong.
-- Neu khoang ngay con ngay chua khoa -> raise ERR_EXPORT_NOT_LOCKED
-- kem danh sach ngay (toi da 10, dinh dang dd/mm/yyyy).
--
-- Dinh dang so: tien numeric(18,2), so luong numeric(18,4) — tra ve
-- jsonb nen giu nguyen kieu so (khong ep text) de lop xlsx ghi dung so
-- Excel that.
-- Khong sua migration cu, khong doi CHANGELOG.

-- ---------------------------------------------------------------------------
-- Helper noi bo: tra ve mang cac ngay trong [p_from, p_to] CHUA duoc khoa.
-- p_scope: 'goods_receipts' | 'stock_moves' | 'finance'.
-- Khong grant execute (chi RPC export goi duoc).
-- ---------------------------------------------------------------------------
create or replace function public._export_unlocked_dates(
  p_entity_id uuid,
  p_property_id uuid,
  p_from date,
  p_to date,
  p_scope text
)
returns date[]
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_d date;
  v_covered boolean;
  v_unlocked date[] := '{}'::date[];
begin
  for v_d in
    select generate_series(p_from, p_to, interval '1 day')::date
  loop
    -- Ky cua thang do da khoa?
    select exists (
      select 1
      from public.accounting_periods ap
      where ap.legal_entity_id = p_entity_id
        and ap.year = extract(year from v_d)::integer
        and ap.month = extract(month from v_d)::integer
        and ap.status = 'closed'
    ) into v_covered;

    -- Kho: neu ky chua khoa, ngay van duoc neu moi kho co phat sinh
    -- trong ngay deu co day_locks.
    if not v_covered and p_scope in ('goods_receipts', 'stock_moves') then
      select not exists (
        select 1
        from public.warehouses w
        where w.property_id = p_property_id
          and (
            (p_scope = 'goods_receipts' and exists (
              select 1
              from public.goods_receipts gr
              where gr.warehouse_id = w.id
                and gr.status = 'posted'
                and (gr.received_at at time zone 'Asia/Ho_Chi_Minh')::date = v_d
            ))
            or (p_scope = 'stock_moves' and exists (
              select 1
              from public.stock_moves sm
              where sm.warehouse_id = w.id
                and sm.business_date = v_d
                and sm.move_type in (
                  'issue_out', 'transfer_out', 'purpose_issue', 'waste',
                  'return_out', 'minibar_sale', 'production_out', 'merge_out',
                  'reversal'
                )
            ))
          )
          and not exists (
            select 1
            from public.day_locks dl
            where dl.warehouse_id = w.id
              and dl.business_date = v_d
          )
      ) into v_covered;
    end if;

    if not v_covered then
      v_unlocked := v_unlocked || v_d;
    end if;
  end loop;

  return v_unlocked;
end;
$$;

revoke all on function public._export_unlocked_dates(uuid, uuid, date, date, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helper noi bo: kiem tra dau vao + quyen, tra ve property_id cua phap nhan.
-- Phap nhan khong ton tai hoac khong thay property -> 42501 (khong lo
-- thong tin ton tai). Thieu quyen `export.accounting` -> require_perm
-- raise 42501 ERR_FORBIDDEN:export.accounting.
-- ---------------------------------------------------------------------------
create or replace function public._export_require(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_legal_entity_id is null
    or p_from is null
    or p_to is null
    or not isfinite(p_from)
    or not isfinite(p_to)
    or p_from > p_to
    or (p_to - p_from) > 366
  then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  select id into v_property_id
  from public.properties
  where legal_entity_id = p_legal_entity_id;

  if not found then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  perform public.require_perm(v_property_id, 'export.accounting');

  return v_property_id;
end;
$$;

revoke all on function public._export_require(uuid, date, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helper noi bo: raise ERR_EXPORT_NOT_LOCKED neu con ngay chua khoa.
-- ---------------------------------------------------------------------------
create or replace function public._export_assert_locked(
  p_entity_id uuid,
  p_property_id uuid,
  p_from date,
  p_to date,
  p_scope text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_unlocked date[];
  v_list text;
  v_total integer;
begin
  v_unlocked := public._export_unlocked_dates(
    p_entity_id, p_property_id, p_from, p_to, p_scope
  );
  v_total := coalesce(array_length(v_unlocked, 1), 0);
  if v_total = 0 then
    return;
  end if;

  select string_agg(to_char(d, 'DD/MM/YYYY'), ', ')
  into v_list
  from (select unnest(v_unlocked) as d order by 1 limit 10) s;

  if v_total > 10 then
    v_list := v_list || format(' và %s ngày khác', v_total - 10);
  end if;

  raise exception using errcode = 'P0001',
    message = format('ERR_EXPORT_NOT_LOCKED: %s', v_list);
end;
$$;

revoke all on function public._export_assert_locked(uuid, uuid, date, date, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. Nhap kho: phieu nhan da posted + dong (so luong thuc nhan).
-- ---------------------------------------------------------------------------
create or replace function public.export_goods_receipts(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_entity record;
  v_rows jsonb;
  v_total_amount numeric(18, 2);
  v_count integer;
begin
  v_property_id := public._export_require(p_legal_entity_id, p_from, p_to);
  select id, code, name into v_entity
  from public.legal_entities where id = p_legal_entity_id;

  perform public._export_assert_locked(
    p_legal_entity_id, v_property_id, p_from, p_to, 'goods_receipts'
  );

  select
    coalesce(jsonb_agg(r order by r.received_date, r.doc_no, r.item_code), '[]'::jsonb),
    coalesce(sum(r.amount), 0),
    count(*)
  into v_rows, v_total_amount, v_count
  from (
    select
      (gr.received_at at time zone 'Asia/Ho_Chi_Minh')::date::text as received_date,
      gr.doc_no,
      gr.status,
      s.code as supplier_code,
      s.name as supplier_name,
      w.code as warehouse_code,
      w.name as warehouse_name,
      i.code as item_code,
      i.name as item_name,
      grl.uom,
      grl.accepted_qty_stock as qty,
      grl.unit_cost,
      round(grl.accepted_qty_stock * coalesce(grl.unit_cost, 0), 2)::numeric(18, 2) as amount
    from public.goods_receipts gr
    join public.goods_receipt_lines grl on grl.gr_id = gr.id
    left join public.suppliers s on s.id = gr.supplier_id
    join public.warehouses w on w.id = gr.warehouse_id
    join public.items i on i.id = grl.item_id
    where gr.legal_entity_id = p_legal_entity_id
      and gr.status = 'posted'
      and (gr.received_at at time zone 'Asia/Ho_Chi_Minh')::date between p_from and p_to
  ) r;

  return jsonb_build_object(
    'ok', true,
    'entity', jsonb_build_object('id', v_entity.id, 'code', v_entity.code, 'name', v_entity.name),
    'property_id', v_property_id,
    'from', p_from::text,
    'to', p_to::text,
    'exported_at', now(),
    'exported_by', auth.uid(),
    'rows', v_rows,
    'totals', jsonb_build_object('count', v_count, 'amount', v_total_amount)
  );
end;
$$;

revoke all on function public.export_goods_receipts(uuid, date, date)
  from public, anon;
grant execute on function public.export_goods_receipts(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Xuat kho: cac move xuat (linh / dieu chuyen / xuat muc dich / huy /
--    tra NCC / ban minibar / san xuat / gop ma / dao but toan).
-- ---------------------------------------------------------------------------
create or replace function public.export_stock_issues(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_entity record;
  v_rows jsonb;
  v_total_amount numeric(18, 2);
  v_count integer;
begin
  v_property_id := public._export_require(p_legal_entity_id, p_from, p_to);
  select id, code, name into v_entity
  from public.legal_entities where id = p_legal_entity_id;

  perform public._export_assert_locked(
    p_legal_entity_id, v_property_id, p_from, p_to, 'stock_moves'
  );

  select
    coalesce(jsonb_agg(r order by r.business_date, r.move_type, r.doc_no, r.item_code), '[]'::jsonb),
    coalesce(sum(r.amount), 0),
    count(*)
  into v_rows, v_total_amount, v_count
  from (
    select
      sm.business_date::text as business_date,
      sm.move_type,
      sm.source_doc_type,
      coalesce(
        rq.doc_no, tr.doc_no, pi.doc_no, wr.doc_no, sr.doc_no,
        gr.doc_no, mc.doc_no, sc.doc_no
      ) as doc_no,
      w.code as warehouse_code,
      w.name as warehouse_name,
      tw.code as to_warehouse_code,
      tw.name as to_warehouse_name,
      i.code as item_code,
      i.name as item_name,
      i.stock_uom as uom,
      sm.qty,
      sm.unit_cost,
      sm.amount,
      cc.code as cost_center_code,
      cc.name as cost_center_name,
      ec.code as expense_category_code,
      ec.name as expense_category_name,
      sm.purpose_code
    from public.stock_moves sm
    join public.warehouses w on w.id = sm.warehouse_id
    join public.items i on i.id = sm.item_id
    left join public.requisitions rq
      on sm.source_doc_type = 'requisition' and sm.source_doc_id = rq.id
    left join public.transfers tr
      on sm.source_doc_type = 'transfer' and sm.source_doc_id = tr.id
    left join public.warehouses tw on tw.id = tr.to_warehouse_id
    left join public.purpose_issues pi
      on sm.source_doc_type = 'purpose_issue' and sm.source_doc_id = pi.id
    left join public.waste_reports wr
      on sm.source_doc_type = 'waste' and sm.source_doc_id = wr.id
    left join public.supplier_returns sr
      on sm.source_doc_type = 'supplier_return' and sm.source_doc_id = sr.id
    left join public.goods_receipts gr
      on sm.source_doc_type = 'goods_receipt' and sm.source_doc_id = gr.id
    left join public.minibar_checks mc
      on sm.source_doc_type = 'minibar_check' and sm.source_doc_id = mc.id
    left join public.stock_counts sc
      on sm.source_doc_type = 'stock_count' and sm.source_doc_id = sc.id
    left join public.cost_centers cc on cc.id = sm.cost_center_id
    left join public.expense_categories ec on ec.id = sm.expense_category_id
    where sm.legal_entity_id = p_legal_entity_id
      and sm.business_date between p_from and p_to
      and sm.move_type in (
        'issue_out', 'transfer_out', 'purpose_issue', 'waste',
        'return_out', 'minibar_sale', 'production_out', 'merge_out',
        'reversal'
      )
  ) r;

  return jsonb_build_object(
    'ok', true,
    'entity', jsonb_build_object('id', v_entity.id, 'code', v_entity.code, 'name', v_entity.name),
    'property_id', v_property_id,
    'from', p_from::text,
    'to', p_to::text,
    'exported_at', now(),
    'exported_by', auth.uid(),
    'rows', v_rows,
    'totals', jsonb_build_object('count', v_count, 'amount', v_total_amount)
  );
end;
$$;

revoke all on function public.export_stock_issues(uuid, date, date)
  from public, anon;
grant execute on function public.export_stock_issues(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Hoa don mua: hoa don (tru da huy) + dong theo PO/GR.
-- ---------------------------------------------------------------------------
create or replace function public.export_invoices(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_entity record;
  v_rows jsonb;
  v_total_amount numeric(18, 2);
  v_total_vat numeric(18, 2);
  v_count integer;
begin
  v_property_id := public._export_require(p_legal_entity_id, p_from, p_to);
  select id, code, name into v_entity
  from public.legal_entities where id = p_legal_entity_id;

  perform public._export_assert_locked(
    p_legal_entity_id, v_property_id, p_from, p_to, 'finance'
  );

  select
    coalesce(jsonb_agg(r order by r.invoice_date, r.doc_no, r.item_code), '[]'::jsonb),
    coalesce(sum(r.amount), 0),
    coalesce(sum(r.vat_amount), 0),
    count(*)
  into v_rows, v_total_amount, v_total_vat, v_count
  from (
    select
      si.invoice_date::text as invoice_date,
      si.invoice_symbol,
      si.invoice_no,
      si.doc_no,
      si.status,
      s.code as supplier_code,
      s.name as supplier_name,
      po.doc_no as po_doc_no,
      i.code as item_code,
      i.name as item_name,
      sil.qty,
      sil.unit_price,
      sil.amount,
      sil.vat_rate,
      sil.vat_amount,
      sil.match_result ->> 'reason' as match_reason,
      (sil.match_result ->> 'price_diff_pct')::numeric as price_diff_pct
    from public.supplier_invoices si
    join public.supplier_invoice_lines sil on sil.invoice_id = si.id
    left join public.suppliers s on s.id = si.supplier_id
    left join public.purchase_order_lines pol on pol.id = sil.po_line_id
    left join public.purchase_orders po on po.id = pol.po_id
    left join public.items i on i.id = sil.item_id
    where si.legal_entity_id = p_legal_entity_id
      and si.invoice_date between p_from and p_to
      and si.status <> 'cancelled'
  ) r;

  return jsonb_build_object(
    'ok', true,
    'entity', jsonb_build_object('id', v_entity.id, 'code', v_entity.code, 'name', v_entity.name),
    'property_id', v_property_id,
    'from', p_from::text,
    'to', p_to::text,
    'exported_at', now(),
    'exported_by', auth.uid(),
    'rows', v_rows,
    'totals', jsonb_build_object('count', v_count, 'amount', v_total_amount, 'vat_amount', v_total_vat)
  );
end;
$$;

revoke all on function public.export_invoices(uuid, date, date)
  from public, anon;
grant execute on function public.export_invoices(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Cong no: tuoi no theo NCC tai thoi diem `to` (snapshot) — giong
--    thuat toan `getApAging` cua T-041 (FIFO tien da tra vao khoan co
--    han tra som nhat, nhom theo so ngay qua han tinh tu `due_date`,
--    khoan chua co han tra tinh theo `entry_date`).
--    Chi tinh cac but toan co entry_date <= p_to; chi xuat NCC con no.
-- ---------------------------------------------------------------------------
create or replace function public.export_payables(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_entity record;
  v_rows jsonb;
  v_total_payable numeric(18, 2);
  v_total_paid numeric(18, 2);
  v_total_balance numeric(18, 2);
  v_count integer;
begin
  v_property_id := public._export_require(p_legal_entity_id, p_from, p_to);
  select id, code, name into v_entity
  from public.legal_entities where id = p_legal_entity_id;

  perform public._export_assert_locked(
    p_legal_entity_id, v_property_id, p_from, p_to, 'finance'
  );

  with ledger as (
    select supplier_id, due_date, entry_date, amount
    from public.ap_ledger
    where legal_entity_id = p_legal_entity_id
      and entry_date <= p_to
  ),
  paid as (
    select supplier_id, sum(-amount)::numeric(18, 2) as paid_pool
    from ledger where amount < 0
    group by supplier_id
  ),
  positives as (
    select
      supplier_id,
      coalesce(due_date, entry_date) as due,
      amount,
      coalesce(
        sum(amount) over (
          partition by supplier_id
          order by coalesce(due_date, entry_date), entry_date
          rows between unbounded preceding and 1 preceding
        ),
        0
      ) as cum_before
    from ledger
    where amount > 0
  ),
  remaining as (
    select
      p.supplier_id,
      p.due,
      p.amount
        - least(
            p.amount,
            greatest(0, coalesce(pa.paid_pool, 0) - p.cum_before)
          ) as remaining
    from positives p
    left join paid pa on pa.supplier_id = p.supplier_id
  )
  select
    coalesce(jsonb_agg(r order by r.balance desc), '[]'::jsonb),
    coalesce(sum(r.payable), 0),
    coalesce(sum(r.paid), 0),
    coalesce(sum(r.balance), 0),
    count(*)
  into v_rows, v_total_payable, v_total_paid, v_total_balance, v_count
  from (
    select
      s.code as supplier_code,
      s.name as supplier_name,
      agg.payable,
      agg.paid,
      agg.balance,
      agg.not_due,
      agg.overdue_1_30,
      agg.overdue_31_60,
      agg.overdue_61_90,
      agg.overdue_over_90,
      agg.oldest_overdue_days
    from (
      select
        supplier_id,
        sum(payable_pos)::numeric(18, 2) as payable,
        least(coalesce(max(paid_pool), 0), sum(payable_pos))::numeric(18, 2) as paid,
        (sum(payable_pos) - least(coalesce(max(paid_pool), 0), sum(payable_pos)))::numeric(18, 2) as balance,
        sum(case when (p_to - due) <= 0 then remaining else 0 end)::numeric(18, 2) as not_due,
        sum(case when (p_to - due) between 1 and 30 then remaining else 0 end)::numeric(18, 2) as overdue_1_30,
        sum(case when (p_to - due) between 31 and 60 then remaining else 0 end)::numeric(18, 2) as overdue_31_60,
        sum(case when (p_to - due) between 61 and 90 then remaining else 0 end)::numeric(18, 2) as overdue_61_90,
        sum(case when (p_to - due) > 90 then remaining else 0 end)::numeric(18, 2) as overdue_over_90,
        max(case when remaining > 0 and (p_to - due) > 0 then (p_to - due) end) as oldest_overdue_days
      from (
        select
          r.supplier_id,
          r.due,
          r.remaining,
          r.amount as payable_pos,
          pa.paid_pool
        from remaining r
        left join paid pa on pa.supplier_id = r.supplier_id
      ) detail
      group by supplier_id
    ) agg
    join public.suppliers s on s.id = agg.supplier_id
    where agg.balance > 0
  ) r;

  return jsonb_build_object(
    'ok', true,
    'entity', jsonb_build_object('id', v_entity.id, 'code', v_entity.code, 'name', v_entity.name),
    'property_id', v_property_id,
    'from', p_from::text,
    'to', p_to::text,
    'exported_at', now(),
    'exported_by', auth.uid(),
    'rows', v_rows,
    'totals', jsonb_build_object(
      'supplier_count', v_count,
      'payable', v_total_payable,
      'paid', v_total_paid,
      'balance', v_total_balance
    )
  );
end;
$$;

revoke all on function public.export_payables(uuid, date, date)
  from public, anon;
grant execute on function public.export_payables(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Tam ung: tam ung tao trong khoang ngay + quyet toan (neu co).
--    Ngay tao tinh theo gio VN tu requested_at.
-- ---------------------------------------------------------------------------
create or replace function public.export_advances(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_entity record;
  v_rows jsonb;
  v_total_amount numeric(18, 2);
  v_total_settled numeric(18, 2);
  v_total_refund numeric(18, 2);
  v_total_extra numeric(18, 2);
  v_count integer;
begin
  v_property_id := public._export_require(p_legal_entity_id, p_from, p_to);
  select id, code, name into v_entity
  from public.legal_entities where id = p_legal_entity_id;

  perform public._export_assert_locked(
    p_legal_entity_id, v_property_id, p_from, p_to, 'finance'
  );

  select
    coalesce(jsonb_agg(r order by r.requested_date, r.doc_no), '[]'::jsonb),
    coalesce(sum(r.amount), 0),
    coalesce(sum(r.settled_amount), 0),
    coalesce(sum(r.refund_amount), 0),
    coalesce(sum(r.extra_pay_amount), 0),
    count(*)
  into v_rows, v_total_amount, v_total_settled, v_total_refund, v_total_extra, v_count
  from (
    select
      a.doc_no,
      a.status,
      p.employee_code,
      p.full_name as employee_name,
      a.purpose,
      a.amount,
      (a.requested_at at time zone 'Asia/Ho_Chi_Minh')::date::text as requested_date,
      (a.disbursed_at at time zone 'Asia/Ho_Chi_Minh')::date::text as disbursed_date,
      (a.due_settle_at at time zone 'Asia/Ho_Chi_Minh')::date::text as due_settle_date,
      (a.settled_at at time zone 'Asia/Ho_Chi_Minh')::date::text as settled_date,
      s.doc_no as settlement_doc_no,
      s.amount as settled_amount,
      s.refund_amount,
      s.extra_pay_amount,
      (s.settled_at at time zone 'Asia/Ho_Chi_Minh')::date::text as settlement_date
    from public.advances a
    left join public.advance_settlements s on s.advance_id = a.id
    left join public.profiles p on p.id = a.employee_id
    where a.legal_entity_id = p_legal_entity_id
      and (a.requested_at at time zone 'Asia/Ho_Chi_Minh')::date between p_from and p_to
  ) r;

  return jsonb_build_object(
    'ok', true,
    'entity', jsonb_build_object('id', v_entity.id, 'code', v_entity.code, 'name', v_entity.name),
    'property_id', v_property_id,
    'from', p_from::text,
    'to', p_to::text,
    'exported_at', now(),
    'exported_by', auth.uid(),
    'rows', v_rows,
    'totals', jsonb_build_object(
      'count', v_count,
      'amount', v_total_amount,
      'settled_amount', v_total_settled,
      'refund_amount', v_total_refund,
      'extra_pay_amount', v_total_extra
    )
  );
end;
$$;

revoke all on function public.export_advances(uuid, date, date)
  from public, anon;
grant execute on function public.export_advances(uuid, date, date)
  to authenticated;
