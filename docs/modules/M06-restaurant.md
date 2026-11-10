# M06 — Nhà hàng (F&B) + Đặt tiệc

Module mới (T-047 sau: "xây dựng chức năng cho nhà hàng") — lời giải cho
"bếp chưa thấy": vai trò chef trước đây không có màn nào. Dữ liệu gốc đã có
trong 4 file Excel (đặc biệt `Lst_2020_DL_Buffet.xlsx`: Menu 75 món,
`02 DL góc` 358 dòng định lượng; `Lst_Alacarte_foodcost.xlsx`: 53 dòng /
6 món) và luồng seed đã bóc tách items làm dữ liệu khởi đầu (Q158).

## 1. Phạm vi MVP

1. **Danh mục món ăn / công thức** — món (`recipes`, kind `dish` /
   `buffet_batch` / `set_menu`), nhóm món (nhóm Bravo: hot, salad,
   dessert, bread, cold cut, noodle, cereal, egg — lưu free-text),
   giá bán, trạng thái, `portions_per_batch` (bếp trưởng điền sau —
   Excel không có), `diet_flags` (vd set lactose-free). Định lượng NVL
   theo món (`recipe_lines`, theo `recipe_versions` — xem §2).
   Foodcost tự tính từ **giá trần hiện hành** (`ceiling_prices`); dòng
   nào chưa có giá trần thì foodcost = NULL + cờ `has_unknown_cost`
   (không dùng giá Excel 2018–2020 đã cũ).
2. **Màn bếp cho chef** — thực đơn hôm nay (món đang bán), phiên buffet
   hôm nay, tiệc hôm nay (đã xác nhận / đang diễn ra), bảng chuẩn bị
   NVL gộp (định lượng × số phần, xem §3) + link sang phiếu lĩnh T-030
   (không chế luồng kho mới).
3. **Ghi nhận bán hàng theo món theo ca/ngày** (`dish_sales`: số lượng,
   đơn giá, thành tiền) + **báo cáo doanh thu F&B** — nối vào T-044
   (`RPT_FNB_REVENUE`, xem §5).
4. **Quản lý phiên buffet** — phiên (ngày, buổi sáng/trưa/tối, số khách,
   giá/khách), món trong phiên; đóng phiên ghi doanh thu buffet theo
   khách vào `dish_sales` (source `buffet`).
5. **Đặt tiệc (banquet)** — khách đặt, ngày/giờ, sảnh/khu vực (free-text,
   chưa có bảng sảnh riêng), số bàn/khách, thực đơn tiệc chọn từ món đã
   có, tiền cọc, trạng thái `new → confirmed → in_progress → completed /
   cancelled`. Khi xác nhận: kiểm tra trùng sảnh + khung giờ (xem §4).
   Khi hoàn thành: ghi doanh thu từng món vào `dish_sales`
   (source `banquet`).

**Không làm:** POS tích hợp máy bán hàng ngoài; bảng sảnh riêng;
tự sinh phiếu lĩnh NVL từ tiệc/buffet (xem Q169); `pos_item_map` (A7 —
chờ có POS).

## 2. Bảng (migration 20261109500000)

Theo `docs/03-DATA-MODEL.md` A7 (P2 — "tạo bảng sớm"), thu gọn cho MVP:

| Bảng | Cột chính | Ghi chú |
|---|---|---|
| `recipes` | `org_id`, `code` (unique/org), `name`, `kind` (`dish`,`buffet_batch`,`set_menu`), `group_name`, `yield_qty`, `yield_uom`, `portions_per_batch`, `diet_flags text[]`, `sale_price`, `is_active`, `notes` | `code` vd `Bu_1` (buffet) — giữ mã Excel để đối chiếu |
| `recipe_versions` | `recipe_id`, `version_no`, `valid_from`, `status` (`draft`,`active`,`retired`), `created_by` | Mỗi lần `recipe_save` tạo version mới `active`, version `active` cũ → `retired` |
| `recipe_lines` | `version_id`, `item_id?`, `sub_recipe_id?`, `qty`, `uom`, `loss_pct` | CHECK đúng 1 trong 2 (A7); `sub_recipe_id` → `recipes(id)` |
| `buffet_sessions` | `property_id`, `business_date`, `meal` (`breakfast`,`lunch`,`dinner`), `guest_count`, `price_per_guest`, `status` (`planned`,`open`,`closed`,`cancelled`), `cancel_reason`, `notes` | Unique `(property_id, business_date, meal)` khi chưa hủy (partial index) |
| `buffet_session_dishes` | `session_id`, `recipe_id`, `planned_qty`, `note` | |
| `dish_sales` | `property_id`, `business_date`, `recipe_id?`, `source` (`manual`,`buffet`,`banquet`), `ref_id?`, `qty`, `unit_price`, `amount`, `voided_at?`, `voided_by?` | `recipe_id` NULL = doanh thu buffet gộp theo khách; `amount = qty × unit_price` (Postgres) |
| `banquets` | `property_id`, `customer_name`, `customer_phone`, `event_date`, `start_time`, `end_time`, `hall`, `tables_count`, `guests_count`, `deposit_amount`, `status` (`new`,`confirmed`,`in_progress`,`completed`,`cancelled`), `cancel_reason`, `notes` | `hall` free-text (vd "Sảnh A") — chưa có bảng sảnh |
| `banquet_dishes` | `banquet_id`, `recipe_id`, `qty`, `unit_price`, `note` | `unit_price` = snapshot `sale_price` lúc lưu |

Quy tắc chung (AGENTS.md + mẫu T-042): `unique(id, org_id)`; RLS bật 100%
+ policy SELECT-only (`in (select public.my_property_ids())` + `has_perm`
theo mã quyền §6 — TUYỆT ĐỐI KHÔNG `= any`); write-guard trigger
(`app.restaurant_guard_bypass`) chặn ghi trực tiếp — mọi ghi qua RPC
`SECURITY DEFINER`; `set_updated_at()` trigger.

## 3. RPC (Postgres tính tiền, JS chỉ hiển thị)

| RPC | Quyền | Hành vi |
|---|---|---|
| `recipe_foodcost(p_recipe_id)` | — (helper, không grant) | Tổng định lượng version `active` × giá trần hiện hành; NULL nếu dòng nào thiếu giá. Đệ quy tối đa 3 tầng cho `sub_recipe_id` (tránh vòng lặp) |
| `recipe_save(p_property_id, p_recipe jsonb)` | `restaurant.dish.manage` | Upsert món + version mới + lines (validate: kind, code unique/org, mỗi line đúng 1 `item_id`/`sub_recipe_id`, `qty > 0`) |
| `recipe_set_active(p_property_id, p_recipe_id, p_is_active)` | `restaurant.dish.manage` | Bật/tắt món |
| `restaurant_kitchen_today(p_property_id, p_business_date)` | `restaurant.view` | Món đang bán + phiên buffet hôm nay + tiệc hôm nay + bảng NVL chuẩn bị gộp |
| `buffet_session_save(p_property_id, p_session jsonb)` | `restaurant.buffet.manage` | Upsert phiên + món trong phiên |
| `buffet_session_close(p_property_id, p_session_id, p_guest_count, p_price_per_guest)` | `restaurant.buffet.manage` | `planned`/`open` → `closed`; ghi 1 dòng `dish_sales` (source `buffet`, `recipe_id` NULL) |
| `buffet_session_cancel(p_property_id, p_session_id, p_reason)` | `restaurant.buffet.manage` | → `cancelled` |
| `dish_sale_record(p_property_id, p_business_date, p_recipe_id, p_qty, p_unit_price)` | `restaurant.sale.record` | Ghi bán tay; chặn ngày tương lai (giờ VN), `qty > 0`, món phải `is_active` |
| `dish_sale_void(p_property_id, p_sale_id)` | `restaurant.sale.record` | Đánh dấu hủy (không xóa dòng — giữ sổ); chỉ hủy dòng `manual` |
| `restaurant_sales_summary(p_property_id, p_from, p_to)` | `restaurant.view` | Tổng + theo ngày + theo món (loại dòng đã void) |
| `banquet_save(p_property_id, p_banquet jsonb)` | `restaurant.banquet.manage` | Upsert tiệc + món (validate: `end_time > start_time`, `guests_count > 0`, `deposit >= 0`) |
| `banquet_confirm(p_property_id, p_banquet_id)` | `restaurant.banquet.manage` | `new` → `confirmed`; **kiểm tra trùng sảnh**: cùng KS + sảnh + ngày + khung giờ giao nhau + trạng thái `confirmed`/`in_progress` → `ERR_BANQUET_HALL_CONFLICT` |
| `banquet_start(p_property_id, p_banquet_id)` | `restaurant.banquet.manage` | `confirmed` → `in_progress` |
| `banquet_complete(p_property_id, p_banquet_id)` | `restaurant.banquet.manage` | `in_progress` → `completed`; ghi `dish_sales` từng món (source `banquet`) |
| `banquet_cancel(p_property_id, p_banquet_id, p_reason)` | `restaurant.banquet.manage` | `new`/`confirmed` → `cancelled` |
| `_report_fnb_revenue(p_property_id, p_params)` + nhánh `RPT_FNB_REVENUE` trong `report_get` | `report.view.rpt_fnb_revenue` | Doanh thu + foodcost + lãi gộp từng món (theo `dish_sales` chưa void); dòng buffet gộp foodcost NULL |

**Đọc danh sách (UI):** đọc trực tiếp qua RLS (mẫu T-041/T-042 —
không RPC list/get), ép kiểu có chủ đích vì `database.types.ts` chưa
sinh lại; ghi chỉ qua RPC. Lỗi: `ERR_FORBIDDEN:<quyền>` (42501) khi
thiếu quyền; `ERR_INVALID_STATUS` khi sai trạng thái;
`ERR_INVALID_VALUE` khi dữ liệu không hợp lệ.

**Bảng NVL chuẩn bị (kitchen_today):** với mỗi món trong phiên buffet /
tiệc hôm nay, lấy định lượng version `active` × số phần; nếu
`portions_per_batch` đã điền thì số mẻ = số phần / `portions_per_batch`
(làm tròn lên), ngược lại giả định định lượng là **theo phần** (× số
phần). Đây là giả định tạm — bếp trưởng phải xác nhận
`portions_per_batch` từng món (xem Q167); số liệu chỉ mang tính chuẩn bị,
không trừ kho.

## 4. Trùng sảnh khi xác nhận tiệc

Kiểm tra đơn giản theo sảnh (text, so khớp chính xác sau khi trim) +
ngày + khung giờ giao nhau (`start < other_end AND end > other_start`),
chỉ xét tiệc `confirmed`/`in_progress` cùng KS. Lý do làm luôn thay vì
chỉ ghi Q: đặt trùng sảnh là lỗi vận hành thật (2 tiệc cùng sảnh cùng giờ),
kiểm tra này đơn giản + đảo ngược được (sửa giờ/sảnh là xong). Nếu Duy
muốn cho phép trùng (vd sảnh chia đôi được), gỡ kiểm tra này bằng 1 câu
SQL — xem Q166.

## 5. Báo cáo F&B (T-044)

Thêm mã `RPT_FNB_REVENUE` (slug `fnb-revenue`, param `range`): cột món,
số lượng, doanh thu, foodcost, lãi gộp, biên lãi. Nguồn: `dish_sales`
chưa void trong kỳ; foodcost lấy `recipe_foodcost` tại thời điểm chạy
báo cáo (giá trần hiện hành — không phải giá lúc bán; ghi chú trong
báo cáo). Thẻ báo cáo thứ 11 tự hiện ở `/reports` khi có quyền
(`REPORT_META` — không sửa trang chỉ mục).

## 6. Quyền (mã mới — AGENTS.md quy tắc 10)

| Mã quyền | Tên | Gán cho |
|---|---|---|
| `restaurant.view` | Xem nhà hàng | chef, outlet_head, front_desk, bartender, owner, gm |
| `restaurant.dish.manage` | Quản lý món ăn + công thức | chef, outlet_head, owner, gm |
| `restaurant.sale.record` | Ghi nhận bán hàng | front_desk, outlet_head, chef, owner, gm |
| `restaurant.buffet.manage` | Quản lý phiên buffet | chef, outlet_head, owner, gm |
| `restaurant.banquet.manage` | Quản lý đặt tiệc | front_desk, outlet_head, owner, gm |
| `report.view.rpt_fnb_revenue` | Xem báo cáo doanh thu F&B | owner, gm, internal_audit (theo mẫu `rpt_minibar`) |

Nav: mục "Nhà hàng" (nhóm Vận hành, icon `UtensilsCrossed`), hiện khi có
bất kỳ mã `restaurant.*` nào; route `/[property]/restaurant/*`:
`dishes`, `kitchen`, `sales`, `buffet`, `banquets`. Màn bếp là màn chính
của chef (trả lời "bếp chưa thấy").

## 7. Dữ liệu khởi đầu + việc còn lại

- Seed items đã có (luồng 8: 668 items). **Món + định lượng từ Excel
  CHƯA nhập** — cần task nhập riêng sau khi bảng có (map 75 món buffet
  + 53 dòng alacarte + 358 dòng định lượng theo `recipe_lines`; bếp
  trưởng điền `portions_per_batch` từng món — xem Q167/Q168).
- Sau khi nhập món, foodcost + màn bếp + báo cáo F&B mới có số thật.
- Test: `supabase/tests/restaurant_test.sql` (pgTAP, plan theo số
  assertion); chạy trên DB thật sau db push (VM không có Docker).
- Câu hỏi mở: Q166–Q170 (`docs/OPEN-QUESTIONS.md`).
