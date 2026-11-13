# Hướng dẫn UAT theo vai trò — ERP_hotel (khách sạn TEST47)

> **Dành cho người thử hệ thống (không cần rành kỹ thuật).** Đọc phần 1 trước, rồi làm
> đúng phần của vai trò mình. Mỗi kịch bản đều có đường dẫn màn hình thật, các bước cụ thể,
> kết quả mong đợi và chỗ điền kết quả.
>
> **Phạm vi:** chỉ khách sạn thử nghiệm **TEST47**. Tuyệt đối không thử trên khách sạn thật
> (Son Hoi An). Các tài khoản UAT tự hết hạn ngày **26/11/2026**.
>
> **Nguồn sự thật:** danh sách vai trò và quyền lấy từ `supabase/seed.sql` (bảng mẫu vai trò)
> + migration 565000 (`admin.health.view`: sys_admin, owner) + migration 567000
> (`pos.import`: gm, chief_accountant, accountant, cost_controller). Đường dẫn màn hình đã
> đối chiếu với code trong `src/app/`. Nếu một bước bị chặn vì thiếu quyền trên production
> (quyền thật có thể khác bảng mẫu), ghi vào cột **Ghi chú** kèm mã quyền thiếu — đó cũng là
> một kết quả thử có giá trị, không phải lỗi của người thử.

> **Lưu ý đường dẫn:** app dùng **mã định danh (UUID) của khách sạn** trong URL. Khách sạn TEST47 = `b0000000-0000-4000-8000-000000000002`; mọi đường dẫn bên dưới đã ghi sẵn theo dạng đó (ví dụ `/b0000000-0000-4000-8000-000000000002/procurement/pr`). Dạng `/TEST47/...` sẽ báo 404.

## 1. Cách đăng nhập và ghi kết quả

### 1.1. Đăng nhập

1. Mở trang đăng nhập của hệ thống.
2. Nhập email dạng `uat.<mã vai trò>@erp.internal` (ví dụ `uat.gm@erp.internal`).
   **Mật khẩu do Duy cấp riêng cho từng người — không có trong tài liệu này.**
3. Sau khi đăng nhập, chỉ chọn khách sạn **TEST47**. Nếu thấy thêm khách sạn khác, dừng lại
   và báo ngay cho Duy.
4. **Lưu ý menu sau khi đăng nhập:** vừa đăng nhập xong, menu trái có thể hiện bộ mục của
   tài khoản đăng nhập trước đó (lỗi hiển thị đã ghi nhận, M9). Chuyển sang một trang khác,
   menu sẽ hiện đúng bộ mục của bạn. Các mục lạ chỉ hiện tên — đừng bấm vào, bấm vào sẽ bị chặn.
4. Nếu hệ thống hỏi **mã PIN** (khi nhận hàng, đăng phiếu, kiểm kê…), dùng mã PIN Duy đã cấp
   cho vai trò của mình. Không đoán PIN.

### 1.2. Cách ghi kết quả

- Mỗi kịch bản có 3 cột: **Đạt** (làm đúng như mong đợi), **Không đạt** (lệch khỏi mong đợi
  hoặc báo lỗi), **Ghi chú** (ghi rõ bước nào, thông báo lỗi hiện ra sao, chụp màn hình nếu có).
- Nếu một kịch bản **không thử được** vì thiếu dữ liệu đầu vào (ví dụ chưa có phòng, chưa có
  phiếu), đánh dấu **Không đạt** và ghi rõ "Chưa thử được vì …" ở cột Ghi chú — đừng bỏ trống.
- Một số nút (ví dụ "Gửi duyệt", "Gửi cho nhà cung cấp") hiện hộp thoại xác nhận của trình
  duyệt: bấm **OK** để tiếp tục.
- Ghi ngày thử và tên người thử ở đầu mỗi phần vai trò.

### 1.3. Dữ liệu thử có sẵn trên TEST47 (để biết trước)

- Nhà cung cấp: **NCC-T047**. Kho chính: **KHO-T047**. Kho minibar: **MINIBAR_MAIN**.
- Phòng: TEST47 có **30 phòng demo** (3 loại phòng, 2 xe đẩy) — lễ tân thấy 8 phòng
  101–306 ở màn Minibar, buồng phòng thấy đủ 30 phòng theo tầng (đã kiểm chứng M9, tối 13/11).
- Giá minibar: **7 món có giá hiện hành** (hiệu lực từ 11/11): Bia Tiger 35.000đ, Diet Coke
  25.000đ, Nước suối Lavie 15.000đ, Sprite 25.000đ, Coca-Cola 25.000đ, Rượu vang 245.000đ,
  Bia Larue 25.000đ (đã kiểm chứng M9, tối 13/11).
- Mã vật tư dùng trong ví dụ: **NVL0388** (kg), **NVL0561** (cái). Mã món minibar ví dụ: **MON01**.
- File POS mẫu (GIẢ LẬP, chỉ để thử thao tác): `docs/samples/pos-export-sample-SYNTHETIC.csv`.
  File POS thật sẽ có tên cột khác — màn nạp file có bước ánh xạ cột, cứ làm theo hướng dẫn
  trên màn hình.

## 2. Tài khoản UAT (16 vai trò)

| # | Email | Vai trò | Làm gì chính |
|---|-------|---------|--------------|
| 1 | `uat.owner@erp.internal` | Chủ đầu tư | Duyệt PO giá trị lớn, đóng PO, xem báo cáo và sức khỏe hệ thống |
| 2 | `uat.gm@erp.internal` | Tổng quản lý | Duyệt PO vượt trần, duyệt điều chỉnh kiểm kê, duyệt tạm ứng, duyệt miễn minibar |
| 3 | `uat.chief_accountant@erp.internal` | Kế toán trưởng chuỗi | Duyệt hóa đơn/thanh toán/NCC, quản lý giá trần, xem báo cáo |
| 4 | `uat.accountant@erp.internal` | Kế toán khách sạn | Nhập hóa đơn, đề nghị thanh toán, giải ngân/quyết toán tạm ứng |
| 5 | `uat.cost_controller@erp.internal` | Cost Controller | Duyệt PO, xem chênh lệch kiểm kê, xem lại ảnh nhận hàng, duyệt hủy |
| 6 | `uat.purchaser@erp.internal` | Thu mua | Tạo PR, tạo PO (kể cả PO chợ), quản lý NCC và hợp đồng khung |
| 7 | `uat.storekeeper@erp.internal` | Thủ kho | Nhận hàng, đăng phiếu, kiểm kê, xuất lĩnh, điều chuyển, trả hàng |
| 8 | `uat.receiver@erp.internal` | Nhận hàng ca sáng | Nhận hàng mù (không thấy số lượng PO và giá) |
| 9 | `uat.outlet_head@erp.internal` | Trưởng bộ phận | Duyệt PR, duyệt phiếu lĩnh, đề xuất hủy hàng |
| 10 | `uat.chef@erp.internal` | Bếp trưởng / Bếp | Duyệt PR, tạo phiếu lĩnh, đếm kiểm kê |
| 11 | `uat.bartender@erp.internal` | Bartender | Đếm kiểm kê đồ uống |
| 12 | `uat.hk_supervisor@erp.internal` | Giám sát buồng | Xe đẩy, bổ sung minibar, quản lý phòng, duyệt phiếu lĩnh |
| 13 | `uat.hk_attendant@erp.internal` | Nhân viên buồng | Xe đẩy, kiểm minibar (kể cả offline) |
| 14 | `uat.front_desk@erp.internal` | Lễ tân | Yêu cầu kiểm minibar, xác nhận thu tiền, nhập số liệu PMS ngày |
| 15 | `uat.engineer@erp.internal` | Kỹ thuật | Lĩnh vật tư, nghiệm thu dịch vụ |
| 16 | `uat.internal_audit@erp.internal` | Kiểm soát nội bộ | Chỉ xem: nhật ký audit và báo cáo (không sửa được dữ liệu) |

> Không có tài khoản `uat.sys_admin` — vai trò quản trị hệ thống không đưa vào UAT.
> Mật khẩu/PIN không ghi trong tài liệu này.
>
> **Đã kiểm chứng ma trận quyền (M9, tối 13/11):** 9/16 tài khoản đã được mở thử từng màn
> (owner, gm, accountant, purchaser, chef, hk_supervisor, front_desk, receiver,
> storekeeper) — 180 lượt mở, không lỗi 500, nhận hàng mù đạt. 7 tài khoản còn lại
> (chief_accountant, cost_controller, outlet_head, bartender, hk_attendant, engineer,
> internal_audit) chưa được kiểm tra theo ma trận trong đợt này; kịch bản của họ dưới
> đây dựa trên quyền trong seed/migration, cần ghi lại kết quả thật khi thử.

---

## 3. Kịch bản theo vai trò

> Quy ước đường dẫn: `/b0000000-0000-4000-8000-000000000002/...` là màn hình máy tính; `/m/b0000000-0000-4000-8000-000000000002/...` là màn hình điện
> thoại (mở bằng trình duyệt điện thoại). `TEST47` là mã khách sạn thử nghiệm trong đường dẫn.

### 3.1. Chủ đầu tư — `uat.owner@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Duyệt PO giá trị lớn | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` | 1. Mở danh sách chờ duyệt. 2. Mở một PO trên 100 triệu. 3. Xem đủ thông tin (NCC, mặt hàng, tổng tiền, lịch sử duyệt). 4. Bấm **Duyệt**. | PO chuyển sang trạng thái đã duyệt, có ghi tên người duyệt. | ☐ | ☐ | |
| 2 | Đóng PO đã nhận đủ | `/b0000000-0000-4000-8000-000000000002/procurement/po` | 1. Mở một PO đã nhận đủ hàng. 2. Bấm **Đóng PO**. | PO chuyển sang trạng thái đã đóng, không tạo thêm phiếu nhận được nữa. | ☐ | ☐ | |
| 3 | Xem báo cáo tổng | `/b0000000-0000-4000-8000-000000000002/reports` | 1. Mở danh sách báo cáo. 2. Mở báo cáo tồn kho và báo cáo công nợ. | Báo cáo hiển thị đúng số liệu của TEST47, không lẫn khách sạn khác. | ☐ | ☐ | |
| 4 | Xem sức khỏe hệ thống | `/admin/health` | 1. Mở màn hình. 2. Kiểm tra trạng thái cron, hàng đợi thông báo, cảnh báo đỏ, dung lượng DB. | Màn hình hiển thị trạng thái **Ổn** hoặc **Cần xem** rõ ràng; số liệu có giá trị thật (không phải số 0 giả). | ☐ | ☐ | |
| 5 | Kiểm tra nhật ký audit tăng sau khi duyệt | `/admin/health` | 1. Trước khi duyệt PO ở kịch bản 1, mở màn hình này và ghi lại số dòng nhật ký audit. 2. Duyệt PO xong, mở lại màn hình. 3. So sánh số dòng. | Số dòng nhật ký audit tăng lên sau thao tác duyệt (app hiện chưa có màn hình xem chi tiết từng dòng nhật ký — chỉ xem được tổng số dòng ở đây). | ☐ | ☐ | |

### 3.2. Tổng quản lý — `uat.gm@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Duyệt PO vượt trần / giá tay | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` | 1. Mở PO có dòng vượt giá trần hoặc giá nhập tay. 2. Xem cảnh báo vượt trần. 3. Bấm **Duyệt**. | Hệ thống cho duyệt và ghi rõ đây là bước duyệt vượt trần của GM. | ☐ | ☐ | |
| 2 | Duyệt điều chỉnh kiểm kê | `/b0000000-0000-4000-8000-000000000002/inventory/counts` | 1. Mở một đợt kiểm kê đã đếm xong, có chênh lệch. 2. Xem chênh lệch từng mã. 3. Bấm **Duyệt điều chỉnh**. | Tồn kho cập nhật theo số đếm đã duyệt; có nhật ký. | ☐ | ☐ | |
| 3 | Duyệt tạm ứng | `/b0000000-0000-4000-8000-000000000002/finance/advances` | 1. Mở một đề nghị tạm ứng đang chờ. 2. Xem số tiền, lý do, người đề nghị. 3. Bấm **Duyệt**. | Tạm ứng chuyển sang đã duyệt, chờ kế toán giải ngân. | ☐ | ☐ | |
| 4 | Duyệt miễn tiền minibar | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` | 1. Mở một phiếu minibar có đề nghị miễn tiền. 2. Xem lý do miễn. 3. Bấm **Duyệt miễn**. | Phiếu minibar ghi đã miễn, không còn thu tiền món đó. | ☐ | ☐ | |
| 5 | Nạp file POS của ca | `/b0000000-0000-4000-8000-000000000002/inventory/pos-import` | 1. Chọn file POS mẫu. 2. Ánh xạ cột theo hướng dẫn trên màn hình. 3. Xem trước 20 dòng rồi bấm **Nạp**. | File nạp thành công, báo đúng số dòng; nạp lại cùng file thì báo đã nạp rồi. | ☐ | ☐ | |
| 6 | Xem bản tin buổi sáng | `/b0000000-0000-4000-8000-000000000002/reports` | 1. Mở báo cáo bản tin ngày. 2. Kiểm tra các mục: tồn kho, PO chờ duyệt, cảnh báo. | Bản tin hiển thị đủ mục, số liệu khớp với màn hình gốc. | ☐ | ☐ | |

### 3.3. Kế toán trưởng chuỗi — `uat.chief_accountant@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Duyệt hóa đơn NCC | `/b0000000-0000-4000-8000-000000000002/finance/invoices` | 1. Mở hóa đơn đang chờ duyệt. 2. Đối chiếu số tiền với PO/phiếu nhận. 3. Bấm **Duyệt**. | Hóa đơn chuyển sang đã duyệt, công nợ tăng đúng số tiền. | ☐ | ☐ | |
| 2 | Duyệt đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` | 1. Mở đề nghị đang chờ. 2. Kiểm tra số tiền và chứng từ. 3. Bấm **Duyệt**. | Đề nghị chuyển sang đã duyệt, chờ kế toán đánh dấu đã trả. | ☐ | ☐ | |
| 3 | Duyệt nhà cung cấp mới | `/b0000000-0000-4000-8000-000000000002/master/suppliers` | 1. Mở NCC đang chờ duyệt. 2. Kiểm tra thông tin, tài khoản ngân hàng. 3. Bấm **Duyệt**. | NCC chuyển sang hoạt động, dùng được khi tạo PO. | ☐ | ☐ | |
| 4 | Quản lý giá trần | `/b0000000-0000-4000-8000-000000000002/master/prices` | 1. Mở giá trần của một mã vật tư. 2. Sửa giá trần và ngày hiệu lực. 3. Lưu. | Giá trần mới được lưu và áp dụng cho PO tạo sau đó. | ☐ | ☐ | |
| 5 | Xem báo cáo công nợ | `/b0000000-0000-4000-8000-000000000002/reports` | 1. Mở báo cáo công nợ phải trả. 2. Lọc theo NCC-T047. | Số công nợ khớp với hóa đơn đã duyệt ở kịch bản 1. | ☐ | ☐ | |
| 6 | Nạp file POS của ca | `/b0000000-0000-4000-8000-000000000002/inventory/pos-import` | Làm như kịch bản 5 của GM. | Như kịch bản 5 của GM. | ☐ | ☐ | |

> **Lưu ý bước duyệt hóa đơn/thanh toán (Q263):** theo demo-walkthrough 13/11, bước duyệt
> hóa đơn giao cho **Quản lý**, bước duyệt thanh toán giao cho **Quản lý hoặc Chủ đầu tư**.
> Tài khoản này giữ vai trò cũ nên vẫn còn quyền duyệt cũ — khi thử, nếu duyệt được thì ghi
> Đạt, nếu màn Chờ duyệt trống hoặc bị chặn thì ghi lại kết quả (không tính là lỗi của người
> thử); Duy sẽ chốt người duyệt cuối theo mô hình gọn.

### 3.4. Kế toán khách sạn — `uat.accountant@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Nhập hóa đơn NCC | `/b0000000-0000-4000-8000-000000000002/finance/invoices/new` | 1. Chọn NCC-T047 và PO đã nhận hàng. 2. Nhập số hóa đơn, ngày, số tiền. 3. Lưu. | Hóa đơn được tạo ở trạng thái chờ duyệt, khớp 3 chiều với PO và phiếu nhận. **Lưu ý 13/11: chạy thử thì màn này bị chặn với thông báo thiếu quyền dù vai trò có quyền nhập hóa đơn — nếu vẫn bị chặn, ghi Không đạt + thông báo nguyên văn (đang chờ kiểm tra lại, M1).** | ☐ | ☐ | |
| 2 | Tạo đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests/new` | 1. Chọn hóa đơn đã duyệt. 2. Nhập số tiền đề nghị. 3. Gửi. | Đề nghị được tạo ở trạng thái chờ duyệt. | ☐ | ☐ | |
| 3 | Đánh dấu đã thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` | 1. Mở đề nghị đã duyệt. 2. Bấm **Đánh dấu đã trả** và nhập ngày trả. | Đề nghị chuyển sang đã trả, công nợ giảm đúng số tiền. | ☐ | ☐ | |
| 4 | Giải ngân tạm ứng | `/b0000000-0000-4000-8000-000000000002/finance/advances` | 1. Mở tạm ứng đã duyệt. 2. Bấm **Giải ngân**, nhập số tiền thực chi. | Tạm ứng chuyển sang đã giải ngân. | ☐ | ☐ | |
| 5 | Quyết toán tạm ứng | `/b0000000-0000-4000-8000-000000000002/finance/advances` | 1. Mở tạm ứng đã giải ngân. 2. Nhập chứng từ quyết toán. 3. Bấm **Quyết toán**. | Tạm ứng chuyển sang đã quyết toán; số thừa/thiếu (nếu có) được ghi rõ. | ☐ | ☐ | |
| 6 | Nạp file POS của ca | `/b0000000-0000-4000-8000-000000000002/inventory/pos-import` | Làm như kịch bản 5 của GM. | Như kịch bản 5 của GM. | ☐ | ☐ | |

### 3.5. Cost Controller — `uat.cost_controller@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Kiểm tra bước duyệt PO theo mô hình mới | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` | 1. Mở màn Chờ duyệt. 2. Ghi lại PO nào hiện ra cho vai trò này (nếu có). | **Mô hình duyệt PO đã đổi (Q260/Q263): 2 bậc Quản lý (từ 0 đ) + Chủ đầu tư (từ 100 triệu); ngưỡng 10–20 triệu cũ không còn đúng.** Nếu không có PO nào chờ bạn duyệt thì ghi Đạt với ghi chú đó; nếu có PO chờ duyệt thì duyệt theo giá trần/hợp đồng như trước. | ☐ | ☐ | |
| 2 | Xem chênh lệch kiểm kê | `/b0000000-0000-4000-8000-000000000002/inventory/counts` | 1. Mở đợt kiểm kê đã đếm xong. 2. Xem cột chênh lệch và giá trị chênh lệch. | Thấy rõ mã nào thừa/thiếu, số lượng và giá trị; mã không chênh lệch không hiện cảnh báo. | ☐ | ☐ | |
| 3 | Xem lại ảnh nhận hàng | `/b0000000-0000-4000-8000-000000000002/receiving/review` | 1. Mở một phiếu nhận có ảnh đính kèm. 2. Xem ảnh chụp hàng và cân. | Ảnh hiển thị rõ, đúng phiếu nhận; có cảnh báo nếu ảnh bị dùng lại ở phiếu khác. | ☐ | ☐ | |
| 4 | Duyệt đề xuất hủy hàng | `/b0000000-0000-4000-8000-000000000002/inventory/waste` | 1. Mở đề xuất hủy đang chờ. 2. Xem lý do, số lượng, giá trị. 3. Bấm **Duyệt**. | Hàng hủy được ghi giảm tồn kho, có nhật ký. | ☐ | ☐ | |
| 5 | Nạp file POS của ca | `/b0000000-0000-4000-8000-000000000002/inventory/pos-import` | Làm như kịch bản 5 của GM. | Như kịch bản 5 của GM. | ☐ | ☐ | |

### 3.6. Thu mua — `uat.purchaser@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Tạo phiếu yêu cầu mua (PR) | `/b0000000-0000-4000-8000-000000000002/procurement/pr/new` | 1. Chọn bộ phận và kho nhận. 2. Thêm dòng: NVL0388, số lượng 10 kg. 3. Lưu nháp rồi bấm **Gửi duyệt**. | PR được tạo, chuyển sang chờ duyệt; người tạo không tự duyệt được PR của mình. | ☐ | ☐ | |
| 2 | Tạo PO từ PR đã duyệt | `/b0000000-0000-4000-8000-000000000002/procurement/po` | 1. Mở PR đã duyệt ở kịch bản 1. 2. Tạo PO cho NCC-T047. 3. Kiểm tra giá dòng tự lấy theo hợp đồng/giá trần. 4. Gửi duyệt. | PO được tạo với giá đúng; đi đúng các bước duyệt theo giá trị. | ☐ | ☐ | |
| 3 | Tạo PO chợ + nhập tổng ước tính | `/b0000000-0000-4000-8000-000000000002/procurement/market/new` | 1. Tạo PO chợ cho NCC chợ. 2. Thêm dòng chưa có giá. 3. Nhập **tổng ước tính** rồi gửi duyệt. | Hệ thống bắt buộc nhập tổng ước tính trước khi gửi (không nhập thì báo lỗi, không cho gửi); sau khi nhập thì gửi được. **Lưu ý 13/11: ô tổng ước tính từ chối số tròn (ví dụ 500.000) — nhập lệch 1 đồng (500.001) thì qua; form Sửa nháp PO chợ không lưu được (bấm Lưu báo dữ liệu không hợp lệ, nội dung sửa bị hoàn lại) — đang chờ kiểm tra lại (M1).** | ☐ | ☐ | |
| 4 | Xem hợp đồng khung / giá trần | `/b0000000-0000-4000-8000-000000000002/master/prices` | 1. Mở giá của NVL0388. 2. Kiểm tra giá hợp đồng và giá trần. | Giá hiển thị đúng, có ngày hiệu lực. | ☐ | ☐ | |
| 5 | Tạo NCC mới | `/b0000000-0000-4000-8000-000000000002/master/suppliers` | 1. Thêm NCC mới (tên, mã số thuế, tài khoản ngân hàng). 2. Lưu và gửi duyệt. | NCC được tạo ở trạng thái chờ duyệt; chưa dùng được để tạo PO cho tới khi được duyệt. | ☐ | ☐ | |
| 6 | Gửi PO đã duyệt cho NCC | `/b0000000-0000-4000-8000-000000000002/procurement/po` | 1. Mở PO đã duyệt hết các bước. 2. Bấm **Gửi cho nhà cung cấp** (bấm OK ở hộp thoại xác nhận). | PO chuyển sang đã gửi; ngày giao dự kiến hiển thị đúng. | ☐ | ☐ | |

### 3.7. Thủ kho — `uat.storekeeper@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Nhận hàng mù (điện thoại) | `/m/b0000000-0000-4000-8000-000000000002/receive` | 1. Mở phiếu nhận của PO đã gửi. **Đừng mở lại PO đã có phiếu nháp — mỗi lần mở lại tạo thêm 1 phiếu nháp trùng; tìm phiếu nháp đang mở dở và làm tiếp.** 2. Cân và nhập số lượng thực nhận **không xem** số lượng PO. 3. Chụp ảnh hàng — **bắt buộc từng dòng, nút Ghi dòng chỉ bật khi đủ số cân và ảnh**. 4. Nhập mã PIN để xác nhận (mã PIN gồm đúng 6 số). | Phiếu nhận được ghi; màn hình không hiện số lượng PO hay giá trong lúc nhận. | ☐ | ☐ | |
| 2 | Đăng phiếu nhận (máy tính) | `/b0000000-0000-4000-8000-000000000002/receiving` | 1. Mở phiếu nhận vừa tạo. 2. Kiểm tra dòng hàng. 3. Bấm **Đăng phiếu** (nhập PIN nếu hỏi). **Chỉ người mở phiếu mới đăng được phiếu đó — nếu người mở phiếu từng duyệt PO này thì hệ thống chặn đăng (SoD); trường hợp đó bỏ phiếu nháp và mở lại bằng tài khoản khác chưa từng duyệt PO.** | Tồn kho tăng đúng số lượng đã nhận; phiếu không sửa được nữa sau khi đăng. | ☐ | ☐ | |
| 3 | Mở đợt kiểm kê + đếm mù | `/m/b0000000-0000-4000-8000-000000000002/count` | 1. Mở đợt kiểm kê đang mở. 2. Đếm mù: nhập số đếm thực tế, không thấy số tồn trên hệ thống. 3. Gửi kết quả đếm. | Số đếm được ghi; màn hình đếm không hiện tồn kho hệ thống. | ☐ | ☐ | |
| 4 | Xuất phiếu lĩnh cho bộ phận | `/b0000000-0000-4000-8000-000000000002/inventory/requisitions` | 1. Mở phiếu lĩnh đã duyệt. 2. Kiểm tra số lượng. 3. Bấm **Xuất kho**. | Tồn kho giảm đúng số lượng; phiếu chuyển sang đã xuất. | ☐ | ☐ | |
| 5 | Điều chuyển kho | `/b0000000-0000-4000-8000-000000000002/inventory/transfers` | 1. Tạo phiếu điều chuyển từ KHO-T047 sang kho minibar. 2. Kho nhận xác nhận. | Tồn kho kho nguồn giảm, kho đích tăng đúng số lượng. | ☐ | ☐ | |
| 6 | Trả hàng cho NCC | `/b0000000-0000-4000-8000-000000000002/receiving/returns` | 1. Tạo phiếu trả hàng từ một phiếu nhận có hàng lỗi. 2. Nhập lý do và số lượng. 3. Đăng phiếu trả. | Tồn kho giảm đúng số lượng trả; công nợ NCC giảm tương ứng. | ☐ | ☐ | |

### 3.8. Nhận hàng ca sáng — `uat.receiver@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Nhận hàng mù (điện thoại) | `/m/b0000000-0000-4000-8000-000000000002/receive` | 1. Mở phiếu nhận của PO đã gửi. 2. Cân 2 lần và nhập số lượng thực nhận. 3. Chụp ảnh hàng. | Phiếu nhận được ghi; số lượng 2 lần cân chênh nhau trong ngưỡng cho phép thì qua, vượt ngưỡng thì báo kiểm tra lại. | ☐ | ☐ | |
| 2 | Xem phiếu đã nhận | `/m/b0000000-0000-4000-8000-000000000002/receive` | 1. Mở danh sách chờ nhận trên mobile. 2. Mở phiếu mình vừa nhận. | Thấy được phiếu của mình; phiếu chưa đăng thì vẫn sửa được. **Lưu ý: đường máy tính `/receiving` trả 404 với vai trò này (M9) — chỉ xem phiếu qua màn mobile.** | ☐ | ☐ | |
| 3 | Kiểm tra không thấy giá/số PO | `/m/b0000000-0000-4000-8000-000000000002/receive` | 1. Mở lại màn hình nhận hàng của một PO chưa nhận. 2. Tìm số lượng PO và đơn giá trên màn hình. | **Không** thấy số lượng PO và đơn giá ở bất kỳ đâu trên màn hình nhận. | ☐ | ☐ | |
| 4 | Hàng lỗi: chụp ảnh + ghi chú | `/m/b0000000-0000-4000-8000-000000000002/receive` | 1. Nhận một mặt hàng có lỗi chất lượng. 2. Chụp ảnh lỗi, ghi chú rõ. 3. Gửi phiếu. | Phiếu nhận ghi rõ hàng lỗi kèm ảnh; thủ kho thấy được để làm phiếu trả hàng. | ☐ | ☐ | |

### 3.9. Trưởng bộ phận — `uat.outlet_head@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Tạo PR cho bộ phận và gửi duyệt | `/b0000000-0000-4000-8000-000000000002/procurement/pr/new` | 1. Tạo PR cho bộ phận mình. 2. Gửi duyệt. 3. Mở lại PR và thử bấm **Duyệt**. | PR được tạo và chờ duyệt. **Bước duyệt PR nay do Quản lý đảm nhiệm (Q263) — trưởng bộ phận chỉ đề xuất, không duyệt; nếu hệ thống cho bạn duyệt thì ghi lại (lệch mô hình mới).** | ☐ | ☐ | |
| 2 | Không tự duyệt PR mình tạo | `/b0000000-0000-4000-8000-000000000002/procurement/pr/new` | 1. Tự tạo một PR mới và gửi duyệt. 2. Mở lại PR đó và thử bấm **Duyệt**. | Hệ thống **chặn** (báo lỗi người tạo không được duyệt) — đây là kiểm soát bắt buộc. | ☐ | ☐ | |
| 3 | Tạo phiếu lĩnh cho bộ phận | `/b0000000-0000-4000-8000-000000000002/inventory/requisitions` | 1. Tạo phiếu lĩnh từ KHO-T047. 2. Thêm mặt hàng cần dùng. 3. Gửi duyệt. | Phiếu lĩnh được tạo ở trạng thái chờ duyệt. | ☐ | ☐ | |
| 4 | Xem phiếu lĩnh đã gửi | `/b0000000-0000-4000-8000-000000000002/inventory/requisitions` | 1. Mở phiếu lĩnh đang chờ duyệt. 2. Ghi lại ai là người duyệt theo màn hình. | **Bước duyệt phiếu lĩnh nay do Quản lý đảm nhiệm (Q263).** Phiếu lĩnh chờ Quản lý duyệt rồi mới tới thủ kho xuất. | ☐ | ☐ | |
| 5 | Đề xuất hủy hàng hỏng | `/b0000000-0000-4000-8000-000000000002/inventory/waste` | 1. Tạo đề xuất hủy: chọn mặt hàng, số lượng, lý do. 2. Gửi. | Đề xuất được tạo ở trạng thái chờ duyệt; tồn kho chưa giảm cho tới khi được duyệt. | ☐ | ☐ | |

### 3.10. Bếp trưởng / Bếp — `uat.chef@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Tạo PR cho bếp và gửi duyệt | `/b0000000-0000-4000-8000-000000000002/procurement/pr/new` | 1. Tạo PR nguyên liệu cho bếp. 2. Gửi duyệt. | PR được tạo và chờ duyệt. **Bước duyệt PR nay do Quản lý đảm nhiệm (Q263) — bếp chỉ đề xuất, không duyệt.** | ☐ | ☐ | |
| 2 | Tạo phiếu lĩnh nguyên liệu | `/b0000000-0000-4000-8000-000000000002/inventory/requisitions` | 1. Tạo phiếu lĩnh từ KHO-T047. 2. Thêm NVL0388 và NVL0561. 3. Gửi duyệt. | Phiếu lĩnh được tạo ở trạng thái chờ duyệt. | ☐ | ☐ | |
| 3 | Đếm kiểm kê khu bếp | `/m/b0000000-0000-4000-8000-000000000002/count` | 1. Mở đợt kiểm kê đang mở. 2. Đếm mù các mã khu bếp, gửi kết quả. | Số đếm được ghi; không thấy tồn hệ thống trong lúc đếm. | ☐ | ☐ | |
| 4 | Xem món và công thức | `/b0000000-0000-4000-8000-000000000002/restaurant/dishes` | 1. Mở danh sách món. 2. Mở một món, xem công thức và định lượng. | Món hiển thị đúng công thức; không sửa được nếu không có quyền. | ☐ | ☐ | |

### 3.11. Bartender — `uat.bartender@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Đếm kiểm kê đồ uống | `/m/b0000000-0000-4000-8000-000000000002/count` | 1. Mở đợt kiểm kê đang mở. 2. Đếm mù các mã đồ uống (nhóm RUOU), gửi kết quả. | Số đếm được ghi; không thấy tồn hệ thống trong lúc đếm. | ☐ | ☐ | |
| 2 | Xem danh sách đợt kiểm kê | `/b0000000-0000-4000-8000-000000000002/inventory/counts` | 1. Mở danh sách đợt kiểm kê. 2. Mở đợt đang đếm. | Thấy được đợt kiểm kê và tiến độ đếm của mình. | ☐ | ☐ | |
| 3 | Kiểm tra không sửa được giá/tồn | `/b0000000-0000-4000-8000-000000000002/inventory/stock` | 1. Thử mở màn hình tồn kho và màn hình giá. | Chỉ xem được phần được phép; không sửa được giá hay tồn kho (báo thiếu quyền hoặc không có nút sửa). | ☐ | ☐ | |

### 3.12. Giám sát buồng — `uat.hk_supervisor@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Mở ca xe đẩy (điện thoại) | `/m/b0000000-0000-4000-8000-000000000002/trolley` | 1. Mở ca xe đẩy mới. 2. Chọn xe và nhân viên. 3. Bấm **Mở ca**. | Ca xe đẩy được mở, ghi đúng người mở và giờ mở. | ☐ | ☐ | |
| 2 | Bổ sung minibar vào phòng | `/b0000000-0000-4000-8000-000000000002/housekeeping/minibar` | 1. Chọn phòng cần bổ sung. 2. Thêm món minibar (MON01) và số lượng. 3. Lưu. | Minibar phòng tăng đúng số lượng; có nhật ký bổ sung. | ☐ | ☐ | |
| 3 | Quản lý phòng | `/b0000000-0000-4000-8000-000000000002/master/rooms` | 1. Mở danh sách phòng. 2. Thêm/sửa một phòng (số phòng, loại phòng, tầng). 3. Lưu. | Phòng được lưu và hiện trong danh sách; dùng được cho minibar và PMS. | ☐ | ☐ | |
| 4 | Xem phiếu lĩnh của buồng | `/b0000000-0000-4000-8000-000000000002/inventory/requisitions` | 1. Mở phiếu lĩnh đang chờ duyệt. 2. Ghi lại ai là người duyệt theo màn hình. | **Bước duyệt phiếu lĩnh nay do Quản lý đảm nhiệm (Q263).** Phiếu lĩnh chờ Quản lý duyệt rồi mới tới thủ kho xuất. | ☐ | ☐ | |
| 5 | Đóng ca xe đẩy | `/m/b0000000-0000-4000-8000-000000000002/trolley` | 1. Mở ca đang mở. 2. Kiểm kê lại đồ trên xe. 3. Bấm **Đóng ca**. | Ca được đóng, số liệu cuối ca được ghi; không mở được ca mới trùng xe khi ca cũ chưa đóng. | ☐ | ☐ | |

### 3.13. Nhân viên buồng — `uat.hk_attendant@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Xe đẩy: mở ca — đếm — đóng ca | `/m/b0000000-0000-4000-8000-000000000002/trolley` | 1. Mở ca xe đẩy. 2. Đếm đồ trên xe theo danh sách. 3. Đóng ca. | Ca mở/đóng đúng; số đếm được ghi; ca đóng không đếm thêm được. | ☐ | ☐ | |
| 2 | Kiểm minibar có mạng | `/m/b0000000-0000-4000-8000-000000000002/minibar` | 1. Chọn phòng cần kiểm. 2. Nhập số lượng thiếu từng món. 3. Gửi phiếu kiểm. | Phiếu kiểm được tạo, trạng thái đã gửi; lễ tân thấy được để thu tiền. | ☐ | ☐ | |
| 3 | Kiểm minibar mất mạng (offline) | `/m/b0000000-0000-4000-8000-000000000002/minibar` | 1. Bật chế độ máy bay (tắt mạng) trên điện thoại. 2. Kiểm minibar một phòng khác, bấm gửi. 3. Kiểm tra màn hình báo **đã xếp hàng chờ đồng bộ**. 4. Bật mạng lại, đợi 1–2 phút. | Lúc mất mạng: phiếu được xếp hàng, không mất dữ liệu. Sau khi có mạng: phiếu tự đồng bộ lên hệ thống, không phải nhập lại. | ☐ | ☐ | |
| 4 | Gửi 2 lần khi mất mạng không trùng phiếu | `/m/b0000000-0000-4000-8000-000000000002/minibar` | 1. Tắt mạng. 2. Bấm gửi cùng một phiếu kiểm 2 lần. 3. Bật mạng lại, đợi đồng bộ. | Chỉ tạo **một** phiếu kiểm trên hệ thống (lần gửi thứ hai được nhận diện là trùng). | ☐ | ☐ | |
| 5 | Xem phiếu kiểm đã nộp | `/b0000000-0000-4000-8000-000000000002/housekeeping/minibar` | 1. Mở danh sách phiếu kiểm minibar. 2. Mở phiếu vừa nộp ở kịch bản 2/3. | Thấy đúng phiếu của mình với số lượng đã nhập. | ☐ | ☐ | |

### 3.14. Lễ tân — `uat.front_desk@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Yêu cầu kiểm minibar khi khách trả phòng | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` | 1. Chọn phòng khách vừa trả. 2. Bấm **Yêu cầu kiểm minibar**. | Yêu cầu được tạo; nhân viên buồng thấy phòng cần kiểm. | ☐ | ☐ | |
| 2 | Xác nhận thu tiền minibar | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` | 1. Mở phiếu kiểm minibar đã gửi. 2. Kiểm tra số tiền. 3. Bấm **Xác nhận thu tiền**, nhập số folio. | Phiếu chuyển sang đã thu tiền; số tiền khớp với số lượng thiếu × giá minibar. | ☐ | ☐ | |
| 3 | Đề nghị miễn tiền minibar | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` | 1. Mở phiếu kiểm có món cần miễn. 2. Nhập lý do miễn. 3. Gửi đề nghị. | Đề nghị được tạo ở trạng thái chờ GM duyệt; tiền chưa bị trừ cho tới khi duyệt. | ☐ | ☐ | |
| 4 | Nhập số liệu PMS ngày | `/b0000000-0000-4000-8000-000000000002/frontdesk/pms-daily` | 1. Nhập số liệu ngày: số phòng bán, doanh thu phòng. 2. Lưu. | Số liệu được lưu đúng ngày; nhập lại cùng ngày thì cập nhật chứ không tạo trùng. | ☐ | ☐ | |

### 3.15. Kỹ thuật — `uat.engineer@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Tạo phiếu lĩnh vật tư | `/b0000000-0000-4000-8000-000000000002/inventory/requisitions` | 1. Tạo phiếu lĩnh từ KHO-T047. 2. Thêm vật tư cần dùng. 3. Gửi duyệt. | Phiếu lĩnh được tạo ở trạng thái chờ duyệt. | ☐ | ☐ | |
| 2 | Nghiệm thu dịch vụ | `/b0000000-0000-4000-8000-000000000002/procurement/service-contracts/schedules` | 1. Mở lịch dịch vụ tới hạn. 2. Kiểm tra công việc đã làm. 3. Bấm **Nghiệm thu**. | Dịch vụ chuyển sang đã nghiệm thu, ghi đúng người và giờ. | ☐ | ☐ | |
| 3 | Xem hợp đồng dịch vụ | `/b0000000-0000-4000-8000-000000000002/procurement/service-contracts` | 1. Mở một hợp đồng dịch vụ. 2. Xem điều khoản và lịch thực hiện. | Thông tin hợp đồng hiển thị đầy đủ. | ☐ | ☐ | |

### 3.16. Kiểm soát nội bộ — `uat.internal_audit@erp.internal`

**Người thử:** ______________ **Ngày thử:** ______________

| # | Kịch bản | Đường dẫn | Các bước | Kết quả mong đợi | Đạt | Không đạt | Ghi chú |
|---|----------|-----------|----------|------------------|-----|-----------|---------|
| 1 | Ghi nhận: chưa có màn hình nhật ký audit | `/b0000000-0000-4000-8000-000000000002/reports` | 1. Tìm màn hình xem nhật ký hoạt động (audit log) trong menu. 2. Ghi lại kết quả tìm. | **Hiện tại app chưa có màn hình xem chi tiết nhật ký audit** (quyền `audit.view_all` đã có nhưng chưa có giao diện). Ghi nhận đây là khoảng trống cần bổ sung, không tính là lỗi thao tác của người thử. | ☐ | ☐ | |
| 2 | Đối chiếu báo cáo | `/b0000000-0000-4000-8000-000000000002/reports` | 1. Mở báo cáo tồn kho, công nợ, tạm ứng. 2. Đối chiếu số liệu chéo giữa các báo cáo. | Các báo cáo khớp nhau (cùng một nghiệp vụ không cho hai số khác nhau). | ☐ | ☐ | |
| 3 | Kiểm tra không sửa được dữ liệu | `/b0000000-0000-4000-8000-000000000002/procurement/po`, `/b0000000-0000-4000-8000-000000000002/finance/invoices` | 1. Mở một PO và một hóa đơn. 2. Tìm nút sửa/duyệt/tạo mới. | **Không** có nút tạo/sửa/duyệt nào hoạt động — vai trò này chỉ được xem. | ☐ | ☐ | |
| 4 | Xem sức khỏe hệ thống | `/admin/health` | 1. Mở màn hình (nếu vào được). | Nếu vào được thì ghi kết quả; nếu báo thiếu quyền thì ghi rõ — cả hai đều là kết quả hợp lệ (quyền này theo thiết kế chỉ có sys_admin và owner). | ☐ | ☐ | |

---

## 4. Luồng liên vai trò (làm theo thứ tự, cần phối hợp)

Dùng khi muốn thử một nghiệp vụ trọn vẹn từ đầu tới cuối, thay vì thử rời rạc từng vai trò.

### 4.1. Mua hàng → nhận hàng → thanh toán

| Bước | Vai trò | Làm gì | Đường dẫn |
|------|---------|--------|-----------|
| 1 | purchaser | Tạo PR (NVL0388, 10 kg) và gửi duyệt | `/b0000000-0000-4000-8000-000000000002/procurement/pr/new` |
| 2 | gm | Duyệt PR (bước duyệt PR nay do Quản lý) | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` |
| 3 | purchaser | Tạo PO từ PR cho NCC-T047, gửi duyệt | `/b0000000-0000-4000-8000-000000000002/procurement/po` |
| 4 | gm (bậc 1, từ 0 đ) + owner (bậc 2, từ 100 triệu) | Duyệt PO | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` |
| 5 | purchaser | Gửi PO cho NCC | `/b0000000-0000-4000-8000-000000000002/procurement/po` |
| 6 | receiver | Nhận hàng mù trên điện thoại | `/m/b0000000-0000-4000-8000-000000000002/receive` |
| 7 | storekeeper | Đăng phiếu nhận | `/b0000000-0000-4000-8000-000000000002/receiving` |
| 8 | accountant | Nhập hóa đơn NCC theo PO + phiếu nhận | `/b0000000-0000-4000-8000-000000000002/finance/invoices/new` |
| 9 | gm | Duyệt hóa đơn (Kế toán không tự duyệt) | `/b0000000-0000-4000-8000-000000000002/finance/invoices` |
| 10 | accountant | Tạo đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests/new` |
| 11 | owner hoặc gm | Duyệt đề nghị thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` |
| 12 | accountant | Đánh dấu đã thanh toán | `/b0000000-0000-4000-8000-000000000002/finance/payment-requests` |

### 4.2. PO chợ (mua ngoài chợ, chưa có giá)

| Bước | Vai trò | Làm gì | Đường dẫn |
|------|---------|--------|-----------|
| 1 | purchaser | Tạo PO chợ, thêm dòng chưa giá, **nhập tổng ước tính**, gửi duyệt | `/b0000000-0000-4000-8000-000000000002/procurement/market/new` |
| 2 | gm / cost_controller | Duyệt PO chợ (duyệt theo số lớn hơn giữa tổng ước tính và tổng thực) | `/b0000000-0000-4000-8000-000000000002/procurement/approvals` |
| 3 | receiver | Nhận hàng mù | `/m/b0000000-0000-4000-8000-000000000002/receive` |
| 4 | storekeeper | Đăng phiếu nhận | `/b0000000-0000-4000-8000-000000000002/receiving` |

### 4.3. Minibar: kiểm → thu tiền

| Bước | Vai trò | Làm gì | Đường dẫn |
|------|---------|--------|-----------|
| 1 | front_desk | Yêu cầu kiểm minibar khi khách trả phòng | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` |
| 2 | hk_attendant | Kiểm minibar trên điện thoại (thử cả lúc mất mạng) | `/m/b0000000-0000-4000-8000-000000000002/minibar` |
| 3 | front_desk | Xác nhận thu tiền, nhập số folio | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` |
| 4 | gm | Duyệt miễn tiền (nếu có đề nghị miễn) | `/b0000000-0000-4000-8000-000000000002/frontdesk/minibar` |

> **Lưu ý:** giá minibar 7 món đã có hiệu lực từ 11/11 (M9 kiểm chứng tối 13/11). Nếu
> món nào hiện "Chưa có giá" khi kiểm thì phiếu đó chưa gửi được — ghi lại và báo Quản lý
> cập nhật giá rồi kiểm lại.

### 4.4. Kiểm kê theo ca (cần file POS)

| Bước | Vai trò | Làm gì | Đường dẫn |
|------|---------|--------|-----------|
| 1 | gm / accountant / cost_controller | Nạp file POS của ca | `/b0000000-0000-4000-8000-000000000002/inventory/pos-import` |
| 2 | storekeeper | Mở đợt kiểm kê cho ca đó | `/b0000000-0000-4000-8000-000000000002/inventory/counts/new` |
| 3 | chef / bartender / hk_attendant | Đếm mù trên điện thoại | `/m/b0000000-0000-4000-8000-000000000002/count` |
| 4 | cost_controller | Xem chênh lệch | `/b0000000-0000-4000-8000-000000000002/inventory/counts` |
| 5 | gm | Duyệt điều chỉnh kiểm kê | `/b0000000-0000-4000-8000-000000000002/inventory/counts` |

---

## 5. Tổng kết sau UAT

Mỗi vai trò điền một dòng khi hoàn thành phần của mình:

| Vai trò | Người thử | Ngày | Số kịch bản Đạt / Tổng | Vấn đề lớn nhất gặp phải |
|---------|-----------|------|------------------------|--------------------------|
| owner | | | / 5 | |
| gm | | | / 6 | |
| chief_accountant | | | / 6 | |
| accountant | | | / 6 | |
| cost_controller | | | / 5 | |
| purchaser | | | / 6 | |
| storekeeper | | | / 6 | |
| receiver | | | / 4 | |
| outlet_head | | | / 5 | |
| chef | | | / 4 | |
| bartender | | | / 3 | |
| hk_supervisor | | | / 5 | |
| hk_attendant | | | / 5 | |
| front_desk | | | / 4 | |
| engineer | | | / 3 | |
| internal_audit | | | / 4 | |

**Quy tắc ghi lỗi:** mỗi lỗi ghi đủ 4 ý — (1) vai trò + kịch bản số mấy, (2) làm tới bước nào thì lỗi,
(3) thông báo lỗi hiện ra nguyên văn, (4) chụp màn hình đính kèm. Lỗi chặn không làm tiếp được thì
dừng kịch bản đó, ghi rõ, làm kịch bản khác.

**Lưu ý cuối:** tài khoản UAT hết hạn **26/11/2026** và phải vô hiệu hóa trước khi vận hành thật.
Không dùng tài khoản UAT để nhập dữ liệu thật.

---

## 6. Lỗi đã biết & cách né (cập nhật tối 13/11/2026 — từ demo test, Day 1, M9, M11)

Mỗi lỗi ghi rõ: hiện tượng, ai gặp, cách né, trạng thái. Lỗi nào chưa sửa thì khi thử gặp
lại, ghi **Không đạt + thông báo nguyên văn** thay vì cố làm tiếp.

### Chặn làm tiếp (phải né hoặc chờ sửa)

1. **Nhập hóa đơn bị chặn với tài khoản kế toán.** Mở `/finance/invoices/new` thì thấy
   "Không thể tải dữ liệu / Bạn chưa được cấp quyền…" dù vai trò kế toán có quyền nhập hóa
   đơn (demo test 13/11). **Cách né:** dừng ở bước nhập hóa đơn, ghi lại thông báo, làm
   tiếp các bước khác không cần hóa đơn. Đang chờ kiểm tra lại (M1). Lớp: quyền.
2. **Form Sửa nháp PO chợ không lưu được.** Sửa PO chợ nháp rồi bấm Lưu thì báo "Dữ liệu
   không hợp lệ", nội dung sửa bị hoàn lại (demo test 13/11, thử 5 lần đều vậy). **Cách né:**
   đừng sửa nháp PO chợ; tạo mới PO chợ khác nếu cần. Đang chờ kiểm tra lại (M1). Lớp: UI.
3. **Người mở phiếu nhận từng duyệt PO thì không đăng được phiếu (SoD).** Phiếu nhận kẹt ở
   trạng thái nháp, không ai đăng được (chỉ người mở mới được đăng). Đã gặp thật ngày 13/11
   (phiếu GRN-...-0001). **Cách né:** ngay từ đầu, để người nhận hàng là người chưa từng
   duyệt PO đó. Lớp: thiết kế SoD (đúng luật, sai người làm).
4. **Chụp ảnh bắt buộc từng dòng nhận hàng, không có đường tải ảnh lên.** Trình duyệt máy
   tính không có camera thì không bấm được Ghi dòng. **Cách né:** nhận hàng bằng điện thoại
   thật, cấp quyền camera trước khi mở phiếu. Lớp: UI/thiết bị.

### Sai số liệu hoặc hiển thị sai

5. **Ô tổng ước tính PO chợ từ chối số tròn.** Nhập 500.000 thì ô không nhận (bước nhảy
   1.000); nhập 500.001 thì qua (demo test 13/11). **Cách né tạm thời:** nhập lệch 1 đồng.
   Lớp: UI.
6. **Mở lại PO đã có phiếu nháp thì tạo thêm phiếu nháp mới.** TEST47 hiện có 5 phiếu nháp
   trùng cho cùng các PO (GRN-...-0001 đến -0005). **Cách né:** tìm phiếu nháp đang mở dở
   và làm tiếp, đừng bấm Mở phiếu nhận lần nữa. Lớp: UI.
7. **Màn Báo cáo hiện đồng thời "không có quyền" và "Đã xảy ra lỗi khi tải dữ liệu".**
   Gặp ở cả 9 tài khoản đã kiểm tra (M9). Có dấu hiệu tải dữ liệu phía sau bị lỗi thật, không
   chỉ do thiếu quyền. **Cách né:** không có — ghi lại khi gặp. Lớp: UI.
8. **Số liệu PO do agent báo ở đợt kiểm tra 2 mâu thuẫn với giá trị đã biết** (PO-...-0002
   báo 600.000đ trong khi giá trị đúng là 1.040.000đ). Chưa xác minh là lỗi hiển thị hay lỗi
   đọc số liệu — cần đối chiếu lại danh sách PO khi chạy M1/M2. Lớp: chưa kết luận.

### Giao diện / quyền hiển thị không khớp

9. **Menu hiện bộ mục của tài khoản trước ngay sau khi đăng nhập.** Gặp ở cả 6 lần đổi tài
   khoản (M9). **Cách né:** chuyển sang một trang khác, menu sẽ hiện đúng. Lớp: UI.
10. **Menu có mục nhưng mở ra bị chặn, và ngược lại.** Quản lý: menu có "Nhận hàng" nhưng
    mở ra 404. Kế toán: menu không có "Nhận hàng" nhưng gõ đường dẫn thì mở được; menu có
    "Nhà hàng" nhưng mở ra 404. Giám sát buồng: menu có "Kho" nhưng Tồn kho bị chặn.
    **Cách né:** dùng đúng các mục đã kiểm chứng trong hướng dẫn theo vai trò (M17). Lớp: UI.
11. **Ô lọc lộ tên danh mục trên màn trống.** Bộ lọc nhà cung cấp liệt kê tên 16 NCC, bộ lọc
    kho liệt kê tên 8 kho — dù số lượng/giá trị bị ẩn. Không lộ số tiền hay chứng từ.
    Lớp: UI (chờ quyết định có nên ẩn).
12. **Trang tổng quan hiện thẻ quản trị cho mọi vai trò** ("Người dùng & Phân quyền",
    "Cấu hình & Quy tắc duyệt") dù 7/9 vai trò bị chặn ở màn quản trị. **Cách né:** đừng
    bấm các thẻ đó nếu bạn không phải Chủ đầu tư/Quản lý. Lớp: UI.
13. **Trang 404 không nhất quán + render 2 thẻ `<main>`.** Trang 404 có tài khoản hiện menu
    trái, có tài khoản không; trang 404 và lúc đang tải đều render 2 thẻ `<main>` (lỗi a11y).
    **Cách né:** không có — ghi lại khi gặp. Lớp: UI/a11y.
14. **Trang 404 có lúc báo lỗi React #419 (hydration).** Gặp ở tài khoản nhận hàng trong
    suite Playwright M11 (chạy đủ bộ thì rớt, chạy riêng thì đậu — phụ thuộc thứ tự, nghi do
    shell cũ từ service worker). Trang vẫn hiển thị được. Lớp: UI.
15. **Kế toán mở được Minibar — Lễ tân nhưng trống** (không thấy phiếu kiểm mà Chủ đầu tư /
    Quản lý / Lễ tân thấy). Buồng phòng thấy bảng giá minibar nhưng không thấy tồn kho phòng
    của chính mình. Lớp: quyền (chờ quyết định thiết kế).

### Spec test cũ lỗi thời (không phải lỗi app)

16. **M4 (Playwright): DB offline "erp-hotel-offline" không xuất hiện sau khi mở màn nhận
    hàng.** Code dùng lazy singleton — DB chỉ được tạo khi enqueue job offline thật, không
    phải khi mở màn. Kỳ vọng của spec cũ đã lỗi thời. Lớp: test.
17. **M5 (Playwright): service worker đã đăng ký nhưng chưa active** ngay sau khi mở trang.
    Có thể do test kiểm tra quá sớm (install chưa xong). Cần chạy lại trên máy Mac hoặc thêm
    bước chờ activation. Lớp: test/timing.
