# Báo cáo tổng — Đợt chạy lại R1–R5 (sau bản sửa Q275–Q276)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Nhánh `feat/muse-rerun` (từ main `eefc372`), 5 commit `T-R1:` … `T-R5:` + commit báo cáo tổng này. Chỉ viết báo cáo (docs), không sửa code, không chạm dữ liệu sản xuất ngoài các bước kiểm thử theo đặc tả.
- Kết quả chung: **R5 đạt toàn bộ; R1 đạt một phần; R2 không đạt (hồi quy P0); R3 không đạt (kẹt PIN); R4 chưa chạy (chờ hết đóng băng kho).**

## Bảng kết quả

| Bài | Nội dung | Kết quả | Commit |
|---|---|---|---|
| R1 | C2 chạy lại: cân lại lần 2 GRN-...-0009 (NVL0561 180) → ghi sổ → tồn 180 → hóa đơn Tạm giữ → phiếu trả NCC | **Đạt một phần** — nút ghi sổ đã BẬT sau lần cân 2 (C2-N1 giữ); nút "Lập phiếu trả hàng NCC" đã có và chỉ liệt kê phiếu đã ghi sổ; nhưng **ghi sổ bị chặn bởi khóa kiểm kê** nên tồn vẫn 0, hóa đơn vẫn Tạm giữ, chưa lập được phiếu trả | `9085a76` |
| R2 | C5 chạy lại: nhận PO-...-0006 vào kho minibar tổng → cấp bù phòng 101 → thu MB-...-0001 140.000 đ | **Không đạt** — ô "Kho nhận" đã có Kho minibar tổng (C5-N1 giữ); nhưng **phương án không-camera (waiver Q274) đã biến mất trên app live** → GRN-...-0011 (7/7 dòng, 0 ảnh) kẹt Nháp; tồn minibar tổng/phòng 101 vẫn 0; MB-...-0001 vẫn Chờ thu 140.000 đ (B-3 vẫn mở) | `3b31a8c` |
| R3 | C3 chạy lại: nộp đợt CNT-...-0005 (NVL0388 đếm 9 / sổ 10) → GM duyệt chênh lệch → tồn 10 → 9 kg | **Không đạt (dừng bước 1)** — nộp đợt báo "Mã PIN không đúng" chung chung, không chỉ rõ người nào; cần Duy đối chiếu PIN 8 người đếm. Ngoài ra đợt kiểm kê tháng nhiều khả năng còn cần đếm lần 2 trước khi nộp (xem R3-N3) | `5945993` |
| R4 | C4: chứng từ kho trọn vòng sau khi hết đóng băng (REQ-...-0002, TRF-...-0002, PIS-...-0001, WST-...-0001) | **Chưa chạy** — kho KHO-T047 vẫn đóng băng vì CNT-...-0005 chưa nộp xong (R3 kẹt) | — |
| R5 | Quét lại nhanh 5 điểm sửa Q276 | **Đạt toàn bộ 5/5** — tìm không dấu, nút làm mới thẻ kho, ẩn nút Duyệt với người tạo, GM mở form PR bị chặn bằng thông báo quyền, ngày trả dd/mm/yyyy HH:mm | `0a41f7d` |

## Lỗi mới (đánh số theo bài)

### Chặn
- **R2-N1 [P0] — Phương án không-camera (waiver Q274) đã biến mất trên app live.** Nhận hàng mobile bắt buộc ảnh nhưng không có ô tích xác nhận + lý do; "Ghi dòng" cho ghi không ảnh, "Ghi sổ" mới báo "Thiếu ảnh bắt buộc. Hãy chụp ảnh rồi gửi lại."; dòng đã ghi không mở lại được để bổ sung ảnh. Đây là **hồi quy so với đợt cycle C1 (14/11, main d93b877)**: khi đó waiver đã xác minh là hoạt động. Giữa d93b877 và eefc372, bản sửa Q276 có chạm `src/components/receiving/mobile-line-form.tsx`. Phiếu GRN-...-0011 kẹt Nháp (7/7 dòng, 0 ảnh). Chuyển Claude Code.
- **R1-N1 [P1, không phải lỗi app]** — Khóa kiểm kê chặn ghi sổ phiếu nhận ("Kho đang kiểm kê nên tạm dừng ghi nhận xuất nhập ở kho này."). Hành vi đúng theo thiết kế; hệ quả về thứ tự: **R1 chỉ hoàn tất được sau khi R3 nộp đợt xong** (R3 phải chạy trước phần còn lại của R1). R2 nhận vào kho minibar tổng không chạm KHO-T047 nên không bị chặn bởi đóng băng này (R2 kẹt vì R2-N1, không phải vì đóng băng).
- **R3-N1 [P1] — Nộp đợt báo PIN sai chung chung, không chỉ rõ người nào.** Hộp thoại nộp đợt không gắn tên người với từng ô PIN (chỉ đánh số 1–8). Đã tra code (`count_submit`, migration 20261109533000): thứ tự nhập thật sự không quan trọng và hai người trùng PIN cũng không sao — nên nguyên nhân là có ít nhất một người trong 8 người có PIN lưu khác hẳn 8 giá trị đã nhập, hoặc chưa có PIN. Cần Duy đối chiếu PIN 8 người đếm (xem mục "Cần Duy quyết").

### Giao diện / thiết kế
- **R3-N2 [P2]** — Trang chi tiết đợt trên desktop không có lối vào màn đếm/nộp đợt (chỉ có hủy đợt); màn đếm + nút "Nộp đợt" chỉ tồn tại trên đường `/m/…/count/…` mà không có liên kết nào từ giao diện desktop dẫn tới (đã xác minh bằng code).
- **R3-N3 [P1 tiềm ẩn, suy ra từ code, chưa kiểm chứng live]** — Đợt kiểm kê tháng (`monthly_full`) yêu cầu mỗi dòng phải có đủ 2 lần đếm (`counted_qty_1` và `counted_qty_2` đều khác NULL) thì `count_submit` mới qua được bước kiểm đủ số liệu, nếu không báo `ERR_COUNT_INCOMPLETE`. Dòng NVL0388 hiện mới đếm 1 lần (9 kg). Nghĩa là ngay cả khi PIN đúng, lần nộp tiếp theo nhiều khả năng vẫn rớt vì thiếu lần đếm 2 — cần đếm lần 2 cho dòng NVL0388 (người đếm khác đếm lại) trước khi nộp. Luồng đếm lần 2 trên giao diện vẫn chưa rõ (C3-N5).
- **R2-N2 [P2]** — "Bổ sung theo tầng" không chọn được phòng riêng (áp dụng cho cả tầng; đã báo lỗi cho 10 phòng 101–110 cùng lúc). Chưa xác minh đường điều chuyển có chọn được phòng riêng không (tồn nguồn đang 0 nên chưa thử được).
- **R1-N2 / R2-N3 [P2]** — Hộp thoại PIN khó dùng: trên desktop, ô PIN 6 số và nút Hủy/Xác nhận bị thanh hành động cố định phía dưới che khuất (bấm chuột bị từ chối, phải dùng phím Tab/Enter); hộp thoại PIN ghi sổ lần đầu chỉ hiện nội dung xác nhận mà không thấy ô nhập PIN, phải bấm "Ghi sổ" lần nữa mới hiện 6 ô nhập PIN. (Cùng họ với C1-N3.)
- **R5-N4 [P3]** — Định dạng ngày chưa nhất quán trên cùng trang phiếu thanh toán: "Ngày trả" đã đúng dạng 14/11/2026 12:55 nhưng "Hạn trả" vẫn dạng yyyy-mm-dd ("Hạn trả: 2026-12-14").
- **R5-N5 [P3, ngoài phạm vi Q276]** — Đường `/finance/payments` trả 404; đường đúng của danh sách phiếu thanh toán là `/finance/payment-requests`.
- **R1-N4 [P3]** — Đường `/inventory/receipts` không có UUID khách sạn trả "Không tìm thấy trang" — phải dùng `/<uuid-khách-sạn>/inventory/receipts`.
- **R5-N2 [P3]** — Sau khi bấm "Làm mới số liệu thẻ kho" không thấy thông báo/toast xác nhận; chỉ thấy nút chuyển sang "Đang làm mới…" rồi dữ liệu cập nhật.
- **R5-N1 [ghi chú]** — Thẻ kho trước khi làm mới trống hoàn toàn (0 dòng, 0 đ) dù tồn kho live đã 10 kg; số liệu chỉ hiện sau khi bấm làm mới (đây chính là lý do Q276 thêm nút làm mới — nút đã giải quyết được vấn đề).

### Ghi chú / xác nhận lại
- **R1-N3** — Phiếu GRN-...-0009 đã ở "Lần cân: 2" và nút ghi sổ bật ngay từ đầu lần chạy (không phải đang chờ cân lại lần 2 như mô tả đầu bài) — luồng nhập cân lần 2 chưa được thực thi lại trong lần chạy này; chỉ xác minh được trạng thái cuối sau lần cân 2 (nút bật), không phải thao tác nhập lần 2. (Suy đoán: một trong các lần thử cân lại ở C2 thực ra đã ghi được lần cân 2.)
- **R2-N4** — Phiếu MB-...-0002 hiển thị "Chờ thu tiền · 0 đ" trên trang lễ tân, trong khi trạng thái đầu bài ghi là "Đã kiểm 0 đ" — nhãn trạng thái không nhất quán.
- **R2-N5** — Tài khoản HK supervisor thiếu quyền xem số lượng tồn (stock.view_qty) nên không xem được tồn kho phòng trên trang minibar buồng phòng (đã biết từ C6).
- **R5-N3** — Thẻ kho tổng hợp theo kho/mã/lô, không có chi tiết theo từng chứng từ (số phiếu GRN-...-0008 không hiện trực tiếp).
- **C2-N3 tái xác nhận** — Trên dòng nhận của GRN-...-0009 không có ô ghi "5 hỏng" (thẻ dòng chỉ hiển thị số thực nhận net 180 / gross 180 / tare 0, "Lần cân: 2", "Đã chụp ảnh: 0", nhãn "Đạt") — vẫn chưa sửa, đang chờ Duy quyết hướng thiết kế (cần thay đổi RPC).
- **C2-N4 đã sửa (giao diện)** — Nút "+ Lập phiếu trả hàng NCC" đã có ở `/receiving/returns`; form ghi "Chỉ phiếu nhận đã ghi sổ mới trả được hàng" và ô chọn phiếu chỉ liệt kê phiếu đã ghi sổ (GRN-...-0008). GRN-...-0009 chưa ghi sổ nên chưa lập được phiếu trả cho nó.

## Chuyển Claude Code (ưu tiên)
1. **R2-N1 (P0)** — Khôi phục phương án không-camera (ô tick + lý do) trên màn nhận hàng mobile; cho phép bổ sung ảnh cho dòng đã ghi ở phiếu nháp; đối chiếu thay đổi Q276 ở `mobile-line-form.tsx` với bản Q274.
2. **R3-N1 (P1)** — Hộp thoại nộp đợt: gắn tên người đếm với từng ô PIN; khi PIN sai thì báo rõ ô/người nào (hoặc ít nhất báo số lượng ô sai).
3. **R3-N2 (P2)** — Thêm liên kết từ trang chi tiết đợt desktop tới màn đếm mobile (`/m/…/count/…`).
4. **R2-N2 (P2)** — "Bổ sung theo tầng": cho chọn phòng riêng (hoặc ghi rõ đường điều chuyển là cách cấp riêng một phòng).
5. **R1-N2 / R2-N3 (P2)** — Sửa hộp thoại PIN bị thanh hành động che / lần đầu không hiện ô nhập PIN.
6. **R5-N4, R5-N5, R1-N4 (P3)** — Định dạng "Hạn trả" dd/mm/yyyy; đường `/finance/payments` 404; đường `/inventory/receipts` không UUID 404.
7. **R5-N2 (P3)** — Thêm toast xác nhận sau khi bấm "Làm mới số liệu thẻ kho".
8. **R3-N3** — Làm rõ luồng đếm lần 2 trên giao diện (đợt tháng yêu cầu 2 lần đếm mỗi dòng trước khi nộp).

## Cần Duy quyết
1. **PIN 8 người đếm (chặn R3, R1-phần-còn-lại, R4)** — Nộp đợt CNT-...-0005 báo PIN sai chung chung; app không nói PIN của ai sai. Cần Duy vào `/admin/users` đối chiếu 8 người đếm (UAT Chủ đầu tư, Dương Ngọc Duy, test 01, TEST03, UAT Bartender, UAT Bếp trưởng, UAT Thủ kho, UAT Thu mua): người nào chưa có PIN hoặc PIN khác với ý định thì đặt lại, rồi báo tau chạy lại R3 từ bước nộp (không cần đếm lại; dòng NVL0388 vẫn 9 kg). Lưu ý: tau đã tra code — thứ tự nhập không quan trọng và trùng PIN không gây lỗi, nên chắc chắn là có người PIN khác/chưa có PIN.
2. **C2-N3 (đứng từ C2)** — Ghi "5 hỏng" một phần trên dòng nhận: cần thay đổi RPC, chờ Duy quyết hướng thiết kế.
3. Các mục đứng từ trước (xem báo cáo cycle): quyết giá NVL0152 cho Ngày 1 đợt test 30 ngày; grant stock.view_value cho cost_controller (hỏi từ 12/11, chưa trả lời); các mục Q71/Q76/Q83, tên pháp nhân thật, Q157/Q168.

## Trạng thái cuối TEST47 (14/11/2026 ~15:05)
- **Tồn KHO-T047: NVL0388 = 10 kg** (sổ; đếm 9 kg đã ghi nhưng chưa nộp/chưa điều chỉnh), **NVL0561 = 0 cái**. Tổng giá trị tồn 1.000.000 đ. **SUP0001 phải trả = 0 đ.**
- **PO:** 0001 sent 1.040.000 đ; 0002 draft 1.040.000 đ (3 dòng, NVL0152 giá 0 — Ngày 1 kẹt); 0003 received 1.000.000 đ; 0004 market CHỜ DUYỆT (0 đ / estimate 500.001 đ); 0005 sent 1.000.000 đ ("Đã nhận 0"); 0006 sent 1.180.000 đ ("3 phiếu chờ nhận").
- **GRN:** 0008 đã ghi sổ (C1); 0009 + 0010 nháp, kẹt chờ cân lại đã xong nhưng chưa ghi sổ được vì khóa kiểm kê (R1); 0011 nháp (R2, 7/7 dòng, 0 ảnh, kẹt vì thiếu ảnh); 0012 nháp (R2, 0/7 dòng, kho nhận chưa xác minh — ô chọn thu gọn vẫn hiện "Kho bếp (Demo)" trong khi MINIBAR_MAIN đang được tô sáng); 0001 (TEST02) không ghi sổ được vì SoD — bỏ.
- **Hóa đơn/thanh toán:** C26TAA 0000001 đã thanh toán (PAY-...-0001, bank ref FT2611140001); C25TAA/0000123 TẠM GIỮ (chênh lệch SL: hóa đơn 200 / đã nhận 0).
- **Đợt kiểm kê:** CNT-...-0004 ĐANG MỞ (0 dòng); **CNT-...-0005 ĐANG ĐẾM** (1/1 dòng, NVL0388 = 9 kg, chưa nộp — kẹt PIN). **KHO-T047 vẫn đóng băng.**
- **Minibar:** MB-...-0001 (phòng 101) "Chờ thu tiền" 140.000 đ, chưa thu được (B-3); MB-...-0002 (phòng 104) "Đã kiểm" 0 đ (nhãn trên trang lễ tân: "Chờ thu tiền · 0 đ"). MINIBAR_MAIN = 0; tồn phòng 101 = 0.
- **Chứng từ kho:** REQ-...-0002 ĐÃ DUYỆT (chưa xuất — chờ hết đóng băng); REQ-...-0004 CHỜ DUYỆT (chef tạo); REQ-...-0001 draft; REQ-...-0003 draft (tự động từ bán món); WST-...-0001 draft (0 ảnh); TRF-...-0002 draft (Tiger ×1 → Minibar 101); PIS-...-0001 draft.
- **Nhà hàng:** phiên buffet 13/11 "Đã hoàn tất"; doanh thu F&B 01–14/11 = 145.000 đ.

## Việc còn lại sau đợt này
1. **R1-phần-còn-lại** (sau khi R3 nộp đợt xong): receiver ghi sổ GRN-...-0009 (nút đã bật) → tồn NVL0561 = 180 → chạy lại "Khớp 3 chiều" cho C25TAA/0000123 → lập phiếu trả 5 cái NVL0561 cho GRN-...-0009.
2. **R2-phần-còn-lại** (sau khi Claude khôi phục waiver): xác minh kho của GRN-...-0011/0012 → ghi sổ GRN-...-0011 (hoặc nhận lại bằng waiver) → cấp bù phòng 101 → thu MB-...-0001 → báo cáo Minibar 01–14/11 phải khớp (Doanh thu/Đã thu 140.000 đ, Chờ thu 0).
3. **R4** (sau khi hết đóng băng): REQ-...-0002 xuất kho → bếp xác nhận nhận; TRF-...-0002 chuyển → xác nhận; PIS-...-0001 thêm cost center + cost item → ghi sổ → đảo; WST-...-0001 vẫn cần ảnh (không có waiver) — ghi "không làm được" nếu không có camera, kiểm tra chặn nộp 0 ảnh phải có thông báo cụ thể.
4. **R3-phần-còn-lại** (sau khi Duy đối chiếu PIN): đếm lần 2 dòng NVL0388 (nếu nộp báo thiếu) → nộp đợt → GM duyệt chênh lệch (đếm 9 / sổ 10 / lệch −1) → tồn NVL0388 → 9 kg → đợt khóa → thử đếm thêm trên đợt đã khóa (phải bị chặn) → ghi có cần hủy CNT-...-0004 để mở đóng băng không + app có chặn mở đợt thứ 2 cùng kho không.

## Lệnh đã chạy + kết quả thật
- Nhánh `feat/muse-rerun` từ main `eefc372`; 5 commit báo cáo (R1 `9085a76`, R2 `3b31a8c`, R3 `5945993`, R5 `0a41f7d`, + commit báo cáo tổng này); gate `pnpm lint && pnpm typecheck && pnpm test` xanh ở mỗi commit.
- Đẩy nhánh `feat/muse-rerun`: **push thất bại** (`fatal: could not read Username for 'https://github.com'` — VM không push được GitHub, như mọi lần). Giao bằng bundle `~/workspace/erp-hotel-rerun-r1-r5.bundle` (verify OK) — Duy fetch từ ~/Downloads rồi merge vào main, push, không cần db push / vercel (chỉ docs).
