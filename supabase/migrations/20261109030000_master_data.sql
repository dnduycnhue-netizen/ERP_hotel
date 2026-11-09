-- T-010: danh mục nền và cấp số chứng từ theo pháp nhân, loại và năm.

create table public.uoms (
  code text primary key check (code ~ '^[a-z][a-z0-9_]*$'),
  name_vi text not null check (btrim(name_vi) <> ''),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.item_groups (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  parent_id uuid,
  code_prefix text not null check (btrim(code_prefix) <> ''),
  name text not null check (public.norm_text(name) <> ''),
  kind text not null check (kind in (
    'food', 'beverage', 'amenity', 'complimentary', 'collateral', 'linen',
    'loan', 'chemical', 'tool', 'minibar', 'engineering', 'ccdc', 'other'
  )),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, code_prefix),
  foreign key (parent_id, org_id) references public.item_groups(id, org_id),
  check (id <> parent_id)
);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null check (btrim(code) <> ''),
  name text not null check (public.norm_text(name) <> ''),
  name_norm text generated always as (public.norm_text(name)) stored,
  name_en text,
  group_id uuid not null,
  stock_uom text not null references public.uoms(code),
  recipe_uom text references public.uoms(code),
  stock_to_recipe numeric(18,4) check (stock_to_recipe > 0),
  is_key_item boolean not null default false,
  abc_class text check (abc_class in ('A', 'B', 'C')),
  track_lot boolean not null default false,
  shelf_life_days integer check (shelf_life_days > 0),
  storage_condition text,
  vat_rate numeric(9,4) check (vat_rate between 0 and 100),
  allowed_channels text[] not null default array['contract', 'market']::text[]
    check (cardinality(allowed_channels) > 0 and
      allowed_channels <@ array['contract', 'market']::text[]),
  tare_g numeric(18,4) check (tare_g >= 0),
  density_g_ml numeric(18,4) check (density_g_ml > 0),
  is_temp boolean not null default false,
  temp_created_at timestamptz,
  status text not null default 'active' check (status in ('active', 'inactive', 'merged')),
  merged_into_id uuid,
  legacy_code text,
  external_codes jsonb not null default '{}'::jsonb check (jsonb_typeof(external_codes) = 'object'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, code),
  unique (org_id, name_norm),
  foreign key (group_id, org_id) references public.item_groups(id, org_id),
  foreign key (merged_into_id, org_id) references public.items(id, org_id),
  check (id <> merged_into_id),
  check ((status = 'merged') = (merged_into_id is not null)),
  check (not is_temp or temp_created_at is not null)
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null check (btrim(code) <> ''),
  name text not null check (btrim(name) <> ''),
  tax_code text,
  kind text not null check (kind in ('company', 'household', 'individual_no_invoice')),
  phone text,
  address text,
  payment_terms_days integer check (payment_terms_days >= 0),
  food_safety_cert_until date,
  status text not null default 'pending' check (status in ('pending', 'active', 'suspended', 'banned')),
  approved_by uuid references auth.users(id),
  external_codes jsonb not null default '{}'::jsonb check (jsonb_typeof(external_codes) = 'object'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, code)
);

create table public.item_purchase_units (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  item_id uuid not null,
  uom text not null references public.uoms(code),
  factor_to_stock numeric(18,4) not null check (factor_to_stock > 0),
  supplier_id uuid,
  is_default boolean not null default false,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (supplier_id, org_id) references public.suppliers(id, org_id),
  unique nulls not distinct (item_id, uom, supplier_id)
);
create unique index item_purchase_units_one_default
  on public.item_purchase_units (item_id) where is_default;

create table public.supplier_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  supplier_id uuid not null,
  bank_name text not null check (btrim(bank_name) <> ''),
  account_no text not null check (btrim(account_no) <> ''),
  account_name text not null check (btrim(account_name) <> ''),
  status text not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  requested_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (supplier_id, org_id) references public.suppliers(id, org_id),
  check (approved_by is null or approved_by <> requested_by),
  check (status <> 'active' or (approved_by is not null and approved_at is not null))
);

create table public.price_agreements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  supplier_id uuid not null,
  valid_from date not null,
  valid_to date not null check (valid_to >= valid_from),
  status text not null default 'draft' check (status in ('draft', 'active', 'expired', 'cancelled')),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (supplier_id, org_id) references public.suppliers(id, org_id)
);

create table public.price_agreement_lines (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  agreement_id uuid not null,
  item_id uuid not null,
  uom text not null references public.uoms(code),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  warn_pct numeric(9,4) check (warn_pct >= 0),
  lock_pct numeric(9,4) check (lock_pct >= 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (agreement_id, org_id) references public.price_agreements(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  unique (agreement_id, item_id, uom)
);

create table public.ceiling_prices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid,
  item_id uuid not null,
  uom text not null references public.uoms(code),
  price numeric(18,4) not null check (price >= 0),
  valid_from date not null,
  valid_to date not null check (valid_to >= valid_from),
  set_by uuid not null references auth.users(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (property_id, org_id) references public.properties(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id)
);

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  code text not null check (btrim(code) <> ''),
  name text not null check (btrim(name) <> ''),
  usali_line text,
  parent_id uuid,
  external_codes jsonb not null default '{}'::jsonb check (jsonb_typeof(external_codes) = 'object'),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, code),
  foreign key (parent_id, org_id) references public.expense_categories(id, org_id),
  check (id <> parent_id)
);

create table public.doc_sequences (
  legal_entity_id uuid not null references public.legal_entities(id),
  doc_type text not null check (doc_type ~ '^[A-Za-z][A-Za-z0-9_]{0,39}$'),
  year integer not null check (year between 1 and 9999),
  last_no bigint not null check (last_no > 0),
  primary key (legal_entity_id, doc_type, year)
);

alter table public.approval_rules
  add constraint approval_rules_item_group_org_fkey
  foreign key (item_group_id, org_id) references public.item_groups(id, org_id);

create function public.validate_approval_rule_item_group()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.item_group_id is not null and not exists (
    select 1 from public.item_groups g
    where g.id = new.item_group_id and g.org_id = new.org_id
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_ITEM_GROUP';
  end if;
  return new;
end;
$$;
revoke all on function public.validate_approval_rule_item_group() from public, anon, authenticated;
create trigger trg_approval_rules_item_group
  before insert or update of item_group_id, org_id on public.approval_rules
  for each row execute function public.validate_approval_rule_item_group();

create or replace function public.next_doc_no(
  p_entity uuid,
  p_doc_type text,
  p_date date default (now() at time zone 'Asia/Ho_Chi_Minh')::date
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_no bigint;
  v_code text;
begin
  if p_entity is null or p_doc_type is null
    or p_doc_type !~ '^[A-Za-z][A-Za-z0-9_]{0,39}$'
    or p_date is null or not isfinite(p_date) then
    raise exception using errcode = '22023', message = 'ERR_INVALID_DOCUMENT_NUMBER_INPUT';
  end if;

  select code into strict v_code from public.legal_entities where id = p_entity;
  insert into public.doc_sequences (legal_entity_id, doc_type, year, last_no)
  values (p_entity, p_doc_type, extract(year from p_date)::integer, 1)
  on conflict (legal_entity_id, doc_type, year)
  do update set last_no = public.doc_sequences.last_no + 1
  returning last_no into v_no;

  return format('%s-%s-%s-%s', p_doc_type, v_code, to_char(p_date, 'YYMM'),
    lpad(v_no::text, greatest(4, length(v_no::text)), '0'));
end;
$$;
revoke all on function public.next_doc_no(uuid, text, date) from public, anon, authenticated;

-- T-012/T-013 sẽ bổ sung các luồng ghi cùng kiểm soát nghiệp vụ tương ứng.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'uoms', 'item_groups', 'items', 'suppliers', 'item_purchase_units',
    'supplier_bank_accounts', 'price_agreements', 'price_agreement_lines',
    'ceiling_prices', 'expense_categories'
  ]
  loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
    execute format('grant select on table public.%I to authenticated', v_table);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', 'trg_' || v_table || '_updated_at', v_table);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_trigger()', 'trg_' || v_table || '_audit', v_table);
  end loop;
end;
$$;

alter table public.doc_sequences enable row level security;
revoke all on public.doc_sequences from public, anon, authenticated;

create policy uoms_select on public.uoms for select to authenticated using (auth.uid() is not null);
create policy item_groups_select on public.item_groups for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = item_groups.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'item.view'))
);
create policy items_select on public.items for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = items.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'item.view'))
);
create policy item_purchase_units_select on public.item_purchase_units for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = item_purchase_units.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'item.view'))
);
create policy suppliers_select on public.suppliers for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = suppliers.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'supplier.view'))
);
create policy supplier_bank_accounts_select on public.supplier_bank_accounts for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = supplier_bank_accounts.org_id
    and p.id in (select public.my_property_ids())
    and (public.has_perm(p.id, 'supplier.bank.request') or public.has_perm(p.id, 'supplier.bank.approve')))
);
create policy price_agreements_select on public.price_agreements for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = price_agreements.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'price.view'))
);
create policy price_agreement_lines_select on public.price_agreement_lines for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = price_agreement_lines.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'price.view'))
);
create policy ceiling_prices_select on public.ceiling_prices for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = ceiling_prices.org_id
    and (ceiling_prices.property_id is null or p.id = ceiling_prices.property_id)
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'price.view'))
);
create policy expense_categories_select on public.expense_categories for select to authenticated using (
  exists (select 1 from public.properties p where p.org_id = expense_categories.org_id
    and p.id in (select public.my_property_ids()) and public.has_perm(p.id, 'item.view'))
);

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam'), ('g', 'Gam'), ('l', 'Lít'), ('ml', 'Mililít'),
  ('cai', 'Cái'), ('chai', 'Chai'), ('lon', 'Lon'), ('goi', 'Gói'),
  ('hop', 'Hộp'), ('xap', 'Xấp'), ('phan', 'Phần');
