-- T-013 pgTAP: NCC + tham dinh + doi STK 2 nguoi + hop dong khung + gia tran.
-- Kiem tra: RLS alerts, CRUD NCC qua RLS, chong doi truc tiep status,
-- submit/approve + SoD (SOD_SUPPLIER_APPROVER), set_status, doi STK + SoD
-- (SOD_BANK_ACCOUNT) + alert BANK_ACCOUNT_CHANGE, xoa NCC, chong trung lap
-- hop dong khung (ERR_AGREEMENT_OVERLAP), gia tran + current_ceiling_price.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(55);

-- 1. Setup Fixture
insert into public.organizations (id, name) values
  ('d0130000-1300-4000-8000-000000000001', 'T-013 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0130000-1300-4000-8000-000000000101', 'd0130000-1300-4000-8000-000000000001', 'T013', 'Entity T-013');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0130000-1300-4000-8000-000000000201', 'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000101', 'P013', 'Property T-013');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('lon', 'Lon');

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0130000-1300-4000-8000-000000000401', 'd0130000-1300-4000-8000-000000000001', 'GAO', 'Gạo', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item) values
  ('d0130000-1300-4000-8000-000000000501', 'd0130000-1300-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0130000-1300-4000-8000-000000000401', 'kg', true),
  ('d0130000-1300-4000-8000-000000000502', 'd0130000-1300-4000-8000-000000000001', 'ITM_DUONG', 'Đường cát', 'd0130000-1300-4000-8000-000000000401', 'kg', true);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0130000-1300-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'purchaser013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0130000-1300-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gm013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0130000-1300-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'accountant013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0130000-1300-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer013@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

-- SDT cua u1 dung lam SDT NCC de kich hoat canh bao PHONE_MATCHES_STAFF.
insert into public.profiles (id, employee_code, full_name, phone) values
  ('d0130000-1300-4000-8000-000000000a01', 'NV01301', 'Nhan vien mua hang', '0901111111'),
  ('d0130000-1300-4000-8000-000000000a02', 'NV01302', 'Giam doc', '0902222222'),
  ('d0130000-1300-4000-8000-000000000a03', 'NV01303', 'Ke toan truong', '0903333333')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name,
  phone = excluded.phone;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0130000-1300-4000-8000-000000000601', 'd0130000-1300-4000-8000-000000000001', 'r_pur013', 'Mua hang'),
  ('d0130000-1300-4000-8000-000000000602', 'd0130000-1300-4000-8000-000000000001', 'r_gm013', 'Giam doc'),
  ('d0130000-1300-4000-8000-000000000603', 'd0130000-1300-4000-8000-000000000001', 'r_acct013', 'Ke toan truong'),
  ('d0130000-1300-4000-8000-000000000604', 'd0130000-1300-4000-8000-000000000001', 'r_both013', 'Vua tao vua duyet NCC (chi de test SoD)'),
  ('d0130000-1300-4000-8000-000000000605', 'd0130000-1300-4000-8000-000000000001', 'r_bankboth013', 'Vua de xuat vua duyet STK (chi de test SoD)'),
  ('d0130000-1300-4000-8000-000000000606', 'd0130000-1300-4000-8000-000000000001', 'r_view013', 'Chi xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0130000-1300-4000-8000-000000000601', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000601', 'supplier.manage'),
  ('d0130000-1300-4000-8000-000000000601', 'supplier.bank.request'),
  ('d0130000-1300-4000-8000-000000000601', 'price.agreement.manage'),
  ('d0130000-1300-4000-8000-000000000601', 'price.view'),
  ('d0130000-1300-4000-8000-000000000602', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000602', 'supplier.approve'),
  ('d0130000-1300-4000-8000-000000000602', 'price.view'),
  ('d0130000-1300-4000-8000-000000000602', 'alert.receive.bank_account_change'),
  ('d0130000-1300-4000-8000-000000000603', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000603', 'supplier.bank.approve'),
  ('d0130000-1300-4000-8000-000000000603', 'price.ceiling.manage'),
  ('d0130000-1300-4000-8000-000000000603', 'price.view'),
  ('d0130000-1300-4000-8000-000000000604', 'supplier.manage'),
  ('d0130000-1300-4000-8000-000000000604', 'supplier.approve'),
  ('d0130000-1300-4000-8000-000000000605', 'supplier.bank.request'),
  ('d0130000-1300-4000-8000-000000000605', 'supplier.bank.approve'),
  ('d0130000-1300-4000-8000-000000000606', 'supplier.view'),
  ('d0130000-1300-4000-8000-000000000606', 'price.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0130000-1300-4000-8000-000000000a01', 'd0130000-1300-4000-8000-000000000601', 'd0130000-1300-4000-8000-000000000201'),
  ('d0130000-1300-4000-8000-000000000a02', 'd0130000-1300-4000-8000-000000000602', 'd0130000-1300-4000-8000-000000000201'),
  ('d0130000-1300-4000-8000-000000000a02', 'd0130000-1300-4000-8000-000000000604', 'd0130000-1300-4000-8000-000000000201'),
  ('d0130000-1300-4000-8000-000000000a02', 'd0130000-1300-4000-8000-000000000605', 'd0130000-1300-4000-8000-000000000201'),
  -- r_acct013 gan chain-wide (property_id null) de test gia tran cap chuoi.
  ('d0130000-1300-4000-8000-000000000a03', 'd0130000-1300-4000-8000-000000000603', null),
  ('d0130000-1300-4000-8000-000000000a03', 'd0130000-1300-4000-8000-000000000602', 'd0130000-1300-4000-8000-000000000201'),
  ('d0130000-1300-4000-8000-000000000a04', 'd0130000-1300-4000-8000-000000000606', 'd0130000-1300-4000-8000-000000000201');

-- Chuyen sang role authenticated; doi user bang set_config request.jwt.claim.sub.
set local role authenticated;

-- Helper: dat lai JWT claim cho u1 (purchaser).
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);

-- 1. Bang alerts bat RLS.
select is(
  (select relrowsecurity from pg_class where relname = 'alerts'),
  true,
  'alerts has RLS enabled'
);

-- 2. Purchaser them NCC qua RLS (SDT trung nhan vien, thieu MST -> 2 canh bao).
select lives_ok(
  $q$insert into public.suppliers (id, org_id, code, name, kind, phone) values (
    'd0130000-1300-4000-8000-000000000701', 'd0130000-1300-4000-8000-000000000001',
    'NCC_GAO', 'Cong ty Gao Sach', 'company', '0901111111'
  )$q$,
  'Purchaser can insert supplier via RLS'
);

-- 3. Trung ma NCC bi chan.
select throws_ok(
  $q$insert into public.suppliers (org_id, code, name, kind) values (
    'd0130000-1300-4000-8000-000000000001', 'NCC_GAO', 'Cong ty khac', 'company'
  )$q$,
  '23505', null, 'Duplicate supplier code is rejected by unique constraint'
);

-- 4. Doi truc tiep status bi chan boi trigger (chi RPC moi duoc doi).
select throws_ok(
  $q$update public.suppliers set status = 'active' where id = 'd0130000-1300-4000-8000-000000000701'$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Direct supplier status change is blocked by trigger'
);

-- 5. Submit NCC tra ve ok.
select is(
  (select public.supplier_submit(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000701'
  ) ->> 'ok'),
  'true',
  'supplier_submit returns ok for pending supplier'
);

-- 6-7. Canh bao tham dinh: SDT trung nhan vien + thieu MST cong ty.
select ok(
  (select public.supplier_assessment_warnings('d0130000-1300-4000-8000-000000000701')
    @> '[{"code":"PHONE_MATCHES_STAFF"}]'::jsonb),
  'Assessment warns when supplier phone matches a staff phone'
);
select ok(
  (select public.supplier_assessment_warnings('d0130000-1300-4000-8000-000000000701')
    @> '[{"code":"TAX_CODE_MISSING"}]'::jsonb),
  'Assessment warns when a company supplier has no tax code'
);

-- 8. Purchaser them NCC thu 3 (pending, khong co STK) de test xoa.
select lives_ok(
  $q$insert into public.suppliers (id, org_id, code, name, kind) values (
    'd0130000-1300-4000-8000-000000000703', 'd0130000-1300-4000-8000-000000000001',
    'NCC_XOA', 'NCC se xoa', 'household'
  )$q$,
  'Purchaser can insert a second pending supplier'
);

-- Doi sang u2 (gm + r_both + r_bankboth).
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a02","role":"authenticated"}', true);

-- 9. u2 them NCC (created_by = u2).
select lives_ok(
  $q$insert into public.suppliers (id, org_id, code, name, kind, tax_code) values (
    'd0130000-1300-4000-8000-000000000702', 'd0130000-1300-4000-8000-000000000001',
    'NCC_DUONG', 'Cong ty Duong Ngot', 'company', '0123456789'
  )$q$,
  'GM can insert supplier via RLS'
);

-- 10. Nguoi tao khong duoc tu phe duyet NCC cua minh (SOD_SUPPLIER_APPROVER).
select throws_ok(
  $q$select public.supplier_approve(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', true, null
  )$q$,
  'P0001', 'ERR_SOD_SUPPLIER_APPROVER',
  'Supplier creator cannot approve own supplier'
);

-- Doi sang u3 (ke toan truong + gm).
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a03","role":"authenticated"}', true);

-- 11. Nguoi duyet khac phe duyet duoc.
select lives_ok(
  $q$select public.supplier_approve(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', true, null
  )$q$,
  'Another approver can approve the supplier'
);

-- 12-13. Trang thai + nguoi duyet duoc ghi dung.
select is(
  (select status from public.suppliers where id = 'd0130000-1300-4000-8000-000000000702'),
  'active',
  'Supplier is active after approval'
);
select is(
  (select approved_by from public.suppliers where id = 'd0130000-1300-4000-8000-000000000702'),
  'd0130000-1300-4000-8000-000000000a03'::uuid,
  'approved_by is the approver'
);

-- Doi sang u1 (purchaser) de test set_status.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);

-- 14-15. Tam ngung NCC dang hoat dong.
select lives_ok(
  $q$select public.supplier_set_status(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', 'suspended', 'Tam ngung do giao hang tre'
  )$q$,
  'Manager can suspend an active supplier'
);
select is(
  (select status from public.suppliers where id = 'd0130000-1300-4000-8000-000000000702'),
  'suspended',
  'Supplier is suspended'
);

-- 16-17. Mo lai NCC bi tam ngung.
select lives_ok(
  $q$select public.supplier_set_status(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', 'active', 'Da khac phuc'
  )$q$,
  'Manager can reactivate a suspended supplier'
);
select is(
  (select status from public.suppliers where id = 'd0130000-1300-4000-8000-000000000702'),
  'active',
  'Supplier is active again'
);

-- 18. Cam NCC.
select lives_ok(
  $q$select public.supplier_set_status(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', 'banned', 'Gian lan chung tu'
  )$q$,
  'Manager can ban an active supplier'
);

-- 19. banned la trang thai cuoi (khong chuyen ra duoc).
select throws_ok(
  $q$select public.supplier_set_status(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', 'suspended', 'Thu mo lai'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Banned supplier is terminal'
);

-- 20. Doi trang thai bat buoc co ly do.
select throws_ok(
  $q$select public.supplier_set_status(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000702', 'suspended', ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'Status change requires a reason'
);

-- Doi sang u3 de phe duyet NCC s1 (u1 tao).
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a03","role":"authenticated"}', true);

-- 21-22. Phe duyet NCC s1 de dung cho luong doi STK.
select lives_ok(
  $q$select public.supplier_approve(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000701', true, null
  )$q$,
  'Approver can approve the first supplier'
);
select is(
  (select status from public.suppliers where id = 'd0130000-1300-4000-8000-000000000701'),
  'active',
  'First supplier is active'
);

-- Doi sang u1 de de xuat doi STK.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);

-- 23. De xuat doi STK tao ban ghi pending.
select is(
  (select public.supplier_bank_request(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000701',
    'Vietcombank', '1234567890', 'CONG TY GAO SACH'
  ) ->> 'ok'),
  'true',
  'Bank change request creates a pending account'
);

-- 24. Trung STK dang cho duyet cua cung NCC bi chan.
select throws_ok(
  $q$select public.supplier_bank_request(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000701',
    'Vietcombank', '1234567890', 'CONG TY GAO SACH'
  )$q$,
  '23505', null,
  'Duplicate pending account for the same supplier is rejected'
);

-- Doi sang u2 (co ca bank.request + bank.approve) de test SoD STK.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a02","role":"authenticated"}', true);

-- 25. u2 de xuat STK thu hai.
select lives_ok(
  $q$select public.supplier_bank_request(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000701',
    'BIDV', '0987654321', 'CONG TY GAO SACH'
  )$q$,
  'Second bank change request is created'
);

-- 26. Nguoi de xuat khong duoc tu duyet STK cua minh (SOD_BANK_ACCOUNT).
select throws_ok(
  $q$select public.supplier_bank_approve(
    'd0130000-1300-4000-8000-000000000201',
    (select id from public.supplier_bank_accounts where supplier_id = 'd0130000-1300-4000-8000-000000000701' and account_no = '0987654321'),
    true, null
  )$q$,
  'P0001', 'ERR_SOD_BANK_ACCOUNT',
  'Bank change requester cannot approve own request'
);

-- Doi sang u3 (bank.approve) de duyet.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a03","role":"authenticated"}', true);

-- 27. Ke toan truong duyet doi STK.
select lives_ok(
  $q$select public.supplier_bank_approve(
    'd0130000-1300-4000-8000-000000000201',
    (select id from public.supplier_bank_accounts where supplier_id = 'd0130000-1300-4000-8000-000000000701' and account_no = '0987654321'),
    true, null
  )$q$,
  'Chief accountant approves the bank change'
);

-- 28. STK moi da active.
select is(
  (select status from public.supplier_bank_accounts where supplier_id = 'd0130000-1300-4000-8000-000000000701' and account_no = '0987654321'),
  'active',
  'Approved bank account is active'
);

-- 29. bank_changed_at duoc dong dau.
select ok(
  (select bank_changed_at is not null from public.suppliers where id = 'd0130000-1300-4000-8000-000000000701'),
  'bank_changed_at is stamped on approval'
);

-- 30-31. Alert BANK_ACCOUNT_CHANGE duoc tao, muc do red.
select is(
  (select count(*) from public.alerts where code = 'BANK_ACCOUNT_CHANGE' and property_id = 'd0130000-1300-4000-8000-000000000201'),
  1::bigint,
  'BANK_ACCOUNT_CHANGE alert is created on approval'
);
select is(
  (select severity from public.alerts where code = 'BANK_ACCOUNT_CHANGE'),
  'red',
  'BANK_ACCOUNT_CHANGE alert is red severity'
);

-- Doi sang u4 (viewer, khong co alert.receive) de test RLS alerts.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a04', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a04","role":"authenticated"}', true);

-- 32. Nguoi khong co quyen alert.receive khong thay alert.
select is(
  (select count(*) from public.alerts),
  0::bigint,
  'User without alert.receive cannot see alerts'
);

-- Doi sang u1 de de xuat STK thu ba.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);

-- 33. De xuat STK thu ba.
select lives_ok(
  $q$select public.supplier_bank_request(
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000701',
    'Techcombank', '5555555555', 'CONG TY GAO SACH'
  )$q$,
  'Third bank change request is created'
);

-- Doi sang u3 de duyet STK thu ba.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a03","role":"authenticated"}', true);

-- 34. Duyet STK thu ba.
select lives_ok(
  $q$select public.supplier_bank_approve(
    'd0130000-1300-4000-8000-000000000201',
    (select id from public.supplier_bank_accounts where supplier_id = 'd0130000-1300-4000-8000-000000000701' and account_no = '5555555555'),
    true, null
  )$q$,
  'Chief accountant approves the third bank change'
);

-- 35. STK cu bi thu hoi khi STK moi duoc duyet.
select is(
  (select status from public.supplier_bank_accounts where supplier_id = 'd0130000-1300-4000-8000-000000000701' and account_no = '0987654321'),
  'revoked',
  'Previous active bank account is revoked'
);

-- Doi sang u1 de test xoa NCC.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a01","role":"authenticated"}', true);

-- 36. Xoa duoc NCC pending khong co STK.
select lives_ok(
  $q$delete from public.suppliers where id = 'd0130000-1300-4000-8000-000000000703'$q$,
  'Pending supplier without bank accounts can be deleted'
);

-- 37. Khong xoa duoc NCC da co STK.
select throws_ok(
  $q$delete from public.suppliers where id = 'd0130000-1300-4000-8000-000000000701'$q$,
  'P0001', 'ERR_SUPPLIER_HAS_BANK_ACCOUNTS',
  'Supplier with bank accounts cannot be deleted'
);

-- 38. Khong xoa duoc NCC khong con pending (du khong co STK).
select throws_ok(
  $q$delete from public.suppliers where id = 'd0130000-1300-4000-8000-000000000702'$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Non-pending supplier cannot be deleted'
);

-- 39-40. Hop dong khung A1 (active) + dong gia.
select lives_ok(
  $q$insert into public.price_agreements (id, org_id, supplier_id, valid_from, valid_to, status) values (
    'd0130000-1300-4000-8000-000000000801', 'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000701', '2026-01-01', '2026-12-31', 'active'
  )$q$,
  'Purchaser can insert an active price agreement via RLS'
);
select lives_ok(
  $q$insert into public.price_agreement_lines (org_id, agreement_id, item_id, uom, unit_price) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000801',
    'd0130000-1300-4000-8000-000000000501', 'kg', 12000
  )$q$,
  'Purchaser can insert a price agreement line via RLS'
);

-- 41. Hop dong A2 (active, trung thoi gian voi A1) them duoc khi chua co dong gia.
select lives_ok(
  $q$insert into public.price_agreements (id, org_id, supplier_id, valid_from, valid_to, status) values (
    'd0130000-1300-4000-8000-000000000802', 'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000701', '2026-06-01', '2027-05-31', 'active'
  )$q$,
  'Overlapping active agreement without lines is allowed'
);

-- 42. Them dong gia trung vat tu vao A2 bi chan (ERR_AGREEMENT_OVERLAP).
select throws_ok(
  $q$insert into public.price_agreement_lines (org_id, agreement_id, item_id, uom, unit_price) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000802',
    'd0130000-1300-4000-8000-000000000501', 'kg', 12500
  )$q$,
  'P0001', 'ERR_AGREEMENT_OVERLAP',
  'Overlapping active agreement for the same item is rejected'
);

-- 43. Dong gia vat tu khac trong A2 duoc chap nhan.
select lives_ok(
  $q$insert into public.price_agreement_lines (org_id, agreement_id, item_id, uom, unit_price) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000802',
    'd0130000-1300-4000-8000-000000000502', 'kg', 18000
  )$q$,
  'Overlapping agreement with a different item is allowed'
);

-- 44-45. Hop dong nhap A3 trung thoi gian + trung vat tu van them duoc (nhap chua bi chan).
select lives_ok(
  $q$insert into public.price_agreements (id, org_id, supplier_id, valid_from, valid_to, status) values (
    'd0130000-1300-4000-8000-000000000803', 'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000701', '2026-06-01', '2026-12-31', 'draft'
  )$q$,
  'Overlapping draft agreement can be inserted'
);
select lives_ok(
  $q$insert into public.price_agreement_lines (org_id, agreement_id, item_id, uom, unit_price) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000803',
    'd0130000-1300-4000-8000-000000000501', 'kg', 11000
  )$q$,
  'Draft agreement line overlapping an active one is allowed'
);

-- 46. Kich hoat hop dong nhap trung lap bi chan.
select throws_ok(
  $q$update public.price_agreements set status = 'active' where id = 'd0130000-1300-4000-8000-000000000803'$q$,
  'P0001', 'ERR_AGREEMENT_OVERLAP',
  'Activating an overlapping draft agreement is rejected'
);

-- 47-48. Hop dong A4 khong trung thoi gian them duoc binh thuong.
select lives_ok(
  $q$insert into public.price_agreements (id, org_id, supplier_id, valid_from, valid_to, status) values (
    'd0130000-1300-4000-8000-000000000804', 'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000701', '2027-01-01', '2027-12-31', 'active'
  )$q$,
  'Non-overlapping active agreement can be inserted'
);
select lives_ok(
  $q$insert into public.price_agreement_lines (org_id, agreement_id, item_id, uom, unit_price) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000804',
    'd0130000-1300-4000-8000-000000000501', 'kg', 13000
  )$q$,
  'Line of a non-overlapping agreement can be inserted'
);

-- Doi sang u4 (viewer) de test RLS ghi hop dong.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a04', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a04","role":"authenticated"}', true);

-- 49. Viewer khong them duoc hop dong khung.
select throws_ok(
  $q$insert into public.price_agreements (org_id, supplier_id, valid_from, valid_to, status) values (
    'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000701', '2028-01-01', '2028-12-31', 'draft'
  )$q$,
  '42501', null,
  'Viewer cannot insert a price agreement'
);

-- Doi sang u3 (price.ceiling.manage chain-wide) de test gia tran.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a03","role":"authenticated"}', true);

-- 50. Them gia tran cap chuoi.
select lives_ok(
  $q$insert into public.ceiling_prices (org_id, item_id, uom, price, valid_from, valid_to, set_by) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000501',
    'kg', 13000, '2026-01-01', '2026-12-31', 'd0130000-1300-4000-8000-000000000a03'
  )$q$,
  'Accountant can insert a chain-wide ceiling price'
);

-- 51. Them gia tran cap khach san.
select lives_ok(
  $q$insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000501', 'kg', 12500, '2026-01-01', '2026-12-31',
    'd0130000-1300-4000-8000-000000000a03'
  )$q$,
  'Accountant can insert a property ceiling price'
);

-- Doi sang u4 de test RLS ghi gia tran.
select set_config('request.jwt.claim.sub', 'd0130000-1300-4000-8000-000000000a04', true);
select set_config('request.jwt.claims', '{"sub":"d0130000-1300-4000-8000-000000000a04","role":"authenticated"}', true);

-- 52. Viewer khong them duoc gia tran.
select throws_ok(
  $q$insert into public.ceiling_prices (org_id, item_id, uom, price, valid_from, valid_to, set_by) values (
    'd0130000-1300-4000-8000-000000000001', 'd0130000-1300-4000-8000-000000000501',
    'kg', 99999, '2026-01-01', '2026-12-31', 'd0130000-1300-4000-8000-000000000a04'
  )$q$,
  '42501', null,
  'Viewer cannot insert a ceiling price'
);

-- current_ceiling_price() khong co grant cho authenticated nen test bang role postgres.
set local role postgres;

-- 53. Gia tran cap khach san thang gia tran cap chuoi.
select is(
  (select public.current_ceiling_price(
    'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000501', 'kg', '2026-06-01'
  )),
  12500.0000::numeric(18, 4),
  'Property ceiling wins over chain-wide ceiling'
);

-- 54. Khong co gia tran cap khach san -> dung gia tran cap chuoi.
select is(
  (select public.current_ceiling_price(
    'd0130000-1300-4000-8000-000000000001',
    null,
    'd0130000-1300-4000-8000-000000000501', 'kg', '2026-06-01'
  )),
  13000.0000::numeric(18, 4),
  'Chain-wide ceiling is used when no property ceiling exists'
);

-- 55. Khong co gia tran nao -> null.
select is(
  (select public.current_ceiling_price(
    'd0130000-1300-4000-8000-000000000001',
    'd0130000-1300-4000-8000-000000000201',
    'd0130000-1300-4000-8000-000000000502', 'kg', '2026-06-01'
  )),
  null::numeric(18, 4),
  'No ceiling returns null'
);

set local role authenticated;

select * from finish();
rollback;
