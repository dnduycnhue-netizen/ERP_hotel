import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { getRpcErrorMessage, rpcErrorFallback } from "@/i18n/errors.vi";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const migrationsDir = path.join(rootDir, "supabase", "migrations");

function collectSqlErrorCodes(): string[] {
  const codes = new Set<string>();
  for (const file of readdirSync(migrationsDir)) {
    if (!file.endsWith(".sql")) {
      continue;
    }
    const sql = readFileSync(path.join(migrationsDir, file), "utf8");
    for (const match of sql.matchAll(/\bERR_[A-Z0-9_]*[A-Z0-9]\b/g)) {
      codes.add(match[0]);
    }
  }
  return [...codes].sort();
}

describe("mã lỗi RPC trong migration", () => {
  const codes = collectSqlErrorCodes();

  it("tìm thấy mã lỗi trong migration", () => {
    expect(codes.length).toBeGreaterThan(50);
  });

  it("mọi mã đều có câu tiếng Việt riêng, không rơi vào câu chung", () => {
    const missing = codes.filter(
      (code) => getRpcErrorMessage(code) === rpcErrorFallback,
    );
    expect(missing).toEqual([]);
  });
});
