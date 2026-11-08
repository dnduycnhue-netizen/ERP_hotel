# Mini-ERP Chuỗi khách sạn — Bộ tài liệu phát triển

Bộ tài liệu này là **nguồn sự thật** để các AI agent (Claude Code, Antigravity, Muse) viết code. Code phải khớp tài liệu; khi đổi hành vi thì sửa tài liệu trước.

## Danh mục tài liệu

| File | Nội dung | Ai đọc |
|---|---|---|
| `AGENTS.md` | Quy tắc bắt buộc, stack, cấu trúc thư mục, Definition of Done | Mọi agent, luôn luôn |
| `CLAUDE.md` | Phần riêng cho Claude Code (import AGENTS.md) | Claude Code |
| `docs/01-PRD.md` | Bài toán, người dùng, phạm vi MVP / P2 / P3 | Mọi agent |
| `docs/02-ARCHITECTURE.md` | Kiến trúc Vercel + Supabase, đa pháp nhân, offline, job định kỳ | Mọi agent |
| `docs/03-DATA-MODEL.md` | Bảng, cột, quan hệ, SQL lõi (sổ cái, giá vốn, đánh số chứng từ) | Backend |
| `docs/04-SECURITY-RLS.md` | Vai trò, RLS, tách biệt nhiệm vụ (SoD), cơ chế "mù" | Backend |
| `docs/05-BUSINESS-RULES.md` | Công thức, ngưỡng, trạng thái chứng từ, quy tắc hạch toán | Mọi agent |
| `docs/06-UI-UX.md` | Sơ đồ màn hình, màn hình mobile hiện trường, quy ước giao diện | Frontend |
| `docs/07-IMPORT-MIGRATION.md` | Nhập dữ liệu từ Excel hiện tại, làm sạch, mẫu file | Backend |
| `docs/08-REPORTS-ALERTS.md` | Báo cáo, cảnh báo, Flash 8h | Mọi agent |
| `docs/09-API-RPC.md` | Danh sách RPC, tham số, mã lỗi | Mọi agent |
| `docs/10-ROADMAP-TASKS.md` | Task chia nhỏ theo giai đoạn, tiêu chí nghiệm thu | Mọi agent |
| `docs/11-TESTING.md` | Chiến lược test, ca test bắt buộc, dữ liệu mẫu | Mọi agent |
| `docs/12-DEPLOY.md` | Môi trường, biến môi trường, quy trình đưa lên Vercel/Supabase | Người triển khai |
| `docs/13-AI-WORKFLOW.md` | Cách phối hợp Antigravity + Muse + Claude Code | dnduy |
| `docs/modules/*.md` | Đặc tả chi tiết từng phân hệ MVP | Agent làm module đó |
| `docs/GLOSSARY.md` | Thuật ngữ Việt – Anh – mã trong code | Mọi agent |
| `docs/OPEN-QUESTIONS.md` | Câu hỏi còn chờ khách chốt | dnduy |
| `docs/decisions/` | ADR — quyết định kiến trúc | Mọi agent |

## Bắt đầu nhanh

1. Tạo repo, chép toàn bộ thư mục này vào gốc repo.
2. Giao Task `T-001` trong `docs/10-ROADMAP-TASKS.md` cho Claude Code (khởi tạo dự án + Supabase local).
3. Làm lần lượt theo roadmap; mỗi task một nhánh `task/T-xxx-ten-ngan`.
# ERP_hotel
