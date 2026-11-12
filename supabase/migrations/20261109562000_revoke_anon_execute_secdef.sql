-- ============================================================================
-- Q241 — 20261109562000_revoke_anon_execute_secdef
--   Ra soat 12/11/2026 (truy van pg_proc tren production): 24 ham SECURITY
--   DEFINER trong schema public co EXECUTE cho PUBLIC va anon (nguoi CHUA dang
--   nhap): receiving_* (gom receiving_post), supplier_return_*,
--   admin_qc_template_*, _verify_pin, _minibar_*, _restaurant_*,
--   check_temp_item_not_expired, mark_import_temp_item. Cac ham nay deu goi
--   require_perm / auth.uid() nen nguoi chua dang nhap khong lam duoc gi, nhung
--   nguyen tac he thong (04-SECURITY-RLS: client khong tin) la khong de ham
--   nghiep vu goi duoc o vai tro anon.
--   Nguyen nhan: cac migration cu (230000 receiving, 250000 supplier_returns...)
--   tao ham ma khong `revoke ... from public, anon` nhu cac migration sau.
--
--   Cach lam: duyet MOI ham SECURITY DEFINER trong public ma anon dang co
--   EXECUTE, thu hoi tu PUBLIC va anon, cap lai cho authenticated va
--   service_role (hanh vi cho nguoi dung dang nhap va cron/Edge Function KHONG
--   doi). Ham da duoc thu hoi tu truoc (anon khong co EXECUTE) khong bi dong
--   toi. Chay lai an toan (idempotent).
-- ============================================================================
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and has_function_privilege('anon', p.oid, 'execute')
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated, service_role', r.sig);
  end loop;
end;
$$;
