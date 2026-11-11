-- Q207 (11/11/2026): restaurant_sales_summary() gom sum(qty)/sum(amount)
-- TRONG jsonb_agg(...) o muc by_day -> Postgres nem 42803
-- "aggregate function calls cannot be nested" ngay lan goi dau tien.
-- Ham la plpgsql nen loi khong bi chan luc CREATE (migration 500000);
-- chi lo ra khi bo pgTAP nha hang chay that lan dau (11/11/2026).
-- Sua: gom nhom truoc trong subquery (giong mau 'prep' cua
-- restaurant_kitchen_today), roi jsonb_agg tren cac dong da gom.
-- Chi doi dung khoi by_day; toan bo phan con lai giu nguyen.
-- Sau db push, chay lai supabase/tests/restaurant_test.sql (§11 goi ham
-- nay 3 lan) de kiem chung.
create or replace function public.restaurant_sales_summary(
  p_property_id uuid, p_from date default null, p_to date default null
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_from date := coalesce(p_from,
    date_trunc('month', (now() at time zone 'Asia/Ho_Chi_Minh')::date)::date);
  v_to date := coalesce(p_to,
    (now() at time zone 'Asia/Ho_Chi_Minh')::date);
begin
  perform public.require_perm(p_property_id, 'restaurant.view');

  select org_id into v_org_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;
  if v_from > v_to then raise exception 'ERR_INVALID_VALUE'; end if;

  return (
    with sales as (
      select ds.*
      from public.dish_sales ds
      where ds.property_id = p_property_id
        and ds.business_date between v_from and v_to
        and ds.voided_at is null
    ),
    per_dish as (
      select
        s.recipe_id, r.code as recipe_code, r.name as recipe_name,
        sum(s.qty) as qty,
        sum(s.amount) as revenue,
        case
          when s.recipe_id is null then null
          when f.has_unknown_cost then null
          else round(sum(s.qty) * coalesce(f.foodcost, 0), 2)
        end as foodcost
      from sales s
      left join public.recipes r on r.id = s.recipe_id
      left join public._restaurant_foodcost_list(p_property_id) f
        on f.recipe_id = s.recipe_id
      group by s.recipe_id, r.code, r.name, f.has_unknown_cost, f.foodcost
    )
    select jsonb_build_object(
      'ok', true, 'from', v_from, 'to', v_to,
      'totals', jsonb_build_object(
        'qty', coalesce((select sum(qty) from sales), 0),
        'revenue', coalesce((select sum(amount) from sales), 0),
        'foodcost', coalesce((select sum(foodcost) from per_dish), 0),
        'gross_profit', coalesce((select sum(amount) from sales), 0)
          - coalesce((select sum(foodcost) from per_dish), 0),
        'has_unknown_cost',
          exists (select 1 from per_dish where foodcost is null
            and recipe_id is not null)
      ),
      'by_day', coalesce((
        select jsonb_agg(jsonb_build_object(
          'business_date', business_date,
          'qty', qty, 'revenue', revenue
        ) order by business_date)
        from (
          select business_date, sum(qty) as qty, sum(amount) as revenue
          from sales group by business_date
        ) d
      ), '[]'::jsonb),
      'by_dish', coalesce((
        select jsonb_agg(jsonb_build_object(
          'recipe_id', recipe_id, 'recipe_code', recipe_code,
          'recipe_name', coalesce(recipe_name, 'Buffet (theo khách)'),
          'qty', qty, 'revenue', revenue, 'foodcost', foodcost,
          'gross_profit', case when foodcost is null then null
            else revenue - foodcost end
        ) order by revenue desc)
        from per_dish
      ), '[]'::jsonb)
    )
  );
end;
$$;
