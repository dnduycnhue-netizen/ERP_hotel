"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import { MODULE_IDS } from "@/lib/modules";
import { callAdminRpc, type AdminActionResult } from "./rpc";

const moduleToggleSchema = z.object({
  propertyId: z.string().uuid(),
  module: z.enum(MODULE_IDS),
  enabled: z.boolean(),
});

export async function setPropertyModuleAction(
  input: z.input<typeof moduleToggleSchema>,
): Promise<AdminActionResult<{ enabled: boolean }>> {
  const parsed = moduleToggleSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: getRpcErrorMessage("ERR_INVALID_VALUE") };
  }
  const supabase = await createClient();
  const result = await callAdminRpc<{ enabled: boolean }>(
    supabase,
    "admin_module_set",
    {
      p_property_id: parsed.data.propertyId,
      p_module: parsed.data.module,
      p_enabled: parsed.data.enabled,
    },
  );
  if (result.ok) {
    revalidatePath("/admin/modules");
    revalidatePath("/", "layout");
  }
  return result;
}
