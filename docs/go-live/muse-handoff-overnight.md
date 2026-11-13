# Giao việc cho Muse — ca đêm (14/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Muse làm **tuần tự, một mình, xuyên đêm**. Sáng ra Claude Code review từng nhánh/commit và làm tiếp.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-demo-test.md` (luật cũ vẫn áp dụng), `docs/go-live/muse-report-demo-test.md` (kết quả lần trước), `docs/go-live/demo-walkthrough.md`, `docs/go-live/uat-guide.md`, `tests/e2e/README.md`.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện** (không có trong repo). Thiếu PIN → dừng task cần PIN, ghi lại, chuyển task kế. **Không đoán PIN.**

## Luật (bắt buộc — như lần trước, thêm vài điểm)

1. Thao tác dữ liệu **chỉ qua giao diện web**, tài khoản `uat.*`, khách sạn **TEST47** (`b0000000-0000-4000-8000-000000000002`, URL dùng UUID). KHÔNG `supabase db push/query`, KHÔNG migration, KHÔNG `vercel`, KHÔNG gọi RPC/SQL trực tiếp, KHÔNG service role key.
2. KHÔNG đổi cấu hình hệ thống (cờ `rule.*`, quy tắc duyệt, vai trò, module, tài khoản). Không tắt PIN/SoD. Gặp chặn → ghi như một kết quả.
3. KHÔNG làm giả bằng chứng. Không in/ghi mật khẩu/PIN vào file, commit, log, ảnh chụp. Không đăng nhập khách sạn khác.
4. Được sửa **code giao diện + test + docs**. Lỗi thuộc DB/RPC/quyền/dữ liệu → **không tự sửa**, ghi vào báo cáo (mục "Chuyển Claude Code").
5. Git: nhánh `feat/muse-overnight` từ `main` mới nhất. **Mỗi task một commit** (hoặc nhiều) với tiền tố `T-Mxx:`; sau mỗi task chạy `pnpm lint && pnpm typecheck && pnpm test` — đỏ thì sửa hoặc revert task đó rồi ghi lý do. **Không merge `main`, không push `main`, không `--force`.** Được push chính nhánh `feat/muse-overnight` nếu Duy đã cho phép; nếu không thì để commit local.
6. Chuỗi hiển thị vào `src/i18n/vi.ts`; không `any`; không tắt ESLint rule; không thêm thư viện mới (cần ADR → bỏ qua, ghi lại).
7. Không đụng: `supabase/migrations/`, `supabase/seed.sql`, `src/lib/database.types.ts`, `docs/sample-data/*.sql`.
8. Kẹt > 30 phút một task → ghi lý do, bỏ qua, làm task kế. Thứ tự ưu tiên: M1 → M2 → … ; làm được tới đâu báo tới đó.
9. **Không bịa kết quả.** Mỗi task có file báo cáo riêng ở `docs/go-live/overnight/Mxx-<tên>.md` (Đạt/Không đạt, lệnh đã chạy, kết quả thật, ảnh chụp không chứa PIN) + một file tổng `docs/go-live/muse-report-overnight.md` (bảng trạng thái, danh sách lỗi, việc bỏ dở).

## Nhóm 1 — Chạy lại chu trình thật (cần PIN, làm nếu Duy đã dán PIN)

### M1. Chu trình mua → nhận → thanh toán (bước 6–12)
Làm đúng bảng ở `demo-walkthrough.md` mục 1, bắt đầu từ bước 6 trên PO-TEST47-LE-2611-0003. Lần này kế toán đã mở được form hóa đơn, PO chợ lưu nháp được, minibar có giá (Q267) — **xác minh từng điểm này** và ghi Đạt/Không đạt. Ảnh nhận hàng: camera giả Chromium. Kiểm tra cuối: tồn KHO-T047 NVL0388 = 10 kg, thẻ kho 1 bút toán nhập, công nợ SUP0001 = 0, khối "Sáng nay" có số liệu, `/admin/audit` đủ dấu vết.

### M2. Chu trình thứ hai có sai lệch (kiểm chống gian lận)
Tạo PO mới (NVL0561 bánh bèo, 200 cái). Nhận hàng **thiếu** (180 cái) và một dòng **hàng lỗi** (5 cái) → kiểm: phiếu có chênh lệch, cảnh báo/biên bản, trả hàng NCC (`supplier_returns`), hóa đơn so khớp 3 bên **báo lệch** khi nhập đủ 200. Thử các chặn SoD: người nhận không đăng phiếu của mình, kế toán không duyệt hóa đơn của mình, người tạo đề nghị thanh toán không duyệt, người tạo PR không duyệt. Mỗi chặn ghi thông báo tiếng Việt nguyên văn; thông báo lộ mã lỗi thô (`ERR_...`) = lỗi giao diện.

### M3. Kiểm kê (đếm mù) + chênh lệch
Dùng tồn vừa tạo: `uat.storekeeper`/người kiểm kê tạo phiên kiểm kê KHO-T047, người đếm **không thấy tồn lý thuyết** ở bất kỳ đâu (mobile + DevTools network tab, xem payload không chứa số tồn). Đếm lệch 1–2 mặt hàng → duyệt chênh lệch → kiểm tồn sau điều chỉnh bằng bút toán, không sửa trực tiếp. Phiên kiểm kê đã khóa không đếm thêm được.

## Nhóm 2 — Thử nghiệm khám phá (exploratory) theo module

Mỗi module: đi **mọi menu/màn** mà vai trò có quyền, thử luồng chính + 3 điều kiện biên (rỗng, giá trị lớn/âm/0, tiếng Việt có dấu & ký tự đặc biệt), ghi lỗi.

### M4. Nhà hàng (POS, bếp, công thức, hủy món, ca)
Tài khoản `uat.chef`, `uat.front_desk`, `uat.gm`. Mở ca → bán món có công thức → trừ kho theo công thức → hủy/hoàn món → đóng ca → đối chiếu doanh thu/tồn. Kiểm tra món thiếu công thức, hết hàng, in/phiếu bếp.

### M5. Buồng phòng & minibar (làm đầy đủ `uat-guide.md` §4.3 + §4.4)
Yêu cầu kiểm phòng → kiểm minibar trên điện thoại (online + tắt mạng rồi bật lại, hàng đợi Dexie đồng bộ không nhân đôi) → lễ tân thu tiền → xe đẩy (par level, bổ sung). Kiểm giá minibar hiện đúng, tổng tiền đúng.

### M6. Tồn kho: chuyển kho, lĩnh kho, hủy hàng, điều chỉnh
Phiếu lĩnh (bếp tạo → Quản lý duyệt → thủ kho xuất), chuyển kho giữa 2 kho TEST47 (nếu chỉ có 1 kho thì ghi "không làm được"), phiếu hủy hàng có lý do + ảnh. Đối chiếu tồn trước/sau, giá vốn bình quân.

### M7. Báo cáo + xuất Excel
Mở **mọi** báo cáo ở `/reports` và `/alerts`: có 4 trạng thái (đang tải/rỗng/lỗi/dữ liệu)? Bộ lọc ngày theo giờ VN? Xuất Excel mở được, đúng cột, đúng dấu tiếng Việt, số tiền không bị thành chữ/khoa học. Báo cáo của module đang tắt không hiện.

### M8. Danh mục & import
Thử import file mẫu (`docs/samples/*.xlsx`, `docs/data-test/*`) vào màn import: file đúng, file sai cột, file trống, file có dòng trùng mã, file ký tự lạ. Ghi cách app báo lỗi (có chỉ rõ dòng/cột không? thông báo tiếng Việt?). **Chỉ import trên TEST47/danh mục thử; dừng nếu import sẽ ghi vào dữ liệu SONHOIAN.**

## Nhóm 3 — Kiểm thử phân quyền qua giao diện

### M9. Ma trận quyền theo 7 vai trò
Với mỗi tài khoản `uat.*` (owner, gm, accountant, purchaser, chef, hk_supervisor, front_desk, receiver, storekeeper): liệt kê menu hiển thị, thử gõ **URL trực tiếp** của ~15 màn không thuộc quyền (kể cả `/m/.../*`). Mong đợi: chuyển hướng/ thông báo "không có quyền" tiếng Việt, **không** lỗi 500, không lộ dữ liệu. Lập bảng vai trò × màn (Thấy menu / Mở được URL / Thấy dữ liệu). Đặc biệt soi **nhận hàng mù**: receiver có thấy số lượng PO/đơn giá ở bất kỳ route/payload nào không (đây là lỗi nghiêm trọng).

### M10. Chặn module tắt (chỉ đọc)
Xác minh bằng đọc code + gọi URL: danh sách route của restaurant/frontdesk/housekeeping/minibar/trolley đều có guard khi tắt module (`src/lib/modules`, các `layout.tsx`). Không bấm tắt module trên production; chỉ liệt kê route chưa được guard (nếu có).

## Nhóm 4 — Viết test tự động (code, an toàn nhất)

### M11. Playwright e2e chu trình chính
Bổ sung vào `tests/e2e/` (theo cấu trúc `readonly/` `write/` `mobile/` hiện có, đọc `tests/e2e/README.md`): spec đọc-chỉ (readonly) cho các màn chính của từng vai trò (tải được, không lỗi console, có tiêu đề tiếng Việt), spec `mobile/` cho 390 px không tràn ngang. Spec ghi dữ liệu (write) viết nhưng **đánh dấu skip theo biến môi trường** để không tự chạy trên production. Chạy spec readonly với `pnpm e2e` nếu cấu hình sẵn; ghi kết quả thật.

### M12. Vitest cho schema Zod & hàm tiện ích còn thiếu
Quét `src/features/*/schema*.ts`, `src/lib/**` tìm file chưa có test (so với `tests/unit/`). Viết test cho: schema form (hợp lệ/sai/biên), hàm định dạng tiền/số lượng/ngày VN, mapping mã lỗi → câu tiếng Việt (mọi mã `ERR_*` trong `docs/09-API-RPC.md` đều phải có câu — thiếu mã nào thì **liệt kê** và thêm câu vào `vi.ts`). Mục tiêu: thêm ≥ 30 test có ý nghĩa, không test rỗng/snapshot vô nghĩa.

## Nhóm 5 — Rà soát code & giao diện (không đổi hành vi nghiệp vụ)

### M13. Rà chuỗi cứng tiếng Việt & i18n
Tìm chuỗi tiếng Việt/Anh hiển thị cứng ngoài `src/i18n/vi.ts` (thông báo toast, `aria-label`, `placeholder`, `title`, `alert`, `confirm`). ESLint đã chặn một phần — tìm phần lọt. Chuyển vào `vi.ts`, cập nhật chỗ dùng, test xanh. Kiểm tra dấu tiếng Việt sai/thiếu, từ nghĩa không nhất quán (ví dụ "Phiếu nhận"/"Phiếu nhập" cho cùng một thứ) → lập bảng thuật ngữ đề xuất ở `docs/go-live/overnight/M13-glossary.md` (so với `docs/GLOSSARY.md`), **không tự đổi thuật ngữ** nếu GLOSSARY không quy định rõ.

### M14. 4 trạng thái mỗi màn hình
Đi qua mọi `page.tsx` dưới `src/app/(app)/[property]/**`, `src/app/m/**`, `src/app/admin/**`. Màn nào thiếu một trong 4 trạng thái (đang tải `loading.tsx`/skeleton, rỗng `EmptyState`, lỗi `error.tsx`/thông báo, có dữ liệu) → bổ sung theo mẫu có sẵn (`EmptyState`, `ModuleDisabled`…). Danh sách màn đã/chưa làm ghi vào báo cáo.

### M15. Truy cập (a11y) & di động
Nút/ô nhập có nhãn (`label`/`aria-label` từ `vi.ts`), tương phản, thứ tự Tab, vùng chạm ≥ 44 px trên `/m/*`, không tràn ngang ở 390 px, bàn phím số cho ô số lượng/PIN (`inputMode`). Sửa các lỗi rõ ràng ở code giao diện; lập danh sách lỗi còn lại.

### M16. Rà soát bảo mật phía client (chỉ báo cáo)
Tìm: `service_role`/secret trong code chạy ở trình duyệt, `NEXT_PUBLIC_*` lộ khóa nhạy cảm, `dangerouslySetInnerHTML`, log chứa PIN/mật khẩu/token, route handler `/api/*` thiếu kiểm tra secret/quyền, Server Action tính tiền bằng `number` rồi lưu (vi phạm quy tắc 7), so sánh tên vai trò thay vì `useCan`/`has_perm` (quy tắc 10). **Chỉ báo cáo** kèm file:dòng và mức độ; sửa chỉ khi là lỗi UI thuần và chắc chắn.

## Nhóm 6 — Tài liệu

### M17. Hướng dẫn sử dụng theo vai trò (tiếng Việt, cho nhân viên khách sạn)
Từ kết quả test, viết `docs/go-live/user-guide-<vai-trò>.md` cho 7 vai trò gọn (Chủ đầu tư, Quản lý, Kế toán, Thu mua & Thủ kho, Bếp/Nhà hàng, Buồng phòng, Lễ tân): mỗi vai trò 1 trang — "Hằng ngày làm gì", từng luồng theo bước kèm tên menu **đúng như trên giao diện**, lỗi thường gặp và cách xử lý. Viết cho người không rành công nghệ; không nêu mã quyền/RPC; không đưa PIN/mật khẩu.

### M18. Cập nhật kịch bản & checklist
Sửa `demo-walkthrough.md`/`uat-guide.md`/`checklist.md` cho khớp thực tế vừa test (đường dẫn, tên nút, bước thừa/thiếu). Thêm mục "Lỗi đã biết & cách né" từ báo cáo. Không đổi số liệu pgTAP trừ khi tự chạy lại được.

## Báo cáo cuối

`docs/go-live/muse-report-overnight.md`:
- Bảng M1–M18: Đạt / Không đạt / Chưa làm (+ lý do), thời gian, commit hash, đường dẫn báo cáo con.
- **Lỗi tìm thấy:** mô tả, bước tái hiện, mức độ (chặn / sai số liệu / bảo mật / giao diện), thuộc **UI / DB-RPC / quyền / dữ liệu**, đã sửa chưa (commit nào).
- **Chuyển Claude Code:** mọi lỗi DB/RPC/quyền/dữ liệu + đề xuất, xếp ưu tiên.
- Tồn kho cuối ngày của NVL0388/NVL0561 ở KHO-T047 và công nợ NCC trên màn hình.
- Lệnh đã chạy + kết quả thật (`pnpm lint`, `typecheck`, `test`, `e2e`), số test trước/sau.
- Việc bỏ dở và vì sao.

## Gợi ý thứ tự nếu thiếu PIN/camera

Không có PIN → bỏ M1–M3, làm M9 (phần không cần PIN), M10, M12, M13, M14, M15, M16, M11 (phần readonly), M17, M18, rồi M4–M8 trong phạm vi tài khoản không bị PIN chặn. Ưu tiên giá trị: M9 > M12 > M16 > M14 > M13 > M15 > M11 > M17 > M18.
