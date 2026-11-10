# Đổi tên pháp nhân (khi có tên thật)

> **Trạng thái:** Chuẩn bị sẵn — chỉ chạy khi Duy đưa tên pháp nhân thật.
> Hiện tại tên pháp nhân thật **chưa có**: cả 3 bảng đều đang dùng tạm tên
> khách sạn "Son Hoi An Boutique Hotel & Spa". Câu SQL mẫu dưới đây dùng
> placeholder `<TÊN PHÁP NHÂN THẬT>` — thay bằng tên thật rồi mới chạy.
> Thời gian thực hiện: ~1 phút (3 câu UPDATE + kiểm chứng).
> Nguồn: `docs/OPEN-QUESTIONS.md`, `docs/sample-data/README.md` §0,
> `supabase/migrations/20261109110000_inventory_foundation.sql` (bảng
> organizations/legal_entities/properties), màn tổng quan
> `src/app/(app)/[property]/page.tsx`.

## 0. Hiện trạng (đã kiểm chứng bằng grep, 10/11)

| Bảng | UUID (production) | Tên hiện tại | Ghi chú |
|---|---|---|---|
| `organizations` | `00dc6aeb-5e34-4e01-9b80-032a72b16d71` | Son Hoi An Boutique Hotel & Spa | Org đầu tiên, code `SONHOIAN` |
| `legal_entities` | `453b278f-62ec-44c3-ad10-e07c7efc6c8d` | Son Hoi An Boutique Hotel & Spa | Pháp nhân duy nhất hiện tại |
| `properties` | `7e37858d-58ed-4924-bb8f-9d56be9c620b` | Son Hoi An Boutique Hotel & Spa | Khách sạn đầu tiên |

> [CẦN XÁC NHẬN trước khi chạy] 3 UUID trên lấy từ MEMORY (ghi ngày
> 08–10/11). Bước 1 dưới đây có câu SELECT để đối chiếu lại UUID + tên
> hiện tại trước khi UPDATE — nếu SELECT không trả đúng 3 dòng thì DỪNG,
> không chạy tiếp.

- **Tên pháp nhân KHÔNG nằm trong code app, migration hay seed:**
  grep `"Son Hoi An"` trong toàn bộ `supabase/` (migrations + Edge
  Functions) = **0 kết quả**. Màn hình, chứng từ, báo cáo, file Excel đều
  đọc tên từ DB lúc chạy (vd. màn tổng quan query
  `legal_entity:legal_entities(code, name, costing_method,
  accounting_regime)`), nên đổi 3 dòng DB là đổi mọi nơi — không cần
  deploy, không cần sửa code.
- **Mã `SONHOIAN` không đổi theo tên.** Mã là `code` (khóa nghiệp vụ, dùng
  trong URL, test, seed). Chỉ đổi tên (`name`) ở đây. Nếu Duy muốn đổi cả
  mã thì đó là quyết định riêng (ảnh hưởng URL, test, seed) — không làm
  trong bước này.

## 1. Bước 0 — Đối chiếu UUID + tên hiện tại (chỉ đọc)

Chạy trên Supabase Dashboard → SQL Editor (project ERP_hotel):

```sql
select 'organizations' as bang, id, code, name from public.organizations;
select 'legal_entities' as bang, id, code, name from public.legal_entities;
select 'properties' as bang, id, code, name from public.properties;
```

Kỳ vọng: mỗi bảng 1 dòng (hiện tại), tên đều là
"Son Hoi An Boutique Hotel & Spa", UUID khớp bảng ở §0.
Nếu có dòng nào khác (vd. đã có thêm org/pháp nhân/khách sạn mới sau
10/11) thì **dừng** và xác định rõ đổi tên pháp nhân nào trước khi chạy.

## 2. Bước 1 — Câu SQL đổi tên (1 lần, 1 giao dịch)

```sql
begin;
update public.legal_entities
   set name = '<TÊN PHÁP NHÂN THẬT>', updated_at = now()
 where id = '453b278f-62ec-44c3-ad10-e07c7efc6c8d';
-- Chỉ đổi bảng legal_entities nếu tên khách sạn (properties) giữ nguyên.
-- Nếu Duy muốn đổi cả tên hiển thị của org và property cho đồng bộ
-- (khuyến nghị KHÔNG, trừ khi Duy nói rõ), bỏ comment 2 dòng dưới:
-- update public.organizations
--    set name = '<TÊN PHÁP NHÂN THẬT>', updated_at = now()
--  where id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71';
-- update public.properties
--    set name = 'Son Hoi An Boutique Hotel & Spa', updated_at = now()
--  where id = '7e37858d-58ed-4924-bb8f-9d56be9c620b';
commit;
```

> **Khuyến nghị mặc định: chỉ đổi `legal_entities.name`.**
> - Tên pháp nhân là tên trên giấy phép/hóa đơn — khác tên thương hiệu
>   khách sạn hiển thị cho nhân viên/khách.
> - `organizations.name` và `properties.name` là tên thương hiệu
>   ("Son Hoi An Boutique Hotel & Spa") — giữ nguyên để UI, test, tài liệu
>   không phải đổi theo.
> - Nếu Duy nói "đổi hết cho đồng bộ" thì mới chạy cả 3 câu.

**An toàn:** `name` không phải khóa chính/khóa ngoại, không có bảng nào
tham chiếu tới `name` — đổi tên không vỡ liên kết dữ liệu. Mọi bảng con
tham chiếu bằng UUID (`legal_entity_id`), không đổi.

## 3. Bước 2 — Kiểm chứng sau khi đổi (chỉ đọc + xem live)

```sql
select id, code, name from public.legal_entities
 where id = '453b278f-62ec-44c3-ad10-e07c7efc6c8d';
-- Kỳ vọng: name = <TÊN PHÁP NHÂN THẬT>, code vẫn như cũ.
```

Kiểm chứng trên giao diện (đăng xuất, mở lại — tên đọc từ DB nên hiện
ngay, không cần deploy):

| Nơi kiểm tra | Kỳ vọng sau khi đổi |
|---|---|
| Màn tổng quan `/[property]` (phần pháp nhân) | Hiện tên pháp nhân mới |
| 1 phiếu PO (màn xem chi tiết) | Đầu phiếu hiện tên pháp nhân mới (khi C3 PO PDF xong thì kiểm tra cả file PDF) |
| 1 hóa đơn / 1 đề nghị thanh toán (màn tài chính) | Tên pháp nhân mới |
| 1 báo cáo (màn `/reports`) | Tên pháp nhân mới trong đầu báo cáo |
| 1 file Excel kế toán (T-043, kỳ đã khóa) | Tên pháp nhân mới trong file |
| Bản tin 8h hôm sau | Tên org/pháp nhân trong bản tin (nếu bản tin in tên) |

## 4. Những chỗ chứa tên cũ bằng chữ (cập nhật riêng, không chặn go-live)

Đổi tên DB xong, các file sau vẫn chứa chuỗi "Son Hoi An Boutique Hotel
& Spa" bằng chữ — chúng **không ảnh hưởng app chạy** (chỉ là chữ trong
comment/docs/test), cập nhật khi rảnh:

| File | Vai trò | Cần làm gì |
|---|---|---|
| `tests/e2e/helpers.ts` (dòng 13) | Comment: tên property production | Sửa comment nếu tên property đổi theo (mặc định không đổi — xem §2) |
| `tests/e2e/readonly/smoke.spec.ts` | Test đọc | [CẦN XÁC NHẬN: kiểm tra xem test có assert đúng chuỗi tên không — nếu có thì cập nhật chuỗi kỳ vọng theo tên mới] |
| `playwright.config.ts` (dòng 11) | Comment nhắc `SONHOIAN` | Không đổi (mã không đổi) |
| `docs/sample-data/seed-sample-data.sql` | Docs seed (ghi tên bằng chữ) | Cập nhật chữ trong docs cho đúng thực tế |
| `docs/sample-data/recipes-import-DRAFT.sql` | Nháp công thức (V2) | Cập nhật chữ trong header nếu tên property đổi |
| `~/workspace/manual-admin-setup.sql` | Script tạo org/pháp nhân mẫu (dùng placeholder `__PROP_NAME__`) | Không đổi — template đã dùng placeholder sẵn |

## 5. Checklist trước khi Duy đưa tên thật

- [ ] Tên pháp nhân thật (đúng từng chữ, đúng dấu, đúng như trên giấy phép ĐKKD)
- [ ] Quyết định: chỉ đổi `legal_entities.name` hay đổi cả 3 bảng (§2)
- [ ] Quyết định: có đổi mã `SONHOIAN` không (mặc định: không)
- [ ] Đã chạy Bước 0 (§1) và UUID khớp
- [ ] Sau khi chạy: đã kiểm chứng §3 (ít nhất màn tổng quan + 1 chứng từ)
