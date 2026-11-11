-- ============================================================================
-- Q214: co che bat/tat rang buoc bang cau hinh (rule toggles) + noi 3 ma
--   R25 (PIN nop phieu kiem ke), R18 (PIN post phieu nhan), R32 (chan dong
--   ky khi con PO treo / tam ung qua han).
--   * Ham moi _rule_enabled(property, ma) doc settings key
--     'rule.<ma>.enabled': tra theo property truoc, fallback ban org
--     (property_id IS NULL), khong co thi mac dinh TRUE (van chan nhu cu).
--   * LUU Y ve kieu gia tri: cot settings.value la jsonb chi chap nhan
--     number (CHECK jsonb_typeof = 'number') va admin_setting_save ep
--     p_value::numeric, nen co luu dang number 0 = tat / 1 = bat (khong
--     luu duoc text 'true'/'false'). _rule_enabled van parse ca dang
--     string ('false'/'0'/'off') de phong khi co nguoi chen truc tiep.
--   * settings.key CHECK duoc mo rong them 3 key; _admin_setting_default
--     tra mac dinh '1' cho 3 key; admin_setting_save gioi han 0..1
--     (nguyen); admin_settings_list liet ke them 3 key.
--   * R25 TAT: chi can PIN nguoi nop (van giu R21 >=2 nguoi dem, R22 SoD
--     doc lap, van kiem nguoi nop la 1 trong 2 nguoi dem).
--   * R18 TAT: bo _verify_pin khi receiving_post (van giu SoD_PO_RECEIVER
--     va SOD_MARKET_BUYER_RECEIVER).
--   * R32 TAT: 2 dieu kien PO partially_received >30 ngay va tam ung
--     overdue chuyen thanh alert PERIOD_CLOSE_WARNING (ma moi, seed kem
--     quyen alert.receive.period_close_warning cho owner/gm/
--     chief_accountant), khong chan; van chan cung ERR_COUNT_NOT_LOCKED.
--   * period_close dong ky theo phap nhan nen lay co theo KS dau tien
--     cua phap nhan (dat co o cap chuoi de ap dung cho ca phap nhan).
-- ============================================================================
-- Mo rong CHECK settings.key them 3 key rule.*. Ten constraint duoc tim
-- theo dinh nghia (ten tu sinh co the khac nhau tuy DB) de migration chay
-- lai duoc.
do $$
declare
  v_con text;
begin
  select conname into v_con
  from pg_constraint
  where conrelid = 'public.settings'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%price_spike_pct%';
  if v_con is not null then
    execute format('alter table public.settings drop constraint %I', v_con);
  end if;
end $$;

alter table public.settings
  add constraint settings_key_check check (key in (
    'price_spike_pct',
    'receiving_tolerance_pct',
    'market_advance_deadline_hours',
    'waste_approval_threshold_vnd',
    'count_random_items',
    'count_variance_threshold_pct',
    'count_without_cc_factor',
    'invoice_price_tolerance_pct',
    'rule.R25.enabled',
    'rule.R18.enabled',
    'rule.R32.enabled'
  ));
create or replace function public._rule_enabled(
  p_property_id uuid,
  p_rule_code text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_value jsonb;
begin
  -- Chi 3 ma co da biet; ma la -> mac dinh BAT (fail closed).
  if p_rule_code is null or p_rule_code not in ('R25', 'R18', 'R32') then
    return true;
  end if;
  if p_property_id is null then
    return true;
  end if;

  select p.org_id into v_org_id
  from public.properties p
  where p.id = p_property_id;
  if v_org_id is null then
    return true;
  end if;

  -- Tra theo property truoc, neu khong co thi tra ban org (property_id
  -- IS NULL), neu khong co nua thi mac dinh BAT.
  select s.value into v_value
  from public.settings s
  where s.org_id = v_org_id and s.property_id = p_property_id
    and s.key = 'rule.' || p_rule_code || '.enabled';
  if v_value is null then
    select s.value into v_value
    from public.settings s
    where s.org_id = v_org_id and s.property_id is null
      and s.key = 'rule.' || p_rule_code || '.enabled';
  end if;
  if v_value is null then
    return true;
  end if;

  -- Gia tri luu dang jsonb number (0 = tat, khac 0 = bat) theo CHECK cua
  -- bang settings; cac nhanh string/boolean chi de phong khi co nguoi
  -- chen truc tiep (hien CHECK chan kieu khac number).
  if jsonb_typeof(v_value) = 'number' then
    return (v_value #>> '{}')::numeric <> 0;
  elsif jsonb_typeof(v_value) = 'boolean' then
    return (v_value #>> '{}')::boolean;
  elsif jsonb_typeof(v_value) = 'string' then
    return lower(btrim(v_value #>> '{}')) not in ('false', '0', 'off', 'no', '');
  else
    return true;
  end if;
end;
$$;

revoke all on function public._rule_enabled(uuid, text) from public, anon;
grant execute on function public._rule_enabled(uuid, text) to authenticated;

-- --- _admin_setting_default: mac dinh '1' (BAT) cho 3 co ---
create or replace function public._admin_setting_default(p_key text)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  select case p_key
    when 'price_spike_pct' then '10'::jsonb
    when 'receiving_tolerance_pct' then '5'::jsonb
    when 'market_advance_deadline_hours' then '24'::jsonb
    when 'waste_approval_threshold_vnd' then '1000000'::jsonb
    when 'count_random_items' then '3'::jsonb
    when 'count_variance_threshold_pct' then '3'::jsonb
    when 'count_without_cc_factor' then '0.7'::jsonb
    when 'invoice_price_tolerance_pct' then '1'::jsonb
    when 'rule.R25.enabled' then '1'::jsonb
    when 'rule.R18.enabled' then '1'::jsonb
    when 'rule.R32.enabled' then '1'::jsonb
    else null
  end
$$;

-- --- admin_settings_list: liet ke them 3 co ---
create or replace function public.admin_settings_list(
  p_org_id uuid,
  p_property_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_settings jsonb;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.settings.manage'
  );

  select jsonb_agg(
    jsonb_build_object(
      'key', k.key,
      'value', public._setting_get(p_org_id, p_property_id, k.key) #>> '{}',
      'source', case
        when ps.id is not null then 'property'
        when os.id is not null then 'organization'
        else 'default'
      end
    )
    order by k.sort_order
  )
  into v_settings
  from (values
    ('price_spike_pct', 10),
    ('receiving_tolerance_pct', 20),
    ('market_advance_deadline_hours', 30),
    ('waste_approval_threshold_vnd', 40),
    ('count_random_items', 50),
    ('count_variance_threshold_pct', 60),
    ('count_without_cc_factor', 70),
    ('invoice_price_tolerance_pct', 80),
    ('rule.R25.enabled', 90),
    ('rule.R18.enabled', 100),
    ('rule.R32.enabled', 110)
  ) as k(key, sort_order)
  left join public.settings ps
    on ps.org_id = p_org_id and ps.property_id = p_property_id and ps.key = k.key
  left join public.settings os
    on os.org_id = p_org_id and os.property_id is null and os.key = k.key;

  return coalesce(v_settings, '[]'::jsonb);
end;
$$;

-- --- admin_setting_save: gioi han 0..1 (nguyen) cho 3 co ---
create or replace function public.admin_setting_save(
  p_org_id uuid,
  p_property_id uuid,
  p_key text,
  p_value text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_value numeric;
  v_min numeric;
  v_max numeric;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.settings.manage'
  );

  if public._admin_setting_default(p_key) is null then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  v_value := p_value::numeric;
  case p_key
    when 'price_spike_pct' then v_min := 0; v_max := 1000;
    when 'receiving_tolerance_pct' then v_min := 0; v_max := 100;
    when 'market_advance_deadline_hours' then v_min := 1; v_max := 720;
    when 'waste_approval_threshold_vnd' then v_min := 0; v_max := 9999999999999999;
    when 'count_random_items' then v_min := 2; v_max := 3;
    when 'count_variance_threshold_pct' then v_min := 0; v_max := 100;
    when 'count_without_cc_factor' then v_min := 0; v_max := 1;
    when 'invoice_price_tolerance_pct' then v_min := 0; v_max := 100;
    when 'rule.R25.enabled' then v_min := 0; v_max := 1;
    when 'rule.R18.enabled' then v_min := 0; v_max := 1;
    when 'rule.R32.enabled' then v_min := 0; v_max := 1;
    else raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end case;

  if v_value < v_min or v_value > v_max
    or (p_key in ('market_advance_deadline_hours', 'count_random_items',
      'rule.R25.enabled', 'rule.R18.enabled', 'rule.R32.enabled')
      and v_value <> trunc(v_value))
    or (p_key = 'waste_approval_threshold_vnd' and v_value <> trunc(v_value))
    or (p_key not in (
      'market_advance_deadline_hours',
      'waste_approval_threshold_vnd',
      'count_random_items',
      'count_without_cc_factor'
    ) and v_value <> round(v_value, 2))
    or (p_key = 'count_without_cc_factor' and v_value <> round(v_value, 4)) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  insert into public.settings (org_id, property_id, key, value, updated_by)
  values (p_org_id, p_property_id, p_key, to_jsonb(v_value), auth.uid())
  on conflict (org_id, property_id, key) do update
    set value = excluded.value, updated_by = excluded.updated_by;

  return jsonb_build_object('ok', true, 'key', p_key, 'value', v_value::text);
end;
$$;

-- --- count_submit: R25 ---
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

-- --- receiving_post: R18 ---
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

-- --- period_close: R32 ---
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
  v_property_id uuid;
  v_po_unresolved integer;
  v_adv_overdue integer;
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

  -- Co R32 doc theo property (pham vi dong ky la phap nhan): lay KS dau
  -- tien cua phap nhan; neu co dat o cap chuoi thi _rule_enabled tu
  -- fallback ve cap chuoi. Neu phap nhan chua co KS nao thi co mac dinh
  -- BAT (fail closed) vi _rule_enabled(null, ...) tra true.
  select p.id into v_property_id
  from public.properties p
  where p.legal_entity_id = p_entity_id
  order by p.created_at, p.id
  limit 1;

  -- 05 §6.1.5 + §10: moi kho cua phap nhan (da ton tai trong thang) phai co
  -- dot monthly_full thang do o 'locked'/'adjusted'.
  if exists (
    select 1
    from public.properties p
    join public.warehouses w on w.property_id = p.id
    where p.legal_entity_id = p_entity_id
      and w.created_at < (make_date(p_year, p_month, 1) + interval '1 month')
      and not exists (
        select 1 from public.stock_counts c
        where c.warehouse_id = w.id
          and c.kind = 'monthly_full'
          and extract(year from c.business_date)::integer = p_year
          and extract(month from c.business_date)::integer = p_month
          and c.status in ('locked', 'adjusted')
      )
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_COUNT_NOT_LOCKED';
  end if;

  -- 05 §10: khong PO partially_received co expected_date qua 30 ngay (Q29).
  -- R32 (co rule.R32.enabled): khi co BAT (mac dinh) chan cung nhu cu;
  -- khi co TAT chi canh bao bang alert PERIOD_CLOSE_WARNING, khong chan.
  select count(*) into v_po_unresolved
  from public.purchase_orders po
  join public.properties p on p.id = po.property_id
  where p.legal_entity_id = p_entity_id
    and po.status = 'partially_received'
    and po.expected_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date - interval '30 days';
  if v_po_unresolved > 0 then
    if public._rule_enabled(v_property_id, 'R32') then
      raise exception using errcode = 'P0001', message = 'ERR_PO_UNRESOLVED';
    else
      perform public._create_alert(
        v_property_id,
        'PERIOD_CLOSE_WARNING',
        'warn',
        'Đóng kỳ khi còn PO treo quá 30 ngày',
        jsonb_build_object('reason', 'po_unresolved', 'year', p_year, 'month', p_month, 'count', v_po_unresolved)
      );
    end if;
  end if;

  -- 05 §10: khong tam ung qua han.
  -- R32 (co rule.R32.enabled): nhu PO o tren — BAT thi chan cung,
  -- TAT thi chi canh bao bang alert PERIOD_CLOSE_WARNING.
  select count(*) into v_adv_overdue
  from public.advances a
  join public.properties p on p.id = a.property_id
  where p.legal_entity_id = p_entity_id
    and a.status = 'overdue';
  if v_adv_overdue > 0 then
    if public._rule_enabled(v_property_id, 'R32') then
      raise exception using errcode = 'P0001', message = 'ERR_ADVANCE_OVERDUE';
    else
      perform public._create_alert(
        v_property_id,
        'PERIOD_CLOSE_WARNING',
        'warn',
        'Đóng kỳ khi còn tạm ứng quá hạn',
        jsonb_build_object('reason', 'advance_overdue', 'year', p_year, 'month', p_month, 'count', v_adv_overdue)
      );
    end if;
  end if;

  insert into public.accounting_periods (legal_entity_id, year, month, status, closed_by, closed_at)
  values (p_entity_id, p_year, p_month, 'closed', auth.uid(), now())
  on conflict (legal_entity_id, year, month)
  do update set status = 'closed', closed_by = auth.uid(), closed_at = now(), updated_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

revoke all on function public.period_close(uuid, integer, integer) from public, anon;
grant execute on function public.period_close(uuid, integer, integer) to authenticated;

-- Seed ma alert moi cho R32 khi co tat: 1 alert moi dieu kien (payload
-- phan biet bang reason 'po_unresolved' / 'advance_overdue').
insert into public.permissions
  (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('alert.receive.period_close_warning', 'Cảnh báo',
   'Nhận cảnh báo đóng kỳ có tồn đọng',
   'Nhận cảnh báo khi đóng kỳ mà còn PO treo quá hạn hoặc tạm ứng quá hạn (cờ R32 tắt).',
   'normal', 1651)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'alert.receive.period_close_warning'
from public.roles r
where r.code in ('owner', 'gm', 'chief_accountant')
on conflict do nothing;

insert into public.alert_rules
  (org_id, property_id, code, threshold, channels, severity, urgent, active)
select o.id, null, 'PERIOD_CLOSE_WARNING', '{}'::jsonb,
  array['app']::text[], 'warn', false, true
from public.organizations o
on conflict do nothing;
