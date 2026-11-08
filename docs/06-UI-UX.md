# 06 — Giao diện & trải nghiệm

## 1. Nguyên tắc

- **Hai khu giao diện:**
  - `/(app)/[property]/…` — giao diện văn phòng (laptop/tablet): bảng, lọc, duyệt, báo cáo.
  - `/m/[property]/…` — giao diện hiện trường (điện thoại): mỗi màn một việc, chữ to, nút to, thao tác một tay, chạy được offline (4 màn).
- Bộ chọn khách sạn ở thanh trên; ghi nhớ lựa chọn cuối (cookie).
- Tiếng Việt có dấu, câu ngắn. Mọi chuỗi trong `src/i18n/vi.ts`.
- Số: định dạng `vi-VN` (1.234.567,5). Tiền thêm "đ". Ngày `dd/MM/yyyy`, giờ `HH:mm`.
- Mã lỗi RPC → câu tiếng Việt trong `src/i18n/errors.vi.ts` (`ERR_NEGATIVE_STOCK` → "Không đủ tồn kho để xuất").
- Mọi nút ghi sổ có hộp xác nhận nêu rõ hậu quả ("Sau khi ghi sổ không sửa được, chỉ đảo được").
- Trạng thái chứng từ hiện bằng huy hiệu màu thống nhất: nháp (xám), chờ duyệt (vàng), đã duyệt (xanh dương), đã ghi sổ (xanh lá), bị từ chối/đảo (đỏ).
- Không dùng màu làm tín hiệu duy nhất — luôn có chữ hoặc icon kèm theo.

## 2. Sơ đồ màn hình — văn phòng

| Nhóm | Route | Màn hình |
|---|---|---|
| Tổng quan | `/[p]` | Bảng tin theo vai trò: việc chờ tôi duyệt, cảnh báo đỏ, 5 chỉ số |
| Danh mục | `/[p]/master/items` | Danh sách vật tư (lọc nhóm, mã tạm, thiếu quy đổi), chi tiết, gộp mã tạm |
|  | `/[p]/master/suppliers` | NCC, thẩm định, STK chờ duyệt |
|  | `/[p]/master/prices` | Hợp đồng khung, giá trần |
|  | `/[p]/master/warehouses`, `/rooms`, `/outlets` | Cơ cấu |
|  | `/[p]/master/import` | Nhập Excel có bước xem trước lỗi |
| Thu mua | `/[p]/purchasing/requests`, `/orders`, `/orders/[id]` | PR, PO, timeline duyệt |
|  | `/[p]/purchasing/market` | Lệnh mua chợ + tạm ứng |
| Kho | `/[p]/inventory/receipts`, `/requisitions`, `/transfers`, `/issues`, `/waste` | Chứng từ kho |
|  | `/[p]/inventory/stock` | Tồn theo kho / lô / hạn dùng, thẻ kho |
|  | `/[p]/inventory/counts` | Đợt kiểm kê, biên bản chênh lệch |
|  | `/[p]/inventory/locks` | Khóa ngày / kỳ |
| Buồng phòng | `/[p]/housekeeping/standards`, `/trolleys`, `/minibar` | Chuẩn setup, ca xe đẩy, đối soát minibar |
| Tài chính | `/[p]/finance/invoices`, `/ap`, `/advances`, `/payments`, `/services` | Hóa đơn, công nợ, tạm ứng, thanh toán, hợp đồng dịch vụ |
|  | `/[p]/finance/export` | Xuất Excel cho kế toán |
| Dữ liệu ngoài | `/[p]/data/pms` | Form số liệu PMS ngày |
| Báo cáo | `/[p]/reports/*` | Xem `08-REPORTS-ALERTS.md` |
| Quản trị | `/admin/users`, `/admin/roles`, `/admin/roles/[id]`, `/admin/users/[id]/access`, `/admin/settings`, `/admin/approval-rules`, `/admin/alert-rules` | Xem mục 6 |

## 3. Màn hình hiện trường (mobile, offline được)

### 3.1 Nhận hàng mù — `/m/[p]/receive`
- Danh sách "Hàng chờ nhận hôm nay": tên NCC, số dòng hàng, giờ dự kiến. **Không có số lượng, không có giá.**
- Chọn PO (hoặc "Nhận hàng không có PO" cho mua chợ — chọn lệnh mua chợ).
- Màn từng dòng (bố cục dọc trên điện thoại):
  - Tên hàng + quy cách + yêu cầu QC.
  - Bàn phím số lớn; 3 ô: **Tổng cân** − **Bì** = **Thực nhận** (tự tính).
  - Nút **Chụp ảnh** (camera trong app, không có nút chọn ảnh từ thư viện). Nút Xác nhận mờ cho tới khi có ảnh (nếu bắt buộc).
  - Checklist QC dạng nút chạm (Đạt / Không đạt), nhiệt độ, hạn dùng.
  - Nếu server trả `needs_reweigh` → màn hình vàng "Vui lòng cân lại" (không nói thừa/thiếu).
- Cuối phiếu: nhập PIN người nhận → gửi. Offline: hiện "Đã lưu trên máy, sẽ gửi khi có mạng" + đếm số phiếu chờ gửi.

### 3.2 Kiểm kê — `/m/[p]/count/[countId]`
- Danh sách mã cần đếm, không hiện tồn sổ.
- Mỗi dòng nhập nhiều quy cách cùng lúc: [số thùng/tảng] + [số túi/chai] + [gram lẻ]; tổng quy đổi hiện ngay.
- Rượu: [số chai nguyên tem] + [gram chai đang mở] → hiện ml.
- Dòng bị yêu cầu đếm lại: viền vàng, chữ "Đếm lại lần cuối". Không hiện số cũ.
- Gửi: PIN từng người đếm.

### 3.3 Xe đẩy — `/m/[p]/trolley`
- Đầu ca: hiện par xe, nhập số đang có → hệ thống tính số cần lĩnh → bấm "Lĩnh bù".
- Cuối ca: đếm lại xe (mù) → gửi.

### 3.4 Kiểm minibar — `/m/[p]/minibar`
- Danh sách phòng chờ kiểm (từ lễ tân bấm check-out). Thông báo đẩy khi có phòng mới.
- Lưới món theo chuẩn minibar phòng: chạm "−" để ghi số thiếu; cờ "sắp hết hạn".
- Gửi → lễ tân thấy ngay tổng tiền.

### 3.5 Duyệt nhanh — `/m/[p]/approvals`
- Thẻ chứng từ: loại, người tạo, số tiền, lý do vượt ngưỡng, ảnh liên quan; 2 nút Duyệt / Từ chối (từ chối bắt buộc nhập lý do).

## 4. Thành phần dùng chung (tạo trong `src/components/common/`)

`DocStatusBadge`, `MoneyText`, `QtyInput` (đa quy cách), `NumPad`, `CameraCapture` (getUserMedia + nén + SHA-256), `PinDialog`, `ApprovalTimeline`, `AttachmentGallery`, `PropertySwitcher`, `DataTable` (TanStack Table, lọc + phân trang server), `EmptyState`, `ErrorState`, `OfflineBanner`, `ConfirmPostDialog`.

## 5. Màn hình lễ tân cho minibar

`/[p]/frontdesk/minibar`: ô nhập số phòng → nút "Yêu cầu kiểm minibar" → danh sách yêu cầu đang chờ / đã có kết quả (tổng tiền, chi tiết món) → nút "Đã thu" (nhập số folio) hoặc "Đề nghị miễn" (lý do, chuyển gm duyệt).

## 6. Màn hình phân quyền (quản trị)

Mọi màn hình dưới đây gọi RPC `admin_*` (mục 9 của `09-API-RPC.md`); không ghi thẳng vào bảng.

### 6.1 Danh sách vai trò — `/admin/roles`
- Bảng: tên vai trò, mô tả, số quyền, số người đang giữ, nhãn "Mẫu hệ thống", trạng thái.
- Nút: **Tạo vai trò**, **Sao chép** (tạo vai trò mới từ vai trò có sẵn), **Ngừng dùng** (không xóa khi còn người giữ).
- Nút **So sánh vai trò**: chọn 2–3 vai trò → bảng quyền đặt cạnh nhau, tô sáng chỗ khác.

### 6.2 Ma trận quyền của vai trò — `/admin/roles/[id]`
- Quyền nhóm theo module (Danh mục, NCC & giá, Thu mua, Nhận hàng, Kho, Kiểm kê & khóa, Buồng phòng, Tài chính, Dịch vụ, Báo cáo, Cảnh báo, Quản trị), mỗi module thu gọn/mở được.
- Mỗi dòng: ô tích, tên quyền tiếng Việt, mô tả một dòng, huy hiệu mức rủi ro (thường / nhạy cảm / quan trọng).
- Ô tích ở tiêu đề module để chọn/bỏ cả nhóm.
- Ô tìm kiếm quyền theo tên.
- Khi lưu:
  - Có quyền mức "quan trọng" thay đổi → hộp xác nhận nêu rõ sẽ báo chủ đầu tư.
  - Có tổ hợp xung đột (vd. Tạo PO + Ghi sổ nhận hàng) → cảnh báo vàng liệt kê cặp xung đột, vẫn cho lưu kèm lý do.
- Lịch sử thay đổi vai trò (ai, lúc nào, thêm/bỏ quyền gì) ở tab bên.

### 6.3 Người dùng — `/admin/users` và `/admin/users/[id]/access`
- Danh sách: mã NV, họ tên, khách sạn, vai trò, trạng thái, lần đăng nhập cuối. Lọc theo KS, vai trò.
- Trang truy cập của 1 người, 3 khối:
  1. **Vai trò được gán**: bảng các dòng (vai trò, khách sạn hoặc "Toàn chuỗi", bộ phận/kho giới hạn — chọn nhiều, từ ngày, đến ngày, người cấp). Nút thêm/sửa/thu hồi.
  2. **Quyền riêng**: bảng (quyền, Cho phép / Chặn, khách sạn, thời hạn, lý do). Dùng cho thay ca, nghỉ phép, ngoại lệ.
  3. **Quyền hiệu lực** (chỉ đọc): chọn khách sạn → danh sách cuối cùng sau khi gộp vai trò + quyền riêng, mỗi quyền ghi nguồn ("từ vai trò Thủ kho", "cho phép riêng đến 30/11", "bị chặn riêng"). Cảnh báo tổ hợp xung đột hiện ở đầu khối.
- Không cho người đang đăng nhập sửa quyền của chính mình (nút bị khóa, RPC cũng chặn).
- Nút **Đặt lại PIN**, **Khóa tài khoản**.

### 6.4 Gán nhanh khi tạo khách sạn
Sau khi tạo khách sạn, trình hướng dẫn gợi ý bộ vai trò mẫu theo hồ sơ (có / không Cost Controller) và cho gán người vào từng vai trò trên một màn hình.

### 6.5 Ẩn/hiện theo quyền ở mọi màn hình
- Hook `useCan(code)` đọc từ `my_permissions(property)` (tải khi chọn khách sạn, làm mới khi đổi KS hoặc sau 5 phút).
- Không có quyền xem → không hiện menu. Có quyền xem nhưng không có quyền thao tác → nút hiện mờ kèm chú thích "Bạn chưa được cấp quyền …".
- Server luôn tự kiểm tra lại; ẩn ở UI chỉ để gọn giao diện.
