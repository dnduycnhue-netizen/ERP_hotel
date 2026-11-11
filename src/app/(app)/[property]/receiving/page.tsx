import Link from "next/link";
import { notFound } from "next/navigation";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import { createClient } from "@/lib/supabase/server";

/**
 * Trang dich khu nhan hang (C6): chi la diem vao — cac thao tac nhan/tra
 * nam o trang con (danh sach phieu nhan o `/inventory/receipts`, phieu
 * tra NCC o `/receiving/returns`, nhan hien truong o `/m/[p]/receive`).
 * Chan nguoi khong co quyen nhan hang nao o day (RPC tung trang con
 * kiem tra lai quyen rieng cua no).
 */
export default async function ReceivingIndexPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  const { data: myPerms } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(myPerms ?? []);
  const canAccess =
    perms.has("receiving.view") ||
    perms.has("receiving.review_photos") ||
    perms.has("supplier_return.post");
  if (!canAccess) {
    notFound();
  }

  const cards = [
    {
      href: `/${propertyId}/inventory/receipts`,
      title: vi.receiving.listTitle,
      description: vi.receiving.receiptsCardDescription,
    },
    {
      href: `/${propertyId}/receiving/returns`,
      title: vi.receiving.returnsListTitle,
      description: vi.receiving.returnsCardDescription,
    },
    {
      href: `/m/${propertyId}/receive`,
      title: vi.receiving.mobileCardTitle,
      description: vi.receiving.mobileCardDescription,
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        title={vi.receiving.receivingTitle}
        description={vi.receiving.indexDescription}
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cards.map((card) => (
          <Link
            key={card.href}
            href={card.href}
            className="block rounded-lg border bg-card p-4 shadow-sm outline-none transition-colors hover:border-brand/60 focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <span className="block text-base font-semibold">{card.title}</span>
            <span className="mt-1 block text-sm text-muted-foreground">
              {card.description}
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
