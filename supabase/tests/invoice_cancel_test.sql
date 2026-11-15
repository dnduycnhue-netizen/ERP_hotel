-- Q284 pgTAP: invoice_cancel (huy hoa don Tam giu/Nhap/Da khop de lap hoa don thay the).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(7);

insert into public.organizations (id, name) values ('d2840000-0000-4000-8000-000000000001', 'Q284 Org');
insert into public.legal_entities (id, org_id, code, name) values ('d2840000-0000-4000-8000-000000000101', 'd2840000-0000-4000-8000-000000000001', 'Q284', 'Entity Q284');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values ('d2840000-0000-4000-8000-000000000201', 'd2840000-0000-4000-8000-000000000001', 'd2840000-0000-4000-8000-000000000101', 'P2841', 'Property Q284', 'with_cc');
insert into public.suppliers (id, org_id, code, name, kind, status, payment_terms_days) values ('d2840000-0000-4000-8000-000000000701', 'd2840000-0000-4000-8000-000000000001', 'S284', 'NCC Q284', 'company', 'active', 30);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('d2840000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'acc284@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d2840000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rec284@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('d2840000-0000-4000-8000-000000000a01', 'NV28401', 'KT'), ('d2840000-0000-4000-8000-000000000a02', 'NV28402', 'NH')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('d2840000-0000-4000-8000-000000000601', 'd2840000-0000-4000-8000-000000000001', 'accountant', 'KT'),
  ('d2840000-0000-4000-8000-000000000602', 'd2840000-0000-4000-8000-000000000001', 'receiver', 'NH');
insert into public.role_permissions (role_id, permission_code) values
  ('d2840000-0000-4000-8000-000000000601', 'invoice.manage'),
  ('d2840000-0000-4000-8000-000000000602', 'receiving.view');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d2840000-0000-4000-8000-000000000a01', 'd2840000-0000-4000-8000-000000000601', 'd2840000-0000-4000-8000-000000000201'),
  ('d2840000-0000-4000-8000-000000000a02', 'd2840000-0000-4000-8000-000000000602', 'd2840000-0000-4000-8000-000000000201');

select set_config('app.finance_guard_bypass', 'on', true);
insert into public.supplier_invoices (id, org_id, legal_entity_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date, status) values
  ('d2840000-0000-4000-8000-000000000b01', 'd2840000-0000-4000-8000-000000000001', 'd2840000-0000-4000-8000-000000000101', 'd2840000-0000-4000-8000-000000000201', 'd2840000-0000-4000-8000-000000000701', 'INV-A', 'AA', '1', '2026-11-09', 'on_hold'),
  ('d2840000-0000-4000-8000-000000000b02', 'd2840000-0000-4000-8000-000000000001', 'd2840000-0000-4000-8000-000000000101', 'd2840000-0000-4000-8000-000000000201', 'd2840000-0000-4000-8000-000000000701', 'INV-B', 'AA', '2', '2026-11-09', 'approved');

create or replace function public._q284_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end; $$;

set local role authenticated;
select public._q284_as('d2840000-0000-4000-8000-000000000a02');
select throws_ok($q$select public.invoice_cancel('d2840000-0000-4000-8000-000000000b01', 'sai so')$q$, null, null, 'user without invoice.manage cannot cancel');
select public._q284_as('d2840000-0000-4000-8000-000000000a01');
select throws_ok($q$select public.invoice_cancel('d2840000-0000-4000-8000-000000000b01', '  ')$q$, 'P0001', 'ERR_REASON_REQUIRED', 'reason required');
select throws_ok($q$select public.invoice_cancel('d2840000-0000-4000-8000-000000000b02', 'sai so')$q$, 'P0001', 'ERR_INVALID_STATUS', 'approved invoice cannot be cancelled');
select is((public.invoice_cancel('d2840000-0000-4000-8000-000000000b01', 'sai so tien') ->> 'status'), 'cancelled', 'on_hold invoice cancelled');
select throws_ok($q$select public.invoice_cancel('d2840000-0000-4000-8000-000000000b01', 'lan 2')$q$, 'P0001', 'ERR_INVALID_STATUS', 'cannot cancel twice');
reset role;
select is((select cancel_reason from public.supplier_invoices where id = 'd2840000-0000-4000-8000-000000000b01'), 'sai so tien', 'reason stored');
select ok((select cancelled_by from public.supplier_invoices where id = 'd2840000-0000-4000-8000-000000000b01') = 'd2840000-0000-4000-8000-000000000a01', 'cancelled_by stored');

select * from finish();
rollback;
