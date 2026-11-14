# Giao việc cho Muse — chạy lại C2, C3, C4, C5 sau bản sửa Q275–Q276 (14/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-cycle.md` (luật + mô tả task C1–C7, vẫn áp dụng), `docs/go-live/muse-report-cycle.md`, `CHANGELOG.md` Q275–Q276.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện** (không có trong repo). Không đoán PIN, không ghi PIN/mật khẩu vào file/commit/log/ảnh.

## Đã sửa (deploy xong) — xác minh từng điểm

- **C2-N1 (P0) cân lại lần 2:** sau lần cân 2 mà vẫn lệch ngoài dung sai, dòng nhận không còn bị coi là "cần cân lại"; nút ghi sổ phải bật được.
- **C5-N1:** ô "Kho nhận" ở `/m/<p>/receive` có **Kho minibar tổng** (MINIBAR_MAIN); PO-TEST47-LE-2611-0006 (7 món minibar, đã gửi) nhận được vào đó.
- **Người đếm độc lập (Q275):** form mở đợt kiểm kê hiện nhãn "Người đếm độc lập" + nhắc luật; nút mở đợt tháng chỉ bật khi chọn ≥ 1 người độc lập.
- **Tồn kho tìm không dấu** (`/inventory/stock`: "ba chi"), **nút "Làm mới số liệu thẻ kho"** (`/reports/stock-card`), **nút "Lập phiếu trả hàng NCC"** ở `/receiving/returns`, ẩn Duyệt/Từ chối với người lập phiếu, `/procurement/pr/new` thiếu quyền hiện thông báo, ngày trả dạng dd/mm/yyyy.
- TEST47 đã có kho trung chuyển; nhận hàng không camera dùng ô tích xác nhận + lý do (như đợt trước).

## Điều kiện để chạy C3/C4 (Duy chuẩn bị)

Duy đặt PIN cho 6 người đếm qua `/admin/users/<id>` → "Đặt lại PIN" (UAT Chủ đầu tư, Dương Ngọc Duy, test 01, UAT Bartender, UAT Bếp trưởng, UAT Thu mua) và dán danh sách PIN cho bạn trong cuộc trò chuyện. **Bạn không được tự đặt PIN hay sửa tài khoản.** Nếu chưa có đủ PIN: làm C2, C5 trước, báo C3/C4 "chưa làm" kèm lý do.

## Thứ tự

### R1. C2 — Chu trình chênh lệch (PO-TEST47-LE-2611-0005, NVL0561 200 cái)
Dọn: các phiếu nhận nháp 0007/0009/0010 đang kẹt — **không xóa**, mở GRN-…-0009 (đã ghi 180, chờ cân lại) và **cân lại lần 2** (nhập 180 lần nữa). Mong đợi: ghi được, phiếu không còn bị khóa. Rồi: người nhận ghi sổ (PIN) hoặc thủ kho/receiver theo mô hình vai trò (ghi rõ ai ghi sổ được); tồn NVL0561 = 180 (nếu app cho nhận 180 sau lệch); hóa đơn C25TAA/0000123 (200 × 5.000) đang **Tạm giữ** — ghi cách app xử lý chênh lệch; phiếu trả hàng NCC bằng nút mới ở `/receiving/returns` (hoặc mobile `/m/<p>/receive/returns/new`) cho phần hỏng/thiếu. Ghi rõ nếu vẫn không ghi được "5 hỏng" trên dòng nhận (C2-N3 chưa sửa — thiết kế chờ Duy).

### R2. C5 — Minibar thu tiền
`uat.receiver`/`uat.storekeeper`: mở nhiệm vụ nhận PO-…-0006, chọn **Kho minibar tổng**, nhận 7 món (không camera: dùng ô tích xác nhận + lý do), ghi sổ → tồn kho minibar tổng. Cấp bù cho phòng 101 bằng luồng minibar/điều chuyển có trên giao diện (ghi rõ nếu không có đường làm hết bằng giao diện). Rồi `uat.front_desk` thu tiền MB-…-0001 (140.000 đ, folio `TEST-M5-1311`): báo cáo Minibar 01–14/11 phải khớp Doanh thu/Đã thu = 140.000 đ, Chờ thu = 0 (B-3, B-8).

### R3. C3 — Nộp đợt kiểm kê (cần PIN 8 người)
Đợt CNT-…-0005 (KHO-T047, đã đếm NVL0388 = 9 kg, chưa nộp): nộp đợt với PIN từng người (mỗi người nhập PIN của chính mình), xem có yêu cầu đếm lần 2 không (ghi luồng đếm lần 2 — C3-N5) → `uat.gm` xem chênh lệch (đếm 9 / sổ 10 / lệch −1) → duyệt điều chỉnh → tồn NVL0388 về 9 kg bằng bút toán điều chỉnh → đợt khóa → thử đếm thêm trên đợt đã khóa (phải bị chặn). Ghi: CNT-…-0004 (đang mở, 0 dòng) có cần hủy để mở đóng băng không; app có chặn mở đợt thứ 2 cùng kho không (C3-N4).

### R4. C4 — Chứng từ kho trọn vòng (sau khi kho hết đóng băng)
- **Phiếu lĩnh** REQ-…-0002 (đã duyệt, NVL0388 2 kg): `uat.storekeeper` **Xuất kho** → bếp **Xác nhận nhận** (thử nhận thiếu có ghi chú lệch); tồn trước/sau.
- **Điều chuyển** TRF-…-0002 (Tiger ×1 KHO-T047 → Minibar 101): chuyển hàng → nhận.
- **Xuất mục đích** PIS-…-0001: bổ sung cost center + khoản mục → ghi sổ → đảo phiếu (có lý do).
- **Hủy hàng** WST-…-0001: hủy hàng vẫn bắt buộc ảnh — nếu không có camera ghi "không làm được"; xác nhận gửi duyệt 0 ảnh bị chặn bằng câu cụ thể.
Mọi thông báo lỗi phải là câu cụ thể, không còn "Dữ liệu không hợp lệ" chung chung.

### R5. Quét lại nhanh
Tìm "ba chi" ở `/inventory/stock`; nút "Làm mới số liệu thẻ kho" rồi thẻ kho NVL0388 có đủ bút toán; chef mở phiếu lĩnh CHỜ DUYỆT của chính mình không thấy nút Duyệt; GM mở `/procurement/pr/new` thấy thông báo thiếu quyền; chi tiết đề nghị thanh toán ngày trả dạng dd/mm/yyyy HH:mm.

## Luật & báo cáo (như `muse-handoff-cycle.md`)

Nhánh `feat/muse-rerun` từ `main` mới nhất (phải có commit Q276); chỉ giao diện, tài khoản `uat.*`, TEST47; không đổi cấu hình/tài khoản/PIN/khóa kỳ; không sửa DB/RPC (ghi vào "Chuyển Claude Code"); mỗi task một commit `T-Rxx:`; lint/typecheck/test xanh; báo cáo `docs/go-live/rerun/Rxx-*.md` + `docs/go-live/muse-report-rerun.md` (Đạt/Không đạt, lỗi mới, số liệu cuối: tồn từng kho, công nợ, trạng thái chứng từ). Không bịa kết quả.
