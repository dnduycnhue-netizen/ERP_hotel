# R1 — C2 chạy lại: chu trình chênh lệch (PO-...-0005, NVL0561 200 cái)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Kết quả: **Đạt một phần** — bản sửa C2-N1 giữ ở mức trạng thái cuối (phiếu GRN-...-0009 đã ở "Lần cân: 2", nút ghi sổ BẬT), nút "Lập phiếu trả hàng NCC" đã có và hoạt động đúng (chỉ liệt kê phiếu đã ghi sổ). Nhưng **ghi sổ bị chặn bởi khóa kiểm kê** (CNT-...-0005 đang mở, KHO-T047 đóng băng) nên tồn NVL0561 vẫn 0, hóa đơn vẫn Tạm giữ, chưa lập được phiếu trả cho GRN-...-0009. Phần còn lại của R1 chỉ chạy được sau khi R3 nộp đợt xong.
- Nhánh `feat/muse-rerun`, commit `T-R1:` (ghi sau khi gate xanh).

## Từng bước

### Bước 0 — Lấy ID của GRN-...-0009: ĐẠT
- uat.owner@erp.internal. Đường `/inventory/receipts` (không có UUID khách sạn) báo "Không tìm thấy trang" — phải dùng đường có UUID `/b0000000-0000-4000-8000-000000000002/inventory/receipts`. Tìm thấy GRN-TEST47-LE-2611-0009, trạng thái Nháp, 1 dòng. URL phiếu (chỉ ghi lại, không bấm): `https://erphotel.vercel.app/m/b0000000-0000-4000-8000-000000000002/receive/7332b6f4-2906-4f59-8ca0-3f8ab98cb750`.

### Bước 1 — Cân lại lần 2 trên GRN-...-0009: ĐẠT (có lưu ý)
- uat.receiver@erp.internal mở trực tiếp URL mobile trên. Màn phiếu hiển thị: "Đã ghi 1/1 dòng", "Đã ghi đủ các dòng.", dòng NVL0561 "Số thực nhận (net): 180 cai (Số cân (gross) 180, Bì (tare) 0)", **"Lần cân: 2"**, nhãn "Đạt", và nút "Ghi sổ nhận hàng" đang **BẬT** (đen, không bị khóa).
- Lưu ý quan trọng: trạng thái thực tế khác mô tả đầu bài — "Lần cân: 2" đã hiển thị sẵn và màn phiếu không có ô nhập cân lần 2 nào (bấm vào thẻ dòng hàng không mở form), nên lần chạy này **không nhập lại 180 cho lần cân 2**. Việc nút ghi sổ bật sau lần cân 2 là phù hợp với bản sửa C2-N1 — điểm C2-N1 **không tái hiện** ở bước này. (Suy đoán: một trong các lần thử cân lại ở C2 — lần "im lặng" — thực ra đã ghi được lần cân 2; chưa có bằng chứng khác, chỉ ghi lại trạng thái quan sát được.)

### Bước 2 — Ghi sổ phiếu nhận: KHÔNG ĐẠT (bị chặn bởi khóa kiểm kê)
- Receiver bấm "Ghi sổ nhận hàng" → hộp thoại "Nhập mã PIN để ghi sổ" (2 bước: xác nhận → nhập PIN 6 số; đã nhập PIN receiver) → app trả về nguyên văn: **"Kho đang kiểm kê nên tạm dừng ghi nhận xuất nhập ở kho này."** Phiếu vẫn Nháp.
- Thử bằng uat.storekeeper@erp.internal: cùng màn phiếu, bấm ghi sổ, nhập PIN thủ kho → nguyên văn: "Bạn chưa được cấp quyền receiving.post để thực hiện thao tác này." (đúng mô hình vai trò — thủ kho không có receiving.post.)
- Kết luận: hiện không tài khoản nào trong 2 tài khoản thử ghi sổ được GRN-...-0009 — receiver có quyền nhưng bị khóa kiểm kê, thủ kho thiếu quyền.

### Bước 3 — Kiểm tra tồn NVL0561: ĐẠT (kiểm tra)
- uat.storekeeper@erp.internal, `/inventory/stock`. NVL0561: "0 tồn kho" — "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại.", tức vẫn 0 cái, không có đơn giá bình quân/giá trị tồn (do phiếu chưa ghi sổ; kỳ vọng 180 cái không đạt được). NVL0388 đối chiếu vẫn đúng kỳ vọng: "ba chỉ nách", Kho chính T047, 10 kg, đơn giá BQ 100.000 đ, giá trị tồn 1.000.000 đ; tổng giá trị tồn toàn kho 1.000.000 đ.

### Bước 4 — Hóa đơn Tạm giữ xử lý chênh lệch thế nào: ĐẠT (chỉ ghi nhận)
- uat.accountant@erp.internal. Hóa đơn C25TAA/0000123 — trạng thái "TẠM GIỮ", NCC T047, ngày hóa đơn 2026-11-14, trước thuế 1.000.000 đ, thuế 0 đ, tổng 1.000.000 đ. Banner: "Hóa đơn tạm giữ: có dòng lệch so với đơn mua / số đã nhận. Xem chi tiết từng dòng bên dưới." Kết quả khớp dòng Bánh bèo: SL hóa đơn 200, đơn giá 5.000 đ, VAT 0%, thành tiền 1.000.000 đ; "SL vượt số đã nhận · SL đã nhận: 0 / SL còn được hóa đơn: 0" (đỏ); "Giá khớp · Đơn giá đơn mua: 5.000 đ → Đơn giá hóa đơn: 5.000 đ (Lệch giá: 0%, Dung sai cho phép: 1%)".
- Hành động duy nhất trên trang là nút "Khớp 3 chiều" — **không có nút Duyệt, không có nút Thanh toán, không có nút sửa số lượng, và không có gợi ý/hướng dẫn xử lý chênh lệch nào.** Lưu ý: "SL đã nhận: 0" vì GRN-...-0009 vẫn là nháp (khớp 3 chiều chỉ tính phiếu đã ghi sổ); sau khi ghi sổ xong cần chạy lại khớp. Không tự duyệt/thanh toán hóa đơn.

### Bước 5 — Phiếu trả hàng NCC: nút có, nhưng không lập được (phiếu chưa ghi sổ)
- uat.purchaser@erp.internal mở `/receiving/returns` thấy ngay nút **"+ Lập phiếu trả hàng NCC"** (tài khoản đầu tiên thử đã thấy nút — bản sửa C2-N4 đã có trên giao diện). Bấm nút → form "Tạo phiếu trả hàng" (`/m/.../receive/returns/new`) ghi: "Chỉ phiếu nhận đã ghi sổ mới trả được hàng. Chọn phiếu rồi nhập số lượng từng dòng." Ô "Chọn phiếu nhận đã ghi sổ" chỉ có đúng 1 lựa chọn là "GRN-TEST47-LE-2611-0008 · Công ty TNHH Thực phẩm Mẫu An Phát" — GRN-...-0009 **không có trong danh sách vì còn Nháp**, nên không thể lập phiếu trả cho PO-...-0005/GRN-...-0009 (NVL0561, 5 cái, "Hàng hỏng"); không có mã/trạng thái phiếu trả nào được tạo. Đã **không** lập phiếu trả cho GRN-...-0008 (phiếu khác, NCC khác).
- Đồng thời: trên dòng nhận của GRN-...-0009 **không có ô ghi "5 hỏng"** — thẻ dòng chỉ hiển thị số thực nhận (net) 180 / gross 180 / tare 0, "Lần cân: 2", "Đã chụp ảnh: 0", nhãn "Đạt" (phù hợp kỳ vọng C2-N3 chưa sửa).
- Phụ: purchaser mở trực tiếp URL phiếu 0009 bị chặn với thông báo "Bạn chưa được cấp quyền receiving.perform để thực hiện thao tác này."

## Lỗi / bất thường mới

1. **R1-N1 [Chặn — P1]** — Khóa kiểm kê chặn ghi sổ phiếu nhận: receiver nhận "Kho đang kiểm kê nên tạm dừng ghi nhận xuất nhập ở kho này." (trên trang tổng quan có thẻ "Kiểm kê · Đang kiểm kê: 1 phiếu chưa khóa sổ"). Đây là nguyên nhân gốc khiến bước 2, 3, 5 không hoàn thành. Hệ quả về thứ tự đợt chạy lại: **R1 chỉ hoàn tất được sau khi R3 nộp đợt kiểm kê xong** (R3 phải chạy trước phần còn lại của R1 — ngược với thứ tự R1 → R5 trong đặc tả; R2 nhận vào kho minibar tổng không chạm KHO-T047 nên vẫn chạy được trước).
2. **R1-N2 [Giao diện — P2]** — Hộp thoại PIN trên trình duyệt desktop bị che: khi hộp thoại "Nhập mã PIN để ghi sổ" mở, phần ô PIN 6 số và nút Hủy/Xác nhận bị thanh hành động cố định phía dưới của trang che khuất — bấm chuột vào nút bị từ chối (bị che), các ô PIN chỉ hiện ra sau khi dùng phím Tab/Enter để điều hướng; đã hoàn thành nhập PIN bằng bàn phím. (Cùng họ với C1-N3 — hộp thoại PIN trên màn mobile bị panel tóm tắt che.)
3. **R1-N3 [Ghi chú]** — Sai lệch trạng thái đầu so với mô tả bài: phiếu đã hiển thị "Lần cân: 2" và nút ghi sổ bật ngay từ đầu lần chạy, không phải đang chờ cân lại lần 2 với nút bị khóa như mô tả. Luồng nhập cân lần 2 chưa được thực thi lại trong lần chạy này — chỉ xác minh được trạng thái cuối sau lần cân 2 (nút bật), không phải thao tác nhập lần 2.
4. **R1-N4 [Giao diện — P3]** — Đường `/inventory/receipts` không có UUID khách sạn trả "Không tìm thấy trang" — phải dùng `/<uuid-khách-sạn>/inventory/receipts`.

## Việc còn lại của R1 (chạy sau R3)
Sau khi đợt CNT-...-0005 được nộp và khóa (R3): receiver ghi sổ GRN-...-0009 (nút đã bật) → kiểm tra tồn NVL0561 kỳ vọng 180 cái → chạy lại "Khớp 3 chiều" cho hóa đơn C25TAA/0000123 → lập phiếu trả 5 cái NVL0561 cho GRN-...-0009 (lúc đó phiếu sẽ xuất hiện trong danh sách phiếu đã ghi sổ).
