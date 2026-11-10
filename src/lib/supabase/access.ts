import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

export const selectedPropertyCookie = "selected_property_id";

export type AccessibleProperty = Pick<
  Database["public"]["Tables"]["properties"]["Row"],
  "id" | "code" | "name"
>;

export async function listAccessibleProperties(
  supabase: SupabaseClient<Database>,
): Promise<AccessibleProperty[]> {
  // Chỉ 1 câu SELECT: policy `properties_select` đã lọc
  // `id in (select public.my_property_ids())` nên kết quả trả về đúng
  // các khách sạn người gọi được truy cập, không cần gọi RPC
  // `my_property_ids()` trước rồi mới select (2 round-trip nối tiếp).
  const { data: properties, error: propertiesError } = await supabase
    .from("properties")
    .select("id, code, name")
    .order("name");

  if (propertiesError) {
    console.error("Unable to load accessible properties.", propertiesError);
    throw propertiesError;
  }

  return properties;
}
