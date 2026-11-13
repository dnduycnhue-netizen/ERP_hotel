# Hồ sơ vai trò gọn cho khách sạn nhỏ (ĐỀ XUẤT — chưa áp)

Ngày 13/11/2026 · Q257 · Chờ Duy duyệt. Vai trò cũ (17 vai trò) **giữ nguyên**; bộ này chỉ **thêm** 7 vai trò mẫu `sm_*`. Mỗi quyền đều lấy từ quyền đang có trong hệ thống (không thêm quyền mới).

## Nguyên tắc

- Phân quyền theo mã quyền, không so tên vai trò (AGENTS.md quy tắc 10).
- SoD vẫn chặn theo từng chứng từ (người tạo ≠ người duyệt ≠ người nhận ≠ người thanh toán), kể cả khi một người giữ nhiều vai trò.
- **Nhận hàng mù** (quy tắc 9): người nhận hàng không được thấy số lượng/đơn giá PO. Vì vậy "Thu mua & Thủ kho" **không** có quyền nhận hàng; việc nhận hàng dùng vai trò `receiver` có sẵn. Không gán `receiver` cho người trong vai trò Thu mua.
- Việc hằng ngày tách khỏi việc duyệt: Chủ đầu tư/Quản lý duyệt, Kế toán/Thu mua/Bếp/Buồng phòng đề xuất.

## Tóm tắt

| Vai trò | Mã | Số quyền | Dựa trên |
|---|---|---|---|
| Chủ đầu tư | `sm_owner` | 57 | owner (129 quyền) cắt còn phần giám sát + duyệt |
| Quản lý | `sm_manager` | 63 | gm (62) + duyệt hóa đơn |
| Kế toán | `sm_accountant` | 40 | accountant + chief_accountant (41), bỏ duyệt thanh toán và duyệt hóa đơn (để người khác duyệt) |
| Thu mua & Thủ kho | `sm_purchasing_store` | 28 | purchaser + storekeeper (28), bỏ nhận hàng/ghi nhận hàng |
| Bếp / Nhà hàng | `sm_kitchen` | 18 | chef + outlet_head (18) |
| Buồng phòng | `sm_housekeeping` | 15 | hk_supervisor + hk_attendant (15) |
| Lễ tân | `sm_frontdesk` | 11 | front_desk (11), giữ nguyên |

## Chi tiết từng vai trò

### Chủ đầu tư (`sm_owner`) — 57 quyền

Xem toàn bộ báo cáo/cảnh báo/nhật ký; duyệt việc lớn (đơn vượt hạn mức, vượt giá trần, thanh toán, tạm ứng, hủy lớn, đóng/mở kỳ); bật/tắt module và cấu hình. KHÔNG làm nghiệp vụ hằng ngày.

| Nhóm | Quyền |
|---|---|
| `admin` | `admin.alert_rules.manage` (Quản lý quy tắc cảnh báo); `admin.approval_rules.manage` (Quản lý quy tắc duyệt); `admin.health.view` (Xem sức khỏe hệ thống); `admin.modules.manage` (Bật/tắt module); `admin.settings.manage` (Quản lý cấu hình) |
| `advance` | `advance.approve` (Duyệt tạm ứng) |
| `alert` | `alert.receive.advance_overdue` (Nhận cảnh báo tạm ứng quá hạn); `alert.receive.avt_daily` (Nhận cảnh báo lệch AvT); `alert.receive.bank_account_change` (Nhận cảnh báo đổi tài khoản NCC); `alert.receive.count_variance` (Nhận cảnh báo lệch kiểm kê); `alert.receive.minibar_check_requested` (Nhận yêu cầu kiểm minibar); `alert.receive.minibar_loss` (Nhận cảnh báo thất thoát minibar); `alert.receive.minibar_mismatch` (Nhận cảnh báo lệch minibar); `alert.receive.over_ceiling_approved` (Nhận cảnh báo duyệt vượt giá trần); `alert.receive.period_close_warning` (Nhận cảnh báo đóng kỳ có tồn đọng); `alert.receive.permission_critical_changed` (Nhận cảnh báo đổi quyền quan trọng); `alert.receive.photo_reused` (Nhận cảnh báo ảnh dùng lại); `alert.receive.price_spike` (Nhận cảnh báo tăng giá); `alert.receive.rule_toggled` (Nhận cảnh báo bật/tắt ràng buộc nghiệp vụ); `alert.receive.service_contract_renewal` (Nhận cảnh báo gia hạn hợp đồng); `alert.receive.service_unaccepted_payment` (Nhận cảnh báo dịch vụ chưa nghiệm thu); `alert.receive.sod_exception_used` (Nhận cảnh báo dùng ngoại lệ SoD); `alert.receive.temp_item_stale` (Nhận cảnh báo mã tạm quá hạn); `alert.receive.unlock` (Nhận cảnh báo mở khóa); `alert.receive.waste_large` (Nhận cảnh báo hủy hàng lớn); `alert.receive.water_night_spike` (Nhận cảnh báo nước ban đêm) |
| `ap` | `ap.view` (Xem công nợ) |
| `attachment` | `attachment.view` (Xem ảnh chứng từ) |
| `audit` | `audit.view_all` (Xem nhật ký kiểm toán) |
| `count` | `count.view_variance` (Xem chênh lệch kiểm kê) |
| `day` | `day.unlock` (Mở khóa ngày) |
| `export` | `export.accounting` (Xuất dữ liệu kế toán) |
| `item` | `item.view` (Xem vật tư) |
| `payment` | `payment.approve` (Duyệt thanh toán) |
| `period` | `period.close` (Khóa kỳ); `period.reopen` (Mở lại kỳ) |
| `po` | `po.approve` (Duyệt PO); `po.approve.over_ceiling` (Duyệt PO vượt giá trần); `po.view` (Xem đơn mua hàng); `po.view_price` (Xem giá PO) |
| `price` | `price.view` (Xem giá) |
| `report` | `report.daily_brief.receive` (Nhận bản tin 8 giờ); `report.receive.daily_brief` (Nhận bản tin 8 giờ); `report.view.rpt_advances` (Xem tạm ứng); `report.view.rpt_amenity_cpor` (Xem chi phí amenities); `report.view.rpt_ap_aging` (Xem tuổi nợ); `report.view.rpt_daily_brief` (Xem bản tin 8 giờ); `report.view.rpt_fnb_revenue` (Xem báo cáo doanh thu F&B); `report.view.rpt_minibar` (Xem báo cáo minibar); `report.view.rpt_open_po_invoice` (Xem PO mở và hóa đơn treo); `report.view.rpt_opex` (Xem chi phí vận hành); `report.view.rpt_receiving_quality` (Xem chất lượng nhận hàng); `report.view.rpt_stock_card` (Xem thẻ kho); `report.view.rpt_waste` (Xem báo cáo hủy hàng) |
| `stock` | `stock.view_value` (Xem giá trị tồn) |
| `supplier` | `supplier.view` (Xem nhà cung cấp) |
| `waste` | `waste.approve.large` (Duyệt phiếu hủy lớn) |

### Quản lý (`sm_manager`) — 63 quyền

Điều hành khách sạn: duyệt đơn mua, duyệt hóa đơn, duyệt hủy, mở/đóng ngày, xem báo cáo, đối soát minibar.

| Nhóm | Quyền |
|---|---|
| `advance` | `advance.approve` (Duyệt tạm ứng) |
| `alert` | `alert.receive.advance_overdue` (Nhận cảnh báo tạm ứng quá hạn); `alert.receive.avt_daily` (Nhận cảnh báo lệch AvT); `alert.receive.bank_account_change` (Nhận cảnh báo đổi tài khoản NCC); `alert.receive.count_variance` (Nhận cảnh báo lệch kiểm kê); `alert.receive.minibar_check_requested` (Nhận yêu cầu kiểm minibar); `alert.receive.minibar_loss` (Nhận cảnh báo thất thoát minibar); `alert.receive.minibar_mismatch` (Nhận cảnh báo lệch minibar); `alert.receive.over_ceiling_approved` (Nhận cảnh báo duyệt vượt giá trần); `alert.receive.period_close_warning` (Nhận cảnh báo đóng kỳ có tồn đọng); `alert.receive.permission_critical_changed` (Nhận cảnh báo đổi quyền quan trọng); `alert.receive.photo_reused` (Nhận cảnh báo ảnh dùng lại); `alert.receive.price_spike` (Nhận cảnh báo tăng giá); `alert.receive.rule_toggled` (Nhận cảnh báo bật/tắt ràng buộc nghiệp vụ); `alert.receive.service_contract_renewal` (Nhận cảnh báo gia hạn hợp đồng); `alert.receive.service_unaccepted_payment` (Nhận cảnh báo dịch vụ chưa nghiệm thu); `alert.receive.sod_exception_used` (Nhận cảnh báo dùng ngoại lệ SoD); `alert.receive.temp_item_stale` (Nhận cảnh báo mã tạm quá hạn); `alert.receive.unlock` (Nhận cảnh báo mở khóa); `alert.receive.waste_large` (Nhận cảnh báo hủy hàng lớn); `alert.receive.water_night_spike` (Nhận cảnh báo nước ban đêm) |
| `attachment` | `attachment.view` (Xem ảnh chứng từ) |
| `count` | `count.adjust.approve` (Duyệt điều chỉnh kiểm kê) |
| `day` | `day.unlock` (Mở khóa ngày) |
| `invoice` | `invoice.approve` (Duyệt hóa đơn) |
| `item` | `item.import` (Nhập danh mục); `item.view` (Xem vật tư) |
| `minibar` | `minibar.price.manage` (Quản lý bảng giá minibar); `minibar.reconcile` (Đối soát minibar); `minibar.waive.approve` (Duyệt miễn minibar) |
| `pms` | `pms.input` (Nhập số liệu PMS) |
| `po` | `po.approve` (Duyệt PO); `po.approve.over_ceiling` (Duyệt PO vượt giá trần) |
| `pos` | `pos.import` (Nhập dữ liệu POS) |
| `price` | `price.view` (Xem giá) |
| `purpose_issue` | `purpose_issue.post` (Ghi sổ xuất theo mục đích); `purpose_issue.reverse` (Đảo xuất theo mục đích) |
| `receiving` | `receiving.override_over_po` (Ghi nhận vượt PO); `receiving.reverse` (Đảo phiếu nhận hàng) |
| `report` | `report.daily_brief.receive` (Nhận bản tin 8 giờ); `report.receive.daily_brief` (Nhận bản tin 8 giờ); `report.view.rpt_advances` (Xem tạm ứng); `report.view.rpt_amenity_cpor` (Xem chi phí amenities); `report.view.rpt_ap_aging` (Xem tuổi nợ); `report.view.rpt_daily_brief` (Xem bản tin 8 giờ); `report.view.rpt_fnb_revenue` (Xem báo cáo doanh thu F&B); `report.view.rpt_minibar` (Xem báo cáo minibar); `report.view.rpt_open_po_invoice` (Xem PO mở và hóa đơn treo); `report.view.rpt_opex` (Xem chi phí vận hành); `report.view.rpt_receiving_quality` (Xem chất lượng nhận hàng); `report.view.rpt_stock_card` (Xem thẻ kho); `report.view.rpt_waste` (Xem báo cáo hủy hàng) |
| `restaurant` | `restaurant.banquet.manage` (Quản lý đặt tiệc); `restaurant.buffet.manage` (Quản lý phiên buffet); `restaurant.dish.manage` (Quản lý món ăn + công thức); `restaurant.sale.record` (Ghi nhận bán hàng); `restaurant.view` (Xem nhà hàng) |
| `room` | `room.manage` (Quản lý phòng) |
| `service` | `service.contract.manage` (Quản lý hợp đồng dịch vụ) |
| `stock` | `stock.view_qty` (Xem số lượng tồn) |
| `supplier` | `supplier.approve` (Duyệt nhà cung cấp); `supplier.view` (Xem nhà cung cấp) |
| `waste` | `waste.approve.large` (Duyệt phiếu hủy lớn) |

### Kế toán (`sm_accountant`) — 40 quyền

Hóa đơn NCC, công nợ, tạm ứng, đề nghị thanh toán và đánh dấu đã chi, đóng kỳ, duyệt NCC/tài khoản ngân hàng NCC, xuất file kế toán.

| Nhóm | Quyền |
|---|---|
| `advance` | `advance.disburse` (Chi tạm ứng); `advance.settle` (Quyết toán tạm ứng) |
| `alert` | `alert.receive.advance_overdue` (Nhận cảnh báo tạm ứng quá hạn); `alert.receive.avt_daily` (Nhận cảnh báo lệch AvT); `alert.receive.bank_account_change` (Nhận cảnh báo đổi tài khoản NCC); `alert.receive.over_ceiling_approved` (Nhận cảnh báo duyệt vượt giá trần); `alert.receive.period_close_warning` (Nhận cảnh báo đóng kỳ có tồn đọng); `alert.receive.permission_critical_changed` (Nhận cảnh báo đổi quyền quan trọng); `alert.receive.photo_reused` (Nhận cảnh báo ảnh dùng lại); `alert.receive.price_spike` (Nhận cảnh báo tăng giá); `alert.receive.service_contract_renewal` (Nhận cảnh báo gia hạn hợp đồng); `alert.receive.service_unaccepted_payment` (Nhận cảnh báo dịch vụ chưa nghiệm thu); `alert.receive.sod_exception_used` (Nhận cảnh báo dùng ngoại lệ SoD); `alert.receive.temp_item_stale` (Nhận cảnh báo mã tạm quá hạn); `alert.receive.unlock` (Nhận cảnh báo mở khóa); `alert.receive.waste_large` (Nhận cảnh báo hủy hàng lớn) |
| `ap` | `ap.view` (Xem công nợ) |
| `attachment` | `attachment.upload` (Tải ảnh chứng từ); `attachment.view` (Xem ảnh chứng từ) |
| `count` | `count.lock` (Khóa đợt kiểm kê) |
| `day` | `day.lock` (Khóa ngày) |
| `export` | `export.accounting` (Xuất dữ liệu kế toán) |
| `invoice` | `invoice.manage` (Quản lý hóa đơn) |
| `item` | `item.import` (Nhập danh mục); `item.manage` (Quản lý vật tư); `item.view` (Xem vật tư) |
| `payment` | `payment.mark_paid` (Ghi nhận đã thanh toán); `payment.request` (Đề nghị thanh toán) |
| `period` | `period.close` (Khóa kỳ); `period.reopen` (Mở lại kỳ) |
| `pms` | `pms.input` (Nhập số liệu PMS) |
| `pos` | `pos.import` (Nhập dữ liệu POS) |
| `price` | `price.ceiling.manage` (Quản lý giá trần); `price.view` (Xem giá) |
| `receiving` | `receiving.view` (Xem phiếu nhận hàng) |
| `report` | `report.view.rpt_ap_aging` (Xem tuổi nợ); `report.view.rpt_opex` (Xem chi phí vận hành) |
| `supplier` | `supplier.approve` (Duyệt nhà cung cấp); `supplier.bank.approve` (Duyệt tài khoản NCC); `supplier.view` (Xem nhà cung cấp) |

### Thu mua & Thủ kho (`sm_purchasing_store`) — 28 quyền

Yêu cầu mua, đơn mua, giá/giá trần, NCC; kho: xuất, chuyển, kiểm kê, trả hàng NCC. Việc NHẬN HÀNG mù giao cho vai trò Nhận hàng cũ (không gộp).

| Nhóm | Quyền |
|---|---|
| `advance` | `advance.request` (Đề nghị tạm ứng) |
| `attachment` | `attachment.upload` (Tải ảnh chứng từ); `attachment.view` (Xem ảnh chứng từ) |
| `count` | `count.open` (Mở đợt kiểm kê); `count.perform` (Thực hiện kiểm kê) |
| `item` | `item.manage` (Quản lý vật tư); `item.temp.create` (Tạo mã tạm); `item.view` (Xem vật tư) |
| `market` | `market.order.create` (Tạo lệnh mua chợ) |
| `po` | `po.close` (Đóng PO); `po.create` (Tạo đơn mua hàng); `po.view` (Xem đơn mua hàng); `po.view_price` (Xem giá PO); `po.view_qty` (Xem số lượng PO) |
| `pr` | `pr.create` (Tạo yêu cầu mua) |
| `price` | `price.agreement.manage` (Quản lý hợp đồng giá); `price.view` (Xem giá) |
| `purpose_issue` | `purpose_issue.post` (Ghi sổ xuất theo mục đích) |
| `receiving` | `receiving.view` (Xem phiếu nhận hàng) |
| `requisition` | `requisition.issue` (Xuất phiếu lĩnh) |
| `stock` | `stock.view_qty` (Xem số lượng tồn) |
| `supplier` | `supplier.bank.request` (Đề nghị đổi tài khoản NCC); `supplier.manage` (Quản lý nhà cung cấp); `supplier.view` (Xem nhà cung cấp) |
| `supplier_return` | `supplier_return.post` (Ghi sổ trả hàng NCC) |
| `transfer` | `transfer.receive` (Nhận điều chuyển); `transfer.send` (Gửi điều chuyển) |
| `warehouse` | `warehouse.manage` (Quản lý kho) |

### Bếp / Nhà hàng (`sm_kitchen`) — 18 quyền

Món, công thức, buffet, tiệc, bán hàng, phiếu lĩnh kho, đề xuất mua/hủy, duyệt phiếu của bộ phận mình. Cần module Nhà hàng bật.

| Nhóm | Quyền |
|---|---|
| `attachment` | `attachment.upload` (Tải ảnh chứng từ); `attachment.view` (Xem ảnh chứng từ) |
| `count` | `count.perform` (Thực hiện kiểm kê) |
| `item` | `item.view` (Xem vật tư) |
| `pr` | `pr.approve` (Duyệt yêu cầu mua); `pr.create` (Tạo yêu cầu mua) |
| `purpose_issue` | `purpose_issue.post` (Ghi sổ xuất theo mục đích) |
| `receiving` | `receiving.view` (Xem phiếu nhận hàng) |
| `requisition` | `requisition.approve` (Duyệt phiếu lĩnh); `requisition.create` (Tạo phiếu lĩnh); `requisition.receive` (Xác nhận nhận phiếu lĩnh) |
| `restaurant` | `restaurant.banquet.manage` (Quản lý đặt tiệc); `restaurant.buffet.manage` (Quản lý phiên buffet); `restaurant.dish.manage` (Quản lý món ăn + công thức); `restaurant.sale.record` (Ghi nhận bán hàng); `restaurant.view` (Xem nhà hàng) |
| `stock` | `stock.view_qty` (Xem số lượng tồn) |
| `waste` | `waste.propose` (Đề xuất hủy hàng) |

### Buồng phòng (`sm_housekeeping`) — 15 quyền

Xe đẩy, chuẩn setup phòng, kiểm/châm minibar, phiếu lĩnh, phòng. Cần module Buồng phòng & Lễ tân bật.

| Nhóm | Quyền |
|---|---|
| `alert` | `alert.receive.minibar_check_requested` (Nhận yêu cầu kiểm minibar) |
| `attachment` | `attachment.upload` (Tải ảnh chứng từ); `attachment.view` (Xem ảnh chứng từ) |
| `hk` | `hk.standard.manage` (Quản lý chuẩn setup); `hk.trolley.operate` (Vận hành xe đẩy) |
| `item` | `item.view` (Xem vật tư) |
| `minibar` | `minibar.check` (Kiểm minibar); `minibar.price.manage` (Quản lý bảng giá minibar); `minibar.refill` (Bổ sung minibar) |
| `requisition` | `requisition.approve` (Duyệt phiếu lĩnh); `requisition.create` (Tạo phiếu lĩnh); `requisition.issue` (Xuất phiếu lĩnh); `requisition.receive` (Xác nhận nhận phiếu lĩnh) |
| `room` | `room.manage` (Quản lý phòng) |
| `waste` | `waste.propose` (Đề xuất hủy hàng) |

### Lễ tân (`sm_frontdesk`) — 11 quyền

Nhập số liệu PMS, yêu cầu kiểm minibar, thu tiền minibar, xin miễn, bán hàng nhà hàng/tiệc.

| Nhóm | Quyền |
|---|---|
| `attachment` | `attachment.upload` (Tải ảnh chứng từ); `attachment.view` (Xem ảnh chứng từ) |
| `item` | `item.view` (Xem vật tư) |
| `minibar` | `minibar.charge.confirm` (Xác nhận thu minibar); `minibar.request_check` (Yêu cầu kiểm minibar); `minibar.waive.request` (Đề nghị miễn minibar) |
| `pms` | `pms.input` (Nhập số liệu PMS) |
| `restaurant` | `restaurant.banquet.manage` (Quản lý đặt tiệc); `restaurant.sale.record` (Ghi nhận bán hàng); `restaurant.view` (Xem nhà hàng) |
| `stock` | `stock.view_qty` (Xem số lượng tồn) |

## Cần bạn quyết định

1. Duyệt thanh toán (`payment.approve`) đang để cho **Chủ đầu tư**. Muốn chuyển cho Quản lý?
2. Bếp/Nhà hàng và Buồng phòng đang vừa **đề xuất** vừa **duyệt** phiếu của bộ phận (SoD theo chứng từ chặn tự duyệt). Khách sạn đủ người thì tách thêm 1 trưởng bộ phận.
3. Thu mua & Thủ kho: một người giữ vai trò này vẫn không nhận hàng được; cần ít nhất 1 người giữ `receiver` (nhân viên kho/bảo vệ nhận hàng).
4. Bậc duyệt đơn mua đang 4 bậc (0 / 10 / 20 / 100 triệu): đề xuất rút còn 2 bậc — bạn chốt hạn mức.

## Cách áp (sau khi duyệt)

Migration tạo 7 vai trò `sm_*` (is_system) cho mọi tổ chức + gán quyền như bảng trên; có pgTAP kiểm tra mỗi quyền tồn tại, không vai trò nào có cặp SoD cùng chứng từ ngoài danh sách đã nêu, và `receiver` không bị đổi. Không gán vai trò cho người dùng nào tự động.
