-- property_modules_test.sql (Q254, migration 20261109569000)
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);

insert into public.organizations (id, name) values ('a5400000-0000-4000-8000-000000000001', 'Q254 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a5400000-0000-4000-8000-000000000101', 'a5400000-0000-4000-8000-000000000001', 'Q254', 'Entity Q254');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a5400000-0000-4000-8000-000000000201', 'a5400000-0000-4000-8000-000000000001', 'a5400000-0000-4000-8000-000000000101', 'PQ254', 'Property Q254', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('a5400000-0000-4000-8000-000000000401', 'a5400000-0000-4000-8000-000000000001', 'MB', 'Minibar', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('a5400000-0000-4000-8000-000000000501', 'a5400000-0000-4000-8000-000000000001', 'ITM_MB', 'Nuoc suoi', 'a5400000-0000-4000-8000-000000000401', 'kg');
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('a5400000-0000-4000-8000-000000000301', 'a5400000-0000-4000-8000-000000000201', 'WH_Q254', 'Kho Q254', 'main', null);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a5400000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q254@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a5400000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q254@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a5400000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-q254@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a5400000-0000-4000-8000-000000000a01', 'NV Q254 01', 'Admin Q254'),
  ('a5400000-0000-4000-8000-000000000a02', 'NV Q254 02', 'Khac Q254'),
  ('a5400000-0000-4000-8000-000000000a03', 'NV Q254 03', 'Kiem ke Q254')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a5400000-0000-4000-8000-000000000601', 'a5400000-0000-4000-8000-000000000001', 'q254_admin', 'Admin Q254'),
  ('a5400000-0000-4000-8000-000000000602', 'a5400000-0000-4000-8000-000000000001', 'q254_other', 'Khac Q254'),
  ('a5400000-0000-4000-8000-000000000603', 'a5400000-0000-4000-8000-000000000001', 'q254_count', 'Kiem ke Q254');
insert into public.role_permissions (role_id, permission_code) values
  ('a5400000-0000-4000-8000-000000000601', 'admin.modules.manage'),
  ('a5400000-0000-4000-8000-000000000602', 'count.perform'),
  ('a5400000-0000-4000-8000-000000000603', 'count.open');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a5400000-0000-4000-8000-000000000a01', 'a5400000-0000-4000-8000-000000000601', null),
  ('a5400000-0000-4000-8000-000000000a02', 'a5400000-0000-4000-8000-000000000602', 'a5400000-0000-4000-8000-000000000201'),
  ('a5400000-0000-4000-8000-000000000a03', 'a5400000-0000-4000-8000-000000000603', 'a5400000-0000-4000-8000-000000000201');

create temp table a54_resp (key text primary key, resp jsonb);
grant all on a54_resp to authenticated;
create or replace function public._a54_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

-- Mac dinh: khong co dong = bat ca hai module.
select is(public.module_enabled('a5400000-0000-4000-8000-000000000201', 'hk_frontdesk'), true, 'hk_frontdesk is on by default');
select is(public.module_enabled('a5400000-0000-4000-8000-000000000201', 'restaurant'), true, 'restaurant is on by default');
select is((select count(*) from pg_trigger where tgname like 'trg\_%\_module\_guard' and not tgisinternal), 15::bigint,
  '15 module guard triggers are installed (13 + 2 child tables, Q271)');
select is((select count(*) from pg_trigger where tgname like 'trg\_%\_module\_guard' and not tgisinternal and (tgtype & 8) = 8), 15::bigint,
  'every module guard trigger also fires on DELETE (Q271)');
select is((select count(*) from pg_trigger where tgname in ('trg_banquet_dishes_module_guard','trg_buffet_session_dishes_module_guard') and not tgisinternal), 2::bigint,
  'child tables banquet_dishes / buffet_session_dishes are guarded via their parent');

set local role authenticated;
select public._a54_as('a5400000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.admin_module_set('a5400000-0000-4000-8000-000000000201', 'restaurant', false)$q$,
  '42501', null, 'user without admin.modules.manage cannot toggle');
select throws_ok(
  $q$insert into public.property_modules (property_id, module, enabled) values ('a5400000-0000-4000-8000-000000000201', 'restaurant', false)$q$,
  '42501', null, 'client cannot write property_modules directly');

select public._a54_as('a5400000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.admin_module_set('a5400000-0000-4000-8000-000000000201', 'core', false)$q$,
  'P0001', 'ERR_INVALID_VALUE', 'unknown module is rejected');
insert into a54_resp values ('off', public.admin_module_set('a5400000-0000-4000-8000-000000000201', 'restaurant', false));
select is((select resp ->> 'enabled' from a54_resp where key = 'off'), 'false', 'restaurant turned off');
select ok(jsonb_path_exists(public.admin_modules_overview(), '$[*] ? (@.code == "PQ254" && @.restaurant == false && @.hk_frontdesk == true)'), 'overview lists the property with both module states');

reset role;
select is(public.module_enabled('a5400000-0000-4000-8000-000000000201', 'restaurant'), false, 'module_enabled sees restaurant off');
select is(public.module_enabled('a5400000-0000-4000-8000-000000000201', 'hk_frontdesk'), true, 'hk_frontdesk stays on');
select is((select count(*) from public.audit_log where table_name = 'property_modules' and new_data ->> 'property_id' = 'a5400000-0000-4000-8000-000000000201'), 1::bigint, 'toggle is audited');

-- Chan o tang du lieu khi tat Nha hang.
select throws_ok(
  $q$insert into public.pos_imports (org_id, legal_entity_id, property_id, business_date, shift, file_name, file_sha256, row_count, total_amount)
     values ('a5400000-0000-4000-8000-000000000001','a5400000-0000-4000-8000-000000000101','a5400000-0000-4000-8000-000000000201','2026-11-10','x','x',repeat('c',64),1,1)$q$,
  'P0001', 'ERR_MODULE_DISABLED', 'pos_imports write is blocked while restaurant is off');

-- Kiem ke theo ca khong doi file POS khi Nha hang tat.
set local role authenticated;
select public._a54_as('a5400000-0000-4000-8000-000000000a03');
-- count_open can counter_ids; dung chinh a02.
insert into a54_resp values ('open', public.count_open(
  'a5400000-0000-4000-8000-000000000301', 'shift_key', '2026-11-10', 'morning',
  array['a5400000-0000-4000-8000-000000000a02']::uuid[], null));
select is((select resp ->> 'ok' from a54_resp where key = 'open'), 'true', 'shift_key count opens without POS file when restaurant is off');

-- Nguoi trong KS doc duoc trang thai module.
select public._a54_as('a5400000-0000-4000-8000-000000000a02');
select is((public.property_modules_get('a5400000-0000-4000-8000-000000000201') ->> 'restaurant'), 'false', 'member reads module state');

-- Tat Buong phong & Le tan: chan minibar. Bat lai Nha hang: kiem ke ca doi POS tro lai.
select public._a54_as('a5400000-0000-4000-8000-000000000a01');
select public.admin_module_set('a5400000-0000-4000-8000-000000000201', 'hk_frontdesk', false);
reset role;
select throws_ok(
  $q$insert into public.minibar_price_list (org_id, property_id, item_id, price, valid_from)
     values ('a5400000-0000-4000-8000-000000000001','a5400000-0000-4000-8000-000000000201','a5400000-0000-4000-8000-000000000501',10000,'2026-11-01')$q$,
  'P0001', 'ERR_MODULE_DISABLED', 'minibar write is blocked while hk_frontdesk is off');

set local role authenticated;
select public._a54_as('a5400000-0000-4000-8000-000000000a01');
select public.admin_module_set('a5400000-0000-4000-8000-000000000201', 'restaurant', true);
select public._a54_as('a5400000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.count_open('a5400000-0000-4000-8000-000000000301','shift_key','2026-11-11','morning',array['a5400000-0000-4000-8000-000000000a02']::uuid[],null)$q$,
  'P0001', 'ERR_POS_IMPORT_REQUIRED', 'shift_key count needs POS again once restaurant is back on');

reset role;
select is((select count(*) from public.stock_balances where warehouse_id = 'a5400000-0000-4000-8000-000000000301'), 0::bigint,
  'core stock tables are untouched by module toggles');

select finish();
rollback;
