# R5 — Quét lại nhanh 5 điểm sửa Q276

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Kết quả: **ĐẠT TOÀN BỘ (5/5)** — tìm kiếm tồn kho không dấu, nút làm mới thẻ kho, ẩn nút Duyệt với người tạo phiếu, thông báo thiếu quyền khi GM mở form tạo PR, định dạng ngày trả — đều đúng như bản sửa Q276.
- Nhánh `feat/muse-rerun`, commit `T-R5:` (ghi sau khi gate xanh).

## Từng bước

### Bước 1 — Tìm kiếm tồn kho không dấu: ĐẠT
- uat.storekeeper@erp.internal, `/inventory/stock`. Gõ "ba chi" (không dấu) trả 1 tồn kho, có NVL0388 "ba chỉ nách": Tồn 10,00 kg, Đã đặt 0,00, Có thể dùng 10,00 kg. Gõ đối chiếu "ba chỉ" (có dấu) cũng trả 1 tồn kho, cùng NVL0388, tồn 10 kg. Lỗi cũ (trả 0 kết quả) đã hết.

### Bước 2 — Nút làm mới thẻ kho: ĐẠT (có lưu ý)
- uat.owner@erp.internal, `/reports/stock-card`. Có nút "Làm mới số liệu thẻ kho". Trước khi bấm, thẻ kho trống: Số dòng 0, Tổng giá trị tồn cuối 0 đ (dù tồn kho live đã là 10 kg). Sau khi bấm, nút chuyển sang "Đang làm mới…" rồi trở lại bình thường, dữ liệu đổi thành 1 dòng: Kho chính T047 | NVL0388 | ba chỉ nách | 14/11/2026 | Tồn đầu 0 | Nhập 10 | Xuất 0 | Tồn cuối 10 | Giá trị tồn cuối 1.000.000 đ; Tổng cộng: Số dòng 1, Tổng giá trị tồn cuối 1.000.000 đ. Tồn cuối 10 kg khớp kỳ vọng.
- Không ghi nhận thông báo toast sau khi bấm — hiệu quả làm mới thể hiện qua việc dữ liệu đổi từ 0 dòng thành 1 dòng.
- Lưu ý: báo cáo này tổng hợp theo kho/mã/lô, không liệt kê từng chứng từ nên số phiếu GRN-TEST47-LE-2611-0008 không hiện trực tiếp trên trang; mức Nhập 10 / Xuất 0 tương ứng với lần nhập 10 kg ngày 14/11 và chưa có xuất (phiếu lĩnh REQ-...-0004 vẫn CHỜ DUYỆT).

### Bước 3 — Người tạo phiếu không thấy nút Duyệt: ĐẠT
- uat.chef@erp.internal, phiếu REQ-TEST47-LE-2611-0004 (`/inventory/requisitions/1daebba4-feda-424b-9248-d8d7f7ac24bd`). Phiếu đang CHỜ DUYỆT, ngày 2026-11-14, Bếp (Demo), Kho xuất Kho chính T047, Kho nhập Kho bếp (Demo), ghi chú "Phiếu lĩnh kiểm thử C7 — thử tự duyệt", mặt hàng NVL0388 ba chỉ nách, kg, 1, Đã xuất 0, Đã nhận 0. Trên trang chỉ có liên kết "← Quay lại", **không có nút "Duyệt", không có nút "Từ chối"**, và cũng không có nút hành động nào khác. Không bấm nút nào.

### Bước 4 — GM mở form tạo PR không có quyền: ĐẠT
- uat.gm@erp.internal, mở trực tiếp `/procurement/pr/new`. Trang chỉ hiện thông báo **"Bạn chưa được cấp quyền tạo yêu cầu mua."** (kèm biểu tượng hộp thư), cùng các tab Yêu cầu mua / Đơn mua / Chờ tôi duyệt / Mua chợ / Tạm ứng / Hợp đồng dịch vụ. Không có form tạo yêu cầu, không nhập gì.

### Bước 5 — Ngày trả trên phiếu thanh toán: ĐẠT
- uat.accountant@erp.internal, phiếu PAY-TEST47-LE-2611-0001 (`/finance/payment-requests/9f7a18df-303f-4812-8693-d05e73a4c9c0`). Phiếu của Công ty TNHH Thực phẩm Mẫu An Phát, ĐÃ THANH TOÁN, Tổng tiền 1.000.000 đ, Số tham chiếu ngân hàng FT2611140001. Dòng ngày trả nguyên văn: **"Ngày trả: 14/11/2026 12:55"** — đúng định dạng dd/mm/yyyy HH:mm, không còn chuỗi ISO dạng "2026-11-14T05:55:53..."; tìm trên trang không thấy chuỗi "2026-11-14T". (Giờ thực tế là 12:55; mốc 12:54:58 là giờ duyệt ở mục "Các bước duyệt": "Đã duyệt · UAT Kế toán trưởng chuỗi · 12:54:58 14/11/2026".) Hóa đơn kèm theo: ký hiệu C26TAA, số 0000001, 1.000.000 đ, Đã thanh toán.

## Lỗi / bất thường mới

1. **R5-N1 [Ghi chú — P3]** — Thẻ kho trước khi làm mới trống hoàn toàn (0 dòng, 0 đ) dù tồn kho live đã 10 kg; số liệu chỉ hiện sau khi bấm làm mới. Trang có ghi chú số liệu đọc từ bảng tổng hợp theo ngày, làm mới lúc 07:35 hàng ngày. (Đây chính là lý do Q276 thêm nút làm mới — nút đã giải quyết được vấn đề.)
2. **R5-N2 [Giao diện — P3]** — Sau khi bấm "Làm mới số liệu thẻ kho" không thấy thông báo/toast xác nhận; chỉ thấy nút chuyển sang "Đang làm mới…" rồi dữ liệu cập nhật.
3. **R5-N3 [Ghi chú]** — Thẻ kho không có chi tiết theo từng chứng từ (không hiển thị số phiếu GRN-TEST47-LE-2611-0008); chỉ có số tổng Nhập/Xuất theo kho/mã/lô.
4. **R5-N4 [Ghi chú — P3]** — Định dạng ngày chưa nhất quán trên cùng trang phiếu thanh toán: "Ngày trả" đã đúng dạng 14/11/2026 12:55 nhưng "Hạn trả" vẫn dạng yyyy-mm-dd: "Hạn trả: 2026-12-14".
5. **R5-N5 [Ngoài phạm vi Q276 — P3]** — Đường dẫn `/finance/payments` trả trang 404 "Không tìm thấy trang"; đường đúng của danh sách phiếu thanh toán là `/finance/payment-requests` (tìm qua ô "Tìm kiếm chức năng…" với từ khóa "Đề nghị thanh toán").
