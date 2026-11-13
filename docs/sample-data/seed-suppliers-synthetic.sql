-- seed-suppliers-synthetic.sql — 16 nha cung cap GIA LAP (Q256).
-- Nguon: docs/samples/suppliers-sample-SYNTHETIC.xlsx (scripts/gen-supplier-sample.py).
-- KHONG phai migration. Chay 1 lan (idempotent: trung (org, code) thi bo qua).
-- NCC o trang thai active, duyet boi tai khoan Duy de test duoc mua hang ngay;
-- tai khoan ngan hang de 'pending' (can tai khoan KHAC duyet — SoD).
-- Du lieu GIA, danh dau external_codes.source = synthetic. Go bo:
--   delete from public.supplier_bank_accounts where supplier_id in (select id from public.suppliers where external_codes->>'source'='synthetic');
--   delete from public.suppliers where external_codes->>'source'='synthetic';  (chi khi chua co chung tu)
begin;
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0001', 'Công ty TNHH Thực phẩm Mẫu An Phát', '0900000001', 'company', '0900000001', 'Cẩm Châu, Hội An, Quảng Nam', 30, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Vietcombank', '0000000001', 'CONG TY TNHH THUC PHAM MAU AN PHAT', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0001' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000001');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0002', 'Công ty TNHH Hải sản Mẫu Biển Xanh', '0900000002', 'company', '0900000002', 'Sơn Trà, Đà Nẵng', 15, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Techcombank', '0000000002', 'CONG TY TNHH HAI SAN MAU BIEN XANH', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0002' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000002');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0003', 'Công ty CP Rau củ Mẫu Đà Lạt', '0900000003', 'company', '0900000003', 'Đà Lạt, Lâm Đồng', 30, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'BIDV', '0000000003', 'CONG TY CP RAU CU MAU DA LAT', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0003' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000003');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0004', 'Công ty TNHH Thịt Mẫu Sạch Quảng Nam', '0900000004', 'company', '0900000004', 'Điện Bàn, Quảng Nam', 15, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Agribank', '0000000004', 'CONG TY TNHH THIT MAU SACH QUANG NAM', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0004' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000004');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0005', 'Công ty TNHH Đồ uống Mẫu Miền Trung', '0900000005', 'company', '0900000005', 'Hải Châu, Đà Nẵng', 30, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Vietcombank', '0000000005', 'CONG TY TNHH DO UONG MAU MIEN TRUNG', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0005' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000005');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0006', 'Công ty TNHH Rượu vang Mẫu Phương Nam', '0900000006', 'company', '0900000006', 'Quận 3, TP. Hồ Chí Minh', 45, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'ACB', '0000000006', 'CONG TY TNHH RUOU VANG MAU PHUONG NAM', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0006' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000006');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0007', 'Công ty TNHH Bao bì Mẫu Xanh', '0900000007', 'company', '0900000007', 'Thanh Khê, Đà Nẵng', 30, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'VietinBank', '0000000007', 'CONG TY TNHH BAO BI MAU XANH', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0007' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000007');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0008', 'Công ty TNHH Hóa chất vệ sinh Mẫu Sạch', '0900000008', 'company', '0900000008', 'Liên Chiểu, Đà Nẵng', 30, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'MB Bank', '0000000008', 'CONG TY TNHH HOA CHAT VE SINH MAU SACH', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0008' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000008');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0009', 'Công ty TNHH Vật tư buồng phòng Mẫu Hội An', '0900000009', 'company', '0900000009', 'Minh An, Hội An, Quảng Nam', 30, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Vietcombank', '0000000009', 'CONG TY TNHH VAT TU BUONG PHONG MAU HOI AN', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0009' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000009');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0010', 'Công ty TNHH Gas và nhiên liệu Mẫu', '0900000010', 'company', '0900000010', 'Duy Xuyên, Quảng Nam', 15, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'BIDV', '0000000010', 'CONG TY TNHH GAS VA NHIEN LIEU MAU', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0010' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000010');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0011', 'Hộ kinh doanh Mẫu Bánh mì Cô Lan', null, 'household', '0900000011', 'Phố cổ, Hội An, Quảng Nam', 7, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0012', 'Hộ kinh doanh Mẫu Trứng gia cầm Ba Thanh', null, 'household', '0900000012', 'Điện Ngọc, Quảng Nam', 7, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Agribank', '0000000012', 'HO KINH DOANH MAU TRUNG GIA CAM BA THANH', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0012' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000012');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0013', 'Hộ kinh doanh Mẫu Đá viên Hội An', null, 'household', '0900000013', 'Cẩm Phô, Hội An, Quảng Nam', 7, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0014', 'Hộ kinh doanh Mẫu Gạo Năm Hòa', null, 'household', '0900000014', 'Duy Vinh, Quảng Nam', 15, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.supplier_bank_accounts (org_id, supplier_id, bank_name, account_no, account_name, status, requested_by, created_by)
select '00dc6aeb-5e34-4e01-9b80-032a72b16d71', s.id, 'Agribank', '0000000014', 'HO KINH DOANH MAU GAO NAM HOA', 'pending', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'
from public.suppliers s where s.org_id='00dc6aeb-5e34-4e01-9b80-032a72b16d71' and s.code='SUP0014' and s.external_codes->>'source'='synthetic'
  and not exists (select 1 from public.supplier_bank_accounts b where b.supplier_id = s.id and b.account_no = '0000000014');
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0015', 'Mẫu Mua chợ — Rau thơm (cá nhân)', null, 'individual_no_invoice', '0900000015', 'Chợ Hội An, Quảng Nam', 0, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
insert into public.suppliers (org_id, code, name, tax_code, kind, phone, address, payment_terms_days, status, approved_by, approved_at, created_by, external_codes)
values ('00dc6aeb-5e34-4e01-9b80-032a72b16d71', 'SUP0016', 'Mẫu Mua chợ — Cá tươi (cá nhân)', null, 'individual_no_invoice', '0900000016', 'Chợ Hội An, Quảng Nam', 0, 'active', '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', now(), '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be', '{"source":"synthetic"}'::jsonb)
on conflict do nothing;
commit;
