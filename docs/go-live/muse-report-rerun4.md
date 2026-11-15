# Báo cáo kiểm chứng rerun4 — ERP_hotel (15/11/2026)

> Nhánh `feat/muse-rerun4` từ `main` 0d523a6b2 (merge fix R3-N1 `1a85aee` + R3-N2 migration `20261109590000` + R3-N3). Chạy tuần tự, một mình, chỉ giao diện web, tài khoản `uat.*`/TEST, khách sạn TEST47 (`b0000000-0000-4000-8000-000000000002`). Không supabase/migration/vercel/RPC/SQL trực tiếp; không đổi cấu hình/tài khoản/PIN/khóa kỳ; không ghi mật khẩu/PIN vào file/log. Nhịp nhanh theo quyết định của Duy (15/11): kẹt thì ghi nhận rồi đi tiếp, không thử lại nhiều lần một chỗ.

## Kết quả tổng

| Task | Kết quả | Ghi chú |
|---|---|---|
| X1 — Hoàn tất kiểm kê CNT-0005 | **Đạt** | Khóa đợt thành công ngay lần 1 sau deploy mới; NVL0388 về 9 kg; kho hết đóng băng |
| X2 — GRN-0009 + hàng hỏng + hủy/khớp lại hóa đơn | **Đạt** | Cả 2 phiếu đã ghi sổ bằng `uat.receiver`; hóa đơn 0000124 ĐÃ KHỚP; phiếu trả NCC đã sinh |
| X3 — Bổ sung minibar theo tầng | **Đạt** | Khối cấp bù đã hiện; cấp Sprite tầng 3 đúng số ở cả kho tổng và phòng |
| X4 — Chứng từ kho trọn vòng | **Đạt một phần** | REQ-0002 trọn vòng; WST-0001 chặn đúng (thiếu ảnh); TRF-0002 sai kho xuất; PIS-0001 không sửa được |

## X1 — Kiểm kê CNT-0005 (đạt, chạy lại 15:56–16:01)

- Lần chạy 15:49–15:50 vẫn lỗi khóa đợt (`ERR_REASON_REQUIRED`, 2 lần thử) — **chạy trước khi deploy mới lên** nên lỗi cũ là đúng, không phải sửa không ăn.
- Chạy lại trên deploy mới: kế toán thấy bảng chênh lệch + dòng đỏ NVL0388 (đếm lần 1 = 9, lần 2 = 9, số đếm 9 kg, số sổ 10 kg, lệch −1 kg, −10%). Chọn mã lý do "Khác", giải thích "Kiểm kê tháng: đếm lần 1 và lần 2 đều 9 kg, sổ 10 kg, chênh lệch -1 kg (-10%).", bấm "Khóa đợt" — **thành công ngay lần 1**. Đợt CHỜ DUYỆT → ĐÃ KHÓA; cột Mã lý do/Giải thích ghi đúng. **R3-N1 đã verify live.**
- GM bấm nút "Ghi điều chỉnh vào sổ" (không có nút tên đúng "Duyệt điều chỉnh"), xác nhận hộp thoại, báo nguyên văn: "Đã ghi 1 bút toán điều chỉnh." Đợt → **ĐÃ ĐIỀU CHỈNH**. Tồn NVL0388: 10 → **9 kg** (900.000 đ, giá bình quân 100.000 đ/kg). Thẻ kho sau "Làm mới số liệu thẻ kho": tồn đầu 0, nhập 9, xuất 0, tồn cuối 9 kg, giá trị tồn cuối 900.000 đ.
- Thử đếm trên đợt đã khóa (người đếm): nút dòng bị vô hiệu, không mở được màn nhập số đếm — bị chặn. Đếm mù giữ nguyên: chỉ thấy "Đã đếm: 9 kg", KHÔNG thấy số sổ (10 kg) hay chênh lệch (−1 kg, −10%) — chỉ có nhãn chữ "Chênh lệch cần xử lý" không kèm con số.
- Đợt CNT-...-0004 (luân phiên, 0 dòng): đã hủy (nhập lý do bắt buộc → "Hủy đợt") — ĐANG MỞ → **ĐÃ HỦY**. CNT-...-0003 đã ĐÃ HỦY từ trước.
- Kho hết đóng băng: form "Lập phiếu xuất mục đích" mở bình thường, không còn thông báo "Kho đang kiểm kê" (chỉ điền thử 1 dòng NVL0388 1 kg, KHÔNG ghi sổ).
- Hộp "Chờ tôi duyệt" của `uat.owner`: vẫn còn đúng 1 chứng từ — PO-TEST47-LE-2611-0004 (0 đ, bước Quản lý) kèm nút Duyệt/Từ chối (không bấm). Xem R4-N1.

## X2 — GRN-0009 + hàng hỏng + hủy/khớp lại hóa đơn (đạt một phần, đang chạy lại)

### Lần 1 (16:02–16:09, bằng TEST03)

- **Ghi sổ GRN-...-0009: KHÔNG LÀM ĐƯỢC.** TEST03 bấm "Ghi sổ nhận hàng", nhập PIN → nguyên văn: "Bạn chưa được cấp quyền receiving.post để thực hiện thao tác này." (thử lại lần 2, giống hệt). Phiếu vẫn Nháp; PO-...-0005 vẫn "ĐÃ NHẬN: 0"; tồn NVL0561 = 0.
- **Hàng hỏng một phần trên GRN-...-0014: KHÔNG LÀM ĐƯỢC.** Form nhập được: gross 20, tare 0 → net 20; "Số lượng hỏng" = 2 + lý do "Dập nát trong quá trình vận chuyển"; tick xác nhận thiết bị không có camera (bắt buộc để nút "Ghi dòng" bật — ô miễn chụp Q274 hoạt động). Bấm "Ghi dòng" → nguyên văn: "Bạn chưa được cấp quyền receiving.perform để thực hiện thao tác này." Dòng không lưu (0/1 dòng). Không có phiếu trả NCC nào (`/receiving/returns`: 0 phiếu).
- **Hủy hóa đơn C25TAA/0000123: ĐẠT.** Kế toán mở chi tiết hóa đơn (TẠM GIỮ, 1.000.000 đ, dòng 200 × 5.000 đ; khớp dòng: "SL vượt số đã nhận · SL đã nhận: 0 / SL còn được hóa đơn: 0", "Giá khớp · Lệch giá: 0%, Dung sai cho phép: 1%"). Nhập lý do hủy bắt buộc ("Hóa đơn sai số lượng so với số đã nhận, hủy để lập hóa đơn thay thế."), xác nhận → nguyên văn: "Đã hủy hóa đơn. Bạn có thể nhập hóa đơn thay thế." Trạng thái: **ĐÃ HỦY**. **Nút "Hủy hóa đơn" Q284 đã verify live.**
- **Hóa đơn thay thế C25TAA/0000124: ĐÃ LẬP, khớp 3 chiều chưa đạt.** NCC là **T047** (PO-...-0005 thuộc NCC T047 — brief ghi SUP0001 là sai; chọn SUP0001 thì hộp Đơn mua chỉ có PO-...-0003 đã disabled). Số liệu: ký hiệu C25TAA, số 0000124, ngày 15/11/2026, PO-...-0005, 198 × 5.000 đ = 990.000 đ, VAT 0%. Id `49c2cb34-c4ac-482d-81bc-6ae82d8c2f97`. Bấm "Khớp 3 chiều": trạng thái NHÁP → **TẠM GIỮ**; số lượng KHÔNG KHỚP ("SL vượt số đã nhận · SL đã nhận: 0 / SL còn được hóa đơn: 0"), đơn giá KHỚP (lệch 0%, dung sai 1%). Số lượng 198 = 180 (GRN-0009) + 18 tốt (GRN-0014) theo kịch bản dự kiến — khớp được khi 2 phiếu đã ghi sổ (số đã nhận = 198).

### Chạy lại (xong 16:10–16:27, bằng `uat.receiver`)

- Nguyên nhân gốc lần 1: TEST03 thiếu `receiving.perform` + `receiving.post` trên TEST47. Seed vẫn gán 2 quyền này cho vai storekeeper/receiver cũ — nhưng TEST03 thực tế không có (và rà lại: TEST03 chưa bao giờ ghi sổ thành công phiếu nào; các phiếu 0008/0011 trước đây không phải do TEST03 ghi sổ). Lỗi ở phía brief: kế hoạch ngày 1 ghi "nhận hàng bằng TEST03" là giả định chưa từng kiểm chứng.
- **Bước 0 — vai của TEST03: KHÔNG xác nhận được qua trang quản trị.** Trang Quản trị hệ thống → Người dùng & Phân quyền (`/admin/users`) chỉ liệt kê đúng 1 người dùng là UAT Chủ đầu tư; tìm "test03", "test03@erp.internal", "Storekeeper" đều trả "Không tìm thấy người dùng." (xem R4-N7). Bằng chứng gián tiếp: menu tài khoản của test03 hiện "Test Storekeeper", phạm vi gồm Nhận hàng và Kho, mở được danh sách phiếu nhận (có receiving.view) — phù hợp giả thiết "Thủ kho trên TEST47", nhưng vai cụ thể không đọc được nên không ghi bừa.
- **Bước 1 — ghi sổ GRN-0009: ĐẠT.** `uat.receiver` bấm "Ghi sổ nhận hàng", nhập PIN → nguyên văn: "Đã ghi sổ phiếu nhận hàng thành công." Tồn NVL0561 ở Kho chính T047 = **180** (đơn giá BQ 5.000 đ, giá trị tồn 900.000 đ). GRN-0009 → ĐÃ GHI SỔ.
- **Bước 2 — hàng hỏng một phần trên GRN-0014: ĐẠT (có 2 điểm lưu ý).** Ghi dòng: gross 20, tare 0 → net 20; "Số lượng hỏng" = 2 + lý do "Dập nát trong quá trình vận chuyển" (trang ghi chú: "Phần hỏng không nhập kho; hệ thống tự lập phiếu trả hàng NCC cho phần hỏng."); tick ô miễn chụp ảnh + lý do "Thiết bị không có camera". Sau "Ghi dòng", app yêu cầu **cân lại lần 2** — nguyên văn: "Cần cân lại—Cân lại lần 2" + "Số lượng lệch quá dung sai so với đơn mua. Hãy cân lại để xác nhận số thực nhận." Lý do đúng thiết kế: hàng tốt 18 so với đặt 20 lệch 10% > dung sai 5% nên kích hoạt cân lại xác nhận; cân lần 2 đúng cùng số liệu (20/0) thì chấp nhận. Ghi sổ → "Đã ghi sổ phiếu nhận hàng thành công."
  - **Tồn sau ghi sổ: tổng 198 nhưng phân bổ lệch (R4-N6).** Kho chính T047 vẫn 180 (không tăng); **Kho bếp (Demo) = 18** (5.000 đ, 90.000 đ) — dòng này xuất hiện sau khi ghi sổ GRN-0014, dù tiêu đề phiếu GRN-0014 ghi "Kho chính T047". Kỳ vọng "tồn NVL0561 = 198" chỉ đúng ở mức tổng các kho, không đúng riêng tại KHO-T047.
  - **Phiếu trả hàng NCC: CÓ** — SRT-TEST47-LE-2611-0002 (id `e2fd854f-ba59-465e-8b1b-ab0178e3ce95`), NCC T047, phiếu gốc GRN-...-0014, PO-...-0005, Bánh bèo 2 cái, lý do "Dập nát trong quá trình vận chuyển", đơn giá gốc 5.000 đ, thành tiền 10.000 đ. Trạng thái thực tế là **"Chờ xác nhận"** (không phải "đã ghi nhận" như kỳ vọng trong brief — đây có vẻ là trạng thái khởi tạo đúng của phiếu trả; trang ghi "Xác nhận NCC đã lấy hàng/Hủy phiếu trả: Thao tác này chỉ làm được trên màn hình mobile hiện trường." — không xác nhận/hủy trong vòng này).
- **Bước 3 — khớp lại hóa đơn 0000124: ĐẠT — ĐÃ KHỚP.** Trước khi khớp: TẠM GIỮ, "SL vượt số đã nhận · SL đã nhận: 0 / SL còn được hóa đơn: 0". Bấm "Khớp 3 chiều" → trạng thái **ĐÃ KHỚP**, dòng "Đã khớp đủ 3 chiều." Kết quả từng tiêu chí (nguyên văn): số lượng — "SL khớp · SL đã nhận: 198 / SL còn được hóa đơn: 198"; đơn giá — "Giá khớp · Đơn giá đơn mua: 5.000 đ → Đơn giá hóa đơn: 5.000 đ (Lệch giá: 0%, Dung sai cho phép: 1%)". Hóa đơn cũ C25TAA/0000123 vẫn ĐÃ HỦY; không lập thêm hóa đơn. **Việc này xác nhận lỗi `invoice.manage` lúc 16:14 chỉ là hệ quả phiên đăng nhập (xem dưới) — kế toán khớp được bình thường.**
- Lưu ý khác: tài khoản receiver mở `/inventory/stock` thì báo "Không tìm thấy trang" (vai nhận hàng mù, không có quyền xem tồn — đúng thiết kế); chính owner cũng không có `receiving.view` (mở `/inventory/receipts` báo "Không thể tải dữ liệu / Bạn chưa được cấp quyền receiving.view"). Trang chủ/thanh điều hướng tải bất đồng bộ, đôi lúc chỉ hiện mục Danh mục vài giây đầu sau đăng nhập (quirk tải trang, không chặn).

## X3 — Bổ sung minibar theo tầng (đạt, 15:51–15:55)

- Khối "Bổ sung theo tầng" **ĐÃ HIỆN** với `uat.hk_attendant` (R3-N2 đã verify live): chọn Tầng (Tất cả / Tầng 1 – 10 phòng / Tầng 2 – 14 phòng / Tầng 3 – 6 phòng), Mặt hàng (7 món), Số lượng, nút "Bổ sung" (vô hiệu tới khi chọn đủ món + số lượng).
- Cấp bù 1 lần: Tầng 3 (6 phòng), Sprite ×1/phòng. Cả 6 phòng 301–306 đều báo "Đã bổ sung minibar vào phòng."
- Số liệu khớp tuyệt đối: MINIBAR_MAIN Sprite 10 → **4** (đúng 6 lon đã cấp); các món khác không đổi (Tiger 9, Diet Coke 9, Lavie 8, Coca-Cola 9, Larue 9, Rượu vang 2); tổng giá trị tồn 1.099.000 → **1.009.000 đ** (giảm 90.000 đ = 6 × 15.000 đ). Mỗi phòng 301–306: 0 → **1 lon Sprite**. Phòng 101/104 vẫn không có tồn hiển thị.
- Lưu ý: nhân viên buồng phòng vẫn thấy cảnh báo thiếu quyền xem tồn (`stock.view_qty`) nên không thấy tồn phòng trên màn của mình — nhưng khối cấp bù chạy bình thường, không bị chặn.

## X4 — Chứng từ kho trọn vòng (đạt một phần, 16:41–16:45)

- **Bước 1 — REQ-0002: HOÀN TẤT.** Phiếu REQ-TEST47-LE-2611-0002: ĐÃ DUYỆT → ĐÃ XUẤT → ĐÃ NHẬN. Thủ kho bấm "Xuất kho" (bảng xác nhận "ba chỉ nách — SL thực tế 2", bấm "Xác nhận"; trạng thái ĐÃ XUẤT, ĐÃ XUẤT = 2, ĐÃ NHẬN = 0, dòng "Đã thực hiện."). Bếp trưởng bấm "Xác nhận nhận hàng" (cùng bảng xác nhận; trạng thái ĐÃ NHẬN, ĐÃ XUẤT = 2, ĐÃ NHẬN = 2). **Không bước nào hỏi PIN.** Tồn: Kho chính T047 NVL0388 19 → **17 kg**; Kho bếp (Demo) NVL0388 0 → **2 kg**; NVL0561 không đổi (188 / 18). (Tác dụng phụ: lượng NVL0388 2 kg của ngày 1 đã về kho bếp qua phiếu này — tồn NVL0388 cuối ngày 1 nay đúng 17 kg như kỳ vọng, dù không phải qua phiếu lĩnh ngày 1; 3 cái NVL0561 của ngày 1 vẫn chưa lĩnh.)
- **Bước 2 — TRF-0002: KHÔNG LÀM ĐƯỢC (sai kho xuất — R4-N9).** Phiếu TRF-TEST47-LE-2611-0002 vẫn NHÁP (Đã chuyển 0, Đã nhận 0). Sai khác so với bối cảnh giao: kho xuất trên phiếu là **Kho chính T047** (không phải Kho minibar tổng), kho nhập "Minibar phòng 101", Tiger (MB-TIGER) 1 lon, ghi chú "V5 - nhap dieu chuyen test minibar phong 101". Thủ kho bấm "Chuyển hàng" → "Xác nhận" → nguyên văn: **"Không đủ tồn kho để xuất."** — đúng (Kho chính T047 không có Tiger; Tiger 9 lon nằm ở Kho minibar tổng). Không thử lại. Kiểm chứng sau: MINIBAR_MAIN Tiger vẫn 9 lon (không về 8); GM mở `/housekeeping/minibar` thấy mục tồn từng phòng chỉ liệt kê Phòng 301–306 (mỗi phòng Sprite 1 lon), không có thẻ Phòng 101 → Phòng 101 Tiger 0 lon. Muốn chuyển được phải sửa dữ liệu phiếu: đổi kho xuất của TRF-0002 sang Kho minibar tổng (hoặc nhập Tiger về Kho chính T047).
- **Bước 3 — PIS-0001: KHÔNG LÀM ĐƯỢC (phiếu cũ không sửa được — R4-N8).** Phiếu PIS-TEST47-LE-2611-0001 vẫn NHÁP: Mục đích "Khác", Kho "Kho chính T047", Trung tâm chi phí "—" (trống), Khoản mục "—", ghi chú "Xuất mục đích kiểm thử V4", đã có sẵn 1 dòng ba chỉ nách 1 kg. Trang chi tiết **không có nút Sửa hay Thêm dòng**; ô Trung tâm chi phí là chữ tĩnh (bấm vào không mở lựa chọn) nên không thể chọn cost center hay thêm dòng như kế hoạch. Bấm "Ghi sổ" → nguyên văn: **"Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập."** — phiếu vẫn NHÁP, không hỏi PIN, không ghi sổ được nên không có bước đảo phiếu. Đối chiếu form tạo mới (`/inventory/issues/new`, chỉ xem): Trung tâm chi phí là trường bắt buộc (*) với các lựa chọn "Hành chính & Quản lý", "Trung tâm chi phí T047", "Ẩm thực - Đồ uống", "Ẩm thực - Món ăn", "Bảo trì & Kỹ thuật", "Buồng phòng", "Năng lượng & Nước" (không có mục tên riêng "Bếp"; gần nhất là "Ẩm thực - Món ăn"). Tồn Kho chính T047 NVL0388 giữ nguyên 17 kg (không giảm, không có số liệu đảo vì phiếu chưa từng ghi sổ). Hướng tiếp: lập phiếu xuất mục đích MỚI với cost center đầy đủ rồi test ghi sổ + đảo trên phiếu mới — phiếu cũ tiền-Q273 này coi như không hoàn tất được.
- **Bước 4 — WST-0001: ĐÚNG KỲ VỌNG BỊ CHẶN.** Phiếu WST-TEST47-LE-2611-0001 vẫn NHÁP, 0 ảnh. Trang phiếu ghi: "Đã có 0 ảnh minh chứng— Cần ít nhất một ảnh minh chứng trước khi gửi duyệt." và "Chưa có ảnh chứng từ — Chứng từ này chưa có ảnh nào. Hãy chụp ảnh bằng camera trong app." Thủ kho bấm "Gửi duyệt" → nguyên văn: **"Thiếu ảnh bắt buộc. Hãy chụp ảnh rồi gửi lại."** Phiếu không nộp được; form không có đường upload. Dòng hàng: ba chỉ nách 1 kg, 0 đ; lý do "Hỏng do bảo quản", kho "Kho chính T047". Ảnh hủy hàng là bắt buộc và KHÔNG có đường miễn như ảnh nhận hàng (Q274) — từ trình duyệt cloud không chụp được nên bước này dừng ở đây đúng như kỳ vọng. (Nếu Duy muốn test hủy hàng từ cloud thì cần quyết có làm đường miễn ảnh cho hủy hàng như Q274 hay không.)
- Tồn cuối sau cả 4 bước: Kho chính T047 NVL0388 **17 kg**, NVL0561 **188 cái**; Kho bếp (Demo) NVL0388 **2 kg**, NVL0561 **18 cái**; Kho minibar tổng Tiger **9 lon** (các món khác không đổi); Kho trung chuyển NVL0388 0; Minibar phòng 101: Coca-Cola 0, Diet Coke 0, Larue 0 (không có Tiger).

## Vấn đề mới

- **R4-N1 (Cần Duy quyết, không phải lỗi lọc):** PO-...-0004 (0 đ, bước Quản lý) vẫn hiện trong hộp "Chờ tôi duyệt" của owner kèm nút Duyệt/Từ chối. Đã đọc code (`procurement/approvals/page.tsx`): bộ lọc Q282 chạy đúng theo quyền — chỉ hiện đơn khi bước hiện tại đòi quyền mà người xem có (`myPermSet.has(current.required_perm)`). Owner thấy đơn vì vai `sm_owner` giữ `po.approve` (seed 570000:84) — tức owner duyệt được cả đơn bước 1, không chỉ đơn lớn bước 2. Đúng mô hình quyền hiện tại (điều 10 AGENTS.md: kiểm quyền, không kiểm vai); kỳ vọng "owner không thấy đơn bước Quản lý" trong brief là sai giả định. **Hỏi Duy: giữ nguyên (owner duyệt được mọi đơn PO) hay gỡ `po.approve` khỏi `sm_owner` để owner chỉ thấy đơn bước 2 (≥100 triệu)?** Nếu gỡ thì Claude làm (seed change; cần xác nhận quyền của bước 2 trước).
- **R4-N2 (Chuyển Claude Code / gán vai):** TEST03 thiếu `receiving.perform` + `receiving.post` trên TEST47 dù seed gán cho vai storekeeper/receiver cũ. Vai thật của TEST03 vẫn chưa xác định được (trang quản trị không liệt kê — xem R4-N7). Hướng xử lý: gán đúng vai cho TEST03, hoặc xác nhận `uat.receiver` là người nhận chuẩn cho mọi vòng test sau (kế hoạch ngày 1 đã sửa theo hướng này; X2 chạy lại đã chứng minh `uat.receiver` nhận + ghi sổ được).
- **R4-N6 (Chuyển Claude Code — tồn vào nhầm kho, P1):** 18 cái tốt từ GRN-...-0014 vào **Kho bếp (Demo)** thay vì Kho chính T047, dù tiêu đề phiếu ghi "Kho chính T047". Tổng NVL0561 vẫn đúng 198 nên khớp 3 chiều vẫn đạt — nhưng phân bổ kho sai sẽ làm lệch tồn từng kho và mọi nghiệp vụ sau dùng KHO-T047 (lĩnh bếp, kiểm kê). **Không tái diễn ở GRN-...-0016 (phiên ngày 1, 16:40):** mở phiếu + chọn Kho chính T047 thì tồn về đúng kho này (NVL0388 19 kg, NVL0561 188 cái). Cần Claude kiểm tra `warehouse_id` của GRN-...-0014 so với `stock_moves` nó sinh ra: phiếu lấy kho nhận từ đâu (form mở phiếu? kho mặc định của người nhận? hay bug khi ghi sổ).
- **R4-N7 (Chuyển Claude Code / hỏi — P3):** trang Quản trị hệ thống → Người dùng & Phân quyền chỉ liệt kê đúng 1 người dùng là UAT Chủ đầu tư, tìm test03/Storekeeper đều "Không tìm thấy người dùng." — trong khi TEST03/TEST01/TEST02 và 16 tài khoản UAT đều tồn tại và đăng nhập được. Chưa rõ đây là lọc theo phạm vi quản trị (owner chỉ thấy chính mình), lỗi phân trang/tìm kiếm, hay danh sách chỉ hiện tài khoản có vai admin. Cần Claude xác nhận hành vi đúng của trang này.
- **R4-N8 (Chuyển Claude Code — phiếu cũ không hoàn tất được, P2):** PIS-...-0001 (tạo trước Q273, cost center trống) không có đường sửa trên trang chi tiết (không nút Sửa/Thêm dòng; ô cost center là chữ tĩnh) và "Ghi sổ" rớt validation "Dữ liệu không hợp lệ." Phiếu này coi như không hoàn tất được — hướng tiếp là lập phiếu xuất mục đích MỚI với cost center đầy đủ rồi test ghi sổ + đảo trên phiếu mới. Câu hỏi cho Claude: trang chi tiết phiếu nháp thiếu nút Sửa là đúng thiết kế hay thiếu (các loại phiếu khác sửa được dòng ở trạng thái nháp)?
- **R4-N9 (Chuyển Claude Code / sửa dữ liệu — P2):** TRF-...-0002 tạo với kho xuất Kho chính T047 trong khi Tiger chỉ có ở Kho minibar tổng → "Không đủ tồn kho để xuất." Cần đổi kho xuất của phiếu sang Kho minibar tổng (hoặc lập phiếu điều chuyển mới đúng kho xuất) rồi chạy lại bước chuyển + xác nhận phòng 101.
- **R4-N3 (quan sát):** `uat.accountant` không xem được `/inventory/stock` — "Bạn chưa được cấp quyền xem tồn kho" (thiếu `stock.view_qty`). Kế toán vẫn thấy chênh lệch kiểm kê qua `count.view_variance` (Q282). Có nên cấp `stock.view_qty` cho kế toán không — để Duy/Claude quyết.
- **R4-N4 (P3, UI):** sau khi GM ghi điều chỉnh, tiêu đề mục vẫn hiển thị "Chờ duyệt điều chỉnh · Bút toán đã ghi: 0" trong khi banner báo "Đã ghi 1 bút toán điều chỉnh." — bộ đếm chưa cập nhật (có thể chỉ cần refresh trang).
- **R4-N5 (P3, UI):** menu Kho của owner hiện nhưng mở báo "Không thể tải dữ liệu — Bạn chưa được cấp quyền thực hiện thao tác này." (mục menu hiện dù không có quyền mở).

## Chuyển Claude Code

- R4-N2: xác định + sửa gán vai cho TEST03 (hoặc xác nhận `uat.receiver` là người nhận chuẩn) — vai thật vẫn chưa đọc được do R4-N7.
- R4-N6: tồn GRN-...-0014 vào nhầm Kho bếp (Demo) — kiểm tra `warehouse_id` của phiếu so với `stock_moves` nó sinh ra. (Không tái diễn ở GRN-...-0016.)
- R4-N7: trang quản trị người dùng chỉ liệt kê owner — xác nhận hành vi đúng (lọc phạm vi hay lỗi).
- R4-N8: phiếu xuất mục đích cũ (PIS-...-0001) không sửa được cost center — trang chi tiết thiếu nút Sửa là đúng thiết kế hay thiếu?
- R4-N9: TRF-...-0002 sai kho xuất — đổi kho xuất sang Kho minibar tổng (hoặc lập phiếu mới đúng kho).
- R4-N4, R4-N5: 2 lỗi hiển thị P3 (bộ đếm bút toán chưa cập nhật; menu Kho hiện dù owner không có quyền mở).
- R4-N1 chỉ làm khi Duy quyết gỡ `po.approve` khỏi `sm_owner`.

## Cần Duy quyết

- R4-N1: giữ hay gỡ `po.approve` khỏi `sm_owner`?
- Giá đ/kg NVL0152 (PO-...-0002) hoặc bỏ dòng — vẫn chưa quyết (từ 13/11; đã hỏi lại trong báo cáo rerun3).
- Phân quyền `pos.import` / `item.import` / `price.ceiling.manage` (từ rerun3 — bài hướng dẫn đã sửa theo seed hiện tại; đổi vai = đổi seed).
- Vai cấp bù minibar: **đã rõ** — `uat.hk_attendant` sau R3-N2, X3 đã verify live. Đóng mục này.

## Số liệu cuối (tính tới 16:45, 15/11/2026 — rerun4 xong X1–X4; Ngày 1 phiên tiếp xong)

- CNT-...-0005: **ĐÃ ĐIỀU CHỈNH** (NVL0388 9 kg lúc khóa; sau nhận + lĩnh: Kho chính T047 NVL0388 **17 kg**). CNT-...-0004: **ĐÃ HỦY**.
- NVL0388: Kho chính T047 **17 kg**, Kho bếp (Demo) **2 kg**. NVL0561: Kho chính T047 **188 cái**, Kho bếp (Demo) **18 cái**.
- MINIBAR_MAIN: Tiger **9**, Diet Coke 9, Lavie 8, Coca-Cola 9, Larue 9, Sprite **4**, Rượu vang 2 (tổng 1.009.000 đ). Phòng 301–306: Sprite 1 lon/phòng. Phòng 101: Tiger 0 (TRF-0002 chưa chuyển được).
- Hóa đơn: C25TAA/0000123 **ĐÃ HỦY**; C25TAA/0000124 (990.000 đ) **ĐÃ KHỚP** (SL đã nhận 198/198, giá lệch 0%).
- GRN-...-0009, GRN-...-0014, GRN-...-0016: **ĐÃ GHI SỔ**. GRN-...-0002 (nháp của TEST03): vẫn **NHÁP, 0 dòng** (app mở phiếu nháp riêng của từng người nhận). Phiếu trả NCC SRT-...-0002 (2 cái, 10.000 đ): **Chờ xác nhận**.
- REQ-...-0002: **ĐÃ NHẬN** (đủ 2/2). TRF-...-0002: **NHÁP** (sai kho xuất). PIS-...-0001: **NHÁP** (không sửa được cost center). WST-...-0001: **NHÁP** (chặn thiếu ảnh — đúng kỳ vọng).
- MB-0001 (Đã thu 140.000 đ), MB-0002 (Đã kiểm, 0 đ) không đổi. MB-...-0008 không tồn tại (R3-N3 đã đóng).
- PO-...-0001: **ĐÃ NHẬN**. PO-...-0002: **NHÁP** (chờ giá NVL0152). MON01 chưa import (Q168) — phần bán ngày 1 chưa làm được.

## Việc bỏ qua / chưa làm

- TRF-0002 và PIS-0001 chưa hoàn tất (kẹt dữ liệu phiếu — xem R4-N9, R4-N8); hướng tiếp: sửa kho xuất TRF-0002 (hoặc lập phiếu mới) và lập phiếu xuất mục đích mới có cost center, chạy lại 2 bước này.
- WST-0001 dừng ở chặn thiếu ảnh đúng kỳ vọng (cần quyết của Duy nếu muốn đường miễn ảnh cho hủy hàng như Q274).
- Không thử lại khóa đợt lần 3 ở lần chạy 15:49 (đúng luật dừng 2 lần; lần chạy lại sau deploy đã đạt ngay lần 1).
