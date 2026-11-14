-- standard_warehouses_test.sql (Q273, migration 20261109579000). Chay trong begin...rollback.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

insert into public.organizations (id, name) values ('a5a00000-0000-4000-8000-000000000001', 'Q273 Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a5a00000-0000-4000-8000-000000000101', 'a5a00000-0000-4000-8000-000000000001', 'Q273', 'Entity Q273');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a5a00000-0000-4000-8000-000000000201', 'a5a00000-0000-4000-8000-000000000001', 'a5a00000-0000-4000-8000-000000000101', 'PQ273', 'Property Q273', 'with_cc');

select throws_ok(
  $q$select public._inventory_transit_wh('a5a00000-0000-4000-8000-000000000201')$q$,
  'P0001', 'ERR_TRANSIT_WAREHOUSE_MISSING', 'missing transit warehouse gives a specific error code');

select is(public.seed_standard_warehouses('a5a00000-0000-4000-8000-000000000201'), 4, 'seeds 4 standard warehouses');
select is((select count(*) from public.warehouses where property_id = 'a5a00000-0000-4000-8000-000000000201' and kind in ('main','transit','quarantine','disposal','minibar_main')), 5::bigint, 'main + 4 standard kinds exist');
select isnt(public._inventory_transit_wh('a5a00000-0000-4000-8000-000000000201'), null, 'transit warehouse now resolves');
select is(public.seed_standard_warehouses('a5a00000-0000-4000-8000-000000000201'), 0, 'idempotent: second run adds nothing');
select is((select count(*) from public.warehouses where property_id = 'a5a00000-0000-4000-8000-000000000201'), 5::bigint, 'no duplicates after second run');

select * from finish();
rollback;
