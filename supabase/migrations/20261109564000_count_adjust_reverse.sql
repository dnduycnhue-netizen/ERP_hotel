-- ============================================================================
-- Q244 — 20261109564000_count_adjust_reverse
--   Boi canh (12/11/2026, truoc cutover ton dau ky): khach san that SONHOIAN
--   co 28 dong adjust_count do ban chay thu (dot CNT-SONHOIAN-2611-0001, TEST03,
--   don gia 0, 872 don vi) — gia von 0 se keo thap gia binh quan khi nhap
--   hang that. So cai bat bien nen KHONG xoa; dao bang but toan dao that
--   (move_type = 'reversal', reverses_move_id) theo AGENTS.md quy tac 2.
--
--   A. _post_move (sinh lai NGUYEN VAN tu 120000, chi doi 1 dong): nhanh
--      bình quân gia quyen cua but toan dao nay xu ly them adjust_count DUONG
--      (truoc day chi 'receipt','opening','production_in','merge_in' nen dao
--      adjust_count duong se lam item_costs lech stock_balances). adjust_count
--      duong khong doi gia binh quan khi ghi (chi cong so luong) nen dao lai
--      bang cong thuc tru gia tri theo don gia goc la dung. Nhanh FIFO KHONG
--      doi (adjust_count duong khong tao lop FIFO).
--   B. count_adjust_reverse(p_count_id, p_reason): dao TOAN BO dong adjust_count
--      chua bi dao cua mot dot kiem ke da 'adjusted'. Quyen count.adjust.approve
--      (nhu count_adjust_post), ly do bat buoc, ghi audit_log. Dao het roi goi
--      lai -> ERR_ALREADY_REVERSED. Trang thai dot kiem ke giu 'adjusted' (khong
--      them trang thai moi); dot moi monthly_full cho kho co the mo binh thuong.
-- ============================================================================
create or replace function public._post_move(
  p_entity uuid,
  p_property uuid,
  p_wh uuid,
  p_item uuid,
  p_lot uuid,
  p_type text,
  p_qty numeric,
  p_unit_cost numeric,
  p_date date,
  p_doc_type text,
  p_doc_id uuid,
  p_line_id uuid default null,
  p_cost_center uuid default null,
  p_expense_cat uuid default null,
  p_purpose text default null,
  p_reverses bigint default null
) returns bigint
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_costing_method text;
  v_cost numeric(18,4);
  v_amount numeric(18,2);
  v_bal numeric(18,4);
  v_ic public.item_costs%rowtype;
  v_id bigint;
  v_orig public.stock_moves%rowtype;
  v_rem_qty numeric(18,4);
  v_rem_val numeric(18,2);
  v_needed numeric(18,4);
  v_take numeric(18,4);
  v_layer_amt numeric(18,2);
  v_total_amt numeric(18,2);
  r_layer record;
  r_alloc record;
  v_caller uuid;
begin
  -- Xác thực thông tin đầu vào cơ bản
  if p_entity is null or p_property is null or p_wh is null or p_item is null
    or p_date is null or not isfinite(p_date) then
    raise exception using errcode = '22023', message = 'ERR_INVALID_MOVE_INPUT';
  end if;

  if p_type is null or p_type not in (
    'opening', 'receipt', 'return_out', 'issue_out', 'issue_in', 'transfer_out',
    'transfer_in', 'purpose_issue', 'waste', 'adjust_count', 'production_out',
    'production_in', 'minibar_sale', 'merge_out', 'merge_in', 'reversal'
  ) then
    raise exception using errcode = '22023', message = format('ERR_INVALID_MOVE_TYPE:%s', coalesce(p_type, 'null'));
  end if;

  if p_qty is null or p_qty = 0 then
    raise exception using errcode = '22023', message = 'ERR_ZERO_QUANTITY_MOVE';
  end if;

  if p_doc_type is null or btrim(p_doc_type) = '' or p_doc_id is null then
    raise exception using errcode = '22023', message = 'ERR_SOURCE_DOC_REQUIRED';
  end if;

  -- Kiểm tra tính hợp lệ giữa property, entity và warehouse
  if not exists (
    select 1 from public.properties p
    where p.id = p_property and p.legal_entity_id = p_entity
  ) then
    raise exception using errcode = '23503', message = 'ERR_PROPERTY_ENTITY_MISMATCH';
  end if;

  if not exists (
    select 1 from public.warehouses w
    where w.id = p_wh and w.property_id = p_property
  ) then
    raise exception using errcode = '23503', message = 'ERR_WAREHOUSE_PROPERTY_MISMATCH';
  end if;

  select org_id, costing_method into strict v_org_id, v_costing_method
  from public.legal_entities
  where id = p_entity;

  if not exists (
    select 1 from public.items i
    where i.id = p_item and i.org_id = v_org_id
  ) then
    raise exception using errcode = '23503', message = 'ERR_ITEM_ORG_MISMATCH';
  end if;

  if p_lot is not null and not exists (
    select 1 from public.lots l
    where l.id = p_lot and l.property_id = p_property and l.item_id = p_item and l.org_id = v_org_id
  ) then
    raise exception using errcode = '23503', message = 'ERR_LOT_MISMATCH';
  end if;

  -- 1. Kỳ kế toán phải mở (P0001: ERR_PERIOD_CLOSED)
  if exists (
    select 1 from public.accounting_periods
    where legal_entity_id = p_entity
      and year = extract(year from p_date)::integer
      and month = extract(month from p_date)::integer
      and status = 'closed'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_CLOSED';
  end if;

  -- 2. Ngày không bị khóa (P0001: ERR_DAY_LOCKED)
  if exists (
    select 1 from public.day_locks
    where warehouse_id = p_wh
      and business_date >= p_date
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_DAY_LOCKED';
  end if;

  -- 3. Xử lý bút toán đảo (reversal)
  if p_type = 'reversal' then
    if p_reverses is null then
      raise exception using errcode = '22023', message = 'ERR_REVERSAL_TARGET_REQUIRED';
    end if;

    select * into v_orig
    from public.stock_moves
    where id = p_reverses
    for update;

    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_ORIGINAL_MOVE_NOT_FOUND';
    end if;

    if exists (
      select 1 from public.stock_moves where reverses_move_id = p_reverses
    ) then
      raise exception using errcode = '23505', message = 'ERR_ALREADY_REVERSED';
    end if;

    if p_qty <> -v_orig.qty then
      raise exception using errcode = '22023', message = 'ERR_REVERSAL_QTY_MISMATCH';
    end if;

    -- Nếu là đảo phiếu nhập trong phương pháp FIFO: kiểm tra lớp nhập chưa bị xuất
    if v_costing_method = 'fifo' and v_orig.qty > 0 and v_orig.move_type in ('receipt', 'opening', 'production_in', 'merge_in') then
      select * into r_layer
      from public.fifo_layers
      where stock_move_id = v_orig.id
      for update;

      if not found or r_layer.qty_remaining < v_orig.qty then
        raise exception using errcode = 'P0001', message = 'ERR_FIFO_LAYER_CONSUMED';
      end if;
    end if;

    v_cost := v_orig.unit_cost;
    v_amount := -v_orig.amount;
  end if;

  -- 4. Chặn tồn âm tại kho (ERR_NEGATIVE_STOCK)
  select coalesce(qty, 0) into v_bal
  from public.stock_balances
  where warehouse_id = p_wh
    and item_id = p_item
    and lot_id is not distinct from p_lot
  for update;

  if coalesce(v_bal, 0) + p_qty < 0 then
    raise exception using errcode = 'P0001',
      message = format('ERR_NEGATIVE_STOCK: kho %s, mã %s, tồn %s, xuất %s', p_wh, p_item, coalesce(v_bal, 0), -p_qty);
  end if;

  -- 5. Khóa dòng giá vốn pháp nhân để tránh tranh chấp
  select * into v_ic
  from public.item_costs
  where legal_entity_id = p_entity and item_id = p_item
  for update;

  if not found then
    insert into public.item_costs (legal_entity_id, org_id, item_id, avg_cost, qty_on_hand)
    values (p_entity, v_org_id, p_item, 0, 0)
    returning * into v_ic;
  end if;

  -- 6. Tính toán giá vốn theo phương pháp (Moving Average hoặc FIFO)
  if v_costing_method = 'moving_avg' then
    if p_type = 'reversal' then
      if v_orig.qty > 0 and v_orig.move_type in ('receipt', 'opening', 'production_in', 'merge_in', 'adjust_count') then
        v_rem_qty := v_ic.qty_on_hand - v_orig.qty;
        v_rem_val := (v_ic.qty_on_hand * v_ic.avg_cost) - (v_orig.qty * v_orig.unit_cost);
        if v_rem_qty < 0 or v_rem_val < 0 then
          raise exception using errcode = 'P0001', message = 'ERR_NEGATIVE_STOCK';
        end if;
        update public.item_costs set
          avg_cost = case when v_rem_qty = 0 then 0 else round(v_rem_val / v_rem_qty, 4) end,
          qty_on_hand = v_rem_qty,
          updated_at = now()
        where legal_entity_id = p_entity and item_id = p_item;
      elsif v_orig.qty < 0 and v_orig.move_type not in ('transfer_out', 'transfer_in', 'issue_out', 'issue_in') then
        update public.item_costs set
          qty_on_hand = qty_on_hand - v_orig.qty,
          updated_at = now()
        where legal_entity_id = p_entity and item_id = p_item;
      end if;
    elsif p_type = 'return_out' then
      if p_unit_cost is null or p_unit_cost < 0 then
        raise exception using errcode = '22023', message = 'ERR_RETURN_COST_REQUIRED';
      end if;
      v_cost := p_unit_cost;
      v_amount := round(p_qty * v_cost, 2);
      v_rem_qty := v_ic.qty_on_hand - (-p_qty);
      v_rem_val := (v_ic.qty_on_hand * v_ic.avg_cost) - ((-p_qty) * v_cost);
      if v_rem_qty < 0 or v_rem_val < 0 then
        raise exception using errcode = 'P0001', message = 'ERR_NEGATIVE_STOCK';
      end if;
      update public.item_costs set
        avg_cost = case when v_rem_qty = 0 then 0 else round(v_rem_val / v_rem_qty, 4) end,
        qty_on_hand = v_rem_qty,
        updated_at = now()
      where legal_entity_id = p_entity and item_id = p_item;
    elsif p_qty > 0 and p_type in ('receipt', 'opening', 'production_in', 'merge_in') then
      if p_unit_cost is null or p_unit_cost < 0 then
        raise exception using errcode = '22023', message = 'ERR_UNIT_COST_REQUIRED';
      end if;
      v_cost := p_unit_cost;
      v_amount := round(p_qty * v_cost, 2);
      update public.item_costs set
        avg_cost = case
          when qty_on_hand + p_qty = 0 then v_cost
          else round((qty_on_hand * avg_cost + p_qty * v_cost) / (qty_on_hand + p_qty), 4)
        end,
        qty_on_hand = qty_on_hand + p_qty,
        updated_at = now()
      where legal_entity_id = p_entity and item_id = p_item;
    else
      v_cost := coalesce(p_unit_cost, v_ic.avg_cost);
      v_amount := round(p_qty * v_cost, 2);
      if p_type not in ('transfer_out', 'transfer_in', 'issue_out', 'issue_in') then
        update public.item_costs set
          qty_on_hand = qty_on_hand + p_qty,
          updated_at = now()
        where legal_entity_id = p_entity and item_id = p_item;
      end if;
    end if;

  else
    -- FIFO Costing
    if exists (
      select 1 from public.stock_moves
      where legal_entity_id = p_entity and item_id = p_item and business_date > p_date
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_FIFO_BACKDATED_FORBIDDEN';
    end if;

    if p_type = 'reversal' then
      if v_orig.qty > 0 and v_orig.move_type in ('receipt', 'opening', 'production_in', 'merge_in') then
        select * into r_layer
        from public.fifo_layers
        where stock_move_id = v_orig.id
        for update;

        if not found or r_layer.qty_remaining < v_orig.qty then
          raise exception using errcode = 'P0001', message = 'ERR_FIFO_LAYER_CONSUMED';
        end if;

        update public.fifo_layers
        set qty_remaining = qty_remaining - v_orig.qty
        where id = r_layer.id;

        update public.item_costs set
          qty_on_hand = qty_on_hand - v_orig.qty,
          updated_at = now()
        where legal_entity_id = p_entity and item_id = p_item;
      elsif v_orig.qty < 0 and v_orig.move_type not in ('transfer_out', 'transfer_in', 'issue_out', 'issue_in') then
        for r_alloc in (
          select * from public.fifo_allocations
          where issue_move_id = v_orig.id
          for update
        ) loop
          update public.fifo_layers
          set qty_remaining = qty_remaining + r_alloc.qty
          where id = r_alloc.layer_id;
        end loop;

        update public.item_costs set
          qty_on_hand = qty_on_hand - v_orig.qty,
          updated_at = now()
        where legal_entity_id = p_entity and item_id = p_item;
      end if;
    elsif p_type = 'return_out' then
      if p_unit_cost is null or p_unit_cost < 0 then
        raise exception using errcode = '22023', message = 'ERR_RETURN_COST_REQUIRED';
      end if;
      v_cost := p_unit_cost;
      v_amount := round(p_qty * v_cost, 2);

      select id, qty_remaining into r_layer
      from public.fifo_layers
      where legal_entity_id = p_entity and item_id = p_item and unit_cost = v_cost and qty_remaining >= (-p_qty)
      order by business_date asc, id asc
      limit 1
      for update;

      if not found then
        raise exception using errcode = 'P0001', message = 'ERR_FIFO_LAYER_CONSUMED';
      end if;

      update public.fifo_layers
      set qty_remaining = qty_remaining - (-p_qty)
      where id = r_layer.id;

      update public.item_costs set
        qty_on_hand = qty_on_hand + p_qty,
        updated_at = now()
      where legal_entity_id = p_entity and item_id = p_item;
    elsif p_qty > 0 and p_type in ('receipt', 'opening', 'production_in', 'merge_in') then
      if p_unit_cost is null or p_unit_cost < 0 then
        raise exception using errcode = '22023', message = 'ERR_UNIT_COST_REQUIRED';
      end if;
      v_cost := p_unit_cost;
      v_amount := round(p_qty * v_cost, 2);
      update public.item_costs set
        qty_on_hand = qty_on_hand + p_qty,
        avg_cost = v_cost,
        updated_at = now()
      where legal_entity_id = p_entity and item_id = p_item;
    elsif p_qty < 0 and p_type not in ('transfer_out', 'transfer_in', 'issue_out', 'issue_in') then
      v_needed := -p_qty;
      v_total_amt := 0;
      for r_layer in (
        select * from public.fifo_layers
        where legal_entity_id = p_entity and item_id = p_item and qty_remaining > 0
        order by business_date asc, id asc
        for update
      ) loop
        v_take := least(r_layer.qty_remaining, v_needed);
        v_layer_amt := round(v_take * r_layer.unit_cost, 2);
        v_total_amt := v_total_amt + v_layer_amt;
        v_needed := v_needed - v_take;
        exit when v_needed = 0;
      end loop;

      if v_needed > 0 then
        raise exception using errcode = 'P0001',
          message = format('ERR_NEGATIVE_STOCK: kho %s, mã %s, không đủ tồn trong các lớp FIFO', p_wh, p_item);
      end if;

      v_cost := round(v_total_amt / (-p_qty), 4);
      v_amount := round(p_qty * v_cost, 2);

      update public.item_costs set
        qty_on_hand = qty_on_hand + p_qty,
        updated_at = now()
      where legal_entity_id = p_entity and item_id = p_item;
    else
      v_cost := coalesce(p_unit_cost, v_ic.avg_cost);
      v_amount := round(p_qty * v_cost, 2);
    end if;
  end if;

  v_caller := auth.uid();
  if v_caller is null then
    raise exception using errcode = '42501', message = 'ERR_UNAUTHENTICATED';
  end if;

  -- 7. Ghi sổ cái stock_moves
  insert into public.stock_moves (
    org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id,
    move_type, qty, unit_cost, amount, business_date, posted_by,
    source_doc_type, source_doc_id, source_line_id, reverses_move_id,
    cost_center_id, expense_category_id, purpose_code
  ) values (
    v_org_id, p_entity, p_property, p_wh, p_item, p_lot,
    p_type, p_qty, v_cost, v_amount, p_date, v_caller,
    p_doc_type, p_doc_id, p_line_id, p_reverses,
    p_cost_center, p_expense_cat, p_purpose
  ) returning id into v_id;

  -- 8. Cập nhật số dư kho stock_balances
  if exists (
    select 1 from public.stock_balances
    where warehouse_id = p_wh
      and item_id = p_item
      and lot_id is not distinct from p_lot
  ) then
    update public.stock_balances
    set qty = qty + p_qty, updated_at = now()
    where warehouse_id = p_wh
      and item_id = p_item
      and lot_id is not distinct from p_lot;
  else
    insert into public.stock_balances (
      org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty
    ) values (
      v_org_id, p_entity, p_property, p_wh, p_item, p_lot, p_qty
    );
  end if;

  -- 9. Xử lý bổ sung cho FIFO (tạo lớp mới hoặc lưu phân bổ)
  if v_costing_method = 'fifo' then
    if p_qty > 0 and p_type in ('receipt', 'opening', 'production_in', 'merge_in') then
      insert into public.fifo_layers (
        org_id, legal_entity_id, item_id, stock_move_id,
        unit_cost, qty_initial, qty_remaining, business_date
      ) values (
        v_org_id, p_entity, p_item, v_id,
        v_cost, p_qty, p_qty, p_date
      );
    elsif p_qty < 0 and p_type not in ('transfer_out', 'transfer_in', 'issue_out', 'issue_in')
      and p_type <> 'reversal' and p_type <> 'return_out' then
      v_needed := -p_qty;
      for r_layer in (
        select * from public.fifo_layers
        where legal_entity_id = p_entity and item_id = p_item and qty_remaining > 0
        order by business_date asc, id asc
        for update
      ) loop
        v_take := least(r_layer.qty_remaining, v_needed);
        v_layer_amt := round(v_take * r_layer.unit_cost, 2);

        update public.fifo_layers
        set qty_remaining = qty_remaining - v_take
        where id = r_layer.id;

        insert into public.fifo_allocations (
          org_id, legal_entity_id, issue_move_id, layer_id, qty, unit_cost, amount
        ) values (
          v_org_id, p_entity, v_id, r_layer.id, v_take, r_layer.unit_cost, v_layer_amt
        );

        v_needed := v_needed - v_take;
        exit when v_needed = 0;
      end loop;
    end if;
  end if;

  return v_id;
end;
$$;

create or replace function public.count_adjust_reverse(
  p_count_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_move public.stock_moves%rowtype;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_n integer := 0;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_count.property_id, 'count.adjust.approve');

  if v_count.status <> 'adjusted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  for v_move in
    select m.*
    from public.stock_moves m
    where m.source_doc_type = 'stock_count'
      and m.source_doc_id = p_count_id
      and m.move_type = 'adjust_count'
      and not exists (
        select 1 from public.stock_moves r where r.reverses_move_id = m.id
      )
    order by m.id
  loop
    perform public._post_move(
      v_move.legal_entity_id, v_move.property_id, v_move.warehouse_id,
      v_move.item_id, v_move.lot_id, 'reversal', -v_move.qty, v_move.unit_cost,
      v_today, 'stock_count', p_count_id, v_move.source_line_id,
      null, null, null, v_move.id
    );
    v_n := v_n + 1;
  end loop;

  if v_n = 0 then
    raise exception using errcode = '23505', message = 'ERR_ALREADY_REVERSED';
  end if;

  insert into public.audit_log (table_name, row_id, action, old_data, new_data, actor)
  values (
    'stock_counts', p_count_id::text, 'UPDATE',
    jsonb_build_object('status', v_count.status),
    jsonb_build_object(
      'status', v_count.status,
      'adjustments_reversed', v_n,
      'reversal_reason', btrim(p_reason)
    ),
    auth.uid()
  );

  return jsonb_build_object('ok', true, 'id', p_count_id, 'reversed_moves', v_n);
end;
$$;

revoke all on function public.count_adjust_reverse(uuid, text)
  from public, anon, authenticated;
grant execute on function public.count_adjust_reverse(uuid, text) to authenticated;
