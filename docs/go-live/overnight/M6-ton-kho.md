# M6 — Thử nghiệm khám phá module Tồn kho

- Ngày: 14/11/2026, 00:04–00:10 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.storekeeper, uat.chef, uat.purchaser (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Không đạt — KHÔNG TẠO ĐƯỢC phiếu lĩnh/điều chuyển/hủy nào vì giao diện không có nút/form tạo ở cả 3 vai trò đã thử. 5 phát hiện (1 chặn, 1 lỗi tái hiện, 1 quyền, 2 cần đối chiếu).**
- Commit: `T-M6` (xem git log).

## 1. Kết luận chung

Không tạo được bất kỳ phiếu lĩnh / điều chuyển / hủy nào: danh sách các loại phiếu đều
chỉ có bộ lọc, không có nút tạo mới, ở cả 3 tài khoản. Các luồng 2, 3, 4 và trường hợp
biên a–d đều không thực hiện được vì không vào được form tạo. Không có phiếu mới nào
được tạo, không xóa/sửa dữ liệu; tồn kho cuối vẫn như đầu kỳ (0).

## 2. Từng bước

| Bước | Kết quả |
|---|---|
| Tồn kho trước (thủ kho) | **Đạt (ghi nhận trạng thái thật):** "0 tồn kho", "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại.", "Tổng GT" trống. Chú thích: "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng." Lọc riêng Kho chính T047 và Kho bếp (Demo) đều 0. 8 kho đúng như đã biết. Danh mục có 672 mặt hàng. **Tìm NVL0388 lỗi tái hiện (L2):** gõ "NVL0388" hoặc "ba chỉ nách" → "Không thể tải dữ liệu / Invalid UUID" (URL ?warehouse=&search=NVL0388). NVL0388 vẫn tồn tại trong Danh mục vật tư (1 kết quả: Nhóm Thịt & Cá, ĐVT kg, Đang dùng, NCC Chợ); form "Sửa vật tư" (chỉ xem, đã bấm Hủy) không có trường tồn kho hay giá vốn. Không xác định được tồn kho riêng của NVL0388 — chỉ biết tổng toàn TEST47 là 0. |
| Phiếu lĩnh | **Không đạt (không có lối tạo):** cả 3 tài khoản đều thấy cùng 1 phiếu duy nhất REQ-TEST47-LE-2611-0001, NHÁP, ngày 2026-11-13, Kho chính → Kho bếp, Người yêu cầu: Bếp (Demo), 7 dòng, Tổng SL 0,425 (NVL0055 Bột Mì 0,03 kg; NVL1385 Rau má 0,005 kg; NPL0525 Dưa leo 0,045 kg; NPL1328 Mướp đắng 0,02 kg; NPL1404 Mồng tơi 0,02 kg; NPL0961 Hành tây 0,02 kg; NPL1406 Giá đỗ 0,06 kg), "Không có ghi chú", không có nút thao tác nào (duyệt/xuất/gửi) — chi tiết chỉ để xem. Danh sách KHÔNG có nút tạo mới ở cả 3 tài khoản; tìm chức năng "Tạo phiếu lĩnh" → "Không tìm thấy chức năng nào"; "/inventory/requisitions/new" và "/create" đều ra màn lỗi chung. Luồng bếp: trang Bếp ghi "NVL cần chuẩn bị — Gộp từ món trong phiên buffet và thực đơn tiệc. Tạo phiếu lĩnh ở khu Kho → Phiếu lĩnh." + "Hôm nay chưa có phiên buffet hay tiệc đã xác nhận." — bấm liên kết "Tạo phiếu lĩnh" chỉ quay lại danh sách. Vậy với bếp, phiếu lĩnh chỉ phát sinh từ buffet/tiệc đã xác nhận. |
| Điều chuyển kho | **Không đạt (không có lối tạo):** /inventory/transfers: "0 phiếu điều chuyển", "Tổng SL 0" — KHÔNG có nút tạo mới (thủ kho, thu mua; bếp trưởng thậm chí không có tab Điều chuyển trong menu Kho). /inventory/transfers/new → màn lỗi chung. |
| Hủy hàng | **Không đạt (không có lối tạo + chặn quyền):** bếp trưởng xem được /inventory/waste: "0 phiếu hủy", "Tổng SL 0" — KHÔNG có nút tạo mới. Thủ kho và thu mua KHÔNG thấy tab Hủy hàng; mở trực tiếp /inventory/waste bị chặn: "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này." Không kiểm chứng được bước chụp ảnh bắt buộc (không tới được form hủy). |
| Giá vốn bình quân | **Không đạt (không xem được):** không nơi nào trong tầm 3 tài khoản hiển thị giá vốn bình quân: màn Tồn kho "chỉ hiện số lượng"; Danh mục vật tư và form sửa NVL0388 không có trường giá vốn/giá nhập; trang chủ ghi phương pháp "Định giá Bình quân gia quyền" nhưng không hiển thị con số. Không có phiếu nào ghi sổ nên cũng không có thay đổi giá vốn để so sánh. |

## 3. Trường hợp biên a–d — chưa thực hiện được

Số lượng 0/âm; số lượng lớn hơn tồn kho; phiếu hủy không lý do; ghi chú tiếng Việt có dấu
— cả 4 đều KHÔNG thử được vì không có form tạo phiếu. Không bịa kết quả; cần form tạo
phiếu mới kiểm chứng được app chặn hay cho qua.

## 4. Phát hiện

- **L1. [Chặn] Không có nút/form tạo phiếu lĩnh, điều chuyển, xuất mục đích, hủy ở bất kỳ vai trò UAT nào đã thử (thủ kho, bếp trưởng, thu mua).** Tái hiện: Kho → Phiếu lĩnh / Điều chuyển / Xuất mục đích / Hủy hàng → đầu trang chỉ có bộ lọc, không có nút tạo. Đối chứng: tab Kiểm kê có nút "Mở đợt kiểm kê", tab Phiếu nhận hiển thị được 5 phiếu — không phải lỗi tải trang chung. **Cần đối chiếu trước khi kết luận app thiếu tính năng:** (a) phiếu lĩnh REQ-...-0001 tồn tại — có thể phiếu lĩnh được SINH TỰ ĐỘNG từ buffet/tiệc đã xác nhận (trang Bếp ghi đúng như vậy), tức không có tạo tay theo thiết kế; (b) chưa kiểm tra vai trò gm/owner — có thể nút tạo chỉ hiện với quản lý/chủ đầu tư; (c) điều chuyển/hủy có thể chỉ tạo từ một lối vào khác chưa tìm thấy. M7 sẽ kiểm tra (b) bằng tài khoản owner/GM. Chuyển Claude Code + Duy xác nhận thiết kế.
- **L2. [Lỗi — tái hiện lần 2] Tìm kiếm màn Tồn kho báo "Invalid UUID" dù gõ mã hay tên hợp lệ.** Tái hiện: /inventory/stock → ô "Tìm mặt hàng theo mã, tên hoặc nhà cung cấp..." → gõ "NVL0388" hoặc "ba chỉ nách" → Enter → "Không thể tải dữ liệu / Invalid UUID". Tìm cùng mã ở Danh mục vật tư thì hoạt động bình thường (1 kết quả). (M4 F-5 đã gặp với "NVL0096"/"tôm bạc".) Chuyển Claude Code.
- **L3. [Quyền] Thủ kho và thu mua bị chặn màn Hủy hàng.** Chỉ bếp trưởng xem được danh sách hủy (0 phiếu, không nút tạo). Nếu phiếu hủy thuộc về thủ kho vận hành thì phân quyền này sai; nếu hủy chỉ do bếp tạo thì cần ghi rõ trong hướng dẫn vai trò. Chuyển Claude Code/Duy xác nhận.
- **L4. [Bất thường cần đối chiếu] Chi tiết phiếu REQ-...-0001 hiển thị "SL tồn kho" bằng đúng số lượng xin lĩnh ở cả 7 dòng** (0,03; 0,005; 0,045; 0,02; 0,02; 0,02; 0,06), trong khi màn Tồn kho báo 0 mặt hàng tồn kho (cả khi lọc Kho chính T047 và Kho bếp Demo). Hoặc đó là tồn kho tại thời điểm tạo phiếu 13/11/2026, hoặc cột hiển thị sai (hiện nhầm SL yêu cầu). Chuyển Claude Code.
- **L5. [Hiển thị/quyền] Thủ kho và thu mua đều không xem được giá trị tồn kho/giá vốn** ("Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng."), nên bước giá vốn bình quân không kiểm chứng được bằng 3 tài khoản UAT này. Cần tài khoản có stock.view_value (GM/owner) để kiểm tra — M7/M1 sẽ đối chiếu.

## 5. Trạng thái cuối (TEST47)

- Phiếu đã tạo trong đợt này: 0. Phiếu lĩnh: 1 phiếu có sẵn REQ-TEST47-LE-2611-0001, NHÁP, không đổi. Điều chuyển: 0. Xuất mục đích: 0. Hủy: 0.
- Phiếu nhận (chỉ xem để đối chiếu): 5 phiếu Nháp ngày 13/11/2026 (GRN-0005, GRN-0004, GRN-0003, GRN-0002, GRN-0001 — GRN-0001 có 2 dòng, còn lại 1 dòng) — không đụng tới, không ghi sổ.
- Tồn kho cuối: 0 tồn kho (toàn TEST47; Kho chính T047: 0; Kho bếp Demo: 0), giống hệt đầu kỳ.
- Không gặp hộp thoại xác nhận hệ thống nào bị kẹt; không gặp màn hỏi mã PIN (không có bước ghi sổ nào để nhập PIN).

## 6. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (storekeeper → chef → purchaser), 00:04–00:10 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
