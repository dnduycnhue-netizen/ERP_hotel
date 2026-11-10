# Kiểm thử nghiệm thu thí điểm (T-047)

## Chạy nhanh

```bash
# Tầng đơn vị (Vitest) — chạy được ngay, không cần tài khoản
pnpm test

# Tầng đầu cuối, chỉ đọc (Playwright) — cần tài khoản để đăng nhập
TEST_USER_EMAIL=... TEST_USER_PASSWORD=... pnpm e2e

# Chỉ test không cần đăng nhập + PWA tĩnh (chạy được trên VM)
npx playwright test --project=public
```

Mặc định `TEST_BASE_URL=https://erphotel.vercel.app`. Chạy local thì
`TEST_BASE_URL=http://localhost:3000 pnpm e2e` (nhớ `pnpm dev` trước).
Trên VM, Playwright dùng Chrome for Testing sẵn có:

```bash
PLAYWRIGHT_CHROME_PATH=/home/hatch/workspace/.chrome-tmp/chrome-linux64/chrome pnpm e2e
```

Trên máy Duy, bỏ biến này (Playwright dùng Chromium của nó, cài bằng
`npx playwright install chromium` nếu chưa có).

## Hai tầng dữ liệu (quy tắc cứng)

| Tầng | Chạy ở đâu | Ghi dữ liệu? | Cần gì |
|---|---|---|---|
| Đọc (`readonly/`, `public`) | Production live | Không — chỉ GET/điều hướng | `TEST_USER_EMAIL`, `TEST_USER_PASSWORD` (thiếu thì test cần auth tự skip) |
| Ghi (`write/`) | Property test riêng | Có — PR/PO/nhận/hóa đơn/thanh toán | `TEST_WRITE_ENABLED=1`, `TEST_PROPERTY_ID` (khác SONHOIAN), `TEST_CREATOR_*`, `TEST_APPROVER_*`, `TEST_RECEIVER_PIN` |

Tầng ghi **không bao giờ** chạy trên SONHOIAN: helper `writeEnabled()`
skip toàn bộ nếu `TEST_PROPERTY_ID` trùng id SONHOIAN.

## Chuẩn bị property test (chỉ làm 1 lần)

1. Chạy `tests/e2e/write/seed-test-property.sql` trong Supabase SQL Editor
   (nút Run). File idempotent, chạy lại không tạo trùng. Tạo: pháp nhân
   `TEST47-LE` (moving_avg), property `TEST47` ("Khách sạn test T047"),
   kho `KHO-T047`, outlet `NH-T047`, NCC `NCC-T047`, 2 vật tư thật từ file
   Excel (`NVL0388` ba chỉ nách, `NVL0561` Bánh bèo) + giá trần.
   Vật tư thuộc nhóm `kind='other'` nên nhận hàng không bắt buộc chụp ảnh.
2. Tạo 2 tài khoản ở `/admin/users` và gán vào property TEST47:
   - **Người tạo** — vai trò `purchaser` (tạo PR/PO). Đặt làm
     `TEST_CREATOR_EMAIL` / `TEST_CREATOR_PASSWORD`.
   - **Người duyệt** — vai trò `outlet_head` + `receiver` (duyệt PR/PO,
     nhận hàng). Đặt làm `TEST_APPROVER_EMAIL` / `TEST_APPROVER_PASSWORD`.
     Đặt mã PIN của người này là `1234` (hoặc đặt `TEST_RECEIVER_PIN`
     theo PIN đã đặt).
   Cần 2 người vì SoD cấm người tạo tự duyệt và tự nhận hàng của mình.
3. Chạy tầng ghi:

```bash
TEST_WRITE_ENABLED=1 \
TEST_PROPERTY_ID=<id property TEST47> \
TEST_CREATOR_EMAIL=... TEST_CREATOR_PASSWORD=... \
TEST_APPROVER_EMAIL=... TEST_APPROVER_PASSWORD=... \
TEST_RECEIVER_PIN=1234 \
pnpm e2e --project=write
```

Lấy id property TEST47 trong SQL Editor:
`select id from properties where code = 'TEST47';`

## Test nào chạy ở đâu

| File | Số test | Chạy trên VM? |
|---|---|---|
| `tests/unit/offline-queue.test.ts` (U1–U5) | 5 | Có |
| `tests/unit/offline-queue-server.test.ts` (U6–U8) | 3 | Có |
| `tests/unit/real-data-fixtures.test.ts` (U9–U13) | 5 | Có |
| `readonly/public.spec.ts` (P1–P5) | 5 | Có |
| `readonly/smoke.spec.ts` (S1–S3) | 14 | Skip (cần tài khoản) |
| `readonly/reports.spec.ts` (R1–R5) | 5 | Skip (cần tài khoản) |
| `readonly/mobile-pwa.spec.ts` (M1–M5) | 5 | Skip (cần tài khoản) |
| `write/01-procurement.spec.ts` (W1–W4) | 4 | Skip (cần property test) |
| `write/02-receiving.spec.ts` (W5–W6) | 2 | Skip (cần property test) |
| `write/03-finance.spec.ts` (W7–W10) | 4 | Skip (cần property test) |
| `write/04-admin-create-user-multirole.spec.ts` (W11) | 1 | Skip (cần tài khoản quản trị) |

Tổng: 16 Vitest + 45 Playwright (5 public chạy được trên VM).

### W11 — tạo tài khoản đa vai trò (ngoại lệ tầng ghi)

W11 hồi quy cho vụ owner 10/11 (tạo tài khoản tick đủ 17 vai trò nhưng
DB chỉ có 1 dòng `sys_admin`). Khác 3 file ghi còn lại, W11 **không cần
property test** (tạo tài khoản là phạm vi chuỗi) — cần:

```bash
TEST_WRITE_ENABLED=1 \
TEST_ADMIN_EMAIL=<tài khoản có admin.users.manage> TEST_ADMIN_PASSWORD=<mật khẩu> \
pnpm e2e --project=write tests/e2e/write/04-admin-create-user-multirole.spec.ts
```

Tác dụng phụ: mỗi lần chạy tạo 1 tài khoản auth thật với email duy nhất
(`e2e-multirole-<timestamp>@example.com`, 2 vai trò purchaser +
storekeeper, phạm vi toàn chuỗi). Không có chức năng xóa tài khoản nên
tài khoản này ở lại trong auth (giống TEST01–TEST05 Duy tạo tay).
Chỉ chạy khi `TEST_WRITE_ENABLED=1`.

## Dữ liệu mẫu (fixture)

`tests/e2e/fixtures/real-data.ts` lấy số liệu thật từ 4 file Excel của Duy
(`~/workspace/user/files/`, chỉ đọc): mã vật tư `NVL0388`/`NVL0152`/
`NVL0561`/`NVL0559`/`NVL0387`, định lượng món "Rau muống trộn tôm thịt",
minibar ngày 01/10/2018 và 03/10/2018 (Larue/Tiger/Coca), amenities
ngày 09/05/2019 (31 phòng). Vitest U9–U13 khóa các bất biến
(tồn = đầu kỳ + nhập − xuất) để fixture không bị gõ sai số.

## Kịch bản 11-TESTING.md — đối chiếu

Các ca bắt buộc ở §2 (sổ cái/giá vốn), §3 (nhận hàng mù), §4 (minibar),
§5 (kiểm kê), §6 (phân quyền động) là **ca pgTAP** (chạy bằng JWT giả
trên CSDL) — đã có bộ test riêng từng task (T-023 đạt 87/87; còn lại
chưa chạy, xem MEMORY). Playwright không thay thế chúng mà chỉ kiểm
chứng tầng UI:

| Ca 11-TESTING.md | Playwright | Ghi chú |
|---|---|---|
| §2 sổ cái/giá vốn | W6 (tồn tăng đúng), W9 (thẻ kho) | Số học giá vốn do pgTAP kiểm |
| §3 nhận hàng mù | W5 (UI không lộ giá; cân gross/tare; clientUuid chống trùng ở U2) | §3.1–3.2 (RLS) do pgTAP kiểm |
| §4 minibar | W10 (màn hình mở được) + fixture U9–U10 | Luồng đầy đủ cần phòng + giá — kiểm tay |
| §5 kiểm kê | W10 (form mở đợt mở được) + U5 (queue đếm) | Đếm mù end-to-end — kiểm tay |
| §6 phân quyền động | W3 (SoD: người tạo không tự duyệt) | Còn lại do pgTAP kiểm |

## Mobile (W5) — màn hiện trường /m/*, viewport 390px

| File | Số test | Tầng | Chạy trên VM? |
|---|---|---|---|
| `tests/unit/mobile-fixtures.test.ts` (U17–U25) | 9 | Đơn vị | Có |
| `tests/e2e/mobile/00-local.spec.ts` (L1–L5, L3b) | 6 | LOCAL | Có (local build) |
| `tests/e2e/mobile/01-shell.spec.ts` (M-S1–M-S4) | 4 | LIVE-DATA | Không — chạy trên máy Mac sau khi seed xong |
| `tests/e2e/mobile/02-receive.spec.ts` (M-R1–M-R3) | 3 | LIVE-DATA | Không |
| `tests/e2e/mobile/03-count.spec.ts` (M-C1–M-C3) | 3 | LIVE-DATA | Không |
| `tests/e2e/mobile/04-trolley.spec.ts` (M-T1–M-T3) | 3 | LIVE-DATA | Không |
| `tests/e2e/mobile/05-minibar.spec.ts` (M-B1–M-B3) | 3 | LIVE-DATA | Không |
| `tests/e2e/mobile/06-restaurant.spec.ts` (M-K-*) | 5 | LIVE-DATA | Không (route W4 — xem Q198) |

Tổng W5: 9 Vitest + 27 Playwright (6 LOCAL chạy được trên VM, 21 LIVE-DATA
viết-chưa-chạy, chờ seed xong + máy Mac).

### Tầng LOCAL — chạy trên VM

```bash
# 1. Cài deps trong worktree (lần đầu)
npx -y pnpm@12.14.0 install
# 2. Build + chạy local với env giả (không cần Supabase thật)
NEXT_PUBLIC_SUPABASE_URL=https://dummy.supabase.co \
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=dummy-publishable-key \
  npx -y pnpm@12.14.0 build
NEXT_PUBLIC_SUPABASE_URL=https://dummy.supabase.co \
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=dummy-publishable-key \
  npx -y pnpm@12.14.0 start -p 3000
# 3. Chạy tầng LOCAL (tab terminal khác)
TEST_BASE_URL=http://localhost:3000 \
PLAYWRIGHT_CHROME_PATH=/home/hatch/workspace/.chrome-tmp/chrome-linux64/chrome \
  npx playwright test --project=mobile-local
```

> Lưu ý VM: `NEXT_PUBLIC_*` được inline lúc **build**, không đọc lại lúc
> `start`. Trên VM, `https://dummy.supabase.co` bị treo qua egress proxy
> (`NODE_USE_ENV_PROXY=1`): mỗi request `/m/*` kẹt >120s ở `getUser()`
> nên L3 timeout. Build lại bằng URL fail-nhanh
> `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:1` (connection refused
> ngay) thì mỗi navigation còn ~7s và L3 pass — hành vi kiểm tra
> (redirect về `/login` khi chưa đăng nhập) không đổi. Trên máy Mac
> dùng `dummy.supabase.co` như trên (DNS fail nhanh, không treo).

Tầng LOCAL không đăng nhập, không cần dữ liệu: form đăng nhập ở 390px,
meta viewport, redirect `/m/*` → `/login` khi chưa đăng nhập, trang
`/offline`, kích thước chạm tối thiểu.

### Tầng LIVE-DATA — chỉ chạy trên máy Mac, sau khi seed xong

Điều kiện tiên quyết (đủ 3 mới chạy):

1. Seed mẫu `docs/sample-data/seed-sample-data.sql` đã chạy xong toàn bộ
   (§0–§7, kiểm chứng §7 đạt) — điều phối viên báo riêng.
2. `TEST_PROPERTY_ID` = id property TEST47
   (`b0000000-0000-4000-8000-000000000002`).
3. `TEST_USER_EMAIL` / `TEST_USER_PASSWORD` = tài khoản TEST02
   (outlet_head + receiver trên TEST47).

```bash
# Trên máy Mac, tại thư mục repo (branch feat/mobile-tests đã merge)
TEST_BASE_URL=https://erphotel.vercel.app \
TEST_PROPERTY_ID=b0000000-0000-4000-8000-000000000002 \
TEST_USER_EMAIL=<email TEST02> TEST_USER_PASSWORD=<mật khẩu TEST02> \
  npx playwright test --project=mobile-live
```

Lưu ý:

- Seed mẫu đã chạy xong 10/11 21:29, kiểm chứng §7 khớp kỳ vọng: 668 items
  (TP 409, CCDC 235, MB 7, AMN 11, CPM 1, KHAC 5), `stock_moves` = 0,
  uoms 33. Ba điểm bắt buộc khi đọc fixture:
  - NVL0388/NVL0561 đã kiểm chứng Dashboard 10/11 21:34: cả 2 món hiện
    đúng là món nhóm TP của SONHOIAN (external_codes buffet stt 1 và 3),
    tổng org 668, không trùng mã ở org khác; nhóm test T047 còn tồn tại
    nhưng trống. Fixture được dùng cả theo mã lẫn nhóm TP (test U23 khóa
    nhóm TP + stt trong seed §3a).
  - `minibar_price_list` có 7 dòng nhưng đều hết hạn 2019 → 0 giá hiện
    hành; giá trong fixture chỉ là lịch sử, không dùng làm giá bán 2026.
  - `room_setup_standards` và `trolley_par_levels` đều 0 dòng (khối §5
    dùng cột `min_qty` không tồn tại, khối §6 thiếu
    `trolley_warehouse_id` NOT NULL) — không fixture nào giả định có
    dữ liệu ở 2 bảng này.
- Test tự skip (không fail) khi chưa đủ dữ liệu: chưa có PO đến hạn
  (M-R3), chưa có đợt kiểm kê (M-C3), chưa có ca xe đẩy (M-T3), chưa có
  phòng chờ kiểm minibar (M-B2/M-B3 — cần tạo phòng + setup, Q153),
  route nhà hàng W4 chưa có (M-K-*, Q198), món MON01 chưa import (Q168).
- Spec không mở đợt/ca/phiếu thật — chỉ mở form, không gửi (mở đợt/ca
  thật là thao tác ghi, sinh chứng từ).
- Fixture lấy từ dữ liệu thật: `tests/e2e/fixtures/mobile-real-data.ts`
  (7 món minibar + giá §4, 12 món amenities §3e, MON01, TEST47).
  Nguồn từng giá trị ghi trong file fixture; Vitest U17–U24 khóa lại.

## Chỉ kiểm tay (không tự động hóa được)

- Chụp ảnh nhận hàng bằng camera điện thoại thật.
- Ký xác nhận khi NCC lấy hàng trả.
- Cài PWA lên màn hình chính (InstallPrompt) + nhận push thật.
- Nhận hàng offline trên điện thoại thật (tắt mạng thật, ghi dòng, bật
  lại mạng, đối chiếu đồng bộ).
- Đếm mù end-to-end với 2 người đếm + PIN từng người.
- Bản tin 8h gửi thật qua email/push (Edge Function + cron).
- Đối chiếu số báo cáo với truy vấn SQL độc lập (pgTAP T-044 đã có).
