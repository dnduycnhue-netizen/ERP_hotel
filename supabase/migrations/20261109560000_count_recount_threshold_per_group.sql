-- ============================================================================
-- 20261109560000 — R26 theo nhom hang + tach nhom con (quyet dinh Duy 2a,
-- 12/11/2026) — R30 khong doi SQL (RPC da cho 0, chi sua form/Zod).
--
-- R26 (docs/05-BUSINESS-RULES.md §6.2): nguong dem lai theo nhom:
--   ruou manh 1,5% / thit ca 3% / rau 5% / mac dinh 3%; ho so
--   without_cc nhan he so count_without_cc_factor (mac dinh 0,7).
--   Vi 10 nhom goc khong tach duoc (DU gop ruou+bia+nuoc ngot, TP gop
--   thit+ca+rau+do kho; items khong co cot phan loai con) nen Duy chot
--   TACH NHOM CON MOI thay vi gan tam:
--   - RUOU  'Ruou manh'  beverage  1,5%  (chua co vat tu nao — khong co
--     ruou manh trong du lieu mau/seed; MB-VANG 'Ruou vang' la vang, khong
--     phai ruou manh, giu nguyen nhom MB)
--   - THIT  'Thit & Ca'   food      3%    (47 ma tu loai 'Thit',
--     'Thit Nguoi', 'hai san' trong file NVL mau)
--   - RAU   'Rau cu'      food      5%    (85 ma tu loai 'Rau Cu',
--     'Rau Mem', tru 3 ma khong chac: NVL0262 dau hu lat, NVL0220 trai
--     Quat, NVL0133 Du du Chin — de nguyen TP, cho Duy chot sau)
--   Nhom cu con lai giu recount_threshold_pct = null (dung nguong chung
--   count_recount_threshold_pct, mac dinh 5).
--
-- count_submit sinh lai NGUYEN VAN tu 20261109543000 (ghi de ban cu),
-- chi thay doi: nguong tinh THEO TUNG DONG qua helper moi
-- _count_line_threshold_pct (nhom -> chung -> nhan he so without_cc).
-- Giu nguyen: R25 (public._rule_enabled), extensions.crypt, ma
-- SOD_COUNT_INDEPENDENT, logic R26 (ton so 0 -> moi lech deu vuot).
-- KHONG DUNG: audit_trigger(), admin_setting_save,
-- _admin_setting_default, admin_settings_list, settings_key_check
-- (Claude Code lam song song). Khong them key settings moi.
-- ============================================================================

-- §1. Cot nguong rieng tung nhom (null = dung nguong chung).
alter table public.item_groups
  add column if not exists recount_threshold_pct numeric(18,2)
    check (recount_threshold_pct is null
      or (recount_threshold_pct >= 0 and recount_threshold_pct <= 100));

-- §2. Nhom con moi cho moi org (theo pattern golive 140000: insert per-org,
-- on conflict do nothing — idempotent khi chay lai / org moi se them sau
-- qua seed hoac UI quan tri).
insert into public.item_groups (org_id, code_prefix, name, kind, recount_threshold_pct)
select o.id, g.code_prefix, g.name, g.kind, g.threshold_pct
from public.organizations o
cross join (
  values
    ('RUOU', 'Rượu mạnh', 'beverage', 1.5::numeric(18,2)),
    ('THIT', 'Thịt & Cá', 'food', 3::numeric(18,2)),
    ('RAU', 'Rau củ', 'food', 5::numeric(18,2))
) as g(code_prefix, name, kind, threshold_pct)
on conflict (org_id, code_prefix) do nothing;

-- §3. Chuyen vat tu hien co sang nhom moi — CHI nhung ma phan loai CHAC
-- CHAN duoc tu cot 'Loai' file NVL mau (Lst_2020_DL_Buffet.xlsx, doi
-- chieu khop file Lst_Alacarte_foodcost.xlsx, 0 xung dot; seed
-- docs/sample-data/seed-sample-data.sql chua toan bo 308 ma trong 319
-- ma Excel, cung loai). Chi chuyen tu nhom TP; ma khong co trong DB
-- (org chua seed du) thi UPDATE khop 0 dong, khong loi.
do $$
declare
  v_org record;
  v_tp uuid;
  v_thit uuid;
  v_rau uuid;
begin
  for v_org in select id from public.organizations loop
    select id into v_tp from public.item_groups
      where org_id = v_org.id and code_prefix = 'TP';
    select id into v_thit from public.item_groups
      where org_id = v_org.id and code_prefix = 'THIT';
    select id into v_rau from public.item_groups
      where org_id = v_org.id and code_prefix = 'RAU';
    if v_tp is null or v_thit is null or v_rau is null then
      continue;
    end if;

    update public.items set group_id = v_thit
    where org_id = v_org.id and group_id = v_tp
      and code in ('NVL0009', 'NVL0017', 'NVL0029', 'NVL0046', 'NVL0061', 'NVL0063', 'NVL0080', 'NVL0088', 'NVL0090', 'NVL0091', 'NVL0092', 'NVL0093', 'NVL0096', 'NVL0097', 'NVL0102', 'NVL0103', 'NVL0107', 'NVL0144', 'NVL0152', 'NVL0153', 'NVL0155', 'NVL0261', 'NVL0273', 'NVL0274', 'NVL0275', 'NVL0276', 'NVL0278', 'NVL0280', 'NVL0281', 'NVL0358', 'NVL0388', 'NVL0403', 'NVL0417', 'NVL0430', 'NVL0431', 'NVL0436', 'NVL0520', 'NVL0525', 'NVL0531', 'NVL0536', 'NVL0565', 'NVL0572', 'NVL0573', 'NVL0576', 'NVL0592', 'NVL0622', 'NVL0629');

    update public.items set group_id = v_rau
    where org_id = v_org.id and group_id = v_tp
      and code in ('NVL 0610', 'NVL0007', 'NVL0011', 'NVL0012', 'NVL0020', 'NVL0021', 'NVL0022', 'NVL0023', 'NVL0028', 'NVL0040', 'NVL0048', 'NVL0049', 'NVL0055', 'NVL0056', 'NVL0066', 'NVL0067', 'NVL0068', 'NVL0071', 'NVL0073', 'NVL0074', 'NVL0077', 'NVL0095', 'NVL0098', 'NVL0099', 'NVL0104', 'NVL0105', 'NVL0108', 'NVL0114', 'NVL0115', 'NVL0118', 'NVL0119', 'NVL0149', 'NVL0188', 'NVL0190', 'NVL0194', 'NVL0195', 'NVL0196', 'NVL0197', 'NVL0198', 'NVL0199', 'NVL0200', 'NVL0201', 'NVL0202', 'NVL0205', 'NVL0206', 'NVL0209', 'NVL0221', 'NVL0222', 'NVL0226', 'NVL0231', 'NVL0235', 'NVL0239', 'NVL0240', 'NVL0241', 'NVL0244', 'NVL0246', 'NVL0257', 'NVL0260', 'NVL0263', 'NVL0264', 'NVL0265', 'NVL0266', 'NVL0267', 'NVL0270', 'NVL0271', 'NVL0362', 'NVL0363', 'NVL0364', 'NVL0366', 'NVL0371', 'NVL0376', 'NVL0408', 'NVL0409', 'NVL0413', 'NVL0420', 'NVL0433', 'NVL0507', 'NVL0532', 'NVL0535', 'NVL0555', 'NVL0557', 'NVL0571', 'NVL0631', 'NVL0634', 'NVL0638');
  end loop;
end;
$$;

-- §4. Helper doc he so without_cc (pattern _count_recount_threshold_pct
-- o 543000: _setting_get, mac dinh 0,7, loi -> 0,7).
create or replace function public._count_without_cc_factor(
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
  v_raw := public._setting_get(p_org_id, p_property_id, 'count_without_cc_factor');
  return coalesce((v_raw #>> '{}')::numeric, 0.7);
exception when others then
  return 0.7;
end;
$$;

revoke all on function public._count_without_cc_factor(uuid, uuid)
  from public, anon, authenticated;

-- §4b. Nguong hieu dung THEO DONG: nhom cua vat tu (neu co) -> nguong
-- chung -> nhan he so without_cc khi property.sod_profile =
-- 'without_cc'. Mac dinh 5 neu co loi (giong helper goc).
create or replace function public._count_line_threshold_pct(
  p_org_id uuid,
  p_property_id uuid,
  p_item_id uuid
)
returns numeric
language plpgsql
stable
as $$
declare
  v_threshold numeric;
  v_profile text;
begin
  select g.recount_threshold_pct into v_threshold
  from public.items i
  join public.item_groups g on g.id = i.group_id
  where i.id = p_item_id;

  if v_threshold is null then
    v_threshold := public._count_recount_threshold_pct(p_org_id, p_property_id);
  end if;

  select sod_profile into v_profile
  from public.properties
  where id = p_property_id;

  if v_profile = 'without_cc' then
    v_threshold := v_threshold * public._count_without_cc_factor(p_org_id, p_property_id);
  end if;

  return v_threshold;
exception when others then
  return 5;
end;
$$;

revoke all on function public._count_line_threshold_pct(uuid, uuid, uuid)
  from public, anon, authenticated;

-- §5. R26 theo nhom: count_submit sinh lai NGUYEN VAN tu 543000, chi doi
-- cach tinh nguong — tu 1 nguong chung sang nguong theo tung dong
-- (helper §4b). Moi logic khac giu nguyen.
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

  -- R26 theo nhom (560000): nguong tinh THEO TUNG DONG qua
  -- _count_line_threshold_pct (nhom cua vat tu -> nguong chung -> nhan
  -- he so without_cc). Ton so = 0 thi moi lech khac 0 deu vuot nguong
  -- (tranh chia cho 0, xem v_within ben duoi).

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
      v_threshold := public._count_line_threshold_pct(
        v_count.org_id, v_count.property_id, r_line.item_id);
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
      v_threshold := public._count_line_threshold_pct(
        v_count.org_id, v_count.property_id, r_line.item_id);
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
