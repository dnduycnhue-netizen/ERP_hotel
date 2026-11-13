import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";
import {
  ALL_MODULES_ON,
  filterPermissionsByModules,
  parsePropertyModules,
  type PropertyModules,
} from "./index";

type Client = SupabaseClient<Database>;

/**
 * Module đang bật của khách sạn. Lỗi đọc → coi như bật hết (chỉ ảnh hưởng
 * hiển thị; DB vẫn chặn ghi khi module tắt).
 */
export async function getPropertyModules(
  supabase: Client,
  propertyId: string,
): Promise<PropertyModules> {
  const { data, error } = await supabase.rpc("property_modules_get", {
    p_property_id: propertyId,
  });
  return error ? ALL_MODULES_ON : parsePropertyModules(data);
}

/** `my_permissions` đã bỏ quyền của module đang tắt. */
export async function getModuleAwarePermissions(
  supabase: Client,
  propertyId: string,
): Promise<string[]> {
  const [{ data }, modules] = await Promise.all([
    supabase.rpc("my_permissions", { p_property: propertyId }),
    getPropertyModules(supabase, propertyId),
  ]);
  return filterPermissionsByModules(data ?? [], modules);
}
