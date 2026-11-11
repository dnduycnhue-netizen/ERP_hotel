-- C10 (completion wave 2) — hieu nang bao cao + dashboard.
--   1. Materialized view cho bao cao nang nhat (M09 yeu cau, hien chua co):
--      RPT_STOCK_CARD (_report_stock_card, T-044). Ly do chon:
--        - La bao cao DUY NHAT quet lai TOAN BO so cai stock_moves moi lan
--          chay: ton dau ky = tong moi but toan truoc ngay bat dau (lich su
--          khong gioi han, so cai chi INSERT them), gop theo
--          (kho, ma, lo) + tong co dieu kien nhap/xuat trong ky.
--        - Cac bao cao khac deu bi gioi han: theo thang (RPT_OPEX,
--          RPT_AMENITY_CPOR), theo khoang ngay (RPT_MINIBAR, RPT_WASTE,
--          RPT_RECEIVING_QUALITY), theo so dong nho (RPT_ADVANCES,
--          RPT_OPEN_PO_INVOICE), hoac quet ap_ledger theo as_of
--          (RPT_AP_AGING — nho hon stock_moves nhieu).
--        - Tong hop theo ngay la dang tu nhien: 1 dong MV thay cho moi
--          but toan cung (property, kho, ma, lo, ngay); ton dau / nhap /
--          xuat tinh lai tu MV cho ket qua giong het ban goc.
--      Danh doi: du lieu the kho chi moi sau moi lan lam moi (07:35
--      hang ngay + RPC thu cong). Ghi ro trong notes cua bao cao.
--   2. Dashboard gom thanh 1 RPC: property_dashboard_overview (Q125 —
--      CHI lam phan ky thuat; khong sua docs/OPEN-QUESTIONS.md, Q125 giu
--      nguyen trang thai mo cho Duy chot).
--   3. Lich pg_cron lam moi MV 07:35 VN (00:35 UTC), ngay sau lich xay
--      ban tin 8h 07:30 cua T-045 (notification-build-daily) — do la diem
--      lam moi tu nhien cua code bao cao (sau report_build_daily).
--   KHONG dung REFRESH CONCURRENTLY: lenh do khong chay duoc trong
--   transaction block (ham plpgsql + pg_cron deu chay trong transaction),
--   nen dung REFRESH thuong — khoa doc MV rat ngan luc 07:35 + khi goi tay.
--   MV chi doc qua RPC SECURITY DEFINER, khong mo policy truc tiep
--   (materialized view khong ho tro RLS); khong grant select cho ai.

-- ---------------------------------------------------------------------------
-- 1. Materialized view: tong hop stock_moves theo ngay.
-- ---------------------------------------------------------------------------
create materialized view public.mv_report_stock_card_daily as
select
  m.property_id,
  m.warehouse_id,
  m.item_id,
  m.lot_id,
  m.business_date,
  sum(m.qty) as qty,
  sum(m.amount) as amount,
  count(*)::bigint as move_count
from public.stock_moves m
group by m.property_id, m.warehouse_id, m.item_id, m.lot_id, m.business_date;

comment on materialized view public.mv_report_stock_card_daily is
  'C10: tong hop stock_moves theo ngay cho RPT_STOCK_CARD; lam moi 07:35 hang ngay (pg_cron report-stock-card-mv-refresh) + RPC report_refresh_stock_card_mv().';

-- Bao cao loc theo property + khoang ngay: index nay phuc vu dung mau do.
create index mv_report_stock_card_daily_property_date_idx
  on public.mv_report_stock_card_daily (property_id, business_date);

-- Chi doc qua RPC SECURITY DEFINER (report_get -> _report_stock_card,
-- report_refresh_stock_card_mv); khong cap quyen truc tiep cho role nao.
revoke all on table public.mv_report_stock_card_daily
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. RPT_STOCK_CARD doc tu MV thay vi quet stock_moves.
--    Hop dong tra ve giu nguyen (ok/code/params/rows/totals/notes); chi
--    them 1 dong notes ve do tuoi du lieu cua MV.
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
    from public.mv_report_stock_card_daily m cross join p
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
      'Gia tri ton tinh tu so cai stock_moves (don gia cua tung but toan); ton dau ky = tong cac but toan truoc ngay bat dau.',
      'So lieu doc tu bang tong hop theo ngay (materialized view), lam moi luc 07:35 hang ngay sau khi xay ban tin 8h; chung tu phat sinh sau lan lam moi chua hien — goi report_refresh_stock_card_mv() de lam moi ngay.')
  ) from p;
$$;
revoke all on function public._report_stock_card(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC lam moi MV (thu cong + pg_cron).
--    - Duong cron (pg_cron khong co JWT, auth.uid() null): cho phep,
--      tien le report_build_daily / minibar_reconcile (khong require_perm).
--    - Duong goi tay: can report.view.rpt_stock_card tren it nhat 1 KS
--      truy cap duoc. Lam moi chi xay lai cache toan chuoi, khong doi
--      du lieu goc, nen khong doi hoi quyen cap chuoi.
-- ---------------------------------------------------------------------------
create or replace function public.report_refresh_stock_card_mv()
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_rows bigint;
begin
  if auth.uid() is not null and not exists (
    select 1
    from public.properties p
    where p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'report.view.rpt_stock_card')
  ) then
    raise exception using
      errcode = '42501',
      message = 'ERR_FORBIDDEN:report.view.rpt_stock_card';
  end if;

  refresh materialized view public.mv_report_stock_card_daily;

  select count(*) into v_rows from public.mv_report_stock_card_daily;
  return jsonb_build_object(
    'ok', true, 'refreshed_at', now(), 'row_count', v_rows);
end $$;
revoke all on function public.report_refresh_stock_card_mv() from public, anon;
grant execute on function public.report_refresh_stock_card_mv() to authenticated;

comment on function public.report_refresh_stock_card_mv() is
  'C10: lam moi mv_report_stock_card_daily (the kho). Cron 07:35 hang ngay + goi tay (can report.view.rpt_stock_card).';

-- ---------------------------------------------------------------------------
-- 4. Dashboard gom thanh 1 RPC (Q125, phan ky thuat).
--    Tra DUNG payload trang tong quan dang hien: thong tin KS + phap nhan
--    + 4 count (mat hang, kho, nhom mat hang, vai tro). KHONG them du lieu
--    moi (trang hien khong co chung tu gan day / tom tat canh bao).
--    SECURITY DEFINER nen phai tai hien dung policy RLS cua cac SELECT
--    cu trong SQL (khong the dua vao RLS nhu ban cu):
--      - properties/legal_entities: chi KS trong my_property_ids().
--      - items/item_groups (policy items_select/item_groups_select): chi
--        hien khi co item.view tren 1 KS cung org; khong co -> 0
--        (dung nhu ban cu: front_desk/owner/gm thieu item.view thay 0).
--      - warehouses (policy warehouses_select): id trong
--        my_warehouse_ids(property) — dung pham vi kho/outlet cua nguoi goi.
--      - roles (policy roles_select): dem theo org khi co KS cung org
--        trong my_property_ids() (da dam bao boi buoc truy cap o tren).
-- ---------------------------------------------------------------------------
create or replace function public.property_dashboard_overview(
  p_property_id uuid
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_prop record;
  v_items bigint := 0;
  v_groups bigint := 0;
  v_wh bigint := 0;
  v_roles bigint := 0;
begin
  select
    p.id, p.code, p.name, p.sod_profile, p.rooms_count, p.org_id,
    le.code as le_code, le.name as le_name,
    le.costing_method as le_costing, le.accounting_regime as le_regime
  into v_prop
  from public.properties p
  left join public.legal_entities le on le.id = p.legal_entity_id
  where p.id = p_property_id;

  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if p_property_id not in (select public.my_property_ids()) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if exists (
    select 1
    from public.properties p
    where p.org_id = v_prop.org_id
      and p.id in (select public.my_property_ids())
      and public.has_perm(p.id, 'item.view')
  ) then
    select count(*) into v_items
    from public.items i where i.org_id = v_prop.org_id;
    select count(*) into v_groups
    from public.item_groups g where g.org_id = v_prop.org_id;
  end if;

  select count(*) into v_wh
  from public.warehouses w
  where w.property_id = p_property_id
    and w.id in (select public.my_warehouse_ids(p_property_id));

  select count(*) into v_roles
  from public.roles r where r.org_id = v_prop.org_id;

  return jsonb_build_object(
    'ok', true,
    'property', jsonb_build_object(
      'id', v_prop.id,
      'code', v_prop.code,
      'name', v_prop.name,
      'sod_profile', v_prop.sod_profile,
      'rooms_count', v_prop.rooms_count,
      'org_id', v_prop.org_id,
      'legal_entity', case when v_prop.le_code is null then 'null'::jsonb
        else jsonb_build_object(
          'code', v_prop.le_code,
          'name', v_prop.le_name,
          'costing_method', v_prop.le_costing,
          'accounting_regime', v_prop.le_regime)
        end),
    'counts', jsonb_build_object(
      'items', v_items,
      'warehouses', v_wh,
      'item_groups', v_groups,
      'roles', v_roles));
end $$;
revoke all on function public.property_dashboard_overview(uuid) from public, anon;
grant execute on function public.property_dashboard_overview(uuid) to authenticated;

comment on function public.property_dashboard_overview(uuid) is
  'C10 (Q125): tong quan 1 KS trong 1 RPC — thong tin KS + phap nhan + 4 count (mat hang, kho, nhom mat hang, vai tro), tai hien dung policy RLS cua cac SELECT cu.';

-- ---------------------------------------------------------------------------
-- 5. pg_cron: lam moi MV 07:35 VN (00:35 UTC), ngay sau lich xay ban tin
--    8h 07:30 cua T-045. pg_cron chay theo UTC (tien le T-045).
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'C10: pg_cron khong cai duoc (%), bo qua lich chay.', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (
      select 1 from cron.job where jobname = 'report-stock-card-mv-refresh'
    ) then
      perform cron.schedule(
        'report-stock-card-mv-refresh',
        '35 0 * * *',
        'select public.report_refresh_stock_card_mv()'
      );
    end if;
  end if;
end $$;
