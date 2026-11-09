-- T-013 pgTAP: NCC, thẩm định, đổi STK 2 người (SoD), hợp đồng khung, giá trần, alert BANK_ACCOUNT_CHANGE.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(22);

-- 1. Setup Fixture
insert into public.organizations (id, name) values
  ('d0130000-1300-4000-8000-000000000001', 'T-013 Suppliers Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0130000-1300-4000-8000-000000000101', 'd0130000-1300-4000-8000-000000000001', 'T013', 'Entity T-013');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0130000-1300-4000-8000-000000000201', 'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000101', 'P013', 'Property T-013');

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0130000-1300-4000-8000-000000000401', 'd0130000-1300-4000-8000-000000000001', 'FOOD', 'Thực phẩm', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0130000-1300-4000-8000-000000000501', 'd0130000-1300-4000-8000-000000000001', 'BEEF13', 'Thịt bò T013', 'd0130000-1300-4000-8000-000000000401', 'kg');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0130000-1300-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'purchaser013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0130000-1300-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'accountant013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0130000-1300-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.roles (id, org_id, code, name_vi) values
  ('d0130000-1300-4000-8000-000000000601', 'd0130000-1300-4000-8000-000000000001', 'r_purchaser', 'Thu mua'),
  ('d0130000-1300-4000-8000-000000000602', 'd0130000-1300-4000-8000-000000000001', 'r_chief', 'Kế toán trưởng / Duyệt'),
  ('d0130000-1300-4000-8000-000000000603', 'd0130000-1300-4000-8000-000000000001', 'r_viewer', 'Người xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0130000-1300-4000-8000-000000000601', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000601', 'supplier.manage'),
  ('d0130000-1300-4000-8000-000000000601', 'supplier.bank.request'),
  ('d0130000-1300-4000-8000-000000000601', 'price.agreement.manage'),
  ('d0130000-1300-4000-8000-000000000602', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000602', 'supplier.approve'),
  ('d0130000-1300-4000-8000-000000000602', 'supplier.bank.approve'),
  ('d0130000-1300-4000-8000-000000000602', 'price.ceiling.manage'),
  ('d0130000-1300-4000-8000-000000000602', 'price.view'),
  ('d0130000-1300-4000-8000-000000000603', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000603', 'price.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0130000-1300-4000-8000-000000000a01', 'd0130000-1300-4000-8000-000000000601', 'd0130000-1300-4000-8000-000000000201'),
  ('d0130000-1300-4000-8000-000000000a02', 'd0130000-1300-4000-8000-000000000602', 'd0130000-1300-4000-8000-000000000201'),
  ('d0130000-1300-4000-8000-000000000a03', 'd0130000-1300-4000-8000-000000000603', 'd0130000-1300-4000-8000-000000000201');

-- 2. Kiểm tra RLS và tạo NCC
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

-- User 1 (Thu mua) tạo NCC mới
select lives_ok(
  $q$insert into public.suppliers (
    id, org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, created_by
  ) values (
    'd0130000-1300-4000-8000-000000000701', 'd0130000-1300-4000-8000-000000000001',
    'NCC_CP', 'Công ty Cổ phần Thực phẩm CP Việt Nam', '0100100100', 'company',
    '02838383838', 'Đồng Nai', 30, 'pending', 'd0130000-1300-4000-8000-000000000a01'
  )$q$,
  'Purchaser can create supplier via RLS'
);

select is(
  (select status from public.suppliers where id = 'd0130000-1300-4000-8000-000000000701'),
  'pending',
  'New supplier starts in pending status'
);

-- SoD 1: Người tạo (User 1) cố tự duyệt NCC của chính mình -> bị chặn ERR_SOD_SUPPLIER_CREATOR_APPROVER
select throws_ok(
  $q$select public.supplier_approve('d0130000-1300-4000-8000-000000000701', 'active')$q$,
  '42501', 'ERR_FORBIDDEN:supplier.approve',
  'Purchaser without supplier.approve is forbidden'
);

-- Switch sang User 2 (Kế toán trưởng / Người duyệt)
reset role;
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a02","role":"authenticated"}', true);
set local role authenticated;

-- User 2 duyệt NCC -> thành công
select ok(
  ((select public.supplier_approve('d0130000-1300-4000-8000-000000000701', 'active')) ->> 'ok')::boolean,
  'Approver can approve supplier'
);

select is(
  (select status from public.suppliers where id = 'd0130000-1300-4000-8000-000000000701'),
  'active',
  'Supplier is now active'
);

select is(
  (select approved_by from public.suppliers where id = 'd0130000-1300-4000-8000-000000000701'),
  'd0130000-1300-4000-8000-000000000a02'::uuid,
  'Supplier recorded approver id'
);

-- Thử duyệt khi chính mình là người tạo -> chặn SoD
reset role;
insert into public.suppliers (
  id, org_id, code, name, kind, status, created_by
) values (
  'd0130000-1300-4000-8000-000000000702', 'd0130000-1300-4000-8000-000000000001',
  'NCC_SELF', 'NCC do kế toán tạo', 'company', 'pending', 'd0130000-1300-4000-8000-000000000a02'
);
set local role authenticated;
select throws_ok(
  $q$select public.supplier_approve('d0130000-1300-4000-8000-000000000702', 'active')$q$,
  'P0001', 'ERR_SOD_SUPPLIER_CREATOR_APPROVER',
  'Creator cannot approve their own supplier'
);

-- 3. Phần SoD Đổi STK Nhà Cung Cấp & Alert BANK_ACCOUNT_CHANGE
-- Switch to User 1 (Thu mua) để yêu cầu STK
reset role;
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $q$select public.supplier_bank_request(
    'd0130000-1300-4000-8000-000000000701',
    'Vietcombank CN TP.HCM',
    '0071000123456',
    'CTY CP THUC PHAM CP VN'
  )$q$,
  'User 1 can request new bank account for supplier'
);

-- SoD 2: Người yêu cầu (User 1) cố tự duyệt STK -> chặn ERR_SOD_BANK_ACCOUNT (hoặc thiếu quyền)
select throws_ok(
  $q$select public.supplier_bank_approve(
    (select id from public.supplier_bank_accounts where account_no = '0071000123456'),
    'active'
  )$q$,
  '42501', 'ERR_FORBIDDEN:supplier.bank.approve',
  'User 1 without supplier.bank.approve cannot approve'
);

-- Switch to User 2 (Kế toán trưởng có supplier.bank.approve)
reset role;
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a02","role":"authenticated"}', true);
set local role authenticated;

-- User 2 duyệt STK
select ok(
  ((select public.supplier_bank_approve(
    (select id from public.supplier_bank_accounts where account_no = '0071000123456'),
    'active'
  )) ->> 'ok')::boolean,
  'User 2 can approve bank account (2-person SoD rule met)'
);

select is(
  (select status from public.supplier_bank_accounts where account_no = '0071000123456'),
  'active',
  'Bank account status is active'
);

-- Kiểm tra cảnh báo đỏ BANK_ACCOUNT_CHANGE được sinh tự động
select ok(
  exists (
    select 1 from public.alerts
    where code = 'BANK_ACCOUNT_CHANGE'
      and severity = 'red'
      and (payload ->> 'account_no') = '0071000123456'
  ),
  'Alert BANK_ACCOUNT_CHANGE generated in alerts table'
);

-- User 2 cố tự duyệt STK do chính User 2 yêu cầu -> chặn ERR_SOD_BANK_ACCOUNT
reset role;
insert into public.supplier_bank_accounts (
  id, org_id, supplier_id, bank_name, account_no, account_name, status, requested_by
) values (
  'd0130000-1300-4000-8000-000000000802', 'd0130000-1300-4000-8000-000000000001',
  'd0130000-1300-4000-8000-000000000701', 'Techcombank', '1903000111222',
  'CTY CP THUC PHAM CP VN', 'pending', 'd0130000-1300-4000-8000-000000000a02'
);
set local role authenticated;
select throws_ok(
  $q$select public.supplier_bank_approve('d0130000-1300-4000-8000-000000000802', 'active')$q$,
  'P0001', 'ERR_SOD_BANK_ACCOUNT',
  'Requester cannot approve their own bank account (SoD 2 persons)'
);

-- Khi duyệt tài khoản mới, tài khoản cũ tự động chuyển sang revoked
reset role;
insert into public.supplier_bank_accounts (
  id, org_id, supplier_id, bank_name, account_no, account_name, status, requested_by
) values (
  'd0130000-1300-4000-8000-000000000803', 'd0130000-1300-4000-8000-000000000001',
  'd0130000-1300-4000-8000-000000000701', 'BIDV', '6868686868',
  'CTY CP THUC PHAM CP VN', 'pending', 'd0130000-1300-4000-8000-000000000a01'
);
set local role authenticated;
select ok(
  ((select public.supplier_bank_approve('d0130000-1300-4000-8000-000000000803', 'active')) ->> 'ok')::boolean,
  'Approve new account 6868686868'
);

select is(
  (select status from public.supplier_bank_accounts where account_no = '0071000123456'),
  'revoked',
  'Previous active bank account automatically revoked'
);

select is(
  (select status from public.supplier_bank_accounts where account_no = '6868686868'),
  'active',
  'New bank account is active'
);

-- 4. Hợp đồng khung (Price Agreements & Lines)
reset role;
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $q$insert into public.price_agreements (
    id, org_id, supplier_id, valid_from, valid_to, status
  ) values (
    'd0130000-1300-4000-8000-000000000901', 'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000701', '2026-01-01', '2026-12-31', 'active'
  )$q$,
  'Purchaser can create price agreement'
);

select lives_ok(
  $q$insert into public.price_agreement_lines (
    org_id, agreement_id, item_id, uom, unit_price, warn_pct, lock_pct
  ) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000901',
    'd0130000-1300-4000-8000-000000000501', 'kg', 250000, 5, 10
  )$q$,
  'Purchaser can add price agreement line'
);

select is(
  (select unit_price from public.price_agreement_lines where agreement_id = 'd0130000-1300-4000-8000-000000000901'),
  250000.0000::numeric,
  'Agreement line unit price is 250.000'
);

-- 5. Giá trần (Ceiling Prices)
reset role;
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a02","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $q$insert into public.ceiling_prices (
    id, org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by
  ) values (
    'd0130000-1300-4000-8000-000000000951', 'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000201', 'd0130000-1300-4000-8000-000000000501',
    'kg', 280000, '2026-01-01', '2026-12-31', 'd0130000-1300-4000-8000-000000000a02'
  )$q$,
  'Cost controller can set ceiling price'
);

select is(
  (select price from public.ceiling_prices where id = 'd0130000-1300-4000-8000-000000000951'),
  280000.0000::numeric,
  'Ceiling price is 280.000'
);

-- User 3 (Viewer) không được sửa giá trần
reset role;
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a03","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $q$insert into public.ceiling_prices (
    org_id, item_id, uom, price, valid_from, valid_to, set_by
  ) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000501',
    'kg', 300000, '2026-01-01', '2026-12-31', 'd0130000-1300-4000-8000-000000000a03'
  )$q$,
  '42501', null,
  'Viewer without price.ceiling.manage cannot set ceiling prices'
);

select * from finish();
rollback;
