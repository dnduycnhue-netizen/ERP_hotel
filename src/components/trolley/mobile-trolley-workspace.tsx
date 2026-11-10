"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { formatYmd } from "@/components/count/count-utils";
import { formatQty } from "@/components/count/count-utils";
import { enqueueOfflineJob, listPendingJobs } from "@/lib/offline/db";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import {
  clearTrolleyDraft,
  emptyRoomsDoneRow,
  loadTrolleyDraft,
  saveTrolleyDraftCounts,
  trolleyCloseDraftKey,
} from "@/features/trolley/drafts";
import { closeTrolleyShiftAction } from "@/features/trolley/actions";
import type {
  TrolleyConsumptionRow,
  TrolleyParRow,
  TrolleyRoomRow,
  TrolleyShiftDetail,
} from "@/features/trolley/queries";
import { TrolleyCountList } from "@/components/trolley/trolley-count-list";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";
import { useCan } from "@/lib/permissions/permissions-provider";
import type { TrolleyCleanType } from "@/features/trolley/schemas";
import { shiftLabel } from "./trolley-utils";

const CLEAN_TYPE_OPTIONS: Array<{ value: TrolleyCleanType; label: string }> = [
  { value: "checkout", label: "Trả phòng" },
  { value: "stayover", label: "Ở tiếp" },
  { value: "vip", label: "VIP" },
  { value: "child", label: "Trẻ em" },
];

function countsToInput(
  values: Record<string, string>,
): Array<{ itemId: string; qty: number }> {
  return Object.entries(values)
    .map(([itemId, raw]) => ({ itemId, qty: Number(raw) }))
    .filter((c) => Number.isFinite(c.qty) && c.qty >= 0);
}

/**
 * Workspace ca xe đẩy mobile (1 ca):
 * - Ca đang mở: số đếm đầu ca (chỉ xem), phiếu lĩnh bù tới par
 *   (số + trạng thái + link sang phiếu lĩnh), form đếm cuối ca (mù —
 *   món đếm = hợp par + món đầu ca, KHÔNG hiện par), danh sách phòng
 *   đã dọn (tùy chọn), nút đóng ca.
 * - Ca đã đóng: bảng tiêu hao đầu/lĩnh/cuối/đã dùng, món thừa, số
 *   phiếu tiêu hao, phòng đã dọn.
 * - Đóng ca online: gọi thẳng `trolley_shift_close` → hiện kết quả.
 *   Offline: xếp hàng kind `trolley_close` (đóng ca là ghi sổ nên
 *   KHÔNG mở ca mới khi job đóng ca còn chờ — xem Q114).
 */
export function MobileTrolleyWorkspace({
  detail,
  parItems,
  rooms,
  propertyId,
}: {
  detail: TrolleyShiftDetail;
  parItems: TrolleyParRow[];
  rooms: TrolleyRoomRow[];
  propertyId: string;
}) {
  const router = useRouter();
  const { online } = useOfflineSync();
  const canOperate = useCan("hk.trolley.operate");
  const shift = detail.shift;
  const isOpen = shift.status === "open";
  // Ca có job đóng ca đang chờ đồng bộ không (đọc từ hàng đợi Dexie).
  const [pendingClose, setPendingClose] = useState(false);

  // Món đếm cuối ca = hợp (món có par) ∪ (món có ở đầu ca).
  const closeItems = (() => {
    const byId = new Map<
      string,
      { itemId: string; code: string; name: string; stockUom: string }
    >();
    for (const p of parItems) {
      byId.set(p.item_id, {
        itemId: p.item_id,
        code: p.item_code,
        name: p.item_name,
        stockUom: p.stock_uom,
      });
    }
    for (const c of detail.opening_counts) {
      if (!byId.has(c.item_id)) {
        byId.set(c.item_id, {
          itemId: c.item_id,
          code: c.item_code,
          name: c.item_name,
          stockUom: c.stock_uom,
        });
      }
    }
    return [...byId.values()].sort((a, b) => a.code.localeCompare(b.code));
  })();

  const [values, setValues] = useState<Record<string, string>>({});
  const [roomsDone, setRoomsDone] = useState<
    Array<{ roomId: string; cleanType: TrolleyCleanType; guests: string }>
  >([]);
  const [draftLoaded, setDraftLoaded] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [queued, setQueued] = useState(false);
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Kiểm tra job đóng ca đang chờ đồng bộ cho ca này.
  useEffect(() => {
    if (!isOpen) {
      return;
    }
    let cancelled = false;
    void listPendingJobs().then((jobs) => {
      if (cancelled) {
        return;
      }
      setPendingClose(
        jobs.some(
          (job) =>
            job.payload.kind === "trolley_close" &&
            job.payload.input.shiftId === shift.id,
        ),
      );
    });
    return () => {
      cancelled = true;
    };
  }, [isOpen, shift.id]);

  // Khôi phục nháp đóng ca dở (chỉ ca đang mở mới có form đếm).
  useEffect(() => {
    if (!isOpen) {
      return;
    }
    let cancelled = false;
    void loadTrolleyDraft(trolleyCloseDraftKey(shift.id)).then((draft) => {
      if (cancelled) {
        return;
      }
      if (draft) {
        const restored: Record<string, string> = {};
        for (const c of draft.counts) {
          restored[c.itemId] = c.qty;
        }
        setValues(restored);
        setRoomsDone(
          draft.roomsDone.map((r) => ({
            roomId: r.roomId,
            cleanType: r.cleanType as TrolleyCleanType,
            guests: r.guests,
          })),
        );
      }
      setDraftLoaded(true);
    });
    return () => {
      cancelled = true;
    };
  }, [isOpen, shift.id]);

  // Tự lưu nháp đóng ca (debounce 500ms).
  useEffect(() => {
    if (!isOpen || !draftLoaded) {
      return;
    }
    if (saveTimer.current) {
      clearTimeout(saveTimer.current);
    }
    saveTimer.current = setTimeout(() => {
      void saveTrolleyDraftCounts(
        trolleyCloseDraftKey(shift.id),
        {
          propertyId,
          shiftId: shift.id,
          trolleyWh: shift.trolley_warehouse_id,
          shift: shift.shift,
          businessDate: shift.business_date,
          kind: "close",
        },
        Object.entries(values).map(([itemId, qty]) => ({ itemId, qty })),
        roomsDone.map((r) => ({
          roomId: r.roomId,
          cleanType: r.cleanType,
          guests: r.guests,
        })),
      );
    }, 500);
    return () => {
      if (saveTimer.current) {
        clearTimeout(saveTimer.current);
      }
    };
  }, [
    values,
    roomsDone,
    isOpen,
    draftLoaded,
    propertyId,
    shift.id,
    shift.trolley_warehouse_id,
    shift.shift,
    shift.business_date,
  ]);

  const countedAll = closeItems.every((item) => {
    const raw = values[item.itemId] ?? "";
    return raw !== "" && Number.isFinite(Number(raw)) && Number(raw) >= 0;
  });

  async function handleClose() {
    if (!canOperate || !isOpen || !countedAll || submitting) {
      return;
    }
    setSubmitting(true);
    setError(null);
    const input = {
      shiftId: shift.id,
      counts: countsToInput(values),
      roomsDone: roomsDone
        .filter((r) => r.roomId !== "")
        .map((r) => ({
          roomId: r.roomId,
          cleanType: r.cleanType,
          guests: r.guests === "" ? undefined : Math.trunc(Number(r.guests)),
        })),
    };
    if (!online) {
      await enqueueOfflineJob({
        propertyId,
        grId: null,
        countId: null,
        kind: "trolley_close",
        clientUuid: null,
        payload: { kind: "trolley_close", input },
        createdAt: Date.now(),
      });
      await clearTrolleyDraft(trolleyCloseDraftKey(shift.id));
      setQueued(true);
      setSubmitting(false);
      return;
    }
    const res = await closeTrolleyShiftAction(input);
    if (!res.ok) {
      setError(res.error);
      setSubmitting(false);
      return;
    }
    await clearTrolleyDraft(trolleyCloseDraftKey(shift.id));
    router.refresh();
  }

  const consumption = detail.consumption as TrolleyConsumptionRow[];
  const surplus = consumption.filter((c) => c.surplus_qty > 0);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold">
            {shift.trolley_code ?? vi.common.noData}
            {shift.trolley_name ? ` — ${shift.trolley_name}` : ""}
          </h1>
          <p className="text-sm text-muted-foreground">
            {formatYmd(shift.business_date)} · {shiftLabel(shift.shift)}
          </p>
        </div>
        <DocStatusBadge status={shift.status} />
      </div>

      {/* Phiếu lĩnh bù tới par (sinh lúc mở ca). */}
      {shift.requisition_id ? (
        <button
          type="button"
          onClick={() =>
            router.push(
              `/m/${propertyId}/inventory/requisitions/${shift.requisition_id}`,
            )
          }
          className="rounded-xl border bg-card p-4 text-left"
        >
          <p className="text-sm text-muted-foreground">
            {vi.trolley.topUpRequisition}
          </p>
          <p className="font-medium">
            {shift.requisition_doc_no ?? shift.requisition_id}
            {shift.requisition_status ? ` · ${shift.requisition_status}` : ""}
          </p>
        </button>
      ) : (
        <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">
          {vi.trolley.noTopUpRequisition}
        </p>
      )}

      {isOpen ? (
        <>
          {/* Số đếm đầu ca (chỉ xem — đã đếm lúc mở ca). */}
          <section className="flex flex-col gap-2">
            <h2 className="font-semibold">{vi.trolley.openingCounts}</h2>
            <ul className="flex flex-col gap-1 rounded-xl border bg-card p-4">
              {detail.opening_counts.map((c) => (
                <li
                  key={c.item_id}
                  className="flex justify-between gap-3 text-sm"
                >
                  <span>
                    {c.item_code} — {c.item_name}
                  </span>
                  <span className="font-medium">
                    {formatQty(c.qty)} {c.stock_uom}
                  </span>
                </li>
              ))}
              {detail.opening_counts.length === 0 ? (
                <li className="text-sm text-muted-foreground">
                  {vi.common.noData}
                </li>
              ) : null}
            </ul>
          </section>

          {/* Đếm cuối ca (mù). */}
          <section className="flex flex-col gap-2">
            <h2 className="font-semibold">{vi.trolley.closingCounts}</h2>
            <TrolleyCountList
              items={closeItems}
              values={values}
              onChange={(itemId, value) =>
                setValues((prev) => ({ ...prev, [itemId]: value }))
              }
              disabled={!draftLoaded || pendingClose}
            />
          </section>

          {/* Phòng đã dọn (tùy chọn, Q117). */}
          <section className="flex flex-col gap-2">
            <h2 className="font-semibold">{vi.trolley.roomsDone}</h2>
            {roomsDone.map((row, index) => (
              <div
                key={index}
                className="flex flex-col gap-2 rounded-xl border bg-card p-3"
              >
                <div className="flex gap-2">
                  <select
                    value={row.roomId}
                    onChange={(e) =>
                      setRoomsDone((prev) =>
                        prev.map((r, i) =>
                          i === index ? { ...r, roomId: e.target.value } : r,
                        ),
                      )
                    }
                    className="min-w-0 flex-1 rounded-md border bg-background px-3 py-2 text-base"
                  >
                    <option value="">{vi.trolley.roomPlaceholder}</option>
                    {rooms.map((room) => (
                      <option key={room.id} value={room.id}>
                        {room.room_no}
                        {room.floor ? ` · ${room.floor}` : ""}
                      </option>
                    ))}
                  </select>
                  <select
                    value={row.cleanType}
                    onChange={(e) =>
                      setRoomsDone((prev) =>
                        prev.map((r, i) =>
                          i === index
                            ? {
                                ...r,
                                cleanType: e.target.value as TrolleyCleanType,
                              }
                            : r,
                        ),
                      )
                    }
                    className="rounded-md border bg-background px-3 py-2 text-base"
                  >
                    {CLEAN_TYPE_OPTIONS.map((o) => (
                      <option key={o.value} value={o.value}>
                        {o.label}
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    onClick={() =>
                      setRoomsDone((prev) => prev.filter((_, i) => i !== index))
                    }
                    className="shrink-0 rounded-md border px-3 py-2 text-sm"
                  >
                    {vi.trolley.removeRoom}
                  </button>
                </div>
                <label className="flex items-center gap-2 text-sm">
                  {vi.trolley.guests}
                  <input
                    type="number"
                    inputMode="numeric"
                    min={0}
                    value={row.guests}
                    onChange={(e) =>
                      setRoomsDone((prev) =>
                        prev.map((r, i) =>
                          i === index ? { ...r, guests: e.target.value } : r,
                        ),
                      )
                    }
                    className="w-20 rounded-md border bg-background px-2 py-1 text-base"
                  />
                </label>
              </div>
            ))}
            <Button
              variant="outline"
              onClick={() =>
                setRoomsDone((prev) => [...prev, emptyRoomsDoneRow()])
              }
            >
              {vi.trolley.addRoom}
            </Button>
          </section>

          {pendingClose ? (
            <p className="rounded-xl border border-amber-300 bg-amber-50/60 p-3 text-sm">
              {vi.trolley.closePendingSync}
            </p>
          ) : null}
          {!online ? (
            <p className="rounded-xl border border-amber-300 bg-amber-50/60 p-3 text-sm">
              {vi.offline.offlineQueuedNote}
            </p>
          ) : null}
          {queued ? (
            <p className="rounded-xl border border-amber-300 bg-amber-50/60 p-3 text-sm">
              {vi.trolley.queuedClose}
            </p>
          ) : null}
          {error ? (
            <p className="rounded-xl border border-destructive/40 bg-destructive/5 p-3 text-sm text-destructive">
              {error}
            </p>
          ) : null}
          <Button
            onClick={handleClose}
            disabled={
              !canOperate || !countedAll || submitting || pendingClose || queued
            }
            className={cn("w-full", !online && "opacity-90")}
          >
            {submitting
              ? vi.common.submitting
              : online
                ? vi.trolley.closeSubmit
                : vi.trolley.closeSubmitOffline}
          </Button>
          {!countedAll ? (
            <p className="text-sm text-muted-foreground">
              {vi.trolley.countAllRequired}
            </p>
          ) : null}
        </>
      ) : (
        <>
          {/* Kết quả sau khi đóng ca: tiêu hao + thừa + phiếu tiêu hao. */}
          <section className="flex flex-col gap-2">
            <h2 className="font-semibold">{vi.trolley.consumptionTitle}</h2>
            <ul className="flex flex-col gap-1 rounded-xl border bg-card p-4">
              {consumption.map((c) => (
                <li
                  key={c.item_id}
                  className="flex flex-col gap-0.5 border-b py-2 text-sm last:border-b-0"
                >
                  <span className="font-medium">
                    {c.item_code} — {c.item_name}
                  </span>
                  <span className="text-muted-foreground">
                    {vi.trolley.openingQty}: {formatQty(c.opening_qty)}{" "}
                    {c.stock_uom} · {vi.trolley.receivedQty}:{" "}
                    {formatQty(c.received_qty)} {c.stock_uom} ·{" "}
                    {vi.trolley.closingQty}: {formatQty(c.closing_qty)}{" "}
                    {c.stock_uom}
                  </span>
                  <span>
                    {vi.trolley.consumedQty}:{" "}
                    <strong>
                      {formatQty(c.consumed_qty)} {c.stock_uom}
                    </strong>
                  </span>
                </li>
              ))}
              {consumption.length === 0 ? (
                <li className="text-sm text-muted-foreground">
                  {vi.common.noData}
                </li>
              ) : null}
            </ul>
          </section>

          {surplus.length > 0 ? (
            <section className="flex flex-col gap-2">
              <h2 className="font-semibold">{vi.trolley.surplusTitle}</h2>
              <ul className="flex flex-col gap-1 rounded-xl border bg-card p-4">
                {surplus.map((c) => (
                  <li
                    key={c.item_id}
                    className="flex justify-between gap-3 text-sm"
                  >
                    <span>
                      {c.item_code} — {c.item_name}
                    </span>
                    <span className="font-medium">
                      +{formatQty(c.surplus_qty)} {c.stock_uom}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          ) : null}

          {shift.purpose_issue_id ? (
            <p className="rounded-xl border bg-card p-4 text-sm">
              {vi.trolley.purposeIssue}:{" "}
              <strong>
                {shift.purpose_issue_doc_no ?? shift.purpose_issue_id}
              </strong>
            </p>
          ) : null}

          {shift.rooms_done.length > 0 ? (
            <section className="flex flex-col gap-2">
              <h2 className="font-semibold">{vi.trolley.roomsDone}</h2>
              <ul className="flex flex-col gap-1 rounded-xl border bg-card p-4">
                {shift.rooms_done.map((r, index) => {
                  const room = rooms.find((x) => x.id === r.room_id);
                  return (
                    <li
                      key={index}
                      className="flex justify-between gap-3 text-sm"
                    >
                      <span>
                        {room ? room.room_no : r.room_id} ·{" "}
                        {CLEAN_TYPE_OPTIONS.find(
                          (o) => o.value === r.clean_type,
                        )?.label ?? r.clean_type}
                      </span>
                      {r.guests !== undefined && r.guests !== null ? (
                        <span>
                          {r.guests} {vi.trolley.guestsShort}
                        </span>
                      ) : null}
                    </li>
                  );
                })}
              </ul>
            </section>
          ) : null}
        </>
      )}
    </div>
  );
}
