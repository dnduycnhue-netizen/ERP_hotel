-- Q272 (14/11/2026): restaurant_sales_summary — lai gop chi tinh mon biet gia von (B-7).
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
        -- Q272 (B-7): lai gop chi tinh tren mon BIET gia von (cung quy tac voi
        -- bao cao F&B). Truoc day doanh thu mon thieu gia von van duoc tinh
        -- vao lai gop nhu thanh phan gia von = 0 -> 145.000 d vs 0 d.
        'gross_profit', coalesce((select sum(revenue - foodcost) from per_dish
          where foodcost is not null), 0),
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
