-- compact_role_profiles_test.sql (Q257, migration 20261109570000)
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

insert into public.organizations (id, name) values ('a5700000-0000-4000-8000-000000000001', 'Q257 Org');

select is(public.seed_compact_roles('a5700000-0000-4000-8000-000000000001'), 7, 'seed creates 7 compact roles');
select is(public.seed_compact_roles('a5700000-0000-4000-8000-000000000001'), 7, 'seed is idempotent (still 7 roles)');

create temp table q257_perms as
select r.code as role_code, rp.permission_code as perm
from public.roles r
join public.role_permissions rp on rp.role_id = r.id
where r.org_id = 'a5700000-0000-4000-8000-000000000001';

select is((select count(*) from public.roles where org_id = 'a5700000-0000-4000-8000-000000000001' and is_system), 7::bigint, 'all 7 roles are system roles');
select is((select count(*) from q257_perms), (select count(distinct (role_code, perm)) from q257_perms), 'no duplicated role permission');

select is((select count(*) from q257_perms where role_code = 'sm_owner'), 58::bigint, 'sm_owner has 58 permissions');
select is((select count(*) from q257_perms where role_code = 'sm_manager'), 73::bigint, 'sm_manager has 73 permissions');
select is((select count(*) from q257_perms where role_code = 'sm_accountant'), 43::bigint, 'sm_accountant has 43 permissions');
select is((select count(*) from q257_perms where role_code = 'sm_purchasing_store'), 30::bigint, 'sm_purchasing_store has 30 permissions');

-- Nhan hang mu: khong vai tro moi nao vua nhan hang vua xem PO.
select is((select count(*) from q257_perms where role_code = 'sm_purchasing_store' and perm in ('receiving.perform', 'receiving.post')), 0::bigint,
  'purchasing & store role cannot receive goods (blind receiving stays with receiver)');
select is((select count(distinct role_code) from q257_perms a
           where a.perm in ('receiving.perform', 'receiving.post')
             and exists (select 1 from q257_perms b where b.role_code = a.role_code and b.perm in ('po.view_qty', 'po.view_price'))),
  0::bigint, 'no compact role combines receiving with PO quantity/price visibility');

-- Quyet dinh Duy 13/11.
select ok(exists (select 1 from q257_perms where role_code = 'sm_owner' and perm = 'payment.approve')
      and exists (select 1 from q257_perms where role_code = 'sm_manager' and perm = 'payment.approve'),
  'payment.approve is held by both owner and manager roles');
select ok(exists (select 1 from q257_perms where role_code = 'sm_manager' and perm = 'admin.approval_rules.manage'),
  'manager can configure approval rules');
select ok((select count(*) from q257_perms where role_code = 'sm_manager' and perm in ('pr.approve', 'requisition.approve', 'waste.approve')) = 3,
  'manager can also approve PR, requisition and waste');
select is((select count(*) from q257_perms where role_code = 'sm_accountant' and perm in ('payment.approve', 'invoice.approve')), 0::bigint,
  'accountant does not approve its own invoices/payments');
select is((select count(*) from q257_perms where role_code = 'sm_owner' and perm in ('po.create', 'receiving.perform', 'invoice.manage')), 0::bigint,
  'owner role does no day-to-day operations');

select finish();
rollback;
