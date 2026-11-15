-- Q284: huy hoa don chua duyet (Tam giu / Nhap / Da khop) de lap hoa don thay the.
-- Hoa don da duyet (da ghi ap_ledger) KHONG huy duoc o day (so cai bat bien).
alter table public.supplier_invoices
  add column if not exists cancel_reason text,
  add column if not exists cancelled_by uuid references auth.users(id),
  add column if not exists cancelled_at timestamptz;

create or replace function public.invoice_cancel(
  p_invoice_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_inv record;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;
  select * into v_inv from public.supplier_invoices where id = p_invoice_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  perform public.require_perm(v_inv.property_id, 'invoice.manage');
  if v_inv.status not in ('draft', 'on_hold', 'matched') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.finance_guard_bypass', 'on', true);

  update public.supplier_invoices
  set status = 'cancelled', cancel_reason = btrim(p_reason),
      cancelled_by = auth.uid(), cancelled_at = now(), updated_at = now()
  where id = p_invoice_id;

  return jsonb_build_object('ok', true, 'id', p_invoice_id, 'status', 'cancelled');
end;
$$;

revoke all on function public.invoice_cancel(uuid, text) from public, anon;
grant execute on function public.invoice_cancel(uuid, text) to authenticated;
