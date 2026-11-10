-- T-045 pgTAP: canh bao + gui thong bao (08-REPORTS-ALERTS.md §2-§3).
-- Kiem tra: seed alert_rules 18 ma (15 ma §3 + 3 ma ngoai §3 da co diem
-- tao), P2 inactive, co khan, gio im lang (khan gui / thuong don),
-- gom tin 5 phut (3 alert cung KS -> 1 tin/nguoi), ban tin 8h (dung
-- snapshot + dung nguoi nhan + idempotent), alert_ack + RLS bang moi,
-- write-guard, cron job 07:30/08:00/5 phut.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
-- GHI CHU: test khong co secret Vault / pg_net that nen delivery duoc
-- tao o trang thai 'failed' + loi ERR_NOTIFICATION_SENDER_UNAVAILABLE
-- (dung hanh vi khi chua cau hinh sender) — gom tin + nguoi nhan van
-- kiem chung duoc qua so dong delivery. Moi pg_net goi nam trong tran
-- se rollback nen khong co HTTP that nao duoc gui.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(54);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0450000-4500-4000-8000-000000000001', 'T-045 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0450000-4500-4000-8000-000000000101', 'd0450000-4500-4000-8000-000000000001', 'T045', 'Entity T-045');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0450000-4500-4000-8000-000000000201', 'd0450000-4500-4000-8000-000000000001', 'd0450000-4500-4000-8000-000000000101', 'P0451', 'Property T-045', 'with_cc');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0450000-4500-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gm045@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0450000-4500-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner045@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0450000-4500-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cc045@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0450000-4500-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nv045@erp.internal', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0450000-4500-4000-8000-000000000a01', 'NV04501', 'Tong quan ly'),
  ('d0450000-4500-4000-8000-000000000a02', 'NV04502', 'Chu dau tu'),
  ('d0450000-4500-4000-8000-000000000a03', 'NV04503', 'Cost Controller'),
  ('d0450000-4500-4000-8000-000000000a04', 'NV04504', 'Nhan vien noi bo')
on conflict (id) do update set
  employee_code = excluded.employee_code, full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0450000-4500-4000-8000-000000000601', 'd0450000-4500-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0450000-4500-4000-8000-000000000602', 'd0450000-4500-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0450000-4500-4000-8000-000000000603', 'd0450000-4500-4000-8000-000000000001', 'cost_controller', 'Cost Controller');

insert into public.role_permissions (role_id, permission_code) values
  ('d0450000-4500-4000-8000-000000000601', 'alert.receive.waste_large'),
  ('d0450000-4500-4000-8000-000000000601', 'alert.receive.bank_account_change'),
  ('d0450000-4500-4000-8000-000000000601', 'alert.receive.minibar_mismatch'),
  ('d0450000-4500-4000-8000-000000000601', 'report.receive.daily_brief'),
  ('d0450000-4500-4000-8000-000000000602', 'alert.receive.waste_large'),
  ('d0450000-4500-4000-8000-000000000602', 'alert.receive.bank_account_change'),
  ('d0450000-4500-4000-8000-000000000602', 'alert.receive.minibar_mismatch'),
  ('d0450000-4500-4000-8000-000000000602', 'report.receive.daily_brief'),
  ('d0450000-4500-4000-8000-000000000603', 'alert.receive.waste_large'),
  ('d0450000-4500-4000-8000-000000000603', 'alert.receive.minibar_mismatch');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0450000-4500-4000-8000-000000000a01', 'd0450000-4500-4000-8000-000000000601', 'd0450000-4500-4000-8000-000000000201'),
  ('d0450000-4500-4000-8000-000000000a02', 'd0450000-4500-4000-8000-000000000602', null),
  ('d0450000-4500-4000-8000-000000000a03', 'd0450000-4500-4000-8000-000000000603', 'd0450000-4500-4000-8000-000000000201'),
  ('d0450000-4500-4000-8000-000000000a04', 'd0450000-4500-4000-8000-000000000603', 'd0450000-4500-4000-8000-000000000201');

-- Rule cho fixture org (giong seed migration, chi 4 ma can test).
insert into public.alert_rules
  (org_id, property_id, code, threshold, channels, severity, urgent, active)
values
  ('d0450000-4500-4000-8000-000000000001', null, 'WASTE_LARGE', '{"amount_vnd": 1000000}'::jsonb, array['webpush']::text[], 'warn', false, true),
  ('d0450000-4500-4000-8000-000000000001', null, 'BANK_ACCOUNT_CHANGE', '{}'::jsonb, array['zalo', 'email', 'webpush']::text[], 'red', true, true),
  ('d0450000-4500-4000-8000-000000000001', null, 'TEMP_ITEM_STALE', '{"hours": 24}'::jsonb, array['webpush']::text[], 'info', false, true),
  ('d0450000-4500-4000-8000-000000000001', null, 'MINIBAR_MISMATCH', '{}'::jsonb, array['webpush']::text[], 'red', false, true);

-- Cau hinh sender gia: URL gia + khong co secret Vault -> delivery
-- 'failed' (dung de test gom tin / nguoi nhan ma khong can HTTP that).
insert into public.notification_sender_config
  (org_id, sender_url, vault_secret_id, email_enabled, webpush_enabled, zalo_enabled)
values
  ('d0450000-4500-4000-8000-000000000001', 'https://example.invalid/functions/v1/send-notification', null, true, true, false);

-- Push subscription cho gm/owner/cc (ghi qua bypass vi co write-guard).
select set_config('app.notification_guard_bypass', 'on', true);
insert into public.push_subscriptions (user_id, endpoint, p256dh, auth) values
  ('d0450000-4500-4000-8000-000000000a01', 'https://example.invalid/push/gm045', 'cDI1MjZkaA', 'YXV0aGdt'),
  ('d0450000-4500-4000-8000-000000000a02', 'https://example.invalid/push/owner045', 'cDIyNTZkaA', 'YXV0aG93'),
  ('d0450000-4500-4000-8000-000000000a03', 'https://example.invalid/push/cc045', 'cDM1MjZkaA', 'YXV0aGNj');

-- 1. Seed + catalog (trang thai sau migration, tren moi org da co).
select ok(
  exists (select 1 from public.permissions where code = 'alert.receive.service_contract_renewal'),
  'ma quyen moi alert.receive.service_contract_renewal co trong catalog'
);
select ok(
  exists (select 1 from public.permissions where code = 'report.receive.daily_brief'),
  'ma quyen moi report.receive.daily_brief co trong catalog'
);
select ok(
  (select count(*) from public.alert_rules where code in (
    'BANK_ACCOUNT_CHANGE', 'UNLOCK', 'WATER_NIGHT_SPIKE', 'COUNT_VARIANCE',
    'AVT_DAILY', 'OVER_CEILING_APPROVED', 'PRICE_SPIKE', 'WASTE_LARGE',
    'MINIBAR_MISMATCH', 'ADVANCE_OVERDUE', 'TEMP_ITEM_STALE', 'PHOTO_REUSED',
    'PERMISSION_CRITICAL_CHANGED', 'SOD_EXCEPTION_USED',
    'SERVICE_UNACCEPTED_PAYMENT', 'MINIBAR_LOSS', 'MINIBAR_CHECK_REQUESTED',
    'SERVICE_CONTRACT_RENEWAL'
  )) >= 18,
  'seed du 18 rule alert (15 ma §3 + 3 ma ngoai §3)'
);
select ok(
  not exists (select 1 from public.alert_rules
    where code in ('WATER_NIGHT_SPIKE', 'COUNT_VARIANCE', 'AVT_DAILY') and active),
  '3 ma P2 seed o trang thai inactive'
);
select ok(
  not exists (select 1 from public.alert_rules
    where code in ('BANK_ACCOUNT_CHANGE', 'UNLOCK', 'WATER_NIGHT_SPIKE', 'PERMISSION_CRITICAL_CHANGED') and not urgent),
  '4 ma khan theo §3 deu urgent=true'
);
select ok(
  not exists (select 1 from public.alert_rules
    where code = 'WASTE_LARGE' and urgent),
  'WASTE_LARGE khong khan'
);
select ok(
  exists (select 1 from public.alert_rules
    where code = 'BANK_ACCOUNT_CHANGE'
      and channels @> array['zalo', 'email', 'webpush']::text[]),
  'BANK_ACCOUNT_CHANGE co kenh zalo+email+webpush'
);
select is(
  (select count(*) from public.alert_rules
    where org_id = 'd0450000-4500-4000-8000-000000000001'),
  4::bigint,
  'fixture org co dung 4 rule da chen'
);

-- 2. Gio im lang 23:00-06:00 VN.
select is(public._notification_is_quiet('2026-11-10 23:00:00+07'::timestamptz), true, '23:00 VN la gio im lang');
select is(public._notification_is_quiet('2026-11-10 05:59:00+07'::timestamptz), true, '05:59 VN la gio im lang');
select is(public._notification_is_quiet('2026-11-10 06:00:00+07'::timestamptz), false, '06:00 VN het gio im lang');
select is(public._notification_is_quiet('2026-11-10 12:00:00+07'::timestamptz), false, '12:00 VN khong phai gio im lang');
select is(public._notification_is_quiet('2026-11-10 22:59:00+07'::timestamptz), false, '22:59 VN chua vao gio im lang');

-- 3. Nguoi nhan theo quyen alert.receive.*.
select is(
  (select count(*) from public._notification_recipients(
    'd0450000-4500-4000-8000-000000000001',
    'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE')),
  3::bigint,
  'WASTE_LARGE co 3 nguoi nhan (gm, owner, cc)'
);
select is(
  (select count(*) from public._notification_recipients(
    'd0450000-4500-4000-8000-000000000001',
    'd0450000-4500-4000-8000-000000000201', 'BANK_ACCOUNT_CHANGE')),
  2::bigint,
  'BANK_ACCOUNT_CHANGE co 2 nguoi nhan (gm, owner; cc khong co quyen)'
);
select is(
  (select email from public._notification_recipients(
    'd0450000-4500-4000-8000-000000000001',
    'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE')
    where user_id = 'd0450000-4500-4000-8000-000000000a01'),
  'gm045@test.com',
  'email nguoi nhan lay tu auth.users'
);
select ok(
  not exists (select 1 from public._notification_recipients(
    'd0450000-4500-4000-8000-000000000001',
    'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE')
    where user_id = 'd0450000-4500-4000-8000-000000000a04'),
  'user chi co email noi bo (@erp.internal) khong vao danh sach nhan'
);

-- 4. Gom tin 5 phut (gio khong im lang).
-- 3 alert WASTE_LARGE luc 10:00/10:01/10:02 + 1 MINIBAR_MISMATCH 10:03.
insert into public.alerts (id, property_id, code, severity, title, created_at) values
  ('d0450000-4500-4000-8000-000000000901', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy vượt ngưỡng 1', '2026-11-10 10:00:00+07'),
  ('d0450000-4500-4000-8000-000000000902', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy vượt ngưỡng 2', '2026-11-10 10:01:00+07'),
  ('d0450000-4500-4000-8000-000000000903', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy vượt ngưỡng 3', '2026-11-10 10:02:00+07'),
  ('d0450000-4500-4000-8000-000000000904', 'd0450000-4500-4000-8000-000000000201', 'MINIBAR_MISMATCH', 'red', 'Đối soát minibar lệch 50.000 đ', '2026-11-10 10:03:00+07');

create temp table _t045_a as
select public.notification_dispatch_pending('2026-11-10 10:05:00+07'::timestamptz) as r;

select is(
  (select (r ->> 'deliveries')::int from _t045_a),
  6,
  'dispatch 10:05 tao 6 delivery (3 nhom huy + 3 nhom lech minibar)'
);
select is(
  (select count(*) from public.notification_deliveries where kind = 'alert'),
  6::bigint,
  'tong delivery alert = 6'
);
select is(
  (select count(*) from public.notification_deliveries
    where alert_id = 'd0450000-4500-4000-8000-000000000901'),
  3::bigint,
  '3 alert huy gom thanh 1 delivery/nguoi (3 nguoi nhan)'
);
select is(
  (select distinct title from public.notification_deliveries
    where alert_id = 'd0450000-4500-4000-8000-000000000901'),
  '3 cảnh báo mức Vàng',
  'tieu de tin gom ghi dung so alert + muc'
);
select is(
  (select count(*) from public.notification_deliveries
    where kind = 'alert' and status = 'failed'
      and error_message like 'ERR_NOTIFICATION_SENDER_UNAVAILABLE%'),
  6::bigint,
  'delivery that bai ro rang khi chua co secret Vault (khong bao sent sai)'
);
select is(
  (select count(*) from public.alerts
    where id in ('d0450000-4500-4000-8000-000000000901',
      'd0450000-4500-4000-8000-000000000902',
      'd0450000-4500-4000-8000-000000000903',
      'd0450000-4500-4000-8000-000000000904')
      and sent_at is not null and 'webpush' = any(sent_channels)),
  4::bigint,
  '4 alert da gui duoc danh dau sent + kenh webpush'
);

-- Alert thu 5 cach nhom dau 20 phut -> nhom moi (vuot cua 5 phut).
insert into public.alerts (id, property_id, code, severity, title, created_at) values
  ('d0450000-4500-4000-8000-000000000905', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy vượt ngưỡng 4', '2026-11-10 10:20:00+07');

create temp table _t045_b as
select public.notification_dispatch_pending('2026-11-10 10:21:00+07'::timestamptz) as r;

select is(
  (select (r ->> 'deliveries')::int from _t045_b),
  3,
  'alert cach 20 phut tao nhom moi: 3 delivery'
);
select is(
  (select count(*) from public.notification_deliveries where kind = 'alert'),
  9::bigint,
  'tong delivery alert = 9 sau 2 lan dispatch'
);

-- 5. Gio im lang: khan gui ngay, thuong don; alert tao trong gio im
--    lang van don ca khi dispatch luc khong im lang.
insert into public.alerts (id, property_id, code, severity, title, created_at) values
  ('d0450000-4500-4000-8000-000000000906', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy đêm', '2026-11-10 23:30:00+07'),
  ('d0450000-4500-4000-8000-000000000907', 'd0450000-4500-4000-8000-000000000201', 'BANK_ACCOUNT_CHANGE', 'red', 'Đổi STK NCC đêm', '2026-11-10 23:30:00+07'),
  ('d0450000-4500-4000-8000-000000000908', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy 2h sáng', '2026-11-10 02:00:00+07');

create temp table _t045_c as
select public.notification_dispatch_pending('2026-11-10 23:35:00+07'::timestamptz) as r;

select is(
  (select (r ->> 'deliveries')::int from _t045_c),
  4,
  '23:35 chi gui alert khan: 2 nguoi x 2 kenh (email+webpush)'
);
select is(
  (select (r ->> 'deferred')::int from _t045_c),
  2,
  '23:35 don 2 alert thuong (23:30 + 02:00) vao ban tin 8h'
);
select is(
  (select count(*) from public.notification_deliveries
    where alert_id = 'd0450000-4500-4000-8000-000000000907'),
  4::bigint,
  'alert khan co 4 delivery (gm+owner x email+webpush)'
);
select ok(
  (select sent_at is null from public.alerts
    where id = 'd0450000-4500-4000-8000-000000000906'),
  'alert thuong tao luc 23:30 van chua gui'
);
select ok(
  (select sent_at is not null
    and 'email' = any(sent_channels) and 'webpush' = any(sent_channels)
    from public.alerts where id = 'd0450000-4500-4000-8000-000000000907'),
  'alert khan da gui ca email + webpush'
);

create temp table _t045_d as
select public.notification_dispatch_pending('2026-11-10 10:00:00+07'::timestamptz) as r;

select is(
  (select (r ->> 'deliveries')::int from _t045_d),
  0,
  '10:00 khong gui them gi (alert 02:00 van don vi tao trong gio im lang)'
);
select is(
  (select (r ->> 'deferred')::int from _t045_d),
  1,
  '10:00 van don 1 alert tao luc 02:00'
);
select ok(
  (select sent_at is null from public.alerts
    where id = 'd0450000-4500-4000-8000-000000000908'),
  'alert tao luc 02:00 van chua gui sau dispatch 10:00'
);

-- 6. Ban tin 8h: doc snapshot, dung nguoi nhan, idempotent, gom chuoi.
insert into public.alerts (id, property_id, code, severity, title, created_at) values
  ('d0450000-4500-4000-8000-000000000910', 'd0450000-4500-4000-8000-000000000201', 'WASTE_LARGE', 'warn', 'Phiếu hủy test dồn bản tin', now() - interval '2 hours');

create temp table _t045_e as
select public.notification_send_digest(
  'd0450000-4500-4000-8000-000000000201', '2026-11-10'::date) as r;

select is(
  (select (r ->> 'deliveries')::int from _t045_e),
  2,
  'ban tin KS gui cho gm: email + webpush (owner chuoi khong nhan ban le)'
);
select is(
  (select count(*) from public.notification_deliveries
    where kind = 'digest'
      and property_id = 'd0450000-4500-4000-8000-000000000201'
      and dedupe_key like 'digest:d0450000-4500-4000-8000-000000000201:2026-11-10:%'),
  2::bigint,
  'dedupe_key ban tin KS dung dinh dang digest:<property>:<date>:<user>:<kenh>'
);
select ok(
  (select sent_at is not null and 'digest' = any(sent_channels)
    from public.alerts where id = 'd0450000-4500-4000-8000-000000000910'),
  'alert don duoc danh dau da gui kem ban tin (kenh digest)'
);
select ok(
  (select (r ->> 'body') like '%BẢN TIN 8H%' from _t045_e),
  'noi dung ban tin co tieu de'
);
select ok(
  (select (r ->> 'body') like '%Mua hàng hôm qua: 0 đ%' from _t045_e),
  'noi dung ban tin doc dung snapshot (mua hom qua = 0)'
);
select ok(
  (select (r ->> 'body') like '%Phiếu hủy test dồn bản tin%' from _t045_e),
  'noi dung ban tin kem muc alert don'
);

create temp table _t045_f as
select public.notification_send_digest(
  'd0450000-4500-4000-8000-000000000201', '2026-11-10'::date) as r;

select is(
  (select (r ->> 'deliveries')::int from _t045_f),
  0,
  'gui lai ban tin cung ngay khong tao delivery moi (idempotent)'
);

create temp table _t045_g as
select public.notification_send_digest_all('2026-11-10'::date) as r;

select is(
  (select count(*) from public.notification_deliveries
    where kind = 'digest' and property_id is null
      and recipient_user_id = 'd0450000-4500-4000-8000-000000000a02'
      and dedupe_key like 'digest:chain:2026-11-10:%'),
  2::bigint,
  'ban gop chuoi gui cho owner: email + webpush'
);
select is(
  (select count(*) from public.notification_deliveries
    where kind = 'digest'
      and recipient_user_id in (
        'd0450000-4500-4000-8000-000000000a01',
        'd0450000-4500-4000-8000-000000000a02')),
  4::bigint,
  'tong delivery digest cho fixture = 4 (2 KS + 2 chuoi)'
);

-- 7. Guard + RLS + cron (chay truoc khi doi role).
select throws_ok(
  $q$insert into public.notification_deliveries
    (org_id, property_id, kind, channel, recipient_address, title, dedupe_key)
    values ('d0450000-4500-4000-8000-000000000001',
      'd0450000-4500-4000-8000-000000000201', 'alert', 'email',
      'x@test.com', 't', 't045-guard-test')$q$,
  'ERR_WRITE_GUARD: notification_deliveries chi duoc ghi qua RPC',
  'ghi truc tiep notification_deliveries bi chan'
);
select is(
  (select count(*) from pg_policies
    where schemaname = 'public'
      and tablename in ('notification_targets', 'push_subscriptions',
        'notification_deliveries', 'notification_sender_config')),
  4::bigint,
  '4 bang moi deu co RLS policy'
);
select is(
  (select count(*) from pg_policies
    where schemaname = 'public'
      and tablename in ('notification_targets', 'push_subscriptions',
        'notification_deliveries', 'notification_sender_config')
      and definition ilike '%= any (public.my_property_ids())%'),
  0::bigint,
  'khong policy moi nao dung = any (my_property_ids())'
);
select ok(
  exists (select 1 from cron.job
    where jobname = 'notification-build-daily' and schedule = '30 0 * * *'),
  'cron xay ban tin 07:30 VN = 00:30 UTC'
);
select ok(
  exists (select 1 from cron.job
    where jobname = 'notification-digest-daily' and schedule = '0 1 * * *'),
  'cron gui ban tin 08:00 VN = 01:00 UTC'
);
select ok(
  exists (select 1 from cron.job
    where jobname = 'notification-worker-5min' and schedule = '*/5 * * * *'),
  'cron worker canh bao moi 5 phut'
);

-- 8. alert_ack + RLS duoi quyen authenticated.
insert into public.alerts (id, property_id, code, severity, title, created_at) values
  ('d0450000-4500-4000-8000-000000000909', 'd0450000-4500-4000-8000-000000000201', 'TEMP_ITEM_STALE', 'info', 'Mã tạm quá hạn test', '2026-11-10 10:00:00+07');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0450000-4500-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0450000-4500-4000-8000-000000000a01","role":"authenticated"}', true);

select lives_ok(
  $q$select public.alert_ack('d0450000-4500-4000-8000-000000000901')$q$,
  'gm ack duoc alert WASTE_LARGE (co quyen alert.receive.waste_large)'
);
select ok(
  (select ack_at is not null from public.alerts
    where id = 'd0450000-4500-4000-8000-000000000901'),
  'alert da ack co ack_at'
);
select ok(
  (select count(*) from public.alerts
    where property_id = 'd0450000-4500-4000-8000-000000000201'
      and code = 'WASTE_LARGE') > 0,
  'gm doc duoc alert WASTE_LARGE qua RLS'
);
select ok(
  (select count(*) from public.notification_deliveries
    where recipient_user_id = 'd0450000-4500-4000-8000-000000000a01') > 0,
  'gm doc duoc delivery cua minh qua RLS'
);

select set_config('request.jwt.claim.sub', 'd0450000-4500-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0450000-4500-4000-8000-000000000a03","role":"authenticated"}', true);

select throws_ok(
  $q$select public.alert_ack('d0450000-4500-4000-8000-000000000907')$q$,
  'ERR_FORBIDDEN',
  'cc khong ack duoc alert BANK_ACCOUNT_CHANGE (khong co quyen nhan)'
);
select is(
  (select count(*) from public.alerts
    where property_id = 'd0450000-4500-4000-8000-000000000201'
      and code = 'TEMP_ITEM_STALE'),
  0::bigint,
  'cc khong doc duoc alert TEMP_ITEM_STALE qua RLS (khong co quyen nhan)'
);

select * from finish();
rollback;
