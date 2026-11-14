# Giao việc cho Muse — chạy lại R2, R3, R4 + phần còn lại R1 (14/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-rerun.md` (R1–R5 gốc), `docs/go-live/muse-report-rerun.md`, `docs/go-live/muse-handoff-cycle.md` (luật), `CHANGELOG.md` Q277–Q278.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện**. Không ghi PIN/mật khẩu vào file, commit, log, ảnh chụp.

## Đã sửa/chuẩn bị (deploy xong) — xác minh từng điểm

- **Q278 — xác nhận không camera ở MỌI dòng và lúc ghi sổ:** màn nhận hàng mobile có ô tích "Thiết bị không có camera…" + lý do ở mọi dòng chưa có ảnh; và **ô tích ngay trên nút "Ghi sổ"** ("Phiếu này không có ảnh vì thiết bị không có camera…") + lý do — dùng để gỡ phiếu đã ghi sẵn dòng như **GRN-…-0011**. Lý do trống vẫn bị chặn.
- **Q278 — hộp thoại PIN/xác nhận ghi sổ** không còn bị thanh điều hướng/thanh hành động che; bấm chuột được.
- **Q277 — hàng hỏng một phần:** dòng nhận có ô "Số lượng hỏng (nếu có)" + lý do (số hỏng > 0 và < số thực nhận). Phần tốt nhập kho; phần hỏng thành phiếu trả hàng NCC "đã ghi nhận" (không move kho).
- **Q275 — người đếm độc lập:** form mở đợt kiểm kê tháng hiện nhãn "Người đếm độc lập".
- **PIN:** Duy đã đặt PIN cho 6 người đếm (UAT Chủ đầu tư, Dương Ngọc Duy, test 01, UAT Bartender, UAT Bếp trưởng, UAT Thu mua); Duy sẽ dán danh sách PIN cho bạn. **Bạn không được tự đặt/đổi PIN hay sửa tài khoản.**

## Luật (như các đợt trước)

Chỉ giao diện web, tài khoản `uat.*`/TEST, khách sạn TEST47 (`b0000000-0000-4000-8000-000000000002`); không supabase/migration/vercel/RPC/SQL trực tiếp; không đổi cấu hình/tài khoản/PIN/khóa kỳ; không bịa kết quả; lỗi DB/RPC/quyền ghi vào "Chuyển Claude Code"; nhánh `feat/muse-rerun2` từ `main` mới nhất (phải có commit Q278 `05635f1`), mỗi task một commit `T-R2x:`, lint/typecheck/test xanh, được push nhánh; báo cáo `docs/go-live/rerun2/*.md` + `docs/go-live/muse-report-rerun2.md`.

## Thứ tự (quan trọng: R3 trước vì kho KHO-T047 đang đóng băng)

### X1. R3 — Nộp đợt kiểm kê CNT-…-0005 (KHO-T047, đã đếm NVL0388 = 9 kg)
1. Đợt đang đếm xong 1/1 dòng, chưa nộp. Nộp đợt: mỗi người đếm nhập **PIN của chính mình** (Duy cấp). Ghi: có yêu cầu đếm lần 2 không (luồng đếm lần 2 — C3-N5); thông báo nguyên văn mỗi bước.
2. `uat.gm` xem chênh lệch (đếm 9 / sổ 10 / lệch −1) → duyệt điều chỉnh → tồn NVL0388 về **9 kg** bằng bút toán điều chỉnh (kiểm thẻ kho — dùng nút "Làm mới số liệu thẻ kho" ở `/reports/stock-card`).
3. Đợt khóa → thử đếm thêm trên đợt đã khóa (phải bị chặn, ghi thông báo).
4. Đợt **CNT-…-0004** (đang mở, 0 dòng) cùng kho: ghi cách hủy/đóng; ghi app có chặn mở đợt thứ 2 cùng kho không (C3-N4). Sau X1 kho KHO-T047 **phải hết đóng băng** — thử xuất kho để xác nhận.
5. Form mở đợt: nhãn "Người đếm độc lập" có hiện đúng không.

### X2. R1 phần còn lại — ghi sổ GRN-…-0009 + chu trình chênh lệch (PO-TEST47-LE-2611-0005, NVL0561 200 cái)
Sau khi hết đóng băng: GRN-…-0009 (đã ghi 180, cân lại lần 2 xong) → ghi sổ bằng receiver/PIN. Tồn NVL0561 = 180. Rồi **thử hàng hỏng một phần** ở phiếu/PO phù hợp (ví dụ phiếu mới hoặc dòng khác): nhận N, hỏng M → phần tốt nhập kho, phiếu trả NCC `recorded` M (kiểm ở `/receiving/returns`). Hóa đơn C25TAA/0000123 (200 × 5.000, đang Tạm giữ): ghi cách app xử lý lệch với số đã nhận; lập phiếu trả bằng nút "Lập phiếu trả hàng NCC" (desktop → mobile).

### X3. R2 — Minibar thu tiền (PO-TEST47-LE-2611-0006, 7 món minibar, kho nhận = Kho minibar tổng)
1. GRN-…-0011 (7/7 dòng, 0 ảnh, kẹt): ghi sổ bằng **ô tích "không có ảnh" ngay trên nút Ghi sổ** + lý do. Nếu app không cho: ghi chính xác bước/thông báo.
2. Kiểm kho nhận đúng là MINIBAR_MAIN (GRN-…-0012 trước đây hiển thị kho không chắc — xác minh bằng chi tiết phiếu/tồn).
3. Tồn kho minibar tổng có 7 món → cấp bù phòng 101 (màn minibar "bổ sung"/điều chuyển có trên giao diện; ghi rõ nếu không chọn được phòng riêng — R2-N2).
4. `uat.front_desk` thu tiền MB-…-0001 (140.000 đ, folio `TEST-M5-1311`): mong đợi thành công. Báo cáo Minibar 01–14/11 khớp: Doanh thu/Đã thu 140.000 đ, Chờ thu = 0 (B-3, B-8).

### X4. R4 — Chứng từ kho trọn vòng (sau khi hết đóng băng)
- **Phiếu lĩnh** REQ-…-0002 (đã duyệt, NVL0388 2 kg, KHO-T047 → KHO_BEP): `uat.storekeeper` **Xuất kho** → bếp **Xác nhận nhận** (thử nhận thiếu có ghi chú lệch); tồn kho nguồn/bếp trước–sau.
- **Điều chuyển** TRF-…-0002 (Tiger ×1 KHO-T047 → Minibar 101): chuyển hàng → nhận. (Cần tồn Tiger ở KHO-T047; nếu 0 ghi rõ và dùng mặt hàng đang có tồn.)
- **Xuất mục đích** PIS-…-0001: bổ sung cost center + khoản mục (bắt buộc) → ghi sổ → đảo phiếu (lý do).
- **Hủy hàng** WST-…-0001: hủy hàng vẫn bắt buộc ảnh; không camera thì ghi "không làm được ảnh"; xác nhận gửi duyệt 0 ảnh bị chặn bằng câu cụ thể.
Mọi lỗi phải là câu cụ thể (không còn "Dữ liệu không hợp lệ" chung chung).

## Báo cáo cuối

Bảng X1–X4 Đạt/Không đạt/Không kiểm được + lý do + commit; lỗi mới (mức độ, lớp UI/DB-RPC/quyền/dữ liệu); **Chuyển Claude Code**; **Cần Duy quyết**; số liệu cuối (tồn từng kho/mặt hàng, giá vốn, công nợ, trạng thái chứng từ); lệnh đã chạy + kết quả thật; việc bỏ dở và vì sao.
