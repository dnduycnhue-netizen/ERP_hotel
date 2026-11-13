-- seed-demo-rooms.sql — DU LIEU DEMO phong + xe day + bep/nha hang cho SONHOIAN (Q261).
-- KHONG phai migration. Idempotent. Du lieu GIA LAP de van hanh thu (he thong dang xay dung).
--   * 3 loai phong (STD/DLX/SUI) + 30 phong (tang 1-3) — dat ten "Demo".
--   * Outlet Buong phong + 2 kho xe day (TROLLEY_1/2); outlet Nha hang + Bep (kho outlet).
--   * Chuan setup phong (room_setup_standards) va muc par xe day — dinh muc THAM KHAO tu
--     file amenities thang 5/2019 (khoi §5/§6 cua seed-sample-data.sql, chay lai sau khi co phong).
--   * Kho minibar tung phong tu tao khi dung (migration 460000) — khong can seed.
-- Go bo: delete rooms/room_types/outlets/warehouses co ma DEMO (chi khi chua co chung tu).
begin;
select set_config('seed.org_id', '00dc6aeb-5e34-4e01-9b80-032a72b16d71', true);
select set_config('seed.property_id', '7e37858d-58ed-4924-bb8f-9d56be9c620b', true);

insert into public.room_types (property_id, code, name, max_guests)
select '7e37858d-58ed-4924-bb8f-9d56be9c620b', v.code, v.name, v.max_guests
from (values ('STD', 'Standard (Demo)', 2), ('DLX', 'Deluxe (Demo)', 3), ('SUI', 'Suite (Demo)', 4)) as v(code, name, max_guests)
where not exists (select 1 from public.room_types x where x.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and x.code = v.code);

insert into public.rooms (property_id, room_type_id, room_no, floor)
select '7e37858d-58ed-4924-bb8f-9d56be9c620b', rt.id, r.room_no, r.floor
from (
  select (100 + g)::text as room_no, 1 as floor, 'STD' as tcode from generate_series(1, 10) g
  union all select (200 + g)::text, 2, 'DLX' from generate_series(1, 14) g
  union all select (300 + g)::text, 3, 'SUI' from generate_series(1, 6) g
) r
join public.room_types rt on rt.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and rt.code = r.tcode
where not exists (select 1 from public.rooms x where x.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and x.room_no = r.room_no);

update public.properties set rooms_count = (select count(*) from public.rooms where property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b')
where id = '7e37858d-58ed-4924-bb8f-9d56be9c620b';

-- Outlet + kho: Buong phong (xe day) va Nha hang / Bep.
insert into public.outlets (property_id, outlet_type_id, code, name)
select '7e37858d-58ed-4924-bb8f-9d56be9c620b', t.id, v.code, v.name
from (values ('HOUSEKEEPING', 'HK-DEMO', 'Buồng phòng (Demo)'), ('RESTAURANT', 'NH-DEMO', 'Nhà hàng (Demo)'), ('KITCHEN', 'BEP-DEMO', 'Bếp (Demo)')) as v(type_code, code, name)
join public.outlet_types t on t.org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and t.code = v.type_code
where not exists (select 1 from public.outlets x where x.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and x.code = v.code);

insert into public.warehouses (property_id, outlet_id, code, name, kind)
select '7e37858d-58ed-4924-bb8f-9d56be9c620b', o.id, v.code, v.name, v.kind
from (values
  ('HK-DEMO', 'TROLLEY_1', 'Xe đẩy 1 (Demo)', 'trolley'),
  ('HK-DEMO', 'TROLLEY_2', 'Xe đẩy 2 (Demo)', 'trolley'),
  ('BEP-DEMO', 'KHO_BEP', 'Kho bếp (Demo)', 'outlet'),
  ('NH-DEMO', 'KHO_NH', 'Kho nhà hàng (Demo)', 'outlet')
) as v(outlet_code, code, name, kind)
join public.outlets o on o.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and o.code = v.outlet_code
where not exists (select 1 from public.warehouses x where x.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and x.code = v.code);

do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.room_setup_standards (org_id, property_id, room_type_id, clean_type, item_id, qty, per_guest)
  select v_org_id, v_property_id, rt.id, 'checkout', i.id, v.qty, false
  from (values
  ('AMN-GIAY-VS', 0.7174),
  ('AMN-TRA-COZY', 0.4868),
  ('AMN-DUONG', 0.3906),
  ('AMN-CAPHE', 0.7736),
  ('AMN-XAPHONG', 0.3753),
  ('AMN-BANCHAI', 0.8868),
  ('AMN-DAO', 0.0196),
  ('AMN-TUIVS', 0.2826),
  ('AMN-LUOC', 0.3191),
  ('AMN-BONG', 0.4043),
  ('AMN-CHUPTOC', 0.2298),
  ('CPM-DASANI', 1.9396)
  ) as v(code, qty)
  join public.items i on i.org_id = v_org_id and i.code = v.code
  join public.room_types rt on rt.property_id = v_property_id
  on conflict (room_type_id, clean_type, item_id, per_guest) do nothing;
  get diagnostics v_n = row_count;
  raise notice '§5 room_setup_standards: % dòng mới (kỳ vọng 12 x số loại phòng)', v_n;
end;
$seed$;

do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.trolley_par_levels (org_id, property_id, trolley_warehouse_id, item_id, par_qty)
  select v_org_id, v_property_id, w.id, i.id, v.par_qty
  from (values
  ('AMN-GIAY-VS', 62),
  ('AMN-TRA-COZY', 100),
  ('AMN-DUONG', 100),
  ('AMN-CAPHE', 100),
  ('AMN-XAPHONG', 60),
  ('AMN-BANCHAI', 110),
  ('AMN-DAO', 6),
  ('AMN-TUIVS', 60),
  ('AMN-LUOC', 60),
  ('AMN-BONG', 60),
  ('AMN-CHUPTOC', 60),
  ('CPM-DASANI', 125)
  ) as v(code, par_qty)
  join public.items i on i.org_id = v_org_id and i.code = v.code
  join public.warehouses w on w.property_id = v_property_id and w.kind = 'trolley'
  on conflict (trolley_warehouse_id, item_id) do nothing;
  get diagnostics v_n = row_count;
  raise notice '§6 trolley_par_levels: % dòng mới (kỳ vọng 12 x số xe đẩy)', v_n;
end;
$seed$;

commit;
