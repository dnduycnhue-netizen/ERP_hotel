# C5 — Minibar thu tiền (cấp tồn kho phòng 101 + thu 140.000đ)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Kết quả: **KHÔNG ĐẠT** — không có đường giao diện nào để nhập hàng vào kho minibar tổng (MINIBAR_MAIN): màn nhận hàng mobile thiếu kho này trong ô Kho nhận, còn giao diện desktop không có hành động nhận hàng nào (chỉ đẩy về mobile). Vì vậy các bước cấp bù phòng 101, thu tiền phiếu MB-...-0001 và kiểm báo cáo Minibar đều **không kiểm được**. Riêng bước kiểm 0 món (B-39) **ĐẠT** — đã gửi được phiếu phòng 104 với 0 món thiếu.
- Nhánh `feat/muse-cycle`, commit `T-C5:` (ghi sau khi gate xanh).

## Từng bước

### Bước 1 — Tạo PR mua hàng minibar: ĐẠT
- uat.purchaser@erp.internal tạo PR **PR-TEST47-LE-2611-0007**, NHÁP → CHỜ DUYỆT ("Đã gửi duyệt.", bước duyệt "1. Quản lý — Chờ duyệt"). 7 dòng: Tiger (MB-TIGER) 10 lon, Diet Coke (MB-DIETCOKE) 10 lon, Lavie (MB-LAVIE) 10 chai, Coca-Cola (MB-COCA) 10 lon, Larue (MB-LARUE) 10 lon, Sprite (MB-SPRITE) 10 lon, Rượu vang (MB-VANG) 2 chai. Tên thật trong danh mục: "Tiger", "Lavie", "Larue" (không có chữ "Bia"/"Nước suối"). Form tạo PR không có ô chọn nhà cung cấp — NCC chỉ chọn ở bước tạo PO.

### Bước 2 — Duyệt PR + tạo PO + gửi NCC: ĐẠT
- (a) uat.gm@erp.internal duyệt PR-...-0007: CHỜ DUYỆT → ĐÃ DUYỆT ("Quản lý — Đã duyệt · UAT Tổng quản lý · 13:42:36 14/11/2026", "Đã duyệt.").
- (b) uat.purchaser@erp.internal bấm "Tạo đơn mua từ yêu cầu", chọn NCC-T047 ("Nhà cung cấp T047 (NCC-T047)") → tạo PO **PO-TEST47-LE-2611-0006**, NHÁP, tổng ban đầu 0 đ. Cả 7 dòng đều "Giá tay", cột "Giá trần" đều "—" (không có giá trần dòng nào) → đã nhập giá tay kiểm thử: Tiger 20.000, Diet Coke 15.000, Lavie 8.000, Coca-Cola 15.000, Larue 15.000, Sprite 15.000, Rượu vang 150.000 (đồng/lon, chai). Tổng PO sau nhập giá: **1.180.000 đ**. "Gửi duyệt" → CHỜ DUYỆT ("Đã gửi duyệt."). Vì dùng giá tay nên PO có 2 bước duyệt (khác PR chỉ 1 bước): 1. Quản lý, 2. Tổng quản lý — cả hai bước đều do uat.gm@erp.internal duyệt (13:44:56 và 13:45:14 14/11/2026, "Đã duyệt."), PO thành ĐÃ DUYỆT. Purchaser bấm "Gửi cho nhà cung cấp" → "Xác nhận" → PO thành **ĐÃ GỬI** ("Đã gửi cho nhà cung cấp.", tổng 1.180.000 đ).

### Bước 3 — Nhận hàng vào kho minibar tổng: KHÔNG ĐẠT (KẸT, DỪNG BÀI)
- uat.receiver@erp.internal, màn mobile `/m/<uuid>/receive`: mở nhiệm vụ "PO-TEST47-LE-2611-0006 — Nhà cung cấp T047, 7 dòng" → hộp thoại "Mở phiếu nhận hàng", ô "Kho nhận" chỉ có đúng 3 lựa chọn: "Kho bếp (Demo) (KHO_BEP)", "Kho nhà hàng (Demo) (KHO_NH)", "Kho chính T047 (KHO-T047)" — **không có "Kho minibar tổng (MINIBAR_MAIN)"**. Kiểm tra lại lần 2 sau khi tải lại trang, kết quả y hệt. Ô "Nhận thẳng ra kho bếp" cũng chỉ có "—", "Kho nhà hàng (Demo) (KHO_NH)", "Kho chính T047 (KHO-T047)". Không có thông báo chặn nào — lựa chọn kho minibar tổng đơn giản là không tồn tại trong danh sách. Đã hủy hộp thoại, không nhận dòng nào, không ghi sổ, không nhập PIN. PO vẫn ĐÃ GỬI, đang chờ nhận.
- Đã đối chiếu: kho MINIBAR_MAIN **có tồn tại** trong Danh mục "Kho & Điểm dịch vụ" (`/master/warehouses`): "MINIBAR_MAIN — Kho minibar tổng — Kho minibar tổng (Minibar Main)"; các kho phòng MINIBAR_101, MINIBAR_104 cũng tồn tại; KHO-T047 là "Kho tổng (Main)". Lỗi là màn nhận hàng mobile không đưa kho minibar tổng vào danh sách kho nhận, chứ không phải kho chưa được tạo.

### Bước A (tiếp tục) — Thử nhận hàng bằng giao diện desktop: KHÔNG ĐẠT
- uat.receiver@erp.internal không mở được chi tiết PO trên desktop: cả danh sách `/procurement/po` và chi tiết `/procurement/po/5cce249f-c807-4983-8ecd-90ad1c9d3a1f` (PO-...-0006) đều trả về trang "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn" (đã thử 2 lần, sau khi tải lại trang vẫn vậy). Ô tìm kiếm chức năng của receiver với "Đơn mua hàng", "Nhận hàng", "Mua hàng" đều trả "Không tìm thấy chức năng nào".
- Kiểm tra thêm bằng tài khoản owner (chỉ xem): chi tiết PO mở được, xác nhận PO-...-0006 đang "ĐÃ GỬI", NCC T047, 1.180.000 đ, 7 dòng, tất cả "Đã nhận: 0". Nhưng ngay cả với owner, trên chi tiết PO desktop cũng **không có nút/hành động "Nhận hàng" hay "Mở phiếu nhận"** — hành động duy nhất là "Đóng đơn". Màn hub `/receiving` của desktop chỉ có 3 thẻ: "Danh sách phiếu nhận", "Phiếu trả hàng NCC", "Nhận hàng trên mobile" (mở nhiệm vụ nhận hôm nay trên màn hình hiện trường — tức vẫn đi về màn mobile); danh sách phiếu nhận `/inventory/receipts` không có nút tạo phiếu mới.
- Kết luận: đường desktop cũng không nhận được vào kho minibar tổng — không phải chỉ vì ô kho thiếu MINIBAR_MAIN, mà còn vì (1) receiver không mở được trang PO trên desktop, (2) chi tiết PO trên desktop không có hành động nhận hàng, (3) luồng nhận hàng của desktop đẩy về màn mobile vốn đã thiếu kho này.
- Mở lại màn mobile đối chiếu (receiver, chỉ xem): ô "Kho nhận" vẫn chỉ có đúng 3 kho nêu trên; danh mục kho của TEST47 gồm: DISPOSAL, KHO_BEP, KHO_NH, KHO-T047, MINIBAR_101, MINIBAR_104, MINIBAR_MAIN, QUARANTINE, TRANSIT, TROLLEY_1, TROLLEY_2.

### Bước 4 — Kiểm tra tồn kho minibar tổng: KHÔNG KIỂM ĐƯỢC
Chưa thực hiện (do dừng ở bước 3); tồn kho MINIBAR_MAIN vẫn 0 vì chưa nhận hàng.

### Bước 5 — Cấp bù cho phòng 101: KHÔNG KIỂM ĐƯỢC
Chưa thực hiện; chưa cấp bù phòng 101, tồn phòng 101 vẫn 0.

### Bước 6 — Thu tiền phiếu MB-...-0001: KHÔNG KIỂM ĐƯỢC
Chưa thực hiện; phiếu MB-TEST47-LE-2611-0001 vẫn "Chờ thu tiền" 140.000 đ như trạng thái đầu, chưa thu.

### Bước 7 — Kiểm tra báo cáo Minibar: KHÔNG KIỂM ĐƯỢC
Chưa thực hiện; không có số liệu báo cáo minibar 01–14/11/2026 nào được ghi nhận trong lần kiểm này.

### Bước 8 — Phiếu 0 món (B-39, đã sửa ở Q273): ĐẠT
- uat.hk_attendant@erp.internal, màn kiểm minibar mobile, phiếu phòng 104 MB-TEST47-LE-2611-0002 đang "Chưa kiểm". Để tất cả số lượng thiếu = 0 (7 món hiển thị 0: Coca-Cola 25.000, Diet Coke 25.000, Larue 25.000, Lavie 15.000, Sprite 25.000, Tiger 35.000, Rượu vang 245.000 — tất cả giá theo bảng giá ngày kiểm), "Đã nhập thiếu: 0/7", "Tạm tính 0 đ". Ban đầu nút "Gửi kết quả kiểm" bị vô hiệu; sau khi tích ô "Phòng không dùng món nào (xác nhận đã kiểm đủ)" nút bật lên. Bấm "Gửi kết quả kiểm" → gửi thành công, không có thông báo chặn nào. Kiểm lại: phiếu chuyển sang "Đã kiểm", chi tiết phiếu hiển thị "MB-TEST47-LE-2611-0002 · 2026-11-13 · Chờ thu tiền", "Tổng tiền 0 đ", "Chưa có dòng thiếu nào"; danh sách minibar: "Chờ kiểm: 0 · Đã kiểm: 2" (phòng 104 — 0 đ; phòng 101 — MB-TEST47-LE-2611-0001 — 140.000 đ). **Bản sửa B-39 của Q273 đã được xác minh: phiếu 0 món gửi được.**

## Lỗi / bất thường mới

1. **C5-N1 [Nhận hàng — P1]** — Không có đường giao diện nào để nhập hàng vào kho minibar tổng: màn nhận hàng mobile thiếu MINIBAR_MAIN trong ô Kho nhận dù kho tồn tại trong danh mục; giao diện desktop không có hành động nhận hàng (chi tiết PO chỉ có "Đóng đơn", hub `/receiving` đẩy về mobile). Hệ quả: kho minibar không thể nhập hàng bằng giao diện → không thể cấp bù phòng → phiếu MB-...-0001 (140.000 đ) không thu được (B-3 vẫn mở, chưa có cách giải quyết bằng giao diện). Tái hiện: receiver → `/m/<uuid>/receive` → mở PO-...-0006 → hộp thoại "Mở phiếu nhận hàng" → ô "Kho nhận" chỉ có Kho bếp (Demo), Kho nhà hàng (Demo), Kho chính T047.
2. **C5-N2 [Quyền — P3, đã biết từ C6 bước 4]** — Receiver bị chặn xem PO trên desktop bằng trang 404 chung (không phải thông báo chặn quyền): receiver → `/procurement/po` hoặc `/procurement/po/5cce249f-c807-4983-8ecd-90ad1c9d3a1f` → "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn"; owner mở cùng URL thì xem được bình thường.
3. **C5-N3 [Nhận hàng — P2]** — Chi tiết PO trên desktop không có hành động nhận hàng (chỉ có "Đóng đơn"); hub `/receiving` chỉ có 3 thẻ (Danh sách phiếu nhận / Phiếu trả hàng NCC / Nhận hàng trên mobile). Toàn bộ luồng nhận hàng đi qua màn mobile duy nhất.
4. **C5-N4 [Giao diện — P3, đã biết từ V10-N6]** — Menu bên / bảng điều khiển hiển thị không ổn định giữa các lần tải (cả receiver lẫn owner): ngay sau đăng nhập menu đầy đủ phân hệ, sau khi tải lại trang chỉ còn "Tổng quan" và "Danh mục"; không dùng được làm căn cứ phân quyền.
5. **C5-N5 [Dữ liệu — P3, đã biết từ C2-N2]** — Danh sách phiếu nhận có nhiều phiếu nháp trùng cho cùng một PO: `/inventory/receipts` hiển thị GRN-...-0010, -0009, -0007 đều "Nháp", cùng PO-TEST47-LE-2611-0005, cùng 1 dòng.
6. **C5-N6 [Dữ liệu — P3]** — Giá trên PR-TEST47-LE-2611-0007 khác giá trên PO ở 2 dòng: Lavie PR 10.000/chai so với PO 8.000/chai; Rượu vang PR 380.000/chai so với PO 150.000/chai (các dòng còn lại khớp; tổng PO 1.180.000 đ khớp với số lượng × đơn giá trên PO). Cần Claude Code xác nhận giá dòng trên PR lấy từ đâu (giá tham khảo/gần nhất?) — chưa kết luận là lỗi.

## Trạng thái dữ liệu sau bài
- PR-TEST47-LE-2611-0007 ĐÃ DUYỆT; PO-TEST47-LE-2611-0006 ĐÃ GỬI (NCC-T047, 1.180.000 đ, 7 dòng) và đang chờ nhận — có thể tiếp tục từ bước nhận ngay khi lỗi danh sách kho được sửa, không cần tạo lại PR/PO.
- MB-TEST47-LE-2611-0002 (phòng 104) đã gửi với 0 món thiếu → "Đã kiểm", 0 đ, "Chờ thu tiền".
- MB-TEST47-LE-2611-0001 (phòng 101) vẫn "Chờ thu tiền" 140.000 đ, chưa thu. Tồn MINIBAR_MAIN = 0, tồn phòng 101 = 0.
