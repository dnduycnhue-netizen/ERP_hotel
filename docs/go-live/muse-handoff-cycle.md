# Giao việc cho Muse — chạy trọn chu trình có tồn kho (14/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại để Claude Code tiếp quản.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-verify.md` (luật, vẫn áp dụng), `docs/go-live/muse-report-verify.md`, `CHANGELOG.md` Q273–Q274, `docs/go-live/demo-walkthrough.md`.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện**. Thiếu PIN → bỏ bước cần PIN, ghi lại. **Không đoán PIN.**

## Điều mới so với đợt trước (Claude Code đã sửa, deploy xong)

- **Nhận hàng không camera:** nếu trình duyệt không có camera, ở màn nhận hàng (`/m/<p>/receive`) dòng bắt buộc ảnh sẽ có ô **"Thiết bị không có camera / không chụp được ảnh — xác nhận nhận hàng không kèm ảnh"** + ô lý do (bắt buộc). Tích ô + nhập lý do (ví dụ "Trình duyệt kiểm thử không có camera") là ghi được dòng và ghi sổ được phiếu. **Dùng phương án này** thay vì chờ camera. Lý do trống vẫn bị chặn.
- TEST47 nay có kho trung chuyển (xuất kho/chuyển hàng không còn báo "Dữ liệu không hợp lệ").
- Phiếu xuất mục đích bắt buộc cost center + khoản mục; tìm vật tư nhiều từ không dấu hoạt động; ô xác nhận trên trang cho hủy dòng bán/Gửi duyệt/Gửi NCC.
- Tồn kho TEST47 hiện **= 0**: mục tiêu đợt này là tạo tồn thật bằng chu trình rồi dùng nó.

## Luật (như đợt trước)

1. Chỉ thao tác qua giao diện web, tài khoản `uat.*`, khách sạn **TEST47** (`b0000000-0000-4000-8000-000000000002`). Không `supabase`, không migration, không `vercel`, không RPC/SQL trực tiếp, không service role key.
2. KHÔNG đổi cấu hình (cờ `rule.*`, quy tắc duyệt, vai trò, module, tài khoản, khóa ngày/kỳ). Không tắt PIN/SoD.
3. Không làm giả bằng chứng; không ghi mật khẩu/PIN vào file/commit/log/ảnh chụp. Không đăng nhập khách sạn khác.
4. Được sửa code giao diện/test/docs nếu lỗi rõ ràng (nhánh `feat/muse-cycle` từ `main` mới nhất, mỗi task một commit `T-Cxx:`, `pnpm lint && pnpm typecheck && pnpm test` xanh, chuỗi vào `src/i18n/vi.ts`, không `any`). Lỗi DB/RPC/quyền/dữ liệu → **không tự sửa**, ghi vào "Chuyển Claude Code". Không merge/push `main`; được push nhánh `feat/muse-cycle`.
5. Kẹt > 30 phút một task → ghi lý do, bỏ qua, làm task kế.
6. Mỗi task: báo cáo ngắn `docs/go-live/cycle/Cxx-<tên>.md`; báo cáo tổng `docs/go-live/muse-report-cycle.md`. **Không bịa kết quả.** Mỗi bước ghi Đạt/Không đạt + thông báo nguyên văn nếu lỗi + số liệu tồn/tiền trước–sau.

## Thứ tự làm (task sau dùng kết quả task trước)

### C1. Chu trình mua → nhận → hóa đơn → thanh toán (tạo tồn đầu tiên)
PO-TEST47-LE-2611-0003 (SUP0001, NVL0388 10 kg × 100.000 đ) đã **gửi**. Làm tuần tự:
1. `uat.receiver` nhận hàng mù ở `/m/<p>/receive`: nhập 10 kg (cân 2 lần nếu app đòi). Dùng phương án **không camera** nếu không chụp được. Xác nhận receiver **không thấy** số lượng PO/đơn giá.
2. `uat.storekeeper` ghi sổ phiếu nhận (PIN). Mong đợi: tồn KHO-T047 NVL0388 = **10 kg**, giá vốn **100.000 đ/kg** (`/inventory/stock`), thẻ kho có đúng 1 bút toán nhập, phiếu `posted` không sửa được.
3. `uat.accountant` nhập hóa đơn theo PO + phiếu nhận (10 kg × 100.000) → so khớp 3 bên khớp.
4. `uat.gm` duyệt hóa đơn; thử `uat.accountant` tự duyệt (phải bị chặn, ghi thông báo).
5. `uat.accountant` tạo đề nghị thanh toán → `uat.gm` hoặc `uat.owner` duyệt (người tạo tự duyệt phải bị chặn) → `uat.accountant` đánh dấu đã thanh toán → công nợ SUP0001 về 0 (`/finance/payables`).
Kiểm tra cuối: khối "Sáng nay" của `uat.owner`; `dnduy@hueic.edu.vn` mở `/admin/audit` thấy dấu vết đúng người, **kể cả dòng `receiving_photo_waivers` nếu đã dùng phương án không camera**.

### C2. Chu trình chênh lệch (PO-TEST47-LE-2611-0005, NVL0561 200 cái, đã gửi NCC)
Nhận **180/200** + ghi 5 hỏng (dòng QC lỗi nếu có) → ghi sổ → hóa đơn nhập đủ 200 phải **báo lệch** so khớp (ghi cách app báo) → phiếu trả hàng NCC cho phần hỏng/thiếu. Ghi rõ nếu màn nhận không có ô ghi chú (đã biết, V2-N3). Kiểm tra tồn NVL0561 = 180 − phần trả. Thử thêm: người nhận không ghi sổ phiếu mình mở (SoD) — ghi thông báo.

### C3. Kiểm kê đếm mù (cần tồn từ C1/C2)
Mở đợt kiểm kê KHO-T047 (cả `/inventory/counts/new` lẫn `/m/<p>/count/new`). Đợt phải sinh dòng cho mặt hàng có tồn. Hai người đếm độc lập (ghi tiêu chí "độc lập" bạn tìm ra: cặp nào mở được, cặp nào bị chặn và thông báo gì). Người đếm **không thấy tồn lý thuyết** (màn hình + tab Network nếu mở được). Đếm lệch 1–2 mặt hàng → duyệt điều chỉnh (GM xem chênh lệch) → tồn sau điều chỉnh bằng bút toán, không sửa trực tiếp; đợt đã khóa không đếm thêm được; kho đang kiểm kê bị đóng băng (thử xuất kho khi đang đếm → `ERR_COUNT_FREEZE`).

### C4. Chứng từ kho trọn vòng (cần tồn)
- **Phiếu lĩnh** REQ-TEST47-LE-2611-0002 (đã duyệt): `uat.storekeeper` **Xuất kho** → bếp **Xác nhận nhận** (thử nhận thiếu có ghi chú lệch). Kiểm tồn kho nguồn/kho bếp/kho trung chuyển trước–sau.
- **Điều chuyển** TRF-…-0002 (nháp): **Chuyển hàng** → bên nhận xác nhận; thử hủy khi nháp ở một phiếu khác.
- **Xuất mục đích** PIS-…-0001: bổ sung cost center + khoản mục nếu form đòi (sửa nháp hoặc lập phiếu mới) → **Ghi sổ** → **Đảo phiếu** (có lý do).
- **Hủy hàng** WST-…-0001 (nháp, cần ảnh): chụp ảnh (nếu không có camera: ghi rõ không làm được, hủy hàng vẫn bắt buộc ảnh) → gửi duyệt → `uat.gm` duyệt/từ chối.
Ghi: nút hiện/ẩn theo vai trò; mọi thông báo lỗi (phải là câu cụ thể, không còn "Dữ liệu không hợp lệ" chung chung); số tồn trước–sau và giá vốn.

### C5. Minibar thu tiền (cần tồn kho phòng)
Tìm đường cấp tồn cho kho minibar phòng 101 bằng giao diện (nhập kho minibar tổng qua PO/nhận hàng cho các món minibar — Tiger, Coca-Cola…, rồi cấp bù/điều chuyển cho phòng 101). Nếu không có đường nào làm được hoàn toàn bằng giao diện, ghi rõ từng bước kẹt. Có tồn thì: `uat.front_desk` thu tiền phiếu MB-…-0001 (140.000 đ, folio `TEST-M5-1311`) → báo cáo Minibar (01–14/11) phải khớp: Doanh thu/Đã thu = 140.000 đ, Chờ thu = 0. Thêm: phiếu 0 món (tick "Phòng không dùng món nào") gửi được.

### C6. Báo cáo + xuất Excel + giá trị tồn (cần tồn)
Mở mọi báo cáo; thẻ kho NVL0388 khớp C1/C3/C4; báo cáo tồn/giá trị. `uat.storekeeper` (và Thu mua) thấy **giá trị tồn** ở `/inventory/stock` (quyền mới); `uat.hk_*` **không** thấy tồn lý thuyết minibar; `uat.receiver` **không** thấy PO/giá. Xuất Excel: ghi thông báo ở từng báo cáo (đúng thiết kế là chỉ kỳ/ngày đã khóa sổ; không tự khóa kỳ). Tìm kiếm không dấu: "duong the", "ba chi" ra kết quả.

### C7. Rà SoD & quyền còn lại (ngắn)
Ghi bảng: mỗi chặn SoD đã gặp (thông báo tiếng Việt nguyên văn, mã `ERR_*` thô lộ ra = lỗi). `/receiving/returns` ai mở được (ghi, Claude Code sẽ hỏi Duy). Người lập phiếu thấy nút Duyệt trên phiếu của mình: bấm thử và ghi thông báo.

## Báo cáo cuối (`docs/go-live/muse-report-cycle.md`)

- Bảng C1–C7: Đạt / Không đạt / Không kiểm được + lý do + commit.
- **Lỗi mới** (mô tả, bước tái hiện, mức độ chặn/sai số liệu/bảo mật/giao diện, thuộc UI/DB-RPC/quyền/dữ liệu, đã sửa chưa).
- **Chuyển Claude Code** (P0/P1/P2) và **Cần Duy quyết**.
- Số liệu cuối: tồn từng kho/mặt hàng, giá vốn, công nợ NCC, trạng thái chứng từ đã tạo.
- Lệnh đã chạy + kết quả thật; việc bỏ dở và vì sao.
