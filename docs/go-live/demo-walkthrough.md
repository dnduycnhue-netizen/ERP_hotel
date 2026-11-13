# Kịch bản chạy thử chế độ DEMO (13/11/2026)

> Mục đích: tạo **tồn kho demo bằng chu trình thật** (mua → duyệt → nhận hàng → hóa đơn → thanh toán) và thử các tính năng mới.
> Dữ liệu giả lập. Làm trên khách sạn **TEST47** (các tài khoản `uat.*` chỉ có quyền ở TEST47).
> Mật khẩu/PIN không ghi ở đây — Duy cấp riêng. Không đoán PIN.
> Hướng dẫn đầy đủ theo từng vai trò: `docs/go-live/uat-guide.md`.

## 0. Chuẩn bị (đã làm sẵn trên production)

- TEST47 có 30 phòng demo, 3 loại phòng, 2 xe đẩy, nhà hàng/bếp demo; 16 nhà cung cấp giả lập `SUP0001`–`SUP0016` (dùng chung cả chuỗi), nhà cung cấp `NCC-T047`.
- Vật tư có **giá trần**: `NVL0388` ba chỉ nách (100.000 đ/kg), `NVL0561` bánh bèo (5.000 đ/cái) → PO tự lấy giá, không phải duyệt giá tay.
- Duyệt đơn mua còn **2 bậc**: bậc 1 Quản lý (từ 0 đ), bậc 2 Chủ đầu tư (từ 100.000.000 đ). Đơn thử dưới đây ~1.000.000 đ nên chỉ cần **Quản lý** duyệt.
- Mỗi tài khoản chỉ làm phần của mình; **người tạo không tự duyệt phiếu của mình** (SoD) nên cần đúng người ở mỗi bước.

## 1. Chu trình mua → nhận hàng → thanh toán (tạo tồn 10 kg NVL0388)

| # | Tài khoản | Việc cần làm | Đường dẫn | Kết quả mong đợi |
|---|---|---|---|---|
| 1 | `uat.purchaser` | Tạo PR: NVL0388, 10 kg, chọn kho nhận KHO-T047 → **Gửi duyệt** | `/TEST47/procurement/pr/new` | PR chờ duyệt |
| 2 | `uat.outlet_head` | Duyệt PR | `/TEST47/procurement/approvals` | PR đã duyệt |
| 3 | `uat.purchaser` | Tạo PO từ PR cho `NCC-T047` hoặc một `SUP00xx` đã duyệt, kiểm giá dòng = 100.000, **Gửi duyệt** | `/TEST47/procurement/po` | PO chờ duyệt, tổng 1.000.000 đ, **1 bậc duyệt** |
| 4 | `uat.gm` (vai trò Quản lý) | Duyệt PO | `/TEST47/procurement/approvals` | PO đã duyệt |
| 5 | `uat.purchaser` | **Gửi cho nhà cung cấp** | `/TEST47/procurement/po` | PO "đã gửi" |
| 6 | `uat.receiver` | Nhận hàng mù trên điện thoại: nhập 10 kg (cân 2 lần), chụp ảnh | `/m/TEST47/receive` | Phiếu nhận ghi; **không thấy** số lượng PO và giá |
| 7 | `uat.storekeeper` | Đăng phiếu nhận (nhập PIN nếu hỏi) | `/TEST47/receiving` | **Tồn KHO-T047 tăng 10 kg**, giá vốn 100.000 đ/kg |
| 8 | `uat.accountant` | Nhập hóa đơn NCC theo PO + phiếu nhận | `/TEST47/finance/invoices/new` | Hóa đơn khớp PO |
| 9 | `uat.gm` (Quản lý) | Duyệt hóa đơn (Kế toán không còn quyền tự duyệt) | `/TEST47/finance/invoices` | Hóa đơn đã duyệt |
| 10 | `uat.accountant` | Tạo đề nghị thanh toán | `/TEST47/finance/payment-requests/new` | Đề nghị chờ duyệt |
| 11 | `uat.owner` (Chủ đầu tư) hoặc `uat.gm` | Duyệt thanh toán | `/TEST47/finance/payment-requests` | Đã duyệt |
| 12 | `uat.accountant` | Đánh dấu đã thanh toán | `/TEST47/finance/payment-requests` | Công nợ NCC về 0 |

**Kiểm tra cuối:** `/TEST47/inventory/stock` thấy 10 kg NVL0388; báo cáo thẻ kho (`/TEST47/reports`) có bút toán nhập; `uat.owner` xem khối **"Sáng nay"** ở trang tổng quan (chi mua hôm qua/hôm nay, công nợ đến hạn).

## 2. Thử các tính năng mới (mỗi mục ~2 phút)

| Tính năng | Cách thử | Kết quả mong đợi |
|---|---|---|
| Bật/tắt module (Q254) | `dnduy@hueic.edu.vn` → `/admin/modules` → tắt **Nhà hàng** ở TEST47 → vào `/TEST47/restaurant` và `/inventory` | "Module đang tắt"; menu POS biến mất; bật lại là dùng tiếp, dữ liệu còn nguyên |
| Cờ tự duyệt (Q258) | `dnduy@` (hoặc tài khoản có `admin.settings.manage`) → `/admin/settings` → "Bật/tắt ràng buộc" → đặt **Chặn tự duyệt đề xuất mua** = 0; sau đó `uat.outlet_head` tạo PR rồi tự duyệt (bước duyệt PR hiện gắn với vai trò `outlet_head`, xem lưu ý cuối) | Tự duyệt được; có cảnh báo `SOD_EXCEPTION_USED`; đặt lại = 1 thì lại bị chặn. PO thì **luôn** bị chặn |
| Nhật ký thay đổi (Q252) | `dnduy@` → `/admin/audit` → lọc bảng `purchase_orders` | Thấy từng bước của chu trình trên, đúng người và giờ |
| Vai trò gọn (Q257) | `/admin/roles` → xem 7 vai trò `sm_*` | Mỗi vai trò đúng số quyền: 57 / 69 / 40 / 28 / 18 / 15 / 11 |
| Minibar + buồng phòng | `uat.front_desk` yêu cầu kiểm phòng 101 → `uat.hk_attendant` kiểm trên điện thoại → lễ tân thu tiền | Làm theo `uat-guide.md` §4.3 (TEST47 đã có phòng) |

## 3. Ghi kết quả

Mỗi bước làm xong ghi Đạt/Không đạt. Lỗi ghi đủ 4 ý: tài khoản + bước số mấy, làm tới đâu thì lỗi, thông báo lỗi nguyên văn, ảnh chụp màn hình.
Bước 7 phụ thuộc PIN của `uat.storekeeper`/`uat.receiver` (cờ R18 đang bật): chưa có PIN thì báo Duy, đừng tắt cờ.

## 4. Lưu ý đã biết (chưa xử lý)

Quy tắc duyệt **PR và phiếu lĩnh** vẫn gắn với vai trò cũ `outlet_head`, **phiếu hủy** gắn `cost_controller`; chỉ **PO** đã chuyển sang vai trò gọn (Quản lý/Chủ đầu tư).
Hệ quả: người chỉ giữ `sm_kitchen`/`sm_housekeeping`/`sm_manager` **có quyền** duyệt PR/phiếu lĩnh/phiếu hủy nhưng **không được giao bước duyệt** nên bấm duyệt sẽ báo "không phải người duyệt được giao".
Cần Duy chọn: (a) đổi bước duyệt PR/phiếu lĩnh/hủy sang `sm_manager` (Quản lý duyệt hết) hoặc (b) giữ trưởng bộ phận duyệt và gán thêm vai trò cũ cho họ.
