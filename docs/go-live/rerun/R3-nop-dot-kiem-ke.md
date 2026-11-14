# R3 — C3 chạy lại: nộp đợt kiểm kê CNT-...-0005 (NVL0388 đếm 9 / sổ 10)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Kết quả: **KHÔNG ĐẠT (dừng ở bước 1)** — hộp thoại nộp đợt báo "Mã PIN không đúng. Vui lòng thử lại." chung chung, không chỉ rõ PIN của người nào; theo chỉ dẫn của bài đã dừng tại đây, không thử mã khác, không đoán, không nộp lại. Đợt 0005 vẫn ĐANG ĐẾM (1/1 dòng, NVL0388 9 kg), đợt 0004 vẫn ĐANG MỞ; không có dữ liệu nào bị thay đổi, không đợt nào bị hủy/khóa.
- Nhánh `feat/muse-rerun`, commit `T-R3:` (ghi sau khi gate xanh).

## Từng bước

### Bước 1 — Nộp đợt 0005: KHÔNG ĐẠT
- uat.storekeeper@erp.internal (gõ tay email + mật khẩu; phiên ban đầu của trình duyệt đang là tài khoản chủ đầu tư nên đã đăng xuất trước), menu tài khoản xác nhận đúng "UAT Thủ kho / uat.storekeeper@erp.internal", khách sạn "Khách sạn test T047".
- Tình trạng đầu đã xác nhận đúng như mô tả: đợt CNT-TEST47-LE-2611-0005 ĐANG ĐẾM, 1/1 dòng đã đếm, NVL0388 "ba chỉ nách" đã đếm 9 kg (đếm mù); đợt CNT-TEST47-LE-2611-0004 ĐANG MỞ.
- Phát hiện về giao diện: trang chi tiết đợt trên desktop (`…/inventory/counts/c8e54061-4627-47a2-8061-3fefa1608c8e`) **không có dòng hàng, không có ô nhập số đếm và không có nút "Nộp đợt"** — chỉ hiển thị dòng "Bạn chưa được cấp quyền xem chênh lệch — chỉ người có quyền mới xem được biên bản." và hộp "Hủy đợt kiểm kê". Các đường dẫn con `/count`, `/counting`, `/mobile`, `/dem` của đợt đều ra trang "Không tìm thấy trang". Màn đếm và nút nộp chỉ có trên đường mobile `/m/b0000000-0000-4000-8000-000000000002/count/c8e54061-4627-47a2-8061-3fefa1608c8e` (theo hướng dẫn của Muse): màn đếm mù hiển thị đợt 0005, 8 người đếm, "Đã đếm 1/1 dòng", dòng NVL0388 "ba chỉ nách" — ĐVT lưu kho: kg · Đã đếm: 9 kg, cảnh báo "Kho đang bị đóng băng do đợt kiểm kê tháng này — không nhập/xuất được cho đến khi điều chỉnh xong.", và thanh hành động dính đáy có nút "Nộp đợt".
- Hộp thoại "Nộp đợt kiểm kê" (số chứng từ CNT-TEST47-LE-2611-0005) ghi: "Mỗi người đếm nhập mã PIN của mình. Thứ tự nhập không quan trọng." Các ô chỉ ghi nhãn "Mã PIN người đếm 1" đến "Mã PIN người đếm 8", **không ghi tên người tương ứng với từng ô**. Đã nhập mã của 8 người vào 8 ô theo đúng thứ tự 8 người đếm hiển thị trên màn hình: UAT Chủ đầu tư, Dương Ngọc Duy, test 01, Test Storekeeper, UAT Bartender, UAT Bếp trưởng / Bếp, UAT Thủ kho, UAT Thu mua.
- Sau khi bấm "Nộp đợt" trong hộp thoại, nút chuyển sang "Đang nộp…", rồi hộp thoại báo lỗi nguyên văn: **"Mã PIN không đúng. Vui lòng thử lại."** Lỗi này hiện chung ở cuối hộp thoại, không gắn với ô số mấy hay tên người nào, nên không xác định được mã của người nào bị báo sai. Theo chỉ dẫn của bài, đã dừng tại đây, không thử mã khác, không đoán, không nộp lại lần 2.
- Trạng thái sau khi nộp lỗi (kiểm tra lúc 14:56 ngày 14/11/2026, cả trên màn đếm mobile và danh sách desktop): đợt 0005 vẫn ĐANG ĐẾM, vẫn 1/1 dòng đã đếm, NVL0388 vẫn 9 kg; đợt 0004 vẫn ĐANG MỞ. Không có thay đổi trạng thái nào.

### Bước 2 — GM xem chênh lệch + duyệt điều chỉnh: KHÔNG KIỂM ĐƯỢC
Đợt chưa được nộp nên không có gì để GM duyệt; chưa đăng nhập tài khoản GM, chưa xem bảng chênh lệch, chưa bấm nút duyệt.

### Bước 3 — Kiểm chứng sau điều chỉnh: KHÔNG KIỂM ĐƯỢC
Chưa có điều chỉnh nào xảy ra: chưa kiểm tra tồn NVL0388 trên `/inventory/stock`, chưa kiểm tra bút toán −1 kg, chưa thử đếm thêm trên đợt đã khóa, chưa kiểm tra phiếu lĩnh REQ-...-0002 hay trạng thái đóng băng kho sau nộp.

### Bước 4 — Kiểm tra form mở đợt mới: KHÔNG KIỂM ĐƯỢC (chỉ có quan sát lẻ)
Chưa chọn kho KHO-T047, chưa thử chọn người đếm để quan sát nút "Mở đợt", không tạo đợt mới. Chỉ có quan sát lẻ trong lúc tìm màn đếm: form `/inventory/counts/new` có nhãn "Người đếm*" với ghi chú "Kiểm kê tháng cần ít nhất 2 người đếm độc lập (người nhận hàng/xuất kho của kho này không được đếm)."; hai người trong danh sách được gắn nhãn "Người đếm độc lập" (UAT Bartender, UAT Bếp trưởng); nút "Mở đợt kiểm kê" tắt khi chưa chọn người đếm; kho mặc định lúc mở form là "Kho xuất hủy (DISPOSAL)" — các quan sát này chưa đủ để kết luận bước 4.

## Phân tích nguyên nhân từ code (đọc từ repo, không chạm dữ liệu)
- Hàm `count_submit` (`supabase/migrations/20261109533000_count_submit_crypt.sql`): với mỗi người đếm trong `counter_ids`, lấy `pin_hash` của người đó và kiểm tra với **bất kỳ** PIN nào trong 8 ô đã nhập — **thứ tự nhập thật sự không quan trọng**, và **hai người trùng PIN cũng không sao** (cùng một giá trị 111111 khớp được cho cả hai người). Vậy hai giả thuyết "thứ tự ô sai" và "trùng PIN gây lỗi" đều **bị loại trừ**.
- Lỗi `ERR_PIN_INVALID` chỉ xảy ra khi có ít nhất một người đếm mà `pin_hash` lưu trong hệ thống **không khớp với bất kỳ PIN nào trong 8 ô đã nhập** — tức người đó có PIN khác với danh sách đã giao, hoặc **chưa có PIN** (`pin_hash` NULL thì vòng kiểm luôn rớt). Giao diện không chỉ rõ là người nào nên không thể xác định từ phía kiểm thử.
- Hộp thoại nộp (`src/components/count/count-submit-dialog.tsx`) chỉ nhận `counterCount` (số lượng) chứ không nhận tên người đếm — các ô chỉ đánh số 1–8, đúng như quan sát trên giao diện.

## Lỗi / bất thường mới

1. **R3-N1 [Chặn — P1]** — Nộp đợt báo PIN sai chung chung, không chỉ rõ người nào; hộp thoại không gắn tên người với từng ô PIN. Người dùng không có cách nào tự xác định và sửa lỗi từ giao diện. Cần phía quản trị/Duy đối chiếu PIN của 8 người đếm. Tái hiện: đăng nhập uat.storekeeper@erp.internal → màn đếm mobile của đợt 0005 → "Nộp đợt" → nhập đủ 8 mã → bấm "Nộp đợt".
2. **R3-N2 [Giao diện — P2]** — Trang chi tiết đợt trên desktop của thủ kho không hề có lối vào màn đếm/nộp đợt (chỉ có hủy đợt); màn đếm chỉ tồn tại trên đường `/m/…/count/…` mà không có liên kết nào từ giao diện desktop dẫn tới (đã xác minh bằng code: nút "Nộp đợt" chỉ có trong `mobile-count-workspace.tsx`).
3. **R3-N3 [Chặn tiềm ẩn — P1, suy ra từ code, chưa kiểm chứng live]** — Đợt kiểm kê tháng (`monthly_full`) yêu cầu **mỗi dòng phải có đủ 2 lần đếm** (`counted_qty_1` và `counted_qty_2` đều khác NULL) thì `count_submit` mới qua được bước kiểm đủ số liệu, nếu không sẽ báo `ERR_COUNT_INCOMPLETE`. Dòng NVL0388 hiện mới đếm 1 lần (9 kg). Nghĩa là **ngay cả khi PIN đúng, lần nộp tiếp theo nhiều khả năng vẫn rớt vì thiếu lần đếm 2** — cần đếm lần 2 cho dòng NVL0388 (người đếm khác đếm lại) trước khi nộp. Luồng đếm lần 2 trên giao diện vẫn chưa rõ (C3-N5).

## Việc còn lại của R3
Cần Duy/quản trị đối chiếu và đặt lại PIN cho 8 người đếm (đặc biệt kiểm tra người nào chưa có PIN hoặc PIN khác danh sách), sau đó chạy lại từ bước 1 mà không cần làm lại dữ liệu đếm (đợt vẫn ĐANG ĐẾM, dòng NVL0388 vẫn 9 kg) — và nhiều khả năng phải đếm lần 2 cho dòng NVL0388 trước khi nộp.
