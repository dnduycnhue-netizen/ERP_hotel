# ADR-007 — Nới lỏng quản trị tài khoản/quyền + tạo tài khoản/đổi mật khẩu (admin-relax)

- Ngày: 10/11/2026
- Trạng thái: Đã chấp nhận (theo chỉ thị Duy 10/11 10:38 + 10:40)
- Liên quan: `docs/09-API-RPC.md` §9 + §11, `docs/OPEN-QUESTIONS.md` Q118–Q132, migration `20261109400000_admin_relax.sql`, Edge Function `admin-create-user` / `admin-reset-password`

## Bối cảnh

Tạo tài khoản và cấp quyền đang vướng ở nhiều chỗ: không có giao diện tạo
tài khoản (Edge Function `admin-create-user` tồn tại nhưng không có chỗ nào
trong app gọi); Edge Function chỉ gán 1 vai trò và chỉ sinh mật khẩu ngẫu
nhiên; RPC chặn owner sửa/sao chép/cấp quyền cho vai trò `sys_admin`
(`ERR_SYSTEM_ROLE`); RPC + UI chặn quản trị tự gán vai trò/quyền cho chính
mình (`ERR_SELF_GRANT`); app không có màn đổi mật khẩu (tự đổi hay quản trị
đặt lại). T-047 cần 2 tài khoản test (người tạo purchaser + người duyệt
outlet_head/receiver) nhưng tạo tài khoản test đang vướng đúng các chặn này.

## Quyết định

1. **Chỉ nới phía quản trị, không đụng kiểm tra nghiệp vụ.**
   `has_perm`/`require_perm` trong RPC nghiệp vụ, quy tắc SoD trên chứng từ,
   nhận hàng mù, write-guard, sổ cái bất biến, RLS giữ nguyên 100%. Ranh
   giới này là lõi chống gian lận, không phải "ràng buộc" Duy muốn bỏ.
2. **Gỡ `ERR_SYSTEM_ROLE` khỏi `admin_role_save` (sửa + tạo),**
   `admin_role_copy`, `admin_role_set_permissions` (migration 400000,
   `CREATE OR REPLACE` chép nguyên thân hàm từ 20261109000001 rồi bỏ đúng
   khối chặn). Owner/sys_admin được sửa, sao chép và cấp/thu hồi mọi mã
   quyền cho bất kỳ vai trò nào, kể cả `sys_admin`.
3. **Gỡ `ERR_SELF_GRANT` khỏi `admin_user_assign_role` và**
   `admin_permission_override_set` (cùng migration), và gỡ khối chặn
   `isSelf` ở UI trong `AssignRoleForm`/`OverrideForm`. Lý do: người có
   `admin.users.manage` vốn đã tạo được tài khoản khác với mọi quyền nên
   khối tự cấp không thêm an toàn thật, chỉ thêm ma sát — và Duy là quản
   trị duy nhất lúc này.
4. **Giữ 3 chặn chống tự khóa hệ thống:** `ERR_SYSTEM_ROLE` ở
   `admin_role_deactivate`; `ERR_SELF_GRANT` ở `admin_user_revoke_role`
   và `admin_user_set_active(false)`; `ERR_LAST_ADMIN` /
   `admin_require_not_last_admin` (giữ ít nhất 2 quản trị chuỗi). Các nút
   PIN/Lock/Revoke vẫn disable khi xem chính mình. Cảnh báo xung đột SoD
   và cảnh báo quyền critical vẫn chỉ cảnh báo, không chặn lưu (đã như vậy
   từ trước).
5. **Tạo tài khoản 1 bước ở `/admin/users/new`:** form email + mật khẩu
   tạm (tự đặt tối thiểu 8 ký tự hoặc sinh ngẫu nhiên) + chọn 1..n vai trò
   + chọn phạm vi (toàn chuỗi hoặc 1 khách sạn), kèm 5 preset
   (người tạo mua hàng / người duyệt + nhận hàng / lễ tân / thủ kho /
   buồng phòng). Gọi Edge Function `admin-create-user` lần đầu từ app qua
   `supabase.functions.invoke` trong server action (mẫu mới — trước đây
   không có `functions.invoke` nào trong `src/`). Edge Function mở rộng
   nhận `roles[]` (mỗi vai trò kèm phạm vi riêng) + `password?`, giữ tương
   thích ngược với `roleId` đơn. Mật khẩu tạm trả về 1 lần, không ghi log.
6. **Đổi mật khẩu:** (a) tự đổi ở màn riêng `/settings/password`
   (mật khẩu hiện tại + mới + nhập lại, tối thiểu 8 ký tự, khác mật khẩu
   cũ; xác minh bằng `signInWithPassword` rồi `updateUser`, phiên hiện tại
   giữ nguyên); (b) quản trị đặt lại cho người khác bằng Edge Function mới
   `admin-reset-password` (mẫu `admin-create-user`, kiểm tra
   `admin.users.manage` chuỗi, ghi `audit_log` event
   `admin_password_reset`, không đặt lại mật khẩu của chính mình qua đường
   này). Không migration riêng cho đổi mật khẩu (Auth lo phần mật khẩu).
7. **Không mã quyền mới.** Cả 2 tính năng tái dùng `admin.users.manage`
   (chuỗi); tự đổi mật khẩu không cần quyền quản trị (mọi người đăng nhập
   đều đổi được mật khẩu của mình).
8. **Không cờ tài khoản test, không giới hạn số tài khoản.** Tài khoản test
   là tài khoản thật, nhận diện bằng mã NV tiền tố `TEST` / email
   `@erp.internal` (xem Q128, Q129).

## Hệ quả

- `supabase/tests/admin_users_test.sql`: 5 kiểm tra (6, 7, 18, 20, 22)
  đổi từ `throws_ok` sang `ok` cho đúng hành vi mới; `plan(35)` giữ nguyên.
- Thêm `supabase/tests/admin_relax_test.sql` (`plan(13)`): 12 kiểm tra gỡ/giữ
  + 1 kiểm tra cuối `num_failed() = 0` (quy ước đếm như các file pgTAP khác).
- Chưa thống nhất: mật khẩu lần đầu ở `(auth)/set-password` yêu cầu tối
  thiểu 12 ký tự, mật khẩu tạm + tự đổi mật khẩu mới yêu cầu tối thiểu 8
  ký tự (xem Q132).
