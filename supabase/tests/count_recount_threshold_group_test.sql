-- ============================================================================
-- R26 theo nhom (560000) — pgTAP cho nguong dem lai theo nhom hang.
--   RUOU 1,5% / THIT 3% / RAU 5% / nhom khong cau hinh -> nguong chung
--   (count_recount_threshold_pct, mac dinh 5); ho so without_cc nhan he
--   so count_without_cc_factor (mac dinh 0,7).
--   - §0: helper _count_line_threshold_pct / _count_without_cc_factor o
--     muc ham (gom ca CHECK 0-100 cua cot moi).
--   - §1: property with_cc — ruou lech 2% -> dem lai (vuot 1,5%), thit
--     lech 3% -> ok (= 3%), rau lech 4% -> ok (<= 5%), do kho lech 4%
--     -> ok (nguong chung 5%).
--   - §2: ton so = 0 — moi lech khac 0 deu vuot nguong (dem 5 vs ton 0
--     -> dem lai); dem 0 vs ton 0 -> ok.
--   - §3: property without_cc — rau lech 4% -> dem lai (vuot 5 x 0,7
--     = 3,5%), do kho lech 3% -> ok (<= 3,5%).
--   - §4: nguong chung doi duoc qua settings; nguong nhom thang nguong
--     chung; he so without_cc doi duoc qua settings.
-- GIA DINH: fixture tu tao nhom cua minh, khong phu thuoc seed
-- production; file recount_threshold_zero_count_test.sql cu khong doi
-- hanh vi (nhom cu co threshold null + property with_cc) nen van dat.
-- R20 (dem mu) KHONG test o day: cac lan doc dong deu dung a03 (co
-- count.view_variance) vi RLS stock_count_lines_select chan nguoi
-- khong co quyen nay (bai hoc T-032).
-- Chay trong 1 transaction begin...rollback; chi chay file nay.
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(43);

-- ---------------------------------------------------------------------------
-- §0. Fixture
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d9e70000-0000-4000-8000-000000000001', 'R26 nhom Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('d9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000001', 'R540', 'Entity R540');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d9e70000-0000-4000-8000-000000000201', 'd9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'P540A', 'Property R540 with_cc', 'with_cc'),
  ('d9e70000-0000-4000-8000-000000000202', 'd9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'P540B', 'Property R540 without_cc', 'without_cc');
insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái'),
  ('ml', 'Mililít')
on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind, recount_threshold_pct) values
  ('d9e70000-0000-4000-8000-000000000401', 'd9e70000-0000-4000-8000-000000000001', 'RUOU', 'Rượu mạnh', 'beverage', 1.5),
  ('d9e70000-0000-4000-8000-000000000402', 'd9e70000-0000-4000-8000-000000000001', 'THIT', 'Thịt & Cá', 'food', 3),
  ('d9e70000-0000-4000-8000-000000000403', 'd9e70000-0000-4000-8000-000000000001', 'RAU', 'Rau củ', 'food', 5),
  ('d9e70000-0000-4000-8000-000000000404', 'd9e70000-0000-4000-8000-000000000001', 'KHO', 'Đồ khô', 'food', null);
insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, tare_g, density_g_ml) values
  ('d9e70000-0000-4000-8000-000000000501', 'd9e70000-0000-4000-8000-000000000001', 'ITM_RUOU', 'Rượu whisky', 'd9e70000-0000-4000-8000-000000000401', 'ml', true, false, null, array['contract'], null, null),
  ('d9e70000-0000-4000-8000-000000000502', 'd9e70000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd9e70000-0000-4000-8000-000000000402', 'kg', true, false, null, array['contract'], null, null),
  ('d9e70000-0000-4000-8000-000000000503', 'd9e70000-0000-4000-8000-000000000001', 'ITM_RAU', 'Cải ngọt', 'd9e70000-0000-4000-8000-000000000403', 'kg', true, false, null, array['contract'], null, null),
  ('d9e70000-0000-4000-8000-000000000504', 'd9e70000-0000-4000-8000-000000000001', 'ITM_KHO', 'Gạo ST25', 'd9e70000-0000-4000-8000-000000000404', 'kg', true, false, null, array['contract'], null, null),
  ('d9e70000-0000-4000-8000-000000000505', 'd9e70000-0000-4000-8000-000000000001', 'ITM_RAU2', 'Xà lách', 'd9e70000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract'], null, null),
  ('d9e70000-0000-4000-8000-000000000506', 'd9e70000-0000-4000-8000-000000000001', 'ITM_KHO2', 'Muối hạt', 'd9e70000-0000-4000-8000-000000000404', 'kg', false, false, null, array['contract'], null, null);
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d9e70000-0000-4000-8000-000000000301', 'd9e70000-0000-4000-8000-000000000201', 'WH1', 'Kho 1 (with_cc)', 'main', null),
  ('d9e70000-0000-4000-8000-000000000302', 'd9e70000-0000-4000-8000-000000000201', 'WH2', 'Kho 2 (ton 0)', 'main', null),
  ('d9e70000-0000-4000-8000-000000000303', 'd9e70000-0000-4000-8000-000000000202', 'WH3', 'Kho 3 (without_cc)', 'main', null);
insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000201', 'd9e70000-0000-4000-8000-000000000301', 'd9e70000-0000-4000-8000-000000000501', null, 1000),
  ('d9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000201', 'd9e70000-0000-4000-8000-000000000301', 'd9e70000-0000-4000-8000-000000000502', null, 100),
  ('d9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000201', 'd9e70000-0000-4000-8000-000000000301', 'd9e70000-0000-4000-8000-000000000503', null, 100),
  ('d9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000201', 'd9e70000-0000-4000-8000-000000000301', 'd9e70000-0000-4000-8000-000000000504', null, 100),
  ('d9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000202', 'd9e70000-0000-4000-8000-000000000303', 'd9e70000-0000-4000-8000-000000000503', null, 100),
  ('d9e70000-0000-4000-8000-000000000001', 'd9e70000-0000-4000-8000-000000000101', 'd9e70000-0000-4000-8000-000000000202', 'd9e70000-0000-4000-8000-000000000303', 'd9e70000-0000-4000-8000-000000000504', null, 100);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('d9e70000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-r540@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e70000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-r540@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e70000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-r540@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e70000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-r540@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e70000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-r540@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('d9e70000-0000-4000-8000-000000000a01', 'NV54001', 'Thủ kho'),
  ('d9e70000-0000-4000-8000-000000000a02', 'NV54002', 'Bếp trưởng'),
  ('d9e70000-0000-4000-8000-000000000a03', 'NV54003', 'Cost Controller'),
  ('d9e70000-0000-4000-8000-000000000a04', 'NV54004', 'Tổng quản lý'),
  ('d9e70000-0000-4000-8000-000000000a06', 'NV54006', 'Kế toán')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;
update public.profiles
set pin_hash = extensions.crypt('1111', extensions.gen_salt('bf'))
where id = 'd9e70000-0000-4000-8000-000000000a01';
update public.profiles
set pin_hash = extensions.crypt('2222', extensions.gen_salt('bf'))
where id = 'd9e70000-0000-4000-8000-000000000a02';
insert into public.roles (id, org_id, code, name_vi) values
  ('d9e70000-0000-4000-8000-000000000601', 'd9e70000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d9e70000-0000-4000-8000-000000000602', 'd9e70000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('d9e70000-0000-4000-8000-000000000603', 'd9e70000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('d9e70000-0000-4000-8000-000000000604', 'd9e70000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d9e70000-0000-4000-8000-000000000606', 'd9e70000-0000-4000-8000-000000000001', 'accountant', 'Kế toán');
insert into public.role_permissions (role_id, permission_code) values
  ('d9e70000-0000-4000-8000-000000000601', 'count.open'),
  ('d9e70000-0000-4000-8000-000000000601', 'count.perform'),
  ('d9e70000-0000-4000-8000-000000000601', 'receiving.post'),
  ('d9e70000-0000-4000-8000-000000000601', 'requisition.issue'),
  ('d9e70000-0000-4000-8000-000000000601', 'stock.view_qty'),
  ('d9e70000-0000-4000-8000-000000000602', 'count.perform'),
  ('d9e70000-0000-4000-8000-000000000603', 'count.view_variance'),
  ('d9e70000-0000-4000-8000-000000000603', 'stock.view_qty'),
  ('d9e70000-0000-4000-8000-000000000603', 'stock.view_value'),
  ('d9e70000-0000-4000-8000-000000000604', 'count.adjust.approve'),
  ('d9e70000-0000-4000-8000-000000000604', 'stock.view_value'),
  ('d9e70000-0000-4000-8000-000000000606', 'count.lock');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d9e70000-0000-4000-8000-000000000a01', 'd9e70000-0000-4000-8000-000000000601', 'd9e70000-0000-4000-8000-000000000201'),
  ('d9e70000-0000-4000-8000-000000000a02', 'd9e70000-0000-4000-8000-000000000602', 'd9e70000-0000-4000-8000-000000000201'),
  ('d9e70000-0000-4000-8000-000000000a03', 'd9e70000-0000-4000-8000-000000000603', 'd9e70000-0000-4000-8000-000000000201'),
  ('d9e70000-0000-4000-8000-000000000a04', 'd9e70000-0000-4000-8000-000000000604', 'd9e70000-0000-4000-8000-000000000201'),
  ('d9e70000-0000-4000-8000-000000000a06', 'd9e70000-0000-4000-8000-000000000606', 'd9e70000-0000-4000-8000-000000000201'),
  ('d9e70000-0000-4000-8000-000000000a01', 'd9e70000-0000-4000-8000-000000000601', 'd9e70000-0000-4000-8000-000000000202'),
  ('d9e70000-0000-4000-8000-000000000a02', 'd9e70000-0000-4000-8000-000000000602', 'd9e70000-0000-4000-8000-000000000202'),
  ('d9e70000-0000-4000-8000-000000000a03', 'd9e70000-0000-4000-8000-000000000603', 'd9e70000-0000-4000-8000-000000000202'),
  ('d9e70000-0000-4000-8000-000000000a04', 'd9e70000-0000-4000-8000-000000000604', 'd9e70000-0000-4000-8000-000000000202'),
  ('d9e70000-0000-4000-8000-000000000a06', 'd9e70000-0000-4000-8000-000000000606', 'd9e70000-0000-4000-8000-000000000202');
create temp table r540_ctx (key text primary key, id uuid);
create temp table r540_resp (key text primary key, resp jsonb);
grant all on r540_ctx, r540_resp to authenticated;
create or replace function public._r540_as(p_user uuid)
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

-- ---------------------------------------------------------------------------
-- §0. Helper o muc ham (chay bang postgres, chua doi role)
-- ---------------------------------------------------------------------------
select is(
  public._count_without_cc_factor(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201'
  ),
  0.7::numeric, 'default without_cc factor is 0.7'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000501'
  ),
  1.5::numeric, 'liquor group threshold is 1.5'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000502'
  ),
  3::numeric, 'meat/fish group threshold is 3'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000503'
  ),
  5::numeric, 'vegetable group threshold is 5'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000504'
  ),
  5::numeric, 'unconfigured group falls back to common threshold 5'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000202',
    'd9e70000-0000-4000-8000-000000000503'
  ),
  3.5::numeric, 'without_cc vegetable threshold is 5 x 0.7 = 3.5'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000202',
    'd9e70000-0000-4000-8000-000000000504'
  ),
  3.5::numeric, 'without_cc unconfigured threshold is 5 x 0.7 = 3.5'
);
select throws_ok(
  $q$insert into public.item_groups (org_id, code_prefix, name, kind, recount_threshold_pct)
    values ('d9e70000-0000-4000-8000-000000000001', 'BAD', 'Nhóm sai', 'food', 101)$q$,
  '23514', null,
  'group threshold above 100 is rejected by CHECK'
);

-- ---------------------------------------------------------------------------
-- §1. with_cc — ruou 2% dem lai; thit 3% ok; rau 4% ok; do kho 4% ok
-- ---------------------------------------------------------------------------
set local role authenticated;
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('openD', public.count_open(
  'd9e70000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['d9e70000-0000-4000-8000-000000000a01', 'd9e70000-0000-4000-8000-000000000a02']::uuid[],
  'd9e70000-0000-4000-8000-00000000aa01'
));
select ok(
  (select (resp ->> 'ok')::boolean from r540_resp where key = 'openD'),
  'count D opens on WH1'
);
select is(
  (select (resp ->> 'lines_created')::int from r540_resp where key = 'openD'),
  4, 'WH1 snapshot creates 4 lines'
);
insert into r540_ctx values ('cntD', (select (resp ->> 'id')::uuid from r540_resp where key = 'openD'));
-- RUOU 980/980 (lech -20, 2% > 1,5%); THIT 97/97 (lech -3, 3% = 3%);
-- RAU 96/96 (lech -4, 4% <= 5%); KHO 96/96 (lech -4, 4% <= 5% chung).
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000501',
  '{"qty": 980, "uom": "ml"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000501',
  '{"qty": 980, "uom": "ml"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000502',
  '{"qty": 97, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000502',
  '{"qty": 97, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000503',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000503',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000504',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000504',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('submitD1', public.count_submit(
  (select id from r540_ctx where key = 'cntD'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from r540_resp where key = 'submitD1'),
  1, 'submitD1 flags 1 recount line (RUOU only)'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r540_resp where key = 'submitD1'),
  0, 'submitD1 flags 0 red lines'
);
select is(
  (select status from public.stock_counts where id = (select id from r540_ctx where key = 'cntD')),
  'recount', 'count D status is recount after submitD1'
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a03');
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntD')
     and item_code = 'ITM_RUOU'),
  'recount', 'RUOU line flag is recount (2% over 1.5%)'
);
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntD')
     and item_code = 'ITM_THIT'),
  'ok', 'THIT line flag is ok (3% equals 3%)'
);
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntD')
     and item_code = 'ITM_RAU'),
  'ok', 'RAU line flag is ok (4% within 5%)'
);
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntD')
     and item_code = 'ITM_KHO'),
  'ok', 'KHO line flag is ok (4% within common 5%)'
);
select is(
  (select variance_qty::numeric from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntD')
     and item_code = 'ITM_THIT'),
  -3::numeric, 'THIT variance_qty is still stored (-3)'
);
-- Vong 2: RUOU dem lai van 980/980 -> red.
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000501',
  '{"qty": 980, "uom": "ml"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntD'),
  'd9e70000-0000-4000-8000-000000000501',
  '{"qty": 980, "uom": "ml"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('submitD2', public.count_submit(
  (select id from r540_ctx where key = 'cntD'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r540_resp where key = 'submitD2'),
  1, 'submitD2 flags 1 red line (RUOU still over 1.5%)'
);
select is(
  (select status from public.stock_counts where id = (select id from r540_ctx where key = 'cntD')),
  'submitted', 'count D status is submitted after submitD2'
);

-- ---------------------------------------------------------------------------
-- §2. Ton so = 0 — dem 5 vs ton 0 -> dem lai; dem 0 vs ton 0 -> ok
-- ---------------------------------------------------------------------------
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('openE', public.count_open(
  'd9e70000-0000-4000-8000-000000000302', 'monthly_full', '2026-11-09', null,
  array['d9e70000-0000-4000-8000-000000000a01', 'd9e70000-0000-4000-8000-000000000a02']::uuid[],
  'd9e70000-0000-4000-8000-00000000aa02'
));
select ok(
  (select (resp ->> 'ok')::boolean from r540_resp where key = 'openE'),
  'count E opens on WH2 (no balances)'
);
select is(
  (select (resp ->> 'lines_created')::int from r540_resp where key = 'openE'),
  0, 'WH2 snapshot creates 0 lines'
);
insert into r540_ctx values ('cntE', (select (resp ->> 'id')::uuid from r540_resp where key = 'openE'));
-- RAU2 5/5 (ton 0 -> moi lech deu vuot); KHO2 0/0 (ton 0, lech 0 -> ok).
select public.count_record_line(
  (select id from r540_ctx where key = 'cntE'),
  'd9e70000-0000-4000-8000-000000000505',
  '{"qty": 5, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntE'),
  'd9e70000-0000-4000-8000-000000000505',
  '{"qty": 5, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntE'),
  'd9e70000-0000-4000-8000-000000000506',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntE'),
  'd9e70000-0000-4000-8000-000000000506',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('submitE1', public.count_submit(
  (select id from r540_ctx where key = 'cntE'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from r540_resp where key = 'submitE1'),
  1, 'submitE1 flags 1 recount line (RAU2 counted 5 vs book 0)'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r540_resp where key = 'submitE1'),
  0, 'submitE1 flags 0 red lines'
);
select is(
  (select status from public.stock_counts where id = (select id from r540_ctx where key = 'cntE')),
  'recount', 'count E status is recount after submitE1'
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a03');
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntE')
     and item_code = 'ITM_RAU2'),
  'recount', 'RAU2 line flag is recount (5 vs book 0)'
);
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntE')
     and item_code = 'ITM_KHO2'),
  'ok', 'KHO2 line flag is ok (0 vs book 0)'
);
-- Vong 2: RAU2 dem lai van 5/5 -> red.
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntE'),
  'd9e70000-0000-4000-8000-000000000505',
  '{"qty": 5, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntE'),
  'd9e70000-0000-4000-8000-000000000505',
  '{"qty": 5, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('submitE2', public.count_submit(
  (select id from r540_ctx where key = 'cntE'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r540_resp where key = 'submitE2'),
  1, 'submitE2 flags 1 red line (RAU2 still 5 vs book 0)'
);
select is(
  (select status from public.stock_counts where id = (select id from r540_ctx where key = 'cntE')),
  'submitted', 'count E status is submitted after submitE2'
);

-- ---------------------------------------------------------------------------
-- §3. without_cc — rau 4% dem lai (vuot 3,5%); do kho 3% ok (<= 3,5%)
-- ---------------------------------------------------------------------------
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('openF', public.count_open(
  'd9e70000-0000-4000-8000-000000000303', 'monthly_full', '2026-11-09', null,
  array['d9e70000-0000-4000-8000-000000000a01', 'd9e70000-0000-4000-8000-000000000a02']::uuid[],
  'd9e70000-0000-4000-8000-00000000aa03'
));
select ok(
  (select (resp ->> 'ok')::boolean from r540_resp where key = 'openF'),
  'count F opens on WH3 (without_cc)'
);
select is(
  (select (resp ->> 'lines_created')::int from r540_resp where key = 'openF'),
  2, 'WH3 snapshot creates 2 lines'
);
insert into r540_ctx values ('cntF', (select (resp ->> 'id')::uuid from r540_resp where key = 'openF'));
select public.count_record_line(
  (select id from r540_ctx where key = 'cntF'),
  'd9e70000-0000-4000-8000-000000000503',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntF'),
  'd9e70000-0000-4000-8000-000000000503',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntF'),
  'd9e70000-0000-4000-8000-000000000504',
  '{"qty": 97, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntF'),
  'd9e70000-0000-4000-8000-000000000504',
  '{"qty": 97, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('submitF1', public.count_submit(
  (select id from r540_ctx where key = 'cntF'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from r540_resp where key = 'submitF1'),
  1, 'submitF1 flags 1 recount line (RAU only)'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r540_resp where key = 'submitF1'),
  0, 'submitF1 flags 0 red lines'
);
select is(
  (select status from public.stock_counts where id = (select id from r540_ctx where key = 'cntF')),
  'recount', 'count F status is recount after submitF1'
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a03');
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntF')
     and item_code = 'ITM_RAU'),
  'recount', 'RAU line flag is recount (4% over 3.5%)'
);
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r540_ctx where key = 'cntF')
     and item_code = 'ITM_KHO'),
  'ok', 'KHO line flag is ok (3% within 3.5%)'
);
-- Vong 2: RAU dem lai van 96/96 -> red.
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntF'),
  'd9e70000-0000-4000-8000-000000000503',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r540_ctx where key = 'cntF'),
  'd9e70000-0000-4000-8000-000000000503',
  '{"qty": 96, "uom": "kg"}'::jsonb
);
select public._r540_as('d9e70000-0000-4000-8000-000000000a01');
insert into r540_resp values ('submitF2', public.count_submit(
  (select id from r540_ctx where key = 'cntF'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r540_resp where key = 'submitF2'),
  1, 'submitF2 flags 1 red line (RAU still over 3.5%)'
);
select is(
  (select status from public.stock_counts where id = (select id from r540_ctx where key = 'cntF')),
  'submitted', 'count F status is submitted after submitF2'
);

-- ---------------------------------------------------------------------------
-- §4. Nguong chung / he so doi duoc qua settings; nguong nhom thang
--   nguong chung. Ghi settings chay bang postgres (reset role) vi
--   _setting_get bi revoke doi voi authenticated.
-- ---------------------------------------------------------------------------
reset role;
insert into public.settings (org_id, property_id, key, value)
values ('d9e70000-0000-4000-8000-000000000001', null, 'count_recount_threshold_pct', '100'::jsonb);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000504'
  ),
  100::numeric, 'unconfigured group follows configured common threshold 100'
);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000503'
  ),
  5::numeric, 'group threshold beats configured common threshold 100'
);
insert into public.settings (org_id, property_id, key, value)
values ('d9e70000-0000-4000-8000-000000000001', null, 'count_without_cc_factor', '0.5'::jsonb);
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000202',
    'd9e70000-0000-4000-8000-000000000503'
  ),
  2.5::numeric, 'without_cc vegetable threshold is 5 x 0.5 = 2.5'
);
delete from public.settings
where org_id = 'd9e70000-0000-4000-8000-000000000001'
  and key in ('count_recount_threshold_pct', 'count_without_cc_factor');
select is(
  public._count_line_threshold_pct(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201',
    'd9e70000-0000-4000-8000-000000000504'
  ),
  5::numeric, 'threshold falls back to default 5 after the settings rows are removed'
);
select is(
  public._count_without_cc_factor(
    'd9e70000-0000-4000-8000-000000000001',
    'd9e70000-0000-4000-8000-000000000201'
  ),
  0.7::numeric, 'factor falls back to default 0.7 after the settings row is removed'
);
select finish();
rollback;
