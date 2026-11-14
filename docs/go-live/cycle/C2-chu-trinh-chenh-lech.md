# C2 — Chu trình chênh lệch (PO-0005, NVL0561 200 cái)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- PO-TEST47-LE-2611-0005 (NCC NCC-T047, NVL0561 "Bánh bèo" 200 cái × 5.000 đ = 1.000.000 đ) đã ĐÃ GỬI trước bài (GM duyệt 10:19:05 14/11/2026).
- Kết quả: **Không đạt** — kẹt ngay bước 1 do lỗi app ở thao tác "Cân lại lần 2": phiếu nhận kẹt chờ cân lại, nút "Ghi sổ nhận hàng" bị vô hiệu hoá, không có hàng nhập kho nên các bước sau mất tiền đề. Bước 4 chạy được một phần trên số thực nhận 0 (không phải 180 như kịch bản).
- Nhánh `feat/muse-cycle`, commit `T-C2:` (ghi sau khi gate xanh).

## Từng bước

### Bước 1 — Nhận 180/200 + ghi 5 hỏng: KHÔNG ĐẠT (dòng đã ghi nhưng phiếu kẹt)
- Tài khoản uat.receiver@erp.internal.
- Mở nhiệm vụ PO-...-0005 tạo phiếu nhận nháp **GRN-TEST47-LE-2611-0009** (đúng kỳ vọng), kho nhận "Kho chính T047 (KHO-T047)".
- Màn dòng nhận NVL0561: **không hiện** số lượng PO, **không hiện** đơn giá (chỉ tên, đặc tả "Thực phẩm tươi sống & khô", đơn vị "cai", yêu cầu "Bắt buộc chụp ảnh").
- Ghi 5 hỏng: **có** ô QC/trạng thái ("Đạt" / "Không đạt" / "Chờ quyết định"); **không có** ô số lượng hỏng; **không có** ô ghi chú. Thử QC "Không đạt" thì app cảnh báo **"Hàng không đạt sẽ không được tính nhập và được đưa vào phiếu trả nhà cung cấp."** kèm ô "Lý do không đạt" bắt buộc — tức QC "Không đạt" áp cho **toàn bộ dòng** (cả 180 cái), không ghi được 5 hỏng riêng. Kết luận: không có cách ghi 5 hỏng trên màn dòng nhận; đã nhận 180 với QC "Đạt".
- Phương án không camera đã dùng: tích ô + lý do "Trình duyệt kiểm thử không có camera" → "Ghi dòng" → dòng đã ghi: "Đã ghi 1/1 dòng", "Lần 1: Số cân (gross)180, Bì (tare)0". Thông báo sau khi ghi dòng: **"Cần cân lại—Cân lại lần 2"** và **"Số lượng lệch quá dung sai so với đơn mua. Hãy cân lại để xác nhận số thực nhận."**; nút "Ghi sổ nhận hàng" bị vô hiệu hoá ngay từ thời điểm này.
- Cân lại lần 2 (tổng 180, bì 0, thực nhận 180, QC "Đạt", không camera + lý do): đã thử **3 lần trên 2 phiếu** — trên GRN-0009: lần 1 bấm "Cân lại" thất bại lặng (form bị reset, không có "Lần 2"); lần 2 báo lỗi đỏ nguyên văn **"Chứng từ đang ở trạng thái không phù hợp với thao tác này."**; trên phiếu nháp thứ hai GRN-...-0010 thử lại đúng quy trình đầy đủ cũng thất bại lặng (sau tải lại vẫn chỉ có "Lần 1", banner "Cần cân lại" vẫn còn, nút "Ghi sổ" vẫn khóa). Lỗi tái hiện được, không phải sự cố một lần.

### Bước 2 — Ghi sổ + thử SoD: KHÔNG KIỂM ĐƯỢC
- (a) Thủ kho (uat.storekeeper) mở GRN-0009: nút "Ghi sổ nhận hàng" **bị vô hiệu hoá**, không bấm được, **không** hiện hộp hỏi mã PIN, **không** có thông báo chặn quyền — khác kỳ vọng ở C1 (bị chặn vì thiếu `receiving.post` kèm thông báo). Không thể kết luận về `receiving.post`.
- (b) Receiver mở GRN-0009 (phiếu do chính mình mở): nút "Ghi sổ nhận hàng" cũng bị vô hiệu hoá, không bấm được, không hỏi PIN, không có thông báo. **Không thể xác nhận hay phủ nhận kết quả C1** (receiver ghi sổ được phiếu của mình); câu hỏi SoD vẫn mở, chỉ kiểm chứng lại được khi lỗi cân lại ở bước 1 được sửa.

### Bước 3 — Kiểm tra tồn sau nhận: KHÔNG ĐẠT
- Tồn KHO-T047 NVL0561 = **0 cái** ("0 tồn kho", "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại." — không có dòng tồn, không có đơn giá bình quân/giá trị tồn, không có thẻ kho/bút toán nhập nào). Kỳ vọng 180 cái.
- NVL0388 của bài C1 không bị chạm: vẫn 10 kg × 100.000 đ = 1.000.000 đ (dòng duy nhất trong tồn kho).

### Bước 4 — Hóa đơn nhập đủ 200, khớp 3 chiều: ĐẠT MỘT PHẦN
- Hóa đơn nháp đã tạo và **không duyệt**: Ký hiệu C25TAA, Số hóa đơn 0000123, ngày 14/11/2026, NCC T047, PO-...-0005, dòng "Bánh bèo" SL hóa đơn 200 × 5.000 đ, VAT 0%, tổng 1.000.000 đ, trạng thái NHÁP sau khi lưu (id 238eb732-6d40-4d68-8a00-80c7dfe70a19).
- Trả lời câu hỏi của bài: app **không chặn** tạo/lưu hóa đơn với SL > SL đã nhận — form còn điền sẵn SL hóa đơn = 200 (bằng SL đặt) trong khi "SL đã nhận: 0", không có cảnh báo lúc nhập hay lúc lưu. (Trả lời một phần câu V1-N3: ở mức lưu nháp thì không chặn; lúc duyệt thì chưa kiểm vì hóa đơn chưa được duyệt.)
- Bấm "Khớp 3 chiều" chạy được (không chặn khớp) và báo **LỆCH**, nguyên văn toàn bộ: banner đỏ **"Hóa đơn tạm giữ: có dòng lệch so với đơn mua / số đã nhận. Xem chi tiết từng dòng bên dưới."**; kết quả dòng: **"SL vượt số đã nhận · SL đã nhận: 0 / SL còn được hóa đơn: 0"** và "Giá khớp · Đơn giá đơn mua: 5.000 đ → Đơn giá hóa đơn: 5.000 đ (Lệch giá: 0%, Dung sai cho phép: 1%)". Sau khớp, hóa đơn chuyển NHÁP → **TẠM GIỮ**.
- Lưu ý: số lệch thực tế là 200 so với 0 (không phải 200 so với 180 như kịch bản) vì bước 1 bị chặn — cần chạy lại sau khi sửa cân lại.

### Bước 5 — Phiếu trả hàng NCC cho 5 cái hỏng: KHÔNG ĐẠT
- Không tạo được phiếu trả ở cả 3 chỗ đã thử:
  1. `/receiving/returns`: trang tồn tại, "0 phiếu trả hàng ncc", "Chưa có phiếu trả hàng nào.", **không có nút tạo phiếu trả**.
  2. Chi tiết phiếu nhận GRN-0009: trang chi tiết chính là màn mobile nhận hàng, chỉ có "Cân lại" / "Ghi sổ nhận hàng" (đều bị khóa), không có thao tác "Trả hàng"; riêng với tài khoản mua hàng, màn mobile này còn không tải được: "Không thể tải dữ liệu — Bạn chưa được cấp quyền receiving.perform để thực hiện thao tác này."
  3. Chi tiết PO-...-0005 (ĐÃ GỬI, "ĐÃ NHẬN: 0"): chỉ có nút "Đóng đơn", không có thao tác trả hàng.
- Không có mã phiếu trả, SL trả 0. Đường trả hàng duy nhất quan sát được là QC "Không đạt" toàn dòng (xem bước 1).

### Bước 6 — Kiểm tra tồn cuối: KHÔNG ĐẠT so với kỳ vọng
- NVL0561 cuối = **0 cái** (kỳ vọng 175 nếu trả được 5). Không có thẻ kho/bút toán nào: nhập 0, xuất/trả 0. Tồn NVL0561 đi 0 → 0 → 0 trong suốt chu trình.

## Dữ liệu kiểm thử đã tạo trên TEST47
- Phiếu nhận nháp GRN-TEST47-LE-2611-0009 (1/1 dòng đã ghi, kẹt chờ cân lại).
- Phiếu nhận nháp GRN-TEST47-LE-2611-0010 (1/1 dòng đã ghi, cũng kẹt chờ cân lại).
- Hóa đơn nháp C25TAA/0000123, PO-0005, 200 × 5.000 đ, hiện ở trạng thái TẠM GIỮ (sau khớp 3 chiều, chưa duyệt).
- Phiếu GRN-TEST47-LE-2611-0007 (PO-0005, Nháp, 0 dòng) đã tồn tại từ trước, không phải do bài này tạo.

## Lỗi / bất thường mới

1. **C2-N1 [Chặn — P0, DB/RPC/UI]** — **"Cân lại lần 2" không gửi được**: sau khi "Ghi dòng" lần 1 với SL thực nhận lệch dung sai so với PO (180/200), app yêu cầu cân lại nhưng bấm "Cân lại" không lưu được lần cân 2 — lúc thì thất bại lặng (form reset, không có "Lần 2", không báo lỗi), lúc thì báo "Chứng từ đang ở trạng thái không phù hợp với thao tác này."; nút "Ghi sổ nhận hàng" bị khóa vĩnh viễn, phiếu kẹt. Tái hiện: receiver, mobile `/m/<uuid>/receive`, PO-0005, kho KHO-T047, dòng NVL0561 tổng 180/bì 0/QC Đạt/không camera + lý do "Trình duyệt kiểm thử không có camera" → "Ghi dòng" → nhập lại 180/0 → "Cân lại" (đã tái hiện trên cả GRN-0009 và GRN-0010). Hệ quả: **mọi lần nhận hàng có chênh lệch số lượng ngoài dung sai đều không ghi sổ được**. Cần sửa rồi chạy lại toàn bộ C2 từ GRN-0009 (kèm dọn các phiếu nháp trùng nếu quy trình cho phép).
2. **C2-N2 [Giao diện — P2]** — Mở lại nhiệm vụ nhận của cùng một PO tạo phiếu nháp **mới** thay vì mở lại phiếu nháp đang có: lần mở thứ hai tạo GRN-...-0010 (0/1 dòng) trong khi GRN-0009 vẫn tồn tại; danh sách còn có GRN-0007 (PO-0005, Nháp, 0 dòng) từ trước. Đây là biến thể của B-6: Q267 nói "mỗi receiver một nháp riêng" là thiết kế, nhưng ở đây **cùng một receiver** mở lại cùng một PO cũng sinh thêm nháp — cần Claude Code xác nhận có phải thiết kế không, và dọn các nháp trùng (0007/0010) nếu được.
3. **C2-N3 [Giao diện — P2]** — Màn dòng nhận không có ô số lượng hỏng và không có ô ghi chú; QC "Không đạt" chỉ áp cho toàn bộ dòng (cả 180 cái sẽ không được tính nhập và bị đưa vào phiếu trả NCC) nên không thể ghi 5 hỏng trên tổng 180 đã nhận. (Đã biết một phần từ V2-N3 — nay xác nhận thêm: QC toàn dòng không thay thế được ô số lượng hỏng.)
4. **C2-N4 [Giao diện — P1]** — Không có điểm vào nào để tạo phiếu trả hàng NCC thủ công: trang `/receiving/returns` không có nút tạo; chi tiết phiếu nhận và chi tiết PO đều không có thao tác "Trả hàng". Đường trả hàng duy nhất quan sát được là QC "Không đạt" toàn dòng.
5. **C2-N5 [Giao diện — P2]** — Form hóa đơn: các đơn mua ở trạng thái "sent" (PO-0005, PO-0001) hiển thị **bị vô hiệu hoá** trong danh sách chọn (chỉ đơn "received" như PO-0003 hiển thị bật); việc chọn PO-0005 chỉ thực hiện được bằng điều hướng bàn phím/đường dẫn do app tự sinh — tùy chọn disabled mà vẫn chọn được bằng bàn phím là không nhất quán. Ngoài ra, chọn NCC rồi bấm phím mũi tên có thể vô tình đổi sang NCC khác (đã quan sát: từng chuyển nhầm sang SUP0001 rồi phải chọn lại NCC-T047). Cùng họ với C1-N4.

## Đề xuất tiếp theo
Sửa luồng cân lại (cho phép ghi lần cân 2 và mở lại nút Ghi sổ) rồi chạy lại toàn bộ C2 từ GRN-0009. Khi đó mới kiểm chứng được SoD ở bước 2, tồn 180 ở bước 3, khớp lệch 180/200 ở bước 4 và phiếu trả 5 cái ở bước 5.
