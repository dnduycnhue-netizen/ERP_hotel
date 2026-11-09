-- T-015 pgTAP: ma tam + gop ma + cron ma tam qua han.
-- Kiem tra: item_create_temp (ma TMP-xxxx, quyen, trung ten, nhom/DVT sai),
-- chan 72h o tang so cai (ERR_TEMP_ITEM_EXPIRED qua _post_move, ca ma tam
-- tuoi va ma thuong van ghi so duoc), item_merge (chuyen ton qua cap
-- merge_out/merge_in cung gia von, trang thai merged, quyen, sai trang
-- thai, trung ma, da gop, ky da khoa), temp_code_maintenance (alert
-- TEMP_ITEM_STALE info + dedupe), cau noi import T-014 (trigger +
-- backfill danh dau is_temp cho dong NO_CODE).
-- Chu y: pgTAP chua chay (khong co Docker tren VM). Backfill o migration
-- khong test truc tiep duoc (da chay truoc khi test ton tai) nen test
-- chay lai dung cau UPDATE do de kiem tra menh de WHERE.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(29);

-- 1. Setup Fixture
insert into public.organizations (id, name) values
  ('d0150000-1500-4000-8000-000000000001', 'T-015 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0150000-1500-4000-8000-000000000101', 'd0150000-1500-4000-8000-000000000001', 'T015', 'Entity T-015'),
  ('d0150000-1500-4000-8000-000000000102', 'd0150000-1500-4000-8000-000000000001', 'T015B', 'Entity T-015 B');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0150000-1500-4000-8000-000000000201', 'd0150000-1500-4000-8000-000000000001', 'd0150000-1500-4000-8000-000000000101', 'P015', 'Property T-015'),
  ('d0150000-1500-4000-8000-000000000202', 'd0150000-1500-4000-8000-000000000001', 'd0150000-1500-4000-8000-000000000102', 'P015B', 'Property T-015 B');

insert into public.warehouses (id, property_id, code, name, kind) values
  ('d0150000-1500-4000-8000-000000000301', 'd0150000-1500-4000-8000-000000000201', 'KHO015', 'Kho chinh T-015', 'main'),
  ('d0150000-1500-4000-8000-000000000302', 'd0150000-1500-4000-8000-000000000202', 'KHO015B', 'Kho chinh T-015 B', 'main');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'), ('cai', 'Cái')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d0150000-1500-4000-8000-000000000401', 'd0150000-1500-4000-8000-000000000001', 'RAU', 'Rau củ', 'food');

-- Ma thuong (dich gop) + ma tam cu 25h (cho cron) + ma tam het han 73h.
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0150000-1500-4000-8000-000000000501', 'd0150000-1500-4000-8000-000000000001', 'RAU-CACHUA', 'Cà chua', 'd0150000-1500-4000-8000-000000000401', 'kg'),
  ('d0150000-1500-4000-8000-000000000502', 'd0150000-1500-4000-8000-000000000001', 'RAU-DUACHUOT', 'Dưa chuột', 'd0150000-1500-4000-8000-000000000401', 'kg');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_temp, temp_created_at) values
  ('d0150000-1500-4000-8000-000000000503', 'd0150000-1500-4000-8000-000000000001', 'TMP-CU', 'Bí đỏ chợ', 'd0150000-1500-4000-8000-000000000401', 'kg', true, now() - interval '25 hours'),
  ('d0150000-1500-4000-8000-000000000504', 'd0150000-1500-4000-8000-000000000001', 'TMP-HETHAN', 'Ớt hiểm chợ', 'd0150000-1500-4000-8000-000000000401', 'kg', true, now() - interval '73 hours');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0150000-1500-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'purchaser015@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0150000-1500-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cc015@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0150000-1500-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer015@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0150000-1500-4000-8000-000000000a01', 'NV01501', 'Nhan vien mua hang'),
  ('d0150000-1500-4000-8000-000000000a02', 'NV01502', 'Cost Controller'),
  ('d0150000-1500-4000-8000-000000000a03', 'NV01503', 'Nguoi chi xem')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0150000-1500-4000-8000-000000000601', 'd0150000-1500-4000-8000-000000000001', 'r_pur015', 'Mua hang'),
  ('d0150000-1500-4000-8000-000000000602', 'd0150000-1500-4000-8000-000000000001', 'r_cc015', 'Cost Controller'),
  ('d0150000-1500-4000-8000-000000000603', 'd0150000-1500-4000-8000-000000000001', 'r_view015', 'Chi xem');

insert into public.role_permissions (role_id, permission_code) values
  ('d0150000-1500-4000-8000-000000000601', 'item.view'),
  ('d0150000-1500-4000-8000-000000000601', 'item.temp.create'),
  ('d0150000-1500-4000-8000-000000000602', 'item.view'),
  ('d0150000-1500-4000-8000-000000000602', 'item.temp.normalize'),
  ('d0150000-1500-4000-8000-000000000602', 'alert.receive.temp_item_stale'),
  ('d0150000-1500-4000-8000-000000000603', 'item.view');

-- r_pur015 + r_cc015 gan chain-wide (property_id null) de RPC chay duoc
-- o ca 2 KS (test ky khoa dung KS B).
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0150000-1500-4000-8000-000000000a01', 'd0150000-1500-4000-8000-000000000601', null),
  ('d0150000-1500-4000-8000-000000000a02', 'd0150000-1500-4000-8000-000000000602', null),
  ('d0150000-1500-4000-8000-000000000a03', 'd0150000-1500-4000-8000-000000000603', 'd0150000-1500-4000-8000-000000000201');

-- Chuyen sang role authenticated; doi user bang set_config request.jwt.claim.sub.
set local role authenticated;

-- Helper: dat lai JWT claim cho u1 (purchaser).
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a01","role":"authenticated"}', true);

-- 2. item_create_temp: tao duoc ma TMP-0001 (u1 purchaser).
select lives_ok(
  $q$select public.item_create_temp(
    'd0150000-1500-4000-8000-000000000201', 'Hành lá chợ', 'd0150000-1500-4000-8000-000000000401', 'kg'
  )$q$,
  'item_create_temp tao duoc ma tam'
);
select is(
  (select code from public.items where name = 'Hành lá chợ'),
  'TMP-0001',
  'ma tam sinh dung dinh dang TMP-0001'
);

-- 3. item_create_temp: nguoi chi xem (khong co item.temp.create) bi chan.
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a03","role":"authenticated"}', true);
select throws_ok(
  $q$select public.item_create_temp(
    'd0150000-1500-4000-8000-000000000201', 'Rau muống chợ', 'd0150000-1500-4000-8000-000000000401', 'kg'
  )$q$,
  'ERR_FORBIDDEN:item.temp.create',
  'viewer khong tao duoc ma tam'
);

-- Tro lai u1 (purchaser).
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a01","role":"authenticated"}', true);

-- 4. Trung ten (name_norm) -> ERR_INVALID_VALUE.
select throws_ok(
  $q$select public.item_create_temp(
    'd0150000-1500-4000-8000-000000000201', 'Cà chua', 'd0150000-1500-4000-8000-000000000401', 'kg'
  )$q$,
  'ERR_INVALID_VALUE',
  'ten trung voi ma da co bi chan'
);

-- 5. Nhom khong ton tai -> ERR_CONFIG_ITEM_GROUP.
select throws_ok(
  $q$select public.item_create_temp(
    'd0150000-1500-4000-8000-000000000201', 'Mướp chợ', 'd0150000-1500-4000-8000-000000000499', 'kg'
  )$q$,
  'ERR_CONFIG_ITEM_GROUP',
  'nhom khong thuoc to chuc bi chan'
);

-- 6. DVT khong ton tai -> ERR_UOM_UNKNOWN.
select throws_ok(
  $q$select public.item_create_temp(
    'd0150000-1500-4000-8000-000000000201', 'Mướp chợ', 'd0150000-1500-4000-8000-000000000401', 'thung'
  )$q$,
  'ERR_UOM_UNKNOWN',
  'DVT la bi chan'
);

-- 7. Ma tam thu 2 chay so tiep: TMP-0002.
select is(
  (select public.item_create_temp(
    'd0150000-1500-4000-8000-000000000201', 'Mướp chợ', 'd0150000-1500-4000-8000-000000000401', 'kg'
  ) ->> 'code'),
  'TMP-0002',
  'ma tam thu 2 la TMP-0002'
);

-- 8. Cron: ma tam 25h tao 1 alert TEMP_ITEM_STALE (info), chay lai khong tao them.
select is(
  (select public.temp_code_maintenance() ->> 'alerts_created'),
  '1',
  'cron tao 1 alert cho ma tam 25h'
);
select is(
  (select severity from public.alerts where code = 'TEMP_ITEM_STALE' order by created_at limit 1),
  'info',
  'alert TEMP_ITEM_STALE muc info'
);
select is(
  (select public.temp_code_maintenance() ->> 'alerts_created'),
  '0',
  'chay lai cron khong tao alert trung (dedupe theo alert chua ack)'
);

-- 9. Chan 72h: nhan ma tam 73h qua _post_move -> ERR_TEMP_ITEM_EXPIRED.
select throws_ok(
  $q$select public._post_move(
    'd0150000-1500-4000-8000-000000000101', 'd0150000-1500-4000-8000-000000000201',
    'd0150000-1500-4000-8000-000000000301', 'd0150000-1500-4000-8000-000000000504',
    null, 'receipt', 10, 5000,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'test', gen_random_uuid()
  )$q$,
  'ERR_TEMP_ITEM_EXPIRED',
  'ma tam 73h bi chan nhan hang'
);

-- 10. Ma tam tuoi (TMP-0001) nhan binh thuong.
select lives_ok(
  $q$select public._post_move(
    'd0150000-1500-4000-8000-000000000101', 'd0150000-1500-4000-8000-000000000201',
    'd0150000-1500-4000-8000-000000000301',
    (select id from public.items where code = 'TMP-0001'),
    null, 'receipt', 10, 5000,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'test', gen_random_uuid()
  )$q$,
  'ma tam tuoi nhan hang binh thuong'
);

-- 11. Ma thuong nhan binh thuong (trigger khong anh huong ma thuong).
select lives_ok(
  $q$select public._post_move(
    'd0150000-1500-4000-8000-000000000101', 'd0150000-1500-4000-8000-000000000201',
    'd0150000-1500-4000-8000-000000000301', 'd0150000-1500-4000-8000-000000000501',
    null, 'receipt', 20, 4000,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'test', gen_random_uuid()
  )$q$,
  'ma thuong nhan hang binh thuong'
);

-- 12. item_merge: gop TMP-0001 (ton 10 kg @ 5000) vao RAU-CACHUA (u2 cost_controller).
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a02","role":"authenticated"}', true);
select lives_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000201',
    (select id from public.items where code = 'TMP-0001'),
    'd0150000-1500-4000-8000-000000000501'
  )$q$,
  'item_merge gop duoc ma tam co ton'
);
select is(
  (select status from public.items where code = 'TMP-0001'),
  'merged',
  'ma tam chuyen sang merged'
);
select is(
  (select qty::text from public.stock_balances
   where warehouse_id = 'd0150000-1500-4000-8000-000000000301'
     and item_id = 'd0150000-1500-4000-8000-000000000501'),
  '30.0000',
  'ton ma dich = 20 cu + 10 chuyen sang'
);
select ok(
  exists (select 1 from public.stock_moves
          where item_id = (select id from public.items where code = 'TMP-0001')
            and move_type = 'merge_out' and qty = -10),
  'co but toan merge_out -10 cua ma tam'
);
select ok(
  exists (select 1 from public.stock_moves
          where item_id = 'd0150000-1500-4000-8000-000000000501'
            and move_type = 'merge_in' and qty = 10),
  'co but toan merge_in +10 cua ma dich'
);
select is(
  (select unit_cost::text from public.stock_moves
   where item_id = 'd0150000-1500-4000-8000-000000000501' and move_type = 'merge_in'),
  (select unit_cost::text from public.stock_moves
   where item_id = (select id from public.items where code = 'TMP-0001') and move_type = 'merge_out'),
  'merge_in cung gia von voi merge_out'
);

-- 13. item_merge: purchaser (khong co item.temp.normalize) bi chan.
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a01","role":"authenticated"}', true);
select throws_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000201',
    (select id from public.items where code = 'TMP-0002'),
    'd0150000-1500-4000-8000-000000000501'
  )$q$,
  'ERR_FORBIDDEN:item.temp.normalize',
  'purchaser khong gop duoc ma tam'
);

-- Tro lai u2 (cost_controller).
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a02","role":"authenticated"}', true);

-- 14. Ma nguon khong phai ma tam -> ERR_INVALID_STATUS.
select throws_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000201',
    'd0150000-1500-4000-8000-000000000501',
    'd0150000-1500-4000-8000-000000000502'
  )$q$,
  'ERR_INVALID_STATUS',
  'ma nguon khong phai ma tam bi chan'
);

-- 15. Ma dich la ma tam -> ERR_INVALID_STATUS.
select throws_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000201',
    (select id from public.items where code = 'TMP-0002'),
    'd0150000-1500-4000-8000-000000000503'
  )$q$,
  'ERR_INVALID_STATUS',
  'ma dich la ma tam bi chan'
);

-- 16. Nguon trung dich -> ERR_INVALID_VALUE.
select throws_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000201',
    (select id from public.items where code = 'TMP-0002'),
    (select id from public.items where code = 'TMP-0002')
  )$q$,
  'ERR_INVALID_VALUE',
  'nguon trung dich bi chan'
);

-- 17. Ma da gop roi khong gop lai duoc.
select throws_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000201',
    (select id from public.items where code = 'TMP-0001'),
    'd0150000-1500-4000-8000-000000000502'
  )$q$,
  'ERR_INVALID_STATUS',
  'ma da merged khong gop lai duoc'
);

-- 18. Ky da khoa: ma tam o KS B co ton, khoa ky hien tai cua phap nhan B -> chan gop.
select lives_ok(
  $q$select public._post_move(
    'd0150000-1500-4000-8000-000000000102', 'd0150000-1500-4000-8000-000000000202',
    'd0150000-1500-4000-8000-000000000302',
    (select public.item_create_temp(
      'd0150000-1500-4000-8000-000000000202', 'Bí xanh chợ B', 'd0150000-1500-4000-8000-000000000401', 'kg'
    ) ->> 'id')::uuid,
    null, 'receipt', 5, 3000,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'test', gen_random_uuid()
  )$q$,
  'nhan ma tam o KS B truoc khi khoa ky'
);

-- Khoa ky hien tai cua phap nhan B (role postgres, insert truc tiep).
set local role postgres;
insert into public.accounting_periods (legal_entity_id, year, month, status) values
  ('d0150000-1500-4000-8000-000000000102',
   extract(year from (now() at time zone 'Asia/Ho_Chi_Minh'))::integer,
   extract(month from (now() at time zone 'Asia/Ho_Chi_Minh'))::integer,
   'closed');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0150000-1500-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0150000-1500-4000-8000-000000000a02","role":"authenticated"}', true);
select throws_ok(
  $q$select public.item_merge(
    'd0150000-1500-4000-8000-000000000202',
    (select id from public.items where code = 'TMP-0003'),
    'd0150000-1500-4000-8000-000000000502'
  )$q$,
  'ERR_PERIOD_CLOSED',
  'ma tam co ton trong ky da khoa khong gop duoc'
);

-- 19. Cau noi import T-014: trigger danh dau is_temp khi dong NO_CODE commit.
-- (role postgres vi import_rows khong co policy ghi truc tiep cho client.)
set local role postgres;
insert into public.import_batches (id, org_id, property_id, kind, file_name, status) values
  ('d0150000-1500-4000-8000-000000000901', 'd0150000-1500-4000-8000-000000000001', 'd0150000-1500-4000-8000-000000000201', 'items', 'test.xlsx', 'validated');
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0150000-1500-4000-8000-000000000505', 'd0150000-1500-4000-8000-000000000001', 'TP-0001', 'Su hào import', 'd0150000-1500-4000-8000-000000000401', 'kg');
insert into public.import_rows (id, batch_id, row_no, raw_data, issues, status) values
  ('d0150000-1500-4000-8000-000000000902', 'd0150000-1500-4000-8000-000000000901', 1, '{}'::jsonb,
   '[{"code":"NO_CODE","field":"code","message":"Thiếu mã","severity":"warning"}]'::jsonb, 'ok');
update public.import_rows
set status = 'committed', target_id = 'd0150000-1500-4000-8000-000000000505'
where id = 'd0150000-1500-4000-8000-000000000902';
select is(
  (select is_temp from public.items where id = 'd0150000-1500-4000-8000-000000000505'),
  true,
  'trigger danh dau is_temp cho dong NO_CODE khi commit'
);
select ok(
  (select temp_created_at is not null from public.items where id = 'd0150000-1500-4000-8000-000000000505'),
  'temp_created_at duoc set khi danh dau'
);

-- 20. Backfill: chay lai dung cau UPDATE cua migration cho dong NO_CODE da
-- commit san (truong hop dong commit truoc khi trigger ton tai).
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('d0150000-1500-4000-8000-000000000506', 'd0150000-1500-4000-8000-000000000001', 'TP-0002', 'Cải thảo import', 'd0150000-1500-4000-8000-000000000401', 'kg');
insert into public.import_rows (id, batch_id, row_no, raw_data, issues, status, target_id) values
  ('d0150000-1500-4000-8000-000000000903', 'd0150000-1500-4000-8000-000000000901', 2, '{}'::jsonb,
   '[{"code":"NO_CODE","field":"code","message":"Thiếu mã","severity":"warning"}]'::jsonb, 'committed', 'd0150000-1500-4000-8000-000000000506');
update public.items i
set is_temp = true,
    temp_created_at = coalesce(i.temp_created_at, i.created_at),
    updated_at = now()
from public.import_rows r
where r.target_id = i.id
  and r.status = 'committed'
  and exists (
    select 1 from jsonb_array_elements(r.issues) x
    where x ->> 'code' = 'NO_CODE'
  )
  and not i.is_temp;
select is(
  (select is_temp from public.items where id = 'd0150000-1500-4000-8000-000000000506'),
  true,
  'backfill danh dau is_temp cho dong NO_CODE da commit truoc'
);

select * from finish();
rollback;
