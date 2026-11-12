-- ============================================================================
-- Q240 — 20261109557000_audit_hardening_rule_toggled_alert
--   Hau kiem review dot Q213/Q214 (audit trigger + co rule.*):
--
--   A. audit_trigger() che cot bi mat khoi old_data/new_data. Truoc day ham
--      ghi to_jsonb(row) nguyen ven, nen sau 536000 moi lan doi PIN ghi
--      profiles.pin_hash (hash PIN 4-6 so, de do nguoc) vao audit_log, doc
--      duoc boi moi nguoi co audit.view_all. Danh sach cot che nam trong
--      mang v_secret_keys; them cot moi vao day khi bang moi co bi mat.
--      LUU Y: audit_log bat bien (forbid_mutation) nen cac dong DA ghi
--      truoc migration nay (neu co) van con pin_hash — migration KHONG sua
--      duoc ma khong pha luat vang #2. Xem OPEN-QUESTIONS Q240.
--
--   B. Bo audit trigger khoi 4 bang nhieu ma 536000 vua gan:
--      doc_sequences, item_code_sequences (cap nhat moi lan sinh so chung
--      tu / ma vat tu), fifo_layers, fifo_allocations (doi theo tung buoc
--      post kho). Cac bang nay khong phai chung tu can truy vet: vet nam o
--      chinh chung tu va so cai stock_moves.
--
--   C. admin_setting_save: moi khi mot co rule.* DOI GIA TRI (tat hoac bat
--      lai) sinh alert RULE_TOGGLED cho owner/gm. Truoc day tat R25/R18
--      khong bao ai (chi co dong audit_log tu trigger settings), trong khi
--      mo khoa ngay (UNLOCK) bao owner ngay. Cap chuoi (property_id NULL)
--      sinh 1 alert cho moi khach san cua to chuc. Tat = 'red', bat lai =
--      'warn'. Dat lai dung gia tri cu khong sinh alert.
--      Phan con lai cua admin_setting_save sinh lai nguyen van tu ban
--      20261109543000 (Q215): khong doi dieu kien kiem tra/pham vi.
-- ============================================================================

-- --- A. audit_trigger: che cot bi mat -------------------------------------
create or replace function public.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  -- Cot khong duoc ghi vao audit_log (hash/bi mat). Them cot moi vao day.
  v_secret_keys constant text[] := array['pin_hash'];
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_headers jsonb;
  v_row_id text;
begin
  if tg_op <> 'INSERT' then
    v_old := to_jsonb(old) - v_secret_keys;
  end if;
  if tg_op <> 'DELETE' then
    v_new := to_jsonb(new) - v_secret_keys;
  end if;

  v_row := coalesce(v_new, v_old);
  v_row_id := coalesce(
    v_row ->> 'id',
    v_row ->> 'code',
    concat_ws(':', nullif(v_row ->> 'role_id', ''), nullif(v_row ->> 'permission_code', '')),
    concat_ws(':', nullif(v_row ->> 'user_id', ''), nullif(v_row ->> 'permission_code', '')),
    md5(v_row::text)
  );
  v_headers := coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb,
    '{}'::jsonb
  ) - 'authorization' - 'cookie' - 'apikey' - 'x-supabase-api-version';

  insert into public.audit_log (
    table_name,
    row_id,
    action,
    old_data,
    new_data,
    actor,
    client_info
  )
  values (
    tg_table_name,
    v_row_id,
    tg_op,
    v_old,
    v_new,
    auth.uid(),
    v_headers
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function public.audit_trigger() from public, anon, authenticated;

-- --- B. Bo audit tren 4 bang nhieu ----------------------------------------
drop trigger if exists trg_doc_sequences_audit on public.doc_sequences;
drop trigger if exists trg_item_code_sequences_audit on public.item_code_sequences;
drop trigger if exists trg_fifo_layers_audit on public.fifo_layers;
drop trigger if exists trg_fifo_allocations_audit on public.fifo_allocations;

-- --- C. Alert RULE_TOGGLED ------------------------------------------------
insert into public.permissions
  (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('alert.receive.rule_toggled', 'Cảnh báo',
   'Nhận cảnh báo bật/tắt ràng buộc nghiệp vụ',
   'Nhận cảnh báo khi quản trị bật hoặc tắt một ràng buộc nghiệp vụ (cờ rule.*: PIN nộp kiểm kê, PIN nhận hàng, chặn đóng kỳ).',
   'sensitive', 1652)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'alert.receive.rule_toggled'
from public.roles r
where r.code in ('owner', 'gm')
on conflict do nothing;

insert into public.alert_rules
  (org_id, property_id, code, threshold, channels, severity, urgent, active)
select o.id, null, 'RULE_TOGGLED', '{}'::jsonb,
  array['email', 'app']::text[], 'red', true, true
from public.organizations o
on conflict do nothing;

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
  v_old numeric;
  v_prop uuid;
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

  -- C: gia tri truoc khi doi (cung pham vi; chua luu thi lay mac dinh) de
  -- biet co rule.* co that su doi khong.
  if p_key like 'rule.%' then
    select (s.value #>> '{}')::numeric into v_old
    from public.settings s
    where s.org_id = p_org_id
      and s.property_id is not distinct from p_property_id
      and s.key = p_key;
    if v_old is null then
      v_old := (public._admin_setting_default(p_key) #>> '{}')::numeric;
    end if;
  end if;

  insert into public.settings (org_id, property_id, key, value, updated_by)
  values (p_org_id, p_property_id, p_key, to_jsonb(v_value), auth.uid())
  on conflict (org_id, property_id, key) do update
    set value = excluded.value, updated_by = excluded.updated_by;

  if p_key like 'rule.%' and v_old is distinct from v_value then
    for v_prop in
      select p.id
      from public.properties p
      where p.org_id = p_org_id
        and (p_property_id is null or p.id = p_property_id)
    loop
      perform public._create_alert(
        v_prop,
        'RULE_TOGGLED',
        case when v_value = 0 then 'red' else 'warn' end,
        case when v_value = 0 then 'Tắt ràng buộc ' else 'Bật lại ràng buộc ' end
          || upper(substring(p_key from 'rule\.(R[0-9]+)\.enabled')),
        jsonb_build_object(
          'key', p_key,
          'old_value', v_old,
          'new_value', v_value,
          'scope', case when p_property_id is null then 'org' else 'property' end,
          'changed_by', auth.uid()
        ),
        'setting',
        null
      );
    end loop;
  end if;

  return jsonb_build_object('ok', true, 'key', p_key, 'value', v_value::text);
end;
$$;

revoke all on function public.admin_setting_save(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.admin_setting_save(uuid, uuid, text, text)
  to authenticated;
