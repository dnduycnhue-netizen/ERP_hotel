# Câu hỏi còn mở

| # | Câu hỏi | Ảnh hưởng | Trạng thái |
|---|---|---|---|
| Q1 | Chủ đầu tư chốt kênh nhận cảnh báo (Zalo/email/app) và ngưỡng báo trong đêm (`08-REPORTS-ALERTS.md` mục 3) | T-045 | Chờ khách |
| Q2 | Khách sạn có Zalo OA chưa? Có sẵn sàng đăng ký template ZNS (tốn phí theo tin)? | T-045 | Chờ khách |
| Q3 | Mẫu file báo cáo bán hàng theo món xuất từ POS hiện tại (có cột void, comp không?) | P2 AvT | Chờ khách |
| Q4 | Mẫu báo cáo ngày xuất từ PMS (phòng bán, khách, ăn sáng) | T-036 (nếu dùng file thay form) | Chờ khách |
| Q5 | Kế toán dùng MISA SME (cài máy) hay MISA AMIS (online)? Mẫu import kế toán đang dùng | T-043, P3 | Chờ khách |
| Q6 | Mỗi pháp nhân áp dụng TT99 hay TT133? Hệ thống đã hỗ trợ cả 2 phương pháp giá vốn `moving_avg` và `fifo`. | T-011 | Đã hỗ trợ cả 2 phương pháp |
| Q7 | Danh sách hợp đồng dịch vụ đang chạy (đơn vị, chu kỳ, giá) | T-042 | Chờ khách |
| Q8 | Ma trận duyệt theo giá trị PO thực tế của chuỗi (mặc định đang ở `05-BUSINESS-RULES.md` mục 2) | T-020 | Chờ khách |
| Q9 | Bảng giá minibar hiện hành theo từng KS; chuẩn minibar mỗi loại phòng | T-035 | Chờ khách |
| Q10 | Mỗi khách sạn có bao nhiêu tầng/xe đẩy; ca làm việc buồng phòng | T-034 | Chờ khách |
| Q11 | Khi dùng bình quân tức thời, tính lại giá bình quân từ giá trị tồn sau trả/đảo theo giá gốc, chặn giá trị tồn âm. Đã thực thi trong `_post_move`. | T-011, T-026 | Đã thực thi |
| Q12 | Phương pháp FIFO đã thực thi: xuất lớp nhập cũ nhất theo thứ tự ghi sổ; chặn ghi lùi ngày và trả/đảo phần lớp nhập đã xuất. Đã kiểm thử 54/54 ca. | T-011, T-026 | Đã thực thi |
| Q13 | Đặc tả `09-API-RPC.md` yêu cầu `item_merge` "chuyển mọi tham chiếu nháp sang mã đích", nhưng ở T-015 chưa có bảng nào tham chiếu nháp tới vật tư (PO/nhận hàng là T-020 trở đi). T-015 chỉ chuyển tồn kho; tham chiếu nháp (khi có) giữ nguyên mã tạm đã gộp. Cần chốt: phạm vi chuyển tham chiếu nháp hoãn sang T-020 hay định nghĩa cơ chế chung ngay từ bây giờ? | T-015, T-020 | **Đã xử lý một phần trong T-020 (09/11/2026): trigger trên `items` tự chuyển dòng PR/PO ĐANG NHÁP sang mã đích khi mã tạm bị gộp; dòng của chứng từ đã submit trở đi không đổi. Còn mở cho các chứng từ khác (phiếu lĩnh T-030, nhận hàng T-023...).** Chờ khách chốt phạm vi chung. |
| Q14 | Dòng `item_merge` trong `09-API-RPC.md` bị cụt giữa câu: "Không gộp nếu mã nguồn đã có `stock_moves` khác pháp nhân… (xem rule)" — không tìm thấy rule được viện dẫn trong docs. T-015 hiện xử lý ngầm: mỗi kho chuyển tồn bằng đúng property của kho đó, `_post_move` chặn sai pháp nhân/khách sạn bằng `ERR_INVALID_VALUE` (không có kiểm tra riêng với mã lỗi rõ nghĩa). Cần chốt quy tắc đích: chặn toàn bộ lệnh gộp khi có bất kỳ `stock_moves` nào thuộc pháp nhân khác, hay cho gộp từng kho? | T-015 | Chờ khách |
| Q15 | `doc_type` của bảng `attachments` (T-016) hiện là text tự do (`receiving`, `count`, `waste`, `minibar`...). Cần chốt tập giá trị chuẩn + bảng tham chiếu, hay giữ text tự do và để từng task nghiệp vụ (T-023 nhận hàng, T-032 kiểm kê) tự quy ước? | T-016, T-023 | Chờ khách |
| Q16 | Ảnh chứng từ (bucket `evidence`) không được sửa/xóa (trigger T-016) và object mồ côi (upload xong nhưng chưa đăng ký `attachments`) không có cơ chế dọn. Cần chốt chính sách lưu trữ: giữ vĩnh viễn, hay dọn object mồ côi sau N ngày bằng cron (ai duyệt, có nhật ký không)? | T-016 | Chờ khách |
| Q17 | `has_perm` không có đặc cách owner/sys_admin: quyền mới của T-013/T-014/T-015 (`supplier.view`, `price.view`, `item.import`, `alert.receive.temp_item_stale`...) đều KHÔNG tự về vai trò `owner` trên production (owner vẫn 109 quyền từ lúc setup tay 09/11). T-016 đã gắn `owner` cho 3 quyền mới của nó. Cần chốt: bổ sung các quyền T-013/014/015 còn thiếu cho `owner` bằng 1 migration sửa riêng hay cấp tay 1 câu SQL? | T-013, T-014, T-015, T-016 | **Đã kiểm chứng SAI (09/11/2026): owner có đủ cả 9 quyền T-013/014/015 trên production, tổng vẫn 109 vì seed đã chứa sẵn các mã này. Không cần migration sửa. Chỉ 3 quyền mới thật sự của T-016 mới cần gán thêm (đã gán trong migration 200000).** |
| Q18 | RPC `pr_list`/`po_list`/`pr_get`/`po_get` chỉ trả `created_by` là uuid, không có tên người tạo — danh sách và chi tiết PR/PO (T-021) hiện không hiện tên người tạo, chỉ hiện ngày tạo. Có nên bổ sung join `profiles` để trả tên người tạo ở các RPC đọc thu mua, hay để UI tự tra cứu? | T-021 | Chờ khách |
