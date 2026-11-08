# CHANGELOG

Ghi theo task. Mỗi dòng: ngày — mã task — agent — tóm tắt.

## [Chưa phát hành]
- 2026-11-08 — DOCS — Khởi tạo bộ tài liệu phát triển (AGENTS.md, docs/01–13, modules, ADR-001).
- 2026-11-08 — DOCS — Chuyển sang phân quyền động: vai trò/quyền cấu hình trên giao diện (ma trận tích chọn, phạm vi KS/bộ phận/kho, thời hạn, quyền riêng cho/chặn), `has_perm`/`require_perm`/`my_permissions`, rào chắn tự cấp quyền, RPC `admin_*`, task T-005b.
- 2026-11-08 — T-001 (đang triển khai) — Copilot SDK — Dựng Next.js 16 + TypeScript strict, Tailwind/shadcn, Supabase CLI và CI; lint, typecheck, format, build và dev smoke test đạt. Chưa xác nhận `supabase start` vì Docker daemon không chạy trong môi trường.
- 2026-11-08 — T-001 (đang triển khai) — Copilot SDK — Thêm Supabase SSR browser/server client và proxy làm mới session; cấu hình URL + publishable key local và Vercel (Production/Preview/Development), xác nhận Auth hoạt động và Data API nhận key. Production deploy qua CLI trạng thái Ready tại `https://erphotel.vercel.app`; tự động deploy theo Git còn chờ quyền Vercel GitHub App cho repo tổ chức.
- 2026-11-08 — T-001 — Copilot SDK — Cập nhật GitHub Actions lên runtime Node.js 24 để tránh cảnh báo Node.js 20 ngừng hỗ trợ.
- 2026-11-08 — Vercel — Kiểm thử deploy qua CLI tạo automation bypass cho Deployment Protection; chưa thu hồi được do thiếu quyền truy cập trình duyệt Vercel. Chủ project cần xóa bypass credential trong Settings → Deployment Protection sau khi kiểm tra deployment.
