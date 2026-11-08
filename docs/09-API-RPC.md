# 09 — RPC (hàm Postgres) & mã lỗi

Mọi RPC ghi dữ liệu: `security definer`, `set search_path = public`, kiểm tra `auth.uid()` + `require_perm(property, 'ma.quyen', warehouse)` + SoD ở đầu hàm (không kiểm tra tên vai trò), trả về `jsonb`. `grant execute ... to authenticated`. Gọi từ Next.js: `supabase.rpc('<ten>', {...})`.

Tham số offline luôn có `p_client_uuid uuid` → nếu đã xử lý, trả lại kết quả cũ (idempotent).

## 1. Danh mục

| RPC | Tham số chính | Kết quả / ghi chú |
|---|---|---|
| `item_create_temp` | `p_name, p_group_id, p_stock_uom` | Tạo mã tạm `TMP-xxxx`, `is_temp = true` |
| `item_merge` | `p_from_id, p_into_id` | Chuyển mọi tham chiếu nháp sang mã đích; `status = 'merged'`. Không gộp nếu mã nguồn đã có `stock_moves` khác pháp nhân… (xem rule) |
| `supplier_submit` / `supplier_approve` | `p_supplier_id` | SoD người duyệt ≠ người tạo |
| `supplier_bank_request` / `supplier_bank_approve` | `p_supplier_id, p_bank..., p_account_no` | Alert `BANK_ACCOUNT_CHANGE` |
| `import_preview` / `import_commit` | `p_mapping_id, p_rows jsonb` | Preview trả danh sách lỗi; commit trong 1 transaction |

## 2. Thu mua

| RPC | Ghi chú |
|---|---|
| `pr_save_draft(p_pr jsonb)` | Tạo/sửa PR nháp |
| `pr_submit(p_pr_id)` / `pr_decide(p_pr_id, p_decision, p_comment)` | |
| `po_create_from_pr(p_pr_line_ids uuid[], p_supplier_id, p_channel)` | Tự lấy giá theo thứ tự hợp đồng → báo giá → giá trần |
| `po_save_draft(p_po jsonb)` | Không cho sửa `unit_price` nếu `price_source <> 'manual'` |
| `po_submit(p_po_id)` | Sinh các bước `approvals` theo `approval_rules` |
| `approval_decide(p_doc_type, p_doc_id, p_decision, p_comment)` | Kiểm `SOD_PO_CREATOR_APPROVER` |
| `po_send(p_po_id)` | Trạng thái `sent`; sinh PDF ở route `/api/export/po/[id]` |
| `po_close(p_po_id, p_reason)` | Đóng phần còn thiếu |
| `market_order_create(p_lines jsonb, p_advance_amount)` | Tạo PO `market` + `advances` `requested` |

## 3. Nhận hàng

| RPC | Ghi chú |
|---|---|
| `receiving_list_tasks(p_property_id, p_date)` | Trả: `po_id, doc_no, supplier_name, line_count, expected_date`. **Không qty, không giá** |
| `receiving_get_task(p_po_id)` | Trả dòng: `po_line_id, item_id, item_name, spec, qc_template, photo_required`. **Không qty, không giá** |
| `receiving_start(p_po_id, p_warehouse_id, p_direct_issue_wh, p_client_uuid)` | Tạo `goods_receipts` nháp |
| `receiving_record_line(p_gr_id, p_po_line_id, p_item_id, p_gross, p_tare, p_uom, p_qc jsonb, p_lot, p_expiry, p_photo_ids uuid[], p_client_uuid)` | Server so PO: trả `{ok, needs_reweigh: bool}`. Lần 2 vẫn lệch → ghi nhận, trả `{ok, accepted_qty_stock_capped: bool}` (không nói số) |
| `receiving_post(p_gr_id, p_pin)` | Kiểm PIN, SoD `SOD_PO_RECEIVER` / `SOD_MARKET_BUYER_RECEIVER`; gọi `_post_move` `receipt` (+ `issue_*` nếu nhận thẳng bếp); cập nhật `received_qty_stock`, trạng thái PO |
| `supplier_return_post(p_gr_id, p_lines jsonb)` | `return_out` theo giá dòng nhận gốc; `ap_ledger` (−) nếu đã có hóa đơn |
| `receiving_reverse(p_gr_id, p_reason)` | Chỉ gm; đảo mọi move của phiếu |

## 4. Kho

| RPC | Ghi chú |
|---|---|
| `requisition_submit`, `requisition_decide`, `requisition_issue(p_id, p_lines)`, `requisition_confirm_receipt(p_id, p_lines)` | `issue_out` khi kho xuất; `issue_in` khi outlet xác nhận (hàng ở `transit` giữa 2 bước) |
| `transfer_send`, `transfer_receive` | 2 bước qua kho `transit` |
| `purpose_issue_post(p_id)` | Bắt buộc `cost_center_id`, `expense_category_id` |
| `waste_submit`, `waste_decide` | SoD `SOD_WASTE`; > ngưỡng thêm gm |
| `stock_balance_get(p_warehouse_id, p_item_id)` | Chỉ cho vai trò được xem tồn |

## 5. Kiểm kê & khóa sổ

| RPC | Ghi chú |
|---|---|
| `count_open(p_warehouse_id, p_kind, p_business_date, p_shift)` | `shift_key` yêu cầu có `pos_imports`; `monthly_full` đặt cờ đóng băng kho |
| `count_record_line(p_count_id, p_item_id, p_detail jsonb, p_bottle_weight_g, p_client_uuid)` | Ghi `counted_qty_1` hoặc `_2` |
| `count_submit(p_count_id, p_pins text[])` | Tính `book/theoretical/variance`; trả `{recount_line_ids: [...]}` — **không trả số** |
| `count_lock(p_count_id)` | Sau lần 2; lý do bắt buộc cho dòng đỏ |
| `count_adjust_post(p_count_id)` | gm duyệt → `adjust_count` |
| `day_lock(p_warehouse_id, p_date)` / `day_unlock(...)` | Unlock → alert `UNLOCK` |
| `period_close(p_entity_id, p_year, p_month)` / `period_reopen` | Kiểm điều kiện mục 10 của `05-BUSINESS-RULES.md` |

## 6. Buồng phòng & minibar

| RPC | Ghi chú |
|---|---|
| `trolley_shift_open(p_trolley_wh, p_counts jsonb)` | Sinh phiếu lĩnh bù tới par |
| `trolley_shift_close(p_shift_id, p_counts jsonb)` | Tiêu hao = đầu + lĩnh − cuối → `purpose_issue` cost center Rooms |
| `minibar_request_check(p_room_id)` | Lễ tân gọi khi khách check-out; tạo alert cho buồng phòng |
| `minibar_submit_check(p_check_id, p_lines jsonb, p_client_uuid)` | Tính tiền theo bảng giá |
| `minibar_confirm_charge(p_check_id, p_folio_no)` | Post `minibar_sale` từ kho phòng |
| `minibar_request_waive(p_check_id, p_reason)` / `minibar_decide_waive` | gm duyệt |
| `minibar_refill(p_room_id, p_lines)` | `transfer` minibar_main → minibar_room |
| `minibar_reconcile(p_property_id, p_date)` | Dùng trong cron; lệch → `MINIBAR_MISMATCH` |

## 7. Tài chính & dịch vụ

| RPC | Ghi chú |
|---|---|
| `invoice_save_draft`, `invoice_match(p_invoice_id)` | Trả kết quả khớp từng dòng |
| `invoice_approve(p_invoice_id)` | Ghi `ap_ledger` (+) |
| `advance_request`, `advance_decide`, `advance_disburse`, `advance_settle(p_id, p_lines)` | Quyết toán theo số thực nhận |
| `payment_request_create`, `payment_request_decide`, `payment_mark_paid(p_id, p_bank_ref)` | `ap_ledger` (−) khi paid |
| `service_contract_save`, `service_schedule_generate(p_month)`, `service_accept(p_schedule_id, p_rating, p_photos)` | |
| `pms_daily_upsert(p_property_id, p_date, p_stats jsonb)` | Lễ tân nhập hằng ngày |
| `pos_import_commit(p_import_id)` (P2) | |

## 9. Phân quyền (quản trị)

Mọi RPC dưới đây yêu cầu `admin.roles.manage` hoặc `admin.users.manage` (ghi rõ ở cột), ghi `audit_log`, tạo alert `PERMISSION_CRITICAL_CHANGED` nếu đụng quyền mức `critical`.

| RPC | Quyền cần | Ghi chú |
|---|---|---|
| `admin_role_save(p_role jsonb)` | `admin.roles.manage` | Tạo/sửa tên, mô tả; không sửa `sys_admin` |
| `admin_role_copy(p_role_id, p_new_name)` | `admin.roles.manage` | Sao chép cả ma trận quyền |
| `admin_role_set_permissions(p_role_id, p_permission_codes text[], p_reason)` | `admin.roles.manage` | Ghi đè toàn bộ ma trận; trả `{added[], removed[], conflicts[]}` |
| `admin_role_deactivate(p_role_id)` | `admin.roles.manage` | Không xóa vật lý |
| `admin_user_assign_role(p_user_id, p_role_id, p_property_id, p_outlet_ids, p_warehouse_ids, p_valid_from, p_valid_to)` | `admin.users.manage` | `ERR_SELF_GRANT` nếu cấp cho chính mình |
| `admin_user_revoke_role(p_assignment_id, p_reason)` | `admin.users.manage` | Đặt `valid_to = hôm nay`; `ERR_LAST_ADMIN` nếu gỡ admin cuối |
| `admin_permission_override_set(p_user_id, p_property_id, p_permission_code, p_effect, p_valid_to, p_reason)` | `admin.permissions.override` | `allow`/`deny`; lý do bắt buộc |
| `admin_user_effective_permissions(p_user_id, p_property_id)` | `admin.users.manage` | Trả mỗi quyền + nguồn (vai trò nào / override nào) |
| `admin_sod_conflict_check(p_user_id \| p_role_id)` | `admin.users.manage` | Trả danh sách cặp quyền xung đột |
| `my_permissions(p_property_id)` | đăng nhập | UI dùng cho `useCan` |

## 10. Mã lỗi (UI dịch trong `errors.vi.ts`)

| Mã | Nghĩa |
|---|---|
| `ERR_FORBIDDEN:<ma.quyen>` | Không có quyền (kèm mã quyền thiếu để UI báo rõ) |
| `ERR_SELF_GRANT` | Không được tự cấp/sửa quyền cho chính mình |
| `ERR_LAST_ADMIN` | Phải còn ít nhất 2 người quản trị |
| `ERR_SYSTEM_ROLE` | Không sửa/xóa vai trò hệ thống |
| `ERR_SOD_<RULE>` | Vi phạm tách biệt nhiệm vụ (mã quy tắc ở `04-SECURITY-RLS.md`) |
| `ERR_IMMUTABLE_LEDGER` | Cố sửa/xóa sổ cái |
| `ERR_DOC_POSTED` | Chứng từ đã ghi sổ |
| `ERR_INVALID_STATUS` | Sai trạng thái cho thao tác |
| `ERR_NEGATIVE_STOCK` | Không đủ tồn |
| `ERR_PERIOD_CLOSED` / `ERR_DAY_LOCKED` | Kỳ/ngày đã khóa |
| `ERR_COUNT_FREEZE` | Kho đang kiểm kê |
| `ERR_OVER_CEILING_NO_REASON` | Vượt giá trần chưa có lý do |
| `ERR_PHOTO_REQUIRED` | Thiếu ảnh bắt buộc |
| `ERR_PIN_INVALID` | Sai PIN |
| `ERR_ADVANCE_OVERDUE_BLOCK` | Có tạm ứng quá hạn, không được ứng mới |
| `ERR_TEMP_ITEM_EXPIRED` | Mã tạm quá 72h |
| `ERR_POS_IMPORT_REQUIRED` | Chưa tải file POS của ca |
| `ERR_SERVICE_NOT_ACCEPTED` | Kỳ dịch vụ chưa nghiệm thu |
| `ERR_UOM_UNKNOWN` | Đơn vị chưa khai báo quy đổi |
