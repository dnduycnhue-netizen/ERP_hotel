# ADR-002 — Kết nối Supabase từ Next.js

- Ngày: 2026-11-08
- Trạng thái: Chấp nhận

## Bối cảnh

Ứng dụng dùng Supabase Auth qua cookie session trong Next.js App Router. Publishable key được phép ở trình duyệt; secret/service-role key chỉ dành cho xử lý server được bảo vệ và không thuộc cấu hình client.

## Quyết định

1. Dùng `@supabase/ssr` cùng `@supabase/supabase-js` để tạo client riêng cho browser và server.
2. Server client đọc/ghi session qua cookie của Next.js; browser client chỉ dùng URL và publishable key.
3. Biến `NEXT_PUBLIC_SUPABASE_URL` và `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` có thể được đặt ở local/Vercel. Không bao giờ đưa `SUPABASE_SECRET_KEY` vào client hoặc commit.
4. Không ghi khóa bí mật vào Git, log, mã nguồn hoặc chat. Khóa bị lộ phải được thu hồi và thay mới tại Supabase.

## Hệ quả

- Dữ liệu nghiệp vụ vẫn phải được bảo vệ bằng RLS và RPC; publishable key không thay thế phân quyền cơ sở dữ liệu.
- Các tính năng Auth và dữ liệu được bổ sung theo thứ tự task trong roadmap.
