-- C12 (Q74): cap quyen de nguoi quyet toan tam ung gan duoc phieu nhan
-- va anh bien lai vao tung dong chi.
--
-- Van de: `advance.settle` chi gan cho vai tro `accountant` (140000),
-- nhung `accountant` khong co `attachment.upload` (chi co
-- `attachment.view`, 200000) va khong co `receiving.view` (chi co
-- `storekeeper` + `chef` qua 450000). Khong co 2 quyen nay, form quyet
-- toan khong tai duoc anh bien lai (`attachment_prepare_upload` doi
-- `attachment.upload`) va khong liet ke duoc phieu nhan da chot
-- (`receiving_list_receipts` doi `receiving.view`).
--
-- Fix: gan them 2 quyen tren cho `accountant`. Khong them ma quyen moi,
-- khong doi schema/RLS/RPC, khong doi has_perm/require_perm.
-- Idempotent: pure INSERT ... ON CONFLICT DO NOTHING, join tren role code
-- (khong loc is_system, theo bai hoc T-013/170000).
--
-- Sau `supabase db push`, verify tren production:
--   select r.code, rp.permission_code
--   from role_permissions rp join roles r on r.id = rp.role_id
--   where r.code = 'accountant'
--     and rp.permission_code in ('attachment.upload', 'receiving.view')
--   order by 2;
-- Expect 2 rows.

insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('accountant', 'attachment.upload'),
    ('accountant', 'receiving.view')
) as rp(role_code, permission_code)
  on r.code = rp.role_code
on conflict (role_id, permission_code) do nothing;
