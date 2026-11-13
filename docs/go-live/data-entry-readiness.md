# Sẵn sàng nhập dữ liệu thật — phòng, NCC, giá (M-02)

Ngày lập: 13/11/2026. Mọi dòng dưới đây đọc từ code hiện tại (không đoán):
màn hình trong `src/app/(app)/[property]/master/`, manager trong
`src/components/master/`, action trong `src/features/master/actions.ts`
và `src/features/minibar/actions.ts`, import wizard trong
`src/components/master/import-wizard.tsx` + `src/features/master/import-actions.ts`.

## 1. Bảng tổng hợp

| Dữ liệu | Nhập tay | Import Excel | Cách ghi (đã có) |
|---|---|---|---|
| Loại phòng | Có — màn `/master/rooms`, nút "Thêm loại phòng" | Không | `saveRoomTypeAction` → ghi trực tiếp bảng `room_types` (ADR-010) |
| Phòng | Có — màn `/master/rooms`, nút "Thêm phòng", từng phòng một | Không (trước M-02) | `saveRoomAction` → ghi trực tiếp bảng `rooms` |
| Nhà cung cấp | Có — màn `/master/suppliers`, kèm luồng gửi duyệt / duyệt, tài khoản ngân hàng | Có — wizard `/master/import`, loại "Nhà cung cấp" (ánh xạ cột, xem trước, báo lỗi) | `saveSupplierAction` + `submitSupplierAction` / `approveSupplierAction`; import qua RPC `import_create_batch` / `import_resolve_row` / `import_commit_batch` |
| Hợp đồng khung (giá theo NCC) | Có — màn `/master/prices`, nút "Thêm hợp đồng" + dòng giá trong hợp đồng | Không | `savePriceAgreementAction` + `savePriceAgreementLineAction` → ghi trực tiếp bảng `price_agreements` / `price_agreement_lines` |
| Giá trần | Có — màn `/master/prices`, nút "Thêm giá trần", từng dòng một | Không (trước M-02) | `saveCeilingPriceAction` → ghi trực tiếp bảng `ceiling_prices` (bắt buộc có `valid_to`) |
| Giá minibar | Có — màn `/housekeeping/minibar`, bảng giá văn phòng, từng món một | Không (trước M-02) | RPC `minibar_price_set` qua `priceSetAction` (`valid_to` được bỏ trống) |
| Vật tư (tham chiếu) | Có — màn `/master/items` | Có — wizard `/master/import`, loại "Vật tư" | `import_create_batch`… (như NCC) |
| Tồn đầu kỳ | Không nhập tay, không import Excel | Không | Kiểm kê toàn bộ bằng app (`stock_counts.kind = 'monthly_full'`), post dạng `opening`; minibar kiểm từng phòng → `opening` vào kho `minibar_room` (xem `docs/07-IMPORT-MIGRATION.md` §4) |

## 2. Nhập hàng loạt mới làm ở M-02 (chỉ thiếu UI, đã có cách ghi từng dòng)

Dialog dùng chung `src/components/master/bulk-import-dialog.tsx` +
module `src/lib/master/bulk-import.ts` (parse/validate có Vitest).
Chọn file CSV hoặc Excel (chỉ đọc sheet đầu tiên) → xem trước 20 dòng
+ lỗi từng dòng → bấm nhập: mỗi dòng hợp lệ gọi đúng action lưu từng
dòng đã có (không RPC mới, không migration). Dòng lỗi không được nhập.

| Loại | Nút mở ở đâu | Cột file (tên nào cũng được, có đoán theo tên gần giống) |
|---|---|---|
| Phòng | Màn phòng, "Nhập phòng hàng loạt" | `room_no` (*), `floor`, `room_type_code` (*) — mã loại phòng phải có sẵn trong danh mục; số phòng không trùng trong file và không trùng phòng đã có |
| Loại phòng | Màn phòng, "Nhập loại phòng hàng loạt" | `code` (*), `name` (*), `max_guests` — mã không trùng |
| Giá trần | Màn giá, "Nhập giá trần hàng loạt" | `item_code` (*), `uom` (*, phải có trong danh mục ĐVT), `price` (*, ≥ 0), `valid_from` (*), `valid_to` (*, ≥ `valid_from`), `scope` (`chuỗi`/`khách sạn`, mặc định khách sạn này) |
| Giá minibar | Màn giá minibar, "Nhập giá hàng loạt" | `item_code` (*), `price` (*, > 0), `valid_from` (*), `valid_to` (được bỏ trống) |

Ngày chấp nhận `YYYY-MM-DD` hoặc `DD/MM/YYYY` (cả serial Excel);
số chấp nhận `1.234,56` hoặc `1,234.56`.

## 3. Phần thiếu RPC — không tự viết migration (để Claude Code)

- **Không có RPC nhập hàng loạt** cho phòng, loại phòng, giá trần,
  giá minibar, hợp đồng khung. Bản M-02 gọi action từng dòng từ
  trình duyệt; với vài trăm dòng thì đủ dùng, nhưng không có tính
  nguyên tử theo lô (dòng lỗi giữa chừng không rollback các dòng đã lưu).
  Muốn nhập một lô nguyên tử cần RPC mới (migration) — chưa làm.
- **Hợp đồng khung + dòng giá chưa có nhập hàng loạt**: cần thiết kế
  định dạng file 2 tầng (hợp đồng + dòng giá) và RPC riêng; hiện chỉ
  nhập tay từng hợp đồng rồi thêm dòng giá trong hợp đồng đó.
- **Tồn đầu kỳ không có đường nhập file**: theo đặc tả, tồn đầu lấy
  bằng kiểm kê thật, không lấy từ Excel.
