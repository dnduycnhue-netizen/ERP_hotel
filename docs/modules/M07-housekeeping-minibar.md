# M07 — Buồng phòng & minibar (PH07, phần MVP)

## 8 nhóm vật tư
| Nhóm (`item_groups.kind`) | Ví dụ | Kiểm soát |
|---|---|---|
| `amenity` | Bàn chải, dầu gội, xà phòng, giấy vệ sinh | Chuẩn setup theo loại phòng × loại dọn × số khách |
| `complimentary` | Nước Dasani, trà, cà phê miễn phí | Theo đêm phòng; chi phí Rooms |
| `collateral` | Bút, giấy, thẻ treo cửa, túi giặt | Bổ sung theo tồn |
| `linen` | Ga, khăn, áo choàng | Luân chuyển (P2) |
| `loan` | Máy sấy, nôi, giường phụ | Cấp/thu hồi theo phòng (P2) |
| `chemical` | Hóa chất vệ sinh, giặt | Theo phòng/m² (P2) |
| `tool` | Giẻ, găng, túi rác | Đổi cũ lấy mới (P3) |
| `minibar` | Lavie, Tiger, Larue, Coca, Sprite, rượu vang | Hàng bán, theo từng phòng |

## Chuẩn setup phòng (07.02 — MVP)
`room_setup_standards`: mỗi loại phòng × `clean_type` (`checkout`, `stayover`, `vip`, `child`) × mã hàng × số lượng (`per_guest` nếu nhân theo khách). Định mức tham khảo tháng 5/2019 của khách (trên đêm phòng): bàn chải 0,89; giấy vệ sinh 0,72 cuộn; nước 1,94 chai; cà phê 0,77 gói — dùng làm giá trị khởi tạo, giám sát buồng chỉnh lại.

## Kho tầng & xe đẩy (07.05 — MVP)
- Mỗi tầng 1 kho `floor`, mỗi xe đẩy 1 kho `trolley` có par.
- Đầu ca `trolley_shift_open`: đếm xe → hệ thống tính số cần lĩnh tới par → phiếu lĩnh kho tầng → xe.
- Cuối ca `trolley_shift_close`: đếm mù xe → tiêu hao ca = đầu + lĩnh − cuối → `purpose_issue` (cost center Rooms, khoản mục Guest supplies), gắn nhân viên.
- Hàng trả về xe/kho **không** được ghi là tiêu hao âm (lỗi trong file Excel cũ) — là phiếu lĩnh ngược.

## Minibar theo phòng — tính tiền khi check-out (MVP)
Xem quy tắc đầy đủ `05-BUSINESS-RULES.md` mục 7.2 và ca test `11-TESTING.md` mục 4.

Màn hình:
- Lễ tân `/[p]/frontdesk/minibar`: yêu cầu kiểm → nhận kết quả → Đã thu (folio) / Đề nghị miễn.
- Buồng phòng `/m/[p]/minibar`: danh sách phòng chờ kiểm (thông báo đẩy), lưới món, ghi số thiếu, cờ sắp hết hạn.
- Văn phòng `/[p]/housekeeping/minibar`: tồn từng phòng, bổ sung hàng loạt theo tầng, đối soát ngày, báo cáo lãi gộp, chỉ số Lavie bán / Dasani cấp trên đêm phòng.

Quy tắc biên:
- Phòng có phiếu kiểm minibar chưa xong mà lễ tân chuẩn bị giao cho khách mới → hệ thống **không** chặn được PMS (không tích hợp), chỉ hiện cảnh báo trên màn hình lễ tân.
- Hàng minibar sắp hết hạn (≤ 30 ngày [cấu hình]) → danh sách thu hồi về `minibar_main`.
- Kiểm đột xuất (`trigger = 'audit'`) 10% phòng mỗi tháng: thiếu mà không có phiếu check-out tương ứng → thất thoát, gắn ca buồng phòng gần nhất.
