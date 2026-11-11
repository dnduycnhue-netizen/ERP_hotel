"use server";
import { vi } from "@/i18n/vi";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callMasterRpc, type MasterActionResult } from "./rpc";
import {
  importAddUomAliasSchema,
  importBatchIdSchema,
  importBatchSummarySchema,
  importCreateBatchSchema,
  importResolveRowSchema,
  importSaveMappingSchema,
  type ImportBatchSummary,
} from "./import-schemas";

function firstErrorMessage(parsed: {
  success: false;
  error: { issues: { message?: string }[] };
}): string {
  return parsed.error.issues[0]?.message ?? vi.common.invalidData;
}

/** Buoc 1-2: tao phien import tu cac dong tho + validate ngay. */
export async function createImportBatchAction(
  input: unknown,
): Promise<MasterActionResult<ImportBatchSummary>> {
  const parsed = importCreateBatchSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: firstErrorMessage(parsed) };
  }
  const { propertyId, kind, fileName, mappingId, rows } = parsed.data;
  const supabase = await createClient();
  const res = await callMasterRpc<unknown>(supabase, "import_create_batch", {
    p_property_id: propertyId,
    p_kind: kind,
    p_file_name: fileName,
    p_mapping_id: mappingId ?? null,
    p_rows: rows,
  });
  if (!res.ok) return { ok: false, error: res.error };
  const summary = importBatchSummarySchema.safeParse(res.data as unknown);
  if (!summary.success) {
    return { ok: false, error: vi.master.importCheckResultUnreadable };
  }
  revalidatePath(`/[property]/master/import`);
  return { ok: true, data: summary.data };
}

/** Buoc 3: ghi quyet dinh xu ly 1 dong roi validate lai batch. */
export async function resolveImportRowAction(
  input: unknown,
): Promise<MasterActionResult<ImportBatchSummary>> {
  const parsed = importResolveRowSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: firstErrorMessage(parsed) };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<unknown>(supabase, "import_resolve_row", {
    p_batch_id: parsed.data.batchId,
    p_row_id: parsed.data.rowId,
    p_resolution: parsed.data.resolution,
  });
  if (!res.ok) return { ok: false, error: res.error };
  const summary = importBatchSummarySchema.safeParse(res.data as unknown);
  if (!summary.success) {
    return { ok: false, error: vi.master.importRecheckResultUnreadable };
  }
  return { ok: true, data: summary.data };
}

/** Buoc 4: ghi batch vao bang that (1 transaction). */
export async function commitImportBatchAction(
  input: unknown,
): Promise<
  MasterActionResult<{ created: number; skipped: number; merged: number }>
> {
  const parsed = importBatchIdSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: firstErrorMessage(parsed) };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{
    created: number;
    skipped: number;
    merged: number;
  }>(supabase, "import_commit_batch", { p_batch_id: parsed.data.batchId });
  if (!res.ok) return { ok: false, error: res.error };
  revalidatePath(`/[property]/master/import`);
  return { ok: true, data: res.data };
}

/** Huy 1 phien import chua ghi. */
export async function discardImportBatchAction(
  input: unknown,
): Promise<MasterActionResult<{ batch_id: string; status: string }>> {
  const parsed = importBatchIdSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: firstErrorMessage(parsed) };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ batch_id: string; status: string }>(
    supabase,
    "import_discard_batch",
    { p_batch_id: parsed.data.batchId },
  );
  if (!res.ok) return { ok: false, error: res.error };
  revalidatePath(`/[property]/master/import`);
  return { ok: true, data: res.data };
}

/** Luu mau anh xa cot de dung lai (upsert theo ten). */
export async function saveImportMappingAction(
  input: unknown,
): Promise<MasterActionResult<{ mapping_id: string }>> {
  const parsed = importSaveMappingSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: firstErrorMessage(parsed) };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ mapping_id: string }>(
    supabase,
    "import_save_mapping",
    {
      p_property_id: parsed.data.propertyId,
      p_kind: parsed.data.kind,
      p_name: parsed.data.name,
      p_column_map: parsed.data.columnMap,
      p_group_map: parsed.data.groupMap,
    },
  );
  if (!res.ok) return { ok: false, error: res.error };
  return { ok: true, data: res.data };
}

/** Them bien the viet don vi (khi gap UNKNOWN_UOM). */
export async function addUomAliasAction(
  input: unknown,
): Promise<MasterActionResult<{ alias: string; uom_code: string }>> {
  const parsed = importAddUomAliasSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: firstErrorMessage(parsed) };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ alias: string; uom_code: string }>(
    supabase,
    "import_add_uom_alias",
    {
      p_property_id: parsed.data.propertyId,
      p_alias: parsed.data.alias,
      p_uom_code: parsed.data.uomCode,
    },
  );
  if (!res.ok) return { ok: false, error: res.error };
  return { ok: true, data: res.data };
}
