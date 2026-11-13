# Báo cáo tổng — Đợt kiểm thử qua đêm (M1–M18)

- Đợt kiểm thử: đêm 13/11 → rạng sáng 14/11/2026 (trình duyệt cloud 22:41 13/11 → 02:53 14/11).
- Khách sạn: TEST47 (Khách sạn test T047). Tài khoản: uat.* (owner/gm/accountant/purchaser/chef/hk_supervisor/hk_attendant/front_desk/receiver/storekeeper).
- Nhánh: `feat/muse-overnight` (từ main 4e307d1), 19 commit, head `fc57466`. Cây làm việc sạch.
- Kết luận chung: **15/18 bài Đạt (M4–M7, M9–M18); 3 bài chưa hoàn thành (M8, M2, M3).** Đã sửa 4 lỗi UI thật trong nhánh (M12/M13/M14/M15). Phát hiện thêm ~30 lỗi/bất thường chưa sửa — toàn bộ liệt kê ở mục 2, ưu tiên chuyển Claude Code ở mục 3. **Chu trình mua → nhận → trả tiền vẫn CHƯA chạy thông được đầu cuối** vì 2 điểm chặn đã biết (chụp ảnh bắt buộc, nút "Gửi duyệt" dùng hộp thoại xác nhận) + 1 điểm chặn mới (trang tạo đợt kiểm kê lỗi máy chủ).

## 1. Bảng trạng thái M1–M18

| Bài | Kết quả | Thời gian | Commit | Báo cáo |
|---|---|---|---|---|
| M1 — Chu trình mua→nhận→trả (thử lại) | Đạt một phần | 02:33–02:38 14/11 | `6cee5b7` | `docs/go-live/overnight/M1-chu-trinh-mua-nhan-tra.md` |
| M2 — Chu trình chênh lệch | Chưa hoàn thành (bản rút gọn) | 02:48–02:53 14/11 | `fc57466` | `docs/go-live/overnight/M2-chu-trinh-chenh-lech.md` |
| M3 — Đếm mù kho | Chưa hoàn thành (chặn bước 1) | 02:40–02:46 14/11 | `feeb4c8` | `docs/go-live/overnight/M3-dem-mu-kho.md` |
| M4 — Nhà hàng | Đạt (10 phát hiện) | 23:42–23:52 13/11 | `3e231c1` | `docs/go-live/overnight/M4-nha-hang.md` |
| M5 — Buồng phòng/minibar | Đạt (9 phát hiện) | 23:54 13/11–00:02 14/11 | `712161c` | `docs/go-live/overnight/M5-buong-phong-minibar.md` |
| M6 — Tồn kho | Đạt (5 phát hiện) | 00:04–00:10 14/11 | `99ca0e9` | `docs/go-live/overnight/M6-ton-kho.md` |
| M7 — Báo cáo/Excel | Đạt (11 phát hiện) | 00:12–00:19 14/11 | `a342722` | `docs/go-live/overnight/M7-bao-cao-excel.md` |
| M8 — Danh mục & import | Chưa hoàn thành (timeout) | 00:20–02:31 14/11 | `0427fe2` | `docs/go-live/overnight/M8-danh-muc-import.md` |
| M9 — Ma trận quyền | Đạt | 22:41–23:04 13/11 | `21f7eba` | `docs/go-live/overnight/M9-ma-tran-quyen.md` |
| M10 — Module-off guard | Đạt | đêm 13/11 | `123ab2e` | `docs/go-live/overnight/M10-module-guard.md` |
| M11 — Playwright | Đạt (31/34) | đêm 13/11 | `3adf660` | `docs/go-live/overnight/M11-playwright.md` |
| M12 — Vitest schema | Đạt | đêm 13/11 | `c7c5d61` | `docs/go-live/overnight/M12-vitest-schema.md` |
| M13 — Chuỗi cứng i18n | Đạt | đêm 13/11 | `48be2d7` + `6f22580` | `docs/go-live/overnight/M13-chuoi-cung-i18n.md`, `M13-glossary.md` |
| M14 — Trạng thái màn hình | Đạt | đêm 13/11 | `fba162b` | `docs/go-live/overnight/M14-trang-thai-man-hinh.md` |
| M15 — A11y/mobile | Đạt | đêm 13/11 | `e07e27a` | `docs/go-live/overnight/M15-a11y-mobile.md` |
| M16 — Bảo mật client | Đạt (sạch) | đêm 13/11 | `dea1ddb` | `docs/go-live/overnight/M16-bao-mat-client.md` |
| M17 — Hướng dẫn vai trò | Đạt | đêm 13/11 | `dcdeba6` | `docs/go-live/user-guide-*.md` (7 file) |
| M18 — Cập nhật tài liệu | Đạt | đêm 13/11 | `36acc45` | (sửa `demo-walkthrough.md`, `uat-guide.md`, `checklist.md`) |

Ghi chú về M1: (a) form hóa đơn **ĐÃ SỬA** (mở được); (b) lưu nháp PO chợ **CHƯA SỬA** (vẫn mất sửa, nay im lặng không báo lỗi); ô Tổng ước tính 500.000 **ĐÃ SỬA** (nhận + lưu được). Nhận hàng mù vẫn giữ ở cả 3 màn; kẹt chụp ảnh.

## 2. Danh sách lỗi / bất thường

Mức độ: **Chặn** (không làm được luồng) · **Sai số liệu** (số hiển thị sai) · **Bảo mật** (lộ/thiếu kiểm soát) · **Giao diện** (hiển thị/UX).

### 2.1. Đã sửa trong nhánh này (UI — đã có commit)

| # | Mô tả | Lớp | Commit |
|---|---|---|---|
| F-1 | Mã lỗi `ERR_SOD_COUNT_INDEPENDENT` thiếu trong `src/i18n/errors.vi.ts` (migration 542000 đổi tên) → rơi về câu SoD chung | Giao diện | `c7c5d61` |
| F-2 | Segment `/m` và `/admin` không có loading/error boundary | Giao diện | `fba162b` |
| F-3 | 6 placeholder hard-code (payment-request-detail, item-form-dialog ×2, dish-form ×2, admin/audit) | Giao diện | `48be2d7` + `6f22580` |
| F-4 | 5 nút `size="sm"` (28px) trong `mobile-count-line-form.tsx` → min-h-11/min-w-11 | Giao diện | `e07e27a` |

### 2.2. Chưa sửa — chặn luồng (ưu tiên cao nhất)

| # | Mô tả | Lớp | Tái hiện |
|---|---|---|---|
| B-1 | **Trang tạo đợt kiểm kê lỗi máy chủ xác định** — desktop "Không thể tải trang", mobile "ERROR 2594239425"; 10/10 lần, cả thủ kho + GM. Cần log Vercel với mã lỗi để xác định câu lệnh nào nổ (code: `counts/new` + `count/new` đều gọi `listWarehouses`; embed đã sửa theo Q235 nên không giải thích được bằng embed). | Chặn | M3: …/inventory/counts/new và …/m/…/count/new |
| B-2 | **Lưu nháp PO chợ mất sửa trong im lặng** — bấm "Lưu nháp" không báo lỗi, quay về trang chi tiết, tải lại thì sửa mất (mô tả + lý do vượt trần). Triệu chứng đổi từ báo lỗi (13/11) sang im lặng (14/11) — tệ hơn về UX. | Chặn | M1: PO-...-0004 → "Sửa nháp" → sửa → "Lưu nháp" → tải lại |
| B-3 | **Thu tiền minibar bị chặn "Không đủ tồn kho để xuất."** — phiếu MB-...-0001 (phòng 101) đã kiểm, "Chờ thu tiền" 140.000 đ, không thu được tiền. | Chặn | M5: /frontdesk/minibar → phòng 101 → nhập folio TEST-M5-1311 → "Đã thu" |
| B-4 | **Không có nút tạo phiếu lĩnh / điều chuyển / hủy hàng với bất kỳ vai trò nào** (kể cả owner, GM) — các luồng 2–4 của M6 không chạy được. | Chặn | M6/M7: /inventory/requisitions, /inventory/transfers, /inventory/waste |
| B-5 | **Xuất Excel hỏng toàn diện** — 3/5 export có nút bị chặn `ERR_EXPORT_NOT_LOCKED` (kể cả khoảng ngày trống Jan 2026), 2/5 lỗi HTTP 500; 6/11 báo cáo chi tiết không có nút xuất. Chưa xuất được file nào → chưa kiểm tra được cột/dấu/định dạng Excel. | Chặn | M7: /reports → các báo cáo chi tiết |
| B-6 | **Mở lại PO đã có phiếu nhận nháp thì sinh thêm nháp mới** — GRN-...-0006 tạo trong M1 (đã có 0001–0005). | Giao diện | M1/M9: mở thẻ PO-0003 trên /m/…/receive |

### 2.3. Chưa sửa — sai số liệu / không nhất quán

| # | Mô tả | Lớp | Tái hiện |
|---|---|---|---|
| B-7 | Lãi gộp không nhất quán: trang bán hàng tổng GP = 145.000 đ (món thiếu giá vốn tính chi phí 0) vs báo cáo F&B tổng GP = 0 đ (món thiếu foodcost bị loại) — cùng kỳ, cùng 1 dòng bán. | Sai số liệu | M4: /restaurant/sales vs /reports/fnb-revenue |
| B-8 | Báo cáo Minibar lệch nhau: Ghi nhận 140.000 đ, Chờ thu 140.000 đ, Chênh lệch đối soát 140.000 đ, nhưng Doanh thu 0 đ, Giá vốn 0 đ, Lãi gộp 0 đ, Đã thu 0 đ; 5 món đều SL bán 0 / doanh thu 0 đ. (Có thể cùng gốc với B-3.) | Sai số liệu | M7: /reports/minibar |
| B-9 | Chi tiết phiếu lĩnh REQ-...-0001: cột "SL tồn kho" bằng đúng số lượng yêu cầu trên cả 7 dòng, trong khi màn Tồn kho báo 0 khắp nơi. | Sai số liệu | M6: REQ-...-0001 |
| B-10 | Cảnh báo đỏ trùng lặp: 9 cảnh báo `PERMISSION_CRITICAL_CHANGED` ngày 12-11 (7 lúc 21:11, 2 lúc 21:19, nội dung giống nhau); trạng thái gửi mâu thuẫn ("Đã gửi 08:00 13-11" nhưng "Lịch sử gửi: Chưa có tin nào được gửi."). | Sai số liệu | M7: /alerts |
| B-11 | Số liệu PO trong M9 đợt 2 ghi sai (PO-0004: 450.000 đ, PO-0003: 800.000 đ, PO-0002: 600.000 đ) — đã đối chiếu lại trong M1: PO-0004 0 đ (ước tính 500.001 đ), PO-0003 1.000.000 đ ĐÃ GỬI, PO-0002 1.040.000 đ NHÁP, PO-0001 1.040.000 đ ĐÃ GỬI. **Không phải lỗi app — lỗi ghi nhận của đợt M9, đã sửa.** | — | M1 §4.1 |

### 2.4. Chưa sửa — quyền / bảo mật

| # | Mô tả | Lớp | Tái hiện |
|---|---|---|---|
| B-12 | GM bị chặn xem chênh lệch kiểm kê ("Bạn chưa được cấp quyền xem chênh lệch — chỉ người có quyền mới xem được biên bản.") — cả trên đợt xe đẩy 0002 (0 dòng đếm). | Bảo mật | M3: chi tiết CNT-...-0002 (GM) |
| B-13 | GM bị chặn toàn bộ /inventory/transfers ("Bạn chưa được cấp quyền…", không có mục "Điều chuyển" trong menu Kho của GM) trong khi owner xem được. | Bảo mật | M7: /inventory/transfers (GM) |
| B-14 | Thủ kho + Thu mua bị chặn /inventory/waste. | Bảo mật | M6: /inventory/waste |
| B-15 | Thủ kho không mở được trang chi tiết PO ("Không tìm thấy trang…"). | Bảo mật | M2: PO-...-0001 (storekeeper) |
| B-16 | Chủ đầu tư không xem được audit trace: đường dẫn trong phạm vi khách sạn → 404; đường dẫn toàn cục /admin/audit → chặn quyền ("Bạn chưa được cấp quyền quản trị…"). Cùng gốc với M-04 "NO audit-log detail screen". | Bảo mật | M1 §4.5 |
| B-17 | Menu ↔ route lệch: GM menu "Nhận hàng" → /receiving 404; menu Kế toán thiếu "Nhận hàng" nhưng /receiving mở được; Kế toán menu "Nhà hàng" → /restaurant 404; HK menu "Kho" → /inventory/stock bị chặn. | Giao diện | M9 F.3 |
| B-18 | Danh sách phiếu nhận: mã phiếu liên kết tới trang chi tiết PO thay vì chi tiết phiếu nhận → thủ kho không có đường xem phiếu nhận nháp từ desktop. | Giao diện | M2: /inventory/receipts |
| B-19 | Trang chi tiết PO không có mục đối chiếu 3 chiều (không phải "có mục nhưng trống") — cần xác định đối chiếu nằm ở màn khác hay chưa xây. | Giao diện | M2: PO-...-0001 |
| B-20 | /inventory/pos-import tải form upload ngay cả khi module restaurant tắt (inventory/layout.tsx không kiểm tra module + trang dùng `has_perm` thô); ghi sẽ rớt ở trigger DB. | Bảo mật | M10 F-1 |
| B-21 | Trigger `_module_guard` thiếu 5 bảng: `recipes`, `recipe_versions`, `recipe_lines`, `banquet_dishes`, `buffet_session_dishes` — ghi trực tiếp vẫn lọt khi restaurant tắt (comment migration "RPC ghi nào cũng bị chặn" là sai với 5 bảng này). DELETE cũng không bị chặn (trigger chỉ INSERT/UPDATE). | Bảo mật | M10 F-2/F-3 |
| B-22 | Menu sau khi đổi tài khoản còn hiển thị menu của tài khoản trước cho tới khi điều hướng (gặp ở cả 6 lần đổi tài khoản). | Giao diện | M9 F.1, M5 B9 |
| B-23 | Dashboard hiện thẻ admin + số liệu tổng hợp (672 mặt hàng, 8 kho, 15 nhóm, 24 vai trò) giống hệt nhau với mọi vai trò. | Bảo mật | M9 F.6 |
| B-24 | Filter dropdown lộ tên danh mục: 16 NCC trên /finance/invoices (thu mua), 8 kho trên filter /inventory/stock (không lộ tiền/chứng từ). | Bảo mật | M9 F.5 |
| B-25 | Kế toán mở /frontdesk/minibar thì thấy TRỐNG (không thấy phiếu 101 đang chờ thu). | Giao diện | M9 F.9 |
| B-26 | HK xem được giá minibar nhưng KHÔNG xem được tồn kho phòng (thiếu `stock.view_qty`) — cùng họ với B-27. | Bảo mật | M9 F.8, M5 B3 |
| B-27 | Thủ kho + Thu mua không xem được giá trị tồn / giá vốn bình quân ("chỉ hiện số lượng"). | Bảo mật | M6 L5, M3 §2 |
| B-28 | /admin/users chỉ hiện đúng dòng của chính tài khoản đó, kể cả với owner/GM. | Giao diện | M9 |

### 2.5. Chưa sửa — giao diện / UX khác

| # | Mô tả | Lớp | Tái hiện |
|---|---|---|---|
| B-29 | Phiên buffet đã đóng hiển thị "KHÔNG RÕ TRẠNG THÁI" thay vì "Đã đóng" (cả danh sách + chi tiết, chef + GM). | Giao diện | M4 F-1 |
| B-30 | Không đóng được phiên buffet 0 khách (Số khách = 0 → [invalid], nút đóng vô hiệu; phải nhập 1 khách giả × 0 đ). | Giao diện | M4 F-3 |
| B-31 | Bán hàng KHÔNG kiểm tra tồn kho (bán món cần tôm/trứng/bột khi tồn = 0, không cảnh báo). | Giao diện | M4 F-4 |
| B-32 | Tìm kiếm ở màn Tồn kho → "Không thể tải dữ liệu / Invalid UUID" (gõ NVL0388 hoặc "ba chỉ nách"). Đã hẹp nguyên nhân trong M1: form Lọc gửi tham số `warehouse=` rỗng; mở trực tiếp URL chỉ có `?search=` thì tải bình thường. | Giao diện | M4 F-5, M6 L2, M1 F-2 |
| B-33 | Nút "Hủy dòng" (hủy dòng bán) bấm 4 lần ở 3 vai trò đều không phản hồi — nghi hộp thoại xác nhận, cần người bấm tay để xác minh. | Giao diện | M4 F-6 |
| B-34 | Link trực tiếp vào chi tiết món không ổn định (Bu_18 → lỗi chung; ALA-03 → 404; mở từ danh sách thì được). | Giao diện | M4 F-8 |
| B-35 | Không có số hóa đơn cho dòng bán (chỉ có "dòng bán", không có số để đối chiếu/hủy). | Giao diện | M4 F-9 |
| B-36 | Không có đối soát ca (không có tiền đầu ca, không tách tiền mặt/thẻ khi đóng ca). | Giao diện | M4 F-10 |
| B-37 | Trang trước (front-desk) ghi sai trạng thái phiếu 104 chưa kiểm thành "Chờ thu tiền 0 đ" (chi tiết ghi "Phiếu này chưa được kiểm — chưa có dòng thiếu."; mobile ghi đúng "Chưa kiểm"). | Giao diện | M5 B2 |
| B-38 | Không giới hạn số lượng thiếu minibar: nhập 999 được chấp nhận → "Tạm tính 24.975.000 đ", không cảnh báo. Số âm −1 thì bị từ chối (tốt). | Giao diện | M5 B4 |
| B-39 | Không ghi được phiếu kiểm minibar toàn 0 (chưa nhập món thiếu nào → nút gửi vô hiệu: "Chưa nhập món thiếu nào…") — phòng không dùng gì thì không ghi nhận được. | Giao diện | M5 B5 |
| B-40 | Tiêu chuẩn phòng: 36 dòng = 3 loại phòng × 12 món, số lượng GIỐNG HỆT nhau ở cả 3 loại (Bàn chải 0.8868, Giấy vệ sinh 0.7174…) — dữ liệu demo, không phải tiêu chuẩn thật theo loại phòng. | Giao diện | M5 B6 |
| B-41 | Mức par xe đẩy không hiển thị thành số ở đâu; không có thao tác lĩnh bù tay (chỉ tự sinh "phiếu lĩnh bù tới par" khi đếm mở < par). | Giao diện | M5 B7/B8 |
| B-42 | /reports hiện CẢ HAI thông báo với tài khoản 0 quyền xem báo cáo ("Bạn chưa được cấp quyền xem báo cáo nào." VÀ "Đã xảy ra lỗi khi tải dữ liệu…"). | Giao diện | M9 F.2 |
| B-43 | Trang 404 không nhất quán (chef/HK không có nav trái; thu mua có menu). | Giao diện | M9 F.7 |
| B-44 | Khoảng ngày đảo ngược được chấp nhận trong im lặng (F&B from=13/11&to=01/11 vẫn hiện 145.000 đ, không báo lỗi). | Giao diện | M7 F-4 |
| B-45 | Thẻ hub /reports của GM không có số tóm tắt (của owner có: "2 đơn mua mở · còn lại 2.040.000 đ", "Doanh thu 145.000 đ…"). | Giao diện | M7 F-9 |
| B-46 | Nút xuất Excel điều hướng TAB HIỆN TẠI sang URL API (người dùng mất trang báo cáo). | Giao diện | M7 F-10 |
| B-47 | /reports/amenities → 404 (đường đúng /reports/amenity-cpor); nhiều ghi chú nguồn hiển thị KHÔNG dấu (waste, thẻ kho, minibar, opex). | Giao diện | M7 F-11 |
| B-48 | /receiving/mobile → "Không tìm thấy trang" (thủ kho); đường mobile đúng là /m/`<uuid>`/receive. | Giao diện | M2 F-4 |
| B-49 | Form hóa đơn: ô "Đơn mua" liệt kê PO-...-0003 nhưng bị disabled nên không chọn được, chưa hiện trường số tiền (có thể do PO chưa nhận hàng — cần xác nhận thiết kế). | Giao diện | M1 F-3 |
| B-50 | Tổng tiền PO chợ trên danh sách là 0 đ trong khi Tổng ước tính là 500.001 đ — hai con số khác nhau (ước tính chỉ hiện trên trang chi tiết). Cần đối chiếu khi đọc số liệu PO chợ. | Giao diện | M1 F-5 |
| B-51 | React error #419 (hydration) pageerror trên trang 404 bị chặn /procurement/pr với tài khoản receiver trong chạy đủ bộ (chạy lẻ thì đậu) — nghi cùng họ với menu stale (B-22). Trang render 2 thẻ `<main>` khi đang tải và trên trang 404 (a11y). | Giao diện | M11 |
| B-52 | 4 nút `size="sm"` còn lại (mobile-count-list.tsx:64, mobile-return-detail.tsx:250, mobile-returns-list.tsx:99, frontdesk-check-list.tsx:185); Button mặc định h-8/lg h-9 < 44px toàn cục (quyết định thiết kế). | Giao diện | M15 |
| B-53 | `normalizeSearch` không chuẩn hóa "đ" (tìm "duong" không ra "Đường"); test đã khóa hành vi hiện tại. | Giao diện | M12 |
| B-54 | Glossary: thiếu "Điều chuyển" và "Phiếu trả hàng NCC"; UI "Phiếu xuất mục đích" vs GLOSSARY "Xuất theo mục đích" lệch tên. | Giao diện | M13 |
| B-55 | demo-walkthrough §4.4 ghi "vào /restaurant và /inventory → 'Module đang tắt'" — SAI với /inventory (core, vẫn mở; chỉ mục POS ẩn). | Giao diện | M10 F-4 |
| B-56 | Ô "Tổng ước tính" lúc đang lưu nút tạm mờ đi, dễ tưởng bị từ chối — cần đợi rồi quan sát lại (không phải lỗi, ghi chú UX). | Giao diện | M1 §3 |

## 3. Chuyển Claude Code (ưu tiên)

**P0 — chặn luồng chính, làm trước:**
1. B-1 — Trang tạo đợt kiểm kê lỗi máy chủ (ERROR 2594239425). Cần log Vercel.
2. B-2 — Lưu nháp PO chợ mất sửa trong im lặng.
3. B-3 — Thu tiền minibar "Không đủ tồn kho để xuất." (kèm B-8 đối soát minibar).
4. B-5 — Xuất Excel: `ERR_EXPORT_NOT_LOCKED` chặn cả khoảng ngày trống + HTTP 500 (receiving-quality, waste) + 6 báo cáo không có nút xuất.
5. B-4 — Không có nút tạo phiếu lĩnh / điều chuyển / hủy hàng (xác nhận: hệ thống tự sinh phiếu lĩnh từ phiên buffet/banquet, hay thiếu nút tạo tay?).

**P1 — sai số liệu / quyền:**
6. B-7 — Lãi gộp F&B không nhất quán giữa 2 màn (145.000 đ vs 0 đ).
7. B-10 — Cảnh báo đỏ trùng lặp + trạng thái gửi mâu thuẫn.
8. B-9 — "SL tồn kho" trên phiếu lĩnh bằng số lượng yêu cầu.
9. B-12/B-13/B-14/B-15 — Quyền xem chênh lệch của GM, GM vào /inventory/transfers, thủ kho/thu mua vào /inventory/waste, thủ kho xem PO.
10. B-16 — Owner không xem được audit trace (cần màn chi tiết audit log — M-04 đã ghi thiếu).
11. B-20/B-21 — Module-off guard: /inventory/pos-import tải form khi tắt module; trigger thiếu 5 bảng + không chặn DELETE.
12. B-32 — Tìm kiếm màn Tồn kho "Invalid UUID" (đã hẹp: `warehouse=` rỗng).
13. B-6 — Mở lại PO sinh thêm nháp GRN (chặn trùng nháp).
14. B-17/B-18/B-19 — Menu↔route lệch; link GRN→PO; vị trí đối chiếu 3 chiều.
15. B-26/B-27 — HK/thủ kho/thu mua thiếu `stock.view_qty` / `stock.view_value` (quyết định cấp quyền — hỏi Duy).

**P2 — giao diện / UX (làm sau P0/P1):**
16. B-29, B-30, B-31, B-33, B-34, B-35, B-36 (nhà hàng); B-37, B-38, B-39, B-40, B-41 (buồng phòng/minibar); B-22, B-42, B-43, B-44, B-45, B-46, B-47, B-48, B-49, B-50, B-51, B-52, B-53, B-54, B-55, B-56.

**Cần Duy quyết (không tự quyết):** B-31 (bán hàng có kiểm tồn không?), B-35/B-36 (có số hóa đơn / đối soát ca không?), B-4 (phiếu lĩnh tự sinh hay tạo tay?), B-15 (thủ kho có cần xem PO?), B-19 (đối chiếu 3 chiều nằm ở đâu?), B-49 (hóa đơn có bắt buộc PO đã nhận hàng không?), B-26/B-27 (cấp `stock.view_qty`/`stock.view_value` cho những vai trò nào?), B-3/B-8 (quy trình tồn kho phòng khi thu tiền minibar — tồn phòng cấp phát lúc nào?).

## 4. Trạng thái cuối TEST47 (theo màn hình, 02:53 14/11/2026)

- **Tồn kho KHO-T047:** NVL0388 "ba chỉ nách" = **0 kg**; NVL0561 "Bánh bèo" = **0 cái**. (Chưa có phiếu nhận nào ghi sổ; đếm mù chưa chạy được nên không có bút toán điều chỉnh nào.)
- **Công nợ NCC:** SUP0001 "Công ty TNHH Thực phẩm Mẫu An Phát" — Còn phải trả **0 đ**, Quá hạn **0 đ**. (Chưa nhận hàng, chưa có hóa đơn.)
- **PO:** 0001 ĐÃ GỬI 1.040.000 đ (12/11, NCC T047); 0002 NHÁP 1.040.000 đ, 3 dòng (13/11, NCC T047); 0003 ĐÃ GỬI 1.000.000 đ (13/11, SUP0001); 0004 chợ NHÁP 0 đ, ước tính 500.001 đ (13/11).
- **PR:** 0001 (đã duyệt, đã chuyển PO), 0002 (đã duyệt), 0004 (chef, nháp), 0005 (thu mua, nháp), **0006 (M2, NVL0561 200 cái, NHÁP — để sẵn cho lần chạy tiếp)**.
- **Phiếu nhận:** GRN-...-0001 → 0006, **tất cả NHÁP, chưa ghi sổ** (0001 có 2 dòng đã ghi, 0002–0006 có 0–1 dòng; mở lại PO sinh thêm nháp — B-6).
- **Minibar:** MB-...-0001 (phòng 101) đã kiểm, **"Chờ thu tiền" 140.000 đ, CHƯA THU ĐƯỢC** (B-3); MB-...-0002 (phòng 104) chưa kiểm, 0 dòng, 0 đ. Giá minibar: 7 món, hiệu lực 11/11/2026 (Tiger 35.000 đ, Diet Coke 25.000 đ, Lavie 15.000 đ, Sprite 25.000 đ, Coca-Cola 25.000 đ, Rượu vang 245.000 đ, Bia Larue 25.000 đ).
- **Nhà hàng:** phiên buffet 13/11 tối ĐÃ ĐÓNG (1 khách × 0 đ, doanh thu 0 đ, hiển thị "KHÔNG RÕ TRẠNG THÁI"); 2 dòng bán ngày 13/11: ALA-02 Tôm Chiên Giòn 1 × 145.000 đ (không hủy), Buffet 1 × 0 đ (tự sinh khi đóng phiên). Doanh thu F&B ghi nhận **145.000 đ**.
- **Kiểm kê:** 2 đợt xe đẩy CNT-...-0001/0002 (13/11, "CHỜ DUYỆT", 0 dòng đếm) — có sẵn từ trước đợt này, không chạm tới. Không có đợt kiểm kê kho nào mới.
- **Phiếu lĩnh:** REQ-...-0001 NHÁP (Kho chính → Kho bếp, 7 dòng, tổng 0.425).
- **Xe đẩy:** 1 ca Xe đẩy 1 (Demo) ngày 13/11 đã mở + đóng, tiêu thụ 0.
- **Cảnh báo:** 11 cảnh báo (9 đỏ `PERMISSION_CRITICAL_CHANGED` ngày 12-11, 2 xanh minibar); chuông "Cảnh báo chưa xử lý (10)".
- **"Sáng nay":** Chi mua hàng hôm qua 0 đ; Giá trị hủy hôm qua 0 đ; Cảnh báo đỏ chưa xử lý 8; Công nợ đến hạn 7 ngày 0 đ; Tạm ứng quá hạn 0.

## 5. Lệnh đã chạy + kết quả thật

```text
pnpm lint && pnpm typecheck && pnpm test   (sau mỗi task, KHÔNG dùng pipe — xem bẫy gate)
  → lint sạch, typecheck sạch, Vitest 285/285 (31 file) — từ 213 lên 285 sau M12 (+72 test)
Playwright (M11, qua proxy-forwarder 127.0.0.1:18080): 31 passed / 3 failed
  → R-receiver hydration #419 (chạy lẻ đậu), M4 indexedDB lazy singleton, M5 SW active false
  → Write-tier env-gate VERIFIED: project=write không có TEST_WRITE_ENABLED → 11 skipped, 1 passed
Trình duyệt cloud: M9 (3 đợt, 9 tài khoản × 20 URL = 180/180 mở được, 0 lỗi 500), M4, M5, M6, M7,
  M8 (timeout 02:31, không báo cáo cuối), M1 (02:33–02:38), M3 (02:40–02:46, failed), M2 (02:48–02:53)
```

## 6. Chưa làm được + vì sao

1. **M8 — Danh mục & import:** tác vụ trình duyệt hết thời gian chờ (timeout 02:31) mà không trả báo cáo cuối. Đã xác minh được nội dung 2 file mẫu (vật tư 13 cột, NCC 10 cột — xem M8). **Chưa xác nhận được import POS hay import danh mục có hoàn tất không** (file tải về không được cấp cho tác vụ; data: URL bị từ chối; file được cấp giữa chừng vẫn upload không thành). Cần chạy lại với cách cấp file khác, hoặc trên trình duyệt máy (Duy) nơi file có sẵn trên đĩa. Không xác nhận nhập NCC/vật tư nào (đúng nguyên tắc an toàn — danh mục chung chuỗi).
2. **M2 — Chu trình chênh lệch đầy đủ:** chỉ làm tới PR-0006 nháp. Chặn bởi (a) nút "Gửi duyệt" dùng hộp thoại xác nhận — trình duyệt tự động không bấm được; (b) ghi dòng nhận hàng bắt chụp ảnh — cloud không có camera. Cần người thao tác tay trên trình duyệt thật có camera (xem M2 §8).
3. **M3 — Đếm mù:** chặn ở bước mở đợt (B-1). Cần sửa lỗi trang tạo đợt rồi làm lại từ đầu; đồng thời kiểm tra quyền xem/duyệt chênh lệch của GM (B-12).
4. **M5 bước 3 — Đồng bộ offline minibar:** không kiểm tra được (trình duyệt tự động không ngắt mạng được; cần thiết bị thật).
5. **M4 "Hủy dòng":** nút không phản hồi trong trình duyệt tự động — cần người bấm tay để xác minh có phải hộp thoại xác nhận không (B-33).
6. **SoD:** các khối SoD của M2 (người nhận không ghi sổ phiếu mình mở, người tạo hóa đơn không duyệt hóa đơn mình tạo, người tạo yêu cầu chi không duyệt, người tạo PR không duyệt PR) **chưa kiểm chứng được** vì chuỗi duyệt → PO → nhận chưa tới được bước ghi sổ/duyệt. Chỉ có SoD của Day 1 (TEST02 duyệt PO#1 nên không ghi sổ GRN-0001) đã chứng minh trước đó. Cần chạy lại sau khi (2) được tháo.
7. **M1/M2 — Kiểm tra rò rỉ qua network:** trình duyệt tự động không mở được DevTools nên phần kiểm tra lộ dữ liệu qua network (đếm mù, nhận hàng mù) chưa làm được — chỉ kiểm tra được bằng mắt trên màn hình (mù giữ ở cả 3 màn nhận hàng; màn đếm chưa mở được).

## 7. Cần Duy làm / quyết

- **Bấm tay trên trình duyệt thật có camera:** (1) "Gửi duyệt" cho PR-TEST47-LE-2611-0006 → GM duyệt → tạo PO → thủ kho nhận 180/200 + 5 hỏng, chụp ảnh minh chứng. (2) "Hủy dòng" bán hàng (M4 F-6) để xác minh có phải hộp thoại xác nhận không.
- **Quyết các câu hỏi ở mục 3 (cuối):** cấp quyền xem tồn/giá trị cho vai trò nào; phiếu lĩnh tự sinh hay tạo tay; vị trí đối chiếu 3 chiều; hóa đơn có bắt buộc PO đã nhận hàng; thủ kho có cần xem PO.
- **Merge nhánh này** (xem lệnh ở dưới) rồi deploy; sau đó Claude Code làm P0/P1 ở mục 3.
- **Day 1 (30 ngày) vẫn kẹt ở NVL0152** — cần Duy cho giá đ/kg hoặc duyệt bỏ dòng đó (xem PLAN-30NGAY.md). Đợt đêm nay tạo thêm tài liệu trên TEST47 (PR-0006, GRN-0006, MB-101 đã kiểm chưa thu, 2 dòng bán F&B) — khi chạy tiếp Day 1 phải đối chiếu lại trạng thái thực tế này.
