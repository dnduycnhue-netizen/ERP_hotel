-- self_approval_toggle_test.sql (Q258, migration 20261109571000)
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

insert into public.organizations (id, name) values ('a5800000-0000-4000-8000-000000000001', 'Q258 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a5800000-0000-4000-8000-000000000101', 'a5800000-0000-4000-8000-000000000001', 'Q258', 'Entity Q258');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a5800000-0000-4000-8000-000000000201', 'a5800000-0000-4000-8000-000000000001', 'a5800000-0000-4000-8000-000000000101', 'PQ258', 'Property Q258', 'with_cc');
select public.seed_compact_roles('a5800000-0000-4000-8000-000000000001');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a5800000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q258@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a5800000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q258@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a5800000-0000-4000-8000-000000000a01', 'NV Q258 01', 'Bep Q258'),
  ('a5800000-0000-4000-8000-000000000a02', 'NV Q258 02', 'Quan ly Q258')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;

-- a01: Bep/Nha hang (tai khoan de xuat + duyet); a02: Quan ly (chuoi) tu bat/tat co.
insert into public.user_property_roles (user_id, role_id, property_id)
select 'a5800000-0000-4000-8000-000000000a01', r.id, 'a5800000-0000-4000-8000-000000000201'
from public.roles r where r.org_id = 'a5800000-0000-4000-8000-000000000001' and r.code = 'sm_kitchen';
insert into public.user_property_roles (user_id, role_id, property_id)
select 'a5800000-0000-4000-8000-000000000a02', r.id, null
from public.roles r where r.org_id = 'a5800000-0000-4000-8000-000000000001' and r.code = 'sm_manager';

-- 2 PR da gui, do a01 tao, buoc 1 giao cho vai tro sm_kitchen.
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_requests (id, org_id, legal_entity_id, property_id, doc_no, status, created_by) values
  ('a5800000-0000-4000-8000-000000000b01', 'a5800000-0000-4000-8000-000000000001', 'a5800000-0000-4000-8000-000000000101', 'a5800000-0000-4000-8000-000000000201', 'PR-Q258-1', 'submitted', 'a5800000-0000-4000-8000-000000000a01'),
  ('a5800000-0000-4000-8000-000000000b02', 'a5800000-0000-4000-8000-000000000001', 'a5800000-0000-4000-8000-000000000101', 'a5800000-0000-4000-8000-000000000201', 'PR-Q258-2', 'submitted', 'a5800000-0000-4000-8000-000000000a01');
insert into public.approvals (org_id, property_id, doc_type, doc_id, step, approver_role_id, required_perm)
select 'a5800000-0000-4000-8000-000000000001', 'a5800000-0000-4000-8000-000000000201', 'pr', d.id, 1, r.id, 'pr.approve'
from (values ('a5800000-0000-4000-8000-000000000b01'::uuid), ('a5800000-0000-4000-8000-000000000b02'::uuid)) as d(id)
cross join public.roles r where r.org_id = 'a5800000-0000-4000-8000-000000000001' and r.code = 'sm_kitchen';
select set_config('app.pr_po_guard_bypass', 'off', true);

create temp table a58_resp (key text primary key, resp jsonb);
grant all on a58_resp to authenticated;
create or replace function public._a58_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;

-- Mac dinh: chan tu duyet.
select public._a58_as('a5800000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.approval_decide('a5800000-0000-4000-8000-000000000201', 'pr', 'a5800000-0000-4000-8000-000000000b01', 'approved', null)$q$,
  'P0001', 'ERR_SOD_PR_CREATOR_APPROVER', 'by default a creator cannot approve their own PR');

-- Bep khong tu bat/tat duoc co.
select throws_ok(
  $q$select public.admin_setting_save('a5800000-0000-4000-8000-000000000001', null, 'rule.SELF_PR.enabled', '0')$q$,
  'P0001', 'ERR_FORBIDDEN', 'kitchen role cannot change the self-approval flag');

-- Quan ly xem va tat co.
select public._a58_as('a5800000-0000-4000-8000-000000000a02');
select ok(jsonb_path_exists(public.admin_settings_list('a5800000-0000-4000-8000-000000000001', null),
  '$[*] ? (@.key == "rule.SELF_PR.enabled" && @.value == "1" && @.source == "default")'),
  'manager sees the PR self-approval flag, ON by default');
select throws_ok(
  $q$select public.admin_setting_save('a5800000-0000-4000-8000-000000000001', null, 'rule.SELF_PR.enabled', '2')$q$,
  'P0001', 'ERR_CONFIG_INVALID', 'flag only accepts 0 or 1');
insert into a58_resp values ('off', public.admin_setting_save('a5800000-0000-4000-8000-000000000001', null, 'rule.SELF_PR.enabled', '0'));
select is((select resp ->> 'value' from a58_resp where key = 'off'), '0', 'manager turned the PR self-approval restriction off');

-- Tat co -> tu duyet duoc, co canh bao truy vet.
select public._a58_as('a5800000-0000-4000-8000-000000000a01');
insert into a58_resp values ('self', public.approval_decide('a5800000-0000-4000-8000-000000000201', 'pr', 'a5800000-0000-4000-8000-000000000b01', 'approved', null));
select is((select status from public.purchase_requests where id = 'a5800000-0000-4000-8000-000000000b01'), 'approved', 'with the flag off the creator can approve their own PR');

reset role;
select is((select count(*) from public.alerts where property_id = 'a5800000-0000-4000-8000-000000000201' and code = 'SOD_EXCEPTION_USED'),
  1::bigint, 'self-approval is traced by a SOD_EXCEPTION_USED alert');
select is((select count(*) from public.alerts where property_id = 'a5800000-0000-4000-8000-000000000201' and code = 'RULE_TOGGLED'),
  1::bigint, 'turning the flag off raised a RULE_TOGGLED alert');
select is((select count(*) from public.audit_log where table_name = 'settings' and new_data ->> 'key' = 'rule.SELF_PR.enabled'),
  1::bigint, 'the flag change is in audit_log');

-- Bat lai -> chan lai.
set local role authenticated;
select public._a58_as('a5800000-0000-4000-8000-000000000a02');
select public.admin_setting_save('a5800000-0000-4000-8000-000000000001', null, 'rule.SELF_PR.enabled', '1');
select public._a58_as('a5800000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.approval_decide('a5800000-0000-4000-8000-000000000201', 'pr', 'a5800000-0000-4000-8000-000000000b02', 'approved', null)$q$,
  'P0001', 'ERR_SOD_PR_CREATOR_APPROVER', 'turning the flag back on blocks self-approval again');

-- Co cua PR khong mo cho phieu huy.
reset role;
select is(public._rule_enabled('a5800000-0000-4000-8000-000000000201', 'SELF_WASTE'), true, 'waste self-approval flag is independent and still ON');
select is((select count(*) from public.roles r join public.role_permissions rp on rp.role_id = r.id
           where r.org_id = 'a5800000-0000-4000-8000-000000000001' and r.code = 'sm_manager' and rp.permission_code = 'admin.settings.manage'),
  1::bigint, 'manager role can change settings');

select finish();
rollback;
