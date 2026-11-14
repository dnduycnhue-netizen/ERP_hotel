# V6 — Đơn mua chợ (ĐẠT TOÀN BỘ — Q268 + gửi duyệt + B-50)

- Ngày: 14/11/2026, 10:51–10:53 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.purchaser (đăng nhập tay, xác nhận qua menu tài khoản; lúc mở trình duyệt phiên cũ là uat.owner nên đã đăng xuất rồi đăng nhập lại đúng tài khoản). Không màn hình nào hỏi mã PIN. Không bấm "Duyệt", không bấm "Gửi cho nhà cung cấp"; PO để ở CHỜ DUYỆT đúng yêu cầu.
- Kết luận: **Đạt toàn bộ — danh sách hiện "Chưa có giá (xem chi tiết)" (B-50), sửa nháp lưu được mô tả dòng mới sau tải lại trang (Q268), gửi duyệt không còn bị chặn vì "giá 0" và gợi ý đúng.**
- Commit: `T-V6` (xem git log).

## 1. Bước 1 — Danh sách PO (B-50): ĐẠT

- Tại /procurement/po, dòng PO-TEST47-LE-2611-0004 hiển thị tổng tiền **"Chưa có giá (xem chi tiết)"** (không phải "0 đ"), trạng thái NHÁP, loại "Mua chợ (tiền mặt)", "Mua chợ", ngày 13/11/2026, 1 dòng.
- Các PO khác để đối chiếu: PO-...-0005 — "1.000.000 đ", ĐÃ GỬI; PO-...-0003 — "1.000.000 đ", ĐÃ GỬI; PO-...-0002 — "1.040.000 đ", NHÁP; PO-...-0001 — "1.040.000 đ", ĐÃ GỬI.

## 2. Bước 2 — Chi tiết PO-0004: ĐẠT

- Trang chi tiết (…/procurement/po/dff27d6e-39cb-4aef-b6f7-ee4369d004d7): trạng thái NHÁP; "Tổng tiền: 0 đ"; "Tổng ước tính: 500.001 đ".
- Gợi ý/hint nguyên văn trên trang: **"Đơn mua chợ còn dòng chưa có giá: nhập tổng tiền ước tính để tính đúng bậc duyệt (lấy số lớn hơn giữa ước tính và tổng dòng đã có giá)."** và "Dòng giá tay cần nhập đơn giá và sẽ qua thêm một bước duyệt của quản lý."
- Dòng hàng duy nhất (1 dòng): vật tư **"Rau cu cho demo B2 — chua co gia"** (gắn nhãn "Giá tay"), số lượng 5 kg, đơn giá 0 đ, nguồn giá "Giá tay", giá trần "—", đã nhận 0, thành tiền 0 đ. (Mô tả thực tế trên trang là dòng này, không phải ví dụ "ba chỉ nách" trong bài.)
- Trang không có câu nào nói nút "Gửi duyệt" bị chặn vì "giá 0"; nút "Gửi duyệt" hiển thị ở trạng thái bật.

## 3. Bước 3 — Sửa nháp (Q268, bước chính): ĐẠT

- Bấm "Sửa nháp" mở form tại …/po/dff27d6e-39cb-4aef-b6f7-ee4369d004d7/edit. Đã đổi mô tả dòng duy nhất từ "Rau cu cho demo B2 — chua co gia" thành **"Rau cu cho demo B2 — chua co gia — kiểm thử V6"**, giữ nguyên các trường khác (số lượng 5, đơn giá 0).
- Form sửa không có ô "lý do sửa" riêng — chỉ có ô "Lý do vượt giá trần" đã điền sẵn "M1-test", nên đã giữ nguyên ô này và không ghi đè (xem N-3).
- Bấm "Lưu nháp": không thấy toast/banner xác nhận nào (xem N-1). **Tải lại trang (F5) rồi mở lại chi tiết PO-0004: mô tả dòng mới VẪN CÒN, nguyên văn "Rau cu cho demo B2 — chua co gia — kiểm thử V6" → Q268 ĐẠT, lỗi sửa nháp không lưu được đêm 13/11 không tái hiện.**

## 4. Bước 4 — Gửi duyệt: ĐẠT

- Nút "Gửi duyệt" ở trạng thái bật (không vô hiệu, không có hint chặn kèm theo). Bấm "Gửi duyệt" hiện ô hỏi ngay trên trang: **"Gửi chứng từ này đi duyệt?"** với hai nút "Xác nhận" / "Bỏ qua" (không còn hộp thoại hệ thống).
- Bấm "Xác nhận": không có thông báo chặn nào, không nhắc "giá 0" hay "ước tính". Kết quả: banner xanh **"Đã gửi duyệt."**, trạng thái PO đổi thành **CHỜ DUYỆT**; các bước duyệt hiện ra: **"1 Quản lý — Chờ duyệt", "2 Tổng quản lý — Chờ duyệt"**. Không bấm duyệt.

## 5. Bước 5 — Kiểm tra cuối: ĐẠT

- Mở lại /procurement/po: dòng PO-0004 hiện trạng thái CHỜ DUYỆT, tổng tiền vẫn "Chưa có giá (xem chi tiết)"; các PO 0001/0002/0003/0005 không đổi so với Bước 1.
- Mở lại trang chi tiết lần nữa: ước tính còn "Tổng ước tính: 500.001 đ", tổng tiền "0 đ", mô tả dòng sửa ở Bước 3 còn nguyên văn "Rau cu cho demo B2 — chua co gia — kiểm thử V6" (5 kg, đơn giá 0 đ, thành tiền 0 đ), trạng thái CHỜ DUYỆT.

## 6. Phát hiện mới (đều nhỏ — giao diện)

- **N-1. [Nhỏ] Sau khi bấm "Lưu nháp", không có phản hồi xác nhận nào:** trang vẫn ở form /edit, nút chỉ chuyển tạm thành "Đang tải dữ liệu…" (vô hiệu) rồi trở lại "Lưu nháp", không thấy toast/banner. Việc lưu thực tế vẫn thành công (đã kiểm chứng bằng tải lại trang ở Bước 3). Tái hiện: mở chi tiết PO-0004 → "Sửa nháp" → đổi mô tả dòng → "Lưu nháp" → quan sát form /edit. Chuyển Claude Code (P2 — thêm toast/banner xác nhận sau khi lưu nháp).
- **N-2. [Nhỏ] Sau khi bấm "Xác nhận" gửi duyệt, trạng thái có độ trễ:** trong khoảnh khắc đầu trang vẫn hiển thị NHÁP và nút "Gửi duyệt" chuyển sang vô hiệu, chưa có banner; vài giây sau mới hiện banner "Đã gửi duyệt." và trạng thái CHỜ DUYỆT. Không phải lỗi chặn, chỉ là phản hồi trong lúc xử lý chưa rõ ràng. Tái hiện: chi tiết PO nháp → "Gửi duyệt" → "Xác nhận" → quan sát ngay sau khi bấm. Chuyển Claude Code (P2).
- **N-3. [Nhỏ] Form "Sửa nháp" không có ô lý do sửa riêng** như bài kiểm tra dự kiến; chỉ có ô "Lý do vượt giá trần" (đã có sẵn "M1-test"). Vì vậy lý do "Sửa mô tả dòng kiểm thử V6" không có chỗ để nhập mà không ghi đè dữ liệu có sẵn, nên đã giữ nguyên ô đó. Chuyển Claude Code (P2 — xác nhận có cần ô lý do sửa riêng không).
- **N-4. [Nhỏ] Điều hướng trong app có độ trễ:** lần bấm đầu vào dòng PO ở danh sách và vào nút "Sửa nháp" đều có lúc ảnh chụp ngay sau đó vẫn hiển thị trang cũ, trang đích chỉ hiện sau một khoảng ngắn. Không ảnh hưởng kết quả, chỉ cần chờ/đọc lại trang. Ghi nhận.

## 7. Kết quả xác minh các lỗi cũ trong V6

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q268 | Sửa nháp PO chợ lưu được mô tả dòng | **Đạt** |
| Q268 | Gửi duyệt PO chợ không còn bị chặn vì "giá 0", hint đúng | **Đạt** |
| Q272 B-50 | Danh sách PO hiện "Chưa có giá (xem chi tiết)" thay vì 0 đ | **Đạt** |

## 8. Lệnh đã chạy

```text
Trình duyệt cloud: 1 tài khoản uat.* (purchaser), 10:51–10:53 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
