-- Q273 (14/11/2026): bao cao verify V10-N1 — tim vat tu nhieu tu tra 0 ket qua
-- ("duong the" khong ra "Duong the"; "ba chi" khong ra "Ba chi nach") vi so khop co dau,
-- nguyen cum. Them cot name_search = lower(unaccent(code || ' ' || name)), d -> d,
-- tu dong cap nhat bang trigger; ung dung tim tung tu (AND) tren cot nay.
alter table public.items add column if not exists name_search text;

create or replace function public._items_name_search_sync()
returns trigger
language plpgsql
set search_path = public, extensions, pg_temp
as $$
begin
  new.name_search := lower(
    translate(extensions.unaccent(coalesce(new.code, '') || ' ' || coalesce(new.name, '')),
      'đĐ', 'dD'));
  return new;
end;
$$;

drop trigger if exists trg_items_name_search on public.items;
create trigger trg_items_name_search
  before insert or update of code, name on public.items
  for each row execute function public._items_name_search_sync();

-- Backfill cot phu: tat trigger (audit/guard) de khong sinh ~670 dong nhat ky vo nghia.
set local session_replication_role = replica;
update public.items
set name_search = lower(translate(extensions.unaccent(coalesce(code, '') || ' ' || coalesce(name, '')), 'đĐ', 'dD'))
where name_search is distinct from lower(translate(extensions.unaccent(coalesce(code, '') || ' ' || coalesce(name, '')), 'đĐ', 'dD'));
reset session_replication_role;
