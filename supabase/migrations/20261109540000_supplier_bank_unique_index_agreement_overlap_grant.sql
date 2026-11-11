-- ============================================================================
-- T-013 follow-up fixes (found by the pgTAP T-013 wave, 11/11/2026).
--
-- Q218 -- Duplicate PENDING bank account not blocked (test 24):
--   supplier_bank_request() claims (comment in 160000) that "the
--   same-supplier duplicate is blocked by the unique index", but NO unique
--   index on supplier_bank_accounts (supplier_id, account_no) exists anywhere
--   in the repo, so a second pending request for the same account number
--   succeeded instead of raising 23505. The partial index below makes the
--   comment true. Scope is deliberately PENDING-only: a supplier may
--   re-request an account number that is already 'active' (the approve step
--   revokes the previous active row), and the Excel import path also inserts
--   'pending' rows, so it is covered by the same rule.
--
-- Q219 -- price_agreement_lines inserts + agreement activation fail 42501
--   for every app user (tests 40, 42, 43, 45, 46, 48):
--   the overlap check runs in two plain (non-SECURITY-DEFINER) trigger
--   functions, _price_agreement_line_overlap_guard() and
--   _price_agreement_overlap_guard(), which call the helper
--   _check_price_agreement_overlap(). Postgres does NOT check EXECUTE
--   privilege on a trigger function itself, but it DOES check it on a nested
--   regular-function call -- and 160000 revoked ALL on the helper from
--   public, anon, authenticated. Result: every price_agreement_lines INSERT
--   and every agreement activation (draft -> active) died with
--   "42501: permission denied for function _check_price_agreement_overlap"
--   for authenticated users, since T-013. The feature never worked through
--   the UI. Verified by diagnostic #1 (all 10 operations correct as
--   postgres) vs diagnostic #2 (the same 10 as authenticated u1: 6 fail
--   with exactly this 42501). Fix: grant EXECUTE on the helper to
--   authenticated, the same pattern org_access.sql uses for has_perm /
--   require_perm / my_property_ids. The helper only reads and raises, and
--   its queries stay under the caller's RLS, so no information leaks beyond
--   what the caller can already see. A repo-wide scan confirms this is the
--   ONLY trigger -> revoked-helper call chain (73 helpers revoked, only this
--   one called from a trigger).
-- ============================================================================

-- Q218: partial unique index -- duplicate pending bank account per supplier.
create unique index if not exists supplier_bank_accounts_pending_unique
  on public.supplier_bank_accounts (supplier_id, account_no)
  where status = 'pending';

-- Q219: let authenticated users execute the overlap helper the triggers need.
grant execute on function public._check_price_agreement_overlap(uuid)
  to authenticated;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109540000_supplier_bank_unique_index_agreement_overlap_grant',
  'INSERT',
  jsonb_build_object('event', 't013_q218_q219_fixes', 'task', 'T-013'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
