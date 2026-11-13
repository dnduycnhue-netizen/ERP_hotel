# M5 — Thử nghiệm khám phá Buồng phòng & Minibar

- Ngày: 13–14/11/2026, 23:54–00:02 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.hk_supervisor, uat.hk_attendant, uat.front_desk (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Đạt một phần — kiểm minibar + xe đẩy chạy tốt, nhưng luồng thu tiền chính BỊ KẸT (B1), 9 phát hiện.**
- Commit: `T-M5` (xem git log).

## 1. Luồng chính

| Bước | Kết quả |
|---|---|
| Giám sát buồng xem minibar | **Đạt (có hạn chế quyền, xem B3):** bảng giá đủ 7 món, khớp dữ liệu đã biết, hiệu lực từ 2026-11-11 (Tiger 35.000, Diet Coke 25.000, Lavie 15.000, Sprite 25.000, Coca-Cola 25.000, Rượu vang 245.000, Larue 25.000). "Thu hồi hàng sắp hết hạn: Không có hàng minibar nào trong phòng sắp hết hạn." Tồn kho từng phòng KHÔNG hiện (thiếu quyền stock.view_qty). Tiêu chuẩn phòng: 36 dòng = 3 loại phòng (Suite, Deluxe, Standard — đều "(Demo)") × 12 món, tất cả loại dọn "Trả phòng" (xem B6). Lúc đầu không có ca xe đẩy nào đang mở; desktop không có nút mở ca mới (chỉ mở được trên mobile). |
| Kiểm minibar phòng 101 (mobile, hk_attendant) | **Đạt:** lúc đầu "Chờ kiểm: 2 · Đã kiểm: 0" (101 + 104). Nhập thiếu phòng 101: Tiger 1, Diet Coke 1, Lavie 2, Sprite 0, Coca-Cola 1, Rượu vang 0, Larue 1 → app hiện "Đã nhập thiếu: 5/7", "Tạm tính 140.000 đ". **Tính tay khớp:** 35.000+25.000+2×15.000+0+25.000+0+25.000 = 140.000 đ. Bấm "Gửi kết quả kiểm" → phiếu "Chờ thu tiền", bảng chi tiết đúng 5 món đã nhập (Sprite, Rượu vang = 0 không hiện). Không bắt nhập lý do khi thiếu hàng (chỉ có ô tick "Sắp hết hạn"). Không hỏi mã PIN, không bắt chụp ảnh. |
| Đồng bộ offline | **KHÔNG TEST ĐƯỢC (không bịa kết quả):** trình duyệt tự động không ngắt được mạng nên không nhập được phiếu 104 khi offline, không kiểm tra được đồng bộ/trùng phiếu. Cần test lại trên thiết bị thật khi tắt mạng. |
| Lễ tân thu tiền phòng 101 | **KHÔNG ĐẠT — bị chặn (B1):** phiếu 101 hiện đúng "Chờ thu tiền · 140.000 đ". Trang có cảnh báo: "Các phòng sau còn phiếu kiểm minibar chưa xong — chưa giao phòng cho khách mới: 104, 101" và "Phòng này còn phiếu kiểm minibar chưa xử lý xong. Hệ thống không chặn giao phòng mới (chưa tích hợp PMS) — hãy xử lý phiếu cũ trước khi giao phòng." Nút "Đã thu" bị vô hiệu cho tới khi nhập "Số folio" — đã nhập folio kiểm thử **"TEST-M5-1311"** (tự đặt, không có PMS/folio thật; đã hỏi ý kiến Muse trong lúc kiểm thử; không dùng "Đề nghị miễn"/"Chuyển thu muộn") → bấm "Đã thu" → banner lỗi đỏ **"Không đủ tồn kho để xuất."** Phiếu 101 vẫn "Chờ thu tiền" 140.000 đ, chưa thu được tiền. |
| Xe đẩy | **Đạt (mở, đóng thành công; par/refill xem B7/B8):** mở ca mới Xe đẩy 1 (Demo), Ca ngày, ngày 13/11/2026 — phải đếm đủ 12 món mới mở được ("Đã đếm: 12/12"). Đếm đầu ca 10 cho cả 12 món (AMN-… và CPM-DASANI) → "ĐANG MỞ". Đóng ca: đếm cuối ca 10/món → "ĐÃ ĐÓNG". Bảng "Tiêu hao trong ca" (Đã dùng = Đầu ca + Đã lĩnh − Cuối ca): 12 món đều Đầu 10, Đã lĩnh 0, Cuối 10, Đã dùng 0. Desktop /housekeeping/trolleys xác nhận: 2026-11-13 · Ca ngày · Xe đẩy 1 (Demo) · Bạn · ĐÃ ĐÓNG · "0 phòng đã dọn · Không có phiếu lĩnh bù · Chưa có phiếu tiêu hao". |

## 2. Trường hợp biên

- **a. Tất cả món = 0 (phòng 104) — KHÔNG GỬI ĐƯỢC (B5):** "Đã nhập thiếu: 0/7", "Tạm tính 0 đ" → nút "Gửi kết quả kiểm" vô hiệu kèm dòng "Chưa nhập món thiếu nào — bấm nút + ở món khách đã dùng." Không có cách ghi nhận phòng trống hoàn toàn; phiếu 104 giữ nguyên chưa kiểm.
- **b. Số lớn/âm (phòng 104, Coca-Cola):** số **999 ĐƯỢC CHẤP NHẬN** — app tính "Tạm tính 24.975.000 đ" (999×25.000 đ), không cảnh báo, không giới hạn tối đa (B4). Số âm -1 KHÔNG nhập được — ô về trống, trạng thái quay về "Đã nhập thiếu: 0/7" (app loại số âm — tốt).
- **c. Tìm phòng có dấu — KHÔNG TEST ĐƯỢC:** trang minibar mobile không có ô tìm kiếm phòng nhìn thấy được (danh sách chỉ có 2 phiếu); ô "Tìm phòng…" chỉ thoáng xuất hiện ở lần tải đầu rồi biến mất.

## 3. Phát hiện

- **B1. [Nghiêm trọng] Thu tiền minibar bị chặn "Không đủ tồn kho để xuất."** Tái hiện: lễ tân mở /frontdesk/minibar → phiếu MB-TEST47-LE-2611-0001 (140.000 đ) → nhập folio TEST-M5-1311 → bấm "Đã thu" → banner lỗi đỏ, phiếu vẫn "Chờ thu tiền". Luồng thu tiền chính bị kẹt — nghi do tồn kho phòng 101 bằng 0 (chưa từng nhập kho phòng). Cần Claude Code kiểm tra: tồn kho phòng có được trừ khi kiểm minibar không, và thu tiền có nên trừ kho phòng hay không. Đây là lỗi chặn luồng chính (blocking), ưu tiên cao.
- **B2. [Sai trạng thái hiển thị]** Trang lễ tân ghi phiếu 104 là "Chờ thu tiền" ("Phòng 104 · MB-TEST47-LE-2611-0002 Trả phòng · Chờ thu tiền 0 đ") dù phiếu chưa hề được kiểm — chi tiết phiếu ghi rõ "Phiếu này chưa được kiểm — chưa có dòng thiếu." và không có nút thu tiền. Trang mobile thể hiện đúng là "Chưa kiểm". Gây hiểu nhầm là đã kiểm xong.
- **B3. [Quyền]** Giám sát buồng không có quyền xem tồn kho phòng (stock.view_qty) — giám sát cần xem tồn để đối chiếu kiểm minibar. (Cùng họ với M9 F.8: HK thấy giá nhưng không thấy tồn.)
- **B4. [Kiểm soát nhập liệu]** Số lượng thiếu không có giới hạn tối đa: nhập 999 cho 1 món được chấp nhận, tính 24.975.000 đ.
- **B5. [Thiết kế]** Không thể hoàn thành phiếu kiểm khi phòng không thiếu món nào (nút Gửi khóa khi tất cả = 0) — không ghi nhận được "phòng trống hoàn toàn".
- **B6. [Dữ liệu]** Tiêu chuẩn phòng giống hệt nhau (kể cả số lẻ 4 chữ số thập phân: Bàn chải 0.8868, Giấy vệ sinh 0.7174, Nước dasani 1.9396…) cho cả 3 loại phòng, chỉ có loại "Trả phòng" — dữ liệu demo/seed, chưa phải tiêu chuẩn thật theo loại phòng.
- **B7. [Hiển thị]** Mức par của xe đẩy không hiển thị con số cụ thể ở bất cứ màn nào (mở ca, chi tiết ca mobile hay desktop). Chỉ có dòng: "Ca này không sinh phiếu lĩnh bù (đủ par, hoặc khách sạn chưa có kho tầng duy nhất)."
- **B8. [Refill]** Không có thao tác bổ sung (refill) tay cho 1 mặt hàng: bổ sung chỉ diễn ra qua "phiếu lĩnh bù tới par" tự sinh khi số đếm đầu ca dưới par; ca test (đếm 10/món) không sinh phiếu lĩnh bù nên không có gì để thử — cần test thêm ca có số đếm dưới par.
- **B9. [Nhỏ]** Sau khi đổi tài khoản (lễ tân → giám sát), trang tổng quan thoáng hiển thị menu của tài khoản trước ("Minibar — Lễ tân") cho tới khi chuyển trang — xác nhận lại M9 F.1 (menu cũ sau đăng nhập). Ngoài ra đoán URL /housekeeping/room-standards bị 404 (đường dẫn đúng là /housekeeping/standards).

## 4. Trạng thái cuối (TEST47)

- Phiếu MB-TEST47-LE-2611-0001 (phòng 101): "Chờ thu tiền", 140.000 đ — ĐÃ KIỂM, CHƯA THU TIỀN (kẹt B1).
- Phiếu MB-TEST47-LE-2611-0002 (phòng 104): "Chờ kiểm / Chưa kiểm", 0 dòng thiếu, 0 đ — chưa kiểm, không thay đổi.
- Ca xe đẩy: không còn ca nào đang mở. Ca duy nhất trong ngày: Xe đẩy 1 (Demo), 13/11/2026, Ca ngày, ĐÃ ĐÓNG (đầu 10/món, cuối 10/món, tiêu hao 0, không phiếu lĩnh bù).
- Không xóa/sửa dữ liệu nào khác; chỉ tạo thêm dữ liệu test trên TEST47 (phiếu 101 đã gửi + 1 ca xe đẩy đã đóng). Phần offline (bước 3) và tìm kiếm có dấu (c) chưa test được, cần thiết bị thật.

## 5. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (hk_supervisor → hk_attendant → front_desk), 23:54 13/11 – 00:02 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
