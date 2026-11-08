# 02 — Kiến trúc kỹ thuật

## 1. Tổng quan

```
Trình duyệt / PWA điện thoại
   │  (HTTPS, cookie session @supabase/ssr)
   ▼
Next.js trên Vercel ──── Server Components / Server Actions ───┐
   │   /api/cron/*  (Vercel Cron, CRON_SECRET)                 │
   │   /api/import/* (đọc Excel/CSV, service role)             │
   │   /api/export/* (sinh Excel bằng exceljs)                 │
   ▼                                                           ▼
Supabase ── Auth ── Postgres (RLS + RPC SECURITY DEFINER) ── Storage (ảnh, file)
              │          │ pg_cron: tính báo cáo, sinh lịch hợp đồng, nhắc quá hạn
              │          │ pg_net: gọi Edge Function gửi thông báo
              └── Edge Functions (Deno): send-notifications, (sau này) misa-adapter, bravo-adapter
```

Nguyên tắc: **Postgres là nơi duy nhất chứa logic nghiệp vụ có hậu quả tiền/tồn kho.** Next.js chỉ hiển thị, validate sơ bộ bằng Zod, gọi RPC.

## 2. Phân tầng dữ liệu

| Tầng | Đối tượng | Ghi bởi |
|---|---|---|
| Danh mục | `items`, `suppliers`, `warehouses`, `recipes`… | Form CRUD (RLS theo vai trò) |
| Chứng từ | `purchase_orders`, `goods_receipts`, `requisitions`, `stock_counts`… | Form ở trạng thái `draft`; chuyển trạng thái chỉ qua RPC |
| Sổ cái | `stock_moves`, `ap_ledger` | **Chỉ RPC post** |
| Số dư | `stock_balances`, `item_costs` | **Chỉ RPC post** (cập nhật cùng giao dịch) |
| Nhật ký | `audit_log`, `attachments` | Trigger / RPC |
| Báo cáo | view, materialized view, bảng `report_snapshots` | `pg_cron` |

## 3. Đa pháp nhân

```
organizations (chuỗi)
 └─ legal_entities (pháp nhân — MST, chế độ kế toán, phương pháp giá xuất kho)
     └─ properties (khách sạn) ── sod_profile: with_cc | without_cc
         ├─ outlets (bếp, bar, buffet, buồng phòng, kỹ thuật… loại do người dùng định nghĩa)
         ├─ warehouses (kho tổng, kho outlet, kho tầng, xe đẩy, minibar từng phòng, kho ảo)
         └─ rooms
```

- Danh mục vật tư, NCC, khoản mục chi phí: cấp `org`.
- Giá vốn bình quân: theo `legal_entity` × `item`.
- Số chứng từ: theo `legal_entity` × loại chứng từ × năm.
- Một người dùng có vai trò theo từng `property` (`user_property_roles`), hoặc toàn chuỗi (`property_id is null`).

## 4. Xác thực

- Supabase Auth, email + mật khẩu, **không cho tự đăng ký**. `sys_admin` tạo tài khoản (qua Edge Function dùng service role).
- Trước khi có `sys_admin` đầu tiên, chỉ Edge Function bootstrap dùng một lần được tạo chuỗi, pháp nhân, khách sạn, hai tài khoản quản trị và tài khoản kiểm thử. RPC bootstrap chỉ cho `service_role`; vai trò kiểm thử không có quyền quản trị hoặc quyền nghiệp vụ mức `critical`.
- Nhân viên không có email: tạo email nội bộ dạng `<ma_nv>@<org>.local` (không gửi thư), đăng nhập bằng mã NV + mật khẩu.
- Phiên làm việc trên điện thoại dùng chung (ví dụ máy nhận hàng ca sáng): bắt buộc **mã PIN 4–6 số theo người** khi ký chứng từ (`profiles.pin_hash`) — để biết ai nhận, ai đếm.

## 5. Offline (giới hạn)

Chỉ 4 màn hình: nhận hàng, kiểm kê, xe đẩy buồng phòng, kiểm minibar.

- Dữ liệu nhập lưu vào IndexedDB (Dexie) với `client_uuid` sinh ở máy.
- Ảnh lưu blob cục bộ, tải lên Storage khi có mạng.
- Khi online: gửi lần lượt qua RPC; RPC dùng `client_uuid` làm khóa **idempotent** (gửi lại không tạo bản ghi trùng).
- Bản ghi offline có cờ `captured_offline = true`, giờ thiết bị lưu ở `device_time`, giờ máy chủ ở `received_at` — báo cáo hậu kiểm hiển thị cả hai.
- **Không** cho offline: duyệt, thanh toán, sửa danh mục, khóa sổ.
- Nhận hàng mù offline không so được với PO (vì máy không có số PO). Kiểm tra dung sai chạy khi đồng bộ; nếu lệch, phiếu chuyển trạng thái `needs_recount` và thông báo người nhận.

## 6. Ảnh chống gian lận

- Chụp trong app bằng `getUserMedia` (không dùng hộp chọn file → chặn ảnh cũ trong thư viện).
- Nén còn ~1280px, JPEG 0.7, tính SHA-256 ở máy, gửi kèm.
- Storage bucket `evidence` **private**; đường dẫn `{legal_entity_id}/{doc_type}/{yyyy}/{mm}/{uuid}.jpg`.
- Bảng `attachments` lưu `sha256`; trùng hash với ảnh cũ → cảnh báo "ảnh dùng lại".
- Xem ảnh bằng signed URL thời hạn ngắn.

## 7. Job định kỳ

| Job | Lịch (giờ VN) | Cơ chế |
|---|---|---|
| Tính báo cáo ngày (Flash, minibar, tạm ứng quá hạn…) | 07:30 hằng ngày | `pg_cron` gọi `report_build_daily()` |
| Gửi bản tin 8h | 08:00 | `pg_cron` + `pg_net` gọi Edge Function `send-notifications` |
| Gửi cảnh báo tức thời | mỗi 5 phút | `pg_cron` + `pg_net` → `send-notifications` (lấy `alerts` chưa gửi) |
| Sinh lịch hợp đồng dịch vụ kỳ tới | 01:00 ngày 1 | `pg_cron` gọi `service_schedule_generate()` |
| Mã tạm quá 24h chưa chuẩn hóa | mỗi giờ | `pg_cron` → tạo alert |

`pg_cron` chạy theo UTC: 08:00 VN = `0 1 * * *`.

## 8. Thông báo — thiết kế adapter

```ts
interface Notifier { send(to: Target, msg: Message): Promise<Result> }
// EmailNotifier (Resend/SMTP) — MVP
// WebPushNotifier — MVP
// ZaloOANotifier — bật khi khách có Zalo OA + template ZNS được duyệt
```
`notification_targets` lưu kênh của từng người. Edge Function `send-notifications` gom cảnh báo cùng KS vào một tin (ZNS tính phí theo tin), tôn trọng giờ im lặng 23h–6h trừ nhóm khẩn.

## 9. Kết nối kế toán (P3) — chuẩn bị từ MVP

- Mọi danh mục có cột `external_codes jsonb` dạng `{"misa": {"<legal_entity_id>": "MA"}, "bravo": {...}}`.
- Mọi chứng từ có `export_status` (`not_exported`, `exported`, `synced`) và `export_batch_id`.
- MVP: `/api/export/*` sinh file Excel theo mẫu import của MISA. P3: Edge Function `misa-adapter`, `bravo-adapter` đọc cùng view `v_export_*`.

## 10. Hiệu năng & quy mô

Ước tính: 8 khách sạn, ~1.500 mã vật tư, ~2.000 dòng `stock_moves`/ngày toàn chuỗi → ~750k dòng/năm. Postgres xử lý thoải mái với index `(warehouse_id, item_id, move_date)`. Báo cáo nặng dùng materialized view refresh bằng cron.
