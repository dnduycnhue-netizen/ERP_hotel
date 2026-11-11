import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);

const prLineSchema = z.object({
  id: uuidSchema.optional(),
  itemId: uuidSchema.optional().nullable(),
  description: z
    .string()
    .trim()
    .max(500, vi.procurement.descriptionMax500)
    .optional()
    .nullable(),
  qty: z.number().positive(vi.common.quantityPositive),
  uom: z.string().trim().min(1, vi.common.uomRequired),
  expenseCategoryId: uuidSchema.optional().nullable(),
  costCenterId: uuidSchema.optional().nullable(),
  reason: z
    .string()
    .trim()
    .max(500, vi.common.reasonMax500)
    .optional()
    .nullable(),
});

export const prSaveDraftSchema = z.object({
  propertyId: uuidSchema,
  id: uuidSchema.optional(),
  outletId: uuidSchema.optional().nullable(),
  kind: z.enum(["stock", "service"]).default("stock"),
  needDate: dateSchema.optional().nullable(),
  note: z
    .string()
    .trim()
    .max(1000, vi.common.noteMax1000)
    .optional()
    .nullable(),
  lines: z.array(prLineSchema),
});

export const prSubmitSchema = z.object({
  propertyId: uuidSchema,
  prId: uuidSchema,
});

export const prDecideSchema = z.object({
  propertyId: uuidSchema,
  prId: uuidSchema,
  decision: z.enum(["approved", "rejected"]),
  comment: z
    .string()
    .trim()
    .max(1000, vi.procurement.commentMax1000)
    .optional()
    .nullable(),
});

export const prCancelSchema = z.object({
  propertyId: uuidSchema,
  prId: uuidSchema,
  reason: z.string().trim().min(1, vi.common.cancelReasonRequired),
});

export const poCreateFromPrSchema = z.object({
  propertyId: uuidSchema,
  prLineIds: z.array(uuidSchema).min(1, vi.procurement.selectAtLeastOnePrLine),
  supplierId: uuidSchema,
  channel: z.enum(["contract", "quote", "market"]),
});

const poLineSchema = z.object({
  id: uuidSchema.optional(),
  itemId: uuidSchema.optional().nullable(),
  description: z
    .string()
    .trim()
    .max(500, vi.procurement.descriptionMax500)
    .optional()
    .nullable(),
  qty: z.number().positive(vi.common.quantityPositive),
  uom: z.string().trim().min(1, vi.common.uomRequired),
  unitPrice: z
    .number()
    .nonnegative(vi.common.unitPriceNonNegative)
    .optional()
    .nullable(),
  expenseCategoryId: uuidSchema.optional().nullable(),
  costCenterId: uuidSchema.optional().nullable(),
});

export const poSaveDraftSchema = z.object({
  propertyId: uuidSchema,
  id: uuidSchema,
  expectedDate: dateSchema.optional().nullable(),
  overCeilingReason: z
    .string()
    .trim()
    .max(1000, vi.procurement.overCeilingReasonMax1000)
    .optional()
    .nullable(),
  lines: z.array(poLineSchema),
});

export const poSubmitSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
});

export const approvalDecideSchema = z.object({
  propertyId: uuidSchema,
  docType: z.enum(["pr", "po"]),
  docId: uuidSchema,
  decision: z.enum(["approved", "rejected"]),
  comment: z
    .string()
    .trim()
    .max(1000, vi.procurement.commentMax1000)
    .optional()
    .nullable(),
});

export const poSendSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
});

export const poCloseSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
  reason: z.string().trim().min(1, vi.procurement.closeReasonRequired),
});

export const poCancelSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
  reason: z.string().trim().min(1, vi.common.cancelReasonRequired),
});

export const itemSearchSchema = z.object({
  propertyId: uuidSchema,
  search: z.string().trim().max(100, vi.common.keywordMax100),
});

/** Dong lenh mua cho (T-022): giong dong PO nhung khong co gia bat buoc. */
const marketOrderLineSchema = z.object({
  itemId: uuidSchema.optional().nullable(),
  description: z
    .string()
    .trim()
    .max(500, vi.procurement.descriptionMax500)
    .optional()
    .nullable(),
  qty: z.number().positive(vi.common.quantityPositive),
  uom: z.string().trim().min(1, vi.common.uomRequired),
  unitPrice: z
    .number()
    .nonnegative(vi.common.unitPriceNonNegative)
    .optional()
    .nullable(),
  expenseCategoryId: uuidSchema.optional().nullable(),
  costCenterId: uuidSchema.optional().nullable(),
});

/** Tao lenh mua cho + tam ung trong 1 giao dich (RPC `market_order_create`, T-022). */
export const marketOrderCreateSchema = z.object({
  propertyId: uuidSchema,
  lines: z
    .array(marketOrderLineSchema)
    .min(1, vi.procurement.form.needAtLeastOneLine),
  advanceAmount: z.number().positive(vi.procurement.advanceAmountPositive),
  purpose: z
    .string()
    .trim()
    .min(1, vi.procurement.advancePurposeRequired)
    .max(500, vi.procurement.purposeMax500),
  expectedDate: dateSchema.optional().nullable(),
});

/** De nghi tam ung doc lap (RPC `advance_request`, T-022). */
export const advanceRequestSchema = z.object({
  propertyId: uuidSchema,
  amount: z.number().positive(vi.procurement.advanceAmountPositive),
  purpose: z
    .string()
    .trim()
    .min(1, vi.procurement.advancePurposeRequired)
    .max(500, vi.procurement.purposeMax500),
});

/** Duyet/tu choi tam ung (RPC `advance_decide`, T-022). Tu choi can ly do
 * (server chan bang `ERR_REASON_REQUIRED` neu thieu). */
export const advanceDecideSchema = z.object({
  propertyId: uuidSchema,
  advanceId: uuidSchema,
  approved: z.boolean(),
  reason: z
    .string()
    .trim()
    .max(1000, vi.common.reasonMax1000)
    .optional()
    .nullable(),
});

/** Chi tien tam ung (RPC `advance_disburse`, T-022). */
export const advanceDisburseSchema = z.object({
  propertyId: uuidSchema,
  advanceId: uuidSchema,
  note: z
    .string()
    .trim()
    .max(1000, vi.common.noteMax1000)
    .optional()
    .nullable(),
});

export const approvalDelegationSaveSchema = z.object({
  orgId: uuidSchema,
  id: uuidSchema.optional(),
  fromUser: uuidSchema,
  toUser: uuidSchema,
  propertyId: uuidSchema.optional().nullable(),
  validFrom: dateSchema,
  validTo: dateSchema,
  reason: z
    .string()
    .trim()
    .max(500, vi.common.reasonMax500)
    .optional()
    .nullable(),
});

export const approvalDelegationDeleteSchema = z.object({
  orgId: uuidSchema,
  delegationId: uuidSchema,
});

export type PrSaveDraftInput = z.infer<typeof prSaveDraftSchema>;
export type PrSubmitInput = z.infer<typeof prSubmitSchema>;
export type PrDecideInput = z.infer<typeof prDecideSchema>;
export type PrCancelInput = z.infer<typeof prCancelSchema>;
export type PoCreateFromPrInput = z.infer<typeof poCreateFromPrSchema>;
export type PoSaveDraftInput = z.infer<typeof poSaveDraftSchema>;
export type PoSubmitInput = z.infer<typeof poSubmitSchema>;
export type ApprovalDecideInput = z.infer<typeof approvalDecideSchema>;
export type PoSendInput = z.infer<typeof poSendSchema>;
export type PoCloseInput = z.infer<typeof poCloseSchema>;
export type PoCancelInput = z.infer<typeof poCancelSchema>;
export type ApprovalDelegationSaveInput = z.infer<
  typeof approvalDelegationSaveSchema
>;
export type ApprovalDelegationDeleteInput = z.infer<
  typeof approvalDelegationDeleteSchema
>;
export type ItemSearchInput = z.infer<typeof itemSearchSchema>;
export type MarketOrderCreateInput = z.infer<typeof marketOrderCreateSchema>;
export type AdvanceRequestInput = z.infer<typeof advanceRequestSchema>;
export type AdvanceDecideInput = z.infer<typeof advanceDecideSchema>;
export type AdvanceDisburseInput = z.infer<typeof advanceDisburseSchema>;
