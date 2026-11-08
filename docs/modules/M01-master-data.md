# M01 — Dữ liệu gốc (PH01)

## Mục đích
Một nguồn danh mục duy nhất cho toàn chuỗi; chặn trùng mã, trùng tên, sai đơn vị ngay từ đầu (lỗi phổ biến nhất trong file Excel hiện tại).

## Chức năng MVP
| Mã | Chức năng | Ghi chú thực thi |
|---|---|---|
| 01.01 | Cây tổ chức | org → legal_entity → property → outlet → warehouse; tạo property tự sinh kho `main`, `transit`, `quarantine`, `disposal`, `minibar_main` |
| 01.02 | Vật tư | `name_norm` unique; nhóm do người dùng định nghĩa; cờ Key Item; `allowed_channels` |
| 01.03 | Quy đổi 3 tầng | mua → kho → công thức; nhiều quy cách mua; `tare_g`, `density_g_ml` cho rượu |
| 01.04 | NCC + thẩm định | trạng thái `pending` → người không thuộc thu mua duyệt; cảnh báo NCC trùng SĐT/STK với nhân viên (`profiles.phone`) |
| 01.05 | Hợp đồng khung, giá trần | hiệu lực theo ngày; không chồng lấn cùng NCC + mã |
| 01.06 | Kho & kho ảo | theo `warehouses.kind` |
| 01.08 | Chế độ kế toán | theo pháp nhân |
| 01.09–01.10 | Import + làm sạch | xem `07-IMPORT-MIGRATION.md` |
| 11.06 | Khoản mục chi phí | cây khoản mục, `usali_line` |
| NT.07 | Cấu hình động & sinh mã | quy tắc mã: `{prefix_nhom}-{prefix_phan_nhom}-{seq4}`; mã tạm `TMP-{seq}` |

## Quy tắc biên
- Không xóa vật tư đã có `stock_moves` → chỉ `inactive`.
- Đổi `stock_uom` của mã đã có giao dịch → cấm.
- Gộp mã tạm: chỉ khi mã tạm chưa qua kỳ đã khóa; mọi `stock_moves` của mã tạm được giữ nguyên, tạo cặp move `merge_out` (mã tạm) / `merge_in` (mã đích) cùng giá vốn để chuyển tồn sang mã đích (không sửa sổ cái).

## Màn hình
Xem `06-UI-UX.md` nhóm Danh mục. Danh sách vật tư có bộ lọc nhanh: "Mã tạm", "Thiếu hệ số quy đổi", "Không có ảnh mẫu", "Key Items".
