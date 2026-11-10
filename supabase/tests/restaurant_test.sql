-- M06 — Nha hang (F&B) + dat tiec — pgTAP
-- CHUA CHAY DUOC: VM khong co Docker (giong cac test T-013..T-022A).
-- Chay tren DB that sau khi db push: psql "$SUPABASE_DB_URL" -f supabase/tests/restaurant_test.sql
-- Fixture: org/property/vat tu dung tien to d060 de khong dung do
-- voi fixture khac. Ngay dung ngay hien tai (gio VN) + ngay mai.
begin;
create extension if not exists pgtap;
select plan(109);

-- ---------------------------------------------------------------------------
-- Fixture: org, legal entity, property, uom, vat tu, gia tran, vai tro,
-- nguoi dung. Ma quyen restaurant.* + report.view.rpt_fnb_revenue do
-- migration 500000 seed; fixture gan lai (on conflict do nothing) de
-- test tu dung, khong phu thuoc thu tu grant cua migration.
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d0600000-0200-4000-8000-000000000001', 'T-060 Master Org');

insert into public.legal_entities (id, org_id, name, code) values
  ('d0600000-0200-4000-8000-000000000101', 'd0600000-0200-4000-8000-000000000001', 'T060 Entity', 'T060E');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0600000-0200-4000-8000-000000000201', 'd0600000-0200-4000-8000-000000000001', 'd0600000-0200-4000-8000-000000000101', 'P0601', 'T-060 Property', 'with_cc');

insert into public.uoms (code, name_vi) values ('kg', 'Ký'), ('gr', 'Gam'), ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0600000-0200-4000-8000-000000000301', 'd0600000-0200-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d0600000-0200-4000-8000-000000000302', 'd0600000-0200-4000-8000-000000000001', 'THIT', 'Thịt', 'food')
on conflict do nothing;

-- GAO: stock kg, recipe gr, 1 kg = 1000 gr. THIT: chi co kg.
-- MUOI: co dinh luong nhung KHONG co gia tran (test foodcost NULL).
insert into public.items (id, org_id, code, name, group_id, stock_uom, recipe_uom, stock_to_recipe, is_key_item, allowed_channels) values
  ('d0600000-0200-4000-8000-000000000501', 'd0600000-0200-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd0600000-0200-4000-8000-000000000301', 'kg', 'gr', 1000, true, array['contract', 'market']),
  ('d0600000-0200-4000-8000-000000000502', 'd0600000-0200-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'd0600000-0200-4000-8000-000000000302', 'kg', null, null, true, array['contract']),
  ('d0600000-0200-4000-8000-000000000503', 'd0600000-0200-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd0600000-0200-4000-8000-000000000302', 'kg', 'gr', 1000, false, array['contract', 'market']);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0600000-0200-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't060-chef@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0600000-0200-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't060-oh@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0600000-0200-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't060-fd@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0600000-0200-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't060-view@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0600000-0200-4000-8000-000000000a05', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't060-noperm@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0600000-0200-4000-8000-000000000a06', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 't060-own@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by) values
  ('d0600000-0200-4000-8000-000000000001', 'd0600000-0200-4000-8000-000000000201', 'd0600000-0200-4000-8000-000000000501', 'kg', 12000, '2026-01-01', '2030-12-31', 'd0600000-0200-4000-8000-000000000a01'),
  ('d0600000-0200-4000-8000-000000000001', 'd0600000-0200-4000-8000-000000000201', 'd0600000-0200-4000-8000-000000000502', 'kg', 50000, '2026-01-01', '2030-12-31', 'd0600000-0200-4000-8000-000000000a01');

insert into public.profiles (id, employee_code, full_name) values
  ('d0600000-0200-4000-8000-000000000a01', 'T060_CHEF', 'Bếp trưởng'),
  ('d0600000-0200-4000-8000-000000000a02', 'T060_OH', 'Trưởng bộ phận'),
  ('d0600000-0200-4000-8000-000000000a03', 'T060_FD', 'Lễ tân'),
  ('d0600000-0200-4000-8000-000000000a04', 'T060_VIEW', 'Người xem'),
  ('d0600000-0200-4000-8000-000000000a05', 'T060_NOPERM', 'Không quyền'),
  ('d0600000-0200-4000-8000-000000000a06', 'T060_OWN', 'Chủ sở hữu')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0600000-0200-4000-8000-000000000601', 'd0600000-0200-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('d0600000-0200-4000-8000-000000000602', 'd0600000-0200-4000-8000-000000000001', 'outlet_head', 'Trưởng bộ phận'),
  ('d0600000-0200-4000-8000-000000000603', 'd0600000-0200-4000-8000-000000000001', 'front_desk', 'Lễ tân'),
  ('d0600000-0200-4000-8000-000000000604', 'd0600000-0200-4000-8000-000000000001', 'r_view060', 'Chỉ xem'),
  ('d0600000-0200-4000-8000-000000000605', 'd0600000-0200-4000-8000-000000000001', 'owner', 'Chủ sở hữu'),
  ('d0600000-0200-4000-8000-000000000606', 'd0600000-0200-4000-8000-000000000001', 'no_perm060', 'Không quyền');

insert into public.role_permissions (role_id, permission_code) values
  ('d0600000-0200-4000-8000-000000000601', 'restaurant.view'),
  ('d0600000-0200-4000-8000-000000000601', 'restaurant.dish.manage'),
  ('d0600000-0200-4000-8000-000000000601', 'restaurant.sale.record'),
  ('d0600000-0200-4000-8000-000000000601', 'restaurant.buffet.manage'),
  ('d0600000-0200-4000-8000-000000000602', 'restaurant.view'),
  ('d0600000-0200-4000-8000-000000000602', 'restaurant.dish.manage'),
  ('d0600000-0200-4000-8000-000000000602', 'restaurant.sale.record'),
  ('d0600000-0200-4000-8000-000000000602', 'restaurant.buffet.manage'),
  ('d0600000-0200-4000-8000-000000000602', 'restaurant.banquet.manage'),
  ('d0600000-0200-4000-8000-000000000603', 'restaurant.view'),
  ('d0600000-0200-4000-8000-000000000603', 'restaurant.sale.record'),
  ('d0600000-0200-4000-8000-000000000603', 'restaurant.banquet.manage'),
  ('d0600000-0200-4000-8000-000000000604', 'restaurant.view'),
  ('d0600000-0200-4000-8000-000000000605', 'restaurant.view'),
  ('d0600000-0200-4000-8000-000000000605', 'report.view.rpt_fnb_revenue')
on conflict do nothing;

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0600000-0200-4000-8000-000000000a01', 'd0600000-0200-4000-8000-000000000601', 'd0600000-0200-4000-8000-000000000201'),
  ('d0600000-0200-4000-8000-000000000a02', 'd0600000-0200-4000-8000-000000000602', 'd0600000-0200-4000-8000-000000000201'),
  ('d0600000-0200-4000-8000-000000000a03', 'd0600000-0200-4000-8000-000000000603', 'd0600000-0200-4000-8000-000000000201'),
  ('d0600000-0200-4000-8000-000000000a04', 'd0600000-0200-4000-8000-000000000604', 'd0600000-0200-4000-8000-000000000201'),
  ('d0600000-0200-4000-8000-000000000a05', 'd0600000-0200-4000-8000-000000000606', 'd0600000-0200-4000-8000-000000000201'),
  ('d0600000-0200-4000-8000-000000000a06', 'd0600000-0200-4000-8000-000000000605', 'd0600000-0200-4000-8000-000000000201');

-- C11 (Q169): bo phan Bep chinh (outlet_types KITCHEN) + kho chinh +
-- kho bep, de banquet_confirm / dish_sale_record tu sinh phieu linh
-- nhap. Them o fixture goc (truoc `set local role authenticated`).
insert into public.outlet_types (id, org_id, code, name) values
  ('d0600000-0200-4000-8000-000000000701', 'd0600000-0200-4000-8000-000000000001', 'KITCHEN', 'Bếp chính');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0600000-0200-4000-8000-000000000702', 'd0600000-0200-4000-8000-000000000201', 'd0600000-0200-4000-8000-000000000701', 'KITCHEN', 'Bếp chính');

insert into public.warehouses (id, property_id, outlet_id, code, name, kind) values
  ('d0600000-0200-4000-8000-000000000703', 'd0600000-0200-4000-8000-000000000201', null, 'MAIN', 'Kho chính', 'main'),
  ('d0600000-0200-4000-8000-000000000704', 'd0600000-0200-4000-8000-000000000201', 'd0600000-0200-4000-8000-000000000702', 'KITCHEN', 'Kho bếp', 'outlet');

-- Helper gia lap nguoi dung dang dang nhap (mau T-020/T-022).
create or replace function _r060_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user::text)::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- 1. RLS + write-guard.
-- ---------------------------------------------------------------------------
select is(
  (select count(*) from pg_class where oid in (
    'public.recipes'::regclass, 'public.recipe_versions'::regclass,
    'public.recipe_lines'::regclass, 'public.buffet_sessions'::regclass,
    'public.buffet_session_dishes'::regclass, 'public.dish_sales'::regclass,
    'public.banquets'::regclass, 'public.banquet_dishes'::regclass)
    and relrowsecurity),
  8::bigint,
  'RLS bat cho ca 8 bang nha hang'
);

select throws_ok(
  $q$insert into public.recipes (org_id, code, name, kind)
    values ('d0600000-0200-4000-8000-000000000001', 'X', 'Mon X', 'dish')$q$,
  'P0001', 'ERR_WRITE_GUARD: recipes chi duoc ghi qua RPC',
  'ghi truc tiep recipes bi write-guard chan'
);

select throws_ok(
  $q$insert into public.dish_sales (org_id, legal_entity_id, property_id, business_date, source, qty, unit_price, amount)
    values ('d0600000-0200-4000-8000-000000000001', 'd0600000-0200-4000-8000-000000000101', 'd0600000-0200-4000-8000-000000000201', '2026-11-10', 'buffet', 1, 100000, 100000)$q$,
  'P0001', 'ERR_WRITE_GUARD: dish_sales chi duoc ghi qua RPC',
  'ghi truc tiep dish_sales bi write-guard chan'
);

select throws_ok(
  $q$insert into public.banquets (org_id, legal_entity_id, property_id, doc_no, customer_name, event_date, start_time, end_time, hall, guests_count)
    values ('d0600000-0200-4000-8000-000000000001', 'd0600000-0200-4000-8000-000000000101', 'd0600000-0200-4000-8000-000000000201', 'banquet-T060E-2611-0001', 'Khach X', '2026-11-11', '10:00', '12:00', 'Sảnh A', 10)$q$,
  'P0001', 'ERR_WRITE_GUARD: banquets chi duoc ghi qua RPC',
  'ghi truc tiep banquets bi write-guard chan'
);

set local role authenticated;
select _r060_as('d0600000-0200-4000-8000-000000000a05');

select is(
  (select count(*) from public.recipes),
  0::bigint,
  'RLS: nguoi khong co quyen restaurant.* thay 0 mon'
);

-- ---------------------------------------------------------------------------
-- 2. recipe_save: happy path + foodcost.
--    MON01: gao 100gr (-> 0,1 kg x 12000 = 1200) + thit 0,2 kg x 50000
--    = 10000 -> foodcost 11200.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a01');

select ok(
  (public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'code', 'MON01', 'name', 'Cơm gà xối mỡ', 'kind', 'dish',
      'group_name', 'hot', 'sale_price', 45000,
      'lines', jsonb_build_array(
        jsonb_build_object('item_id', 'd0600000-0200-4000-8000-000000000501', 'qty', 100, 'uom', 'gr'),
        jsonb_build_object('item_id', 'd0600000-0200-4000-8000-000000000502', 'qty', 0.2, 'uom', 'kg')
      )
    )
  ) ->> 'ok')::boolean,
  'recipe_save mon MON01 tra ok'
);

select is(
  (select count(*) from public.recipes where code = 'MON01'),
  1::bigint,
  'mon MON01 da co trong recipes'
);

select is(
  (select version_no from public.recipe_versions
    where recipe_id = (select id from public.recipes where code = 'MON01')
      and status = 'active'),
  1,
  'version active cua MON01 la v1'
);

select is(
  (select count(*) from public.recipe_lines
    where version_id = (select id from public.recipe_versions
      where recipe_id = (select id from public.recipes where code = 'MON01')
        and status = 'active')),
  2::bigint,
  'v1 cua MON01 co 2 dong dinh luong'
);

select is(
  (select foodcost from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')
    where recipe_id = (select id from public.recipes where code = 'MON01')),
  11200::numeric,
  'foodcost MON01 = 1200 (gao) + 10000 (thit)'
);

select is(
  (select has_unknown_cost from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')
    where recipe_id = (select id from public.recipes where code = 'MON01')),
  false,
  'MON01 khong co dong thieu gia'
);

select is(
  public.recipe_foodcost('d0600000-0200-4000-8000-000000000201',
    (select id from public.recipes where code = 'MON01')),
  11200::numeric,
  'recipe_foodcost (scalar) MON01 = 11200'
);

select is(
  (select count(*) from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')),
  1::bigint,
  'foodcost_list tra 1 mon (luc nay chi co MON01)'
);

-- ---------------------------------------------------------------------------
-- 3. recipe_save: validation.
-- ---------------------------------------------------------------------------
select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "BAD01", "name": "Mon sai", "kind": "drink", "lines": []}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'kind khong hop le -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "MON01", "name": "Trung code", "kind": "dish", "lines": []}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'trung code mon -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "BAD02", "name": "Mon sai", "kind": "dish", "lines": [{"qty": 10, "uom": "kg"}]}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'dong khong co item_id/sub_recipe_id -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "BAD03", "name": "Mon sai", "kind": "dish", "lines": [{"item_id": "d0600000-0200-4000-8000-000000000501", "qty": 0, "uom": "kg"}]}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'dong qty 0 -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "BAD04", "name": "Mon sai", "kind": "dish", "lines": [{"item_id": "d0600000-0200-4000-8000-000000009999", "qty": 10, "uom": "kg"}]}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'dong item khong ton tai -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object('id', (select id::text from public.recipes where code = 'MON01'),
      'code', 'MON01', 'name', 'Cơm gà xối mỡ', 'kind', 'dish',
      'lines', jsonb_build_array(
        jsonb_build_object('sub_recipe_id', (select id::text from public.recipes where code = 'MON01'), 'qty', 1, 'uom', 'cai')))$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'sub_recipe tu tro chinh minh -> ERR_INVALID_VALUE'
);

-- ---------------------------------------------------------------------------
-- 4. Versioning: luu lai tao version moi, version cu retired.
--    MON01 v2 chi con gao 200gr -> foodcost 0,2 kg x 12000 = 2400.
-- ---------------------------------------------------------------------------
select ok(
  (public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id::text from public.recipes where code = 'MON01'),
      'code', 'MON01', 'name', 'Cơm gà xối mỡ', 'kind', 'dish',
      'group_name', 'hot', 'sale_price', 45000,
      'lines', jsonb_build_array(
        jsonb_build_object('item_id', 'd0600000-0200-4000-8000-000000000501', 'qty', 200, 'uom', 'gr')
      )
    )
  ) ->> 'ok')::boolean,
  'recipe_save lai MON01 (v2) tra ok'
);

select is(
  (select version_no from public.recipe_versions
    where recipe_id = (select id from public.recipes where code = 'MON01')
      and status = 'active'),
  2,
  'luu lai tao version v2 active'
);

select is(
  (select count(*) from public.recipe_versions
    where recipe_id = (select id from public.recipes where code = 'MON01')
      and status = 'retired'),
  1::bigint,
  'v1 cua MON01 da retired'
);

select is(
  (select foodcost from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')
    where recipe_id = (select id from public.recipes where code = 'MON01')),
  2400::numeric,
  'foodcost MON01 sau v2 = 200gr gao -> 2400'
);

-- ---------------------------------------------------------------------------
-- 5. Mon thieu gia tran: foodcost NULL + co has_unknown_cost.
-- ---------------------------------------------------------------------------
select ok(
  (public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'code', 'MON02', 'name', 'Muối chấm', 'kind', 'dish',
      'sale_price', 5000,
      'lines', jsonb_build_array(
        jsonb_build_object('item_id', 'd0600000-0200-4000-8000-000000000503', 'qty', 5, 'uom', 'gr')
      )
    )
  ) ->> 'ok')::boolean,
  'recipe_save mon MON02 (muoi khong gia tran) tra ok'
);

select is(
  (select foodcost from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')
    where recipe_id = (select id from public.recipes where code = 'MON02')),
  null::numeric,
  'foodcost MON02 NULL (muoi khong co gia tran)'
);

select is(
  (select has_unknown_cost from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')
    where recipe_id = (select id from public.recipes where code = 'MON02')),
  true,
  'MON02 co dong thieu gia'
);

-- ---------------------------------------------------------------------------
-- 6. Quyen: chi xem khong luu duoc mon; khong quyen khong doc duoc foodcost.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a04');

select throws_ok(
  $q$select public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "MON03", "name": "Mon xem", "kind": "dish", "lines": []}'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:restaurant.dish.manage',
  'nguoi chi xem khong luu duoc mon'
);

select _r060_as('d0600000-0200-4000-8000-000000000a05');

select throws_ok(
  $q$select count(*) from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')$q$,
  '42501', 'ERR_FORBIDDEN:restaurant.view',
  'nguoi khong quyen khong doc duoc foodcost'
);

select _r060_as('d0600000-0200-4000-8000-000000000a04');

select is(
  (select count(*) from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')),
  2::bigint,
  'nguoi xem doc duoc foodcost_list (2 mon)'
);

-- ---------------------------------------------------------------------------
-- 7. Phien buffet: tao, dong (ghi doanh thu theo khach), trung phien.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a01');

select ok(
  (public.buffet_session_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'business_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text,
      'meal', 'breakfast',
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'planned_qty', 10)
      )
    )
  ) ->> 'ok')::boolean,
  'buffet_session_save phien sang hom nay tra ok'
);

select is(
  (select status from public.buffet_sessions
    where property_id = 'd0600000-0200-4000-8000-000000000201'
      and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date
      and meal = 'breakfast'),
  'planned',
  'phien buffet moi o trang thai planned'
);

select is(
  (select count(*) from public.buffet_session_dishes
    where session_id = (select id from public.buffet_sessions
      where property_id = 'd0600000-0200-4000-8000-000000000201'
        and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date
        and meal = 'breakfast')),
  1::bigint,
  'phien buffet co 1 mon'
);

select throws_ok(
  $q$select public.buffet_session_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'business_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text,
      'meal', 'breakfast',
      'dishes', '[]'::jsonb))$q$,
  '23505', 'duplicate key value violates unique constraint "buffet_sessions_one_per_meal"',
  'trung phien cung buoi cung ngay -> 23505'
);

select ok(
  (public.buffet_session_close(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.buffet_sessions
      where property_id = 'd0600000-0200-4000-8000-000000000201'
        and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date
        and meal = 'breakfast'),
    20, 150000
  ) ->> 'ok')::boolean,
  'buffet_session_close (20 khach x 150000) tra ok'
);

select is(
  (select amount from public.dish_sales
    where source = 'buffet'
      and ref_id = (select id from public.buffet_sessions
        where property_id = 'd0600000-0200-4000-8000-000000000201'
          and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date
          and meal = 'breakfast')),
  3000000::numeric,
  'dong phien ghi doanh thu buffet 20 x 150000'
);

select throws_ok(
  $q$select public.buffet_session_close(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.buffet_sessions
      where property_id = 'd0600000-0200-4000-8000-000000000201'
        and business_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date
        and meal = 'breakfast'),
    20, 150000)$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'dong phien da dong -> ERR_INVALID_STATUS'
);

-- ---------------------------------------------------------------------------
-- 8. Ghi ban tay + huy dong ghi sai.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a03');

select ok(
  (public.dish_sale_record(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    (select id from public.recipes where code = 'MON01'),
    3, 45000
  ) ->> 'ok')::boolean,
  'dish_sale_record (3 x 45000) tra ok'
);

select is(
  (select amount from public.dish_sales
    where source = 'manual'
      and recipe_id = (select id from public.recipes where code = 'MON01')
    order by created_at desc limit 1),
  135000::numeric,
  'thanh tien ban tay 3 x 45000'
);

select throws_ok(
  $q$select public.dish_sale_record(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date + 5,
    (select id from public.recipes where code = 'MON01'),
    1, 45000)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'ghi ban ngay tuong lai -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.dish_sale_record(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    (select id from public.recipes where code = 'MON01'),
    0, 45000)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'ghi ban qty 0 -> ERR_INVALID_VALUE'
);

select _r060_as('d0600000-0200-4000-8000-000000000a01');

select ok(
  (public.recipe_set_active(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.recipes where code = 'MON02'), false
  ) ->> 'ok')::boolean,
  'recipe_set_active tat MON02 tra ok'
);

select _r060_as('d0600000-0200-4000-8000-000000000a03');

select throws_ok(
  $q$select public.dish_sale_record(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    (select id from public.recipes where code = 'MON02'),
    1, 5000)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'ghi ban mon da tat -> ERR_INVALID_VALUE'
);

select ok(
  (public.dish_sale_void(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.dish_sales
      where source = 'manual'
        and recipe_id = (select id from public.recipes where code = 'MON01')
      order by created_at desc limit 1)
  ) ->> 'ok')::boolean,
  'dish_sale_void dong ban tay tra ok'
);

-- ---------------------------------------------------------------------------
-- 9. Dat tiec: tao, xac nhan, trung sanh, bat dau, hoan thanh, huy.
--    Ngay mai, sanh A: B1 10:00-13:00, B2 12:00-15:00 (trung B1),
--    B3 14:00-17:00 (khong trung B1, B2 chua xac nhan nen khong chan).
-- ---------------------------------------------------------------------------
select ok(
  (public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Anh Tuấn', 'customer_phone', '0900000001',
      'event_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text,
      'start_time', '10:00', 'end_time', '13:00', 'hall', 'Sảnh A',
      'tables_count', 5, 'guests_count', 50, 'deposit_amount', 5000000,
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'qty', 50, 'unit_price', 45000)
      )
    )
  ) ->> 'ok')::boolean,
  'banquet_save tiec B1 tra ok'
);

select ok(
  (select doc_no like 'banquet-%' from public.banquets
    where customer_name = 'Anh Tuấn'),
  'so chung tu tiec co prefix banquet-'
);

select ok(
  (public.banquet_confirm(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Anh Tuấn')
  ) ->> 'ok')::boolean,
  'banquet_confirm B1 tra ok'
);

select is(
  (select status from public.banquets where customer_name = 'Anh Tuấn'),
  'confirmed',
  'tiec B1 da xac nhan'
);

select ok(
  (public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Chị Lan',
      'event_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text,
      'start_time', '12:00', 'end_time', '15:00', 'hall', 'Sảnh A',
      'guests_count', 30,
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'qty', 30, 'unit_price', 45000)
      )
    )
  ) ->> 'ok')::boolean,
  'banquet_save tiec B2 (trung gio B1) tra ok — chua xac nhan nen chua chan'
);

select throws_ok(
  $q$select public.banquet_confirm(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Chị Lan'))$q$,
  'P0001', 'ERR_BANQUET_HALL_CONFLICT',
  'xac nhan tiec trung sanh + gio voi tiec da xac nhan -> ERR_BANQUET_HALL_CONFLICT'
);

select ok(
  (public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Anh Hùng',
      'event_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text,
      'start_time', '14:00', 'end_time', '17:00', 'hall', 'Sảnh A',
      'guests_count', 40,
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'qty', 40, 'unit_price', 45000)
      )
    )
  ) ->> 'ok')::boolean,
  'banquet_save tiec B3 (14:00-17:00) tra ok'
);

select ok(
  (public.banquet_confirm(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Anh Hùng')
  ) ->> 'ok')::boolean,
  'banquet_confirm B3 tra ok (khong trung B1, B2 chua xac nhan)'
);

select ok(
  (public.banquet_start(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Anh Tuấn')
  ) ->> 'ok')::boolean,
  'banquet_start B1 tra ok'
);

select ok(
  (public.banquet_complete(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Anh Tuấn')
  ) ->> 'ok')::boolean,
  'banquet_complete B1 tra ok'
);

select is(
  (select amount from public.dish_sales
    where source = 'banquet'
      and ref_id = (select id from public.banquets where customer_name = 'Anh Tuấn')),
  2250000::numeric,
  'doanh thu tiec B1 = 50 x 45000'
);

select is(
  (select count(*) from public.dish_sales
    where source = 'banquet'
      and ref_id = (select id from public.banquets where customer_name = 'Anh Tuấn')),
  1::bigint,
  'hoan thanh tiec ghi 1 dong dish_sales'
);

select ok(
  (public.banquet_cancel(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Chị Lan'),
    'Khách đổi ngày'
  ) ->> 'ok')::boolean,
  'banquet_cancel B2 (dang new) tra ok'
);

-- ---------------------------------------------------------------------------
-- 10. Man bep ngay mai: phien buffet sang (MON01 x 5) + tiec B3
--     (MON01 x 40, confirmed) -> NVL chuan bi gao 200gr x 45 = 9000gr.
--     B1 da completed, B2 da cancelled -> khong co trong man bep.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a01');

select ok(
  (public.buffet_session_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'business_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text,
      'meal', 'breakfast',
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'planned_qty', 5)
      )
    )
  ) ->> 'ok')::boolean,
  'buffet_session_save phien sang ngay mai tra ok'
);

select ok(
  (public.restaurant_kitchen_today(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
  ) ->> 'ok')::boolean,
  'restaurant_kitchen_today (ngay mai) tra ok'
);

select is(
  jsonb_array_length(
    public.restaurant_kitchen_today(
      'd0600000-0200-4000-8000-000000000201',
      (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
    ) -> 'buffet_sessions'),
  1,
  'man bep ngay mai co 1 phien buffet'
);

select is(
  jsonb_array_length(
    public.restaurant_kitchen_today(
      'd0600000-0200-4000-8000-000000000201',
      (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
    ) -> 'banquets'),
  1,
  'man bep ngay mai co 1 tiec (B3 confirmed)'
);

select is(
  (select (x ->> 'total_qty')::numeric
   from jsonb_array_elements(
     public.restaurant_kitchen_today(
       'd0600000-0200-4000-8000-000000000201',
       (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
     ) -> 'prep') x
   where x ->> 'item_code' = 'ITM_GAO'),
  9000::numeric,
  'NVL chuan bi: gao 200gr x (5 phan buffet + 40 phan tiec) = 9000gr'
);

select is(
  jsonb_array_length(
    public.restaurant_kitchen_today(
      'd0600000-0200-4000-8000-000000000201',
      (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
    ) -> 'dishes'),
  1,
  'man bep liet ke 1 mon dang ban (MON01; MON02 da tat)'
);

-- ---------------------------------------------------------------------------
-- 11. Tong hop doanh thu hom nay -> ngay mai (ban tay da void khong tinh).
--     Doanh thu = buffet 3000000 + tiec 2250000 = 5250000; so luong 20 + 50.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a04');

select is(
  (public.restaurant_sales_summary(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
  ) -> 'totals' ->> 'revenue')::numeric,
  5250000::numeric,
  'tong doanh thu = buffet 3000000 + tiec 2250000'
);

select is(
  (public.restaurant_sales_summary(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
  ) -> 'totals' ->> 'qty')::numeric,
  70::numeric,
  'tong so luong = 20 khach buffet + 50 phan tiec'
);

select is(
  (select (x ->> 'revenue')::numeric
   from jsonb_array_elements(
     public.restaurant_sales_summary(
       'd0600000-0200-4000-8000-000000000201',
       (now() at time zone 'Asia/Ho_Chi_Minh')::date,
       (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
     ) -> 'by_dish') x
   where x ->> 'recipe_code' = 'MON01'),
  2250000::numeric,
  'MON01: doanh thu 2250000 tu tiec'
);

-- ---------------------------------------------------------------------------
-- 12. Bao cao F&B (T-044): RPT_FNB_REVENUE qua report_get.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a06');

select ok(
  (public.report_get(
    'd0600000-0200-4000-8000-000000000201', 'RPT_FNB_REVENUE',
    jsonb_build_object(
      'from', ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text,
      'to', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text)
  ) ->> 'ok')::boolean,
  'report_get RPT_FNB_REVENUE tra ok'
);

select is(
  (public.report_get(
    'd0600000-0200-4000-8000-000000000201', 'RPT_FNB_REVENUE',
    jsonb_build_object(
      'from', ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text,
      'to', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text)
  ) -> 'totals' ->> 'revenue')::numeric,
  5250000::numeric,
  'bao cao F&B: tong doanh thu 5250000'
);

select is(
  (select (x ->> 'revenue')::numeric
   from jsonb_array_elements(
     public.report_get(
       'd0600000-0200-4000-8000-000000000201', 'RPT_FNB_REVENUE',
       jsonb_build_object(
         'from', ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text,
         'to', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text)
     ) -> 'rows') x
   where x ->> 'dish_code' = 'MON01'),
  2250000::numeric,
  'bao cao F&B: MON01 doanh thu 2250000'
);

select is(
  (select (x ->> 'foodcost')::numeric
   from jsonb_array_elements(
     public.report_get(
       'd0600000-0200-4000-8000-000000000201', 'RPT_FNB_REVENUE',
       jsonb_build_object(
         'from', ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text,
         'to', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)::text)
     ) -> 'rows') x
   where x ->> 'dish_code' = 'MON01'),
  120000::numeric,
  'bao cao F&B: MON01 foodcost 50 x 2400 (gia tran hien hanh)'
);

-- ---------------------------------------------------------------------------
-- 13. C11 — Danh muc sanh (Q170b): banquet_hall_save.
-- ---------------------------------------------------------------------------
select is(
  (select count(*) from pg_class
    where oid = 'public.banquet_halls'::regclass and relrowsecurity),
  1::bigint,
  'RLS bat cho banquet_halls'
);

select throws_ok(
  $q$insert into public.banquet_halls (org_id, property_id, name)
    values ('d0600000-0200-4000-8000-000000000001', 'd0600000-0200-4000-8000-000000000201', 'Sảnh X')$q$,
  'P0001', 'ERR_WRITE_GUARD: banquet_halls chi duoc ghi qua RPC',
  'ghi truc tiep banquet_halls bi write-guard chan'
);

select _r060_as('d0600000-0200-4000-8000-000000000a05');

select throws_ok(
  $q$select public.banquet_hall_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"name": "Sảnh A", "capacity": 100}'::jsonb)$q$,
  '42501', 'ERR_FORBIDDEN:restaurant.banquet.manage',
  'nguoi khong quyen khong luu duoc sanh'
);

select _r060_as('d0600000-0200-4000-8000-000000000a03');

select ok(
  (public.banquet_hall_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"name": "Sảnh A", "capacity": 100}'::jsonb
  ) ->> 'ok')::boolean,
  'banquet_hall_save Sảnh A tra ok'
);

select is(
  (select capacity from public.banquet_halls where name = 'Sảnh A'),
  100,
  'sanh Sảnh A luu dung suc chua 100'
);

select throws_ok(
  $q$select public.banquet_hall_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"name": "sảnh a", "capacity": 50}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'trung ten sanh (khong phan biet hoa/thuong) -> ERR_INVALID_VALUE'
);

select ok(
  (public.banquet_hall_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id::text from public.banquet_halls where name = 'Sảnh A'),
      'name', 'Sảnh A', 'capacity', 120)
  ) ->> 'ok')::boolean,
  'banquet_hall_save cap nhat suc chua Sảnh A tra ok'
);

select is(
  (select capacity from public.banquet_halls where name = 'Sảnh A'),
  120,
  'suc chua Sảnh A da doi thanh 120'
);

select throws_ok(
  $q$select public.banquet_hall_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"name": "Sảnh B", "capacity": 0}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'suc chua 0 -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.banquet_hall_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"name": "   ", "capacity": 10}'::jsonb)$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'ten sanh rong -> ERR_INVALID_VALUE'
);

select _r060_as('d0600000-0200-4000-8000-000000000a04');

select is(
  (select count(*) from public.banquet_halls),
  1::bigint,
  'nguoi chi xem (restaurant.view) doc duoc danh muc sanh'
);

select _r060_as('d0600000-0200-4000-8000-000000000a05');

select is(
  (select count(*) from public.banquet_halls),
  0::bigint,
  'nguoi khong quyen thay 0 sanh'
);

-- ---------------------------------------------------------------------------
-- 14. C11 — Trang thai coc (Q170a): deposit_status chi ghi nhan,
--     KHONG ghi ap_ledger. 'paid' doi deposit_amount > 0.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a03');

select throws_ok(
  $q$select public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Khách Cọc', 'event_date',
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'start_time', '18:00', 'end_time', '21:00', 'hall', 'Sảnh A',
      'guests_count', 10, 'deposit_amount', 0, 'deposit_status', 'paid'))$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'deposit_status paid nhung tien coc 0 -> ERR_INVALID_VALUE'
);

select throws_ok(
  $q$select public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Khách Cọc', 'event_date',
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'start_time', '18:00', 'end_time', '21:00', 'hall', 'Sảnh A',
      'guests_count', 10, 'deposit_amount', 100000,
      'deposit_status', 'bogus'))$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'deposit_status ngoai (unpaid, paid) -> ERR_INVALID_VALUE'
);

select ok(
  (public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Chị Đào', 'event_date',
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'start_time', '18:00', 'end_time', '21:00',
      'hall_id', (select id::text from public.banquet_halls where name = 'Sảnh A'),
      'guests_count', 50, 'tables_count', 5,
      'deposit_amount', 2000000, 'deposit_status', 'paid',
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'qty', 10, 'unit_price', 45000))
    )
  ) ->> 'ok')::boolean,
  'banquet_save tiec B4 (sanh danh muc + da coc) tra ok'
);

select is(
  (select deposit_status || '|' || hall from public.banquets
    where customer_name = 'Chị Đào'),
  'paid|Sảnh A',
  'tiec B4 luu deposit_status paid + hall snapshot theo ten sanh danh muc'
);

select is(
  (select hall_id from public.banquets where customer_name = 'Chị Đào'),
  (select id from public.banquet_halls where name = 'Sảnh A'),
  'tiec B4 luu hall_id tro toi sanh danh muc'
);

select ok(
  (public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'id', (select id::text from public.banquets where customer_name = 'Chị Đào'),
      'customer_name', 'Chị Đào', 'event_date',
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'start_time', '18:00', 'end_time', '21:00',
      'hall_id', (select id::text from public.banquet_halls where name = 'Sảnh A'),
      'guests_count', 50, 'tables_count', 5,
      'deposit_amount', 2000000, 'deposit_status', 'unpaid',
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON01'), 'qty', 10, 'unit_price', 45000))
    )
  ) ->> 'ok')::boolean,
  'banquet_save cap nhat deposit_status ve unpaid tra ok'
);

select is(
  (select deposit_status from public.banquets where customer_name = 'Chị Đào'),
  'unpaid',
  'tiec B4 da doi ve unpaid'
);

select throws_ok(
  $q$select public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Khách Lạ', 'event_date',
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'start_time', '18:00', 'end_time', '21:00',
      'hall_id', '00000000-0000-4000-8000-000000000099',
      'guests_count', 10))$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'hall_id khong ton tai -> ERR_INVALID_VALUE'
);

-- ---------------------------------------------------------------------------
-- 15. C11 — portions_per_batch (Q167): so me trong man bep + foodcost
--     theo phan. MON03: 1000gr gao / me, 10 phan / me -> foodcost
--     12000 / 10 = 1200 / phan; buffet 25 phan -> 3 me -> 3000gr gao.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a01');

select ok(
  (public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'code', 'MON03', 'name', 'Cơm rang', 'kind', 'dish',
      'sale_price', 60000, 'portions_per_batch', 10,
      'lines', jsonb_build_array(
        jsonb_build_object('item_id', 'd0600000-0200-4000-8000-000000000501', 'qty', 1000, 'uom', 'gr'))
    )
  ) ->> 'ok')::boolean,
  'recipe_save MON03 (10 phan/me) tra ok'
);

select is(
  (select portions_per_batch from public.recipes where code = 'MON03'),
  10::numeric,
  'MON03 luu portions_per_batch = 10'
);

select is(
  (select foodcost from public.recipe_foodcost_list('d0600000-0200-4000-8000-000000000201')
    where recipe_id = (select id from public.recipes where code = 'MON03')),
  1200::numeric,
  'foodcost MON03 = 12000 / me / 10 phan = 1200 / phan'
);

select ok(
  (public.buffet_session_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'business_date', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'meal', 'breakfast',
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON03'), 'planned_qty', 25))
    )
  ) ->> 'ok')::boolean,
  'buffet_session_save phien sang ngay +2 (MON03 x 25) tra ok'
);

select is(
  (select (x ->> 'batches')::numeric
   from jsonb_array_elements(
     public.restaurant_kitchen_today(
       'd0600000-0200-4000-8000-000000000201',
       (now() at time zone 'Asia/Ho_Chi_Minh')::date + 2
     ) -> 'buffet_sessions') s,
   jsonb_array_elements(s -> 'dishes') x
   where x ->> 'recipe_code' = 'MON03'),
  3::numeric,
  'man bep: MON03 25 phan / 10 phan-me = 3 me'
);

select is(
  (select (x ->> 'total_qty')::numeric
   from jsonb_array_elements(
     public.restaurant_kitchen_today(
       'd0600000-0200-4000-8000-000000000201',
       (now() at time zone 'Asia/Ho_Chi_Minh')::date + 2
     ) -> 'prep') x
   where x ->> 'item_code' = 'ITM_GAO'),
  3000::numeric,
  'NVL chuan bi ngay +2: gao 1000gr x 3 me = 3000gr'
);

-- ---------------------------------------------------------------------------
-- 16. C11 — Tu sinh phieu linh nhap khi xac nhan tiec (Q169).
--     B4 (MON01 x 10, dinh luong v2 200gr gao/phan) -> 2000gr = 2 kg,
--     kho bep nhan tu kho chinh, trang thai draft, KHONG tu duyet.
--     B5 (mon MON04 khong co dong dinh luong) -> khong co phieu.
-- ---------------------------------------------------------------------------
select _r060_as('d0600000-0200-4000-8000-000000000a03');

select is(
  (select count(*) from public.outlets
    where property_id = 'd0600000-0200-4000-8000-000000000201'
      and code = 'KITCHEN'),
  1::bigint,
  'fixture co 1 outlet Bep chinh (KITCHEN)'
);

select ok(
  ((public.banquet_confirm(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Chị Đào')
  ) ->> 'requisition_id') is not null,
  'banquet_confirm B4 tra ve requisition_id (phieu linh nhap da sinh)'
);

select is(
  (select status from public.banquets where customer_name = 'Chị Đào'),
  'confirmed',
  'tiec B4 da xac nhan'
);

select is(
  (select status from public.requisitions
    where note = 'Tự động từ tiệc ' || (select doc_no from public.banquets where customer_name = 'Chị Đào')),
  'draft',
  'phieu linh tu dong cua B4 o trang thai draft (khong tu duyet)'
);

select is(
  (select count(*) from public.requisition_lines
    where requisition_id = (select id from public.requisitions
      where note = 'Tự động từ tiệc ' || (select doc_no from public.banquets where customer_name = 'Chị Đào'))),
  1::bigint,
  'phieu linh tu dong cua B4 co 1 dong NVL'
);

select is(
  (select qty_stock from public.requisition_lines
    where requisition_id = (select id from public.requisitions
      where note = 'Tự động từ tiệc ' || (select doc_no from public.banquets where customer_name = 'Chị Đào'))),
  2::numeric,
  'phieu linh B4: gao 200gr x 10 phan = 2000gr = 2 kg (stock_uom)'
);

select is(
  (select uom from public.requisition_lines
    where requisition_id = (select id from public.requisitions
      where note = 'Tự động từ tiệc ' || (select doc_no from public.banquets where customer_name = 'Chị Đào'))),
  'kg',
  'phieu linh B4: dong NVL tinh theo stock_uom kg'
);

select ok(
  (public.recipe_save(
    'd0600000-0200-4000-8000-000000000201',
    '{"code": "MON04", "name": "Món chưa có định lượng", "kind": "dish", "sale_price": 10000, "lines": []}'::jsonb
  ) ->> 'ok')::boolean,
  'recipe_save MON04 (khong dong dinh luong) tra ok'
);

select ok(
  (public.banquet_save(
    'd0600000-0200-4000-8000-000000000201',
    jsonb_build_object(
      'customer_name', 'Chị Hoa', 'event_date',
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 2)::text,
      'start_time', '10:00', 'end_time', '12:00', 'hall', 'Sảnh B',
      'guests_count', 20,
      'dishes', jsonb_build_array(
        jsonb_build_object('recipe_id', (select id::text from public.recipes where code = 'MON04'), 'qty', 10, 'unit_price', 10000))
    )
  ) ->> 'ok')::boolean,
  'banquet_save tiec B5 (mon khong dinh luong) tra ok'
);

select ok(
  ((public.banquet_confirm(
    'd0600000-0200-4000-8000-000000000201',
    (select id from public.banquets where customer_name = 'Chị Hoa')
  ) ->> 'requisition_id') is null,
  'banquet_confirm B5 tra requisition_id NULL (mon khong co NVL)'
);

select is(
  (select status from public.banquets where customer_name = 'Chị Hoa'),
  'confirmed',
  'tiec B5 van xac nhan binh thuong du khong sinh phieu'
);

-- ---------------------------------------------------------------------------
-- 17. C11 — Tu sinh phieu linh nhap khi ghi ban mon (Q169).
--     MON03 x 7 phan -> ceil(7/10) = 1 me -> 1000gr gao = 1 kg.
-- ---------------------------------------------------------------------------
select ok(
  ((public.dish_sale_record(
    'd0600000-0200-4000-8000-000000000201',
    (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    (select id from public.recipes where code = 'MON03'),
    7, 60000
  ) ->> 'requisition_id') is not null,
  'dish_sale_record MON03 x 7 tra ve requisition_id'
);

select is(
  (select count(*) from public.requisition_lines
    where requisition_id = (select id from public.requisitions
      where note like 'Tự động từ bán món Cơm rang%' 
      order by created_at desc limit 1)),
  1::bigint,
  'phieu linh tu dong cua ban MON03 co 1 dong NVL'
);

select is(
  (select qty_stock from public.requisition_lines
    where requisition_id = (select id from public.requisitions
      where note like 'Tự động từ bán món Cơm rang%'
      order by created_at desc limit 1)),
  1::numeric,
  'phieu linh ban MON03: gao 1000gr x 1 me = 1 kg'
);

select * from finish();
rollback;
