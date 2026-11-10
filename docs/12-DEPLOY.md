# 12 — Triển khai Vercel + Supabase

## 1. Môi trường

| Môi trường | Supabase project | Vercel | Nhánh git |
|---|---|---|---|
| Local | `supabase start` (Docker) | `pnpm dev` | bất kỳ |
| Staging | `mini-erp-staging` (region Singapore) | Preview deployments | `develop` + nhánh PR |
| Production | `mini-erp-prod` (region Singapore) | Production | `main` |

Gói Supabase: Free đủ cho dev; **production nên dùng gói trả phí** để có sao lưu hằng ngày, không bị tạm dừng khi ít truy cập, và tùy chọn PITR. Free tier chỉ dùng cho giai đoạn thử.

## 2. Biến môi trường

| Biến | Nơi | Ghi chú |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Vercel (all) | |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Vercel (all) | Khóa công khai (publishable/anon — tùy loại khóa của project) |
| `SUPABASE_SECRET_KEY` | Vercel (server only) | Khóa secret/service role — chỉ dùng trong `/api/cron`, `/api/import`, `/api/export` |
| `CRON_SECRET` | Vercel | Header `Authorization: Bearer` cho route cron |
| `RESEND_API_KEY` (hoặc SMTP) | Supabase secrets | Gửi email |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Vercel + Supabase secrets | Web push |
| `ZALO_OA_*` | Supabase secrets | Khi có OA |

Tạo `.env.example` liệt kê đủ biến, không có giá trị thật.

## 3. Quy trình đưa schema lên

```bash
supabase link --project-ref <staging-ref>
supabase db push            # chạy migration chưa áp dụng
supabase functions deploy send-notifications
supabase functions deploy admin-create-user
```
- GitHub Action trên `develop`: lint, typecheck, test, `supabase db reset` + `supabase test db` ở CI (Docker), sau đó `supabase db push` lên staging.
- Production: chạy tay sau khi staging nghiệm thu; **sao lưu trước khi push**.
- Không sửa schema trực tiếp trên Studio production. Thay đổi phát hiện bằng `supabase db diff` phải chuyển thành migration.

## 4. Cron

- DB job: bật extension `pg_cron`, `pg_net` trong Dashboard; job định nghĩa trong migration 14 (giờ UTC).
- Nếu cần Vercel Cron cho route Next.js: `vercel.json` → `crons`, route kiểm `CRON_SECRET`.

## 5. Tên miền & PWA

- Gắn domain (vd. `erp.<ten-chuoi>.vn`) trên Vercel; HTTPS bắt buộc cho camera và service worker.
- Supabase Auth → URL Configuration: thêm domain production + preview vào Redirect URLs.
- PWA (T-046, service worker viết tay `public/sw.js`, không dùng thư viện):
  - Sau mỗi deploy, service worker mới tự kích hoạt (`skipWaiting`) và xóa cache cũ theo `CACHE_VERSION` — khi đổi app shell/manifest thì tăng `CACHE_VERSION` trong `public/sw.js`.
  - Nút "Bật thông báo" ở màn lịch sử cảnh báo chỉ hoạt động khi Vercel có biến `NEXT_PUBLIC_VAPID_PUBLIC_KEY` (khóa công khai; khóa bí mật `VAPID_PRIVATE_KEY` chỉ nằm trong Supabase secrets cho Edge Function). Chưa có khóa thì nút hiện ghi chú, không lỗi.
  - iOS: cài thủ công qua Share → Thêm vào MH chính; web push trên iOS chỉ hoạt động khi app đã thêm vào MH chính (iOS 16.4+).

## 6. Vận hành

- Theo dõi: Supabase Logs (Postgres, Edge Functions), Vercel Logs. Lỗi RPC có mã `ERR_*` ghi rõ.
- Sao lưu thêm: xuất `pg_dump` hằng tuần về storage riêng của khách.
- Kiểm tra bảo mật trước khi go-live: chạy Security Advisor của Supabase (cảnh báo bảng thiếu RLS, hàm `security definer` thiếu `search_path`).
