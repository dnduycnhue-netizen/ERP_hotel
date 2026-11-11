-- C3 (completion wave 2): chong xuat trung + xuat PDF PO + file Excel
-- chuyen khoan (M03/M09; audit §2.3, §2.8).
--
-- 1. Bang moi `export_batches`: moi lan xuat (PDF PO, file chuyen khoan,
--    5 loai xuat ke toan T-043) ghi 1 dong — bang + file checksum (sha256)
--    de doi chieu va biet file nao da xuat, khi nao, boi ai.
-- 2. Cot moi `export_status` ('not_exported' | 'exported') tren
--    `purchase_orders` va `payment_requests`: M09 yeu cau danh dau
--    `export_status = 'exported'` de khong xuat trung. Truoc day 2 bang
--    nay CHUA co cot do (grep export_status = 0) nen them o day.
-- 3. RPC moi:
--    - `export_po_data(p_po_id)`: du lieu in PDF PO (header + dong +
--      lich su duyet), dung lai cac cot cua `po_get`/`approval_timeline`,
--      khong them field moi. Can `po.view_price` (PDF gui NCC bat buoc
--      co gia; nguoi khong duoc xem gia khong tai duoc PDF co gia).
--    - `export_bank_transfer(p_payment_request_ids)`: danh sach chuyen
--      khoan cho cac de nghi thanh toan DA DUYET (status='approved');
--      NCC lay tai khoan ngan hang ACTIVE moi nhat tu
--      `supplier_bank_accounts`. Chi `export.accounting` hoac
--      `payment.mark_paid` duoc xuat.
--    - `export_batch_record(p_kind, p_ref_type, p_ref_ids, p_file_hash,
--      p_note)`: ghi 1 dong `export_batches` cho moi ref + danh dau
--      `export_status='exported'` tren chung tu duoc xuat. Route goi
--      SAU khi build xong file (da co hash) va TRUOC khi tra file —
--      file khong bao gio duoc tra ma khong co dong log.
-- Khong them ma quyen moi. Khong sua migration cu. Tien la numeric,
-- ngay nghiep vu Asia/Ho_Chi_Minh.
--
-- Quyet dinh khi dac ta im lang (ghi ro de Duy chot lai neu sai):
--  1. Xuat lai (re-export) KHONG bi chan cung: moi lan xuat deu ghi
--     them 1 dong `export_batches` (co hash file) de doi chieu; de nghi
--     da xuat truoc do duoc danh dau trong file (cot Ghi chu) thay vi
--     tra 409 — file cu co the bi mat, ke toan can tai lai. Chan cung
--     chi o 2 cho: de nghi chua 'approved' (chua duyet / da tra) thi
--     khong xuat; NCC chua co tai khoan ngan hang ACTIVE thi khong xuat.
--  2. Noi dung chuyen khoan mac dinh: 'Thanh toán <so de nghi>'.
--     M09 khong dinh nghia mau noi dung; ke toan sua tay o ngan hang
--     neu can (C4 se cho sua truoc khi xuat neu Duy muon).
--  3. `export_batches.property_id` NOT NULL: voi ref la legal_entity
--     (xuat ke toan T-043) lay property nhu `_export_require` (property
--     dau tien cua phap nhan).

-- ---------------------------------------------------------------------------
-- 1. Bang export_batches.
-- ---------------------------------------------------------------------------
create table public.export_batches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  kind text not null check (kind in (
    'po-pdf', 'bank-transfer',
    'goods-receipts', 'stock-issues', 'invoices', 'payables', 'advances'
  )),
  ref_type text not null check (ref_type in (
    'purchase_order', 'payment_request', 'legal_entity'
  )),
  ref_id uuid not null,
  exported_by uuid not null references auth.users(id),
  exported_at timestamptz not null default now(),
  file_hash text check (
    file_hash is null or file_hash ~ '^[0-9a-f]{64}$'
  ),
  note text,
  unique (id, org_id)
);

create index export_batches_ref_idx
  on public.export_batches (ref_type, ref_id, exported_at desc);
create index export_batches_property_idx
  on public.export_batches (property_id, exported_at desc);
create index export_batches_kind_idx
  on public.export_batches (kind, exported_at desc);

alter table public.export_batches enable row level security;
revoke all on table public.export_batches from public, anon, authenticated;
grant select on table public.export_batches to authenticated;

create policy export_batches_select on public.export_batches
  for select to authenticated
  using (
    property_id in (select public.my_property_ids())
    and (
      public.has_perm(property_id, 'export.accounting')
      or public.has_perm(property_id, 'po.view')
      or public.has_perm(property_id, 'payment.approve')
      or public.has_perm(property_id, 'payment.mark_paid')
    )
  );

-- Chi RPC SECURITY DEFINER ghi (qua bypass GUC), mau _notification_write_guard.
create or replace function public._export_batch_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.export_guard_bypass', true), '') <> 'on' then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public._export_batch_write_guard()
  from public, anon, authenticated;

create trigger trg_export_batches_write_guard
before insert or update or delete on public.export_batches
for each row execute function public._export_batch_write_guard();

create trigger trg_export_batches_audit
after insert or update or delete on public.export_batches
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 2. Cot export_status tren 2 bang chung tu (M09).
-- ---------------------------------------------------------------------------
alter table public.purchase_orders
  add column export_status text not null default 'not_exported'
    check (export_status in ('not_exported', 'exported'));

alter table public.payment_requests
  add column export_status text not null default 'not_exported'
    check (export_status in ('not_exported', 'exported'));

-- ---------------------------------------------------------------------------
-- 3. RPC: du lieu in PDF PO.
-- ---------------------------------------------------------------------------
create or replace function public.export_po_data(
  p_po_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_po public.purchase_orders%rowtype;
  v_supplier record;
  v_entity record;
  v_created_by_name text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = p_po_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  if not (
    public.has_perm(v_po.property_id, 'po.view')
    or public.has_perm(v_po.property_id, 'po.create')
    or public.has_perm(v_po.property_id, 'po.approve')
    or public.has_perm(v_po.property_id, 'po.close')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:po.view';
  end if;
  if not public.has_perm(v_po.property_id, 'po.view_price') then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:po.view_price';
  end if;

  select s.code, s.name, s.tax_code into v_supplier
  from public.suppliers s where s.id = v_po.supplier_id;

  select le.code, le.name into v_entity
  from public.legal_entities le where le.id = v_po.legal_entity_id;

  select p.full_name into v_created_by_name
  from public.profiles p where p.id = v_po.created_by;

  select jsonb_build_object(
    'ok', true,
    'po', jsonb_build_object(
      'id', v_po.id,
      'doc_no', v_po.doc_no,
      'supplier_code', v_supplier.code,
      'supplier_name', v_supplier.name,
      'supplier_tax_code', v_supplier.tax_code,
      'entity_code', v_entity.code,
      'entity_name', v_entity.name,
      'channel', v_po.channel,
      'kind', v_po.kind,
      'order_date', v_po.order_date::text,
      'expected_date', v_po.expected_date::text,
      'status', v_po.status,
      'total_amount', v_po.total_amount,
      'created_by_name', v_created_by_name,
      'created_at', v_po.created_at
    ),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l))
      from (
        select
          pol.id,
          i.code as item_code,
          coalesce(i.name, pol.description) as item_name,
          pol.description,
          pol.qty,
          pol.uom,
          pol.unit_price,
          round(pol.qty * pol.unit_price, 2)::numeric(18, 2) as line_amount
        from public.purchase_order_lines pol
        left join public.items i on i.id = pol.item_id
        where pol.po_id = p_po_id
        order by pol.created_at asc
      ) l
    ), '[]'::jsonb),
    'timeline', coalesce((
      select jsonb_agg(to_jsonb(s))
      from (
        select
          a.step,
          r.name_vi as approver_role_name,
          a.decision,
          p1.full_name as decided_by_name,
          a.decided_at,
          a.comment
        from public.approvals a
        left join public.roles r on r.id = a.approver_role_id
        left join public.profiles p1 on p1.id = a.decided_by
        where a.doc_type = 'po' and a.doc_id = p_po_id
        order by a.step asc
      ) s
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.export_po_data(uuid)
  from public, anon, authenticated;
grant execute on function public.export_po_data(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC: danh sach chuyen khoan cho cac de nghi thanh toan DA DUYET.
-- ---------------------------------------------------------------------------
create or replace function public.export_bank_transfer(
  p_payment_request_ids uuid[]
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_ids uuid[];
  v_property_id uuid;
  v_property_count integer;
  v_found integer;
  v_not_approved text;
  v_no_bank text;
  v_rows jsonb;
  v_total_amount numeric(18, 2);
  v_count integer;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_payment_request_ids is null
    or coalesce(array_length(p_payment_request_ids, 1), 0) = 0
    or array_length(p_payment_request_ids, 1) > 200
  then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  select array_agg(distinct x order by x) into v_ids
  from unnest(p_payment_request_ids) as x;

  select count(*) into v_found
  from public.payment_requests pr where pr.id = any (v_ids);
  if v_found <> array_length(v_ids, 1) then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  select count(distinct pr.property_id) into v_property_count
  from public.payment_requests pr where pr.id = any (v_ids);
  if v_property_count <> 1 then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  select pr.property_id into v_property_id
  from public.payment_requests pr where pr.id = v_ids[1];

  if not (
    public.has_perm(v_property_id, 'export.accounting')
    or public.has_perm(v_property_id, 'payment.mark_paid')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:export.accounting';
  end if;

  -- Chi de nghi DA DUYET moi duoc xuat: chua duyet / da tra / da huy
  -- deu khong duoc ra ngan hang (chong chi trung).
  select string_agg(pr.doc_no, ', ' order by pr.doc_no) into v_not_approved
  from public.payment_requests pr
  where pr.id = any (v_ids) and pr.status <> 'approved';
  if v_not_approved is not null then
    raise exception using errcode = 'P0001',
      message = format('ERR_INVALID_STATUS: %s', v_not_approved);
  end if;

  -- NCC phai co tai khoan ngan hang ACTIVE (da duyet); thieu thi dung
  -- ca file — ke toan duyet tai khoan truoc roi xuat lai.
  select string_agg(pr.doc_no, ', ' order by pr.doc_no) into v_no_bank
  from public.payment_requests pr
  where pr.id = any (v_ids)
    and not exists (
      select 1
      from public.supplier_bank_accounts sba
      where sba.supplier_id = pr.supplier_id
        and sba.status = 'active'
    );
  if v_no_bank is not null then
    raise exception using errcode = 'P0001',
      message = format('ERR_BANK_ACCOUNT_MISSING: %s', v_no_bank);
  end if;

  select
    coalesce(jsonb_agg(r order by r.due_date nulls last, r.doc_no), '[]'::jsonb),
    coalesce(sum(r.amount), 0),
    count(*)
  into v_rows, v_total_amount, v_count
  from (
    select
      pr.id as request_id,
      pr.doc_no,
      pr.due_date::text as due_date,
      s.code as supplier_code,
      s.name as supplier_name,
      sba.bank_name,
      sba.account_no,
      sba.account_name,
      pr.total as amount,
      'Thanh toán ' || pr.doc_no as content,
      (
        select max(eb.exported_at)
        from public.export_batches eb
        where eb.kind = 'bank-transfer'
          and eb.ref_type = 'payment_request'
          and eb.ref_id = pr.id
      ) as previously_exported_at
    from public.payment_requests pr
    join public.suppliers s on s.id = pr.supplier_id
    join lateral (
      select sba2.bank_name, sba2.account_no, sba2.account_name
      from public.supplier_bank_accounts sba2
      where sba2.supplier_id = pr.supplier_id
        and sba2.status = 'active'
      order by sba2.approved_at desc nulls last, sba2.created_at desc
      limit 1
    ) sba on true
    where pr.id = any (v_ids)
  ) r;

  select jsonb_build_object(
    'ok', true,
    'property_id', v_property_id,
    'rows', v_rows,
    'totals', jsonb_build_object('count', v_count, 'amount', v_total_amount),
    'meta', jsonb_build_object(
      'exported_at', now(),
      'exported_by', auth.uid()
    )
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.export_bank_transfer(uuid[])
  from public, anon, authenticated;
grant execute on function public.export_bank_transfer(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC: ghi log xuat + danh dau export_status (nguyen tu: 1 giao dich).
-- ---------------------------------------------------------------------------
create or replace function public.export_batch_record(
  p_kind text,
  p_ref_type text,
  p_ref_ids uuid[],
  p_file_hash text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_ref_id uuid;
  v_org_id uuid;
  v_property_id uuid;
  v_batch_ids uuid[] := '{}'::uuid[];
  v_batch_id uuid;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_kind not in (
      'po-pdf', 'bank-transfer',
      'goods-receipts', 'stock-issues', 'invoices', 'payables', 'advances'
    )
    or p_ref_type not in ('purchase_order', 'payment_request', 'legal_entity')
    or p_ref_ids is null
    or coalesce(array_length(p_ref_ids, 1), 0) = 0
    or array_length(p_ref_ids, 1) > 200
    or (p_file_hash is not null and p_file_hash !~ '^[0-9a-f]{64}$')
  then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  perform set_config('app.export_guard_bypass', 'on', true);

  foreach v_ref_id in array p_ref_ids loop
    v_org_id := null;
    v_property_id := null;

    if p_ref_type = 'purchase_order' then
      select po.org_id, po.property_id into v_org_id, v_property_id
      from public.purchase_orders po where po.id = v_ref_id;
    elsif p_ref_type = 'payment_request' then
      select pr.org_id, pr.property_id into v_org_id, v_property_id
      from public.payment_requests pr where pr.id = v_ref_id;
    else
      select le.org_id into v_org_id
      from public.legal_entities le where le.id = v_ref_id;
      if v_org_id is not null then
        select p.id into v_property_id
        from public.properties p
        where p.legal_entity_id = v_ref_id
        limit 1;
      end if;
    end if;

    if v_org_id is null or v_property_id is null then
      raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
    end if;

    -- Quyen theo loai xuat (giong RPC lay du lieu cua loai do).
    if p_kind = 'po-pdf' then
      if not (
        public.has_perm(v_property_id, 'po.view')
        or public.has_perm(v_property_id, 'po.create')
        or public.has_perm(v_property_id, 'po.approve')
        or public.has_perm(v_property_id, 'po.close')
      ) then
        raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:po.view';
      end if;
      if not public.has_perm(v_property_id, 'po.view_price') then
        raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:po.view_price';
      end if;
    elsif p_kind = 'bank-transfer' then
      if not (
        public.has_perm(v_property_id, 'export.accounting')
        or public.has_perm(v_property_id, 'payment.mark_paid')
      ) then
        raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:export.accounting';
      end if;
    else
      perform public.require_perm(v_property_id, 'export.accounting');
    end if;

    insert into public.export_batches (
      org_id, property_id, kind, ref_type, ref_id,
      exported_by, file_hash, note
    ) values (
      v_org_id, v_property_id, p_kind, p_ref_type, v_ref_id,
      auth.uid(), p_file_hash, p_note
    ) returning id into v_batch_id;
    v_batch_ids := v_batch_ids || v_batch_id;

    -- Danh dau chung tu da xuat (M09). Bang legal_entity khong co
    -- chung tu cu the nen khong danh dau.
    if p_ref_type = 'purchase_order' then
      perform set_config('app.pr_po_guard_bypass', 'on', true);
      update public.purchase_orders
      set export_status = 'exported' where id = v_ref_id;
    elsif p_ref_type = 'payment_request' then
      perform set_config('app.finance_guard_bypass', 'on', true);
      update public.payment_requests
      set export_status = 'exported' where id = v_ref_id;
    end if;
  end loop;

  select jsonb_build_object(
    'ok', true,
    'count', array_length(v_batch_ids, 1),
    'batch_ids', to_jsonb(v_batch_ids),
    'exported_at', now(),
    'exported_by', auth.uid()
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.export_batch_record(text, text, uuid[], text, text)
  from public, anon, authenticated;
grant execute on function public.export_batch_record(text, text, uuid[], text, text)
  to authenticated;
