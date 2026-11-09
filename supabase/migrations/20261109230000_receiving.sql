-- ============================================================================
-- T-023: Nhan hang mu (blind receiving) — Migration 07
-- Bang: goods_receipts, goods_receipt_lines, supplier_returns,
--       supplier_return_lines, qc_templates.
-- RPC: receiving_list_tasks, receiving_get_task, receiving_start,
--      receiving_record_line, receiving_override_line, receiving_post,
--      receiving_get_receipt, receiving_list_receipts, supplier_return_post,
--      receiving_reverse, admin_qc_template_save, admin_qc_template_delete.
-- Can cu: docs/03-DATA-MODEL.md A4, docs/05-BUSINESS-RULES.md §3,
--         docs/09-API-RPC.md §3, docs/04-SECURITY-RLS.md §8 (mu o tang du
--         lieu), docs/modules/M04-receiving.md, docs/11-TESTING.md §3.
-- AC: receiver SELECT purchase_order_lines = 0 dong; lech 6% -> needs_reweigh;
--     vuot PO bi chan tran (cap = so luong con mo x (1 + dung sai)).
--
-- Quyet dinh tu chot (danh so de Duy doi chieu; chi tiet them trong bao cao):
--   D1. PO du dieu kien nhan: sent/partially_received; PO market them approved
--       (Q20 da chot o T-022: market PO approved du dieu kien nhan, khong cho sent).
--   D2. Dung sai so voi so luong CON MO cua dong (qty_stock - received_qty_stock),
--       khong phai tong PO. Lan nhan dau so con mo = tong PO nen khop ca test
--       11-TESTING §3.3 (lech 6% tren 10kg -> needs_reweigh).
--   D3. Can lan 1 lech ngoai dung sai: needs_reweigh, accepted = 0, luu can 1.
--       Can lai (goi lai record_line cung dong): lan 2 ghi de, luu ca hai lan;
--       lan 2 van lech -> nhan so thuc, cap o con mo x (1 + dung sai); phan du
--       ghi over_po_qty_stock, chi receiving_override_line (storekeeper/gm, ly
--       do bat buoc) moi nhan du.
--   D4. QC fail: accepted = 0 + sinh supplier_returns 'recorded' ngay (khong
--       move kho). QC conditional: nhap kho quarantine; quyet dinh trong 24h
--       (ngoai pham vi T-023, khong co RPC quyet dinh).
--   D5. Anh bat buoc theo dong: item is_key_item hoac nhom kind = 'food'
--       (dac ta noi "thit, ca, hai san" nhung item_groups chi phan kind='food',
--       chua co loai con — xem Q21). Cac dong khac chi can >= 1 anh/phieu
--       (kiem o receiving_post).
--   D6. spec o get_task = mo ta dong PO neu co, khong thi ten nhom hang.
--   D7. PIN kiem bang _verify_pin (bcrypt extensions.crypt; "chua dat PIN" va
--       "sai PIN" deu tra ERR_PIN_INVALID, khong lo thong tin).
--   D8. receiving_post chi nguoi nhan da mo phieu (receiver_id = auth.uid())
--       duoc post; SoD kiem nguoi tao/duyet PO va nguoi giu tam ung cho.
--   D9. Direct issue: receipt vao kho nhan roi cap issue_out/issue_in sang
--       kho bep cung business_date (theo 05 §3). QC conditional khong direct
--       issue (vao quarantine).
--  D10. supplier_return_post chi cho hang da nhan (khong ap cho dong QC fail
--       — dong do chua vao kho). ap_ledger (-) khi da co hoa don thuoc T-040
--       (invoices chua co nen bo qua, da ghi chu trong RPC).
--  D11. receiving_reverse chi gm (quyen receiving.reverse); dao moi move cua
--       phieu theo thu tu nguoc; chan khi da co supplier_returns posted.
--  D12. Khong tao alert moi cho nhan hang (catalog chua co ma alert nhan hang;
--       SOD_EXCEPTION_USED van tao qua _sod_check).
--  D13. get_receipt/list_receipts: unit_cost/total_amount chi tra khi caller
--       co po.view_price (mu gia voi nguoi nhan); nguoi nhan chi xem duoc
--       phieu nhap cua chinh minh, khong xem phieu da post (ca RLS lan RPC).
--  D14. client_uuid: idempotency cho receiving_start + receiving_record_line.
--  D15. qc_templates: bang moi theo A4 (org_id, item_group_id, checklist jsonb);
--       chua seed mau nao — admin cau hinh sau; get_task tra null khi chua co.
--       Kem 2 RPC admin quan ly template (admin.settings.manage).
--  D16. lot: track_lot bat buoc lot_no + expiry_date (ERR_LOT_REQUIRED);
--       expiry < 50% shelf_life -> short_shelf_life_warning trong response
--       record_line (khong chan).
--  D17. doc_no phieu nhan: next_doc_no(le, 'GRN', today); phieu tra: 'SRT'.
--  D18. goods_receipt_lines co them property_id (denormalized tu phieu) de FK
--       lot (property_id, item_id, lot_no) va posted_warehouse_id ve warehouses.
--  D19. received_qty_stock tren purchase_order_lines la so da POST (khong
--       tinh dong nhap). receiving_post cap accepted ve so con mo tai luc post.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Bang
-- ---------------------------------------------------------------------------

create table public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  po_id uuid,
  supplier_id uuid,
  warehouse_id uuid not null,
  direct_issue_warehouse_id uuid,
  doc_no text not null,
  receiver_id uuid not null references auth.users(id),
  received_at timestamptz not null default now(),
  device_time timestamptz not null default now(),
  captured_offline boolean not null default false,
  client_uuid uuid unique,
  status text not null default 'draft'
    check (status in ('draft', 'needs_recount', 'posted', 'reversed')),
  total_amount numeric(18,2) not null default 0
    check (total_amount >= 0),
  reversed_by uuid references auth.users(id),
  reversed_at timestamptz,
  reverse_reason text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (legal_entity_id, doc_no),
  unique (id, org_id),
  unique (id, property_id),
  foreign key (po_id, org_id) references public.purchase_orders(id, org_id),
  foreign key (supplier_id, org_id) references public.suppliers(id, org_id),
  foreign key (warehouse_id, property_id)
    references public.warehouses(id, property_id),
  foreign key (direct_issue_warehouse_id, property_id)
    references public.warehouses(id, property_id),
  check (direct_issue_warehouse_id is null
    or direct_issue_warehouse_id <> warehouse_id)
);

comment on table public.goods_receipts is 'T-023: phieu nhan hang (mu) — 1 phieu nhan cho 1 PO';
comment on column public.goods_receipts.client_uuid is 'T-023: idempotency key cho receiving_start (offline queue T-025)';

create table public.goods_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  gr_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.properties(id),
  po_line_id uuid,
  item_id uuid not null,
  gross_qty numeric(18,4) not null check (gross_qty > 0),
  tare_qty numeric(18,4) not null default 0 check (tare_qty >= 0),
  net_qty numeric(18,4) generated always as (gross_qty - tare_qty) stored,
  uom text not null references public.uoms(code),
  net_qty_stock numeric(18,4) not null check (net_qty_stock > 0),
  unit_cost numeric(18,4) check (unit_cost is null or unit_cost >= 0),
  accepted_qty_stock numeric(18,4) not null default 0
    check (accepted_qty_stock >= 0),
  over_po_qty_stock numeric(18,4) not null default 0
    check (over_po_qty_stock >= 0),
  override_by uuid references auth.users(id),
  override_reason text,
  qc_status text not null
    check (qc_status in ('pass', 'fail', 'conditional')),
  qc_checklist jsonb not null default '{}'::jsonb,
  temperature_c numeric(6,2),
  lot_no text,
  expiry_date date,
  lot_id uuid,
  weigh_count integer not null default 1 check (weigh_count in (1, 2)),
  weigh1_gross_qty numeric(18,4),
  weigh1_tare_qty numeric(18,4),
  weigh2_gross_qty numeric(18,4),
  weigh2_tare_qty numeric(18,4),
  needs_reweigh boolean not null default false,
  photo_ids uuid[] not null default '{}',
  posted_warehouse_id uuid,
  client_uuid uuid unique,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (id, property_id),
  unique (gr_id, po_line_id),
  foreign key (gr_id, org_id)
    references public.goods_receipts(id, org_id) on delete cascade,
  foreign key (po_line_id, org_id)
    references public.purchase_order_lines(id, org_id),
  foreign key (item_id, org_id)
    references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id),
  foreign key (posted_warehouse_id, property_id)
    references public.warehouses(id, property_id),
  check (net_qty > 0),
  check (weigh_count = 1
    or (weigh2_gross_qty is not null and weigh2_tare_qty is not null))
);

comment on table public.goods_receipt_lines is 'T-023: dong phieu nhan hang — luu ca hai lan can';
comment on column public.goods_receipt_lines.net_qty is 'T-023: net = gross - tare (generated)';

create table public.supplier_returns (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  gr_id uuid,
  po_id uuid,
  supplier_id uuid,
  doc_no text not null,
  status text not null default 'recorded'
    check (status in ('recorded', 'posted', 'cancelled')),
  reason text,
  supplier_signature_path text,
  photo_ids uuid[] not null default '{}',
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (legal_entity_id, doc_no),
  unique (id, org_id),
  unique (id, property_id),
  foreign key (gr_id, org_id)
    references public.goods_receipts(id, org_id),
  foreign key (po_id, org_id)
    references public.purchase_orders(id, org_id),
  foreign key (supplier_id, org_id)
    references public.suppliers(id, org_id)
);

comment on table public.supplier_returns is 'T-023: phieu tra NCC (QC fail sinh tu dong; tra hang da nhan qua supplier_return_post)';

create table public.supplier_return_lines (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  gr_line_id uuid,
  item_id uuid not null,
  qty_stock numeric(18,4) not null check (qty_stock > 0),
  unit_cost numeric(18,4) not null check (unit_cost >= 0),
  reason text,
  photo_ids uuid[] not null default '{}',
  supplier_signature_path text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (return_id, org_id)
    references public.supplier_returns(id, org_id) on delete cascade,
  foreign key (gr_line_id, org_id)
    references public.goods_receipt_lines(id, org_id),
  foreign key (item_id, org_id)
    references public.items(id, org_id)
);

comment on table public.supplier_return_lines is 'T-023: dong phieu tra NCC — unit_cost = gia dong nhan goc (theo don vi ton kho)';

create table public.qc_templates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  item_group_id uuid not null,
  checklist jsonb not null default '[]'::jsonb
    check (jsonb_typeof(checklist) = 'array'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, item_group_id),
  foreign key (item_group_id, org_id)
    references public.item_groups(id, org_id)
);

comment on table public.qc_templates is 'T-023: mau checklist QC theo nhom hang (admin cau hinh)';

create index goods_receipts_po_idx on public.goods_receipts (po_id);
create index goods_receipts_property_status_idx
  on public.goods_receipts (property_id, status);
create index goods_receipt_lines_gr_idx on public.goods_receipt_lines (gr_id);
create index goods_receipt_lines_item_idx
  on public.goods_receipt_lines (item_id);
create index supplier_returns_gr_idx on public.supplier_returns (gr_id);
create index supplier_returns_property_status_idx
  on public.supplier_returns (property_id, status);
create index supplier_return_lines_return_idx
  on public.supplier_return_lines (return_id);
create index supplier_return_lines_gr_line_idx
  on public.supplier_return_lines (gr_line_id);
create index qc_templates_group_idx on public.qc_templates (item_group_id);

-- ---------------------------------------------------------------------------
-- 2. RLS — mu o tang du lieu (AGENTS.md quy tac 9)
--    Nguoi nhan (chi co receiving.perform) chi SELECT duoc phieu NHAP cua
--    chinh minh; phieu da post/reversed khong doc duoc. Nguoi co receiving.view
--    hoac receiving.review_photos moi xem duoc phieu da post. So luong PO, don
--    gia, ton ly thuyet khong bao gio lo qua RLS: policy tren
--    purchase_order_lines da chan receiver (xem 20261109210000:286).
-- ---------------------------------------------------------------------------

alter table public.goods_receipts enable row level security;
alter table public.goods_receipt_lines enable row level security;
alter table public.supplier_returns enable row level security;
alter table public.supplier_return_lines enable row level security;
alter table public.qc_templates enable row level security;

create policy goods_receipts_select on public.goods_receipts
for select using (
  property_id = any (public.my_property_ids())
  and (
    public.has_perm(property_id, 'receiving.view')
    or public.has_perm(property_id, 'receiving.review_photos')
    or (
      status = 'draft'
      and receiver_id = auth.uid()
      and public.has_perm(property_id, 'receiving.perform')
    )
  )
);

create policy goods_receipt_lines_select on public.goods_receipt_lines
for select using (
  exists (
    select 1 from public.goods_receipts gr
    where gr.id = goods_receipt_lines.gr_id
    and gr.property_id = any (public.my_property_ids())
    and (
      public.has_perm(gr.property_id, 'receiving.view')
      or public.has_perm(gr.property_id, 'receiving.review_photos')
      or (
        gr.status = 'draft'
        and gr.receiver_id = auth.uid()
        and public.has_perm(gr.property_id, 'receiving.perform')
      )
    )
  )
);

create policy supplier_returns_select on public.supplier_returns
for select using (
  property_id = any (public.my_property_ids())
  and (
    public.has_perm(property_id, 'receiving.view')
    or public.has_perm(property_id, 'receiving.review_photos')
    or public.has_perm(property_id, 'supplier_return.post')
  )
);

create policy supplier_return_lines_select on public.supplier_return_lines
for select using (
  exists (
    select 1 from public.supplier_returns sr
    where sr.id = supplier_return_lines.return_id
    and sr.property_id = any (public.my_property_ids())
    and (
      public.has_perm(sr.property_id, 'receiving.view')
      or public.has_perm(sr.property_id, 'receiving.review_photos')
      or public.has_perm(sr.property_id, 'supplier_return.post')
    )
  )
);

create policy qc_templates_select on public.qc_templates
for select using (
  exists (
    select 1 from public.properties p
    where p.org_id = qc_templates.org_id
    and p.id = any (public.my_property_ids())
    and (
      public.has_perm(p.id, 'receiving.perform')
      or public.has_perm(p.id, 'receiving.view')
    )
  )
);

-- ---------------------------------------------------------------------------
-- 3. Trigger: audit + updated_at + write guard (chi RPC duoc viet, qua co
--    'app.receiving_guard_bypass' — cung mau _pr_po_write_guard o T-020)
-- ---------------------------------------------------------------------------

create or replace function public._receiving_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.receiving_guard_bypass', true), '') <> 'on' then
    raise exception using errcode = 'P0001',
      message = format('ERR_WRITE_GUARD: %s chi duoc ghi qua RPC', TG_TABLE_NAME);
  end if;
  return coalesce(new, old);
end;
$$;

create trigger goods_receipts_write_guard
before insert or update or delete on public.goods_receipts
for each row execute function public._receiving_write_guard();

create trigger goods_receipt_lines_write_guard
before insert or update or delete on public.goods_receipt_lines
for each row execute function public._receiving_write_guard();

create trigger supplier_returns_write_guard
before insert or update or delete on public.supplier_returns
for each row execute function public._receiving_write_guard();

create trigger supplier_return_lines_write_guard
before insert or update or delete on public.supplier_return_lines
for each row execute function public._receiving_write_guard();

create trigger qc_templates_write_guard
before insert or update or delete on public.qc_templates
for each row execute function public._receiving_write_guard();

create trigger goods_receipts_updated_at
before update on public.goods_receipts
for each row execute function public.set_updated_at();

create trigger goods_receipt_lines_updated_at
before update on public.goods_receipt_lines
for each row execute function public.set_updated_at();

create trigger supplier_returns_updated_at
before update on public.supplier_returns
for each row execute function public.set_updated_at();

create trigger supplier_return_lines_updated_at
before update on public.supplier_return_lines
for each row execute function public.set_updated_at();

create trigger qc_templates_updated_at
before update on public.qc_templates
for each row execute function public.set_updated_at();

create trigger goods_receipts_audit
after insert or update or delete on public.goods_receipts
for each row execute function public.audit_trigger();

create trigger goods_receipt_lines_audit
after insert or update or delete on public.goods_receipt_lines
for each row execute function public.audit_trigger();

create trigger supplier_returns_audit
after insert or update or delete on public.supplier_returns
for each row execute function public.audit_trigger();

create trigger supplier_return_lines_audit
after insert or update or delete on public.supplier_return_lines
for each row execute function public.audit_trigger();

create trigger qc_templates_audit
after insert or update or delete on public.qc_templates
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 4. Helper
-- ---------------------------------------------------------------------------

-- Dung sai nhan hang (%) — setting receiving_tolerance_pct, mac dinh 5.
create or replace function public._receiving_tolerance_pct(
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
  v_raw := public._setting_get(p_org_id, p_property_id, 'receiving_tolerance_pct');
  return coalesce((v_raw #>> '{}')::numeric, 5);
exception when others then
  return 5;
end;
$$;

-- Xac minh PIN nhan vien (bcrypt, extensions.crypt). "Chua dat PIN" va "sai
-- PIN" deu tra ERR_PIN_INVALID de khong lo thong tin. PIN kiem o luc post
-- thuoc T-023 (xem chu thich o 20261109000001).
create or replace function public._verify_pin(p_pin text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_hash text;
begin
  select p.pin_hash into v_hash
  from public.profiles p
  where p.id = auth.uid();

  if v_hash is null or p_pin is null or p_pin = '' then
    raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
  end if;

  if v_hash <> crypt(p_pin, v_hash) then
    raise exception using errcode = 'P0001', message = 'ERR_PIN_INVALID';
  end if;
end;
$$;

-- Don gia theo don vi ton kho: don gia PO (theo don vi mua) / he so quy doi.
create or replace function public._receiving_unit_cost_stock(
  p_org_id uuid,
  p_item_id uuid,
  p_uom text,
  p_unit_price numeric
)
returns numeric
language plpgsql
stable
as $$
declare
  v_stock_uom text;
  v_factor numeric;
begin
  select i.stock_uom into v_stock_uom
  from public.items i
  where i.id = p_item_id and i.org_id = p_org_id;

  if v_stock_uom is null then
    raise exception using errcode = 'P0001', message = 'ERR_ITEM_NOT_FOUND';
  end if;

  if p_uom = v_stock_uom then
    return p_unit_price;
  end if;

  select ipu.factor_to_stock into v_factor
  from public.item_purchase_units ipu
  where ipu.item_id = p_item_id and ipu.org_id = p_org_id and ipu.uom = p_uom;

  if v_factor is null or v_factor <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_UOM_UNKNOWN';
  end if;

  return round(p_unit_price / v_factor, 4);
end;
$$;

-- Anh bat buoc theo dong: hang then chot hoac nhom thuc pham (kind = 'food').
create or replace function public._receiving_photo_required(
  p_org_id uuid,
  p_item_id uuid
)
returns boolean
language plpgsql
stable
as $$
declare
  v_required boolean;
begin
  select (i.is_key_item or ig.kind = 'food')
  into v_required
  from public.items i
  join public.item_groups ig on ig.id = i.group_id and ig.org_id = i.org_id
  where i.id = p_item_id and i.org_id = p_org_id;

  return coalesce(v_required, false);
end;
$$;

-- PO co du dieu kien nhan hang khong (D1, Q20).
create or replace function public._receiving_po_eligible(
  p_channel text,
  p_status text
)
returns boolean
language sql
immutable
as $$
  select case
    when p_channel = 'market' then p_status in ('approved', 'sent', 'partially_received')
    else p_status in ('sent', 'partially_received')
  end;
$$;

-- Cap nhat trang thai PO sau khi nhan/tra/dao.
create or replace function public._receiving_update_po_status(
  p_po_id uuid
)
returns void
language plpgsql
as $$
declare
  v_status text;
  v_any_received boolean;
  v_all_received boolean;
begin
  select po.status into v_status
  from public.purchase_orders po
  where po.id = p_po_id;

  -- Khong doi trang thai PO nhap / cho duyet / da huy. PO market o 'approved'
  -- VAN nhan truc tiep (D1/Q20) nen khong loai 'approved' o day.
  if v_status is null or v_status in ('draft', 'pending_approval', 'cancelled') then
    return;
  end if;

  select
    coalesce(bool_or(pol.received_qty_stock > 0), false),
    coalesce(bool_and(pol.received_qty_stock >= pol.qty_stock), false)
  into v_any_received, v_all_received
  from public.purchase_order_lines pol
  where pol.po_id = p_po_id and pol.item_id is not null;

  if v_all_received then
    update public.purchase_orders
    set status = 'received', updated_at = now()
    where id = p_po_id;
  elsif v_any_received then
    update public.purchase_orders
    set status = 'partially_received', updated_at = now()
    where id = p_po_id;
  else
    update public.purchase_orders
    set status = case
      when (select po2.channel from public.purchase_orders po2 where po2.id = p_po_id) = 'market'
        then 'approved'
      else 'sent'
    end,
    updated_at = now()
    where id = p_po_id;
  end if;
end;
$$;

-- Kho cach ly cua khach san.
create or replace function public._receiving_quarantine_wh(
  p_property_id uuid
)
returns uuid
language plpgsql
stable
as $$
declare
  v_wh uuid;
begin
  select w.id into v_wh
  from public.warehouses w
  where w.property_id = p_property_id and w.kind = 'quarantine'
  limit 1;

  if v_wh is null then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;

  return v_wh;
end;
$$;

-- So luong da tra (phieu tra da post) cho mot dong phieu nhan.
create or replace function public._receiving_returned_qty(
  p_gr_line_id uuid
)
returns numeric
language plpgsql
stable
as $$
declare
  v_qty numeric;
begin
  select coalesce(sum(srl.qty_stock), 0) into v_qty
  from public.supplier_return_lines srl
  join public.supplier_returns sr
    on sr.id = srl.return_id
  where srl.gr_line_id = p_gr_line_id
    and sr.status = 'posted';

  return v_qty;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. RPC — danh sach nhiem vu / nhan hang mu
-- ---------------------------------------------------------------------------

-- Danh sach PO den han nhan trong ngay (khong tra so luong, don gia).
create or replace function public.receiving_list_tasks(
  p_property_id uuid,
  p_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_date date := coalesce(
    p_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_rows jsonb;
begin
  select p.org_id into v_org_id
  from public.properties p
  where p.id = p_property_id;

  if v_org_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(p_property_id, 'receiving.perform');

  select coalesce(jsonb_agg(t), '[]'::jsonb) into v_rows
  from (
    select
      po.id as po_id,
      po.doc_no,
      coalesce(s.name, 'Mua chợ') as supplier_name,
      po.channel,
      po.expected_date,
      count(pol.id)::int as line_count
    from public.purchase_orders po
    left join public.suppliers s
      on s.id = po.supplier_id and s.org_id = po.org_id
    join public.purchase_order_lines pol
      on pol.po_id = po.id and pol.org_id = po.org_id
    where po.property_id = p_property_id
      and po.expected_date <= v_date
      and public._receiving_po_eligible(po.channel, po.status)
      and pol.item_id is not null
      and pol.received_qty_stock < pol.qty_stock
    group by po.id, po.doc_no, s.name, po.channel, po.expected_date
    order by po.expected_date, po.doc_no
  ) t;

  return jsonb_build_object('ok', true, 'tasks', v_rows);
end;
$$;

-- Chi tiet 1 PO de nhan: chi tra ten hang / dac ta / mau QC / can anh —
-- KHONG tra so luong PO, don gia (mu o tang du lieu).
create or replace function public.receiving_get_task(
  p_po_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_po record;
  v_rows jsonb;
  v_supplier text;
begin
  select po.* into v_po
  from public.purchase_orders po
  where po.id = p_po_id;

  if v_po.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_po.property_id, 'receiving.perform');

  if not public._receiving_po_eligible(v_po.channel, v_po.status) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select s.name into v_supplier
  from public.suppliers s
  where s.id = v_po.supplier_id and s.org_id = v_po.org_id;

  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_rows
  from (
    select
      pol.id as po_line_id,
      pol.item_id,
      i.name as item_name,
      coalesce(nullif(pol.description, ''), ig.name) as spec,
      qt.checklist as qc_template,
      public._receiving_photo_required(v_po.org_id, pol.item_id)
        as photo_required,
      pol.uom,
      i.track_lot,
      i.shelf_life_days
    from public.purchase_order_lines pol
    join public.items i
      on i.id = pol.item_id and i.org_id = pol.org_id
    left join public.item_groups ig
      on ig.id = i.group_id and ig.org_id = i.org_id
    left join public.qc_templates qt
      on qt.org_id = pol.org_id and qt.item_group_id = i.group_id
    where pol.po_id = p_po_id
      and pol.item_id is not null
      and pol.received_qty_stock < pol.qty_stock
    order by pol.created_at
  ) l;

  return jsonb_build_object(
    'ok', true,
    'po_id', v_po.id,
    'doc_no', v_po.doc_no,
    'supplier_name', coalesce(v_supplier, 'Mua chợ'),
    'channel', v_po.channel,
    'lines', v_rows
  );
end;
$$;

-- Mo phieu nhan nhap cho 1 PO. Idempotent theo client_uuid.
create or replace function public.receiving_start(
  p_po_id uuid,
  p_warehouse_id uuid,
  p_direct_issue_wh uuid default null,
  p_client_uuid uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_po record;
  v_wh record;
  v_wh_direct record;
  v_gr record;
  v_gr_id uuid;
  v_doc_no text;
begin
  select po.* into v_po
  from public.purchase_orders po
  where po.id = p_po_id;

  if v_po.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_po.property_id, 'receiving.perform');

  if not public._receiving_po_eligible(v_po.channel, v_po.status) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_client_uuid is not null then
    select gr.* into v_gr
    from public.goods_receipts gr
    where gr.client_uuid = p_client_uuid
      and gr.po_id = p_po_id
      and gr.org_id = v_po.org_id
      and gr.status = 'draft';

    if found then
      return jsonb_build_object('ok', true, 'id', v_gr.id, 'doc_no', v_gr.doc_no);
    end if;
  end if;

  select w.* into v_wh
  from public.warehouses w
  where w.id = p_warehouse_id;

  if v_wh.id is null or v_wh.property_id <> v_po.property_id
    or v_wh.kind not in ('main', 'outlet', 'floor') then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;

  if p_direct_issue_wh is not null then
    select w.* into v_wh_direct
    from public.warehouses w
    where w.id = p_direct_issue_wh;

    if v_wh_direct.id is null
      or v_wh_direct.property_id <> v_po.property_id
      or v_wh_direct.kind not in ('main', 'outlet', 'floor') then
      raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
    end if;
  end if;

  v_doc_no := public.next_doc_no(
    v_po.legal_entity_id, 'GRN',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date);

  perform set_config('app.receiving_guard_bypass', 'on', true);

  insert into public.goods_receipts (
    org_id, legal_entity_id, property_id, po_id, supplier_id,
    warehouse_id, direct_issue_warehouse_id, doc_no, receiver_id,
    received_at, device_time, client_uuid, status
  ) values (
    v_po.org_id, v_po.legal_entity_id, v_po.property_id, v_po.id, v_po.supplier_id,
    p_warehouse_id, p_direct_issue_wh, v_doc_no, auth.uid(),
    now(), now(), p_client_uuid, 'draft'
  ) returning id into v_gr_id;

  return jsonb_build_object('ok', true, 'id', v_gr_id, 'doc_no', v_doc_no);
end;
$$;

-- Ghi 1 dong nhan hang. Goi lan 2 cung (gr, po_line) = can lai (ghi de,
-- luu ca hai lan can). Response KHONG tra so luong PO / don gia.
-- p_qc: {"status": "pass"|"fail"|"conditional", "checklist": [...],
--        "temperature_c": n, "reason": "...", "supplier_signature_path": "..."}
create or replace function public.receiving_record_line(
  p_gr_id uuid,
  p_po_line_id uuid,
  p_item_id uuid,
  p_gross numeric,
  p_tare numeric default 0,
  p_uom text default null,
  p_qc jsonb default '{}'::jsonb,
  p_lot text default null,
  p_expiry date default null,
  p_photo_ids uuid[] default null,
  p_client_uuid uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_pol record;
  v_item record;
  v_line record;
  v_uom text;
  v_net numeric;
  v_net_stock numeric;
  v_remaining numeric;
  v_cap numeric;
  v_tol numeric;
  v_dev numeric;
  v_qc_status text;
  v_photo_required boolean;
  v_unit_cost numeric;
  v_short_warning boolean := false;
  v_accepted numeric;
  v_over_po numeric;
  v_needs_reweigh boolean;
  v_is_reweigh boolean := false;
  v_line_id uuid;
  v_ret_id uuid;
  v_ret_no text;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.perform');

  if v_gr.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if v_gr.receiver_id <> auth.uid() then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.perform';
  end if;

  -- Idempotency (offline queue T-025): tra lai dong da ghi.
  if p_client_uuid is not null then
    select grl.* into v_line
    from public.goods_receipt_lines grl
    where grl.client_uuid = p_client_uuid and grl.gr_id = p_gr_id;

    if found then
      return jsonb_build_object(
        'ok', true,
        'id', v_line.id,
        'weigh_count', v_line.weigh_count,
        'needs_reweigh', v_line.needs_reweigh,
        'accepted_qty_stock_capped', v_line.accepted_qty_stock,
        'short_shelf_life_warning', false
      );
    end if;
  end if;

  select pol.* into v_pol
  from public.purchase_order_lines pol
  where pol.id = p_po_line_id and pol.po_id = v_gr.po_id;

  if v_pol.id is null or v_pol.item_id is null or v_pol.item_id <> p_item_id then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select i.* into v_item
  from public.items i
  where i.id = p_item_id and i.org_id = v_gr.org_id;

  if v_item.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_ITEM_NOT_FOUND';
  end if;

  v_uom := coalesce(p_uom, v_pol.uom);

  if p_gross is null or p_gross <= 0 or p_tare is null or p_tare < 0
    or p_gross <= p_tare then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_net := p_gross - p_tare;
  v_net_stock := public._po_line_qty_stock(v_gr.org_id, p_item_id, v_uom, v_net);

  v_qc_status := coalesce(p_qc ->> 'status', 'pass');
  if v_qc_status not in ('pass', 'fail', 'conditional') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- Hang theo lot: bat buoc so lot + han su dung.
  if v_item.track_lot and (p_lot is null or p_lot = '' or p_expiry is null) then
    raise exception using errcode = 'P0001', message = 'ERR_LOT_REQUIRED';
  end if;

  -- Anh bat buoc theo dong (hang then chot / nhom thuc pham).
  v_photo_required := public._receiving_photo_required(v_gr.org_id, p_item_id);
  if v_photo_required and coalesce(cardinality(p_photo_ids), 0) = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_PHOTO_REQUIRED';
  end if;

  -- Anh phai la attachment doc_type = 'receiving', doc_id = phieu nay
  -- (line_id khong cap nhat duoc — trigger T-016 chan UPDATE attachments).
  if coalesce(cardinality(p_photo_ids), 0) > 0 then
    if exists (
      select 1 from public.attachments a
      where a.id = any (p_photo_ids)
        and (a.doc_type <> 'receiving' or a.doc_id <> p_gr_id)
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;

    if (select count(*) from public.attachments a
        where a.id = any (p_photo_ids)) <> cardinality(p_photo_ids) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
  end if;

  -- Canh bao han su dung ngan: expiry < 50% shelf_life ke tu hom nay.
  if v_item.track_lot and v_item.shelf_life_days is not null
    and p_expiry is not null then
    if p_expiry < current_date + floor(v_item.shelf_life_days * 0.5)::int then
      v_short_warning := true;
    end if;
  end if;

  v_tol := public._receiving_tolerance_pct(v_gr.org_id, v_gr.property_id);
  -- Don gia PO dinh gia theo UOM cua dong PO (pol.uom), khong phai UOM ghi
  -- nhan (v_uom) — quy doi sai o day se lech gia von theo he so don vi.
  v_unit_cost := public._receiving_unit_cost_stock(
    v_gr.org_id, p_item_id, v_pol.uom, v_pol.unit_price);

  -- So con mo tai luc nhan (chi tinh so da POST).
  v_remaining := v_pol.qty_stock - v_pol.received_qty_stock;
  if v_remaining <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  v_cap := v_remaining * (1 + v_tol / 100);
  v_dev := abs(v_net_stock - v_remaining) / v_remaining * 100;

  -- Dong da ton tai -> can lai (lan 2). QC fail la chung ket cua dong:
  -- muon nhan lai phai mo phieu moi (phieu tra 'recorded' da sinh).
  select grl.* into v_line
  from public.goods_receipt_lines grl
  where grl.gr_id = p_gr_id and grl.po_line_id = p_po_line_id;

  if found then
    if v_line.weigh_count >= 2 then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    if v_line.qc_status = 'fail' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    v_is_reweigh := true;
  end if;

  -- Quy tac chap nhan (D3):
  --  can 1 lech ngoai dung sai -> needs_reweigh, chua nhan (accepted = 0);
  --  can 2 lech ngoai dung sai -> nhan so thuc, cap o tran; phan du ghi
  --  over_po (can override moi nhan du); lech trong dung sai -> nhan du.
  if v_qc_status = 'fail' then
    v_needs_reweigh := false;
    v_accepted := 0;
    v_over_po := 0;
  elsif v_dev <= v_tol then
    v_needs_reweigh := false;
    v_accepted := least(v_net_stock, v_cap);
    v_over_po := 0;
  elsif not v_is_reweigh then
    v_needs_reweigh := true;
    v_accepted := 0;
    v_over_po := 0;
  else
    v_needs_reweigh := true;
    v_accepted := least(v_net_stock, v_cap);
    v_over_po := greatest(v_net_stock - v_cap, 0);
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  if not v_is_reweigh then
    insert into public.goods_receipt_lines (
      gr_id, org_id, property_id, po_line_id, item_id,
      gross_qty, tare_qty, uom, net_qty_stock, unit_cost,
      accepted_qty_stock, over_po_qty_stock,
      qc_status, qc_checklist, temperature_c,
      lot_no, expiry_date,
      weigh_count, weigh1_gross_qty, weigh1_tare_qty,
      needs_reweigh, photo_ids, client_uuid
    ) values (
      p_gr_id, v_gr.org_id, v_gr.property_id, p_po_line_id, p_item_id,
      p_gross, p_tare, v_uom, v_net_stock, v_unit_cost,
      v_accepted, v_over_po,
      v_qc_status, coalesce(p_qc -> 'checklist', '{}'::jsonb),
      (p_qc ->> 'temperature_c')::numeric,
      p_lot, p_expiry,
      1, p_gross, p_tare,
      v_needs_reweigh, coalesce(p_photo_ids, '{}'),
      p_client_uuid
    ) returning id into v_line_id;
  else
    update public.goods_receipt_lines
    set gross_qty = p_gross,
        tare_qty = p_tare,
        uom = v_uom,
        net_qty_stock = v_net_stock,
        unit_cost = v_unit_cost,
        accepted_qty_stock = v_accepted,
        over_po_qty_stock = v_over_po,
        override_by = null,
        override_reason = null,
        qc_status = v_qc_status,
        qc_checklist = coalesce(p_qc -> 'checklist', '{}'::jsonb),
        temperature_c = (p_qc ->> 'temperature_c')::numeric,
        lot_no = p_lot,
        expiry_date = p_expiry,
        weigh_count = 2,
        weigh2_gross_qty = p_gross,
        weigh2_tare_qty = p_tare,
        needs_reweigh = v_needs_reweigh,
        photo_ids = coalesce(p_photo_ids, '{}'),
        client_uuid = coalesce(p_client_uuid, client_uuid),
        updated_at = now()
    where id = v_line.id
    returning id into v_line_id;
  end if;

  -- QC fail: sinh phieu tra NCC 'recorded' ngay (khong move kho).
  if v_qc_status = 'fail' then
    v_ret_no := public.next_doc_no(
      v_gr.legal_entity_id, 'SRT',
      (now() at time zone 'Asia/Ho_Chi_Minh')::date);

    insert into public.supplier_returns (
      org_id, legal_entity_id, property_id, gr_id, po_id, supplier_id,
      doc_no, status, reason,
      supplier_signature_path, photo_ids
    ) values (
      v_gr.org_id, v_gr.legal_entity_id, v_gr.property_id,
      p_gr_id, v_gr.po_id, v_gr.supplier_id,
      v_ret_no, 'recorded', p_qc ->> 'reason',
      p_qc ->> 'supplier_signature_path', coalesce(p_photo_ids, '{}')
    ) returning id into v_ret_id;

    insert into public.supplier_return_lines (
      return_id, org_id, gr_line_id, item_id, qty_stock, unit_cost,
      reason, photo_ids, supplier_signature_path
    ) values (
      v_ret_id, v_gr.org_id, v_line_id, p_item_id, v_net_stock, v_unit_cost,
      p_qc ->> 'reason', coalesce(p_photo_ids, '{}'),
      p_qc ->> 'supplier_signature_path'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_line_id,
    'weigh_count', case when v_is_reweigh then 2 else 1 end,
    'needs_reweigh', v_needs_reweigh,
    'accepted_qty_stock_capped', v_accepted,
    'short_shelf_life_warning', v_short_warning
  );
end;
$$;

-- Duyet nhan vuot tran cho 1 dong (storekeeper/gm, ly do bat buoc).
-- Dat accepted = toan bo net, xoa over_po; luc post khong cap dong nay.
create or replace function public.receiving_override_line(
  p_gr_line_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_line record;
  v_gr record;
begin
  select grl.* into v_line
  from public.goods_receipt_lines grl
  where grl.id = p_gr_line_id;

  if v_line.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = v_line.gr_id;

  perform public.require_perm(v_gr.property_id, 'receiving.override_over_po');

  if v_gr.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  if v_line.over_po_qty_stock <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  update public.goods_receipt_lines
  set accepted_qty_stock = net_qty_stock,
      over_po_qty_stock = 0,
      override_by = auth.uid(),
      override_reason = p_reason,
      needs_reweigh = false,
      updated_at = now()
  where id = p_gr_line_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_gr_line_id,
    'accepted_qty_stock', v_line.net_qty_stock
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. RPC — post phieu nhan (cham ton kho + tien)
-- ---------------------------------------------------------------------------

-- Post phieu nhan: kiem PIN + SoD, move receipt (QC conditional -> kho cach
-- ly; direct issue -> receipt + issue_out + issue_in), cap so nhan ve so
-- con mo tai luc post. Response KHONG tra total_amount (mu gia voi nguoi nhan).
create or replace function public.receiving_post(
  p_gr_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_po record;
  v_line record;
  v_pol record;
  v_item record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_tol numeric;
  v_remaining numeric;
  v_cap numeric;
  v_accepted numeric;
  v_unit_cost numeric;
  v_lot_id uuid;
  v_lot_expiry date;
  v_target_wh uuid;
  v_final_wh uuid;
  v_move_id bigint;
  v_out_cost numeric;
  v_total numeric := 0;
  v_posted_lines int := 0;
  v_att_count int;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.post');

  if v_gr.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Chi nguoi nhan da mo phieu moi duoc post phieu do.
  if v_gr.receiver_id <> auth.uid() then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.post';
  end if;

  -- PIN kiem truoc khi cham den ton kho.
  perform public._verify_pin(p_pin);

  -- SoD: nguoi tao/duyet PO khong duoc nhan; nguoi giu tam ung cho khong
  -- duoc nhan PO cho do. _sod_check chi raise khi khong co ngoai le hop le.
  select po.* into v_po
  from public.purchase_orders po
  where po.id = v_gr.po_id;

  if v_po.created_by = auth.uid() then
    perform public._sod_check(v_gr.property_id, 'SOD_PO_RECEIVER');
  end if;

  if exists (
    select 1 from public.approvals a
    where a.doc_type = 'po' and a.doc_id = v_gr.po_id
      and a.decision = 'approved' and a.decided_by = auth.uid()
  ) then
    perform public._sod_check(v_gr.property_id, 'SOD_PO_RECEIVER');
  end if;

  if v_po.advance_id is not null and exists (
    select 1 from public.advances ad
    where ad.id = v_po.advance_id and ad.employee_id = auth.uid()
  ) then
    perform public._sod_check(v_gr.property_id, 'SOD_MARKET_BUYER_RECEIVER');
  end if;

  -- Chan post khi con dong chua can lai xong (can 1 lech, chua can lan 2).
  if exists (
    select 1 from public.goods_receipt_lines grl
    where grl.gr_id = p_gr_id
      and grl.needs_reweigh
      and grl.weigh_count = 1
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Moi phieu phai co it nhat 1 anh (05 §3: "Anh chup phieu (bat buoc)").
  select count(*) into v_att_count
  from public.attachments a
  where a.doc_type = 'receiving' and a.doc_id = p_gr_id;

  if v_att_count = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_PHOTO_REQUIRED';
  end if;

  v_tol := public._receiving_tolerance_pct(v_gr.org_id, v_gr.property_id);

  perform set_config('app.receiving_guard_bypass', 'on', true);

  for v_line in
    select * from public.goods_receipt_lines
    where gr_id = p_gr_id
    order by created_at
  loop
    -- Dong QC fail: khong vao kho (phieu tra 'recorded' da sinh luc ghi).
    if v_line.qc_status = 'fail' then
      continue;
    end if;

    select pol.* into v_pol
    from public.purchase_order_lines pol
    where pol.id = v_line.po_line_id
    for update;

    if v_pol.id is null then
      continue;
    end if;

    v_remaining := v_pol.qty_stock - v_pol.received_qty_stock;
    v_cap := v_remaining * (1 + v_tol / 100);

    -- Cap ve so con mo tai luc post; dong co override thi khong cap.
    if v_line.override_by is not null then
      v_accepted := v_line.accepted_qty_stock;
    else
      v_accepted := least(v_line.accepted_qty_stock, greatest(v_cap, 0));
    end if;

    if v_accepted <= 0 then
      continue;
    end if;

    select i.* into v_item
    from public.items i
    where i.id = v_line.item_id and i.org_id = v_gr.org_id;

    -- Don gia theo UOM cua dong PO (xem chu thich o receiving_record_line).
    v_unit_cost := public._receiving_unit_cost_stock(
      v_gr.org_id, v_line.item_id, v_pol.uom, v_pol.unit_price);

    -- Lot: tim hoac tao (hang theo lot).
    v_lot_id := null;
    if v_item.track_lot then
      if v_line.lot_no is null or v_line.expiry_date is null then
        raise exception using errcode = 'P0001', message = 'ERR_LOT_REQUIRED';
      end if;

      insert into public.lots (org_id, property_id, item_id, lot_no, expiry_date)
      values (v_gr.org_id, v_gr.property_id, v_line.item_id,
        v_line.lot_no, v_line.expiry_date)
      on conflict (property_id, item_id, lot_no) do nothing
      returning id into v_lot_id;

      if v_lot_id is null then
        select l.id, l.expiry_date into v_lot_id, v_lot_expiry
        from public.lots l
        where l.property_id = v_gr.property_id
          and l.item_id = v_line.item_id
          and l.lot_no = v_line.lot_no;

        if v_lot_expiry is distinct from v_line.expiry_date then
          raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
        end if;
      end if;
    end if;

    -- Kho dich: QC conditional -> kho cach ly; binh thuong -> kho nhan.
    if v_line.qc_status = 'conditional' then
      v_target_wh := public._receiving_quarantine_wh(v_gr.property_id);
    else
      v_target_wh := v_gr.warehouse_id;
    end if;

    v_move_id := public._post_move(
      v_gr.legal_entity_id, v_gr.property_id, v_target_wh,
      v_line.item_id, v_lot_id, 'receipt', v_accepted, v_unit_cost,
      v_today, 'goods_receipt', p_gr_id, v_line.id);

    v_final_wh := v_target_wh;

    -- Nhan thang ra bep (chi dong pass): receipt + issue_out + issue_in.
    if v_gr.direct_issue_warehouse_id is not null
      and v_line.qc_status = 'pass' then
      v_move_id := public._post_move(
        v_gr.legal_entity_id, v_gr.property_id, v_target_wh,
        v_line.item_id, v_lot_id, 'issue_out', -v_accepted, null,
        v_today, 'goods_receipt', p_gr_id, v_line.id);

      select sm.unit_cost into v_out_cost
      from public.stock_moves sm
      where sm.id = v_move_id;

      perform public._post_move(
        v_gr.legal_entity_id, v_gr.property_id,
        v_gr.direct_issue_warehouse_id,
        v_line.item_id, v_lot_id, 'issue_in', v_accepted, v_out_cost,
        v_today, 'goods_receipt', p_gr_id, v_line.id);

      v_final_wh := v_gr.direct_issue_warehouse_id;
    end if;

    update public.goods_receipt_lines
    set accepted_qty_stock = v_accepted,
        unit_cost = v_unit_cost,
        lot_id = v_lot_id,
        posted_warehouse_id = v_final_wh,
        updated_at = now()
    where id = v_line.id;

    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock + v_accepted,
        updated_at = now()
    where id = v_pol.id;

    v_total := v_total + round(v_accepted * v_unit_cost, 2);
    v_posted_lines := v_posted_lines + 1;
  end loop;

  if v_posted_lines = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  update public.goods_receipts
  set status = 'posted',
      total_amount = round(v_total, 2),
      received_at = now(),
      updated_at = now()
  where id = p_gr_id;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object(
    'ok', true,
    'id', p_gr_id,
    'lines_posted', v_posted_lines
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. RPC — xem phieu nhan (mu gia)
-- ---------------------------------------------------------------------------

-- Chi tiet 1 phieu nhan. unit_cost/total_amount chi tra khi caller co
-- po.view_price; nguoi nhan chi xem duoc phieu nhap cua chinh minh.
create or replace function public.receiving_get_receipt(
  p_gr_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_can_price boolean;
  v_lines jsonb;
  v_supplier text;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_gr.status = 'draft'
    and v_gr.receiver_id = auth.uid()
    and public.has_perm(v_gr.property_id, 'receiving.perform') then
    -- Nguoi nhan xem phieu nhap cua chinh minh.
    v_can_price := public.has_perm(v_gr.property_id, 'po.view_price');
  elsif public.has_perm(v_gr.property_id, 'receiving.view')
    or public.has_perm(v_gr.property_id, 'receiving.review_photos') then
    v_can_price := public.has_perm(v_gr.property_id, 'po.view_price');
  else
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.view';
  end if;

  select s.name into v_supplier
  from public.suppliers s
  where s.id = v_gr.supplier_id and s.org_id = v_gr.org_id;

  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_lines
  from (
    select
      grl.id,
      grl.po_line_id,
      grl.item_id,
      i.name as item_name,
      grl.gross_qty,
      grl.tare_qty,
      grl.net_qty,
      grl.net_qty_stock,
      grl.uom,
      grl.accepted_qty_stock,
      grl.over_po_qty_stock,
      grl.qc_status,
      grl.temperature_c,
      grl.lot_no,
      grl.expiry_date,
      grl.weigh_count,
      grl.needs_reweigh,
      grl.photo_ids,
      case when v_can_price then grl.unit_cost else null end as unit_cost,
      case when v_can_price
        then round(grl.accepted_qty_stock * grl.unit_cost, 2)
        else null end as line_amount
    from public.goods_receipt_lines grl
    join public.items i
      on i.id = grl.item_id and i.org_id = grl.org_id
    where grl.gr_id = p_gr_id
    order by grl.created_at
  ) l;

  return jsonb_build_object(
    'ok', true,
    'id', v_gr.id,
    'doc_no', v_gr.doc_no,
    'po_id', v_gr.po_id,
    'supplier_name', coalesce(v_supplier, 'Mua chợ'),
    'warehouse_id', v_gr.warehouse_id,
    'direct_issue_warehouse_id', v_gr.direct_issue_warehouse_id,
    'status', v_gr.status,
    'receiver_id', v_gr.receiver_id,
    'received_at', v_gr.received_at,
    'total_amount', case when v_can_price then v_gr.total_amount else null end,
    'reverse_reason', v_gr.reverse_reason,
    'lines', v_lines
  );
end;
$$;

-- Danh sach phieu nhan (chi header, khong tra total_amount).
create or replace function public.receiving_list_receipts(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows jsonb;
  v_total int;
begin
  if not (
    public.has_perm(p_property_id, 'receiving.view')
    or public.has_perm(p_property_id, 'receiving.review_photos')
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.view';
  end if;

  select count(*) into v_total
  from public.goods_receipts gr
  where gr.property_id = p_property_id
    and (p_status is null or gr.status = p_status)
    and (p_search is null or gr.doc_no ilike '%' || p_search || '%');

  select coalesce(jsonb_agg(r), '[]'::jsonb) into v_rows
  from (
    select
      gr.id,
      gr.doc_no,
      gr.po_id,
      po.doc_no as po_doc_no,
      coalesce(s.name, 'Mua chợ') as supplier_name,
      gr.status,
      gr.receiver_id,
      gr.received_at,
      (select count(*)::int from public.goods_receipt_lines grl
        where grl.gr_id = gr.id) as line_count
    from public.goods_receipts gr
    left join public.purchase_orders po
      on po.id = gr.po_id
    left join public.suppliers s
      on s.id = gr.supplier_id and s.org_id = gr.org_id
    where gr.property_id = p_property_id
      and (p_status is null or gr.status = p_status)
      and (p_search is null or gr.doc_no ilike '%' || p_search || '%')
    order by gr.received_at desc, gr.created_at desc
    limit greatest(p_limit, 1)
    offset greatest(p_offset, 0)
  ) r;

  return jsonb_build_object('ok', true, 'receipts', v_rows, 'total', v_total);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. RPC — tra NCC + dao phieu
-- ---------------------------------------------------------------------------

-- Tra hang da nhan ve NCC: return_out theo gia dong nhan goc, giam so da
-- nhan tren PO. p_lines: [{"gr_line_id", "qty_stock", "reason"?,
-- "photo_ids"?: [uuid], "supplier_signature_path"?}].
-- GHI CHU: ap_ledger (-) khi da co hoa don thuoc T-040 (invoices chua co
-- nen chua ghi — phieu tra posted o day chi dao kho + so da nhan).
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
  end loop;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object('ok', true, 'id', v_ret_id, 'doc_no', v_ret_no);
end;
$$;

-- Dao phieu nhan da post: dao moi move cua phieu theo thu tu nguoc,
-- tra lai so da nhan tren PO. Chan khi da co phieu tra posted.
create or replace function public.receiving_reverse(
  p_gr_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_move record;
  v_line record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.reverse');

  if v_gr.status = 'reversed' then
    raise exception using errcode = 'P0001', message = 'ERR_ALREADY_REVERSED';
  end if;

  if v_gr.status <> 'posted' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  if exists (
    select 1 from public.supplier_returns sr
    where sr.gr_id = p_gr_id and sr.status = 'posted'
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  for v_move in
    select * from public.stock_moves sm
    where sm.doc_type = 'goods_receipt' and sm.doc_id = p_gr_id
    order by sm.id desc
  loop
    perform public._post_move(
      v_move.legal_entity_id, v_move.property_id, v_move.warehouse_id,
      v_move.item_id, v_move.lot_id, 'reversal', -v_move.qty, null,
      v_today, 'goods_receipt', p_gr_id, v_move.line_id,
      null, null, null, v_move.id);
  end loop;

  for v_line in
    select * from public.goods_receipt_lines
    where gr_id = p_gr_id
      and accepted_qty_stock > 0
      and posted_warehouse_id is not null
  loop
    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock - v_line.accepted_qty_stock,
        updated_at = now()
    where id = v_line.po_line_id;
  end loop;

  update public.goods_receipts
  set status = 'reversed',
      reversed_by = auth.uid(),
      reversed_at = now(),
      reverse_reason = p_reason,
      updated_at = now()
  where id = p_gr_id;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object('ok', true, 'id', p_gr_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. RPC — quan ly mau checklist QC (admin)
-- ---------------------------------------------------------------------------

create or replace function public.admin_qc_template_save(
  p_org_id uuid,
  p_item_group_id uuid,
  p_checklist jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group record;
  v_property_id uuid;
  v_template_id uuid;
begin
  select ig.* into v_group
  from public.item_groups ig
  where ig.id = p_item_group_id and ig.org_id = p_org_id;

  if v_group.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  -- Quyen cau hinh: kiem tren 1 property bat ky cua org ma caller co quyen.
  select p.id into v_property_id
  from public.properties p
  where p.org_id = p_org_id
    and p.id = any (public.my_property_ids())
  order by p.code
  limit 1;

  if v_property_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:admin.settings.manage';
  end if;

  perform public.require_perm(v_property_id, 'admin.settings.manage');

  if p_checklist is null or jsonb_typeof(p_checklist) <> 'array' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  insert into public.qc_templates (org_id, item_group_id, checklist)
  values (p_org_id, p_item_group_id, p_checklist)
  on conflict (org_id, item_group_id)
  do update set checklist = excluded.checklist, updated_at = now()
  returning id into v_template_id;

  return jsonb_build_object('ok', true, 'id', v_template_id);
end;
$$;

create or replace function public.admin_qc_template_delete(
  p_template_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template record;
  v_property_id uuid;
begin
  select qt.* into v_template
  from public.qc_templates qt
  where qt.id = p_template_id;

  if v_template.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select p.id into v_property_id
  from public.properties p
  where p.org_id = v_template.org_id
    and p.id = any (public.my_property_ids())
  order by p.code
  limit 1;

  if v_property_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:admin.settings.manage';
  end if;

  perform public.require_perm(v_property_id, 'admin.settings.manage');

  perform set_config('app.receiving_guard_bypass', 'on', true);

  delete from public.qc_templates where id = p_template_id;

  return jsonb_build_object('ok', true, 'id', p_template_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Gan quyen moi cho vai tro mau (cac ma receiving.* da co trong danh muc
--     tu 20261108141000; owner da co du cac ma nay qua seed — chi gan them
--     2 ma chua co vai tro nao giu: override_over_po va reverse).
--     Join theo ma vai tro, giong mau seed.sql.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('storekeeper', 'receiving.override_over_po'),
  ('gm', 'receiving.override_over_po'),
  ('gm', 'receiving.reverse')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109230000_receiving',
  'INSERT',
  jsonb_build_object('event', 'receiving_created', 'task', 'T-023'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
