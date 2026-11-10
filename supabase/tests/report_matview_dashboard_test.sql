-- C10 pgTAP: materialized view the kho (RPT_STOCK_CARD) + 1 RPC dashboard.
-- Kiem tra: MV ton tai + tong hop khop stock_moves, report_get doc tu MV
-- (so lieu giong het ban goc), tinh "cu" cua MV (chen move moi chua lam
-- moi thi bao cao khong doi; lam moi xong moi doi), quyen refresh
-- (report.view.rpt_stock_card), duong cron (khong JWT) van lam moi duoc,
-- property_dashboard_overview tra dung payload trang tong quan + tai hien
-- dung policy RLS cu (khong item.view -> items/groups = 0; gioi han kho
-- theo my_warehouse_ids; khong truy cap KS -> ERR_FORBIDDEN).
-- Du lieu mau: KS P1, ky 2026-11-09..2026-11-10.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(32);

-- ---------------------------------------------------------------------------
-- 0. Bang tam luu ket qua + helper doc so (theo mau T-044).
-- ---------------------------------------------------------------------------
create temp table c10_resp (key text primary key, resp jsonb);
grant all on c10_resp to authenticated;

create or replace function public._c10_as(p_user uuid)
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

create or replace function public._c10_num(p_key text, p_match_key text, p_match_val text, p_field text)
returns numeric
language sql stable
as $$
  select (r ->> p_field)::numeric
  from jsonb_array_elements((select resp->'rows' from c10_resp where key = p_key)) r
  where r ->> p_match_key = p_match_val;
$$;

create or replace function public._c10_total(p_key text, p_field text)
returns numeric
language sql stable
as $$
  select (resp->'totals'->>p_field)::numeric from c10_resp where key = p_key;
$$;

create or replace function public._c10_rows(p_key text)
returns bigint
language sql stable
as $$
  select jsonb_array_length(resp->'rows') from c10_resp where key = p_key;
$$;

-- ---------------------------------------------------------------------------
-- 0b. Fixture: master data + nguoi dung + quyen.
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('c1000000-0000-4000-8000-000000000001', 'C10 Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000001', 'TC10', 'Entity C10');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile, rooms_count) values
  ('c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'P1', 'Property C10', 'with_cc', 10);

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'),
  ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('c1000000-0000-4000-8000-000000000401', 'c1000000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('c1000000-0000-4000-8000-000000000402', 'c1000000-0000-4000-8000-000000000001', 'THIT', 'Thịt', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('c1000000-0000-4000-8000-000000000501', 'c1000000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'c1000000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market'], false),
  ('c1000000-0000-4000-8000-000000000502', 'c1000000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'c1000000-0000-4000-8000-000000000402', 'kg', true, true, 30, array['contract'], false);

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('c1000000-0000-4000-8000-000000000301', 'c1000000-0000-4000-8000-000000000201', 'WH1', 'Kho 1', 'main', null),
  ('c1000000-0000-4000-8000-000000000302', 'c1000000-0000-4000-8000-000000000201', 'WH2', 'Kho 2', 'main', null);

insert into public.lots (id, org_id, property_id, item_id, lot_no, expiry_date) values
  ('c1000000-0000-4000-8000-000000000906', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000502', 'LOT-THIT-001', '2027-01-01');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('c1000000-0000-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3-cc10@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u5-own10@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a07', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u7-wh10@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('c1000000-0000-4000-8000-000000000a09', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u9-no10@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('c1000000-0000-4000-8000-000000000a03', 'NV1003', 'Cost Controller'),
  ('c1000000-0000-4000-8000-000000000a05', 'NV1005', 'Chủ đầu tư'),
  ('c1000000-0000-4000-8000-000000000a07', 'NV1007', 'Thủ kho kho 1'),
  ('c1000000-0000-4000-8000-000000000a09', 'NV1009', 'Không quyền')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('c1000000-0000-4000-8000-000000000603', 'c1000000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('c1000000-0000-4000-8000-000000000605', 'c1000000-0000-4000-8000-000000000001', 'owner', 'Chủ đầu tư'),
  ('c1000000-0000-4000-8000-000000000607', 'c1000000-0000-4000-8000-000000000001', 'receiver', 'Nhân viên nhận hàng');

insert into public.role_permissions (role_id, permission_code) values
  ('c1000000-0000-4000-8000-000000000605', 'report.view.rpt_stock_card'),
  ('c1000000-0000-4000-8000-000000000605', 'item.view'),
  ('c1000000-0000-4000-8000-000000000603', 'report.view.rpt_opex'),
  ('c1000000-0000-4000-8000-000000000607', 'item.view'),
  ('c1000000-0000-4000-8000-000000000607', 'report.view.rpt_stock_card');

insert into public.user_property_roles (user_id, role_id, property_id, warehouse_ids) values
  ('c1000000-0000-4000-8000-000000000a03', 'c1000000-0000-4000-8000-000000000603', 'c1000000-0000-4000-8000-000000000201', null),
  ('c1000000-0000-4000-8000-000000000a05', 'c1000000-0000-4000-8000-000000000605', null, null),
  ('c1000000-0000-4000-8000-000000000a07', 'c1000000-0000-4000-8000-000000000607', 'c1000000-0000-4000-8000-000000000201', array['c1000000-0000-4000-8000-000000000301'::uuid]);

-- Bat bypass cho stock_moves de chen fixture truc tiep.
do $$
begin
  perform set_config('app.inventory_guard_bypass', 'on', true);
end $$;

-- stock_moves: GAO ton dau 11-08 (100) + nhap 50 / xuat 20 ngay 11-09;
-- THIT lo L1 nhap 10 ngay 11-09; THIT khong lo xuat 4 ngay 11-10.
insert into public.stock_moves (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id, cost_center_id, expense_category_id, purpose_code) values
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000301', 'c1000000-0000-4000-8000-000000000501', null, 'receipt', 100, 10000, 1000000, '2026-11-08', 'c1000000-0000-4000-8000-000000000a05', 'opening', 'c1000000-0000-4000-8000-000000000f01', null, null, null),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000301', 'c1000000-0000-4000-8000-000000000501', null, 'receipt', 50, 10000, 500000, '2026-11-09', 'c1000000-0000-4000-8000-000000000a05', 'opening', 'c1000000-0000-4000-8000-000000000f01', null, null, null),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000301', 'c1000000-0000-4000-8000-000000000501', null, 'purpose_issue', -20, 10000, -200000, '2026-11-09', 'c1000000-0000-4000-8000-000000000a05', 'purpose_issue', 'c1000000-0000-4000-8000-000000000f02', null, null, 'kitchen'),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000302', 'c1000000-0000-4000-8000-000000000502', 'c1000000-0000-4000-8000-000000000906', 'receipt', 10, 30000, 300000, '2026-11-09', 'c1000000-0000-4000-8000-000000000a05', 'opening', 'c1000000-0000-4000-8000-000000000f01', null, null, null),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000302', 'c1000000-0000-4000-8000-000000000502', null, 'purpose_issue', -4, 30000, -120000, '2026-11-10', 'c1000000-0000-4000-8000-000000000a05', 'purpose_issue', 'c1000000-0000-4000-8000-000000000f03', null, null, 'kitchen');

-- ---------------------------------------------------------------------------
-- A. MV ton tai + lam moi duong cron (role authenticated, chua set JWT).
-- ---------------------------------------------------------------------------
set local role authenticated;

select is(
  (select count(*) from pg_matviews where schemaname = 'public' and matviewname = 'mv_report_stock_card_daily'),
  1::bigint, 'mv_report_stock_card_daily exists'
);
select is(
  (select count(*) from pg_indexes where schemaname = 'public' and indexname = 'mv_report_stock_card_daily_property_date_idx'),
  1::bigint, 'MV has index on (property_id, business_date)'
);

insert into c10_resp (key, resp)
select 'refresh_cron', public.report_refresh_stock_card_mv();

select ok(
  (select (resp->>'ok')::boolean from c10_resp where key = 'refresh_cron'),
  'cron-path refresh (no JWT) succeeds'
);
select is(
  (select (resp->>'row_count')::bigint from c10_resp where key = 'refresh_cron'),
  4::bigint, 'MV has 4 daily rows after refresh'
);
select is(
  (select sum(qty) from public.mv_report_stock_card_daily),
  136::numeric, 'MV total qty equals stock_moves total qty'
);
select is(
  (select sum(amount) from public.mv_report_stock_card_daily),
  1480000::numeric, 'MV total amount equals stock_moves total amount'
);

-- ---------------------------------------------------------------------------
-- B. report_get RPT_STOCK_CARD doc tu MV — so lieu giong het ban goc.
-- ---------------------------------------------------------------------------
select public._c10_as('c1000000-0000-4000-8000-000000000a05');
insert into c10_resp (key, resp)
select 'stock_card', public.report_get('c1000000-0000-4000-8000-000000000201', 'RPT_STOCK_CARD',
  '{"from": "2026-11-09", "to": "2026-11-10"}'::jsonb);

select is(public._c10_rows('stock_card'), 3::bigint, 'stock card has 3 rows');
select is(public._c10_num('stock_card', 'item_code', 'ITM_GAO', 'closing_qty'), 130::numeric, 'GAO closing qty 130');
select is(public._c10_num('stock_card', 'item_code', 'ITM_GAO', 'closing_value'), 1300000::numeric, 'GAO closing value 1.300.000');
select is(
  (select (r->>'closing_qty')::numeric
   from jsonb_array_elements((select resp->'rows' from c10_resp where key = 'stock_card')) r
   where r->>'item_code' = 'ITM_THIT' and r->>'lot_no' = 'LOT-THIT-001'),
  10::numeric, 'THIT lot closing qty 10'
);
select is(public._c10_total('stock_card', 'closing_value'), 1480000::numeric, 'stock card total closing value 1.480.000');
select ok(
  (select exists (
     select 1 from jsonb_array_elements(resp->'notes') n
     where n::text like '%materialized view%')
   from c10_resp where key = 'stock_card'),
  'stock card notes mention MV freshness'
);

-- ---------------------------------------------------------------------------
-- C. Tinh "cu" cua MV: chen move moi -> bao cao chua doi; lam moi -> doi.
-- ---------------------------------------------------------------------------
reset role;
insert into public.stock_moves (org_id, legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty, unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id, cost_center_id, expense_category_id, purpose_code) values
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000101', 'c1000000-0000-4000-8000-000000000201', 'c1000000-0000-4000-8000-000000000301', 'c1000000-0000-4000-8000-000000000501', null, 'receipt', 10, 10000, 100000, '2026-11-10', 'c1000000-0000-4000-8000-000000000a05', 'opening', 'c1000000-0000-4000-8000-000000000f01', null, null, null);

select public._c10_as('c1000000-0000-4000-8000-000000000a05');
set local role authenticated;
insert into c10_resp (key, resp)
select 'stock_card_stale', public.report_get('c1000000-0000-4000-8000-000000000201', 'RPT_STOCK_CARD',
  '{"from": "2026-11-09", "to": "2026-11-10"}'::jsonb);

select is(public._c10_num('stock_card_stale', 'item_code', 'ITM_GAO', 'closing_qty'), 130::numeric, 'before refresh: new move not visible (stale MV)');

insert into c10_resp (key, resp)
select 'refresh_own', public.report_refresh_stock_card_mv();

select ok(
  (select (resp->>'ok')::boolean from c10_resp where key = 'refresh_own'),
  'owner refresh succeeds'
);

insert into c10_resp (key, resp)
select 'stock_card_new', public.report_get('c1000000-0000-4000-8000-000000000201', 'RPT_STOCK_CARD',
  '{"from": "2026-11-09", "to": "2026-11-10"}'::jsonb);

select is(public._c10_num('stock_card_new', 'item_code', 'ITM_GAO', 'closing_qty'), 140::numeric, 'after refresh: GAO closing qty 140');
select is(public._c10_total('stock_card_new', 'closing_value'), 1580000::numeric, 'after refresh: total closing value 1.580.000');

-- ---------------------------------------------------------------------------
-- D. Quyen refresh: khong co report.view.rpt_stock_card thi bi chan.
-- ---------------------------------------------------------------------------
select public._c10_as('c1000000-0000-4000-8000-000000000a03');
select throws_ok(
  $q$select public.report_refresh_stock_card_mv()$q$,
  '42501', 'ERR_FORBIDDEN:report.view.rpt_stock_card',
  'cost_controller without report.view.rpt_stock_card cannot refresh'
);

select public._c10_as('c1000000-0000-4000-8000-000000000a07');
insert into c10_resp (key, resp)
select 'refresh_wh', public.report_refresh_stock_card_mv();
select ok(
  (select (resp->>'ok')::boolean from c10_resp where key = 'refresh_wh'),
  'warehouse-scoped user with report.view.rpt_stock_card can refresh'
);

-- ---------------------------------------------------------------------------
-- E. property_dashboard_overview: dung payload + tai hien dung RLS cu.
-- ---------------------------------------------------------------------------
select public._c10_as('c1000000-0000-4000-8000-000000000a05');
insert into c10_resp (key, resp)
select 'dash_own', public.property_dashboard_overview('c1000000-0000-4000-8000-000000000201');

select is((select resp->'property'->>'code' from c10_resp where key = 'dash_own'), 'P1', 'dashboard owner: property code P1');
select is((select resp->'property'->'legal_entity'->>'code' from c10_resp where key = 'dash_own'), 'TC10', 'dashboard owner: legal entity code TC10');
select is((select (resp->'counts'->>'items')::bigint from c10_resp where key = 'dash_own'), 2::bigint, 'dashboard owner: items 2');
select is((select (resp->'counts'->>'warehouses')::bigint from c10_resp where key = 'dash_own'), 2::bigint, 'dashboard owner: warehouses 2');
select is((select (resp->'counts'->>'item_groups')::bigint from c10_resp where key = 'dash_own'), 2::bigint, 'dashboard owner: item_groups 2');
select is((select (resp->'counts'->>'roles')::bigint from c10_resp where key = 'dash_own'), 3::bigint, 'dashboard owner: roles 3');

select public._c10_as('c1000000-0000-4000-8000-000000000a03');
insert into c10_resp (key, resp)
select 'dash_cc', public.property_dashboard_overview('c1000000-0000-4000-8000-000000000201');

select is((select (resp->'counts'->>'items')::bigint from c10_resp where key = 'dash_cc'), 0::bigint, 'dashboard no item.view: items 0 (as RLS before)');
select is((select (resp->'counts'->>'item_groups')::bigint from c10_resp where key = 'dash_cc'), 0::bigint, 'dashboard no item.view: item_groups 0 (as RLS before)');
select is((select (resp->'counts'->>'warehouses')::bigint from c10_resp where key = 'dash_cc'), 2::bigint, 'dashboard no item.view: warehouses 2');
select is((select (resp->'counts'->>'roles')::bigint from c10_resp where key = 'dash_cc'), 3::bigint, 'dashboard no item.view: roles 3');

select public._c10_as('c1000000-0000-4000-8000-000000000a07');
insert into c10_resp (key, resp)
select 'dash_wh', public.property_dashboard_overview('c1000000-0000-4000-8000-000000000201');

select is((select (resp->'counts'->>'warehouses')::bigint from c10_resp where key = 'dash_wh'), 1::bigint, 'dashboard warehouse-scoped user: warehouses 1 (WH1 only)');
select is((select (resp->'counts'->>'items')::bigint from c10_resp where key = 'dash_wh'), 2::bigint, 'dashboard warehouse-scoped user with item.view: items 2');

select throws_ok(
  $q$select public.property_dashboard_overview('c1000000-0000-4000-8000-00000000ffff')$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'dashboard unknown property is rejected'
);

select public._c10_as('c1000000-0000-4000-8000-000000000a09');
select throws_ok(
  $q$select public.property_dashboard_overview('c1000000-0000-4000-8000-000000000201')$q$,
  '42501', 'ERR_FORBIDDEN',
  'dashboard user without property access is forbidden'
);

select * from finish();
rollback;
