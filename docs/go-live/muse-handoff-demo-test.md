# Giao việc cho Muse — test chu trình demo (13/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại để Claude Code tiếp quản.
> Đọc trước: `AGENTS.md`, `docs/go-live/demo-walkthrough.md` (kịch bản gốc), `docs/go-live/uat-guide.md`, `tests/e2e/README.md`.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện** (không có trong repo). Thiếu PIN của tài khoản nào → dừng bước đó, ghi lại, làm bước khác. **Không đoán PIN.**

## Mục tiêu

Chạy **thật qua giao diện** phần còn lại của chu trình mua → nhận hàng → thanh toán trên khách sạn **TEST47** (production, dữ liệu DEMO), để tạo tồn kho demo và tìm lỗi. Bước 1–5 đã chạy sẵn:
đơn mua **PO-TEST47-LE-2611-0003** (NCC `SUP0001`, NVL0388 10 kg × 100.000 đ = 1.000.000 đ) đang ở trạng thái **đã gửi**, chưa nhận hàng. Tồn KHO-T047 đang = 0.

## Luật (bắt buộc)

1. **Chỉ thao tác qua giao diện web** bằng tài khoản `uat.*` trên khách sạn **TEST47**. KHÔNG `supabase db push/query`, KHÔNG migration, KHÔNG `vercel`, KHÔNG gọi RPC/SQL trực tiếp, KHÔNG dùng service role key.
2. **KHÔNG đổi** cấu hình hệ thống: không sửa cờ `rule.*` ở `/admin/settings`, không sửa quy tắc duyệt, vai trò, module, tài khoản. Không tắt PIN, không tắt SoD để "cho qua". Gặp chặn → ghi lại như một kết quả, không lách.
3. **KHÔNG làm giả bằng chứng.** Ảnh nhận hàng: nếu chạy bằng trình duyệt tự động, dùng camera giả của Chromium (`--use-fake-device-for-media-stream --use-fake-ui-for-media-stream`) hoặc tải ảnh thử nếu màn có nhập file — đây là môi trường demo. Nếu hệ thống từ chối ảnh (trùng SHA-256, kích thước…) thì ghi đúng thông báo, **không** sửa app để qua.
4. Không in/ghi mật khẩu hoặc PIN vào file, commit, log hay ảnh chụp màn hình. Đừng đăng nhập khách sạn khác (SONHOIAN, v.v.) — nếu tài khoản `uat.*` thấy thêm khách sạn, dừng và báo.
5. Được sửa **code giao diện** nếu thấy lỗi rõ ràng (nhánh `feat/muse-demo-test` từ `main` mới nhất, `pnpm lint && pnpm typecheck && pnpm test` xanh, chuỗi vào `src/i18n/vi.ts`, không `any`). Lỗi thuộc DB/RPC/quyền → **không tự sửa**, ghi vào báo cáo để Claude Code xử lý. Không merge vào `main`, không push.
6. Kẹt > 30 phút ở một bước → ghi lý do, bỏ qua, làm bước kế.

## Phần A — Chu trình (làm đúng thứ tự)

Mỗi bước: ghi **Đạt / Không đạt**, thông báo hiển thị nguyên văn nếu lỗi, và chụp màn hình (che PIN).

| # | Tài khoản | Việc | Đường dẫn | Mong đợi |
|---|---|---|---|---|
| 6 | `uat.receiver` (điện thoại/khung hình di động) | Nhận hàng mù PO-TEST47-LE-2611-0003: nhập 10 kg (cân 2 lần), chụp/đính ảnh. Kiểm tra màn **không hiện** số lượng PO và đơn giá ở bất kỳ đâu | `/m/b0000000-0000-4000-8000-000000000002/receive` | Phiếu nhận nháp được ghi |
| 7 | `uat.storekeeper` | Mở phiếu nhận, kiểm dòng, **Đăng phiếu** (nhập PIN) | `/b0000000-0000-4000-8000-000000000002/receiving` | Phiếu `posted`; **tồn KHO-T047 = 10 kg NVL0388**, giá vốn 100.000 đ/kg (kiểm tại `/b0000000-0000-4000-8000-000000000002/inventory/stock`); phiếu không sửa được nữa |
| 8 | `uat.accountant` | Nhập hóa đơn NCC theo PO + phiếu nhận (đơn giá 100.000, 10 kg) | `/b0000000-0000-4000-8000-000000000002/finance/invoices/new` | Hóa đơn khớp PO/phiếu nhận (so khớp 3 bên) |
| 9 | `uat.gm` (Quản lý) | Duyệt hóa đơn | `/b0000000-0000-4000-8000-000000000002/finance/invoices` | Đã duyệt. Thử thêm: `uat.accountant` KHÔNG duyệt được hóa đơn của mình |
| 10 | `uat.accountant` | Tạo đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests/new` | Đề nghị chờ duyệt |
| 11 | `uat.owner` hoặc `uat.gm` | Duyệt đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` | Đã duyệt; người tạo không tự duyệt được |
| 12 | `uat.accountant` | Đánh dấu đã thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` | Công nợ NCC `SUP0001` về 0 (`/b0000000-0000-4000-8000-000000000002/finance/payables`) |

Kiểm tra cuối: thẻ kho NVL0388 có đúng 1 bút toán nhập; `uat.owner` mở trang tổng quan khối **"Sáng nay"** thấy số liệu; `/admin/audit` (tài khoản `dnduy@hueic.edu.vn` hoặc owner) có đủ dấu vết các bước, đúng người.

## Phần B — Thử các điểm mới (mỗi mục ghi Đạt/Không đạt)

1. **Phân quyền gọn:** `uat.gm` duyệt được PR/PO/phiếu lĩnh/phiếu hủy/hóa đơn/thanh toán; `uat.purchaser` không duyệt được gì; `uat.chef`/`uat.hk_supervisor` chỉ đề xuất (tạo PR/phiếu lĩnh), bấm duyệt thì bị từ chối đúng thông báo tiếng Việt.
2. **Một chu trình PR nữa → PO chợ:** `uat.purchaser` tạo **PO chợ** (`/b0000000-0000-4000-8000-000000000002/procurement/market/new`), dòng chưa giá, thử gửi duyệt khi **chưa** nhập tổng ước tính (phải bị chặn), rồi nhập và gửi.
3. **Bật/tắt module** (chỉ **xem**, không bấm tắt trên production nếu `dnduy@hueic.edu.vn` không cho phép): mở `/admin/modules` xác nhận hiện 2 khách sạn × 2 module; mở `/b0000000-0000-4000-8000-000000000002/restaurant` và `/m/b0000000-0000-4000-8000-000000000002/restaurant` thấy nội dung bình thường (module đang bật).
4. **Nhật ký thay đổi:** `/admin/audit` lọc theo bảng `purchase_orders`, mở "N cột", kiểm tra bộ lọc ngày và phân trang; dòng chỉ đổi `updated_at` hiện "Chỉ cập nhật thời điểm sửa".
5. **Buồng phòng + minibar (TEST47 đã có 30 phòng demo):** làm `uat-guide.md` §4.3 (lễ tân yêu cầu kiểm phòng 101 → nhân viên buồng kiểm trên điện thoại, thử cả lúc tắt mạng → lễ tân thu tiền).
6. **Giao diện di động:** các màn `/m/b0000000-0000-4000-8000-000000000002/*` không tràn ngang trên khung 390 px; nút bấm đủ lớn.

## Báo cáo

Tạo `docs/go-live/muse-report-demo-test.md`:
- Bảng từng bước (A6–A12, B1–B6): Đạt/Không đạt, thời gian, thông báo lỗi nguyên văn, đường dẫn ảnh chụp (không chứa PIN).
- Tồn kho cuối cùng của NVL0388 ở KHO-T047 và giá vốn đọc được trên màn hình.
- Danh sách lỗi: mô tả, bước tái hiện, mức độ (chặn / sai số liệu / giao diện), thuộc **UI / DB-RPC / quyền / dữ liệu**.
- Lệnh đã chạy và kết quả thật (lint/typecheck/test nếu có sửa code). Việc bỏ dở và vì sao.
Không bịa kết quả: bước nào không làm được ghi rõ "chưa làm" và lý do.

## Việc Claude Code làm sau đó (Muse đừng làm)

Xử lý lỗi DB/RPC/quyền Muse báo; Q172 (giá vốn hàng chợ giá 0); vô hiệu hóa 21 tài khoản test và đổi mật khẩu yếu (làm sau, theo Duy); dữ liệu thật khi Duy gửi.
