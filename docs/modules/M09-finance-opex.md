# M09 + M11 — Tài chính & chi phí vận hành (phần MVP)

## Hóa đơn & khớp 3 chiều
1. Kế toán nhập hóa đơn (MVP: nhập tay + ảnh/PDF; P2: import XML hóa đơn điện tử).
2. Chọn PO/GRN liên quan → `invoice_match` so từng dòng: số lượng ≤ số nhận; đơn giá trong ±1%.
3. Khớp → `matched` → kế toán trưởng `invoice_approve` → `ap_ledger` (+).
4. Không khớp → `on_hold` + lý do; thu mua/NCC xử lý (hóa đơn điều chỉnh, trả hàng).

## Tạm ứng & quyết toán
`requested` → `approved` (gm) → `disbursed` (kế toán) → `settling` (người ứng nộp chứng từ) → `settled`.
Quyết toán = Σ (số lượng thực nhận trên GRN × đơn giá biên nhận). Chênh với số ứng → hoàn ứng hoặc chi thêm. Quá 24h → `overdue`.

## Thanh toán
Đề nghị thanh toán gom hóa đơn theo NCC và hạn → kế toán trưởng duyệt → xuất file Excel danh sách chuyển khoản (MVP; chưa nối ngân hàng) → đánh dấu đã chi + số tham chiếu → `ap_ledger` (−).

## Mua dịch vụ & hợp đồng định kỳ (11.01, 11.02)
- PO dịch vụ → nghiệm thu (`service_acceptances`: người nghiệm thu ≠ người đặt, ảnh trước/sau, đánh giá 1–5) → mới được ghi hóa đơn/công nợ.
- Hợp đồng định kỳ (thang máy, PCCC, côn trùng, rác, internet, bảo vệ, phần mềm…) → cron sinh kỳ; kỳ đến hạn nhắc người phụ trách nghiệm thu; nhắc gia hạn trước 30 ngày.

## Xuất Excel cho kế toán (thay cho kết nối MISA/Bravo ở MVP)
| File | Nội dung |
|---|---|
| Phiếu nhập kho | Theo pháp nhân, kỳ/ngày đã khóa: số phiếu, ngày, NCC, mã, tên, ĐVT, SL, đơn giá, thành tiền, kho |
| Phiếu xuất kho | Loại xuất, kho, cost center, khoản mục, mã, SL, giá bình quân, thành tiền |
| Hóa đơn mua & công nợ | Ký hiệu, số, ngày hóa đơn, MST, tiền hàng, thuế, tổng |
| Bảng kê không hóa đơn | Theo mẫu kế toán cung cấp |
| Tạm ứng | Người ứng, số ứng, quyết toán, còn lại |

Đặt tên cột theo mẫu import của MISA khi có mẫu từ kế toán (ghi vào `OPEN-QUESTIONS.md`); trước đó dùng tên cột tiếng Việt rõ nghĩa. Mỗi lần xuất tạo `export_batches` và đánh dấu `export_status = 'exported'` để không xuất trùng.
