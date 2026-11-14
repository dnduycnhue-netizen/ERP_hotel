# V8 — Bán hàng nhà hàng + cảnh báo tồn (ĐẠT MỘT PHẦN — B-31/B-7/B-29 đạt; B-33 tái hiện)

- Ngày: 14/11/2026, 11:02–11:06 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.chef (bước 1, 2, 4, 5), uat.owner (bước 3). Đăng nhập tay, xác nhận qua menu tài khoản (lúc bắt đầu phiên đang là uat.receiver nên đã đăng xuất, đăng nhập lại đúng tài khoản). Dòng bán kiểm thử đã ghi và đã hủy đúng dòng đó; dòng bán đêm 13/11 không bị chạm tới.
- Kết luận: **Đạt một phần — cảnh báo thiếu tồn (B-31), phiếu lĩnh nháp tự sinh, lãi gộp khớp nhau (B-7), phiên buffet "Đã hoàn tất" (B-29) đều đạt. "Hủy dòng" hủy ngay không qua ô xác nhận — B-33 tái hiện.**
- Commit: `T-V8` (xem git log).

## 1. Bước 1 — Ghi dòng bán khi tồn thiếu: ĐẠT

- Ghi bán thành công món **ALA-02 — Tôm Chiên Giòn × 1**, ngày 14/11/2026, đơn giá 145.000 đ, nguồn "Ghi tay". Dòng bán hiện trong danh sách ngày 14/11.
- Cảnh báo thiếu tồn CÓ hiện, nguyên văn: **"Đã ghi bán. Cảnh báo: 7 nguyên liệu của món này chưa đủ tồn trong kho. Dòng bán vẫn được ghi; hãy kiểm tra phiếu lĩnh nháp tự sinh."** → N = 7, đúng dạng kỳ vọng.

## 2. Bước 2 — Phiếu lĩnh nháp tự động: ĐẠT

- Có phiếu nháp mới sinh tự động sau dòng bán: **REQ-TEST47-LE-2611-0003**, NHÁP, ngày 2026-11-14, bộ phận Bếp (Demo), Kho chính T047 → Kho bếp (Demo), 7 dòng, tổng SL 0,425, ghi chú **"Tự động từ bán món Tôm Chiên Giòn"**, đã xuất 0, đã nhận 0. Khác REQ-...-0001 (NHÁP, 13/11) và REQ-...-0002 (ĐÃ DUYỆT, 14/11, V4).
- Các dòng (tên mặt hàng — ĐVT — SL yêu cầu): bột Mì — kg — 0,03; Tương ớt Sài Gòn (chai 2 lít) — chai — 0,01; Trứng Gà - mã 213603 — trung — 0,25; Tabasco (60ml) — chai — 0,0417; tôm bạc 60c/kg — kg — 0,0333; mayonnaise — kg — 0,02; bột bắp_năng — kg — 0,04. (Trang phiếu chỉ hiển thị tên mặt hàng, không hiển thị mã mặt hàng.)

## 3. Bước 3 — Lãi gộp khớp nhau (trước khi hủy, kỳ 14/11/2026): ĐẠT — KHỚP

- Trang bán hàng (lọc 14/11–14/11): Tổng số lượng 1; Tổng doanh thu 145.000 đ; Tổng giá vốn 0 đ; Tổng lãi gộp 0 đ. Dòng "Tôm Chiên Giòn" giá vốn "—", lãi gộp "—", kèm ghi chú "Có món chưa tính được foodcost (thiếu giá trần) nên lãi gộp chưa đủ."
- Báo cáo F&B (/reports/fnb-revenue, kỳ 14/11/2026): Doanh thu 145.000 đ; Giá vốn 0 đ; Lãi gộp 0 đ. Dòng ALA-02 Tôm Chiên Giòn × 1, 145.000 đ, giá vốn "—", lãi gộp "—". Ghi chú báo cáo: foodcost lấy từ giá trần hiện hành tại thời điểm chạy báo cáo; món thiếu giá trần thì foodcost NULL và không tính vào lãi gộp.
- Kết luận: **hai chỗ KHỚP nhau, chênh lệch 0 đ (cả doanh thu, giá vốn và lãi gộp). Đúng hành vi bản sửa B-7 (chỉ tính lãi gộp với món có giá vốn đã biết; ALA-02 chưa có giá trần nên lãi gộp 0 đ ở cả hai chỗ).** Để tham chiếu, kỳ 01/11–14/11 cả hai chỗ đều là 290.000 đ / 0 đ / 0 đ.

## 4. Bước 4 — Hủy dòng bán: KHÔNG ĐẠT (ở khâu xác nhận; việc hủy đúng dòng thì thành công)

- Hủy ĐÚNG dòng 14/11 (Tôm Chiên Giòn, Ghi tay, 145.000 đ); dòng ALA-02 đêm 13/11 vẫn nguyên trạng thái "—" và còn nút "Hủy dòng" (đã kiểm tra lại ở kỳ 01/11–14/11).
- **Ô HỎI XÁC NHẬN KHÔNG XUẤT HIỆN: bấm "Hủy dòng" một lần, trang không hiện câu hỏi nào ngay trên trang, không có nút "Xác nhận"/"Bỏ qua" — dòng bán chuyển thẳng sang trạng thái "ĐÃ HỦY" mà không qua bước xác nhận.**
- Sau khi hủy, tổng tiền ngày 14/11: Tổng số lượng 0, Tổng doanh thu 0 đ, Tổng giá vốn 0 đ, Tổng lãi gộp 0 đ ("Theo món: Chưa có dòng bán nào trong kỳ."). Tổng kỳ 01/11–14/11 trở về 145.000 đ (chỉ còn dòng 13/11).

## 5. Bước 5 — Phiên buffet đã đóng (13/11, buổi Tối): ĐẠT

- Trạng thái phiên hiển thị **"ĐÃ HOÀN TẤT"** — KHÔNG còn "KHÔNG RÕ TRẠNG THÁI" (cả ở danh sách buffet và trong trang chi tiết phiên).
- Chi tiết phiên: "Phiên buffet — 2026-11-13 · Tối"; Số khách: 1 · Giá / khách: 0 đ (doanh thu phiên 1 × 0 đ = 0 đ); "Chưa có món ăn nào."; ghi chú "Phiên kiểm thử M4".

## 6. Phát hiện mới

- **N-1. [Giao diện — B-33 tái hiện, bản sửa Q272 chưa đủ] Nút "Hủy dòng" hủy ngay không qua ô xác nhận.** Tái hiện: tài khoản bếp trưởng → Nhà hàng → Bán hàng → lọc ngày 14/11/2026 → bấm "Hủy dòng" trên dòng 14/11 → dòng chuyển "ĐÃ HỦY" ngay, không hiện câu hỏi Xác nhận/Bỏ qua. Rủi ro: hủy nhầm dòng bán chỉ bằng một lần bấm. Kỳ vọng theo Q272: hiện ô hỏi ngay trên trang với nút "Xác nhận"/"Bỏ qua". Chuyển Claude Code (P1 — bọc nút "Hủy dòng" bán hàng bằng InlineConfirmButton; đối chiếu các nút hủy khác đã sửa ở Q272).
- **N-2. [Nhỏ — chính tả/i18n]** Tiêu đề trang tổng quan viết "Chúc năng thường dùng" (sai chính tả, đúng là "Chức năng"). Ghi chú trong báo cáo F&B có đoạn không dấu: "Foodcost lay tu gia tran hien hanh tai thoi diem chay bao cao (khong phai gia luc ban); mon nao thieu gia tran thi foodcost NULL va khong tinh vao lai gop." — phần không dấu này đã biết từ trước (B-47, cần migration riêng để sửa ghi chú trong SQL). Chuyển Claude Code (P2 — sửa typo "Chúc năng" trong vi.ts; B-47 vẫn chờ migration).

## 7. Kết quả xác minh các lỗi cũ trong V8

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q270 B-31 | Bán món khi tồn thiếu: dòng vẫn ghi + cảnh báo + phiếu lĩnh nháp tự sinh | **Đạt** |
| Q271 B-7 | Lãi gộp trang bán khớp báo cáo F&B (chỉ món có giá vốn đã biết) | **Đạt** |
| Q272 B-33 | Hủy dòng bán qua ô xác nhận trên trang | **Tái hiện — chưa sửa** |
| Q271 B-29 | Phiên buffet đã đóng hiện "Đã hoàn tất" | **Đạt** |

## 8. Trạng thái cuối

- Dòng bán kiểm thử ngày 14/11 đã ở trạng thái "ĐÃ HỦY"; phiếu REQ-TEST47-LE-2611-0003 vẫn NHÁP (không duyệt/không chạm thêm); dòng ALA-02 đêm 13/11 và phiên buffet 13/11 giữ nguyên.

## 9. Lệnh đã chạy

```text
Trình duyệt cloud: 2 tài khoản uat.* (chef → owner → chef), 11:02–11:06 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
