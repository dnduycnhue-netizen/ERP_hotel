-- Repair test: the 6 master-data role grants from migration
-- 20261109150000, re-applied by 20261109170000.
-- (Production 09/11: 20261109150000 recorded as applied but its 6 rows
-- were missing from role_permissions; only owner held the 3 codes.
-- This test asserts the repair migration restored them.)
--
-- Run via: supabase test db (needs Docker; cannot run on the agent VM).

begin;
select plan(6);

-- storekeeper: item.manage + warehouse.manage
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'storekeeper' and rp.permission_code = 'item.manage'),
  'repair: storekeeper has item.manage'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'storekeeper' and rp.permission_code = 'warehouse.manage'),
  'repair: storekeeper has warehouse.manage'
);

-- cost_controller + chief_accountant: item.manage
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'cost_controller' and rp.permission_code = 'item.manage'),
  'repair: cost_controller has item.manage'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chief_accountant' and rp.permission_code = 'item.manage'),
  'repair: chief_accountant has item.manage'
);

-- hk_supervisor + gm: room.manage
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'hk_supervisor' and rp.permission_code = 'room.manage'),
  'repair: hk_supervisor has room.manage'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'gm' and rp.permission_code = 'room.manage'),
  'repair: gm has room.manage'
);

select * from finish();
rollback;
