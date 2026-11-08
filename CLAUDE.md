# CLAUDE.md

Quy tắc chung của dự án nằm ở AGENTS.md — đọc và tuân thủ toàn bộ:

@AGENTS.md

## Riêng cho Claude Code

- Trước khi sửa code, đọc file đặc tả liên quan trong `docs/` và task trong `docs/10-ROADMAP-TASKS.md`.
- Mỗi phiên làm **một task** (mã `T-xxx`). Bắt đầu bằng việc nhắc lại tiêu chí nghiệm thu của task.
- Thế mạnh được giao: migration SQL, RLS, hàm RPC, pgTAP, Edge Functions, script import, rà soát code của agent khác.
- Sau migration: `supabase db reset && supabase test db && supabase gen types typescript --local > src/lib/database.types.ts`.
- Không chạy lệnh tác động môi trường production (`supabase db push --linked` vào prod, `vercel --prod`) trừ khi được yêu cầu rõ.
- Kết thúc phiên: tóm tắt thay đổi, cập nhật `CHANGELOG.md`, đánh dấu task trong roadmap.
