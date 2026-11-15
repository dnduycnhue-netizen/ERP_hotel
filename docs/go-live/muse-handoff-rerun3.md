# Giao việc cho Muse — chạy lại X1–X4 sau khi gỡ bế tắc khóa kiểm kê (15/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-rerun2.md` (X1–X4 gốc, vẫn là đặc tả chi tiết), `docs/go-live/muse-report-help.md`, `CHANGELOG.md` Q282–Q284.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện**. Không ghi PIN/mật khẩu vào file, commit, log, ảnh chụp.

## Đã sửa (deploy + migration xong) — xác minh từng điểm

- **Q282 — bế tắc khóa đợt kiểm kê (X1-N1):** Kế toán (`uat.accountant`) và GM nay có quyền xem chênh lệch → Kế toán thấy dòng đỏ, nhập lý do, **khóa đợt**; Quản lý/GM **duyệt điều chỉnh** sau khi khóa. Thứ tự thật: nộp → **khóa (Kế toán)** → **duyệt điều chỉnh (Quản lý/GM)**.
- **Q282 — "Chờ tôi duyệt":** chỉ hiện đơn khi bước **hiện tại** thuộc quyền người xem (Chủ đầu tư không còn thấy đơn đang ở bước Quản lý).
- **Q282 — form mở đợt:** nhãn "Trung tâm chi phí" (xuất mục đích); kho mặc định là kho chính (không phải kho chờ hủy); câu hướng dẫn người đếm đã thống nhất.
- **Q283 — vai trò `owner` cũ thu hẹp 129 → 63 quyền:** `uat.owner` không còn làm được thao tác nghiệp vụ của vai khác (nhận hàng, ghi sổ, lập hóa đơn...). **Không dùng owner để làm việc của vai khác** — dùng đúng tài khoản `uat.*`. Hãy ghi lại nếu có màn nào của chủ đầu tư bị mất nội dung cần thiết.
- **Q284 — Hủy hóa đơn chưa duyệt:** hóa đơn Tạm giữ/Nháp/Đã khớp có nút **Hủy hóa đơn** + ô lý do (người có quyền quản lý hóa đơn) → nhập hóa đơn thay thế. Hóa đơn đã duyệt không hủy được.
- **Q284 — Phiếu trả hàng NCC:** GM xem được (chỉ đọc). Người nhận hàng vẫn **không** xem (cố ý, vai trò mù).
- **Q284 — 10 bài hướng dẫn mới** (SOP-09..15, quy tắc mất mạng/foodcost/hợp đồng khung).

## Luật (như các đợt trước)

Chỉ giao diện web, tài khoản `uat.*`/TEST, khách sạn TEST47 (`b0000000-0000-4000-8000-000000000002`); không supabase/migration/vercel/RPC/SQL trực tiếp; không đổi cấu hình/tài khoản/PIN/khóa kỳ; không bịa kết quả; lỗi DB/RPC/quyền ghi vào "Chuyển Claude Code"; nhánh `feat/muse-rerun3` từ `main` mới nhất; mỗi task một commit `T-Xnn:`; `pnpm lint && pnpm typecheck && pnpm test` xanh nếu sửa code nhỏ; không merge/push `main`.

## Thứ tự

### X1. Hoàn tất kiểm kê CNT-…-0005 (KHO-T047) — **làm trước**
1. Nộp đợt (mỗi người đếm nhập **PIN của chính mình**). Ghi thông báo nguyên văn; có đếm lần 2 không.
2. `uat.accountant` mở đợt đã nộp: **thấy dòng đỏ** (chênh lệch −1 NVL0388) → chọn lý do → **Khóa đợt**. Ghi chính xác nếu vẫn không thấy/không khóa được.
3. `uat.gm` (hoặc `uat.manager`) **Duyệt điều chỉnh** → tồn NVL0388 về 9 kg; kiểm thẻ kho (nút "Làm mới số liệu thẻ kho").
4. Đợt đã khóa: thử đếm thêm (phải bị chặn). Đợt CNT-…-0004 (0 dòng): cách hủy/đóng; app có chặn mở 2 đợt cùng kho không. Sau đó KHO-T047 **hết đóng băng** — thử xuất kho.
5. Người đếm **không** thấy chênh lệch (đếm mù) — xác nhận bằng tài khoản người đếm.
6. Hộp **Chờ tôi duyệt** của `uat.owner`: không còn đơn đang ở bước Quản lý.

### X2. Nhận hàng + hỏng một phần (như X2 gốc trong rerun2)
GRN-…-0009 ghi sổ; thử hàng hỏng một phần; hóa đơn C25TAA/0000123 đang Tạm giữ: thử nút **Hủy hóa đơn** (có lý do) rồi **Nhập hóa đơn mới** thay thế khớp 3 chiều. Ghi kết quả từng bước.

### X3. Minibar thu tiền (như X3 gốc)
GRN-…-0011 ghi sổ bằng ô tích không ảnh; kho nhận = MINIBAR_MAIN; **Bổ sung theo tầng** cho phòng; `uat.front_desk` thu MB-…-0001; báo cáo Minibar khớp.

### X4. Chứng từ kho trọn vòng (như X4 gốc)
Phiếu lĩnh → xuất → xác nhận nhận; điều chuyển; xuất mục đích (**Trung tâm chi phí** + khoản mục) → ghi sổ → đảo; hủy hàng (ảnh bắt buộc).

### X5. Hướng dẫn mới (đọc/đối chiếu, ngắn)
Mở 10 bài mới (Hướng dẫn → lọc SOP/Quy tắc): SOP-09 Ủy quyền, SOP-10 mật khẩu/PIN, SOP-11 file POS, SOP-12 NCC/đổi STK, SOP-13 cấp bù minibar, SOP-14 Excel, SOP-15 bảng kê; quy tắc mất mạng, foodcost, hợp đồng khung. Đối chiếu tên nút/đường dẫn với màn thật; sửa bài (commit riêng) nếu chắc, nếu không ghi "Cần xác nhận". Kiểm "Dành cho bạn" của `uat.owner` sau khi thu hẹp quyền (còn bao nhiêu bài, có hợp lý không).

## Báo cáo cuối

Bảng X1–X5 Đạt/Không đạt/Không kiểm được + lý do + commit; lỗi mới (mức độ, lớp UI/DB-RPC/quyền/dữ liệu); **Chuyển Claude Code**; **Cần Duy quyết**; số liệu cuối (tồn từng kho/mặt hàng, công nợ, trạng thái chứng từ); lệnh đã chạy + kết quả thật; việc bỏ dở và vì sao. Báo cáo: `docs/go-live/muse-report-rerun3.md`.
