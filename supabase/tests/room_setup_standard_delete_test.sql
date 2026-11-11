-- C7 pgTAP: RPC xoa tieu chuan setup phong `room_setup_standard_delete`
-- (migration 20261109526000).
-- Kiem tra: xoa id khong ton tai, quyen (chi `hk.standard.manage` tren
-- property cua dong moi xoa duoc — ke ca giam sat cua property khac),
-- xoa thanh cong tra ok + id, dong bien mat, xoa lai cung id bao loi,
-- vong upsert (room_setup_standard_set) -> xoa.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into public.organizations (id, name) values
  ('d2600000-0000-4000-8000-000000000001', 'C7 Org');

-- Moi property can 1 legal_entity rieng: properties.legal_entity_id unique.
insert into public.legal_entities (id, org_id, code, name) values
  ('d2600000-0000-4000-8000-000000000101', 'd2600000-0000-4000-8000-000000000001', 'C7', 'Entity C7'),
  ('d2600000-0000-4000-8000-000000000102', 'd2600000-0000-4000-8000-000000000001', 'C7B', 'Entity C7 B');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d2600000-0000-4000-8000-000000000201', 'd2600000-0000-4000-8000-000000000001', 'd2600000-0000-4000-8000-000000000101', 'PC71', 'Property C7 A', 'with_cc'),
  ('d2600000-0000-4000-8000-000000000202', 'd2600000-0000-4000-8000-000000000001', 'd2600000-0000-4000-8000-000000000102', 'PC72', 'Property C7 B', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('cai', 'Cái'),
  ('chai', 'Chai')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d2600000-0000-4000-8000-000000000401', 'd2600000-0000-4000-8000-000000000001', 'AMEN', 'Amenities', 'amenity');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels, is_temp) values
  ('d2600000-0000-4000-8000-000000000501', 'd2600000-0000-4000-8000-000000000001', 'ITM_BANCHAI', 'Bàn chải', 'd2600000-0000-4000-8000-000000000401', 'cai', false, false, null, array['contract', 'market'], false),
  ('d2600000-0000-4000-8000-000000000502', 'd2600000-0000-4000-8000-000000000001', 'ITM_NUOC', 'Nước suối', 'd2600000-0000-4000-8000-000000000401', 'chai', false, false, null, array['contract', 'market'], false);

insert into public.room_types (id, property_id, code, name, max_guests) values
  ('d2600000-0000-4000-8000-000000000b01', 'd2600000-0000-4000-8000-000000000201', 'DLX', 'Deluxe', 2),
  ('d2600000-0000-4000-8000-000000000b02', 'd2600000-0000-4000-8000-000000000202', 'STD', 'Standard', 2);

-- Tieu chuan thuoc property B (tao truc tiep truoc khi doi role sang
-- authenticated — bang chi co policy SELECT-only nen khong the tao qua
-- RLS; dung de kiem tra chan xoa cheo property).
insert into public.room_setup_standards
  (id, org_id, property_id, room_type_id, clean_type, item_id, qty, per_guest)
values
  ('d2600000-0000-4000-8000-000000000d02', 'd2600000-0000-4000-8000-000000000001', 'd2600000-0000-4000-8000-000000000202', 'd2600000-0000-4000-8000-000000000b02', 'checkout', 'd2600000-0000-4000-8000-000000000501', 1, false);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d2600000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-sup260@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d2600000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u2-att260@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.roles (id, org_id, code, name_vi) values
  ('d2600000-0000-4000-8000-000000000601', 'd2600000-0000-4000-8000-000000000001', 'hk_supervisor', 'Giám sát buồng'),
  ('d2600000-0000-4000-8000-000000000602', 'd2600000-0000-4000-8000-000000000001', 'hk_attendant', 'Nhân viên buồng');

insert into public.role_permissions (role_id, permission_code) values
  ('d2600000-0000-4000-8000-000000000601', 'hk.standard.manage'),
  ('d2600000-0000-4000-8000-000000000601', 'hk.trolley.operate'),
  ('d2600000-0000-4000-8000-000000000602', 'hk.trolley.operate');

-- Giam sat chi duoc gan o property A; nhan vien buong cung chi o A.
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d2600000-0000-4000-8000-000000000a01', 'd2600000-0000-4000-8000-000000000601', 'd2600000-0000-4000-8000-000000000201'),
  ('d2600000-0000-4000-8000-000000000a02', 'd2600000-0000-4000-8000-000000000602', 'd2600000-0000-4000-8000-000000000201');

create temp table t260_resp (key text primary key, resp jsonb);

create or replace function public._t260_as(p_user uuid)
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

set local role authenticated;

-- A. Xoa id khong ton tai (1).
select public._t260_as('d2600000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.room_setup_standard_delete(
    p_standard_id := 'd2600000-0000-4000-8000-000000000999'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: tieu chuan setup khong ton tai',
  'delete rejects unknown standard'
);

-- B. Tao 1 tieu chuan o property A bang RPC upsert co san (de xoa sau).
insert into t260_resp values ('stdA', public.room_setup_standard_set(
  p_property_id := 'd2600000-0000-4000-8000-000000000201',
  p_room_type_id := 'd2600000-0000-4000-8000-000000000b01',
  p_clean_type := 'checkout',
  p_item_id := 'd2600000-0000-4000-8000-000000000501',
  p_qty := 2
));

-- C. Nhan vien buong (chi hk.trolley.operate) khong xoa duoc (1).
select public._t260_as('d2600000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.room_setup_standard_delete(
    p_standard_id := (select (resp ->> 'id')::uuid from t260_resp where key = 'stdA')
  )$q$,
  '42501', 'ERR_FORBIDDEN:hk.standard.manage',
  'delete rejects user without hk.standard.manage'
);

-- D. Giam sat property A khong xoa duoc tieu chuan cua property B (1).
select public._t260_as('d2600000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.room_setup_standard_delete(
    p_standard_id := 'd2600000-0000-4000-8000-000000000d02'
  )$q$,
  '42501', 'ERR_FORBIDDEN:hk.standard.manage',
  'delete rejects standard of another property'
);

-- E. Giam sat xoa duoc tieu chuan cua property minh (3).
insert into t260_resp values ('delA', public.room_setup_standard_delete(
  p_standard_id := (select (resp ->> 'id')::uuid from t260_resp where key = 'stdA')
));
select is(
  (select resp ->> 'ok' from t260_resp where key = 'delA'),
  'true', 'delete returns ok'
);
select is(
  (select resp ->> 'id' from t260_resp where key = 'delA'),
  (select resp ->> 'id' from t260_resp where key = 'stdA'),
  'delete returns the deleted id'
);
select is(
  (select count(*) from public.room_setup_standards
   where id = (select (resp ->> 'id')::uuid from t260_resp where key = 'stdA')),
  0::bigint, 'deleted standard row is gone'
);

-- F. Xoa lai cung id bao loi (1).
select throws_ok(
  $q$select public.room_setup_standard_delete(
    p_standard_id := (select (resp ->> 'id')::uuid from t260_resp where key = 'stdA')
  )$q$,
  'P0001', 'ERR_INVALID_VALUE: tieu chuan setup khong ton tai',
  'delete of an already deleted standard rejects'
);

-- G. Vong upsert -> xoa (1).
insert into t260_resp values ('stdB', public.room_setup_standard_set(
  p_property_id := 'd2600000-0000-4000-8000-000000000201',
  p_room_type_id := 'd2600000-0000-4000-8000-000000000b01',
  p_clean_type := 'stayover',
  p_item_id := 'd2600000-0000-4000-8000-000000000502',
  p_qty := 1,
  p_per_guest := true
));
select lives_ok(
  $q$select public.room_setup_standard_delete(
    p_standard_id := (select (resp ->> 'id')::uuid from t260_resp where key = 'stdB')
  )$q$,
  'upserted standard can be deleted'
);
select is(
  (select count(*) from public.room_setup_standards
   where id = (select (resp ->> 'id')::uuid from t260_resp where key = 'stdB')),
  0::bigint, 'upserted then deleted standard row is gone'
);

select * from finish();
rollback;
