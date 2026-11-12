-- audit_hardening_test.sql
--
-- Q240: kiem chung migration 20261109557000_audit_hardening_rule_toggled_alert.
--   §1: audit_trigger che profiles.pin_hash khoi old_data/new_data.
--   §2: 4 bang nhieu (doc_sequences, item_code_sequences, fifo_layers,
--       fifo_allocations) khong con trigger audit; bang chung tu van con.
--   §3: admin_setting_save sinh alert RULE_TOGGLED khi co rule.* doi gia tri
--       (tat = red, bat lai = warn), khong sinh khi dat lai cung gia tri hoac
--       khi key khong phai rule.*, cap chuoi sinh 1 alert moi khach san.
--
-- CHI chay file nay sau khi db push migration 557000, tren DB KHONG phai
-- production. Khong chay ca bo. Chay trong begin...rollback.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

-- ---------------------------------------------------------------------------
-- Fixture: prefix a8d00000 (audit hardening).
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('a8d00000-0000-4000-8000-000000000001', 'A8D Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a8d00000-0000-4000-8000-000000000101', 'a8d00000-0000-4000-8000-000000000001', 'A8D1', 'Entity A8D 1'),
  ('a8d00000-0000-4000-8000-000000000102', 'a8d00000-0000-4000-8000-000000000001', 'A8D2', 'Entity A8D 2');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a8d00000-0000-4000-8000-000000000201', 'a8d00000-0000-4000-8000-000000000001', 'a8d00000-0000-4000-8000-000000000101', 'PA8D1', 'Property A8D 1', 'with_cc'),
  ('a8d00000-0000-4000-8000-000000000202', 'a8d00000-0000-4000-8000-000000000001', 'a8d00000-0000-4000-8000-000000000102', 'PA8D2', 'Property A8D 2', 'with_cc');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a8d00000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-a8d@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a8d00000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-a8d@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a8d00000-0000-4000-8000-000000000a01', 'NV A8D01', 'Quản trị A8D'),
  ('a8d00000-0000-4000-8000-000000000a02', 'NV A8D02', 'Nhân viên A8D')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a8d00000-0000-4000-8000-000000000601', 'a8d00000-0000-4000-8000-000000000001', 'a8d_admin', 'Quản trị A8D');
insert into public.role_permissions (role_id, permission_code) values
  ('a8d00000-0000-4000-8000-000000000601', 'admin.users.manage'),
  ('a8d00000-0000-4000-8000-000000000601', 'admin.settings.manage'),
  ('a8d00000-0000-4000-8000-000000000601', 'audit.view_all');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a8d00000-0000-4000-8000-000000000a01', 'a8d00000-0000-4000-8000-000000000601', null);

-- Doc alerts / dem trigger bang ham security definer (chu so huu = postgres)
-- de khong phu thuoc RLS cua nguoi goi.
create or replace function public._a8d_alert_count(p_property uuid, p_severity text default null)
returns bigint
language sql
security definer
set search_path = public, pg_temp
as $$
  select count(*) from public.alerts a
  where a.code = 'RULE_TOGGLED'
    and a.property_id = p_property
    and (p_severity is null or a.severity = p_severity);
$$;
create or replace function public._a8d_has_audit_trigger(p_table text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = p_table
      and t.tgname = 'trg_' || p_table || '_audit'
      and not t.tgisinternal
  );
$$;
create or replace function public._a8d_as(p_user uuid)
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
create temp table a8d_num (key text primary key, n bigint);
grant all on a8d_num to authenticated;

-- ---------------------------------------------------------------------------
-- §2 (khong can role): bang nhieu khong con trigger; bang chung tu van con.
-- ---------------------------------------------------------------------------
select ok(not public._a8d_has_audit_trigger('doc_sequences'), 'doc_sequences has no audit trigger');
select ok(not public._a8d_has_audit_trigger('item_code_sequences'), 'item_code_sequences has no audit trigger');
select ok(not public._a8d_has_audit_trigger('fifo_layers'), 'fifo_layers has no audit trigger');
select ok(not public._a8d_has_audit_trigger('fifo_allocations'), 'fifo_allocations has no audit trigger');
select ok(public._a8d_has_audit_trigger('requisitions'), 'requisitions keeps its audit trigger');

select ok(
  exists (select 1 from public.permissions where code = 'alert.receive.rule_toggled'),
  'permission alert.receive.rule_toggled is seeded'
);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- §1: pin_hash khong vao audit_log.
-- ---------------------------------------------------------------------------
select public._a8d_as('a8d00000-0000-4000-8000-000000000a01');
select public.admin_user_set_pin('a8d00000-0000-4000-8000-000000000a02', '1234');
select ok(
  (select not (new_data ? 'pin_hash') from public.audit_log
   where table_name = 'profiles' and row_id = 'a8d00000-0000-4000-8000-000000000a02'
   order by id desc limit 1),
  'profiles audit new_data has no pin_hash'
);
select ok(
  (select not (old_data ? 'pin_hash') from public.audit_log
   where table_name = 'profiles' and row_id = 'a8d00000-0000-4000-8000-000000000a02'
   order by id desc limit 1),
  'profiles audit old_data has no pin_hash'
);
select is(
  (select new_data ->> 'full_name' from public.audit_log
   where table_name = 'profiles' and row_id = 'a8d00000-0000-4000-8000-000000000a02'
   order by id desc limit 1),
  'Nhân viên A8D',
  'profiles audit row still records the other columns'
);

-- ---------------------------------------------------------------------------
-- §3: RULE_TOGGLED.
-- ---------------------------------------------------------------------------
-- Tat R25 cap khach san 1 -> 1 alert red.
select public.admin_setting_save(
  'a8d00000-0000-4000-8000-000000000001',
  'a8d00000-0000-4000-8000-000000000201',
  'rule.R25.enabled', '0');
select is(public._a8d_alert_count('a8d00000-0000-4000-8000-000000000201', 'red'), 1::bigint,
  'turning R25 off at property scope raises 1 red RULE_TOGGLED alert');
select is(public._a8d_alert_count('a8d00000-0000-4000-8000-000000000202'), 0::bigint,
  'the other property gets no alert for a property-scoped change');

-- Dat lai dung gia tri 0 -> khong sinh them.
select public.admin_setting_save(
  'a8d00000-0000-4000-8000-000000000001',
  'a8d00000-0000-4000-8000-000000000201',
  'rule.R25.enabled', '0');
select is(public._a8d_alert_count('a8d00000-0000-4000-8000-000000000201'), 1::bigint,
  'saving the same value again raises no new alert');

-- Bat lai -> 1 alert warn nua.
select public.admin_setting_save(
  'a8d00000-0000-4000-8000-000000000001',
  'a8d00000-0000-4000-8000-000000000201',
  'rule.R25.enabled', '1');
select is(public._a8d_alert_count('a8d00000-0000-4000-8000-000000000201', 'warn'), 1::bigint,
  're-enabling R25 raises 1 warn RULE_TOGGLED alert');

-- Key khong phai rule.* -> khong sinh alert.
select public.admin_setting_save(
  'a8d00000-0000-4000-8000-000000000001',
  'a8d00000-0000-4000-8000-000000000201',
  'price_spike_pct', '12');
select is(public._a8d_alert_count('a8d00000-0000-4000-8000-000000000201'), 2::bigint,
  'a non-rule key change raises no RULE_TOGGLED alert');

-- Cap chuoi (property NULL) tat R18 -> 1 alert cho moi khach san cua org.
insert into a8d_num values ('p1_before', public._a8d_alert_count('a8d00000-0000-4000-8000-000000000201'));
insert into a8d_num values ('p2_before', public._a8d_alert_count('a8d00000-0000-4000-8000-000000000202'));
select public.admin_setting_save(
  'a8d00000-0000-4000-8000-000000000001',
  null,
  'rule.R18.enabled', '0');
select is(
  (public._a8d_alert_count('a8d00000-0000-4000-8000-000000000201') - (select n from a8d_num where key = 'p1_before'))
  + (public._a8d_alert_count('a8d00000-0000-4000-8000-000000000202') - (select n from a8d_num where key = 'p2_before')),
  2::bigint,
  'org-scope change raises one alert per property of the org'
);

select finish();
rollback;
