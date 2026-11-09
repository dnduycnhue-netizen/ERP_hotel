-- T-011: Sổ cái kho, hàm _post_move, FIFO layers, khóa ngày và đóng kỳ.

-- 1. Bảng theo dõi các lớp FIFO
create table public.fifo_layers (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null,
  item_id uuid not null,
  stock_move_id bigint not null references public.stock_moves(id),
  unit_cost numeric(18,4) not null check (unit_cost >= 0),
  qty_initial numeric(18,4) not null check (qty_initial > 0),
  qty_remaining numeric(18,4) not null check (qty_remaining >= 0),
  business_date date not null check (isfinite(business_date)),
  created_at timestamptz not null default now(),
  foreign key (legal_entity_id, org_id) references public.legal_entities(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id)
);

create index fifo_layers_active_idx
  on public.fifo_layers (legal_entity_id, item_id, business_date, id)
  where qty_remaining > 0;

-- 2. Bảng phân bổ lớp FIFO cho các lần xuất
create table public.fifo_allocations (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null,
  issue_move_id bigint not null references public.stock_moves(id),
  layer_id bigint not null references public.fifo_layers(id),
  qty numeric(18,4) not null check (qty > 0),
  unit_cost numeric(18,4) not null check (unit_cost >= 0),
  amount numeric(18,2) not null,
  created_at timestamptz not null default now(),
  foreign key (legal_entity_id, org_id) references public.legal_entities(id, org_id)
);

create index fifo_allocations_issue_idx
  on public.fifo_allocations (issue_move_id);
create index fifo_allocations_layer_idx
  on public.fifo_allocations (layer_id);

create trigger trg_fifo_allocations_immutable
  before update or delete on public.fifo_allocations
  for each row execute function public.forbid_mutation();

create or replace function public.forbid_delete()
returns trigger
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  raise exception using
    errcode = '55000',
    message = format('ERR_IMMUTABLE_LEDGER:%s:DELETE', tg_table_name);
end;
$$;
revoke all on function public.forbid_delete() from public, anon, authenticated;

create trigger trg_fifo_layers_no_delete
  before delete on public.fifo_layers
  for each row execute function public.forbid_delete();

-- 3. Trigger chặn sửa chứng từ đã post
create or replace function public.forbid_edit_when_posted()
returns trigger
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  if old.status in ('posted', 'locked', 'reversed', 'closed') then
    raise exception using errcode = '55000', message = format('ERR_DOC_POSTED:%s', old.id);
  end if;
  return new;
end;
$$;
revoke all on function public.forbid_edit_when_posted() from public, anon, authenticated;

-- 4. Hàm ghi sổ kho dùng chung _post_move
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
      if v_orig.qty > 0 and v_orig.move_type in ('receipt', 'opening', 'production_in', 'merge_in') then
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
revoke all on function public._post_move from public, anon, authenticated;

-- 5. RPC quản trị khóa ngày và đóng kỳ
create or replace function public.day_lock(
  p_warehouse_id uuid,
  p_date date,
  p_shift text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_warehouse_id is null or p_date is null or not isfinite(p_date) then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  select property_id into v_property_id
  from public.warehouses
  where id = p_warehouse_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;

  perform public.require_perm(v_property_id, 'day.lock', p_warehouse_id);

  insert into public.day_locks (property_id, warehouse_id, business_date, shift, locked_by)
  values (v_property_id, p_warehouse_id, p_date, p_shift, auth.uid())
  on conflict (warehouse_id, business_date, shift)
  do update set locked_by = auth.uid(), locked_at = now(), updated_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.day_unlock(
  p_lock_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_lock public.day_locks%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_lock
  from public.day_locks
  where id = p_lock_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_LOCK_NOT_FOUND';
  end if;

  perform public.require_perm(v_lock.property_id, 'day.unlock', v_lock.warehouse_id);

  delete from public.day_locks where id = p_lock_id;

  return jsonb_build_object('ok', true, 'id', p_lock_id);
end;
$$;

create or replace function public.period_close(
  p_entity_id uuid,
  p_year integer,
  p_month integer
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_entity_id is null or p_year is null or p_year < 1 or p_month is null or p_month not between 1 and 12 then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  perform public.require_perm(null, 'period.close');

  if exists (
    select 1 from public.accounting_periods
    where legal_entity_id = p_entity_id and year = p_year and month = p_month and status = 'closed'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_ALREADY_CLOSED';
  end if;

  insert into public.accounting_periods (legal_entity_id, year, month, status, closed_by, closed_at)
  values (p_entity_id, p_year, p_month, 'closed', auth.uid(), now())
  on conflict (legal_entity_id, year, month)
  do update set status = 'closed', closed_by = auth.uid(), closed_at = now(), updated_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.period_reopen(
  p_period_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_period public.accounting_periods%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_period
  from public.accounting_periods
  where id = p_period_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_NOT_FOUND';
  end if;

  perform public.require_perm(null, 'period.reopen');

  update public.accounting_periods
  set status = 'open', closed_by = null, closed_at = null, updated_at = now()
  where id = p_period_id;

  return jsonb_build_object('ok', true, 'id', p_period_id);
end;
$$;

revoke all on function public.day_lock(uuid, date, text) from public, anon;
revoke all on function public.day_unlock(uuid, text) from public, anon;
revoke all on function public.period_close(uuid, integer, integer) from public, anon;
revoke all on function public.period_reopen(uuid, text) from public, anon;

grant execute on function public.day_lock(uuid, date, text) to authenticated;
grant execute on function public.day_unlock(uuid, text) to authenticated;
grant execute on function public.period_close(uuid, integer, integer) to authenticated;
grant execute on function public.period_reopen(uuid, text) to authenticated;

-- 6. RLS Policies và Phân quyền SELECT
alter table public.fifo_layers enable row level security;
alter table public.fifo_allocations enable row level security;

revoke all on table public.fifo_layers, public.fifo_allocations from public, anon, authenticated;

grant select on public.stock_moves to authenticated;
grant select on public.stock_balances to authenticated;
grant select on public.item_costs to authenticated;
grant select on public.lots to authenticated;
grant select on public.accounting_periods to authenticated;
grant select on public.day_locks to authenticated;
grant select on public.fifo_layers to authenticated;
grant select on public.fifo_allocations to authenticated;

create policy stock_moves_select on public.stock_moves for select to authenticated
using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'stock.view_qty', warehouse_id)
    or public.has_perm(property_id, 'stock.view_value', warehouse_id)
    or (select public.has_perm(null, 'audit.view_all'))
  )
);

create policy stock_balances_select on public.stock_balances for select to authenticated
using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'stock.view_qty', warehouse_id)
    or public.has_perm(property_id, 'stock.view_value', warehouse_id)
  )
);

create policy item_costs_select on public.item_costs for select to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.legal_entity_id = item_costs.legal_entity_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'stock.view_value')
  )
);

create policy lots_select on public.lots for select to authenticated
using (
  property_id in (select public.my_property_ids())
  and public.has_perm(property_id, 'stock.view_qty')
);

create policy accounting_periods_select on public.accounting_periods for select to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.legal_entity_id = accounting_periods.legal_entity_id
      and p.id in (select public.my_property_ids())
  )
);

create policy day_locks_select on public.day_locks for select to authenticated
using (
  property_id in (select public.my_property_ids())
);

create policy fifo_layers_select on public.fifo_layers for select to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.legal_entity_id = fifo_layers.legal_entity_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'stock.view_value')
  )
);

create policy fifo_allocations_select on public.fifo_allocations for select to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.legal_entity_id = fifo_allocations.legal_entity_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'stock.view_value')
  )
);
