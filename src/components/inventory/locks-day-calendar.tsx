"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Lock, LockOpen } from "lucide-react";
import { Button } from "@/components/ui/button";
import { lockDayAction, unlockDayAction } from "@/features/locks/actions";
import {
  monthDays,
  todayInVietnam,
  weekdayIndex,
} from "@/features/locks/date-utils";
import type {
  DayLockRow,
  FrozenWarehouse,
  LockWarehouse,
} from "@/features/locks/queries";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

type Pending =
  | { kind: "lock"; warehouseId: string; businessDate: string }
  | { kind: "unlock"; lock: DayLockRow };

/**
 * Lịch tháng khóa ngày (C1, M05): 1 hàng = 1 ngày, 1 cột = 1 kho.
 * Ô đã khóa hiện huy hiệu + nút mở khóa (gm, kèm lý do); ô chưa khóa
 * hiện nút khóa ngày (kế toán). Kho đang đóng băng kiểm kê được gắn
 * nhãn ở đầu cột — vẫn khóa ngày được (RPC `day_lock` không chặn).
 */
export function LocksDayCalendar({
  propertyId,
  year,
  month,
  warehouses,
  locks,
  frozenWarehouses,
  canLock,
  canUnlock,
}: {
  propertyId: string;
  year: number;
  month: number;
  warehouses: LockWarehouse[];
  locks: DayLockRow[];
  frozenWarehouses: FrozenWarehouse[];
  canLock: boolean;
  canUnlock: boolean;
}) {
  const router = useRouter();
  const [pending, setPending] = useState<Pending | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const days = useMemo(() => monthDays(year, month), [year, month]);
  const today = todayInVietnam();

  const lockByKey = useMemo(() => {
    const map = new Map<string, DayLockRow>();
    for (const lock of locks) {
      const key = `${lock.warehouse_id}|${lock.business_date}`;
      if (!map.has(key)) {
        map.set(key, lock);
      }
    }
    return map;
  }, [locks]);

  const frozenByWarehouse = useMemo(() => {
    const map = new Map<string, FrozenWarehouse>();
    for (const frozen of frozenWarehouses) {
      map.set(frozen.warehouse_id, frozen);
    }
    return map;
  }, [frozenWarehouses]);

  function warehouseName(id: string): string {
    return warehouses.find((w) => w.id === id)?.name ?? id;
  }

  async function handleConfirm(): Promise<void> {
    if (!pending || busy) {
      return;
    }
    if (pending.kind === "unlock" && reason.trim() === "") {
      setError(vi.locks.unlockReasonLabel);
      return;
    }
    setBusy(true);
    setError(null);
    const res =
      pending.kind === "lock"
        ? await lockDayAction({
            propertyId,
            warehouseId: pending.warehouseId,
            businessDate: pending.businessDate,
            shift: null,
          })
        : await unlockDayAction({
            propertyId,
            lockId: pending.lock.id,
            reason: reason.trim(),
          });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setPending(null);
    setReason("");
    router.refresh();
  }

  function pendingTitle(): string {
    if (!pending) {
      return "";
    }
    if (pending.kind === "lock") {
      return `${vi.locks.lockConfirm} ${pending.businessDate} — ${warehouseName(pending.warehouseId)}`;
    }
    return `${vi.locks.unlockConfirm} ${pending.lock.business_date} — ${warehouseName(pending.lock.warehouse_id)}`;
  }

  return (
    <div className="flex flex-col gap-3">
      {pending ? (
        <div
          role="group"
          aria-label={pendingTitle()}
          className="rounded-lg border bg-card p-4"
        >
          <p className="text-sm font-semibold">{pendingTitle()}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {pending.kind === "lock"
              ? vi.locks.lockNote
              : vi.locks.unlockWarning}
          </p>
          {pending.kind === "unlock" ? (
            <label className="mt-3 flex flex-col gap-1.5 text-sm font-medium">
              {vi.locks.unlockReasonLabel} *
              <input
                type="text"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder={vi.locks.unlockReasonPlaceholder}
                maxLength={500}
                className="h-9 rounded-md border bg-background px-3 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
              />
            </label>
          ) : null}
          {error ? (
            <p role="alert" className="mt-2 text-sm text-destructive">
              {error}
            </p>
          ) : null}
          <div className="mt-3 flex gap-2">
            <Button
              size="sm"
              disabled={busy}
              onClick={() => void handleConfirm()}
            >
              {busy
                ? pending.kind === "lock"
                  ? vi.locks.locking
                  : vi.locks.unlocking
                : vi.locks.confirm}
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={busy}
              onClick={() => {
                setPending(null);
                setReason("");
                setError(null);
              }}
            >
              {vi.locks.cancel}
            </Button>
          </div>
        </div>
      ) : null}

      <div className="overflow-x-auto rounded-lg border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-muted/40 text-left">
            <tr>
              <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                {vi.locks.day}
              </th>
              {warehouses.map((warehouse) => {
                const frozen = frozenByWarehouse.get(warehouse.id);
                return (
                  <th
                    key={warehouse.id}
                    className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase"
                  >
                    <span className="flex flex-col gap-1">
                      <span>{warehouse.name}</span>
                      {frozen ? (
                        <span className="inline-flex w-fit items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-semibold normal-case text-amber-800 dark:bg-amber-900/40 dark:text-amber-200">
                          <Lock className="size-3" aria-hidden />
                          {vi.locks.frozenTitle}
                        </span>
                      ) : null}
                    </span>
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {days.map((date) => {
              const isToday = date === today;
              const dayNo = Number(date.slice(8, 10));
              const weekday = vi.locks.weekdayShort[weekdayIndex(date)];
              return (
                <tr
                  key={date}
                  className={cn("border-t", isToday && "bg-brand/5")}
                >
                  <th
                    scope="row"
                    className="px-3 py-2 text-left font-medium whitespace-nowrap"
                  >
                    {dayNo} · {weekday}
                    {isToday ? (
                      <span className="ml-2 rounded-full bg-brand/10 px-2 py-0.5 text-[11px] font-semibold text-brand">
                        {vi.common.today}
                      </span>
                    ) : null}
                  </th>
                  {warehouses.map((warehouse) => {
                    const lock = lockByKey.get(`${warehouse.id}|${date}`);
                    return (
                      <td
                        key={warehouse.id}
                        className="px-3 py-2 whitespace-nowrap"
                      >
                        {lock ? (
                          <span className="flex items-center gap-2">
                            <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-[11px] font-semibold text-green-800 dark:bg-green-900/40 dark:text-green-200">
                              <Lock className="size-3" aria-hidden />
                              {vi.locks.locked}
                            </span>
                            {canUnlock ? (
                              <Button
                                size="xs"
                                variant="ghost"
                                onClick={() =>
                                  setPending({ kind: "unlock", lock })
                                }
                              >
                                <LockOpen aria-hidden />
                                {vi.locks.unlockDay}
                              </Button>
                            ) : null}
                          </span>
                        ) : canLock ? (
                          <Button
                            size="xs"
                            variant="outline"
                            onClick={() =>
                              setPending({
                                kind: "lock",
                                warehouseId: warehouse.id,
                                businessDate: date,
                              })
                            }
                          >
                            <Lock aria-hidden />
                            {vi.locks.lockDay}
                          </Button>
                        ) : (
                          <span className="text-muted-foreground">
                            {vi.locks.open}
                          </span>
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
