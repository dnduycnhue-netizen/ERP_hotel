# H4 — Đối chiếu nội dung bài hướng dẫn với hệ thống thật

- Ngày: 14/11/2026
- Nhánh: `feat/muse-help` (từ main `cf08c19`)
- Phương pháp: 3 tác vụ trình duyệt cloud, chỉ xem/mở màn hình và đọc. Không tạo/sửa/xóa chứng từ (ngoại trừ 2 phiếu nhận nháp trống do mở hộp thoại nhận hàng — xem "Tác dụng phụ"), không bấm Nộp/Khóa/Duyệt/Ghi sổ/Gửi/Khớp, không đổi cấu hình/quyền/tài khoản/PIN.
- Tài khoản: uat.storekeeper / uat.accountant / uat.gm / uat.chef / uat.purchaser / uat.front_desk / uat.hk_attendant / uat.owner / uat.chief_accountant + admin dnduy@hueic.edu.vn (TEST47).
- Kết quả: **Đạt một phần.** Đối chiếu xong SOP-01..05, luồng mua hàng 13 bước, luồng kiểm kê, luồng lĩnh kho, quy tắc duyệt, 8 bài vai trò. **10 lỗi nội dung đã sửa** (commit T-H04a..e, gate xanh từng commit). **5 lỗi giao diện cho Claude** (H4-N2..N6). **2 mục cần Duy/Claude xác nhận.** Một số bước ghi "chưa kiểm được" vì cần chạy thật hoặc không có mẫu dữ liệu (liệt kê cuối).

## 1. Lỗi nội dung đã sửa

| # | Bài / vị trí | Lỗi cũ | Sửa thành | Căn cứ | Commit |
|---|---|---|---|---|---|
| 1 | SOP-01 bước 2 + vai-tro-nhan-hang bước 2 | "nhập **cân cả bì** và **bì**; xác nhận đơn vị" | "nhập **Số cân** và **Bì**; hệ thống tự tính số thực nhận (Số cân − Bì)" | `vi.receiving.grossQty = "Số cân (gross)"`; không có thao tác "xác nhận đơn vị" | T-H04a, T-H04d |
| 2 | SOP-01 bước 4 | "theo bảng kiểm" (không điều kiện) | "theo bảng kiểm (nếu có cho nhóm hàng)" | Form đọc `qc_templates`; 2 nhóm hàng kiểm tra đều "Chưa có mẫu checklist cho nhóm hàng này" | T-H04a |
| 3 | SOP-01 bước 1 | Không nhắc 2 lựa chọn trên màn thật | Thêm "(có thể chọn **Nhận thẳng ra kho bếp**; mất mạng thì dùng **Xếp hàng gửi sau (offline)**)" | Màn mở phiếu nhận có cả 2 lựa chọn | T-H04a |
| 4 | SOP-02 bước 1, 6–8 + tóm tắt + controls + luong-kiem-ke-thang | GM "duyệt điều chỉnh" (bước 6) → hệ thống ghi bút toán (7) → "Khóa đợt" (8); controls "Hai người đếm độc lập" | Thứ tự thật: Kế toán **Khóa đợt** (nhập lý do từng dòng đỏ) → Quản lý **duyệt điều chỉnh** trên đợt đã khóa → hệ thống ghi bút toán, kho hết đóng băng. Controls: "Ít nhất một người đếm độc lập". Nút thật "Mở đợt kiểm kê". | Live CNT-0005: kế toán thấy nút "Khóa đợt" đang mở ở trạng thái CHỜ DUYỆT; quản lý thấy bảng chênh lệch nhưng KHÔNG có nút duyệt điều chỉnh. Code: `count_lock` yêu cầu 'submitted', `count_adjust_post` yêu cầu 'locked'. Ngưỡng độc lập: `count_open` bắt ≥ 1 độc lập | T-H04c |
| 5 | SOP-03 bước 4 + vai-tro-quan-ly + phan-he-kho | "Hủy giá trị lớn có thể cần thêm một người duyệt" / "từ 1.000.000 đ có thể thêm bước duyệt" | "Chỉ một bước duyệt (Quản lý); chưa có bước duyệt thứ hai cho phiếu giá trị lớn" (ngưỡng có trong Cài đặt nhưng chưa tạo bước duyệt) | /admin/approval-rules: waste chỉ 1 bước Quản lý, 0 đ trở lên, không ngưỡng, không bước 2. Setting `waste_approval_threshold_vnd` (mặc định 1.000.000) chỉ tồn tại trong Cài đặt, không có logic nào đọc | T-H04d |
| 6 | SOP-04 bước 2 | "sửa hoặc đối chiếu lại" | "trao đổi với NCC/thủ kho rồi bấm **Khớp 3 chiều** để đối chiếu lại. Hóa đơn Tạm giữ không sửa trực tiếp được." | Trang chi tiết hóa đơn không có nút Sửa; không có trang `/finance/invoices/[id]/edit` | T-H04e |
| 7 | SOP-04 bước 3 + luong-mua-hang bước 10 | "Quản lý: Duyệt hóa đơn" | "Quản lý hoặc Kế toán trưởng chuỗi: Duyệt hóa đơn" | `invoice_approve` yêu cầu quyền `invoice.approve` — sm_manager VÀ chief_accountant đều có; SoD người nhập không được duyệt (`SOD_INVOICE_CREATOR_APPROVER`) | T-H04e |
| 8 | SOP-04 bước 4 | "chọn hóa đơn và tài khoản NCC" | "chọn hóa đơn cần thanh toán (tài khoản nhận lấy theo tài khoản mặc định của NCC)" | Form "Tạo đề nghị mới" không có trường chọn tài khoản; tài khoản nhận hiện ở chi tiết đề nghị theo NCC | T-H04e |
| 9 | SOP-04 bước 5 + vai-tro-ke-toan (quy tắc 30 ngày) + luong-mua-hang bước 12 | (a) Bản gốc: "NCC vừa đổi tài khoản trong 30 ngày cần thêm duyệt Chủ đầu tư." (b) Bản sửa T-H04b của tau: chỉ giữ phần "người đổi không được tự duyệt" — **sai sót của tau: bỏ mất phần (a)** | Đầy đủ cả hai: "Mặc định 1 bước: **Kế toán trưởng chuỗi**; NCC vừa đổi tài khoản ngân hàng trong 30 ngày thì **thêm bước duyệt của Chủ đầu tư**. Người duyệt không được là người lập hóa đơn trong đề nghị hay người yêu cầu đổi tài khoản — hệ thống chặn tách biệt nhiệm vụ." | `payment_request_create` (migration 20261109340000): không rule thì mặc định 1 bước chief_accountant; `bank_changed_at` trong 30 ngày thì thêm bước owner. `payment_request_decide` (migration 20261109563000, Q242): chặn người duyệt là người nhập hóa đơn hoặc người yêu cầu đổi STK (`ERR_SOD_PAYMENT_APPROVER`). Đề nghị PAY-0001 thật: 1 bước, Kế toán trưởng chuỗi duyệt 12:54:58 14/11/2026 | T-H04b (sai sót), T-H04e (sửa lại cho đủ) |
| 10 | phan-he-bao-cao-canh-bao (modules.ts:190) | "12 báo cáo vận hành" | "11 báo cáo vận hành" | Danh sách trong chính bài đếm được 11; live 11 thẻ báo cáo (M7/V9) | T-H04b |
| 11 | quy-tac-dung-sai-can-lai (rules.ts:111) | "Dung sai nhận hàng (mặc định 5%) … có thể theo nhóm hàng" | "… một mức chung cho khách sạn (không theo nhóm hàng; mức theo nhóm chỉ áp dụng cho ngưỡng đếm lại khi kiểm kê)" | `receiving_tolerance_pct` là một setting duy nhất theo khách sạn; mức 1,5/3/5% theo nhóm là ngưỡng đếm lại kiểm kê | T-H04b |
| 12 | phan-he-nhan-hang (modules.ts:68) | "Bấm **Lập phiếu trả hàng NCC** (mở màn trên điện thoại)" | "(ở trang Trả hàng NCC trên máy tính)" | Nút nằm trên trang `/receiving/returns` desktop (Q276, đã verify R1) | T-H04b |

## 2. Kết luận đối chiếu từng SOP

### SOP-01 · Nhận hàng mù — ĐÚNG sau khi sửa lỗi #1–#3
- Bước 3 (không camera): bài ĐÚNG. Ô lý do chỉ hiện sau khi tích ô xác nhận (đã sửa câu chữ cho rõ).
- Bước 4 (lý do hàng hỏng): bài ĐÚNG. Ô lý do hiện ra sau khi nhập số hỏng.
- Bước 5 (lô/hạn dùng): bài ĐÚNG, có điều kiện ("Hàng theo lô") — trường lô/hạn chỉ hiện khi `line.track_lot`.
- Bước 6 (cân lại): đúng (đã verify C2/R1: cân lần 2 mở nút ghi sổ).
- Bước 7 (duyệt phần dư): đúng — form có mục duyệt vượt đơn kèm lý do, quyền `receiving.override_over_po` (thủ kho/GM/sm_manager); người nhận không thấy là đúng phân quyền.
- Bước 8 (ghi sổ + PIN): đúng (đã verify C1/X3).
- Nhận mù xác nhận lại: nhiệm vụ nhận không hiện số lượng/đơn giá.

### SOP-02 · Kiểm kê cuối tháng — ĐÚNG sau khi sửa lỗi #4
- Bước 2 (đóng băng): đúng — đã verify C3/R1 (nhập/xuất trên kho đang kiểm kê bị chặn với thông báo "Kho đang kiểm kê").
- Bước 3 (hàng cân): đúng theo code — form đếm có cân chai (`ml = (gram − bì) ÷ tỉ trọng`); chưa quan sát live vì không có đợt đang đếm có dòng.
- Bước 5 (nộp bằng PIN): đúng — đã verify X1 (nộp lần 2/lần 3 với PIN từng người đếm).
- Bước 7 (bút toán theo giá bình quân): đúng theo code — `count_adjust_post` dùng `moving_avg` (Q103 Duy chốt giữ moving_avg).
- Lưu ý: form mở đợt có 2 ghi chú mâu thuẫn nhau ("ít nhất 2 người đếm độc lập" ở đầu, "ít nhất một" ở cuối) — bài viết theo ghi chú cuối là đúng quy tắc thật; mâu thuẫn trong form là lỗi giao diện (X1-N2, đã báo). Kho mặc định khi mở form là "Kho chờ hủy (DISPOSAL)" — xem H4-N8.

### SOP-03 · Hủy hàng — ĐÚNG sau khi sửa lỗi #5
- Điều kiện "không có ngoại lệ không camera": đúng — quy tắc ảnh ghi rõ trong phần ngoại lệ: "**Hủy hàng** vẫn bắt buộc ảnh, không có ngoại lệ không camera."
- Bước 1–3: đúng (nút "Lập phiếu hủy hàng", form đủ trường, nút "Chụp ảnh", nút "Gửi duyệt").
- Bước 4 (duyệt/từ chối): chưa kiểm được nút Duyệt (phiếu đang nháp); phần giá trị lớn đã sửa theo lỗi #5.
- Bước 5–6: chưa kiểm được (cần phiếu được duyệt thật).

### SOP-04 · Thanh toán NCC — ĐÚNG sau khi sửa lỗi #6–#9
- Bước 1: đúng — form có đủ trường NCC/đơn mua/ký hiệu/số/ngày; gợi ý "Hãy chọn nhà cung cấp trước để thấy danh sách đơn mua" khớp bài.
- Bước 2: đúng một phần — nút "Khớp 3 chiều" có; hóa đơn Tạm giữ C25TAA/0000123 hiện đúng lý do lệch (SL vượt số đã nhận, lệch giá 0%, dung sai 1%).
- Bước 3: chưa kiểm được nút Duyệt (không có hóa đơn nào ở trạng thái "Đã khớp"/chờ duyệt trong dữ liệu).
- Bước 6: đúng về dữ liệu — PAY-0001 đã thanh toán, tham chiếu FT2611140001, công nợ An Phát về 0; nút "Đã thanh toán" chưa kiểm được (không có đề nghị nào đang "Đã duyệt").

### SOP-05 · Kiểm minibar trả phòng — ĐÚNG
- Bước 1: đúng — nút "Yêu cầu kiểm" có; loại kiểm gồm Trả phòng/Hằng ngày/Kiểm đột xuất (phạm vi bài đã ghi đủ).
- Bước 2–4: chưa kiểm được trong H4 (không còn phiếu đang chờ kiểm) — đã verify ở các vòng trước: M5 (nhập số thiếu, tiền tính đúng 140.000 đ), V5 (cảnh báo > 20 món), C5 (tích "Phòng không dùng món nào" sau Q273).
- Bước 5: đúng — "Cộng vào folio khách trên PMS" là thao tác thủ công ngoài app (chưa tích hợp PMS); bài viết đúng ở dạng hướng dẫn thủ công.
- Bước 6: đúng — nút "Đã thu" + ô "Số folio", đã verify X3 (MB-0001 thu 140.000 đ).
- Bước 7: đúng theo code — RPC `minibar_decide_waive` + cột `write_off_reason` tồn tại; nút duyệt của quản lý nằm trên cùng trang chi tiết (quyền `minibar.waive.approve`, chỉ GM thấy). Tài khoản lễ tân không thấy là đúng phân quyền.

### Luồng mua hàng 13 bước — ĐÚNG sau khi sửa lỗi #7, #9
- Bước 1–2: đúng (nút "Tạo yêu cầu mua", "Gửi duyệt"; lịch sử PR-0007: bước 1 Quản lý đã duyệt).
- Bước 3: chưa kiểm được nút tạo đơn từ yêu cầu (các yêu cầu đã duyệt đều đã chuyển hết); giá tự lấy đúng — dòng hiện nguồn "Giá trần"/"Giá tay".
- Bước 4: đúng — đơn nháp PO-0002 có nút "Gửi duyệt" (đang vô hiệu vì dòng giá tay chưa nhập đơn giá, kèm banner giải thích).
- Bước 5: đúng theo quy tắc (po 2 bước, bước 2 từ 100.000.000 đ, bước 1 Quản lý, bước 2 Chủ đầu tư — /admin/approval-rules). Chưa kiểm được bước 2 live (không có đơn ≥ 100 triệu).
- Bước 6: chưa kiểm được nút "Gửi cho nhà cung cấp" (không có đơn nào đang "Đã duyệt").
- Bước 7–8: đúng một phần — nhiệm vụ nhận không hiện số lượng (nhận mù); cân/ảnh/QC/PIN chưa kiểm được trong H4 (cần mở phiếu nhận — sẽ tạo chứng từ), đã verify ở C1/R1/X3.
- Bước 9, 11, 13: đúng (xem SOP-04). Bước 10, 12: đúng về quy tắc (xem lỗi #7, #9); nút chưa kiểm được do thiếu mẫu dữ liệu.
- Tên trạng thái thật khác bài ở vài chỗ (đơn mua: "ĐÃ GỬI"/"ĐÃ NHẬN"; yêu cầu: "ĐÃ CHUYỂN PO") — bài viết dùng dạng thường, không phải lỗi nội dung.

### Luồng lĩnh kho / điều chuyển / xuất mục đích — ĐÚNG
- Phiếu lĩnh do **Bếp / bộ phận** lập (quyền `requisition.create` thuộc sm_kitchen + sm_housekeeping; thủ kho không có — đúng thiết kế, thủ kho chỉ xuất). Trang Kho → Phiếu lĩnh của thủ kho không có nút lập là đúng phân quyền, không phải lỗi.
- Điều chuyển: đúng (nút + form khớp bài).
- Xuất mục đích: đúng — "Cost center" và "Khoản mục" đều bắt buộc. Nhãn "Cost center" chưa dịch sang tiếng Việt — xem H4-N6. Phiếu nháp PIS-0001 có cost center trống vì được tạo trước khi Q273 bắt buộc trường này — dữ liệu cũ, không phải lỗi.

### Quy tắc duyệt — ĐÚNG (sau khi sửa lỗi #5, #11)
- /admin/approval-rules (Toàn chuỗi, TEST47 không có quy tắc riêng): po 2 bước (bước 2 từ 100.000.000 đ, Chủ đầu tư), pr 1 bước Quản lý, requisition 1 bước Quản lý, waste 1 bước Quản lý. Không có quy tắc cho hóa đơn hay đề nghị thanh toán — đúng thiết kế (hóa đơn duyệt bằng quyền `invoice.approve`; đề nghị thanh toán mặc định 1 bước Kế toán trưởng chuỗi, xem lỗi #9).
- Tiêu đề đơn mua "Hợp đồng" là **kênh mua** (`po.channel = "contract"`), khác với nguồn giá của dòng ("Giá trần"/"Giá tay") — bài viết chuỗi nguồn giá không mâu thuẫn với màn hình.
- Trạng thái phiếu minibar "Chưa kiểm" tồn tại trong code (`vi.minibar.notChecked`) — bài đúng; H4 không thấy mẫu nào trong dữ liệu hiện tại.

### Bài vai trò — ĐÚNG phần lớn
- Chủ đầu tư: đúng phần lớn (khối "Sáng nay", Cảnh báo, Chờ tôi duyệt, Đề nghị thanh toán). Xem H4-N2 về việc chủ đầu tư thấy cả đơn đang ở bước Quản lý.
- Quản lý: đúng phần lớn (Chờ tôi duyệt, Hóa đơn, Tồn kho, Hủy hàng, Kiểm kê). Menu của GM thiếu "Nhận hàng" so với các tài khoản khác — đúng phân quyền (GM không có `receiving.perform`).
- Kế toán: đúng (Hóa đơn, Công nợ, Tạm ứng, Đề nghị thanh toán đủ cả). Trang "Chờ tôi duyệt" của kế toán ghi rõ "Bạn không có quyền duyệt chứng từ nào" — đúng.
- Thu mua & Thủ kho: đúng phần lớn (Tạo yêu cầu mua, Gửi duyệt, Đóng đơn). Nút tạo đơn từ yêu cầu và "Gửi cho nhà cung cấp" chưa kiểm được (thiếu mẫu dữ liệu).
- Lễ tân: đúng (Yêu cầu kiểm, Chờ thu tiền, Đã thu + số folio, Chuyển thu muộn, Đề nghị miễn). Xem H4-N3 về cảnh báo mâu thuẫn trên trang.
- Buồng phòng: đúng một phần — nút "+" theo số thiếu và ô "Phòng không dùng món nào" chưa kiểm được trong H4 (không còn phiếu chờ kiểm); đã verify ở M5/C5.
- Bếp & Nhà hàng: đúng (Bếp, Ghi bán, Buffet, Hủy hàng; trang Phiếu lĩnh của bếp CÓ nút "+ Lập phiếu lĩnh").

## 3. Lỗi giao diện cho Claude (không sửa trong vòng Help)

| Mã | Mức | Vấn đề | Bằng chứng |
|---|---|---|---|
| H4-N1 | P0 | **Bế tắc khóa đợt kiểm kê (X1-N1, đã báo)** — kế toán là người duy nhất có `count.lock` nhưng không có `count.view_variance` nên không thấy dòng đỏ/lý do để khóa; GM thấy chênh lệch nhưng không có nút duyệt điều chỉnh trên đợt CHỜ DUYỆT. Đợt CNT-0005 kẹt ở CHỜ DUYỆT, KHO-T047 vẫn đóng băng. | H4b + X1 (CNT-0005: NVL0388 đếm 9, sổ 10, −10%) |
| H4-N2 | P2 | Trang "Chờ tôi duyệt" hiện đơn PO-0004 (0 đ, đang ở bước Quản lý) cho cả Chủ đầu tư kèm nút Duyệt/Từ chối — trái thiết kế 2 bước (chủ đầu tư chỉ duyệt bước 2 từ 100 triệu). RPC sẽ chặn nếu bấm (`ERR_NOT_APPROVER`), nhưng nút không nên hiện. | H4c: owner + GM cùng thấy PO-0004 |
| H4-N3 | P3 | Trang Minibar — Lễ tân mâu thuẫn: cảnh báo "chưa giao phòng cho khách mới: 104" nhưng ngay dưới ghi "Hệ thống không chặn giao phòng mới (chưa tích hợp PMS)". | H4c: /frontdesk/minibar |
| H4-N4 | P3 | Menu trái của thu mua lúc mới đăng nhập thoáng hiện 17 mục giống chủ đầu tư (kể cả Quản trị hệ thống), chuyển trang mới còn 7 mục — menu không ổn định giữa các trang. | H4c |
| H4-N5 | P3 | Form nhập hóa đơn: lần chọn NCC đầu, 3 đơn mua hiện ra nhưng không chọn được ngay (phải chọn lại mới vào được). | H4c: /finance/invoices/new |
| H4-N6 | P3 | Nhãn "Cost center" trên form xuất mục đích chưa dịch sang tiếng Việt ("trung tâm chi phí") — vi phạm quy tắc chuỗi UI trong `vi.ts`. | H4b: /inventory/issues/new |
| H4-N7 | P2 | Form mở đợt kiểm kê tự mâu thuẫn: ghi chú đầu "ít nhất 2 người đếm độc lập", ghi chú cuối "ít nhất một người đếm độc lập" (đã báo ở X1-N2). | H4b: /inventory/counts/new |
| H4-N8 | P3 | Kho mặc định khi mở form "Mở đợt kiểm kê" là "Kho chờ hủy (DISPOSAL)" thay vì Kho chính. | H4b |

## 4. Cần Duy/Claude xác nhận

1. **Đường sửa hóa đơn Tạm giữ:** hóa đơn Tạm giữ không có nút sửa trực tiếp. Khi số lượng/đơn giá trên hóa đơn sai, quy trình đúng là gì — lập hóa đơn mới thay thế (hóa đơn cũ giữ nguyên Tạm giữ) hay có đường sửa khác? Bài hiện chỉ viết "bấm Khớp 3 chiều để đối chiếu lại".
2. **H4-N2 (chủ đầu tư thấy đơn bước 1):** đây là lỗi hiển thị cần sửa, hay thiết kế cho phép chủ đầu tư duyệt thay bước 1 trong trường hợp khẩn? (RPC hiện chặn bằng `ERR_NOT_APPROVER` nếu bấm.)
3. **X1-N1 (H4-N1):** hướng sửa do Claude quyết — đang chặn toàn bộ X2/X4 và đợt kiểm kê tháng 11.

## 5. Chưa kiểm được (cần chạy thật hoặc thiếu mẫu dữ liệu)

- Nút Duyệt hóa đơn trên hóa đơn đã khớp; nút "Đã thanh toán" + nhập tham chiếu ngân hàng; nút "Gửi cho nhà cung cấp"; nút tạo đơn mua từ yêu cầu đã duyệt.
- Kết quả bấm "Khớp 3 chiều"; việc hệ thống chặn tách biệt nhiệm vụ ở bước duyệt thanh toán (cần một trường hợp vi phạm thật).
- Các trường cân/ảnh/QC và nhập PIN khi ghi sổ phiếu nhận trong H4 (đã verify ở C1/R1/X3, không chạy lại).
- Nút "+" và "Phòng không dùng món nào" trên phiếu minibar đang chờ kiểm; các bước mở ca/lĩnh bù/đếm/đóng ca xe đẩy (đã verify ở M5/C5/V5, không chạy lại).
- Bước 2 từ 100 triệu của đơn mua (không có đơn ≥ 100 triệu trong dữ liệu).

## 6. Tác dụng phụ

- Tác vụ H4a mở hộp thoại nhận hàng đã tạo 2 phiếu nhận nháp trống GRN-TEST47-LE-2611-0014 (PO-0005) và 0015 (PO-0001) — cùng hành vi đã biết ở X3-N2 ("mở phiếu nhận luôn tạo nháp"). Không ảnh hưởng dữ liệu khác; có thể xóa khi dọn dữ liệu test.
- Không thay đổi nào khác trên hệ thống.

## 7. Commit trong vòng H4

- `9e88fab` T-H04a — SOP-01 (Số cân, bảng kiểm có điều kiện, nhận thẳng/offline)
- `e32994a` T-H04b — quy tắc ngân hàng 30 ngày (bản sửa thiếu — xem lỗi #9), dung sai, 11 báo cáo, nút trả hàng
- `e903ee1` T-H04c — SOP-02 + luồng kiểm kê (khóa trước, duyệt sau)
- `5f59344` T-H04d — ngưỡng hủy lớn, bài Người nhận hàng
- `4af7d3f` T-H04e — SOP-04 + luồng mua hàng (sửa lại lỗi #9 cho đủ)
- Báo cáo này: commit riêng `T-H04:` (sau H4c).
