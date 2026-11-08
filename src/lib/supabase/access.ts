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
  const { data: propertyIds, error: accessError } =
    await supabase.rpc("my_property_ids");

  if (accessError) {
    console.error("Unable to load accessible property IDs.", accessError);
    throw accessError;
  }

  if (propertyIds.length === 0) {
    return [];
  }

  const { data: properties, error: propertiesError } = await supabase
    .from("properties")
    .select("id, code, name")
    .in("id", propertyIds)
    .order("name");

  if (propertiesError) {
    console.error("Unable to load accessible properties.", propertiesError);
    throw propertiesError;
  }

  return properties;
}
