# H3 — Bản mobile của trang Hướng dẫn (14/11/2026)

- Khách sạn: TEST47. Nhánh: `feat/muse-help` (từ main `cf08c19`, gồm Q279 + Q280 + Q281).
- Báo cáo này không ghi mật khẩu/PIN.
- Task trình duyệt cloud: chạy 16:44–16:51 (7 phút), 2 tài khoản (receiver, hk_attendant). Bổ sung: kiểm khổ 390 px bằng Playwright (4 trang mobile help), đối chiếu nav dưới với `src/components/mobile/mobile-bottom-nav.tsx` và quyền vai trò receiver.

## Kết luận: ĐẠT MỘT PHẦN

| Hạng mục | Kết quả |
|---|---|
| Trang `/m/.../help` tải được (receiver, hk_attendant) | Đạt |
| Tìm kiếm không dấu | Đạt ("nhan hang mu" → 7 kết quả, bài đúng lên đầu) |
| "Dành cho bạn" đúng theo vai trò | Đạt (receiver 9 bài, hk_attendant 7 bài — khớp đúng với quyền thật) |
| Mở 4 bài (SOP-01, Kiểm kê tháng, SOP-05, Buồng phòng) | Đạt — tiêu đề, nội dung đọc được |
| Nút quay lại | Đạt — về đúng danh sách, ô tìm kiếm giữ từ khóa |
| KHÔNG có nút "Mở màn hình" (theo thiết kế) | Đạt — 0 nút ở cả 4 bài (agent quét toàn trang + Playwright xác nhận) |
| Khổ 390 px | Đạt — không tràn ngang (Playwright, 4 trang: `/help`, SOP-01, SOP-05, Buồng phòng; `scrollWidth == 390`) |
| Menu điều hướng dưới cùng | KHÔNG ĐẠT với receiver (không có nav nào — H3-N1); hk_attendant có 2 mục (đúng theo quyền) |

## Chi tiết theo tài khoản

### uat.receiver@erp.internal

- Trang `/m/.../help` tải được. Header "Hướng dẫn" / "Khách sạn test T047"; ô tìm kiếm "Tìm hướng dẫn (ví dụ: nhận hàng, kiểm kê, hóa đơn...)"; 6 nút lọc (Tất cả + 5 tab loại).
- "Dành cho bạn" 9 bài: Người nhận hàng; Danh mục; Nhận hàng; Mua hàng → Nhận hàng → Hóa đơn → Thanh toán; SOP-01 · Nhận hàng mù; Tách biệt nhiệm vụ (SoD); Nhận hàng mù và đếm mù; Dung sai và cân lại khi nhận hàng; Ảnh bằng chứng và ngoại lệ không camera. Không có nhãn: Chủ đầu tư, Quản lý, Kế toán, Thu mua & Thủ kho, Bếp & Nhà hàng, Buồng phòng, Lễ tân, Thu mua, Kho, Tài chính, Kiểm kê, Nhà hàng, Buồng phòng & Minibar, Báo cáo & Cảnh báo, Quản trị hệ thống, Kiểm kê tháng, SOP-02..08 và các quy tắc còn lại. (Khớp đúng với 5 quyền của vai trò receiver: `receiving.perform`, `receiving.post`, `item.view`, `attachment.upload`, `attachment.view`.)
- Tìm "nhan hang mu": 7 kết quả, bài lên đầu "Người nhận hàng" (Dành cho bạn); còn lại: Danh mục, Nhận hàng, SOP-01, Lĩnh kho…, Kiểm kê tháng, Giá vốn và định giá tồn kho.
- Bài SOP-01: tiêu đề đúng, nội dung đọc được (8 bước, Kiểm soát và bằng chứng, Lỗi thường gặp, Bài liên quan). Nút "Quay lại" bấm về đúng danh sách, ô tìm kiếm giữ từ khóa. Không có nút "Mở màn hình". Bài mở thêm "Kiểm kê tháng": tương tự, không có nút "Mở màn hình".
- Menu dưới cùng: KHÔNG CÓ (đã tải lại 2 lần) — xem H3-N1.

### uat.hk_attendant@erp.internal

- Trang `/m/.../help` tải được, header/ô tìm kiếm/6 nút lọc như trên.
- "Dành cho bạn" 7 bài: Buồng phòng; Danh mục; Buồng phòng & Minibar; Minibar: từ bổ sung đến thu tiền; SOP-05 · Kiểm minibar khi trả phòng; SOP-06 · Ca xe đẩy buồng phòng; Nhận hàng mù và đếm mù. (Khớp đúng tính toán từ seed ở H1.)
- Bài SOP-05: tiêu đề đúng, nội dung đọc được, nút "Quay lại" về đúng danh sách, không có nút "Mở màn hình".
- Bài "Buồng phòng": tiêu đề đúng, nội dung đọc được (Kiểm minibar, Xe đẩy, Lỗi thường gặp), nút "Quay lại" về đúng danh sách, không có nút "Mở màn hình".
- Menu dưới cùng: hiển thị bình thường, cố định ở đáy, có icon + nhãn, hiện cả trang danh sách và trang bài — chỉ có 2 mục: Buồng phòng và Minibar (đúng theo quyền: `hk.trolley.operate`, `minibar.check`).

## Lỗi / bất thường

1. **H3-N1 [P2] Tài khoản Receiver không có thanh điều hướng dưới cùng trên mobile.** Nguyên nhân đã kiểm chứng từ code: `MobileBottomNav` (`src/components/mobile/mobile-bottom-nav.tsx`) chỉ hiện mục khi user có quyền tương ứng — mục Nhận hàng chốt bằng `receiving.view`; nếu không có mục nào thì trả `null` (không hiện nav). Vai trò receiver cũ chỉ có 5 quyền (`receiving.perform`, `receiving.post`, `item.view`, `attachment.upload`, `attachment.view`) — **không có `receiving.view`** — trong khi các màn nhận hàng mobile chốt bằng `receiving.perform`. Kết quả: người nhận hàng — người dùng mobile chính — không có nav nào cả (không chỉ trên trang help mà trên mọi màn mobile). Đây là lệch quyền giữa nav và màn (nav đòi `receiving.view`, màn đòi `receiving.perform`), không phải lỗi của trang help. Hướng sửa (chuyển Claude Code): chốt mục Nhận hàng của nav bằng `receiving.perform` HOẶC `receiving.view`. (Nav của bếp hiện 3 mục Nhận hàng/Kiểm kê/Nhà hàng và của buồng phòng hiện 2 mục là đúng theo quyền của họ — không phải lỗi.)
2. **H3-N2 [P3] Đường dẫn `/m/<p>/` trần trả 404.** Không có `page.tsx` trong `src/app/m/[p]/` (chỉ có count/help/layout/minibar/receive/restaurant/trolley) nên mở `/m/b0000000-.../` với tài khoản receiver trả "Không tìm thấy trang". Hướng sửa (chuyển Claude Code): chuyển hướng `/m/<p>/` tới mục đầu tiên user có quyền (hoặc tới `/m/<p>/help`).
3. **H3-N3 [P2 — cùng họ với H1-N3] Sơ đồ luồng bị cắt ở cạnh phải trên trang bài mobile.** SOP-01 (nút cuối "Duyệt p..." bị cắt nửa), Kiểm kê tháng phần 1 (nút "Đếm..." và nhãn "Kì..." bị cắt), SOP-05 (nút "Phiếu h.../Ch..." bị cắt), Buồng phòng (sơ đồ minibar, nút "Phiếu h.../b.../Ch..." bị cắt). Khung sơ đồ có thanh cuộn ngang nên vẫn xem được khi cuộn — mức nhẹ hơn bản desktop (H1-N3: sơ đồ minibar tràn hẳn ra ngoài khung nhìn). Cùng gốc: sơ đồ rộng hơn khung chứa.
4. **H3-N4 [Quan sát, chưa xác nhận] Lần bấm đầu tiên vào thẻ bài chỉ tô viền, bấm lần 2 bài mới mở** (gặp ở cả 4 bài); nút "Quay lại" cũng chuyển trang sau một nhịp; 2 lần bấm "Quay lại" gặp lỗi trình duyệt thoáng qua, bấm lại thì được. Nhiều khả năng là artifact của trình duyệt cloud (bấm lần đầu chỉ focus), chưa xác nhận là lỗi app — ghi nhận, không tính là lỗi.

## Ghi chú khác

- Agent đếm trang danh sách mobile là "tổng 44 bài" trong khi desktop là 45 bài. Code cho thấy mobile và desktop dùng chung `visibleArticles(modules)` + `toListItems` nên cùng 45 bài — chênh lệch 1 bài nhiều khả năng là đếm sót, không tính là lỗi.
- Tiêu đề bài trên mobile là `<h2>` (h1 "Hướng dẫn" là tiêu đề của shell mobile); nút quay lại là nút icon (mũi tên, `aria-label` "Quay lại") trong `MobileHeader`, không phải nút chữ — agent đã bấm và xác nhận hoạt động.
