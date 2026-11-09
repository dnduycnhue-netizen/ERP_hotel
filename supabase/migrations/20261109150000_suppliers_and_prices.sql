-- T-013: NCC, thẩm định, đổi STK 2 người (SoD), hợp đồng khung, giá trần và cảnh báo BANK_ACCOUNT_CHANGE.

-- 1. Bảng alerts
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid references public.properties(id),
  code text not null,
  severity text not null check (severity in ('info', 'warn', 'red')),
  title text not null,
  payload jsonb not null default '{}'::jsonb,
  doc_type text,
  doc_id uuid,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  sent_channels text[],
  ack_by uuid references auth.users(id),
  ack_at timestamptz
);

create index if not exists alerts_scope_idx on public.alerts (org_id, property_id, code);
alter table public.alerts enable row level security;
revoke all on public.alerts from public, anon, authenticated;
grant select on public.alerts to authenticated;

create policy alerts_select on public.alerts for select to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = alerts.org_id
      and p.id in (select public.my_property_ids())
      and (alerts.property_id is null or alerts.property_id = p.id)
  )
);

create trigger trg_alerts_audit
  after insert or update on public.alerts
  for each row execute function public.audit_trigger();

-- 2. Cấp quyền và RLS Write Policies cho suppliers
grant insert, update, delete on public.suppliers to authenticated;
grant insert, update, delete on public.price_agreements to authenticated;
grant insert, update, delete on public.price_agreement_lines to authenticated;
grant insert, update, delete on public.ceiling_prices to authenticated;

-- Policies suppliers
create policy suppliers_insert on public.suppliers for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  ) or (select public.has_perm(null, 'supplier.manage'))
);

create policy suppliers_update on public.suppliers for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  ) or (select public.has_perm(null, 'supplier.manage'))
)
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  ) or (select public.has_perm(null, 'supplier.manage'))
);

create policy suppliers_delete on public.suppliers for delete to authenticated
using (
  status = 'pending'
  and (
    exists (
      select 1 from public.properties p
      where p.org_id = suppliers.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'supplier.manage')
    ) or (select public.has_perm(null, 'supplier.manage'))
  )
);

-- Cập nhật policy SELECT cho price_agreements và ceiling_prices để người có quyền manage cũng được xem
drop policy if exists price_agreements_select on public.price_agreements;
create policy price_agreements_select on public.price_agreements for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = price_agreements.org_id
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'price.view') or public.has_perm(p.id, 'price.agreement.manage')))
);

drop policy if exists price_agreement_lines_select on public.price_agreement_lines;
create policy price_agreement_lines_select on public.price_agreement_lines for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = price_agreement_lines.org_id
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'price.view') or public.has_perm(p.id, 'price.agreement.manage')))
);

drop policy if exists ceiling_prices_select on public.ceiling_prices;
create policy ceiling_prices_select on public.ceiling_prices for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = ceiling_prices.org_id
    and (ceiling_prices.property_id is null or p.id = ceiling_prices.property_id)
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'price.view') or public.has_perm(p.id, 'price.ceiling.manage')))
);

-- Policies price_agreements
create policy price_agreements_insert on public.price_agreements for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreements_update on public.price_agreements for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
)
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreements_delete on public.price_agreements for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
);

-- Policies price_agreement_lines
create policy price_agreement_lines_insert on public.price_agreement_lines for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreement_lines.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreement_lines_update on public.price_agreement_lines for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreement_lines.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
)
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreement_lines.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreement_lines_delete on public.price_agreement_lines for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = price_agreement_lines.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  ) or (select public.has_perm(null, 'price.agreement.manage'))
);

-- Policies ceiling_prices
create policy ceiling_prices_insert on public.ceiling_prices for insert to authenticated
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = ceiling_prices.org_id
      and (ceiling_prices.property_id is null or p.id = ceiling_prices.property_id)
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.ceiling.manage')
  ) or (select public.has_perm(null, 'price.ceiling.manage'))
);

create policy ceiling_prices_update on public.ceiling_prices for update to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = ceiling_prices.org_id
      and (ceiling_prices.property_id is null or p.id = ceiling_prices.property_id)
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.ceiling.manage')
  ) or (select public.has_perm(null, 'price.ceiling.manage'))
)
with check (
  exists (
    select 1 from public.properties p
    where p.org_id = ceiling_prices.org_id
      and (ceiling_prices.property_id is null or p.id = ceiling_prices.property_id)
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.ceiling.manage')
  ) or (select public.has_perm(null, 'price.ceiling.manage'))
);

create policy ceiling_prices_delete on public.ceiling_prices for delete to authenticated
using (
  exists (
    select 1 from public.properties p
    where p.org_id = ceiling_prices.org_id
      and (ceiling_prices.property_id is null or p.id = ceiling_prices.property_id)
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.ceiling.manage')
  ) or (select public.has_perm(null, 'price.ceiling.manage'))
);

-- 3. RPC Thẩm định và duyệt nhà cung cấp (SoD: người duyệt != người tạo)
create or replace function public.supplier_approve(
  p_supplier_id uuid,
  p_decision text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_supp public.suppliers%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_decision is null or p_decision not in ('active', 'suspended', 'banned') then
    raise exception using errcode = '22023', message = 'ERR_INVALID_DECISION';
  end if;

  select * into v_supp
  from public.suppliers
  where id = p_supplier_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_SUPPLIER_NOT_FOUND';
  end if;

  -- Kiểm tra quyền supplier.approve
  if not (
    public.has_perm(null, 'supplier.approve')
    or exists (
      select 1 from public.properties p
      where p.org_id = v_supp.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'supplier.approve')
    )
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:supplier.approve';
  end if;

  -- SoD: Người duyệt != người tạo
  if v_supp.created_by = auth.uid() then
    raise exception using errcode = 'P0001', message = 'ERR_SOD_SUPPLIER_CREATOR_APPROVER';
  end if;

  update public.suppliers
  set status = p_decision,
      approved_by = case when p_decision = 'active' then auth.uid() else approved_by end,
      updated_at = now()
  where id = p_supplier_id;

  return jsonb_build_object('ok', true, 'id', p_supplier_id, 'status', p_decision);
end;
$$;

-- 4. RPC Đề nghị thêm/đổi STK NCC
create or replace function public.supplier_bank_request(
  p_supplier_id uuid,
  p_bank_name text,
  p_account_no text,
  p_account_name text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_supp public.suppliers%rowtype;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_bank_name is null or btrim(p_bank_name) = ''
    or p_account_no is null or btrim(p_account_no) = ''
    or p_account_name is null or btrim(p_account_name) = '' then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  select * into v_supp
  from public.suppliers
  where id = p_supplier_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_SUPPLIER_NOT_FOUND';
  end if;

  -- Kiểm tra quyền supplier.bank.request
  if not (
    public.has_perm(null, 'supplier.bank.request')
    or exists (
      select 1 from public.properties p
      where p.org_id = v_supp.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'supplier.bank.request')
    )
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:supplier.bank.request';
  end if;

  insert into public.supplier_bank_accounts (
    org_id, supplier_id, bank_name, account_no, account_name,
    status, requested_by
  ) values (
    v_supp.org_id, p_supplier_id, btrim(p_bank_name), btrim(p_account_no), btrim(p_account_name),
    'pending', auth.uid()
  ) returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

-- 5. RPC Duyệt STK NCC (SoD 2 người: người duyệt != người yêu cầu, sinh alert BANK_ACCOUNT_CHANGE)
create or replace function public.supplier_bank_approve(
  p_bank_account_id uuid,
  p_decision text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_bank public.supplier_bank_accounts%rowtype;
  v_supp public.suppliers%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_decision is null or p_decision not in ('active', 'revoked') then
    raise exception using errcode = '22023', message = 'ERR_INVALID_DECISION';
  end if;

  select * into v_bank
  from public.supplier_bank_accounts
  where id = p_bank_account_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_BANK_ACCOUNT_NOT_FOUND';
  end if;

  select * into v_supp
  from public.suppliers
  where id = v_bank.supplier_id;

  -- Kiểm tra quyền supplier.bank.approve
  if not (
    public.has_perm(null, 'supplier.bank.approve')
    or exists (
      select 1 from public.properties p
      where p.org_id = v_bank.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'supplier.bank.approve')
    )
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN:supplier.bank.approve';
  end if;

  -- SoD: Người duyệt != người yêu cầu
  if v_bank.requested_by = auth.uid() then
    raise exception using errcode = 'P0001', message = 'ERR_SOD_BANK_ACCOUNT';
  end if;

  if p_decision = 'active' then
    -- Hủy các tài khoản cũ đang active của NCC này
    update public.supplier_bank_accounts
    set status = 'revoked', updated_at = now()
    where supplier_id = v_bank.supplier_id
      and id <> p_bank_account_id
      and status = 'active';

    update public.supplier_bank_accounts
    set status = 'active',
        approved_by = auth.uid(),
        approved_at = now(),
        updated_at = now()
    where id = p_bank_account_id;

    -- Sinh cảnh báo đỏ BANK_ACCOUNT_CHANGE
    insert into public.alerts (
      org_id, code, severity, title, payload, doc_type, doc_id
    ) values (
      v_bank.org_id,
      'BANK_ACCOUNT_CHANGE',
      'red',
      format('Thay đổi số tài khoản ngân hàng nhà cung cấp %s: %s - %s', v_supp.name, v_bank.bank_name, v_bank.account_no),
      jsonb_build_object(
        'supplier_id', v_bank.supplier_id,
        'supplier_code', v_supp.code,
        'supplier_name', v_supp.name,
        'bank_name', v_bank.bank_name,
        'account_no', v_bank.account_no,
        'account_name', v_bank.account_name,
        'requested_by', v_bank.requested_by,
        'approved_by', auth.uid()
      ),
      'supplier_bank_accounts',
      v_bank.id
    );
  else
    update public.supplier_bank_accounts
    set status = 'revoked', updated_at = now()
    where id = p_bank_account_id;
  end if;

  return jsonb_build_object('ok', true, 'id', p_bank_account_id, 'status', p_decision);
end;
$$;

revoke all on function public.supplier_approve(uuid, text) from public, anon;
revoke all on function public.supplier_bank_request(uuid, text, text, text) from public, anon;
revoke all on function public.supplier_bank_approve(uuid, text) from public, anon;

grant execute on function public.supplier_approve(uuid, text) to authenticated;
grant execute on function public.supplier_bank_request(uuid, text, text, text) to authenticated;
grant execute on function public.supplier_bank_approve(uuid, text) to authenticated;
