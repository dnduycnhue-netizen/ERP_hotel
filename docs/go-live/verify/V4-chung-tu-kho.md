# V4 — Chứng từ kho: form mới và vòng đời (ĐẠT MỘT PHẦN — form + nháp + duyệt đạt; các bước tiêu tồn bị chặn chung chung)

- Ngày: 14/11/2026, 10:34–10:40 (trình duyệt cloud). Khách sạn TEST47.
- Tài khoản: uat.storekeeper, uat.chef, uat.gm (đăng nhập tay, xác nhận qua menu tài khoản). Không màn hình nào hỏi mã PIN trong suốt bài (kể cả duyệt của GM).
- Kết luận: **Đạt một phần — cả 4 form mới đều mở + lưu nháp được; phiếu lĩnh gửi duyệt → GM duyệt tới ĐÃ DUYỆT; hủy hàng thiếu ảnh bị chặn đúng; hủy nháp điều chuyển hoạt động. Các bước tiêu tồn (xuất kho, chuyển hàng, ghi sổ xuất) đều bị chặn với cùng một thông báo chung chung "Dữ liệu không hợp lệ", không nêu lý do — không phân biệt được thiếu tồn hay kho bị đóng băng do kiểm kê. Đợt kiểm kê 0004 không hủy (không có thông báo nào nhắc tới kiểm kê).**
- Commit: `T-V4` (xem git log).

## 1. Phần A — Hủy hàng (storekeeper): ĐẠT, trừ bước ảnh bị chặn như dự kiến

- A1 Đạt: form /inventory/waste/new tải được, gồm Kho*, Lý do* (Hết hạn, Hỏng do bảo quản, Vỡ/hỏng, Khách trả lại, Khác), Ghi chú, Mặt hàng*, Số lượng*, Ghi chú dòng, Thêm dòng, Lưu nháp. Lưu nháp thành công: **WST-TEST47-LE-2611-0001**, NHÁP, Kho chính T047, NVL0388 "ba chỉ nách" 1 kg, ghi chú "Hủy hàng kiểm thử V4 — hỏng", trang chi tiết cảnh báo "Đã có 0 ảnh minh chứng— Cần ít nhất một ảnh minh chứng trước khi gửi duyệt."
- A2 Đạt (chặn đúng như kỳ vọng): bấm "Chụp ảnh" → "Không tìm thấy camera trên thiết bị này. Hãy dùng thiết bị có camera rồi thử lại."; nút "Chụp ảnh" biến mất, thay bằng "Thử lại". Không có cách tải ảnh từ file thay thế. Bấm "Gửi duyệt" khi 0 ảnh → bị chặn, banner đỏ nguyên văn **"Thiếu ảnh bắt buộc. Hãy chụp ảnh rồi gửi lại."**, phiếu vẫn NHÁP — **đúng hành vi yêu cầu (thiếu ảnh phải chặn)**.
- A3: trên trang chi tiết phiếu nháp với tài khoản storekeeper, nút HIỆN: Chụp ảnh (sau lỗi chụp thành "Thử lại"), Gửi duyệt, Hủy phiếu. Nút ẨN/không có: Sửa/Chỉnh sửa, Duyệt/Từ chối, Ghi sổ, Xóa.

## 2. Phần B — Phiếu lĩnh (chef → GM → storekeeper): ĐẠT đến bước duyệt; xuất kho bị chặn

- B1 Đạt: form /inventory/requisitions/new tải được, gồm Bộ phận*, Kho xuất*, Kho nhập*, Ghi chú, Mặt hàng*, SL yêu cầu*, SL thực tế, Ghi chú dòng, Thêm dòng, Lưu nháp (có dòng nhắc "...thiếu tồn kho → không thể xuất hàng."). Lưu nháp thành công: **REQ-TEST47-LE-2611-0002**, NHÁP, bộ phận Bếp (Demo), Kho chính T047 → Kho bếp (KHO_BEP), NVL0388 2 kg, ghi chú "Phiếu lĩnh kiểm thử V4", Đã xuất 0, Đã nhận 0. Bấm "Gửi duyệt" → trạng thái đổi thành CHỜ DUYỆT (toast "Đã thực hiện."). Lưu ý: không thấy ô xác nhận trên trang hiện ra cho bước này (xem N-2).
- B2 Đạt (duyệt được, không hỏi PIN): trang /procurement/approvals, mục "Chờ tôi duyệt" hiển thị "Không có chứng từ nào chờ bạn duyệt" — **phiếu lĩnh KHÔNG nằm trong danh sách này (trang chỉ có tab "Yêu cầu mua", "Đơn mua")**, nên duyệt trực tiếp trên trang chi tiết phiếu lĩnh. GM bấm Duyệt → trạng thái đổi thành **ĐÃ DUYỆT**, không hỏi mã PIN, không thấy ô xác nhận hiện ra; sau duyệt GM không còn nút thao tác nào trên trang.
- B3 Chặn: storekeeper mở phiếu đã duyệt, nút "Xuất kho" hiện; bấm vào mở khung xác nhận trên trang (dòng "ba chỉ nách — SL thực tế 2", nút Xác nhận/Bỏ qua). Bấm Xác nhận → bị chặn, nguyên văn **"Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập."**, phiếu vẫn ĐÃ DUYỆT, Đã xuất 0. Thông báo chung chung, **KHÔNG nêu thiếu tồn và KHÔNG nhắc kiểm kê/đóng băng** (xem N-1).
- Bếp xác nhận nhận: **chưa kiểm được — chưa xuất kho.**

## 3. Phần C — Điều chuyển (storekeeper): ĐẠT lưu nháp và hủy nháp; chuyển hàng bị chặn

- C1 Đạt: form /inventory/transfers/new tải được, gồm Kho xuất*, Kho nhập*, Ghi chú, Mặt hàng*, Số lượng*, Ghi chú dòng, Thêm dòng, Lưu nháp. Lưu nháp thành công: **TRF-TEST47-LE-2611-0001**, NHÁP, NVL0561 "Bánh bèo" 2 cái, Kho chính T047 → Kho bếp (KHO_BEP), ghi chú "Điều chuyển kiểm thử V4", Đã chuyển 0, Đã nhận 0.
- C2 Chặn: bấm "Chuyển hàng" → khung xác nhận trên trang (dòng "Bánh bèo — SL thực tế 2", Xác nhận/Bỏ qua) → bấm Xác nhận → bị chặn, nguyên văn **"Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập."**, phiếu vẫn NHÁP, Đã chuyển 0. Không nhắc thiếu tồn hay kiểm kê. Vì không chuyển được nên không có bước bên nhận xác nhận để kiểm.
- C3 Đạt: bấm "Hủy phiếu" → khung hủy trên trang, ô "Lý do *" (nút Xác nhận bị khóa cho tới khi nhập lý do) → nhập "Hủy nháp kiểm thử V4" → Xác nhận → trạng thái đổi thành **ĐÃ HỦY** (đã đối chiếu lại trên danh sách).

## 4. Phần D — Xuất mục đích (storekeeper): ĐẠT lưu nháp; ghi sổ bị chặn

- D1 Đạt: form /inventory/issues/new tải được, gồm Kho*, Mục đích* (Ăn ca nhân viên, VIP/Comp, Marketing, Họp, Đào tạo, Sửa chữa, Khác), Cost center, Khoản mục, Ghi chú, Mặt hàng*, Số lượng*, Ghi chú dòng, Thêm dòng, Lưu nháp. Lưu nháp thành công: **PIS-TEST47-LE-2611-0001**, NHÁP, NVL0388 1 kg, Kho chính T047, mục đích "Khác" (bài giao không chỉ định mục đích cụ thể nên chọn "Khác"), ghi chú "Xuất mục đích kiểm thử V4".
- D2 Chặn: bấm "Ghi sổ" → bị chặn, nguyên văn **"Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập."**, phiếu vẫn NHÁP. Không có ô xác nhận hiện ra cho bước này; thông báo không nêu thiếu tồn hay kiểm kê.
- D3 Đảo phiếu: **chưa kiểm được — chưa ghi sổ.**

## 5. Đợt kiểm kê 0004: KHÔNG HỦY (không có căn cứ)

- Đợt CNT-TEST47-LE-2611-0004 (Kiểm kê luân phiên, Kho chính T047, 14/11/2026) vẫn ĐANG MỞ — KHÔNG HỦY. Lý do: trong cả bài, không một thông báo chặn nào nhắc tới đợt kiểm kê/đóng băng kho, nên điều kiện để hủy đợt theo bài giao (chặn với thông báo liên quan kiểm kê) không xảy ra. Vì vậy **chưa kết luận được đợt 0004 có chặn chứng từ kho hay không; nguyên nhân chặn thực tế (thiếu tồn hay đợt kiểm kê) không xác định được từ giao diện** do thông báo chung chung (N-1). Đề xuất kiểm lại sau khi có tồn hoặc sau khi hủy đợt 0004 để phân biệt nguyên nhân.

## 6. Kiểm tra cuối (storekeeper)

- /inventory/stock: tổng "0 tồn kho"; tìm NVL0388 và NVL0561 đều "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại" — tồn cả hai mã vẫn 0, không đổi sau bài kiểm.
- /inventory/waste: 1 phiếu — WST-...-0001, NHÁP (phiếu V4).
- /inventory/requisitions: 2 phiếu — REQ-...-0002 ĐÃ DUYỆT (V4; Đã xuất 0, Đã nhận 0) và REQ-...-0001 NHÁP ngày 13/11 (có sẵn từ trước, không chạm).
- /inventory/transfers: 1 phiếu — TRF-...-0001, ĐÃ HỦY (V4).
- /inventory/issues: 1 phiếu — PIS-...-0001, NHÁP (V4).

## 7. Phát hiện mới

- **N-1. [Nghiêm trọng — giao diện/RPC] Thông báo chặn chung chung, không nêu lý do:** cả 3 thao tác tiêu tồn (Xuất kho phiếu lĩnh REQ-0002, Chuyển hàng TRF-0001, Ghi sổ PIS-0001) đều thất bại với cùng một câu "Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập.", không phân biệt thiếu tồn / kho bị đóng băng do kiểm kê / lỗi dữ liệu. Người dùng không biết phải khắc phục gì. Tái hiện: mở từng phiếu trên, bấm Xuất kho/Chuyển hàng → Xác nhận (SL thực tế mặc định), hoặc Ghi sổ trên PIS-0001. Chuyển Claude Code (P0/P1 — trả về mã lỗi/lý do cụ thể từ RPC, map sang câu tiếng Việt).
- **N-2. [Giao diện] Ô xác nhận trên trang không nhất quán:** "Gửi duyệt" phiếu lĩnh, "Duyệt" của GM và "Ghi sổ" phiếu xuất mục đích thực thi ngay khi bấm (chỉ thấy nút mờ đi trong lúc xử lý, toast "Đã thực hiện."), không hiện ô Xác nhận/Bỏ qua; trong khi "Xuất kho", "Chuyển hàng" (khung SL thực tế) và "Hủy phiếu" (khung Lý do) thì có ô xác nhận trên trang. Chuyển Claude Code (P2 — thống nhất dùng InlineConfirmButton cho mọi thao tác chuyển trạng thái).
- **N-3. [Giao diện/i18n] Lý do hủy hiển thị mã thô:** phiếu hủy WST-0001 hiển thị lý do "spoiled_storage" ở cả trang chi tiết và danh sách, thay vì nhãn tiếng Việt "Hỏng do bảo quản" như trong form lập phiếu. Chuyển Claude Code (P2 — map mã lý do sang nhãn vi.ts khi hiển thị).
- **N-4. [Bảo mật — cần xác minh phía máy chủ] Người lập phiếu thấy nút Duyệt/Từ chối trên phiếu CHỜ DUYỆT của chính mình** (tài khoản chef, trang chi tiết REQ-0002 sau khi gửi duyệt) — có nguy cơ tự duyệt nếu phía máy chủ không chặn; bài này không bấm thử hai nút đó với tài khoản chef. Chuyển Claude Code (P1 — xác minh RPC `requisition_decide` chặn SoD; đồng thời ẩn nút Duyệt/Từ chối với người tạo phiếu ở UI). Tương tự, GM sau khi duyệt xong thì không còn nút nào, còn storekeeper trên phiếu đã duyệt chỉ thấy "Xuất kho".
- **N-5. [Nhỏ]** ĐVT "Bánh bèo" hiển thị "cai" (không dấu) trên form và trang chi tiết điều chuyển; trang /procurement/approvals không liệt kê phiếu lĩnh chờ duyệt (chỉ yêu cầu/đơn mua) nên GM phải mở thẳng trang chi tiết; sau khi bấm "Lưu nháp" trang giữ nguyên form vài giây rồi mới chuyển sang trang chi tiết, trông như bấm không có phản hồi. Tổng giá trị các phiếu đều 0 đ (mặt hàng chưa có giá) — chỉ ghi nhận.

## 8. Kết quả xác minh các lỗi cũ trong V4

| Mã cũ | Nội dung | Kết quả |
|---|---|---|
| Q270 B-4 | Form + thao tác cho 4 chứng từ kho | **Đạt một phần** — form + lưu nháp + gửi duyệt + duyệt + hủy nháp đều hoạt động; xuất kho/chuyển/ghi sổ bị chặn (thông báo chung chung, N-1) |
| Q270 | Nút "Lập phiếu" ẩn khi thiếu quyền | **Chưa kiểm được** — chưa thử tài khoản thiếu quyền lập phiếu |
| — | Hủy hàng thiếu ảnh phải bị chặn | **Đạt** — "Thiếu ảnh bắt buộc. Hãy chụp ảnh rồi gửi lại." |

## 9. Lệnh đã chạy

```text
Trình duyệt cloud: 3 tài khoản uat.* (storekeeper → chef → gm → storekeeper), 10:34–10:40 14/11/2026
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
