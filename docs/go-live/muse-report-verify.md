# BÁO CÁO TỔNG — XÁC MINH CÁC BẢN SỬA Q268–Q272 (V1–V10)

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Phạm vi: xác minh live các bản sửa của Claude Code Q268–Q272 (migrations 574000–578000) trên dữ liệu TEST47, bằng trình duyệt cloud + tài khoản `uat.*` + Playwright.
- Nhánh: `feat/muse-verify` (từ main `fb194a1`), 1 commit/bài, tiền tố `T-Vxx:`; gate `pnpm lint && pnpm typecheck && pnpm test` xanh sau mỗi commit.
- Kết luận chung: **7/10 bài đạt hoặc đạt một phần; 3 bài không hoàn thành luồng chính (V1, V3, V5) — cùng một gốc: tồn kho TEST47 = 0 và trình duyệt cloud không có camera.** Các bản sửa đã xác nhận đúng: Q268 (PO chợ, xuất Excel), Q272 B-37/B-38/B-42/B-44/B-50/B-29/B-7/B-31, Q270 (quyền mở rộng + tính mù giữ), Q271 B-18/B-32/B-22. **3 bản sửa được ghi là xong nhưng kiểm lại vẫn lỗi: B-39 (gửi phiếu minibar 0 món), B-33 (hủy dòng bán không hỏi xác nhận), B-3 (thu tiền minibar — cần tồn phòng).** Phát hiện mới lớn nhất: mọi thao tác tiêu tồn đều chặn bằng một câu chung chung "Dữ liệu không hợp lệ" (V4-N1), và tìm kiếm 2 từ trả 0 kết quả (V10-N1).

## 1. Bảng kết quả V1–V10

| Bài | Nội dung | Kết quả | Ghi chú |
|---|---|---|---|
| V1 | Chu trình mua–nhận–trả (Q268 B-18, B-49) | **Không hoàn thành** (a–d đạt) | Kẹt camera ở bước nhận; form hóa đơn mở được, hint đúng, link GRN đúng |
| V2 | Chu trình chênh lệch + SoD | **Đạt một phần** | Ô xác nhận trên trang đạt 5/5; PO-0005 đã gửi; SoD theo kịch bản không kiểm được (GM không tạo được PR) |
| V3 | Kiểm kê đếm mù (Q268 B-1) | **Không hoàn thành** | Trang tạo đợt đạt 2 đường; cả 2 loại đợt đều 0 dòng vì tồn = 0 |
| V4 | Chứng từ kho (Q270 B-4) | **Đạt một phần** | 4 form + nháp + duyệt đạt; 3 thao tác tiêu tồn chặn chung chung |
| V5 | Minibar thu tiền (B-3) | **Không hoàn thành** | Đường cấp tồn có nhưng kho nguồn = 0; B-37/B-38 đạt; B-39 tái hiện |
| V6 | PO chợ (Q268, B-50) | **Đạt toàn bộ** | Sửa nháp lưu được; gửi duyệt không chặn vì "giá 0"; PO-0004 CHỜ DUYỆT |
| V7 | Quyền mới Q270 | **Đạt một phần** | Mở rộng đạt, mù giữ; chênh lệch/giá trị tồn chưa kiểm đủ |
| V8 | Bán hàng nhà hàng (B-31, B-7, B-29, B-33) | **Đạt một phần** | B-31/B-7/B-29 đạt; B-33 tái hiện |
| V9 | Báo cáo + Excel (B-5) | **Đạt một phần** | B-46/B-44/B-42 đạt; 2 báo cáo xuất im lặng; nhánh xuất khi khóa chưa kiểm |
| V10 | Quét nhanh giao diện (B-53/B-32/B-20/B-22/390px) | **Đạt một phần** | B-32/B-22 đạt; B-53 một phần; 390px đạt 20/20 qua Playwright |

## 2. Bảng xác minh lỗi cũ B-1…B-56

| Mã | Nội dung | Kết quả | Bằng chứng |
|---|---|---|---|
| B-1 | Trang tạo đợt kiểm kê tải được | **Đạt** | V3 — desktop + mobile |
| B-2 | Sửa nháp PO chợ không lưu được | **Đạt** | V6 — mô tả dòng còn sau F5 |
| B-3 | Thu tiền minibar khi kho phòng chưa có tồn | **Không đạt — tái hiện** | V5 — "Không đủ tồn kho để xuất.", phiếu 101 vẫn "Chờ thu tiền" 140.000 đ |
| B-4 | Form + thao tác 4 chứng từ kho | **Đạt một phần** | V4 — form + nháp + duyệt + hủy nháp đạt; xuất/chuyển/ghi sổ chặn chung chung |
| B-5 | Xuất Excel HTTP 500 | **Đạt một phần** | V9 — 0 lỗi 500 trong 7 lần bấm; 2 báo cáo im lặng; nhánh khóa chưa kiểm |
| B-6 | Mở lại PO sinh thêm nháp GRN | **Không kiểm trực tiếp** | Theo Q267 là thiết kế (mỗi receiver một nháp riêng); V1/V2 ghi nhận thêm GRN 0006/0007 khi mở lại PO |
| B-7 | Lãi gộp trang bán ≠ báo cáo F&B | **Đạt** | V8 — khớp 145.000/0/0 (14/11) |
| B-8 | Báo cáo Minibar lệch 140.000 đ | **Không kiểm được** | V5/V9 — chưa thu được tiền phiếu 101 |
| B-9 | Cột "SL tồn kho" gây hiểu lầm | **Không kiểm được** | Không ghi trong V4 |
| B-10 | 9 cảnh báo PERMISSION_CRITICAL_CHANGED | **Không kiểm trong V1–V10** | Theo Q271 không phải lỗi (9 phân quyền khác nhau) |
| B-11 | Số liệu PO ghi sai trong M9 đợt 2 | **Không phải lỗi app** | M1 đã đối chiếu và sửa số liệu |
| B-12 | GM xem chênh lệch kiểm kê | **Đạt một phần** | V7 — quyền đã mở (không còn dòng chặn); chưa có số chênh lệch thật |
| B-13 | `transfer_list` cho `stock.view_qty` | **Đạt** | V7 1a — GM mở /inventory/transfers |
| B-14 | Tab Điều chuyển trong menu Kho | **Đạt** | V7 1a |
| B-15 | Thủ kho mở được chi tiết PO | **Đạt** | V7 2a |
| B-16 | Owner xem /admin/audit | **Không kiểm trong V1–V10** | Theo Q271: quyền chain-level, tài khoản Duy mở được |
| B-17 | Login/logout `revalidatePath` | **Đạt** | V10 bước 4 — menu cập nhật ngay khi đổi tài khoản (cùng họ B-22) |
| B-18 | Link GRN trỏ về PO thay vì GRN | **Đạt** | V1 (c) |
| B-19 | Trang chi tiết PO không có mục đối chiếu 3 chiều | **Không đạt** | V2 — vẫn không có mục này trên trang chi tiết PO-0005 |
| B-20 | /inventory/pos-import hiện "Module đang tắt" khi module tắt | **Không kiểm được** | V10 — module đang bật (không được bật/tắt); hành vi khi bật là đúng |
| B-21 | `_module_guard` chặn DELETE + bảng con | **Không kiểm trong V1–V10 (UI)** | pgTAP 19/19 theo Q271 |
| B-22 | Menu cũ sau khi đổi tài khoản | **Đạt** | V10 bước 4 |
| B-23 | Dashboard hiện thẻ admin + số liệu tổng với mọi vai trò | **Không kiểm trong V1–V10** | — |
| B-24 | Filter dropdown lộ tên danh mục | **Không kiểm trong V1–V10** | — |
| B-25 | Kế toán mở /frontdesk/minibar thấy TRỐNG | **Không kiểm trong V1–V10** | — |
| B-26 | HK xem giá minibar nhưng không xem tồn kho phòng | **Đạt** | V7 3a/3b — mù giữ (theo thiết kế Q270) |
| B-27 | Thủ kho + Thu mua không xem được giá trị tồn | **Không kiểm được** | V7 2c — cần tồn > 0 (Q270 đã cấp `stock.view_value` cho sm_purchasing_store) |
| B-28 | /admin/users chỉ hiện đúng dòng của chính tài khoản | **Không kiểm trong V1–V10** | — |
| B-29 | Phiên buffet đã đóng hiện "Đã hoàn tất" | **Đạt** | V8 |
| B-30 | Không đóng được phiên buffet 0 khách | **Không kiểm trong V1–V10** | Theo Q272: theo thiết kế (có nút hủy phiên) |
| B-31 | Bán món khi tồn thiếu: vẫn ghi + cảnh báo | **Đạt** | V8 — cảnh báo 7 nguyên liệu + phiếu lĩnh nháp REQ-0003 tự sinh |
| B-32 | Tìm ở /inventory/stock báo "Invalid UUID" | **Đạt** | V10 bước 2 |
| B-33 | Hủy dòng bán qua ô xác nhận trên trang | **Không đạt — tái hiện** | V8 — bấm "Hủy dòng" hủy ngay, không hiện ô hỏi |
| B-34 | Link trực tiếp chi tiết món không ổn định | **Không kiểm trong V1–V10** | — |
| B-35 | Không có số hóa đơn bán hàng | **Không kiểm trong V1–V10** | Chờ Duy quyết |
| B-36 | Không có đối soát ca bán hàng | **Không kiểm trong V1–V10** | Chờ Duy quyết |
| B-37 | Phiếu minibar chưa kiểm hiện "Chờ thu tiền 0 đ" | **Đạt** | V5 — hiện "Chưa kiểm" |
| B-38 | Cảnh báo khi số lượng minibar > 20 | **Đạt** | V5 — "Có món số lượng lớn hơn 20 — hãy kiểm tra lại trước khi gửi." |
| B-39 | Gửi phiếu minibar 0 món khi tick "Phòng không dùng món nào" | **Không đạt — tái hiện** | V5 — tick xong bấm Gửi vẫn báo "Cần ít nhất một món thiếu để gửi kết quả kiểm." |
| B-40 | Tiêu chuẩn phòng minibar giống hệt nhau (dữ liệu demo) | **Không kiểm trong V1–V10** | Theo Q272: dữ liệu demo, chưa sửa |
| B-41 | Par xe đẩy không hiển thị số | **Không kiểm trong V1–V10** | Theo Q272: thiết kế |
| B-42 | Tài khoản 0 quyền báo cáo thấy 2 thông báo | **Đạt** | V9 — chỉ 1 dòng "Bạn chưa được cấp quyền xem báo cáo nào." |
| B-43 | Trang 404 không nhất quán giữa các vai trò | **Không kiểm trực tiếp** | 404 chung đã ghi nhận ở V7 N-4, V10 N-3 |
| B-44 | Ngày ngược (từ > đến) trả dữ liệu im lặng | **Đạt** | V9 — "Ngày bắt đầu phải trước hoặc bằng ngày kết thúc." + không trả dữ liệu |
| B-45 | Thẻ tổng quan GM không có số liệu | **Không kiểm trong V1–V10** | Theo Q272: chưa sửa |
| B-46 | Nút Xuất Excel chuyển tab | **Đạt một phần** | V9 — không đổi tab ở cả 5 báo cáo; thông báo dưới nút chỉ hiện ở 3/5 |
| B-47 | Ghi chú nguồn số liệu báo cáo không dấu | **Không đạt — tái hiện** | V8 N-2 — ghi chú F&B vẫn không dấu (cần migration riêng) |
| B-48 | /receiving/mobile 404 (thủ kho) | **Đạt theo thiết kế** | V2 — đường mobile đúng là /m/`<uuid>`/receive |
| B-49 | Form hóa đơn: chọn NCC trước mới thấy PO | **Đạt** | V1 (b) — "Hãy chọn nhà cung cấp trước để thấy danh sách đơn mua." |
| B-50 | Danh sách PO hiện 0 đ với dòng chưa có giá | **Đạt** | V6 — "Chưa có giá (xem chi tiết)" |
| B-51 | 2 thẻ `<main>` khi tải + trang 404 | **Không kiểm trực tiếp** | Playwright 20/20 — `<main>` hiển thị bình thường (V10) |
| B-52 | Nút "Xóa chữ ký" mobile 44px | **Không kiểm trong V1–V10** | — |
| B-53 | Tìm "duong" không ra "Đường" | **Đạt một phần** | V10 — 1 từ không dấu hoạt động ở danh mục; trang tồn kho chưa kiểm được (tồn rỗng); tìm 2 từ trả 0 (lỗi mới) |
| B-54 | GLOSSARY thiếu Điều chuyển / Phiếu trả hàng NCC | **Không kiểm trực tiếp** | Theo Q272 đã thêm |
| B-55 | Walkthrough mô tả sai /inventory khi nhà hàng tắt | **Không kiểm trực tiếp** | Theo Q272 đã sửa |
| B-56 | Nút "Tổng ước tính" mờ đi lúc lưu, dễ tưởng bị từ chối | **Ghi chú UX** | V6 N-2 ghi nhận độ trễ tương tự ở nút gửi duyệt |

## 3. Lỗi / bất thường mới (tổng hợp V1–V10)

### 3.1 Chặn (blocker — luồng chính không chạy được)

| ID | Mô tả | Tái hiện | Lớp |
|---|---|---|---|
| V1-N1 / V2-N5 | Trình duyệt cloud không có camera (fake device không hoạt động) — nhận hàng + hủy hàng có ảnh đều kẹt | Mở màn nhận → bấm chụp ảnh → "Không tìm thấy camera trên thiết bị này." | Môi trường (không phải lỗi app) — cần thiết bị thật |
| V3-N1 | Đợt kiểm kê sinh 0 dòng khi tồn = 0 — cả tháng + luân phiên; không có cách thêm mặt hàng tồn 0 | Mở đợt mới trên KHO-T047 khi tồn = 0 → "Đã đếm 0/0 dòng" | DB/RPC + thiết kế — cần Duy/Claude xác nhận có phải thiết kế không |
| V5-N1 (B-39) | Gửi phiếu minibar 0 món vẫn rớt dù đã tick "Phòng không dùng món nào" — bản sửa Q272 chưa đủ | Mobile /m/`<uuid>`/minibar/`<phiếu 104>` → 0 món → tick → Gửi → "Cần ít nhất một món thiếu để gửi kết quả kiểm." | UI + RPC (kiểm tra phía máy chủ mâu thuẫn với ô tick) |
| V5-N2 (B-3) | Thu tiền phiếu 101 vẫn báo "Không đủ tồn kho để xuất." — cần tồn phòng trước | /frontdesk/minibar/`<phiếu 101>` → folio TEST-M5-1311 → "Đã thu" | Dữ liệu (cần tồn thật) — xem Q268 |
| V8-N1 (B-33) | "Hủy dòng" bán hàng hủy ngay không qua ô xác nhận — bản sửa Q272 chưa đủ | Bếp trưởng → Bán hàng → lọc 14/11 → "Hủy dòng" → ĐÃ HỦY ngay | UI (bọc bằng InlineConfirmButton) |

### 3.2 Sai số liệu / chặn chẩn đoán

| ID | Mô tả | Tái hiện | Lớp |
|---|---|---|---|
| V4-N1 | Mọi thao tác tiêu tồn chặn bằng cùng một câu chung chung "Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập." — không phân biệt thiếu tồn / kho đóng băng / lỗi dữ liệu | Xuất kho REQ-0002, Chuyển hàng TRF-0001, Ghi sổ PIS-0001 | RPC/UI — trả mã lỗi/lý do cụ thể, map sang câu tiếng Việt |
| V1-N3 | Form hóa đơn không chặn SL hóa đơn (10) > SL đã nhận (0) ở nút Lưu (chỉ có ghi chú khớp 3 chiều); RPC có chặn khi gửi hay không thì chưa kiểm (cố ý không gửi) | Mở form hóa đơn → chọn SUP0001 → PO-0003 → SL hóa đơn 10 trong khi SL đã nhận 0 → nút Lưu vẫn bật | RPC — cần xác minh `invoice_create` chặn khi gửi |
| V9-N1 | Xuất Excel im lặng ở 2 báo cáo dạng khoảng ngày (Chất lượng nhận hàng, Hủy hàng): nút "Đang xuất…" rồi trở lại, không thông báo, không 500, không file | /reports/receiving-quality hoặc /reports/waste (kỳ chưa khóa) → "Xuất Excel" | UI — nhánh lỗi ERR_EXPORT_NOT_LOCKED không được bắt/hiển thị ở 2 báo cáo này |
| V10-N1 | Tìm kiếm nhiều từ trả 0 kết quả dù mặt hàng tồn tại: "duong the" → 0 (trong khi "duong" → 1 "Đường thẻ"); "ba chi" → 0 (trong khi "ba" → 16) | /master/items?search=duong%20the | UI/tìm kiếm — tách từ + khớp từng từ sau khi bỏ dấu |

### 3.3 Bảo mật / quyền (cần xác minh phía máy chủ)

| ID | Mô tả | Tái hiện | Lớp |
|---|---|---|---|
| V4-N4 | Người lập phiếu thấy nút Duyệt/Từ chối trên phiếu CHỜ DUYỆT của chính mình (chef, REQ-0002) — nguy cơ tự duyệt nếu RPC không chặn; bài kiểm không bấm thử | Mở chi tiết REQ-0002 bằng tài khoản chef sau khi gửi duyệt | RPC (xác minh SoD) + UI (ẩn nút với người tạo) |
| V2-N4 | /receiving/returns: GM + receiver bị chặn bởi `receiving.view`, chỉ thu mua xem được | Mở /receiving/returns bằng GM/receiver | Quyền — cần Duy/Claude xác nhận ai được xem phiếu trả |
| V2 bước 7 | GM không tạo được PR (thiếu `pr.create`) nên kịch bản "người tạo PR tự duyệt" không xảy ra được qua UI; SoD ở tầng RPC (người tạo = người duyệt) chưa được kiểm | Mở /procurement/pr/new bằng GM → nhập đủ → "Lưu nháp" chặn "Bạn chưa được cấp quyền pr.create" | RPC — cần Duy/Claude chấp nhận tách quyền hay kiểm thêm |

### 3.4 Giao diện (nhỏ)

- **V2-N1:** trạng thái (badge) không refresh ngay sau thao tác ô xác nhận (gửi PR/PO, duyệt PO, gửi NCC) — toast hiện nhưng badge giữ trạng thái cũ tới khi tải lại trang (duyệt PR thì refresh ngay).
- **V2-N2:** form tạo PR của GM nhận đủ dữ liệu rồi mới chặn lúc lưu (danh sách ẩn nút "Tạo yêu cầu" nhưng mở trực tiếp bằng URL thì form vẫn mở).
- **V2-N3:** màn nhận không có ô ghi chú — không ghi được "5 hỏng" khi nhận thiếu.
- **V3-N2:** luật người đếm độc lập chặn mọi cặp 2 người đã thử (kể cả cặp có Chủ đầu tư/Duy); chỉ chọn cả 8 người mới mở được đợt — không rõ tiêu chí "độc lập", giao diện không chỉ ai đủ điều kiện.
- **V3-N3:** receiver không có trong danh sách người đếm.
- **V3-N4/N-5:** bấm đợt trong danh sách mobile không chuyển trang; sau "Mở đợt kiểm kê" trang chuyển chậm.
- **V4-N2:** ô xác nhận trên trang không nhất quán — "Gửi duyệt" phiếu lĩnh, "Duyệt" của GM, "Ghi sổ" phiếu xuất thực thi ngay; "Xuất kho"/"Chuyển hàng"/"Hủy phiếu" thì có ô xác nhận.
- **V4-N3:** lý do hủy hiển thị mã thô "spoiled_storage" thay vì nhãn "Hỏng do bảo quản".
- **V4-N5:** ĐVT "Bánh bèo" hiển thị "cai" (không dấu); /procurement/approvals không liệt kê phiếu lĩnh chờ duyệt; sau "Lưu nháp" trang giữ form vài giây mới chuyển.
- **V5-N4:** hk_supervisor thiếu `stock.view_qty` — cần Duy xác nhận có nên cấp không (đếm mù) hay cảnh báo là đúng thiết kế.
- **V5-N5:** bảng theo món của báo cáo Minibar chỉ liệt kê 5/7 món (thiếu Sprite, Rượu vang).
- **V5-N6:** trạng thái phiếu 101 hiển thị khác nhau theo màn hình (mobile "Đã kiểm 140.000 đ", lễ tân "Chờ thu tiền"); đường mobile đúng là /m/`<uuid>`/minibar.
- **V6-N1/N-2/N-3/N-4:** sau "Lưu nháp" không có phản hồi xác nhận; sau gửi duyệt trạng thái có độ trễ vài giây; form Sửa nháp không có ô lý do sửa riêng; điều hướng có độ trễ.
- **V7-N1/N-2:** GM xem chênh lệch đợt xe đẩy chỉ thấy cột "—" (SỐ SỔ/CHÊNH LỆCH/% LỆCH); thông báo biên bản gộp 2 nguyên nhân ("người đếm chưa nộp hoặc bạn không có quyền xem").
- **V7-N3:** trang Tồn kho khi trống ẩn hẳn bảng + tổng giá trị (không kiểm được quyền xem giá trị ở trạng thái tồn 0).
- **V7-N4/N-5:** receiver bị chặn PO bằng trang 404 chung; màn nhận mobile không có lối vào chỉ-đọc (mở nhiệm vụ là tạo nháp GRN).
- **V8-N2:** typo "Chúc năng thường dùng" (đúng là "Chức năng"); ghi chú F&B không dấu (B-47).
- **V10-N3/N-4/N-6/N-7:** receiver mở /inventory/waste/new → 404 chung; mở chi tiết phiếu bằng mã chứng từ trong URL → lỗi tải chung (phải dùng UUID); sidebar tải chậm (chỉ "Tổng quan" + "Danh mục" lúc đầu); nút "Tìm kiếm" ở /master/items có vẻ không lọc (chưa chắc chắn — cần kiểm lại).
- **V1-N2/N-5:** giá trị cân đã nhập mất khi tải lại trang nhận (không có nháp dòng tự lưu); ô chọn trên form hóa đơn tải chậm vài giây.
- **V1-N4:** số cảnh báo đỏ đổi 8 → 10 trong phiên của owner (chưa giải thích được — chỉ ghi nhận).

## 4. Chuyển Claude Code (ưu tiên)

### P0 — Không có P0 về dữ liệu (không có lỗi nào làm sai số liệu đã ghi). 2 nút chặn gốc làm 5/10 bài không hoàn thành luồng chính — thuộc về dữ liệu/thiết bị, cần Duy quyết:
1. **Camera** — nhận hàng + hủy hàng có ảnh kẹt trên trình duyệt cloud; cần thiết bị thật (hoặc Duy quyết nới luật chụp ảnh — Q21).
2. **Tồn kho TEST47 = 0** — kiểm kê, chứng từ kho tiêu tồn, thu tiền minibar, xem giá trị tồn đều cần tồn thật; cần nhận hàng thành công (phụ thuộc camera) hoặc Duy quyết cách tạo tồn kiểm thử.

### P1
1. **V4-N1** — thông báo chặn chung chung "Dữ liệu không hợp lệ" ở mọi thao tác tiêu tồn (xuất kho/chuyển/ghi sổ).
2. **V5-N1 (B-39)** — gửi phiếu minibar 0 món vẫn rớt dù đã tick (bản sửa Q272 chưa đủ — kiểm tra cả RPC).
3. **V8-N1 (B-33)** — "Hủy dòng" bán hàng hủy ngay không qua ô xác nhận.
4. **V9-N1** — xuất Excel im lặng ở 2 báo cáo dạng khoảng ngày.
5. **V10-N1** — tìm kiếm 2 từ trả 0 kết quả.
6. **V3-N1** — đợt kiểm kê 0 dòng khi tồn = 0 (xác nhận thiết kế + nếu cần thì thêm cách thêm dòng tồn 0).
7. **V3-N2** — luật người đếm độc lập: làm rõ tiêu chí + gợi ý ai đủ điều kiện trong form.
8. **V1-N3** — xác minh RPC hóa đơn có chặn SL > SL đã nhận khi gửi không.
9. **V4-N4** — xác minh RPC chặn tự duyệt phiếu lĩnh + ẩn nút Duyệt/Từ chối với người tạo.
10. **V2-N4** — xác nhận ai được xem phiếu trả hàng NCC (`receiving.view`).
11. **V2 bước 7** — chấp nhận tách quyền PR (GM có duyệt, không có tạo) hay kiểm SoD ở tầng RPC.

### P2
- V2-N1 (badge không refresh), V2-N2 (form PR của GM), V2-N3 (ô ghi chú màn nhận), V3-N3/N-4/N-5, V4-N2 (ô xác nhận không nhất quán), V4-N3 (mã lý do thô), V4-N5, V5-N4 (cấp `stock.view_qty` cho hk_supervisor?), V5-N5, V5-N6, V6-N1/N-2/N-3, V7-N1/N-2/N-3/N-4/N-5, V8-N2 (typo "Chúc năng" + B-47), V10-N3/N-4/N-6/N-7, V1-N2/N-5, V7 1b (số chênh lệch đợt xe đẩy "—"), V9 nhánh xuất file khi kỳ đã khóa (kiểm sau khi có kỳ khóa), B-19 (vị trí đối chiếu 3 chiều), B-9 (nhãn cột phiếu lĩnh).

## 5. Trạng thái cuối TEST47 (14/11/2026, sau V10)

- **Tồn kho KHO-T047: NVL0388 = 0 kg, NVL0561 = 0 cái** (không đổi trong cả đợt — chưa có phiếu nhận nào ghi sổ).
- **SUP0001 công nợ = 0 đ** (chưa có hóa đơn nào được tạo).
- **PO:** 0001 ĐÃ GỬI 1.040.000 đ (12/11); 0002 NHÁP 1.040.000 đ (13/11, dòng NVL0152 giá 0 — Day 1 vẫn kẹt); 0003 ĐÃ GỬI 1.000.000 đ (13/11); **0004 Mua chợ CHỜ DUYỆT** (0 đ / ước tính 500.001 đ — V6 đã gửi duyệt); 0005 ĐÃ GỬI 1.000.000 đ (14/11, NVL0561 200 cái — V2).
- **PR:** 0001 đã chuyển PO; 0002 đã duyệt; 0004/0005 nháp; 0006 đã duyệt + chuyển PO-0005 (V2).
- **GRN: tất cả NHÁP, chưa ghi sổ** — 0001 (TEST02, UNPOSTABLE do SoD — không thử lại), 0002 (TEST03, Day 1), 0003/0004 (demo test), 0005 (M9), 0006 (V1, PO-0003, 0/1 dòng), 0007 (V2, PO-0005, 0/1 dòng).
- **Đợt kiểm kê:** CNT-0001/0002 (xe đẩy, CHỜ DUYỆT, 0 dòng — không chạm); CNT-0003 (tháng, ĐÃ HỦY — V3); **CNT-0004 (luân phiên, ĐANG MỞ, 0 dòng — V3, chưa thấy cảnh báo đóng băng)**.
- **Minibar:** MB-0001 (phòng 101) "Chờ thu tiền" 140.000 đ, CHƯA THU; MB-0002 (phòng 104) "Chưa kiểm", 0 đ.
- **Chứng từ kho (mới trong đợt verify):** REQ-0002 ĐÃ DUYỆT (V4, chưa xuất, Đã xuất 0); REQ-0003 NHÁP tự sinh từ bán ALA-02 (V8, 7 dòng, 0,425); WST-0001 NHÁP (V4, 0 ảnh); TRF-0001 ĐÃ HỦY (V4); TRF-0002 NHÁP (V5, Tiger ×1 → Minibar 101, chưa chuyển); PIS-0001 NHÁP (V4).
- **Nhà hàng:** dòng bán ALA-02 ngày 13/11 còn hiệu lực (145.000 đ); dòng bán ALA-02 ngày 14/11 ĐÃ HỦY (V8); F&B 01/11–14/11: doanh thu 145.000 đ, giá vốn 0 đ, lãi gộp 0 đ. Phiên buffet 13/11 "Đã hoàn tất".
- **Báo cáo Minibar 01/11–14/11:** Ghi nhận 140.000 đ, Doanh thu 0 đ, Đã thu 0 đ, Chờ thu 140.000 đ, Chênh lệch đối soát 140.000 đ.

## 6. Lệnh đã chạy + kết quả thật

```text
Trình duyệt cloud (10 phiên, 14/11/2026):
  V1  10:05–10:12  failed (camera)      V6  10:51–10:53  completed
  V2  10:15–10:24  completed            V7  10:55–11:00  completed
  V3  10:26–10:32  failed (0 dòng đếm)   V8  11:02–11:06  completed
  V4  10:34–10:40  completed            V9  11:11–11:15  completed
  V5  10:41–10:49  completed            V10 11:19–11:27  completed
Playwright (VM, proxy-forwarder 127.0.0.1:18080, Chrome for Testing):
  tests/e2e/readonly/mobile-overflow.spec.ts --project=readonly-mobile
  - storekeeper: 19/20 (rớt /admin/users — không có quyền admin, không phải tràn ngang)
  - owner: 20/20 PASSED (54.8s) — gồm 5 màn mới thêm cho V10
Gate (mỗi commit T-Vxx): pnpm lint && pnpm typecheck && pnpm test — xanh cả 10 lần.
Nhánh feat/muse-verify: 10 commit T-V1…T-V10 (5edd699, 9ee3072, fdd92a5, 821053c,
  5ff5d6e, 521443c, d26b554, 5081c02, 7aee161, bb3fc5a) + commit báo cáo tổng này.
```

## 7. Chưa xong + vì sao

- **V1 (mua–nhận–trả–thanh toán):** kẹt camera ở bước nhận → không có tồn → hóa đơn (chưa gửi), thanh toán, trả hàng đều chưa chạy được. Cần thiết bị có camera thật (hoặc Duy quyết nới luật chụp ảnh).
- **V3 (đếm mù/chênh lệch/duyệt/khóa + trường hợp biên):** cần tồn > 0 để đợt sinh dòng đếm; cần Duy/Claude xác nhận luật 0 dòng + luật người đếm độc lập.
- **V4 (xuất kho/nhận hàng/xuất mục đích + đảo phiếu):** cần tồn > 0; đảo phiếu cần phiếu đã ghi sổ.
- **V5 (thu tiền minibar + B-8):** cần tồn trong kho phòng 101 (nhận hàng minibar hoặc điều chuyển từ kho có tồn).
- **V7 1b/2c:** số chênh lệch thật + cột giá trị tồn — cần đợt kiểm kê có tồn và tồn > 0.
- **V9 (xuất file khi kỳ đã khóa):** cần một kỳ đã khóa (Duy duyệt khóa kỳ — chưa có).
- **V10 B-53 trên trang tồn kho:** cần tồn > 0.
- **V2 bước 7/8 (SoD ở tầng RPC):** cần thiết kế kiểm khác (người tạo = người duyệt qua RPC) hoặc Duy chấp nhận tách ở tầng quyền.
- **B-52 (nút "Xóa chữ ký" 44px):** không thuộc V1–V10, chưa kiểm.
- **M8 (nhập file POS/danh mục):** vẫn chưa xác nhận được (trình duyệt cloud không tải file lên được) — ngoài phạm vi đợt verify, cần thử bằng trình duyệt trên máy có file thật.
