# M11 — Playwright e2e: ma trận quyền theo vai trò + không tràn ngang mobile

- Ngày chạy: 13/11/2026, ~23:20–23:35 (giờ VN). App live https://erphotel.vercel.app, TEST47.
- Lệnh chạy (trên VM, xem mục "Chạy trên VM" ở cuối):
  `TEST_PROPERTY_ID=<id TEST47> TEST_USER_EMAIL=uat.owner@erp.internal TEST_USER_PASSWORD=<mk> TEST_ROLE_PASSWORD=<mk> npx playwright test --project=readonly-roles --project=readonly-mobile --project=public`
- Kết quả chạy đầy đủ cuối cùng: **31 đậu / 3 rớt** (1,9 phút). Chi tiết ở mục A.

## A. Kết quả theo spec

### Mới — roles.spec.ts (project readonly-roles, desktop 1280×800)
9 test, 1 test/vai trò: đăng nhập đúng vai trò (uat.*), mở 1 màn được phép
(200 + main + tiêu đề tiếng Việt + không pageerror/console error) và 1 màn
bị chặn (hiện thông báo 404 hoặc không có quyền, không pageerror).
Kết quả: **8/9 đậu**. Rớt duy nhất **R-receiver** — xem mục B.1.

| Test | Màn mở | Màn chặn | Kết quả |
|---|---|---|---|
| R-owner | /procurement/pr | (không có — owner mở hết; kiểm thêm /admin/users) | Đậu |
| R-gm | /inventory/stock | /receiving (404) | Đậu |
| R-accountant | /procurement/pr | /inventory/stock (không quyền xem tồn) | Đậu |
| R-purchaser | /procurement/pr | /finance/payables (không quyền xem công nợ) | Đậu |
| R-chef | /restaurant | /procurement/po (không quyền) | Đậu |
| R-hk_supervisor | /housekeeping/minibar | /inventory/stock (không quyền xem tồn) | Đậu |
| R-front_desk | /frontdesk/minibar | /procurement/pr (404) | Đậu |
| R-receiver | /m/receive | /procurement/pr (404) | **Rớt — React error #419 (mục B.1)** |
| R-storekeeper | /receiving | /procurement/pr (404) | Đậu |

### Mới — mobile-overflow.spec.ts (project readonly-mobile, 390×844)
14 màn (desktop + /m/*) với tài khoản owner: đo `documentElement.scrollWidth`
và `body.scrollWidth` sau khi tải xong, cả hai phải ≤ 390.
Kết quả: **14/14 đậu — không màn nào tràn ngang ở 390px.**
(Tổng quan, danh sách yêu cầu mua, danh sách đơn mua, tồn kho, đợt kiểm kê,
hóa đơn NCC, báo cáo, nhà hàng, minibar lễ tân, minibar buồng phòng,
quản lý người dùng, nhận hàng mobile, kiểm kê mobile, minibar mobile.)

### Cũ — public.spec.ts (project public, không cần đăng nhập)
**5/5 đậu** (P1–P5: form đăng nhập, / chuyển về /login, manifest, sw.js, /offline).

### Cũ — mobile-pwa.spec.ts (project readonly-mobile)
M1–M3 đậu. **M4, M5 rớt (spec cũ, không phải do M11)** — xem mục B.2, B.3.

### Tầng ghi — kiểm tra env-gate (không chạy ghi thật)
`npx playwright test --project=write` khi KHÔNG đặt TEST_WRITE_ENABLED:
**11 test ghi skip, 1 passed** (chỉ có setup authenticate ghi state rỗng).
Env-gate còn nguyên — không test ghi nào chạy khi chưa đủ điều kiện.

## B. Phát hiện

### B.1 R-receiver: React error #419 (hydration) trên trang 404 — lỗi thật, cần soi code
- Hiện tượng: trong 2 lần chạy đầy đủ, test R-receiver rớt ở màn chặn
  /procurement/pr với `pageerror: Minified React error #419` (lỗi hydration —
  client render khác server render, ngoài Suspense boundary). Trang 404 vẫn
  hiển thị được (đã kiểm chứng bằng mắt ở M9), nhưng console có pageerror.
- Chạy RIÊNG chỉ test R-receiver thì **đậu** — lỗi phụ thuộc thứ tự chạy
  trong suite (order-dependent), không tái hiện khi chạy đơn lẻ.
- Giả thuyết mạnh nhất: service worker / menu cache chia sẻ giữa các test
  trong cùng 1 trình duyệt phục vụ shell cũ (menu của tài khoản trước) rồi
  hydration lệch với menu của receiver (chỉ 2 mục) — cùng họ với phát hiện
  M9 F.1 (menu hiện bộ mục của tài khoản trước ngay sau đăng nhập).
  Chưa chứng minh chắc chắn bằng code — cần soi `src/app` (menu/layout/
  service worker) để kết luận.
- **Lớp: UI. Chuyển Claude Code.** Tái hiện: chạy full project
  readonly-roles; R-receiver rớt ở màn chặn, các vai trò khác đậu.

### B.2 M4: DB offline "erp-hotel-offline" không tồn tại sau khi mở /m/receive — kỳ vọng của spec cũ đã lỗi thời, không phải lỗi app
- `indexedDB.databases()` trả `[]` sau khi mở màn nhận hàng mobile.
- Đối chiếu code (`src/lib/offline/db.ts`): `getOfflineDb()` là lazy
  singleton — `new OfflineDb()` chỉ chạy khi có code gọi nó, và Dexie chỉ
  tạo IndexedDB khi enqueue job thật (offline). Màn /m/receive chỉ import
  `enqueueOfflineJob`, không gọi, nên DB chưa được tạo cho tới khi người
  dùng ghi offline thật. Kỳ vọng "mở màn là có DB" của M4 không còn đúng
  với code hiện tại.
- **Hướng xử lý (đề xuất, chưa làm trong M11):** sửa M4 thành kiểm tra DB
  xuất hiện sau khi enqueue 1 job (tầng ghi), hoặc bỏ assertion này khỏi
  tầng đọc. Chuyển Claude Code quyết định.

### B.3 M5: service worker đã đăng ký nhưng chưa active — chưa kết luận
- `navigator.serviceWorker.getRegistration()` có registration, nhưng
  `registration.active` là false ngay sau khi mở trang tổng quan.
  `public/sw.js` có `skipWaiting()` + `clients.claim()` nên SW đáng lẽ
  active nhanh; khả năng cao là test kiểm tra quá sớm (install chưa xong)
  hoặc install chậm qua proxy VM. Chưa phân biệt được lỗi app hay timing
  của test — cần chạy lại trên máy Mac (mạng trực tiếp) hoặc thêm bước chờ
  activation rồi mới assert.
- **Chuyển Claude Code** (soi cùng B.1/B.2 hoặc chạy lại trên Mac).

### B.4 Trang 404 và lúc đang tải render 2 thẻ <main> — lỗi a11y thật
- Phát hiện khi viết spec: `locator('main')` strict-violation vì DOM có 2
  `<main>` cùng lúc — lúc đang tải (1 `<main aria-busy>` của loading
  boundary + 1 `<main>` nội dung) và trên trang 404 (1 `<main>` layout cũ
  + 1 `<main>` của trang 404). Một trang chỉ nên có đúng 1 landmark main.
- Spec M11 đã né bằng cách dùng `main.last()` (main của trang đang hiện)
  sau khi đợi loading boundary biến mất — spec xanh không có nghĩa app đúng.
- **Lớp: UI/a11y. Chuyển Claude Code** (loading.tsx / not-found.tsx render
  `<main>` riêng thay vì `<div>`).

### B.5 Route /admin/* không có uuid property
- `/<uuid>/admin/users` trả HTTP 404; đường đúng là `/admin/users`
  (không uuid) — khớp ma trận M9 (dòng #14/#15 không có uuid).
  Spec M11 ban đầu viết sai đường này, đã sửa (owner open2 + overflow).
  Không phải lỗi app — ghi lại để tránh tái phạm.

## C. Thay đổi code trong M11

- `tests/e2e/helpers.ts`: thêm hằng `TEST47_PROPERTY_ID` + `requireTest47()`
  (skip khi TEST_PROPERTY_ID không phải TEST47 — tài khoản uat.* chỉ thấy TEST47).
- `tests/e2e/readonly/roles.spec.ts` (mới, 9 test): ma trận quyền theo vai trò,
  xem đầu báo cáo. Tài khoản qua env `TEST_ROLE_PASSWORD` (mật khẩu chung
  uat.*) + email mặc định `uat.<vai trò>@erp.internal`, đổi được qua
  `TEST_ROLE_<VAI TRÒ>_EMAIL`. Không hardcode mật khẩu.
- `tests/e2e/readonly/mobile-overflow.spec.ts` (mới, 14 test): không tràn
  ngang ở 390px.
- `playwright.config.ts`: thêm project `readonly-roles` (desktop 1280×800,
  storageState như readonly-desktop); project `readonly-mobile` nhận thêm
  `mobile-overflow.spec.ts`.
- `tests/e2e/README.md`: thêm 2 dòng vào bảng test + mục chạy roles +
  ghi chú forwarder cho VM (xem dưới).
- Không đổi code app, không đổi migration, không ghi dữ liệu.

## D. Chạy trên VM (ghi chú hạ tầng, đã kiểm chứng)

- **Chromium trên VM không qua được egress proxy nếu không có
  Proxy-Authorization preemptive** (proxy cắt CONNECT không xác thực ngay,
  `ERR_TUNNEL_CONNECTION_FAILED`; curl chạy được vì gửi preemptive).
  Config Playwright đã tách user/pass để xử lý 407 nhưng không đủ với proxy này.
- **Cách chạy đã kiểm chứng:** forwarder CONNECT cục bộ
  `~/workspace/proxy-forwarder.cjs` (Node, không dependency): lắng nghe
  127.0.0.1:18080, tự thêm `Proxy-Authorization` vào CONNECT lên upstream.
  Chạy nền trước rồi đặt `HTTPS_PROXY=http://127.0.0.1:18080` cho lệnh Playwright.
  Không có forwarder thì setup + mọi `page.goto` đều rớt tunnel (đã gặp 2 lần).
- Lệnh đầy đủ (VM):
  `node ~/workspace/proxy-forwarder.cjs &` rồi chạy lệnh ở đầu báo cáo với
  `HTTPS_PROXY=http://127.0.0.1:18080` + `PLAYWRIGHT_CHROME_PATH=/home/hatch/workspace/.chrome-tmp/chrome-linux64/chrome`.
- Các test ghi (`--project=write`) vẫn skip khi thiếu TEST_WRITE_ENABLED
  (đã kiểm chứng 11 skipped).
- Thư mục `tests/e2e/.auth/` và `test-results/` không commit (đã có trong
  .gitignore từ trước).

## E. Kết luận M11

- **Đạt một phần — 31/34 đậu ở lần chạy đầy đủ cuối.** 2 spec mới viết xong
  và chạy được thật trên VM: ma trận quyền theo vai trò 8/9 (R-receiver rớt
  do lỗi hydration #419, mục B.1) và không tràn ngang mobile 14/14.
- 3 phát hiện chuyển Claude Code: hydration #419 ở trang 404 (B.1), M4/M5
  spec cũ lỗi thời hoặc timing (B.2/B.3), 2 thẻ `<main>` (B.4).
- Gate: lint + typecheck + Vitest 285/285 xanh (chạy lại ở commit).
