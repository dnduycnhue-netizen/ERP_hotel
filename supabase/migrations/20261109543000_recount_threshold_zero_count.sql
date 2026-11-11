-- ============================================================================
-- R26 + R30 (Q215) — 20261109543000_recount_threshold_zero_count
--   R26: count_submit doi tu nguong tuyet doi (>0.0001 la dem lai) sang
--     nguong lech % cau hinh (settings count_recount_threshold_pct, mac
--     dinh 5). Dong khop khi 2 nguoi dem bang nhau VA |lech| <= nguong %
--     cua ton so; ton so = 0 thi moi lech khac 0 deu vuot nguong.
--     variance_qty van luu dung so that khi dong khop.
--   R30: cho phep ghi so luong 0 khi dem (_count_qty_from_detail,
--     _count_bottle_qty chi tu choi < 0, khong tu choi 0 nua). Day la
--     sua loi, khong boc co. Luu y: form dem mobile van bo dong 0
--     (ngoai pham vi migration nay, xem CHANGELOG).
--   Key settings moi 'count_recount_threshold_pct' can mo CHECK
--     constraint cua bang settings + them vao _admin_setting_default,
--     admin_settings_list, admin_setting_save. Danh sach CHECK BAO GOM
--     CA 3 key 'rule.R25/R18/R32.enabled' cua migration 537000 (da ap
--     dung tren production): thu tu ap dung 537000 TRUOC, 543000 SAU.
--     (Danh lai tu 538000 -> 543000 ngay 11/11/2026: db push ap dung theo
--     thu tu version; neu giu 538000 thi migration 542000 (Q216) ap dung
--     SAU se ghi de count_submit bang ban khong co R26, lam mat nguong %.
--     543000 > 542000 nen count_submit cuoi cung la ban nay: R25 + R26.)
--     Gia tri rule.* luu dang so 1/0 (cot settings.value chi chap nhan
--     jsonb number). admin_settings_list o day DA gom ca 3 key rule.*
--     (thua tu 90/100/110 nhu 537000) vi 537000 da len production.
--   REBASE 11/11/2026 (sau khi 537000 merge): count_submit trong file
--     nay duoc sinh lai tu ban 542000 (Q216) — giu wrapper R25
--     `_rule_enabled`, fix crypt 533000 `extensions.crypt`, ma SoD moi
--     `SOD_COUNT_INDEPENDENT` — roi ap them diff R26 (nguong % +
--     v_within). Khong duoc ghi de bang ban 533000 cu (se xoa mat R25).
--   Khong dung R20 (dem mu): khong dung v_count_sheet,
--     stock_count_lines_select hay bat ky logic an so so nao.
-- ============================================================================

-- Mo CHECK constraint cua bang settings cho key moi. Tim ten constraint
-- theo noi dung (ten tu sinh), roi them lai voi day du 12 key:
-- 8 key cu + 3 key rule.* cua 537000 + count_recount_threshold_pct.
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

alter table public.settings add constraint settings_key_check check (key in (
  'price_spike_pct',
  'receiving_tolerance_pct',
  'market_advance_deadline_hours',
  'waste_approval_threshold_vnd',
  'count_random_items',
  'count_variance_threshold_pct',
  'count_recount_threshold_pct',
  'count_without_cc_factor',
  'invoice_price_tolerance_pct',
  'rule.R25.enabled',
  'rule.R18.enabled',
  'rule.R32.enabled'
));

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
    when 'count_recount_threshold_pct' then '5'::jsonb
    when 'rule.R25.enabled' then '1'::jsonb
    when 'rule.R18.enabled' then '1'::jsonb
    when 'rule.R32.enabled' then '1'::jsonb
    when 'count_without_cc_factor' then '0.7'::jsonb
    when 'invoice_price_tolerance_pct' then '1'::jsonb
    else null
  end
$$;
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
    ('count_recount_threshold_pct', 65),
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
    when 'count_recount_threshold_pct' then v_min := 0; v_max := 100;
    when 'rule.R25.enabled' then v_min := 0; v_max := 1;
    when 'rule.R18.enabled' then v_min := 0; v_max := 1;
    when 'rule.R32.enabled' then v_min := 0; v_max := 1;
    when 'count_without_cc_factor' then v_min := 0; v_max := 1;
    when 'invoice_price_tolerance_pct' then v_min := 0; v_max := 100;
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
-- Nguong lech cho phep khi dem lai (%) — setting
-- count_recount_threshold_pct, mac dinh 5. Bat chuoc y pattern cua
-- _receiving_tolerance_pct (20261109230000_receiving.sql:423).
create or replace function public._count_recount_threshold_pct(
  p_org_id uuid,
  p_property_id uuid
)
returns numeric
language plpgsql
stable
as $$
declare
  v_raw jsonb;
begin
  v_raw := public._setting_get(p_org_id, p_property_id, 'count_recount_threshold_pct');
  return coalesce((v_raw #>> '{}')::numeric, 5);
exception when others then
  return 5;
end;
$$;

revoke all on function public._count_recount_threshold_pct(uuid, uuid)
  from public, anon, authenticated;

-- R30: cho phep dem 0 — chi tu choi so am.
create or replace function public._count_qty_from_detail(
  p_item_id uuid,
  p_detail jsonb
)
returns numeric(18,4)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_item public.items%rowtype;
  v_elem jsonb;
  v_qty numeric(18,4);
  v_uom text;
  v_factor numeric(18,4);
  v_total numeric(18,4) := 0;
begin
  select * into v_item from public.items where id = p_item_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_detail is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  for v_elem in
    select * from jsonb_array_elements(
      case when jsonb_typeof(p_detail) = 'array' then p_detail
           else jsonb_build_array(p_detail) end
    )
  loop
    v_qty := nullif(v_elem ->> 'qty', '')::numeric;
    v_uom := nullif(v_elem ->> 'uom', '');
    if v_qty is null or v_qty < 0 or v_uom is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    if v_uom = v_item.stock_uom then
      v_factor := 1;
    else
      select factor_to_stock into v_factor
      from public.item_purchase_units
      where org_id = v_item.org_id and item_id = p_item_id and uom = v_uom;
      if not found then
        raise exception using errcode = 'P0001', message = 'ERR_UOM_UNKNOWN';
      end if;
    end if;

    v_total := v_total + v_qty * v_factor;
  end loop;

  if v_total < 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  return v_total;
end;
$$;
create or replace function public._count_bottle_qty(
  p_item_id uuid,
  p_bottle_weight_g numeric(18,4)
)
returns numeric(18,4)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_item public.items%rowtype;
  v_ml numeric(18,4);
  v_factor numeric(18,4);
begin
  select * into v_item from public.items where id = p_item_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_bottle_weight_g is null or p_bottle_weight_g < 0
    or v_item.tare_g is null or v_item.density_g_ml is null
    or v_item.density_g_ml <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_ml := (p_bottle_weight_g - v_item.tare_g) / v_item.density_g_ml;
  if v_ml < 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_item.stock_uom = 'ml' then
    return v_ml;
  end if;

  select factor_to_stock into v_factor
  from public.item_purchase_units
  where org_id = v_item.org_id and item_id = p_item_id and uom = 'ml';
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_UOM_UNKNOWN';
  end if;

  return v_ml * v_factor;
end;
$$;
-- R26: count_submit dung nguong % cau hinh thay cho 0.0001 tuyet doi.
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
  v_threshold numeric;
  v_within boolean;
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

  -- R26: nguong lech % cho phep khi dem lai (settings
  -- count_recount_threshold_pct, mac dinh 5). Ton so = 0 thi moi lech
  -- khac 0 deu vuot nguong (tranh chia cho 0, xem v_within ben duoi).
  v_threshold := public._count_recount_threshold_pct(v_count.org_id, v_count.property_id);

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
    -- Vong 1: hai nguoi khop nhau va lech trong nguong moi co final;
    -- lech vuot nguong -> dem lai (variance_qty van luu khi khop).
    for r_line in
      select * from public.stock_count_lines
      where count_id = p_count_id
      for update
    loop
      v_book := coalesce(r_line.book_qty, 0);
      if r_line.counted_qty_1 = r_line.counted_qty_2 then
        v_final := r_line.counted_qty_1;
        v_var := v_final - v_book;
        v_within := v_var = 0
          or (v_book <> 0 and abs(v_var / v_book * 100) <= v_threshold);
        if not v_within then
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
    -- con lech vuot nguong hoac hai nguoi van khac nhau -> 'red'.
    for r_line in
      select * from public.stock_count_lines
      where count_id = p_count_id and flag = 'recount'
      for update
    loop
      v_book := coalesce(r_line.book_qty, 0);
      v_final := coalesce(r_line.counted_qty_2, r_line.counted_qty_1);
      v_var := v_final - v_book;
      v_within := v_var = 0
        or (v_book <> 0 and abs(v_var / v_book * 100) <= v_threshold);
      update public.stock_count_lines set
        final_qty = v_final, variance_qty = v_var,
        variance_pct = case when v_book <> 0
          then round(v_var / v_book * 100, 4) else null end,
        flag = case
          when r_line.counted_qty_1 is distinct from r_line.counted_qty_2
            then 'red'
          when not v_within then 'red'
          else 'ok'
        end
      where id = r_line.id;
      if r_line.counted_qty_1 is distinct from r_line.counted_qty_2
        or not v_within then
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
