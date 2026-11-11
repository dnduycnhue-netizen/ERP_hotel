# ADR-010 — Ngoại lệ: ghi trực tiếp bảng danh mục trong `src/features/master/actions.ts`

- Ngày: 11/11/2026
- Trạng thái: Đã chấp nhận (theo review của Claude + chỉ thị Duy 11/11 "làm luôn")
- Liên quan: `AGENTS.md` §5, `docs/09-API-RPC.md`, migration
  `20261109130000_master_data_crud.sql` và
  `20261109160000_suppliers_pricing.sql`,
  `src/features/master/actions.ts`

## Bối cảnh

`AGENTS.md` §5 quy ước "Server Action gọi RPC, không viết logic nghiệp vụ
trong TypeScript". Nhưng `src/features/master/actions.ts` (1.140 dòng) ghi
trực tiếp vào bảng danh mục bằng client Supabase (`insert` / `update` /
`delete` / `upsert`) thay vì gọi RPC — review của Claude đã nêu đây là điểm
lệch quy ước. Quyết định này ghi lại vì sao lệch đó được chấp nhận, để
người review sau không "sửa" nó bằng cách bọc RPC cho mọi thao tác danh
mục.

## Quyết định

1. **Chỉ thao tác CRUD thuần túy trên 14 bảng danh mục được ghi trực
   tiếp.** Danh sách đầy đủ (đếm từ `actions.ts`):
   `items`, `item_groups`, `uoms`, `item_purchase_units`,
   `expense_categories`, `warehouses`, `rooms`, `room_types`, `outlets`,
   `outlet_types`, `suppliers`, `price_agreements`,
   `price_agreement_lines`, `ceiling_prices`.
2. **An toàn vì 3 lớp, không lớp nào nằm trong TypeScript:**
   - Client dùng là client server **theo phiên người dùng**
     (`createClient` từ `@/lib/supabase/server`), không dùng service-role
     key — RLS vẫn áp dụng đầy đủ.
   - Mọi policy ghi của các bảng trên kiểm tra quyền bằng `has_perm`
     (migration `20261109130000_master_data_crud.sql` và
     `20261109160000_suppliers_pricing.sql`):
     `item.manage` cho items, item_groups, uoms, item_purchase_units,
     expense_categories, rooms, room_types, outlets, outlet_types;
     `warehouse.manage` cho warehouses; `supplier.manage` cho suppliers;
     `price.agreement.manage` cho price_agreements và
     price_agreement_lines; `price.ceiling.manage` cho ceiling_prices.
     Người không có quyền nhận 42501, `actions.ts` map thành câu "Bạn
     chưa được cấp quyền thực hiện thao tác này."
   - Đầu vào vẫn validate bằng Zod (`*SaveSchema.safeParse`) trước khi
     ghi; không có logic nghiệp vụ (tính tiền, SoD, trạng thái chứng từ)
     nào nằm trong TypeScript.
3. **Không bao giờ chạm sổ cái.** `actions.ts` không có lệnh nào tới
   `stock_moves`, `ap_ledger`, `stock_balances`, `item_costs` (grep = 0).
   Mọi thay đổi tồn kho và tiền vẫn đi qua RPC "post" theo quy tắc vàng 1.
4. **Thao tác có logic nghiệp vụ vẫn qua RPC.** Duyệt/từ chối NCC, đổi
   trạng thái NCC, duyệt yêu cầu đổi tài khoản ngân hàng, tạo mã tạm,
   gộp mã vật tư đã gọi `callMasterRpc` trong cùng file — ngoại lệ này
   chỉ bao CRUD thuần túy, không bao quyết định hay chuyển trạng thái.
5. **Hạn chế đã biết:** các lần ghi này không tự ghi dòng `audit_log`
   (không có lệnh ghi audit trong `actions.ts`). Chấp nhận vì đây là dữ
   liệu danh mục, không phải chứng từ; nếu sau này cần vết audit cho danh
   mục thì thêm trigger hoặc RPC riêng, không đổi cơ chế ghi.

## Hệ quả

- Không bọc RPC cho CRUD danh mục chỉ để "đúng quy ước" — đó là việc
  thừa, thêm bề mặt lỗi mà không thêm an toàn.
- Bảng danh mục mới chỉ được `actions.ts` chạm tới sau khi đã có policy
  ghi tương ứng kiểm tra `.manage` trong migration — policy là lớp kiểm
  tra quyền duy nhất ở đây, thiếu policy là lỗi chặn (không ai ghi được)
  chứ không phải lỗ hổng.
- Bảng `cost_centers` đã có sẵn policy ghi (`item.manage`) nhưng
  `actions.ts` hiện không chạm tới — không thuộc ngoại lệ này; khi nào
  có action cho nó thì rà lại theo cùng tiêu chí.
- Quy tắc vàng 1 (tồn kho/tiền qua RPC) và quy tắc vàng 2 (sổ cái bất
  biến) không thay đổi, không có ngoại lệ.
