import { redirect } from "next/navigation";

export default async function MasterPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  redirect(`/${propertyId}/master/items`);
}
