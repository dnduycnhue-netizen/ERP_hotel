-- T-012/Go-live: Khởi tạo dữ liệu cơ sở vận hành cho các khách sạn & tổ chức
-- Bao gồm: Cost Centers USALI, Outlet Types, Item Groups chuẩn, Kho chuẩn theo M01.01,
-- và Các vai trò mẫu hệ thống (system roles) kèm ma trận quyền chuẩn.

-- 1. Cost Centers theo chuẩn USALI
insert into public.cost_centers (org_id, code, name, usali_department)
select o.id, c.code, c.name, c.usali_department
from public.organizations o
cross join (
  values
    ('ROOMS', 'Buồng phòng', 'Rooms'),
    ('FB_FOOD', 'Ẩm thực - Món ăn', 'F&B Food'),
    ('FB_BEVERAGE', 'Ẩm thực - Đồ uống', 'F&B Beverage'),
    ('AG', 'Hành chính & Quản lý', 'A&G'),
    ('MAINTENANCE', 'Bảo trì & Kỹ thuật', 'Maintenance'),
    ('UTILITIES', 'Năng lượng & Nước', 'Utilities')
) as c(code, name, usali_department)
on conflict (org_id, code) do nothing;

-- 2. Outlet Types cơ bản
insert into public.outlet_types (org_id, code, name)
select o.id, t.code, t.name
from public.organizations o
cross join (
  values
    ('KITCHEN', 'Bếp chính'),
    ('BAR', 'Quầy Bar'),
    ('RESTAURANT', 'Nhà hàng'),
    ('HOUSEKEEPING', 'Buồng phòng'),
    ('ENGINEERING', 'Kỹ thuật')
) as t(code, name)
on conflict (org_id, code) do nothing;

-- 3. Item Groups chuẩn hóa toàn chuỗi
insert into public.item_groups (org_id, code_prefix, name, kind)
select o.id, g.code_prefix, g.name, g.kind
from public.organizations o
cross join (
  values
    ('TP', 'Thực phẩm tươi sống & khô', 'food'),
    ('DU', 'Đồ uống & Rượu bia', 'beverage'),
    ('AMN', 'Đồ dùng phòng khách', 'amenity'),
    ('CPM', 'Đồ miễn phí cho khách', 'complimentary'),
    ('VAI', 'Đồ vải khách sạn', 'linen'),
    ('HC', 'Hóa chất giặt tẩy & vệ sinh', 'chemical'),
    ('DC', 'Dụng cụ làm việc', 'tool'),
    ('MB', 'Mặt hàng Minibar', 'minibar'),
    ('KT', 'Vật tư thay thế kỹ thuật', 'engineering'),
    ('CCDC', 'Công cụ dụng cụ', 'ccdc')
) as g(code_prefix, name, kind)
on conflict (org_id, code_prefix) do nothing;

-- 4. Kho chuẩn cho mọi khách sạn (main, transit, quarantine, disposal, minibar_main) theo M01.01
insert into public.warehouses (property_id, code, name, kind)
select p.id, w.code, w.name, w.kind
from public.properties p
cross join (
  values
    ('MAIN', 'Kho tổng', 'main'),
    ('TRANSIT', 'Kho trung chuyển', 'transit'),
    ('QUARANTINE', 'Kho cách ly chờ xử lý', 'quarantine'),
    ('DISPOSAL', 'Kho chờ hủy', 'disposal'),
    ('MINIBAR_MAIN', 'Kho minibar tổng', 'minibar_main')
) as w(code, name, kind)
on conflict (property_id, code) do nothing;

-- 5. Các vai trò mẫu hệ thống (system roles)
insert into public.roles (org_id, code, name_vi, description, is_system)
select o.id, r.code, r.name_vi, r.description, true
from public.organizations o
cross join (
  values
    ('gm', 'Tổng quản lý', 'Điều hành và duyệt toàn diện tại khách sạn.'),
    ('chief_accountant', 'Kế toán trưởng chuỗi', 'Kiểm soát kế toán, kỳ và giá trần.'),
    ('accountant', 'Kế toán khách sạn', 'Hóa đơn, công nợ, tạm ứng, khóa sổ ngày.'),
    ('cost_controller', 'Cost Controller', 'Kiểm soát giá vốn, hậu kiểm nhận hàng và tồn kho.'),
    ('purchaser', 'Thu mua', 'Tạo và quản lý đơn đặt hàng, tìm nguồn cung ứng.'),
    ('storekeeper', 'Thủ kho', 'Nhận hàng, xuất kho, kiểm kê và quản lý kho.'),
    ('receiver', 'Nhận hàng ca sáng', 'Nhận hàng mù không xem số lượng PO và giá.'),
    ('outlet_head', 'Trưởng bộ phận', 'Lập phiếu yêu cầu và xác nhận lĩnh hàng.'),
    ('chef', 'Bếp trưởng / Bếp', 'Quản lý bếp, định mức và kiểm kê thực phẩm.'),
    ('bartender', 'Bartender', 'Quản lý quầy bar và kiểm kê đồ uống.'),
    ('hk_supervisor', 'Giám sát buồng', 'Quản lý buồng phòng, xe đẩy và đồ vải.'),
    ('hk_attendant', 'Nhân viên buồng', 'Kiểm minibar và vận hành xe đẩy phòng.'),
    ('front_desk', 'Lễ tân', 'Thu tiền minibar và tiếp nhận thông tin khách.'),
    ('engineer', 'Kỹ thuật', 'Lĩnh vật tư bảo trì và nghiệm thu dịch vụ.'),
    ('internal_audit', 'Kiểm soát nội bộ', 'Xem báo cáo và nhật ký kiểm toán toàn chuỗi.')
) as r(code, name_vi, description)
on conflict (org_id, code) do nothing;

-- 6. Gán quyền mặc định cho các vai trò mẫu
insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
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
    ('chief_accountant', 'invoice.approve'),
    ('chief_accountant', 'payment.approve'),
    ('chief_accountant', 'period.close'),
    ('chief_accountant', 'period.reopen'),
    ('chief_accountant', 'price.ceiling.manage'),
    ('chief_accountant', 'item.view'),
    ('chief_accountant', 'supplier.bank.approve'),
    ('chief_accountant', 'export.accounting'),
    ('chief_accountant', 'report.view.rpt_ap_aging'),
    ('chief_accountant', 'report.view.rpt_opex'),
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
    ('cost_controller', 'item.view'),
    ('cost_controller', 'receiving.review_photos'),
    ('cost_controller', 'count.view_variance'),
    ('cost_controller', 'waste.approve'),
    ('cost_controller', 'item.temp.normalize'),
    ('cost_controller', 'po.approve'),
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
    ('purchaser', 'advance.request'),
    ('purchaser', 'item.temp.create'),
    ('storekeeper', 'receiving.perform'),
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
    ('storekeeper', 'item.view'),
    ('receiver', 'receiving.perform'),
    ('receiver', 'receiving.post'),
    ('receiver', 'item.view'),
    ('outlet_head', 'pr.create'),
    ('outlet_head', 'pr.approve'),
    ('outlet_head', 'requisition.create'),
    ('outlet_head', 'requisition.approve'),
    ('outlet_head', 'requisition.receive'),
    ('outlet_head', 'waste.propose'),
    ('outlet_head', 'item.view'),
    ('chef', 'pr.create'),
    ('chef', 'pr.approve'),
    ('chef', 'requisition.create'),
    ('chef', 'requisition.approve'),
    ('chef', 'requisition.receive'),
    ('chef', 'waste.propose'),
    ('chef', 'count.perform'),
    ('chef', 'item.view'),
    ('bartender', 'count.perform'),
    ('bartender', 'item.view'),
    ('hk_supervisor', 'hk.standard.manage'),
    ('hk_supervisor', 'hk.trolley.operate'),
    ('hk_supervisor', 'minibar.refill'),
    ('hk_supervisor', 'requisition.create'),
    ('hk_supervisor', 'requisition.approve'),
    ('hk_supervisor', 'requisition.issue'),
    ('hk_supervisor', 'requisition.receive'),
    ('hk_supervisor', 'waste.propose'),
    ('hk_supervisor', 'item.view'),
    ('hk_attendant', 'hk.trolley.operate'),
    ('hk_attendant', 'minibar.check'),
    ('hk_attendant', 'item.view'),
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
  on r.code = rp.role_code and r.is_system = true
on conflict (role_id, permission_code) do nothing;
