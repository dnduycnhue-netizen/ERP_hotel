-- C1 (man khoa ngay / khoa ky): RPC chi doc xem truoc dieu kien khoa ky.
--
-- `day_lock`, `day_unlock`, `period_close`, `period_reopen` da co tu
-- 20261109120000 (`period_close` duoc dinh nghia lai +3 dieu kien o
-- 20261109280000) nen KHONG tao them RPC ghi. Chi thieu mot RPC doc de
-- man `/[property]/inventory/locks` hien DUOC dieu kien nao dang chan
-- (thay vi chi bao loi sau khi bam khoa ky) va trang thai dong bang
-- kiem dem theo kho — 2 thu nay nam o `stock_counts` (khong co trong
-- `database.types.ts`) nen phai tinh o server, khong doc truc tiep tu UI.
--
-- Dieu kien 1-3 sao chep y het `period_close` (05 §10): kho thieu dot
-- monthly_full thang do o 'locked'/'adjusted'; PO partially_received
-- co expected_date qua 30 ngay; tam ung 'overdue'. Chi doc, khong ghi,
-- khong doi so lieu — tra ve chi so dem + ten kho/dot kiem (khong co
-- so tien hay ton so), nen chi can nguoi goi thuoc 1 property cua phap
-- nhan (khong yeu cau rieng 'period.close' de ke toan cung xem duoc).

create or replace function public.period_close_check(
  p_entity_id uuid,
  p_year integer,
  p_month integer
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_already_closed boolean;
  v_missing jsonb;
  v_po_count integer;
  v_advance_count integer;
  v_frozen jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_entity_id is null or p_year is null or p_year < 1
    or p_month is null or p_month not between 1 and 12 then
    raise exception using errcode = '22023', message = 'ERR_INVALID_INPUT';
  end if;

  -- Nguoi goi phai thuoc it nhat 1 property cua phap nhan (giong RLS
  -- `accounting_periods_select`); khong mo cho nguoi ngoai phap nhan.
  if not exists (
    select 1 from public.properties p
    where p.legal_entity_id = p_entity_id
      and p.id in (select public.my_property_ids())
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  select exists (
    select 1 from public.accounting_periods
    where legal_entity_id = p_entity_id
      and year = p_year and month = p_month and status = 'closed'
  ) into v_already_closed;

  -- Dieu kien 1 (giong period_close): moi kho cua phap nhan (da ton tai
  -- trong thang) phai co dot monthly_full thang do o 'locked'/'adjusted'.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'warehouse_id', w.id,
        'warehouse_name', w.name,
        'property_id', w.property_id
      )
      order by w.name
    ),
    '[]'::jsonb
  )
  into v_missing
  from public.properties p
  join public.warehouses w on w.property_id = p.id
  where p.legal_entity_id = p_entity_id
    and w.created_at < (make_date(p_year, p_month, 1) + interval '1 month')
    and not exists (
      select 1 from public.stock_counts c
      where c.warehouse_id = w.id
        and c.kind = 'monthly_full'
        and extract(year from c.business_date)::integer = p_year
        and extract(month from c.business_date)::integer = p_month
        and c.status in ('locked', 'adjusted')
    );

  -- Dieu kien 2 (giong period_close): PO partially_received qua 30 ngay.
  select count(*)
  into v_po_count
  from public.purchase_orders po
  join public.properties p on p.id = po.property_id
  where p.legal_entity_id = p_entity_id
    and po.status = 'partially_received'
    and po.expected_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date - interval '30 days';

  -- Dieu kien 3 (giong period_close): tam ung qua han.
  select count(*)
  into v_advance_count
  from public.advances a
  join public.properties p on p.id = a.property_id
  where p.legal_entity_id = p_entity_id
    and a.status = 'overdue';

  -- Trang thai dong bang kiem dem hien tai (giong trigger
  -- `_count_freeze_guard`): kho co dot monthly_full dang mo
  -- ('open'/'counting'/'recount'/'submitted'/'locked') thi tam dung
  -- ghi nhan xuat nhap. Lay dot mo moi nhat cua moi kho.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'warehouse_id', w.id,
        'warehouse_name', w.name,
        'property_id', w.property_id,
        'count_id', c.id,
        'count_doc_no', c.doc_no,
        'count_status', c.status
      )
      order by w.name
    ),
    '[]'::jsonb
  )
  into v_frozen
  from public.properties p
  join public.warehouses w on w.property_id = p.id
  join lateral (
    select c.id, c.doc_no, c.status
    from public.stock_counts c
    where c.warehouse_id = w.id
      and c.kind = 'monthly_full'
      and c.status in ('open', 'counting', 'recount', 'submitted', 'locked')
    order by c.created_at desc
    limit 1
  ) c on true
  where p.legal_entity_id = p_entity_id;

  return jsonb_build_object(
    'ok', true,
    'already_closed', v_already_closed,
    'count_blocked', jsonb_array_length(v_missing) > 0,
    'missing_counts', v_missing,
    'po_blocked', v_po_count > 0,
    'po_count', v_po_count,
    'advance_blocked', v_advance_count > 0,
    'advance_count', v_advance_count,
    'frozen_warehouses', v_frozen
  );
end;
$$;

revoke all on function public.period_close_check(uuid, integer, integer)
  from public, anon;
grant execute on function public.period_close_check(uuid, integer, integer)
  to authenticated;
