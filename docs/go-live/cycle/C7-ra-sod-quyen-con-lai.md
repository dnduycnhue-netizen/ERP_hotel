# C7 — Rà SoD & quyền còn lại

- Ngày: 14/11/2026. App live https://erphotel.vercel.app. Khách sạn TEST47.
- Kết quả: **Đạt** — máy chủ chặn tự duyệt đúng (câu tiếng Việt, không lộ mã `ERR_*` thô); bảng quyền xem phiếu trả đã rõ (GM + receiver bị chặn, 4 vai trò còn lại mở được); GM không tạo được PR ở mức danh sách. 2 điểm giao diện: nút Duyệt vẫn hiện cho người lập phiếu, và form tạo PR vẫn mở được bằng URL trực tiếp.
- Nhánh `feat/muse-cycle`, commit `T-C7:` (ghi sau khi gate xanh).

## (1) Bảng /receiving/returns theo từng tài khoản

| Tài khoản | Kết quả | Thông báo nguyên văn (nếu bị chặn) |
|---|---|---|
| uat.purchaser@erp.internal | MỞ ĐƯỢC | — (0 phiếu, "Chưa có phiếu trả hàng nào.", không có nút tạo) |
| uat.gm@erp.internal | BỊ CHẶN | "Không thể tải dữ liệu — Bạn chưa được cấp quyền receiving.view để thực hiện thao tác này." |
| uat.receiver@erp.internal | BỊ CHẶN | "Không thể tải dữ liệu — Bạn chưa được cấp quyền receiving.view để thực hiện thao tác này." |
| uat.storekeeper@erp.internal | MỞ ĐƯỢC | — (0 phiếu, không có nút tạo) |
| uat.accountant@erp.internal | MỞ ĐƯỢC | — (0 phiếu, không có nút tạo) |
| uat.owner@erp.internal | MỞ ĐƯỢC | — (0 phiếu, không có nút tạo) |

Lưu ý: cả 6 tài khoản đều không thấy nút tạo trên trang danh sách phiếu trả (kể cả các tài khoản xem được). Xem C2-N4.

## (2) Người lập phiếu bấm thử "Duyệt" phiếu của mình: BỊ CHẶN ĐÚNG
- Tài khoản uat.chef@erp.internal ("UAT Bếp trưởng") lập phiếu lĩnh mới: Bộ phận "Bếp (Demo)", Kho xuất "Kho chính T047 (KHO-T047)", Kho nhập "Kho bếp (Demo) (KHO_BEP)", mặt hàng NVL0388 "ba chỉ nách" số lượng yêu cầu 1 kg, ghi chú "Phiếu lĩnh kiểm thử C7 — thử tự duyệt". Lưu nháp thành công → mã phiếu **REQ-TEST47-LE-2611-0004** (id 1daebba4-feda-424b-9248-d8d7f7ac24bd). Bấm "Gửi duyệt" → hiện "Đã thực hiện.", trạng thái CHỜ DUYỆT (không xuất hiện ô xác nhận trên trang khi bấm Gửi duyệt).
- Vẫn bằng tài khoản chef, mở chi tiết phiếu CHỜ DUYỆT: **có hiện nút "Duyệt" và "Từ chối" cho chính người lập phiếu**. Bấm "Duyệt" (không xuất hiện ô xác nhận) → bị chặn ở phía máy chủ, thông báo nguyên văn: **"Bạn không phải người duyệt được giao cho bước này."** (dòng đỏ trên trang). Trạng thái phiếu sau khi bấm vẫn là CHỜ DUYỆT — **không** chuyển thành ĐÃ DUYỆT, nên đây **không** phải lỗi tự duyệt thành công. Toàn bộ thông báo là câu tiếng Việt, **không lộ mã lỗi thô dạng `ERR_*`** trên màn hình. (Xác nhận kết luận của Q273 về V4-N4: máy chủ chặn tự duyệt.)
- Phiếu REQ-...-0004 vẫn đang ở trạng thái CHỜ DUYỆT để kiểm tra tiếp.

## (3) Bảng tổng hợp các chặn SoD đã gặp trong toàn đợt C1–C7

| # | Tình huống | Tài khoản | Thông báo tiếng Việt nguyên văn | Kết quả |
|---|---|---|---|---|
| 1 | Người lập phiếu lĩnh tự duyệt phiếu của mình (REQ-...-0004) | chef | "Bạn không phải người duyệt được giao cho bước này." | Bị chặn đúng ở máy chủ (C7). Nhưng giao diện vẫn hiện nút Duyệt/Từ chối cho người lập — xem C7-N1. |
| 2 | Kế toán duyệt hóa đơn mình tạo (C26TAA 0000001) | accountant | "Người tạo hóa đơn không được tự duyệt (tách biệt nhiệm vụ)." (ghi chú trên trang, không có nút Duyệt) | Bị chặn đúng (C1). Ghi chú này không còn hiện sau khi hóa đơn đã thanh toán — xem C7-N3. |
| 3 | Kế toán duyệt đề nghị thanh toán mình tạo (PAY-...-0001) | accountant | (không có nút Duyệt; mục duyệt chỉ hiện "1 — Kế toán trưởng chuỗi — Chờ duyệt") | Bị chặn đúng (C1). |
| 4 | GM duyệt đề nghị thanh toán (không phải người được giao) | gm | "Bạn không phải người duyệt được giao cho bước này." | Bị chặn đúng (C1). Người được giao là Kế toán trưởng chuỗi — chief_accountant duyệt được. |
| 5 | GM tạo PR (tách quyền tạo/duyệt) | gm | "Bạn chưa được cấp quyền pr.create để thực hiện thao tác này." (khi bấm Lưu nháp — V2) | Bị chặn đúng ở mức danh sách (không có nút "Tạo yêu cầu") + khi lưu (V2). Nhưng form vẫn mở được bằng URL trực tiếp — xem C7-N2. |
| 6 | Receiver ghi sổ phiếu nhận của mình (GRN-...-0008) | receiver | — (ghi sổ thành công, "Đã ghi sổ phiếu nhận hàng thành công.") | **Không phải chặn SoD** — receiver là người ghi sổ phiếu nhận theo thiết kế (C1). |
| 7 | Thủ kho ghi sổ phiếu nhận | storekeeper | "Bạn chưa được cấp quyền receiving.post để thực hiện thao tác này." | Chặn quyền (thiếu `receiving.post`), không phải SoD (C1). |
| 8 | GM / receiver xem phiếu trả hàng NCC | gm, receiver | "Bạn chưa được cấp quyền receiving.view để thực hiện thao tác này." | Chặn quyền xem, không phải SoD (C7). |

## Lỗi / bất thường mới

1. **C7-N1 [Giao diện — P2]** — Nút "Duyệt"/"Từ chối" vẫn hiển thị cho **người lập phiếu** trên chi tiết phiếu lĩnh đang CHỜ DUYỆT. Tái hiện: đăng nhập chef → mở `/inventory/requisitions/1daebba4-feda-424b-9248-d8d7f7ac24bd` (REQ-...-0004, CHỜ DUYỆT) → thấy nút "Duyệt"/"Từ chối". Bấm "Duyệt" thì máy chủ chặn nên không thành lỗi bảo mật, nhưng giao diện đang để lộ nút duyệt cho người không được duyệt (cùng họ với V4-N4).
2. **C7-N2 [Giao diện — P2, đã biết từ V2-N2]** — GM mở trực tiếp `/procurement/pr/new` vẫn thấy form tạo PR đầy đủ và nút "Lưu nháp", dù danh sách PR của GM không có nút "Tạo yêu cầu". Chưa bấm Lưu nháp nên chưa rõ máy chủ có chặn khi lưu hay không (V2 đã kiểm: bấm Lưu nháp thì chặn với "Bạn chưa được cấp quyền pr.create..."). Cần ẩn form/chuyển hướng khi thiếu quyền thay vì chỉ ẩn nút ở danh sách.
3. **C7-N3 [Giao diện — P3]** — Trang chi tiết hóa đơn C26TAA 0000001 (xem bằng accountant) không hiển thị ghi chú SoD "Người tạo hóa đơn không được tự duyệt (tách biệt nhiệm vụ)." như kỳ vọng ở C1, và cũng không hiển thị trạng thái duyệt "ĐÃ DUYỆT" nào — chỉ có trạng thái thanh toán "ĐÃ THANH TOÁN" và bảng "Kết quả khớp từng dòng". Không có nút Duyệt (đúng), nhưng phần giải thích SoD đã biến mất khỏi trang chi tiết. Cần Claude Code xác nhận: ghi chú/trạng thái duyệt có nên hiện tiếp sau khi hóa đơn đã thanh toán không (có thể ghi chú chỉ hiện khi hóa đơn đang chờ duyệt — khi đó đây là thiết kế, không phải lỗi).
4. **C7-N4 [Giao diện — P3]** — Chi tiết đề nghị thanh toán PAY-...-0001 hiển thị ngày trả dạng thô chưa định dạng: "Ngày trả: 2026-11-14T05:55:53.306215+00:00" (ISO có micro giây, múi giờ +00:00), không đồng nhất với định dạng "14/11/2026" của các trường ngày khác trên cùng trang.
5. **C7-N5 [Quyền — cần Duy quyết]** — GM (người duyệt) và receiver (người nhận hàng) đều không có quyền xem phiếu trả hàng (thiếu `receiving.view`), trong khi purchaser/storekeeper/accountant/owner xem được — cần Duy xác nhận có đúng thiết kế phân quyền hay không (cùng câu hỏi V2-N4, vẫn chờ Duy).
6. **C7-N6 [Giao diện — P3]** — Không có ô xác nhận trên trang nào xuất hiện khi bấm "Gửi duyệt" phiếu lĩnh hay bấm "Duyệt" phiếu lĩnh (hành động thực hiện ngay); các lần bấm "Lưu nháp"/"Gửi duyệt" phản hồi chậm vài giây mới chuyển trạng thái nhưng vẫn thành công. (Cùng họ với V4-N2/C1-N5: ô xác nhận không nhất quán giữa các thao tác.)
