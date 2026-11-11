-- ============================================================================
-- T-014 follow-up fix (found by the pgTAP T-014 wave, 11/11/2026).
--
-- Q220 -- import_normalize_item calls import_parse_number(text), but the
--   function only exists as import_parse_number(jsonb) (42883):
--   line 636 of 180000 does v_vat := public.import_parse_number(p_raw ->>
--   'vat'); the ->> operator returns TEXT, and Postgres resolves the call
--   by argument type, so any items import batch containing a VAT value
--   aborted the whole import_create_batch (via import_validate_batch).
--   Rows without a VAT value never reached the line, which is why the bug
--   stayed latent: the VAT column could never be imported. The other four
--   import_parse_number call sites in 180000 all pass jsonb (-> operator)
--   and are correct; this is the only wrong one. Fix: wrap the text in
--   to_jsonb() so the existing (jsonb) overload parses it ('8' -> 8,
--   '1,5' -> 1.5, per the jsonb function's own string handling). Generated
--   programmatically from the original function text; EXACTLY ONE line
--   differs. No change to the function's contract, search_path, or grants.
-- ============================================================================

create or replace function public.import_normalize_item(
  p_org_id uuid, p_raw jsonb, p_group_map jsonb, p_resolution jsonb
) returns jsonb
language plpgsql
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_name text;
  v_name_norm text;
  v_code text;
  v_group_raw text;
  v_group_id uuid;
  v_group_kind text;
  v_group_prefix text;
  v_stock_uom text;
  v_recipe_uom text;
  v_factor numeric(18,4);
  v_purchase_uom text;
  v_purchase_factor numeric(18,4);
  v_key_item boolean := false;
  v_vat numeric(18,4);
  v_shelf integer;
  v_shelf_raw text;
  v_norm jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_existing record;
  v_sim numeric;
  v_sim_code text;
  v_kind_raw text;
begin
  v_name := btrim(normalize(coalesce(p_raw ->> 'name', ''), NFC));
  v_code := upper(btrim(coalesce(p_raw ->> 'code', '')));
  if (p_resolution ->> 'new_code') is not null and btrim(p_resolution ->> 'new_code') <> '' then
    v_code := upper(btrim(p_resolution ->> 'new_code'));
  end if;

  -- Dong trong: khong ten, khong ma -> bo qua, khong dem.
  if v_name = '' and v_code = '' then
    return jsonb_build_object('normalized', '{}'::jsonb, 'issues', '[]'::jsonb, 'blank', true);
  end if;

  if v_name = '' then
    v_issues := v_issues || jsonb_build_object(
      'code', 'EMPTY_NAME', 'field', 'name',
      'message', 'Thiếu tên vật tư.', 'severity', 'error');
  else
    v_name_norm := public.norm_text(v_name);
  end if;

  if v_code = '' then
    v_issues := v_issues || jsonb_build_object(
      'code', 'NO_CODE', 'field', 'code',
      'message', 'Thiếu mã vật tư: sẽ sinh mã theo tiền tố nhóm khi ghi.',
      'severity', 'warning');
    v_code := null;
  else
    -- Ma da ton tai trong DB?
    select i.id, i.code, i.name_norm into v_existing
    from public.items i
    where i.org_id = p_org_id and i.code = v_code;
    if found then
      if v_name_norm is not null and v_existing.name_norm = v_name_norm then
        v_issues := v_issues || jsonb_build_object(
          'code', 'EXISTING', 'field', 'code',
          'message', 'Mã ' || v_code || ' đã có trong danh mục với cùng tên: sẽ bỏ qua dòng này.',
          'severity', 'warning',
          'existing_id', v_existing.id);
      else
        v_issues := v_issues || jsonb_build_object(
          'code', 'DUP_CODE', 'field', 'code',
          'message', 'Mã ' || v_code || ' đã thuộc về vật tư khác trong danh mục.',
          'severity', 'error');
      end if;
    end if;
  end if;

  -- Ten trung / gan trung trong DB (pg_trgm, nguong 0,8 theo 07 section 2).
  if v_name_norm is not null then
    select i.id, i.code into v_existing
    from public.items i
    where i.org_id = p_org_id and i.name_norm = v_name_norm;
    if found then
      v_issues := v_issues || jsonb_build_object(
        'code', 'NEAR_DUP_NAME', 'field', 'name',
        'message', 'Tên đã tồn tại trong danh mục với mã ' || v_existing.code || ': cần gộp hoặc đổi tên.',
        'severity', 'error',
        'existing_id', v_existing.id, 'existing_code', v_existing.code);
    else
      select extensions.similarity(v_name_norm, i.name_norm), i.code
        into v_sim, v_sim_code
      from public.items i
      where i.org_id = p_org_id
      order by extensions.similarity(v_name_norm, i.name_norm) desc
      limit 1;
      if v_sim is not null and v_sim > 0.8 then
        v_issues := v_issues || jsonb_build_object(
          'code', 'NEAR_DUP_NAME', 'field', 'name',
          'message', 'Tên gần trùng với vật tư ' || v_sim_code || ' (độ tương đồng ' || round(v_sim, 2) || '): cân nhắc gộp.',
          'severity', 'warning',
          'existing_code', v_sim_code);
      end if;
    end if;
  end if;

  -- Nhom hang: anh xa qua group_map cua batch (khoa = gia tri cot Loai).
  v_group_raw := btrim(coalesce(p_raw ->> 'group_raw', ''));
  if (p_resolution ->> 'group_id') is not null and btrim(p_resolution ->> 'group_id') <> '' then
    v_group_id := (p_resolution ->> 'group_id')::uuid;
  elsif v_group_raw <> '' and p_group_map ? v_group_raw then
    v_group_id := (p_group_map ->> v_group_raw)::uuid;
  else
    v_group_id := null;
  end if;

  if v_group_id is null then
    v_issues := v_issues || jsonb_build_object(
      'code', 'UNKNOWN_GROUP', 'field', 'group_raw',
      'message', 'Chưa ánh xạ nhóm hàng cho loại "' || v_group_raw || '".',
      'severity', 'error');
  else
    select g.kind, g.code_prefix into v_group_kind, v_group_prefix
    from public.item_groups g
    where g.id = v_group_id and g.org_id = p_org_id;
    if not found then
      v_issues := v_issues || jsonb_build_object(
        'code', 'UNKNOWN_GROUP', 'field', 'group_raw',
        'message', 'Nhóm hàng đã chọn không thuộc tổ chức này.',
        'severity', 'error');
      v_group_kind := null;
      v_group_prefix := null;
    elsif v_group_raw <> '' and v_group_raw ~* '^ccdc$' and v_group_kind <> 'ccdc' then
      v_issues := v_issues || jsonb_build_object(
        'code', 'GROUP_KIND_MISMATCH', 'field', 'group_raw',
        'message', 'Loại CCDC nên ánh xạ vào nhóm kind ccdc.',
        'severity', 'warning');
    end if;
  end if;

  -- Don vi kho / cong thuc.
  if (p_resolution ->> 'stock_uom') is not null and btrim(p_resolution ->> 'stock_uom') <> '' then
    v_stock_uom := public.import_normalize_uom(p_resolution ->> 'stock_uom');
  else
    v_stock_uom := public.import_normalize_uom(p_raw ->> 'stock_uom_raw');
  end if;
  if v_stock_uom is null then
    v_issues := v_issues || jsonb_build_object(
      'code', 'UNKNOWN_UOM', 'field', 'stock_uom_raw',
      'message', 'Đơn vị kho "' || coalesce(p_raw ->> 'stock_uom_raw', '') || '" chưa có trong danh mục hoặc chưa có biến thể ánh xạ.',
      'severity', 'error');
  end if;

  v_recipe_uom := public.import_normalize_uom(p_raw ->> 'recipe_uom_raw');
  if (p_raw ->> 'recipe_uom_raw') is not null
    and btrim(p_raw ->> 'recipe_uom_raw') <> ''
    and v_recipe_uom is null then
    v_issues := v_issues || jsonb_build_object(
      'code', 'UNKNOWN_UOM', 'field', 'recipe_uom_raw',
      'message', 'Đơn vị công thức "' || (p_raw ->> 'recipe_uom_raw') || '" chưa có trong danh mục hoặc chưa có biến thể ánh xạ.',
      'severity', 'error');
  end if;

  -- He so qui doi kho -> cong thuc.
  if (p_resolution ->> 'factor') is not null then
    v_factor := public.import_parse_number(p_resolution -> 'factor');
  else
    v_factor := public.import_parse_number(p_raw -> 'factor_raw');
  end if;
  if v_recipe_uom is not null and v_stock_uom is not null and v_recipe_uom <> v_stock_uom then
    if v_factor is null or v_factor <= 0 then
      v_issues := v_issues || jsonb_build_object(
        'code', 'NO_FACTOR', 'field', 'factor_raw',
        'message', 'Thiếu hệ số quy đổi từ ' || v_stock_uom || ' sang ' || v_recipe_uom || '.',
        'severity', case when v_group_kind in ('food', 'beverage') then 'error' else 'warning' end);
      v_factor := null;
    elsif v_factor = 1 then
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_FACTOR', 'field', 'factor_raw',
        'message', 'Hệ số = 1 trong khi đơn vị kho (' || v_stock_uom || ') khác đơn vị công thức (' || v_recipe_uom || '): kiểm tra lại số liệu.',
        'severity', 'warning');
    end if;
  else
    -- Cung don vi hoac khong co don vi cong thuc: khong can he so.
    v_factor := null;
  end if;

  -- Quy cach mua (mau chuan mau_vat_tu.xlsx): thieu he so chi la canh bao.
  v_purchase_uom := public.import_normalize_uom(p_raw ->> 'purchase_uom_raw');
  if (p_raw ->> 'purchase_uom_raw') is not null
    and btrim(p_raw ->> 'purchase_uom_raw') <> '' then
    if v_purchase_uom is null then
      v_issues := v_issues || jsonb_build_object(
        'code', 'UNKNOWN_UOM', 'field', 'purchase_uom_raw',
        'message', 'Đơn vị mua "' || (p_raw ->> 'purchase_uom_raw') || '" chưa có trong danh mục.',
        'severity', 'error');
    else
      v_purchase_factor := public.import_parse_number(p_raw -> 'purchase_factor_raw');
      if v_purchase_factor is null or v_purchase_factor <= 0 then
        v_issues := v_issues || jsonb_build_object(
          'code', 'NO_FACTOR', 'field', 'purchase_factor_raw',
          'message', 'Thiếu hệ số quy đổi mua -> kho cho đơn vị ' || v_purchase_uom || ': sẽ không tạo quy cách mua.',
          'severity', 'warning');
        v_purchase_factor := null;
      end if;
    end if;
  end if;

  -- key_item / vat / han dung (cac cot tuy chon trong mau chuan docs/07 §5).
  if btrim(coalesce(p_raw ->> 'key_item', '')) <> '' then
    v_key_item := lower(btrim(p_raw ->> 'key_item')) in ('1', 'true', 'x', 'co', 'yes', 'y');
  end if;
  if btrim(coalesce(p_raw ->> 'vat', '')) <> '' then
    v_vat := public.import_parse_number(to_jsonb(p_raw ->> 'vat'));
    if v_vat is null or v_vat < 0 or v_vat > 100 then
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_VALUE', 'field', 'vat',
        'message', 'VAT không hợp lệ (phải là số 0–100): "' || (p_raw ->> 'vat') || '".',
        'severity', 'error');
    end if;
  end if;
  v_shelf_raw := btrim(coalesce(p_raw ->> 'expiry_days', ''));
  if v_shelf_raw <> '' then
    begin
      v_shelf := v_shelf_raw::integer;
      if v_shelf <= 0 then
        raise exception 'not positive';
      end if;
    exception when others then
      v_shelf := null;
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_VALUE', 'field', 'expiry_days',
        'message', 'Hạn dùng (ngày) không hợp lệ: "' || v_shelf_raw || '".',
        'severity', 'error');
    end;
  end if;

  v_norm := jsonb_build_object(
    'code', v_code,
    'name', nullif(v_name, ''),
    'name_en', nullif(btrim(coalesce(p_raw ->> 'name_en', '')), ''),
    'group_id', v_group_id,
    'group_kind', v_group_kind,
    'group_prefix', v_group_prefix,
    'is_ccdc', (v_group_kind = 'ccdc'),
    'stock_uom', v_stock_uom,
    'recipe_uom', v_recipe_uom,
    'stock_to_recipe', v_factor,
    'cost_group', nullif(btrim(coalesce(p_raw ->> 'cost_group', '')), ''),
    'legacy_code', nullif(btrim(coalesce(p_raw ->> 'legacy_code', '')), ''),
    'purchase_uom', v_purchase_uom,
    'purchase_factor', v_purchase_factor,
    'key_item', v_key_item,
    'vat_rate', v_vat,
    'shelf_life_days', v_shelf
  );

  return jsonb_build_object('normalized', v_norm, 'issues', v_issues, 'blank', false);
end $$;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109541000_import_normalize_item_vat_text_to_jsonb',
  'INSERT',
  jsonb_build_object('event', 't014_q220_fix', 'task', 'T-014'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
