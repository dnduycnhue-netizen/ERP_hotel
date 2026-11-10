-- 20261109420000_minibar_display_grants.sql
--
-- Q60 + Q61 (T-035): cap quyen hien thi minibar con thieu cho
-- front_desk / owner / gm.
--   * Q60: `item.view` — ten/ma mat hang trong phieu kiem minibar chi
--     doc duoc khi co `item.view` (policy `items_select`); thieu quyen
--     nay dong thieu chi hien so luong/don gia/thanh tien, ten hang
--     trong (UI hien `vi.minibar.itemNameHidden`).
--   * Q61: `stock.view_qty` — ton minibar tung phong (man van phong)
--     doc tu `stock_balances`, policy yeu cau `stock.view_qty` hoac
--     `stock.view_value`; thieu quyen UI chi hien ghi chu thay vi bang
--     ton. (Ban goc Q61 de xuat hk_supervisor; task Q60-Q61 chot cap
--     cho front_desk/owner/gm cung 1 dot voi Q60.)
--
-- Co che giong het migration T-035 20261109320000 (muc 6): INSERT ...
-- SELECT join theo ma vai tro (khong loc org, ap dung moi org hien
-- co), chi grant ma DA CO trong catalog `permissions` (khong tao ma
-- moi), `on conflict do nothing` — idempotent, chay lai an toan.
-- Khong co INSERT audit_log o day (chi grant quyen, khong ghi so).
--
-- Sau `supabase db push`, kiem chung tren production:
--   select r.code, rp.permission_code
--   from role_permissions rp join roles r on r.id = rp.role_id
--   where rp.permission_code in ('item.view', 'stock.view_qty')
--     and r.code in ('front_desk', 'owner', 'gm')
--   order by 2, 1;
-- Expect 6 rows moi (owner co the da co san 2 ma nay tu setup tay
-- 09/11 — on conflict do nothing nen khong trung).

insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('front_desk', 'item.view'),
  ('owner', 'item.view'),
  ('gm', 'item.view'),
  ('front_desk', 'stock.view_qty'),
  ('owner', 'stock.view_qty'),
  ('gm', 'stock.view_qty')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;
