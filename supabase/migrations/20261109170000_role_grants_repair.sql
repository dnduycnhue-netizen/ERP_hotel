-- 20261109170000_role_grants_repair.sql
--
-- Repair: re-apply the 6 master-data role grants from migration
-- 20261109150000 (item.manage -> storekeeper / cost_controller /
-- chief_accountant, warehouse.manage -> storekeeper,
-- room.manage -> hk_supervisor / gm).
--
-- Diagnosis (verified 09/11/2026 15:20-15:24 +07 against production
-- Supabase, project ERP_hotel ufxcjfntesafmqzsjsyr):
--   * supabase_migrations lists 20261109150000 as APPLIED.
--   * role_permissions in production has NO row for any of the 6 grants;
--     only owner holds item.manage / warehouse.manage / room.manage.
--   * The original hypothesis (join filter `r.is_system = true` matching
--     nothing) is WRONG: every production role has is_system = true
--     (17/17 rows, all in org 00dc6aeb-5e34-4e01-9b80-032a72b16d71),
--     so that filter WOULD have matched. The permission codes also
--     exist in the permissions seed.
--   * Conclusion: the push that recorded 20261109150000 as applied did
--     NOT execute its INSERT (or executed it against different data).
--     Root cause of that push behaviour is still unknown; do NOT
--     re-run the old migration (it is already recorded as applied and
--     would be skipped). This repair migration is the fix.
--
-- Safety: pure INSERT ... ON CONFLICT DO NOTHING, join on role code
-- only (no is_system filter, per the T-013 lesson). Idempotent: safe
-- to run even if the grants somehow already exist.
-- After `supabase db push`, verify on production:
--   select r.code, rp.permission_code
--   from role_permissions rp join roles r on r.id = rp.role_id
--   where rp.permission_code in ('item.manage','warehouse.manage','room.manage')
--   order by 2, 1;
-- Expect 9 rows: owner x3 + the 6 repaired grants.

insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('storekeeper', 'item.manage'),
    ('cost_controller', 'item.manage'),
    ('chief_accountant', 'item.manage'),
    ('storekeeper', 'warehouse.manage'),
    ('hk_supervisor', 'room.manage'),
    ('gm', 'room.manage')
) as rp(role_code, permission_code)
  on r.code = rp.role_code
on conflict (role_id, permission_code) do nothing;
