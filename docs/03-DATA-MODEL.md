# 03 — Mô hình dữ liệu

Tài liệu gồm 3 phần: (A) danh mục bảng theo nhóm, (B) SQL lõi bắt buộc viết đúng như mô tả, (C) thứ tự migration.

Quy ước chung cho mọi bảng (không lặp lại ở từng bảng):
`id uuid primary key default gen_random_uuid()`, `created_at timestamptz default now()`, `created_by uuid references auth.users`, `updated_at timestamptz` (trigger `set_updated_at`). Bảng chứng từ thêm `doc_no text`, `status text`, `posted_at timestamptz`, `posted_by uuid`, `export_status text default 'not_exported'`.

Kiểu số: tiền `numeric(18,2)`, đơn giá `numeric(18,4)`, số lượng `numeric(18,4)`, tỷ lệ `numeric(9,4)`.

---

## A. Danh mục bảng

### A1. Tổ chức & truy cập

| Bảng | Cột chính | Ghi chú |
|---|---|---|
| `organizations` | `name` | Chuỗi |
| `legal_entities` | `org_id`, `code`, `name`, `tax_code`, `accounting_regime` (`TT99`/`TT133`), `costing_method` (`moving_avg` mặc định, `fifo`), `external_codes jsonb` | Mỗi KS một pháp nhân |
| `properties` | `org_id`, `legal_entity_id`, `code`, `name`, `address`, `sod_profile` (`with_cc`/`without_cc`), `rooms_count` | Khách sạn |
| `outlet_types` | `org_id`, `code`, `name` | Người dùng tự định nghĩa (bếp Á-la-carte, buffet, bar, buồng phòng, kỹ thuật, spa…) |
| `cost_centers` | `org_id`, `code`, `name`, `usali_department` | Rooms, F&B Food, F&B Beverage, Other Operated, A&G, Maintenance, S&M, Utilities |
| `outlets` | `property_id`, `outlet_type_id`, `cost_center_id`, `code`, `name` | |
| `warehouses` | `property_id`, `outlet_id?`, `room_id?`, `code`, `name`, `kind` | `kind`: `main`, `outlet`, `floor`, `trolley`, `minibar_main`, `minibar_room`, `transit`, `quarantine`, `disposal` |
| `room_types` | `property_id`, `code`, `name`, `max_guests` | |
| `rooms` | `property_id`, `room_type_id`, `room_no`, `floor` | Mỗi phòng có 1 kho `minibar_room` |
| `profiles` | `id = auth.users.id`, `employee_code`, `full_name`, `phone`, `pin_hash`, `active` | |
| `permissions` | `code` (PK), `module`, `name_vi`, `description_vi`, `risk_level`, `sort_order` | Danh mục quyền — seed bởi migration, người dùng chỉ đọc |
| `roles` | `org_id`, `code`, `name_vi`, `description`, `is_system`, `active`, `copied_from_id` | **Người dùng tự tạo/sửa**; vai trò mẫu seed `is_system = true` |
| `role_permissions` | `role_id`, `permission_code` | PK 2 cột — ma trận tích chọn |
| `user_property_roles` | `user_id`, `role_id`, `property_id?`, `outlet_ids uuid[]?`, `warehouse_ids uuid[]?`, `valid_from`, `valid_to`, `granted_by` | `property_id null` = toàn chuỗi; mảng phạm vi null = toàn KS |
| `user_permission_overrides` | `user_id`, `property_id?`, `permission_code`, `effect` (`allow`/`deny`), `valid_from`, `valid_to`, `reason`, `granted_by` | Quyền riêng từng người; `deny` thắng |
| `sod_exceptions` | `property_id`, `user_id`, `rule_code`, `reason`, `valid_to`, `approved_by` | Ngoại lệ SoD có thời hạn |
| `doc_sequences` | `legal_entity_id`, `doc_type`, `year`, `last_no` | PK 3 cột đầu |
| `settings` | `org_id`, `property_id?`, `key`, `value jsonb`, `updated_by` | Tham số [cấu hình] trong `05-BUSINESS-RULES.md`; giá trị theo KS ghi đè giá trị chuỗi |
| `approval_delegations` | `from_user`, `to_user`, `property_id`, `valid_from`, `valid_to`, `reason` | Ủy quyền duyệt khi vắng |
| `notification_targets` | (xem A10) | |

### A2. Danh mục vật tư & nhà cung cấp

| Bảng | Cột chính | Ghi chú |
|---|---|---|
| `uoms` | `code` (PK, chữ thường không dấu: `kg`, `g`, `l`, `ml`, `cai`, `chai`, `lon`, `goi`, `hop`, `xap`, `phan`…), `name_vi` | Chuẩn hóa — không cho tạo biến thể hoa/thường |
| `item_groups` | `org_id`, `parent_id`, `code_prefix`, `name`, `kind` | `kind`: `food`, `beverage`, `amenity`, `complimentary`, `collateral`, `linen`, `loan`, `chemical`, `tool`, `minibar`, `engineering`, `ccdc`, `other` |
| `items` | `org_id`, `code` (unique theo org), `name`, `name_norm` (NFC, lower, bỏ khoảng trắng thừa), `name_en`, `group_id`, `stock_uom`, `recipe_uom`, `stock_to_recipe` (hệ số), `is_key_item`, `abc_class`, `track_lot`, `shelf_life_days`, `storage_condition`, `vat_rate`, `allowed_channels text[]` (`contract`,`market`), `tare_g`, `density_g_ml`, `is_temp`, `temp_created_at`, `status` (`active`,`inactive`,`merged`), `merged_into_id`, `legacy_code`, `external_codes jsonb` | `unique(org_id, name_norm)` — chặn trùng tên |
| `item_purchase_units` | `item_id`, `uom`, `factor_to_stock`, `supplier_id?`, `is_default` | Nhiều quy cách mua |
| `suppliers` | `org_id`, `code`, `name`, `tax_code`, `kind` (`company`,`household`,`individual_no_invoice`), `phone`, `address`, `payment_terms_days`, `food_safety_cert_until`, `status` (`pending`,`active`,`suspended`,`banned`), `approved_by` | |
| `supplier_bank_accounts` | `supplier_id`, `bank_name`, `account_no`, `account_name`, `status` (`pending`,`active`,`revoked`), `requested_by`, `approved_by`, `approved_at` | Đổi STK cần người duyệt ≠ người yêu cầu |
| `price_agreements` | `org_id`, `supplier_id`, `valid_from`, `valid_to`, `status` | Hợp đồng khung |
| `price_agreement_lines` | `agreement_id`, `item_id`, `uom`, `unit_price`, `warn_pct`, `lock_pct` | |
| `ceiling_prices` | `org_id`, `property_id?`, `item_id`, `uom`, `price`, `valid_from`, `valid_to`, `set_by` | Hàng tươi mua chợ |
| `expense_categories` | `org_id`, `code`, `name`, `usali_line`, `parent_id` | Khoản mục chi phí, mở rộng được |

### A3. Thu mua

| Bảng | Cột chính |
|---|---|
| `purchase_requests` | `property_id`, `outlet_id`, `kind` (`stock`,`service`), `need_date`, `status` (`draft`,`submitted`,`approved`,`rejected`,`converted`,`cancelled`), `note` |
| `purchase_request_lines` | `pr_id`, `item_id?`, `description`, `qty`, `uom`, `expense_category_id`, `cost_center_id`, `reason` |
| `purchase_orders` | `legal_entity_id`, `property_id`, `supplier_id`, `channel` (`contract`,`quote`,`market`), `kind` (`stock`,`service`), `order_date`, `expected_date`, `advance_id?`, `total_amount`, `status` (`draft`,`submitted`,`approved`,`rejected`,`sent`,`partially_received`,`received`,`closed`,`cancelled`) |
| `purchase_order_lines` | `po_id`, `pr_line_id?`, `item_id?`, `description`, `qty`, `uom`, `qty_stock` (đã quy đổi), `unit_price`, `price_source` (`agreement`,`quote`,`ceiling`,`manual`), `ceiling_price`, `over_ceiling bool`, `received_qty_stock`, `expense_category_id`, `cost_center_id` |
| `approval_rules` | `org_id`, `property_id?`, `doc_type`, `min_amount`, `max_amount`, `item_group_id?`, `condition jsonb`, `step`, `approver_role_id` (vai trò động) **hoặc** `approver_user_id` (người cụ thể), `required_perm` (mặc định `po.approve`) |
| `approvals` | `doc_type`, `doc_id`, `step`, `approver_role_id`, `approver_id`, `decision` (`pending`,`approved`,`rejected`), `comment`, `decided_at`, `delegated_from` |

### A4. Nhận hàng & chất lượng

| Bảng | Cột chính |
|---|---|
| `goods_receipts` | `legal_entity_id`, `property_id`, `po_id?`, `supplier_id`, `warehouse_id`, `direct_issue_warehouse_id?` (nhận thẳng vào bếp), `receiver_id`, `received_at` (máy chủ), `device_time`, `captured_offline`, `client_uuid unique`, `status` (`draft`,`needs_recount`,`posted`,`reversed`), `total_amount` |
| `goods_receipt_lines` | `gr_id`, `po_line_id?`, `item_id`, `gross_qty`, `tare_qty`, `net_qty` (generated = gross − tare), `uom`, `net_qty_stock`, `unit_cost` (lấy từ PO lúc post, không nhập tay), `qc_status` (`pass`,`fail`,`conditional`), `qc_checklist jsonb`, `temperature_c`, `lot_no`, `expiry_date`, `weigh_count` (1 hoặc 2), `over_po_qty_stock`, `override_by`, `override_reason` |
| `supplier_returns` / `_lines` | `gr_id`, `item_id`, `qty_stock`, `reason`, `photo_ids`, `supplier_signature_path` |
| `qc_templates` | `org_id`, `item_group_id`, `checklist jsonb` |
| `attachments` | `bucket`, `path`, `sha256`, `doc_type`, `doc_id`, `line_id?`, `taken_at` (máy chủ), `device_time`, `uploaded_by`, `device_info jsonb` |

### A5. Kho

| Bảng | Cột chính |
|---|---|
| `lots` | `property_id`, `item_id`, `lot_no`, `expiry_date`, `received_at` |
| `stock_moves` | xem SQL B3 — **sổ cái** |
| `stock_balances` | `warehouse_id`, `item_id`, `lot_id?`, `qty` — PK 3 cột; chỉ RPC cập nhật |
| `item_costs` | `legal_entity_id`, `item_id`, `avg_cost`, `qty_on_hand` — PK 2 cột; chỉ RPC cập nhật |
| `requisitions` / `_lines` | `property_id`, `from_warehouse_id`, `to_warehouse_id`, `status` (`draft`,`submitted`,`approved`,`issued`,`received`,`closed`), `issued_qty_stock`, `received_qty_stock`, `discrepancy_note` |
| `transfers` / `_lines` | `from_warehouse_id`, `to_warehouse_id`, `is_inter_entity`, `status` (`draft`,`in_transit`,`received`,`cancelled`) |
| `purpose_issues` / `_lines` | `warehouse_id`, `purpose_code` (`staff_meal`,`vip_comp`,`marketing`,`meeting`,`training`,`repair`,`other`), `cost_center_id`, `expense_category_id`, `work_order_id?` |
| `waste_reports` / `_lines` | `warehouse_id`, `reason_code` (`expired`,`spoiled_storage`,`broken`,`guest_return`,`other`), `photo_ids`, `proposed_by`, `approved_by` |
| `accounting_periods` | `legal_entity_id`, `year`, `month`, `status` (`open`,`closing`,`closed`), `closed_by`, `closed_at` |
| `day_locks` | `property_id`, `warehouse_id`, `business_date`, `shift`, `locked_by`, `locked_at` |
| `stock_counts` | `property_id`, `warehouse_id`, `kind` (`shift_key`,`monthly_full`,`cycle`,`trolley`,`minibar_audit`), `business_date`, `shift`, `status` (`open`,`counting`,`recount`,`submitted`,`locked`), `pos_import_id?`, `counter_ids uuid[]` |
| `stock_count_lines` | `count_id`, `item_id`, `count_detail jsonb` (đa quy cách), `bottle_weight_g`, `counted_qty_1`, `counted_qty_2`, `final_qty`, `book_qty` (**ẩn với người đếm**), `theoretical_qty` (**ẩn**), `variance_qty`, `variance_pct`, `flag` (`ok`,`recount`,`red`), `reason_code`, `explanation`, `photo_ids` |
| `count_adjustments` | `count_id`, `status`, `approved_by` → sinh `stock_moves` loại `adjust_count` |

### A6. Dữ liệu ngoài (PMS, POS)

| Bảng | Cột chính |
|---|---|
| `import_mappings` | `org_id`, `source` (`pos`,`pms`,`supplier_xml`,`master_excel`), `name`, `column_map jsonb`, `sample_header text[]` |
| `pms_daily_stats` | `property_id`, `business_date` (unique cặp), `rooms_available`, `rooms_sold`, `guests`, `breakfast_pax`, `extra_beds`, `checkouts`, `source` (`form`,`file`), `entered_by` |
| `pos_imports` | `property_id`, `outlet_id`, `business_date`, `shift`, `file_path`, `mapping_id`, `status`, `row_count` |
| `pos_sales_lines` | `import_id`, `pos_item_code`, `pos_item_name`, `qty`, `amount`, `is_void`, `voided_after_print`, `is_comp`, `comp_approved_by_name`, `cashier_name`, `sold_at` |

### A7. Công thức (P2 — tạo bảng sớm để không phải sửa cấu trúc)

| Bảng | Cột chính |
|---|---|
| `recipes` | `org_id`, `code`, `name`, `kind` (`dish`,`sub_recipe`,`buffet_batch`,`set_menu`,`room_setup`), `yield_qty`, `yield_uom`, `portions_per_batch`, `diet_flags text[]` |
| `recipe_versions` | `recipe_id`, `valid_from`, `status` (`draft`,`active`,`retired`), `approved_by` |
| `recipe_lines` | `version_id`, `item_id?`, `sub_recipe_id?`, `qty`, `uom`, `loss_pct` — CHECK đúng 1 trong 2 |
| `pos_item_map` | `outlet_id`, `pos_item_code`, `recipe_id`, `multiplier` |

### A8. Buồng phòng & minibar (MVP phần lõi)

| Bảng | Cột chính |
|---|---|
| `room_setup_standards` | `room_type_id`, `clean_type` (`checkout`,`stayover`,`vip`,`child`), `item_id`, `qty`, `per_guest bool` |
| `trolley_shifts` | `property_id`, `trolley_warehouse_id`, `attendant_id`, `business_date`, `shift`, `opening_count_id`, `closing_count_id`, `rooms_done jsonb`, `status` |
| `minibar_price_list` | `property_id`, `item_id`, `price`, `valid_from`, `valid_to` |
| `minibar_checks` | `property_id`, `room_id`, `trigger` (`checkout`,`daily`,`audit`), `checked_by`, `checked_at`, `status` (`pending_charge`,`charged`,`waived`,`late_charge`,`written_off`), `total_amount`, `folio_no`, `charged_by`, `charged_at`, `waive_reason`, `waive_approved_by` |
| `minibar_check_lines` | `check_id`, `item_id`, `missing_qty`, `unit_price`, `amount`, `near_expiry bool` |

### A9. Tài chính & chi phí vận hành

| Bảng | Cột chính |
|---|---|
| `supplier_invoices` / `_lines` | `legal_entity_id`, `supplier_id`, `invoice_symbol`, `invoice_no`, `invoice_date`, `lookup_code`, `xml_path`, `amount_before_tax`, `vat_amount`, `total`, `status` (`draft`,`matched`,`on_hold`,`approved`,`partially_paid`,`paid`,`cancelled`), dòng: `po_line_id`, `gr_line_id`, `qty`, `unit_price`, `amount`, `vat_rate`, `match_result jsonb` |
| `no_invoice_listings` / `_lines` | Bảng kê mua hàng không hóa đơn: `seller_name`, `seller_address`, `seller_id_no`, `item_desc`, `qty`, `unit_price`, `amount`, `purchase_date` |
| `ap_ledger` | Sổ chi tiết công nợ NCC — **chỉ INSERT**: `legal_entity_id`, `supplier_id`, `doc_type`, `doc_id`, `amount` (+ phải trả / − đã trả, trả hàng), `due_date`, `entry_date` |
| `advances` | `legal_entity_id`, `property_id`, `employee_id`, `amount`, `purpose`, `due_settle_at`, `status` (`requested`,`approved`,`disbursed`,`settling`,`settled`,`overdue`) |
| `advance_settlements` / `_lines` | `advance_id`, `gr_id?`, `amount`, `receipt_photo_id`, `refund_amount`, `extra_pay_amount` |
| `payment_requests` / `_lines` | `legal_entity_id`, `supplier_id`, `total`, `due_date`, `status` (`draft`,`submitted`,`approved`,`paid`,`cancelled`), `paid_at`, `bank_ref`; dòng: `invoice_id`, `amount` |
| `service_contracts` | `legal_entity_id`, `property_id`, `supplier_id`, `expense_category_id`, `cost_center_id`, `title`, `start_date`, `end_date`, `billing_cycle` (`monthly`,`quarterly`,`yearly`,`per_visit`), `amount_per_cycle`, `renew_notice_days`, `status` |
| `service_schedules` | `contract_id`, `period_start`, `period_end`, `due_date`, `status` (`scheduled`,`performed`,`accepted`,`invoiced`,`paid`,`skipped`) |
| `service_acceptances` | `schedule_id?`, `po_id?`, `accepted_by`, `accepted_at`, `rating 1..5`, `note`, `photo_ids` |
| `export_batches` | `legal_entity_id`, `kind`, `period_from`, `period_to`, `file_path`, `row_count`, `created_by` |

### A10. Cảnh báo, nhật ký

| Bảng | Cột chính |
|---|---|
| `alert_rules` | `org_id`, `property_id?`, `code`, `threshold jsonb`, `channels text[]`, `urgent bool`, `active` |
| `alerts` | `property_id`, `code`, `severity` (`info`,`warn`,`red`), `title`, `payload jsonb`, `doc_type`, `doc_id`, `created_at`, `sent_at`, `sent_channels`, `ack_by`, `ack_at` |
| `notification_targets` | `user_id`, `channel` (`email`,`webpush`,`zalo`), `address`, `active` |
| `report_snapshots` | `property_id`, `report_code`, `business_date`, `data jsonb` |
| `audit_log` | `table_name`, `row_id`, `action`, `old_data jsonb`, `new_data jsonb`, `actor`, `at`, `client_info jsonb` — **chỉ INSERT** |

---

## B. SQL lõi (viết đúng tinh thần, agent được tối ưu cú pháp)

### B1. Extension & hàm tiện ích

```sql
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
create extension if not exists unaccent;

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end $$;

-- Chuẩn hóa tên để chống trùng: NFC + lower + gộp khoảng trắng
create or replace function public.norm_text(t text) returns text
language sql immutable as $$
  select btrim(regexp_replace(lower(normalize(coalesce(t,''), NFC)), '\s+', ' ', 'g'))
$$;
```

### B2. Đánh số chứng từ

T-010 triển khai trong `supabase/migrations/20261109030000_master_data.sql`:

- `doc_sequences` dùng khóa `(legal_entity_id, doc_type, year)`, bộ đếm `bigint` và RLS không có policy cho client. `next_doc_no` chỉ được gọi từ hàm nghiệp vụ có quyền tương ứng, không cấp quyền gọi trực tiếp cho client.
- Một lệnh `INSERT ... ON CONFLICT ... UPDATE ... RETURNING` tăng bộ đếm nguyên tử trong transaction của chứng từ. Năm tính theo ngày nghiệp vụ được truyền; mặc định là ngày `Asia/Ho_Chi_Minh`.
- Định dạng `PO-KS01-2611-0007`: số thứ tự có **tối thiểu** bốn chữ số, không cắt cụt khi vượt 9999; tháng chỉ thuộc phần hiển thị, không đặt lại bộ đếm.
- `norm_text` đã được tạo từ migration tiện ích; `items.name_norm` là cột generated và duy nhất trong từng tổ chức.
- Các bảng danh mục T-010 chỉ mở quyền đọc theo RLS. Luồng ghi danh mục và NCC được bổ sung ở T-012/T-013; không cho ghi trực tiếp trong lúc các kiểm soát nghiệp vụ chưa hoàn chỉnh.

### B3. Sổ cái kho bất biến

T-011 đang chuẩn bị schema nền trong
`supabase/migrations/20261109110000_inventory_foundation.sql`: các bảng mới
chưa cấp quyền cho client và migration chưa áp dụng production. Việc ghi sổ,
phân bổ lớp FIFO, đảo và thực thi khóa vẫn chưa được triển khai; đoạn SQL dưới
đây là đặc tả, không phải khả năng đang chạy.

```sql
create table public.stock_moves (
  id bigint generated always as identity primary key,
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  warehouse_id uuid not null references public.warehouses(id),
  item_id uuid not null references public.items(id),
  lot_id uuid references public.lots(id),
  move_type text not null check (move_type in (
    'opening','receipt','return_out','issue_out','issue_in','transfer_out','transfer_in',
    'purpose_issue','waste','adjust_count','production_out','production_in',
    'minibar_sale','merge_out','merge_in','reversal')),
  qty numeric(18,4) not null check (qty <> 0),          -- đơn vị kho, có dấu: + vào, − ra
  unit_cost numeric(18,4) not null default 0,
  amount numeric(18,2) not null,                          -- = qty * unit_cost, có dấu
  business_date date not null,
  posted_at timestamptz not null default now(),
  posted_by uuid not null,
  source_doc_type text not null,
  source_doc_id uuid not null,
  source_line_id uuid,
  reverses_move_id bigint references public.stock_moves(id),
  cost_center_id uuid references public.cost_centers(id),
  expense_category_id uuid references public.expense_categories(id),
  purpose_code text
);
create index on public.stock_moves (warehouse_id, item_id, business_date);
create index on public.stock_moves (source_doc_type, source_doc_id);
create index on public.stock_moves (legal_entity_id, business_date);

create or replace function public.forbid_mutation() returns trigger
language plpgsql as $$
begin
  raise exception 'ERR_IMMUTABLE_LEDGER: % không cho phép %', tg_table_name, tg_op;
end $$;
create trigger trg_stock_moves_immutable before update or delete on public.stock_moves
for each row execute function public.forbid_mutation();
-- Áp cùng trigger cho ap_ledger, audit_log.

alter table public.stock_moves enable row level security;
-- Chỉ policy SELECT (theo property người dùng được xem). Không policy INSERT/UPDATE/DELETE.
```

### B4. Hàm ghi sổ dùng chung (mọi RPC post gọi hàm này)

```sql
-- Ghi 1 dòng sổ cái + cập nhật số dư + giá vốn bình quân. Gọi BÊN TRONG RPC post (cùng transaction).
create or replace function public._post_move(
  p_entity uuid, p_property uuid, p_wh uuid, p_item uuid, p_lot uuid,
  p_type text, p_qty numeric, p_unit_cost numeric,          -- p_unit_cost null = lấy giá bình quân hiện tại
  p_date date, p_doc_type text, p_doc_id uuid, p_line_id uuid,
  p_cost_center uuid default null, p_expense_cat uuid default null, p_purpose text default null,
  p_reverses bigint default null
) returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_cost numeric(18,4); v_bal numeric(18,4); v_ic item_costs%rowtype; v_id bigint;
begin
  -- 1. Kỳ kế toán phải mở, ngày không bị khóa
  if exists (select 1 from accounting_periods
             where legal_entity_id = p_entity and year = extract(year from p_date)
               and month = extract(month from p_date) and status = 'closed') then
    raise exception 'ERR_PERIOD_CLOSED';
  end if;
  if exists (select 1 from day_locks where warehouse_id = p_wh and business_date >= p_date) then
    raise exception 'ERR_DAY_LOCKED';
  end if;

  -- 2. Khóa dòng số dư để tránh tranh chấp
  select * into v_ic from item_costs where legal_entity_id = p_entity and item_id = p_item for update;
  if not found then
    insert into item_costs(legal_entity_id, item_id, avg_cost, qty_on_hand) values (p_entity, p_item, 0, 0)
    returning * into v_ic;
  end if;

  -- 3. Giá vốn: nhập dùng giá truyền vào; xuất dùng bình quân hiện tại
  v_cost := coalesce(p_unit_cost, v_ic.avg_cost);

  -- 4. Chặn tồn âm tại kho
  select coalesce(qty,0) into v_bal from stock_balances
   where warehouse_id = p_wh and item_id = p_item and lot_id is not distinct from p_lot for update;
  if coalesce(v_bal,0) + p_qty < 0 then
    raise exception 'ERR_NEGATIVE_STOCK: kho %, mã %, tồn %, xuất %', p_wh, p_item, coalesce(v_bal,0), -p_qty;
  end if;

  insert into stock_moves(legal_entity_id, property_id, warehouse_id, item_id, lot_id, move_type, qty,
    unit_cost, amount, business_date, posted_by, source_doc_type, source_doc_id, source_line_id,
    reverses_move_id, cost_center_id, expense_category_id, purpose_code)
  values (p_entity, p_property, p_wh, p_item, p_lot, p_type, p_qty, v_cost, round(p_qty * v_cost, 2),
    p_date, auth.uid(), p_doc_type, p_doc_id, p_line_id, p_reverses, p_cost_center, p_expense_cat, p_purpose)
  returning id into v_id;

  insert into stock_balances(warehouse_id, item_id, lot_id, qty) values (p_wh, p_item, p_lot, p_qty)
  on conflict (warehouse_id, item_id, lot_id) do update set qty = stock_balances.qty + excluded.qty;

  -- 5. Bình quân gia quyền tức thời — chỉ đổi giá khi NHẬP có giá mới (receipt, opening, production_in)
  if p_qty > 0 and p_type in ('receipt','opening','production_in','merge_in') then
    update item_costs set
      avg_cost = case when qty_on_hand + p_qty = 0 then v_cost
                      else round((qty_on_hand * avg_cost + p_qty * v_cost) / (qty_on_hand + p_qty), 4) end,
      qty_on_hand = qty_on_hand + p_qty
    where legal_entity_id = p_entity and item_id = p_item;
  elsif p_type not in ('transfer_out','transfer_in','issue_out','issue_in') then
    -- chuyển nội bộ trong cùng pháp nhân không làm đổi tổng tồn pháp nhân
    update item_costs set qty_on_hand = qty_on_hand + p_qty
    where legal_entity_id = p_entity and item_id = p_item;
  end if;

  return v_id;
end $$;
revoke all on function public._post_move from public, anon, authenticated;
```

Ghi chú cho agent:
- `stock_balances` khai báo `unique nulls not distinct (warehouse_id, item_id, lot_id)` khi tạo bảng (Postgres 15+) để `on conflict (warehouse_id, item_id, lot_id)` hoạt động cả khi `lot_id` null — đã chạy thử trên Postgres 16.
- Trả hàng NCC (`return_out`) dùng **giá của dòng nhận gốc**, không dùng bình quân, và giảm `qty_on_hand`.
- Đảo bút toán (`reversal`): đọc dòng gốc, ghi `qty = -qty_gốc`, `unit_cost = unit_cost_gốc`, `reverses_move_id = id_gốc`; không đảo được 2 lần (unique trên `reverses_move_id`).

### B5. Chặn sửa chứng từ đã post

```sql
create or replace function public.forbid_edit_when_posted() returns trigger
language plpgsql as $$
begin
  if old.status in ('posted','locked','reversed','closed') then
    raise exception 'ERR_DOC_POSTED: chứng từ % đã ghi sổ', old.id;
  end if;
  return new;
end $$;
-- Gắn BEFORE UPDATE OR DELETE cho bảng đầu chứng từ; bảng dòng kiểm tra status của đầu chứng từ.
```

### B6. Nhật ký kiểm toán

```sql
create or replace function public.audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log(table_name, row_id, action, old_data, new_data, actor, client_info)
  values (tg_table_name, coalesce(new.id, old.id), tg_op,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end,
          auth.uid(),
          coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb)
            - 'authorization' - 'cookie' - 'apikey');
  return coalesce(new, old);
end $$;
-- Gắn AFTER INSERT/UPDATE/DELETE cho mọi bảng danh mục và chứng từ.
```

---

## C. Thứ tự migration

| # | File | Nội dung |
|---|---|---|
| 01 | `..._extensions_utils.sql` | B1, `forbid_mutation`, `set_updated_at`, `audit_log` + B6 |
| 02 | `..._org_access.sql` | A1 + `permissions`/`roles`/`role_permissions`/`user_permission_overrides` + `has_perm`, `require_perm`, `my_property_ids`, `my_permissions` (xem `04-SECURITY-RLS.md`) + seed danh mục quyền và vai trò mẫu |
| 03 | `..._master.sql` | A2 + `doc_sequences` + B2 |
| 04 | `..._inventory_core.sql` | `lots`, `stock_moves` (B3), `stock_balances`, `item_costs`, `accounting_periods`, `day_locks`, B4, B5 |
| 05 | `..._attachments_storage.sql` | `attachments`, bucket `evidence` + storage policy |
| 06 | `..._procurement.sql` | A3 + RPC thu mua |
| 07 | `..._receiving.sql` | A4 + view mù + RPC nhận hàng |
| 08 | `..._inventory_docs.sql` | phiếu lĩnh, điều chuyển, xuất mục đích, hủy + RPC |
| 09 | `..._counts_close.sql` | kiểm kê, điều chỉnh, khóa ngày/kỳ |
| 10 | `..._external_data.sql` | A6 |
| 11 | `..._housekeeping_minibar.sql` | A8 |
| 12 | `..._finance.sql` | A9 (+ `ap_ledger` bất biến) |
| 13 | `..._recipes.sql` | A7 (bảng tạo sẵn, RPC làm ở P2) |
| 14 | `..._alerts_reports.sql` | A10, `pg_cron` jobs |

Mỗi migration kèm file pgTAP cùng tên trong `supabase/tests/`.
