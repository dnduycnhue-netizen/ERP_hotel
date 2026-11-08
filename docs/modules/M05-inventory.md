# M05 — Kho, lĩnh xuất, điều chuyển (PH05) & kiểm kê, khóa sổ (PH08)

## Phiếu lĩnh 2 bước
1. Outlet tạo → trưởng outlet duyệt.
2. Kho xuất (`requisition_issue`): `issue_out` kho tổng → `issue_in` kho `transit`.
3. Outlet xác nhận nhận (`requisition_confirm_receipt`): `issue_out` transit → `issue_in` kho outlet theo số thực nhận.
4. Lệch giữa xuất và nhận → còn trong `transit`, phải xử lý (trả lại kho / biên bản thiếu) trước khi khóa ca outlet.

## Xuất theo mục đích
Staff meal, VIP/comp, marketing, họp, đào tạo, sửa chữa (gắn phiếu công việc ở P2). Bắt buộc cost center + khoản mục; không tính vào giá vốn hàng bán.

## Hủy hàng
Đề xuất (ảnh + lý do) → người khác duyệt → `waste`. > 1.000.000đ thêm gm.

## Kiểm kê tháng (MVP)
1. `count_open(kind='monthly_full')` → kho đóng băng.
2. ≥ 2 người đếm mù trên điện thoại (`v_count_sheet`).
3. `count_submit` → dòng lệch → đếm lại 1 lần → `count_lock`.
4. Biên bản chênh lệch (Excel) → gm duyệt `count_adjust_post`.
5. Mở băng kho.

## Khóa ngày / kỳ
Xem `05-BUSINESS-RULES.md` mục 10. Màn hình `/[p]/inventory/locks` hiện lịch tháng, ngày nào đã khóa theo từng kho.
