-- seed-demo-minibar-prices-test47.sql — DEMO (Q267): sao chep gia minibar hien hanh cua SONHOIAN sang TEST47.
-- Muse (docs/go-live/muse-report-demo-test.md, loi 5): TEST47 khong co gia minibar nen phieu kiem "Chua co gia",
-- nut Gui ket qua kiem bi khoa. Gia la gia THAM KHAO 2018 (can chot lai khi van hanh that).
-- KHONG phai migration. Idempotent. Go bo: delete from public.minibar_price_list where property_id = 'b0000000-0000-4000-8000-000000000002' and valid_from = '2026-11-11';
begin;
insert into public.minibar_price_list (org_id, property_id, item_id, price, valid_from, valid_to)
select s.org_id, 'b0000000-0000-4000-8000-000000000002', s.item_id, s.price, s.valid_from, s.valid_to
from public.minibar_price_list s
where s.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b'
  and s.valid_to is null
  and not exists (
    select 1 from public.minibar_price_list x
    where x.property_id = 'b0000000-0000-4000-8000-000000000002'
      and x.item_id = s.item_id and x.valid_from = s.valid_from);
commit;
