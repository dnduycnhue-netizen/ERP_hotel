# Cấu hình sender thông báo T-045 (Resend + Web Push + Zalo)

> **Trạng thái:** Hướng dẫn chuẩn bị cho Q98/Q99. Chưa cấu hình được —
> thiếu key/secret của Duy. Tài liệu này liệt kê CHÍNH XÁC cái gì cần,
> nhập vào đâu, và kiểm chứng ra sao. Không chứa key/secret thật nào.
> Nguồn: `supabase/functions/send-notification/index.ts`,
> migration 380000, `docs/OPEN-QUESTIONS.md` Q94–Q102.

## 0. Hiện trạng (đã có, không cần làm lại)

- Edge Function `send-notification` đã deploy; 3 cron đã chạy đúng lịch
  trên production (kiểm chứng 10/11): `notification-build-daily`
  (00:30 UTC = 07:30 VN, xây bản tin), `notification-digest-daily`
  (01:00 UTC = 08:00 VN, gửi bản tin 8h), `notification-worker-5min`
  (worker gửi, mỗi 5 phút).
- Bảng `notification_sender_config`, `notification_targets`,
  `push_subscriptions`, `notification_deliveries` đã có (migration 380000).
- Luồng gửi: worker trong DB đọc `notification_sender_config` →
  lấy secret từ Vault (`_notification_vault_secret`) → gọi Edge Function
  qua `pg_net` (`_notification_http_post`) với header
  `x-notification-secret` → Edge Function gửi qua Resend (email) /
  web-push (VAPID) / Zalo (stub).
- Giờ im lặng 23:00–06:00 giờ VN (`_notification_is_quiet`): alert tạo
  trong giờ này bị hoãn gửi, worker gửi lại sau 06:00.

## 1. Duy cần cung cấp gì (4 + 1 mục)

| # | Thứ cần | Dùng cho | Lấy ở đâu |
|---|---|---|---|
| 1 | **Resend API key** (`re_...`) | Gửi email qua Resend | [resend.com/api-keys](https://resend.com/api-keys) — tạo key mới cho project ERP_hotel, quyền gửi mail (Sending access). **Không dán key vào chat/file.** |
| 2 | **Địa chỉ email gửi** (`NOTIFICATION_FROM_EMAIL`) | Địa chỉ `from` của email thông báo | Một địa chỉ/domain đã verify trên Resend (vd. `thongbao@<domain-của-khách-sạn>`). [CẦN XÁC NHẬN: Duy chốt domain/email gửi] |
| 3 | **VAPID public key + private key** | Web push (trình duyệt) | Sinh 1 cặp mới bằng `npx web-push generate-vapid-keys` hoặc trang [vapidkeys.com](https://vapidkeys.com) (chỉ dùng để sinh, không lưu key ở đó). Giữ private key như mật khẩu |
| 4 | **VAPID subject** (`VAPID_SUBJECT`) | Định danh người gửi push (chuẩn Web Push) | Một `mailto:` (vd. `mailto:thongbao@<domain>`) hoặc URL `https://erphotel.vercel.app`. [CẦN XÁC NHẬN: Duy chốt 1 trong 2] |
| 5 | **Vault shared secret** (chuỗi ngẫu nhiên dài) | Khóa chung giữa DB và Edge Function (header `x-notification-secret`) | Tự sinh 1 chuỗi ngẫu nhiên dài (vd. 32 ký tự trở lên bằng lệnh `openssl rand -hex 32`). Giá trị này phải GIỐNG NHAU ở 2 chỗ: Vault (§2 bước 1) và biến môi trường Edge Function (§2 bước 2) |
| — | **Zalo OA credentials** (chỉ nếu muốn gửi Zalo) | Gửi qua Zalo | Zalo OA access token + ZNS template đã được duyệt (xem Q98). **Hiện tại Zalo là stub 501 — chưa gửi được dù có cấu hình xong 4 mục trên.** Zalo làm riêng sau |

> Q99 (ai giữ VAPID keys + ai tạo Resend key) chưa chốt — mặc định: Duy
> (chủ tài khoản) tạo và giữ; agent chỉ hướng dẫn nhập, không giữ bản sao.

## 2. Các bước cấu hình (thứ tự bắt buộc)

### Bước 1 — Tạo secret trong Vault (SQL Editor, quyền postgres)

Chạy trên Supabase Dashboard → SQL Editor (project ERP_hotel):

```sql
select vault.create_secret('<CHUỖI-SHARED-SECRET-Ở-MỤC-5>', 'NOTIFICATION_SHARED_SECRET');
-- Trả về 1 UUID — ghi lại UUID này, dùng ở Bước 3.
```

> Chuỗi secret nhập ở đây phải **giống hệt** giá trị sẽ đặt làm biến môi
> trường `NOTIFICATION_SHARED_SECRET` ở Bước 2. Lệch 1 ký tự là Edge
> Function trả 401, worker ghi lỗi
> `ERR_NOTIFICATION_SENDER_UNAVAILABLE`.

### Bước 2 — Đặt biến môi trường cho Edge Function

Dashboard → Edge Functions → `send-notification` → Secrets (hoặc CLI
trên máy Duy: `npx -y supabase secrets set ... --remote` trong thư mục repo
đã link project):

| Biến | Giá trị |
|---|---|
| `RESEND_API_KEY` | key Resend ở mục 1 |
| `NOTIFICATION_FROM_EMAIL` | email gửi ở mục 2 |
| `VAPID_PUBLIC_KEY` | public key VAPID ở mục 3 |
| `VAPID_PRIVATE_KEY` | private key VAPID ở mục 3 |
| `VAPID_SUBJECT` | subject ở mục 4 |
| `NOTIFICATION_SHARED_SECRET` | **giống hệt** chuỗi đã tạo ở Bước 1 |

Xong thì deploy lại Edge Function (nếu đổi secret sau deploy):

```bash
npx -y supabase functions deploy send-notification --remote
```

### Bước 3 — Ghi 1 dòng `notification_sender_config` (SQL Editor)

Bảng này **không có policy ghi** — chỉ admin SQL (postgres) ghi được
(migration 380000:338). Chạy 1 lần cho org SONHOIAN:

```sql
insert into public.notification_sender_config
  (org_id, sender_url, vault_secret_id,
   email_enabled, webpush_enabled, zalo_enabled)
values (
  '00dc6aeb-5e34-4e01-9b80-032a72b16d71',
  'https://ufxcjfntesafmqzsjsyr.supabase.co/functions/v1/send-notification',
  '<UUID-VAULT-SECRET-Ở-BƯỚC-1>',
  true,   -- email: bật sau khi Resend đã verify (mục 2)
  true,   -- webpush: bật sau khi VAPID đã có (mục 3)
  false   -- zalo: LUÔN false cho tới khi Zalo OA + ZNS xong (stub 501)
)
on conflict (org_id) do update set
  sender_url = excluded.sender_url,
  vault_secret_id = excluded.vault_secret_id,
  email_enabled = excluded.email_enabled,
  webpush_enabled = excluded.webpush_enabled,
  zalo_enabled = excluded.zalo_enabled;
```

> Nếu chỉ muốn bật email trước, push sau (hay ngược lại) thì đặt cờ
> tương ứng `false` rồi bật sau — không cần chạy lại Bước 1–2.

### Bước 4 — Bật đăng ký nhận push trên trình duyệt (mỗi người dùng)

- Mở app → màn `/[property]/alerts` → bật nút web push
  (`PushSubscriptionToggle`). Trình duyệt hỏi quyền Notifications → cho phép.
- Kiểm tra: 1 dòng mới trong `push_subscriptions` cho user đó
  (xem §3 câu 3.3).

## 3. Checklist kiểm chứng sau khi cấu hình

Chạy trên SQL Editor (chỉ đọc), theo thứ tự:

```sql
-- 3.1 Cấu hình đã đủ chưa?
select org_id, sender_url,
       (vault_secret_id is not null) as co_secret,
       email_enabled, webpush_enabled, zalo_enabled
from public.notification_sender_config
where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71';
-- Kỳ vọng: 1 dòng, co_secret = true, email/webpush theo ý muốn, zalo = false.

-- 3.2 Vault đọc được secret không?
select public._notification_vault_secret(
  (select vault_secret_id from public.notification_sender_config
   where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71')
) is not null as doc_duoc_secret;
-- Kỳ vọng: true. false = Vault chưa bật / sai UUID / sai quyền.

-- 3.3 Có người đăng ký push chưa?
select count(*) as so_dang_ky_push from public.push_subscriptions;
```

**Gửi thử:**

1. **Email thử:** tạo 1 alert test (vd. từ màn Alerts, hoặc đợi 1 alert
   thật phát sinh — vd. tạm ứng quá hạn). Trong vòng 5 phút (worker
   `*/5`), kiểm tra:
   ```sql
   select channel, status, error_message, created_at
   from public.notification_deliveries
   order by created_at desc limit 10;
   ```
   Kỳ vọng: 1 dòng `channel='email'`, `status='sent'` (hoặc giá trị
   tương đương theo code worker — xem cột `status` thực tế rồi đối chiếu).
   Nhận được email trong hộp thư đến thì xong.
2. **Push thử:** cùng cách trên với 1 user đã bật push ở Bước 4.
   Kỳ vọng: trình duyệt nhận được push (tiêu đề + nội dung alert).
3. **Bản tin 8h:** đợi tới 08:00 hôm sau (digest 01:00 UTC), kiểm tra
   `notification_deliveries` có dòng bản tin ngày + email/push đã nhận.
   Nếu không thấy: kiểm tra cron `notification-digest-daily` và
   `notification-build-daily` còn chạy không (`select * from cron.job`).

## 4. Lỗi thường gặp

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `notification_deliveries` có dòng lỗi `ERR_NOTIFICATION_SENDER_UNAVAILABLE` | Chưa có `sender_url` / Vault secret / `pg_net` | Làm lại §2 Bước 1–3; kiểm tra §3.1–3.2 |
| Edge Function log báo `send_notification_unavailable` (503) | Chưa đặt biến `NOTIFICATION_SHARED_SECRET` trên Edge Function | Đặt biến (§2 Bước 2) + deploy lại |
| Edge Function log báo `unauthorized` (401) | Shared secret ở Vault ≠ biến môi trường EF | Đặt lại 1 trong 2 cho giống hệt nhau |
| Email lỗi `email_not_configured` (503) | Chưa đặt `RESEND_API_KEY` / `NOTIFICATION_FROM_EMAIL` | Đặt 2 biến + deploy lại; kiểm tra domain đã verify trên Resend |
| Push lỗi `webpush_not_configured` | Chưa đặt đủ 3 biến VAPID | Đặt đủ `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` |
| Push lỗi `410/404` trong log | Subscription hết hạn / user gỡ quyền | User bật lại push ở màn Alerts (Bước 4) |
| Zalo trả `501 zalo_not_configured` | Zalo chưa làm (stub) | Đúng như thiết kế — Zalo làm riêng sau khi có OA + ZNS (Q98) |
| Không nhận gì dù `deliveries` báo sent | Email vào spam / trình duyệt chặn notification | Kiểm tra spam; kiểm tra quyền Notifications của trình duyệt |

## 5. Ghi chú bảo mật

- **Không bao giờ** dán Resend key / VAPID private key / shared secret
  vào chat, file docs, hay commit lên GitHub. Chỉ nhập qua Dashboard
  (Vault, Edge Function Secrets) hoặc CLI trên máy Duy.
- Xoay (rotate) key ngay nếu nghi lộ: tạo key mới trên Resend → cập nhật
  biến môi trường → deploy lại; tạo shared secret mới → cập nhật cả Vault
  (§2 Bước 1) và EF (§2 Bước 2) cùng lúc.
- `notification_sender_config` **không chứa secret** — chỉ chứa URL công
  khai + UUID của secret trong Vault + cờ bật kênh (migration 380000:338).
