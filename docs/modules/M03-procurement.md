# M03 — Thu mua (PH03)

## Luồng có PO
1. Outlet/kho tạo PR (`kind = stock | service`).
2. Trưởng outlet duyệt PR.
3. Thu mua chọn dòng PR → `po_create_from_pr` → hệ thống lấy giá: hợp đồng → báo giá → giá trần. Không có nguồn giá → `manual` + duyệt gm.
4. `po_submit` → sinh bước duyệt theo `approval_rules` (giá trị, nhóm hàng, vượt trần).
5. Đủ duyệt → `po_send` (PDF, gửi Zalo/email cho NCC — MVP: tải PDF và gửi tay).
6. Nhận hàng (M04) cập nhật `received_qty_stock`; PO chuyển `partially_received` / `received`.
7. Thu mua có thể `po_close` phần còn thiếu (lý do bắt buộc).

## Luồng mua chợ
1. `market_order_create`: danh sách hàng + số lượng + giá trần + số tiền tạm ứng.
2. gm duyệt → kế toán chi tạm ứng (`advance_disburse`).
3. Đi mua → chụp biên nhận ngay trong app (gắn PO); người bán không hóa đơn → nhập tên, địa chỉ cho bảng kê.
4. Hàng về → nhận mù bởi người **khác** người đi chợ.
5. Trong 24h quyết toán (M09).

## Quy tắc biên
- PO thuộc 1 pháp nhân, 1 NCC, 1 kho nhận.
- Sửa PO sau `approved` → phải `cancel` và tạo PO mới (giữ liên kết `replaces_po_id`).
- PR dịch vụ sinh PO `kind = service` → không qua nhận hàng, qua nghiệm thu (M11).
- Ủy quyền duyệt khi vắng: `approval_delegations(from_user, to_user, from, to)`; ủy quyền không được trao cho người tạo chứng từ.
