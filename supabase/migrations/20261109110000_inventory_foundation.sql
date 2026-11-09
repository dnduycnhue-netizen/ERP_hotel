-- T-011, phần nền: chưa mở quyền ghi hoặc đọc cho client.
-- Hàm post, lớp FIFO và các RPC khóa sổ được triển khai ở migration tiếp theo.

alter table public.properties add constraint properties_id_entity_org_key
  unique (id, legal_entity_id, org_id);

create table public.lots (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null,
  item_id uuid not null,
  lot_no text not null check (btrim(lot_no) <> ''),
  expiry_date date,
  received_at timestamptz not null default now(),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, property_id, item_id, org_id),
  unique (property_id, item_id, lot_no),
  foreign key (property_id, org_id) references public.properties(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id)
);

create table public.stock_moves (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null,
  property_id uuid not null,
  warehouse_id uuid not null,
  item_id uuid not null,
  lot_id uuid,
  move_type text not null check (move_type in (
    'opening', 'receipt', 'return_out', 'issue_out', 'issue_in', 'transfer_out',
    'transfer_in', 'purpose_issue', 'waste', 'adjust_count', 'production_out',
    'production_in', 'minibar_sale', 'merge_out', 'merge_in', 'reversal'
  )),
  qty numeric(18,4) not null check (qty <> 0),
  unit_cost numeric(18,4) not null check (unit_cost >= 0),
  amount numeric(18,2) not null,
  business_date date not null check (isfinite(business_date)),
  posted_at timestamptz not null default now(),
  posted_by uuid not null references auth.users(id),
  source_doc_type text not null check (btrim(source_doc_type) <> ''),
  source_doc_id uuid not null,
  source_line_id uuid,
  reverses_move_id bigint unique references public.stock_moves(id),
  cost_center_id uuid,
  expense_category_id uuid,
  purpose_code text,
  foreign key (property_id, legal_entity_id, org_id)
    references public.properties(id, legal_entity_id, org_id),
  foreign key (warehouse_id, property_id)
    references public.warehouses(id, property_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id),
  foreign key (cost_center_id, org_id) references public.cost_centers(id, org_id),
  foreign key (expense_category_id, org_id) references public.expense_categories(id, org_id),
  check ((move_type = 'reversal') = (reverses_move_id is not null)),
  check (amount = round(qty * unit_cost, 2))
);

create index stock_moves_warehouse_item_date_idx
  on public.stock_moves (warehouse_id, item_id, business_date);
create index stock_moves_source_idx
  on public.stock_moves (source_doc_type, source_doc_id);
create index stock_moves_entity_date_idx
  on public.stock_moves (legal_entity_id, business_date);

create table public.stock_balances (
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null,
  property_id uuid not null,
  warehouse_id uuid not null,
  item_id uuid not null,
  lot_id uuid,
  qty numeric(18,4) not null check (qty >= 0),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (warehouse_id, item_id, lot_id),
  foreign key (property_id, legal_entity_id, org_id)
    references public.properties(id, legal_entity_id, org_id),
  foreign key (warehouse_id, property_id)
    references public.warehouses(id, property_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (lot_id, property_id, item_id, org_id)
    references public.lots(id, property_id, item_id, org_id)
);

create table public.item_costs (
  legal_entity_id uuid not null,
  org_id uuid not null references public.organizations(id),
  item_id uuid not null,
  avg_cost numeric(18,4) not null default 0 check (avg_cost >= 0),
  qty_on_hand numeric(18,4) not null default 0 check (qty_on_hand >= 0),
  updated_at timestamptz not null default now(),
  primary key (legal_entity_id, item_id),
  foreign key (legal_entity_id, org_id) references public.legal_entities(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id)
);

create table public.accounting_periods (
  id uuid primary key default gen_random_uuid(),
  legal_entity_id uuid not null references public.legal_entities(id),
  year integer not null check (year between 1 and 9999),
  month integer not null check (month between 1 and 12),
  status text not null default 'open' check (status in ('open', 'closing', 'closed')),
  closed_by uuid references auth.users(id),
  closed_at timestamptz,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (legal_entity_id, year, month),
  check (status <> 'closed' or (closed_by is not null and closed_at is not null))
);

create table public.day_locks (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null,
  warehouse_id uuid not null,
  business_date date not null check (isfinite(business_date)),
  shift text,
  locked_by uuid not null references auth.users(id),
  locked_at timestamptz not null default now(),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (warehouse_id, business_date, shift),
  foreign key (warehouse_id, property_id) references public.warehouses(id, property_id)
);
create index day_locks_warehouse_date_idx on public.day_locks (warehouse_id, business_date);

create trigger trg_stock_moves_immutable before update or delete on public.stock_moves
  for each row execute function public.forbid_mutation();
create trigger trg_lots_updated_at before update on public.lots
  for each row execute function public.set_updated_at();
create trigger trg_accounting_periods_updated_at before update on public.accounting_periods
  for each row execute function public.set_updated_at();
create trigger trg_day_locks_updated_at before update on public.day_locks
  for each row execute function public.set_updated_at();
create trigger trg_lots_audit after insert or update or delete on public.lots
  for each row execute function public.audit_trigger();
create trigger trg_accounting_periods_audit after insert or update or delete on public.accounting_periods
  for each row execute function public.audit_trigger();
create trigger trg_day_locks_audit after insert or update or delete on public.day_locks
  for each row execute function public.audit_trigger();

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'lots', 'stock_moves', 'stock_balances', 'item_costs',
    'accounting_periods', 'day_locks'
  ]
  loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
  end loop;
end;
$$;
revoke all on sequence public.stock_moves_id_seq from public, anon, authenticated;
