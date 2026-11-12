-- ============================================================================
-- Q249 — 20261109565000_admin_system_health
--   P1 go-live muc 6: man "suc khoe he thong" cho quan tri chuoi.
--   RPC admin_system_health() (chi doc) tra ve:
--     * cron: moi job pg_cron — lan chay cuoi, so lan loi 7 ngay;
--     * notifications: so dong notification_deliveries theo trang thai,
--       so dong ket (queued/sending qua 1 gio), so dong failed;
--     * alerts: so canh bao chua xac nhan theo muc do (red/warn/info);
--     * database: kich thuoc DB, audit_log (so dong uoc tinh + dung luong).
--   Quyen moi admin.health.view (sys_admin, owner). Khong bang moi => khong
--   can RLS moi; ham SECURITY DEFINER can quyen doc schema cron.
-- ============================================================================

insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values (
  'admin.health.view', 'Quản trị', 'Xem sức khỏe hệ thống',
  'Xem tình trạng cron, hàng đợi thông báo, cảnh báo chưa xử lý và dung lượng cơ sở dữ liệu.',
  'sensitive', 80
)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'admin.health.view'
from public.roles r
where r.is_system and r.code in ('sys_admin', 'owner')
on conflict (role_id, permission_code) do nothing;

create or replace function public.admin_system_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, cron, pg_temp
as $$
declare
  v_cron jsonb;
  v_notif jsonb;
  v_alerts jsonb;
  v_db jsonb;
begin
  perform public.require_perm(null, 'admin.health.view');

  select coalesce(jsonb_agg(jsonb_build_object(
      'jobname', j.jobname,
      'schedule', j.schedule,
      'active', j.active,
      'last_status', lr.status,
      'last_run_at', lr.start_time,
      'failed_7d', coalesce(f.failed, 0),
      'runs_7d', coalesce(f.runs, 0)
    ) order by j.jobname), '[]'::jsonb)
  into v_cron
  from cron.job j
  left join lateral (
    select d.status, d.start_time
    from cron.job_run_details d
    where d.jobid = j.jobid
    order by d.start_time desc
    limit 1
  ) lr on true
  left join lateral (
    select count(*) filter (where d.status = 'failed') as failed, count(*) as runs
    from cron.job_run_details d
    where d.jobid = j.jobid and d.start_time >= now() - interval '7 days'
  ) f on true;

  select jsonb_build_object(
    'queued', count(*) filter (where status = 'queued'),
    'sending', count(*) filter (where status = 'sending'),
    'sent', count(*) filter (where status = 'sent'),
    'failed', count(*) filter (where status = 'failed'),
    'skipped_quiet', count(*) filter (where status = 'skipped_quiet'),
    'stuck', count(*) filter (
      where status in ('queued', 'sending') and next_attempt_at < now() - interval '1 hour')
  ) into v_notif
  from public.notification_deliveries;

  select jsonb_build_object(
    'red', count(*) filter (where severity = 'red'),
    'warn', count(*) filter (where severity = 'warn'),
    'info', count(*) filter (where severity = 'info'),
    'oldest_at', min(created_at)
  ) into v_alerts
  from public.alerts
  where ack_at is null;

  select jsonb_build_object(
    'db_bytes', pg_database_size(current_database()),
    'audit_log_bytes', pg_total_relation_size('public.audit_log'),
    'audit_log_rows_estimate', (
      select greatest(c.reltuples, 0)::bigint from pg_class c where c.oid = 'public.audit_log'::regclass),
    'stock_moves_rows_estimate', (
      select greatest(c.reltuples, 0)::bigint from pg_class c where c.oid = 'public.stock_moves'::regclass)
  ) into v_db;

  return jsonb_build_object(
    'ok', true,
    'generated_at', now(),
    'cron', v_cron,
    'notifications', v_notif,
    'alerts', v_alerts,
    'database', v_db
  );
end;
$$;

revoke all on function public.admin_system_health() from public, anon;
grant execute on function public.admin_system_health() to authenticated, service_role;
