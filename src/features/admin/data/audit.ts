import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

type Client = SupabaseClient<Database>;

export const AUDIT_PAGE_SIZE = 50;

export type AuditFilters = {
  table?: string;
  action?: "INSERT" | "UPDATE" | "DELETE";
  /** Ngày nghiệp vụ YYYY-MM-DD (giờ Việt Nam). */
  from?: string;
  to?: string;
  page: number;
};

export type AuditRow = {
  id: number;
  table_name: string;
  row_id: string;
  action: string;
  at: string;
  actor: string | null;
  actor_name: string | null;
  old_data: unknown;
  new_data: unknown;
};

export type AuditPage = { rows: AuditRow[]; hasMore: boolean };

/**
 * Đọc audit_log qua RLS (`audit.view_all`). Người không có quyền nhận
 * danh sách rỗng — layout đã chặn trang, đây chỉ là lớp thứ hai.
 */
export async function listAuditLog(
  supabase: Client,
  filters: AuditFilters,
): Promise<AuditPage> {
  const offset = (filters.page - 1) * AUDIT_PAGE_SIZE;
  let request = supabase
    .from("audit_log")
    .select("id, table_name, row_id, action, at, actor, old_data, new_data")
    .order("at", { ascending: false })
    .order("id", { ascending: false })
    .range(offset, offset + AUDIT_PAGE_SIZE);
  if (filters.table) {
    request = request.eq("table_name", filters.table);
  }
  if (filters.action) {
    request = request.eq("action", filters.action);
  }
  if (filters.from) {
    request = request.gte("at", `${filters.from}T00:00:00+07:00`);
  }
  if (filters.to) {
    request = request.lt("at", `${nextDay(filters.to)}T00:00:00+07:00`);
  }
  const { data, error } = await request;
  if (error) {
    throw error;
  }
  const all = data ?? [];
  const hasMore = all.length > AUDIT_PAGE_SIZE;
  const page = all.slice(0, AUDIT_PAGE_SIZE);

  const actorIds = Array.from(
    new Set(page.map((r) => r.actor).filter((a): a is string => a !== null)),
  );
  const names = new Map<string, string>();
  if (actorIds.length > 0) {
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, full_name")
      .in("id", actorIds);
    for (const p of profiles ?? []) {
      names.set(p.id, p.full_name);
    }
  }
  return {
    hasMore,
    rows: page.map((r) => ({
      ...r,
      old_data: r.old_data as unknown,
      new_data: r.new_data as unknown,
      actor_name: r.actor ? (names.get(r.actor) ?? null) : null,
    })),
  };
}

function nextDay(ymd: string): string {
  const d = new Date(`${ymd}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}
