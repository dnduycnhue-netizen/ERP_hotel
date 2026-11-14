"use client";

import { Dialog } from "@base-ui/react/dialog";
import { CheckCircle2, Package, Store, TriangleAlert } from "lucide-react";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "cn";
import { EmptyState } from "@/components/common/empty-state";
import { startReceivingAction } from "@/features/receiving/actions";
import type { ReceivingTaskRow } from "@/features/receiving/queries";
import type { WarehouseRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import { useCan } from "@/lib/permissions/permissions-provider";

/** "2026-11-09" → "09/11/2026" (tách chuỗi, không qua Date để tránh lệch múi giờ). */
function formatYmd(value: string | null): string {
  if (!value) {
    return vi.common.noData;
  }
  const [year, month, day] = value.split("-");
  if (!year || !month || !day) {
    return value;
  }
  return `${day}/${month}/${year}`;
}

function interpolate(
  template: string,
  values: Record<string, string | number>,
): string {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`{${key}}`, String(value)),
    template,
  );
}

/** Bỏ dấu + thường hóa để tìm kiếm tiếng Việt khớp cả khi gõ không dấu. */
function normalizeSearch(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function channelLabel(channel: string): string {
  if (channel === "market") {
    return vi.receiving.channelMarket;
  }
  if (channel === "quote") {
    return vi.receiving.channelQuote;
  }
  return vi.receiving.channelContract;
}

/**
 * Danh sách nhiệm vụ nhận hàng hôm nay + hộp thoại mở phiếu (T-024).
 *
 * Chỉ hiện tên NCC, số dòng, ngày hẹn giao — không số lượng, không giá.
 * Kho nhận phải là main/outlet/floor (RPC `receiving_start` kiểm tra);
 * kho nhận thẳng bếp là tùy chọn, không được trùng kho nhận.
 */
export function MobileTaskList({
  tasks,
  propertyId,
  warehouses,
  posted,
}: {
  tasks: ReceivingTaskRow[];
  propertyId: string;
  warehouses: WarehouseRow[];
  posted: boolean;
}) {
  const router = useRouter();
  const canPerform = useCan("receiving.perform");
  const canViewReceiving = useCan("receiving.view");
  const canReturn = useCan("supplier_return.post");
  const canViewReturns = canViewReceiving || canReturn;
  const canCountOpen = useCan("count.open");
  const canCountPerform = useCan("count.perform");
  const canCountViewVariance = useCan("count.view_variance");
  const canCountLock = useCan("count.lock");
  const canCountAdjustApprove = useCan("count.adjust.approve");
  const canCount =
    canCountOpen ||
    canCountPerform ||
    canCountViewVariance ||
    canCountLock ||
    canCountAdjustApprove;
  // Mo phieu moi can server (workspace can du lieu server) nen khong
  // xep hang offline duoc — chi ghi dong / duyet vuot / ghi so tren
  // phieu da mo moi offline (T-025).
  const { online } = useOfflineSync();
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<ReceivingTaskRow | null>(null);
  const [warehouseId, setWarehouseId] = useState("");
  const [directIssueWarehouseId, setDirectIssueWarehouseId] = useState("");
  const [starting, setStarting] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);

  const normalizedQuery = normalizeSearch(query.trim());
  const filteredTasks = useMemo(
    () =>
      normalizedQuery === ""
        ? tasks
        : tasks.filter((task) => {
            const haystack = normalizeSearch(
              [
                task.supplier_name ?? "",
                task.doc_no,
                channelLabel(task.channel),
              ].join(" "),
            );
            return haystack.includes(normalizedQuery);
          }),
    [tasks, normalizedQuery],
  );
  const receivableWarehouses = useMemo(
    () =>
      warehouses.filter((w) =>
        ["main", "outlet", "floor", "minibar_main"].includes(w.kind),
      ),
    [warehouses],
  );
  const directIssueOptions = useMemo(
    () => receivableWarehouses.filter((w) => w.id !== warehouseId),
    [receivableWarehouses, warehouseId],
  );

  function openStart(task: ReceivingTaskRow) {
    setSelected(task);
    setStartError(null);
    setWarehouseId(receivableWarehouses[0]?.id ?? "");
    setDirectIssueWarehouseId("");
  }

  function closeStart() {
    if (starting) {
      return;
    }
    setSelected(null);
    setStartError(null);
  }

  async function handleStart() {
    if (!selected || !warehouseId || starting) {
      return;
    }
    if (!online) {
      setStartError(vi.offline.startNeedsOnline);
      return;
    }
    setStarting(true);
    setStartError(null);
    const res = await startReceivingAction({
      poId: selected.po_id,
      warehouseId,
      directIssueWarehouseId: directIssueWarehouseId || null,
      clientUuid: crypto.randomUUID(),
    });
    setStarting(false);
    if (!res.ok) {
      setStartError(res.error);
      return;
    }
    router.push(`/m/${propertyId}/receive/${res.data.id}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-xl font-semibold">{vi.receiving.tasksTitle}</h1>
        <div className="flex gap-2">
          {canCount ? (
            <a
              href={`/m/${propertyId}/count`}
              className={cn(
                buttonVariants({ size: "sm", variant: "outline" }),
                "min-h-11",
              )}
            >
              {vi.count.title}
            </a>
          ) : null}
          {canViewReturns ? (
            <a
              href={`/m/${propertyId}/receive/returns`}
              className={cn(
                buttonVariants({ size: "sm", variant: "outline" }),
                "min-h-11",
              )}
            >
              {vi.receiving.returnsListTitle}
            </a>
          ) : null}
        </div>
      </div>

      <label className="flex flex-col gap-1.5">
        <span className="sr-only">{vi.common.search}</span>
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={vi.receiving.searchTasksPlaceholder}
          aria-label={vi.receiving.searchTasksPlaceholder}
          className="h-12 w-full rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
        />
      </label>

      <p className="text-base text-muted-foreground">
        {interpolate(vi.receiving.tasksCount, { count: tasks.length })}
        {normalizedQuery !== ""
          ? ` · ${filteredTasks.length}/${tasks.length}`
          : ""}
      </p>

      {posted ? (
        <p
          role="status"
          className="flex items-start gap-2 rounded-lg border border-green-200 bg-green-50 p-3 text-sm text-green-800"
        >
          <CheckCircle2 className="mt-0.5 size-4 shrink-0" aria-hidden />
          {vi.receiving.postedBanner}
        </p>
      ) : null}

      {tasks.length === 0 ? (
        <EmptyState
          icon={Package}
          title={vi.receiving.tasksTitle}
          description={vi.receiving.tasksEmpty}
        />
      ) : filteredTasks.length === 0 ? (
        <EmptyState
          icon={Package}
          title={vi.receiving.tasksTitle}
          description={vi.receiving.noMatchingTasks}
        />
      ) : (
        <ul className="flex flex-col gap-3">
          {filteredTasks.map((task) => (
            <li key={task.po_id}>
              <button
                type="button"
                onClick={() => openStart(task)}
                disabled={!canPerform}
                className="min-h-11 w-full rounded-xl border bg-card p-4 text-left shadow-sm transition-colors hover:border-ring disabled:opacity-60"
              >
                <span className="flex items-start justify-between gap-3">
                  <span className="flex min-w-0 flex-col gap-1">
                    <span className="flex items-center gap-2 text-base font-semibold">
                      <Store className="size-4 shrink-0" aria-hidden />
                      <span className="truncate">
                        {task.supplier_name ??
                          (task.channel === "market"
                            ? vi.receiving.channelMarket
                            : vi.common.noData)}
                      </span>
                    </span>
                    <span className="text-base text-muted-foreground">
                      {task.doc_no} · {task.line_count}{" "}
                      {vi.receiving.taskLineCount}
                    </span>
                    <span className="text-base text-muted-foreground">
                      {vi.receiving.expectedDate}:{" "}
                      {formatYmd(task.expected_date)}
                    </span>
                  </span>
                  <span className="shrink-0 rounded-full border px-2 py-0.5 text-xs font-medium">
                    {channelLabel(task.channel)}
                  </span>
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {!canPerform && tasks.length > 0 ? (
        <p className="flex items-start gap-2 text-sm text-muted-foreground">
          <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
          {vi.receiving.noPerformPermission}
        </p>
      ) : null}

      <Dialog.Root
        open={selected !== null}
        onOpenChange={(open) => {
          if (!open) {
            closeStart();
          }
        }}
      >
        <Dialog.Portal>
          <Dialog.Backdrop className="fixed inset-0 z-[60] bg-black/50" />
          <Dialog.Popup className="fixed z-[61] top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
            {selected ? (
              <>
                <Dialog.Title className="text-lg font-semibold">
                  {vi.receiving.startTitle}
                </Dialog.Title>
                <Dialog.Description className="mt-1 text-sm text-muted-foreground">
                  {selected.doc_no} ·{" "}
                  {selected.supplier_name ??
                    (selected.channel === "market"
                      ? vi.receiving.channelMarket
                      : vi.common.noData)}
                </Dialog.Description>
                <div className="mt-4 flex flex-col gap-4">
                  <p className="text-base text-muted-foreground">
                    {vi.receiving.startReceiptHint}
                  </p>
                  <label className="flex flex-col gap-1.5 text-base font-medium">
                    {vi.receiving.warehouse}
                    <select
                      value={warehouseId}
                      onChange={(event) => setWarehouseId(event.target.value)}
                      disabled={starting}
                      className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                    >
                      {receivableWarehouses.map((w) => (
                        <option key={w.id} value={w.id}>
                          {w.name} ({w.code})
                        </option>
                      ))}
                    </select>
                  </label>
                  <label className="flex flex-col gap-1.5 text-base font-medium">
                    {vi.receiving.directIssueWarehouse}
                    <select
                      value={directIssueWarehouseId}
                      onChange={(event) =>
                        setDirectIssueWarehouseId(event.target.value)
                      }
                      disabled={starting}
                      className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                    >
                      <option value="">{vi.common.noData}</option>
                      {directIssueOptions.map((w) => (
                        <option key={w.id} value={w.id}>
                          {w.name} ({w.code})
                        </option>
                      ))}
                    </select>
                    <span className="text-xs font-normal text-muted-foreground">
                      {vi.receiving.directIssueHint}
                    </span>
                  </label>
                  {startError ? (
                    <p role="alert" className="text-sm text-destructive">
                      {startError}
                    </p>
                  ) : null}
                  {!online ? (
                    <p className="text-sm text-amber-700">
                      {vi.offline.startNeedsOnline}
                    </p>
                  ) : null}
                </div>
                <div className="mt-6 flex justify-end gap-2">
                  <Button
                    variant="outline"
                    disabled={starting}
                    onClick={closeStart}
                    className="min-h-11"
                  >
                    {vi.common.cancel}
                  </Button>
                  <Button
                    disabled={starting || !warehouseId || !online}
                    onClick={() => void handleStart()}
                    className="min-h-11"
                  >
                    {starting ? vi.common.loading : vi.receiving.startReceipt}
                  </Button>
                </div>
              </>
            ) : null}
          </Dialog.Popup>
        </Dialog.Portal>
      </Dialog.Root>
    </div>
  );
}
