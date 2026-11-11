-- T-014 pgTAP: Import Excel 4 buoc cho vat tu & NCC.
-- Kiem tra: chuan hoa don vi (54 bien the -> 33 ma chuan), parse so tieng
-- Viet, tao batch tu dong NVL mo phong file that (DUP_CODE 11 -> thu nho
-- thanh 1 cap trung, NO_CODE, NO_FACTOR food, UNKNOWN_UOM/GROUP,
-- NEAR_DUP_NAME), resolve tung dong, commit 1 transaction, NCC pending +
-- tai khoan pending, phan quyen item.import, them alias don vi, sinh ma.
-- So lieu AC tren file that (da do truc tiep): DUP_CODE 11, DVT 54->33,
-- NO_FACTOR 281 (tren 661 dong co ten/ma).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(47);

-- 1. Setup Fixture
insert into public.organizations (id, name) values
  ('d0140000-1400-4000-8000-000000000001', 'T-014 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0140000-1400-4000-8000-000000000101', 'd0140000-1400-4000-8000-000000000001', 'T014', 'Entity T-014');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0140000-1400-4000-8000-000000000201', 'd0140000-1400-4000-8000-000000000001', 'd0140000-1400-4000-8000-000000000101', 'P014', 'Property T-014');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'), ('g', 'Gam'), ('l', 'Lít'), ('ml', 'Mililít'),
  ('cai', 'Cái'), ('lon', 'Lon')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0140000-1400-4000-8000-000000000401', 'd0140000-1400-4000-8000-000000000001', 'TP', 'Thực phẩm', 'food'),
  ('d0140000-1400-4000-8000-000000000402', 'd0140000-1400-4000-8000-000000000001', 'CCDC', 'Công cụ dụng cụ', 'ccdc');

insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0140000-1400-4000-8000-000000000501', 'd0140000-1400-4000-8000-000000000001', 'NVL0996', 'Gạo ST25', 'd0140000-1400-4000-8000-000000000401', 'kg');

-- Mau anh xa NVL: cot Loai -> nhom hang (khong co "Loại Lạ" de test UNKNOWN_GROUP).
insert into public.import_mappings (id, org_id, source, kind, name, column_map, group_map) values
  ('d0140000-1400-4000-8000-000000000801', 'd0140000-1400-4000-8000-000000000001', 'master_excel', 'items', 'NVL test',
  '{"code":{"col":1,"header":"Mã nvl2"},"name":{"col":2,"header":"Sản phẩm"},"group_raw":{"col":4,"header":"Loại"},"stock_uom_raw":{"col":5,"header":"ĐVT"},"factor_raw":{"col":6,"header":"Hệ Số Qui Đổi"},"recipe_uom_raw":{"col":7,"header":"ĐVT Qui Đổi"}}'::jsonb,
  '{"hải sản":"d0140000-1400-4000-8000-000000000401","Bánh":"d0140000-1400-4000-8000-000000000401","Gia Vị":"d0140000-1400-4000-8000-000000000401","CCDC":"d0140000-1400-4000-8000-000000000402","NVL Khô":"d0140000-1400-4000-8000-000000000401","Rau Củ":"d0140000-1400-4000-8000-000000000401","Thịt":"d0140000-1400-4000-8000-000000000401"}'::jsonb);

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('d0140000-1400-4000-8000-000000000701', 'd0140000-1400-4000-8000-000000000001', 'SUP_EXIST', 'NCC Cũ', 'company', 'active');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0140000-1400-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'importer014@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0140000-1400-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer014@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name, phone) values
  ('d0140000-1400-4000-8000-000000000a01', 'NV01401', 'Nhan vien nhap lieu', '0901414141'),
  ('d0140000-1400-4000-8000-000000000a02', 'NV01402', 'Nguoi xem', '0901424242')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name,
  phone = excluded.phone;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0140000-1400-4000-8000-000000000601', 'd0140000-1400-4000-8000-000000000001', 'r_imp014', 'Nhap lieu'),
  ('d0140000-1400-4000-8000-000000000602', 'd0140000-1400-4000-8000-000000000001', 'r_view014', 'Chi xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0140000-1400-4000-8000-000000000601', 'item.view'),
  ('d0140000-1400-4000-8000-000000000601', 'item.import'),
  ('d0140000-1400-4000-8000-000000000601', 'item.manage'),
  ('d0140000-1400-4000-8000-000000000602', 'item.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0140000-1400-4000-8000-000000000a01', 'd0140000-1400-4000-8000-000000000601', 'd0140000-1400-4000-8000-000000000201'),
  ('d0140000-1400-4000-8000-000000000a02', 'd0140000-1400-4000-8000-000000000602', 'd0140000-1400-4000-8000-000000000201');

-- Chuyen sang role authenticated; doi user bang set_config request.jwt.claim.sub.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0140000-1400-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0140000-1400-4000-8000-000000000a01","role":"authenticated"}', true);

-- 2. import_normalize_uom: bien the -> ma chuan (AC 54->33, thu nho)
-- §2-§3 goi truc tiep 2 helper noi bo (import_normalize_uom,
-- import_parse_number): ca 2 bi revoke khoi authenticated theo thiet ke
-- (chi goi ben trong RPC SECURITY DEFINER), nen chay duoi role postgres
-- nhu cach test Q209 doc audit_log (tien le: reset role, khong doi app).
reset role;

select is(public.import_normalize_uom('KG'), 'kg', 'KG -> kg');
select is(public.import_normalize_uom('Cái'), 'cai', 'Cái (NFD) -> cai');
select is(public.import_normalize_uom('gr'), 'g', 'gr -> g (alias)');
select is(public.import_normalize_uom('lít'), 'l', 'lít -> l (alias lit)');
select is(public.import_normalize_uom('Quả'), 'trai', 'Quả -> trai (alias dong nghia)');
select is(public.import_normalize_uom('xyz-unit'), null, 'don vi la -> NULL');

-- 3. import_parse_number: so tieng Viet
select is(public.import_parse_number('1000'::jsonb), 1000::numeric, 'so JSON 1000 giu nguyen');
select is(public.import_parse_number('"1,5"'::jsonb), 1.5::numeric, 'chuoi 1,5 -> 1.5');
select is(public.import_parse_number('"1.000"'::jsonb), 1000::numeric, 'chuoi 1.000 -> 1000');
select is(public.import_parse_number('"abc"'::jsonb), null, 'chuoi rac -> NULL');

-- 4. Tao batch vat tu tu 12 dong mo phong sheet NVL (gom 1 dong trong)
-- Tro lai authenticated u1 cho cac RPC (can item.import / item.manage).
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0140000-1400-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0140000-1400-4000-8000-000000000a01","role":"authenticated"}', true);

select public.import_create_batch(
  'd0140000-1400-4000-8000-000000000201', 'items', 'nvl-test.xlsx',
  'd0140000-1400-4000-8000-000000000801',
  '[
    {"code":"NVL0029","name":"Cua nguyên con","group_raw":"hải sản","stock_uom_raw":"kg","factor_raw":1000,"recipe_uom_raw":"gr"},
    {"code":"NVL0029","name":"Cua hộp 450gr","group_raw":"hải sản","stock_uom_raw":"kg","factor_raw":450,"recipe_uom_raw":"gr"},
    {"code":"","name":"Bánh bèo","group_raw":"Bánh","stock_uom_raw":"CÁI","factor_raw":null,"recipe_uom_raw":"cái"},
    {"code":"NVL0999","name":"Đường trắng","group_raw":"Gia Vị","stock_uom_raw":"kg","factor_raw":null,"recipe_uom_raw":"gr"},
    {"code":"NVL0998","name":"Muỗng inox","group_raw":"CCDC","stock_uom_raw":"CÁI","factor_raw":null,"recipe_uom_raw":null},
    {"code":"NVL0997","name":"Dầu ăn","group_raw":"Gia Vị","stock_uom_raw":"lít","factor_raw":null,"recipe_uom_raw":"ml","key_item":"x","vat":"8","expiry_days":365},
    {"code":"NVL0996","name":"Gạo ST25","group_raw":"NVL Khô","stock_uom_raw":"kg","factor_raw":null,"recipe_uom_raw":null},
    {"code":"NVL0995","name":"Gạo ST25","group_raw":"NVL Khô","stock_uom_raw":"kg","factor_raw":null,"recipe_uom_raw":null},
    {"code":"NVL0994","name":"Ớt hiểm","group_raw":"Rau Củ","stock_uom_raw":"xyz-unit","factor_raw":null,"recipe_uom_raw":null},
    {"code":"NVL0993","name":"Bánh mì","group_raw":"Loại Lạ","stock_uom_raw":"kg","factor_raw":null,"recipe_uom_raw":null},
    {"code":"","name":"","group_raw":"","stock_uom_raw":null,"factor_raw":null,"recipe_uom_raw":null},
    {"code":"NVL0992","name":"Thịt bò","group_raw":"Thịt","stock_uom_raw":"kg","factor_raw":1,"recipe_uom_raw":"gr"}
  ]'::jsonb
);

select is(
  (select status from public.import_batches where file_name = 'nvl-test.xlsx'),
  'draft', 'batch co loi nen o draft');
select is(
  (select (counts ->> 'total')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  11, 'total = 11 dong du lieu (tru 1 dong trong)');
select is(
  (select (counts ->> 'skipped_blank')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'skipped_blank = 1');
select is(
  (select (counts ->> 'errors')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  7, 'errors = 7 (DUP x2, NO_FACTOR x2, NEAR_DUP, UNKNOWN_UOM, UNKNOWN_GROUP)');
select is(
  (select (counts ->> 'warnings')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  3, 'warnings = 3 (NO_CODE, EXISTING, INVALID_FACTOR)');
select is(
  (select (counts ->> 'dup_code')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  2, 'dup_code = 2 dong (NVL0029 x2)');
select is(
  (select (counts ->> 'no_factor')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  2, 'no_factor = 2 (nhom food thieu he so)');
select is(
  (select (counts ->> 'unknown_uom')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'unknown_uom = 1');
select is(
  (select (counts ->> 'unknown_group')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'unknown_group = 1');
select is(
  (select (counts ->> 'near_dup')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'near_dup = 1 (ten trung ma khac)');
select is(
  (select (counts ->> 'no_code')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'no_code = 1');

-- 5. Commit khi con loi -> chan
select throws_ok(
  $q$select public.import_commit_batch((select id from public.import_batches where file_name = 'nvl-test.xlsx'))$q$,
  'ERR_INVALID_STATUS', 'commit khi con loi bi chan');

-- 6. Resolve tung dong loi (can mapping nhom cua batch: tao mapping truoc
--    thi moi resolve duoc UNKNOWN_GROUP; o day dung set_group truc tiep)
select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'nvl-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 2),
  '{"action":"split","new_code":"NVL0028"}'::jsonb);
select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'nvl-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 4),
  '{"action":"set_factor","factor":1000}'::jsonb);
select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'nvl-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 6),
  '{"action":"set_factor","factor":1000}'::jsonb);
select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'nvl-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 8),
  '{"action":"merge","target_id":"d0140000-1400-4000-8000-000000000501","target_code":"NVL0996"}'::jsonb);
select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'nvl-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 9),
  '{"action":"set_uom","stock_uom":"kg"}'::jsonb);
select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'nvl-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 10),
  '{"action":"set_group","group_id":"d0140000-1400-4000-8000-000000000401"}'::jsonb);

select is(
  (select status from public.import_batches where file_name = 'nvl-test.xlsx'),
  'validated', 'sau resolve het loi -> validated');
select is(
  (select (counts ->> 'errors')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  0, 'errors = 0 sau resolve');
select is(
  (select (counts ->> 'merged')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'merged = 1 (dong gop ten trung)');

-- 7. Commit: 1 transaction
select public.import_commit_batch((select id from public.import_batches where file_name = 'nvl-test.xlsx'));

select is(
  (select (counts ->> 'created')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  9, 'created = 9 vat tu moi');
select is(
  (select (counts ->> 'skipped')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  2, 'skipped = 2 (dong EXISTING + dong trong)');
select is(
  (select (counts ->> 'merged')::integer from public.import_batches where file_name = 'nvl-test.xlsx'),
  1, 'merged = 1 sau commit');
select is(
  (select (normalized_data ->> 'key_item')::boolean from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 6),
  true, 'key_item x -> true');
select is(
  (select (normalized_data ->> 'vat_rate')::numeric from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 6),
  8, 'vat 8 -> vat_rate 8');
select is(
  (select (normalized_data ->> 'shelf_life_days')::integer from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'nvl-test.xlsx') and row_no = 6),
  365, 'han dung 365 -> shelf_life_days 365');
select ok(
  exists (select 1 from public.items where org_id = 'd0140000-1400-4000-8000-000000000001' and code = 'NVL0029' and name = 'Cua nguyên con'),
  'vat tu NVL0029 duoc tao');
select ok(
  exists (select 1 from public.items where org_id = 'd0140000-1400-4000-8000-000000000001' and code = 'NVL0997' and is_key_item and vat_rate = 8 and shelf_life_days = 365),
  'NVL0997 ghi dung key_item/vat/han dung');
select ok(
  exists (select 1 from public.items where org_id = 'd0140000-1400-4000-8000-000000000001' and code = 'TP-0001' and name = 'Bánh bèo'),
  'dong NO_CODE sinh ma TP-0001 theo tien to nhom');
select throws_ok(
  $q$select public.import_commit_batch((select id from public.import_batches where file_name = 'nvl-test.xlsx'))$q$,
  'ERR_INVALID_STATUS', 'commit lan 2 bi chan');

-- 8. Batch NCC: DUP_CODE + NO_CODE, commit tao pending + tai khoan pending
select public.import_create_batch(
  'd0140000-1400-4000-8000-000000000201', 'suppliers', 'ncc-test.xlsx', null,
  '[
    {"code":"SUP001","name":"NCC Thực phẩm","tax_code":"0101234567","kind_raw":"công ty","phone":"0901000001","address":"Hội An","payment_terms_days":30,"bank_name":"VCB","account_no":"123456789","account_name":"CTY TP"},
    {"code":"SUP001","name":"NCC Khác","tax_code":"","kind_raw":"công ty","phone":"","address":"","payment_terms_days":null},
    {"code":"","name":"Hộ KD Lan","tax_code":"","kind_raw":"hộ kinh doanh","phone":"0901000002","address":"","payment_terms_days":15}
  ]'::jsonb
);

select is(
  (select status from public.import_batches where file_name = 'ncc-test.xlsx'),
  'draft', 'batch NCC co loi nen o draft');
select is(
  (select (counts ->> 'errors')::integer from public.import_batches where file_name = 'ncc-test.xlsx'),
  2, 'batch NCC errors = 2 (DUP_CODE ca 2 dong chung ma)');
select is(
  (select (counts ->> 'no_code')::integer from public.import_batches where file_name = 'ncc-test.xlsx'),
  1, 'batch NCC no_code = 1');

select public.import_resolve_row(
  (select id from public.import_batches where file_name = 'ncc-test.xlsx'),
  (select id from public.import_rows where batch_id = (select id from public.import_batches where file_name = 'ncc-test.xlsx') and row_no = 2),
  '{"action":"split","new_code":"SUP002"}'::jsonb);

select is(
  (select status from public.import_batches where file_name = 'ncc-test.xlsx'),
  'validated', 'batch NCC validated sau resolve');

select public.import_commit_batch((select id from public.import_batches where file_name = 'ncc-test.xlsx'));

select is(
  (select (counts ->> 'created')::integer from public.import_batches where file_name = 'ncc-test.xlsx'),
  3, 'batch NCC created = 3');
select ok(
  exists (select 1 from public.suppliers where org_id = 'd0140000-1400-4000-8000-000000000001' and code = 'SUP002' and status = 'pending'),
  'NCC moi tao o pending (cho duyet theo T-013)');
select ok(
  exists (select 1 from public.supplier_bank_accounts b
    join public.suppliers s on s.id = b.supplier_id
    where s.code = 'SUP001' and b.account_no = '123456789' and b.status = 'pending'),
  'tai khoan NCC kem theo o pending');

-- 9. Phan quyen: viewer khong co item.import
select set_config('request.jwt.claim.sub', 'd0140000-1400-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0140000-1400-4000-8000-000000000a02","role":"authenticated"}', true);

select throws_ok(
  $q$select public.import_create_batch('d0140000-1400-4000-8000-000000000201', 'items', 'nope.xlsx', null, '[{"code":"X1","name":"Test"}]'::jsonb)$q$,
  'ERR_FORBIDDEN:item.import', 'viewer khong tao duoc batch');
select ok(
  (select public.import_get_batch((select id from public.import_batches where file_name = 'nvl-test.xlsx')) is not null),
  'viewer co item.view van doc duoc batch');

-- 10. Them alias don vi (can item.manage) + sinh ma khong trung
select set_config('request.jwt.claim.sub', 'd0140000-1400-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0140000-1400-4000-8000-000000000a01","role":"authenticated"}', true);

select is(
  (select public.import_add_uom_alias('d0140000-1400-4000-8000-000000000201', 'can-nhua', 'can') ->> 'uom_code'),
  'can', 'them alias can-nhua -> can');
-- 2 assert cuoi goi truc tiep helper noi bo: import_normalize_uom (revoke
-- khoi authenticated) + next_item_code (SECURITY DEFINER, comment o
-- migration 180000: "Chi goi ben trong RPC commit") — chay duoi postgres.
reset role;

select is(public.import_normalize_uom('CAN-NHUA'), 'can', 'alias moi co hieu luc (khong phan biet hoa/thuong)');

select ok(
  public.next_item_code('d0140000-1400-4000-8000-000000000001', 'TP')
    <> public.next_item_code('d0140000-1400-4000-8000-000000000001', 'TP'),
  'sinh ma lien tiep khong trung');

select * from finish();
rollback;
