# Báo cáo kiểm chứng rerun5 — ERP_hotel (15/11/2026)

> Nhánh `feat/muse-rerun5` từ `main` 7e5ee66 (Q285). Chạy tuần tự, một mình, chỉ giao diện web, tài khoản `uat.*`/TEST, khách sạn TEST47 (`b0000000-0000-4000-8000-000000000002`). Không supabase/migration/vercel/RPC/SQL trực tiếp; không đổi cấu hình/tài khoản/PIN/khóa kỳ; không ghi mật khẩu/PIN vào file/log. Nhịp nhanh theo quyết định của Duy (15/11): kẹt thì ghi nhận rồi đi tiếp, không thử lại quá 2 lần một chỗ.

## Kết quả tổng

| Task | Kết quả | Ghi chú |
|---|---|---|
| Y1 — TEST03 ghi 1 dòng + ghi sổ phiếu nhận (đăng nhập mới) | **Không kiểm được** | Lỗi quyền không tái hiện, nhưng form từ chối tải phiếu GRN-0002 (PO#1 đã nhận đủ) nên quyền chưa được gọi |
| Y2 — Điều chuyển 18 cái NVL0561 Kho bếp → Kho chính | **Đạt** | TRF-...-0010 ĐÃ NHẬN 18/18; Kho chính 206, Kho bếp 0 |
| Y3 — TRF-0002 hủy + phiếu mới Tiger MINIBAR_MAIN → phòng 101 | **Đạt** | TRF-0002 ĐÃ HỦY; TRF-0011 ĐÃ NHẬN 1/1; Tiger kho tổng 8, phòng 101 có 1 |
| Y4 — PIS-0001 hủy + phiếu xuất mục đích mới (ghi sổ → đảo) | **Đạt** | PIS-0001 ĐÃ HỦY; PIS-0002 ghi sổ rồi ĐÃ ĐẢO bằng quản lý; NVL0388 17→16→17, thẻ kho có bút toán đảo |
| Y5 — PO-0002: xóa dòng NVL0152 (giá 0 đ) | **Đạt** (thử lại bằng thủ kho) | Dòng NVL0152 đã xóa; còn 2 dòng nguyên vẹn; tổng 1.040.000đ; vẫn NHÁP; "Gửi duyệt" đã bật (không bấm) |
| Y6 — Menu Kho của owner + form nhận mặc định Kho chính | **Đạt một phần** | Kho mặc định Kho chính đã verify; menu Kho 5/7 mở được, bấm «Kho» vẫn đáp xuống «Phiếu lĩnh» lỗi |
| Y7 — Hủy hàng WST-0001 | **Không làm** | Duy tự test trên điện thoại |

## Bối cảnh đầu vòng (từ rerun4, 16:45 15/11)

- Kho chính T047: NVL0388 **17 kg**, NVL0561 **188 cái**. Kho bếp (Demo): NVL0388 **2 kg**, NVL0561 **18 cái**. MINIBAR_MAIN: Tiger **9**, Diet Coke 9, Lavie 8, Coca-Cola 9, Larue 9, Sprite **4**, Rượu vang 2. Phòng 301–306: Sprite 1 lon/phòng. Phòng 101: Tiger 0.
- GRN-...-0002 (nháp của TEST03, PO-...-0001): **NHÁP, 0 dòng**. PO-...-0001: **ĐÃ NHẬN**. PO-...-0002: **NHÁP** (NVL0152 5 kg × 0 đ giá tay).
- TRF-...-0002: **NHÁP** (kho xuất sai: Kho chính T047, Tiger không có ở đó). PIS-...-0001: **NHÁP** (thiếu Trung tâm chi phí/Khoản mục). WST-...-0001: **NHÁP** (0 ảnh — Duy tự test).
- Hóa đơn C25TAA/0000124 (990.000 đ): **ĐÃ KHỚP**. Phiếu trả NCC SRT-...-0002: **Chờ xác nhận**. REQ-...-0002: **ĐÃ NHẬN**.
- Q285 đã sửa (commit 7e5ee66): form mở phiếu nhận mobile mặc định Kho chính (R4-N6); menu Kho dẫn tới màn mở được (R4-N5); phiếu xuất mục đích nháp thiếu cost center/khoản mục có cảnh báo "hủy và lập phiếu mới" (R4-N8). R4-N7 đúng thiết kế (bỏ qua). R4-N1 giữ nguyên. Không làm đường miễn ảnh cho hủy hàng. NVL0152: bỏ dòng.

## Y1 — TEST03 ghi dòng + ghi sổ phiếu nhận (không kiểm được, 22:05–22:08)

- **Đăng nhập mới sạch: CÓ.** Trình duyệt còn phiên test02; đã đăng xuất qua menu, gõ tay test03@erp.internal + mật khẩu; menu hiện "Test Storekeeper / test03@erp.internal" — đúng TEST03, phiên mới sạch.
- **GRN-...-0002: tìm thấy nhưng form từ chối tải.** Danh sách phiếu nhận → GRN-TEST47-LE-2611-0002 (PO-...-0001, NCC T047, Nháp, 13/11/2026, 0 dòng) → màn nhận hàng `/m/b0000000-.../receive/c67930e7-7989-44eb-8326-bfdf1bd47b85` báo nguyên văn: "Không thể tải dữ liệu / Chứng từ đang ở trạng thái không phù hợp với thao tác này." — lặp lại y hệt sau 1 lần tải lại. Không có nút "Ghi dòng", không nhập được dòng NVL0388 1 kg, không ghi sổ, không nhập PIN — dừng đúng hướng dẫn. Phiếu vẫn Nháp, 0 dòng.
- **Cả 2 lỗi quyền vòng trước đều KHÔNG xuất hiện lại** — nhưng do form không tải nên 2 quyền đó cũng chưa được kiểm chứng thực tế (chưa tới bước gọi quyền). **R4-N2 vẫn chưa verify, nhưng cũng không tái hiện.**
- **Kiểm chứng đối chứng:** GRN-...-0001 (cùng PO-...-0001, Nháp, 2 dòng) cũng bị từ chối với đúng thông báo trên. Ngược lại GRN-...-0017 (PO-...-0005, Nháp, 0 dòng) mở form bình thường cho TEST03 — đầy đủ Số cân/Bì/Số thực nhận, Chụp ảnh + ô tick miễn chụp, QC Đạt/Không đạt/Chờ quyết định, nút "Ghi dòng" và "Ghi sổ nhận hàng" (chỉ quan sát, không nhập/lưu gì). Mẫu này phù hợp giả thuyết: PO-...-0001 đã nhận đủ qua GRN-...-0016 (Đã ghi sổ, 15/11, 2 dòng) nên các phiếu nháp còn lại của nó không mở được nữa — nhưng thông báo app không ghi rõ "đơn đã nhận đủ", chỉ ghi chung "trạng thái không phù hợp".
- **Tồn không đổi:** Kho chính T047 NVL0388 **17 kg**, NVL0561 **188 cái** (TEST03 xem được số lượng; app chặn giá trị tiền: "Bạn chưa được cấp quyền xem giá trị tồn — chỉ hiện số lượng."). Không có thao tác ghi nào trong vòng này nên tồn không thay đổi — kỳ vọng Y2/Y4 vẫn giữ nguyên.
- **Quan sát R4-N6:** form nhận hàng (màn hiện trường) KHÔNG có ô "Kho nhận" — các trường chỉ gồm Số cân/Bì/Số thực nhận, Chụp ảnh + ô tick miễn chụp, QC, Số lượng hỏng, Nhiệt độ, "Ghi dòng", "Ghi sổ nhận hàng". Kho nhận được chọn ở bước "Mở phiếu nhận" (hộp thoại mở phiếu), không phải trên form dòng — nên Y6 phải kiểm kho mặc định ở bước mở phiếu, không phải ở form dòng.

## Y2 — Điều chuyển NVL0561 Kho bếp → Kho chính (đạt, 22:08–22:11)

- **Tồn trước (khớp kỳ vọng):** Kho bếp (Demo) NVL0561 18 cái; Kho chính T047 NVL0561 188 cái, NVL0388 17 kg; Kho bếp NVL0388 2 kg.
- **Phiếu mới TRF-TEST47-LE-2611-0010** (id `9ed90674-afb5-4d36-810a-f6af7e2e78fd`, ngày 15/11/2026): Kho xuất Kho bếp (Demo) → Kho nhập Kho chính T047, NVL0561 18 cái. Lập bằng `uat.storekeeper` (đăng xuất phiên test03 cũ, đăng nhập tay, menu xác nhận "UAT Thủ kho"). Form chọn kho phải dùng phím mũi tên (giá trị option không phải mã kho).
- **Chuyển:** nút "Chuyển hàng" → bảng xác nhận "Bánh bèo — SL thực tế 18" → "Xác nhận" → nguyên văn "Đã thực hiện."; trạng thái ĐANG CHUYỂN, Đã chuyển 18, Đã nhận 0. Không hỏi PIN.
- **Nhận:** cùng tài khoản thủ kho bấm "Xác nhận nhận hàng" → bảng xác nhận "Bánh bèo — SL thực tế 18" → "Xác nhận" → nguyên văn "Đã thực hiện."; trạng thái **ĐÃ NHẬN**, Đã chuyển 18, Đã nhận 18. Không cần đổi tài khoản, không hỏi PIN.
- **Tồn sau (đúng kỳ vọng):** Kho chính T047 NVL0561 **206 cái** (188+18); Kho bếp (Demo) NVL0561 **0 cái**; Kho chính NVL0388 17 kg không đổi; Kho bếp NVL0388 2 kg không đổi. R4-N6 coi như đã khắc phục xong ở mức tồn (18 cái về đúng kho chính).

## Y3 — TRF-0002 hủy + phiếu điều chuyển Tiger mới (đạt, 22:11–22:16)

- **Hủy TRF-...-0002: ĐẠT.** Phiếu ban đầu NHÁP (Kho chính T047 → Minibar phòng 101, Tiger 1 lon). Bấm "Hủy phiếu", nhập lý do bắt buộc "Kho xuất sai (Kho chính T047 không có Tiger) — hủy để lập phiếu mới từ Kho minibar tổng.", "Xác nhận" → trạng thái **ĐÃ HỦY** (kiểm lại trên danh sách). Không còn toast để trích nguyên văn ở bước này.
- **Phiếu mới TRF-TEST47-LE-2611-0011** (id `1a8f770a-e2e7-419f-95e2-2a9deadcf474`, ngày 15/11/2026): Kho xuất Kho minibar tổng (MINIBAR_MAIN) → Kho nhập Minibar phòng 101, Tiger (MB-TIGER) 1 lon, ban đầu NHÁP (Đã chuyển 0, Đã nhận 0). Chọn kho bằng phím mũi tên (13 lần xuống tới "Kho minibar tổng (MINIBAR_MAIN)", 5 lần tới "Minibar phòng 101 (MINIBAR_101)"); mặt hàng chọn từ gợi ý "MB-TIGER Tiger lon". "Lưu nháp" xong form ở lại trang lập phiếu, không thấy toast; phiếu xác nhận đã lưu qua danh sách (TRF-0011 ở đầu danh sách).
- **Chuyển:** "Chuyển hàng" → bảng xác nhận SL thực tế 1 lon → "Xác nhận" → nguyên văn "Đã thực hiện."; ĐANG CHUYỂN, Đã chuyển 1, Đã nhận 0. Không hỏi PIN.
- **Nhận:** cùng tài khoản thủ kho, nút "Xác nhận nhận hàng" hiện bình thường, không bị chặn → "Xác nhận" → **ĐÃ NHẬN**, Đã chuyển 1, Đã nhận 1. Không cần đổi sang `uat.hk_attendant`. Không hỏi PIN.
- **Tồn sau (đúng kỳ vọng, kiểm bằng `uat.gm`):** MINIBAR_MAIN Tiger **9 → 8 lon**; Minibar phòng 101 Tiger **0 → 1 lon** — xác nhận ở cả 2 nơi: màn minibar có thẻ "Phòng 101 · Tầng 1" ghi Tiger 1 lon; màn Tồn kho: "Kho minibar tổng | MB-TIGER | Tiger | lon | 8" và "Minibar phòng 101 | MB-TIGER | Tiger | lon | 1". R4-N9 đóng.

## Y4 — PIS-0001 hủy + phiếu xuất mục đích mới (đạt một phần, 22:16–22:21; bước đảo đang thử lại)

- **Bước 1 — Hủy PIS-...-0001: ĐẠT.** Trang phiếu nháp hiện cảnh báo nguyên văn (fix Q285 đã verify live): "Phiếu nháp này thiếu Trung tâm chi phí hoặc Khoản mục nên không ghi sổ được. Hãy hủy phiếu và lập phiếu mới có đủ hai trường này." Hủy với lý do "Phiếu tạo trước khi Trung tâm chi phí thành bắt buộc, không sửa được — hủy để lập phiếu mới." → **ĐÃ HỦY** (cảnh báo và các nút Ghi sổ/Hủy phiếu biến mất; danh sách xác nhận). R4-N8 đóng ở mức hiển thị.
- **Bước 2 — Phiếu mới PIS-TEST47-LE-2611-0002: ĐẠT.** Ban đầu NHÁP, ngày 15/11/2026, Kho Kho chính T047, mục đích "Ăn ca nhân viên", Trung tâm chi phí "Ẩm thực - Món ăn", Khoản mục "Chi phí test T047", 1 dòng NVL0388 1 kg. Không còn cảnh báo thiếu trường.
- **Bước 3 — Ghi sổ: ĐẠT.** Bấm "Ghi sổ" — không hỏi PIN, phiếu → **ĐÃ GHI SỔ**, đơn giá vốn 100.000 đ, thành tiền −100.000 đ. Tồn NVL0388 Kho chính T047: **17 → 16 kg** (giá trị tồn 1.700.000 → 1.600.000 đ), đúng kỳ vọng.
- **Bước 4 — Đảo phiếu: ĐẠT (bằng `uat.gm`, 22:24–22:25).** Đăng nhập tay `uat.gm@erp.internal` thành công (menu: "UAT Tổng quản lý", vai trò "Quản lý"). Trên chi tiết PIS-...-0002 (ĐÃ GHI SỔ), quản lý CÓ thấy nút "Đảo phiếu" (trang chỉ có 2 nút "← Quay lại" và "Đảo phiếu") — khác với thủ kho. Bấm "Đảo phiếu" → form lý do bắt buộc ("Lý do *", nút "Xác nhận" khóa tới khi nhập lý do) → nhập "Đảo phiếu test Y4 — kiểm tra bút toán đảo" → "Xác nhận" → phiếu **ĐÃ ĐẢO**, nút đảo biến mất. Không hỏi PIN, không có toast (bằng chứng là trạng thái + bút toán đảo trên thẻ kho).
- **Thẻ kho sau đảo:** Tồn đầu kỳ 0, Tổng nhập +21, Tổng xuất −4, Tồn cuối theo thẻ 17, Tồn sổ 17, "✓ Khớp với tồn sổ (17 = 17)". Dòng bút toán đảo (dòng cuối): 15/11/2026, PIS-...-0002, loại "Bút toán đảo", ghi chú "Đảo của bút toán #2548", Nhập 1, Xuất "—", Tồn sau 17. Dòng xuất gốc ngay trên: "Xuất mục đích", Xuất 1, Tồn sau 16. **NVL0388: 17 → 16 → 17 kg, đúng kỳ vọng toàn bộ. Y4 ĐẠT.** R5-N3 đóng: đảo phiếu là quyền quản lý theo thiết kế (thủ kho không thấy nút là đúng); brief Y4 ban đầu giao sai tài khoản ở bước đảo.

## Y5 — PO-0002 xóa dòng NVL0152 (đạt ở lần 2, 22:25–22:27)

- **Lần 1 (test02, 22:02–22:04): KHÔNG LÀM ĐƯỢC.** TEST02 ("Test Approver Receiver") không có quyền xem Đơn mua — danh sách PO báo "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này." Không dòng nào bị đổi. (Đường dẫn brief `/procurement/purchase-orders` cũng sai — đường dẫn thực tế là `/procurement/po`.)
- **Lần 2 (uat.storekeeper): ĐẠT.** Đăng nhập tay thủ kho (menu: "UAT Thủ kho"). Danh sách Đơn mua `/procurement/po` mở bình thường — thủ kho xem được (6 đơn). Dòng PO-...-0002: NCC T047, kênh "Hợp đồng", ngày đặt 13/11/2026, tổng 1.040.000 đ, 3 dòng, người tạo "Test Purchaser", NHÁP.
- **Trước khi xóa (chi tiết PO):** NHÁP, NCC T047 · Hợp đồng · Ngày đặt 13/11/2026 · Ngày dự kiến nhận 13/11/2026, tổng 1.040.000 đ. 3 dòng: NVL0388 10 kg × 100.000 đ (Giá trần) = 1.000.000 đ; NVL0561 8 cái × 5.000 đ (Giá trần) = 40.000 đ; NVL0152 [Giá tay] 5 kg × 0 đ = 0 đ. Cảnh báo nguyên văn: "Dòng giá tay cần nhập đơn giá và sẽ qua thêm một bước duyệt của quản lý." + "Còn dòng giá tay chưa nhập đơn giá." — nút "Gửi duyệt" bị vô hiệu.
- **Xóa:** bấm "Sửa nháp" (vào `/po/957f9448-007d-4f50-9200-f021066dfa0f/edit`) → bấm "Xóa dòng" của "Dòng 3 (Giá tay)" NVL0152 — không có hộp xác nhận, dòng biến mất ngay. Không chạm NVL0388/NVL0561, không sửa giá/số lượng. Bấm "Lưu nháp" → quay về trang chi tiết (không thấy toast).
- **Sau khi xóa (tải lại cả chi tiết + danh sách):** PO còn đúng 2 dòng nguyên vẹn (NVL0388 10 × 100.000 đ; NVL0561 8 × 5.000 đ); tổng vẫn 1.040.000 đ; vẫn NHÁP; danh sách hiển thị cột "DÒNG HÀNG" = 2 (trước là 3). Nút "Gửi duyệt" **ĐÃ BẬT** (ghi chú "Còn dòng giá tay chưa nhập đơn giá." đã biến mất) — chỉ quan sát, **KHÔNG bấm gửi duyệt**. R5-N1 đóng: xóa dòng PO nháp là việc của thủ kho (vai thu mua), TEST02 không có quyền xem PO là đúng phân quyền.

## Y6 — Menu Kho owner + form nhận mặc định Kho chính (đạt một phần, 22:27–22:30)

- **Phần A — Menu Kho của owner (`uat.owner`): 5/7 mục mở được.** Bấm "Kho" ở sidebar đáp tới mục đầu tiên là "Phiếu lĩnh" (`/inventory/requisitions`) — tức kỳ vọng Q285 "menu Kho dẫn tới màn đầu tiên người dùng mở được" **CHƯA đúng với owner**, vì màn đầu tiên này vẫn báo lỗi (xem R5-N5). Kết quả từng mục:
  - Phiếu lĩnh (`/inventory/requisitions`): **LỖI** — "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này."
  - Điều chuyển (`/inventory/transfers`): **MỞ ĐƯỢC** — màn "Phiếu điều chuyển", 11 phiếu.
  - Xuất mục đích (`/inventory/issues`): **MỞ ĐƯỢC** — màn "Phiếu xuất mục đích", 2 phiếu.
  - Hủy hàng (`/inventory/waste`): **MỞ ĐƯỢC** — màn "Phiếu hủy hàng", 1 phiếu.
  - Kiểm kê (`/inventory/counts`): **MỞ ĐƯỢC** — màn "Đợt kiểm kê", 5 đợt.
  - Tồn kho (`/inventory/stock`): **MỞ ĐƯỢC** — màn "Tồn kho", 29 dòng tồn.
  - Phiếu nhận (`/inventory/receipts`): **LỖI** — "Không thể tải dữ liệu / Bạn chưa được cấp quyền receiving.view để thực hiện thao tác này." (owner không có `receiving.view` — đúng thiết kế.)
  - Không bấm nút nào làm thay đổi dữ liệu trong các màn đã mở.
- **Phần B — Kho mặc định trên form mở phiếu nhận (`uat.receiver`): ĐẠT — R4-N6 đã verify live.** Màn nhận hàng mobile `/m/b0000000-.../receive` hiện "1 phiếu chờ nhận": NCC T047, PO-...-0005 · 1 dòng, ngày hẹn giao 14/11/2026. Bấm vào đơn mở hộp thoại "Mở phiếu nhận hàng" ("PO-...-0005 · NCC T047", "Chọn kho nhận rồi mở phiếu nháp cho đơn này."). Ô "Kho nhận" đang chọn sẵn **TRƯỚC KHI bấm xác nhận** là **"Kho chính T047 (KHO-T047)"** — không cần chọn tay, không còn mặc định Kho bếp như rerun4. Các lựa chọn khác: "Kho bếp (Demo) (KHO_BEP)", "Kho nhà hàng (Demo) (KHO_NH)", "Kho minibar tổng (MINIBAR_MAIN)"; ô "Nhận thẳng ra kho bếp" đang là "—". Đã bấm "Hủy" để đóng hộp thoại — KHÔNG bấm "Mở phiếu nhận", KHÔNG ghi dòng, KHÔNG ghi sổ; danh sách trở lại "1 phiếu chờ nhận" như ban đầu. (Hộp thoại chỉ hiện số PO, không hiện số phiếu nháp GRN-...-0017 nên không đối chiếu được số GRN từ đây.)

## Y7 — WST-0001 (không làm)

Duy tự test trên điện thoại thật (quyết định Q285: không làm đường miễn ảnh cho hủy hàng).

## Vấn đề mới

- **R5-N1 (Y5 — cần tài khoản đúng — ĐÃ XONG):** TEST02 ("Test Approver Receiver") không có quyền xem Đơn mua — duyệt PO qua hộp "Chờ tôi duyệt" được nhưng không mở được danh sách PO. Đã xóa dòng NVL0152 bằng `uat.storekeeper` ở lần 2. Đóng.
- **R5-N5 (Y6 — menu Kho của owner vẫn đáp xuống trang lỗi, Chuyển Claude Code):** bấm "Kho" ở sidebar đáp tới mục đầu tiên "Phiếu lĩnh" (`/inventory/requisitions`) và báo lỗi quyền — tức fix Q285 "menu Kho dẫn tới màn đầu tiên người dùng mở được" chưa đạt với owner (5/7 mục mở được: Điều chuyển, Xuất mục đích, Hủy hàng, Kiểm kê, Tồn kho; 2 mục lỗi quyền: Phiếu lĩnh, Phiếu nhận — lỗi quyền của 2 mục này là đúng thiết kế vì owner không có `requisition.view`/`receiving.view`, nhưng điểm đáp của menu Kho vẫn là trang lỗi). Cần Claude kiểm tra `resolveNavHref` với owner: hoặc đổi điểm đáp của menu Kho sang mục mở được đầu tiên (VD Điều chuyển), hoặc ẩn 2 mục không có quyền khỏi menu.
- **R5-N4 (Y4 — tài khoản quản lý là `uat.gm`, không phải `uat.manager`):** lần thử đảo bằng `uat.manager@erp.internal` rớt đăng nhập "Email hoặc mật khẩu không chính xác." — đối chiếu repo (ma trận quyền M9: `uat.gm | sm_manager`; demo-walkthrough ghi `uat.gm` là Quản lý) cho thấy tài khoản Quản lý là `uat.gm`, không có tài khoản `uat.manager` riêng. Đang thử lại bước đảo bằng `uat.gm`.
- **R5-N3 (Y4 — đảo phiếu là quyền quản lý, đang thử lại):** tài khoản thủ kho không thấy nút "Đảo phiếu" trên phiếu xuất mục đích đã ghi sổ (tìm toàn trang không có chữ "Đảo"); hướng dẫn trong app ghi đảo thuộc "QUẢN LÝ / NGƯỜI CÓ QUYỀN". Đang thử lại bằng quản lý (`uat.gm`) — nếu quản lý thấy nút và đảo được thì đây là đúng thiết kế (không phải lỗi), chỉ là brief Y4 giao sai tài khoản ở bước đảo.
- **R5-N2 (Y1 — phiếu nháp của PO đã nhận đủ không mở được form):** GRN-...-0002/0001 (PO-...-0001 đã nhận đủ qua GRN-...-0016) bị form từ chối với thông báo chung "Chứng từ đang ở trạng thái không phù hợp với thao tác này." — không nói rõ lý do (đã nhận đủ). Muốn kiểm thực quyền receiving.perform/post của TEST03 cần phiếu nháp thuộc PO chưa nhận đủ (VD GRN-...-0017 của PO-...-0005 mở form bình thường) — nhưng ghi dòng/ghi sổ trên phiếu đó sẽ làm thay đổi tồn PO-...-0005 nên cần Duy quyết trước khi làm.

## Chuyển Claude Code

- R5-N5: menu Kho của owner vẫn đáp xuống "Phiếu lĩnh" lỗi quyền — kiểm tra `resolveNavHref` với owner (đổi điểm đáp sang mục mở được đầu tiên hoặc ẩn mục không có quyền).
- R5-N2: Y1 chưa kiểm thực được quyền receiving.perform/post của TEST03 — phiếu nháp của PO đã nhận đủ không mở được form; cần phiếu của PO chưa nhận đủ (GRN-...-0017/PO-...-0005) nhưng việc đó làm thay đổi tồn nên cần Duy quyết trước (xem "Cần Duy quyết").

## Cần Duy quyết

- R5-N2: có cho TEST03 ghi thử 1 dòng + ghi sổ trên GRN-...-0017 (PO-...-0005, chưa nhận đủ) để kiểm thực quyền receiving.perform/post không? Làm vậy sẽ tăng tồn NVL0561 (PO-...-0005 còn 1 dòng chưa nhận) — cần Duy gật trước.
- PO-...-0002 đã đủ điều kiện gửi duyệt (2 dòng, không còn dòng giá tay, nút "Gửi duyệt" đã bật) — gửi duyệt hay để nháp?
- R4-N3 (từ rerun4, vẫn mở): có cấp `stock.view_qty` cho kế toán không (kế toán hiện không xem được `/inventory/stock`)?
- R4-N1/R4-N7 đã đóng theo Q285 (giữ `po.approve` ở sm_owner; trang người dùng chỉ thấy owner là đúng thiết kế). Không làm đường miễn ảnh cho hủy hàng (Q285).

## Số liệu cuối (tính tới 22:30, 15/11/2026 — rerun5 xong Y1–Y6; Y7 Duy tự làm)

- CNT-...-0005: **ĐÃ ĐIỀU CHỈNH**. CNT-...-0004: **ĐÃ HỦY**.
- NVL0388: Kho chính T047 **17 kg**, Kho bếp (Demo) **2 kg**. NVL0561: Kho chính T047 **206 cái**, Kho bếp (Demo) **0 cái**.
- MINIBAR_MAIN: Tiger **8**, Diet Coke 9, Lavie 8, Coca-Cola 9, Larue 9, Sprite **4**, Rượu vang 2. Phòng 101: Tiger **1 lon**. Phòng 301–306: Sprite 1 lon/phòng.
- Hóa đơn: C25TAA/0000123 **ĐÃ HỦY**; C25TAA/0000124 (990.000 đ) **ĐÃ KHỚP**. Phiếu trả NCC SRT-...-0002: **Chờ xác nhận**.
- GRN-...-0009, GRN-...-0014, GRN-...-0016: **ĐÃ GHI SỔ**. GRN-...-0001, GRN-...-0002: **NHÁP** (0/2 dòng — phiếu của PO-...-0001 đã nhận đủ, form không mở được). GRN-...-0017 (PO-...-0005): **NHÁP**, 0 dòng.
- REQ-...-0002: **ĐÃ NHẬN**. TRF-...-0002: **ĐÃ HỦY**. TRF-...-0010: **ĐÃ NHẬN** (18/18). TRF-...-0011: **ĐÃ NHẬN** (1/1). PIS-...-0001: **ĐÃ HỦY**. PIS-...-0002: **ĐÃ ĐẢO**. WST-...-0001: **NHÁP** (0 ảnh — Duy tự test trên điện thoại).
- MB-0001 (Đã thu 140.000 đ), MB-0002 (Đã kiểm, 0 đ) không đổi. MB-...-0008 không tồn tại (R3-N3 đã đóng).
- PO-...-0001: **ĐÃ NHẬN**. PO-...-0002: **NHÁP** (2 dòng, nút "Gửi duyệt" đã bật — chưa bấm). PO-...-0005: còn 1 phiếu chờ nhận (GRN-...-0017). MON01 chưa import (Q168).

## Việc bỏ qua / chưa làm

- Y7: WST-...-0001 để nguyên — Duy tự test trên điện thoại thật (Q285: không làm đường miễn ảnh cho hủy hàng).
- Y1: quyền receiving.perform/post của TEST03 chưa kiểm thực được (form từ chối tải phiếu của PO đã nhận đủ) — xem R5-N2 / "Cần Duy quyết".
- PO-...-0002 chưa gửi duyệt (theo lệnh Y5: không gửi duyệt).
