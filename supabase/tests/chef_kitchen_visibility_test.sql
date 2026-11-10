-- Chef kitchen visibility: migration 20261109450000 grants `chef` the
-- 2 missing read permissions (`receiving.view`, `stock.view_qty`) and
-- re-asserts the 11 grants from 140000/200000/260000, so the chef can
-- see the Receiving nav + the Stock tab (kitchen stock quantities).
-- Also guards the deliberate non-grants: chef must NOT get
-- `receiving.perform` (blind receiving + PIN + SoD belongs to the
-- storekeeper / morning receiver) nor `stock.view_value` (stock value
-- is cost-sensitive).
--
-- Run via: supabase test db (needs Docker; cannot run on the agent VM).

begin;
select plan(15);

-- 11 grants re-asserted from 140000 / 200000 / 260000
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'pr.create'),
  'chef: has pr.create (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'pr.approve'),
  'chef: has pr.approve (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'requisition.create'),
  'chef: has requisition.create (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'requisition.approve'),
  'chef: has requisition.approve (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'requisition.receive'),
  'chef: has requisition.receive (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'waste.propose'),
  'chef: has waste.propose (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'count.perform'),
  'chef: has count.perform (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'item.view'),
  'chef: has item.view (140000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'attachment.upload'),
  'chef: has attachment.upload (200000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'attachment.view'),
  'chef: has attachment.view (200000)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'purpose_issue.post'),
  'chef: has purpose_issue.post (260000)'
);

-- 2 new grants from 20261109450000
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'receiving.view'),
  'chef: has receiving.view (450000, NEW)'
);
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'chef' and rp.permission_code = 'stock.view_qty'),
  'chef: has stock.view_qty (450000, NEW)'
);

-- Deliberate non-grants (must stay absent)
select ok(
  not exists (select 1 from public.role_permissions rp
              join public.roles r on r.id = rp.role_id
              where r.code = 'chef' and rp.permission_code = 'receiving.perform'),
  'chef: must NOT have receiving.perform (blind receiving stays with storekeeper/receiver)'
);
select ok(
  not exists (select 1 from public.role_permissions rp
              join public.roles r on r.id = rp.role_id
              where r.code = 'chef' and rp.permission_code = 'stock.view_value'),
  'chef: must NOT have stock.view_value (stock value stays cost-sensitive)'
);

select * from finish();
rollback;
