# Kịch bản chạy thử chế độ DEMO (13/11/2026)

> Mục đích: tạo **tồn kho demo bằng chu trình thật** (mua → duyệt → nhận hàng → hóa đơn → thanh toán) và thử các tính năng mới.
> Dữ liệu giả lập. Làm trên khách sạn **TEST47** (các tài khoản `uat.*` chỉ có quyền ở TEST47).
> Mật khẩu/PIN không ghi ở đây — Duy cấp riêng. Không đoán PIN.
> **Lưu ý đường dẫn:** app dùng **mã định danh (UUID) của khách sạn** trong URL. Khách sạn TEST47 = `b0000000-0000-4000-8000-000000000002`; mọi đường dẫn bên dưới đã ghi sẵn theo dạng đó (ví dụ `/b0000000-0000-4000-8000-000000000002/procurement/pr`). Dạng `/TEST47/...` sẽ báo 404.

> Hướng dẫn đầy đủ theo từng vai trò: `docs/go-live/uat-guide.md`.

## 0. Chuẩn bị (đã làm sẵn trên production)

- TEST47 có 30 phòng demo, 3 loại phòng, 2 xe đẩy, nhà hàng/bếp demo; 16 nhà cung cấp giả lập `SUP0001`–`SUP0016` (dùng chung cả chuỗi), nhà cung cấp `NCC-T047`.
- Vật tư có **giá trần**: `NVL0388` ba chỉ nách (100.000 đ/kg), `NVL0561` bánh bèo (5.000 đ/cái) → PO tự lấy giá, không phải duyệt giá tay.
- Duyệt đơn mua còn **2 bậc**: bậc 1 Quản lý (từ 0 đ), bậc 2 Chủ đầu tư (từ 100.000.000 đ). Đơn thử dưới đây ~1.000.000 đ nên chỉ cần **Quản lý** duyệt.
- Mỗi tài khoản chỉ làm phần của mình; **người tạo không tự duyệt phiếu của mình** (SoD) nên cần đúng người ở mỗi bước.
- **Người nhận hàng không được là người đã duyệt đơn mua đó** (SoD): nếu người mở phiếu nhận từng duyệt PO thì phiếu đó không đăng được — phải để người khác mở phiếu ngay từ đầu. Ngày 13/11 đã gặp đúng trường hợp này (phiếu nhận của PO-...-0001 không đăng được vì người mở phiếu chính là người duyệt PO).

## 1. Chu trình mua → nhận hàng → thanh toán (tạo tồn 10 kg NVL0388)

> **Bước 1–5 đã được chạy sẵn (Q264, 13/11/2026)** bằng `docs/sample-data/demo-cycle-po.sql` với tài khoản `uat.purchaser` và `uat.gm` qua RPC thật:
> PO **PO-TEST47-LE-2611-0003** (NCC `SUP0001`, NVL0388 10 kg × 100.000 = 1.000.000 đ) đang ở trạng thái **đã gửi**, chờ nhận hàng.
> **Bắt đầu từ bước 6.** Bước 6–12 cần PIN và ảnh của từng tài khoản (do Duy giữ) nên không chạy thay được.

| # | Tài khoản | Việc cần làm | Đường dẫn | Kết quả mong đợi |
|---|---|---|---|---|
| 1 | `uat.purchaser` | Tạo PR: NVL0388, 10 kg, chọn kho nhận KHO-T047 → **Gửi duyệt** | `/b0000000-0000-4000-8000-000000000002/procurement/pr/new` | PR chờ duyệt |
| 2 | `uat.gm` (Quản lý) | Duyệt PR (bước duyệt PR đã chuyển sang Quản lý, Q263) | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` | PR đã duyệt |
| 3 | `uat.purchaser` | Tạo PO từ PR cho `NCC-T047` hoặc một `SUP00xx` đã duyệt, kiểm giá dòng = 100.000, **Gửi duyệt** | `/b0000000-0000-4000-8000-000000000002/procurement/po` | PO chờ duyệt, tổng 1.000.000 đ, **1 bậc duyệt** |
| 4 | `uat.gm` (vai trò Quản lý) | Duyệt PO | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` | PO đã duyệt |
| 5 | `uat.purchaser` | **Gửi cho nhà cung cấp** | `/b0000000-0000-4000-8000-000000000002/procurement/po` | PO "đã gửi" |
| 6 | `uat.receiver` | Nhận hàng mù trên điện thoại: cân 2 lần (số cân lần 1 và lần 2, chênh nhau trong ngưỡng ±5% mới qua), chụp ảnh **bắt buộc cho từng dòng** — nút **Ghi dòng** chỉ bật khi đủ số cân và ảnh | `/m/b0000000-0000-4000-8000-000000000002/receive` | Phiếu nhận ghi; **không thấy** số lượng PO và giá. Dùng điện thoại thật (trình duyệt máy tính không có camera nên không chụp được ảnh, phiếu sẽ kẹt ở bước này) |
| 7 | `uat.storekeeper` | Đăng phiếu nhận (nhập PIN 6 số nếu hỏi). **Chỉ người mở phiếu mới đăng được phiếu đó** — nếu người mở phiếu từng duyệt PO này thì hệ thống chặn đăng (SoD); trường hợp đó phải bỏ phiếu nháp và mở lại bằng tài khoản khác chưa từng duyệt PO | `/b0000000-0000-4000-8000-000000000002/receiving` | **Tồn KHO-T047 tăng 10 kg**, giá vốn 100.000 đ/kg |
| 8 | `uat.accountant` | Nhập hóa đơn NCC theo PO + phiếu nhận | `/b0000000-0000-4000-8000-000000000002/finance/invoices/new` | Hóa đơn khớp PO. **13/11 chạy thử: màn này bị chặn với thông báo thiếu quyền dù vai trò có quyền nhập hóa đơn — đang chờ kiểm tra lại (xem §5)** |
| 9 | `uat.gm` (Quản lý) | Duyệt hóa đơn (Kế toán không còn quyền tự duyệt) | `/b0000000-0000-4000-8000-000000000002/finance/invoices` | Hóa đơn đã duyệt |
| 10 | `uat.accountant` | Tạo đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests/new` | Đề nghị chờ duyệt |
| 11 | `uat.owner` (Chủ đầu tư) hoặc `uat.gm` | Duyệt thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` | Đã duyệt |
| 12 | `uat.accountant` | Đánh dấu đã thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` | Công nợ NCC về 0 |

**Kiểm tra cuối:** `/b0000000-0000-4000-8000-000000000002/inventory/stock` thấy 10 kg NVL0388; báo cáo thẻ kho (`/b0000000-0000-4000-8000-000000000002/reports`) có bút toán nhập; `uat.owner` xem khối **"Sáng nay"** ở trang tổng quan (chi mua hôm qua/hôm nay, công nợ đến hạn).

## 2. Thử các tính năng mới (mỗi mục ~2 phút)

| Tính năng | Cách thử | Kết quả mong đợi |
|---|---|---|
| Bật/tắt module (Q254) | `dnduy@hueic.edu.vn` → `/admin/modules` → tắt **Nhà hàng** ở TEST47 → vào `/b0000000-0000-4000-8000-000000000002/restaurant` (và `/inventory/pos-import`) | "Module đang tắt" ở `/restaurant` và `/inventory/pos-import`; `/inventory` vẫn mở bình thường (kho là lõi), chỉ mục "Nạp file POS" ẩn; bật lại là dùng tiếp, dữ liệu còn nguyên |
| Cờ tự duyệt (Q258) | Chỉ còn ý nghĩa khi người tạo phiếu cũng là người được giao bước duyệt. Vì PR/phiếu lĩnh/phiếu hủy nay do **Quản lý duyệt** (Q263) mà Quản lý hầu như không tự tạo phiếu, cờ gần như không còn tác dụng. Vẫn có thể xem 3 cờ tại `/admin/settings` → "Bật/tắt ràng buộc" | Mặc định 1 (chặn). PO luôn bị chặn tự duyệt |
| Nhật ký thay đổi (Q252) | `dnduy@` → `/admin/audit` → lọc bảng `purchase_orders` | Thấy từng bước của chu trình trên, đúng người và giờ |
| Vai trò gọn (Q257) | `/admin/roles` → xem 7 vai trò `sm_*` | Mỗi vai trò đúng số quyền: 57 / 69 / 40 / 28 / 18 / 15 / 11 |
| Minibar + buồng phòng | `uat.front_desk` yêu cầu kiểm phòng 101 → `uat.hk_attendant` kiểm trên điện thoại → lễ tân thu tiền | Làm theo `uat-guide.md` §4.3 (TEST47 đã có phòng; giá 7 món đã kiểm chứng có hiệu lực từ 11/11 — M9, tối 13/11) |

## 3. Ghi kết quả

Mỗi bước làm xong ghi Đạt/Không đạt. Lỗi ghi đủ 4 ý: tài khoản + bước số mấy, làm tới đâu thì lỗi, thông báo lỗi nguyên văn, ảnh chụp màn hình.
Bước 7 phụ thuộc PIN của `uat.storekeeper`/`uat.receiver` (cờ R18 đang bật): chưa có PIN thì báo Duy, đừng tắt cờ.

## 4. Duyệt phiếu (Q263, đã xử lý 13/11)

Duyệt **PR, phiếu lĩnh kho, phiếu hủy hàng** đã chuyển sang vai trò **Quản lý** (`sm_manager`); duyệt PO: Quản lý (bậc 1) + Chủ đầu tư (từ 100 triệu, bậc 2).
Trưởng bộ phận/Bếp/Buồng phòng chỉ **đề xuất**. Người tạo phiếu mà không phải Quản lý thì không duyệt được phiếu của chính mình (và cũng không duyệt phiếu bộ phận khác).
Hạn mức và vai trò duyệt do Quản lý tự chỉnh ở `/admin/approval-rules`.

## 5. Lỗi đã biết & cách né (cập nhật tối 13/11/2026)

Danh sách đầy đủ: `uat-guide.md` §6. Riêng các lỗi chạm trực tiếp tới chu trình này:

1. **Chụp ảnh bắt buộc từng dòng nhận hàng, không có đường tải ảnh lên.** Trình duyệt máy tính không có camera thì phiếu kẹt ở bước 6 (không bấm được Ghi dòng). **Cách né:** nhận hàng bằng điện thoại thật, cấp quyền camera trước khi mở phiếu.
2. **Người mở phiếu nhận từng duyệt PO thì không đăng được phiếu (SoD).** **Cách né:** ngay từ bước 6, để người nhận hàng là người chưa từng duyệt PO đó (ví dụ thủ kho mở phiếu, người nhận khác duyệt PO).
3. **Mở lại PO đã có phiếu nháp thì tạo thêm phiếu nháp mới.** **Cách né:** đừng bấm Mở phiếu nhận lần nữa; tìm phiếu nháp đang mở dở trong danh sách phiếu nhận và làm tiếp phiếu đó.
4. **Màn nhập hóa đơn bị chặn với tài khoản kế toán (chạy thử 13/11).** **Cách né:** ghi lại thông báo nguyên văn, dừng ở bước 8, làm tiếp bước 9–12 sau khi lỗi được sửa (đang chờ kiểm tra lại, M1).
5. **Nút "Gửi duyệt" / "Gửi cho nhà cung cấp" hiện hộp thoại xác nhận của trình duyệt.** Bấm OK để tiếp tục; trình duyệt tự động không bấm được hộp thoại này.
6. **PO chợ: ô tổng ước tính từ chối số tròn (ví dụ 500.000) và form Sửa nháp không lưu được (chạy thử 13/11).** **Cách né tạm thời:** nhập tổng ước tính lệch 1 đồng (500.001); đừng sửa nháp PO chợ cho tới khi lỗi được sửa (đang chờ kiểm tra lại, M1).
