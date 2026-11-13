-- demo-cycle-po.sql — chay buoc 1-5 cua docs/go-live/demo-walkthrough.md tren TEST47 (Q264).
-- DU LIEU DEMO. Moi buoc goi dung RPC that voi tai khoan UAT tuong ung (jwt gia lap trong giao dich):
--   uat.purchaser tao + gui PR  ->  uat.gm duyet PR  ->  uat.purchaser tao PO tu PR (NCC SUP0001), gui duyet
--   ->  uat.gm duyet PO  ->  uat.purchaser gui PO cho NCC.
-- DUNG o PO "da gui". Buoc 6-12 (nhan hang mu can PIN + anh, dang phieu can PIN, hoa don, thanh toan) do
-- nguoi that lam qua giao dien vi can PIN cua tung tai khoan.
begin;
create temp table demo_ctx (key text primary key, val text);
grant all on demo_ctx to authenticated;
create or replace function pg_temp._as(p_email text) returns void language plpgsql as $$
declare v uuid;
begin
  select val::uuid into v from demo_ctx where key = 'u:' || p_email;
  if v is null then raise exception 'khong co tai khoan %', p_email; end if;
  perform set_config('request.jwt.claim.sub', v::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v::text, 'role', 'authenticated')::text, true);
end $$;
grant execute on function pg_temp._as(text) to authenticated;
insert into demo_ctx values ('prop', 'b0000000-0000-4000-8000-000000000002');
insert into demo_ctx select 'u:' || email, id::text from auth.users where email in ('uat.purchaser@erp.internal', 'uat.gm@erp.internal');

set local role authenticated;

-- 1. Thu mua tao PR: NVL0388 10 kg, gui duyet.
select pg_temp._as('uat.purchaser@erp.internal');
select public.pr_save_draft('b0000000-0000-4000-8000-000000000002'::uuid,
  jsonb_build_object('kind', 'stock', 'lines', jsonb_build_array(
    jsonb_build_object('item_id', 'b0000000-0000-4000-8000-000000000011', 'qty', 10, 'uom', 'kg'))));
insert into demo_ctx
select 'pr', id::text from public.purchase_requests
where status = 'draft' and created_by = (select val::uuid from demo_ctx where key = 'u:uat.purchaser@erp.internal')
order by created_at desc limit 1;
select public.pr_submit('b0000000-0000-4000-8000-000000000002'::uuid, (select val::uuid from demo_ctx where key = 'pr'));

-- 2. Quan ly duyet PR.
select pg_temp._as('uat.gm@erp.internal');
select public.pr_decide('b0000000-0000-4000-8000-000000000002'::uuid, (select val::uuid from demo_ctx where key = 'pr'), 'approved', 'Demo');

-- 3. Thu mua tao PO tu dong PR (NCC SUP0001), gui duyet.
select pg_temp._as('uat.purchaser@erp.internal');
select public.po_create_from_pr('b0000000-0000-4000-8000-000000000002'::uuid,
  array(select l.id from public.purchase_request_lines l where l.pr_id = (select val::uuid from demo_ctx where key = 'pr')),
  (select id from public.suppliers where code = 'SUP0001' and external_codes->>'source' = 'synthetic'),
  'contract');
insert into demo_ctx
select 'po', id::text from public.purchase_orders
where created_by = (select val::uuid from demo_ctx where key = 'u:uat.purchaser@erp.internal') and status = 'draft'
order by created_at desc limit 1;
select public.po_submit('b0000000-0000-4000-8000-000000000002'::uuid, (select val::uuid from demo_ctx where key = 'po'));

-- 4. Quan ly duyet PO.
select pg_temp._as('uat.gm@erp.internal');
select public.approval_decide('b0000000-0000-4000-8000-000000000002'::uuid, 'po', (select val::uuid from demo_ctx where key = 'po'), 'approved', 'Demo');

-- 5. Thu mua gui PO cho NCC.
select pg_temp._as('uat.purchaser@erp.internal');
select public.po_send('b0000000-0000-4000-8000-000000000002'::uuid, (select val::uuid from demo_ctx where key = 'po'));

reset role;
select p.doc_no, p.status, p.total_amount, s.code as supplier
from public.purchase_orders p join public.suppliers s on s.id = p.supplier_id
where p.id = (select val::uuid from demo_ctx where key = 'po');
commit;
