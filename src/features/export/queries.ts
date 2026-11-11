import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";

/* ------------------------------------------------------------------ */
/* Hub xuất file tài chính (C4): quyền xem từng mục, pháp nhân của      */
/* khách sạn, lịch sử xuất từ `export_batches` (C3, migration          */
/* 20261109522000).                                                     */
/*                                                                      */
/* `export_batches` chưa có trong `database.types.ts` (chỉ sinh lại    */
/* được khi có DB local — tiền lệ finance/queries.ts) nên đọc qua       */
/* client untyped, ép kiểu có chủ đích tại đúng chỗ đọc dưới đây.       */
/* Nếu bảng chưa có (C3 chưa merge/áp) thì truy vấn lỗi → lịch sử trả   */
/* về "không đọc được" để màn hình vẫn hiện các mục xuất khác thay vì   */
/* vỡ cả trang.                                                         */
/* ------------------------------------------------------------------ */

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

/** Quyền xuất file của người gọi tại 1 property (qua `my_permissions`). */
export type ExportPerms = {
  /** Xuất Excel kế toán T-043 (`export.accounting`). */
  canExportAccounting: boolean;
  /** Tải PDF PO: cần `po.view` (hoặc po.create/approve/close) + `po.view_price`. */
  canExportPo: boolean;
  /** Xuất file chuyển khoản: `export.accounting` hoặc `payment.mark_paid`. */
  canExportBankTransfer: boolean;
  /** Xem lịch sử xuất (theo policy SELECT của `export_batches`, C3). */
  canViewHistory: boolean;
};

export async function getExportPerms(propertyId: string): Promise<ExportPerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set<string>(data ?? []);
  const canViewPo =
    perms.has("po.view") ||
    perms.has("po.create") ||
    perms.has("po.approve") ||
    perms.has("po.close");
  return {
    canExportAccounting: perms.has("export.accounting"),
    canExportPo: canViewPo && perms.has("po.view_price"),
    canExportBankTransfer:
      perms.has("export.accounting") || perms.has("payment.mark_paid"),
    canViewHistory:
      perms.has("export.accounting") ||
      perms.has("po.view") ||
      perms.has("payment.approve") ||
      perms.has("payment.mark_paid"),
  };
}

/** Pháp nhân của khách sạn (tham số `entity` cho xuất T-043). */
export type PropertyLegalEntity = {
  id: string;
  code: string;
  name: string;
};

export async function getPropertyLegalEntity(
  propertyId: string,
): Promise<PropertyLegalEntity | null> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("properties")
    .select("legal_entity:legal_entities(id, code, name)")
    .eq("id", propertyId)
    .single();
  const entity = (
    data as {
      legal_entity: PropertyLegalEntity | null;
    } | null
  )?.legal_entity;
  return entity ?? null;
}

export type ExportBatchKind =
  | "po-pdf"
  | "bank-transfer"
  | "goods-receipts"
  | "stock-issues"
  | "invoices"
  | "payables"
  | "advances";

/** 1 dòng lịch sử xuất (đã gắn số chứng từ để đọc được). */
export type ExportBatchRow = {
  id: string;
  kind: ExportBatchKind;
  ref_type: "purchase_order" | "payment_request" | "legal_entity";
  ref_id: string;
  /** Số PO / số đề nghị; null khi chứng từ đã xóa hoặc không có quyền xem. */
  ref_doc_no: string | null;
  exported_by: string;
  exported_at: string;
  file_hash: string | null;
  note: string | null;
};

type RawExportBatchRow = Omit<ExportBatchRow, "ref_doc_no">;

type DocNoMap = Map<string, string>;

async function fetchDocNos(
  client: UntypedClient,
  table: string,
  ids: string[],
): Promise<DocNoMap> {
  const map: DocNoMap = new Map();
  if (ids.length === 0) return map;
  const { data } = await client.from(table).select("id, doc_no").in("id", ids);
  for (const row of (data ?? []) as Array<{ id: string; doc_no: string }>) {
    map.set(row.id, row.doc_no);
  }
  return map;
}

/**
 * Lịch sử xuất gần đây của 1 property (mới nhất trước). Lỗi đọc (vd bảng
 * `export_batches` chưa có vì C3 chưa áp) trả `ok: false` để trang hub
 * hiện ghi chú thay vì vỡ.
 */
export async function listExportHistory(
  propertyId: string,
  limit = 50,
): Promise<
  { ok: true; data: ExportBatchRow[] } | { ok: false; error: string }
> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("export_batches")
    .select(
      "id, kind, ref_type, ref_id, exported_by, exported_at, file_hash, note",
    )
    .eq("property_id", propertyId)
    .order("exported_at", { ascending: false })
    .limit(limit);
  if (error) {
    return { ok: false, error: vi.export.hub.historyUnavailable };
  }
  const rows = (data ?? []) as RawExportBatchRow[];
  const [poDocNos, requestDocNos] = await Promise.all([
    fetchDocNos(
      client,
      "purchase_orders",
      rows.filter((r) => r.ref_type === "purchase_order").map((r) => r.ref_id),
    ),
    fetchDocNos(
      client,
      "payment_requests",
      rows.filter((r) => r.ref_type === "payment_request").map((r) => r.ref_id),
    ),
  ]);
  return {
    ok: true,
    data: rows.map((r) => ({
      ...r,
      ref_doc_no:
        r.ref_type === "purchase_order"
          ? (poDocNos.get(r.ref_id) ?? null)
          : r.ref_type === "payment_request"
            ? (requestDocNos.get(r.ref_id) ?? null)
            : null,
    })),
  };
}

/**
 * Map đề nghị thanh toán -> lần xuất chuyển khoản gần nhất (để cảnh báo
 * "đã xuất trước đây" trước khi xuất lại). Trả `ok: false` khi không đọc
 * được bảng `export_batches` (C3 chưa áp) — màn hình hiện ghi chú thay
 * vì cảnh báo sai là "chưa xuất".
 */
export async function listBankTransferExportedAt(
  propertyId: string,
): Promise<
  { ok: true; data: Record<string, string> } | { ok: false; error: string }
> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("export_batches")
    .select("ref_id, exported_at")
    .eq("property_id", propertyId)
    .eq("kind", "bank-transfer")
    .eq("ref_type", "payment_request")
    .order("exported_at", { ascending: false })
    .limit(500);
  if (error) {
    return { ok: false, error: getRpcErrorMessage(null) };
  }
  const map: Record<string, string> = {};
  for (const row of (data ?? []) as Array<{
    ref_id: string;
    exported_at: string;
  }>) {
    map[row.ref_id] ??= row.exported_at;
  }
  return { ok: true, data: map };
}
