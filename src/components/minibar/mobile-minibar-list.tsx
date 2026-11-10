"use client";

import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/common/empty-state";
import { MoneyText } from "@/components/common/money-text";
import type { MinibarCheckRow } from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

/**
 * Danh sách phòng chờ kiểm minibar — mobile buồng phòng (T-035).
 * Phiếu chưa kiểm (buồng chưa nộp) bấm vào để kiểm; phiếu đã kiểm
 * xong nhưng lễ tân chưa thu thì chỉ xem, không kiểm lại được.
 */
export function MobileMinibarList({
  propertyId,
  checks,
}: {
  propertyId: string;
  checks: MinibarCheckRow[];
}) {
  const router = useRouter();
  const awaiting = checks.filter((c) => c.checked_by === null);
  const checked = checks.filter((c) => c.checked_by !== null);

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{vi.minibar.mobileTitle}</h1>

      <a
        href={`/m/${propertyId}/receive`}
        className="text-sm font-medium text-primary underline"
      >
        ← {vi.receiving.tasksTitle}
      </a>

      {checks.length === 0 ? (
        <EmptyState title={vi.minibar.roomsEmpty} />
      ) : (
        <>
          {awaiting.length > 0 ? (
            <ul className="flex flex-col gap-2">
              {awaiting.map((check) => (
                <li key={check.id}>
                  <button
                    type="button"
                    onClick={() =>
                      router.push(`/m/${propertyId}/minibar/${check.id}`)
                    }
                    className="flex w-full items-start justify-between gap-3 rounded-xl border bg-card p-4 text-left"
                  >
                    <span>
                      <span className="block font-medium">
                        {vi.minibar.roomNo} {check.room_no}
                      </span>
                      <span className="block text-sm text-muted-foreground">
                        {check.doc_no} · {vi.minibar.triggers[check.trigger]}
                      </span>
                    </span>
                    <span className="shrink-0 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-900">
                      {vi.minibar.statuses.pendingCharge}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          ) : null}

          {checked.length > 0 ? (
            <div className="space-y-2">
              <h2 className="text-sm font-medium text-muted-foreground">
                {vi.minibar.statuses.pendingCharge} — {vi.minibar.checkedBy}
              </h2>
              <ul className="flex flex-col gap-2">
                {checked.map((check) => (
                  <li
                    key={check.id}
                    className="flex items-start justify-between gap-3 rounded-xl border bg-muted/50 p-4"
                  >
                    <span>
                      <span className="block font-medium">
                        {vi.minibar.roomNo} {check.room_no}
                      </span>
                      <span className="block text-sm text-muted-foreground">
                        {check.doc_no}
                      </span>
                    </span>
                    <MoneyText amount={check.total_amount} />
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </>
      )}
    </div>
  );
}
