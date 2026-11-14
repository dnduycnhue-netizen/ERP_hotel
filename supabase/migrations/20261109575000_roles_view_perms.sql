-- Q269 (14/11/2026): theo quyet dinh Duy sau bao cao dem 13-14/11.
--  B-12: sm_manager xem duoc chenh lech kiem ke (count.view_variance) de duyet dieu chinh.
--  B-27: sm_purchasing_store xem gia tri ton (stock.view_value).
--  B-14: sm_purchasing_store de xuat huy hang (waste.propose).
--  B-13: transfer_list/transfer_get cho nguoi co stock.view_qty xem (GM xem dieu chuyen).
--  KHONG cap stock.view_qty cho sm_housekeeping (B-26): kiem minibar la dem mu (quy tac 9).

insert into public.role_permissions (role_id, permission_code)
select r.id, v.perm
from public.roles r
join (values
  ('sm_manager', 'count.view_variance'),
  ('sm_purchasing_store', 'stock.view_value'),
  ('sm_purchasing_store', 'waste.propose')
) as v(code, perm) on v.code = r.code
on conflict do nothing;

CREATE OR REPLACE FUNCTION public.transfer_list(p_property_id uuid, p_status text DEFAULT NULL::text, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'transfer.send')
    or public.has_perm(p_property_id, 'transfer.receive')
    or public.has_perm(p_property_id, 'stock.view_qty')
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
$function$;

CREATE OR REPLACE FUNCTION public.transfer_get(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
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
    or public.has_perm(v_tr.property_id, 'stock.view_qty')
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
$function$;

CREATE OR REPLACE FUNCTION public.seed_compact_roles(p_org_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_n integer;
begin
  insert into public.roles (org_id, code, name_vi, description, is_system)
  select p_org_id, r.code, r.name_vi, r.description, true
  from (
    values
    ('sm_owner', 'Chủ đầu tư', 'Giám sát toàn chuỗi, duyệt việc lớn, bật/tắt module; không làm nghiệp vụ hằng ngày.'),
    ('sm_manager', 'Quản lý', 'Điều hành khách sạn, duyệt đơn mua/hóa đơn/thanh toán/hủy, cấu hình bậc duyệt.'),
    ('sm_accountant', 'Kế toán', 'Hóa đơn, công nợ, tạm ứng, đề nghị thanh toán, đóng kỳ, xuất file kế toán.'),
    ('sm_purchasing_store', 'Thu mua & Thủ kho', 'Yêu cầu/đơn mua, giá, nhà cung cấp, xuất/chuyển/kiểm kê kho. Không nhận hàng (dùng vai trò Nhận hàng).'),
    ('sm_kitchen', 'Bếp / Nhà hàng', 'Món, công thức, buffet, tiệc, bán hàng, phiếu lĩnh, duyệt phiếu bộ phận.'),
    ('sm_housekeeping', 'Buồng phòng', 'Xe đẩy, chuẩn setup phòng, minibar, phiếu lĩnh.'),
    ('sm_frontdesk', 'Lễ tân', 'Số liệu PMS, minibar, bán hàng.')
  ) as r(code, name_vi, description)
  on conflict (org_id, code) do nothing;

  insert into public.role_permissions (role_id, permission_code)
  select ro.id, rp.permission_code
  from public.roles ro
  join (
    values
    ('sm_owner', 'po.view_qty'),
    ('sm_owner', 'admin.alert_rules.manage'),
    ('sm_owner', 'admin.approval_rules.manage'),
    ('sm_owner', 'admin.health.view'),
    ('sm_owner', 'admin.modules.manage'),
    ('sm_owner', 'admin.settings.manage'),
    ('sm_owner', 'advance.approve'),
    ('sm_owner', 'alert.receive.advance_overdue'),
    ('sm_owner', 'alert.receive.avt_daily'),
    ('sm_owner', 'alert.receive.bank_account_change'),
    ('sm_owner', 'alert.receive.count_variance'),
    ('sm_owner', 'alert.receive.minibar_check_requested'),
    ('sm_owner', 'alert.receive.minibar_loss'),
    ('sm_owner', 'alert.receive.minibar_mismatch'),
    ('sm_owner', 'alert.receive.over_ceiling_approved'),
    ('sm_owner', 'alert.receive.period_close_warning'),
    ('sm_owner', 'alert.receive.permission_critical_changed'),
    ('sm_owner', 'alert.receive.photo_reused'),
    ('sm_owner', 'alert.receive.price_spike'),
    ('sm_owner', 'alert.receive.rule_toggled'),
    ('sm_owner', 'alert.receive.service_contract_renewal'),
    ('sm_owner', 'alert.receive.service_unaccepted_payment'),
    ('sm_owner', 'alert.receive.sod_exception_used'),
    ('sm_owner', 'alert.receive.temp_item_stale'),
    ('sm_owner', 'alert.receive.unlock'),
    ('sm_owner', 'alert.receive.waste_large'),
    ('sm_owner', 'alert.receive.water_night_spike'),
    ('sm_owner', 'ap.view'),
    ('sm_owner', 'attachment.view'),
    ('sm_owner', 'audit.view_all'),
    ('sm_owner', 'count.view_variance'),
    ('sm_owner', 'day.unlock'),
    ('sm_owner', 'export.accounting'),
    ('sm_owner', 'item.view'),
    ('sm_owner', 'payment.approve'),
    ('sm_owner', 'period.close'),
    ('sm_owner', 'period.reopen'),
    ('sm_owner', 'po.approve'),
    ('sm_owner', 'po.approve.over_ceiling'),
    ('sm_owner', 'po.view'),
    ('sm_owner', 'po.view_price'),
    ('sm_owner', 'price.view'),
    ('sm_owner', 'report.daily_brief.receive'),
    ('sm_owner', 'report.receive.daily_brief'),
    ('sm_owner', 'report.view.rpt_advances'),
    ('sm_owner', 'report.view.rpt_amenity_cpor'),
    ('sm_owner', 'report.view.rpt_ap_aging'),
    ('sm_owner', 'report.view.rpt_daily_brief'),
    ('sm_owner', 'report.view.rpt_fnb_revenue'),
    ('sm_owner', 'report.view.rpt_minibar'),
    ('sm_owner', 'report.view.rpt_open_po_invoice'),
    ('sm_owner', 'report.view.rpt_opex'),
    ('sm_owner', 'report.view.rpt_receiving_quality'),
    ('sm_owner', 'report.view.rpt_stock_card'),
    ('sm_owner', 'report.view.rpt_waste'),
    ('sm_owner', 'stock.view_value'),
    ('sm_owner', 'supplier.view'),
    ('sm_owner', 'waste.approve.large'),
    ('sm_manager', 'admin.approval_rules.manage'),
    ('sm_manager', 'admin.settings.manage'),
    ('sm_manager', 'po.view'),
    ('sm_manager', 'po.view_price'),
    ('sm_manager', 'po.view_qty'),
    ('sm_manager', 'advance.approve'),
    ('sm_manager', 'alert.receive.advance_overdue'),
    ('sm_manager', 'alert.receive.avt_daily'),
    ('sm_manager', 'alert.receive.bank_account_change'),
    ('sm_manager', 'alert.receive.count_variance'),
    ('sm_manager', 'alert.receive.minibar_check_requested'),
    ('sm_manager', 'alert.receive.minibar_loss'),
    ('sm_manager', 'alert.receive.minibar_mismatch'),
    ('sm_manager', 'alert.receive.over_ceiling_approved'),
    ('sm_manager', 'alert.receive.period_close_warning'),
    ('sm_manager', 'alert.receive.permission_critical_changed'),
    ('sm_manager', 'alert.receive.photo_reused'),
    ('sm_manager', 'alert.receive.price_spike'),
    ('sm_manager', 'alert.receive.rule_toggled'),
    ('sm_manager', 'alert.receive.service_contract_renewal'),
    ('sm_manager', 'alert.receive.service_unaccepted_payment'),
    ('sm_manager', 'alert.receive.sod_exception_used'),
    ('sm_manager', 'alert.receive.temp_item_stale'),
    ('sm_manager', 'alert.receive.unlock'),
    ('sm_manager', 'alert.receive.waste_large'),
    ('sm_manager', 'alert.receive.water_night_spike'),
    ('sm_manager', 'attachment.view'),
    ('sm_manager', 'count.adjust.approve'),
    ('sm_manager', 'count.view_variance'),
    ('sm_manager', 'day.unlock'),
    ('sm_manager', 'invoice.approve'),
    ('sm_manager', 'item.import'),
    ('sm_manager', 'item.view'),
    ('sm_manager', 'minibar.price.manage'),
    ('sm_manager', 'minibar.reconcile'),
    ('sm_manager', 'minibar.waive.approve'),
    ('sm_manager', 'payment.approve'),
    ('sm_manager', 'pms.input'),
    ('sm_manager', 'po.approve'),
    ('sm_manager', 'po.approve.over_ceiling'),
    ('sm_manager', 'pos.import'),
    ('sm_manager', 'pr.approve'),
    ('sm_manager', 'price.view'),
    ('sm_manager', 'purpose_issue.post'),
    ('sm_manager', 'purpose_issue.reverse'),
    ('sm_manager', 'receiving.override_over_po'),
    ('sm_manager', 'receiving.reverse'),
    ('sm_manager', 'report.daily_brief.receive'),
    ('sm_manager', 'report.receive.daily_brief'),
    ('sm_manager', 'report.view.rpt_advances'),
    ('sm_manager', 'report.view.rpt_amenity_cpor'),
    ('sm_manager', 'report.view.rpt_ap_aging'),
    ('sm_manager', 'report.view.rpt_daily_brief'),
    ('sm_manager', 'report.view.rpt_fnb_revenue'),
    ('sm_manager', 'report.view.rpt_minibar'),
    ('sm_manager', 'report.view.rpt_open_po_invoice'),
    ('sm_manager', 'report.view.rpt_opex'),
    ('sm_manager', 'report.view.rpt_receiving_quality'),
    ('sm_manager', 'report.view.rpt_stock_card'),
    ('sm_manager', 'report.view.rpt_waste'),
    ('sm_manager', 'requisition.approve'),
    ('sm_manager', 'restaurant.banquet.manage'),
    ('sm_manager', 'restaurant.buffet.manage'),
    ('sm_manager', 'restaurant.dish.manage'),
    ('sm_manager', 'restaurant.sale.record'),
    ('sm_manager', 'restaurant.view'),
    ('sm_manager', 'room.manage'),
    ('sm_manager', 'service.contract.manage'),
    ('sm_manager', 'stock.view_qty'),
    ('sm_manager', 'supplier.approve'),
    ('sm_manager', 'supplier.view'),
    ('sm_manager', 'waste.approve'),
    ('sm_manager', 'waste.approve.large'),
    ('sm_accountant', 'po.view'),
    ('sm_accountant', 'po.view_price'),
    ('sm_accountant', 'po.view_qty'),
    ('sm_accountant', 'advance.disburse'),
    ('sm_accountant', 'advance.settle'),
    ('sm_accountant', 'alert.receive.advance_overdue'),
    ('sm_accountant', 'alert.receive.avt_daily'),
    ('sm_accountant', 'alert.receive.bank_account_change'),
    ('sm_accountant', 'alert.receive.over_ceiling_approved'),
    ('sm_accountant', 'alert.receive.period_close_warning'),
    ('sm_accountant', 'alert.receive.permission_critical_changed'),
    ('sm_accountant', 'alert.receive.photo_reused'),
    ('sm_accountant', 'alert.receive.price_spike'),
    ('sm_accountant', 'alert.receive.service_contract_renewal'),
    ('sm_accountant', 'alert.receive.service_unaccepted_payment'),
    ('sm_accountant', 'alert.receive.sod_exception_used'),
    ('sm_accountant', 'alert.receive.temp_item_stale'),
    ('sm_accountant', 'alert.receive.unlock'),
    ('sm_accountant', 'alert.receive.waste_large'),
    ('sm_accountant', 'ap.view'),
    ('sm_accountant', 'attachment.upload'),
    ('sm_accountant', 'attachment.view'),
    ('sm_accountant', 'count.lock'),
    ('sm_accountant', 'day.lock'),
    ('sm_accountant', 'export.accounting'),
    ('sm_accountant', 'invoice.manage'),
    ('sm_accountant', 'item.import'),
    ('sm_accountant', 'item.manage'),
    ('sm_accountant', 'item.view'),
    ('sm_accountant', 'payment.mark_paid'),
    ('sm_accountant', 'payment.request'),
    ('sm_accountant', 'period.close'),
    ('sm_accountant', 'period.reopen'),
    ('sm_accountant', 'pms.input'),
    ('sm_accountant', 'pos.import'),
    ('sm_accountant', 'price.ceiling.manage'),
    ('sm_accountant', 'price.view'),
    ('sm_accountant', 'receiving.view'),
    ('sm_accountant', 'report.view.rpt_ap_aging'),
    ('sm_accountant', 'report.view.rpt_opex'),
    ('sm_accountant', 'supplier.approve'),
    ('sm_accountant', 'supplier.bank.approve'),
    ('sm_accountant', 'supplier.view'),
    ('sm_purchasing_store', 'advance.request'),
    ('sm_purchasing_store', 'attachment.upload'),
    ('sm_purchasing_store', 'attachment.view'),
    ('sm_purchasing_store', 'count.open'),
    ('sm_purchasing_store', 'count.perform'),
    ('sm_purchasing_store', 'item.manage'),
    ('sm_purchasing_store', 'item.temp.create'),
    ('sm_purchasing_store', 'item.view'),
    ('sm_purchasing_store', 'market.order.create'),
    ('sm_purchasing_store', 'po.close'),
    ('sm_purchasing_store', 'po.create'),
    ('sm_purchasing_store', 'po.view'),
    ('sm_purchasing_store', 'po.view_price'),
    ('sm_purchasing_store', 'po.view_qty'),
    ('sm_purchasing_store', 'pr.create'),
    ('sm_purchasing_store', 'price.agreement.manage'),
    ('sm_purchasing_store', 'price.view'),
    ('sm_purchasing_store', 'purpose_issue.post'),
    ('sm_purchasing_store', 'receiving.view'),
    ('sm_purchasing_store', 'requisition.issue'),
    ('sm_purchasing_store', 'stock.view_qty'),
    ('sm_purchasing_store', 'stock.view_value'),
    ('sm_purchasing_store', 'supplier.bank.request'),
    ('sm_purchasing_store', 'supplier.manage'),
    ('sm_purchasing_store', 'supplier.view'),
    ('sm_purchasing_store', 'supplier_return.post'),
    ('sm_purchasing_store', 'transfer.receive'),
    ('sm_purchasing_store', 'transfer.send'),
    ('sm_purchasing_store', 'warehouse.manage'),
    ('sm_purchasing_store', 'waste.propose'),
    ('sm_kitchen', 'attachment.upload'),
    ('sm_kitchen', 'attachment.view'),
    ('sm_kitchen', 'count.perform'),
    ('sm_kitchen', 'item.view'),
    ('sm_kitchen', 'pr.approve'),
    ('sm_kitchen', 'pr.create'),
    ('sm_kitchen', 'purpose_issue.post'),
    ('sm_kitchen', 'receiving.view'),
    ('sm_kitchen', 'requisition.approve'),
    ('sm_kitchen', 'requisition.create'),
    ('sm_kitchen', 'requisition.receive'),
    ('sm_kitchen', 'restaurant.banquet.manage'),
    ('sm_kitchen', 'restaurant.buffet.manage'),
    ('sm_kitchen', 'restaurant.dish.manage'),
    ('sm_kitchen', 'restaurant.sale.record'),
    ('sm_kitchen', 'restaurant.view'),
    ('sm_kitchen', 'stock.view_qty'),
    ('sm_kitchen', 'waste.propose'),
    ('sm_housekeeping', 'alert.receive.minibar_check_requested'),
    ('sm_housekeeping', 'attachment.upload'),
    ('sm_housekeeping', 'attachment.view'),
    ('sm_housekeeping', 'hk.standard.manage'),
    ('sm_housekeeping', 'hk.trolley.operate'),
    ('sm_housekeeping', 'item.view'),
    ('sm_housekeeping', 'minibar.check'),
    ('sm_housekeeping', 'minibar.price.manage'),
    ('sm_housekeeping', 'minibar.refill'),
    ('sm_housekeeping', 'requisition.approve'),
    ('sm_housekeeping', 'requisition.create'),
    ('sm_housekeeping', 'requisition.issue'),
    ('sm_housekeeping', 'requisition.receive'),
    ('sm_housekeeping', 'room.manage'),
    ('sm_housekeeping', 'waste.propose'),
    ('sm_frontdesk', 'attachment.upload'),
    ('sm_frontdesk', 'attachment.view'),
    ('sm_frontdesk', 'item.view'),
    ('sm_frontdesk', 'minibar.charge.confirm'),
    ('sm_frontdesk', 'minibar.request_check'),
    ('sm_frontdesk', 'minibar.waive.request'),
    ('sm_frontdesk', 'pms.input'),
    ('sm_frontdesk', 'restaurant.banquet.manage'),
    ('sm_frontdesk', 'restaurant.sale.record'),
    ('sm_frontdesk', 'restaurant.view'),
    ('sm_frontdesk', 'stock.view_qty')
  ) as rp(role_code, permission_code) on rp.role_code = ro.code
  where ro.org_id = p_org_id
  on conflict (role_id, permission_code) do nothing;

  select count(*) into v_n from public.roles
  where org_id = p_org_id and code like 'sm\_%';
  return v_n;
end;
$function$;
