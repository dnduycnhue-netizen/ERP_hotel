# 09 — RPC (hàm Postgres) & mã lỗi

Mọi RPC ghi dữ liệu: `security definer`, `set search_path = public`, kiểm tra `auth.uid()` + `require_perm(property, 'ma.quyen', warehouse)` + SoD ở đầu hàm (không kiểm tra tên vai trò), trả về `jsonb`. `grant execute ... to authenticated`. Gọi từ Next.js: `supabase.rpc('<ten>', {...})`.

Tham số offline luôn có `p_client_uuid uuid` → nếu đã xử lý, trả lại kết quả cũ (idempotent).

## 1. Danh mục

`next_doc_no(p_entity, p_doc_type, p_date)` là hàm nội bộ cấp số nguyên tử,
không cấp quyền gọi trực tiếp cho client. Ngày mặc định theo `Asia/Ho_Chi_Minh`.
Các RPC danh mục dưới đây thuộc các task sau, chưa được triển khai bởi T-010.

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
| `po_submit(p_po_id)` | Sinh các bước `approvals` theo `approval_rules`; chặn `ERR_PRICE_NOT_SET` khi PO **thường** (contract/quote) có dòng `manual` giá ≤ 0 — **PO chợ (`channel = 'market'`) được miễn** kiểm tra giá (T-022A, tự phê duyệt 10/11) |
| `approval_decide(p_doc_type, p_doc_id, p_decision, p_comment)` | Kiểm `SOD_PO_CREATOR_APPROVER` |
| `pr_list(p_property_id, p_status, p_search, p_limit, p_offset)` / `po_list(...)` | Trả `created_by_name` (join `profiles`, Q18); `total` + `rows` |
| `approval_timeline(p_property_id, p_doc_type, p_doc_id)` | `p_doc_type` 'pr'/'po'/'payment_request' (Q73: 'payment_request' cần `payment.request`/`payment.approve`/`payment.mark_paid`); trả `steps` kèm tên vai trò + tên người quyết |
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
| `supplier_return_list(p_property_id, p_status, p_search, p_limit, p_offset)` | Danh sách phiếu trả: `doc_no, status, supplier_name, gr_doc_no, po_doc_no, line_count, total_qty_stock, total_amount` (giá chỉ khi có `po.view_price`); quyền `receiving.view` |
| `supplier_return_get(p_return_id)` | Chi tiết phiếu trả + dòng (`unit_cost`/`line_amount` chỉ khi có `po.view_price`); quyền `receiving.view` |
| `supplier_return_eligible_lines(p_gr_id)` | Dòng của phiếu nhận đã post còn trả được: `accepted_qty_stock, returned_qty_stock, returnable_qty_stock`; quyền `supplier_return.post` |
| `supplier_return_confirm(p_return_id, p_supplier_signature_path, p_photo_ids)` | `recorded` → `posted`; cần chữ ký người giao HOẶC ≥1 ảnh (`ERR_PHOTO_REQUIRED`); không phát sinh move (hàng QC fail chưa vào kho); quyền `supplier_return.post` |
| `supplier_return_cancel(p_return_id, p_reason)` | `recorded` → `cancelled`; lý do bắt buộc (`ERR_REASON_REQUIRED`); quyền `supplier_return.post` |
| `receiving_reverse(p_gr_id, p_reason)` | Chỉ gm; đảo mọi move của phiếu |

## 4. Kho

| RPC | Ghi chú |
|---|---|
| `requisition_submit`, `requisition_decide`, `requisition_issue(p_id, p_lines)`, `requisition_confirm_receipt(p_id, p_lines)` | `issue_out` khi kho xuất; `issue_in` khi outlet xác nhận (hàng ở `transit` giữa 2 bước) |
| `transfer_send`, `transfer_receive` | 2 bước qua kho `transit` |
| `purpose_issue_post(p_id)` | Bắt buộc `cost_center_id`, `expense_category_id` |
| `waste_submit`, `waste_decide` | SoD `SOD_WASTE`; > ngưỡng thêm gm |
| `requisition_save_draft(p_doc jsonb)` | Tạo/sửa nháp phiếu lĩnh: kho đích phải là kho của outlet (`ERR_INVALID_VALUE`); đổi UOM qua hệ số mua (`ERR_UOM_UNKNOWN`); quyền `requisition.create` |

> `stock_balance_get` đã chốt STOP (Q28/Q147) — không triển khai, không có trong đặc tả nữa.
| `requisition_cancel(p_property_id, p_id, p_reason)` | `draft`/`submitted`/`approved` → `cancelled`; lý do bắt buộc (`ERR_REASON_REQUIRED`); quyền `requisition.create` |
| `requisition_list(p_property_id, p_status, p_search, p_limit, p_offset)` | Danh sách phiếu lĩnh (số lượng, không giá); quyền `requisition.create` |
| `requisition_get(p_id)` | Chi tiết phiếu lĩnh + dòng (không trả `unit_cost`); quyền `requisition.create` |
| `transfer_save_draft(p_doc jsonb)` | Tạo/sửa nháp điều chuyển: kho nguồn ≠ kho đích, cùng property, không chuyển liên pháp nhân (`ERR_INVALID_VALUE`); quyền `transfer.send` |
| `transfer_cancel(p_property_id, p_id, p_reason)` | Chỉ `draft` → `cancelled`; lý do bắt buộc; quyền `transfer.send` |
| `transfer_list(p_property_id, p_status, p_search, p_limit, p_offset)` / `transfer_get(p_id)` | Danh sách/chi tiết điều chuyển (số lượng, không giá); quyền `transfer.send` |
| `purpose_issue_save_draft(p_doc jsonb)` | Tạo/sửa nháp xuất mục đích: `purpose_code` trong 7 giá trị; `cost_center_id`/`expense_category_id` bắt buộc ở lúc post, không bắt buộc ở nháp; quyền `purpose_issue.post` |
| `purpose_issue_cancel(p_property_id, p_id, p_reason)` | Chỉ `draft` → `cancelled`; lý do bắt buộc; quyền `purpose_issue.post` |
| `purpose_issue_reverse(p_id, p_property_id, p_reason)` | `posted` → `reversed`; ghi move `reversal` (`reverses_move_id`); đảo 2 lần → `ERR_INVALID_STATUS`; quyền mới `purpose_issue.reverse` (gm, owner) |
| `purpose_issue_list(p_property_id, p_status, p_search, p_limit, p_offset)` / `purpose_issue_get(p_id)` | Danh sách/chi tiết xuất mục đích; `unit_cost`/`line_amount` chỉ khi có `stock.view_value`; quyền `purpose_issue.post` hoặc `purpose_issue.reverse` |
| `waste_save_draft(p_doc jsonb)` | Tạo/sửa nháp hủy hàng: `photo_ids` phải là attachment đã đăng ký; quyền `waste.propose` |
| `waste_cancel(p_property_id, p_id, p_reason)` | `draft`/`submitted` → `cancelled`; lý do bắt buộc; quyền `waste.propose` |
| `waste_list(p_property_id, p_status, p_search, p_limit, p_offset)` / `waste_get(p_id)` | Danh sách/chi tiết hủy hàng; `total_value`/`unit_cost` chỉ khi có `stock.view_value`; quyền `waste.propose` hoặc `waste.approve` hoặc `waste.approve.large` |

## 5. Kiểm kê & khóa sổ

| RPC | Ghi chú |
|---|---|
| `count_open(p_warehouse_id, p_kind, p_business_date, p_shift, p_counter_ids, p_client_uuid)` | `shift_key` yêu cầu có `pos_imports` (`ERR_POS_IMPORT_REQUIRED`); `monthly_full` cần ≥2 người đếm, 1 người độc lập (`ERR_SOD_COUNT_INDEPENDENT`), 1 đợt mở/kho; mở đợt = đóng băng kho (`ERR_COUNT_FREEZE`); không mở vào ngày đã khóa (`ERR_DAY_LOCKED`) hay kỳ đã đóng (`ERR_PERIOD_CLOSED`); trả `{ok, id, doc_no, lines_created}` |
| `count_record_line(p_count_id, p_item_id, p_detail jsonb, p_bottle_weight_g, p_client_uuid)` | Ghi `counted_qty_1` hoặc `_2` (2 người đếm khác nhau); `p_detail` là 1 object hoặc mảng nhiều UOM, quy đổi qua `item_purchase_units` (`ERR_UOM_UNKNOWN`); cân chai `(cân − tare_g)/density_g_ml`; trả `{ok, counted_qty}` |
| `count_submit(p_count_id, p_pins text[])` | Tính `book/theoretical/variance`; 1 PIN/người đếm (thứ tự tùy ý); trả `{ok, round, recount_line_ids, red_line_ids}` — **không trả số**; dòng khớp khi 2 người đếm bằng nhau và \|lệch\| ≤ ngưỡng `count_recount_threshold_pct` (mặc định 5% của tồn sổ; tồn sổ = 0 thì mọi lệch khác 0 đều vượt ngưỡng) → `ok`, `variance_qty` vẫn lưu đúng số thật; ngược lại vòng 1 → `recount`, vòng 2 → `red` |
| `count_lock(p_count_id, p_reasons jsonb)` | Sau lần 2; lý do bắt buộc cho mọi dòng đỏ (`ERR_REASON_REQUIRED`, `ERR_REASON_CODE_INVALID`); quyền `count.lock` |
| `count_adjust_post(p_count_id)` | gm duyệt (`count.adjust.approve`) → `adjust_count` theo giá bình quân (FIFO dùng giá lớp); dòng chênh 0 không ghi move nhưng vẫn mở đóng băng |
| `count_add_counter(p_count_id, p_user_id)` | Thêm người đếm vào đợt đang mở; quyền `count.open` |
| `count_cancel(p_count_id, p_reason)` | Hủy đợt trước khi khóa; lý do bắt buộc; quyền `count.open` |
| `day_lock(p_warehouse_id, p_date, p_shift)` / `day_unlock(p_lock_id, p_reason)` | Khóa theo kho + ngày (+ ca); khóa trùng là upsert lũy đẳng; mở khóa cần lý do (`ERR_REASON_REQUIRED`, `ERR_LOCK_NOT_FOUND`); Unlock → alert `UNLOCK` |
| `period_close(p_entity_id, p_year, p_month)` / `period_reopen(p_period_id, p_reason)` | Kiểm điều kiện mục 10 của `05-BUSINESS-RULES.md`: mọi kho của pháp nhân có đợt `monthly_full` tháng đó ở `locked`/`adjusted` (`ERR_COUNT_NOT_LOCKED`), không PO `partially_received` quá hạn >30 ngày (`ERR_PO_UNRESOLVED`), không tạm ứng `overdue` (`ERR_ADVANCE_OVERDUE`); đóng trùng → `ERR_PERIOD_ALREADY_CLOSED` |

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
| `payment_request_create`, `payment_request_decide`, `payment_mark_paid(p_id, p_bank_ref)` | `ap_ledger` (−) khi paid; timeline duyệt đọc qua `approval_timeline(..., 'payment_request', ...)` (Q73) |
| `service_contract_save`, `service_schedule_generate(p_month)`, `service_accept(p_schedule_id, p_rating, p_photos, p_po_id, p_note)` | `p_note` tuy chon, luu vao `service_acceptances.note` (Q81) |
| `pms_daily_upsert(p_property_id, p_date, p_stats jsonb)` | Lễ tân nhập hằng ngày |
| `pos_import_commit(p_import_id)` (P2) | |

## 8. Nhà hàng (M06)

| RPC | Ghi chú |
|---|---|
| `recipe_save(p_property_id, p_recipe jsonb)` | Upsert món + tạo version mới `active`, version cũ `retired`; kiểm tra loại món, mã trùng, mỗi dòng đúng một trong `item_id`/`sub_recipe_id`, `qty > 0`, `loss_pct` 0–100, không tự tham chiếu chính mình |
| `recipe_set_active(p_recipe_id, p_active)` | Bật/tắt món |
| `recipe_foodcost(p_recipe_id)` / `recipe_foodcost_list(p_property_id)` | Foodcost mỗi phần theo giá trần hiện tại; dòng chưa có giá trần hoặc chưa có hệ số đổi đơn vị → foodcost `NULL` + `has_unknown_cost = true` (không dùng giá Excel 2018–2020) |
| `restaurant_kitchen_today(p_property_id, p_date)` | Món đang bán + phiên buffet + tiệc đã xác nhận/đang diễn ra hôm đó + bảng NVL cần chuẩn bị (gộp theo món, tính theo `portions_per_batch`) |
| `restaurant_sales_summary(p_property_id, p_from, p_to)` | Tổng doanh thu/foodcost/lãi gộp + theo món + theo ngày (đã trừ dòng hủy) |
| `dish_sale_record(p_property_id, p_recipe_id, p_business_date, p_qty, p_unit_price)` | Ghi bán tay; chặn ngày tương lai (giờ VN), `qty > 0`, món phải đang bán |
| `dish_sale_void(p_sale_id)` | Chỉ dòng bán tay; đánh dấu hủy, không xóa |
| `buffet_session_save(p_property_id, p_session jsonb)` | Tạo/sửa phiên buffet (mỗi buổi/ngày 1 phiên trừ khi hủy) |
| `buffet_session_close(p_session_id, p_guests, p_price_per_guest)` | Đóng phiên → sinh dòng bán `source='buffet'`, doanh thu = khách × giá/khách |
| `buffet_session_cancel(p_session_id, p_reason)` | Lý do bắt buộc |
| `banquet_save(p_property_id, p_banquet jsonb)` | Tạo/sửa tiệc; kiểm tra `end_time > start_time` |
| `banquet_confirm(p_banquet_id)` | Kiểm tra trùng sảnh: cùng khách sạn + cùng sảnh + cùng ngày + khung giờ giao nhau + trạng thái `confirmed`/`in_progress` → `ERR_BANQUET_HALL_CONFLICT` |
| `banquet_start(p_banquet_id)` / `banquet_complete(p_banquet_id)` | Hoàn thành → sinh dòng bán `source='banquet'` theo thực đơn tiệc |
| `banquet_cancel(p_banquet_id, p_reason)` | Lý do bắt buộc |
| `report_get(..., 'RPT_FNB_REVENUE', ...)` | Báo cáo doanh thu F&B: mỗi dòng theo món + 1 dòng tổng buffet; foodcost theo giá trần hiện tại |

Quyền mới (seed 500000): `restaurant.view`, `restaurant.dish.manage`, `restaurant.sale.record`, `restaurant.buffet.manage`, `restaurant.banquet.manage`, `report.view.rpt_fnb_revenue`.

## 9. Phân quyền (quản trị)

Mọi RPC dưới đây yêu cầu `admin.roles.manage` hoặc `admin.users.manage` (ghi rõ ở cột), ghi `audit_log`, tạo alert `PERMISSION_CRITICAL_CHANGED` nếu đụng quyền mức `critical`.

| RPC | Quyền cần | Ghi chú |
|---|---|---|
| `admin_role_save(p_role jsonb)` | `admin.roles.manage` | Tạo/sửa tên, mô tả; sửa được cả `sys_admin` (admin-relax 10/11/2026) |
| `admin_role_copy(p_role_id, p_new_name)` | `admin.roles.manage` | Sao chép cả ma trận quyền; sao chép được cả `sys_admin` (admin-relax 10/11/2026) |
| `admin_role_set_permissions(p_role_id, p_permission_codes text[], p_reason)` | `admin.roles.manage` | Ghi đè toàn bộ ma trận; trả `{added[], removed[], conflicts[]}`; cấp được cho cả `sys_admin` (admin-relax 10/11/2026) |
| `admin_role_deactivate(p_role_id)` | `admin.roles.manage` | Không xóa vật lý; vẫn chặn `sys_admin` (`ERR_SYSTEM_ROLE`) |
| `admin_user_assign_role(p_user_id, p_role_id, p_property_id, p_outlet_ids, p_warehouse_ids, p_valid_from, p_valid_to)` | `admin.users.manage` | Tự gán cho chính mình được phép (admin-relax 10/11/2026); gán được mọi vai trò kể cả `sys_admin` |
| `admin_user_revoke_role(p_assignment_id, p_reason)` | `admin.users.manage` | Đặt `valid_to = hôm nay`; `ERR_LAST_ADMIN` nếu gỡ admin cuối; vẫn chặn tự thu hồi (`ERR_SELF_GRANT`) |
| `admin_permission_override_set(p_user_id, p_property_id, p_permission_code, p_effect, p_valid_to, p_reason)` | `admin.permissions.override` | `allow`/`deny`; lý do bắt buộc; tự cấp cho chính mình được phép (admin-relax 10/11/2026) |
| `admin_user_effective_permissions(p_user_id, p_property_id)` | `admin.users.manage` | Trả mỗi quyền + nguồn (vai trò nào / override nào) |
| `admin_sod_conflict_check(p_user_id \| p_role_id)` | `admin.users.manage` | Trả danh sách cặp quyền xung đột |
| `my_permissions(p_property_id)` | đăng nhập | UI dùng cho `useCan` |

### Edge Function quản trị tài khoản (gọi từ app qua `supabase.functions.invoke`)

| Edge Function | Quyền cần | Ghi chú |
|---|---|---|
| `admin-create-user` | `admin.users.manage` (chuỗi, kiểm tra qua `user_has_perm`) | Tạo tài khoản + gán 1..n vai trò trong 1 lần; body `{employeeCode, fullName, email?, phone?, password?, roles?: [{roleId, propertyId?, outletIds?, warehouseIds?}], roleId?, propertyId?, outletIds?, warehouseIds?, validTo?}`; `password` bỏ trống thì sinh ngẫu nhiên; mật khẩu tạm trả về 1 lần; lỗi trả mã `email_exists` / `employee_code_exists` / `invalid_role` / `invalid_property_for_role` / `assign_role_failed` (UI dịch trong `vi.admin.edgeFunctionErrors`) |
| `admin-reset-password` | `admin.users.manage` (chuỗi, kiểm tra qua `user_has_perm`) | Đặt lại mật khẩu cho tài khoản khác; body `{userId, password?}`; `password` bỏ trống thì sinh ngẫu nhiên; mật khẩu tạm trả về 1 lần; không đặt lại mật khẩu của chính mình (`cannot_reset_own_password` — tự đổi ở `/settings/password`); ghi `audit_log` (`table_name='profiles'`, `new_data={event:'admin_password_reset'}`) |

Tự đổi mật khẩu của chính mình không qua Edge Function: màn `/settings/password` gọi server action `changeOwnPasswordAction` — xác minh mật khẩu hiện tại bằng `signInWithPassword` rồi `updateUser({password})`; phiên hiện tại giữ nguyên.

## 10. Cấu hình nghiệp vụ

Các RPC cấu hình kiểm tra quyền tương ứng, ghi `audit_log` và chỉ cho phép đọc/ghi qua RPC; bảng bật RLS nhưng không cấp quyền truy cập trực tiếp cho client. `p_property_id = null` là cấu hình toàn chuỗi; giá trị `settings` tại khách sạn ghi đè giá trị toàn chuỗi.

| RPC | Quyền cần | Ghi chú |
|---|---|---|
| `admin_settings_list(p_org_id, p_property_id)` | `admin.settings.manage` | Trả giá trị đã lưu hoặc mặc định; nguồn ghi rõ `default` / `organization` / `property` |
| `admin_setting_save(p_org_id, p_property_id, p_key, p_value text)` | `admin.settings.manage` | Lưu ngưỡng đã kiểm tra miền giá trị |
| `admin_approval_rules_list(p_org_id, p_property_id)` | `admin.approval_rules.manage` | Danh sách quy tắc theo phạm vi |
| `admin_approval_approvers_list(p_org_id, p_property_id)` | `admin.approval_rules.manage` | Chỉ trả vai trò hoạt động và người dùng thuộc tổ chức |
| `admin_approval_rule_save(p_rule jsonb)` / `admin_approval_rule_delete(p_rule_id)` | `admin.approval_rules.manage` | Mỗi bước có đúng một vai trò hoặc người duyệt; vai trò phải có quyền cần duyệt; khi chuyển phạm vi phải có quyền ở cả phạm vi hiện tại và đích |
| `admin_alert_rules_list(p_org_id, p_property_id)` | `admin.alert_rules.manage` | Danh sách quy tắc theo phạm vi |
| `admin_alert_rule_save(p_rule jsonb)` / `admin_alert_rule_delete(p_rule_id)` | `admin.alert_rules.manage` | Ngưỡng là JSON object; kênh hợp lệ: `app`, `email`, `webpush`, `zalo`; khi chuyển phạm vi phải có quyền ở cả phạm vi hiện tại và đích |

Khởi tạo production trước khi có quản trị viên là ngoại lệ vận hành một lần: `bootstrap_initial_org(...)` chỉ được gọi từ Edge Function bằng `service_role`, chỉ chạy khi chưa có tổ chức, và tạo hai tài khoản `sys_admin` cùng một tài khoản kiểm thử bị giới hạn ở khách sạn đầu tiên. Tài khoản kiểm thử không nhận quyền quản trị hoặc quyền `critical`. Sau bootstrap, tạo và quản lý người dùng theo các RPC quản trị ở trên; không cấp `service_role` cho client.

## 11. Mã lỗi (UI dịch trong `errors.vi.ts`)

| Mã | Nghĩa |
|---|---|
| `ERR_FORBIDDEN:<ma.quyen>` | Không có quyền (kèm mã quyền thiếu để UI báo rõ) |
| `ERR_CONFIG_INVALID` | Cấu hình sai định dạng hoặc ngoài giới hạn |
| `ERR_CONFIG_SCOPE` | Phạm vi cấu hình không thuộc tổ chức |
| `ERR_CONFIG_ITEM_GROUP` | Nhóm hàng không tồn tại hoặc không thuộc tổ chức của quy tắc duyệt |
| `ERR_CONFIG_APPROVER` | Vai trò/người duyệt không hợp lệ hoặc thiếu quyền |
| `ERR_SELF_GRANT` | Không được tự thu hồi vai trò / tự khóa tài khoản của chính mình (tự CẤP đã được phép từ admin-relax 10/11/2026) |
| `ERR_LAST_ADMIN` | Phải còn ít nhất 2 người quản trị |
| `ERR_SYSTEM_ROLE` | Không ngừng dùng vai trò hệ thống (sửa/sao chép/cấp quyền cho `sys_admin` đã được phép từ admin-relax 10/11/2026) |
| `ERR_SOD_<RULE>` | Vi phạm tách biệt nhiệm vụ (mã quy tắc ở `04-SECURITY-RLS.md`) |
| `ERR_IMMUTABLE_LEDGER` | Cố sửa/xóa sổ cái |
| `ERR_DOC_POSTED` | Chứng từ đã ghi sổ |
| `ERR_INVALID_STATUS` | Sai trạng thái cho thao tác |
| `ERR_NEGATIVE_STOCK` | Không đủ tồn |
| `ERR_PERIOD_CLOSED` / `ERR_DAY_LOCKED` | Kỳ/ngày đã khóa |
| `ERR_COUNT_FREEZE` | Kho đang kiểm kê |
| `ERR_COUNT_NOT_LOCKED` | Kỳ chưa đóng được vì có kho chưa có đợt kiểm kê tháng ở trạng thái `locked`/`adjusted` |
| `ERR_COUNT_ALREADY_OPEN` | Đã có đợt kiểm kê tháng đang mở cho kho này |
| `ERR_COUNT_INCOMPLETE` | Có dòng chưa đủ 2 lượt đếm khi nộp đợt |
| `ERR_PO_UNRESOLVED` | Còn PO `partially_received` quá hạn >30 ngày, kỳ chưa đóng được |
| `ERR_ADVANCE_OVERDUE` | Còn tạm ứng `overdue`, kỳ chưa đóng được |
| `ERR_SOD_COUNT_INDEPENDENT` | Đội đếm kiểm kê tháng không có người độc lập (không đếm ở ca) |
| `ERR_REASON_CODE_INVALID` | Mã lý do chênh lệch không nằm trong danh sách chuẩn |
| `ERR_PERIOD_ALREADY_CLOSED` | Kỳ đã đóng rồi |
| `ERR_DAY_LOCKED` | Ngày đã khóa (theo kho) |
| `ERR_LOCK_NOT_FOUND` | Không tìm thấy bản ghi khóa ngày |
| `ERR_OVER_CEILING_NO_REASON` | Vượt giá trần chưa có lý do |
| `ERR_PHOTO_REQUIRED` | Thiếu ảnh bắt buộc |
| `ERR_PIN_INVALID` | Sai PIN |
| `ERR_INVALID_PIN` | Mã PIN mới không đúng định dạng 4–6 chữ số |
| `ERR_REASON_REQUIRED` | Thao tác quản trị thiếu lý do bắt buộc |
| `ERR_ADVANCE_OVERDUE_BLOCK` | Có tạm ứng quá hạn, không được ứng mới |
| `ERR_TEMP_ITEM_EXPIRED` | Mã tạm quá 72h |
| `ERR_POS_IMPORT_REQUIRED` | Chưa tải file POS của ca |
| `ERR_SERVICE_NOT_ACCEPTED` | Kỳ dịch vụ chưa nghiệm thu |
| `ERR_UOM_UNKNOWN` | Đơn vị chưa khai báo quy đổi |
