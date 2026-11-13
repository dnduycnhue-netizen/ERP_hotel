# M4 — Thử nghiệm khám phá module Nhà hàng

- Ngày: 13/11/2026, 23:42–23:52 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.chef, uat.front_desk, uat.gm (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Đạt một phần — luồng bán/đóng phiên chạy được, 10 phát hiện (4 lỗi hiển thị/tính toán, 1 lỗi tìm kiếm, 1 nút chưa xác minh được, 4 thiếu sót thiết kế/dữ liệu).**
- Commit: `T-M4` (xem git log).

## 1. Luồng chính

| Bước | Kết quả |
|---|---|
| Mở ca | **Đạt (theo thiết kế app):** Bán hàng KHÔNG có nút "mở ca". Khái niệm tương đương là **"Phiên buffet"** (trang Buffet, nút "Thêm phiên"). Tạo phiên 13/11/2026 buổi "Tối", 0 khách, ghi chú "Phiên kiểm thử M4" → trạng thái "MỚI". Form KHÔNG hỏi tiền quỹ đầu ca. |
| Danh sách món | **Đạt:** 82 món (76 buffet + 6 món lẻ). 7/7 món mẫu đều CÓ công thức v1 (VD ALA-02 Tôm Chiên Giòn 145.000 đ, 7 NVL; ALA-03 120.000 đ, 13 NVL; Bu_18 Bò kho, 9 NVL, 30 phần/mẻ). Không tìm được món nào không có công thức; danh sách không có chỉ báo công thức. Toàn bộ 82 món foodcost "Chưa tính được (thiếu giá trần)". |
| Bán món có công thức | **Đạt:** ALA-02 × 1 = 145.000 đ, thông báo "Đã ghi bán." App KHÔNG sinh số hóa đơn — chỉ "dòng bán" (Ngày 2026-11-13, Nguồn "Ghi tay", Trạng thái "—"). Không báo hết hàng dù tồn kho NVL = 0. Trừ kho KHÔNG đo được (màn Tồn kho 0 dòng cả trước và sau khi bán; xem lỗi F-5). |
| Bán món không công thức | **Không thực hiện được:** không xác định được món nào không có công thức. |
| Hủy/hoàn dòng bán | **Chưa xác minh được:** bấm "Hủy dòng" 4 lần (chef ×2, lễ tân ×1, GM ×1) — nút không phản hồi, không thông báo/hộp thoại, dòng bán + tổng 145.000 đ giữ nguyên. Nghi hộp thoại xác nhận hệ thống (trình duyệt tự động không bấm được) — cần người bấm tay. |
| Đóng ca | **Đạt một phần:** đóng phiên buffet 13/11 buổi Tối (1 khách × 0 đ/khách, doanh thu phiên 0 đ). Sau đóng: chỉ đọc, không còn nút "Đóng phiên"/"Hủy phiên", số khách 1, giá/khách 0 đ — nhưng trạng thái "KHÔNG RÕ TRẠNG THÁI" (xem F-1). Không có màn đối soát tiền mặt/thẻ/chênh lệch. |
| Báo cáo | **Đạt:** dòng bán hiện ở Bán hàng ("Dòng bán trong kỳ" + "Theo món", tổng 145.000 đ) và báo cáo "Doanh thu F&B" (01/11–13/11): ALA-02 SL 1, 145.000 đ, giá vốn "—", lãi gộp "—"; Buffet (theo khách) SL 1, 0 đ; tổng 145.000 đ / giá vốn 0 đ / lãi gộp 0 đ. Trang Tổng quan không có mục doanh thu F&B. Lễ tân + GM thấy cùng số liệu. |

## 2. Trường hợp biên

- **a. Số lượng 0/âm — Đạt (bị chặn đúng):** nhập 0 và -1 được, nhưng nút "Ghi bán" vô hiệu, không ghi được, không hiện thông báo lỗi; nhập -1 thì ô bị đánh dấu [invalid]. Tổng giữ 1 món / 145.000 đ.
- **b. Đóng ca trống — Đạt một phần, phát hiện lỗi (F-3):** Số khách = 0 ở mục "Đóng phiên" bị đánh dấu [invalid], nút "Đóng phiên" vô hiệu — không đóng được phiên hoàn toàn trống. Phải nhập 1 khách × 0 đ mới đóng được; phiên vẫn trống doanh thu (0 đ) nhưng mang 1 khách "ảo".
- **c. Tìm món có dấu — Đạt:** gõ "bánh" trả về 13 món (Bu_4 Bánh bèo sốt tôm … ALA-03 Bánh mì nhồi thịt bò nướng 120.000 đ).

## 3. Phát hiện

- **F-1. Trạng thái phiên sau khi đóng hiển thị sai — LỖI UI.** "KHÔNG RÕ TRẠNG THÁI" thay vì "Đã đóng", cả ở danh sách phiên lẫn trang chi tiết, giống nhau ở chef và GM. Tái hiện: Buffet → mở phiên 13/11/2026 buổi Tối → Đóng phiên (1 khách, 0 đ).
- **F-2. Lãi gộp không nhất quán giữa hai màn hình — LỖI TÍNH TOÁN/HIỂN THỊ.** Cùng kỳ 01/11–13/11/2026, cùng 1 món bán ra: trang Bán hàng tổng lãi gộp **145.000 đ** (coi món thiếu giá vốn = 0), báo cáo Doanh thu F&B tổng lãi gộp **0 đ** (loại món thiếu foodcost). Một trong hai cách tính sai — cần chốt quy tắc chung (món thiếu giá vốn thì lãi gộp tính thế nào) rồi sửa màn còn lại. Chuyển Claude Code.
- **F-3. Không đóng được phiên 0 khách — LỖI.** Xem mục 2b. Phiên trống (không khách, không doanh thu) phải đóng được đúng nghĩa.
- **F-4. Bán hàng không kiểm tra tồn kho — LỖI/TÍNH NĂNG THIẾU.** Bán được Tôm Chiên Giòn (cần tôm, trứng, bột…) trong khi tồn kho toàn bộ = 0, không cảnh báo hết hàng nào. Nếu thiết kế cố tình cho bán âm kho thì phải có cảnh báo; nếu không thì phải chặn hoặc cảnh báo. Cần Duy quyết hướng xử lý (ghi vào mục Chuyển Claude Code).
- **F-5. Ô tìm kiếm màn Tồn kho lỗi — LỖI.** Nhập "NVL0096" hoặc "tôm bạc" rồi bấm Lọc → "Không thể tải dữ liệu — Invalid UUID"; danh sách không lọc hiển thị 0 dòng. Không tra cứu được tồn kho một mặt hàng cụ thể. Chuyển Claude Code.
- **F-6. Nút "Hủy dòng" không phản hồi trong trình duyệt tự động — CHƯA XÁC MINH.** 4 lần bấm ở 3 vai trò đều im lặng. Nghi `window.confirm`. Cần người bấm tay xác minh (Duy hoặc test trên Mac). Nếu bấm tay cũng im thì là lỗi thật.
- **F-7. Foodcost toàn bộ 82 món "Chưa tính được (thiếu giá trần)" — DỮ LIỆU.** Giá trần chưa thiết lập trên TEST47 nên giá vốn/lãi gộp từng món không tính được ("—" trong báo cáo). Cần dữ kiện thật (giá trần NVL) hoặc quyết định dùng giá khác làm giá vốn — chờ Duy.
- **F-8. Mở link trực tiếp trang chi tiết món không ổn định — LỖI.** Bò kho (Bu_18) báo "Không thể tải dữ liệu — Đã xảy ra lỗi…", ALA-03 báo "Không tìm thấy trang" (404); bấm từ danh sách thì mở bình thường. Chuyển Claude Code.
- **F-9. Không có số hóa đơn — THIẾU.** Bán hàng chỉ sinh "dòng bán" (Nguồn: Ghi tay/Buffet), không có mã/số hóa đơn để đối chiếu, hoàn, hủy. Cần Duy quyết có cần số hóa đơn không.
- **F-10. Không có đối soát ca — THIẾU.** Mở phiên không hỏi tiền quỹ đầu ca; đóng phiên không hỏi tiền mặt/thẻ, không có màn chênh lệch đối soát. Cần Duy quyết có cần đối soát ca không (đặc thù: buffet tính theo khách, bán lẻ ghi tay).

## 4. Trạng thái cuối (TEST47, ngày 13/11/2026)

- Phiên buffet 13/11 buổi Tối: ĐÃ ĐÓNG (chỉ đọc), 1 khách, doanh thu phiên 0 đ, trạng thái hiển thị "KHÔNG RÕ TRẠNG THÁI", không món trong phiên, ghi chú "Phiên kiểm thử M4".
- Dòng bán đã tạo: (1) Tôm Chiên Giòn (Ghi tay) 1 × 145.000 đ = 145.000 đ, **chưa hủy được**; (2) Buffet (theo khách) 1 × 0 đ = 0 đ (ghi tự động khi đóng phiên). Tổng doanh thu ghi nhận 145.000 đ.
- Không còn ca/phiên nào đang mở. Mục Đặt tiệc/Sảnh tiệc CHƯA kiểm thử.
- Không xóa/sửa dữ liệu có sẵn; không gặp màn hỏi mã PIN; không bị chặn quyền ở bước nào.

## 5. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (chef → front_desk → gm), 23:42–23:52 13/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
