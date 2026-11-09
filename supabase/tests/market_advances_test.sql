-- T-022: market orders + advances — pgTAP
-- CHUA CHAY DUOC: VM khong co Docker (giong cac test T-013..T-021).
-- Chay tren DB that sau khi db push: psql "$SUPABASE_DB_URL" -f supabase/tests/market_advances_test.sql
-- Luu y: _sod_check duoc test o day ky vong ma ERR_SOD_ADVANCE_APPROVER
-- (dinh dang 'ERR_%' cua ban 20261109160000 da hoa giai tren main).
-- Fixture: org/property/vat tu dung tien to d022 de khong dung do
-- voi fixture T-020 (d020).
begin;
create extension if not exists pgtap;
select plan(56);

-- ---------------------------------------------------------------------------
-- Fixture: org, legal entity, property, uom, vat tu, gia tran, vai tro,
-- nguoi dung, quy tac duyet PO mac dinh (PO < 5tr: 1 buoc outlet_head).
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d0220000-0200-4000-8000-000000000001', 'T-022 Master Org');

insert into public.legal_entities (id, org_id, name, code) values
  ('d0220000-0200-4000-8000-000000000101', 'd0220000-0200-4000-8000-000000000001', 'T022 Entity', 'T022E');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0220000-0200-4000-8000-000000000201', 'd0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000101', 'P0221', 'T-022 Property', 'with_cc');

insert into public.uoms (code, name_vi) values ('kg', 'Ký'), ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0220000-0200-4000-8000-000000000301', 'd0220000-0200-4000-8000-000000000001', 'GAO', 'Gạo', 'key'),
  ('d0220000-0200-4000-8000-000000000302', 'd0220000-0200-4000-8000-000000000001', 'THIT', 'Thịt', 'key')
on conflict do nothing;

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, allowed_channels) values
  ('d0220000-0200-4000-8000-000000000501', 'd0220000-0200-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0220000-0200-4000-8000-000000000301', 'kg', true, array['contract', 'market']),
  ('d0220000-0200-4000-8000-000000000502', 'd0220000-0200-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0220000-0200-4000-8000-000000000302', 'kg', true, array['contract']),
  ('d0220000-0200-4000-8000-000000000503', 'd0220000-0200-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0220000-0200-4000-8000-000000000302', 'kg', false, array['contract', 'market']);

-- Nguoi dung auth (mau master_data_test.sql): profiles, user_property_roles
-- va ceiling_prices.set_by deu FK ve auth.users nen phai co dong auth truoc.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0220000-0200-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-pur@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-oh@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-cc@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-gm@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-own@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-acc@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-view@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0220000-0200-4000-8000-000000000a08', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't022-pur2@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by) values
  ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000201', 'd0220000-0200-4000-8000-000000000501', 'kg', 12000, '2026-01-01', '2030-12-31', 'd0220000-0200-4000-8000-000000000a01'),
  ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000201', 'd0220000-0200-4000-8000-000000000502', 'kg', 50000, '2026-01-01', '2030-12-31', 'd0220000-0200-4000-8000-000000000a01');

insert into public.cost_centers (id, org_id, code, name) values
  ('d0220000-0200-4000-8000-000000000401', 'd0220000-0200-4000-8000-000000000001', 'CC_KIT', 'Bếp');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0220000-0200-4000-8000-000000000402', 'd0220000-0200-4000-8000-000000000001', 'EC_TP', 'Thực phẩm');

insert into public.profiles (id, employee_code, full_name) values
  ('d0220000-0200-4000-8000-000000000a01', 'T022_PUR', 'Người mua hàng'),
  ('d0220000-0200-4000-8000-000000000a02', 'T022_OH', 'Trưởng bộ phận'),
  ('d0220000-0200-4000-8000-000000000a03', 'T022_CC', 'Kiểm soát chi phí'),
  ('d0220000-0200-4000-8000-000000000a04', 'T022_GM', 'Tổng quản lý'),
  ('d0220000-0200-4000-8000-000000000a05', 'T022_OWN', 'Chủ sở hữu'),
  ('d0220000-0200-4000-8000-000000000a06', 'T022_ACC', 'Kế toán'),
  ('d0220000-0200-4000-8000-000000000a07', 'T022_VIEW', 'Người xem'),
  ('d0220000-0200-4000-8000-000000000a08', 'T022_PUR2', 'Người mua hàng 2');

insert into public.roles (id, org_id, code, name_vi) values
  ('d0220000-0200-4000-8000-000000000601', 'd0220000-0200-4000-8000-000000000001', 'purchaser', 'Thu mua'),
  ('d0220000-0200-4000-8000-000000000602', 'd0220000-0200-4000-8000-000000000001', 'outlet_head', 'Trưởng bộ phận'),
  ('d0220000-0200-4000-8000-000000000603', 'd0220000-0200-4000-8000-000000000001', 'cost_controller', 'Kiểm soát chi phí'),
  ('d0220000-0200-4000-8000-000000000604', 'd0220000-0200-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0220000-0200-4000-8000-000000000605', 'd0220000-0200-4000-8000-000000000001', 'owner', 'Chủ sở hữu'),
  ('d0220000-0200-4000-8000-000000000606', 'd0220000-0200-4000-8000-000000000001', 'accountant', 'Kế toán'),
  ('d0220000-0200-4000-8000-000000000607', 'd0220000-0200-4000-8000-000000000001', 'r_view022', 'Chỉ xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0220000-0200-4000-8000-000000000601', 'market.order.create'),
  ('d0220000-0200-4000-8000-000000000601', 'advance.request'),
  ('d0220000-0200-4000-8000-000000000601', 'po.create'),
  ('d0220000-0200-4000-8000-000000000601', 'po.view'),
  ('d0220000-0200-4000-8000-000000000602', 'po.approve'),
  ('d0220000-0200-4000-8000-000000000602', 'pr.approve'),
  ('d0220000-0200-4000-8000-000000000603', 'po.approve'),
  ('d0220000-0200-4000-8000-000000000604', 'po.approve'),
  ('d0220000-0200-4000-8000-000000000604', 'po.approve.over_ceiling'),
  ('d0220000-0200-4000-8000-000000000604', 'advance.approve'),
  ('d0220000-0200-4000-8000-000000000605', 'po.approve'),
  ('d0220000-0200-4000-8000-000000000605', 'po.close'),
  ('d0220000-0200-4000-8000-000000000606', 'advance.disburse'),
  ('d0220000-0200-4000-8000-000000000606', 'advance.settle'),
  ('d0220000-0200-4000-8000-000000000607', 'po.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0220000-0200-4000-8000-000000000a01', 'd0220000-0200-4000-8000-000000000601', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a02', 'd0220000-0200-4000-8000-000000000602', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a03', 'd0220000-0200-4000-8000-000000000603', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a04', 'd0220000-0200-4000-8000-000000000604', 'd0220000-0200-4000-8000-000000000201'),
  -- a04 (gm) co them vai tro purchaser de test SoD: nguoi de nghi tam ung
  -- khong duoc tu duyet (advance_decide doi advance.approve truoc SoD).
  ('d0220000-0200-4000-8000-000000000a04', 'd0220000-0200-4000-8000-000000000601', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a05', 'd0220000-0200-4000-8000-000000000605', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a06', 'd0220000-0200-4000-8000-000000000606', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a07', 'd0220000-0200-4000-8000-000000000607', 'd0220000-0200-4000-8000-000000000201'),
  ('d0220000-0200-4000-8000-000000000a08', 'd0220000-0200-4000-8000-000000000601', 'd0220000-0200-4000-8000-000000000201');

insert into public.approval_rules (org_id, property_id, doc_type, min_amount, max_amount, item_group_id, condition, step, approver_role_id, approver_user_id, required_perm) values
  ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000201', 'po', 0, 4999999, null, null, 1, 'd0220000-0200-4000-8000-000000000602', null, null),
  ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000201', 'po', 5000000, 19999999, null, null, 2, 'd0220000-0200-4000-8000-000000000603', null, null),
  ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000201', 'po', 20000000, 99999999, null, null, 3, 'd0220000-0200-4000-8000-000000000604', null, null),
  ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000201', 'po', 100000000, null, null, null, 4, 'd0220000-0200-4000-8000-000000000605', null, null);

-- Helper gia lap nguoi dung dang dang nhap (mau T-020).
create or replace function _t022_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user::text)::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- 1. RLS + rang buoc schema
-- ---------------------------------------------------------------------------
select ok(
  (select relrowsecurity from pg_class where oid = 'public.advances'::regclass),
  'advances co RLS bat'
);

select ok(
  exists (select 1 from pg_constraint where conname = 'purchase_orders_advance_id_fkey'),
  'FK purchase_orders.advance_id -> advances ton tai'
);

select ok(
  (select is_nullable from information_schema.columns
    where table_schema = 'public' and table_name = 'purchase_orders'
      and column_name = 'supplier_id') = 'YES',
  'purchase_orders.supplier_id nullable (cho PO mua cho)'
);

select ok(
  exists (
    select 1 from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where t.relname = 'advances' and c.contype = 'u'
      and pg_get_constraintdef(c.oid) like '%(id, org_id)%'
  ),
  'advances co unique (id, org_id)'
);

select throws_ok(
  $q$insert into public.advances
    (org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status)
    values ('d0220000-0200-4000-8000-000000000001', 'd0220000-0200-4000-8000-000000000101', 'd0220000-0200-4000-8000-000000000201', 'd0220000-0200-4000-8000-000000000a01', 'ADV-T022-X', 100000, 'Test', 'requested')$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'ghi truc tiep advances bi write-guard chan (khong qua RPC)'
);

-- ---------------------------------------------------------------------------
-- 2. market_order_create: happy path
-- ---------------------------------------------------------------------------
set local role authenticated;
select _t022_as('d0220000-0200-4000-8000-000000000a01');

select ok(
  (public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[{"item_id": "d0220000-0200-4000-8000-000000000501", "qty": 10, "uom": "kg", "unit_price": 11000, "cost_center_id": "d0220000-0200-4000-8000-000000000401", "expense_category_id": "d0220000-0200-4000-8000-000000000402"},
      {"item_id": "d0220000-0200-4000-8000-000000000503", "qty": 5, "uom": "kg"}]'::jsonb,
    200000, 'Mua gạo + muối chợ sớm', '2026-11-10'
  ) ->> 'ok')::boolean,
  'market_order_create tra ok'
);

select is(
  (select channel from public.purchase_orders
    where advance_id is not null order by created_at desc limit 1),
  'market',
  'PO market co channel = market'
);

select is(
  (select supplier_id from public.purchase_orders
    where advance_id is not null order by created_at desc limit 1),
  null,
  'PO market co supplier_id NULL'
);

select is(
  (select count(*) from public.advances a
    join public.purchase_orders po on po.advance_id = a.id
    where po.channel = 'market'),
  1::bigint,
  '1 tam ung lien ket voi PO market'
);

select is(
  (select status from public.advances
    where doc_no like 'ADV-%' order by created_at desc limit 1),
  'requested',
  'tam ung moi tao o trang thai requested'
);

select is(
  (select employee_id from public.advances
    where doc_no like 'ADV-%' order by created_at desc limit 1),
  'd0220000-0200-4000-8000-000000000a01'::uuid,
  'employee_id tam ung = nguoi goi'
);

select is(
  (select amount from public.advances
    where doc_no like 'ADV-%' order by created_at desc limit 1),
  200000::numeric,
  'so tien tam ung dung nhu de nghi'
);

select ok(
  (select doc_no like 'ADV-%' from public.advances
    where doc_no like 'ADV-%' order by created_at desc limit 1),
  'so chung tu tam ung co prefix ADV-'
);

select is(
  (select count(*) from public.purchase_order_lines pol
    join public.purchase_orders po on po.id = pol.po_id
    where po.channel = 'market'),
  2::bigint,
  'PO market co 2 dong'
);

select is(
  (select price_source from public.purchase_order_lines pol
    join public.purchase_orders po on po.id = pol.po_id
    where po.channel = 'market' and pol.item_id = 'd0220000-0200-4000-8000-000000000501'),
  'manual',
  'dong co unit_price dua vao -> price_source manual'
);

select is(
  (select unit_price from public.purchase_order_lines pol
    join public.purchase_orders po on po.id = pol.po_id
    where po.channel = 'market' and pol.item_id = 'd0220000-0200-4000-8000-000000000503'),
  0::numeric,
  'dong khong co gia + khong co gia tran -> unit_price 0 (manual)'
);

select is(
  (select price_source from public.purchase_order_lines pol
    join public.purchase_orders po on po.id = pol.po_id
    where po.channel = 'market' and pol.item_id = 'd0220000-0200-4000-8000-000000000503'),
  'manual',
  'dong khong co gia + khong co gia tran -> price_source manual'
);

select is(
  (select total_amount from public.purchase_orders
    where channel = 'market' order by created_at desc limit 1),
  110000::numeric,
  'tong PO = 10 x 11000 + 5 x 0'
);

-- po_list hien PO market voi supplier_name NULL (LEFT JOIN, quyet dinh 1)
select is(
  (select (row ->> 'supplier_name') is null from (
    select jsonb_array_elements((public.po_list('d0220000-0200-4000-8000-000000000201', null, null, 100, 0) -> 'rows')) as row
  ) r where (row ->> 'channel') = 'market' limit 1),
  true,
  'po_list tra PO market voi supplier_name NULL'
);

-- ---------------------------------------------------------------------------
-- 3. market_order_create: validation
-- ---------------------------------------------------------------------------
select throws_ok(
  $q$select public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[{"item_id": "d0220000-0200-4000-8000-000000000502", "qty": 2, "uom": "kg", "unit_price": 45000}]'::jsonb,
    100000, 'Mua thịt', null)$q$,
  'P0001', 'ERR_CHANNEL_NOT_ALLOWED',
  'vat tu khong cho kenh market -> ERR_CHANNEL_NOT_ALLOWED'
);

select throws_ok(
  $q$select public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[]'::jsonb, 100000, 'Mua gạo', null)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'dong rong -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[{"item_id": "d0220000-0200-4000-8000-000000000501", "qty": 10, "uom": "kg"}]'::jsonb,
    0, 'Mua gạo', null)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'so tien tam ung 0 -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[{"item_id": "d0220000-0200-4000-8000-000000000501", "qty": 10, "uom": "kg"}]'::jsonb,
    100000, '   ', null)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'thieu muc dich -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[{"item_id": "d0220000-0200-4000-8000-000000000501", "qty": 10, "uom": "bao"}]'::jsonb,
    100000, 'Mua gạo', null)$q$,
  'P0001', 'ERR_UOM_UNKNOWN',
  'dvt khong ton tai -> ERR_UOM_UNKNOWN'
);

-- ---------------------------------------------------------------------------
-- 4. advance_request / decide / disburse: luong chuan
-- ---------------------------------------------------------------------------
select _t022_as('d0220000-0200-4000-8000-000000000a01');

select ok(
  (public.advance_request(
    'd0220000-0200-4000-8000-000000000201', 150000, 'Tạm ứng mua hải sản'
  ) ->> 'ok')::boolean,
  'advance_request doc lap tra ok'
);

select _t022_as('d0220000-0200-4000-8000-000000000a07');

select throws_ok(
  $q$select public.advance_request(
    'd0220000-0200-4000-8000-000000000201', 150000, 'Không có quyền')$q$,
  '42501', 'ERR_FORBIDDEN:advance.request',
  'advance_request can quyen advance.request'
);

-- a04 (gm, co them vai tro purchaser) tu de nghi roi tu duyet -> SoD.
select _t022_as('d0220000-0200-4000-8000-000000000a04');

select ok(
  (public.advance_request(
    'd0220000-0200-4000-8000-000000000201', 50000, 'Tạm ứng của GM'
  ) ->> 'ok')::boolean,
  'gm (co vai tro purchaser) de nghi tam ung duoc'
);

select throws_ok(
  $q$select public.advance_decide(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Tạm ứng của GM'),
    true, null)$q$,
  'P0001', 'ERR_SOD_ADVANCE_APPROVER',
  'nguoi de nghi tu duyet tam ung cua minh -> ERR_SOD_ADVANCE_APPROVER'
);

select throws_ok(
  $q$select public.advance_decide(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Tạm ứng mua hải sản'),
    false, null)$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'tu choi khong co ly do -> ERR_REASON_REQUIRED'
);

select ok(
  (public.advance_decide(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Tạm ứng mua hải sản'),
    true, null
  ) ->> 'ok')::boolean,
  'gm duyet tam ung doc lap'
);

select is(
  (select status from public.advances where purpose = 'Tạm ứng mua hải sản'),
  'approved',
  'tam ung doc lap da approved'
);

select throws_ok(
  $q$select public.advance_decide(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Tạm ứng mua hải sản'),
    true, null)$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'duyet lai tam ung da duyet -> ERR_INVALID_STATUS'
);

-- Chi tien: tam ung doc lap (khong PO) duoc chi ngay khi approved.
select _t022_as('d0220000-0200-4000-8000-000000000a06');

select ok(
  (public.advance_disburse(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Tạm ứng mua hải sản'),
    'Chi tiền mặt'
  ) ->> 'ok')::boolean,
  'ke toan chi tam ung doc lap da approved'
);

select is(
  (select status from public.advances where purpose = 'Tạm ứng mua hải sản'),
  'disbursed',
  'tam ung doc lap da disbursed'
);

select ok(
  (select due_settle_at > now() and due_settle_at < now() + interval '25 hours'
    from public.advances where purpose = 'Tạm ứng mua hải sản'),
  'due_settle_at = disbursed_at + 24h (mac dinh)'
);

select throws_ok(
  $q$select public.advance_disburse(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Tạm ứng mua hải sản'),
    null)$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'chi lai tam ung da disbursed -> ERR_INVALID_STATUS'
);

-- Chi tien: tam ung gan PO market van o draft -> chan.
select throws_ok(
  $q$select public.advance_disburse(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm'),
    null)$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'chi tam ung khi PO market van draft -> ERR_INVALID_STATUS'
);

-- Duyet PO market: submit (1 buoc outlet_head) -> outlet_head duyet -> approved.
select _t022_as('d0220000-0200-4000-8000-000000000a01');

select ok(
  (public.po_submit(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.purchase_orders where channel = 'market'),
    null
  ) ->> 'ok')::boolean,
  'po_submit PO market (tong < 5tr, khong vuot tran)'
);

select _t022_as('d0220000-0200-4000-8000-000000000a02');

select ok(
  (public.approval_decide(
    'd0220000-0200-4000-8000-000000000201',
    (select a.id from public.approvals a
      join public.purchase_orders po on po.id = a.doc_id
      where po.channel = 'market' and a.status = 'pending'),
    true, null
  ) ->> 'ok')::boolean,
  'outlet_head duyet PO market'
);

select is(
  (select status from public.purchase_orders where channel = 'market'),
  'approved',
  'PO market da approved sau 1 buoc'
);

select _t022_as('d0220000-0200-4000-8000-000000000a04');

select ok(
  (public.advance_decide(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm'),
    true, null
  ) ->> 'ok')::boolean,
  'gm duyet tam ung gan PO market'
);

select _t022_as('d0220000-0200-4000-8000-000000000a06');

select ok(
  (public.advance_disburse(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm'),
    'Chi tiền mặt đi chợ'
  ) ->> 'ok')::boolean,
  'ke toan chi tam ung khi PO market da approved'
);

-- ---------------------------------------------------------------------------
-- 5. AC T-022: tam ung qua han -> chan tam ung moi + cron danh dau
-- ---------------------------------------------------------------------------
-- Gia lap qua han: dua due_settle_at ve qua khu (can bypass guard).
select set_config('app.advance_guard_bypass', 'on', true);

update public.advances
set due_settle_at = now() - interval '2 hours'
where purpose = 'Mua gạo + muối chợ sớm';

select _t022_as('d0220000-0200-4000-8000-000000000a01');

select throws_ok(
  $q$select public.advance_request(
    'd0220000-0200-4000-8000-000000000201', 50000, 'Ứng thêm khi đang quá hạn')$q$,
  'P0001', 'ERR_ADVANCE_OVERDUE_BLOCK',
  'AC: co tam ung qua han -> advance_request bi chan'
);

select throws_ok(
  $q$select public.market_order_create(
    'd0220000-0200-4000-8000-000000000201',
    '[{"item_id": "d0220000-0200-4000-8000-000000000501", "qty": 2, "uom": "kg", "unit_price": 11000}]'::jsonb,
    50000, 'Mua gạo khi đang quá hạn', null)$q$,
  'P0001', 'ERR_ADVANCE_OVERDUE_BLOCK',
  'AC: co tam ung qua han -> market_order_create bi chan'
);

-- Nguoi khac (khong co tam ung qua han) van ung duoc.
select _t022_as('d0220000-0200-4000-8000-000000000a08');

select ok(
  (public.advance_request(
    'd0220000-0200-4000-8000-000000000201', 50000, 'Người khác ứng bình thường'
  ) ->> 'ok')::boolean,
  'chan qua han chi ap dung cho dung nguoi giu tien'
);

-- Cron: danh dau overdue + alert (dedupe khi chay lai).
select is(
  (public.advance_overdue_maintenance() ->> 'marked_overdue')::int,
  1,
  'maintenance danh dau 1 tam ung overdue'
);

select is(
  (public.advance_overdue_maintenance() ->> 'alerts_created')::int,
  0,
  'maintenance chay lai: khong tao alert trung (dedupe)'
);

select is(
  (select status from public.advances where purpose = 'Mua gạo + muối chợ sớm'),
  'overdue',
  'tam ung qua han co status overdue'
);

select ok(
  exists (
    select 1 from public.alerts
    where code = 'ADVANCE_OVERDUE' and doc_type = 'advance'
      and doc_id = (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm')
  ),
  'alert ADVANCE_OVERDUE duoc tao cho tam ung qua han'
);

-- ---------------------------------------------------------------------------
-- 6. advance_list / advance_get
-- ---------------------------------------------------------------------------
select _t022_as('d0220000-0200-4000-8000-000000000a01');

select ok(
  ((select public.advance_list('d0220000-0200-4000-8000-000000000201', null, null, 100, 0)) ->> 'total')::int >= 2,
  'advance_list tra >= 2 tam ung cua KS'
);

select ok(
  exists (
    select 1 from jsonb_array_elements(
      (select public.advance_list('d0220000-0200-4000-8000-000000000201', 'overdue', null, 100, 0) -> 'rows')
    ) r where (r ->> 'employee_name') = 'Người mua hàng'
  ),
  'advance_list loc overdue tra employee_name'
);

select _t022_as('d0220000-0200-4000-8000-000000000a07');

select throws_ok(
  $q$select public.advance_list('d0220000-0200-4000-8000-000000000201', null, null, 100, 0)$q$,
  '42501', 'ERR_FORBIDDEN',
  'advance_list can quyen advance.*'
);

select _t022_as('d0220000-0200-4000-8000-000000000a06');

select ok(
  (public.advance_get(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm')
  ) -> 'advance' ->> 'employee_name') = 'Người mua hàng',
  'advance_get tra employee_name'
);

select ok(
  (public.advance_get(
    'd0220000-0200-4000-8000-000000000201',
    (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm')
  ) -> 'po' ->> 'doc_no') is not null,
  'advance_get tra PO lien ket'
);

select throws_ok(
  $q$select public.advance_get(
    'd0220000-0200-4000-8000-000000000999',
    (select id from public.advances where purpose = 'Mua gạo + muối chợ sớm'))$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'advance_get sai KS -> ERR_INVALID_STATUS'
);

-- RLS: nguoi khong co quyen advance.* khong doc duoc dong advances.
select _t022_as('d0220000-0200-4000-8000-000000000a07');

select is(
  (select count(*) from public.advances),
  0::bigint,
  'RLS select: nguoi khong co quyen advance.* thay 0 dong'
);

select * from finish();
rollback;
