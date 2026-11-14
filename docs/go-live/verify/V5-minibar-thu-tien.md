# V5 — Minibar thu tiền (KHÔNG HOÀN THÀNH — đường cấp tồn có trên giao diện nhưng kho nguồn = 0; B-3/B-39 tái hiện; B-37/B-38 đạt)

- Ngày: 14/11/2026, 10:41–10:49 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.hk_supervisor, uat.storekeeper, uat.front_desk, uat.hk_attendant, uat.owner (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Không hoàn thành — không có đường nào cấp được tồn thật cho kho phòng bằng giao diện trong ngày 14/11: mọi đường đều chết ở kho nguồn đang 0 tồn. Phiếu 101 vẫn chưa thu được tiền (B-3 tái hiện), phiếu 104 vẫn chưa kiểm được (B-39 tái hiện), báo cáo vẫn lệch 140.000 đ (B-8 chưa kiểm được). B-37 và B-38 đã sửa đúng.**
- Commit: `T-V5` (xem git log).

## 1. Bước 1 — Tìm đường cấp tồn cho kho phòng 101 (hk_supervisor, /housekeeping/minibar): ĐẠT (có lưu ý)

- Mục "Tồn minibar từng phòng" không hiển thị tồn: nguyên văn **"Bạn chưa có quyền xem số lượng tồn (stock.view_qty) nên màn này không hiển thị tồn kho phòng. Nhờ quản trị cấp quyền xem tồn cho kho phòng để xem được."** — hk_supervisor thiếu quyền stock.view_qty nên không xem được tồn phòng 101.
- Các nút/thao tác hiện trên trang (nguyên văn): **"Bổ sung"** (mục "Bổ sung theo tầng": "Bổ sung là chuyển hàng từ kho minibar tổng sang kho phòng — không phải bán, không đổi tổng tồn.", chọn Tầng / Mặt hàng / Số lượng), "Lưu giá" (đang vô hiệu), "Nhập giá hàng loạt". Không có nút "Cấp bù", "Nhập kho", "Điều chuyển" trên trang này. Mục "Thu hồi hàng sắp hết hạn": "Không có hàng minibar nào trong phòng sắp hết hạn."
- Bảng giá minibar: đủ 7 món còn giá, hiệu lực 11/11/2026, không có ngày kết thúc: Bia Tiger 35.000 đ, Diet Coke 25.000 đ, Lavie 15.000 đ, Sprite 25.000 đ, Coca-Cola 25.000 đ, Rượu vang 245.000 đ, Larue 25.000 đ.
- Đường cấp bù tìm được trên giao diện: **"Bổ sung theo tầng" (chuyển từ kho minibar tổng sang kho phòng, theo tầng)**. Không bấm nút này (ngoài phạm vi bước và kho tổng đang 0 tồn — xem Bước 2).

## 2. Bước 2 — Tồn kho minibar tổng (storekeeper, /inventory/stock): ĐẠT

- Lọc kho "Kho minibar tổng" (MINIBAR_MAIN): nguyên văn "0 tồn kho" — "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại." Tồn Tiger, Coca-Cola, Lavie và mọi món minibar khác đều 0.
- Đối chiếu thêm kho "Minibar phòng 101": cũng "0 tồn kho". Trước khi lọc, toàn bộ kho cũng hiển thị "0 tồn kho".

## 3. Bước 3 — Điều chuyển vào kho phòng (storekeeper, /inventory/transfers/new): ĐẠT

- Ô Kho nhập chọn được kho phòng 101. Danh sách Kho xuất/Kho nhập gồm: Kho bếp (Demo), Kho nhà hàng (Demo), Kho chính T047, Minibar phòng 101, Minibar phòng 104, Kho minibar tổng, Xe đẩy 1, Xe đẩy 2.
- Đã tạo nháp điều chuyển (CHỈ LƯU NHÁP, không bấm "Chuyển hàng"): mã **TRF-TEST47-LE-2611-0002**, NHÁP, 14/11/2026, Kho chính T047 → Minibar phòng 101, mặt hàng "MB-TIGER — Bia Tiger (lon): Số lượng 1 — Đã chuyển 0 — Đã nhận 0", ghi chú "V5 - nhap dieu chuyen test minibar phong 101". **Đường điều chuyển vào kho phòng tồn tại trên giao diện, nhưng không thực thi được vì kho nguồn (Kho chính T047) cũng 0 tồn.**

## 4. Bước 4 — Đường nhận hàng (chỉ ghi nhận): ĐẠT

- Danh sách có 5 PO; dạng xem danh sách không hiện mặt hàng từng dòng. Đã mở kiểm tra 2 PO: PO-...-0005 (14/11, 1.000.000 đ — Bánh bèo 200 cái, không phải minibar) và PO-...-0002 (13/11, 1.040.000 đ — ba chỉ nách, Bánh bèo, BA CHỈ XÔNG KHÓI, không phải minibar). Các PO 0001/0003/0004 chưa mở.
- Kết luận: **chưa kiểm được đường nhận hàng minibar — cần PO + camera.**

## 5. Bước 5 — Thu tiền phiếu 101 (front_desk, /frontdesk/minibar): KHÔNG ĐẠT (B-3 tái hiện)

- Phiếu MB-TEST47-LE-2611-0001 (phòng 101) trước khi thu: "Chờ thu tiền", Tổng tiền 140.000 đ, 5 dòng: Coca-Cola 1 × 25.000, Diet Coke 1 × 25.000, Larue 1 × 25.000, Lavie 2 × 15.000, Bia Tiger 1 × 35.000. Phòng 101 · Trả phòng · Người kiểm: UAT Giám sát buồng · 13/11/2026 19:26. Đã nhập Số folio "TEST-M5-1311", bấm "Đã thu".
- Kết quả nguyên văn: **"Không đủ tồn kho để xuất."** Phiếu vẫn ở trạng thái "Chờ thu tiền", 140.000 đ, chưa thu được đồng nào.

## 6. Bước 6 — Hiển thị phiếu 104 (front_desk, /frontdesk/minibar): ĐẠT

- Phiếu MB-TEST47-LE-2611-0002 (phòng 104) hiện trạng thái nguyên văn **"Chưa kiểm"**, số tiền 0 đ — KHÔNG phải "Chờ thu tiền 0 đ". **B-37 không tái hiện (ghi nhận trước đây là sai đã được sửa đúng).**

## 7. Bước 7 — Kiểm phòng 104 trên mobile (hk_attendant): KHÔNG ĐẠT (B-38 đạt, B-39 tái hiện)

- Lưu ý đường dẫn: dạng /<UUID khách sạn>/m/... (kể cả /m/minibar, /m/housekeeping/minibar) đều trả "Không tìm thấy trang"; đường mobile đúng là **/m/b0000000-0000-4000-8000-000000000002/minibar**, phiếu 104 tại /m/.../minibar/8ac8bfde-b4b4-4116-8e01-8a69d9e34255. Trang danh sách mobile: "Chờ kiểm: 1 · Đã kiểm: 1"; phòng 104 "MB-...-0002 · Trả phòng — Chưa kiểm"; phòng 101 "Đã kiểm 140.000 đ".
- **B-38 Đạt:** nhập số lượng thiếu 25 cho Bia Tiger → hiện cảnh báo nguyên văn **"Có món số lượng lớn hơn 20 — hãy kiểm tra lại trước khi gửi."**, Tạm tính 875.000 đ, "Đã nhập thiếu: 1/7". Cảnh báo chỉ là cảnh báo — nút "Gửi kết quả kiểm" vẫn bật, không bị chặn.
- Đưa mọi số lượng về 0, chưa tick ô "Phòng không dùng món nào": nút "Gửi kết quả kiểm" ở trạng thái vô hiệu (bấm không phản hồi), kèm dòng nhắc "Chưa nhập món thiếu nào — bấm nút + ở món khách đã dùng." — bị chặn, không có thông báo lỗi riêng.
- Tick ô "Phòng không dùng món nào (xác nhận đã kiểm đủ)" → nút Gửi bật → bấm Gửi → **KHÔNG gửi được**, trang ở lại form và hiện nguyên văn: **"Cần ít nhất một món thiếu để gửi kết quả kiểm."** (**B-39 tái hiện: ô xác nhận không dùng món nào mâu thuẫn với kiểm tra bắt buộc phải có ít nhất 1 món thiếu — bản sửa Q272 chưa đủ.**)
- Trạng thái phiếu 104 sau khi gửi: vẫn "Chưa kiểm", vẫn nằm ở mục "Chờ kiểm (1)", "Chờ kiểm: 1 · Đã kiểm: 1" không đổi. Phiếu 104 vẫn 0 dòng, 0 đ.

## 8. Bước 8 — Báo cáo Minibar (owner, /reports/minibar, kỳ 01/11–14/11/2026): ĐẠT

- Tổng cộng: Doanh thu 0 đ; Giá vốn 0 đ; Lãi gộp 0 đ; Ghi nhận 140.000 đ; Đã thu 0 đ; Miễn thu 0 đ; Thu muộn 0 đ; Chờ thu 140.000 đ; Chờ thu quá kỳ 0 đ; **Chênh lệch đối soát 140.000 đ**; Lavie đã bán (chai) 0; Doanh thu Lavie 0 đ; Dasani đã cấp (chai) 0; Đêm phòng (có phiếu đã thu) 0; Lavie / đêm phòng —; Dasani / đêm phòng —.
- Bảng theo món (chỉ 5 món, toàn 0): Tiger 0 / 0 đ, Diet Coke 0 / 0 đ, Lavie 0 / 0 đ, Coca-Cola 0 / 0 đ, Larue 0 / 0 đ (Số lượng bán / Doanh thu / Giá vốn / Lãi gộp / Miễn thu / Thu muộn đều 0).
- Kết luận: **B-8 vẫn chưa kiểm được — giống hệt đêm 13/11: Ghi nhận 140.000 đ nhưng Doanh thu 0 đ, Chênh lệch đối soát 140.000 đ, vì phiếu 101 vẫn chưa thu được tiền.** (Nhân viên buồng phòng mở /reports/minibar thì bị chuyển về trang "Báo cáo" với dòng "Bạn chưa được cấp quyền xem báo cáo nào.")

## 9. Có đường nào cấp tồn cho kho phòng bằng giao diện không — KHÔNG (ngày 14/11)

- "Bổ sung theo tầng" (/housekeeping/minibar, hk_supervisor): có nút, chuyển từ kho minibar tổng sang kho phòng — chết vì MINIBAR_MAIN = 0.
- Điều chuyển kho (/inventory/transfers/new, storekeeper): chọn được kho phòng 101 làm Kho nhập, đã lưu nháp TRF-...-0002 (NHÁP, Tiger × 1, Kho chính T047 → Minibar phòng 101) — chết vì kho nguồn Kho chính T047 = 0, không bấm "Chuyển hàng".
- Nhận hàng qua PO + chụp ảnh: chưa kiểm được — cần PO + camera; 2 PO đã kiểm tra đều không phải hàng minibar, danh sách PO không hiện mặt hàng.
- Muốn thu được tiền phiếu 101 phải có tồn trong kho phòng 101 trước; hiện kho phòng 101 = 0.

## 10. Phát hiện mới

- **N-1. [Chặn — B-39 tái hiện, bản sửa Q272 chưa đủ] Không gửi được phiếu kiểm 0 món dù đã tick "Phòng không dùng món nào":** mobile /m/<UUID>/minibar/<phiếu 104> → để mọi số lượng = 0 → tick ô "Phòng không dùng món nào (xác nhận đã kiểm đủ)" → bấm "Gửi kết quả kiểm" → hiện "Cần ít nhất một món thiếu để gửi kết quả kiểm.", phiếu vẫn "Chưa kiểm". Chuyển Claude Code (P1 — khi đã tick thì RPC phải chấp nhận 0 dòng thiếu; kiểm tra cả phía máy chủ lẫn UI).
- **N-2. [B-3 tái hiện] Thu tiền phiếu 101 báo "Không đủ tồn kho để xuất."** — /frontdesk/minibar/<phiếu 101> → nhập folio "TEST-M5-1311" → bấm "Đã thu" → báo lỗi trên, phiếu vẫn "Chờ thu tiền" 140.000 đ. Chuyển Claude Code (P1 — cần dữ liệu tồn thật để thu; xem xét có nên cho thu khi kho phòng chưa có tồn không — quyết định của Duy, xem Q268).
- **N-3. [B-8 vẫn mở] Báo cáo minibar kỳ 01/11–14/11/2026: Ghi nhận 140.000 đ, Doanh thu 0 đ, Chênh lệch đối soát 140.000 đ.** Chuyển Claude Code (P1 — kiểm lại sau khi thu được tiền phiếu 101).
- **N-4. [Quyền — cần Duy xác nhận] hk_supervisor thiếu quyền stock.view_qty:** /housekeeping/minibar hiện cảnh báo "Bạn chưa có quyền xem số lượng tồn (stock.view_qty) nên màn này không hiển thị tồn kho phòng..." — giám sát buồng không xem được tồn kho phòng. Cần Duy/Claude xác nhận: giám sát buồng có nên xem tồn kho phòng không (đếm minibar là đếm mù theo Q270 B-26 — cho xem tồn sẽ phá tính mù), hay cảnh báo này là đúng thiết kế?
- **N-5. [Báo cáo — nhỏ] Bảng theo món của báo cáo minibar chỉ liệt kê 5/7 món trong bảng giá** (thiếu Sprite và Rượu vang) dù tất cả đều 0 — 5 món liệt kê đúng bằng 5 món có dòng thiếu trong phiếu 101. Ghi chú nguồn số liệu: "Gia von lay tu move minibar_sale; doi soat: ghi nhan = da thu + mien + thu muon (lech != 0 la MINIBAR_MISMATCH)." Chuyển Claude Code (P2 — xác nhận bảng có nên liệt kê đủ 7 món giá không).
- **N-6. [Ghi nhận]** Trạng thái phiếu 101 hiển thị khác nhau theo màn hình — mobile ghi "Đã kiểm 140.000 đ", lễ tân ghi "Chờ thu tiền"; đường mobile đúng là /m/<UUID khách sạn>/minibar, dạng /<UUID>/m/... trả 404.

## 11. Kết quả xác minh các lỗi cũ trong V5

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q268 B-3 | Thu tiền minibar khi kho phòng chưa có tồn | **Tái hiện — chưa sửa** (cần dữ liệu tồn thật) |
| Q272 B-37 | Phiếu chưa kiểm hiện "Chưa kiểm" | **Đạt** |
| Q272 B-38 | Cảnh báo khi số lượng > 20 | **Đạt** |
| Q272 B-39 | Gửi phiếu 0 món khi tick "Phòng không dùng món nào" | **Tái hiện — chưa sửa đủ** |
| Q271 B-8 (M7) | Báo cáo Minibar khớp sau thu tiền | **Chưa kiểm được** — chưa thu được tiền |

## 12. Lệnh đã chạy

```text
Trình duyệt cloud: 5 tài khoản uat.* (hk_supervisor → storekeeper → front_desk → hk_attendant → owner), 10:41–10:49 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
