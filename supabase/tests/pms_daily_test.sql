-- T-036 pgTAP: form PMS ngay — pms_daily_upsert + pms_daily_history.
-- Kiem tra: RLS, write-guard, upsert tao moi/cap nhat cung ngay (khong
-- trung dong), validate (sold <= available, so >= 0, so nguyen, khong ngay
-- tuong lai, source hop le), quyen pms.input (le tan/ke toan/owner/gm duoc,
-- thu kho khong; khach san khac khong), lich su sua qua audit_log (INSERT +
-- 2 UPDATE, moi nhat truoc, kem ten nguoi sua), source 'file' giu nguyen
-- khi sua khong truyen source, entered_by = nguoi sua cuoi.
-- Ngay nghiep vu = today (Asia/Ho_Chi_Minh) lay dong; khong hard-code today.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(49);

insert into public.organizations (id, name) values
  ('d0360000-0000-4000-8000-000000000001', 'T-036 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0360000-0000-4000-8000-000000000101', 'd0360000-0000-4000-8000-000000000001', 'T036', 'Entity T-036'),
  ('d0360000-0000-4000-8000-000000000102', 'd0360000-0000-4000-8000-000000000001', 'T036B', 'Entity T-036 B');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0360000-0000-4000-8000-000000000201', 'd0360000-0000-4000-8000-000000000001', 'd0360000-0000-4000-8000-000000000101', 'P0361', 'Property T-036', 'with_cc'),
  ('d0360000-0000-4000-8000-000000000202', 'd0360000-0000-4000-8000-000000000001', 'd0360000-0000-4000-8000-000000000102', 'P0362', 'Property T-036 B', 'with_cc');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0360000-0000-4000-8000-000000000a00', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u0-owner036@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0360000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-gm036@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0360000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u4-fd036@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0360000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-stk036@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0360000-0000-4000-8000-000000000a08', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u8-acc036@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0360000-0000-4000-8000-000000000a00', 'NV03600', 'Chủ đầu tư'),
  ('d0360000-0000-4000-8000-000000000a01', 'NV03601', 'Tổng quản lý'),
  ('d0360000-0000-4000-8000-000000000a04', 'NV03604', 'Lễ tân'),
  ('d0360000-0000-4000-8000-000000000a07', 'NV03607', 'Thủ kho'),
  ('d0360000-0000-4000-8000-000000000a08', 'NV03608', 'Kế toán')
on conflict (id) do update set full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0360000-0000-4000-8000-000000000600', 'd0360000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0360000-0000-4000-8000-000000000601', 'd0360000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0360000-0000-4000-8000-000000000604', 'd0360000-0000-4000-8000-000000000001', 'front_desk', 'Lễ tân'),
  ('d0360000-0000-4000-8000-000000000607', 'd0360000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0360000-0000-4000-8000-000000000608', 'd0360000-0000-4000-8000-000000000001', 'accountant', 'Kế toán');

insert into public.role_permissions (role_id, permission_code) values
  ('d0360000-0000-4000-8000-000000000600', 'pms.input'),
  ('d0360000-0000-4000-8000-000000000601', 'pms.input'),
  ('d0360000-0000-4000-8000-000000000604', 'pms.input'),
  ('d0360000-0000-4000-8000-000000000608', 'pms.input');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0360000-0000-4000-8000-000000000a00', 'd0360000-0000-4000-8000-000000000600', 'd0360000-0000-4000-8000-000000000201'),
  ('d0360000-0000-4000-8000-000000000a01', 'd0360000-0000-4000-8000-000000000601', 'd0360000-0000-4000-8000-000000000201'),
  ('d0360000-0000-4000-8000-000000000a04', 'd0360000-0000-4000-8000-000000000604', 'd0360000-0000-4000-8000-000000000201'),
  ('d0360000-0000-4000-8000-000000000a07', 'd0360000-0000-4000-8000-000000000607', 'd0360000-0000-4000-8000-000000000201'),
  ('d0360000-0000-4000-8000-000000000a08', 'd0360000-0000-4000-8000-000000000608', 'd0360000-0000-4000-8000-000000000201');

-- 1 dong mau (ngay T-2) de test RLS doc; ghi truc tiep can bypass guard.
select set_config('app.pms_daily_guard_bypass', 'on', true);
insert into public.pms_daily_stats (org_id, legal_entity_id, property_id, business_date, rooms_available, rooms_sold, guests, breakfast_pax, extra_beds, checkouts, source, entered_by, created_by) values
  ('d0360000-0000-4000-8000-000000000001', 'd0360000-0000-4000-8000-000000000101', 'd0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date - 2, 100, 80, 160, 90, 5, 75, 'form', 'd0360000-0000-4000-8000-000000000a04', 'd0360000-0000-4000-8000-000000000a04');
select set_config('app.pms_daily_guard_bypass', 'off', true);

create temp table t036_res (key text primary key, resp jsonb);
grant all on t036_res to authenticated;

create or replace function public._t036_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
end;
$$;

-- A. RLS bat (1).
select is(
  (select relrowsecurity from pg_class where relname = 'pms_daily_stats'),
  true, 'pms_daily_stats has RLS enabled'
);

-- B. Write-guard chan ghi truc tiep (1).
select throws_ok(
  $q$insert into public.pms_daily_stats (org_id, legal_entity_id, property_id, business_date, rooms_available, rooms_sold, guests, breakfast_pax, extra_beds, checkouts, source, entered_by) values (
    'd0360000-0000-4000-8000-000000000001',
    'd0360000-0000-4000-8000-000000000101',
    'd0360000-0000-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date, 100, 80, 160, 90, 5, 75, 'form',
    'd0360000-0000-4000-8000-000000000a04'
  )$q$,
  'P0001', 'ERR_WRITE_GUARD: pms_daily_stats chi duoc ghi qua RPC',
  'Direct pms_daily_stats insert is blocked by write guard'
);

set local role authenticated;

-- C. Upsert tao moi — le tan, P0361, hom nay (6).
select public._t036_as('d0360000-0000-4000-8000-000000000a04');
insert into t036_res (key, resp)
select 'up1', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb
);
select is(
  (select (resp ->> 'is_new')::boolean from t036_res where key = 'up1'),
  true, 'First upsert is_new=true'
);
select is(
  (select (resp -> 'stats' ->> 'rooms_sold')::integer from t036_res where key = 'up1'),
  85, 'First upsert returns rooms_sold 85'
);
select is(
  (select resp ->> 'source' from t036_res where key = 'up1'),
  'form', 'First upsert defaults source=form'
);
select is(
  (select count(*) from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  1::bigint, 'Exactly 1 row after first upsert'
);
select is(
  (select entered_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  'd0360000-0000-4000-8000-000000000a04'::uuid, 'entered_by is the front_desk user'
);
select is(
  (select created_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  'd0360000-0000-4000-8000-000000000a04'::uuid, 'created_by is the front_desk user'
);

-- D. Upsert lai cung ngay — cap nhat, khong tao dong moi (5).
insert into t036_res (key, resp)
select 'up2', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  '{"rooms_available": 100, "rooms_sold": 88, "guests": 175, "breakfast_pax": 96, "extra_beds": 6, "checkouts": 82}'::jsonb
);
select is(
  (select (resp ->> 'is_new')::boolean from t036_res where key = 'up2'),
  false, 'Second upsert same day is_new=false'
);
select is(
  (select count(*) from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  1::bigint, 'Still 1 row after second upsert same day'
);
select is(
  (select rooms_sold from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  88, 'rooms_sold updated to 88'
);
select is(
  (select source from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  'form', 'source stays form when not provided on update'
);
select is(
  (select entered_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date),
  'd0360000-0000-4000-8000-000000000a04'::uuid, 'entered_by still front_desk after own update'
);

-- E. Validate (10).
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 101, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'rooms_sold > rooms_available is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": -1, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Negative guests is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Missing checkouts field is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 10.5, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Fractional breakfast_pax is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Future date is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80, "source": "bogus"}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Invalid source is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', null::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Null date is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000299', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Unknown property is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, null::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Null stats is rejected'
);
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '[]'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Non-object stats is rejected'
);

-- F. Quyen (2).
select public._t036_as('d0360000-0000-4000-8000-000000000a07');
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:pms.input',
  'Storekeeper without pms.input cannot upsert'
);
select public._t036_as('d0360000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.pms_daily_upsert('d0360000-0000-4000-8000-000000000202', (now() at time zone 'Asia/Ho_Chi_Minh')::date, '{"rooms_available": 100, "rooms_sold": 85, "guests": 170, "breakfast_pax": 95, "extra_beds": 6, "checkouts": 80}'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:pms.input',
  'Front_desk cannot upsert for another property'
);

-- G. Lich su sua — nhap + 2 lan sua ngay T-1, doc qua pms_daily_history (12).
insert into t036_res (key, resp)
select 'h1', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1,
  '{"rooms_available": 90, "rooms_sold": 70, "guests": 140, "breakfast_pax": 80, "extra_beds": 4, "checkouts": 60}'::jsonb
);
insert into t036_res (key, resp)
select 'h2', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1,
  '{"rooms_available": 90, "rooms_sold": 72, "guests": 145, "breakfast_pax": 80, "extra_beds": 4, "checkouts": 61}'::jsonb
);
insert into t036_res (key, resp)
select 'h3', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1,
  '{"rooms_available": 95, "rooms_sold": 72, "guests": 145, "breakfast_pax": 82, "extra_beds": 4, "checkouts": 61}'::jsonb
);
insert into t036_res (key, resp)
select 'hist', public.pms_daily_history(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1
);
select is(
  (select jsonb_array_length(resp -> 'entries') from t036_res where key = 'hist'),
  3, 'History has 3 entries (INSERT + 2 UPDATE)'
);
select is(
  (select resp -> 'entries' -> 0 ->> 'action' from t036_res where key = 'hist'),
  'UPDATE', 'Latest history entry is an UPDATE'
);
select is(
  (select (resp -> 'entries' -> 0 -> 'new_stats' ->> 'rooms_available')::integer from t036_res where key = 'hist'),
  95, 'Latest entry new rooms_available is 95'
);
select is(
  (select (resp -> 'entries' -> 0 -> 'old_stats' ->> 'rooms_available')::integer from t036_res where key = 'hist'),
  90, 'Latest entry old rooms_available is 90'
);
select is(
  (select resp -> 'entries' -> 1 ->> 'action' from t036_res where key = 'hist'),
  'UPDATE', 'Second history entry is an UPDATE'
);
select is(
  (select (resp -> 'entries' -> 1 -> 'new_stats' ->> 'rooms_sold')::integer from t036_res where key = 'hist'),
  72, 'Second entry new rooms_sold is 72'
);
select is(
  (select (resp -> 'entries' -> 1 -> 'old_stats' ->> 'rooms_sold')::integer from t036_res where key = 'hist'),
  70, 'Second entry old rooms_sold is 70'
);
select is(
  (select resp -> 'entries' -> 2 ->> 'action' from t036_res where key = 'hist'),
  'INSERT', 'Oldest history entry is the INSERT'
);
select ok(
  (select (resp -> 'entries' -> 2 ->> 'old_stats') is null from t036_res where key = 'hist'),
  'INSERT entry has null old_stats'
);
select is(
  (select resp -> 'entries' -> 0 ->> 'actor_name' from t036_res where key = 'hist'),
  'Lễ tân', 'Latest entry actor_name is the front_desk user'
);
insert into t036_res (key, resp)
select 'hist_empty', public.pms_daily_history(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 5
);
select is(
  (select jsonb_array_length(resp -> 'entries') from t036_res where key = 'hist_empty'),
  0, 'History for a date with no row is empty'
);
select public._t036_as('d0360000-0000-4000-8000-000000000a07');
select throws_ok(
  $q$select public.pms_daily_history('d0360000-0000-4000-8000-000000000201', (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1)$q$,
  '42501', 'ERR_FORBIDDEN:pms.input',
  'Storekeeper cannot read history'
);

-- H. RLS doc truc tiep (4).
select public._t036_as('d0360000-0000-4000-8000-000000000a07');
select is(
  (select count(*) from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201'),
  0::bigint, 'Storekeeper sees 0 pms_daily_stats rows'
);
select public._t036_as('d0360000-0000-4000-8000-000000000a04');
select is(
  (select count(*) from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201'),
  3::bigint, 'Front_desk sees 3 rows for its property (T-2, T-1, T)'
);
select public._t036_as('d0360000-0000-4000-8000-000000000a01');
select is(
  (select count(*) from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201'),
  3::bigint, 'GM sees 3 rows for its property'
);
select public._t036_as('d0360000-0000-4000-8000-000000000a04');
select is(
  (select count(*) from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000202'),
  0::bigint, 'Front_desk sees 0 rows for another property'
);

-- I. source 'file' + giu nguyen khi sua khong truyen source (4).
insert into t036_res (key, resp)
select 's1', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 3,
  '{"rooms_available": 80, "rooms_sold": 60, "guests": 120, "breakfast_pax": 70, "extra_beds": 3, "checkouts": 50, "source": "file"}'::jsonb
);
select is(
  (select source from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 3),
  'file', 'source=file is stored'
);
insert into t036_res (key, resp)
select 's2', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 3,
  '{"rooms_available": 80, "rooms_sold": 61, "guests": 120, "breakfast_pax": 70, "extra_beds": 3, "checkouts": 50}'::jsonb
);
select is(
  (select (resp ->> 'is_new')::boolean from t036_res where key = 's2'),
  false, 'Second upsert on T-3 is_new=false'
);
select is(
  (select source from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 3),
  'file', 'source stays file when update omits source'
);
select is(
  (select rooms_sold from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 3),
  61, 'rooms_sold updated to 61 on T-3'
);

-- J. entered_by = nguoi sua cuoi, created_by giu nguyen (4).
select public._t036_as('d0360000-0000-4000-8000-000000000a01');
insert into t036_res (key, resp)
select 'j1', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 4,
  '{"rooms_available": 70, "rooms_sold": 50, "guests": 100, "breakfast_pax": 60, "extra_beds": 2, "checkouts": 40}'::jsonb
);
select is(
  (select entered_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 4),
  'd0360000-0000-4000-8000-000000000a01'::uuid, 'entered_by is GM after GM creates the row'
);
select is(
  (select created_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 4),
  'd0360000-0000-4000-8000-000000000a01'::uuid, 'created_by is GM'
);
select public._t036_as('d0360000-0000-4000-8000-000000000a04');
insert into t036_res (key, resp)
select 'j2', public.pms_daily_upsert(
  'd0360000-0000-4000-8000-000000000201',
  (now() at time zone 'Asia/Ho_Chi_Minh')::date - 4,
  '{"rooms_available": 70, "rooms_sold": 51, "guests": 100, "breakfast_pax": 60, "extra_beds": 2, "checkouts": 40}'::jsonb
);
select is(
  (select entered_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 4),
  'd0360000-0000-4000-8000-000000000a04'::uuid, 'entered_by moves to front_desk after their edit'
);
select is(
  (select created_by from public.pms_daily_stats where property_id = 'd0360000-0000-4000-8000-000000000201' and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 4),
  'd0360000-0000-4000-8000-000000000a01'::uuid, 'created_by stays GM after front_desk edit'
);

select * from finish();
rollback;
