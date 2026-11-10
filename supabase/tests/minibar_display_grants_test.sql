-- Q60/Q61 test: migration 20261109420000 cap `item.view` +
-- `stock.view_qty` cho front_desk / owner / gm (hien ten hang trong
-- phieu kiem minibar + bang ton phong).
-- Mau test giong supabase/tests/role_grants_repair_test.sql
-- (plan = so assertion; khong can fixture user vi chi doc
-- role_permissions theo ma vai tro, ap dung moi org).
--
-- Run via: supabase test db (needs Docker; cannot run on the agent VM).

begin;
select plan(6);

-- front_desk: item.view + stock.view_qty
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'front_desk' and rp.permission_code = 'item.view'),
  'q60-q61: front_desk has item.view'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'front_desk' and rp.permission_code = 'stock.view_qty'),
  'q60-q61: front_desk has stock.view_qty'
);

-- owner: item.view + stock.view_qty
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'owner' and rp.permission_code = 'item.view'),
  'q60-q61: owner has item.view'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'owner' and rp.permission_code = 'stock.view_qty'),
  'q60-q61: owner has stock.view_qty'
);

-- gm: item.view + stock.view_qty
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'gm' and rp.permission_code = 'item.view'),
  'q60-q61: gm has item.view'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'gm' and rp.permission_code = 'stock.view_qty'),
  'q60-q61: gm has stock.view_qty'
);

select * from finish();
rollback;
