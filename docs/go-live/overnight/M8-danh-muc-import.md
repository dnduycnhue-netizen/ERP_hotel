# M8 — Thử nghiệm Danh mục & Import (CHƯA HOÀN THÀNH — timeout, không có báo cáo cuối)

- Ngày: 14/11/2026, 00:20–02:31 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.owner (đăng nhập tay, xác nhận qua menu tài khoản). Tài khoản thu mua chưa kịp dùng.
- Kết luận: **Chưa hoàn thành — tác vụ trình duyệt hết thời gian chờ (timeout) mà không trả báo cáo cuối. Không xác nhận được import POS hay import danh mục có hoàn tất hay không. Chỉ ghi lại những gì đã xác minh được dưới đây; cần chạy lại M8 (hoặc phần còn lại) khi có thời gian.**
- Commit: `T-M8-partial` (xem git log).

## 1. Những gì đã xác minh được

- Mở được trang `/master/import` và `/inventory/pos-import` bằng tài khoản owner.
- Tải về được 2 file mẫu từ app (mỗi file 18 KB):
  - `mau_vat_tu.xlsx` — 1 sheet "Du lieu", 13 cột theo thứ tự: Mã | Tên | Tên tiếng Anh | Nhóm | ĐVT kho | ĐVT mua | Hệ số mua → kho | ĐVT công thức | Hệ số kho → công thức | Hàng chủ lực | Hạn dùng (ngày) | VAT (%) | Mã cũ (Bravo). Dòng mẫu: NVL0001 | Gạo ST25 | ST25 Rice | NVL Khô | kg | bao | 50 | g | 1000 | x | 365 | 8.
  - `mau_ncc.xlsx` — 1 sheet "Du lieu", 10 cột theo thứ tự: Mã | Tên | Mã số thuế | Loại NCC | Điện thoại | Địa chỉ | Hạn thanh toán (ngày) | Ngân hàng | Số TK | Chủ TK. Dòng mẫu: SUP0001 | Công ty TNHH Thực phẩm Sạch | 0101234567 | công ty | 0901000001 | Hội An, Quảng Nam | 30 | Vietcombank | 1234567890 | CTY TNHH THUC PHAM SACH.
  - Nội dung đọc từ file mẫu gốc trong repo (`public/templates/mau_vat_tu.xlsx`, `mau_ncc.xlsx`) — khớp kích thước file đã tải.
- Đã cấp 3 file cho tác vụ để upload: `pos-test-m8.csv` (tạo từ nội dung mẫu trong đề bài — header + 5 dòng, 2 hóa đơn B20261110-0001/0002, ngày 2026-11-10 ca morning) + 2 file mẫu trên.

## 2. Những gì KHÔNG làm được (do timeout / giới hạn môi trường)

- **Tạo file trong trình duyệt:** cách data: URL để tạo file CSV bị trình duyệt từ chối; file tải về từ app không được tính là file được cấp cho tác vụ ("file ID is not one granted to this task") nên lần upload đầu bị chặn. Sau khi cấp 3 file qua cơ chế grant, các lần thử upload đều bị hủy/không thành — không rõ nguyên nhân (có thể do hết thời gian chờ của tác vụ).
- **Không có bước xác nhận nhập nào được thực hiện** — không xác nhận được:
  - Import POS file hợp lệ (ánh xạ cột, xem trước, tổng 860.000 đ) — CHƯA XÁC MINH.
  - Các trường hợp biên: sai cột (thiếu qty), file rỗng, nạp lại trùng, ký tự lạ — CHƯA XÁC MINH.
  - Import danh mục/NCC: trang /master/import và /master/suppliers chỉ mới mở xem, chưa test lỗi sai loại file, chưa đối chiếu thông báo lỗi có nêu dòng/cột không — CHƯA XÁC MINH.
  - Không xác nhận nhập NCC/vật tư nào (đúng nguyên tắc an toàn — danh mục chung chuỗi).
- **Bài học môi trường:** đính kèm file qua tham số `files` của browser.browse từng hỏng (12/11) khi agent cần ĐỌC file; lần này cấp file để UPLOAD cũng không thành công trong thời gian tác vụ còn lại. Cần kiểm tra lại cơ chế cấp file trước khi chạy lại M8, hoặc thực hiện M8 trên trình duyệt máy (Duy) nơi file có sẵn trên đĩa.

## 3. Trạng thái cuối

- Không có dữ liệu import mới nào được tạo trên TEST47 trong đợt này (không có bước xác nhận nhập nào chạy xong).
- M8 ghi nhận: **Chưa hoàn thành — chạy lại khi có thời gian.** Phần đã xong (nội dung 2 file mẫu) giữ nguyên giá trị, không cần làm lại.

## 4. Lệnh đã chạy

```text
Trình duyệt cloud: tài khoản uat.owner, 00:20–02:31 14/11/2026 (timeout, không có báo cáo cuối)
Đọc file mẫu: python3 + openpyxl trên public/templates/mau_vat_tu.xlsx, mau_ncc.xlsx
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
