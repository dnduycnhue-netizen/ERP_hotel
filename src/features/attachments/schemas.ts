import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const docTypeSchema = z
  .string()
  .trim()
  .min(1, vi.attachments.docTypeRequired)
  .max(50, vi.attachments.docTypeMax50);

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
    .min(1, vi.attachments.filePathRequired)
    .max(500, vi.attachments.filePathMax500),
  sha256: z
    .string()
    .regex(/^[0-9a-f]{64}$/, vi.attachments.sha256InvalidFormat),
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
