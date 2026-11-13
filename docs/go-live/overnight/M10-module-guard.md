# M10 — Chặn module tắt (module-off guards)

- Ngày: 13/11/2026 (đêm). Phạm vi: chỉ đọc code + kiểm tra live trạng thái BẬT (đã có từ M9/B3).
- Kết luận: **Đạt — guard chính hoạt động; 2 lỗ hổng + 1 điểm cần sửa tài liệu, chuyển Claude Code.**
- Commit: `T-M10` (xem git log).

## 1. Kiến trúc guard (đã rà code)

Chỉ có 2 module tùy chọn: `hk_frontdesk` (minibar, xe đẩy, chuẩn setup phòng, PMS ngày)
và `restaurant` (món/công thức, buffet, tiệc, bán hàng, nạp POS). Core (mua hàng, nhận hàng,
kho, tài chính, báo cáo chung) luôn bật.

- **Tầng UI — 6 layout chặn hiển thị:** kiểm tra `getPropertyModules()` trước, module tắt
  thì render `<ModuleDisabled>` ("Module đang tắt: <tên>"):
  - Desktop: `frontdesk/layout.tsx`, `housekeeping/layout.tsx`, `restaurant/layout.tsx`
    (đều `hk_frontdesk` / `restaurant` tương ứng).
  - Mobile: `m/[p]/minibar/layout.tsx`, `m/[p]/restaurant/layout.tsx`,
    `m/[p]/trolley/layout.tsx`.
  - Sau guard module, các layout này còn kiểm tra quyền thô qua RPC `my_permissions`
    (không lọc module) rồi `notFound()` nếu thiếu quyền — thứ tự đúng (module trước,
    quyền sau).
- **Menu:** desktop `(app)/[property]/layout.tsx:52` và mobile `m/[p]/layout.tsx:81`
  đều dùng `getModuleAwarePermissions()` → đưa vào `PermissionsProvider`; sidebar,
  `InventoryNav`, mobile bottom nav đều dùng `useCan()` trên danh sách đã lọc → mục
  của module tắt tự ẩn khỏi menu. Báo cáo: `src/features/report/queries.ts:51` cũng
  dùng danh sách đã lọc → báo cáo của module tắt bị ẩn.
- **Tầng DB — trigger `_module_guard`** (migration 569000, Q254): `BEFORE INSERT OR UPDATE`
  trên 13 bảng → gọi `require_module()` → raise `ERR_MODULE_DISABLED`; lỗi này đã map
  sang tiếng Việt trong `errors.vi.ts` ("Module này đang tắt ở khách sạn này. Hãy nhờ
  quản trị bật lại trong Quản trị → Module."). 13 bảng: `minibar_checks`,
  `minibar_check_lines`, `minibar_price_list`, `pms_daily_stats`, `room_setup_standards`,
  `trolley_par_levels`, `trolley_shifts` (hk_frontdesk) + `banquets`, `banquet_halls`,
  `buffet_sessions`, `dish_sales`, `pos_imports`, `pos_import_lines` (restaurant).
  Không có RPC nào gọi `require_module()` trực tiếp — chặn hoàn toàn dựa vào trigger.
- **Trang bật/tắt:** `/admin/modules` (quyền `admin.modules.manage`, owner/sys_admin).
  Mặc định không có dòng = BẬT; dữ liệu cũ giữ nguyên, bật lại dùng tiếp.

## 2. Kiểm chứng live (trạng thái BẬT — trạng thái TẮT KHÔNG test live)

- **Không test live trạng thái TẮT:** bật/tắt module trên production bị cấm theo
  handoff (thay đổi cấu hình hệ thống). Cả 2 khách sạn hiện đều bật đủ 2 module.
- **Bằng chứng trạng thái BẬT (đã có, không chạy lại):**
  - M9 đêm 13/11: owner mở được toàn bộ route có guard với nội dung thật —
    `/frontdesk/minibar` (1 phiếu MB-...-0001), `/housekeeping/minibar` (bảng giá 7 món),
    `/restaurant` (trang trung tâm), `/m/minibar`, `/m/restaurant`, `/m/trolley`.
  - Demo test B3 (chiều 13/11): `/admin/modules` hiện 2 khách sạn × 2 module, tất cả BẬT.
- Hành vi khi TẮT chỉ được xác minh bằng đọc code (mục 1 + mục 3), không bằng live.

## 3. Phát hiện (chuyển Claude Code)

### F-1. Trang `/inventory/pos-import` MỞ ĐƯỢC form khi module Nhà hàng tắt (UI)
- `inventory/layout.tsx` KHÔNG kiểm tra module, chỉ kiểm tra quyền thô qua
  `supabase.rpc("my_permissions")` (không lọc module). Trang pos-import kiểm tra
  `has_perm("pos.import")` trực tiếp (quyền thô, không qua module-aware).
- Hệ quả: tắt module Nhà hàng → mục "Nạp POS" ẩn khỏi menu (đúng), nhưng gõ trực tiếp
  URL vẫn mở form upload trông như hoạt động bình thường. Bấm nạp thì mới rớt ở
  trigger DB (`ERR_MODULE_DISABLED` → thông báo tiếng Việt) — dữ liệu an toàn,
  nhưng UX sai: form không nên hiện.
- Sửa đề xuất: trang pos-import (và mọi trang dưới layout không có guard mà kiểm tra
  quyền thuộc module) dùng `getModuleAwarePermissions()` hoặc kiểm tra
  `getPropertyModules()` rồi render `<ModuleDisabled>` như 6 layout kia.

### F-2. Trigger DB KHÔNG phủ 5 bảng nội dung của module Nhà hàng (tầng dữ liệu)
- Không có trigger `_module_guard` trên: `recipes`, `recipe_versions`, `recipe_lines`
  (định nghĩa món ăn), `banquet_dishes`, `buffet_session_dishes`.
- Nhận xét trong migration 569000 ("RPC ghi nào cũng bị chặn, không cần sửa từng RPC")
  KHÔNG đúng với 5 bảng này: không RPC nào gọi `require_module()` trực tiếp
  (grep toàn repo chỉ thấy trong chính 569000).
- Hệ quả: module Nhà hàng tắt → UI ẩn (layout guard) nên người dùng thường không vào
  được, nhưng gọi trực tiếp RPC/API vẫn ghi được món ăn / món trong tiệc / món trong
  buffet. Mức độ: thấp (cần gọi API trực tiếp), nhưng là lỗ hổng thực ở tầng dữ liệu.
- Sửa đề xuất: thêm 5 bảng trên vào vòng lặp tạo trigger trong 569000 (migration mới).

### F-3. Trigger chỉ chặn INSERT/UPDATE, không chặn DELETE
- Xóa dữ liệu module (ví dụ xóa phiếu minibar, xóa dòng bán hàng) khi module tắt vẫn
  chạy được. Mức độ: thấp. Sửa đề xuất: thêm `DELETE` vào trigger (cân nhắc: xóa khi
  tắt module có nên cho phép để dọn dữ liệu cũ không — cần Duy/Claude quyết).

### F-4. Tài liệu sai: demo-walkthrough §4.4 viết "vào /restaurant và /inventory → 'Module đang tắt'"
- `/inventory` là core, LUÔN mở khi module Nhà hàng tắt — chỉ mục "Nạp POS" ẩn khỏi menu.
  Câu đúng: `/restaurant` (và các trang con) → "Module đang tắt"; `/inventory` vẫn mở;
  trang nạp POS mở được form nhưng bấm nạp sẽ báo lỗi (F-1). Đã ghi vào danh sách sửa
  tài liệu của M18 (bản cập nhật sau M10).

### Ghi chú — không phải lỗi
- **Phòng (`rooms`, `room_types`) ở ngoài module:** quyền `room.manage` thuộc nhóm
  "Danh mục" (seed.sql / migration 08141000), KHÔNG nằm trong matcher `hk_frontdesk`
  (`minibar.*`, `hk.*`, `pms.input`, 2 báo cáo) và bảng `rooms` không có trigger.
  → Tắt `hk_frontdesk`, trang `/master/rooms` vẫn mở và sửa phòng vẫn chạy được.
  Coi là theo thiết kế (phòng là danh mục chung của khách sạn); nếu Duy muốn phòng
  thuộc module Buồng phòng thì cần bổ sung matcher + trigger — ghi nhận, không tự đổi.
- **`getPropertyModules()` fail-open khi lỗi đọc:** trả về `ALL_MODULES_ON` (chỉ để
  hiển thị); nếu RPC lỗi thì menu hiện đủ mục, nhưng layout guard + trigger DB vẫn
  chặn. Chấp nhận được, ghi nhận.
- `count_open`: ca kiểm kê chỉ đòi file POS khi module Nhà hàng đang BẬT (theo
  migration 569000) — đúng thiết kế, chưa test live (thuộc M3/M6).

## 4. Lệnh đã chạy

```text
grep/rà code: src/lib/modules/*, 6 layout guard, inventory/layout.tsx,
master/layout.tsx, report/queries.ts, migration 20261109569000, seed.sql
(không chạy migration, không đổi cấu hình, không gọi RPC ghi)
pnpm lint && pnpm typecheck && pnpm test   (gate sau khi viết báo cáo — xem commit)
```
