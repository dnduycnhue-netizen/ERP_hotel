create schema if not exists extensions;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.norm_text(p_text text)
returns text
language sql
immutable
parallel safe
set search_path = pg_catalog
as $$
  select btrim(
    regexp_replace(
      lower(normalize(coalesce(p_text, ''), NFC)),
      '\s+',
      ' ',
      'g'
    )
  )
$$;

create table public.audit_log (
  id bigint generated always as identity primary key,
  table_name text not null,
  row_id text not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb,
  actor uuid,
  at timestamptz not null default now(),
  client_info jsonb not null default '{}'::jsonb
);

alter table public.audit_log enable row level security;

create or replace function public.forbid_mutation()
returns trigger
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  raise exception using
    errcode = '55000',
    message = format('ERR_IMMUTABLE_LEDGER:%s:%s', tg_table_name, tg_op);
end;
$$;

create trigger trg_audit_log_immutable
before update or delete on public.audit_log
for each row execute function public.forbid_mutation();

create or replace function public.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_headers jsonb;
  v_row_id text;
begin
  if tg_op <> 'INSERT' then
    v_old := to_jsonb(old);
  end if;
  if tg_op <> 'DELETE' then
    v_new := to_jsonb(new);
  end if;

  v_row := coalesce(v_new, v_old);
  v_row_id := coalesce(
    v_row ->> 'id',
    v_row ->> 'code',
    concat_ws(':', nullif(v_row ->> 'role_id', ''), nullif(v_row ->> 'permission_code', '')),
    concat_ws(':', nullif(v_row ->> 'user_id', ''), nullif(v_row ->> 'permission_code', '')),
    md5(v_row::text)
  );
  v_headers := coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb,
    '{}'::jsonb
  ) - 'authorization' - 'cookie' - 'apikey' - 'x-supabase-api-version';

  insert into public.audit_log (
    table_name,
    row_id,
    action,
    old_data,
    new_data,
    actor,
    client_info
  )
  values (
    tg_table_name,
    v_row_id,
    tg_op,
    v_old,
    v_new,
    auth.uid(),
    v_headers
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.norm_text(text) from public, anon, authenticated;
revoke all on function public.forbid_mutation() from public, anon, authenticated;
revoke all on function public.audit_trigger() from public, anon, authenticated;