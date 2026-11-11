import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";
import type { ExportPayload } from "./workbook";

type RpcClient = SupabaseClient<Database>;

export type ExportRpcResult =
  | { ok: true; data: ExportPayload }
  | {
      ok: false;
      /** Ma loi dang ERR_* (khong kem chi tiet). */
      code: string | null;
      /** Chi tiet sau dau ":" (vd ngay chua khoa), neu co. */
      detail: string | null;
      /** SQLSTATE tu PostgREST (42501 / 22023 / P0001...), neu co. */
      sqlstate: string | null;
      message: string;
    };

/**
 * Goi RPC xuat ke toan (T-043). `database.types.ts` chi sinh lai duoc khi co
 * DB local (Docker) nen 5 ham `export_*` chua co trong type sinh san;
 * ep kieu co chu dich tai dung mot cho nay thay vi rai khap noi.
 *
 * LUU Y: `supabase.rpc` doc `this.rest` nen KHONG duoc tach method ra khoi
 * client (`const caller = supabase.rpc` lam mat `this` va no
 * `TypeError: Cannot read properties of undefined (reading 'rest')` o
 * production — loi ERROR755103700 ngay 09/11/2026). Phai `.bind`.
 */
export async function callExportRpc(
  supabase: RpcClient,
  fn: string,
  entityId: string,
  from: string,
  to: string,
): Promise<ExportRpcResult> {
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: ExportPayload | null;
    error: { message: string; code?: string } | null;
  }>;
  const { data, error } = await caller(fn, {
    p_legal_entity_id: entityId,
    p_from: from,
    p_to: to,
  });
  if (error) {
    const parsed = parseRpcError(error.message);
    return {
      ok: false,
      code: parsed.code,
      detail: parsed.detail,
      sqlstate: error.code ?? null,
      message: error.message,
    };
  }
  return { ok: true, data: data as ExportPayload };
}

/**
 * Goi RPC tra jsonb bat ky (C3: `export_po_data`, `export_bank_transfer`,
 * `export_batch_record`). Cung quy tac bind nhu `callExportRpc` (xem ghi
 * chu o tren): `supabase.rpc` doc `this.rest` nen phai `.bind`.
 */
export type JsonRpcResult =
  | { ok: true; data: unknown }
  | {
      ok: false;
      /** Ma loi dang ERR_* (khong kem chi tiet). */
      code: string | null;
      /** Chi tiet sau dau ":" (vd danh sach so chung tu), neu co. */
      detail: string | null;
      /** SQLSTATE tu PostgREST (42501 / 22023 / P0001...), neu co. */
      sqlstate: string | null;
      message: string;
    };

export async function callJsonRpc(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<JsonRpcResult> {
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: unknown;
    error: { message: string; code?: string } | null;
  }>;
  const { data, error } = await caller(fn, args);
  if (error) {
    const parsed = parseRpcError(error.message);
    return {
      ok: false,
      code: parsed.code,
      detail: parsed.detail,
      sqlstate: error.code ?? null,
      message: error.message,
    };
  }
  return { ok: true, data };
}

/** "ERR_EXPORT_NOT_LOCKED: 03/12/2026" -> { code, detail }. */
function parseRpcError(message: string): {
  code: string | null;
  detail: string | null;
} {
  const match = message.match(/(ERR_[A-Z_]+)(?::\s*(.+))?/);
  if (!match) {
    return { code: null, detail: null };
  }
  return {
    code: match[1] ?? null,
    detail: (match[2] ?? "").trim() || null,
  };
}
