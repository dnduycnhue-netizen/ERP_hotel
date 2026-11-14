import type { HelpArticle, HelpBlock, HelpModule } from "./types";

function rule(input: {
  slug: string;
  title: string;
  summary: string;
  module?: HelpModule;
  perms?: string[];
  related: string[];
  rule: string;
  why: string;
  how: string[];
  exceptions?: string[];
  config?: string[];
}): HelpArticle {
  const blocks: HelpBlock[] = [
    { t: "note", tone: "rule", text: input.rule },
    { t: "h", text: "Vì sao có quy tắc này" },
    { t: "p", text: input.why },
    { t: "h", text: "Hệ thống thực thi thế nào" },
    { t: "ul", items: input.how },
  ];
  if (input.exceptions && input.exceptions.length > 0) {
    blocks.push({ t: "h", text: "Ngoại lệ" }, { t: "ul", items: input.exceptions });
  }
  if (input.config && input.config.length > 0) {
    blocks.push({ t: "h", text: "Cấu hình được" }, { t: "ul", items: input.config });
  }
  return {
    slug: input.slug,
    kind: "rule",
    title: input.title,
    summary: input.summary,
    module: input.module ?? "core",
    perms: input.perms ?? [],
    related: input.related,
    blocks,
  };
}

/** Quy tắc nghiệp vụ: luật hệ thống tự thực thi và lý do tồn tại. */
export const RULE_ARTICLES: HelpArticle[] = [
  rule({
    slug: "quy-tac-tach-biet-nhiem-vu",
    title: "Tách biệt nhiệm vụ (SoD)",
    summary: "Không ai vừa lập vừa duyệt, vừa mua vừa nhận, vừa nhập vừa duyệt cùng một chứng từ.",
    perms: ["pr.approve", "po.approve", "invoice.approve", "payment.approve", "receiving.post"],
    related: ["quy-tac-duyet-nhieu-buoc", "sop-duyet-chung-tu", "quy-tac-nhan-hang-mu-dem-mu"],
    rule: "Mỗi chứng từ phải đi qua **ít nhất hai người khác nhau** ở các khâu lập và duyệt/nhận. Hệ thống chặn người làm cả hai.",
    why: "Gian lận trong mua – nhận – thanh toán gần như luôn cần một người nắm nhiều khâu. Tách khâu khiến muốn gian lận phải có ít nhất hai người thông đồng.",
    how: [
      "Người lập yêu cầu mua/đơn mua/phiếu lĩnh/hủy hàng **không duyệt** phiếu của mình.",
      "Người tạo đơn mua **không nhận hàng** của đơn đó (kể cả đơn mua chợ: người mua chợ không nhận hàng chợ của mình).",
      "Người nhập hóa đơn **không duyệt** hóa đơn đó; người lập đề nghị thanh toán không duyệt đề nghị đó.",
      "Người nhận hàng chỉ **ghi sổ** phiếu do chính mình mở.",
      "Kiểm kê tháng cần ít nhất **một người đếm độc lập** — không có quyền ghi sổ nhận hàng/xuất kho tại kho đó.",
      "Kiểm tra nằm trong cơ sở dữ liệu, không phải chỉ ẩn nút: dù gọi trực tiếp cũng bị từ chối.",
    ],
    exceptions: ["Việc dùng ngoại lệ (nếu quản trị cho phép) luôn tạo cảnh báo **SOD_EXCEPTION_USED** gửi người phụ trách."],
    config: ["Cờ **tự duyệt** (phiếu mua, phiếu lĩnh, hủy hàng) ở Quản trị → Cài đặt → Bật/tắt ràng buộc; mặc định **chặn**. Đơn mua không bao giờ tự duyệt."],
  }),
  rule({
    slug: "quy-tac-duyet-nhieu-buoc",
    title: "Duyệt nhiều bước và hạn mức",
    summary: "Mỗi loại chứng từ có các bước duyệt theo vai trò và hạn mức; đổi ở Quy tắc duyệt.",
    perms: ["admin.approval_rules.manage", "po.approve", "po.approve.over_ceiling"],
    related: ["sop-duyet-chung-tu", "quy-tac-tach-biet-nhiem-vu", "quy-tac-gia-tran-gia-tay", "phan-he-quan-tri"],
    rule: "Chứng từ chỉ có hiệu lực khi **mọi bước duyệt áp dụng cho số tiền của nó** đã được duyệt bởi đúng vai trò của bước.",
    why: "Khoản nhỏ cần nhanh, khoản lớn cần nhiều mắt. Hạn mức giúp cân bằng tốc độ và kiểm soát.",
    how: [
      "**Yêu cầu mua, phiếu lĩnh, hủy hàng:** bước duyệt do Quản lý (mặc định).",
      "**Đơn mua:** bước 1 Quản lý (từ 0 đồng); bước 2 Chủ đầu tư **từ 100 triệu**. Hạn mức do Quản lý chỉnh ở Quy tắc duyệt.",
      "**Dòng giá tay hoặc vượt giá trần:** thêm bước duyệt, kèm lý do.",
      "Mọi bước có điều kiện số tiền ≤ tổng chứng từ đều áp dụng; người duyệt phải giữ **đúng vai trò của bước**.",
      "Duyệt xong mọi bước: chứng từ chuyển trạng thái; từ chối thì quay về cho người lập sửa.",
    ],
    config: ["Quản trị → **Quy tắc duyệt** (vai trò, hạn mức từng bước). Mọi thay đổi có nhật ký và cảnh báo."],
  }),
  rule({
    slug: "quy-tac-nhan-hang-mu-dem-mu",
    title: "Nhận hàng mù và đếm mù",
    summary: "Người nhận/đếm không thấy số lượng đặt, đơn giá, tồn lý thuyết — thực thi ở cơ sở dữ liệu.",
    perms: ["receiving.perform", "count.perform", "minibar.check"],
    related: ["sop-nhan-hang-mu", "sop-kiem-ke-cuoi-thang", "vai-tro-nhan-hang", "quy-tac-tach-biet-nhiem-vu"],
    rule: "Vai trò nhận hàng, đếm kho và kiểm minibar **không thể** đọc số lượng trên đơn mua, đơn giá hay tồn lý thuyết — không chỉ ẩn trên màn hình mà bị chặn ở cơ sở dữ liệu.",
    why: "Nếu người đếm biết số sổ, họ có thể \"đếm cho khớp\" thay vì đếm thật. Nếu người nhận biết số đặt, họ có thể thỏa thuận số lượng với người giao.",
    how: [
      "Dữ liệu trả về cho người nhận/đếm là **tối thiểu**: tên hàng, đơn vị, mẫu kiểm; không có số đặt, giá, số sổ.",
      "Quyền xem số lượng đặt/giá/tồn là các quyền riêng (xem đơn mua, xem giá, xem tồn), **không cấp** cho vai trò nhận/đếm.",
      "Đợt đếm lại không cho biết số sổ hay chiều lệch; lệch chỉ hiện cho người duyệt có quyền xem chênh lệch.",
      "Buồng phòng kiểm minibar chỉ nhập **số thiếu**, không xem tồn phòng.",
    ],
    exceptions: ["Thủ kho/Quản lý có quyền xem đơn để **duyệt nhận vượt** hoặc xử lý chênh lệch; họ không phải người nhận/đếm trong cùng chứng từ."],
  }),
  rule({
    slug: "quy-tac-dung-sai-can-lai",
    title: "Dung sai và cân lại khi nhận hàng",
    summary: "Lệch trong ±5% nhận bình thường; ngoài dung sai bắt buộc cân lại lần 2; thừa chỉ nhận đến trần.",
    perms: ["receiving.perform", "receiving.override_over_po"],
    related: ["sop-nhan-hang-mu", "quy-tac-anh-bang-chung", "luong-mua-hang-nhan-thanh-toan"],
    rule: "Số thực nhận so với đơn mua: **trong dung sai** thì nhận; **ngoài dung sai** lần 1 thì phải cân lại; sau lần 2 nhận số thực nhưng **không vượt trần dung sai**.",
    why: "Sai lệch nhỏ là bình thường (cân, hao nước). Sai lệch lớn phải được kiểm chứng hai lần trước khi chấp nhận, tránh cân sai hoặc cố ý.",
    how: [
      "Số thực nhận = cân cả bì − bì, quy sang đơn vị kho theo hệ số quy đổi.",
      "Lệch **≤ dung sai** (mặc định 5%): nhận đủ.",
      "Lệch ngoài dung sai ở **lần cân 1**: dòng ở trạng thái \"cần cân lại\"; cân lần 2 **ghi đè** lần 1 (lưu cả hai).",
      "Sau lần 2: thiếu thì nhận số thực, đơn còn mở phần thiếu; thừa thì chỉ nhận đến **số đặt × (1 + dung sai)**, phần dư cần người có quyền duyệt kèm lý do.",
      "Phần **hỏng** nhập riêng: không vào kho, thành phiếu trả nhà cung cấp; dung sai tính trên phần tốt.",
      "QC **Không đạt** cả dòng: không nhập kho, tự lập phiếu trả. QC **Chờ quyết định**: vào kho cách ly chờ xử lý trong 24 giờ.",
    ],
    config: ["Dung sai nhận hàng (mặc định 5%) ở Quản trị → Cài đặt, có thể theo nhóm hàng."],
  }),
  rule({
    slug: "quy-tac-anh-bang-chung",
    title: "Ảnh bằng chứng và ngoại lệ không camera",
    summary: "Ảnh chụp bằng camera trong app, giờ máy chủ; hàng bắt buộc ảnh; xác nhận không camera có lưu vết.",
    perms: ["receiving.perform", "receiving.review_photos", "waste.propose"],
    related: ["sop-nhan-hang-mu", "sop-huy-hang", "quy-tac-nhan-hang-mu-dem-mu"],
    rule: "Chứng từ nhạy cảm cần **ảnh chụp tại chỗ** trong app. Nếu thiết bị **không có camera**, nhận hàng cho phép tích xác nhận kèm **lý do**, và hệ thống luôn **lưu vết**.",
    why: "Ảnh là bằng chứng độc lập với lời khai. Ảnh cũ/ảnh dùng lại hoặc giờ thiết bị bị chỉnh sẽ làm mất giá trị — nên hệ thống kiểm soát nguồn và thời điểm.",
    how: [
      "Ảnh chỉ đến từ **camera trong app** (không chọn từ thư viện), nén và tính mã SHA-256 ngay trên máy.",
      "Thời điểm chụp lấy theo **giờ máy chủ**, không tin giờ thiết bị.",
      "Ảnh trùng mã với ảnh đã dùng trước đó tạo cảnh báo đỏ **ảnh dùng lại**.",
      "Nhận hàng: bắt buộc ít nhất một ảnh cho hàng thực phẩm/hàng chủ chốt, và ít nhất một ảnh cho cả phiếu khi ghi sổ.",
      "Không có camera: người nhận tích **xác nhận** và nhập lý do; lý do trống vẫn bị chặn. Mỗi lần dùng được ghi lại và có nhật ký để hậu kiểm.",
    ],
    exceptions: ["**Hủy hàng** vẫn bắt buộc ảnh, không có ngoại lệ không camera."],
  }),
  rule({
    slug: "quy-tac-gia-tran-gia-tay",
    title: "Giá đơn mua: tự động, giá trần, giá tay",
    summary: "Giá lấy theo hợp đồng khung → báo giá → giá trần; không có nguồn thì là giá tay và qua thêm duyệt.",
    perms: ["po.create", "po.approve", "price.agreement.manage"],
    related: ["phan-he-danh-muc", "phan-he-thu-mua", "luong-mua-cho-va-tam-ung"],
    rule: "Thu mua **không gõ giá tuỳ ý**. Giá dòng đơn mua tự lấy theo nguồn có kiểm soát; chỉ khi không có nguồn mới dùng giá tay và phải qua thêm duyệt.",
    why: "Giá là chỗ dễ thất thoát nhất (nâng giá, ăn chênh lệch). Đưa giá về hợp đồng/giá trần thì mọi lệch đều nhìn thấy.",
    how: [
      "Thứ tự nguồn giá: **hợp đồng khung còn hiệu lực → báo giá được chọn → giá trần** (hàng chợ).",
      "Không có nguồn: dòng là **giá tay**; đơn thường phải nhập giá mới gửi duyệt và qua thêm bước duyệt.",
      "Giá vượt trần: dòng đánh dấu **vượt giá trần**, bắt buộc lý do và thêm bước duyệt.",
      "Đơn mua **chợ** được miễn kiểm giá dòng (giá thực tế theo biên nhận lúc đi chợ), thay bằng tổng ước tính.",
      "Tăng giá nhập quá ngưỡng so với trung bình 7 ngày tạo cảnh báo **PRICE_SPIKE**.",
    ],
    config: ["Ngưỡng cảnh báo tăng giá (mặc định 10%) ở Cài đặt; giá trần và hợp đồng khung ở Danh mục → Giá."],
  }),
  rule({
    slug: "quy-tac-doi-chieu-3-ben",
    title: "Đối chiếu 3 bên (đơn mua – phiếu nhận – hóa đơn)",
    summary: "Hóa đơn chỉ ghi công nợ khi số lượng không vượt số đã nhận và đơn giá khớp đơn mua.",
    perms: ["invoice.manage", "invoice.approve"],
    related: ["sop-thanh-toan-ncc", "luong-mua-hang-nhan-thanh-toan", "phan-he-tai-chinh"],
    rule: "Chỉ trả tiền cho **hàng đã nhận thật theo giá đã thỏa thuận**. Hóa đơn lệch bị giữ lại cho đến khi xử lý.",
    why: "Hóa đơn nhà cung cấp có thể ghi nhiều hơn thực giao hoặc giá cao hơn đơn mua. Đối chiếu tự động chặn ở cửa.",
    how: [
      "Theo từng dòng: **số lượng hóa đơn ≤ số lượng đã nhận ghi sổ** (dung sai 0).",
      "**Đơn giá hóa đơn = đơn giá đơn mua ± 1%** (mặc định).",
      "Ngoài dung sai: hóa đơn **Tạm giữ**, không ghi công nợ, không đưa vào đề nghị thanh toán.",
      "Hóa đơn khớp và được duyệt: ghi công nợ phải trả. Trả hàng NCC giảm công nợ khi ghi sổ.",
      "Mua dịch vụ: thay phiếu nhận bằng **nghiệm thu**; chưa nghiệm thu thì không ghi công nợ.",
    ],
    config: ["Dung sai đơn giá hóa đơn (mặc định 1%) ở Cài đặt."],
  }),
  rule({
    slug: "quy-tac-so-cai-bat-bien",
    title: "Sổ cái bất biến và đảo bút toán",
    summary: "Mọi thay đổi tồn kho/tiền đi qua hàm ghi sổ; chứng từ đã ghi sổ không sửa, không xóa, chỉ đảo.",
    perms: ["purpose_issue.reverse", "receiving.reverse"],
    related: ["quy-tac-gia-von", "luong-linh-kho-dieu-chuyen-huy", "quy-tac-khoa-so-ngay-nghiep-vu"],
    rule: "Sổ kho, sổ công nợ và nhật ký **chỉ thêm, không sửa, không xóa**. Sai thì **đảo** (tạo bút toán ngược) rồi ghi lại đúng.",
    why: "Nếu sổ sửa được thì không còn gì để tin: một người có thể che dấu hao hụt bằng cách sửa số cũ. Bút toán đảo giữ nguyên dấu vết.",
    how: [
      "Client **không bao giờ** ghi trực tiếp vào bảng tồn kho, công nợ, giá vốn; chỉ qua các hàm ghi sổ có kiểm tra quyền và tách biệt nhiệm vụ.",
      "Chứng từ ở trạng thái **nháp** sửa được; đã **ghi sổ** chỉ **đảo**.",
      "Tồn kho **không bao giờ âm**: xuất quá tồn báo \"Không đủ tồn kho để xuất\".",
      "Mọi chuyển trạng thái được ghi nhật ký (ai, lúc nào, giá trị trước/sau).",
    ],
  }),
  rule({
    slug: "quy-tac-gia-von",
    title: "Giá vốn và định giá tồn kho",
    summary: "Bình quân gia quyền tức thời (hoặc FIFO theo pháp nhân); xuất mục đích không tính vào giá vốn hàng bán.",
    perms: ["stock.view_value"],
    related: ["phan-he-kho", "luong-ban-hang-nha-hang", "quy-tac-so-cai-bat-bien"],
    rule: "Giá xuất kho tính **tự động** theo phương pháp của pháp nhân; không ai nhập tay giá vốn.",
    why: "Giá vốn sai làm lãi gộp và chi phí sai. Tính tự động từ sổ cái giúp số liệu nhất quán và kiểm chứng được.",
    how: [
      "Phương pháp mặc định: **bình quân gia quyền tức thời** theo pháp nhân; có thể đặt **FIFO** trước khi phát sinh giao dịch.",
      "Giá nhập kho lấy từ **đơn giá đơn mua** (quy về đơn vị kho).",
      "**Xuất mục đích** (ăn ca, comp, sửa chữa…) không tính vào giá vốn hàng bán mà gắn cost center + khoản mục.",
      "Giá trị tồn và giá vốn chỉ hiện với người có **quyền xem giá trị**; người khác chỉ thấy số lượng.",
      "Lãi gộp nhà hàng chỉ tính trên món **biết giá vốn**.",
    ],
  }),
  rule({
    slug: "quy-tac-khoa-so-ngay-nghiep-vu",
    title: "Ngày nghiệp vụ và khóa sổ",
    summary: "Ngày nghiệp vụ theo giờ Việt Nam; khóa ngày/kỳ chặn ghi lùi; xuất kế toán chỉ cho kỳ đã khóa.",
    perms: ["day.lock", "period.close", "export.accounting"],
    related: ["sop-khoa-ngay-ky", "phan-he-bao-cao-canh-bao", "quy-tac-so-cai-bat-bien"],
    rule: "Mỗi bút toán có **ngày nghiệp vụ** theo giờ Việt Nam. Sau khi **khóa ngày/kỳ** không ghi thêm vào ngày đó; dữ liệu cho kế toán chỉ xuất từ kỳ đã khóa.",
    why: "Số liệu đã báo cáo hoặc đã chuyển kế toán không được thay đổi lặng lẽ. Khóa sổ đảm bảo cùng một con số cho mọi người.",
    how: [
      "Thời điểm chụp ảnh và nhận hàng lấy **giờ máy chủ**, không tin giờ thiết bị.",
      "**Khóa ngày** theo kho (Quản lý hoặc Kế toán); sau khóa không ghi ngày nghiệp vụ ≤ ngày đó. Mở khóa cần lý do và cảnh báo Chủ đầu tư.",
      "**Khóa kỳ** (Kế toán trưởng): cần kiểm kê tháng đã khóa, không còn đơn nhận một phần quá 30 ngày, không còn tạm ứng quá hạn.",
      "**Xuất dữ liệu kế toán:** chỉ các ngày/kỳ đã khóa; khoảng ngày có phát sinh chưa khóa bị từ chối kèm danh sách ngày.",
      "Kho đang **kiểm kê** đóng băng nhập/xuất cho đến khi khóa đợt.",
    ],
  }),
  rule({
    slug: "quy-tac-phan-quyen-theo-quyen",
    title: "Phân quyền theo quyền, không theo tên vai trò",
    summary: "Hệ thống kiểm mã quyền; vai trò chỉ là nhóm quyền do quản trị cấu hình; có thể giới hạn theo kho/ca.",
    perms: ["admin.roles.manage", "admin.users.manage", "admin.permissions.override"],
    related: ["phan-he-quan-tri", "vai-tro-chu-dau-tu", "quy-tac-tach-biet-nhiem-vu"],
    rule: "Mỗi chức năng kiểm **mã quyền** của người dùng tại khách sạn đó. Vai trò là tập quyền do quản trị đặt, **không** được hard-code theo tên.",
    why: "Mỗi chuỗi tổ chức khác nhau. Dùng quyền cho phép đổi cách chia việc mà không sửa mã, và giúp kiểm toán \"ai có thể làm gì\".",
    how: [
      "Menu và nút hiện theo **quyền** của bạn; quyền kiểm lại ở cơ sở dữ liệu khi gọi.",
      "Vai trò có thể gán theo **khách sạn, kho, ca, thời hạn**.",
      "Có 7 hồ sơ vai trò gọn (Chủ đầu tư, Quản lý, Kế toán, Thu mua & Thủ kho, Bếp/Nhà hàng, Buồng phòng, Lễ tân) và vai trò Nhận hàng riêng.",
      "Ghi đè quyền cho từng người (từ chối thắng cho phép) và mọi thay đổi **quyền quan trọng** tạo cảnh báo đỏ.",
      "Dữ liệu tách theo **pháp nhân**; danh mục vật tư và nhà cung cấp dùng chung cấp chuỗi.",
    ],
  }),
  rule({
    slug: "quy-tac-bat-tat-module",
    title: "Bật/tắt module theo khách sạn",
    summary: "Buồng phòng & Lễ tân, Nhà hàng có thể tắt: menu ẩn và hệ thống chặn ghi dữ liệu.",
    perms: ["admin.modules.manage"],
    related: ["phan-he-nha-hang", "phan-he-buong-phong-minibar", "phan-he-quan-tri"],
    rule: "Khách sạn không có nhà hàng hoặc buồng phòng có thể **tắt module** tương ứng. Tắt là chặn thật ở cơ sở dữ liệu, không chỉ ẩn menu.",
    why: "Đơn giản hóa giao diện cho khách sạn nhỏ và tránh dữ liệu rác ở phân hệ không dùng.",
    how: [
      "Tắt module: menu, báo cáo và bài hướng dẫn liên quan **ẩn**; ghi vào bảng của module bị từ chối với thông báo \"module đang tắt\".",
      "Kho và các chức năng lõi **vẫn dùng bình thường**; chỉ mục thuộc module (ví dụ nạp file POS) ẩn.",
      "Bật lại là dùng tiếp, **dữ liệu cũ còn nguyên**.",
      "Chỉ quản trị cấp chuỗi có quyền bật/tắt; thay đổi có nhật ký.",
    ],
  }),
  rule({
    slug: "quy-tac-minibar-doi-soat",
    title: "Minibar: tính tiền, miễn và đối soát",
    summary: "Bổ sung không phải bán; chỉ bán khi lễ tân xác nhận thu; miễn cần người duyệt; đối soát cuối ngày.",
    module: "hk_frontdesk",
    perms: ["minibar.charge.confirm", "minibar.waive.approve", "minibar.reconcile"],
    related: ["sop-kiem-minibar-tra-phong", "luong-minibar-tinh-tien", "phan-he-buong-phong-minibar"],
    rule: "Minibar **chỉ thành doanh thu và xuất kho khi lễ tân bấm \"Đã thu\"** kèm số folio. Đối soát cuối ngày phải cân.",
    why: "Minibar là điểm thất thoát nhỏ nhưng thường xuyên. Tách người kiểm (buồng phòng) và người thu (lễ tân), có đối soát, giúp phát hiện sớm.",
    how: [
      "Bổ sung minibar vào phòng là **chuyển kho** (kho minibar tổng → kho phòng), không phải bán.",
      "Giá tính theo **bảng giá minibar** hiệu lực, không nhập tay.",
      "**Miễn thu** (VIP, lỗi phòng) cần lý do và Quản lý duyệt; người đề nghị không duyệt.",
      "**Thu muộn** khi phát hiện sau khách đi; **xóa sổ** bởi Quản lý.",
      "**Đối soát cuối ngày:** ghi nhận = đã thu + miễn + thu muộn; lệch thì cảnh báo **MINIBAR_MISMATCH**.",
      "Nước miễn phí (nhóm complimentary) và nước bán là **hai mã khác nhau**.",
    ],
  }),
];
