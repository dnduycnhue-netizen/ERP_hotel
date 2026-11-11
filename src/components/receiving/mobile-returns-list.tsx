"use client";

import { PackageX, Undo2 } from "lucide-react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "cn";
import { EmptyState } from "@/components/common/empty-state";
import type { SupplierReturnRow } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { useCan } from "@/lib/permissions/permissions-provider";

/** "2026-11-09T…" → "09/11/2026" (tách chuỗi, không qua Date để tránh lệch múi giờ). */
function formatDate(value: string | null): string {
  if (!value) {
    return vi.common.noData;
  }
  const date = value.slice(0, 10);
  const [year, month, day] = date.split("-");
  if (!year || !month || !day) {
    return date;
  }
  return `${day}/${month}/${year}`;
}

function statusLabel(status: SupplierReturnRow["status"]): string {
  if (status === "posted") {
    return vi.receiving.returnPosted;
  }
  if (status === "cancelled") {
    return vi.components.docStatus.cancelled;
  }
  return vi.receiving.returnRecorded;
}

/**
 * Danh sách phiếu trả hàng NCC trên mobile (T-026).
 *
 * Phiếu trả QC fail (trạng thái `recorded`) chưa qua kho — xác nhận NCC
 * đã lấy hàng xong mới chuyển `posted`. Trang này chỉ xem/xác nhận/hủy;
 * tạo phiếu mới ở /returns/new (chỉ online).
 */
export function MobileReturnsList({
  returns,
  total,
  propertyId,
}: {
  returns: SupplierReturnRow[];
  total: number;
  propertyId: string;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const status = searchParams.get("status") ?? "";
  const canReturn = useCan("supplier_return.post");

  function setStatus(next: string) {
    const params = new URLSearchParams(searchParams.toString());
    if (next) {
      params.set("status", next);
    } else {
      params.delete("status");
    }
    router.push(`/m/${propertyId}/receive/returns?${params.toString()}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-xl font-semibold">
          {vi.receiving.returnsListTitle}
        </h1>
        {canReturn ? (
          <Link
            href={`/m/${propertyId}/receive/returns/new`}
            className={cn(buttonVariants({ size: "sm" }), "min-h-11")}
          >
            {vi.receiving.newReturnTitle}
          </Link>
        ) : null}
      </div>

      <div
        className="flex flex-wrap gap-2"
        role="group"
        aria-label={vi.common.status}
      >
        {(
          [
            ["", vi.common.all],
            ["recorded", vi.receiving.returnRecorded],
            ["posted", vi.receiving.returnPosted],
            ["cancelled", vi.components.docStatus.cancelled],
          ] as const
        ).map(([value, label]) => (
          <Button
            key={value}
            type="button"
            size="sm"
            variant={status === value ? "default" : "outline"}
            onClick={() => setStatus(value)}
            aria-pressed={status === value}
            className="min-h-11"
          >
            {label}
          </Button>
        ))}
      </div>

      <p className="text-base text-muted-foreground">
        {total} {vi.receiving.returnsListTitle.toLowerCase()}
      </p>

      {returns.length === 0 ? (
        <EmptyState
          icon={PackageX}
          title={vi.receiving.returnsListTitle}
          description={vi.receiving.returnsEmpty}
        />
      ) : (
        <ul className="flex flex-col gap-3">
          {returns.map((ret) => (
            <li key={ret.id}>
              <Link
                href={`/m/${propertyId}/receive/returns/${ret.id}`}
                className="block rounded-xl border bg-card p-4 shadow-sm transition-colors hover:border-ring"
              >
                <span className="flex items-start justify-between gap-3">
                  <span className="flex min-w-0 flex-col gap-1">
                    <span className="flex items-center gap-2 text-base font-semibold">
                      <Undo2 className="size-4 shrink-0" aria-hidden />
                      <span className="truncate">{ret.doc_no}</span>
                    </span>
                    <span className="text-base text-muted-foreground">
                      {ret.supplier_name} · {ret.line_count}{" "}
                      {vi.receiving.taskLineCount}
                    </span>
                    <span className="text-base text-muted-foreground">
                      {vi.receiving.returnGrDocNo}: {ret.gr_doc_no ?? "—"}
                    </span>
                    <span className="text-base text-muted-foreground">
                      {formatDate(ret.created_at)}
                    </span>
                  </span>
                  <span className="shrink-0 rounded-full border px-2 py-0.5 text-xs font-medium">
                    {statusLabel(ret.status)}
                  </span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}

      {!canReturn ? (
        <p className="text-sm text-muted-foreground">
          {vi.receiving.noReturnPermission}
        </p>
      ) : null}
    </div>
  );
}
