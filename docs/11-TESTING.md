# 11 — Kiểm thử

## 1. Tầng test

| Tầng | Công cụ | Bắt buộc cho |
|---|---|---|
| CSDL | pgTAP (`supabase test db`) | Mọi RPC ghi dữ liệu, mọi policy RLS, mọi quy tắc SoD |
| Đơn vị | Vitest | Schema Zod, hàm định dạng, quy đổi đơn vị phía client, Dexie queue |
| Đầu cuối | Playwright | Luồng chính trên viewport điện thoại (390×844) và laptop |

Viết test CSDL bằng cách đặt JWT giả: `set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>"}';`.

## 2. Ca test bắt buộc — sổ cái & giá vốn

1. Nhập 10 kg × 100.000 → avg 100.000. Nhập 10 kg × 120.000 → avg 110.000. Xuất 5 kg → giá xuất 110.000, tồn 15 kg.
2. Xuất quá tồn → `ERR_NEGATIVE_STOCK`.
3. UPDATE/DELETE `stock_moves` → `ERR_IMMUTABLE_LEDGER`.
4. Đảo phiếu nhận → số dư về như trước; đảo lần 2 → lỗi.
5. Ghi vào kỳ đã đóng → `ERR_PERIOD_CLOSED`.
6. Điều chuyển nội bộ cùng pháp nhân không đổi `item_costs.qty_on_hand`.
7. Trả hàng NCC dùng `unit_cost` dòng nhận gốc dù avg đã đổi.

## 3. Ca test bắt buộc — nhận hàng mù

1. `receiver` `select * from purchase_order_lines` → 0 dòng.
2. `receiving_get_task` không có khóa `qty`, `unit_price` trong JSON.
3. PO 10 kg, cân 9,4 kg (−6%) → `needs_reweigh = true`; cân lần 2 9,4 → nhận 9,4, PO còn mở 0,6.
4. PO 10 kg, cân 11 kg (+10%) lần 2 → nhập tối đa 10,5; phần dư cần override.
5. Người tạo PO gọi `receiving_post` → `ERR_SOD_PO_RECEIVER`.
6. Gửi lại cùng `client_uuid` → không tạo dòng mới.

## 4. Ca test bắt buộc — minibar

1. Bổ sung phòng 101: 2 Lavie, 2 Tiger (transfer). Tồn `minibar_main` giảm, tồn kho phòng tăng, `item_costs.qty_on_hand` không đổi.
2. Check-out: thiếu 1 Lavie, 1 Tiger → tổng = giá Lavie + giá Tiger theo bảng giá.
3. Lễ tân xác nhận thu + folio → move `minibar_sale`; kho phòng còn 1 + 1.
4. Đối soát ngày: ghi nhận = thu + miễn + late → không có alert. Bỏ trống 1 phiếu `pending_charge` qua ngày → alert `MINIBAR_MISMATCH`.
5. Đề nghị miễn bởi lễ tân, gm duyệt → `waived`; lễ tân tự duyệt → `ERR_FORBIDDEN`.

## 5. Ca test bắt buộc — kiểm kê

1. Người đếm đọc `v_count_sheet`: không có cột `book_qty`, `theoretical_qty`.
2. `count_submit` trả mảng `line_id` cần đếm lại, không có số.
3. Kho đang kiểm kê tháng → mọi post vào kho đó lỗi `ERR_COUNT_FREEZE`.
4. Điều chỉnh sau duyệt ghi `adjust_count` theo giá bình quân.

## 6. Ca test bắt buộc — phân quyền động

1. Tạo vai trò "Bếp phó" (sao chép Bếp trưởng), bỏ quyền `waste.approve` → user giữ vai trò này gọi `waste_decide` → `ERR_FORBIDDEN:waste.approve`.
2. Cấp `allow waste.approve` riêng cho user đó đến hết ngày mai → gọi được; quá hạn → lại bị chặn.
3. `deny po.approve` riêng cho GM tại KS01 → GM không duyệt được PO ở KS01 nhưng vẫn duyệt được ở KS02.
4. Gán Thủ kho với `warehouse_ids = [kho bếp]` → không post được phiếu của kho bar.
5. Vai trò `active = false` → mọi quyền từ vai trò đó mất hiệu lực.
6. Tự gán vai trò/quyền cho chính mình được phép có chủ đích từ migration `20261109400000` (admin-relax, 10/11/2026): `admin_user_assign_role` và `admin_permission_override_set` không còn chặn `ERR_SELF_GRANT` — người có `admin.users.manage` vốn đã tạo được tài khoản khác với mọi quyền nên khối tự cấp chỉ thêm ma sát, không thêm an toàn thật. Các guard còn giữ: gỡ quyền quản trị của người thứ 2 khi chỉ còn 2 → `ERR_LAST_ADMIN` (giữ ít nhất 2 quản trị chuỗi); tự thu hồi vai trò của chính mình (`admin_user_revoke_role`) và tự khóa tài khoản của chính mình (`admin_user_set_active`) vẫn → `ERR_SELF_GRANT`; vô hiệu hóa vai trò hệ thống (`admin_role_deactivate`) vẫn → `ERR_SYSTEM_ROLE`.
7. Một người có đủ mọi quyền (`po.create`, `po.approve`, `receiving.post`) vẫn bị `ERR_SOD_PO_CREATOR_APPROVER` và `ERR_SOD_PO_RECEIVER` trên cùng một PO.
8. Thay đổi quyền mức `critical` sinh alert `PERMISSION_CRITICAL_CHANGED`.

## 7. Dữ liệu mẫu (`supabase/seed.sql`)

- 1 org, 2 pháp nhân (`KS01`, `KS02`), mỗi pháp nhân 1 KS, `KS01` hồ sơ `with_cc`, `KS02` `without_cc`.
- Người dùng mẫu mỗi vai trò (mật khẩu `Test@12345`, PIN `1234`) — chỉ ở local/staging.
- ~60 vật tư lấy từ file Excel đã làm sạch (thịt, hải sản, rau, khô, rượu, amenities, minibar Lavie/Tiger/Coca, Dasani miễn phí).
- 3 NCC (doanh nghiệp, hộ kinh doanh, cá nhân không hóa đơn), 20 phòng, kho đầy đủ loại.
- Không seed dữ liệu thật của khách vào repo.
