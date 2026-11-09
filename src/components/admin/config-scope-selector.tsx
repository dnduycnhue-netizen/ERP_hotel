import type { AccessibleProperty } from "@/lib/supabase/access";
import { vi } from "@/i18n/vi";

export function ConfigScopeSelector({
  path,
  properties,
  selectedPropertyId,
}: {
  path: string;
  properties: AccessibleProperty[];
  selectedPropertyId: string | null;
}) {
  return (
    <form method="get" action={path} className="flex flex-wrap items-end gap-2">
      <label className="grid gap-1 text-sm">
        <span>{vi.admin.configScope}</span>
        <select
          name="property"
          defaultValue={selectedPropertyId ?? ""}
          className="h-9 min-w-56 rounded-md border bg-background px-3"
        >
          <option value="">{vi.admin.configOrganizationScope}</option>
          {properties.map((property) => (
            <option key={property.id} value={property.id}>
              {property.name}
            </option>
          ))}
        </select>
      </label>
      <button
        type="submit"
        className="h-9 rounded-md border bg-background px-3 text-sm font-medium hover:bg-muted"
      >
        {vi.admin.configChangeScope}
      </button>
    </form>
  );
}
