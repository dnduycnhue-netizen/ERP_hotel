-- ============================================================================
-- Q216: doi ma loi SoD kiem ke cho khop tai lieu (Duy chot 11/11/2026).
--
-- `_sod_check` raise `'ERR_' || p_rule_code`; moi call site khac deu truyen
-- ma co tien to `SOD_` (SOD_PO_RECEIVER, SOD_BANK_ACCOUNT...), chi kiem ke
-- truyen `'COUNT_INDEPENDENT'` o 2 cho (count_open 280000:805, count_submit
-- 280000:1068) nen message that la `ERR_COUNT_INDEPENDENT`, trong khi docs
-- (05-BUSINESS-RULES.md:84, 04-SECURITY-RLS.md:175, 09-API-RPC.md:83,206)
-- deu ghi `ERR_SOD_COUNT_INDEPENDENT`. Duy chot: DOI CODE cho khop docs.
--
-- count_open sinh tu 280000; count_submit sinh tu ban hien hanh tren
-- production (537000 — co wrapper R25 `_rule_enabled` + fix crypt 533000
-- `extensions.crypt`); MOI ham chi doi dung 1 chuoi
-- `'COUNT_INDEPENDENT'` -> `'SOD_COUNT_INDEPENDENT'`. Khong doi hop dong,
-- search_path, hay quyen (CREATE OR REPLACE giu nguyen grant).
-- `_sod_check` tra cuu `sod_exceptions.rule_code` nen cac dong ngoai le cu
-- (neu co) cung duoc doi theo; khong co CHECK nao rang buoc gia tri rule_code.
-- ============================================================================

create or replace function public.count_open(
  p_warehouse_id uuid,
  p_kind text,
  p_business_date date,
  p_shift text default null,
  p_counter_ids uuid[] default null,
  p_client_uuid uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wh public.warehouses%rowtype;
  v_property_id uuid;
  v_org_id uuid;
  v_entity_id uuid;
  v_business_date date := coalesce(
    p_business_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_counters uuid[] := coalesce(p_counter_ids, '{}');
  v_counter uuid;
  v_doc_no text;
  v_id uuid;
  v_lines integer;
  v_existing jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_warehouse_id is null or p_kind is null
    or p_kind not in ('shift_key', 'monthly_full', 'cycle', 'trolley', 'minibar_audit')
    or v_business_date is null or not isfinite(v_business_date) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_wh from public.warehouses where id = p_warehouse_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;
  v_property_id := v_wh.property_id;

  perform public.require_perm(v_property_id, 'count.open', p_warehouse_id);

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = v_property_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- Idempotency: goi lai cung client_uuid tra dot cu.
  if p_client_uuid is not null then
    select jsonb_build_object('ok', true, 'id', id, 'doc_no', doc_no,
      'lines_created', (select count(*) from public.stock_count_lines where count_id = stock_counts.id))
    into v_existing
    from public.stock_counts
    where client_uuid = p_client_uuid;
    if found then
      return v_existing;
    end if;
  end if;

  -- Kiem ke ca yeu cau file POS (09 §5); bang pos_imports chua co (Q34).
  if p_kind = 'shift_key' then
    raise exception using errcode = 'P0001', message = 'ERR_POS_IMPORT_REQUIRED';
  end if;

  -- Ngay nghiep vu khong nam trong ky da khoa / ngay da khoa (giong _post_move).
  if exists (
    select 1 from public.accounting_periods
    where legal_entity_id = v_entity_id
      and year = extract(year from v_business_date)::integer
      and month = extract(month from v_business_date)::integer
      and status = 'closed'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_CLOSED';
  end if;

  if exists (
    select 1 from public.day_locks
    where warehouse_id = p_warehouse_id
      and business_date = v_business_date
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_DAY_LOCKED';
  end if;

  -- Chi 1 dot monthly_full dang mo cho 1 kho.
  if p_kind = 'monthly_full' and exists (
    select 1 from public.stock_counts
    where warehouse_id = p_warehouse_id and kind = 'monthly_full'
      and status in ('open', 'counting', 'recount', 'submitted', 'locked')
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_ALREADY_OPEN';
  end if;

  -- Doi dem: monthly_full >= 2 nguoi khac nhau; moi nguoi phai ton tai.
  if array_length(v_counters, 1) is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if p_kind = 'monthly_full' and array_length(v_counters, 1) < 2 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  foreach v_counter in array v_counters loop
    if v_counter is null or not exists (
      select 1 from auth.users where id = v_counter
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
  end loop;
  if (select count(*) from (select distinct unnest(v_counters) as u) s)
    <> array_length(v_counters, 1) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- SOD_COUNT_INDEPENDENT (04 §6): dot thang phai co >= 1 nguoi dem khong co
  -- quyen receiving.post / requisition.issue tai kho do.
  if p_kind = 'monthly_full' and not exists (
    select 1 from unnest(v_counters) as u(uid)
    where not public._count_user_has_perm(u.uid, v_property_id, 'receiving.post', p_warehouse_id)
      and not public._count_user_has_perm(u.uid, v_property_id, 'requisition.issue', p_warehouse_id)
  ) then
    perform public._sod_check(v_property_id, 'SOD_COUNT_INDEPENDENT');
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity_id, 'CNT', v_business_date);

  insert into public.stock_counts (
    org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind,
    business_date, shift, status, counter_ids, opened_by, client_uuid,
    created_by
  ) values (
    v_org_id, v_entity_id, v_property_id, p_warehouse_id, v_doc_no, p_kind,
    v_business_date, p_shift, 'open', v_counters, auth.uid(), p_client_uuid,
    auth.uid()
  )
  returning id into v_id;

  -- Khoa dong ton hien tai de snapshot nhat quan: _post_move cung khoa dong
  -- nay (FOR UPDATE) nen post dong thoi bi chan toi khi mo dot xong.
  perform 1 from public.stock_balances
  where warehouse_id = p_warehouse_id
  for update;

  -- Snapshot ton so: 1 dong / ma hang, cong don qua cac lo.
  insert into public.stock_count_lines (count_id, org_id, item_id, book_qty, theoretical_qty)
  select v_id, v_org_id, sb.item_id, sum(sb.qty),
    case when p_kind = 'monthly_full' then sum(sb.qty) else null end
  from public.stock_balances sb
  where sb.warehouse_id = p_warehouse_id and sb.qty <> 0
  group by sb.item_id;

  get diagnostics v_lines = row_count;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no, 'lines_created', v_lines
  );
end;
$$;

create or replace function public.count_submit(
  p_count_id uuid,
  p_pins text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_counter uuid;
  v_pin text;
  v_hash text;
  v_pin_ok boolean;
  v_recount uuid[] := '{}';
  v_red uuid[] := '{}';
  r_line public.stock_count_lines%rowtype;
  v_final numeric(18,4);
  v_var numeric(18,4);
  v_book numeric(18,4);
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status not in ('counting', 'recount') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.perform', v_count.warehouse_id);

  if not (auth.uid() = any(v_count.counter_ids)) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:count.perform';
  end if;

  -- R25 (co rule.R25.enabled): khi co BAT (mac dinh) yeu cau du PIN moi
  -- nguoi dem (06 §3.2); khi co TAT chi can PIN nguoi nop. R21 (>=2 nguoi
  -- dem) va R22 (SoD doc lap) o tren/duoi khong doi.
  if public._rule_enabled(v_count.property_id, 'R25') then
    if p_pins is null
      or array_length(p_pins, 1) is null
      or array_length(p_pins, 1) <> array_length(v_count.counter_ids, 1) then
      raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
    end if;
    foreach v_counter in array v_count.counter_ids loop
      select pin_hash into v_hash from public.profiles where id = v_counter;
      v_pin_ok := false;
      if v_hash is not null then
        foreach v_pin in array p_pins loop
          if v_pin is not null and v_hash = extensions.crypt(v_pin, v_hash) then
            v_pin_ok := true;
          end if;
        end loop;
      end if;
      if not v_pin_ok then
        raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
      end if;
    end loop;
  else
    -- Chi can PIN nguoi nop (nguoi nop van phai la 1 trong 2 nguoi dem,
    -- kiem tra o tren khong doi).
    select pin_hash into v_hash from public.profiles where id = auth.uid();
    v_pin_ok := false;
    if v_hash is not null and p_pins is not null then
      foreach v_pin in array p_pins loop
        if v_pin is not null and v_hash = extensions.crypt(v_pin, v_hash) then
          v_pin_ok := true;
        end if;
      end loop;
    end if;
    if not v_pin_ok then
      raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
    end if;
  end if;

  -- SOD_COUNT_INDEPENDENT (04 §6): kiem lai o luc submit.
  if v_count.kind = 'monthly_full' and not exists (
    select 1 from unnest(v_count.counter_ids) as u(uid)
    where not public._count_user_has_perm(u.uid, v_count.property_id, 'receiving.post', v_count.warehouse_id)
      and not public._count_user_has_perm(u.uid, v_count.property_id, 'requisition.issue', v_count.warehouse_id)
  ) then
    perform public._sod_check(v_count.property_id, 'SOD_COUNT_INDEPENDENT');
  end if;

  -- Mọi dòng phải được đếm đủ: monthly_full cần cả 2 vòng.
  if exists (
    select 1 from public.stock_count_lines
    where count_id = p_count_id
      and (counted_qty_1 is null
        or (v_count.kind = 'monthly_full' and counted_qty_2 is null))
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_INCOMPLETE';
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  if v_count.status = 'counting' then
    -- Vong 1: hai nguoi khop nhau moi co final; lech so sach -> dem lai.
    for r_line in
      select * from public.stock_count_lines
      where count_id = p_count_id
      for update
    loop
      v_book := coalesce(r_line.book_qty, 0);
      if r_line.counted_qty_1 = r_line.counted_qty_2 then
        v_final := r_line.counted_qty_1;
        v_var := v_final - v_book;
        if abs(v_var) > 0.0001 then
          update public.stock_count_lines set
            final_qty = null, variance_qty = null, variance_pct = null,
            flag = 'recount',
            counted_qty_1 = null, counted_qty_2 = null,
            counted_by_1 = null, counted_by_2 = null,
            count_detail = '{}'::jsonb, count_detail_by = null,
            bottle_weight_g = null
          where id = r_line.id;
          v_recount := array_append(v_recount, r_line.id);
        else
          update public.stock_count_lines set
            final_qty = v_final, variance_qty = v_var,
            variance_pct = case when v_book <> 0
              then round(v_var / v_book * 100, 4) else null end,
            flag = 'ok'
          where id = r_line.id;
        end if;
      else
        update public.stock_count_lines set
          final_qty = null, variance_qty = null, variance_pct = null,
          flag = 'recount',
          counted_qty_1 = null, counted_qty_2 = null,
          counted_by_1 = null, counted_by_2 = null,
          count_detail = '{}'::jsonb, count_detail_by = null,
          bottle_weight_g = null
        where id = r_line.id;
        v_recount := array_append(v_recount, r_line.id);
      end if;
    end loop;

    if array_length(v_recount, 1) is not null then
      update public.stock_counts set status = 'recount' where id = p_count_id;
    else
      update public.stock_counts set status = 'submitted' where id = p_count_id;
    end if;
  else
    -- Vong 2 (sau dem lai): final = vong 2 neu co, khong thi vong 1;
    -- con lech so sach hoac hai nguoi van khac nhau -> 'red'.
    for r_line in
      select * from public.stock_count_lines
      where count_id = p_count_id and flag = 'recount'
      for update
    loop
      v_book := coalesce(r_line.book_qty, 0);
      v_final := coalesce(r_line.counted_qty_2, r_line.counted_qty_1);
      v_var := v_final - v_book;
      update public.stock_count_lines set
        final_qty = v_final, variance_qty = v_var,
        variance_pct = case when v_book <> 0
          then round(v_var / v_book * 100, 4) else null end,
        flag = case
          when r_line.counted_qty_1 is distinct from r_line.counted_qty_2
            then 'red'
          when abs(v_var) > 0.0001 then 'red'
          else 'ok'
        end
      where id = r_line.id;
      if r_line.counted_qty_1 is distinct from r_line.counted_qty_2
        or abs(v_var) > 0.0001 then
        v_red := array_append(v_red, r_line.id);
      end if;
    end loop;

    update public.stock_counts set status = 'submitted' where id = p_count_id;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', p_count_id,
    'recount_line_ids', coalesce(to_jsonb(v_recount), '[]'::jsonb),
    'red_line_ids', coalesce(to_jsonb(v_red), '[]'::jsonb)
  );
end;
$$;

-- Doi theo cac dong ngoai le SoD cu (neu co) de _sod_check van khop.
update public.sod_exceptions
set rule_code = 'SOD_COUNT_INDEPENDENT'
where rule_code = 'COUNT_INDEPENDENT';

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109542000_sod_count_independent_rename',
  'INSERT',
  jsonb_build_object('event', 'q216_sod_rename', 'task', 'T-032'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
