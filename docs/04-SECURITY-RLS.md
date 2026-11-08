# 04 — Phân quyền động, RLS và tách biệt nhiệm vụ (SoD)

## 0. Nguyên tắc thiết kế

1. **Vai trò và quyền là dữ liệu, không phải code.** Quản trị tự tạo vai trò, tích chọn quyền cho vai trò, gán vai trò cho người dùng theo khách sạn (và tùy chọn theo bộ phận/kho), chỉnh quyền riêng từng người. Không cần deploy khi đổi phân quyền.
2. **Code chỉ kiểm tra *quyền* (`permission_code`), không bao giờ kiểm tra tên vai trò.** Viết `has_perm(p, 'po.approve')`, **không** viết `role_code = 'gm'`.
3. **Danh mục quyền (permission catalog) do code định nghĩa** — mỗi tính năng mới phải khai báo quyền của nó trong migration seed. Người dùng không tạo được quyền mới, chỉ gán.
4. **Các vai trò mặc định chỉ là mẫu** (`is_system = true`), được sao chép/sửa; không xóa được vai trò hệ thống `sys_admin`.
5. **SoD và cơ chế "mù" không phụ thuộc cấu hình quyền.** Dù cấu hình thế nào, một người vẫn không được vừa tạo vừa duyệt cùng một chứng từ, và màn hình nhận hàng không bao giờ trả số lượng PO. Cấu hình chỉ quyết định *ai được làm gì*, không tắt được kiểm soát.

## 1. Mô hình dữ liệu phân quyền

| Bảng | Cột | Ghi chú |
|---|---|---|
| `permissions` | `code` (PK, vd `po.approve`), `module`, `name_vi`, `description_vi`, `risk_level` (`normal`,`sensitive`,`critical`), `sort_order` | Seed bởi migration. Chỉ đọc với mọi người |
| `roles` | `id`, `org_id`, `code`, `name_vi`, `description`, `is_system`, `active`, `copied_from_id` | Người dùng tạo/sửa |
| `role_permissions` | `role_id`, `permission_code` | PK 2 cột. Ma trận tích chọn |
| `user_property_roles` | `id`, `user_id`, `role_id`, `property_id?` (null = toàn chuỗi), `outlet_ids uuid[]?`, `warehouse_ids uuid[]?` (null = mọi outlet/kho của KS), `valid_from`, `valid_to`, `granted_by` | Gán vai trò có phạm vi và thời hạn |
| `user_permission_overrides` | `id`, `user_id`, `property_id?`, `permission_code`, `effect` (`allow`,`deny`), `valid_from`, `valid_to`, `reason`, `granted_by` | Quyền riêng từng người; `deny` thắng mọi `allow` |
| `permission_change_log` | (dùng `audit_log` chung) | Mọi thay đổi 4 bảng trên đều ghi audit + alert |

Thứ tự đánh giá quyền của một người tại khách sạn P:
1. Có `deny` còn hạn cho quyền đó (P hoặc toàn chuỗi) → **không có quyền**.
2. Có `allow` còn hạn → có quyền.
3. Có ít nhất một vai trò còn hạn, `active`, tại P hoặc toàn chuỗi, chứa quyền đó → có quyền.
4. Ngược lại → không có quyền.

Phạm vi bộ phận/kho: quyền thao tác chứng từ của một kho chỉ có hiệu lực nếu `warehouse_ids` (hoặc `outlet_ids`) của lần gán vai trò bao phủ kho đó — ví dụ bếp trưởng chỉ duyệt hủy hàng của kho bếp mình.

## 2. Hàm phân quyền

```sql
-- Có quyền p_perm tại khách sạn p_property (và kho p_warehouse nếu truyền) không?
create or replace function public.has_perm(p_property uuid, p_perm text, p_warehouse uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  with ov as (
    select effect from user_permission_overrides o
    where o.user_id = auth.uid() and o.permission_code = p_perm
      and (o.property_id = p_property or o.property_id is null)
      and current_date between o.valid_from and coalesce(o.valid_to, 'infinity'::date)
  )
  select case
    when exists (select 1 from ov where effect = 'deny')  then false
    when exists (select 1 from ov where effect = 'allow') then true
    else exists (
      select 1
      from user_property_roles upr
      join roles r on r.id = upr.role_id and r.active
      join role_permissions rp on rp.role_id = r.id and rp.permission_code = p_perm
      where upr.user_id = auth.uid()
        and (upr.property_id = p_property or upr.property_id is null)
        and current_date between upr.valid_from and coalesce(upr.valid_to, 'infinity'::date)
        and (p_warehouse is null or upr.warehouse_ids is null or p_warehouse = any(upr.warehouse_ids)
             or exists (select 1 from warehouses w where w.id = p_warehouse and w.outlet_id = any(upr.outlet_ids)))
    )
  end
$$;

-- Bản "ném lỗi" dùng đầu mỗi RPC
create or replace function public.require_perm(p_property uuid, p_perm text, p_warehouse uuid default null)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.has_perm(p_property, p_perm, p_warehouse) then
    raise exception 'ERR_FORBIDDEN:%', p_perm;
  end if;
end $$;

-- Khách sạn người dùng được truy cập (có ít nhất 1 vai trò còn hạn)
create or replace function public.my_property_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id from properties p
  where exists (select 1 from user_property_roles upr join roles r on r.id = upr.role_id and r.active
                where upr.user_id = auth.uid()
                  and (upr.property_id = p.id or upr.property_id is null)
                  and current_date between upr.valid_from and coalesce(upr.valid_to,'infinity'::date))
$$;

-- Toàn bộ quyền hiệu lực của tôi tại 1 KS — UI dùng để ẩn/hiện nút, menu
create or replace function public.my_permissions(p_property uuid) returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(p.code order by p.code), '{}')
  from permissions p where public.has_perm(p_property, p.code)
$$;
```

Ghi chú: gọi `has_perm` **không** truyền `p_warehouse` → trả `true` nếu người dùng có quyền ở ít nhất một kho trong phạm vi (dùng cho UI hiện menu). RPC thao tác trên kho cụ thể **bắt buộc** truyền `p_warehouse`. Đã chạy thử 12 ca (vai trò, khác KS, phạm vi kho, deny thắng, allow riêng, hết hạn, vai trò ngừng dùng, bỏ tích quyền) trên Postgres 16.

Mẫu policy:

```sql
alter table public.goods_receipts enable row level security;
create policy gr_select on public.goods_receipts for select to authenticated
  using (property_id in (select public.my_property_ids())
         and (select public.has_perm(property_id, 'receiving.view')));
-- Không có policy INSERT/UPDATE cho bảng đầu chứng từ: tạo/sửa nháp qua RPC *_save_draft

-- Bảng cấp chuỗi
create policy items_write on public.items for insert to authenticated
  with check ((select public.has_perm(null, 'item.manage')));
```

Hiệu năng: bọc hàm trong `(select …)` trong policy để Postgres tính một lần cho mỗi câu lệnh; index `user_property_roles(user_id)`, `user_permission_overrides(user_id, permission_code)`, `role_permissions(permission_code)`.

**Giao diện:** khi chọn khách sạn, client gọi `my_permissions(property_id)` một lần, lưu vào context; dùng hook `useCan('po.approve')` để ẩn/hiện. Việc ẩn ở UI chỉ để gọn giao diện — **RPC luôn tự kiểm tra lại**.

## 3. Danh mục quyền (seed — agent bổ sung khi thêm tính năng)

| Module | Mã quyền | Mức |
|---|---|---|
| Quản trị | `admin.users.manage`, `admin.roles.manage`, `admin.permissions.override`, `admin.settings.manage`, `admin.approval_rules.manage`, `admin.alert_rules.manage` | critical |
| Danh mục | `item.view`, `item.manage`, `item.temp.create`, `item.temp.normalize`, `item.import`, `warehouse.manage`, `room.manage` | normal / sensitive |
| NCC & giá | `supplier.view`, `supplier.manage`, `supplier.approve`, `supplier.bank.request`, `supplier.bank.approve`, `price.agreement.manage`, `price.ceiling.manage`, `price.view` | sensitive / critical |
| Thu mua | `pr.create`, `pr.approve`, `po.create`, `po.view`, `po.view_qty`, `po.view_price`, `po.approve`, `po.approve.over_ceiling`, `po.close`, `market.order.create` | normal / sensitive |
| Nhận hàng | `receiving.perform`, `receiving.post`, `receiving.view`, `receiving.review_photos`, `receiving.override_over_po`, `receiving.reverse`, `supplier_return.post` | sensitive |
| Kho | `stock.view_qty`, `stock.view_value`, `requisition.create`, `requisition.approve`, `requisition.issue`, `requisition.receive`, `transfer.send`, `transfer.receive`, `purpose_issue.post`, `waste.propose`, `waste.approve`, `waste.approve.large` | normal / sensitive |
| Kiểm kê & khóa | `count.open`, `count.perform`, `count.lock`, `count.view_variance`, `count.adjust.approve`, `day.lock`, `day.unlock`, `period.close`, `period.reopen` | sensitive / critical |
| Buồng phòng | `hk.standard.manage`, `hk.trolley.operate`, `minibar.request_check`, `minibar.check`, `minibar.charge.confirm`, `minibar.waive.request`, `minibar.waive.approve`, `minibar.refill` | normal / sensitive |
| Tài chính | `invoice.manage`, `invoice.approve`, `ap.view`, `advance.request`, `advance.approve`, `advance.disburse`, `advance.settle`, `payment.request`, `payment.approve`, `payment.mark_paid`, `export.accounting` | sensitive / critical |
| Dịch vụ | `service.contract.manage`, `service.accept` | normal |
| Dữ liệu ngoài | `pms.input`, `pos.import` | normal |
| Báo cáo | `report.view.<mã báo cáo>` (một quyền cho mỗi báo cáo), `report.daily_brief.receive`, `audit.view_all` | normal / sensitive |
| Cảnh báo | `alert.receive.<mã cảnh báo>` | normal |

Quyền mức `critical` khi được gán/bỏ → tạo alert `PERMISSION_CRITICAL_CHANGED` gửi chủ đầu tư ngay.

## 4. Vai trò mẫu (seed, `is_system = true`, sửa được trừ `sys_admin`)

| Vai trò mẫu | Quyền tiêu biểu |
|---|---|
| Chủ đầu tư | mọi `report.view.*`, `report.daily_brief.receive`, `po.approve` (bước > 100 triệu), `audit.view_all` |
| Tổng quản lý (GM) | `po.approve`, `po.approve.over_ceiling`, `waste.approve.large`, `count.adjust.approve`, `day.unlock`, `minibar.waive.approve`, `advance.approve`, báo cáo |
| Kế toán trưởng chuỗi | `invoice.approve`, `payment.approve`, `period.close`, `price.ceiling.manage`, `supplier.bank.approve`, `export.accounting` |
| Kế toán KS | `invoice.manage`, `ap.view`, `advance.disburse`, `advance.settle`, `payment.request`, `payment.mark_paid`, `day.lock`, `count.lock`, `pms.input` |
| Cost Controller | `price.ceiling.manage`, `receiving.review_photos`, `count.view_variance`, `waste.approve`, `item.temp.normalize`, `po.approve` (bước giữa) |
| Thu mua | `pr.create`, `po.create`, `po.view`, `po.view_qty`, `po.view_price`, `market.order.create`, `supplier.manage`, `supplier.bank.request`, `advance.request`, `item.temp.create` |
| Thủ kho | `receiving.perform`, `receiving.post`, `receiving.view`, `requisition.issue`, `transfer.*`, `stock.view_qty`, `count.open`, `count.perform`, `supplier_return.post`, `item.temp.create` |
| Nhận hàng ca sáng | `receiving.perform`, `receiving.post` (không `po.view_qty`, không `stock.view_*`) |
| Trưởng bộ phận | `pr.create`, `pr.approve`, `requisition.create`, `requisition.approve`, `requisition.receive`, `waste.propose` |
| Bếp trưởng | như Trưởng bộ phận + `count.perform`, `hk`/`recipe` (P2) |
| Giám sát buồng | `hk.standard.manage`, `hk.trolley.operate`, `minibar.refill`, `requisition.*` (kho tầng), `waste.propose` |
| Nhân viên buồng | `hk.trolley.operate`, `minibar.check` |
| Lễ tân | `minibar.request_check`, `minibar.charge.confirm`, `minibar.waive.request`, `pms.input` |
| Kỹ thuật | `requisition.create`, `service.accept` (P2: chỉ số đồng hồ, phiếu sửa chữa) |
| Kiểm soát nội bộ | `audit.view_all`, mọi `report.view.*` — **không** quyền ghi |
| Quản trị hệ thống | `admin.*` — **không** quyền nghiệp vụ |

## 5. Rào chắn khi cấu hình (bắt buộc thực thi)

| Rào chắn | Cách thực thi |
|---|---|
| Không tự cấp quyền cho chính mình | RPC `admin_user_assign_role`, `admin_permission_override_set`, `admin_role_set_permissions` (khi người sửa đang giữ vai trò đó): `auth.uid()` ≠ người được cấp → `ERR_SELF_GRANT` |
| Luôn còn ≥ 2 người giữ `admin.users.manage` + `admin.roles.manage` | Kiểm trong RPC trước khi gỡ → `ERR_LAST_ADMIN` |
| Không sửa/xóa vai trò `sys_admin`; vai trò đang được gán không xóa, chỉ `active = false` | Trigger |
| Quản trị hệ thống không được giữ quyền nghiệp vụ tiền/kho cùng lúc với `admin.*` | Cảnh báo "tổ hợp nguy hiểm" khi lưu; cho lưu nếu có lý do + alert chủ đầu tư |
| Cảnh báo tổ hợp xung đột trong cùng vai trò hoặc cùng người (vd. `po.create` + `receiving.post`; `supplier.bank.request` + `payment.approve`; `waste.propose` + `waste.approve`) | Hàm `sod_conflict_check(user_id)` chạy khi lưu; hiển thị cảnh báo vàng trên màn hình phân quyền. **Không chặn** (khách sạn nhỏ cần kiêm nhiệm) vì SoD trên từng chứng từ vẫn chặn |
| Gán vai trò/quyền có thời hạn | `valid_to` khuyến nghị cho quyền tạm (thay ca, nghỉ phép) |
| Mọi thay đổi ghi `audit_log`; quyền `critical` → alert ngay | Trigger + RPC |

## 6. Tách biệt nhiệm vụ trên từng chứng từ (không tắt được)

Kiểm tra trong RPC bằng `assert_sod(rule_code, doc_id)`, dựa trên **người** thực hiện các bước của chứng từ (lưu ở `created_by`, `approvals.approver_id`, `receiver_id`…), độc lập với cấu hình quyền. Vi phạm → `ERR_SOD_<CODE>`, trừ khi có `sod_exceptions` còn hạn (vẫn cho qua, tạo alert `SOD_EXCEPTION_USED`, vào báo cáo tuần).

| Mã | Quy tắc |
|---|---|
| `SOD_PO_CREATOR_APPROVER` | Người tạo PO ≠ người duyệt bất kỳ bước nào |
| `SOD_PO_RECEIVER` | Người tạo hoặc duyệt PO ≠ người nhận hàng của PO đó |
| `SOD_MARKET_BUYER_RECEIVER` | Người giữ tạm ứng đi chợ ≠ người nhận hàng mua chợ |
| `SOD_INVOICE_GR` | Người nhập hóa đơn ≠ người nhận hàng |
| `SOD_PAYMENT_APPROVER` | Người duyệt thanh toán ≠ người nhập hóa đơn ≠ người yêu cầu đổi STK NCC (30 ngày) |
| `SOD_BANK_ACCOUNT` | Người yêu cầu đổi STK ≠ người duyệt |
| `SOD_WASTE` | Người đề xuất hủy ≠ người duyệt |
| `SOD_MINIBAR_WAIVE` | Người đề nghị miễn minibar ≠ người duyệt miễn |
| `SOD_YIELD` (P2) | Người lập biên bản pha lóc ≠ người duyệt |
| `SOD_COUNT_INDEPENDENT` | Đợt kiểm kê tháng có ≥ 1 người đếm không có quyền `receiving.post`/`requisition.issue` tại kho đó |
| `SOD_GRANT` | Người cấp quyền ≠ người nhận quyền |

`sod_exceptions` chỉ tạo được bởi người có `admin.permissions.override` **và** được người có `po.approve` mức GM xác nhận.

## 7. Hai hồ sơ SoD theo khách sạn (`properties.sod_profile`)

Hồ sơ không còn quyết định "ai làm" (đã do cấu hình quyền), chỉ quyết định **mức kiểm soát bù trừ**:

| Thiết lập | `with_cc` | `without_cc` |
|---|---|---|
| Hậu kiểm ảnh nhận hàng | 100% phiếu | 20% ngẫu nhiên + mọi phiếu bị cảnh báo |
| Ngưỡng cảnh báo | mặc định | chặt hơn 30% |
| Kiểm kê chọn mẫu | P2 | bắt buộc hằng ngày từ MVP (3 mã) |
| Duyệt pha lóc dưới chuẩn (P2) | người có `count.view_variance` tại KS | bắt buộc người ở **KS khác** (duyệt chéo) hoặc GM |

Khi tạo khách sạn mới, màn hình gợi ý bộ vai trò mẫu phù hợp hồ sơ (có hoặc không vai trò Cost Controller) để quản trị gán nhanh.

## 8. Cơ chế "mù" ở tầng dữ liệu (không phụ thuộc quyền)

| Màn hình | Không trả về | Cách thực thi |
|---|---|---|
| Nhận hàng | Số lượng PO, đơn giá, thành tiền | RPC `receiving_get_task` không bao giờ trả các trường đó, kể cả khi người dùng có `po.view_qty` (người đó xem ở màn hình PO, không phải lúc đang nhận). Policy SELECT `purchase_order_lines` yêu cầu `po.view_qty` |
| Kiểm kê | `book_qty`, `theoretical_qty`, `variance_*` | Người đếm đọc qua view `v_count_sheet`; cột đầy đủ chỉ đọc qua `v_count_result` yêu cầu `count.view_variance` **và** người đó không có tên trong `counter_ids` của đợt đếm |
| Xe đẩy | Tiêu hao lý thuyết | View riêng tương tự |

Dung sai ±5% so với PO được kiểm tra **trong** `receiving_record_line`; kết quả trả về chỉ là `{ needs_reweigh: true }`.

## 9. Storage

- Bucket `evidence` private. INSERT: người dùng đăng nhập, đường dẫn bắt đầu bằng `legal_entity_id` mà họ có quyền. SELECT: theo `my_property_ids()` qua bảng `attachments`.
- Không cho UPDATE/DELETE object.

## 10. Bí mật & khóa

| Khóa | Ở đâu | Không bao giờ |
|---|---|---|
| Publishable/anon key | `NEXT_PUBLIC_*` | — |
| Secret/service role key | Vercel env (server), Supabase secrets | Code client, repo, log |
| `CRON_SECRET` | Vercel env + header gọi cron | Query string |
| Token Zalo OA | Supabase secrets | Bảng DB dạng rõ |

## 11. Kiểm tra bắt buộc trong pgTAP

- Mỗi bảng: RLS enabled.
- User KS A không SELECT được dữ liệu KS B.
- `has_perm`: `deny` thắng `allow` và thắng vai trò; quyền hết hạn không có hiệu lực; vai trò `active = false` không có hiệu lực; phạm vi `warehouse_ids` giới hạn đúng kho.
- Tạo vai trò mới, tích quyền `waste.approve`, gán cho user X → X duyệt được hủy hàng; bỏ tích → X bị `ERR_FORBIDDEN` ngay (không cần đăng nhập lại).
- Tự cấp quyền cho chính mình → `ERR_SELF_GRANT`; gỡ admin cuối cùng → lỗi.
- Người có `po.view_qty` gọi `receiving_get_task` → JSON vẫn không có `qty`.
- `authenticated` `insert into stock_moves` → lỗi quyền; UPDATE `stock_moves` → `ERR_IMMUTABLE_LEDGER`.
- Mỗi quy tắc SoD: 1 test vi phạm, 1 test hợp lệ — kể cả khi user có đủ mọi quyền.
