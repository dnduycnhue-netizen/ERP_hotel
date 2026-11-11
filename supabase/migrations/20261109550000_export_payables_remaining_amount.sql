-- Q227: export_payables referenced r.amount in the `detail` subquery, but the
-- `remaining` CTE only selected (supplier_id, due, remaining) — no `amount`
-- column. The function is plpgsql, so the bad reference was never validated at
-- CREATE time; every call that passed the lock check failed at runtime with
-- 42703 (column r.amount does not exist). The payables export never worked on
-- production (found by T-043 accounting run 2, 2026-11-12 01:23, at §10).
-- Fix: select p.amount in the `remaining` CTE (the original positive ledger
-- amount = payable_pos, the gross payable before FIFO payment allocation).
-- No other change: payable/paid/balance/aging math is untouched.
create or replace function public.export_payables(
  p_legal_entity_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_property_id uuid;
  v_entity record;
  v_rows jsonb;
  v_total_payable numeric(18, 2);
  v_total_paid numeric(18, 2);
  v_total_balance numeric(18, 2);
  v_count integer;
begin
  v_property_id := public._export_require(p_legal_entity_id, p_from, p_to);
  select id, code, name into v_entity
  from public.legal_entities where id = p_legal_entity_id;

  perform public._export_assert_locked(
    p_legal_entity_id, v_property_id, p_from, p_to, 'finance'
  );

  with ledger as (
    select supplier_id, due_date, entry_date, amount
    from public.ap_ledger
    where legal_entity_id = p_legal_entity_id
      and entry_date <= p_to
  ),
  paid as (
    select supplier_id, sum(-amount)::numeric(18, 2) as paid_pool
    from ledger where amount < 0
    group by supplier_id
  ),
  positives as (
    select
      supplier_id,
      coalesce(due_date, entry_date) as due,
      amount,
      coalesce(
        sum(amount) over (
          partition by supplier_id
          order by coalesce(due_date, entry_date), entry_date
          rows between unbounded preceding and 1 preceding
        ),
        0
      ) as cum_before
    from ledger
    where amount > 0
  ),
  remaining as (
    select
      p.supplier_id,
      p.due,
      p.amount,
      p.amount
        - least(
            p.amount,
            greatest(0, coalesce(pa.paid_pool, 0) - p.cum_before)
          ) as remaining
    from positives p
    left join paid pa on pa.supplier_id = p.supplier_id
  )
  select
    coalesce(jsonb_agg(r order by r.balance desc), '[]'::jsonb),
    coalesce(sum(r.payable), 0),
    coalesce(sum(r.paid), 0),
    coalesce(sum(r.balance), 0),
    count(*)
  into v_rows, v_total_payable, v_total_paid, v_total_balance, v_count
  from (
    select
      s.code as supplier_code,
      s.name as supplier_name,
      agg.payable,
      agg.paid,
      agg.balance,
      agg.not_due,
      agg.overdue_1_30,
      agg.overdue_31_60,
      agg.overdue_61_90,
      agg.overdue_over_90,
      agg.oldest_overdue_days
    from (
      select
        supplier_id,
        sum(payable_pos)::numeric(18, 2) as payable,
        least(coalesce(max(paid_pool), 0), sum(payable_pos))::numeric(18, 2) as paid,
        (sum(payable_pos) - least(coalesce(max(paid_pool), 0), sum(payable_pos)))::numeric(18, 2) as balance,
        sum(case when (p_to - due) <= 0 then remaining else 0 end)::numeric(18, 2) as not_due,
        sum(case when (p_to - due) between 1 and 30 then remaining else 0 end)::numeric(18, 2) as overdue_1_30,
        sum(case when (p_to - due) between 31 and 60 then remaining else 0 end)::numeric(18, 2) as overdue_31_60,
        sum(case when (p_to - due) between 61 and 90 then remaining else 0 end)::numeric(18, 2) as overdue_61_90,
        sum(case when (p_to - due) > 90 then remaining else 0 end)::numeric(18, 2) as overdue_over_90,
        max(case when remaining > 0 and (p_to - due) > 0 then (p_to - due) end) as oldest_overdue_days
      from (
        select
          r.supplier_id,
          r.due,
          r.remaining,
          r.amount as payable_pos,
          pa.paid_pool
        from remaining r
        left join paid pa on pa.supplier_id = r.supplier_id
      ) detail
      group by supplier_id
    ) agg
    join public.suppliers s on s.id = agg.supplier_id
    where agg.balance > 0
  ) r;

  return jsonb_build_object(
    'ok', true,
    'entity', jsonb_build_object('id', v_entity.id, 'code', v_entity.code, 'name', v_entity.name),
    'property_id', v_property_id,
    'from', p_from::text,
    'to', p_to::text,
    'exported_at', now(),
    'exported_by', auth.uid(),
    'rows', v_rows,
    'totals', jsonb_build_object(
      'supplier_count', v_count,
      'payable', v_total_payable,
      'paid', v_total_paid,
      'balance', v_total_balance
    )
  );
end;
$$;

revoke all on function public.export_payables(uuid, date, date)
  from public, anon;
grant execute on function public.export_payables(uuid, date, date)
  to authenticated;
