-- Go-live MVP-A: cấp quyền quản lý danh mục còn thiếu cho vai trò mẫu.
--
-- Bối cảnh: migration 20261109130000_master_data_crud.sql yêu cầu quyền
-- `item.manage` / `warehouse.manage` / `room.manage` cho mọi thao tác ghi
-- danh mục (vật tư, kho, phòng), nhưng ma trận quyền trong
-- 20261109140000_golive_init_org_data.sql không gán 3 mã quyền này cho bất
-- kỳ vai trò mẫu nào. Kết quả: chỉ vai trò owner (được cấp tay đủ 109 quyền
-- trên production) sửa được danh mục; nhân viên (thủ kho, cost controller,
-- kế toán trưởng, giám sát buồng, tổng quản lý) bị chặn bởi RLS và `useCan`.
--
-- Phân công theo mô tả vai trò trong ma trận go-live:
--   * `item.manage` (tạo/cập nhật vật tư): thủ kho (quản lý vật tư trong
--     kho), cost controller (kiểm soát giá vốn, chuẩn hóa mã tạm),
--     kế toán trưởng (kiểm soát giá trần/kế toán). Không cấp cho thu mua:
--     thu mua chỉ tạo mã tạm (`item.temp.create`), chuẩn hóa do cost
--     controller làm (`item.temp.normalize`).
--   * `warehouse.manage` (tạo/cập nhật kho): chỉ thủ kho (quản lý kho là
--     nhiệm vụ của thủ kho).
--   * `room.manage` (tạo/cập nhật phòng): giám sát buồng (quản lý buồng
--     phòng) và tổng quản lý (điều hành toàn diện tại khách sạn).
-- Không bổ sung cho `owner`: trên production owner đã có đủ 109 quyền qua
-- cấp tay; trên DB mới owner giữ vai trò xem/duyệt theo ma trận go-live.
--
-- Chỉ chèn dòng (không đổi schema) nên không cần sinh lại database.types.ts.
-- Lũy thừa (idempotent): chạy lại không tạo trùng nhờ `on conflict do nothing`.

insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('storekeeper', 'item.manage'),
    ('cost_controller', 'item.manage'),
    ('chief_accountant', 'item.manage'),
    ('storekeeper', 'warehouse.manage'),
    ('hk_supervisor', 'room.manage'),
    ('gm', 'room.manage')
) as rp(role_code, permission_code)
  on r.code = rp.role_code and r.is_system = true
on conflict (role_id, permission_code) do nothing;
