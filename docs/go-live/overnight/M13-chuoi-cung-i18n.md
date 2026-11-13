# M13 — Rà chuỗi cứng tiếng Việt & i18n

- Trạng thái: **Đạt**
- Thời gian: 13/11/2026 ~23:05–23:15
- Lệnh đã chạy: `pnpm lint`, `pnpm typecheck`, `pnpm test` — đều xanh (285/285)

## Cách rà

- ESLint đã có rule chặn chuỗi tiếng Việt có dấu hard-code (Literal/JSXText/TemplateElement) ngoài `src/i18n/**` và `src/app/dev/**`; chạy `pnpm lint` sạch — không còn chuỗi tiếng Việt hard-code nào trong code.
- Quét thêm những chỗ rule không bắt được: chuỗi tiếng Anh hiển thị, `placeholder`/`title`/`aria-label` hard-code, `alert`/`confirm`, literal tiếng Anh trong `.ts` (actions/lib). So sánh thuật ngữ `vi.ts` với `docs/GLOSSARY.md`.

## Lỗi tìm thấy và đã sửa: 6 placeholder hard-code (rule ESLint không bắt được vì không chứa dấu tiếng Việt)

| # | File | Chuỗi cũ | Khóa mới trong vi.ts |
|---|---|---|---|
| 1 | `src/components/finance/payment-request-detail.tsx:259` | `placeholder="VD: FT260110123456"` | `vi.finance.bankRefExample` |
| 2 | `src/components/master/item-form-dialog.tsx:268` | `placeholder="VD: 1000"` | `vi.master.stockToRecipeExample` |
| 3 | `src/components/master/item-form-dialog.tsx:379` | `placeholder="VD: 0.95"` | `vi.master.densityExample` |
| 4 | `src/components/restaurant/dish-form.tsx:207` | `placeholder="hot / salad / dessert / bread…"` | `vi.restaurant.dishGroupExample` |
| 5 | `src/components/restaurant/dish-form.tsx:243` | `placeholder="lactose-free, vegetarian"` | `vi.restaurant.dietFlagsExample` |
| 6 | `src/app/admin/audit/page.tsx:101` | `placeholder="stock_moves"` | `vi.admin.audit.filterTableExample` |

Nội dung placeholder giữ nguyên (chỉ chuyển chỗ chứa). Hai placeholder tiếng Anh ở món ăn giữ nguyên tiếng Anh vì nghiệp vụ nhập nhóm món/chế độ ăn bằng tiếng Anh.

## Không tìm thấy lỗi ở các chỗ khác

- Mọi `confirm()`/`window.confirm()` (15 chỗ: xóa quy tắc duyệt, xóa nhóm vật tư, xóa món…) đều dùng chuỗi `vi.*`.
- Không có literal tiếng Anh nào làm chuỗi hiển thị trong `.ts` (actions/lib) — các chuỗi "Error/Failed/…" không xuất hiện.
- Không có `aria-label`/`title` hard-code nào ngoài vi.ts (trừ 1 chỗ ở trang dev, xem dưới).
- Không phát hiện chuỗi thiếu dấu trong `vi.ts`.

## Thuật ngữ

- "Phiếu nhận" dùng nhất quán 10 lần; "Phiếu nhập" chỉ xuất hiện 1 lần ở trang dev `src/app/dev/components/page.tsx:259` (`title="Chưa có phiếu nhập kho"`) — trang dev không phải màn người dùng nên không sửa trong M13.
- Bảng so sánh đầy đủ + 4 đề xuất bổ sung/sửa GLOSSARY: `docs/go-live/overnight/M13-glossary.md` (không tự đổi thuật ngữ theo luật task).

## Việc chưa làm

- Không sửa trang dev (ngoài phạm vi màn người dùng).
- Không đổi bất kỳ thuật ngữ nào trong `vi.ts` hay `docs/GLOSSARY.md` — chỉ đề xuất ở file glossary riêng.
- Không mở rộng rule ESLint sang chuỗi tiếng Anh (cần quyết định của Claude Code vì có thể gây nhiễu với các chuỗi kỹ thuật như tên bảng/cột trong placeholder).
