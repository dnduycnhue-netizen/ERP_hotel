-- revoke_anon_execute_secdef_test.sql
-- Q241: sau migration 562000 khong con ham SECURITY DEFINER nao trong public
-- ma anon goi duoc; authenticated va service_role van goi duoc.
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and has_function_privilege('anon', p.oid, 'execute')),
  0::bigint,
  'no SECURITY DEFINER function in public is executable by anon');

select ok(
  not has_function_privilege('anon', 'public.receiving_post(uuid,text)'::regprocedure, 'execute'),
  'anon cannot execute receiving_post');

select ok(
  not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
    where p.oid = 'public.receiving_post(uuid,text)'::regprocedure
      and a.grantee = 0 and a.privilege_type = 'EXECUTE'),
  'PUBLIC no longer holds EXECUTE on receiving_post');

select ok(
  has_function_privilege('authenticated', 'public.receiving_post(uuid,text)'::regprocedure, 'execute'),
  'authenticated can still execute receiving_post');

select ok(
  has_function_privilege('authenticated', 'public.receiving_list_tasks(uuid,date)'::regprocedure, 'execute'),
  'authenticated can still execute receiving_list_tasks');

select ok(
  has_function_privilege('service_role', 'public.supplier_return_list(uuid,text,text,integer,integer)'::regprocedure, 'execute'),
  'service_role can still execute supplier_return_list');

select finish();
rollback;
