-- Sample organization/access data for local development only.
begin;

insert into public.organizations (id, name)
values ('00000000-0000-4000-8000-000000000001', 'Chuỗi khách sạn mẫu (local)')
on conflict (id) do nothing;

insert into public.legal_entities (
  id, org_id, code, name, accounting_regime, costing_method
)
values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'KS01', 'Khách sạn mẫu 01', 'TT99', 'moving_avg'),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000001', 'KS02', 'Khách sạn mẫu 02', 'TT99', 'moving_avg')
on conflict (id) do nothing;

insert into public.properties (
  id, org_id, legal_entity_id, code, name, sod_profile
)
values
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'KS01', 'Khách sạn mẫu 01', 'with_cc'),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'KS02', 'Khách sạn mẫu 02', 'without_cc')
on conflict (id) do nothing;

insert into public.outlet_types (id, org_id, code, name)
values
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000001', 'KITCHEN', 'Bếp'),
  ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000001', 'BAR', 'Quầy bar'),
  ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000001', 'HOUSEKEEPING', 'Buồng phòng')
on conflict (id) do nothing;

insert into public.cost_centers (id, org_id, code, name, usali_department)
values
  ('00000000-0000-4000-8000-000000000311', '00000000-0000-4000-8000-000000000001', 'ROOMS', 'Buồng phòng', 'Rooms'),
  ('00000000-0000-4000-8000-000000000312', '00000000-0000-4000-8000-000000000001', 'FB_FOOD', 'Ẩm thực - món ăn', 'F&B Food'),
  ('00000000-0000-4000-8000-000000000313', '00000000-0000-4000-8000-000000000001', 'FB_BEVERAGE', 'Ẩm thực - đồ uống', 'F&B Beverage'),
  ('00000000-0000-4000-8000-000000000314', '00000000-0000-4000-8000-000000000001', 'AG', 'Hành chính và quản lý', 'A&G'),
  ('00000000-0000-4000-8000-000000000315', '00000000-0000-4000-8000-000000000001', 'MAINTENANCE', 'Bảo trì', 'Maintenance'),
  ('00000000-0000-4000-8000-000000000316', '00000000-0000-4000-8000-000000000001', 'UTILITIES', 'Năng lượng và nước', 'Utilities')
on conflict (id) do nothing;

insert into public.outlets (
  id, property_id, outlet_type_id, cost_center_id, code, name
)
values
  ('00000000-0000-4000-8000-000000000321', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000312', 'KITCHEN', 'Bếp chính'),
  ('00000000-0000-4000-8000-000000000322', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000313', 'BAR', 'Quầy bar'),
  ('00000000-0000-4000-8000-000000000323', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000311', 'HOUSEKEEPING', 'Buồng phòng')
on conflict (id) do nothing;

insert into public.room_types (id, property_id, code, name, max_guests)
values
  ('00000000-0000-4000-8000-000000000331', '00000000-0000-4000-8000-000000000201', 'STD', 'Phòng tiêu chuẩn', 2),
  ('00000000-0000-4000-8000-000000000332', '00000000-0000-4000-8000-000000000202', 'STD', 'Phòng tiêu chuẩn', 2)
on conflict (id) do nothing;

insert into public.rooms (id, property_id, room_type_id, room_no, floor)
values
  ('00000000-0000-4000-8000-000000000341', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000331', '101', '1'),
  ('00000000-0000-4000-8000-000000000342', '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000332', '201', '2')
on conflict (id) do nothing;

insert into public.warehouses (
  id, property_id, outlet_id, room_id, code, name, kind
)
values
  ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000201', null, null, 'MAIN', 'Kho tổng', 'main'),
  ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000201', null, null, 'TRANSIT', 'Kho trung chuyển', 'transit'),
  ('00000000-0000-4000-8000-000000000403', '00000000-0000-4000-8000-000000000201', null, null, 'QUARANTINE', 'Kho cách ly', 'quarantine'),
  ('00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000201', null, null, 'DISPOSAL', 'Kho chờ hủy', 'disposal'),
  ('00000000-0000-4000-8000-000000000405', '00000000-0000-4000-8000-000000000201', null, null, 'MINIBAR_MAIN', 'Kho minibar tổng', 'minibar_main'),
  ('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000321', null, 'KITCHEN', 'Kho bếp', 'outlet'),
  ('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000322', null, 'BAR', 'Kho bar', 'outlet'),
  ('00000000-0000-4000-8000-000000000408', '00000000-0000-4000-8000-000000000201', null, '00000000-0000-4000-8000-000000000341', 'MINIBAR_101', 'Minibar phòng 101', 'minibar_room'),
  ('00000000-0000-4000-8000-000000000411', '00000000-0000-4000-8000-000000000202', null, null, 'MAIN', 'Kho tổng', 'main'),
  ('00000000-0000-4000-8000-000000000412', '00000000-0000-4000-8000-000000000202', null, null, 'TRANSIT', 'Kho trung chuyển', 'transit'),
  ('00000000-0000-4000-8000-000000000413', '00000000-0000-4000-8000-000000000202', null, null, 'QUARANTINE', 'Kho cách ly', 'quarantine'),
  ('00000000-0000-4000-8000-000000000414', '00000000-0000-4000-8000-000000000202', null, null, 'DISPOSAL', 'Kho chờ hủy', 'disposal'),
  ('00000000-0000-4000-8000-000000000415', '00000000-0000-4000-8000-000000000202', null, null, 'MINIBAR_MAIN', 'Kho minibar tổng', 'minibar_main'),
  ('00000000-0000-4000-8000-000000000418', '00000000-0000-4000-8000-000000000202', null, '00000000-0000-4000-8000-000000000342', 'MINIBAR_201', 'Minibar phòng 201', 'minibar_room')
on conflict (id) do nothing;

insert into public.roles (id, org_id, code, name_vi, description, is_system)
values
  ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư', 'Mẫu quyền xem báo cáo và duyệt theo ngưỡng.', true),
  ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý', 'Mẫu quyền điều hành và duyệt tại khách sạn.', true),
  ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng chuỗi', 'Mẫu quyền kiểm soát kế toán và kỳ.', true),
  ('00000000-0000-4000-8000-000000000504', '00000000-0000-4000-8000-000000000001', 'accountant', 'Kế toán khách sạn', 'Mẫu quyền hóa đơn, công nợ và tạm ứng.', true),
  ('00000000-0000-4000-8000-000000000505', '00000000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller', 'Mẫu quyền kiểm soát giá và hậu kiểm.', true),
  ('00000000-0000-4000-8000-000000000506', '00000000-0000-4000-8000-000000000001', 'purchaser', 'Thu mua', 'Mẫu quyền yêu cầu và lập đơn mua.', true),
  ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho', 'Mẫu quyền nhận hàng và thao tác kho.', true),
  ('00000000-0000-4000-8000-000000000508', '00000000-0000-4000-8000-000000000001', 'receiver', 'Nhận hàng ca sáng', 'Mẫu quyền nhận hàng mù, không xem số lượng PO và giá.', true),
  ('00000000-0000-4000-8000-000000000509', '00000000-0000-4000-8000-000000000001', 'outlet_head', 'Trưởng bộ phận', 'Mẫu quyền yêu cầu và xác nhận lĩnh hàng.', true),
  ('00000000-0000-4000-8000-000000000510', '00000000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng / Bếp', 'Mẫu quyền bộ phận bếp và kiểm kê.', true),
  ('00000000-0000-4000-8000-000000000511', '00000000-0000-4000-8000-000000000001', 'bartender', 'Bartender', 'Mẫu quyền kiểm kê đồ uống.', true),
  ('00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng', 'Mẫu quyền điều hành kho tầng và xe đẩy.', true),
  ('00000000-0000-4000-8000-000000000513', '00000000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng', 'Mẫu quyền xe đẩy và kiểm minibar.', true),
  ('00000000-0000-4000-8000-000000000514', '00000000-0000-4000-8000-000000000001', 'front_desk', 'Lễ tân', 'Mẫu quyền yêu cầu và xác nhận thu minibar.', true),
  ('00000000-0000-4000-8000-000000000515', '00000000-0000-4000-8000-000000000001', 'engineer', 'Kỹ thuật', 'Mẫu quyền lĩnh vật tư và nghiệm thu dịch vụ.', true),
  ('00000000-0000-4000-8000-000000000516', '00000000-0000-4000-8000-000000000001', 'internal_audit', 'Kiểm soát nội bộ', 'Mẫu quyền chỉ xem báo cáo và nhật ký.', true),
  ('00000000-0000-4000-8000-000000000517', '00000000-0000-4000-8000-000000000001', 'sys_admin', 'Quản trị hệ thống', 'Chỉ quản trị người dùng và quyền; không có quyền nghiệp vụ tiền hoặc kho.', true)
on conflict (id) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from (
  values
    ('owner', 'report.view.rpt_stock_card'),
    ('owner', 'report.view.rpt_receiving_quality'),
    ('owner', 'report.view.rpt_open_po_invoice'),
    ('owner', 'report.view.rpt_ap_aging'),
    ('owner', 'report.view.rpt_advances'),
    ('owner', 'report.view.rpt_waste'),
    ('owner', 'report.view.rpt_opex'),
    ('owner', 'report.view.rpt_minibar'),
    ('owner', 'report.view.rpt_amenity_cpor'),
    ('owner', 'report.view.rpt_daily_brief'),
    ('owner', 'report.daily_brief.receive'),
    ('owner', 'po.approve'),
    ('owner', 'audit.view_all'),
    ('gm', 'report.view.rpt_stock_card'),
    ('gm', 'report.view.rpt_receiving_quality'),
    ('gm', 'report.view.rpt_open_po_invoice'),
    ('gm', 'report.view.rpt_ap_aging'),
    ('gm', 'report.view.rpt_advances'),
    ('gm', 'report.view.rpt_waste'),
    ('gm', 'report.view.rpt_opex'),
    ('gm', 'report.view.rpt_minibar'),
    ('gm', 'report.view.rpt_amenity_cpor'),
    ('gm', 'report.view.rpt_daily_brief'),
    ('gm', 'report.daily_brief.receive'),
    ('gm', 'po.approve'),
    ('gm', 'po.approve.over_ceiling'),
    ('gm', 'waste.approve.large'),
    ('gm', 'count.adjust.approve'),
    ('gm', 'day.unlock'),
    ('gm', 'minibar.waive.approve'),
    ('gm', 'advance.approve'),
    ('gm', 'room.manage'),
    ('gm', 'supplier.approve'),
    ('gm', 'supplier.view'),
    ('gm', 'price.view'),
    ('gm', 'item.import'),
    ('gm', 'alert.receive.bank_account_change'),
    ('chief_accountant', 'invoice.approve'),
    ('chief_accountant', 'payment.approve'),
    ('chief_accountant', 'period.close'),
    ('chief_accountant', 'period.reopen'),
    ('chief_accountant', 'price.ceiling.manage'),
    ('chief_accountant', 'item.view'),
    ('chief_accountant', 'supplier.bank.approve'),
    ('chief_accountant', 'supplier.approve'),
    ('chief_accountant', 'supplier.view'),
    ('chief_accountant', 'price.view'),
    ('chief_accountant', 'alert.receive.bank_account_change'),
    ('chief_accountant', 'export.accounting'),
    ('chief_accountant', 'report.view.rpt_ap_aging'),
    ('chief_accountant', 'report.view.rpt_opex'),
    ('chief_accountant', 'item.manage'),
    ('chief_accountant', 'item.import'),
    ('accountant', 'invoice.manage'),
    ('accountant', 'item.view'),
    ('accountant', 'ap.view'),
    ('accountant', 'advance.disburse'),
    ('accountant', 'advance.settle'),
    ('accountant', 'payment.request'),
    ('accountant', 'payment.mark_paid'),
    ('accountant', 'day.lock'),
    ('accountant', 'count.lock'),
    ('accountant', 'pms.input'),
    ('cost_controller', 'price.ceiling.manage'),
    ('cost_controller', 'price.agreement.manage'),
    ('cost_controller', 'supplier.view'),
    ('cost_controller', 'price.view'),
    ('cost_controller', 'item.view'),
    ('cost_controller', 'receiving.review_photos'),
    ('cost_controller', 'count.view_variance'),
    ('cost_controller', 'waste.approve'),
    ('cost_controller', 'item.temp.normalize'),
    ('cost_controller', 'po.approve'),
    ('cost_controller', 'item.manage'),
    ('cost_controller', 'item.import'),
    ('purchaser', 'pr.create'),
    ('purchaser', 'item.view'),
    ('purchaser', 'po.create'),
    ('purchaser', 'po.view'),
    ('purchaser', 'po.view_qty'),
    ('purchaser', 'po.view_price'),
    ('purchaser', 'market.order.create'),
    ('purchaser', 'supplier.view'),
    ('purchaser', 'supplier.manage'),
    ('purchaser', 'supplier.bank.request'),
    ('purchaser', 'price.agreement.manage'),
    ('purchaser', 'price.view'),
    ('purchaser', 'advance.request'),
    ('purchaser', 'item.temp.create'),
    ('storekeeper', 'receiving.perform'),
    ('storekeeper', 'item.view'),
    ('storekeeper', 'receiving.post'),
    ('storekeeper', 'receiving.view'),
    ('storekeeper', 'requisition.issue'),
    ('storekeeper', 'transfer.send'),
    ('storekeeper', 'transfer.receive'),
    ('storekeeper', 'stock.view_qty'),
    ('storekeeper', 'count.open'),
    ('storekeeper', 'count.perform'),
    ('storekeeper', 'supplier_return.post'),
    ('storekeeper', 'item.temp.create'),
    ('storekeeper', 'item.manage'),
    ('storekeeper', 'warehouse.manage'),
    ('receiver', 'receiving.perform'),
    ('receiver', 'item.view'),
    ('receiver', 'receiving.post'),
    ('outlet_head', 'pr.create'),
    ('outlet_head', 'item.view'),
    ('outlet_head', 'pr.approve'),
    ('outlet_head', 'requisition.create'),
    ('outlet_head', 'requisition.approve'),
    ('outlet_head', 'requisition.receive'),
    ('outlet_head', 'waste.propose'),
    ('chef', 'pr.create'),
    ('chef', 'item.view'),
    ('chef', 'pr.approve'),
    ('chef', 'requisition.create'),
    ('chef', 'requisition.approve'),
    ('chef', 'requisition.receive'),
    ('chef', 'waste.propose'),
    ('chef', 'count.perform'),
    ('bartender', 'count.perform'),
    ('bartender', 'item.view'),
    ('hk_supervisor', 'hk.standard.manage'),
    ('hk_supervisor', 'item.view'),
    ('hk_supervisor', 'hk.trolley.operate'),
    ('hk_supervisor', 'minibar.refill'),
    ('hk_supervisor', 'requisition.create'),
    ('hk_supervisor', 'requisition.approve'),
    ('hk_supervisor', 'requisition.issue'),
    ('hk_supervisor', 'requisition.receive'),
    ('hk_supervisor', 'waste.propose'),
    ('hk_supervisor', 'room.manage'),
    ('hk_attendant', 'hk.trolley.operate'),
    ('hk_attendant', 'item.view'),
    ('hk_attendant', 'minibar.check'),
    ('front_desk', 'minibar.request_check'),
    ('front_desk', 'minibar.charge.confirm'),
    ('front_desk', 'minibar.waive.request'),
    ('front_desk', 'pms.input'),
    ('engineer', 'requisition.create'),
    ('engineer', 'service.accept'),
    ('internal_audit', 'audit.view_all'),
    ('internal_audit', 'report.view.rpt_stock_card'),
    ('internal_audit', 'report.view.rpt_receiving_quality'),
    ('internal_audit', 'report.view.rpt_open_po_invoice'),
    ('internal_audit', 'report.view.rpt_ap_aging'),
    ('internal_audit', 'report.view.rpt_advances'),
    ('internal_audit', 'report.view.rpt_waste'),
    ('internal_audit', 'report.view.rpt_opex'),
    ('internal_audit', 'report.view.rpt_minibar'),
    ('internal_audit', 'report.view.rpt_amenity_cpor'),
    ('internal_audit', 'report.view.rpt_daily_brief')
) as rp(role_code, permission_code)
join public.roles r
  on r.org_id = '00000000-0000-4000-8000-000000000001'
 and r.code = rp.role_code
join public.permissions p on p.code = rp.permission_code
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code
from public.roles r
join public.permissions p on p.module = 'Quản trị'
where r.org_id = '00000000-0000-4000-8000-000000000001'
  and r.code = 'sys_admin'
on conflict do nothing;

commit;
