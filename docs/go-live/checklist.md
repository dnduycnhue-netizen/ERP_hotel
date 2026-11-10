# Checklist go-live ERP_hotel — 1 bảng duy nhất

> **Trạng thái:** Tổng hợp ngày 10/11/2026 (sau đợt verify-prep).
> Nguồn trạng thái: báo cáo audit `~/workspace/erp-hotel-feature-audit-REPORT.md`
> (§1, §3, §5.2), `docs/OPEN-QUESTIONS.md` (Q1–Q173), các doc go-live
> trong `docs/go-live/` (V3–V5, V7 của đợt này). Không bịa trạng thái:
> mục nào chưa kiểm chứng thì ghi rõ "chưa kiểm chứng".
> Thứ tự làm = thứ tự bảng (từ trên xuống). Chủ sở hữu: **Duy** = chỉ Duy
> làm được; **tau** = agent chính; **agent** = wave đang chạy.

## A. Cổng kỹ thuật (phải xanh mới go-live)

| # | Cổng | Trạng thái hiện tại | Chủ sở hữu | Ghi chú |
|---|---|---|---|---|
| A1 | pgTAP 35 suite / 1.709 assertion | **2/35 suite đã chạy, đều PASS**: T-023 87/87 (10/11 00:35), bootstrap 22 (08/11). Restaurant 69 assertion **kẹt lỗi fixture** (C13 đang sửa, test-only). 32 suite chưa chạy | tau + agent (C13) | Danh sách từng suite ở audit §5.2. Các suite lớn (>54KB) đã có bản chạy gọn trong `supabase/tests/run-ready/` (V1 đợt này). Chạy trên SQL Editor, mỗi file < 50.000 B |
| A2 | pgTAP các suite chưa chạy (10 suite lớn đã nêu tên) | Chưa chạy: T-026 (49), T-030 (97), T-034 (93), T-035 (104), T-036 (49), T-040 (80), T-042 (67), T-043 (55), T-044 (82), T-045 (54); còn lại xem audit §5.2 | tau | Chạy sau khi bundle completion-2 merge (C13 sửa fixture xong thì chạy lại restaurant trước) |
| A3 | Playwright tầng ghi W1–W11 | **Chưa chạy** — chỉ chạy được trên máy Mac của Duy (property test riêng TEST47 + TEST01/TEST02 + PIN 1234; VM Chromium không tới được production) | Duy | Tầng đọc public 5/5 PASS, Vitest 13/13 PASS (Duy chạy 10/11 10:15). Tầng ghi cần Duy chạy seed test-property + tạo 2 user test trước |
| A4 | Q110 checklist tay (7 mục) | **0/7** | Duy | Đếm mù end-to-end trên điện thoại thật, đối chiếu Excel với `v_count_result`, test offline, kiểm tra `count_list_counters` theo kho, nhận hàng offline |
| A5 | `database.types.ts` | **Stale từ T-012** — chỉ Duy regenerate được (`supabase gen types` trên máy Mac) | Duy | Làm trước khi go-live để typecheck khớp schema thật |

## B. Cổng dữ liệu & cấu hình (cần Duy chốt/cung cấp)

| # | Cổng | Trạng thái hiện tại | Chủ sở hữu | Ghi chú |
|---|---|---|---|---|
| B1 | Sender T-045 (email + push) | **Chưa cấu hình được** — thiếu key của Duy (Q98/Q99) | Duy | Hướng dẫn đầy đủ ở `docs/go-live/notification-sender-setup.md` (V4). Cần: Resend API key, email gửi đã verify, VAPID public/private + subject, shared secret (Vault + EF giống hệt nhau). Zalo là stub 501 — làm riêng sau |
| B2 | Tên pháp nhân thật | **Chưa có** — 3 bảng đang dùng tạm "Son Hoi An Boutique Hotel & Spa" | Duy | SQL mẫu 1 phút ở `docs/go-live/legal-entity-rename.md` (V5). Khuyến nghị: chỉ đổi `legal_entities.name` |
| B3 | Tồn đầu kỳ (Q157) | **Chưa chốt** — runbook đã sẵn | Duy chốt, tau/GM làm | `docs/go-live/opening-stock-runbook.md` (V3): kiểm đếm thật ngày cutover, không dùng số 11/2019 (7 năm tuổi). Cần chốt thêm Q31/Q35/Q36/Q37/Q38 trước ngày cutover |
| B4 | Công thức món ăn (Q168) | **Chưa chốt nguồn** — nháp đã sẵn | Duy chốt | `docs/sample-data/recipes-import-DRAFT.sql` (V2): 81 công thức, 392 dòng định lượng; 18 dòng [CẦN XÁC NHẬN]. Chốt import Excel hay nhập tay rồi mới chạy (sau seed, chia nhỏ file nếu >54KB) |
| B5 | Dữ liệu go-live khác | Seed mẫu 668 items đã nạp + kiểm chứng (10/11 21:34); `stock_moves` = 0 theo thiết kế | tau | Minibar: 7 món chưa có giá bán (giá seed hết hạn 2018–2019) — nhập giá hiện hành trước khi bán. `room_setup_standards` + `trolley_par_levels` = 0 (seed §5/§6 lỗi, chưa chạy) — nhập lại khi có số thật |

## C. Cổng quyết định nghiệp vụ (Duy chốt, gom 1 lần)

| # | Câu hỏi | Trạng thái | Ảnh hưởng nếu không chốt |
|---|---|---|---|
| C1 | **Q71** — phiếu không hóa đơn có được ghi `ap_ledger` không | Mở | Màn tài chính hiển thị công nợ thiếu/không khớp |
| C2 | **Q76** — ai nghiệm thu dịch vụ (`service.accept` hiện chỉ engineer) | Mở | Lễ tân/GM không nghiệm thu được dịch vụ |
| C3 | **Q83** — ai được chạy `export.accounting` (hiện chỉ `chief_accountant`) | Mở | Chỉ kế toán trưởng xuất được file kế toán |
| C4 | **Q58** — pháp nhân FIFO lỗi `ERR_NEGATIVE_STOCK` khi bán minibar từ kho phòng (transfer_in không tạo lớp FIFO) | Mở — **QUAN TRỌNG** | Chỉ `moving_avg` (mặc định) chạy được; kiểm tra costing method của SONHOIAN trước go-live |
| C5 | **Q60** — lễ tân/owner/gm thiếu `item.view` nên phiếu kiểm hiện đủ tiền mà thiếu tên hàng | Mở — **QUAN TRỌNG** | Cần cấp `item.view` cho front_desk/owner/gm |
| C6 | **Q73** — timeline duyệt đề nghị thanh toán không đọc được từ client (`approvals_select`/`approval_timeline` chỉ hỗ trợ pr/po) | Mở — **QUAN TRỌNG** | Màn tài chính thiếu lịch sử duyệt đề nghị thanh toán |
| C7 | **Q81** — `service_accept` không nhận `note` dù bảng có cột | Mở | Nghiệm thu không ghi được ghi chú |
| C8 | **T-022 (A/B)** — miễn kiểm tra giá cho PO chợ trong `po_submit` hay giữ luật chặn, sửa test | Mở | PO chợ có dòng không giá thì submit bị chặn (P0001 `ERR_PRICE_NOT_SET`) |
| C9 | **Q101** — (xem OPEN-QUESTIONS) | Mở | Theo audit §1 — chốt cùng đợt với C1–C8 |
| C10 | **Q31/Q42/Q80** — (xem OPEN-QUESTIONS) | Mở | Theo audit §1 — chốt cùng đợt |

## D. Cổng giao diện & hiệu năng

| # | Cổng | Trạng thái hiện tại | Chủ sở hữu | Ghi chú |
|---|---|---|---|---|
| D1 | Đợt redesign ClickUp (UI polish) | **Kế hoạch đã sẵn** (V7), chưa làm | agent (đợt riêng) | `docs/go-live/ui-polish-plan.md`. Làm sau khi xong hết chức năng, trước go-live (chỉ thị Duy 10/11 07:34). UI-1/UI-2 đã làm xong vỏ + 34 bảng |
| D2 | Tốc độ tải (bom1, Q124–Q126) | **Chưa khắc phục** | agent | Trang chủ từng kẹt ~15 giây (09/11, đã sửa 1 phần); cần đo lại sau khi merge các wave |
| D3 | Màn xe đẩy mobile | Đã làm (T-047 + Q105 chốt làm) | — | Đã xong; kiểm chứng lại trong A4 (Q110 tay) |

## E. Các wave đang chạy (không được quên khi merge)

| Wave | Nhánh | Phạm vi | Trạng thái |
|---|---|---|---|
| Mobile UI | `merge/mobile-ui` | W1–W5: màn mobile + test | Đang chạy (coordinator riêng) |
| Completion-2 | `merge/completion-2` | C1–C13: day-lock, photo-review, PO PDF + bank-transfer + export_batches, finance export, org/property UI, route còn thiếu, housekeeping/minibar, RPC thiếu + 5 alert code chết, docs + fix nhỏ, report matview + dashboard single-RPC, restaurant Q166–Q170, GR attachment, C13 sửa fixture pgTAP | Đang chạy (coordinator riêng) |
| Verify-prep (đợt này) | `merge/verify-prep` | V1–V7: bản chạy pgTAP gọn, nháp công thức, runbook tồn đầu kỳ, hướng dẫn sender, đổi tên pháp nhân, checklist này, kế hoạch UI polish | V1–V7 xong, chờ merge chung |

> **Quy tắc merge:** Duy merge 1 lần duy nhất cả 3 bundle (mobile +
> completion-2 + verify-prep). Không merge lẻ từng wave. Sau merge: chạy
> lại A1 (restaurant trước), A2, rồi A3–A4 trên máy Duy.

## F. Thứ tự làm (tóm tắt)

1. Duy chốt C1–C10 (gom 1 lần) + cung cấp B1 (sender keys) + B2 (tên pháp nhân).
2. Merge 3 bundle (mobile + completion-2 + verify-prep) → deploy.
3. Chạy A1 (restaurant trước) + A2 (pgTAP còn lại) trên production.
4. Duy chạy A3 (Playwright ghi) + A4 (Q110 tay) trên Mac/điện thoại thật.
5. Duy regenerate A5 (`database.types.ts`).
6. Chạy B3 (kiểm đếm cutover theo runbook V3) → khóa kỳ → B4 (công thức theo Q168).
7. Đợt D1 (UI polish theo kế hoạch V7) + D2 (đo tốc độ bom1).
8. Go-live.
