# V2 — Chu trình chênh lệch + chặn SoD (ĐẠT MỘT PHẦN — chuỗi duyệt/PO/gửi NCC đạt; nhận hàng + SoD còn lại chưa kiểm được)

- Ngày: 14/11/2026, 10:15–10:24 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.purchaser, uat.gm, uat.receiver, uat.accountant (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Đạt một phần — các bước 1–5 (gửi duyệt PR → duyệt PR → tạo PO → duyệt PO → gửi NCC) đều ĐẠT, ô xác nhận trên trang hoạt động ở mọi lần bấm. Bước 6 (nhận 180/200 + 5 hỏng) kẹt camera như V1. Thử chặn SoD "người tạo PR tự duyệt" không thực hiện được theo kịch bản vì GM không có quyền tạo PR (tách biệt ở tầng quyền). Các chặn SoD còn lại chưa kiểm được vì chưa có dòng đã ghi/hóa đơn/đề nghị.**
- Commit: `T-V2` (xem git log).

## 1. Bước 1 — Gửi duyệt PR-0006 (purchaser): ĐẠT

- PR-TEST47-LE-2611-0006 (NVL0561 "Bánh bèo", 200 cái) từ NHÁP → CHỜ DUYỆT. Ô xác nhận trên trang CÓ hiện, nguyên văn: **"Gửi chứng từ này đi duyệt?"**, nút "Xác nhận" / "Bỏ qua". Bấm "Xác nhận" phản hồi ngay, hiện thông báo "Đã gửi duyệt.".

## 2. Bước 2 — Duyệt PR (GM): ĐẠT

- PR-0006 có trong danh sách chờ duyệt ("Quản lý - Chờ duyệt"). Bấm Duyệt mở hộp thoại trên trang có ô "Nhận xét" và nút "Hủy" / "Xác nhận" (không phải ô xác nhận ngắn như nút Gửi duyệt); bấm "Xác nhận" → trạng thái ĐÃ DUYỆT, dòng bước duyệt: "Đã duyệt · UAT Tổng quản lý · 10:17:11 14/11/2026".

## 3. Bước 3 — Tạo PO từ PR-0006 (purchaser): ĐẠT

- Hộp "Tạo đơn mua từ yêu cầu" không gợi ý NCC (ô Nhà cung cấp để trống) nên đã chọn NCC-T047 theo hướng dẫn; kênh Hợp đồng. PO mới: **PO-TEST47-LE-2611-0005**, 1 dòng NVL0561 200 cái, đơn giá 5.000 đ (Nguồn giá: Giá trần), tổng tiền **1.000.000 đ**, trạng thái ban đầu NHÁP. Bấm "Gửi duyệt" → ô xác nhận "Gửi chứng từ này đi duyệt?" → "Xác nhận" → CHỜ DUYỆT.

## 4. Bước 4 — Duyệt PO (GM): ĐẠT

- PO-0005 có trong danh sách chờ duyệt của GM. Bấm Duyệt (hộp thoại Nhận xét → "Xác nhận") → ĐÃ DUYỆT, dòng bước duyệt: "Đã duyệt · UAT Tổng quản lý · 10:19:05 14/11/2026".

## 5. Bước 5 — Gửi cho NCC (purchaser): ĐẠT

- PO-0005: bấm "Gửi cho nhà cung cấp" → ô xác nhận trên trang "Gửi đơn mua này cho nhà cung cấp?" → "Xác nhận" → trạng thái cuối **ĐÃ GỬI** (chỉ còn nút "Đóng đơn"). Sau khi tạo PO, trạng thái PR-0006 đổi thành "ĐÃ CHUYỂN PO".

## 6. Bước 6 — Nhận hàng 180/200 + 5 hỏng (receiver): KHÔNG ĐẠT — kẹt camera

- Nhiệm vụ nhận PO-0005 có trong danh sách (3 phiếu chờ nhận); bấm "Mở phiếu nhận" tạo phiếu nhận nháp mới **GRN-TEST47-LE-2611-0007** (kho mặc định Kho bếp (Demo)). Trên màn nhập dòng đã nhập Số cân 180, Bì 0, Số thực nhận tự tính 180 cái; **màn nhập dòng KHÔNG có ô ghi chú nên không ghi được thông tin "hỏng 5 cái"** (xem N-3).
- Bấm "Chụp ảnh" → nguyên văn: **"Không tìm thấy camera trên thiết bị này. Hãy dùng thiết bị có camera rồi thử lại."** Nút "Ghi dòng" và "Ghi sổ nhận hàng" vẫn bị vô hiệu, không ghi được dòng, không ghi sổ được. Phiếu GRN-0007 vẫn nháp "Đã ghi 0/1 dòng"; PO-0005 vẫn "Đã nhận 0". Điểm chặn đã biết, tái hiện đúng như V1.

## 7. Bước 7 — Thử chặn SoD "người tạo PR không duyệt PR" (GM): KHÔNG KIỂM ĐƯỢC THEO KỊCH BẢN

- Trang tạo PR (/procurement/pr/new) mở được, đã nhập đủ NVL0561 1 cái, ghi chú "PR kiểm thử SoD V2 — GM tự tạo", nhưng bấm "Lưu nháp" 2 lần đều bị chặn, nguyên văn: **"Bạn chưa được cấp quyền pr.create để thực hiện thao tác này."** Danh sách PR vẫn 6 phiếu, không có PR SoD mới; trong danh sách PR của GM cũng không có nút "Tạo yêu cầu".
- Do đó không có PR do GM tạo để GM tự duyệt, không bấm được nút Duyệt, không thu được thông báo chặn SoD khi duyệt (cũng không có mã lỗi thô dạng ERR_...).
- **Về bản chất, việc tách biệt đã xảy ra ở tầng quyền: GM có quyền duyệt nhưng không có quyền tạo PR, nên kịch bản "GM tự tạo rồi tự duyệt" không thể xảy ra bằng tài khoản GM.** Đây là một dạng đảm bảo SoD khác (tách quyền thay vì chặn lúc duyệt) — cần Duy/Claude xác nhận có chấp nhận không, hay vẫn cần chặn SoD ở tầng RPC cho trường hợp người tạo trùng người duyệt (VD tài khoản vừa có pr.create vừa có bước duyệt).

## 8. Bước 8 — Các chặn SoD còn lại: CHƯA KIỂM ĐƯỢC

- (a) Người nhận không ghi sổ phiếu mình mở: **chưa kiểm được — kẹt chụp ảnh** (bước 6, chưa có dòng đã ghi).
- (b) Kế toán không duyệt hóa đơn mình tạo: **chưa kiểm được — không có hóa đơn** (đã đăng nhập kế toán kiểm tra trực tiếp: Tài chính → Hóa đơn: "Chưa có dòng nào phù hợp với bộ lọc hiện tại.", tổng quan tài chính "0 hóa đơn nhà cung cấp · Nháp/Tạm giữ", "Còn phải trả 0 đ", "Quá hạn 0 đ").
- (c) Người tạo đề nghị thanh toán không duyệt: **chưa kiểm được — không có đề nghị nào** (tổng quan tài chính: "Đề nghị chờ duyệt 0").

## 9. Bước 9 — Kiểm tra nhanh: ĐẠT (phần xem được)

- /receiving/returns với tài khoản purchaser: 0 phiếu trả NCC, "Chưa có phiếu trả hàng nào.", KHÔNG có nút tạo mới trên trang. (Với GM và receiver, trang này bị chặn quyền — xem N-4.)
- Chi tiết PO-0005 (purchaser) chỉ có: thông tin chung (NCC T047 · Hợp đồng · Ngày đặt 14/11/2026 · Ngày dự kiến nhận 14/11/2026 · Tổng tiền 1.000.000 đ), Dòng hàng (1 dòng NVL0561 200 cái × 5.000 đ, Giá trần, Đã nhận 0, 1.000.000 đ), Duyệt · Các bước duyệt (1 Quản lý — Đã duyệt · UAT Tổng quản lý · 10:19:05 14/11/2026). **KHÔNG có mục đối chiếu 3 chiều, không có mục phiếu nhận/hóa đơn trên trang chi tiết PO** (M2 F-3 vẫn mở — vị trí đối chiếu 3 chiều chưa xác định).

## 10. Phát hiện mới

- **N-1. [Giao diện] Trạng thái (badge) không cập nhật ngay sau khi bấm "Xác nhận":** Gửi duyệt PR (bước 1), Gửi duyệt PO (bước 3), Duyệt PO (bước 4), Gửi cho NCC (bước 5) — thông báo "Đã gửi duyệt."/"Đã duyệt." đã hiện nhưng badge vẫn giữ trạng thái cũ cho tới khi tải lại trang mới thấy trạng thái mới. (Riêng Duyệt PR ở bước 2 cập nhật ngay thành ĐÃ DUYỆT.) Tái hiện: mở chi tiết PR/PO → bấm nút chuyển trạng thái → bấm "Xác nhận" trên ô xác nhận trên trang → quan sát badge trước khi tải lại. Chuyển Claude Code (P2 — UI stale).
- **N-2. [Giao diện/quyền] Form tạo PR của GM cho nhập đầy đủ rồi mới báo lỗi quyền khi bấm "Lưu nháp"** ("Bạn chưa được cấp quyền pr.create để thực hiện thao tác này."), thay vì chặn/vô hiệu ngay khi mở form; danh sách PR của GM cũng không có nút "Tạo yêu cầu" trong khi purchaser có (không nhất quán: danh sách ẩn nút nhưng URL trực tiếp vẫn mở được form). Chuyển Claude Code (P2).
- **N-3. [Giao diện] Màn nhập dòng phiếu nhận mobile không có ô ghi chú** — không thể ghi chú hàng hỏng (5 cái) trên dòng nhận. Chuyển Claude Code (P2 — cần ô ghi chú/QC để ghi hỏng/thiếu).
- **N-4. [Quyền] Quyền xem phiếu trả NCC không đồng nhất:** /receiving/returns với GM và receiver đều lỗi "Không thể tải dữ liệu — Bạn chưa được cấp quyền receiving.view để thực hiện thao tác này.", chỉ purchaser xem được (0 phiếu, không có nút tạo mới). Ngoài ra, mục "Nhận hàng" trên desktop với receiver trả "Không tìm thấy trang…" (receiver chỉ nhận hàng được qua trang mobile /m/.../receive). Chuyển Claude Code/Duy xác nhận: GM và receiver có cần xem phiếu trả NCC không (P1 — xác nhận quyền).
- **N-5. [Môi trường — chặn] Điểm chặn camera ở bước 6 vẫn tồn tại** (đã biết từ V1) — toàn bộ chuỗi chênh lệch (nhận thiếu 20 cái, hỏng 5 cái → đối chiếu 3 chiều → trả NCC/hóa đơn) vẫn kẹt tại đây. Cần thiết bị thật có camera hoặc camera giả hoạt động.

## 11. Dữ liệu kiểm thử đã tạo trên TEST47

- PO PO-TEST47-LE-2611-0005 (ĐÃ GỬI, 1.000.000 đ, NVL0561 200 cái, NCC-T047).
- Phiếu nhận nháp GRN-TEST47-LE-2611-0007 (0/1 dòng, chưa ghi sổ).
- Không tạo thêm PR SoD nào (bị chặn quyền). Không có mã PIN nào được ghi trong báo cáo này.

## 12. Kết quả xác minh các lỗi cũ trong V2

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q272 B-33 | Ô xác nhận trên trang thay hộp thoại trình duyệt (Gửi duyệt PR/PO, Gửi NCC) | **Đạt** — hoạt động ở cả 5 lần bấm |
| M2 F-3 | Vị trí đối chiếu 3 chiều trên trang PO | **Vẫn mở** — trang PO-0005 không có mục đối chiếu 3 chiều |
| SoD | Người tạo PR không duyệt PR | **Không kiểm được theo kịch bản** — GM không có pr.create (tách biệt ở tầng quyền) |
| SoD | Người nhận/kế toán/người tạo đề nghị | **Chưa kiểm được** — kẹt camera / không có hóa đơn / đề nghị |

## 13. Lệnh đã chạy

```text
Trình duyệt cloud: 4 tài khoản uat.* (purchaser → gm → receiver → accountant), 10:15–10:24 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
