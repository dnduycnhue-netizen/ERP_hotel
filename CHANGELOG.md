# CHANGELOG

Ghi theo task. Mỗi dòng: ngày — mã task — agent — tóm tắt.

## [Chưa phát hành]
- 2026-11-08 — DOCS — Khởi tạo bộ tài liệu phát triển (AGENTS.md, docs/01–13, modules, ADR-001).
- 2026-11-08 — DOCS — Chuyển sang phân quyền động: vai trò/quyền cấu hình trên giao diện (ma trận tích chọn, phạm vi KS/bộ phận/kho, thời hạn, quyền riêng cho/chặn), `has_perm`/`require_perm`/`my_permissions`, rào chắn tự cấp quyền, RPC `admin_*`, task T-005b.
- 2026-11-08 — T-001 (đang triển khai) — Copilot SDK — Dựng Next.js 16 + TypeScript strict, Tailwind/shadcn, Supabase CLI và CI; lint, typecheck, format, build và dev smoke test đạt. Chưa xác nhận `supabase start` vì Docker daemon không chạy trong môi trường.
- 2026-11-08 — T-001 (đang triển khai) — Copilot SDK — Thêm Supabase SSR browser/server client và proxy làm mới session; cấu hình URL + publishable key local và Vercel (Production/Preview/Development), xác nhận Auth hoạt động và Data API nhận key. Production deploy qua CLI trạng thái Ready tại `https://erphotel.vercel.app`; tự động deploy theo Git còn chờ quyền Vercel GitHub App cho repo tổ chức.
- 2026-11-08 — T-001 — Copilot SDK — Cập nhật GitHub Actions lên runtime Node.js 24 và runner Ubuntu 24.04 cố định.
- 2026-11-08 — Vercel — Chủ project xác nhận đã xóa hai automation bypass credentials được tạo trong lần kiểm thử deploy; Deployment Protection/SSO tiếp tục bật.
- 2026-11-08 — T-002 — Copilot SDK — Áp hai migration tiện ích/audit và tổ chức/phân quyền lên Supabase production; sinh `src/lib/database.types.ts` từ schema remote. 30 assertion pgTAP chạy qua Supabase SQL query API trong transaction, tất cả đạt; xác nhận fixture và extension đã rollback. Seed dữ liệu mẫu giữ cho local, không đưa vào production.
- 2026-11-08 — T-002 — Copilot SDK — Deploy production lên Vercel (`dpl_Eci578a9ciwM4qkTxL6QURX1wm48`), trạng thái Ready; alias production trả HTTP 200.
- 2026-11-08 — T-003 — Copilot SDK — Thêm đăng nhập email/mật khẩu và đăng xuất qua Supabase Auth; bảo vệ route bằng proxy và kiểm tra lại trong server components/actions; chỉ cho phép khách sạn từ `my_property_ids()`, lưu lựa chọn cuối bằng cookie HttpOnly; bổ sung trạng thái tài khoản, lỗi và 404 bằng tiếng Việt.
- 2026-11-08 — Bootstrap — Copilot SDK — Thêm quy trình khởi tạo production một lần, vai trò kiểm thử không có quyền quản trị/critical, callback lời mời và đặt mật khẩu ban đầu; migration đã áp dụng, 22 assertion pgTAP transactional đạt, types đã sinh lại. Deploy production Ready tại `https://erphotel.vercel.app`, callback smoke test trả HTTP 200. Gửi lời mời gặp `over_email_send_rate_limit`; function đã rollback, xác minh production còn 0 tổ chức/Auth user, đồng thời xóa secret/endpoint tạm. Cần nâng giới hạn email hoặc cấu hình SMTP riêng trước khi thử lại.
