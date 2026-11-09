import "server-only";

import { createClient } from "@/lib/supabase/server";
import { callMasterRpc, type MasterActionResult } from "./rpc";
import {
  importBatchDetailSchema,
  importBatchListItemSchema,
  importMappingSchema,
  type ImportBatchDetail,
  type ImportBatchListItem,
  type ImportBatchSummary,
  type ImportMapping,
} from "./import-schemas";

/** Danh sach phien import gan day (20) cua to chuc. */
export async function listImportBatches(
  propertyId: string,
): Promise<ImportBatchListItem[]> {
  const supabase = await createClient();
  const res = await callMasterRpc<unknown>(supabase, "import_list_batches", {
    p_property_id: propertyId,
  });
  if (!res.ok) return [];
  const parsed = importBatchListItemSchema
    .array()
    .safeParse(res.data as unknown);
  return parsed.success ? parsed.data : [];
}

/** Chi tiet 1 phien import: batch + toan bo dong. */
export async function getImportBatch(
  batchId: string,
): Promise<ImportBatchDetail | null> {
  const supabase = await createClient();
  const res = await callMasterRpc<unknown>(supabase, "import_get_batch", {
    p_batch_id: batchId,
  });
  if (!res.ok) return null;
  const parsed = importBatchDetailSchema.safeParse(res.data as unknown);
  return parsed.success ? parsed.data : null;
}

/** Danh sach mau anh xa cot da luu cua to chuc. */
export async function listImportMappings(
  propertyId: string,
): Promise<ImportMapping[]> {
  const supabase = await createClient();
  const res = await callMasterRpc<unknown>(supabase, "import_list_mappings", {
    p_property_id: propertyId,
  });
  if (!res.ok) return [];
  const parsed = importMappingSchema.array().safeParse(res.data as unknown);
  return parsed.success ? parsed.data : [];
}

export type { MasterActionResult };
export type {
  ImportBatchSummary,
  ImportBatchDetail,
  ImportBatchListItem,
  ImportMapping,
};
