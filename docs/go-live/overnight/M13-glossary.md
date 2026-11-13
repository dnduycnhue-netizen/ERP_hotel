# M13 — Bảng thuật ngữ đề xuất (so với docs/GLOSSARY.md)

So sánh thuật ngữ trong `docs/GLOSSARY.md` với cách dùng thật trong `src/i18n/vi.ts` (đêm 13/11/2026).
**Không tự đổi thuật ngữ** — bảng này chỉ đề xuất để Claude Code/Duy chốt.

## Thuật ngữ đã nhất quán (không cần làm gì)

| Thuật ngữ (GLOSSARY) | Cách dùng trong vi.ts | Ghi chú |
|---|---|---|
| Phiếu nhận hàng / nhập kho (GRN) | "Phiếu nhận" — 10 lần | Dùng "Phiếu nhận" mọi nơi trong app |
| Yêu cầu mua hàng (PR) | "Yêu cầu mua hàng" | — |
| Đơn đặt hàng (PO) | "Đơn đặt hàng" | — |
| Phiếu lĩnh (Requisition) | "Phiếu lĩnh" — 6 lần | — |
| Xuất theo mục đích (Purpose issue) | "Phiếu xuất mục đích" — 2 lần | Thêm chữ "Phiếu" cho đồng dạng với các phiếu khác |
| Tạm ứng (Cash advance) | "Tạm ứng" — 13 lần | — |
| Đề nghị thanh toán | "Đề nghị thanh toán" — 4 lần | — |
| Công nợ NCC (Accounts payable) | "Công nợ" — 7 lần | — |
| Hủy hàng (Waste) | "Phiếu hủy" — 2 lần | — |
| Kiểm kê mù (Blind count) | "Kiểm kê" — 12 lần | UI lược chữ "mù" (đúng vì màn đếm vốn đã mù); docs giữ "Kiểm kê mù" |
| Giá trần / Hợp đồng khung / Mã tạm | đúng như GLOSSARY | — |

## Điểm không nhất quán / thiếu trong GLOSSARY

1. **"Phiếu nhập kho" chỉ xuất hiện 1 lần, ở trang dev.** `src/app/dev/components/page.tsx:259` dùng `title="Chưa có phiếu nhập kho"` trong khi toàn bộ app dùng "Phiếu nhận". Trang dev không phải màn người dùng (ESLint bỏ qua) nên không sửa trong M13. Đề xuất: đổi thành "Chưa có phiếu nhận hàng" để đồng nhất; hoặc ghi rõ trong GLOSSARY rằng "Phiếu nhập kho" là tên cũ, không dùng nữa.
2. **"Điều chuyển" chưa có trong GLOSSARY.** UI dùng "Điều chuyển" cho transfers (`vi.inventory.transfers`), "Điều chuyển đi" / "Điều chuyển đến" cho `transfer_out`/`transfer_in`. GLOSSARY không có dòng nào cho chuyển kho. Đề xuất thêm: `Điều chuyển | Transfer | transfers/stock_moves (move_type='transfer')`.
3. **"Phiếu trả hàng NCC" chưa có trong GLOSSARY.** UI dùng "Phiếu trả" (3 lần) cho supplier returns. Đề xuất thêm: `Phiếu trả hàng NCC | Supplier return | supplier_returns`.
4. **"Phiếu xuất" dễ nhầm với xuất kho chung.** vi.ts dùng "Phiếu xuất mục đích" cho purpose issue — đúng và rõ, nhưng GLOSSARY ghi "Xuất theo mục đích" không có chữ "Phiếu". Đề xuất sửa GLOSSARY thành "Phiếu xuất mục đích" cho khớp UI.

## Ghi chú về dấu tiếng Việt

- Không phát hiện chuỗi thiếu dấu trong vi.ts (quét bằng mắt các nhóm đã sửa + ESLint chặn chuỗi cứng có dấu ngoài vi.ts).
- Các placeholder tiếng Anh ("lactose-free, vegetarian", "hot / salad / dessert / bread…") là ví dụ nhập liệu bằng tiếng Anh theo nghiệp vụ (nhóm món/chế độ ăn nhập bằng tiếng Anh) — đã đưa vào vi.ts trong M13, giữ nguyên nội dung.
