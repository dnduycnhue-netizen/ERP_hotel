-- R3-N2: uat.hk_attendant chi co vai cu hk_attendant (khong co minibar.refill) nen
-- khong thay khoi "Bo sung theo tang" (SOP-13). Gan them vai gon sm_housekeeping
-- (co minibar.refill) giong uat.hk_supervisor. Chi tac dong tai khoan UAT, idempotent.
insert into public.user_property_roles (user_id, role_id, property_id, valid_from, valid_to, granted_by)
select cur.user_id, r.id, cur.property_id, cur.valid_from, cur.valid_to, cur.granted_by
from public.user_property_roles cur
join auth.users u on u.id = cur.user_id and u.email = 'uat.hk_attendant@erp.internal'
join public.roles old_r on old_r.id = cur.role_id and old_r.code = 'hk_attendant'
join public.roles r on r.code = 'sm_housekeeping' and r.org_id = old_r.org_id
where not exists (
  select 1 from public.user_property_roles x
  where x.user_id = cur.user_id and x.role_id = r.id and x.property_id = cur.property_id
);
