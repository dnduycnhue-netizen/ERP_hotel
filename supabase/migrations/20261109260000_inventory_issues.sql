-- Migration 08 (T-030): phieu linh 2 buoc, dieu chuyen, xuat theo muc dich, huy hang.
--
-- Pham vi:
--   - 8 bang moi: requisitions / requisition_lines, transfers / transfer_lines,
--     purpose_issues / purpose_issue_lines, waste_reports / waste_report_lines.
--   - RPC ghi: requisition_* (save_draft/submit/cancel/issue/confirm_receipt),
--     transfer_* (save_draft/send/receive/cancel), purpose_issue_* (save_draft/
--     post/cancel/reverse), waste_* (save_draft/submit/cancel) + RPC doc
--     (list/get) cho ca 4 loai. Duyet phieu linh + huy hang dung chung co che
--     approvals cua T-020 qua approval_decide / requisition_decide / waste_decide
--     (mo rong _decide_approval o muc 6).
--   - Quy tac: phieu linh outlet tao -> truong outlet duyet (approval_rules
--     doc_type='requisition'); huy hang nguoi de xuat != nguoi duyet (SOD_WASTE),
--     vuot nguong waste_approval_threshold_vnd [cau hinh] them buoc gm
--     (waste.approve.large) + alert WASTE_LARGE.
--   - Ghi so qua _post_move (T-011): issue_out/issue_in qua kho transit cho
--     phieu linh + dieu chuyen (transfer_out/transfer_in), purpose_issue va
--     waste theo gia binh quan hien tai. Khong viet lai ledger.
--   - Chi chuyen trong cung phap nhan: dieu chuyen khac phap nhan bi chan
--     (ERR_INVALID_VALUE) — xem Q27; is_inter_entity luu san cho P2.
--   - Khong sua migration cu. Ma quyen moi duy nhat: purpose_issue.reverse
--     (cac ma khac da seed san tu 20261108141000).
--   - RLS: policy dung `property_id in (select public.my_property_ids())`,
--     KHONG dung `= any (public.my_property_ids())` (SRF cam trong policy).

-- ---------------------------------------------------------------------------
-- 1. Ma quyen moi (chen vao danh muc; cac ma kho khac da seed san).
-- ---------------------------------------------------------------------------
insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('purpose_issue.reverse', 'Kho', 'Đảo xuất theo mục đích', 'Đảo bút toán xuất theo mục đích đã ghi sổ (chỉ gm).', 'critical', 581)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Bang phieu linh (requisitions) — 03-DATA-MODEL.md A5 + M05.
--    Trang thai: draft -> submitted -> approved -> issued ->
--    partially_received -> received; cancelled (chi truoc khi xuat).
-- ---------------------------------------------------------------------------
create table public.requisitions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  outlet_id uuid not null references public.outlets(id),
  from_warehouse_id uuid not null references public.warehouses(id),
  to_warehouse_id uuid not null references public.warehouses(id),
  doc_no text not null,
  business_date date not null,
  status text not null default 'draft' check (status in (
    'draft', 'submitted', 'approved', 'issued', 'partially_received',
    'received', 'cancelled'
  )),
  note text,
  discrepancy_note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  check (from_warehouse_id <> to_warehouse_id),
  foreign key (outlet_id, property_id) references public.outlets(id, property_id),
  foreign key (from_warehouse_id, property_id) references public.warehouses(id, property_id),
  foreign key (to_warehouse_id, property_id) references public.warehouses(id, property_id)
);
create index on public.requisitions (property_id, status, created_at desc);
create index on public.requisitions (outlet_id, status);

create table public.requisition_lines (
  id uuid primary key default gen_random_uuid(),
  requisition_id uuid not null,
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  item_id uuid not null references public.items(id),
  uom text not null,
  qty numeric(18,4) not null check (qty > 0),
  qty_stock numeric(18,4) not null check (qty_stock > 0),
  issued_qty_stock numeric(18,4) not null default 0 check (issued_qty_stock >= 0),
  received_qty_stock numeric(18,4) not null default 0 check (received_qty_stock >= 0),
  lot_id uuid references public.lots(id),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (requisition_id, org_id) references public.requisitions(id, org_id) on delete cascade,
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id),
  check (issued_qty_stock <= qty_stock),
  check (received_qty_stock <= issued_qty_stock)
);
create index on public.requisition_lines (requisition_id, item_id);

-- ---------------------------------------------------------------------------
-- 3. Bang dieu chuyen (transfers) — 03-DATA-MODEL.md A5 + M05.
--    Trang thai: draft -> in_transit -> partially_received -> received;
--    cancelled (chi khi draft). Nhan du moi len 'received'.
-- ---------------------------------------------------------------------------
create table public.transfers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  from_warehouse_id uuid not null references public.warehouses(id),
  to_warehouse_id uuid not null references public.warehouses(id),
  doc_no text not null,
  business_date date not null,
  status text not null default 'draft' check (status in (
    'draft', 'in_transit', 'partially_received', 'received', 'cancelled'
  )),
  is_inter_entity boolean not null default false,
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  check (from_warehouse_id <> to_warehouse_id),
  foreign key (from_warehouse_id, property_id) references public.warehouses(id, property_id),
  foreign key (to_warehouse_id, property_id) references public.warehouses(id, property_id)
);
create index on public.transfers (property_id, status, created_at desc);

create table public.transfer_lines (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null,
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  item_id uuid not null references public.items(id),
  uom text not null,
  qty numeric(18,4) not null check (qty > 0),
  qty_stock numeric(18,4) not null check (qty_stock > 0),
  sent_qty_stock numeric(18,4) not null default 0 check (sent_qty_stock >= 0),
  received_qty_stock numeric(18,4) not null default 0 check (received_qty_stock >= 0),
  lot_id uuid references public.lots(id),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (transfer_id, org_id) references public.transfers(id, org_id) on delete cascade,
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id),
  check (sent_qty_stock <= qty_stock),
  check (received_qty_stock <= sent_qty_stock)
);
create index on public.transfer_lines (transfer_id, item_id);

-- ---------------------------------------------------------------------------
-- 4. Bang xuat theo muc dich (purpose_issues) — 03-DATA-MODEL.md A5 + 05 §5.
--    Trang thai: draft -> posted -> reversed; cancelled (chi khi draft).
--    cost_center + expense_category bat buoc luc post (khong bat buoc luc nhap).
-- ---------------------------------------------------------------------------
create table public.purpose_issues (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  warehouse_id uuid not null references public.warehouses(id),
  doc_no text not null,
  business_date date not null,
  status text not null default 'draft' check (status in (
    'draft', 'posted', 'reversed', 'cancelled'
  )),
  purpose_code text not null check (purpose_code in (
    'staff_meal', 'vip_comp', 'marketing', 'meeting', 'training', 'repair', 'other'
  )),
  cost_center_id uuid references public.cost_centers(id),
  expense_category_id uuid references public.expense_categories(id),
  work_order_id uuid,
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  foreign key (warehouse_id, property_id) references public.warehouses(id, property_id),
  foreign key (cost_center_id, org_id) references public.cost_centers(id, org_id),
  foreign key (expense_category_id, org_id) references public.expense_categories(id, org_id)
);
create index on public.purpose_issues (property_id, status, created_at desc);
create index on public.purpose_issues (property_id, purpose_code, business_date);

create table public.purpose_issue_lines (
  id uuid primary key default gen_random_uuid(),
  purpose_issue_id uuid not null,
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  item_id uuid not null references public.items(id),
  uom text not null,
  qty numeric(18,4) not null check (qty > 0),
  qty_stock numeric(18,4) not null check (qty_stock > 0),
  lot_id uuid references public.lots(id),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (purpose_issue_id, org_id) references public.purpose_issues(id, org_id) on delete cascade,
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id)
);
create index on public.purpose_issue_lines (purpose_issue_id, item_id);

-- ---------------------------------------------------------------------------
-- 5. Bang huy hang (waste_reports) — 03-DATA-MODEL.md A5 + 05 §5 + M05.
--    Trang thai: draft -> submitted -> posted (duyet xong ghi so ngay) /
--    rejected; cancelled (chi khi draft/submitted). Khong co trang thai
--    'approved' rieng: duyet du buoc = posted.
-- ---------------------------------------------------------------------------
create table public.waste_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  warehouse_id uuid not null references public.warehouses(id),
  doc_no text not null,
  business_date date not null,
  status text not null default 'draft' check (status in (
    'draft', 'submitted', 'posted', 'rejected', 'cancelled'
  )),
  reason_code text not null check (reason_code in (
    'expired', 'spoiled_storage', 'broken', 'guest_return', 'other'
  )),
  photo_ids uuid[] not null default '{}'::uuid[],
  total_value numeric(18,2) not null default 0 check (total_value >= 0),
  proposed_by uuid references auth.users(id) default auth.uid(),
  approved_by uuid references auth.users(id),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  foreign key (warehouse_id, property_id) references public.warehouses(id, property_id)
);
create index on public.waste_reports (property_id, status, created_at desc);
create index on public.waste_reports (property_id, reason_code, business_date);

create table public.waste_report_lines (
  id uuid primary key default gen_random_uuid(),
  waste_report_id uuid not null,
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  item_id uuid not null references public.items(id),
  lot_id uuid references public.lots(id),
  qty_stock numeric(18,4) not null check (qty_stock > 0),
  unit_cost numeric(18,4) not null default 0 check (unit_cost >= 0),
  note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (waste_report_id, org_id) references public.waste_reports(id, org_id) on delete cascade,
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id)
);
create index on public.waste_report_lines (waste_report_id, item_id);

-- ---------------------------------------------------------------------------
-- 6. RLS (SELECT-only; ghi chi qua RPC SECURITY DEFINER) + trigger updated_at.
-- ---------------------------------------------------------------------------
alter table public.requisitions enable row level security;
alter table public.requisition_lines enable row level security;
alter table public.transfers enable row level security;
alter table public.transfer_lines enable row level security;
alter table public.purpose_issues enable row level security;
alter table public.purpose_issue_lines enable row level security;
alter table public.waste_reports enable row level security;
alter table public.waste_report_lines enable row level security;

create policy requisitions_select on public.requisitions
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'requisition.create')
    or public.has_perm(property_id, 'requisition.approve')
    or public.has_perm(property_id, 'requisition.issue')
    or public.has_perm(property_id, 'requisition.receive')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy requisition_lines_select on public.requisition_lines
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'requisition.create')
    or public.has_perm(property_id, 'requisition.approve')
    or public.has_perm(property_id, 'requisition.issue')
    or public.has_perm(property_id, 'requisition.receive')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy transfers_select on public.transfers
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'transfer.send')
    or public.has_perm(property_id, 'transfer.receive')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy transfer_lines_select on public.transfer_lines
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'transfer.send')
    or public.has_perm(property_id, 'transfer.receive')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy purpose_issues_select on public.purpose_issues
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'purpose_issue.post')
    or public.has_perm(property_id, 'purpose_issue.reverse')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy purpose_issue_lines_select on public.purpose_issue_lines
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'purpose_issue.post')
    or public.has_perm(property_id, 'purpose_issue.reverse')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy waste_reports_select on public.waste_reports
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'waste.propose')
    or public.has_perm(property_id, 'waste.approve')
    or public.has_perm(property_id, 'waste.approve.large')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);
create policy waste_report_lines_select on public.waste_report_lines
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'waste.propose')
    or public.has_perm(property_id, 'waste.approve')
    or public.has_perm(property_id, 'waste.approve.large')
    or public.has_perm(property_id, 'stock.view_qty')
  )
);

do $$
declare
  v_table text;
begin
  for v_table in
    select unnest(array[
      'requisitions', 'requisition_lines',
      'transfers', 'transfer_lines',
      'purpose_issues', 'purpose_issue_lines',
      'waste_reports', 'waste_report_lines'
    ])
  loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Write-guard + status-guard (mau _pr_po_write_guard / _pr_po_status_guard,
--    T-020): chi RPC cua module nay (bat GUC app.inventory_guard_bypass)
--    moi duoc ghi truc tiep vao 8 bang.
-- ---------------------------------------------------------------------------
create or replace function public._inventory_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.inventory_guard_bypass', true), '') <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public._inventory_write_guard()
  from public, anon, authenticated;

create or replace function public._inventory_status_guard()
returns trigger
language plpgsql
as $$
begin
  if (
    old.status is distinct from new.status
    or old.created_by is distinct from new.created_by
  ) and coalesce(
    current_setting('app.inventory_guard_bypass', true), ''
  ) <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return new;
end;
$$;

revoke all on function public._inventory_status_guard()
  from public, anon, authenticated;

do $$
declare
  v_table text;
begin
  for v_table in
    select unnest(array[
      'requisitions', 'requisition_lines',
      'transfers', 'transfer_lines',
      'purpose_issues', 'purpose_issue_lines',
      'waste_reports', 'waste_report_lines'
    ])
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      'trg_' || v_table || '_write_guard', v_table
    );
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function public._inventory_write_guard()',
      'trg_' || v_table || '_write_guard', v_table
    );
  end loop;
  for v_table in
    select unnest(array[
      'requisitions', 'transfers', 'purpose_issues', 'waste_reports'
    ])
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      'trg_' || v_table || '_status_guard', v_table
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function public._inventory_status_guard()',
      'trg_' || v_table || '_status_guard', v_table
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Ham phu noi bo.
-- ---------------------------------------------------------------------------

-- Kho transit duy nhat cua khach san (M05: hang cho o transit giua 2 buoc).
create or replace function public._inventory_transit_wh(p_property_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wh uuid;
begin
  select w.id into v_wh
  from public.warehouses w
  where w.property_id = p_property_id and w.kind = 'transit'
  order by w.created_at asc
  limit 1;
  if v_wh is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  return v_wh;
end;
$$;

revoke all on function public._inventory_transit_wh(uuid)
  from public, anon, authenticated;

-- Gia binh quan hien tai cua 1 ma tai 1 phap nhan (0 neu chua co item_costs).
create or replace function public._inventory_avg_cost(
  p_entity uuid,
  p_item_id uuid
)
returns numeric(18,4)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_cost numeric(18,4);
begin
  select ic.avg_cost into v_cost
  from public.item_costs ic
  where ic.legal_entity_id = p_entity and ic.item_id = p_item_id;
  return coalesce(v_cost, 0);
end;
$$;

revoke all on function public._inventory_avg_cost(uuid, uuid)
  from public, anon, authenticated;

-- Ghi so cac dong huy hang (goi khi duyet du buoc): move 'waste' theo gia
-- binh quan hien tai; cap nhat unit_cost dong + approved_by. Chi goi tu
-- _decide_approval (da bat bypass), trong cung transaction voi quyet dinh.
create or replace function public._waste_post_moves(p_waste_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wr public.waste_reports%rowtype;
  v_line public.waste_report_lines%rowtype;
  v_cost numeric(18,4);
begin
  select * into v_wr
  from public.waste_reports wr where wr.id = p_waste_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  for v_line in
    select * from public.waste_report_lines wrl
    where wrl.waste_report_id = p_waste_id
    order by wrl.created_at asc
  loop
    v_cost := public._inventory_avg_cost(v_wr.legal_entity_id, v_line.item_id);

    perform set_config('app.inventory_guard_bypass', 'on', true);
    update public.waste_report_lines
    set unit_cost = v_cost
    where id = v_line.id;

    perform public._post_move(
      v_wr.legal_entity_id, v_wr.property_id, v_wr.warehouse_id,
      v_line.item_id, v_line.lot_id,
      'waste', -v_line.qty_stock, v_cost,
      v_wr.business_date, 'waste', p_waste_id, v_line.id
    );
  end loop;

  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.waste_reports
  set approved_by = auth.uid()
  where id = p_waste_id;
end;
$$;

revoke all on function public._waste_post_moves(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Mo rong _decide_approval (T-020) them 2 loai chung tu kho: 'requisition'
--    (SoD SOD_REQUISITION_CREATOR_APPROVER) va 'waste' (SoD SOD_WASTE).
--    Duyet du buoc huy hang -> ghi so move 'waste' ngay + status 'posted'
--    (khong dung trang thai trung gian 'approved'). Phan PR/PO giu nguyen.
-- ---------------------------------------------------------------------------
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
  elsif p_doc_type = 'requisition' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.requisitions where id = p_doc_id;
    v_sod_code := 'SOD_REQUISITION_CREATOR_APPROVER';
  elsif p_doc_type = 'waste' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.waste_reports where id = p_doc_id;
    v_sod_code := 'SOD_WASTE';
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
  perform set_config('app.inventory_guard_bypass', 'on', true);

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

  -- Huy hang: duyet du buoc thi ghi so luon, khong dung 'approved'.
  if p_doc_type = 'waste' and v_new_status = 'approved' then
    perform public._waste_post_moves(p_doc_id);
    v_new_status := 'posted';
  end if;

  if p_doc_type = 'pr' then
    update public.purchase_requests
    set status = v_new_status where id = p_doc_id;
  elsif p_doc_type = 'po' then
    update public.purchase_orders
    set status = v_new_status where id = p_doc_id;
  elsif p_doc_type = 'requisition' then
    update public.requisitions
    set status = v_new_status where id = p_doc_id;
  else
    update public.waste_reports
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
-- 10. Mo rong _repoint_merged_item_refs (T-020, Q13): gop ma tam cung chuyen
--     dong cua phieu linh / dieu chuyen / xuat muc dich / huy hang DANG NHAP
--     sang ma dich. Chung tu da submit tro di khong doi.
-- ---------------------------------------------------------------------------
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

    perform set_config('app.inventory_guard_bypass', 'on', true);
    update public.requisition_lines rl
    set item_id = new.merged_into_id
    from public.requisitions r
    where rl.requisition_id = r.id
      and rl.item_id = old.id
      and r.status = 'draft';
    update public.transfer_lines tl
    set item_id = new.merged_into_id
    from public.transfers t
    where tl.transfer_id = t.id
      and tl.item_id = old.id
      and t.status = 'draft';
    update public.purpose_issue_lines pil
    set item_id = new.merged_into_id
    from public.purpose_issues pi
    where pil.purpose_issue_id = pi.id
      and pil.item_id = old.id
      and pi.status = 'draft';
    update public.waste_report_lines wrl
    set item_id = new.merged_into_id
    from public.waste_reports wr
    where wrl.waste_report_id = wr.id
      and wrl.item_id = old.id
      and wr.status = 'draft';
  end if;
  return new;
end;
$$;

revoke all on function public._repoint_merged_item_refs()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPC phieu linh.
-- ---------------------------------------------------------------------------

-- Tao/sua phieu linh nhap. p_requisition: {id?, property_id, outlet_id,
-- from_warehouse_id, to_warehouse_id, business_date?, note?,
-- lines: [{id?, item_id, qty, uom?, note?}]}. Chi sua duoc khi draft
-- (rejected -> quay ve draft, xoa buoc duyet cu). Kho dich phai la kho cua
-- outlet (to_warehouse.outlet_id = outlet_id); kho nguon la main/floor.
create or replace function public.requisition_save_draft(
  p_requisition jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_doc jsonb := p_requisition;
  v_id uuid := nullif(v_doc ->> 'id', '')::uuid;
  v_property_id uuid := (v_doc ->> 'property_id')::uuid;
  v_org_id uuid;
  v_entity_id uuid;
  v_outlet_id uuid := (v_doc ->> 'outlet_id')::uuid;
  v_from_wh uuid := (v_doc ->> 'from_warehouse_id')::uuid;
  v_to_wh uuid := (v_doc ->> 'to_warehouse_id')::uuid;
  v_business_date date := coalesce(
    nullif(v_doc ->> 'business_date', '')::date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_note text := nullif(v_doc ->> 'note', '');
  v_existing public.requisitions%rowtype;
  v_from_kind text;
  v_to_outlet uuid;
  v_line jsonb;
  v_item public.items%rowtype;
  v_uom text;
  v_qty numeric(18,4);
  v_qty_stock numeric(18,4);
  v_doc_no text;
  v_status text;
begin
  if v_property_id is null or v_outlet_id is null
    or v_from_wh is null or v_to_wh is null
  then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_from_wh = v_to_wh then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_property_id, 'requisition.create');

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = v_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not exists (
    select 1 from public.outlets o
    where o.id = v_outlet_id and o.property_id = v_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select w.kind into v_from_kind
  from public.warehouses w
  where w.id = v_from_wh and w.property_id = v_property_id;
  if not found or v_from_kind not in ('main', 'floor') then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select w.outlet_id into v_to_outlet
  from public.warehouses w
  where w.id = v_to_wh and w.property_id = v_property_id;
  if not found or v_to_outlet is distinct from v_outlet_id then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  if v_id is not null then
    select * into v_existing
    from public.requisitions r where r.id = v_id;
    if not found or v_existing.property_id <> v_property_id then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_existing.status not in ('draft', 'rejected') then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    v_doc_no := v_existing.doc_no;
    v_status := 'draft';
    update public.requisitions r
    set outlet_id = v_outlet_id,
        from_warehouse_id = v_from_wh,
        to_warehouse_id = v_to_wh,
        business_date = v_business_date,
        note = v_note,
        status = 'draft'
    where r.id = v_id;
    delete from public.approvals a
    where a.doc_type = 'requisition' and a.doc_id = v_id;
    delete from public.requisition_lines rl
    where rl.requisition_id = v_id;
  else
    v_doc_no := public.next_doc_no(v_entity_id, 'REQ', v_business_date);
    v_status := 'draft';
    insert into public.requisitions (
      org_id, legal_entity_id, property_id, outlet_id,
      from_warehouse_id, to_warehouse_id, doc_no, business_date,
      status, note, created_by
    ) values (
      v_org_id, v_entity_id, v_property_id, v_outlet_id,
      v_from_wh, v_to_wh, v_doc_no, v_business_date,
      'draft', v_note, auth.uid()
    )
    returning id into v_id;
  end if;

  for v_line in
    select * from jsonb_array_elements(coalesce(v_doc -> 'lines', '[]'::jsonb))
  loop
    select * into v_item
    from public.items i
    where i.id = (v_line ->> 'item_id')::uuid and i.org_id = v_org_id;
    if not found or v_item.status = 'merged' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_uom := coalesce(nullif(v_line ->> 'uom', ''), v_item.stock_uom);
    v_qty_stock := public._po_line_qty_stock(
      v_org_id, v_item.id, v_uom, v_qty
    );
    insert into public.requisition_lines (
      requisition_id, org_id, property_id, item_id, uom,
      qty, qty_stock, note
    ) values (
      v_id, v_org_id, v_property_id, v_item.id, v_uom,
      v_qty, v_qty_stock, nullif(v_line ->> 'note', '')
    );
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no, 'status', v_status
  );
end;
$$;

revoke all on function public.requisition_save_draft(jsonb)
  from public, anon, authenticated;
grant execute on function public.requisition_save_draft(jsonb) to authenticated;

-- Gui duyet phieu linh: draft -> submitted + sinh buoc duyet theo
-- approval_rules (mac dinh 1 buoc outlet_head).
create or replace function public.requisition_submit(
  p_property_id uuid,
  p_requisition_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req public.requisitions%rowtype;
  v_total numeric(18,2) := 0;
  v_steps integer;
begin
  perform public.require_perm(p_property_id, 'requisition.create');

  select * into v_req
  from public.requisitions r where r.id = p_requisition_id;
  if not found or v_req.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_req.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if not exists (
    select 1 from public.requisition_lines rl
    where rl.requisition_id = p_requisition_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select coalesce(sum(
    rl.qty_stock * public._inventory_avg_cost(v_req.legal_entity_id, rl.item_id)
  ), 0)
  into v_total
  from public.requisition_lines rl
  where rl.requisition_id = p_requisition_id;

  perform set_config('app.pr_po_guard_bypass', 'on', true);
  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.requisitions
  set status = 'submitted' where id = p_requisition_id;

  v_steps := public._generate_approval_steps(
    'requisition', p_requisition_id, p_property_id, v_req.org_id, v_total
  );

  return jsonb_build_object(
    'ok', true, 'id', p_requisition_id, 'doc_no', v_req.doc_no,
    'status', 'submitted', 'steps', v_steps
  );
end;
$$;

revoke all on function public.requisition_submit(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.requisition_submit(uuid, uuid) to authenticated;

-- Duyet phieu linh qua co che duyet chung (giong pr_decide).
create or replace function public.requisition_decide(
  p_property_id uuid,
  p_requisition_id uuid,
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
    p_property_id, 'requisition', p_requisition_id, p_decision, p_comment
  );
end;
$$;

revoke all on function public.requisition_decide(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.requisition_decide(uuid, uuid, text, text) to authenticated;

-- Huy phieu linh khi chua xuat (draft/submitted/approved). Da xuat thi
-- phai nhan / tra lai qua dieu chuyen, khong huy ngang.
create or replace function public.requisition_cancel(
  p_property_id uuid,
  p_requisition_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req public.requisitions%rowtype;
begin
  perform public.require_perm(p_property_id, 'requisition.create');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_req
  from public.requisitions r where r.id = p_requisition_id;
  if not found or v_req.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_req.status not in ('draft', 'submitted', 'approved') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.requisitions
  set status = 'cancelled' where id = p_requisition_id;

  return jsonb_build_object(
    'ok', true, 'id', p_requisition_id, 'doc_no', v_req.doc_no,
    'status', 'cancelled'
  );
end;
$$;

revoke all on function public.requisition_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.requisition_cancel(uuid, uuid, text) to authenticated;

-- Kho xuat phieu linh: issue_out kho nguon -> issue_in kho transit (M05).
-- p_lines: [{line_id, qty_stock, lot_id?}]. Cho xuat tung phan, goi nhieu
-- lan cho den khi du. Ma track_lot bat buoc chon lo luc xuat.
create or replace function public.requisition_issue(
  p_requisition_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req public.requisitions%rowtype;
  v_transit_wh uuid;
  v_entry jsonb;
  v_line public.requisition_lines%rowtype;
  v_item public.items%rowtype;
  v_qty numeric(18,4);
  v_lot uuid;
begin
  select * into v_req
  from public.requisitions r where r.id = p_requisition_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(
    v_req.property_id, 'requisition.issue', v_req.from_warehouse_id
  );

  if v_req.status not in ('approved', 'issued') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_transit_wh := public._inventory_transit_wh(v_req.property_id);

  perform set_config('app.inventory_guard_bypass', 'on', true);

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb))
  loop
    select * into v_line
    from public.requisition_lines rl
    where rl.id = (v_entry ->> 'line_id')::uuid
      and rl.requisition_id = p_requisition_id;
    if not found then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_entry ->> 'qty_stock')::numeric(18,4);
    if v_qty is null or v_qty <= 0
      or v_qty > v_line.qty_stock - v_line.issued_qty_stock
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    select * into v_item
    from public.items i where i.id = v_line.item_id;
    v_lot := nullif(v_entry ->> 'lot_id', '')::uuid;
    if v_item.track_lot then
      if v_lot is null then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      if not exists (
        select 1 from public.lots l
        where l.id = v_lot
          and l.property_id = v_req.property_id
          and l.item_id = v_line.item_id
          and l.org_id = v_req.org_id
      ) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
    elsif v_lot is not null then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    perform public._post_move(
      v_req.legal_entity_id, v_req.property_id, v_req.from_warehouse_id,
      v_line.item_id, v_lot,
      'issue_out', -v_qty, null,
      v_req.business_date, 'requisition', p_requisition_id, v_line.id
    );
    perform public._post_move(
      v_req.legal_entity_id, v_req.property_id, v_transit_wh,
      v_line.item_id, v_lot,
      'issue_in', v_qty, null,
      v_req.business_date, 'requisition', p_requisition_id, v_line.id
    );

    update public.requisition_lines
    set issued_qty_stock = issued_qty_stock + v_qty,
        lot_id = v_lot
    where id = v_line.id;
  end loop;

  update public.requisitions
  set status = 'issued' where id = p_requisition_id;

  return jsonb_build_object(
    'ok', true, 'id', p_requisition_id, 'doc_no', v_req.doc_no,
    'status', 'issued'
  );
end;
$$;

revoke all on function public.requisition_issue(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.requisition_issue(uuid, jsonb) to authenticated;

-- Outlet xac nhan nhan: issue_out transit -> issue_in kho outlet theo so
-- thuc nhan (M05). Lecht thieu so voi da xuat -> bat buoc ghi chu lech
-- (discrepancy_note); phan thieu o lai transit cho xu ly sau.
create or replace function public.requisition_confirm_receipt(
  p_requisition_id uuid,
  p_lines jsonb,
  p_discrepancy_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req public.requisitions%rowtype;
  v_transit_wh uuid;
  v_entry jsonb;
  v_line public.requisition_lines%rowtype;
  v_qty numeric(18,4);
  v_short boolean := false;
  v_all_received boolean;
begin
  select * into v_req
  from public.requisitions r where r.id = p_requisition_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(
    v_req.property_id, 'requisition.receive', v_req.to_warehouse_id
  );

  if v_req.status not in ('issued', 'partially_received') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_transit_wh := public._inventory_transit_wh(v_req.property_id);

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb))
  loop
    select * into v_line
    from public.requisition_lines rl
    where rl.id = (v_entry ->> 'line_id')::uuid
      and rl.requisition_id = p_requisition_id;
    if not found then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_entry ->> 'qty_stock')::numeric(18,4);
    if v_qty is null or v_qty <= 0
      or v_qty > v_line.issued_qty_stock - v_line.received_qty_stock
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_line.received_qty_stock + v_qty < v_line.issued_qty_stock then
      v_short := true;
    end if;
  end loop;

  if v_short and (p_discrepancy_note is null or btrim(p_discrepancy_note) = '') then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb))
  loop
    select * into v_line
    from public.requisition_lines rl
    where rl.id = (v_entry ->> 'line_id')::uuid
      and rl.requisition_id = p_requisition_id;
    v_qty := (v_entry ->> 'qty_stock')::numeric(18,4);

    perform public._post_move(
      v_req.legal_entity_id, v_req.property_id, v_transit_wh,
      v_line.item_id, v_line.lot_id,
      'issue_out', -v_qty, null,
      v_req.business_date, 'requisition', p_requisition_id, v_line.id
    );
    perform public._post_move(
      v_req.legal_entity_id, v_req.property_id, v_req.to_warehouse_id,
      v_line.item_id, v_line.lot_id,
      'issue_in', v_qty, null,
      v_req.business_date, 'requisition', p_requisition_id, v_line.id
    );

    update public.requisition_lines
    set received_qty_stock = received_qty_stock + v_qty
    where id = v_line.id;
  end loop;

  select not exists (
    select 1 from public.requisition_lines rl
    where rl.requisition_id = p_requisition_id
      and rl.received_qty_stock < rl.issued_qty_stock
  ) into v_all_received;

  update public.requisitions
  set status = case when v_all_received then 'received' else 'partially_received' end,
      discrepancy_note = case
        when v_short then p_discrepancy_note
        else discrepancy_note
      end
  where id = p_requisition_id;

  return jsonb_build_object(
    'ok', true, 'id', p_requisition_id, 'doc_no', v_req.doc_no,
    'status', case when v_all_received then 'received' else 'partially_received' end
  );
end;
$$;

revoke all on function public.requisition_confirm_receipt(uuid, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.requisition_confirm_receipt(uuid, jsonb, text) to authenticated;

-- Danh sach phieu linh (loc trang thai + tim theo so chung tu/ghi chu).
create or replace function public.requisition_list(
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
    public.has_perm(p_property_id, 'requisition.create')
    or public.has_perm(p_property_id, 'requisition.approve')
    or public.has_perm(p_property_id, 'requisition.issue')
    or public.has_perm(p_property_id, 'requisition.receive')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      r.id, r.doc_no, r.status, r.business_date, r.note,
      r.outlet_id, o.name as outlet_name,
      r.from_warehouse_id, wf.name as from_warehouse_name,
      r.to_warehouse_id, wt.name as to_warehouse_name,
      r.created_by, r.created_at, r.updated_at,
      count(rl.id) as line_count,
      coalesce(sum(rl.qty_stock), 0) as total_qty_stock,
      coalesce(sum(rl.issued_qty_stock), 0) as total_issued_qty_stock,
      coalesce(sum(rl.received_qty_stock), 0) as total_received_qty_stock
    from public.requisitions r
    left join public.outlets o on o.id = r.outlet_id
    left join public.warehouses wf on wf.id = r.from_warehouse_id
    left join public.warehouses wt on wt.id = r.to_warehouse_id
    left join public.requisition_lines rl on rl.requisition_id = r.id
    where r.property_id = p_property_id
      and (p_status is null or r.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or r.doc_no ilike '%' || btrim(p_search) || '%'
        or r.note ilike '%' || btrim(p_search) || '%'
      )
    group by
      r.id, r.doc_no, r.status, r.business_date, r.note,
      r.outlet_id, o.name,
      r.from_warehouse_id, wf.name,
      r.to_warehouse_id, wt.name,
      r.created_by, r.created_at, r.updated_at
  )
  select jsonb_build_object(
    'rows', coalesce(jsonb_agg(f.* order by f.created_at desc), '[]'::jsonb),
    'total', (select count(*) from filtered)
  )
  into v_result
  from (select * from filtered order by created_at desc limit v_limit offset v_offset) f;

  return v_result;
end;
$$;

revoke all on function public.requisition_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.requisition_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet phieu linh + dong (chi so luong, khong gia von).
create or replace function public.requisition_get(
  p_requisition_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_req public.requisitions%rowtype;
  v_result jsonb;
begin
  select * into v_req
  from public.requisitions r where r.id = p_requisition_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_req.property_id, 'requisition.create')
    or public.has_perm(v_req.property_id, 'requisition.approve')
    or public.has_perm(v_req.property_id, 'requisition.issue')
    or public.has_perm(v_req.property_id, 'requisition.receive')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select jsonb_build_object(
    'id', r.id, 'doc_no', r.doc_no, 'status', r.status,
    'business_date', r.business_date, 'note', r.note,
    'discrepancy_note', r.discrepancy_note,
    'property_id', r.property_id,
    'outlet_id', r.outlet_id, 'outlet_name', o.name,
    'from_warehouse_id', r.from_warehouse_id, 'from_warehouse_name', wf.name,
    'to_warehouse_id', r.to_warehouse_id, 'to_warehouse_name', wt.name,
    'created_by', r.created_by, 'created_at', r.created_at,
    'updated_at', r.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', rl.id, 'item_id', rl.item_id, 'item_name', i.name,
          'uom', rl.uom, 'qty', rl.qty, 'qty_stock', rl.qty_stock,
          'issued_qty_stock', rl.issued_qty_stock,
          'received_qty_stock', rl.received_qty_stock,
          'lot_id', rl.lot_id, 'lot_no', l.lot_no, 'note', rl.note
        ) order by rl.created_at asc
      )
      from public.requisition_lines rl
      join public.items i on i.id = rl.item_id
      left join public.lots l on l.id = rl.lot_id
      where rl.requisition_id = r.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.requisitions r
  left join public.outlets o on o.id = r.outlet_id
  left join public.warehouses wf on wf.id = r.from_warehouse_id
  left join public.warehouses wt on wt.id = r.to_warehouse_id
  where r.id = p_requisition_id;

  return v_result;
end;
$$;

revoke all on function public.requisition_get(uuid)
  from public, anon, authenticated;
grant execute on function public.requisition_get(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 12. RPC dieu chuyen (trong cung khach san; khac phap nhan bi chan — Q27).
-- ---------------------------------------------------------------------------

-- Tao/sua phieu dieu chuyen nhap. p_transfer: {id?, property_id,
-- from_warehouse_id, to_warehouse_id, business_date?, note?,
-- lines: [{id?, item_id, qty, uom?, note?}]}. Chi sua duoc khi draft.
create or replace function public.transfer_save_draft(
  p_transfer jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_doc jsonb := p_transfer;
  v_id uuid := nullif(v_doc ->> 'id', '')::uuid;
  v_property_id uuid := (v_doc ->> 'property_id')::uuid;
  v_org_id uuid;
  v_entity_id uuid;
  v_from_wh uuid := (v_doc ->> 'from_warehouse_id')::uuid;
  v_to_wh uuid := (v_doc ->> 'to_warehouse_id')::uuid;
  v_business_date date := coalesce(
    nullif(v_doc ->> 'business_date', '')::date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_note text := nullif(v_doc ->> 'note', '');
  v_existing public.transfers%rowtype;
  v_line jsonb;
  v_item public.items%rowtype;
  v_uom text;
  v_qty numeric(18,4);
  v_qty_stock numeric(18,4);
  v_doc_no text;
begin
  if v_property_id is null or v_from_wh is null or v_to_wh is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_from_wh = v_to_wh then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_property_id, 'transfer.send');

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = v_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not exists (
    select 1 from public.warehouses w
    where w.id = v_from_wh and w.property_id = v_property_id
  ) or not exists (
    select 1 from public.warehouses w
    where w.id = v_to_wh and w.property_id = v_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  if v_id is not null then
    select * into v_existing
    from public.transfers t where t.id = v_id;
    if not found or v_existing.property_id <> v_property_id then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_existing.status <> 'draft' then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    v_doc_no := v_existing.doc_no;
    update public.transfers t
    set from_warehouse_id = v_from_wh,
        to_warehouse_id = v_to_wh,
        business_date = v_business_date,
        note = v_note
    where t.id = v_id;
    delete from public.transfer_lines tl
    where tl.transfer_id = v_id;
  else
    v_doc_no := public.next_doc_no(v_entity_id, 'TRF', v_business_date);
    insert into public.transfers (
      org_id, legal_entity_id, property_id,
      from_warehouse_id, to_warehouse_id, doc_no, business_date,
      status, note, created_by
    ) values (
      v_org_id, v_entity_id, v_property_id,
      v_from_wh, v_to_wh, v_doc_no, v_business_date,
      'draft', v_note, auth.uid()
    )
    returning id into v_id;
  end if;

  for v_line in
    select * from jsonb_array_elements(coalesce(v_doc -> 'lines', '[]'::jsonb))
  loop
    select * into v_item
    from public.items i
    where i.id = (v_line ->> 'item_id')::uuid and i.org_id = v_org_id;
    if not found or v_item.status = 'merged' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_uom := coalesce(nullif(v_line ->> 'uom', ''), v_item.stock_uom);
    v_qty_stock := public._po_line_qty_stock(
      v_org_id, v_item.id, v_uom, v_qty
    );
    insert into public.transfer_lines (
      transfer_id, org_id, property_id, item_id, uom,
      qty, qty_stock, note
    ) values (
      v_id, v_org_id, v_property_id, v_item.id, v_uom,
      v_qty, v_qty_stock, nullif(v_line ->> 'note', '')
    );
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no, 'status', 'draft'
  );
end;
$$;

revoke all on function public.transfer_save_draft(jsonb)
  from public, anon, authenticated;
grant execute on function public.transfer_save_draft(jsonb) to authenticated;

-- Gui dieu chuyen: transfer_out kho nguon -> transfer_in kho transit (M05).
-- p_lines: [{line_id, qty_stock, lot_id?}]. Cho gui tung phan.
create or replace function public.transfer_send(
  p_transfer_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_tr public.transfers%rowtype;
  v_transit_wh uuid;
  v_entry jsonb;
  v_line public.transfer_lines%rowtype;
  v_item public.items%rowtype;
  v_qty numeric(18,4);
  v_lot uuid;
begin
  select * into v_tr
  from public.transfers t where t.id = p_transfer_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(
    v_tr.property_id, 'transfer.send', v_tr.from_warehouse_id
  );

  if v_tr.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_transit_wh := public._inventory_transit_wh(v_tr.property_id);

  perform set_config('app.inventory_guard_bypass', 'on', true);

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb))
  loop
    select * into v_line
    from public.transfer_lines tl
    where tl.id = (v_entry ->> 'line_id')::uuid
      and tl.transfer_id = p_transfer_id;
    if not found then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_entry ->> 'qty_stock')::numeric(18,4);
    if v_qty is null or v_qty <= 0
      or v_qty > v_line.qty_stock - v_line.sent_qty_stock
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    select * into v_item
    from public.items i where i.id = v_line.item_id;
    v_lot := nullif(v_entry ->> 'lot_id', '')::uuid;
    if v_item.track_lot then
      if v_lot is null then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      if not exists (
        select 1 from public.lots l
        where l.id = v_lot
          and l.property_id = v_tr.property_id
          and l.item_id = v_line.item_id
          and l.org_id = v_tr.org_id
      ) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
    elsif v_lot is not null then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    perform public._post_move(
      v_tr.legal_entity_id, v_tr.property_id, v_tr.from_warehouse_id,
      v_line.item_id, v_lot,
      'transfer_out', -v_qty, null,
      v_tr.business_date, 'transfer', p_transfer_id, v_line.id
    );
    perform public._post_move(
      v_tr.legal_entity_id, v_tr.property_id, v_transit_wh,
      v_line.item_id, v_lot,
      'transfer_in', v_qty, null,
      v_tr.business_date, 'transfer', p_transfer_id, v_line.id
    );

    update public.transfer_lines
    set sent_qty_stock = sent_qty_stock + v_qty,
        lot_id = v_lot
    where id = v_line.id;
  end loop;

  update public.transfers
  set status = 'in_transit' where id = p_transfer_id;

  return jsonb_build_object(
    'ok', true, 'id', p_transfer_id, 'doc_no', v_tr.doc_no,
    'status', 'in_transit'
  );
end;
$$;

revoke all on function public.transfer_send(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.transfer_send(uuid, jsonb) to authenticated;

-- Kho dich xac nhan nhan: transfer_out transit -> transfer_in kho dich.
-- p_lines: [{line_id, qty_stock}]. Phan chua nhan o lai transit.
create or replace function public.transfer_receive(
  p_transfer_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_tr public.transfers%rowtype;
  v_transit_wh uuid;
  v_entry jsonb;
  v_line public.transfer_lines%rowtype;
  v_qty numeric(18,4);
  v_all_received boolean;
begin
  select * into v_tr
  from public.transfers t where t.id = p_transfer_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(
    v_tr.property_id, 'transfer.receive', v_tr.to_warehouse_id
  );

  if v_tr.status not in ('in_transit', 'partially_received') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_transit_wh := public._inventory_transit_wh(v_tr.property_id);

  perform set_config('app.inventory_guard_bypass', 'on', true);

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb))
  loop
    select * into v_line
    from public.transfer_lines tl
    where tl.id = (v_entry ->> 'line_id')::uuid
      and tl.transfer_id = p_transfer_id;
    if not found then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_entry ->> 'qty_stock')::numeric(18,4);
    if v_qty is null or v_qty <= 0
      or v_qty > v_line.sent_qty_stock - v_line.received_qty_stock
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    perform public._post_move(
      v_tr.legal_entity_id, v_tr.property_id, v_transit_wh,
      v_line.item_id, v_line.lot_id,
      'transfer_out', -v_qty, null,
      v_tr.business_date, 'transfer', p_transfer_id, v_line.id
    );
    perform public._post_move(
      v_tr.legal_entity_id, v_tr.property_id, v_tr.to_warehouse_id,
      v_line.item_id, v_line.lot_id,
      'transfer_in', v_qty, null,
      v_tr.business_date, 'transfer', p_transfer_id, v_line.id
    );

    update public.transfer_lines
    set received_qty_stock = received_qty_stock + v_qty
    where id = v_line.id;
  end loop;

  select not exists (
    select 1 from public.transfer_lines tl
    where tl.transfer_id = p_transfer_id
      and tl.received_qty_stock < tl.sent_qty_stock
  ) into v_all_received;

  update public.transfers
  set status = case when v_all_received then 'received' else 'partially_received' end
  where id = p_transfer_id;

  return jsonb_build_object(
    'ok', true, 'id', p_transfer_id, 'doc_no', v_tr.doc_no,
    'status', case when v_all_received then 'received' else 'partially_received' end
  );
end;
$$;

revoke all on function public.transfer_receive(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.transfer_receive(uuid, jsonb) to authenticated;

-- Huy phieu dieu chuyen khi con nhap (draft). Da gui thi phai nhan / chuyen
-- tra lai, khong huy ngang.
create or replace function public.transfer_cancel(
  p_property_id uuid,
  p_transfer_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_tr public.transfers%rowtype;
begin
  perform public.require_perm(p_property_id, 'transfer.send');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_tr
  from public.transfers t where t.id = p_transfer_id;
  if not found or v_tr.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_tr.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.transfers
  set status = 'cancelled' where id = p_transfer_id;

  return jsonb_build_object(
    'ok', true, 'id', p_transfer_id, 'doc_no', v_tr.doc_no,
    'status', 'cancelled'
  );
end;
$$;

revoke all on function public.transfer_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.transfer_cancel(uuid, uuid, text) to authenticated;

-- Danh sach phieu dieu chuyen.
create or replace function public.transfer_list(
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
    public.has_perm(p_property_id, 'transfer.send')
    or public.has_perm(p_property_id, 'transfer.receive')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      t.id, t.doc_no, t.status, t.business_date, t.note,
      t.from_warehouse_id, wf.name as from_warehouse_name,
      t.to_warehouse_id, wt.name as to_warehouse_name,
      t.created_by, t.created_at, t.updated_at,
      count(tl.id) as line_count,
      coalesce(sum(tl.qty_stock), 0) as total_qty_stock,
      coalesce(sum(tl.sent_qty_stock), 0) as total_sent_qty_stock,
      coalesce(sum(tl.received_qty_stock), 0) as total_received_qty_stock
    from public.transfers t
    left join public.warehouses wf on wf.id = t.from_warehouse_id
    left join public.warehouses wt on wt.id = t.to_warehouse_id
    left join public.transfer_lines tl on tl.transfer_id = t.id
    where t.property_id = p_property_id
      and (p_status is null or t.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or t.doc_no ilike '%' || btrim(p_search) || '%'
        or t.note ilike '%' || btrim(p_search) || '%'
      )
    group by
      t.id, t.doc_no, t.status, t.business_date, t.note,
      t.from_warehouse_id, wf.name,
      t.to_warehouse_id, wt.name,
      t.created_by, t.created_at, t.updated_at
  )
  select jsonb_build_object(
    'rows', coalesce(jsonb_agg(f.* order by f.created_at desc), '[]'::jsonb),
    'total', (select count(*) from filtered)
  )
  into v_result
  from (select * from filtered order by created_at desc limit v_limit offset v_offset) f;

  return v_result;
end;
$$;

revoke all on function public.transfer_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.transfer_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet phieu dieu chuyen + dong (chi so luong, khong gia von).
create or replace function public.transfer_get(
  p_transfer_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_tr public.transfers%rowtype;
  v_result jsonb;
begin
  select * into v_tr
  from public.transfers t where t.id = p_transfer_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_tr.property_id, 'transfer.send')
    or public.has_perm(v_tr.property_id, 'transfer.receive')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select jsonb_build_object(
    'id', t.id, 'doc_no', t.doc_no, 'status', t.status,
    'business_date', t.business_date, 'note', t.note,
    'property_id', t.property_id,
    'from_warehouse_id', t.from_warehouse_id, 'from_warehouse_name', wf.name,
    'to_warehouse_id', t.to_warehouse_id, 'to_warehouse_name', wt.name,
    'created_by', t.created_by, 'created_at', t.created_at,
    'updated_at', t.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', tl.id, 'item_id', tl.item_id, 'item_name', i.name,
          'uom', tl.uom, 'qty', tl.qty, 'qty_stock', tl.qty_stock,
          'sent_qty_stock', tl.sent_qty_stock,
          'received_qty_stock', tl.received_qty_stock,
          'lot_id', tl.lot_id, 'lot_no', l.lot_no, 'note', tl.note
        ) order by tl.created_at asc
      )
      from public.transfer_lines tl
      join public.items i on i.id = tl.item_id
      left join public.lots l on l.id = tl.lot_id
      where tl.transfer_id = t.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.transfers t
  left join public.warehouses wf on wf.id = t.from_warehouse_id
  left join public.warehouses wt on wt.id = t.to_warehouse_id
  where t.id = p_transfer_id;

  return v_result;
end;
$$;

revoke all on function public.transfer_get(uuid)
  from public, anon, authenticated;
grant execute on function public.transfer_get(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 13. RPC xuat theo muc dich (05 §5: bat buoc cost center + khoan muc,
--    khong tinh vao gia von hang ban).
-- ---------------------------------------------------------------------------

-- Tao/sua phieu xuat muc dich nhap. p_issue: {id?, property_id,
-- warehouse_id, purpose_code, cost_center_id?, expense_category_id?,
-- work_order_id?, business_date?, note?,
-- lines: [{id?, item_id, qty, uom?, lot_id?, note?}]}. Chi sua duoc khi draft.
create or replace function public.purpose_issue_save_draft(
  p_issue jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_doc jsonb := p_issue;
  v_id uuid := nullif(v_doc ->> 'id', '')::uuid;
  v_property_id uuid := (v_doc ->> 'property_id')::uuid;
  v_org_id uuid;
  v_entity_id uuid;
  v_warehouse_id uuid := (v_doc ->> 'warehouse_id')::uuid;
  v_purpose_code text := v_doc ->> 'purpose_code';
  v_cost_center_id uuid := nullif(v_doc ->> 'cost_center_id', '')::uuid;
  v_expense_category_id uuid := nullif(v_doc ->> 'expense_category_id', '')::uuid;
  v_work_order_id uuid := nullif(v_doc ->> 'work_order_id', '')::uuid;
  v_business_date date := coalesce(
    nullif(v_doc ->> 'business_date', '')::date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_note text := nullif(v_doc ->> 'note', '');
  v_existing public.purpose_issues%rowtype;
  v_line jsonb;
  v_item public.items%rowtype;
  v_uom text;
  v_qty numeric(18,4);
  v_qty_stock numeric(18,4);
  v_lot uuid;
  v_doc_no text;
begin
  if v_property_id is null or v_warehouse_id is null
    or v_purpose_code is null
    or v_purpose_code not in (
      'staff_meal', 'vip_comp', 'marketing', 'meeting', 'training', 'repair', 'other'
    )
  then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_property_id, 'purpose_issue.post');

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = v_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not exists (
    select 1 from public.warehouses w
    where w.id = v_warehouse_id and w.property_id = v_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_cost_center_id is not null and not exists (
    select 1 from public.cost_centers cc
    where cc.id = v_cost_center_id and cc.org_id = v_org_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_expense_category_id is not null and not exists (
    select 1 from public.expense_categories ec
    where ec.id = v_expense_category_id and ec.org_id = v_org_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  if v_id is not null then
    select * into v_existing
    from public.purpose_issues pi where pi.id = v_id;
    if not found or v_existing.property_id <> v_property_id then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_existing.status <> 'draft' then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    v_doc_no := v_existing.doc_no;
    update public.purpose_issues pi
    set warehouse_id = v_warehouse_id,
        purpose_code = v_purpose_code,
        cost_center_id = v_cost_center_id,
        expense_category_id = v_expense_category_id,
        work_order_id = v_work_order_id,
        business_date = v_business_date,
        note = v_note
    where pi.id = v_id;
    delete from public.purpose_issue_lines pil
    where pil.purpose_issue_id = v_id;
  else
    v_doc_no := public.next_doc_no(v_entity_id, 'PIS', v_business_date);
    insert into public.purpose_issues (
      org_id, legal_entity_id, property_id, warehouse_id,
      doc_no, business_date, status, purpose_code,
      cost_center_id, expense_category_id, work_order_id, note, created_by
    ) values (
      v_org_id, v_entity_id, v_property_id, v_warehouse_id,
      v_doc_no, v_business_date, 'draft', v_purpose_code,
      v_cost_center_id, v_expense_category_id, v_work_order_id, v_note, auth.uid()
    )
    returning id into v_id;
  end if;

  for v_line in
    select * from jsonb_array_elements(coalesce(v_doc -> 'lines', '[]'::jsonb))
  loop
    select * into v_item
    from public.items i
    where i.id = (v_line ->> 'item_id')::uuid and i.org_id = v_org_id;
    if not found or v_item.status = 'merged' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_uom := coalesce(nullif(v_line ->> 'uom', ''), v_item.stock_uom);
    v_qty_stock := public._po_line_qty_stock(
      v_org_id, v_item.id, v_uom, v_qty
    );
    v_lot := nullif(v_line ->> 'lot_id', '')::uuid;
    if v_lot is not null and not exists (
      select 1 from public.lots l
      where l.id = v_lot
        and l.property_id = v_property_id
        and l.item_id = v_item.id
        and l.org_id = v_org_id
    ) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    insert into public.purpose_issue_lines (
      purpose_issue_id, org_id, property_id, item_id, uom,
      qty, qty_stock, lot_id, note
    ) values (
      v_id, v_org_id, v_property_id, v_item.id, v_uom,
      v_qty, v_qty_stock, v_lot, nullif(v_line ->> 'note', '')
    );
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no, 'status', 'draft'
  );
end;
$$;

revoke all on function public.purpose_issue_save_draft(jsonb)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_save_draft(jsonb) to authenticated;

-- Ghi so xuat muc dich: move 'purpose_issue' theo gia binh quan, gan cost
-- center + khoan muc + purpose_code (05 §5). Khong can duyet.
create or replace function public.purpose_issue_post(
  p_issue_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pi public.purpose_issues%rowtype;
  v_line public.purpose_issue_lines%rowtype;
  v_item public.items%rowtype;
begin
  select * into v_pi
  from public.purpose_issues pi where pi.id = p_issue_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_pi.property_id, 'purpose_issue.post');

  if v_pi.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_pi.cost_center_id is null or v_pi.expense_category_id is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if not exists (
    select 1 from public.purpose_issue_lines pil
    where pil.purpose_issue_id = p_issue_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  for v_line in
    select * from public.purpose_issue_lines pil
    where pil.purpose_issue_id = p_issue_id
    order by pil.created_at asc
  loop
    select * into v_item
    from public.items i where i.id = v_line.item_id;
    if v_item.track_lot and v_line.lot_id is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    perform public._post_move(
      v_pi.legal_entity_id, v_pi.property_id, v_pi.warehouse_id,
      v_line.item_id, v_line.lot_id,
      'purpose_issue', -v_line.qty_stock, null,
      v_pi.business_date, 'purpose_issue', p_issue_id, v_line.id,
      v_pi.cost_center_id, v_pi.expense_category_id, v_pi.purpose_code
    );
  end loop;

  update public.purpose_issues
  set status = 'posted' where id = p_issue_id;

  return jsonb_build_object(
    'ok', true, 'id', p_issue_id, 'doc_no', v_pi.doc_no, 'status', 'posted'
  );
end;
$$;

revoke all on function public.purpose_issue_post(uuid)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_post(uuid) to authenticated;

-- Huy phieu xuat muc dich khi con nhap.
create or replace function public.purpose_issue_cancel(
  p_property_id uuid,
  p_issue_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pi public.purpose_issues%rowtype;
begin
  perform public.require_perm(p_property_id, 'purpose_issue.post');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_pi
  from public.purpose_issues pi where pi.id = p_issue_id;
  if not found or v_pi.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_pi.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.purpose_issues
  set status = 'cancelled' where id = p_issue_id;

  return jsonb_build_object(
    'ok', true, 'id', p_issue_id, 'doc_no', v_pi.doc_no, 'status', 'cancelled'
  );
end;
$$;

revoke all on function public.purpose_issue_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_cancel(uuid, uuid, text) to authenticated;

-- Dao phieu xuat muc dich da ghi so (chi gm, ma purpose_issue.reverse):
-- ghi move 'reversal' dao tung move goc, khong xoa so cai.
create or replace function public.purpose_issue_reverse(
  p_property_id uuid,
  p_issue_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pi public.purpose_issues%rowtype;
  v_move public.stock_moves%rowtype;
begin
  perform public.require_perm(p_property_id, 'purpose_issue.reverse');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_pi
  from public.purpose_issues pi where pi.id = p_issue_id;
  if not found or v_pi.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_pi.status <> 'posted' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  for v_move in
    select * from public.stock_moves sm
    where sm.source_doc_type = 'purpose_issue'
      and sm.source_doc_id = p_issue_id
      and sm.move_type = 'purpose_issue'
    order by sm.id asc
  loop
    perform public._post_move(
      v_move.legal_entity_id, v_move.property_id, v_move.warehouse_id,
      v_move.item_id, v_move.lot_id,
      'reversal', -v_move.qty, v_move.unit_cost,
      v_pi.business_date, 'purpose_issue', p_issue_id, v_move.source_line_id,
      v_move.cost_center_id, v_move.expense_category_id, v_move.purpose_code,
      v_move.id
    );
  end loop;

  update public.purpose_issues
  set status = 'reversed' where id = p_issue_id;

  return jsonb_build_object(
    'ok', true, 'id', p_issue_id, 'doc_no', v_pi.doc_no, 'status', 'reversed'
  );
end;
$$;

revoke all on function public.purpose_issue_reverse(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_reverse(uuid, uuid, text) to authenticated;

-- Danh sach phieu xuat muc dich.
create or replace function public.purpose_issue_list(
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
    public.has_perm(p_property_id, 'purpose_issue.post')
    or public.has_perm(p_property_id, 'purpose_issue.reverse')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      pi.id, pi.doc_no, pi.status, pi.business_date, pi.note,
      pi.purpose_code, pi.warehouse_id, w.name as warehouse_name,
      pi.cost_center_id, cc.name as cost_center_name,
      pi.expense_category_id, ec.name as expense_category_name,
      pi.created_by, pi.created_at, pi.updated_at,
      count(pil.id) as line_count,
      coalesce(sum(pil.qty_stock), 0) as total_qty_stock
    from public.purpose_issues pi
    left join public.warehouses w on w.id = pi.warehouse_id
    left join public.cost_centers cc on cc.id = pi.cost_center_id
    left join public.expense_categories ec on ec.id = pi.expense_category_id
    left join public.purpose_issue_lines pil on pil.purpose_issue_id = pi.id
    where pi.property_id = p_property_id
      and (p_status is null or pi.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or pi.doc_no ilike '%' || btrim(p_search) || '%'
        or pi.note ilike '%' || btrim(p_search) || '%'
      )
    group by
      pi.id, pi.doc_no, pi.status, pi.business_date, pi.note,
      pi.purpose_code, pi.warehouse_id, w.name,
      pi.cost_center_id, cc.name,
      pi.expense_category_id, ec.name,
      pi.created_by, pi.created_at, pi.updated_at
  )
  select jsonb_build_object(
    'rows', coalesce(jsonb_agg(f.* order by f.created_at desc), '[]'::jsonb),
    'total', (select count(*) from filtered)
  )
  into v_result
  from (select * from filtered order by created_at desc limit v_limit offset v_offset) f;

  return v_result;
end;
$$;

revoke all on function public.purpose_issue_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet phieu xuat muc dich + dong (gia von chi hien khi co stock.view_value).
create or replace function public.purpose_issue_get(
  p_issue_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pi public.purpose_issues%rowtype;
  v_show_value boolean;
  v_result jsonb;
begin
  select * into v_pi
  from public.purpose_issues pi where pi.id = p_issue_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_pi.property_id, 'purpose_issue.post')
    or public.has_perm(v_pi.property_id, 'purpose_issue.reverse')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  v_show_value := public.has_perm(v_pi.property_id, 'stock.view_value');

  select jsonb_build_object(
    'id', pi.id, 'doc_no', pi.doc_no, 'status', pi.status,
    'business_date', pi.business_date, 'note', pi.note,
    'property_id', pi.property_id,
    'warehouse_id', pi.warehouse_id, 'warehouse_name', w.name,
    'purpose_code', pi.purpose_code,
    'cost_center_id', pi.cost_center_id, 'cost_center_name', cc.name,
    'expense_category_id', pi.expense_category_id,
    'expense_category_name', ec.name,
    'work_order_id', pi.work_order_id,
    'created_by', pi.created_by, 'created_at', pi.created_at,
    'updated_at', pi.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', pil.id, 'item_id', pil.item_id, 'item_name', i.name,
          'uom', pil.uom, 'qty', pil.qty, 'qty_stock', pil.qty_stock,
          'lot_id', pil.lot_id, 'lot_no', l.lot_no, 'note', pil.note,
          'unit_cost', case when v_show_value then sm.unit_cost else null end,
          'line_amount', case when v_show_value then sm.amount else null end
        ) order by pil.created_at asc
      )
      from public.purpose_issue_lines pil
      join public.items i on i.id = pil.item_id
      left join public.lots l on l.id = pil.lot_id
      left join public.stock_moves sm
        on sm.source_doc_type = 'purpose_issue'
        and sm.source_doc_id = pi.id
        and sm.source_line_id = pil.id
        and sm.move_type = 'purpose_issue'
      where pil.purpose_issue_id = pi.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.purpose_issues pi
  left join public.warehouses w on w.id = pi.warehouse_id
  left join public.cost_centers cc on cc.id = pi.cost_center_id
  left join public.expense_categories ec on ec.id = pi.expense_category_id
  where pi.id = p_issue_id;

  return v_result;
end;
$$;

revoke all on function public.purpose_issue_get(uuid)
  from public, anon, authenticated;
grant execute on function public.purpose_issue_get(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 14. RPC huy hang (05 §5 + M05: de xuat anh + ly do -> nguoi khac duyet;
--    vuot nguong them gm).
-- ---------------------------------------------------------------------------

-- Tao/sua phieu huy nhap. p_waste: {id?, property_id, warehouse_id,
-- reason_code, photo_ids?, business_date?, note?,
-- lines: [{id?, item_id, lot_id?, qty_stock, note?}]}. Chi sua duoc khi draft.
create or replace function public.waste_save_draft(
  p_waste jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_doc jsonb := p_waste;
  v_id uuid := nullif(v_doc ->> 'id', '')::uuid;
  v_property_id uuid := (v_doc ->> 'property_id')::uuid;
  v_org_id uuid;
  v_entity_id uuid;
  v_warehouse_id uuid := (v_doc ->> 'warehouse_id')::uuid;
  v_reason_code text := v_doc ->> 'reason_code';
  v_photo_ids uuid[] := coalesce(
    (select array_agg((x)::uuid) from jsonb_array_elements_text(coalesce(v_doc -> 'photo_ids', '[]'::jsonb)) as x),
    '{}'::uuid[]
  );
  v_business_date date := coalesce(
    nullif(v_doc ->> 'business_date', '')::date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_note text := nullif(v_doc ->> 'note', '');
  v_existing public.waste_reports%rowtype;
  v_line jsonb;
  v_item public.items%rowtype;
  v_qty_stock numeric(18,4);
  v_lot uuid;
  v_photo uuid;
  v_doc_no text;
begin
  if v_property_id is null or v_warehouse_id is null
    or v_reason_code is null
    or v_reason_code not in (
      'expired', 'spoiled_storage', 'broken', 'guest_return', 'other'
    )
  then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_property_id, 'waste.propose');

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = v_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not exists (
    select 1 from public.warehouses w
    where w.id = v_warehouse_id and w.property_id = v_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  foreach v_photo in array v_photo_ids loop
    if not exists (
      select 1 from public.attachments a
      where a.id = v_photo and a.property_id = v_property_id
    ) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
  end loop;

  perform set_config('app.inventory_guard_bypass', 'on', true);

  if v_id is not null then
    select * into v_existing
    from public.waste_reports wr where wr.id = v_id;
    if not found or v_existing.property_id <> v_property_id then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_existing.status <> 'draft' then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    v_doc_no := v_existing.doc_no;
    update public.waste_reports wr
    set warehouse_id = v_warehouse_id,
        reason_code = v_reason_code,
        photo_ids = v_photo_ids,
        business_date = v_business_date,
        note = v_note
    where wr.id = v_id;
    delete from public.waste_report_lines wrl
    where wrl.waste_report_id = v_id;
  else
    v_doc_no := public.next_doc_no(v_entity_id, 'WST', v_business_date);
    insert into public.waste_reports (
      org_id, legal_entity_id, property_id, warehouse_id,
      doc_no, business_date, status, reason_code, photo_ids,
      note, created_by, proposed_by
    ) values (
      v_org_id, v_entity_id, v_property_id, v_warehouse_id,
      v_doc_no, v_business_date, 'draft', v_reason_code, v_photo_ids,
      v_note, auth.uid(), auth.uid()
    )
    returning id into v_id;
  end if;

  for v_line in
    select * from jsonb_array_elements(coalesce(v_doc -> 'lines', '[]'::jsonb))
  loop
    select * into v_item
    from public.items i
    where i.id = (v_line ->> 'item_id')::uuid and i.org_id = v_org_id;
    if not found or v_item.status = 'merged' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_qty_stock := (v_line ->> 'qty_stock')::numeric(18,4);
    if v_qty_stock is null or v_qty_stock <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_lot := nullif(v_line ->> 'lot_id', '')::uuid;
    if v_lot is not null and not exists (
      select 1 from public.lots l
      where l.id = v_lot
        and l.property_id = v_property_id
        and l.item_id = v_item.id
        and l.org_id = v_org_id
    ) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    insert into public.waste_report_lines (
      waste_report_id, org_id, property_id, item_id, lot_id,
      qty_stock, note
    ) values (
      v_id, v_org_id, v_property_id, v_item.id, v_lot,
      v_qty_stock, nullif(v_line ->> 'note', '')
    );
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no, 'status', 'draft'
  );
end;
$$;

revoke all on function public.waste_save_draft(jsonb)
  from public, anon, authenticated;
grant execute on function public.waste_save_draft(jsonb) to authenticated;

-- Gui duyet phieu huy: draft -> submitted + sinh buoc duyet theo
-- approval_rules (mac dinh 1 buoc cost_controller). Vuot nguong
-- waste_approval_threshold_vnd [cau hinh] them buoc gm (waste.approve.large)
-- + alert WASTE_LARGE.
create or replace function public.waste_submit(
  p_property_id uuid,
  p_waste_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wr public.waste_reports%rowtype;
  v_total numeric(18,2) := 0;
  v_threshold numeric(18,2);
  v_steps integer;
begin
  perform public.require_perm(p_property_id, 'waste.propose');

  select * into v_wr
  from public.waste_reports wr where wr.id = p_waste_id;
  if not found or v_wr.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_wr.status <> 'draft' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if not exists (
    select 1 from public.waste_report_lines wrl
    where wrl.waste_report_id = p_waste_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if coalesce(array_length(v_wr.photo_ids, 1), 0) = 0 then
    raise exception 'ERR_PHOTO_REQUIRED';
  end if;
  if exists (
    select 1
    from public.waste_report_lines wrl
    join public.items i on i.id = wrl.item_id
    where wrl.waste_report_id = p_waste_id
      and i.track_lot and wrl.lot_id is null
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select coalesce(sum(
    wrl.qty_stock * public._inventory_avg_cost(v_wr.legal_entity_id, wrl.item_id)
  ), 0)
  into v_total
  from public.waste_report_lines wrl
  where wrl.waste_report_id = p_waste_id;

  v_threshold := (
    public._setting_get(v_wr.org_id, p_property_id, 'waste_approval_threshold_vnd')
  )::numeric;

  perform set_config('app.pr_po_guard_bypass', 'on', true);
  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.waste_reports
  set status = 'submitted', total_value = v_total
  where id = p_waste_id;

  v_steps := public._generate_approval_steps(
    'waste', p_waste_id, p_property_id, v_wr.org_id, v_total
  );

  if v_total > v_threshold then
    insert into public.approvals (
      org_id, property_id, doc_type, doc_id, step,
      approver_role_id, approver_user_id, required_perm, decision
    )
    select
      v_wr.org_id,
      p_property_id,
      'waste',
      p_waste_id,
      coalesce((select max(step) from public.approvals where doc_type = 'waste' and doc_id = p_waste_id), 0) + 1,
      r.id,
      null,
      'waste.approve.large',
      'pending'
    from public.roles r
    where r.org_id = v_wr.org_id and r.code = 'gm';
    v_steps := v_steps + 1;

    perform public._create_alert(
      p_property_id,
      'WASTE_LARGE',
      'warn',
      'Phiếu hủy vượt ngưỡng duyệt',
      jsonb_build_object('doc_no', v_wr.doc_no, 'total_value', v_total, 'threshold', v_threshold),
      'waste',
      p_waste_id
    );
  end if;

  return jsonb_build_object(
    'ok', true, 'id', p_waste_id, 'doc_no', v_wr.doc_no,
    'status', 'submitted', 'steps', v_steps,
    'total_value', v_total
  );
end;
$$;

revoke all on function public.waste_submit(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.waste_submit(uuid, uuid) to authenticated;

-- Duyet phieu huy qua co che duyet chung (giong pr_decide). Duyet du buoc
-- thi _decide_approval ghi so move 'waste' + status 'posted'.
create or replace function public.waste_decide(
  p_property_id uuid,
  p_waste_id uuid,
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
    p_property_id, 'waste', p_waste_id, p_decision, p_comment
  );
end;
$$;

revoke all on function public.waste_decide(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.waste_decide(uuid, uuid, text, text) to authenticated;

-- Huy phieu huy khi chua ghi so (draft/submitted).
create or replace function public.waste_cancel(
  p_property_id uuid,
  p_waste_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wr public.waste_reports%rowtype;
begin
  perform public.require_perm(p_property_id, 'waste.propose');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  select * into v_wr
  from public.waste_reports wr where wr.id = p_waste_id;
  if not found or v_wr.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_wr.status not in ('draft', 'submitted') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.inventory_guard_bypass', 'on', true);
  update public.waste_reports
  set status = 'cancelled' where id = p_waste_id;

  return jsonb_build_object(
    'ok', true, 'id', p_waste_id, 'doc_no', v_wr.doc_no, 'status', 'cancelled'
  );
end;
$$;

revoke all on function public.waste_cancel(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.waste_cancel(uuid, uuid, text) to authenticated;

-- Danh sach phieu huy (gia tri chi hien khi co stock.view_value).
create or replace function public.waste_list(
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
  v_show_value boolean;
begin
  if not (
    public.has_perm(p_property_id, 'waste.propose')
    or public.has_perm(p_property_id, 'waste.approve')
    or public.has_perm(p_property_id, 'waste.approve.large')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  v_show_value := public.has_perm(p_property_id, 'stock.view_value');

  with filtered as (
    select
      wr.id, wr.doc_no, wr.status, wr.business_date, wr.note,
      wr.reason_code, wr.warehouse_id, w.name as warehouse_name,
      case when v_show_value then wr.total_value else null end as total_value,
      wr.proposed_by, wr.approved_by,
      wr.created_by, wr.created_at, wr.updated_at,
      count(wrl.id) as line_count,
      coalesce(sum(wrl.qty_stock), 0) as total_qty_stock
    from public.waste_reports wr
    left join public.warehouses w on w.id = wr.warehouse_id
    left join public.waste_report_lines wrl on wrl.waste_report_id = wr.id
    where wr.property_id = p_property_id
      and (p_status is null or wr.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or wr.doc_no ilike '%' || btrim(p_search) || '%'
        or wr.note ilike '%' || btrim(p_search) || '%'
      )
    group by
      wr.id, wr.doc_no, wr.status, wr.business_date, wr.note,
      wr.reason_code, wr.warehouse_id, w.name,
      wr.total_value, wr.proposed_by, wr.approved_by,
      wr.created_by, wr.created_at, wr.updated_at
  )
  select jsonb_build_object(
    'rows', coalesce(jsonb_agg(f.* order by f.created_at desc), '[]'::jsonb),
    'total', (select count(*) from filtered)
  )
  into v_result
  from (select * from filtered order by created_at desc limit v_limit offset v_offset) f;

  return v_result;
end;
$$;

revoke all on function public.waste_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.waste_list(uuid, text, text, integer, integer) to authenticated;

-- Chi tiet phieu huy + dong (gia von chi hien khi co stock.view_value).
create or replace function public.waste_get(
  p_waste_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wr public.waste_reports%rowtype;
  v_show_value boolean;
  v_result jsonb;
begin
  select * into v_wr
  from public.waste_reports wr where wr.id = p_waste_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_wr.property_id, 'waste.propose')
    or public.has_perm(v_wr.property_id, 'waste.approve')
    or public.has_perm(v_wr.property_id, 'waste.approve.large')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  v_show_value := public.has_perm(v_wr.property_id, 'stock.view_value');

  select jsonb_build_object(
    'id', wr.id, 'doc_no', wr.doc_no, 'status', wr.status,
    'business_date', wr.business_date, 'note', wr.note,
    'property_id', wr.property_id,
    'warehouse_id', wr.warehouse_id, 'warehouse_name', w.name,
    'reason_code', wr.reason_code,
    'photo_ids', wr.photo_ids,
    'total_value', case when v_show_value then wr.total_value else null end,
    'proposed_by', wr.proposed_by, 'approved_by', wr.approved_by,
    'created_by', wr.created_by, 'created_at', wr.created_at,
    'updated_at', wr.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', wrl.id, 'item_id', wrl.item_id, 'item_name', i.name,
          'lot_id', wrl.lot_id, 'lot_no', l.lot_no,
          'qty_stock', wrl.qty_stock, 'note', wrl.note,
          'unit_cost', case when v_show_value then wrl.unit_cost else null end,
          'line_amount', case when v_show_value
            then round(wrl.qty_stock * wrl.unit_cost, 2) else null end
        ) order by wrl.created_at asc
      )
      from public.waste_report_lines wrl
      join public.items i on i.id = wrl.item_id
      left join public.lots l on l.id = wrl.lot_id
      where wrl.waste_report_id = wr.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.waste_reports wr
  left join public.warehouses w on w.id = wr.warehouse_id
  where wr.id = p_waste_id;

  return v_result;
end;
$$;

revoke all on function public.waste_get(uuid)
  from public, anon, authenticated;
grant execute on function public.waste_get(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 15. Seed ma tran duyet mac dinh (05 §2, M05) cho moi org hien co:
--     phieu linh 1 buoc outlet_head; huy hang 1 buoc cost_controller
--     (buoc gm vuot nguong sinh dong luc submit).
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
      ('requisition', 0::numeric(18,2), null::numeric(18,2), 1, 'outlet_head', 'requisition.approve'),
      ('waste', 0::numeric(18,2), null::numeric(18,2), 1, 'cost_controller', 'waste.approve')
    ) as v (doc_type, min_amount, max_amount, step, role_code, required_perm)
    join public.roles r
      on r.org_id = v_org.id and r.code = v.role_code
    on conflict do nothing;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 16. Gan quyen cho vai tro mau (join theo ma vai tro; chi grant owner ma
--     quyen THAT SU MOI cua migration nay: purpose_issue.reverse).
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('storekeeper', 'purpose_issue.post'),
  ('gm', 'purpose_issue.post'),
  ('outlet_head', 'purpose_issue.post'),
  ('chef', 'purpose_issue.post'),
  ('gm', 'purpose_issue.reverse'),
  ('owner', 'purpose_issue.reverse'),
  ('gm', 'alert.receive.waste_large'),
  ('chief_accountant', 'alert.receive.waste_large'),
  ('cost_controller', 'alert.receive.waste_large')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109260000_inventory_issues',
  'INSERT',
  jsonb_build_object('event', 'inventory_issues_created', 'task', 'T-030'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
