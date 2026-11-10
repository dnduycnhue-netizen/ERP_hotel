# ADR-005 — Công cụ kiểm thử: Playwright + Vitest + fake-indexeddb

Ngày: 2026-11-10. Task: T-047.

## Bối cảnh

`AGENTS.md` §2 đã chọn sẵn bộ công cụ test (pgTAP, Vitest, Playwright) nhưng
repo chưa có bất kỳ test nào trong 3 tầng: chưa có `tests/e2e/`, chưa có
Vitest, chưa có Playwright. T-047 cần dựng khung để chạy được ngay trên VM
(không Docker, không Supabase local) và để Duy chạy tiếp trên máy mình.

## Quyết định

1. **Playwright 1.65** (`@playwright/test`, devDependency) cho tầng đầu cuối.
   Chạy 2 project viewport theo `11-TESTING.md` §1: laptop 1280×800 và
   điện thoại 390×844. `trace`/`screenshot` chỉ khi fail.
2. **Vitest 5.1** (`vitest`, devDependency) cho tầng đơn vị: schema Zod đã
   có sẵn, hàm tiện ích, và Dexie queue (theo `11-TESTING.md` §1).
3. **fake-indexeddb 6.2.8** (`fake-indexeddb`, devDependency) để test Dexie
   queue trong Node — không cần trình duyệt thật cho tầng đơn vị.
4. **Không tải browser của Playwright trên VM**: dùng Chrome for Testing
   158 có sẵn qua env `PLAYWRIGHT_CHROME_PATH` (xem `playwright.config.ts`).
   Trên máy Duy, bỏ env này thì Playwright dùng Chromium của nó
   (`npx playwright install chromium`).
5. **Không test pumpQueue trong Vitest**: `sync.ts` import server actions
   của Next.js nên không chạy được trong Node. Đồng bộ thật được kiểm
   chứng ở tầng Playwright (W5) trên trình duyệt.

## Thiết kế 2 tầng (quy tắc dữ liệu)

- **Tầng đọc** (mặc định): chỉ GET/điều hướng trên production live, không
  ghi dữ liệu. Cần `TEST_USER_EMAIL`/`TEST_USER_PASSWORD`; thiếu thì test
  cần auth tự skip, test public + PWA tĩnh vẫn chạy.
- **Tầng ghi** (`tests/e2e/write/`): chỉ chạy khi `TEST_WRITE_ENABLED=1`
  và `TEST_PROPERTY_ID` là property test riêng (khác SONHOIAN). Tạo PR →
  PO → nhận hàng → hóa đơn → thanh toán → báo cáo trên property đó.
  Seed property test bằng SQL tay (`seed-test-property.sql`), 2 tài khoản
  test (người tạo + người duyệt) vì SoD cấm 1 người làm cả 2 vai.

## Hệ quả

- Script mới: `pnpm test` (Vitest), `pnpm e2e` (Playwright).
- `.gitignore` thêm `/test-results`, `/playwright-report`,
  `/tests/e2e/.auth` (session + flow state, không commit).
- pgTAP giữ nguyên là tầng CSDL, không thay đổi trong task này.
