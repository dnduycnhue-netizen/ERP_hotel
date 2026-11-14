# V3 — Kiểm kê đếm mù (KHÔNG HOÀN THÀNH LUỒNG CHÍNH — trang tạo đợt đã sửa, nhưng 0 dòng đếm khi tồn = 0)

- Ngày: 14/11/2026, 10:26–10:32 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.storekeeper (đăng nhập tay, xác nhận qua menu tài khoản; trước đó trình duyệt còn phiên accountant nên đã đăng xuất).
- Kết luận: **Không hoàn thành được luồng chính — trang tạo đợt đã tải được ở cả hai đường (lỗi máy chủ đêm 13/11 đã được sửa), nhưng cả đợt Kiểm kê tháng và đợt Kiểm kê luân phiên đều sinh 0 dòng đếm khi tồn kho bằng 0, nên không có dòng nào để đếm, không kiểm được đếm mù, chênh lệch, duyệt, điều chỉnh tồn và khóa đợt. Kết luận cốt lõi: đếm cần mặt hàng có tồn — các bước đếm/duyệt/khóa cần có tồn trước (phụ thuộc bài nhận hàng V1).**
- Commit: `T-V3` (xem git log).

## 1. Bước 1 — Mở đợt kiểm kê tháng (storekeeper, desktop): ĐẠT (trang tải được)

- Trang /inventory/counts hiện 2 đợt xe đẩy cũ CNT-...-0001/0002 (CHỜ DUYỆT) — không chạm tới. Nút "Mở đợt kiểm kê" mở được /inventory/counts/new, **không còn lỗi máy chủ — B-1 ĐẠT**.
- Chọn Kho chính T047 (KHO-T047), loại Kiểm kê tháng (mặc định; trong danh sách chỉ có "Kiểm kê tháng" và "Kiểm kê luân phiên", **không có loại theo ca**), ngày 14/11/2026.
- Mục chọn người đếm chỉ liệt kê 8 người: Dương Ngọc Duy; test 01 / 0001; Test Storekeeper / TEST03; UAT Bartender / UAT-BARTENDER; UAT Bếp trưởng / Bếp / UAT-CHEF; UAT Chủ đầu tư / UAT-OWNER; UAT Thủ kho / UAT-STOREKEEPER; UAT Thu mua / UAT-PURCHASER — **KHÔNG có UAT Receiver (người nhận hàng)** trong danh sách.
- Đợt đã mở: **CNT-TEST47-LE-2611-0003**, ngày 14/11/2026, Kho chính T047, Kiểm kê tháng, trạng thái ĐANG MỞ, 8 người đếm (cả 8 người trên).
- Lưu ý: các cặp 2 người đều bị chặn với nguyên văn **"Đợt kiểm kê cần ít nhất một người đếm độc lập, không phải người nhập hoặc xuất kho tại kho này."** — đã thử Thủ kho+Thu mua, Thủ kho+Chủ đầu tư, Thủ kho+Dương Ngọc Duy, Dương Ngọc Duy+Chủ đầu tư (đều lỗi); chỉ khi chọn cả 8 người thì đợt mới mở được (xem N-2).

## 2. Bước 2 — Trang tạo đợt mobile: ĐẠT (chỉ xem, không mở đợt thứ hai)

- Trang /m/b0000000-0000-4000-8000-000000000002/count/new tải được, hiện form "Mở đợt kiểm kê" với Kho*, Loại kiểm kê* (Kiểm kê tháng), Ngày kiểm kê* 14/11/2026, Người đếm* ("Đang tải dữ liệu…"). Không bấm "Mở đợt kiểm kê" trên mobile. **B-1 ĐẠT ở cả hai đường.**

## 3. Bước 3 — Đếm mù người đếm 1 (storekeeper, mobile): KHÔNG KIỂM ĐƯỢC (0 dòng đếm)

- Màn đếm đợt 0003 hiện "Đã đếm 0/0 dòng", "Đợt này chưa có dòng đếm nào."; trang chi tiết desktop của đợt cũng không có mục dòng đếm hay nút thêm mặt hàng. Đã thử tìm theo mã NVL0388, theo tên "ba chỉ", nhấn Enter, cuộn trang và tải lại trang — vẫn 0 dòng, không có ô nhập số lượng nào để nhập 2 kg.
- Trên các màn hình đã xem (danh sách đợt, chi tiết đợt, ô tìm kiếm) không thấy tồn lý thuyết, số lượng kỳ vọng hay giá trị tồn — chỉ có các số 0 của tiến độ đếm (0/0 dòng). **Chưa có màn nhập số lượng thực tế để kết luận đếm mù có giữ hay không.**

## 4. Bước 4 — Đếm mù người đếm 2: KHÔNG KIỂM ĐƯỢC

- Receiver không có trong danh sách người đếm nên không được chọn làm người đếm; việc đổi tài khoản sang receiver cũng không thực hiện vì đợt không có dòng đếm nào để đếm (kể cả storekeeper cũng không đếm được). NVL0561 = 3 cái chưa được nhập.

## 5–8. Nộp đợt / duyệt chênh lệch / tồn sau duyệt / khóa đợt: KHÔNG KIỂM ĐƯỢC

- Bước 5 (nộp đợt): không có số đếm nào để nộp; trên màn đếm không xuất hiện nút nộp/gửi khi 0 dòng.
- Bước 6 (duyệt chênh lệch, GM): không có chênh lệch vì không có số đếm; chưa đăng nhập tài khoản GM. Ghi nhận thêm: trên trang chi tiết đợt, tài khoản storekeeper thấy dòng "Bạn chưa được cấp quyền xem chênh lệch — chỉ người có quyền mới xem được biên bản." — với storekeeper thì đây là hành vi có vẻ đúng quyền (GM có `count.view_variance` theo Q270, chưa được kiểm tra vì không có đợt để duyệt).
- Bước 7 (tồn sau duyệt): không có duyệt chênh lệch nào xảy ra. Tồn cuối kiểm tra: NVL0388 = 0 kg và NVL0561 = 0 cái — trang Tồn kho hiện "0 tồn kho" khi tìm từng mã. Cả hai mặt hàng đều có trong Danh mục vật tư (đều Đang dùng), chỉ là không có dòng tồn nào ở TEST47.
- Bước 8 (khóa đợt): không có đợt nào tới được trạng thái duyệt/khóa.
- Trường hợp biên (a: đếm 0; b: đếm số âm; c: đếm trùng 2 lần): **KHÔNG KIỂM ĐƯỢC** — không có dòng đếm nào để nhập số liệu.

## 9. Hướng xử lý đã thực hiện (theo quyết định được chỉ định giữa bài)

- (1) Hủy đợt CNT-...-0003 với lý do nguyên văn **"Đợt kiểm thử V3 — đợt tháng không sinh dòng đếm (tồn kho bằng 0), hủy để thử đợt luân phiên"** — trạng thái sau hủy: ĐÃ HỦY. Khi mở đợt tháng đã hiện thông báo đóng băng nguyên văn: **"Kho đang bị đóng băng do đợt kiểm kê tháng này — không nhập/xuất được cho đến khi điều chỉnh xong."**; sau khi hủy, cảnh báo đóng băng không còn hiện trên màn đếm của đợt đã hủy (đợt đã hủy hiện 0/0 dòng, không còn ô tìm kiếm/tab).
- (2) Mở đợt mới loại Kiểm kê luân phiên trên Kho chính T047, chọn lại cả 8 người đếm: **CNT-TEST47-LE-2611-0004**, ngày 14/11/2026, trạng thái ĐANG MỞ.
- (3) Màn đếm mobile đợt 0004 cũng "Đã đếm 0/0 dòng", "Đợt này chưa có dòng đếm nào." — tìm NVL0388 cũng không ra dòng nào; **trên màn đếm đợt luân phiên này không thấy cảnh báo đóng băng kho (khác với đợt tháng)**. Vì vậy đã DỪNG theo chỉ định, không đổi tiếp sang tài khoản thu mua/GM.

## 10. Phát hiện mới

- **N-1. [Chặn — cần xác nhận thiết kế] Đợt kiểm kê sinh 0 dòng đếm khi tồn kho bằng 0 — cả Kiểm kê tháng và Kiểm kê luân phiên; không có cách thêm mặt hàng có tồn 0 vào đợt** (màn đếm chỉ tìm/lọc trong các dòng đã có; trang chi tiết desktop không có nút thêm dòng). Tái hiện: mở đợt mới (tháng hoặc luân phiên) trên Kho chính T047 khi tồn kho = 0 → màn đếm hiện "Đã đếm 0/0 dòng", "Đợt này chưa có dòng đếm nào.". Cần Duy/Claude xác nhận: đây có phải thiết kế (chỉ đếm mặt hàng có tồn) không, và nếu muốn kiểm kê cả mặt hàng tồn 0 thì làm sao? Chuyển Claude Code (P1 — xác nhận thiết kế; nếu cần thêm nút thêm dòng thì là P1 UI).
- **N-2. [Bất thường — cần làm rõ] Luật người đếm độc lập chặn mọi cặp 2 người đã thử, kể cả cặp có người ngoài kho (Chủ đầu tư, Dương Ngọc Duy); chỉ khi chọn cả 8 người liệt kê thì đợt mới mở được.** Thông báo nguyên văn: "Đợt kiểm kê cần ít nhất một người đếm độc lập, không phải người nhập hoặc xuất kho tại kho này." — không rõ tiêu chí "độc lập" và giao diện không chỉ rõ ai là người độc lập. Chuyển Claude Code (P1 — làm rõ luật + gợi ý trong form ai đủ điều kiện độc lập).
- **N-3. [Ghi nhận] Người nhận hàng (receiver) không có trong danh sách người đếm của Kho chính T047**, nên không thể chọn receiver làm người đếm thứ hai như kế hoạch ban đầu. Chuyển Duy xác nhận: receiver có nên được đếm không (hai người đếm độc lập lấy từ đâu nếu không có receiver?).
- **N-4. [Giao diện — nhỏ] Bấm vào một đợt trong danh sách mobile không chuyển trang** (phải mở trực tiếp bằng URL chi tiết đợt mới vào được màn đếm). Chuyển Claude Code (P2).
- **N-5. [Giao diện — nhỏ] Sau khi bấm "Mở đợt kiểm kê", trang chuyển sang chi tiết đợt chậm** (cần tải lại/quan sát thêm mới thấy đã chuyển). Ghi nhận.
- **N-6. [Ghi nhận] Đợt tháng làm kho bị đóng băng, đợt luân phiên không thấy cảnh báo đóng băng** (trên màn đếm). Cần xác minh: đợt luân phiên có đóng băng kho không, hay chỉ đợt tháng mới đóng băng? Ghi nhận để V4 đối chiếu (V4 cần nhập/xuất kho trong khi đợt 0004 đang mở).

## 11. Trạng thái cuối

- CNT-TEST47-LE-2611-0004 (Kiểm kê luân phiên, Kho chính T047, 14/11/2026) **ĐANG MỞ, 0 dòng đếm** — để lại đang mở (không thấy cảnh báo đóng băng trên màn đếm; V4 sẽ đối chiếu xem chứng từ kho có bị chặn không, nếu bị chặn thì hủy đợt này).
- CNT-TEST47-LE-2611-0003 (Kiểm kê tháng) **ĐÃ HỦY** (theo chỉ định giữa bài).
- CNT-...-0001/0002 (Kiểm kê xe đẩy, Xe đẩy 1 Demo, 13/11/2026) vẫn CHỜ DUYỆT, không bị chạm tới.
- Tồn kho cuối: NVL0388 = 0 kg, NVL0561 = 0 cái.
- Cần có tồn kho trước (nhận hàng) rồi mở lại đợt kiểm kê thì mới kiểm tiếp được các bước đếm mù, chênh lệch, duyệt, khóa đợt và trường hợp biên.

## 12. Kết quả xác minh các lỗi cũ trong V3

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q268 B-1 | Trang tạo đợt kiểm kê tải được (cả desktop + mobile) | **Đạt** |
| Q270 B-12 | GM xem được chênh lệch kiểm kê (`count.view_variance`) | **Không kiểm được** — không có chênh lệch nào để xem (cần tồn trước) |
| Đếm mù | Người đếm không thấy tồn lý thuyết | **Không kiểm được** — màn nhập số lượng chưa từng hiện ra (network cũng chưa kiểm được) |
| Khóa đợt | Đợt đã khóa không đếm thêm được | **Không kiểm được** — không có đợt nào tới trạng thái khóa |

## 13. Lệnh đã chạy

```text
Trình duyệt cloud: 1 tài khoản uat.* (storekeeper), 10:26–10:32 14/11/2026 (failed — 0 dòng đếm)
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
