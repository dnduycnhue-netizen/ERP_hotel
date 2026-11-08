# M04 — Nhận hàng mù & QC (PH04)

## Luồng
1. Người nhận mở `/m/[p]/receive` → `receiving_list_tasks` (không số lượng, không giá).
2. Chọn PO → `receiving_start` (tạo phiếu nháp, `client_uuid`).
3. Từng dòng: đặt hàng lên cân → nhập Tổng cân, Bì → chụp ảnh → QC → `receiving_record_line`.
   - Server so với PO: trong ±5% → `ok`; ngoài → `needs_reweigh` → cân lại lần 2 (lưu cả 2 lần).
4. Dòng QC `fail` → không tính nhập, đưa vào trả hàng (chữ ký/ảnh người giao).
5. Hoàn tất → nhập PIN → `receiving_post` → ghi `receipt` (+ `issue_out/in` nếu nhận thẳng bếp).
6. Thủ kho / Cost Controller hậu kiểm ảnh trong ngày (`with_cc`: 100%; `without_cc`: 20% ngẫu nhiên + phiếu có cảnh báo).

## Dữ liệu ghi
`goods_receipts`, `goods_receipt_lines`, `attachments`, `supplier_returns`, `stock_moves`, cập nhật `purchase_order_lines.received_qty_stock`.

## Quy tắc biên
- Nhận hàng không có PO: chỉ cho mua chợ (gắn lệnh mua chợ). Hàng NCC đến mà không có PO → từ chối hoặc gọi thu mua tạo PO khẩn (vẫn phải duyệt) trước khi nhận.
- Hàng có lô/hạn dùng (`track_lot`) bắt buộc nhập hạn dùng; hạn dùng ngắn hơn `shelf_life_days × 50%` → cảnh báo QC.
- Offline: không kiểm tra dung sai lúc nhận; khi đồng bộ nếu lệch → phiếu `needs_recount`, báo người nhận cân lại nếu hàng còn ở cửa kho, nếu không → ghi chú và hậu kiểm.
- Không cho người nhận xem phiếu cũ của chính mình sau khi post (tránh đối chiếu ngược với hóa đơn NCC).
