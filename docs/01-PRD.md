# 01 — Product Requirements (PRD)

## 1. Bài toán

Chi phí nguyên vật liệu F&B và vật tư buồng phòng chiếm 28–40% doanh thu khách sạn. Hiện khách sạn quản lý bằng các file Google Sheets/Excel rời rạc (định lượng buffet, food cost Á-la-carte, thẻ kho minibar, theo dõi amenities) — xem `docs/07-IMPORT-MIGRATION.md`. Các file này không có đơn giá tin cậy, không gắn với số khách/số phòng thực tế, không chặn lỗi (tồn âm, ghi đè, một mã cho hai mặt hàng), nên **không ra được con số quản trị nào**.

### Năm điểm rò rỉ cần chặn

| Khâu | Kiểu gian lận / sai sót | Cơ chế chặn trong phần mềm |
|---|---|---|
| Thu mua | Kê giá, báo giá "quân xanh", mua loại 2 trả giá loại 1 | Giá lấy tự động từ hợp đồng/báo giá, giá trần, duyệt đa tầng |
| Nhận hàng | Giao thiếu cân, độn đá, thủ kho ký khống | Nhận hàng mù (ẩn số PO), trừ bì, ảnh chụp trực tiếp, giờ máy chủ |
| Lưu kho & xuất | Xuất miệng, không FIFO, tuồn hàng | Sổ cái bất biến, phiếu lĩnh có xác nhận 2 phía, điều chuyển 2 bước |
| Sơ chế | Khai khống hao hụt | Biên bản pha lóc bảo toàn khối lượng, chuẩn yield động |
| Bán hàng | Bán chui, void sau in bill, đổ lỗi cho buffet | Kiểm kê mù cuối ca, đối soát Thực tế vs Lý thuyết (AvT) |

## 2. Người dùng

| Vai trò mẫu (sửa được) | Mã gợi ý | Thiết bị chính | Việc chính |
|---|---|---|---|
| Chủ đầu tư | `owner` | Điện thoại | Xem báo cáo 8h, nhận cảnh báo, duyệt vượt ngưỡng |
| Tổng quản lý KS | `gm` | Điện thoại, laptop | Duyệt, mở khóa sổ, xử lý cảnh báo |
| Kế toán trưởng chuỗi | `chief_accountant` | Laptop | Định mức, giá trần, chuẩn yield khi không có Cost Controller, duyệt thanh toán |
| Kế toán KS | `accountant` | Laptop | Hóa đơn, khớp 3 chiều, công nợ, tạm ứng, xuất Excel |
| Cost Controller | `cost_controller` | Laptop, tablet | Định mức, hậu kiểm ảnh, đối soát AvT (có thể không có ở một số KS) |
| Thu mua | `purchaser` | Điện thoại | PR → PO, báo giá, mua chợ |
| Thủ kho | `storekeeper` | Điện thoại, tablet | Nhận hàng, xuất kho, kiểm kê kho tổng |
| Người nhận ca sáng | `receiver` | Điện thoại | Nhận hàng tươi lúc sớm (không thấy PO/giá) |
| Trưởng bộ phận | `outlet_head` | Điện thoại | Lập/duyệt phiếu lĩnh |
| Bếp trưởng / Bếp | `chef` | Tablet | Công thức, pha lóc, hủy hàng, đếm cuối ca |
| Bartender | `bartender` | Điện thoại | Đếm/cân chai cuối ca |
| Giám sát buồng | `hk_supervisor` | Điện thoại | Phân phòng, xe đẩy, đồ vải |
| Nhân viên buồng | `hk_attendant` | Điện thoại | Xe đẩy, báo phòng xong, kiểm minibar |
| Lễ tân | `front_desk` | Máy bàn | Nhập số liệu PMS, thu tiền minibar, ghi nhận yêu cầu thêm của khách |
| Kỹ thuật | `engineer` | Điện thoại | Ghi chỉ số đồng hồ, phiếu sửa chữa |
| Kiểm soát nội bộ | `internal_audit` | Laptop | Chỉ xem toàn chuỗi |
| Quản trị hệ thống | `sys_admin` | Laptop | Người dùng, cấu hình |

Đây là **vai trò mẫu**. Quản trị tự tạo thêm vai trò, sửa quyền của từng vai trò bằng ma trận tích chọn, gán vai trò cho người dùng theo khách sạn / bộ phận / kho, có thời hạn, và cấp hoặc chặn quyền riêng cho từng người — không cần sửa code. Một người có thể giữ nhiều vai trò ở khách sạn nhỏ; tách biệt nhiệm vụ vẫn được kiểm tra **trên từng chứng từ** dù cấu hình thế nào (xem `04-SECURITY-RLS.md`).

## 3. Phạm vi theo giai đoạn

### MVP (thí điểm 1 khách sạn) — 10–12 tuần

- Nền tảng: đăng nhập, đa pháp nhân, phân quyền động, 2 hồ sơ SoD (có/không Cost Controller), nhật ký, ảnh chứng từ, cấu hình động + sinh mã tự động, thông báo (email + web push; Zalo OA khi có OA).
- PH01 Dữ liệu gốc: tổ chức, kho, vật tư, đơn vị quy đổi, NCC + thẩm định, hợp đồng khung, giá trần, khoản mục chi phí, import Excel có làm sạch.
- PH03 Thu mua: PR, PO, duyệt đa tầng, mua chợ tiền mặt gắn tạm ứng, bảng kê hàng không hóa đơn.
- PH04 Nhận hàng: nhận mù trên điện thoại, QC, trả hàng, nhận trực tiếp vào bếp.
- PH05 Kho: sổ cái bất biến, phiếu lĩnh, xuất theo mục đích, hủy hàng, điều chuyển trong KS, thẻ kho / nhập–xuất–tồn.
- PH07 (một phần): danh mục vật tư buồng phòng, chuẩn setup phòng, kho tầng & xe đẩy, **minibar theo phòng tính tiền khi check-out**.
- PH08: kiểm kê tháng toàn kho, xử lý chênh lệch, khóa ngày/kỳ.
- PH09 (một phần): hóa đơn NCC, khớp 3 chiều, công nợ, tạm ứng & quyết toán.
- PH11 (một phần): mua dịch vụ + nghiệm thu, hợp đồng dịch vụ định kỳ, khoản mục chi phí theo USALI.
- PMS: form nhập số liệu ngày (phòng bán, khách, khách ăn sáng).
- Xuất Excel chứng từ cho kế toán (chưa kết nối MISA/Bravo).
- 6 báo cáo MVP (mục `08-REPORTS-ALERTS.md`).

### P2 — 10–12 tuần
Công thức đa cấp, pha lóc, sản xuất lô, import POS + AvT, kiểm kê cuối ca Key Items, bar cân rượu, buffet theo mẻ, báo giá hằng ngày, chấm điểm NCC, FEFO, void/comp; phân phòng & đối soát theo nhân viên buồng, đồ vải, giặt là; năng lượng–nước; bảo trì & tài sản; ngân sách; lịch thanh toán.

### P3 — 6–8 tuần
Kết nối MISA & Bravo (adapter), MRP, điều chuyển liên pháp nhân, thu mua tập trung, phân bổ chi phí chung, BEO tiệc, báo cáo USALI, giặt nội bộ, đồng phục, rác thải.

## 4. Ngoài phạm vi

- Hóa đơn điện tử đầu ra (PMS/POS lo).
- Sổ cái kế toán tổng hợp (GL), báo cáo tài chính — MISA lo.
- Lương, chấm công.
- Đặt phòng, lễ tân.

## 5. Chỉ số thành công của thí điểm

- 100% hàng nhập qua nhận hàng mù có ảnh.
- 0 PO vượt giá trần mà không có duyệt.
- Kiểm kê tháng đầu ra được biên bản chênh lệch theo từng mã, giá trị.
- Báo cáo 8h sáng gửi đúng giờ ≥ 95% ngày.
- Minibar: tổng tiền buồng phòng ghi nhận = tổng lễ tân thu + miễn có duyệt + phát hiện muộn, lệch = 0 sau 4 tuần.
