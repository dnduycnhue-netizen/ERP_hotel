-- Q217: supplier_bank_accounts.org_id is NOT NULL with no default
-- (20261109030000_master_data.sql:112), but two code paths inserted rows
-- without it, so EVERY bank-account insert failed with 23502:
--   (1) supplier_bank_request (20261109160000) — the UI bank-change flow
--       never worked since T-013; found by pgTAP T-013 attempt 1, test 23.
--   (2) import_commit_batch (20261109180000) — Excel import of a supplier
--       WITH a bank account failed the same way (same 23502).
-- Fix: CREATE OR REPLACE both functions; each differs from the original in
-- exactly one INSERT (org_id added: v_org / v_batch.org_id). No other
-- behaviour changes. No new permissions, no UI change.
create or replace function public.supplier_bank_request(
  p_property_id uuid,
  p_supplier_id uuid,
  p_bank_name text,
  p_account_no text,
  p_account_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_sup record;
  v_id uuid;
  v_warnings jsonb := '[]'::jsonb;
begin
  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:supplier.bank.request';
  end if;
  perform public.require_perm(p_property_id, 'supplier.bank.request');

  select * into v_sup
  from public.suppliers
  where id = p_supplier_id and org_id = v_org;
  if not found then
    raise exception 'ERR_FORBIDDEN:supplier.bank.request';
  end if;
  if v_sup.status not in ('pending', 'active') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if p_bank_name is null or btrim(p_bank_name) = ''
    or p_account_no is null or btrim(p_account_no) = ''
    or p_account_name is null or btrim(p_account_name) = '' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  -- Warning (not blocking): the account number is already used by another
  -- supplier. The same-supplier duplicate is blocked by the unique index.
  if exists (
    select 1
    from public.supplier_bank_accounts b
    where b.supplier_id <> p_supplier_id
      and b.status in ('pending', 'active')
      and b.account_no = btrim(p_account_no)
  ) then
    v_warnings := v_warnings || jsonb_build_object(
      'code', 'BANK_ACCOUNT_DUPLICATE',
      'message', 'Số tài khoản đã được dùng bởi một nhà cung cấp khác'
    );
  end if;

  insert into public.supplier_bank_accounts
    (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by)
  values
    (v_org, p_supplier_id, btrim(p_bank_name), btrim(p_account_no),
     btrim(p_account_name), 'pending', auth.uid())
  returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'warnings', v_warnings
  );
end;
$$;

create or replace function public.import_commit_batch(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_batch public.import_batches%rowtype;
  v_row public.import_rows%rowtype;
  v_norm jsonb;
  v_code text;
  v_item_id uuid;
  v_supplier_id uuid;
  v_created integer := 0;
  v_skipped integer := 0;
  v_merged integer := 0;
  v_existing_id uuid;
  v_has_existing boolean;
begin
  select * into v_batch from public.import_batches where id = p_batch_id for update;
  if not found then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy phiên import %', p_batch_id;
  end if;
  if v_batch.status <> 'validated' then
    raise exception 'ERR_INVALID_STATUS: phiên import chưa đạt kiểm tra (còn lỗi hoặc đã ghi/hủy)';
  end if;

  perform public.require_perm(v_batch.property_id, 'item.import');

  for v_row in
    select * from public.import_rows
    where batch_id = p_batch_id and status in ('ok', 'warning', 'merged', 'skipped')
    order by row_no
  loop
    if v_row.status = 'merged' then
      v_merged := v_merged + 1;
      continue;
    end if;
    if v_row.status = 'skipped' then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_norm := v_row.normalized_data;
    select
      exists (select 1 from jsonb_array_elements(v_row.issues) x
        where x ->> 'code' = 'EXISTING'),
      (select (x ->> 'existing_id')::uuid
       from jsonb_array_elements(v_row.issues) x
       where x ->> 'code' = 'EXISTING' limit 1)
    into v_has_existing, v_existing_id;
    if v_has_existing then
      -- Ma + ten da co san: bo qua, chi ghi target.
      update public.import_rows
      set status = 'committed', target_id = v_existing_id,
        target_code = (v_norm ->> 'code')
      where id = v_row.id;
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if v_batch.kind = 'items' then
      v_code := v_norm ->> 'code';
      if v_code is null or v_code = '' then
        v_code := public.next_item_code(
          v_batch.org_id, coalesce(v_norm ->> 'group_prefix', 'TP'));
      end if;

      insert into public.items (
        org_id, code, name, name_en, group_id, stock_uom, recipe_uom,
        stock_to_recipe, legacy_code, is_key_item, vat_rate,
        shelf_life_days, status
      ) values (
        v_batch.org_id, v_code, v_norm ->> 'name', v_norm ->> 'name_en',
        (v_norm ->> 'group_id')::uuid, v_norm ->> 'stock_uom',
        v_norm ->> 'recipe_uom',
        case when v_norm ->> 'stock_to_recipe' is null then null
          else (v_norm ->> 'stock_to_recipe')::numeric(18,4) end,
        v_norm ->> 'legacy_code',
        coalesce((v_norm ->> 'key_item')::boolean, false),
        case when v_norm ->> 'vat_rate' is null then null
          else (v_norm ->> 'vat_rate')::numeric(18,4) end,
        case when v_norm ->> 'shelf_life_days' is null then null
          else (v_norm ->> 'shelf_life_days')::integer end,
        'active'
      ) returning id into v_item_id;

      if (v_norm ->> 'purchase_uom') is not null
        and (v_norm ->> 'purchase_factor') is not null then
        insert into public.item_purchase_units
          (item_id, uom, factor_to_stock, is_default)
        values (
          v_item_id, v_norm ->> 'purchase_uom',
          (v_norm ->> 'purchase_factor')::numeric(18,4), true);
      end if;

      update public.import_rows
      set status = 'committed', target_id = v_item_id, target_code = v_code
      where id = v_row.id;
    else
      v_code := v_norm ->> 'code';
      if v_code is null or v_code = '' then
        v_code := public.next_item_code(v_batch.org_id, 'NCC');
      end if;

      insert into public.suppliers (
        org_id, code, name, tax_code, kind, phone, address,
        payment_terms_days, status
      ) values (
        v_batch.org_id, v_code, v_norm ->> 'name', v_norm ->> 'tax_code',
        v_norm ->> 'kind', v_norm ->> 'phone', v_norm ->> 'address',
        case when v_norm ->> 'payment_terms_days' is null then null
          else (v_norm ->> 'payment_terms_days')::integer end,
        'pending'
      ) returning id into v_supplier_id;

      if (v_norm ->> 'account_no') is not null then
        insert into public.supplier_bank_accounts (
          org_id, supplier_id, bank_name, account_no, account_name, status, requested_by
        ) values (
          v_batch.org_id, v_supplier_id, v_norm ->> 'bank_name', v_norm ->> 'account_no',
          v_norm ->> 'account_name', 'pending', auth.uid());
      end if;

      update public.import_rows
      set status = 'committed', target_id = v_supplier_id, target_code = v_code
      where id = v_row.id;
    end if;

    v_created := v_created + 1;
  end loop;

  update public.import_batches
  set status = 'committed',
    committed_at = now(),
    committed_by = auth.uid(),
    counts = counts || jsonb_build_object(
      'created', v_created, 'skipped', v_skipped, 'merged', v_merged)
  where id = p_batch_id;

  return jsonb_build_object(
    'batch_id', p_batch_id,
    'status', 'committed',
    'created', v_created,
    'skipped', v_skipped,
    'merged', v_merged);
end $$;
