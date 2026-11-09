"use client";

import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import type { CountKind, CountRow } from "@/features/count/queries";
import { vi } from "@/i18n/vi";
import { useCan } from "@/lib/permissions/permissions-provider";
import { formatYmd } from "./count-utils";

function kindLabel(kind: CountKind): string {
  switch (kind) {
    case "monthly_full":
      return vi.count.kindMonthlyFull;
    case "cycle":
      return vi.count.kindCycle;
    case "shift_key":
      return vi.count.kindShiftKey;
    case "trolley":
      return vi.count.kindTrolley;
    case "minibar_audit":
      return vi.count.kindMinibarAudit;
  }
}

/** Danh sách đợt kiểm kê mobile (T-033) — chỉ số chứng từ, kho, ngày, loại, trạng thái. */
export function MobileCountList({
  counts,
  propertyId,
}: {
  counts: CountRow[];
  propertyId: string;
}) {
  const router = useRouter();
  const canOpen = useCan("count.open");

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-xl font-semibold">{vi.count.countsTitle}</h1>
        {canOpen ? (
          <Button
            size="sm"
            onClick={() => router.push(`/m/${propertyId}/count/new`)}
          >
            {vi.count.openButton}
          </Button>
        ) : null}
      </div>

      <a
        href={`/m/${propertyId}/receive`}
        className="text-sm font-medium text-primary underline"
      >
        ← {vi.receiving.tasksTitle}
      </a>

      {counts.length === 0 ? (
        <EmptyState title={vi.count.countsEmpty} />
      ) : (
        <ul className="flex flex-col gap-2">
          {counts.map((count) => (
            <li key={count.id}>
              <button
                type="button"
                onClick={() =>
                  router.push(`/m/${propertyId}/count/${count.id}`)
                }
                className="flex w-full items-start justify-between gap-3 rounded-xl border bg-card p-4 text-left"
              >
                <span>
                  <span className="block font-medium">{count.doc_no}</span>
                  <span className="block text-sm text-muted-foreground">
                    {count.warehouse_name ?? vi.common.noData} ·{" "}
                    {formatYmd(count.business_date)}
                  </span>
                  <span className="block text-sm text-muted-foreground">
                    {kindLabel(count.kind)}
                  </span>
                </span>
                <DocStatusBadge status={count.status} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
