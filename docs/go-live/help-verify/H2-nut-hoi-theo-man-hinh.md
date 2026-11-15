# H2 — Nút "?" trợ giúp theo ngữ cảnh (14/11/2026)

- Khách sạn: TEST47. Nhánh: `feat/muse-help` (từ main `cf08c19`, gồm Q279 + Q280 + Q281).
- Báo cáo này không ghi mật khẩu/PIN.
- Task trình duyệt cloud: chạy 16:33–16:39 (6 phút), đủ 12 màn desktop (owner) + 4/5 màn mobile (receiver, hk_attendant); màn mobile Nhà hàng kiểm bổ sung bằng tài khoản bếp (16:41–16:42, 1 phút). Bổ sung: đối chiếu danh sách gợi ý với `HELP_SECTION_SLUGS` trong `src/features/help/lib.ts` và `helpSectionForPath` trong `src/features/help/context.ts`.

## Kết luận: ĐẠT MỘT PHẦN

| Hạng mục | Kết quả |
|---|---|
| 12 màn desktop: có nút "?" | Đạt 12/12 |
| 12 màn desktop: có khối "Gợi ý cho màn hình bạn vừa xem" | Đạt 12/12 |
| Gợi ý đúng chủ đề (desktop) | Đạt 9/12 màn; 3 màn có bài lệch/thiếu (H2-N1, H2-N2, H2-N3) |
| 5 màn mobile: có nút "?" + gợi ý đúng dạng `/m/.../help?ctx=...` | Đạt 5/5 (màn Nhà hàng cần tài khoản có quyền nhà hàng — xem H2-N4) |

## Bảng 12 màn desktop (tài khoản owner)

| # | Màn | ctx | Gợi ý (đúng tiêu đề) | Nhận xét |
|---|---|---|---|---|
| 1 | /procurement/po (Đơn mua) | procurement | Thu mua; Mua hàng → Nhận hàng → Hóa đơn → Thanh toán; Mua chợ và tạm ứng; SOP-07 Duyệt chứng từ; Giá đơn mua: tự động, giá trần, giá tay | Đúng chủ đề |
| 2 | /procurement/approvals (Chờ tôi duyệt) | procurement | 5 bài y hệt màn 1 | Đúng chủ đề chung, nhưng không phân biệt với màn Đơn mua; thiếu bài "Duyệt nhiều bước và hạn mức" (H2-N3) |
| 3 | /inventory/waste (Phiếu hủy hàng) | waste | SOP-03 Hủy hàng; Lĩnh kho, điều chuyển, xuất mục đích, hủy hàng; Ảnh bằng chứng và ngoại lệ không camera | Đúng hết |
| 4 | /inventory/counts (Đợt kiểm kê) | count | SOP-02 Kiểm kê kho cuối tháng; Kiểm kê tháng; Kiểm kê; Nhận hàng mù và đếm mù | Đúng hết (3 bài đầu trùng lặp nội dung kiểm kê) |
| 5 | /inventory/locks (Khóa ngày/kỳ) | locks | SOP-08 Khóa ngày và khóa kỳ; Ngày nghiệp vụ và khóa sổ | Đúng hết, chính xác |
| 6 | /inventory/stock (Tồn kho) | inventory | Kho; Lĩnh kho, điều chuyển, xuất mục đích, hủy hàng; Sổ cái bất biến và đảo bút toán; Giá vốn và định giá tồn kho | Đúng chủ đề kho chung; ctx dùng chung "inventory", không có bài riêng về xem tồn kho |
| 7 | /finance/invoices (Hóa đơn NCC) | finance | Tài chính; SOP-04 Thanh toán nhà cung cấp; Đối chiếu 3 bên; Kế toán | Đúng hết |
| 8 | /restaurant/dishes (Món ăn & công thức) | restaurant | Nhà hàng; Bán hàng nhà hàng và nguyên liệu; Bếp & Nhà hàng; Giá vốn và định giá tồn kho | Đúng chủ đề chung; thiếu bài riêng về món/công thức (chỉ nhắc trong mô tả bài "Nhà hàng") |
| 9 | /frontdesk/minibar (Minibar — Lễ tân) | minibar | Buồng phòng & Minibar; Minibar: từ bổ sung đến thu tiền; SOP-05 Kiểm minibar khi trả phòng; Minibar: tính tiền, miễn và đối soát | Đúng hết, chính xác |
| 10 | /housekeeping/trolleys (Ca xe đẩy) | trolley | SOP-06 Ca xe đẩy buồng phòng; Buồng phòng; Buồng phòng & Minibar | Đúng hết |
| 11 | /reports (Báo cáo) | reports | Báo cáo & Cảnh báo; Ngày nghiệp vụ và khóa sổ | Bài 1 đúng; bài 2 lệch chủ đề (H2-N2) |
| 12 | /master/items (Danh mục vật tư) | master | Danh mục; Giá đơn mua: tự động, giá trần, giá tay; Phân quyền theo quyền, không theo tên vai trò | Bài 1 đúng; 2 bài sau sai/lệch (H2-N1, đã sửa 1 bài) |

## Bảng 5 màn mobile

| # | Màn | Tài khoản | ctx | Gợi ý | Nhận xét |
|---|---|---|---|---|---|
| M1 | /m/.../receive (Nhận hàng) | receiver | receiving | SOP-01 Nhận hàng mù; Người nhận hàng; Nhận hàng; Dung sai và cân lại khi nhận hàng; Ảnh bằng chứng và ngoại lệ không camera | Đúng hết |
| M2 | /m/.../count (Kiểm kê) | receiver | count | 4 bài giống hệt màn desktop Kiểm kê | Đúng hết |
| M3 | /m/.../minibar (Kiểm minibar) | hk_attendant | minibar | 4 bài giống hệt màn desktop Minibar | Đúng hết |
| M4 | /m/.../trolley (Ca xe đẩy) | hk_attendant | trolley | 3 bài giống hệt màn desktop Ca xe đẩy | Đúng hết |
| M5 | /m/.../restaurant (Nhà hàng) | hk_attendant → 404; bếp → mở được | restaurant | Nhà hàng; Bán hàng nhà hàng và nguyên liệu; Bếp & Nhà hàng; Giá vốn và định giá tồn kho | 3 bài đúng trực tiếp; bài Giá vốn chỉ liên quan gián tiếp (H2-N4) |

## Lỗi / bất thường

1. **H2-N1 [P2 — gợi ý sai chủ đề, ĐÃ SỬA 1 PHẦN] Màn Danh mục vật tư gợi ý 2 bài sai chủ đề.** `HELP_SECTION_SLUGS.master` cũ: `phan-he-danh-muc`, `quy-tac-gia-tran-gia-tay`, `quy-tac-phan-quyen-theo-quyen`. Bài "Phân quyền theo quyền, không theo tên vai trò" thuộc Quản trị hệ thống, không liên quan vật tư. Đã sửa: bỏ bài này khỏi mục master (commit `e530b16`, test help-content xanh). Bài "Giá đơn mua: tự động, giá trần, giá tay" được GIỮ LẠI có chủ đích: giá trần là dữ liệu danh mục (bài Danh mục có nhắc giá trần) — nếu Duy/Claude thấy vẫn lệch thì bỏ nốt, mục master còn 1 gợi ý.
2. **H2-N2 [P3 — gợi ý lệch] Màn Báo cáo gợi ý bài "Ngày nghiệp vụ và khóa sổ".** `HELP_SECTION_SLUGS.reports` = `phan-he-bao-cao-canh-bao`, `quy-tac-khoa-so-ngay-nghiep-vu`. Bài khóa sổ chỉ liên quan gián tiếp (báo cáo theo ngày cần kỳ đã khóa); danh sách chỉ có 2 gợi ý, thiếu bài hiển nhiên về cách đọc/xuất báo cáo, bản tin 8h/cảnh báo. Chưa sửa (mức liên quan là quyết định nội dung — chuyển Claude Code).
3. **H2-N3 [P3 — gợi ý không phân biệt] Màn Chờ tôi duyệt gợi ý giống hệt màn Đơn mua.** `helpSectionForPath` map cả `/procurement/po` và `/procurement/approvals` về cùng mục `procurement`. Thiếu bài "Duyệt nhiều bước và hạn mức" (`quy-tac-duyet-nhieu-buoc`) dù bài này có trong danh mục. Hướng sửa (chuyển Claude Code): tách mục `approvals` riêng, hoặc thêm bài duyệt nhiều bước vào mục procurement (lúc đó thành 6 gợi ý, vượt khung 2–5 bài của handoff — cần quyết).
4. **H2-N4 [Không phải lỗi — đã xác nhận] Màn mobile Nhà hàng 404 với tài khoản buồng phòng.** Trang hub mobile `/m/[p]/restaurant/page.tsx` ghi rõ: "không có quyền nhà hàng nào → 404"; nav mobile cũng không có Nhà hàng. Tài khoản hk_attendant không có quyền nhà hàng nên 404 là đúng thiết kế. Kiểm lại bằng tài khoản bếp (uat.chef): mở được, hub hiện 4 mục (Bếp/Bán hàng/Buffet/Đặt tiệc), nút "?" ở góc phải header, URL `/m/.../help?ctx=restaurant` đúng, khối gợi ý 4 bài (3 đúng trực tiếp, bài "Giá vốn và định giá tồn kho" chỉ liên quan gián tiếp qua giá vốn nguyên liệu).
5. **H2-N5 [Quan sát, chưa xác nhận] Màn /procurement/approvals không thấy nút chuông.** Agent báo thanh trên cùng của màn này chỉ có "?" và avatar, khác các màn desktop khác. Chuông trong `app-topbar.tsx` chỉ hiện khi `canViewAlerts` đúng — điều kiện này chung cho mọi màn trong cùng shell nên chưa đủ căn cứ kết luận lỗi (có thể agent nhìn sót). Ghi nhận để kiểm lại, không tính là lỗi.

## Ghi chú khác

- Sau mỗi lần bấm "?", bấm nút quay lại của trình duyệt để về màn trước rồi mở màn tiếp theo — điều hướng hoạt động bình thường.
- Nút "?" desktop nằm ở thanh trên cùng, ngay cạnh nút chuông; nút "?" mobile nằm ở góc phải header, có tên truy cập "Hướng dẫn cho màn hình này".
- Màn Tồn kho dùng chung ctx "inventory" (không có mục riêng cho xem tồn kho); màn Món ăn thiếu bài riêng về món/công thức — ghi nhận cho H5 (bài thiếu).
