import { ErrorState } from "@/components/common/error-state";
import { DishForm } from "@/components/restaurant/dish-form";
import { listRecipes } from "@/features/restaurant/queries";
import { listItems, listUoms } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Thêm món ăn mới (M06). */
export default async function NewDishPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [recipesRes, itemsRes, uoms] = await Promise.all([
    listRecipes(propertyId),
    listItems({ propertyId, pageSize: 200 }),
    listUoms(),
  ]);

  if (!recipesRes.ok) {
    return <ErrorState description={recipesRes.error} />;
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.newDish}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.dishesHint}
        </p>
      </div>
      <DishForm
        propertyId={propertyId}
        recipe={null}
        items={itemsRes.items}
        uoms={uoms}
        recipes={recipesRes.data.map((r) => ({
          id: r.id,
          code: r.code,
          name: r.name,
        }))}
      />
    </div>
  );
}
