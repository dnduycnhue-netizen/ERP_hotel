begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(128);
insert into public.organizations (id, name) values
('d0200000-0200-4000-8000-000000000001', 'T-020 Master Org');
insert into public.legal_entities (id, org_id, code, name) values
('d0200000-0200-4000-8000-000000000101', 'd0200000-0200-4000-8000-000000000001', 'T020', 'Entity T-020'),
('d0200000-0200-4000-8000-000000000102', 'd0200000-0200-4000-8000-000000000001', 'T020B', 'Entity T-020 B');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
('d0200000-0200-4000-8000-000000000201', 'd0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000101', 'P0201', 'Property T-020', 'with_cc'),
('d0200000-0200-4000-8000-000000000202', 'd0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000102', 'P0202', 'Property T-020 no-CC', 'without_cc');
insert into public.uoms (code, name_vi) values
('kg', 'Kilôgam'),
('cai', 'Cái')
on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
('d0200000-0200-4000-8000-000000000401', 'd0200000-0200-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
('d0200000-0200-4000-8000-000000000402', 'd0200000-0200-4000-8000-000000000001', 'THIT', 'Thịt', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, allowed_channels) values
('d0200000-0200-4000-8000-000000000501', 'd0200000-0200-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0200000-0200-4000-8000-000000000401', 'kg', true, array['contract', 'market']),
('d0200000-0200-4000-8000-000000000502', 'd0200000-0200-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0200000-0200-4000-8000-000000000402', 'kg', true, array['contract']),
('d0200000-0200-4000-8000-000000000503', 'd0200000-0200-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0200000-0200-4000-8000-000000000401', 'kg', false, array['contract', 'market']);
insert into public.item_purchase_units (org_id, item_id, uom, factor_to_stock, is_default) values
('d0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000501', 'cai', 10, false);
insert into public.suppliers (id, org_id, code, name, kind, status) values
('d0200000-0200-4000-8000-000000000701', 'd0200000-0200-4000-8000-000000000001', 'NCC_GAO', 'Công ty Gạo Sạch', 'company', 'active'),
('d0200000-0200-4000-8000-000000000702', 'd0200000-0200-4000-8000-000000000001', 'NCC_BAN', 'NCC bị cấm', 'company', 'banned'),
('d0200000-0200-4000-8000-000000000703', 'd0200000-0200-4000-8000-000000000001', 'NCC_SUS', 'NCC tạm ngưng', 'company', 'suspended');
insert into public.price_agreements (id, org_id, supplier_id, valid_from, valid_to, status) values
('d0200000-0200-4000-8000-000000000801', 'd0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000701', '2026-01-01', '2030-12-31', 'active');
insert into public.price_agreement_lines (org_id, agreement_id, item_id, uom, unit_price) values
('d0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000801', 'd0200000-0200-4000-8000-000000000501', 'kg', 10000),
('d0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000801', 'd0200000-0200-4000-8000-000000000502', 'kg', 60000);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
('d0200000-0200-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-pur020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-out020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-cc020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-gm020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u5-own020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-acct020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u7-both020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a08', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u8-outcreator020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a09', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u9-admin020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
('d0200000-0200-4000-8000-000000000a10', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u10-view020@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by) values
('d0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000201', 'd0200000-0200-4000-8000-000000000501', 'kg', 12000, '2026-01-01', '2030-12-31', 'd0200000-0200-4000-8000-000000000a01'),
('d0200000-0200-4000-8000-000000000001', 'd0200000-0200-4000-8000-000000000201', 'd0200000-0200-4000-8000-000000000502', 'kg', 50000, '2026-01-01', '2030-12-31', 'd0200000-0200-4000-8000-000000000a01');
insert into public.cost_centers (id, org_id, code, name) values
('d0200000-0200-4000-8000-000000000311', 'd0200000-0200-4000-8000-000000000001', 'CC_KIT', 'Bếp');
insert into public.outlet_types (id, org_id, code, name) values
('d0200000-0200-4000-8000-000000000301', 'd0200000-0200-4000-8000-000000000001', 'KITCHEN', 'Bếp');
insert into public.outlets (id, property_id, outlet_type_id, cost_center_id, code, name) values
('d0200000-0200-4000-8000-000000000321', 'd0200000-0200-4000-8000-000000000201', 'd0200000-0200-4000-8000-000000000301', 'd0200000-0200-4000-8000-000000000311', 'KIT01', 'Bếp chính'),
('d0200000-0200-4000-8000-000000000322', 'd0200000-0200-4000-8000-000000000202', 'd0200000-0200-4000-8000-000000000301', 'd0200000-0200-4000-8000-000000000311', 'KIT02', 'Bếp chính 2');
insert into public.profiles (id, employee_code, full_name) values
('d0200000-0200-4000-8000-000000000a01', 'NV02001', 'Thu mua'),
('d0200000-0200-4000-8000-000000000a02', 'NV02002', 'Trưởng bếp'),
('d0200000-0200-4000-8000-000000000a03', 'NV02003', 'Cost Controller'),
('d0200000-0200-4000-8000-000000000a04', 'NV02004', 'Tổng quản lý'),
('d0200000-0200-4000-8000-000000000a05', 'NV02005', 'Chủ đầu tư'),
('d0200000-0200-4000-8000-000000000a06', 'NV02006', 'Kế toán'),
('d0200000-0200-4000-8000-000000000a07', 'NV02007', 'Vừa tạo vừa duyệt PO'),
('d0200000-0200-4000-8000-000000000a08', 'NV02008', 'Vừa tạo vừa duyệt PR'),
('d0200000-0200-4000-8000-000000000a09', 'NV02009', 'Quản trị cấu hình'),
('d0200000-0200-4000-8000-000000000a10', 'NV02010', 'Chỉ xem')
on conflict (id) do update set
employee_code = excluded.employee_code,
full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
('d0200000-0200-4000-8000-000000000601', 'd0200000-0200-4000-8000-000000000001', 'purchaser', 'Mua hàng'),
('d0200000-0200-4000-8000-000000000602', 'd0200000-0200-4000-8000-000000000001', 'outlet_head', 'Trưởng bộ phận'),
('d0200000-0200-4000-8000-000000000603', 'd0200000-0200-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
('d0200000-0200-4000-8000-000000000604', 'd0200000-0200-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
('d0200000-0200-4000-8000-000000000605', 'd0200000-0200-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
('d0200000-0200-4000-8000-000000000606', 'd0200000-0200-4000-8000-000000000001', 'accountant', 'Kế toán'),
('d0200000-0200-4000-8000-000000000608', 'd0200000-0200-4000-8000-000000000001', 'r_admin020', 'Quản trị cấu hình'),
('d0200000-0200-4000-8000-000000000609', 'd0200000-0200-4000-8000-000000000001', 'r_view020', 'Chỉ xem');
insert into public.role_permissions (role_id, permission_code) values
('d0200000-0200-4000-8000-000000000601', 'pr.create'),
('d0200000-0200-4000-8000-000000000601', 'po.create'),
('d0200000-0200-4000-8000-000000000601', 'po.view'),
('d0200000-0200-4000-8000-000000000601', 'po.view_qty'),
('d0200000-0200-4000-8000-000000000601', 'po.view_price'),
('d0200000-0200-4000-8000-000000000601', 'po.close'),
('d0200000-0200-4000-8000-000000000601', 'item.temp.create'),
('d0200000-0200-4000-8000-000000000602', 'pr.create'),
('d0200000-0200-4000-8000-000000000602', 'pr.approve'),
('d0200000-0200-4000-8000-000000000603', 'po.approve'),
('d0200000-0200-4000-8000-000000000603', 'item.temp.normalize'),
('d0200000-0200-4000-8000-000000000604', 'po.approve'),
('d0200000-0200-4000-8000-000000000604', 'po.approve.over_ceiling'),
('d0200000-0200-4000-8000-000000000605', 'po.approve'),
('d0200000-0200-4000-8000-000000000605', 'po.approve.over_ceiling'),
('d0200000-0200-4000-8000-000000000605', 'po.close'),
('d0200000-0200-4000-8000-000000000606', 'po.approve'),
('d0200000-0200-4000-8000-000000000608', 'admin.approval_rules.manage'),
('d0200000-0200-4000-8000-000000000609', 'po.view');
insert into public.user_property_roles (user_id, role_id, property_id) values
('d0200000-0200-4000-8000-000000000a01', 'd0200000-0200-4000-8000-000000000601', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a01', 'd0200000-0200-4000-8000-000000000601', 'd0200000-0200-4000-8000-000000000202'),
('d0200000-0200-4000-8000-000000000a02', 'd0200000-0200-4000-8000-000000000602', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a02', 'd0200000-0200-4000-8000-000000000602', 'd0200000-0200-4000-8000-000000000202'),
('d0200000-0200-4000-8000-000000000a03', 'd0200000-0200-4000-8000-000000000603', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a04', 'd0200000-0200-4000-8000-000000000604', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a05', 'd0200000-0200-4000-8000-000000000605', null),
('d0200000-0200-4000-8000-000000000a06', 'd0200000-0200-4000-8000-000000000606', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a06', 'd0200000-0200-4000-8000-000000000606', 'd0200000-0200-4000-8000-000000000202'),
('d0200000-0200-4000-8000-000000000a07', 'd0200000-0200-4000-8000-000000000601', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a07', 'd0200000-0200-4000-8000-000000000603', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a08', 'd0200000-0200-4000-8000-000000000601', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a08', 'd0200000-0200-4000-8000-000000000602', 'd0200000-0200-4000-8000-000000000201'),
('d0200000-0200-4000-8000-000000000a09', 'd0200000-0200-4000-8000-000000000608', null),
('d0200000-0200-4000-8000-000000000a10', 'd0200000-0200-4000-8000-000000000609', 'd0200000-0200-4000-8000-000000000201');
insert into public.approval_rules (org_id, property_id, doc_type, min_amount, max_amount, item_group_id, condition, step, approver_role_id, approver_user_id, required_perm) values
('d0200000-0200-4000-8000-000000000001', null, 'pr', 0, null, null, '{}', 1, 'd0200000-0200-4000-8000-000000000602', null, 'pr.approve'),
('d0200000-0200-4000-8000-000000000001', null, 'po', 0, 5000000, null, '{}', 1, 'd0200000-0200-4000-8000-000000000602', null, 'po.approve'),
('d0200000-0200-4000-8000-000000000001', null, 'po', 5000000, 20000000, null, '{}', 2, 'd0200000-0200-4000-8000-000000000603', null, 'po.approve'),
('d0200000-0200-4000-8000-000000000001', null, 'po', 20000000, 100000000, null, '{}', 3, 'd0200000-0200-4000-8000-000000000604', null, 'po.approve'),
('d0200000-0200-4000-8000-000000000001', null, 'po', 100000000, null, null, '{}', 4, 'd0200000-0200-4000-8000-000000000605', null, 'po.approve');
create or replace function public._t020_as(p_user uuid)
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
(select relrowsecurity from pg_class where relname = 'purchase_requests'),
true, 'purchase_requests has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'purchase_request_lines'),
true, 'purchase_request_lines has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'purchase_orders'),
true, 'purchase_orders has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'purchase_order_lines'),
true, 'purchase_order_lines has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'approvals'),
true, 'approvals has RLS enabled'
);
select is(
(select relrowsecurity from pg_class where relname = 'approval_delegations'),
true, 'approval_delegations has RLS enabled'
);
insert into public.purchase_requests (id, org_id, legal_entity_id, property_id, doc_no, kind, status)
values (
'd0200000-0200-4000-8000-000000000b01',
'd0200000-0200-4000-8000-000000000001',
'd0200000-0200-4000-8000-000000000101',
'd0200000-0200-4000-8000-000000000201',
'PR-GUARD-0001', 'stock', 'draft'
);
select throws_ok(
$q$update public.purchase_requests set status = 'approved' where id = 'd0200000-0200-4000-8000-000000000b01'$q$,
'P0001', 'ERR_INVALID_STATUS',
'Direct PR status change is blocked by trigger'
);
select throws_ok(
$q$insert into public.purchase_request_lines (pr_id, org_id, qty, uom) values (
    'd0200000-0200-4000-8000-000000000b01',
    'd0200000-0200-4000-8000-000000000001',
    10, 'kg'
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'Direct PR line insert is blocked by trigger'
);
set local role authenticated;
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select throws_ok(
$q$insert into public.purchase_requests (org_id, legal_entity_id, property_id, doc_no, kind) values (
    'd0200000-0200-4000-8000-000000000001',
    'd0200000-0200-4000-8000-000000000101',
    'd0200000-0200-4000-8000-000000000201',
    'PR-DIRECT-0001', 'stock'
  )$q$,
'42501', null,
'Direct PR insert via RLS is blocked (no INSERT policy)'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a07');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"outlet_id": "d0200000-0200-4000-8000-000000000321", "kind": "stock", "need_date": "2026-11-15", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 3000, "uom": "kg"}]}'::jsonb
  )$q$,
'Purchaser can create PR draft via RPC'
);
select ok(
(select doc_no like 'PR-T020-%' from public.purchase_requests where kind = 'stock' and status = 'draft' order by created_at desc limit 1),
'PR doc_no follows next_doc_no format'
);
select is(
(select count(*) from public.purchase_request_lines prl join public.purchase_requests pr on pr.id = prl.pr_id where pr.status = 'draft'),
1::bigint,
'PR draft has 1 line'
);
select throws_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 10, "uom": "yen"}]}'::jsonb
  )$q$,
'P0001', 'ERR_UOM_UNKNOWN',
'PR line with unknown UOM is rejected'
);
select throws_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"description": "Hang khong ro", "qty": 10, "uom": "kg"}]}'::jsonb
  )$q$,
'P0001', 'ERR_INVALID_VALUE',
'Stock PR line without item is rejected'
);
create temp table t020_ctx (key text primary key, id uuid);
insert into t020_ctx(key, id)
select 'pr_main', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a07'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_main'))$q$,
'Creator can submit PR'
);
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_main')),
'submitted', 'PR status is submitted after submit'
);
select is(
(select count(*) from public.approvals where doc_type = 'pr' and doc_id = (select id from t020_ctx where key = 'pr_main')),
1::bigint, 'PR submit generates 1 approval step'
);
select is(
(select approver_role_id from public.approvals where doc_type = 'pr' and doc_id = (select id from t020_ctx where key = 'pr_main')),
'd0200000-0200-4000-8000-000000000602'::uuid, 'PR step approver is outlet_head'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a08');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 5, "uom": "kg"}]}'::jsonb
  )$q$,
'u8 can create PR draft'
);
insert into t020_ctx(key, id)
select 'pr_sod', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a08'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_sod'))$q$,
'u8 can submit own PR'
);
select throws_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_sod'), 'approved', 'Tự duyệt')$q$,
'P0001', 'ERR_SOD_PR_CREATOR_APPROVER',
'PR creator cannot approve own PR (SoD)'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select throws_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_main'), 'approved', null)$q$,
'42501', 'ERR_FORBIDDEN:pr.approve',
'User without pr.approve cannot decide PR'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_main'), 'approved', 'Duyệt mua gạo')$q$,
'Outlet head can approve PR'
);
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_main')),
'approved', 'PR is approved after outlet head decision'
);
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_sod'), 'approved', 'OK')$q$,
'Outlet head can approve second PR'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a07');
insert into t020_ctx(key, id)
select 'prl_main', id from public.purchase_request_lines
where pr_id = (select id from t020_ctx where key = 'pr_main') limit 1;
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from t020_ctx where key = 'prl_main')],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Purchaser can create PO from approved PR'
);
insert into t020_ctx(key, id)
select 'po_30m', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a07'
order by created_at desc limit 1;
select is(
(select price_source from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_30m')),
'agreement', 'PO line price source is agreement'
);
select is(
(select unit_price from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_30m')),
10000.0000::numeric(18,4), 'PO line unit price is agreement price'
);
select is(
(select qty_stock from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_30m')),
3000.0000::numeric(18,4), 'PO line qty_stock equals qty for stock UOM'
);
select is(
(select total_amount from public.purchase_orders where id = (select id from t020_ctx where key = 'po_30m')),
30000000.00::numeric(18,2), 'PO total is 30M'
);
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_main')),
'converted', 'PR is converted after PO creation'
);
insert into t020_ctx(key, id)
select 'prl_sod', id from public.purchase_request_lines
where pr_id = (select id from t020_ctx where key = 'pr_sod') limit 1;
select throws_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from t020_ctx where key = 'prl_sod')],
    'd0200000-0200-4000-8000-000000000702', 'contract'
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'Banned supplier cannot be used for PO'
);
select throws_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from t020_ctx where key = 'prl_main')],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'Fully converted PR line cannot be converted again'
);
select lives_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_30m'))$q$,
'Creator can submit PO 30M'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_30m')),
'submitted', 'PO 30M status is submitted'
);
select is(
(select count(*) from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_30m')),
3::bigint, 'AC: PO 30M has 3 approval steps'
);
select is(
(select decision from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_30m') and step = 1),
'approved', 'Step 1 outlet_head is auto-approved from approved PR'
);
select is(
(select approver_role_id from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_30m') and step = 2),
'd0200000-0200-4000-8000-000000000603'::uuid, 'Step 2 approver is cost_controller'
);
select is(
(select approver_role_id from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_30m') and step = 3),
'd0200000-0200-4000-8000-000000000604'::uuid, 'Step 3 approver is gm'
);
select throws_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_30m'), 'approved', null)$q$,
'P0001', 'ERR_SOD_PO_CREATOR_APPROVER',
'AC: PO creator cannot approve own PO (SoD)'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a04');
select throws_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_30m'), 'approved', null)$q$,
'P0001', 'ERR_NOT_APPROVER',
'GM cannot decide cost_controller step'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a03');
select lives_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_30m'), 'approved', 'Giá đúng hợp đồng')$q$,
'Cost controller approves step 2'
);
select is(
(select count(*) from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_30m') and decision = 'pending'),
1::bigint, 'One pending step remains after step 2'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a04');
select lives_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_30m'), 'approved', 'Đồng ý')$q$,
'GM approves step 3'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_30m')),
'approved', 'PO is approved after all steps'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a07');
select lives_ok(
$q$select public.po_send('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_30m'))$q$,
'Creator can send approved PO'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_30m')),
'sent', 'PO status is sent'
);
select throws_ok(
$q$select public.po_close('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_30m'), '')$q$,
'P0001', 'ERR_REASON_REQUIRED',
'PO close requires reason'
);
select lives_ok(
$q$select public.po_close('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_30m'), 'NCC hết hàng, đóng phần còn lại')$q$,
'Creator can close sent PO with reason'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_30m')),
'closed', 'PO status is closed'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 100, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR2'
);
insert into t020_ctx(key, id)
select 'pr_2', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_2'))$q$,
'Setup: u1 submits PR2'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_2'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR2'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_2') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Setup: u1 creates PO2 from PR2'
);
insert into t020_ctx(key, id)
select 'po_2', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select throws_ok(
$q$select public.po_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id from t020_ctx where key = 'po_2'),
      'lines', jsonb_build_array(
        jsonb_build_object(
          'id', (select id from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_2')),
          'item_id', 'd0200000-0200-4000-8000-000000000501',
          'qty', 100, 'uom', 'kg', 'unit_price', 9999
        )
      )
    )
  )$q$,
'P0001', 'ERR_INVALID_STATUS',
'Agreement line unit_price cannot be changed in draft'
);
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000503", "qty": 100, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR manual (Muối, không hợp đồng/trần)'
);
insert into t020_ctx(key, id)
select 'pr_manual', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_manual'))$q$,
'Setup: u1 submits PR manual'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_manual'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR manual'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_manual') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Setup: u1 creates manual PO from PR manual'
);
insert into t020_ctx(key, id)
select 'po_manual', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select is(
(select price_source from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_manual')),
'manual', 'Line without agreement/ceiling has price_source manual'
);
select throws_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_manual'))$q$,
'P0001', 'ERR_PRICE_NOT_SET',
'Manual PO without price cannot be submitted'
);
select lives_ok(
$q$select public.po_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id from t020_ctx where key = 'po_manual'),
      'lines', jsonb_build_array(
        jsonb_build_object(
          'id', (select id from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_manual')),
          'item_id', 'd0200000-0200-4000-8000-000000000503',
          'qty', 100, 'uom', 'kg', 'unit_price', 5000
        )
      )
    )
  )$q$,
'Manual line price can be set in draft'
);
select is(
(select unit_price from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_manual')),
5000.0000::numeric(18,4), 'Manual line price is updated'
);
select lives_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_manual'))$q$,
'Manual PO submits after price is set'
);
select is(
(select count(*) from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_manual')),
2::bigint, 'Manual PO has 2 steps (outlet_head auto + extra GM)'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_manual')),
'submitted', 'Manual PO is submitted (GM step pending)'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a04');
select lives_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_manual'), 'approved', 'Đồng ý giá tay')$q$,
'GM approves manual-price step'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_manual')),
'approved', 'Manual PO is approved'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000502", "qty": 10, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR over-ceiling (Thịt)'
);
insert into t020_ctx(key, id)
select 'pr_over', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_over'))$q$,
'Setup: u1 submits PR over-ceiling'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_over'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR over-ceiling'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_over') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Setup: u1 creates over-ceiling PO from PR over-ceiling'
);
insert into t020_ctx(key, id)
select 'po_over', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select is(
(select over_ceiling from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_over')),
true, 'Agreement price above ceiling flags over_ceiling'
);
select is(
(select ceiling_price from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_over')),
50000.0000::numeric(18,4), 'Ceiling price is recorded on PO line'
);
select throws_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_over'))$q$,
'P0001', 'ERR_OVER_CEILING_NO_REASON',
'Over-ceiling PO cannot submit without reason'
);
select lives_ok(
$q$select public.po_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id from t020_ctx where key = 'po_over'),
      'over_ceiling_reason', 'Giá thịt tăng theo thị trường, đã đối chiếu 3 NCC',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'id', (select id from public.purchase_order_lines where po_id = (select id from t020_ctx where key = 'po_over')),
          'item_id', 'd0200000-0200-4000-8000-000000000502',
          'qty', 10, 'uom', 'kg'
        )
      )
    )
  )$q$,
'Over-ceiling reason can be saved in draft'
);
select lives_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_over'))$q$,
'Over-ceiling PO submits with reason'
);
select is(
(select count(*) from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_over')),
2::bigint, 'Over-ceiling PO has 2 steps (outlet_head auto + extra GM)'
);
select is(
(select required_perm from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_over') and step = 2),
'po.approve.over_ceiling', 'Extra GM step requires po.approve.over_ceiling'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a04');
select lives_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_over'), 'approved', 'Đồng ý vượt trần')$q$,
'GM approves over-ceiling step'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_over')),
'approved', 'Over-ceiling PO is approved'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000502", "qty": 5, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR market (Thịt)'
);
insert into t020_ctx(key, id)
select 'pr_market', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_market'))$q$,
'Setup: u1 submits PR market'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_market'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR market'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select throws_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_market') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'market'
  )$q$,
'P0001', 'ERR_CHANNEL_NOT_ALLOWED',
'Market channel is blocked for item without market channel'
);
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 10, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR reject flow'
);
insert into t020_ctx(key, id)
select 'pr_rej', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_rej'))$q$,
'Setup: u1 submits PR reject flow'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select throws_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_rej'), 'rejected', '')$q$,
'P0001', 'ERR_REASON_REQUIRED',
'Rejecting PR requires comment'
);
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_rej'), 'rejected', 'Số lượng chưa hợp lý')$q$,
'Outlet head can reject PR with comment'
);
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_rej')),
'rejected', 'PR status is rejected'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id from t020_ctx where key = 'pr_rej'),
      'kind', 'stock',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'id', (select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_rej')),
          'item_id', 'd0200000-0200-4000-8000-000000000501',
          'qty', 8, 'uom', 'kg'
        )
      )
    )
  )$q$,
'Rejected PR can be edited back to draft'
);
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_rej')),
'draft', 'Rejected PR returns to draft after edit'
);
select is(
(select count(*) from public.approvals where doc_type = 'pr' and doc_id = (select id from t020_ctx where key = 'pr_rej')),
0::bigint, 'Old approval steps are cleared when rejected PR is edited'
);
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_rej'))$q$,
'Edited PR can be resubmitted'
);
select is(
(select count(*) from public.approvals where doc_type = 'pr' and doc_id = (select id from t020_ctx where key = 'pr_rej')),
1::bigint, 'Resubmitted PR has 1 fresh approval step'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a09');
select lives_ok(
$q$select public.admin_approval_delegation_save(
    'd0200000-0200-4000-8000-000000000001',
    '{"from_user": "d0200000-0200-4000-8000-000000000a03", "to_user": "d0200000-0200-4000-8000-000000000a06", "property_id": "d0200000-0200-4000-8000-000000000201", "valid_from": "2026-01-01", "valid_to": "2030-12-31", "reason": "Cost Controller nghỉ phép"}'::jsonb
  )$q$,
'Admin can save approval delegation'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 1000, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR delegation (Gạo 1000kg = 10tr)'
);
insert into t020_ctx(key, id)
select 'pr_deleg', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_deleg'))$q$,
'Setup: u1 submits PR delegation'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_deleg'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR delegation'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_deleg') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Setup: u1 creates PO delegation (10M)'
);
insert into t020_ctx(key, id)
select 'po_deleg', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_deleg'))$q$,
'Setup: u1 submits PO delegation'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a06');
select lives_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_deleg'), 'approved', 'Duyệt thay CC đang nghỉ')$q$,
'Delegate can decide delegated step'
);
select is(
(select delegated_from from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_deleg') and step = 2),
'd0200000-0200-4000-8000-000000000a03'::uuid, 'Delegated decision records delegated_from'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_deleg')),
'approved', 'PO is approved after delegated decision'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000202',
    '{"outlet_id": "d0200000-0200-4000-8000-000000000322", "kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 1000, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR without_cc (Gạo 1000kg = 10tr)'
);
insert into t020_ctx(key, id)
select 'pr_nocc', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01' and property_id = 'd0200000-0200-4000-8000-000000000202'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000202', (select id from t020_ctx where key = 'pr_nocc'))$q$,
'Setup: u1 submits PR without_cc'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000202', (select id from t020_ctx where key = 'pr_nocc'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR without_cc'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000202',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_nocc') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Setup: u1 creates PO without_cc (10M)'
);
insert into t020_ctx(key, id)
select 'po_nocc', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01' and property_id = 'd0200000-0200-4000-8000-000000000202'
order by created_at desc limit 1;
select lives_ok(
$q$select public.po_submit('d0200000-0200-4000-8000-000000000202', (select id from t020_ctx where key = 'po_nocc'))$q$,
'Setup: u1 submits PO without_cc'
);
select is(
(select approver_role_id from public.approvals where doc_type = 'po' and doc_id = (select id from t020_ctx where key = 'po_nocc') and step = 2),
'd0200000-0200-4000-8000-000000000606'::uuid, 'without_cc: cost_controller step is replaced by accountant'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a06');
select lives_ok(
$q$select public.approval_decide('d0200000-0200-4000-8000-000000000202', 'po', (select id from t020_ctx where key = 'po_nocc'), 'approved', 'OK')$q$,
'Accountant approves substituted step'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_nocc')),
'approved', 'without_cc PO is approved'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    '{"kind": "stock", "lines": [{"item_id": "d0200000-0200-4000-8000-000000000501", "qty": 100, "uom": "kg"}]}'::jsonb
  )$q$,
'Setup: u1 creates PR cancel flow'
);
insert into t020_ctx(key, id)
select 'pr_cancel', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_submit('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_cancel'))$q$,
'Setup: u1 submits PR cancel flow'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a02');
select lives_ok(
$q$select public.pr_decide('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'pr_cancel'), 'approved', 'OK')$q$,
'Setup: outlet head approves PR cancel flow'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select lives_ok(
$q$select public.po_create_from_pr(
    'd0200000-0200-4000-8000-000000000201',
    array[(select id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_cancel') limit 1)],
    'd0200000-0200-4000-8000-000000000701', 'contract'
  )$q$,
'Setup: u1 creates PO cancel flow from PR cancel flow'
);
insert into t020_ctx(key, id)
select 'po_cancel', id from public.purchase_orders
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_cancel')),
'converted', 'PR is converted before cancel'
);
select lives_ok(
$q$select public.po_cancel('d0200000-0200-4000-8000-000000000201', (select id from t020_ctx where key = 'po_cancel'), 'Hủy vì NCC báo hết hàng')$q$,
'Creator can cancel draft PO with reason'
);
select is(
(select status from public.purchase_requests where id = (select id from t020_ctx where key = 'pr_cancel')),
'approved', 'PR returns to approved after PO cancel'
);
select is(
(select converted_qty from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_cancel')),
0::numeric(18,4), 'Converted qty is released after PO cancel'
);
select is(
(select status from public.purchase_orders where id = (select id from t020_ctx where key = 'po_cancel')),
'cancelled', 'PO is cancelled'
);
select lives_ok(
$q$select public.item_create_temp(
    'd0200000-0200-4000-8000-000000000201', 'Ớt tạm test', 'd0200000-0200-4000-8000-000000000401', 'kg'
  )$q$,
'Setup: u1 creates temp item'
);
insert into t020_ctx(key, id)
select 'item_tmp', id from public.items
where is_temp and org_id = 'd0200000-0200-4000-8000-000000000001'
order by created_at desc limit 1;
select lives_ok(
$q$select public.pr_save_draft(
    'd0200000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'kind', 'stock',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'item_id', (select id from t020_ctx where key = 'item_tmp'),
          'qty', 10, 'uom', 'kg'
        )
      )
    )
  )$q$,
'Setup: u1 creates draft PR with temp item'
);
insert into t020_ctx(key, id)
select 'pr_tmp', id from public.purchase_requests
where status = 'draft' and created_by = 'd0200000-0200-4000-8000-000000000a01'
order by created_at desc limit 1;
select public._t020_as('d0200000-0200-4000-8000-000000000a03');
select lives_ok(
$q$select public.item_merge(
    'd0200000-0200-4000-8000-000000000201',
    (select id from t020_ctx where key = 'item_tmp'),
    'd0200000-0200-4000-8000-000000000501'
  )$q$,
'Cost controller merges temp item into real item'
);
select is(
(select item_id from public.purchase_request_lines where pr_id = (select id from t020_ctx where key = 'pr_tmp')),
'd0200000-0200-4000-8000-000000000501'::uuid,
'Q13: draft PR line is re-pointed to merged target item'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a01');
select is(
((select public.pr_list('d0200000-0200-4000-8000-000000000201', null, null, 100, 0)) ->> 'total')::int >= 1,
true, 'pr_list returns PRs for the property'
);
select is(
(select jsonb_array_length((select public.approval_timeline('d0200000-0200-4000-8000-000000000201', 'po', (select id from t020_ctx where key = 'po_30m'))) -> 'steps')),
3, 'approval_timeline returns 3 steps for PO 30M'
);
select public._t020_as('d0200000-0200-4000-8000-000000000a10');
select is(
((select public.po_list('d0200000-0200-4000-8000-000000000201', null, null, 100, 0)) ->> 'total')::int >= 1,
true, 'po_list works for view-only role'
);
set local role authenticated;
select * from finish();
rollback;
