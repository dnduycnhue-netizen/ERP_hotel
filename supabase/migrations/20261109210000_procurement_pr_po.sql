-- 20261109210000_procurement_pr_po.sql
--
-- T-020: Migration 06 thu mua + RPC PR/PO/duyet (approval_rules sinh buoc).
-- AC: PO 30 trieu co du 3 buoc; nguoi tao khong duyet duoc (SoD).
--
-- Can cu: docs/03-DATA-MODEL.md A3 (purchase_requests/_lines,
-- purchase_orders/_lines, approval_rules, approvals) + A1
-- (approval_delegations), docs/05-BUSINESS-RULES.md §2 (gia tu dong:
-- hop dong -> bao gia -> gia tran; vuot tran can ly do + them buoc gm;
-- ma tran duyet mac dinh), docs/09-API-RPC.md §2 (pr_save_draft,
-- pr_submit/pr_decide, po_create_from_pr, po_save_draft, po_submit,
-- approval_decide, po_send, po_close) + §11 (ERR_OVER_CEILING_NO_REASON,
-- ERR_SOD_<RULE>), docs/04-SECURITY-RLS.md (SOD_PO_CREATOR_APPROVER),
-- docs/modules/M03-procurement.md (luong co PO; sua PO sau approved
-- phai cancel + tao moi, giu replaces_po_id; uy quyen duyet khi vang).
--
-- Quyet dinh khi dac ta im lang / mo (ghi ro de Duy chot lai neu sai):
--  1. Sinh buoc duyet theo kieu LUY TIEN (cumulative): po_submit lay
--     moi rule co min_amount <= tong PO (khong loc theo max_amount).
--     Voi ma tran mac dinh (outlet_head 0, cost_controller 5tr, gm 20tr,
--     owner 100tr), PO 30tr sinh dung 3 buoc: outlet_head (buoc 1) +
--     cost_controller (buoc 2) + gm (buoc 3) — khop AC. max_amount chi
--     dung de hien thi khoang (band) o man hinh cau hinh, khong dung
--     de loc buoc. Neu loc theo band thi PO 30tr chi co 1 buoc (gm),
--     trai AC.
--  2. Buoc outlet_head cua PO duoc TU DONG DUYET khi PO tao tu (cac) PR
--     da duoc truong outlet duyet: PR duyet la buoc outlet_head cua
--     chuoi ("< 5 trieu | outlet_head (PR) -> tu dong duyet PO neu
--     khong vuot tran", 05-BUSINESS-RULES.md §2). Nguoi duyet ghi
--     nhan la nguoi duyet PR gan nhat. PO < 5tr khong vuot tran vi the
--     duoc duyet ngay khi submit (chi co 1 buoc, da tu dong duyet).
--     PO tao truc tiep khong qua PR (po_save_draft) thi buoc nay van
--     cho duyet tay.
--  3. Vuot tran HOAC gia tay (manual) deu them 1 buoc gm bo sung o
--     cuoi chuoi (khong them 2 buoc neu ca 2 dieu kien cung xay ra;
--     buoc bo sung dung required_perm 'po.approve.over_ceiling' khi
--     co vuot tran, 'po.approve' khi chi co gia tay). Ly do: 2 buoc gm
--     lien tiep khong them thong tin kiem soat, chi them ma sat.
--  4. Thay the cost_controller bang accountant khi property co
--     sod_profile = 'without_cc' (05-BUSINESS-RULES.md §2: "+ cost
--     _controller (hoac accountant neu without_cc)"). Neu org khong
--     co vai tro accountant thi giu nguyen cost_controller.
--  5. Khong co bang bao gia (quotes) trong 03-DATA-MODEL.md nen
--     po_create_from_pr chi giai quyet gia theo: hop dong khung con
--     hieu luc -> gia tran -> manual (gia 0, thu mua nhap tay o ban
--     nhap). price_source 'quote' van giu trong enum de dung sau khi
--     co bang bao gia; RPC hien tai khong bao gio sinh ra no.
--  6. po_create_from_pr chuyen TOAN BO so luong con lai cua moi dong
--     PR duoc chon (khong ho tro chuyen mot phan — chu ky RPC khong
--     co tham so so luong). converted_qty theo doi tren dong PR de
--     chan chuyen trung.
--  7. po_send dung quyen 'po.create' (khong co ma 'po.send' trong
--     danh muc quyen); po_close dung 'po.close' (ma da seed san
--     nhung chua gan vai tro mau nao — migration nay gan cho
--     purchaser + owner).
--  8. Quy tac SoD cho PR khong co trong 04-SECURITY-RLS.md (chi co
--     SOD_PO_CREATOR_APPROVER). Ap dung cung nguyen tac: nguoi tao PR
--     khong duyet PR do, ma SOD_PR_CREATOR_APPROVER (tuong thich
--     _sod_check + bang sod_exceptions).
--  9. Uy quyen duyet (approval_delegations): nguoi duoc uy quyen
--     chi duyet duoc buoc cua nguoi uy quyen khi uy quyen con han
--     va cung pham vi (property_id null = toan chuoi). Them 2 RPC
--     quan tri admin_approval_delegation_save/delete (quyen
--     admin.approval_rules.manage) vi 09-API-RPC.md khong dinh
--     nghia RPC quan ly uy quyen — neu khong co thi bang chi doc
--     duoc, khong tao duoc uy quyen.
-- 10. Cau hoi Q13 (gop ma: "chuyen moi tham chieu nhap sang ma
--     dich"): tu T-020, trigger tren items tu dong chuyen cac dong
--     PR/PO DANG NHAP (draft) sang ma dich khi ma tam bi gop. Dong
--     cua chung tu da submit tro di khong doi (chung tu da dong
--     bang). Hop dong khung / gia tran khong doi (rang buoc hop
--     dong, theo quyet dinh T-015).
-- 11. advance_id tren purchase_orders de trong (uuid, chua FK):
--     bang advances thuoc T-022. po_cancel chi cho tu
--     draft/submitted/approved (PO da sent thi dung po_close).
-- 12. Khong them ma quyen moi: pr.create/pr.approve/po.create/
--     po.view/po.view_qty/po.view_price/po.approve/
--     po.approve.over_ceiling/po.close da co trong danh muc
--     (20261108141000) va owner da co du tren production (xac minh
--     09/11: owner 109 quyen, seed da chua san cac ma nay — xem
--     ghi chu Q17 da sua trong OPEN-QUESTIONS.md).

-- ---------------------------------------------------------------------------
-- 1. Bang thu mua (03-DATA-MODEL.md A3) + approvals + delegations.
-- ---------------------------------------------------------------------------
create table public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  outlet_id uuid,
  doc_no text not null,
  kind text not null default 'stock' check (kind in ('stock', 'service')),
  need_date date,
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'approved', 'rejected', 'converted', 'cancelled')),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (legal_entity_id, doc_no),
  unique (id, org_id),
  unique (id, property_id),
  foreign key (outlet_id, property_id) references public.outlets(id, property_id)
);

create table public.purchase_request_lines (
  id uuid primary key default gen_random_uuid(),
  pr_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid,
  description text,
  qty numeric(18,4) not null check (qty > 0),
  uom text not null references public.uoms(code),
  expense_category_id uuid references public.expense_categories(id),
  cost_center_id uuid references public.cost_centers(id),
  reason text,
  converted_qty numeric(18,4) not null default 0
    check (converted_qty >= 0 and converted_qty <= qty),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (pr_id, org_id) references public.purchase_requests(id, org_id) on delete cascade,
  foreign key (item_id, org_id) references public.items(id, org_id),
  check (item_id is not null or (description is not null and btrim(description) <> ''))
);

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  supplier_id uuid not null,
  channel text not null check (channel in ('contract', 'quote', 'market')),
  kind text not null default 'stock' check (kind in ('stock', 'service')),
  order_date date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  expected_date date,
  advance_id uuid,
  total_amount numeric(18,2) not null default 0 check (total_amount >= 0),
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'approved', 'rejected', 'sent', 'partially_received', 'received', 'closed', 'cancelled')),
  over_ceiling_reason text,
  replaces_po_id uuid references public.purchase_orders(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  doc_no text not null,
  unique (legal_entity_id, doc_no),
  unique (id, org_id),
  unique (id, property_id),
  foreign key (supplier_id, org_id) references public.suppliers(id, org_id)
);

create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  po_id uuid not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  pr_line_id uuid,
  item_id uuid,
  description text,
  qty numeric(18,4) not null check (qty > 0),
  uom text not null references public.uoms(code),
  qty_stock numeric(18,4) check (qty_stock is null or qty_stock > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  price_source text not null check (price_source in ('agreement', 'quote', 'ceiling', 'manual')),
  ceiling_price numeric(18,4) check (ceiling_price is null or ceiling_price >= 0),
  over_ceiling boolean not null default false,
  received_qty_stock numeric(18,4) not null default 0 check (received_qty_stock >= 0),
  expense_category_id uuid references public.expense_categories(id),
  cost_center_id uuid references public.cost_centers(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (po_id, org_id) references public.purchase_orders(id, org_id) on delete cascade,
  foreign key (pr_line_id, org_id) references public.purchase_request_lines(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  check (item_id is not null or (description is not null and btrim(description) <> ''))
);

create table public.approvals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.properties(id),
  doc_type text not null check (doc_type ~ '^[a-z][a-z0-9_]{1,39}$'),
  doc_id uuid not null,
  step integer not null check (step > 0),
  approver_role_id uuid,
  approver_user_id uuid references auth.users(id),
  required_perm text not null default 'po.approve' references public.permissions(code),
  decision text not null default 'pending' check (decision in ('pending', 'approved', 'rejected')),
  comment text,
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  delegated_from uuid references auth.users(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (approver_role_id, org_id) references public.roles(id, org_id),
  check ((approver_role_id is null) <> (approver_user_id is null)),
  unique (id, org_id),
  unique (doc_type, doc_id, step)
);

create index approvals_doc_idx on public.approvals (doc_type, doc_id, step);

create table public.approval_delegations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  from_user uuid not null references auth.users(id),
  to_user uuid not null references auth.users(id),
  property_id uuid references public.properties(id),
  valid_from date not null,
  valid_to date not null,
  reason text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  check (from_user <> to_user),
  check (valid_to >= valid_from)
);

create index approval_delegations_from_idx on public.approval_delegations (from_user, valid_from, valid_to);
create index approval_delegations_to_idx on public.approval_delegations (to_user, valid_from, valid_to);

-- ---------------------------------------------------------------------------
-- 2. RLS: chi SELECT qua policy (ghi chi qua RPC SECURITY DEFINER).
--    has_perm(property, perm) da bao ca vai tro toan chuoi
--    (user_property_roles.property_id null).
-- ---------------------------------------------------------------------------
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'purchase_requests', 'purchase_request_lines',
    'purchase_orders', 'purchase_order_lines',
    'approvals', 'approval_delegations'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
    execute format('grant select on table public.%I to authenticated', v_table);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', 'trg_' || v_table || '_updated_at', v_table);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_trigger()', 'trg_' || v_table || '_audit', v_table);
  end loop;
end $$;

create policy purchase_requests_select on public.purchase_requests
  for select to authenticated
  using (
    property_id in (select public.my_property_ids())
    and (
      public.has_perm(property_id, 'pr.create')
      or public.has_perm(property_id, 'pr.approve')
      or public.has_perm(property_id, 'po.create')
      or public.has_perm(property_id, 'po.view')
    )
  );

create policy purchase_request_lines_select on public.purchase_request_lines
  for select to authenticated
  using (
    exists (
      select 1 from public.purchase_requests pr
      where pr.id = pr_id
        and pr.property_id in (select public.my_property_ids())
        and (
          public.has_perm(pr.property_id, 'pr.create')
          or public.has_perm(pr.property_id, 'pr.approve')
          or public.has_perm(pr.property_id, 'po.create')
          or public.has_perm(pr.property_id, 'po.view')
        )
    )
  );

create policy purchase_orders_select on public.purchase_orders
  for select to authenticated
  using (
    property_id in (select public.my_property_ids())
    and (
      public.has_perm(property_id, 'po.view')
      or public.has_perm(property_id, 'po.create')
      or public.has_perm(property_id, 'po.approve')
      or public.has_perm(property_id, 'po.close')
    )
  );

create policy purchase_order_lines_select on public.purchase_order_lines
  for select to authenticated
  using (
    exists (
      select 1 from public.purchase_orders po
      where po.id = po_id
        and po.property_id in (select public.my_property_ids())
        and (
          public.has_perm(po.property_id, 'po.view')
          or public.has_perm(po.property_id, 'po.create')
          or public.has_perm(po.property_id, 'po.approve')
          or public.has_perm(po.property_id, 'po.close')
        )
    )
  );

create policy approvals_select on public.approvals
  for select to authenticated
  using (
    (
      doc_type = 'pr'
      and exists (
        select 1 from public.purchase_requests pr
        where pr.id = doc_id
          and pr.property_id in (select public.my_property_ids())
          and (
            public.has_perm(pr.property_id, 'pr.create')
            or public.has_perm(pr.property_id, 'pr.approve')
            or public.has_perm(pr.property_id, 'po.create')
            or public.has_perm(pr.property_id, 'po.view')
          )
      )
    )
    or (
      doc_type = 'po'
      and exists (
        select 1 from public.purchase_orders po
        where po.id = doc_id
          and po.property_id in (select public.my_property_ids())
          and (
            public.has_perm(po.property_id, 'po.view')
            or public.has_perm(po.property_id, 'po.create')
            or public.has_perm(po.property_id, 'po.approve')
            or public.has_perm(po.property_id, 'po.close')
          )
      )
    )
  );

create policy approval_delegations_select on public.approval_delegations
  for select to authenticated
  using (
    from_user = auth.uid()
    or to_user = auth.uid()
    or public.has_perm(property_id, 'admin.approval_rules.manage')
    or (property_id is null and public.has_perm(null, 'admin.approval_rules.manage'))
  );

-- ---------------------------------------------------------------------------
-- 3. Guard: trang thai PR/PO chi doi trong RPC (co bypass transaction-local
--    `app.pr_po_guard_bypass`, mau T-013). Dong chung tu va buoc duyet chi
--    ghi qua RPC.
-- ---------------------------------------------------------------------------
create or replace function public._pr_po_status_guard()
returns trigger
language plpgsql
as $$
begin
  if (
    old.status is distinct from new.status
    or old.created_by is distinct from new.created_by
  ) and coalesce(
    current_setting('app.pr_po_guard_bypass', true), ''
  ) <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return new;
end;
$$;

revoke all on function public._pr_po_status_guard()
  from public, anon, authenticated;

drop trigger if exists trg_purchase_requests_status_guard on public.purchase_requests;
create trigger trg_purchase_requests_status_guard
before update on public.purchase_requests
for each row execute function public._pr_po_status_guard();

drop trigger if exists trg_purchase_orders_status_guard on public.purchase_orders;
create trigger trg_purchase_orders_status_guard
before update on public.purchase_orders
for each row execute function public._pr_po_status_guard();

create or replace function public._pr_po_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.pr_po_guard_bypass', true), '') <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public._pr_po_write_guard()
  from public, anon, authenticated;

drop trigger if exists trg_purchase_request_lines_write_guard on public.purchase_request_lines;
create trigger trg_purchase_request_lines_write_guard
before insert or update or delete on public.purchase_request_lines
for each row execute function public._pr_po_write_guard();

drop trigger if exists trg_purchase_order_lines_write_guard on public.purchase_order_lines;
create trigger trg_purchase_order_lines_write_guard
before insert or update or delete on public.purchase_order_lines
for each row execute function public._pr_po_write_guard();

drop trigger if exists trg_approvals_write_guard on public.approvals;
create trigger trg_approvals_write_guard
before insert or update or delete on public.approvals
for each row execute function public._pr_po_write_guard();

-- Tong PO tu dong tinh lai tu dong (sau moi thay doi dong).
create or replace function public._po_recalc_total()
returns trigger
language plpgsql
as $$
begin
  update public.purchase_orders po
  set total_amount = coalesce((
    select sum(pol.qty * pol.unit_price)
    from public.purchase_order_lines pol
    where pol.po_id = coalesce(new.po_id, old.po_id)
  ), 0)
  where po.id = coalesce(new.po_id, old.po_id);
  return coalesce(new, old);
end;
$$;

revoke all on function public._po_recalc_total()
  from public, anon, authenticated;

drop trigger if exists trg_purchase_order_lines_recalc on public.purchase_order_lines;
create trigger trg_purchase_order_lines_recalc
after insert or update or delete on public.purchase_order_lines
for each row execute function public._po_recalc_total();

-- Q13 (mot phan): khi ma tam bi gop (items.status -> 'merged'), cac dong
-- PR/PO DANG NHAP tu dong chuyen sang ma dich. Dong cua chung tu da
-- submit tro di khong doi; hop dong khung / gia tran khong doi.
create or replace function public._repoint_merged_item_refs()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'merged'
    and old.status is distinct from new.status
    and new.merged_into_id is not null
  then
    perform set_config('app.pr_po_guard_bypass', 'on', true);
    update public.purchase_request_lines prl
    set item_id = new.merged_into_id
    from public.purchase_requests pr
    where prl.pr_id = pr.id
      and prl.item_id = old.id
      and pr.status = 'draft';
    update public.purchase_order_lines pol
    set item_id = new.merged_into_id
    from public.purchase_orders po
    where pol.po_id = po.id
      and pol.item_id = old.id
      and po.status = 'draft';
  end if;
  return new;
end;
$$;

revoke all on function public._repoint_merged_item_refs()
  from public, anon, authenticated;

drop trigger if exists trg_items_repoint_merged_refs on public.items;
create trigger trg_items_repoint_merged_refs
after update of status on public.items
for each row execute function public._repoint_merged_item_refs();

-- ---------------------------------------------------------------------------
-- 4. Ham phu noi bo.
-- ---------------------------------------------------------------------------

-- Giai quyet gia cho 1 dong PO theo thu tu: hop dong khung con hieu luc
-- -> gia tran -> manual (gia 0, thu mua nhap tay o ban nhap).
-- Quyet dinh 5: khong co bang bao gia trong 03-DATA-MODEL.md nen khong
-- giai quyet 'quote' o day.
create or replace function public._po_resolve_line_price(
  p_org_id uuid,
  p_property_id uuid,
  p_supplier_id uuid,
  p_item_id uuid,
  p_uom text,
  p_date date
)
returns table (
  unit_price numeric(18,4),
  price_source text,
  ceiling_price numeric(18,4),
  over_ceiling boolean
)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_agreement_price numeric(18,4);
  v_ceiling numeric(18,4);
begin
  if p_item_id is not null then
    select pal.unit_price into v_agreement_price
    from public.price_agreement_lines pal
    join public.price_agreements pa
      on pa.id = pal.agreement_id and pa.org_id = pal.org_id
    where pa.org_id = p_org_id
      and pa.supplier_id = p_supplier_id
      and pa.status = 'active'
      and pa.valid_from <= p_date and p_date <= pa.valid_to
      and pal.item_id = p_item_id
      and pal.uom = p_uom
    order by pa.valid_from desc
    limit 1;

    v_ceiling := public.current_ceiling_price(
      p_org_id, p_property_id, p_item_id, p_uom, p_date
    );

    if v_agreement_price is not null then
      return query select
        v_agreement_price,
        'agreement'::text,
        v_ceiling,
        (v_ceiling is not null and v_agreement_price > v_ceiling);
      return;
    end if;

    if v_ceiling is not null then
      return query select v_ceiling, 'ceiling'::text, v_ceiling, false;
      return;
    end if;
  end if;

  return query select 0::numeric(18,4), 'manual'::text, v_ceiling, false;
end;
$$;

revoke all on function public._po_resolve_line_price(uuid, uuid, uuid, uuid, text, date)
  from public, anon, authenticated;

-- Quy doi so luong mua ve don vi kho (factor_to_stock). Dong dich vu
-- khong co item -> null.
create or replace function public._po_line_qty_stock(
  p_org_id uuid,
  p_item_id uuid,
  p_uom text,
  p_qty numeric(18,4)
)
returns numeric(18,4)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_stock_uom text;
  v_factor numeric(18,4);
begin
  if p_item_id is null then
    return null;
  end if;

  select i.stock_uom into v_stock_uom
  from public.items i
  where i.id = p_item_id and i.org_id = p_org_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if v_stock_uom = p_uom then
    return p_qty;
  end if;

  select pu.factor_to_stock into v_factor
  from public.item_purchase_units pu
  where pu.org_id = p_org_id
    and pu.item_id = p_item_id
    and pu.uom = p_uom
  limit 1;
  if v_factor is null then
    raise exception 'ERR_UOM_UNKNOWN';
  end if;

  return p_qty * v_factor;
end;
$$;

revoke all on function public._po_line_qty_stock(uuid, uuid, text, numeric)
  from public, anon, authenticated;

-- Sinh cac buoc duyet cho 1 chung tu tu approval_rules (quyet dinh 1:
-- luy tien theo min_amount; max_amount chi de hien thi band).
-- Xoa buoc cu cua chung tu roi sinh lai (dung khi submit lai sau reject).
-- Tra ve so buoc da sinh. Tu dong duyet buoc outlet_head cua PO khi PO
-- tao tu (cac) PR da duoc truong outlet duyet (quyet dinh 2).
create or replace function public._generate_approval_steps(
  p_doc_type text,
  p_doc_id uuid,
  p_property_id uuid,
  p_org_id uuid,
  p_total_amount numeric(18,2)
)
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_sod_profile text;
  v_accountant_role_id uuid;
  v_group_ids uuid[];
  v_over_ceiling boolean := false;
  v_manual boolean := false;
  v_pr_ids uuid[];
  v_pr_approver uuid;
  v_steps integer;
begin
  delete from public.approvals
  where doc_type = p_doc_type and doc_id = p_doc_id;

  select p.sod_profile into v_sod_profile
  from public.properties p where p.id = p_property_id;

  select r.id into v_accountant_role_id
  from public.roles r
  where r.org_id = p_org_id and r.code = 'accountant';

  if p_doc_type = 'pr' then
    select coalesce(array_agg(distinct i.group_id), '{}'::uuid[])
      into v_group_ids
    from public.purchase_request_lines prl
    join public.items i on i.id = prl.item_id
    where prl.pr_id = p_doc_id;
  elsif p_doc_type = 'po' then
    select coalesce(array_agg(distinct i.group_id), '{}'::uuid[])
      into v_group_ids
    from public.purchase_order_lines pol
    join public.items i on i.id = pol.item_id
    where pol.po_id = p_doc_id;
    select exists (
      select 1 from public.purchase_order_lines pol
      where pol.po_id = p_doc_id and pol.over_ceiling
    ) into v_over_ceiling;
    select exists (
      select 1 from public.purchase_order_lines pol
      where pol.po_id = p_doc_id and pol.price_source = 'manual'
    ) into v_manual;
  end if;

  insert into public.approvals (
    org_id, property_id, doc_type, doc_id, step,
    approver_role_id, approver_user_id, required_perm,
    decision, comment, decided_by, decided_at
  )
  select distinct on (r.step)
    p_org_id,
    p_property_id,
    p_doc_type,
    p_doc_id,
    r.step,
    case
      when rc.code = 'cost_controller' and v_sod_profile = 'without_cc'
        and v_accountant_role_id is not null
      then v_accountant_role_id
      else r.approver_role_id
    end,
    r.approver_user_id,
    r.required_perm,
    'pending',
    null,
    null,
    null
  from public.approval_rules r
  left join public.roles rc on rc.id = r.approver_role_id
  where r.org_id = p_org_id
    and (r.property_id is null or r.property_id = p_property_id)
    and r.doc_type = p_doc_type
    and r.min_amount <= p_total_amount
    and (r.item_group_id is null or r.item_group_id = any(v_group_ids))
    and (
      (r.condition - 'over_ceiling' - 'manual_price') = '{}'::jsonb
      and (not (r.condition ? 'over_ceiling')
        or (r.condition ->> 'over_ceiling')::boolean = v_over_ceiling)
      and (not (r.condition ? 'manual_price')
        or (r.condition ->> 'manual_price')::boolean = v_manual)
    )
  order by r.step, (r.property_id is not null) desc;

  -- Buoc gm bo sung khi vuot tran hoac gia tay (quyet dinh 3): 1 buoc
  -- duy nhat, dung quyen over_ceiling khi co vuot tran.
  if p_doc_type = 'po' and (v_over_ceiling or v_manual) then
    insert into public.approvals (
      org_id, property_id, doc_type, doc_id, step,
      approver_role_id, approver_user_id, required_perm, decision
    )
    select
      p_org_id,
      p_property_id,
      'po',
      p_doc_id,
      coalesce((select max(step) from public.approvals where doc_type = 'po' and doc_id = p_doc_id), 0) + 1,
      r.id,
      null,
      case when v_over_ceiling then 'po.approve.over_ceiling' else 'po.approve' end,
      'pending'
    from public.roles r
    where r.org_id = p_org_id and r.code = 'gm';
  end if;

  -- Tu dong duyet buoc outlet_head cua PO tao tu PR da duyet (quyet dinh 2).
  if p_doc_type = 'po' then
    select array_agg(distinct pr.id) into v_pr_ids
    from public.purchase_order_lines pol
    join public.purchase_request_lines prl on prl.id = pol.pr_line_id
    join public.purchase_requests pr on pr.id = prl.pr_id
    where pol.po_id = p_doc_id;

    if v_pr_ids is not null and array_length(v_pr_ids, 1) > 0
      and not exists (
        select 1 from public.purchase_requests pr
        where pr.id = any(v_pr_ids) and pr.status <> 'approved'
      )
    then
      select a.decided_by into v_pr_approver
      from public.approvals a
      where a.doc_type = 'pr'
        and a.doc_id = any(v_pr_ids)
        and a.decision = 'approved'
      order by a.decided_at desc nulls last
      limit 1;

      if v_pr_approver is not null then
        update public.approvals a
        set decision = 'approved',
            decided_by = v_pr_approver,
            decided_at = now(),
            comment = 'Tự động duyệt: PR đã được trưởng outlet duyệt'
        where a.doc_type = 'po'
          and a.doc_id = p_doc_id
          and a.decision = 'pending'
          and a.approver_role_id in (
            select r.id from public.roles r
            where r.org_id = p_org_id and r.code = 'outlet_head'
          );
      end if;
    end if;
  end if;

  select count(*) into v_steps
  from public.approvals
  where doc_type = p_doc_type and doc_id = p_doc_id;
  return v_steps;
end;
$$;

revoke all on function public._generate_approval_steps(text, uuid, uuid, uuid, numeric)
  from public, anon, authenticated;

-- Nguoi dang dang nhap co duoc quyet buoc duyet nay khong: dung nguoi
-- duoc chi dinh, giu vai tro duoc chi dinh, hoac duoc uy quyen tu mot
-- nguoi nhu vay (uy quyen con han, cung pham vi).
create or replace function public._approval_can_decide(
  p_property_id uuid,
  p_approval_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_step public.approvals%rowtype;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select * into v_step from public.approvals a where a.id = p_approval_id;
  if not found then
    return false;
  end if;

  if v_step.approver_user_id is not null then
    if auth.uid() = v_step.approver_user_id then
      return true;
    end if;
    return exists (
      select 1 from public.approval_delegations d
      where d.org_id = v_step.org_id
        and d.from_user = v_step.approver_user_id
        and d.to_user = auth.uid()
        and (d.property_id is null or d.property_id = p_property_id)
        and v_today between d.valid_from and d.valid_to
    );
  end if;

  if exists (
    select 1
    from public.user_property_roles upr
    join public.roles r on r.id = upr.role_id and r.active
    where upr.user_id = auth.uid()
      and upr.role_id = v_step.approver_role_id
      and (upr.property_id is null or upr.property_id = p_property_id)
      and v_today between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
  ) then
    return true;
  end if;

  return exists (
    select 1
    from public.approval_delegations d
    where d.org_id = v_step.org_id
      and d.to_user = auth.uid()
      and (d.property_id is null or d.property_id = p_property_id)
      and v_today between d.valid_from and d.valid_to
      and exists (
        select 1
        from public.user_property_roles upr
        join public.roles r on r.id = upr.role_id and r.active
        where upr.user_id = d.from_user
          and upr.role_id = v_step.approver_role_id
          and (upr.property_id is null or upr.property_id = p_property_id)
          and v_today between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
      )
  );
end;
$$;

revoke all on function public._approval_can_decide(uuid, uuid)
  from public, anon, authenticated;

-- Logic quyet buoc dung chung cho pr_decide + approval_decide:
-- duyet buoc pending thap nhat, theo thu tu buoc.
create or replace function public._decide_approval(
  p_property_id uuid,
  p_doc_type text,
  p_doc_id uuid,
  p_decision text,
  p_comment text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_doc record;
  v_step public.approvals%rowtype;
  v_sod_code text;
  v_pending integer;
  v_new_status text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if p_doc_type = 'pr' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.purchase_requests where id = p_doc_id;
    v_sod_code := 'SOD_PR_CREATOR_APPROVER';
  elsif p_doc_type = 'po' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.purchase_orders where id = p_doc_id;
    v_sod_code := 'SOD_PO_CREATOR_APPROVER';
  else
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not found or v_doc.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_doc.status <> 'submitted' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_step
  from public.approvals a
  where a.doc_type = p_doc_type
    and a.doc_id = p_doc_id
    and a.decision = 'pending'
  order by a.step asc
  limit 1;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(p_property_id, v_step.required_perm);

  if not public._approval_can_decide(p_property_id, v_step.id) then
    raise exception 'ERR_NOT_APPROVER';
  end if;

  if v_doc.created_by = auth.uid() then
    perform public._sod_check(p_property_id, v_sod_code);
  end if;

  if p_decision = 'rejected'
    and (p_comment is null or btrim(p_comment) = '')
  then
    raise exception 'ERR_REASON_REQUIRED';
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
    v_new_status := 'rejected';
  else
    select count(*) into v_pending
    from public.approvals a
    where a.doc_type = p_doc_type
      and a.doc_id = p_doc_id
      and a.decision = 'pending';
    v_new_status := case when v_pending = 0 then 'approved' else 'submitted' end;
  end if;

  if p_doc_type = 'pr' then
    update public.purchase_requests
    set status = v_new_status where id = p_doc_id;
  else
    update public.purchase_orders
    set status = v_new_status where id = p_doc_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'doc_type', p_doc_type,
    'doc_id', p_doc_id,
    'status', v_new_status,
    'pending_steps', coalesce(v_pending, 0)
  );
end;
$$;

revoke all on function public._decide_approval(uuid, text, uuid, text, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC PR.
-- ---------------------------------------------------------------------------

-- Tao/sua PR nhap. p_pr: {id?, outlet_id?, kind?, need_date?, note?,
-- lines: [{id?, item_id?, description?, qty, uom, expense_category_id?,
-- cost_center_id?, reason?}]}. Chi sua duoc khi draft (hoac rejected ->
-- quay ve draft, xoa buoc duyet cu).
create or replace function public.pr_save_draft(
  p_property_id uuid,
  p_pr jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_pr_id uuid;
  v_pr public.purchase_requests%rowtype;
  v_kind text;
  v_outlet_id uuid;
  v_line jsonb;
  v_line_id uuid;
  v_item_id uuid;
  v_qty numeric(18,4);
  v_uom text;
  v_expense_category_id uuid;
  v_cost_center_id uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'pr.create');

  select p.org_id, p.legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_kind := coalesce(nullif(p_pr ->> 'kind', ''), 'stock');
  if v_kind not in ('stock', 'service') then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_outlet_id := nullif(p_pr ->> 'outlet_id', '')::uuid;
  if v_outlet_id is not null and not exists (
    select 1 from public.outlets o
    where o.id = v_outlet_id and o.property_id = p_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if jsonb_typeof(coalesce(p_pr -> 'lines', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_pr_id := nullif(p_pr ->> 'id', '')::uuid;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  if v_pr_id is null then
    insert into public.purchase_requests (
      org_id, legal_entity_id, property_id, outlet_id, doc_no,
      kind, need_date, status, note, created_by
    )
    values (
      v_org_id, v_legal_entity_id, p_property_id, v_outlet_id,
      public.next_doc_no(v_legal_entity_id, 'PR', v_today),
      v_kind,
      nullif(p_pr ->> 'need_date', '')::date,
      'draft',
      nullif(p_pr ->> 'note', ''),
      auth.uid()
    )
    returning id into v_pr_id;
  else
    select * into v_pr
    from public.purchase_requests pr where pr.id = v_pr_id;
    if not found or v_pr.property_id <> p_property_id then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    if v_pr.status not in ('draft', 'rejected') then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    update public.purchase_requests pr
    set outlet_id = v_outlet_id,
        kind = v_kind,
        need_date = nullif(p_pr ->> 'need_date', '')::date,
        note = nullif(p_pr ->> 'note', ''),
        status = 'draft'
    where pr.id = v_pr_id;

    if v_pr.status = 'rejected' then
      delete from public.approvals
      where doc_type = 'pr' and doc_id = v_pr_id;
    end if;
  end if;

  -- Dong: xoa dong khong con trong payload (tru dong da chuyen sang PO).
  delete from public.purchase_request_lines prl
  where prl.pr_id = v_pr_id
    and prl.converted_qty = 0
    and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_pr -> 'lines', '[]'::jsonb)) l
      where nullif(l ->> 'id', '')::uuid = prl.id
    );
  if exists (
    select 1
    from public.purchase_request_lines prl
    where prl.pr_id = v_pr_id
      and prl.converted_qty > 0
      and not exists (
        select 1
        from jsonb_array_elements(coalesce(p_pr -> 'lines', '[]'::jsonb)) l
        where nullif(l ->> 'id', '')::uuid = prl.id
      )
  ) then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  for v_line in
    select * from jsonb_array_elements(coalesce(p_pr -> 'lines', '[]'::jsonb))
  loop
    v_line_id := nullif(v_line ->> 'id', '')::uuid;
    v_item_id := nullif(v_line ->> 'item_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    v_uom := v_line ->> 'uom';
    v_expense_category_id := nullif(v_line ->> 'expense_category_id', '')::uuid;
    v_cost_center_id := nullif(v_line ->> 'cost_center_id', '')::uuid;

    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_uom is null or not exists (
      select 1 from public.uoms u where u.code = v_uom
    ) then
      raise exception 'ERR_UOM_UNKNOWN';
    end if;
    if v_item_id is not null then
      if not exists (
        select 1 from public.items i
        where i.id = v_item_id and i.org_id = v_org_id and i.status = 'active'
      ) then
        raise exception 'ERR_INVALID_STATUS';
      end if;
    end if;
    if v_item_id is null
      and (v_line ->> 'description' is null or btrim(v_line ->> 'description') = '')
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_kind = 'stock' and v_item_id is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_expense_category_id is not null and not exists (
      select 1 from public.expense_categories ec
      where ec.id = v_expense_category_id and ec.org_id = v_org_id
    ) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_cost_center_id is not null and not exists (
      select 1 from public.cost_centers cc
      where cc.id = v_cost_center_id and cc.org_id = v_org_id
    ) then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    if v_line_id is not null then
      update public.purchase_request_lines prl
      set item_id = v_item_id,
          description = nullif(v_line ->> 'description', ''),
          qty = v_qty,
          uom = v_uom,
          expense_category_id = v_expense_category_id,
          cost_center_id = v_cost_center_id,
          reason = nullif(v_line ->> 'reason', '')
      where prl.id = v_line_id and prl.pr_id = v_pr_id
        and v_qty >= prl.converted_qty;
      if not found then
        raise exception 'ERR_INVALID_STATUS';
      end if;
    else
      insert into public.purchase_request_lines (
        pr_id, org_id, item_id, description, qty, uom,
        expense_category_id, cost_center_id, reason, created_by
      )
      values (
        v_pr_id, v_org_id, v_item_id,
        nullif(v_line ->> 'description', ''),
        v_qty, v_uom,
        v_expense_category_id, v_cost_center_id,
        nullif(v_line ->> 'reason', ''),
        auth.uid()
      );
    end if;
  end loop;

  select * into v_pr from public.purchase_requests pr where pr.id = v_pr_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_pr_id,
    'doc_no', v_pr.doc_no,
    'status', v_pr.status
  );
end;
$$;

revoke all on function public.pr_save_draft(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.pr_save_draft(uuid, jsonb) to authenticated;

-- Gui PR duyet: sinh buoc theo approval_rules (doc_type 'pr').
create or replace function public.pr_submit(
  p_property_id uuid,
  p_pr_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pr public.purchase_requests%rowtype;
  v_steps integer;
  v_pending integer;
  v_new_status text;
begin
  perform public.require_perm(p_property_id, 'pr.create');

  select * into v_pr
  from public.purchase_requests pr where pr.id = p_pr_id;
  if not found or v_pr.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_pr.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if not exists (
    select 1 from public.purchase_request_lines prl where prl.pr_id = p_pr_id
  ) then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  v_steps := public._generate_approval_steps(
    'pr', p_pr_id, p_property_id, v_pr.org_id, 0
  );
  if v_steps = 0 then
    raise exception 'ERR_CONFIG_NOT_FOUND';
  end if;

  select count(*) into v_pending
  from public.approvals a
  where a.doc_type = 'pr' and a.doc_id = p_pr_id and a.decision = 'pending';
  v_new_status := case when v_pending = 0 then 'approved' else 'submitted' end;

  update public.purchase_requests
  set status = v_new_status where id = p_pr_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_pr_id,
    'doc_no', v_pr.doc_no,
    'status', v_new_status,
    'steps', v_steps,
    'pending_steps', v_pending
  );
end;
$$;

revoke all on function public.pr_submit(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.pr_submit(uuid, uuid) to authenticated;

-- Duyet/tu choi PR (buoc pending thap nhat).
create or replace function public.pr_decide(
  p_property_id uuid,
  p_pr_id uuid,
  p_decision text,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  return public._decide_approval(
    p_property_id, 'pr', p_pr_id, p_decision, p_comment
  );
end;
$$;

revoke all on function public.pr_decide(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.pr_decide(uuid, uuid, text, text) to authenticated;

-- Huy PR nhap / da gui (chua co PO thi moi huy duoc: PR approved tro di
-- chi huy bang cach huy PO lien quan truoc — o day chan luon de don gian,
-- PR approved/converted huy qua po_cancel + tao PR moi).
create or replace function public.pr_cancel(
  p_property_id uuid,
  p_pr_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pr public.purchase_requests%rowtype;
begin
  perform public.require_perm(p_property_id, 'pr.create');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_pr
  from public.purchase_requests pr where pr.id = p_pr_id;
  if not found or v_pr.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_pr.status not in ('draft', 'submitted') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.purchase_requests
  set status = 'cancelled'
  where id = p_pr_id;

  return jsonb_build_object(
    'ok', true, 'id', p_pr_id, 'doc_no', v_pr.doc_no, 'status', 'cancelled'
  );
end;
$$;

revoke all on function public.pr_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.pr_cancel(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPC PO: tao tu PR, sua nhap, gui duyet.
-- ---------------------------------------------------------------------------

-- Tao PO tu cac dong PR da duyet. Gia tu dong: hop dong -> gia tran ->
-- manual (quyet dinh 5). Chuyen toan bo so luong con lai cua moi dong
-- (quyet dinh 6).
create or replace function public.po_create_from_pr(
  p_property_id uuid,
  p_pr_line_ids uuid[],
  p_supplier_id uuid,
  p_channel text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_sup public.suppliers%rowtype;
  v_po_id uuid;
  v_po_no text;
  v_kind text;
  v_line_id uuid;
  v_prl public.purchase_request_lines%rowtype;
  v_pr public.purchase_requests%rowtype;
  v_remaining numeric(18,4);
  v_unit_price numeric(18,4);
  v_price_source text;
  v_ceiling_price numeric(18,4);
  v_over_ceiling boolean;
  v_qty_stock numeric(18,4);
  v_lines integer := 0;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'po.create');

  if p_channel not in ('contract', 'quote', 'market') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_pr_line_ids is null or array_length(p_pr_line_ids, 1) is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select p.org_id, p.legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_sup
  from public.suppliers s where s.id = p_supplier_id;
  if not found or v_sup.org_id <> v_org_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_sup.status <> 'active' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  -- Kiem tra truoc toan bo dong: cung KS, PR da duyet, con so luong,
  -- cung kind, kenh mua cho hop le.
  for v_line_id in select unnest(p_pr_line_ids) loop
    select * into v_prl
    from public.purchase_request_lines prl where prl.id = v_line_id;
    if not found or v_prl.org_id <> v_org_id then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    select * into v_pr
    from public.purchase_requests pr where pr.id = v_prl.pr_id;
    if v_pr.property_id <> p_property_id or v_pr.status <> 'approved' then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    v_remaining := v_prl.qty - v_prl.converted_qty;
    if v_remaining <= 0 then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    if v_kind is null then
      v_kind := v_pr.kind;
    elsif v_kind <> v_pr.kind then
      raise exception 'ERR_INVALID_STATUS';
    end if;

    if v_prl.item_id is not null then
      if not exists (
        select 1 from public.items i
        where i.id = v_prl.item_id and i.org_id = v_org_id and i.status = 'active'
      ) then
        raise exception 'ERR_INVALID_STATUS';
      end if;
      if p_channel = 'market' and not (
        select 'market' = any(i.allowed_channels)
        from public.items i where i.id = v_prl.item_id
      ) then
        raise exception 'ERR_CHANNEL_NOT_ALLOWED';
      end if;
    end if;
  end loop;

  v_po_no := public.next_doc_no(v_legal_entity_id, 'PO', v_today);

  insert into public.purchase_orders (
    org_id, legal_entity_id, property_id, supplier_id, channel, kind,
    order_date, status, doc_no, created_by
  )
  values (
    v_org_id, v_legal_entity_id, p_property_id, p_supplier_id, p_channel,
    v_kind, v_today, 'draft', v_po_no, auth.uid()
  )
  returning id into v_po_id;

  for v_line_id in select unnest(p_pr_line_ids) loop
    select * into v_prl
    from public.purchase_request_lines prl where prl.id = v_line_id;
    v_remaining := v_prl.qty - v_prl.converted_qty;

    select unit_price, price_source, ceiling_price, over_ceiling
      into v_unit_price, v_price_source, v_ceiling_price, v_over_ceiling
    from public._po_resolve_line_price(
      v_org_id, p_property_id, p_supplier_id,
      v_prl.item_id, v_prl.uom, v_today
    );

    v_qty_stock := public._po_line_qty_stock(
      v_org_id, v_prl.item_id, v_prl.uom, v_remaining
    );

    insert into public.purchase_order_lines (
      po_id, org_id, pr_line_id, item_id, description, qty, uom,
      qty_stock, unit_price, price_source, ceiling_price, over_ceiling,
      expense_category_id, cost_center_id, created_by
    )
    values (
      v_po_id, v_org_id, v_prl.id, v_prl.item_id, v_prl.description,
      v_remaining, v_prl.uom, v_qty_stock,
      v_unit_price, v_price_source, v_ceiling_price,
      v_over_ceiling,
      v_prl.expense_category_id, v_prl.cost_center_id, auth.uid()
    );

    update public.purchase_request_lines
    set converted_qty = qty
    where id = v_line_id;

    v_lines := v_lines + 1;
  end loop;

  -- PR nao chuyen het dong thi chuyen sang 'converted'.
  update public.purchase_requests pr
  set status = 'converted'
  where pr.id in (
    select distinct prl.pr_id
    from public.purchase_request_lines prl
    where prl.id = any(p_pr_line_ids)
  )
  and pr.status = 'approved'
  and not exists (
    select 1 from public.purchase_request_lines prl2
    where prl2.pr_id = pr.id and prl2.converted_qty < prl2.qty
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_po_id,
    'doc_no', v_po_no,
    'kind', v_kind,
    'lines', v_lines,
    'status', 'draft'
  );
end;
$$;

revoke all on function public.po_create_from_pr(uuid, uuid[], uuid, text)
  from public, anon, authenticated;
grant execute on function public.po_create_from_pr(uuid, uuid[], uuid, text) to authenticated;

-- Sua PO nhap. p_po: {id, expected_date?, over_ceiling_reason?,
-- lines: [{id?, item_id?, description?, qty, uom, unit_price?,
-- expense_category_id?, cost_center_id?}]}.
-- Khong doi duoc: supplier, channel, kind, item/uom cua dong cu, don
-- gia cua dong khong phai manual. Dong moi giai quyet gia nhu
-- po_create_from_pr (khong gan dong PR).
create or replace function public.po_save_draft(
  p_property_id uuid,
  p_po jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_po public.purchase_orders%rowtype;
  v_po_id uuid;
  v_line jsonb;
  v_line_id uuid;
  v_old public.purchase_order_lines%rowtype;
  v_item_id uuid;
  v_qty numeric(18,4);
  v_uom text;
  v_unit_price numeric(18,4);
  v_price_source text;
  v_ceiling_price numeric(18,4);
  v_over_ceiling boolean;
  v_qty_stock numeric(18,4);
  v_total numeric(18,2);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'po.create');

  v_po_id := nullif(p_po ->> 'id', '')::uuid;
  if v_po_id is null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = v_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status not in ('draft', 'rejected') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if jsonb_typeof(coalesce(p_po -> 'lines', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_org_id := v_po.org_id;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.purchase_orders po
  set expected_date = case
      when p_po ? 'expected_date'
      then nullif(p_po ->> 'expected_date', '')::date
      else po.expected_date end,
    over_ceiling_reason = case
      when p_po ? 'over_ceiling_reason'
      then nullif(p_po ->> 'over_ceiling_reason', '')
      else po.over_ceiling_reason end,
    status = 'draft'
  where po.id = v_po_id;

  if v_po.status = 'rejected' then
    delete from public.approvals
    where doc_type = 'po' and doc_id = v_po_id;
  end if;

  -- Dong bi xoa khoi payload: tra lai so luong da chuyen cho dong PR.
  for v_old in
    select * from public.purchase_order_lines pol
    where pol.po_id = v_po_id
      and not exists (
        select 1
        from jsonb_array_elements(coalesce(p_po -> 'lines', '[]'::jsonb)) l
        where nullif(l ->> 'id', '')::uuid = pol.id
      )
  loop
    if v_old.pr_line_id is not null then
      update public.purchase_request_lines
      set converted_qty = converted_qty - v_old.qty
      where id = v_old.pr_line_id;
      update public.purchase_requests pr
      set status = 'approved'
      where pr.id = (
        select prl.pr_id from public.purchase_request_lines prl
        where prl.id = v_old.pr_line_id
      )
      and pr.status = 'converted';
    end if;
    delete from public.purchase_order_lines where id = v_old.id;
  end loop;

  for v_line in
    select * from jsonb_array_elements(coalesce(p_po -> 'lines', '[]'::jsonb))
  loop
    v_line_id := nullif(v_line ->> 'id', '')::uuid;
    v_item_id := nullif(v_line ->> 'item_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    v_uom := v_line ->> 'uom';

    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_uom is null or not exists (
      select 1 from public.uoms u where u.code = v_uom
    ) then
      raise exception 'ERR_UOM_UNKNOWN';
    end if;
    if v_item_id is not null and not exists (
      select 1 from public.items i
      where i.id = v_item_id and i.org_id = v_org_id and i.status = 'active'
    ) then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    if v_item_id is null
      and (v_line ->> 'description' is null or btrim(v_line ->> 'description') = '')
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_po.kind = 'stock' and v_item_id is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if nullif(v_line ->> 'expense_category_id', '')::uuid is not null
      and not exists (
        select 1 from public.expense_categories ec
        where ec.id = nullif(v_line ->> 'expense_category_id', '')::uuid
          and ec.org_id = v_org_id
      )
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if nullif(v_line ->> 'cost_center_id', '')::uuid is not null
      and not exists (
        select 1 from public.cost_centers cc
        where cc.id = nullif(v_line ->> 'cost_center_id', '')::uuid
          and cc.org_id = v_org_id
      )
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    if v_line_id is not null then
      select * into v_old
      from public.purchase_order_lines pol where pol.id = v_line_id;
      if not found or v_old.po_id <> v_po_id then
        raise exception 'ERR_INVALID_STATUS';
      end if;
      if v_old.pr_line_id is not null then
        -- Dong gan PR: chi cho luu lai nguyen ven (khong sua); muon doi
        -- thi xoa dong khoi payload roi tao lai bang po_create_from_pr.
        if v_old.item_id is distinct from v_item_id
          or v_old.uom <> v_uom
          or v_old.qty <> v_qty
          or (v_line ? 'unit_price'
            and (v_line ->> 'unit_price')::numeric(18,4) <> v_old.unit_price)
          or (v_line ? 'expense_category_id'
            and nullif(v_line ->> 'expense_category_id', '')::uuid
              is distinct from v_old.expense_category_id)
          or (v_line ? 'cost_center_id'
            and nullif(v_line ->> 'cost_center_id', '')::uuid
              is distinct from v_old.cost_center_id)
        then
          raise exception 'ERR_INVALID_STATUS';
        end if;
        continue;
      end if;
      if v_old.item_id is distinct from v_item_id
        or v_old.uom <> v_uom
      then
        -- Doi item/uom: xoa dong cu khoi payload, them dong moi.
        raise exception 'ERR_INVALID_STATUS';
      end if;

      v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

      update public.purchase_order_lines pol
      set qty = v_qty,
          qty_stock = v_qty_stock,
          unit_price = case
            when pol.price_source = 'manual'
              and v_line ? 'unit_price'
            then (v_line ->> 'unit_price')::numeric(18,4)
            else pol.unit_price end,
          over_ceiling = case
            when pol.price_source = 'manual'
              and v_line ? 'unit_price'
            then (pol.ceiling_price is not null
              and (v_line ->> 'unit_price')::numeric(18,4) > pol.ceiling_price)
            else pol.over_ceiling end,
          expense_category_id = case
            when v_line ? 'expense_category_id'
            then nullif(v_line ->> 'expense_category_id', '')::uuid
            else pol.expense_category_id end,
          cost_center_id = case
            when v_line ? 'cost_center_id'
            then nullif(v_line ->> 'cost_center_id', '')::uuid
            else pol.cost_center_id end
      where pol.id = v_line_id
        and (
          pol.price_source = 'manual'
          or not (v_line ? 'unit_price')
          or (v_line ->> 'unit_price')::numeric(18,4) = pol.unit_price
        );
      if not found then
        raise exception 'ERR_INVALID_STATUS';
      end if;
    else
      if v_po.channel = 'market' and v_item_id is not null and not (
        select 'market' = any(i.allowed_channels)
        from public.items i where i.id = v_item_id
      ) then
        raise exception 'ERR_CHANNEL_NOT_ALLOWED';
      end if;

      select unit_price, price_source, ceiling_price, over_ceiling
        into v_unit_price, v_price_source, v_ceiling_price, v_over_ceiling
      from public._po_resolve_line_price(
        v_org_id, p_property_id, v_po.supplier_id,
        v_item_id, v_uom, v_today
      );
      -- Dong moi co gia tay gui kem thi dung gia do (chi khi manual).
      if v_price_source = 'manual' and (v_line ? 'unit_price') then
        v_unit_price := (v_line ->> 'unit_price')::numeric(18,4);
        v_over_ceiling := v_ceiling_price is not null
          and v_unit_price > v_ceiling_price;
      end if;

      v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

      insert into public.purchase_order_lines (
        po_id, org_id, pr_line_id, item_id, description, qty, uom,
        qty_stock, unit_price, price_source, ceiling_price, over_ceiling,
        expense_category_id, cost_center_id, created_by
      )
      values (
        v_po_id, v_org_id, null, v_item_id,
        nullif(v_line ->> 'description', ''),
        v_qty, v_uom, v_qty_stock,
        v_unit_price, v_price_source, v_ceiling_price,
        v_over_ceiling,
        nullif(v_line ->> 'expense_category_id', '')::uuid,
        nullif(v_line ->> 'cost_center_id', '')::uuid,
        auth.uid()
      );
    end if;
  end loop;

  select total_amount into v_total
  from public.purchase_orders where id = v_po_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_po_id,
    'doc_no', v_po.doc_no,
    'status', 'draft',
    'total_amount', v_total
  );
end;
$$;

revoke all on function public.po_save_draft(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.po_save_draft(uuid, jsonb) to authenticated;

-- Gui PO duyet: kiem tra gia tay + ly do vuot tran, sinh buoc duyet.
create or replace function public.po_submit(
  p_property_id uuid,
  p_po_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_po public.purchase_orders%rowtype;
  v_steps integer;
  v_pending integer;
  v_new_status text;
begin
  perform public.require_perm(p_property_id, 'po.create');

  select * into v_po
  from public.purchase_orders po where po.id = p_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if not exists (
    select 1 from public.purchase_order_lines pol where pol.po_id = p_po_id
  ) then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if exists (
    select 1 from public.purchase_order_lines pol
    where pol.po_id = p_po_id
      and pol.price_source = 'manual'
      and pol.unit_price <= 0
  ) then
    raise exception 'ERR_PRICE_NOT_SET';
  end if;
  if exists (
    select 1 from public.purchase_order_lines pol
    where pol.po_id = p_po_id and pol.over_ceiling
  ) and (v_po.over_ceiling_reason is null or btrim(v_po.over_ceiling_reason) = '')
  then
    raise exception 'ERR_OVER_CEILING_NO_REASON';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  v_steps := public._generate_approval_steps(
    'po', p_po_id, p_property_id, v_po.org_id, v_po.total_amount
  );
  if v_steps = 0 then
    raise exception 'ERR_CONFIG_NOT_FOUND';
  end if;

  select count(*) into v_pending
  from public.approvals a
  where a.doc_type = 'po' and a.doc_id = p_po_id and a.decision = 'pending';
  v_new_status := case when v_pending = 0 then 'approved' else 'submitted' end;

  update public.purchase_orders
  set status = v_new_status where id = p_po_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_po_id,
    'doc_no', v_po.doc_no,
    'status', v_new_status,
    'steps', v_steps,
    'pending_steps', v_pending
  );
end;
$$;

revoke all on function public.po_submit(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.po_submit(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPC duyet chung + gui/dong/huy PO + quan ly uy quyen.
-- ---------------------------------------------------------------------------

-- Duyet/tu choi buoc pending thap nhat cua 1 chung tu (pr hoac po).
create or replace function public.approval_decide(
  p_property_id uuid,
  p_doc_type text,
  p_doc_id uuid,
  p_decision text,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  return public._decide_approval(
    p_property_id, p_doc_type, p_doc_id, p_decision, p_comment
  );
end;
$$;

revoke all on function public.approval_decide(uuid, text, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.approval_decide(uuid, text, uuid, text, text) to authenticated;

-- Gui PO cho NCC (PDF o route /api/export/po/[id] — T-021/T-043).
create or replace function public.po_send(
  p_property_id uuid,
  p_po_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_po public.purchase_orders%rowtype;
begin
  perform public.require_perm(p_property_id, 'po.create');

  select * into v_po
  from public.purchase_orders po where po.id = p_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status <> 'approved' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.purchase_orders
  set status = 'sent' where id = p_po_id;

  return jsonb_build_object(
    'ok', true, 'id', p_po_id, 'doc_no', v_po.doc_no, 'status', 'sent'
  );
end;
$$;

revoke all on function public.po_send(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.po_send(uuid, uuid) to authenticated;

-- Dong phan con thieu cua PO (ly do bat buoc).
create or replace function public.po_close(
  p_property_id uuid,
  p_po_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_po public.purchase_orders%rowtype;
begin
  perform public.require_perm(p_property_id, 'po.close');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = p_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status not in ('approved', 'sent', 'partially_received') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.purchase_orders
  set status = 'closed' where id = p_po_id;

  return jsonb_build_object(
    'ok', true, 'id', p_po_id, 'doc_no', v_po.doc_no, 'status', 'closed'
  );
end;
$$;

revoke all on function public.po_close(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.po_close(uuid, uuid, text) to authenticated;

-- Huy PO (M03: sua PO sau approved -> cancel + tao PO moi, giu
-- replaces_po_id). Chi tu draft/submitted/approved; PO da sent thi
-- dung po_close. Huy thi tra lai so luong da chuyen cho dong PR.
create or replace function public.po_cancel(
  p_property_id uuid,
  p_po_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_po public.purchase_orders%rowtype;
  v_line public.purchase_order_lines%rowtype;
begin
  perform public.require_perm(p_property_id, 'po.create');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = p_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status not in ('draft', 'submitted', 'approved') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  for v_line in
    select * from public.purchase_order_lines pol where pol.po_id = p_po_id
  loop
    if v_line.pr_line_id is not null then
      update public.purchase_request_lines
      set converted_qty = converted_qty - v_line.qty
      where id = v_line.pr_line_id;
      update public.purchase_requests pr
      set status = 'approved'
      where pr.id = (
        select prl.pr_id from public.purchase_request_lines prl
        where prl.id = v_line.pr_line_id
      )
      and pr.status = 'converted';
    end if;
  end loop;

  update public.purchase_orders
  set status = 'cancelled' where id = p_po_id;

  return jsonb_build_object(
    'ok', true, 'id', p_po_id, 'doc_no', v_po.doc_no, 'status', 'cancelled'
  );
end;
$$;

revoke all on function public.po_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.po_cancel(uuid, uuid, text) to authenticated;

-- Quan ly uy quyen duyet (quyet dinh 9). p_delegation: {id?, from_user,
-- to_user, property_id?, valid_from, valid_to, reason?}.
create or replace function public.admin_approval_delegation_save(
  p_org_id uuid,
  p_delegation jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id uuid;
  v_from uuid;
  v_to uuid;
  v_property_id uuid;
  v_from_date date;
  v_to_date date;
begin
  v_from := nullif(p_delegation ->> 'from_user', '')::uuid;
  v_to := nullif(p_delegation ->> 'to_user', '')::uuid;
  v_property_id := nullif(p_delegation ->> 'property_id', '')::uuid;
  v_from_date := nullif(p_delegation ->> 'valid_from', '')::date;
  v_to_date := nullif(p_delegation ->> 'valid_to', '')::date;
  v_id := nullif(p_delegation ->> 'id', '')::uuid;

  if v_from is null or v_to is null or v_from = v_to then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_from_date is null or v_to_date is null or v_to_date < v_from_date then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_property_id is not null and not exists (
    select 1 from public.properties p
    where p.id = v_property_id and p.org_id = p_org_id
  ) then
    raise exception 'ERR_CONFIG_SCOPE';
  end if;
  if not exists (
    select 1 from public.profiles pr where pr.id = v_from
  ) or not exists (
    select 1 from public.profiles pr where pr.id = v_to
  ) then
    raise exception 'ERR_CONFIG_APPROVER';
  end if;

  perform public._admin_config_require_perm(
    p_org_id, v_property_id, 'admin.approval_rules.manage'
  );

  if v_id is null then
    insert into public.approval_delegations (
      org_id, from_user, to_user, property_id,
      valid_from, valid_to, reason, created_by
    )
    values (
      p_org_id, v_from, v_to, v_property_id,
      v_from_date, v_to_date,
      nullif(p_delegation ->> 'reason', ''),
      auth.uid()
    )
    returning id into v_id;
  else
    update public.approval_delegations d
    set from_user = v_from,
        to_user = v_to,
        property_id = v_property_id,
        valid_from = v_from_date,
        valid_to = v_to_date,
        reason = nullif(p_delegation ->> 'reason', '')
    where d.id = v_id and d.org_id = p_org_id;
    if not found then
      raise exception 'ERR_CONFIG_NOT_FOUND';
    end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

revoke all on function public.admin_approval_delegation_save(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_approval_delegation_save(uuid, jsonb) to authenticated;

create or replace function public.admin_approval_delegation_delete(
  p_org_id uuid,
  p_delegation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
begin
  select d.property_id into v_property_id
  from public.approval_delegations d
  where d.id = p_delegation_id and d.org_id = p_org_id;
  if not found then
    raise exception 'ERR_CONFIG_NOT_FOUND';
  end if;

  perform public._admin_config_require_perm(
    p_org_id, v_property_id, 'admin.approval_rules.manage'
  );

  delete from public.approval_delegations
  where id = p_delegation_id and org_id = p_org_id;

  return jsonb_build_object('ok', true, 'id', p_delegation_id);
end;
$$;

revoke all on function public.admin_approval_delegation_delete(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.admin_approval_delegation_delete(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Seed ma tran duyet mac dinh (05-BUSINESS-RULES.md §2) cho moi org
--    hien co. Quy tac theo cap chuoi (property_id null); quan tri co the
--    ghi de theo KS bang admin_approval_rule_save (T-006).
-- ---------------------------------------------------------------------------
do $$
declare
  v_org record;
begin
  for v_org in select o.id from public.organizations o loop
    insert into public.approval_rules (
      org_id, property_id, doc_type, min_amount, max_amount,
      item_group_id, condition, step,
      approver_role_id, approver_user_id, required_perm
    )
    select
      v_org.id,
      null,
      v.doc_type,
      v.min_amount,
      v.max_amount,
      null,
      '{}'::jsonb,
      v.step,
      r.id,
      null,
      v.required_perm
    from (values
      ('pr', 0::numeric(18,2), null::numeric(18,2), 1, 'outlet_head', 'pr.approve'),
      ('po', 0::numeric(18,2), 5000000::numeric(18,2), 1, 'outlet_head', 'po.approve'),
      ('po', 5000000::numeric(18,2), 20000000::numeric(18,2), 2, 'cost_controller', 'po.approve'),
      ('po', 20000000::numeric(18,2), 100000000::numeric(18,2), 3, 'gm', 'po.approve'),
      ('po', 100000000::numeric(18,2), null::numeric(18,2), 4, 'owner', 'po.approve')
    ) as v (doc_type, min_amount, max_amount, step, role_code, required_perm)
    join public.roles r
      on r.org_id = v_org.id and r.code = v.role_code
    on conflict do nothing;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 9. Gan quyen po.close cho vai tro mau (ma da seed san, chua gan ai).
--    Join theo ma vai tro, giong mau seed.sql.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('purchaser', 'po.close'),
  ('owner', 'po.close')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109210000_procurement_pr_po',
  'INSERT',
  jsonb_build_object('event', 'procurement_pr_po_created', 'task', 'T-020'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);

-- ---------------------------------------------------------------------------
-- 10. RPC doc (phuc vu man hinh T-021). Doc qua RPC thay vi SELECT truc
--    tiep de khong phu thuoc database.types.ts (chua sinh lai duoc tren
--    VM khong Docker); RLS SELECT o muc 2 van la lop bao ve thu hai.
-- ---------------------------------------------------------------------------

-- Danh sach PR (loc theo trang thai + tim theo so chung tu/ghi chu).
create or replace function public.pr_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'pr.create')
    or public.has_perm(p_property_id, 'pr.approve')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.view')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      pr.id, pr.doc_no, pr.kind, pr.need_date, pr.status, pr.note,
      pr.outlet_id, o.name as outlet_name,
      pr.created_by, pr.created_at, pr.updated_at,
      count(prl.id) as line_count
    from public.purchase_requests pr
    left join public.outlets o on o.id = pr.outlet_id
    left join public.purchase_request_lines prl on prl.pr_id = pr.id
    where pr.property_id = p_property_id
      and (p_status is null or pr.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or pr.doc_no ilike '%' || p_search || '%'
        or pr.note ilike '%' || p_search || '%'
      )
    group by pr.id, o.name
  )
  select jsonb_build_object(
    'ok', true,
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f))
      from (select * from filtered order by created_at desc limit v_limit offset v_offset) f
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.pr_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.pr_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet PR + dong (kem ten vat tu).
create or replace function public.pr_get(
  p_property_id uuid,
  p_pr_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pr public.purchase_requests%rowtype;
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'pr.create')
    or public.has_perm(p_property_id, 'pr.approve')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.view')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select * into v_pr
  from public.purchase_requests pr where pr.id = p_pr_id;
  if not found or v_pr.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select jsonb_build_object(
    'ok', true,
    'pr', to_jsonb(v_pr),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l))
      from (
        select prl.*, i.code as item_code, i.name as item_name
        from public.purchase_request_lines prl
        left join public.items i on i.id = prl.item_id
        where prl.pr_id = p_pr_id
        order by prl.created_at asc
      ) l
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.pr_get(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.pr_get(uuid, uuid) to authenticated;

-- Danh sach PO (loc theo trang thai + tim theo so chung tu / ten NCC).
create or replace function public.po_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'po.view')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.approve')
    or public.has_perm(p_property_id, 'po.close')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      po.id, po.doc_no, po.kind, po.channel, po.supplier_id,
      s.name as supplier_name, po.order_date, po.expected_date,
      po.total_amount, po.status, po.over_ceiling_reason,
      po.created_by, po.created_at, po.updated_at,
      count(pol.id) as line_count,
      coalesce(sum(pol.received_qty_stock), 0) as received_qty_stock
    from public.purchase_orders po
    join public.suppliers s on s.id = po.supplier_id
    left join public.purchase_order_lines pol on pol.po_id = po.id
    where po.property_id = p_property_id
      and (p_status is null or po.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or po.doc_no ilike '%' || p_search || '%'
        or s.name ilike '%' || p_search || '%'
      )
    group by po.id, s.name
  )
  select jsonb_build_object(
    'ok', true,
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f))
      from (select * from filtered order by created_at desc limit v_limit offset v_offset) f
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.po_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.po_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet PO + dong (kem ten vat tu, ten NCC).
create or replace function public.po_get(
  p_property_id uuid,
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
  v_supplier_name text;
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'po.view')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.approve')
    or public.has_perm(p_property_id, 'po.close')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = p_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select s.name into v_supplier_name
  from public.suppliers s where s.id = v_po.supplier_id;

  select jsonb_build_object(
    'ok', true,
    'po', to_jsonb(v_po) || jsonb_build_object('supplier_name', v_supplier_name),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l))
      from (
        select pol.*, i.code as item_code, i.name as item_name
        from public.purchase_order_lines pol
        left join public.items i on i.id = pol.item_id
        where pol.po_id = p_po_id
        order by pol.created_at asc
      ) l
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.po_get(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.po_get(uuid, uuid) to authenticated;

-- Timeline duyet cua 1 chung tu (kem ten vai tro + nguoi duyet + uy quyen).
create or replace function public.approval_timeline(
  p_property_id uuid,
  p_doc_type text,
  p_doc_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_result jsonb;
begin
  if p_doc_type = 'pr' then
    if not (
      public.has_perm(p_property_id, 'pr.create')
      or public.has_perm(p_property_id, 'pr.approve')
      or public.has_perm(p_property_id, 'po.create')
      or public.has_perm(p_property_id, 'po.view')
    ) then
      raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
    end if;
  elsif p_doc_type = 'po' then
    if not (
      public.has_perm(p_property_id, 'po.view')
      or public.has_perm(p_property_id, 'po.create')
      or public.has_perm(p_property_id, 'po.approve')
      or public.has_perm(p_property_id, 'po.close')
    ) then
      raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
    end if;
  else
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select jsonb_build_object(
    'ok', true,
    'steps', coalesce((
      select jsonb_agg(to_jsonb(s))
      from (
        select
          a.id, a.step, a.approver_role_id, r.name_vi as approver_role_name,
          a.approver_user_id, a.required_perm, a.decision, a.comment,
          a.decided_by, p1.full_name as decided_by_name,
          a.decided_at, a.delegated_from, p2.full_name as delegated_from_name,
          a.created_at
        from public.approvals a
        left join public.roles r on r.id = a.approver_role_id
        left join public.profiles p1 on p1.id = a.decided_by
        left join public.profiles p2 on p2.id = a.delegated_from
        where a.doc_type = p_doc_type and a.doc_id = p_doc_id
        order by a.step asc
      ) s
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.approval_timeline(uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.approval_timeline(uuid, text, uuid) to authenticated;
