# Báo cáo rerun6 — Z1: kiểm lại điểm đáp menu Kho sau Q286

- Ngày: 16/11/2026, 07:15–07:17. Nhánh: `feat/muse-rerun6` (từ `origin/main` 1d20508, Q286). App live: https://erphotel.vercel.app, TEST47.
- Phạm vi: chỉ giao diện; không tạo/sửa/xóa chứng từ, không sửa cấu hình/quyền/tài khoản/PIN.

## Kết quả

| Bước | Đích thực tế | Kết quả |
|---|---|---|
| 1 — Owner bấm "Kho" ở sidebar | `/inventory/requisitions` — "Phiếu lĩnh" | **Không đạt** — "Không thể tải dữ liệu / Bạn chưa được cấp quyền thực hiện thao tác này." (tái hiện đúng R5-N5) |
| 2 — Owner gõ thẳng `/<P>/inventory` | Tự chuyển tới `/inventory/transfers` — "Phiếu điều chuyển", 11 phiếu, mở được | **Đạt** |
| 3 — Owner, ô tìm nhanh "Kho" | Gợi ý "Kho" → `/inventory/transfers` — "Phiếu điều chuyển", mở được | **Đạt** (lưu ý: lúc bấm, trang đã đang ở `/inventory/transfers` sau bước 2 nên không phát sinh chuyển trang mới) |
| 4 — Receiver bấm "Kho" ở sidebar | Sidebar của receiver KHÔNG có mục "Kho" (chỉ "Tổng quan", "Hướng dẫn", "Danh mục"); tìm nhanh "Kho" → `/master/warehouses` — "Danh mục kho", mở được | **Không đạt như kỳ vọng** (kỳ vọng "Phiếu lĩnh" là sai — receiver không có menu Kho; làm việc qua màn nhận hàng mobile) |

**Kết luận: Đạt một phần (2/4).** Q286 sửa được điểm đáp `/inventory` gốc (gõ thẳng + tìm nhanh đều về `/inventory/transfers`), nhưng mục "Kho" trên sidebar vẫn trỏ tới `/inventory/requisitions` đối với owner và vẫn báo lỗi quyền như trước Q286.

## Vấn đề mới

- **R6-N1 (Chuyển Claude Code) — R5-N5 chưa sửa hết:** Q286 chỉ sửa redirect `/inventory` và jump search; href của mục "Kho" trên sidebar vẫn là `/inventory/requisitions`. Cần đổi href của mục "Kho" theo quyền (owner → `/inventory/transfers`) hoặc cho nó trỏ `/inventory` để redirect lo.

## Ghi chú

- Bước 4: kỳ vọng trong giao nhiệm vụ ("receiver bấm Kho → Phiếu lĩnh") là sai — sidebar của receiver không có mục Kho; receiver nhận hàng qua màn mobile `/m/<P>/receive`. Không phải lỗi app.
- Không đổi tồn/số liệu nào trong vòng này (chỉ mở màn hình).
