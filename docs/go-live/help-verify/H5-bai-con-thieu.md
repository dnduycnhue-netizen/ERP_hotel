# H5 — Bài còn thiếu (đề xuất, tối đa 10)

- Ngày: 14/11/2026
- Nhánh: `feat/muse-help`
- Phương pháp: đối chiếu 45 bài hiện có (`src/i18n/help/*.ts`) với tính năng thật trên app + các khoảng trống phát hiện ở H1–H4. **Chỉ đề xuất — không viết bài mới** (theo brief H5).
- Quy ước: mỗi đề xuất ghi loại bài, đối tượng, nội dung cần có, bằng chứng thiếu (số lần nhắc trong bài hiện có), mức ưu tiên.

## 1. SOP — Ủy quyền duyệt khi vắng mặt (ưu tiên: cao)

- Loại đề xuất: SOP mới (hoặc mục trong `sop-duyet-chung-tu`).
- Đối tượng: Quản lý, Chủ đầu tư, Kế toán trưởng.
- Nội dung cần có: vào đâu để ủy quyền (`/admin/approval-rules` → mục "Ủy quyền duyệt"), chọn người nhận ủy quyền + thời hạn, chứng từ nào được ủy quyền, hết hạn thì sao, nhật ký ủy quyền xem ở đâu.
- Bằng chứng thiếu: từ "ủy quyền" xuất hiện **0 lần** trong toàn bộ 45 bài. H4c xác nhận mục "Ủy quyền duyệt" tồn tại trên trang Quy tắc duyệt (hiện "Chưa có ủy quyền nào") — tính năng có, hướng dẫn không.
- Vì sao cần: người duyệt nghỉ phép là trường hợp thường gặp; không có hướng dẫn thì chứng từ kẹt chờ duyệt.

## 2. SOP — Đổi mật khẩu và đổi PIN của chính mình (ưu tiên: cao)

- Loại đề xuất: SOP mới (ngắn).
- Đối tượng: mọi người dùng.
- Nội dung cần có: đổi mật khẩu ở đâu (`/settings/password`), đổi PIN ở đâu, quên mật khẩu/PIN thì làm gì (ai đặt lại được), quy tắc mật khẩu tối thiểu 12 ký tự (Q132), PIN dùng ở những bước nào (ghi sổ nhận hàng, nộp đợt kiểm kê).
- Bằng chứng thiếu: "mật khẩu" xuất hiện **1 lần** (một dòng trong bảng Quản trị: admin đặt lại mật khẩu và PIN cho người khác). Không có hướng dẫn nào cho người dùng tự đổi.
- Vì sao cần: thao tác cơ bản nhất của mọi tài khoản; hiện người dùng phải hỏi admin.

## 3. SOP — Nạp file POS (ưu tiên: cao)

- Loại đề xuất: SOP mới.
- Đối tượng: Thủ kho / Kế toán / Bếp.
- Nội dung cần có: lấy file từ máy POS như thế nào, định dạng file đúng (CSV theo file POS thật — Q251 lưu ý file mẫu khác file thật), nạp ở đâu (tab "Nạp file POS" trong Kho), lỗi thường gặp khi nạp, nạp xong kiểm tra ở đâu, liên hệ với kiểm kê theo ca ra sao.
- Bằng chứng thiếu: chỉ **1 dòng** trong bảng phân hệ Nhà hàng ("Nạp file bán hàng của ca để làm kiểm kê theo ca") + 1 nút trong sơ đồ. Không có bước nào.
- Vì sao cần: Q251 đã ghi rõ file POS thật khác file giả lập — không có hướng dẫn thì người nạp dễ dùng sai mẫu.

## 4. SOP — Quản lý nhà cung cấp và đổi tài khoản ngân hàng (ưu tiên: cao)

- Loại đề xuất: SOP mới (hoặc mục trong `phan-he-thu-mua`).
- Đối tượng: Thu mua, Kế toán, Quản lý.
- Nội dung cần có: tạo/sửa NCC ở đâu, đổi tài khoản ngân hàng NCC như thế nào, **hậu quả của việc đổi**: đề nghị thanh toán cho NCC đó có thêm bước duyệt Chủ đầu tư + người vừa đổi không được tự duyệt (quy tắc 30 ngày, đã sửa ở T-H04e), xem lịch sử đổi tài khoản ở đâu.
- Bằng chứng thiếu: "tài khoản ngân hàng" xuất hiện **5 lần**, toàn bộ chỉ nói về quy tắc chặn — không có bước thao tác nào.
- Vì sao cần: thao tác đổi STK là thao tác nhạy cảm nhất về tiền; hiện bài chỉ nói hậu quả mà không nói cách làm.

## 5. Quy tắc — Làm việc khi mất mạng (ưu tiên: trung bình)

- Loại đề xuất: bài quy tắc mới (gom các câu rải rác hiện có).
- Đối tượng: Người nhận hàng, Buồng phòng, mọi người dùng mobile.
- Nội dung cần có: chứng từ nào xếp hàng được khi mất mạng (nhận hàng, kiểm minibar, kiểm kê), cái nào không (ghi sổ? — cần xác nhận), dấu hiệu "đang chờ đồng bộ" ở đâu, gửi lại có bị ghi trùng không, mất mạng lâu thì xử lý thế nào, dữ liệu nào chỉ có khi có mạng (giá, số sổ).
- Bằng chứng thiếu: "mất mạng"/"offline" xuất hiện **5 lần**, rải ở 3 bài khác nhau (vai trò Người nhận hàng, vai trò Buồng phòng, SOP-01) — mỗi nơi một câu, không có bài tổng hợp.
- Vì sao cần: kho và nhà hàng thường xuyên mất mạng; người dùng cần một nơi tra cứu duy nhất thay vì nhớ từng câu lẻ.

## 6. SOP — Cấp bù minibar cho phòng (ưu tiên: trung bình)

- Loại đề xuất: SOP mới (ngắn) hoặc bổ sung vào `sop-kiem-minibar-tra-phong`.
- Đối tượng: Thủ kho, Buồng phòng, Lễ tân.
- Nội dung cần có: khi nào cần cấp bù (báo lỗi "Không đủ tồn kho để xuất" khi bấm Đã thu), cấp bù ở đâu (phiếu điều chuyển sang kho phòng hay nút cấp bù riêng), cấp bù từng phòng hay cả tầng (R2-N2: hiện chưa cấp bù riêng một phòng được — cần ghi rõ giới hạn này), kiểm tra tồn kho phòng sau khi cấp bù.
- Bằng chứng thiếu: "cấp bù" xuất hiện **2 lần**, cả hai đều là câu xử lý lỗi ("báo thủ kho cấp bù… rồi thử lại") — không có bước thao tác nào.
- Vì sao cần: lỗi "Không đủ tồn kho để xuất" đã gặp thật ở X3; người dùng hiện không biết cấp bù bằng cách nào.

## 7. Quy tắc — Giá vốn món ăn (foodcost) tính như thế nào (ưu tiên: trung bình)

- Loại đề xuất: bài quy tắc mới (hoặc mục trong `phan-he-nha-hang`).
- Đối tượng: Bếp, Kế toán, Quản lý.
- Nội dung cần có: foodcost tính từ công thức + giá trần/giá vốn ra sao, vì sao món hiện "Chưa tính được (thiếu giá trần)", sửa bằng cách nào (nhập giá trần cho nguyên liệu), lãi gộp trong Bán hàng vì sao bằng 0 khi thiếu foodcost.
- Bằng chứng thiếu: "foodcost" xuất hiện **0 lần** trong 45 bài. H4c ghi nhận nhiều món hiển thị "Chưa tính được (thiếu giá trần)" và báo cáo bán hàng ghi "lãi gộp chưa đủ" — người dùng không có chỗ nào để tra cứu ý nghĩa.
- Vì sao cần: bếp và kế toán đang thấy số 0/chưa tính được mà không biết sửa ở đâu.

## 8. SOP — Nhập danh mục bằng Excel (ưu tiên: trung bình)

- Loại đề xuất: SOP mới (ngắn).
- Đối tượng: Thủ kho, Thu mua, Quản lý.
- Nội dung cần có: tải file mẫu ở đâu, điền cột nào bắt buộc (vật tư, nhà cung cấp), nhập ở đâu, đọc báo lỗi theo dòng/cột như thế nào, sửa file rồi nhập lại, lưu ý danh mục dùng chung cả chuỗi nên chỉ nhập khi chắc chắn.
- Bằng chứng thiếu: hiện chỉ có **1 đoạn** trong `phan-he-danh-muc` ("Màn Nhập danh mục đọc file Excel mẫu… báo lỗi theo dòng/cột; sửa file rồi nhập lại") — đúng hướng nhưng chưa đủ thành SOP từng bước.
- Vì sao cần: nhập Excel sai là lỗi thường gặp (T-014); một SOP ngắn sẽ giảm số lần hỏi lại.

## 9. Quy tắc — Hợp đồng khung và báo giá (ưu tiên: thấp)

- Loại đề xuất: bài quy tắc mới (hoặc mục trong `phan-he-thu-mua`).
- Đối tượng: Thu mua, Quản lý.
- Nội dung cần có: tạo hợp đồng khung ở đâu, nhập báo giá NCC ở đâu, thứ tự ưu tiên giá (hợp đồng khung → báo giá → giá trần → giá tay), hợp đồng hết hạn thì giá lấy từ đâu, ai được sửa hợp đồng.
- Bằng chứng thiếu: "hợp đồng khung" xuất hiện **4 lần**, toàn bộ trong bài quy tắc giá (`quy-tac-gia-tran-gia-tay`) — chỉ nói thứ tự ưu tiên, không nói cách tạo/quản lý.
- Vì sao cần: H4c ghi nhận người dùng không phân biệt được "Hợp đồng" trên tiêu đề đơn (kênh mua) với "Giá trần" trên dòng hàng (nguồn giá) — một bài riêng sẽ gỡ rối này.

## 10. SOP — Bảng kê không hóa đơn (ưu tiên: thấp)

- Loại đề xuất: SOP mới (ngắn).
- Đối tượng: Kế toán.
- Nội dung cần có: khi nào dùng bảng kê không hóa đơn thay vì hóa đơn NCC, lập ở đâu (tab "Bảng kê không hóa đơn" trong Tài chính), bảng kê có ghi công nợ không, có qua duyệt không, xuất file cho kế toán như thế nào.
- Bằng chứng thiếu: "bảng kê không hóa đơn" xuất hiện **0 lần** trong 45 bài, dù tab này tồn tại trên trang Tài chính (H4c xác nhận).
- Vì sao cần: tính năng có trên màn hình nhưng không có trong Trợ giúp — người dùng mới sẽ không biết dùng khi nào.

## Ghi chú

- Các chủ đề đã xem xét nhưng KHÔNG đề xuất vì đã có bài đủ dùng: tạm ứng (luồng `luong-mua-cho-va-tam-ung` đã có), khóa ngày/kỳ (`sop-khoa-ngay-ky` đã có), ca xe đẩy (`sop-ca-xe-day` đã có), thẻ kho (đã có trong `phan-he-kho`), công thức món ăn (đã có trong `phan-he-nha-hang`), xuất Excel (đã có trong `phan-he-bao-cao-canh-bao`).
- Thứ tự ưu tiên đề nghị viết trước: 1 (ủy quyền) → 2 (mật khẩu/PIN) → 3 (nạp file POS) → 4 (quản lý NCC) → 5–8 → 9–10.
