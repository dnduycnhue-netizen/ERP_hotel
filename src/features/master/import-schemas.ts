import { z } from "zod";

// ---------------------------------------------------------------------------
// T-014: Import Excel 4 buoc cho vat tu & NCC
// ---------------------------------------------------------------------------

export const importKindSchema = z.enum(["items", "suppliers"]);
export type ImportKind = z.infer<typeof importKindSchema>;

/** 1 dong tho gui tu client: object JSON tu do (da map cot -> truong). */
export const importRawRowSchema = z
  .record(z.string(), z.unknown())
  .refine((row) => Object.keys(row).length > 0, {
    message: "Dòng trống không hợp lệ.",
  });
export type ImportRawRow = z.infer<typeof importRawRowSchema>;

export const importCreateBatchSchema = z.object({
  propertyId: z.string().uuid(),
  kind: importKindSchema,
  fileName: z
    .string()
    .trim()
    .min(1, "Thiếu tên file")
    .max(255, "Tên file tối đa 255 ký tự"),
  mappingId: z.string().uuid().optional().nullable(),
  rows: z
    .array(importRawRowSchema)
    .min(1, "File không có dòng dữ liệu nào.")
    .max(5000, "File tối đa 5000 dòng mỗi lần import."),
});
export type ImportCreateBatchInput = z.infer<typeof importCreateBatchSchema>;

export const importResolutionSchema = z
  .object({
    action: z.enum([
      "split",
      "merge",
      "set_code",
      "set_factor",
      "set_group",
      "set_uom",
      "skip",
      "keep",
    ]),
    new_code: z.string().trim().max(50).optional().nullable(),
    target_id: z.string().uuid().optional().nullable(),
    target_code: z.string().trim().max(50).optional().nullable(),
    factor: z.coerce.number().positive().optional().nullable(),
    group_id: z.string().uuid().optional().nullable(),
    stock_uom: z.string().trim().max(20).optional().nullable(),
    kind: z.enum(["company", "household", "individual_no_invoice"]).optional(),
  })
  .superRefine((v, ctx) => {
    if ((v.action === "split" || v.action === "set_code") && !v.new_code) {
      ctx.addIssue({
        code: "custom",
        message: "Tách/đổi mã cần nhập mã mới.",
        path: ["new_code"],
      });
    }
    if (v.action === "merge" && !v.target_id) {
      ctx.addIssue({
        code: "custom",
        message: "Gộp cần chọn vật tư/NCC đích.",
        path: ["target_id"],
      });
    }
    if (
      v.action === "set_factor" &&
      (v.factor === null || v.factor === undefined)
    ) {
      ctx.addIssue({
        code: "custom",
        message: "Đặt hệ số cần nhập hệ số.",
        path: ["factor"],
      });
    }
    if (v.action === "set_group" && !v.group_id) {
      ctx.addIssue({
        code: "custom",
        message: "Đổi nhóm cần chọn nhóm hàng.",
        path: ["group_id"],
      });
    }
    if (v.action === "set_uom" && !v.stock_uom) {
      ctx.addIssue({
        code: "custom",
        message: "Đổi đơn vị cần nhập đơn vị.",
        path: ["stock_uom"],
      });
    }
  });
export type ImportResolutionInput = z.infer<typeof importResolutionSchema>;

export const importResolveRowSchema = z.object({
  batchId: z.string().uuid(),
  rowId: z.string().uuid(),
  resolution: importResolutionSchema,
});
export type ImportResolveRowInput = z.infer<typeof importResolveRowSchema>;

export const importBatchIdSchema = z.object({
  batchId: z.string().uuid(),
});

export const importSaveMappingSchema = z.object({
  propertyId: z.string().uuid(),
  kind: importKindSchema,
  name: z
    .string()
    .trim()
    .min(1, "Thiếu tên mẫu ánh xạ")
    .max(100, "Tên mẫu tối đa 100 ký tự"),
  columnMap: z.record(z.string(), z.unknown()),
  groupMap: z.record(z.string(), z.string().uuid()),
});
export type ImportSaveMappingInput = z.infer<typeof importSaveMappingSchema>;

export const importAddUomAliasSchema = z.object({
  propertyId: z.string().uuid(),
  alias: z
    .string()
    .trim()
    .min(1, "Thiếu biến thể đơn vị")
    .max(30, "Biến thể tối đa 30 ký tự"),
  uomCode: z.string().trim().min(1, "Thiếu mã đơn vị chuẩn").max(20),
});
export type ImportAddUomAliasInput = z.infer<typeof importAddUomAliasSchema>;

// --- Ket qua RPC tra ve (jsonb) ------------------------------------------------

export const importIssueSchema = z.object({
  code: z.string(),
  field: z.string(),
  message: z.string(),
  severity: z.enum(["error", "warning"]),
  existing_id: z.string().optional(),
  existing_code: z.string().optional(),
});
export type ImportIssue = z.infer<typeof importIssueSchema>;

export const importCountsSchema = z.object({
  total: z.number(),
  skipped_blank: z.number(),
  ok: z.number(),
  warnings: z.number(),
  errors: z.number(),
  skipped: z.number(),
  merged: z.number(),
  committed: z.number(),
  dup_code: z.number(),
  near_dup: z.number(),
  no_code: z.number(),
  no_factor: z.number(),
  unknown_uom: z.number(),
  unknown_group: z.number(),
  created: z.number().optional(),
});
export type ImportCounts = z.infer<typeof importCountsSchema>;

export const importBatchSummarySchema = z.object({
  batch_id: z.string(),
  status: z.string(),
  counts: importCountsSchema,
});
export type ImportBatchSummary = z.infer<typeof importBatchSummarySchema>;

export const importRowSchema = z.object({
  id: z.string(),
  row_no: z.number(),
  raw_data: z.record(z.string(), z.unknown()),
  normalized_data: z.record(z.string(), z.unknown()),
  status: z.string(),
  issues: z.array(importIssueSchema),
  resolution: z.record(z.string(), z.unknown()),
  target_id: z.string().nullable(),
  target_code: z.string().nullable(),
});
export type ImportRow = z.infer<typeof importRowSchema>;

export const importBatchDetailSchema = z.object({
  batch: z.object({
    id: z.string(),
    kind: z.string(),
    file_name: z.string(),
    status: z.string(),
    row_count: z.number(),
    counts: importCountsSchema,
    created_at: z.string(),
    committed_at: z.string().nullable(),
    mapping_id: z.string().nullable(),
  }),
  rows: z.array(importRowSchema),
});
export type ImportBatchDetail = z.infer<typeof importBatchDetailSchema>;

export const importBatchListItemSchema = z.object({
  id: z.string(),
  kind: z.string(),
  file_name: z.string(),
  status: z.string(),
  row_count: z.number(),
  counts: importCountsSchema,
  created_at: z.string(),
  committed_at: z.string().nullable(),
});
export type ImportBatchListItem = z.infer<typeof importBatchListItemSchema>;

export const importMappingSchema = z.object({
  id: z.string(),
  kind: z.string(),
  name: z.string(),
  column_map: z.record(z.string(), z.unknown()),
  group_map: z.record(z.string(), z.string()),
  sample_header: z.array(z.string()).nullable(),
});
export type ImportMapping = z.infer<typeof importMappingSchema>;
