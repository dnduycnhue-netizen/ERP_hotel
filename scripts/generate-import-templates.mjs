// Sinh file mau Excel chuan cho import T-014 (docs/07-IMPORT-MIGRATION.md §5).
// Chay: node scripts/generate-import-templates.mjs
// Ghi vao public/templates/mau_vat_tu.xlsx va mau_ncc.xlsx.
// Tieu de cot tieng Viet khop voi anh xa tu dong trong import-wizard.tsx.
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const XLSX = require("xlsx");

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = join(root, "public", "templates");
mkdirSync(outDir, { recursive: true });

const ITEMS_HEADERS = [
  "Mã",
  "Tên",
  "Tên tiếng Anh",
  "Nhóm",
  "ĐVT kho",
  "ĐVT mua",
  "Hệ số mua → kho",
  "ĐVT công thức",
  "Hệ số kho → công thức",
  "Hàng chủ lực",
  "Hạn dùng (ngày)",
  "VAT (%)",
  "Mã cũ (Bravo)",
];

const ITEMS_EXAMPLES = [
  [
    "NVL0001",
    "Gạo ST25",
    "ST25 Rice",
    "NVL Khô",
    "kg",
    "bao",
    50,
    "g",
    1000,
    "x",
    365,
    8,
    "",
  ],
  ["CCDC0001", "Muỗng inox", "", "CCDC", "cái", "", "", "", "", "", "", 8, ""],
];

const SUPPLIERS_HEADERS = [
  "Mã",
  "Tên",
  "Mã số thuế",
  "Loại NCC",
  "Điện thoại",
  "Địa chỉ",
  "Hạn thanh toán (ngày)",
  "Ngân hàng",
  "Số TK",
  "Chủ TK",
];

const SUPPLIERS_EXAMPLES = [
  [
    "SUP0001",
    "Công ty TNHH Thực phẩm Sạch",
    "0101234567",
    "công ty",
    "0901000001",
    "Hội An, Quảng Nam",
    30,
    "Vietcombank",
    "1234567890",
    "CTY TNHH THUC PHAM SACH",
  ],
  [
    "SUP0002",
    "Hộ kinh doanh Lan",
    "",
    "hộ kinh doanh",
    "0901000002",
    "Đà Nẵng",
    15,
    "",
    "",
    "",
  ],
];

function writeTemplate(fileName, headers, examples) {
  const wb = XLSX.utils.book_new();
  const ws = XLSX.utils.aoa_to_sheet([headers, ...examples]);
  ws["!cols"] = headers.map(() => ({ wch: 18 }));
  XLSX.utils.book_append_sheet(wb, ws, "Du lieu");
  const path = join(outDir, fileName);
  XLSX.writeFile(wb, path);
  console.log(`wrote ${path}`);
}

writeTemplate("mau_vat_tu.xlsx", ITEMS_HEADERS, ITEMS_EXAMPLES);
writeTemplate("mau_ncc.xlsx", SUPPLIERS_HEADERS, SUPPLIERS_EXAMPLES);
