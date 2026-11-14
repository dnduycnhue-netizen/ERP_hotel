# Báo cáo tổng — Đợt chạy trọn chu trình có tồn kho (C1–C7)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Nhánh `feat/muse-cycle`, từ main `d93b877`. 7 commit `T-C1:` … `T-C7:` (trừ C4 — chưa chạy, xem bên dưới). Chỉ thao tác qua giao diện web, tài khoản `uat.*`, khách sạn TEST47. Không supabase db push/query, không migration, không vercel, không RPC/SQL trực tiếp, không đổi cấu hình. Gate `pnpm lint && pnpm typecheck && pnpm test` xanh ở mỗi commit.
- Kết quả chung: **2/7 Đạt (C1, C7), 2/7 Đạt một phần (C3, C6), 2/7 Không đạt (C2 — lỗi P0, C5 — không có đường giao diện), 1/7 Không kiểm được (C4 — bị đóng băng kho)**. Chu trình mua → nhận → hóa đơn → thanh toán **chạy trọn được một lần duy nhất** (C1, với số lượng khớp đúng). Mọi nhánh có chênh lệch số lượng, có kiểm kê, hoặc có minibar đều kẹt ở một bước chưa sửa được bằng giao diện.

## Bảng tổng kết C1–C7

| Bài | Kết quả | Commit | Tóm tắt |
|---|---|---|---|
| C1 — Chu trình mua → nhận → hóa đơn → thanh toán | **ĐẠT** | `78647b4` | GRN-...-0008 nhận đủ 10 kg NVL0388 bằng waiver không camera, receiver ghi sổ được; tồn 10 kg, giá trị 1.000.000 đ; hóa đơn C26TAA 0000001 khớp 3 chiều, GM duyệt, đề nghị PAY-...-0001 do Kế toán trưởng chuỗi duyệt (không phải GM), đã thanh toán; công nợ SUP0001 về 0. |
| C2 — Chu trình chênh lệch (nhận 180/200 + 5 hỏng) | **KHÔNG ĐẠT** | `b090f2e` | Cân lại lần 2 không gửi được (P0) — GRN-...-0009/0010 kẹt vĩnh viễn; không có ô ghi số hỏng; không có điểm tạo phiếu trả hàng NCC; hóa đơn 200 báo lệch, Tạm giữ. |
| C3 — Kiểm kê đếm mù | **ĐẠT MỘT PHẦN** | `75316a0` | Đợt CNT-...-0005 sinh đúng 1 dòng (NVL0388), đếm mù 9 kg; đóng băng kho được kiểm chứng (xuất kho bị chặn đúng). Nộp đợt kẹt vì cần PIN của cả 8 người đếm, chỉ biết 2/8. |
| C4 — Chứng từ kho trọn vòng | **KHÔNG KIỂM ĐƯỢC** | — | Bị đóng băng kho do CNT-...-0005 (và CNT-...-0004) chưa nộp — chờ Duy quyết về PIN/hủy đợt. Chưa chạy. |
| C5 — Minibar thu tiền | **KHÔNG ĐẠT** | `f5c27ae` | Không có đường giao diện nào để nhập hàng vào kho minibar tổng (mobile thiếu kho, desktop không có nút nhận) → không cấp bù phòng 101, không thu được MB-...-0001 (140.000 đ). Riêng phiếu 0 món (B-39) ĐẠT — gửi được. |
| C6 — Báo cáo + xuất Excel + giá trị tồn | **ĐẠT MỘT PHẦN** | `1c753b2` | 11/11 báo cáo tải được; giá trị tồn hiện đúng cho thủ kho + thu mua; tính mù giữ (HK + receiver). Thẻ kho trống (MV chưa làm mới); tìm không dấu không chạy ở trang Tồn kho; chi phí vận hành tính cả hóa đơn đang Tạm giữ. |
| C7 — Rà SoD & quyền còn lại | **ĐẠT** | `bf24ece` | Máy chủ chặn tự duyệt đúng (câu tiếng Việt, không lộ mã `ERR_*`); bảng quyền xem phiếu trả đã rõ (GM + receiver bị chặn); GM không tạo được PR ở mức danh sách. |

## Lỗi mới (tổng hợp từ C1–C7)

### P0 — chặn chu trình
- **C2-N1 — Cân lại lần 2 không gửi được.** Nhận 180/200 (lệch quá dung sai) → app đòi cân lại lần 2 → thử 3 lần trên 2 phiếu: 1 lần im lặng (form reset, không có "Lần 2", không báo lỗi), 1 lần báo đỏ "Chứng từ đang ở trạng thái không phù hợp với thao tác này.", 1 lần im lặng. Nút ghi sổ khóa vĩnh viễn. Hệ quả: **mọi lần nhận có chênh lệch số lượng vượt dung sai đều không bao giờ ghi sổ được.** C1 thoát được chỉ vì số lượng khớp đúng (10/10, cân 1 lần). Tái hiện: receiver → mở nhiệm vụ nhận PO-...-0005 → nhập 180/0/180 + waiver → "Đã ghi 1/1 dòng" → app đòi cân lại lần 2 → không gửi được. Phiếu GRN-...-0009/0010 đang kẹt.

### P1 — chặn một luồng nghiệp vụ
- **C5-N1 — Không có đường giao diện nào để nhập hàng vào kho minibar tổng.** Màn nhận hàng mobile: ô "Kho nhận" chỉ có Kho bếp (Demo), Kho nhà hàng (Demo), Kho chính T047 — không có MINIBAR_MAIN dù kho tồn tại trong danh mục. Giao diện desktop: chi tiết PO không có hành động nhận hàng (chỉ "Đóng đơn"), hub `/receiving` đẩy về mobile. Hệ quả: kho minibar không thể nhập hàng bằng giao diện → không cấp bù phòng → phiếu MB-...-0001 (140.000 đ) không thu được (B-3 vẫn mở, chưa có cách giải quyết bằng giao diện). PO-...-0006 (minibar, 1.180.000 đ) đang ĐÃ GỬI, chờ nhận — tiếp tục được ngay khi lỗi được sửa, không cần tạo lại PR/PO.
- **C2-N4 — Không có điểm tạo phiếu trả hàng NCC bằng tay.** `/receiving/returns` hiện "0 phiếu trả hàng ncc", "Chưa có phiếu trả hàng nào.", không có nút tạo với cả 6 vai trò đã thử (purchaser, GM, receiver, storekeeper, accountant, owner). Chi tiết phiếu nhận (màn mobile) không có hành động "Trả hàng"; chi tiết PO chỉ có "Đóng đơn". Đường trả duy nhất quan sát được là QC "Không đạt" cả dòng.
- **C3-N1 — Nộp đợt kiểm kê cần PIN của cả 8 người đếm, chỉ biết 2/8.** Hộp thoại nộp đợt: "Mỗi người đếm nhập mã PIN của mình."; nút nộp chỉ bật khi đủ 8 ô. Đã biết PIN: uat.storekeeper 111111, TEST03 111111. 6 người còn lại (UAT Chủ đầu tư, Dương Ngọc Duy, test 01, UAT Bartender, UAT Bếp trưởng, UAT Thu mua) chưa từng được đặt PIN qua admin. Nhập PIN thủ kho vào cả 8 ô → máy chủ báo "Mã PIN không đúng. Vui lòng thử lại." Đợt CNT-...-0005 (đã đếm 9 kg) không nộp được → kho KHO-T047 đóng băng → C4 kẹt theo. Quy tắc "người độc lập" cũng không rõ: mọi cặp 2 người đã thử đều bị chặn với cùng câu "Đợt kiểm kê cần ít nhất một người đếm độc lập, không phải người nhập hoặc xuất kho tại kho này." — chỉ chọn đủ 8 người mới mở được đợt.
- **C6-N5 — Tìm kiếm ở trang Tồn kho không hoạt động với từ không dấu.** `/inventory/stock` gõ "ba chi" → 0 kết quả; gõ có dấu "ba chỉ" → 1 kết quả NVL0388 tồn 10. Trong khi ở `/master/items`, "ba chi" không dấu hoạt động (ra 4 kết quả). Bản sửa Q273 (`items.name_search`) mới phủ danh mục vật tư, chưa phủ trang Tồn kho.
- **C6-N3 — Chi phí vận hành tính hóa đơn đang Tạm giữ.** `/reports/opex` (01–14/11) tổng chi phí 1.000.000 đ, trong đó "hóa đơn 1.000.000 đ", trùng giá trị hóa đơn C25TAA/0000123 đang ở trạng thái Tạm giữ (chưa duyệt, lệch SL 200 so với đã nhận 0). Cần đối chiếu: hóa đơn chưa duyệt / đang tạm giữ có nên tính vào chi phí vận hành không.

### P2 — cần sửa / cần xác nhận thiết kế
- **C1-N2 — Thủ kho thiếu quyền `receiving.post`.** Thủ kho bấm ghi sổ phiếu nhận → "Bạn chưa được cấp quyền receiving.post để thực hiện thao tác này." (sm_purchasing_store không có receiving.post — theo mô hình vai trò hiện tại chỉ receiver ghi sổ). Kỳ vọng trong bài là thủ kho ghi sổ — kỳ vọng này sai so với mô hình vai trò. Cần Claude Code/Duy xác nhận: receiver-only là đúng thiết kế hay thủ kho cũng cần quyền này.
- **C1-N1 — Bước duyệt đề nghị thanh toán giao cho Kế toán trưởng chuỗi, không phải GM.** GM bấm duyệt → "Bạn không phải người duyệt được giao cho bước này."; uat.chief_accountant duyệt được (không hỏi PIN). Kỳ vọng trong bài là GM duyệt — kỳ vọng này sai so với thiết kế bước duyệt hiện tại. Cần xác nhận đây có phải thiết kế đúng không.
- **C6-N1 — Thẻ kho trống dù đã có nhập kho C1.** `/reports/stock-card` (01–14/11, lọc KHO-T047) hiện "0 dòng", "Tổng giá trị 0 đ", trong khi `/inventory/stock` thấy NVL0388 tồn 10, giá trị 1.000.000 đ. Trang ghi dữ liệu từ materialized view làm mới 07:35 hằng ngày; bút toán sau lần làm mới chưa hiển thị. Cần xác nhận: đây là thiết kế (báo cáo chỉ đúng sau 07:35 hôm sau) hay cần nút làm mới thủ công trên giao diện.
- **C6-N2 — PO-...-0004 (CHỜ DUYỆT) không hiện trong báo cáo Đơn mua mở.** Báo cáo chỉ hiện 2 PO đều "sent" (PO-...-0001, PO-...-0005), tổng còn lại 2.040.000 đ. Cần xác nhận: báo cáo "Đơn mua mở" có gồm PO đang chờ duyệt không.
- **C7-N1 — Nút "Duyệt"/"Từ chối" vẫn hiển thị cho người lập phiếu** trên chi tiết phiếu lĩnh đang CHỜ DUYỆT (REQ-...-0004, chef). Bấm "Duyệt" thì máy chủ chặn đúng ("Bạn không phải người duyệt được giao cho bước này.") nên không thành lỗi bảo mật, nhưng giao diện đang để lộ nút duyệt cho người không được duyệt (cùng họ với V4-N4).
- **C7-N2 / V2-N2 — GM mở trực tiếp `/procurement/pr/new` vẫn thấy form tạo PR đầy đủ và nút "Lưu nháp"**, dù danh sách PR của GM không có nút "Tạo yêu cầu". V2 đã kiểm: bấm Lưu nháp thì máy chủ chặn ("Bạn chưa được cấp quyền pr.create..."). Cần ẩn form/chuyển hướng khi thiếu quyền thay vì chỉ ẩn nút ở danh sách.
- **C5-N3 — Chi tiết PO trên desktop không có hành động nhận hàng** (chỉ có "Đóng đơn"); hub `/receiving` chỉ có 3 thẻ (Danh sách phiếu nhận / Phiếu trả hàng NCC / Nhận hàng trên mobile). Toàn bộ luồng nhận hàng đi qua màn mobile duy nhất.
- **C2-N2 — Mở lại nhiệm vụ nhận của cùng một PO tạo phiếu nháp mới thay vì mở tiếp phiếu cũ.** Mở lại PO-...-0005 tạo GRN-...-0010 thay vì mở tiếp GRN-...-0009 (cùng receiver). Q267 kết luận "mỗi receiver có phiếu nháp riêng" là thiết kế — nhưng đó là trường hợp khác receiver; trường hợp cùng receiver tạo trùng cần Claude Code xác nhận + dọn các phiếu nháp trùng 0007/0009/0010 nếu được phép.
- **C2-N3 — Không có ô ghi số lượng hỏng / ghi chú trên dòng nhận.** QC chỉ có "Đạt"/"Không đạt"/"Chờ quyết định" cho CẢ DÒNG; chọn "Không đạt" thì toàn bộ dòng bị loại khỏi nhập và đưa vào phiếu trả. Không ghi được "180 nhận, 5 hỏng".
- **C3-N4 — App không chặn mở đợt kiểm kê mới khi đã có đợt đang mở cho cùng kho.** CNT-...-0005 mở được trong khi CNT-...-0004 vẫn ĐANG MỞ (cùng KHO-T047). Cần xác nhận thiết kế.
- **C3-N5 — Luồng đếm 2 lần chưa rõ.** Bảng chênh lệch của GM có cột ĐẾM LẦN 1 / ĐẾM LẦN 2 / SỐ ĐẾM, nhưng màn đếm mobile không bao giờ hỏi đếm lần 2; sau khi đếm 9 kg, ĐẾM LẦN 1 = 9, ĐẾM LẦN 2 = —, SỐ ĐẾM = —, SỐ SỔ = 10, CHÊNH LỆCH = —. Cần Claude Code giải thích luồng 2 lần đếm.
- **C1-N3 — Hộp thoại PIN trên màn nhận mobile bị che bởi panel tóm tắt phía dưới** — chuột không bấm được, chỉ dùng bàn phím (Tab/Enter).
- **C1-N5 — GM duyệt hóa đơn không có ô xác nhận trên trang** (bấm một cái là duyệt ngay) — không nhất quán với các thao tác khác (V4-N2).
- **C1-N6 — Không có bản ghi audit cho `stock_moves`** (lọc table=stock_moves → "Không có bản ghi nào khớp bộ lọc.").
- **C1-N4 — Ô chọn nhà cung cấp / PO trong form hóa đơn + đề nghị thanh toán không phản ánh lựa chọn cho đến khi tải lại trang.**
- **C5-N2 — Receiver bị chặn xem PO trên desktop bằng trang 404 chung** (không phải thông báo chặn quyền): `/procurement/po` → "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn"; owner mở cùng URL thì xem được.

### P3 — ghi chú / lỗi hiển thị nhỏ
- C6-N4 — Danh sách ngày chưa khóa sổ khác nhau giữa các báo cáo cùng khoảng ngày (Chất lượng nhận hàng chỉ liệt kê 14/11; Đơn mua mở/Tuổi nợ/Tạm ứng liệt kê 01–10/11 "và 4 ngày khác"; riêng Hủy hàng cùng khoảng lại xuất thành công). Cần xác nhận phạm vi ngày của từng báo cáo là đúng.
- C6-N6 — Tìm "ba chi" ở Danh mục vật tư trả thêm kết quả nhiễu (NVL0566 "bánh tráng chín", SEED-CCDC-0163 "Nhiệt kế đo chín bánh BG363") — khớp theo từng token rời.
- C6-N7 — Bản tin 8h ghi "Cảnh báo đỏ chưa xử lý: 8" nhưng đồng thời "Không có cảnh báo đỏ nào trong 24 giờ qua." — cần đối chiếu định nghĩa "chưa xử lý".
- C7-N3 — Trang chi tiết hóa đơn C26TAA 0000001 (xem bằng accountant) không hiển thị ghi chú SoD "Người tạo hóa đơn không được tự duyệt (tách biệt nhiệm vụ)." như ở C1, và không hiển thị trạng thái duyệt "ĐÃ DUYỆT" — chỉ có "ĐÃ THANH TOÁN" + bảng khớp từng dòng. Có thể ghi chú chỉ hiện khi hóa đơn đang chờ duyệt — cần xác nhận.
- C7-N4 — Chi tiết đề nghị thanh toán hiển thị ngày trả dạng thô chưa định dạng: "Ngày trả: 2026-11-14T05:55:53.306215+00:00".
- C7-N6 — Không có ô xác nhận trên trang khi bấm "Gửi duyệt"/"Duyệt" phiếu lĩnh (thực hiện ngay); các lần bấm "Lưu nháp"/"Gửi duyệt" phản hồi chậm vài giây.
- C5-N4 / V10-N6 — Menu bên hiển thị không ổn định giữa các lần tải: ngay sau đăng nhập menu đầy đủ phân hệ, sau khi tải lại trang chỉ còn "Tổng quan" và "Danh mục"; không dùng được làm căn cứ phân quyền.
- C5-N6 — Giá trên PR-...-0007 khác giá trên PO ở 2 dòng: Lavie PR 10.000/chai so với PO 8.000/chai; Rượu vang PR 380.000/chai so với PO 150.000/chai. Cần xác nhận giá dòng trên PR lấy từ đâu.
- C2-N5 — Form hóa đơn: PO ở trạng thái "sent" hiện TẮT trong danh sách chọn nhưng vẫn chọn được bằng phím điều hướng; phím mũi tên trong ô chọn nhà cung cấp có thể vô tình đổi nhà cung cấp (đã quan sát: nhảy sang SUP0001, phải chọn lại NCC-T047).

## Đã xác minh là đúng (kỳ vọng trong bài sai — không phải lỗi)
- **C1:** receiver (không phải thủ kho) là người ghi sổ phiếu nhận; bước duyệt đề nghị thanh toán giao cho Kế toán trưởng chuỗi (không phải GM). Cả hai đều đúng theo mô hình vai trò/bước duyệt hiện tại.
- **C6 bước 5:** xuất Excel bị chặn ở 4/5 báo cáo vì khoảng ngày chứa dữ liệu chưa khóa sổ là **đúng thiết kế** (chỉ kỳ/ngày đã khóa sổ mới xuất được); báo cáo Hủy hàng xuất được vì khoảng không có chứng từ hủy nên không cần khóa sổ — nhất quán với giải thích của Q273.
- **C7:** máy chủ chặn tự duyệt đúng, thông báo tiếng Việt, không lộ mã `ERR_*` (xác nhận kết luận Q273 về V4-N4).
- **C5 bước 8:** phiếu kiểm minibar 0 món gửi được (B-39 đã sửa xong — xác minh lại sau Q273).
- **C6:** tính mù giữ ở mọi màn đã kiểm (HK không thấy tồn lý thuyết; receiver không thấy PO/giá).

## Chuyển Claude Code (ưu tiên)
1. **P0 — C2-N1 cân lại lần 2.** Chạy lại C2 từ GRN-...-0009 sau khi sửa.
2. **P1 — C5-N1 nhận hàng vào kho minibar tổng.** Thêm MINIBAR_MAIN vào ô Kho nhận (mobile) và/hoặc hành động nhận hàng trên desktop. Chạy lại C5 từ bước 3 (PO-...-0006 đang chờ nhận).
3. **P1 — C2-N4 điểm tạo phiếu trả hàng NCC** (kèm C2-N3 ô số hỏng/ghi chú trên dòng nhận).
4. **P1 — C3-N1 nộp đợt kiểm kê** (quy tắc PIN 8 người + tiêu chí người đếm độc lập) — cần Duy quyết kèm theo (xem bên dưới).
5. **P1 — C6-N5 tìm kiếm trang Tồn kho không bỏ dấu** (mở rộng bản sửa Q273 sang trang Tồn kho).
6. **P1 — C6-N3 opex tính hóa đơn đang Tạm giữ** (xác nhận có đúng ý đồ không).
7. **P2 — C1-N2 / C1-N1** (xác nhận thiết kế vai trò/bước duyệt), **C6-N1** (thẻ kho MV), **C6-N2** (PO chờ duyệt trong báo cáo Đơn mua mở), **C7-N1** (ẩn nút Duyệt với người lập), **C7-N2** (ẩn form PR với GM), **C2-N2** (phiếu nháp trùng + dọn 0007/0009/0010), **C3-N4/N5** (mở trùng đợt + luồng đếm 2 lần), **C1-N3/N4/N5/N6**, **C5-N3** (hành động nhận trên desktop).
8. **P3 — C6-N4/N6/N7, C7-N3/N4/N6, C5-N4/N6, C2-N5.**

## Cần Duy quyết (chưa có trả lời)
1. **PIN nộp đợt kiểm kê (hỏi lúc ~13:19 ngày 14/11, chưa trả lời):** (a) dán 6 PIN còn lại của người đếm (UAT Chủ đầu tư, Dương Ngọc Duy, test 01, UAT Bartender, UAT Bếp trưởng, UAT Thu mua), hoặc (b) cho phép tau đặt PIN cho 6 tài khoản đó qua `/admin/users` rồi nộp CNT-...-0005 → GM duyệt chênh lệch (đếm 9 / sổ 10 / lệch −1) → tồn NVL0388 về 9 kg → đợt khóa → chạy C4, hoặc (c) chấp nhận C3 dở dang / hủy CNT-...-0005 để mở đóng băng kho cho C4 (số đếm 9 kg sẽ mất, đếm lại được sau). **C4 đang kẹt hoàn toàn vì quyết này.**
2. **C7-N5 / V2-N4:** GM (người duyệt) và receiver (người nhận hàng) đều không có quyền xem phiếu trả hàng (`receiving.view`) — có đúng thiết kế phân quyền không?
3. **C1-N2:** thủ kho có nên ghi sổ được phiếu nhận không, hay receiver-only là đúng?
4. **C1-N1:** bước duyệt đề nghị thanh toán giao cho Kế toán trưởng chuỗi (không phải GM) — có đúng ý đồ không?
5. **V3-N1 / V3-N2:** vật tư tồn 0 có được đếm không; tiêu chí "người đếm độc lập" là gì (và quy tắc nộp đợt cần PIN cả 8 người có đúng không).
6. **Ngày 1 đợt test 30 ngày:** giá NVL0152 'BA CHỈ XÔNG KHÓI' (đ/kg) hoặc đồng ý bỏ dòng này khỏi PO-...-0002 — vẫn chờ từ 13/11.
7. **Q233 Việc 2+3** (RPC `po_set_expected_date` + write guard): chỉ làm tiếp nếu Duy yêu cầu — cần rebase sang migration 582000+.
8. **Grant `stock.view_value` + `stock.view_qty` cho cost_controller** (hỏi 12/11, chưa trả lời).

## Trạng thái TEST47 cuối đợt (14/11/2026 ~14:00)

- **Tồn KHO-T047: NVL0388 = 10 kg (sổ sách; số đếm 9 kg đã ghi nhưng chưa nộp/chưa điều chỉnh), NVL0561 = 0 cái.** Giá trị tồn 1.000.000 đ. **SUP0001 phải trả = 0 đ** (hóa đơn C1 đã thanh toán đủ).
- **PO:** 0001 sent 1.040.000 đ (12/11, NCC-T047); 0002 draft 1.040.000 đ, 3 dòng (13/11, dòng NVL0152 giá tay 0 — điểm kẹt Ngày 1); 0003 **received** 1.000.000 đ (13/11, SUP0001, đã nhận ở C1); 0004 market **CHỜ DUYỆT** (tổng 0 đ / ước tính 500.001 đ); 0005 sent 1.000.000 đ (14/11, NCC-T047, NVL0561 200 cái, "Đã nhận 0"); 0006 sent 1.180.000 đ (14/11, NCC-T047, 7 món minibar, "Đã nhận: 0" — chờ sửa C5-N1).
- **PR:** 0001 (đã duyệt, đã chuyển), 0002 (đã duyệt), 0004 (chef, nháp), 0005 (thu mua, nháp), 0006 (đã duyệt + chuyển thành PO-0005), 0007 (đã duyệt, minibar).
- **Phiếu nhận (nháp trừ khi ghi khác):** 0001 (của TEST02, 2 dòng đã ghi, KHÔNG GHI SỔ ĐƯỢC do SoD — bỏ); 0002 (của TEST03, Ngày 1); 0003 + 0004 (demo test); 0005 (M9); 0006 (PO-0003, 0/1 dòng); 0007 (PO-0005, 0/1 dòng); **0008 ĐÃ GHI SỔ (C1, PO-0003, NVL0388 10 kg, dùng waiver)**; **0009 + 0010 (C2, PO-0005, 1/1 dòng đã ghi ở 180, KẸT chờ cân lại lần 2)**.
- **Hóa đơn/thanh toán:** C26TAA 0000001 (PO-0003) — đã duyệt + **ĐÃ THANH TOÁN** (qua PAY-...-0001, tham chiếu ngân hàng FT2611140001); PAY-TEST47-LE-2611-0001 — **ĐÃ THANH TOÁN**; C25TAA/0000123 (PO-0005, 200 × 5.000 đ) — **TẠM GIỮ** (khớp báo lệch SL, chưa duyệt).
- **Đợt kiểm kê:** CNT-...-0001/0002 (xe đẩy, 13/11, CHỜ DUYỆT — không chạm); CNT-...-0003 (tháng) ĐÃ HỦY (V3); **CNT-...-0004 (chu trình, KHO-T047) ĐANG MỞ, 0 dòng**; **CNT-...-0005 (tháng, KHO-T047) ĐANG ĐẾM (mobile) / ĐANG MỞ (desktop), 1/1 dòng đã đếm (NVL0388 = 9 kg), CHƯA NỘP (cần PIN 8 người đếm)**. **KHO-T047 ĐANG ĐÓNG BĂNG** trong khi các đợt đang mở (xuất kho bị chặn: "Kho đang kiểm kê nên tạm dừng ghi nhận xuất nhập ở kho này.").
- **Minibar:** MB-...-0001 (phòng 101) đã kiểm, "Chờ thu tiền" 140.000 đ, CHƯA THU (thu bị chặn vì thiếu tồn — B-3; chi tiết đã xác minh ở M5/V5: Tiger 1, Diet Coke 1, Lavie 2, Coca-Cola 1, Larue 1). MB-...-0002 (phòng 104) **"Đã kiểm" 0 đ** (gửi 0 món ở C5 bước 8). Giá bán 7 món hiệu lực 2026-11-11 (Tiger 35.000, Diet Coke 25.000, Lavie 15.000, Sprite 25.000, Coca-Cola 25.000, Rượu vang 245.000, Larue 25.000).
- **Chứng từ kho:** REQ-...-0001 (nháp, 13/11); **REQ-...-0002 (ĐÃ DUYỆT, NVL0388 2 kg, KHO-T047 → KHO_BEP, Đã xuất 0 — C4 sẽ xuất sau khi mở đóng băng)**; REQ-...-0003 (NHÁP, tự động từ bán ALA-02 ở V8, 7 dòng, 0.425); **REQ-...-0004 (CHỜ DUYỆT, chef, NVL0388 1 kg — tạo ở C7 để thử tự duyệt)**; WST-...-0001 (nháp, NVL0388 1 kg, 0 ảnh); TRF-...-0001 (ĐÃ HỦY); TRF-...-0002 (NHÁP, Tiger ×1 KHO-T047 → Minibar phòng 101, chưa gửi); PIS-...-0001 (nháp, NVL0388 1 kg).
- **Nhà hàng:** phiên buffet tối 13/11 ĐÃ ĐÓNG, hiển thị "Đã hoàn tất" (1 khách × 0 đ); doanh thu F&B 01–14/11 = 145.000 đ (dòng ALA-02 ngày 14/11 đã hủy).
- **Cảnh báo:** 11 cảnh báo (9 đỏ PERMISSION_CRITICAL_CHANGED + 2 xanh minibar); "Sáng nay"/bản tin 8h: cảnh báo đỏ chưa xử lý = 8.

## Lệnh đã chạy + kết quả thật
- Gate mỗi commit: `npx -y pnpm@12.14.0 lint && npx -y pnpm@12.14.0 typecheck && npx -y pnpm@12.14.0 test` — xanh cả 6 commit (lint, typecheck, Vitest).
- 6 commit trên nhánh `feat/muse-cycle` (từ `d93b877`): `78647b4` (C1), `b090f2e` (C2), `75316a0` (C3), `1c753b2` (C6), `bf24ece` (C7), `f5c27ae` (C5).
- 7 phiên trình duyệt cloud (C1 17ad3eb5 + tiếp nối, C2 8e05006e, C3 69d086ad, C6 9f3c3fcf, C7 ce4383c9, C5 1b6955be + tiếp nối a1f7c86b).

## Chưa xong + vì sao
- **C4 — chưa chạy:** kẹt đóng băng kho KHO-T047 (CNT-...-0005 chưa nộp). Cần Duy quyết về PIN (mục 1 ở trên). Khi mở đóng băng: xuất REQ-...-0002 → bếp nhận (thử nhận thiếu kèm ghi chú chênh lệch); gửi TRF-...-0002 → xác nhận; hủy một phiếu nháp khác; PIS-...-0001: thêm trung tâm chi phí + khoản mục (nay bắt buộc) → ghi sổ → đảo (kèm lý do); WST-...-0001: chụp ảnh (trình duyệt cloud không có camera, waste không có waiver → ghi là không làm được; nộp với 0 ảnh phải bị chặn).
- **C2 chạy lại:** chỉ sau khi Claude Code sửa C2-N1 (cân lại lần 2) — bắt đầu từ GRN-...-0009; sau đó: kiểm SoD khi ghi sổ, tồn NVL0561 = 180, đối chiếu 180-vs-200, trả hàng 5 hỏng (cần đường tạo phiếu trả — C2-N4).
- **C5 chạy lại:** chỉ sau khi Claude Code sửa C5-N1 — bắt đầu từ bước 3 (PO-...-0006 đang ĐÃ GỬI, chờ nhận).
- **C3 hoàn tất:** chỉ sau khi Duy quyết về PIN — nộp CNT-...-0005 (cả 8 PIN; lưu ý khả năng cần đếm lần 2 theo C3-N5) → GM xem chênh lệch (đếm 9 / sổ 10 / lệch −1) → duyệt điều chỉnh → tồn NVL0388 về 9 kg → đợt khóa → thử đếm lại trên đợt đã khóa (phải bị chặn).
