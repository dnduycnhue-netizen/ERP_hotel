-- seed-approval-rules-manager.sql — Duy chot 13/11/2026 (Q263): Quan ly (sm_manager) duyet
-- phieu de xuat mua (PR), phieu linh kho (requisition) va phieu huy hang (waste).
-- KHONG phai migration (du lieu cau hinh theo to chuc; Quan ly doi duoc o /admin/approval-rules).
-- Truoc: PR/phieu linh -> outlet_head, phieu huy -> cost_controller. Sau: ca 3 -> sm_manager.
-- Chung tu da duyet khong bi anh huong; hien khong co buoc duyet nao dang cho.
begin;
update public.approval_rules ar
set approver_role_id = (select id from public.roles r where r.org_id = ar.org_id and r.code = 'sm_manager')
where ar.doc_type in ('pr', 'requisition', 'waste')
  and ar.step = 1
  and exists (select 1 from public.roles r where r.org_id = ar.org_id and r.code = 'sm_manager');
commit;
-- Dat lai nhu cu:
--   pr, requisition -> vai tro outlet_head; waste -> vai tro cost_controller (qua /admin/approval-rules).
