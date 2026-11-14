# V10 — Quét nhanh lỗi giao diện đã sửa (ĐẠT MỘT PHẦN — B-32/B-22 đạt; B-53 một phần; 390px đạt qua Playwright)

- Ngày: 14/11/2026, 11:19–11:27 (trình duyệt cloud) + kiểm tra 390px bằng Playwright trên VM (11:2x–11:3x). Khách sạn TEST47.
- Tài khoản trình duyệt: uat.storekeeper, uat.gm, uat.receiver, uat.owner (đăng nhập tay, xác nhận qua menu tài khoản). Chỉ mở xem + tìm kiếm + đổi tài khoản; không tạo/sửa/xóa dữ liệu, không bật/tắt module.
- Kết luận: **Đạt một phần — B-32 (không còn lỗi "Invalid UUID") và B-22 (đổi tài khoản không hiện menu cũ) đạt; B-20 không áp dụng (module đang bật, form hiện đúng); B-53 chỉ kiểm được một phần (tìm 1 từ không dấu được ở danh mục, nhưng tìm 2 từ trả 0 kết quả — lỗi mới N-1); bước 5 (390px) đạt qua Playwright 20/20 màn, gồm cả 5 màn mới.**
- Commit: `T-V10` (xem git log).

## 1. Bước 1 — Tìm kiếm không dấu (storekeeper, B-53): KHÔNG KIỂM ĐƯỢC DỨT ĐIỂM trên /inventory/stock

- Gõ "duong" (Tất cả kho) → "0 tồn kho" + "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại."; "ba chi" → cũng 0 kết quả; "duong" trong Kho chính T047 → cũng 0; "Đường" có dấu trong Kho chính T047 → cũng 0.
- Nguyên nhân gây nhiễu: tồn kho của TEST47 đang rỗng — mở /inventory/stock không lọc cũng cho "0 tồn kho" ở cả Tất cả kho và Kho chính T047, dù Danh mục vật tư có 672 mặt hàng.
- Đối chiếu tại /master/items (Danh mục vật tư): tìm "duong" → 1 kết quả nguyên văn: mã **AMN-DUONG**, tên **"Đường thẻ"**, nhóm "Ăn mặn", ĐVT kg, "Hiển thị 1–1 trên tổng 1 dòng" — tức **tìm không dấu 1 từ hoạt động ở danh mục**.
- Do đó không thể kết luận riêng lỗi dấu trên trang tồn kho khi tồn kho đang rỗng; cần dữ liệu tồn kho có hàng mới kiểm chứng dứt điểm B-53 trên /inventory/stock.

## 2. Bước 2 — Tìm kiếm không còn lỗi UUID (storekeeper, B-32): ĐẠT

- Gõ "xyz123" trên /inventory/stock rồi bấm tìm: **KHÔNG hiện lỗi "Invalid UUID"** hay bất kỳ thông báo lỗi nào. Kết quả hiện ra nguyên văn: "0 tồn kho" + "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại."

## 3. Bước 3 — POS import khi module tắt (owner, B-20): ĐẠT — hành vi đúng khi module đang BẬT, B-20 không áp dụng

- Mở /inventory/pos-import bằng tài khoản owner thấy form tải file, không có dòng "Module đang tắt": tiêu đề "Nạp file POS của ca", nội dung "Chọn file CSV hoặc Excel xuất từ POS (chỉ đọc sheet đầu tiên của file Excel). Mỗi ca (ngày + ca) trong file thành một lần nạp; có file POS của ca thì mới mở được kiểm kê theo ca. File chỉ dùng để đối chiếu, không ghi tồn kho hay tiền.", nút "Chọn file CSV hoặc Excel" và nút "Nạp file" đang tắt (chưa chọn file nên chưa nạp được).
- Mở /admin/modules theo UUID khách sạn thì báo "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn."; đường dẫn đúng là /admin/modules toàn cục, nhưng tài khoản owner bị chặn và không đọc trực tiếp được trạng thái module: tiêu đề "Bật/tắt module", thông báo "Không tải được danh sách module. Bạn chưa được cấp quyền admin.modules.manage để thực hiện thao tác này."
- Kết luận module Nhà hàng đang BẬT được suy ra từ form POS-import hiện ra và sidebar của owner có nhóm Nhà hàng (Nạp file POS, Kiểm kê theo ca NH…). Không bấm nút bật/tắt module nào.

## 4. Bước 4 — Đổi tài khoản không hiện menu cũ (B-22): ĐẠT

- Storekeeper (UAT Thủ kho) — menu sau khi tải xong: Tổng quan; Thu mua, Nhận hàng, Kho, Tài chính; Danh mục (mở rộng trên trang tồn kho: Thu mua gồm Đề nghị mua hàng, Đơn đặt hàng, Theo dõi đơn hàng; Nhận hàng gồm Nhập kho, Kiểm tra chất lượng, Trả hàng NCC; Kho gồm Tồn kho, Phiếu lĩnh, Phiếu nhập — Nhà hàng, Phiếu chuyển kho, Phiếu hủy, Phiếu nhập kho (hủy), Kiểm kê kho, Thẻ kho, Nạp file POS, Kiểm kê theo ca NH, Xuất — Nhà hàng, Đề nghị nhập — Nhà hàng; Tài chính gồm Công nợ & Thanh toán, Tạm ứng & hoàn ứng, Chi phí chung, Lịch sử thao tác).
- Đăng xuất → đăng nhập GM (UAT Tổng quản lý): **menu đổi ngay sang menu GM** — trên trang /inventory/stock menu GM gồm Thu mua, Kho, Tài chính, Nhà hàng; Minibar — Lễ tân, Số liệu PMS ngày, Minibar — Buồng phòng; Báo cáo, Cảnh báo; Danh mục (không còn mục Nhận hàng, có thêm ghi chú **"Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng"**), khác hẳn menu storekeeper.
- Đăng xuất → đăng nhập receiver (UAT Nhận hàng ca sáng): **menu đổi ngay sang menu receiver** ngay tại trang chủ — Tổng quan; Thu mua, Kho, Tài chính, Nhà hàng; Minibar — Lễ tân, Số liệu PMS ngày, Minibar — Buồng phòng; Báo cáo, Cảnh báo; Danh mục (không còn mục Nhận hàng). Không lần nào hiện menu của tài khoản trước sau khi đổi tài khoản.
- Lưu ý: sidebar lúc mới tải trang chỉ hiện "Tổng quan" + "Danh mục", vài giây sau mới hiện đủ nhóm theo vai trò (quan sát ở cả storekeeper, GM, receiver, owner) — cần chờ tải xong mới kết luận về menu (xem N-6).

## 5. Bước 5 — Màn 390px không tràn ngang: ĐẠT (kiểm bằng Playwright, không phải trình duyệt cloud)

- Trình duyệt cloud trong phiên này không đổi được kích thước cửa sổ và phím tắt thu phóng Ctrl+/Ctrl+ không có tác dụng. Theo chỉ đạo, bỏ qua bước 5 trong phiên trình duyệt — đã kiểm bằng Playwright trên VM (viewport 390×844, tài khoản owner, spec `tests/e2e/readonly/mobile-overflow.spec.ts`).
- **Kết quả: 20/20 màn không tràn ngang** (`documentElement.scrollWidth <= innerWidth` và `body.scrollWidth <= innerWidth`), gồm 14 màn cũ + **5 màn mới thêm cho V10: lập phiếu hủy hàng, lập phiếu lĩnh, lập phiếu điều chuyển, lập phiếu xuất mục đích, chi tiết phiếu lĩnh REQ-0002 — tất cả đều đạt**.
- Lưu ý: lần chạy đầu bằng tài khoản storekeeper đạt 19/20 — màn /admin/users rớt vì storekeeper không có quyền admin (trang không render `<main>`, không phải lỗi tràn ngang); chạy lại bằng owner thì 20/20. (Spec đã bổ sung 5 màn mới vào danh sách kiểm tra — xem commit.)
- Đã xác nhận trước ở cỡ desktop rằng cả 5 màn đều mở được bằng tài khoản storekeeper (chỉ xem, không bấm ghi/lưu).

## 6. Phát hiện mới

- **N-1. [Tìm kiếm — cần sửa] Tìm kiếm nhiều từ trả 0 kết quả dù mặt hàng tồn tại (Danh mục vật tư, storekeeper).** Tái hiện: /master/items?search=duong%20the → 0 dòng ("Chưa có vật tư nào phù hợp với bộ lọc.") trong khi "duong" → 1 dòng "Đường thẻ" (AMN-DUONG); /master/items?search=ba%20chi → 0 dòng, trong khi tìm "ba" → 16 dòng, gồm "ba chỉ nách" (NVL0388) và "BA CHỈ XÔNG KHÓI" (NVL0152). **Tìm 1 từ không dấu hoạt động, tìm 2 từ thì không.** (Trên /inventory/stock "ba chi" cũng 0 dòng, nhưng tồn kho đang rỗng nên chưa tách được nguyên nhân ở trang này.) Chuyển Claude Code (P1 — tìm kiếm phải tách từ và khớp từng từ sau khi bỏ dấu, thay vì khớp nguyên chuỗi).
- **N-2. [Ghi nhận] Tồn kho TEST47 đang rỗng:** /inventory/stock không lọc cho "0 tồn kho" ở cả Tất cả kho và Kho chính T047, dù danh mục có 672 vật tư. Điều này làm B-53 không kiểm chứng dứt điểm được trên trang tồn kho.
- **N-3. [Giao diện — nhỏ] /inventory/waste/new với tài khoản receiver hiện trang "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn." (404 chung, không có thông báo thiếu quyền),** trong khi cùng đường dẫn với tài khoản storekeeper mở được form "Lập phiếu hủy hàng". Tái hiện: đăng nhập receiver → mở /inventory/waste/new. Chuyển Claude Code (P2 — cùng họ với V7 N-4: trang chặn quyền riêng thay vì 404 chung).
- **N-4. [Giao diện — nhỏ] Mở chi tiết phiếu lĩnh bằng mã trong URL (/inventory/requisitions/REQ-TEST47-LE-2611-0002) báo lỗi "Không thể tải dữ liệu — Đã xảy ra lỗi. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên.";** đường dẫn đúng phải dùng UUID trong danh sách: /inventory/requisitions/d220983d-acf9-484f-9a6c-2c3aae12a930 — mở được chi tiết: phiếu REQ-TEST47-LE-2611-0002, trạng thái "ĐÃ DUYỆT", ngày 2026-11-14, bộ phận "Bếp (Demo)", kho xuất "Kho chính T047", kho nhập "Kho bếp (Demo)", ghi chú "Phiếu lĩnh kiểm thử V4", 1 dòng "ba chỉ nách", 2 kg, đã xuất 0, đã nhận 0. Chuyển Claude Code (P2 — URL dùng mã chứng từ nên chuyển hướng sang UUID hoặc báo lỗi rõ ràng hơn "không tìm thấy phiếu", thay vì lỗi tải chung).
- **N-5. [Ghi nhận]** Đường dẫn /admin/modules gắn sau UUID khách sạn không tồn tại (404); trang module đúng là /admin/modules toàn cục và tài khoản owner không có quyền admin.modules.manage nên không xem được trạng thái module trực tiếp. (Đường dẫn admin không theo UUID là hành vi đã biết từ M11.)
- **N-6. [Giao diện — nhỏ] Sidebar tải chậm:** lúc mới vào trang chỉ hiện "Tổng quan" + "Danh mục", vài giây sau mới hiện đủ nhóm theo vai trò (cả 4 tài khoản) — dễ gây hiểu lầm menu bị thiếu hoặc menu cũ khi kiểm tra vội. Chuyển Claude Code (P3 — hiện skeleton/loading rõ ràng cho sidebar trong lúc tải quyền).
- **N-7. [Chưa chắc chắn — cần kiểm lại] Nút "Tìm kiếm" trên trang Danh mục vật tư:** quan sát thấy gõ "duong" rồi bấm "Tìm kiếm" nhưng danh sách vẫn "Hiển thị 1–20 trên tổng 672 dòng", không lọc; việc tìm chỉ có tác dụng khi dùng tham số URL ?search=. Chuyển Claude Code (P2 — kiểm tra lại nút Tìm kiếm có kích hoạt lọc không, hay chỉ là quan sát chậm).

## 7. Kết quả xác minh các lỗi cũ trong V10

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q272 B-53 | Tìm "duong" ra "Đường" (tìm không dấu) | **Đạt một phần** — 1 từ không dấu hoạt động ở danh mục; trang tồn kho chưa kiểm được dứt điểm (tồn rỗng); tìm 2 từ trả 0 (N-1) |
| Q271 B-32 | Tìm ở /inventory/stock không còn "Invalid UUID" | **Đạt** |
| Q271 B-20 | /inventory/pos-import hiện "Module đang tắt" khi module tắt | **Không kiểm được** — module đang bật (không được bật/tắt); hành vi khi bật là đúng |
| Q271 B-22 | Đổi tài khoản không hiện menu cũ | **Đạt** |
| — | 390px không tràn ngang trên màn mới | **Đạt** — Playwright 20/20 (14 màn cũ + 5 màn mới) |

## 8. Lệnh đã chạy

```text
Trình duyệt cloud: 4 tài khoản uat.* (storekeeper → gm → receiver → owner), 11:19–11:27 14/11/2026
Playwright (VM, proxy-forwarder 127.0.0.1:18080, Chrome for Testing):
  npx playwright test --project=readonly-mobile tests/e2e/readonly/mobile-overflow.spec.ts
  - storekeeper: 19/20 (rớt /admin/users — không có quyền admin, không phải tràn ngang)
  - owner: 20/20 PASSED (54.8s)
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
