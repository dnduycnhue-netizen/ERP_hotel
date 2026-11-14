# Giao việc cho Muse — xác minh các bản sửa (14/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại để Claude Code tiếp quản.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-overnight.md` (luật, vẫn áp dụng), `docs/go-live/muse-report-overnight.md` (danh sách lỗi đợt trước), `CHANGELOG.md` mục Q268–Q272, `docs/go-live/demo-walkthrough.md`.
> Mật khẩu chung và PIN **Duy dán riêng vào cuộc trò chuyện**. Thiếu PIN → bỏ bước cần PIN, ghi lại, làm bước khác. **Không đoán PIN.**

## Mục tiêu

Đợt trước tìm ~56 lỗi. Claude Code đã sửa Q268–Q272 và deploy. Việc của bạn: **chạy lại trên giao diện thật** để xác nhận từng bản sửa hoạt động (Đạt / Không đạt / Không kiểm được), và tìm lỗi mới do bản sửa gây ra. Không cần khám phá rộng như đợt trước; bám danh sách dưới đây.

## Luật (như đợt trước + bổ sung)

1. Chỉ thao tác dữ liệu qua giao diện web, tài khoản `uat.*`, khách sạn **TEST47** (`b0000000-0000-4000-8000-000000000002`). Không `supabase`, không migration, không `vercel`, không RPC/SQL trực tiếp, không service role key.
2. KHÔNG đổi cấu hình (cờ `rule.*`, quy tắc duyệt, vai trò, module, tài khoản, khóa ngày/kỳ). Không tắt PIN/SoD.
3. Không làm giả bằng chứng; không ghi mật khẩu/PIN vào file, commit, log, ảnh chụp. Không đăng nhập khách sạn khác.
4. Camera: dùng camera giả của Chromium (`--use-fake-device-for-media-stream --use-fake-ui-for-media-stream`). Nếu không có camera/ảnh bị từ chối → ghi đúng thông báo, **không** sửa app để qua.
5. Được sửa code giao diện/test/docs nếu lỗi rõ ràng (nhánh `feat/muse-verify` từ `main` mới nhất, mỗi task một commit tiền tố `T-Vxx:`, `pnpm lint && pnpm typecheck && pnpm test` xanh, chuỗi vào `src/i18n/vi.ts`, không `any`). Lỗi DB/RPC/quyền/dữ liệu → **không tự sửa**, ghi vào mục "Chuyển Claude Code". Không merge/push `main`; được push nhánh `feat/muse-verify`.
6. Kẹt > 30 phút một task → ghi lý do, bỏ qua, làm task kế.
7. Mỗi task: báo cáo ngắn ở `docs/go-live/verify/Vxx-<tên>.md`; báo cáo tổng `docs/go-live/muse-report-verify.md` (bảng Đạt/Không đạt, lỗi mới, việc bỏ dở). **Không bịa kết quả.**
8. Nút xác nhận giờ là ô hỏi **ngay trên trang** ("Xác nhận" / "Bỏ qua"), không còn hộp thoại trình duyệt — thao tác được bằng trình duyệt tự động. Nếu vẫn bị kẹt thì đó là lỗi, ghi lại.

## Thứ tự làm (ưu tiên từ trên xuống)

### V1. Chu trình mua → nhận → hóa đơn → thanh toán (cần PIN, camera)
Làm theo `demo-walkthrough.md` mục 1 từ bước 6 trên **PO-TEST47-LE-2611-0003** (NVL0388 10 kg × 100.000 đ). Kiểm tra cuối: tồn KHO-T047 NVL0388 = 10 kg, giá vốn 100.000 đ/kg, thẻ kho 1 bút toán nhập, công nợ SUP0001 về 0 sau khi đánh dấu đã thanh toán, khối "Sáng nay" có số liệu. Xác minh riêng: (a) kế toán mở được form hóa đơn (Q267); (b) ô "Đơn mua" có dòng gợi ý "chọn nhà cung cấp trước" (Q272); (c) mã phiếu nhận ở `/inventory/receipts` mở tới chính phiếu nhận (Q271 B-18); (d) người nhận không thấy số lượng/giá PO ở bất kỳ màn hay phản hồi mạng nào nhìn thấy được.

### V2. Chu trình có chênh lệch + chặn SoD
PR-TEST47-LE-2611-0006 (NVL0561, 200 cái) đang **nháp**: `uat.purchaser` bấm **Gửi duyệt** (kiểm tra ô xác nhận trên trang hoạt động) → `uat.gm` duyệt → tạo PO → gửi NCC → nhận **180/200** + 5 hỏng → hóa đơn 200 phải **báo lệch** so khớp → trả hàng NCC. Thử các chặn SoD (mỗi chặn ghi thông báo tiếng Việt nguyên văn, mã `ERR_*` thô hiện ra = lỗi): người nhận không ghi sổ phiếu mình mở; kế toán không duyệt hóa đơn mình tạo; người tạo đề nghị thanh toán không duyệt; người tạo PR không duyệt PR.

### V3. Kiểm kê đếm mù (B-1 đã sửa)
Mở đợt kiểm kê KHO-T047 ở **cả hai** `/inventory/counts/new` và `/m/<p>/count/new` (trước đây lỗi máy chủ 10/10). Hai người đếm độc lập, người đếm không thấy tồn lý thuyết (kể cả tab Network nếu mở được). Đếm lệch → duyệt điều chỉnh (GM có quyền xem chênh lệch — Q270) → tồn sau điều chỉnh bằng bút toán. Đợt đã khóa không đếm thêm được.

### V4. Chứng từ kho: form mới và vòng đời (B-4, Q270)
Cần có tồn từ V1. Với từng loại, làm trọn vòng (tài khoản gợi ý trong ngoặc):
- **Hủy hàng** `/inventory/waste/new` (`uat.storekeeper` hoặc `uat.chef`): lập nháp → chụp ảnh minh chứng → gửi duyệt (thiếu ảnh phải bị chặn) → `uat.gm` duyệt/từ chối → tồn giảm đúng.
- **Phiếu lĩnh** `/inventory/requisitions/new` (`uat.chef`, bộ phận Bếp, kho xuất KHO-T047 → kho nhận KHO_BEP): gửi duyệt → `uat.gm` duyệt → `uat.storekeeper` **Xuất kho** → bếp **Xác nhận nhận** (thử nhận thiếu có ghi chú lệch).
- **Điều chuyển** `/inventory/transfers/new` (`uat.storekeeper`): chuyển hàng → bên nhận xác nhận; thử hủy khi nháp.
- **Xuất mục đích** `/inventory/issues/new`: ghi sổ → đảo phiếu (có lý do).
Ghi: nút nào hiện/ẩn theo vai trò, mọi thông báo lỗi, số liệu tồn trước/sau.

### V5. Minibar thu tiền (B-3)
Cấp tồn cho kho minibar phòng 101 bằng luồng thật (nhập kho minibar tổng rồi cấp bù qua màn minibar/điều chuyển nếu có), sau đó thu tiền phiếu MB-…-0001 (140.000 đ, folio `TEST-M5-1311`). Ghi rõ nếu không có đường nào cấp tồn cho kho phòng bằng giao diện. Kiểm tra: báo cáo Minibar sau khi thu (Doanh thu/Đã thu có khớp 140.000 đ không — B-8). Thêm: phiếu 104 chưa kiểm hiện "Chưa kiểm" (không phải "Chờ thu tiền"); gửi phiếu 0 món chỉ khi tick "Phòng không dùng món nào"; nhập số lượng > 20 hiện cảnh báo.

### V6. PO chợ
`uat.purchaser`: PO-TEST47-LE-2611-0004 → **Sửa nháp** → đổi mô tả dòng + lý do → Lưu nháp → tải lại: mô tả mới phải còn (Q268). Nhập tổng ước tính → **Gửi duyệt** không còn bị chặn bởi "giá 0" và chú giải đúng. Danh sách PO hiện "Chưa có giá (xem chi tiết)" thay vì 0 đ.

### V7. Quyền mới (Q270) — mỗi dòng Đạt/Không đạt
- `uat.gm`: mở `/inventory/transfers` (tab "Điều chuyển" có trong menu Kho), xem chênh lệch kiểm kê.
- `uat.storekeeper`: mở chi tiết PO (xem được), `/inventory/waste/new` (lập được), thấy giá trị tồn ở `/inventory/stock`.
- `uat.hk_attendant`/`uat.hk_supervisor`: **vẫn không** thấy tồn lý thuyết minibar (đếm mù — phải giữ).
- `uat.receiver`: **vẫn không** thấy PO/giá.

### V8. Bán hàng nhà hàng + cảnh báo tồn (B-31)
`uat.chef` hoặc `uat.front_desk`: ghi bán 1 món có công thức khi tồn bếp thiếu → dòng bán vẫn ghi, hiện cảnh báo "N nguyên liệu chưa đủ tồn…"; có phiếu lĩnh nháp tự sinh. Lãi gộp trên trang Bán hàng khớp báo cáo F&B (B-7). Hủy dòng bán bằng ô xác nhận trên trang (B-33). Phiên buffet đã đóng hiện "Đã hoàn tất" (B-29).

### V9. Báo cáo + xuất Excel (B-5)
Mở từng báo cáo có nút Xuất Excel. Mong đợi: bấm nút **không** đổi tab; khoảng chưa khóa sổ hiện thông báo tiếng Việt ngay dưới nút (đó là đúng thiết kế); **không còn HTTP 500**. Nếu có khoảng ngày đã khóa sổ thì tải được file: ghi cột, dấu tiếng Việt, số là số Excel thật. Người không có quyền xem báo cáo chỉ thấy MỘT thông báo (B-42); đảo ngày (from > to) báo lỗi (B-44).

### V10. Quét nhanh các lỗi giao diện đã sửa
Tìm "duong" ở màn tìm vật tư/tồn kho ra "Đường" (B-53); tìm kiếm ở `/inventory/stock` không còn "Invalid UUID" (B-32); `/inventory/pos-import` hiện "Module đang tắt" khi module tắt — **chỉ xem, không tắt module** (B-20); đổi tài khoản không còn menu cũ (B-22); khung 390 px không tràn ngang ở các màn mới (`/inventory/*/new`, trang chi tiết).

## Báo cáo cuối (`docs/go-live/muse-report-verify.md`)

- Bảng V1–V10 + từng mã lỗi cũ (B-1…B-56 đã sửa): **Đạt / Không đạt / Không kiểm được** + lý do + commit/ảnh.
- **Lỗi mới** (mô tả, bước tái hiện, mức độ chặn/sai số liệu/bảo mật/giao diện, thuộc UI/DB-RPC/quyền/dữ liệu, đã sửa chưa).
- **Chuyển Claude Code** (xếp P0/P1/P2).
- Tồn kho cuối ngày NVL0388/NVL0561 ở KHO-T047, công nợ SUP0001, trạng thái các chứng từ đã tạo.
- Lệnh đã chạy + kết quả thật (`pnpm lint`, `typecheck`, `test`); việc bỏ dở và vì sao.

## Nếu thiếu PIN/camera

Bỏ V1, V2, V4 (phần chụp ảnh), V5 (phần cấp tồn). Làm: V3 (mở được đợt kiểm kê), V6, V7, V8, V9, V10, rồi phần còn lại của V4/V5 trong phạm vi không bị chặn.
