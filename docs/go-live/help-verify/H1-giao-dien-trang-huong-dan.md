# H1 — Giao diện trang Hướng dẫn (desktop) (14/11/2026)

- Khách sạn: TEST47. Nhánh: `feat/muse-help` (từ main `cf08c19`, gồm Q279 + Q280 + Q281).
- Báo cáo này không ghi mật khẩu/PIN.
- Task trình duyệt cloud: chạy 16:20–16:25 (5 phút), 3 tài khoản (owner, purchaser, hk_attendant). Bổ sung: kiểm chứng bằng code/seed (đối chiếu số bài "Dành cho bạn" với quyền thật), kiểm khổ 390 px bằng Playwright (5 trang), chụp ảnh sơ đồ để tự kiểm L2–L4.

## Kết luận: ĐẠT MỘT PHẦN

| Hạng mục | Kết quả |
|---|---|
| Trang `/help` tải được (3 vai trò) | Đạt |
| Tìm kiếm không dấu, nhiều từ | Đạt (có kết quả cả 3 từ khóa), nhưng thứ tự chưa tối ưu (H1-N5) |
| 5 tab loại, đủ 45 bài (8+10+6+8+13) | Đạt (tab không hiện số bài) |
| "Dành cho bạn" đúng theo vai trò | KHÔNG ĐẠT với owner (45/45 — H1-N1); Đạt với purchaser (17) và hk_attendant (7, trừ 1 bài thiếu đã sửa) |
| Mở 12 bài (mỗi loại ≥ 2) | Đạt — tiêu đề, bảng, bước, ô ghi chú đều đúng |
| Nút "Mở màn hình" (thử 4 nút) | Đạt — đúng trang, đúng TEST47, không 404 |
| Liên kết "Bài liên quan" (thử 2), nút quay lại | Đạt |
| Khổ desktop 1919 px | Đạt — không tràn ngang, bảng vừa khung |
| Khổ 390 px | Đạt — không tràn ngang (Playwright, 5 trang); 4 nút icon shell < 44 px (ghi chú) |
| Module tắt | Không kiểm được live (cấm bật/tắt module) — chỉ xác nhận từ code + test |

## Bước 1 — "Dành cho bạn"

- **owner: 45/45 bài đều có nhãn** — gồm cả các bài rõ ràng không thuộc việc Chủ đầu tư (Người nhận hàng, Bếp & Nhà hàng, Buồng phòng, Lễ tân, SOP-01/02/03/05/06, Nhận hàng mù, Dung sai, Ảnh bằng chứng, Giá vốn…). Nhãn mất tác dụng lọc.
- **purchaser: 17 bài** — khớp đúng 9 bài kỳ vọng, không thiếu, không có bài nào rõ ràng không liên quan (Tài chính/Danh mục chỉ liên quan gián tiếp).
- **hk_attendant: 7 bài** — 5/6 bài kỳ vọng có; THIẾU bài quy tắc "Minibar: tính tiền, miễn và đối soát" (xem H1-N2, đã sửa); gián tiếp: Danh mục, Nhận hàng mù và đếm mù.

## Bước 2 — Tìm kiếm (tài khoản owner)

- "nhan hang mu": 7 kết quả (Người nhận hàng; Nhận hàng; Mua hàng → Nhận hàng → Hóa đơn → Thanh toán; Lĩnh kho…; SOP-01; Nhận hàng mù và đếm mù; Giá vốn…). 2 kết quả cuối khớp lỏng.
- "kiem ke": 6 kết quả. Thứ tự chưa tối ưu: "Thu mua & Thủ kho" (chỉ nhắc kiểm kê trong mô tả) xếp trên bài "Kiểm kê" (khớp tiêu đề).
- "hoa don": 9 kết quả. Thứ tự chưa tối ưu: 2 bài vai trò (Quản lý, Kế toán) xếp trên "Tài chính" và bài luồng có "Hóa đơn" trong tiêu đề; "Kiểm kê tháng"/SOP-02 khớp rất lỏng.
- Trang không hiển thị số lượng kết quả.

## Bước 3 — 5 tab loại

- Tất cả 45; Theo vai trò 8; Theo phân hệ 10; Luồng nghiệp vụ 6; Quy trình SOP 8; Quy tắc nghiệp vụ 13 (8+10+6+8+13=45). Đều bấm được. Tab không hiển thị số bài — phải tự đếm thẻ.

## Bước 4 — Mở 12 bài

Đã mở đủ 12 bài bắt buộc (mỗi loại ≥ 2) + 2 bài thêm qua liên kết liên quan. Tiêu đề đều đúng.

| Bài | Sơ đồ | Bảng | Bước | Ghi chú | Liên quan |
|---|---|---|---|---|---|
| vai-tro-chu-dau-tu | 2 sơ đồ, đọc được | Không có | 1–4 rõ | Có | 4 |
| vai-tro-thu-mua-thu-kho | 2 sơ đồ, đọc được | Không có | 1–4 (Mua hàng), 1–5 (Kho) | Không có ô riêng | 4 |
| vai-tro-ke-toan | 2 sơ đồ, đọc được | Không có | 1–6 rõ | Không có ô riêng | 4 |
| phan-he-thu-mua | 1 sơ đồ, đọc được | 6 dòng × 3 cột đúng | Không có | Không có | 4 |
| phan-he-bao-cao-canh-bao | Không có | Không có | Không có | Có (xanh) | 3 |
| phan-he-kho | 2 sơ đồ, đọc được | 4 dòng × 3 cột đúng | Không có | Không có | 4 |
| luong-mua-hang-nhan-thanh-toan | 3 giai đoạn, đọc được | 13 dòng × 5 cột đúng | Không có | Không có | 5 |
| luong-minibar-tinh-tien | Đọc được, nút cuối chật (H1-N3) | 8 dòng × 4 cột đúng | Không có | Có (vàng) | 3 |
| sop-nhan-hang-mu | Chỉ hiện "Giai đoạn 2" (H1-N4) | Không có | 1–8 rõ, kèm nhãn vai trò | Không có | 4 |
| sop-kiem-ke-cuoi-thang | 2 sơ đồ, đọc được | Không có | 1–8 rõ, kèm nhãn vai trò | Không có | 4 |
| quy-tac-dung-sai-can-lai | Nhãn cạnh bị cắt (H1-N2) | Không có | Không có | Có (xanh) | 3 |
| quy-tac-doi-chieu-3-ben | Chỉ hiện "Giai đoạn 3" (H1-N4) | Không có | Không có | Có (xanh) | 3 |

- Liên kết "Bài liên quan": bấm thử 2, đều mở đúng bài đích ("Tách biệt nhiệm vụ" từ bài Chủ đầu tư; "Minibar: tính tiền, miễn và đối soát" từ bài Luồng Minibar). Nút "Tất cả hướng dẫn" bấm 2 lần đều về đúng danh sách `/help`.
- Nút "Mở màn hình" (bấm thử 4, đều đúng TEST47, không 404): bài Chủ đầu tư bước Cảnh báo → `/alerts` (10 cảnh báo chưa xử lý); bài Thu mua & Thủ kho bước Lập yêu cầu mua → `/procurement/pr` (7 PR); bài Kế toán bước Nhập hóa đơn → `/finance/invoices` (2 hóa đơn); SOP-02 bước Mở đợt → `/inventory/counts/new` (form tải bình thường, không tạo/sửa gì).
- Lưu ý: điều hướng trong app chậm ~1 giây sau khi bấm (lần đầu tưởng như không phản hồi); sau khi quay lại bằng nút trình duyệt, trang giữ vị trí cuộn cũ nên phần đầu sơ đồ có thể bị cắt ở mép trên khung nhìn — không phải lỗi nội dung.

## Bước 5 — Khung hiển thị

- Desktop 1919×998: không tràn ngang, không có thanh cuộn ngang; bảng 13 dòng × 5 cột vừa khung; nút/tab/thẻ đủ lớn để bấm.
- 390 px (Playwright, tự kiểm — trình duyệt cloud không thu hẹp được): 5 trang (`/help`, SOP-01, luồng mua hàng, quy tắc dung sai, vai trò Chủ đầu tư) đều `scrollWidth == innerWidth == 390`, **không tràn ngang**. Mỗi trang có 4 nút < 44×44 px trong khung nhìn đầu trang — đều là nút icon của khung shell chung (menu/chuông/"?"/tài khoản), không phải nút của trang help.

## Bước 6 — Module

- Không bật/tắt module, không vào trang quản trị module. Các bài thuộc phân hệ Nhà hàng và Buồng phòng & Minibar đều đang hiển thị trong danh sách; menu trái cũng có Nhà hàng, Minibar — Lễ tân, Minibar — Buồng phòng, Ca xe đẩy, Tiêu chuẩn phòng. Phù hợp với việc cả hai module đang bật ở TEST47.
- Ẩn bài khi module tắt: chỉ xác nhận từ code (`visibleArticles` trong `src/features/help/lib.ts`: bài `module !== "core"` chỉ hiện khi module đó bật) và test `help-content` (có test ẩn bài theo module) — chưa kiểm live vì cấm bật/tắt module.

## Lỗi / bất thường

1. **H1-N1 [P1 — cá nhân hóa] Owner thấy "Dành cho bạn" trên cả 45 bài.** Nguyên nhân đã kiểm chứng bằng code + probe admin (chỉ đọc `/admin/users` + `/access`): tài khoản uat.owner giữ vai trò `owner` cũ, trên production vai trò này đã được cấp tay 109 quyền (ghi trong migration `20261109150000_master_data_role_permissions.sql`) và hiện có **129 quyền hiệu lực**, tất cả đều "Được cấp", hết hạn 2026-11-26; không có ghi đè quyền riêng. Logic "Dành cho bạn" (`article.perms.some(p => userPerms.has(p))` trong `src/features/help/lib.ts`) bản thân đúng — đối chiếu từ seed: purchaser khớp đúng 17/45, hk_attendant khớp đúng 7/45 như agent báo; chỉ owner khớp 45/45 vì tập quyền quá rộng. Hệ quả: nhãn mất tác dụng với owner, và thứ tự tìm kiếm của owner cũng bị ảnh hưởng (xếp theo loại, không theo độ khớp tiêu đề). Hướng sửa (chuyển Claude Code, cần Duy quyết hướng): thu hẹp quyền vai trò `owner` cũ (vai trò UAT hết hạn 2026-11-26), hoặc đổi luật "Dành cho bạn" thành xếp hạng theo số quyền khớp / ưu tiên khớp tiêu đề thay vì nhãn nhị phân.
2. **H1-N2 [P3 — nội dung, ĐÃ SỬA] hk_attendant thiếu nhãn "Dành cho bạn" ở bài quy tắc Minibar đối soát.** Nguyên nhân: `perms` của bài `quy-tac-minibar-doi-soat` chỉ có `minibar.charge.confirm`, `minibar.waive.approve`, `minibar.reconcile` — hk_attendant chỉ có `minibar.check`. Đã sửa: thêm `minibar.check` vào `perms` của bài (commit `eae02c5`, test help-content 13/13 xanh). Bài này thuộc việc buồng phòng (người kiểm minibar) nên gắn là đúng.
3. **H1-N3 [P2 — hiển thị sơ đồ] Nhãn cạnh sơ đồ dung sai bị cắt; sơ đồ minibar tràn mép phải.** Tự kiểm bằng ảnh chụp màn hình 1280 px: bài `quy-tac-dung-sai-can-lai` — nhãn "Trong dung sai" bị cắt sau nút quyết định (chỉ còn mảnh chữ sau nút "Nhận đủ"), nhãn "Thừa" bị cắt ở mép hình thoi; bài `luong-minibar-tinh-tien` (và `quy-tac-minibar-doi-soat` dùng chung sơ đồ) — sơ đồ tràn ra ngoài mép phải khung nhìn, nút cuối "Bấm Đã thu + số folio / Xuất kho phòng, ghi doanh thu" và nhãn "Phát hiện muộn" bị cắt mất một phần. (Chữ "kh…"/"hi…" trong báo cáo agent là đọc nhầm; lỗi cắt nhãn là thật.)
4. **H1-N4 [P3 — nội dung sơ đồ] Tiêu đề sơ đồ "Giai đoạn 2/3" gây hiểu lầm khi đứng một mình.** Sơ đồ `NHAN` ("Giai đoạn 2 — Nhận hàng mù") và `THANH_TOAN` ("Giai đoạn 3 — Hóa đơn → Thanh toán") được dùng chung: trong bài luồng 3 giai đoạn thì đúng, nhưng bài `sop-nhan-hang-mu` chỉ hiện mỗi sơ đồ NHAN (tiêu đề "Giai đoạn 2" mà không có Giai đoạn 1) và bài `quy-tac-doi-chieu-3-ben` chỉ hiện mỗi THANH_TOAN ("Giai đoạn 3" mà không có Giai đoạn 1–2). Đã xác nhận từ `src/i18n/help/diagrams.ts` (`HELP_DIAGRAMS`) + ảnh chụp. Hướng sửa: tiêu đề sơ đồ theo từng bài (không đánh số giai đoạn khi đứng một mình), hoặc đổi tên sơ đồ dùng chung thành tên không có số giai đoạn.
5. **H1-N5 [P3 — tìm kiếm] Thứ tự kết quả chưa ưu tiên khớp tiêu đề; không hiện số lượng.** `filterListItems` xếp bài "Dành cho bạn" trước rồi theo thứ tự loại (vai trò → phân hệ → luồng → SOP → quy tắc), không có điểm cộng khi từ khóa khớp tiêu đề. Với owner (45/45 đều "Dành cho bạn") thứ tự thành xếp theo loại: "Thu mua & Thủ kho" (chỉ nhắc kiểm kê trong mô tả) lên trên "Kiểm kê"; "Quản lý"/"Kế toán" lên trên "Tài chính" và bài luồng có "Hóa đơn" trong tiêu đề. Trang cũng không hiển thị số kết quả; tab loại không hiển thị số bài.

## Ghi chú khác

- Số bài trên tab phải tự đếm (không có con số trên tab).
- 4 nút icon shell < 44 px ở 390 px là nút khung chung, không phải lỗi của trang help — ghi nhận để Claude xem có cần chuẩn 44 px cho khung mobile không.
