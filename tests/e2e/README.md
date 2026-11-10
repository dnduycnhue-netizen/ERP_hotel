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

## Chỉ kiểm tay (không tự động hóa được)

- Chụp ảnh nhận hàng bằng camera điện thoại thật.
- Ký xác nhận khi NCC lấy hàng trả.
- Cài PWA lên màn hình chính (InstallPrompt) + nhận push thật.
- Nhận hàng offline trên điện thoại thật (tắt mạng thật, ghi dòng, bật
  lại mạng, đối chiếu đồng bộ).
- Đếm mù end-to-end với 2 người đếm + PIN từng người.
- Bản tin 8h gửi thật qua email/push (Edge Function + cron).
- Đối chiếu số báo cáo với truy vấn SQL độc lập (pgTAP T-044 đã có).
