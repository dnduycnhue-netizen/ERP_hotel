# M16 — Rà soát bảo mật phía client (chỉ báo cáo, không sửa)

- Trạng thái: **Đạt (không tìm thấy lỗi bảo mật phía client)**
- Thời gian: 13/11/2026 ~22:52–22:58
- Phạm vi: toàn bộ `src/` (code chạy ở trình duyệt + Server Actions + 3 route `/api/*`)
- Phương pháp: grep + đọc code các điểm nghi ngờ. Không đổi hành vi, không sửa code.

## Kết quả theo từng điểm trong đặc tả

| # | Điểm kiểm tra | Kết quả |
|---|---|---|
| 1 | `service_role`/secret trong code chạy ở trình duyệt | **Không có.** `grep service_role src/` trả về 0 dòng. Browser client chỉ dùng publishable key (`src/lib/supabase/client.ts` → `createBrowserClient(url, publishableKey)`). |
| 2 | `NEXT_PUBLIC_*` lộ khóa nhạy cảm | **Không.** Chỉ 3 biến: `NEXT_PUBLIC_VAPID_PUBLIC_KEY` (khóa công khai Web Push, theo thiết kế), `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (đều công khai theo thiết kế Supabase). |
| 3 | `dangerouslySetInnerHTML` | **Không có.** Cũng không có `eval(`, `new Function(`, `innerHTML`. |
| 4 | Log chứa PIN/mật khẩu/token | **Không.** Toàn `src/` chỉ có 1 log liên quan mật khẩu: `src/app/(auth)/set-password/actions.ts:25` — `console.error("Unable to set the account's initial password.", error)` (chạy phía server, log đối tượng lỗi của Supabase, không chứa giá trị mật khẩu). PIN dialog (`src/components/common/pin-dialog.tsx`) không log, không lưu localStorage/sessionStorage; PIN chỉ truyền cho màn cha gọi RPC, server kiểm tra `pin_hash`. Không có `localStorage`/`sessionStorage` nào chứa token/PIN/mật khẩu. |
| 5 | Route handler `/api/*` thiếu kiểm tra secret/quyền | **Đủ kiểm tra đăng nhập; quyền giao cho RPC + RLS.** 3 route (`/api/export/[kind]`, `/api/export/bank-transfer`, `/api/export/po/[id]`) đều gọi `getAuthenticatedUser` và trả 401 khi chưa đăng nhập (ghi chú trong code: proxy không redirect `/api/*` về /login nên route tự trả 401). Route không tự kiểm tra từng quyền mà gọi RPC export — RPC kiểm tra `has_perm` phía server và RLS lọc dữ liệu; lỗi RPC trả về qua `rpcErrorResponse`. Đây là mẫu đúng của repo, không phải lỗ hổng. Ghi chú: nếu sau này thêm route export mới, giữ nguyên mẫu này (401 + RPC kiểm quyền). |
| 6 | Server Action tính tiền bằng `number` rồi lưu | **Không.** `grep toFixed|Math.round` trong `src/**/actions.ts` trả về 0 dòng. Tiền tính trong Postgres bằng `numeric` theo quy tắc 7 (xác nhận bằng comment ở `money-text.tsx` và không có phép tính tiền nào trong actions). |
| 7 | So sánh tên vai trò thay vì `useCan`/`has_perm` (quy tắc 10) | **Không có chỗ nào quyết định quyền bằng tên vai trò.** `useCan`/`has_perm` xuất hiện ở 29 file components/app. Các chỗ nhắc tên vai trò chỉ để hiển thị (`role_name` trong bảng, `approver_role_name` trong timeline/PO PDF) hoặc preset ở form tạo tài khoản admin (`PRESET_ROLES.purchaser.includes(role.code)` — chọn mặc định khi tick, không phải kiểm tra quyền). `app-sidebar.tsx:61` (`isAdmin = mode === "admin"`) chỉ đổi giao diện theo chế độ admin, không mở dữ liệu. |

## Không tìm thấy lỗi — không có mục "Chuyển Claude Code" cho M16

- Không có secret nào cần xoay, không có route nào cần vá gấp.
- Ghi chú duy nhất (không phải lỗi): route export dựa hoàn toàn vào RPC/RLS để chặn quyền; nếu một RPC export nào đó quên kiểm tra quyền thì route không chặn lại được. Đây là thiết kế hiện tại, không phải lỗi phát hiện trong đợt rà này (pgTAP đã bao phủ RPC export ở các suite trước).
