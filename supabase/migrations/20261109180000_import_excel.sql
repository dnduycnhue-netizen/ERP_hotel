-- T-014: Import Excel 4 buoc cho vat tu & NCC (docs/07-IMPORT-MIGRATION.md 01.10).
--
-- Do tren file mau that Lst_2020_DL_Buffet.xlsx (sheet NVL, 668 dong du lieu):
--   * DUP_CODE: 11 ma gan cho >= 2 ten khac nhau (vd. NVL0029 = cua nguyen con
--     va cua hop 450gr). Dem truc tiep tu file, khop AC.
--   * Don vi: cot DVT co 54 cach ghi (gom 1 o trong); hop nhat 2 cot DVT
--     (kho + qui doi) co 59 cach ghi tho -> 33 ma chuan (NFC + lower +
--     unaccent + dong nghia gr->g, lit->l, qua->trai). AC "54->33" duoc hieu
--     la: 54 cach ghi o cot DVT, 33 ma chuan cho toan bo file (gop qua vao
--     trai vi 2 tu dong nghia; neu Duy muon tach thi sua 1 dong alias).
--     Rieng cot DVT: 54 tho -> 31 ma chuan (30 neu gop qua->trai).
--   * NO_FACTOR: 281 dong thieu he so qui doi, tinh tren 661 dong co ten
--     hoac ma (288 o he so trong tru 7 dong trong hoan toan). Khop AC.
--     Dinh nghia: he so trong + dong co ten/ma; dong trong ca ten va ma
--     duoc bo qua nhu dong trang, khong dem.
--   * 338 dong khong co ma (50,6%); 236 dong CCDC lan vao; 332 dong khong
--     ma nhung co ten -> sinh ma theo tien to nhom (vd. TP-0001).
--   * Cot "Ma va ten nvl" luon bat dau bang ma o cot Ma (0 lech) nen chi
--     dung de khoi phuc ma khi cot Ma trong va token dau co dang ma
--     (chu + so, vd. CB025); ten thuong khong duoc doan la ma.
--   * Nhom CP (1 nvl_Chinh, 2 nvl_phu...) khong co cot dich trong schema
--     hien tai: giu trong import_rows.raw_data de doi chieu, khong map
--     vao cot nao (ghi chu trong CHANGELOG; map sau neu them truong).
--   * Sheet Menu / 02 DL goc (cong thuc buffet) KHONG nhap o T-014:
--     recipes la P2 (docs/03-DATA-MODEL.md A7), can portions_per_batch
--     cua bep truong + man hinh ghep tay (07 section 3). Chi nhap NVL
--     (vat tu) va mau_ncc (NCC).
--
-- Decisions (spec im lang hoac mo; xem CHANGELOG T-014):
--   1. Quyen dung ma `item.import` da co san trong seed quyen (Danh muc,
--      'Nhap danh muc', sensitive, 140) nhung chua gan cho vai tro nao.
--      T-014 gan cho cost_controller, chief_accountant, gm (nguoi chuan
--      hoa danh muc; thu kho co item.manage nhung khong duoc nhap hang
--      loat). Join theo ma vai tro, khong loc them.
--   2. `uom_aliases` la bang tham chieu toan cuc (nhu `uoms`, khong co
--      org_id) vi chuan hoa don vi la van de ngon ngu, khong theo to chuc.
--      Chi can 3 dong alias (gr->g, lit->l, qua->trai); cac bien the
--      hoa/thuong/dau/NFC con lai duoc ham chuan hoa xu ly chung
--      (NFC + trim + lower + unaccent).
--   3. Don vi chuan con thieu (22 ma) duoc seed thang vao `uoms` o day
--      (hu, o, bich, bo, can, cay, con, cuon, doi, don, la, lat, lo, loc,
--      ly, mieng, nai, thung, trai, trung, uc, vien) de commit khong phai
--      tu tao don vi.
--   4. `import_normalize_*` chay trong SQL (nguon su that duy nhat, test
--      duoc bang pgTAP). Client chi parse file .xlsx thanh JSON tho va
--      gui len; khong co logic nghiep vu o TypeScript.
--   5. NO_FACTOR la loi chan chi voi nhom kind food/beverage (theo 07
--      section 2: "khong cho bo qua voi nhom food/beverage"); nhom khac
--      (ccdc, tool...) chi la canh bao, duoc phep commit.
--   6. Commit ghi 1 transaction duy nhat (theo 07 section 2 buoc 4).
--      NCC moi tao o trang thai pending (vong doi T-013); tai khoan
--      ngan hang kem theo (neu co) cung o pending, cho duyet theo
--      luong T-013, khong tu dong active.
--   7. Ma sinh cho dong NO_CODE: tien to nhom + so chay 4 chu so
--      (vd. TP-0001), dem bang bang `item_code_sequences` (khoa dong),
--      bo qua ma da ton tai trong items.
--   8. Dong trong (khong ten, khong ma) duoc danh dau skipped ngay khi
--      nhan, khong dem vao tong so dong du lieu.
--   9. `import_rows` khong co policy ghi truc tiep cho client: chi RPC
--      (SECURITY DEFINER) duoc ghi; client doc qua RLS theo batch.
--  10. `import_mappings.column_map` luu anh xa truong -> {col (so cot
--      0-based), header (ten cot doc duoc)}; `group_map` luu anh xa
--      gia tri cot Loai -> item_group_id (nguoi dung chon o buoc 1,
--      goi y mac dinh theo kind).

-- ---------------------------------------------------------------------------
-- 1. Bo sung don vi chuan con thieu (22 ma) vao `uoms`
-- ---------------------------------------------------------------------------
insert into public.uoms (code, name_vi) values
  ('hu', 'Hủ'),
  ('o', 'Ổ'),
  ('bich', 'Bịch'),
  ('bo', 'Bó'),
  ('can', 'Can'),
  ('cay', 'Cây'),
  ('con', 'Con'),
  ('cuon', 'Cuộn'),
  ('doi', 'Đôi'),
  ('don', 'Đòn'),
  ('la', 'Lá'),
  ('lat', 'Lát'),
  ('lo', 'Lọ'),
  ('loc', 'Lóc'),
  ('ly', 'Ly'),
  ('mieng', 'Miếng'),
  ('nai', 'Nải'),
  ('thung', 'Thùng'),
  ('trai', 'Trái'),
  ('trung', 'Trứng'),
  ('uc', 'Ức'),
  ('vien', 'Viên')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- 2. `uom_aliases`: bien the viet don vi -> ma chuan
-- ---------------------------------------------------------------------------
create table if not exists public.uom_aliases (
  alias text primary key,
  uom_code text not null references public.uoms(code),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now()
);

comment on table public.uom_aliases is
  'T-014: anh xa bien the viet don vi (da chuan hoa NFC+lower+unaccent) ve ma chuan uoms.code. Chi can dong nghia that su (gr->g...); bien the hoa/thuong/dau duoc ham import_normalize_uom xu ly chung.';

insert into public.uom_aliases (alias, uom_code) values
  ('gr', 'g'),
  ('lit', 'l'),
  ('qua', 'trai')
on conflict (alias) do nothing;

alter table public.uom_aliases enable row level security;

drop policy if exists uom_aliases_select on public.uom_aliases;
create policy uom_aliases_select on public.uom_aliases
  for select to authenticated using (true);

-- Khong co policy ghi truc tiep: chi RPC import_add_uom_alias (quyen
-- item.manage) duoc ghi, nhu doc_sequences o T-012.

-- ---------------------------------------------------------------------------
-- 3. `import_mappings`: mau anh xa cot (docs/03-DATA-MODEL.md A6)
-- ---------------------------------------------------------------------------
create table if not exists public.import_mappings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  source text not null default 'master_excel'
    check (source in ('pos', 'pms', 'supplier_xml', 'master_excel')),
  kind text not null check (kind in ('items', 'suppliers')),
  name text not null check (btrim(name) <> ''),
  column_map jsonb not null default '{}'::jsonb
    check (jsonb_typeof(column_map) = 'object'),
  group_map jsonb not null default '{}'::jsonb
    check (jsonb_typeof(group_map) = 'object'),
  sample_header text[],
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, kind, name)
);

comment on table public.import_mappings is
  'T-014: mau anh xa cot cho import Excel (07 section 2 buoc 1). column_map: truong -> {col, header}; group_map: gia tri cot Loai -> item_group_id.';

alter table public.import_mappings enable row level security;

drop policy if exists import_mappings_select on public.import_mappings;
create policy import_mappings_select on public.import_mappings
  for select to authenticated using (
    exists (
      select 1 from public.properties p
      where p.org_id = import_mappings.org_id
        and p.id in (select public.my_property_ids())
        and (public.has_perm(p.id, 'item.view') or public.has_perm(p.id, 'item.import'))
    )
    or public.has_perm(null, 'item.view')
    or public.has_perm(null, 'item.import')
  );

drop policy if exists import_mappings_write on public.import_mappings;
create policy import_mappings_write on public.import_mappings
  for all to authenticated using (
    exists (
      select 1 from public.properties p
      where p.org_id = import_mappings.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'item.import')
    )
    or public.has_perm(null, 'item.import')
  ) with check (
    exists (
      select 1 from public.properties p
      where p.org_id = import_mappings.org_id
        and p.id in (select public.my_property_ids())
        and public.has_perm(p.id, 'item.import')
    )
    or public.has_perm(null, 'item.import')
  );

drop trigger if exists trg_import_mappings_set_updated_at on public.import_mappings;
create trigger trg_import_mappings_set_updated_at
before update on public.import_mappings
for each row execute function public.set_updated_at();

drop trigger if exists trg_import_mappings_audit on public.import_mappings;
create trigger trg_import_mappings_audit
after insert or update or delete on public.import_mappings
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 4. `import_batches`: phien import (1 file = 1 batch)
-- ---------------------------------------------------------------------------
create table if not exists public.import_batches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  kind text not null check (kind in ('items', 'suppliers')),
  mapping_id uuid references public.import_mappings(id),
  file_name text not null check (btrim(file_name) <> ''),
  status text not null default 'draft'
    check (status in ('draft', 'validated', 'committed', 'discarded')),
  row_count integer not null default 0 check (row_count >= 0),
  counts jsonb not null default '{}'::jsonb
    check (jsonb_typeof(counts) = 'object'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  committed_at timestamptz,
  committed_by uuid references auth.users(id)
);

comment on table public.import_batches is
  'T-014: phien import Excel. counts: {total, skipped_blank, ok, warnings, errors, dup_code, near_dup, no_code, no_factor, unknown_uom, unknown_group, created, skipped, merged}.';

alter table public.import_batches enable row level security;

drop policy if exists import_batches_select on public.import_batches;
create policy import_batches_select on public.import_batches
  for select to authenticated using (
    exists (
      select 1 from public.properties p
      where p.org_id = import_batches.org_id
        and p.id in (select public.my_property_ids())
        and (public.has_perm(p.id, 'item.view') or public.has_perm(p.id, 'item.import'))
    )
    or public.has_perm(null, 'item.view')
    or public.has_perm(null, 'item.import')
  );

-- Khong co policy ghi truc tiep: chi RPC duoc tao/sua batch (giong
-- supplier_bank_accounts o T-013).

drop trigger if exists trg_import_batches_set_updated_at on public.import_batches;
create trigger trg_import_batches_set_updated_at
before update on public.import_batches
for each row execute function public.set_updated_at();

drop trigger if exists trg_import_batches_audit on public.import_batches;
create trigger trg_import_batches_audit
after insert or update or delete on public.import_batches
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 5. `import_rows`: dong du lieu tam trong 1 batch
-- ---------------------------------------------------------------------------
create table if not exists public.import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches(id) on delete cascade,
  row_no integer not null check (row_no > 0),
  raw_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(raw_data) = 'object'),
  normalized_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(normalized_data) = 'object'),
  status text not null default 'pending'
    check (status in ('pending', 'ok', 'warning', 'error', 'skipped', 'committed', 'merged')),
  issues jsonb not null default '[]'::jsonb
    check (jsonb_typeof(issues) = 'array'),
  resolution jsonb not null default '{}'::jsonb
    check (jsonb_typeof(resolution) = 'object'),
  target_id uuid,
  target_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (batch_id, row_no)
);

comment on table public.import_rows is
  'T-014: dong tam cua 1 phien import. issues: [{code, field, message, severity}]; resolution: quyet dinh cua nguoi dung (split/merge/set_code/set_factor/set_group/set_uom/skip/keep).';

alter table public.import_rows enable row level security;

drop policy if exists import_rows_select on public.import_rows;
create policy import_rows_select on public.import_rows
  for select to authenticated using (
    exists (
      select 1 from public.import_batches b
      join public.properties p on p.org_id = b.org_id
      where b.id = import_rows.batch_id
        and p.id in (select public.my_property_ids())
        and (public.has_perm(p.id, 'item.view') or public.has_perm(p.id, 'item.import'))
    )
    or exists (
      select 1 from public.import_batches b
      where b.id = import_rows.batch_id
        and (public.has_perm(null, 'item.view') or public.has_perm(null, 'item.import'))
    )
  );

-- Khong co policy ghi truc tiep: chi RPC duoc ghi.

drop trigger if exists trg_import_rows_set_updated_at on public.import_rows;
create trigger trg_import_rows_set_updated_at
before update on public.import_rows
for each row execute function public.set_updated_at();

drop trigger if exists trg_import_rows_audit on public.import_rows;
create trigger trg_import_rows_audit
after insert or update or delete on public.import_rows
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 6. `item_code_sequences`: bo dem sinh ma cho dong NO_CODE
-- ---------------------------------------------------------------------------
create table if not exists public.item_code_sequences (
  org_id uuid not null references public.organizations(id),
  code_prefix text not null check (btrim(code_prefix) <> ''),
  last_no bigint not null default 0 check (last_no >= 0),
  primary key (org_id, code_prefix)
);

comment on table public.item_code_sequences is
  'T-014: bo dem sinh ma vat tu/NCC cho dong thieu ma (vd. TP-0001, NCC-0001). Chi RPC duoc doc/ghi, nhu doc_sequences.';

alter table public.item_code_sequences enable row level security;
-- Khong co policy: RPC-only (SECURITY DEFINER).

-- ---------------------------------------------------------------------------
-- 7. Ham tien ich
-- ---------------------------------------------------------------------------

-- Parse so tu o Excel: chap nhan number hoac chuoi tieng Viet ("1,5" = 1.5;
-- "1.000" = 1000; "1.234,5" = 1234.5). Tra ve NULL neu khong parse duoc
-- (khong bao gio throw de ham validate khong sap ca batch).
create or replace function public.import_parse_number(p_value jsonb)
returns numeric(18,4)
language sql immutable
set search_path = public, pg_temp as $$
  select case
    when p_value is null or jsonb_typeof(p_value) = 'null' then null
    when jsonb_typeof(p_value) = 'number' then (p_value #>> '{}')::numeric(18,4)
    when jsonb_typeof(p_value) = 'string' then
      case
        when btrim(p_value #>> '{}') = '' then null
        -- Dang Viet "1.234,5": bo dau cham ngan cach hang nghin, phay -> cham.
        when btrim(p_value #>> '{}') ~ '^-?\d{1,3}(\.\d{3})+(,\d+)?$' then
          replace(replace(btrim(p_value #>> '{}'), '.', ''), ',', '.')::numeric(18,4)
        -- Co dau phay: phay la thap phan ("1,5" = 1.5); bo khoang trang.
        when btrim(p_value #>> '{}') ~ ',' then
          replace(replace(btrim(p_value #>> '{}'), ' ', ''), ',', '.')::numeric(18,4)
        -- Con lai: chi chap nhan dang so thap phan hop le, neu khong -> NULL.
        when replace(btrim(p_value #>> '{}'), ' ', '') ~ '^-?\d+(\.\d+)?$' then
          replace(btrim(p_value #>> '{}'), ' ', '')::numeric(18,4)
        else null
      end
    else null
  end;
$$;

comment on function public.import_parse_number(jsonb) is
  'T-014: parse so tu o Excel (number hoac chuoi tieng Viet). Tra NULL neu khong parse duoc, khong throw.';

revoke all on function public.import_parse_number(jsonb) from public, anon, authenticated;

-- Chuan hoa don vi: NFC + trim + lower + unaccent -> tra ma chuan neu khop
-- uoms.code, neu khong thi tra alias (gr->g, lit->l, qua->trai), neu khong
-- thi NULL (UNKNOWN_UOM). Khong phan biet hoa/thuong, dau, dang NFC/NFD.
create or replace function public.import_normalize_uom(p_raw text)
returns text
language sql stable
set search_path = public, extensions, pg_temp as $$
  select case
    when v_canon is null or v_canon = '' then null
    when exists (select 1 from public.uoms u where u.code = v_canon) then v_canon
    else (select a.uom_code from public.uom_aliases a where a.alias = v_canon)
  end
  from (
    select extensions.unaccent(lower(btrim(normalize(coalesce(p_raw, ''), NFC)))) as v_canon
  ) s;
$$;

comment on function public.import_normalize_uom(text) is
  'T-014: chuan hoa bien the don vi ve ma chuan (vd. KG|Kg|kg -> kg; Cái (NFD) -> cai; lit -> l; Qua -> trai). Tra NULL neu khong co ma/alias tuong ung.';

revoke all on function public.import_normalize_uom(text) from public, anon, authenticated;

-- Sinh ma tiep theo cho 1 tien to trong 1 to chuc (khoa dong de tranh trung
-- khi commit dong thoi). Bo qua ma da ton tai trong items (phong truong hop
-- ma thu cong chen ngang day so).
create or replace function public.next_item_code(p_org_id uuid, p_prefix text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp as $$
declare
  v_no bigint;
  v_code text;
  v_tries integer := 0;
begin
  if p_org_id is null or btrim(p_prefix) = '' then
    raise exception 'ERR_INVALID_VALUE: thieu to chuc hoac tien to ma';
  end if;

  insert into public.item_code_sequences (org_id, code_prefix, last_no)
  values (p_org_id, btrim(p_prefix), 0)
  on conflict (org_id, code_prefix) do nothing;

  loop
    update public.item_code_sequences
    set last_no = last_no + 1
    where org_id = p_org_id and code_prefix = btrim(p_prefix)
    returning last_no into v_no;

    v_code := btrim(p_prefix) || '-' || lpad(v_no::text, 4, '0');
    exit when not exists (
      select 1 from public.items i
      where i.org_id = p_org_id and i.code = v_code
    );
    v_tries := v_tries + 1;
    if v_tries > 100 then
      raise exception 'ERR_INVALID_VALUE: khong sinh duoc ma moi cho tien to %', p_prefix;
    end if;
  end loop;

  return v_code;
end $$;

comment on function public.next_item_code(uuid, text) is
  'T-014: sinh ma kieu TP-0001 cho dong NO_CODE (khoa dong item_code_sequences). Chi goi ben trong RPC commit.';

revoke all on function public.next_item_code(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. Chuan hoa 1 dong vat tu (tra ve {normalized, issues, blank})
-- ---------------------------------------------------------------------------
create or replace function public.import_normalize_item(
  p_org_id uuid, p_raw jsonb, p_group_map jsonb, p_resolution jsonb
) returns jsonb
language plpgsql
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_name text;
  v_name_norm text;
  v_code text;
  v_group_raw text;
  v_group_id uuid;
  v_group_kind text;
  v_group_prefix text;
  v_stock_uom text;
  v_recipe_uom text;
  v_factor numeric(18,4);
  v_purchase_uom text;
  v_purchase_factor numeric(18,4);
  v_key_item boolean := false;
  v_vat numeric(18,4);
  v_shelf integer;
  v_shelf_raw text;
  v_norm jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_existing record;
  v_sim numeric;
  v_sim_code text;
  v_kind_raw text;
begin
  v_name := btrim(normalize(coalesce(p_raw ->> 'name', ''), NFC));
  v_code := upper(btrim(coalesce(p_raw ->> 'code', '')));
  if (p_resolution ->> 'new_code') is not null and btrim(p_resolution ->> 'new_code') <> '' then
    v_code := upper(btrim(p_resolution ->> 'new_code'));
  end if;

  -- Dong trong: khong ten, khong ma -> bo qua, khong dem.
  if v_name = '' and v_code = '' then
    return jsonb_build_object('normalized', '{}'::jsonb, 'issues', '[]'::jsonb, 'blank', true);
  end if;

  if v_name = '' then
    v_issues := v_issues || jsonb_build_object(
      'code', 'EMPTY_NAME', 'field', 'name',
      'message', 'Thiếu tên vật tư.', 'severity', 'error');
  else
    v_name_norm := public.norm_text(v_name);
  end if;

  if v_code = '' then
    v_issues := v_issues || jsonb_build_object(
      'code', 'NO_CODE', 'field', 'code',
      'message', 'Thiếu mã vật tư: sẽ sinh mã theo tiền tố nhóm khi ghi.',
      'severity', 'warning');
    v_code := null;
  else
    -- Ma da ton tai trong DB?
    select i.id, i.code, i.name_norm into v_existing
    from public.items i
    where i.org_id = p_org_id and i.code = v_code;
    if found then
      if v_name_norm is not null and v_existing.name_norm = v_name_norm then
        v_issues := v_issues || jsonb_build_object(
          'code', 'EXISTING', 'field', 'code',
          'message', 'Mã ' || v_code || ' đã có trong danh mục với cùng tên: sẽ bỏ qua dòng này.',
          'severity', 'warning',
          'existing_id', v_existing.id);
      else
        v_issues := v_issues || jsonb_build_object(
          'code', 'DUP_CODE', 'field', 'code',
          'message', 'Mã ' || v_code || ' đã thuộc về vật tư khác trong danh mục.',
          'severity', 'error');
      end if;
    end if;
  end if;

  -- Ten trung / gan trung trong DB (pg_trgm, nguong 0,8 theo 07 section 2).
  if v_name_norm is not null then
    select i.id, i.code into v_existing
    from public.items i
    where i.org_id = p_org_id and i.name_norm = v_name_norm;
    if found then
      v_issues := v_issues || jsonb_build_object(
        'code', 'NEAR_DUP_NAME', 'field', 'name',
        'message', 'Tên đã tồn tại trong danh mục với mã ' || v_existing.code || ': cần gộp hoặc đổi tên.',
        'severity', 'error',
        'existing_id', v_existing.id, 'existing_code', v_existing.code);
    else
      select extensions.similarity(v_name_norm, i.name_norm), i.code
        into v_sim, v_sim_code
      from public.items i
      where i.org_id = p_org_id
      order by extensions.similarity(v_name_norm, i.name_norm) desc
      limit 1;
      if v_sim is not null and v_sim > 0.8 then
        v_issues := v_issues || jsonb_build_object(
          'code', 'NEAR_DUP_NAME', 'field', 'name',
          'message', 'Tên gần trùng với vật tư ' || v_sim_code || ' (độ tương đồng ' || round(v_sim, 2) || '): cân nhắc gộp.',
          'severity', 'warning',
          'existing_code', v_sim_code);
      end if;
    end if;
  end if;

  -- Nhom hang: anh xa qua group_map cua batch (khoa = gia tri cot Loai).
  v_group_raw := btrim(coalesce(p_raw ->> 'group_raw', ''));
  if (p_resolution ->> 'group_id') is not null and btrim(p_resolution ->> 'group_id') <> '' then
    v_group_id := (p_resolution ->> 'group_id')::uuid;
  elsif v_group_raw <> '' and p_group_map ? v_group_raw then
    v_group_id := (p_group_map ->> v_group_raw)::uuid;
  else
    v_group_id := null;
  end if;

  if v_group_id is null then
    v_issues := v_issues || jsonb_build_object(
      'code', 'UNKNOWN_GROUP', 'field', 'group_raw',
      'message', 'Chưa ánh xạ nhóm hàng cho loại "' || v_group_raw || '".',
      'severity', 'error');
  else
    select g.kind, g.code_prefix into v_group_kind, v_group_prefix
    from public.item_groups g
    where g.id = v_group_id and g.org_id = p_org_id;
    if not found then
      v_issues := v_issues || jsonb_build_object(
        'code', 'UNKNOWN_GROUP', 'field', 'group_raw',
        'message', 'Nhóm hàng đã chọn không thuộc tổ chức này.',
        'severity', 'error');
      v_group_kind := null;
      v_group_prefix := null;
    elsif v_group_raw <> '' and v_group_raw ~* '^ccdc$' and v_group_kind <> 'ccdc' then
      v_issues := v_issues || jsonb_build_object(
        'code', 'GROUP_KIND_MISMATCH', 'field', 'group_raw',
        'message', 'Loại CCDC nên ánh xạ vào nhóm kind ccdc.',
        'severity', 'warning');
    end if;
  end if;

  -- Don vi kho / cong thuc.
  if (p_resolution ->> 'stock_uom') is not null and btrim(p_resolution ->> 'stock_uom') <> '' then
    v_stock_uom := public.import_normalize_uom(p_resolution ->> 'stock_uom');
  else
    v_stock_uom := public.import_normalize_uom(p_raw ->> 'stock_uom_raw');
  end if;
  if v_stock_uom is null then
    v_issues := v_issues || jsonb_build_object(
      'code', 'UNKNOWN_UOM', 'field', 'stock_uom_raw',
      'message', 'Đơn vị kho "' || coalesce(p_raw ->> 'stock_uom_raw', '') || '" chưa có trong danh mục hoặc chưa có biến thể ánh xạ.',
      'severity', 'error');
  end if;

  v_recipe_uom := public.import_normalize_uom(p_raw ->> 'recipe_uom_raw');
  if (p_raw ->> 'recipe_uom_raw') is not null
    and btrim(p_raw ->> 'recipe_uom_raw') <> ''
    and v_recipe_uom is null then
    v_issues := v_issues || jsonb_build_object(
      'code', 'UNKNOWN_UOM', 'field', 'recipe_uom_raw',
      'message', 'Đơn vị công thức "' || (p_raw ->> 'recipe_uom_raw') || '" chưa có trong danh mục hoặc chưa có biến thể ánh xạ.',
      'severity', 'error');
  end if;

  -- He so qui doi kho -> cong thuc.
  if (p_resolution ->> 'factor') is not null then
    v_factor := public.import_parse_number(p_resolution -> 'factor');
  else
    v_factor := public.import_parse_number(p_raw -> 'factor_raw');
  end if;
  if v_recipe_uom is not null and v_stock_uom is not null and v_recipe_uom <> v_stock_uom then
    if v_factor is null or v_factor <= 0 then
      v_issues := v_issues || jsonb_build_object(
        'code', 'NO_FACTOR', 'field', 'factor_raw',
        'message', 'Thiếu hệ số quy đổi từ ' || v_stock_uom || ' sang ' || v_recipe_uom || '.',
        'severity', case when v_group_kind in ('food', 'beverage') then 'error' else 'warning' end);
      v_factor := null;
    elsif v_factor = 1 then
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_FACTOR', 'field', 'factor_raw',
        'message', 'Hệ số = 1 trong khi đơn vị kho (' || v_stock_uom || ') khác đơn vị công thức (' || v_recipe_uom || '): kiểm tra lại số liệu.',
        'severity', 'warning');
    end if;
  else
    -- Cung don vi hoac khong co don vi cong thuc: khong can he so.
    v_factor := null;
  end if;

  -- Quy cach mua (mau chuan mau_vat_tu.xlsx): thieu he so chi la canh bao.
  v_purchase_uom := public.import_normalize_uom(p_raw ->> 'purchase_uom_raw');
  if (p_raw ->> 'purchase_uom_raw') is not null
    and btrim(p_raw ->> 'purchase_uom_raw') <> '' then
    if v_purchase_uom is null then
      v_issues := v_issues || jsonb_build_object(
        'code', 'UNKNOWN_UOM', 'field', 'purchase_uom_raw',
        'message', 'Đơn vị mua "' || (p_raw ->> 'purchase_uom_raw') || '" chưa có trong danh mục.',
        'severity', 'error');
    else
      v_purchase_factor := public.import_parse_number(p_raw -> 'purchase_factor_raw');
      if v_purchase_factor is null or v_purchase_factor <= 0 then
        v_issues := v_issues || jsonb_build_object(
          'code', 'NO_FACTOR', 'field', 'purchase_factor_raw',
          'message', 'Thiếu hệ số quy đổi mua -> kho cho đơn vị ' || v_purchase_uom || ': sẽ không tạo quy cách mua.',
          'severity', 'warning');
        v_purchase_factor := null;
      end if;
    end if;
  end if;

  -- key_item / vat / han dung (cac cot tuy chon trong mau chuan docs/07 §5).
  if btrim(coalesce(p_raw ->> 'key_item', '')) <> '' then
    v_key_item := lower(btrim(p_raw ->> 'key_item')) in ('1', 'true', 'x', 'co', 'yes', 'y');
  end if;
  if btrim(coalesce(p_raw ->> 'vat', '')) <> '' then
    v_vat := public.import_parse_number(p_raw ->> 'vat');
    if v_vat is null or v_vat < 0 or v_vat > 100 then
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_VALUE', 'field', 'vat',
        'message', 'VAT không hợp lệ (phải là số 0–100): "' || (p_raw ->> 'vat') || '".',
        'severity', 'error');
    end if;
  end if;
  v_shelf_raw := btrim(coalesce(p_raw ->> 'expiry_days', ''));
  if v_shelf_raw <> '' then
    begin
      v_shelf := v_shelf_raw::integer;
      if v_shelf <= 0 then
        raise exception 'not positive';
      end if;
    exception when others then
      v_shelf := null;
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_VALUE', 'field', 'expiry_days',
        'message', 'Hạn dùng (ngày) không hợp lệ: "' || v_shelf_raw || '".',
        'severity', 'error');
    end;
  end if;

  v_norm := jsonb_build_object(
    'code', v_code,
    'name', nullif(v_name, ''),
    'name_en', nullif(btrim(coalesce(p_raw ->> 'name_en', '')), ''),
    'group_id', v_group_id,
    'group_kind', v_group_kind,
    'group_prefix', v_group_prefix,
    'is_ccdc', (v_group_kind = 'ccdc'),
    'stock_uom', v_stock_uom,
    'recipe_uom', v_recipe_uom,
    'stock_to_recipe', v_factor,
    'cost_group', nullif(btrim(coalesce(p_raw ->> 'cost_group', '')), ''),
    'legacy_code', nullif(btrim(coalesce(p_raw ->> 'legacy_code', '')), ''),
    'purchase_uom', v_purchase_uom,
    'purchase_factor', v_purchase_factor,
    'key_item', v_key_item,
    'vat_rate', v_vat,
    'shelf_life_days', v_shelf
  );

  return jsonb_build_object('normalized', v_norm, 'issues', v_issues, 'blank', false);
end $$;

revoke all on function public.import_normalize_item(uuid, jsonb, jsonb, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Chuan hoa 1 dong NCC (tra ve {normalized, issues, blank})
-- ---------------------------------------------------------------------------
create or replace function public.import_normalize_supplier(
  p_org_id uuid, p_raw jsonb, p_resolution jsonb
) returns jsonb
language plpgsql
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_name text;
  v_code text;
  v_kind_raw text;
  v_kind text;
  v_terms numeric(18,4);
  v_norm jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_existing record;
  v_bank_name text;
  v_account_no text;
  v_account_name text;
begin
  v_name := btrim(normalize(coalesce(p_raw ->> 'name', ''), NFC));
  v_code := upper(btrim(coalesce(p_raw ->> 'code', '')));
  if (p_resolution ->> 'new_code') is not null and btrim(p_resolution ->> 'new_code') <> '' then
    v_code := upper(btrim(p_resolution ->> 'new_code'));
  end if;

  if v_name = '' and v_code = '' then
    return jsonb_build_object('normalized', '{}'::jsonb, 'issues', '[]'::jsonb, 'blank', true);
  end if;

  if v_name = '' then
    v_issues := v_issues || jsonb_build_object(
      'code', 'EMPTY_NAME', 'field', 'name',
      'message', 'Thiếu tên nhà cung cấp.', 'severity', 'error');
  end if;

  if v_code = '' then
    v_issues := v_issues || jsonb_build_object(
      'code', 'NO_CODE', 'field', 'code',
      'message', 'Thiếu mã nhà cung cấp: sẽ sinh mã NCC-0001... khi ghi.',
      'severity', 'warning');
    v_code := null;
  else
    select s.id, s.code, s.name into v_existing
    from public.suppliers s
    where s.org_id = p_org_id and s.code = v_code;
    if found then
      if public.norm_text(v_existing.name) = public.norm_text(v_name) then
        v_issues := v_issues || jsonb_build_object(
          'code', 'EXISTING', 'field', 'code',
          'message', 'Mã ' || v_code || ' đã có trong danh mục với cùng tên: sẽ bỏ qua dòng này.',
          'severity', 'warning',
          'existing_id', v_existing.id);
      else
        v_issues := v_issues || jsonb_build_object(
          'code', 'DUP_CODE', 'field', 'code',
          'message', 'Mã ' || v_code || ' đã thuộc về nhà cung cấp khác trong danh mục.',
          'severity', 'error');
      end if;
    end if;
  end if;

  -- Loai NCC: chap nhan tieng Viet va tieng Anh.
  v_kind_raw := lower(btrim(coalesce(p_raw ->> 'kind_raw', '')));
  if (p_resolution ->> 'kind') is not null then
    v_kind := p_resolution ->> 'kind';
  elsif v_kind_raw in ('công ty', 'cong ty', 'company') then
    v_kind := 'company';
  elsif v_kind_raw in ('hộ kinh doanh', 'ho kinh doanh', 'household') then
    v_kind := 'household';
  elsif v_kind_raw in ('cá nhân', 'ca nhan', 'individual', 'individual_no_invoice') then
    v_kind := 'individual_no_invoice';
  elsif v_kind_raw = '' then
    v_kind := 'company';
    v_issues := v_issues || jsonb_build_object(
      'code', 'INVALID_VALUE', 'field', 'kind_raw',
      'message', 'Thiếu loại nhà cung cấp: tạm mặc định là Công ty, kiểm tra lại trước khi ghi.',
      'severity', 'warning');
  else
    v_issues := v_issues || jsonb_build_object(
      'code', 'INVALID_VALUE', 'field', 'kind_raw',
      'message', 'Loại nhà cung cấp "' || (p_raw ->> 'kind_raw') || '" không hợp lệ (công ty / hộ kinh doanh / cá nhân).',
      'severity', 'error');
  end if;

  -- Ma so thue trung.
  if (p_raw ->> 'tax_code') is not null and btrim(p_raw ->> 'tax_code') <> '' then
    select s.id, s.code into v_existing
    from public.suppliers s
    where s.org_id = p_org_id and s.tax_code = btrim(p_raw ->> 'tax_code');
    if found then
      v_issues := v_issues || jsonb_build_object(
        'code', 'TAX_CODE_DUP', 'field', 'tax_code',
        'message', 'Mã số thuế đã thuộc về nhà cung cấp ' || v_existing.code || '.',
        'severity', 'warning',
        'existing_id', v_existing.id);
    end if;
  end if;

  -- Han thanh toan: so nguyen >= 0.
  v_terms := public.import_parse_number(p_raw -> 'payment_terms_days');
  if (p_raw -> 'payment_terms_days') is not null
    and (p_raw ->> 'payment_terms_days') is not null
    and btrim(p_raw ->> 'payment_terms_days') <> ''
    and (v_terms is null or v_terms < 0 or v_terms <> trunc(v_terms)) then
    v_issues := v_issues || jsonb_build_object(
      'code', 'INVALID_VALUE', 'field', 'payment_terms_days',
      'message', 'Hạn thanh toán phải là số ngày nguyên không âm.',
      'severity', 'error');
    v_terms := null;
  end if;

  -- Tai khoan ngan hang kem theo: co 1 thi phai du ca 3.
  v_bank_name := btrim(coalesce(p_raw ->> 'bank_name', ''));
  v_account_no := btrim(coalesce(p_raw ->> 'account_no', ''));
  v_account_name := btrim(coalesce(p_raw ->> 'account_name', ''));
  if v_bank_name <> '' or v_account_no <> '' or v_account_name <> '' then
    if v_bank_name = '' or v_account_no = '' or v_account_name = '' then
      v_issues := v_issues || jsonb_build_object(
        'code', 'INVALID_VALUE', 'field', 'bank_name',
        'message', 'Tài khoản ngân hàng thiếu ngân hàng, số tài khoản hoặc chủ tài khoản.',
        'severity', 'error');
    else
      select b.id, b.supplier_id into v_existing
      from public.supplier_bank_accounts b
      join public.suppliers s on s.id = b.supplier_id
      where s.org_id = p_org_id and b.account_no = v_account_no
        and b.status in ('pending', 'active')
      limit 1;
      if found then
        v_issues := v_issues || jsonb_build_object(
          'code', 'BANK_ACCOUNT_DUP', 'field', 'account_no',
          'message', 'Số tài khoản đã tồn tại ở một nhà cung cấp khác.',
          'severity', 'warning');
      end if;
    end if;
  end if;

  v_norm := jsonb_build_object(
    'code', v_code,
    'name', nullif(v_name, ''),
    'tax_code', nullif(btrim(coalesce(p_raw ->> 'tax_code', '')), ''),
    'kind', v_kind,
    'phone', nullif(btrim(coalesce(p_raw ->> 'phone', '')), ''),
    'address', nullif(btrim(coalesce(p_raw ->> 'address', '')), ''),
    'payment_terms_days', case when v_terms is null then null else v_terms::integer end,
    'bank_name', nullif(v_bank_name, ''),
    'account_no', nullif(v_account_no, ''),
    'account_name', nullif(v_account_name, '')
  );

  return jsonb_build_object('normalized', v_norm, 'issues', v_issues, 'blank', false);
end $$;

revoke all on function public.import_normalize_supplier(uuid, jsonb, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10. Validate toan bo batch (pass 1: chuan hoa tung dong; pass 2: DUP_CODE
--     trong file; pass 3: dem + cap nhat trang thai batch). Goi lai duoc
--     (idempotent): moi lan chay tinh lai tu raw_data + resolution.
-- ---------------------------------------------------------------------------
create or replace function public.import_validate_batch(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_batch public.import_batches%rowtype;
  v_group_map jsonb := '{}'::jsonb;
  v_row public.import_rows%rowtype;
  v_out jsonb;
  v_norm jsonb;
  v_issues jsonb;
  v_status text;
  v_resolution jsonb;
  v_has_error boolean;
  v_has_warning boolean;
  v_dup_code text;
  v_name_count integer;
  v_first_id uuid;
  v_counts jsonb;
  v_target_exists boolean;
begin
  select * into v_batch from public.import_batches where id = p_batch_id for update;
  if not found then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy phiên import %', p_batch_id;
  end if;
  if v_batch.status = 'committed' then
    raise exception 'ERR_INVALID_STATUS: phiên import đã ghi, không validate lại';
  end if;

  perform public.require_perm(v_batch.property_id, 'item.import');

  select coalesce(m.group_map, '{}'::jsonb) into v_group_map
  from public.import_mappings m where m.id = v_batch.mapping_id;

  -- Pass 1: chuan hoa tung dong.
  for v_row in
    select * from public.import_rows where batch_id = p_batch_id order by row_no
  loop
    v_resolution := coalesce(v_row.resolution, '{}'::jsonb);

    if (v_resolution ->> 'action') = 'skip' then
      update public.import_rows
      set status = 'skipped', issues = '[]'::jsonb
      where id = v_row.id;
      continue;
    end if;

    if (v_resolution ->> 'action') = 'merge' then
      if v_batch.kind = 'items' then
        select exists (select 1 from public.items i
          where i.id = (v_resolution ->> 'target_id')::uuid and i.org_id = v_batch.org_id)
        into v_target_exists;
      else
        select exists (select 1 from public.suppliers s
          where s.id = (v_resolution ->> 'target_id')::uuid and s.org_id = v_batch.org_id)
        into v_target_exists;
      end if;
      if v_target_exists then
        update public.import_rows
        set status = 'merged',
          target_id = (v_resolution ->> 'target_id')::uuid,
          target_code = (v_resolution ->> 'target_code'),
          issues = '[]'::jsonb
        where id = v_row.id;
      else
        update public.import_rows
        set status = 'error',
          issues = jsonb_build_array(jsonb_build_object(
            'code', 'INVALID_VALUE', 'field', 'resolution',
            'message', 'Mục tiêu gộp không còn tồn tại.', 'severity', 'error'))
        where id = v_row.id;
      end if;
      continue;
    end if;

    if v_batch.kind = 'items' then
      v_out := public.import_normalize_item(
        v_batch.org_id, v_row.raw_data, v_group_map, v_resolution);
    else
      v_out := public.import_normalize_supplier(
        v_batch.org_id, v_row.raw_data, v_resolution);
    end if;

    if coalesce((v_out ->> 'blank')::boolean, false) then
      update public.import_rows
      set status = 'skipped',
        normalized_data = '{"_blank": true}'::jsonb,
        issues = '[]'::jsonb
      where id = v_row.id;
      continue;
    end if;

    v_norm := v_out -> 'normalized';
    v_issues := v_out -> 'issues';

    -- 'keep': nguoi dung da xem canh bao va chap nhan -> bo cac warning.
    if (v_resolution ->> 'action') = 'keep' then
      select coalesce(jsonb_agg(x), '[]'::jsonb) into v_issues
      from jsonb_array_elements(v_issues) x
      where x ->> 'severity' = 'error';
    end if;

    v_has_error := exists (
      select 1 from jsonb_array_elements(v_issues) x where x ->> 'severity' = 'error');
    v_has_warning := exists (
      select 1 from jsonb_array_elements(v_issues) x where x ->> 'severity' = 'warning');
    v_status := case when v_has_error then 'error'
      when v_has_warning then 'warning' else 'ok' end;

    update public.import_rows
    set normalized_data = v_norm, issues = v_issues, status = v_status
    where id = v_row.id;
  end loop;

  -- Pass 2: DUP_CODE trong file (ma hieu luc sau resolution).
  for v_dup_code in
    select r.normalized_data ->> 'code'
    from public.import_rows r
    where r.batch_id = p_batch_id
      and r.status in ('ok', 'warning', 'error')
      and r.normalized_data ->> 'code' is not null
    group by r.normalized_data ->> 'code'
    having count(*) > 1
  loop
    select count(distinct public.norm_text(r.normalized_data ->> 'name'))
    into v_name_count
    from public.import_rows r
    where r.batch_id = p_batch_id
      and r.normalized_data ->> 'code' = v_dup_code
      and r.status in ('ok', 'warning', 'error');

    if v_name_count > 1 then
      -- Mot ma nhieu ten: loi tren tat ca dong trong nhom.
      update public.import_rows r
      set issues = r.issues || jsonb_build_object(
            'code', 'DUP_CODE', 'field', 'code',
            'message', 'Mã ' || v_dup_code || ' gán cho ' || v_name_count
              || ' tên khác nhau trong file: chọn tách mã mới hoặc gộp.',
            'severity', 'error'),
        status = 'error'
      where r.batch_id = p_batch_id
        and r.normalized_data ->> 'code' = v_dup_code
        and r.status in ('ok', 'warning', 'error');
    else
      -- Trung ca ma va ten: giu dong dau, loi cac dong sau.
      select r.id into v_first_id
      from public.import_rows r
      where r.batch_id = p_batch_id
        and r.normalized_data ->> 'code' = v_dup_code
        and r.status in ('ok', 'warning', 'error')
      order by r.row_no
      limit 1;

      update public.import_rows r
      set issues = r.issues || jsonb_build_object(
            'code', 'DUP_CODE', 'field', 'code',
            'message', 'Trùng cả mã và tên với dòng trước trong file: chọn gộp hoặc bỏ qua.',
            'severity', 'error'),
        status = 'error'
      where r.batch_id = p_batch_id
        and r.normalized_data ->> 'code' = v_dup_code
        and r.status in ('ok', 'warning', 'error')
        and r.id <> v_first_id;
    end if;
  end loop;

  -- Pass 3: dem + cap nhat batch.
  select jsonb_build_object(
    'total', count(*) filter (where not (normalized_data ? '_blank')),
    'skipped_blank', count(*) filter (where normalized_data ? '_blank'),
    'ok', count(*) filter (where status = 'ok'),
    'warnings', count(*) filter (where status = 'warning'),
    'errors', count(*) filter (where status = 'error'),
    'skipped', count(*) filter (where status = 'skipped' and not (normalized_data ? '_blank')),
    'merged', count(*) filter (where status = 'merged'),
    'committed', count(*) filter (where status = 'committed'),
    'dup_code', count(*) filter (where exists (
      select 1 from jsonb_array_elements(issues) x where x ->> 'code' = 'DUP_CODE')),
    'near_dup', count(*) filter (where exists (
      select 1 from jsonb_array_elements(issues) x where x ->> 'code' = 'NEAR_DUP_NAME')),
    'no_code', count(*) filter (where exists (
      select 1 from jsonb_array_elements(issues) x where x ->> 'code' = 'NO_CODE')),
    'no_factor', count(*) filter (where exists (
      select 1 from jsonb_array_elements(issues) x where x ->> 'code' = 'NO_FACTOR')),
    'unknown_uom', count(*) filter (where exists (
      select 1 from jsonb_array_elements(issues) x where x ->> 'code' = 'UNKNOWN_UOM')),
    'unknown_group', count(*) filter (where exists (
      select 1 from jsonb_array_elements(issues) x where x ->> 'code' = 'UNKNOWN_GROUP')),
    'created', 0
  ) into v_counts
  from public.import_rows
  where batch_id = p_batch_id;

  update public.import_batches
  set counts = v_counts,
    status = case
      when (v_counts ->> 'errors')::integer = 0
        and (v_counts ->> 'total')::integer > 0 then 'validated'
      else 'draft' end,
    row_count = (v_counts ->> 'total')::integer
  where id = p_batch_id;

  return jsonb_build_object(
    'batch_id', p_batch_id,
    'status', case
      when (v_counts ->> 'errors')::integer = 0
        and (v_counts ->> 'total')::integer > 0 then 'validated'
      else 'draft' end,
    'counts', v_counts);
end $$;

comment on function public.import_validate_batch(uuid) is
  'T-014: validate lai toan bo batch (idempotent). Dung sau tao batch va sau moi lan resolve.';

revoke all on function public.import_validate_batch(uuid) from public, anon, authenticated;
grant execute on function public.import_validate_batch(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPC: tao batch tu cac dong tho (client da parse .xlsx) + validate ngay
-- ---------------------------------------------------------------------------
create or replace function public.import_create_batch(
  p_property_id uuid, p_kind text, p_file_name text,
  p_mapping_id uuid, p_rows jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_org uuid;
  v_batch_id uuid;
  v_row record;
  v_n integer := 0;
  v_result jsonb;
begin
  perform public.require_perm(p_property_id, 'item.import');

  select org_id into v_org from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:item.import';
  end if;

  if p_kind not in ('items', 'suppliers') then
    raise exception 'ERR_INVALID_VALUE: kind phai la items hoac suppliers';
  end if;
  if p_file_name is null or btrim(p_file_name) = '' then
    raise exception 'ERR_INVALID_VALUE: thieu ten file';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'ERR_INVALID_VALUE: du lieu dong phai la mang JSON';
  end if;
  if jsonb_array_length(p_rows) < 1 or jsonb_array_length(p_rows) > 5000 then
    raise exception 'ERR_INVALID_VALUE: so dong phai tu 1 den 5000';
  end if;
  if p_mapping_id is not null and not exists (
    select 1 from public.import_mappings m
    where m.id = p_mapping_id and m.org_id = v_org and m.kind = p_kind
  ) then
    raise exception 'ERR_INVALID_VALUE: mau anh xa khong thuoc to chuc hoac sai loai';
  end if;

  insert into public.import_batches
    (org_id, property_id, kind, mapping_id, file_name, status)
  values (v_org, p_property_id, p_kind, p_mapping_id, btrim(p_file_name), 'draft')
  returning id into v_batch_id;

  for v_row in select jsonb_array_elements(p_rows) as elem loop
    if jsonb_typeof(v_row.elem) <> 'object' then
      raise exception 'ERR_INVALID_VALUE: moi dong phai la doi tuong JSON';
    end if;
    v_n := v_n + 1;
    insert into public.import_rows (batch_id, row_no, raw_data)
    values (v_batch_id, v_n, v_row.elem);
  end loop;

  v_result := public.import_validate_batch(v_batch_id);
  return v_result;
end $$;

comment on function public.import_create_batch(uuid, text, text, uuid, jsonb) is
  'T-014: tao phien import tu cac dong tho (JSON) + validate ngay, tra ve tom tat dem. Khong ghi gi vao bang that cho toi buoc 4 (commit).';

revoke all on function public.import_create_batch(uuid, text, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.import_create_batch(uuid, text, text, uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 12. RPC: ghi quyet dinh xu ly 1 dong (split/merge/set_*/skip/keep) + validate lai
-- ---------------------------------------------------------------------------
create or replace function public.import_resolve_row(
  p_batch_id uuid, p_row_id uuid, p_resolution jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_batch public.import_batches%rowtype;
  v_action text;
begin
  select * into v_batch from public.import_batches where id = p_batch_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy phiên import %', p_batch_id;
  end if;
  if v_batch.status = 'committed' then
    raise exception 'ERR_INVALID_STATUS: phiên import đã ghi, không sửa được';
  end if;
  if v_batch.status = 'discarded' then
    raise exception 'ERR_INVALID_STATUS: phiên import đã hủy';
  end if;

  perform public.require_perm(v_batch.property_id, 'item.import');

  if not exists (
    select 1 from public.import_rows r where r.id = p_row_id and r.batch_id = p_batch_id
  ) then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy dòng trong phiên import';
  end if;

  v_action := p_resolution ->> 'action';
  if v_action not in ('split', 'merge', 'set_code', 'set_factor', 'set_group', 'set_uom', 'skip', 'keep') then
    raise exception 'ERR_INVALID_VALUE: action khong hop le: %', coalesce(v_action, '');
  end if;
  if v_action in ('split', 'set_code')
    and ((p_resolution ->> 'new_code') is null or btrim(p_resolution ->> 'new_code') = '') then
    raise exception 'ERR_INVALID_VALUE: tach/doi ma can new_code';
  end if;
  if v_action = 'merge'
    and ((p_resolution ->> 'target_id') is null or btrim(p_resolution ->> 'target_id') = '') then
    raise exception 'ERR_INVALID_VALUE: gop can target_id';
  end if;
  if v_action = 'set_factor' and (p_resolution -> 'factor') is null then
    raise exception 'ERR_INVALID_VALUE: dat he so can factor';
  end if;
  if v_action = 'set_group'
    and ((p_resolution ->> 'group_id') is null or btrim(p_resolution ->> 'group_id') = '') then
    raise exception 'ERR_INVALID_VALUE: doi nhom can group_id';
  end if;
  if v_action = 'set_uom'
    and ((p_resolution ->> 'stock_uom') is null or btrim(p_resolution ->> 'stock_uom') = '') then
    raise exception 'ERR_INVALID_VALUE: doi don vi can stock_uom';
  end if;

  update public.import_rows
  set resolution = p_resolution
  where id = p_row_id;

  return public.import_validate_batch(p_batch_id);
end $$;

comment on function public.import_resolve_row(uuid, uuid, jsonb) is
  'T-014: ghi quyet dinh xu ly 1 dong roi validate lai toan bo batch.';

revoke all on function public.import_resolve_row(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.import_resolve_row(uuid, uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 13. RPC: ghi batch vao bang that trong 1 transaction (buoc 4)
-- ---------------------------------------------------------------------------
create or replace function public.import_commit_batch(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_batch public.import_batches%rowtype;
  v_row public.import_rows%rowtype;
  v_norm jsonb;
  v_code text;
  v_item_id uuid;
  v_supplier_id uuid;
  v_created integer := 0;
  v_skipped integer := 0;
  v_merged integer := 0;
  v_existing_id uuid;
  v_has_existing boolean;
begin
  select * into v_batch from public.import_batches where id = p_batch_id for update;
  if not found then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy phiên import %', p_batch_id;
  end if;
  if v_batch.status <> 'validated' then
    raise exception 'ERR_INVALID_STATUS: phiên import chưa đạt kiểm tra (còn lỗi hoặc đã ghi/hủy)';
  end if;

  perform public.require_perm(v_batch.property_id, 'item.import');

  for v_row in
    select * from public.import_rows
    where batch_id = p_batch_id and status in ('ok', 'warning', 'merged', 'skipped')
    order by row_no
  loop
    if v_row.status = 'merged' then
      v_merged := v_merged + 1;
      continue;
    end if;
    if v_row.status = 'skipped' then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_norm := v_row.normalized_data;
    select
      exists (select 1 from jsonb_array_elements(v_row.issues) x
        where x ->> 'code' = 'EXISTING'),
      (select (x ->> 'existing_id')::uuid
       from jsonb_array_elements(v_row.issues) x
       where x ->> 'code' = 'EXISTING' limit 1)
    into v_has_existing, v_existing_id;
    if v_has_existing then
      -- Ma + ten da co san: bo qua, chi ghi target.
      update public.import_rows
      set status = 'committed', target_id = v_existing_id,
        target_code = (v_norm ->> 'code')
      where id = v_row.id;
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if v_batch.kind = 'items' then
      v_code := v_norm ->> 'code';
      if v_code is null or v_code = '' then
        v_code := public.next_item_code(
          v_batch.org_id, coalesce(v_norm ->> 'group_prefix', 'TP'));
      end if;

      insert into public.items (
        org_id, code, name, name_en, group_id, stock_uom, recipe_uom,
        stock_to_recipe, legacy_code, is_key_item, vat_rate,
        shelf_life_days, status
      ) values (
        v_batch.org_id, v_code, v_norm ->> 'name', v_norm ->> 'name_en',
        (v_norm ->> 'group_id')::uuid, v_norm ->> 'stock_uom',
        v_norm ->> 'recipe_uom',
        case when v_norm ->> 'stock_to_recipe' is null then null
          else (v_norm ->> 'stock_to_recipe')::numeric(18,4) end,
        v_norm ->> 'legacy_code',
        coalesce((v_norm ->> 'key_item')::boolean, false),
        case when v_norm ->> 'vat_rate' is null then null
          else (v_norm ->> 'vat_rate')::numeric(18,4) end,
        case when v_norm ->> 'shelf_life_days' is null then null
          else (v_norm ->> 'shelf_life_days')::integer end,
        'active'
      ) returning id into v_item_id;

      if (v_norm ->> 'purchase_uom') is not null
        and (v_norm ->> 'purchase_factor') is not null then
        insert into public.item_purchase_units
          (item_id, uom, factor_to_stock, is_default)
        values (
          v_item_id, v_norm ->> 'purchase_uom',
          (v_norm ->> 'purchase_factor')::numeric(18,4), true);
      end if;

      update public.import_rows
      set status = 'committed', target_id = v_item_id, target_code = v_code
      where id = v_row.id;
    else
      v_code := v_norm ->> 'code';
      if v_code is null or v_code = '' then
        v_code := public.next_item_code(v_batch.org_id, 'NCC');
      end if;

      insert into public.suppliers (
        org_id, code, name, tax_code, kind, phone, address,
        payment_terms_days, status
      ) values (
        v_batch.org_id, v_code, v_norm ->> 'name', v_norm ->> 'tax_code',
        v_norm ->> 'kind', v_norm ->> 'phone', v_norm ->> 'address',
        case when v_norm ->> 'payment_terms_days' is null then null
          else (v_norm ->> 'payment_terms_days')::integer end,
        'pending'
      ) returning id into v_supplier_id;

      if (v_norm ->> 'account_no') is not null then
        insert into public.supplier_bank_accounts (
          supplier_id, bank_name, account_no, account_name, status, requested_by
        ) values (
          v_supplier_id, v_norm ->> 'bank_name', v_norm ->> 'account_no',
          v_norm ->> 'account_name', 'pending', auth.uid());
      end if;

      update public.import_rows
      set status = 'committed', target_id = v_supplier_id, target_code = v_code
      where id = v_row.id;
    end if;

    v_created := v_created + 1;
  end loop;

  update public.import_batches
  set status = 'committed',
    committed_at = now(),
    committed_by = auth.uid(),
    counts = counts || jsonb_build_object(
      'created', v_created, 'skipped', v_skipped, 'merged', v_merged)
  where id = p_batch_id;

  return jsonb_build_object(
    'batch_id', p_batch_id,
    'status', 'committed',
    'created', v_created,
    'skipped', v_skipped,
    'merged', v_merged);
end $$;

comment on function public.import_commit_batch(uuid) is
  'T-014: ghi batch vao bang that trong 1 transaction (buoc 4 cua 07 section 2). Chi chay khi batch o trang thai validated. Vat tu tao moi o active; NCC moi o pending + tai khoan (neu co) o pending theo vong doi T-013.';

revoke all on function public.import_commit_batch(uuid) from public, anon, authenticated;
grant execute on function public.import_commit_batch(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 14. RPC: huy batch + them bien the don vi + doc batch/danh sach batch
-- ---------------------------------------------------------------------------
create or replace function public.import_discard_batch(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_batch public.import_batches%rowtype;
begin
  select * into v_batch from public.import_batches where id = p_batch_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy phiên import %', p_batch_id;
  end if;
  if v_batch.status in ('committed', 'discarded') then
    raise exception 'ERR_INVALID_STATUS: phiên import đã ghi hoặc đã hủy';
  end if;

  perform public.require_perm(v_batch.property_id, 'item.import');

  update public.import_batches set status = 'discarded' where id = p_batch_id;
  return jsonb_build_object('batch_id', p_batch_id, 'status', 'discarded');
end $$;

revoke all on function public.import_discard_batch(uuid) from public, anon, authenticated;
grant execute on function public.import_discard_batch(uuid) to authenticated;

create or replace function public.import_add_uom_alias(
  p_property_id uuid, p_alias text, p_uom_code text
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_canon text;
begin
  perform public.require_perm(p_property_id, 'item.manage');

  if p_alias is null or btrim(p_alias) = '' then
    raise exception 'ERR_INVALID_VALUE: thieu bien the don vi';
  end if;
  if not exists (select 1 from public.uoms u where u.code = btrim(p_uom_code)) then
    raise exception 'ERR_UOM_UNKNOWN: don vi % chua co trong danh muc', p_uom_code;
  end if;

  v_canon := extensions.unaccent(lower(btrim(normalize(p_alias, NFC))));

  insert into public.uom_aliases (alias, uom_code)
  values (v_canon, btrim(p_uom_code))
  on conflict (alias) do update set uom_code = excluded.uom_code;

  return jsonb_build_object('alias', v_canon, 'uom_code', btrim(p_uom_code));
end $$;

comment on function public.import_add_uom_alias(uuid, text, text) is
  'T-014: them bien the viet don vi (quyen item.manage). Dung khi gap UNKNOWN_UOM: them alias roi validate lai batch.';

revoke all on function public.import_add_uom_alias(uuid, text, text) from public, anon, authenticated;
grant execute on function public.import_add_uom_alias(uuid, text, text) to authenticated;

create or replace function public.import_get_batch(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_batch public.import_batches%rowtype;
  v_can boolean := false;
begin
  select * into v_batch from public.import_batches where id = p_batch_id;
  if not found then
    raise exception 'ERR_INVALID_STATUS: không tìm thấy phiên import %', p_batch_id;
  end if;

  v_can := public.has_perm(v_batch.property_id, 'item.view')
    or public.has_perm(v_batch.property_id, 'item.import')
    or public.has_perm(null, 'item.view')
    or public.has_perm(null, 'item.import');
  if not v_can then
    raise exception 'ERR_FORBIDDEN:item.view';
  end if;

  return jsonb_build_object(
    'batch', jsonb_build_object(
      'id', v_batch.id, 'kind', v_batch.kind, 'file_name', v_batch.file_name,
      'status', v_batch.status, 'row_count', v_batch.row_count,
      'counts', v_batch.counts, 'created_at', v_batch.created_at,
      'committed_at', v_batch.committed_at, 'mapping_id', v_batch.mapping_id),
    'rows', coalesce((
      select jsonb_agg(x order by x.row_no)
      from (
        select r.id, r.row_no, r.raw_data, r.normalized_data, r.status,
          r.issues, r.resolution, r.target_id, r.target_code
        from public.import_rows r
        where r.batch_id = p_batch_id
      ) x
    ), '[]'::jsonb));
end $$;

revoke all on function public.import_get_batch(uuid) from public, anon, authenticated;
grant execute on function public.import_get_batch(uuid) to authenticated;

create or replace function public.import_list_batches(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_org uuid;
  v_can boolean := false;
begin
  select org_id into v_org from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:item.view';
  end if;

  v_can := public.has_perm(p_property_id, 'item.view')
    or public.has_perm(p_property_id, 'item.import')
    or public.has_perm(null, 'item.view')
    or public.has_perm(null, 'item.import');
  if not v_can then
    raise exception 'ERR_FORBIDDEN:item.view';
  end if;

  return coalesce((
    select jsonb_agg(x order by x.created_at desc)
    from (
      select b.id, b.kind, b.file_name, b.status, b.row_count, b.counts,
        b.created_at, b.committed_at
      from public.import_batches b
      where b.org_id = v_org
      order by b.created_at desc
      limit 20
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function public.import_list_batches(uuid) from public, anon, authenticated;
grant execute on function public.import_list_batches(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 15. Gan quyen mau: `item.import` (da co trong seed quyen, chua gan cho ai)
--     -> cost_controller, chief_accountant, gm. Join theo ma vai tro.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('cost_controller', 'item.import'),
  ('chief_accountant', 'item.import'),
  ('gm', 'item.import')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 16. RPC: luu + liet ke mau anh xa (client khong query truc tiep bang
--     duoc vi bang moi chua co trong database.types.ts chua sinh lai)
-- ---------------------------------------------------------------------------
create or replace function public.import_save_mapping(
  p_property_id uuid, p_kind text, p_name text,
  p_column_map jsonb, p_group_map jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_org uuid;
  v_id uuid;
begin
  perform public.require_perm(p_property_id, 'item.import');

  select org_id into v_org from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:item.import';
  end if;
  if p_kind not in ('items', 'suppliers') then
    raise exception 'ERR_INVALID_VALUE: kind phai la items hoac suppliers';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'ERR_INVALID_VALUE: thieu ten mau anh xa';
  end if;

  insert into public.import_mappings
    (org_id, source, kind, name, column_map, group_map)
  values (v_org, 'master_excel', p_kind, btrim(p_name),
    coalesce(p_column_map, '{}'::jsonb), coalesce(p_group_map, '{}'::jsonb))
  on conflict (org_id, kind, name) do update set
    column_map = excluded.column_map,
    group_map = excluded.group_map,
    updated_at = now()
  returning id into v_id;

  return jsonb_build_object('mapping_id', v_id);
end $$;

comment on function public.import_save_mapping(uuid, text, text, jsonb, jsonb) is
  'T-014: luu mau anh xa cot (upsert theo org+kind+name).';

revoke all on function public.import_save_mapping(uuid, text, text, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.import_save_mapping(uuid, text, text, jsonb, jsonb) to authenticated;

create or replace function public.import_list_mappings(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth, pg_temp as $$
declare
  v_org uuid;
  v_can boolean := false;
begin
  select org_id into v_org from public.properties where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_FORBIDDEN:item.view';
  end if;

  v_can := public.has_perm(p_property_id, 'item.view')
    or public.has_perm(p_property_id, 'item.import')
    or public.has_perm(null, 'item.view')
    or public.has_perm(null, 'item.import');
  if not v_can then
    raise exception 'ERR_FORBIDDEN:item.view';
  end if;

  return coalesce((
    select jsonb_agg(x order by x.name)
    from (
      select m.id, m.kind, m.name, m.column_map, m.group_map, m.sample_header
      from public.import_mappings m
      where m.org_id = v_org
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function public.import_list_mappings(uuid) from public, anon, authenticated;
grant execute on function public.import_list_mappings(uuid) to authenticated;
