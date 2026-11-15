# Báo cáo kiểm chứng rerun3 — ERP_hotel (15/11/2026)

> Nhánh `feat/muse-rerun3` từ `main` c91ec58 (Q284). Chạy tuần tự, một mình, chỉ giao diện web, tài khoản `uat.*`/TEST, khách sạn TEST47 (`b0000000-0000-4000-8000-000000000002`). Không supabase/migration/vercel/RPC/SQL trực tiếp; không đổi cấu hình/tài khoản/PIN/khóa kỳ; không ghi mật khẩu/PIN vào file/log.

## Kết quả tổng

| Task | Kết quả | Commit / ghi chú |
|---|---|---|
| X1 — Hoàn tất kiểm kê CNT-0005 | **Không đạt** (chặn ở khóa đợt) | Xem R3-N1 (P0). Q282 đã có hiệu lực phần xem chênh lệch |
| X2 — GRN-0009 + hủy hóa đơn C25TAA/0000123 | **Chưa kiểm được** (chờ X1 mở khóa đóng băng) | Kho KHO-T047 vẫn đóng băng |
| X3 — Minibar | **Đạt một phần** | GRN-0011 + tồn kho + báo cáo khớp; cấp bù theo tầng không làm được (R3-N2); MB-0008 mất dấu (R3-N3) |
| X4 — Chứng từ kho trọn vòng | **Chưa kiểm được** (chờ X1 mở khóa đóng băng) | REQ-0002/TRF-0002/PIS-0001/WST-0001 chưa chạy |
| X5 — Đối chiếu 10 bài hướng dẫn mới | **Đạt một phần** | 7 lỗi nội dung đã sửa, commit `T-X51` (414ef15); SOP-13 không sửa bài (lỗi gán vai, R3-N2) |

## X1 — Kiểm kê CNT-0005 (không đạt)

- Đợt CNT-TEST47-LE-2611-0005 (`c8e54061-4627-47a2-8061-3fefa1608c8e`, kho KHO-T047, kiểm kê tháng, ngày 14/11/2026): trạng thái **CHỜ DUYỆT** — đã nộp từ vòng trước, không cần nộp lại, không nhập PIN, không yêu cầu đếm lần 2 ở bước này. Chi tiết đợt ghi "8 người đếm".
- **Q282 đã có hiệu lực (đã xác minh):** `uat.accountant` THẤY bảng chênh lệch và dòng đỏ NVL0388 — ba chỉ nách: đếm lần 1 = 9, đếm lần 2 = 9, số đếm = 9, số sổ = 10, chênh lệch = -1, % lệch = -10%, trạng thái dòng "Chênh lệch". Không còn câu "Bạn chưa được cấp quyền xem chênh lệch". Có ô "Mã lý do *" (Mất, Hỏng, Hết hạn, Trộm cắp, Đếm sai, NCC giao thiếu, Khác) và ô "Giải thích". Hướng dẫn trên màn: "Nhập lý do cho từng dòng chênh lệch (đỏ) trước khi khóa. Dòng không có lý do sẽ bị chặn."
- **Chặn ở khóa đợt (R3-N1):** thử khóa 4 lần, đều thất bại với cùng thông báo nguyên văn (đỏ, dưới ô Giải thích): "Vui lòng nhập lý do cho thao tác này." — lần 1 mã "Khác" + giải thích đầy đủ; lần 2 gõ lại giải thích; lần 3 đổi mã "Mất"; lần 4 tải lại trang rồi chọn lại "Khác" + giải thích. Sau các lần bấm, đợt vẫn CHỜ DUYỆT, cột "MÃ LÝ DO" và "GIẢI THÍCH" trong bảng vẫn "—" (lý do chưa được ghi nhận).
- Chưa làm được (phụ thuộc khóa đợt): GM duyệt điều chỉnh; tồn NVL0388 về 9 kg; thử đếm trên đợt đã khóa; hủy/đóng CNT-0004 (đang ĐANG MỞ, 0 dòng); thử mở đợt mới cùng kho; thử xuất kho xác nhận hết đóng băng; kiểm người đếm mù; kiểm hộp "Chờ tôi duyệt" của `uat.owner`.
- Kho KHO-T047 vẫn đóng băng.

## X2 — Chưa kiểm được

Chờ X1: GRN-...-0009 chỉ ghi sổ được sau khi kho hết đóng băng. Hóa đơn C25TAA/0000123 (Tạm giữ) + nút "Hủy hóa đơn" (Q284) chưa thử.

## X3 — Minibar (đạt một phần)

- **GRN-...-0011: Đạt.** Trạng thái ĐÃ GHI SỔ (xác nhận ở danh sách và chi tiết phiếu). PO-...-0006 ĐÃ NHẬN 1.180.000 đ, đã nhận đủ 10/10/10/10/10/10/2. Lưu ý: phiếu đã ghi sổ không hiện lại dòng hàng/kho nhận với người nhận (màn ghi "Đã ghi sổ — Sau khi ghi sổ, người nhận không xem lại được phiếu này." — đúng quy tắc mù). Kho nhận suy ra từ tồn kho: MINIBAR_MAIN có đúng 7 món — Tiger 9, Diet Coke 9, Lavie 8, Coca-Cola 9, Larue 9, Sprite 10, Rượu vang 2 (tổng 1.099.000 đ), khớp tuyệt đối với số nhận trừ 6 món đã bán theo MB-0001 (Tiger 1, Diet Coke 1, Lavie 2, Coca-Cola 1, Larue 1).
- **Bổ sung theo tầng: Không đạt (R3-N2).** Khối "Bổ sung theo tầng" không xuất hiện ở cả `uat.hk_attendant` lẫn `uat.gm` (tìm "Bổ sung" toàn trang, đã cuộn hết). Không thực hiện cấp bù nào. Nhân viên buồng phòng còn thấy cảnh báo: "Bạn chưa có quyền xem số lượng tồn (stock.view_qty) nên màn này không hiển thị tồn kho phòng. Nhờ quản trị cấp quyền xem tồn cho kho phòng để xem được." Màn GM hiện: "Tồn minibar từng phòng: Không có tồn minibar ở phòng nào.", Bảng giá, Đối soát ngày, Thu hồi sắp hết hạn (trống), Báo cáo 01→15/11.
- **MB-0001: Đạt một phần.** Phiếu đã thu từ vòng trước nên không còn trong danh sách lễ tân (danh sách chỉ còn MB-...-0002, phòng 104, Chờ thu tiền, 0 đ, không dòng thiếu). Số tiền 140.000 đ được xác nhận gián tiếp qua báo cáo (xem dưới). Folio TEST-M5-1311 không thấy ở màn nào đã mở.
- **MB-0008: Không kiểm được (R3-N3).** Không tìm thấy ở danh sách lễ tân lẫn báo cáo minibar (Chờ thu 0 đ). Xem R3-N3.
- **Báo cáo minibar 01–14/11/2026 (`/reports/minibar`): Đạt.** Doanh thu 140.000 đ, Giá vốn 81.000 đ, Lãi gộp 59.000 đ; Ghi nhận 140.000 đ, Đã thu 140.000 đ, Miễn thu 0 đ, Thu muộn 0 đ, Chờ thu 0 đ, Chờ thu quá kỳ 0 đ, Chênh lệch đối soát 0 đ. Theo món: Tiger 1×35.000 đ (vốn 20.000 đ), Lavie 2×30.000 đ (vốn 16.000 đ), Diet Coke 1×25.000 đ (15.000 đ), Coca-Cola 1×25.000 đ (15.000 đ), Larue 1×25.000 đ (15.000 đ); không có Sprite/Rượu vang. Đã thu 140.000 đ KHỚP MB-0001. Lavie đã bán 2 chai/30.000 đ; Đêm phòng (có phiếu đã thu) 1; Lavie/đêm phòng 2.
- Lưu ý thêm: tài khoản lễ tân mở `/housekeeping/minibar` báo "Không tìm thấy trang" (trang thuộc phạm vi buồng phòng, không phải lỗi chặn quyền hiển thị rõ) — xem R3-N4.

## X4 — Chưa kiểm được

Chờ X1 (kho đóng băng): REQ-...-0002 (xuất → xác nhận nhận), TRF-...-0002, PIS-...-0001 (Trung tâm chi phí + khoản mục → ghi sổ → đảo), WST-...-0001 (ảnh bắt buộc) chưa chạy.

## X5 — Hướng dẫn mới (đạt một phần)

Đối chiếu 10 bài với màn thật (đăng nhập tay từng tài khoản, chỉ xem — không tạo/sửa chứng từ; đã bấm Hủy ở hộp thoại mở phiếu nhận để không tạo phiếu nháp). Tổng 55 thẻ bài trong Trợ giúp.

**Đã sửa 7 lỗi nội dung — commit `T-X51` (414ef15), gate `pnpm lint && pnpm typecheck && pnpm test` xanh (308/308):**

| Bài | Lỗi đã sửa | Căn cứ code |
|---|---|---|
| SOP-09 Ủy quyền | Nút nộp form là "Thêm ủy quyền" (chỉ khi sửa mới hiện "Lưu ủy quyền") | `approval-delegations-editor.tsx:223`, `vi.admin.configDelegationAdd/Save` |
| SOP-10 Mật khẩu/PIN | Nút "Đặt lại PIN" nằm ở trang Quyền truy cập (qua nút "Quản lý quyền truy cập" trên trang người dùng), bài ghi thiếu bước này | `pin-reset-button.tsx` (`vi.admin.resetPin`), `admin/users/[id]/access/page.tsx:91-92` |
| SOP-11 File POS | Quyền nạp POS chỉ có sm_manager + sm_accountant (Quản lý/Kế toán), không phải thủ kho/bếp như bài ghi | `20261109570000_compact_role_profiles.sql:140,204`; nav `inventory-nav.tsx:99` (gated `pos.import`) |
| SOP-14 Nhập Excel | Quyền nhập danh mục chỉ có sm_manager + sm_accountant, không phải Thủ kho/Thu mua | Cùng seed `:131,196` |
| Quy tắc foodcost | "Thêm giá trần" do Kế toán làm, không phải Thu mua | `price.ceiling.manage` chỉ có sm_accountant/chief_accountant/cost_controller (seed `:205`, `572000:182,198`) |
| Quy tắc hợp đồng khung | Thêm chú thích vai trò ở dòng Giá trần (Kế toán/Kiểm soát chi phí) | Cùng seed trên |
| SOP-15 Bảng kê | Form "Nhập bảng kê mới" hiện sẵn trên trang (không có nút bấm); sau khi Lưu không có thông báo "Đã lưu bảng kê" (`listingSaved` có trong `vi.ts` nhưng không chỗ nào dùng — form chỉ `router.refresh()`); bảng kê mới ở trạng thái Nháp | `no-invoice-listings/page.tsx:32`, `no-invoice-form.tsx` (nút `vi.common.save`), `vi.ts:2927` |

**Hai "lỗi" agent báo nhưng đối chiếu code thấy KHÔNG phải lỗi (không sửa):**
- Đường dẫn gốc `/settings/password`, `/admin/approval-rules` trong bài là ĐÚNG — đây là route quản trị, không gắn mã khách sạn; gắn mã vào thì 404 là đúng thiết kế.
- "Dành cho bạn" của `uat.owner` = 23 bài trên 55: badge chạy theo quyền (`isRelevant`: `article.perms` giao với quyền người dùng, `src/features/help/lib.ts`), không theo tên vai. Owner trùng quyền duyệt với GM/Kế toán nên các bài đó gắn nhãn là đúng thiết kế; bài "Hợp đồng khung" không gắn nhãn là đúng vì owner không có `price.agreement.manage`/`price.ceiling.manage`. Không còn bài thao tác tay nào gắn nhãn cho owner.
- SOP-15: câu "Đã duyệt bảng kê" trong bài là ĐÚNG (`listingApproved` hiện sau khi duyệt, `no-invoice-list.tsx:60`); chỉ bước 2–3 sai.

**Chưa kiểm được (cần chạy thật):** dấu hiệu offline khi mất mạng; "Được ủy quyền từ…" trong Chờ tôi duyệt; Sửa/Xóa ủy quyền; Duyệt đổi STK/Từ chối đổi STK (tài khoản Vietcombank 0000000001 của SUP0001 đang "Chờ duyệt" nhưng cột Thao tác trống với tài khoản Thu mua — đúng SoD, người đề xuất không tự duyệt); trạng thái "Đã thu hồi" của tài khoản cũ; hậu quả 30 ngày thêm bước duyệt Chủ đầu tư; Thẩm định/Phê duyệt/Từ chối NCC; công thức foodcost với món đủ giá trần (không món nào tính được); trạng thái hợp đồng, "Thêm dòng giá", ngưỡng Cảnh báo/Khóa vượt %.

**SOP-13 không sửa bài:** xem R3-N2.

## Lỗi mới

### R3-N1 — P0 — Lỗi RPC/giao diện: khóa đợt kiểm kê không bao giờ chạy được
- **Hiện tượng:** `count_lock` luôn trả `ERR_REASON_REQUIRED` ("Vui lòng nhập lý do cho thao tác này.") dù đã nhập đủ mã lý do + giải thích (4 lần thử, 2 mã lý do khác nhau).
- **Gốc (đã đối chiếu code):** `lockCountAction` (`src/features/count/actions.ts:154-160`) gửi `p_reasons` với khóa camelCase `{ lineId, reasonCode, explanation }` (theo `countLockReasonSchema`, `src/features/count/schemas.ts:68-76`); RPC `count_lock` (`supabase/migrations/20261109280000_stocktake.sql:1221-1222`) đọc khóa snake_case `v_reason ->> 'line_id'` / `->> 'reason_code'` — cả hai đều NULL nên RPC báo thiếu lý do (dòng 1224-1226). `callCountRpc` (`src/features/count/rpc.ts`) không chuyển khóa. pgTAP đậu vì test gọi RPC trực tiếp bằng snake_case. Nói cách khác: khóa đợt qua giao diện **chưa bao giờ chạy được** — các vòng trước tưởng chỉ kẹt ở quyền xem chênh lệch, thực ra còn kẹt thêm lớp này.
- **Hướng sửa:** ở `lockCountAction`, map `p_reasons` sang `{ line_id, reason_code, explanation }` trước khi gọi RPC — không cần migration. Nên rà các action khác gửi JSONB object có khóa camelCase nhiều từ sang RPC (riêng `count_record_line` an toàn vì `qty`/`uom` một từ).
- **Tác động:** chặn toàn bộ X1 (khóa → duyệt điều chỉnh → tồn NVL0388 về 9 kg), và chặn X2 + X4 vì kho KHO-T047 vẫn đóng băng.

### R3-N2 — P1 — Quyền: `uat.hk_attendant` không có `minibar.refill`
- **Hiện tượng:** khối "Bổ sung theo tầng" (form `office-refill-form.tsx`, tiêu đề "Bổ sung minibar"/"Bổ sung theo tầng", nút "Bổ sung") không hiện với `uat.hk_attendant` lẫn `uat.gm` trên `/housekeeping/minibar`.
- **Đối chiếu code:** khối chỉ render khi `perms.canRefill` = có quyền `minibar.refill` (`minibar/page.tsx:116`, `features/minibar/queries.ts:187`). Seed cấp `minibar.refill` cho `sm_housekeeping` và `hk_supervisor` — GM (sm_manager) không có là đúng thiết kế. Nhưng `uat.hk_attendant` cũng không thấy khối, tức tài khoản UAT này thực tế không có quyền đó (dù vai Buồng phòng theo mapping compact là `sm_housekeeping`).
- **Hướng xử lý:** kiểm tra gán vai cho `uat.hk_attendant` (phải là `sm_housekeeping`); nếu cố ý không giao cho nhân viên buồng phòng thì SOP-13 phải ghi đúng vai làm cấp bù (vd. hk_supervisor/thủ kho). Bài SOP-13 không sai về tính năng nên không sửa bài.

### R3-N3 — P2 — Dữ liệu: MB-...-0008 (125.000 đ) mất dấu
- Vòng trước (14/11 ~16:59) quan sát được MB-...-0008 "Chờ thu tiền · 125.000 đ" trên danh sách lễ tân. Vòng này: không có trong danh sách lễ tân (chỉ còn MB-...-0002, 0 đ), không có trong báo cáo minibar 01–14/11 (Chờ thu 0 đ). Không xác nhận được nó đã được thu/hủy hay thuộc phạm vi khác. Cần kiểm tra dữ liệu (người thu/hủy, thời điểm, folio/phòng).

### R3-N4 — P3 — UI: trang ngoài phạm vi vai trò báo 404 chung chung
- Tài khoản lễ tân mở `/housekeeping/minibar` nhận "Không tìm thấy trang — Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn." thay vì thông báo thiếu quyền. Nhỏ, để backlog.

## Chuyển Claude Code
1. **R3-N1 (P0):** sửa `lockCountAction` map khóa `p_reasons` sang snake_case (xem trên). Sau khi deploy, chạy lại X1 từ bước khóa đợt.
2. **R3-N2 (P1):** kiểm tra gán vai/quyền cho `uat.hk_attendant` (`minibar.refill`); xác nhận vai làm cấp bù minibar.
3. **R3-N3 (P2):** truy vết MB-...-0008 (125.000 đ) — đã thu/hủy hay thuộc phạm vi khác.
4. Rà các action gửi JSONB object sang RPC có khóa camelCase nhiều từ (họ lỗi R3-N1).
5. R3-N4 (P3, backlog): thông báo thiếu quyền rõ ràng thay vì 404 chung chung ở trang ngoài phạm vi vai trò.

## Cần Duy quyết
- **Giá NVL0152 (BA CHỈ XÔNG KHÓI) cho PO-...-0002** — vẫn là nút chặn Ngày 1 đợt test 30 ngày (hỏi 13/11, chưa trả lời): cho giá tay (đ/kg) hay bỏ dòng.
- **MB-...-0008 (R3-N3):** Duy có thu/hủy phiếu này sau 14/11 16:59 không, hay phiếu thuộc phạm vi khác?
- **Phân quyền nạp POS / nhập Excel / giá trần:** hiện tại chỉ Quản lý/Kế toán (POS, Excel) và Kế toán/Kiểm soát chi phí (giá trần). Bài hướng dẫn đã sửa theo đúng phân quyền hiện hành. Nếu Duy muốn Thủ kho/Bếp/Thu mua cũng làm được thì đó là đổi seed phân quyền, không phải sửa bài.
- **Vai làm cấp bù minibar (R3-N2):** nhân viên buồng phòng hay quản lý buồng phòng/thủ kho?
- Còn mở từ các vòng trước: hướng sửa H1-N1 (đã xử lý Q283, còn kiểm "Dành cho bạn" — vòng này xác nhận 23 bài, đúng thiết kế); đường sửa hóa đơn Tạm giữ (nay có nút Hủy hóa đơn Q284 — chờ X2 kiểm sau khi mở khóa).

## Số liệu cuối (đã xác minh vòng này; mục ghi "vòng trước" chưa kiểm lại)
- **CNT-...-0005:** CHỜ DUYỆT — NVL0388 đếm 9 / sổ 10 / lệch -1 (-10%), dòng đỏ, chưa có lý do. **CNT-...-0004:** ĐANG MỞ, 0 dòng. KHO-T047 vẫn đóng băng.
- **MINIBAR_MAIN:** Tiger 9, Diet Coke 9, Lavie 8, Coca-Cola 9, Larue 9, Sprite 10, Rượu vang 2 — tổng 1.099.000 đ.
- **GRN-...-0011:** ĐÃ GHI SỔ. **PO-...-0006:** ĐÃ NHẬN, 1.180.000 đ.
- **Báo cáo minibar 01–14/11/2026:** Doanh thu 140.000 đ, Giá vốn 81.000 đ, Lãi gộp 59.000 đ, Đã thu 140.000 đ, Chờ thu 0 đ. MB-...-0002: Chờ thu 0 đ (phòng 104). MB-...-0001: đã thu 140.000 đ (xác nhận qua báo cáo). MB-...-0008: mất dấu.
- **Trợ giúp:** 55 bài; "Dành cho bạn" của `uat.owner`: 23 bài.
- **KHO-T047 (vòng trước, chưa kiểm lại):** NVL0388 sổ 10 kg, NVL0561 0. GRN-...-0009 (PO-...-0005, 180 đã ghi, cân lần 2 xong) chờ ghi sổ sau khi hết đóng băng. Hóa đơn C25TAA/0000123 Tạm giữ. PO-...-0004 (0 đ) chờ duyệt bước Quản lý.

## Lệnh đã chạy + kết quả thật
- `git fetch origin && git checkout main && git pull --ff-only` — main từ cf08c19 lên **c91ec58** (Q282, Q283, Q284 + merge Help H1–H5).
- `git checkout -b feat/muse-rerun3` — nhánh mới từ c91ec58.
- Browser task X1 (cloud, 09:27–09:29): bước 0 đạt, bước 1 chặn (R3-N1), bước 2–6 chưa làm.
- Browser task X5 (cloud, 09:31–09:40): đối chiếu 10 bài xong.
- `pnpm lint && pnpm typecheck && pnpm test` — xanh, **308/308 test đậu**.
- `git commit T-X51` (414ef15): sửa 7 lỗi nội dung `src/i18n/help/extra.ts`.
- Browser task X3 (cloud, 09:41–09:48): GRN-0011 + tồn + báo cáo khớp; cấp bù theo tầng không có ở cả 2 vai; MB-0008 mất dấu.
- Báo cáo này: `docs/go-live/muse-report-rerun3.md` (commit T-R3).

## Việc bỏ dở và vì sao
- **X1 bước 2–6:** chặn bởi R3-N1 (khóa đợt lỗi). Chạy lại sau khi Claude sửa + deploy.
- **X2, X4:** chặn bởi kho KHO-T047 đóng băng (hệ quả R3-N1). Chạy lại sau X1.
- **X3 cấp bù theo tầng:** chặn bởi R3-N2 (thiếu quyền `minibar.refill` ở tài khoản kiểm). Chạy lại sau khi gán vai đúng.
- **X5 các mục "chưa kiểm được":** cần chạy thật (tạo ủy quyền, đổi STK, mất mạng thật, món đủ giá trần, hợp đồng khung có dữ liệu) — để vòng sau hoặc Duy quyết có cần kiểm không.
- **SOP-13:** không sửa bài vì bài đúng, lỗi ở gán vai.

## Phản hồi của Claude Code (15/11/2026)

- **R3-N1 (đã sửa, chưa deploy):** `lockCountAction` map `p_reasons` sang `{ line_id, reason_code, explanation }`; thêm Vitest `tests/unit/count-lock-action.test.ts`. Đã rà các action khác truyền mảng/đối tượng sang RPC: finance/minibar/procurement/receiving/trolley đều map tường minh, `pos-import` đã dùng snake_case sẵn — không còn chỗ nào cùng họ lỗi. pgTAP `stocktake_test.sql` 103/103 (RPC không đổi). Cần deploy rồi chạy lại X1 từ bước khóa đợt, sau đó X2/X4.
- **R3-N2 (có migration, chưa áp dụng):** `uat.hk_attendant` chỉ có vai cũ `hk_attendant` (không có `minibar.refill`); `uat.hk_supervisor` có thêm `sm_housekeeping`. Migration `20261109590000_uat_hk_attendant_sm_housekeeping.sql` gán thêm `sm_housekeeping` cho tài khoản UAT này (idempotent, chỉ tác động `uat.hk_attendant@erp.internal`). `uat.gm` không có `minibar.refill` là đúng thiết kế.
- **R3-N3 (kết luận: không có dữ liệu mất):** trên prod chỉ tồn tại 2 phiếu minibar của TEST47 là MB-0001 (đã thu 140.000 đ lúc 14/11 16:12 giờ VN) và MB-0002 (0 đ, chờ thu); `audit_log` không có bản ghi nào của phiếu 0008 và không có DELETE. Phiếu 0008 chưa từng được tạo — quan sát "MB-0008 · 125.000 đ" ở vòng trước là đọc nhầm (sau 16:12 MB-0001 đã thu nên không thể còn "chờ thu"). Không cần xử lý dữ liệu.
