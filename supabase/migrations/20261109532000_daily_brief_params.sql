-- ===========================================================================
-- Q205 — Ban tin 8h sap vi _build_daily_brief thieu 'params' (11/11/2026).
--
-- NGUYEN NHAN GOC: moi builder bao cao khac deu tra 'params' trong JSON
--   (xem 20261109370000: 9 cho + _report_fnb_revenue o 500000), rieng
--   _build_daily_brief khong co. Trang [code]/page.tsx doc
--   payload.params[key] de nap bo loc -> TypeError (undefined[key])
--   -> error boundary cua (app) hien "Khong the tai trang". Loi tai
--   hien 3/3 lan thu tren live (09:00 11/11); trang the kho (co params)
--   tai binh thuong nen day khong phai loi quyen/du lieu.
--
-- CACH SUA: dinh nghia lai _build_daily_brief, them dong params duy nhat
--   ('date', p.d) — dung mau cac builder khac. Ham la `language sql` nen
--   Postgres kiem tra ngay luc CREATE. Khong doi RPC, khong doi quyen.
--   Trang [code]/page.tsx them phong thu `payload.params ?? {}` de mot
--   builder nao quen params sau nay cung khong lam sap ca trang.
-- ===========================================================================

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
    'params', jsonb_build_object('date', p.d),
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
