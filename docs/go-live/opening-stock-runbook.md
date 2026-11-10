# Runbook tồn kho đầu kỳ (cutover) — kiểm đếm thật

> **Trạng thái:** BẢN NHÁP chuẩn bị cho go-live. Chưa chạy, chưa chốt.
> Cần Duy chốt **Q157** (giữ luồng kiểm đếm ngày chuyển đổi hay cho phép nhập
> tồn đầu từ số liệu lịch sử) trước khi làm. Các câu hỏi mở liên quan:
> Q31 (không có đường từ chối điều chỉnh), Q35 (ai được khóa ngày),
> Q36 (mã lý do chênh lệch), Q37 (đợt đã `locked` chưa điều chỉnh không
> hủy được), Q38 (người khóa/duyệt không xem được chênh lệch).
> Nguồn: `docs/05-BUSINESS-RULES.md`, T-032 (migration 280000),
> T-033 (migration 290000), `docs/sample-data/README.md` §6–§7, Q157.

## 0. Nguyên tắc (không thỏa hiệp)

1. **Tồn đầu kỳ CHỈ lấy bằng kiểm đếm thật ngày chuyển đổi.** File seed
   `docs/sample-data/seed-sample-data.sql` cố ý ghi **0 `stock_moves`**
   (kiểm chứng §7.7 = 0) — không seed tồn kho, không bịa chứng từ nhập/xuất.
   Mọi thay đổi tồn kho và tiền đi qua RPC `post` trong Postgres
   (AGENTS.md quy tắc 1); **không ai INSERT trực tiếp vào `stock_moves`**,
   `stock_balances`, `item_costs`.
2. **Số tồn cuối 11/2019 trong README chỉ để tham khảo khi kiểm đếm:**
   Larue 24, Tiger 18, Coca-Cola 13, Diet Coke 22, Lavie 17, Sprite 18.
   Các số này đã **7 năm tuổi — tuyệt đối không dùng làm tồn đầu kỳ** (Q157).
3. **Đếm mù:** người đếm không đọc được tồn lý thuyết (`book_qty`) —
   view `v_count_sheet` chỉ hiện vật tư của người đếm, không hiện số sách.
   Kho đang kiểm kê bị đóng băng: mọi ghi tồn vào kho đó chặn bằng
   `ERR_COUNT_FREEZE` (trigger `trg_stock_moves_count_freeze`, T-032).
4. **Sổ cái bất biến:** bút toán điều chỉnh sai không xóa — làm phiếu kiểm
   đếm đảo ngược / điều chỉnh mới.

## 1. Chuẩn bị trước cutover

| Hạng mục | Nội dung | Chủ sở hữu |
|---|---|---|
| Danh mục đã seed | 668 items (TP 409, CCDC 235, MB 7, AMN 11, CPM 1, KHAC 5) đã kiểm chứng §7 | Đã xong 10/11 |
| Danh sách kho | Liệt kê mọi kho của SONHOIAN (kho chính, kho tầng, kho phòng minibar `minibar_room`, kho bếp) — mọi kho đều phải có đợt `monthly_full`, kể cả kho trống (ghi 0) | Thủ kho |
| Người đếm + PIN | Mỗi kho 2 người đếm trở lên; mỗi người có PIN đếm riêng (PIN 4–6 số, đặt qua admin — xem màn `/admin/users/[id]/access`); phân ca đếm, tránh 1 người đếm 2 lần cùng kho | GM + thủ kho |
| Quyền (seed migration 141000) | `count.open` + `count.perform`: storekeeper (chef, bartender cũng có `count.perform`); `count.lock`: accountant; `count.adjust.approve`: gm; `count.view_variance`: cost_controller; `period.close` / `period.reopen`: chief_accountant | Đã seed |
| Thiết bị | Điện thoại đã cài PWA (màn `/m/<property>/count` làm việc offline, đồng bộ khi có mạng) hoặc máy tính màn đếm desktop | Nhân viên |
| Lịch | Chốt ngày cutover (ngày D) + giờ đóng băng kho (ngừng nhận/xuất trước giờ đếm) | Duy + GM |

> [CẦN XÁC NHẬN — Q35] Seed hiện chỉ gán `day.lock` cho `accountant`
> (05 §10 nói "gm hoặc kế toán"). Nếu GM cần khóa ngày trong ngày cutover
> thì Duy chốt trước, không tự đổi seed trong lúc chạy.

## 2. Quy trình từng bước (mỗi kho làm riêng, làm hết kho mới khóa kỳ)

### Bước 1 — Mở đợt kiểm đếm tháng (`count_open`)

- Thủ kho (quyền `count.open`) mở đợt `kind = 'monthly_full'`,
  `business_date` = ngày D, cho từng kho.
- RPC: `count_open(p_warehouse_id, 'monthly_full', p_business_date, null,
  p_counter_ids)` — `p_counter_ids` là danh sách người đếm của đợt.
- Đợt ở trạng thái `open` → `counting`. Kho bắt đầu bị đóng băng
  (`ERR_COUNT_FREEZE` cho mọi ghi tồn khác vào kho này).
- Minibar: kiểm từng phòng, ghi vào kho `minibar_room` tương ứng
  (mỗi phòng là 1 kho `minibar_room`, xem T-035 fix 460000).

### Bước 2 — Đếm mù 2 người (mobile hoặc desktop)

- Mỗi người đếm mở phiếu đếm của mình (`v_count_sheet` — chỉ thấy vật tư
  mình được giao, **không** thấy số sách, không thấy số người kia đếm).
- Ghi số đếm thật qua RPC `count_record_line` (ghi offline được qua Dexie
  kind `count_record`, đồng bộ khi có mạng; **submit chỉ làm online**).
- Đếm lại khi 2 người lệch nhau: đợt chuyển sang `recount`, thêm người đếm
  bằng `count_add_counter` (quyền `count.open`).
- Mở nhầm / bỏ đợt: `count_cancel` (chỉ trước khi `locked`, cần lý do).

### Bước 3 — Nộp đợt (`count_submit`, 2 PIN)

- RPC: `count_submit(p_count_id, p_pins text[])` — mảng PIN của **2 người
  đếm** (vd. `array['1111','2222']`). 1 người không nộp được; PIN sai bị
  chặn (SoD: người tạo đợt không tự duyệt — xem T-020/T-032).
- Đợt chuyển sang `submitted`.

### Bước 4 — Khóa đợt (`count_lock`)

- Kế toán (quyền `count.lock`) khóa đợt: `count_lock(p_count_id,
  p_reasons jsonb)` — `p_reasons` là lý do chênh lệch theo từng dòng
  (dạng JSON).
- Đợt chuyển sang `locked`. Từ đây **không hủy/quay lại được** (Q37 mở —
  chưa có đường hủy đợt đã `locked` chưa điều chỉnh; nếu phát hiện sai sau
  khi khóa thì xử lý bằng đợt điều chỉnh mới, không xóa).

> [CẦN XÁC NHẬN — Q36] 05 §6.2 liệt kê 5 mã lý do chênh lệch cho kiểm kê
> theo ca (`short`, `over`, `damaged`, `expired`, `theft`) nhưng chưa có
> danh sách chuẩn cho kiểm kê tháng. Trước cutover, Duy/GM chốt bộ mã lý
> do dùng chung cho `p_reasons`, không tự chế mã trong lúc đếm.

### Bước 5 — Duyệt điều chỉnh, ghi sổ (`count_adjust_post`)

- GM (quyền `count.adjust.approve`) duyệt: `count_adjust_post(p_count_id)`.
- Hệ thống sinh bút toán `adjust_count` cho từng dòng chênh lệch
  (migration 280000:1329, ghi theo giá trung bình `moving_avg`) và chuyển
  đợt sang `adjusted`.
- **Không có đường từ chối điều chỉnh** (Q31 mở): GM chỉ có "duyệt là ghi
  sổ ngay". Nếu số chênh lệch sai thì KHÔNG bấm duyệt — quay lại Bước 2
  (đếm lại trước khi khóa) hoặc mở đợt điều chỉnh mới sau khi khóa.
- Sau bước này, tồn kho của đợt kiểm đếm **chính là tồn đầu kỳ**.
  Q157 gọi bút toán này ở cutover là "post dạng `opening`" — đối chiếu:
  `count_adjust_post` ghi `move_type = 'adjust_count'` (280000:1329).
  Nếu Duy muốn loại move riêng tên `opening` cho cutover thì đó là task
  code (không phải runbook) — ghi rõ trước khi chạy.

### Bước 6 — Kiểm chứng (chỉ đọc, xem §3)

- Đối chiếu `v_count_result` với số đếm tay; kiểm tra mọi kho đều
  `locked`/`adjusted`; kiểm tra `stock_moves` đã phát sinh đúng số dòng.
- Kho nào chưa `locked`/`adjusted` thì **không được khóa kỳ** (Bước 7 sẽ
  chặn bằng `ERR_COUNT_NOT_LOCKED`).

### Bước 7 — Khóa kỳ (`period_close`)

- Kế toán trưởng (quyền `period.close`) gọi
  `period_close(p_legal_entity_id, p_year, p_month)`.
- Điều kiện bắt buộc (migration 280000:1477, 05 §10):
  1. Mọi kho của pháp nhân tồn tại trong tháng đều có đợt `monthly_full`
     ở `locked`/`adjusted` — thiếu 1 kho là chặn `ERR_COUNT_NOT_LOCKED`.
  2. Không có PO `partially_received` quá 30 ngày chưa xử lý
     (`ERR_PO_UNRESOLVED`, Q29).
  3. Không có tạm ứng quá hạn (`ERR_ADVANCE_OVERDUE`).
  4. Kỳ chưa khóa rồi (`ERR_PERIOD_ALREADY_CLOSED` nếu khóa lại).
- Khóa kỳ xong mới được xuất file kế toán (T-043 chỉ xuất kỳ/ngày đã khóa)
  và báo cáo tháng mới tin được.
- Mở lại kỳ (nếu sai sót sau khóa): `period_reopen` — chỉ kế toán trưởng
  (quyền `period.reopen`, Q30 mở về điều kiện mở lại).

## 3. Câu SQL kiểm chứng (CHỈ ĐỌC — chạy trên SQL Editor, không ghi)

```sql
-- 3.1 Mọi kho đã có đợt monthly_full tháng cutover ở locked/adjusted chưa?
select w.code as kho, c.kind, c.status, c.business_date
from public.warehouses w
left join public.stock_counts c
  on c.warehouse_id = w.id and c.kind = 'monthly_full'
  and extract(year from c.business_date) = 2026
  and extract(month from c.business_date) = 11
where w.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b'
order by w.code;
-- Kỳ vọng: mỗi kho 1 dòng, status in ('locked','adjusted'), không có NULL.

-- 3.2 Chênh lệch theo đợt (cần quyền count.view_variance)
select count_id, item_id, book_qty, counted_qty, variance_qty
from public.v_count_result
where business_date = '2026-11-30'  -- [CẦN XÁC NHẬN: ngày cutover thật]
order by abs(variance_qty) desc;

-- 3.3 Tồn sau kiểm đếm (đối chiếu tay với số đếm)
select w.code as kho, count(*) as so_dong_ton
from public.stock_balances b
join public.warehouses w on w.id = b.warehouse_id
where w.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b'
group by w.code;

-- 3.4 Không còn PO quá hạn / tạm ứng quá hạn trước khi khóa kỳ
select count(*) as po_qua_han
from public.purchase_orders po
where po.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b'
  and po.status = 'partially_received'
  and po.expected_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date - interval '30 days';
select count(*) as tam_ung_qua_han
from public.advances a
where a.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b'
  and a.status = 'overdue';
-- Kỳ vọng: cả hai đều 0.
```

## 4. Xử lý chênh lệch và sai sót

| Tình huống | Cách xử lý |
|---|---|
| 2 người đếm lệch nhau | Đợt sang `recount`; thêm người đếm (`count_add_counter`) hoặc đếm lại; không tự sửa số của người kia |
| Phát hiện sai trước khi khóa | Đếm lại (Bước 2); mở nhầm thì `count_cancel` (cần lý do, chỉ trước `locked`) |
| Phát hiện sai sau khi khóa, trước duyệt | [CẦN XÁC NHẬN — Q37] Chưa có đường hủy/quay lại đợt đã `locked`. Tạm thời: không duyệt vội; mở đợt điều chỉnh mới sau khi duyệt đợt cũ, ghi rõ lý do |
| GM thấy số chênh lệch sai | Không bấm duyệt (Q31: không có nút từ chối — bấm duyệt là ghi sổ ngay). Dừng lại, báo lại cho đội đếm |
| Người khóa/duyệt cần xem chênh lệch | [CẦN XÁC NHẬN — Q38] `count.view_variance` hiện chỉ gán `cost_controller`; accountant (khóa) và gm (duyệt) không có quyền xem `v_count_result`. Duy chốt có cấp thêm không trước cutover |
| Kho bị đóng băng giữa ca | Kiểm tra có đợt kiểm đếm đang mở ở kho đó không; xong đợt thì băng tự gỡ khi `locked`/`adjusted` |

## 5. Minibar — tồn đầu kỳ theo phòng

- Kiểm từng phòng (màn minibar buồng phòng / lễ tân): đếm thực tế từng
  món trong tủ phòng, đối chiếu giá đang hiệu lực (lưu ý: giá minibar
  trong seed đã hết hạn 11/2019 — **7 món minibar hiện chưa có giá bán**,
  phải nhập giá hiện hành trước khi bán, không liên quan tồn đầu kỳ).
- Ghi `opening` vào kho `minibar_room` của từng phòng (Q157).
- Tồn cuối 11/2019 (Larue 24, Tiger 18, Coca 13, Diet Coke 22, Lavie 17,
  Sprite 18) chỉ dùng để tham khảo khi đếm, không nhập làm tồn đầu.

## 6. Checklist ký xác nhận (in ra, ký tay ngày cutover)

- [ ] Mọi kho đã có đợt `monthly_full` ở `locked`/`adjusted` (§3.1 đủ dòng, không NULL)
- [ ] `v_count_result` đã đối chiếu xong, chênh lệch lớn đã có lý do (Q36)
- [ ] `stock_moves` phát sinh đúng số đợt (không có move lạ ngoài `adjust_count`)
- [ ] PO quá hạn = 0, tạm ứng quá hạn = 0 (§3.4)
- [ ] `period_close` chạy thành công, kỳ đã `closed`
- [ ] Minibar từng phòng đã kiểm xong, kho `minibar_room` đủ số
- [ ] Người xác nhận: Thủ kho ________  Kế toán ________  GM ________
      Ngày: ________

## 7. Những gì cần Duy chốt trước ngày cutover

1. **Q157** — Giữ luồng kiểm đếm ngày chuyển đổi (khuyến nghị, đúng docs/07
   §4) hay cho nhập tồn đầu từ số liệu lịch sử? Nếu nhập từ lịch sử thì
   cần task riêng + cơ chế `opening` qua RPC (không insert trực tiếp).
2. **Q31** — Có cần nút "từ chối điều chỉnh" cho GM không, hay giữ nguyên
   (duyệt là ghi sổ)?
3. **Q35** — GM có được khóa ngày (`day.lock`) trong ngày cutover không?
4. **Q38** — Có cấp `count.view_variance` thêm cho accountant + gm không?
5. **Q36** — Bộ mã lý do chênh lệch dùng chung cho kiểm kê tháng.
6. **Q37** — Đường hủy/quay lại đợt đã `locked` chưa điều chỉnh (hay chấp
   nhận xử lý bằng đợt mới)?
7. Ngày cutover chính thức + giờ đóng băng kho.
