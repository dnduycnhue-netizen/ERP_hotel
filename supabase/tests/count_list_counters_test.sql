-- T-033 pgTAP: count_list_counters — danh sach nguoi duoc dem tai kho.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

insert into public.organizations (id, name) values
  ('d0330000-0000-4000-8000-000000000001', 'T-033 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0330000-0000-4000-8000-000000000101', 'd0330000-0000-4000-8000-000000000001', 'T033', 'Entity T-033');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d0330000-0000-4000-8000-000000000201', 'd0330000-0000-4000-8000-000000000001', 'd0330000-0000-4000-8000-000000000101', 'P0331', 'Property T-033', 'with_cc');

insert into public.outlet_types (id, org_id, code, name) values
  ('d0330000-0000-4000-8000-000000000801', 'd0330000-0000-4000-8000-000000000001', 'KIT', 'Bếp');

insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('d0330000-0000-4000-8000-000000000802', 'd0330000-0000-4000-8000-000000000201', 'd0330000-0000-4000-8000-000000000801', 'KITCHEN', 'Bếp chính');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('d0330000-0000-4000-8000-000000000301', 'd0330000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('d0330000-0000-4000-8000-000000000302', 'd0330000-0000-4000-8000-000000000201', 'WH_KIT', 'Kho bếp', 'outlet', 'd0330000-0000-4000-8000-000000000802');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0330000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-stk033@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0330000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-chef033@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0330000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-0000-000000000000', 'authenticated', 'authenticated', 'u3-cc033@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0330000-0000-4000-8000-000000000a04', '00000000-0000-4000-8000-0000-000000000000', 'authenticated', 'authenticated', 'u4-bar033@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0330000-0000-4000-8000-000000000a05', '00000000-0000-4000-8000-0000-000000000000', 'authenticated', 'authenticated', 'u5-rec033@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0330000-0000-4000-8000-000000000a01', 'NV03301', 'Thủ kho'),
  ('d0330000-0000-4000-8000-000000000a02', 'NV03302', 'Bếp trưởng'),
  ('d0330000-0000-4000-8000-000000000a03', 'NV03303', 'Cost Controller'),
  ('d0330000-0000-4000-8000-000000000a04', 'NV03304', 'Pha chế'),
  ('d0330000-0000-4000-8000-000000000a05', 'NV03305', 'Nhận hàng')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;

insert into public.roles (id, org_id, code, name_vi) values
  ('d0330000-0000-4000-8000-000000000601', 'd0330000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d0330000-0000-4000-8000-000000000602', 'd0330000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('d0330000-0000-4000-8000-000000000603', 'd0330000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('d0330000-0000-4000-8000-000000000604', 'd0330000-0000-4000-8000-000000000001', 'bartender', 'Pha chế'),
  ('d0330000-0000-4000-8000-000000000605', 'd0330000-0000-4000-8000-000000000001', 'receiver', 'Nhận hàng');

insert into public.role_permissions (role_id, permission_code) values
  ('d0330000-0000-4000-8000-000000000601', 'count.open'),
  ('d0330000-0000-4000-8000-000000000601', 'count.perform'),
  ('d0330000-0000-4000-8000-000000000602', 'count.perform'),
  ('d0330000-0000-4000-8000-000000000603', 'count.view_variance'),
  ('d0330000-0000-4000-8000-000000000604', 'count.perform'),
  ('d0330000-0000-4000-8000-000000000605', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id, warehouse_ids) values
  ('d0330000-0000-4000-8000-000000000a01', 'd0330000-0000-4000-8000-000000000601', 'd0330000-0000-4000-8000-000000000201', null),
  ('d0330000-0000-4000-8000-000000000a02', 'd0330000-0000-4000-8000-000000000602', 'd0330000-0000-4000-8000-000000000201', null),
  ('d0330000-0000-4000-8000-000000000a03', 'd0330000-0000-4000-8000-000000000603', 'd0330000-0000-4000-8000-000000000201', null),
  ('d0330000-0000-4000-8000-000000000a04', 'd0330000-0000-4000-8000-000000000604', 'd0330000-0000-4000-8000-000000000201', array['d0330000-0000-4000-8000-000000000302'::uuid]),
  ('d0330000-0000-4000-8000-000000000a05', 'd0330000-0000-4000-8000-000000000605', 'd0330000-0000-4000-8000-000000000201', null);

create or replace function public._t033_as(p_user uuid)
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

-- 1. Kho chinh: chi thu kho + bep truong (khong co cost controller, pha che gioi han kho bep, nhan hang).
select public._t033_as('d0330000-0000-4000-8000-000000000a01');
select is(
  (select count(*) from public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000301'
  )),
  2::bigint,
  'kho chinh tra 2 nguoi dem'
);
select ok(
  (select exists (select 1 from public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000301'
  ) where id = 'd0330000-0000-4000-8000-000000000a01')),
  'kho chinh co thu kho'
);
select ok(
  (select exists (select 1 from public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000301'
  ) where id = 'd0330000-0000-4000-8000-000000000a02')),
  'kho chinh co bep truong'
);

-- 2. Kho bep: them pha che (gioi han theo kho).
select is(
  (select count(*) from public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000302'
  )),
  3::bigint,
  'kho bep tra 3 nguoi dem'
);

-- 3. Nguoi khong co count.open khong goi duoc.
select public._t033_as('d0330000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000301'
  )$q$,
  '42501',
  'ERR_FORBIDDEN:count.open',
  'bep truong khong co count.open bi chan'
);

-- 4. Tham so null va kho khong thuoc property.
select public._t033_as('d0330000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    null
  )$q$,
  'P0001',
  'ERR_INVALID_VALUE',
  'warehouse null bi chan'
);
select throws_ok(
  $q$select public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000999'
  )$q$,
  'P0001',
  'ERR_WAREHOUSE_NOT_FOUND',
  'warehouse khong ton tai bi chan'
);

-- 5. Nguoi dem bi vo hieu (active = false) khong xuat hien.
update public.profiles set active = false
where id = 'd0330000-0000-4000-8000-000000000a02';
select is(
  (select count(*) from public.count_list_counters(
    'd0330000-0000-4000-8000-000000000201',
    'd0330000-0000-4000-8000-000000000301'
  )),
  1::bigint,
  'nguoi dem vo hieu khong duoc liet ke'
);

select * from finish();
rollback;
