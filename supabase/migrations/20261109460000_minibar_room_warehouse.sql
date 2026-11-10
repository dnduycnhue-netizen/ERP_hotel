-- ===========================================================================
-- Minibar fix (workstream 7): kho phong + kho minibar tong tu tao khi thieu,
-- sua lich doi soat ve dung 23:30 gio VN.
--
-- NGUYEN NHAN GOC (dieu tra tu code + seed, khong doan):
--   `_minibar_room_wh()` tra NULL khi phong chua co kho `minibar_room` thi
--   `minibar_request_check` / `minibar_refill` / `minibar_confirm_charge`
--   deu nem `ERR_INVALID_VALUE` (UI hien "Du lieu khong hop le") — toan bo
--   luong minibar chet o buoc dau tien.
--   Khong co duong nao tao duoc kho phong tren production:
--     1. `20261109140000_golive_init_org_data.sql` chi tao 5 kho chuan
--        (main/transit/quarantine/disposal/minibar_main) — khong co phong,
--        khong co kho `minibar_room`.
--     2. Form tao phong (`saveRoomAction`) chi tao phong.
--     3. Form tao kho (`warehouses-manager.tsx`) khong co lua chon
--        `minibar_room`, va `saveWarehouseAction` khong gui `room_id` —
--        du co gui thi check constraint
--        `(kind = 'minibar_room') = (room_id is not null)` cung chan.
--     4. Kho phong chi ton tai trong `supabase/seed.sql` (dev local) va
--        trong fixture cua `supabase/tests/minibar_test.sql` (chen tay
--        bang SQL) — vi vay test/dev chay duoc, production thi khong.
--   Cung vay voi kho `minibar_main`: khach san tao sau go-live khong co
--   kho nay (khong co trigger tao kho chuan khi them property).
--
-- CACH SUA (khong doi RPC, khong doi quyen — Q60/Q61 la viec cua
-- workstream 3):
--   1. Hai helper noi bo `_minibar_room_wh` / `_minibar_main_wh` (T-035)
--      doi thanh "tim, thieu thi tao" (ensure): phong/khach san nao chua
--      co kho thi tu tao kho dung quy uoc ma (`MINIBAR_<so phong>` /
--      `MINIBAR_MAIN`) ngay trong lan goi RPC minibar dau tien. Ba RPC
--      goi helper (request_check, refill, confirm_charge) duoc sua
--      khong can doi lai code.
--      KHONG dung trigger AFTER INSERT tren `rooms`: seed.sql chen kho
--      phong bang `on conflict (id) do nothing` — trigger tao truoc
--      cung ma kho se lam `supabase db reset` vo unique (property, code).
--      Xem Q151.
--   2. Backfill: tao kho phong cho moi phong hien co chua co kho, va
--      kho `minibar_main` cho moi property hien co chua co kho nay.
--      `on conflict do nothing` nen chay lai an toan.
--   3. Lich pg_cron `minibar-reconcile-daily` dang la `'30 23 * * *'`
--      theo gio UTC = 06:30 gio VN hom sau, khong phai 23:30 gio VN nhu
--      dac ta T-035. Quy uoc lich trong repo la gio UTC (T-045: ban tin
--      07:30 VN = '30 0' UTC; T-042: 01:00 VN = '0 18' UTC) nen doi
--      thanh `'30 16 * * *'` (= 23:30 VN).
--
-- CAC NGHI VAN DA KIEM TRA (xem bao cao workstream):
--   Q58 FIFO: LOAI — mac dinh `costing_method = 'moving_avg'`
--     (org_access.sql); lop FIFO chi theo phap nhan, receipt tao lop,
--     transfer_in khong tao/khong tieu lop nen ban minibar tieu lop
--     receipt binh thuong. Chi lech o truong hop bien (vd adjust_count
--     duong khong tao lop) — giu nguyen Q58 cho Duy chot, khong sua
--     `_post_move`.
--   Q60/Q61: DUNG co che (items_select doi `item.view`,
--     stock_balances doi `stock.view_qty`) nhung la pham vi workstream 3,
--     khong lam lai o day.
--   RLS chan doc: LOAI — rooms_select mo cho moi user trong property;
--     minibar_*_select gom du quyen; warehouses_select qua
--     my_warehouse_ids (scope null = tat ca kho).
--   Par level: KHONG phai dieu kien tien quyet — code minibar khong doc
--     `room_setup_standards`/`trolley_par_levels` (chi xe day T-034 doc).
--   Phong / mat hang / bang gia that: van phai do Duy/team nhap tay
--     (khong tu bia du lieu that) — xem Q153.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Helper `_minibar_room_wh`: tim kho phong, thieu thi tao.
--    Chi goi tu RPC SECURITY DEFINER (nhu cu) — ham chay voi quyen owner
--    nen vuot RLS khi insert vao warehouses; audit trigger ghi
--    actor = auth.uid() (nullable) nen an toan ca khi goi tu cron/backfill.
-- ---------------------------------------------------------------------------
create or replace function public._minibar_room_wh(p_room_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wh uuid;
  v_room public.rooms%rowtype;
begin
  select w.id into v_wh
  from public.warehouses w
  where w.room_id = p_room_id and w.kind = 'minibar_room'
  order by w.created_at
  limit 1;
  if v_wh is not null then
    return v_wh;
  end if;

  select * into v_room from public.rooms r where r.id = p_room_id;
  if not found then
    return null;
  end if;

  insert into public.warehouses (property_id, room_id, code, name, kind, created_by)
  values (
    v_room.property_id, p_room_id,
    'MINIBAR_' || v_room.room_no,
    'Minibar phòng ' || v_room.room_no,
    'minibar_room', auth.uid()
  )
  on conflict do nothing;

  select w.id into v_wh
  from public.warehouses w
  where w.room_id = p_room_id and w.kind = 'minibar_room'
  order by w.created_at
  limit 1;
  return v_wh;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Helper `_minibar_main_wh`: tim kho minibar tong, thieu thi tao.
--    Ly do nhu muc 1: property tao sau go-live khong co kho nay vi khong
--    co trigger tao kho chuan khi them property.
-- ---------------------------------------------------------------------------
create or replace function public._minibar_main_wh(p_property_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_wh uuid;
begin
  select w.id into v_wh
  from public.warehouses w
  where w.property_id = p_property_id and w.kind = 'minibar_main'
  order by w.created_at
  limit 1;
  if v_wh is not null then
    return v_wh;
  end if;

  if not exists (
    select 1 from public.properties p where p.id = p_property_id
  ) then
    return null;
  end if;

  insert into public.warehouses (property_id, code, name, kind, created_by)
  values (
    p_property_id, 'MINIBAR_MAIN', 'Kho minibar tổng', 'minibar_main',
    auth.uid()
  )
  on conflict do nothing;

  select w.id into v_wh
  from public.warehouses w
  where w.property_id = p_property_id and w.kind = 'minibar_main'
  order by w.created_at
  limit 1;
  return v_wh;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Backfill: kho phong cho phong hien co + kho minibar tong cho
--    property hien co. Khong chen audit bang tay — trigger audit cua
--    warehouses ghi actor = auth.uid() (NULL khi chay migration, cot
--    cho phep NULL) nen khong gap loi 22P02 nhu T-034.
-- ---------------------------------------------------------------------------
insert into public.warehouses (property_id, room_id, code, name, kind)
select
  r.property_id, r.id,
  'MINIBAR_' || r.room_no,
  'Minibar phòng ' || r.room_no,
  'minibar_room'
from public.rooms r
where not exists (
  select 1 from public.warehouses w
  where w.room_id = r.id and w.kind = 'minibar_room'
)
on conflict do nothing;

insert into public.warehouses (property_id, code, name, kind)
select p.id, 'MINIBAR_MAIN', 'Kho minibar tổng', 'minibar_main'
from public.properties p
where not exists (
  select 1 from public.warehouses w
  where w.property_id = p.id and w.kind = 'minibar_main'
)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 4. Sua lich doi soat minibar ve 23:30 gio VN (= 16:30 UTC).
--    pg_cron chay theo gio UTC; lich cu '30 23' UTC = 06:30 VN hom sau.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (
      select 1 from cron.job where jobname = 'minibar-reconcile-daily'
    ) then
      perform cron.unschedule('minibar-reconcile-daily');
    end if;
    perform cron.schedule(
      'minibar-reconcile-daily',
      '30 16 * * *',
      'select public.minibar_reconcile_all()'
    );
  end if;
end $$;

comment on function public._minibar_room_wh(uuid) is
  'Minibar fix (460000): tim kho minibar_room cua phong, thieu thi tu tao (ma MINIBAR_<so phong>) — phong tao qua UI truoc day khong co kho nay nen moi RPC minibar deu loi ERR_INVALID_VALUE.';
comment on function public._minibar_main_wh(uuid) is
  'Minibar fix (460000): tim kho minibar_main cua property, thieu thi tu tao — property tao sau go-live khong co kho chuan nay.';
