-- 20261109240000_t022a_market_po_price_exemption.sql
--
-- T-022A: mien kiem tra gia cho PO cho trong po_submit (phuong an A).
-- Quyet dinh: tu phe duyet 10/11/2026 (chon A thay vi B) — spec M03 khong
-- noi ro dong PO cho khong gia co duoc submit khong; PO cho mua theo gia
-- thuc te luc di cho (khong co gia tran, khong co bao gia), nen chan
-- submit vi thieu gia la sai nghiep vu. PO thuong (contract/quote) van
-- bi chan ERR_PRICE_NOT_SET khi co dong manual gia <= 0 (suite T-020
-- van giu assertion nay).
-- Thay doi duy nhat: dieu kien kiem tra gia trong po_submit them
-- `v_po.channel <> 'market'`. Khong doi: quy trinh duyet (so buoc theo
-- total_amount), SoD, kiem tra vuot tran + ly do, quyen po.create.
-- Test: supabase/tests/market_advances_test.sql plan 56 -> 58
-- (2 assertion moi ghim hanh vi mien tru; assertion po_submit PO market
-- cu hien PASS thay vi P0001). Suite T-020 (128) khong doi.
-- Luu y db push: version 240000 cu hon nhieu migration da ap — chay
-- `supabase db push --remote --include-all` (tien le 290000).

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
