# Giao việc cho Muse — đêm 13/11/2026

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình** trong đêm; sáng mai Claude Code tiếp quản.
> Đọc `AGENTS.md`, `docs/go-live/checklist.md`, `docs/OPEN-QUESTIONS.md` (Q34, Q152, Q172, Q173) trước khi code.

## Luật cho đêm nay (bắt buộc)

1. **Chỉ làm code giao diện, test, tài liệu.** KHÔNG tạo/sửa migration trong `supabase/migrations/`, KHÔNG chạy `supabase db push`, KHÔNG `vercel`, KHÔNG ghi dữ liệu lên production (kể cả qua `supabase db query`). Cần DB mới → dừng, ghi vào `docs/OPEN-QUESTIONS.md`, để Claude Code làm.
2. **Không đụng** các file/hàm Claude Code vừa làm: migration 565000–567000, `po_submit`, `po_set_estimated_total`, `count_open`, `pos_import_commit`, `src/lib/database.types.ts` (không sửa tay).
3. Mỗi task = **một nhánh** `feat/muse-<tên>` từ `main` mới nhất; xong thì `pnpm lint && pnpm typecheck && pnpm test` xanh rồi commit. **Không merge vào `main`, không push** — để Claude Code review sáng mai.
4. Mọi chuỗi hiển thị vào `src/i18n/vi.ts` (ESLint chặn tiếng Việt hard-code ngoài `src/i18n/`). Không `any`, không tắt ESLint rule.
5. Mỗi task thêm 1 dòng vào `CHANGELOG.md` (mã `M-xx`) và ghi trạng thái thật (đã chạy gì, chưa chạy gì). Không bịa kết quả.
6. Làm theo thứ tự dưới đây. Task nào kẹt > 30 phút → ghi lý do vào CHANGELOG, bỏ qua, làm task tiếp.

## Task M-01 — Ánh xạ cột khi nạp file POS (ưu tiên cao nhất)

Bối cảnh: `/inventory/pos-import` (`src/components/inventory/pos-import-form.tsx`, parser `src/lib/pos/parse-csv.ts`) đang giả định tên cột theo file **giả lập** `docs/samples/pos-export-sample-SYNTHETIC.csv`. File POS thật sẽ có tên cột khác.

Làm: thêm bước **ánh xạ cột** ở trình duyệt: đọc dòng tiêu đề của file bất kỳ (CSV, và nếu gọn thì xlsx qua thư viện `xlsx` đã có) → cho người dùng chọn cột nguồn cho từng trường đích (`bill_no`, `business_date`, `shift`, `time`, `outlet`, `item_code`, `item_name`, `qty`, `unit_price`, `amount`, `payment`; 7 trường đầu bắt buộc như `REQUIRED` trong parser) → xem trước 20 dòng → nạp. Tự đoán ánh xạ theo tên gần giống; nhớ ánh xạ đã chọn trong `localStorage` (bọc try/catch). Hỗ trợ định dạng ngày `DD/MM/YYYY` → chuẩn hóa `YYYY-MM-DD` trước khi gửi, và số kiểu `1.234,56`/`1,234.56`. Vẫn gọi `importPosAction` hiện có, **không đổi RPC/tham số**.
Tiêu chí xong: Vitest cho hàm ánh xạ + chuẩn hóa ngày/số (file mẫu giả lập vẫn đọc được); 4 trạng thái màn hình (tải/rỗng/lỗi/có dữ liệu); không đụng server action.

## Task M-02 — Kiểm tra màn nhập danh mục thật (phòng, NCC, giá minibar)

Bối cảnh: sắp phải nhập dữ liệu thật (0 phòng, 1 NCC, giá minibar hết hạn). Xem `src/app/(app)/[property]/master/{rooms,suppliers,prices,import}` và `docs/07-IMPORT-MIGRATION.md`.

Làm: (a) lập bảng trong `docs/go-live/data-entry-readiness.md`: với phòng, loại phòng, NCC, hợp đồng khung/giá trần, giá minibar — hiện **nhập tay được không / import Excel được không / RPC nào**; (b) với phần chỉ thiếu UI (đã có RPC), làm UI nhập hàng loạt từ Excel/CSV có xem trước + báo lỗi từng dòng; (c) phần thiếu RPC → liệt kê rõ, **không tự viết migration**.
Tiêu chí xong: tài liệu (a) chính xác (đọc code, không đoán); mỗi UI mới có Vitest cho phần parse/validate.

## Task M-03 — Test đồng bộ offline kiểm minibar (Q152/Q199)

Bối cảnh: đã thêm kind `minibar_submit` vào `src/lib/offline/{db,sync}.ts` và `mobile-check-form.tsx`; mới sửa test U24, chưa có test đồng bộ.
Làm: Vitest (fake IndexedDB nếu đã có sẵn trong repo; nếu phải thêm thư viện thì ghi lý do ở `docs/decisions/ADR-xxx.md` trước) cho: xếp hàng khi `online=false`; `pumpQueue` gọi `submitCheckAction` đúng tham số và xóa job; gửi lại cùng `clientUuid` không tạo job thứ hai; lỗi server → job `failed` và `lastError`; thứ tự job.
Tiêu chí xong: test chạy xanh trong `pnpm test`; không sửa logic production trừ khi phát hiện lỗi thật (khi đó mô tả lỗi trong CHANGELOG).

## Task M-04 — Hướng dẫn UAT theo vai trò

Làm: `docs/go-live/uat-guide.md` (tiếng Việt có dấu, dành cho người không rành kỹ thuật): mỗi vai trò trong 16 tài khoản `uat.<mã vai trò>@erp.internal` (lấy danh sách vai trò từ `docs/04-SECURITY-RLS.md`/seed — **không ghi mật khẩu**) → 3–6 kịch bản thử có bước cụ thể, kết quả mong đợi, và chỗ điền "Đạt/Không đạt/Ghi chú". Phải có các luồng: mua hàng (PR→PO→duyệt, gồm PO chợ nhập tổng ước tính), nhận hàng mù, kiểm kê, xe đẩy + minibar offline, nạp file POS, màn `/admin/health`. Chỉ ghi những gì app thực sự làm — đọc code/route để xác nhận.
Tiêu chí xong: mỗi kịch bản trỏ đúng đường dẫn màn hình có thật.

## Task M-05 — Hoàn thiện màn `/admin/health` (ưu tiên thấp)

`src/app/admin/health/page.tsx` mới là bản đầu. Làm: trạng thái Ổn/Cần xem theo ngưỡng (cron lỗi > 0, thông báo kẹt > 0, cảnh báo đỏ > 0), nút Tải lại, ghi chú dung lượng so với giới hạn gói (chỉ hiển thị số, không bịa giới hạn), responsive điện thoại. Dùng chuỗi có sẵn trong `vi.admin.health`, thêm chuỗi mới nếu cần.

## Việc Claude Code làm sáng mai (Muse đừng làm)

Review + merge nhánh Muse; Q172 (điều chỉnh giá vốn hàng chợ giá 0 — cần kế toán duyệt); script import dữ liệu thật khi Duy gửi; tắt tài khoản test/UAT; staging (chờ Duy đồng ý chi phí).

## Báo cáo cuối đêm

Cuối phiên: liệt kê từng nhánh, lệnh đã chạy và kết quả thật (lint/typecheck/test), task nào bỏ dở và vì sao. Đặt vào `docs/go-live/muse-report-2026-11-13.md`.
