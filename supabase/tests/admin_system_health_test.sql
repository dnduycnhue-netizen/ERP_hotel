-- admin_system_health_test.sql (Q249, migration 20261109565000)
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(7);

insert into public.organizations (id, name) values ('a4900000-0000-4000-8000-000000000001', 'Q249 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a4900000-0000-4000-8000-000000000101', 'a4900000-0000-4000-8000-000000000001', 'Q249', 'Entity Q249');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a4900000-0000-4000-8000-000000000201', 'a4900000-0000-4000-8000-000000000001', 'a4900000-0000-4000-8000-000000000101', 'PQ249', 'Property Q249', 'with_cc');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a4900000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q249@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a4900000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q249@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a4900000-0000-4000-8000-000000000a01', 'NV Q249 01', 'Admin Q249'),
  ('a4900000-0000-4000-8000-000000000a02', 'NV Q249 02', 'Thu kho Q249')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a4900000-0000-4000-8000-000000000601', 'a4900000-0000-4000-8000-000000000001', 'q249_admin', 'Admin Q249'),
  ('a4900000-0000-4000-8000-000000000602', 'a4900000-0000-4000-8000-000000000001', 'q249_other', 'Khac Q249');
insert into public.role_permissions (role_id, permission_code) values
  ('a4900000-0000-4000-8000-000000000601', 'admin.health.view'),
  ('a4900000-0000-4000-8000-000000000602', 'count.perform');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a4900000-0000-4000-8000-000000000a01', 'a4900000-0000-4000-8000-000000000601', null),
  ('a4900000-0000-4000-8000-000000000a02', 'a4900000-0000-4000-8000-000000000602', 'a4900000-0000-4000-8000-000000000201');

create temp table a49_resp (key text primary key, resp jsonb);
grant all on a49_resp to authenticated;
create or replace function public._a49_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

select ok(exists (select 1 from public.permissions where code = 'admin.health.view'), 'permission seeded');
select ok(exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
  where r.is_system and r.code = 'owner' and rp.permission_code = 'admin.health.view'),
  'owner role has admin.health.view');

set local role authenticated;
select public._a49_as('a4900000-0000-4000-8000-000000000a02');
select throws_ok($q$select public.admin_system_health()$q$, '42501', null, 'user without permission is rejected');

select public._a49_as('a4900000-0000-4000-8000-000000000a01');
insert into a49_resp values ('h', public.admin_system_health());
select is((select resp ->> 'ok' from a49_resp where key = 'h'), 'true', 'returns ok');
select is((select jsonb_typeof(resp -> 'cron') from a49_resp where key = 'h'), 'array', 'cron is an array');
select ok((select resp -> 'notifications' ? 'stuck' from a49_resp where key = 'h'), 'notifications has stuck counter');
select ok((select (resp -> 'database' ->> 'db_bytes')::bigint > 0 from a49_resp where key = 'h'), 'database size reported');

select finish();
rollback;
