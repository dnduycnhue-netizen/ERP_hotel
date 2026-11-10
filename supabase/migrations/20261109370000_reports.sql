-- T-044: 10 bao cao MVP (docs/08-REPORTS-ALERTS.md §1-§2).
--   - Bang report_snapshots (theo data model A10) luu ban tin 8h.
--   - RPC report_get(p_property_id, p_code, p_params) — diem vao duy nhat
--     cua 10 bao cao; SECURITY DEFINER, kiem tra quyen report.view.<code>
--     ben trong (Q64 CHOT: doc pms_daily_stats qua RPC rieng thay vi mo
--     policy pms_daily_stats_select — cost_controller khong co pms.input
--     van doc duoc CPOR qua bao cao).
--   - RPC report_build_daily(p_property_id, p_date) — xay ban tin 8h, luu
--     snapshot; khong require_perm (cron-callable, tien le
--     minibar_reconcile / service_schedule_generate) — chi ghi snapshot.
--   - Moi bao cao tra jsonb { ok, code, params, rows, totals, notes }.
--   - Tien/so luong tinh trong Postgres (numeric); ngay nghiep vu VN.
--   - KHONG sua migration cu. Khong quyen moi (report.view.rpt_* da co
--     trong catalog 141000, owner da du).

-- ---------------------------------------------------------------------------
-- 1. Bang report_snapshots + write-guard + RLS
-- ---------------------------------------------------------------------------
create table public.report_snapshots (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  report_code text not null check (btrim(report_code) <> ''),
  business_date date not null,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (property_id, report_code, business_date)
);
create index on public.report_snapshots (property_id, business_date desc);

alter table public.report_snapshots enable row level security;
revoke all on table public.report_snapshots from anon, authenticated;
grant select on table public.report_snapshots to authenticated;

create policy report_snapshots_select on public.report_snapshots
for select to authenticated
using (property_id in (select public.my_property_ids()));

create or replace function public._report_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.report_guard_bypass', true), '') <> 'on' then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return new;
end $$;

create trigger trg_report_snapshots_write_guard
before insert or update or delete on public.report_snapshots
for each row execute function public._report_write_guard();

drop trigger if exists trg_report_snapshots_set_updated_at on public.report_snapshots;
create trigger trg_report_snapshots_set_updated_at
before update on public.report_snapshots
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Helper dung chung (noi bo — khong grant execute)
-- ---------------------------------------------------------------------------
-- Ngay nghiep vu hien tai (VN).
create or replace function public._report_today()
returns date
language sql stable
as $$
  select (now() at time zone 'Asia/Ho_Chi_Minh')::date;
$$;
revoke all on function public._report_today() from public, anon, authenticated;

-- FIFO: cong no rong theo (NCC, han tra) tai ngay as_of. Chi tinh but toan
-- co entry_date <= as_of; tien da tra / tra hang (amount < 0) phan bo vao
-- cac khoan den han som nhat truoc (giong getApAging cua T-041).
create or replace function public._report_ap_outstanding(
  p_property_id uuid, p_asof date
)
returns table (supplier_id uuid, due_date date, amount numeric)
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with pos as (
    select a.supplier_id,
      coalesce(a.due_date, a.entry_date) as due_date,
      a.amount,
      sum(a.amount) over (
        partition by a.supplier_id
        order by coalesce(a.due_date, a.entry_date), a.entry_date, a.created_at
        rows between unbounded preceding and current row
      ) as cum_amount
    from public.ap_ledger a
    where a.property_id = p_property_id and a.amount > 0 and a.entry_date <= p_asof
  ),
  paid as (
    select a.supplier_id, -sum(a.amount) as paid_amount
    from public.ap_ledger a
    where a.property_id = p_property_id and a.amount < 0 and a.entry_date <= p_asof
    group by a.supplier_id
  )
  select p.supplier_id, p.due_date,
    p.amount - greatest(0, least(p.amount, coalesce(pd.paid_amount, 0) - (p.cum_amount - p.amount))) as amount
  from pos p
  left join paid pd on pd.supplier_id = p.supplier_id
  where p.amount - greatest(0, least(p.amount, coalesce(pd.paid_amount, 0) - (p.cum_amount - p.amount))) > 0;
$$;
revoke all on function public._report_ap_outstanding(uuid, date) from public, anon, authenticated;

-- Tong so dem phong ban trong thang (tu pms_daily_stats; doc qua RPC nay
-- nen nguoi chi co report.view.* van doc duoc — Q64).
create or replace function public._report_rooms_sold(
  p_property_id uuid, p_from date, p_to date
)
returns numeric
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  select coalesce(sum(s.rooms_sold), 0)
  from public.pms_daily_stats s
  where s.property_id = p_property_id and s.business_date between p_from and p_to;
$$;
revoke all on function public._report_rooms_sold(uuid, date, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPT_STOCK_CARD — the kho / nhap–xuat–ton (tu stock_moves)
--    Ton dau = tong but toan truoc ngay bat dau; gia tri lay theo don gia
--    cua tung but toan (amount co dau). Cap 1000 dong.
-- ---------------------------------------------------------------------------
create or replace function public._report_stock_card(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce((p_params ->> 'from')::date, date_trunc('month', public._report_today())::date) as d_from,
      coalesce((p_params ->> 'to')::date, public._report_today()) as d_to,
      nullif(p_params ->> 'warehouse_id', '')::uuid as wh_id,
      nullif(p_params ->> 'item_id', '')::uuid as item_id
  ),
  agg as (
    select
      m.warehouse_id, m.item_id, m.lot_id,
      coalesce(sum(m.qty) filter (where m.business_date < p.d_from), 0) as opening_qty,
      coalesce(sum(m.amount) filter (where m.business_date < p.d_from), 0) as opening_value,
      coalesce(sum(m.qty) filter (where m.business_date between p.d_from and p.d_to and m.qty > 0), 0) as in_qty,
      coalesce(sum(m.amount) filter (where m.business_date between p.d_from and p.d_to and m.qty > 0), 0) as in_value,
      -coalesce(sum(m.qty) filter (where m.business_date between p.d_from and p.d_to and m.qty < 0), 0) as out_qty,
      -coalesce(sum(m.amount) filter (where m.business_date between p.d_from and p.d_to and m.qty < 0), 0) as out_value
    from public.stock_moves m cross join p
    where m.property_id = p_property_id
      and (p.wh_id is null or m.warehouse_id = p.wh_id)
      and (p.item_id is null or m.item_id = p.item_id)
      and m.business_date <= p.d_to
    group by m.warehouse_id, m.item_id, m.lot_id
  ),
  rows as (
    select jsonb_build_object(
      'warehouse_id', a.warehouse_id,
      'warehouse_code', w.code, 'warehouse_name', w.name,
      'item_id', a.item_id, 'item_code', i.code, 'item_name', i.name,
      'uom', i.stock_uom,
      'lot_no', l.lot_no, 'expiry_date', l.expiry_date,
      'opening_qty', a.opening_qty, 'in_qty', a.in_qty, 'out_qty', a.out_qty,
      'closing_qty', a.opening_qty + a.in_qty - a.out_qty,
      'opening_value', a.opening_value, 'in_value', a.in_value, 'out_value', a.out_value,
      'closing_value', a.opening_value + a.in_value - a.out_value
    ) as row,
    a.opening_value + a.in_value - a.out_value as closing_value
    from agg a
    join public.warehouses w on w.id = a.warehouse_id
    join public.items i on i.id = a.item_id
    left join public.lots l on l.id = a.lot_id
    order by w.code, i.code, l.lot_no nulls last
    limit 1000
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_STOCK_CARD',
    'params', jsonb_build_object('from', p.d_from, 'to', p.d_to,
      'warehouse_id', p.wh_id, 'item_id', p.item_id),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'row_count', (select count(*) from rows),
      'capped', (select count(*) from agg) > 1000,
      'closing_value', coalesce((select sum(r.closing_value) from rows r), 0)),
    'notes', jsonb_build_array(
      'Gia tri ton tinh tu so cai stock_moves (don gia cua tung but toan); ton dau ky = tong cac but toan truoc ngay bat dau.')
  ) from p;
$$;
revoke all on function public._report_stock_card(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPT_RECEIVING_QUALITY — chat luong nhan hang theo NCC
--    Thieu can = so luong PO - so luong thuc nhan (chi tinh phan thieu);
--    can lai = so dong weigh_count = 2; QC fail = qc_status = 'fail'.
-- ---------------------------------------------------------------------------
create or replace function public._report_receiving_quality(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce((p_params ->> 'from')::date, date_trunc('month', public._report_today())::date) as d_from,
      coalesce((p_params ->> 'to')::date, public._report_today()) as d_to,
      nullif(p_params ->> 'supplier_id', '')::uuid as supplier_id
  ),
  grs as (
    select g.supplier_id, count(*)::bigint as gr_count
    from public.goods_receipts g cross join p
    where g.property_id = p_property_id and g.status = 'posted'
      and (g.received_at at time zone 'Asia/Ho_Chi_Minh')::date between p.d_from and p.d_to
      and (p.supplier_id is null or g.supplier_id = p.supplier_id)
    group by g.supplier_id
  ),
  lines as (
    select g.supplier_id,
      count(*)::bigint as line_count,
      coalesce(sum(pol.qty_stock), 0) as ordered_qty,
      coalesce(sum(l.net_qty_stock), 0) as received_qty,
      coalesce(sum(greatest(coalesce(pol.qty_stock, l.net_qty_stock) - l.net_qty_stock, 0)), 0) as short_qty,
      count(*) filter (where l.weigh_count = 2)::bigint as reweigh_count,
      count(*) filter (where l.qc_status = 'fail')::bigint as qc_fail_count
    from public.goods_receipt_lines l
    join public.goods_receipts g on g.id = l.gr_id
    left join public.purchase_order_lines pol on pol.id = l.po_line_id
    cross join p
    where g.property_id = p_property_id and g.status = 'posted'
      and (g.received_at at time zone 'Asia/Ho_Chi_Minh')::date between p.d_from and p.d_to
      and (p.supplier_id is null or g.supplier_id = p.supplier_id)
    group by g.supplier_id
  ),
  rets as (
    select r.supplier_id, count(distinct r.id)::bigint as return_count,
      coalesce(sum(rl.qty_stock), 0) as return_qty
    from public.supplier_returns r
    join public.supplier_return_lines rl on rl.return_id = r.id
    cross join p
    where r.property_id = p_property_id and r.status = 'posted'
      and (r.created_at at time zone 'Asia/Ho_Chi_Minh')::date between p.d_from and p.d_to
      and (p.supplier_id is null or r.supplier_id = p.supplier_id)
    group by r.supplier_id
  ),
  suppliers as (
    select supplier_id from grs
    union select supplier_id from lines
    union select supplier_id from rets
  ),
  rows as (
    select jsonb_build_object(
      'supplier_id', s.supplier_id,
      'supplier_code', sup.code, 'supplier_name', sup.name,
      'gr_count', coalesce(g.gr_count, 0),
      'line_count', coalesce(ln.line_count, 0),
      'ordered_qty', coalesce(ln.ordered_qty, 0),
      'received_qty', coalesce(ln.received_qty, 0),
      'short_qty', coalesce(ln.short_qty, 0),
      'short_pct', case when coalesce(ln.ordered_qty, 0) > 0
        then round(100 * coalesce(ln.short_qty, 0) / ln.ordered_qty, 2) end,
      'reweigh_count', coalesce(ln.reweigh_count, 0),
      'qc_fail_count', coalesce(ln.qc_fail_count, 0),
      'return_count', coalesce(rt.return_count, 0),
      'return_qty', coalesce(rt.return_qty, 0)
    ) as row,
    coalesce(ln.short_qty, 0) as short_qty
    from suppliers s
    join public.suppliers sup on sup.id = s.supplier_id
    left join grs g on g.supplier_id = s.supplier_id
    left join lines ln on ln.supplier_id = s.supplier_id
    left join rets rt on rt.supplier_id = s.supplier_id
    order by coalesce(ln.short_qty, 0) desc, sup.code
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_RECEIVING_QUALITY',
    'params', jsonb_build_object('from', p.d_from, 'to', p.d_to,
      'supplier_id', p.supplier_id),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'gr_count', coalesce((select sum((r.row ->> 'gr_count')::bigint) from rows r), 0),
      'short_qty', coalesce((select sum(r.short_qty) from rows r), 0),
      'reweigh_count', coalesce((select sum((r.row ->> 'reweigh_count')::bigint) from rows r), 0),
      'qc_fail_count', coalesce((select sum((r.row ->> 'qc_fail_count')::bigint) from rows r), 0),
      'return_count', coalesce((select sum((r.row ->> 'return_count')::bigint) from rows r), 0)),
    'notes', jsonb_build_array(
      'Thieu can = tong (so luong PO - so luong thuc nhan) chi tren cac dong thieu; dong nhan vuot khong bu tru.')
  ) from p;
$$;
revoke all on function public._report_receiving_quality(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPT_OPEN_PO_INVOICE — PO mo & hoa don treo (tai ngay as_of)
-- ---------------------------------------------------------------------------
create or replace function public._report_open_po_invoice(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select coalesce((p_params ->> 'as_of')::date, public._report_today()) as d_asof
  ),
  po_rows as (
    select jsonb_build_object(
      'po_id', po.id, 'doc_no', po.doc_no,
      'supplier_id', po.supplier_id, 'supplier_code', s.code, 'supplier_name', s.name,
      'order_date', po.order_date, 'expected_date', po.expected_date, 'status', po.status,
      'ordered_amount', coalesce(sum(pol.qty_stock * pol.unit_price), 0),
      'received_amount', coalesce(sum(pol.received_qty_stock * pol.unit_price), 0),
      'remaining_amount', coalesce(sum((pol.qty_stock - pol.received_qty_stock) * pol.unit_price), 0),
      'overdue_days', case when po.expected_date is null then null
        else greatest(0, (select d_asof from p) - po.expected_date) end
    ) as row,
    coalesce(sum((pol.qty_stock - pol.received_qty_stock) * pol.unit_price), 0) as remaining_amount
    from public.purchase_orders po
    join public.suppliers s on s.id = po.supplier_id
    join public.purchase_order_lines pol on pol.po_id = po.id
    where po.property_id = p_property_id
      and po.status in ('approved', 'sent', 'partially_received')
    group by po.id, s.code, s.name, po.order_date, po.expected_date, po.status
    having coalesce(sum(pol.qty_stock - pol.received_qty_stock), 0) > 0
    order by po.expected_date nulls last, po.doc_no
  ),
  inv_rows as (
    select jsonb_build_object(
      'invoice_id', inv.id, 'doc_no', inv.doc_no,
      'invoice_symbol', inv.invoice_symbol, 'invoice_no', inv.invoice_no,
      'invoice_date', inv.invoice_date,
      'supplier_id', inv.supplier_id, 'supplier_code', s.code, 'supplier_name', s.name,
      'total', inv.total,
      'match_result', (
        select l.match_result from public.supplier_invoice_lines l
        where l.invoice_id = inv.id order by l.created_at limit 1
      )
    ) as row,
    inv.total as total
    from public.supplier_invoices inv
    join public.suppliers s on s.id = inv.supplier_id
    where inv.property_id = p_property_id and inv.status = 'on_hold'
    order by inv.invoice_date, inv.doc_no
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_OPEN_PO_INVOICE',
    'params', jsonb_build_object('as_of', p.d_asof),
    'rows', coalesce((select jsonb_agg(r.row) from po_rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'open_po_count', (select count(*) from po_rows),
      'open_po_remaining_amount', coalesce((select sum(r.remaining_amount) from po_rows r), 0),
      'on_hold_count', (select count(*) from inv_rows),
      'on_hold_amount', coalesce((select sum(r.total) from inv_rows r), 0)),
    'extra', jsonb_build_object(
      'on_hold_invoices', coalesce((select jsonb_agg(r.row) from inv_rows r), '[]'::jsonb)),
    'notes', jsonb_build_array(
      'PO mo = trang thai approved/sent/partially_received va con so luong chua nhan; hoa don treo = status on_hold.')
  ) from p;
$$;
revoke all on function public._report_open_po_invoice(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPT_AP_AGING — tuoi no & du bao chi 14 ngay (FIFO nhu T-041)
-- ---------------------------------------------------------------------------
create or replace function public._report_ap_aging(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select coalesce((p_params ->> 'as_of')::date, public._report_today()) as d_asof
  ),
  per_sup as (
    select o.supplier_id,
      coalesce(sum(o.amount) filter (where o.due_date > p.d_asof), 0) as not_due,
      coalesce(sum(o.amount) filter (where o.due_date <= p.d_asof and o.due_date > p.d_asof - 30), 0) as o1_30,
      coalesce(sum(o.amount) filter (where o.due_date <= p.d_asof - 30 and o.due_date > p.d_asof - 60), 0) as o31_60,
      coalesce(sum(o.amount) filter (where o.due_date <= p.d_asof - 60 and o.due_date > p.d_asof - 90), 0) as o61_90,
      coalesce(sum(o.amount) filter (where o.due_date <= p.d_asof - 90), 0) as o90,
      coalesce(sum(o.amount) filter (where o.due_date > p.d_asof and o.due_date <= p.d_asof + 14), 0) as forecast_14d,
      coalesce(sum(o.amount), 0) as total
    from public._report_ap_outstanding(p_property_id, (select d_asof from p)) o
    cross join p
    group by o.supplier_id
  ),
  rows as (
    select jsonb_build_object(
      'supplier_id', ps.supplier_id,
      'supplier_code', s.code, 'supplier_name', s.name,
      'not_due', ps.not_due, 'overdue_1_30', ps.o1_30,
      'overdue_31_60', ps.o31_60, 'overdue_61_90', ps.o61_90,
      'overdue_over_90', ps.o90, 'forecast_14d', ps.forecast_14d,
      'total', ps.total
    ) as row,
    ps.total as total, ps.forecast_14d as forecast_14d,
    ps.not_due as not_due, ps.o1_30 as o1_30, ps.o31_60 as o31_60,
    ps.o61_90 as o61_90, ps.o90 as o90
    from per_sup ps
    join public.suppliers s on s.id = ps.supplier_id
    order by ps.total desc
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_AP_AGING',
    'params', jsonb_build_object('as_of', p.d_asof),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'total', coalesce((select sum(r.total) from rows r), 0),
      'not_due', coalesce((select sum(r.not_due) from rows r), 0),
      'overdue_1_30', coalesce((select sum(r.o1_30) from rows r), 0),
      'overdue_31_60', coalesce((select sum(r.o31_60) from rows r), 0),
      'overdue_61_90', coalesce((select sum(r.o61_90) from rows r), 0),
      'overdue_over_90', coalesce((select sum(r.o90) from rows r), 0),
      'forecast_14d', coalesce((select sum(r.forecast_14d) from rows r), 0)),
    'notes', jsonb_build_array(
      'Tien da tra / tra hang phan bo FIFO vao khoan den han som nhat; du bao chi 14 ngay = cac khoan den han trong (as_of, as_of+14].')
  ) from p;
$$;
revoke all on function public._report_ap_aging(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPT_ADVANCES — tam ung chua quyet toan
-- ---------------------------------------------------------------------------
create or replace function public._report_advances(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select coalesce((p_params ->> 'as_of')::date, public._report_today()) as d_asof
  ),
  rows as (
    select jsonb_build_object(
      'advance_id', a.id, 'doc_no', a.doc_no,
      'employee_id', a.employee_id, 'employee_name', pr.full_name,
      'amount', a.amount,
      'settled_amount', coalesce(sum(st.amount), 0),
      'remaining_amount', a.amount - coalesce(sum(st.amount), 0),
      'purpose', a.purpose,
      'due_settle_at', a.due_settle_at,
      'overdue_hours', case when a.due_settle_at is null then null
        else greatest(0, floor(extract(epoch from (now() - a.due_settle_at)) / 3600))::bigint end,
      'status', a.status
    ) as row,
    a.amount - coalesce(sum(st.amount), 0) as remaining_amount,
    case when a.due_settle_at is null then null
      else greatest(0, floor(extract(epoch from (now() - a.due_settle_at)) / 3600))::bigint end as overdue_hours
    from public.advances a
    left join public.profiles pr on pr.id = a.employee_id
    left join public.advance_settlements st on st.advance_id = a.id
    where a.property_id = p_property_id
      and a.status in ('approved', 'disbursed', 'settling', 'overdue')
    group by a.id, pr.full_name
    order by overdue_hours desc nulls last, a.due_settle_at
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_ADVANCES',
    'params', jsonb_build_object('as_of', p.d_asof),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'count', (select count(*) from rows),
      'remaining_amount', coalesce((select sum(r.remaining_amount) from rows r), 0),
      'overdue_count', coalesce((select count(*) from rows r where r.overdue_hours is not null and r.overdue_hours > 0), 0)),
    'notes', jsonb_build_array(
      'So gio qua han tinh tu due_settle_at den gio hien tai (gio may chu); tam ung da settled/rejected khong hien.')
  ) from p;
$$;
revoke all on function public._report_advances(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. RPT_WASTE — huy hang theo ly do / outlet / nguoi de xuat
--    % doanh thu: doanh thu POS chua tich hop (Q34) nen tam tinh % theo
--    gia tri nhap kho cung ky, ghi ro tren man hinh + Q88.
-- ---------------------------------------------------------------------------
create or replace function public._report_waste(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce((p_params ->> 'from')::date, date_trunc('month', public._report_today())::date) as d_from,
      coalesce((p_params ->> 'to')::date, public._report_today()) as d_to
  ),
  agg as (
    select wr.reason_code, wr.warehouse_id, wr.proposed_by,
      count(distinct wr.id)::bigint as doc_count,
      coalesce(sum(l.qty_stock), 0) as qty,
      coalesce(sum(l.qty_stock * l.unit_cost), 0) as value
    from public.waste_reports wr
    join public.waste_report_lines l on l.waste_report_id = wr.id
    cross join p
    where wr.property_id = p_property_id and wr.status = 'posted'
      and wr.business_date between p.d_from and p.d_to
    group by wr.reason_code, wr.warehouse_id, wr.proposed_by
  ),
  total_value as (
    select coalesce(sum(value), 0) as v from agg
  ),
  received_value as (
    select coalesce(sum(g.total_amount), 0) as v
    from public.goods_receipts g cross join p
    where g.property_id = p_property_id and g.status = 'posted'
      and (g.received_at at time zone 'Asia/Ho_Chi_Minh')::date between p.d_from and p.d_to
  ),
  rows as (
    select jsonb_build_object(
      'reason_code', a.reason_code,
      'warehouse_id', a.warehouse_id,
      'warehouse_code', w.code, 'warehouse_name', w.name,
      'outlet_name', o.name,
      'proposed_by', a.proposed_by, 'proposer_name', pr.full_name,
      'doc_count', a.doc_count, 'qty', a.qty, 'value', a.value,
      'value_share_pct', case when (select v from total_value) > 0
        then round(100 * a.value / (select v from total_value), 2) end
    ) as row,
    a.value as value
    from agg a
    join public.warehouses w on w.id = a.warehouse_id
    left join public.outlets o on o.id = w.outlet_id
    left join public.profiles pr on pr.id = a.proposed_by
    order by a.value desc
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_WASTE',
    'params', jsonb_build_object('from', p.d_from, 'to', p.d_to),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'doc_count', coalesce((select sum((r.row ->> 'doc_count')::bigint) from rows r), 0),
      'total_value', (select v from total_value),
      'received_value', (select v from received_value),
      'waste_pct_of_received', case when (select v from received_value) > 0
        then round(100 * (select v from total_value) / (select v from received_value), 2) end),
    'notes', jsonb_build_array(
      '% doanh thu theo spec can du lieu POS (pos_sales_lines) chua tich hop (Q34); tam tinh % theo gia tri nhap kho cung ky.')
  ) from p;
$$;
revoke all on function public._report_waste(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. RPT_OPEX — chi phi van hanh theo khoan muc x cost center x thang; CPOR
--    Nguon: moves (purpose_issue/waste, -amount) + dich vu da nghiem thu
--    (amount_per_cycle) + hoa don da duyet (theo dong PO). CPOR = chi phi
--    khoan muc / tong rooms_sold thang (pms_daily_stats — Q64: doc qua RPC).
-- ---------------------------------------------------------------------------
create or replace function public._report_opex(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce(p_params ->> 'month', to_char(public._report_today(), 'YYYY-MM')) as month,
      (coalesce(p_params ->> 'month', to_char(public._report_today(), 'YYYY-MM')) || '-01')::date as m_from,
      ((coalesce(p_params ->> 'month', to_char(public._report_today(), 'YYYY-MM')) || '-01')::date
        + interval '1 month' - interval '1 day')::date as m_to
  ),
  rooms_sold as (
    select public._report_rooms_sold(p_property_id, p.m_from, p.m_to) as rs from p
  ),
  moves as (
    select m.expense_category_id, m.cost_center_id, -sum(m.amount) as cost
    from public.stock_moves m cross join p
    where m.property_id = p_property_id
      and m.move_type in ('purpose_issue', 'waste')
      and m.business_date between p.m_from and p.m_to
    group by m.expense_category_id, m.cost_center_id
  ),
  services as (
    select sc.expense_category_id, sc.cost_center_id, sum(sc.amount_per_cycle) as cost
    from public.service_schedules ss
    join public.service_contracts sc on sc.id = ss.contract_id
    cross join p
    where ss.property_id = p_property_id and ss.status = 'accepted'
      and ss.period_start between p.m_from and p.m_to
    group by sc.expense_category_id, sc.cost_center_id
  ),
  invoices as (
    select pol.expense_category_id, pol.cost_center_id, sum(l.amount) as cost
    from public.supplier_invoice_lines l
    join public.supplier_invoices inv on inv.id = l.invoice_id
    join public.purchase_order_lines pol on pol.id = l.po_line_id
    cross join p
    where inv.property_id = p_property_id
      and inv.status in ('approved', 'partially_paid', 'paid')
      and inv.invoice_date between p.m_from and p.m_to
    group by pol.expense_category_id, pol.cost_center_id
  ),
  combined as (
    select expense_category_id, cost_center_id,
      coalesce(sum(cost) filter (where src = 'moves'), 0) as moves_cost,
      coalesce(sum(cost) filter (where src = 'services'), 0) as service_cost,
      coalesce(sum(cost) filter (where src = 'invoices'), 0) as invoice_cost
    from (
      select 'moves' as src, expense_category_id, cost_center_id, cost from moves
      union all
      select 'services', expense_category_id, cost_center_id, cost from services
      union all
      select 'invoices', expense_category_id, cost_center_id, cost from invoices
    ) all_costs
    group by expense_category_id, cost_center_id
  ),
  rows as (
    select jsonb_build_object(
      'expense_category_id', c.expense_category_id,
      'expense_category_code', ec.code, 'expense_category_name', ec.name,
      'cost_center_id', c.cost_center_id,
      'cost_center_code', cc.code, 'cost_center_name', cc.name,
      'moves_cost', c.moves_cost, 'service_cost', c.service_cost,
      'invoice_cost', c.invoice_cost,
      'total_cost', c.moves_cost + c.service_cost + c.invoice_cost,
      'cpor', case when (select rs from rooms_sold) > 0
        then round((c.moves_cost + c.service_cost + c.invoice_cost) / (select rs from rooms_sold), 2) end
    ) as row,
    c.moves_cost + c.service_cost + c.invoice_cost as total_cost
    from combined c
    left join public.expense_categories ec on ec.id = c.expense_category_id
    left join public.cost_centers cc on cc.id = c.cost_center_id
    order by total_cost desc
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_OPEX',
    'params', jsonb_build_object('month', p.month),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'total_cost', coalesce((select sum(r.total_cost) from rows r), 0),
      'rooms_sold', (select rs from rooms_sold),
      'cpor', case when (select rs from rooms_sold) > 0
        then round(coalesce((select sum(r.total_cost) from rows r), 0) / (select rs from rooms_sold), 2) end),
    'notes', jsonb_build_array(
      'CPOR = chi phi / tong dem phong ban (rooms_sold) thang; hoa don chi tinh dong co khoan muc/cost center tren PO.')
  ) from p;
$$;
revoke all on function public._report_opex(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10. RPT_MINIBAR — doanh thu, gia von, lai gop tung mon; doi soat thu;
--     Lavie ban / Dasani cap tren dem phong (theo Q62).
--     Gia von = -sum(amount) cua move minibar_sale; doi soat theo cong thuc
--     minibar_reconcile nhung tren khoang ngay (thay vi 1 ngay).
-- ---------------------------------------------------------------------------
create or replace function public._report_minibar(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce((p_params ->> 'from')::date, date_trunc('month', public._report_today())::date) as d_from,
      coalesce((p_params ->> 'to')::date, public._report_today()) as d_to
  ),
  per_item as (
    select l.item_id, i.code, i.name,
      coalesce(sum(l.amount) filter (where c.status = 'charged'), 0) as revenue,
      coalesce(sum(l.missing_qty) filter (where c.status = 'charged'), 0) as units_sold,
      coalesce(sum(l.amount) filter (where c.status = 'waived'), 0) as waived,
      coalesce(sum(l.amount) filter (where c.status = 'late_charge'), 0) as late_charge
    from public.minibar_check_lines l
    join public.minibar_checks c on c.id = l.check_id
    join public.items i on i.id = l.item_id
    cross join p
    where c.property_id = p_property_id and c.business_date between p.d_from and p.d_to
      and c.checked_by is not null
    group by l.item_id, i.code, i.name
  ),
  costs as (
    select m.item_id, -sum(m.amount) as cogs
    from public.stock_moves m cross join p
    where m.property_id = p_property_id and m.move_type = 'minibar_sale'
      and m.business_date between p.d_from and p.d_to
    group by m.item_id
  ),
  recon as (
    select
      coalesce(sum(c.total_amount) filter (
        where c.checked_by is not null
          and c.status in ('pending_charge', 'charged', 'waived', 'late_charge')), 0) as recorded,
      coalesce(sum(c.total_amount) filter (where c.status = 'charged'), 0) as charged,
      coalesce(sum(c.total_amount) filter (where c.status = 'waived'), 0) as waived,
      coalesce(sum(c.total_amount) filter (where c.status = 'late_charge'), 0) as late_charge,
      coalesce(sum(c.total_amount) filter (where c.status = 'pending_charge'), 0) as pending
    from public.minibar_checks c cross join p
    where c.property_id = p_property_id and c.business_date between p.d_from and p.d_to
  ),
  stale as (
    select coalesce(sum(c.total_amount), 0) as pending_stale
    from public.minibar_checks c cross join p
    where c.property_id = p_property_id
      and c.status = 'pending_charge' and c.business_date < p.d_from
  ),
  lavie as (
    select
      coalesce(sum(l.missing_qty) filter (where c.status = 'charged'), 0) as units,
      coalesce(sum(l.amount) filter (where c.status = 'charged'), 0) as revenue
    from public.minibar_check_lines l
    join public.minibar_checks c on c.id = l.check_id
    join public.items i on i.id = l.item_id
    cross join p
    where c.property_id = p_property_id and c.business_date between p.d_from and p.d_to
      and (lower(i.code) like '%lavie%' or lower(i.name) like '%lavie%')
  ),
  dasani as (
    select -coalesce(sum(m.qty), 0) as units
    from public.stock_moves m
    join public.items i on i.id = m.item_id
    cross join p
    where m.property_id = p_property_id
      and m.move_type = 'purpose_issue' and m.purpose_code = 'housekeeping'
      and m.business_date between p.d_from and p.d_to
      and lower(i.name) like '%dasani%'
  ),
  room_nights as (
    select count(distinct c.room_id)::bigint as n
    from public.minibar_checks c cross join p
    where c.property_id = p_property_id and c.status = 'charged'
      and c.business_date between p.d_from and p.d_to
  ),
  rows as (
    select jsonb_build_object(
      'item_id', pi.item_id, 'item_code', pi.code, 'item_name', pi.name,
      'units_sold', pi.units_sold, 'revenue', pi.revenue,
      'cogs', coalesce(cs.cogs, 0),
      'gross_profit', pi.revenue - coalesce(cs.cogs, 0),
      'waived', pi.waived, 'late_charge', pi.late_charge
    ) as row,
    pi.revenue as revenue, coalesce(cs.cogs, 0) as cogs
    from per_item pi
    left join costs cs on cs.item_id = pi.item_id
    order by pi.revenue desc
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_MINIBAR',
    'params', jsonb_build_object('from', p.d_from, 'to', p.d_to),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'revenue', coalesce((select sum(r.revenue) from rows r), 0),
      'cogs', coalesce((select sum(r.cogs) from rows r), 0),
      'gross_profit', coalesce((select sum(r.revenue - r.cogs) from rows r), 0),
      'recorded', (select recorded from recon),
      'charged', (select charged from recon),
      'waived', (select waived from recon),
      'late_charge', (select late_charge from recon),
      'pending', (select pending from recon),
      'pending_stale', (select pending_stale from stale),
      'diff', (select recorded - (charged + waived + late_charge) from recon),
      'lavie_units', (select units from lavie),
      'lavie_revenue', (select revenue from lavie),
      'dasani_units', (select units from dasani),
      'room_nights', (select n from room_nights),
      'lavie_per_roomnight', case when (select n from room_nights) > 0
        then round((select units from lavie)::numeric / (select n from room_nights), 2) end,
      'dasani_per_roomnight', case when (select n from room_nights) > 0
        then round((select units from dasani)::numeric / (select n from room_nights), 2) end),
    'notes', jsonb_build_array(
      'Gia von lay tu move minibar_sale; doi soat: ghi nhan = da thu + mien + thu muon (lech != 0 la MINIBAR_MISMATCH).',
      'Lavie = mon co ma/ten chua "lavie" tren phieu da thu; Dasani = tieu hao housekeeping co ten chua "dasani"; dem phong = so phong distinct co phieu da thu trong ky (tam tinh, Q62).')
  ) from p;
$$;
revoke all on function public._report_minibar(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPT_AMENITY_CPOR — tieu hao amenities, chi phi tren dem phong theo nhom
--     Nguon: purpose_issue 'housekeeping' (tieu hao ca xe day, T-034) tren
--     stock_moves; mau so rooms_sold thang (pms_daily_stats — Q64).
-- ---------------------------------------------------------------------------
create or replace function public._report_amenity_cpor(
  p_property_id uuid, p_params jsonb
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (
    select
      coalesce(p_params ->> 'month', to_char(public._report_today(), 'YYYY-MM')) as month,
      (coalesce(p_params ->> 'month', to_char(public._report_today(), 'YYYY-MM')) || '-01')::date as m_from,
      ((coalesce(p_params ->> 'month', to_char(public._report_today(), 'YYYY-MM')) || '-01')::date
        + interval '1 month' - interval '1 day')::date as m_to
  ),
  rooms_sold as (
    select public._report_rooms_sold(p_property_id, p.m_from, p.m_to) as rs from p
  ),
  agg as (
    select ig.id as group_id, ig.name as group_name, ig.kind,
      -sum(m.qty) as qty, -sum(m.amount) as cost
    from public.stock_moves m
    join public.items i on i.id = m.item_id
    join public.item_groups ig on ig.id = i.group_id
    cross join p
    where m.property_id = p_property_id
      and m.move_type = 'purpose_issue' and m.purpose_code = 'housekeeping'
      and m.business_date between p.m_from and p.m_to
      and ig.kind in ('amenity', 'complimentary', 'collateral', 'linen', 'chemical', 'tool')
    group by ig.id, ig.name, ig.kind
  ),
  rows as (
    select jsonb_build_object(
      'group_id', a.group_id, 'group_name', a.group_name, 'kind', a.kind,
      'qty', a.qty, 'cost', a.cost,
      'cost_per_roomnight', case when (select rs from rooms_sold) > 0
        then round(a.cost / (select rs from rooms_sold), 2) end
    ) as row,
    a.cost as cost
    from agg a
    order by a.cost desc
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_AMENITY_CPOR',
    'params', jsonb_build_object('month', p.month),
    'rows', coalesce((select jsonb_agg(r.row) from rows r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'total_cost', coalesce((select sum(r.cost) from rows r), 0),
      'rooms_sold', (select rs from rooms_sold),
      'cost_per_roomnight', case when (select rs from rooms_sold) > 0
        then round(coalesce((select sum(r.cost) from rows r), 0) / (select rs from rooms_sold), 2) end),
    'notes', jsonb_build_array(
      'Tieu hao amenities = purpose_issue housekeeping (ca xe day); chi phi tren dem phong = chi phi / rooms_sold thang.')
  ) from p;
$$;
revoke all on function public._report_amenity_cpor(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 12. RPT_DAILY_BRIEF — ban tin 8h (noi bo; report_build_daily luu snapshot)
-- ---------------------------------------------------------------------------
create or replace function public._build_daily_brief(
  p_property_id uuid, p_date date
)
returns jsonb
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  with p as (select p_date as d),
  purchase_yesterday as (
    select coalesce(sum(g.total_amount), 0) as v
    from public.goods_receipts g cross join p
    where g.property_id = p_property_id and g.status = 'posted'
      and (g.received_at at time zone 'Asia/Ho_Chi_Minh')::date = p.d - 1
  ),
  waste_yesterday as (
    select coalesce(sum(l.qty_stock * l.unit_cost), 0) as v
    from public.waste_reports wr
    join public.waste_report_lines l on l.waste_report_id = wr.id
    cross join p
    where wr.property_id = p_property_id and wr.status = 'posted'
      and wr.business_date = p.d - 1
  ),
  red_unacked as (
    select count(*)::bigint as n
    from public.alerts a
    where a.property_id = p_property_id and a.severity = 'red' and a.ack_at is null
  ),
  ap_due_7d as (
    select coalesce(sum(o.amount), 0) as v
    from public._report_ap_outstanding(p_property_id, (select d from p)) o
    cross join p
    where o.due_date between p.d and p.d + 7
  ),
  advances_overdue as (
    select count(*)::bigint as n, coalesce(sum(a.amount), 0) as v
    from public.advances a
    where a.property_id = p_property_id
      and (a.status = 'overdue'
        or (a.status in ('disbursed', 'settling') and a.due_settle_at is not null and a.due_settle_at < now()))
  ),
  red_list as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', a.id, 'code', a.code, 'title', a.title,
      'doc_type', a.doc_type, 'doc_id', a.doc_id,
      'created_at', a.created_at, 'acked', a.ack_at is not null
    ) order by a.created_at desc), '[]'::jsonb) as items
    from public.alerts a
    where a.property_id = p_property_id and a.severity = 'red'
      and a.created_at >= now() - interval '24 hours'
  ),
  contracts_expiring as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'contract_id', sc.id, 'title', sc.title,
      'supplier_id', sc.supplier_id, 'supplier_name', s.name,
      'end_date', sc.end_date,
      'days_left', sc.end_date - (select d from p)
    ) order by sc.end_date), '[]'::jsonb) as items
    from public.service_contracts sc
    join public.suppliers s on s.id = sc.supplier_id
    cross join p
    where sc.property_id = p_property_id and sc.status = 'active'
      and sc.end_date is not null
      and sc.end_date between p.d and p.d + sc.renew_notice_days
  ),
  schedules_unaccepted as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'schedule_id', ss.id, 'contract_id', ss.contract_id,
      'contract_title', sc.title,
      'period_start', ss.period_start, 'period_end', ss.period_end,
      'due_date', ss.due_date, 'status', ss.status
    ) order by ss.period_end), '[]'::jsonb) as items
    from public.service_schedules ss
    join public.service_contracts sc on sc.id = ss.contract_id
    cross join p
    where ss.property_id = p_property_id
      and ss.status in ('scheduled', 'performed')
      and ss.period_end <= p.d + 7
  )
  select jsonb_build_object(
    'ok', true, 'code', 'RPT_DAILY_BRIEF',
    'date', p.d,
    'purchase_yesterday', (select v from purchase_yesterday),
    'waste_yesterday', (select v from waste_yesterday),
    'red_alerts_unacked', (select n from red_unacked),
    'ap_due_7d', (select v from ap_due_7d),
    'advances_overdue', jsonb_build_object(
      'count', (select n from advances_overdue),
      'amount', (select v from advances_overdue)),
    'red_alerts_24h', (select items from red_list),
    'contracts_expiring', (select items from contracts_expiring),
    'schedules_unaccepted', (select items from schedules_unaccepted),
    'notes', jsonb_build_array(
      'Chi mua hang hom qua = tong phieu nhan posted nhan ngay hom qua; cong no den han 7 ngay = cong no rong FIFO co han tra trong 7 ngay toi.')
  ) from p;
$$;
revoke all on function public._build_daily_brief(uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 13. Diem vao cong khai: report_get (doc bao cao) + report_build_daily
-- ---------------------------------------------------------------------------
create or replace function public.report_get(
  p_property_id uuid, p_code text, p_params jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_perm text;
  v_params jsonb := coalesce(p_params, '{}'::jsonb);
  v_from date;
  v_to date;
begin
  if not exists (select 1 from public.properties where id = p_property_id) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_perm := 'report.view.' || lower(p_code);
  if not exists (select 1 from public.permissions where code = v_perm) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(p_property_id, v_perm);

  v_from := (v_params ->> 'from')::date;
  v_to := (v_params ->> 'to')::date;
  if v_from is not null and v_to is not null and v_from > v_to then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  case upper(p_code)
    when 'RPT_STOCK_CARD' then return public._report_stock_card(p_property_id, v_params);
    when 'RPT_RECEIVING_QUALITY' then return public._report_receiving_quality(p_property_id, v_params);
    when 'RPT_OPEN_PO_INVOICE' then return public._report_open_po_invoice(p_property_id, v_params);
    when 'RPT_AP_AGING' then return public._report_ap_aging(p_property_id, v_params);
    when 'RPT_ADVANCES' then return public._report_advances(p_property_id, v_params);
    when 'RPT_WASTE' then return public._report_waste(p_property_id, v_params);
    when 'RPT_OPEX' then return public._report_opex(p_property_id, v_params);
    when 'RPT_MINIBAR' then return public._report_minibar(p_property_id, v_params);
    when 'RPT_AMENITY_CPOR' then return public._report_amenity_cpor(p_property_id, v_params);
    when 'RPT_DAILY_BRIEF' then
      return public._build_daily_brief(
        p_property_id,
        coalesce((v_params ->> 'date')::date, public._report_today()));
    else raise exception 'ERR_INVALID_VALUE';
  end case;
end $$;
revoke all on function public.report_get(uuid, text, jsonb) from public, anon;
grant execute on function public.report_get(uuid, text, jsonb) to authenticated;

-- Xay ban tin 8h va luu snapshot (goi tay hoac pg_cron luc 07:30 o T-045).
-- Khong require_perm (cron-callable, tien le minibar_reconcile).
create or replace function public.report_build_daily(
  p_property_id uuid, p_date date default null
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_date date := coalesce(p_date, public._report_today());
  v_org uuid;
  v_entity uuid;
  v_payload jsonb;
begin
  select org_id, legal_entity_id into v_org, v_entity
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_payload := public._build_daily_brief(p_property_id, v_date);

  perform set_config('app.report_guard_bypass', 'on', true);
  insert into public.report_snapshots
    (org_id, legal_entity_id, property_id, report_code, business_date, data)
  values (v_org, v_entity, p_property_id, 'RPT_DAILY_BRIEF', v_date, v_payload)
  on conflict (property_id, report_code, business_date)
  do update set data = excluded.data, updated_at = now();

  return v_payload;
end $$;
revoke all on function public.report_build_daily(uuid, date) from public, anon;
grant execute on function public.report_build_daily(uuid, date) to authenticated;
