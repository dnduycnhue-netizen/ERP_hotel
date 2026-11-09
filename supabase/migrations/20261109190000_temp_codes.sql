-- 20261109190000_temp_codes.sql
--
-- T-015: ma tam + gop ma (item_create_temp, item_merge) + cron ma tam qua han.
-- AC: ma tam > 72h bi chan dung (ERR_TEMP_ITEM_EXPIRED).
--
-- Can cu: docs/03-DATA-MODEL.md (items: is_temp, temp_created_at, status
-- active/inactive/merged, merged_into_id), docs/05-BUSINESS-RULES.md §5
-- (ma tam dung ngay khi nhan/mua cho; > 24h chua chuan hoa -> alert;
-- > 72h -> chan dung tiep), docs/09-API-RPC.md §1 (item_create_temp,
-- item_merge) + muc 10 (ERR_TEMP_ITEM_EXPIRED), docs/08-REPORTS-ALERTS.md
-- (TEMP_ITEM_STALE, severity info), docs/02-ARCHITECTURE.md:83 (cron moi
-- gio: ma tam qua 24h chua chuan hoa -> tao alert), docs/modules/M01
-- (gop ma tam: chi khi ma tam chua qua ky da khoa; stock_moves giu nguyen,
-- tao cap move merge_out/merge_in cung gia von).
--
-- Quyet dinh khi dac ta im lang / mo (ghi ro de Duy chot lai neu sai):
--  1. Chu ky RPC them p_property_id dau tien (theo mau T-013
--     supplier_submit): can de require_perm + suy ra org. Ban goc trong
--     09-API-RPC.md khong co tham so nay.
--  2. Chan 72h thuc thi o tang so cai bang trigger BEFORE INSERT tren
--     stock_moves (khong copy lai ham _post_move ~500 dong): moi buoc
--     ghi so cho ma tam het han deu bi chan, ke ca RPC tuong lai
--     (nhan hang T-023, xuat kho T-030...). Mien tru: merge_out /
--     merge_in (gop ma la duong sua ma het han) va reversal (dao but
--     toan la sua sai, khong phai "dung" ma).
--  3. Gop ma (M01 "chi khi ma tam chua qua ky da khoa"): chan khi ma
--     nguon con ton de chuyen (qty > 0) MA co stock_moves roi vao ky
--     ke toan da khoa (accounting_periods status = 'closed'). Neu ton
--     bang 0 thi chi doi trang thai, khong chan (tranh truong hop ma
--     tam cu khong ton bi ket vinh vien: khong dung duoc, khong gop
--     duoc). Cac cap move lay ngay nghiep vu hom nay (Asia/Ho_Chi_Minh)
--     nen _post_move van tu chan neu ky hien tai da khoa / ngay bi khoa.
--  4. Chuyen ton theo tung (kho, lo): merge_out lay gia von hien tai
--     cua ma tam (do _post_move tinh: avg_cost voi moving_avg, gia
--     binh quan lop FIFO da xuat), roi merge_in dung dung gia do. Nhu
--     vay "cung gia von" dung voi ca 2 phuong phap, khong can nhan ban
--     logic tinh gia cua _post_move. source_doc_type = 'item_merge',
--     source_doc_id = id ma nguon.
--  5. Ma dich phai cung don vi kho voi ma nguon KHI con ton de chuyen
--     (khac don vi thi so luong chuyen se sai nghia). Neu ton bang 0
--     thi khong chan.
--  6. "Chuyen moi tham chieu nhap sang ma dich" (09-API-RPC.md): trong
--     schema hien tai chua co chung tu nhap nao tham chieu item
--     (PR/PO den T-020, phieu linh den T-030); price_agreement_lines
--     va ceiling_prices la rang buoc hop dong, KHONG tu doi sang ma
--     dich. Ghi cau hoi Q13 vao docs/OPEN-QUESTIONS.md de T-020 bo
--     sung khi cac bang do co mat.
--  7. Doan "Khong gop neu ma nguon da co stock_moves khac phap nhan…"
--     trong 09-API-RPC.md bi cut, khong co quy tac day du trong docs.
--     Cach xu ly o day: moi cap move nam trong dung kho/phap nhan cua
--     no nen gia tri khong bao gio chuyen cheo phap nhan; khong chan
--     gop ma co ton o nhieu phap nhan (ma tam la cap chuoi, co the
--     nhan o 2 khach san khac phap nhan; chan se lam ket ma). Ghi cau
--     hoi Q14 vao docs/OPEN-QUESTIONS.md.
--  8. T-014 khong danh dau is_temp cho dong NO_CODE (import_commit
--     chi sinh ma TP-.../ma nhom-...). De T-015 nhan dien duoc cac ma
--     do: (a) backfill 1 lan trong migration nay (join import_rows co
--     issue NO_CODE, status committed -> target item); (b) trigger
--     tren import_rows tu danh dau cac dong NO_CODE commit sau nay.
--     Sua lau dai: import_commit_batch nen tu set is_temp (follow-up
--     T-014, khong sua file 20261109180000 o day).
--  9. Cron: pg_cron job 'temp-code-stale-hourly' chay moi gio, goi
--     temp_code_maintenance() tao alert TEMP_ITEM_STALE (info, dedupe
--     theo alert chua ack). Tao extension + lich chay co guard: neu
--     pg_cron chua bat (Dashboard > Database > Extensions) thi
--     migration van chay xong, job bi bo qua; ham van goi tay duoc.
--     Chu y: cron chay theo gio UTC.
-- 10. Ma quyen dung san trong seed, khong them ma moi: item.temp.create
--     (purchaser, storekeeper), item.temp.normalize (cost_controller),
--     alert.receive.temp_item_stale (da seed ma chua gan vai tro nao).
--     Migration nay gan alert.receive.temp_item_stale cho
--     cost_controller, chief_accountant, gm (join theo ma vai tro, giong
--     mau seed.sql — KHONG dung filter is_system).
-- 11. Migration nay viet tren nen T-013 goc (branch feat/t-014-
--     import-excel); chi goi _create_alert (chu ky giu nguyen qua ban
--     hoa giai fix/t-013-reconcile), khong dung den bang alerts truc
--     tiep. Chay SAU 20261109160000 (alerts + _create_alert) va SAU
--     20261109180000 (import_rows).

-- ---------------------------------------------------------------------------
-- 1. Helper: ma tam het han 72h? (dung chung cho trigger + cron + UI sau nay)
-- ---------------------------------------------------------------------------
create or replace function public.temp_item_is_expired(p_item_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.items
    where id = p_item_id
      and is_temp
      and coalesce(temp_created_at, created_at) < now() - interval '72 hours'
  );
$$;

comment on function public.temp_item_is_expired(uuid) is
  'T-015: true khi ma tam qua 72h tinh tu temp_created_at (fallback created_at).';

revoke all on function public.temp_item_is_expired(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Chan 72h o tang so cai: trigger BEFORE INSERT tren stock_moves.
--    Mien tru merge_out / merge_in / reversal (xem quyet dinh 2 o dau file).
-- ---------------------------------------------------------------------------
create or replace function public.check_temp_item_not_expired()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if NEW.move_type in ('merge_out', 'merge_in', 'reversal') then
    return NEW;
  end if;
  if public.temp_item_is_expired(NEW.item_id) then
    raise exception using errcode = 'P0001', message = 'ERR_TEMP_ITEM_EXPIRED';
  end if;
  return NEW;
end $$;

comment on function public.check_temp_item_not_expired() is
  'T-015: trigger chan ghi so cho ma tam qua 72h (ERR_TEMP_ITEM_EXPIRED).';

drop trigger if exists trg_stock_moves_temp_expiry on public.stock_moves;
create trigger trg_stock_moves_temp_expiry
before insert on public.stock_moves
for each row execute function public.check_temp_item_not_expired();

-- ---------------------------------------------------------------------------
-- 3. RPC: tao ma tam (09-API-RPC.md §1 + p_property_id theo mau T-013).
--    Ma sinh TMP-0001… qua next_item_code (T-014, khoa dong
--    item_code_sequences). Ten trung (name_norm) -> ERR_INVALID_VALUE.
-- ---------------------------------------------------------------------------
create or replace function public.item_create_temp(
  p_property_id uuid,
  p_name text,
  p_group_id uuid,
  p_stock_uom text
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp as $$
declare
  v_org uuid;
  v_code text;
  v_item_id uuid;
begin
  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:item.temp.create';
  end if;
  perform public.require_perm(p_property_id, 'item.temp.create');

  if p_name is null or btrim(p_name) = '' then
    raise exception 'ERR_INVALID_VALUE: ten vat tu trong';
  end if;
  if not exists (
    select 1 from public.item_groups
    where id = p_group_id and org_id = v_org
  ) then
    raise exception 'ERR_CONFIG_ITEM_GROUP';
  end if;
  if p_stock_uom is null or not exists (
    select 1 from public.uoms where code = btrim(p_stock_uom)
  ) then
    raise exception 'ERR_UOM_UNKNOWN';
  end if;
  if exists (
    select 1 from public.items
    where org_id = v_org and name_norm = public.norm_text(p_name)
  ) then
    raise exception 'ERR_INVALID_VALUE: ten vat tu da ton tai';
  end if;

  v_code := public.next_item_code(v_org, 'TMP');

  insert into public.items
    (org_id, code, name, group_id, stock_uom, is_temp, temp_created_at, status)
  values
    (v_org, v_code, btrim(p_name), p_group_id, btrim(p_stock_uom), true, now(), 'active')
  returning id into v_item_id;

  return jsonb_build_object('ok', true, 'id', v_item_id, 'code', v_code);
end $$;

comment on function public.item_create_temp(uuid, text, uuid, text) is
  'T-015: tao ma tam TMP-xxxx (is_temp, temp_created_at = now()).';

revoke all on function public.item_create_temp(uuid, text, uuid, text)
  from public, anon;
grant execute on function public.item_create_temp(uuid, text, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC: gop ma tam vao ma chinh (M01 + quyet dinh 3, 4, 5 o dau file).
-- ---------------------------------------------------------------------------
create or replace function public.item_merge(
  p_property_id uuid,
  p_from_id uuid,
  p_into_id uuid
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp as $$
declare
  v_org uuid;
  v_from public.items%rowtype;
  v_into public.items%rowtype;
  v_today date;
  v_has_balance boolean;
  v_moved jsonb := '[]'::jsonb;
  v_moved_count integer := 0;
  r_bal record;
  v_out_id bigint;
  v_unit_cost numeric(18,4);
begin
  select org_id into v_org
  from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:item.temp.normalize';
  end if;
  perform public.require_perm(p_property_id, 'item.temp.normalize');

  if p_from_id = p_into_id then
    raise exception 'ERR_INVALID_VALUE: ma nguon va ma dich trung nhau';
  end if;

  select * into v_from
  from public.items
  where id = p_from_id and org_id = v_org
  for update;
  if not found then
    raise exception 'ERR_FORBIDDEN:item.temp.normalize';
  end if;
  select * into v_into
  from public.items
  where id = p_into_id and org_id = v_org;
  if not found then
    raise exception 'ERR_FORBIDDEN:item.temp.normalize';
  end if;

  if not v_from.is_temp or v_from.status <> 'active' then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_into.is_temp or v_into.status <> 'active' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select exists (
    select 1 from public.stock_balances
    where item_id = p_from_id and qty > 0
  ) into v_has_balance;

  -- Chi chan theo quy tac "chua qua ky da khoa" khi con ton de chuyen.
  if v_has_balance and exists (
    select 1
    from public.stock_moves m
    join public.accounting_periods ap
      on ap.legal_entity_id = m.legal_entity_id
     and ap.year = extract(year from m.business_date)::integer
     and ap.month = extract(month from m.business_date)::integer
     and ap.status = 'closed'
    where m.item_id = p_from_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_PERIOD_CLOSED';
  end if;

  -- Don vi kho phai giong nhau khi con ton de chuyen.
  if v_has_balance and v_from.stock_uom <> v_into.stock_uom then
    raise exception 'ERR_INVALID_VALUE: don vi kho cua ma dich khac ma tam';
  end if;

  v_today := (now() at time zone 'Asia/Ho_Chi_Minh')::date;

  -- Chuyen ton theo tung (kho, lo). merge_out lay gia von hien tai cua ma
  -- tam (do _post_move tinh); merge_in dung dung gia do.
  for r_bal in
    select warehouse_id, legal_entity_id, property_id, lot_id, qty
    from public.stock_balances
    where item_id = p_from_id and qty > 0
    order by warehouse_id, lot_id nulls first
    for update
  loop
    v_out_id := public._post_move(
      r_bal.legal_entity_id, r_bal.property_id, r_bal.warehouse_id,
      p_from_id, r_bal.lot_id, 'merge_out', -r_bal.qty, null,
      v_today, 'item_merge', p_from_id, null
    );
    select unit_cost into v_unit_cost
    from public.stock_moves where id = v_out_id;

    perform public._post_move(
      r_bal.legal_entity_id, r_bal.property_id, r_bal.warehouse_id,
      p_into_id, r_bal.lot_id, 'merge_in', r_bal.qty, v_unit_cost,
      v_today, 'item_merge', p_from_id, null
    );

    v_moved := v_moved || jsonb_build_object(
      'warehouse_id', r_bal.warehouse_id,
      'lot_id', r_bal.lot_id,
      'qty', r_bal.qty,
      'unit_cost', v_unit_cost
    );
    v_moved_count := v_moved_count + 1;
  end loop;

  update public.items
  set status = 'merged', merged_into_id = p_into_id, updated_at = now()
  where id = p_from_id;

  return jsonb_build_object(
    'ok', true,
    'from_id', p_from_id,
    'into_id', p_into_id,
    'from_code', v_from.code,
    'into_code', v_into.code,
    'moved', v_moved,
    'moved_count', v_moved_count
  );
end $$;

comment on function public.item_merge(uuid, uuid, uuid) is
  'T-015: gop ma tam vao ma chinh; ton chuyen qua cap merge_out/merge_in cung gia von, stock_moves cu giu nguyen.';

revoke all on function public.item_merge(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.item_merge(uuid, uuid, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Cron worker: alert TEMP_ITEM_STALE cho ma tam > 24h chua chuan hoa.
--    Chay moi gio qua pg_cron (muc 7). Dedupe: bo qua ma da co alert
--    chua ack. property_id = null (ma tam cap chuoi) -> alert doc duoc
--    nho quyen chain-wide alert.receive.temp_item_stale.
-- ---------------------------------------------------------------------------
create or replace function public.temp_code_maintenance()
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp as $$
declare
  v_created integer := 0;
  r record;
  v_age_hours numeric(18,1);
  v_blocked boolean;
begin
  for r in
    select i.id, i.code, i.name,
           coalesce(i.temp_created_at, i.created_at) as v_since
    from public.items i
    where i.is_temp
      and i.status = 'active'
      and coalesce(i.temp_created_at, i.created_at) < now() - interval '24 hours'
      and not exists (
        select 1 from public.alerts a
        where a.code = 'TEMP_ITEM_STALE'
          and a.doc_type = 'item'
          and a.doc_id = i.id
          and a.ack_at is null
      )
    order by i.temp_created_at
  loop
    v_age_hours := round(extract(epoch from (now() - r.v_since)) / 3600, 1);
    v_blocked := r.v_since < now() - interval '72 hours';
    perform public._create_alert(
      null,
      'TEMP_ITEM_STALE',
      'info',
      format(
        'Mã tạm %s quá %s giờ chưa chuẩn hóa%s',
        r.code, v_age_hours::text,
        case when v_blocked then ' — đã bị chặn dùng' else '' end
      ),
      jsonb_build_object(
        'item_id', r.id,
        'code', r.code,
        'name', r.name,
        'age_hours', v_age_hours,
        'blocked', v_blocked
      ),
      'item',
      r.id
    );
    v_created := v_created + 1;
  end loop;

  return jsonb_build_object('ok', true, 'alerts_created', v_created);
end $$;

comment on function public.temp_code_maintenance() is
  'T-015: cron moi gio — tao alert TEMP_ITEM_STALE cho ma tam > 24h chua chuan hoa (dedupe theo alert chua ack).';

revoke all on function public.temp_code_maintenance()
  from public, anon;
grant execute on function public.temp_code_maintenance()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Cau noi import T-014: danh dau ma tam cho dong NO_CODE.
--    (a) Backfill 1 lan cho cac dong da commit truoc T-015.
--    (b) Trigger tu danh dau cac dong NO_CODE commit sau nay.
--    Sua lau dai: import_commit_batch nen tu set is_temp (follow-up T-014).
-- ---------------------------------------------------------------------------
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

create or replace function public.mark_import_temp_item()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if TG_OP = 'UPDATE'
     and NEW.status = 'committed'
     and OLD.status is distinct from 'committed'
     and NEW.target_id is not null
     and exists (
       select 1 from jsonb_array_elements(NEW.issues) x
       where x ->> 'code' = 'NO_CODE'
     )
     and exists (
       select 1 from public.items
       where id = NEW.target_id and not is_temp
     ) then
    update public.items
    set is_temp = true,
        temp_created_at = coalesce(temp_created_at, now()),
        updated_at = now()
    where id = NEW.target_id;
  end if;
  return NEW;
end $$;

comment on function public.mark_import_temp_item() is
  'T-015: trigger danh dau is_temp cho vat tu import tu dong NO_CODE khi commit.';

drop trigger if exists trg_import_rows_mark_temp on public.import_rows;
create trigger trg_import_rows_mark_temp
after update of status, target_id on public.import_rows
for each row execute function public.mark_import_temp_item();

-- ---------------------------------------------------------------------------
-- 7. pg_cron: job moi gio 'temp-code-stale-hourly' (02-ARCHITECTURE.md:83).
--    Guard 2 lop: extension chua bat -> bo qua, migration van chay xong.
--    Bat pg_cron trong Dashboard (Database > Extensions) truoc/sau khi push;
--    neu chua bat, goi tay select public.temp_code_maintenance().
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'T-015: pg_cron khong cai duoc (%), bo qua lich chay.', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (
      select 1 from cron.job where jobname = 'temp-code-stale-hourly'
    ) then
      perform cron.schedule(
        'temp-code-stale-hourly',
        '0 * * * *',
        'select public.temp_code_maintenance()'
      );
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Gan quyen nhan alert TEMP_ITEM_STALE (ma da seed san, chua gan vai
--    tro nao). Join theo ma vai tro, giong mau seed.sql.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('cost_controller', 'alert.receive.temp_item_stale'),
  ('chief_accountant', 'alert.receive.temp_item_stale'),
  ('gm', 'alert.receive.temp_item_stale')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109190000_temp_codes',
  'INSERT',
  jsonb_build_object('event', 'temp_codes_created', 'task', 'T-015'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
