import { listExpenseCategories } from "@/features/master/queries";
import { ExpenseCategoriesManager } from "@/components/master/expense-categories-manager";

export default async function ExpenseCategoriesPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const categories = await listExpenseCategories(propertyId);

  return (
    <ExpenseCategoriesManager propertyId={propertyId} categories={categories} />
  );
}
