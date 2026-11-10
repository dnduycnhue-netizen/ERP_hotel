# ADR-009 — Thêm `pdfkit` để xuất PDF đơn mua (C3)

- Ngày: 2026-11-10
- Trạng thái: Chấp nhận

## Bối cảnh

M03 yêu cầu sau khi PO đủ duyệt thì `po_send` (PDF, gửi cho NCC — MVP:
tải PDF và gửi tay) và 09-API-RPC.md §2 ghi rõ "sinh PDF ở route
`/api/export/po/[id]`". Repo chưa có thư viện PDF nào (grep
`jspdf|pdfkit|pdf-lib` trong `package.json` = 0); route `/api/export/[kind]`
của T-043 chỉ xuất Excel bằng `xlsx` 0.18.5.

PDF phải hiển thị đúng tiếng Việt có dấu (tên NCC, tên vật tư, lịch sử
duyệt). Font mặc định của các thư viện PDF (Helvetica/Courier) không có
glyph tiếng Việt nên bắt buộc nhúng font.

## Quyết định

1. Cài `pdfkit@0.20.2` (runtime) + `@types/pdfkit@0.17.7` (dev). pdfkit
   chạy phía server trong route handler Next.js (Node runtime), nhận
   `Buffer` font và trả `Buffer` PDF — không cần trình duyệt/headless
   Chrome, không thêm service ngoài.
2. Nhúng 2 file font `NotoSans-Regular.ttf` + `NotoSans-Bold.ttf`
   (SIL OFL) vào `src/features/export/fonts/` (đọc bằng `fs` lúc chạy,
   không để trong `public/` để trình đóng gói file của Next.js/Vercel
   đưa font theo cùng function). Không dùng font hệ thống của máy chủ
   vì Vercel không có font đó.
3. Không dùng `jspdf`: cùng phải nhúng font, nhưng pdfkit viết theo
   luồng (stream) và API vẽ bảng tay phù hợp file PDF 1–2 trang này
   hơn; `pdf-lib` thiên về sửa PDF có sẵn, không phải sinh mới.
4. File Excel chuyển khoản vẫn dùng `xlsx` 0.18.5 đã có (như T-043),
   không thêm thư viện Excel mới. Lệch với AGENTS.md §2 (ghi `exceljs`
   cho xuất Excel) là lệch có sẵn từ T-043, không đổi trong task này.

## Hệ quả

- `package.json`/`pnpm-lock.yaml` thêm `pdfkit`; repo tăng ~1 MB do 2
  file font (512 KB + 515 KB).
- PDF builder là hàm thuần `src/features/export/poPdf.ts`, test bằng
  Vitest (buffer bắt đầu bằng `%PDF`).
- Khi có logo/màu thương hiệu thật (Q103), thay font/logo trong cùng
  module export, không đổi contract route.
