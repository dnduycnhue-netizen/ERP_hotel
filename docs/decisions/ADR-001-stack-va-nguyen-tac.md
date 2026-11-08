# ADR-001 — Stack và nguyên tắc ghi sổ

- Ngày: 2026-11-08
- Trạng thái: Chấp nhận

## Bối cảnh
Đội nhỏ, phát triển bằng nhiều AI agent, chạy trên Vercel + Supabase. Phần mềm quản lý tiền và tồn kho, mục tiêu chính là chống gian lận.

## Quyết định
1. Next.js App Router + Supabase; **không** thêm backend riêng (Laravel/Express).
2. Logic có hậu quả tiền/tồn kho nằm trong hàm Postgres `security definer`, gọi qua RPC.
3. Sổ cái `stock_moves`, `ap_ledger`, `audit_log` chỉ INSERT; sửa bằng bút toán đảo.
4. Giá vốn bình quân gia quyền tức thời theo pháp nhân (đổi được theo cấu hình đầu năm tài chính).
5. MVP chạy độc lập, xuất Excel cho kế toán; kết nối MISA/Bravo ở P3 qua adapter.
6. Offline chỉ cho 4 màn hình hiện trường, đồng bộ idempotent bằng `client_uuid`.

## Hệ quả
- Agent phải viết nhiều SQL/pgTAP; Claude Code đảm nhận phần này.
- Logic không bị phân tán giữa TypeScript và SQL → dễ kiểm toán.
- Postgres trở thành điểm tập trung: cần test kỹ và migration có kỷ luật.
