-- T-013: NCC + tham dinh + doi STK 2 nguoi + hop dong khung + gia tran.
-- RECONCILIATION 09/11/2026: production already had the parallel wip
-- migration's alerts table / policies / RPCs (version collision on
-- 20261109150000 — see the preamble before `alter table public.suppliers`).
--
-- Decisions (spec silent or ambiguous; see CHANGELOG T-013):
--   1. The `alerts` table is defined by docs/03-DATA-MODEL.md table A10 and is
--      created here (the repo had no `alerts` table; alert_rules from T-006 is
--      only the rule config). Insert is via SECURITY DEFINER RPC only; there is
--      no direct insert policy. Select policy checks the matching
--      `alert.receive.<code>` permission dynamically, so future alert codes
--      work once their permission is seeded.
--   2. Supplier approval SoD has no rule code in docs/04-SECURITY-RLS.md §6,
--      so a new code is introduced: `SOD_SUPPLIER_APPROVER` (approver must
--      differ from the supplier creator). It is also added to the §6 table.
--      Bank-account change uses the spec code `SOD_BANK_ACCOUNT`.
--   3. `supplier_submit` is side-effect-free validation: it returns the
--      assessment warnings (M01 01.04) and does not change state. Approval is
--      `supplier_approve` (decision + SoD). The UI calls submit to show
--      warnings, then approve.
--   4. `suppliers.status` / `approved_by` / `approved_at` / `bank_changed_at`
--      may only change inside the RPCs. A trigger enforces this; the RPCs set
--      the transaction-local flag `app.supplier_status_guard_bypass` before
--      writing. Direct writes raise ERR_INVALID_STATUS.
--   5. A `BANK_ACCOUNT_CHANGE` alert (severity red) is created only when a
--      bank-account change is APPROVED (the moment money can actually flow to
--      the new account), not when it is merely requested.
--   6. Status lifecycle: pending -> active (approve) -> suspended/banned
--      (supplier_set_status, reason required); suspended -> active/banned;
--      banned is terminal. A pending supplier that fails assessment is either
--      corrected and re-submitted or deleted (delete is allowed only while
--      pending and with no bank accounts).
--   7. Price-agreement overlap (M01 01.05: no overlap for the same supplier +
--      item): checked when a line is added/changed or when an agreement is
--      activated / its validity changes; drafts may overlap freely.
--      Violation raises ERR_AGREEMENT_OVERLAP (new code).
--   8. `current_ceiling_price()` (spec: 05-BUSINESS-RULES.md §2) resolves the
--      ceiling for (org, property, item, uom, date): property-specific wins
--      over chain-wide, then latest valid_from wins. It is an internal helper
--      (no direct grant); T-020 calls it at PO creation.
--   9. SoD exceptions (04 §6): a valid `sod_exceptions` row for the rule lets
--      the same user pass, and a `SOD_EXCEPTION_USED` (warn) alert is created.
--  10. `supplier_assessment_warnings()` is SECURITY DEFINER because the
--      staff-phone duplicate check (M01 01.04) reads `profiles.phone`, which
--      RLS restricts to the owner. It returns only warning codes/messages,
--      never other users' data, and requires the caller to hold
--      `supplier.view` somewhere in the org.
--  11. `supplier_bank_accounts` stays RPC-only (no direct write grants or
--      policies), like `doc_sequences` in T-012.
--  12. New permission assignments (sample roles): `supplier.approve` -> gm,
--      chief_accountant (NOT purchaser, per M01 01.04); `price.agreement.manage`
--      -> purchaser, cost_controller; `price.view` -> purchaser,
--      cost_controller, chief_accountant, gm; `supplier.view` -> gm,
--      chief_accountant, cost_controller (purchaser already has it);
--      `alert.receive.bank_account_change` -> gm, chief_accountant. All are
--      already seeded as permission codes (20261108141000_org_access.sql).
--      `seed.sql` is updated to mirror these assignments.

-- ---------------------------------------------------------------------------
-- Reconciliation with production (09/11/2026): a parallel suppliers
-- implementation (wip/local-2026-11-09, migration file
-- 20261109150000_suppliers_and_prices.sql) was already applied to production
-- under version 20261109150000 — the same version as the H1 grants migration
-- 20261109150000_master_data_role_permissions.sql, which db push therefore
-- skipped (that is why its 6 grants never landed; the is_system theory was
-- wrong). Production already has B's `alerts` table + policies + 3 RPC
-- overloads. This preamble removes B's conflicting objects first so the
-- statements below can apply. It is a no-op on a fresh database: every DROP
-- uses IF EXISTS (the alerts policy drop is guarded by the table existing,
-- because DROP POLICY errors when the table itself is absent), and the
-- ALTERs run only if the table already exists.
-- Do NOT drop B's 3 select policies (price_agreements_select,
-- price_agreement_lines_select, ceiling_prices_select): this migration does
-- not redefine them and they are compatible with the definitions below.
-- ---------------------------------------------------------------------------
drop function if exists public.supplier_approve(uuid, text);
drop function if exists public.supplier_bank_request(uuid, text, text, text);
drop function if exists public.supplier_bank_approve(uuid, text);

drop policy if exists suppliers_insert on public.suppliers;
drop policy if exists suppliers_update on public.suppliers;
drop policy if exists suppliers_delete on public.suppliers;
drop policy if exists price_agreements_insert on public.price_agreements;
drop policy if exists price_agreements_update on public.price_agreements;
drop policy if exists price_agreements_delete on public.price_agreements;
drop policy if exists price_agreement_lines_insert on public.price_agreement_lines;
drop policy if exists price_agreement_lines_update on public.price_agreement_lines;
drop policy if exists price_agreement_lines_delete on public.price_agreement_lines;
drop policy if exists ceiling_prices_insert on public.ceiling_prices;
drop policy if exists ceiling_prices_update on public.ceiling_prices;
drop policy if exists ceiling_prices_delete on public.ceiling_prices;

-- B's `alerts` table lacks the columns A's helpers need and forces org_id
-- NOT NULL. Add the missing columns, drop B's select policy (A redefines
-- it below with the per-code alert.receive.<code> check), and relax org_id
-- (chain-wide alerts have no property, hence no org). Guarded: runs only
-- when the table already exists (production); on a fresh database the
-- CREATE TABLE below defines the full shape, org_id included.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'alerts'
  ) then
    drop policy if exists alerts_select on public.alerts;
    alter table public.alerts
      add column if not exists created_by uuid references auth.users(id) default auth.uid(),
      add column if not exists updated_at timestamptz not null default now();
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'alerts'
        and column_name = 'org_id'
    ) then
      alter table public.alerts alter column org_id drop not null;
    end if;
  end if;
end $$;

alter table public.suppliers
  add column if not exists approved_at timestamptz,
  add column if not exists bank_changed_at timestamptz;

comment on column public.suppliers.approved_at is
  'T-013: thoi diem NCC duoc phe duyet (thay doi chi qua supplier_approve)';
comment on column public.suppliers.bank_changed_at is
  'T-013: thoi diem STK duoc phe duyet thay doi lan cuoi; dung cho quy tac 05-BUSINESS-RULES.md §8 (thanh toan trong 30 ngay sau doi STK can buoc duyet them, T-041)';

-- ---------------------------------------------------------------------------
-- alerts (docs/03-DATA-MODEL.md table A10). Delivery (sent_at /
-- sent_channels) and acknowledgement (ack_by / ack_at) are consumed by
-- T-045; the columns exist now so the AC "alert BANK_ACCOUNT_CHANGE tao ra"
-- is literally satisfied by a durable row.
-- ---------------------------------------------------------------------------
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  -- org_id is kept (nullable) for compatibility with the reconciled wip
  -- table on production; A10 does not define it, and _create_alert fills
  -- it from the property (NULL when chain-wide).
  org_id uuid references public.organizations(id),
  property_id uuid references public.properties(id),
  code text not null check (btrim(code) <> ''),
  severity text not null check (severity in ('info', 'warn', 'red')),
  title text not null check (btrim(title) <> ''),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object'),
  doc_type text,
  doc_id uuid,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz,
  sent_channels text[] not null default '{}'::text[],
  ack_by uuid references auth.users(id),
  ack_at timestamptz,
  check (ack_at is null or ack_by is not null)
);

create index if not exists alerts_property_created_idx
  on public.alerts (property_id, created_at desc);
create index if not exists alerts_code_idx
  on public.alerts (code);

alter table public.alerts enable row level security;
revoke all on table public.alerts from anon, authenticated;
grant select on public.alerts to authenticated;

-- Readable only by users who hold the matching alert.receive.<code>
-- permission for this property (or chain-wide). A code without a seeded
-- permission is visible to nobody, by design.
create policy alerts_select on public.alerts
for select to authenticated
using (
  (
    property_id is not null
    and property_id in (select public.my_property_ids())
    and (select public.has_perm(property_id, 'alert.receive.' || lower(code)))
  )
  or (
    property_id is null
    and (select public.has_perm(null, 'alert.receive.' || lower(code)))
  )
);

drop trigger if exists trg_alerts_set_updated_at on public.alerts;
create trigger trg_alerts_set_updated_at
before update on public.alerts
for each row execute function public.set_updated_at();

drop trigger if exists trg_alerts_audit on public.alerts;
create trigger trg_alerts_audit
after insert or update or delete on public.alerts
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- Internal helpers (no direct grant).
-- ---------------------------------------------------------------------------
create or replace function public._create_alert(
  p_property_id uuid,
  p_code text,
  p_severity text,
  p_title text,
  p_payload jsonb default '{}'::jsonb,
  p_doc_type text default null,
  p_doc_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid;
  v_org_id uuid;
begin
  -- Resolve the org from the property; chain-wide alerts (no property)
  -- have no org. Production's alerts table (from the reconciled wip
  -- migration) carries org_id, now nullable — see the preamble.
  select p.org_id into v_org_id
  from public.properties p
  where p.id = p_property_id;
  insert into public.alerts
    (org_id, property_id, code, severity, title, payload, doc_type, doc_id)
  values
    (v_org_id, p_property_id, p_code, p_severity, p_title, p_payload, p_doc_type, p_doc_id)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public._create_alert(uuid, text, text, text, jsonb, text, uuid)
  from public, anon, authenticated;

-- SoD guard (docs/04-SECURITY-RLS.md §6). Call AFTER the caller has
-- established that the acting user is the same person as the first actor.
-- A valid sod_exceptions row lets the action pass and records an
-- SOD_EXCEPTION_USED alert; otherwise raises ERR_<rule_code> (e.g.
-- ERR_SOD_BANK_ACCOUNT when p_rule_code is 'SOD_BANK_ACCOUNT').
create or replace function public._sod_check(
  p_property_id uuid,
  p_rule_code text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if exists (
    select 1
    from public.sod_exceptions e
    where e.property_id = p_property_id
      and e.user_id = auth.uid()
      and e.rule_code = p_rule_code
      and e.valid_to >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
  ) then
    perform public._create_alert(
      p_property_id,
      'SOD_EXCEPTION_USED',
      'warn',
      'Đã dùng ngoại lệ tách biệt nhiệm vụ',
      jsonb_build_object('rule_code', p_rule_code)
    );
    return;
  end if;
  raise exception 'ERR_%', p_rule_code;
end;
$$;

revoke all on function public._sod_check(uuid, text)
  from public, anon, authenticated;

-- Vendor assessment warnings (M01 01.04). SECURITY DEFINER because the
-- staff-phone check reads profiles.phone across users; returns only warning
-- codes/messages, never other users' data. Caller must hold supplier.view
-- somewhere in the supplier's org.
create or replace function public.supplier_assessment_warnings(
  p_supplier_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_sup record;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_sup from public.suppliers where id = p_supplier_id;
  if not found then
    raise exception 'ERR_FORBIDDEN:supplier.view';
  end if;

  if not (
    exists (
      select 1
      from public.properties p
      where p.org_id = v_sup.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'supplier.view')
    )
    or (select public.has_perm(null, 'supplier.view'))
  ) then
    raise exception 'ERR_FORBIDDEN:supplier.view';
  end if;

  -- 1. Phone duplicates a staff member's phone (M01 01.04).
  if v_sup.phone is not null and btrim(v_sup.phone) <> '' and exists (
    select 1 from public.profiles pr where pr.phone = v_sup.phone
  ) then
    v_warnings := v_warnings || jsonb_build_object(
      'code', 'PHONE_MATCHES_STAFF',
      'message', 'Số điện thoại trùng với số điện thoại của một nhân viên'
    );
  end if;

  -- 2. Bank account number already used by another supplier.
  if exists (
    select 1
    from public.supplier_bank_accounts b
    where b.supplier_id <> v_sup.id
      and b.status in ('pending', 'active')
      and exists (
        select 1
        from public.supplier_bank_accounts b2
        where b2.supplier_id = v_sup.id
          and b2.status in ('pending', 'active')
          and b2.account_no = b.account_no
      )
  ) then
    v_warnings := v_warnings || jsonb_build_object(
      'code', 'BANK_ACCOUNT_DUPLICATE',
      'message', 'Số tài khoản đã được dùng bởi một nhà cung cấp khác'
    );
  end if;

  -- 3. Company supplier without a tax code.
  if v_sup.kind = 'company'
    and (v_sup.tax_code is null or btrim(v_sup.tax_code) = '') then
    v_warnings := v_warnings || jsonb_build_object(
      'code', 'TAX_CODE_MISSING',
      'message', 'Nhà cung cấp là công ty nhưng chưa có mã số thuế'
    );
  end if;

  return v_warnings;
end;
$$;

revoke all on function public.supplier_assessment_warnings(uuid)
  from public, anon;
grant execute on function public.supplier_assessment_warnings(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Supplier status guard: status / approved_by / approved_at / bank_changed_at
-- may only change inside an RPC (supplier_approve / supplier_set_status /
-- supplier_bank_approve), which sets the transaction-local flag
-- `app.supplier_status_guard_bypass` first. Direct writes raise
-- ERR_INVALID_STATUS.
-- ---------------------------------------------------------------------------
create or replace function public._supplier_status_guard()
returns trigger
language plpgsql
as $$
begin
  if (
    old.status is distinct from new.status
    or old.approved_by is distinct from new.approved_by
    or old.approved_at is distinct from new.approved_at
    or old.bank_changed_at is distinct from new.bank_changed_at
  ) and coalesce(
    current_setting('app.supplier_status_guard_bypass', true), ''
  ) <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return new;
end;
$$;

revoke all on function public._supplier_status_guard()
  from public, anon, authenticated;

drop trigger if exists trg_suppliers_status_guard on public.suppliers;
create trigger trg_suppliers_status_guard
before update on public.suppliers
for each row execute function public._supplier_status_guard();

-- Delete guard: only a pending supplier with no bank accounts may be deleted.
create or replace function public._supplier_delete_guard()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from public.supplier_bank_accounts b where b.supplier_id = old.id
  ) then
    raise exception 'ERR_SUPPLIER_HAS_BANK_ACCOUNTS';
  end if;
  if old.status <> 'pending' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return old;
end;
$$;

revoke all on function public._supplier_delete_guard()
  from public, anon, authenticated;

drop trigger if exists trg_suppliers_delete_guard on public.suppliers;
create trigger trg_suppliers_delete_guard
before delete on public.suppliers
for each row execute function public._supplier_delete_guard();

-- ---------------------------------------------------------------------------
-- Price-agreement overlap (M01 01.05): no two ACTIVE agreements of the same
-- supplier may overlap in validity while sharing an (item_id, uom) line.
-- Drafts may overlap; the check runs when a line changes or when an
-- agreement is activated / its validity changes.
-- ---------------------------------------------------------------------------
create or replace function public._check_price_agreement_overlap(
  p_agreement_id uuid
)
returns void
language plpgsql
as $$
declare
  v_ag record;
begin
  select * into v_ag
  from public.price_agreements where id = p_agreement_id;
  if not found or v_ag.status <> 'active' then
    return;
  end if;

  if exists (
    select 1
    from public.price_agreement_lines l
    join public.price_agreements a2
      on a2.id = l.agreement_id
    join public.price_agreements a1
      on a1.id = p_agreement_id
    where a2.id <> p_agreement_id
      and a2.supplier_id = v_ag.supplier_id
      and a2.status = 'active'
      and a2.valid_from <= coalesce(a1.valid_to, '9999-12-31'::date)
      and coalesce(a2.valid_to, '9999-12-31'::date) >= a1.valid_from
      and exists (
        select 1
        from public.price_agreement_lines l1
        where l1.agreement_id = p_agreement_id
          and l1.item_id = l.item_id
          and l1.uom = l.uom
      )
  ) then
    raise exception 'ERR_AGREEMENT_OVERLAP';
  end if;
end;
$$;

revoke all on function public._check_price_agreement_overlap(uuid)
  from public, anon, authenticated;

create or replace function public._price_agreement_line_overlap_guard()
returns trigger
language plpgsql
as $$
begin
  perform public._check_price_agreement_overlap(coalesce(new.agreement_id, old.agreement_id));
  return coalesce(new, old);
end;
$$;

revoke all on function public._price_agreement_line_overlap_guard()
  from public, anon, authenticated;

drop trigger if exists trg_price_agreement_lines_overlap on public.price_agreement_lines;
create trigger trg_price_agreement_lines_overlap
after insert or update or delete on public.price_agreement_lines
for each row execute function public._price_agreement_line_overlap_guard();

create or replace function public._price_agreement_overlap_guard()
returns trigger
language plpgsql
as $$
begin
  if old.status is distinct from new.status
    or old.valid_from is distinct from new.valid_from
    or old.valid_to is distinct from new.valid_to then
    perform public._check_price_agreement_overlap(new.id);
  end if;
  return new;
end;
$$;

revoke all on function public._price_agreement_overlap_guard()
  from public, anon, authenticated;

drop trigger if exists trg_price_agreements_overlap on public.price_agreements;
create trigger trg_price_agreements_overlap
after update of status, valid_from, valid_to on public.price_agreements
for each row execute function public._price_agreement_overlap_guard();

-- ---------------------------------------------------------------------------
-- Ceiling price resolution (05-BUSINESS-RULES.md §2): property-specific
-- wins over chain-wide, then latest valid_from wins. Internal helper;
-- T-020 calls it at PO creation.
-- ---------------------------------------------------------------------------
create or replace function public.current_ceiling_price(
  p_org_id uuid,
  p_property_id uuid,
  p_item_id uuid,
  p_uom text,
  p_date date default (now() at time zone 'Asia/Ho_Chi_Minh')::date
)
returns numeric(18, 4)
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select price
  from public.ceiling_prices
  where org_id = p_org_id
    and item_id = p_item_id
    and uom = p_uom
    and valid_from <= p_date
    and coalesce(valid_to, '9999-12-31'::date) >= p_date
    and (property_id is null or property_id = p_property_id)
  order by (property_id is not null) desc, valid_from desc, created_at desc
  limit 1;
$$;

revoke all on function public.current_ceiling_price(uuid, uuid, uuid, text, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPCs: supplier_submit / supplier_approve / supplier_set_status /
-- supplier_bank_request / supplier_bank_approve
-- (names per docs/09-API-RPC.md §1).
-- ---------------------------------------------------------------------------
create or replace function public.supplier_submit(
  p_property_id uuid,
  p_supplier_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_sup record;
begin
  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:supplier.manage';
  end if;
  perform public.require_perm(p_property_id, 'supplier.manage');

  select * into v_sup
  from public.suppliers
  where id = p_supplier_id and org_id = v_org;
  if not found then
    raise exception 'ERR_FORBIDDEN:supplier.manage';
  end if;
  if v_sup.status <> 'pending' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_supplier_id,
    'warnings', public.supplier_assessment_warnings(p_supplier_id)
  );
end;
$$;

revoke all on function public.supplier_submit(uuid, uuid)
  from public, anon;
grant execute on function public.supplier_submit(uuid, uuid)
  to authenticated;

create or replace function public.supplier_approve(
  p_property_id uuid,
  p_supplier_id uuid,
  p_approved boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_sup record;
begin
  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:supplier.approve';
  end if;
  perform public.require_perm(p_property_id, 'supplier.approve');

  select * into v_sup
  from public.suppliers
  where id = p_supplier_id and org_id = v_org;
  if not found then
    raise exception 'ERR_FORBIDDEN:supplier.approve';
  end if;
  if v_sup.status <> 'pending' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if not p_approved and (p_reason is null or btrim(p_reason) = '') then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  -- SoD: approver must differ from the supplier creator (new rule
  -- SOD_SUPPLIER_APPROVER; see header decision 2).
  if v_sup.created_by = auth.uid() then
    perform public._sod_check(p_property_id, 'SOD_SUPPLIER_APPROVER');
  end if;

  if p_approved then
    perform set_config('app.supplier_status_guard_bypass', 'on', true);
    update public.suppliers
    set status = 'active',
        approved_by = auth.uid(),
        approved_at = now()
    where id = p_supplier_id;
  else
    -- Rejection keeps the supplier pending so the purchaser can correct
    -- and re-submit; the decision + reason are recorded in the audit trail
    -- (audit_log.action only allows INSERT/UPDATE/DELETE, so the decision
    -- is carried in new_data).
    insert into public.audit_log
      (table_name, row_id, action, new_data, actor)
    values (
      'suppliers', p_supplier_id, 'UPDATE',
      jsonb_build_object('decision', 'rejected', 'reason', p_reason), auth.uid()
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_supplier_id,
    'status', case when p_approved then 'active' else 'pending' end
  );
end;
$$;

revoke all on function public.supplier_approve(uuid, uuid, boolean, text)
  from public, anon;
grant execute on function public.supplier_approve(uuid, uuid, boolean, text)
  to authenticated;

create or replace function public.supplier_set_status(
  p_property_id uuid,
  p_supplier_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_sup record;
  v_ok boolean;
begin
  if p_status not in ('suspended', 'banned', 'active') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:supplier.manage';
  end if;
  perform public.require_perm(p_property_id, 'supplier.manage');

  select * into v_sup
  from public.suppliers
  where id = p_supplier_id and org_id = v_org;
  if not found then
    raise exception 'ERR_FORBIDDEN:supplier.manage';
  end if;

  -- Allowed transitions: active -> suspended/banned;
  -- suspended -> active/banned. Banned is terminal.
  v_ok := (v_sup.status = 'active' and p_status in ('suspended', 'banned'))
    or (v_sup.status = 'suspended' and p_status in ('active', 'banned'));
  if not v_ok then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.supplier_status_guard_bypass', 'on', true);
  update public.suppliers
  set status = p_status
  where id = p_supplier_id;

  -- The suppliers UPDATE above also fires the audit trigger; this extra row
  -- records the reason (audit_log.action only allows INSERT/UPDATE/DELETE).
  insert into public.audit_log
    (table_name, row_id, action, new_data, actor)
  values (
    'suppliers', p_supplier_id, 'UPDATE',
    jsonb_build_object('decision', 'set_status', 'status', p_status, 'reason', p_reason), auth.uid()
  );

  return jsonb_build_object('ok', true, 'id', p_supplier_id, 'status', p_status);
end;
$$;

revoke all on function public.supplier_set_status(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.supplier_set_status(uuid, uuid, text, text)
  to authenticated;

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
    (supplier_id, bank_name, account_no, account_name, status, requested_by)
  values
    (p_supplier_id, btrim(p_bank_name), btrim(p_account_no),
     btrim(p_account_name), 'pending', auth.uid())
  returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'warnings', v_warnings
  );
end;
$$;

revoke all on function public.supplier_bank_request(uuid, uuid, text, text, text)
  from public, anon;
grant execute on function public.supplier_bank_request(uuid, uuid, text, text, text)
  to authenticated;

create or replace function public.supplier_bank_approve(
  p_property_id uuid,
  p_bank_account_id uuid,
  p_approved boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_acc record;
  v_sup record;
begin
  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:supplier.bank.approve';
  end if;
  perform public.require_perm(p_property_id, 'supplier.bank.approve');

  select b.* into v_acc
  from public.supplier_bank_accounts b
  join public.suppliers s on s.id = b.supplier_id
  where b.id = p_bank_account_id
    and s.org_id = v_org;
  if not found then
    raise exception 'ERR_FORBIDDEN:supplier.bank.approve';
  end if;
  if v_acc.status <> 'pending' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if not p_approved and (p_reason is null or btrim(p_reason) = '') then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  -- SoD: the approver must differ from the requester (SOD_BANK_ACCOUNT).
  if v_acc.requested_by = auth.uid() then
    perform public._sod_check(p_property_id, 'SOD_BANK_ACCOUNT');
  end if;

  select * into v_sup from public.suppliers where id = v_acc.supplier_id;

  if p_approved then
    -- Revoke any previously active account of this supplier, activate the
    -- new one, and stamp the supplier so T-041 can enforce the 30-day
    -- extra-approval rule on payments.
    update public.supplier_bank_accounts
    set status = 'revoked'
    where supplier_id = v_acc.supplier_id
      and status = 'active';

    update public.supplier_bank_accounts
    set status = 'active',
        approved_by = auth.uid(),
        approved_at = now()
    where id = p_bank_account_id;

    perform set_config('app.supplier_status_guard_bypass', 'on', true);
    update public.suppliers
    set bank_changed_at = now()
    where id = v_acc.supplier_id;

    -- The BANK_ACCOUNT_CHANGE alert is created only on approval.
    perform public._create_alert(
      p_property_id,
      'BANK_ACCOUNT_CHANGE',
      'red',
      format(
        'Đổi tài khoản ngân hàng của NCC %s',
        v_sup.name
      ),
      jsonb_build_object(
        'supplier_id', v_sup.id,
        'supplier_code', v_sup.code,
        'supplier_name', v_sup.name,
        'bank_name', v_acc.bank_name,
        'account_no', v_acc.account_no,
        'account_name', v_acc.account_name
      ),
      'supplier_bank_accounts',
      p_bank_account_id
    );
  else
    update public.supplier_bank_accounts
    set status = 'revoked',
        approved_by = auth.uid(),
        approved_at = now()
    where id = p_bank_account_id;

    insert into public.audit_log
      (table_name, row_id, action, new_data, actor)
    values (
      'supplier_bank_accounts', p_bank_account_id, 'UPDATE',
      jsonb_build_object('decision', 'rejected', 'reason', p_reason), auth.uid()
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_bank_account_id,
    'status', case when p_approved then 'active' else 'revoked' end
  );
end;
$$;

revoke all on function public.supplier_bank_approve(uuid, uuid, boolean, text)
  from public, anon;
grant execute on function public.supplier_bank_approve(uuid, uuid, boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- RLS write policies + grants (select policies already exist from T-010).
-- supplier_bank_accounts stays RPC-only: no write policies, no write grants.
-- ---------------------------------------------------------------------------
create policy suppliers_insert on public.suppliers
for insert to authenticated
with check (
  exists (
    select 1
    from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  )
  or (select public.has_perm(null, 'supplier.manage'))
);

create policy suppliers_update on public.suppliers
for update to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  )
  or (select public.has_perm(null, 'supplier.manage'))
)
with check (
  exists (
    select 1
    from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  )
  or (select public.has_perm(null, 'supplier.manage'))
);

create policy suppliers_delete on public.suppliers
for delete to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = suppliers.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'supplier.manage')
  )
  or (select public.has_perm(null, 'supplier.manage'))
);

create policy price_agreements_insert on public.price_agreements
for insert to authenticated
with check (
  exists (
    select 1
    from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreements_update on public.price_agreements
for update to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
)
with check (
  exists (
    select 1
    from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreements_delete on public.price_agreements
for delete to authenticated
using (
  exists (
    select 1
    from public.properties p
    where p.org_id = price_agreements.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreement_lines_insert on public.price_agreement_lines
for insert to authenticated
with check (
  exists (
    select 1
    from public.price_agreements a
    join public.properties p on p.org_id = a.org_id
    where a.id = price_agreement_lines.agreement_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreement_lines_update on public.price_agreement_lines
for update to authenticated
using (
  exists (
    select 1
    from public.price_agreements a
    join public.properties p on p.org_id = a.org_id
    where a.id = price_agreement_lines.agreement_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
)
with check (
  exists (
    select 1
    from public.price_agreements a
    join public.properties p on p.org_id = a.org_id
    where a.id = price_agreement_lines.agreement_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy price_agreement_lines_delete on public.price_agreement_lines
for delete to authenticated
using (
  exists (
    select 1
    from public.price_agreements a
    join public.properties p on p.org_id = a.org_id
    where a.id = price_agreement_lines.agreement_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'price.agreement.manage')
  )
  or (select public.has_perm(null, 'price.agreement.manage'))
);

create policy ceiling_prices_insert on public.ceiling_prices
for insert to authenticated
with check (
  (
    ceiling_prices.property_id is null
    and (select public.has_perm(null, 'price.ceiling.manage'))
  )
  or (
    ceiling_prices.property_id in (select public.my_property_ids())
    and public.has_perm(ceiling_prices.property_id, 'price.ceiling.manage')
  )
);

create policy ceiling_prices_update on public.ceiling_prices
for update to authenticated
using (
  (
    ceiling_prices.property_id is null
    and (select public.has_perm(null, 'price.ceiling.manage'))
  )
  or (
    ceiling_prices.property_id in (select public.my_property_ids())
    and public.has_perm(ceiling_prices.property_id, 'price.ceiling.manage')
  )
)
with check (
  (
    ceiling_prices.property_id is null
    and (select public.has_perm(null, 'price.ceiling.manage'))
  )
  or (
    ceiling_prices.property_id in (select public.my_property_ids())
    and public.has_perm(ceiling_prices.property_id, 'price.ceiling.manage')
  )
);

create policy ceiling_prices_delete on public.ceiling_prices
for delete to authenticated
using (
  (
    ceiling_prices.property_id is null
    and (select public.has_perm(null, 'price.ceiling.manage'))
  )
  or (
    ceiling_prices.property_id in (select public.my_property_ids())
    and public.has_perm(ceiling_prices.property_id, 'price.ceiling.manage')
  )
);

grant insert, update, delete on public.suppliers to authenticated;
grant insert, update, delete on public.price_agreements to authenticated;
grant insert, update, delete on public.price_agreement_lines to authenticated;
grant insert, update, delete on public.ceiling_prices to authenticated;

-- ---------------------------------------------------------------------------
-- Sample role assignments (idempotent; mirrored in supabase/seed.sql).
-- Join on role code ALONE, mirroring supabase/seed.sql. Do NOT add an
-- `r.is_system = true` filter: keep the grant join minimal (code only) so
-- it cannot silently match zero rows if role flags ever differ.
-- NOTE (09/11/2026): the earlier claim that migration 20261109150000
-- matched zero rows because of the is_system filter was WRONG. Production
-- roles are all is_system = true; the real cause was a version collision —
-- the wip migration 20261109150000_suppliers_and_prices.sql was already
-- applied under version 20261109150000, so db push skipped the H1 file
-- (same version). The 6 grants were restored by
-- 20261109170000_role_grants_repair.sql.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('gm', 'supplier.approve'),
  ('chief_accountant', 'supplier.approve'),
  ('purchaser', 'price.agreement.manage'),
  ('cost_controller', 'price.agreement.manage'),
  ('purchaser', 'price.view'),
  ('cost_controller', 'price.view'),
  ('chief_accountant', 'price.view'),
  ('gm', 'price.view'),
  ('gm', 'supplier.view'),
  ('chief_accountant', 'supplier.view'),
  ('cost_controller', 'supplier.view'),
  ('gm', 'alert.receive.bank_account_change'),
  ('chief_accountant', 'alert.receive.bank_account_change')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109160000_suppliers_pricing',
  'INSERT',
  jsonb_build_object('event', 'suppliers_pricing_schema_created', 'task', 'T-013'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
