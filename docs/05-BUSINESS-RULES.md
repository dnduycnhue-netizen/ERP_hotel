# 05 — Quy tắc nghiệp vụ & công thức

Mọi tham số có chữ **[cấu hình]** lưu trong bảng `settings` (`org_id`, `property_id?`, `key`, `value jsonb`) — không hard-code. Giá trị ghi ở đây là mặc định.

## 1. Trạng thái chứng từ

```
draft ──submit──▶ submitted ──approve (đủ bước)──▶ approved ──post──▶ posted ──reverse──▶ reversed
   │                  └──reject──▶ rejected (sửa lại → draft)
   └──cancel──▶ cancelled
```
- Chỉ `draft` được sửa. `posted` chỉ được `reverse` (tạo bút toán đảo), không xóa.
- Mọi chuyển trạng thái qua RPC, ghi `audit_log`.

## 2. Giá và thu mua

- Đơn giá PO **tự động**: hợp đồng khung còn hiệu lực → báo giá được chọn → giá trần (hàng chợ). Thu mua không gõ giá tay; trường hợp không có nguồn giá → `price_source = 'manual'` và bắt buộc qua bước duyệt bổ sung của gm.
- Vượt giá trần: `unit_price > ceiling_price` → `over_ceiling = true`, PO không submit được nếu không có lý do; thêm 1 bước duyệt `gm` bất kể giá trị.
- Ngưỡng cảnh báo giá: tăng > **10%** [cấu hình] so với trung bình 7 ngày giá nhập cùng mã → alert `PRICE_SPIKE`.
- Ma trận duyệt mặc định [cấu hình `approval_rules`]. Mỗi bước chỉ định **vai trò động** (hoặc người cụ thể); người duyệt phải có quyền `po.approve` tại KS và vai trò đó. Tên vai trò trong bảng dưới là vai trò mẫu:

| Giá trị PO | Bước |
|---|---|
| < 5 triệu | outlet_head (PR) → tự động duyệt PO nếu không vượt trần |
| 5–20 triệu | + cost_controller (hoặc accountant nếu `without_cc`) |
| 20–100 triệu | + gm |
| > 100 triệu | + owner |

- Mặt hàng có `allowed_channels` không chứa `market` thì không được mua chợ.

## 3. Nhận hàng

- `net_qty = gross_qty − tare_qty`; quy đổi sang đơn vị kho qua `item_purchase_units.factor_to_stock`.
- Dung sai so với PO: **±5%** [cấu hình theo nhóm hàng].
  - Lệch trong dung sai → nhận bình thường.
  - Lệch ngoài dung sai lần cân 1 → `needs_reweigh`, bắt buộc cân lại (lần 2 ghi đè lần 1, lưu cả hai).
  - Thiếu sau lần 2 → nhận số thực, PO còn mở phần thiếu (hoặc thu mua đóng).
  - Thừa sau lần 2 → chỉ nhập đến `qty PO × (1 + dung sai)`; phần dư cần `storekeeper` hoặc `gm` override có lý do (hàng nguyên con).
- QC `fail` → không nhập kho, sinh `supplier_returns` ngay. QC `conditional` → nhập vào kho `quarantine`, chờ quyết định trong 24h.
- Ảnh bắt buộc: ≥ 1 ảnh/dòng cho nhóm `food` thịt, cá, hải sản và mọi dòng `is_key_item`; ≥ 1 ảnh/phiếu cho nhóm khác [cấu hình].
- `unit_cost` dòng nhận = đơn giá PO (quy đổi về đơn vị kho), **không** nhập tay.
- Nhận thẳng vào bếp (`direct_issue_warehouse_id`): post ghi 2 cặp move: `receipt` vào kho tổng rồi `issue_out`/`issue_in` sang kho bếp, cùng `business_date`.

## 4. Mua chợ & tạm ứng

- Lệnh mua chợ = PO `channel = 'market'` gắn `advance_id`.
- Quyết toán trong **24h** [cấu hình] kể từ lúc chi tạm ứng; quá hạn → `overdue`, chặn tạm ứng mới của người đó.
- Số tiền quyết toán hợp lệ = Σ (số lượng **thực nhận** trên GRN × đơn giá trên biên nhận/hóa đơn). Không dùng số lượng người đi chợ tự khai.
- Đơn giá biên nhận > giá trần → bắt buộc giải trình; cảnh báo `MARKET_OVER_CEILING`.
- Người bán không có hóa đơn → tự sinh dòng `no_invoice_listings`.

## 5. Kho

- Không cho tồn âm ở bất kỳ kho nào (`ERR_NEGATIVE_STOCK`).
- Giá xuất: bình quân gia quyền tức thời theo pháp nhân (B4 trong `03-DATA-MODEL.md`). Phương pháp đặt trong `legal_entities.costing_method`, đổi chỉ khi đầu năm tài chính.
- Phiếu lĩnh: lệch giữa `issued` và `received` phải giải quyết trước khi khóa ca của outlet.
- Xuất theo mục đích không tính vào giá vốn hàng bán; gắn `cost_center_id` + `expense_category_id` bắt buộc.
- Hủy hàng > **1.000.000đ/phiếu** [cấu hình] → thêm duyệt gm.
- Mã tạm (`is_temp`): được dùng ngay khi nhận/mua chợ; quá **24h** chưa chuẩn hóa → alert; quá 72h → chặn dùng tiếp.

## 6. Kiểm kê

### 6.1 Kiểm kê tháng (MVP)
1. Mở đợt → đóng băng mọi giao dịch của kho được kiểm (RPC post trả `ERR_COUNT_FREEZE`).
2. Đếm mù trên điện thoại; ≥ 2 người, theo `SOD_COUNT_INDEPENDENT`.
3. Submit → hệ thống tính `book_qty`, `variance`.
4. Lệch → biên bản, lý do, người chịu trách nhiệm → gm duyệt → `adjust_count` theo giá bình quân.
5. Khóa kỳ chỉ khi mọi kho trong pháp nhân đã khóa đợt kiểm kê tháng.

### 6.2 Kiểm kê cuối ca Key Items (P2)
- Bắt buộc có `pos_imports` của ca trước khi mở phiếu đếm.
- Phiếu gồm Key Items của outlet + **2–3 mã ngẫu nhiên** [cấu hình].
- Thực tế = Tồn đầu ca + Lĩnh vào + Chuyển vào − Chuyển ra − Hủy duyệt − Xuất mục đích − Tồn đếm.
- Lý thuyết = Σ (món bán + comp có duyệt) × định mức phiên bản đang hiệu lực tại giờ bán ÷ yield.
- Lệch % = (Thực tế − Lý thuyết) ÷ Lý thuyết.
- Ngưỡng: rượu mạnh 1,5%, thịt cá 3%, rau 5%, mặc định 3% [cấu hình]; hồ sơ `without_cc` nhân 0,7.
- Vượt ngưỡng → đếm lại **đúng 1 lần**, không lộ số, không lộ chiều lệch. Vẫn lệch → lý do bắt buộc (`forgot_waste`, `pos_wrong_item`, `guest_return`, `tasting`, `unknown`) + ảnh → khóa ca → alert.

### 6.3 Rượu theo cân
`ml còn = (gram cân − tare_g) ÷ density_g_ml`. Ví dụ chai 700 ml, vỏ 450 g, tỷ trọng 0,95 → cân 800 g ⇒ 368 ml.

## 7. Buồng phòng & minibar

### 7.1 Xe đẩy (MVP)
- Đầu ca: lĩnh bù đủ par xe (phiếu lĩnh từ kho tầng → kho `trolley`).
- Cuối ca: đếm lại xe (đếm mù) → tiêu hao thực tế của ca = Tồn đầu + Lĩnh − Tồn cuối.
- MVP: ghi nhận tiêu hao (`purpose_issue` cost center Rooms). P2: so với lý thuyết = Σ phòng đã làm × chuẩn setup + yêu cầu thêm của khách.

### 7.2 Minibar theo phòng — tính tiền khi check-out (MVP)
1. Bổ sung minibar vào phòng = `transfer` từ kho `minibar_main` → kho `minibar_room` (không phải bán).
2. Khách check-out → lễ tân bấm "Yêu cầu kiểm minibar phòng X" → nhân viên buồng nhận thông báo, kiểm trên điện thoại, nhập số thiếu → hệ thống tính tiền theo `minibar_price_list` → hiện ngay cho lễ tân.
3. Lễ tân thu/ghi folio trên PMS (tay), bấm **Đã thu** + nhập `folio_no` → post `minibar_sale` (xuất kho phòng, doanh thu ghi nhận ở báo cáo).
4. Phát hiện sau khi khách đã đi → `late_charge`; gm duyệt xóa hoặc thu qua thẻ đã giữ.
5. Miễn phí (khách VIP, lỗi phòng) → `waived`, cần gm duyệt, có lý do.
6. Đối soát cuối ngày: Σ tiền minibar buồng phòng ghi nhận = Σ `charged` + Σ `waived` + Σ `late_charge`. Lệch ≠ 0 → alert `MINIBAR_MISMATCH`.
7. Nước Dasani miễn phí (nhóm `complimentary`) và Lavie bán (nhóm `minibar`) là **2 mã khác nhau**.

## 8. Công nợ & hóa đơn

- Khớp 3 chiều theo dòng: số lượng hóa đơn ≤ số lượng nhận (dung sai 0); đơn giá hóa đơn = đơn giá PO ± **1%** [cấu hình]; ngoài dung sai → `on_hold`.
- Chỉ hóa đơn `matched/approved` mới ghi `ap_ledger` (+). Trả hàng NCC ghi `ap_ledger` (−) khi post trả hàng.
- Mua dịch vụ: thay "phiếu nhận" bằng `service_acceptances`; chưa nghiệm thu thì không ghi công nợ.
- Đổi STK NCC trong 30 ngày gần nhất → mọi đề nghị thanh toán cho NCC đó cần thêm duyệt owner.

## 9. Hợp đồng dịch vụ định kỳ

- `service_schedule_generate()` tạo kỳ kế tiếp theo `billing_cycle`.
- Nhắc gia hạn trước `renew_notice_days` (mặc định 30).
- Kỳ chưa `accepted` → thanh toán bị chặn (`ERR_SERVICE_NOT_ACCEPTED`).

## 10. Khóa sổ

- Khóa ngày: gm hoặc accountant, theo kho; sau khóa không ghi `business_date` ≤ ngày khóa.
- Mở khóa: gm + lý do, ghi alert `UNLOCK` gửi owner ngay.
- Khóa kỳ: chief_accountant; điều kiện: kiểm kê tháng đã khóa, không còn PO `partially_received` quá 30 ngày chưa xử lý, không còn tạm ứng `overdue`.
- Mở lại kỳ: chief_accountant + gm.

## 11. Các chỉ số

| Chỉ số | Công thức |
|---|---|
| Food cost % (tháng) | (Tồn đầu + Mua − Tồn cuối ± Chuyển Food/Bev − Staff meal − Comp) ÷ Doanh thu food thuần |
| Flash cost ngày (ước tính) | Giá trị lĩnh/xuất vào outlet trong ngày ÷ Doanh thu ngày (nhập tay từ POS ở MVP) — luôn gắn nhãn "ước tính" |
| CPOR | Chi phí khoản mục ÷ Đêm phòng bán (`pms_daily_stats.rooms_sold`) |
| Chi phí buffet/khách (P2) | (Xuất buffet − Thu hồi) ÷ `breakfast_pax` |
| Số ngày tồn kho | Tồn cuối ÷ Tiêu hao bình quân ngày |
| Giá hiệu dụng NCC (P2) | Giá mua ÷ Yield chuẩn của NCC |
| Pax ratio (P3) | Lượng đặt ÷ Số khách dự kiến |
