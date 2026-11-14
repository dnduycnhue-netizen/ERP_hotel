# C3 — Kiểm kê đếm mù (KHO-T047)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Tồn đầu: KHO-T047 NVL0388 = 10 kg (từ C1), NVL0561 = 0 cái (C2 kẹt).
- Kết quả: **Đạt một phần** — mở đợt, đếm mù, đóng băng kho đều đạt; **nộp đợt KHÔNG KIỂM ĐƯỢC** vì màn nộp yêu cầu mã PIN của cả 8 người đếm mà chỉ biết PIN của 2 người → bước 5 (GM duyệt chênh lệch) và bước 6 (tồn sau điều chỉnh, khóa đợt) cũng không kiểm được. Đợt CNT-...-0005 vẫn ĐANG ĐẾM (đã đếm 1/1 dòng = 9 kg).
- Nhánh `feat/muse-cycle`, commit `T-C3:` (ghi sau khi gate xanh).

## Từng bước

### Bước 0 — Kiểm tra đợt cũ: ĐẠT
- CNT-TEST47-LE-2611-0004 (luân phiên, KHO-T047, 14/11/2026): ĐANG MỞ, 8 người đếm, **0 dòng**.
- CNT-TEST47-LE-2611-0003 (tháng, 13/11/2026): ĐÃ HỦY.

### Bước 1 — Mở đợt kiểm kê mới (cả 2 đường): ĐẠT
- (a) Desktop `/inventory/counts/new`: kho KHO-T047, loại "Kiểm kê tháng", ngày 14/11/2026. **Không** bị chặn vì đã có đợt đang mở — app cho mở đợt mới dù CNT-...-0004 vẫn đang mở, nên không phải hủy CNT-...-0004 (đợt này vẫn ĐANG MỞ). Đợt mới: **CNT-TEST47-LE-2611-0005**, ĐANG MỞ, Kho chính T047, 14/11/2026, Kiểm kê tháng, 8 người đếm.
- (b) Mobile `/m/<uuid>/count/new` tải được — hiển thị form "Mở đợt kiểm kê" (Kho, Loại đợt, Ngày kiểm kê, Người đếm, nút "Mở đợt"); không mở thêm đợt ở đây.
- (c) Đợt mới sinh đúng **1 dòng đếm**: NVL0388 "ba chỉ nách" (ĐVT kg); NVL0561 **không có dòng** (phù hợp tồn 0).
- Lưu ý: trang chi tiết desktop của thủ kho không hiện dòng đếm nào và ghi "Bạn chưa được cấp quyền xem chênh lệch" — số dòng chỉ thấy được trên màn đếm mobile và bảng chênh lệch của GM.

### Bước 2 — Hai người đếm độc lập: ĐẠT (theo hướng dự phòng của bài)
- Gợi ý trên form: "Kiểm kê tháng cần ít nhất 2 người đếm độc lập (người nhận hàng/xuất kho của kho này không được đếm)."
- Cả 3 cặp đều bị chặn với cùng thông báo nguyên văn: **"Đợt kiểm kê cần ít nhất một người đếm độc lập, không phải người nhập hoặc xuất kho tại kho này."** — (1) Thủ kho + Thu mua; (2) Thủ kho + Chủ đầu tư; (3) Chủ đầu tư + Dương Ngọc Duy. Như vậy cả Thủ kho, Thu mua, Chủ đầu tư và Dương Ngọc Duy đều không được tính là độc lập.
- Chọn cả 8 người đếm thì mở được đợt. Tiêu chí "độc lập" vẫn chưa xác định được chính xác từng người: chỉ biết trong 8 người có ít nhất một người độc lập, nhiều khả năng thuộc nhóm test 01, Test Storekeeper (TEST03), UAT Bartender hoặc UAT Bếp trưởng — nhưng chưa biết là ai.
- Người đếm: 8 người (Dương Ngọc Duy; test 01; Test Storekeeper/TEST03; UAT Bartender; UAT Bếp trưởng; UAT Chủ đầu tư; UAT Thủ kho; UAT Thu mua). uat.receiver **không** có trong danh sách.

### Bước 3 — Đếm mù: ĐẠT (phần đếm); Nộp đợt: KHÔNG KIỂM ĐƯỢC
- Màn đếm mobile của đợt 0005 (đăng nhập thủ kho) **không hiện** "số sổ"/tồn lý thuyết của NVL0388 — đúng đếm mù. Các trường hiện trên màn đếm: mã + tên mặt hàng (NVL0388 — ba chỉ nách), "ĐVT lưu kho: kg", ô nhập số đếm, ô chọn ĐVT (kg), "Thêm dòng", "Tổng quy ra kg", bàn phím số, nút "Xóa hết" và "Lưu số đếm".
- Đã nhập và lưu **NVL0388 = 9 kg**: màn hình hiện "Đã đếm 1/1 dòng", "Đã đếm: 9 kg", trạng thái đợt chuyển ĐANG MỞ → ĐANG ĐẾM (mobile). App **không** yêu cầu lượt đếm thứ hai ngay sau khi lưu và không yêu cầu đăng nhập người đếm thứ hai để nhập lại.
- Bấm "Nộp đợt" mở hộp thoại yêu cầu nhập mã PIN của cả 8 người đếm ("Mỗi người đếm nhập mã PIN của mình. Thứ tự nhập không quan trọng."); nút "Nộp đợt" chỉ bật khi đủ 8 ô — nhập 1 ô hay 2 ô đều vẫn tắt. Khi nhập mã PIN thủ kho vào cả 8 ô, máy chủ báo nguyên văn: **"Mã PIN không đúng. Vui lòng thử lại."**
- Chỉ biết mã PIN của 2/8 người đếm (UAT Thủ kho và Test Storekeeper); 6 người còn lại (UAT Chủ đầu tư, Dương Ngọc Duy, test 01, UAT Bartender, UAT Bếp trưởng, UAT Thu mua) chưa từng được đặt mã PIN, nhiều khả năng chưa có mã PIN, và không được đoán thêm. Vì vậy đợt 0005 vẫn ở trạng thái **ĐANG ĐẾM, chưa nộp được**.

### Bước 4 — Thử đóng băng kho: ĐẠT
- Đợt vẫn đang mở, đăng nhập thủ kho, mở phiếu lĩnh REQ-TEST47-LE-2611-0002 (ĐÃ DUYỆT, 2026-11-14, Bếp, Kho chính T047 → Kho bếp, ba chỉ nách 2 kg, ĐÃ XUẤT 0, ĐÃ NHẬN 0), bấm "Xuất kho" rồi "Xác nhận" (SL thực tế 2).
- Xuất kho **bị chặn**, thông báo nguyên văn: **"Kho đang kiểm kê nên tạm dừng ghi nhận xuất nhập ở kho này."** Không có mã lỗi dạng `ERR_COUNT_FREEZE` hiển thị.
- Sau khi chặn, phiếu vẫn ĐÃ DUYỆT, ĐÃ XUẤT vẫn 0 — phiếu chưa xuất, nên bài C4 vẫn cần thực hiện bước xuất kho và bếp xác nhận nhận sau khi đợt kiểm kê hoàn tất.

### Bước 5 — GM xem chênh lệch + duyệt điều chỉnh: KHÔNG KIỂM ĐƯỢC
- Đăng nhập GM mở chi tiết đợt 0005: trạng thái ĐANG ĐẾM. Bảng chênh lệch hiện đủ các cột: MÃ HÀNG, TÊN HÀNG, ĐVT, ĐẾM LẦN 1, ĐẾM LẦN 2, SỐ ĐẾM, SỐ SỔ, CHÊNH LỆCH, % LỆCH, TRẠNG THÁI DÒNG, MÃ LÝ DO, GIẢI THÍCH.
- Dòng NVL0388: ĐẾM LẦN 1 = 9, ĐẾM LẦN 2 = —, SỐ ĐẾM = —, SỐ SỔ = 10, CHÊNH LỆCH = —, % LỆCH = — (các cột còn lại đều —).
- **Không có nút "Duyệt"/"Phê duyệt điều chỉnh"** nào trên trang (chỉ có nút "Xuất Excel") vì đợt chưa nộp, SỐ ĐẾM chưa chốt nên GM chưa duyệt điều chỉnh được. Tồn NVL0388 theo SỐ SỔ vẫn là 10 kg — chưa có điều chỉnh nào.

### Bước 6 — Tồn sau điều chỉnh + đợt đã khóa: KHÔNG KIỂM ĐƯỢC
- Vì đợt chưa nộp/khóa và chưa có phê duyệt điều chỉnh nên (a) không kiểm được tồn sau điều chỉnh (dự kiến 9 kg) hay bút toán điều chỉnh −1; (b) không kiểm được việc đếm thêm trên đợt đã khóa vì đợt chưa khóa.

## Số liệu trước–sau

| Chỉ số | Trước | Sau |
|---|---|---|
| Tồn KHO-T047 NVL0388 | 10 kg | 10 kg (chưa điều chỉnh — đợt chưa nộp) |
| Đợt CNT-...-0005 | — | ĐANG ĐẾM, 1/1 dòng, đếm 9 kg |
| Đợt CNT-...-0004 | ĐANG MỞ, 0 dòng | ĐANG MỞ, 0 dòng (không chạm) |
| REQ-...-0002 | ĐÃ DUYỆT, Đã xuất 0 | ĐÃ DUYỆT, Đã xuất 0 (xuất kho bị chặn do đóng băng) |

## Lỗi / bất thường mới

1. **C3-N1 [Chặn — P1, thiết kế/quyền]** — Nộp đợt yêu cầu mã PIN của cả 8 người đếm dù chỉ 1 người thực hiện đếm; 6/8 người đếm chưa có mã PIN nên đợt không thể nộp khi buộc chọn cả 8 người vì luật độc lập — đây là điểm tắc của bài C3. Cần người có quyền quản trị đặt mã PIN cho 6 người đếm còn lại (hoặc điều chỉnh luật nộp) thì mới nộp được đợt. **Cần Duy quyết: dán PIN 6 người, hoặc cho tau đặt PIN qua màn quản trị, hoặc hủy đợt 0005 để mở đường cho C4.**
2. **C3-N2 [Giao diện — P2]** — Trạng thái đợt không nhất quán giữa desktop và mobile: sau khi lưu số đếm, desktop vẫn hiện ĐANG MỞ, mobile hiện ĐANG ĐẾM.
3. **C3-N3 [Ghi chú]** — Trang chi tiết desktop của thủ kho không hiện dòng đếm và chặn xem chênh lệch ("Bạn chưa được cấp quyền xem chênh lệch"), trong khi GM thấy đủ bảng chênh lệch (đúng phân quyền — thủ kho không có `count.view_variance`).
4. **C3-N4 [Thiết kế — P2]** — App không chặn mở đợt mới khi đã có đợt đang mở cùng kho (CNT-...-0004 vẫn mở, CNT-...-0005 vẫn mở được) — khác với giả định trong bài. Cần Claude Code xác nhận có phải thiết kế không (2 đợt cùng kho cùng mở có gây xung đột đóng băng không).
5. **C3-N5 [Giao diện — P2]** — Bảng chênh lệch của GM có 2 cột ĐẾM LẦN 1 / ĐẾM LẦN 2: sau lần đếm 1 = 9 thì SỐ ĐẾM vẫn trống, cho thấy quy trình có thể còn cần một lần đếm thứ 2 trước khi chốt số, nhưng màn đếm mobile không hề yêu cầu lần đếm thứ 2 — cần Claude Code làm rõ quy trình đếm 2 lần (ai đếm lần 2, khi nào).

## Để tiếp tục
Cần cung cấp/đặt mã PIN cho 6 người đếm còn lại, sau đó nộp đợt 0005, GM xem chênh lệch (kỳ vọng đếm 9, sổ 10, lệch −1) và duyệt điều chỉnh, rồi mới kiểm được bước 6 (tồn NVL0388 10 → 9 kg, bút toán điều chỉnh −1, đợt đã khóa không đếm thêm được). Đợt 0005 hiện ĐANG ĐẾM, đã đếm 1/1 dòng = 9 kg; đợt 0004 vẫn ĐANG MỞ; phiếu REQ-...-0002 vẫn ĐÃ DUYỆT, chưa xuất.
