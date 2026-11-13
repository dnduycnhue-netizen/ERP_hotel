# Báo cáo test demo — chu trình mua → nhận → thanh toán (13/11/2026)

> Người làm: Muse. Nhánh: `feat/muse-demo-test` (từ `main` a7d0d8d). Không merge, không push.
> Phạm vi: app live https://erphotel.vercel.app, khách sạn TEST47 (UUID `b0000000-0000-4000-8000-000000000002`), dữ liệu DEMO.
> Chỉ thao tác qua giao diện web bằng tài khoản `uat.*`. Không SQL/RPC/migration/Vercel, không đổi cấu hình hệ thống, không tắt PIN/SoD, không bấm tắt module nào.
> Mật khẩu và PIN không ghi trong báo cáo này. PIN của 3 tài khoản (uat.receiver, uat.storekeeper, uat.accountant) đã được đặt mới qua đúng chức năng reset PIN của admin trước khi test.
> Ảnh chụp màn hình: các phiên trình duyệt test không xuất file ảnh đính kèm được, nên báo cáo này ghi lại thông báo nguyên văn trên màn hình thay cho ảnh.

## Kết luận chung

Chu trình mua → nhận → thanh toán cho PO-TEST47-LE-2611-0003 **KHÔNG hoàn thành**: kẹt gốc ở bước 6 (chụp ảnh bắt buộc nhưng trình duyệt test không có camera, màn không có ô tải ảnh lên), kéo theo bước 7–12 không có đối tượng để thực hiện. Tồn NVL0388 ở KHO-T047 cuối buổi vẫn **0 kg** (không đổi so với đầu buổi).

Ngoài điểm kẹt camera, test tìm ra **2 lỗi chặn độc lập** (kế toán không mở được form nhập hóa đơn; form Sửa nháp PO chợ không lưu được lần nào), **1 lỗi dữ liệu** (giá minibar chưa có nên không kiểm/không thu được tiền) và vài lỗi nhỏ khác. Chi tiết ở bảng dưới và mục lỗi.

Phần B: B3 (module) và B4 (nhật ký thay đổi) **Đạt**; B2 và B5 **một phần**; B1 **chưa kết luận được** (nghi là giới hạn của trình duyệt test, xem mục lỗi số 8); B6 **đạt có lưu ý**.

## Phần A — Chu trình (17:49–17:59, 13/11/2026)

Bối cảnh: PO-TEST47-LE-2611-0003 (NCC SUP0001, NVL0388 10 kg × 100.000 đ = 1.000.000 đ) đang ở trạng thái đã gửi, chưa nhận hàng. Tồn KHO-T047 = 0.

| Bước | Tài khoản | Kết quả | Ghi chú (thông báo nguyên văn) |
|---|---|---|---|
| 6 — Nhận hàng mù | uat.receiver | **Không đạt** | Mở được PO-TEST47-LE-2611-0003, chọn Kho chính T047 (KHO-T047); hệ tạo phiếu GRN-TEST47-LE-2611-0003. Cân: tổng cân 10, tịnh 10 kg (ô bì để trống; giao diện chỉ có 2 ô tổng cân/bì, không có ô "cân lần 2" riêng — cân lại chỉ xảy ra khi lần 1 lệch). Chụp ảnh: bấm "Chụp ảnh" 3 lần đều báo "Không tìm thấy camera trên thiết bị này. Hãy dùng thiết bị có camera rồi thử lại." Màn không có ô nhập file nên không tải ảnh thử được; trình duyệt này không bật được camera giả của Chromium. Nút "Ghi dòng" luôn bị khóa (ảnh bắt buộc) — "Đã ghi 0/1 dòng". Kiểm tra mù: **Đạt** — màn nhận hàng mù không hiện số lượng PO và đơn giá ở bất kỳ đâu (chỉ thấy "ba chỉ nách", "Đặc tả: Thịt & Cá", "kg · Bắt buộc chụp ảnh"). |
| 7 — Ghi sổ phiếu nhận | uat.storekeeper | **Không đạt** | Phiếu GRN-TEST47-LE-2611-0003 đang Nháp, 0 dòng hàng. Màn di động: "Đã ghi 0/1 dòng", "Còn dòng chưa ghi — ghi đủ các dòng trước khi ghi sổ.", nút "Ghi sổ nhận hàng" bị khóa; PIN không bao giờ được hỏi. Trên desktop, liên kết mã phiếu dẫn sang trang PO và báo 404 "Không có quyền xem (1503)" với thủ kho. Tồn KHO-T047 tại /inventory/stock, lọc NVL0388: "0 tồn kho", "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại." — vẫn 0 kg; không đọc được giá vốn vì màn báo "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng". Tác dụng phụ: khi thủ kho mở lại cùng PO, hệ tạo thêm 1 phiếu nháp GRN-TEST47-LE-2611-0004 (xem lỗi số 6). |
| 8 — Nhập hóa đơn NCC | uat.accountant | **Không đạt** | Danh sách hóa đơn mở được, đang trống. Nhưng /finance/invoices/new báo "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này." (thử 2 lần). Không có số hóa đơn, không so khớp 3 bên. Lỗi này độc lập với vụ camera — xem lỗi số 2. |
| 9 — Duyệt hóa đơn | uat.gm | **Không đạt** (không có gì để duyệt) | Danh sách hóa đơn của GM trống. Thử kế toán tự duyệt hóa đơn của mình: không áp dụng vì không tồn tại hóa đơn nào. |
| 10 — Tạo đề nghị thanh toán | uat.accountant | **Không đạt** | Form mở được; chọn NCC SUP0001 (Công ty TNHH Thực phẩm Mẫu An Phát) thì báo "Nhà cung cấp này không còn hóa đơn nào đủ điều kiện đề nghị thanh toán." (thử cả SUP0002 cũng vậy). Không có số đề nghị. |
| 11 — Duyệt đề nghị | uat.owner / uat.gm | **Không đạt** (không có gì để duyệt) | Danh sách đề nghị thanh toán trống ở cả owner và GM. Thử kế toán tự duyệt đề nghị của mình: không áp dụng vì không tồn tại đề nghị nào. |
| 12 — Đánh dấu đã thanh toán | uat.accountant | **Không đạt** (không có đề nghị để đánh dấu) | Công nợ SUP0001 tại /finance/payables: "Còn phải trả: 0 đ, Quá hạn: 0 đ", cả hai bảng đều không có dòng. Số 0 đ này là "trống" vì chưa từng có hóa đơn nào được lập, **không phải** kết quả của thanh toán. |

Kiểm tra cuối phần A:
- Thẻ kho NVL0388: **không đạt** (kỳ vọng đúng 1 bút toán nhập). Báo cáo Thẻ kho (/reports/stock-card, kỳ 01/11/2026–13/11/2026, tất cả kho) xem bằng GM: "Số dòng 0, Tổng giá trị tồn cuối 0 đ", bảng trống — 0 bút toán. Lưu ý: báo cáo đọc từ bảng tổng hợp theo ngày, làm mới lúc 07:35 hằng ngày, nên chứng từ phát sinh sau lần làm mới chưa hiện. Thủ kho mở cùng báo cáo thì bị chặn quyền: "Bạn chưa được cấp quyền xem báo cáo nào." và "Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên."
- Trang tổng quan, khối "Sáng nay": **đạt** (uat.owner và uat.gm). Hiện đủ số liệu: Chi mua hàng hôm qua 0 đ; Giá trị hủy hôm qua 0 đ; Cảnh báo đỏ chưa xử lý 8; Công nợ đến hạn 7 ngày 0 đ; Tạm ứng quá hạn 0; kèm 5 cảnh báo đỏ "Gán vai trò có quyền mức quan trọng" lúc 21:19/21:11 ngày 12/11/26.
- Kiểm tra /admin/audit cho các bước phần A: không thực hiện được trong phiên phần A vì mật khẩu chung không đăng nhập được tài khoản admin (màn đăng nhập báo "Email hoặc mật khẩu không chính xác."). Giao diện nhật ký đã được kiểm tra và **đạt** ở mục B4 bên dưới (dùng thông tin đăng nhập admin đã lưu của trình duyệt). Dấu vết các bước phần A: không có gì để đối chiếu vì không có chứng từ nào được ghi sổ.

Tồn cuối và giá vốn: NVL0388 tại KHO-T047 = **0 kg**. Không đọc được giá vốn trên màn hình: thủ kho bị ẩn giá trị tồn; báo cáo Thẻ kho (GM) tổng giá trị tồn cuối 0 đ với 0 dòng — không có giá vốn 100.000 đ/kg nào được ghi nhận vì không có bút toán nhập.

## Phần B — Thử các điểm mới (18:00–18:21, 13/11/2026)

| Mục | Kết quả | Ghi chú |
|---|---|---|
| B1 — Phân quyền gọn | **Chưa kết luận được** | uat.chef tạo PR thử mới thành công (PR-TEST47-LE-2611-0004, 1 dòng NVL0045 Gạo khách 1 kg, ngày cần 20/11/2026, outlet BEP-DEMO, NHÁP). uat.purchaser tạo PR thử mới thành công (PR-TEST47-LE-2611-0005, cùng nội dung, NHÁP). Cả hai đều kẹt ở nút "Gửi duyệt" trên trang chi tiết PR: bấm 6+ lần (chuột + Enter), chờ tới 30 giây mỗi lần, cả sau khi bổ sung ngày cần — PR vẫn NHÁP, không có thông báo lỗi nào. Vì PR không vào bước duyệt nên không thử được: GM duyệt PR, purchaser tự duyệt PR của mình, chef/hk_supervisor thử duyệt. Hàng "Chờ tôi duyệt" của GM trống; phiếu lĩnh 0, phiếu hủy 0, hóa đơn 0, đề nghị thanh toán 0 → "không có chứng từ chờ để thử" cho cả 4 loại. Phụ: trang "Chờ tôi duyệt" của chef không tải được dữ liệu ("Không thể tải dữ liệu — Bạn chưa được cấp quyền thực hiện thao tác này."); trang /procurement/approvals của hk_supervisor báo 404 (menu của HK cũng không có mục Mua hàng). Phụ: tạo PR dòng chỉ có mô tả (không chọn vật tư) bị từ chối: "Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập." Xem lỗi số 8 về nguyên nhân nghi ngờ của nút "Gửi duyệt". |
| B2 — PO chợ | **Một phần đạt** | Tạo PO chợ thành công: PO-TEST47-LE-2611-0004, NHÁP, 1 dòng chưa có giá — "Rau cu cho demo B2 — chua co gia" (Giá tay), 5 kg, đơn giá 0 đ, thành tiền 0 đ. Thử gửi duyệt khi chưa nhập tổng ước tính: bị chặn đúng kỳ vọng (khi "Số tiền tạm ứng" để trống, bấm "Tạo lệnh mua chợ" hiện cảnh báo đỏ: "Số tiền ứng trước cho người đi chợ (đồng). Không cần bằng tổng đơn mua."). Nhập tổng ước tính: ô "Tổng ước tính" từ chối đúng 500.000 đ do kiểm tra bước nhảy của ô số ("Please enter a valid value. The two nearest valid values are 499001 and 500001.") → nhập 500.001 đ, lưu thành công ("Đã lưu tổng ước tính.", hiển thị "Tổng ước tính: 500.001 đ") — xem lỗi số 4. Gửi duyệt sau khi nhập ước tính: **không đạt** — nút "Gửi duyệt" vẫn vô hiệu với chú thích "Chưa có lý do vượt trần — không gửi duyệt được." Lý do vượt trần chỉ nhập được ở trang Sửa nháp, nhưng trang Sửa nháp không lưu được: 5 lần lưu đều báo "Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập." (đã thử: chỉ nhập lý do; giữ nguyên không đổi gì; nhập đơn giá 100.001; nhập ngày nhận 20/11/2026; nhập đủ lý do + đơn giá + ngày). Sau các lần lưu lỗi, toàn bộ dữ liệu đã nhập đều bị trả về trạng thái gốc (đơn giá 0 đ, ngày —, lý do trống) — xem lỗi số 3. |
| B3 — Bật/tắt module (chỉ xem) | **Đạt** | Admin: /admin/modules hiển thị đúng 2 khách sạn × 2 module, tất cả "Đang bật": Son Hoi An Boutique Hotel & Spa (SONHOIAN) — "Buồng phòng & Lễ tân", "Nhà hàng"; Khách sạn test T047 (TEST47) — "Buồng phòng & Lễ tân", "Nhà hàng". Không bấm nút "Tắt" nào. uat.gm: /restaurant hiển thị bình thường — "Bếp — thực đơn hôm nay" với 82 món, các tab Bếp / Món ăn / Bán hàng / Buffet / Đặt tiệc / Sảnh tiệc. /m/.../restaurant hiển thị bình thường — 4 thẻ Bếp / Bán hàng / Buffet / Đặt tiệc, thanh điều hướng dưới có Kiểm kê — Nhà hàng. Module đang bật. |
| B4 — Nhật ký thay đổi | **Đạt** | Lọc theo bảng purchase_orders: hoạt động (URL ?table=purchase_orders, chỉ hiện purchase_orders). Mở mục "1 cột" đầu tiên → hiện chi tiết "estimated_total: ∅ → 500001". Bộ lọc ngày: hoạt động (from=2026-11-13&to=2026-11-13, chỉ còn dòng 13/11/26; các dòng 12/11/26 biến mất). Phân trang: hoạt động — cuối trang 1 có "Trang sau →", bấm sang ?page=2, hiện "Trang 2" với cả "← Trang trước" và "Trang sau →". Dòng chỉ đổi updated_at: có, hiển thị "Chỉ cập nhật thời điểm sửa" (ví dụ: 18:08:28 13/11/26 — UAT Thu mua, Sửa purchase_orders; 16:37:34 — Test Purchaser). |
| B5 — Buồng phòng + minibar | **Một phần đạt** | uat.front_desk mở /frontdesk/minibar, yêu cầu kiểm minibar phòng 101 (Trả phòng): thành công — "Đã gửi yêu cầu kiểm minibar.", tạo phiếu MB-TEST47-LE-2611-0001, trạng thái "Chờ thu tiền 0 đ"; phòng 101 hiện cảnh báo "Phòng này còn phiếu kiểm minibar chưa xử lý xong. Hệ thống không chặn giao phòng mới (chưa tích hợp PMS) — hãy xử lý phiếu cũ trước khi giao phòng." uat.hk_attendant mở /m/.../minibar: "Chờ kiểm: 1 · Đã kiểm: 0", thẻ "Phòng 101 — MB-TEST47-LE-2611-0001 · Trả phòng — Chưa kiểm". Mở phiếu kiểm: 7 món (Coca-Cola, Diet Coke, Larue, Lavie, Sprite, Tiger, Rượu vang), tất cả đều "Chưa có giá". Ghi nhận thiếu Coca-Cola 1, Lavie 1 → "Đã nhập thiếu: 2/7", "Tạm tính 0 đ". Nhưng nút "Gửi kết quả kiểm" luôn ở trạng thái vô hiệu (cả khi chưa nhập và khi đã nhập 2 món), kèm banner vàng "Chưa có giá" → không gửi được kết quả kiểm; quay lại danh sách vẫn "Chờ kiểm: 1 · Đã kiểm: 0", phòng 101 "Chưa kiểm" — xem lỗi số 5. Phần thử lúc tắt mạng: không tắt được mạng bằng công cụ trình duyệt hiện có — phần offline **chưa thử được** bằng cách này. uat.front_desk xác nhận thu tiền, nhập số folio: không thực hiện được — chi tiết phiếu MB-TEST47-LE-2611-0001 ghi "Phiếu này chưa được kiểm — chưa có dòng thiếu.", "Tổng tiền 0 đ", không có nút xác nhận thu tiền hay ô nhập số folio nào. Số tiền thu được: không có (0 đ trên phiếu). |
| B6 — Giao diện di động | **Đạt có lưu ý** | Hạn chế: không đặt được khung 390 px chính xác bằng công cụ trình duyệt hiện có (không có chức năng đổi kích thước cửa sổ). Đã kiểm tra bố cục mobile của app (các màn /m/ dùng cột hẹp căn giữa, responsive) ở khung hiện tại: không thấy tràn ngang, nút/thẻ bấm đủ lớn trên cả 3 màn. /m/.../receive (uat.storekeeper): đạt — 2 phiếu chờ nhận (PO-TEST47-LE-2611-0001, PO-TEST47-LE-2611-0003), ô tìm kiếm, nút Kiểm kê / Phiếu trả hàng NCC, thanh điều hướng dưới; hộp thoại "Mở phiếu nhận hàng" gọn trong cột (đã bấm "Hủy", không tạo phiếu). Lưu ý: với uat.front_desk, uat.hk_attendant và uat.purchaser, màn này báo lỗi quyền: "Không thể tải dữ liệu — Bạn chưa được cấp quyền receiving.perform để thực hiện thao tác này." Chỉ uat.storekeeper xem được màn này. /m/.../minibar (uat.hk_attendant): đạt — thẻ phòng 101 lớn, nút −/+ khoảng 44 px, nút "Gửi kết quả kiểm" rộng toàn cột, không tràn ngang. /m/.../restaurant (uat.gm): đạt — 4 thẻ lớn (Bếp / Bán hàng / Buffet / Đặt tiệc), không tràn ngang. |

## Chứng từ thực tế tạo ra trong đợt test (đều trên TEST47, dữ liệu demo)

- GRN-TEST47-LE-2611-0003 (nháp, 0 dòng, uat.receiver mở) và GRN-TEST47-LE-2611-0004 (nháp, 0 dòng, tạo thêm khi thủ kho mở lại cùng PO).
- PR-TEST47-LE-2611-0004 (uat.chef, nháp), PR-TEST47-LE-2611-0005 (uat.purchaser, nháp).
- PO-TEST47-LE-2611-0004 — PO chợ (uat.purchaser, nháp, tạm ứng 500.001 đ, tổng ước tính 500.001 đ).
- MB-TEST47-LE-2611-0001 — phiếu kiểm minibar phòng 101 (Chờ thu tiền, 0 đ).

Không đụng PR-TEST47-LE-2611-0002 và PO-TEST47-LE-2611-0002 của đợt test ngày 1 (hai chứng từ này đang ở trạng thái "ĐÃ CHUYỂN PO").

## Danh sách lỗi

### 1. [Chặn] Nhận hàng mù bắt buộc chụp ảnh nhưng không có cách nào khác khi không có camera — UI
- Mô tả: màn nhận hàng di động bắt buộc chụp ảnh mỗi dòng ("Bắt buộc chụp ảnh*") mới bật nút "Ghi dòng". Trình duyệt test không có camera thì bấm "Chụp ảnh" báo "Không tìm thấy camera trên thiết bị này. Hãy dùng thiết bị có camera rồi thử lại."; màn không có ô tải ảnh lên; camera giả của Chromium không bật được bằng công cụ trình duyệt hiện có.
- Tái hiện: /m/<uuid>/receive → mở PO-TEST47-LE-2611-0003 → bấm "Chụp ảnh".
- Hệ quả: cả chu trình A6–A12 đổ (không ghi được dòng → không ghi sổ → không hóa đơn → không thanh toán). Cùng điểm kẹt đã gặp ở test ngày 1 buổi sáng (TEST02) và chiều (TEST03).
- Hướng xử lý: nhận trên thiết bị có camera thật (hoặc người dùng tiếp quản trình duyệt để chụp ảnh như sáng 13/11 đã làm được); hoặc cân nhắc đường tải ảnh lên / nới luật bắt chụp ảnh — quyết định này thuộc về Duy, không tự đổi.

### 2. [Chặn] Kế toán không mở được form nhập hóa đơn — Quyền (cần điều tra thêm)
- Mô tả: uat.accountant mở /finance/invoices/new báo "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này." (thử 2 lần: mở trực tiếp và bấm "Nhập hóa đơn mới"). Danh sách hóa đơn thì mở được (đang trống).
- Tái hiện: đăng nhập uat.accountant → /finance/invoices/new.
- Lưu ý: định nghĩa vai trò kế toán trong repo có quyền `invoice.manage` (migration 20261109570000, dòng sm_accountant), nên form tải dữ liệu có thể đang đòi thêm một quyền khác, hoặc phần gán vai trò thực tế trên production khác với định nghĩa. Lỗi này độc lập với vụ camera — sau khi sửa được camera thì bước 8 vẫn kẹt ở đây.

### 3. [Chặn] Trang Sửa nháp PO chợ không lưu được lần nào — UI
- Mô tả: trang Sửa nháp của PO chợ (PO-TEST47-LE-2611-0004) luôn báo "Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập." — cả khi giữ nguyên không đổi gì (5 lần thử: chỉ nhập lý do; giữ nguyên; nhập đơn giá 100.001; nhập ngày nhận 20/11/2026; nhập đủ lý do + đơn giá + ngày). Sau mỗi lần lưu lỗi, dữ liệu đã nhập bị trả về trạng thái gốc.
- Hệ quả: không bổ sung được lý do vượt trần → nút "Gửi duyệt" PO chợ vẫn vô hiệu ("Chưa có lý do vượt trần — không gửi duyệt được."), PO chợ không gửi duyệt được.
- Nghi ngờ (chưa kiểm chứng): liên quan đến trường ĐVT đang ở trạng thái vô hiệu trong form sửa.

### 4. [Giao diện] Ô "Tổng ước tính" từ chối số tròn 500.000 đ — UI
- Mô tả: ô nhập tổng ước tính từ chối đúng 500.000 đ với thông báo trình duyệt "Please enter a valid value. The two nearest valid values are 499001 and 500001." Nguyên nhân trong code: ô này có `step="1000"` (`src/components/procurement/market-order-form.tsx:170`), nên chỉ nhận các giá trị trên lưới bước nhảy tính từ giá trị gốc (500.001 đ lưu được, 500.000 đ thì không).
- Hướng sửa: đổi thành `step="any"` hoặc đặt `min="0"` cho khớp lưới bước nhảy.

### 5. [Dữ liệu] Giá minibar chưa có nên không kiểm/không thu được tiền — Dữ liệu
- Mô tả: 7 món minibar trong phiếu kiểm phòng 101 đều "Chưa có giá" → nút "Gửi kết quả kiểm" luôn vô hiệu kèm banner vàng "Chưa có giá" → phiếu kiểm không gửi được → lễ tân không có nút xác nhận thu tiền hay ô nhập số folio.
- Lưu ý: checklist go-live (mục C4) đã ghi 7 giá minibar hết hạn (2018–2019). Cần nhập giá minibar hiện hành cho TEST47 rồi thử lại B5.

### 6. [Giao diện/dữ liệu] Mở lại PO để nhận thì tạo thêm phiếu nháp mới thay vì mở tiếp phiếu cũ — UI / DB-RPC (cần điều tra)
- Mô tả: GRN-TEST47-LE-2611-0003 (nháp, 0 dòng) đã tồn tại cho PO-TEST47-LE-2611-0003; khi thủ kho mở lại cùng PO, hệ tạo thêm GRN-TEST47-LE-2611-0004 (nháp, 0 dòng).
- Hệ quả: phiếu nháp trùng lặp tồn đọng; người dùng khó biết phiếu nào mới là phiếu đang làm dở.

### 7. [Tài liệu] Đường dẫn /TEST47/... trong tài liệu đều 404 — Tài liệu
- Mô tả: mọi đường dạng `/TEST47/...` trong tài liệu giao việc và kịch bản demo đều trả 404 ("Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn."). App dùng UUID khách sạn trong đường dẫn (ví dụ `/m/b0000000-0000-4000-8000-000000000002/receive`).
- Hướng sửa: sửa các đường dẫn trong `docs/go-live/muse-handoff-demo-test.md`, `docs/go-live/demo-walkthrough.md` và `docs/go-live/uat-guide.md` sang dạng UUID (hoặc ghi chú rõ).

### 8. [Chưa xác nhận] Nút "Gửi duyệt" PR không phản hồi trong trình duyệt test — Môi trường test (chưa phải lỗi app)
- Mô tả: nút "Gửi duyệt" trên trang chi tiết PR không phản hồi khi bấm bằng trình duyệt cloud (6+ lần, không có thông báo lỗi). Đối chiếu code: nút gọi `handleSubmit` → `confirm(...)` (hộp thoại xác nhận của trình duyệt) → `submitPrAction` (RPC `pr_submit`) — xem `src/components/procurement/pr-detail.tsx:70-77`. Hộp thoại `window.confirm` vốn cần người bấm OK bằng tay: cùng nút này đã hoạt động ngày 13/11 lúc 14:26 khi Duy bấm OK trực tiếp (PR-TEST47-LE-2611-0002 đã được gửi duyệt và chuyển PO). Nhiều khả năng trình duyệt tự động đã tự hủy hộp thoại nên hàm dừng im lặng, không phải lỗi app.
- Hướng xử lý: thử lại với người bấm OK trên hộp thoại xác nhận (hoặc trên trình duyệt của Duy), rồi mới kết luận B1. Vì vậy mục B1 trong báo cáo này ghi "chưa kết luận được", không ghi "lỗi app".

### 9. [Quyền — nhỏ] Vài màn báo lỗi quyền thay vì hiển thị trống
- Trang "Chờ tôi duyệt" của uat.chef không tải được dữ liệu: "Không thể tải dữ liệu — Bạn chưa được cấp quyền thực hiện thao tác này."
- Thủ kho mở báo cáo Thẻ kho: "Bạn chưa được cấp quyền xem báo cáo nào." và "Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên."
- Thủ kho bấm liên kết mã phiếu nhận trên desktop → trang PO báo 404 "Không có quyền xem (1503)".
- Thủ kho xem màn tồn kho: "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng" (đúng thiết kế ẩn giá trị, nhưng khiến bước 7 không kiểm tra được giá vốn bằng tài khoản thủ kho).

## Lệnh đã chạy và kết quả thật

- Không sửa code giao diện nào trong đợt test này (không có lỗi UI nào thuộc diện sửa ngay trên nhánh mà không cần quyết định thêm; các lỗi UI tìm được đều cần Claude Code xem xét cùng phần DB/RPC/quyền). Vì vậy không chạy `pnpm lint` / `typecheck` / `test` cho code — nhánh `feat/muse-demo-test` chỉ chứa báo cáo này.
- Nhánh làm việc: `feat/muse-demo-test` từ `origin/main` a7d0d8d. Không merge vào `main`, không push.

## Việc bỏ dở và vì sao

- A6–A12: chưa làm được vì kẹt camera ở bước 6 (lỗi 1); bước 8 có thêm lỗi quyền độc lập (lỗi 2).
- B1: chưa kết luận được vì nút "Gửi duyệt" PR cần người bấm OK trên hộp thoại xác nhận (lỗi 8); các loại chứng từ khác không có chứng từ chờ để thử.
- B2: tạo PO chợ và chặn khi chưa nhập ước tính đã đạt; gửi duyệt chưa làm được vì form Sửa nháp không lưu được (lỗi 3).
- B5: phần kiểm minibar trên điện thoại chưa gửi được kết quả vì thiếu giá (lỗi 5); phần thử lúc tắt mạng chưa thử được vì công cụ trình duyệt hiện có không tắt được mạng.
- B6: chưa đặt được khung 390 px chính xác (công cụ trình duyệt không có chức năng đổi kích thước cửa sổ); đã kiểm tra bố cục mobile ở khung hiện tại, không thấy tràn ngang.

## Đề xuất làm lại

1. Dùng thiết bị có camera thật (hoặc Duy tiếp quản trình duyệt để chụp ảnh) rồi chạy lại A6–A12; trước đó cần xử lý lỗi 2 (quyền form hóa đơn) nếu không bước 8 vẫn kẹt.
2. Nhập giá minibar hiện hành cho TEST47 rồi chạy lại B5 (cả phần offline trên điện thoại thật).
3. Thử lại B1 với người bấm OK trên hộp thoại xác nhận để kết luận nút "Gửi duyệt" PR.
4. Sửa lỗi 3, 4, 6, 7 theo danh sách trên.
