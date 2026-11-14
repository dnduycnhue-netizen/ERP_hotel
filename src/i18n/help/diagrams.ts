import { flow, type FlowDiagram } from "./types";

/**
 * Sơ đồ luồng cho từng bài (khóa = slug bài). Tách riêng khỏi nội dung bài để
 * sửa chữ không đụng sơ đồ và ngược lại. Quy ước: hình thoi vàng = điểm rẽ
 * nhánh; nét đứt đỏ = từ chối/quay lại; ô nét đứt xám = hệ thống tự làm.
 */

// ───────────── Mua hàng → nhận hàng → thanh toán ─────────────
const MUA = flow(
  "Giai đoạn 1 — Mua hàng",
  ["Thu mua / bộ phận", "Quản lý", "Chủ đầu tư"],
  [
    ["a1", 0, 0, "Lập yêu cầu mua", "start", "Nháp"],
    ["a2", 1, 1, "Quản lý duyệt yêu cầu?", "decision", "Chờ duyệt"],
    ["a3", 0, 2, "Tạo đơn mua (giá tự lấy theo hợp đồng / giá trần)", "step", "Nháp"],
    ["a4", 1, 3, "Duyệt đơn (bước 1)?", "decision", "Chờ duyệt"],
    ["a5", 2, 4, "Duyệt đơn (bước 2)", "decision"],
    ["a6", 0, 5, "Gửi cho nhà cung cấp", "end", "Đã gửi"],
  ],
  [
    ["a1", "a2"],
    ["a2", "a3", "Duyệt"],
    ["a2", "a1", "Từ chối", "bad"],
    ["a3", "a4", "Gửi duyệt"],
    ["a4", "a6", "Dưới 100 triệu"],
    ["a4", "a5", "Từ 100 triệu"],
    ["a5", "a6", "Duyệt"],
    ["a4", "a3", "Từ chối", "bad"],
  ],
);

const NHAN = flow(
  "Giai đoạn 2 — Nhận hàng mù",
  ["Người nhận hàng", "Thủ kho / Quản lý", "Hệ thống"],
  [
    ["r1", 0, 0, "Mở phiếu, cân, chụp ảnh, kiểm chất lượng", "start"],
    ["r2", 2, 1, "Lệch ngoài dung sai?", "decision"],
    ["r3", 0, 2, "Cân lại lần 2 (lần chốt)", "step"],
    ["r4", 2, 3, "Thừa quá trần dung sai?", "decision"],
    ["r5", 1, 4, "Duyệt phần dư kèm lý do", "step"],
    ["r6", 0, 5, "Ghi sổ bằng PIN", "step", "Đã ghi sổ"],
    ["r7", 2, 6, "Tồn kho tăng; đơn Đã nhận / Nhận một phần", "end"],
  ],
  [
    ["r1", "r2"],
    ["r2", "r6", "Trong dung sai"],
    ["r2", "r3", "Ngoài dung sai"],
    ["r3", "r4"],
    ["r4", "r6", "Không"],
    ["r4", "r5", "Có"],
    ["r5", "r6", "Duyệt"],
    ["r6", "r7"],
  ],
);

const THANH_TOAN = flow(
  "Giai đoạn 3 — Hóa đơn → Thanh toán",
  ["Kế toán", "Quản lý", "Người duyệt thanh toán", "Hệ thống"],
  [
    ["f1", 0, 0, "Nhập hóa đơn + Khớp 3 chiều", "start"],
    ["f2", 3, 1, "Khớp số lượng và đơn giá?", "decision"],
    ["f3", 0, 2, "Hóa đơn Tạm giữ: kiểm lệch, trao đổi NCC", "step", "Tạm giữ"],
    ["f4", 1, 2, "Duyệt hóa đơn", "decision", "Ghi công nợ"],
    ["f5", 0, 3, "Tạo đề nghị thanh toán", "step", "Chờ duyệt"],
    ["f6", 2, 4, "Duyệt thanh toán", "decision"],
    ["f7", 0, 5, "Chuyển tiền, bấm Đã thanh toán", "step", "Đã thanh toán"],
    ["f8", 3, 6, "Công nợ nhà cung cấp về đúng số", "end"],
  ],
  [
    ["f1", "f2"],
    ["f2", "f4", "Khớp"],
    ["f2", "f3", "Lệch", "bad"],
    ["f3", "f1", "Sửa rồi khớp lại", "bad"],
    ["f4", "f5", "Duyệt"],
    ["f5", "f6"],
    ["f6", "f7", "Duyệt"],
    ["f6", "f5", "Từ chối", "bad"],
    ["f7", "f8"],
  ],
);

// ───────────── Mua chợ & tạm ứng ─────────────
const MUA_CHO = flow(
  "Mua chợ và tạm ứng",
  ["Thu mua", "Quản lý", "Kế toán", "Người nhận hàng"],
  [
    ["m1", 0, 0, "Lập đơn chợ + nhập Tổng ước tính", "start", "Nháp"],
    ["m2", 1, 1, "Duyệt đơn chợ?", "decision"],
    ["m3", 0, 2, "Đề nghị tạm ứng", "step"],
    ["m4", 2, 3, "Chi tiền tạm ứng", "step"],
    ["m5", 3, 4, "Nhận hàng mù (số thực nhận)", "step"],
    ["m6", 0, 5, "Quyết toán theo biên nhận", "step"],
    ["m7", 2, 6, "Quá 24 giờ?", "decision"],
    ["m8", 2, 7, "Chặn tạm ứng mới của người đó", "end"],
    ["m9", 0, 7, "Đóng tạm ứng", "end"],
  ],
  [
    ["m1", "m2"],
    ["m2", "m3", "Duyệt"],
    ["m2", "m1", "Từ chối", "bad"],
    ["m3", "m4"],
    ["m4", "m5"],
    ["m5", "m6"],
    ["m6", "m7"],
    ["m7", "m8", "Có", "bad"],
    ["m7", "m9", "Không"],
  ],
);

// ───────────── Kho ─────────────
const LINH = flow(
  "Phiếu lĩnh kho",
  ["Bộ phận (bếp…)", "Quản lý", "Thủ kho", "Hệ thống"],
  [
    ["l1", 0, 0, "Lập phiếu lĩnh, gửi duyệt", "start"],
    ["l2", 1, 1, "Duyệt?", "decision"],
    ["l3", 2, 2, "Xuất kho (số thực xuất)", "step", "Đã xuất"],
    ["l4", 3, 3, "Hàng đi qua kho trung chuyển", "system"],
    ["l5", 0, 4, "Xác nhận nhận (thiếu thì ghi chú lệch)", "step"],
    ["l6", 3, 5, "Tồn kho bộ phận tăng", "end", "Đã nhận"],
  ],
  [
    ["l1", "l2"],
    ["l2", "l3", "Duyệt"],
    ["l2", "l1", "Từ chối", "bad"],
    ["l3", "l4"],
    ["l4", "l5"],
    ["l5", "l6"],
  ],
);

const HUY = flow(
  "Hủy hàng",
  ["Người đề xuất", "Quản lý", "Hệ thống"],
  [
    ["w1", 0, 0, "Lập phiếu, chọn lý do và số lượng", "start", "Nháp"],
    ["w2", 0, 1, "Chụp ảnh minh chứng", "step"],
    ["w3", 2, 2, "Đã có ảnh?", "decision"],
    ["w4", 1, 3, "Duyệt?", "decision", "Chờ duyệt"],
    ["w5", 2, 4, "Trừ tồn kho, ghi giá trị hủy vào báo cáo", "end", "Đã duyệt"],
  ],
  [
    ["w1", "w2"],
    ["w2", "w3", "Gửi duyệt"],
    ["w3", "w4", "Có"],
    ["w3", "w2", "Chưa — bị chặn", "bad"],
    ["w4", "w5", "Duyệt"],
    ["w4", "w1", "Từ chối", "bad"],
  ],
);

// ───────────── Nhà hàng ─────────────
const BAN_HANG = flow(
  "Từ món bán ra đến nguyên liệu và lãi gộp",
  ["Bếp trưởng", "Nhà hàng", "Hệ thống", "Quản lý"],
  [
    ["s1", 0, 0, "Khai báo món + công thức (định mức)", "start"],
    ["s2", 1, 1, "Ghi bán hàng (hoặc nạp file POS)", "step"],
    ["s3", 2, 2, "Tự sinh phiếu lĩnh nháp theo định mức", "system"],
    ["s4", 2, 3, "Nguyên liệu đủ tồn?", "decision"],
    ["s5", 2, 4, "Cảnh báo — bán vẫn được ghi", "system"],
    ["s6", 3, 5, "Duyệt phiếu lĩnh → thủ kho xuất", "step", "Kho giảm"],
    ["s7", 3, 6, "Xem lãi gộp (món biết giá vốn)", "end"],
  ],
  [
    ["s1", "s2"],
    ["s2", "s3"],
    ["s3", "s4"],
    ["s4", "s6", "Đủ"],
    ["s4", "s5", "Thiếu", "bad"],
    ["s5", "s6"],
    ["s6", "s7"],
  ],
);

// ───────────── Minibar ─────────────
const MINIBAR = flow(
  "Minibar: từ bổ sung đến thu tiền",
  ["Thủ kho", "Lễ tân", "Buồng phòng", "Quản lý"],
  [
    ["b1", 0, 0, "Nhận hàng vào kho minibar tổng", "start"],
    ["b2", 0, 1, "Bổ sung minibar cho phòng", "step"],
    ["b3", 1, 2, "Khách trả phòng: Yêu cầu kiểm", "step", "Chưa kiểm"],
    ["b4", 2, 3, "Kiểm (mù), nhập số thiếu, gửi kết quả", "step"],
    ["b5", 1, 4, "Phiếu hiện tiền theo bảng giá", "step", "Chờ thu tiền"],
    ["b6", 1, 5, "Thu / Miễn / Thu muộn?", "decision"],
    ["b7", 1, 6, "Bấm Đã thu + số folio", "end", "Xuất kho phòng, ghi doanh thu"],
    ["b8", 3, 6, "Miễn: Quản lý duyệt (có lý do)", "step"],
    ["b9", 3, 7, "Thu muộn / xóa sổ", "end"],
  ],
  [
    ["b1", "b2"],
    ["b2", "b3"],
    ["b3", "b4"],
    ["b4", "b5"],
    ["b5", "b6"],
    ["b6", "b7", "Thu"],
    ["b6", "b8", "Miễn"],
    ["b6", "b9", "Phát hiện muộn", "bad"],
  ],
);

// ───────────── Kiểm kê tháng ─────────────
const KIEM_KE = flow(
  "Kiểm kê tháng",
  ["Thủ kho", "Người đếm", "Quản lý", "Hệ thống"],
  [
    ["k1", 0, 0, "Mở đợt: ≥ 2 người đếm, có người độc lập", "start"],
    ["k2", 3, 1, "Kho đóng băng nhập/xuất", "system"],
    ["k3", 1, 2, "Đếm mù trên điện thoại", "step"],
    ["k4", 3, 3, "Lệch quá ngưỡng?", "decision"],
    ["k5", 1, 4, "Đếm lại một lần", "step"],
    ["k6", 1, 5, "Nộp đợt: mỗi người nhập PIN của mình", "step"],
    ["k7", 2, 6, "Duyệt điều chỉnh?", "decision"],
    ["k8", 3, 7, "Bút toán điều chỉnh theo giá bình quân", "system", "Tồn khớp"],
    ["k9", 0, 8, "Khóa đợt — kho hết đóng băng", "end"],
  ],
  [
    ["k1", "k2"],
    ["k2", "k3"],
    ["k3", "k4"],
    ["k4", "k5", "Có"],
    ["k4", "k6", "Không"],
    ["k5", "k6"],
    ["k6", "k7"],
    ["k7", "k8", "Duyệt"],
    ["k7", "k3", "Cần đếm lại", "bad"],
    ["k8", "k9"],
  ],
);

// ───────────── Duyệt chứng từ ─────────────
const DUYET = flow(
  "Duyệt chứng từ nhiều bước",
  ["Người lập", "Người duyệt", "Hệ thống"],
  [
    ["d1", 0, 0, "Lập chứng từ và Gửi duyệt", "start", "Chờ duyệt"],
    ["d2", 1, 1, "Xem nội dung, số tiền, ảnh — Duyệt?", "decision"],
    ["d3", 2, 2, "Còn bước duyệt sau?", "decision"],
    ["d4", 1, 3, "Người duyệt bước sau", "step"],
    ["d5", 2, 4, "Chứng từ có hiệu lực", "end", "Đã duyệt"],
  ],
  [
    ["d1", "d2"],
    ["d2", "d3", "Duyệt"],
    ["d2", "d1", "Từ chối + lý do", "bad"],
    ["d3", "d4", "Còn"],
    ["d3", "d5", "Hết"],
    ["d4", "d5"],
  ],
);

// ───────────── Khóa ngày / kỳ ─────────────
const KHOA = flow(
  "Khóa ngày và khóa kỳ",
  ["Kế toán / Quản lý", "Kế toán trưởng", "Hệ thống"],
  [
    ["x1", 0, 0, "Mọi chứng từ trong ngày đã ghi sổ", "start"],
    ["x2", 0, 1, "Khóa ngày theo kho", "step", "Ngày đã khóa"],
    ["x3", 2, 2, "Chặn ghi lùi ngày", "system"],
    ["x4", 1, 3, "Đủ điều kiện khóa kỳ?", "decision"],
    ["x5", 1, 4, "Khóa kỳ", "step", "Kỳ đã khóa"],
    ["x6", 0, 5, "Xuất dữ liệu kế toán", "end"],
  ],
  [
    ["x1", "x2"],
    ["x2", "x3"],
    ["x3", "x4"],
    ["x4", "x5", "Đủ"],
    ["x4", "x2", "Chưa đủ", "bad"],
    ["x5", "x6"],
  ],
);

// ───────────── Quy tắc: dung sai nhận hàng ─────────────
const DUNG_SAI = flow(
  "Quyết định khi nhận hàng lệch số lượng",
  ["Người nhận hàng", "Hệ thống"],
  [
    ["t1", 0, 0, "Nhập số cân (cân − bì)", "start"],
    ["t2", 1, 1, "Lệch ≤ dung sai (mặc định 5%)?", "decision"],
    ["t3", 1, 2, "Nhận đủ", "end"],
    ["t4", 0, 2, "Cân lại lần 2 (ghi đè lần 1)", "step"],
    ["t5", 1, 3, "Thiếu hay thừa?", "decision"],
    ["t6", 1, 4, "Thiếu: nhận số thực, đơn còn mở phần thiếu", "end"],
    ["t7", 0, 4, "Thừa: chỉ nhận đến trần dung sai; phần dư cần duyệt", "end"],
  ],
  [
    ["t1", "t2"],
    ["t2", "t3", "Trong dung sai"],
    ["t2", "t4", "Ngoài dung sai", "bad"],
    ["t4", "t5"],
    ["t5", "t6", "Thiếu"],
    ["t5", "t7", "Thừa"],
  ],
);

// ───────────── Quy tắc: duyệt theo hạn mức đơn mua ─────────────
const HAN_MUC = flow(
  "Bước duyệt đơn mua theo giá trị",
  ["Người lập đơn", "Quản lý", "Chủ đầu tư"],
  [
    ["h1", 0, 0, "Gửi duyệt đơn mua", "start"],
    ["h2", 1, 1, "Duyệt bước 1 (từ 0 đồng)", "decision"],
    ["h3", 2, 2, "Từ 100 triệu: duyệt bước 2", "decision"],
    ["h4", 0, 3, "Đơn đã duyệt — gửi nhà cung cấp", "end"],
  ],
  [
    ["h1", "h2"],
    ["h2", "h4", "Dưới 100 triệu"],
    ["h2", "h3", "Từ 100 triệu"],
    ["h3", "h4", "Duyệt"],
    ["h2", "h1", "Từ chối", "bad"],
  ],
);

// ───────────── Vòng việc hằng ngày theo vai trò (một hàng) ─────────────
function daily(title: string, steps: string[]): FlowDiagram {
  return flow(
    title,
    ["Việc hằng ngày"],
    steps.map((label, i) => [
      `v${i}`,
      0,
      i,
      label,
      i === 0 ? "start" : i === steps.length - 1 ? "end" : "step",
    ]),
    steps.slice(1).map((_, i) => [`v${i}`, `v${i + 1}`]),
  );
}

export const HELP_DIAGRAMS: Record<string, FlowDiagram[]> = {
  // luồng
  "luong-mua-hang-nhan-thanh-toan": [MUA, NHAN, THANH_TOAN],
  "luong-mua-cho-va-tam-ung": [MUA_CHO],
  "luong-linh-kho-dieu-chuyen-huy": [LINH, HUY],
  "luong-ban-hang-nha-hang": [BAN_HANG],
  "luong-minibar-tinh-tien": [MINIBAR],
  "luong-kiem-ke-thang": [KIEM_KE],
  // SOP
  "sop-nhan-hang-mu": [NHAN],
  "sop-kiem-ke-cuoi-thang": [KIEM_KE],
  "sop-huy-hang": [HUY],
  "sop-thanh-toan-ncc": [THANH_TOAN],
  "sop-kiem-minibar-tra-phong": [MINIBAR],
  "sop-duyet-chung-tu": [DUYET],
  "sop-khoa-ngay-ky": [KHOA],
  // quy tắc
  "quy-tac-dung-sai-can-lai": [DUNG_SAI],
  "quy-tac-duyet-nhieu-buoc": [HAN_MUC, DUYET],
  "quy-tac-doi-chieu-3-ben": [THANH_TOAN],
  "quy-tac-minibar-doi-soat": [MINIBAR],
  // phân hệ
  "phan-he-thu-mua": [MUA],
  "phan-he-nhan-hang": [NHAN],
  "phan-he-kho": [LINH, HUY],
  "phan-he-tai-chinh": [THANH_TOAN],
  "phan-he-kiem-ke": [KIEM_KE],
  "phan-he-nha-hang": [BAN_HANG],
  "phan-he-buong-phong-minibar": [MINIBAR],
  // vai trò: vòng việc hằng ngày
  "vai-tro-chu-dau-tu": [
    daily("Một ngày của Chủ đầu tư", [
      "Xem khối Sáng nay",
      "Xử lý cảnh báo đỏ",
      "Duyệt đơn mua từ 100 triệu",
      "Duyệt thanh toán (nếu được giao)",
      "Cuối tuần: xem báo cáo và nhật ký",
    ]),
    HAN_MUC,
  ],
  "vai-tro-quan-ly": [
    daily("Một ngày của Quản lý", [
      "Mở Chờ tôi duyệt",
      "Duyệt yêu cầu, đơn mua, phiếu lĩnh, hủy hàng",
      "Duyệt hóa đơn đã khớp",
      "Xem tồn kho, hủy hàng, cảnh báo",
      "Cuối tháng: duyệt điều chỉnh kiểm kê",
    ]),
    DUYET,
  ],
  "vai-tro-ke-toan": [
    daily("Một ngày của Kế toán", [
      "Nhập hóa đơn nhà cung cấp",
      "Khớp 3 chiều",
      "Tạo đề nghị thanh toán",
      "Chuyển tiền, bấm Đã thanh toán",
      "Cuối ngày: khóa ngày",
    ]),
    THANH_TOAN,
  ],
  "vai-tro-thu-mua-thu-kho": [
    daily("Một ngày của Thu mua & Thủ kho", [
      "Lập yêu cầu / đơn mua, gửi duyệt",
      "Gửi nhà cung cấp, theo dõi hàng về",
      "Xuất kho theo phiếu lĩnh đã duyệt",
      "Chuyển kho, xuất mục đích, hủy hàng",
      "Cuối tháng: mở đợt kiểm kê",
    ]),
    MUA,
  ],
  "vai-tro-nhan-hang": [
    daily("Một lần nhận hàng", [
      "Mở phiếu nhận, chọn kho",
      "Cân, chụp ảnh, kiểm chất lượng",
      "Cân lại nếu app yêu cầu",
      "Ghi sổ bằng PIN",
    ]),
    NHAN,
  ],
  "vai-tro-bep-nha-hang": [
    daily("Một ngày của Bếp & Nhà hàng", [
      "Xem Bếp: nguyên liệu cần chuẩn bị",
      "Lập phiếu lĩnh nguyên liệu",
      "Ghi bán hàng; mở / đóng buffet",
      "Lập phiếu hủy hàng hỏng, hết hạn",
    ]),
    BAN_HANG,
  ],
  "vai-tro-buong-phong": [
    daily("Một ngày của Buồng phòng", [
      "Mở ca xe đẩy, lĩnh đủ mức chuẩn",
      "Nhận yêu cầu kiểm minibar",
      "Kiểm minibar, gửi kết quả",
      "Cuối ca: đếm lại xe, đóng ca",
    ]),
    MINIBAR,
  ],
  "vai-tro-le-tan": [
    daily("Một lần khách trả phòng", [
      "Yêu cầu kiểm minibar",
      "Chờ buồng phòng gửi kết quả",
      "Thu tiền vào folio trên PMS",
      "Bấm Đã thu + số folio",
    ]),
    MINIBAR,
  ],
};
