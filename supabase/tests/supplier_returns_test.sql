-- T-026 pgTAP: phieu tra NCC — doc (list/get), dong du tra, vong doi
-- phieu tra QC fail 'recorded' (xac nhan/huy), quyen.
-- Kiem tra: RLS 2 bang tra, list/get (gia chi khi co po.view_price),
-- eligible_lines (da nhan - da tra), supplier_return_post tra theo gia
-- dong goc + giam so da nhan (AC T-026), tra vuot / tra dong QC fail bi
-- chan, confirm bat buoc chu ky hoac anh, cancel bat buoc ly do, phan
-- quyen (receiver khong doc/duyet tra).
-- Fixture chay luong nhan that qua RPC (start -> record -> post) thay vi
-- chen truc tiep — giong receiving_test.sql.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(49);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('d0260000-0000-4000-8000-000000000001', 'T-026 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0260000-0000-4000-8000-000000000101', 'd0260000-0000-4000-8000-000000000001', 'T026', 'Entity T-026');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0260000-0000-4000-8000-000000000201', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000101', 'P0261', 'Property T-026', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0260000-0000-4000-8000-000000000401', 'd0260000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d0260000-0000-4000-8000-000000000402', 'd0260000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
  ('d0260000-0000-4000-8000-000000000403', 'd0260000-0000-4000-8000-000000000001', 'MUOI', 'Muối', 'other');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels) values
  ('d0260000-0000-4000-8000-000000000501', 'd0260000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0260000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market']),
  ('d0260000-0000-4000-8000-000000000502', 'd0260000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0260000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract']),
  ('d0260000-0000-4000-8000-000000000503', 'd0260000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0260000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market']);

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('d0260000-0000-4000-8000-000000000701', 'd0260000-0000-4000-8000-000000000001', 'NCC_GAO', 'Công ty Gạo Sạch', 'company', 'active');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0260000-0000-4000-8000-000000000301', 'd0260000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0260000-0000-4000-8000-000000000302', 'd0260000-0000-4000-8000-000000000201', 'WH_QUAR', 'Kho cách ly', 'quarantine', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0260000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-pur026@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0260000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-gm026@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0260000-0000-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u5-own026@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0260000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-rec026@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0260000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-stk026@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0260000-0000-4000-8000-000000000a10', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u10-view026@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0260000-0000-4000-8000-000000000a01', 'NV02601', 'Thu mua'),
  ('d0260000-0000-4000-8000-000000000a04', 'NV02604', 'Tổng quản lý'),
  ('d0260000-0000-4000-8000-000000000a05', 'NV02605', 'Chủ đầu tư'),
  ('d0260000-0000-4000-8000-000000000a06', 'NV02606', 'Nhân viên nhận hàng'),
  ('d0260000-0000-4000-8000-000000000a07', 'NV02607', 'Thủ kho'),
  ('d0260000-0000-4000-8000-000000000a10', 'NV02610', 'Chỉ xem')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

-- PIN 1234 cho nguoi nhan a06 (ghi so phieu nhan).
update public.profiles
set pin_hash = extensions.crypt('1234', extensions.gen_salt('bf'))
where id = 'd0260000-0000-4000-8000-000000000a06';

insert into public.roles (id, org_id, code, name_vi) values
  ('d0260000-0000-4000-8000-000000000601', 'd0260000-0000-4000-8000-000000000001', 'purchaser', 'Mua hàng'),
  ('d0260000-0000-4000-8000-000000000604', 'd0260000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0260000-0000-4000-8000-000000000605', 'd0260000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0260000-0000-4000-8000-000000000606', 'd0260000-0000-4000-8000-000000000001', 'receiver', 'Nhận hàng'),
  ('d0260000-0000-4000-8000-000000000607', 'd0260000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0260000-0000-4000-8000-000000000609', 'd0260000-0000-4000-8000-000000000001', 'r_view026', 'Chỉ xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0260000-0000-4000-8000-000000000601', 'pr.create'),
  ('d0260000-0000-4000-8000-000000000601', 'po.create'),
  ('d0260000-0000-4000-8000-000000000601', 'po.view'),
  ('d0260000-0000-4000-8000-000000000601', 'po.view_qty'),
  ('d0260000-0000-4000-8000-000000000601', 'po.view_price'),
  ('d0260000-0000-4000-8000-000000000601', 'po.close'),
  ('d0260000-0000-4000-8000-000000000604', 'po.approve'),
  ('d0260000-0000-4000-8000-000000000604', 'po.approve.over_ceiling'),
  ('d0260000-0000-4000-8000-000000000604', 'receiving.view'),
  ('d0260000-0000-4000-8000-000000000604', 'receiving.override_over_po'),
  ('d0260000-0000-4000-8000-000000000604', 'receiving.reverse'),
  ('d0260000-0000-4000-8000-000000000605', 'po.approve'),
  ('d0260000-0000-4000-8000-000000000605', 'po.view'),
  ('d0260000-0000-4000-8000-000000000605', 'po.view_price'),
  ('d0260000-0000-4000-8000-000000000605', 'receiving.view'),
  ('d0260000-0000-4000-8000-000000000605', 'receiving.perform'),
  ('d0260000-0000-4000-8000-000000000605', 'receiving.post'),
  ('d0260000-0000-4000-8000-000000000605', 'receiving.override_over_po'),
  ('d0260000-0000-4000-8000-000000000605', 'receiving.reverse'),
  ('d0260000-0000-4000-8000-000000000605', 'audit.view_all'),
  ('d0260000-0000-4000-8000-000000000606', 'receiving.perform'),
  ('d0260000-0000-4000-8000-000000000606', 'receiving.post'),
  ('d0260000-0000-4000-8000-000000000606', 'attachment.upload'),
  ('d0260000-0000-4000-8000-000000000606', 'attachment.view'),
  ('d0260000-0000-4000-8000-000000000607', 'receiving.perform'),
  ('d0260000-0000-4000-8000-000000000607', 'receiving.post'),
  ('d0260000-0000-4000-8000-000000000607', 'receiving.view'),
  ('d0260000-0000-4000-8000-000000000607', 'receiving.override_over_po'),
  ('d0260000-0000-4000-8000-000000000607', 'supplier_return.post'),
  ('d0260000-0000-4000-8000-000000000607', 'stock.view_qty'),
  ('d0260000-0000-4000-8000-000000000607', 'attachment.view'),
  ('d0260000-0000-4000-8000-000000000609', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0260000-0000-4000-8000-000000000a01', 'd0260000-0000-4000-8000-000000000601', 'd0260000-0000-4000-8000-000000000201'),
  ('d0260000-0000-4000-8000-000000000a04', 'd0260000-0000-4000-8000-000000000604', 'd0260000-0000-4000-8000-000000000201'),
  ('d0260000-0000-4000-8000-000000000a05', 'd0260000-0000-4000-8000-000000000605', null),
  ('d0260000-0000-4000-8000-000000000a06', 'd0260000-0000-4000-8000-000000000606', 'd0260000-0000-4000-8000-000000000201'),
  ('d0260000-0000-4000-8000-000000000a07', 'd0260000-0000-4000-8000-000000000607', 'd0260000-0000-4000-8000-000000000201'),
  ('d0260000-0000-4000-8000-000000000a10', 'd0260000-0000-4000-8000-000000000609', 'd0260000-0000-4000-8000-000000000201');

-- PO fixture (chen truc tiep, bypass pr_po).
select set_config('app.pr_po_guard_bypass', 'on', true);

insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
  ('d0260000-0000-4000-8000-000000000b01', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000101', 'd0260000-0000-4000-8000-000000000201', 'd0260000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0260000-0000-4000-8000-000000000a01', 'PO-026-001'),
  ('d0260000-0000-4000-8000-000000000b02', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000101', 'd0260000-0000-4000-8000-000000000201', 'd0260000-0000-4000-8000-000000000701', 'contract', 'stock', '2026-11-09', '2026-11-09', null, 'sent', 'd0260000-0000-4000-8000-000000000a01', 'PO-026-002');

insert into public.purchase_order_lines (id, po_id, org_id, item_id, description, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('d0260000-0000-4000-8000-000000000c01', 'd0260000-0000-4000-8000-000000000b01', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000501', 'Gạo ST25', 10, 'kg', 10, 10000, 'agreement', 0),
  ('d0260000-0000-4000-8000-000000000c02', 'd0260000-0000-4000-8000-000000000b01', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000502', 'Thịt ba chỉ', 5, 'kg', 5, 60000, 'agreement', 0),
  ('d0260000-0000-4000-8000-000000000c03', 'd0260000-0000-4000-8000-000000000b01', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000503', 'Muối hạt', 20, 'kg', 20, 5000, 'manual', 0),
  ('d0260000-0000-4000-8000-000000000c04', 'd0260000-0000-4000-8000-000000000b02', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000501', 'Gạo ST25', 8, 'kg', 8, 9000, 'agreement', 0),
  ('d0260000-0000-4000-8000-000000000c05', 'd0260000-0000-4000-8000-000000000b02', 'd0260000-0000-4000-8000-000000000001', 'd0260000-0000-4000-8000-000000000503', 'Muối hạt', 10, 'kg', 10, 4000, 'manual', 0);

select set_config('app.pr_po_guard_bypass', 'off', true);

-- Bang tam giu id chung tu tao trong test (mau T-020).
create temp table t026_ctx (key text primary key, id uuid);

-- Bang tam giu response JSON cua cac lan goi RPC (goi 1 lan, assert nhieu truong).
create temp table t026_resp (key text primary key, resp jsonb);

-- Bang tam tao duoi role postgres, nhung tu 'set local role authenticated'
-- tro di moi lenh deu chay duoi authenticated -> cap quyen truoc khi doi
-- role (bai hoc T-023 run 2, 42501).
grant all on t026_ctx, t026_resp to authenticated;

-- Helper doi user: dat lai JWT claim (mau T-020).
create or replace function public._t026_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
end;
$$;

-- 1. RLS bat cho 2 bang tra.
select is(
  (select relrowsecurity from pg_class where relname = 'supplier_returns'),
  true, 'supplier_returns has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'supplier_return_lines'),
  true, 'supplier_return_lines has RLS enabled'
);

-- Tu day tro di chay duoi role authenticated (RLS co hieu luc).
set local role authenticated;

-- 2. Lap phieu nhan gr1 (PO1) qua RPC that: 3 dong pass -> post.
select public._t026_as('d0260000-0000-4000-8000-000000000a06');
insert into t026_ctx values ('gr1', (select (public.receiving_start(
  'd0260000-0000-4000-8000-000000000b01',
  'd0260000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t026_ctx values ('att1', (select (public.attachment_register(
  'd0260000-0000-4000-8000-000000000201',
  'evidence',
  'd0260000-0000-4000-8000-000000000101/receiving/gr1-photo1.jpg',
  encode(sha256('gr1-photo1'::bytea), 'hex'),
  'receiving',
  (select id from t026_ctx where key = 'gr1')
)) ->> 'id')::uuid);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr1'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c01',
  p_item_id := 'd0260000-0000-4000-8000-000000000501',
  p_gross := 10, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "pass"}'::jsonb,
  p_photo_ids := array[(select id from t026_ctx where key = 'att1')]
);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr1'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c02',
  p_item_id := 'd0260000-0000-4000-8000-000000000502',
  p_gross := 5, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "pass"}'::jsonb,
  p_lot := 'LOT-T1', p_expiry := '2026-12-09',
  p_photo_ids := array[(select id from t026_ctx where key = 'att1')]
);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr1'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c03',
  p_item_id := 'd0260000-0000-4000-8000-000000000503',
  p_gross := 20, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "pass"}'::jsonb
);
do $$
declare
  v_gr uuid := (select id from t026_ctx where key = 'gr1');
begin
  insert into t026_resp values ('post_gr1',
    public.receiving_post(v_gr, '1234'));
end $$;
select ok(
  (select ((select resp from t026_resp where key = 'post_gr1') ->> 'ok')::boolean),
  'receiving_post succeeds for gr1'
);
select is(
  (select ((select resp from t026_resp where key = 'post_gr1') ->> 'lines_posted')::int),
  3, 'gr1 posts 3 lines'
);

-- 3. Phieu nhan gr2 (PO2): 2 dong QC fail -> tu sinh 2 phieu tra 'recorded'.
insert into t026_ctx values ('gr2', (select (public.receiving_start(
  'd0260000-0000-4000-8000-000000000b02',
  'd0260000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t026_ctx values ('att2', (select (public.attachment_register(
  'd0260000-0000-4000-8000-000000000201',
  'evidence',
  'd0260000-0000-4000-8000-000000000101/receiving/gr2-photo1.jpg',
  encode(sha256('gr2-photo1'::bytea), 'hex'),
  'receiving',
  (select id from t026_ctx where key = 'gr2')
)) ->> 'id')::uuid);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr2'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c04',
  p_item_id := 'd0260000-0000-4000-8000-000000000501',
  p_gross := 2, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "fail", "reason": "Gạo ẩm mốc"}'::jsonb,
  p_photo_ids := array[(select id from t026_ctx where key = 'att2')]
);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr2'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c05',
  p_item_id := 'd0260000-0000-4000-8000-000000000503',
  p_gross := 3, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "fail", "reason": "Muối vón cục"}'::jsonb,
  p_photo_ids := array[(select id from t026_ctx where key = 'att2')]
);

-- Phieu nhan gr3 (PO2): 1 dong pass + 1 dong QC fail -> them 1 phieu tra
-- 'recorded'; gr3 duoc post de test tra dong QC fail bi chan.
insert into t026_ctx values ('gr3', (select (public.receiving_start(
  'd0260000-0000-4000-8000-000000000b02',
  'd0260000-0000-4000-8000-000000000301'
)) ->> 'id')::uuid);
insert into t026_ctx values ('att3', (select (public.attachment_register(
  'd0260000-0000-4000-8000-000000000201',
  'evidence',
  'd0260000-0000-4000-8000-000000000101/receiving/gr3-photo1.jpg',
  encode(sha256('gr3-photo1'::bytea), 'hex'),
  'receiving',
  (select id from t026_ctx where key = 'gr3')
)) ->> 'id')::uuid);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr3'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c04',
  p_item_id := 'd0260000-0000-4000-8000-000000000501',
  p_gross := 5, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "pass"}'::jsonb,
  p_photo_ids := array[(select id from t026_ctx where key = 'att3')]
);
select public.receiving_record_line(
  p_gr_id := (select id from t026_ctx where key = 'gr3'),
  p_po_line_id := 'd0260000-0000-4000-8000-000000000c05',
  p_item_id := 'd0260000-0000-4000-8000-000000000503',
  p_gross := 2, p_tare := 0, p_uom := 'kg',
  p_qc := '{"status": "fail", "reason": "Muối vón cục"}'::jsonb,
  p_photo_ids := array[(select id from t026_ctx where key = 'att3')]
);
do $$
declare
  v_gr uuid := (select id from t026_ctx where key = 'gr3');
begin
  insert into t026_resp values ('post_gr3',
    public.receiving_post(v_gr, '1234'));
end $$;
select ok(
  (select ((select resp from t026_resp where key = 'post_gr3') ->> 'ok')::boolean),
  'receiving_post succeeds for gr3 with a QC fail line'
);

-- Luu id 3 phieu tra QC fail: sr1 = GAO gr2, sr2 = MUOI gr2, sr3 = MUOI gr3.
-- Nguoi nhan a06 KHONG doc duoc supplier_returns qua RLS (chi co
-- receiving.view / review_photos / supplier_return.post moi xem duoc) nen
-- doi sang thu kho a07 (co supplier_return.post) truoc khi doc.
select public._t026_as('d0260000-0000-4000-8000-000000000a07');
insert into t026_ctx values ('sr1', (select sr.id from public.supplier_returns sr
  join public.supplier_return_lines srl on srl.return_id = sr.id
  where sr.gr_id = (select id from t026_ctx where key = 'gr2')
    and srl.item_id = 'd0260000-0000-4000-8000-000000000501'));
insert into t026_ctx values ('sr2', (select sr.id from public.supplier_returns sr
  join public.supplier_return_lines srl on srl.return_id = sr.id
  where sr.gr_id = (select id from t026_ctx where key = 'gr2')
    and srl.item_id = 'd0260000-0000-4000-8000-000000000503'));
insert into t026_ctx values ('sr3', (select sr.id from public.supplier_returns sr
  join public.supplier_return_lines srl on srl.return_id = sr.id
  where sr.gr_id = (select id from t026_ctx where key = 'gr3')
    and srl.item_id = 'd0260000-0000-4000-8000-000000000503'));

-- 4. supplier_return_list: nguoi xem (chi receiving.view) thay 3 phieu
--    tra QC fail, chua co phieu nao posted/cancelled, khong thay gia.
select public._t026_as('d0260000-0000-4000-8000-000000000a10');
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201'
  ) ->> 'total')::int),
  3, 'list returns total 3 QC-fail returns'
);
select ok(
  (select public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201'
  ) -> 'returns' @> jsonb_build_array(jsonb_build_object(
    'gr_doc_no', (select doc_no from public.goods_receipts
      where id = (select id from t026_ctx where key = 'gr2')),
    'status', 'recorded'
  ))),
  'list contains the recorded return for gr2'
);
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201', 'recorded'
  ) ->> 'total')::int),
  3, 'list filter recorded total 3'
);
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201', 'posted'
  ) ->> 'total')::int),
  0, 'list filter posted total 0'
);
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201', 'cancelled'
  ) ->> 'total')::int),
  0, 'list filter cancelled total 0'
);
select ok(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201'
  ) -> 'returns' -> 0 ->> 'total_amount') is null),
  'viewer without po.view_price sees no total_amount in list'
);

-- 5. supplier_return_get: owner (co po.view_price) thay gia goc;
--    thu kho (khong co po.view_price) khong thay gia.
select public._t026_as('d0260000-0000-4000-8000-000000000a05');
select is(
  (select public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) ->> 'status'),
  'recorded', 'sr1 status is recorded'
);
select is(
  (select jsonb_array_length(public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) -> 'lines')),
  1, 'sr1 has 1 line'
);
select is(
  (select (public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) -> 'lines' -> 0 ->> 'qty_stock')::numeric),
  2::numeric, 'sr1 line holds the rejected 2kg GAO'
);
select is(
  (select (public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) -> 'lines' -> 0 ->> 'unit_cost')::numeric),
  9000::numeric, 'owner sees QC-fail line unit_cost 9000 (PO line price)'
);
select is(
  (select (public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) -> 'lines' -> 0 ->> 'line_amount')::numeric),
  18000::numeric, 'owner sees sr1 line_amount 18000'
);
select public._t026_as('d0260000-0000-4000-8000-000000000a07');
select ok(
  (select (public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) -> 'lines' -> 0 ->> 'unit_cost') is null),
  'storekeeper sees no unit_cost (no po.view_price)'
);
select ok(
  (select (public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  ) ->> 'total_amount') is null),
  'storekeeper sees no total_amount (no po.view_price)'
);

-- 6. eligible_lines: dong cua phieu da post con tra duoc.
select is(
  (select jsonb_array_length(public.supplier_return_eligible_lines(
    (select id from t026_ctx where key = 'gr1')
  ) -> 'lines')),
  3, 'gr1 has 3 returnable lines'
);
select is(
  (select ((select v from jsonb_array_elements(
    public.supplier_return_eligible_lines(
      (select id from t026_ctx where key = 'gr1')
    ) -> 'lines') v
    where v ->> 'item_name' = 'Gạo ST25'
  ) ->> 'returnable_qty_stock')::numeric),
  10::numeric, 'GAO returnable is 10 before any return'
);
select is(
  (select ((select v from jsonb_array_elements(
    public.supplier_return_eligible_lines(
      (select id from t026_ctx where key = 'gr1')
    ) -> 'lines') v
    where v ->> 'item_name' = 'Thịt ba chỉ'
  ) ->> 'returnable_qty_stock')::numeric),
  5::numeric, 'THIT returnable is 5'
);
select is(
  (select ((select v from jsonb_array_elements(
    public.supplier_return_eligible_lines(
      (select id from t026_ctx where key = 'gr1')
    ) -> 'lines') v
    where v ->> 'item_name' = 'Muối hạt'
  ) ->> 'returnable_qty_stock')::numeric),
  20::numeric, 'MUOI returnable is 20'
);
select throws_ok(
  $q$select public.supplier_return_eligible_lines(
    (select id from t026_ctx where key = 'gr2')
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'eligible_lines rejects a draft receipt'
);
select public._t026_as('d0260000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.supplier_return_eligible_lines(
    (select id from t026_ctx where key = 'gr1')
  )$q$,
  '42501', 'ERR_FORBIDDEN:supplier_return.post',
  'receiver cannot list eligible lines (no supplier_return.post)'
);

-- 7. Tra hang da nhan (thu kho): tra 2kg GAO theo gia goc 10000 (AC T-026).
select public._t026_as('d0260000-0000-4000-8000-000000000a07');
do $$
declare
  v_gr uuid := (select id from t026_ctx where key = 'gr1');
  v_line uuid := (select id from public.goods_receipt_lines
    where gr_id = v_gr
      and po_line_id = 'd0260000-0000-4000-8000-000000000c01');
begin
  insert into t026_resp values ('ret_gao',
    public.supplier_return_post(
      v_gr,
      jsonb_build_array(jsonb_build_object(
        'gr_line_id', v_line,
        'qty_stock', 2,
        'reason', 'Gạo ẩm mốc'
      ))
    ));
end $$;
select ok(
  (select ((select resp from t026_resp where key = 'ret_gao') ->> 'ok')::boolean),
  'supplier_return_post succeeds'
);
select ok(
  (select ((select resp from t026_resp where key = 'ret_gao') ->> 'doc_no') like 'SRT-%'),
  'return doc_no starts with SRT-'
);
select is(
  (select count(*) from public.stock_moves
   where doc_type = 'supplier_return' and qty = -2 and unit_cost = 10000),
  1::bigint, 'AC T-026: return_out move at original cost 10000'
);
-- Thu kho a07 KHONG doc duoc purchase_order_lines qua RLS (can po.view /
-- po.create / po.approve / po.close) nen doi sang thu mua a01 (co po.view)
-- chi cho assert nay, roi doi lai a07.
select public._t026_as('d0260000-0000-4000-8000-000000000a01');
select is(
  (select received_qty_stock from public.purchase_order_lines
   where id = 'd0260000-0000-4000-8000-000000000c01'),
  8::numeric, 'GAO received_qty_stock drops to 8 after return'
);
select public._t026_as('d0260000-0000-4000-8000-000000000a07');
select is(
  (select ((select v from jsonb_array_elements(
    public.supplier_return_eligible_lines(
      (select id from t026_ctx where key = 'gr1')
    ) -> 'lines') v
    where v ->> 'item_name' = 'Gạo ST25'
  ) ->> 'returnable_qty_stock')::numeric),
  8::numeric, 'GAO returnable drops to 8 after return'
);
select throws_ok(
  $q$select public.supplier_return_post(
    (select id from t026_ctx where key = 'gr1'),
    jsonb_build_array(jsonb_build_object(
      'gr_line_id', (select id from public.goods_receipt_lines
        where gr_id = (select id from t026_ctx where key = 'gr1')
          and po_line_id = 'd0260000-0000-4000-8000-000000000c01'),
      'qty_stock', 9,
      'reason', 'Trả quá số đã nhận'
    ))
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'return above returnable qty is rejected'
);
select throws_ok(
  $q$select public.supplier_return_post(
    (select id from t026_ctx where key = 'gr3'),
    jsonb_build_array(jsonb_build_object(
      'gr_line_id', (select id from public.goods_receipt_lines
        where gr_id = (select id from t026_ctx where key = 'gr3')
          and qc_status = 'fail'),
      'qty_stock', 2,
      'reason', 'Trả dòng QC fail'
    ))
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'QC fail line cannot be returned via supplier_return_post'
);

-- 8. Xac nhan phieu tra QC fail sr1 (thu kho): bat buoc chu ky hoac anh.
select throws_ok(
  $q$select public.supplier_return_confirm(
    (select id from t026_ctx where key = 'sr1')
  )$q$,
  'P0001', 'ERR_PHOTO_REQUIRED',
  'confirm without signature or photo is rejected'
);
select ok(
  (select (public.supplier_return_confirm(
    (select id from t026_ctx where key = 'sr1'),
    'd0260000-0000-4000-8000-000000000101/receiving/signature-sr1.jpg',
    null
  ) ->> 'ok')::boolean),
  'storekeeper confirms sr1 with driver signature'
);
select is(
  (select status from public.supplier_returns
   where id = (select id from t026_ctx where key = 'sr1')),
  'posted', 'sr1 status is posted after confirm'
);
select is(
  (select confirmed_by from public.supplier_returns
   where id = (select id from t026_ctx where key = 'sr1')),
  'd0260000-0000-4000-8000-000000000a07'::uuid,
  'sr1 confirmed_by is the storekeeper'
);
select throws_ok(
  $q$select public.supplier_return_confirm(
    (select id from t026_ctx where key = 'sr1'),
    'd0260000-0000-4000-8000-000000000101/receiving/signature-sr1b.jpg',
    null
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'second confirm is rejected'
);

-- 9. Huy phieu tra QC fail sr2 (thu kho): ly do bat buoc.
select throws_ok(
  $q$select public.supplier_return_cancel(
    (select id from t026_ctx where key = 'sr2'), ''
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'cancel without reason is rejected'
);
select ok(
  (select (public.supplier_return_cancel(
    (select id from t026_ctx where key = 'sr2'),
    'NCC đổi hàng tại chỗ'
  ) ->> 'ok')::boolean),
  'storekeeper cancels sr2 with reason'
);
select is(
  (select status from public.supplier_returns
   where id = (select id from t026_ctx where key = 'sr2')),
  'cancelled', 'sr2 status is cancelled after cancel'
);
select is(
  (select cancel_reason from public.supplier_returns
   where id = (select id from t026_ctx where key = 'sr2')),
  'NCC đổi hàng tại chỗ', 'sr2 cancel_reason is stored'
);
select throws_ok(
  $q$select public.supplier_return_confirm(
    (select id from t026_ctx where key = 'sr2'),
    'd0260000-0000-4000-8000-000000000101/receiving/signature-sr2.jpg',
    null
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'confirm of a cancelled return is rejected'
);

-- 10. Phan quyen: nguoi nhan khong doc/duyet phieu tra.
select public._t026_as('d0260000-0000-4000-8000-000000000a06');
select throws_ok(
  $q$select public.supplier_return_confirm(
    (select id from t026_ctx where key = 'sr3'),
    'd0260000-0000-4000-8000-000000000101/receiving/signature-sr3.jpg',
    null
  )$q$,
  '42501', 'ERR_FORBIDDEN:supplier_return.post',
  'receiver cannot confirm a return'
);
select throws_ok(
  $q$select public.supplier_return_cancel(
    (select id from t026_ctx where key = 'sr3'), 'Không được phép'
  )$q$,
  '42501', 'ERR_FORBIDDEN:supplier_return.post',
  'receiver cannot cancel a return'
);
-- list/get raise P0001 ERR_FORBIDDEN:receiving.view TRUC TIEP (khong qua
-- require_perm) nen 2 assert duoi giu 'P0001' — khac 3 assert 42501 tren.
select throws_ok(
  $q$select public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201'
  )$q$,
  'P0001', 'ERR_FORBIDDEN:receiving.view',
  'receiver cannot list returns (no receiving.view)'
);
select throws_ok(
  $q$select public.supplier_return_get(
    (select id from t026_ctx where key = 'sr1')
  )$q$,
  'P0001', 'ERR_FORBIDDEN:receiving.view',
  'receiver cannot get a return (no receiving.view)'
);

-- 11. Dem cuoi: 4 phieu tra — 2 posted (sr1 xac nhan + tra GAO gr1),
--     1 recorded (sr3), 1 cancelled (sr2).
select public._t026_as('d0260000-0000-4000-8000-000000000a10');
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201'
  ) ->> 'total')::int),
  4, 'final list total 4 returns'
);
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201', 'posted'
  ) ->> 'total')::int),
  2, 'final posted total 2'
);
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201', 'recorded'
  ) ->> 'total')::int),
  1, 'final recorded total 1 (sr3)'
);
select is(
  (select (public.supplier_return_list(
    'd0260000-0000-4000-8000-000000000201', 'cancelled'
  ) ->> 'total')::int),
  1, 'final cancelled total 1 (sr2)'
);

select * from finish();
rollback;
