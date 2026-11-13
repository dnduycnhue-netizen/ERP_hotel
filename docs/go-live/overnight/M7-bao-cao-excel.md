# M7 — Thử nghiệm Báo cáo + Cảnh báo + Xuất Excel

- Ngày: 14/11/2026, 00:12–00:19 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.owner, uat.gm, uat.accountant (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Đạt một phần — 12/12 báo cáo tải được, bộ lọc ngày đúng, nhưng XUẤT EXCEL HỎNG TOÀN DIỆN (không tải được file nào), 11 phát hiện.**
- Commit: `T-M7` (xem git log).

## 1. Danh sách 12 báo cáo (owner, /reports — đủ 12 mục, đều tải được)

| # | Báo cáo | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | Báo cáo vận hành (tổng quan /reports, 11 thẻ) | Tải được | GM thấy đủ 12 mục nhưng thẻ GM KHÔNG hiện số liệu tóm tắt như owner (xem F-9) |
| 2 | Thẻ kho (/reports/stock-card) | TRỐNG | 0 dòng, tồn cuối 0 đ, nhập 0 đ, xuất 0 đ; mặc định 01/11–14/11/2026; KHÔNG có nút Xuất Excel |
| 3 | Chất lượng nhận hàng (/reports/receiving-quality) | TRỐNG | 0 phiếu, tỉ lệ kiểm tra 0,00%, tỉ lệ lỗi 0,00%; CÓ nút Xuất Excel (nhưng lỗi 500 — F-2) |
| 4 | Đơn mua mở & hóa đơn treo (/reports/open-po-invoice) | CÓ DỮ LIỆU | 2 đơn mở · còn lại 2.040.000 đ; PO-...-0001 (NCC T047, 12/11, gửi 1.040.000 đ, đã nhận 0 đ, còn lại 1.040.000 đ, quá hạn 2 ngày); PO-...-0003 (An Phát, 13/11, gửi 1.000.000 đ, còn lại 1.000.000 đ, quá hạn 1 ngày); Hóa đơn treo 0 · 0 đ; "Tính đến ngày" 14/11/2026; CÓ nút Xuất Excel (bị chặn khóa sổ — F-1) |
| 5 | Tuổi nợ & dòng tiền chi (/reports/ap-aging) | TRỐNG | Toàn 0 đ; Tính đến ngày 14/11/2026; CÓ nút Xuất Excel (bị chặn khóa sổ — F-1) |
| 6 | Tạm ứng chưa quyết toán (/reports/advances) | TRỐNG | 0 tạm ứng, 0 đ, 0 quá hạn; CÓ nút Xuất Excel (bị chặn khóa sổ — F-1) |
| 7 | Hủy hàng (/reports/waste) | TRỐNG | 0 chứng từ, 0 đ, % doanh thu —; ghi chú KHÔNG DẤU: "% doanh thu theo spec can du lieu POS (pos_sales_lines) chua tich hop (Q34); tam tinh % theo gia tri nhap kho cung ky."; CÓ nút Xuất Excel (lỗi 500 — F-2) |
| 8 | Chi phí vận hành (/reports/opex) | TRỐNG | Tháng 11/2026, Tổng 0 đ, Đêm phòng bán 0, CPOR —; KHÔNG có nút Xuất Excel |
| 9 | Minibar (/reports/minibar) | CÓ DỮ LIỆU LỆCH | Ghi nhận 140.000 đ, Chờ thu 140.000 đ, Chênh lệch đối soát 140.000 đ, nhưng Doanh thu 0 đ, Giá vốn 0 đ, Lãi gộp 0 đ, Đã thu 0 đ, cả 5 món đều SL bán 0, Doanh thu 0 đ (xem F-5); KHÔNG có nút Xuất Excel |
| 10 | Amenities — chi phí/đêm phòng (/reports/amenity-cpor) | TRỐNG | Tháng 11/2026, Tổng 0 đ, Đêm phòng bán 0, Chi phí/đêm —; KHÔNG có nút Xuất Excel |
| 11 | Doanh thu F&B (/reports/fnb-revenue) | CÓ DỮ LIỆU | Doanh thu 145.000 đ, Giá vốn 0 đ, Lãi gộp 0 đ, Biên lãi —; ALA-02 Tôm Chiên Giòn SL 1, 145.000 đ, Giá vốn —, Lãi gộp —; Buffet (theo khách) SL 1, 0 đ; KHÔNG có nút Xuất Excel |
| 12 | Bản tin 8h (/reports/daily-brief) | Tải được | Ngày 14/11/2026; Chi mua hôm qua 0 đ, Giá trị hủy hôm qua 0 đ, Cảnh báo đỏ chưa xử lý 8, Công nợ đến hạn 7 ngày 0 đ, Tạm ứng quá hạn 0; "Không có cảnh báo đỏ trong 24 giờ qua.", "Không có hợp đồng NCC sắp hết hạn trong 7 ngày.", "Không có kỳ nào chưa nghiệm thu."; KHÔNG có nút Xuất Excel |

Lưu ý: /reports/amenities trả 404 (đường dẫn đúng là /reports/amenity-cpor).

## 2. Bộ lọc ngày (owner) — Đạt

- Doanh thu F&B: mặc định 01/11–14/11/2026 → 145.000 đ. Chỉ ngày 13/11/2026 → vẫn 145.000 đ (khớp: doanh thu phát sinh ngày 13/11). 01/01–31/01/2026 → 0 đ, bảng chỉ còn dòng "—" (trống, không có dòng chữ "Không có dữ liệu").
- Minibar: chỉ 13/11/2026 → vẫn Ghi nhận/Chờ thu/Chênh lệch 140.000 đ, món bán 0. 01/01–31/01/2026 → toàn 0 đ. Khoản 140.000 đ gắn với ngày 13/11/2026, bộ lọc có tác dụng — nhưng đối soát lệch (F-5).
- Múi giờ VN: Bản tin 8h ghi "Ngày 14/11/2026" lúc kiểm thử 00:12–00:19 ngày 14/11 giờ +07; doanh thu 13/11 hiện đúng khi lọc 13/11 ("hôm qua" theo giờ VN). Ô ngày là ô chọn ngày chuẩn (bấm từng phần Ngày/Tháng/Năm rồi gõ số).

## 3. Xuất Excel — KHÔNG TẢI ĐƯỢC FILE NÀO (owner)

- Chỉ **5/11** báo cáo chi tiết có nút "Xuất Excel" (Chất lượng nhận hàng, Đơn mua mở, Tuổi nợ, Tạm ứng, Hủy hàng). **6 báo cáo còn lại KHÔNG có nút xuất**, gồm cả Doanh thu F&B (báo cáo có dữ liệu chính) — F-3.
- Đã thử cả 5 nút:
  - Đơn mua mở, Tuổi nợ, Tạm ứng → JSON lỗi `ERR_EXPORT_NOT_LOCKED`: "Khoảng ngày yêu cầu chứa dữ liệu chưa khóa sổ (01/11/2026 … và 4 ngày khác). Hãy khóa sổ kỳ kế toán hoặc ngày nghiệp vụ rồi xuất lại, hoặc thu hẹp khoảng ngày." — thử lại với 01/01–31/01/2026 (không dữ liệu) cũng bị chặn tương tự → **thực tế không xuất được với bất kỳ khoảng nào khi chưa có ngày nào được khóa sổ** (F-1).
  - Chất lượng nhận hàng (thử 2 lần) và Hủy hàng (1 lần) → trang "HTTP ERROR 500", không file (F-2).
- Vì không tải được file xlsx nào nên **KHÔNG kiểm tra được tên cột, dấu tiếng Việt, tiền là số hay chữ trong file** — mục này của M7 chưa hoàn thành, cần làm lại sau khi F-1/F-2 được sửa.
- Lưu ý thêm: (i) nút "Xuất Excel" điều hướng luôn tab hiện tại sang URL API (mất trang báo cáo, phải bấm Back) — F-10; (ii) mọi URL xuất dùng `entity=b0000000-0000-4000-8000-000000000001` trong khi UUID khách sạn trên URL trang là …0002 — chưa xác định là ID pháp nhân khác hay sai thực thể, cần đội dev xác nhận (ghi nhận, không kết luận lỗi).

## 4. Trang Cảnh báo (/alerts, owner) — Đạt, có bất thường

- Tải được. Ghi chú: "Cảnh báo do hệ thống tạo (mức đỏ/vàng/xanh). Gửi tức thời qua email / web push theo quy tắc alert_rules; cảnh báo thường trong giờ im lặng 23:00–06:00 được dồn vào bản tin 8h." và "Cấu hình gửi báo cáo (email / web push): Chưa cấu hình khóa Web Push (NEXT_PUBLIC_VAPID_PUBLIC_KEY). Liên hệ quản trị viên."
- Tổng 11 cảnh báo: **9 ĐỎ** (đều mã PERMISSION_CRITICAL_CHANGED, "Gán vai trò có quyền mức quan trọng", ngày 12-11, "Đã gửi 08:00 13-11"; 1 dòng "Đã xử lý", 8 dòng còn nút "Đã xử lý") + **2 XANH** (MINIBAR_CHECK_REQUESTED: "Yêu cầu kiểm minibar phòng 104" lúc 22:47 13-11 và phòng 101 lúc 18:15 13-11, cả 2 "Chưa gửi", còn nút "Đã xử lý") + 0 VÀNG. Chuông hiển thị "10" chưa xử lý (khớp: 8 đỏ + 2 xanh).
- Bấm tiêu đề 1 cảnh báo ("Yêu cầu kiểm minibar phòng 104") thì KHÔNG đi đâu — dòng cảnh báo không phải liên kết, không có trang chi tiết; thao tác duy nhất là nút "Đã xử lý" (không bấm, vì là nút đổi trạng thái).
- Bất thường (F-6): 9 cảnh báo đỏ trùng lặp hoàn toàn (giờ 21:19 12-11 xuất hiện 2 lần, 21:11 12-11 xuất hiện 7 lần); cột "Trạng thái gửi" ghi "Đã gửi 08:00 13-11" nhưng mục "Lịch sử gửi" ghi "Chưa có tin nào được gửi." — mâu thuẫn.

## 5. Kiểm tra thêm — nút tạo phiếu ở 3 trang kho (owner + GM)

- **Owner:** /inventory/requisitions — KHÔNG có nút tạo mới (chỉ bộ lọc trạng thái + tìm kiếm); 1 phiếu REQ-...-0001. /inventory/transfers — KHÔNG có nút tạo mới; "0 phiếu điều chuyển". /inventory/waste — KHÔNG có nút tạo mới; "0 phiếu hủy hàng".
- **GM:** /inventory/requisitions — KHÔNG có nút tạo mới (xem được cùng 1 phiếu). /inventory/transfers — **BỊ CHẶN QUYỀN**: "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này." (tải lại vẫn vậy; mục "Điều chuyển" cũng không xuất hiện trong menu Kho của GM). /inventory/waste — KHÔNG có nút tạo mới, "0 phiếu hủy hàng".
- **Kết luận đối chiếu (F-8):** nút tạo phiếu vắng mặt với cả owner lẫn GM — giống hệt 3 tài khoản ở M6. Việc thiếu nút tạo KHÔNG phải do phân quyền theo vai trò quản lý/chủ đầu tư; tính năng tạo phiếu chưa có trên cả 3 trang với mọi vai trò đã kiểm tra (5 vai trò). Cần Duy xác nhận thiết kế (tạo phiếu ở đâu, hay phiếu chỉ sinh tự động).

## 6. Trường hợp biên

- **a. Ngày kết thúc trước ngày bắt đầu (F-4):** F&B, Từ 13/11/2026 – Đến 01/11/2026 (?from=2026-11-13&to=2026-11-01): app KHÔNG báo lỗi, vẫn hiện doanh thu 145.000 đ như khi lọc đúng ngày 13/11 — khoảng ngày ngược được chấp nhận ngầm và vẫn trả dữ liệu.
- **b. Accountant mở /reports:** chỉ thấy 2 báo cáo — "Tuổi nợ & dòng tiền chi" và "Chi phí vận hành". KHÔNG xuất hiện dòng "Đã xảy ra lỗi khi tải dữ liệu..." và cũng KHÔNG có câu "Bạn chưa được cấp quyền xem báo cáo nào." (đã tìm chuỗi "lỗi" trên toàn trang, không có kết quả). Mở cả 2 đều tải được (Tuổi nợ toàn 0 đ, có nút Xuất Excel; Chi phí vận hành tháng 11/2026, Tổng 0 đ, CPOR —, bảng trống). **Đối chiếu M9:** dòng lỗi kép trên /reports chỉ xuất hiện với tài khoản KHÔNG có quyền xem báo cáo nào (purchaser/chef/hk_supervisor) — accountant có 2 báo cáo nên không gặp. Ghi nhận để sửa cho đúng nhóm đối tượng.
- **c. Báo cáo module tắt:** KHÔNG test được (cả 2 module đang bật, cấm tắt trên production).

## 7. Phát hiện (tổng 11)

- **F-1. [Nghiêm trọng] Xuất Excel bị chặn khóa sổ với mọi khoảng ngày.** `ERR_EXPORT_NOT_LOCKED` — ngay cả tháng không dữ liệu cũng bị chặn vì chưa ngày nào được khóa sổ. Thực tế không xuất được file khi chưa khóa sổ. Chuyển Claude Code (xem lại quy tắc: khoảng không có dữ liệu có nên đòi khóa sổ không; hoặc cho xuất khi chưa khóa sổ kèm cảnh báo).
- **F-2. [Nghiêm trọng] Xuất Excel lỗi HTTP 500.** Chất lượng nhận hàng (tái hiện 2/2 lần) và Hủy hàng (1 lần). Chuyển Claude Code.
- **F-3. [Thiếu] 6/11 báo cáo chi tiết không có nút Xuất Excel**, gồm cả Doanh thu F&B. Chuyển Claude Code/Duy xác nhận danh sách báo cáo cần xuất.
- **F-4. [Lỗi] Khoảng ngày ngược không báo lỗi mà vẫn trả dữ liệu.** F&B 13/11→01/11 vẫn hiện 145.000 đ.
- **F-5. [Sai số liệu] Minibar đối soát lệch:** Ghi nhận 140.000 đ / Chờ thu 140.000 đ / Chênh lệch đối soát 140.000 đ trong khi Doanh thu 0 đ và mọi món bán 0. Liên quan M5 B1 (thu tiền kẹt "Không đủ tồn kho để xuất") — có thể cùng gốc: phiếu kiểm đã ghi nhận tiền nhưng chưa thành doanh thu vì chưa thu được. Chuyển Claude Code kiểm tra nguồn số liệu đối soát.
- **F-6. [Dữ liệu] Cảnh báo đỏ trùng lặp (9 dòng giống hệt nhau) + mâu thuẫn trạng thái gửi** ("Đã gửi 08:00 13-11" nhưng "Lịch sử gửi: Chưa có tin nào được gửi.").
- **F-7. [Quyền] GM bị chặn trang Điều chuyển kho** trong khi owner xem được; GM cũng không thấy mục "Điều chuyển" trong menu Kho.
- **F-8. [Chặn — đối chiếu M6 L1] Nút tạo phiếu vắng mặt ở cả 3 trang kho với cả owner và GM** (5 vai trò đã kiểm tra).
- **F-9. [Hiển thị] Trang tổng quan Báo cáo của GM không hiện số liệu tóm tắt trên các thẻ như owner** (owner có "2 đơn mua mở · còn lại 2.040.000 đ", "Ghi nhận 140.000 đ · Chênh lệch đối soát 140.000 đ", "Doanh thu 145.000 đ · … 79 / 177 món"; GM chỉ hiện mô tả + "Xem báo cáo").
- **F-10. [UX] Nút "Xuất Excel" điều hướng tab hiện tại sang URL API** thay vì tải file (mất trang báo cáo; với lỗi khóa sổ/500 người dùng chỉ thấy trang JSON/trang lỗi).
- **F-11. [Nhỏ]** /reports/amenities trả 404 (đường dẫn đúng là /reports/amenity-cpor); ghi chú nguồn số liệu ở Hủy hàng/Thẻ kho/Minibar/Chi phí vận hành hiển thị không dấu (VD "Gia von lay tu move minibar_sale; doi soat: ghi nhan = da thu + mien + thu muon…", "CPOR = chi phi / tong dem phong ban (rooms_sold) thang; hoa don chi tinh dong co khoan muc/cost center tren PO.").
- Lưu ý kỹ thuật: nhiều lần bấm/điều hướng trên app phản hồi chậm vài giây mới chuyển trang (đã chờ và xác nhận bằng URL/số liệu sau khi tải), không phải nút hỏng.

## 8. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (owner → gm → accountant), 00:12–00:19 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
