# M12 — Vitest cho schema Zod & hàm tiện ích còn thiếu

- Trạng thái: **Đạt**
- Thời gian: 13/11/2026 ~22:47–22:55
- Lệnh đã chạy: `pnpm vitest run tests/unit/overnight-*.test.ts`, `pnpm test`, `pnpm lint`, `pnpm typecheck`
- Kết quả: file mới 72/72 đậu; toàn bộ suite 285/285 (31 file, trước M12 là 213 test); lint sạch; typecheck sạch.

## Phạm vi đã quét

- 18 file `src/features/*/schemas.ts`. Có test riêng trước M12: admin (create-user, legal-entity), housekeeping-standards, pms-daily, receiving-photo-review, restaurant, count (một phần), rpc-error-coverage.
- **Không có test riêng trước M12 (11 file):** account, attachments, finance, inventory, locks, master, minibar, procurement, report, service, trolley.
- Hàm tiện ích chưa có test: `formatMoney`/`formatNumber` (`money-text.tsx`), `formatYmd`/`formatQty`/`parseDecimal`/`calcUomTotal`/`calcBottleTotal`/`normalizeSearch` (`count-utils.ts`), `formatDateVn`/`formatDateTimeVn` (`export/hub.ts`).

## Việc đã làm

1. **4 file test mới (72 test có ý nghĩa, không snapshot rỗng):**
   - `tests/unit/overnight-schemas-finance.test.ts` — hóa đơn (dòng, nháp, khớp, duyệt), quyết toán tạm ứng, đề nghị thanh toán (từ chối bắt buộc lý do), ghi đã thanh toán, bảng kê không hóa đơn.
   - `tests/unit/overnight-schemas-master.test.ts` — vật tư (mã, VAT, ABC, kênh), ĐVT (mã chữ thường), nhóm vật tư, NCC, hợp đồng khung (ngày kết ≥ ngày bắt đầu), giá trần, mã tạm, gộp mã, phòng, kho.
   - `tests/unit/overnight-schemas-ops.test.ts` — tồn kho (limit 1–100, mặc định 20/0), thẻ kho, khóa ngày/kỳ (tháng 1–12, năm 1–9999), minibar (số thiếu dương, ít nhất 1 dòng, folio bắt buộc), xe đẩy (ca day/morning/evening), hợp đồng dịch vụ, báo cáo (from ≤ to), đổi mật khẩu (≥12 ký tự, khác cũ, khớp xác nhận), đăng ký đính kèm, PO ước tính.
   - `tests/unit/overnight-format-errors.test.ts` — định dạng tiền/số/ngày theo vi-VN và giờ Asia/Ho_Chi_Minh; `parseDecimal`/`calcUomTotal`/`calcBottleTotal` theo R30 (0 là tổng hợp lệ); `normalizeSearch`; mapping mã lỗi RPC → câu tiếng Việt.
2. **Sửa 1 thiếu sót về mapping mã lỗi** (`src/i18n/errors.vi.ts`): thêm câu riêng cho `ERR_SOD_COUNT_INDEPENDENT` (xem mục Lỗi).

## Kiểm tra mapping mã lỗi ERR_* (docs/09-API-RPC.md)

- Tài liệu liệt kê **41 mã**. Trước M12: 40 mã có câu riêng, **1 mã thiếu**: `ERR_SOD_COUNT_INDEPENDENT` — rơi vào câu SoD chung ("Thao tác vi phạm quy tắc tách biệt nhiệm vụ…"), không nói rõ lý do.
- Nguyên nhân: migration 542000 (Q216, Duy chốt 11/11) đã đổi code raise từ `ERR_COUNT_INDEPENDENT` sang `ERR_SOD_COUNT_INDEPENDENT` cho khớp docs, nhưng `errors.vi.ts` chỉ có câu cho mã cũ `ERR_COUNT_INDEPENDENT`. Test `rpc-error-coverage.test.ts` quét mã trong migration không bắt được vì mã này không xuất hiện dạng literal trong migration (raise bằng `'ERR_' || p_rule_code`).
- Đã sửa: thêm `ERR_SOD_COUNT_INDEPENDENT` với cùng câu như mã cũ ("Đợt kiểm kê cần ít nhất một người đếm độc lập, không phải người nhập hoặc xuất kho tại kho này."). Mã cũ giữ nguyên (vẫn xuất hiện trong migration cũ).
- Test mới khóa lại: mọi mã trong docs đều không rơi vào câu chung (trừ các mã SoD chưa có câu riêng — hiện chỉ còn các mã SoD chưa xuất hiện trong docs).

## Lỗi / hạn chế tìm thấy

1. **(Đã sửa) `ERR_SOD_COUNT_INDEPENDENT` không có câu riêng** — xem trên. Thuộc nhóm UI (hiển thị). Commit T-M12.
2. **(Ghi nhận, chưa sửa — chuyển Claude Code) `normalizeSearch` không chuẩn hóa được chữ "đ".** Hàm dùng NFD để lược dấu, nhưng "đ" (U+0110) không tách được bằng NFD nên `normalizeSearch("Đường")` trả về `"đường"` (đ + uong) thay vì `"duong"`. Hệ quả: tìm kiếm không dấu "duong" không khớp "Đường". Test mới khóa đúng hành vi hiện tại (ghi chú trong test). Sửa đúng cần thay "đ"→"d"/"Đ"→"D" trước khi lược dấu — việc nhỏ, để Claude Code quyết có sửa không (ảnh hưởng mọi ô tìm kiếm dùng hàm này).
3. **(Ghi nhận) Test `rpc-error-coverage` không bao quát mã lỗi chỉ có trong docs.** Mã raise bằng nối chuỗi (`'ERR_' || rule_code`) không xuất hiện dạng literal trong migration nên test quét migration bỏ sót. Test mới của M12 khóa 41 mã trong docs, bổ sung cho test cũ.

## Việc chưa làm

- Không viết test cho các schema đã có test riêng (admin, housekeeping-standards, pms-daily, receiving-photo-review, restaurant, count) — ngoài phạm vi "còn thiếu".
- Không test `src/lib/modules`, `src/lib/offline` (đã có test riêng: offline-queue, minibar-offline-sync, property-modules).
- Spec Playwright (M11) chưa làm trong task này.
