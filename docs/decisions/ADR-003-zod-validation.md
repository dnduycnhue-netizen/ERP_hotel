# ADR-003 — Thêm `zod` để validate Server Action (T-005b)

## Bối cảnh

`AGENTS.md` mục 2 quy định form & validate dùng React Hook Form + Zod, nhưng
scaffold T-001 chưa cài cả hai thư viện. Các action trước đó (đăng nhập, đổi
khách sạn) validate thủ công bằng `FormData` và `throw`.

## Quyết định

- Cài `zod@4.6.7` (không phụ thuộc khác) và dùng schema Zod trong
  `src/features/admin/schemas.ts` cho mọi Server Action quản trị; lỗi
  validation trả về `AdminActionResult` với câu tiếng Việt, không throw.
- **Hoãn React Hook Form**: các form quản trị ở T-005b là form đơn giản
  (ô nhập, select, checkbox) và dùng native form + Server Action giống mẫu
  đăng nhập hiện có. Khi nào có form phức tạp đầu tiên (nhiều trường, validate
  chéo client-side), cài RHF và ghi ADR bổ sung.
- **Hoãn Vitest**: repo chưa có Vitest hay script `test`. Schema Zod được kiểm
  chứng bằng script Node chạy trực tiếp file schema (type-stripping của Node 24)
  trong quá trình làm T-005b; khi repo có Vitest, chuyển các case đó thành test
  chính thức.

## Hệ quả

- Server Action quản trị có input typed + thông báo lỗi thống nhất.
- Không thêm thư viện nào khác ở T-005b; `package.json` chỉ thêm `zod`.
