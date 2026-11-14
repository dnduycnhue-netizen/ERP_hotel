# V1 — Chu trình mua → nhận → hóa đơn → thanh toán (KHÔNG HOÀN THÀNH — kẹt chụp ảnh)

- Ngày: 14/11/2026, 10:05–10:12 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.receiver, uat.accountant, uat.owner (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Không hoàn thành — chặn ở bước 6 (nhận hàng) vì trình duyệt cloud không có camera, chụp ảnh bắt buộc để ghi dòng. Đã làm theo hướng dẫn dự phòng: dừng phần nhận hàng, kiểm tra (a)(b)(c)(d) và kiểm tra cuối. Không tạo hóa đơn/đề nghị/công nợ giả; không xóa/sửa dữ liệu có sẵn.**
- Commit: `T-V1` (xem git log).

## 1. Bước 6 — Nhận hàng mù (receiver, GRN-...-0006): KHÔNG ĐẠT, kẹt chụp ảnh

- Kiểm tra mù: màn nhập dòng CHỈ hiện tên mặt hàng "ba chỉ nách", Đặc tả "Thịt & Cá", đơn vị "kg · Bắt buộc chụp ảnh", các ô Số cân / Bì / Số thực nhận và QC Người nhập (mặc định Đạt). **KHÔNG thấy số lượng đặt, KHÔNG thấy đơn giá PO** ở màn này; tiêu đề chỉ có mã phiếu, mã PO và tên NCC.
- (d) Trong suốt quá trình dùng tài khoản receiver (màn nhận hàng mobile, trang tổng quan, danh mục kho): **KHÔNG thấy số lượng đặt/đơn giá PO ở bất kỳ màn nào — ĐẠT** (phần màn hình). Kiểm tra phản hồi mạng qua DevTools: **chưa làm được** — trình duyệt tự động không mở được DevTools (ghi rõ giới hạn).
- Cân lần 1: nhập Số cân 10, Bì 0 → Số thực nhận tự tính 10 kg, nhập được, không có thông báo chặn. Cân lần 2 **chưa kiểm chứng được**: giao diện chỉ có một bộ 3 ô cân, không có ô cân lần 2 riêng; nút "Ghi dòng" đã bị mờ nên không tới được bước cân lần 2 / quy tắc chênh ±5%.
- Chụp ảnh: bấm "Chụp ảnh" → nguyên văn: **"Không tìm thấy camera trên thiết bị này. Hãy dùng thiết bị có camera rồi thử lại."** Bấm "Thử lại" vẫn báo đúng câu đó. Nút "Ghi dòng" và "Ghi sổ nhận hàng" vẫn bị mờ. Phiếu sau đó vẫn Nháp, 0/1 dòng; tải lại trang thì các số cân đã nhập bị mất (dòng chưa lưu). Mã PIN của receiver chưa từng được hỏi nên chưa dùng tới.
- Tái hiện: uat.receiver → https://erphotel.vercel.app/m/b0000000-0000-4000-8000-000000000002/receive/3807430e-33bf-4d64-9867-0dbfa48a24b6 → nhập cân 10/0/10 → bấm "Chụp ảnh".

## 2. Bước 7 — Kiểm tra tồn sau nhận: KHÔNG ĐẠT (tồn không tăng)

- Với receiver, /inventory/stock và /inventory/receipts đều trả trang "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn." (sidebar của receiver chỉ có Tổng quan và Danh mục). Với owner, /inventory/stock lọc Kho chính T047 + tìm NVL0388 cho "0 tồn kho" (lọc Tất cả các kho cũng 0). Không có số lượng, không hiện giá vốn — kỳ vọng 10 kg × 100.000 đ/kg không đạt.
- Lưu ý: receiver không có quyền xem tồn kho là đúng theo phân quyền (không phải lỗi) — bước 7 nên dùng storekeeper/owner để kiểm tra tồn.

## 3. Bước 8 — Nhập hóa đơn (accountant): form ĐẠT, tạo hóa đơn KHÔNG ĐẠT (chưa nhận hàng)

- **(a) ĐẠT — form "Nhập hóa đơn mới" mở được.**
- **(b) ĐẠT — ô "Đơn mua" khi chưa chọn NCC hiện nguyên văn: "Hãy chọn nhà cung cấp trước để thấy danh sách đơn mua."** Chọn NCC SUP0001 rồi chọn PO-...-0003 (hiển thị "PO-TEST47-LE-2611-0003 · sent", lúc đầu phản ánh chậm vài giây mới chọn được). Dòng hóa đơn nạp: ba chỉ nách, Đơn giá 100.000 đ, SL đặt 10, SL đã nhận 0, SL hóa đơn 10, Thành tiền 1.000.000 đ; Trước thuế 1.000.000 đ, Thuế 0 đ, Tổng cộng (VND) 1.000.000 đ; Ngày hóa đơn mặc định 14/11/2026.
- **KHÔNG gửi form, KHÔNG tạo hóa đơn:** vì phiếu nhận chưa ghi sổ (SL đã nhận = 0), tạo hóa đơn sẽ sinh công nợ 1.000.000 đ khi chưa nhận hàng — quyết định đúng, không tạo dữ liệu sai. Đã điền thử Số hóa đơn HD-V1-1411 để kiểm tra điều kiện Lưu (nút Lưu chỉ sáng sau khi điền thêm Ký hiệu — chỉ điền thử, không gửi). Kiểm chứng sau tại /finance/invoices: danh sách trống — không có hóa đơn nào được tạo.
- Vì vậy bước 8 về tạo hóa đơn: **KHÔNG ĐẠT** (không tạo được hóa đơn hợp lệ theo PO + phiếu nhận — do bước 6 kẹt).

## 4. Bước 9–12: KHÔNG LÀM ĐƯỢC (không có hóa đơn)

- Bước 9 (duyệt hóa đơn, GM), bước 10 (đề nghị thanh toán), bước 11 (duyệt thanh toán), bước 12 (đánh dấu đã thanh toán) — đều không làm được vì không có hóa đơn nào để duyệt/lập đề nghị.

## 5. Kiểm tra cuối (owner)

1. Tồn kho: NVL0388 ở Kho chính T047 = 0 (không có dòng tồn kho), không hiện giá vốn. Kỳ vọng 10 kg: không đạt (do chưa nhận hàng).
2. Thẻ kho (/reports → Thẻ kho, 01/11–14/11/2026, Kho chính T047): Số dòng 0, Tổng giá trị tồn cuối 0 đ — 0 bút toán nhập NVL0388 (kỳ vọng 1 bút toán 10 kg: không đạt; lọc tất cả kho cũng 0 dòng).
3. Công nợ (/finance/payables): NCC SUP0001 = 0 đ (Còn phải trả 0 đ, Quá hạn 0 đ, không có dòng nào). Con số 0 đ này là hiển nhiên vì chưa có hóa đơn nào được tạo, **KHÔNG phải vì đã thanh toán — không chứng minh được chu trình thanh toán**.
4. Trang Tổng quan, mục "Sáng nay": **CÓ số liệu — ĐẠT**: Chi mua hàng hôm qua 0 đ; Giá trị hủy hôm qua 0 đ; Cảnh báo đỏ chưa xử lý 8; Công nợ đến hạn 7 ngày 0 đ; Tạm ứng quá hạn 0; banner "Có việc cần xem: cảnh báo đỏ, tạm ứng quá hạn hoặc hợp đồng sắp đến hạn."
5. **(c) ĐẠT — /inventory/receipts: bấm mã GRN-...-0006 mở tới CHÍNH PHIẾU NHẬN (màn mobile), không phải trang chi tiết PO.** URL đích: …/m/b0000000-0000-4000-8000-000000000002/receive/3807430e-33bf-4d64-9867-0dbfa48a24b6 — phiếu vẫn Nháp, 0/1 dòng. (Với receiver, /inventory/receipts trả 404 như ở bước 7 — receiver không có quyền xem màn này.)

## 6. Phát hiện mới

- **N-1. [Môi trường — chặn] Camera giả của Chromium không hoạt động trong trình duyệt cloud** ("Không tìm thấy camera trên thiết bị này") dù bài giao ghi là đã bật. Đây là giới hạn môi trường kiểm thử, không phải lỗi app — nhưng nó chặn toàn bộ V1 (bước 6–12), V2 (phần nhận), V4 (phần chụp ảnh hủy hàng). Cần chạy lại trên thiết bị thật có camera hoặc bật lại camera giả. Chuyển Duy/Claude Code quyết cách chạy tiếp.
- **N-2. [Giao diện — nhỏ] Số cân đã nhập trên màn nhận hàng mobile bị mất khi tải lại trang** (dòng chưa lưu thì không có lưu tạm). Tái hiện: nhập cân 10/0/10 → tải lại trang → các ô trống lại. Chuyển Claude Code (P2).
- **N-3. [Cần xác minh — có thể là lỗi] Form hóa đơn không chặn SL hóa đơn vượt SL đã nhận ở mức nút Lưu:** SL hóa đơn 10 trong khi SL đã nhận 0, nút Lưu vẫn sáng sau khi đủ Ký hiệu + Số hóa đơn (dù có ghi chú "khớp 3 chiều so với số đã nhận"). **Chưa kiểm chứng mức chặn khi gửi** (đã không gửi form vì không muốn tạo công nợ sai). Cần Claude Code xác nhận RPC `invoice_*` có chặn không — nếu không chặn thì đây là lỗi thật (tạo được hóa đơn cho hàng chưa nhận). Chuyển Claude Code (P1 — xác minh).
- **N-4. [Ghi nhận] Số "Cảnh báo đỏ chưa xử lý" thay đổi 8 → 10 trong phiên làm việc của owner (chuông thông báo)** — chưa xác định nguyên nhân (có thể có cảnh báo mới sinh trong lúc làm việc). Ghi nhận, chưa kết luận.
- **N-5. [Giao diện — nhỏ] Các lựa chọn trên form hóa đơn (chọn NCC, chọn PO) và một số lần chuyển trang phản ánh chậm vài giây**, lúc đầu dễ tưởng là bị vô hiệu hóa. Ghi nhận.
- **N-6. [Ghi nhận dữ liệu có sẵn]** Danh sách phiếu nhận đã có nhiều phiếu nháp 0 dòng cho cùng PO-...-0003 (GRN-...-0003, -0004, -0006) và PO-...-0001; GRN-...-0001 Nháp với 2 dòng. Không chạm tới.

## 7. Kết quả xác minh các lỗi cũ trong V1

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q267 (a) | Kế toán mở được form hóa đơn | **Đạt** |
| Q272 (b) | Ô Đơn mua gợi ý "chọn NCC trước" | **Đạt** — "Hãy chọn nhà cung cấp trước để thấy danh sách đơn mua." |
| Q271 B-18 (c) | Mã phiếu nhận mở tới chính phiếu nhận | **Đạt** |
| (d) | Người nhận không thấy số lượng/giá PO | **Đạt** (màn hình; network chưa kiểm được) |
| Chu trình V1 | Tồn 10 kg, thẻ kho 1 bút toán, công nợ về 0 sau thanh toán | **Không kiểm được** — kẹt bước 6 (camera) |

## 8. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (receiver → accountant → owner), 10:05–10:12 14/11/2026 (failed — kẹt camera)
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
