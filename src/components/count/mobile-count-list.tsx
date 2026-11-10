"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import type { CountKind, CountRow } from "@/features/count/queries";
import { vi } from "@/i18n/vi";
import { useCan } from "@/lib/permissions/permissions-provider";
import { formatYmd, interpolate, normalizeSearch } from "./count-utils";

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
  const [query, setQuery] = useState("");

  const normalizedQuery = normalizeSearch(query.trim());
  const filteredCounts = useMemo(
    () =>
      normalizedQuery === ""
        ? counts
        : counts.filter((count) => {
            const haystack = normalizeSearch(
              [
                count.doc_no,
                count.warehouse_name ?? "",
                kindLabel(count.kind),
              ].join(" "),
            );
            return haystack.includes(normalizedQuery);
          }),
    [counts, normalizedQuery],
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-xl font-semibold">{vi.count.countsTitle}</h1>
        {canOpen ? (
          <Button
            size="sm"
            onClick={() => router.push(`/m/${propertyId}/count/new`)}
            className="min-h-11"
          >
            {vi.count.openButton}
          </Button>
        ) : null}
      </div>

      <a
        href={`/m/${propertyId}/receive`}
        className="min-h-11 text-base font-medium text-primary underline"
      >
        ← {vi.receiving.tasksTitle}
      </a>

      <label className="flex flex-col gap-1.5">
        <span className="sr-only">{vi.common.search}</span>
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={vi.count.searchCountPlaceholder}
          aria-label={vi.count.searchCountPlaceholder}
          className="h-12 w-full rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
        />
      </label>

      <p className="text-base text-muted-foreground">
        {interpolate(vi.count.countsCount, { count: counts.length })}
        {normalizedQuery !== ""
          ? ` · ${filteredCounts.length}/${counts.length}`
          : ""}
      </p>

      {counts.length === 0 ? (
        <EmptyState title={vi.count.countsEmpty} />
      ) : filteredCounts.length === 0 ? (
        <EmptyState
          title={vi.count.countsTitle}
          description={vi.count.noMatchingLines}
        />
      ) : (
        <ul className="flex flex-col gap-2">
          {filteredCounts.map((count) => (
            <li key={count.id}>
              <button
                type="button"
                onClick={() =>
                  router.push(`/m/${propertyId}/count/${count.id}`)
                }
                className="flex min-h-11 w-full items-start justify-between gap-3 rounded-xl border bg-card p-4 text-left"
              >
                <span>
                  <span className="block text-base font-medium">
                    {count.doc_no}
                  </span>
                  <span className="block text-base text-muted-foreground">
                    {count.warehouse_name ?? vi.common.noData} ·{" "}
                    {formatYmd(count.business_date)}
                  </span>
                  <span className="block text-base text-muted-foreground">
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
