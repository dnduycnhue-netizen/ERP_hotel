-- T-045: canh bao + gui thong bao (docs/08-REPORTS-ALERTS.md §2-§3).
--   - Seed alert_rules mac dinh theo §3: dung 15 ma trong bang §3
--     (3 ma P2 WATER_NIGHT_SPIKE / COUNT_VARIANCE / AVT_DAILY seed voi
--     active=false — chua kich hoat gui cho toi P2) + 3 ma da co diem tao
--     alert nhung §3 khong liet ke (MINIBAR_LOSS, MINIBAR_CHECK_REQUESTED,
--     SERVICE_CONTRACT_RENEWAL).
--   - Quyet dinh anh xa kenh §3 -> alert_rules.channels (ghi Q94):
--     "App" = 'webpush' (day trinh duyet; hien thi trong app la mac dinh
--     qua bang alerts + man lich su, khong phai kenh gui rieng). "Zalo/email
--     + app" = ['zalo','email','webpush']; "Email tuan + ban tin" /
--     "Email tuan" = ['email'] (email tuan chua co job rieng — ban tin 8h
--     hang ngay la kenh don hien tai; xem Q95).
--   - Them cot severity vao alert_rules de luu muc mac dinh theo §3
--     (bang goc T-006 khong co cot nay; muc that cua tung alert do diem
--     tao _create_alert truyen — da doi chieu: 10/10 diem tao khop §3).
--   - Ma quyen MOI duy nhat: alert.receive.service_contract_renewal
--     (T-042 tao alert ma khong co ma quyen — alert bi an voi moi nguoi
--     theo RLS alerts_select). Cap them owner/gm/chief_accountant.
--   - Cap bu cac ma alert.receive.* chua co grant nao (unlock,
--     water_night_spike, count_variance, avt_daily, over_ceiling_approved,
--     price_spike, permission_critical_changed, sod_exception_used,
--     service_unaccepted_payment) + owner cho bank_account_change (do,
--     khan, lien quan bao mat — owner la chu tai khoan; xem Q96).
--   - Bang moi: notification_targets (kenh tung nguoi, theo data model
--     A10), push_subscriptions (endpoint + khoa web push),
--     notification_deliveries (hang doi + log gui, dedupe_key chong gui
--     trung), notification_sender_config (URL Edge Function + id secret
--     trong Vault + co bat tung kenh — KHONG chua secret trong bang).
--   - Gui that qua pg_net -> Edge Function send-notification (Resend cho
--     email, web-push cho web push, Zalo stub). Worker chay moi 5 phut
--     (notification_worker), doi soat (notification_reconcile_sending),
--     ban tin 8h (notification_send_digest_all, 01:00 UTC = 08:00 VN),
--     xay ban tin 07:30 (notification_build_daily_all, 00:30 UTC).
--   - KHONG sua migration cu. Khong sua CHANGELOG.md.
--   - Tien/so luong tinh trong Postgres (numeric); ngay nghiep vu VN.

-- ---------------------------------------------------------------------------
-- 1. Ma quyen moi + cap bu grant alert.receive.*
-- ---------------------------------------------------------------------------
insert into public.permissions
  (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('alert.receive.service_contract_renewal', 'Cảnh báo',
   'Nhận cảnh báo gia hạn hợp đồng',
   'Nhận cảnh báo hợp đồng dịch vụ sắp hết hạn.', 'normal', 1650),
  -- Ma nhan ban tin 8h (rieng voi report.view.rpt_daily_brief — xem Q97):
  -- §2 gui ban tin cho owner + gm; kiem tra quyen thay vi ten vai tro
  -- (AGENTS.md quy tac 10). Nguoi co quyen nay theo pham vi chuoi nhan
  -- ban gop toan chuoi; theo pham vi KS nhan ban tin KS do.
  ('report.receive.daily_brief', 'Báo cáo',
   'Nhận bản tin 8 giờ',
   'Nhận bản tin tổng hợp vận hành hằng ngày qua email / web push lúc 08:00.', 'sensitive', 1395)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'report.receive.daily_brief'
from public.roles r
where r.code in ('owner', 'gm')
on conflict do nothing;

-- Cap owner cho bank_account_change: ma do + khan, owner hien khong thay
-- duoc alert doi STK NCC (chi gm + chief_accountant co). Cac ma con lai
-- la ma chua tung co grant (them moi thuc te) hoac ma moi.
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('owner', 'alert.receive.bank_account_change'),
  ('owner', 'alert.receive.unlock'),
  ('gm', 'alert.receive.unlock'),
  ('chief_accountant', 'alert.receive.unlock'),
  ('owner', 'alert.receive.water_night_spike'),
  ('gm', 'alert.receive.water_night_spike'),
  ('engineer', 'alert.receive.water_night_spike'),
  ('owner', 'alert.receive.count_variance'),
  ('gm', 'alert.receive.count_variance'),
  ('cost_controller', 'alert.receive.count_variance'),
  ('owner', 'alert.receive.avt_daily'),
  ('gm', 'alert.receive.avt_daily'),
  ('chief_accountant', 'alert.receive.avt_daily'),
  ('owner', 'alert.receive.over_ceiling_approved'),
  ('gm', 'alert.receive.over_ceiling_approved'),
  ('chief_accountant', 'alert.receive.over_ceiling_approved'),
  ('cost_controller', 'alert.receive.over_ceiling_approved'),
  ('owner', 'alert.receive.price_spike'),
  ('gm', 'alert.receive.price_spike'),
  ('chief_accountant', 'alert.receive.price_spike'),
  ('cost_controller', 'alert.receive.price_spike'),
  ('owner', 'alert.receive.permission_critical_changed'),
  ('gm', 'alert.receive.permission_critical_changed'),
  ('chief_accountant', 'alert.receive.permission_critical_changed'),
  ('owner', 'alert.receive.sod_exception_used'),
  ('gm', 'alert.receive.sod_exception_used'),
  ('chief_accountant', 'alert.receive.sod_exception_used'),
  ('internal_audit', 'alert.receive.sod_exception_used'),
  ('owner', 'alert.receive.service_unaccepted_payment'),
  ('gm', 'alert.receive.service_unaccepted_payment'),
  ('chief_accountant', 'alert.receive.service_unaccepted_payment'),
  ('cost_controller', 'alert.receive.service_unaccepted_payment'),
  ('owner', 'alert.receive.service_contract_renewal'),
  ('gm', 'alert.receive.service_contract_renewal'),
  ('chief_accountant', 'alert.receive.service_contract_renewal')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. alert_rules: them cot severity (muc mac dinh theo §3) + seed 18 rule
--    cho moi org (chain-wide, property_id null). Seed idempotent (on
--    conflict do nothing) — chay lai khong tao trung.
-- ---------------------------------------------------------------------------
alter table public.alert_rules
  add column if not exists severity text not null default 'warn'
    check (severity in ('info', 'warn', 'red'));

insert into public.alert_rules
  (org_id, property_id, code, threshold, channels, severity, urgent, active)
select o.id, null, v.code, v.threshold, v.channels, v.severity, v.urgent, v.active
from public.organizations o
cross join (values
  -- 15 ma §3 (thu tu bang spec).
  ('BANK_ACCOUNT_CHANGE', '{}'::jsonb,
   array['zalo', 'email', 'webpush']::text[], 'red', true, true),
  ('UNLOCK', '{}'::jsonb,
   array['zalo', 'email']::text[], 'red', true, true),
  ('WATER_NIGHT_SPIKE', '{"pct": 150, "window_days": 7}'::jsonb,
   array['zalo']::text[], 'red', true, false),
  ('COUNT_VARIANCE', '{"pct": 5, "amount_vnd": 500000}'::jsonb,
   array['zalo', 'webpush']::text[], 'red', false, false),
  ('AVT_DAILY', '{"amount_vnd": 2000000}'::jsonb,
   array['zalo']::text[], 'red', false, false),
  ('OVER_CEILING_APPROVED', '{}'::jsonb,
   array['webpush']::text[], 'warn', false, true),
  ('PRICE_SPIKE', '{"pct": 10, "window_days": 7}'::jsonb,
   array['webpush']::text[], 'warn', false, true),
  ('WASTE_LARGE', '{"amount_vnd": 1000000}'::jsonb,
   array['webpush']::text[], 'warn', false, true),
  ('MINIBAR_MISMATCH', '{}'::jsonb,
   array['webpush']::text[], 'red', false, true),
  ('ADVANCE_OVERDUE', '{"hours": 24}'::jsonb,
   array['email']::text[], 'warn', false, true),
  ('TEMP_ITEM_STALE', '{"hours": 24}'::jsonb,
   array['webpush']::text[], 'info', false, true),
  ('PHOTO_REUSED', '{}'::jsonb,
   array['webpush']::text[], 'red', false, true),
  ('PERMISSION_CRITICAL_CHANGED', '{}'::jsonb,
   array['zalo', 'email']::text[], 'red', true, true),
  ('SOD_EXCEPTION_USED', '{}'::jsonb,
   array['email']::text[], 'warn', false, true),
  ('SERVICE_UNACCEPTED_PAYMENT', '{}'::jsonb,
   array['webpush']::text[], 'warn', false, true),
  -- 3 ma ngoai §3 nhung da co diem tao alert (muc = muc diem tao truyen).
  ('MINIBAR_LOSS', '{}'::jsonb,
   array['email', 'webpush']::text[], 'warn', false, true),
  ('MINIBAR_CHECK_REQUESTED', '{}'::jsonb,
   array['webpush']::text[], 'info', false, true),
  ('SERVICE_CONTRACT_RENEWAL', '{}'::jsonb,
   array['email', 'webpush']::text[], 'warn', false, true)
) as v (code, threshold, channels, severity, urgent, active)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 3. Bang moi: notification_targets / push_subscriptions /
--    notification_deliveries / notification_sender_config.
--    Ghi truc tiep bi chan (chi RPC SECURITY DEFINER ghi, qua bypass GUC
--    — mau T-030/T-032); doc qua RLS SELECT-only.
-- ---------------------------------------------------------------------------
create or replace function public._notification_write_guard()
returns trigger
language plpgsql
as $$
begin
  if current_setting('app.notification_guard_bypass', true) <> 'on' then
    raise exception using errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return coalesce(new, old);
end;
$$;
revoke all on function public._notification_write_guard()
  from public, anon, authenticated;

-- 3a. notification_targets (data model A10): kenh cua tung nguoi.
--     email: address = email nhan thay cho auth.users.email (null = dung
--     email tai khoan). webpush: address = endpoint (trung
--     push_subscriptions.endpoint). zalo: address = Zalo user id / OA
--     follower id. active=false = nguoi dung tu tat kenh do (opt-out).
create table if not exists public.notification_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check (channel in ('email', 'webpush', 'zalo')),
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (user_id, channel, address)
);
create index if not exists notification_targets_user_idx
  on public.notification_targets (user_id, channel);
alter table public.notification_targets enable row level security;
revoke all on table public.notification_targets from anon, authenticated;
grant select on table public.notification_targets to authenticated;
create policy notification_targets_select on public.notification_targets
for select to authenticated using (user_id = auth.uid());
drop trigger if exists trg_notification_targets_write_guard
  on public.notification_targets;
create trigger trg_notification_targets_write_guard
before insert or update or delete on public.notification_targets
for each row execute function public._notification_write_guard();
drop trigger if exists trg_notification_targets_set_updated_at
  on public.notification_targets;
create trigger trg_notification_targets_set_updated_at
before update on public.notification_targets
for each row execute function public.set_updated_at();
drop trigger if exists trg_notification_targets_audit
  on public.notification_targets;
create trigger trg_notification_targets_audit
after insert or update or delete on public.notification_targets
for each row execute function public.audit_trigger();

-- 3b. push_subscriptions: endpoint + khoa web push cua tung thiet bi.
--     Khoa p256dh/auth la bi mat ky thuat (khong phai secret van hanh):
--     chi doc duoc boi chu so huu (RLS) va Edge Function qua payload
--     cua worker (khong luu khoa vao bang khac).
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null check (btrim(p256dh) <> ''),
  auth text not null check (btrim(auth) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_used_at timestamptz,
  unique (endpoint)
);
create index if not exists push_subscriptions_user_idx
  on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
revoke all on table public.push_subscriptions from anon, authenticated;
grant select on table public.push_subscriptions to authenticated;
create policy push_subscriptions_select on public.push_subscriptions
for select to authenticated using (user_id = auth.uid());
drop trigger if exists trg_push_subscriptions_write_guard
  on public.push_subscriptions;
create trigger trg_push_subscriptions_write_guard
before insert or update or delete on public.push_subscriptions
for each row execute function public._notification_write_guard();
drop trigger if exists trg_push_subscriptions_set_updated_at
  on public.push_subscriptions;
create trigger trg_push_subscriptions_set_updated_at
before update on public.push_subscriptions
for each row execute function public.set_updated_at();

-- 3c. notification_deliveries: hang doi + log gui (1 dong = 1 tin gui toi
--     1 nguoi qua 1 kenh). kind='alert' gan alert_id; kind='digest' la
--     ban tin 8h (alert_id null, digest_date = ngay nghiep vu).
--     dedupe_key dam bao idempotent: worker chay lai khong gui trung.
create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid references public.properties(id) on delete cascade,
  alert_id uuid references public.alerts(id) on delete set null,
  kind text not null check (kind in ('alert', 'digest')),
  digest_date date,
  channel text not null check (channel in ('email', 'webpush', 'zalo')),
  recipient_user_id uuid references auth.users(id) on delete set null,
  recipient_address text not null check (btrim(recipient_address) <> ''),
  title text not null check (btrim(title) <> ''),
  body text not null default '',
  status text not null default 'queued'
    check (status in ('queued', 'sending', 'sent', 'failed', 'skipped_quiet')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  provider_request_id bigint,
  error_message text,
  dedupe_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (id, org_id),
  unique (dedupe_key),
  check (kind = 'digest' or alert_id is not null),
  check (kind = 'alert' or digest_date is not null)
);
create index if not exists notification_deliveries_retry_idx
  on public.notification_deliveries (status, next_attempt_at)
  where status in ('queued', 'failed');
create index if not exists notification_deliveries_alert_idx
  on public.notification_deliveries (alert_id);
create index if not exists notification_deliveries_property_idx
  on public.notification_deliveries (property_id, created_at desc);
alter table public.notification_deliveries enable row level security;
revoke all on table public.notification_deliveries from anon, authenticated;
grant select on table public.notification_deliveries to authenticated;
-- Nguoi nhan thay dong cua minh; nguoi co bat ky quyen alert.receive.*
-- tai KS thay duoc dong cua KS do (xem lich su gui tren man alerts).
create policy notification_deliveries_select on public.notification_deliveries
for select to authenticated using (
  recipient_user_id = auth.uid()
  or (
    property_id is not null
    and property_id in (select public.my_property_ids())
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id
      join public.role_permissions rp on rp.role_id = r.id
      where upr.user_id = auth.uid()
        and rp.permission_code like 'alert.receive.%'
        and (upr.property_id = notification_deliveries.property_id
          or upr.property_id is null)
    )
  )
  or (
    property_id is null
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id
      join public.role_permissions rp on rp.role_id = r.id
      where upr.user_id = auth.uid()
        and rp.permission_code like 'alert.receive.%'
        and upr.property_id is null
    )
  )
);
drop trigger if exists trg_notification_deliveries_write_guard
  on public.notification_deliveries;
create trigger trg_notification_deliveries_write_guard
before insert or update or delete on public.notification_deliveries
for each row execute function public._notification_write_guard();
drop trigger if exists trg_notification_deliveries_set_updated_at
  on public.notification_deliveries;
create trigger trg_notification_deliveries_set_updated_at
before update on public.notification_deliveries
for each row execute function public.set_updated_at();

-- 3d. notification_sender_config: cau hinh gui theo org — URL Edge Function
--     + id secret trong Vault + co bat tung kenh. KHONG chua secret nao
--     trong bang (secret nam trong Vault; URL la dia chi cong khai cua
--     Edge Function). Admin cap 1 lan sau deploy (xem bao cao T-045).
--     Khong co policy ghi: chi admin SQL (postgres) moi ghi duoc.
create table if not exists public.notification_sender_config (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  sender_url text,
  vault_secret_id uuid,
  email_enabled boolean not null default false,
  webpush_enabled boolean not null default false,
  zalo_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id)
);
alter table public.notification_sender_config enable row level security;
revoke all on table public.notification_sender_config from anon, authenticated;
grant select on table public.notification_sender_config to authenticated;
create policy notification_sender_config_select
  on public.notification_sender_config
for select to authenticated using (
  public.has_perm(null, 'admin.alert_rules.manage')
);
drop trigger if exists trg_notification_sender_config_set_updated_at
  on public.notification_sender_config;
create trigger trg_notification_sender_config_set_updated_at
before update on public.notification_sender_config
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. Helper noi bo (khong grant execute — chi worker/RPC SECURITY DEFINER goi).
-- ---------------------------------------------------------------------------
-- Gio im lang 23:00-06:00 (gio VN). Dung ca luc tao alert (defer) va luc
-- gui (worker) — xem notification_dispatch_pending.
create or replace function public._notification_is_quiet(
  p_at timestamptz default now()
)
returns boolean
language sql stable
as $$
  select extract(hour from (p_at at time zone 'Asia/Ho_Chi_Minh')) >= 23
      or extract(hour from (p_at at time zone 'Asia/Ho_Chi_Minh')) < 6;
$$;
revoke all on function public._notification_is_quiet(timestamptz)
  from public, anon, authenticated;

-- Rule hieu luc cho (org, property, code): dong rieng theo KS uu tien
-- hon dong chuoi (property_id null).
create or replace function public._notification_rule_for(
  p_org_id uuid, p_property_id uuid, p_code text
)
returns public.alert_rules
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  select r
  from public.alert_rules r
  where r.org_id = p_org_id
    and r.code = upper(p_code)
    and (r.property_id = p_property_id or r.property_id is null)
  order by (r.property_id is not null) desc
  limit 1;
$$;
revoke all on function public._notification_rule_for(uuid, uuid, text)
  from public, anon, authenticated;

-- Email nhan cua 1 user: uu tien notification_targets.address (ghi de),
-- neu khong dung auth.users.email. Tra null khi: opt-out email, khong co
-- email, hoac email noi bo (@erp.internal / *.local — tai khoan khong co
-- email that, khong duoc gui mail ra ngoai).
create or replace function public._notification_user_email(p_user_id uuid)
returns text
language plpgsql stable security definer set search_path = public, auth, pg_temp
as $$
declare
  v_email text;
begin
  if exists (
    select 1 from public.notification_targets t
    where t.user_id = p_user_id and t.channel = 'email' and not t.active
  ) then
    return null;
  end if;

  select t.address into v_email
  from public.notification_targets t
  where t.user_id = p_user_id and t.channel = 'email' and t.active
    and t.address is not null and btrim(t.address) <> ''
  order by t.created_at desc
  limit 1;

  if v_email is null then
    select u.email into v_email from auth.users u where u.id = p_user_id;
  end if;

  if v_email is null
    or v_email ilike '%@erp.internal'
    or v_email ilike '%@%.local'
  then
    return null;
  end if;
  return v_email;
end;
$$;
revoke all on function public._notification_user_email(uuid)
  from public, anon, authenticated;

-- Nguoi nhan cua 1 ma alert: nguoi co quyen alert.receive.<code> tai KS
-- (hoac chuoi), profile active, thuoc org. has_webpush = co subscription.
create or replace function public._notification_recipients(
  p_org_id uuid, p_property_id uuid, p_code text
)
returns table (user_id uuid, email text, has_webpush boolean)
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  select distinct u.id,
    public._notification_user_email(u.id),
    exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
  from auth.users u
  left join public.profiles pr on pr.id = u.id
  where coalesce(pr.active, true)
    and public.user_has_perm(u.id, p_property_id, 'alert.receive.' || lower(p_code))
    -- Chi nguoi lien lac duoc (co email that hoac co push subscription);
    -- nguoi chi co email noi bo (@erp.internal / *.local) bi loai o day.
    and (
      public._notification_user_email(u.id) is not null
      or exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
    )
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id and r.org_id = p_org_id
      where upr.user_id = u.id
    );
$$;
revoke all on function public._notification_recipients(uuid, uuid, text)
  from public, anon, authenticated;

-- Nguoi nhan ban tin 8h: nguoi co quyen report.receive.daily_brief.
-- is_chain=true: quyen pham vi chuoi (nhan ban gop toan chuoi);
-- is_chain=false: quyen tai KS cu the (nhan ban tin KS do).
create or replace function public._notification_digest_recipients(
  p_org_id uuid, p_property_id uuid
)
returns table (user_id uuid, email text, has_webpush boolean, is_chain boolean)
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  select distinct u.id,
    public._notification_user_email(u.id),
    exists (select 1 from public.push_subscriptions s where s.user_id = u.id),
    true
  from auth.users u
  left join public.profiles pr on pr.id = u.id
  where coalesce(pr.active, true)
    and public.user_has_perm(u.id, null, 'report.receive.daily_brief')
    and (
      public._notification_user_email(u.id) is not null
      or exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
    )
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id and r.org_id = p_org_id
      where upr.user_id = u.id
    )
  union
  select distinct u.id,
    public._notification_user_email(u.id),
    exists (select 1 from public.push_subscriptions s where s.user_id = u.id),
    false
  from auth.users u
  left join public.profiles pr on pr.id = u.id
  where coalesce(pr.active, true)
    and public.user_has_perm(u.id, p_property_id, 'report.receive.daily_brief')
    and not public.user_has_perm(u.id, null, 'report.receive.daily_brief')
    and (
      public._notification_user_email(u.id) is not null
      or exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
    )
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id and r.org_id = p_org_id
      where upr.user_id = u.id
    );
$$;
revoke all on function public._notification_digest_recipients(uuid, uuid)
  from public, anon, authenticated;

-- Danh dau 1 alert da gui qua 1 kenh (sent_at + sent_channels).
create or replace function public._notification_mark_alert(
  p_alert_id uuid, p_channel text
)
returns void
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
begin
  update public.alerts a
  set sent_at = coalesce(a.sent_at, now()),
      sent_channels = case
        when p_channel = any(a.sent_channels) then a.sent_channels
        else array_append(a.sent_channels, p_channel)
      end
  where a.id = p_alert_id;
end;
$$;
revoke all on function public._notification_mark_alert(uuid, text)
  from public, anon, authenticated;

-- Doc secret tu Vault theo id (tra null neu Vault chua bat / khong doc duoc
-- — worker se de delivery o 'failed' voi loi ro rang thay vi vo tran).
create or replace function public._notification_vault_secret(p_secret_id uuid)
returns text
language plpgsql stable security definer
  set search_path = public, auth, pg_temp, vault
as $$
declare
  v_secret text;
begin
  if p_secret_id is null then
    return null;
  end if;
  if not exists (select 1 from pg_extension where extname = 'vault') then
    return null;
  end if;
  begin
    select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where id = p_secret_id;
  exception when others then
    return null;
  end;
  return v_secret;
end;
$$;
revoke all on function public._notification_vault_secret(uuid)
  from public, anon, authenticated;

-- Gui HTTP qua pg_net toi Edge Function send-notification. Tra request id,
-- hoac null khi pg_net / URL / secret khong san sang (nguoi goi tu xu ly
-- thanh 'failed' + thu lai). Khong bao gio raise — worker cron khong
-- duoc vo tran vi 1 tin loi.
create or replace function public._notification_http_post(
  p_url text, p_secret text, p_body jsonb
)
returns bigint
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_req bigint;
begin
  if p_url is null or btrim(p_url) = '' or p_secret is null then
    return null;
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    return null;
  end if;
  begin
    select net.http_post(
      url := p_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-notification-secret', p_secret
      ),
      body := p_body
    ) into v_req;
  exception when others then
    return null;
  end;
  return v_req;
end;
$$;
revoke all on function public._notification_http_post(text, text, jsonb)
  from public, anon, authenticated;

-- Doc ket qua pg_net (neu co) cho 1 request id. Tra rong khi chua co
-- phan hoi hoac bang/cot khong dung dinh dang — nguoi goi tu xu ly timeout.
create or replace function public._notification_http_response(
  p_request_id bigint
)
returns table (status_code integer, error_msg text)
language plpgsql stable security definer set search_path = public, auth, pg_temp
as $$
begin
  if p_request_id is null then
    return;
  end if;
  if to_regclass('net._http_response') is null then
    return;
  end if;
  begin
    return query execute
      'select status_code, error_msg from net._http_response where id = $1'
      using p_request_id;
  exception when others then
    return;
  end;
end;
$$;
revoke all on function public._notification_http_response(bigint)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Worker gui canh bao tuc thoi (moi 5 phut).
-- ---------------------------------------------------------------------------
-- Gui 1 nhom alert (cung KS + muc + khan) toi moi nguoi nhan x kenh.
-- Tra so delivery da tao. Nhom co the rong nguoi nhan / kenh tat / chua
-- cau hinh sender -> tra 0, alert giu nguyen chua gui de lan sau thu lai.
create or replace function public._notification_flush_group(
  p_org_id uuid, p_property_id uuid, p_severity text, p_urgent boolean,
  p_alert_ids uuid[], p_titles text[], p_times text[], p_codes text[],
  p_now timestamptz
)
returns integer
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_cfg record;
  v_secret text;
  v_channels text[] := '{}';
  v_channel text;
  v_title text;
  v_body text;
  v_property_name text := '';
  v_sev_vi text := case p_severity
    when 'red' then 'Đỏ' when 'warn' then 'Vàng' else 'Xanh' end;
  v_rec record;
  v_dedupe text;
  v_delivery_id uuid;
  v_req bigint;
  v_payload jsonb;
  v_sub jsonb;
  v_zalo text;
  v_count int := 0;
  i int;
begin
  if coalesce(array_length(p_alert_ids, 1), 0) = 0 then
    return 0;
  end if;

  select * into v_cfg
  from public.notification_sender_config c
  where c.org_id = p_org_id;
  if v_cfg.id is null then
    return 0;
  end if;

  -- Kenh = hop cac rule trong nhom ('app' -> 'webpush', xem muc 2),
  -- giao voi kenh da bat trong cau hinh sender.
  select array_agg(distinct ch) into v_channels
  from public.alert_rules r,
    lateral unnest(r.channels) as ch
  where r.org_id = p_org_id
    and r.code = any(p_codes)
    and (r.property_id = p_property_id or r.property_id is null);
  v_channels := array(
    select distinct case when c = 'app' then 'webpush' else c end
    from unnest(coalesce(v_channels, '{}'::text[])) as c
    where (c = 'email' and v_cfg.email_enabled)
       or (c in ('webpush', 'app') and v_cfg.webpush_enabled)
       or (c = 'zalo' and v_cfg.zalo_enabled)
  );
  if coalesce(array_length(v_channels, 1), 0) = 0 then
    return 0;
  end if;

  if p_property_id is not null then
    select p.name into v_property_name
    from public.properties p where p.id = p_property_id;
  end if;

  if array_length(p_alert_ids, 1) = 1 then
    v_title := p_titles[1];
  else
    v_title := format('%s cảnh báo mức %s', array_length(p_alert_ids, 1), v_sev_vi)
      || case when v_property_name <> '' then ' — ' || v_property_name else '' end;
  end if;
  v_body := '';
  for i in 1 .. array_length(p_alert_ids, 1) loop
    v_body := v_body || '• [' || p_times[i] || '] ' || p_titles[i] || E'\n';
  end loop;
  v_body := v_body || 'Xem chi tiết trong mục Cảnh báo.';

  v_secret := public._notification_vault_secret(v_cfg.vault_secret_id);

  -- Nguoi nhan = hop cua moi ma trong nhom (moi ma co tap nguoi rieng).
  for v_rec in
    select distinct r.user_id, r.email, r.has_webpush
    from unnest(p_codes) as code,
      lateral public._notification_recipients(p_org_id, p_property_id, code) r
  loop
    foreach v_channel in array v_channels loop
      -- Dia chi nhan theo kenh; khong co dia chi -> bo qua kenh do.
      v_payload := null;
      if v_channel = 'email' then
        if v_rec.email is null then
          continue;
        end if;
        v_payload := jsonb_build_object(
          'channel', 'email', 'to', v_rec.email,
          'subject', v_title, 'text', v_body,
          'property_id', p_property_id, 'severity', p_severity
        );
      elsif v_channel = 'webpush' then
        if not v_rec.has_webpush then
          continue;
        end if;
        select row_to_json(s) into v_sub
        from (
          select endpoint, jsonb_build_object('p256dh', p256dh, 'auth', auth) as keys
          from public.push_subscriptions
          where user_id = v_rec.user_id
          order by last_used_at desc nulls last, created_at desc
          limit 1
        ) s;
        if v_sub is null then
          continue;
        end if;
        v_payload := jsonb_build_object(
          'channel', 'webpush', 'to', v_sub ->> 'endpoint',
          'subject', v_title, 'text', v_body,
          'subscription', v_sub,
          'property_id', p_property_id, 'severity', p_severity
        );
      elsif v_channel = 'zalo' then
        select t.address into v_zalo
        from public.notification_targets t
        where t.user_id = v_rec.user_id and t.channel = 'zalo' and t.active
          and t.address is not null and btrim(t.address) <> ''
        order by t.created_at desc
        limit 1;
        if v_zalo is null then
          continue;
        end if;
        v_payload := jsonb_build_object(
          'channel', 'zalo', 'to', v_zalo,
          'subject', v_title, 'text', v_body,
          'property_id', p_property_id, 'severity', p_severity
        );
      end if;

      v_dedupe := 'alert:' || encode(
        sha256(convert_to(array_to_string(
          (select array_agg(u order by u) from unnest(p_alert_ids) as u), ','), 'UTF8')),
        'hex')
        || ':' || v_rec.user_id || ':' || v_channel;

      perform set_config('app.notification_guard_bypass', 'on', true);
      insert into public.notification_deliveries
        (org_id, property_id, alert_id, kind, channel,
         recipient_user_id, recipient_address, title, body, dedupe_key)
      values
        (p_org_id, p_property_id, p_alert_ids[1], 'alert', v_channel,
         v_rec.user_id, v_payload ->> 'to', v_title, v_body, v_dedupe)
      on conflict (dedupe_key) do nothing
      returning id into v_delivery_id;

      if v_delivery_id is null then
        continue; -- da co delivery nay tu lan chay truoc (idempotent)
      end if;
      v_count := v_count + 1;

      v_req := public._notification_http_post(v_cfg.sender_url, v_secret, v_payload);
      if v_req is not null then
        update public.notification_deliveries
        set status = 'sending', attempts = 1, provider_request_id = v_req
        where id = v_delivery_id;
      else
        update public.notification_deliveries
        set status = 'failed', attempts = 1,
            next_attempt_at = p_now + interval '5 minutes',
            error_message = 'ERR_NOTIFICATION_SENDER_UNAVAILABLE: chua cau hinh sender_url / secret Vault / pg_net'
        where id = v_delivery_id;
      end if;
    end loop;
  end loop;

  -- Danh dau alert da xu ly (delivery retry doc lap theo dong delivery).
  if v_count > 0 then
    for i in 1 .. array_length(p_alert_ids, 1) loop
      foreach v_channel in array v_channels loop
        perform public._notification_mark_alert(p_alert_ids[i], v_channel);
      end loop;
    end loop;
  end if;
  return v_count;
end;
$$;
revoke all on function public._notification_flush_group(
  uuid, uuid, text, boolean, uuid[], text[], text[], text[], timestamptz)
  from public, anon, authenticated;

-- Thu lai delivery loi / doi gui (attempts < 3, den han). Tra so dong da thu.
create or replace function public._notification_retry_due(p_now timestamptz)
returns integer
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_row record;
  v_cfg record;
  v_secret text;
  v_req bigint;
  v_payload jsonb;
  v_sub jsonb;
  v_count int := 0;
begin
  for v_row in
    select d.*
    from public.notification_deliveries d
    where d.status in ('queued', 'failed')
      and d.attempts < 3
      and d.next_attempt_at <= p_now
    order by d.created_at
    limit 100
  loop
    select * into v_cfg
    from public.notification_sender_config c
    where c.org_id = v_row.org_id;
    if v_cfg.id is null then
      continue;
    end if;
    if (v_row.channel = 'email' and not v_cfg.email_enabled)
      or (v_row.channel = 'webpush' and not v_cfg.webpush_enabled)
      or (v_row.channel = 'zalo' and not v_cfg.zalo_enabled)
    then
      continue;
    end if;
    v_secret := public._notification_vault_secret(v_cfg.vault_secret_id);

    v_payload := jsonb_build_object(
      'channel', v_row.channel, 'to', v_row.recipient_address,
      'subject', v_row.title, 'text', v_row.body,
      'property_id', v_row.property_id
    );
    if v_row.channel = 'webpush' then
      select row_to_json(s) into v_sub
      from (
        select endpoint, jsonb_build_object('p256dh', p256dh, 'auth', auth) as keys
        from public.push_subscriptions
        where user_id = v_row.recipient_user_id
          and endpoint = v_row.recipient_address
        limit 1
      ) s;
      if v_sub is null then
        continue;
      end if;
      v_payload := v_payload || jsonb_build_object('subscription', v_sub);
    end if;

    v_req := public._notification_http_post(v_cfg.sender_url, v_secret, v_payload);
    perform set_config('app.notification_guard_bypass', 'on', true);
    if v_req is not null then
      update public.notification_deliveries
      set status = 'sending', attempts = v_row.attempts + 1,
          provider_request_id = v_req, error_message = null
      where id = v_row.id;
    else
      update public.notification_deliveries
      set status = 'failed', attempts = v_row.attempts + 1,
          next_attempt_at = p_now + (v_row.attempts + 1) * interval '5 minutes',
          error_message = 'ERR_NOTIFICATION_SENDER_UNAVAILABLE: chua cau hinh sender_url / secret Vault / pg_net'
      where id = v_row.id;
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public._notification_retry_due(timestamptz)
  from public, anon, authenticated;

-- Doi soat delivery dang 'sending' voi phan hoi pg_net: 2xx -> 'sent',
-- loi -> 'failed' (thu lai theo _notification_retry_due). Khong co phan
-- hoi sau 120 phut -> 'failed' timeout (thu lai toi da 3 lan).
create or replace function public.notification_reconcile_sending()
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_row record;
  v_resp record;
  v_sent int := 0;
  v_failed int := 0;
begin
  for v_row in
    select d.*
    from public.notification_deliveries d
    where d.status = 'sending'
    order by d.created_at
    limit 200
  loop
    select * into v_resp
    from public._notification_http_response(v_row.provider_request_id);
    if v_resp.status_code is not null then
      perform set_config('app.notification_guard_bypass', 'on', true);
      if v_resp.status_code between 200 and 299 then
        update public.notification_deliveries
        set status = 'sent', sent_at = now(), error_message = null
        where id = v_row.id;
        v_sent := v_sent + 1;
      else
        update public.notification_deliveries
        set status = 'failed',
            next_attempt_at = now() + (attempts + 1) * interval '5 minutes',
            error_message = left(
              'ERR_NOTIFICATION_SEND_FAILED: HTTP ' || v_resp.status_code
              || coalesce(': ' || v_resp.error_msg, ''), 500)
        where id = v_row.id;
        v_failed := v_failed + 1;
      end if;
    elsif v_row.created_at < now() - interval '120 minutes' then
      perform set_config('app.notification_guard_bypass', 'on', true);
      update public.notification_deliveries
      set status = 'failed',
          next_attempt_at = now() + (attempts + 1) * interval '5 minutes',
          error_message = 'ERR_NOTIFICATION_TIMEOUT: khong co phan hoi pg_net sau 120 phut'
      where id = v_row.id;
      v_failed := v_failed + 1;
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'sent', v_sent, 'failed', v_failed);
end;
$$;
revoke all on function public.notification_reconcile_sending()
  from public, anon, authenticated;
grant execute on function public.notification_reconcile_sending()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Dispatcher chinh: gom tin 5 phut + gio im lang.
--    p_now: moc thoi gian (mac dinh now()) — truyen tuong minh khi test
--    pgTAP de kiem chung gio im lang ma khong phu thuoc gio chay that.
--    Quy tac gui:
--    - Rule khong co / inactive -> bo qua (alert het han sau 24h).
--    - Khong khan + (dang gio im lang HOAC alert tao trong gio im lang)
--      -> don vao ban tin 8h (khong gui ngay, khong danh dau da gui).
--    - Con lai: gom theo (org, KS, muc, khan), cua so truot 5 phut tinh
--      tu alert dau nhom -> 1 tin duy nhat cho moi nguoi nhan x kenh.
--    - Alert chi xet trong 24h gan nhat (chong tran tin khi worker dung
--      lau roi chay lai); alert cu hon giu nguyen chua gui.
-- ---------------------------------------------------------------------------
create or replace function public.notification_dispatch_pending(
  p_now timestamptz default null
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_now timestamptz := coalesce(p_now, now());
  v_quiet_now boolean := public._notification_is_quiet(v_now);
  v_retried int := 0;
  v_deliveries int := 0;
  v_deferred int := 0;
  v_skipped int := 0;
  v_alert record;
  g_org uuid := null;
  g_property uuid := null;
  g_severity text := null;
  g_urgent boolean := null;
  g_start timestamptz := null;
  g_ids uuid[] := '{}';
  g_titles text[] := '{}';
  g_times text[] := '{}';
  g_codes text[] := '{}';
  v_flushed int;
begin
  v_retried := public._notification_retry_due(v_now);

  for v_alert in
    select a.id as alert_id, a.property_id, a.code, a.severity, a.title,
      a.created_at,
      coalesce(p.org_id, o.id) as org_id,
      r.urgent as rule_urgent, r.active as rule_active,
      (r.code is not null) as has_rule
    from public.alerts a
    left join public.properties p on p.id = a.property_id
    left join public.organizations o on a.property_id is null
    left join lateral public._notification_rule_for(
      coalesce(p.org_id, o.id), a.property_id, a.code) r on true
    where a.sent_at is null
      and a.created_at >= v_now - interval '24 hours'
      and a.created_at <= v_now
      and not exists (
        select 1 from public.notification_deliveries d
        where d.alert_id = a.id and d.status in ('queued', 'sending')
      )
    order by org_id, a.property_id nulls last, a.severity, r.urgent, a.created_at
  loop
    if not v_alert.has_rule or not v_alert.rule_active then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    if not v_alert.rule_urgent and (
      v_quiet_now or public._notification_is_quiet(v_alert.created_at)
    ) then
      v_deferred := v_deferred + 1;
      continue;
    end if;
    if g_start is null
      or g_org is distinct from v_alert.org_id
      or g_property is distinct from v_alert.property_id
      or g_severity is distinct from v_alert.severity
      or g_urgent is distinct from v_alert.rule_urgent
      or v_alert.created_at > g_start + interval '5 minutes'
    then
      if g_start is not null then
        v_flushed := public._notification_flush_group(
          g_org, g_property, g_severity, g_urgent,
          g_ids, g_titles, g_times, g_codes, v_now);
        v_deliveries := v_deliveries + v_flushed;
        if v_flushed = 0 then
          v_skipped := v_skipped + array_length(g_ids, 1);
        end if;
      end if;
      g_org := v_alert.org_id;
      g_property := v_alert.property_id;
      g_severity := v_alert.severity;
      g_urgent := v_alert.rule_urgent;
      g_start := v_alert.created_at;
      g_ids := '{}'; g_titles := '{}'; g_times := '{}'; g_codes := '{}';
    end if;
    g_ids := array_append(g_ids, v_alert.alert_id);
    g_titles := array_append(g_titles, v_alert.title);
    g_times := array_append(g_times,
      to_char(v_alert.created_at at time zone 'Asia/Ho_Chi_Minh', 'HH24:MI'));
    g_codes := array_append(g_codes, v_alert.code);
  end loop;

  if g_start is not null then
    v_flushed := public._notification_flush_group(
      g_org, g_property, g_severity, g_urgent,
      g_ids, g_titles, g_times, g_codes, v_now);
    v_deliveries := v_deliveries + v_flushed;
    if v_flushed = 0 then
      v_skipped := v_skipped + array_length(g_ids, 1);
    end if;
  end if;

  return jsonb_build_object(
    'ok', true, 'at', v_now, 'quiet_hours', v_quiet_now,
    'deliveries', v_deliveries, 'deferred', v_deferred,
    'skipped', v_skipped, 'retried', v_retried);
end;
$$;
revoke all on function public.notification_dispatch_pending(timestamptz)
  from public, anon, authenticated;
grant execute on function public.notification_dispatch_pending(timestamptz)
  to authenticated;

-- Worker 5 phut: dispatch + doi soat (1 job pg_cron duy nhat).
create or replace function public.notification_worker()
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_d jsonb;
  v_r jsonb;
begin
  v_d := public.notification_dispatch_pending();
  v_r := public.notification_reconcile_sending();
  return jsonb_build_object('ok', true, 'dispatch', v_d, 'reconcile', v_r);
end;
$$;
revoke all on function public.notification_worker()
  from public, anon, authenticated;
grant execute on function public.notification_worker() to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Ban tin 8h (doc/08-REPORTS-ALERTS.md §2).
--    Nguoi nhan = quyen report.receive.daily_brief (AGENTS.md quy tac 10):
--    pham vi KS -> ban tin KS do; pham vi chuoi -> ban gop toan chuoi.
--    Idempotent nho dedupe_key (chay lai khong gui trung).
-- ---------------------------------------------------------------------------
-- Alert don vao ban tin: chua gui, trong 24h, tao trong gio im lang HOAC
-- qua 1 gio van chua gui duoc (worker loi / chua cau hinh sender).
create or replace function public._notification_deferred_alerts(
  p_property_id uuid
)
returns setof public.alerts
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  select a
  from public.alerts a
  where a.sent_at is null
    and a.property_id = p_property_id
    and a.created_at >= now() - interval '24 hours'
    and (
      public._notification_is_quiet(a.created_at)
      or a.created_at < now() - interval '1 hour'
    )
  order by
    case a.severity when 'red' then 0 when 'warn' then 1 else 2 end,
    a.created_at desc
  limit 50;
$$;
revoke all on function public._notification_deferred_alerts(uuid)
  from public, anon, authenticated;

-- Nguoi nhan ban gop chuoi (quyen pham vi chuoi).
create or replace function public._notification_chain_digest_recipients(
  p_org_id uuid
)
returns table (user_id uuid, email text, has_webpush boolean)
language sql stable security definer set search_path = public, auth, pg_temp
as $$
  select distinct u.id,
    public._notification_user_email(u.id),
    exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
  from auth.users u
  left join public.profiles pr on pr.id = u.id
  where coalesce(pr.active, true)
    and public.user_has_perm(u.id, null, 'report.receive.daily_brief')
    and (
      public._notification_user_email(u.id) is not null
      or exists (select 1 from public.push_subscriptions s where s.user_id = u.id)
    )
    and exists (
      select 1
      from public.user_property_roles upr
      join public.roles r on r.id = upr.role_id and r.org_id = p_org_id
      where upr.user_id = u.id
    );
$$;
revoke all on function public._notification_chain_digest_recipients(uuid)
  from public, anon, authenticated;

-- Noi dung ban tin 1 KS: so lieu tu snapshot RPT_DAILY_BRIEF (T-044) +
-- muc alert don. Snapshot null -> ghi ro chu khong che so lieu.
create or replace function public._notification_digest_body(
  p_property_id uuid, p_date date, p_snapshot jsonb
)
returns text
language plpgsql stable security definer set search_path = public, auth, pg_temp
as $$
declare
  v_name text := '';
  v_body text;
  v_item record;
begin
  select p.name into v_name
  from public.properties p where p.id = p_property_id;

  v_body := format('BẢN TIN 8H — %s — ngày %s',
    v_name, to_char(p_date, 'DD/MM/YYYY')) || E'\n';

  if p_snapshot is null then
    v_body := v_body
      || 'Chưa có bản tin 07:30 (snapshot RPT_DAILY_BRIEF chưa xây được).'
      || E'\n';
  else
    v_body := v_body || format(
      'Mua hàng hôm qua: %s đ | Hủy hàng hôm qua: %s đ | Cảnh báo đỏ chưa xác nhận: %s | Công nợ đến hạn 7 ngày: %s đ | Tạm ứng quá hạn: %s (%s đ)',
      to_char(coalesce((p_snapshot ->> 'purchase_yesterday')::numeric, 0), 'FM999,999,999,990'),
      to_char(coalesce((p_snapshot ->> 'waste_yesterday')::numeric, 0), 'FM999,999,999,990'),
      coalesce((p_snapshot ->> 'red_alerts_unacked'), '0'),
      to_char(coalesce((p_snapshot ->> 'ap_due_7d')::numeric, 0), 'FM999,999,999,990'),
      coalesce((p_snapshot -> 'advances_overdue' ->> 'count'), '0'),
      to_char(coalesce((p_snapshot -> 'advances_overdue' ->> 'amount')::numeric, 0), 'FM999,999,999,990')
    ) || E'\n';

    if jsonb_array_length(coalesce(p_snapshot -> 'red_alerts_24h', '[]'::jsonb)) > 0 then
      v_body := v_body || 'Cảnh báo đỏ 24h qua:' || E'\n';
      for v_item in
        select (x ->> 'title') as title, (x ->> 'code') as code,
          (x ->> 'created_at')::timestamptz as created_at
        from jsonb_array_elements(p_snapshot -> 'red_alerts_24h') x
      loop
        v_body := v_body || format('• [%s] %s (%s)',
          to_char(v_item.created_at at time zone 'Asia/Ho_Chi_Minh', 'HH24:MI'),
          v_item.title, v_item.code) || E'\n';
      end loop;
    end if;

    if jsonb_array_length(coalesce(p_snapshot -> 'contracts_expiring', '[]'::jsonb)) > 0 then
      v_body := v_body || 'Hợp đồng sắp hết hạn:' || E'\n';
      for v_item in
        select (x ->> 'title') as title, (x ->> 'end_date')::date as end_date,
          (x ->> 'days_left')::int as days_left
        from jsonb_array_elements(p_snapshot -> 'contracts_expiring') x
      loop
        v_body := v_body || format('• %s — hết hạn %s (còn %s ngày)',
          v_item.title, to_char(v_item.end_date, 'DD/MM/YYYY'), v_item.days_left) || E'\n';
      end loop;
    end if;

    if jsonb_array_length(coalesce(p_snapshot -> 'schedules_unaccepted', '[]'::jsonb)) > 0 then
      v_body := v_body || 'Lịch dịch vụ chưa nghiệm thu:' || E'\n';
      for v_item in
        select (x ->> 'contract_title') as title,
          (x ->> 'period_end')::date as period_end
        from jsonb_array_elements(p_snapshot -> 'schedules_unaccepted') x
      loop
        v_body := v_body || format('• %s — kỳ đến %s',
          v_item.title, to_char(v_item.period_end, 'DD/MM/YYYY')) || E'\n';
      end loop;
    end if;
  end if;

  -- Alert don (chi hien muc nay khi co alert don).
  if exists (select 1 from public._notification_deferred_alerts(p_property_id)) then
    v_body := v_body || 'Cảnh báo dồn từ đêm qua (giờ im lặng / chưa gửi được):' || E'\n';
    for v_item in
      select a.title, a.code, a.created_at
      from public._notification_deferred_alerts(p_property_id) a
    loop
      v_body := v_body || format('• [%s] %s (%s)',
        to_char(v_item.created_at at time zone 'Asia/Ho_Chi_Minh', 'HH24:MI'),
        v_item.title, v_item.code) || E'\n';
    end loop;
  end if;

  return v_body;
end;
$$;
revoke all on function public._notification_digest_body(uuid, date, jsonb)
  from public, anon, authenticated;

-- Gui ban tin 1 KS. Tra ca 'body' de digest_all ghep ban chuoi.
create or replace function public.notification_send_digest(
  p_property_id uuid, p_business_date date default null
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_date date := coalesce(p_business_date, public._report_today());
  v_prop record;
  v_snap jsonb;
  v_body text;
  v_title text;
  v_cfg record;
  v_secret text;
  v_rec record;
  v_channel text;
  v_channels text[] := '{}';
  v_delivery_id uuid;
  v_req bigint;
  v_payload jsonb;
  v_sub jsonb;
  v_zalo text;
  v_dedupe text;
  v_count int := 0;
  v_deferred int := 0;
  v_alert record;
begin
  select * into v_prop from public.properties where id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- Dam bao snapshot ton tai (xay lai idempotent neu job 07:30 loi).
  perform public.report_build_daily(p_property_id, v_date);
  select s.data into v_snap
  from public.report_snapshots s
  where s.property_id = p_property_id
    and s.report_code = 'RPT_DAILY_BRIEF'
    and s.business_date = v_date;

  v_body := public._notification_digest_body(p_property_id, v_date, v_snap);
  v_title := format('Bản tin 8h — %s — %s',
    v_prop.name, to_char(v_date, 'DD/MM/YYYY'));

  select * into v_cfg
  from public.notification_sender_config c
  where c.org_id = v_prop.org_id;
  if v_cfg.id is not null then
    if v_cfg.email_enabled then v_channels := array_append(v_channels, 'email'); end if;
    if v_cfg.webpush_enabled then v_channels := array_append(v_channels, 'webpush'); end if;
    if v_cfg.zalo_enabled then v_channels := array_append(v_channels, 'zalo'); end if;
    v_secret := public._notification_vault_secret(v_cfg.vault_secret_id);
  end if;

  for v_rec in
    select r.user_id, r.email, r.has_webpush
    from public._notification_digest_recipients(v_prop.org_id, p_property_id) r
    where not r.is_chain
  loop
    foreach v_channel in array v_channels loop
      v_payload := null;
      if v_channel = 'email' then
        if v_rec.email is null then continue; end if;
        v_payload := jsonb_build_object(
          'channel', 'email', 'to', v_rec.email,
          'subject', v_title, 'text', v_body, 'property_id', p_property_id);
      elsif v_channel = 'webpush' then
        if not v_rec.has_webpush then continue; end if;
        select row_to_json(s) into v_sub
        from (
          select endpoint, jsonb_build_object('p256dh', p256dh, 'auth', auth) as keys
          from public.push_subscriptions
          where user_id = v_rec.user_id
          order by last_used_at desc nulls last, created_at desc
          limit 1
        ) s;
        if v_sub is null then continue; end if;
        v_payload := jsonb_build_object(
          'channel', 'webpush', 'to', v_sub ->> 'endpoint',
          'subject', v_title, 'text', v_body, 'subscription', v_sub,
          'property_id', p_property_id);
      elsif v_channel = 'zalo' then
        select t.address into v_zalo
        from public.notification_targets t
        where t.user_id = v_rec.user_id and t.channel = 'zalo' and t.active
          and t.address is not null and btrim(t.address) <> ''
        order by t.created_at desc
        limit 1;
        if v_zalo is null then continue; end if;
        v_payload := jsonb_build_object(
          'channel', 'zalo', 'to', v_zalo,
          'subject', v_title, 'text', v_body, 'property_id', p_property_id);
      end if;

      v_dedupe := 'digest:' || p_property_id || ':' || v_date
        || ':' || v_rec.user_id || ':' || v_channel;
      perform set_config('app.notification_guard_bypass', 'on', true);
      insert into public.notification_deliveries
        (org_id, property_id, alert_id, kind, digest_date, channel,
         recipient_user_id, recipient_address, title, body, dedupe_key)
      values
        (v_prop.org_id, p_property_id, null, 'digest', v_date, v_channel,
         v_rec.user_id, v_payload ->> 'to', v_title, v_body, v_dedupe)
      on conflict (dedupe_key) do nothing
      returning id into v_delivery_id;
      if v_delivery_id is null then
        continue;
      end if;
      v_count := v_count + 1;
      v_req := public._notification_http_post(v_cfg.sender_url, v_secret, v_payload);
      if v_req is not null then
        update public.notification_deliveries
        set status = 'sending', attempts = 1, provider_request_id = v_req
        where id = v_delivery_id;
      else
        update public.notification_deliveries
        set status = 'failed', attempts = 1,
            next_attempt_at = now() + interval '5 minutes',
            error_message = 'ERR_NOTIFICATION_SENDER_UNAVAILABLE: chua cau hinh sender_url / secret Vault / pg_net'
        where id = v_delivery_id;
      end if;
    end loop;
  end loop;

  -- Danh dau alert don da gui kem ban tin (log loi nam o dong delivery).
  for v_alert in
    select a.id from public._notification_deferred_alerts(p_property_id) a
  loop
    perform public._notification_mark_alert(v_alert.id, 'digest');
    v_deferred := v_deferred + 1;
  end loop;

  return jsonb_build_object(
    'ok', true, 'property_id', p_property_id, 'date', v_date,
    'deliveries', v_count, 'deferred_marked', v_deferred, 'body', v_body);
end;
$$;
revoke all on function public.notification_send_digest(uuid, date)
  from public, anon, authenticated;
grant execute on function public.notification_send_digest(uuid, date)
  to authenticated;

-- Gui ban tin tat ca KS + ban gop chuoi (08:00 VN). Moi org doc lap.
create or replace function public.notification_send_digest_all(
  p_business_date date default null
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_date date := coalesce(p_business_date, public._report_today());
  v_org record;
  v_prop record;
  v_r jsonb;
  v_chain_body text;
  v_chain_title text;
  v_cfg record;
  v_secret text;
  v_rec record;
  v_channel text;
  v_channels text[] := '{}';
  v_delivery_id uuid;
  v_req bigint;
  v_payload jsonb;
  v_sub jsonb;
  v_zalo text;
  v_dedupe text;
  v_chain_count int := 0;
  v_results jsonb := '[]'::jsonb;
begin
  for v_org in select * from public.organizations order by created_at loop
    v_chain_body := format('BẢN TIN 8H TOÀN CHUỖI — ngày %s',
      to_char(v_date, 'DD/MM/YYYY')) || E'\n';

    for v_prop in
      select * from public.properties
      where org_id = v_org.id order by name
    loop
      v_r := public.notification_send_digest(v_prop.id, v_date);
      v_results := v_results || jsonb_build_array(v_r);
      v_chain_body := v_chain_body || E'\n---\n'
        || coalesce(v_r ->> 'body', '');
    end loop;

    -- Ban gop chuoi cho nguoi co quyen pham vi chuoi.
    select * into v_cfg
    from public.notification_sender_config c
    where c.org_id = v_org.id;
    v_channels := '{}';
    if v_cfg.id is not null then
      if v_cfg.email_enabled then v_channels := array_append(v_channels, 'email'); end if;
      if v_cfg.webpush_enabled then v_channels := array_append(v_channels, 'webpush'); end if;
      if v_cfg.zalo_enabled then v_channels := array_append(v_channels, 'zalo'); end if;
      v_secret := public._notification_vault_secret(v_cfg.vault_secret_id);
    end if;
    if array_length(v_channels, 1) > 0 then
      v_chain_title := format('Bản tin 8h toàn chuỗi — %s',
        to_char(v_date, 'DD/MM/YYYY'));
      for v_rec in
        select * from public._notification_chain_digest_recipients(v_org.id)
      loop
        foreach v_channel in array v_channels loop
          v_payload := null;
          if v_channel = 'email' then
            if v_rec.email is null then continue; end if;
            v_payload := jsonb_build_object(
              'channel', 'email', 'to', v_rec.email,
              'subject', v_chain_title, 'text', v_chain_body);
          elsif v_channel = 'webpush' then
            if not v_rec.has_webpush then continue; end if;
            select row_to_json(s) into v_sub
            from (
              select endpoint, jsonb_build_object('p256dh', p256dh, 'auth', auth) as keys
              from public.push_subscriptions
              where user_id = v_rec.user_id
              order by last_used_at desc nulls last, created_at desc
              limit 1
            ) s;
            if v_sub is null then continue; end if;
            v_payload := jsonb_build_object(
              'channel', 'webpush', 'to', v_sub ->> 'endpoint',
              'subject', v_chain_title, 'text', v_chain_body,
              'subscription', v_sub);
          elsif v_channel = 'zalo' then
            select t.address into v_zalo
            from public.notification_targets t
            where t.user_id = v_rec.user_id and t.channel = 'zalo' and t.active
              and t.address is not null and btrim(t.address) <> ''
            order by t.created_at desc
            limit 1;
            if v_zalo is null then continue; end if;
            v_payload := jsonb_build_object(
              'channel', 'zalo', 'to', v_zalo,
              'subject', v_chain_title, 'text', v_chain_body);
          end if;

          v_dedupe := 'digest:chain:' || v_date
            || ':' || v_rec.user_id || ':' || v_channel;
          perform set_config('app.notification_guard_bypass', 'on', true);
          insert into public.notification_deliveries
            (org_id, property_id, alert_id, kind, digest_date, channel,
             recipient_user_id, recipient_address, title, body, dedupe_key)
          values
            (v_org.id, null, null, 'digest', v_date, v_channel,
             v_rec.user_id, v_payload ->> 'to', v_chain_title, v_chain_body, v_dedupe)
          on conflict (dedupe_key) do nothing
          returning id into v_delivery_id;
          if v_delivery_id is null then
            continue;
          end if;
          v_chain_count := v_chain_count + 1;
          v_req := public._notification_http_post(v_cfg.sender_url, v_secret, v_payload);
          if v_req is not null then
            update public.notification_deliveries
            set status = 'sending', attempts = 1, provider_request_id = v_req
            where id = v_delivery_id;
          else
            update public.notification_deliveries
            set status = 'failed', attempts = 1,
                next_attempt_at = now() + interval '5 minutes',
                error_message = 'ERR_NOTIFICATION_SENDER_UNAVAILABLE: chua cau hinh sender_url / secret Vault / pg_net'
            where id = v_delivery_id;
          end if;
        end loop;
      end loop;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true, 'date', v_date,
    'properties', v_results, 'chain_deliveries', v_chain_count);
end;
$$;
revoke all on function public.notification_send_digest_all(date)
  from public, anon, authenticated;
grant execute on function public.notification_send_digest_all(date)
  to authenticated;

-- Xay ban tin 8h cho moi KS (07:30 VN) — goi report_build_daily (T-044).
create or replace function public.notification_build_daily_all()
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_prop record;
  v_count int := 0;
begin
  for v_prop in select id from public.properties loop
    perform public.report_build_daily(v_prop.id, null);
    v_count := v_count + 1;
  end loop;
  return jsonb_build_object('ok', true, 'properties', v_count);
end;
$$;
revoke all on function public.notification_build_daily_all()
  from public, anon, authenticated;
grant execute on function public.notification_build_daily_all()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. RPC cong khai: alert_ack + push subscription + notification_targets.
-- ---------------------------------------------------------------------------
-- Xac nhan da doc 1 alert (idempotent: ack roi tra lai ack cu).
create or replace function public.alert_ack(p_alert_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
declare
  v_alert record;
begin
  if auth.uid() is null then
    raise exception 'ERR_FORBIDDEN';
  end if;
  select * into v_alert from public.alerts where id = p_alert_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if not public.has_perm(v_alert.property_id,
    'alert.receive.' || lower(v_alert.code)) then
    raise exception 'ERR_FORBIDDEN';
  end if;
  if v_alert.ack_at is not null then
    return jsonb_build_object(
      'ok', true, 'alert_id', p_alert_id,
      'acked_at', v_alert.ack_at, 'already', true);
  end if;
  perform set_config('app.notification_guard_bypass', 'on', true);
  update public.alerts
  set ack_by = auth.uid(), ack_at = now()
  where id = p_alert_id;
  return jsonb_build_object(
    'ok', true, 'alert_id', p_alert_id, 'acked_at', now(), 'already', false);
end;
$$;
revoke all on function public.alert_ack(uuid) from public, anon;
grant execute on function public.alert_ack(uuid) to authenticated;

-- Dang ky web push cho thiet bi hien tai (endpoint + khoa VAPID client).
-- Upsert: dang ky lai cung endpoint chi cap nhat khoa.
create or replace function public.push_subscribe(
  p_endpoint text, p_p256dh text, p_auth text
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'ERR_FORBIDDEN';
  end if;
  if p_endpoint is null or p_endpoint not like 'https://%'
    or p_p256dh is null or btrim(p_p256dh) = ''
    or p_auth is null or btrim(p_auth) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  perform set_config('app.notification_guard_bypass', 'on', true);
  insert into public.push_subscriptions
    (user_id, endpoint, p256dh, auth)
  values
    (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set
    user_id = excluded.user_id,
    p256dh = excluded.p256dh,
    auth = excluded.auth,
    updated_at = now();
  insert into public.notification_targets
    (user_id, channel, address, active)
  values
    (auth.uid(), 'webpush', p_endpoint, true)
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'endpoint', p_endpoint);
end;
$$;
revoke all on function public.push_subscribe(text, text, text)
  from public, anon;
grant execute on function public.push_subscribe(text, text, text)
  to authenticated;

-- Huy dang ky web push (xoa subscription + tat target).
create or replace function public.push_unsubscribe(p_endpoint text)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'ERR_FORBIDDEN';
  end if;
  if p_endpoint is null or btrim(p_endpoint) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  perform set_config('app.notification_guard_bypass', 'on', true);
  delete from public.push_subscriptions
  where user_id = auth.uid() and endpoint = p_endpoint;
  update public.notification_targets
  set active = false
  where user_id = auth.uid() and channel = 'webpush'
    and address = p_endpoint;
  return jsonb_build_object('ok', true, 'endpoint', p_endpoint);
end;
$$;
revoke all on function public.push_unsubscribe(text) from public, anon;
grant execute on function public.push_unsubscribe(text) to authenticated;

-- Luu kenh nhan cua chinh minh: email ghi de / Zalo user id / tat-mo kenh.
create or replace function public.notification_targets_save(
  p_channel text, p_address text, p_active boolean default true
)
returns jsonb
language plpgsql security definer set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'ERR_FORBIDDEN';
  end if;
  if p_channel not in ('email', 'webpush', 'zalo') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_channel = 'email' and p_address is not null
    and p_address not like '%@%.%' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  perform set_config('app.notification_guard_bypass', 'on', true);
  insert into public.notification_targets
    (user_id, channel, address, active)
  values
    (auth.uid(), p_channel, nullif(btrim(coalesce(p_address, '')), ''), p_active)
  on conflict (user_id, channel, address) do update set
    active = excluded.active, updated_at = now();
  return jsonb_build_object(
    'ok', true, 'channel', p_channel, 'active', p_active);
end;
$$;
revoke all on function public.notification_targets_save(text, text, boolean)
  from public, anon;
grant execute on function public.notification_targets_save(text, text, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 9. pg_cron: xay ban tin 07:30 VN (00:30 UTC), gui ban tin 08:00 VN
--    (01:00 UTC), worker canh bao moi 5 phut. pg_cron chay theo UTC.
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'T-045: pg_cron khong cai duoc (%), bo qua lich chay.', sqlerrm;
end $$;

do $$
begin
  create extension if not exists pg_net with schema extensions;
exception when others then
  raise notice 'T-045: pg_net khong cai duoc (%), bo qua — worker se bao loi sender unavailable.', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (
      select 1 from cron.job where jobname = 'notification-build-daily'
    ) then
      perform cron.schedule(
        'notification-build-daily',
        '30 0 * * *',
        'select public.notification_build_daily_all()'
      );
    end if;
    if not exists (
      select 1 from cron.job where jobname = 'notification-digest-daily'
    ) then
      perform cron.schedule(
        'notification-digest-daily',
        '0 1 * * *',
        'select public.notification_send_digest_all()'
      );
    end if;
    if not exists (
      select 1 from cron.job where jobname = 'notification-worker-5min'
    ) then
      perform cron.schedule(
        'notification-worker-5min',
        '*/5 * * * *',
        'select public.notification_worker()'
      );
    end if;
  end if;
end $$;
