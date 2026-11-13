-- ============================================================================
-- Q257 — 20261109570000_compact_role_profiles
--   Bo 7 vai tro mau GON cho khach san nho (docs/go-live/role-profiles-proposal.md,
--   Duy duyet 13/11/2026): sm_owner, sm_manager, sm_accountant,
--   sm_purchasing_store, sm_kitchen, sm_housekeeping, sm_frontdesk.
--   * CHI THEM vai tro moi; 17 vai tro cu giu nguyen; khong gan cho ai.
--   * Khong them ma quyen moi — moi quyen deu co san trong bang permissions.
--   * sm_purchasing_store KHONG co receiving.perform/post (nhan hang mu dung
--     vai tro receiver cu).
--   * Quyet dinh Duy: payment.approve cho ca Chu dau tu va Quan ly; Quan ly
--     them pr/requisition/waste.approve + admin.approval_rules.manage (tu dieu
--     chinh bac duyet). SoD theo tung chung tu van chan nguoi tu duyet chung
--     tu do chinh minh tao.
--   * seed_compact_roles(org) idempotent: migration goi cho moi to chuc hien co;
--     to chuc moi goi ham nay sau bootstrap.
--   * KHONG sua approval_rules: buoc duyet tro ve vai tro cu (gm/owner/...), doi
--     sang vai tro moi cung luc voi viec gan nguoi dung (xem tai lieu).
-- ============================================================================

create or replace function public.seed_compact_roles(p_org_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
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
    ('sm_purchasing_store', 'supplier.bank.request'),
    ('sm_purchasing_store', 'supplier.manage'),
    ('sm_purchasing_store', 'supplier.view'),
    ('sm_purchasing_store', 'supplier_return.post'),
    ('sm_purchasing_store', 'transfer.receive'),
    ('sm_purchasing_store', 'transfer.send'),
    ('sm_purchasing_store', 'warehouse.manage'),
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
$$;

revoke all on function public.seed_compact_roles(uuid) from public, anon, authenticated;
grant execute on function public.seed_compact_roles(uuid) to service_role;

do $$
declare
  r record;
begin
  for r in select id from public.organizations loop
    perform public.seed_compact_roles(r.id);
  end loop;
end $$;
