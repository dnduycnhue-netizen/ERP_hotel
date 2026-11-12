import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// Luật vàng #11 (AGENTS.md): chuỗi hiển thị tiếng Việt phải nằm trong
// src/i18n/vi.ts (hoặc errors.vi.ts). Quy tắc dưới chặn chuỗi/JSX text chứa
// chữ cái tiếng Việt có dấu nằm ngoài các file đó. Comment không bị chặn.
const VIETNAMESE_CHARS =
  "[ạảãàáâậầấẩẫăắằặẳẵéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ]";
const hardcodedVietnamese = (selectorType, attr) => ({
  selector: `${selectorType}[${attr}=/${VIETNAMESE_CHARS}/i]`,
  message:
    "Không hard-code chuỗi tiếng Việt trong code. Thêm vào src/i18n/vi.ts (hoặc errors.vi.ts) rồi dùng vi.<nhóm>.<khóa>.",
});

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    files: ["src/**/*.{ts,tsx}"],
    ignores: [
      "src/i18n/**",
      // Trang trình diễn thành phần dùng nội bộ, không phải màn hình người dùng.
      "src/app/dev/**",
    ],
    rules: {
      "no-restricted-syntax": [
        "error",
        hardcodedVietnamese("Literal", "value"),
        hardcodedVietnamese("JSXText", "value"),
        hardcodedVietnamese("TemplateElement", "value.raw"),
      ],
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // Playwright artifacts: gitignored but ESLint still scans them;
    // without these, `pnpm lint` fails locally after any e2e run
    // (133 errors from playwright-report/ alone, 11/11/2026).
    "playwright-report/**",
    "test-results/**",
  ]),
]);

export default eslintConfig;
