# M9 — Ma trận quyền 9 tài khoản UAT (TEST47)

- Ngày kiểm tra: 13/11/2026, 22:41–23:04 (3 đợt, trình duyệt cloud, lần lượt từng tài khoản).
- App live: https://erphotel.vercel.app — Khách sạn test T047 (TEST47), UUID `b0000000-0000-4000-8000-000000000002`.
- Tài khoản: 9 tài khoản `uat.*@erp.internal` (owner, gm, accountant, purchaser, chef, hk_supervisor, front_desk, receiver, storekeeper). Đăng nhập bằng cách nhập tay email + mật khẩu, xác nhận đúng tài khoản qua menu người dùng trước mỗi đợt.
- Phạm vi: chỉ xem, không tạo/sửa/xóa dữ liệu, không bấm nút ghi/chuyển trạng thái, không gửi form — trừ một tác động phụ ở phần C (mở phiếu nhận PO-0001 tạo phiếu nháp GRN-...-0005, xem mục "Tác động dữ liệu").
- Kết quả tổng: **180/180 URL đã mở. Không có lỗi 500 ở bất kỳ lượt nào. Không có URL nào bị chuyển hướng. Không có màn bị chặn nào lộ danh sách chứng từ hay số tiền.**

## A. Số mục menu và số URL mở được theo tài khoản

| Tài khoản | Vai trò (compact) | Mục menu | URL mở được /20 |
|---|---|---|---|
| uat.owner | sm_owner | 15 | 20 |
| uat.gm | sm_manager | 15 | 16 |
| uat.accountant | sm_accountant | 11 | 10 |
| uat.purchaser | sm_purchasing_store | 6 | 10 |
| uat.chef | sm_kitchen | 6 | 8 |
| uat.hk_supervisor | sm_housekeeping | 7 | 6 |
| uat.front_desk | sm_frontdesk | 6 | 7 |
| uat.receiver | (chưa gán compact) | 2 | 3 |
| uat.storekeeper | sm_purchasing_store | 4 | 6 |

Tổng cộng 86/180 ô mở được. Cả 9 tài khoản đều chỉ thấy duy nhất TEST47; mở "/" đều về TEST47, không thấy khách sạn khác.

## B. Menu trái theo tài khoản (bộ đã ổn định sau khi chuyển trang)

- **owner / gm (15 mục, giống hệt nhau):** Tổng quan | Thu mua, Nhận hàng, Kho, Tài chính, Nhà hàng | Minibar — Lễ tân, Số liệu PMS ngày, Minibar — Buồng phòng, Tiêu chuẩn phòng, Ca xe đẩy | Báo cáo, Cảnh báo | Danh mục, Quản trị hệ thống.
- **accountant (11):** Tổng quan | Thu mua, Kho, Tài chính, Nhà hàng | Minibar — Lễ tân, Số liệu PMS ngày, Minibar — Buồng phòng | Báo cáo, Cảnh báo | Danh mục. Thiếu so với owner/GM: Nhận hàng, Tiêu chuẩn phòng, Ca xe đẩy, Quản trị hệ thống.
- **purchaser (6):** Tổng quan | Thu mua, Nhận hàng, Kho, Tài chính | Danh mục.
- **chef (6):** Tổng quan | Thu mua, Nhận hàng, Kho, Nhà hàng | Danh mục.
- **hk_supervisor (7):** Tổng quan | Kho | Minibar — Buồng phòng, Tiêu chuẩn phòng, Ca xe đẩy | Cảnh báo | Danh mục.
- **front_desk (6):** Tổng quan | Kho | Nhà hàng, Minibar — Lễ tân, Số liệu PMS ngày | Danh mục.
- **receiver (2):** Tổng quan | Danh mục.
- **storekeeper (4):** Tổng quan | Nhận hàng, Kho | Danh mục.
- Menu mobile (thanh dưới) khác nhau: purchaser: Nhận hàng, Kiểm kê; chef: Nhận hàng, Kiểm kê, Nhà hàng; hk_supervisor: Buồng phòng, Minibar.

## C. Ma trận 9 tài khoản × 20 URL

Ký hiệu: **T** = mở được + thấy dữ liệu; **K** = mở được, trống/không có dòng; **H** = mở được, trang trung tâm (hub, chỉ có liên kết/thẻ); **C** = bị chặn tại chỗ (thông báo không có quyền); **404** = trang "Không tìm thấy trang". URL đầy đủ dạng `/<uuid>/...` (desktop) và `/m/<uuid>/...` (mobile); `/admin/...` không có uuid.

| # | URL | owner | gm | accountant | purchaser | chef | hk_sup | front_desk | receiver | storekeeper |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | /procurement/pr | T (5 PR) | T | T | T (5 PR) | T (5 PR) | 404 | 404 | 404 | 404 |
| 2 | /procurement/po | T (4 PO) | T | T | T (4 PO) | C | 404 | 404 | 404 | 404 |
| 3 | /procurement/approvals | K | K | C | K (thông báo) | C | 404 | 404 | 404 | 404 |
| 4 | /receiving | H | 404 | H | H | H | 404 | 404 | 404 | H |
| 5 | /inventory/stock | K (0) | K (0) | C | K (0) | K (0) | C | K (0) | 404 | K (0) |
| 6 | /inventory/counts | K | K | K | K | K | K | K | 404 | K |
| 7 | /finance/invoices | K | K | K | K | 404 | 404 | 404 | 404 | 404 |
| 8 | /finance/payment-requests | K | K | K | K | 404 | 404 | 404 | 404 | 404 |
| 9 | /finance/payables | K (0 đ) | K | K | C | 404 | 404 | 404 | 404 | 404 |
| 10 | /restaurant | H | H | 404 | 404 | H | 404 | H | 404 | 404 |
| 11 | /frontdesk/minibar | T (1 phiếu) | T | K | 404 | 404 | 404 | T (2 phiếu) | 404 | 404 |
| 12 | /housekeeping/minibar | T (giá 7 món) | T | 404 | 404 | 404 | T (giá 7 món) | 404 | 404 | 404 |
| 13 | /reports | T (12) | T (12) | T (2/12) | K | K | K | K | K | K |
| 14 | /admin/users | T (chỉ mình) | T (chỉ mình) | C | C | C | C | C | C | C |
| 15 | /admin/settings | T | T | C | C | C | C | C | C | C |
| 16 | /m/receive | T (2 PO) | C | C | C | C | C | C | T (2 PO) | T (2 PO) |
| 17 | /m/count | K | K | K | K | K | K | K | K | K |
| 18 | /m/minibar | T (1 phiếu) | 404 | 404 | 404 | 404 | T (2 phiếu) | 404 | 404 | 404 |
| 19 | /m/restaurant | T | T | 404 | 404 | H | 404 | H | 404 | 404 |
| 20 | /m/trolley | T (3 ca) | 404 | 404 | 404 | 404 | K | 404 | 404 | 404 |

Ghi chú theo ô:
- **#1 PR:** 5 yêu cầu PR-TEST47-2608-0001…0005; chef thấy cả 5 PR gồm PR do người khác tạo (danh sách PR không có cột tiền — tốt). Người tạo: UAT Thu mua, UAT Bếp trưởng, Test Purchaser.
- **#2 PO:** 4 đơn PO-…-0001…0004. **Số tiền do agent đợt 2 báo (0004: 450.000đ, 0003: 800.000đ, 0002: 600.000đ, 0001: 1.040.000đ) MÂU THUẪN với giá trị đã biết (PO-0002 = 1.040.000đ, PO-0003 = 1.000.000đ, PO-0004 là PO chợ với ước tính 500.001đ) — coi là CHƯA XÁC MINH, có thể agent đọc nhầm cột; cần đối chiếu lại khi mở danh sách PO ở M1/M2.** Đợt 2 còn báo PO-0001 "Chờ duyệt" trong khi đã xác minh PO-0001 ở trạng thái `sent` từ 12/11 — cũng chưa xác minh, có thể đọc nhầm.
- **#3 approvals:** owner/GM mở được, trống ("Không có chứng từ nào chờ bạn duyệt"). Accountant và purchaser thấy thông báo "Bạn không có quyền duyệt chứng từ nào" + "Việc duyệt do Quản lý và Chủ đầu tư đảm nhiệm. Bạn chỉ cần tạo và gửi duyệt chứng từ của mình." Chef bị chặn hẳn ("Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này.").
- **#5 stock:** tất cả các ô mở được đều "0 mặt hàng". GM, purchaser, front_desk, storekeeper thấy ghi chú "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng." Accountant và hk_supervisor bị chặn hẳn ("Bạn chưa được cấp quyền xem tồn kho."). Nút "Cập nhật giá" hiện ở trạng thái tắt với purchaser (không bấm).
- **#7 invoices:** purchaser mở được, trống, nhưng ô lọc "Nhà cung cấp" liệt kê tên 16 nhà cung cấp (xem mục D.5).
- **#9 payables:** owner thấy tổng 0 đ, bộ lọc hiện tên 16 NCC. Purchaser bị chặn ("Bạn chưa được cấp quyền xem công nợ.").
- **#11 frontdesk/minibar:** owner/GM thấy 1 phiếu MB-TEST47-LE-2611-0001 (phòng 101, 0 đ). **Accountant mở được nhưng trống — KHÔNG thấy phiếu MB-...-0001.** front_desk thấy 8 phòng 101–306 và 2 phiếu "Chờ thu tiền": MB-...-0001 (phòng 101) và MB-...-0002 (phòng 104), đều 0 đ; có nút "Yêu cầu kiểm" (không bấm).
- **#12 housekeeping/minibar:** owner/GM/hk_supervisor thấy bảng giá 7 món: Bia Tiger 35.000đ, Diet Coke 25.000đ, Nước suối Lavie 15.000đ, Sprite 25.000đ, Coca-Cola 25.000đ, Rượu vang 245.000đ, Bia Larue 25.000đ (hiệu lực từ 2026-11-11); tồn kho trống. GM thấy thêm "Lãi gộp chưa tính được vì giá vốn cần quyền xem giá trị tồn (stock.view_value)." HK thấy "Tồn minibar từng phòng" bị ẩn với câu "Bạn chưa có quyền xem số lượng tồn (stock.view_qty) nên màn này không hiển thị tồn kho phòng."; "Bổ sung theo tầng: Tầng 1 (10 phòng), Tầng 2 (14 phòng), Tầng 3 (6 phòng)"; "Thu hồi hàng sắp hết hạn: Không có hàng minibar nào trong phòng sắp hết hạn." — **giá minibar trên TEST47 ĐÃ CÓ (xác nhận cho M1, yêu cầu (c)).**
- **#13 reports:** owner/GM thấy 12 mục báo cáo; accountant chỉ thấy 2 ("Tuổi nợ & dòng tiền chi", "Chi phí vận hành"). 6 tài khoản còn lại mở được nhưng trống, kèm CẢ HAI câu "Bạn chưa được cấp quyền xem báo cáo nào." và "Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên." (xem D.3).
- **#14 /admin/users:** owner và GM mở được nhưng chỉ thấy 1 dòng là chính mình (UAT-OWNER / UAT-GM, "Đang dùng"). 7 tài khoản còn lại bị chặn ("Bạn chưa được cấp quyền quản trị").
- **#15 /admin/settings:** owner và GM mở được, thấy các ngưỡng cấu hình (chỉ xem, không bấm Lưu). 7 tài khoản còn lại bị chặn như #14.
- **#16 /m/receive:** owner thấy 2 PO chờ nhận (PO-...-0001, PO-...-0002). Receiver và storekeeper thấy danh sách "2 phiếu chờ nhận" giống nhau (xem phần E). GM, accountant, purchaser, chef, hk_supervisor, front_desk đều bị chặn ("Bạn chưa được cấp quyền receiving.perform để thực hiện thao tác này.").
- **#18 /m/minibar:** hk_supervisor thấy "Kiểm minibar — Chờ kiểm: 2 · Đã kiểm: 0 — Chờ kiểm (2): Phòng 104 MB-TEST47-LE-2611-0002 · Trả phòng, Chưa kiểm; Phòng 101 MB-TEST47-LE-2611-0001 · Trả phòng, Chưa kiểm." (không hiện số tiền).

## D. Thông báo nguyên văn (dùng chung)

- 404: tiêu đề "Không tìm thấy trang", nội dung "Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn.", nút "Về tổng quan".
- Thiếu receiving.perform: "Không thể tải dữ liệu" / "Bạn chưa được cấp quyền receiving.perform để thực hiện thao tác này."
- Thiếu quyền xem tồn kho: "Không thể tải dữ liệu" / "Bạn chưa được cấp quyền xem tồn kho."
- Thiếu quyền xem công nợ: "Không thể tải dữ liệu" / "Bạn chưa được cấp quyền xem công nợ."
- Thiếu quyền quản trị: "Bạn chưa được cấp quyền quản trị" / "Tài khoản này chưa được cấp quyền quản lý vai trò hoặc người dùng. Hãy liên hệ quản trị viên."
- Không có quyền duyệt: "Bạn không có quyền duyệt chứng từ nào" / "Việc duyệt do Quản lý và Chủ đầu tư đảm nhiệm. Bạn chỉ cần tạo và gửi duyệt chứng từ của mình."
- Thiếu quyền xem giá trị tồn (ghi chú trong trang): "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng."
- Báo cáo: "Bạn chưa được cấp quyền xem báo cáo nào." + "Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên."

## E. Kiểm tra riêng — Nhận hàng mù (receiver) — ✅ ĐẠT

Ba màn đã xem, đều KHÔNG thấy số lượng đặt và KHÔNG thấy đơn giá:

1. **Danh sách PO chờ nhận** (`/m/<uuid>/receive`): "Nhiệm vụ nhận hàng hôm nay", "2 phiếu chờ nhận". Thẻ 1: "NCC T047", "PO-TEST47-LE-2611-0001 · 2 dòng", "Ngày hẹn giao: 12/11/2026", nhãn "Hợp đồng". Thẻ 2: "Công ty TNHH Thực phẩm Mẫu An Phát", "PO-TEST47-LE-2611-0003 · 1 dòng", "Ngày hẹn giao: 13/11/2026", nhãn "Hợp đồng". **PO-TEST47-LE-2611-0002 không có trong danh sách** (đúng — PO này vẫn ở trạng thái nháp, chưa gửi cho NCC nên chưa thể nhận). Trên danh sách chỉ có số dòng, nhà cung cấp, ngày hẹn giao.
2. **Hộp thoại khi mở thẻ PO-0001:** "Mở phiếu nhận hàng", "Chọn kho nhận rồi mở phiếu nháp cho đơn này.", "Kho nhận" = "Kho bếp (Demo) (KHO_BEP)", "Nhận thẳng ra kho bếp" = "Kho bếp (Demo) (KHO_BEP)", nút "Hủy" / "Mở phiếu nhận". Không thấy số lượng đặt, không thấy đơn giá.
3. **Màn nhập dòng nhận hàng** (sau khi bấm "Mở phiếu nhận" chỉ để xem, không nhập số, không bấm ghi): `/m/<uuid>/receive/340acb0b-1aa8-47eb-bd74-d2849f495127`, tiêu đề "Phiếu nhận hàng GRN-TEST47-LE-2611-0005", "PO-TEST47-LE-2611-0001 · NCC T047", "Đã ghi 0/2 dòng". Dòng 1: "ba chỉ nách", "Đặc tả: Thịt & Cá", "kg · Bắt buộc chụp ảnh", các ô "Số cân (gross) —", "Bì (tare) —", "Số thực nhận (net) —", "Thực nhận = Tổng cân − Bì.", "Bắt buộc chụp ảnh* / Chưa chụp ảnh", nút "Chụp ảnh", "Kết quả QC" (Đạt / Không đạt / Chờ quyết định), "Chưa có mẫu checklist cho nhóm hàng này.", "Nhiệt độ (°C) —". Dòng 2: "Bánh bèo", "Đặc tả: Thực phẩm tươi sống & khô", "cai · Bắt buộc chụp ảnh", các ô cân cũng "—". Nút "Ghi dòng" đang tắt ở cả 2 dòng; cuối màn "Đã ghi 0/2 dòng", "Còn dòng chưa ghi — ghi đủ các dòng trước khi ghi sổ.", nút "Ghi sổ nhận hàng" đang tắt. Đã cuộn xuống cuối màn: **không thấy số lượng đặt của PO và không thấy đơn giá ở bất cứ đâu** — chỉ có tên mặt hàng, nhóm đặc tả, đơn vị (kg / cai) và các ô cân đang trống "—".
4. Receiver mở `/<uuid>/inventory/receipts` thì **404** — receiver không thấy danh sách phiếu nhận qua đường desktop.

**Kết luận: nhận hàng mù được giữ trên cả 3 màn (danh sách PO chờ, hộp thoại mở phiếu, màn nhập cân). Đây là điểm kiểm tra quan trọng nhất của M9 — ĐẠT.**

## F. Phát hiện (theo mức độ)

1. **Menu trái hiện bộ mục của tài khoản TRƯỚC ĐÓ ngay sau khi đăng nhập — lỗi thật, mức trung bình.** Quan sát lặp lại ở cả 6 lần đổi tài khoản (đợt 2 và đợt 3): vừa đăng nhập xong, menu hiển thị bộ mục của phiên/tài khoản trước — ví dụ purchaser lúc đầu hiện thêm "Số liệu PMS ngày, Báo cáo, Cảnh báo"; hk_supervisor lúc đầu hiện giống menu của chef; front_desk lúc mới vào hiện bộ 7 mục của hk_supervisor; receiver lúc mới vào hiện bộ 6 mục của front_desk; storekeeper lúc mới vào hiện bộ 2 mục của receiver. Sau khi chuyển sang một trang khác, menu mới đổi thành bộ đúng của tài khoản đang đăng nhập (đã kiểm tra lại ở trang tổng quan cuối mỗi đợt). Các mục menu cũ chỉ hiển thị tên, agent không bấm vào chúng — nhưng người dùng thật có thể bấm; cần kiểm tra xem bấm vào mục menu cũ có mở được màn không hay bị chặn ở route guard. **Lớp: UI. Chuyển Claude Code.**
2. **/reports hiện đồng thời thông báo "không có quyền" VÀ "Đã xảy ra lỗi khi tải dữ liệu" — dấu hiệu lỗi tải thật, mức trung bình.** Xảy ra ở cả 9 tài khoản (owner/GM thấy đủ 12 báo cáo nên không gặp; accountant thấy 2 báo cáo, không báo lỗi; 6 tài khoản còn lại đều gặp cả 2 câu). Có thể trang cố tải danh sách báo cáo và lỗi thật, không chỉ do thiếu quyền. **Lớp: UI/DB-RPC (cần soi code). Chuyển Claude Code.**
3. **Mâu thuẫn menu ↔ quyền ở route — mức thấp (nhất quán giao diện).** GM: menu hiện "Nhận hàng" nhưng gõ trực tiếp /receiving ra 404. Accountant: menu KHÔNG hiện "Nhận hàng" nhưng /receiving lại mở được trang trung tâm; ngược lại menu hiện "Nhà hàng" nhưng /restaurant ra 404. hk_supervisor: menu có "Kho" nhưng /inventory/stock bị chặn. **Lớp: UI. Chuyển Claude Code.**
4. **Mở lại PO đã có phiếu nháp thì tạo THÊM phiếu nháp mới — xác nhận lại phát hiện của demo test, mức trung bình (dữ liệu).** Việc bấm "Mở phiếu nhận" cho PO-0001 đã tạo GRN-TEST47-LE-2611-0005 (0/2 dòng) dù đã có GRN-...-0003 (demo test) và GRN-...-0001 (Day 1) cho cùng PO. TEST47 hiện có các phiếu nháp trùng: GRN-...-0001, -0002 (Day 1), -0003, -0004 (demo test), -0005 (M9). Cần cơ chế mở lại phiếu nháp đang có thay vì tạo mới. **Lớp: UI/DB-RPC. Chuyển Claude Code.**
5. **Ô lọc (filter dropdown) lộ tên danh mục trên màn trống — mức thấp.** Purchaser ở /finance/invoices: danh sách trống nhưng ô lọc "Nhà cung cấp" liệt kê tên 16 nhà cung cấp. Purchaser và chef ở /inventory/stock: bộ lọc liệt kê tên 8 kho (Kho bếp Demo, Kho chính T047, Kho minibar tổng, Kho nhà hàng Demo, Minibar phòng 101, Minibar phòng 104, Xe đẩy 1 Demo, Xe đẩy 2 Demo) dù số lượng/giá trị tồn bị ẩn. Không lộ số tiền hay chứng từ. **Lớp: UI. Chuyển Claude Code (quyết định có nên ẩn).**
6. **Trang tổng quan hiện thẻ quản trị + số liệu tổng hợp cho mọi vai trò — mức thấp.** 4 thẻ "Người dùng & Phân quyền", "Cấu hình & Quy tắc duyệt", "Kho & Điểm dịch vụ", "Hệ thống & Thiết bị" và các số liệu "Mặt hàng danh mục 672", "Kho hoạt động 8", "Nhóm hàng hóa 15", "Vai trò hệ thống 24", "Đơn đang chờ 0" giống hệt nhau ở cả 9 tài khoản, dù 7/9 tài khoản bị chặn ở /admin/users và /admin/settings (đích đến của thẻ chưa được bấm kiểm tra). **Lớp: UI. Chuyển Claude Code (quyết định có nên ẩn thẻ theo quyền).**
7. **Trang 404 không nhất quán — mức thấp (giao diện).** Với chef và hk_supervisor, trang 404 không hiển thị thanh điều hướng trái; với purchaser trang 404 vẫn hiển thị menu trái. **Lớp: UI.**
8. **HK thấy bảng giá minibar nhưng không thấy tồn kho phòng — mức thấp (nhất quán quyền).** HK xem được bảng giá 7 món ở /housekeeping/minibar trong khi "Tồn minibar từng phòng" của chính mình bị ẩn vì thiếu quyền stock.view_qty. Nếu giá được coi là nhạy cảm như số lượng thì cần chặn cả hai; nếu không thì đây là thiết kế. **Lớp: quyền/dữ liệu. Chuyển Claude Code (quyết định).**
9. **Accountant mở được /frontdesk/minibar nhưng trống — không thấy phiếu MB-...-0001 mà owner/GM/front_desk thấy.** Có thể do RLS theo vai trò (kế toán chỉ thấy phiếu đã thu tiền?) hoặc do lọc trạng thái. Cần đối chiếu với thiết kế quyền minibar. **Lớp: quyền/dữ liệu. Chuyển Claude Code.**
10. **Số liệu PO do agent đợt 2 báo mâu thuẫn với giá trị đã biết — chưa xác minh, không kết luận.** Xem ghi chú ở mục C, dòng #2. Cần đối chiếu lại danh sách PO khi chạy M1/M2.

## G. Tác động dữ liệu trong lúc kiểm tra

- **GRN-TEST47-LE-2611-0005** (phiếu nháp, 0/2 dòng) được tạo khi agent mở màn nhập nhận hàng của PO-0001 ở phần E — đây là bước phần C yêu cầu, không nhập số, không chụp ảnh, không bấm "Ghi dòng" hay "Ghi sổ nhận hàng" (cả hai đều đang tắt). Quay lại danh sách thì vẫn "2 phiếu chờ nhận", PO-0001 vẫn ở trạng thái chờ.
- Ngoài ra không tạo/sửa/xóa dữ liệu nào khác, không bấm nút ghi/chuyển trạng thái nào. Cuối mỗi đợt đã đăng xuất tài khoản, trình duyệt dừng ở trang đăng nhập.

## H. Kết luận M9

- **Đạt — ma trận quyền 9×20 đã kiểm tra xong (180/180 URL).** Không có lỗi 500, không có chuyển hướng, không lộ chứng từ/số tiền trên màn bị chặn.
- **Điểm quan trọng nhất (nhận hàng mù) — ĐẠT:** receiver không thấy số lượng đặt và đơn giá trên cả 3 màn.
- **Minibar có giá trên TEST47 — ĐÃ XÁC NHẬN** (7 món, hiệu lực 2026-11-11) — yêu cầu (c) của M1 coi như xong.
- 10 phát hiện cần xử lý (mục F), trong đó 2 lỗi thật đáng chú ý: menu cũ sau đăng nhập (F.1) và /reports lỗi tải (F.2), cùng phát hiện trùng phiếu nháp (F.4) xác nhận lại từ demo test.
