-- Q253: 5 bang nhan hang/tra hang co 2 trigger audit giong het nhau
-- (`<bang>_audit` tu 20261109230000_receiving.sql va `trg_<bang>_audit`
-- tu migration audit chung) -> moi thay doi ghi 2 dong audit_log.
-- Giu `trg_<bang>_audit` (quy uoc cua 30 bang con lai), bo ban khong tien to.
-- Cac dong audit trung da ghi KHONG bi xoa (audit_log chi INSERT).
drop trigger if exists goods_receipts_audit on public.goods_receipts;
drop trigger if exists goods_receipt_lines_audit on public.goods_receipt_lines;
drop trigger if exists qc_templates_audit on public.qc_templates;
drop trigger if exists supplier_returns_audit on public.supplier_returns;
drop trigger if exists supplier_return_lines_audit on public.supplier_return_lines;
