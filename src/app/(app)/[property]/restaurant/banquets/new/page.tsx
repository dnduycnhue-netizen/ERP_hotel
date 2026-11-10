import { ErrorState } from "@/components/common/error-state";
import { BanquetForm } from "@/components/restaurant/banquet-form";
import { listRecipes } from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/** Thêm tiệc mới (M06). */
export default async function NewBanquetPage({
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
        <h1 className="text-xl font-semibold">{vi.restaurant.newBanquet}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.banquetsHint}
        </p>
      </div>
      <BanquetForm
        propertyId={propertyId}
        banquet={null}
        recipes={recipesRes.data.map((r) => ({
          id: r.id,
          code: r.code,
          name: r.name,
          sale_price: r.sale_price,
        }))}
      />
    </div>
  );
}
