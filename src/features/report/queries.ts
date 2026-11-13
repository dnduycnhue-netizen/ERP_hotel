import "server-only";

import { getModuleAwarePermissions } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";
import { callReportRpc } from "./rpc";
import { REPORT_CODES, getReportMeta, type ReportCode } from "./definitions";
import { reportParamsSchema, type ReportParams } from "./schemas";

export type ReportRow = Record<string, unknown>;

export type ReportPayload = {
  ok: boolean;
  code: ReportCode;
  params: Record<string, unknown>;
  rows?: ReportRow[];
  totals?: Record<string, unknown>;
  extra?: Record<string, unknown>;
  notes?: string[];
  [key: string]: unknown;
};

export type ReportPerms = Record<ReportCode, boolean>;

/** Ngày hôm nay theo giờ Việt Nam (YYYY-MM-DD). */
export function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/** Tháng hiện tại theo Asia/Ho_Chi_Minh (YYYY-MM). */
export function monthVn(): string {
  return todayVn().slice(0, 7);
}

/** Ngày đầu tháng hiện tại theo Asia/Ho_Chi_Minh (YYYY-MM-DD). */
export function monthStartVn(): string {
  return `${monthVn()}-01`;
}

/**
 * Quyền xem từng báo cáo của người dùng hiện tại trên khách sạn đang chọn.
 * Dùng has_perm qua my_permissions (tiền lệ finance/getFinancePerms), đã bỏ
 * quyền của module đang tắt.
 */
export async function getReportPerms(propertyId: string): Promise<ReportPerms> {
  const supabase = await createClient();
  // Q254: báo cáo của module đang tắt (minibar, amenities, doanh thu F&B)
  // bị bỏ khỏi danh sách quyền nên không hiện và không mở được qua URL.
  const perms = new Set<string>(
    await getModuleAwarePermissions(supabase, propertyId),
  );
  const out = {} as ReportPerms;
  for (const code of REPORT_CODES) {
    out[code] = perms.has(getReportMeta(code).permission);
  }
  return out;
}

/** Pháp nhân của khách sạn (để nút xuất Excel T-043 cần entity). */
export async function getPropertyEntity(
  propertyId: string,
): Promise<string | null> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("properties")
    .select("legal_entity_id")
    .eq("id", propertyId)
    .single();
  return (
    (data as { legal_entity_id: string | null } | null)?.legal_entity_id ?? null
  );
}

/**
 * Đọc 1 báo cáo qua report_get. Tham số mặc định theo loại báo cáo:
 * range = từ đầu tháng tới hôm nay; as_of/date = hôm nay; month = tháng nay.
 * Ném Error mang mã ERR_* khi RPC từ chối (trang gọi bắt và hiện ErrorState).
 */
export async function getReport(
  propertyId: string,
  code: ReportCode,
  rawParams: Record<string, string | undefined>,
): Promise<ReportPayload> {
  const meta = getReportMeta(code);
  const parsed = reportParamsSchema.safeParse(rawParams);
  const input: ReportParams = parsed.success ? parsed.data : {};

  const params: Record<string, unknown> = {};
  if (meta.paramKind === "range") {
    params.from = input.from ?? monthStartVn();
    params.to = input.to ?? todayVn();
    if (input.warehouse_id) params.warehouse_id = input.warehouse_id;
    if (input.supplier_id) params.supplier_id = input.supplier_id;
  } else if (meta.paramKind === "as_of") {
    params.as_of = input.as_of ?? todayVn();
  } else if (meta.paramKind === "month") {
    params.month = input.month ?? monthVn();
  } else {
    params.date = input.date ?? todayVn();
  }

  const data = await callReportRpc(propertyId, code, params);
  if (!data || data.ok !== true) {
    throw new Error("ERR_UNKNOWN");
  }
  return data as unknown as ReportPayload;
}
