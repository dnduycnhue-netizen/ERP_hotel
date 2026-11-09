import { redirect } from "next/navigation";

/** Mặc định khu thu mua mở danh sách yêu cầu mua. */
export default async function ProcurementPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  redirect(`/${propertyId}/procurement/pr`);
}
