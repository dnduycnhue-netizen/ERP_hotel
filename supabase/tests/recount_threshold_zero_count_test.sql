-- ============================================================================
-- R26 + R30 (Q215) — pgTAP cho nguong dem lai theo % va dem so 0.
--   R26: count_submit dung nguong lech % cau hinh
--     (settings count_recount_threshold_pct, mac dinh 5). Dong khop khi
--     2 nguoi dem bang nhau VA |lech| <= nguong % cua ton so; ton so = 0
--     thi moi lech khac 0 deu vuot nguong; variance_qty van luu dung.
--   R30: cho phep ghi so luong 0 khi dem (chi tu choi < 0).
-- GIA DINH: test chay TREN code chua noi R25 (task co 537000 chua merge),
--   nen count_submit van can du PIN ca 2 nguoi dem. Neu 537000 da merge
--   truoc thi cac lan submit van dung duoc vi du PIN khong lam sai test.
--   R20 (dem mu) KHONG test o day: khong dong nao doc so so qua kenh
--   khong phai variance viewer; cac lan doc dong deu dung a03
--   (co count.view_variance) vi RLS stock_count_lines_select chan
--   nguoi khong co quyen nay (bai hoc T-032, attempt 4/5).
-- Chay trong 1 transaction begin...rollback; chi chay file nay.
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(39);

-- ---------------------------------------------------------------------------
-- §0. Fixture
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d9e60000-0000-4000-8000-000000000001', 'R26/R30 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('d9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000001', 'R538', 'Entity R538');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'P538', 'Property R538', 'with_cc');
insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái'),
  ('ml', 'Mililít')
on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d9e60000-0000-4000-8000-000000000401', 'd9e60000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d9e60000-0000-4000-8000-000000000402', 'd9e60000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food'),
  ('d9e60000-0000-4000-8000-000000000403', 'd9e60000-0000-4000-8000-000000000001', 'MUOI', 'Muối', 'other'),
  ('d9e60000-0000-4000-8000-000000000404', 'd9e60000-0000-4000-8000-000000000001', 'RUUOU', 'Rượu', 'beverage');
insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, tare_g, density_g_ml) values
  ('d9e60000-0000-4000-8000-000000000501', 'd9e60000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd9e60000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market'], null, null),
  ('d9e60000-0000-4000-8000-000000000502', 'd9e60000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd9e60000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract'], null, null),
  ('d9e60000-0000-4000-8000-000000000503', 'd9e60000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd9e60000-0000-4000-8000-000000000403', 'kg', false, false, null, array['contract', 'market'], null, null),
  ('d9e60000-0000-4000-8000-000000000504', 'd9e60000-0000-4000-8000-000000000001', 'ITM_RUUOU', 'Rượu gạo', 'd9e60000-0000-4000-8000-000000000404', 'ml', false, false, null, array['contract'], 450, 0.95);
insert into public.outlet_types (id, org_id, code, name) values
  ('d9e60000-0000-4000-8000-000000000801', 'd9e60000-0000-4000-8000-000000000001', 'KIT', 'Bếp');
insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d9e60000-0000-4000-8000-000000000802', 'd9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000801', 'KITCHEN', 'Bếp chính');
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d9e60000-0000-4000-8000-000000000301', 'd9e60000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d9e60000-0000-4000-8000-000000000302', 'd9e60000-0000-4000-8000-000000000201', 'WH_KIT', 'Kho bếp', 'outlet', 'd9e60000-0000-4000-8000-000000000802');
insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, qty) values
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000301', 'd9e60000-0000-4000-8000-000000000501', null, 100),
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000301', 'd9e60000-0000-4000-8000-000000000503', null, 50),
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000301', 'd9e60000-0000-4000-8000-000000000504', null, 7000),
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000302', 'd9e60000-0000-4000-8000-000000000501', null, 10),
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000201', 'd9e60000-0000-4000-8000-000000000302', 'd9e60000-0000-4000-8000-000000000503', null, 5);
insert into public.item_costs (legal_entity_id, org_id, item_id, avg_cost, qty_on_hand) values
  ('d9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000501', 10000, 110),
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000503', 5000, 55),
  ('d9e60000-0000-4000-8000-000000000001', 'd9e60000-0000-4000-8000-000000000101', 'd9e60000-0000-4000-8000-000000000504', 20, 7000);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('d9e60000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-r538@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e60000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-r538@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e60000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-r538@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e60000-0000-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u4-r538@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e60000-0000-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u6-r538@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('d9e60000-0000-4000-8000-000000000a01', 'NV53801', 'Thủ kho'),
  ('d9e60000-0000-4000-8000-000000000a02', 'NV53802', 'Bếp trưởng'),
  ('d9e60000-0000-4000-8000-000000000a03', 'NV53803', 'Cost Controller'),
  ('d9e60000-0000-4000-8000-000000000a04', 'NV53804', 'Tổng quản lý'),
  ('d9e60000-0000-4000-8000-000000000a06', 'NV53806', 'Kế toán')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;
update public.profiles
set pin_hash = extensions.crypt('1111', extensions.gen_salt('bf'))
where id = 'd9e60000-0000-4000-8000-000000000a01';
update public.profiles
set pin_hash = extensions.crypt('2222', extensions.gen_salt('bf'))
where id = 'd9e60000-0000-4000-8000-000000000a02';
insert into public.roles (id, org_id, code, name_vi) values
  ('d9e60000-0000-4000-8000-000000000601', 'd9e60000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d9e60000-0000-4000-8000-000000000602', 'd9e60000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('d9e60000-0000-4000-8000-000000000603', 'd9e60000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('d9e60000-0000-4000-8000-000000000604', 'd9e60000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý'),
  ('d9e60000-0000-4000-8000-000000000606', 'd9e60000-0000-4000-8000-000000000001', 'accountant', 'Kế toán');
insert into public.role_permissions (role_id, permission_code) values
  ('d9e60000-0000-4000-8000-000000000601', 'count.open'),
  ('d9e60000-0000-4000-8000-000000000601', 'count.perform'),
  ('d9e60000-0000-4000-8000-000000000601', 'receiving.post'),
  ('d9e60000-0000-4000-8000-000000000601', 'requisition.issue'),
  ('d9e60000-0000-4000-8000-000000000601', 'stock.view_qty'),
  ('d9e60000-0000-4000-8000-000000000602', 'count.perform'),
  ('d9e60000-0000-4000-8000-000000000603', 'count.view_variance'),
  ('d9e60000-0000-4000-8000-000000000603', 'stock.view_qty'),
  ('d9e60000-0000-4000-8000-000000000603', 'stock.view_value'),
  ('d9e60000-0000-4000-8000-000000000604', 'count.adjust.approve'),
  ('d9e60000-0000-4000-8000-000000000604', 'stock.view_value'),
  ('d9e60000-0000-4000-8000-000000000606', 'count.lock');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d9e60000-0000-4000-8000-000000000a01', 'd9e60000-0000-4000-8000-000000000601', 'd9e60000-0000-4000-8000-000000000201'),
  ('d9e60000-0000-4000-8000-000000000a02', 'd9e60000-0000-4000-8000-000000000602', 'd9e60000-0000-4000-8000-000000000201'),
  ('d9e60000-0000-4000-8000-000000000a03', 'd9e60000-0000-4000-8000-000000000603', 'd9e60000-0000-4000-8000-000000000201'),
  ('d9e60000-0000-4000-8000-000000000a04', 'd9e60000-0000-4000-8000-000000000604', 'd9e60000-0000-4000-8000-000000000201'),
  ('d9e60000-0000-4000-8000-000000000a06', 'd9e60000-0000-4000-8000-000000000606', 'd9e60000-0000-4000-8000-000000000201');
create temp table r538_ctx (key text primary key, id uuid);
create temp table r538_resp (key text primary key, resp jsonb);
grant all on r538_ctx, r538_resp to authenticated;
create or replace function public._r538_as(p_user uuid)
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
-- §0. R26/R30 o muc ham phu (chay bang postgres, chua doi role)
-- ---------------------------------------------------------------------------
select is(
  public._count_recount_threshold_pct(
    'd9e60000-0000-4000-8000-000000000001',
    'd9e60000-0000-4000-8000-000000000201'
  ),
  5::numeric, 'default recount threshold is 5'
);
select is(
  public._count_qty_from_detail(
    'd9e60000-0000-4000-8000-000000000501',
    '{"qty": 0, "uom": "kg"}'::jsonb
  ),
  0::numeric, 'zero qty converts to 0'
);
select is(
  public._count_bottle_qty(
    'd9e60000-0000-4000-8000-000000000504',
    450
  ),
  0::numeric, 'bottle at tare weight converts to 0 ml'
);
select throws_ok(
  $q$select public._count_qty_from_detail(
    'd9e60000-0000-4000-8000-000000000501',
    '{"qty": -1, "uom": "kg"}'::jsonb
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'negative qty is still rejected'
);
select throws_ok(
  $q$select public._count_bottle_qty(
    'd9e60000-0000-4000-8000-000000000504',
    100
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'bottle below tare weight is still rejected'
);

-- ---------------------------------------------------------------------------
-- §1. R26 — cntA tren MAIN: lech trong nguong thi khop, vuot thi dem lai
-- ---------------------------------------------------------------------------
set local role authenticated;
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('openA', public.count_open(
  'd9e60000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['d9e60000-0000-4000-8000-000000000a01', 'd9e60000-0000-4000-8000-000000000a02']::uuid[],
  'd9e60000-0000-4000-8000-00000000aa01'
));
select ok(
  (select (resp ->> 'ok')::boolean from r538_resp where key = 'openA'),
  'count_open succeeds for MAIN warehouse'
);
select is(
  (select (resp ->> 'lines_created')::int from r538_resp where key = 'openA'),
  3, 'snapshot creates 3 lines'
);
insert into r538_ctx values ('cntA', (select (resp ->> 'id')::uuid from r538_resp where key = 'openA'));
-- GAO 98/98 (lech -2, 2% <= 5% -> khop); MUOI 50/50 (khop); RUUOU 500/500 (lech -6500, ~93% -> dem lai).
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 98, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 98, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('rec_ruou1', public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000504',
  null, 925
));
select is(
  (select (resp ->> 'counted_qty')::numeric from r538_resp where key = 'rec_ruou1'),
  500::numeric, 'bottle 925g converts to 500 ml'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('submit1', public.count_submit(
  (select id from r538_ctx where key = 'cntA'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from r538_resp where key = 'submit1'),
  1, 'submit1 flags 1 recount line (RUUOU only)'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r538_resp where key = 'submit1'),
  0, 'submit1 flags 0 red lines'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a03');
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r538_ctx where key = 'cntA')
     and item_code = 'ITM_GAO'),
  'ok', 'GAO line flag is ok (2% within threshold)'
);
select is(
  (select variance_qty::numeric from public.v_count_result
   where count_id = (select id from r538_ctx where key = 'cntA')
     and item_code = 'ITM_GAO'),
  -2::numeric, 'GAO variance_qty is still stored (-2)'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select is(
  (select status from public.stock_counts where id = (select id from r538_ctx where key = 'cntA')),
  'recount', 'count status is recount after submit1'
);
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntA'),
  'd9e60000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('submit2', public.count_submit(
  (select id from r538_ctx where key = 'cntA'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r538_resp where key = 'submit2'),
  1, 'submit2 flags 1 red line (RUUOU still over threshold)'
);
select is(
  (select status from public.stock_counts where id = (select id from r538_ctx where key = 'cntA')),
  'submitted', 'count status is submitted after submit2'
);

-- ---------------------------------------------------------------------------
-- §1c. Khoa + dieu chinh cntA de giai phong kho MAIN cho §3
--   (mang ly do dung truoc bang a03: chi nguoi co count.view_variance
--   moi doc truc tiep duoc stock_count_lines — bai hoc T-032.)
-- ---------------------------------------------------------------------------
select public._r538_as('d9e60000-0000-4000-8000-000000000a03');
insert into r538_resp values ('lockA_reasons', jsonb_build_array(
  jsonb_build_object(
    'line_id', (select id from public.stock_count_lines
       where count_id = (select id from r538_ctx where key = 'cntA')
         and item_id = 'd9e60000-0000-4000-8000-000000000504'),
    'reason_code', 'lost',
    'explanation', 'test'
  )
));
select public._r538_as('d9e60000-0000-4000-8000-000000000a06');
select ok(
  (select (resp ->> 'ok')::boolean from (
    select public.count_lock(
      (select id from r538_ctx where key = 'cntA'),
      (select resp from r538_resp where key = 'lockA_reasons')
    ) as resp
  ) s),
  'count_lock succeeds with a valid reason'
);
select is(
  (select status from public.stock_counts where id = (select id from r538_ctx where key = 'cntA')),
  'locked', 'count status is locked'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a04');
insert into r538_resp values ('adjA', public.count_adjust_post((select id from r538_ctx where key = 'cntA')));
select ok(
  (select (resp ->> 'ok')::boolean from r538_resp where key = 'adjA'),
  'count_adjust_post succeeds'
);
select is(
  (select (resp ->> 'moves_posted')::int from r538_resp where key = 'adjA'),
  2, 'two adjustment moves are posted (GAO + RUUOU)'
);
select is(
  (select (resp ->> 'total_value')::numeric from r538_resp where key = 'adjA'),
  -150000::numeric, 'total adjustment value is -150000 (-20000 GAO + -130000 RUUOU)'
);

-- ---------------------------------------------------------------------------
-- §2. R30 — cntB tren KIT: dem 0 ca 2 vong; mon khong co ton dem 0
-- ---------------------------------------------------------------------------
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('openB', public.count_open(
  'd9e60000-0000-4000-8000-000000000302', 'monthly_full', '2026-11-09', null,
  array['d9e60000-0000-4000-8000-000000000a01', 'd9e60000-0000-4000-8000-000000000a02']::uuid[],
  'd9e60000-0000-4000-8000-00000000aa02'
));
select ok(
  (select (resp ->> 'ok')::boolean from r538_resp where key = 'openB'),
  'monthly count B opens on KIT'
);
select is(
  (select (resp ->> 'lines_created')::int from r538_resp where key = 'openB'),
  2, 'KIT snapshot creates 2 lines (THIT has no balance)'
);
insert into r538_ctx values ('cntB', (select (resp ->> 'id')::uuid from r538_resp where key = 'openB'));
-- GAO 0/0 (ton 10 -> lech -10); MUOI 5/5 (khop); THIT 0/0 (khong co ton -> dong moi, ton 0).
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000503',
  '{"qty": 5, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000503',
  '{"qty": 5, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000502',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000502',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('submitB1', public.count_submit(
  (select id from r538_ctx where key = 'cntB'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from r538_resp where key = 'submitB1'),
  1, 'submitB1 flags 1 recount line (GAO zero vs book 10)'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r538_resp where key = 'submitB1'),
  0, 'submitB1 flags 0 red lines'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a03');
select is(
  (select flag from public.v_count_result
   where count_id = (select id from r538_ctx where key = 'cntB')
     and item_code = 'ITM_THIT'),
  'ok', 'THIT line flag is ok (0 counted vs 0 book)'
);
select is(
  (select variance_qty::numeric from public.v_count_result
   where count_id = (select id from r538_ctx where key = 'cntB')
     and item_code = 'ITM_THIT'),
  0::numeric, 'THIT variance_qty is 0 (0 - 0)'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntB'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 0, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('submitB2', public.count_submit(
  (select id from r538_ctx where key = 'cntB'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r538_resp where key = 'submitB2'),
  1, 'submitB2 flags 1 red line (GAO zero vs book 10)'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a03');
select is(
  (select variance_qty::numeric from public.v_count_result
   where count_id = (select id from r538_ctx where key = 'cntB')
     and item_code = 'ITM_GAO'),
  -10::numeric, 'GAO variance is 0 - 10 = -10'
);
insert into r538_resp values ('lockB_reasons', jsonb_build_array(
  jsonb_build_object(
    'line_id', (select id from public.stock_count_lines
       where count_id = (select id from r538_ctx where key = 'cntB')
         and item_id = 'd9e60000-0000-4000-8000-000000000501'),
    'reason_code', 'lost',
    'explanation', 'test'
  )
));
select public._r538_as('d9e60000-0000-4000-8000-000000000a06');
select ok(
  (select (resp ->> 'ok')::boolean from (
    select public.count_lock(
      (select id from r538_ctx where key = 'cntB'),
      (select resp from r538_resp where key = 'lockB_reasons')
    ) as resp
  ) s),
  'count_lock succeeds for count B'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a04');
insert into r538_resp values ('adjB', public.count_adjust_post((select id from r538_ctx where key = 'cntB')));
select is(
  (select (resp ->> 'moves_posted')::int from r538_resp where key = 'adjB'),
  1, 'one adjustment move is posted (GAO only)'
);
select is(
  (select (resp ->> 'total_value')::numeric from r538_resp where key = 'adjB'),
  -100000::numeric, 'total adjustment value is -100000 (GAO -10 x 10000)'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select is(
  (select qty::numeric from public.stock_balances
   where warehouse_id = 'd9e60000-0000-4000-8000-000000000302'
     and item_id = 'd9e60000-0000-4000-8000-000000000501'),
  0::numeric, 'KIT GAO balance is 0 after adjustment'
);

-- ---------------------------------------------------------------------------
-- §3. R26 — nguong cau hinh duoc: dat 100 thi lech 50% cung khop.
--   Doc helper + ghi settings chay bang postgres (reset role) vi
--   _setting_get bi revoke doi voi authenticated.
-- ---------------------------------------------------------------------------
reset role;
insert into public.settings (org_id, property_id, key, value)
values ('d9e60000-0000-4000-8000-000000000001', null, 'count_recount_threshold_pct', '100'::jsonb);
select is(
  public._count_recount_threshold_pct(
    'd9e60000-0000-4000-8000-000000000001',
    'd9e60000-0000-4000-8000-000000000201'
  ),
  100::numeric, 'configured recount threshold reads back as 100'
);
set local role authenticated;
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('openC', public.count_open(
  'd9e60000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['d9e60000-0000-4000-8000-000000000a01', 'd9e60000-0000-4000-8000-000000000a02']::uuid[],
  'd9e60000-0000-4000-8000-00000000aa03'
));
select ok(
  (select (resp ->> 'ok')::boolean from r538_resp where key = 'openC'),
  'monthly count C opens on MAIN'
);
insert into r538_ctx values ('cntC', (select (resp ->> 'id')::uuid from r538_resp where key = 'openC'));
-- MAIN sau §1c: GAO 98, MUOI 50, RUUOU 500. Dem GAO 49/49 (lech -49, 50% <= 100% -> khop).
select public.count_record_line(
  (select id from r538_ctx where key = 'cntC'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 49, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntC'),
  'd9e60000-0000-4000-8000-000000000501',
  '{"qty": 49, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntC'),
  'd9e60000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntC'),
  'd9e60000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntC'),
  'd9e60000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from r538_ctx where key = 'cntC'),
  'd9e60000-0000-4000-8000-000000000504',
  '{"qty": 500, "uom": "ml"}'::jsonb
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a01');
insert into r538_resp values ('submitC1', public.count_submit(
  (select id from r538_ctx where key = 'cntC'),
  array['1111', '2222']
));
select is(
  (select jsonb_array_length(resp -> 'recount_line_ids') from r538_resp where key = 'submitC1'),
  0, 'submitC1 flags 0 recount lines at threshold 100'
);
select is(
  (select jsonb_array_length(resp -> 'red_line_ids') from r538_resp where key = 'submitC1'),
  0, 'submitC1 flags 0 red lines at threshold 100'
);
select is(
  (select status from public.stock_counts where id = (select id from r538_ctx where key = 'cntC')),
  'submitted', 'count status is submitted after submitC1'
);
select public._r538_as('d9e60000-0000-4000-8000-000000000a03');
select is(
  (select variance_qty::numeric from public.v_count_result
   where count_id = (select id from r538_ctx where key = 'cntC')
     and item_code = 'ITM_GAO'),
  -49::numeric, 'GAO variance_qty is still stored (-49) when within threshold'
);
reset role;
delete from public.settings
where org_id = 'd9e60000-0000-4000-8000-000000000001'
  and key = 'count_recount_threshold_pct';
select is(
  public._count_recount_threshold_pct(
    'd9e60000-0000-4000-8000-000000000001',
    'd9e60000-0000-4000-8000-000000000201'
  ),
  5::numeric, 'threshold falls back to default 5 after the settings row is removed'
);
select finish();
rollback;
