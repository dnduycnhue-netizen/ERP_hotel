-- 20261109450000_chef_kitchen_visibility.sql
--
-- Kitchen visibility: vai tro `chef` (Bep truong / Bep) khong thay duoc
-- khu vuc bep cua minh trong app.
--
-- Diagnosis (kiem chung tu code + seed, 10/11/2026):
--   * Chef KHONG phai vai tro rong: migration 140000 gan 8 quyen
--     (pr.create, pr.approve, requisition.create, requisition.approve,
--     requisition.receive, waste.propose, count.perform, item.view),
--     200000 them attachment.upload/view, 260000 them purpose_issue.post
--     (tong 11 quyen). Voi tap nay sidebar chi hien Tong quan, Thu mua,
--     Kho (phieu linh / huy hang / kiem ke — KHONG co tab Ton kho) va
--     Danh muc.
--   * 2 quyen doc thieu khien khu bep vo hinh voi bep truong:
--       - `receiving.view`: nav "Nhan hang" (nav-items.ts:91, can hien
--         khi co receiving.view hoac supplier_return.post) an hoan toan;
--         mobile-nav cung an tile "Nhan hang". Bep truong khong thay
--         duoc phieu nhan hang — ke ca nhan thang vao bep
--         (direct_issue_warehouse_id, 05 SS3 + M04).
--       - `stock.view_qty`: tab "Ton kho" trong khu Kho an
--         (inventory-nav.tsx: canStock = stock.view_qty ||
--         stock.view_value); RLS tren stock_balances cung chan doc so
--         luong ton. Bep truong quan ly bep + kiem ke thuc pham (mo ta
--         vai tro trong 140000) nhung khong thay duoc ton kho bep.
--   * Khong them nav item moi: khong co man hinh bep rieng de tro toi —
--     bang `recipes` chua ton tai, dinh muc/foodcost/buffet la P2
--     (03-DATA-MODEL.md A7, 04-SECURITY-RLS.md SS5.2, 07-IMPORT-MIGRATION.md;
--     T-014 chi import Excel). Xem Q148.
--   * Khong co outlet "Bep chinh" hay kho bep nao duoc seed cho property
--     production (140000 chi seed outlet_types + 5 kho MAIN/TRANSIT/
--     QUARANTINE/DISPOSAL/MINIBAR_MAIN; outlet rows chi co trong seed.sql
--     local). Can setup tay — xem Q149.
--
-- Fix: gan them 2 quyen doc tren cho `chef`, dong thoi khang dinh lai
-- toan bo 11 quyen hien co (phong truong hop giong 150000: migration ghi
-- da ap nhung rows khong co tren production — xem 170000).
-- Co y KHONG gan: `receiving.perform`/`receiving.post` (nhan hang mu +
-- PIN + SoD la viec cua thu kho / nhan hang ca sang), `stock.view_value`
-- (gia tri ton la du lieu nhay cam ve gia von), `count.view_variance`
-- (nguoi dem khong duoc thay chenh lech — quy tac dem mu).
--
-- Safety: pure INSERT ... ON CONFLICT DO NOTHING, join tren role code
-- (khong loc is_system, theo bai hoc T-013/170000). Idempotent.
-- Khong doi RLS, khong doi has_perm/require_perm, khong them bang/RPC.
-- Sau `supabase db push`, verify tren production:
--   select r.code, rp.permission_code
--   from role_permissions rp join roles r on r.id = rp.role_id
--   where r.code = 'chef' order by 2;
-- Expect 13 rows (11 cu + receiving.view + stock.view_qty).

insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('chef', 'pr.create'),
    ('chef', 'pr.approve'),
    ('chef', 'requisition.create'),
    ('chef', 'requisition.approve'),
    ('chef', 'requisition.receive'),
    ('chef', 'waste.propose'),
    ('chef', 'count.perform'),
    ('chef', 'item.view'),
    ('chef', 'attachment.upload'),
    ('chef', 'attachment.view'),
    ('chef', 'purpose_issue.post'),
    ('chef', 'receiving.view'),
    ('chef', 'stock.view_qty')
) as rp(role_code, permission_code)
  on r.code = rp.role_code
on conflict (role_id, permission_code) do nothing;
