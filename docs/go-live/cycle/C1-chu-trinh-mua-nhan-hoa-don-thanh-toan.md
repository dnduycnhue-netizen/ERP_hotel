# C1 — Chu trình mua → nhận → hóa đơn → thanh toán (tạo tồn đầu tiên)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- PO-TEST47-LE-2611-0003 (SUP0001, NVL0388 "ba chỉ nách" 10 kg × 100.000 đ) đã ĐÃ GỬI trước bài.
- Kết quả: **Đạt** — chu trình hoàn tất (công nợ SUP0001 về 0 đ), nhưng bước 2 và bước 6 không đi đúng kỳ vọng của bài: thủ kho không ghi sổ được (chỉ receiver ghi sổ được) và GM không duyệt được đề nghị thanh toán (người duyệt được giao là Kế toán trưởng chuỗi). Cả hai đều đã giải quyết trong bài bằng đúng vai trò được giao.
- Nhánh `feat/muse-cycle`, commit `T-C1:` (ghi sau khi gate xanh).

## Từng bước

### Bước 1 — Nhận hàng mù: ĐẠT
- Tài khoản uat.receiver@erp.internal ("UAT Nhận hàng ca sáng").
- Mở nhiệm vụ PO-...-0003 tạo phiếu nhận nháp **GRN-TEST47-LE-2611-0008** (đúng kỳ vọng), kho nhận "Kho chính T047 (KHO-T047)".
- Màn nhận **không hiện** số lượng PO hay đơn giá (nhận mù đúng kỳ vọng).
- Cân lần 1: tổng 10, bì 0, thực nhận 10 kg; app chỉ yêu cầu **1 lần cân** (không đòi cân lần 2).
- Phương án không camera (Q274) **có xuất hiện**: đã tích ô "Thiết bị không có camera / không chụp được ảnh — xác nhận nhận hàng không kèm ảnh", lý do nguyên văn "Trình duyệt kiểm thử không có camera" → "Ghi dòng" → "Đã ghi 1/1 dòng", "Đã ghi đủ các dòng.", 1 lần cân, 0 ảnh chụp.

### Bước 2 — Ghi sổ phiếu nhận: KHÔNG ĐẠT theo kỳ vọng (đã giải quyết bằng receiver)
- (a) uat.storekeeper@erp.internal ("UAT Thủ kho") bấm "Ghi sổ" → nhập PIN → bị chặn, nguyên văn: **"Bạn chưa được cấp quyền receiving.post để thực hiện thao tác này."**
- (b) Thử lại bằng tài khoản receiver: ghi sổ **thành công**, "Đã ghi sổ phiếu nhận hàng thành công." (trang chuyển về `/m/.../receive?posted=1`).
- Phiếu GRN-...-0008 Nháp → Đã ghi sổ; PO-...-0003 chuyển sang trạng thái "received".
- Ghi chú: theo mô hình phân quyền hiện tại, `sm_purchasing_store` không có `receiving.post` (nhận hàng dùng vai trò receiver cũ) — hành vi này khớp phân quyền, kỳ vọng của bài (thủ kho ghi sổ) có thể sai. Cần Claude Code xác nhận người ghi sổ phiếu nhận là ai. Xem C1-N2.

### Bước 3 — Tồn + thẻ kho + không sửa được phiếu đã ghi sổ: ĐẠT
- `/inventory/stock` (thủ kho): NVL0388 tại Kho chính T047 — tồn **10 kg** (0 → 10 kg), đơn giá bình quân **100.000 đ/kg**, giá trị tồn **1.000.000 đ**.
- Thẻ kho NVL0388: đúng **1 bút toán nhập** — ngày 2026-11-14, chứng từ GRN-TEST47-LE-2611-0008, Nhập 10, Xuất —, Đơn giá vốn 100.000 đ, Thành tiền 1.000.000 đ, Tồn sau 10; Tồn đầu kỳ 0, Tổng nhập +10, Tổng xuất −0, Tồn cuối theo thẻ 10, Tồn sổ 10, "✓ Khớp với tồn sổ (10 = 10)".
- Thử sửa phiếu đã ghi sổ: **không có nút Sửa/Chỉnh sửa** (trang phiếu chỉ hiện "Đã ghi sổ—Sau khi ghi sổ, người nhận không xem lại được phiếu này." + liên kết "Về danh sách chờ nhận"; danh sách phiếu nhận cũng không có thao tác sửa).

### Bước 4 — Hóa đơn: ĐẠT
- Tài khoản uat.accountant@erp.internal ("UAT Kế toán khách sạn").
- Form `/finance/invoices/new`: chọn NCC SUP0001 trước → chọn PO-...-0003 (hiển thị "received") → dòng "ba chỉ nách" SL đặt 10, SL đã nhận 10, SL hóa đơn 10, đơn giá 100.000 đ, VAT 0, thành tiền 1.000.000 đ → lưu.
- Hóa đơn: **C26TAA 0000001**, trạng thái NHÁP → ĐÃ KHỚP sau khi bấm "Khớp 3 chiều".
- So khớp 3 bên (nguyên văn): **"Đã khớp đủ 3 chiều."**; "SL khớp · SL đã nhận: 10 / SL còn được hóa đơn: 10"; "Giá khớp · Đơn giá đơn mua: 100.000 đ → Đơn giá hóa đơn: 100.000 đ (Lệch giá: 0%, Dung sai cho phép: 1%)". Trước thuế 1.000.000 đ, Tiền thuế 0 đ, Tổng tiền 1.000.000 đ.

### Bước 5 — Duyệt hóa đơn + thử tự duyệt (SoD): ĐẠT
- (a) Tài khoản kế toán: trang chi tiết hóa đơn **không có nút Duyệt**; chỉ hiện ghi chú nguyên văn **"Người tạo hóa đơn không được tự duyệt (tách biệt nhiệm vụ)."**
- (b) Tài khoản uat.gm@erp.internal ("UAT Tổng quản lý") mở hóa đơn → nút "Duyệt hóa đơn" xuất hiện → bấm → hóa đơn ĐÃ KHỚP → ĐÃ DUYỆT, kèm dòng "Đã duyệt hóa đơn và ghi công nợ."
- Lưu ý: duyệt hóa đơn bằng GM **không hiện ô xác nhận** (Xác nhận/Bỏ qua); một lần bấm là duyệt luôn (nút chuyển trạng thái "Đang duyệt…"). Xem C1-N5.

### Bước 6 — Đề nghị thanh toán + duyệt + đánh dấu đã thanh toán: ĐẠT (sau khi đổi người duyệt)
- Kế toán tạo đề nghị thanh toán **PAY-TEST47-LE-2611-0001**, tổng 1.000.000 đ cho hóa đơn C26TAA 0000001, trạng thái CHỜ DUYỆT, hạn trả 2026-12-14.
- (a) Kế toán tự duyệt: **không có nút Duyệt** (cả trang chi tiết và danh sách); mục duyệt chỉ hiện "1 — Kế toán trưởng chuỗi — Chờ duyệt".
- (b) Tài khoản GM: trang chi tiết hiện nút "Duyệt"/"Từ chối"; bấm "Duyệt" → ô xác nhận trên trang → bấm "Xác nhận" → bị chặn, nguyên văn: **"Bạn không phải người duyệt được giao cho bước này."** Đề nghị vẫn CHỜ DUYỆT.
- (c) Đăng nhập uat.chief_accountant@erp.internal ("UAT Kế toán trưởng chuỗi"): mục duyệt ghi đúng "1 — Kế toán trưởng chuỗi — Chờ duyệt" → bấm "Duyệt" → ô xác nhận → "Xác nhận" → **không hỏi PIN** → ĐÃ DUYỆT, "Đã ghi quyết định duyệt.", bước duyệt hiển thị "1 — Kế toán trưởng chuỗi — Đã duyệt · UAT Kế toán trưởng chuỗi · 12:54:58 14/11/2026".
- (d) Accountant mở đề nghị đã duyệt → nút "Đã trả tiền" ban đầu disabled cho đến khi nhập "Số tham chiếu ngân hàng" (dùng mã kiểm thử FT2611140001) → bấm → ĐÃ THANH TOÁN, "Đã ghi nhận thanh toán và cập nhật công nợ.", "Ngày trả: 2026-11-14T05:55:53.306215+00:00", tiến trình 4 bước đều xong; hóa đơn C26TAA 0000001 chuyển "Đã thanh toán".
- `/finance/payables` — SUP0001: Phải trả 1.000.000 đ, **Đã trả 1.000.000 đ, Còn nợ 0 đ**, Chưa đến hạn 0 đ, Quá hạn 0 đ. Sổ chi tiết: 2026-11-14 "Hóa đơn" 1.000.000 đ; 2026-11-14 "Đề nghị thanh toán" −1.000.000 đ. Trang "Còn phải trả: 0 đ", "Quá hạn: 0 đ".

### Bước 7 — Kiểm tra cuối: ĐẠT
- (a) uat.owner@erp.internal ("UAT Chủ đầu tư") mở trang tổng quan, khối "Sáng nay" (nguyên văn): "Có việc cần xem: cảnh báo đỏ, tạm ứng quá hạn hoặc hợp đồng sắp đến hạn."; "Chi mua hàng hôm qua 0 đ"; "Giá trị hủy hôm qua 0 đ"; "Cảnh báo đỏ chưa xử lý 8"; "Công nợ đến hạn 7 ngày 0 đ"; "Tạm ứng quá hạn 0".
- (b) Đăng nhập dnduy@hueic.edu.vn (dịch vụ đăng nhập đã lưu) → `/admin/audit`: các thao tác hiện đúng người thực hiện — 12:34:09 UAT Nhận hàng ca sáng Thêm goods_receipts (tạo phiếu nháp); 12:34:41 UAT Nhận hàng ca sáng Thêm goods_receipt_lines và **receiving_photo_waivers**; 12:44:50 UAT Nhận hàng ca sáng Sửa goods_receipts/purchase_orders/purchase_order_lines (ghi sổ); 12:47:03 UAT Kế toán khách sạn Thêm supplier_invoices và supplier_invoice_lines (tạo hóa đơn); 12:47:26 UAT Kế toán khách sạn Sửa supplier_invoices (khớp 3 chiều); 12:48:40 UAT Tổng quản lý Sửa supplier_invoices (GM duyệt hóa đơn); 12:49:49 UAT Kế toán khách sạn Thêm payment_requests + payment_request_lines + approvals (tạo đề nghị).
- Dòng `receiving_photo_waivers` **có xuất hiện**: 12:34:41 14/11/26, UAT Nhận hàng ca sáng, Thêm, receiving_photo_waivers 7960d4b4-7cbd-43a6-8032-41c25acd1663, 9 cột; gr_id 8106a796-bea6-478d-b733-7b3acf14dd30, item_id b0000000-0000-4000-8000-000000000011, po_line_id a46d1b7b-eade-4523-89c6-1b5f86ea532c, property_id b0000000-0000-4000-8000-000000000002, reason: "Trình duyệt kiểm thử không có camera".

## Số liệu trước–sau

| Chỉ số | Trước | Sau |
|---|---|---|
| Tồn KHO-T047 NVL0388 | 0 kg | 10 kg |
| Giá vốn NVL0388 | — | 100.000 đ/kg |
| Giá trị tồn NVL0388 | 0 đ | 1.000.000 đ |
| Công nợ SUP0001 (Còn nợ) | 0 đ | 0 đ (đã trả 1.000.000 đ) |
| GRN-...-0008 | — | Đã ghi sổ |
| PO-...-0003 | ĐÃ GỬI | received |
| Hóa đơn C26TAA 0000001 | — | Đã thanh toán |
| PAY-...-0001 | — | ĐÃ THANH TOÁN |

## Lỗi / bất thường mới

1. **C1-N1 [Chặn — đã giải quyết trong bài]** — Bước duyệt đề nghị thanh toán được giao cho vai trò "Kế toán trưởng chuỗi", GM bấm Duyệt → Xác nhận thì bị chặn ("Bạn không phải người duyệt được giao cho bước này."). Bài giao nói "GM hoặc owner duyệt" — sai so với cấu hình bước duyệt thật. Đã giải quyết bằng uat.chief_accountant. **Chuyển Claude Code: xác nhận cấu hình bước duyệt thanh toán (ai duyệt) + sửa bài giao; hoặc xem có cần cho GM duyệt được không.**
2. **C1-N2 [Quyền — cần xác nhận]** — Thủ kho thiếu quyền `receiving.post` ("Bạn chưa được cấp quyền receiving.post để thực hiện thao tác này."); chỉ receiver ghi sổ được phiếu nhận. Bài giao kỳ vọng thủ kho ghi sổ (PIN). Theo mô hình phân quyền hiện tại (`sm_purchasing_store` không có `receiving.post`) thì đây là thiết kế, không phải lỗi app — nhưng mâu thuẫn với bài giao. **Chuyển Claude Code/Duy: xác nhận người ghi sổ phiếu nhận là receiver (đúng thiết kế) hay thủ kho cũng phải ghi sổ được.**
3. **C1-N3 [Giao diện — P2]** — Hộp thoại nhập mã PIN ghi sổ trên màn nhận (mobile) bị panel tóm tắt cuối trang ("Đã ghi 1/1 dòng" + nút "Ghi sổ nhận hàng") che phần dưới, gồm ô nhập PIN 6 chữ số và nút Xác nhận; không bấm chuột được (báo "covered"), chỉ thao tác được bằng bàn phím (Tab/Enter). Tái hiện: uat.storekeeper → phiếu GRN-...-0008 → Ghi sổ → nhập PIN.
4. **C1-N4 [Giao diện — P2]** — Ô chọn Nhà cung cấp/Đơn mua trong form nhập hóa đơn và form đề nghị thanh toán không phản ánh lựa chọn ngay sau khi chọn (phải tải lại trang mới thấy trạng thái đã chọn; lần chọn PO còn hiển thị tùy chọn ở trạng thái disabled).
5. **C1-N5 [Giao diện — P2]** — Duyệt hóa đơn bằng GM không hiện ô xác nhận (Xác nhận/Bỏ qua); một lần bấm "Duyệt hóa đơn" là duyệt luôn — không nhất quán với các thao tác duyệt khác (đề nghị thanh toán có ô xác nhận).
6. **C1-N6 [Audit — P2]** — Nhật ký kiểm toán không có bản ghi nào cho bảng `stock_moves` (lọc table=stock_moves → "Không có bản ghi nào khớp bộ lọc."): bút toán nhập kho chỉ kiểm chứng được qua thẻ kho, không có dấu vết audit cho `stock_moves`.
7. **C1-N7 [Ghi chú]** — Form nhập hóa đơn bắt buộc Ký hiệu và Số hóa đơn để bật nút Lưu (bài không nêu giá trị); đã dùng giá trị kiểm thử C26TAA / 0000001. Hạn trả của đề nghị thanh toán tự mặc định thành 2026-12-14 (30 ngày) dù không nhập. Nút "Đã trả tiền" bắt buộc nhập "Số tham chiếu ngân hàng" mới bật (đã dùng FT2611140001).
