import { ErrorState } from "@/components/common/error-state";
import { BuffetForm } from "@/components/restaurant/buffet-form";
import { listRecipes } from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/** Thêm phiên buffet mới (M06). */
export default async function NewBuffetPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const recipesRes = await listRecipes(propertyId);
  if (!recipesRes.ok) {
    return <ErrorState description={recipesRes.error} />;
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.newSession}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.buffetHint}
        </p>
      </div>
      <BuffetForm
        propertyId={propertyId}
        session={null}
        recipes={recipesRes.data.map((r) => ({
          id: r.id,
          code: r.code,
          name: r.name,
        }))}
      />
    </div>
  );
}
