-- 20261109536000_audit_triggers_business_tables.sql
--
-- Q213: bo sung audit trigger cho cac bang nghiep vu con thieu, lam tien de
-- cho viec noi long rang buoc (truy vet bang audit_log thay cho chan truoc).
--
-- Cach lam: MỘT vong DO duyet moi bang thuong (relkind = 'r') trong schema
-- public CHUA co trigger ten trg_<bang>_audit (kiem tra qua pg_trigger +
-- pg_class) va gan trigger AFTER INSERT OR UPDATE OR DELETE dung ham
-- public.audit_trigger() co san (20261108140958_extensions_utils.sql,
-- security definer, actor = auth.uid()).
--
-- Vong lap chay lai duoc an toan: neu trigger da ton tai (duoc gan o
-- migration truoc, hoac bang chi co trigger INSERT-only nhu attachments)
-- thi bo qua nho dieu kien NOT EXISTS, khong tao trung.
--
-- BO QUA 8 bang (co chu dich, khong gan trigger):
--   * stock_moves, stock_balances, item_costs, ap_ledger:
--     so cai tu la vet (INSERT-only, khong sua/xoa); ghi audit cho tung dong
--     so cai se tran audit_log (moi buoc post sinh hang loat dong).
--   * audit_log: ban than bang log, da co trigger trg_audit_log_immutable
--     chan UPDATE/DELETE; gan them trigger audit len chinh no la sai logic.
--   * report_snapshots, notification_deliveries, push_subscriptions:
--     chi chua du lieu cache / hang doi thong bao, khong phai chung tu
--     nghiep vu can truy vet.
--
-- Sau migration nay, moi bang public (tru 8 bang tren) deu co trigger
-- trg_<bang>_audit. Danh sach 51 bang duoc gan them o lan chay dau tien
-- (doi chieu tu CREATE TABLE trong cac migration): advance_settlements,
-- advance_settlement_lines, approval_delegations, approvals, banquets,
-- banquet_dishes, banquet_halls, buffet_sessions, buffet_session_dishes,
-- count_adjustments, dish_sales, doc_sequences, fifo_allocations,
-- fifo_layers, item_code_sequences, minibar_checks, minibar_check_lines,
-- minibar_price_list, no_invoice_listings, no_invoice_listing_lines,
-- notification_sender_config, payment_requests, payment_request_lines,
-- permissions, profiles, purchase_requests, purchase_request_lines,
-- purchase_orders, purchase_order_lines, purpose_issues,
-- purpose_issue_lines, recipes, recipe_versions, recipe_lines,
-- requisitions, requisition_lines, room_setup_standards,
-- service_acceptances, service_contracts, service_schedules,
-- stock_counts, stock_count_lines, supplier_invoices,
-- supplier_invoice_lines, transfers, transfer_lines, trolley_shifts,
-- trolley_par_levels, uom_aliases, waste_reports, waste_report_lines.
--
-- Luu y ve khoi luong log: doc_sequences / item_code_sequences duoc cap
-- nhat moi lan sinh so chung tu (next_doc_no), fifo_allocations /
-- fifo_layers thay doi theo tung buoc post kho; cac bang nay nay cung sinh
-- dong audit_log. Chap nhan o buoc nay theo pham vi Q213; neu audit_log
-- phi nhanh thi xet them co che don dep / archive sau.
do $$
declare
  r record;
begin
  for r in
    select c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname not in (
        -- So cai: tu la vet, tranh tran log.
        'stock_moves', 'stock_balances', 'item_costs', 'ap_ledger',
        -- Ban than bang log (da co trg_audit_log_immutable).
        'audit_log',
        -- Cache / hang doi thong bao, khong phai chung tu nghiep vu.
        'report_snapshots', 'notification_deliveries', 'push_subscriptions'
      )
      and not exists (
        select 1
        from pg_trigger t
        where t.tgrelid = c.oid
          and t.tgname = 'trg_' || c.relname || '_audit'
          and not t.tgisinternal
      )
    order by c.relname
  loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I '
      'for each row execute function public.audit_trigger()',
      'trg_' || r.table_name || '_audit',
      r.table_name
    );
  end loop;
end;
$$;
