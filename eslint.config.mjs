import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
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
