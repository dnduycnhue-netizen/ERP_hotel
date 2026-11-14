# V7 — Quyền mới Q270 (ĐẠT MỘT PHẦN — quyền mở rộng đạt; chênh lệch + giá trị tồn chưa kiểm được đầy đủ)

- Ngày: 14/11/2026, 10:55–11:00 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.gm, uat.storekeeper, uat.hk_supervisor, uat.hk_attendant, uat.receiver (đăng nhập tay, xác nhận qua menu tài khoản). Chỉ mở xem — không tạo/sửa/xóa dữ liệu, không bấm nút ghi/chuyển trạng thái nào.
- Kết luận: **Đạt một phần — tính mù được giữ ở HK (3a, 3b) và receiver (4a); quyền mở rộng được cấp ở GM (1a) và thủ kho (2a, 2b). Còn 2 điểm chưa kiểm được đầy đủ (1b, 2c) và 1 điểm không kiểm được đầy đủ (4b).**
- Commit: `T-V7` (xem git log).

## 1. Kiểm tra 1 — GM

- **1a Đạt.** GM (uat.gm@erp.internal) mở /inventory/transfers tải được, hiện danh sách 2 phiếu: TRF-TEST47-LE-2611-0002 (NHÁP, Kho tổng → Kho trung chuyển, 14/11/2026) và TRF-TEST47-LE-2611-0001 (ĐÃ HỦY, 13/11/2026). Menu Kho (sidebar) có mục "Điều chuyển".
- **1b Không kiểm được đầy đủ (quyền đã mở, số liệu chưa có để đối chiếu).** Đợt CNT-TEST47-LE-2611-0001 (xe đẩy, CHỜ DUYỆT, 13/11, 12 dòng): GM thấy bảng có các cột "SỐ ĐẾM", "SỐ SỔ", "CHÊNH LỆCH", "% LỆCH", "TRẠNG THÁI DÒNG", nhưng mọi giá trị SỐ SỔ / CHÊNH LỆCH / % LỆCH đều là "—", trạng thái dòng đều "Khớp" (số đếm 10 cho mọi mặt hàng, ví dụ MILO ON-THE-GO 10, NESTEA 10). **Không xuất hiện dòng chặn "Bạn chưa được cấp quyền xem chênh lệch — chỉ người có quyền mới xem được biên bản."** — tức quyền `count.view_variance` của GM đã mở (Q270). Nhưng GM cũng không thấy được con số chênh lệch thực tế nào và không có mục biên bản riêng bên dưới bảng. Đợt CNT-...-0004 (luân phiên, ĐANG MỞ) chỉ hiện thông báo: "Chưa có biên bản chênh lệch — người đếm chưa nộp hoặc bạn không có quyền xem." — không có dòng đếm nào.
  - Diễn giải: đợt 0001 là đợt xe đẩy — có thể đợt xe đẩy không có "số sổ" để đối chiếu (số sổ "—" là đúng thiết kế?), và đợt 0004 có 0 dòng nên không có chênh lệch. **Muốn kiểm được việc tính chênh lệch thì cần một đợt kiểm kê kho có tồn + số sổ — phụ thuộc V1/V3 (cần tồn trước).** Chuyển Claude Code (P2 — xác nhận "SỐ SỔ —" ở đợt xe đẩy là đúng thiết kế hay thiếu dữ liệu; xem N-1, N-2).

## 2. Kiểm tra 2 — Thủ kho

- **2a Đạt.** Thủ kho (uat.storekeeper@erp.internal) mở chi tiết PO-TEST47-LE-2611-0001 xem được đầy đủ: mua hàng nội bộ, ĐÃ GỬI, ngày yêu cầu 13/11/2026, cần giao trước 15/11/2026, Tổng tiền 1.040.000 đ, bảng dòng có cột ĐƠN GIÁ / GIÁ TRẦN / THÀNH TIỀN (ví dụ NVL0388 Gạo nếp lợn, 10 kg, đơn giá 100.000 đ, thành tiền 1.000.000 đ; NVL0561, 8 cái, đơn giá 5.000 đ, thành tiền 40.000 đ). Không có thông báo chặn.
- **2b Đạt.** Thủ kho mở /inventory/waste/new: form "Lập phiếu hủy hàng" tải được đầy đủ (trường Kho*, Lý do* với các lựa chọn Hết hạn / Hỏng do bảo quản / Vỡ, hỏng / Khách trả lại / Khác, Ghi chú, bảng Mặt hàng* — Số lượng*, nút Thêm dòng, nút Lưu nháp). Chỉ mở xem, không tạo phiếu.
- **2c Không kiểm được (cần tồn > 0).** Thủ kho mở /inventory/stock: trang tải được nhưng chỉ hiện "0 tồn kho" và "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại." — **KHÔNG có bảng, KHÔNG có cột giá trị/số tiền, KHÔNG có tổng giá trị tồn** (không có số 0 đ nào; tìm "giá trị" trên trang không có kết quả). Vì tồn đang trống nên không xác nhận được cột giá trị có hiện khi có tồn hay không. Chuyển Claude Code (P2 — trạng thái trống ẩn hẳn bảng + tổng giá trị; xem N-3).

## 3. Kiểm tra 3 — HK vẫn không được thấy tồn lý thuyết minibar (đếm mù giữ nguyên)

- **3a Đạt.** hk_supervisor mở /housekeeping/minibar: KHÔNG thấy số lượng tồn lý thuyết của phòng. Nguyên văn cảnh báo: "Bạn chưa có quyền xem số lượng tồn (stock.view_qty) nên màn này không hiển thị tồn kho phòng. Nhờ quản trị cấp quyền xem tồn cho kho phòng để xem được." Mục "Tồn minibar từng phòng" trống, không có số tồn nào.
- **3b Đạt.** hk_attendant mở màn kiểm minibar mobile /m/.../minibar → phiếu phòng 104 (MB-TEST47-LE-2611-0002, Trả phòng, Chưa kiểm): màn nhập chỉ hiện ô "Số thiếu" (nhập 0, nút -, +) cho từng mặt hàng, "Đã nhập thiếu: 0/7", "Tạm tính 0 đ" và "Đơn giá" bán (ví dụ Coca-Cola 25.000 đ, Pepsi 25.000 đ). KHÔNG hiện tồn lý thuyết/tồn kỳ vọng hay bất kỳ số tồn nào.

## 4. Kiểm tra 4 — Receiver vẫn không được thấy PO/giá

- **4a Đạt.** receiver mở /procurement/po: bị chặn, trang hiện "Không tìm thấy trang" và "Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn." — không thấy danh sách PO, không thấy giá. Sidebar của receiver cũng không có menu Mua hàng/Kho.
- **4b Không kiểm được đầy đủ (màn trong chưa mở được mà không tạo dữ liệu).** receiver mở màn nhận hàng mobile /m/.../receive: danh sách hiện "Nhiệm vụ đang chờ nhận (3)", gồm PO-TEST47-LE-2611-0005 — "1 dòng, Ngày hẹn giao 14/11/2026" — **không hiện số lượng hay đơn giá**. Bấm vào nhiệm vụ này chỉ mở hộp thoại "Mở phiếu nhận hàng" với nội dung "Chọn kho nhận rồi mở phiếu nháp cho đơn này." và nút "Mở phiếu nhận" — bước này sẽ mở/tạo phiếu nhận nháp nên đã HỦY, không bấm tiếp, để tuân thủ quy tắc chỉ mở xem. Thử đường xem chỉ-đọc /inventory/grn cũng trả "Không tìm thấy trang" với receiver. Vì vậy màn nhận bên trong (có hiện số lượng/đơn giá PO của GRN-...-0007 hay không) chưa kiểm được; bằng chứng gián tiếp (danh sách + hộp thoại không hề lộ số lượng/giá) ủng hộ tính mù.
  - Đối chiếu: V1 đã kiểm màn nhận bên trong (GRN-...-0006, receiver) — màn nhận mù, không hiện số lượng/đơn giá PO. Kết hợp V1 + 4b thì tính mù nhận hàng đã được kiểm ở cả hai lớp (danh sách + màn trong).

## 5. Phát hiện mới

- **N-1. [Giao diện — cần xác nhận] GM xem chênh lệch kiểm kê chỉ thấy cột rỗng:** mở đợt CNT-TEST47-LE-2611-0001 bằng GM → các cột SỐ SỔ/CHÊNH LỆCH/% LỆCH đều "—" nhưng trạng thái dòng vẫn "Khớp". Chênh lệch không được tính/hiển thị, GM không thể đối chiếu số đếm với số sổ. Chuyển Claude Code (P2 — xác nhận "SỐ SỔ —" ở đợt xe đẩy là đúng thiết kế hay thiếu dữ liệu; cần đợt kho có tồn để kiểm thật).
- **N-2. [Giao diện — nhỏ] Thông báo biên bản mơ hồ, gộp 2 nguyên nhân:** mở đợt CNT-...-0004 bằng GM → "Chưa có biên bản chênh lệch — người đếm chưa nộp hoặc bạn không có quyền xem." Không phân biệt được là chưa có dữ liệu hay bị thiếu quyền. Chuyển Claude Code (P2 — tách thông báo theo nguyên nhân thật).
- **N-3. [Giao diện — nhỏ] Trang Tồn kho khi trống thì ẩn hẳn cột giá trị/tổng giá trị:** đăng nhập thủ kho → /inventory/stock (tồn = 0) → chỉ có "0 tồn kho" và dòng trống, không có tổng giá trị 0 đ. Không kiểm chứng được quyền xem giá trị tồn ở trạng thái tồn 0. Chuyển Claude Code (P2 — trạng thái trống vẫn hiện bảng rỗng + tổng giá trị 0 đ, hoặc ghi rõ quyền xem giá trị đang bật).
- **N-4. [Giao diện — nhỏ] Receiver bị chặn PO bằng trang 404 chung, không phải thông báo quyền:** đăng nhập receiver → /procurement/po → "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn." Người dùng không biết là do thiếu quyền hay sai đường dẫn. Chuyển Claude Code (P2 — trang chặn quyền riêng thay vì 404 chung).
- **N-5. [Giao diện — nhỏ] Màn nhận mobile không có lối vào chỉ-đọc:** đăng nhập receiver → /m/.../receive → bấm PO-TEST47-LE-2611-0005 → chỉ có hộp thoại "Mở phiếu nhận hàng" (mở phiếu nháp). Không có cách xem màn nhận của GRN-...-0007 mà không mở/tạo phiếu nháp. Chuyển Claude Code (P2).
- **N-6. [Ghi nhận]** Trang Minibar của hk_supervisor vẫn hiện "Bảng giá" bán minibar (ví dụ Coca-Cola 25.000 đ, Pepsi 25.000 đ, Bia Tiger 35.000 đ) trong khi ẩn số tồn; trang /procurement/po của thủ kho hiện đầy đủ tổng tiền và đơn giá PO (xem 2a). Đây là hành vi có vẻ đúng (giá bán được hiện, tồn thì ẩn).

## 6. Kết quả xác minh các lỗi cũ trong V7

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q270 B-12/B-14 | GM mở /inventory/transfers (tab Điều chuyển trong menu Kho) | **Đạt** |
| Q270 B-12 | GM xem được chênh lệch kiểm kê (`count.view_variance`) | **Đạt một phần** — quyền đã mở (không còn dòng chặn), nhưng chưa có số chênh lệch thật để đối chiếu (cần đợt có tồn) |
| Q270 B-15 | Thủ kho mở được chi tiết PO | **Đạt** |
| Q270 B-4 | Thủ kho mở được /inventory/waste/new | **Đạt** |
| Q270 | Thủ kho thấy được giá trị tồn (`stock.view_value`) | **Không kiểm được** — trang trống ẩn hẳn bảng (cần tồn > 0) |
| Q270 B-26 | HK vẫn không thấy tồn lý thuyết minibar | **Đạt** (3a + 3b) |
| — | Receiver vẫn không thấy PO/giá | **Đạt** (4a; 4b gián tiếp + V1 đã kiểm màn trong) |

## 7. Lệnh đã chạy

```text
Trình duyệt cloud: 5 tài khoản uat.* (gm → storekeeper → hk_supervisor → hk_attendant → receiver), 10:55–11:00 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
