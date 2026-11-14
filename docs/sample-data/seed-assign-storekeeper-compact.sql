-- seed-assign-storekeeper-compact.sql — gan vai tro gon sm_purchasing_store cho uat.storekeeper (Q270).
-- KHONG phai migration. Idempotent. CONG THEM (giu vai tro storekeeper cu, van co receiving.*).
-- Ly do: B-14/B-15 bao cao dem 13-14/11 — thu kho can xem PO, de xuat huy hang, xem gia tri ton.
-- Go bo: delete from public.user_property_roles where role_id = (select id from public.roles where code='sm_purchasing_store' limit 1)
--        and user_id = (select id from auth.users where email='uat.storekeeper@erp.internal');
begin;
insert into public.user_property_roles (user_id, role_id, property_id, warehouse_ids, outlet_ids, granted_by)
select upr.user_id, nr.id, upr.property_id, upr.warehouse_ids, upr.outlet_ids, '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from auth.users u
join public.roles orr on orr.code = 'storekeeper'
join public.user_property_roles upr on upr.user_id = u.id and upr.role_id = orr.id
join public.roles nr on nr.org_id = orr.org_id and nr.code = 'sm_purchasing_store'
where u.email = 'uat.storekeeper@erp.internal'
  and not exists (
    select 1 from public.user_property_roles x
    where x.user_id = u.id and x.role_id = nr.id and x.property_id is not distinct from upr.property_id
  );
commit;
