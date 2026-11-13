/**
 * Tóm tắt thay đổi của một dòng audit_log: chỉ liệt kê cột có giá trị khác
 * nhau giữa old_data và new_data (INSERT: toàn bộ cột mới; DELETE: toàn bộ
 * cột cũ). Chỉ để hiển thị — không tính tiền hay số lượng ở đây.
 */
export type AuditChange = {
  field: string;
  before: string | null;
  after: string | null;
};

const IGNORED_FIELDS = new Set(["updated_at"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function show(value: unknown): string | null {
  if (value === undefined || value === null) {
    return null;
  }
  const text = typeof value === "string" ? value : JSON.stringify(value);
  return text.length > 200 ? `${text.slice(0, 200)}…` : text;
}

export function diffAuditRow(
  oldData: unknown,
  newData: unknown,
): AuditChange[] {
  const before = isRecord(oldData) ? oldData : {};
  const after = isRecord(newData) ? newData : {};
  const fields = Array.from(
    new Set([...Object.keys(before), ...Object.keys(after)]),
  ).sort();
  const changes: AuditChange[] = [];
  for (const field of fields) {
    if (IGNORED_FIELDS.has(field)) {
      continue;
    }
    const b = show(before[field]);
    const a = show(after[field]);
    if (b !== a) {
      changes.push({ field, before: b, after: a });
    }
  }
  return changes;
}
