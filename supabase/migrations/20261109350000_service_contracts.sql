-- T-042: Mua dich vu + nghiem thu + hop dong dinh ky + cron sinh lich
-- (MVP-D, migration 13).
-- Spec: 03-DATA-MODEL.md (service_contracts / service_schedules /
-- service_acceptances), 05-BUSINESS-RULES.md §8/§9, 09-API-RPC.md §7.
--
-- QUYET DINH (xem them Q75-Q80 o docs/OPEN-QUESTIONS.md):
--  D1. Hop dong dich vu: billing_cycle monthly/quarterly/yearly/
--      per_visit (theo data model). per_visit KHONG sinh lich tu dong
--      (khong co ky lap lai); ky cua no chi co qua PO le + nghiem thu
--      theo PO (xem D5).
--  D2. Sinh lich: service_schedule_generate(p_month) sinh ky chua ky
--      cho hop dong 'active' (start_date <= cuoi thang, end_date null
--      hoac >= dau thang). monthly = thang do; quarterly = quy chua
--      p_month; yearly = nam chua p_month. Idempotent nho unique
--      (contract_id, period_start) + ON CONFLICT DO NOTHING.
--      due_date = period_end (khong cong them payment terms — Q77).
--  D3. Nghiem thu: service_accept nhan schedule HOAC po (chi 1 trong 2).
--      Chu ky RPC spec (p_schedule_id, p_rating, p_photos) chi mo ta
--      nghiem thu theo ky hop dong; PO dich vu le (khong hop dong) can
--      nghiem thu theo PO nen them tham so tuy chon p_po_id (Q75).
--      rating tuy chon 1..5, photos tuy chon (jsonb array).
--      Trang thai ky: scheduled/performed -> accepted; da accepted thi
--      loi ERR_INVALID_STATUS. 1 ky / 1 PO chi co toi da 1 nghiem thu
--      (unique index partial); chua co duong huy/sua nghiem thu sai (Q80).
--  D4. SoD nghiem thu: nguoi tao hop dong / nguoi tao PO khong duoc tu
--      nghiem thu (quyen 'service.accept' mo ta "nguoi khong dat dich
--      vu") — ma SOD_SERVICE_ACCEPTOR qua _sod_check.
--  D5. Chan thanh toan khi chua nghiem thu (05 §8/§9, CHOT Q72):
--      - invoice_save_draft VAN cho tao nhap (nhap chua ghi cong no).
--      - invoice_match / invoice_approve / payment_request_create
--        RAISE ERR_SERVICE_NOT_ACCEPTED neu dong hoa don gan PO
--        kind='service' ma chua co nghiem thu.
--      - Lien ket PO<->hop dong: them cot purchase_orders.
--        service_contract_id (nullable). Nghiem thu duoc chap nhan neu:
--        (a) co service_acceptances voi po_id = PO do, HOAC (b) PO co
--        service_contract_id va co nghiem thu cho ky cua hop dong do ma
--        period chua invoice_date.
--      - Khi da nghiem thu, invoice_match tinh so nhan cua dong dich vu
--        = so luong PO (nghiem thu theo PO, khong theo GR — dich vu
--        khong co phieu nhan).
--  D6. Bao tri hang ngay (cron): service_maintenance() sinh lich thang
--      hien tai + danh dau hop dong het han (end_date < hom nay) thanh
--      'expired' + tao alert SERVICE_CONTRACT_RENEWAL (warn, dedupe
--      theo alert chua ack cung contract) cho hop dong sap het han trong
--      cua so renew_notice_days (mac dinh 30 ngay).
--  D7. Quyen: khong co ma quyen moi (catalog 141000 da co
--      service.contract.manage + service.accept). Migration nay chi gan
--      them 'service.contract.manage' cho owner + gm (ma nay chua gan
--      cho vai tro nao); 'service.accept' giu nguyen o engineer (seed).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Bang moi
-- ---------------------------------------------------------------------------

create table public.service_contracts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  supplier_id uuid not null,
  expense_category_id uuid not null,
  cost_center_id uuid not null,
  title text not null check (btrim(title) <> ''),
  start_date date not null,
  end_date date,
  billing_cycle text not null
    check (billing_cycle in ('monthly', 'quarterly', 'yearly', 'per_visit')),
  amount_per_cycle numeric(18,2) not null check (amount_per_cycle >= 0),
  renew_notice_days integer not null default 30 check (renew_notice_days >= 0),
  status text not null default 'active'
    check (status in ('draft', 'active', 'suspended', 'expired', 'cancelled')),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (supplier_id, org_id) references public.suppliers(id, org_id),
  foreign key (expense_category_id, org_id) references public.expense_categories(id, org_id),
  foreign key (cost_center_id, org_id) references public.cost_centers(id, org_id),
  check (end_date is null or end_date >= start_date)
);

create table public.service_schedules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  contract_id uuid not null,
  period_start date not null,
  period_end date not null,
  due_date date not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'performed', 'accepted', 'invoiced', 'paid', 'skipped')),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (contract_id, period_start),
  foreign key (contract_id, org_id) references public.service_contracts(id, org_id),
  check (period_end >= period_start)
);

create table public.service_acceptances (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  schedule_id uuid,
  po_id uuid,
  accepted_by uuid references auth.users(id) default auth.uid(),
  accepted_at timestamptz not null default now(),
  rating integer check (rating is null or (rating between 1 and 5)),
  note text,
  photo_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(photo_ids) = 'array'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (schedule_id, org_id) references public.service_schedules(id, org_id),
  foreign key (po_id, org_id) references public.purchase_orders(id, org_id),
  check (schedule_id is not null or po_id is not null)
);

-- 1 ky / 1 PO chi co toi da 1 nghiem thu (D3).
create unique index service_acceptances_schedule_uidx
  on public.service_acceptances (schedule_id) where schedule_id is not null;
create unique index service_acceptances_po_uidx
  on public.service_acceptances (po_id) where po_id is not null;

-- Lien ket PO dich vu <-> hop dong (D5).
alter table public.purchase_orders
  add column if not exists service_contract_id uuid;
alter table public.purchase_orders
  add constraint purchase_orders_service_contract_fk
  foreign key (service_contract_id, org_id)
  references public.service_contracts(id, org_id);

-- ---------------------------------------------------------------------------
-- 2. Write-guard + updated_at
-- ---------------------------------------------------------------------------

create or replace function public._service_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.service_guard_bypass', true), '') <> 'on' then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return coalesce(new, old);
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'service_contracts', 'service_schedules', 'service_acceptances'
  ] loop
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function public._service_write_guard()',
      'trg_' || v_table || '_write_guard', v_table
    );
  end loop;
end $$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'service_contracts', 'service_schedules', 'service_acceptances'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. RLS: bat 100% + policy SELECT-only (mau T-030 §5 / T-040 §4).
--    Ghi truc tiep bi chan; RPC SECURITY DEFINER ghi.
--    Dung `in (select public.my_property_ids())` — TUYET DOI KHONG dung
--    `= any (public.my_property_ids())` (loi 0A000 khi db push).
-- ---------------------------------------------------------------------------
alter table public.service_contracts enable row level security;
alter table public.service_schedules enable row level security;
alter table public.service_acceptances enable row level security;

create policy service_contracts_select on public.service_contracts
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'service.contract.manage')
    or public.has_perm(property_id, 'service.accept')
    or public.has_perm(property_id, 'invoice.manage')
    or public.has_perm(property_id, 'invoice.approve')
    or public.has_perm(property_id, 'ap.view')
    or public.has_perm(property_id, 'payment.request')
    or public.has_perm(property_id, 'payment.approve')
  )
);

create policy service_schedules_select on public.service_schedules
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'service.contract.manage')
    or public.has_perm(property_id, 'service.accept')
    or public.has_perm(property_id, 'invoice.manage')
    or public.has_perm(property_id, 'invoice.approve')
    or public.has_perm(property_id, 'ap.view')
    or public.has_perm(property_id, 'payment.request')
    or public.has_perm(property_id, 'payment.approve')
  )
);

create policy service_acceptances_select on public.service_acceptances
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'service.contract.manage')
    or public.has_perm(property_id, 'service.accept')
    or public.has_perm(property_id, 'invoice.manage')
    or public.has_perm(property_id, 'invoice.approve')
    or public.has_perm(property_id, 'ap.view')
    or public.has_perm(property_id, 'payment.request')
    or public.has_perm(property_id, 'payment.approve')
  )
);

-- ---------------------------------------------------------------------------
-- 4. Gan quyen (quyet dinh D7): 'service.contract.manage' cho owner +
--    gm. Ma quyen da co trong catalog (141000), chi gan them — khong tao
--    ma moi. Join theo ma role, ap dung moi org hien co, idempotent.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, 'service.contract.manage'
from public.roles r
where r.code in ('owner', 'gm')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 5. Helper noi bo (khong grant execute — chi RPC SECURITY DEFINER goi).
-- ---------------------------------------------------------------------------

-- PO dich vu da duoc nghiem thu chua (D5)? Dung khi (a) co acceptance
-- truc tiep theo po_id, hoac (b) PO gan hop dong va co acceptance cho
-- ky cua hop dong do ma period chua p_date.
create or replace function public._service_po_accepted(
  p_po_id uuid,
  p_date date
)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  return exists (
    select 1 from public.service_acceptances a
    where a.po_id = p_po_id
  ) or exists (
    select 1
    from public.service_acceptances a
    join public.service_schedules s on s.id = a.schedule_id
    join public.purchase_orders po on po.service_contract_id = s.contract_id
    where po.id = p_po_id
      and p_date is not null
      and s.period_start <= p_date
      and s.period_end >= p_date
  );
end;
$$;

revoke all on function public._service_po_accepted(uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPC hop dong dich vu
-- ---------------------------------------------------------------------------

-- Tao / cap nhat hop dong dich vu.
-- p_contract: {"supplier_id", "expense_category_id", "cost_center_id",
--   "title", "start_date", "end_date"?, "billing_cycle",
--   "amount_per_cycle", "renew_notice_days"?, "status"?}.
create or replace function public.service_contract_save(
  p_property_id uuid,
  p_contract jsonb,
  p_contract_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_entity uuid;
  v_sup record;
  v_title text;
  v_start date;
  v_end date;
  v_cycle text;
  v_amount numeric(18,2);
  v_renew integer;
  v_status text;
  v_id uuid;
begin
  select org_id, legal_entity_id into v_org, v_entity
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN:service.contract.manage';
  end if;
  perform public.require_perm(p_property_id, 'service.contract.manage');

  if p_contract is null or jsonb_typeof(p_contract) <> 'object' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_title := nullif(btrim(p_contract ->> 'title'), '');
  v_cycle := p_contract ->> 'billing_cycle';
  if v_title is null
    or (p_contract ->> 'supplier_id') is null
    or (p_contract ->> 'expense_category_id') is null
    or (p_contract ->> 'cost_center_id') is null
    or (p_contract ->> 'start_date') is null
    or v_cycle is null
    or (p_contract ->> 'amount_per_cycle') is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  begin
    v_start := (p_contract ->> 'start_date')::date;
    if (p_contract ->> 'end_date') is not null then
      v_end := (p_contract ->> 'end_date')::date;
    end if;
    v_amount := (p_contract ->> 'amount_per_cycle')::numeric;
    v_renew := coalesce((p_contract ->> 'renew_notice_days')::integer, 30);
  exception when others then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end;
  v_status := coalesce(p_contract ->> 'status', 'active');
  if v_cycle not in ('monthly', 'quarterly', 'yearly', 'per_visit')
    or v_status not in ('draft', 'active', 'suspended', 'expired', 'cancelled')
    or v_amount < 0
    or v_renew < 0
    or (v_end is not null and v_end < v_start) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_sup from public.suppliers
  where id = (p_contract ->> 'supplier_id')::uuid and org_id = v_org;
  if not found or v_sup.status <> 'active' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if not exists (
    select 1 from public.expense_categories
    where id = (p_contract ->> 'expense_category_id')::uuid and org_id = v_org
  ) or not exists (
    select 1 from public.cost_centers
    where id = (p_contract ->> 'cost_center_id')::uuid and org_id = v_org
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.service_guard_bypass', 'on', true);

  if p_contract_id is null then
    insert into public.service_contracts (
      org_id, legal_entity_id, property_id, supplier_id,
      expense_category_id, cost_center_id, title,
      start_date, end_date, billing_cycle, amount_per_cycle,
      renew_notice_days, status, created_by
    ) values (
      v_org, v_entity, p_property_id,
      (p_contract ->> 'supplier_id')::uuid,
      (p_contract ->> 'expense_category_id')::uuid,
      (p_contract ->> 'cost_center_id')::uuid,
      v_title, v_start, v_end, v_cycle, v_amount, v_renew, v_status,
      auth.uid()
    ) returning id into v_id;
  else
    update public.service_contracts set
      supplier_id = (p_contract ->> 'supplier_id')::uuid,
      expense_category_id = (p_contract ->> 'expense_category_id')::uuid,
      cost_center_id = (p_contract ->> 'cost_center_id')::uuid,
      title = v_title,
      start_date = v_start,
      end_date = v_end,
      billing_cycle = v_cycle,
      amount_per_cycle = v_amount,
      renew_notice_days = v_renew,
      status = v_status,
      updated_at = now()
    where id = p_contract_id
      and org_id = v_org and property_id = p_property_id
    returning id into v_id;
    if v_id is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'status', v_status, 'title', v_title,
    'billing_cycle', v_cycle, 'start_date', v_start, 'end_date', v_end
  );
end;
$$;

revoke all on function public.service_contract_save(uuid, jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.service_contract_save(uuid, jsonb, uuid)
  to authenticated;

-- Sinh ky chua co cho thang p_month (D2). Khong require_perm de chay
-- duoc tu pg_cron (mau minibar_reconcile, Q57); UI chan theo quyen.
create or replace function public.service_schedule_generate(
  p_month date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_month date;
  v_month_end date;
  v_c record;
  v_ps date;
  v_pe date;
  v_sid uuid;
  v_generated integer := 0;
  v_existing integer := 0;
  v_skipped integer := 0;
begin
  if p_month is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  v_month := date_trunc('month', p_month)::date;
  v_month_end := (v_month + interval '1 month' - interval '1 day')::date;

  perform set_config('app.service_guard_bypass', 'on', true);

  for v_c in
    select * from public.service_contracts
    where status = 'active'
      and start_date <= v_month_end
      and (end_date is null or end_date >= v_month)
  loop
    if v_c.billing_cycle = 'per_visit' then
      v_skipped := v_skipped + 1;
      continue;
    elsif v_c.billing_cycle = 'monthly' then
      v_ps := v_month;
      v_pe := v_month_end;
    elsif v_c.billing_cycle = 'quarterly' then
      v_ps := date_trunc('quarter', p_month)::date;
      v_pe := (v_ps + interval '3 months' - interval '1 day')::date;
    else -- yearly
      v_ps := date_trunc('year', p_month)::date;
      v_pe := (v_ps + interval '1 year' - interval '1 day')::date;
    end if;

    insert into public.service_schedules (
      org_id, legal_entity_id, property_id, contract_id,
      period_start, period_end, due_date, status
    ) values (
      v_c.org_id, v_c.legal_entity_id, v_c.property_id, v_c.id,
      v_ps, v_pe, v_pe, 'scheduled'
    )
    on conflict (contract_id, period_start) do nothing
    returning id into v_sid;

    if v_sid is not null then
      v_generated := v_generated + 1;
    else
      v_existing := v_existing + 1;
    end if;
    v_sid := null;
  end loop;

  return jsonb_build_object(
    'ok', true, 'month', v_month,
    'generated', v_generated, 'existing', v_existing,
    'skipped_per_visit', v_skipped
  );
end;
$$;

revoke all on function public.service_schedule_generate(date)
  from public, anon, authenticated;
grant execute on function public.service_schedule_generate(date)
  to authenticated;

-- Nghiem thu ky hop dong HOAC PO dich vu le (D3/D4). Chi 1 trong 2 id
-- duoc truyen. rating tuy chon 1..5, photos la jsonb array (ids anh).
create or replace function public.service_accept(
  p_schedule_id uuid default null,
  p_rating integer default null,
  p_photos jsonb default '[]'::jsonb,
  p_po_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_sched record;
  v_contract record;
  v_po record;
  v_property uuid;
  v_acc_id uuid;
begin
  if (p_schedule_id is null) = (p_po_id is null) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if p_rating is not null and (p_rating < 1 or p_rating > 5) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if p_photos is null then
    p_photos := '[]'::jsonb;
  end if;
  if jsonb_typeof(p_photos) <> 'array' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.service_guard_bypass', 'on', true);

  if p_schedule_id is not null then
    select * into v_sched from public.service_schedules
    where id = p_schedule_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    select * into v_contract from public.service_contracts
    where id = v_sched.contract_id;
    v_property := v_sched.property_id;

    perform public.require_perm(v_property, 'service.accept');
    if v_sched.status not in ('scheduled', 'performed') then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    if exists (
      select 1 from public.service_acceptances
      where schedule_id = p_schedule_id
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    -- SoD: nguoi tao hop dong khong duoc tu nghiem thu (D4).
    if v_contract.created_by = auth.uid() then
      perform public._sod_check(v_property, 'SOD_SERVICE_ACCEPTOR');
    end if;

    insert into public.service_acceptances (
      org_id, legal_entity_id, property_id, schedule_id,
      accepted_by, rating, photo_ids, created_by
    ) values (
      v_sched.org_id, v_sched.legal_entity_id, v_sched.property_id,
      p_schedule_id, auth.uid(), p_rating, p_photos, auth.uid()
    ) returning id into v_acc_id;

    update public.service_schedules
    set status = 'accepted', updated_at = now()
    where id = p_schedule_id;

    return jsonb_build_object(
      'ok', true, 'id', v_acc_id, 'schedule_id', p_schedule_id,
      'status', 'accepted', 'rating', p_rating
    );
  else
    select * into v_po from public.purchase_orders where id = p_po_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    if v_po.kind <> 'service' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    v_property := v_po.property_id;

    perform public.require_perm(v_property, 'service.accept');
    if exists (
      select 1 from public.service_acceptances where po_id = p_po_id
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    -- SoD: nguoi tao PO khong duoc tu nghiem thu (D4).
    if v_po.created_by = auth.uid() then
      perform public._sod_check(v_property, 'SOD_SERVICE_ACCEPTOR');
    end if;

    insert into public.service_acceptances (
      org_id, legal_entity_id, property_id, po_id,
      accepted_by, rating, photo_ids, created_by
    ) values (
      v_po.org_id, v_po.legal_entity_id, v_po.property_id,
      p_po_id, auth.uid(), p_rating, p_photos, auth.uid()
    ) returning id into v_acc_id;

    return jsonb_build_object(
      'ok', true, 'id', v_acc_id, 'po_id', p_po_id,
      'status', 'accepted', 'rating', p_rating
    );
  end if;
end;
$$;

revoke all on function public.service_accept(uuid, integer, jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.service_accept(uuid, integer, jsonb, uuid)
  to authenticated;

-- Bao tri hang ngay cho cron (D6): sinh lich thang hien tai + danh dau
-- hop dong het han + alert gia han sap toi. Khong require_perm (cron
-- chay voi auth.uid() NULL, mau advance_overdue_maintenance).
create or replace function public.service_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_gen jsonb;
  v_generated integer;
  v_expired integer := 0;
  v_alerts integer := 0;
  v_c record;
  v_days integer;
begin
  v_gen := public.service_schedule_generate(v_today);
  v_generated := (v_gen ->> 'generated')::integer;

  perform set_config('app.service_guard_bypass', 'on', true);

  update public.service_contracts
  set status = 'expired', updated_at = now()
  where status = 'active'
    and end_date is not null
    and end_date < v_today;
  get diagnostics v_expired = row_count;

  for v_c in
    select * from public.service_contracts
    where status = 'active'
      and end_date is not null
      and end_date >= v_today
      and end_date <= v_today + renew_notice_days
  loop
    v_days := (v_c.end_date - v_today)::integer;
    if not exists (
      select 1 from public.alerts al
      where al.code = 'SERVICE_CONTRACT_RENEWAL'
        and al.property_id = v_c.property_id
        and al.ack_at is null
        and (al.payload ->> 'contract_id') = v_c.id::text
    ) then
      perform public._create_alert(
        v_c.property_id,
        'SERVICE_CONTRACT_RENEWAL',
        'warn',
        format('Hop dong dich vu "%s" het han ngay %s (%s ngay nua)',
               v_c.title, to_char(v_c.end_date, 'DD/MM/YYYY'), v_days),
        jsonb_build_object(
          'contract_id', v_c.id, 'title', v_c.title,
          'supplier_id', v_c.supplier_id,
          'end_date', v_c.end_date, 'days_left', v_days
        ),
        'service_contract',
        v_c.id
      );
      v_alerts := v_alerts + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true, 'date', v_today,
    'generated', v_generated, 'expired', v_expired,
    'renewal_alerts', v_alerts
  );
end;
$$;

revoke all on function public.service_maintenance()
  from public, anon, authenticated;
grant execute on function public.service_maintenance()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 7. pg_cron: bao tri dich vu hang ngay 01:00 VN (18:00 UTC) — sinh lich
--    + het han + alert gia han (mau minibar-reconcile-daily, T-022 §7).
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'T-042: pg_cron khong cai duoc (%), bo qua lich chay.', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (
      select 1 from cron.job where jobname = 'service-maintenance-daily'
    ) then
      perform cron.schedule(
        'service-maintenance-daily',
        '0 18 * * *',
        'select public.service_maintenance()'
      );
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Dinh nghia lai 3 RPC T-040 (CHOT Q72): invoice_match,
--    invoice_approve, payment_request_create — trich nguyen van tu
--    migration 340000, chi them diem chan ERR_SERVICE_NOT_ACCEPTED
--    cho PO kind='service' chua nghiem thu (05 §8/§9). Moi phan khac
--    giu nguyen byte-identical.
-- ---------------------------------------------------------------------------

create or replace function public.invoice_match(
  p_invoice_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_inv record;
  v_tol_pct numeric;
  v_line record;
  v_pol record;
  v_po_qty numeric;
  v_received numeric;
  v_invoiced_other numeric;
  v_inv_qty_for_po numeric;
  v_available numeric;
  v_qty_ok boolean;
  v_price_ok boolean;
  v_diff_pct numeric;
  v_po_kind text;
  v_all_ok boolean := true;
  v_results jsonb := '[]'::jsonb;
begin
  select * into v_inv from public.supplier_invoices where id = p_invoice_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_inv.property_id, 'invoice.manage');
  if v_inv.status not in ('draft', 'on_hold') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  v_tol_pct := ((public._setting_get(
    v_inv.org_id, v_inv.property_id, 'invoice_price_tolerance_pct'
  ))::text)::numeric;

  perform set_config('app.finance_guard_bypass', 'on', true);

  for v_line in
    select * from public.supplier_invoice_lines
    where invoice_id = p_invoice_id
    order by created_at, id
  loop
    select * into v_pol
    from public.purchase_order_lines where id = v_line.po_line_id;

    v_po_qty := coalesce(v_pol.qty_stock, v_pol.qty);

    -- T-042 (Q72): PO dich vu — so nhan thay bang nghiem thu (05 §8/§9).
    -- Chua nghiem thu -> chan han ERR_SERVICE_NOT_ACCEPTED; da nghiem
    -- thu thi so nhan = so luong PO (nghiem thu theo PO, khong theo GR).
    select kind into v_po_kind
    from public.purchase_orders where id = v_pol.po_id;
    if v_po_kind = 'service' then
      if not public._service_po_accepted(v_pol.po_id, v_inv.invoice_date) then
        raise exception using errcode = 'P0001', message = 'ERR_SERVICE_NOT_ACCEPTED';
      end if;
      v_received := v_po_qty;
    else
      -- So da nhan: tong accepted_qty_stock cua GR da 'posted'.
      select coalesce(sum(grl.accepted_qty_stock), 0) into v_received
      from public.goods_receipt_lines grl
      join public.goods_receipts gr on gr.id = grl.gr_id
      where grl.po_line_id = v_pol.id
        and gr.status = 'posted';
    end if;

    -- So da hoa don o hoa don KHAC (chua huy, da khop tro di).
    select coalesce(sum(sil.qty), 0) into v_invoiced_other
    from public.supplier_invoice_lines sil
    join public.supplier_invoices si on si.id = sil.invoice_id
    where sil.po_line_id = v_pol.id
      and sil.invoice_id <> p_invoice_id
      and si.status in ('matched', 'approved', 'partially_paid', 'paid');

    -- Tong so luong hoa don NAY cho cung dong PO (phieu co the co 2
    -- dong trung po_line_id).
    select coalesce(sum(qty), 0) into v_inv_qty_for_po
    from public.supplier_invoice_lines
    where invoice_id = p_invoice_id
      and po_line_id = v_pol.id;

    v_available := v_received - v_invoiced_other;
    v_qty_ok := (v_inv_qty_for_po <= v_available);

    if v_pol.unit_price = 0 then
      v_price_ok := (v_line.unit_price = 0);
      v_diff_pct := case when v_line.unit_price = 0 then 0 else null end;
    else
      v_diff_pct := round(
        abs(v_line.unit_price - v_pol.unit_price) / v_pol.unit_price * 100, 4);
      v_price_ok := (v_diff_pct <= v_tol_pct);
    end if;

    if not (v_qty_ok and v_price_ok) then
      v_all_ok := false;
    end if;

    update public.supplier_invoice_lines
    set match_result = jsonb_build_object(
      'qty_ok', v_qty_ok,
      'price_ok', v_price_ok,
      'po_qty', v_po_qty,
      'received_qty', v_received,
      'available_qty', v_available,
      'already_invoiced_qty', v_invoiced_other,
      'invoice_qty_for_po_line', v_inv_qty_for_po,
      'po_unit_price', v_pol.unit_price,
      'invoice_unit_price', v_line.unit_price,
      'price_diff_pct', v_diff_pct,
      'tolerance_pct', v_tol_pct,
      'reason', case
        when not v_qty_ok then 'QTY_OVER_RECEIVED'
        when not v_price_ok then 'PRICE_OVER_TOLERANCE'
        else null end
    )
    where id = v_line.id;

    v_results := v_results || jsonb_build_object(
      'line_id', v_line.id,
      'po_line_id', v_pol.id,
      'qty_ok', v_qty_ok,
      'price_ok', v_price_ok,
      'reason', case
        when not v_qty_ok then 'QTY_OVER_RECEIVED'
        when not v_price_ok then 'PRICE_OVER_TOLERANCE'
        else null end
    );
  end loop;

  update public.supplier_invoices
  set status = case when v_all_ok then 'matched' else 'on_hold' end,
      updated_at = now()
  where id = p_invoice_id;

  return jsonb_build_object(
    'ok', true, 'id', p_invoice_id,
    'status', case when v_all_ok then 'matched' else 'on_hold' end,
    'lines', v_results
  );
end;
$$;

revoke all on function public.invoice_match(uuid)
  from public, anon, authenticated;
grant execute on function public.invoice_match(uuid) to authenticated;


create or replace function public.invoice_approve(
  p_invoice_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_inv record;
  v_sup record;
  v_due date;
  v_line record;
begin
  select * into v_inv from public.supplier_invoices where id = p_invoice_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_inv.property_id, 'invoice.approve');
  if v_inv.status <> 'matched' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if v_inv.created_by = auth.uid() then
    perform public._sod_check(v_inv.property_id, 'SOD_INVOICE_CREATOR_APPROVER');
  end if;

  -- T-042 (Q72): phong thu — kiem tra lai nghiem thu dich vu truoc
  -- khi ghi ap_ledger (05 §8/§9).
  for v_line in
    select sil.*, po.id as po_id, po.kind as po_kind
    from public.supplier_invoice_lines sil
    join public.purchase_order_lines pol on pol.id = sil.po_line_id
    join public.purchase_orders po on po.id = pol.po_id
    where sil.invoice_id = p_invoice_id
  loop
    if v_line.po_kind = 'service'
      and not public._service_po_accepted(v_line.po_id, v_inv.invoice_date) then
      raise exception using errcode = 'P0001', message = 'ERR_SERVICE_NOT_ACCEPTED';
    end if;
  end loop;

  select * into v_sup from public.suppliers where id = v_inv.supplier_id;
  v_due := v_inv.invoice_date + coalesce(v_sup.payment_terms_days, 0);

  perform set_config('app.finance_guard_bypass', 'on', true);

  update public.supplier_invoices
  set status = 'approved', updated_at = now()
  where id = p_invoice_id;

  insert into public.ap_ledger (
    org_id, legal_entity_id, property_id, supplier_id,
    doc_type, doc_id, amount, due_date, entry_date
  ) values (
    v_inv.org_id, v_inv.legal_entity_id, v_inv.property_id, v_inv.supplier_id,
    'supplier_invoice', p_invoice_id, v_inv.total, v_due,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );

  return jsonb_build_object(
    'ok', true, 'id', p_invoice_id, 'status', 'approved',
    'total', v_inv.total, 'due_date', v_due
  );
end;
$$;

revoke all on function public.invoice_approve(uuid)
  from public, anon, authenticated;
grant execute on function public.invoice_approve(uuid) to authenticated;

-- ---------------------------------------------------------------------------

create or replace function public.payment_request_create(
  p_property_id uuid,
  p_supplier_id uuid,
  p_lines jsonb,
  p_due_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_entity uuid;
  v_sup record;
  v_el jsonb;
  v_inv record;
  v_paid numeric(18,2);
  v_requested numeric(18,2);
  v_remaining numeric(18,2);
  v_total numeric(18,2) := 0;
  v_due date;
  v_req_id uuid;
  v_doc_no text;
  v_steps integer;
  v_bank_extra boolean := false;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select org_id, legal_entity_id into v_org, v_entity
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN:payment.request';
  end if;
  perform public.require_perm(p_property_id, 'payment.request');

  select * into v_sup from public.suppliers
  where id = p_supplier_id and org_id = v_org;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    if (v_el ->> 'invoice_id') is null
      or (v_el ->> 'amount')::numeric is null
      or (v_el ->> 'amount')::numeric <= 0 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    select * into v_inv
    from public.supplier_invoices
    where id = (v_el ->> 'invoice_id')::uuid;
    if not found
      or v_inv.supplier_id <> p_supplier_id
      or v_inv.legal_entity_id <> v_entity
      or v_inv.status not in ('approved', 'partially_paid') then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    -- Da tra: tong dong cua cac de nghi da 'paid'.
    select coalesce(sum(prl.amount), 0) into v_paid
    from public.payment_request_lines prl
    join public.payment_requests pr on pr.id = prl.request_id
    where prl.invoice_id = v_inv.id and pr.status = 'paid';

    -- Da de nghi (chua huy/chua tra): tong dong cua de nghi
    -- 'submitted'/'approved'.
    select coalesce(sum(prl.amount), 0) into v_requested
    from public.payment_request_lines prl
    join public.payment_requests pr on pr.id = prl.request_id
    where prl.invoice_id = v_inv.id
      and pr.status in ('submitted', 'approved');

    v_remaining := v_inv.total - v_paid - v_requested;
    if (v_el ->> 'amount')::numeric > v_remaining then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    -- T-042 (Q72): hoa don co dong PO dich vu chua nghiem thu -> chan
    -- thanh toan (05 §8/§9).
    if exists (
      select 1
      from public.supplier_invoice_lines sil
      join public.purchase_order_lines pol on pol.id = sil.po_line_id
      join public.purchase_orders po on po.id = pol.po_id
      where sil.invoice_id = v_inv.id
        and po.kind = 'service'
        and not public._service_po_accepted(po.id, v_inv.invoice_date)
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_SERVICE_NOT_ACCEPTED';
    end if;
    v_total := v_total + (v_el ->> 'amount')::numeric;
  end loop;

  if p_due_date is not null then
    v_due := p_due_date;
  else
    -- Mac dinh: han tra muon nhat trong cac hoa don (theo ap_ledger (+)).
    select max(al.due_date) into v_due
    from public.ap_ledger al
    where al.doc_type = 'supplier_invoice'
      and al.doc_id in (
        select (x ->> 'invoice_id')::uuid
        from jsonb_array_elements(p_lines) x
      );
    v_due := coalesce(v_due, v_today);
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity, 'PAY', v_today);

  insert into public.payment_requests (
    org_id, legal_entity_id, property_id, supplier_id, doc_no,
    total, due_date, status
  ) values (
    v_org, v_entity, p_property_id, p_supplier_id, v_doc_no,
    v_total, v_due, 'submitted'
  ) returning id into v_req_id;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.payment_request_lines (
      request_id, org_id, invoice_id, amount
    ) values (
      v_req_id, v_org,
      (v_el ->> 'invoice_id')::uuid,
      (v_el ->> 'amount')::numeric
    );
  end loop;

  -- Sinh buoc duyet: uu tien rule admin da cau hinh (neu co); neu
  -- khong co rule nao thi mac dinh 1 buoc chief_accountant.
  perform set_config('app.pr_po_guard_bypass', 'on', true);
  v_steps := public._generate_approval_steps(
    'payment_request', v_req_id, p_property_id, v_org, v_total);

  if v_steps = 0 then
    insert into public.approvals (
      org_id, property_id, doc_type, doc_id, step,
      approver_role_id, approver_user_id, required_perm, decision
    ) select
      v_org, p_property_id, 'payment_request', v_req_id, 1,
      r.id, null, 'payment.approve', 'pending'
    from public.roles r
    where r.org_id = v_org and r.code = 'chief_accountant';
    v_steps := 1;
  end if;

  -- Doi STK trong 30 ngay gan nhat -> them buoc duyet owner (05 §8).
  if v_sup.bank_changed_at is not null
    and (v_sup.bank_changed_at at time zone 'Asia/Ho_Chi_Minh')::date
        >= v_today - 30 then
    insert into public.approvals (
      org_id, property_id, doc_type, doc_id, step,
      approver_role_id, approver_user_id, required_perm, decision
    ) select
      v_org, p_property_id, 'payment_request', v_req_id,
      coalesce((select max(step) from public.approvals
                where doc_type = 'payment_request' and doc_id = v_req_id), 0) + 1,
      r.id, null, 'payment.approve', 'pending'
    from public.roles r
    where r.org_id = v_org and r.code = 'owner';
    v_steps := v_steps + 1;
    v_bank_extra := true;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', v_req_id, 'doc_no', v_doc_no,
    'status', 'submitted', 'total', v_total, 'due_date', v_due,
    'steps', v_steps, 'bank_changed_extra_step', v_bank_extra
  );
end;
$$;

revoke all on function public.payment_request_create(uuid, uuid, jsonb, date)
  from public, anon, authenticated;
grant execute on function public.payment_request_create(uuid, uuid, jsonb, date)
  to authenticated;

