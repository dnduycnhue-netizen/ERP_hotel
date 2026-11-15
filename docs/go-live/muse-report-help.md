# Báo cáo vòng Help — kiểm tra Trung tâm Trợ giúp trong app (H1–H5)

- Ngày: 14/11/2026
- Nhánh: `feat/muse-help` (từ main `cf08c19`, 12 commit)
- Phạm vi: chỉ giao diện + nội dung bài hướng dẫn trong app (`src/i18n/help/*`, trang `/help`, nút "?" theo màn hình, bản mobile). Không migration, không Supabase, không Vercel, không RPC/SQL trực tiếp, không đổi cấu hình/quyền/tài khoản/PIN.
- Môi trường kiểm: app live https://erphotel.vercel.app, khách sạn TEST47, tài khoản uat.*/TEST + admin dnduy@hueic.edu.vn. Chỉ xem/đọc, không bấm Duyệt/Nộp/Khóa/Ghi sổ/Gửi.
- Kết quả chung: **H1–H5 xong. 45 bài đều tải được; 12 lỗi nội dung đã sửa (gate xanh từng commit); 2 lỗi nội dung nhỏ đã sửa ở H1–H2; 13 lỗi giao diện cho Claude; 10 bài còn thiếu đã đề xuất (không viết mới).**

## 1. Bảng tổng kết H1–H5

| Nhiệm vụ | Kết quả | Báo cáo | Commit sửa nội dung |
|---|---|---|---|
| H1 — Giao diện trang Hướng dẫn | Đạt một phần | `docs/go-live/help-verify/H1-giao-dien-trang-huong-dan.md` | `eae02c5` T-H01a (thêm `minibar.check` vào quy-tắc minibar đối soát để buồng phòng thấy "Dành cho bạn") |
| H2 — Nút "?" theo màn hình | Đạt một phần | `docs/go-live/help-verify/H2-nut-hoi-theo-man-hinh.md` | `e530b16` T-H02a (bỏ bài phân quyền khỏi gợi ý mục Danh mục) |
| H3 — Bản mobile | Đạt một phần | `docs/go-live/help-verify/H3-ban-mobile.md` | — (chỉ ghi lỗi, không sửa nội dung) |
| H4 — Nội dung vs hệ thống thật | Đạt một phần | `docs/go-live/help-verify/H4-noi-dung-vs-he-thong-that.md` | `9e88fab` T-H04a, `e32994a` T-H04b, `e903ee1` T-H04c, `5f59344` T-H04d, `4af7d3f` T-H04e |
| H5 — Bài còn thiếu | Xong (10 đề xuất) | `docs/go-live/help-verify/H5-bai-con-thieu.md` | — (không viết bài mới) |

## 2. Lỗi nội dung đã sửa (12 lỗi, H4 + 2 lỗi H1–H2)

### H4 — đối chiếu SOP-01..05, luồng, quy tắc, vai trò (10 lỗi, xem chi tiết ở báo cáo H4)
1. SOP-01 bước 2 + bài Người nhận hàng: "cân cả bì" → trường thật **"Số cân"** (hệ thống tự tính Số cân − Bì).
2. SOP-01 bước 4: bảng kiểm QC chỉ "nếu có cho nhóm hàng" (2 nhóm kiểm tra không có mẫu checklist).
3. SOP-01 bước 1: thêm lựa chọn **Nhận thẳng ra kho bếp** và **Xếp hàng gửi sau (offline)**.
4. SOP-02 + luồng Kiểm kê tháng: thứ tự thật là **Khóa đợt trước, duyệt điều chỉnh sau** (bài cũ viết ngược); controls "Hai người đếm độc lập" → "Ít nhất một người đếm độc lập"; nút thật "Mở đợt kiểm kê".
5. SOP-03 + bài Quản lý + phân hệ Kho: phiếu hủy giá trị lớn **chỉ có một bước duyệt (Quản lý)** — không có bước thứ hai.
6. SOP-04 bước 2: hóa đơn Tạm giữ **không sửa trực tiếp được** (không có nút Sửa) — chỉ bấm Khớp 3 chiều để đối chiếu lại.
7. SOP-04 bước 3 + luồng mua hàng bước 10: duyệt hóa đơn là **Quản lý hoặc Kế toán trưởng chuỗi** (cả hai đều có quyền `invoice.approve`).
8. SOP-04 bước 4: tài khoản nhận **lấy theo tài khoản mặc định của NCC**, không chọn tay trên form.
9. SOP-04 bước 5 + luồng mua hàng bước 12 + bài Kế toán: duyệt thanh toán **mặc định 1 bước Kế toán trưởng chuỗi**; NCC vừa đổi tài khoản ngân hàng trong 30 ngày thì **thêm bước duyệt Chủ đầu tư**; người duyệt không được là người lập hóa đơn hay người yêu cầu đổi tài khoản. (Lưu ý: commit T-H04b của tau sửa thiếu — bỏ mất phần "thêm bước Chủ đầu tư"; T-H04e đã sửa lại cho đủ.)
10. Phân hệ Báo cáo: "12 báo cáo" → **"11 báo cáo"**; quy tắc dung sai: **một mức chung cho khách sạn, không theo nhóm hàng**; nút "Lập phiếu trả hàng NCC" nằm **ở trang Trả hàng NCC trên máy tính** (không phải "mở màn trên điện thoại").

### H1–H2 (2 lỗi)
11. H1-N2: bài quy tắc minibar đối soát thiếu quyền `minibar.check` nên buồng phòng không thấy bài trong "Dành cho bạn" — đã thêm.
12. H2: gợi ý ở mục Danh mục chứa bài phân quyền (thuộc Quản trị, không liên quan vật tư) — đã bỏ.

## 3. Lỗi giao diện cho Claude (không sửa trong vòng Help)

| Mã | Mức | Vấn đề | Nguồn |
|---|---|---|---|
| H4-N1 (= X1-N1) | P0 | **Bế tắc khóa đợt kiểm kê**: kế toán có `count.lock` nhưng không có `count.view_variance` nên không thấy dòng đỏ/lý do để khóa; GM thấy chênh lệch nhưng không có nút duyệt điều chỉnh trên đợt CHỜ DUYỆT. CNT-0005 kẹt, KHO-T047 vẫn đóng băng — chặn X2/X4. | H4b + X1 |
| H1-N1 | P1 | Owner "Dành cho bạn" hiện 45/45 bài (vai trò owner cũ = siêu vai trò, 129 quyền gán tay trên production, hết hạn 26/11/2026). Hướng sửa chưa chốt: thu hẹp quyền owner cũ hay siết xếp hạng "Dành cho bạn". | H1 |
| H1-N3 | P2 | Sơ đồ DUNG_SAI bị cắt nhãn cạnh; sơ đồ MINIBAR tràn khung chứa. | H1 (ảnh chụp Playwright) |
| H1-N4 | P3 | Tiêu đề chung "Giai đoạn 2/3" gây khó hiểu khi sơ đồ đứng riêng trong bài. | H1 |
| H1-N5 | P3 | Tìm kiếm xếp theo loại bài trước, không theo độ khớp tiêu đề; không hiện số kết quả. | H1 |
| H2-N1 | P2 | Gợi ý ở Báo cáo + Chờ duyệt lệch (ghi trong báo cáo H2). | H2 |
| H3-N1 | P2 | Người nhận hàng không có nav dưới trên mobile. | H3 |
| H3-N2 | P3 | Đường dẫn `/m/<property>/` trần trả 404 (thiếu page.tsx). | H3 |
| H3-N3 | P3 | Sơ đồ bị cắt trên mobile. | H3 |
| H4-N2 | P2 | Trang "Chờ tôi duyệt" hiện đơn PO-0004 (0 đ, đang ở bước Quản lý) cho cả Chủ đầu tư kèm nút Duyệt/Từ chối — trái thiết kế 2 bước. | H4c |
| H4-N3 | P3 | Trang Minibar — Lễ tân mâu thuẫn: vừa cảnh báo "chưa giao phòng cho khách mới: 104" vừa ghi "Hệ thống không chặn giao phòng mới". | H4c |
| H4-N4 | P3 | Menu trái của thu mua lúc mới đăng nhập thoáng hiện 17 mục giống chủ đầu tư rồi mới còn 7 mục. | H4c |
| H4-N5 | P3 | Form nhập hóa đơn: lần chọn NCC đầu, đơn mua hiện ra nhưng không chọn được ngay (phải chọn lại). | H4c |
| H4-N6 | P3 | Nhãn "Cost center" trên form xuất mục đích chưa dịch sang tiếng Việt. | H4b |
| H4-N7 (= X1-N2) | P2 | Form mở đợt kiểm kê tự mâu thuẫn: "ít nhất 2 người đếm độc lập" vs "ít nhất một người đếm độc lập". | H4b + X1 |
| H4-N8 | P3 | Kho mặc định khi mở form kiểm kê là "Kho chờ hủy (DISPOSAL)". | H4b |

## 4. Bài còn thiếu — 10 đề xuất (chi tiết ở báo cáo H5)

Ưu tiên viết trước: (1) Ủy quyền duyệt khi vắng mặt — tính năng có, hướng dẫn 0 lần nhắc; (2) Đổi mật khẩu/PIN của chính mình; (3) Nạp file POS; (4) Quản lý NCC + đổi tài khoản ngân hàng. Tiếp theo: (5) Làm việc khi mất mạng; (6) Cấp bù minibar cho phòng; (7) Giá vốn món ăn (foodcost); (8) Nhập danh mục bằng Excel; (9) Hợp đồng khung và báo giá; (10) Bảng kê không hóa đơn.

## 5. Cần Duy/Claude xác nhận

1. **H1-N1** — hướng sửa: thu hẹp quyền của vai trò owner cũ hay siết xếp hạng "Dành cho bạn"?
2. **Đường sửa hóa đơn Tạm giữ** — không có nút sửa trực tiếp; khi số liệu sai thì lập hóa đơn mới thay thế hay có đường sửa khác?
3. **H4-N2** — chủ đầu tư thấy đơn bước 1 là lỗi hiển thị cần sửa, hay thiết kế cho phép duyệt thay trong trường hợp khẩn? (RPC hiện chặn bằng `ERR_NOT_APPROVER`.)
4. **X1-N1 (H4-N1)** — hướng sửa do Claude quyết; đang chặn X2/X4 và kiểm kê tháng 11.
5. **Ai xem phiếu trả hàng NCC** — GM + người nhận hiện bị chặn xem (ghi trong báo cáo H1–H3, chờ Duy quyết).
6. **H5** — Duy có muốn tau/Claude viết 10 bài đề xuất không, theo thứ tự ưu tiên nào? (Vòng này chỉ đề xuất, chưa viết.)

## 6. Tác dụng phụ

- H4a mở hộp thoại nhận hàng tạo 2 phiếu nhận nháp trống GRN-TEST47-LE-2611-0014 (PO-0005) và 0015 (PO-0001) — cùng hành vi đã biết ở X3-N2. Không ảnh hưởng dữ liệu khác.
- Không thay đổi nào khác trên hệ thống; không migration, không db push, không deploy.

## 7. Lệnh cho Duy (merge nhánh này)

```zsh
cd ~/Documents/code/mini-erp-ks
git fetch origin
git checkout main
git merge --no-ff feat/muse-help -m "Help H1-H5: doi chieu noi dung + sua 12 loi bai huong dan"
git push origin main
vercel --prod
```

Không cần `supabase db push` (vòng này không có migration). Sau deploy, kiểm tra nhanh trang `/help` và một bài đã sửa (VD SOP-02).

## 8. Việc chưa xong (ngoài vòng Help)

- X2/X4 vẫn chặn ở X1-N1 (khóa đợt kiểm kê) — chờ Claude sửa + deploy rồi chạy tiếp.
- Đợt test vận hành 30 ngày, ngày 1 vẫn kẹt ở giá NVL0152 — chờ Duy chốt cho giá hay bỏ dòng.
- Q233 việc 2+3 (RPC `po_set_expected_date` + write guard) — chỉ làm khi Duy yêu cầu; cần rebase sang migration 586000+.
