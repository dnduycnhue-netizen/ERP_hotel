import { z } from "zod";

/**
 * Tham so query cho GET /api/export/[kind] (T-043).
 * entity = legal_entity_id (uuid); from/to dang yyyy-mm-dd.
 * Kiem tra khoa so + pham vi 366 ngay nam trong RPC (can doc trang thai
 * khoa tu DB), o day chi kiem tra dinh dang.
 */
export const exportParamsSchema = z.object({
  entity: z.string().uuid(),
  from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export type ExportParams = z.infer<typeof exportParamsSchema>;
