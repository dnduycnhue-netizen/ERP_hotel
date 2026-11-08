# 08 — Báo cáo & cảnh báo

## 1. Báo cáo MVP

| Mã | Tên | Nội dung | Nguồn | Tần suất |
|---|---|---|---|---|
| `RPT_STOCK_CARD` | Thẻ kho / Nhập–xuất–tồn | Theo kho, mã, lô, kỳ; số lượng + giá trị | `stock_moves` | Theo yêu cầu |
| `RPT_RECEIVING_QUALITY` | Chất lượng nhận hàng | % thiếu cân, số lần cân lại, QC fail, trả hàng theo NCC | `goods_receipt_lines`, `supplier_returns` | Tuần |
| `RPT_OPEN_PO_INVOICE` | PO mở & hóa đơn treo | PO chưa nhận đủ, hóa đơn `on_hold` | PO, invoices | Ngày |
| `RPT_AP_AGING` | Tuổi nợ & dòng tiền chi | Nợ theo hạn, dự báo chi 14 ngày | `ap_ledger` | Tuần |
| `RPT_ADVANCES` | Tạm ứng chưa quyết toán | Theo người, số giờ quá hạn | `advances` | Ngày |
| `RPT_WASTE` | Hủy hàng | Theo lý do, outlet, người đề xuất; % doanh thu | `waste_reports` | Tuần |
| `RPT_OPEX` | Chi phí vận hành theo khoản mục | Khoản mục × cost center × tháng; CPOR | moves + service + invoices | Tháng |
| `RPT_MINIBAR` | Minibar | Doanh thu, giá vốn, lãi gộp từng món; đối soát thu; Lavie bán / Dasani cấp trên đêm phòng | minibar_* | Ngày / tháng |
| `RPT_AMENITY_CPOR` | Amenities | Tiêu hao, chi phí trên đêm phòng theo nhóm | trolley + pms | Tháng |
| `RPT_DAILY_BRIEF` | Bản tin 8h | Tổng hợp cho chủ đầu tư (mục 2) | snapshot | Ngày |

P2: AvT, Flash food/beverage cost, biến động giá, scorecard NCC, so sánh chéo các KS, buffet/khách, Menu Engineering.

## 2. Bản tin 8h (`RPT_DAILY_BRIEF`)

Gửi owner + gm mỗi KS; owner nhận bản gộp toàn chuỗi.

1. 5 con số: chi mua hàng hôm qua, giá trị hủy, số cảnh báo đỏ chưa xử lý, công nợ đến hạn 7 ngày, tạm ứng quá hạn. (P2 thêm Food cost %, Beverage cost %, tổng lệch AvT.)
2. Danh sách cảnh báo đỏ trong 24h, mỗi dòng có link xem chứng từ + ảnh.
3. Hợp đồng dịch vụ sắp hết hạn / kỳ chưa nghiệm thu.

Tạo bởi `report_build_daily(p_date)` lúc 07:30, lưu `report_snapshots`, gửi lúc 08:00.

## 3. Cảnh báo (`alert_rules` mặc định — chờ chủ đầu tư chốt)

| Mã | Điều kiện mặc định | Mức | Kênh | Khẩn (vượt giờ im lặng) |
|---|---|---|---|---|
| `BANK_ACCOUNT_CHANGE` | Yêu cầu/duyệt đổi STK NCC | red | Zalo/email + app | Có |
| `UNLOCK` | Mở khóa ngày/kỳ | red | Zalo/email | Có |
| `WATER_NIGHT_SPIKE` (P2) | Nước ban đêm > 150% TB 7 ngày | red | Zalo + kỹ thuật | Có |
| `COUNT_VARIANCE` (P2) | Lệch Key Item > 5% hoặc > 500.000đ | red | Zalo + app | Không |
| `AVT_DAILY` (P2) | Tổng lệch AvT ngày > 2.000.000đ/KS | red | Zalo | Không |
| `OVER_CEILING_APPROVED` | PO duyệt vượt giá trần | warn | App, gộp bản tin | Không |
| `PRICE_SPIKE` | Giá nhập > TB 7 ngày + 10% | warn | App | Không |
| `WASTE_LARGE` | Phiếu hủy > 1.000.000đ | warn | App | Không |
| `MINIBAR_MISMATCH` | Đối soát minibar lệch ≠ 0 | red | App + bản tin | Không |
| `ADVANCE_OVERDUE` | Tạm ứng quá 24h | warn | Email tuần + bản tin | Không |
| `TEMP_ITEM_STALE` | Mã tạm > 24h | info | App | Không |
| `PHOTO_REUSED` | SHA-256 ảnh trùng ảnh cũ | red | App | Không |
| `PERMISSION_CRITICAL_CHANGED` | Gán/bỏ quyền mức quan trọng, tạo/sửa vai trò có quyền quan trọng | red | Zalo/email | Có |
| `SOD_EXCEPTION_USED` | Dùng ngoại lệ SoD | warn | Email tuần | Không |
| `SERVICE_UNACCEPTED_PAYMENT` | Đề nghị thanh toán dịch vụ chưa nghiệm thu | warn | App | Không |

Giờ im lặng 23:00–06:00: chỉ gửi cảnh báo "Khẩn"; còn lại dồn vào bản tin 8h. Nhiều cảnh báo cùng KS trong 5 phút → gộp 1 tin.
