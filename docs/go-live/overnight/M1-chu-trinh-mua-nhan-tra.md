# M1 — Thử lại chu trình Mua → Nhận → Trả tiền (PO-TEST47-LE-2611-0003)

- Ngày: 14/11/2026, 02:33–02:38 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.receiver, uat.accountant, uat.purchaser, uat.owner (đăng nhập tay, xác nhận qua menu tài khoản).
- Kết luận: **Đạt một phần — (a) form hóa đơn ĐÃ SỬA (mở được); (b) lưu nháp PO chợ CHƯA SỬA (vẫn mất sửa, nay im lặng không báo lỗi); ô ước tính 500.000 đã sửa (nhận + lưu được). Chu trình vẫn dừng ở bước nhận hàng vì kẹt chụp ảnh; không có phiếu nhận nào được ghi sổ.**
- Commit: `T-M1` (xem git log).

## 1. Nhận hàng (receiver, mobile /m/…/receive) — mù vẫn giữ, kẹt chụp ảnh

- Danh sách PO chờ nhận: PO-TEST47-LE-2611-0003 CÓ trong danh sách, thẻ ghi "1 dòng", NCC "Công ty TNHH Thực phẩm Mẫu An Phát", ngày hẹn giao 13/11/2026, "Hợp đồng". Không thấy số lượng đặt hay đơn giá trên thẻ.
- Hộp thoại "Mở phiếu nhận hàng": kho nhận mặc định "Kho bếp (Demo) (KHO_BEP)", có lựa chọn Kho nhà hàng / Kho chính T047. Không thấy số lượng đặt/đơn giá trong hộp thoại.
- Bấm "Mở phiếu nhận" → tạo thêm 1 phiếu nháp mới: **GRN-TEST47-LE-2611-0006** (0/1 dòng) — tái hiện lỗi trùng nháp (mở lại PO đã có nháp thì sinh thêm nháp mới, xem demo test + M9).
- Màn nhập dòng: "ba chỉ nách", "Thịt & Cá", kg, các ô Số cân (gross) —, Bì (tare) —, Số thực nhận (net) — ("Thực nhận = Tổng cân − Bì"), "Bắt buộc chụp ảnh* Chưa chụp ảnh", nút "Chụp ảnh", "Kết quả QC: Đạt / Không đạt / Chờ quyết định", "Chưa có mẫu checklist cho nhóm hàng này", "Nhiệt độ (°C) —". Không thấy số lượng đặt/đơn giá ở đâu — **mù giữ ở cả 3 màn**.
- Bấm "Chụp ảnh" → "Không tìm thấy camera trên thiết bị này. Hãy dùng thiết bị có camera rồi thử lại." (nút "Thử lại"). Kẹt ở bước chụp ảnh, không ghi được dòng: "Ghi dòng" và "Ghi sổ nhận hàng" đều vô hiệu, vẫn "Đã ghi 0/1 dòng". Đã dừng phần nhận hàng tại đây, không vòng qua, không bấm ghi sổ. Không cần dùng mã PIN (chưa tới bước ghi sổ).

## 2. Kiểm tra (a): form hóa đơn (accountant, /finance/invoices/new) — ĐÃ SỬA

- Form "Nhập hóa đơn mới" **MỞ ĐƯỢC** — lỗi chiều 13/11 ("Không thể tải dữ liệu / Bạn chưa được cấp quyền…") đã được sửa. Không còn thông báo chặn. KHÔNG gửi form.
- Các trường: Nhà cung cấp (combobox, có SUP0001 "Công ty TNHH Thực phẩm Mẫu An Phát"), Đơn mua (combobox), Ký hiệu, Số hóa đơn, Ngày hóa đơn (mặc định 14/11/2026), Mã tra cứu; khu vực "Chọn đơn mua".
- **Ghi nhận thêm:** sau khi chọn NCC SUP0001, ô Đơn mua hiện "PO-TEST47-LE-2611-0003 · sent" nhưng **bị vô hiệu hóa (disabled)** nên không chọn được, chưa hiện các trường số tiền. Có lẽ cần PO đã nhận hàng mới chọn được — chưa xác minh được, cần xác nhận thiết kế (xem F-3).

## 3. Kiểm tra (b): lưu nháp PO chợ (purchaser, PO-TEST47-LE-2611-0004) — CHƯA SỬA

- Trang chi tiết PO-0004: NHÁP, "Mua chợ (tiền mặt) · Mua chợ · Ngày đặt: 13/11/2026", Tổng tiền: 0 đ, Tổng ước tính: 500.001 đ, dòng hàng 1: "Rau cu cho demo B2 — chua co gia", Giá tay, 5 kg, đơn giá 0 đ, thành tiền 0 đ; "Gửi duyệt" vô hiệu vì "Chưa có lý do vượt trần — không gửi duyệt được".
- **Lưu nháp: KHÔNG LƯU ĐƯỢC — lỗi chưa sửa.** Thử 2 lần: lần 1 thêm "M1-test" vào mô tả dòng hàng rồi "Lưu nháp"; lần 2 thêm "M1-test" vào cả "Lý do vượt giá trần" và mô tả (đã kiểm tra ô nhập hiển thị đúng "M1-test" trước khi bấm Lưu). Cả hai lần đều **KHÔNG có thông báo nào** (không còn báo "Dữ liệu không hợp lệ…" như chiều 13/11): form quay về trang chi tiết trong im lặng. Tải lại trang: mô tả vẫn "Rau cu cho demo B2 — chua co gia", lý do vượt trần vẫn trống. **Sửa bị mất hoàn toàn — triệu chứng đổi từ báo lỗi sang im lặng bỏ sửa (tệ hơn về UX: người dùng tưởng đã lưu).**
- Form "Sửa nháp" KHÔNG có trường ghi chú; các trường có là: Ngày dự kiến nhận (đang trống), Lý do vượt giá trần, Mô tả, Số lượng, Đơn giá, Khoản mục chi phí, Trung tâm chi phí.
- **Ô "Tổng ước tính": nhập 500.000 thì NHẬN và LƯU ĐƯỢC** — banner xanh "Đã lưu tổng ước tính.", tiêu đề đổi thành "Tổng ước tính: 500.000 đ". Lỗi step=1000 chiều 13/11 **ĐÃ ĐƯỢC SỬA** (lúc đang lưu nút "Lưu ước tính" tạm mờ đi, dễ tưởng bị từ chối — cần đợi rồi quan sát lại). Sau kiểm tra đã khôi phục lại 500.001 đ (banner "Đã lưu tổng ước tính.", tiêu đề về 500.001 đ).
- Lưu ý: 1 thao tác trong tác vụ trình duyệt trả về trạng thái không xác định (receipt unknown) — việc khôi phục ước tính về 500.001 đ đã thấy banner + tiêu đề đổi, nhưng nên đối chiếu lại con số này ở lần kiểm tra sau.

## 4. Kiểm tra cuối (owner)

1. **Danh sách PO (/procurement/po) — đầy đủ 4 dòng (đối chiếu chuẩn, sửa lại số liệu M9 đợt 2 đã ghi sai):**
   - PO-...-0004 | Mua chợ (tiền mặt) | Mua chợ | 13/11/2026 | 0 đ | 1 dòng | UAT Thu mua | NHÁP
   - PO-...-0003 | Công ty TNHH Thực phẩm Mẫu An Phát | Hợp đồng | 13/11/2026 | 1.000.000 đ | 1 dòng | UAT Thu mua | ĐÃ GỬI
   - PO-...-0002 | NCC T047 | Hợp đồng | 13/11/2026 | 1.040.000 đ | 3 dòng | Test Purchaser | NHÁP
   - PO-...-0001 | NCC T047 | Hợp đồng | 12/11/2026 | 1.040.000 đ | 2 dòng | Test Purchaser | ĐÃ GỬI
2. **Tồn kho:** NVL0388 "ba chỉ nách" = 0 ("0 tồn kho"; mở trực tiếp ?search=NVL0388 cũng 0 kết quả, không có giá trị tồn) — đúng kỳ vọng (chưa có phiếu nhận nào ghi sổ).
3. **Công nợ NCC:** SUP0001 — Còn phải trả 0 đ, Quá hạn 0 đ, "Chưa có dòng nào phù hợp với bộ lọc hiện tại." — đúng kỳ vọng.
4. **Trang Tổng quan, mục "Sáng nay":** có số liệu — Chi mua hàng hôm qua 0 đ; Giá trị hủy hôm qua 0 đ; Cảnh báo đỏ chưa xử lý 8; Công nợ đến hạn 7 ngày 0 đ; Tạm ứng quá hạn 0; banner "Có việc cần xem: cảnh báo đỏ, tạm ứng quá hạn hoặc hợp đồng sắp đến hạn." (chuông "Cảnh báo chưa xử lý (10)").
5. **Audit (/admin/audit): KHÔNG xem được dấu vết với tài khoản chủ đầu tư.** Đường dẫn trong phạm vi khách sạn (…/b000…0002/admin/audit) → "Không tìm thấy trang"; đường dẫn toàn cục (/admin/audit, "Nhật ký thay đổi") → chặn quyền: "Bạn chưa được cấp quyền quản trị…". Ô tìm kiếm chức năng gõ "Nhật ký" → "Không tìm thấy chức năng nào". Không xác minh được audit trace của các thao tác trong đợt này (kể cả tạo GRN-0006 và 2 lần lưu ước tính PO-0004) — xem F-4.

## 5. Phát hiện mới

- **F-1. [Nghiêm trọng] Lưu nháp PO chợ vẫn mất sửa, nay im lặng không báo lỗi.** Tái hiện: PO-0004 → "Sửa nháp" → sửa mô tả hoặc lý do vượt giá trần → "Lưu nháp" → tải lại trang chi tiết (sửa mất). Chuyển Claude Code — ưu tiên cao (mất dữ liệu âm thầm).
- **F-2. [Lỗi — đã hẹp được nguyên nhân] Màn Tồn kho: bấm nút "Lọc" (kể cả kho "Tất cả các kho" + từ khóa NVL0388 hoặc "ba chỉ") → "Không thể tải dữ liệu / Invalid UUID"; tải lại vẫn lỗi dù đã bấm "Thử lại".** Nguyên nhân hẹp: form Lọc gửi tham số `warehouse=` rỗng; mở trực tiếp URL chỉ có `?search=NVL0388` (không có `warehouse=`) thì tải bình thường, 0 kết quả. Tái hiện: /inventory/stock → nhập từ khóa → bấm "Lọc". Chuyển Claude Code (đã có hướng sửa: đừng gửi `warehouse=` rỗng, hoặc server chấp nhận chuỗi rỗng).
- **F-3. [Cần xác nhận thiết kế] Form hóa đơn: ô "Đơn mua" liệt kê PO-0003 nhưng bị disabled nên không chọn được, không hiện trường số tiền.** Có thể do PO chưa nhận hàng. Cần Duy/Claude xác nhận: hóa đơn có bắt buộc PO đã nhận hàng không, và ô disabled có giải thích gì không.
- **F-4. [Quyền] Không có đường xem audit trace cho tài khoản chủ đầu tư** (404 ở đường dẫn khách sạn; chặn quyền ở đường dẫn toàn cục). Chủ đầu tư cần xem nhật ký thay đổi thì xem bằng tài khoản nào? Chuyển Claude Code/Duy xác nhận. (Lưu ý: M-04 đã ghi "NO audit-log detail screen" — đây là cùng vấn đề, nay có thêm bằng chứng live: cả owner cũng không vào được.)
- **F-5. [Ghi nhận] Tổng tiền PO-0004 trên danh sách là 0 đ trong khi Tổng ước tính là 500.001 đ** — hai con số khác nhau (ước tính hiển thị riêng trên trang chi tiết). Cần đối chiếu khi đọc số liệu PO chợ.

## 6. Dữ liệu tạo thêm trong đợt này

- 1 phiếu nhận nháp GRN-TEST47-LE-2611-0006 (0/1 dòng, chưa ghi dòng nào, chưa ghi sổ).
- Các thay đổi ước tính PO-0004 đã khôi phục về 500.001 đ (cần đối chiếu lại ở lần kiểm tra sau — xem mục 3).
- Không tạo hóa đơn, không xóa/sửa dữ liệu có sẵn nào khác.

## 7. Lệnh đã chạy

```text
Trình duyệt cloud: 4 tài khoản uat.* (receiver → accountant → purchaser → owner), 02:33–02:38 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
