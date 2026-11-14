-- Q271 (14/11/2026): bao cao dem 13-14/11 (B-21, M10 F-2/F-3).
--  * _module_guard chan ca DELETE (truoc day chi INSERT/UPDATE) tren 13 bang module.
--  * banquet_dishes / buffet_session_dishes khong co property_id -> guard lay property
--    qua bang cha (banquets / buffet_sessions).
--  * recipes / recipe_versions / recipe_lines la danh muc DUNG CHUNG CAP CHUOI (org_id,
--    khong co property_id) nen KHONG the chan theo tung khach san — co chu dich.
create or replace function public._module_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    perform public.require_module(old.property_id, tg_argv[0]);
    return old;
  end if;
  perform public.require_module(new.property_id, tg_argv[0]);
  return new;
end;
$$;

create or replace function public._module_guard_child()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row jsonb := to_jsonb(case when tg_op = 'DELETE' then old else new end);
  v_property uuid;
begin
  execute format('select property_id from public.%I where id = $1', tg_argv[1])
    into v_property
    using (v_row ->> tg_argv[2])::uuid;
  if v_property is not null then
    perform public.require_module(v_property, tg_argv[0]);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
revoke all on function public._module_guard_child() from public, anon, authenticated;

do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('hk_frontdesk', 'minibar_checks'),
      ('hk_frontdesk', 'minibar_check_lines'),
      ('hk_frontdesk', 'minibar_price_list'),
      ('hk_frontdesk', 'pms_daily_stats'),
      ('hk_frontdesk', 'room_setup_standards'),
      ('hk_frontdesk', 'trolley_par_levels'),
      ('hk_frontdesk', 'trolley_shifts'),
      ('restaurant', 'banquets'),
      ('restaurant', 'banquet_halls'),
      ('restaurant', 'buffet_sessions'),
      ('restaurant', 'dish_sales'),
      ('restaurant', 'pos_imports'),
      ('restaurant', 'pos_import_lines')
    ) as t(module, tbl)
  loop
    execute format('drop trigger if exists trg_%1$s_module_guard on public.%1$s', r.tbl);
    execute format(
      'create trigger trg_%1$s_module_guard before insert or update or delete on public.%1$s '
      'for each row execute function public._module_guard(%2$L)', r.tbl, r.module);
  end loop;
end $$;

drop trigger if exists trg_banquet_dishes_module_guard on public.banquet_dishes;
create trigger trg_banquet_dishes_module_guard
  before insert or update or delete on public.banquet_dishes
  for each row execute function public._module_guard_child('restaurant', 'banquets', 'banquet_id');

drop trigger if exists trg_buffet_session_dishes_module_guard on public.buffet_session_dishes;
create trigger trg_buffet_session_dishes_module_guard
  before insert or update or delete on public.buffet_session_dishes
  for each row execute function public._module_guard_child('restaurant', 'buffet_sessions', 'session_id');
