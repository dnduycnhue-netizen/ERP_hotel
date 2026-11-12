"use server";

import { z } from "zod";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

const lineSchema = z.object({
  bill_no: z.string().min(1),
  business_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  shift: z.string().min(1),
  time: z.string(),
  outlet: z.string(),
  item_code: z.string().min(1),
  item_name: z.string(),
  qty: z.string(),
  unit_price: z.string(),
  amount: z.string(),
  payment: z.string(),
});

const importSchema = z.object({
  propertyId: z.string().uuid(),
  fileName: z.string().min(1).max(255),
  sha256: z.string().regex(/^[0-9a-f]{64}$/),
  lines: z.array(lineSchema).min(1).max(20000),
});

export type PosImportInput = z.infer<typeof importSchema>;

export type PosImportResult =
  | {
      ok: true;
      data: { imports: number; rows: number; unmappedCodes: string[] };
    }
  | { ok: false; error: string };

/** Nạp file POS của ca (RPC `pos_import_commit`, Q34). */
export async function importPosAction(
  input: PosImportInput,
): Promise<PosImportResult> {
  const parsed = importSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: vi.inventory.posImport.invalidFile };
  }
  const supabase = await createClient();
  // `.bind` bắt buộc: tách method ra khỏi client làm mất `this` (lỗi ERROR755103700).
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: {
      imports: number;
      rows: number;
      unmapped_codes: string[];
    } | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller("pos_import_commit", {
    p_property_id: parsed.data.propertyId,
    p_file_name: parsed.data.fileName,
    p_file_sha256: parsed.data.sha256,
    p_lines: parsed.data.lines,
  });
  if (error || !data) {
    const code = error?.message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/)?.[0];
    return { ok: false, error: getRpcErrorMessage(code ?? null) };
  }
  return {
    ok: true,
    data: {
      imports: data.imports,
      rows: data.rows,
      unmappedCodes: data.unmapped_codes ?? [],
    },
  };
}
