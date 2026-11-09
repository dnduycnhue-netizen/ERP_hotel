import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const docTypeSchema = z
  .string()
  .trim()
  .min(1, "Loại chứng từ không được để trống.")
  .max(50, "Loại chứng từ tối đa 50 ký tự.");

export const attachmentPrepareUploadSchema = z.object({
  propertyId: uuidSchema,
  docType: docTypeSchema,
});

export const attachmentRegisterSchema = z.object({
  propertyId: uuidSchema,
  bucket: z.enum(["evidence", "attachments"]),
  path: z
    .string()
    .trim()
    .min(1, "Đường dẫn file không được để trống.")
    .max(500, "Đường dẫn file tối đa 500 ký tự."),
  sha256: z
    .string()
    .regex(/^[0-9a-f]{64}$/, "Mã SHA-256 không đúng định dạng."),
  docType: docTypeSchema,
  docId: uuidSchema,
  lineId: uuidSchema.optional().nullable(),
  deviceTime: z.string().datetime().optional().nullable(),
  deviceInfo: z.record(z.string(), z.unknown()).optional().nullable(),
});

export const attachmentListSchema = z.object({
  propertyId: uuidSchema,
  docType: docTypeSchema,
  docId: uuidSchema,
});

export type AttachmentPrepareUploadInput = z.infer<
  typeof attachmentPrepareUploadSchema
>;
export type AttachmentRegisterInput = z.infer<typeof attachmentRegisterSchema>;
export type AttachmentListInput = z.infer<typeof attachmentListSchema>;
