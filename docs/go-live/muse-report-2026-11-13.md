# Báo cáo đêm 13/11/2026 — Muse (M-01 → M-05)

> **Phạm vi:** chỉ code giao diện, test, tài liệu. Không tạo/sửa migration, không `db push`,
> không `vercel`, không ghi production. Tất cả 5 nhánh đều tạo từ `origin/main` head `eab1ddf`,
> **chưa merge, chưa push** — chờ Claude Code review sáng 13/11.
>
> **Môi trường kiểm tra:** VM, `npx -y pnpm@12.14.0`, env giả
> `NEXT_PUBLIC_SUPABASE_URL=https://dummy.supabase.co` +
> `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=dummy-publishable-key`.
> Lệnh chuẩn mỗi nhánh: `pnpm lint && pnpm typecheck && pnpm test`.

## Tổng kết

| Task | Trạng thái | Nhánh | Head commit | Lint | Typecheck | Test |
|------|-----------|-------|-------------|------|-----------|------|
| M-01 Ánh xạ cột POS | **ĐẠT** | `feat/muse-pos-column-mapping` | `a7f1246` | sạch | sạch | **174/174** (21 file) |
| M-02 Nhập danh mục thật | **ĐẠT** | `feat/muse-data-entry-readiness` | `4745bdb` | sạch | sạch | **173/173** (21 file) |
| M-03 Test đồng bộ offline minibar | **ĐẠT** | `feat/muse-minibar-offline-sync-test` | `ea20311` | sạch | sạch | **166/166** (21 file) |
| M-04 Hướng dẫn UAT theo vai trò | **ĐẠT** | `feat/muse-uat-guide` | `a279859` | sạch | sạch | **160/160** (20 file) |
| M-05 Hoàn thiện /admin/health | **ĐẠT** | `feat/muse-admin-health-polish` | `549d7de` | sạch | sạch | **166/166** (21 file) |

Không có task nào bỏ dở. Không có task nào kẹt quá 30 phút.

## M-01 — Ánh xạ cột khi nạp file POS (ưu tiên cao nhất) — ĐẠT

- **Nhánh:** `feat/muse-pos-column-mapping` — head `a7f1246` — "feat(pos-import): anh xa cot khi nap file POS (M-01)".
- **Làm gì:**
  - Mới `src/lib/pos/column-mapping.ts`: tự đoán ánh xạ theo tên cột (có/không dấu), chuẩn hóa ngày
    `DD/MM/YYYY` + Excel serial → `YYYY-MM-DD`, chuẩn hóa số `1.234,56` / `1,234.56`, nhớ ánh
    xạ đã chọn trong `localStorage` (bọc try/catch).
  - Sửa `src/components/inventory/pos-import-form.tsx`: thêm bước ánh xạ cột + xem trước 20 dòng,
    nhận `.xlsx`/`.xls` (sheet đầu tiên); vẫn gọi `importPosAction` hiện có, không đổi RPC/tham số.
  - Sửa `src/lib/pos/parse-csv.ts`: export `splitCsv` (1 dòng). Thêm chuỗi vào `src/i18n/vi.ts`.
- **Test:** `tests/unit/pos-column-mapping.test.ts` — 14 test. File mẫu giả lập vẫn đọc được.
  Toàn bộ: **174/174** (21 file).
- **Lỗi bắt được nhờ test (đã sửa trong nhánh):**
  1. Thiếu alias `mabill` ("Mã bill" chuẩn hóa thành `mabill`).
  2. `đ` không tách được dưới NFD — "Đơn giá" chuẩn hóa thành `ongia` thay vì `dongia` — sửa bằng
     `.replace(/đ/g, "d")` trước NFD.
  3. Ký tự tổ hợp dấu trong source dễ vỡ khi sửa bằng công cụ — đã thay bằng escape tường minh
     `[\u0300-\u036f]` và `[\s\u00a0]`.
- **File đổi (6):** `CHANGELOG.md`, `src/components/inventory/pos-import-form.tsx`,
  `src/i18n/vi.ts`, `src/lib/pos/column-mapping.ts` (mới), `src/lib/pos/parse-csv.ts`,
  `tests/unit/pos-column-mapping.test.ts` (mới). 875 dòng thêm, 31 dòng bớt.

## M-02 — Kiểm tra màn nhập danh mục thật — ĐẠT

- **Nhánh:** `feat/muse-data-entry-readiness` — head `4745bdb` — "feat(master): nhap hang loat danh muc + tai lieu san sang nhap du lieu that (M-02)".
- **Làm gì:**
  - Mới `docs/go-live/data-entry-readiness.md`: bảng đối chiếu đọc từ code — phòng/loại phòng nhập
    tay được (ghi thẳng bảng qua action có sẵn), NCC nhập tay + import Excel trong wizard, hợp
    đồng khung/giá trần nhập tay, giá minibar nhập tay từng dòng qua RPC `minibar_price_set`,
    tồn đầu kỳ KHÔNG nhập qua Excel (phải kiểm kê toàn bộ).
  - Mới `src/lib/master/bulk-import.ts` + `src/components/master/bulk-import-dialog.tsx`: UI nhập
    hàng loạt CSV/XLSX có xem trước 20 dòng + báo lỗi từng dòng; mỗi dòng hợp lệ gọi action
    đơn dòng đã có (không RPC mới, không migration). Gắn vào: phòng + loại phòng
    (`rooms-manager.tsx`), giá trần (`prices-manager.tsx`), giá minibar
    (`office-price-manager.tsx`).
  - Sửa `src/lib/pos/parse-csv.ts`: export `splitCsv` (cùng 1 dòng như M-01 — nhánh này tách từ
    main nên chưa có).
- **Test:** `tests/unit/master-bulk-import.test.ts` — 13 test. Toàn bộ: **173/173** (21 file).
- **Lưu ý cho Claude Code khi merge:**
  - `bulk-import.ts` đang inline bản sao các hàm chuẩn hóa của M-01 (`column-mapping.ts`) kèm
    ghi chú NOTE — vì nhánh này tách từ main, không import được module M-01. Sau khi cả hai
    nhánh merge, xóa bản sao và import từ `column-mapping`.
  - Nhập hàng loạt KHÔNG nguyên tử theo lô: dòng giữa chừng lỗi thì các dòng đã lưu vẫn giữ.
    Đã ghi rõ trong tài liệu.
  - Phần thiếu RPC (liệt kê trong tài liệu, để Claude Code làm): không có RPC ghi hàng loạt
    nguyên tử cho phòng/loại phòng/giá trần/giá minibar/hợp đồng; không có import file cho hợp
    đồng giá (+ dòng — cần thiết kế file 2 tầng + RPC mới); không có import file cho tồn đầu kỳ.
- **File đổi (10):** `CHANGELOG.md`, `docs/go-live/data-entry-readiness.md` (mới),
  `src/components/master/bulk-import-dialog.tsx` (mới), `src/components/master/prices-manager.tsx`,
  `src/components/master/rooms-manager.tsx`, `src/components/minibar/office-price-manager.tsx`,
  `src/i18n/vi.ts`, `src/lib/master/bulk-import.ts` (mới), `src/lib/pos/parse-csv.ts`,
  `tests/unit/master-bulk-import.test.ts` (mới). 1.300 dòng thêm, 12 dòng bớt.

## M-03 — Test đồng bộ offline kiểm minibar (Q152/Q199) — ĐẠT

- **Nhánh:** `feat/muse-minibar-offline-sync-test` — head `ea20311` — "test(offline): dong bo offline kiem minibar (M-03)".
- **Làm gì:** mới `tests/unit/minibar-offline-sync.test.ts` — 6 test, mock các server action rồi
  test `pumpQueue` thật trong `src/lib/offline/sync.ts`:
  1. Mất mạng: job xếp hàng, `pumpQueue` không bơm.
  2. `pumpQueue` gọi `submitCheckAction` đúng tham số và xóa job; listener `onMinibarSubmitSynced`
     được gọi đúng `checkId`.
  3. Bơm lại sau khi xong không gửi lại (không tạo job thứ hai).
  4. Hai job cùng `clientUuid` (bấm nộp 2 lần khi offline) đều được bơm, server trả `duplicate`
     lần 2, không còn job tồn.
  5. Lỗi server → job `failed` + `lastError`, job sau không bị bơm (hàng đợi dừng đúng thứ tự).
  6. Thứ tự job theo `createdAt`.
- **Kết quả:** 6/6 xanh ngay lần đầu. **Không sửa logic production** (không phát hiện lỗi thật).
  Không cần thêm thư viện — `fake-indexeddb` đã có sẵn trong repo (không cần viết ADR).
- **Ghi nhận (không phải lỗi):** bấm nộp 2 lần khi offline tạo 2 job cùng `clientUuid` (form không
  chặn trùng) — chống trùng dựa vào server trả `duplicate`, như tiền lệ U2. Đã ghi trong CHANGELOG
  của nhánh.
- **Bẫy kỹ thuật gặp khi viết test:** `navigator` của Node có sẵn nhưng không ghi đè được bằng
  phép gán (`navigator.onLine` là `undefined`) — test phải dùng `Object.defineProperty` để điều
  khiển trạng thái online. Đã ghi chú trong file test.
- **File đổi (2):** `CHANGELOG.md`, `tests/unit/minibar-offline-sync.test.ts` (mới).
  Toàn bộ: **166/166** (21 file).

## M-04 — Hướng dẫn UAT theo vai trò — ĐẠT

- **Nhánh:** `feat/muse-uat-guide` — head `a279859` — "docs(uat): huong dan UAT theo vai tro (M-04)".
- **Làm gì:** mới `docs/go-live/uat-guide.md` — 16 tài khoản `uat.<vai trò>@erp.internal`
  (**không ghi mật khẩu**), 77 kịch bản có bước cụ thể + kết quả mong đợi + cột
  Đạt/Không đạt/Ghi chú, kèm 4 luồng liên vai trò (mua hàng → nhận → thanh toán, PO chợ,
  minibar, kiểm kê theo ca) và bảng tổng kết cuối.
- **Kiểm chứng:** toàn bộ **35 đường dẫn màn hình** trong tài liệu đã đối chiếu bằng script với
  `page.tsx` thật — 35/35 có thật. Quyền theo bảng mẫu `supabase/seed.sql` + migration 565000
  (`admin.health.view`: sys_admin, owner) + 567000 (`pos.import`: gm, chief_accountant,
  accountant, cost_controller); tài liệu ghi rõ quyền thật trên production có thể khác bảng mẫu.
- **Khoảng trống phát hiện khi viết (đã ghi trong tài liệu):** app **chưa có màn hình xem chi
  tiết nhật ký audit** — quyền `audit.view_all` đã có nhưng chưa có giao diện. Kịch bản của
  `internal_audit` ghi nhận đây là khoảng trống cần bổ sung, không tính là lỗi thao tác.
- **File đổi (2):** `CHANGELOG.md`, `docs/go-live/uat-guide.md` (mới).
  Toàn bộ: **160/160** (20 file — nhánh tách từ main nên không có test mới của M-03/M-05).

## M-05 — Hoàn thiện màn `/admin/health` (ưu tiên thấp) — ĐẠT

- **Nhánh:** `feat/muse-admin-health-polish` — head `549d7de` — "feat(admin): hoan thien man /admin/health (M-05)".
- **Làm gì:**
  - Banner trạng thái chung **Ổn/Cần xem** theo đúng 3 ngưỡng (cron lỗi 7 ngày > 0, thông báo
    kẹt > 0, cảnh báo đỏ > 0) kèm danh sách chỉ số vượt ngưỡng.
  - Nút **Tải lại** (`router.refresh`) qua client component mới
    `src/components/admin/health-refresh-button.tsx`, đặt trong `PageHeader` actions.
  - Ghi chú dung lượng: giới hạn gói chưa được cấu hình nên chỉ hiển thị dung lượng hiện tại,
    **không bịa giới hạn**.
  - Responsive: bảng cron `min-w-[560px]` để cuộn ngang trên điện thoại; số liệu Stat
    `text-xl sm:text-2xl`.
  - Logic trạng thái tách ra `src/lib/admin/health-status.ts` (hàm thuần `summarizeHealth`).
  - Dùng luôn chuỗi `statusOk`/`statusWarn`/`refresh` đã có sẵn trong `vi.ts` (trước đây chưa
    dùng); thêm 3 chuỗi mới (`statusOkDetail`, `statusWarnDetail`, `dbLimitNote`).
- **Test:** `tests/unit/admin-health-status.test.ts` — 6 test. Toàn bộ: **166/166** (21 file).
- **File đổi (6):** `CHANGELOG.md`, `src/app/admin/health/page.tsx`,
  `src/components/admin/health-refresh-button.tsx` (mới), `src/i18n/vi.ts`,
  `src/lib/admin/health-status.ts` (mới), `tests/unit/admin-health-status.test.ts` (mới).
  179 dòng thêm, 4 dòng bớt.

## Những gì Claude Code cần biết sáng mai

1. **Thứ tự merge gợi ý:** M-01 trước, rồi M-02 — vì M-02 inline bản sao hàm chuẩn hóa của M-01
   (có ghi chú NOTE trong code). Sau khi cả hai merge, xóa bản sao trong `bulk-import.ts` và
   import từ `src/lib/pos/column-mapping.ts`. Cả hai nhánh đều sửa cùng 1 dòng
   `src/lib/pos/parse-csv.ts` (export `splitCsv`) — merge nhánh sau sẽ trùng, giữ 1 bản là xong.
2. **M-02:** nhập hàng loạt không nguyên tử theo lô; thiếu RPC ghi hàng loạt nguyên tử + import
   hợp đồng giá + import tồn đầu kỳ (đã liệt kê trong `docs/go-live/data-entry-readiness.md`).
3. **M-03:** không phát hiện lỗi production. Bấm nộp 2 lần khi offline tạo 2 job cùng
   `clientUuid` — chống trùng ở server, đúng thiết kế.
4. **M-04:** app chưa có màn hình xem chi tiết nhật ký audit (quyền `audit.view_all` đã có).
   Nếu bổ sung màn hình này thì cập nhật kịch bản của `internal_audit` trong
   `docs/go-live/uat-guide.md`.
5. **M-05:** không đổi RPC `admin_system_health`, không đổi ngưỡng nào khác — chỉ hiển thị.
6. **Không có task nào cần DB mới**, nên không có dòng OPEN-QUESTIONS nào phát sinh trong đêm.
7. **Số test nền thay đổi theo nhánh** (do mỗi nhánh tách từ main `eab1ddf` ở thời điểm khác nhau
   và chỉ chứa test của chính nó): M-01 174, M-02 173, M-03 166, M-04 160, M-05 166 — tất cả
   đều xanh 100%, không có test nào fail hay skip.

## Nhánh báo cáo này

- **Nhánh:** `feat/muse-night-report` — chỉ chứa file báo cáo này
  (`docs/go-live/muse-report-2026-11-13.md`). Không sửa CHANGELOG ở nhánh này (dòng
  CHANGELOG của từng task đã nằm trong nhánh của task đó).
- **Chưa merge, chưa push.**
