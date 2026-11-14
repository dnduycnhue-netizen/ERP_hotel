-- Q276 (14/11/2026): bao cao cycle C5-N1 — khong co duong giao dien nhap hang vao kho minibar tong
-- (receiving_start chi nhan kho main/outlet/floor). Them minibar_main: PO hang minibar nhan vao kho
-- minibar tong roi cap bu cho phong bang minibar_refill.
CREATE OR REPLACE FUNCTION public.receiving_start(p_po_id uuid, p_warehouse_id uuid, p_direct_issue_wh uuid DEFAULT NULL::uuid, p_client_uuid uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    or v_wh.kind not in ('main', 'outlet', 'floor', 'minibar_main') then
    raise exception using errcode = 'P0001', message = 'ERR_WAREHOUSE_NOT_FOUND';
  end if;

  if p_direct_issue_wh is not null then
    select w.* into v_wh_direct
    from public.warehouses w
    where w.id = p_direct_issue_wh;

    if v_wh_direct.id is null
      or v_wh_direct.property_id <> v_po.property_id
      or v_wh_direct.kind not in ('main', 'outlet', 'floor', 'minibar_main') then
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
$function$;
