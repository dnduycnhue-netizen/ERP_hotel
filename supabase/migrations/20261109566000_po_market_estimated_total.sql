-- ============================================================================
-- Q173 — 20261109566000_po_market_estimated_total
--   Duy chot 12/11/2026 (phuong an khuyen nghi): PO cho co dong chua co gia
--   phai co TONG UOC TINH; buoc duyet tinh theo so lon hon giua tong dong co
--   gia (total_amount) va tong uoc tinh — khong con tinh thap vi dong gia 0.
--   * purchase_orders.estimated_total (nullable, >= 0).
--   * RPC po_set_estimated_total(property, po, amount): quyen po.create,
--     chi PO cho dang 'draft', amount > 0 (ERR_INVALID_VALUE / ERR_INVALID_STATUS).
--   * po_submit: sinh lai tu 20261109240000, them (1) PO cho co dong gia <= 0
--     ma chua co tong uoc tinh -> ERR_ESTIMATE_REQUIRED; (2) bac duyet theo
--     greatest(total_amount, estimated_total). Khong doi gi khac.
--   Khong bang moi => khong can RLS moi; audit trigger co san tren purchase_orders.
-- ============================================================================

alter table public.purchase_orders
  add column if not exists estimated_total numeric(18,2)
  check (estimated_total is null or estimated_total >= 0);

comment on column public.purchase_orders.estimated_total is
  'Q173: tong tien uoc tinh cua PO cho co dong chua co gia; chi dung de tinh bac duyet.';

create or replace function public.po_set_estimated_total(
  p_property_id uuid,
  p_po_id uuid,
  p_amount numeric
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
  if p_amount is null or p_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  select * into v_po from public.purchase_orders po where po.id = p_po_id;
  if not found or v_po.property_id <> p_property_id
     or v_po.status <> 'draft' or v_po.channel <> 'market' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  update public.purchase_orders
  set estimated_total = round(p_amount, 2) where id = p_po_id;
  return jsonb_build_object('ok', true, 'id', p_po_id, 'estimated_total', round(p_amount, 2));
end;
$$;

revoke all on function public.po_set_estimated_total(uuid, uuid, numeric) from public, anon;
grant execute on function public.po_set_estimated_total(uuid, uuid, numeric) to authenticated, service_role;

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
  -- T-022A (tu phe duyet 10/11, phuong an A): PO cho (channel = 'market')
  -- duoc mien kiem tra gia — gia cho chot luc mua thuc te, dong khong
  -- gia/khong gia tran van submit duoc. PO thuong (contract/quote) van
  -- bi chan khi co dong manual gia <= 0.
  if v_po.channel = 'market' and exists (
    select 1 from public.purchase_order_lines pol
    where pol.po_id = p_po_id and pol.unit_price <= 0
  ) and coalesce(v_po.estimated_total, 0) <= 0 then
    -- Q173: PO cho co dong chua co gia bat buoc co tong uoc tinh de
    -- tinh dung bac duyet.
    raise exception 'ERR_ESTIMATE_REQUIRED';
  end if;
  if v_po.channel <> 'market' and exists (
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
    'po', p_po_id, p_property_id, v_po.org_id,
    greatest(v_po.total_amount, coalesce(v_po.estimated_total, 0))
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
  from public, anon;
grant execute on function public.po_submit(uuid, uuid) to authenticated;
