-- ============================================================================
-- Q206: count_submit goi crypt() khong kem schema -> 42883, khong dot kiem
--   ke nao nop duoc (PIN verify luon no). Ham co `set search_path = public,
--   auth, pg_temp` (khong co extensions) nen crypt() cua pgcrypto khong
--   thay duoc — loi xay ra o MOI ngu canh goi (SQL Editor lan app), khong
--   phai do search_path cua caller. Hai ham phu _verify_pin (T-023) va
--   _count_verify_pin co `set search_path = public, extensions` nen khong
--   dinh; chi count_submit tu kiem PIN noi tuyen (dong 1052 goc) la dinh.
--   Phat hien 11/11/2026 khi chay script ton dau ky demo: submit vong 1
--   no 42883 `function crypt(text, text) does not exist`.
--   Sua: goi day du extensions.crypt — dung quy uoc da co (admin_users_roles
--   dung extensions.crypt khi dat PIN; script demo cung vay). Khong doi
--   search_path cua ham, khong doi chu ky ham.
-- ============================================================================

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

  -- PIN tung nguoi dem (06 §3.2): du PIN, moi nguoi phai khop >= 1 PIN dua len.
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

  -- SOD_COUNT_INDEPENDENT (04 §6): kiem lai o luc submit.
  if v_count.kind = 'monthly_full' and not exists (
    select 1 from unnest(v_count.counter_ids) as u(uid)
    where not public._count_user_has_perm(u.uid, v_count.property_id, 'receiving.post', v_count.warehouse_id)
      and not public._count_user_has_perm(u.uid, v_count.property_id, 'requisition.issue', v_count.warehouse_id)
  ) then
    perform public._sod_check(v_count.property_id, 'COUNT_INDEPENDENT');
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
