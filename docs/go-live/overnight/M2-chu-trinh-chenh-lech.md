# M2 — Chu trình Chênh lệch nhận hàng (BẢN RÚT GỌN — chu trình đầy đủ chưa chạy được)

- Ngày: 14/11/2026, 02:48–02:53 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.purchaser, uat.gm, uat.storekeeper (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Chưa hoàn thành chu trình đầy đủ — chỉ làm được tới tạo PR nháp + kiểm tra UI. Chu trình đầy đủ (nhận thiếu 180/200 + 5 hỏng → biên bản chênh lệch → trả NCC → đối chiếu 3 chiều → SoD) bị chặn bởi: nút "Gửi duyệt" không phản hồi trong trình duyệt tự động (hộp thoại xác nhận), ghi dòng nhận hàng bắt chụp ảnh (cloud không có camera). PR-TEST47-LE-2611-0006 đã tạo sẵn ở trạng thái NHÁP để chạy tiếp khi có người + camera.**
- Commit: `T-M2-partial` (xem git log).

## 1. Bước 1 — Tạo PR nháp: ĐẠT

- **PR-TEST47-LE-2611-0006**, trạng thái NHÁP, loại Vật tư, ngày 14/11/2026, người tạo UAT Thu mua. 1 dòng duy nhất: NVL0561 "Bánh bèo" — 200 cai, ghi chú "PR kiểm thử M2 — nhận thiếu/hỏng". Chưa chuyển PO (Đã chuyển PO: 0, Còn lại: 200).

## 2. Bước 2 — Thử gửi duyệt: KHÔNG PHẢN HỒI (đúng như kỳ vọng đã biết)

- Bấm "Gửi duyệt" trên PR-0006: không xuất hiện hộp thoại, không thông báo, không đổi trạng thái. Tải lại trang chi tiết PR vẫn là NHÁP, nút "Gửi duyệt" vẫn hiện. Ghi nhận: "nút không phản hồi trong trình duyệt tự động (nghi hộp thoại xác nhận)" — KHÔNG kết luận app hỏng.

## 3. Bước 3 — Kiểm tra phê duyệt (GM): trống, nhất quán

- /procurement/approvals: "Không có chứng từ nào chờ bạn duyệt. Khi có yêu cầu mua hoặc đơn mua tới bước duyệt của bạn, chúng sẽ hiện ở đây." — nhất quán vì PR-0006 chưa gửi duyệt thành công nên chưa tới GM. Không bấm duyệt/từ chối bất kỳ chứng từ nào.

## 4. Bước 4 — Kiểm tra UI chênh lệch: KHÔNG TÌM THẤY

- Trang trung tâm Nhận hàng (/receiving) chỉ có 3 mục: "Danh sách phiếu nhận" ("Danh sách phiếu nhận đã mở và đã ghi sổ, lọc theo trạng thái."), "Phiếu trả hàng NCC" ("Phiếu trả hàng cho nhà cung cấp sau khi nhận."), "Nhận hàng trên mobile" ("Mở nhiệm vụ nhận hôm nay trên màn hình hiện trường."). **Không có mục biên bản chênh lệch / xử lý thiếu-hỏng ở các nơi đã xem.**
- Danh sách phiếu nhận có 6 phiếu, tất cả NHÁP (GRN-TEST47-LE-2611-0001 → 0006), trong đó GRN-...-0001 có 2 dòng hàng, PO-...-0001, NCC T047. **Mã phiếu trong danh sách liên kết tới trang chi tiết PO, không mở được phiếu nhận ở chế độ xem từ danh sách (xem F-4).**
- Màn hình mobile (/m/…/receive) liệt kê 2 nhiệm vụ nhận (NCC T047 — PO-0001 · 2 dòng; Công ty TNHH Thực phẩm Mẫu An Phát — PO-0003 · 1 dòng), cũng không có mục chênh lệch; bấm vào nhiệm vụ thì mở hộp thoại "Mở phiếu nhận hàng" (chọn kho rồi tạo phiếu nháp mới) nên đã bấm Hủy, không đi vào màn nhập dòng nhận.

## 5. Bước 5 — Kiểm tra đối chiếu 3 chiều (PO-0001): KHÔNG CÓ MỤC NÀY

- Chi tiết PO-TEST47-LE-2611-0001 (ĐÃ GỬI, NCC T047, Hợp đồng, ngày đặt 12/11/2026, tổng 1.040.000 đ) CHỈ CÓ 2 mục: "Dòng hàng (2)" — NVL0388 ba chỉ nách 10 kg × 100.000 đ = 1.000.000 đ, ĐÃ NHẬN 0; NVL0561 Bánh bèo 8 cai × 5.000 đ = 40.000 đ, ĐÃ NHẬN 0 — và "Duyệt · Các bước duyệt" — "1 Trưởng bộ phận — Đã duyệt · Test Approver Receiver · 15:54:42 12/11/2026" + "Tự động duyệt: PR đã được trưởng outlet duyệt". **KHÔNG có mục đối chiếu 3 chiều (PO vs phiếu nhận vs hóa đơn) nào trên trang, đã cuộn hết trang để kiểm tra (xem F-5).**

## 6. Bước 6 — Kiểm tra phiếu trả NCC: 0 phiếu, không có nút tạo mới

- /receiving/returns: "0 phiếu trả hàng ncc", "Chưa có phiếu trả hàng nào." Bộ lọc: Tất cả / Chờ xác nhận / Đã lấy hàng / Đã hủy. **KHÔNG có nút tạo mới trên trang danh sách này** — chỉ xem, không tạo, đúng yêu cầu. (Phiếu trả được tạo từ đâu — có thể từ trong phiếu nhận đã ghi sổ — chưa xác minh được vì chưa có phiếu nhận nào ghi sổ.)

## 7. Phát hiện mới

- **F-1. [Quyền] Tài khoản Thủ kho không mở được trang chi tiết PO:** "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn." Thủ kho vì vậy cũng không xem được phiếu nhận qua liên kết trong danh sách phiếu nhận. Chuyển Claude Code/Duy xác nhận: thủ kho có cần xem PO không (để đối chiếu khi nhận)?
- **F-2. [UI] Liên kết mã phiếu nhận trong danh sách /inventory/receipts trỏ tới trang chi tiết PO thay vì chi tiết phiếu nhận** — thủ kho không có đường xem trực tiếp phiếu nhận nháp (VD GRN-...-0001) từ danh sách desktop. Chuyển Claude Code.
- **F-3. [Thiết kế — cần xác định] Trang chi tiết PO hoàn toàn không có mục đối chiếu 3 chiều** (không phải "có mục nhưng trống dữ liệu") — cần xác định đối chiếu 3 chiều nằm ở màn hình khác (VD màn khớp hóa đơn /finance) hay chưa được xây dựng. Chuyển Claude Code/Duy xác nhận.
- **F-4. [Nhỏ] Đường dẫn /receiving/mobile báo "Không tìm thấy trang" với tài khoản Thủ kho;** đường dẫn mobile đúng là /m/`<uuid>`/receive (theo thẻ "Nhận hàng trên mobile" ở trung tâm Nhận hàng).

## 8. Điểm chặn khiến chu trình đầy đủ chưa chạy được + cần gì để chạy tiếp

1. (Đã biết, đã xác nhận) Nút "Gửi duyệt" không phản hồi trong trình duyệt tự động — PR-0006 vẫn kẹt ở NHÁP nên toàn bộ chuỗi duyệt → PO → nhận hàng từ PR này chưa thể bắt đầu.
2. (Đã biết, chưa kiểm chứng trực tiếp trong bài này) Ghi dòng nhận hàng bắt chụp ảnh mà trình duyệt cloud không có camera — màn hình nhập dòng nhận chưa được mở (mở vào sẽ tạo phiếu nhận nháp mới, ngoài phạm vi cho phép), nên điểm chặn này vẫn giữ nguyên.
3. (Mới) Quyền xem PO của Thủ kho + đường xem chi tiết phiếu nhận (F-1, F-2).
4. (Mới) Vị trí thực của UI biên bản chênh lệch và UI đối chiếu 3 chiều (F-3, mục 4).

**Để chạy tiếp chu trình đầy đủ:** (a) Người thao tác tay trên trình duyệt thật có camera: bấm "Gửi duyệt" cho PR-TEST47-LE-2611-0006 qua hộp thoại xác nhận, sau đó GM duyệt, tạo PO, rồi thủ kho nhận hàng 180/200 + 5 hỏng và chụp ảnh minh chứng ngay tại màn hình nhập dòng nhận. (b) Làm rõ quyền xem PO của Thủ kho và đường xem chi tiết phiếu nhận, để thủ kho xem được phiếu nhận/biên bản. (c) Xác định vị trí thực của UI biên bản chênh lệch và UI đối chiếu 3 chiều (nếu có ở màn hình khác) trước khi chạy lại bài đầy đủ.

## 9. Dữ liệu tạo thêm trong đợt này

- 1 PR nháp PR-TEST47-LE-2611-0006 (NVL0561 200 cái) — để sẵn cho lần chạy tiếp.
- Không tạo phiếu trả NCC, không duyệt/từ chối chứng từ nào, không xóa/sửa dữ liệu có sẵn.

## 10. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (purchaser → gm → storekeeper), 02:48–02:53 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
