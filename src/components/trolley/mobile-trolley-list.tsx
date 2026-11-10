"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { formatYmd } from "@/components/count/count-utils";
import type { TrolleyShiftRow } from "@/features/trolley/queries";
import { vi } from "@/i18n/vi";
import { listPendingJobs } from "@/lib/offline/db";
import { useCan } from "@/lib/permissions/permissions-provider";
import { shiftLabel } from "./trolley-utils";

export type TrolleyWarehouseOption = {
  id: string;
  code: string;
  name: string;
};

/**
 * Danh sách ca xe đẩy mobile — ca đang mở trước, rồi ca đã đóng gần nhất.
 * Ca mở offline chưa đồng bộ hiện riêng ở đầu danh sách ("Chờ đồng bộ",
 * đọc từ hàng đợi Dexie) để nhân viên không mở trùng ca.
 */
export function MobileTrolleyList({
  shifts,
  trolleyWarehouses,
  propertyId,
}: {
  shifts: TrolleyShiftRow[];
  trolleyWarehouses: TrolleyWarehouseOption[];
  propertyId: string;
}) {
  const router = useRouter();
  const canOperate = useCan("hk.trolley.operate");
  const [pendingOpen, setPendingOpen] = useState<
    Array<{
      key: string;
      trolleyWh: string;
      shift: string;
      businessDate: string;
    }>
  >([]);

  useEffect(() => {
    let cancelled = false;
    void listPendingJobs().then((jobs) => {
      if (cancelled) {
        return;
      }
      setPendingOpen(
        jobs
          .filter((job) => job.payload.kind === "trolley_open")
          .map((job, index) => {
            const input =
              job.payload.kind === "trolley_open" ? job.payload.input : null;
            return {
              key: `pending-${job.id ?? index}`,
              trolleyWh: input?.trolleyWh ?? "",
              shift: input?.shift ?? "day",
              businessDate: input?.businessDate ?? "",
            };
          }),
      );
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const warehouseById = new Map(
    trolleyWarehouses.map((w) => [w.id, w] as const),
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-xl font-semibold">{vi.trolley.shiftsTitle}</h1>
        {canOperate ? (
          <Button
            size="sm"
            onClick={() => router.push(`/m/${propertyId}/trolley/new`)}
          >
            {vi.trolley.openButton}
          </Button>
        ) : null}
      </div>

      {pendingOpen.length > 0 ? (
        <ul className="flex flex-col gap-2">
          {pendingOpen.map((job) => {
            const wh = warehouseById.get(job.trolleyWh);
            return (
              <li
                key={job.key}
                className="rounded-xl border border-amber-300 bg-amber-50/60 p-4"
              >
                <p className="font-medium">
                  {wh ? `${wh.code} — ${wh.name}` : vi.common.noData}
                </p>
                <p className="text-sm text-muted-foreground">
                  {formatYmd(job.businessDate)} · {shiftLabel(job.shift)}
                </p>
                <p className="mt-1 text-sm font-medium text-amber-800">
                  {vi.trolley.pendingOpen}
                </p>
              </li>
            );
          })}
        </ul>
      ) : null}

      {shifts.length === 0 && pendingOpen.length === 0 ? (
        <EmptyState title={vi.trolley.shiftsEmpty} />
      ) : (
        <ul className="flex flex-col gap-2">
          {shifts.map((shift) => (
            <li key={shift.id}>
              <button
                type="button"
                onClick={() =>
                  router.push(`/m/${propertyId}/trolley/${shift.id}`)
                }
                className="flex w-full items-start justify-between gap-3 rounded-xl border bg-card p-4 text-left"
              >
                <span>
                  <span className="block font-medium">
                    {shift.trolley_code ?? vi.common.noData}
                    {shift.trolley_name ? ` — ${shift.trolley_name}` : ""}
                  </span>
                  <span className="block text-sm text-muted-foreground">
                    {formatYmd(shift.business_date)} · {shiftLabel(shift.shift)}
                  </span>
                </span>
                <DocStatusBadge status={shift.status} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
