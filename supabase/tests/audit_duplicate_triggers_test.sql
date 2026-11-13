-- audit_duplicate_triggers_test.sql — Q253 (migration 20261109568000).
-- Moi bang chi con dung 1 trigger audit_trigger() va do la trg_<bang>_audit.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

select is(
  (select count(*) from pg_trigger t
    where t.tgrelid = ('public.' || tbl)::regclass and not t.tgisinternal
      and t.tgfoid = 'public.audit_trigger'::regproc),
  1::bigint, tbl || ' has exactly one audit trigger')
from unnest(array['goods_receipts','goods_receipt_lines','qc_templates',
                  'supplier_returns','supplier_return_lines']) as tbl;

select is(
  (select count(*) from pg_trigger t
    where t.tgrelid = ('public.' || tbl)::regclass
      and t.tgname = 'trg_' || tbl || '_audit'),
  1::bigint, tbl || ' keeps trg_' || tbl || '_audit')
from unnest(array['goods_receipts','goods_receipt_lines','qc_templates',
                  'supplier_returns','supplier_return_lines']) as tbl;

select finish();
rollback;
