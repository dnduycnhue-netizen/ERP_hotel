import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");

/** 1 dòng hóa đơn: { po_line_id, qty, unit_price, vat_rate?, gr_line_id? }. */
export const invoiceSaveLineSchema = z.object({
  poLineId: uuidSchema,
  qty: z.number().positive("Số lượng phải lớn hơn 0."),
  unitPrice: z.number().nonnegative("Đơn giá không được âm."),
  vatRate: z.number().min(0).max(100).optional().nullable(),
  grLineId: uuidSchema.optional().nullable(),
});
export type InvoiceSaveLineInput = z.infer<typeof invoiceSaveLineSchema>;

/** Nhập hóa đơn mới (RPC `invoice_save_draft`). */
export const invoiceSaveDraftSchema = z.object({
  propertyId: uuidSchema,
  supplierId: uuidSchema,
  header: z.object({
    invoiceSymbol: z
      .string()
      .trim()
      .min(1, "Ký hiệu hóa đơn không được để trống."),
    invoiceNo: z.string().trim().min(1, "Số hóa đơn không được để trống."),
    invoiceDate: dateSchema,
    lookupCode: z.string().trim().optional().nullable(),
    xmlPath: z.string().trim().optional().nullable(),
  }),
  lines: z.array(invoiceSaveLineSchema).min(1, "Cần ít nhất một dòng hóa đơn."),
});
export type InvoiceSaveDraftInput = z.infer<typeof invoiceSaveDraftSchema>;

/** Khớp 3 chiều 1 hóa đơn (RPC `invoice_match`). */
export const invoiceMatchSchema = z.object({
  propertyId: uuidSchema,
  invoiceId: uuidSchema,
});
export type InvoiceMatchInput = z.infer<typeof invoiceMatchSchema>;

/** Duyệt hóa đơn đã khớp (RPC `invoice_approve`). */
export const invoiceApproveSchema = z.object({
  propertyId: uuidSchema,
  invoiceId: uuidSchema,
});
export type InvoiceApproveInput = z.infer<typeof invoiceApproveSchema>;

/** 1 dòng quyết toán tạm ứng: { amount, gr_id?, receipt_photo_id? }. */
export const advanceSettleLineSchema = z.object({
  amount: z.number().positive("Số tiền phải lớn hơn 0."),
  grId: uuidSchema.optional().nullable(),
  receiptPhotoId: uuidSchema.optional().nullable(),
});
export type AdvanceSettleLineInput = z.infer<typeof advanceSettleLineSchema>;

/** Quyết toán tạm ứng theo số thực nhận (RPC `advance_settle`). */
export const advanceSettleSchema = z.object({
  propertyId: uuidSchema,
  advanceId: uuidSchema,
  lines: z
    .array(advanceSettleLineSchema)
    .min(1, "Cần ít nhất một dòng chi thực tế."),
});
export type AdvanceSettleInput = z.infer<typeof advanceSettleSchema>;

/** 1 dòng đề nghị thanh toán: { invoice_id, amount }. */
export const paymentRequestLineSchema = z.object({
  invoiceId: uuidSchema,
  amount: z.number().positive("Số tiền phải lớn hơn 0."),
});
export type PaymentRequestLineInput = z.infer<typeof paymentRequestLineSchema>;

/** Tạo đề nghị thanh toán (RPC `payment_request_create`). */
export const paymentRequestCreateSchema = z.object({
  propertyId: uuidSchema,
  supplierId: uuidSchema,
  lines: z
    .array(paymentRequestLineSchema)
    .min(1, "Cần ít nhất một hóa đơn để đề nghị thanh toán."),
  dueDate: dateSchema.optional().nullable(),
});
export type PaymentRequestCreateInput = z.infer<
  typeof paymentRequestCreateSchema
>;

/** Duyệt/từ chối đề nghị thanh toán (RPC `payment_request_decide`). */
export const paymentRequestDecideSchema = z
  .object({
    propertyId: uuidSchema,
    requestId: uuidSchema,
    decision: z.enum(["approved", "rejected"]),
    comment: z
      .string()
      .trim()
      .max(1000, "Ghi chú tối đa 1000 ký tự.")
      .optional()
      .nullable(),
  })
  .superRefine((v, ctx) => {
    if (v.decision === "rejected" && !v.comment) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["comment"],
        message: "Từ chối đề nghị thanh toán phải nhập lý do.",
      });
    }
  });
export type PaymentRequestDecideInput = z.infer<
  typeof paymentRequestDecideSchema
>;

/** Ghi nhận đã thanh toán (RPC `payment_mark_paid`). */
export const paymentMarkPaidSchema = z.object({
  propertyId: uuidSchema,
  requestId: uuidSchema,
  bankRef: z
    .string()
    .trim()
    .min(1, "Số tham chiếu ngân hàng không được để trống."),
});
export type PaymentMarkPaidInput = z.infer<typeof paymentMarkPaidSchema>;

/** 1 dòng bảng kê: { item_desc, qty, unit_price }. */
export const noInvoiceListingLineSchema = z.object({
  itemDesc: z.string().trim().min(1, "Tên hàng không được để trống."),
  qty: z.number().positive("Số lượng phải lớn hơn 0."),
  unitPrice: z.number().nonnegative("Đơn giá không được âm."),
});
export type NoInvoiceListingLineInput = z.infer<
  typeof noInvoiceListingLineSchema
>;

/** Nhập bảng kê mua hàng không hóa đơn (RPC `no_invoice_listing_save`). */
export const noInvoiceListingSaveSchema = z.object({
  propertyId: uuidSchema,
  listing: z.object({
    sellerName: z.string().trim().min(1, "Tên người bán không được để trống."),
    purchaseDate: dateSchema,
    poId: uuidSchema.optional().nullable(),
    grId: uuidSchema.optional().nullable(),
    sellerAddress: z.string().trim().optional().nullable(),
    sellerIdNo: z.string().trim().optional().nullable(),
  }),
  lines: z
    .array(noInvoiceListingLineSchema)
    .min(1, "Cần ít nhất một dòng hàng."),
});
export type NoInvoiceListingSaveInput = z.infer<
  typeof noInvoiceListingSaveSchema
>;

/** Duyệt bảng kê (RPC `no_invoice_listing_approve`). */
export const noInvoiceListingApproveSchema = z.object({
  propertyId: uuidSchema,
  listingId: uuidSchema,
});
export type NoInvoiceListingApproveInput = z.infer<
  typeof noInvoiceListingApproveSchema
>;
