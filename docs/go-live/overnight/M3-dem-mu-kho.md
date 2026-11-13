# M3 — Thử nghiệm Đếm mù kho (CHƯA HOÀN THÀNH — chặn ở bước mở đợt)

- Ngày: 14/11/2026, 02:40–02:46 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.storekeeper, uat.gm (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Chưa hoàn thành — trang tạo đợt kiểm kê lỗi máy chủ xác định (10/10 lần thử, cả desktop + mobile, cả thủ kho + GM). Không mở được đợt mới nên toàn bộ các bước đếm mù, nộp đợt, duyệt chênh lệch, khóa đợt và trường hợp biên đều chưa thực hiện được. Không có dữ liệu nào bị tạo/sửa/xóa trong bài này.**
- Commit: `T-M3-blocked` (xem git log).

## 1. Bước 1 — Mở đợt kiểm kê mới: KHÔNG ĐẠT (lỗi chặn toàn bộ luồng)

- Thủ kho, desktop …/inventory/counts → nút "Mở đợt kiểm kê" → trang …/inventory/counts/new chỉ hiển thị: "Không thể tải trang" — "Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên." + nút "Thử lại". Bấm "Thử lại", tải lại trang, bấm lại nút mở đợt, truy cập trực tiếp URL — đều ra cùng lỗi (5 lần với thủ kho).
- Thủ kho, mobile …/m/…/count → nút "Mở đợt kiểm kê" → trang …/count/new hiển thị lỗi máy chủ tiếng Anh: "This page couldn't load" — "A server error occurred. Reload to try again." — "ERROR 2594239425". Bấm "Reload" vẫn ra cùng lỗi với cùng mã lỗi.
- GM thử lại cả hai đường: desktop …/counts/new lỗi "Không thể tải trang" (2 lần, lần 2 sau khi chờ 2 phút); mobile …/count/new lỗi máy chủ "ERROR 2594239425" (1 lần).
- Mã lỗi mobile giống hệt nhau ở cả hai tài khoản và mọi lần tải lại → lỗi phía máy chủ mang tính xác định, không phải lỗi nhất thời hay do quyền của riêng thủ kho. Không ghi được mã/số đợt, ngày, kho hay trạng thái đợt mới. Câu hỏi về loại đợt (thường/theo ca, file POS) chưa tới được vì trang chọn kho/loại đợt không tải lên.

## 2. Các bước còn lại — chưa thực hiện được

- **Bước 2 (đếm mù NVL0388 2 kg, NVL0561 3 cái):** chưa thực hiện được (không có đợt mới để đếm). **Kết luận về đếm mù: CHƯA THỂ KẾT LUẬN** — màn hình đếm chưa từng mở được nên chưa kiểm tra được màn đếm có hiện tồn lý thuyết hay không. Trên các màn đã xem được (danh sách đợt, chi tiết đợt cũ, màn Tồn kho) không thấy con số tồn lý thuyết/gợi ý nào, nhưng đó không phải màn hình đếm. Giới hạn: trình duyệt tự động không mở được DevTools nên phần kiểm tra rò rỉ dữ liệu qua network chưa làm được.
- **Bước 3 (nộp đợt), Bước 4 (duyệt chênh lệch GM), Bước 5 (tồn kho sau duyệt), Bước 6 (khóa đợt / đếm thêm sau khóa):** chưa thực hiện được (không có đợt mới).
- **Trường hợp biên a (đếm 0), b (đếm âm −1), c (đếm trùng):** chưa thực hiện được — cả ba đều cần một đợt đang đếm.
- Tồn đầu kỳ ghi nhận được: màn Tồn kho (cả thủ kho và GM) đều "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại." + "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng." → tồn kho TEST47 = 0, đúng như tình trạng đã biết. Không có bút toán điều chỉnh nào được tạo. Không có mã PIN nào được dùng hay hỏi (chưa tới bước nào yêu cầu PIN).

## 3. Phát hiện bổ sung

- **B1. [Mới — khác tình trạng đã biết] Trên TEST47 đã có sẵn 2 đợt kiểm kê từ 13/11/2026:** CNT-TEST47-LE-2611-0001 và CNT-TEST47-LE-2611-0002, đều loại "Kiểm kê xe đẩy", kho "Xe đẩy 1 (Demo)", trạng thái "CHỜ DUYỆT", cả hai đều "Đã đếm 0/0 dòng" / "Đợt này chưa có dòng đếm nào." Hai đợt này không thuộc bài kiểm thử nên không duyệt, không hủy, không đếm thêm vào chúng. (Trước đây ghi "Chưa có đợt kiểm kê nào" — đó là trạng thái trước khi 2 đợt này xuất hiện; cần cập nhật lại ghi nhận: 2 đợt xe đẩy tồn tại từ 13/11.)
- **B2. [Quyền — cần xác minh lại] Cả thủ kho lẫn GM khi mở chi tiết đợt 0002 đều thấy:** "Bạn chưa được cấp quyền xem chênh lệch — chỉ người có quyền mới xem được biên bản." và không thấy bảng chênh lệch hay nút duyệt nào. Đáng chú ý là **GM cũng bị chặn xem chênh lệch** trên đợt này — cần xác minh lại quyền xem/duyệt chênh lệch của GM khi đã khắc phục được lỗi mở đợt (có thể do đợt có 0 dòng đếm, hoặc do quyền thật sự thiếu).
- **B3.** Hai mặt hàng cần đếm đã xác minh là có trong danh mục TEST47 (672 mặt hàng): NVL0388 "ba chỉ nách", nhóm "Thịt & Cá", ĐVT lưu kho "kg", "Đang dùng"; NVL0561 "Bánh bèo", nhóm "Thực phẩm tươi sống & khô", ĐVT lưu kho "cai", "Đang dùng". Kho "Kho chính T047 (KHO-T047)" có trong bộ lọc kho của màn Tồn kho (0 tồn kho).
- **B4.** Trang "Nạp file POS của ca" ghi: "có file POS của ca thì mới mở được kiểm kê theo ca. File chỉ dùng để đối chiếu, không ghi tồn kho hay tiền." Trang này không hiển thị danh sách file POS đã nạp nên chưa xác nhận được TEST47 có file POS nào hay không (phù hợp M8: import POS chưa hoàn tất).
- Quan sát thêm (không bấm): trên trang mobile chi tiết đợt cũ có xuất hiện ô "Khóa đợt kiểm kê".

## 4. Chẩn đoán code (đọc code, chưa sửa — chuyển Claude Code)

- Cả 2 trang tạo đợt (desktop `src/app/(app)/[property]/inventory/counts/new/page.tsx` và mobile `src/app/m/[p]/count/new/page.tsx`) đều gọi chung `listWarehouses(propertyId)` rồi render `<CountOpenForm>` chung. Form đếm chỉ gọi `listCountersAction` ở client (useEffect) nên không gây lỗi server.
- `listWarehouses` (`src/features/master/queries.ts:288`) dùng embed đã sửa theo Q235 (`outlet:outlets!warehouses_outlet_id_fkey(name)`) và tự nuốt lỗi (trả `[]` khi query lỗi) — nên lỗi server xác định này KHÔNG giải thích được bằng embed hay lỗi query thông thường; cần log máy chủ (Vercel) với mã lỗi mobile `ERROR 2594239425` để xác định câu lệnh nào nổ.
- Các trang khác cùng khách sạn (danh sách kiểm kê, chi tiết đợt, Tồn kho, Danh mục, Nạp file POS) vẫn tải bình thường → lỗi khu trú ở trang tạo đợt.
- **Để tiếp tục M3:** khắc phục lỗi tải trang mở đợt rồi làm lại từ Bước 1; đồng thời kiểm tra lại quyền xem/duyệt chênh lệch của GM (B2). Không đếm nhờ vào 2 đợt xe đẩy có sẵn (sẽ làm thay đổi dữ liệu đợt của người khác).

## 5. Lệnh đã chạy

```text
Trình duyệt cloud: 2 tài khoản uat.* (storekeeper → gm), 02:40–02:46 14/11/2026 (10 lần thử, failed)
Đọc code: counts/new + count/new page.tsx, listWarehouses (master/queries.ts:288), CountOpenForm
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
