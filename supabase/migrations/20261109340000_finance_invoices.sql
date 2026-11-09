-- T-040: Hoa don, khop 3 chieu, so cong no ap_ledger, bang ke khong hoa
-- don, quyet toan tam ung, de nghi thanh toan (MVP-D, migration 12).
-- Spec: 03-DATA-MODEL.md A9, 05-BUSINESS-RULES.md §8, 09-API-RPC.md §7.
--
-- QUYET DINH (xem them Q65-Q72 o docs/OPEN-QUESTIONS.md):
--  D1. Khop 3 chieu theo dong: so luong hoa don <= so luong DA NHAN
--      (tong accepted_qty_stock cua GR da 'posted') TRU di so luong da
--      hoa don o cac hoa don khac (trang thai matched/approved/
--      partially_paid/paid) — chong hoa don trung so nhan. Dung sai so
--      luong = 0. Don gia: |gia hoa don - gia PO| <= gia PO * dung sai,
--      dung sai doc tu settings 'invoice_price_tolerance_pct' qua
--      _setting_get (mac dinh 1%, 09 §10).
--  D2. So luong hoa don tinh theo DON VI TON KHO (stock UOM), vi so
--      nhan (accepted_qty_stock) luon o don vi ton kho. Gia PO so sanh
--      la purchase_order_lines.unit_price; so luong PO dung
--      coalesce(qty_stock, qty).
--  D3. Chi hoa don 'matched' moi duyet duoc; duyet ghi ap_ledger (+)
--      voi due_date = invoice_date + payment_terms_days cua NCC
--      (mac dinh 0 ngay neu NCC khong dat). SoD: nguoi tao hoa don
--      khong duoc duyet (SOD_INVOICE_CREATOR_APPROVER).
--  D4. Tra hang: dinh nghia lai supplier_return_post tu ban LIVE
--      270000 (giu nguyen ca 2 dong bypass) + them nhanh ap_ledger (-)
--      CHI cho phan da co hoa don duyet: toi da = min(so tra, tong so
--      luong hoa don duyet cua dong GR - so da tra truoc do), gia =
--      don gia hoa don duyet som nhat. Khong co hoa don duyet thi
--      khong ghi ap_ledger (dung ghi chu T-023).
--  D5. De nghi thanh toan: tao la 'submitted' + sinh buoc duyet.
--      _generate_approval_steps('payment_request') chi sinh buoc khi
--      admin da cau hinh approval_rules cho doc_type nay (hien chua co
--      dong rule nao); neu 0 buoc thi mac dinh 1 buoc chief_accountant
--      (payment.approve). Doi STK NCC trong 30 ngay gan nhat
--      (suppliers.bank_changed_at, T-013) thi them buoc 2: owner
--      (payment.approve) — vi vay migration nay gan them
--      'payment.approve' cho role 'owner' (ma quyen da co trong
--      catalog, chua gan owner).
--  D6. Quyet toan tam ung: tu trang thai disbursed/settling/overdue
--      (quyet toan la cach thoat 'overdue', khong bi chan); SoD nguoi
--      giu tam ung khong duoc tu quyet toan (SOD_ADVANCE_SETTLER).
--      Thua -> refund_amount, thieu -> extra_pay_amount.
--  D7. Bang ke khong hoa don: them 2 RPC nho ngoai §7
--      (no_invoice_listing_save/approve) de bang dung duoc; phe duyet
--      KHONG ghi ap_ledger (chua co co so spec) — xem Q71.
--  D8. ap_ledger chi INSERT: trigger forbid_mutation (co san) chan
--      UPDATE/DELETE + write-guard chan ghi truc tiep. service_acceptances
--      / service_schedules thuoc T-042, KHONG lam o day.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Bang moi
-- ---------------------------------------------------------------------------

create table public.supplier_invoices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  supplier_id uuid not null references public.suppliers(id),
  doc_no text not null,
  invoice_symbol text not null check (btrim(invoice_symbol) <> ''),
  invoice_no text not null check (btrim(invoice_no) <> ''),
  invoice_date date not null,
  lookup_code text,
  xml_path text,
  amount_before_tax numeric(18,2) not null default 0 check (amount_before_tax >= 0),
  vat_amount numeric(18,2) not null default 0 check (vat_amount >= 0),
  total numeric(18,2) not null default 0 check (total >= 0),
  status text not null default 'draft'
    check (status in ('draft', 'matched', 'on_hold', 'approved', 'partially_paid', 'paid', 'cancelled')),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no)
);

-- Chong hoa don trung so/ký hieu cua cung NCC trong cung phap nhan.
-- Hoa don da huy khong tinh (duoc nhap lai so cu neu can).
create unique index uq_supplier_invoices_number
  on public.supplier_invoices (legal_entity_id, supplier_id, invoice_symbol, invoice_no)
  where status <> 'cancelled';

create table public.supplier_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.properties(id),
  po_line_id uuid not null,
  gr_line_id uuid,
  item_id uuid,
  qty numeric(18,4) not null check (qty > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  amount numeric(18,2) not null check (amount >= 0),
  vat_rate numeric(6,2) not null default 0 check (vat_rate >= 0 and vat_rate <= 100),
  vat_amount numeric(18,2) not null default 0 check (vat_amount >= 0),
  match_result jsonb not null default '{}'::jsonb check (jsonb_typeof(match_result) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (invoice_id, org_id) references public.supplier_invoices(id, org_id) on delete cascade,
  foreign key (po_line_id, org_id) references public.purchase_order_lines(id, org_id),
  foreign key (gr_line_id, org_id) references public.goods_receipt_lines(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id)
);

create table public.no_invoice_listings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  po_id uuid,
  gr_id uuid,
  doc_no text not null,
  seller_name text not null check (btrim(seller_name) <> ''),
  seller_address text,
  seller_id_no text,
  purchase_date date not null,
  status text not null default 'draft'
    check (status in ('draft', 'approved', 'cancelled')),
  total numeric(18,2) not null default 0 check (total >= 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  foreign key (po_id, org_id) references public.purchase_orders(id, org_id),
  foreign key (gr_id, org_id) references public.goods_receipts(id, org_id)
);

create table public.no_invoice_listing_lines (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  item_desc text not null check (btrim(item_desc) <> ''),
  qty numeric(18,4) not null check (qty > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  amount numeric(18,2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (listing_id, org_id) references public.no_invoice_listings(id, org_id) on delete cascade
);

create table public.ap_ledger (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  supplier_id uuid not null references public.suppliers(id),
  doc_type text not null
    check (doc_type in ('supplier_invoice', 'supplier_return', 'payment_request', 'advance_settlement')),
  doc_id uuid not null,
  amount numeric(18,2) not null check (amount <> 0),
  due_date date,
  entry_date date not null,
  created_at timestamptz not null default now(),
  unique (id, org_id)
);

create table public.advance_settlements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  advance_id uuid not null references public.advances(id),
  doc_no text not null,
  amount numeric(18,2) not null check (amount >= 0),
  refund_amount numeric(18,2) not null default 0 check (refund_amount >= 0),
  extra_pay_amount numeric(18,2) not null default 0 check (extra_pay_amount >= 0),
  settled_by uuid references auth.users(id),
  settled_at timestamptz not null default now(),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  unique (advance_id)
);

create table public.advance_settlement_lines (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  gr_id uuid,
  amount numeric(18,2) not null check (amount > 0),
  receipt_photo_id uuid,
  created_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (settlement_id, org_id) references public.advance_settlements(id, org_id) on delete cascade,
  foreign key (gr_id, org_id) references public.goods_receipts(id, org_id)
);

create table public.payment_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  supplier_id uuid not null references public.suppliers(id),
  doc_no text not null,
  total numeric(18,2) not null check (total >= 0),
  due_date date,
  status text not null default 'submitted'
    check (status in ('draft', 'submitted', 'approved', 'paid', 'cancelled')),
  paid_at timestamptz,
  bank_ref text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no)
);

create table public.payment_request_lines (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  invoice_id uuid not null,
  amount numeric(18,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (request_id, org_id) references public.payment_requests(id, org_id) on delete cascade,
  foreign key (invoice_id, org_id) references public.supplier_invoices(id, org_id)
);

-- ---------------------------------------------------------------------------
-- 2. Index phu
-- ---------------------------------------------------------------------------
create index idx_supplier_invoices_supplier on public.supplier_invoices (supplier_id, invoice_date);
create index idx_supplier_invoices_status on public.supplier_invoices (property_id, status);
create index idx_supplier_invoice_lines_po on public.supplier_invoice_lines (po_line_id);
create index idx_supplier_invoice_lines_gr on public.supplier_invoice_lines (gr_line_id);
create index idx_ap_ledger_supplier on public.ap_ledger (supplier_id, entry_date);
create index idx_ap_ledger_doc on public.ap_ledger (doc_type, doc_id);
create index idx_advance_settlements_advance on public.advance_settlements (advance_id);
create index idx_payment_requests_supplier on public.payment_requests (supplier_id, status);
create index idx_payment_request_lines_invoice on public.payment_request_lines (invoice_id);
create index idx_no_invoice_listings_po on public.no_invoice_listings (po_id) where po_id is not null;

-- ---------------------------------------------------------------------------
-- 3. Write-guard + so cai bat bien + updated_at
-- ---------------------------------------------------------------------------
create or replace function public._finance_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.finance_guard_bypass', true), '') <> 'on' then
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
    'supplier_invoices', 'supplier_invoice_lines',
    'no_invoice_listings', 'no_invoice_listing_lines',
    'ap_ledger',
    'advance_settlements', 'advance_settlement_lines',
    'payment_requests', 'payment_request_lines'
  ] loop
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function public._finance_write_guard()',
      'trg_' || v_table || '_write_guard', v_table
    );
  end loop;
end $$;

-- ap_ledger chi INSERT: chan UPDATE/DELETE bang trigger bat bien dung
-- chung voi audit_log (AGENTS.md §3 quy tac 2).
create trigger trg_ap_ledger_immutable
before update or delete on public.ap_ledger
for each row execute function public.forbid_mutation();

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'supplier_invoices', 'supplier_invoice_lines',
    'no_invoice_listings',
    'payment_requests'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. RLS: bat 100% + policy SELECT-only (mau T-030 §5 / T-034 §5 / T-035).
--    Ghi truc tiep bi chan; RPC SECURITY DEFINER ghi.
--    Dung `in (select public.my_property_ids())` — TUYET DOI KHONG dung
--    `= any (public.my_property_ids())` (loi 0A000 khi db push).
-- ---------------------------------------------------------------------------
alter table public.supplier_invoices enable row level security;
alter table public.supplier_invoice_lines enable row level security;
alter table public.no_invoice_listings enable row level security;
alter table public.no_invoice_listing_lines enable row level security;
alter table public.ap_ledger enable row level security;
alter table public.advance_settlements enable row level security;
alter table public.advance_settlement_lines enable row level security;
alter table public.payment_requests enable row level security;
alter table public.payment_request_lines enable row level security;

create policy supplier_invoices_select on public.supplier_invoices
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'invoice.manage')
    or public.has_perm(property_id, 'invoice.approve')
    or public.has_perm(property_id, 'ap.view')
    or public.has_perm(property_id, 'payment.request')
    or public.has_perm(property_id, 'payment.approve')
    or public.has_perm(property_id, 'payment.mark_paid')
    or public.has_perm(property_id, 'report.view.rpt_open_po_invoice')
    or public.has_perm(property_id, 'report.view.rpt_ap_aging')
  )
);

create policy supplier_invoice_lines_select on public.supplier_invoice_lines
for select using (
  exists (
    select 1 from public.supplier_invoices si
    where si.id = supplier_invoice_lines.invoice_id
      and si.property_id in (select public.my_property_ids())
      and (
        public.has_perm(si.property_id, 'invoice.manage')
        or public.has_perm(si.property_id, 'invoice.approve')
        or public.has_perm(si.property_id, 'ap.view')
        or public.has_perm(si.property_id, 'payment.request')
        or public.has_perm(si.property_id, 'payment.approve')
        or public.has_perm(si.property_id, 'payment.mark_paid')
        or public.has_perm(si.property_id, 'report.view.rpt_open_po_invoice')
        or public.has_perm(si.property_id, 'report.view.rpt_ap_aging')
      )
  )
);

create policy no_invoice_listings_select on public.no_invoice_listings
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'invoice.manage')
    or public.has_perm(property_id, 'invoice.approve')
    or public.has_perm(property_id, 'ap.view')
  )
);

create policy no_invoice_listing_lines_select on public.no_invoice_listing_lines
for select using (
  exists (
    select 1 from public.no_invoice_listings l
    where l.id = no_invoice_listing_lines.listing_id
      and l.property_id in (select public.my_property_ids())
      and (
        public.has_perm(l.property_id, 'invoice.manage')
        or public.has_perm(l.property_id, 'invoice.approve')
        or public.has_perm(l.property_id, 'ap.view')
      )
  )
);

create policy ap_ledger_select on public.ap_ledger
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'ap.view')
    or public.has_perm(property_id, 'invoice.manage')
    or public.has_perm(property_id, 'invoice.approve')
    or public.has_perm(property_id, 'payment.request')
    or public.has_perm(property_id, 'payment.approve')
    or public.has_perm(property_id, 'payment.mark_paid')
    or public.has_perm(property_id, 'report.view.rpt_ap_aging')
  )
);

create policy advance_settlements_select on public.advance_settlements
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'advance.settle')
    or public.has_perm(property_id, 'advance.approve')
    or public.has_perm(property_id, 'advance.disburse')
    or public.has_perm(property_id, 'report.view.rpt_advances')
  )
);

create policy advance_settlement_lines_select on public.advance_settlement_lines
for select using (
  exists (
    select 1 from public.advance_settlements s
    where s.id = advance_settlement_lines.settlement_id
      and s.property_id in (select public.my_property_ids())
      and (
        public.has_perm(s.property_id, 'advance.settle')
        or public.has_perm(s.property_id, 'advance.approve')
        or public.has_perm(s.property_id, 'advance.disburse')
        or public.has_perm(s.property_id, 'report.view.rpt_advances')
      )
  )
);

create policy payment_requests_select on public.payment_requests
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'payment.request')
    or public.has_perm(property_id, 'payment.approve')
    or public.has_perm(property_id, 'payment.mark_paid')
    or public.has_perm(property_id, 'ap.view')
    or public.has_perm(property_id, 'report.view.rpt_ap_aging')
  )
);

create policy payment_request_lines_select on public.payment_request_lines
for select using (
  exists (
    select 1 from public.payment_requests pr
    where pr.id = payment_request_lines.request_id
      and pr.property_id in (select public.my_property_ids())
      and (
        public.has_perm(pr.property_id, 'payment.request')
        or public.has_perm(pr.property_id, 'payment.approve')
        or public.has_perm(pr.property_id, 'payment.mark_paid')
        or public.has_perm(pr.property_id, 'ap.view')
        or public.has_perm(pr.property_id, 'report.view.rpt_ap_aging')
      )
  )
);

-- ---------------------------------------------------------------------------
-- 5. Gan quyen (quyet dinh D5): 'payment.approve' cho role 'owner' de
--    buoc duyet bo sung khi doi STK trong 30 ngay chay duoc. Ma quyen da
--    co trong catalog (141000), chi gan them — khong tao ma moi.
--    Join theo ma role, ap dung moi org hien co, idempotent.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, 'payment.approve'
from public.roles r
where r.code = 'owner'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 6. RPC hoa don
-- ---------------------------------------------------------------------------

-- Nhap hoa don nhap (draft). Tong tien tinh server-side tu dong.
-- p_header: {"invoice_symbol", "invoice_no", "invoice_date",
--   "lookup_code"?, "xml_path"?}.
-- p_lines: [{"po_line_id", "gr_line_id"?, "qty", "unit_price",
--   "vat_rate"?}]. So luong o don vi ton kho (quyet dinh D2).
create or replace function public.invoice_save_draft(
  p_property_id uuid,
  p_supplier_id uuid,
  p_header jsonb,
  p_lines jsonb
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
  v_symbol text;
  v_no text;
  v_date date;
  v_inv_id uuid;
  v_doc_no text;
  v_el jsonb;
  v_pol record;
  v_po record;
  v_grl record;
  v_qty numeric;
  v_price numeric;
  v_vat numeric;
  v_amt numeric(18,2);
  v_vat_amt numeric(18,2);
  v_before numeric(18,2) := 0;
  v_vat_total numeric(18,2) := 0;
begin
  select org_id, legal_entity_id into v_org, v_entity
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN:invoice.manage';
  end if;
  perform public.require_perm(p_property_id, 'invoice.manage');

  select * into v_sup from public.suppliers
  where id = p_supplier_id and org_id = v_org;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_sup.status <> 'active' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  -- NCC khong xuat hoa don (ca nhan khong hoa don) thi dung bang ke
  -- (no_invoice_listings), khong nhap hoa don VAT.
  if v_sup.kind = 'individual_no_invoice' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_header is null or jsonb_typeof(p_header) <> 'object' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  v_symbol := nullif(btrim(p_header ->> 'invoice_symbol'), '');
  v_no := nullif(btrim(p_header ->> 'invoice_no'), '');
  if v_symbol is null or v_no is null or (p_header ->> 'invoice_date') is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  begin
    v_date := (p_header ->> 'invoice_date')::date;
  exception when others then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end;

  -- Chong trung so hoa don (chi tinh hoa don chua huy).
  if exists (
    select 1 from public.supplier_invoices si
    where si.legal_entity_id = v_entity
      and si.supplier_id = p_supplier_id
      and si.invoice_symbol = v_symbol
      and si.invoice_no = v_no
      and si.status <> 'cancelled'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity, 'INV', v_date);

  insert into public.supplier_invoices (
    org_id, legal_entity_id, property_id, supplier_id, doc_no,
    invoice_symbol, invoice_no, invoice_date,
    lookup_code, xml_path, status
  ) values (
    v_org, v_entity, p_property_id, p_supplier_id, v_doc_no,
    v_symbol, v_no, v_date,
    nullif(btrim(p_header ->> 'lookup_code'), ''),
    nullif(btrim(p_header ->> 'xml_path'), ''),
    'draft'
  ) returning id into v_inv_id;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    if (v_el ->> 'po_line_id') is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_el ->> 'qty')::numeric;
    v_price := (v_el ->> 'unit_price')::numeric;
    v_vat := coalesce((v_el ->> 'vat_rate')::numeric, 0);
    if v_qty is null or v_qty <= 0 or v_price is null or v_price < 0
      or v_vat < 0 or v_vat > 100 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    select pol.* into v_pol
    from public.purchase_order_lines pol
    where pol.id = (v_el ->> 'po_line_id')::uuid
      and pol.org_id = v_org;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    select po.* into v_po
    from public.purchase_orders po where po.id = v_pol.po_id;
    if v_po.supplier_id <> p_supplier_id
      or v_po.legal_entity_id <> v_entity
      or v_po.status not in ('approved', 'sent', 'partially_received', 'received', 'closed') then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    if (v_el ->> 'gr_line_id') is not null then
      select grl.* into v_grl
      from public.goods_receipt_lines grl
      join public.goods_receipts gr on gr.id = grl.gr_id
      where grl.id = (v_el ->> 'gr_line_id')::uuid
        and grl.po_line_id = v_pol.id
        and gr.status = 'posted';
      if not found then
        raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
      end if;
    end if;

    v_amt := round(v_qty * v_price, 2);
    v_vat_amt := round(v_amt * v_vat / 100, 2);
    v_before := v_before + v_amt;
    v_vat_total := v_vat_total + v_vat_amt;

    insert into public.supplier_invoice_lines (
      invoice_id, org_id, property_id, po_line_id, gr_line_id, item_id,
      qty, unit_price, amount, vat_rate, vat_amount
    ) values (
      v_inv_id, v_org, p_property_id, v_pol.id,
      (v_el ->> 'gr_line_id')::uuid, v_pol.item_id,
      v_qty, v_price, v_amt, v_vat, v_vat_amt
    );
  end loop;

  update public.supplier_invoices
  set amount_before_tax = v_before,
      vat_amount = v_vat_total,
      total = v_before + v_vat_total,
      updated_at = now()
  where id = v_inv_id;

  return jsonb_build_object(
    'ok', true, 'id', v_inv_id, 'doc_no', v_doc_no,
    'status', 'draft', 'total', v_before + v_vat_total
  );
end;
$$;

revoke all on function public.invoice_save_draft(uuid, uuid, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.invoice_save_draft(uuid, uuid, jsonb, jsonb)
  to authenticated;

-- Khop 3 chieu theo dong (05 §8, quyet dinh D1/D2): so luong <= so da
-- nhan tru di so da hoa don o hoa don khac; don gia trong dung sai
-- settings 'invoice_price_tolerance_pct'. Khop du -> 'matched',
-- khong thi 'on_hold' + match_result ghi ro tung dong.
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

    -- So da nhan: tong accepted_qty_stock cua GR da 'posted'.
    select coalesce(sum(grl.accepted_qty_stock), 0) into v_received
    from public.goods_receipt_lines grl
    join public.goods_receipts gr on gr.id = grl.gr_id
    where grl.po_line_id = v_pol.id
      and gr.status = 'posted';

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

-- Duyet hoa don da khop: ghi ap_ledger (+) voi due_date theo
-- payment_terms_days cua NCC. SoD: nguoi tao khong duoc duyet.
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
-- 7. RPC quyet toan tam ung
-- ---------------------------------------------------------------------------

-- Quyet toan tam ung theo so thuc nhan. p_lines:
-- [{"gr_id"?, "amount", "receipt_photo_id"?}]. Thua -> tra lai
-- (refund_amount), thieu -> tra them (extra_pay_amount). Quyet toan la
-- cach thoat 'overdue' nen tam ung qua han VAN duoc quyet toan (D6).
create or replace function public.advance_settle(
  p_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_adv record;
  v_el jsonb;
  v_gr record;
  v_spent numeric(18,2) := 0;
  v_refund numeric(18,2);
  v_extra numeric(18,2);
  v_settle_id uuid;
  v_doc_no text;
begin
  select * into v_adv from public.advances where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_adv.property_id, 'advance.settle');
  if v_adv.status not in ('disbursed', 'settling', 'overdue') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- SoD: nguoi giu tam ung khong duoc tu quyet toan.
  if v_adv.employee_id = auth.uid() then
    perform public._sod_check(v_adv.property_id, 'SOD_ADVANCE_SETTLER');
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    if (v_el ->> 'amount')::numeric is null
      or (v_el ->> 'amount')::numeric <= 0 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    if (v_el ->> 'gr_id') is not null then
      select gr.* into v_gr
      from public.goods_receipts gr
      where gr.id = (v_el ->> 'gr_id')::uuid
        and gr.org_id = v_adv.org_id
        and gr.property_id = v_adv.property_id;
      if not found or v_gr.status <> 'posted' then
        raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
      end if;
    end if;
    v_spent := v_spent + (v_el ->> 'amount')::numeric;
  end loop;

  v_refund := greatest(v_adv.amount - v_spent, 0);
  v_extra := greatest(v_spent - v_adv.amount, 0);

  perform set_config('app.advance_guard_bypass', 'on', true);
  perform set_config('app.finance_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(
    v_adv.legal_entity_id, 'STL',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date);

  insert into public.advance_settlements (
    org_id, legal_entity_id, property_id, advance_id, doc_no,
    amount, refund_amount, extra_pay_amount, settled_by
  ) values (
    v_adv.org_id, v_adv.legal_entity_id, v_adv.property_id, p_id, v_doc_no,
    v_spent, v_refund, v_extra, auth.uid()
  ) returning id into v_settle_id;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.advance_settlement_lines (
      settlement_id, org_id, gr_id, amount, receipt_photo_id
    ) values (
      v_settle_id, v_adv.org_id,
      (v_el ->> 'gr_id')::uuid,
      (v_el ->> 'amount')::numeric,
      (v_el ->> 'receipt_photo_id')::uuid
    );
  end loop;

  update public.advances
  set status = 'settled',
      settled_at = now(),
      updated_at = now()
  where id = p_id;

  return jsonb_build_object(
    'ok', true, 'id', v_settle_id, 'advance_id', p_id,
    'doc_no', v_doc_no, 'spent', v_spent,
    'refund_amount', v_refund, 'extra_pay_amount', v_extra,
    'status', 'settled'
  );
end;
$$;

revoke all on function public.advance_settle(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.advance_settle(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. RPC de nghi thanh toan
-- ---------------------------------------------------------------------------

-- Tao de nghi thanh toan (status 'submitted' + sinh buoc duyet).
-- p_lines: [{"invoice_id", "amount"}]. Chi hoa don approved /
-- partially_paid, so tien <= so con lai (total - da tra - da de nghi).
-- Doi STK trong 30 ngay -> them buoc duyet owner (quyet dinh D5).
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

-- Duyet/tu choi de nghi thanh toan theo co che duyet chung (mau
-- _decide_approval cua T-020, viet rieng vi ham goc chi ho tro pr/po).
-- Tu choi -> status 'cancelled' (bang khong co 'rejected').
create or replace function public.payment_request_decide(
  p_property_id uuid,
  p_request_id uuid,
  p_decision text,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req record;
  v_step public.approvals%rowtype;
  v_pending integer;
  v_new_status text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select * into v_req
  from public.payment_requests where id = p_request_id;
  if not found or v_req.property_id <> p_property_id then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if v_req.status <> 'submitted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select * into v_step
  from public.approvals a
  where a.doc_type = 'payment_request'
    and a.doc_id = p_request_id
    and a.decision = 'pending'
  order by a.step asc
  limit 1;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(p_property_id, v_step.required_perm);

  if not public._approval_can_decide(p_property_id, v_step.id) then
    raise exception using errcode = 'P0001', message = 'ERR_NOT_APPROVER';
  end if;

  if v_req.created_by = auth.uid() then
    perform public._sod_check(p_property_id, 'SOD_PAYMENT_CREATOR_APPROVER');
  end if;

  if p_decision = 'rejected'
    and (p_comment is null or btrim(p_comment) = '') then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.approvals a
  set decision = p_decision,
      comment = p_comment,
      decided_by = auth.uid(),
      decided_at = now(),
      delegated_from = case
        when auth.uid() <> coalesce(v_step.approver_user_id, auth.uid())
          and v_step.approver_user_id is not null
        then v_step.approver_user_id
        else (
          select d.from_user
          from public.approval_delegations d
          where d.org_id = v_step.org_id
            and d.to_user = auth.uid()
            and (d.property_id is null or d.property_id = p_property_id)
            and (now() at time zone 'Asia/Ho_Chi_Minh')::date
              between d.valid_from and d.valid_to
          order by d.valid_from desc
          limit 1
        )
      end
  where a.id = v_step.id;

  if p_decision = 'rejected' then
    v_new_status := 'cancelled';
  else
    select count(*) into v_pending
    from public.approvals a
    where a.doc_type = 'payment_request'
      and a.doc_id = p_request_id
      and a.decision = 'pending';
    v_new_status := case when v_pending = 0 then 'approved' else 'submitted' end;
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);
  update public.payment_requests
  set status = v_new_status, updated_at = now()
  where id = p_request_id;

  return jsonb_build_object(
    'ok', true, 'id', p_request_id, 'status', v_new_status
  );
end;
$$;

revoke all on function public.payment_request_decide(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.payment_request_decide(uuid, uuid, text, text)
  to authenticated;

-- Ghi nhan da thanh toan: ap_ledger (-) + cap nhat trang thai hoa don
-- (partially_paid / paid theo tong da tra).
create or replace function public.payment_mark_paid(
  p_id uuid,
  p_bank_ref text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req record;
  v_line record;
  v_paid numeric(18,2);
  v_inv_total numeric(18,2);
begin
  select * into v_req from public.payment_requests where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_req.property_id, 'payment.mark_paid');
  if v_req.status <> 'approved' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if p_bank_ref is null or btrim(p_bank_ref) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);

  insert into public.ap_ledger (
    org_id, legal_entity_id, property_id, supplier_id,
    doc_type, doc_id, amount, due_date, entry_date
  ) values (
    v_req.org_id, v_req.legal_entity_id, v_req.property_id, v_req.supplier_id,
    'payment_request', p_id, -v_req.total, v_req.due_date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );

  update public.payment_requests
  set status = 'paid',
      paid_at = now(),
      bank_ref = btrim(p_bank_ref),
      updated_at = now()
  where id = p_id;

  for v_line in
    select * from public.payment_request_lines where request_id = p_id
  loop
    select coalesce(sum(prl.amount), 0) into v_paid
    from public.payment_request_lines prl
    join public.payment_requests pr on pr.id = prl.request_id
    where prl.invoice_id = v_line.invoice_id
      and pr.status = 'paid';

    select total into v_inv_total
    from public.supplier_invoices where id = v_line.invoice_id;

    update public.supplier_invoices
    set status = case when v_paid >= v_inv_total then 'paid' else 'partially_paid' end,
        updated_at = now()
    where id = v_line.invoice_id
      and status in ('approved', 'partially_paid');
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', p_id, 'status', 'paid',
    'total', v_req.total, 'bank_ref', btrim(p_bank_ref)
  );
end;
$$;

revoke all on function public.payment_mark_paid(uuid, text)
  from public, anon, authenticated;
grant execute on function public.payment_mark_paid(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. RPC bang ke khong hoa don (them ngoai §7 — quyet dinh D7)
-- ---------------------------------------------------------------------------

-- Luu bang ke mua hang khong hoa don (nhap). p_listing:
-- {"seller_name", "seller_address"?, "seller_id_no"?, "purchase_date",
--  "po_id"?, "gr_id"?}. p_lines: [{"item_desc", "qty", "unit_price"}].
create or replace function public.no_invoice_listing_save(
  p_property_id uuid,
  p_listing jsonb,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_entity uuid;
  v_seller text;
  v_date date;
  v_list_id uuid;
  v_doc_no text;
  v_el jsonb;
  v_qty numeric;
  v_price numeric;
  v_amt numeric(18,2);
  v_total numeric(18,2) := 0;
begin
  select org_id, legal_entity_id into v_org, v_entity
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'ERR_FORBIDDEN:invoice.manage';
  end if;
  perform public.require_perm(p_property_id, 'invoice.manage');

  if p_listing is null or jsonb_typeof(p_listing) <> 'object' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  v_seller := nullif(btrim(p_listing ->> 'seller_name'), '');
  if v_seller is null or (p_listing ->> 'purchase_date') is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  begin
    v_date := (p_listing ->> 'purchase_date')::date;
  exception when others then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end;

  if (p_listing ->> 'po_id') is not null
    and not exists (
      select 1 from public.purchase_orders
      where id = (p_listing ->> 'po_id')::uuid
        and org_id = v_org and property_id = p_property_id
    ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if (p_listing ->> 'gr_id') is not null
    and not exists (
      select 1 from public.goods_receipts
      where id = (p_listing ->> 'gr_id')::uuid
        and org_id = v_org and property_id = p_property_id
    ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);

  v_doc_no := public.next_doc_no(v_entity, 'NIL', v_date);

  insert into public.no_invoice_listings (
    org_id, legal_entity_id, property_id, po_id, gr_id, doc_no,
    seller_name, seller_address, seller_id_no, purchase_date, status
  ) values (
    v_org, v_entity, p_property_id,
    (p_listing ->> 'po_id')::uuid,
    (p_listing ->> 'gr_id')::uuid,
    v_doc_no,
    v_seller,
    nullif(btrim(p_listing ->> 'seller_address'), ''),
    nullif(btrim(p_listing ->> 'seller_id_no'), ''),
    v_date, 'draft'
  ) returning id into v_list_id;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    if nullif(btrim(v_el ->> 'item_desc'), '') is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_el ->> 'qty')::numeric;
    v_price := (v_el ->> 'unit_price')::numeric;
    if v_qty is null or v_qty <= 0 or v_price is null or v_price < 0 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    v_amt := round(v_qty * v_price, 2);
    v_total := v_total + v_amt;
    insert into public.no_invoice_listing_lines (
      listing_id, org_id, item_desc, qty, unit_price, amount
    ) values (
      v_list_id, v_org,
      btrim(v_el ->> 'item_desc'), v_qty, v_price, v_amt
    );
  end loop;

  update public.no_invoice_listings
  set total = v_total, updated_at = now()
  where id = v_list_id;

  return jsonb_build_object(
    'ok', true, 'id', v_list_id, 'doc_no', v_doc_no,
    'status', 'draft', 'total', v_total
  );
end;
$$;

revoke all on function public.no_invoice_listing_save(uuid, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.no_invoice_listing_save(uuid, jsonb, jsonb)
  to authenticated;

-- Duyet bang ke (ke toan truong). Khong ghi ap_ledger (quyet dinh D7).
create or replace function public.no_invoice_listing_approve(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_list record;
begin
  select * into v_list
  from public.no_invoice_listings where id = p_listing_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_list.property_id, 'invoice.approve');
  if v_list.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if v_list.created_by = auth.uid() then
    perform public._sod_check(v_list.property_id, 'SOD_INVOICE_CREATOR_APPROVER');
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);
  update public.no_invoice_listings
  set status = 'approved', updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object(
    'ok', true, 'id', p_listing_id, 'status', 'approved'
  );
end;
$$;

revoke all on function public.no_invoice_listing_approve(uuid)
  from public, anon, authenticated;
grant execute on function public.no_invoice_listing_approve(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Dinh nghia lai supplier_return_post (ban LIVE 270000 + nhanh
--     ap_ledger (-), quyet dinh D4). Than ham GIU NGUYEN tung chu so
--     voi 270000, chi them: 3 bien khai bao, 1 dong bypass finance,
--     va khoi ap_ledger (-) trong vong lap theo dong tra.
-- ---------------------------------------------------------------------------
create or replace function public.supplier_return_post(
  p_gr_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_el jsonb;
  v_gr_line record;
  v_pol record;
  v_returnable numeric;
  v_qty numeric;
  v_ret_id uuid;
  v_ret_no text;
  v_ret_line_id uuid;
  -- T-040: bien cho nhanh ap_ledger (-).
  v_invoiced_qty numeric;
  v_prev_returned numeric;
  v_ledger_qty numeric;
  v_inv_price numeric;
  v_inv_id uuid;
  v_ledger_due date;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'supplier_return.post');

  if v_gr.status <> 'posted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);
  -- Mo bypass T-020 (210000): _pr_po_write_guard chan moi ghi vao
  -- purchase_order_lines; _pr_po_status_guard cung chan doi status PO
  -- khi _receiving_update_po_status cap nhat. Dat sau moi kiem tra
  -- quyen/PIN/SoD, truoc ghi dau tien (theo dung mau T-020).
  perform set_config('app.pr_po_guard_bypass', 'on', true);
  -- T-040: mo bypass finance de ghi ap_ledger (-) (neu co).
  perform set_config('app.finance_guard_bypass', 'on', true);

  v_ret_no := public.next_doc_no(v_gr.legal_entity_id, 'SRT', v_today);

  insert into public.supplier_returns (
    org_id, legal_entity_id, property_id, gr_id, po_id, supplier_id,
    doc_no, status, reason
  ) values (
    v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
    p_gr_id, v_gr.po_id, v_gr.supplier_id,
    v_ret_no, 'posted', p_lines -> 0 ->> 'reason'
  ) returning id into v_ret_id;

  for v_el in select * from jsonb_array_elements(p_lines)
  loop
    v_qty := (v_el ->> 'qty_stock')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    select grl.* into v_gr_line
    from public.goods_receipt_lines grl
    where grl.id = (v_el ->> 'gr_line_id')::uuid
      and grl.gr_id = p_gr_id;

    -- Dong QC fail khong vao kho nen khong tra bang RPC nay.
    if v_gr_line.id is null or v_gr_line.qc_status = 'fail'
      or v_gr_line.posted_warehouse_id is null
      or v_gr_line.unit_cost is null then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    -- So tra toi da = da nhan - da tra (phieu tra da post).
    v_returnable := v_gr_line.accepted_qty_stock
      - public._receiving_returned_qty(v_gr_line.id);
    if v_qty > v_returnable then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    insert into public.supplier_return_lines (
      return_id, org_id, gr_line_id, item_id, qty_stock, unit_cost,
      reason, photo_ids, supplier_signature_path
    ) values (
      v_ret_id, v_gr.org_id, v_gr_line.id, v_gr_line.item_id, v_qty,
      v_gr_line.unit_cost,
      v_el ->> 'reason',
      coalesce(
        (select array_agg(x::uuid)
         from jsonb_array_elements_text(
           coalesce(v_el -> 'photo_ids', '[]'::jsonb)) x),
        '{}'),
      v_el ->> 'supplier_signature_path'
    ) returning id into v_ret_line_id;

    perform public._post_move(
      v_gr.legal_entity_id, v_gr.property_id,
      v_gr_line.posted_warehouse_id,
      v_gr_line.item_id, v_gr_line.lot_id, 'return_out', -v_qty,
      v_gr_line.unit_cost, v_today, 'supplier_return', v_ret_id,
      v_ret_line_id);

    select pol.* into v_pol
    from public.purchase_order_lines pol
    where pol.id = v_gr_line.po_line_id
    for update;

    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock - v_qty,
        updated_at = now()
    where id = v_pol.id;

    -- T-040: ap_ledger (-) cho phan da co hoa don duyet (05 §8).
    -- Khong co hoa don duyet thi khong ghi (dung ghi chu T-023).
    select coalesce(sum(sil.qty), 0) into v_invoiced_qty
    from public.supplier_invoice_lines sil
    join public.supplier_invoices si on si.id = sil.invoice_id
    where sil.gr_line_id = v_gr_line.id
      and si.status in ('approved', 'partially_paid', 'paid');

    if v_invoiced_qty > 0 then
      -- So da tra truoc do (tru phieu tra hien tai) de khong tru
      -- trung cong no cua cung 1 so luong.
      select coalesce(sum(srl.qty_stock), 0) into v_prev_returned
      from public.supplier_return_lines srl
      join public.supplier_returns sr on sr.id = srl.return_id
      where srl.gr_line_id = v_gr_line.id
        and sr.status = 'posted'
        and sr.id <> v_ret_id;

      v_ledger_qty := least(
        v_qty, greatest(v_invoiced_qty - v_prev_returned, 0));
      if v_ledger_qty > 0 then
        -- Gia hoa don duyet som nhat cua dong GR nay.
        select sil.unit_price, si.id into v_inv_price, v_inv_id
        from public.supplier_invoice_lines sil
        join public.supplier_invoices si on si.id = sil.invoice_id
        where sil.gr_line_id = v_gr_line.id
          and si.status in ('approved', 'partially_paid', 'paid')
        order by si.invoice_date, si.created_at
        limit 1;

        -- Han tra goc (theo ap_ledger (+) cua hoa don do).
        select al.due_date into v_ledger_due
        from public.ap_ledger al
        where al.doc_type = 'supplier_invoice'
          and al.doc_id = v_inv_id
        order by al.entry_date desc
        limit 1;

        insert into public.ap_ledger (
          org_id, legal_entity_id, property_id, supplier_id,
          doc_type, doc_id, amount, due_date, entry_date
        ) values (
          v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
          v_gr.supplier_id,
          'supplier_return', v_ret_id,
          -v_ledger_qty * v_inv_price,
          coalesce(v_ledger_due, v_today), v_today
        );
      end if;
    end if;
  end loop;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object('ok', true, 'id', v_ret_id, 'doc_no', v_ret_no);
end;
$$;

revoke all on function public.supplier_return_post(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.supplier_return_post(uuid, jsonb) to authenticated;
