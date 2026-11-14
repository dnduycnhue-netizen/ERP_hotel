import { z } from "zod";
import { vi } from "@/i18n/vi";

/** 4 loại chứng từ kho có form tạo + thao tác trạng thái (B-4, Q270). */
export const docKindSchema = z.enum([
  "waste",
  "requisition",
  "transfer",
  "purpose_issue",
]);
export type DocKind = z.infer<typeof docKindSchema>;

export const WASTE_REASONS = [
  "expired",
  "spoiled_storage",
  "broken",
  "guest_return",
  "other",
] as const;

export const PURPOSE_CODES = [
  "staff_meal",
  "vip_comp",
  "marketing",
  "meeting",
  "training",
  "repair",
  "other",
] as const;

const uuid = z.string().uuid(vi.common.invalidData);

export const docLineSchema = z.object({
  itemId: uuid,
  qty: z.number({ message: vi.common.invalidData }).positive(vi.common.invalidData),
  note: z.string().trim().max(500).nullable().optional(),
});

export const saveDocDraftSchema = z
  .object({
    kind: docKindSchema,
    propertyId: uuid,
    id: uuid.nullable().optional(),
    businessDate: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .nullable()
      .optional(),
    note: z.string().trim().max(1000).nullable().optional(),
    warehouseId: uuid.nullable().optional(),
    reasonCode: z.enum(WASTE_REASONS).nullable().optional(),
    photoIds: z.array(uuid).optional(),
    outletId: uuid.nullable().optional(),
    fromWarehouseId: uuid.nullable().optional(),
    toWarehouseId: uuid.nullable().optional(),
    purposeCode: z.enum(PURPOSE_CODES).nullable().optional(),
    costCenterId: uuid.nullable().optional(),
    expenseCategoryId: uuid.nullable().optional(),
    lines: z.array(docLineSchema).min(1, vi.inventory.doc.needLine),
  })
  .superRefine((v, ctx) => {
    const need = (ok: boolean, message: string) => {
      if (!ok) ctx.addIssue({ code: "custom", message });
    };
    if (v.kind === "waste") {
      need(!!v.warehouseId, vi.inventory.doc.needWarehouse);
      need(!!v.reasonCode, vi.inventory.doc.needReason);
    } else if (v.kind === "purpose_issue") {
      need(!!v.warehouseId, vi.inventory.doc.needWarehouse);
      need(!!v.purposeCode, vi.inventory.doc.needPurpose);
    } else if (v.kind === "transfer") {
      need(
        !!v.fromWarehouseId && !!v.toWarehouseId,
        vi.inventory.doc.needWarehouse,
      );
      need(
        v.fromWarehouseId !== v.toWarehouseId,
        vi.inventory.doc.sameWarehouse,
      );
    } else {
      need(!!v.outletId, vi.inventory.doc.needOutlet);
      need(
        !!v.fromWarehouseId && !!v.toWarehouseId,
        vi.inventory.doc.needWarehouse,
      );
      need(
        v.fromWarehouseId !== v.toWarehouseId,
        vi.inventory.doc.sameWarehouse,
      );
    }
  });
export type SaveDocDraftInput = z.infer<typeof saveDocDraftSchema>;

/** Thao tác đổi trạng thái không cần danh sách dòng. */
export const DOC_OPS = {
  waste: ["submit", "approve", "reject", "cancel"],
  requisition: ["submit", "approve", "reject", "cancel"],
  transfer: ["cancel"],
  purpose_issue: ["post", "cancel", "reverse"],
} as const;

export const docOpSchema = z.object({
  kind: docKindSchema,
  op: z.enum(["submit", "approve", "reject", "cancel", "post", "reverse"]),
  propertyId: uuid,
  id: uuid,
  /** Lý do (bắt buộc với cancel/reverse/reject) hoặc ghi chú duyệt. */
  reason: z.string().trim().max(500).nullable().optional(),
});
export type DocOpInput = z.infer<typeof docOpSchema>;

/** Xuất/chuyển/nhận theo từng dòng (số lượng theo ĐVT lưu kho). */
export const docLineQtySchema = z.object({
  kind: z.enum(["requisition_issue", "requisition_receive", "transfer_send", "transfer_receive"]),
  id: uuid,
  note: z.string().trim().max(500).nullable().optional(),
  lines: z
    .array(
      z.object({
        lineId: uuid,
        qtyStock: z.number({ message: vi.common.invalidData }).min(0),
      }),
    )
    .min(1, vi.inventory.doc.needLine),
});
export type DocLineQtyInput = z.infer<typeof docLineQtySchema>;
