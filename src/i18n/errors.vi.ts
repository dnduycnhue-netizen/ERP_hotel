// Mã lỗi RPC (docs/09-API-RPC.md mục 10) → câu tiếng Việt hiển thị cho người dùng.
// Server trả mã dạng `ERR_...`; `ERR_FORBIDDEN:<ma.quyen>` kèm mã quyền thiếu.
// Không hard-code chuỗi lỗi trong component — dùng `getRpcErrorMessage` ở đây.

export const rpcErrorMessages: Record<string, string> = {
  ERR_FORBIDDEN: "Bạn chưa được cấp quyền thực hiện thao tác này.",
  ERR_CONFIG_INVALID: "Thông tin cấu hình không hợp lệ. Hãy kiểm tra lại.",
  ERR_CONFIG_SCOPE: "Phạm vi cấu hình không thuộc tổ chức đã chọn.",
  ERR_CONFIG_ITEM_GROUP:
    "Nhóm hàng không tồn tại hoặc không thuộc tổ chức đã chọn.",
  ERR_CONFIG_APPROVER:
    "Người duyệt không hoạt động hoặc chưa có quyền duyệt bắt buộc.",
  ERR_CONFIG_NOT_FOUND: "Không tìm thấy quy tắc cấu hình.",
  ERR_SELF_GRANT:
    "Không được tự cấp hoặc tự sửa quyền cho chính mình. Nhờ quản trị viên khác thực hiện.",
  ERR_LAST_ADMIN:
    "Phải còn ít nhất 2 người quản trị. Không thể gỡ người quản trị cuối cùng.",
  ERR_SYSTEM_ROLE: "Không được sửa hoặc xóa vai trò hệ thống.",
  ERR_IMMUTABLE_LEDGER:
    "Sổ cái không được sửa hoặc xóa. Hãy ghi bút toán đảo rồi ghi bút toán mới.",
  ERR_DOC_POSTED:
    "Chứng từ đã ghi sổ nên không sửa hoặc xóa được. Chỉ được đảo chứng từ.",
  ERR_INVALID_STATUS:
    "Chứng từ đang ở trạng thái không phù hợp với thao tác này.",
  ERR_NEGATIVE_STOCK: "Không đủ tồn kho để xuất.",
  ERR_PERIOD_CLOSED: "Kỳ kế toán đã khóa, không ghi thêm được.",
  ERR_DAY_LOCKED: "Ngày nghiệp vụ đã khóa, không ghi thêm được.",
  ERR_FIFO_BACKDATED_FORBIDDEN:
    "Phương pháp FIFO không cho phép ghi nhận giao dịch lùi ngày.",
  ERR_FIFO_LAYER_CONSUMED:
    "Lớp hàng nhập này đã được xuất kho, không thể trả lại hoặc đảo chứng từ.",
  ERR_ALREADY_REVERSED:
    "Bút toán này đã được đảo trước đó, không thể đảo lần hai.",
  ERR_PERIOD_ALREADY_CLOSED: "Kỳ kế toán này đã được đóng trước đó.",
  ERR_WAREHOUSE_NOT_FOUND: "Không tìm thấy kho được yêu cầu.",
  ERR_LOCK_NOT_FOUND: "Không tìm thấy thông tin khóa ngày.",
  ERR_PERIOD_NOT_FOUND: "Không tìm thấy kỳ kế toán.",
  ERR_ITEM_HAS_STOCK_MOVES:
    "Vật tư đã có phát sinh giao dịch kho, không thể xóa (chỉ có thể chuyển sang ngừng hoạt động).",
  ERR_ITEM_UOM_CHANGE_FORBIDDEN:
    "Không thể đổi đơn vị tính lưu kho của vật tư đã có giao dịch kho.",
  ERR_COUNT_FREEZE:
    "Kho đang kiểm kê nên tạm dừng ghi nhận xuất nhập ở kho này.",
  ERR_OVER_CEILING_NO_REASON:
    "Giá vượt giá trần. Hãy nhập lý do vượt trần rồi gửi lại.",
  ERR_NOT_APPROVER: "Bạn không phải người duyệt được giao cho bước này.",
  ERR_PRICE_NOT_SET:
    "Đơn hàng còn dòng chưa có đơn giá. Hãy nhập giá cho các dòng giá tay trước khi gửi duyệt.",
  ERR_CHANNEL_NOT_ALLOWED: "Mặt hàng này không được mua theo kênh đã chọn.",
  ERR_PHOTO_REQUIRED: "Thiếu ảnh bắt buộc. Hãy chụp ảnh rồi gửi lại.",
  ERR_ATTACHMENT_IMMUTABLE:
    "Ảnh chứng từ không được sửa hoặc xóa. Hãy tải ảnh mới thay thế.",
  ERR_ATTACHMENT_INVALID_SHA: "Mã SHA-256 của ảnh không hợp lệ.",
  ERR_ATTACHMENT_PATH_MISMATCH:
    "Đường dẫn ảnh không thuộc khách sạn đang chọn.",
  ERR_PIN_INVALID: "Mã PIN không đúng. Vui lòng thử lại.",
  ERR_INVALID_PIN: "Mã PIN phải gồm 4–6 chữ số.",
  ERR_REASON_REQUIRED: "Vui lòng nhập lý do cho thao tác này.",
  ERR_ADVANCE_OVERDUE_BLOCK:
    "Bạn đang có tạm ứng quá hạn chưa quyết toán nên chưa được ứng thêm.",
  ERR_TEMP_ITEM_EXPIRED:
    "Mã tạm đã quá 72 giờ nên không dùng được nữa. Hãy chuẩn hóa mã trước khi dùng.",
  ERR_POS_IMPORT_REQUIRED:
    "Chưa tải file POS của ca này nên chưa đối soát được.",
  ERR_SERVICE_NOT_ACCEPTED:
    "Kỳ dịch vụ chưa được nghiệm thu nên chưa thanh toán được.",
  ERR_UOM_UNKNOWN:
    "Đơn vị chưa được khai báo quy đổi. Hãy bổ sung quy đổi trước khi dùng.",
  ERR_AGREEMENT_OVERLAP:
    "Đã có hợp đồng khung khác của cùng nhà cung cấp còn hiệu lực trong khoảng thời gian này cho cùng vật tư và đơn vị tính.",
  ERR_INVALID_VALUE:
    "Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường đã nhập.",
  ERR_SUPPLIER_HAS_BANK_ACCOUNTS:
    "Nhà cung cấp đã có tài khoản ngân hàng nên không thể xóa. Hãy tạm ngưng hoặc cấm nhà cung cấp thay vì xóa.",
} as const;

export const rpcErrorFallback =
  "Đã xảy ra lỗi. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên.";

/**
 * Dịch mã lỗi RPC sang câu tiếng Việt.
 * - `ERR_FORBIDDEN:po.approve` → câu chung + mã quyền thiếu để UI báo rõ.
 * - Mã chưa có trong bảng → câu chung, không lộ mã kỹ thuật ra giao diện.
 */
export function getRpcErrorMessage(code: string | null | undefined): string {
  if (!code) {
    return rpcErrorFallback;
  }
  const [base, detail] = code.split(":");
  if (base === "ERR_FORBIDDEN") {
    return detail
      ? `Bạn chưa được cấp quyền ${detail} để thực hiện thao tác này.`
      : rpcErrorMessages.ERR_FORBIDDEN;
  }
  if (base.startsWith("ERR_SOD_")) {
    return "Thao tác vi phạm quy tắc tách biệt nhiệm vụ: người thực hiện bước trước không được thực hiện bước này.";
  }
  return rpcErrorMessages[base] ?? rpcErrorFallback;
}
