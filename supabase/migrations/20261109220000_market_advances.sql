-- 20261109220000_market_advances.sql
--
-- T-022: Lenh mua cho + tam ung (market_order_create, advance_request /
-- advance_decide / advance_disburse, advance_overdue_maintenance + pg_cron).
-- AC: co tam ung qua han -> ERR_ADVANCE_OVERDUE_BLOCK.
--
-- Can cu: docs/03-DATA-MODEL.md A9 (advances), docs/05-BUSINESS-RULES.md
-- §4 (mua cho & tam ung; han quyet toan 24h cau hinh
-- market_advance_deadline_hours), docs/09-API-RPC.md §2 + §7
-- (market_order_create; advance_request/decide/disburse/settle) + §11
-- (ERR_ADVANCE_OVERDUE_BLOCK), docs/04-SECURITY-RLS.md (advance.request /
-- advance.approve / advance.disburse / advance.settle,
-- market.order.create; SOD_MARKET_BUYER_RECEIVER),
-- docs/modules/M03-procurement.md (luong mua cho),
-- docs/08-REPORTS-ALERTS.md (ADVANCE_OVERDUE).
--
-- Quyet dinh khi dac ta im lang / mo (ghi ro de Duy chot lai neu sai):
--  1. supplier_id tren purchase_orders thanh NULL duoc (alter column o
--     migration MOI nay, khong sua file 210000): lenh mua cho khong co NCC
--     dang ky; ten/dia chi nguoi ban ghi o bang ke khong hoa don (T-040).
--     po_list viet lai o muc 2 (LEFT JOIN suppliers) de PO cho hien trong
--     danh sach; po_get da null-safe (select into khong co dong -> NULL).
--  2. market_order_create tao PO market (draft, supplier null, kind stock)
--     + advances requested trong 1 giao dich; employee_id = nguoi goi
--     (nguoi di cho). advance_amount chi can > 0, khong bat buoc bang tong
--     PO (tien mat ung tron; quyet toan theo thuc nhan o T-040).
--  3. Gia dong cho: unit_price nguoi goi dua -> price_source 'manual' +
--     so gia tran de danh over_ceiling; khong dua -> giai quyet nhu
--     po_create_from_pr qua _po_resolve_line_price voi supplier null
--     (hop dong bo qua vi khong co NCC, gia tran -> manual 0). po_submit
--     sau do ap dung luat chung (manual chua gia -> ERR_PRICE_NOT_SET;
--     vuot tran thieu ly do -> ERR_OVER_CEILING_NO_REASON + them buoc gm).
--  4. Duyet 2 lop doc lap: PO duyet theo ma tran chuan qua po_submit
--     (khong co rule rieng cho cho); tien mat duyet rieng qua
--     advance_decide boi nguoi co advance.approve (gm theo vai tro mau) —
--     "gm duyet" o M03 la buoc nay.
--  5. advance_disburse yeu cau PO lien ket (neu co) da o trang thai
--     approved/sent/partially_received/received — khong chi tien cho PO
--     nhap/cho duyet/bi huy. Tam ung doc lap (advance_request, khong gan
--     PO) thi bo qua kiem tra nay.
--  6. advance_decide: SoD nguoi de nghi != nguoi duyet (mo ta quyen
--     advance.approve), ma moi SOD_ADVANCE_APPROVER qua _sod_check (tien
--     le T-020 voi SOD_PR_CREATOR_APPROVER, cung khong co trong
--     04-SECURITY-RLS.md). Tu choi bat buoc co ly do (ERR_REASON_REQUIRED).
--  7. Qua han tinh theo due_settle_at = disbursed_at +
--     market_advance_deadline_hours (mac dinh 24h, doc qua _setting_get
--     3 tang). Kiem tra chan (advance_request, market_order_create) tinh
--     truc tiep (status = 'overdue' hoac disbursed/settling ma
--     due_settle_at < now()) nen khong phu thuoc cron da chay;
--     advance_overdue_maintenance chi dong bo status + tao alert
--     ADVANCE_OVERDUE (dedupe theo alert chua ack).
--  8. advance_settle + bang advance_settlements thuoc T-040 (roadmap ghi
--     "quyet toan tam ung" o T-040); T-022 chi tao bang advances voi du
--     trang thai settling/settled de T-040 dung tiep. Khong co RPC
--     advance_cancel: tam ung requested cua PO cho da huy thi gm tu choi
--     qua advance_decide (xem Q19).
--  9. Khong them ma quyen moi: market.order.create, advance.request /
--     approve / disburse / settle da co trong danh muc (20261108141000)
--     va da gan vai tro mau trong seed (purchaser: market.order.create +
--     advance.request; gm: advance.approve; accountant: advance.disburse
--     + advance.settle; owner da co du — theo hieu chinh Q17). Chi gan
--     them alert.receive.advance_overdue (da co ma trong danh muc, chua
--     gan vai tro nao) cho gm/chief_accountant/cost_controller theo mau
--     T-015.
-- 10. advance_id tren purchase_orders: them FK composite (advance_id,
--     org_id) -> advances(id, org_id) bang migration MOI nay (bang
--     advances tao o muc 1, truoc lenh ALTER).
-- 11. po_send cho PO cho van chay duoc ve ky thuat (khong chan) nhung UI
--     T-022 khong hien nut "Gui NCC" voi PO cho (khong co NCC de gui);
--     nhan hang (T-023) can coi PO cho approved la du dieu kien nhan,
--     khong doi 'sent' (xem Q20).

-- ---------------------------------------------------------------------------
-- 1. Bang advances (03-DATA-MODEL.md A9) + RLS + guard + FK tu PO.
-- ---------------------------------------------------------------------------
create table public.advances (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  employee_id uuid not null references auth.users(id),
  doc_no text not null,
  amount numeric(18,2) not null check (amount > 0),
  purpose text not null check (btrim(purpose) <> ''),
  status text not null default 'requested'
    check (status in ('requested', 'approved', 'rejected', 'disbursed', 'settling', 'settled', 'overdue')),
  requested_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decide_reason text,
  disbursed_at timestamptz,
  disbursed_note text,
  due_settle_at timestamptz,
  settled_at timestamptz,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (legal_entity_id, doc_no),
  unique (id, org_id),
  unique (id, property_id)
);

create index advances_employee_idx on public.advances (employee_id, status, due_settle_at);
create index advances_property_idx on public.advances (property_id, status, created_at desc);

-- RLS: chi SELECT qua policy (ghi chi qua RPC SECURITY DEFINER), mau T-020.
alter table public.advances enable row level security;
revoke all on table public.advances from public, anon, authenticated;
grant select on table public.advances to authenticated;
create trigger trg_advances_updated_at
  before update on public.advances
  for each row execute function public.set_updated_at();
create trigger trg_advances_audit
  after insert or update or delete on public.advances
  for each row execute function public.audit_trigger();

create policy advances_select on public.advances
  for select to authenticated
  using (
    property_id in (select public.my_property_ids())
    and (
      public.has_perm(property_id, 'advance.request')
      or public.has_perm(property_id, 'advance.approve')
      or public.has_perm(property_id, 'advance.disburse')
      or public.has_perm(property_id, 'advance.settle')
    )
  );

-- Guard chan ghi truc tiep (mau _pr_po_write_guard, T-020): chi RPC moi
-- duoc ghi, bang cach bat co transaction-local 'app.advance_guard_bypass'.
create or replace function public._advance_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.advance_guard_bypass', true), '') <> 'on' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public._advance_write_guard()
  from public, anon, authenticated;

drop trigger if exists trg_advances_write_guard on public.advances;
create trigger trg_advances_write_guard
before insert or update or delete on public.advances
for each row execute function public._advance_write_guard();

-- FK tu PO sang tam ung (T-020 de trong advance_id, chua FK).
alter table public.purchase_orders
  add constraint purchase_orders_advance_id_fkey
  foreign key (advance_id, org_id) references public.advances(id, org_id);

-- Lenh mua cho khong co NCC dang ky -> supplier_id duoc NULL (quyet dinh 1).
alter table public.purchase_orders
  alter column supplier_id drop not null;

-- ---------------------------------------------------------------------------
-- 2. Viet lai po_list: LEFT JOIN suppliers (quyet dinh 1). PO cho co
--    supplier_id NULL phai hien trong danh sach; ban goc dung JOIN trong
--    nen PO cho se bien mat. Chi doi cho join, giu nguyen chu ky + loc.
-- ---------------------------------------------------------------------------
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
    left join public.suppliers s on s.id = po.supplier_id
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

-- ---------------------------------------------------------------------------
-- 3. Helper noi bo: han quyet toan (gio) + kiem tra tam ung qua han.
-- ---------------------------------------------------------------------------
-- Han quyet toan theo cau hinh market_advance_deadline_hours (mac dinh
-- 24h, _admin_setting_default). Doc qua _setting_get 3 tang (KS -> chuoi
-- -> mac dinh), giong admin_setting_get.
create or replace function public._advance_deadline_hours(
  p_org_id uuid,
  p_property_id uuid
)
returns numeric
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_value jsonb;
begin
  v_value := public._setting_get(p_org_id, p_property_id, 'market_advance_deadline_hours');
  if v_value is null then
    return 24;
  end if;
  return greatest(1, (v_value::text)::numeric);
exception
  when others then
    return 24;
end;
$$;

revoke all on function public._advance_deadline_hours(uuid, uuid)
  from public, anon, authenticated;

-- Co tam ung qua han khong? Tinh truc tiep (khong phu thuoc cron):
-- status 'overdue', hoac disbursed/settling ma due_settle_at da qua.
create or replace function public._advance_has_overdue(
  p_employee_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1 from public.advances a
    where a.employee_id = p_employee_id
      and (
        a.status = 'overdue'
        or (
          a.status in ('disbursed', 'settling')
          and a.due_settle_at is not null
          and a.due_settle_at < now()
        )
      )
  );
$$;

revoke all on function public._advance_has_overdue(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC ghi: lenh mua cho + tam ung.
-- ---------------------------------------------------------------------------

-- Tao PO market + tam ung requested trong 1 giao dich (09-API-RPC §2).
-- p_lines: [{item_id?, description?, qty, uom, unit_price?,
--   expense_category_id?, cost_center_id?}]. kind luon 'stock' (mua cho
--   la hang hoa; dich vu khong mua cho). employee_id = nguoi goi.
create or replace function public.market_order_create(
  p_property_id uuid,
  p_lines jsonb,
  p_advance_amount numeric,
  p_purpose text default null,
  p_expected_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_po_id uuid;
  v_po_no text;
  v_adv_id uuid;
  v_adv_no text;
  v_total numeric(18,2);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_idx integer;
  v_line jsonb;
  v_item_id uuid;
  v_item public.items%rowtype;
  v_description text;
  v_qty numeric(18,4);
  v_uom text;
  v_unit_price numeric(18,4);
  v_price_source text;
  v_ceiling_price numeric(18,4);
  v_over_ceiling boolean;
  v_qty_stock numeric(18,4);
  v_expense_category_id uuid;
  v_cost_center_id uuid;
  v_lines integer := 0;
begin
  perform public.require_perm(p_property_id, 'market.order.create');

  select p.org_id, p.legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  if p_advance_amount is null or p_advance_amount <= 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_purpose is null or btrim(p_purpose) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) < 1 then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- AC T-022: co tam ung qua han thi chan tao tam ung moi.
  if public._advance_has_overdue(auth.uid()) then
    raise exception 'ERR_ADVANCE_OVERDUE_BLOCK';
  end if;

  -- Kiem tra truoc toan bo dong (khong ghi gi khi co dong loi).
  for v_idx in 0 .. jsonb_array_length(p_lines) - 1 loop
    v_line := p_lines -> v_idx;
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    v_qty := (v_line ->> 'qty')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_uom := btrim(v_line ->> 'uom');
    if v_uom is null or v_uom = '' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if not exists (select 1 from public.uoms u where u.code = v_uom) then
      raise exception 'ERR_UOM_UNKNOWN';
    end if;

    v_item_id := null;
    if v_line ->> 'item_id' is not null and btrim(v_line ->> 'item_id') <> '' then
      if not (v_line ->> 'item_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        raise exception 'ERR_INVALID_VALUE';
      end if;
      v_item_id := (v_line ->> 'item_id')::uuid;
      select * into v_item from public.items i where i.id = v_item_id;
      if not found or v_item.org_id <> v_org_id or v_item.status <> 'active' then
        raise exception 'ERR_INVALID_STATUS';
      end if;
      if not ('market' = any(v_item.allowed_channels)) then
        raise exception 'ERR_CHANNEL_NOT_ALLOWED';
      end if;
    end if;

    v_description := nullif(btrim(v_line ->> 'description'), '');
    if v_item_id is null and v_description is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    if v_line ->> 'unit_price' is not null and (v_line ->> 'unit_price')::numeric < 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    if v_line ->> 'expense_category_id' is not null and btrim(v_line ->> 'expense_category_id') <> '' then
      if not exists (
        select 1 from public.expense_categories ec
        where ec.id = (v_line ->> 'expense_category_id')::uuid and ec.org_id = v_org_id
      ) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
    end if;
    if v_line ->> 'cost_center_id' is not null and btrim(v_line ->> 'cost_center_id') <> '' then
      if not exists (
        select 1 from public.cost_centers cc
        where cc.id = (v_line ->> 'cost_center_id')::uuid and cc.org_id = v_org_id
      ) then
        raise exception 'ERR_INVALID_VALUE';
      end if;
    end if;
  end loop;

  perform set_config('app.pr_po_guard_bypass', 'on', true);
  perform set_config('app.advance_guard_bypass', 'on', true);

  v_adv_no := public.next_doc_no(v_legal_entity_id, 'ADV', v_today);
  insert into public.advances (
    org_id, legal_entity_id, property_id, employee_id, doc_no,
    amount, purpose, status, requested_at, created_by
  )
  values (
    v_org_id, v_legal_entity_id, p_property_id, auth.uid(), v_adv_no,
    p_advance_amount, btrim(p_purpose), 'requested', now(), auth.uid()
  )
  returning id into v_adv_id;

  v_po_no := public.next_doc_no(v_legal_entity_id, 'PO', v_today);
  insert into public.purchase_orders (
    org_id, legal_entity_id, property_id, supplier_id, channel, kind,
    order_date, expected_date, advance_id, status, doc_no, created_by
  )
  values (
    v_org_id, v_legal_entity_id, p_property_id, null, 'market', 'stock',
    v_today, p_expected_date, v_adv_id, 'draft', v_po_no, auth.uid()
  )
  returning id into v_po_id;

  for v_idx in 0 .. jsonb_array_length(p_lines) - 1 loop
    v_line := p_lines -> v_idx;
    v_item_id := null;
    if v_line ->> 'item_id' is not null and btrim(v_line ->> 'item_id') <> '' then
      v_item_id := (v_line ->> 'item_id')::uuid;
    end if;
    v_description := nullif(btrim(v_line ->> 'description'), '');
    v_qty := (v_line ->> 'qty')::numeric;
    v_uom := btrim(v_line ->> 'uom');
    v_expense_category_id := null;
    if v_line ->> 'expense_category_id' is not null and btrim(v_line ->> 'expense_category_id') <> '' then
      v_expense_category_id := (v_line ->> 'expense_category_id')::uuid;
    end if;
    v_cost_center_id := null;
    if v_line ->> 'cost_center_id' is not null and btrim(v_line ->> 'cost_center_id') <> '' then
      v_cost_center_id := (v_line ->> 'cost_center_id')::uuid;
    end if;

    if v_line ->> 'unit_price' is not null then
      -- Gia nguoi di cho du kien: nguon 'manual', so gia tran de danh
      -- over_ceiling (po_submit se doi ly do + them buoc gm).
      v_unit_price := (v_line ->> 'unit_price')::numeric;
      v_price_source := 'manual';
      v_ceiling_price := public.current_ceiling_price(
        v_org_id, p_property_id, v_item_id, v_uom, v_today
      );
      v_over_ceiling := v_ceiling_price is not null and v_unit_price > v_ceiling_price;
    else
      -- Khong dua gia: giai quyet nhu po_create_from_pr (supplier null
      -- -> bo qua hop dong, gia tran -> manual 0).
      select unit_price, price_source, ceiling_price, over_ceiling
        into v_unit_price, v_price_source, v_ceiling_price, v_over_ceiling
      from public._po_resolve_line_price(
        v_org_id, p_property_id, null,
        v_item_id, v_uom, v_today
      );
    end if;

    v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

    insert into public.purchase_order_lines (
      po_id, org_id, item_id, description, qty, uom,
      qty_stock, unit_price, price_source, ceiling_price, over_ceiling,
      expense_category_id, cost_center_id, created_by
    )
    values (
      v_po_id, v_org_id, v_item_id, v_description, v_qty, v_uom,
      v_qty_stock, v_unit_price, v_price_source, v_ceiling_price,
      v_over_ceiling,
      v_expense_category_id, v_cost_center_id, auth.uid()
    );

    v_lines := v_lines + 1;
  end loop;

  select total_amount into v_total
  from public.purchase_orders where id = v_po_id;

  return jsonb_build_object(
    'ok', true,
    'po_id', v_po_id,
    'po_doc_no', v_po_no,
    'advance_id', v_adv_id,
    'advance_doc_no', v_adv_no,
    'status', 'draft',
    'lines', v_lines,
    'total_amount', v_total
  );
end;
$$;

revoke all on function public.market_order_create(uuid, jsonb, numeric, text, date)
  from public, anon, authenticated;
grant execute on function public.market_order_create(uuid, jsonb, numeric, text, date) to authenticated;

-- De nghi tam ung doc lap (khong gan PO). Nguoi giu tien = nguoi goi.
create or replace function public.advance_request(
  p_property_id uuid,
  p_amount numeric,
  p_purpose text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_adv_id uuid;
  v_adv_no text;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'advance.request');

  select p.org_id, p.legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_purpose is null or btrim(p_purpose) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- AC T-022: co tam ung qua han thi chan tao tam ung moi.
  if public._advance_has_overdue(auth.uid()) then
    raise exception 'ERR_ADVANCE_OVERDUE_BLOCK';
  end if;

  perform set_config('app.advance_guard_bypass', 'on', true);

  v_adv_no := public.next_doc_no(v_legal_entity_id, 'ADV', v_today);
  insert into public.advances (
    org_id, legal_entity_id, property_id, employee_id, doc_no,
    amount, purpose, status, requested_at, created_by
  )
  values (
    v_org_id, v_legal_entity_id, p_property_id, auth.uid(), v_adv_no,
    p_amount, btrim(p_purpose), 'requested', now(), auth.uid()
  )
  returning id into v_adv_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_adv_id,
    'doc_no', v_adv_no,
    'status', 'requested'
  );
end;
$$;

revoke all on function public.advance_request(uuid, numeric, text)
  from public, anon, authenticated;
grant execute on function public.advance_request(uuid, numeric, text) to authenticated;

-- Duyet/tu choi tam ung (gm theo vai tro mau). SoD: nguoi de nghi !=
-- nguoi duyet, ma SOD_ADVANCE_APPROVER (quyet dinh 6).
create or replace function public.advance_decide(
  p_property_id uuid,
  p_advance_id uuid,
  p_approved boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_adv public.advances%rowtype;
begin
  perform public.require_perm(p_property_id, 'advance.approve');

  select * into v_adv from public.advances a where a.id = p_advance_id;
  if not found or v_adv.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_adv.status <> 'requested' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  if v_adv.employee_id = auth.uid() then
    perform public._sod_check(p_property_id, 'SOD_ADVANCE_APPROVER');
  end if;

  if not p_approved and (p_reason is null or btrim(p_reason) = '') then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.advance_guard_bypass', 'on', true);

  update public.advances
  set status = case when p_approved then 'approved' else 'rejected' end,
      decided_by = auth.uid(),
      decided_at = now(),
      decide_reason = nullif(btrim(p_reason), ''),
      updated_at = now()
  where id = p_advance_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_advance_id,
    'doc_no', v_adv.doc_no,
    'status', case when p_approved then 'approved' else 'rejected' end
  );
end;
$$;

revoke all on function public.advance_decide(uuid, uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.advance_decide(uuid, uuid, boolean, text) to authenticated;

-- Chi tien tam ung (ke toan KS). Han quyet toan tinh tu luc chi
-- (quyet dinh 7): due_settle_at = now() + market_advance_deadline_hours.
create or replace function public.advance_disburse(
  p_property_id uuid,
  p_advance_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_adv public.advances%rowtype;
  v_po public.purchase_orders%rowtype;
  v_deadline_hours numeric;
  v_due_settle_at timestamptz;
begin
  perform public.require_perm(p_property_id, 'advance.disburse');

  select * into v_adv from public.advances a where a.id = p_advance_id;
  if not found or v_adv.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_adv.status <> 'approved' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  -- PO lien ket (neu co) phai da duyet — khong chi tien cho PO nhap,
  -- cho duyet, bi tu choi/huy (quyet dinh 5).
  select * into v_po
  from public.purchase_orders po where po.advance_id = p_advance_id;
  if found and v_po.status not in ('approved', 'sent', 'partially_received', 'received') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  v_deadline_hours := public._advance_deadline_hours(v_adv.org_id, p_property_id);
  v_due_settle_at := now() + (v_deadline_hours::text || ' hours')::interval;

  perform set_config('app.advance_guard_bypass', 'on', true);

  update public.advances
  set status = 'disbursed',
      disbursed_at = now(),
      disbursed_note = nullif(btrim(p_note), ''),
      due_settle_at = v_due_settle_at,
      updated_at = now()
  where id = p_advance_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_advance_id,
    'doc_no', v_adv.doc_no,
    'status', 'disbursed',
    'due_settle_at', v_due_settle_at
  );
end;
$$;

revoke all on function public.advance_disburse(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.advance_disburse(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC doc: danh sach + chi tiet tam ung (cho UI T-022).
-- ---------------------------------------------------------------------------
create or replace function public.advance_list(
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
    public.has_perm(p_property_id, 'advance.request')
    or public.has_perm(p_property_id, 'advance.approve')
    or public.has_perm(p_property_id, 'advance.disburse')
    or public.has_perm(p_property_id, 'advance.settle')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      a.id, a.doc_no, a.employee_id, pr.full_name as employee_name,
      a.amount, a.purpose, a.status, a.requested_at,
      a.decided_by, a.decided_at, a.decide_reason,
      a.disbursed_at, a.due_settle_at, a.created_at,
      po.id as po_id, po.doc_no as po_doc_no, po.status as po_status
    from public.advances a
    left join public.profiles pr on pr.id = a.employee_id
    left join public.purchase_orders po on po.advance_id = a.id
    where a.property_id = p_property_id
      and (p_status is null or a.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or a.doc_no ilike '%' || p_search || '%'
        or a.purpose ilike '%' || p_search || '%'
        or pr.full_name ilike '%' || p_search || '%'
      )
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

revoke all on function public.advance_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.advance_list(uuid, text, text, integer, integer) to authenticated;

create or replace function public.advance_get(
  p_property_id uuid,
  p_advance_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_adv public.advances%rowtype;
  v_employee_name text;
  v_po jsonb;
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'advance.request')
    or public.has_perm(p_property_id, 'advance.approve')
    or public.has_perm(p_property_id, 'advance.disburse')
    or public.has_perm(p_property_id, 'advance.settle')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select * into v_adv from public.advances a where a.id = p_advance_id;
  if not found or v_adv.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select pr.full_name into v_employee_name
  from public.profiles pr where pr.id = v_adv.employee_id;

  select to_jsonb(p)
  into v_po
  from (
    select po.id, po.doc_no, po.status, po.total_amount, po.channel
    from public.purchase_orders po where po.advance_id = p_advance_id
  ) p;

  select jsonb_build_object(
    'ok', true,
    'advance', to_jsonb(v_adv) || jsonb_build_object('employee_name', v_employee_name),
    'po', v_po
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.advance_get(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.advance_get(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Cron worker: danh dau tam ung qua han + alert ADVANCE_OVERDUE.
--    Chay moi gio qua pg_cron (muc 7). Dedupe: bo qua tam ung da co alert
--    chua ack. Kiem tra chan o advance_request/market_order_create tinh
--    truc tiep nen khong phu thuoc cron (quyet dinh 7).
-- ---------------------------------------------------------------------------
create or replace function public.advance_overdue_maintenance()
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp as $$
declare
  v_marked integer := 0;
  v_alerts integer := 0;
  r record;
begin
  perform set_config('app.advance_guard_bypass', 'on', true);

  for r in
    select a.id, a.doc_no, a.property_id, a.employee_id, a.amount,
           a.due_settle_at
    from public.advances a
    where a.status in ('disbursed', 'settling')
      and a.due_settle_at is not null
      and a.due_settle_at < now()
    order by a.due_settle_at
  loop
    update public.advances
    set status = 'overdue', updated_at = now()
    where id = r.id;
    v_marked := v_marked + 1;

    if not exists (
      select 1 from public.alerts al
      where al.code = 'ADVANCE_OVERDUE'
        and al.doc_type = 'advance'
        and al.doc_id = r.id
        and al.ack_at is null
    ) then
      perform public._create_alert(
        r.property_id,
        'ADVANCE_OVERDUE',
        'warn',
        format('Tạm ứng %s quá hạn quyết toán', r.doc_no),
        jsonb_build_object(
          'advance_id', r.id,
          'doc_no', r.doc_no,
          'employee_id', r.employee_id,
          'amount', r.amount,
          'due_settle_at', r.due_settle_at
        ),
        'advance',
        r.id
      );
      v_alerts := v_alerts + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'marked_overdue', v_marked,
    'alerts_created', v_alerts
  );
end $$;

comment on function public.advance_overdue_maintenance() is
  'T-022: cron moi gio — danh dau tam ung qua han + alert ADVANCE_OVERDUE (dedupe theo alert chua ack).';

revoke all on function public.advance_overdue_maintenance()
  from public, anon;
grant execute on function public.advance_overdue_maintenance()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 7. pg_cron: job moi gio 'advance-overdue-hourly' (02-ARCHITECTURE.md:83).
--    Guard 2 lop: extension chua bat -> bo qua, migration van chay xong.
--    Bat pg_cron trong Dashboard (Database > Extensions) truoc/sau khi push;
--    neu chua bat, goi tay select public.advance_overdue_maintenance().
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'T-022: pg_cron khong cai duoc (%), bo qua lich chay.', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (
      select 1 from cron.job where jobname = 'advance-overdue-hourly'
    ) then
      perform cron.schedule(
        'advance-overdue-hourly',
        '0 * * * *',
        'select public.advance_overdue_maintenance()'
      );
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Gan quyen nhan alert ADVANCE_OVERDUE (ma da seed san, chua gan vai
--    tro nao). Join theo ma vai tro, giong mau T-015.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('cost_controller', 'alert.receive.advance_overdue'),
  ('chief_accountant', 'alert.receive.advance_overdue'),
  ('gm', 'alert.receive.advance_overdue')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109220000_market_advances',
  'INSERT',
  jsonb_build_object('event', 'market_advances_created', 'task', 'T-022'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
