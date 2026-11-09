-- T-030 pgTAP: phieu linh 2 buoc, dieu chuyen, xuat theo muc dich, huy hang.
-- Kiem tra: RLS 8 bang moi, write-guard, phieu linh (tao/duyet SoD/xuat
-- qua transit/xac nhan thieu so/huy), dieu chuyen (gui/nhan tung phan,
-- tong ton phap nhan khong doi), xuat muc dich (bat buoc cost center +
-- khoan muc, dao phieu chi gm), huy hang (anh bat buoc, SoD SOD_WASTE,
-- vuot nguong them buoc gm + alert WASTE_LARGE), phan quyen, gop ma
-- chuyen dong nhap (Q13).
-- Ton kho dau: GAO 200kg @10000, MUOI 50kg @5000, THIT 20kg @60000 (theo lo).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(97);

insert into public.organizations (id, name) values
  ('d0300000-0000-4000-8000-000000000001', 'T-030 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000001', 'T030', 'Entity T-030');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0300000-0000-4000-8000-000000000201', 'd0300000-0000-4000-8000-000000000001', 'd0300000-0000-4000-8000-000000000101', 'P0301', 'Property T-030', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0300000-0000-4000-8000-000000000401', 'd0300000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d0300000-0000-4000-8000-000000000402', 'd0300000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
  ('d0300000-0000-4000-8000-000000000403', 'd0300000-0000-4000-8000-000000000001', 'MUOI', 'Muối', 'other');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d0300000-0000-4000-8000-000000000501', 'd0300000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0300000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market'], false),
  ('d0300000-0000-4000-8000-000000000502', 'd0300000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0300000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract'], false),
  ('d0300000-0000-4000-8000-000000000503', 'd0300000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0300000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market'], false),
  ('d0300000-0000-4000-8000-000000000504', 'd0300000-0000-4000-8000-000000000001', 'TMP-030-1', 'Mã tạm 1', 'd0300000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market'], true),
  ('d0300000-0000-4000-8000-000000000505', 'd0300000-0000-4000-8000-000000000001', 'TMP-030-2', 'Mã tạm 2', 'd0300000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market'], true);

insert into public.item_purchase_units (org_id, item_id, uom, factor_to_stock, is_default) values
  ('d0300000-0000-4000-8000-000000000001', 'd0300000-0000-4000-8000-000000000501', 'cai', 10, false);

insert into public.outlet_types (id, org_id, code, name) values
  ('d0300000-0000-4000-8000-000000000801', 'd0300000-0000-4000-8000-000000000001', 'KIT', 'Bếp');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0300000-0000-4000-8000-000000000802', 'd0300000-0000-4000-8000-000000000201', 'd0300000-0000-4000-8000-000000000801', 'KITCHEN', 'Bếp chính');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0300000-0000-4000-8000-000000000302', 'd0300000-0000-4000-8000-000000000201', 'WH_TRANSIT', 'Kho trung chuyển', 'transit', null),
  ('d0300000-0000-4000-8000-000000000303', 'd0300000-0000-4000-8000-000000000201', 'WH_KIT', 'Kho bếp', 'outlet', 'd0300000-0000-4000-8000-000000000802'),
  ('d0300000-0000-4000-8000-000000000304', 'd0300000-0000-4000-8000-000000000201', 'WH_FLOOR', 'Kho tầng', 'floor', 'd0300000-0000-4000-8000-000000000802');

insert into public.cost_centers (id, org_id, code, name) values
  ('d0300000-0000-4000-8000-000000000901', 'd0300000-0000-4000-8000-000000000001', 'FB', 'F&B');

insert into public.expense_categories (id, org_id, code, name) values
  ('d0300000-0000-4000-8000-000000000902', 'd0300000-0000-4000-8000-000000000001', 'FOOD', 'Thực phẩm');

insert into public.lots (id, org_id, property_id, item_id, lot_no, expiry_date) values
  ('d0300000-0000-4000-8000-000000000903', 'd0300000-0000-4000-8000-000000000001', 'd0300000-0000-4000-8000-000000000201', 'd0300000-0000-4000-8000-000000000502', 'LOT-THIT-001', '2027-01-01');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0300000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-out030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0300000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-cc030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0300000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-gm030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0300000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u5-own030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0300000-0000-4000-8000-000000000a07', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u7-stk030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0300000-0000-4000-8000-000000000a10', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u10-view030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0300000-0000-4000-8000-000000000a11', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u11-out2030@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0300000-0000-4000-8000-000000000a02', 'NV03002', 'Trưởng bếp'),
  ('d0300000-0000-4000-8000-000000000a03', 'NV03003', 'Cost Controller'),
  ('d0300000-0000-4000-8000-000000000a04', 'NV03004', 'Tổng quản lý'),
  ('d0300000-0000-4000-8000-000000000a05', 'NV03005', 'Chủ đầu tư'),
  ('d0300000-0000-4000-8000-000000000a07', 'NV03007', 'Thủ kho'),
  ('d0300000-0000-4000-8000-000000000a10', 'NV03010', 'Chỉ xem'),
  ('d0300000-0000-4000-8000-000000000a11', 'NV03011', 'Phó bếp trưởng')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0300000-0000-4000-8000-000000000602', 'd0300000-0000-4000-8000-000000000001', 'outlet_head', 'Trưởng bộ phận'),
  ('d0300000-0000-4000-8000-000000000603', 'd0300000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('d0300000-0000-4000-8000-000000000604', 'd0300000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d0300000-0000-4000-8000-000000000605', 'd0300000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('d0300000-0000-4000-8000-000000000607', 'd0300000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0300000-0000-4000-8000-000000000609', 'd0300000-0000-4000-8000-000000000001', 'r_view030', 'Chỉ xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0300000-0000-4000-8000-000000000602', 'requisition.create'),
  ('d0300000-0000-4000-8000-000000000602', 'requisition.approve'),
  ('d0300000-0000-4000-8000-000000000602', 'requisition.receive'),
  ('d0300000-0000-4000-8000-000000000602', 'waste.propose'),
  ('d0300000-0000-4000-8000-000000000602', 'purpose_issue.post'),
  ('d0300000-0000-4000-8000-000000000603', 'waste.approve'),
  ('d0300000-0000-4000-8000-000000000603', 'stock.view_qty'),
  ('d0300000-0000-4000-8000-000000000603', 'stock.view_value'),
  ('d0300000-0000-4000-8000-000000000604', 'waste.approve.large'),
  ('d0300000-0000-4000-8000-000000000604', 'purpose_issue.post'),
  ('d0300000-0000-4000-8000-000000000604', 'purpose_issue.reverse'),
  ('d0300000-0000-4000-8000-000000000604', 'stock.view_value'),
  ('d0300000-0000-4000-8000-000000000605', 'purpose_issue.reverse'),
  ('d0300000-0000-4000-8000-000000000605', 'stock.view_value'),
  ('d0300000-0000-4000-8000-000000000607', 'requisition.issue'),
  ('d0300000-0000-4000-8000-000000000607', 'transfer.send'),
  ('d0300000-0000-4000-8000-000000000607', 'transfer.receive'),
  ('d0300000-0000-4000-8000-000000000607', 'purpose_issue.post'),
  ('d0300000-0000-4000-8000-000000000607', 'stock.view_qty'),
  ('d0300000-0000-4000-8000-000000000609', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0300000-0000-4000-8000-000000000a02', 'd0300000-0000-4000-8000-000000000602', 'd0300000-0000-4000-8000-000000000201'),
  ('d0300000-0000-4000-8000-000000000a03', 'd0300000-0000-4000-8000-000000000603', 'd0300000-0000-4000-8000-000000000201'),
  ('d0300000-0000-4000-8000-000000000a04', 'd0300000-0000-4000-8000-000000000604', 'd0300000-0000-4000-8000-000000000201'),
  ('d0300000-0000-4000-8000-000000000a05', 'd0300000-0000-4000-8000-000000000605', null),
  ('d0300000-0000-4000-8000-000000000a07', 'd0300000-0000-4000-8000-000000000607', 'd0300000-0000-4000-8000-000000000201'),
  ('d0300000-0000-4000-8000-000000000a10', 'd0300000-0000-4000-8000-000000000609', 'd0300000-0000-4000-8000-000000000201'),
  ('d0300000-0000-4000-8000-000000000a11', 'd0300000-0000-4000-8000-000000000602', 'd0300000-0000-4000-8000-000000000201');

insert into public.approval_rules (
  org_id, property_id, doc_type, min_amount, max_amount,
  item_group_id, condition, step,
  approver_role_id, approver_user_id, required_perm
) values
  ('d0300000-0000-4000-8000-000000000001', null, 'requisition', 0, null,
   null, '{}'::jsonb, 1,
   'd0300000-0000-4000-8000-000000000602', null, 'requisition.approve'),
  ('d0300000-0000-4000-8000-000000000001', null, 'waste', 0, null,
   null, '{}'::jsonb, 1,
   'd0300000-0000-4000-8000-000000000603', null, 'waste.approve')
on conflict do nothing;

insert into public.attachments (id, org_id, legal_entity_id, property_id, bucket, path, sha256, doc_type, doc_id, uploaded_by) values
  ('d0300000-0000-4000-8000-000000000904', 'd0300000-0000-4000-8000-000000000001', 'd0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000201', 'evidence', 'd0300000-0000-4000-8000-000000000101/waste/photo1.jpg', encode(sha256('waste-photo1'::bytea), 'hex'), 'waste', 'd0300000-0000-4000-8000-000000000905', 'd0300000-0000-4000-8000-000000000a02');

insert into public.stock_moves (legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id) values
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000201', 'd0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000501', null, 'receipt', 200, 10000, 2000000, '2026-11-09', 'd0300000-0000-4000-8000-000000000a07', 'opening', 'd0300000-0000-4000-8000-000000000f01'),
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000201', 'd0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000503', null, 'receipt', 50, 5000, 250000, '2026-11-09', 'd0300000-0000-4000-8000-000000000a07', 'opening', 'd0300000-0000-4000-8000-000000000f01'),
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000201', 'd0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000502', 'd0300000-0000-4000-8000-000000000903', 'receipt', 20, 60000, 1200000, '2026-11-09', 'd0300000-0000-4000-8000-000000000a07', 'opening', 'd0300000-0000-4000-8000-000000000f01');

insert into public.stock_balances (warehouse_id, item_id, lot_id, qty) values
  ('d0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000501', null, 200),
  ('d0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000503', null, 50),
  ('d0300000-0000-4000-8000-000000000301', 'd0300000-0000-4000-8000-000000000502', 'd0300000-0000-4000-8000-000000000903', 20);

insert into public.item_costs (legal_entity_id, item_id, avg_cost, qty_on_hand) values
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000501', 10000, 200),
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000503', 5000, 50),
  ('d0300000-0000-4000-8000-000000000101', 'd0300000-0000-4000-8000-000000000502', 60000, 20);

create temp table t030_ctx (key text primary key, id uuid);

create temp table t030_resp (key text primary key, resp jsonb);

grant all on t030_ctx, t030_resp to authenticated;

create or replace function public._t030_as(p_user uuid)
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

select is(
  (select relrowsecurity from pg_class where relname = 'requisitions'),
  true, 'requisitions has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'requisition_lines'),
  true, 'requisition_lines has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'transfers'),
  true, 'transfers has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'transfer_lines'),
  true, 'transfer_lines has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'purpose_issues'),
  true, 'purpose_issues has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'purpose_issue_lines'),
  true, 'purpose_issue_lines has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'waste_reports'),
  true, 'waste_reports has RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where relname = 'waste_report_lines'),
  true, 'waste_report_lines has RLS enabled'
);

select throws_ok(
  $q$insert into public.requisition_lines (requisition_id, org_id, property_id, item_id, uom, qty, qty_stock) values (
    'd0300000-0000-4000-8000-000000000e01',
    'd0300000-0000-4000-8000-000000000001',
    'd0300000-0000-4000-8000-000000000201',
    'd0300000-0000-4000-8000-000000000501',
    'kg', 1, 1
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Direct requisition_lines insert is blocked by write guard'
);

select throws_ok(
  $q$insert into public.transfers (org_id, legal_entity_id, property_id, from_warehouse_id, to_warehouse_id, doc_no, business_date, status) values (
    'd0300000-0000-4000-8000-000000000001',
    'd0300000-0000-4000-8000-000000000101',
    'd0300000-0000-4000-8000-000000000201',
    'd0300000-0000-4000-8000-000000000301',
    'd0300000-0000-4000-8000-000000000304',
    'TRF-TEST-001', '2026-11-09', 'draft'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Direct transfers insert is blocked by write guard'
);

set local role authenticated;

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.requisition_save_draft(
    '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000301", "lines": []}'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'requisition_save_draft rejects from_warehouse = to_warehouse'
);
select throws_ok(
  $q$select public.requisition_save_draft(
    '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000303", "to_warehouse_id": "d0300000-0000-4000-8000-000000000301", "lines": []}'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'requisition_save_draft rejects to_warehouse that is not the outlet warehouse'
);
select throws_ok(
  $q$select public.requisition_save_draft(
    '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000501", "qty": 1, "uom": "hop"}]}'::jsonb
  )$q$,
  'P0001', 'ERR_UOM_UNKNOWN',
  'requisition_save_draft rejects unknown UOM'
);

insert into t030_resp values ('r1', public.requisition_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "note": "Linh buoi sang", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000501", "qty": 10, "uom": "kg"}, {"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 5, "uom": "kg"}]}'::jsonb
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'r1'),
  'requisition_save_draft creates draft R1'
);
select ok(
  (select (resp ->> 'doc_no') like 'REQ-%' from t030_resp where key = 'r1'),
  'requisition doc_no starts with REQ-'
);
insert into t030_ctx values ('r1', (select (resp ->> 'id')::uuid from t030_resp where key = 'r1'));
insert into t030_ctx values ('r1_gao', (select id from public.requisition_lines where requisition_id = (select id from t030_ctx where key = 'r1') and item_id = 'd0300000-0000-4000-8000-000000000501'));
insert into t030_ctx values ('r1_muoi', (select id from public.requisition_lines where requisition_id = (select id from t030_ctx where key = 'r1') and item_id = 'd0300000-0000-4000-8000-000000000503'));

insert into t030_resp values ('r1sub', public.requisition_submit(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'r1')
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'r1sub'),
  'submitted', 'requisition_submit sets status submitted'
);
select is(
  (select (resp ->> 'steps')::integer from t030_resp where key = 'r1sub'),
  1, 'requisition_submit generates 1 approval step (outlet_head)'
);

select throws_ok(
  $q$select public.approval_decide(
    'd0300000-0000-4000-8000-000000000201',
    'requisition',
    (select id from t030_ctx where key = 'r1'),
    'approved',
    null
  )$q$,
  'P0001', 'ERR_SOD_REQUISITION_CREATOR_APPROVER',
  'requisition creator cannot approve own requisition (SoD)'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a11');
insert into t030_resp values ('r1dec', public.requisition_decide(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'r1'),
  'approved',
  null
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'r1dec'),
  'approved', 'second outlet_head approves R1'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a07');
insert into t030_resp values ('r1iss', public.requisition_issue(
  (select id from t030_ctx where key = 'r1'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 6)) from t030_ctx where key = 'r1_gao')
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'r1iss'),
  'requisition_issue issues 6kg GAO'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  194, 'issue: main GAO balance 200 -> 194'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000302'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  6, 'issue: transit GAO balance 6'
);
select throws_ok(
  $q$select public.requisition_issue(
    (select id from t030_ctx where key = 'r1'),
    (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 5)) from t030_ctx where key = 'r1_gao')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'requisition_issue rejects qty over remaining requested'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.requisition_confirm_receipt(
    (select id from t030_ctx where key = 'r1'),
    (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 5)) from t030_ctx where key = 'r1_gao')
  )$q$,
  'P0001', 'ERR_REASON_REQUIRED',
  'confirm_receipt without discrepancy note is rejected on short receipt'
);
insert into t030_resp values ('r1rcv1', public.requisition_confirm_receipt(
  (select id from t030_ctx where key = 'r1'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 5)) from t030_ctx where key = 'r1_gao'),
  'Thieu 1kg, NCC giao thieu'
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'r1rcv1'),
  'confirm_receipt receives 5kg GAO with discrepancy note'
);
select is(
  (select resp ->> 'status' from t030_resp where key = 'r1rcv1'),
  'partially_received', 'confirm_receipt short receipt sets partially_received'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000302'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  1, 'confirm: transit GAO balance 1 after short receipt'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000303'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  5, 'confirm: kitchen GAO balance 5'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('r1rcv2', public.requisition_confirm_receipt(
  (select id from t030_ctx where key = 'r1'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 1)) from t030_ctx where key = 'r1_gao'),
  null
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'r1rcv2'),
  'received', 'confirm_receipt of remaining 1kg sets received'
);

insert into t030_resp values ('r2', public.requisition_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_resp values ('r2can', public.requisition_cancel(
  'd0300000-0000-4000-8000-000000000201',
  (select (resp ->> 'id')::uuid from t030_resp where key = 'r2'),
  'Khong can nua'
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'r2can'),
  'cancelled', 'requisition_cancel cancels draft R2'
);

insert into t030_resp values ('r3', public.requisition_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('r3', (select (resp ->> 'id')::uuid from t030_resp where key = 'r3'));
select public.requisition_submit(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'r3')
);
select public._t030_as('d0300000-0000-4000-8000-000000000a11');
select public.requisition_decide(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'r3'),
  'approved',
  null
);
select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('r3can', public.requisition_cancel(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'r3'),
  'Doi ke hoach'
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'r3can'),
  'cancelled', 'requisition_cancel cancels approved R3'
);
select throws_ok(
  $q$select public.requisition_cancel(
    'd0300000-0000-4000-8000-000000000201',
    (select id from t030_ctx where key = 'r1'),
    'Muon huy'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'requisition_cancel rejects cancelling received R1'
);

select ok(
  (select jsonb_array_length(public.requisition_list(
    'd0300000-0000-4000-8000-000000000201', null, null, 20, 0
  ) -> 'rows') >= 3),
  'requisition_list returns at least 3 rows'
);
select is(
  (select jsonb_array_length(public.requisition_get(
    (select id from t030_ctx where key = 'r1')
  ) -> 'lines')),
  2, 'requisition_get returns 2 lines for R1'
);
select ok(
  (select not ((public.requisition_get(
    (select id from t030_ctx where key = 'r1')
  ) -> 'lines' -> 0) ? 'unit_cost')),
  'requisition_get leaks no unit_cost'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a07');
insert into t030_resp values ('t1', public.transfer_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000304", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 10, "uom": "kg"}]}'::jsonb
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 't1'),
  'transfer_save_draft creates draft T1 (MUOI 10kg main -> floor)'
);
select ok(
  (select (resp ->> 'doc_no') like 'TRF-%' from t030_resp where key = 't1'),
  'transfer doc_no starts with TRF-'
);
insert into t030_ctx values ('t1', (select (resp ->> 'id')::uuid from t030_resp where key = 't1'));
insert into t030_ctx values ('t1_muoi', (select id from public.transfer_lines where transfer_id = (select id from t030_ctx where key = 't1')));

insert into t030_resp values ('t1send', public.transfer_send(
  (select id from t030_ctx where key = 't1'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 10)) from t030_ctx where key = 't1_muoi')
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 't1send'),
  'transfer_send sends 10kg MUOI'
);
select is(
  (select resp ->> 'status' from t030_resp where key = 't1send'),
  'in_transit', 'transfer_send sets status in_transit'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000503'
     and lot_id is null),
  40, 'transfer send: main MUOI balance 50 -> 40'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000302'
     and item_id = 'd0300000-0000-4000-8000-000000000503'
     and lot_id is null),
  10, 'transfer send: transit MUOI balance 10'
);
select is(
  (select coalesce(sum(qty), 0) from public.stock_balances
   where item_id = 'd0300000-0000-4000-8000-000000000503'),
  50, 'transfer send: entity total MUOI unchanged at 50'
);
insert into t030_resp values ('t1rcv', public.transfer_receive(
  (select id from t030_ctx where key = 't1'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 10)) from t030_ctx where key = 't1_muoi')
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 't1rcv'),
  'transfer_receive receives 10kg MUOI at floor'
);
select is(
  (select resp ->> 'status' from t030_resp where key = 't1rcv'),
  'received', 'transfer_receive sets status received'
);
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000304'
     and item_id = 'd0300000-0000-4000-8000-000000000503'
     and lot_id is null),
  10, 'transfer receive: floor MUOI balance 10'
);

insert into t030_resp values ('t2', public.transfer_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000304", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000501", "qty": 10, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('t2', (select (resp ->> 'id')::uuid from t030_resp where key = 't2'));
insert into t030_ctx values ('t2_gao', (select id from public.transfer_lines where transfer_id = (select id from t030_ctx where key = 't2')));
insert into t030_resp values ('t2send', public.transfer_send(
  (select id from t030_ctx where key = 't2'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 6)) from t030_ctx where key = 't2_gao')
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 't2send'),
  'transfer_send sends partial 6kg GAO of 10kg requested'
);
select throws_ok(
  $q$select public.transfer_receive(
    (select id from t030_ctx where key = 't2'),
    (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 7)) from t030_ctx where key = 't2_gao')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'transfer_receive rejects qty over in-transit amount'
);
insert into t030_resp values ('t2rcv1', public.transfer_receive(
  (select id from t030_ctx where key = 't2'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 4)) from t030_ctx where key = 't2_gao')
));
select is(
  (select resp ->> 'status' from t030_resp where key = 't2rcv1'),
  'partially_received', 'transfer_receive partial sets partially_received'
);
insert into t030_resp values ('t2rcv2', public.transfer_receive(
  (select id from t030_ctx where key = 't2'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 2)) from t030_ctx where key = 't2_gao')
));
select is(
  (select resp ->> 'status' from t030_resp where key = 't2rcv2'),
  'received', 'transfer_receive of remaining 2kg sets received'
);

insert into t030_resp values ('t3', public.transfer_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000304", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000502", "qty": 5, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('t3', (select (resp ->> 'id')::uuid from t030_resp where key = 't3'));
insert into t030_ctx values ('t3_thit', (select id from public.transfer_lines where transfer_id = (select id from t030_ctx where key = 't3')));
select throws_ok(
  $q$select public.transfer_send(
    (select id from t030_ctx where key = 't3'),
    (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 5)) from t030_ctx where key = 't3_thit')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'transfer_send rejects tracked item without lot'
);
insert into t030_resp values ('t3send', public.transfer_send(
  (select id from t030_ctx where key = 't3'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 5, 'lot_id', 'd0300000-0000-4000-8000-000000000903')) from t030_ctx where key = 't3_thit')
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 't3send'),
  'transfer_send sends 5kg THIT with lot'
);
insert into t030_resp values ('t3rcv', public.transfer_receive(
  (select id from t030_ctx where key = 't3'),
  (select jsonb_build_array(jsonb_build_object('line_id', id, 'qty_stock', 5)) from t030_ctx where key = 't3_thit')
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 't3rcv'),
  'transfer_receive receives 5kg THIT at floor'
);

insert into t030_resp values ('t4', public.transfer_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000304", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_resp values ('t4can', public.transfer_cancel(
  'd0300000-0000-4000-8000-000000000201',
  (select (resp ->> 'id')::uuid from t030_resp where key = 't4'),
  'Khong can nua'
));
select is(
  (select resp ->> 'status' from t030_resp where key = 't4can'),
  'cancelled', 'transfer_cancel cancels draft T4'
);
select throws_ok(
  $q$select public.transfer_cancel(
    'd0300000-0000-4000-8000-000000000201',
    (select id from t030_ctx where key = 't2'),
    'Muon huy'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'transfer_cancel rejects cancelling received T2'
);
select ok(
  (select jsonb_array_length(public.transfer_list(
    'd0300000-0000-4000-8000-000000000201', null, null, 20, 0
  ) -> 'rows') >= 3),
  'transfer_list returns at least 3 rows'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('pi1', public.purpose_issue_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "purpose_code": "staff_meal", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000501", "qty": 2, "uom": "kg"}]}'::jsonb
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'pi1'),
  'purpose_issue_save_draft creates draft PI1 without cost center (allowed at draft)'
);
insert into t030_ctx values ('pi1', (select (resp ->> 'id')::uuid from t030_resp where key = 'pi1'));
select throws_ok(
  $q$select public.purpose_issue_post(
    (select id from t030_ctx where key = 'pi1')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'purpose_issue_post rejects draft without cost center'
);
select throws_ok(
  $q$select public.purpose_issue_save_draft(
    '{"id": "d0300000-0000-4000-8000-000000000e01", "property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "purpose_code": "staff_meal", "lines": []}'::jsonb
  )$q$,
  'P0001', 'ERR_NOT_FOUND',
  'purpose_issue_save_draft rejects unknown id'
);
insert into t030_resp values ('pi1c', public.purpose_issue_save_draft(
  (select jsonb_build_object(
    'id', (select id from t030_ctx where key = 'pi1'),
    'property_id', 'd0300000-0000-4000-8000-000000000201',
    'warehouse_id', 'd0300000-0000-4000-8000-000000000301',
    'purpose_code', 'staff_meal',
    'cost_center_id', 'd0300000-0000-4000-8000-000000000901',
    'expense_category_id', 'd0300000-0000-4000-8000-000000000902',
    'lines', jsonb_build_array(jsonb_build_object('item_id', 'd0300000-0000-4000-8000-000000000501', 'qty', 2, 'uom', 'kg'))
  ))
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'pi1c'),
  'purpose_issue_save_draft updates PI1 with cost center and category'
);
insert into t030_resp values ('pi1post', public.purpose_issue_post(
  (select id from t030_ctx where key = 'pi1')
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'pi1post'),
  'posted', 'purpose_issue_post posts PI1'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  186, 'purpose issue: main GAO balance 188 -> 186'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.purpose_issue_reverse(
    (select id from t030_ctx where key = 'pi1'),
    'd0300000-0000-4000-8000-000000000201',
    'Xuat nham'
  )$q$,
  '42501', 'ERR_FORBIDDEN:purpose_issue.reverse',
  'purpose_issue_reverse rejects outlet_head without reverse permission'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a04');
insert into t030_resp values ('pi1rev', public.purpose_issue_reverse(
  (select id from t030_ctx where key = 'pi1'),
  'd0300000-0000-4000-8000-000000000201',
  'Xuat nham, can dao phieu'
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'pi1rev'),
  'purpose_issue_reverse reverses PI1 as gm'
);
select is(
  (select resp ->> 'status' from t030_resp where key = 'pi1rev'),
  'reversed', 'purpose_issue_reverse sets status reversed'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  188, 'purpose issue reverse: main GAO balance back to 188'
);
select is(
  (select count(*) from public.stock_moves
   where source_doc_type = 'purpose_issue'
     and source_doc_id = (select id from t030_ctx where key = 'pi1')
     and move_type = 'reversal'),
  1, 'purpose issue reverse writes one reversal move'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a04');
select throws_ok(
  $q$select public.purpose_issue_reverse(
    (select id from t030_ctx where key = 'pi1'),
    'd0300000-0000-4000-8000-000000000201',
    'Dao lan 2'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'purpose_issue_reverse rejects reversing twice'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('pi2', public.purpose_issue_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "purpose_code": "vip_comp", "cost_center_id": "d0300000-0000-4000-8000-000000000901", "expense_category_id": "d0300000-0000-4000-8000-000000000902", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000502", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('pi2', (select (resp ->> 'id')::uuid from t030_resp where key = 'pi2'));
select throws_ok(
  $q$select public.purpose_issue_post(
    (select id from t030_ctx where key = 'pi2')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'purpose_issue_post rejects tracked item without lot'
);
select ok(
  (select jsonb_array_length(public.purpose_issue_list(
    'd0300000-0000-4000-8000-000000000201', null, null, 20, 0
  ) -> 'rows') >= 1),
  'purpose_issue_list returns at least 1 row'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a03');
select is(
  (select (public.purpose_issue_get(
    (select id from t030_ctx where key = 'pi1')
  ) -> 'lines' -> 0 ->> 'unit_cost')::numeric),
  10000, 'purpose_issue_get shows unit_cost 10000 to cost_controller'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a02');
select ok(
  (select (public.purpose_issue_get(
    (select id from t030_ctx where key = 'pi1')
  ) -> 'lines' -> 0 ->> 'unit_cost') is null),
  'purpose_issue_get hides unit_cost from outlet_head'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('w1', public.waste_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "reason_code": "expired", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 3, "uom": "kg"}]}'::jsonb
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'w1'),
  'waste_save_draft creates draft W1 without photo (allowed at draft)'
);
insert into t030_ctx values ('w1', (select (resp ->> 'id')::uuid from t030_resp where key = 'w1'));
select throws_ok(
  $q$select public.waste_submit(
    'd0300000-0000-4000-8000-000000000201',
    (select id from t030_ctx where key = 'w1')
  )$q$,
  'P0001', 'ERR_PHOTO_REQUIRED',
  'waste_submit rejects draft without photo'
);
insert into t030_resp values ('w1b', public.waste_save_draft(
  (select jsonb_build_object(
    'id', (select id from t030_ctx where key = 'w1'),
    'property_id', 'd0300000-0000-4000-8000-000000000201',
    'warehouse_id', 'd0300000-0000-4000-8000-000000000301',
    'reason_code', 'expired',
    'photo_ids', jsonb_build_array('d0300000-0000-4000-8000-000000000904'),
    'lines', jsonb_build_array(jsonb_build_object('item_id', 'd0300000-0000-4000-8000-000000000503', 'qty', 3, 'uom', 'kg'))
  ))
));
select ok(
  (select (resp ->> 'ok')::boolean from t030_resp where key = 'w1b'),
  'waste_save_draft updates W1 with photo'
);
insert into t030_resp values ('w1sub', public.waste_submit(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w1')
));
select is(
  (select (resp ->> 'total_value')::numeric from t030_resp where key = 'w1sub'),
  15000, 'waste_submit values W1 at 3kg x 5000 = 15000'
);
select is(
  (select (resp ->> 'steps')::integer from t030_resp where key = 'w1sub'),
  1, 'waste_submit under threshold generates 1 approval step'
);
select throws_ok(
  $q$select public.waste_decide(
    'd0300000-0000-4000-8000-000000000201',
    (select id from t030_ctx where key = 'w1'),
    'approved',
    null
  )$q$,
  'P0001', 'ERR_SOD_WASTE',
  'waste proposer cannot approve own waste report (SoD)'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a03');
insert into t030_resp values ('w1dec', public.waste_decide(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w1'),
  'approved',
  null
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'w1dec'),
  'posted', 'cost_controller approval posts W1 immediately'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000503'
     and lot_id is null),
  37, 'waste: main MUOI balance 40 -> 37'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a03');
select is(
  (select (public.waste_get(
    (select id from t030_ctx where key = 'w1')
  ) -> 'lines' -> 0 ->> 'unit_cost')::numeric),
  5000, 'waste_get shows line unit_cost 5000 to cost_controller'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('w2', public.waste_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "reason_code": "spoiled_storage", "photo_ids": ["d0300000-0000-4000-8000-000000000904"], "lines": [{"item_id": "d0300000-0000-4000-8000-000000000501", "qty": 150, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('w2', (select (resp ->> 'id')::uuid from t030_resp where key = 'w2'));
insert into t030_resp values ('w2sub', public.waste_submit(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w2')
));
select is(
  (select (resp ->> 'steps')::integer from t030_resp where key = 'w2sub'),
  2, 'waste_submit over threshold (1.5M > 1M) generates 2 approval steps'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a03');
select is(
  (select count(*) from public.alerts
   where property_id = 'd0300000-0000-4000-8000-000000000201'
     and code = 'WASTE_LARGE'),
  1, 'waste_submit over threshold creates WASTE_LARGE alert'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a03');
insert into t030_resp values ('w2dec1', public.waste_decide(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w2'),
  'approved',
  null
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'w2dec1'),
  'submitted', 'first approval of large waste keeps status submitted'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a04');
insert into t030_resp values ('w2dec2', public.waste_decide(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w2'),
  'approved',
  null
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'w2dec2'),
  'posted', 'gm approval of second step posts W2'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a07');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  38, 'waste: main GAO balance 188 -> 38 after W2'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('w3', public.waste_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "reason_code": "broken", "photo_ids": ["d0300000-0000-4000-8000-000000000904"], "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_resp values ('w3can', public.waste_cancel(
  'd0300000-0000-4000-8000-000000000201',
  (select (resp ->> 'id')::uuid from t030_resp where key = 'w3'),
  'Khong huy nua'
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'w3can'),
  'cancelled', 'waste_cancel cancels draft W3'
);
insert into t030_resp values ('w4', public.waste_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "reason_code": "guest_return", "photo_ids": ["d0300000-0000-4000-8000-000000000904"], "lines": [{"item_id": "d0300000-0000-4000-8000-000000000503", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('w4', (select (resp ->> 'id')::uuid from t030_resp where key = 'w4'));
select public.waste_submit(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w4')
);
insert into t030_resp values ('w4can', public.waste_cancel(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'w4'),
  'Doi ke hoach'
));
select is(
  (select resp ->> 'status' from t030_resp where key = 'w4can'),
  'cancelled', 'waste_cancel cancels submitted W4'
);
select ok(
  (select jsonb_array_length(public.waste_list(
    'd0300000-0000-4000-8000-000000000201', null, null, 20, 0
  ) -> 'rows') >= 2),
  'waste_list returns at least 2 rows'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a03');
select is(
  (select (public.waste_get(
    (select id from t030_ctx where key = 'w1')
  ) ->> 'total_value')::numeric),
  15000, 'waste_get shows total_value 15000 to cost_controller'
);
select public._t030_as('d0300000-0000-4000-8000-000000000a02');
select ok(
  (select (public.waste_get(
    (select id from t030_ctx where key = 'w1')
  ) ->> 'total_value') is null),
  'waste_get hides total_value from outlet_head'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a10');
select throws_ok(
  $q$select public.requisition_save_draft(
    '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "lines": []}'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:requisition.create',
  'viewer cannot create requisition draft'
);
select throws_ok(
  $q$select public.transfer_save_draft(
    '{"property_id": "d0300000-0000-4000-8000-000000000201", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000304", "lines": []}'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:transfer.send',
  'viewer cannot create transfer draft'
);
select throws_ok(
  $q$select public.waste_save_draft(
    '{"property_id": "d0300000-0000-4000-8000-000000000201", "warehouse_id": "d0300000-0000-4000-8000-000000000301", "reason_code": "broken", "lines": []}'::jsonb
  )$q$,
  '42501', 'ERR_FORBIDDEN:waste.propose',
  'viewer cannot create waste draft'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
insert into t030_resp values ('r4', public.requisition_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000504", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('r4', (select (resp ->> 'id')::uuid from t030_resp where key = 'r4'));
insert into t030_resp values ('r5', public.requisition_save_draft(
  '{"property_id": "d0300000-0000-4000-8000-000000000201", "outlet_id": "d0300000-0000-4000-8000-000000000802", "from_warehouse_id": "d0300000-0000-4000-8000-000000000301", "to_warehouse_id": "d0300000-0000-4000-8000-000000000303", "lines": [{"item_id": "d0300000-0000-4000-8000-000000000505", "qty": 1, "uom": "kg"}]}'::jsonb
));
insert into t030_ctx values ('r5', (select (resp ->> 'id')::uuid from t030_resp where key = 'r5'));
select public.requisition_submit(
  'd0300000-0000-4000-8000-000000000201',
  (select id from t030_ctx where key = 'r5')
);

reset role;
update public.items
set status = 'merged', merged_into_item_id = 'd0300000-0000-4000-8000-000000000501'
where id = 'd0300000-0000-4000-8000-000000000504';
update public.items
set status = 'merged', merged_into_item_id = 'd0300000-0000-4000-8000-000000000501'
where id = 'd0300000-0000-4000-8000-000000000505';
set local role authenticated;

select public._t030_as('d0300000-0000-4000-8000-000000000a02');
select is(
  (select item_id from public.requisition_lines
   where requisition_id = (select id from t030_ctx where key = 'r4')),
  'd0300000-0000-4000-8000-000000000501',
  'item merge repoints draft requisition line to target item'
);
select is(
  (select item_id from public.requisition_lines
   where requisition_id = (select id from t030_ctx where key = 'r5')),
  'd0300000-0000-4000-8000-000000000505',
  'item merge does not repoint submitted requisition line'
);

select public._t030_as('d0300000-0000-4000-8000-000000000a03');
select is(
  (select qty from public.stock_balances
   where warehouse_id = 'd0300000-0000-4000-8000-000000000301'
     and item_id = 'd0300000-0000-4000-8000-000000000501'
     and lot_id is null),
  38, 'final: main GAO balance 38'
);
select is(
  (select qty_on_hand from public.item_costs
   where legal_entity_id = 'd0300000-0000-4000-8000-000000000101'
     and item_id = 'd0300000-0000-4000-8000-000000000501'),
  50, 'final: entity GAO qty_on_hand 50 (200 - 2 purpose issue + 2 reversal - 150 waste)'
);

select * from finish();
rollback;
