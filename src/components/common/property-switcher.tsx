import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import type { AccessibleProperty } from "@/lib/supabase/access";
import { switchProperty } from "@/app/(app)/actions";

export function PropertySwitcher({
  currentPropertyId,
  properties,
}: {
  currentPropertyId: string;
  properties: AccessibleProperty[];
}) {
  return (
    <form
      action={switchProperty}
      className="flex flex-col gap-2 sm:flex-row sm:items-end"
    >
      <div className="space-y-1">
        <label
          className="text-xs font-medium text-muted-foreground"
          htmlFor="propertyId"
        >
          {vi.property.switchLabel}
        </label>
        <select
          className="h-9 min-w-56 rounded-md border bg-background px-3 text-sm"
          defaultValue={currentPropertyId}
          id="propertyId"
          name="propertyId"
        >
          {properties.map((property) => (
            <option key={property.id} value={property.id}>
              {property.name} ({property.code})
            </option>
          ))}
        </select>
      </div>
      <Button className="h-9" type="submit">
        {vi.property.switchAction}
      </Button>
    </form>
  );
}
