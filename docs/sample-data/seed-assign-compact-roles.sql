-- seed-assign-compact-roles.sql — gan 7 vai tro gon sm_* cho tai khoan hien co (Q260).
-- KHONG phai migration. Chay 1 lan; idempotent (da co thi bo qua).
-- CONG THEM (khong go vai tro cu): moi tai khoan GIU vai tro cu, nhan them vai
-- tro gon tuong ung, cung pham vi (khach san / chuoi) voi vai tro cu cua no:
--   uat.owner -> sm_owner            uat.gm -> sm_manager
--   uat.accountant -> sm_accountant  uat.purchaser -> sm_purchasing_store
--   uat.chef -> sm_kitchen           uat.hk_supervisor -> sm_housekeeping
--   uat.front_desk -> sm_frontdesk
--   dnduy@hueic.edu.vn (Duy) -> sm_owner
--   owner@sonhoianhotel.com (test 01, tai khoan thu moi vai tro) -> sm_owner, sm_manager
-- Sau do doi buoc duyet PO ve 2 buoc (cung file, phan 2):
--   buoc 1 = sm_manager (tu 0 d), buoc 2 = sm_owner (tu 100.000.000 d, giu moc owner cu).
--   Han muc do Quan ly tu chinh o /admin/approval-rules.
-- Go bo: xem cuoi file.
begin;

insert into public.user_property_roles (user_id, role_id, property_id, warehouse_ids, outlet_ids, granted_by)
select upr.user_id, nr.id, upr.property_id, upr.warehouse_ids, upr.outlet_ids, '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from (values
  ('uat.owner@erp.internal', 'owner', 'sm_owner'),
  ('uat.gm@erp.internal', 'gm', 'sm_manager'),
  ('uat.accountant@erp.internal', 'accountant', 'sm_accountant'),
  ('uat.purchaser@erp.internal', 'purchaser', 'sm_purchasing_store'),
  ('uat.chef@erp.internal', 'chef', 'sm_kitchen'),
  ('uat.hk_supervisor@erp.internal', 'hk_supervisor', 'sm_housekeeping'),
  ('uat.front_desk@erp.internal', 'front_desk', 'sm_frontdesk'),
  ('dnduy@hueic.edu.vn', 'owner', 'sm_owner'),
  ('owner@sonhoianhotel.com', 'owner', 'sm_owner'),
  ('owner@sonhoianhotel.com', 'gm', 'sm_manager')
) as m(email, old_code, new_code)
join auth.users u on u.email = m.email
join public.roles orr on orr.code = m.old_code
join public.user_property_roles upr on upr.user_id = u.id and upr.role_id = orr.id
join public.roles nr on nr.org_id = orr.org_id and nr.code = m.new_code
where not exists (
  select 1 from public.user_property_roles x
  where x.user_id = u.id and x.role_id = nr.id and x.property_id is not distinct from upr.property_id
);

-- Phan 2: don mua (PO) con 2 buoc duyet. Bo 2 buoc giua/cao, doi 2 buoc con lai sang vai tro moi.
delete from public.approval_rules
where doc_type = 'po' and step in (3, 4)
  and org_id = (select org_id from public.roles where code = 'sm_manager' limit 1);

update public.approval_rules ar
set approver_role_id = (select id from public.roles r where r.org_id = ar.org_id and r.code = 'sm_manager'),
    min_amount = 0, max_amount = null
where ar.doc_type = 'po' and ar.step = 1 and ar.property_id is null;

update public.approval_rules ar
set approver_role_id = (select id from public.roles r where r.org_id = ar.org_id and r.code = 'sm_owner'),
    min_amount = 100000000, max_amount = null
where ar.doc_type = 'po' and ar.step = 2 and ar.property_id is null;

commit;

-- Go bo (neu can):
--   delete from public.user_property_roles where role_id in (select id from public.roles where code like 'sm\_%');
--   (va dat lai buoc duyet PO cu qua /admin/approval-rules)
