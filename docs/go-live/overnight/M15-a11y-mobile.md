# M15 — Truy cập (a11y) & di động

- Trạng thái: **Đạt (phần sửa được); còn danh sách đo thực tế để kiểm tiếp**
- Thời gian: 13/11/2026 ~23:15–23:30
- Lệnh đã chạy: `pnpm lint`, `pnpm typecheck`, `pnpm test` — đều xanh (285/285)

## Kết quả rà (code, chưa đo bằng tay trên máy thật)

| Hạng mục | Kết quả |
|---|---|
| Nhãn cho nút/ô nhập | **Tốt.** 0 nút chỉ-icon thiếu `aria-label` (quét cả `<button>` và `<Button>`); mọi ô nhập số trên mobile đều có `aria-label` hoặc nằm trong `<label>` (mẫu `MobileField` bọc `<label>`); `aria-label` lấy từ `vi.ts` (vd `vi.minibar.missingQty + tên món`, `vi.count.removeRow`). |
| Bàn phím số | **Tốt.** `inputMode` có ở 20 chỗ: PIN (`pin-dialog.tsx:144` numeric), đếm (`count-submit-dialog.tsx` numeric), tiền/số lượng (decimal) ở invoice, advance, payment-request, minibar, PO, PMS daily, nhà hàng mobile. Ô số nào cũng có `type="number"` + `inputMode`. |
| Vùng chạm | **Đã sửa 5 nút; còn 4 nút nhỏ khác (ghi dưới).** Nút chính trên mobile đã đủ lớn: bàn phím số `h-14` (56px), ô số lượng đếm `h-14`, select ĐVT `h-14`, stepper minibar `size-11 min-h-11` (44px), nút ghi dòng/ghi sổ `size="lg"`. Nút mặc định của hệ thống là `h-8` (32px), `lg` là `h-9` (36px) — dưới mốc 44px nhưng là chuẩn chung của desktop; không đổi mặc định toàn app trong ca đêm. |
| Thứ tự Tab / focus | **Có.** `Button` có `focus-visible:ring-3`; ô số lượng đếm có `focus:border-ring` + `ring-2` khi active. Không phát hiện `tabIndex` lạ. |
| Tràn ngang 390px | **Chưa đo bằng tay.** Bằng chứng gián tiếp: đợt test demo B6 (13/11) kết luận mobile không tràn ngang, nút ~44px+. Kiểm chứng tự động ở M11 (spec mobile 390px). |

## Lỗi đã sửa: 5 nút nhỏ trong form đếm mobile

File `src/components/count/mobile-count-line-form.tsx` — các nút phụ đang `size="sm"` (`h-7` = 28px), dưới mốc 44px:
- Nút đóng (X) + nút xóa dòng (X): thêm `min-h-11 min-w-11` → vùng chạm 44×44.
- 2 tab chế độ (ĐVT/Chai) + nút thêm dòng: thêm `min-h-11` → cao 44px.

Chỉ thêm class, không đổi variant/kích thước chữ/bố cục. Ô nhập số lượng chính trong cùng form vốn đã `h-14`.

## Còn lại (chưa sửa — chuyển Claude Code)

1. **4 nút `size="sm"` khác trên mobile** (28px): `mobile-count-list.tsx:64`, `mobile-return-detail.tsx:250`, `mobile-returns-list.tsx:99`, `frontdesk-check-list.tsx:185`. Chưa sửa vì chưa đọc kỹ ngữ cảnh từng nút (có nút nằm trong hàng dense); sửa theo cùng mẫu `min-h-11` khi Claude Code xem.
2. **Nút mặc định toàn app `h-8` (32px) và `lg` `h-9` (36px)** — dưới mốc 44px. Đổi mặc định sẽ thay đổi giao diện mọi màn nên cần quyết định thiết kế, không tự đổi trong ca đêm.
3. **Thanh điều hướng mobile** (`mobile-nav.tsx:75` dùng `py-1.5`): chưa đo chiều cao chạm thực tế của từng mục — cần đo trên máy thật ở 390px.
4. **Tương phản màu** chưa kiểm bằng công cụ (cần đo bằng axe/Lighthouse trên trình duyệt thật, không đo được bằng grep).

## Việc chưa làm

- Không đo bằng tay trên máy thật (đêm, không có thiết bị); phần đo 390px và tương phản giao cho M11 (Playwright) + Claude Code kiểm tiếp.
- Không đổi kích thước mặc định của `Button`.
