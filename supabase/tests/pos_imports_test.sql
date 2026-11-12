-- pos_imports_test.sql (Q34, migration 20261109567000)
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

insert into public.organizations (id, name) values ('a3400000-0000-4000-8000-000000000001', 'Q34 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a3400000-0000-4000-8000-000000000101', 'a3400000-0000-4000-8000-000000000001', 'Q34', 'Entity Q34');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a3400000-0000-4000-8000-000000000201', 'a3400000-0000-4000-8000-000000000001', 'a3400000-0000-4000-8000-000000000101', 'PQ34', 'Property Q34', 'with_cc');
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('a3400000-0000-4000-8000-000000000301', 'a3400000-0000-4000-8000-000000000201', 'WH_Q34', 'Kho Q34', 'main', null);
select set_config('app.restaurant_guard_bypass', 'on', true);
insert into public.recipes (id, org_id, code, name, kind) values
  ('a3400000-0000-4000-8000-000000000701', 'a3400000-0000-4000-8000-000000000001', 'ALA-01', 'Mon 1', 'dish');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a3400000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q34@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a3400000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q34@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a3400000-0000-4000-8000-000000000a01', 'NV Q34 01', 'Ke toan Q34'),
  ('a3400000-0000-4000-8000-000000000a02', 'NV Q34 02', 'Khac Q34')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a3400000-0000-4000-8000-000000000601', 'a3400000-0000-4000-8000-000000000001', 'q34_acc', 'Ke toan Q34'),
  ('a3400000-0000-4000-8000-000000000602', 'a3400000-0000-4000-8000-000000000001', 'q34_other', 'Khac Q34');
insert into public.role_permissions (role_id, permission_code) values
  ('a3400000-0000-4000-8000-000000000601', 'pos.import'),
  ('a3400000-0000-4000-8000-000000000601', 'count.open'),
  ('a3400000-0000-4000-8000-000000000602', 'count.perform');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a3400000-0000-4000-8000-000000000a01', 'a3400000-0000-4000-8000-000000000601', 'a3400000-0000-4000-8000-000000000201'),
  ('a3400000-0000-4000-8000-000000000a02', 'a3400000-0000-4000-8000-000000000602', 'a3400000-0000-4000-8000-000000000201');

create temp table a34_resp (key text primary key, resp jsonb);
grant all on a34_resp to authenticated;
create or replace function public._a34_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;
select public._a34_as('a3400000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.pos_import_commit('a3400000-0000-4000-8000-000000000201','f.csv',repeat('a',64),
     '[{"bill_no":"B1","business_date":"2026-11-10","shift":"morning","item_code":"ALA-01","qty":"1","unit_price":"1000","amount":"1000"}]'::jsonb)$q$,
  '42501', null, 'user without pos.import cannot import');

select public._a34_as('a3400000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.pos_import_commit('a3400000-0000-4000-8000-000000000201','f.csv',repeat('a',64),
     '[{"bill_no":"B1","business_date":"2026-11-10","shift":"morning","item_code":"ALA-01","qty":"0","unit_price":"1000","amount":"0"}]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'qty 0 rejects the whole file');

-- Chua nap -> mo kiem ke ca bi chan.
select throws_ok(
  $q$select public.count_open('a3400000-0000-4000-8000-000000000301','shift_key','2026-11-10','morning',null,null)$q$,
  'P0001', 'ERR_POS_IMPORT_REQUIRED', 'shift_key count needs a POS import first');

-- Nap file: 2 ca, 1 ma khong co cong thuc.
insert into a34_resp values ('imp', public.pos_import_commit(
  'a3400000-0000-4000-8000-000000000201', 'pos.csv', repeat('b', 64),
  '[{"bill_no":"B1","business_date":"2026-11-10","shift":"morning","time":"08:10","outlet":"RESTAURANT","item_code":"ALA-01","item_name":"Mon 1","qty":"2","unit_price":"50000","amount":"100000","payment":"cash"},
    {"bill_no":"B1","business_date":"2026-11-10","shift":"morning","item_code":"XXX-99","qty":"1","unit_price":"30000","amount":"30000"},
    {"bill_no":"B2","business_date":"2026-11-10","shift":"evening","item_code":"ALA-01","qty":"1","unit_price":"50000","amount":"50000"}]'::jsonb));
select is((select resp ->> 'imports' from a34_resp where key = 'imp'), '2', 'one import per (date, shift)');
select is((select resp ->> 'rows' from a34_resp where key = 'imp'), '3', 'all rows stored');
select is((select resp -> 'unmapped_codes' ->> 0 from a34_resp where key = 'imp'), 'XXX-99',
  'unknown dish code is reported, not guessed');

select throws_ok(
  $q$select public.pos_import_commit('a3400000-0000-4000-8000-000000000201','pos.csv',repeat('b',64),
     '[{"bill_no":"B1","business_date":"2026-11-10","shift":"morning","item_code":"ALA-01","qty":"1","unit_price":"1","amount":"1"}]'::jsonb)$q$,
  '23505', 'ERR_ALREADY_IMPORTED', 'same file cannot be imported twice');

-- Co file POS -> mo kiem ke ca duoc va gan pos_import_id.
insert into a34_resp values ('open', public.count_open(
  'a3400000-0000-4000-8000-000000000301', 'shift_key', '2026-11-10', 'morning', array['a3400000-0000-4000-8000-000000000a02']::uuid[], null));
select is((select resp ->> 'ok' from a34_resp where key = 'open'), 'true', 'shift_key count opens after POS import');
select ok((select pos_import_id is not null from public.stock_counts
           where id = (select (resp ->> 'id')::uuid from a34_resp where key = 'open')),
  'stock_counts.pos_import_id is linked');

-- Ca khac chua co file -> van bi chan.
select throws_ok(
  $q$select public.count_open('a3400000-0000-4000-8000-000000000301','shift_key','2026-11-11','morning',null,null)$q$,
  'P0001', 'ERR_POS_IMPORT_REQUIRED', 'a different shift without import is still blocked');

-- RLS: nguoi khong co quyen khong doc duoc; client khong ghi truc tiep.
select public._a34_as('a3400000-0000-4000-8000-000000000a02');
select is((select count(*) from public.pos_imports), 0::bigint, 'user without perm sees no imports');
select throws_ok(
  $q$insert into public.pos_imports (org_id, legal_entity_id, property_id, business_date, shift, file_name, file_sha256, row_count, total_amount)
     values ('a3400000-0000-4000-8000-000000000001','a3400000-0000-4000-8000-000000000101','a3400000-0000-4000-8000-000000000201','2026-11-10','x','x',repeat('c',64),1,1)$q$,
  '42501', null, 'client cannot insert pos_imports directly');

select finish();
rollback;
