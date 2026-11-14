# V9 — Báo cáo + xuất Excel (ĐẠT MỘT PHẦN — B-46/B-44/B-42 đạt; 2 báo cáo xuất im lặng; nhánh xuất file khi khóa chưa kiểm được)

- Ngày: 14/11/2026, 11:11–11:15 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.owner (bước 1–3), uat.receiver (bước 4). Đăng nhập tay, xác nhận qua menu tài khoản. Không khóa kỳ nào.
- Kết luận: **Đạt một phần — 11 báo cáo tải được; xuất Excel không còn đổi tab hay HTTP 500; ngày ngược báo lỗi đúng (B-44); receiver chỉ thấy đúng một thông báo (B-42). 2/5 báo cáo có nút Xuất bấm xong im lặng, không hiện thông báo dưới nút. Nhánh xuất file thành công (kỳ ĐÃ khóa) chưa kiểm được vì không có kỳ nào đang khóa.**
- Commit: `T-V9` (xem git log).

## 1. Bước 1 — Trung tâm báo cáo (owner, /reports): ĐẠT

- Trung tâm hiện 1 tab "Báo cáo vận hành" và 11 thẻ báo cáo chi tiết, tất cả đều tải được, không lỗi tải: (1) Thẻ kho, (2) Chất lượng nhận hàng, (3) Đơn mua mở & hóa đơn treo, (4) Tuổi nợ & dòng tiền chi, (5) Tạm ứng chưa quyết toán, (6) Hủy hàng, (7) Chi phí vận hành, (8) Minibar, (9) Amenities — chi phí / đêm phòng, (10) Doanh thu F&B, (11) Bản tin 8h. Cả 11 báo cáo chi tiết đều đã mở và hiển thị dữ liệu/trạng thái trống, không có báo cáo nào lỗi tải.

## 2. Bước 2 — Xuất Excel từng báo cáo (owner, kỳ chưa khóa 01/11–14/11/2026): KHÔNG ĐẠT (3/5 đạt, 2/5 lỗi im lặng)

- Chỉ 5/11 báo cáo có nút "Xuất Excel" (đúng như đêm 13/11). Không có nút Xuất: Thẻ kho, Chi phí vận hành (chỉ chọn tháng 11/2026), Minibar, Amenities — chi phí / đêm phòng (chỉ chọn tháng 11/2026), Doanh thu F&B, Bản tin 8h.
- Ở cả 5 báo cáo có nút Xuất, bấm Xuất đều **KHÔNG làm tab chuyển trang** (đúng kỳ vọng Q268/Q272, khác đêm 13/11), **KHÔNG có lỗi HTTP 500 hay lỗi đỏ nào** (cải thiện so với đêm 13/11), **KHÔNG có file nào được tải xuống** (đúng kỳ vọng vì kỳ chưa khóa; không thấy biểu tượng/thông báo tải file trong cả 7 lần bấm, gồm 2 lần bấm lại).
- Kết quả từng báo cáo có nút Xuất:
  - **Chất lượng nhận hàng** (/reports/receiving-quality): bấm 2 lần — tab không đổi, **KHÔNG hiện thông báo nào dưới nút** (nút chỉ chuyển "Đang xuất…" rồi trở lại "Xuất Excel"), không 500, không file. → **LỖI MỚI (N-1)**.
  - **Đơn mua mở & hóa đơn treo** (/reports/open-po-invoice): hiện thông báo đỏ ngay dưới nút, nguyên văn: **"Khoảng ngày yêu cầu chứa dữ liệu chưa khóa sổ (01/11/2026, 02/11/2026, 03/11/2026, 04/11/2026, 05/11/2026, 06/11/2026, 07/11/2026, 08/11/2026, 09/11/2026, 10/11/2026 và 4 ngày khác). Hãy khóa sổ kỳ kế toán hoặc ngày nghiệp vụ rồi xuất lại, hoặc thu hẹp khoảng ngày."** → Đạt.
  - **Tuổi nợ & dòng tiền chi** (/reports/ap-aging): đúng thông báo đỏ nguyên văn như trên, ngay dưới nút. → Đạt.
  - **Tạm ứng chưa quyết toán** (/reports/advances): đúng thông báo đỏ nguyên văn như trên, ngay dưới nút. → Đạt.
  - **Hủy hàng** (/reports/waste): bấm 2 lần — tab không đổi, **KHÔNG hiện thông báo nào dưới nút** (nút chỉ chuyển "Đang xuất…" rồi trở lại "Xuất Excel"), không 500, không file. → **LỖI MỚI (N-1)**.
- Nhận xét: 2 báo cáo lỗi đều là báo cáo dạng khoảng ngày (Từ–Đến: 01/11–14/11/2026), còn 3 báo cáo hiện thông báo đúng đều là dạng "Tính đến ngày".
- **Chưa xác minh được nhánh xuất file thành công (kỳ ĐÃ khóa)** vì không có kỳ nào đang khóa và nhiệm vụ cấm khóa kỳ — phần này **KHÔNG KIỂM ĐƯỢC**, cần kiểm riêng sau khi có kỳ đã khóa.

## 3. Bước 3 — Ngày ngược (owner, B-44, báo cáo F&B): ĐẠT

- Nhập Từ ngày 14/11/2026, Đến ngày 01/11/2026 rồi bấm Áp dụng (URL thành /reports/fnb-revenue?from=2026-11-14&to=2026-11-01): trang hiện cảnh báo, nguyên văn **"Ngày bắt đầu phải trước hoặc bằng ngày kết thúc."** và KHÔNG trả dữ liệu (không còn bảng/số liệu). Không còn hiện tượng trả dữ liệu im lặng như đêm 13/11.

## 4. Bước 4 — Tài khoản không có quyền xem báo cáo (receiver, /reports, B-42): ĐẠT

- Trang chỉ hiện **ĐÚNG MỘT dòng thông báo**, nguyên văn: **"Bạn chưa được cấp quyền xem báo cáo nào."** Không còn cảnh "vừa báo không có quyền vừa báo lỗi tải" như đêm 13/11; không có thẻ báo cáo nào, không có nút Xuất.

## 5. Phát hiện mới

- **N-1. [Lỗi chính — giao diện] Xuất Excel im lặng ở 2 báo cáo kỳ chưa khóa: Chất lượng nhận hàng và Hủy hàng.** Tái hiện: đăng nhập owner → mở /reports/receiving-quality hoặc /reports/waste (kỳ mặc định 01/11–14/11/2026, chưa khóa) → bấm "Xuất Excel" → nút hiện "Đang xuất…" rồi trở lại bình thường, tab không đổi, không có thông báo tiếng Việt nào dưới nút, không lỗi 500, không file tải. Đã bấm lại lần 2 ở cả hai báo cáo, kết quả giống hệt. Kỳ vọng theo thiết kế: hiện thông báo tiếng Việt ngay dưới nút như 3 báo cáo còn lại. Chuyển Claude Code (P1 — hai báo cáo dạng khoảng ngày không hiện thông báo lỗi xuất; có thể nhánh lỗi ERR_EXPORT_NOT_LOCKED không được bắt/hiển thị ở hai báo cáo này).
- **N-2. [Cần xác minh — đã biết từ V5] Báo cáo Minibar (/reports/minibar, kỳ 01/11–14/11/2026) hiển thị các chỉ số có vẻ mâu thuẫn:** "Doanh thu 0 đ" nhưng "Ghi nhận 140.000 đ", "Chờ thu 140.000 đ", "Chênh lệch đối soát 140.000 đ". Chưa kết luận là lỗi vì có thể các chỉ số này khác nhau về định nghĩa; đây chính là B-8 đã ghi ở V5 (cần thu được tiền phiếu 101 mới kiểm được). Không ghi thành lỗi mới.

## 6. Kết quả xác minh các lỗi cũ trong V9

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q268 | Xuất Excel không đổi tab, lỗi hiện ngay dưới nút (B-46) | **Đạt một phần** — không đổi tab + không 500 ở cả 5 báo cáo; thông báo dưới nút chỉ hiện ở 3/5 (2 báo cáo im lặng, N-1) |
| Q268 | Xuất Excel không còn HTTP 500 | **Đạt** — 0 lỗi 500 trong 7 lần bấm |
| Q272 B-42 | Tài khoản 0 quyền báo cáo chỉ thấy 1 thông báo | **Đạt** |
| Q272 B-44 | Ngày ngược báo lỗi | **Đạt** |
| — | Xuất file thành công khi kỳ đã khóa (cột, dấu, số Excel) | **Không kiểm được** — không có kỳ nào khóa |

## 7. Lệnh đã chạy

```text
Trình duyệt cloud: 2 tài khoản uat.* (owner → receiver), 11:11–11:15 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
