-- sod_invoice_gr_payment_approver_test.sql
--
-- Q242 (migration 20261109563000): thuc thi 2 quy tac SoD.
--   SOD_INVOICE_GR       — nguoi nhap hoa don != nguoi nhan hang (invoice_match).
--   SOD_PAYMENT_APPROVER — nguoi duyet thanh toan != nguoi nhap hoa don trong
--                          de nghi != nguoi yeu cau doi STK NCC trong 30 ngay
--                          (payment_request_decide, chi khi duyet).
-- Ca cho qua nho sod_exceptions con han (alert SOD_EXCEPTION_USED).
--
-- Chay trong begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

-- ---------------------------------------------------------------------------
-- Fixture: prefix a42d0000.
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('a42d0000-0000-4000-8000-000000000001', 'Q242 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a42d0000-0000-4000-8000-000000000101', 'a42d0000-0000-4000-8000-000000000001', 'Q242', 'Entity Q242');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000101', 'PQ242', 'Property Q242', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('a42d0000-0000-4000-8000-000000000401', 'a42d0000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom, allowed_channels) values
  ('a42d0000-0000-4000-8000-000000000501', 'a42d0000-0000-4000-8000-000000000001', 'ITM_Q242', 'Gạo Q242', 'a42d0000-0000-4000-8000-000000000401', 'kg', array['contract']);
insert into public.suppliers (id, org_id, code, name, kind, status, payment_terms_days, bank_changed_at) values
  ('a42d0000-0000-4000-8000-000000000701', 'a42d0000-0000-4000-8000-000000000001', 'NCC_Q242', 'NCC Q242', 'company', 'active', 30, null);
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('a42d0000-0000-4000-8000-000000000301', 'a42d0000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a42d0000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-q242@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a42d0000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-q242@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a42d0000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-q242@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a42d0000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-q242@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a42d0000-0000-4000-8000-000000000a01', 'NV Q242 01', 'Kế toán Q242'),
  ('a42d0000-0000-4000-8000-000000000a02', 'NV Q242 02', 'KTT 1 Q242'),
  ('a42d0000-0000-4000-8000-000000000a03', 'NV Q242 03', 'KTT 2 Q242'),
  ('a42d0000-0000-4000-8000-000000000a07', 'NV Q242 07', 'Thủ kho Q242')
on conflict (id) do update set employee_code = excluded.employee_code, full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('a42d0000-0000-4000-8000-000000000601', 'a42d0000-0000-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('a42d0000-0000-4000-8000-000000000602', 'a42d0000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng'),
  ('a42d0000-0000-4000-8000-000000000607', 'a42d0000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho');
insert into public.role_permissions (role_id, permission_code) values
  ('a42d0000-0000-4000-8000-000000000601', 'invoice.manage'),
  ('a42d0000-0000-4000-8000-000000000601', 'payment.request'),
  ('a42d0000-0000-4000-8000-000000000602', 'invoice.manage'),
  ('a42d0000-0000-4000-8000-000000000602', 'invoice.approve'),
  ('a42d0000-0000-4000-8000-000000000602', 'payment.request'),
  ('a42d0000-0000-4000-8000-000000000602', 'payment.approve'),
  ('a42d0000-0000-4000-8000-000000000607', 'invoice.manage');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a42d0000-0000-4000-8000-000000000a01', 'a42d0000-0000-4000-8000-000000000601', 'a42d0000-0000-4000-8000-000000000201'),
  ('a42d0000-0000-4000-8000-000000000a02', 'a42d0000-0000-4000-8000-000000000602', 'a42d0000-0000-4000-8000-000000000201'),
  ('a42d0000-0000-4000-8000-000000000a03', 'a42d0000-0000-4000-8000-000000000602', 'a42d0000-0000-4000-8000-000000000201'),
  ('a42d0000-0000-4000-8000-000000000a07', 'a42d0000-0000-4000-8000-000000000607', 'a42d0000-0000-4000-8000-000000000201');

-- PO da gui + 3 dong; phieu nhan da post (nguoi nhan = a07, thu kho).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, status, created_by, doc_no) values
  ('a42d0000-0000-4000-8000-000000000b01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000101', 'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', 'sent', 'a42d0000-0000-4000-8000-000000000a01', 'PO-Q242-001');
insert into public.purchase_order_lines (id, po_id, org_id, item_id, description, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('a42d0000-0000-4000-8000-000000000c01', 'a42d0000-0000-4000-8000-000000000b01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000501', 'Gạo A', 10, 'kg', 10, 10000, 'manual', 10),
  ('a42d0000-0000-4000-8000-000000000c02', 'a42d0000-0000-4000-8000-000000000b01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000501', 'Gạo B', 5, 'kg', 5, 20000, 'manual', 5),
  ('a42d0000-0000-4000-8000-000000000c03', 'a42d0000-0000-4000-8000-000000000b01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000501', 'Gạo C', 20, 'kg', 20, 5000, 'manual', 20);
select set_config('app.pr_po_guard_bypass', 'off', true);

select set_config('app.receiving_guard_bypass', 'on', true);
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, po_id, supplier_id, warehouse_id, doc_no, receiver_id, status) values
  ('a42d0000-0000-4000-8000-000000000e01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000101', 'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000b01', 'a42d0000-0000-4000-8000-000000000701', 'a42d0000-0000-4000-8000-000000000301', 'GR-Q242-001', 'a42d0000-0000-4000-8000-000000000a07', 'posted');
insert into public.goods_receipt_lines (id, gr_id, org_id, property_id, po_line_id, item_id, gross_qty, tare_qty, uom, net_qty_stock, unit_cost, accepted_qty_stock, qc_status, posted_warehouse_id) values
  ('a42d0000-0000-4000-8000-000000000e11', 'a42d0000-0000-4000-8000-000000000e01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000c01', 'a42d0000-0000-4000-8000-000000000501', 10, 0, 'kg', 10, 10000, 10, 'pass', 'a42d0000-0000-4000-8000-000000000301'),
  ('a42d0000-0000-4000-8000-000000000e12', 'a42d0000-0000-4000-8000-000000000e01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000c02', 'a42d0000-0000-4000-8000-000000000501', 5, 0, 'kg', 5, 20000, 5, 'pass', 'a42d0000-0000-4000-8000-000000000301'),
  ('a42d0000-0000-4000-8000-000000000e13', 'a42d0000-0000-4000-8000-000000000e01', 'a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000c03', 'a42d0000-0000-4000-8000-000000000501', 20, 0, 'kg', 20, 5000, 20, 'pass', 'a42d0000-0000-4000-8000-000000000301');
select set_config('app.receiving_guard_bypass', 'off', true);

create temp table a42_ctx (key text primary key, id uuid);
create temp table a42_resp (key text primary key, resp jsonb);
grant all on a42_ctx, a42_resp to authenticated;
create or replace function public._a42_as(p_user uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- SOD_INVOICE_GR
-- ---------------------------------------------------------------------------
-- invA: a07 (nguoi NHAN hang) nhap hoa don cho dong c01.
select public._a42_as('a42d0000-0000-4000-8000-000000000a07');
insert into a42_resp values ('invA', public.invoice_save_draft(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000001", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "a42d0000-0000-4000-8000-000000000c01", "qty": 10, "unit_price": 10000, "vat_rate": 0}]'::jsonb));
insert into a42_ctx values ('invA', (select (resp ->> 'id')::uuid from a42_resp where key = 'invA'));

-- (1) Nguoi KHAC (a01) bam khop hoa don do a07 nhap -> van bi chan (kiem theo nguoi nhap).
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
select throws_ok(
  format('select public.invoice_match(%L::uuid)', (select id::text from a42_ctx where key = 'invA')),
  'P0001', 'ERR_SOD_INVOICE_GR',
  'invoice entered by the receiver is blocked even when another user matches it');
-- (2) Chinh a07 bam khop -> bi chan.
select public._a42_as('a42d0000-0000-4000-8000-000000000a07');
select throws_ok(
  format('select public.invoice_match(%L::uuid)', (select id::text from a42_ctx where key = 'invA')),
  'P0001', 'ERR_SOD_INVOICE_GR',
  'receiver matching his own invoice is blocked');

-- (3) invB do a01 (khong phai nguoi nhan) nhap -> khop binh thuong.
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
insert into a42_resp values ('invB', public.invoice_save_draft(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000002", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "a42d0000-0000-4000-8000-000000000c02", "qty": 5, "unit_price": 20000, "vat_rate": 0}]'::jsonb));
insert into a42_ctx values ('invB', (select (resp ->> 'id')::uuid from a42_resp where key = 'invB'));
insert into a42_resp values ('matchB', public.invoice_match((select id from a42_ctx where key = 'invB')));
select is((select resp ->> 'status' from a42_resp where key = 'matchB'), 'matched',
  'invoice entered by a non-receiver matches normally');

-- (4) Cap ngoai le sod_exceptions cho a07 -> khop duoc.
reset role;
insert into public.sod_exceptions (property_id, user_id, rule_code, reason, valid_to, approved_by) values
  ('a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000a07', 'SOD_INVOICE_GR',
   'Q242 test: khach san nho, thu kho kiem nhap hoa don', '2030-12-31', 'a42d0000-0000-4000-8000-000000000a03');
set local role authenticated;
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
select lives_ok(
  format('select public.invoice_match(%L::uuid)', (select id::text from a42_ctx where key = 'invA')),
  'valid sod_exception lets the receiver-entered invoice through');
reset role;
select is(
  (select count(*) from public.alerts
   where code = 'SOD_EXCEPTION_USED' and property_id = 'a42d0000-0000-4000-8000-000000000201'),
  1::bigint, 'using the exception raises one SOD_EXCEPTION_USED alert');
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Duyet hoa don (SoD cu: nguoi duyet != nguoi nhap) de co hoa don 'approved'.
-- ---------------------------------------------------------------------------
select public._a42_as('a42d0000-0000-4000-8000-000000000a02');
insert into a42_resp values ('apprA', public.invoice_approve((select id from a42_ctx where key = 'invA')));
select is((select resp ->> 'status' from a42_resp where key = 'apprA'), 'approved', 'invA approved by a02');
insert into a42_resp values ('apprB', public.invoice_approve((select id from a42_ctx where key = 'invB')));
select is((select resp ->> 'status' from a42_resp where key = 'apprB'), 'approved', 'invB approved by a02');

-- invC: a02 (ke toan truong) nhap + khop, a03 duyet.
insert into a42_resp values ('invC', public.invoice_save_draft(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  '{"invoice_symbol": "AA", "invoice_no": "0000003", "invoice_date": "2026-11-09"}'::jsonb,
  '[{"po_line_id": "a42d0000-0000-4000-8000-000000000c03", "qty": 20, "unit_price": 5000, "vat_rate": 0}]'::jsonb));
insert into a42_ctx values ('invC', (select (resp ->> 'id')::uuid from a42_resp where key = 'invC'));
insert into a42_resp values ('matchC', public.invoice_match((select id from a42_ctx where key = 'invC')));
select is((select resp ->> 'status' from a42_resp where key = 'matchC'), 'matched', 'invC (entered by a02, not a receiver) matched');
select public._a42_as('a42d0000-0000-4000-8000-000000000a03');
insert into a42_resp values ('apprC', public.invoice_approve((select id from a42_ctx where key = 'invC')));
select is((select resp ->> 'status' from a42_resp where key = 'apprC'), 'approved', 'invC approved by a03');

-- ---------------------------------------------------------------------------
-- SOD_PAYMENT_APPROVER
-- ---------------------------------------------------------------------------
-- PR1: invB (a01 nhap) -> a02 duyet duoc.
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
insert into a42_resp values ('pr1', public.payment_request_create(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from a42_ctx where key = 'invB'), 'amount', 40000)), null));
insert into a42_ctx values ('pr1', (select (resp ->> 'id')::uuid from a42_resp where key = 'pr1'));
select public._a42_as('a42d0000-0000-4000-8000-000000000a02');
insert into a42_resp values ('dec1', public.payment_request_decide(
  'a42d0000-0000-4000-8000-000000000201', (select id from a42_ctx where key = 'pr1'), 'approved', null));
select is((select resp ->> 'status' from a42_resp where key = 'dec1'), 'approved',
  'approver who did not enter any invoice in the request may approve');

-- PR2: invC (a02 nhap).
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
insert into a42_resp values ('pr2', public.payment_request_create(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from a42_ctx where key = 'invC'), 'amount', 40000)), null));
insert into a42_ctx values ('pr2', (select (resp ->> 'id')::uuid from a42_resp where key = 'pr2'));
select public._a42_as('a42d0000-0000-4000-8000-000000000a02');
select throws_ok(
  format('select public.payment_request_decide(%L::uuid, %L::uuid, %L, null)',
    'a42d0000-0000-4000-8000-000000000201', (select id::text from a42_ctx where key = 'pr2'), 'approved'),
  'P0001', 'ERR_SOD_PAYMENT_APPROVER',
  'approver who entered an invoice in the request is blocked');
select public._a42_as('a42d0000-0000-4000-8000-000000000a03');
insert into a42_resp values ('dec2', public.payment_request_decide(
  'a42d0000-0000-4000-8000-000000000201', (select id from a42_ctx where key = 'pr2'), 'approved', null));
select is((select resp ->> 'status' from a42_resp where key = 'dec2'), 'approved',
  'another approver can approve the same request');

-- PR4: a02 TU CHOI de nghi chua invC (a02 nhap) -> khong bi chan (rule chi ap dung khi duyet).
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
insert into a42_resp values ('pr4', public.payment_request_create(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from a42_ctx where key = 'invC'), 'amount', 30000)), null));
insert into a42_ctx values ('pr4', (select (resp ->> 'id')::uuid from a42_resp where key = 'pr4'));
select public._a42_as('a42d0000-0000-4000-8000-000000000a02');
insert into a42_resp values ('dec4', public.payment_request_decide(
  'a42d0000-0000-4000-8000-000000000201', (select id from a42_ctx where key = 'pr4'), 'rejected', 'Test tu choi'));
select is((select resp ->> 'status' from a42_resp where key = 'dec4'), 'cancelled',
  'rejecting is not blocked by SOD_PAYMENT_APPROVER');

-- Doi STK: a03 yeu cau doi STK NCC (hom nay); a02 yeu cau doi STK 40 ngay truoc.
reset role;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_at) values
  ('a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000701', 'VCB', '0011', 'NCC Q242', 'pending', 'a42d0000-0000-4000-8000-000000000a03', now()),
  ('a42d0000-0000-4000-8000-000000000001', 'a42d0000-0000-4000-8000-000000000701', 'VCB', '0022', 'NCC Q242', 'revoked', 'a42d0000-0000-4000-8000-000000000a02', now() - interval '40 days');
set local role authenticated;

-- PR5: invB (a01 nhap) 30000.
select public._a42_as('a42d0000-0000-4000-8000-000000000a01');
insert into a42_resp values ('pr5', public.payment_request_create(
  'a42d0000-0000-4000-8000-000000000201', 'a42d0000-0000-4000-8000-000000000701',
  jsonb_build_array(jsonb_build_object('invoice_id', (select id from a42_ctx where key = 'invB'), 'amount', 30000)), null));
insert into a42_ctx values ('pr5', (select (resp ->> 'id')::uuid from a42_resp where key = 'pr5'));
select public._a42_as('a42d0000-0000-4000-8000-000000000a03');
select throws_ok(
  format('select public.payment_request_decide(%L::uuid, %L::uuid, %L, null)',
    'a42d0000-0000-4000-8000-000000000201', (select id::text from a42_ctx where key = 'pr5'), 'approved'),
  'P0001', 'ERR_SOD_PAYMENT_APPROVER',
  'approver who requested a bank-account change within 30 days is blocked');
select public._a42_as('a42d0000-0000-4000-8000-000000000a02');
insert into a42_resp values ('dec5', public.payment_request_decide(
  'a42d0000-0000-4000-8000-000000000201', (select id from a42_ctx where key = 'pr5'), 'approved', null));
select is((select resp ->> 'status' from a42_resp where key = 'dec5'), 'approved',
  'a bank-account change older than 30 days does not block the approver');

select finish();
rollback;
